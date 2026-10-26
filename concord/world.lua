--- A collection of Systems and Entities.
--- A World emits events so Systems can iterate their Pools.
--- A World contains any amount of Systems and Entities, plus optional named resources.
--- `World(...)` is equivalent to `World.new(...)`.
--- Override optional callbacks below on the world instance (methods are copied onto each instance at creation).
---@docs kind class
---@class Concord.World
---@field ENABLE_OPTIMIZATION boolean When true, shallow-copies class methods onto each instance for faster access (default true)
---@field private __entities Concord.List Flushed Entities in the World
---@field private __systems Concord.List Systems registered on the World
---@field private __systemLookup table<Concord.SystemClass, Concord.System> SystemClass to live System instance
---@field private __hash Concord.WorldKeyHash Entity key registry
---@field private __resources table<string, any> Named singleton resources
---@field private __events table<string, Concord.WorldEventListener[]> Listeners per callback name
local World = {
   ENABLE_OPTIMIZATION = true,
}
World.__mt = {
   __index = World,
}

--- Payload from `World:serialize`, passed to `World:deserialize`.
--- `generator` restores key-generator state. Numeric indices are per-entity tables from `Entity:serialize` (see Entity for shape).
---@class Concord.SerializedWorld
---@field generator any Snapshot of the World's key-generator state
---@field [integer] table Serialized Entity data from `Entity:serialize`

--- Registered handler invoked by `World:emit` for a callback name on a System instance.
---@class Concord.WorldEventListener
---@field system Concord.System System instance that owns the callback
---@field callback fun(system: Concord.System, ...: any) Function from the SystemClass (first arg is the live system)

--- Internal key registry and generator state for `World:getEntityByKey` / built-in Key.
---@class Concord.WorldKeyHash
---@field state any Current generator state
---@field generator fun(state: any): string|number, any Key generator
---@field keys table<Concord.Entity, string|number> Entity to key
---@field entities table<string|number, Concord.Entity> Key to Entity

---@module 'concord.world'

---@module 'concord.entity'
---@module 'concord.system'
local ConcordEntity --luacheck: ignore

local PATH = (...):gsub('%.[^%.]+$', '')

local Filter     = require(PATH..".filter")
local Entity     = require(PATH..".entity")
local Components = require(PATH..".components")
local Type       = require(PATH..".type")
local List       = require(PATH..".list")
local Utils      = require(PATH..".utils")


local defaultGenerator = function (state)
   local current = state
   state = state +1
   return string.format("%d", current), state
end

--- Creates a new World.
---@see Concord.World#addSystems
---@param ... Concord.SystemClass SystemClasses of Systems to add
---@return Concord.World world The new World
function World.new(...)
   local world = setmetatable({
      __entities = List(),
      __systems  = List(),

      __events     = {},
      __emitSDepth = 0,

      __resources = {},

      __hash = {
         state = -2^53,
         generator = defaultGenerator,
         keys = {},
         entities = {}
      },

      __added   = List(), __backAdded   = List(),
      __removed = List(), __backRemoved = List(),
      __dirty   = List(), __backDirty   = List(),

      __systemLookup = {},

      __isWorld = true,

      __ignoreEmits = false,
      __flushing = false,
   }, World.__mt)

   -- Optimization: We shallow copy the World class into our instance of a world.
   -- This grants slightly faster access times at the cost of memory.
   -- Since there (generally) won't be many instances of worlds this is a worthwhile tradeoff
   if (World.ENABLE_OPTIMIZATION) then
      Utils.shallowCopy(World, world)
   end

   return world:addSystems(...)
end

--- Queues an Entity to be added to the World.
--- The Entity's world is set immediately. The Entity is not in getEntities()
--- and is not evaluated by Systems until the next flush.
---@param e Concord.Entity Entity to add
---@return Concord.World world
function World:addEntity(e)
   if not Type.isEntity(e) then
      Utils.error(2, "bad argument #1 to 'World:addEntity' (Entity expected, got %s)", type(e))
   end

   if Entity.__getWorld(e) then
      error("bad argument #1 to 'World:addEntity' (Entity was already added to a world)", 2)
   end

   Entity.__setWorld(e, self)
   self.__added:add(e)

   return self
end

--- Creates a new Entity and queues it to be added to the World.
---@return Concord.Entity e the new Entity
function World:newEntity()
   return Entity(self)
end

--- Queries flushed Entities against a Filter definition.
--- Pending (not yet flushed) additions are not included. Component changes on
--- already flushed Entities are visible immediately.
---@overload fun(self: Concord.World, def: Concord.FilterDefinition, onMatch: fun(e: Concord.Entity)): nil
--- Pass a function as onMatch. It is called once per matching Entity. Nothing is returned.
---@overload fun(self: Concord.World, def: Concord.FilterDefinition, onMatch?: table): table
--- Collect matches into a table and return it. onMatch is optional; when omitted, a new empty table is used.
---@param def Concord.FilterDefinition Filter definition (component names, with ! prefix to reject)
---@param onMatch? fun(e: Concord.Entity)|table Callback for each match, or a table to fill
---@return table|nil matches The list of matches, or nil if onMatch was a callback
function World:query(def, onMatch)
   local filter = Filter.parse(nil, def)

   local list = nil
   if not Type.isCallable(onMatch) then
      list = type(onMatch) == "table" and onMatch or {}
   end

   for _, e in ipairs(self.__entities) do
      if Filter.match(e, filter) then
         if list then
            table.insert(list, e)
         elseif onMatch then
            onMatch(e)
         end
      end
   end

   return list
end

--- Queues an Entity to be removed from the World.
--- If the Entity has a key Component, it is removed first.
--- The Entity remains in the World until the next flush.
---@param e Concord.Entity Entity to remove
---@return Concord.World world
function World:removeEntity(e)
   if not Type.isEntity(e) then
      Utils.error(2, "bad argument #1 to 'World:removeEntity' (Entity expected, got %s)", type(e))
   end

   if Entity.__getWorld(e) ~= self then
      error("trying to remove an Entity from a World it doesn't belong to", 2)
   end

   if e:has("key") then
      e:remove("key")
   end

   self.__removed:add(e)

   return self
end

-- Internal: Marks an Entity as dirty.
function World:__dirtyEntity(e)
   if not self.__dirty:has(e) then
      self.__dirty:add(e)
   end
end

--- Returns whether a Flush can currently be performed.
--- Flushing is forbidden while a Flush is already in progress
--- (for example from World:onEntityAdded / Pool:onAdded).
---@return boolean canFlush
function World:canFlush()
   return not self.__flushing
end

--- Applies queued Entity additions, removals, and dirty reevaluations.
--- Only the queued buffers are processed, not every Entity in the World.
---@return Concord.World world
function World:flush()
   if not self:canFlush() then
      Utils.error(2, "bad call to 'World:flush' (cannot flush during a flush)")
   end

   -- Early out
   if (self.__added.size == 0 and self.__removed.size == 0 and self.__dirty.size == 0) then
      return self
   end

   self.__flushing = true

   -- Switch buffers
   self.__added,   self.__backAdded   = self.__backAdded,   self.__added
   self.__removed, self.__backRemoved = self.__backRemoved, self.__removed
   self.__dirty,   self.__backDirty   = self.__backDirty,   self.__dirty

   local e

   -- Process added entities
   for i = 1, self.__backAdded.size do
      e = self.__backAdded[i]

      if Entity.__getWorld(e) == self then
         self.__entities:add(e)

         for j = 1, self.__systems.size do
            self.__systems[j]:__evaluate(e)
         end

         self:onEntityAdded(e)
      end
   end
   self.__backAdded:clear()

   -- Process removed entities
   for i = 1, self.__backRemoved.size do
      e = self.__backRemoved[i]

      if Entity.__getWorld(e) == self then
         Entity.__setWorld(e, nil)
         self.__entities:remove(e)

         for j = 1, self.__systems.size do
            self.__systems[j]:__remove(e)
         end

         self:onEntityRemoved(e)
      end
   end
   self.__backRemoved:clear()

   -- Process dirty entities
   for i = 1, self.__backDirty.size do
      e = self.__backDirty[i]

      if Entity.__getWorld(e) == self then
         for j = 1, self.__systems.size do
            self.__systems[j]:__evaluate(e)
         end
      end
   end
   self.__backDirty:clear()

   self.__flushing = false

   return self
end

-- Callback names that should not be registered as World events.
-- This table is an array, so lookup by callback name never matches.
local blacklistedSystemFunctions = {
   "init",
   "onEnabled",
   "onDisabled",
}

local tryAddSystem = function (world, systemClass)
   if (not Type.isSystemClass(systemClass)) then
      return false, "SystemClass expected, got "..type(systemClass)
   end

   if (world.__systemLookup[systemClass]) then
      return false, "SystemClass was already added to World"
   end

   -- Create instance of system
   local system = systemClass(world)

   world.__systemLookup[systemClass] = system
   world.__systems:add(system)

   for callbackName, callback in pairs(systemClass) do
      -- Skip callback if its blacklisted
      if (not blacklistedSystemFunctions[callbackName]) then
         -- Make container for all listeners of the callback if it does not exist yet
         if (not world.__events[callbackName]) then
            world.__events[callbackName] = {}
         end

         -- Add callback to listeners
         local listeners = world.__events[callbackName]
         listeners[#listeners + 1] = {
            system   = system,
            callback = callback,
         }
      end
   end

   -- Evaluate all existing entities
   for j = 1, world.__entities.size do
      system:__evaluate(world.__entities[j])
   end

   return true
end

--- Adds a System to the World.
--- Functions on the SystemClass are registered as event listeners.
--- Entities already in the World are evaluated against the System's Filters.
---@see Concord.World#emit
---@param systemClass Concord.SystemClass SystemClass of System to add
---@return Concord.World world
function World:addSystem(systemClass)
   local ok, err = tryAddSystem(self, systemClass)

   if not ok then
      Utils.error(2, "bad argument #1 to 'World:addSystem' (%s)", err)
   end

   return self
end

--- Adds multiple Systems to the World.
--- Functions on each SystemClass are registered as event listeners.
---@see Concord.World#addSystem
---@see Concord.World#emit
---@param ... Concord.SystemClass SystemClasses of Systems to add
---@return Concord.World world
function World:addSystems(...)
   for i = 1, select("#", ...) do
      local systemClass = select(i, ...)

      local ok, err = tryAddSystem(self, systemClass)
      if not ok then
         Utils.error(2, "bad argument #%d to 'World:addSystems' (%s)", i, err)
      end
   end

   return self
end

--- Returns whether the World has a System.
---@param systemClass Concord.SystemClass SystemClass of System to check for
---@return boolean has
function World:hasSystem(systemClass)
   if not Type.isSystemClass(systemClass) then
      Utils.error(2, "bad argument #1 to 'World:hasSystem' (SystemClass expected, got %s)", type(systemClass))
   end

   return self.__systemLookup[systemClass] and true or false
end

--- Gets a System from the World.
---@param systemClass Concord.SystemClass SystemClass of System to get
---@return Concord.System|nil system The system instance, or nil if the class was not added
function World:getSystem(systemClass)
   if not Type.isSystemClass(systemClass) then
      Utils.error(2, "bad argument #1 to 'World:getSystem' (SystemClass expected, got %s)", type(systemClass))
   end

   return self.__systemLookup[systemClass]
end

--- Emits a callback in the World.
--- Calls all functions with the functionName of added Systems (see System class for listener registration).
---@see Concord.System
--- Prefix the name with a System's name to target one System: `"SystemName.event"`.
--- Automatically flushes before forwarding the event, unless this emit is nested
--- or a flush is already in progress.
--- If beforeEmit exists and returns a truthy value, listeners are skipped.
--- afterEmit is called after listeners when present.
---@param functionName string Event name, or `"SystemName.event"` to call only that System
---@param ... any Parameters passed to System's functions
---@return Concord.World world
function World:emit(functionName, ...)
   local shouldFlush = self.__emitSDepth == 0 and self:canFlush()

   if not functionName or type(functionName) ~= "string" then
      Utils.error(2, "bad argument #1 to 'World:emit' (String expected, got %s)", type(functionName))
   end

   local systemName, eventName = functionName:match("^([^%.]+)%.(.+)$")
   if not eventName then
      eventName = functionName
   end

   self.__emitSDepth = self.__emitSDepth + 1

   local listeners = self.__events[eventName]

   if not self.__ignoreEmits and Type.isCallable(self.beforeEmit) then
      self.__ignoreEmits = true
      local preventDefaults = self:beforeEmit(systemName, eventName, listeners, ...)
      self.__ignoreEmits = false
      if preventDefaults then
         self.__emitSDepth = self.__emitSDepth - 1
         return self
      end
   end

   if shouldFlush then
      self:flush()
   end

   if listeners then
      for i = 1, #listeners do
         local listener = listeners[i]
         local system = listener.system

         if system:isEnabled() and (not systemName or system:getName() == systemName) then
            self.__ignoreEmits = true
            local ignoreListener = self:beforeSystemCallback(system, eventName, ...)
            self.__ignoreEmits = false
            if not ignoreListener then
               listener.callback(system, ...)
            end
            self.__ignoreEmits = true
            self:afterSystemCallback(system, eventName, ...)
            self.__ignoreEmits = false
         end
      end
   end

   if not self.__ignoreEmits and Type.isCallable(self.afterEmit) then
      self.__ignoreEmits = true
      self:afterEmit(systemName, eventName, listeners, ...)
      self.__ignoreEmits = false
   end

   self.__emitSDepth = self.__emitSDepth - 1

   return self
end

--- Emits a callback in the World without flushing.
---@see Concord.World#emit
---@param functionName string Name of functions to call.
---@param ... any Parameters passed to System's functions
---@return Concord.World world
function World:emitNoFlush(functionName, ...)
   local flushing = self.__flushing
   self.__flushing = true
   self:emit(functionName, ...)
   self.__flushing = flushing
   return self
end

--- Removes all Entities from the World and flushes.
--- Entities that were queued to be added are detached immediately without
--- onEntityRemoved. Already flushed Entities are removed through the normal flush.
---@return Concord.World world
function World:clear()
   for i = 1, self.__entities.size do
      self:removeEntity(self.__entities[i])
   end

   for i = 1, self.__added.size do
      local e = self.__added[i]
      Entity.__setWorld(e, nil)
   end
   self.__added:clear()

   self:flush()

   return self
end

--- Returns the List of flushed Entities in the World.
---@return Concord.List entities
function World:getEntities()
   return self.__entities
end

--- Returns the List of Systems in the World.
---@return Concord.List systems
function World:getSystems()
   return self.__systems
end

--- Serializes serializable Entities in the World.
--- Flushes first. Only Entities with a serializable Component are included.
---@see Concord.Entity#serialize
---@param ignoreKeys? boolean If true, omits keys when calling `Entity:serialize` (Entity parameter name: `ignoreKey`)
---@return Concord.SerializedWorld data Serialized world data
function World:serialize(ignoreKeys)
   self:flush()

   local data = { generator = self.__hash.state }

   for i = 1, self.__entities.size do
      local entity = self.__entities[i]

      if entity.serializable then
         local entityData = entity:serialize(ignoreKeys)
         table.insert(data, entityData)
      end
   end

   return data
end

--- Deserializes Entities into the World.
--- Restores each entity's `key` first when present in saved data, then deserializes component array entries.
---@see Concord.Entity#deserialize
---@param data Concord.SerializedWorld Serialized world data
---@param startClean? boolean If true, existing Entities are cleared first
---@param ignoreGenerator? boolean If true, the World's key generator state is left unchanged
---@return Concord.World world
function World:deserialize(data, startClean, ignoreGenerator)
   if startClean then
      self:clear()
   end

   if (not ignoreGenerator) then
      self.__hash.state = data.generator
   end

   local entities = {}

   for i = 1, #data do
      local entity = Entity(self)

      if data[i].key then
         local component = Components.key:__new(entity)
         component:deserialize(data[i].key)
         entity.key = component

         entity:__dirty()
      end

      entities[i] = entity
   end

   for i = 1, #data do
      entities[i]:deserialize(data[i])
   end

   self:flush()

   return self
end

--- Sets the function used to generate Entity keys.
---@param generator fun(state: any): string|number, any Callable that receives the current state and returns key, newState
---@param initialState any Initial state passed to the generator
---@return Concord.World world
function World:setKeyGenerator(generator, initialState)
   if not Type.isCallable(generator) then
      Utils.error(2, "bad argument #1 to 'World:setKeyGenerator' (function expected, got %s)", type(generator))
   end

   self.__hash.generator = generator
   self.__hash.state = initialState

   return self
end

-- Internal: Clears the key assigned to an Entity.
function World:__clearKey(e)
   local key = self.__hash.keys[e]

   if key then
      self.__hash.keys[e] = nil
      self.__hash.entities[key] = nil
   end

   return self
end

-- Internal: Assigns a key to an Entity, generating one if needed.
function World:__assignKey(e, key)
   local hash = self.__hash

   if not key then
      key = hash.keys[e]
      if key then return key end

      key, hash.state = hash.generator(hash.state)
   end

   if hash.entities[key] and hash.entities[key] ~= e then
      Utils.error(4, "Trying to assign a key that is already taken (key: '%s').", key)
   elseif hash.keys[e] and hash.keys[e] ~= key then
      Utils.error(4, "Trying to assign more than one key to an Entity. (old: '%s', new: '%s')", hash.keys[e], key)
   end

   hash.keys[e] = key
   hash.entities[key] = e

   return key
end

--- Gets an Entity by its key.
---@param key string|number Key to look up
---@return Concord.Entity|nil entity
function World:getEntityByKey(key)
   return self.__hash.entities[key]
end

--- Sets a named resource on the World (singleton shared state, not an Entity Component).
--- Typical uses: services, asset handles, or frame context accessible from Systems.
---@param name string Name of the resource
---@param resource any Resource to set
---@return Concord.World world
function World:setResource(name, resource)
  self.__resources[name] = resource
  return self
end

--- Gets a named resource from the World.
---@param name string Name of the resource
---@return any resource The resource, or nil if none was set
function World:getResource(name)
  return self.__resources[name]
end

--- ## Callbacks
--- Optional hooks: assign on the world instance after `World.new`, e.g. `function world:onEntityAdded(e) ... end`.

--- Callback for when an Entity is added to the World.
---@param e Concord.Entity The Entity that was added
function World:onEntityAdded(e) -- luacheck: ignore
end

--- Callback for when an Entity is removed from the World.
---@param e Concord.Entity The Entity that was removed
function World:onEntityRemoved(e) -- luacheck: ignore
end

--- Callback before World:emit forwards an event to Systems.
--- Returning a truthy value skips System listeners and afterEmit for this emit.
--- Nested emits are forbidden inside this callback
---@param systemName? string System name when emit used `"SystemName.event"`, otherwise nil
---@param functionName string Name of the event being emitted
---@param listeners? table Listeners registered for this event, or nil
---@param ... any Parameters passed to World:emit
---@return boolean? skip Truthy to skip listeners
function World:beforeEmit(systemName, functionName, listeners, ...) -- luacheck: ignore
end

--- Callback after World:emit has forwarded an event to Systems.
--- Not called when beforeEmit skips the emit
--- Nested emits are forbidden inside this callback
---@param systemName? string System name when emit used `"SystemName.event"`, otherwise nil
---@param functionName string Name of the event being emitted
---@param listeners? table Listeners registered for this event, or nil
---@param ... any Parameters passed to World:emit
function World:afterEmit(systemName, functionName, listeners, ...) -- luacheck: ignore
end


--- Callback before World:emit forwards an event to a System.
--- Returning a truthy value skips the System listener and afterSystemCallback for this event.
--- Nested emits are forbidden inside this callback
---@param system Concord.System System that is being called
---@param eventName string Name of the event being emitted
---@param ... any Parameters passed to World:emit
---@return boolean? skip Truthy to skip the System listener and afterSystemCallback
function World:beforeSystemCallback(system, eventName, ...) -- luacheck: ignore
end

--- Callback after World:emit has forwarded an event to a System.
--- Not called when beforeSystemCallback skips the emit
--- Nested emits are forbidden inside this callback
---@param system Concord.System System that is being called
---@param eventName string Name of the event being emitted
---@param ... any Parameters passed to World:emit
function World:afterSystemCallback(system, eventName, ...) -- luacheck: ignore
end

return setmetatable(World, {
   __call = function(_, ...)
      return World.new(...)
   end,
})

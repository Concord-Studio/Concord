--- Iterates over Entities, reads their Components, and updates game state.
--- A SystemClass is a template registered on a World via `World:addSystem`.
--- Each instance belongs to one World and holds zero or more Pools (one per filter key in the definition).
---
--- **Pools:** Keys in the definition table become fields on the system instance, each holding a `Pool`
--- (default `List`). Iterate with `ipairs(system.poolName)`; when the pool is a `List`, use `pool.size`.
---@see FilterDefinition
---@see List
---
--- **Event listeners:** Every function on the SystemClass except `init`, `onEnabled`, and `onDisabled`
--- is registered when the system is added. `World:emit("callbackName", ...)` invokes those functions
--- on enabled system instances. Use `System.new("Name", ...)` and `World:emit("Name.callback", ...)`
--- to target one system.
---@see World#emit
---@see World#addSystem
---
--- **Flush and pools:** On `World:flush`, added, removed, and dirty Entities are processed;
--- each system's filters re-evaluate matching Entities and update pool membership.
---@see World#flush
---@docs kind class
---@class System
---@field ENABLE_OPTIMIZATION boolean When true, shallow-copies class methods onto each instance for faster access (default true)

--- Registered system type returned by `System.new` / `System()`.
--- Call the class with a World to construct a live system instance (`SystemClass(world)`).
--- Filter definition keys become dynamic pool fields on each instance (not listed on this type).
---@class SystemClass : System

local PATH = (...):gsub('%.[^%.]+$', '')

local Filter     = require(PATH..".filter")
local Utils      = require(PATH..".utils")

local System = {
   ENABLE_OPTIMIZATION = true,
}

System.mt = {
   __index = System,
   __call  = function(systemClass, world)
      local system = setmetatable({
         __enabled = true,

         __filters = {},
         __world = world,

         __isSystem = true,
         __isSystemClass = false, -- Overwrite value from systemClass
      }, systemClass)

      -- Optimization: We shallow copy the System class into our instance of a system.
      -- This grants slightly faster access times at the cost of memory.
      -- Since there (generally) won't be many instances of systems this is a worthwhile tradeoff
      if (System.ENABLE_OPTIMIZATION) then
         Utils.shallowCopy(systemClass, system)
      end

      for name, def in pairs(systemClass.__definition) do
         local filter, pool = Filter(name, Utils.shallowCopy(def, {}))

         system[name] = pool
         table.insert(system.__filters, filter)
      end

      system:init(world)

      return system
   end,
}
--- Creates a new SystemClass. The return value is a class; the World constructs instances when the class is added.
--- Reject components in filter lists with the `!` prefix or `Components.reject` (same rules as `FilterDefinition`).
---@overload fun(definition: table<string, FilterDefinition>): SystemClass
---@param name? string Name of the System. If the first argument is not a string, it is treated as the definition.
---@param definition? table<string, FilterDefinition> Map of pool names to filter definitions (component names, optional `!` reject entries)
---@return SystemClass
function System.new(name, definition)
   if type(name) ~= "string" then
      definition = name or definition
      name = nil
   end

   definition = definition or {}

   if type(definition) ~= "table" then
      Utils.error(2, "bad argument to 'System.new' (definition table expected, got %s)", type(definition))
   end

   for filterName, def in pairs(definition) do
      if type(filterName) ~= 'string' then
         Utils.error(2, "invalid name for filter (string key expected, got %s)", type(filterName))
      end

      Filter.validate(0, filterName, def)
   end

   local systemClass = setmetatable({
      __definition = definition,
      __name = name,

      __isSystemClass = true,
   }, System.mt)
   systemClass.__index = systemClass

   -- Optimization: We shallow copy the System class into the SystemClass.
   -- This grants slightly faster access times at the cost of memory.
   -- Since there (generally) won't be many instances of systems this is a worthwhile tradeoff
   if (System.ENABLE_OPTIMIZATION) then
      Utils.shallowCopy(System, systemClass)
   end

   return systemClass
end

-- Internal: Evaluates an Entity for all the System's Pools.
function System:__evaluate(e)
   for _, filter in ipairs(self.__filters) do
      filter:evaluate(e)
   end

   return self
end

-- Internal: Removes an Entity from the System.
function System:__remove(e)
   for _, filter in ipairs(self.__filters) do
      if filter:has(e) then
         filter:remove(e)
      end
   end

   return self
end

-- Internal: Clears all Entities from the System.
function System:__clear()
   for _, filter in ipairs(self.__filters) do
      filter:clear()
   end

   return self
end

--- Sets whether the System is enabled.
--- Disabled systems do not receive `World:emit` callbacks until re-enabled.
---@see World#emit
---@param enable boolean
---@return System
function System:setEnabled(enable)
   if (not self.__enabled and enable) then
      self.__enabled = true
      self:onEnabled()
   elseif (self.__enabled and not enable) then
      self.__enabled = false
      self:onDisabled()
   end

   return self
end

--- Returns whether the System is enabled (enabled systems receive emit callbacks).
---@return boolean
function System:isEnabled()
   return self.__enabled
end

--- Returns the World the System is in.
---@return World
function System:getWorld()
   return self.__world
end

--- ## Callbacks

--- Callback for system initialization.
---@param world World The World the System was added to
function System:init(world) -- luacheck: ignore
end

--- Callback when the system becomes enabled via `setEnabled(true)`.
function System:onEnabled() -- luacheck: ignore
end

--- Callback when the system becomes disabled via `setEnabled(false)`.
function System:onDisabled() -- luacheck: ignore
end

return setmetatable(System, {
   __call = function(_, ...)
      return System.new(...)
   end,
})

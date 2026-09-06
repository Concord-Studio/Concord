--- Iterates over Entities. From these Entities its get Components and modify them.
-- A System contains 1 or more Pools.
-- A System is contained by 1 World.
-- @classmod System

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

      -- Optimization: We deep copy the System class into our instance of a system.
      -- This grants slightly faster access times at the cost of memory.
      -- Since there (generally) won't be many instances of worlds this is a worthwhile tradeoff
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
--- Creates a new SystemClass.
-- @string name Name of the System
-- @tparam table definition A table containing filters (name = {components...})
-- @treturn System A new SystemClass
function System.new(name, definition)
   if type(name) == "table" then
      definition = name
      name = nil
   elseif name ~= nil and type(name) ~= "string" then
      Utils.error(2, "bad argument #1 to 'System.new' (string expected, got %s)", type(name))
   end

   definition = definition or {}

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

   -- Optimization: We deep copy the World class into our instance of a world.
   -- This grants slightly faster access times at the cost of memory.
   -- Since there (generally) won't be many instances of worlds this is a worthwhile tradeoff
   if (System.ENABLE_OPTIMIZATION) then
      Utils.shallowCopy(System, systemClass)
   end

   return systemClass
end

-- Internal: Evaluates an Entity for all the System's Pools.
-- @param e The Entity to check
-- @treturn System self
function System:__evaluate(e)
   for _, filter in ipairs(self.__filters) do
      filter:evaluate(e)
   end

   return self
end

-- Internal: Removes an Entity from the System.
-- @param e The Entity to remove
-- @treturn System self
function System:__remove(e)
   for _, filter in ipairs(self.__filters) do
      if filter:has(e) then
         filter:remove(e)
      end
   end

   return self
end

-- Internal: Clears all Entities from the System.
-- @treturn System self
function System:__clear()
   for _, filter in ipairs(self.__filters) do
      filter:clear()
   end

   return self
end

--- Sets if the System is enabled
-- @tparam boolean enable
-- @treturn System self
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

--- Returns is the System is enabled
-- @treturn boolean
function System:isEnabled()
   return self.__enabled
end

--- Returns the World the System is in.
-- @treturn World
function System:getWorld()
   return self.__world
end

--- Callbacks
-- @section Callbacks

--- Callback for system initialization.
-- @tparam World world The World the System was added to
function System:init(world) -- luacheck: ignore
end

--- Callback for when a System is enabled.
function System:onEnabled() -- luacheck: ignore
end

--- Callback for when a System is disabled.
function System:onDisabled() -- luacheck: ignore
end

return setmetatable(System, {
   __call = function(_, ...)
      return System.new(...)
   end,
})

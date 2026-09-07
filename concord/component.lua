--- A pure data container that is contained by a single entity.
-- @classmod Component

local PATH = (...):gsub('%.[^%.]+$', '')

local Components = require(PATH..".components")
local Utils      = require(PATH..".utils")

local Component = {}
Component.__mt = {
   __index = Component,
}

--- Creates a new ComponentClass and registers it by name.
-- @string name Unique name of the ComponentClass
-- @tparam[opt] function populate Function that populates a Component with values
-- @treturn Component A new ComponentClass
function Component.new(name, populate)
   if (type(name) ~= "string") then
      Utils.error(2, "bad argument #1 to 'Component.new' (string expected, got %s)", type(name))
   end

   if (string.match(name, Components.__REJECT_MATCH) ~= "") then
      Utils.error(2, "bad argument #1 to 'Component.new' (Component names can't start with '%s', got %s)", Components.__REJECT_PREFIX, name)
   end

   if (rawget(Components, name)) then
      Utils.error(2, "bad argument #1 to 'Component.new' (ComponentClass with name '%s' was already registerd)", name) -- luacheck: ignore
   end

   if (type(populate) ~= "function" and type(populate) ~= "nil") then
      Utils.error(2, "bad argument #1 to 'Component.new' (function/nil expected, got %s)", type(populate))
   end

   local componentClass = setmetatable({
      __populate = populate,

      __name             = name,
      __isComponentClass = true,
   }, Component.__mt)

   componentClass.__mt = {
      __index = componentClass
   }

   Components[name] = componentClass

   return componentClass
end

-- Internal: Populates a Component with values.
function Component:__populate() -- luacheck: ignore
end

--- Callback: When the Component gets removed or replaced in an Entity.
-- @tparam boolean replaced True when the Component is being overwritten, false when it is being removed
function Component:removed(replaced) -- luacheck: ignore
end

--- Callback: When the Component gets serialized as part of an Entity.
-- @treturn table|nil Serialized data, or nil to omit this Component
function Component:serialize()
   local data = Utils.shallowCopy(self, {})

   --This values shouldn't be copied over
   data.__componentClass   = nil
   data.__entity           = nil
   data.__isComponent      = nil
   data.__isComponentClass = nil

   return data
end

--- Callback: When the Component gets deserialized from serialized data.
-- @tparam table data Serialized data to copy onto this Component
function Component:deserialize(data)
   Utils.shallowCopy(data, self)
end

-- Internal: Creates a new Component.
-- @param entity The Entity that will receive this Component.
-- @return A new Component
function Component:__new(entity)
   local component = setmetatable({
      __componentClass = self,

      __entity           = entity,
      __isComponent      = true,
      __isComponentClass = false,
   }, self.__mt)

   return component
end

-- Internal: Creates and populates a new Component.
-- @param entity The Entity that will receive this Component.
-- @param ... Varargs passed to the populate function
-- @return A new populated Component
function Component:__initialize(entity, ...)
   local component = self:__new(entity)

   -- LuaLS: redundant-parameter (varargs forwarded to populate)
   self.__populate(component, ...)

   return component
end

--- Returns true if the Component has a name.
-- @treturn boolean
function Component:hasName()
   return self.__name and true or false
end

--- Returns the name of the Component.
-- @treturn string
function Component:getName()
   return self.__name
end

return setmetatable(Component, {
   __call = function(_, ...)
      return Component.new(...)
   end,
})

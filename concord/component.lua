--- A pure data container attached to a single Entity.
--- Component instances are created when an Entity `:give`s the class; populate runs at attach time.
---@docs kind class
---@class Concord.Component
---@field getName fun(self: Concord.Component): string
---@field hasName fun(self: Concord.Component): boolean
---@field serialize fun(self: Concord.Component): table|nil
---@field deserialize fun(self: Concord.Component, data: table): nil
---@field removed fun(self: Concord.Component, replaced: boolean): nil

--- Registered component type returned by `Component.new` / `Component()`.
--- `ComponentClass` is the registry entry; instances on entities share callbacks via the class metatable.
---@class Concord.ComponentClass : Concord.Component
---@module 'concord.component'

local PATH = (...):gsub('%.[^%.]+$', '')

local Components = require(PATH..".components")
local Utils      = require(PATH..".utils")

local Component = {}
Component.__mt = {
   __index = Component,
}

--- Creates a new ComponentClass and registers it by name.
--- `Component("name", populate?)` is equivalent to this function.
--- Populate receives the new component instance and `:give` / `:ensure` arguments.
---@see Concord.Entity#give
---@param name string Unique name of the ComponentClass
---@param populate? fun(component: Concord.Component, ...): nil Function that populates a Component with values
---@return Concord.ComponentClass
function Component.new(name, populate)
   if (type(name) ~= "string") then
      Utils.error(2, "bad argument #1 to 'Component.new' (string expected, got %s)", type(name))
   end

   if (string.match(name, Components.__REJECT_MATCH) ~= "") then
      Utils.error(2, "bad argument #1 to 'Component.new' (Component names can't start with '%s', got %s)", Components.__REJECT_PREFIX, name)
   end

   if (rawget(Components, name)) then
      Utils.error(2, "bad argument #1 to 'Component.new' (ComponentClass with name '%s' was already registered)", name) -- luacheck: ignore
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

-- Internal: Creates a new Component.
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
function Component:__initialize(entity, ...)
   local component = self:__new(entity)

   ---@diagnostic disable-next-line: redundant-parameter
   self.__populate(component, ...)

   return component
end

--- Returns true if the Component has a name.
---@return boolean
function Component:hasName()
   return self.__name and true or false
end

--- Returns the name of the Component.
---@return string
function Component:getName()
   return self.__name
end

--- ## Callbacks

--- Callback for when the Component is removed or replaced in an Entity.
---@param replaced boolean True when the Component is being overwritten, false when it is being removed
function Component:removed(replaced) -- luacheck: ignore
end

--- Callback for when the Component is serialized as part of an Entity.
---@return table|nil Serialized data, or nil to omit this Component
function Component:serialize()
   local data = Utils.shallowCopy(self, {})

   --This values shouldn't be copied over
   data.__componentClass   = nil
   data.__entity           = nil
   data.__isComponent      = nil
   data.__isComponentClass = nil

   return data
end

--- Callback for when the Component is deserialized from serialized data.
---@param data table Serialized data to copy onto this Component
function Component:deserialize(data)
   Utils.shallowCopy(data, self)
end

return setmetatable(Component, {
   __call = function(_, ...)
      return Component.new(...)
   end,
})

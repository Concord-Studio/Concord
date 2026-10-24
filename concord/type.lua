--- Runtime type predicates for Concord values (extension code, tooling, defensive checks).
---@docs kind module
---@class Type
---@module 'concord.type'

local Type = {}

--- Returns true if the value is a function or has a `__call` metamethod.
--- Use before treating a value as a populate function, pool constructor, or generator.
---@param t any Object to check
---@return boolean
function Type.isCallable(t)
   if type(t) == "function" then return true end

   local meta = getmetatable(t)
   if meta and type(meta.__call) == "function" then return true end

   return false
end

--- Returns true if the value is an Entity instance.
--- Use when accepting arbitrary tables that might be entities (e.g. world APIs, serializers).
---@param t any Object to check
---@return boolean
function Type.isEntity(t)
   return type(t) == "table" and t.__isEntity or false
end

--- Returns true if the value is a registered ComponentClass (not a component instance).
--- Use before `World`-level APIs that expect a class, or when validating `Component.new` results.
---@param t any Object to check
---@return boolean
function Type.isComponentClass(t)
   return type(t) == "table" and t.__isComponentClass or false
end

--- Returns true if the value is a Component instance attached to an entity.
--- Use when iterating entity fields or handling `Entity:give` component-instance overload.
---@param t any Object to check
---@return boolean
function Type.isComponent(t)
   return type(t) == "table" and t.__isComponent or false
end

--- Returns true if the value is a SystemClass template (not a live system instance).
--- Use before `World:addSystem`, `World:hasSystem`, or `World:getSystem`.
---@param t any Object to check
---@return boolean
function Type.isSystemClass(t)
   return type(t) == "table" and t.__isSystemClass or false
end

--- Returns true if the value is a System instance belonging to a World.
---@param t any Object to check
---@return boolean
function Type.isSystem(t)
   return type(t) == "table" and t.__isSystem or false
end

--- Returns true if the value is a World instance.
--- Use when validating optional world arguments to `Entity.new` or custom helpers.
---@param t any Object to check
---@return boolean
function Type.isWorld(t)
   return type(t) == "table" and t.__isWorld or false
end

--- Returns true if the value is a Filter instance (internal pool driver; rarely needed in game code).
---@param t any Object to check
---@return boolean
function Type.isFilter(t)
   return type(t) == "table" and t.__isFilter or false
end

return Type

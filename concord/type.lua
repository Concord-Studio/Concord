--- Helper module to do easy type checking for Concord types
-- @module Type

local Type = {}

--- Returns true if the value is a function or has a __call metamethod.
-- @param t Object to check
-- @treturn boolean
function Type.isCallable(t)
   if type(t) == "function" then return true end

   local meta = getmetatable(t)
   if meta and type(meta.__call) == "function" then return true end

   return false
end

--- Returns if object is an Entity.
-- @param t Object to check
-- @treturn boolean
function Type.isEntity(t)
   return type(t) == "table" and t.__isEntity or false
end

--- Returns if object is a ComponentClass.
-- @param t Object to check
-- @treturn boolean
function Type.isComponentClass(t)
   return type(t) == "table" and t.__isComponentClass or false
end

--- Returns if object is a Component.
-- @param t Object to check
-- @treturn boolean
function Type.isComponent(t)
   return type(t) == "table" and t.__isComponent or false
end

--- Returns if object is a SystemClass.
-- @param t Object to check
-- @treturn boolean
function Type.isSystemClass(t)
   return type(t) == "table" and t.__isSystemClass or false
end

--- Returns if object is a System.
-- @param t Object to check
-- @treturn boolean
function Type.isSystem(t)
   return type(t) == "table" and t.__isSystem or false
end

--- Returns if object is a World.
-- @param t Object to check
-- @treturn boolean
function Type.isWorld(t)
   return type(t) == "table" and t.__isWorld or false
end

--- Returns if object is a Filter.
-- @param t Object to check
-- @treturn boolean
function Type.isFilter(t)
   return type(t) == "table" and t.__isFilter or false
end

return Type

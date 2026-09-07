--- Built-in marker Component. Entities with this Component are included in World:serialize.
-- The Component itself is not serialized.
-- @builtin serializable

local PATH = (...):gsub('%.builtins%.[^%.]+$', '')

local Component = require(PATH..".component")

local Serializable = Component("serializable")

--- Callback: When the Component gets serialized as part of an Entity.
-- Returns nil so this marker is not written to serialized data.
-- @treturn nil
function Serializable:serialize ()
  -- Don't serialize this Component
  return nil
end

return Serializable
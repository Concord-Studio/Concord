--- Built-in Component that assigns a unique key to an Entity in its World.
-- The Entity must belong to a World. Calling the Component returns the key value.
-- @builtin key

local PATH = (...):gsub('%.builtins%.[^%.]+$', '')

local Component = require(PATH..".component")

local getKey = function (self, key)
  local entity = self.__entity

  if not entity:inWorld() then
    error("entity needs to belong to a world")
  end

  local world = entity:getWorld()

  return world:__assignKey(entity, key)
end

local Key = Component("key", function (self, key)
  self.value = getKey(self, key)
end)

--- Assigns a key from serialized data.
-- @param data Previously serialized key value
function Key:deserialize (data)
  self.value = getKey(self, data)
end

--- Returns the key value.
-- @function Key
-- @treturn string|number The Entity's key
function Key.__mt:__call()
  return self.value
end

--- Callback: Clears the World key when the Component is removed (not replaced).
-- @tparam boolean replaced True when the Component is being overwritten
function Key:removed (replaced)
  if not replaced then
    local entity = self.__entity

    if entity:inWorld() then
      local world = entity:getWorld()

      return world:__clearKey(entity)
    end
  end
end

return Key

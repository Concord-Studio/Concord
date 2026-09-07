--- Container for registered ComponentClasses
-- @module Components

local Components = {}

Components.__REJECT_PREFIX = "!"
Components.__REJECT_MATCH = "^(%"..Components.__REJECT_PREFIX.."?)(.+)"

--- Returns true if the container has the ComponentClass with the specified name
-- @string name Name of the ComponentClass to check
-- @treturn boolean
function Components.has(name)
   return rawget(Components, name) and true or false
end

--- Prefix a component's name with the currently set Reject Prefix
-- @string name Name of the ComponentClass to reject
-- @treturn string
function Components.reject(name)
   local ok, err = Components.try(name)

   if not ok then error(err, 2) end

   return Components.__REJECT_PREFIX..name
end

--- Returns true and the ComponentClass if one was registered with the specified name
-- or false and an error otherwise
-- @string name Name of the ComponentClass to check
-- @tparam[opt] boolean acceptRejected Whether to accept names prefixed with the Reject Prefix.
-- @treturn boolean ok
-- @treturn Component|string ComponentClass on success, or an error string on failure
-- @treturn string|boolean On success: the stripped Component name if the name had the Reject Prefix, otherwise false
function Components.try(name, acceptRejected)
   if type(name) ~= "string" then
      return false, "ComponentsClass name is expected to be a string, got "..type(name)..")"
   end

   local rejected = false
   if acceptRejected then
      local prefix
      prefix, name = string.match(name, Components.__REJECT_MATCH)

      rejected = prefix ~= "" and name
   end

   local value = rawget(Components, name)
   if not value then
      return false, "ComponentClass '"..name.."' does not exist / was not registered"
   end

   return true, value, rejected
end

--- Returns the ComponentClass with the specified name
-- @string name Name of the ComponentClass to get
-- @treturn Component The registered ComponentClass
function Components.get(name)
   local ok, value = Components.try(name)

   if not ok then error(value, 2) end

   return value
end

return setmetatable(Components, {
   __index = function(_, name)
      local ok, value = Components.try(name)

      if not ok then error(value, 2) end

      return value    end
})

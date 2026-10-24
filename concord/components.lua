--- Container for registered ComponentClasses.
--- Use `Components.get(name)`, `Components.has(name)`, or `Components[name]` / `Components.name` (same as get; errors if missing).
---@see Concord.FilterDefinition
---@docs kind module
---@class Concord.Components
---@field __REJECT_PREFIX string Reject prefix for filter lists (`"!"`); see `Components.reject` and FilterDefinition
---@module 'concord.component'

local Components = {}

---@type string
Components.__REJECT_PREFIX = "!"
Components.__REJECT_MATCH = "^(%"..Components.__REJECT_PREFIX.."?)(.+)"

--- Returns true if the container has the ComponentClass with the specified name
---@param name string Name of the ComponentClass to check
---@return boolean
function Components.has(name)
   return rawget(Components, name) and true or false
end

--- Prefix a component's name with the currently set Reject Prefix
---@param name string Name of the ComponentClass to reject
---@return string
function Components.reject(name)
   local ok, err = Components.try(name)

   if not ok then error(err, 2) end

   return Components.__REJECT_PREFIX..name
end

--- Returns true and the ComponentClass if one was registered with the specified name
--- or false and an error otherwise
---@param name string Name of the ComponentClass to check
---@param acceptRejected? boolean Whether to accept names prefixed with the Reject Prefix.
---@return boolean ok
---@return Concord.ComponentClass|string componentClass ComponentClass on success, or an error string on failure
---@return string|boolean rejected On success: the stripped Component name if the name had the Reject Prefix, otherwise false
function Components.try(name, acceptRejected)
   if type(name) ~= "string" then
      return false, "ComponentsClass name is expected to be a string, got "..type(name)..")", false
   end

   local rejected = false
   if acceptRejected then
      local prefix
      prefix, name = string.match(name, Components.__REJECT_MATCH)

      rejected = prefix ~= "" and name
   end

   local value = rawget(Components, name)
   if not value then
      return false, "ComponentClass '"..name.."' does not exist / was not registered", false
   end

   return true, value, rejected
end

--- Returns the ComponentClass with the specified name
---@param name string Name of the ComponentClass to get
---@return Concord.ComponentClass
function Components.get(name)
   local ok, value = Components.try(name)

   if not ok then error(value, 2) end

   return value --[[@as Concord.ComponentClass]]
end

return setmetatable(Components, {
   __index = function(_, name)
      local ok, value = Components.try(name)

      if not ok then error(value, 2) end

      return value    end
})

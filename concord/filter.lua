--- Used to filter Entities with specific Components
-- A Filter has an associated Pool that can contain any amount of Entities.
-- @classmod Filter

local PATH = (...):gsub('%.[^%.]+$', '')

local List       = require(PATH..".list")
local Type       = require(PATH..".type")
local Utils      = require(PATH..".utils")
local Components = require(PATH..".components")


local Filter = {}
Filter.__mt = {
   __index = Filter,
}

--- Validates a Filter Definition to make sure every component is valid.
-- Also checks that def.constructor is callable when present, unless onComponent is provided.
-- @int errorLevel Extra stack level added to error reports
-- @tparam[opt] string name Name for the Filter. If omitted, errors refer to a World:query filter.
-- @tparam table def Table containing the Filter Definition
-- @tparam[opt] function onComponent Called with (component, reject) when a component is valid.
-- reject is the stripped Component name when the entry had the Reject Prefix, otherwise false.
function Filter.validate (errorLevel, name, def, onComponent)
   local filter = "World:query filter"
   if name then
      filter = ("filter '%s'"):format(name)
   end

   if type(def) ~= 'table' then
      Utils.error(3 + errorLevel, "invalid component list for %s (table expected, got %s)", filter, type(def))
   end

   if not onComponent and def.constructor and not Type.isCallable(def.constructor) then
      Utils.error(3 + errorLevel, "invalid pool constructor for %s (callable expected, got %s)", filter, type(def.constructor))
   end

   for n, component in ipairs(def) do
      local ok, err, reject = Components.try(component, true)

      if not ok then
         Utils.error(3 + errorLevel, "invalid component for %s at position #%d (%s)", filter, n, err)
      end

      if onComponent then
         onComponent(component, reject)
      end
   end
end

--- Parses a Filter Definition into a single interleaved table.
-- Entries are stored as name, required pairs: {name, true, name, false, ...}
-- where true means the Component is required and false means it is rejected.
-- @tparam[opt] string name Name for the Filter.
-- @tparam table def Table containing the Filter Definition
-- @treturn table Parsed filter
function Filter.parse (name, def)
   local filter = {}

   Filter.validate(1, name, def, function (component, reject)
      if reject then
         table.insert(filter, reject)
         table.insert(filter, false)
      else
         table.insert(filter, component)
         table.insert(filter, true)
      end
   end)

   return filter
end

--- Returns true if the Entity matches a parsed Filter.
-- @tparam Entity e Entity to check
-- @tparam table filter Parsed filter from Filter.parse
-- @treturn boolean
function Filter.match (e, filter)
   for i=#filter, 2, -2 do
      local match = filter[i - 0]
      local name  = filter[i - 1]

      if (not e[name]) == match then return false end
   end

   return true
end

local REQUIRED_METHODS = {"add", "remove", "has", "clear"}
local VALID_POOL_TYPES = {table=true, userdata=true, lightuserdata=true, cdata=true}

--- Checks that a custom Pool implements add, remove, has, and clear as callables.
-- The Pool may be a table, userdata, lightuserdata, or cdata.
-- @string name Name of the Filter / Pool
-- @param pool Pool returned by a custom constructor
function Filter.isValidPool (name, pool)
   local poolType = type(pool)
   --Check that pool is not nil
   if not VALID_POOL_TYPES[poolType] then
      Utils.error(3, "invalid value returned by pool '%s' constructor (table expected, got %s).", name, type(pool))
   end

   --Check if methods are callables
   for _, method in ipairs(REQUIRED_METHODS) do
      if not Type.isCallable(pool[method]) then
         Utils.error(3, "invalid :%s method on pool '%s' (callable expected, got %s).", method, name, type(pool[method]))
      end
   end
end

--- Creates a new Filter
-- If definition.constructor is set, it is called with the definition to create the Pool.
-- @string name Name for the Filter.
-- @tparam table def Table containing the Filter Definition
-- @treturn Filter The new Filter
-- @treturn Pool The associated Pool
function Filter.new (name, def)
   local pool

   if def.constructor then
      pool = def.constructor(def)
      Filter.isValidPool(name, pool)
   else
      pool = List()
   end

   local filter = Filter.parse(name, def)

   local filter = setmetatable({
      pool = pool,

      __filter = filter,
      __name   = name,
   
      __isFilter = true,
   }, Filter.__mt)

   return filter, pool
end

--- Checks if an Entity fulfills the Filter requirements.
-- @tparam Entity e Entity to check
-- @treturn boolean
function Filter:eligible(e)
   return Filter.match(e, self.__filter)
end

--- Evaluates an Entity against this Filter and updates the Pool.
-- Adds the Entity if it became eligible, removes it if it no longer is.
-- @tparam Entity e Entity to evaluate
-- @treturn Filter self
function Filter:evaluate (e)
   local has  = self.pool:has(e)
   local eligible = self:eligible(e)

   if not has and eligible then
      self.pool:add(e)
   elseif has and not eligible then
      self.pool:remove(e)
   end

   return self
end


--- Adds an Entity to the Pool, if it passes the Filter.
-- @tparam Entity e Entity to add
-- @tparam[opt] boolean bypass Whether to bypass the Filter or not.
-- @treturn Filter self
-- @treturn boolean Whether the entity was added or not.
function Filter:add (e, bypass)
   if not bypass and not self:eligible(e) then
      return self, false
   end

   self.pool:add(e)

   return self, true
end

--- Removes an Entity from the Pool associated to this Filter.
-- @tparam Entity e Entity to remove
-- @treturn Filter self
function Filter:remove (e)
   self.pool:remove(e)
   return self
end

--- Clears the Pool associated to this Filter.
-- Arguments are forwarded to the Pool's clear method.
-- @param e Forwarded to pool:clear
-- @treturn Filter self
function Filter:clear (e)
   self.pool:clear(e)
   return self
end

--- Checks if the Pool associated to this Filter contains the passed Entity.
-- @tparam Entity e Entity to check
-- @treturn boolean Whether the Entity exists.
function Filter:has (e)
   return self.pool:has(e)
end

--- Gets the name of the Filter
-- @treturn string
function Filter:getName()
   return self.__name
end

return setmetatable(Filter, {
  __call  = function(_, ...)
     return Filter.new(...)
  end,
})
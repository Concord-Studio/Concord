--- Data structure that allows for fast removal at the cost of order.
--- Iterate in order with `ipairs(list)` over indices `1`..`list.size`.
--- `List()` is equivalent to `List.new()`.
---@docs kind class
---@class Concord.List
---@field size integer Number of items in the List
---@field add fun(self: Concord.List, obj: any): Concord.List
---@field remove fun(self: Concord.List, obj: any): Concord.List|nil
---@field clear fun(self: Concord.List): Concord.List
---@field has fun(self: Concord.List, obj: any): boolean

local List = {}
List.__mt = {
   __index = List
}

--- Creates a new List.
---@return Concord.List list
function List.new()
   return setmetatable({
      size = 0,
   }, List.__mt)
end

--- Adds an object to the List.
--- Object must be of reference type
--- Object may not be the string 'size', 'onAdded' or 'onRemoved'
---@param obj any Object to add
---@return Concord.List list
function List:add(obj)
   local size = self.size + 1

   self[size] = obj
   self[obj]  = size
   self.size  = size

   if self.onAdded then self:onAdded(obj) end
   return self
end

--- Removes an object from the List.
---@param obj any Object to remove
---@return Concord.List|nil list Returns self if removed; nil if the object was not in the List
function List:remove(obj)
   local index = self[obj]
   if not index then return end
   local size  = self.size

   if index == size then
      self[size] = nil
   else
      local other = self[size]

      self[index] = other
      self[other] = index

      self[size] = nil
   end

   self[obj] = nil
   self.size = size - 1

   if self.onRemoved then self:onRemoved(obj) end
   return self
end

--- Clears the List completely.
--- Does not call onRemoved.
---@return Concord.List list
function List:clear()
   for i = 1, self.size do
      local o = self[i]

      self[o] = nil
      self[i] = nil
   end

   self.size = 0

   return self
end

--- Returns true if the List has the object.
---@param obj any Object to check for
---@return boolean has
function List:has(obj)
   return self[obj] and true or false
end

--- Returns the object at an index.
---@param i integer Index to get from
---@return any obj Object at the index
function List:get(i)
   return self[i]
end

--- Returns the index of an object in the List.
--- Errors if the object is not in the List.
---@param obj any Object to get index of
---@return integer index Index of the object in the List.
function List:indexOf(obj)
   if (not self[obj]) then
      error("bad argument #1 to 'List:indexOf' (Object was not in List)", 2)
   end

   return self[obj]
end

--- Sorts the List in place, using the order function.
--- The order function is passed to table.sort internally so documentation on table.sort can be used as reference.
---@param order fun(a: any, b: any): boolean Function that takes two items (a and b) and returns true if a should go before b.
---@return Concord.List list
function List:sort(order)
   table.sort(self, order)

   for key, obj in ipairs(self) do
      self[obj] = key
   end

   return self
end

--- ## Callbacks

--- Callback for when an item is added to the List.
---@param obj any Object that was added
function List:onAdded (obj) --luacheck: ignore
end

--- Callback for when an item is removed from the List.
--- Not called by List:clear.
---@param obj any Object that was removed
function List:onRemoved (obj) --luacheck: ignore
end

return setmetatable(List, {
   __call = function()
      return List.new()
   end,
})

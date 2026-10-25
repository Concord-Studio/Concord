--- An object in a World that holds Components processed by Systems.
--- Components are stored as fields named after the component (`entity.position` after `:give("position", ...)`).
--- Prefer `:give`, `:get`, and `:has` so unregistered names error instead of silently failing.
--- `Entity(...)` is equivalent to `Entity.new(...)`.
---@docs kind class
---@class Concord.Entity
---@field SERIALIZE_BY_DEFAULT boolean When true, `Entity.new` auto-`:give("serializable")` (see built-in Serializable)
---@field private __world? Concord.World
---@field has fun(self: Concord.Entity, name: string): boolean
---@field remove fun(self: Concord.Entity, name: string): Concord.Entity
---@module 'concord.entity'

local PATH = (...):gsub("%.[^%.]+$", "")

local Components = require(PATH .. ".components")
local Type = require(PATH .. ".type")
local Utils = require(PATH .. ".utils")

-- Initialize built-in Components (as soon as possible)
local Builtins = require(PATH .. ".builtins.init") --luacheck: ignore
-- Builtins is unused but the require already registers the Components

local Entity = {
	SERIALIZE_BY_DEFAULT = true,
}

Entity.__mt = {
	__index = Entity,
}

-- Internal: World binding (for World; keeps `__world` private to Entity).
function Entity.__getWorld(e)
	return e.__world
end

function Entity.__setWorld(e, world)
	e.__world = world
end

--- Creates a new Entity. Optionally queues it to be added to a World.
--- If Entity.SERIALIZE_BY_DEFAULT is true, the Entity is given a "serializable" Component.
---@param world? Concord.World World to add the entity to
---@return Concord.Entity entity
function Entity.new(world)
	if world ~= nil and not Type.isWorld(world) then
		Utils.error(2, "bad argument #1 to 'Entity.new' (world/nil expected, got %s)", type(world))
	end

	local e = setmetatable({
		__world = nil,

		__isEntity = true,
	}, Entity.__mt)

	if world then
		world:addEntity(e)
	end

	if Entity.SERIALIZE_BY_DEFAULT then
		e:give("serializable")
	end

	return e
end

local function createComponent(e, name, componentClass, ...)
	local component = componentClass:__initialize(e, ...)
	local hadComponent = not not e[name]

	if hadComponent then
		e[name]:removed(true)
	end

	e[name] = component

	if not hadComponent then
		e:__dirty()
	end
end

local function deserializeComponent(e, name, componentData)
	local componentClass = Components[name]
	local hadComponent = not not e[name]

	if hadComponent then
		e[name]:removed(true)
	end

	local component = componentClass:__new(e)
	component:deserialize(componentData)

	e[name] = component

	if not hadComponent then
		e:__dirty()
	end
end

local function giveComponent(e, ensure, name, ...)
	local component
	if Type.isComponent(name) then
		component = name
		name = component:getName()
	end

	if ensure and e[name] then
		return e
	end

	local ok, componentClass = Components.try(name)

	if not ok then
		Utils.error(3, "bad argument #1 to 'Entity:%s' (%s)", ensure and "ensure" or "give", componentClass)
	end

	if component then
		local data = component:deserialize()
		if data == nil then
			Utils.error(
				3,
				"bad argument #1 to 'Entity:$s' (Component '%s' couldn't be deserialized)",
				ensure and "ensure" or "give",
				name
			)
		end

		deserializeComponent(e, name, data)
	else
		createComponent(e, name, componentClass, ...)
	end

	return e
end

local function removeComponent(e, name)
	if e[name] then
		e[name]:removed(false)

		e[name] = nil

		e:__dirty()
	end
end

--- Gives an Entity a Component.
--- If the Component already exists, it's overridden by this new Component.
---@see Concord.Component#removed
---@overload fun(self: Concord.Entity, component: Concord.Component): Concord.Entity
--- Pass an existing Component instance (already populated, not attached to an entity). Skips name and populate arguments.
---@param name string Name of the ComponentClass
---@param ... any Additional arguments to pass to the Component's populate function
---@return Concord.Entity entity
--[[@usage
Concord.Component("position", function (component, x, y)
  component.x = x or 0
  component.y = y or 0
end)

entity:give("position", 10, 20) -- 10 and 20 are passed to populate after `component`
]]
function Entity:give(name, ...)
	return giveComponent(self, false, name, ...)
end

--- Ensures an Entity has a Component.
--- If the Component already exists, no action is taken.
---@overload fun(self: Concord.Entity, component: Concord.Component): Concord.Entity
--- Pass an existing Component instance (already populated, not attached to an entity). Skips name and populate arguments.
---@param name string Name of the ComponentClass
---@param ... any Additional arguments to pass to the Component's populate function
---@return Concord.Entity entity
function Entity:ensure(name, ...)
	return giveComponent(self, true, name, ...)
end

--- Removes a Component from an Entity.
---@see Concord.Component#removed
---@param name string Name of the ComponentClass to remove
---@return Concord.Entity entity
function Entity:remove(name)
	local ok, componentClass = Components.try(name)

	if not ok then
		Utils.error(2, "bad argument #1 to 'Entity:remove' (%s)", componentClass)
	end

	removeComponent(self, name)

	return self
end

--- Assembles an Entity by calling `assemblage(self, ...)` and returning `self`.
---@param assemblage fun(entity: Concord.Entity, ...) Function that will assemble an entity
---@param ... any Additional arguments to pass to the assemblage function.
---@return Concord.Entity entity
function Entity:assemble(assemblage, ...)
	if type(assemblage) ~= "function" then
		Utils.error(2, "bad argument #1 to 'Entity:assemble' (function expected, got %s)", type(assemblage))
	end

	assemblage(self, ...)

	return self
end

--- Destroys the Entity.
--- Queues removal from its World if it's in one. The Entity stays in the World until the next flush.
---@return Concord.Entity entity
function Entity:destroy()
	if self.__world then
		self.__world:removeEntity(self)
	end

	return self
end

-- Internal: Tells the World it's in that this Entity is dirty.
function Entity:__dirty()
	if self.__world then
		self.__world:__dirtyEntity(self)
	end

	return self
end

--- Returns true if the Entity has a Component.
---@param name string Name of the ComponentClass to check
---@return boolean has
function Entity:has(name)
	local ok, componentClass = Components.try(name)

	if not ok then
		Utils.error(2, "bad argument #1 to 'Entity:has' (%s)", componentClass)
	end

	return self[name] and true or false
end

--- Gets a Component from the Entity.
---@param name string Name of the ComponentClass to get
---@return Concord.Component|nil component The Component, or nil if the Entity does not have it
function Entity:get(name)
	local ok, componentClass = Components.try(name)

	if not ok then
		Utils.error(2, "bad argument #1 to 'Entity:get' (%s)", componentClass)
	end

	return self[name] --[[@as Concord.Component|nil]]
end

--- Returns a shallow copy of the Entity's fields, excluding __world and __isEntity.
--- This is primarily the Entity's Components. Extra non-component fields are also copied.
--- Mutating a copied Component still mutates the Entity's Component.
---@param output? table Table to copy into. A new table is created if omitted.
---@return table components
function Entity:getComponents(output)
	output = output or {}
	local components = Utils.shallowCopy(self, output)
	components.__world = nil
	components.__isEntity = nil

	return components
end

--- Returns true if the Entity has been assigned a World.
--- True as soon as addition is queued, and remains true until removal is flushed.
---@return boolean inWorld
function Entity:inWorld()
	return self.__world and true or false
end

--- Returns the World the Entity is in, or nil when not in a world.
---@return Concord.World|nil world
function Entity:getWorld()
	return self.__world
end

--- Serializes the Entity's Components.
--- Output shape: optional `key` field (key value) unless `ignoreKey`; other components as array entries
--- each with `__name` plus fields from `Component:serialize`. Components that return nil from serialize are omitted.
---@see Concord.SerializedWorld
---@param ignoreKey? boolean If true, the key Component is omitted (World:serialize uses the related flag `ignoreKeys`)
---@return table data Serialized Entity data
function Entity:serialize(ignoreKey)
	local data = {}

	---@cast self { [string]: Concord.Component }
	for name, component in pairs(self) do
		if Type.isComponent(component) then
         ---@type Concord.Component
         local comp = component

			-- The key component needs to be treated separately.
			if name == "key" and comp:getName() == "key" then
				if not ignoreKey then
					data.key = comp--[[@as {value: any}]].value
				end
			--We only care about components that were properly given to the entity
			elseif comp:getName() == name then
				local componentData = comp:serialize()

				if componentData ~= nil then
					componentData.__name = comp:getName()
					data[#data + 1] = componentData
				end
			end
		end
	end

	return data
end

--- Deserializes Components onto the Entity from the array portion of serialized data.
--- Component classes must already be registered. Does not restore `key`; `World:deserialize` handles keys separately.
---@see Concord.World#deserialize
---@param data table Serialized Entity data (array of component blobs; may include `.key` when loading outside World)
function Entity:deserialize(data)
	for i = 1, #data do
		local componentData = data[i]

		if not Components.has(componentData.__name) then
			Utils.error(
				2,
				"bad argument #1 to 'Entity:deserialize' (ComponentClass '%s' wasn't yet loaded)",
				tostring(componentData.__name)
			) -- luacheck: ignore
		end

		deserializeComponent(self, componentData.__name, componentData)
	end
end

return setmetatable(Entity, {
	__call = function(_, ...)
		return Entity.new(...)
	end,
})

--- All the built-in components.
---@docs index
---@docs kind module
---@docs title Overview
---@class Concord.Builtins
---@field serializable Concord.Serializable
---@field key Concord.Key

local PATH = (...):gsub("%.init$", "")

---@type Concord.Builtins
return {
	serializable = require(PATH .. ".serializable"),
	key = require(PATH .. ".key"),
}

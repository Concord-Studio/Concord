--- All the built-in components.
---@docs index
---@docs kind module
---@docs title Overview
---@class Builtins
---@field serializable Serializable
---@field key Key

local PATH = (...):gsub("%.init$", "")

---@type Builtins
return {
	serializable = require(PATH .. ".serializable"),
	key = require(PATH .. ".key"),
}

--- A feature-complete ECS library.
--- Entry point: `local Concord = require("concord")` (adjust the path to your package layout).
--- Exports `Entity`, `Component`, `Components`, `System`, `World`, `Type`, `utils`, and `builtins`.
--- Types are callable constructors, e.g. `Concord.World()`, `Concord.Entity(world)`.
--- Lowercase field names are deprecated compatibility aliases for the uppercase types.
---@docs index
---@docs kind module
---@class Concord
---@field Entity Entity
---@field Component Component
---@field Components Components
---@field System System
---@field World World
---@field Type Type
---@field utils Utils
---@field builtins Builtins
---@field entity Entity @deprecated Use Entity
---@field component Component @deprecated Use Component
---@field components Components @deprecated Use Components
---@field system System @deprecated Use System
---@field world World @deprecated Use World
---@field _VERSION string
---@field _DESCRIPTION string
---@field _LICENCE string

local PATH = (...):gsub("%.init$", "")

local Concord = {
	_VERSION = "3.0",
	_DESCRIPTION = "A feature-complete ECS library",
	_LICENCE = [[
      MIT LICENSE

      Copyright (c) 2020 Justin van der Leij / Tjakka5

      Permission is hereby granted, free of charge, to any person obtaining a
      copy of this software and associated documentation files (the
      "Software"), to deal in the Software without restriction, including
      without limitation the rights to use, copy, modify, merge, publish,
      distribute, sublicense, and/or sell copies of the Software, and to
      permit persons to whom the Software is furnished to do so, subject to
      the following conditions:

      The above copyright notice and this permission notice shall be included
      in all copies or substantial portions of the Software.

      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
      OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
      MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
      IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
      CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
      TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
      SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
   ]],
}

Concord.Entity = require(PATH .. ".entity")
Concord.Component = require(PATH .. ".component")
Concord.Components = require(PATH .. ".components")
Concord.System = require(PATH .. ".system")
Concord.World = require(PATH .. ".world")
Concord.Type = require(PATH .. ".type")
Concord.utils = require(PATH .. ".utils")
Concord.builtins = require(PATH .. ".builtins")

-- Compatibility aliases, deprecated in favor of uppercase names
Concord.entity = Concord.Entity
Concord.component = Concord.Component
Concord.components = Concord.Components
Concord.system = Concord.System
Concord.world = Concord.World

---@cast Concord Concord
return Concord

--!strict
-- Converts between layout-local (x, z on the floor plan) and world space.
local Layout = require(script.Parent.Parent.Config.LevelLayout)

local LayoutSpace = {}
local O = Layout.Origin
LayoutSpace.Origin = Vector3.new(O[1], O[2], O[3])

function LayoutSpace.ToWorld(x: number, y: number, z: number): Vector3
	return LayoutSpace.Origin + Vector3.new(x, y, z)
end

function LayoutSpace.ToLocal(p: Vector3): Vector3
	return p - LayoutSpace.Origin
end

return LayoutSpace

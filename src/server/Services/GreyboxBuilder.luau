--!strict
--[[
	Builds the Floor 4 East greybox from LevelLayout at server start (task F13), unless a
	hand-built Workspace.Map already exists. Grey blocks only: no final art until the M1 gate.
	Everything gameplay needs is found later through CollectionService tags, not paths.
]]
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Layout = require(Shared.Config.LevelLayout)
local LayoutSpace = require(Shared.Util.LayoutSpace)

local GreyboxBuilder = {}

local H = Layout.Height
local T = Layout.WallThickness
local DW = Layout.DoorWidth
local DH = Layout.DoorHeight

local VOLUME_GROUP = "CellVolume"
-- Pathfinding rasterises modifier volumes onto a coarse voxel grid, so a volume flush with a wall
-- bleeds into the room next door. Insetting keeps a clean room's label out of the corridor beside it.
local VOLUME_INSET = 2
local WALL_COLOR = Color3.fromRGB(150, 150, 142)
local CEIL_COLOR = Color3.fromRGB(110, 110, 106)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color or WALL_COLOR
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function w(x: number, y: number, z: number): Vector3
	return LayoutSpace.ToWorld(x, y, z)
end

-- Builds one wall side (from..to along its run) with gaps for openings.
local function buildSide(
	parent: Instance,
	axis: "X" | "Z",
	at: number,
	inset: number,
	from: number,
	to: number,
	gaps: { { number } }
)
	table.sort(gaps, function(a, b)
		return a[1] < b[1]
	end)
	local cursor = from
	local function segment(a: number, b: number, y0: number, y1: number)
		if b - a < 0.05 or y1 - y0 < 0.05 then
			return
		end
		local mid = (a + b) / 2
		local ym = (y0 + y1) / 2
		if axis == "Z" then
			part(parent, "Wall", Vector3.new(b - a, y1 - y0, T), CFrame.new(w(mid, ym, at + inset)))
		else
			part(parent, "Wall", Vector3.new(T, y1 - y0, b - a), CFrame.new(w(at + inset, ym, mid)))
		end
	end
	for _, g in gaps do
		local g0, g1, top = g[1], g[2], g[3]
		segment(cursor, math.max(cursor, g0), 0, H)
		segment(math.max(cursor, g0), g1, top, H) -- lintel
		cursor = math.max(cursor, g1)
	end
	segment(cursor, to, 0, H)
end

local function openingsOn(cellId: string, axis: "X" | "Z", at: number): { { number } }
	local gaps = {}
	for _, o in Layout.Openings do
		if o.Kind ~= "Fake" and o.Axis == axis and o.At == at and table.find(o.Cells, cellId) then
			local width = o.Width or DW
			local top = if o.Kind == "Arch" then 9 else DH
			table.insert(gaps, { o.Center - width / 2, o.Center + width / 2, top })
		end
	end
	return gaps
end

local function buildCell(map: Instance, c: any)
	local r = c.Rect
	local model = Instance.new("Model")
	model.Name = "Cell_" .. c.Id
	model:SetAttribute("CellId", c.Id)
	model.Parent = map
	local sx, sz = r[3] - r[1], r[4] - r[2]
	local cx, cz = (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
	local fc = c.FloorColor or { 90, 90, 90 }

	local floor = part(
		model,
		"Floor",
		Vector3.new(sx, 1, sz),
		CFrame.new(w(cx, -0.5, cz)),
		Color3.fromRGB(fc[1], fc[2], fc[3])
	)
	floor:SetAttribute("CellId", c.Id)
	CollectionService:AddTag(floor, "CellFloor")
	part(model, "Ceiling", Vector3.new(sx, 1, sz), CFrame.new(w(cx, H + 0.5, cz)), CEIL_COLOR)

	buildSide(model, "Z", r[2], T / 2, r[1], r[3], openingsOn(c.Id, "Z", r[2]))
	buildSide(model, "Z", r[4], -T / 2, r[1], r[3], openingsOn(c.Id, "Z", r[4]))
	buildSide(model, "X", r[1], T / 2, r[2], r[4], openingsOn(c.Id, "X", r[1]))
	buildSide(model, "X", r[3], -T / 2, r[2], r[4], openingsOn(c.Id, "X", r[3]))

	-- Invisible volume carrying the pathfinding label. LodgerService prices each label by wear,
	-- which is how "it only walks where someone has walked" reaches PathfindingService.
	local vol = part(
		model,
		"Volume",
		Vector3.new(math.max(1, sx - 2 * VOLUME_INSET), H, math.max(1, sz - 2 * VOLUME_INSET)),
		CFrame.new(w(cx, H / 2, cz))
	)
	vol.Transparency = 1
	vol.CanCollide = false
	vol.CanTouch = false
	-- Left queryable so pathfinding sees the label; a collision group hides it from raycasts.
	vol.CollisionGroup = VOLUME_GROUP
	vol.AudioCanCollide = false
	vol:SetAttribute("CellId", c.Id)
	CollectionService:AddTag(vol, "CellVolume")
	local mod = Instance.new("PathfindingModifier")
	mod.Label = "Cell_" .. c.Id
	mod.Parent = vol

	if c.Tags and table.find(c.Tags, "Water") then
		local water = part(
			model,
			"Water",
			Vector3.new(sx - 1, 0.3, sz - 1),
			CFrame.new(w(cx, 0.15, cz)),
			Color3.fromRGB(40, 60, 70)
		)
		water.Transparency = 0.4
		water.CanCollide = false
		water.CanQuery = false
		water.AudioCanCollide = false
	end
	return model
end

local function openingFrame(o: any, yCenter: number): CFrame
	if o.Axis == "Z" then
		return CFrame.new(w(o.Center, yCenter, o.At))
	else
		return CFrame.new(w(o.At, yCenter, o.Center)) * CFrame.Angles(0, math.rad(90), 0)
	end
end

local function buildOpening(map: Instance, o: any)
	if o.Kind == "Arch" then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Door_" .. o.Id
	model:SetAttribute("OpeningId", o.Id)
	model:SetAttribute("Kind", o.Kind)
	model:SetAttribute("Open", false)
	model:SetAttribute("Locked", o.Kind == "Lift" or o.Kind == "Fake")
	if o.Label then
		model:SetAttribute("Label", o.Label)
	end
	model.Parent = map

	local cf = openingFrame(o, DH / 2)
	local panel: Part
	if o.Kind == "Fake" then
		-- Slab on the corridor face of a solid wall; which face depends on the side the corridor is on.
		local corridorRect = nil
		for _, c in Layout.Cells do
			if c.Id == o.Cells[1] then
				corridorRect = c.Rect
			end
		end
		local sign = 1
		if corridorRect and o.Axis == "Z" and o.At == corridorRect[4] then
			sign = -1
		end
		panel = part(
			model,
			"Panel",
			Vector3.new(DW - 0.6, DH - 0.2, 0.3),
			cf * CFrame.new(0, 0, sign * (T + 0.15)),
			Color3.fromRGB(92, 70, 52)
		)
	elseif o.Kind == "Plastic" then
		panel = part(model, "Panel", Vector3.new(DW, DH, 0.1), cf, Color3.fromRGB(220, 225, 230))
		panel.Transparency = 0.45
		panel.Material = Enum.Material.Glass
		panel.AudioCanCollide = false
	elseif o.Kind == "Lift" then
		panel = part(model, "Panel", Vector3.new(DW, DH, 0.4), cf, Color3.fromRGB(150, 155, 160))
		panel.Material = Enum.Material.DiamondPlate
	else
		panel = part(model, "Panel", Vector3.new(DW - 0.2, DH - 0.1, 0.35), cf, Color3.fromRGB(92, 70, 52))
	end
	panel:SetAttribute("ClosedCFrame", panel.CFrame)
	model.PrimaryPart = panel
	-- Paths may run through closed doors; the Lodger opens them as it reaches them.
	if o.Kind == "Door" then
		local pm = Instance.new("PathfindingModifier")
		pm.PassThrough = true
		pm.Parent = panel
	end
	CollectionService:AddTag(model, "Door")
end

local function buildPoint(map: Instance, pt: any)
	local pos = w(pt.Pos[1], pt.Pos[2], pt.Pos[3])
	local kind = pt.Kind
	if kind == "Spawn" then
		local s = Instance.new("SpawnLocation")
		s.Name = "Spawn"
		s.Anchored = true
		s.Size = Vector3.new(4, 0.2, 4)
		s.CFrame = CFrame.new(pos - Vector3.new(0, pt.Pos[2] - 0.1, 0)) * CFrame.Angles(0, math.rad(-90), 0)
		s.Transparency = 1
		s.CanCollide = false
		s.Duration = 0
		s.Neutral = true
		s.Parent = map
		CollectionService:AddTag(s, "Checkpoint")
		return
	end
	if kind == "LodgerHome" then
		local a = part(map, "LodgerHome", Vector3.new(1, 1, 1), CFrame.new(pos))
		a.Transparency = 1
		a.CanCollide = false
		a.CanQuery = false
		CollectionService:AddTag(a, "LodgerHome")
		return
	end
	if kind == "Fluorescent" or kind == "Lamp" or kind == "Sodium" then
		local fixture = part(
			map,
			kind,
			if kind == "Fluorescent" then Vector3.new(4, 0.3, 0.8) else Vector3.new(0.8, 0.8, 0.8),
			CFrame.new(pos)
		)
		fixture.CanCollide = false
		fixture.CastShadow = false
		local working = pt.Data == nil or pt.Data.Working ~= false
		local light: Light
		if kind == "Fluorescent" then
			local l = Instance.new("SurfaceLight")
			l.Face = Enum.NormalId.Bottom
			l.Angle = 120
			l.Range = 16
			l.Brightness = 1.1
			l.Color = Color3.fromRGB(205, 225, 220)
			light = l
			fixture.Material = if working then Enum.Material.Neon else Enum.Material.SmoothPlastic
			fixture.Color = Color3.fromRGB(200, 215, 210)
		elseif kind == "Lamp" then
			local l = Instance.new("PointLight")
			l.Range = 14
			l.Brightness = 0.9
			l.Color = Color3.fromRGB(255, 190, 120)
			light = l
		else
			local l = Instance.new("SpotLight")
			l.Face = Enum.NormalId.Right
			l.Angle = 60
			l.Range = 24
			l.Brightness = 1.4
			l.Color = Color3.fromRGB(255, 150, 60)
			light = l
		end
		light.Shadows = kind ~= "Fluorescent"
		light.Enabled = working
		light.Parent = fixture
		fixture:SetAttribute("CellId", pt.Cell)
		CollectionService:AddTag(fixture, "RoomLight")
		return
	end
	-- Interactables: notes, tapes, items, fuse box.
	local sizes = {
		Note = Vector3.new(0.2, 1.4, 1),
		Tape = Vector3.new(1.2, 0.5, 0.8),
		Item = Vector3.new(0.5, 0.5, 1),
		FuseBox = Vector3.new(2, 2.6, 0.6),
	}
	local colors = {
		Note = Color3.fromRGB(230, 225, 205),
		Tape = Color3.fromRGB(40, 40, 44),
		Item = Color3.fromRGB(210, 170, 60),
		FuseBox = Color3.fromRGB(70, 80, 70),
	}
	local p = part(map, pt.Id, sizes[kind] or Vector3.new(1, 1, 1), CFrame.new(pos), colors[kind])
	p.CanCollide = kind == "FuseBox"
	p:SetAttribute("InteractKind", kind)
	p:SetAttribute("PointId", pt.Id)
	p:SetAttribute("CellId", pt.Cell)
	if pt.Data then
		for k, v in pt.Data do
			p:SetAttribute(k, v)
		end
	end
	CollectionService:AddTag(p, "Interactable")
end

local function setupLighting()
	-- LightingStyle / PrioritizeLightingQuality replaced Lighting.Technology (Unified Lighting).
	-- pcall because S5 has not yet confirmed they are script-writable.
	pcall(function()
		(Lighting :: any).LightingStyle = Enum.LightingStyle.Realistic
	end)
	pcall(function()
		(Lighting :: any).PrioritizeLightingQuality = true
	end)
	Lighting.Ambient = Color3.fromRGB(5, 5, 6)
	Lighting.OutdoorAmbient = Color3.fromRGB(8, 8, 9)
	Lighting.Brightness = 0
	Lighting.ClockTime = 0
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0.1
	Lighting.ExposureCompensation = 0
	local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atm.Density = 0.32
	atm.Haze = 0.6
	atm.Glare = 0
	atm.Offset = 0
	atm.Color = Color3.fromRGB(30, 34, 36)
	atm.Decay = Color3.fromRGB(10, 12, 14)
	atm.Parent = Lighting
	local cc = Lighting:FindFirstChild("Grade") :: ColorCorrectionEffect?
		or Instance.new("ColorCorrectionEffect")
	cc.Name = "Grade"
	cc.Saturation = -0.35
	cc.Contrast = 0.12
	cc.TintColor = Color3.fromRGB(225, 238, 235)
	cc.Parent = Lighting
	pcall(function()
		(SoundService :: any).AcousticSimulationEnabled = true
	end)
end

function GreyboxBuilder:Init()
	setupLighting()
	-- Cell volumes must never block rays (sight, interaction, audio occlusion) or bodies.
	pcall(function()
		PhysicsService:RegisterCollisionGroup(VOLUME_GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(VOLUME_GROUP, "Default", false)
	if Workspace:FindFirstChild("Map") then
		return -- a hand-built map takes precedence
	end
	local base = Workspace:FindFirstChild("Baseplate")
	if base then
		base:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "Map"
	for _, c in Layout.Cells do
		buildCell(map, c)
	end
	for _, o in Layout.Openings do
		buildOpening(map, o)
	end
	for _, wd in Layout.ExtraWalls do
		local len = wd.To - wd.From
		local mid = (wd.From + wd.To) / 2
		if wd.Axis == "X" then
			part(map, "Chicane", Vector3.new(T, H, len), CFrame.new(w(wd.At, H / 2, mid)))
		else
			part(map, "Chicane", Vector3.new(len, H, T), CFrame.new(w(mid, H / 2, wd.At)))
		end
	end
	for _, pt in Layout.Points do
		buildPoint(map, pt)
	end
	map.Parent = Workspace
end

return GreyboxBuilder

--!strict
--[[
	Shows wear diegetically (plan §D.1): scuffed footprints in the dust. Each footstep leaves a print,
	and every print in a cell fades with that cell's wear, so clean dust really looks clean.
	Client-only, pooled, capped per quality tier.
	TODO(art pass): decal texture + reveal only in grazing flashlight light.
]]
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CellGraph = require(Shared.Logic.CellGraph)
local Layout = require(Shared.Config.LevelLayout)
local LayoutSpace = require(Shared.Util.LayoutSpace)
local Net = require(Shared.Net)
local WearMath = require(Shared.Logic.WearMath)

local FootprintController = {}

type Print = { Part: Part, Cell: string }
local graph = CellGraph.Build(Layout)
local prints: { Print } = {}
local pool: { Part } = {}
local wear: { [string]: number } = {}
local side: { [Model]: number } = {}
local folder: Folder
local Settings: any
local Movement: any

local function alphaFor(cell: string): number
	local w = wear[cell] or 0
	-- Invisible on clean dust, clearly scuffed from about 0.5 wear.
	return 1 - math.clamp(w * 1.5, 0, 0.7)
end

local function take(): Part
	local p = table.remove(pool)
	if p then
		return p
	end
	local n = Instance.new("Part")
	n.Name = "Footprint"
	n.Anchored = true
	n.CanCollide = false
	n.CanQuery = false
	n.CanTouch = false
	n.CastShadow = false
	n.AudioCanCollide = false
	n.Material = Enum.Material.SmoothPlastic
	n.Color = Color3.fromRGB(38, 36, 33)
	n.Size = Vector3.new(0.55, 0.04, 1.1)
	return n
end

local function onStep(character: Model, foot: Vector3)
	local l = LayoutSpace.ToLocal(foot)
	local cell = CellGraph.CellAt(graph, l.X, l.Z)
	if not cell then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local s = (side[character] or 1) * -1
	side[character] = s
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.01 then
		return
	end
	local floorY = LayoutSpace.Origin.Y + 0.03
	local base =
		CFrame.lookAt(Vector3.new(foot.X, floorY, foot.Z), Vector3.new(foot.X, floorY, foot.Z) + look.Unit)
	local p = take()
	p.CFrame = base * CFrame.new(s * 0.45, 0, 0)
	p.Transparency = alphaFor(cell)
	p.Parent = folder
	table.insert(prints, { Part = p, Cell = cell })
	local cap = Settings.Tier.FootprintCap
	while #prints > cap do
		local old = table.remove(prints, 1) :: Print
		old.Part.Parent = nil
		table.insert(pool, old.Part)
	end
end

function FootprintController:Init(registry)
	Settings = registry.SettingsController
	Movement = registry.MovementController
	local f = Instance.new("Folder")
	f.Name = "Footprints"
	f.Parent = Workspace
	folder = f
end

function FootprintController:Start()
	Movement.Step:Connect(onStep)
	Net.OnClient("WearSnapshot", function(bytes: { [string]: number })
		for id, b in bytes do
			wear[id] = WearMath.FromByte(b)
		end
		for _, pr in prints do
			pr.Part.Transparency = alphaFor(pr.Cell)
		end
	end)
end

function FootprintController:GetWear(cell: string): number
	return wear[cell] or 0
end

return FootprintController

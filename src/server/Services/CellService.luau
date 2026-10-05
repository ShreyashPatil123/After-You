--!strict
-- Knows which cell (room / corridor segment) every player is in.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CellGraph = require(Shared.Logic.CellGraph)
local Layout = require(Shared.Config.LevelLayout)
local LayoutSpace = require(Shared.Util.LayoutSpace)
local Signal = require(Shared.Util.Signal)

local CellService = {}
CellService.Graph = CellGraph.Build(Layout)
CellService.CellChanged = Signal.new() :: Signal.Signal<Player, string?, string?>

local current: { [Player]: string? } = {}
local PlayerService: any

function CellService:CellAt(worldPos: Vector3): string?
	local l = LayoutSpace.ToLocal(worldPos)
	if l.Y < -2 or l.Y > Layout.Height + 2 then
		return nil
	end
	return CellGraph.CellAt(self.Graph, l.X, l.Z)
end

function CellService:GetCell(player: Player): string?
	return current[player]
end

function CellService:PlayersIn(cellId: string): { Player }
	local out = {}
	for p, c in current do
		if c == cellId then
			table.insert(out, p)
		end
	end
	return out
end

function CellService:HasTag(cellId: string, tag: string): boolean
	return CellGraph.HasTag(self.Graph, cellId, tag)
end

function CellService:Tags(cellId: string?): { string }
	local c = cellId and self.Graph.Cells[cellId]
	return (c and c.Tags) or {}
end

function CellService:Init(registry)
	PlayerService = registry.PlayerService
end

function CellService:Start()
	Players.PlayerRemoving:Connect(function(p)
		current[p] = nil
	end)
	while true do
		for _, p in Players:GetPlayers() do
			local root = PlayerService:GetRoot(p)
			local cell = if root and PlayerService:IsAlive(p) then self:CellAt(root.Position) else nil
			local old = current[p]
			if cell ~= old then
				current[p] = cell
				p:SetAttribute("Cell", cell)
				CellService.CellChanged:Fire(p, old, cell)
			end
		end
		task.wait(0.2)
	end
end

return CellService

--!strict
--[[
	Records every player's recent history (plan §D.2) so the Director can replay it as echoes and
	the Lodger can walk it. Positions are stored layout-local; actions reference a sample index.
]]
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local EchoCodec = require(Shared.Logic.EchoCodec)
local EchoConfig = require(Shared.Config.EchoConfig)
local LayoutSpace = require(Shared.Util.LayoutSpace)
local RingBuffer = require(Shared.Util.RingBuffer)

type Sample = EchoCodec.Sample
type Record = {
	Samples: RingBuffer.RingBuffer<Sample>,
	Actions: { { Total: number, Kind: number, Id: string } }, -- Total = sample count when it happened
}

local EchoService = {}
EchoService.Kind = EchoCodec.ActionKind

local records: { [Player]: Record } = {}
local PlayerService: any

local interval = 1 / EchoConfig.SampleHz
local capacity = math.ceil(EchoConfig.HistorySeconds * EchoConfig.SampleHz)

local function record(player: Player): Record
	local r = records[player]
	if not r then
		r = { Samples = RingBuffer.new(capacity), Actions = {} }
		records[player] = r
	end
	return r
end

function EchoService:HistorySeconds(player: Player): number
	local r = records[player]
	return if r then r.Samples:Size() * interval else 0
end

function EchoService:LogAction(player: Player, kind: number, id: string)
	local r = record(player)
	table.insert(r.Actions, { Total = r.Samples.Total, Kind = kind, Id = id })
	-- Drop actions older than retained history.
	local oldest = r.Samples.Total - r.Samples:Size()
	while r.Actions[1] and r.Actions[1].Total < oldest do
		table.remove(r.Actions, 1)
	end
end

-- Ring index (1 = oldest) for a moment `ago` seconds in the past, or nil if outside history.
local function indexAgo(r: Record, ago: number): number?
	local n = r.Samples:Size()
	local i = n - math.floor(ago / interval)
	if i < 1 or i > n then
		return nil
	end
	return i
end

-- Path covering [ago, ago - duration] (older to newer).
function EchoService:Segment(player: Player, ago: number, duration: number): EchoCodec.Path?
	local r = records[player]
	if not r then
		return nil
	end
	local first = indexAgo(r, ago)
	if not first then
		return nil
	end
	local n = r.Samples:Size()
	local last = math.min(n, first + math.floor(duration / interval))
	local samples = {}
	for i = first, last do
		table.insert(samples, r.Samples:Get(i) :: Sample)
	end
	-- Convert ring positions to sample Totals to slice the action log.
	local base = r.Samples.Total - n -- Total value of the sample before ring index 1
	local actions = {}
	for _, a in r.Actions do
		local ringIndex = a.Total - base
		if ringIndex >= first and ringIndex <= last then
			table.insert(actions, { Index = ringIndex - first + 1, Kind = a.Kind, Id = a.Id })
		end
	end
	return { Interval = interval, Quantum = EchoConfig.Quantum, Samples = samples, Actions = actions }
end

-- Latest action of `kind` between minAgo and maxAgo seconds ago.
function EchoService:FindAction(
	player: Player,
	kinds: { number },
	minAgo: number,
	maxAgo: number
): (string?, number?)
	local r = records[player]
	if not r then
		return nil, nil
	end
	local total = r.Samples.Total
	for i = #r.Actions, 1, -1 do
		local a = r.Actions[i]
		local ago = (total - a.Total) * interval
		if ago > maxAgo then
			break
		end
		if ago >= minAgo and table.find(kinds, a.Kind) then
			return a.Id, ago
		end
	end
	return nil, nil
end

--[[
	Finds a stretch of history the viewer could see from where they stand now: the first sample of the
	stretch must be between minDist and maxDist away (world studs) and pass `visible(worldPos)`.
	Returns how long ago that stretch starts.
]]
function EchoService:FindVisibleStretch(
	player: Player,
	minAgo: number,
	maxAgo: number,
	viewer: Vector3,
	minDist: number,
	maxDist: number,
	visible: (Vector3) -> boolean,
	filter: ((Sample) -> boolean)?
): number?
	local r = records[player]
	if not r then
		return nil
	end
	local n = r.Samples:Size()
	local step = math.max(1, math.floor(1 / interval)) -- test once per second of history
	local startAgo = math.min(maxAgo, (n - 1) * interval)
	local ago = startAgo
	while ago >= minAgo do
		local i = indexAgo(r, ago)
		if i then
			local s = r.Samples:Get(i) :: Sample
			if filter == nil or filter(s) then
				local wp = LayoutSpace.ToWorld(s.X, s.Y, s.Z)
				local d = (wp - viewer).Magnitude
				if d >= minDist and d <= maxDist and visible(wp) then
					return ago
				end
			end
		end
		ago -= step * interval
	end
	return nil
end

function EchoService:Encode(path: EchoCodec.Path): buffer
	return EchoCodec.Encode(path)
end

function EchoService:Init(registry)
	PlayerService = registry.PlayerService
	local Interaction = registry.InteractionService
	Interaction.Action:Connect(function(player: Player, kind: number, id: string)
		EchoService:LogAction(player, kind, id)
	end)
	PlayerService.FlashlightChanged:Connect(function(player: Player, on: boolean)
		EchoService:LogAction(
			player,
			if on then EchoCodec.ActionKind.FlashOn else EchoCodec.ActionKind.FlashOff,
			""
		)
	end)
	Players.PlayerRemoving:Connect(function(p)
		records[p] = nil
	end)
end

function EchoService:Start()
	local F = EchoCodec.Flags
	while true do
		task.wait(interval)
		for _, p in Players:GetPlayers() do
			local root = PlayerService:GetRoot(p)
			if root and PlayerService:IsAlive(p) then
				local l = LayoutSpace.ToLocal(root.Position)
				local look = root.CFrame.LookVector
				local yaw = math.atan2(-look.X, -look.Z)
				local flags = 0
				if PlayerService:IsFlashlightOn(p) then
					flags += F.Flashlight
				end
				local stance = PlayerService:GetStance(p)
				if stance == "Run" then
					flags += F.Running
				elseif stance == "Crouch" then
					flags += F.Crouching
				end
				record(p).Samples:Push({ X = l.X, Y = l.Y, Z = l.Z, Yaw = yaw, Flags = flags })
			end
		end
	end
end

return EchoService

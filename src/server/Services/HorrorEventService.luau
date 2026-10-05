--!strict
--[[
	Turns an event definition into a concrete payload for one player and sends it (plan §J.3).
	Builders are per Category, so a new event of an existing category is a data file only.
	The Director decides *when*; this service decides *what exactly* and whether it can happen now.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local EchoCodec = require(Shared.Logic.EchoCodec)
local Events = require(Shared.Events)
local LayoutSpace = require(Shared.Util.LayoutSpace)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

type EventDef = any
type Payload = { [string]: any }

local HorrorEventService = {}
HorrorEventService.Defs = Events :: { EventDef }
HorrorEventService.Played = Signal.new() :: Signal.Signal<Player, EventDef, Payload>

local byId: { [string]: EventDef } = {}
for _, d in Events do
	byId[d.Id] = d
end

local PlayerService: any
local EchoService: any
local InteractionService: any
local LodgerService: any
local nextToken = 0
local pending: { [number]: { player: Player, id: string } } = {}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

-- Is world point `p` visible from the player's head (walls and closed doors block)?
local function visibleFrom(player: Player, p: Vector3): boolean
	local head = PlayerService:GetHead(player)
	if not head then
		return false
	end
	local exclude = {}
	for _, pl in Players:GetPlayers() do
		if pl.Character then
			table.insert(exclude, pl.Character)
		end
	end
	local dyn = Workspace:FindFirstChild("Dynamic")
	if dyn then
		table.insert(exclude, dyn)
	end
	rayParams.FilterDescendantsInstances = exclude
	local target = p + Vector3.new(0, 1.5, 0)
	local dir = target - head.Position
	return Workspace:Raycast(head.Position, dir, rayParams) == nil
end
HorrorEventService.VisibleFrom = visibleFrom

local Builders: { [string]: (Player, EventDef) -> Payload? } = {}

Builders.EchoSound = function(_player, def)
	return { Duration = def.Params.Duration, Lag = def.Params.Lag }
end

Builders.EchoObject = function(player, def)
	local P = def.Params
	local K = EchoCodec.ActionKind
	local id, ago = EchoService:FindAction(player, { K.DoorOpen, K.DoorClose }, P.MinAgo, P.MaxAgo)
	if not id then
		return nil
	end
	local door = InteractionService:FindDoor(id)
	local head = PlayerService:GetHead(player)
	if not door or not head or door:GetAttribute("Kind") ~= "Door" then
		return nil
	end
	local d = (door:GetPivot().Position - head.Position).Magnitude
	if d > P.MaxDistance or d < P.MinDistance then
		return nil
	end
	return { Opening = id, Ago = ago }
end

local function stretchPayload(player: Player, def: EventDef, filter: ((any) -> boolean)?): Payload?
	local P = def.Params
	local head = PlayerService:GetHead(player)
	if not head then
		return nil
	end
	local ago = EchoService:FindVisibleStretch(
		player,
		P.MinAgo,
		P.MaxAgo,
		head.Position,
		P.MinDistance,
		P.MaxDistance,
		function(wp)
			return visibleFrom(player, wp)
		end,
		filter
	)
	if not ago then
		return nil
	end
	local path = EchoService:Segment(player, ago, P.Duration)
	if not path or #path.Samples < 4 then
		return nil
	end
	return { Path = EchoService:Encode(path), UserId = player.UserId, Origin = LayoutSpace.Origin }
end

Builders.EchoLight = function(player, def)
	return stretchPayload(player, def, function(s)
		return bit32.band(s.Flags, EchoCodec.Flags.Flashlight) ~= 0
	end)
end

Builders.EchoFigure = function(player, def)
	return stretchPayload(player, def, nil)
end

Builders.Silence = function(_player, def)
	return { Duration = def.Params.Duration }
end

Builders.Fake = function(player, def)
	local P = def.Params
	local pos: Vector3
	if P.Opening then
		local door = InteractionService:FindDoor(P.Opening)
		if not door then
			return nil
		end
		pos = door:GetPivot().Position
	elseif P.Above then
		local root = PlayerService:GetRoot(player)
		if not root then
			return nil
		end
		pos = root.Position + Vector3.new(0, 12, 0)
	else
		return nil
	end
	return { Sound = P.Sound, Position = pos, Repeat = P.Repeat or 1 }
end

Builders.Lodger = function(player, def)
	local ok = LodgerService:Wake(player, def.Params.First == true)
	if not ok then
		return nil
	end
	if def.Params.LightsOut then
		for _, fixture in CollectionService:GetTagged("RoomLight") do
			if table.find(def.Params.LightsOut, fixture:GetAttribute("CellId")) then
				local light = fixture:FindFirstChildWhichIsA("Light")
				if light and light.Enabled then
					light.Enabled = false
					fixture:SetAttribute("CutByLodger", true)
				end
			end
		end
	end
	return { First = def.Params.First }
end

Builders.LiftKnock = function(player, def)
	local lift = InteractionService:FindDoor("LiftDoor")
	if not lift then
		return nil
	end
	-- Your own knock on 4A, replayed on the lift door from the lobby side.
	local knocked = EchoService:FindAction(player, { EchoCodec.ActionKind.Knock }, 0, 1e9) ~= nil
	InteractionService:SetDoorOpen(lift, false)
	return {
		Delay = def.Params.Delay,
		Position = lift:GetPivot().Position - Vector3.new(1.5, 0, 0),
		Repeat = if knocked then 2 else 3,
	}
end

function HorrorEventService:Get(id: string): EventDef?
	return byId[id]
end

-- Builds and sends an event to one player. Returns true if it actually played.
function HorrorEventService:Play(player: Player, def: EventDef): boolean
	local builder = Builders[def.Category]
	if not builder then
		warn("[HorrorEvent] no builder for category " .. tostring(def.Category))
		return false
	end
	local ok, payload = pcall(builder, player, def)
	if not ok then
		warn("[HorrorEvent] " .. def.Id .. " failed: " .. tostring(payload))
		return false
	end
	if payload == nil then
		return false
	end
	nextToken += 1
	payload.Token = nextToken
	payload.Id = def.Id
	payload.Category = def.Category
	pending[nextToken] = { player = player, id = def.Id }
	Net.Fire(player, "EventPlay", payload)
	HorrorEventService.Played:Fire(player, def, payload)
	return true
end

function HorrorEventService:PlayScripted(id: string, player: Player): boolean
	local def = byId[id]
	assert(def, "unknown event " .. id)
	return self:Play(player, def)
end

-- Restores lights cut by a Lodger event (called when it withdraws).
function HorrorEventService:RestoreLights()
	for _, fixture in CollectionService:GetTagged("RoomLight") do
		if fixture:GetAttribute("CutByLodger") then
			fixture:SetAttribute("CutByLodger", nil)
			local light = fixture:FindFirstChildWhichIsA("Light")
			if light then
				light.Enabled = true
			end
		end
	end
end

function HorrorEventService:Init(registry)
	PlayerService = registry.PlayerService
	EchoService = registry.EchoService
	InteractionService = registry.InteractionService
	LodgerService = registry.LodgerService
	Net.OnServer("EventFeedback", function(player, token: number, noticed: boolean)
		local p = pending[token]
		if p and p.player == player then
			pending[token] = nil
			registry.AnalyticsService:Log(player, "EventFeedback", { Id = p.id, Noticed = noticed })
		end
	end)
end

return HorrorEventService

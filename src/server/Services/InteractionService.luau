--!strict
--[[
	Validates every interaction (plan §G.3: never trust the client) and owns door state.
	Doors: the server owns Open/Locked and collision; clients animate the panel locally.
]]
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local EchoCodec = require(Shared.Logic.EchoCodec)
local Net = require(Shared.Net)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local Signal = require(Shared.Util.Signal)

local InteractionService = {}
-- (player, EchoCodec.ActionKind, id)
InteractionService.Action = Signal.new() :: Signal.Signal<Player, number, string>
-- (player | nil, worldPosition, loudness 0..1, reason) for the Lodger's hearing
InteractionService.Noise = Signal.new() :: Signal.Signal<Player?, Vector3, number, string>
-- (player, interactable part) for objective logic
InteractionService.Used = Signal.new() :: Signal.Signal<Player, BasePart>

local PLASTIC_CUT_SECONDS = 1.6
local K = EchoCodec.ActionKind

local PlayerService: any
local holds: { [Player]: { target: Instance, started: number } } = {}

local function doorModel(target: Instance): Model?
	local m = target:IsA("Model") and target or target:FindFirstAncestorOfClass("Model")
	if m and CollectionService:HasTag(m, "Door") then
		return m :: Model
	end
	return nil
end

local function withinReach(player: Player, target: Instance): boolean
	local head = PlayerService:GetHead(player)
	if not head or not PlayerService:IsAlive(player) then
		return false
	end
	local pos: Vector3
	if target:IsA("BasePart") then
		pos = target.Position
	elseif target:IsA("Model") then
		pos = target:GetPivot().Position
	else
		return false
	end
	-- Generous margin over the client's reach for latency and part size.
	return (pos - head.Position).Magnitude <= PlayerConfig.InteractDistance + 4
end

function InteractionService:FindDoor(openingId: string): Model?
	for _, m in CollectionService:GetTagged("Door") do
		if m:GetAttribute("OpeningId") == openingId then
			return m :: Model
		end
	end
	return nil
end

function InteractionService:IsDoorClosed(openingId: string): boolean
	local m = self:FindDoor(openingId)
	if not m then
		return false -- arches have no door
	end
	return m:GetAttribute("Open") ~= true
end

function InteractionService:SetDoorOpen(model: Model, open: boolean)
	if model:GetAttribute("Open") == open then
		return
	end
	model:SetAttribute("Open", open)
	local panel = model.PrimaryPart
	if panel then
		panel.CanCollide = not open
		panel.CanQuery = not open
		panel.AudioCanCollide = not open
	end
end

function InteractionService:SetLocked(model: Model, locked: boolean)
	model:SetAttribute("Locked", locked)
end

local function sfx(sound: string, position: Vector3)
	Net.FireAll("EventPlay", { Category = "Sfx", Sound = sound, Position = position })
end

local function useDoor(player: Player, model: Model, action: string)
	local id = model:GetAttribute("OpeningId") :: string
	local kind = model:GetAttribute("Kind")
	local pos = model:GetPivot().Position
	if action == "Knock" then
		sfx("DoorKnock", pos)
		InteractionService.Action:Fire(player, K.Knock, id)
		InteractionService.Noise:Fire(player, pos, 0.6, "Knock")
		return
	end
	if kind == "Fake" or kind == "Plastic" then
		return -- fake doors never open; plastic needs the hold action
	end
	if model:GetAttribute("Locked") == true then
		sfx("DoorLocked", pos)
		return
	end
	local open = model:GetAttribute("Open") ~= true
	InteractionService:SetDoorOpen(model, open)
	sfx(if open then "DoorOpen" else "DoorClose", pos)
	InteractionService.Action:Fire(player, if open then K.DoorOpen else K.DoorClose, id)
	-- Running into a door is a slam.
	local loud = if PlayerService:GetStance(player) == "Run" then 0.8 else 0.25
	InteractionService.Noise:Fire(player, pos, loud, "Door")
end

function InteractionService:Init(registry)
	PlayerService = registry.PlayerService

	Net.OnServer("Interact", function(player, target: Instance, action: string)
		if not withinReach(player, target) then
			return
		end
		local door = doorModel(target)
		if door then
			if action == "Use" or action == "Knock" then
				useDoor(player, door, action)
			end
			return
		end
		if
			target:IsA("BasePart")
			and CollectionService:HasTag(target, "Interactable")
			and action == "Use"
		then
			InteractionService.Used:Fire(player, target)
		end
	end)

	Net.OnServer("HoldInteract", function(player, target: Instance, phase: string)
		if phase == "End" then
			holds[player] = nil
			return
		end
		local door = doorModel(target)
		if not door or door:GetAttribute("Kind") ~= "Plastic" or door:GetAttribute("Open") == true then
			return
		end
		if not withinReach(player, door) then
			return
		end
		local started = os.clock()
		holds[player] = { target = door, started = started }
		sfx("PlasticTear", door:GetPivot().Position)
		task.delay(PLASTIC_CUT_SECONDS, function()
			local h = holds[player]
			if h and h.target == door and h.started == started and withinReach(player, door) then
				holds[player] = nil
				InteractionService:SetDoorOpen(door, true)
				local panel = door.PrimaryPart
				if panel then
					panel.Transparency = 1
				end
				InteractionService.Action:Fire(player, K.DoorOpen, door:GetAttribute("OpeningId") :: string)
			end
		end)
	end)
end

return InteractionService

--!strict
--[[
	Slice objective (VERTICAL_SLICE_SPEC §2): two fuses -> fuse box -> lift -> payoff.
	Items and progress are shared by the whole server (co-op), and owned here.
]]
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local EchoCodec = require(Shared.Logic.EchoCodec)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Story = require(Shared.Config.Story)

local ObjectiveService = {}
ObjectiveService.FlagSet = Signal.new() :: Signal.Signal<string, Player?>

local flags: { [string]: boolean } = {}
local fusesHeld = 0
local fusesNeeded = 2
local InteractionService: any
local CellService: any
local HorrorEventService: any

function ObjectiveService:GetFlags(): { [string]: boolean }
	return flags
end

function ObjectiveService:SetFlag(name: string, player: Player?)
	if flags[name] then
		return
	end
	flags[name] = true
	ObjectiveService.FlagSet:Fire(name, player)
end

-- 0..1 progress through the slice, used by the Director's MinProgress gates.
function ObjectiveService:Progress(): number
	local p = 0
	if flags.ReadClipboard then
		p += 0.1
	end
	if flags.HasTape01 then
		p += 0.2
	end
	p += 0.25 * math.min(fusesHeld + (if flags.Powered then fusesNeeded else 0), fusesNeeded)
	if flags.Powered then
		p = 1
	end
	return math.min(p, 1)
end

local function objectiveText(): string
	if flags.Powered then
		return Story.Objectives.TakeLift
	elseif fusesHeld >= fusesNeeded then
		return Story.Objectives.PowerLift
	end
	return Story.Objectives.FindFuses
end

local function broadcast(target: Player?)
	local payload = {
		Text = objectiveText(),
		Fuses = fusesHeld,
		Needs = fusesNeeded,
		Visible = flags.ReadClipboard == true,
	}
	if target then
		Net.Fire(target, "Objective", payload)
	else
		Net.FireAll("Objective", payload)
	end
end

local function onUsed(player: Player, part: BasePart)
	local kind = part:GetAttribute("InteractKind")
	if kind == "Note" then
		local id = part:GetAttribute("NoteId") :: string
		Net.Fire(player, "Subtitle", { Kind = "Note", Text = Story.Notes[id] or "" })
		if id == "Clipboard" then
			ObjectiveService:SetFlag("ReadClipboard", player)
			broadcast(nil)
		end
	elseif kind == "Tape" then
		local id = part:GetAttribute("TapeId") :: string
		local lines = Story.Tapes[id]
		if lines then
			-- Everyone near hears a tape; send to all, clients filter by distance via the emitter.
			Net.FireAll(
				"Subtitle",
				{ Kind = "Tape", Speaker = "Theo (tape)", Lines = lines, Position = part.Position }
			)
			ObjectiveService:SetFlag("Has" .. id, player)
		end
	elseif kind == "Item" and part:GetAttribute("ItemId") == "Fuse" then
		local pointId = part:GetAttribute("PointId") :: string
		part:Destroy()
		fusesHeld += 1
		InteractionService.Action:Fire(player, EchoCodec.ActionKind.Pickup, pointId)
		ObjectiveService:SetFlag(pointId, player)
		broadcast(nil)
	elseif kind == "FuseBox" then
		if flags.Powered then
			return
		end
		if fusesHeld >= fusesNeeded then
			fusesHeld = 0
			ObjectiveService:SetFlag("Powered", player)
			local lift = InteractionService:FindDoor("LiftDoor")
			if lift then
				InteractionService:SetLocked(lift, false)
				InteractionService:SetDoorOpen(lift, true)
			end
			Net.FireAll("EventPlay", { Category = "Sfx", Sound = "LiftPower", Position = part.Position })
			broadcast(nil)
		else
			Net.Fire(
				player,
				"Subtitle",
				{ Kind = "Hint", Text = string.format("Needs %d fuses.", fusesNeeded) }
			)
		end
	end
end

function ObjectiveService:Init(registry)
	InteractionService = registry.InteractionService
	CellService = registry.CellService
	HorrorEventService = registry.HorrorEventService
	InteractionService.Used:Connect(onUsed)
	Players.PlayerAdded:Connect(function(p)
		task.defer(broadcast, p)
	end)
	CellService.CellChanged:Connect(function(player: Player, old: string?, new: string?)
		-- Beat 13: stepping back out of 4D with the second fuse wakes the Lodger, once.
		if old == "R4D" and new == "CorrE" and flags.Fuse2 and not flags.MetLodger then
			ObjectiveService:SetFlag("MetLodger", player)
			HorrorEventService:PlayScripted("LodgerFirst", player)
		end
		-- Beat 18: entering the powered lift ends the slice.
		if new == "Lift" and flags.Powered and not flags.SliceEnded then
			ObjectiveService:SetFlag("SliceEnded", player)
			HorrorEventService:PlayScripted("LiftKnock", player)
			task.delay(9, function()
				Net.FireAll("SliceEnd", {})
			end)
		end
	end)
end

function ObjectiveService:Start()
	broadcast(nil)
end

return ObjectiveService

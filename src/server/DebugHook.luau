--!strict
--[[
	Studio-only test hook. Creates ServerStorage.AfterYouDebug (a BindableFunction) so playtest
	tooling can drive the slice from server-side code without a keyboard:
	  Invoke("State")                      -> wear, flags, lodger state/position, player cells
	  Invoke("Teleport", target)           -> move the first player to a cell id or layout point id
	  Invoke("Walk", cellId)               -> Humanoid:MoveTo the centre of a cell (wear accrues normally)
	  Invoke("Use", pointId)               -> act as if the first player used that interactable
	  Invoke("Force", eventIdOrPacing)     -> DirectorService:Force; true if the event actually played
	  Invoke("Door", openingId)            -> open a door, or cut plastic sheeting, instantly
	  Invoke("Wear", cellId, amount)       -> WearService:Add
	  Invoke("Wake")                       -> LodgerService:Wake(first player, true) -> ok, reason
	Never created outside Studio.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local LevelLayout = require(Shared.Config.LevelLayout)
local LayoutSpace = require(Shared.Util.LayoutSpace)
local EchoCodec = require(Shared.Logic.EchoCodec)

local DebugHook = {}

local function firstPlayer(): Player?
	return Players:GetPlayers()[1]
end

local function targetPos(id: string): Vector3?
	for _, c in LevelLayout.Cells do
		if c.Id == id then
			local r = c.Rect
			return LayoutSpace.ToWorld((r[1] + r[3]) / 2, 3, (r[2] + r[4]) / 2)
		end
	end
	for _, pt in LevelLayout.Points do
		if pt.Id == id then
			return LayoutSpace.ToWorld(pt.Pos[1], 3, pt.Pos[3])
		end
	end
	return nil
end

function DebugHook.Install(registry: { [string]: any })
	if not RunService:IsStudio() then
		return
	end
	local fn = Instance.new("BindableFunction")
	fn.Name = "AfterYouDebug"
	fn.OnInvoke = function(cmd: string, a: any, b: any): any
		local p = firstPlayer()
		if cmd == "State" then
			local cells = {}
			for _, pl in Players:GetPlayers() do
				cells[pl.Name] = registry.CellService:GetCell(pl) or "none"
			end
			local lodgerPos = nil
			for _, m in CollectionService:GetTagged("Lodger") do
				if m:IsA("Model") then
					lodgerPos = tostring(m:GetPivot().Position)
				end
			end
			return {
				Wear = registry.WearService:All(),
				Flags = registry.ObjectiveService:GetFlags(),
				Progress = registry.ObjectiveService:Progress(),
				Lodger = registry.LodgerService:State(),
				LodgerPos = lodgerPos,
				Cells = cells,
			}
		end
		if not p then
			return "no player"
		end
		if cmd == "Teleport" or cmd == "Walk" then
			local pos = targetPos(a)
			local root = registry.PlayerService:GetRoot(p)
			if not pos or not root then
				return "bad target or no character"
			end
			if cmd == "Teleport" then
				root.CFrame = CFrame.new(pos)
			else
				local hum = (p.Character :: any):FindFirstChildOfClass("Humanoid")
				hum:MoveTo(pos)
			end
			return "ok"
		elseif cmd == "Use" then
			for _, part in CollectionService:GetTagged("Interactable") do
				if part:GetAttribute("PointId") == a then
					registry.InteractionService.Used:Fire(p, part)
					return "ok"
				end
			end
			return "no interactable " .. tostring(a)
		elseif cmd == "Force" then
			return registry.DirectorService:Force(p, a)
		elseif cmd == "Door" then
			local door = registry.InteractionService:FindDoor(a)
			if not door then
				return "no door " .. tostring(a)
			end
			registry.InteractionService:SetDoorOpen(door, true)
			if door:GetAttribute("Kind") == "Plastic" and door.PrimaryPart then
				door.PrimaryPart.Transparency = 1
			end
			-- Logged like a real use, so DoorReplay has something to replay.
			registry.InteractionService.Action:Fire(p, EchoCodec.ActionKind.DoorOpen, a)
			return "ok"
		elseif cmd == "Wear" then
			registry.WearService:Add(a, b)
			return registry.WearService:Get(a)
		elseif cmd == "Wake" then
			return registry.LodgerService:Wake(p, true)
		end
		return "unknown command " .. tostring(cmd)
	end
	fn.Parent = ServerStorage
end

return DebugHook

--!strict
--[[
	Walk / run (hold Shift) / crouch (C or Ctrl). The server sets the actual speed (PlayerService),
	this only requests a stance. Also plays footsteps for every character, by floor type.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local MovementController = {}
-- (character, world position) each time any character plants a foot. Used by footprints.
MovementController.Step = Signal.new() :: Signal.Signal<Model, Vector3>

local stance = "Walk"
local runHeld = false
local crouchOn = false
local Audio: any

local STEP_DISTANCE = { Walk = 4.2, Run = 5.4, Crouch = 3.4 }
local lastStepPos: { [Model]: Vector3 } = {}

local function setStance(s: string)
	if s ~= stance then
		stance = s
		Net.FireServer("Stance", s)
	end
end

local function refresh()
	if crouchOn then
		setStance("Crouch")
	elseif runHeld then
		setStance("Run")
	else
		setStance("Walk")
	end
end

function MovementController:GetStance(): string
	return stance
end

local function footstepKey(character: Model): string
	local cell = nil
	local owner = Players:GetPlayerFromCharacter(character)
	if owner then
		cell = owner:GetAttribute("Cell")
	end
	if cell == "R4E" then
		return "FootstepWater"
	elseif cell == "StairA" or cell == "Laundry" or cell == "Closet" then
		return "FootstepConcrete"
	end
	return "FootstepLino"
end

local function stepCharacters()
	for _, plr in Players:GetPlayers() do
		local c = plr.Character
		local root = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if c and root and h and h.FloorMaterial ~= Enum.Material.Air then
			local pos = root.Position
			local last = lastStepPos[c]
			local s = (c:GetAttribute("Stance") :: string?) or "Walk"
			local dist = (STEP_DISTANCE :: any)[s] or 4.2
			if not last then
				lastStepPos[c] = pos
			elseif ((pos - last) * Vector3.new(1, 0, 1)).Magnitude >= dist then
				lastStepPos[c] = pos
				local foot = pos - Vector3.new(0, 2.8, 0)
				local vol = if s == "Run" then 1 elseif s == "Crouch" then 0.35 else 0.65
				local isLocal = plr == Players.LocalPlayer
				Audio:Play(footstepKey(c), if isLocal then nil else foot, {
					Bus = "Player",
					Volume = vol * (if isLocal then 0.7 else 1),
					Speed = 0.9 + math.random() * 0.2,
					Curve = "Footstep",
				})
				MovementController.Step:Fire(c, foot)
			end
		end
	end
end

function MovementController:Init(registry)
	Audio = registry.AudioController
end

function MovementController:Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift then
			runHeld = true
			refresh()
		elseif input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.LeftControl then
			crouchOn = not crouchOn
			refresh()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			runHeld = false
			refresh()
		end
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		crouchOn = false
		runHeld = false
		stance = ""
		refresh()
	end)
	RunService.Heartbeat:Connect(stepCharacters)
end

return MovementController

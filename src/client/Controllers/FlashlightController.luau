--!strict
-- F toggles the flashlight. The light itself lives on the server (everyone sees your beam);
-- the local copy is switched instantly so input feels immediate. Also reports look direction at 4 Hz.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local FlashlightController = {}
local on = false
local Settings: any
local Audio: any
local player = Players.LocalPlayer

local function light(): SpotLight?
	local c = player.Character
	local l = c and c:FindFirstChild("Flashlight", true)
	return if l and l:IsA("SpotLight") then l else nil
end

local function apply()
	local l = light()
	if l then
		l.Enabled = on
		l.Shadows = Settings.Tier.FlashlightShadows
	end
end

function FlashlightController:IsOn(): boolean
	return on
end

function FlashlightController:Toggle()
	on = not on
	apply()
	Audio:Play("FlashlightClick", nil, { Bus = "Player", Volume = 0.5 })
	Net.FireServer("Flashlight", on)
end

function FlashlightController:Init(registry)
	Settings = registry.SettingsController
	Audio = registry.AudioController
end

function FlashlightController:Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F then
			self:Toggle()
		end
	end)
	player.CharacterAdded:Connect(function(c)
		c:WaitForChild("Head"):WaitForChild("FlashlightAttachment", 10)
		apply()
	end)
	Settings.Changed:Connect(apply)
	-- Aim the beam where the camera looks, every frame (local only; others see it follow the head).
	RunService.RenderStepped:Connect(function()
		local cam = Workspace.CurrentCamera
		local c = player.Character
		local head = c and c:FindFirstChild("Head") :: BasePart?
		local att = head and head:FindFirstChild("FlashlightAttachment") :: Attachment?
		if att and cam then
			att.WorldCFrame = CFrame.lookAt(att.WorldPosition, att.WorldPosition + cam.CFrame.LookVector)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local cam = Workspace.CurrentCamera
			if cam then
				Net.FireServer("Look", cam.CFrame.LookVector)
			end
		end
	end)
end

return FlashlightController

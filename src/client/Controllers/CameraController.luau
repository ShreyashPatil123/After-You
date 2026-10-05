--!strict
-- Locked first person with subtle head-bob and crouch height. Exposes hooks for scripted camera moments.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PlayerConfig = require(Shared.Config.PlayerConfig)

local CameraController = {}
CameraController.Scripted = false -- when true, another system owns the camera (e.g. Taken sequence)

local player = Players.LocalPlayer
local Settings: any
local Movement: any
local bobPhase = 0
local crouchBlend = 0

function CameraController:Init(registry)
	Settings = registry.SettingsController
	Movement = registry.MovementController
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMaxZoomDistance = 0.5
end

function CameraController:Start()
	local cam = Workspace.CurrentCamera
	cam.FieldOfView = PlayerConfig.FieldOfView
	RunService:BindToRenderStep("AfterYouCamera", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		if self.Scripted then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		local crouching = Movement:GetStance() == "Crouch"
		crouchBlend += ((if crouching then 1 else 0) - crouchBlend) * math.min(1, dt * 10)
		local offset = Vector3.new(0, -PlayerConfig.CrouchCameraDrop * crouchBlend, 0)
		local speed = humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed
		if Settings.HeadBob and speed > 0.5 and humanoid.FloorMaterial ~= Enum.Material.Air then
			bobPhase += dt * PlayerConfig.HeadBob.Frequency * (speed / PlayerConfig.WalkSpeed)
			local a = PlayerConfig.HeadBob.Amplitude * math.min(speed / PlayerConfig.WalkSpeed, 1.6)
			offset += Vector3.new(math.cos(bobPhase * 0.5) * a * 0.6, math.abs(math.sin(bobPhase)) * a, 0)
		else
			bobPhase = 0
		end
		humanoid.CameraOffset = offset
	end)
end

return CameraController

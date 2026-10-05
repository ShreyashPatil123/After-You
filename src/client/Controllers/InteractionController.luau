--!strict
--[[
	Looks at what's under the crosshair. E = use, Q = knock (doors), hold E on plastic sheeting.
	No floating prompts on PC; the UI shows a small hint line under the crosshair.
	TODO(mobile): touch buttons via ContextActionService before mobile testing.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local PlayerConfig = require(Shared.Config.PlayerConfig)

local InteractionController = {}

type Focus = { Target: any, Kind: string, Hint: string }
local focus: Focus? = nil
local holding: Instance? = nil
local UI: any

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function describe(hit: Instance): Focus?
	local model = hit:FindFirstAncestorOfClass("Model")
	if model and CollectionService:HasTag(model, "Door") then
		local kind = model:GetAttribute("Kind") :: string
		local label = (model:GetAttribute("Label") :: string?) or ""
		if kind == "Fake" then
			return { Target = model, Kind = "Fake", Hint = "[Q] Knock  " .. label }
		elseif kind == "Plastic" then
			if model:GetAttribute("Open") then
				return nil
			end
			return { Target = model, Kind = "Plastic", Hint = "[Hold E] Cut the plastic  " .. label }
		elseif kind == "Lift" then
			return {
				Target = model,
				Kind = "Lift",
				Hint = if model:GetAttribute("Locked") then "No power" else "",
			}
		end
		local open = model:GetAttribute("Open") == true
		return {
			Target = model,
			Kind = "Door",
			Hint = (if open then "[E] Close" else "[E] Open") .. "   [Q] Knock  " .. label,
		}
	end
	if hit:IsA("BasePart") and CollectionService:HasTag(hit, "Interactable") then
		local kind = hit:GetAttribute("InteractKind") :: string
		local hints =
			{ Note = "[E] Read", Tape = "[E] Play tape", Item = "[E] Take", FuseBox = "[E] Fuse box" }
		return { Target = hit, Kind = kind, Hint = hints[kind] or "[E]" }
	end
	return nil
end

local function update()
	local cam = Workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	if not cam or not character then
		focus = nil
		return
	end
	params.FilterDescendantsInstances = { character }
	local origin = cam.CFrame.Position
	local hit = Workspace:Raycast(origin, cam.CFrame.LookVector * PlayerConfig.InteractDistance, params)
	focus = if hit then describe(hit.Instance) else nil
	UI:SetHint(if focus then focus.Hint else "")
end

function InteractionController:Init(registry)
	UI = registry.UIController
end

function InteractionController:Start()
	RunService.Heartbeat:Connect(update)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not focus then
			return
		end
		local f = focus :: Focus
		if input.KeyCode == Enum.KeyCode.E then
			if f.Kind == "Plastic" then
				holding = f.Target
				Net.FireServer("HoldInteract", f.Target, "Begin")
			elseif f.Kind ~= "Fake" and f.Kind ~= "Lift" then
				Net.FireServer("Interact", f.Target, "Use")
			end
		elseif input.KeyCode == Enum.KeyCode.Q and (f.Kind == "Door" or f.Kind == "Fake") then
			Net.FireServer("Interact", f.Target, "Knock")
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.E and holding then
			Net.FireServer("HoldInteract", holding, "End")
			holding = nil
		end
	end)
end

return InteractionController

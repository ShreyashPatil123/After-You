--!strict
--[[
	Minimal UI (plan §F): crosshair dot, interaction hint, subtitles with direction, notes,
	Theo's clipboard (Tab), the Taken sequence, end card, and a Studio-only debug overlay (F2).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local UIController = {}

local player = Players.LocalPlayer
local Settings: any
local Camera: any
local gui: ScreenGui
local hint: TextLabel
local subtitle: TextLabel
local note: TextLabel
local clipboard: TextLabel
local fade: Frame
local card: TextLabel
local debugLabel: TextLabel
local subtitleToken = 0
local objective = { Text = "", Fuses = 0, Needs = 2, Visible = false }

local FONT = Font.new("rbxasset://fonts/families/SourceSansPro.json")

local CAPTIONS: { [string]: string } = {
	DoorKnock = "knocking",
	FootstepConcrete = "footsteps",
	FootstepLino = "footsteps",
	DoorOpen = "a door opens",
	DoorClose = "a door closes",
}

local function label(name: string, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.fromRGB(225, 225, 215)
	l.FontFace = FONT
	l.TextWrapped = true
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = gui
	return l
end

local function direction(pos: Vector3): string
	local cam = Workspace.CurrentCamera
	if not cam then
		return ""
	end
	local rel = cam.CFrame:PointToObjectSpace(pos)
	local dist = rel.Magnitude
	local where
	if rel.Z > 0 and math.abs(rel.X) < rel.Z then
		where = "behind you"
	elseif math.abs(rel.X) > math.abs(rel.Z) then
		where = if rel.X > 0 then "to your right" else "to your left"
	else
		where = "ahead"
	end
	if pos.Y - cam.CFrame.Position.Y > 6 then
		where = "above you"
	end
	local near = if dist < 12 then "close" elseif dist < 40 then "" else "far"
	return where .. (if near ~= "" then ", " .. near else "")
end

function UIController:SetHint(text: string)
	if hint.Text ~= text then
		hint.Text = text
	end
end

function UIController:ShowSubtitle(text: string, seconds: number)
	if not Settings.Subtitles then
		return
	end
	subtitleToken += 1
	local my = subtitleToken
	subtitle.Text = text
	subtitle.TextTransparency = 0
	task.delay(seconds, function()
		if subtitleToken == my then
			TweenService:Create(subtitle, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		end
	end)
end

-- Non-speech caption with direction, e.g. "[knocking, behind you, close]".
function UIController:Caption(soundKey: string, pos: Vector3?)
	local what = CAPTIONS[soundKey] or soundKey
	local where = if pos then direction(pos) else ""
	self:ShowSubtitle("[" .. what .. (if where ~= "" then ", " .. where else "") .. "]", 3)
end

local function showNote(text: string)
	note.Text = text
	note.Visible = true
	task.delay(7, function()
		if note.Text == text then
			note.Visible = false
		end
	end)
end

local function refreshClipboard()
	clipboard.Text =
		string.format("THEO'S LIST\n\n%s\n\nFuses: %d / %d", objective.Text, objective.Fuses, objective.Needs)
end

local function takenSequence()
	-- The Lodger takes your place: the camera drifts back while "you" walk away. No gore (§D.3).
	Camera.Scripted = true
	local cam = Workspace.CurrentCamera
	local start = cam.CFrame
	cam.CameraType = Enum.CameraType.Scriptable
	TweenService
		:Create(cam, TweenInfo.new(3.5, Enum.EasingStyle.Sine), { CFrame = start * CFrame.new(0, 1.2, 7) })
		:Play()
	TweenService:Create(fade, TweenInfo.new(3.5), { BackgroundTransparency = 0 }):Play()
	player.CharacterAdded:Wait()
	task.wait(0.3)
	cam.CameraType = Enum.CameraType.Custom
	Camera.Scripted = false
	TweenService:Create(fade, TweenInfo.new(2), { BackgroundTransparency = 1 }):Play()
end

function UIController:Init(registry)
	Settings = registry.SettingsController
	Camera = registry.CameraController
	local g = Instance.new("ScreenGui")
	g.Name = "AfterYouUI"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.Parent = player:WaitForChild("PlayerGui")
	gui = g

	local dot = Instance.new("Frame")
	dot.Name = "Crosshair"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(4, 4)
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.BackgroundTransparency = 0.5
	dot.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
	dot.Parent = gui

	hint = label("Hint", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 18),
		Size = UDim2.fromOffset(420, 22),
		TextSize = 16,
		TextTransparency = 0.2,
	})
	subtitle = label("Subtitle", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -60),
		Size = UDim2.new(0.7, 0, 0, 60),
		TextSize = 22,
		TextTransparency = 1,
		TextStrokeTransparency = 0.4,
	})
	note = label("Note", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(460, 160),
		TextSize = 22,
		BackgroundTransparency = 0.1,
		BackgroundColor3 = Color3.fromRGB(226, 220, 198),
		TextColor3 = Color3.fromRGB(40, 36, 30),
		Visible = false,
	})
	clipboard = label("Clipboard", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 24),
		Size = UDim2.fromOffset(300, 140),
		TextSize = 18,
		BackgroundTransparency = 0.15,
		BackgroundColor3 = Color3.fromRGB(226, 220, 198),
		TextColor3 = Color3.fromRGB(40, 36, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Visible = false,
	})
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingTop = UDim.new(0, 10)
	pad.Parent = clipboard
	fade = Instance.new("Frame")
	fade.Name = "Fade"
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BackgroundTransparency = 1
	fade.BorderSizePixel = 0
	fade.ZIndex = 10
	fade.Parent = gui
	card = label("Card", {
		Size = UDim2.fromScale(1, 1),
		TextSize = 40,
		TextTransparency = 1,
		ZIndex = 11,
		Text = "AFTER YOU\n\nend of the greybox slice",
	})
	debugLabel = label("Debug", {
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.fromOffset(420, 520),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Code,
		BackgroundTransparency = 0.4,
		BackgroundColor3 = Color3.new(0, 0, 0),
		Visible = false,
	})
end

function UIController:Start()
	Net.OnClient("Subtitle", function(p)
		if p.Kind == "Note" then
			showNote(p.Text)
		elseif p.Kind == "Hint" then
			self:ShowSubtitle(p.Text, 3)
		elseif p.Kind == "Tape" then
			-- Only players near the tape hear it.
			local cam = Workspace.CurrentCamera
			if p.Position and cam and (p.Position - cam.CFrame.Position).Magnitude > 40 then
				return
			end
			for _, line in p.Lines do
				task.delay(line.At, function()
					self:ShowSubtitle(p.Speaker .. ": " .. line.Text, 4)
				end)
			end
		end
	end)
	Net.OnClient("Objective", function(p)
		objective = p
		refreshClipboard()
	end)
	Net.OnClient("Taken", function()
		task.spawn(takenSequence)
	end)
	Net.OnClient("SliceEnd", function()
		TweenService:Create(fade, TweenInfo.new(2), { BackgroundTransparency = 0 }):Play()
		task.wait(2)
		TweenService:Create(card, TweenInfo.new(2), { TextTransparency = 0 }):Play()
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Tab and objective.Visible then
			clipboard.Visible = not clipboard.Visible
		elseif input.KeyCode == Enum.KeyCode.F2 and RunService:IsStudio() then
			debugLabel.Visible = not debugLabel.Visible
		end
	end)
	Net.OnClient("DebugState", function(d)
		if not debugLabel.Visible then
			return
		end
		local lines = {
			string.format(
				"PACING %s  %ds/%ds  tension %d",
				d.Pacing,
				d.PacingTime,
				d.PacingDuration,
				d.Tension
			),
			string.format("cell %s   lodger %s   progress %.2f", tostring(d.Cell), d.Lodger, d.Progress),
			"",
			"WEAR (0-255, lodger >= 64)",
		}
		local ids = {}
		for id in d.Wear do
			table.insert(ids, id)
		end
		table.sort(ids)
		for _, id in ids do
			local b = d.Wear[id]
			table.insert(lines, string.format("  %-8s %3d %s", id, b, string.rep("#", math.floor(b / 16))))
		end
		table.insert(lines, "")
		table.insert(lines, "EVENTS")
		local evs = {}
		for id in d.Events do
			table.insert(evs, id)
		end
		table.sort(evs)
		for _, id in evs do
			table.insert(lines, string.format("  %-14s %s", id, d.Events[id]))
		end
		debugLabel.Text = table.concat(lines, "\n")
	end)
end

return UIController

--!strict
--[[
	Plays everything the server sends through EventPlay (plan §J): echoes of the player's own past,
	fake scares, silence windows and one-shot sounds. Presenters are keyed by event Category, so a new
	event of an existing category needs no client change.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local EchoCodec = require(Shared.Logic.EchoCodec)
local EchoConfig = require(Shared.Config.EchoConfig)
local AssetIds = require(Shared.Config.AssetIds)
local LayoutSpace = require(Shared.Util.LayoutSpace)
local Net = require(Shared.Net)

local EchoController = {}

type Payload = { [string]: any }
local Audio: any
local Doors: any
local UI: any
local player = Players.LocalPlayer

-- Local position history for "behind you" footsteps.
local trail: { { t: number, p: Vector3 } } = {}

local function worldPath(path: EchoCodec.Path): { CFrame }
	local out = table.create(#path.Samples)
	for i, s in path.Samples do
		local pos = LayoutSpace.ToWorld(s.X, s.Y, s.Z)
		out[i] = CFrame.new(pos) * CFrame.Angles(0, s.Yaw, 0)
	end
	return out
end

-- Calls fn(cframe, sampleIndex) every frame while interpolating along the path; yields until done.
local function walkPath(cfs: { CFrame }, interval: number, fn: (CFrame, number) -> ())
	local total = (#cfs - 1) * interval
	local t = 0
	while t < total do
		local f = t / interval
		local i = math.floor(f) + 1
		local a = f - (i - 1)
		local cf = cfs[i]:Lerp(cfs[math.min(i + 1, #cfs)], a)
		fn(cf, i)
		t += RunService.Heartbeat:Wait()
	end
end

-- Reports whether the player turned toward the event within `window` seconds (tuning data, A1).
local function watchNoticed(token: number?, position: Vector3?, window: number)
	if not token or not position then
		return
	end
	task.spawn(function()
		local t0 = os.clock()
		local noticed = false
		while os.clock() - t0 < window do
			local cam = Workspace.CurrentCamera
			if cam then
				local to = (position - cam.CFrame.Position).Unit
				if cam.CFrame.LookVector:Dot(to) > 0.82 then
					noticed = true
					break
				end
			end
			task.wait(0.1)
		end
		Net.FireServer("EventFeedback", token, noticed)
	end)
end

local function makeFigure(userId: number): Model?
	local owner = Players:GetPlayerByUserId(userId)
	local character = owner and owner.Character
	if not character then
		return nil
	end
	character.Archivable = true
	local clone = character:Clone()
	if not clone then
		return nil
	end
	for _, d in clone:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Light") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = d.Name == "HumanoidRootPart"
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			if d.Name ~= "HumanoidRootPart" then
				local c = d.Color
				local l = (c.R + c.G + c.B) / 3
				d.Color = Color3.new(l, l, l * 1.04)
				d.Transparency = EchoConfig.FigureTransparency
				d.Material = Enum.Material.SmoothPlastic
			end
		elseif d:IsA("Decal") then
			d.Transparency = 0.5
		end
	end
	local h = clone:FindFirstChildOfClass("Humanoid")
	if h then
		h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		h.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	clone.Name = "Echo"
	return clone
end

local Presenters: { [string]: (Payload) -> () } = {}

Presenters.Sfx = function(p)
	Audio:Play(p.Sound, p.Position, { Bus = "World" })
end

Presenters.EchoSound = function(p)
	-- Your own footsteps, `Lag` seconds behind you: stop, and they stop a beat later.
	local t0 = os.clock()
	local last: Vector3? = nil
	local firstStep: Vector3? = nil
	while os.clock() - t0 < p.Duration do
		local target = os.clock() - p.Lag
		local lagged: Vector3? = nil
		for i = #trail, 1, -1 do
			if trail[i].t <= target then
				lagged = trail[i].p
				break
			end
		end
		if lagged then
			if not last then
				last = lagged
			elseif ((lagged - last :: Vector3) * Vector3.new(1, 0, 1)).Magnitude >= 4.2 then
				last = lagged
				Audio:Play(
					"FootstepLino",
					lagged - Vector3.new(0, 2.8, 0),
					{ Bus = "Echo", Volume = 0.8, Curve = "Footstep" }
				)
				firstStep = firstStep or lagged
			end
		end
		RunService.Heartbeat:Wait()
	end
	watchNoticed(p.Token, firstStep, 1)
end

Presenters.EchoObject = function(p)
	local door = Doors:FindDoor(p.Opening)
	if door then
		Doors:PlayLocal(door, { true, false }, 2.2)
		Audio:Play("DoorOpen", door:GetPivot().Position, { Bus = "Echo" })
		task.delay(2.2, function()
			Audio:Play("DoorClose", door:GetPivot().Position, { Bus = "Echo" })
		end)
		watchNoticed(p.Token, door:GetPivot().Position, 4)
	end
end

Presenters.EchoLight = function(p)
	local path = EchoCodec.Decode(p.Path)
	local cfs = worldPath(path)
	local carrier = Instance.new("Part")
	carrier.Name = "EchoLight"
	carrier.Anchored = true
	carrier.CanCollide = false
	carrier.CanQuery = false
	carrier.Transparency = 1
	carrier.Size = Vector3.new(0.2, 0.2, 0.2)
	carrier.Parent = Workspace
	local spot = Instance.new("SpotLight")
	spot.Angle = 42
	spot.Range = 48
	spot.Brightness = 2
	spot.Color = Color3.fromRGB(255, 244, 225)
	spot.Face = Enum.NormalId.Front
	spot.Parent = carrier
	watchNoticed(p.Token, cfs[1].Position, 4)
	walkPath(cfs, path.Interval, function(cf, i)
		local s = path.Samples[i]
		spot.Enabled = bit32.band(s.Flags, EchoCodec.Flags.Flashlight) ~= 0
		-- Beam at head height, sweeping where you were looking.
		carrier.CFrame = cf * CFrame.new(0.4, 1.6, -0.6)
	end)
	carrier:Destroy()
end

Presenters.EchoFigure = function(p)
	local path = EchoCodec.Decode(p.Path)
	local fig = makeFigure(p.UserId)
	if not fig then
		return
	end
	local cfs = worldPath(path)
	fig:PivotTo(cfs[1])
	fig.Parent = Workspace
	local h = fig:FindFirstChildOfClass("Humanoid")
	local animator = h and h:FindFirstChildOfClass("Animator")
	local track: AnimationTrack? = nil
	if animator then
		local a = Instance.new("Animation")
		a.AnimationId = AssetIds.Animations.Walk
		local ok, t = pcall(function()
			return animator:LoadAnimation(a)
		end)
		if ok then
			track = t
			t:Play(0.1)
		end
	end
	watchNoticed(p.Token, cfs[1].Position, 5)
	local lastStep = cfs[1].Position
	walkPath(cfs, path.Interval, function(cf)
		fig:PivotTo(cf)
		if (cf.Position - lastStep).Magnitude >= 4.2 then
			lastStep = cf.Position
			Audio:Play(
				"FootstepLino",
				cf.Position - Vector3.new(0, 2.8, 0),
				{ Bus = "Echo", Volume = 0.7, Curve = "Footstep" }
			)
		end
	end)
	if track then
		track:Stop()
	end
	fig:Destroy()
end

Presenters.Silence = function(p)
	Audio:Silence(p.Duration)
end

Presenters.Fake = function(p)
	for i = 1, p.Repeat or 1 do
		Audio:Play(p.Sound, p.Position, { Bus = "World", Curve = "Far" })
		task.wait(if p.Sound == "DoorKnock" then 0.45 else 0.75)
	end
	UI:Caption(p.Sound, p.Position)
	watchNoticed(p.Token, p.Position, 3)
end

Presenters.Lodger = function(p)
	-- The rig itself is server-side and replicated; the presentation controller handles its sounds.
	if p.First then
		Audio:Silence(25)
	end
end

Presenters.LiftKnock = function(p)
	task.wait(p.Delay or 3)
	for _ = 1, p.Repeat or 2 do
		Audio:Play("DoorKnock", p.Position, { Bus = "Echo" })
		task.wait(0.5)
	end
	UI:Caption("DoorKnock", p.Position)
end

function EchoController:Init(registry)
	Audio = registry.AudioController
	Doors = registry.DoorController
	UI = registry.UIController
end

function EchoController:Start()
	RunService.Heartbeat:Connect(function()
		local c = player.Character
		local root = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local now = os.clock()
			table.insert(trail, { t = now, p = root.Position })
			while trail[1] and now - trail[1].t > 5 do
				table.remove(trail, 1)
			end
		end
	end)
	Net.OnClient("EventPlay", function(p: Payload)
		local fn = Presenters[p.Category]
		if fn then
			task.spawn(fn, p)
		else
			warn("[Echo] no presenter for " .. tostring(p.Category))
		end
	end)
end

return EchoController

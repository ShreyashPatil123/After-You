--!strict
--[[
	Object-based audio (plan §M): AudioPlayer -> [AudioFilter] -> AudioEmitter for 3D sounds,
	heard by one AudioListener on the camera; 2D beds go straight to a bus fader.
	Acoustic Simulation handles occlusion where the tier allows; otherwise a raycast drives a low-pass.
]]
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AssetIds = require(Shared.Config.AssetIds)
local AudioConfig = require(Shared.Config.AudioConfig)

export type Bus = "Ambience" | "World" | "Player" | "Echo" | "Lodger" | "UI"
export type PlayOptions = {
	Bus: Bus?,
	Volume: number?,
	Speed: number?,
	Curve: string?,
	Looping: boolean?,
}
type Handle = {
	Player: AudioPlayer,
	Emitter: AudioEmitter?,
	Filter: AudioFilter?,
	Anchor: Instance?,
	Position: Vector3?,
}

local AudioController = {}

local Settings: any
local root: Folder
local master: AudioFader
local busFaders: { [string]: AudioFader } = {}
local listener: AudioListener
local active: { Handle } = {}
local warned: { [string]: boolean } = {}

local function wire(from: Instance, to: Instance, parent: Instance): Wire
	local w = Instance.new("Wire")
	w.SourceInstance = from
	w.TargetInstance = to
	w.Parent = parent
	return w
end

local function busVolume(bus: Bus): number
	return (AudioConfig.Buses :: any)[bus] or 1
end

local function resolve(key: string): string?
	local id = (AssetIds.Sounds :: any)[key]
	if id == nil or id == "" then
		if not warned[key] then
			warned[key] = true
			warn("[Audio] no asset for sound '" .. key .. "' yet (AssetIds.Sounds)")
		end
		return nil
	end
	return id
end

local function cleanup(h: Handle)
	local i = table.find(active, h)
	if i then
		table.remove(active, i)
	end
	if h.Anchor then
		h.Anchor:Destroy()
	end
	h.Player:Destroy()
	if h.Filter then
		h.Filter:Destroy()
	end
end

local function startWhenReady(p: AudioPlayer)
	if p.IsReady then
		p:Play()
		return
	end
	task.spawn(function()
		local t0 = os.clock()
		while not p.IsReady and p.Parent and os.clock() - t0 < 5 do
			task.wait(0.05)
		end
		if p.Parent then
			p:Play()
		end
	end)
end

--[[
	Plays a sound by AssetIds key. `at` = world position (3D), an Instance to follow (3D), or nil (2D).
	Returns the AudioPlayer so callers can stop it, or nil when the asset isn't sourced yet.
]]
function AudioController:Play(key: string, at: (Vector3 | Instance)?, opts: PlayOptions?): AudioPlayer?
	local id = resolve(key)
	if not id then
		return nil
	end
	local o: PlayOptions = opts or {}
	local bus: Bus = o.Bus or "World"
	local p = Instance.new("AudioPlayer")
	p.Asset = id
	p.Volume = (o.Volume or 1) * busVolume(bus)
	p.PlaybackSpeed = o.Speed or 1
	p.Looping = o.Looping == true
	local h: Handle = { Player = p }
	if at == nil then
		p.Parent = root
		wire(p, busFaders[bus], p)
	else
		local anchor: Instance
		if typeof(at) == "Vector3" then
			local a = Instance.new("Attachment")
			a.WorldPosition = at
			a.Parent = Workspace.Terrain
			anchor = a
			h.Anchor = a
			h.Position = at
		else
			anchor = at
		end
		local e = Instance.new("AudioEmitter")
		local curve = (AudioConfig.Curves :: any)[o.Curve or "Default"] or AudioConfig.Curves.Default
		e:SetDistanceAttenuation(curve)
		e.AcousticSimulationEnabled = Settings.Tier.AcousticSimulation
		e.Parent = anchor
		h.Emitter = e
		p.Parent = e
		if not Settings.Tier.AcousticSimulation then
			-- Raycast fallback (§M): a low-pass between player and emitter, driven in the update loop.
			local f = Instance.new("AudioFilter")
			f.FilterType = Enum.AudioFilterType.Lowpass12dB
			f.Frequency = AudioConfig.OcclusionFallback.OpenFrequency
			f.Parent = e
			wire(p, f, f)
			wire(f, e, f)
			h.Filter = f
		else
			wire(p, e, p)
		end
		if h.Anchor == nil then
			-- Following an instance: the emitter dies with it, the player with the emitter.
			e.Destroying:Connect(function()
				cleanup(h)
			end)
		end
	end
	table.insert(active, h)
	p.Ended:Connect(function()
		if not p.Looping then
			cleanup(h)
		end
	end)
	startWhenReady(p)
	return p
end

function AudioController:Stop(p: AudioPlayer?)
	if not p then
		return
	end
	for _, h in active do
		if h.Player == p then
			cleanup(h)
			return
		end
	end
	p:Destroy()
end

-- Silence window (§M): pull the ambience bus down, then restore.
function AudioController:Silence(seconds: number)
	local f = busFaders.Ambience
	TweenService:Create(f, TweenInfo.new(2.5), { Volume = 0.03 }):Play()
	task.delay(seconds, function()
		TweenService:Create(f, TweenInfo.new(4), { Volume = 1 }):Play()
	end)
end

function AudioController:SetMasterVolume(v: number)
	master.Volume = v
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function updateOcclusion()
	local cam = Workspace.CurrentCamera
	if not cam or Settings.Tier.AcousticSimulation then
		return
	end
	local exclude: { Instance } = {}
	local dyn = Workspace:FindFirstChild("Dynamic")
	if dyn then
		table.insert(exclude, dyn)
	end
	for _, plr in game:GetService("Players"):GetPlayers() do
		if plr.Character then
			table.insert(exclude, plr.Character)
		end
	end
	rayParams.FilterDescendantsInstances = exclude
	local fb = AudioConfig.OcclusionFallback
	for _, h in active do
		if h.Filter and h.Emitter then
			local parent = h.Emitter.Parent
			local pos: Vector3? = h.Position
			if not pos and parent then
				if parent:IsA("Attachment") then
					pos = parent.WorldPosition
				elseif parent:IsA("BasePart") then
					pos = parent.Position
				end
			end
			if pos then
				local hit = Workspace:Raycast(cam.CFrame.Position, pos - cam.CFrame.Position, rayParams)
				local blocked = hit ~= nil and (hit.Position - pos).Magnitude > 1
				h.Filter.Frequency = if blocked then fb.BlockedFrequency else fb.OpenFrequency
			end
		end
	end
end

function AudioController:Init(registry)
	Settings = registry.SettingsController
	local f = Instance.new("Folder")
	f.Name = "AudioGraph"
	f.Parent = SoundService
	root = f

	local out = Instance.new("AudioDeviceOutput")
	out.Parent = root
	local comp = Instance.new("AudioCompressor")
	comp.Threshold = -12
	comp.Ratio = 3
	comp.Parent = root
	master = Instance.new("AudioFader")
	master.Name = "Master"
	master.Parent = root
	wire(master, comp, root)
	wire(comp, out, root)
	for name: string in AudioConfig.Buses :: any do
		local fader = Instance.new("AudioFader")
		fader.Name = name
		fader.Parent = root
		wire(fader, master, root)
		busFaders[name] = fader
	end
	listener = Instance.new("AudioListener")
	listener.Name = "Listener"
	-- 3D sounds are mixed by the listener and land on the World bus.
	wire(listener, busFaders.World, root)
	pcall(function()
		(SoundService :: any).AcousticSimulationEnabled = true
	end)
end

function AudioController:Start()
	local function attachListener()
		local cam = Workspace.CurrentCamera
		if cam then
			listener.AcousticSimulationEnabled = Settings.Tier.AcousticSimulation
			listener.Parent = cam
		end
	end
	attachListener()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(attachListener)
	Settings.Changed:Connect(attachListener)
	-- Ambience beds (only those with sourced assets play).
	self:Play("RoomTone", nil, { Bus = "Ambience", Looping = true, Volume = 0.5 })
	self:Play("Rain", nil, { Bus = "Ambience", Looping = true, Volume = 0.35 })
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= AudioConfig.OcclusionFallback.CheckSeconds then
			acc = 0
			updateOcclusion()
		end
	end)
end

return AudioController

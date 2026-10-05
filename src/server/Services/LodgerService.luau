--!strict
--[[
	The Lodger (plan §D.3, §I). Decisions come from Logic/LodgerBrain; this service gathers
	perception, moves the rig, and enforces the rule: it can only enter worn cells.
	Wear reaches PathfindingService through per-cell PathfindingModifier labels priced by wear.
]]
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AssetIds = require(Shared.Config.AssetIds)
local CellGraph = require(Shared.Logic.CellGraph)
local EchoConfig = require(Shared.Config.EchoConfig)
local LayoutSpace = require(Shared.Util.LayoutSpace)
local LodgerBrain = require(Shared.Logic.LodgerBrain)
local LodgerConfig = require(Shared.Config.LodgerConfig)
local Net = require(Shared.Net)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local Signal = require(Shared.Util.Signal)

local LodgerService = {}
LodgerService.StateChanged = Signal.new() :: Signal.Signal<string, Player?>
LodgerService.Withdrew = Signal.new() :: Signal.Signal<Player?>
LodgerService.Took = Signal.new() :: Signal.Signal<Player>

local PlayerService: any
local CellService: any
local WearService: any
local EchoService: any
local InteractionService: any
local HorrorEventService: any
local AnalyticsService: any

local brain = LodgerBrain.New()
local target: Player? = nil
local rig: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local walkTrack: AnimationTrack? = nil

local route: { Vector3 } = {} -- current waypoints
local routeIndex = 1
local lastRepath = 0
local lastKnown: Vector3? = nil
local noise = 0 -- loudest attenuated noise heard since last tick
local withdrawUntil = 0
local withdrawGiveUpAt = 0

local TICK = 0.15
local Cfg = LodgerConfig

local function dynamicFolder(): Folder
	local f = Workspace:FindFirstChild("Dynamic")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Dynamic"
		f.Parent = Workspace
	end
	return f :: Folder
end

local function setLook(transparency: number, grey: boolean)
	if not rig then
		return
	end
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			d.Transparency = transparency
			if grey then
				local c = d.Color
				local l = (c.R + c.G + c.B) / 3
				d.Color = Color3.new(l, l, l)
			end
		elseif d:IsA("Decal") then
			d.Transparency = transparency
		end
	end
end

local function despawn()
	if rig then
		rig:Destroy()
	end
	rig, humanoid, root, walkTrack = nil, nil, nil, nil
	route = {}
end

local function spawnRig(asPlayer: Player, at: Vector3): boolean
	despawn()
	local character = asPlayer.Character
	if not character then
		return false
	end
	character.Archivable = true
	local clone = character:Clone()
	if not clone then
		return false
	end
	for _, d in clone:GetDescendants() do
		if
			d:IsA("BaseScript")
			or d:IsA("Light")
			or d:IsA("Attachment") and d.Name == "FlashlightAttachment"
		then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
			d.AudioCanCollide = false
		end
	end
	clone.Name = "Lodger"
	local h = clone:FindFirstChildOfClass("Humanoid") :: Humanoid
	local r = clone:FindFirstChild("HumanoidRootPart") :: BasePart
	if not h or not r then
		clone:Destroy()
		return false
	end
	r.CanCollide = true
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	h.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	h.WalkSpeed = Cfg.WalkSpeed
	h.JumpPower = 0
	h.BreakJointsOnDeath = false
	clone:SetAttribute("State", brain.State)
	clone:PivotTo(CFrame.new(at + Vector3.new(0, 3, 0)))
	CollectionService:AddTag(clone, "Lodger")
	clone.Parent = dynamicFolder()
	r:SetNetworkOwner(nil)
	rig, humanoid, root = clone, h, r

	local animator = h:FindFirstChildOfClass("Animator") or Instance.new("Animator", h)
	local ok, track = pcall(function()
		local a = Instance.new("Animation")
		a.AnimationId = AssetIds.Animations.Walk
		return (animator :: Animator):LoadAnimation(a)
	end)
	if ok then
		walkTrack = track
	end
	return true
end

local function cellOf(p: Vector3): string?
	return CellService:CellAt(p)
end

local function canEnter(id: string): boolean
	return WearService:CanLodgerEnter(id)
end

local function reachable(fromCell: string?, toCell: string?): boolean
	if not fromCell or not toCell then
		return false
	end
	return CellGraph.Route(CellService.Graph, fromCell, toCell, canEnter) ~= nil
end

local function costs(): { [string]: number }
	local c: { [string]: number } = {}
	for _, id in CellService.Graph.Order do
		c["Cell_" .. id] = if canEnter(id) then 1 else math.huge
	end
	return c
end

local function computePath(to: Vector3): { Vector3 }?
	if not root then
		return nil
	end
	local path = PathfindingService:CreatePath({
		AgentRadius = Cfg.AgentRadius,
		AgentHeight = Cfg.AgentHeight,
		AgentCanJump = false,
		WaypointSpacing = 4,
		Costs = costs(),
	})
	local ok = pcall(function()
		path:ComputeAsync(root.Position, to)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return nil
	end
	local pts = {}
	for _, wp in path:GetWaypoints() do
		table.insert(pts, wp.Position)
	end
	return pts
end

local function setRoute(points: { Vector3 })
	route = points
	routeIndex = 1
end

local function stopMoving()
	route = {}
	if humanoid and root then
		humanoid:MoveTo(root.Position)
	end
end

-- Opens closed doors the Lodger walks into (it is a tenant; doors don't stop it).
local function openDoorsNear()
	if not root then
		return
	end
	for _, door in CollectionService:GetTagged("Door") do
		if door:GetAttribute("Kind") == "Door" and door:GetAttribute("Open") ~= true then
			local d = (door:GetPivot().Position - root.Position) * Vector3.new(1, 0, 1)
			if d.Magnitude < 4.5 then
				InteractionService:SetDoorOpen(door, true)
				Net.FireAll(
					"EventPlay",
					{ Category = "Sfx", Sound = "DoorOpen", Position = door:GetPivot().Position }
				)
			end
		end
	end
end

local function followRoute(): boolean -- returns true when finished
	if not humanoid or not root then
		return true
	end
	while routeIndex <= #route do
		local goal = route[routeIndex]
		local flat = (goal - root.Position) * Vector3.new(1, 0, 1)
		if flat.Magnitude < 2 then
			routeIndex += 1
		else
			-- Never step into a cell it may not enter (route can go stale as dust settles).
			local c = cellOf(goal)
			if c and not canEnter(c) and c ~= cellOf(root.Position) then
				route = {}
				return true
			end
			humanoid:MoveTo(goal)
			return false
		end
	end
	return true
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function canSee(p: Player): boolean
	if not root or not rig then
		return false
	end
	local head = PlayerService:GetHead(p)
	local myHead = rig:FindFirstChild("Head") :: BasePart?
	if not head or not myHead then
		return false
	end
	local to = head.Position - myHead.Position
	local range = if PlayerService:IsFlashlightOn(p) then Cfg.SightRangeFlashlightOn else Cfg.SightRange
	if to.Magnitude > range then
		return false
	end
	-- Cone check, except in Deviate/Search where it is actively looking around.
	if brain.State == "Mimic" or brain.State == "Pursue" then
		local cos = root.CFrame.LookVector:Dot(to.Unit)
		if cos < math.cos(math.rad(Cfg.SightConeDegrees / 2)) then
			return false
		end
	end
	local exclude: { Instance } = { rig :: any }
	local dyn = Workspace:FindFirstChild("Dynamic")
	if dyn then
		table.insert(exclude, dyn)
	end
	rayParams.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(myHead.Position, to, rayParams)
	return hit ~= nil and hit.Instance:IsDescendantOf(p.Character :: any)
end

local function lookingAtMe(p: Player): boolean
	local head = PlayerService:GetHead(p)
	local look = PlayerService:GetLook(p)
	if not head or not look or not root then
		return false
	end
	local to = (root.Position + Vector3.new(0, 1.5, 0) - head.Position).Unit
	return look:Dot(to) > 0.85
end

-- Noise propagates through the room graph; closed doors on the way muffle it.
function LodgerService:Hear(source: Vector3, loudness: number)
	if not root or brain.State == "Dormant" or brain.State == "Withdraw" then
		return
	end
	local from, to = cellOf(source), cellOf(root.Position)
	local muffle = 1
	if from and to then
		local r = CellGraph.Route(CellService.Graph, from, to, function()
			return true
		end)
		if r then
			local closed = CellGraph.ClosedDoorsAlong(CellService.Graph, r, function(openingId)
				return InteractionService:IsDoorClosed(openingId)
			end)
			muffle = Cfg.DoorMuffle ^ closed
		end
	end
	local d = (source - root.Position).Magnitude
	local heard = loudness * muffle * math.clamp(1 - d / Cfg.HearingRange, 0, 1)
	if heard > noise then
		noise = heard
		lastKnown = source
	end
end

function LodgerService:IsActive(): boolean
	return brain.State ~= "Dormant"
end

function LodgerService:State(): string
	return brain.State
end

function LodgerService:DistanceTo(p: Player): number
	local r = PlayerService:GetRoot(p)
	if not root or not r then
		return math.huge
	end
	return (r.Position - root.Position).Magnitude
end

--[[
	Wakes the Lodger to hunt `p`. It appears inside an echo of p's own route, in a worn cell,
	somewhere p can see (first meeting) or out of sight (later). Returns false if nowhere fits.
]]
function LodgerService:Wake(p: Player, first: boolean): boolean
	if brain.State ~= "Dormant" then
		return false
	end
	local head = PlayerService:GetHead(p)
	if not head then
		return false
	end
	local wantVisible = first
	local ago = EchoService:FindVisibleStretch(
		p,
		30,
		EchoConfig.HistorySeconds - 20,
		head.Position,
		22,
		60,
		function(wp)
			local c = cellOf(wp)
			if not c or not canEnter(c) then
				return false
			end
			return HorrorEventService.VisibleFrom(p, wp) == wantVisible
		end,
		nil
	)
	if not ago then
		return false
	end
	local path = EchoService:Segment(p, ago, 14)
	if not path or #path.Samples < 4 then
		return false
	end
	local s1 = path.Samples[1]
	if not spawnRig(p, LayoutSpace.ToWorld(s1.X, s1.Y, s1.Z)) then
		return false
	end
	target = p
	LodgerBrain.Wake(brain)
	-- While mimicking it looks like an echo: grey and translucent. It turns solid when it deviates.
	setLook(0.35, true)
	local pts = {}
	for i = 2, #path.Samples do
		local s = path.Samples[i]
		table.insert(pts, LayoutSpace.ToWorld(s.X, s.Y, s.Z))
	end
	setRoute(pts)
	if humanoid then
		humanoid.WalkSpeed = PlayerConfig.WalkSpeed -- walks exactly at the player's pace while it pretends
	end
	AnalyticsService:Log(p, "LodgerWake", { First = first, Ago = ago })
	return true
end

local function visibleToAnyone(at: Vector3): boolean
	for _, p in Players:GetPlayers() do
		if HorrorEventService.VisibleFrom(p, at) then
			return true
		end
	end
	return false
end

local function anyoneLookingAtMe(): boolean
	for _, p in Players:GetPlayers() do
		if lookingAtMe(p) then
			return true
		end
	end
	return false
end

--[[
	Where to go when backing off. Home (the laundry) is often clean dust it can't reach, so the
	fallback is the reachable worn cell farthest from the target whose centre nobody can see.
]]
local function withdrawRoute(): { Vector3 }
	local home = CollectionService:GetTagged("LodgerHome")[1] :: BasePart?
	local pts = if home then computePath(home.Position) else nil
	if pts then
		return pts
	end
	if not root then
		return {}
	end
	local myCell = cellOf(root.Position)
	local tRoot = if target then PlayerService:GetRoot(target) else nil
	local from = if tRoot then tRoot.Position else root.Position
	local best: Vector3?, bestScore = nil, -math.huge
	for _, id in CellService.Graph.Order do
		if id ~= myCell and canEnter(id) and reachable(myCell, id) then
			local r = CellService.Graph.Cells[id].Rect
			local centre = LayoutSpace.ToWorld((r[1] + r[3]) / 2, 3, (r[2] + r[4]) / 2)
			if not visibleToAnyone(centre) then
				local score = (centre - from).Magnitude
				if score > bestScore then
					best, bestScore = centre, score
				end
			end
		end
	end
	return if best then computePath(best) or {} else {}
end

local function enterState(s: string)
	if rig then
		rig:SetAttribute("State", s)
	end
	LodgerService.StateChanged:Fire(s, target)
	if s == "Deviate" then
		stopMoving()
		setLook(0, false)
	elseif s == "Pursue" then
		if humanoid then
			humanoid.WalkSpeed = Cfg.PursueSpeed
		end
		lastRepath = 0
	elseif s == "Search" then
		if humanoid then
			humanoid.WalkSpeed = Cfg.WalkSpeed
		end
		stopMoving()
	elseif s == "Withdraw" then
		if humanoid then
			humanoid.WalkSpeed = Cfg.WalkSpeed
		end
		withdrawUntil = os.clock() + 8
		withdrawGiveUpAt = os.clock() + Cfg.WithdrawGiveUpSeconds
		setRoute(withdrawRoute())
		HorrorEventService:RestoreLights()
	elseif s == "Take" then
		stopMoving()
		local victim = target
		if victim then
			local vh = victim.Character and victim.Character:FindFirstChildOfClass("Humanoid")
			if vh then
				vh.WalkSpeed = 0
			end
			Net.Fire(victim, "Taken", { LodgerPosition = root and root.Position })
			AnalyticsService:Log(victim, "Taken", { Cell = CellService:GetCell(victim) })
			LodgerService.Took:Fire(victim)
			task.delay(4, function()
				PlayerService:Respawn(victim)
			end)
		end
		task.delay(1.5, function()
			LodgerBrain.Finish(brain) -- Take -> Withdraw
			enterState("Withdraw")
		end)
	elseif s == "Dormant" then
		local t = target
		despawn()
		target = nil
		LodgerService.Withdrew:Fire(t)
	end
end

local function faceTarget()
	if not root or not target then
		return
	end
	local tr = PlayerService:GetRoot(target)
	if tr then
		local flat = Vector3.new(tr.Position.X, root.Position.Y, tr.Position.Z)
		if (flat - root.Position).Magnitude > 0.1 then
			root.CFrame = CFrame.lookAt(root.Position, flat)
		end
	end
end

local function tick(dt: number)
	if brain.State == "Dormant" then
		return
	end
	if not rig or not root or not humanoid or not rig.Parent then
		LodgerBrain.Finish(brain)
		brain.State = "Dormant"
		enterState("Dormant")
		return
	end
	local t = target
	local hasTarget = t ~= nil and t.Parent ~= nil and PlayerService:IsAlive(t)
	local tRoot = if hasTarget and t then PlayerService:GetRoot(t) else nil
	local visible = hasTarget and t ~= nil and canSee(t)
	local dist = if tRoot then (tRoot.Position - root.Position).Magnitude else math.huge
	local myCell = cellOf(root.Position)
	local tCell = if tRoot then cellOf(tRoot.Position) else nil
	if visible and tRoot then
		lastKnown = tRoot.Position
	end
	-- Running and wading are loud.
	if hasTarget and t and tRoot then
		local speed = PlayerService:GetSpeed(t)
		local loud = 0
		if PlayerService:GetStance(t) == "Run" and speed > PlayerConfig.RunSpeedThreshold then
			loud = 0.55
		end
		if tCell and CellService:HasTag(tCell, "Water") and speed > 1 then
			loud = math.max(loud, 0.6)
		end
		if loud > 0 then
			LodgerService:Hear(tRoot.Position, loud)
		end
	end

	local routeDone = #route == 0 or routeIndex > #route
	local changed = LodgerBrain.Step(brain, {
		Dt = dt,
		HasTarget = hasTarget,
		TargetVisible = visible,
		TargetDistance = dist,
		TargetReachable = tCell ~= nil and canEnter(tCell) and reachable(myCell, tCell),
		TargetLookingAtMe = hasTarget and t ~= nil and lookingAtMe(t),
		HeardLoudness = noise,
		RouteDone = routeDone and (brain.State :: string) ~= "Withdraw"
			or (
				(brain.State :: string) == "Withdraw"
				and os.clock() > withdrawUntil
				and (
					not visibleToAnyone(root.Position)
					-- Never stand frozen in plain view: past the give-up time it leaves when nobody is looking.
					or (os.clock() > withdrawGiveUpAt and not anyoneLookingAtMe())
				)
			),
	}, Cfg)
	noise = 0
	if changed then
		enterState(changed)
		if changed == "Dormant" then
			return
		end
	end

	local s = brain.State
	if s == "Mimic" or s == "Withdraw" then
		followRoute()
	elseif s == "Deviate" then
		faceTarget()
	elseif s == "Pursue" and tRoot then
		local now = os.clock()
		if now - lastRepath >= Cfg.RepathSeconds or #route == 0 then
			lastRepath = now
			local pts = computePath(tRoot.Position)
			if pts then
				setRoute(pts)
			end
		end
		followRoute()
	elseif s == "Search" then
		if lastKnown then
			local c = cellOf(lastKnown)
			if c and canEnter(c) and #route == 0 then
				local pts = computePath(lastKnown)
				if pts then
					setRoute(pts)
				end
				lastKnown = nil
			end
		end
		if followRoute() then
			faceTarget() -- stands at the edge of clean dust, facing you
		end
	end
	openDoorsNear()
	if walkTrack then
		local moving = root.AssemblyLinearVelocity.Magnitude > 1
		if moving and not walkTrack.IsPlaying then
			walkTrack:Play(0.2)
		elseif not moving and walkTrack.IsPlaying then
			walkTrack:Stop(0.3)
		end
	end
end

function LodgerService:Init(registry)
	PlayerService = registry.PlayerService
	CellService = registry.CellService
	WearService = registry.WearService
	EchoService = registry.EchoService
	InteractionService = registry.InteractionService
	HorrorEventService = registry.HorrorEventService
	AnalyticsService = registry.AnalyticsService
	InteractionService.Noise:Connect(function(_p, pos: Vector3, loudness: number)
		LodgerService:Hear(pos, loudness)
	end)
	Players.PlayerRemoving:Connect(function(p)
		if p == target then
			target = nil
		end
	end)
end

function LodgerService:Start()
	-- A loop rather than Heartbeat: path computation yields, and ticks must not overlap.
	while true do
		local dt = task.wait(TICK)
		local ok, err = pcall(tick :: any, dt)
		if not ok then
			warn("[Lodger] tick failed: " .. tostring(err))
		end
	end
end

return LodgerService

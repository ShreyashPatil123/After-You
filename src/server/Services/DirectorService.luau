--!strict
--[[
	The Horror Director (plan §J): one pacing model per player, chooses events through
	Logic/EventSelector, never spams. In Studio it also streams its state to the debug overlay.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DirectorConfig = require(Shared.Config.DirectorConfig)
local EventSelector = require(Shared.Logic.EventSelector)
local Net = require(Shared.Net)
local PacingModel = require(Shared.Logic.PacingModel)
local WearMath = require(Shared.Logic.WearMath)

type PlayerState = {
	Pacing: PacingModel.Pacing,
	History: EventSelector.History,
	PeakEventAt: number?,
}

local DirectorService = {}

local states: { [Player]: PlayerState } = {}
local rng = Random.new()
local function roll(): number
	return rng:NextNumber()
end

local PlayerService: any
local CellService: any
local WearService: any
local EchoService: any
local ObjectiveService: any
local HorrorEventService: any
local LodgerService: any
local AnalyticsService: any

local function stateFor(p: Player): PlayerState
	local s = states[p]
	if not s then
		s = { Pacing = PacingModel.New(DirectorConfig, roll), History = EventSelector.NewHistory() }
		states[p] = s
	end
	return s
end

local function isAlone(p: Player): boolean
	local r = PlayerService:GetRoot(p)
	if not r then
		return true
	end
	for _, other in Players:GetPlayers() do
		if other ~= p then
			local o = PlayerService:GetRoot(other)
			if o and (o.Position - r.Position).Magnitude < 25 then
				return false
			end
		end
	end
	return true
end

local function cellLit(cell: string?): boolean
	if not cell then
		return false
	end
	for _, f in CollectionService:GetTagged("RoomLight") do
		if f:GetAttribute("CellId") == cell then
			local l = f:FindFirstChildWhichIsA("Light")
			if l and l.Enabled then
				return true
			end
		end
	end
	return false
end

local function context(p: Player, s: PlayerState): EventSelector.Context
	local cell = CellService:GetCell(p)
	return {
		State = s.Pacing.State,
		Progress = ObjectiveService:Progress(),
		Cell = cell,
		CellTags = CellService:Tags(cell),
		CellWear = if cell then WearService:Get(cell) else 0,
		Alone = isAlone(p),
		EchoHistorySeconds = EchoService:HistorySeconds(p),
		Flags = ObjectiveService:GetFlags(),
	}
end

local function tickPlayer(p: Player, dt: number, now: number)
	local s = stateFor(p)
	if not PlayerService:IsAlive(p) then
		return
	end
	local cell = CellService:GetCell(p)
	local changed = PacingModel.Step(s.Pacing, {
		Dt = dt,
		Running = PlayerService:GetStance(p) == "Run" and PlayerService:GetSpeed(p) > 1,
		Dark = not cellLit(cell),
		LodgerNear = LodgerService:IsActive() and LodgerService:DistanceTo(p) < 30,
	}, DirectorConfig, roll)
	if changed then
		AnalyticsService:Log(p, "Pacing", { State = changed, Tension = math.floor(s.Pacing.Tension) })
	end
	-- A Peak resolves a little after its major beat, or when the Lodger leaves.
	if
		s.Pacing.State == "Peak"
		and s.PeakEventAt
		and now - s.PeakEventAt > 15
		and not LodgerService:IsActive()
	then
		PacingModel.ResolvePeak(s.Pacing)
		s.PeakEventAt = nil
	end
	local st = s.Pacing.State
	if st ~= "Build" and st ~= "Peak" then
		return
	end
	if st == "Peak" and s.PeakEventAt then
		return -- one major beat per peak
	end
	local ctx = context(p, s)
	local def = EventSelector.Select(HorrorEventService.Defs, ctx, s.History, now, DirectorConfig, roll)
	if def and HorrorEventService:Play(p, def) then
		EventSelector.Record(s.History, def, now, DirectorConfig)
		PacingModel.AddTension(s.Pacing, 6 + def.Intensity * 5)
		if st == "Peak" then
			s.PeakEventAt = now
		end
		AnalyticsService:Log(p, "Event", { Id = def.Id, State = st, Cell = cell })
	elseif def then
		-- Selected but could not be built here (e.g. no visible history): short back-off.
		s.History.LastByEvent[def.Id] = now - def.Cooldown + 10
	end
end

local function debugPush(now: number)
	if not RunService:IsStudio() then
		return
	end
	local wear = {}
	for id, w in WearService:All() do
		wear[id] = WearMath.ToByte(w)
	end
	for _, p in Players:GetPlayers() do
		local s = states[p]
		if s then
			local reasons = {}
			local ctx = context(p, s)
			for _, d in HorrorEventService.Defs do
				reasons[d.Id] = EventSelector.Ineligible(d, ctx, s.History, now, DirectorConfig) or "ready"
			end
			Net.Fire(p, "DebugState", {
				Pacing = s.Pacing.State,
				PacingTime = math.floor(s.Pacing.StateTime),
				PacingDuration = math.floor(s.Pacing.StateDuration),
				Tension = math.floor(s.Pacing.Tension),
				Cell = CellService:GetCell(p),
				Wear = wear,
				Lodger = LodgerService:State(),
				Events = reasons,
				Progress = ObjectiveService:Progress(),
			})
		end
	end
end

-- Studio-only: lets the debug overlay force an event or a pacing state while tuning.
function DirectorService:Force(p: Player, what: string): boolean
	local s = stateFor(p)
	if what == "Build" or what == "Peak" or what == "Relax" or what == "Fade" then
		PacingModel.Enter(s.Pacing, what :: any, DirectorConfig, roll)
		return true
	end
	local def = HorrorEventService:Get(what)
	return def ~= nil and HorrorEventService:Play(p, def)
end

function DirectorService:Init(registry)
	PlayerService = registry.PlayerService
	CellService = registry.CellService
	WearService = registry.WearService
	EchoService = registry.EchoService
	ObjectiveService = registry.ObjectiveService
	HorrorEventService = registry.HorrorEventService
	LodgerService = registry.LodgerService
	AnalyticsService = registry.AnalyticsService

	LodgerService.Took:Connect(function(p: Player)
		local s = stateFor(p)
		PacingModel.ForceRelax(s.Pacing, DirectorConfig.PostDeathRelaxSeconds, DirectorConfig, roll)
		s.PeakEventAt = nil
	end)
	LodgerService.Withdrew:Connect(function(p: Player?)
		if p and states[p] and states[p].Pacing.State == "Peak" then
			PacingModel.ResolvePeak(states[p].Pacing)
			states[p].PeakEventAt = nil
		end
	end)
	HorrorEventService.Played:Connect(function(p: Player, def)
		-- Scripted events (not chosen here) still count toward spacing and history.
		if def.Scripted then
			local s = stateFor(p)
			EventSelector.Record(s.History, def, os.clock(), DirectorConfig)
			if def.Intensity >= DirectorConfig.MajorIntensity then
				PacingModel.Enter(s.Pacing, "Peak", DirectorConfig, roll)
				s.PeakEventAt = os.clock()
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		states[p] = nil
	end)
end

function DirectorService:Start()
	while true do
		local dt = task.wait(DirectorConfig.TickSeconds)
		local now = os.clock()
		for _, p in Players:GetPlayers() do
			local ok, err = pcall(tickPlayer :: any, p, dt, now)
			if not ok then
				warn("[Director] " .. tostring(err))
			end
		end
		debugPush(now)
	end
end

return DirectorService

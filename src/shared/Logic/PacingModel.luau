--!strict
--[[
	Per-player pacing state (Left 4 Dead director pattern: build-up, peak, fade, relax).
	Pure: callers own time and randomness. MASTER_IMPLEMENTATION_PLAN.md §J.2.
]]
export type StateName = "Relax" | "Build" | "Peak" | "Fade"
export type Pacing = {
	State: StateName,
	StateTime: number,
	StateDuration: number,
	Tension: number,
	PeakResolved: boolean,
}
export type Inputs = {
	Dt: number,
	Running: boolean,
	Dark: boolean,
	LodgerNear: boolean,
}

local PacingModel = {}

local function durationFor(cfg: any, state: StateName, rng: () -> number): number
	local s = cfg.States[state]
	local lo = s.MinSeconds or s.MaxSeconds
	local hi = s.MaxSeconds or lo
	return lo + (hi - lo) * rng()
end

function PacingModel.New(cfg: any, rng: () -> number): Pacing
	return {
		State = "Relax",
		StateTime = 0,
		StateDuration = durationFor(cfg, "Relax", rng),
		Tension = 0,
		PeakResolved = false,
	}
end

function PacingModel.Enter(p: Pacing, state: StateName, cfg: any, rng: () -> number, duration: number?)
	p.State = state
	p.StateTime = 0
	p.StateDuration = duration or durationFor(cfg, state, rng)
	p.PeakResolved = false
end

function PacingModel.AddTension(p: Pacing, amount: number)
	p.Tension = math.clamp(p.Tension + amount, 0, 100)
end

-- Called by the Director when the Peak's major beat has played out.
function PacingModel.ResolvePeak(p: Pacing)
	p.PeakResolved = true
end

-- Advances time and returns the new state name if a transition happened.
function PacingModel.Step(p: Pacing, input: Inputs, cfg: any, rng: () -> number): StateName?
	local dt = input.Dt
	p.StateTime += dt
	local gain = 0
	if input.Running then
		gain += cfg.TensionFromRunPerSecond
	end
	if input.Dark then
		gain += cfg.TensionFromDarkPerSecond
	end
	if input.LodgerNear then
		gain += cfg.TensionFromLodgerNearPerSecond
	end
	p.Tension = math.clamp(p.Tension + (gain - cfg.TensionDecayPerSecond) * dt, 0, 100)

	local s = p.State
	local nextState: StateName? = nil
	if s == "Relax" then
		if p.StateTime >= p.StateDuration then
			nextState = "Build"
		end
	elseif s == "Build" then
		if p.Tension >= cfg.BuildToPeakTension or p.StateTime >= p.StateDuration then
			nextState = "Peak"
		end
	elseif s == "Peak" then
		if p.PeakResolved or p.StateTime >= p.StateDuration then
			nextState = "Fade"
		end
	elseif s == "Fade" then
		if p.StateTime >= p.StateDuration then
			nextState = "Relax"
		end
	end
	if nextState then
		PacingModel.Enter(p, nextState, cfg, rng)
	end
	return nextState
end

-- Death or a scripted beat forces a long relax.
function PacingModel.ForceRelax(p: Pacing, seconds: number, cfg: any, rng: () -> number)
	PacingModel.Enter(p, "Relax", cfg, rng, seconds)
	p.Tension = math.min(p.Tension, 20)
end

return PacingModel

--!strict
--[[
	The Lodger's decision logic as a pure state machine (§I.2). LodgerService gathers perception
	into a Snapshot, calls Step, and carries out the returned state. No Roblox APIs here.
]]
export type State = "Dormant" | "Mimic" | "Deviate" | "Pursue" | "Search" | "Withdraw" | "Take"
export type Brain = {
	State: State,
	StateTime: number,
	Menace: number,
	SinceSeen: number,
}
export type Snapshot = {
	Dt: number,
	HasTarget: boolean,
	TargetVisible: boolean,
	TargetDistance: number,
	TargetReachable: boolean, -- target's cell is worn enough and connected through worn cells
	TargetLookingAtMe: boolean,
	HeardLoudness: number, -- 0..1 after attenuation
	RouteDone: boolean, -- current movement goal reached / echo route finished
}

local LodgerBrain = {}

function LodgerBrain.New(): Brain
	return { State = "Dormant", StateTime = 0, Menace = 0, SinceSeen = math.huge }
end

local function enter(b: Brain, s: State)
	b.State = s
	b.StateTime = 0
end

function LodgerBrain.Wake(b: Brain)
	if b.State == "Dormant" then
		enter(b, "Mimic")
		b.Menace = 0
		b.SinceSeen = math.huge
	end
end

function LodgerBrain.Finish(b: Brain)
	-- Take sequence or withdraw route complete.
	if b.State == "Take" then
		enter(b, "Withdraw")
	elseif b.State == "Withdraw" then
		enter(b, "Dormant")
	end
end

-- Returns the new state if it changed.
function LodgerBrain.Step(b: Brain, s: Snapshot, cfg: any): State?
	local before = b.State
	b.StateTime += s.Dt
	if s.TargetVisible then
		b.SinceSeen = 0
	else
		b.SinceSeen += s.Dt
	end

	-- Menace gauge: pressure on the player builds while it is close and seen; it must back off when full.
	if b.State ~= "Dormant" and b.State ~= "Withdraw" then
		if s.HasTarget and s.TargetDistance < cfg.MenaceNearDistance and s.TargetVisible then
			b.Menace = math.min(1, b.Menace + cfg.MenaceRisePerSecondNear * s.Dt)
		else
			b.Menace = math.max(0, b.Menace - cfg.MenaceDecayPerSecond * s.Dt)
		end
	end

	local st = b.State
	if st == "Dormant" or st == "Take" or st == "Withdraw" then
		-- Leaving these is driven by Wake/Finish.
		if st == "Withdraw" and s.RouteDone then
			enter(b, "Dormant")
		end
	elseif not s.HasTarget then
		enter(b, "Withdraw")
	elseif b.Menace >= cfg.MenaceWithdrawAt then
		enter(b, "Withdraw")
	elseif st == "Mimic" then
		local noticed = s.TargetVisible and s.TargetLookingAtMe and s.TargetDistance < 45
		if noticed or s.HeardLoudness >= 0.5 then
			enter(b, "Deviate")
		elseif s.RouteDone then
			-- The echo's route ran out near the player: it stops and turns to them (the deviation beat).
			if s.TargetVisible or s.TargetDistance <= cfg.MimicDeviateDistance then
				enter(b, "Deviate")
			else
				enter(b, "Withdraw")
			end
		end
	elseif st == "Deviate" then
		if b.StateTime >= cfg.DeviateHoldSeconds then
			enter(b, if s.TargetReachable then "Pursue" else "Search")
		end
	elseif st == "Pursue" then
		if s.TargetReachable and s.TargetDistance <= cfg.CatchDistance then
			enter(b, "Take")
		elseif not s.TargetReachable then
			enter(b, "Search") -- holds at the edge of clean dust
		elseif b.SinceSeen >= cfg.LoseSightSeconds and s.HeardLoudness < 0.3 then
			enter(b, "Search")
		end
	elseif st == "Search" then
		if s.TargetReachable and (s.TargetVisible or s.HeardLoudness >= 0.4) then
			enter(b, "Pursue")
		elseif b.StateTime >= cfg.SearchSeconds then
			enter(b, "Withdraw")
		end
	end
	if b.State ~= before then
		return b.State
	end
	return nil
end

return LodgerBrain

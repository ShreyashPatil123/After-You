-- Unit tests for pure modules. Run: luau tests/run.luau (from the game folder)
local passed, failed = 0, 0
local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end
local function eq(a: any, b: any, msg: string?)
	if a ~= b then
		error((msg or "") .. " expected " .. tostring(b) .. " got " .. tostring(a), 2)
	end
end
local function near(a: number, b: number, tol: number, msg: string?)
	if math.abs(a - b) > tol then
		error((msg or "") .. " expected ~" .. b .. " got " .. a, 2)
	end
end

local WearMath = require("../src/shared/Logic/WearMath")
local EchoCodec = require("../src/shared/Logic/EchoCodec")
local CellGraph = require("../src/shared/Logic/CellGraph")
local PacingModel = require("../src/shared/Logic/PacingModel")
local EventSelector = require("../src/shared/Logic/EventSelector")
local LodgerBrain = require("../src/shared/Logic/LodgerBrain")
local RingBuffer = require("../src/shared/Util/RingBuffer")
local Signal = require("../src/shared/Util/Signal")
local Layout = require("../src/shared/Config/LevelLayout")
local DirectorConfig = require("../src/shared/Config/DirectorConfig")
local LodgerConfig = require("../src/shared/Config/LodgerConfig")

test("wear decays by half over one half-life", function()
	near(WearMath.Decay(0.8, 360, 360), 0.4, 1e-9)
	eq(WearMath.Decay(0, 10, 360), 0)
end)
test("wear clamps and round-trips through a byte", function()
	eq(WearMath.Add(0.9, 0.5), 1)
	eq(WearMath.Add(0.1, -1), 0)
	near(WearMath.FromByte(WearMath.ToByte(0.5)), 0.5, 1 / 255)
end)
test("seconds until below threshold", function()
	near(WearMath.SecondsUntilBelow(1, 0.25, 360), 720, 1e-6)
	eq(WearMath.SecondsUntilBelow(0.1, 0.25, 360), 0)
end)

test("echo codec round trip", function()
	local path = {
		Interval = 0.25,
		Quantum = 0.25,
		Samples = {
			{ X = 10.13, Y = 3, Z = -4.5, Yaw = 1.0, Flags = 1 },
			{ X = -100.6, Y = 3.2, Z = 8, Yaw = 6.2, Flags = 3 },
		},
		Actions = { { Index = 2, Kind = EchoCodec.ActionKind.DoorOpen, Id = "Door4B" } },
	}
	local out = EchoCodec.Decode(EchoCodec.Encode(path))
	eq(#out.Samples, 2)
	near(out.Samples[1].X, 10.25, 1e-6) -- quantised to 0.25
	near(out.Samples[2].X, -100.5, 1e-6)
	near(out.Samples[2].Yaw, 6.2, 2 * math.pi / 256)
	eq(out.Samples[2].Flags, 3)
	eq(out.Actions[1].Id, "Door4B")
	eq(out.Actions[1].Kind, EchoCodec.ActionKind.DoorOpen)
	near(out.Interval, 0.25, 1e-6)
end)

test("ring buffer keeps newest items in order", function()
	local r = RingBuffer.new(3)
	for i = 1, 5 do
		r:Push(i)
	end
	eq(r:Size(), 3)
	eq(r:Get(1), 3)
	eq(r:Get(3), 5)
	eq(r:Get(4), nil)
	eq(r.Total, 5)
end)

test("signal fires and disconnects", function()
	local s = Signal.new()
	local n = 0
	local c = s:Connect(function(x)
		n += x
	end)
	s:Once(function(x)
		n += 10 * x
	end)
	s:Fire(1)
	s:Fire(1)
	c:Disconnect()
	s:Fire(1)
	eq(n, 12)
end)

local graph = CellGraph.Build(Layout)
test("layout graph: every cell reachable from the stairwell", function()
	for _, id in graph.Order do
		local r = CellGraph.Route(graph, "StairA", id, function()
			return true
		end)
		assert(r ~= nil, "unreachable " .. id)
	end
end)
test("layout graph: cell lookup", function()
	eq(CellGraph.CellAt(graph, 30, 4), "CorrW")
	eq(CellGraph.CellAt(graph, 100, 20), "R4D")
	eq(CellGraph.CellAt(graph, 500, 500), nil)
end)
test("route avoids unworn cells", function()
	local worn = { CorrW = true, R4E = true, CorrE = true, Laundry = true }
	local r = CellGraph.Route(graph, "Laundry", "CorrW", function(id)
		return worn[id] == true
	end)
	assert(r)
	eq(r[1], "Laundry")
	eq(r[#r], "CorrW")
	local blocked = CellGraph.Route(graph, "CorrE", "R4D", function(id)
		return id ~= "R4D"
	end)
	eq(blocked, nil)
end)
test("openings sit on the edge of the cells they connect", function()
	for _, o in Layout.Openings do
		for _, cid in o.Cells do
			local r = graph.Cells[cid].Rect
			local onEdge
			if o.Axis == "X" then
				onEdge = (o.At == r[1] or o.At == r[3]) and o.Center >= r[2] and o.Center <= r[4]
			else
				onEdge = (o.At == r[2] or o.At == r[4]) and o.Center >= r[1] and o.Center <= r[3]
			end
			assert(onEdge, o.Id .. " not on edge of " .. cid)
		end
	end
end)

local seq = 0
local function rng()
	seq = (seq * 1103515245 + 12345) % 2147483648
	return seq / 2147483648
end

test("pacing cycles relax -> build -> peak -> fade -> relax", function()
	local p = PacingModel.New(DirectorConfig, rng)
	local seen = {}
	for _ = 1, 2000 do
		local s = PacingModel.Step(
			p,
			{ Dt = 1, Running = false, Dark = true, LodgerNear = false },
			DirectorConfig,
			rng
		)
		if s then
			table.insert(seen, s)
		end
	end
	eq(seen[1], "Build")
	eq(seen[2], "Peak")
	eq(seen[3], "Fade")
	eq(seen[4], "Relax")
end)
test("running raises tension into peak sooner", function()
	local p = PacingModel.New(DirectorConfig, rng)
	PacingModel.Enter(p, "Build", DirectorConfig, rng, 1000)
	local t = 0
	while p.State == "Build" and t < 1000 do
		PacingModel.Step(p, { Dt = 1, Running = true, Dark = false, LodgerNear = true }, DirectorConfig, rng)
		t += 1
	end
	assert(t < 20, "took " .. t)
end)

local defs = {
	{ Id = "A", Category = "EchoSound", Intensity = 1, Cooldown = 60, Weight = 1, States = { "Build" } },
	{
		Id = "B",
		Category = "EchoFigure",
		Intensity = 4,
		Cooldown = 60,
		Weight = 1,
		States = { "Peak" },
		Requires = { Tags = { "LongCorridor" }, PlayerAlone = true },
	},
	{
		Id = "S",
		Category = "Lodger",
		Intensity = 5,
		Cooldown = 0,
		Weight = 1,
		States = { "Peak" },
		Scripted = true,
	},
}
local function ctx(state, tags)
	return {
		State = state,
		Progress = 1,
		Cell = "CorrW",
		CellTags = tags,
		CellWear = 0.5,
		Alone = true,
		EchoHistorySeconds = 300,
		Flags = {},
	}
end
test("selector respects state, tags, scripted and cooldown", function()
	local h = EventSelector.NewHistory()
	eq(EventSelector.Select(defs, ctx("Build", {}), h, 100, DirectorConfig, rng).Id, "A")
	eq(EventSelector.Select(defs, ctx("Peak", {}), h, 100, DirectorConfig, rng), nil)
	eq(EventSelector.Select(defs, ctx("Peak", { "LongCorridor" }), h, 100, DirectorConfig, rng).Id, "B")
	EventSelector.Record(h, defs[1], 100, DirectorConfig)
	eq(EventSelector.Ineligible(defs[1], ctx("Build", {}), h, 130, DirectorConfig), "cooldown")
	eq(EventSelector.Ineligible(defs[1], ctx("Build", {}), h, 110, DirectorConfig), "cooldown")
	eq(EventSelector.Ineligible(defs[2], ctx("Peak", { "LongCorridor" }), h, 110, DirectorConfig), "spacing")
	EventSelector.Record(h, defs[2], 200, DirectorConfig)
	eq(
		EventSelector.Ineligible(defs[2], ctx("Peak", { "LongCorridor" }), h, 300, DirectorConfig),
		"majorSpacing"
	)
end)
test("selector penalises recently used categories", function()
	local h = EventSelector.NewHistory()
	EventSelector.Record(h, defs[1], 0, DirectorConfig)
	near(EventSelector.Weight(defs[1], h, DirectorConfig), DirectorConfig.RecentCategoryPenalty, 1e-9)
end)

local function snap(o)
	local s = {
		Dt = 0.5,
		HasTarget = true,
		TargetVisible = false,
		TargetDistance = 50,
		TargetReachable = true,
		TargetLookingAtMe = false,
		HeardLoudness = 0,
		RouteDone = false,
	}
	for k, v in o do
		s[k] = v
	end
	return s
end
test("lodger: mimic -> deviate when seen -> pursue -> take", function()
	local b = LodgerBrain.New()
	LodgerBrain.Wake(b)
	eq(b.State, "Mimic")
	LodgerBrain.Step(
		b,
		snap({ TargetVisible = true, TargetLookingAtMe = true, TargetDistance = 30 }),
		LodgerConfig
	)
	eq(b.State, "Deviate")
	for _ = 1, 10 do
		LodgerBrain.Step(b, snap({ TargetVisible = true, TargetDistance = 20 }), LodgerConfig)
	end
	eq(b.State, "Pursue")
	LodgerBrain.Step(b, snap({ TargetVisible = true, TargetDistance = 2 }), LodgerConfig)
	eq(b.State, "Take")
	LodgerBrain.Finish(b)
	eq(b.State, "Withdraw")
end)
test("lodger: mimic route ending near the player deviates, far away withdraws", function()
	local b = LodgerBrain.New()
	LodgerBrain.Wake(b)
	LodgerBrain.Step(b, snap({ RouteDone = true, TargetDistance = 24 }), LodgerConfig)
	eq(b.State, "Deviate")
	local far = LodgerBrain.New()
	LodgerBrain.Wake(far)
	LodgerBrain.Step(far, snap({ RouteDone = true, TargetDistance = 120 }), LodgerConfig)
	eq(far.State, "Withdraw")
end)
test("lodger: stops at clean dust and gives up", function()
	local b = LodgerBrain.New()
	LodgerBrain.Wake(b)
	b.State = "Pursue"
	LodgerBrain.Step(
		b,
		snap({ TargetVisible = true, TargetDistance = 6, TargetReachable = false }),
		LodgerConfig
	)
	eq(b.State, "Search")
	for _ = 1, 40 do
		LodgerBrain.Step(b, snap({ TargetVisible = false, TargetReachable = false }), LodgerConfig)
	end
	eq(b.State, "Withdraw")
end)
test("lodger: menace gauge forces withdraw", function()
	local b = LodgerBrain.New()
	LodgerBrain.Wake(b)
	b.State = "Search"
	for _ = 1, 40 do
		LodgerBrain.Step(
			b,
			snap({ TargetVisible = true, TargetDistance = 10, TargetReachable = false }),
			LodgerConfig
		)
	end
	eq(b.State, "Withdraw")
end)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error("tests failed")
end

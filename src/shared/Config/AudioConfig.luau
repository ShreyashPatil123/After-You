--!strict
-- Mix buses and per-sound defaults. Volumes are linear.
return {
	Buses = {
		Ambience = 0.6,
		World = 1.0,
		Player = 0.8,
		Echo = 0.85,
		Lodger = 1.0,
		UI = 0.7,
	},
	-- Distance attenuation curves: {[distance] = volume}
	Curves = {
		Default = { [0] = 1, [10] = 0.7, [40] = 0.25, [90] = 0 },
		Footstep = { [0] = 1, [6] = 0.6, [30] = 0.15, [60] = 0 },
		Far = { [0] = 1, [30] = 0.6, [120] = 0.15, [200] = 0 },
	},
	AcousticSimulation = true,
	-- Fallback occlusion when acoustic simulation is off: low-pass when the ray to the emitter is blocked.
	OcclusionFallback = { CheckSeconds = 0.25, BlockedFrequency = 900, OpenFrequency = 20000 },
}

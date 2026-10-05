-- Beat 4: your own footsteps, one step behind you. Stop and they stop a beat later.
return {
	Id = "BehindYou",
	Category = "EchoSound",
	Intensity = 1,
	Cooldown = 240,
	Weight = 1.2,
	States = { "Build" },
	Requires = { Tags = { "LongCorridor" } },
	MaxPlaysPerSession = 2,
	Params = { Duration = 9, Lag = 1.0 },
}

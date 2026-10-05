-- Beat 8: your own flashlight beam sweeps a corridor you already left.
return {
	Id = "LightReplay",
	Category = "EchoLight",
	Intensity = 2,
	Cooldown = 220,
	Weight = 0.9,
	States = { "Build" },
	Requires = { Tags = { "LongCorridor" }, EchoHistorySeconds = 60 },
	MaxPlaysPerSession = 2,
	Params = { Duration = 6, MinAgo = 45, MaxAgo = 240, MinDistance = 18, MaxDistance = 70 },
}

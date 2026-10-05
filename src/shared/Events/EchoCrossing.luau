-- Beat 10: a copy of you crosses the far end of the corridor, walking your earlier route.
return {
	Id = "EchoCrossing",
	Category = "EchoFigure",
	Intensity = 3,
	Cooldown = 240,
	Weight = 1,
	States = { "Build", "Peak" },
	Requires = { Tags = { "LongCorridor" }, PlayerAlone = true, EchoHistorySeconds = 60 },
	MaxPlaysPerSession = 3,
	Params = { Duration = 7, MinAgo = 45, MaxAgo = 240, MinDistance = 20, MaxDistance = 80 },
}

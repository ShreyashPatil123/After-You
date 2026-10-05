-- Beat 8: a door you used opens and closes again exactly as you did. Only you see it.
return {
	Id = "DoorReplay",
	Category = "EchoObject",
	Intensity = 2,
	Cooldown = 200,
	Weight = 1,
	States = { "Build" },
	Requires = { EchoHistorySeconds = 60 },
	MaxPlaysPerSession = 3,
	Params = { MinAgo = 45, MaxAgo = 240, MaxDistance = 50, MinDistance = 10 },
}

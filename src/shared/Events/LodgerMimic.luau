-- After the first meeting: the Lodger walks one of your old routes, waiting to be noticed.
return {
	Id = "LodgerMimic",
	Category = "Lodger",
	Intensity = 5,
	Cooldown = 300,
	Weight = 1,
	States = { "Peak" },
	Requires = { Flag = "MetLodger", MinWearInCell = 0.25, EchoHistorySeconds = 60 },
	MaxPlaysPerSession = 3,
	Params = { First = false },
}

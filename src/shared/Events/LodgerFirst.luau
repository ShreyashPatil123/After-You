-- Beat 13 (scripted): leaving 4D with the second fuse, an echo of you stops, turns, and the lights die.
return {
	Id = "LodgerFirst",
	Category = "Lodger",
	Intensity = 5,
	Cooldown = 0,
	Weight = 0,
	States = { "Peak" },
	Scripted = true,
	Params = { First = true, LightsOut = { "CorrE" } },
}

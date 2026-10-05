-- Beat 18 (scripted payoff): as the lift doors close, your own knock comes from the corridor.
return {
	Id = "LiftKnock",
	Category = "LiftKnock",
	Intensity = 4,
	Cooldown = 0,
	Weight = 0,
	States = { "Peak" },
	Scripted = true,
	Params = { Delay = 3 },
}

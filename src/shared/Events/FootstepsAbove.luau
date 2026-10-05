-- "Nothing happens" scare: slow footsteps cross the ceiling above you.
return {
	Id = "FootstepsAbove",
	Category = "Fake",
	Intensity = 1,
	Cooldown = 300,
	Weight = 0.7,
	States = { "Build" },
	MaxPlaysPerSession = 2,
	Params = { Sound = "FootstepConcrete", Above = true, Repeat = 6 },
}

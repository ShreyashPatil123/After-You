-- "Nothing happens" scare: two knocks from inside 4A, the flat that never opens.
return {
	Id = "FakeKnock4A",
	Category = "Fake",
	Intensity = 1,
	Cooldown = 400,
	Weight = 0.7,
	States = { "Build" },
	Requires = { Cells = { "CorrW" } },
	MaxPlaysPerSession = 1,
	Params = { Sound = "DoorKnock", Opening = "Door4A", Repeat = 2 },
}

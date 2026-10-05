--!strict
--[[
	Floor 4 East greybox layout (VERTICAL_SLICE_SPEC.md §1), as plain data so it can be
	unit-tested outside Roblox. Units are studs, floor at Y = 0. Rects are {x0, z0, x1, z1}.

	Openings sit on a cell edge. Axis = which coordinate the wall is perpendicular to:
	  Axis "Z": wall runs along X at z = At, opening centred on x = Center.
	  Axis "X": wall runs along Z at x = At, opening centred on z = Center.
	Kinds:
	  Door    - hinged door, starts closed
	  Arch    - open gap, no door
	  Plastic - sealed with plastic sheeting; hold to cut, then an open gap
	  Lift    - lift doors, locked until power is restored
	  Fake    - door slab on a solid wall (knockable, never opens)
]]

export type Rect = { number }
export type CellDef = { Id: string, Rect: Rect, Tags: { string }?, FloorColor: { number }? }
export type OpeningDef = {
	Id: string,
	Kind: "Door" | "Arch" | "Plastic" | "Lift" | "Fake",
	Cells: { string },
	Axis: "X" | "Z",
	At: number,
	Center: number,
	Width: number?,
	Label: string?,
}
export type WallDef = { Axis: "X" | "Z", At: number, From: number, To: number, Cell: string }
export type PointDef = { Id: string, Kind: string, Cell: string, Pos: { number }, Data: { [string]: any }? }

local Layout = {}

Layout.Height = 11
Layout.WallThickness = 0.5
Layout.DoorWidth = 5
Layout.DoorHeight = 8
Layout.Origin = { 0, 100, 0 } -- whole floor is built at this offset (floor 4 sits above ground)

Layout.Cells = {
	{ Id = "StairA", Rect = { -12, 0, 0, 9 }, Tags = { "Stair" }, FloorColor = { 90, 90, 88 } },
	{ Id = "CorrW", Rect = { 0, 0, 60, 9 }, Tags = { "LongCorridor" }, FloorColor = { 70, 92, 74 } },
	{ Id = "CorrE", Rect = { 60, 0, 120, 9 }, Tags = { "LongCorridor" }, FloorColor = { 70, 92, 74 } },
	{ Id = "Lobby", Rect = { 120, 0, 132, 9 }, Tags = { "LiftLobby" }, FloorColor = { 80, 80, 80 } },
	{ Id = "Lift", Rect = { 132, 1.5, 138, 7.5 }, Tags = { "Lift" }, FloorColor = { 60, 60, 64 } },
	{ Id = "R4B", Rect = { 24, 9, 44, 29 }, Tags = { "Apartment" }, FloorColor = { 96, 82, 66 } },
	{ Id = "Laundry", Rect = { 64, 9, 84, 29 }, Tags = { "Laundry", "Noisy" }, FloorColor = { 84, 86, 90 } },
	{ Id = "R4D", Rect = { 90, 9, 112, 29 }, Tags = { "Apartment", "Sealed" }, FloorColor = { 96, 82, 66 } },
	{ Id = "R4E", Rect = { 40, -20, 80, 0 }, Tags = { "Apartment", "Water" }, FloorColor = { 52, 64, 76 } },
	{ Id = "Closet", Rect = { 100, -10, 112, 0 }, Tags = { "Closet" }, FloorColor = { 80, 76, 70 } },
} :: { CellDef }

Layout.Openings = {
	{ Id = "StairDoor", Kind = "Door", Cells = { "StairA", "CorrW" }, Axis = "X", At = 0, Center = 4.5 },
	{
		Id = "Dogleg",
		Kind = "Arch",
		Cells = { "CorrW", "CorrE" },
		Axis = "X",
		At = 60,
		Center = 6.75,
		Width = 4.5,
	},
	{
		Id = "LobbyArch",
		Kind = "Arch",
		Cells = { "CorrE", "Lobby" },
		Axis = "X",
		At = 120,
		Center = 4.5,
		Width = 6,
	},
	{ Id = "LiftDoor", Kind = "Lift", Cells = { "Lobby", "Lift" }, Axis = "X", At = 132, Center = 4.5 },
	{ Id = "Door4A", Kind = "Fake", Cells = { "CorrW" }, Axis = "Z", At = 9, Center = 15, Label = "4A" },
	{
		Id = "Door4B",
		Kind = "Door",
		Cells = { "CorrW", "R4B" },
		Axis = "Z",
		At = 9,
		Center = 34,
		Label = "4B",
	},
	{
		Id = "DoorLaundry",
		Kind = "Door",
		Cells = { "CorrE", "Laundry" },
		Axis = "Z",
		At = 9,
		Center = 74,
		Label = "LAUNDRY",
	},
	{
		Id = "Door4D",
		Kind = "Plastic",
		Cells = { "CorrE", "R4D" },
		Axis = "Z",
		At = 9,
		Center = 100,
		Label = "4D",
	},
	{ Id = "Door4F", Kind = "Fake", Cells = { "CorrW" }, Axis = "Z", At = 0, Center = 20, Label = "4F" },
	{
		Id = "Door4E_W",
		Kind = "Door",
		Cells = { "CorrW", "R4E" },
		Axis = "Z",
		At = 0,
		Center = 48,
		Label = "4E",
	},
	{
		Id = "Door4E_E",
		Kind = "Door",
		Cells = { "CorrE", "R4E" },
		Axis = "Z",
		At = 0,
		Center = 74,
		Label = "4E",
	},
	{
		Id = "DoorCloset",
		Kind = "Door",
		Cells = { "CorrE", "Closet" },
		Axis = "Z",
		At = 0,
		Center = 106,
		Label = "CARETAKER",
	},
} :: { OpeningDef }

-- Free-standing walls (the dog-leg chicane that breaks the corridor sightline).
Layout.ExtraWalls = {
	{ Axis = "X", At = 66, From = 4.5, To = 9, Cell = "CorrE" },
} :: { WallDef }

Layout.Points = {
	{ Id = "Spawn", Kind = "Spawn", Cell = "StairA", Pos = { -6, 3, 4.5 } },
	{
		Id = "Clipboard",
		Kind = "Note",
		Cell = "StairA",
		Pos = { -0.6, 4.5, 2 },
		Data = { NoteId = "Clipboard" },
	},
	{ Id = "Tape4B", Kind = "Tape", Cell = "R4B", Pos = { 40, 3, 26 }, Data = { TapeId = "Tape01" } },
	{ Id = "Fuse1", Kind = "Item", Cell = "Laundry", Pos = { 80, 3, 26 }, Data = { ItemId = "Fuse" } },
	{ Id = "Fuse2", Kind = "Item", Cell = "R4D", Pos = { 108, 3, 26 }, Data = { ItemId = "Fuse" } },
	{ Id = "FuseBox", Kind = "FuseBox", Cell = "Lobby", Pos = { 126, 4.5, 8.5 }, Data = { Needs = 2 } },
	{
		Id = "LightW",
		Kind = "Fluorescent",
		Cell = "CorrW",
		Pos = { 22, 10.6, 4.5 },
		Data = { Working = true },
	},
	{
		Id = "LightE",
		Kind = "Fluorescent",
		Cell = "CorrE",
		Pos = { 92, 10.6, 4.5 },
		Data = { Working = true },
	},
	{
		Id = "LightDead1",
		Kind = "Fluorescent",
		Cell = "CorrW",
		Pos = { 45, 10.6, 4.5 },
		Data = { Working = false },
	},
	{
		Id = "LightDead2",
		Kind = "Fluorescent",
		Cell = "CorrE",
		Pos = { 110, 10.6, 4.5 },
		Data = { Working = false },
	},
	{ Id = "Lamp4B", Kind = "Lamp", Cell = "R4B", Pos = { 30, 4, 25 }, Data = {} },
	{ Id = "StairWindow", Kind = "Sodium", Cell = "StairA", Pos = { -11.5, 7, 4.5 }, Data = {} },
	{ Id = "LodgerHome", Kind = "LodgerHome", Cell = "Laundry", Pos = { 70, 3, 24 } },
} :: { PointDef }

return Layout

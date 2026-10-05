--!strict
-- Recording and replay of player history. See §D.2.
return {
	SampleHz = 4,
	-- How much history each player keeps (seconds).
	HistorySeconds = 360,
	-- Echoes replay a slice of history recorded between these many seconds ago.
	MinDelaySeconds = 45,
	MaxDelaySeconds = 240,
	-- Positions are quantised to this many studs before sending.
	Quantum = 0.25,
	-- Figure echo visuals.
	FigureTransparency = 0.35,
	FigureMaxDistance = 140,
	-- "Behind you" footsteps lag the player by this many seconds.
	BehindYouLagSeconds = 1.0,
}

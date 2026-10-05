--!strict
-- Pacing. See §J. Times in seconds.
return {
	TickSeconds = 1,
	States = {
		Relax = { MinSeconds = 45, MaxSeconds = 90 },
		Build = { MaxSeconds = 240 },
		Peak = { MaxSeconds = 60 },
		Fade = { MinSeconds = 20, MaxSeconds = 35 },
	},
	BuildToPeakTension = 60,
	TensionDecayPerSecond = 0.6,
	TensionFromRunPerSecond = 1.5,
	TensionFromDarkPerSecond = 0.2,
	TensionFromLodgerNearPerSecond = 6,
	-- Event spacing.
	MinSecondsBetweenEvents = 20,
	MinSecondsBetweenMajor = 240, -- intensity >= 4
	MajorIntensity = 4,
	PostDeathRelaxSeconds = 90,
	RecentCategoryPenalty = 0.35, -- weight multiplier per recent play of the same category
	RecentWindowSeconds = 300,
}

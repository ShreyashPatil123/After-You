--!strict
-- The Lodger's perception and movement. See §I.
return {
	WalkSpeed = 8, -- players walk at 10 and run at 17, so a running player always escapes
	PursueSpeed = 11,
	AgentRadius = 1.6,
	AgentHeight = 5,
	SightRange = 60,
	SightRangeFlashlightOn = 90,
	SightConeDegrees = 110,
	HearingRange = 70, -- loudness 1.0 heard this far through open space
	DoorMuffle = 0.35, -- each closed door between multiplies loudness by this
	CatchDistance = 3.2,
	DeviateHoldSeconds = 2.2,
	SearchSeconds = 12,
	LoseSightSeconds = 4,
	-- Menace gauge (Alien: Isolation pattern). Rises while near/visible, forces Withdraw when full.
	MenaceRisePerSecondNear = 0.12,
	MenaceDecayPerSecond = 0.05,
	MenaceNearDistance = 30,
	MenaceWithdrawAt = 1.0,
	RepathSeconds = 0.6,
	-- Mimic: walk a player's echo route recorded this long ago.
	MimicDelaySeconds = 60,
}

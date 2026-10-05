--!strict
return {
	WalkSpeed = 10,
	RunSpeed = 17,
	CrouchSpeed = 5,
	CrouchCameraDrop = 1.6,
	RunSpeedThreshold = 13.5, -- server classifies horizontal speed above this as running
	CrouchSpeedThreshold = 6,
	HeadBob = { Amplitude = 0.08, Frequency = 7 },
	FieldOfView = 72,
	InteractDistance = 9,
	-- Avatar clamps so extreme avatars don't break tone (§S risks).
	BodyScaleClamp = { Min = 0.9, Max = 1.05 },
}

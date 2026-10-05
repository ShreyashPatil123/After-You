--!strict
-- Tunables for the building's memory of footsteps. See MASTER_IMPLEMENTATION_PLAN.md §D.1.
return {
	-- Wear gained per second while a player is inside a cell, by movement mode.
	GainPerSecond = {
		Still = 0.004,
		Crouch = 0.012,
		Walk = 0.03,
		Run = 0.06,
	},
	-- Extra wear for entering a cell (crossing a threshold counts more than lingering).
	EnterBonus = 0.08,
	-- Wear decays exponentially; half-life in seconds (dust settling).
	HalfLifeSeconds = 360,
	-- The Lodger may enter a cell only at or above this wear.
	LodgerThreshold = 0.25,
	-- Server tick for wear accumulation.
	TickSeconds = 0.25,
	-- Replication: send deltas at most this often, and only if a value moved by this much (0-255 scale).
	ReplicateSeconds = 0.5,
	ReplicateMinStep = 2,
}

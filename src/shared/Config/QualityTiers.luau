--!strict
export type Tier = "Low" | "Medium" | "High"
return {
	Low = { FootprintCap = 120, FlashlightShadows = false, AcousticSimulation = false, DustParticles = false },
	Medium = {
		FootprintCap = 260,
		FlashlightShadows = false,
		AcousticSimulation = true,
		DustParticles = false,
	},
	High = { FootprintCap = 400, FlashlightShadows = true, AcousticSimulation = true, DustParticles = true },
}

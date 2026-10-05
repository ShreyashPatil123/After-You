--!strict
-- Every asset reference lives here. Empty string = not sourced yet; callers skip it.
-- rbxasset:// paths ship with the Roblox client and need no upload.
return {
	Sounds = {
		FootstepLino = "rbxasset://sounds/action_footsteps_plastic.mp3",
		FootstepConcrete = "rbxasset://sounds/action_footsteps_plastic.mp3",
		FootstepWater = "rbxasset://sounds/action_footsteps_plastic.mp3",
		DoorOpen = "",
		DoorClose = "",
		DoorKnock = "",
		FlashlightClick = "",
		Breath = "",
		LodgerInhale = "",
		FluorescentHum = "",
		RoomTone = "",
		Rain = "",
		LiftPower = "",
	},
	Animations = {
		-- Default R15 walk; confirm id in Studio (S5).
		Walk = "rbxassetid://507777826",
	},
	Decals = {
		Footprint = "",
	},
}

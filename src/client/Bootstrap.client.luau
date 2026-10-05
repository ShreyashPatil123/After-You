--!strict
-- Client entry point. Order: settings and audio first (others depend on them), UI before interaction.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Loader = require(Shared.Util.Loader)

Loader.Run(script.Parent.Controllers, {
	"SettingsController",
	"AudioController",
	"UIController",
	"MovementController",
	"CameraController",
	"FlashlightController",
	"DoorController",
	"InteractionController",
	"FootprintController",
	"EchoController",
	"LodgerPresentationController",
})

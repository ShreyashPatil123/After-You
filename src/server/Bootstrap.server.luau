--!strict
-- Server entry point. Order matters: GreyboxBuilder must build the map before services look for tags.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Loader = require(Shared.Util.Loader)
local Net = require(Shared.Net)

Net.Init()

Loader.Run(script.Parent.Services, {
	"GreyboxBuilder",
	"AnalyticsService",
	"PlayerService",
	"CellService",
	"WearService",
	"InteractionService",
	"EchoService",
	"HorrorEventService",
	"ObjectiveService",
	"LodgerService",
	"DirectorService",
})

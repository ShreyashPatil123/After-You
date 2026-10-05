--!strict
-- Picks the quality tier (plan §O) and holds accessibility toggles. Overridable from the pause menu later.
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local QualityTiers = require(Shared.Config.QualityTiers)
local Signal = require(Shared.Util.Signal)

local SettingsController = {}
SettingsController.Changed = Signal.new() :: Signal.Signal<>
SettingsController.TierName = "Medium" :: QualityTiers.Tier
SettingsController.Tier = QualityTiers.Medium
SettingsController.HeadBob = true
SettingsController.ReduceFlashing = false
SettingsController.Subtitles = true

local function detectTier(): QualityTiers.Tier
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if ok and level ~= Enum.SavedQualitySetting.Automatic then
		local n = tonumber(string.match(level.Name, "%d+")) or 5
		if n <= 3 then
			return "Low"
		elseif n >= 8 then
			return "High"
		end
		return "Medium"
	end
	return if touch then "Low" else "Medium"
end

function SettingsController:SetTier(name: QualityTiers.Tier)
	self.TierName = name
	self.Tier = (QualityTiers :: any)[name]
	self.Changed:Fire()
end

function SettingsController:Init()
	self:SetTier(detectTier())
end

return SettingsController

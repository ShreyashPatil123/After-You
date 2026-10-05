--!strict
-- Playtest telemetry. For the greybox it prints to the server log in one parseable line per event;
-- swap the sink for AnalyticsService custom events once the slice is published.
local HttpService = game:GetService("HttpService")

local AnalyticsService = {}
local started = os.clock()

function AnalyticsService:Log(player: Player?, name: string, data: { [string]: any }?)
	local line = {
		t = math.floor((os.clock() - started) * 10) / 10,
		p = if player then player.UserId else 0,
		e = name,
		d = data,
	}
	print("[Telemetry] " .. HttpService:JSONEncode(line))
end

return AnalyticsService

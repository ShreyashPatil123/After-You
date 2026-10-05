--!strict
-- Pure wear arithmetic (no Roblox APIs) so it can be unit-tested.
local WearMath = {}

function WearMath.Decay(w: number, dt: number, halfLife: number): number
	if w <= 0 then
		return 0
	end
	return w * (0.5 ^ (dt / halfLife))
end

function WearMath.Add(w: number, amount: number): number
	return math.clamp(w + amount, 0, 1)
end

function WearMath.ToByte(w: number): number
	return math.clamp(math.floor(w * 255 + 0.5), 0, 255)
end

function WearMath.FromByte(b: number): number
	return b / 255
end

-- Seconds until wear w decays below threshold (0 if already below).
function WearMath.SecondsUntilBelow(w: number, threshold: number, halfLife: number): number
	if w <= threshold or threshold <= 0 then
		return 0
	end
	return halfLife * math.log(w / threshold, 2)
end

return WearMath

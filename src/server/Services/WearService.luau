--!strict
-- The building's memory of footsteps (plan §D.1). Server-authoritative; clients get byte snapshots.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local WearConfig = require(Shared.Config.WearConfig)
local WearMath = require(Shared.Logic.WearMath)

local WearService = {}
-- Fires when a cell crosses the Lodger threshold (cellId, nowEnterable).
WearService.ThresholdCrossed = Signal.new() :: Signal.Signal<string, boolean>

local wear: { [string]: number } = {}
local sentBytes: { [string]: number } = {}
local CellService: any
local PlayerService: any

function WearService:Get(cellId: string): number
	return wear[cellId] or 0
end

function WearService:CanLodgerEnter(cellId: string): boolean
	return (wear[cellId] or 0) >= WearConfig.LodgerThreshold
end

function WearService:Add(cellId: string, amount: number)
	local before = wear[cellId] or 0
	local after = WearMath.Add(before, amount)
	wear[cellId] = after
	local t = WearConfig.LodgerThreshold
	if (before < t) ~= (after < t) then
		WearService.ThresholdCrossed:Fire(cellId, after >= t)
	end
end

function WearService:All(): { [string]: number }
	return table.clone(wear)
end

local function movementMode(player: Player): string
	local speed = PlayerService:GetSpeed(player)
	if speed < 0.5 then
		return "Still"
	end
	local stance = PlayerService:GetStance(player)
	if stance == "Crouch" then
		return "Crouch"
	end
	if speed >= require(Shared.Config.PlayerConfig).RunSpeedThreshold then
		return "Run"
	end
	return "Walk"
end

local function snapshot(force: boolean)
	local changed = force
	local out: { [string]: number } = {}
	for id, w in wear do
		local b = WearMath.ToByte(w)
		out[id] = b
		if math.abs(b - (sentBytes[id] or 0)) >= WearConfig.ReplicateMinStep then
			changed = true
		end
	end
	if changed then
		sentBytes = out
		Net.FireAll("WearSnapshot", out)
	end
end

function WearService:Init(registry)
	CellService = registry.CellService
	PlayerService = registry.PlayerService
	for _, id in CellService.Graph.Order do
		wear[id] = 0
	end
	CellService.CellChanged:Connect(function(_player, _old, new)
		if new then
			WearService:Add(new, WearConfig.EnterBonus)
		end
	end)
	Players.PlayerAdded:Connect(function(p)
		task.defer(function()
			Net.Fire(p, "WearSnapshot", sentBytes)
		end)
	end)
end

function WearService:Start()
	local tick = WearConfig.TickSeconds
	local sinceSend = 0
	while true do
		local dt = task.wait(tick)
		for id, w in wear do
			local d = WearMath.Decay(w, dt, WearConfig.HalfLifeSeconds)
			if d ~= w then
				local t = WearConfig.LodgerThreshold
				wear[id] = d
				if w >= t and d < t then
					WearService.ThresholdCrossed:Fire(id, false)
				end
			end
		end
		for _, p in Players:GetPlayers() do
			local cell = CellService:GetCell(p)
			if cell then
				WearService:Add(cell, WearConfig.GainPerSecond[movementMode(p)] * dt)
			end
		end
		sinceSend += dt
		if sinceSend >= WearConfig.ReplicateSeconds then
			sinceSend = 0
			snapshot(false)
		end
	end
end

return WearService

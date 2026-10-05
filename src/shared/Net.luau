--!strict
--[[
	Every RemoteEvent in the game is declared here, once (MASTER_IMPLEMENTATION_PLAN §G.3, §H).
	Server: Net.Init() creates them; Net.OnServer(name, handler) validates args and rate-limits.
	Client: Net.OnClient / Net.FireServer wait for the server's instances.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

type Validator = (...any) -> boolean
type Def = { Unreliable: boolean?, RatePerSecond: number?, Validate: Validator? }

local function isInstance(v: any): boolean
	return typeof(v) == "Instance"
end

-- C->S remotes carry a validator and a rate limit. S->C remotes need neither.
local Defs: { [string]: Def } = {
	-- Client to server
	Interact = {
		RatePerSecond = 8,
		Validate = function(target, action)
			return isInstance(target) and type(action) == "string" and #action <= 16
		end,
	},
	HoldInteract = {
		RatePerSecond = 4,
		Validate = function(target, phase)
			return isInstance(target) and (phase == "Begin" or phase == "End")
		end,
	},
	Flashlight = {
		RatePerSecond = 6,
		Validate = function(on)
			return type(on) == "boolean"
		end,
	},
	Look = {
		Unreliable = true,
		RatePerSecond = 8,
		Validate = function(dir)
			return typeof(dir) == "Vector3" and dir.Magnitude > 0.5 and dir.Magnitude < 1.5
		end,
	},
	EventFeedback = {
		RatePerSecond = 4,
		Validate = function(token, noticed)
			return type(token) == "number" and type(noticed) == "boolean"
		end,
	},
	Stance = {
		RatePerSecond = 6,
		Validate = function(stance)
			return stance == "Walk" or stance == "Run" or stance == "Crouch"
		end,
	},
	-- Server to client
	WearSnapshot = {},
	EventPlay = {},
	Subtitle = {},
	Objective = {},
	Taken = {},
	SliceEnd = {},
	DebugState = { Unreliable = true },
}

local Net = {}
Net.Names = {} :: { [string]: string }
for name in Defs do
	Net.Names[name] = name
end

local folder: Folder? = nil
local remotes: { [string]: any } = {}

function Net.Init()
	assert(RunService:IsServer(), "Net.Init is server-only")
	local f = Instance.new("Folder")
	f.Name = "Remotes"
	for name, def in Defs do
		local r = Instance.new(if def.Unreliable then "UnreliableRemoteEvent" else "RemoteEvent")
		r.Name = name
		r.Parent = f
		remotes[name] = r
	end
	f.Parent = ReplicatedStorage
	folder = f
end

local function remote(name: string): any
	local r = remotes[name]
	if r then
		return r
	end
	assert(Defs[name], "unknown remote " .. name)
	if not folder then
		folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
	r = (folder :: Folder):WaitForChild(name)
	remotes[name] = r
	return r
end

-- Per-player token bucket so a client can't flood a remote.
local buckets: { [Player]: { [string]: { tokens: number, at: number } } } = {}
if RunService:IsServer() then
	Players.PlayerRemoving:Connect(function(p)
		buckets[p] = nil
	end)
end

local function allow(player: Player, name: string, rate: number): boolean
	local now = os.clock()
	local pb = buckets[player]
	if not pb then
		pb = {}
		buckets[player] = pb
	end
	local b = pb[name]
	if not b then
		b = { tokens = rate, at = now }
		pb[name] = b
	end
	b.tokens = math.min(rate, b.tokens + (now - b.at) * rate)
	b.at = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

function Net.OnServer(name: string, handler: (Player, ...any) -> ())
	local def = Defs[name]
	assert(def and def.Validate, name .. " is not a client-to-server remote")
	local validate = def.Validate :: Validator
	local rate = def.RatePerSecond or 4
	remote(name).OnServerEvent:Connect(function(player: Player, ...)
		if not allow(player, name, rate) then
			return
		end
		local ok, valid = pcall(validate, ...)
		if not ok or not valid then
			return
		end
		handler(player, ...)
	end)
end

function Net.Fire(player: Player, name: string, ...: any)
	remote(name):FireClient(player, ...)
end

function Net.FireAll(name: string, ...: any)
	remote(name):FireAllClients(...)
end

function Net.OnClient(name: string, handler: (...any) -> ())
	remote(name).OnClientEvent:Connect(handler)
end

function Net.FireServer(name: string, ...: any)
	remote(name):FireServer(...)
end

return Net

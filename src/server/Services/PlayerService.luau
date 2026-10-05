--!strict
-- Character setup, stance (server-authoritative speeds), flashlight, look direction, respawn.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local Signal = require(Shared.Util.Signal)

export type Stance = "Walk" | "Run" | "Crouch"

local PlayerService = {}
PlayerService.Respawned = Signal.new() :: Signal.Signal<Player>
PlayerService.FlashlightChanged = Signal.new() :: Signal.Signal<Player, boolean>

local stance: { [Player]: Stance } = {}
local look: { [Player]: Vector3 } = {}
local flashlight: { [Player]: boolean } = {}
local checkpoint: CFrame? = nil

local SCALE_VALUES = { "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" }

local function speedFor(s: Stance): number
	if s == "Run" then
		return PlayerConfig.RunSpeed
	elseif s == "Crouch" then
		return PlayerConfig.CrouchSpeed
	end
	return PlayerConfig.WalkSpeed
end

local function setupCharacter(player: Player, character: Model)
	character.Archivable = true -- echo figures and the Lodger are cloned from the character
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.WalkSpeed = speedFor(stance[player] or "Walk")
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	-- Clamp avatar proportions so extreme avatars don't break the tone (plan §S).
	for _, name in SCALE_VALUES do
		local v = humanoid:FindFirstChild(name)
		if v and v:IsA("NumberValue") then
			v.Value = math.clamp(v.Value, PlayerConfig.BodyScaleClamp.Min, PlayerConfig.BodyScaleClamp.Max)
		end
	end
	-- Flashlight lives on the server so every player sees everyone's beam.
	local head = character:WaitForChild("Head") :: BasePart
	local att = Instance.new("Attachment")
	att.Name = "FlashlightAttachment"
	att.Position = Vector3.new(0.4, -0.3, -0.6)
	att.Parent = head
	local spot = Instance.new("SpotLight")
	spot.Name = "Flashlight"
	spot.Angle = 42
	spot.Range = 48
	spot.Brightness = 2.2
	spot.Color = Color3.fromRGB(255, 244, 225)
	spot.Shadows = false -- clients raise this locally on the High tier
	spot.Enabled = flashlight[player] == true
	spot.Face = Enum.NormalId.Front
	spot.Parent = att
	character:SetAttribute("Flashlight", spot.Enabled)
	character:SetAttribute("Stance", stance[player] or "Walk")
	if checkpoint then
		character:PivotTo(checkpoint)
	end
end

function PlayerService:GetStance(player: Player): Stance
	return stance[player] or "Walk"
end

function PlayerService:GetRoot(player: Player): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function PlayerService:GetHead(player: Player): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("Head") :: BasePart?
end

function PlayerService:GetLook(player: Player): Vector3?
	return look[player]
end

function PlayerService:IsFlashlightOn(player: Player): boolean
	return flashlight[player] == true
end

function PlayerService:IsAlive(player: Player): boolean
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0
end

-- Horizontal speed from physics, used to classify movement on the server.
function PlayerService:GetSpeed(player: Player): number
	local root = self:GetRoot(player)
	if not root then
		return 0
	end
	local v = root.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

function PlayerService:Respawn(player: Player)
	player:LoadCharacter()
	PlayerService.Respawned:Fire(player)
end

function PlayerService:SetCheckpoint(cf: CFrame)
	checkpoint = cf
end

function PlayerService:Init()
	Players.CharacterAutoLoads = true
	local spawn = CollectionService:GetTagged("Checkpoint")[1]
	if spawn and spawn:IsA("BasePart") then
		checkpoint = spawn.CFrame + Vector3.new(0, 3, 0)
	end
	Net.OnServer("Stance", function(player, s: Stance)
		stance[player] = s
		local c = player.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if h then
			h.WalkSpeed = speedFor(s)
		end
		if c then
			c:SetAttribute("Stance", s)
		end
	end)
	Net.OnServer("Flashlight", function(player, on: boolean)
		flashlight[player] = on
		local c = player.Character
		local spot = c and c:FindFirstChild("Flashlight", true)
		if spot and spot:IsA("SpotLight") then
			spot.Enabled = on
		end
		if c then
			c:SetAttribute("Flashlight", on)
		end
		PlayerService.FlashlightChanged:Fire(player, on)
	end)
	Net.OnServer("Look", function(player, dir: Vector3)
		look[player] = dir.Unit
	end)
end

function PlayerService:Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(c)
			setupCharacter(player, c)
		end)
		if player.Character then
			setupCharacter(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		stance[p] = nil
		look[p] = nil
		flashlight[p] = nil
	end)
end

return PlayerService

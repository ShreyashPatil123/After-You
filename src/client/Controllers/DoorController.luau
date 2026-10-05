--!strict
--[[
	Animates door panels locally from the server's Open attribute (server owns collision,
	clients own the motion). EchoObject events use PlayLocal to swing a door for one player only.
]]
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local DoorController = {}

local SWING = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SLIDE = TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local function openCFrame(model: Model, panel: BasePart): CFrame
	local closed = panel:GetAttribute("ClosedCFrame") :: CFrame
	if model:GetAttribute("Kind") == "Lift" then
		return closed * CFrame.new(-panel.Size.X * 0.95, 0, 0)
	end
	-- Hinge on the panel's left edge, swing ~95 degrees.
	local hinge = closed * CFrame.new(-panel.Size.X / 2, 0, 0)
	return hinge * CFrame.Angles(0, math.rad(95), 0) * CFrame.new(panel.Size.X / 2, 0, 0)
end

local function animate(model: Model, open: boolean, info: TweenInfo?)
	local panel = model.PrimaryPart
	if not panel then
		return
	end
	local closed = panel:GetAttribute("ClosedCFrame") :: CFrame?
	if not closed or model:GetAttribute("Kind") == "Plastic" or model:GetAttribute("Kind") == "Fake" then
		return
	end
	local goal = if open then openCFrame(model, panel) else closed
	local i = info or (if model:GetAttribute("Kind") == "Lift" then SLIDE else SWING)
	TweenService:Create(panel, i, { CFrame = goal }):Play()
end

-- One player's private replay of a door (plan §N: per-player hallucinations).
function DoorController:PlayLocal(model: Model, sequence: { boolean }, gap: number)
	task.spawn(function()
		local serverOpen = model:GetAttribute("Open") == true
		for _, open in sequence do
			animate(model, open)
			task.wait(gap)
		end
		animate(model, serverOpen) -- end matching reality
	end)
end

local function track(model: Instance)
	if not model:IsA("Model") then
		return
	end
	model:GetAttributeChangedSignal("Open"):Connect(function()
		animate(model, model:GetAttribute("Open") == true)
	end)
	if model:GetAttribute("Open") == true then
		animate(model, true, TweenInfo.new(0))
	end
end

function DoorController:FindDoor(openingId: string): Model?
	for _, m in CollectionService:GetTagged("Door") do
		if m:GetAttribute("OpeningId") == openingId then
			return m :: Model
		end
	end
	return nil
end

function DoorController:Start()
	CollectionService:GetInstanceAddedSignal("Door"):Connect(track)
	for _, m in CollectionService:GetTagged("Door") do
		track(m)
	end
end

return DoorController

--!strict
--[[
	Local presentation of the Lodger (plan §M layer 7): its footsteps land a fraction late,
	a wet inhale when it deviates, breathing while it waits at the edge of clean dust.
]]
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local LodgerPresentationController = {}
local Audio: any

local FOOTSTEP_LAG = 0.18

local function track(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local root = model:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not root then
		return
	end
	local last = root.Position
	local breath: AudioPlayer? = nil
	local conn = RunService.Heartbeat:Connect(function()
		if not root.Parent then
			return
		end
		local pos = root.Position
		if ((pos - last) * Vector3.new(1, 0, 1)).Magnitude >= 4.6 then
			last = pos
			local at = pos - Vector3.new(0, 2.8, 0)
			task.delay(FOOTSTEP_LAG, function()
				Audio:Play(
					"FootstepLino",
					at,
					{ Bus = "Lodger", Volume = 0.9, Speed = 0.92, Curve = "Footstep" }
				)
			end)
		end
	end)
	model:GetAttributeChangedSignal("State"):Connect(function()
		local s = model:GetAttribute("State")
		if s == "Deviate" then
			Audio:Play("LodgerInhale", root, { Bus = "Lodger" })
		end
		if s == "Search" and not breath then
			breath = Audio:Play("Breath", root, { Bus = "Lodger", Looping = true, Volume = 0.6 })
		elseif s ~= "Search" and breath then
			Audio:Stop(breath)
			breath = nil
		end
	end)
	model.Destroying:Connect(function()
		conn:Disconnect()
		if breath then
			Audio:Stop(breath)
		end
	end)
end

function LodgerPresentationController:Init(registry)
	Audio = registry.AudioController
end

function LodgerPresentationController:Start()
	CollectionService:GetInstanceAddedSignal("Lodger"):Connect(track)
	for _, m in CollectionService:GetTagged("Lodger") do
		task.spawn(track, m)
	end
end

return LodgerPresentationController

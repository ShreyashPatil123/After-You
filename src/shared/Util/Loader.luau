--!strict
--[[
	Starts services (server) or controllers (client) in an explicit order.
	Each module returns a table with optional Init(registry) and Start() methods.
	Init runs for all modules first (wire references), then Start for all (begin work).
]]
export type Registry = { [string]: any }

local Loader = {}

function Loader.Run(container: Instance, order: { string }): Registry
	local registry: Registry = {}
	local modules = {}
	for _, name in order do
		local m = container:FindFirstChild(name)
		assert(m and m:IsA("ModuleScript"), "missing module " .. name)
		local mod = (require :: any)(m)
		registry[name] = mod
		table.insert(modules, { name = name, mod = mod })
	end
	-- Warn about modules that exist but were left out of the order list (likely a mistake).
	for _, child in container:GetChildren() do
		if child:IsA("ModuleScript") and registry[child.Name] == nil then
			warn("[Loader] " .. child.Name .. " is not in the start order and was not loaded")
		end
	end
	for _, e in modules do
		if type(e.mod.Init) == "function" then
			e.mod:Init(registry)
		end
	end
	for _, e in modules do
		if type(e.mod.Start) == "function" then
			task.spawn(function()
				e.mod:Start()
			end)
		end
	end
	return registry
end

return Loader

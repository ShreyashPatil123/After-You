--!strict
-- Owns things that need cleaning up (connections, instances, threads, functions, objects with Destroy).
-- Cleanup runs in reverse order of addition.
local Janitor = {}
Janitor.__index = Janitor

export type Janitor = typeof(setmetatable({} :: { _items: { any } }, Janitor))

function Janitor.new(): Janitor
	return setmetatable({ _items = {} }, Janitor)
end

function Janitor.Add<T>(self: Janitor, item: T): T
	table.insert(self._items, item)
	return item
end

local function clean(item: any)
	local t = typeof(item)
	if t == "function" then
		item()
	elseif t == "RBXScriptConnection" then
		item:Disconnect()
	elseif t == "Instance" then
		item:Destroy()
	elseif t == "thread" then
		pcall(task.cancel, item)
	elseif t == "table" then
		if type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		end
	end
end

function Janitor.Cleanup(self: Janitor)
	local items = self._items
	self._items = {}
	for i = #items, 1, -1 do
		clean(items[i])
	end
end

Janitor.Destroy = Janitor.Cleanup

return Janitor

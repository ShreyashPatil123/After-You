--!strict
-- Collects every event definition module in this folder. Adding an event = adding a file here
-- (plus a client presenter only if it introduces a new Category). Schema: Logic/EventSelector.
local list = {}
for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") then
		local def = (require :: any)(child)
		assert(def.Id == child.Name, "event Id must match its file name: " .. child.Name)
		table.insert(list, def)
	end
end
table.sort(list, function(a, b)
	return a.Id < b.Id
end)
return list

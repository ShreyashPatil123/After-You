--!strict
-- Room/corridor graph built from LevelLayout. Pure data, testable outside Roblox.
type Rect = { number }
type CellDef = { Id: string, Rect: Rect, Tags: { string }? }
type OpeningDef = { Id: string, Kind: string, Cells: { string } }
type Layout = { Cells: { any }, Openings: { any } }

export type Edge = { To: string, Opening: string, Kind: string }
export type CellGraph = {
	Cells: { [string]: CellDef },
	Order: { string },
	Edges: { [string]: { Edge } },
}

local CellGraph = {}

function CellGraph.Build(layout: Layout): CellGraph
	local cells: { [string]: CellDef } = {}
	local order = {}
	local edges: { [string]: { Edge } } = {}
	for _, c in layout.Cells do
		assert(cells[c.Id] == nil, "duplicate cell " .. c.Id)
		cells[c.Id] = c
		table.insert(order, c.Id)
		edges[c.Id] = {}
	end
	for _, o in layout.Openings do
		if o.Kind ~= "Fake" and #o.Cells == 2 then
			local a, b = o.Cells[1], o.Cells[2]
			assert(cells[a] and cells[b], "opening " .. o.Id .. " references unknown cell")
			table.insert(edges[a], { To = b, Opening = o.Id, Kind = o.Kind })
			table.insert(edges[b], { To = a, Opening = o.Id, Kind = o.Kind })
		end
	end
	return { Cells = cells, Order = order, Edges = edges }
end

-- Returns the cell id containing (x, z) in layout-local coordinates, or nil.
function CellGraph.CellAt(graph: CellGraph, x: number, z: number): string?
	for _, id in graph.Order do
		local r = graph.Cells[id].Rect
		if x >= r[1] and x <= r[3] and z >= r[2] and z <= r[4] then
			return id
		end
	end
	return nil
end

function CellGraph.HasTag(graph: CellGraph, id: string, tag: string): boolean
	local tags = graph.Cells[id] and graph.Cells[id].Tags
	return tags ~= nil and table.find(tags, tag) ~= nil
end

-- Breadth-first route of cell ids from `from` to `to`, only through cells where canEnter(id) is true
-- (the start cell is always allowed). Returns nil if unreachable.
function CellGraph.Route(
	graph: CellGraph,
	from: string,
	to: string,
	canEnter: (string) -> boolean,
	canPass: ((Edge) -> boolean)?
): { string }?
	if from == to then
		return { from }
	end
	if not canEnter(to) then
		return nil
	end
	local prev: { [string]: string } = {}
	local seen = { [from] = true }
	local queue = { from }
	local head = 1
	while head <= #queue do
		local cur = queue[head]
		head += 1
		for _, e in graph.Edges[cur] do
			if not seen[e.To] and canEnter(e.To) and (canPass == nil or canPass(e)) then
				seen[e.To] = true
				prev[e.To] = cur
				if e.To == to then
					local route = { to }
					local node = to
					while prev[node] do
						node = prev[node]
						table.insert(route, 1, node)
					end
					return route
				end
				table.insert(queue, e.To)
			end
		end
	end
	return nil
end

-- Number of openings of the given kinds that are "closed" between two adjacent cells along a route.
function CellGraph.ClosedDoorsAlong(
	graph: CellGraph,
	route: { string },
	isClosed: (string) -> boolean
): number
	local n = 0
	for i = 1, #route - 1 do
		for _, e in graph.Edges[route[i]] do
			if e.To == route[i + 1] then
				if isClosed(e.Opening) then
					n += 1
				end
				break
			end
		end
	end
	return n
end

return CellGraph

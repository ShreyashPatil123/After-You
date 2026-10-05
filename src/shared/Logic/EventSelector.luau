--!strict
--[[
	Chooses which horror event (if any) to play for one player. Pure.
	Event definitions live in ReplicatedStorage.Shared.Events; see §J.3 for the schema.
]]
export type Requires = {
	Tags: { string }?,
	Cells: { string }?,
	PlayerAlone: boolean?,
	MinWearInCell: number?,
	MaxWearInCell: number?,
	EchoHistorySeconds: number?,
	Flag: string?, -- a game flag that must be set (e.g. "HasTape01")
	NotFlag: string?,
}
export type EventDef = {
	Id: string,
	Category: string,
	Intensity: number,
	MinProgress: number?,
	Cooldown: number,
	Weight: number,
	States: { string },
	Requires: Requires?,
	MaxPlaysPerSession: number?,
	Scripted: boolean?, -- only fired by scripted triggers, never selected by the Director
}
export type Context = {
	State: string,
	Progress: number,
	Cell: string?,
	CellTags: { string },
	CellWear: number,
	Alone: boolean,
	EchoHistorySeconds: number,
	Flags: { [string]: boolean },
}
export type History = {
	LastByEvent: { [string]: number },
	PlaysByEvent: { [string]: number },
	LastAny: number,
	LastMajor: number,
	Recent: { { Category: string, At: number } },
}

local EventSelector = {}

function EventSelector.NewHistory(): History
	return { LastByEvent = {}, PlaysByEvent = {}, LastAny = -math.huge, LastMajor = -math.huge, Recent = {} }
end

function EventSelector.Record(h: History, def: EventDef, now: number, cfg: any)
	h.LastByEvent[def.Id] = now
	h.PlaysByEvent[def.Id] = (h.PlaysByEvent[def.Id] or 0) + 1
	h.LastAny = now
	if def.Intensity >= cfg.MajorIntensity then
		h.LastMajor = now
	end
	table.insert(h.Recent, { Category = def.Category, At = now })
	-- Drop entries outside the recency window.
	local cutoff = now - cfg.RecentWindowSeconds
	while h.Recent[1] and h.Recent[1].At < cutoff do
		table.remove(h.Recent, 1)
	end
end

local function anyTag(have: { string }, want: { string }): boolean
	for _, t in want do
		if table.find(have, t) then
			return true
		end
	end
	return false
end

-- Returns a reason string when the event is not eligible (useful for the debug overlay), else nil.
function EventSelector.Ineligible(def: EventDef, ctx: Context, h: History, now: number, cfg: any): string?
	if def.Scripted then
		return "scripted"
	end
	if not table.find(def.States, ctx.State) then
		return "state"
	end
	if ctx.Progress < (def.MinProgress or 0) then
		return "progress"
	end
	if now - (h.LastByEvent[def.Id] or -math.huge) < def.Cooldown then
		return "cooldown"
	end
	if now - h.LastAny < cfg.MinSecondsBetweenEvents then
		return "spacing"
	end
	if def.Intensity >= cfg.MajorIntensity and now - h.LastMajor < cfg.MinSecondsBetweenMajor then
		return "majorSpacing"
	end
	if def.MaxPlaysPerSession and (h.PlaysByEvent[def.Id] or 0) >= def.MaxPlaysPerSession then
		return "maxPlays"
	end
	local r = def.Requires
	if r then
		if r.Tags and not anyTag(ctx.CellTags, r.Tags) then
			return "tags"
		end
		if r.Cells and (ctx.Cell == nil or not table.find(r.Cells, ctx.Cell)) then
			return "cell"
		end
		if r.PlayerAlone and not ctx.Alone then
			return "notAlone"
		end
		if r.MinWearInCell and ctx.CellWear < r.MinWearInCell then
			return "wearLow"
		end
		if r.MaxWearInCell and ctx.CellWear > r.MaxWearInCell then
			return "wearHigh"
		end
		if r.EchoHistorySeconds and ctx.EchoHistorySeconds < r.EchoHistorySeconds then
			return "history"
		end
		if r.Flag and not ctx.Flags[r.Flag] then
			return "flag"
		end
		if r.NotFlag and ctx.Flags[r.NotFlag] then
			return "notFlag"
		end
	end
	return nil
end

function EventSelector.Weight(def: EventDef, h: History, cfg: any): number
	local same = 0
	for _, r in h.Recent do
		if r.Category == def.Category then
			same += 1
		end
	end
	return def.Weight * (cfg.RecentCategoryPenalty ^ same)
end

-- Weighted random pick among eligible events. rng returns [0, 1).
function EventSelector.Select(
	defs: { EventDef },
	ctx: Context,
	h: History,
	now: number,
	cfg: any,
	rng: () -> number
): EventDef?
	local pool = {}
	local total = 0
	for _, def in defs do
		if EventSelector.Ineligible(def, ctx, h, now, cfg) == nil then
			local w = EventSelector.Weight(def, h, cfg)
			if w > 0 then
				total += w
				table.insert(pool, { def = def, w = w })
			end
		end
	end
	if total <= 0 then
		return nil
	end
	local pick = rng() * total
	for _, e in pool do
		pick -= e.w
		if pick < 0 then
			return e.def
		end
	end
	return pool[#pool].def
end

return EventSelector

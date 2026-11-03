--!strict
--[[
	Lobby fill rules for a 48-contender match.
	  * Launch at once when 48 humans are queued.
	  * Otherwise, after `fillAfter` s with at least `minHumans`, or after `lateFillAfter` s with
	    at least `lateMinHumans`, launch and fill the rest with labeled Stand-In bots.
	  * A single server (v1) can only ever hold 50 people, so it uses the single-server rule.
]]
local Queue = {}

export type Rules = {
	fillAfter: number,
	minHumans: number,
	lateFillAfter: number,
	lateMinHumans: number,
	singleServerFillAfter: number,
	singleServerMinHumans: number,
}

function Queue.shouldLaunch(humans: number, waited: number, size: number, rules: Rules, singleServer: boolean): (boolean, string)
	if humans <= 0 then
		return false, "empty"
	end
	if humans >= size then
		return true, "full"
	end
	if singleServer then
		if waited >= rules.singleServerFillAfter and humans >= rules.singleServerMinHumans then
			return true, "single-server-fill"
		end
		return false, "waiting"
	end
	if waited >= rules.fillAfter and humans >= rules.minHumans then
		return true, "timer-fill"
	end
	if waited >= rules.lateFillAfter and humans >= rules.lateMinHumans then
		return true, "late-fill"
	end
	return false, "waiting"
end

-- Seconds left on the visible lobby timer (nil = waiting for more players).
function Queue.secondsLeft(humans: number, waited: number, size: number, rules: Rules, singleServer: boolean): number?
	if humans <= 0 then
		return nil
	end
	if humans >= size then
		return 0
	end
	if singleServer then
		return math.max(0, rules.singleServerFillAfter - waited)
	end
	if humans >= rules.minHumans then
		return math.max(0, rules.fillAfter - waited)
	end
	if humans >= rules.lateMinHumans then
		return math.max(0, rules.lateFillAfter - waited)
	end
	return nil
end

export type Entry = { id: string, reach: string?, partner: string? }
export type Slot = { id: string, reach: string, partner: string? }

--[[
	Assigns every entry a Reach with at most `per` contenders per Reach, keeping partners
	together. Entries are humans first (in queue order); `botIds` fill the rest.
	Returns slots in plate order: partners on neighbouring plates.
]]
function Queue.assign(entries: { Entry }, botIds: { string }, reaches: { string }, per: number): { Slot }
	local count: { [string]: number } = {}
	local byReach: { [string]: { string } } = {}
	local assigned: { [string]: string } = {}
	local function free(r: string): boolean
		return (count[r] or 0) < per
	end
	local function put(id: string, r: string)
		count[r] = (count[r] or 0) + 1
		byReach[r] = byReach[r] or {}
		table.insert(byReach[r], id)
		assigned[id] = r
	end
	local function firstFree(need: number): string?
		for _, r in ipairs(reaches) do
			if per - (count[r] or 0) >= need then
				return r
			end
		end
		return nil
	end
	local byId: { [string]: Entry } = {}
	for _, e in ipairs(entries) do
		byId[e.id] = e
	end
	-- partners first (both must agree)
	for _, e in ipairs(entries) do
		local p = e.partner
		if not assigned[e.id] and p and byId[p] and byId[p].partner == e.id and not assigned[p] then
			local want = e.reach
			local r = (want and per - (count[want] or 0) >= 2) and want or firstFree(2)
			if r then
				put(e.id, r)
				put(p, r)
			end
		end
	end
	for _, e in ipairs(entries) do
		if not assigned[e.id] then
			local want = e.reach
			local r = (want and free(want)) and want or firstFree(1)
			if r then
				put(e.id, r)
			end
		end
	end
	for _, b in ipairs(botIds) do
		local r = firstFree(1)
		if not r then
			break
		end
		put(b, r)
	end
	local slots: { Slot } = {}
	for _, r in ipairs(reaches) do
		local list = byReach[r]
		if list then
			for i, id in ipairs(list) do
				local other = list[3 - i]
				table.insert(slots, { id = id, reach = r, partner = other })
			end
		end
	end
	return slots
end

return Queue

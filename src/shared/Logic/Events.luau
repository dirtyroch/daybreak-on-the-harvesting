--!strict
--[[
	Events.luau: yearly festivals on fixed UTC dates (same on every server, no live config).

	Founders' Dawn (18-30 November): the nation's holiday for the first sunrise after the Long Dark,
	timed for launch week. It brings:
	  * Archive Reel matches (every third match): a sepia broadcast of the 25th Trials, the year
	    Rusty was drawn, with a young Rusty among the Stand-Ins.
	  * Three free festival rewards earned by playing (Events.REWARDS).
	  * The Founders' Dawn Set in the shop for the festival, back every November.
	  * Gold-dawn lobby lighting and lantern strings.
]]
local Events = {}

export type Event = { id: string, name: string, month: number, fromDay: number, toDay: number, blurb: string }
Events.LIST = {
	{ id = "founders_dawn", name = "Founders' Dawn", month = 11, fromDay = 18, toDay = 30, blurb = "The whole nation celebrates the first sunrise after the Long Dark. Archive Reel matches, lanterns and free festival rewards." },
} :: { Event }

export type Reward = { id: string, need: string, count: number, label: string }
Events.REWARDS = {
	founders_dawn = {
		{ id = "banner_founders_lantern", need = "matches", count = 3, label = "Play 3 matches during the festival" },
		{ id = "tag_dawn_ribbon", need = "days", count = 3, label = "Play on 3 different festival days" },
		{ id = "fade_archive_reel", need = "archiveTop5", count = 1, label = "Finish top 5 in an Archive Reel match" },
	},
} :: { [string]: { Reward } }
Events.ARCHIVE_EVERY = 3 -- every third match during Founders' Dawn is an Archive Reel

-- Days since 1970-01-01 for a civil date (proleptic Gregorian, UTC).
function Events.daysFromCivil(y: number, m: number, d: number): number
	y -= if m <= 2 then 1 else 0
	local era = (if y >= 0 then y else y - 399) // 400
	local yoe = y - era * 400
	local mp = (m + 9) % 12
	local doy = (153 * mp + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

-- Year of a unix time (UTC).
function Events.yearOf(t: number): number
	local z = math.floor(t / 86400) + 719468
	local era = (if z >= 0 then z else z - 146096) // 146097
	local doe = z - era * 146097
	local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
	local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
	local mp = (5 * doy + 2) // 153
	local m = if mp < 10 then mp + 3 else mp - 9
	return yoe + era * 400 + (if m <= 2 then 1 else 0)
end

-- [start, finish) unix seconds of an event in a given year.
function Events.window(e: Event, year: number): (number, number)
	local a = Events.daysFromCivil(year, e.month, e.fromDay) * 86400
	local b = (Events.daysFromCivil(year, e.month, e.toDay) + 1) * 86400
	return a, b
end

function Events.byId(id: string): Event?
	for _, e in ipairs(Events.LIST) do
		if e.id == id then
			return e
		end
	end
	return nil
end

-- The event running at time t, or nil.
function Events.active(t: number): Event?
	local y = Events.yearOf(t)
	for _, e in ipairs(Events.LIST) do
		local a, b = Events.window(e, y)
		if t >= a and t < b then
			return e
		end
	end
	return nil
end

-- Does a shop week (Monday-based, as Store.week) overlap the event in any year?
function Events.weekOverlaps(id: string, weekStart: number, weekLen: number): boolean
	local e = Events.byId(id)
	if not e then
		return false
	end
	local y = Events.yearOf(weekStart)
	for yy = y - 1, y + 1 do
		local a, b = Events.window(e, yy)
		if weekStart < b and weekStart + weekLen > a then
			return true
		end
	end
	return false
end

-- The next start time of an event at or after t (for "back every November" copy).
function Events.nextStart(id: string, t: number): number?
	local e = Events.byId(id)
	if not e then
		return nil
	end
	local y = Events.yearOf(t)
	for yy = y, y + 1 do
		local a, b = Events.window(e, yy)
		if t < b then
			return math.max(a, t)
		end
	end
	return nil
end

function Events.isArchiveMatch(matchNo: number): boolean
	return matchNo % Events.ARCHIVE_EVERY == 0
end

-- Festival progress bookkeeping on the save: { id, year, matches, days = {[day]=true}, archiveTop5, got = {} }
export type Progress = { id: string, year: number, matches: number, days: { [string]: boolean }, archiveTop5: number, got: { [string]: boolean } }

function Events.progressFor(saved: any, e: Event, year: number): Progress
	if type(saved) ~= "table" or saved.id ~= e.id or saved.year ~= year then
		return { id = e.id, year = year, matches = 0, days = {}, archiveTop5 = 0, got = {} }
	end
	return saved
end

-- Record a finished festival match. Returns reward ids newly earned.
function Events.recordMatch(p: Progress, day: number, archiveTop5: boolean): { string }
	p.matches += 1
	p.days[tostring(day)] = true
	if archiveTop5 then
		p.archiveTop5 += 1
	end
	local nDays = 0
	for _ in pairs(p.days) do
		nDays += 1
	end
	local out = {}
	for _, r in ipairs(Events.REWARDS[p.id] or {}) do
		local have = if r.need == "matches" then p.matches elseif r.need == "days" then nDays else p.archiveTop5
		if have >= r.count and not p.got[r.id] then
			p.got[r.id] = true
			table.insert(out, r.id)
		end
	end
	return out
end

return Events

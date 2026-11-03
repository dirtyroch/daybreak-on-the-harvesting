--!strict
--[[
	Daily (3) and weekly (3) challenges. Every server picks the same set from the day/week number,
	so friends share the same goals. Each challenge tracks one stat. Rewards are Renown and Stars.
	Daily challenges are sized for about 3 matches; weeklies for a few sessions. They never expire
	mid-progress without warning: the panel shows "new in 5h 12m".
]]
-- Same hash as TimeUtil.hash (kept local so this module has no requires and runs in Lune tests).
local function hash(n: number): number
	return math.floor((n * 2654435761) % 4294967296)
end

local Challenges = {}

export type Def = { id: string, stat: string, goal: number, text: string, xp: number, stars: number }
export type Entry = { id: string, progress: number, done: boolean, claimed: boolean }
export type State = { key: number, list: { Entry } }

Challenges.DAILY = {
	{ id = "d_play3", stat = "matches", goal = 3, text = "Play 3 matches", xp = 120, stars = 2 },
	{ id = "d_top10", stat = "top10", goal = 1, text = "Finish in the top 10", xp = 150, stars = 2 },
	{ id = "d_knock2", stat = "knocks", goal = 2, text = "Knock out 2 contenders", xp = 140, stars = 2 },
	{ id = "d_crates8", stat = "crates", goal = 8, text = "Open 8 crates", xp = 100, stars = 1 },
	{ id = "d_gift2", stat = "gifts", goal = 2, text = "Send 2 parachute gifts from the Gallery", xp = 100, stars = 1 },
	{ id = "d_vote3", stat = "votes", goal = 3, text = "Vote on 3 hazards from the Gallery", xp = 90, stars = 1 },
	{ id = "d_token1", stat = "tokens", goal = 1, text = "Find a Jubilee Token", xp = 120, stars = 2 },
	{ id = "d_survive5", stat = "survive5", goal = 2, text = "Survive past 5:00 twice", xp = 130, stars = 2 },
	{ id = "d_hub1", stat = "hubloot", goal = 3, text = "Grab 3 items at the Sundial", xp = 110, stars = 1 },
	{ id = "d_meadow", stat = "meadow", goal = 1, text = "Loot a Gilded Meadow crate", xp = 110, stars = 1 },
	{ id = "d_snack4", stat = "snacks", goal = 4, text = "Eat 4 snacks", xp = 90, stars = 1 },
	{ id = "d_bowknock", stat = "bowknocks", goal = 1, text = "Knock someone out with a bow", xp = 140, stars = 2 },
} :: { Def }

Challenges.WEEKLY = {
	{ id = "w_play20", stat = "matches", goal = 20, text = "Play 20 matches", xp = 600, stars = 6 },
	{ id = "w_win1", stat = "wins", goal = 1, text = "Win a Jubilee", xp = 800, stars = 8 },
	{ id = "w_knock15", stat = "knocks", goal = 15, text = "Knock out 15 contenders", xp = 600, stars = 6 },
	{ id = "w_top5x3", stat = "top5", goal = 3, text = "Finish top 5 three times", xp = 700, stars = 7 },
	{ id = "w_tokens6", stat = "tokens", goal = 6, text = "Find 6 Jubilee Tokens", xp = 650, stars = 6 },
	{ id = "w_gifts10", stat = "gifts", goal = 10, text = "Send 10 gifts from the Gallery", xp = 500, stars = 5 },
	{ id = "w_partner5", stat = "partnermatches", goal = 5, text = "Play 5 matches with a partner", xp = 550, stars = 5 },
	{ id = "w_encore", stat = "encore", goal = 1, text = "Get voted back in by the Gallery", xp = 500, stars = 5 },
} :: { Def }

local byId: { [string]: Def } = {}
for _, d in ipairs(Challenges.DAILY) do
	byId[d.id] = d
end
for _, d in ipairs(Challenges.WEEKLY) do
	byId[d.id] = d
end

function Challenges.def(id: string): Def?
	return byId[id]
end

-- Pick `n` distinct challenges from a pool using a deterministic seed.
function Challenges.pick(pool: { Def }, seed: number, n: number): { Def }
	local idx = {}
	for i = 1, #pool do
		idx[i] = i
	end
	local h = hash(seed + 7)
	for i = #idx, 2, -1 do
		h = hash(h % 1000003 + i)
		local j = ((h // 4096) % i) + 1
		idx[i], idx[j] = idx[j], idx[i]
	end
	local out = {}
	for i = 1, math.min(n, #idx) do
		table.insert(out, pool[idx[i]])
	end
	return out
end

-- Make sure the state matches the current day/week key; resets when it changes.
function Challenges.ensure(s: State, pool: { Def }, key: number, n: number): boolean
	if s.key == key and #s.list == n then
		return false
	end
	s.key = key
	s.list = {}
	for _, d in ipairs(Challenges.pick(pool, key, n)) do
		table.insert(s.list, { id = d.id, progress = 0, done = false, claimed = false })
	end
	return true
end

-- Add progress for a stat. Returns the defs that just completed.
function Challenges.bump(s: State, stat: string, amount: number): { Def }
	local done = {}
	for _, e in ipairs(s.list) do
		local d = byId[e.id]
		if d and d.stat == stat and not e.done then
			e.progress = math.min(d.goal, e.progress + amount)
			if e.progress >= d.goal then
				e.done = true
				table.insert(done, d)
			end
		end
	end
	return done
end

-- Claim a completed challenge's reward (auto-claimed by the server at match end).
function Challenges.claim(s: State, id: string): Def?
	for _, e in ipairs(s.list) do
		if e.id == id and e.done and not e.claimed then
			e.claimed = true
			return byId[id]
		end
	end
	return nil
end

return Challenges

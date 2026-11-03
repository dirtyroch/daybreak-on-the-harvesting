--!nocheck
-- Unit tests for the pure logic modules, the name-swap kit and the fair-play rules.
-- Run with:  lune run tests/run
local process = require("@lune/process")
local fs = require("@lune/fs")

local Config = require("../src/shared/Config")
local Names = require("../src/shared/Names")
local Content = require("../src/shared/Content")
local Monetization = require("../src/shared/Monetization")
local DefaultData = require("../src/shared/DefaultData")
local SfxIds = require("../src/shared/SfxIds")
local Veil = require("../src/shared/Logic/Veil")
local Queue = require("../src/shared/Logic/Queue")
local Streak = require("../src/shared/Logic/Streak")
local Leveling = require("../src/shared/Logic/Leveling")
local SeasonTrack = require("../src/shared/Logic/SeasonTrack")
local Challenges = require("../src/shared/Logic/Challenges")
local Twists = require("../src/shared/Logic/Twists")
local NearMiss = require("../src/shared/Logic/NearMiss")
local Gifts = require("../src/shared/Logic/Gifts")
local Vote = require("../src/shared/Logic/Vote")
local ReachStandings = require("../src/shared/Logic/ReachStandings")
local Loot = require("../src/shared/Logic/Loot")
local Combat = require("../src/shared/Logic/Combat")
local TimeUtil = require("../src/shared/Logic/TimeUtil")
local RateLimiter = require("../src/shared/Logic/RateLimiter")
local ReceiptLedger = require("../src/shared/Logic/ReceiptLedger")
local SessionLock = require("../src/shared/Logic/SessionLock")
local Reconcile = require("../src/shared/Logic/Reconcile")

local passed, failed = 0, 0
local current = ""
local function test(name: string, fn: () -> ())
	current = name
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  ✓ " .. name)
	else
		failed += 1
		print("  ✗ " .. name .. "\n      " .. tostring(err))
	end
end
local function eq(a, b, msg)
	if a ~= b then
		error(string.format("%s: expected %s, got %s", msg or current, tostring(b), tostring(a)), 2)
	end
end
local function near(a, b, tol, msg)
	if math.abs(a - b) > (tol or 1e-6) then
		error(string.format("%s: expected ~%s, got %s", msg or current, tostring(b), tostring(a)), 2)
	end
end
local function truthy(v, msg)
	if not v then
		error(msg or (current .. ": expected truthy"), 2)
	end
end

-- ================================================================
print("Names (name-swap kit)")
test("title is Daybreak on the Harvesting", function()
	eq(Names.TITLE, "Daybreak on the Harvesting")
end)
test("24 Reaches, unique", function()
	eq(#Names.REACH_LIST, 24)
	local seen = {}
	for _, r in ipairs(Names.REACH_LIST) do
		truthy(not seen[r], "duplicate reach " .. r)
		seen[r] = true
		truthy(Names.reachIndex(r), "reachIndex " .. r)
	end
end)
test("ranks cover every prestige", function()
	for p = 0, Config.PRESTIGE_CAP do
		truthy(type(Names.rank(p)) == "string" and #Names.rank(p) > 0)
	end
end)
local function walk(dir: string, out: { string })
	for _, name in ipairs(fs.readDir(dir)) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path, out)
		elseif name:match("%.luau$") then
			table.insert(out, path)
		end
	end
	return out
end
test("the title and brand words only live in Names.luau", function()
	local banned = { Names.TITLE, "Daybreak on", "Harvesting", "Halcyon", "Rusty Dunmore", "Marigold Vane", "Monty Gleam" }
	for _, path in ipairs(walk("src", {})) do
		if not path:match("Names%.luau$") then
			-- ignore comments: brand words in comments are fine, string literals are not
			local src = fs.readFile(path):gsub("%-%-%[%[.-%]%]", "")
			for line in src:gmatch("[^\n]+") do
				local code = line:gsub("%-%-.*$", "")
				for _, w in ipairs(banned) do
					if code:find(w, 1, true) and not code:find("DaybreakHarvesting_", 1, true) then
						error(string.format("%s has hard-coded %q: %s", path, w, line))
					end
				end
			end
		end
	end
end)
test("no film/book IP words anywhere in src", function()
	local ip = { "Hunger Games", "Panem", "Katniss", "Haymitch", "Mockingjay", "Cornucopia", "District 12", "Capitol", "Sunrise on the Reaping", "Lionsgate", "Suzanne Collins" }
	for _, path in ipairs(walk("src", {})) do
		local src = fs.readFile(path)
		for _, w in ipairs(ip) do
			truthy(not src:find(w, 1, true), string.format("%s mentions %q", path, w))
		end
	end
end)

-- ================================================================
print("Config")
test("48 contenders = 24 Reaches x 2", function()
	eq(Config.MATCH_SIZE, 48)
	eq(#Names.REACH_LIST * Config.PER_REACH, Config.MATCH_SIZE)
end)
test("Veil phases are in order and keep shrinking", function()
	local last, lastEnd = Config.Map.ARENA_SIZE / 2, 0
	for i, p in ipairs(Config.VeilPhases) do
		truthy(p.at >= lastEnd, "phase " .. i .. " overlaps")
		eq(p.from, last, "phase " .. i .. " from")
		truthy(p.to < p.from, "phase " .. i .. " shrinks")
		last, lastEnd = p.to, p.at + p.dur
	end
	truthy(lastEnd <= Config.ARENA_CAP, "Veil closes before the arena cap")
	eq(#Config.VEIL_DAMAGE, #Config.VeilPhases + 1)
end)
test("gifts point at real items", function()
	for _, g in ipairs(Config.Gifts) do
		truthy(Config.Items[g.item], g.item)
	end
end)
test("loot tables point at real items", function()
	for _, t in ipairs({ Config.LootHub, Config.LootField, Config.LootMeadow }) do
		for id, w in pairs(t) do
			truthy(Config.Items[id], id)
			truthy(w > 0)
		end
	end
end)
test("weapon items point at real weapons", function()
	for id, it in pairs(Config.Items) do
		if it.weapon then
			truthy(Config.Weapons[it.weapon], id)
		end
	end
end)
test("Map parts fit Roblox's 2048-stud part limit", function()
	truthy(Config.Map.ARENA_SIZE >= 2400)
	truthy(Config.Map.ARENA_SIZE / 8 <= 2048)
end)

-- ================================================================
print("Monetization (fair play)")
test("every ID ships as 0", function()
	for k, p in pairs(Monetization.Passes) do
		eq(p.id, 0, k)
	end
	for k, p in pairs(Monetization.Products) do
		eq(p.id, 0, k)
	end
end)
test("no paid random items", function()
	truthy(Monetization.noRandomItems())
	for k, p in pairs(Monetization.Products) do
		truthy(p.kind == "boost" or p.kind == "cosmetic", k)
	end
end)
test("calm shop copy (no pressure words)", function()
	local words = { "last chance", "hurry", "limited time", "only today", "don't miss", "expires", "act now", "loot box", "mystery" }
	for k, p in pairs(Monetization.Passes) do
		for _, w in ipairs(words) do
			truthy(not (p.name .. " " .. p.desc):lower():find(w, 1, true), k .. " says " .. w)
		end
	end
	for k, p in pairs(Monetization.Products) do
		for _, w in ipairs(words) do
			truthy(not (p.name .. " " .. p.desc):lower():find(w, 1, true), k .. " says " .. w)
		end
	end
end)

-- ================================================================
print("Queue")
local rules = Config.Matchmaking
test("single server launches after 25 s with 1 player", function()
	eq((Queue.shouldLaunch(1, 10, 48, rules, true)), false)
	eq((Queue.shouldLaunch(1, 25, 48, rules, true)), true)
	eq(Queue.secondsLeft(1, 10, 48, rules, true), 15)
end)
test("cross-server waits for 16 humans or the late rule", function()
	eq((Queue.shouldLaunch(10, 100, 48, rules, false)), false)
	eq((Queue.shouldLaunch(16, 90, 48, rules, false)), true)
	eq((Queue.shouldLaunch(8, 150, 48, rules, false)), true)
	eq((Queue.shouldLaunch(48, 0, 48, rules, false)), true)
end)
test("assign fills to 48 with max 2 per Reach and keeps partners together", function()
	local entries = {
		{ id = "u1", reach = "Ashford", partner = "u2" },
		{ id = "u2", reach = "Millbrook", partner = "u1" },
		{ id = "u3", reach = "Ashford" },
		{ id = "u4", reach = "Ashford" },
	}
	local bots = {}
	for i = 1, 48 do
		table.insert(bots, "b" .. i)
	end
	local reaches = Names.REACH_LIST
	local slots = Queue.assign(entries, bots, reaches, 2)
	eq(#slots, 48)
	local per, reachOf = {}, {}
	for _, s in ipairs(slots) do
		per[s.reach] = (per[s.reach] or 0) + 1
		reachOf[s.id] = s.reach
	end
	for r, n in pairs(per) do
		truthy(n <= 2, r .. " has " .. n)
	end
	eq(reachOf.u1, reachOf.u2, "partners share a Reach")
	truthy(reachOf.u3 and reachOf.u4, "everyone placed")
end)
test("one-sided partner requests don't pair", function()
	local slots = Queue.assign({ { id = "u1", partner = "u2" }, { id = "u2" } }, {}, { "A", "B" }, 1)
	eq(#slots, 2)
end)

-- ================================================================
print("Veil")
local P = Config.VeilPhases
test("radius holds, shrinks, then holds", function()
	eq(Veil.radiusAt(0, P, 1200), 1200)
	near(Veil.radiusAt(P[1].at + P[1].dur / 2, P, 1200), (P[1].from + P[1].to) / 2)
	eq(Veil.radiusAt(P[1].at + P[1].dur + 1, P, 1200), P[1].to)
	eq(Veil.radiusAt(10000, P, 1200), 0)
end)
test("next shrink + damage by phase", function()
	local secs, to = Veil.nextShrink(0, P)
	eq(secs, P[1].at)
	eq(to, P[1].to)
	eq(Veil.damage(0, P, Config.VEIL_DAMAGE), Config.VEIL_DAMAGE[1])
	eq(Veil.damage(P[2].at, P, Config.VEIL_DAMAGE), Config.VEIL_DAMAGE[3])
	truthy(Veil.isShrinking(P[1].at + 1, P))
	truthy(not Veil.isShrinking(P[1].at - 1, P))
end)
test("outside + scaled", function()
	truthy(Veil.outside(100, 0, 50))
	truthy(not Veil.outside(10, 10, 50))
	eq(Veil.scaled(P, 0.85)[1].at, math.floor(P[1].at * 0.85))
end)

-- ================================================================
print("Streak")
test("consecutive days build the streak", function()
	local s = Streak.new()
	eq(Streak.claim(s, 100).count, 1)
	eq(Streak.claim(s, 101).count, 2)
	eq(Streak.claim(s, 101).ok, false)
	eq(Streak.claim(s, 102).count, 3)
end)
test("one free miss, then a soft reset (never back to zero)", function()
	local s = Streak.new()
	for d = 100, 109 do
		Streak.claim(s, d)
	end
	eq(s.count, 10)
	local r = Streak.claim(s, 111)
	eq(r.usedFreeMiss, true)
	eq(r.count, 11)
	local r2 = Streak.claim(s, 120)
	eq(r2.softReset, true)
	eq(r2.count, 8)
end)
test("reward scale caps at week 4", function()
	eq(Streak.rewardScale(1), 1)
	eq(Streak.rewardScale(8), 1.5)
	eq(Streak.rewardScale(100), 2.5)
end)

-- ================================================================
print("Leveling")
test("xp curve and multi-level gains", function()
	eq(Leveling.xpToNext(1), 100)
	eq(Leveling.xpToNext(3), 150)
	local s = { level = 1, xp = 0, prestige = 0 }
	eq(Leveling.add(s, 230, 50), 2)
	eq(s.level, 3)
	eq(s.xp, 5)
	eq(Leveling.totalTo(3), 225)
end)
test("cap and prestige", function()
	local s = { level = 50, xp = 0, prestige = 0 }
	Leveling.add(s, 1e6, 50)
	eq(s.level, 50)
	truthy(Leveling.canPrestige(s, 50, 4))
	truthy(Leveling.prestige(s, 50, 4))
	eq(s.level, 1)
	eq(s.prestige, 1)
	s.level, s.prestige = 50, 4
	truthy(not Leveling.prestige(s, 50, 4))
end)
test("match streak: quick requeue builds a bonus, capped", function()
	local p = { count = 0, lastEnd = 0 }
	eq(Leveling.playStreak(p, 1000, 240), 1)
	eq(Leveling.playStreak(p, 1200, 240), 2)
	eq(Leveling.playStreak(p, 1400, 240), 3)
	near(Leveling.playMult(3, 0.1, 0.5), 1.2)
	near(Leveling.playMult(20, 0.1, 0.5), 1.5)
	eq(Leveling.playStreak(p, 2000, 240), 1, "a long break just starts a new streak")
end)

-- ================================================================
print("Season Track")
test("30 tiers, every tier has a free reward, nothing random", function()
	eq(#SeasonTrack.tiers, 30)
	for i, t in ipairs(SeasonTrack.tiers) do
		truthy(t.free and t.free.name, "free " .. i)
		truthy(t.premium and t.premium.kind == "cosmetic", "premium is cosmetic " .. i)
	end
end)
test("stars -> tiers -> claims", function()
	local s = SeasonTrack.new(1)
	eq(SeasonTrack.addStars(s, 17, 8), 2)
	eq(SeasonTrack.unclaimed(s, false, 8), 2)
	truthy(SeasonTrack.claim(s, 1, "free", false, 8))
	local r, why = SeasonTrack.claim(s, 1, "free", false, 8)
	eq(r, nil)
	eq(why, "Already claimed.")
	eq((SeasonTrack.claim(s, 3, "free", false, 8)), nil, "not reached")
	eq((SeasonTrack.claim(s, 2, "premium", false, 8)), nil, "premium needs the pass")
	truthy(SeasonTrack.claim(s, 2, "premium", true, 8))
end)
test("new season resets the track", function()
	local s = SeasonTrack.new(1)
	SeasonTrack.addStars(s, 40, 8)
	truthy(SeasonTrack.ensure(s, 2))
	eq(s.stars, 0)
end)

-- ================================================================
print("Challenges")
test("pick is deterministic and distinct", function()
	local a = Challenges.pick(Challenges.DAILY, 20000, 3)
	local b = Challenges.pick(Challenges.DAILY, 20000, 3)
	eq(#a, 3)
	for i = 1, 3 do
		eq(a[i].id, b[i].id)
	end
	truthy(a[1].id ~= a[2].id and a[2].id ~= a[3].id and a[1].id ~= a[3].id)
end)
test("different days give different sets (mostly)", function()
	local diff = 0
	for d = 20000, 20013 do
		local x, y = Challenges.pick(Challenges.DAILY, d, 3), Challenges.pick(Challenges.DAILY, d + 1, 3)
		if x[1].id ~= y[1].id then
			diff += 1
		end
	end
	truthy(diff >= 7, "only " .. diff .. " of 14 days changed")
end)
test("ensure, bump, claim", function()
	local s = { key = -1, list = {} }
	truthy(Challenges.ensure(s, Challenges.WEEKLY, 2900, 3))
	truthy(not Challenges.ensure(s, Challenges.WEEKLY, 2900, 3))
	local d = Challenges.def(s.list[1].id)
	local done = Challenges.bump(s, d.stat, d.goal)
	truthy(#done >= 1)
	truthy(Challenges.claim(s, d.id))
	eq(Challenges.claim(s, d.id), nil, "only once")
end)

-- ================================================================
print("Twists")
test("weekly rotation covers every weekly rule", function()
	local seen = {}
	for w = 0, 3 do
		seen[Twists.weekly(w).id] = true
	end
	for _, t in ipairs(Twists.WEEKLY) do
		truthy(seen[t.id], t.id)
	end
end)
test("match twists vary", function()
	local seen, n = {}, 0
	for m = 1, 40 do
		local id = Twists.forMatch(m, 2900).id
		if not seen[id] then
			seen[id] = true
			n += 1
		end
	end
	truthy(n >= 5, "only " .. n .. " twists in 40 matches")
end)
test("mods multiply or replace", function()
	eq(Twists.mod({ Twists.WEEKLY[1] }, "giftCost", 1), 0.75)
	eq(Twists.mod({ Twists.WEEKLY[2] }, "tokens", 4), 6)
	eq(Twists.mod({}, "tokens", 4), 4)
end)

-- ================================================================
print("Near miss")
test("ordinals", function()
	eq(NearMiss.ordinal(1), "1st")
	eq(NearMiss.ordinal(2), "2nd")
	eq(NearMiss.ordinal(13), "13th")
	eq(NearMiss.ordinal(22), "22nd")
end)
test("second place shows the winner's Pep", function()
	local l = NearMiss.lines({ place = 2, size = 48, knocks = 3, survived = 500, bestPlace = 0, winnerPepLeft = 7 })
	truthy(l[1]:find("7 Pep"))
end)
test("new best + next goal, max 3 lines", function()
	local l = NearMiss.lines({ place = 4, size = 48, knocks = 1, survived = 400, bestPlace = 9, nextKnockGoal = 1 })
	truthy(#l <= 3)
	truthy(l[2]:find("personal best"))
	truthy(l[3]:find("1 more knock "))
end)

-- ================================================================
print("Gallery")
test("gift cost scales with the field and partner discount", function()
	eq(Gifts.cost(10, 40, false, 0.75, 1), 10)
	eq(Gifts.cost(10, 20, false, 0.75, 1), 12)
	eq(Gifts.cost(10, 3, false, 0.75, 1), 20)
	eq(Gifts.cost(10, 40, true, 0.75, 1), 8)
	eq(Gifts.cost(10, 40, false, 0.75, 0.75), 8)
end)
test("one gift per contender per cooldown", function()
	local last = {}
	truthy((Gifts.canSend(last, "x", 100, 45)))
	last.x = 100
	local ok, wait = Gifts.canSend(last, "x", 120, 45)
	eq(ok, false)
	eq(wait, 25)
	truthy((Gifts.canSend(last, "x", 146, 45)))
end)
test("votes: one per voter, ties go to the first option", function()
	local b = Vote.new({ "finches", "bloom", "supply" })
	eq(Vote.winner(b), "finches")
	truthy(Vote.cast(b, "1", "bloom"))
	truthy(Vote.cast(b, "1", "supply"))
	truthy(not Vote.cast(b, "2", "nope"))
	eq(Vote.counts(b).supply, 1)
	eq(Vote.counts(b).bloom, 0)
	eq(Vote.winner(b), "supply")
end)

-- ================================================================
print("Reach standings")
test("points, sort, banners for top 3", function()
	eq(ReachStandings.pointsFor(1, 3), 13)
	eq(ReachStandings.pointsFor(4, 0), 3)
	local t = {}
	ReachStandings.add(t, "A", 5)
	ReachStandings.add(t, "B", 9)
	ReachStandings.add(t, "C", 9)
	ReachStandings.add(t, "D", 1)
	local s = ReachStandings.sorted(t)
	eq(s[1].reach, "B")
	eq(s[2].reach, "C")
	local b = ReachStandings.banners(t)
	eq(#b, 3)
	eq(b[3], "A")
	truthy(ReachStandings.canChange(10, 11))
	truthy(not ReachStandings.canChange(11, 11))
end)

-- ================================================================
print("Loot + combat")
test("loot pick is deterministic and covers the table", function()
	local w = { a = 1, b = 1, c = 2 }
	eq(Loot.pick(w, 0), "a")
	eq(Loot.pick(w, 0.3), "b")
	eq(Loot.pick(w, 0.99), "c")
	near(Loot.odds(w).c, 0.5)
end)
test("Reach mates can't hurt each other until the final few", function()
	truthy(not Combat.canHurt("A", "A", 20, Config.ALLIES_UNTIL))
	truthy(Combat.canHurt("A", "A", Config.ALLIES_UNTIL, Config.ALLIES_UNTIL))
	truthy(Combat.canHurt("A", "B", 20, Config.ALLIES_UNTIL))
end)
test("bow falloff, hits and arcs", function()
	eq(Combat.bowDamage(22, 50, 170), 22)
	eq(Combat.bowDamage(22, 170, 170), 15)
	eq(Combat.bowDamage(22, 171, 170), 0)
	local n, ko = Combat.hit(10, 12)
	eq(n, 0)
	eq(ko, true)
	truthy(Combat.inArc({ x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 1 }, { x = 1, y = 0, z = 5 }, 70))
	truthy(not Combat.inArc({ x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 1 }, { x = 0, y = 0, z = -5 }, 70))
	truthy(Combat.ready(nil, 0, 1))
end)

-- ================================================================
print("Time + infra")
test("days and Monday weeks", function()
	eq(TimeUtil.day(86400 * 3 + 5), 3)
	eq(TimeUtil.week(0), 0, "Thu 1970-01-01 is in week 0")
	eq(TimeUtil.week(86400 * 4), 1, "Mon 1970-01-05 starts week 1")
	eq(TimeUtil.clock(125), "2:05")
end)
test("rate limiter blocks bursts", function()
	local l = RateLimiter.new(3, 1)
	truthy(RateLimiter.allow(l, "k", 0))
	truthy(RateLimiter.allow(l, "k", 0))
	truthy(RateLimiter.allow(l, "k", 0))
	truthy(not RateLimiter.allow(l, "k", 0))
	truthy(RateLimiter.allow(l, "k", 2))
end)
test("receipt ledger is idempotent and bounded", function()
	local list = {}
	ReceiptLedger.add(list, "a", 2)
	ReceiptLedger.add(list, "b", 2)
	ReceiptLedger.add(list, "c", 2)
	truthy(ReceiptLedger.has(list, "c"))
	truthy(not ReceiptLedger.has(list, "a"))
end)
test("default data reconciles", function()
	local d = DefaultData.new()
	eq(d.level, 1)
	eq(d.equipped.fade, "fade_gold")
	local old = { level = 7 }
	Reconcile.fill(old, DefaultData.new())
	eq(old.level, 7)
	truthy(old.season and old.settings and old.settings.autoQueue == true)
	truthy(SessionLock ~= nil)
end)
test("content tables are sane", function()
	eq(#Content.TOKENS, 24)
	eq(#Content.BOT_NAMES >= Config.MATCH_SIZE, true)
	truthy(Content.FADES.fade_gold)
	for name, def in pairs(SfxIds) do
		truthy(type(def.id) == "number" and def.id > 0, name)
	end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end

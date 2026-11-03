--!strict
--[[
	ProgressService — everything that keeps players coming back, all cosmetic or Renown:
	  * Contender level 1-50 and prestige ranks (Leveling)
	  * Play streak: back-to-back matches add +10% Renown each (max +50%), resets after 4 min idle
	  * Forgiving daily streak (one free miss a week, soft reset)
	  * 3 daily + 3 weekly challenges (same for everyone on a given day/week)
	  * The Season Track (free lane for all; optional premium cosmetic lane)
	  * Jubilee Token collection book
	  * Reach loyalty: weekly Reach standings and cosmetic banners for the top 3 Reaches
	  * Sponsor letters: a daily package from the patrons you've won over (Logic/Sponsors)
	  * Encore top-ups: a contender voted back in is paid for their better finish (Logic/Award)
	It also builds the "state" snapshot each client renders.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Names = require(Shared.Names)
local Content = require(Shared.Content)
local Monetization = require(Shared.Monetization)
local Leveling = require(Shared.Logic.Leveling)
local Streak = require(Shared.Logic.Streak)
local Challenges = require(Shared.Logic.Challenges)
local SeasonTrack = require(Shared.Logic.SeasonTrack)
local ReachStandings = require(Shared.Logic.ReachStandings)
local Twists = require(Shared.Logic.Twists)
local TimeUtil = require(Shared.Logic.TimeUtil)
local Sponsors = require(Shared.Logic.Sponsors)
local Award = require(Shared.Logic.Award)

local ProgressService = {}
local ctx: any = nil
local letterView: (data: any) -> any -- assigned below (sponsor letters)

export type Runtime = { passes: { [string]: boolean }, dirty: boolean }
ProgressService.runtime = {} :: { [Player]: Runtime }
ProgressService.reachTable = {} :: { [string]: number } -- this server's view of this week's points
local reachStore: OrderedDataStore? = nil

local function week(): number
	return TimeUtil.week(os.time())
end
local function today(): number
	return TimeUtil.day(os.time())
end

function ProgressService.dataOf(player: Player): any?
	local p = ctx.Data.get(player)
	return p and p.data or nil
end

function ProgressService.hasPass(player: Player, key: string): boolean
	local r = ProgressService.runtime[player]
	return r ~= nil and r.passes[key] == true
end

local function ensurePeriodic(data: any)
	Challenges.ensure(data.daily, Challenges.DAILY, today(), 3)
	Challenges.ensure(data.weekly, Challenges.WEEKLY, week(), 3)
	SeasonTrack.ensure(data.season, SeasonTrack.SEASON)
end

local function challengeView(list: { any }): { any }
	local out = {}
	for _, e in ipairs(list) do
		local d = Challenges.def(e.id)
		if d then
			table.insert(out, { id = e.id, text = d.text, goal = d.goal, progress = e.progress, done = e.done, xp = d.xp, stars = d.stars })
		end
	end
	return out
end

local tiersView: { any }? = nil
local function tiers(): { any }
	if tiersView then
		return tiersView
	end
	local t = {}
	for i, tier in ipairs(SeasonTrack.tiers) do
		t[i] = { free = tier.free.name, premium = tier.premium.name }
	end
	tiersView = t
	return t
end

function ProgressService.snapshot(player: Player): any?
	local data = ProgressService.dataOf(player)
	if not data then
		return nil
	end
	ensurePeriodic(data)
	local hasPremium = ProgressService.hasPass(player, "PremiumLane")
	local tokens = 0
	for _ in pairs(data.tokens) do
		tokens += 1
	end
	local now = os.time()
	return {
		title = Names.TITLE,
		level = data.level,
		xp = data.xp,
		xpNext = Leveling.xpToNext(data.level),
		prestige = data.prestige,
		rank = Names.rank(data.prestige),
		canPrestige = Leveling.canPrestige(data, Config.LEVEL_CAP, Config.PRESTIGE_CAP),
		stats = data.stats,
		streak = data.streak.count,
		bestStreak = data.streak.best,
		play = data.play.count,
		playMult = Leveling.playMult(data.play.count, Config.PLAY_STREAK_STEP, Config.PLAY_STREAK_MAX),
		daily = challengeView(data.daily.list),
		weekly = challengeView(data.weekly.list),
		dailyResetIn = 86400 - (now % 86400),
		season = {
			name = SeasonTrack.SEASON_NAME,
			stars = data.season.stars,
			perTier = Config.STARS_PER_TIER,
			tier = SeasonTrack.tierFor(data.season.stars, Config.STARS_PER_TIER),
			claimedFree = data.season.claimedFree,
			claimedPremium = data.season.claimedPremium,
			premium = hasPremium,
			unclaimed = SeasonTrack.unclaimed(data.season, hasPremium, Config.STARS_PER_TIER),
			tiers = tiers(),
		},
		tokens = tokens,
		tokenTotal = #Content.TOKENS,
		tokenBook = data.tokens,
		owned = data.owned,
		equipped = data.equipped,
		reach = data.reach,
		canChangeReach = ReachStandings.canChange(data.reachWeek, week()),
		reachTop = ReachStandings.sorted(ProgressService.reachTable),
		weeklyRule = Twists.weekly(week()),
		settings = data.settings,
		quip = data.quip,
		passes = ProgressService.runtime[player] and ProgressService.runtime[player].passes or {},
		shop = ctx.Purchase.availability(player),
		seenReaping = data.seenReaping,
		letters = letterView(data),
		favorBank = data.favorBank or 0,
		titleName = Content.TITLES[data.equipped.title],
	}
end

function ProgressService.sendState(player: Player)
	local snap = ProgressService.snapshot(player)
	if snap then
		ctx.push(player, "state", snap)
	end
end

function ProgressService.markDirty(player: Player)
	local r = ProgressService.runtime[player]
	if r then
		r.dirty = true
	end
end

local function giveXp(player: Player, data: any, amount: number): number
	local gained = Leveling.add(data, amount, Config.LEVEL_CAP)
	if gained > 0 then
		ctx.push(player, "levelup", { level = data.level, rank = Names.rank(data.prestige) })
	end
	return gained
end

local function finishChallenges(player: Player, data: any, done: { any })
	for _, d in ipairs(done) do
		local list = data.daily.list
		local claimed = Challenges.claim(data.daily, d.id) or Challenges.claim(data.weekly, d.id)
		if claimed then
			giveXp(player, data, claimed.xp)
			SeasonTrack.addStars(data.season, claimed.stars, Config.STARS_PER_TIER)
			ctx.push(player, "challenge", { text = claimed.text, xp = claimed.xp, stars = claimed.stars })
		end
		local _ = list
	end
end

-- In-match stat ticks (crates, knocks, gifts, votes, tokens...). Shows challenge pops right away.
function ProgressService.bump(player: Player, stat: string, amount: number?)
	local data = ProgressService.dataOf(player)
	if not data then
		return
	end
	ensurePeriodic(data)
	local n = amount or 1
	local done = Challenges.bump(data.daily, stat, n)
	for _, d in ipairs(Challenges.bump(data.weekly, stat, n)) do
		table.insert(done, d)
	end
	finishChallenges(player, data, done)
	ProgressService.markDirty(player)
end

-- How many more of `stat` finish the closest open challenge (nil if none).
function ProgressService.nextGoal(player: Player, stat: string): number?
	local data = ProgressService.dataOf(player)
	if not data then
		return nil
	end
	local best: number? = nil
	for _, s in ipairs({ data.daily, data.weekly }) do
		for _, e in ipairs(s.list) do
			local d = Challenges.def(e.id)
			if d and d.stat == stat and not e.done then
				local left = d.goal - e.progress
				if best == nil or left < best then
					best = left
				end
			end
		end
	end
	return best
end

function ProgressService.boostMult(_player: Player, data: any): number
	if data.boost and data.boost.untilT > os.time() then
		return 1 + data.boost.mult
	end
	return 1
end

function ProgressService.addBoost(data: any, minutes: number, mult: number)
	local now = os.time()
	local base = math.max(now, data.boost.untilT)
	data.boost.untilT = base + minutes * 60
	data.boost.mult = math.max(data.boost.mult or 0, mult)
end

export type MatchResult = {
	place: number,
	size: number,
	knocks: number,
	crates: number,
	tokens: number,
	gifts: number,
	votes: number,
	encore: boolean,
	survived: number,
	partner: boolean,
	bonusStars: number,
	pactKept: boolean?,
}

-- Encore fix: a contender already paid at their knockout, voted back in by the Gallery and then
-- finishing higher, gets the difference (never a second "match played").
function ProgressService.topUp(player: Player, first: MatchResult, final: MatchResult): any
	local data = ProgressService.dataOf(player)
	if not data then
		return {}
	end
	ensurePeriodic(data)
	local t = Award.topUp(first :: any, final :: any, Config.XP, Config.STARS)
	local mult = Leveling.playMult(data.play.count, Config.PLAY_STREAK_STEP, Config.PLAY_STREAK_MAX) * ProgressService.boostMult(player, data)
	local xp = math.floor(t.xp * mult)
	local levels = giveXp(player, data, xp)
	local tiersUp = SeasonTrack.addStars(data.season, t.stars, Config.STARS_PER_TIER)
	local st = data.stats
	local prevBest = st.bestPlace
	local place = math.min(first.place, final.place)
	st.knocks += t.knocks
	if t.win then
		st.wins += 1
	end
	if t.top10 then
		st.top10 += 1
	end
	if t.top5 then
		st.top5 += 1
	end
	if t.encore then
		st.encores += 1
	end
	if st.bestPlace == 0 or place < st.bestPlace then
		st.bestPlace = place
	end
	local done = {}
	local function add(stat: string, on: boolean)
		if on then
			for _, d in ipairs(Challenges.bump(data.daily, stat, 1)) do
				table.insert(done, d)
			end
			for _, d in ipairs(Challenges.bump(data.weekly, stat, 1)) do
				table.insert(done, d)
			end
		end
	end
	add("top10", t.top10)
	add("top5", t.top5)
	add("wins", t.win)
	add("encore", t.encore)
	finishChallenges(player, data, done)
	if data.reach ~= "" then
		local extra = ReachStandings.pointsFor(place, final.knocks) - ReachStandings.pointsFor(first.place, first.knocks)
		if extra > 0 then
			ProgressService.addReachPoints(data.reach, extra)
		end
	end
	ProgressService.markDirty(player)
	task.defer(ProgressService.sendState, player)
	return { xp = xp, levels = levels, level = data.level, stars = t.stars, tiersUp = tiersUp, prevBest = prevBest, topUp = true }
end

function ProgressService.grant(player: Player, id: string, why: string)
	local data = ProgressService.dataOf(player)
	if data and not data.owned[id] then
		data.owned[id] = true
		ctx.toast(player, why, "good")
		ProgressService.markDirty(player)
		task.defer(ProgressService.sendState, player)
	end
end

-- ===== Sponsor letters =====
local function letterStats(data: any): { [string]: number }
	return data.stats
end

letterView = function(data: any): any
	local signed = Sponsors.earned(Content.PATRONS :: any, letterStats(data))
	local per = { renown = 0, favor = 0 }
	local from = {}
	for _, p in ipairs(signed) do
		per.renown += p.renown
		per.favor += p.favor
		table.insert(from, p.name)
	end
	local nxt = Sponsors.nextPatron(Content.PATRONS :: any, letterStats(data))
	local every = Config.Sponsors.cosmeticEvery
	local left = 0
	for _, id in ipairs(Content.LETTER_COSMETICS) do
		if not data.owned[id] then
			left += 1
		end
	end
	return {
		waiting = data.letters.waiting,
		from = from,
		perLetter = per,
		next = nxt and { name = nxt.name, stat = nxt.stat, need = nxt.need, have = data.stats[nxt.stat] or 0 } or nil,
		cosmeticIn = left > 0 and (every - data.letters.claimed % every) or nil,
	}
end

local function deliverLetters(player: Player, data: any)
	local n = Sponsors.accrue(data.letters, TimeUtil.day(os.time()), Config.Sponsors.maxStack)
	if n > 0 then
		ProgressService.markDirty(player)
		ctx.toast(player, string.format("✉️ %d sponsor letter%s arrived! Open Letters.", data.letters.waiting, data.letters.waiting == 1 and "" or "s"), "good")
	end
end

local function claimLetters(player: Player): (boolean, string?)
	local data = ProgressService.dataOf(player)
	if not data then
		return false, nil
	end
	if data.letters.waiting <= 0 then
		return false, "No letters waiting. The next one arrives tomorrow."
	end
	local signed = Sponsors.earned(Content.PATRONS :: any, letterStats(data))
	local pkg = Sponsors.claim(data.letters, signed, Content.LETTER_COSMETICS, Config.Sponsors.cosmeticEvery, data.owned)
	giveXp(player, data, pkg.renown)
	data.favorBank = math.min(Config.Sponsors.favorCap, (data.favorBank or 0) + pkg.favor)
	local extra = ""
	for _, id in ipairs(pkg.cosmetics) do
		data.owned[id] = true
		local nm = Content.TITLES[id] or (Content.FADES[id] and Content.FADES[id].name) or id
		extra ..= " + " .. nm
	end
	ctx.push(player, "letters", { letters = pkg.letters, renown = pkg.renown, favor = pkg.favor, cosmetics = pkg.cosmetics, from = pkg.from })
	ProgressService.markDirty(player)
	ProgressService.sendState(player)
	return true, string.format("Opened %d letter%s: +%d %s, +%d %s banked%s", pkg.letters, pkg.letters == 1 and "" or "s", pkg.renown, Names.XP, pkg.favor, Names.FAVOR, extra)
end

-- Gallery asks for the banked head start when a player sits down.
function ProgressService.takeFavorBank(player: Player): number
	local data = ProgressService.dataOf(player)
	if not data or not data.favorBank or data.favorBank <= 0 then
		return 0
	end
	local n = data.favorBank
	data.favorBank = 0
	ProgressService.markDirty(player)
	return n
end

-- Called once per contender when their match ends (knocked out or at the podium).
function ProgressService.award(player: Player, r: MatchResult): any
	local data = ProgressService.dataOf(player)
	if not data then
		return {}
	end
	ensurePeriodic(data)
	local prevBest = data.stats.bestPlace
	local playCount = Leveling.playStreak(data.play, os.time(), Config.PLAY_STREAK_WINDOW)
	local playMult = Leveling.playMult(playCount, Config.PLAY_STREAK_STEP, Config.PLAY_STREAK_MAX)
	local base = Award.baseXp(r :: any, Config.XP)
	local mult = playMult * ProgressService.boostMult(player, data)
	local xp = math.floor(base * mult)
	local levels = giveXp(player, data, xp)
	-- Season stars
	local stars = Award.stars(r.place, Config.STARS, r.bonusStars)
	local tiersUp = SeasonTrack.addStars(data.season, stars, Config.STARS_PER_TIER)
	-- Daily streak counts on the first finished match of the day
	local streakMsg: string? = nil
	if Streak.canClaim(data.streak, today()) then
		local res = Streak.claim(data.streak, today())
		if res.ok then
			local bonus = math.floor(Config.DAILY_STREAK_XP * Streak.rewardScale(res.count))
			giveXp(player, data, bonus)
			streakMsg = string.format("Day %d streak! +%d %s", res.count, bonus, Names.XP)
			if res.usedFreeMiss then
				streakMsg = tostring(streakMsg) .. " (free miss used)"
			end
		end
	end
	-- Stats + challenges
	local st = data.stats
	st.matches += 1
	st.knocks += r.knocks
	if r.encore then
		st.encores += 1
	end
	if r.place == 1 then
		st.wins += 1
	end
	if r.place <= 10 then
		st.top10 += 1
	end
	if r.place <= 5 then
		st.top5 += 1
	end
	if st.bestPlace == 0 or r.place < st.bestPlace then
		st.bestPlace = r.place
	end
	local done = {}
	local function add(stat: string, n: number)
		if n > 0 then
			for _, d in ipairs(Challenges.bump(data.daily, stat, n)) do
				table.insert(done, d)
			end
			for _, d in ipairs(Challenges.bump(data.weekly, stat, n)) do
				table.insert(done, d)
			end
		end
	end
	add("matches", 1)
	add("top10", r.place <= 10 and 1 or 0)
	add("top5", r.place <= 5 and 1 or 0)
	add("wins", r.place == 1 and 1 or 0)
	add("survive5", r.survived >= 300 and 1 or 0)
	add("partnermatches", r.partner and 1 or 0)
	add("encore", r.encore and 1 or 0)
	finishChallenges(player, data, done)
	-- Reach loyalty
	if data.reach ~= "" then
		local pts = ReachStandings.pointsFor(r.place, r.knocks)
		data.reachPlayedWeek = week()
		ProgressService.addReachPoints(data.reach, pts)
	end
	ProgressService.markDirty(player)
	task.defer(ProgressService.sendState, player)
	return {
		xp = xp,
		playStreak = playCount,
		playMult = playMult,
		levels = levels,
		level = data.level,
		stars = stars,
		tiersUp = tiersUp,
		streakMsg = streakMsg,
		prevBest = prevBest,
	}
end

function ProgressService.addReachPoints(reach: string, pts: number)
	if pts <= 0 or not Names.reachIndex(reach) then
		return
	end
	ReachStandings.add(ProgressService.reachTable, reach, pts)
	local store = reachStore
	if store then
		task.spawn(function()
			pcall(function()
				store:IncrementAsync(reach, pts)
			end)
		end)
	end
end

local function refreshReachTable()
	local store = reachStore
	if not store then
		return
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, 24)
	end)
	if ok and pages then
		local page = pages:GetCurrentPage()
		local tbl = {}
		for _, row in ipairs(page) do
			tbl[row.key] = row.value
		end
		ProgressService.reachTable = tbl
	end
end

-- Last week's top 3 Reaches give a banner to everyone who repped them that week.
local function grantBanners(player: Player, data: any)
	local last = week() - 1
	if data.reachPlayedWeek ~= last or data.reach == "" then
		return
	end
	local ok, pages = pcall(function()
		return DataStoreService:GetOrderedDataStore("ReachWeek_" .. last):GetSortedAsync(false, 3)
	end)
	if not ok or not pages then
		return
	end
	local tbl = {}
	for _, row in ipairs(pages:GetCurrentPage()) do
		tbl[row.key] = row.value
	end
	for i, reach in ipairs(ReachStandings.banners(tbl)) do
		if reach == data.reach then
			local id = string.format("banner_w%d_%s", last, (reach:lower():gsub("%s+", "_")))
			if not data.owned[id] then
				data.owned[id] = true
				ctx.toast(player, string.format("%s placed #%d last week! You earned its banner.", reach, i), "good")
				ProgressService.markDirty(player)
			end
		end
	end
end

-- ===== client intents =====
local function claimTier(player: Player, tier: any, lane: any): (boolean, string?)
	local data = ProgressService.dataOf(player)
	if not data or type(tier) ~= "number" or type(lane) ~= "string" then
		return false, nil
	end
	local reward, why = SeasonTrack.claim(data.season, math.floor(tier), lane, ProgressService.hasPass(player, "PremiumLane"), Config.STARS_PER_TIER)
	if not reward then
		return false, why
	end
	if reward.kind == "renown" then
		giveXp(player, data, reward.amount or 0)
	else
		data.owned[reward.id] = true
	end
	ProgressService.markDirty(player)
	ProgressService.sendState(player)
	return true, "Claimed: " .. reward.name
end

local function prestige(player: Player): (boolean, string?)
	local data = ProgressService.dataOf(player)
	if not data then
		return false, nil
	end
	if not Leveling.prestige(data, Config.LEVEL_CAP, Config.PRESTIGE_CAP) then
		return false, "Reach level " .. Config.LEVEL_CAP .. " to prestige."
	end
	data.owned["frame_rank" .. data.prestige] = true
	ProgressService.markDirty(player)
	ProgressService.sendState(player)
	return true, "You are now " .. Names.rank(data.prestige) .. "! New frame unlocked."
end

local function setReach(player: Player, reach: any): (boolean, string?)
	local data = ProgressService.dataOf(player)
	if not data or type(reach) ~= "string" or not Names.reachIndex(reach) then
		return false, nil
	end
	if data.reach == reach then
		return true, nil
	end
	if data.reach ~= "" and not ReachStandings.canChange(data.reachWeek, week()) then
		return false, "You can change your home " .. Names.REGION .. " once a week."
	end
	data.reach = reach
	data.reachWeek = week()
	ProgressService.markDirty(player)
	ProgressService.sendState(player)
	return true, "Home " .. Names.REGION .. ": " .. reach
end

local function setting(player: Player, key: any, value: any): (boolean, string?)
	local data = ProgressService.dataOf(player)
	if not data or type(key) ~= "string" or type(value) ~= "boolean" then
		return false, nil
	end
	if key ~= "autoQueue" and key ~= "sfx" and key ~= "shortReaping" then
		return false, nil
	end
	data.settings[key] = value
	ProgressService.markDirty(player)
	ProgressService.sendState(player)
	return true, nil
end

local function setQuip(player: Player, i: any): (boolean, string?)
	local data = ProgressService.dataOf(player)
	if not data or type(i) ~= "number" or not Content.QUIPS[i] then
		return false, nil
	end
	data.quip = math.floor(i)
	ProgressService.markDirty(player)
	ProgressService.sendState(player)
	return true, nil
end

local function equip(player: Player, slot: any, id: any): (boolean, string?)
	local data = ProgressService.dataOf(player)
	if not data or type(slot) ~= "string" or type(id) ~= "string" then
		return false, nil
	end
	if slot ~= "fade" and slot ~= "banner" and slot ~= "title" then
		return false, nil
	end
	if id ~= "" and id ~= "fade_gold" and not data.owned[id] then
		return false, "Not owned yet."
	end
	data.equipped[slot] = id
	ProgressService.markDirty(player)
	ProgressService.sendState(player)
	return true, nil
end

local function seenReaping(player: Player): (boolean, string?)
	local data = ProgressService.dataOf(player)
	if data and not data.seenReaping then
		data.seenReaping = true
		ProgressService.markDirty(player)
	end
	return true, nil
end

local function onLoaded(player: Player, profile: any, isNew: boolean)
	local data = profile.data
	ensurePeriodic(data)
	ProgressService.runtime[player] = { passes = ctx.Purchase.loadPasses(player), dirty = false }
	deliverLetters(player, data)
	ProgressService.sendState(player)
	if isNew then
		ctx.toast(player, "Welcome to " .. Names.CAPITAL:gsub("^the ", "the ") .. ". Pick your home " .. Names.REGION .. " on the board!", "good")
	end
	task.spawn(grantBanners, player, data)
end

function ProgressService.init(c: any)
	ctx = c
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore("ReachWeek_" .. week())
	end)
	if ok then
		reachStore = store
	end
	ctx.handle("claimTier", claimTier)
	ctx.handle("prestige", prestige)
	ctx.handle("setReach", setReach)
	ctx.handle("setting", setting)
	ctx.handle("quip", setQuip)
	ctx.handle("equip", equip)
	ctx.handle("seenReaping", seenReaping)
	ctx.handle("claimLetters", claimLetters)
	ctx.handle("refresh", function(player: Player): (boolean, string?)
		ProgressService.sendState(player)
		return true, nil
	end)
end

function ProgressService.start()
	ctx.Data.onLoaded.Event:Connect(onLoaded)
	Players.PlayerAdded:Connect(function(player)
		ctx.Data.load(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(ctx.Data.load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		ctx.Match.onLeave(player)
		ctx.Data.release(player)
		ProgressService.runtime[player] = nil
	end)
	task.spawn(function()
		while true do
			refreshReachTable()
			for _, p in ipairs(Players:GetPlayers()) do
				local d = ProgressService.dataOf(p)
				if d then
					deliverLetters(p, d)
				end
			end
			task.wait(60)
		end
	end)
end

local _ = Monetization
return ProgressService

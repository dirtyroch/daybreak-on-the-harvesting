--!strict
-- The save file for a new contender. Reconcile fills any missing keys on load, so adding a field
-- here is always safe. Bump VERSION only for migrations.
local DefaultData = {}

DefaultData.VERSION = 1

function DefaultData.new(): any
	return {
		version = DefaultData.VERSION,
		level = 1,
		xp = 0,
		prestige = 0,
		stats = { matches = 0, wins = 0, knocks = 0, top10 = 0, top5 = 0, bestPlace = 0, gifts = 0, encores = 0 },
		streak = { lastDay = -1, count = 0, best = 0, freeMissWeek = -1 },
		play = { count = 0, lastEnd = 0 },
		daily = { key = -1, list = {} },
		weekly = { key = -1, list = {} },
		season = { season = 0, stars = 0, claimedFree = {}, claimedPremium = {} },
		tokens = {}, -- token id -> true (collection book)
		owned = {}, -- cosmetic id -> true
		equipped = { fade = "fade_gold", banner = "", title = "" },
		reach = "",
		reachWeek = -1,
		reachPlayedWeek = -1,
		banners = {}, -- "week:reach" -> true
		seenReaping = false,
		boost = { untilT = 0, mult = 0 },
		receipts = {},
		settings = { autoQueue = true, sfx = true, shortReaping = false },
		quip = 1,
		letters = { lastDay = -1, waiting = 0, claimed = 0 }, -- sponsor letters
		favorBank = 0, -- Favor head start from letters, spent on the next Gallery visit
	}
end

return DefaultData

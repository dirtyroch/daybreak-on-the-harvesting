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
		equipped = {
			fade = "fade_gold",
			banner = "",
			title = "",
			bow = "",
			spear = "",
			knife = "",
			pose = "",
			emote = "",
			wrap = "",
			nametag = "",
			parade = "",
			rusty = "",
		},
		reach = "",
		reachWeek = -1,
		reachPlayedWeek = -1,
		banners = {}, -- "week:reach" -> true
		seenReaping = false,
		boost = { untilT = 0, mult = 0 },
		receipts = {},
		settings = {
			autoQueue = true,
			sfx = true, -- master mute; false silences every bus
			shortReaping = false,
			mode = "", -- "" = auto (Modes.preferred)
			view = "third", -- "third" | "first"; presentation only, never read by combat
			reduceMotion = false,
			fov = 70, -- 60, 65 or 70. Never wider than third person.
			volumes = { master = 80, effects = 85, ambience = 40, voice = 70, ui = 55 }, -- 0–100
			muted = { effects = false, ambience = false, voice = false, ui = false },
		},
		quip = 1,
		letters = { lastDay = -1, waiting = 0, claimed = 0 }, -- sponsor letters
		favorBank = 0, -- Favor head start from letters, spent on the next Gallery visit
		-- Item Shop
		vouchers = {}, -- price (string) -> count; from receipts whose saved choice was lost
		shopFlags = {}, -- "bundle:starter" -> true (one-per-account bundles)
		spent = 0, -- lifetime Robux spent in this game (shown in Profile)
		buyLog = {}, -- last 20 purchases { t, name, price, gift }
		patronMonth = -1, -- last month the Patron Club monthly perks were granted
		shopSeenWeek = -1, -- last shop week the player opened the shop (for the "new this week" dot)
		-- v4
		mastery = {}, -- "bow:skin_bow_gilded" -> points (Mastery.luau); free progress
		memberMonth = -1, -- last month the Roblox Plus / Premium member gift was granted
		dailyTen = { day = -1, seconds = 0, claimed = false }, -- Daily Ten play bonus
		referral = { by = 0, rewarded = false, brought = 0 }, -- friend invites
		onboarding = { done = {}, finished = false, skipped = false, reopened = false, rewarded = false }, -- first-match checklist (Onboarding.luau)
		comeback = { lastSeenDay = -1, homecoming = 0, catchUpTier = 0, welcomedDay = -1 }, -- Comeback.luau
		festival = {}, -- yearly festival progress (Events.progressFor)
		shared = 0, -- moments shared with the Roblox share sheet
		shopOpenedOnce = false,
		offers = { firstWinShown = false, previewsSeen = 0 }, -- calm offer bookkeeping
	}
end

return DefaultData

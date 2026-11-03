--!strict
-- All tuning numbers in one place. Names live in Names.luau; Robux IDs in Monetization.luau.
local Config = {}

Config.VERSION = "v1.0 vertical slice"
Config.AUTOSAVE_SECONDS = 90

-- ===== Match size: exactly 48 contenders (24 Reaches x 2) =====
Config.MATCH_SIZE = 48
Config.REACH_COUNT = 24
Config.PER_REACH = 2
Config.MAX_SERVER_PLAYERS = 50 -- set Game Settings > Places > Max Players to 50

-- ===== Matchmaking =====
Config.Matchmaking = {
	-- v1 runs everything in one server. Set crossServer = true once the lobby/arena place
	-- split is published (see README "Cross-server queue").
	crossServer = false,
	fillAfter = 90, -- seconds: launch with bots if at least minHumans are queued
	minHumans = 16,
	lateFillAfter = 150, -- seconds: launch with at least lateMinHumans
	lateMinHumans = 8,
	-- single-server rules (one Roblox server can only ever hold 50 people)
	singleServerFillAfter = 25,
	singleServerMinHumans = 1,
	nextMatchSeconds = 10, -- "Next match in 10s" after the podium
}

-- ===== Map (studs). Arena centered at the origin, ground top at y = 0 =====
Config.Map = {
	ARENA_SIZE = 2400,
	HUB_RADIUS = 44,
	PLATE_RADIUS = 100,
	LOBBY_CENTER = { 0, 0, 3400 },
	GALLERY_CENTER = { 0, 420, 0 },
	MEADOW = { x = 640, z = -620, r = 340 },
	LAKE = { x = 700, z = 480, r = 250 },
	WOOD = { x = -720, z = 0, r = 470 },
	RIDGE = { x = 0, z = -900, r = 330 },
	RUINS = { x = -420, z = 760, r = 260 },
}

-- ===== Pregame ceremony (seconds; played locally, synced by the server) =====
Config.Pregame = {
	reaping = 14,
	reapingShort = 3,
	parade = 8,
	interview = 8,
	training = 8,
	launch = 10,
}
function Config.pregameTotal(): number
	local p = Config.Pregame
	return p.reaping + p.parade + p.interview + p.training
end

-- ===== Arena timeline =====
Config.ARENA_CAP = 12 * 60
Config.HARD_CAP = 12 * 60 + 30 -- if more than one is still in at 12:30, highest Pep wins
Config.PODIUM_SECONDS = 12
-- Veil phases: at time `at` the radius shrinks from `from` to `to` over `dur` seconds.
Config.VeilPhases = {
	{ at = 180, from = 1200, to = 850, dur = 60 },
	{ at = 300, from = 850, to = 550, dur = 60 },
	{ at = 420, from = 550, to = 325, dur = 60 },
	{ at = 510, from = 325, to = 175, dur = 50 },
	{ at = 600, from = 175, to = 60, dur = 60 },
	{ at = 690, from = 60, to = 0, dur = 30 },
}
Config.VEIL_WARNING = 10
Config.VEIL_DAMAGE = { 4, 5, 6, 8, 10, 12, 15 } -- Pep per second outside, by phase (index 1 = before phase 1)

-- ===== Contenders =====
Config.PEP_MAX = 100
Config.WALK_SPEED = 16
Config.SPRINT_SPEED = 24
Config.STAMINA_MAX = 100
Config.STAMINA_DRAIN = 22 -- per second while sprinting
Config.STAMINA_REGEN = 14 -- per second
Config.BACKPACK_SLOTS = 3
Config.BACKPACK_SLOTS_BIG = 6
Config.ALLIES_UNTIL = 4 -- Reach partners can't hurt each other until 4 remain

-- ===== Weapons and items =====
export type Weapon = { id: string, name: string, kind: string, damage: number, range: number, cooldown: number, arc: number?, ammo: number? }
Config.Weapons = {
	bow = { id = "bow", name = "Bow", kind = "ranged", damage = 22, range = 170, cooldown = 0.9, ammo = 8 },
	spear = { id = "spear", name = "Spear", kind = "melee", damage = 24, range = 10, cooldown = 0.8, arc = 70 },
	knife = { id = "knife", name = "Knife", kind = "melee", damage = 14, range = 7, cooldown = 0.4, arc = 70 },
	shove = { id = "shove", name = "Shove", kind = "melee", damage = 5, range = 6, cooldown = 0.6, arc = 70 },
} :: { [string]: Weapon }

export type Item = { id: string, name: string, kind: string, heal: number?, stamina: number?, weapon: string?, ammo: number? }
Config.Items = {
	bow = { id = "bow", name = "Bow", kind = "weapon", weapon = "bow" },
	spear = { id = "spear", name = "Spear", kind = "weapon", weapon = "spear" },
	knife = { id = "knife", name = "Knife", kind = "weapon", weapon = "knife" },
	arrows = { id = "arrows", name = "Arrows x6", kind = "ammo", ammo = 6 },
	backpack = { id = "backpack", name = "Backpack", kind = "backpack" },
	trailmix = { id = "trailmix", name = "Trail Mix", kind = "snack", heal = 20 },
	apple = { id = "apple", name = "Apple", kind = "snack", heal = 15, stamina = 20 },
	canteen = { id = "canteen", name = "Canteen", kind = "snack", heal = 10, stamina = 60 },
	bandage = { id = "bandage", name = "Bandage", kind = "snack", heal = 35 },
	sweettea = { id = "sweettea", name = "Rusty's Sweet Tea", kind = "snack", heal = 100, stamina = 100 },
} :: { [string]: Item }

-- Crate loot tables (weights). Hub crates are richer. Rates are shown in the Help panel.
Config.LootHub = { bow = 22, spear = 20, knife = 14, backpack = 14, arrows = 12, bandage = 10, trailmix = 8 }
Config.LootField = { knife = 16, spear = 10, bow = 8, arrows = 16, apple = 16, trailmix = 14, canteen = 10, bandage = 6, backpack = 4 }
Config.LootMeadow = { bandage = 30, bow = 20, backpack = 20, arrows = 15, canteen = 15 }
Config.HUB_CRATES = 36
Config.FIELD_CRATES = 110
Config.MEADOW_CRATES = 12
Config.TOKENS_PER_MATCH = 4

-- ===== Hazards =====
Config.Hazards = {
	finches = { warn = 5, duration = 14, radius = 24, dps = 6, speed = 15, birds = 12 },
	bloom = { warn = 5, duration = 25, dps = 4, slow = 0.6 },
	supply = { crates = 3 },
	scheduled = { { at = 240, id = "finches" }, { at = 360, id = "bloom" } },
	voteEvery = 90,
	voteFirstAt = 150,
	voteLength = 20,
}

-- ===== Viewing Gallery =====
Config.Gallery = {
	favorEvery = 5, -- seconds per +1 Favor while watching a live match
	favorStart = 10,
	giftCooldown = 45, -- per contender
	maxInAir = 6,
	partnerDiscount = 0.75,
}
export type Gift = { id: string, name: string, item: string, cost: number }
Config.Gifts = {
	{ id = "water", name = "Canteen", item = "canteen", cost = 8 },
	{ id = "snack", name = "Trail Mix", item = "trailmix", cost = 10 },
	{ id = "arrows", name = "Arrows", item = "arrows", cost = 10 },
	{ id = "bandage", name = "Bandage", item = "bandage", cost = 16 },
	{ id = "tea", name = "Rusty's Sweet Tea", item = "sweettea", cost = 40 },
} :: { Gift }

-- Spectator vote-back ("Encore"): once a match the Gallery can vote one contender back in.
Config.Encore = { at = 330, length = 20, minAlive = 6, pep = 50, candidates = 3 }

-- Rusty's in-match gift: one sweet tea to the human contender with the lowest Pep when 8 remain.
Config.RUSTY_GIFT_AT = 8

-- ===== Progression =====
Config.LEVEL_CAP = 50
Config.PRESTIGE_CAP = 4
Config.XP = {
	match = 40,
	perPlaceAbove = 2, -- (49 - place) * 2
	knock = 15,
	crate = 2,
	gift = 5,
	vote = 2,
	win = 150,
	token = 25,
	top10 = 30,
	encore = 20,
}
Config.PLAY_STREAK_WINDOW = 240 -- seconds between matches to keep a play streak
Config.PLAY_STREAK_STEP = 0.1
Config.PLAY_STREAK_MAX = 0.5
Config.STARS = { match = 1, top10 = 2, win = 5 }
Config.STARS_PER_TIER = 8
Config.DAILY_STREAK_XP = 60

-- ===== Fair play =====
Config.FairPlay = {
	boostMult = 0.5, -- Renown Boost: +50% XP for 30 min (never affects combat)
	showerMult = 0.25, -- everyone else in the server: +25% XP for 5 min
	showerMinutes = 5,
	satchelInRanked = false, -- Starter Satchel only in casual modes
	bootsRegen = 0.05, -- Trail Boots: +5% stamina regen, casual only
}
Config.RANKED = false -- v1 ships casual Jubilee only

-- ===== Bots =====
Config.Bots = {
	tick = 0.25,
	aimSpread = 0.12, -- radians-ish error for bot bows
	damageMult = 0.8,
	reaction = { 0.35, 0.9 },
	hubBrave = 0.4, -- share of bots that rush the Sundial
	sight = 70,
}

return Config

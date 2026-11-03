--!strict
--[[
	Season2.luau: the skeleton for Season 2, "High Harvest". Nothing here is on sale or live;
	it's the authored plan so the team can ship a season without starting from a blank page.
	Tests check it is complete and that none of its ids clash with Season 1.

	Turn it on by moving the ITEMS into Store.luau with `drop = n` and a new SCHEDULE.
]]
local Season2 = {}

Season2.NAME = "High Harvest"
Season2.WEEKS = 10
Season2.STARTS_AFTER_S1_WEEKS = 10 -- Season 2 week 1 = Store.SEASON1_START_WEEK + 10

-- Season Track: 30 tiers, cosmetics only. free = everyone, club = Patron Club.
Season2.TRACK = {
	{ tier = 1, free = "title_highharvest", club = "tag_s2_copper" },
	{ tier = 5, free = "banner_s2_sheaf", club = "wrap_s2_hayloft" },
	{ tier = 10, free = "emote_s2_scythe", club = "fade_s2_windmill" },
	{ tier = 15, free = "tag_s2_copper", club = "parade_s2_scarecrow" },
	{ tier = 20, free = "wrap_s2_hayloft", club = "skin_bow_s2_orchard" },
	{ tier = 25, free = "pose_s2_harvestking", club = "pose_s2_harvestking" },
	{ tier = 30, free = "skin_knife_s2_sickle", club = "skin_spear_s2_pitch" },
}

-- Shop items (planned prices on Store.TIERS, 3 per weekly drop).
Season2.ITEMS = {
	{ id = "skin_bow_s2_orchard", name = "Orchard Bow", slot = "bow", price = 299, drop = 1 },
	{ id = "fade_s2_windmill", name = "Windmill Sails", slot = "fade", price = 199, drop = 1 },
	{ id = "emote_s2_scythe", name = "Scythe Spin", slot = "emote", price = 99, drop = 1 },
	{ id = "skin_spear_s2_pitch", name = "Pitchfork Spear", slot = "spear", price = 399, drop = 2 },
	{ id = "pose_s2_harvestking", name = "Harvest King", slot = "pose", price = 299, drop = 2 },
	{ id = "tag_s2_copper", name = "Copper Sheaf Nametag", slot = "nametag", price = 149, drop = 2 },
	{ id = "skin_knife_s2_sickle", name = "Moon Sickle", slot = "knife", price = 199, drop = 3 },
	{ id = "wrap_s2_hayloft", name = "Hayloft Wrap", slot = "wrap", price = 99, drop = 3 },
	{ id = "parade_s2_scarecrow", name = "Scarecrow Parade Coat", slot = "parade", price = 199, drop = 3 },
	{ id = "rusty_s2_farmer", name = "Rusty: Old Farmer", slot = "rusty", price = 149, drop = 4 },
	{ id = "banner_s2_sheaf", name = "Sheaf Banner", slot = "banner", price = 99, drop = 4 },
	{ id = "fade_s2_fireflies", name = "Firefly Field", slot = "fade", price = 299, drop = 4 },
}
Season2.GRAND_PRICE = 4999 -- a Season 2 Grand Collection, built the same way as grand_s1

-- New weekly rules and twists to author (names and one-line intent).
Season2.WEEKLY_RULES = {
	{ id = "hay_bales", name = "Hay Bales", note = "Bales you can hide in; arrows set them smouldering." },
	{ id = "long_dusk", name = "Long Dusk", note = "The Veil closes slower but the arena goes dark sooner." },
	{ id = "scarecrows", name = "Scarecrow Field", note = "Decoy scarecrows that wear your Parade look." },
	{ id = "orchard_feast", name = "Orchard Feast", note = "More food, fewer crates." },
}
Season2.TWISTS = {
	{ id = "harvest_moon", name = "Harvest Moon", note = "Mid-match: the moon rises and every Fade glows twice as bright." },
	{ id = "windmill", name = "The Windmill", note = "A central landmark whose sails sweep the hill every 30 seconds." },
}

Season2.HALL = "Season 1 Champions stay in the Hall in a gold alcove."

return Season2

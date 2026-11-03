--!strict
--[[
	Store.luau: the Daybreak Item Shop catalog and its rules, as pure data + helpers (tested).

	How selling works
	  * Every item and bundle has one fixed Robux price from Store.TIERS. Each price has ONE
	    developer product in Monetization.Products ("Shop199" and so on), so Mike creates 11
	    products instead of one per item. Before the Roblox prompt, the game shows a card with the
	    exact item name, picture and price, and saves that choice ("intent") in the player's save.
	  * When the receipt arrives, the saved intent is granted. If it is missing or doesn't match
	    (a server restarted mid-purchase), the buyer gets a Shop Voucher for that price instead,
	    which buys any item at that price or lower. Nobody ever loses Robux.
	  * Nothing is random. No item changes stats. Items are kept forever.

	The weekly rotation is real, not fake urgency
	  * Always-on items never leave. Rotating items are featured for one real week (Monday 00:00
	    UTC to Monday 00:00 UTC), and every one of them comes back on a fixed cycle (the shop shows
	    when). The copy never says "last chance", never shows a ticking timer, never says sold out.
]]
local Store = {}

local Events: any
if typeof(script) == "Instance" then
	Events = require((script :: any).Parent.Logic.Events) :: any
else
	Events = (require :: any)("./Logic/Events")
end

export type Item = {
	id: string,
	name: string,
	cat: string,
	slot: string,
	price: number,
	icon: string,
	color: string,
	desc: string,
	rot: boolean, -- true = weekly rotation, false = always on sale
	anim: number?, -- Studio animation asset id for poses/emotes (0 = built-in fallback effect)
	sound: number?, -- Studio audio id for Rusty voice packs (0 = text lines only)
	shopOnly: boolean?,
	drop: number?, -- weekly drop number (1..6): joins the shop that week of Season 1, then rotates
	earned: boolean?, -- never sold: first win, member monthly, Patron Club, invites
	clip: string?, -- Anim.CLIPS key for poses/emotes when it differs from the id
	season: number?, -- 2 = Season 2 (High Harvest); its drops (7-10) start in season week 10
	event: string?, -- yearly festival id (Events.luau): on sale only during that festival
}
export type Bundle = { id: string, name: string, price: number, icon: string, desc: string, items: { string }, once: boolean?, event: string?, fromWeek: number? }

-- One developer product per price point. Covers R$25 to R$4,999.
Store.TIERS = { 25, 49, 99, 149, 199, 299, 399, 499, 799, 1299, 1999, 4999 }
Store.FEATURED_PER_WEEK = 6
Store.WEEK = 604800
Store.EPOCH_MONDAY = 345600 -- Monday 5 Jan 1970 00:00 UTC

Store.CATS = { "Arms", "Fades", "Poses", "Emotes", "Wraps", "Nametags", "Parade", "Rusty", "Reach" }
Store.SLOTS = { "bow", "spear", "knife", "fade", "pose", "emote", "wrap", "nametag", "parade", "rusty", "banner" }

local items: { Item } = {
	-- Arms: weapon skins. Same stats, new look: the held model built from parts (Arms.luau), the
	-- arrow / spear streak everyone sees, the hotbar tile and the kill-feed icon.
	{ id = "skin_bow_ashen", name = "Ashwood Bow", cat = "Arms", slot = "bow", price = 99, icon = "🏹", color = "#C9B79C", desc = "Pale ash with a dark grip. Same stats, new look.", rot = false },
	{ id = "skin_bow_gilded", name = "Gilded Bow", cat = "Arms", slot = "bow", price = 199, icon = "🏹", color = "#FFD36B", desc = "Gold-leaf limbs and a warm gold arrow streak. Same stats.", rot = false },
	{ id = "skin_bow_mirror", name = "Mirrorwood Bow", cat = "Arms", slot = "bow", price = 149, icon = "🏹", color = "#BFE7FF", desc = "Polished like Mirror Lake. Silver streak. Same stats.", rot = true },
	{ id = "skin_bow_frost", name = "Frostline Bow", cat = "Arms", slot = "bow", price = 299, icon = "🏹", color = "#9FE3FF", desc = "Frosted limbs and an icy streak. Same stats.", rot = true },
	{ id = "skin_bow_regent", name = "Regent's Longbow", cat = "Arms", slot = "bow", price = 499, icon = "🏹", color = "#FFB347", desc = "Carved gold and a wide sunset streak. Same stats.", rot = true },
	{ id = "skin_spear_ashen", name = "Ashen Spear", cat = "Arms", slot = "spear", price = 99, icon = "🗡️", color = "#A8A29A", desc = "Soot-gray shaft. Same stats, new look.", rot = false },
	{ id = "skin_spear_ember", name = "Ember Spear", cat = "Arms", slot = "spear", price = 199, icon = "🗡️", color = "#FF7A3D", desc = "A glowing ember tip and a spark trail when thrown. Same stats.", rot = false },
	{ id = "skin_spear_lake", name = "Lakeglass Spear", cat = "Arms", slot = "spear", price = 299, icon = "🗡️", color = "#6FD3E8", desc = "Blue glass head and a ripple trail. Same stats.", rot = true },
	{ id = "skin_knife_copper", name = "Copper Knife", cat = "Arms", slot = "knife", price = 49, icon = "🔪", color = "#D98A4E", desc = "Warm copper blade. Same stats.", rot = false },
	{ id = "skin_knife_night", name = "Nightglass Knife", cat = "Arms", slot = "knife", price = 149, icon = "🔪", color = "#8E7CFF", desc = "Dark glass with a violet edge. Same stats.", rot = true },
	-- Fades: how your knockouts dissolve into light (seen by everyone nearby).
	{ id = "fade_ember", name = "Ember Light", cat = "Fades", slot = "fade", price = 99, icon = "🔥", color = "#FF8A4C", desc = "Knockouts dissolve into warm ember light.", rot = false },
	{ id = "fade_veil", name = "Veil Shimmer", cat = "Fades", slot = "fade", price = 99, icon = "💠", color = "#7FF3FF", desc = "Knockouts dissolve into cyan shimmer.", rot = false },
	{ id = "fade_ash", name = "Ash and Embers", cat = "Fades", slot = "fade", price = 149, icon = "🌫️", color = "#D8C3A5", desc = "A slow drift of pale ash and sparks.", rot = true },
	{ id = "fade_aurora", name = "Aurora Fade", cat = "Fades", slot = "fade", price = 199, icon = "🌌", color = "#7DFFB2", desc = "Green and violet ribbons of light.", rot = true },
	{ id = "fade_starfall", name = "Starfall Fade", cat = "Fades", slot = "fade", price = 299, icon = "🌠", color = "#FFF1B8", desc = "A shower of tiny falling stars.", rot = true },
	-- Victory poses: played on the podium and when you win (everyone sees them).
	{ id = "pose_heart", name = "Hand on Heart", cat = "Poses", slot = "pose", price = 49, icon = "🤍", color = "#E8D9B5", desc = "A hand on your heart for your Reach on the podium.", rot = false, anim = 0 },
	{ id = "pose_bow", name = "Curtain Bow", cat = "Poses", slot = "pose", price = 99, icon = "🙇", color = "#FFD36B", desc = "A theatrical bow for the Gallery.", rot = false, anim = 0 },
	{ id = "pose_lantern", name = "Lantern Raise", cat = "Poses", slot = "pose", price = 199, icon = "🏮", color = "#FFC86B", desc = "Hold a lantern high as the crowd cheers.", rot = true, anim = 0 },
	{ id = "pose_crown", name = "Wheat Crown Toss", cat = "Poses", slot = "pose", price = 299, icon = "🌾", color = "#F2D27A", desc = "Toss a wheat crown into the air and catch it.", rot = true, anim = 0 },
	{ id = "pose_regent", name = "Regent's Stand", cat = "Poses", slot = "pose", price = 499, icon = "👑", color = "#FFB347", desc = "Golden light rises behind you on the podium.", rot = true, anim = 0 },
	-- Emotes: press B in the lobby or Gallery (never blocks a fight).
	{ id = "emote_tip", name = "Hat Tip", cat = "Emotes", slot = "emote", price = 25, icon = "🎩", color = "#E8D9B5", desc = "A polite tip of the hat.", rot = false, anim = 0 },
	{ id = "emote_toast", name = "Thermos Toast", cat = "Emotes", slot = "emote", price = 49, icon = "🫖", color = "#C98B4E", desc = "Raise a thermos, Rusty style.", rot = false, anim = 0 },
	{ id = "emote_twirl", name = "Ribbon Twirl", cat = "Emotes", slot = "emote", price = 99, icon = "🎀", color = "#FF9EC7", desc = "A spinning ribbon dance.", rot = true, anim = 0 },
	{ id = "emote_lantern", name = "Lantern Swing", cat = "Emotes", slot = "emote", price = 149, icon = "🏮", color = "#FFC86B", desc = "Swing a paper lantern overhead.", rot = true, anim = 0 },
	-- Gift wraps: how the parachute gifts you send from the Gallery look.
	{ id = "wrap_gold", name = "Gold Ribbon Wrap", cat = "Wraps", slot = "wrap", price = 49, icon = "🎁", color = "#FFD36B", desc = "Your parachute gifts come with a gold ribbon.", rot = false },
	{ id = "wrap_lantern", name = "Paper Lantern Wrap", cat = "Wraps", slot = "wrap", price = 99, icon = "🏮", color = "#FF9A5C", desc = "Your gifts float down under a paper lantern.", rot = false },
	{ id = "wrap_meadow", name = "Meadow Bloom Wrap", cat = "Wraps", slot = "wrap", price = 99, icon = "🌼", color = "#B9E07A", desc = "A canopy of meadow flowers.", rot = true },
	{ id = "wrap_star", name = "Starry Night Wrap", cat = "Wraps", slot = "wrap", price = 149, icon = "✨", color = "#9DB4FF", desc = "A deep blue canopy with stars.", rot = true },
	-- Nametags: the color of your name over your head in the lobby and Gallery.
	{ id = "tag_ember", name = "Ember Nametag", cat = "Nametags", slot = "nametag", price = 99, icon = "🏷️", color = "#FF8A4C", desc = "Your name glows ember orange.", rot = false },
	{ id = "tag_lake", name = "Lake Nametag", cat = "Nametags", slot = "nametag", price = 99, icon = "🏷️", color = "#6FD3E8", desc = "Your name glows lake blue.", rot = false },
	{ id = "tag_aurora", name = "Aurora Nametag", cat = "Nametags", slot = "nametag", price = 199, icon = "🏷️", color = "#7DFFB2", desc = "Your name shifts green to violet.", rot = true },
	-- Parade: what you wear on your Reach's float in the pregame parade.
	{ id = "parade_sunrise", name = "Sunrise Parade Coat", cat = "Parade", slot = "parade", price = 149, icon = "🧥", color = "#FFB38A", desc = "A glowing coat for the Spire parade.", rot = false },
	{ id = "parade_ember", name = "Ember Parade Cape", cat = "Parade", slot = "parade", price = 149, icon = "🧣", color = "#FF7A3D", desc = "A cape that trails sparks on the float.", rot = false },
	{ id = "parade_regal", name = "Regal Parade Mantle", cat = "Parade", slot = "parade", price = 399, icon = "🥻", color = "#E6C36A", desc = "A long gold mantle that catches the fireworks.", rot = true },
	-- Rusty packs: new line sets for your mentor (text now; voiced lines once audio IDs are set).
	{ id = "rusty_thermos", name = "Rusty's Brass Thermos", cat = "Rusty", slot = "rusty", price = 99, icon = "🫖", color = "#C9A04E", desc = "Rusty carries a polished brass thermos and toasts your wins.", rot = false, sound = 0 },
	{ id = "rusty_stories", name = "Rusty: Old Stories", cat = "Rusty", slot = "rusty", price = 149, icon = "📖", color = "#C98B4E", desc = "Rusty tells tales from his own Trials between matches.", rot = false, sound = 0 },
	{ id = "rusty_coach", name = "Rusty: Coach Mode", cat = "Rusty", slot = "rusty", price = 149, icon = "📣", color = "#E8D9B5", desc = "Rusty shouts practical tips from the Gallery.", rot = true, sound = 0 },

	-- ===== Season 1 weekly drops (pre-authored; see Store.SCHEDULE) =====
	-- Drop 1: Harvest Moon
	{ id = "skin_bow_harvest", name = "Harvest Moon Bow", cat = "Arms", slot = "bow", price = 299, icon = "🏹", color = "#E9C46A", desc = "Dark oak, wheat-gold leaves and a harvest-gold streak. Same stats.", rot = true, drop = 1 },
	{ id = "emote_harvest", name = "Harvest Lift", cat = "Emotes", slot = "emote", price = 99, icon = "🌾", color = "#E9C46A", desc = "Gather an armful of wheat and lift it to the sky.", rot = true, drop = 1, anim = 0 },
	{ id = "wrap_harvest", name = "Harvest Moon Wrap", cat = "Wraps", slot = "wrap", price = 99, icon = "🌕", color = "#F2B84B", desc = "Your gifts drift down under a harvest moon canopy.", rot = true, drop = 1 },
	-- Drop 2: Wheatsheaf
	{ id = "skin_spear_wheat", name = "Wheatsheaf Spear", cat = "Arms", slot = "spear", price = 299, icon = "🗡️", color = "#D9B45A", desc = "A gold head bound with wheat ears and a ribbon. Same stats.", rot = true, drop = 2 },
	{ id = "pose_reaper", name = "Harvest Kneel", cat = "Poses", slot = "pose", price = 199, icon = "🧎", color = "#D9B45A", desc = "Drop to one knee on the podium, weapon raised.", rot = true, drop = 2, anim = 0 },
	{ id = "tag_wheat", name = "Wheatsheaf Nametag", cat = "Nametags", slot = "nametag", price = 149, icon = "🏷️", color = "#E9C46A", desc = "Your name in warm wheat gold.", rot = true, drop = 2 },
	-- Drop 3: Comet Night
	{ id = "skin_bow_comet", name = "Comet Night Bow", cat = "Arms", slot = "bow", price = 399, icon = "🏹", color = "#9DB4FF", desc = "Midnight limbs, crystal tips and a pale blue comet streak. Same stats.", rot = true, drop = 3 },
	{ id = "fade_comet", name = "Comet Tail", cat = "Fades", slot = "fade", price = 199, icon = "☄️", color = "#9DB4FF", desc = "Knockouts streak up into the sky like a comet.", rot = true, drop = 3 },
	{ id = "emote_clap", name = "Gallery Applause", cat = "Emotes", slot = "emote", price = 49, icon = "👏", color = "#E8D9B5", desc = "A round of applause for a great match.", rot = true, drop = 3, anim = 0 },
	-- Drop 4: Lantern Festival
	{ id = "skin_knife_lantern", name = "Lantern Knife", cat = "Arms", slot = "knife", price = 149, icon = "🔪", color = "#FFC86B", desc = "A pale marble blade with a glowing lantern guard. Same stats.", rot = true, drop = 4 },
	{ id = "pose_moon", name = "Moon Lantern", cat = "Poses", slot = "pose", price = 299, icon = "🏮", color = "#FFC86B", desc = "Raise a lantern to the moon on the podium.", rot = true, drop = 4, anim = 0 },
	{ id = "parade_lantern", name = "Lantern Parade Robe", cat = "Parade", slot = "parade", price = 199, icon = "🥻", color = "#FFC86B", desc = "A robe hung with tiny paper lanterns for the parade.", rot = true, drop = 4 },
	-- Drop 5: Gallery Gala
	{ id = "fade_petals", name = "Petal Storm", cat = "Fades", slot = "fade", price = 149, icon = "🌸", color = "#FF9EC7", desc = "Knockouts burst into a swirl of petals.", rot = true, drop = 5 },
	{ id = "wrap_gala", name = "Gala Ribbon Wrap", cat = "Wraps", slot = "wrap", price = 149, icon = "🎀", color = "#FF7AB6", desc = "A velvet canopy with a gala ribbon.", rot = true, drop = 5 },
	{ id = "rusty_gala", name = "Rusty: Gala Host", cat = "Rusty", slot = "rusty", price = 149, icon = "🎩", color = "#E8D9B5", desc = "Rusty hosts the Gallery like a gala night.", rot = true, drop = 5, sound = 0 },
	-- Drop 6: Regent's Return
	{ id = "skin_spear_regent", name = "Regent's Spear", cat = "Arms", slot = "spear", price = 499, icon = "🗡️", color = "#FFD36B", desc = "Gold leaf head, crimson shaft and a sunset ribbon. Same stats.", rot = true, drop = 6 },
	{ id = "tag_regent", name = "Regent Nametag", cat = "Nametags", slot = "nametag", price = 199, icon = "🏷️", color = "#FFB347", desc = "Your name in sunset gold.", rot = true, drop = 6 },
	{ id = "fade_sunburst", name = "Sunburst", cat = "Fades", slot = "fade", price = 299, icon = "🌞", color = "#FFB347", desc = "Knockouts flare out in rings of sunrise light.", rot = true, drop = 6 },

	-- ===== Season 2: High Harvest (season = 2). Four drops, released in season weeks 10-13. =====
	{ id = "skin_bow_s2_orchard", name = "Orchard Bow", cat = "Arms", slot = "bow", price = 299, icon = "🏹", color = "#C8553D", desc = "Apple-wood limbs and a red-gold streak. Same stats.", rot = true, drop = 7, season = 2 },
	{ id = "fade_s2_windmill", name = "Windmill Sails", cat = "Fades", slot = "fade", price = 199, icon = "🌬️", color = "#E8D9B5", desc = "Knockouts spin away on four little windmill sails.", rot = true, drop = 7, season = 2 },
	{ id = "emote_s2_scythe", name = "Scythe Spin", cat = "Emotes", slot = "emote", price = 99, icon = "🌾", color = "#D9B45A", desc = "Twirl a wooden harvest scythe over your shoulder.", rot = true, drop = 7, season = 2, anim = 0, clip = "emote_harvest" },
	{ id = "skin_spear_s2_pitch", name = "Pitchfork Spear", cat = "Arms", slot = "spear", price = 399, icon = "🗡️", color = "#9C6B3E", desc = "A three-tined iron head on an oak shaft. Same stats.", rot = true, drop = 8, season = 2 },
	{ id = "pose_s2_harvestking", name = "Harvest King", cat = "Poses", slot = "pose", price = 299, icon = "👑", color = "#E9C46A", desc = "Sit on a throne of wheat sheaves on the podium.", rot = true, drop = 8, season = 2, anim = 0, clip = "pose_crown" },
	{ id = "tag_s2_copper", name = "Copper Sheaf Nametag", cat = "Nametags", slot = "nametag", price = 149, icon = "🏷️", color = "#C47A3A", desc = "Your name in burnished copper.", rot = true, drop = 8, season = 2 },
	{ id = "skin_knife_s2_sickle", name = "Moon Sickle", cat = "Arms", slot = "knife", price = 199, icon = "🔪", color = "#CFD8E3", desc = "A crescent blade with a pale moon shine. Same stats.", rot = true, drop = 9, season = 2 },
	{ id = "wrap_s2_hayloft", name = "Hayloft Wrap", cat = "Wraps", slot = "wrap", price = 99, icon = "🎁", color = "#E2C27A", desc = "Your gifts float down in a little hay basket.", rot = true, drop = 9, season = 2 },
	{ id = "parade_s2_scarecrow", name = "Scarecrow Parade Coat", cat = "Parade", slot = "parade", price = 199, icon = "🧥", color = "#B08850", desc = "A patched field coat with straw at the cuffs.", rot = true, drop = 9, season = 2 },
	{ id = "rusty_s2_farmer", name = "Rusty: Old Farmer", cat = "Rusty", slot = "rusty", price = 149, icon = "🧑‍🌾", color = "#9C6B3E", desc = "Rusty swaps the thermos for a straw hat and farm sayings.", rot = true, drop = 10, season = 2, sound = 0 },
	{ id = "banner_s2_sheaf", name = "Sheaf Banner", cat = "Reach", slot = "banner", price = 99, icon = "🚩", color = "#E9C46A", desc = "A wheat-sheaf banner behind your name and on the podium.", rot = true, drop = 10, season = 2 },
	{ id = "fade_s2_fireflies", name = "Firefly Field", cat = "Fades", slot = "fade", price = 299, icon = "✨", color = "#D7F27A", desc = "Knockouts drift away as a cloud of fireflies.", rot = true, drop = 10, season = 2 },

	-- ===== Founders' Dawn (18-30 November, every year): on sale during the festival =====
	{ id = "skin_bow_founders", name = "Founders' Bow", cat = "Arms", slot = "bow", price = 199, icon = "🏹", color = "#F4C27A", desc = "Pale birch wrapped in festival ribbon, with a dawn-gold streak. Same stats.", rot = false, event = "founders_dawn" },
	{ id = "pose_first_sunrise", name = "First Sunrise", cat = "Poses", slot = "pose", price = 199, icon = "🌄", color = "#FFB38A", desc = "Turn to the horizon as the podium lights up gold.", rot = false, event = "founders_dawn", anim = 0, clip = "pose_lantern" },
	{ id = "wrap_s_festival", name = "Festival Lantern Wrap", cat = "Wraps", slot = "wrap", price = 99, icon = "🏮", color = "#FF9A5C", desc = "Your gifts float down under a string of festival lanterns.", rot = false, event = "founders_dawn" },
	{ id = "parade_dawn_coat", name = "Dawn Festival Coat", cat = "Parade", slot = "parade", price = 149, icon = "🧥", color = "#FFC86B", desc = "A sunrise-orange coat with a gold lantern pin for the parade.", rot = false, event = "founders_dawn" },

	-- ===== Earned only (never sold) =====
	{ id = "pose_firstlight", name = "First Light", cat = "Poses", slot = "pose", price = 0, icon = "🌅", color = "#FFD36B", desc = "Earned with your first win. Raise the dawn on the podium.", rot = false, earned = true, anim = 0 },
	{ id = "emote_patron", name = "Patron's Flourish", cat = "Emotes", slot = "emote", price = 0, icon = "📜", color = "#C9A04E", desc = "A Patron Club thank-you: a sweeping courtly bow.", rot = false, earned = true, anim = 0 },
	{ id = "sash_torchbearer", name = "Torchbearer Sash", cat = "Parade", slot = "parade", price = 0, icon = "🔥", color = "#FF8A4C", desc = "For bringing a friend into a match (you both get one).", rot = false, earned = true },
	{ id = "tag_member_dawn", name = "Member Dawn Nametag", cat = "Nametags", slot = "nametag", price = 0, icon = "➕", color = "#FFC2A1", desc = "A monthly thank-you for Roblox Plus members.", rot = false, earned = true },
	{ id = "wrap_member_silver", name = "Member Silver Wrap", cat = "Wraps", slot = "wrap", price = 0, icon = "➕", color = "#D7E6EE", desc = "A monthly thank-you for Roblox Plus members.", rot = false, earned = true },
	{ id = "banner_member_spire", name = "Member Spire Banner", cat = "Reach", slot = "banner", price = 0, icon = "➕", color = "#BFE7FF", desc = "A monthly thank-you for Roblox Plus members.", rot = false, earned = true },
	{ id = "emote_member_cheer", name = "Member Cheer", cat = "Emotes", slot = "emote", price = 0, icon = "➕", color = "#FFE9A8", desc = "A monthly thank-you for Roblox Plus members.", rot = false, earned = true, anim = 0, clip = "emote_clap" },
	{ id = "banner_founders_lantern", name = "Founders' Lantern Banner", cat = "Reach", slot = "banner", price = 0, icon = "🏮", color = "#FFC86B", desc = "Free for playing 3 matches during Founders' Dawn.", rot = false, earned = true },
	{ id = "tag_dawn_ribbon", name = "Dawn Ribbon Nametag", cat = "Nametags", slot = "nametag", price = 0, icon = "🎗️", color = "#FFB38A", desc = "Free for playing on 3 different days of Founders' Dawn.", rot = false, earned = true },
	{ id = "fade_archive_reel", name = "Archive Reel", cat = "Fades", slot = "fade", price = 0, icon = "🎞️", color = "#C9A97A", desc = "Free for a top 5 in an Archive Reel match. Knockouts flicker out like old film.", rot = false, earned = true },
	{ id = "sash_homecoming", name = "Homecoming Sash", cat = "Parade", slot = "parade", price = 0, icon = "🏡", color = "#E8D9B5", desc = "Free for finishing your first five matches. Welcome to the Trials.", rot = false, earned = true },
}

-- Free monthly cosmetic for Roblox Plus (and legacy Premium) members: a fixed list by month,
-- never random. Month 1 = January.
Store.MEMBER_MONTHLY = { "tag_member_dawn", "wrap_member_silver", "banner_member_spire", "emote_member_cheer" }
function Store.memberItemFor(yyyymm: number): string
	local m = yyyymm % 100
	return Store.MEMBER_MONTHLY[((m - 1) % #Store.MEMBER_MONTHLY) + 1]
end

-- Reach Pride bundles: one per Reach, generated (banner + parade sash + nametag in Reach colors).
local function slug(s: string): string
	return (s:lower():gsub("[^%w]+", "_"))
end
Store.slug = slug

function Store.addReachPride(reaches: { string })
	for _, r in ipairs(reaches) do
		local s = slug(r)
		if not Store.byId[`banner_pride_{s}`] then
			local adds: { Item } = {
				{ id = `banner_pride_{s}`, name = `{r} Pride Banner`, cat = "Reach", slot = "banner", price = 149, icon = "🚩", color = "#E8D9B5", desc = `Fly {r}'s banner behind your name and on the podium.`, rot = false },
				{ id = `sash_pride_{s}`, name = `{r} Parade Sash`, cat = "Reach", slot = "parade", price = 99, icon = "🎗️", color = "#E8D9B5", desc = `Wear {r}'s colors in the parade.`, rot = false },
				{ id = `tag_pride_{s}`, name = `{r} Nametag`, cat = "Reach", slot = "nametag", price = 99, icon = "🏷️", color = "#E8D9B5", desc = `Your name in {r}'s colors.`, rot = false },
			}
			for _, it in ipairs(adds) do
				table.insert(Store.ITEMS, it)
				Store.byId[it.id] = it
			end
			table.insert(Store.BUNDLES, { id = `pride_{s}`, name = `{r} Pride Bundle`, price = 199, icon = "🚩", desc = `Banner, parade sash and nametag for {r}.`, items = { `banner_pride_{s}`, `sash_pride_{s}`, `tag_pride_{s}` } })
		end
	end
end

Store.ITEMS = items
Store.byId = {} :: { [string]: Item }
for _, it in ipairs(items) do
	Store.byId[it.id] = it
end

Store.BUNDLES = {
	{ id = "starter", name = "Starter Pack", price = 99, icon = "🎒", once = true, desc = "One per account: Ashwood Bow, Copper Knife, Gold Ribbon Wrap and the Hat Tip emote.", items = { "skin_bow_ashen", "skin_knife_copper", "wrap_gold", "emote_tip" } },
	{ id = "ember_set", name = "Ember Set", price = 399, icon = "🔥", desc = "Ember Spear, Ember Light fade, Ember Parade Cape and Ember Nametag.", items = { "skin_spear_ember", "fade_ember", "parade_ember", "tag_ember" } },
	{ id = "rusty_set", name = "Rusty's Corner", price = 299, icon = "🫖", desc = "Brass Thermos, Old Stories, Coach Mode and the Thermos Toast emote.", items = { "rusty_thermos", "rusty_stories", "rusty_coach", "emote_toast" } },
	{ id = "regent_set", name = "Regent Collection", price = 1299, icon = "👑", desc = "Regent's Longbow, Regent's Stand, Starfall Fade and Regal Parade Mantle.", items = { "skin_bow_regent", "pose_regent", "fade_starfall", "parade_regal" } },
	{ id = "arms_locker", name = "Complete Arms Locker", price = 1299, icon = "⚔️", desc = "All 10 weapon skins in this season's shop.", items = { "skin_bow_ashen", "skin_bow_gilded", "skin_bow_mirror", "skin_bow_frost", "skin_bow_regent", "skin_spear_ashen", "skin_spear_ember", "skin_spear_lake", "skin_knife_copper", "skin_knife_night" } },
	{ id = "spire_collection", name = "Spire Collection", price = 1999, icon = "🏛️", desc = "Every fade, pose, emote and gift wrap in this season's shop.", items = {
		"fade_ember", "fade_veil", "fade_ash", "fade_aurora", "fade_starfall",
		"pose_heart", "pose_bow", "pose_lantern", "pose_crown", "pose_regent",
		"emote_tip", "emote_toast", "emote_twirl", "emote_lantern",
		"wrap_gold", "wrap_lantern", "wrap_meadow", "wrap_star",
	} },
	{ id = "founders_set", name = "Founders' Dawn Set", price = 499, icon = "🌄", event = "founders_dawn", desc = "Founders' Bow, First Sunrise, Festival Lantern Wrap and Dawn Festival Coat. In the shop during Founders' Dawn, back every November.", items = { "skin_bow_founders", "pose_first_sunrise", "wrap_s_festival", "parade_dawn_coat" } },
	{ id = "high_harvest", name = "High Harvest Collection", price = 1999, icon = "🌾", fromWeek = 10, desc = "All 12 Season 2 items, including drops that haven't arrived yet (they unlock in your Locker right away).", items = {
		"skin_bow_s2_orchard", "fade_s2_windmill", "emote_s2_scythe", "skin_spear_s2_pitch", "pose_s2_harvestking", "tag_s2_copper",
		"skin_knife_s2_sickle", "wrap_s2_hayloft", "parade_s2_scarecrow", "rusty_s2_farmer", "banner_s2_sheaf", "fade_s2_fireflies",
	} },
} :: { Bundle }

-- The R$ 4,999 Season 1 Grand Collection: every sellable Season 1 item outside Reach Pride,
-- weekly drops included (they unlock in the buyer's Locker right away). Built from the list so
-- it never goes stale; Store.validate checks it stays a real saving.
do
	local all = {}
	for _, it in ipairs(items) do
		if not it.earned and not it.season and not it.event then
			table.insert(all, it.id)
		end
	end
	table.insert(Store.BUNDLES, { id = "grand_s1", name = "First Light Grand Collection", price = 4999, icon = "🌅", desc = "Every weapon skin, fade, pose, emote, wrap, nametag, parade look and Rusty pack in Season 1, weekly drops included.", items = all })
end

function Store.bundle(id: string): Bundle?
	for _, b in ipairs(Store.BUNDLES) do
		if b.id == id then
			return b
		end
	end
	return nil
end

-- Festival and Season 2 bundles are only on the shelf in their weeks.
function Store.bundleOnSale(b: Bundle, week: number): (boolean, string?)
	if b.event then
		if Events.weekOverlaps(b.event, Store.weekStart(week), Store.WEEK) then
			return true, nil
		end
		local e = Events.byId(b.event)
		return false, "In the shop during " .. (if e then e.name else "its festival") .. ", every year."
	end
	if b.fromWeek then
		local rel = week - Store.SEASON1_START_WEEK + 1
		if rel < b.fromWeek then
			return false, string.format("Opens with Season 2 in %d week%s.", b.fromWeek - rel, b.fromWeek - rel == 1 and "" or "s")
		end
	end
	return true, nil
end

-- What a bundle's items cost one by one, for the "R$ X of items for R$ Y" line.
function Store.anchor(b: Bundle, owned: { [string]: any }?): (number, number)
	local v = Store.value(b, owned)
	return v, math.max(0, v - b.price)
end

function Store.value(b: Bundle, owned: { [string]: any }?): number
	local v = 0
	for _, id in ipairs(b.items) do
		local it = Store.byId[id]
		if it and not (owned and owned[id]) then
			v += it.price
		end
	end
	return v
end

-- ===== Weekly rotation =====
function Store.week(t: number): number
	return (t - Store.EPOCH_MONDAY) // Store.WEEK
end
function Store.weekStart(week: number): number
	return Store.EPOCH_MONDAY + week * Store.WEEK
end

function Store.rotatingPool(withDrops: boolean?): { Item }
	local pool = {}
	for _, it in ipairs(Store.ITEMS) do
		if it.rot and (withDrops ~= false or not it.drop) then
			table.insert(pool, it)
		end
	end
	table.sort(pool, function(a: Item, b: Item): boolean
		return a.id < b.id
	end)
	-- fixed interleave so each week mixes categories (deterministic, same on every server)
	local out = {}
	local n = #pool
	local step = 7
	while n > 0 and n % step == 0 do
		step += 1
	end
	for i = 0, n - 1 do
		out[i + 1] = pool[(i * step) % n + 1]
	end
	return out
end

function Store.cycleWeeks(): number
	return math.max(1, math.ceil(#Store.rotatingPool() / Store.FEATURED_PER_WEEK))
end
function Store.cycleWeeksAt(week: number): number
	if week < Store.SEASON1_START_WEEK then
		return math.max(1, math.ceil(#Store.rotatingPool(false) / Store.FEATURED_PER_WEEK))
	end
	return Store.cycleWeeks()
end

-- ===== Season 1 drop schedule (pre-authored) =====
-- Week 1 of Season 1 starts on Store.SEASON1_START_WEEK (a Monday 00:00 UTC). Set it to your
-- launch Monday before publishing (PUBLISHING.md 6f). Weeks 1-3 are the launch shelves; weeks
-- 4-9 each add one 3-item drop next to 3 returning items. After week 9 every rotating item,
-- drops included, cycles on the fixed schedule in Store.rotation.
Store.SEASON1_START_WEEK = 2967 -- Monday 16 Nov 2026 00:00 UTC
Store.DROP_NAMES = { "Harvest Moon", "Wheatsheaf", "Comet Night", "Lantern Festival", "Gallery Gala", "Regent's Return", "Orchard", "Pitchfork Fair", "Moon Field", "Firefly Night" }
Store.SCHEDULE = {
	{ "skin_bow_mirror", "fade_ash", "pose_lantern", "emote_twirl", "wrap_meadow", "tag_aurora" },
	{ "skin_spear_lake", "fade_aurora", "pose_crown", "emote_lantern", "wrap_star", "rusty_coach" },
	{ "skin_bow_frost", "skin_bow_regent", "skin_knife_night", "fade_starfall", "pose_regent", "parade_regal" },
	{ "skin_bow_harvest", "emote_harvest", "wrap_harvest", "skin_bow_mirror", "fade_ash", "pose_lantern" },
	{ "skin_spear_wheat", "pose_reaper", "tag_wheat", "skin_spear_lake", "emote_twirl", "wrap_meadow" },
	{ "skin_bow_comet", "fade_comet", "emote_clap", "fade_aurora", "pose_crown", "tag_aurora" },
	{ "skin_knife_lantern", "pose_moon", "parade_lantern", "emote_lantern", "wrap_star", "rusty_coach" },
	{ "fade_petals", "wrap_gala", "rusty_gala", "skin_bow_frost", "skin_knife_night", "fade_starfall" },
	{ "skin_spear_regent", "tag_regent", "fade_sunburst", "skin_bow_regent", "pose_regent", "parade_regal" },
	-- Season 2 (High Harvest) starts in week 10: one drop a week next to 3 returning items.
	{ "skin_bow_s2_orchard", "fade_s2_windmill", "emote_s2_scythe", "skin_bow_harvest", "pose_reaper", "fade_comet" },
	{ "skin_spear_s2_pitch", "pose_s2_harvestking", "tag_s2_copper", "skin_spear_wheat", "pose_moon", "wrap_gala" },
	{ "skin_knife_s2_sickle", "wrap_s2_hayloft", "parade_s2_scarecrow", "skin_bow_comet", "fade_petals", "tag_wheat" },
	{ "rusty_s2_farmer", "banner_s2_sheaf", "fade_s2_fireflies", "skin_spear_regent", "fade_sunburst", "emote_harvest" },
}
Store.SEASON2_WEEK = 10 -- season week the High Harvest shelf opens

-- Which Season 1 week (1-based) a shop week is, or nil outside the authored weeks.
function Store.seasonWeek(week: number): number?
	local rel = week - Store.SEASON1_START_WEEK + 1
	if rel >= 1 and rel <= #Store.SCHEDULE then
		return rel
	end
	return nil
end

-- The drop number released by a week (nil if none), and whether a drop item is out yet.
function Store.dropOf(week: number): number?
	local sw = Store.seasonWeek(week)
	if sw and sw >= 4 then
		return sw - 3
	end
	return nil
end
function Store.released(it: Item, week: number): boolean
	if not it.drop then
		return true
	end
	return week - Store.SEASON1_START_WEEK + 1 >= it.drop + 3
end

-- The featured rotating items for a week: the authored schedule during Season 1's first 9
-- weeks, then a fixed cycle. Every rotating item appears at least once per cycle.
function Store.rotation(week: number): { Item }
	local sw = Store.seasonWeek(week)
	if sw then
		local out = {}
		for _, id in ipairs(Store.SCHEDULE[sw]) do
			table.insert(out, Store.byId[id])
		end
		return out
	end
	local beforeLaunch = week < Store.SEASON1_START_WEEK
	local pool = Store.rotatingPool(not beforeLaunch)
	local cycle = Store.cycleWeeksAt(week)
	local slot = week % cycle
	local out = {}
	for i = 1, Store.FEATURED_PER_WEEK do
		local idx = slot * Store.FEATURED_PER_WEEK + i
		if idx <= #pool then
			table.insert(out, pool[idx])
		else
			-- last slice is short: top up from the start of the pool so the shelf is always full
			table.insert(out, pool[((idx - 1) % #pool) + 1])
		end
	end
	return out
end

function Store.inRotation(id: string, week: number): boolean
	local it = Store.byId[id]
	if not it then
		return false
	end
	if it.event then
		return Events.weekOverlaps(it.event, Store.weekStart(week), Store.WEEK)
	end
	if not it.rot then
		return true
	end
	for _, x in ipairs(Store.rotation(week)) do
		if x.id == id then
			return true
		end
	end
	return false
end

-- The next week (>= week) an item is on sale. Always-on items return `week`.
function Store.nextWeek(id: string, week: number): number?
	local it = Store.byId[id]
	local horizon = if it and it.event then 54 else Store.cycleWeeks() + #Store.SCHEDULE + 1
	for w = week, week + horizon do
		if Store.inRotation(id, w) then
			return w
		end
	end
	return nil
end

-- ===== Pricing and buying =====
function Store.tierKey(price: number): string?
	for _, p in ipairs(Store.TIERS) do
		if p == price then
			return "Shop" .. p
		end
	end
	return nil
end

export type Offer = { kind: string, id: string, name: string, price: number, items: { string }, icon: string, once: boolean? }

function Store.offer(kind: string, id: string): Offer?
	if kind == "item" then
		local it = Store.byId[id]
		if it and not it.earned then
			return { kind = "item", id = id, name = it.name, price = it.price, items = { id }, icon = it.icon }
		end
	elseif kind == "bundle" then
		local b = Store.bundle(id)
		if b then
			return { kind = "bundle", id = id, name = b.name, price = b.price, items = b.items, icon = b.icon, once = b.once }
		end
	end
	return nil
end

-- Can `owned` (the recipient's owned table) receive this offer this week?
-- Bundles: allowed only while the items you don't own are still worth more than the price,
-- so a bundle is never a worse deal than buying the missing pieces.
function Store.canReceive(o: Offer, owned: { [string]: any }, week: number, flags: { [string]: any }?): (boolean, string?)
	if o.kind == "item" then
		if owned[o.id] then
			return false, "Already owned."
		end
		if not Store.inRotation(o.id, week) then
			local nw = Store.nextWeek(o.id, week)
			local it = Store.byId[o.id]
			local verb = (it and not Store.released(it, week)) and "Arrives" or "Back in the shop"
			return false, nw and string.format("%s in %d week%s.", verb, nw - week, nw - week == 1 and "" or "s") or "Not in the shop this season."
		end
		return true, nil
	end
	local b = Store.bundle(o.id)
	if not b then
		return false, "Not found."
	end
	local okWeek, why = Store.bundleOnSale(b, week)
	if not okWeek then
		return false, why
	end
	if b.once and flags and flags["bundle:" .. b.id] then
		return false, "One per account."
	end
	if Store.value(b, owned) <= b.price then
		return false, "You already own most of this. Buy the missing items on their own."
	end
	return true, nil
end

-- Grant an offer into an owned table. Returns the number of new items.
function Store.grant(o: Offer, owned: { [string]: any }, flags: { [string]: any }?): number
	local n = 0
	for _, id in ipairs(o.items) do
		if not owned[id] then
			owned[id] = true
			n += 1
		end
	end
	if o.kind == "bundle" and flags then
		flags["bundle:" .. o.id] = true
	end
	return n
end

-- Vouchers: a receipt with no matching intent becomes a voucher for that price.
-- A voucher pays for any item or bundle at that price or lower (no change given).
function Store.addVoucher(vouchers: { [string]: number }, price: number)
	local k = tostring(price)
	vouchers[k] = (vouchers[k] or 0) + 1
end

function Store.voucherFor(vouchers: { [string]: number }, price: number): number?
	local best: number? = nil
	for k, n in pairs(vouchers) do
		local v = tonumber(k)
		if v and n > 0 and v >= price and (best == nil or v < best) then
			best = v
		end
	end
	return best
end

function Store.useVoucher(vouchers: { [string]: number }, price: number): boolean
	local v = Store.voucherFor(vouchers, price)
	if not v then
		return false
	end
	local k = tostring(v)
	vouchers[k] -= 1
	if vouchers[k] <= 0 then
		vouchers[k] = nil
	end
	return true
end

-- Match a receipt to the saved intent. Returns the offer to grant, or nil (=> voucher).
export type Intent = { kind: string, id: string, price: number, to: number?, t: number }
function Store.matchIntent(intent: Intent?, price: number, now: number): Intent?
	if not intent or intent.price ~= price then
		return nil
	end
	if now - (intent.t or 0) > 3600 then
		return nil
	end
	return intent
end

-- ===== Checks used by tests =====
local PRESSURE = { "last chance", "hurry", "limited time", "only today", "don't miss", "expires", "act now", "loot box", "mystery", "random", "sold out", "almost gone", "% off", "sale" }
Store.PRESSURE_WORDS = PRESSURE

function Store.validate(): { string }
	local errs = {}
	local seen = {}
	local slots = {}
	for _, s in ipairs(Store.SLOTS) do
		slots[s] = true
	end
	for _, it in ipairs(Store.ITEMS) do
		if seen[it.id] then
			table.insert(errs, "duplicate " .. it.id)
		end
		seen[it.id] = true
		if it.earned then
			if it.price ~= 0 or it.rot then
				table.insert(errs, it.id .. " earned items are never sold")
			end
		elseif not Store.tierKey(it.price) then
			table.insert(errs, it.id .. " price not a tier")
		end
		if not slots[it.slot] then
			table.insert(errs, it.id .. " bad slot")
		end
		local text = (it.name .. " " .. it.desc):lower()
		for _, w in ipairs(PRESSURE) do
			if text:find(w, 1, true) then
				table.insert(errs, it.id .. " says " .. w)
			end
		end
	end
	for _, b in ipairs(Store.BUNDLES) do
		if not Store.tierKey(b.price) then
			table.insert(errs, b.id .. " price not a tier")
		end
		for _, id in ipairs(b.items) do
			if not Store.byId[id] then
				table.insert(errs, b.id .. " missing " .. id)
			elseif Store.byId[id].earned then
				table.insert(errs, b.id .. " sells earned-only " .. id)
			end
		end
		if Store.value(b, nil) <= b.price then
			table.insert(errs, b.id .. " is not a real saving")
		end
		local text = (b.name .. " " .. b.desc):lower()
		for _, w in ipairs(PRESSURE) do
			if text:find(w, 1, true) then
				table.insert(errs, b.id .. " says " .. w)
			end
		end
	end
	for w, ids in ipairs(Store.SCHEDULE) do
		if #ids ~= Store.FEATURED_PER_WEEK then
			table.insert(errs, "schedule week " .. w .. " size")
		end
		for _, id in ipairs(ids) do
			local it = Store.byId[id]
			if not it or not it.rot then
				table.insert(errs, "schedule week " .. w .. " bad " .. id)
			elseif it.drop and w < it.drop + 3 then
				table.insert(errs, "schedule week " .. w .. " shows " .. id .. " before its drop")
			end
		end
	end
	return errs
end

return Store

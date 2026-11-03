--!strict
--[[
	Monetization.luau: THE ONE PLACE FOR ROBUX IDS. Every ID ships as 0 (subscription as "").

	HOW TO FILL THIS IN (PUBLISHING.md §11 lists every product with its suggested price):
	  1. Publish the game once (File > Publish to Roblox).
	  2. Creator Hub > the game > Monetization > Passes: create each entry in `Passes`, paste the ID.
	  3. Monetization > Developer Products: create each entry in `Products` at the listed price.
	     The 11 "Shop" products are price points; the in-game card names the exact item.
	  4. Monetization > Subscriptions: create "Patron Club" (Robux, 299/month), paste its EXP- id.
	  5. Places > Permissions/Settings: allow Private Servers and set the price (suggested R$ 99/month).
	  6. Save, rebuild, publish again.

	Anything left at 0 is hidden in the live game. In Studio play-testing, 0-ID items show a
	"Studio test" button that grants them free so you can try everything.

	Fair-play rules (Roblox monetization guidelines, checked by tests):
	  * No paid random items. Nothing sold has a chance roll. Crates in the arena are free.
	  * Calm copy: "See item", "Buy for R$ X". No ticking timers, no "LAST CHANCE", no fake sales.
	    The weekly shop rotation is real and every rotating item comes back on a fixed cycle.
	  * No paid combat power. Starter Satchel and Trail Boots work only in casual Jubilees, switch
	    off when 10 are left, can be earned free on the Season Track, and ranked ignores them.
	  * Robux never buys Favor. Spectator gifts that help a contender are paid with Favor earned by
	    watching. Patron Picks adds cosmetic-only gift choices.
	  * Tier Skips move you along the cosmetic Season Track only.
	  * PolicyService gates every sale; subscriptions also need IsEligibleToPurchaseSubscription.
]]

export type Pass = { id: number, name: string, price: number, desc: string, icon: string }
export type Product = {
	id: number,
	name: string,
	price: number,
	desc: string,
	icon: string,
	kind: string, -- "boost" | "cosmetic" | "skip" | "shop"
	category: string,
	minutes: number?,
	tiers: number?,
}
export type Subscription = { id: string, name: string, price: number, desc: string, icon: string, perks: { string } }

local Monetization = {}

Monetization.Passes = {
	PremiumLane = { id = 0, name = "Season Track Premium Lane", price = 399, icon = "🌅", desc = "Unlocks the premium cosmetic lane for this season. Every reward is shown before you buy." },
	VIP = { id = 0, name = "Spire VIP", price = 499, icon = "💛", desc = "Gold nametag, +10% Renown in casual matches, and twist + No Betrayals controls in private servers you own. No combat power." },
	GalleryBox = { id = 0, name = "Gallery Box Seat", price = 149, icon = "🎟️", desc = "A cushioned box seat in the Viewing Gallery and a gold name in the gift feed. Cosmetic." },
	BigSponsor = { id = 0, name = "Big Sponsor", price = 249, icon = "🪂", desc = "Earn Favor twice as fast while spectating. Favor itself is never sold." },
	PatronPicks = { id = 0, name = "Patron Picks", price = 199, icon = "🎆", desc = "Two extra Gallery gift choices: a firework flare and a cheering banner over a contender. Cosmetic, paid with earned Favor." },
	StarterSatchel = { id = 0, name = "Starter Satchel", price = 199, icon = "🎒", desc = "Start casual Jubilees with an apple and a canteen. Also free at Season Track tier 12." },
	TrailBoots = { id = 0, name = "Trail Boots", price = 299, icon = "🥾", desc = "+5% stamina regen in casual Jubilees until 10 are left, and a dusty footprint trail. Free at tier 24." },
	TrainingRetry = { id = 0, name = "Extra Training Try", price = 99, icon = "🎯", desc = "One extra try at the pregame target range each match. The score is cosmetic." },
} :: { [string]: Pass }

Monetization.Products = {
	RenownBoost = { id = 0, name = "Renown Boost", price = 49, icon = "✨", kind = "boost", category = "Boosts", minutes = 30, desc = "+50% Renown for 30 minutes. Everyone else in the server gets a free 5-minute Renown Shower." },
	TierSkip = { id = 0, name = "Season Tier Skip", price = 75, icon = "⏩", kind = "skip", category = "Season", tiers = 1, desc = "Move one tier along the Season Track. Cosmetic rewards only." },
	TierSkip10 = { id = 0, name = "Season Tier Skip x10", price = 599, icon = "⏭️", kind = "skip", category = "Season", tiers = 10, desc = "Move ten tiers along the Season Track. Cosmetic rewards only." },
} :: { [string]: Product }

-- One developer product per shop price point (see Store.luau). Created from Store.TIERS.
local SHOP_TIERS = { 25, 49, 99, 149, 199, 299, 399, 499, 799, 1299, 1999, 4999 }
for _, p in ipairs(SHOP_TIERS) do
	Monetization.Products["Shop" .. p] = {
		id = 0,
		name = "Daybreak Shop item (R$ " .. p .. ")",
		price = p,
		icon = "🛍️",
		kind = "shop",
		category = "Shop",
		desc = "Pays for the item or bundle you picked in the shop card. The card shows exactly what you get.",
	}
end

Monetization.Subscriptions = {
	PatronClub = {
		id = "",
		name = "Patron Club",
		price = 299,
		icon = "📜",
		desc = "A monthly club for regulars. Cancel any time in Roblox settings; everything you got stays yours.",
		perks = {
			"A Patron cosmetic each month, kept forever",
			"2 Season Tier Skips each month",
			"+15% Renown in casual matches",
			"A wax-seal Patron stamp on your sponsor letters",
		},
	},
} :: { [string]: Subscription }

-- Private servers are priced in Creator Hub, not here. Suggested: R$ 99 per month.
Monetization.PRIVATE_SERVER_PRICE = 99

-- True when nothing in this module is a random/gacha item (checked by tests).
function Monetization.noRandomItems(): boolean
	for _, p in pairs(Monetization.Products) do
		if p.kind ~= "boost" and p.kind ~= "cosmetic" and p.kind ~= "skip" and p.kind ~= "shop" then
			return false
		end
	end
	return true
end

-- Every Robux price a player can pay, sorted (used for the price-ladder test and the Page).
function Monetization.ladder(extra: { number }?): { number }
	local seen, out = {}, {}
	local function add(p: number)
		if not seen[p] then
			seen[p] = true
			table.insert(out, p)
		end
	end
	for _, p in pairs(Monetization.Passes) do
		add(p.price)
	end
	for _, p in pairs(Monetization.Products) do
		add(p.price)
	end
	for _, s in pairs(Monetization.Subscriptions) do
		add(s.price)
	end
	add(Monetization.PRIVATE_SERVER_PRICE)
	for _, p in ipairs(extra or {}) do
		add(p)
	end
	table.sort(out)
	return out
end

return Monetization

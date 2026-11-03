--!strict
--[[
	Monetization.luau — THE ONE PLACE FOR ROBUX IDS. Every ID ships as 0.

	HOW TO FILL THIS IN (see PUBLISHING.md for click-by-click steps):
	  1. Publish the game once (File > Publish to Roblox).
	  2. https://create.roblox.com/dashboard/creations > the game > Monetization > Passes:
	     "Create a Pass" for every entry in `Passes`. Paste its ID over the 0.
	  3. Monetization > Developer Products: create every entry in `Products`, paste IDs.
	  4. Save, rebuild, publish again.

	Anything left at 0 is hidden in the live game. In Studio play-testing, 0-ID items show a
	"Studio test" button that grants them free so you can try everything.

	Fair-play rules (Roblox monetization policy + "promoting to younger audiences" guidance):
	  * No paid random items. Nothing sold has a chance roll. Crates in the arena are free.
	  * Calm shop copy: "See item", "Buy for R$ X". No countdowns, no "LAST CHANCE", no FOMO.
	  * No paid combat power. Starter Satchel and Trail Boots only work in casual Jubilees and
	    can be earned free from the Season Track; ranked (future) ignores them.
	  * The Premium lane of the Season Track never sells tiers or Stars; you earn tiers by playing.
	  * Robux never buys Favor; spectator gifts are earned by watching.
	  * Renown Boost gives everyone else in the server a free 5-minute Renown Shower.
]]

export type Pass = { id: number, name: string, price: number, desc: string, icon: string }
export type Product = {
	id: number,
	name: string,
	price: number,
	desc: string,
	icon: string,
	kind: string, -- "boost" | "cosmetic"
	category: string,
	minutes: number?,
	grants: { string }?,
}

local Monetization = {}

Monetization.Passes = {
	PremiumLane = { id = 0, name = "Season Track Premium Lane", price = 399, icon = "🌅", desc = "Unlocks the premium cosmetic lane for this season. Every reward is shown before you buy. No tiers or Stars for sale." },
	GalleryBox = { id = 0, name = "Gallery Box Seat", price = 149, icon = "🎟️", desc = "A cushioned box seat in the Viewing Gallery and a gold name in the gift feed. Cosmetic." },
	BigSponsor = { id = 0, name = "Big Sponsor", price = 249, icon = "🪂", desc = "Earn Favor twice as fast while spectating. Favor is never sold." },
	StarterSatchel = { id = 0, name = "Starter Satchel", price = 199, icon = "🎒", desc = "Start casual Jubilees with an apple and a canteen. Also free at Season Track tier 12." },
	TrailBoots = { id = 0, name = "Trail Boots", price = 299, icon = "🥾", desc = "+5% stamina regen in casual Jubilees and a dusty footprint trail. Free at tier 24." },
	TrainingRetry = { id = 0, name = "Extra Training Try", price = 99, icon = "🎯", desc = "One extra try at the pregame target range score each match. Cosmetic score only." },
} :: { [string]: Pass }

Monetization.Products = {
	RenownBoost = { id = 0, name = "Renown Boost", price = 49, icon = "✨", kind = "boost", category = "Boosts", minutes = 30, desc = "+50% Renown for 30 minutes. Everyone else in the server gets a free 5-minute Renown Shower." },
	FadeEmber = { id = 0, name = "Ember Knockout Fade", price = 75, icon = "🔥", kind = "cosmetic", category = "Fades", grants = { "fade_ember" }, desc = "Your knockouts dissolve into warm ember light. Cosmetic." },
	FadeVeil = { id = 0, name = "Veil Shimmer Fade", price = 75, icon = "💠", kind = "cosmetic", category = "Fades", grants = { "fade_veil" }, desc = "Your knockouts dissolve into cyan shimmer. Cosmetic." },
	ParadeSunrise = { id = 0, name = "Sunrise Parade Coat", price = 120, icon = "🧥", kind = "cosmetic", category = "Parade", grants = { "parade_sunrise" }, desc = "A glowing coat for the Spire parade. Cosmetic." },
	ParadeEmber = { id = 0, name = "Ember Parade Cape", price = 120, icon = "🧣", kind = "cosmetic", category = "Parade", grants = { "parade_ember" }, desc = "A cape that trails sparks on the parade chariot. Cosmetic." },
	BowGilded = { id = 0, name = "Gilded Bow Skin", price = 90, icon = "🏹", kind = "cosmetic", category = "Skins", grants = { "skin_bow_gilded" }, desc = "Same stats, new look. Cosmetic." },
	SpearAshen = { id = 0, name = "Ashen Spear Skin", price = 90, icon = "🔱", kind = "cosmetic", category = "Skins", grants = { "skin_spear_ashen" }, desc = "Same stats, new look. Cosmetic." },
	PackLantern = { id = 0, name = "Lantern Backpack Skin", price = 80, icon = "🏮", kind = "cosmetic", category = "Skins", grants = { "skin_pack_lantern" }, desc = "Same slots, new look. Cosmetic." },
} :: { [string]: Product }

-- True when nothing in this module is a random/gacha item (checked by tests).
function Monetization.noRandomItems(): boolean
	for _, p in pairs(Monetization.Products) do
		if p.kind ~= "boost" and p.kind ~= "cosmetic" then
			return false
		end
	end
	return true
end

return Monetization

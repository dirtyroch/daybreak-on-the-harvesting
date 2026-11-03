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
}
export type Bundle = { id: string, name: string, price: number, icon: string, desc: string, items: { string }, once: boolean? }

-- One developer product per price point. Covers R$25 to R$1,999.
Store.TIERS = { 25, 49, 99, 149, 199, 299, 399, 499, 799, 1299, 1999 }
Store.FEATURED_PER_WEEK = 6
Store.WEEK = 604800
Store.EPOCH_MONDAY = 345600 -- Monday 5 Jan 1970 00:00 UTC

Store.CATS = { "Arms", "Fades", "Poses", "Emotes", "Wraps", "Nametags", "Parade", "Rusty", "Reach" }
Store.SLOTS = { "bow", "spear", "knife", "fade", "pose", "emote", "wrap", "nametag", "parade", "rusty", "banner" }

local items: { Item } = {
	-- Arms: weapon skins. Same stats, new look: the arrow / spear streak everyone sees, the hotbar
	-- tile and the kill-feed icon. (Held 3D models need MeshParts from Studio; see PUBLISHING §11.)
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
	{ id = "pose_salute", name = "Reach Salute", cat = "Poses", slot = "pose", price = 49, icon = "🫡", color = "#E8D9B5", desc = "A proud salute to your Reach on the podium.", rot = false, anim = 0 },
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
}

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
		"pose_salute", "pose_bow", "pose_lantern", "pose_crown", "pose_regent",
		"emote_tip", "emote_toast", "emote_twirl", "emote_lantern",
		"wrap_gold", "wrap_lantern", "wrap_meadow", "wrap_star",
	} },
} :: { Bundle }

function Store.bundle(id: string): Bundle?
	for _, b in ipairs(Store.BUNDLES) do
		if b.id == id then
			return b
		end
	end
	return nil
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

function Store.rotatingPool(): { Item }
	local pool = {}
	for _, it in ipairs(Store.ITEMS) do
		if it.rot then
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

-- The featured rotating items for a week. Every rotating item appears once per cycle.
function Store.rotation(week: number): { Item }
	local pool = Store.rotatingPool()
	local cycle = Store.cycleWeeks()
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
	for w = week, week + Store.cycleWeeks() do
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
		if it then
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
			return false, nw and string.format("Back in the shop in %d week%s.", nw - week, nw - week == 1 and "" or "s") or "Not in the shop this season."
		end
		return true, nil
	end
	local b = Store.bundle(o.id)
	if not b then
		return false, "Not found."
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
		if not Store.tierKey(it.price) then
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
	return errs
end

return Store

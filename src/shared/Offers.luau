--!strict
--[[
	Offers.luau: the few moments the game shows a cosmetic at a natural point. Every card is
	calm (checked against Store.PRESSURE_WORDS in tests), has a "No thanks" that closes it for
	the rest of the session, and never appears for players whose policy hides paid items.

	1. Fade preview after a match with a knockout: "See your knockout with Comet Tail". It
	   plays a knockout on a local practice double of you with that fade. Trying is free.
	2. First win: a free earned pose (First Light), then one quiet line about the Locker.
	3. Gallery partner moment: when your partner is in the last 10 or low on Pep, a card
	   suggests a free Favor gift and shows which Wrap it falls under.
]]
-- In Roblox, siblings come from script.Parent; under Lune tests (no `script`), by path.
local Store: any, Content: any
if typeof(script) == "Instance" then
	local here = (script :: any).Parent
	Store = require(here.Store) :: any
	Content = require(here.Content) :: any
else
	Store = (require :: any)("./Store")
	Content = (require :: any)("./Content")
end

local Offers = {}

Offers.MAX_PER_SESSION = 2 -- shop-linked cards per session (first-win gift and Gallery card excluded)

export type Card = { kind: string, title: string, body: string, itemId: string?, price: number?, tryLabel: string?, buyLabel: string?, noLabel: string, style: string?, color: string?, target: string?, gift: string? }

-- Choose a fade to preview after a match: the cheapest fade in the shop this week the player
-- doesn't own. Nil if they own them all or have no knockouts.
function Offers.fadePreview(owned: { [string]: any }, week: number, knocks: number): Card?
	if knocks <= 0 then
		return nil
	end
	local best = nil
	for _, it in ipairs(Store.ITEMS) do
		if it.slot == "fade" and not it.earned and not owned[it.id] and Store.inRotation(it.id, week) and Content.FADES[it.id] then
			if not best or it.price < best.price then
				best = it
			end
		end
	end
	if not best then
		return nil
	end
	return {
		kind = "fadePreview",
		title = "See your knockout with " .. best.name,
		body = string.format("Watch a knockout play out on your practice double with the %s fade. Only you see it, and trying is free.", best.name),
		itemId = best.id,
		price = best.price,
		tryLabel = "▶ Watch it",
		buyLabel = "Get it (R$ " .. best.price .. ")",
		noLabel = "No thanks",
	}
end

-- First win: the free gift, and a single gentle pointer to the Locker.
function Offers.firstWin(name: string): Card
	return {
		kind = "firstWin",
		title = "First win, " .. name .. "!",
		body = "The First Light pose is yours, free. It plays on the podium every time you win. You can change it in the Locker.",
		itemId = "pose_firstlight",
		tryLabel = "Equip First Light",
		noLabel = "Close",
	}
end

-- Gallery: when should we show the partner card?
function Offers.partnerMoment(alive: number, partnerPep: number, pepMax: number): boolean
	return alive <= 10 or partnerPep <= pepMax * 0.35
end
function Offers.partnerCard(partner: string, giftName: string, cost: number, favor: number, wrapName: string?): Card
	local canAfford = favor >= cost
	return {
		kind = "partnerGift",
		title = partner .. " could use a hand",
		body = canAfford
				and string.format("Send %s a %s for %d Favor (your partner price). It floats down under your %s.", partner, giftName, cost, wrapName or "Gallery Gold Wrap")
			or string.format("A %s costs %d Favor. You earn Favor by watching; you have %d.", giftName, cost, favor),
		tryLabel = canAfford and ("Send " .. giftName) or nil,
		noLabel = "Not now",
	}
end

-- Copy check used by tests: no pressure words in any card.
function Offers.calm(c: Card): boolean
	local text = (c.title .. " " .. c.body .. " " .. (c.buyLabel or "") .. " " .. (c.tryLabel or "") .. " " .. c.noLabel):lower()
	for _, w in ipairs(Store.PRESSURE_WORDS) do
		if text:find(w, 1, true) then
			return false
		end
	end
	return true
end

return Offers

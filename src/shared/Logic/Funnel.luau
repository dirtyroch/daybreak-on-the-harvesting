--!strict
--[[
	Funnel.luau: the step lists the server logs to AnalyticsService so the first-purchase funnel
	and onboarding can be measured after launch (Creator Dashboard > Analytics > Funnels).
	Server-only logging (Roblox ignores client and Studio events). Pure step lookup here.
]]
local Funnel = {}

Funnel.SHOP = "ShopFirstPurchase"
Funnel.SHOP_STEPS = { "shop_open", "item_view", "try_on", "prompt", "purchase" }
Funnel.ONBOARDING_STEPS = { "joined", "first_match", "crate", "weapon", "eat", "veil", "gallery", "second_match", "first_shop_open" }

function Funnel.step(list: { string }, name: string): number?
	return table.find(list, name)
end

-- Session id for a shop visit: one per player per shop open (no GUID needed in tests).
function Funnel.session(userId: number, opens: number): string
	return tostring(userId) .. ":" .. tostring(opens)
end

return Funnel

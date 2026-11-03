--!strict
--[[
	Store rules from PolicyService:GetPolicyInfoForPlayerAsync, as a pure helper.
	Fail closed: until the policy loads (or if it never does), the shop stays hidden.
	This game sells no random items and nothing tradable, so in practice only the "not loaded"
	case hides things; the flags still gate any future item that sets `random` or `tradable`.
]]
local Policy = {}

export type Info = {
	loaded: boolean,
	paidRandomRestricted: boolean,
	tradingAllowed: boolean,
	adsAllowed: boolean,
	links: { string },
}
export type Sellable = { random: boolean?, tradable: boolean?, ad: boolean? }

function Policy.unknown(): Info
	return { loaded = false, paidRandomRestricted = true, tradingAllowed = false, adsAllowed = false, links = {} }
end

-- Map the raw PolicyService table (keys can be missing) to our flags.
function Policy.fromRaw(raw: any): Info
	if type(raw) ~= "table" then
		return Policy.unknown()
	end
	local links = {}
	if type(raw.AllowedExternalLinkReferences) == "table" then
		for _, v in ipairs(raw.AllowedExternalLinkReferences) do
			if type(v) == "string" then
				table.insert(links, v)
			end
		end
	end
	return {
		loaded = true,
		-- missing = assume restricted
		paidRandomRestricted = raw.ArePaidRandomItemsRestricted ~= false,
		tradingAllowed = raw.IsPaidItemTradingAllowed == true,
		adsAllowed = raw.AreAdsAllowed == true,
		links = links,
	}
end

function Policy.shopVisible(p: Info): boolean
	return p.loaded
end

function Policy.canSell(p: Info, item: Sellable): boolean
	if not p.loaded then
		return false
	end
	if item.random and p.paidRandomRestricted then
		return false
	end
	if item.tradable and not p.tradingAllowed then
		return false
	end
	if item.ad and not p.adsAllowed then
		return false
	end
	return true
end

return Policy

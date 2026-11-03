--!strict
--[[
	Arena twists. Every match rolls one small twist from the week's pool, and every week has a
	Jubilee Rule that applies to all matches (shown in the lobby and on the Season board).
	Twists change the arena, never the shop; all are free and all are announced before launch.
]]
-- Same hash as TimeUtil.hash (kept local so this module has no requires and runs in Lune tests).
local function hash(n: number): number
	return math.floor((n * 2654435761) % 4294967296)
end

local Twists = {}

export type Twist = { id: string, name: string, text: string, mods: { [string]: number } }

Twists.MATCH = {
	{ id = "longbows", name = "Long Bows", text = "Bows reach 25% farther.", mods = { bowRange = 1.25 } },
	{ id = "feast", name = "Feast Crates", text = "Twice as many snacks in crates.", mods = { snacks = 2 } },
	{ id = "quickveil", name = "Quick Veil", text = "The Veil moves 15% sooner.", mods = { veil = 0.85 } },
	{ id = "twilight", name = "Twilight Arena", text = "The arena starts at dusk. Lanterns glow.", mods = { clock = 18.6 } },
	{ id = "featherfall", name = "Featherfall", text = "Lower gravity. Big jumps!", mods = { gravity = 0.6 } },
	{ id = "finchday", name = "Finch Day", text = "Candyfinches come twice.", mods = { finches = 2 } },
	{ id = "richhub", name = "Golden Sundial", text = "Extra crates at the Sundial.", mods = { hubCrates = 1.5 } },
	{ id = "fog", name = "Morning Fog", text = "Thick fog until the first Veil shrink.", mods = { fog = 1 } },
} :: { Twist }

Twists.WEEKLY = {
	{ id = "w_gallery", name = "Gallery Week", text = "Gifts cost 25% less Favor.", mods = { giftCost = 0.75 } },
	{ id = "w_tokens", name = "Token Hunt", text = "6 Jubilee Tokens per arena instead of 4.", mods = { tokens = 6 } },
	{ id = "w_encore", name = "Double Encore", text = "The Gallery votes two contenders back in.", mods = { encores = 2 } },
	{ id = "w_stars", name = "Starfall", text = "+1 Daybreak Star for every match.", mods = { bonusStars = 1 } },
} :: { Twist }

function Twists.weekly(week: number): Twist
	return Twists.WEEKLY[(week % #Twists.WEEKLY) + 1]
end

-- Match twist from a match counter + week (different every match, same across servers by seed).
function Twists.forMatch(matchNo: number, week: number): Twist
	local h = hash(week * 97 + matchNo)
	return Twists.MATCH[((h // 4096) % #Twists.MATCH) + 1]
end

function Twists.mod(list: { Twist }, key: string, default: number): number
	local v = default
	for _, t in ipairs(list) do
		local m = t.mods[key]
		if m ~= nil then
			if key == "tokens" or key == "encores" or key == "clock" or key == "fog" or key == "bonusStars" then
				v = m
			else
				v *= m
			end
		end
	end
	return v
end

return Twists

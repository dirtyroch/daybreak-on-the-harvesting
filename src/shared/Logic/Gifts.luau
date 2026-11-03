--!strict
--[[
	Viewing Gallery gifts. Spectators earn Favor just by watching (never bought with Robux).
	Gifts get pricier as the field shrinks so the final few aren't flooded; your Reach partner
	gets a discount. Each contender can receive one gift every `cooldown` seconds.
]]
local Gifts = {}

function Gifts.cost(base: number, alive: number, isPartner: boolean, discount: number, weekMult: number): number
	local scale = 1
	if alive <= 4 then
		scale = 2
	elseif alive <= 10 then
		scale = 1.5
	elseif alive <= 24 then
		scale = 1.2
	end
	local c = base * scale * weekMult
	if isPartner then
		c *= discount
	end
	return math.max(1, math.floor(c + 0.5))
end

-- lastGift: target id -> time of their last received gift
function Gifts.canSend(lastGift: { [string]: number }, target: string, now: number, cooldown: number): (boolean, number)
	local t = lastGift[target]
	if t and now - t < cooldown then
		return false, cooldown - (now - t)
	end
	return true, 0
end

return Gifts

--!strict
-- Crate rolls from a weight table. Crates are free and found in the arena; odds are shown in Help.
-- Nothing here is ever sold.
local Loot = {}

local function keys(weights: { [string]: number }): { string }
	local k = {}
	for id in pairs(weights) do
		table.insert(k, id)
	end
	table.sort(k)
	return k
end

-- u in [0,1)
function Loot.pick(weights: { [string]: number }, u: number): string
	local total = 0
	local ks = keys(weights)
	for _, id in ipairs(ks) do
		total += weights[id]
	end
	local x = u * total
	for _, id in ipairs(ks) do
		x -= weights[id]
		if x < 0 then
			return id
		end
	end
	return ks[#ks]
end

function Loot.odds(weights: { [string]: number }): { [string]: number }
	local total = 0
	for _, w in pairs(weights) do
		total += w
	end
	local out = {}
	for id, w in pairs(weights) do
		out[id] = w / total
	end
	return out
end

return Loot

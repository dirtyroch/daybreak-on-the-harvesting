--!strict
-- Food and Water: slow meters that drain over a match. Snacks refill them. Low meters only slow
-- stamina regeneration; they never cost Pep, so they can't knock anyone out on their own.
local Meters = {}

export type Rules = { max: number, start: number, foodDrain: number, waterDrain: number, low: number, lowRegen: number }
export type M = { food: number, water: number }

function Meters.new(r: Rules): M
	return { food = r.start, water = r.start }
end

function Meters.step(m: M, r: Rules, dt: number, drainMult: number): M
	m.food = math.max(0, m.food - r.foodDrain * dt * drainMult)
	m.water = math.max(0, m.water - r.waterDrain * dt * drainMult)
	return m
end

function Meters.eat(m: M, r: Rules, food: number?, water: number?)
	m.food = math.min(r.max, m.food + (food or 0))
	m.water = math.min(r.max, m.water + (water or 0))
end

-- Stamina regen multiplier from the meters.
function Meters.regenMult(m: M, r: Rules): number
	local k = 1
	if m.food < r.low then
		k *= r.lowRegen
	end
	if m.water < r.low then
		k *= r.lowRegen
	end
	return k
end

return Meters

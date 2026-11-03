--!strict
-- The Veil (force field) timeline: radius over time, warnings and damage.
local Veil = {}

export type Phase = { at: number, from: number, to: number, dur: number }

function Veil.radiusAt(t: number, phases: { Phase }, startRadius: number): number
	local r = startRadius
	for _, p in ipairs(phases) do
		if t < p.at then
			return r
		elseif t < p.at + p.dur then
			local a = (t - p.at) / p.dur
			return p.from + (p.to - p.from) * a
		else
			r = p.to
		end
	end
	return r
end

-- 0 before the first shrink starts, 1 during/after phase 1, and so on.
function Veil.phaseIndex(t: number, phases: { Phase }): number
	local idx = 0
	for i, p in ipairs(phases) do
		if t >= p.at then
			idx = i
		end
	end
	return idx
end

-- Seconds until the next shrink starts (nil when no more shrinks), and that phase's target radius.
function Veil.nextShrink(t: number, phases: { Phase }): (number?, number?)
	for _, p in ipairs(phases) do
		if t < p.at then
			return p.at - t, p.to
		end
	end
	return nil, nil
end

function Veil.isShrinking(t: number, phases: { Phase }): boolean
	for _, p in ipairs(phases) do
		if t >= p.at and t < p.at + p.dur then
			return true
		end
	end
	return false
end

function Veil.damage(t: number, phases: { Phase }, table_: { number }): number
	local i = Veil.phaseIndex(t, phases) + 1
	return table_[math.min(i, #table_)]
end

-- A twist can speed the whole timeline up (e.g. Quick Veil = 0.85).
function Veil.scaled(phases: { Phase }, k: number): { Phase }
	local out = {}
	for _, p in ipairs(phases) do
		table.insert(out, { at = math.floor(p.at * k), from = p.from, to = p.to, dur = math.max(10, math.floor(p.dur * k)) })
	end
	return out
end

function Veil.outside(dx: number, dz: number, radius: number): boolean
	return dx * dx + dz * dz > radius * radius
end

return Veil

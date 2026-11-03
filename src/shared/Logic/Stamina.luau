--!strict
--[[
	Server-owned stamina and a simple movement sanity check.
	The client only says "I want to sprint"; the server drains/refills stamina, sets WalkSpeed,
	and rubber-bands anyone who moves much faster than their speed allows for a few seconds.
]]
local Stamina = {}

export type Rules = { max: number, drain: number, regen: number, resume: number }
export type S = { value: number, wants: boolean, sprinting: boolean, tired: boolean }

function Stamina.new(r: Rules): S
	return { value = r.max, wants = false, sprinting = false, tired = false }
end

-- One step. `moving` = actually moving; `regenMult` = 1 + bonuses (Trail Boots in casual).
function Stamina.step(s: S, r: Rules, dt: number, moving: boolean, regenMult: number): S
	if s.tired and s.value >= r.resume then
		s.tired = false
	end
	if s.wants and moving and not s.tired and s.value > 0 then
		s.sprinting = true
		s.value = math.max(0, s.value - r.drain * dt)
		if s.value <= 0 then
			s.tired = true
			s.sprinting = false
		end
	else
		s.sprinting = false
		s.value = math.min(r.max, s.value + r.regen * regenMult * dt)
	end
	return s
end

function Stamina.add(s: S, r: Rules, amount: number)
	s.value = math.clamp(s.value + amount, 0, r.max)
end

-- Horizontal distance moved in `dt` seconds vs. the fastest legal speed.
function Stamina.tooFast(dist: number, dt: number, maxSpeed: number, slack: number, grace: number): boolean
	return dist > maxSpeed * dt * slack + grace
end

return Stamina

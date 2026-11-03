--!strict
--[[
	Contender level (1-50) and prestige (Reaped -> Contender -> Favorite -> Champion -> Legend).
	Level only unlocks cosmetics and titles. It never changes combat.
]]
local Leveling = {}

export type State = { level: number, xp: number, prestige: number }

function Leveling.xpToNext(level: number): number
	return 100 + 25 * (math.max(1, level) - 1)
end

-- Adds Renown. Returns how many levels were gained. XP stops at the cap until you prestige.
function Leveling.add(s: State, amount: number, cap: number): number
	local gained = 0
	s.xp += math.max(0, math.floor(amount))
	while s.level < cap and s.xp >= Leveling.xpToNext(s.level) do
		s.xp -= Leveling.xpToNext(s.level)
		s.level += 1
		gained += 1
	end
	if s.level >= cap then
		s.xp = math.min(s.xp, Leveling.xpToNext(cap))
	end
	return gained
end

function Leveling.canPrestige(s: State, cap: number, prestigeCap: number): boolean
	return s.level >= cap and s.prestige < prestigeCap
end

-- Prestige resets level to 1 and grants the next rank's frame and title (cosmetic only).
function Leveling.prestige(s: State, cap: number, prestigeCap: number): boolean
	if not Leveling.canPrestige(s, cap, prestigeCap) then
		return false
	end
	s.prestige += 1
	s.level = 1
	s.xp = 0
	return true
end

-- Total Renown needed to reach a level from level 1.
function Leveling.totalTo(level: number): number
	local t = 0
	for l = 1, level - 1 do
		t += Leveling.xpToNext(l)
	end
	return t
end

-- Play streak: back-to-back matches within `window` seconds add +step XP each, up to max.
export type Play = { count: number, lastEnd: number }
function Leveling.playStreak(p: Play, now: number, window: number): number
	if p.lastEnd > 0 and now - p.lastEnd <= window then
		p.count += 1
	else
		p.count = 1
	end
	p.lastEnd = now
	return p.count
end

function Leveling.playMult(count: number, step: number, maxBonus: number): number
	return 1 + math.min(maxBonus, step * math.max(0, count - 1))
end

return Leveling

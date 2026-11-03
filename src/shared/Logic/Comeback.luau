--!strict
--[[
	Comeback.luau: a warm welcome for contenders who've been away, never a guilt trip.

	Away 3+ days: Rusty's welcome-back letter, 30 Favor for your next Gallery visit and a
	Homecoming bonus of +50% Renown for your next 3 matches (cosmetic progress only, casual).
	Away 14+ days: the same plus Season catch-up: Daybreak Stars count double until you reach
	the tier a weekly player would be at this week (never past it).
	The streak itself is untouched (Streak.luau already forgives one miss a week).
]]
local Comeback = {}

Comeback.MIN_DAYS = 3
Comeback.LONG_DAYS = 14
Comeback.FAVOR = 30
Comeback.MATCHES = 3
Comeback.RENOWN_MULT = 0.5
Comeback.TIERS_PER_WEEK = 4 -- a weekly player's pace on the Season Track

export type State = { lastSeenDay: number, homecoming: number, catchUpTier: number, welcomedDay: number }

function Comeback.new(): State
	return { lastSeenDay = -1, homecoming = 0, catchUpTier = 0, welcomedDay = -1 }
end

export type Welcome = { days: number, favor: number, matches: number, catchUpTier: number, long: boolean }

-- Call on join. Returns a Welcome when it applies (once per return), and records today.
function Comeback.onJoin(s: State, today: number, seasonWeek: number?, currentTier: number): Welcome?
	local last = s.lastSeenDay
	s.lastSeenDay = today
	if last < 0 or s.welcomedDay == today then
		return nil
	end
	local days = today - last
	if days < Comeback.MIN_DAYS then
		return nil
	end
	s.welcomedDay = today
	s.homecoming = Comeback.MATCHES
	local long = days >= Comeback.LONG_DAYS
	local target = 0
	if long and seasonWeek then
		target = math.max(currentTier, seasonWeek * Comeback.TIERS_PER_WEEK)
		s.catchUpTier = target
	end
	return { days = days, favor = Comeback.FAVOR, matches = Comeback.MATCHES, catchUpTier = target, long = long }
end

-- Extra Renown multiplier for a finished match (and uses one Homecoming match).
function Comeback.useMatch(s: State): number
	if s.homecoming > 0 then
		s.homecoming -= 1
		return Comeback.RENOWN_MULT
	end
	return 0
end

-- Star multiplier while the player is below their catch-up tier.
function Comeback.starMult(s: State, currentTier: number): number
	if s.catchUpTier > 0 and currentTier < s.catchUpTier then
		return 2
	end
	return 1
end

return Comeback

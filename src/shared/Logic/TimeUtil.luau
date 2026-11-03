--!strict
-- Day and week numbers (UTC) used by streaks, challenges, weekly rules and Reach standings.
local TimeUtil = {}

function TimeUtil.day(t: number): number
	return math.floor(t / 86400)
end

-- Weeks start on Monday (1970-01-01 was a Thursday, hence the +3).
function TimeUtil.week(t: number): number
	return math.floor((TimeUtil.day(t) + 3) / 7)
end

function TimeUtil.clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- Small deterministic hash so every server picks the same daily challenges and twists.
function TimeUtil.hash(n: number): number
	local x = (n * 2654435761) % 4294967296
	return math.floor(x)
end

return TimeUtil

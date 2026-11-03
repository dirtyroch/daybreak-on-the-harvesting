--!strict
--[[
	Reach loyalty. Pick a home Reach once (change it once a week). Every win and top-5 finish by
	anyone repping that Reach adds points to the weekly server-wide table. The top 3 Reaches each
	week earn a cosmetic banner for everyone who played a match for them that week.
]]
local ReachStandings = {}

ReachStandings.POINTS = { win = 10, top5 = 3, knock = 1 }

export type Row = { reach: string, points: number }

function ReachStandings.add(tbl: { [string]: number }, reach: string, points: number)
	tbl[reach] = (tbl[reach] or 0) + points
end

function ReachStandings.sorted(tbl: { [string]: number }): { Row }
	local rows: { Row } = {}
	for r, p in pairs(tbl) do
		table.insert(rows, { reach = r, points = p })
	end
	table.sort(rows, function(a: Row, b: Row): boolean
		if a.points == b.points then
			return a.reach < b.reach
		end
		return a.points > b.points
	end)
	return rows
end

function ReachStandings.pointsFor(place: number, knocks: number): number
	local p = knocks * ReachStandings.POINTS.knock
	if place == 1 then
		p += ReachStandings.POINTS.win
	elseif place <= 5 then
		p += ReachStandings.POINTS.top5
	end
	return p
end

-- Banner for a finished week: top 3 Reaches by points (ties broken by name).
function ReachStandings.banners(tbl: { [string]: number }): { string }
	local out = {}
	for i, row in ipairs(ReachStandings.sorted(tbl)) do
		if i > 3 or row.points <= 0 then
			break
		end
		table.insert(out, row.reach)
	end
	return out
end

-- Players can change their home Reach once per week.
function ReachStandings.canChange(lastChangeWeek: number, week: number): boolean
	return lastChangeWeek < week
end

return ReachStandings

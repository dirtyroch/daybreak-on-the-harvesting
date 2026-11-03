--!strict
--[[
	The end-of-match card. Shows how close you got and one honest, specific next goal.
	Never shames, never says "buy". Copy is short and readable at a glance.
]]
local NearMiss = {}

export type Result = {
	place: number,
	size: number,
	knocks: number,
	survived: number, -- seconds
	bestPlace: number, -- previous best (0 = none)
	nextKnockGoal: number?, -- knocks needed for the next daily/weekly step
	winnerPepLeft: number?,
	tapperName: string?,
}

local function ordinal(n: number): string
	local suf = "th"
	local m100 = n % 100
	if m100 < 11 or m100 > 13 then
		local m = n % 10
		if m == 1 then
			suf = "st"
		elseif m == 2 then
			suf = "nd"
		elseif m == 3 then
			suf = "rd"
		end
	end
	return tostring(n) .. suf
end
NearMiss.ordinal = ordinal

function NearMiss.headline(r: Result): string
	if r.place == 1 then
		return "Champion at daybreak!"
	end
	return string.format("%s of %d!", ordinal(r.place), r.size)
end

-- Up to three short lines, most motivating first.
function NearMiss.lines(r: Result): { string }
	local out = {}
	if r.place == 2 and r.winnerPepLeft then
		table.insert(out, string.format("So close! The champion had only %d Pep left.", math.max(1, math.floor(r.winnerPepLeft))))
	elseif r.place == 2 then
		table.insert(out, "So close! One more knock and it was yours.")
	elseif r.place <= 5 then
		table.insert(out, string.format("Top 5! Just %d more to outlast.", r.place - 1))
	elseif r.place <= 10 then
		table.insert(out, string.format("Top 10! %d spots from the podium.", r.place - 3))
	end
	if r.bestPlace > 0 and r.place < r.bestPlace then
		table.insert(out, "New personal best! (was " .. ordinal(r.bestPlace) .. ")")
	elseif r.bestPlace > 0 and r.place > 1 and r.place - r.bestPlace <= 3 and r.place ~= r.bestPlace then
		table.insert(out, string.format("%d places off your best (%s).", r.place - r.bestPlace, ordinal(r.bestPlace)))
	end
	if r.nextKnockGoal and r.nextKnockGoal > 0 and r.nextKnockGoal <= 2 then
		table.insert(out, string.format("%d more knock%s finishes a challenge.", r.nextKnockGoal, r.nextKnockGoal == 1 and "" or "s"))
	end
	local mins = math.floor(r.survived / 60)
	if #out < 3 and mins >= 1 then
		table.insert(out, string.format("You lasted %d:%02d.", mins, math.floor(r.survived) % 60))
	end
	while #out > 3 do
		table.remove(out)
	end
	return out
end

return NearMiss

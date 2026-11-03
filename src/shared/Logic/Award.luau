--!strict
--[[
	Match rewards as pure math, plus the Encore "top-up".
	A contender knocked out, voted back in by the Gallery and then finishing higher is paid once
	at the knockout and then topped up to the better finish (never paid twice for the match).
]]
local Award = {}

export type Result = { place: number, size: number, knocks: number, crates: number, encore: boolean, pactKept: boolean? }

function Award.baseXp(r: Result, X: any): number
	local base = X.match + (r.size + 1 - r.place) * X.perPlaceAbove + r.knocks * X.knock + r.crates * X.crate
	if r.place == 1 then
		base += X.win
	end
	if r.place <= 10 then
		base += X.top10
	end
	if r.encore then
		base += X.encore
	end
	if r.pactKept then
		base += X.pactKept
	end
	return base
end

function Award.stars(place: number, S: any, bonus: number): number
	local s = S.match + bonus
	if place == 1 then
		s += S.win
	elseif place <= 10 then
		s += S.top10
	end
	return s
end

export type TopUp = { xp: number, stars: number, knocks: number, win: boolean, top10: boolean, top5: boolean, encore: boolean }

-- What's still owed after the first payout, given the final result. Never negative.
function Award.topUp(first: Result, final: Result, X: any, S: any): TopUp
	local place = math.min(first.place, final.place)
	local f = { place = place, size = final.size, knocks = final.knocks, crates = final.crates, encore = final.encore, pactKept = final.pactKept or first.pactKept }
	return {
		xp = math.max(0, Award.baseXp(f, X) - Award.baseXp(first, X)),
		stars = math.max(0, Award.stars(place, S, 0) - Award.stars(first.place, S, 0)),
		knocks = math.max(0, final.knocks - first.knocks),
		win = place == 1 and first.place ~= 1,
		top10 = place <= 10 and first.place > 10,
		top5 = place <= 5 and first.place > 5,
		encore = final.encore and not first.encore,
	}
end

return Award

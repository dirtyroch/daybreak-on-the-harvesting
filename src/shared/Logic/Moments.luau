--!strict
--[[
	Moments.luau: which match results are worth a "Share this moment" card, and the small
	payload that goes with a shared screenshot.

	The client takes the screenshot with CaptureService and offers Roblox's own share sheet only
	when PolicyService says content sharing is allowed. Friends who open the shared capture join
	with launch data "ref:<userId>;m:<moment>", so the existing invite reward still works.
]]
local Moments = {}

local Names: any
if typeof(script) == "Instance" then
	Names = require((script :: any).Parent.Parent.Names) :: any
else
	Names = (require :: any)("../Names")
end

export type Result = { place: number, knocks: number, veilBreaker: boolean?, encoreWon: boolean?, archive: boolean?, partyBest: boolean? }
export type Moment = { id: string, title: string, caption: string, rank: number }

Moments.LIST = {
	win = { id = "win", title = "Last one standing", caption = "Last one standing in " .. Names.TITLE .. "!", rank = 1 },
	veil = { id = "veil", title = "Veil Breaker", caption = "Outran the Veil to the very end.", rank = 2 },
	encore = { id = "encore", title = "Encore hero", caption = "Won the Gallery's Encore vote.", rank = 3 },
	top3 = { id = "top3", title = "Top 3", caption = "Made the final three!", rank = 4 },
	knocks = { id = "knocks", title = "Five knockouts", caption = "Five knockouts in one match.", rank = 5 },
	archive = { id = "archive", title = "Archive Reel", caption = "Made the top 5 in an Archive Reel match.", rank = 6 },
	party = { id = "party", title = "Best in the party", caption = "Best finish in our party tonight.", rank = 7 },
} :: { [string]: Moment }
Moments.MAX_LAUNCH_BYTES = 200

-- The single best moment for a result (one card per match, never a nag), or nil.
function Moments.pick(r: Result): Moment?
	local best: Moment? = nil
	local function try(id: string, ok: boolean?)
		if ok then
			local m = Moments.LIST[id]
			if not best or m.rank < best.rank then
				best = m
			end
		end
	end
	try("win", r.place == 1)
	try("veil", r.veilBreaker)
	try("encore", r.encoreWon)
	try("top3", r.place <= 3)
	try("knocks", r.knocks >= 5)
	try("archive", r.archive and r.place <= 5)
	try("party", r.partyBest)
	return best
end

function Moments.launchData(userId: number, momentId: string): string
	local s = "ref:" .. tostring(userId) .. ";m:" .. momentId
	return string.sub(s, 1, Moments.MAX_LAUNCH_BYTES)
end

-- Parses "ref:<id>" or "ref:<id>;m:<moment>". Returns referrer id and moment id.
function Moments.parse(data: string?): (number?, string?)
	if type(data) ~= "string" then
		return nil, nil
	end
	local id = tonumber(string.match(data, "^ref:(%d+)") or "")
	local m = string.match(data, ";m:([%w_]+)")
	return id, m
end

return Moments

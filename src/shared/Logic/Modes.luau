--!strict
--[[
	Modes.luau: Jubilee (the full 12-minute show) and Quick Trials (a ~5-minute match).

	Quick Trials keeps all 48 contenders, the map and every rule, and runs the arena clock on a
	shorter schedule: the Veil, hazards, the Encore vote and the time cap all happen sooner, and
	the pregame is the 3-second short reaping plus launch. It's the default for a player's first
	two matches (so the first session has a payoff inside 6 minutes) and anyone can pick it.
	The queue runs whichever mode most queued players picked; a tie goes to Jubilee.
]]
local Modes = {}

export type Phase = { at: number, from: number, to: number, dur: number }
export type Mode = { id: string, name: string, pace: number, ceremony: boolean, blurb: string }

Modes.JUBILEE = "jubilee"
Modes.QUICK = "quick"
Modes.LIST = {
	jubilee = { id = "jubilee", name = "Jubilee", pace = 1, ceremony = true, blurb = "The full show: reaping, parade, interviews, training and a 12-minute arena." },
	quick = { id = "quick", name = "Quick Trials", pace = 0.45, ceremony = false, blurb = "Straight to the plates. Same 48 and same rules, about 5 minutes of arena." },
} :: { [string]: Mode }
Modes.NEW_PLAYER_QUICK_MATCHES = 2 -- first two matches default to Quick Trials

function Modes.get(id: string?): Mode
	return Modes.LIST[id or ""] or Modes.LIST.jubilee
end

-- The mode a player wants: their saved pick, else Quick for brand-new players.
function Modes.preferred(saved: string?, matchesPlayed: number): string
	if saved == Modes.QUICK or saved == Modes.JUBILEE then
		return saved :: string
	end
	return if matchesPlayed < Modes.NEW_PLAYER_QUICK_MATCHES then Modes.QUICK else Modes.JUBILEE
end

-- Majority of the queued humans' picks; ties and an empty queue go to Jubilee.
function Modes.pick(prefs: { string }): string
	local q, j = 0, 0
	for _, p in ipairs(prefs) do
		if p == Modes.QUICK then
			q += 1
		else
			j += 1
		end
	end
	return if q > j then Modes.QUICK else Modes.JUBILEE
end

-- Scale a schedule time (seconds into the arena) to the mode's pace.
function Modes.at(mode: Mode, t: number): number
	return math.floor(t * mode.pace)
end

function Modes.phases(mode: Mode, phases: { Phase }, twistScale: number?): { Phase }
	local k = mode.pace * (twistScale or 1)
	local out = {}
	for _, p in ipairs(phases) do
		table.insert(out, { at = math.floor(p.at * k), from = p.from, to = p.to, dur = math.max(10, math.floor(p.dur * k)) })
	end
	return out
end

-- Arena hard cap for the mode (seconds).
function Modes.cap(mode: Mode, hardCap: number): number
	return math.floor(hardCap * mode.pace)
end

-- Pregame seconds for the mode: the full ceremony, or the short reaping only.
function Modes.pregame(mode: Mode, full: number, shortReaping: number): number
	return if mode.ceremony then full else shortReaping
end

return Modes

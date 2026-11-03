--!strict
--[[
	Pregame training: a 6-second target round, then a score from 1 to 10 shown to everyone.
	Targets are seeded by the server (same seed on every client), clicks are checked against the
	target windows, and the score is cosmetic plus one small catch-up rule: a low score makes
	Gallery gifts to you a bit cheaper, so there's no reason to fake a high one.
]]
local Training = {}

export type Target = { i: number, x: number, y: number, at: number, life: number }
export type Click = { i: number, t: number }

local function lcg(s: number): number
	return (s * 1103515245 + 12345) % 2147483648
end

function Training.targets(seed: number, n: number, duration: number): { Target }
	local out = {}
	local s = math.floor(seed) % 2147483648
	local gap = duration / (n + 1)
	for i = 1, n do
		s = lcg(s)
		local x = 0.15 + (s % 7000) / 10000
		s = lcg(s)
		local y = 0.25 + (s % 5000) / 10000
		table.insert(out, { i = i, x = x, y = y, at = gap * (i - 1) + 0.4, life = 1.6 })
	end
	return out
end

-- Score: 2 per hit (5 targets -> 10), +1 if your average reaction is under 0.6 s, from 1 to `max`.
function Training.score(targets: { Target }, clicks: { Click }, max: number): (number, number)
	local hit: { [number]: number } = {}
	local hits, react = 0, 0
	for _, c in ipairs(clicks) do
		local tg = targets[c.i]
		if tg and not hit[c.i] and type(c.t) == "number" and c.t >= tg.at and c.t <= tg.at + tg.life then
			hit[c.i] = c.t
			hits += 1
			react += c.t - tg.at
		end
	end
	local score = hits * 2
	if hits > 0 and react / hits < 0.6 then
		score += 1
	end
	return math.clamp(score, 1, max), hits
end

-- Stand-Ins get a steady, deterministic score (3..8) so the board isn't all bots at the top.
function Training.botScore(seed: number, id: string): number
	local h = seed
	for k = 1, #id do
		h = lcg(h + string.byte(id, k))
	end
	return 3 + h % 6
end

-- Underdog rule for Gallery gift prices.
function Training.giftMult(score: number?, underdogAt: number, mult: number): number
	if score and score <= underdogAt then
		return mult
	end
	return 1
end

return Training

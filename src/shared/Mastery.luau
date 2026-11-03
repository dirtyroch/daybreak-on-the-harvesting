--!strict
--[[
	Mastery.luau: free cosmetic progress for the weapon you actually use.

	Every bow, spear and knife look (the free default included) earns Mastery points:
	+1 for each match you finish with it equipped, +3 for each knockout with it.
	Patron Club members earn 1.5x (cosmetic only). Nothing here is sold or skippable with
	Robux, so buying a skin starts a track you fill by playing.

	Levels show to everyone: L1 a star in the kill feed, L2 a brighter tracer, L3 a gold trim
	band on the held model, L4 a sparkle, L5 "Mastered" gilded edges and a nametag star.
]]
local Mastery = {}

Mastery.THRESHOLDS = { 5, 15, 35, 70, 120 } -- points needed for levels 1..5
Mastery.MAX = #Mastery.THRESHOLDS
Mastery.PER_MATCH = 1
Mastery.PER_KNOCK = 3
Mastery.PATRON_MULT = 1.5
Mastery.SLOTS = { "bow", "spear", "knife" }

Mastery.PERKS = {
	"★ in the kill feed",
	"Brighter arrow and spear streak",
	"Gold trim band on the weapon",
	"Sparkle on the weapon",
	"Mastered: gilded edges and a ✦ nametag star",
}

-- Save key for a slot + skin ("" = the free default look).
function Mastery.key(slot: string, skinId: string?): string
	return slot .. ":" .. ((skinId and skinId ~= "") and skinId or "default")
end

function Mastery.level(points: number): number
	local lv = 0
	for i, need in ipairs(Mastery.THRESHOLDS) do
		if points >= need then
			lv = i
		end
	end
	return lv
end

-- Points to the next level (nil at max).
function Mastery.toNext(points: number): number?
	local lv = Mastery.level(points)
	if lv >= Mastery.MAX then
		return nil
	end
	return Mastery.THRESHOLDS[lv + 1] - points
end

-- Adds points. Returns new points and whether a level was gained.
function Mastery.add(book: { [string]: number }, key: string, base: number, patron: boolean?): (number, boolean)
	local before = book[key] or 0
	local gain = base
	if patron then
		gain = math.floor(base * Mastery.PATRON_MULT + 0.5)
	end
	local after = before + gain
	book[key] = after
	return after, Mastery.level(after) > Mastery.level(before)
end

function Mastery.stars(points: number): string
	local lv = Mastery.level(points)
	if lv >= Mastery.MAX then
		return "✦"
	end
	return string.rep("★", lv)
end

return Mastery

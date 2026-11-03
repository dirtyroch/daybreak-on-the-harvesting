--!strict
--[[
	Sponsor letters: a small daily package from the patrons you've won over.
	  * Patrons sign on when you hit a milestone (first top 10, first win, 10 knockouts, ...).
	    "Your home Reach" always writes, so every player gets a letter.
	  * One letter a day (UTC), whether you play or not. Unclaimed letters stack up to `maxStack`
	    so a weekend away still has something waiting, but missing days never takes anything.
	  * A letter holds Renown XP + a Favor head start for the next Viewing Gallery visit. Every
	    `cosmeticEvery`-th letter also carries a cosmetic from a fixed list, in order.
	  * Nothing here is random and nothing is sold.
]]
local Sponsors = {}

export type Patron = { id: string, name: string, stat: string, need: number, renown: number, favor: number }
export type Letters = { lastDay: number, waiting: number, claimed: number }
export type Package = { letters: number, renown: number, favor: number, cosmetics: { string }, from: { string } }

-- Which patrons have signed on, given lifetime stats.
function Sponsors.earned(patrons: { Patron }, stats: { [string]: number }): { Patron }
	local out = {}
	for _, p in ipairs(patrons) do
		if p.need <= 0 or (stats[p.stat] or 0) >= p.need then
			table.insert(out, p)
		end
	end
	return out
end

-- The next patron you could win over (for the "next sponsor" hint), or nil.
function Sponsors.nextPatron(patrons: { Patron }, stats: { [string]: number }): Patron?
	for _, p in ipairs(patrons) do
		if p.need > 0 and (stats[p.stat] or 0) < p.need then
			return p
		end
	end
	return nil
end

-- Deliver letters for the days since the last delivery. Returns how many arrived.
function Sponsors.accrue(l: Letters, today: number, maxStack: number): number
	if l.lastDay >= today then
		return 0
	end
	local days = if l.lastDay < 0 then 1 else today - l.lastDay
	local before = l.waiting
	l.waiting = math.min(maxStack, l.waiting + days)
	l.lastDay = today
	return l.waiting - before
end

-- Open every waiting letter. Cosmetics already owned are skipped (you get the next one).
function Sponsors.claim(l: Letters, signed: { Patron }, cosmeticList: { string }, cosmeticEvery: number, owned: { [string]: boolean }): Package
	local pkg: Package = { letters = 0, renown = 0, favor = 0, cosmetics = {}, from = {} }
	for _, p in ipairs(signed) do
		table.insert(pkg.from, p.name)
	end
	while l.waiting > 0 do
		l.waiting -= 1
		l.claimed += 1
		pkg.letters += 1
		for _, p in ipairs(signed) do
			pkg.renown += p.renown
			pkg.favor += p.favor
		end
		if cosmeticEvery > 0 and l.claimed % cosmeticEvery == 0 then
			for _, id in ipairs(cosmeticList) do
				if not owned[id] and not table.find(pkg.cosmetics, id) then
					table.insert(pkg.cosmetics, id)
					break
				end
			end
		end
	end
	return pkg
end

return Sponsors

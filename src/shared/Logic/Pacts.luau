--!strict
--[[
	Pacts: in-match alliances between contenders from different Reaches (Reach partners are
	already allies). Pure state + rules so the server and the tests share one source of truth.

	  offer(from, to)  -> a pending offer (expires after offerSeconds)
	  accept(to, from) -> both join one pact (max `maxSize` members)
	  canHurt(a, b)    -> members of one pact can't hurt each other
	  snap(who)        -> starts a visible wind-up (snapSeconds). While winding up the pact still
	                      protects everyone, and the other members are warned.
	  tick(now)        -> finishes wind-ups: the snapper leaves, gets a short "betrayal window"
	                      (first hit on an ex-ally deals bonus damage), and the ex-allies get a
	                      brief guard so a betrayal is a moment, not a free knockout.
	  endAll()         -> every pact dissolves at the final few (Config.Pacts.endAt).
	No chat, no free text: everything is a button press the server validates.
]]
local Pacts = {}

export type Rules = {
	maxSize: number,
	offerSeconds: number,
	snapSeconds: number,
	betrayWindow: number,
	betrayBonus: number,
	guardSeconds: number,
	guardMult: number,
	endAt: number,
	cooldown: number,
}

export type Pact = { id: number, members: { string }, formedAt: number }
export type Offer = { from: string, at: number }
export type Snap = { who: string, pact: number, at: number, doneAt: number }
export type Betrayal = { who: string, victims: { string }, untilT: number, used: boolean }

export type State = {
	nextId: number,
	pacts: { [number]: Pact },
	memberOf: { [string]: number },
	offers: { [string]: Offer }, -- to -> offer
	snaps: { [string]: Snap }, -- who -> snap
	betrayals: { [string]: Betrayal }, -- snapper -> window
	guardUntil: { [string]: number }, -- victim -> time
	lastPactAt: { [string]: number }, -- after a snap you can't re-pact right away
	ended: boolean,
}

export type Event = { kind: string, who: string?, with: { string }?, pact: number? }

function Pacts.new(): State
	return {
		nextId = 1,
		pacts = {},
		memberOf = {},
		offers = {},
		snaps = {},
		betrayals = {},
		guardUntil = {},
		lastPactAt = {},
		ended = false,
	}
end

function Pacts.pactOf(s: State, id: string): Pact?
	local p = s.memberOf[id]
	return p and s.pacts[p] or nil
end

function Pacts.allies(s: State, id: string): { string }
	local out = {}
	local p = Pacts.pactOf(s, id)
	if p then
		for _, m in ipairs(p.members) do
			if m ~= id then
				table.insert(out, m)
			end
		end
	end
	return out
end

function Pacts.same(s: State, a: string, b: string): boolean
	local pa = s.memberOf[a]
	return pa ~= nil and pa == s.memberOf[b]
end

local function size(s: State, id: string): number
	local p = Pacts.pactOf(s, id)
	return p and #p.members or 1
end

-- Can `from` offer a pact to `to` right now? Returns ok + a player-facing reason.
function Pacts.canOffer(s: State, r: Rules, from: string, to: string, alive: number, now: number): (boolean, string?)
	if s.ended or alive <= r.endAt then
		return false, "Pacts are over. It's every contender for themselves."
	end
	if from == to then
		return false, nil
	end
	if Pacts.same(s, from, to) then
		return false, "You're already in a pact together."
	end
	if s.snaps[from] then
		return false, "You're snapping your pact."
	end
	if (s.lastPactAt[from] or -math.huge) + r.cooldown > now then
		return false, "Wait a moment before making a new pact."
	end
	if s.memberOf[to] and s.memberOf[from] then
		return false, "You're both in different pacts."
	end
	if size(s, from) + size(s, to) > r.maxSize then
		return false, string.format("A pact can have at most %d contenders.", r.maxSize)
	end
	return true, nil
end

function Pacts.offer(s: State, r: Rules, from: string, to: string, alive: number, now: number): (boolean, string?)
	local ok, why = Pacts.canOffer(s, r, from, to, alive, now)
	if not ok then
		return false, why
	end
	s.offers[to] = { from = from, at = now }
	return true, nil
end

-- `to` accepts the pending offer. Returns the pact on success.
function Pacts.accept(s: State, r: Rules, to: string, alive: number, now: number): (Pact?, string?)
	local o = s.offers[to]
	if not o or now - o.at > r.offerSeconds then
		s.offers[to] = nil
		return nil, "That offer has expired."
	end
	s.offers[to] = nil
	local ok, why = Pacts.canOffer(s, r, o.from, to, alive, now)
	if not ok then
		return nil, why
	end
	local pid = s.memberOf[o.from] or s.memberOf[to]
	local p: Pact
	if pid then
		p = s.pacts[pid]
	else
		p = { id = s.nextId, members = {}, formedAt = now }
		s.pacts[p.id] = p
		s.nextId += 1
	end
	for _, m in ipairs({ o.from, to }) do
		if s.memberOf[m] == nil then
			table.insert(p.members, m)
			s.memberOf[m] = p.id
		end
	end
	return p, nil
end

function Pacts.decline(s: State, to: string)
	s.offers[to] = nil
end

local function leave(s: State, id: string)
	local pid = s.memberOf[id]
	if not pid then
		return
	end
	s.memberOf[id] = nil
	local p = s.pacts[pid]
	if p then
		local i = table.find(p.members, id)
		if i then
			table.remove(p.members, i)
		end
		if #p.members <= 1 then
			for _, m in ipairs(p.members) do
				s.memberOf[m] = nil
			end
			s.pacts[pid] = nil
		end
	end
end

-- Start the betrayal wind-up. The pact keeps protecting everyone until it completes.
function Pacts.snap(s: State, r: Rules, who: string, now: number): (Snap?, string?)
	local pid = s.memberOf[who]
	if not pid then
		return nil, "You're not in a pact."
	end
	if s.snaps[who] then
		return nil, nil
	end
	local sn = { who = who, pact = pid, at = now, doneAt = now + r.snapSeconds }
	s.snaps[who] = sn
	return sn, nil
end

-- Advance wind-ups. Returns "snapped" events (who + the ex-allies they betrayed).
function Pacts.tick(s: State, r: Rules, now: number): { Event }
	local events: { Event } = {}
	local done = {}
	for who, sn in pairs(s.snaps) do
		if now >= sn.doneAt then
			table.insert(done, who)
		end
	end
	table.sort(done)
	for _, who in ipairs(done) do
		local sn = s.snaps[who]
		s.snaps[who] = nil
		if s.memberOf[who] == sn.pact then
			local victims = Pacts.allies(s, who)
			leave(s, who)
			s.lastPactAt[who] = now
			s.betrayals[who] = { who = who, victims = victims, untilT = now + r.betrayWindow, used = false }
			for _, v in ipairs(victims) do
				s.guardUntil[v] = now + r.guardSeconds
			end
			table.insert(events, { kind = "snapped", who = who, with = victims, pact = sn.pact })
		end
	end
	return events
end

function Pacts.canHurt(s: State, a: string, b: string): boolean
	return not Pacts.same(s, a, b)
end

-- Damage multiplier for a hit from `a` on `b`: the snapper's first hit on an ex-ally inside the
-- betrayal window deals bonus damage ("Pact Snap!"); a freshly betrayed contender takes less
-- from everyone else for a moment. Returns mult and whether this hit is the betrayal strike.
function Pacts.hitMult(s: State, r: Rules, a: string, b: string, now: number): (number, boolean)
	local m = 1
	local strike = false
	local bt = s.betrayals[a]
	if bt and not bt.used and now <= bt.untilT and table.find(bt.victims, b) then
		bt.used = true
		m *= r.betrayBonus
		strike = true
	end
	if not strike and (s.guardUntil[b] or -math.huge) > now then
		m *= r.guardMult
	end
	return m, strike
end

-- A contender is out of the match: leave their pact and cancel anything pending.
function Pacts.remove(s: State, id: string)
	leave(s, id)
	s.offers[id] = nil
	s.snaps[id] = nil
	for to, o in pairs(s.offers) do
		if o.from == id then
			s.offers[to] = nil
		end
	end
end

-- Final few: every pact ends at once. Returns the pacts that were dissolved.
function Pacts.endAll(s: State): { Pact }
	local out = {}
	for _, p in pairs(s.pacts) do
		table.insert(out, p)
	end
	s.pacts = {}
	s.memberOf = {}
	s.offers = {}
	s.snaps = {}
	s.ended = true
	return out
end

return Pacts

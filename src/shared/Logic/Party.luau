--!strict
--[[
	Party.luau: friend and family groups of up to 10 who queue together.

	  * Anyone can start a party by inviting someone in the server; the inviter leads.
	  * A party is never split by the queue: either everyone in it gets a seat or it waits for
	    the next match (fill() below), and party members share one lobby banner and a party
	    results card after every match.
	  * In public matches party members can still knock each other out (fair to solo players;
	    Reach partners and pacts work as usual). In private servers the owner can turn on
	    Family Rules: the whole party is allied until 4 are left, like Reach partners.
]]
local Party = {}

Party.MAX = 10

export type State = { nextId: number, of: { [number]: number }, members: { [number]: { number } }, leader: { [number]: number }, invites: { [number]: number } }

function Party.new(): State
	return { nextId = 1, of = {}, members = {}, leader = {}, invites = {} }
end

function Party.partyOf(s: State, user: number): number?
	return s.of[user]
end

function Party.membersOf(s: State, user: number): { number }
	local pid = s.of[user]
	return if pid then s.members[pid] else { user }
end

function Party.size(s: State, pid: number): number
	return #(s.members[pid] or {})
end

-- `from` invites `to`. Returns ok, message.
function Party.invite(s: State, from: number, to: number): (boolean, string?)
	if from == to then
		return false, "You can't invite yourself."
	end
	local pid = s.of[from]
	if pid and #s.members[pid] >= Party.MAX then
		return false, "Your party is full (" .. Party.MAX .. ")."
	end
	if pid and s.of[to] == pid then
		return false, "Already in your party."
	end
	s.invites[to] = from
	return true, nil
end

-- `user` accepts the invite waiting for them. Joins (or creates) the inviter's party.
function Party.accept(s: State, user: number): (boolean, string?)
	local from = s.invites[user]
	if not from then
		return false, "No invite waiting."
	end
	s.invites[user] = nil
	local pid: number = s.of[from] or 0
	if pid == 0 then
		pid = s.nextId
		s.nextId += 1
		s.members[pid] = { from }
		s.leader[pid] = from
		s.of[from] = pid
	end
	if #s.members[pid] >= Party.MAX then
		return false, "That party is full."
	end
	Party.leave(s, user)
	table.insert(s.members[pid], user)
	s.of[user] = pid
	return true, nil
end

-- Leaves the party. A party of one disbands; the next member leads if the leader leaves.
function Party.leave(s: State, user: number)
	local pid = s.of[user]
	if not pid then
		return
	end
	s.of[user] = nil
	local list = s.members[pid]
	local i = table.find(list, user)
	if i then
		table.remove(list, i)
	end
	if #list <= 1 then
		for _, u in ipairs(list) do
			s.of[u] = nil
		end
		s.members[pid] = nil
		s.leader[pid] = nil
	elseif s.leader[pid] == user then
		s.leader[pid] = list[1]
	end
end

-- Pick who goes into a match from a queue (user ids in queue order) without splitting a party:
-- a party only takes seats if every queued member fits.
function Party.fill(s: State, queue: { number }, cap: number): { number }
	local out: { number } = {}
	local taken: { [number]: boolean } = {}
	for _, u in ipairs(queue) do
		if not taken[u] then
			local group = {}
			local pid = s.of[u]
			if pid then
				for _, m in ipairs(queue) do
					if s.of[m] == pid and not taken[m] then
						table.insert(group, m)
					end
				end
			else
				group = { u }
			end
			if #out + #group <= cap then
				for _, m in ipairs(group) do
					table.insert(out, m)
					taken[m] = true
				end
			else
				for _, m in ipairs(group) do
					taken[m] = true -- skip the whole group this round
				end
			end
		end
	end
	return out
end

-- Family Rules (private servers only): party members can't hurt each other until `untilLeft`.
function Party.canHurt(s: State, a: number, b: number, alive: number, untilLeft: number, familyRules: boolean): boolean
	if not familyRules then
		return true
	end
	local pa, pb = s.of[a], s.of[b]
	if pa and pa == pb and alive > untilLeft then
		return false
	end
	return true
end

-- The party results card: members sorted by place, the best finish and the total knockouts.
export type Line = { name: string, place: number, knocks: number }
function Party.summary(lines: { Line }): { best: Line?, knocks: number, lines: { Line } }
	local sorted = table.clone(lines)
	table.sort(sorted, function(x: Line, y: Line): boolean
		return x.place < y.place
	end)
	local k = 0
	for _, l in ipairs(sorted) do
		k += l.knocks
	end
	return { best = sorted[1], knocks = k, lines = sorted }
end

return Party

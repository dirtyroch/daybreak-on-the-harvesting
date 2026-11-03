--!strict
-- Gallery votes (hazard cards and Encore vote-backs). One vote per spectator; ties go to the
-- option listed first so results are deterministic and explainable.
local Vote = {}

export type Ballot = { options: { string }, votes: { [string]: string } }

function Vote.new(options: { string }): Ballot
	return { options = options, votes = {} }
end

function Vote.cast(b: Ballot, voter: string, option: string): boolean
	if not table.find(b.options, option) then
		return false
	end
	b.votes[voter] = option
	return true
end

function Vote.counts(b: Ballot): { [string]: number }
	local c: { [string]: number } = {}
	for _, o in ipairs(b.options) do
		c[o] = 0
	end
	for _, o in pairs(b.votes) do
		c[o] = (c[o] or 0) + 1
	end
	return c
end

function Vote.winner(b: Ballot): (string, number)
	local c = Vote.counts(b)
	local best, n = b.options[1], -1
	for _, o in ipairs(b.options) do
		if c[o] > n then
			best, n = o, c[o]
		end
	end
	return best, n
end

return Vote

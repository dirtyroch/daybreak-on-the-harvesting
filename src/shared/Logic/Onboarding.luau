--!strict
--[[
	Onboarding.luau: the first five minutes. Rusty walks a new contender through five small
	steps in their first matches, one at a time, each with a one-line tip and a small Renown
	reward. Nothing blocks play: the steps complete from things you'd do anyway, and the
	checklist hides itself once done or after 5 matches.

	v6: the checklist is skippable. A Skip button asks once (calm copy, no pressure words) and
	the choice is saved. Skipping keeps your progress; reopen it from Settings any time and you
	can still finish it for the reward. Finishing all five gives the step Renown (120 in total)
	plus Rusty's Pick, a nametag title only checklist finishers get (cosmetic only).

	It also softens the first matches against Stand-In bots (only bots, never real players):
	their damage to a contender in their first 3 matches is scaled down.
]]
local Onboarding = {}

export type Step = { id: string, event: string, title: string, tip: string, xp: number }
Onboarding.STEPS = {
	{ id = "crate", event = "crate", title = "Open a crate", tip = "Crates glow at the Sundial and all over the map. Walk up and hold E.", xp = 20 },
	{ id = "weapon", event = "weapon", title = "Pick up a weapon", tip = "Bows reach far, spears hit hard, knives are quick. Grab one.", xp = 20 },
	{ id = "eat", event = "eat", title = "Eat or drink something", tip = "Food and Water keep your stamina up. Press the item's number.", xp = 20 },
	{ id = "veil", event = "veil", title = "Stay ahead of the Veil", tip = "Watch the ring on your map. Be inside before it shrinks.", xp = 30 },
	{ id = "gallery", event = "gallery", title = "Help from the Gallery", tip = "Out already? Send a gift or vote on the next hazard. It counts.", xp = 30 },
} :: { Step }
Onboarding.HIDE_AFTER_MATCHES = 5
Onboarding.SOFT_MATCHES = 3
Onboarding.SOFT_BOT_DAMAGE = 0.6

-- What finishing all five steps gives (stated plainly on the checklist).
Onboarding.REWARD = { id = "title_rustys_pick", name = "Rusty's Pick", kind = "nametag title" }
Onboarding.COPY = {
	reward = "Finish all 5: %d Renown + the Rusty's Pick title, only for finishers.",
	skipAsk = "Skip Rusty's checklist? You'll miss the finish reward, the Rusty's Pick title. Your progress is kept, and you can reopen the checklist in Settings any time.",
	skipYes = "Skip it",
	skipNo = "Keep it",
	skipped = "Checklist hidden. Reopen it any time in Settings to finish it for Rusty's Pick.",
	reopened = "Rusty's checklist is back. Finish it for the Rusty's Pick title.",
	done = "Checklist done! Title unlocked: Rusty's Pick.",
}

export type State = { done: { [string]: boolean }, finished: boolean, skipped: boolean?, reopened: boolean?, rewarded: boolean? }

function Onboarding.new(): State
	return { done = {}, finished = false, skipped = false, reopened = false, rewarded = false }
end

function Onboarding.totalXp(): number
	local n = 0
	for _, st in ipairs(Onboarding.STEPS) do
		n += st.xp
	end
	return n
end

-- Is the checklist running (shown and counting steps)? Skipped hides it; after 5 matches it
-- hides itself unless the player reopened it from Settings.
function Onboarding.active(s: State, matchesPlayed: number): boolean
	if s.finished or s.skipped then
		return false
	end
	return s.reopened == true or matchesPlayed < Onboarding.HIDE_AFTER_MATCHES
end

-- Can Settings offer "Reopen Rusty's checklist"? (not finished and not showing right now)
function Onboarding.canReopen(s: State, matchesPlayed: number): boolean
	return not s.finished and not Onboarding.active(s, matchesPlayed)
end

function Onboarding.skip(s: State): boolean
	if s.finished or s.skipped then
		return false
	end
	s.skipped = true
	return true
end

function Onboarding.reopen(s: State, matchesPlayed: number): boolean
	if not Onboarding.canReopen(s, matchesPlayed) then
		return false
	end
	s.skipped = false
	s.reopened = true
	return true
end

-- Once, when the checklist is finished: true means grant Onboarding.REWARD now.
function Onboarding.claimReward(s: State): boolean
	if s.finished and not s.rewarded then
		s.rewarded = true
		return true
	end
	return false
end

-- The step to show now (the first not done), or nil when finished / hidden.
function Onboarding.current(s: State, matchesPlayed: number): Step?
	if not Onboarding.active(s, matchesPlayed) then
		return nil
	end
	for _, st in ipairs(Onboarding.STEPS) do
		if not s.done[st.id] then
			return st
		end
	end
	return nil
end

-- Record an event. Any matching step completes (not only the current one, so nothing a new
-- player does is wasted). Returns the steps completed by this event.
function Onboarding.mark(s: State, event: string): { Step }
	local out = {}
	if s.finished or s.skipped then
		return out
	end
	for _, st in ipairs(Onboarding.STEPS) do
		if st.event == event and not s.done[st.id] then
			s.done[st.id] = true
			table.insert(out, st)
		end
	end
	local all = true
	for _, st in ipairs(Onboarding.STEPS) do
		if not s.done[st.id] then
			all = false
		end
	end
	s.finished = all
	return out
end

function Onboarding.progress(s: State): (number, number)
	local n = 0
	for _, st in ipairs(Onboarding.STEPS) do
		if s.done[st.id] then
			n += 1
		end
	end
	return n, #Onboarding.STEPS
end

-- Bot damage multiplier against a contender who has played `matchesPlayed` matches.
function Onboarding.botDamageMult(matchesPlayed: number): number
	return if matchesPlayed < Onboarding.SOFT_MATCHES then Onboarding.SOFT_BOT_DAMAGE else 1
end

return Onboarding

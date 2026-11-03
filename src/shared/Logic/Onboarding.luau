--!strict
--[[
	Onboarding.luau: the first five minutes. Rusty walks a new contender through five small
	steps in their first matches, one at a time, each with a one-line tip and a small Renown
	reward. Nothing blocks play: the steps complete from things you'd do anyway, and the
	checklist hides itself once done or after 5 matches.

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

export type State = { done: { [string]: boolean }, finished: boolean }

function Onboarding.new(): State
	return { done = {}, finished = false }
end

-- The step to show now (the first not done), or nil when finished / hidden.
function Onboarding.current(s: State, matchesPlayed: number): Step?
	if s.finished or matchesPlayed >= Onboarding.HIDE_AFTER_MATCHES then
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
	if s.finished then
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

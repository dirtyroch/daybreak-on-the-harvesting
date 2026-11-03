--!strict
--[[
	The Season Track: 30 tiers per season, earned by playing (Daybreak Stars).
	  * Free lane: every player gets every free reward by playing. Nothing random.
	  * Premium lane (optional game pass): extra cosmetics on the same tiers. It never
	    sells power, sells only Tier Skips (cosmetic rewards), and never expires mid-season.
	  * Every reward is shown before you earn it.
]]
local SeasonTrack = {}

export type Reward = { kind: string, id: string, name: string, amount: number? }
export type Tier = { free: Reward, premium: Reward }

SeasonTrack.SEASON = 1
SeasonTrack.SEASON_NAME = "Season 1: First Light"
SeasonTrack.TIERS = 30

local FREE_COSMETICS = {
	"Reach Pin", "Dawn Scarf", "Lantern Trail", "Wheat Crown", "Slate Cloak",
	"Copper Bracer", "Glow Arrows", "Meadow Charm", "Gallery Wave", "Sundial Frame",
}
local PREMIUM_COSMETICS = {
	"Gilded Sash", "Ember Cloak", "Daybreak Halo", "Candyfinch Pet", "Veil Shimmer Fade",
	"Spire Parade Coat", "Mirror Bow Skin", "Ashen Spear Skin", "Marigold Banner", "Sunrise Wings",
	"Regent Gold Fade", "Whisperwood Hood", "Star Lantern Pack", "Champion Plume", "Legend Aura",
}

local function id(s: string): string
	return (s:lower():gsub("%s+", "_"))
end

local tiers: { Tier } = {}
for t = 1, SeasonTrack.TIERS do
	local free: Reward
	if t % 3 == 0 then
		local name = FREE_COSMETICS[t // 3]
		free = { kind = "cosmetic", id = id(name), name = name }
	elseif t % 3 == 1 then
		free = { kind = "renown", id = "renown", name = "+150 Renown", amount = 150 }
	else
		free = { kind = "emote", id = "emote_" .. t, name = "Emote: " .. ({ "Bow", "Salute", "Wave", "Cheer", "Shrug", "Dance", "Twirl", "Clap", "Point", "Flex" })[(t // 3) % 10 + 1] }
	end
	local pname = PREMIUM_COSMETICS[math.min(#PREMIUM_COSMETICS, (t + 1) // 2)]
	local premium: Reward = { kind = "cosmetic", id = id(pname) .. "_" .. t, name = pname }
	tiers[t] = { free = free, premium = premium }
end
SeasonTrack.tiers = tiers

export type State = { season: number, stars: number, claimedFree: { [string]: boolean }, claimedPremium: { [string]: boolean } }

function SeasonTrack.new(season: number): State
	return { season = season, stars = 0, claimedFree = {}, claimedPremium = {} }
end

-- If a new season started, reset the track (owned cosmetics stay forever).
function SeasonTrack.ensure(s: State, season: number): boolean
	if s.season ~= season then
		s.season = season
		s.stars = 0
		s.claimedFree = {}
		s.claimedPremium = {}
		return true
	end
	return false
end

function SeasonTrack.tierFor(stars: number, perTier: number): number
	return math.clamp(stars // perTier, 0, SeasonTrack.TIERS)
end

function SeasonTrack.addStars(s: State, n: number, perTier: number): number
	local before = SeasonTrack.tierFor(s.stars, perTier)
	s.stars += math.max(0, math.floor(n))
	return SeasonTrack.tierFor(s.stars, perTier) - before
end

-- Claim one tier's reward. lane = "free" or "premium". Returns the reward or nil + reason.
function SeasonTrack.claim(s: State, tier: number, lane: string, hasPremium: boolean, perTier: number): (Reward?, string?)
	if tier < 1 or tier > SeasonTrack.TIERS then
		return nil, "No such tier."
	end
	if SeasonTrack.tierFor(s.stars, perTier) < tier then
		return nil, "Keep playing to reach this tier."
	end
	local key = tostring(tier)
	if lane == "free" then
		if s.claimedFree[key] then
			return nil, "Already claimed."
		end
		s.claimedFree[key] = true
		return tiers[tier].free, nil
	elseif lane == "premium" then
		if not hasPremium then
			return nil, "Premium lane is optional and not owned."
		end
		if s.claimedPremium[key] then
			return nil, "Already claimed."
		end
		s.claimedPremium[key] = true
		return tiers[tier].premium, nil
	end
	return nil, "Unknown lane."
end

-- Number of reached tiers whose rewards are waiting to be claimed.
function SeasonTrack.unclaimed(s: State, hasPremium: boolean, perTier: number): number
	local n = 0
	for t = 1, SeasonTrack.tierFor(s.stars, perTier) do
		if not s.claimedFree[tostring(t)] then
			n += 1
		end
		if hasPremium and not s.claimedPremium[tostring(t)] then
			n += 1
		end
	end
	return n
end

return SeasonTrack

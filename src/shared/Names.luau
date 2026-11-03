--!strict
--[[
	Names.luau — THE NAME-SWAP KIT.

	Every player-facing proper noun in the game comes from this one module: the title, the
	nation, the regions, the hub, the force field, every NPC, the currencies and the badge
	names. To rename the game (for example after a trademark complaint), change the strings
	here, rebuild, and republish. No other file needs to change. The tests check that no other
	source file hard-codes the title.

	Rules for anything you put here (see README "IP guardrails"):
	  * No book or film names, places, characters, symbols or quotes from any franchise.
	  * Keep the game's own world: Halcyon, the Spire, the Reaches, the Sundial, the Veil.
]]
local Names = {}

Names.TITLE = "Daybreak on the Harvesting"
Names.SHORT_TITLE = "Daybreak"
Names.TAGLINE = "48 contenders. 24 Reaches. One champion at daybreak."

-- World
Names.NATION = "Halcyon"
Names.CAPITAL = "the Spire"
Names.REGION = "Reach"
Names.REGIONS = "Reaches"
Names.EVENT = "the Jubilee Trials"
Names.EVENT_SHORT = "Jubilee"
Names.DRAW = "the Harvesting"
Names.CONTENDER = "Contender"
Names.CONTENDERS = "Contenders"
Names.CHAMPION = "Champion"
Names.HUB = "the Sundial"
Names.VEIL = "the Veil"
Names.GALLERY = "the Viewing Gallery"
Names.SHOWRUNNERS = "the Showrunners"

-- People (all original characters)
Names.MENTOR = "Rusty Dunmore"
Names.MENTOR_SHORT = "Rusty"
Names.HERALD = "Herald Marigold Vane"
Names.HOST = "Monty Gleam"
Names.PUP = "Bubbles"
Names.BOT_TAG = "Stand-In"

-- Currencies and progression
Names.XP = "Renown"
Names.FAVOR = "Favor"
Names.STARS = "Daybreak Stars"
Names.TRACK = "Season Track"
Names.TOKENS = "Jubilee Tokens"

-- Hazards and places in the arena
Names.FINCHES = "Candyfinches"
Names.MEADOW = "the Gilded Meadow"
Names.BLOOM = "Meadow Bloom"
Names.LAKE = "Mirror Lake"
Names.WOOD = "Whisperwood"
Names.RIDGE = "Ashen Ridge"
Names.RUINS = "Old Glassford"

-- The 24 Reaches. Each sends two contenders in a Jubilee year (24 x 2 = 48).
Names.REACH_LIST = {
	"Cinderhollow", "Saltmere", "Timberwick", "Glassford", "Orchard Vale", "Loomstead",
	"Ironbend", "Windmere", "Quarrytop", "Reedmarsh", "Copperfield", "Hearthstone",
	"Millbrook", "Lanternfall", "Stonecross", "Wheatlow", "Brinecliff", "Ashgrove",
	"Kilnside", "Tidewater", "Foxhollow", "Silverrun", "Thistledown", "Bellhaven",
} :: { string }

-- Prestige ranks (index 0 = no prestige yet)
Names.RANKS = { [0] = "Reaped", [1] = "Contender", [2] = "Favorite", [3] = "Champion", [4] = "Legend" } :: { [number]: string }

function Names.rank(prestige: number): string
	local p = math.clamp(math.floor(prestige), 0, 4)
	return Names.RANKS[p]
end

function Names.reachIndex(name: string): number?
	for i, n in ipairs(Names.REACH_LIST) do
		if n == name then
			return i
		end
	end
	return nil
end

return Names

--!strict
-- Game content tables: tokens, hazard cards, interview quips, Stand-In names, cosmetics.
-- Player-facing proper nouns come from Names.luau.
local Content = {}

-- 24 collectible Jubilee Tokens. Each match hides Config.TOKENS_PER_MATCH of them in the arena.
Content.TOKENS = {
	{ id = "t_sundial", name = "Sundial Token", zone = "hub" },
	{ id = "t_gnomon", name = "Gnomon Shard", zone = "hub" },
	{ id = "t_bloom", name = "Bloom Token", zone = "meadow" },
	{ id = "t_pollen", name = "Pollen Coin", zone = "meadow" },
	{ id = "t_petal", name = "Gilded Petal", zone = "meadow" },
	{ id = "t_finch", name = "Finch Feather", zone = "meadow" },
	{ id = "t_mirror", name = "Mirror Pebble", zone = "lake" },
	{ id = "t_reed", name = "Reed Whistle", zone = "lake" },
	{ id = "t_shell", name = "Lake Shell", zone = "lake" },
	{ id = "t_ripple", name = "Ripple Glass", zone = "lake" },
	{ id = "t_acorn", name = "Whisper Acorn", zone = "wood" },
	{ id = "t_owl", name = "Owl Button", zone = "wood" },
	{ id = "t_moss", name = "Moss Locket", zone = "wood" },
	{ id = "t_lantern", name = "Lost Lantern", zone = "wood" },
	{ id = "t_ash", name = "Ash Stone", zone = "ridge" },
	{ id = "t_ember", name = "Ember Chip", zone = "ridge" },
	{ id = "t_cairn", name = "Cairn Marker", zone = "ridge" },
	{ id = "t_echo", name = "Echo Horn", zone = "ridge" },
	{ id = "t_pane", name = "Glassford Pane", zone = "ruins" },
	{ id = "t_key", name = "Greenhouse Key", zone = "ruins" },
	{ id = "t_seed", name = "Old Seed Packet", zone = "ruins" },
	{ id = "t_bell", name = "Ruin Bell", zone = "ruins" },
	{ id = "t_thermos", name = "Rusty's Old Thermos Lid", zone = "field" },
	{ id = "t_ribbon", name = "Parade Ribbon", zone = "field" },
} :: { { id: string, name: string, zone: string } }

-- Gallery hazard vote cards. One card is always friendly so voting isn't only about hurting.
Content.HAZARD_CARDS = {
	{ id = "finches", name = "Candyfinch Flock", text = "A sugary flock chases the biggest group." },
	{ id = "bloom", name = "Meadow Bloom", text = "Gilded pollen fills the meadow for 25 s." },
	{ id = "supply", name = "Supply Drop", text = "Three parachute crates land near the Sundial." },
} :: { { id: string, name: string, text: string } }

-- Interview quips (preset, no free text = no moderation risk). Players pick one in the lobby.
Content.QUIPS = {
	"I'm here to make my Reach proud.",
	"I packed snacks. Lots of snacks.",
	"Rusty says keep your head down. I say keep it up!",
	"I'm faster than I look.",
	"See you at the Sundial.",
	"I just want to see the sunrise.",
} :: { string }

-- Rusty's lines. Short, warm, a bit rough around the edges. Never mean.
Content.RUSTY = {
	reaping = "Easy, kid. Breathe. I've done this walk before.",
	launch = "Don't run for the gold first. Run for the trees.",
	gift = "Thought you looked thirsty. Sweet tea, my recipe.",
	win = "Ha! Told the whole Spire you'd make it.",
	lose = "Good run. Shake it off. We go again.",
} :: { [string]: string }

-- Stand-In bot first names (generic, original).
Content.BOT_NAMES = {
	"Ash", "Briar", "Cove", "Dell", "Ember", "Fern", "Gale", "Hollis", "Ivy", "Jory", "Kit", "Lark",
	"Moss", "Nell", "Oren", "Pip", "Quill", "Rook", "Sage", "Tamsin", "Umber", "Vale", "Wren", "Yarrow",
	"Zinnia", "Bram", "Clove", "Dune", "Esk", "Flint", "Hazel", "Juniper", "Linnet", "Marlow", "Nico", "Orla",
	"Perrin", "Reed", "Sorrel", "Thistle", "Ulla", "Vesper", "Willow", "Alder", "Birch", "Cedar", "Rowan", "Tansy",
} :: { string }

-- Cosmetic knockout fades (how a knocked-out contender dissolves into light).
Content.FADES = {
	fade_gold = { name = "Gold Light", color = "#FFD36B" },
	fade_ember = { name = "Ember Light", color = "#FF8A4C" },
	fade_veil = { name = "Veil Shimmer", color = "#7FF3FF" },
	fade_bloom = { name = "Bloom Petals", color = "#FF4FB8" },
} :: { [string]: { name: string, color: string } }

return Content

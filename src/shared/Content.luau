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

-- Interview questions from the host. Answers are the preset QUIPS above: no free text.
Content.QUESTIONS = {
	"So! What's the plan out there?",
	"Your Reach is watching. Anything to say to them?",
	"Who should the other contenders be worried about?",
	"Be honest: are you nervous?",
	"What's in the backpack, hm?",
	"One word for the crowd. Well, one sentence.",
} :: { string }

-- Sponsor letter patrons, in the order you can win them over. `need` is a lifetime stat.
-- "home" always writes, so every player gets a daily letter from day one.
Content.PATRONS = {
	{ id = "home", name = "Your home Reach", stat = "matches", need = 0, renown = 40, favor = 6 },
	{ id = "lamplighters", name = "The Lamplighters' Guild", stat = "top10", need = 1, renown = 25, favor = 4 },
	{ id = "bakers", name = "Orchard Row Bakers", stat = "matches", need = 10, renown = 25, favor = 4 },
	{ id = "rangers", name = "Ridge Rangers Club", stat = "knocks", need = 10, renown = 25, favor = 4 },
	{ id = "choir", name = "The Meadowlark Choir", stat = "top5", need = 3, renown = 30, favor = 5 },
	{ id = "kettle", name = "The Gilded Kettle", stat = "wins", need = 1, renown = 40, favor = 6 },
	{ id = "glassford", name = "Glassford Lens Works", stat = "encores", need = 1, renown = 30, favor = 5 },
	{ id = "spire", name = "A Spire Admirer", stat = "wins", need = 5, renown = 60, favor = 8 },
} :: { { id: string, name: string, stat: string, need: number, renown: number, favor: number } }

-- Cosmetics that arrive in sponsor letters, in order (every 5th letter).
Content.LETTER_COSMETICS = { "fade_dawn", "title_patron", "fade_lantern", "title_darling" } :: { string }
Content.TITLES = {
	title_patron = "Patron's Pick",
	title_darling = "Darling of the Spire",
	title_veilbreaker = "Veil Breaker",
	title_turncoat = "Pact Snapper",
} :: { [string]: string }

-- Rusty's lines. Short, warm, a bit rough around the edges. Never mean.
Content.RUSTY = {
	reaping = "Easy, kid. Breathe. I've done this walk before.",
	launch = "Don't run for the gold first. Run for the trees.",
	gift = "Thought you looked thirsty. Sweet tea, my recipe.",
	win = "Ha! Told the whole Spire you'd make it.",
	lose = "Good run. Shake it off. We go again.",
	pact = "A pact's a promise. Promises are heavy. Pick who you carry.",
	snapped = "That stung, didn't it? Now you know who they are.",
	training = "Not bad. Not bad at all.",
	-- v5
	onboardDone = "That's the basics, kid. Everything else you learn by doing. Go on.",
	welcomeBack = "There you are! Kept your seat warm. Here's a little Favor to get you going.",
	archive = "Archive Reel tonight. That's me, twenty-five years back, borrowed coat and all. Outlast the young fool.",
	quick = "Quick Trials. No parade, no speeches. Straight to the plates.",
	party = "Brought the whole family, did you? Good. Stick together till the final four.",
	festival = "Founders' Dawn! Lanterns up. First sunrise after the Long Dark, and we still celebrate it.",
} :: { [string]: string }

-- Rusty packs (Item Shop): extra voice lines that replace the defaults when equipped.
-- Text lines now; `sound` slots in Store.luau take recorded voice IDs later.
Content.RUSTY_PACKS = {
	rusty_s2_farmer = {
		win = "Good harvest, kid. You planted early and you picked clean.",
		lose = "Frost gets the best fields some years. We sow again tomorrow.",
		launch = "Mind the rows and keep your back to the sun. Off you go.",
	},
	rusty_thermos = {
		win = "*clink* To you, champ. Thermos is full and so am I. Proud, I mean.",
		lose = "Have a sip. Warm tea fixes most things. The rest we fix next match.",
		launch = "Thermos is warm, kid. Come back and I'll pour you one.",
	},
	rusty_stories = {
		win = "Reminds me of my own Trial. Except I won ugly. You won pretty.",
		lose = "Back in my year I got tapped in the first minute. Stood up. Went again.",
		launch = "My first Trial, I hid in a tree for an hour. Do better than me. Just a bit.",
	},
	rusty_coach = {
		win = "Textbook! High ground, patience, one clean shot. Again!",
		lose = "Tip: drink before you're thirsty, move before the Veil makes you.",
		launch = "Coach says: trees first, crates second, heroics last.",
	},
	rusty_gala = {
		win = "Ladies, gentlemen and Gallery! Your champion, dressed for the occasion!",
		lose = "A fine performance. The Gala saves you a seat for the next one.",
		launch = "Welcome to the Gala, darling. Mind the Veil, it ruins a good coat.",
	},
} :: { [string]: { [string]: string } }

-- Rusty's voice. Each pack has a `sound` slot for a recorded voice line (0 until you upload
-- one; PUBLISHING.md 6g) and a built-in "babble" made from a stock Roblox client sound played
-- in short pitched beeps, like a talking animal in a cartoon, so every line has a voice today.
-- `pitch` and `pace` make each pack sound different.
Content.RUSTY_BABBLE = "rbxasset://sounds/electronicpingshort.wav"
Content.RUSTY_VOICE = {
	default = { sound = 0, pitch = 0.8, pace = 0.09 },
	rusty_thermos = { sound = 0, pitch = 0.7, pace = 0.11 },
	rusty_stories = { sound = 0, pitch = 0.65, pace = 0.13 },
	rusty_coach = { sound = 0, pitch = 0.95, pace = 0.07 },
	rusty_gala = { sound = 0, pitch = 1.05, pace = 0.08 },
} :: { [string]: { sound: number, pitch: number, pace: number } }

function Content.rustyVoice(pack: string?): { sound: number, pitch: number, pace: number }
	return (pack and Content.RUSTY_VOICE[pack]) or Content.RUSTY_VOICE.default
end

-- Babble beeps for a line: one per word, max 12, pitch wobbling by word length (deterministic).
function Content.babble(line: string, pack: string?): { { t: number, pitch: number } }
	local v = Content.rustyVoice(pack)
	local out = {}
	local i = 0
	for word in line:gmatch("%a+") do
		if i >= 12 then
			break
		end
		local wobble = ((#word * 7) % 5 - 2) * 0.04
		table.insert(out, { t = i * v.pace * 1.6, pitch = v.pitch + wobble })
		i += 1
	end
	return out
end

function Content.rustyLine(pack: string?, key: string): string
	local p = pack and Content.RUSTY_PACKS[pack]
	return (p and p[key]) or Content.RUSTY[key]
end

-- Stand-In bot first names (generic, original).
Content.BOT_NAMES = {
	"Ash", "Briar", "Cove", "Dell", "Ember", "Fern", "Gale", "Hollis", "Ivy", "Jory", "Kit", "Lark",
	"Moss", "Nell", "Oren", "Pip", "Quill", "Rook", "Sage", "Tamsin", "Umber", "Vale", "Wren", "Yarrow",
	"Zinnia", "Bram", "Clove", "Dune", "Esk", "Flint", "Hazel", "Juniper", "Linnet", "Marlow", "Nico", "Orla",
	"Perrin", "Reed", "Sorrel", "Thistle", "Ulla", "Vesper", "Willow", "Alder", "Birch", "Cedar", "Rowan", "Tansy",
} :: { string }

-- Cosmetic knockout fades (how a knocked-out contender dissolves into light).
-- Fades: how a knocked-out contender leaves the field. The KNOCKER's equipped fade plays, so
-- every knockout shows off the fade to the whole lobby. `style` picks the animated finisher in
-- MatchService.dissolve: column (rising light), embers, shimmer, petals, lanterns, ash, ribbons,
-- stars, comet, burst.
Content.FADES = {
	fade_gold = { name = "Gold Light", color = "#FFD36B", style = "column" },
	fade_ember = { name = "Ember Light", color = "#FF8A4C", style = "embers" },
	fade_veil = { name = "Veil Shimmer", color = "#7FF3FF", style = "shimmer" },
	fade_bloom = { name = "Bloom Petals", color = "#FF4FB8", style = "petals" },
	fade_dawn = { name = "Patron's Dawn", color = "#FFB38A", style = "burst" },
	fade_lantern = { name = "Lantern Glow", color = "#FFE9A8", style = "lanterns" },
	fade_ash = { name = "Ash and Embers", color = "#D8C3A5", style = "ash" },
	fade_aurora = { name = "Aurora Fade", color = "#7DFFB2", style = "ribbons" },
	fade_starfall = { name = "Starfall Fade", color = "#FFF1B8", style = "stars" },
	fade_comet = { name = "Comet Tail", color = "#9DB4FF", style = "comet" },
	fade_petals = { name = "Petal Storm", color = "#FF9EC7", style = "petals" },
	fade_sunburst = { name = "Sunburst", color = "#FFB347", style = "burst" },
	fade_s2_windmill = { name = "Windmill Sails", color = "#E8D9B5", style = "ribbons" },
	fade_s2_fireflies = { name = "Firefly Field", color = "#D7F27A", style = "stars" },
	fade_archive_reel = { name = "Archive Reel", color = "#C9A97A", style = "ash" },
} :: { [string]: { name: string, color: string, style: string } }

Content.FADE_STYLES = { "column", "embers", "shimmer", "petals", "lanterns", "ash", "ribbons", "stars", "comet", "burst" }

return Content

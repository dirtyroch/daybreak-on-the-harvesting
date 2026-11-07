--!strict
--[[
	Sound cues for Daybreak.

	Two layers, on purpose:

	  * Playable now. `engine` is a Roblox engine sound (`rbxasset://sounds/...`, the same
	    short effects the client ships for buttons, hits and footsteps — not music). `libraryId`
	    is one of the twelve Roblox-library ids this project already used. No new marketplace
	    ids are added here.
	  * Original samples. `sample` is a file under `audio/samples/`, synthesized for this game
	    (see `scripts/synth-audio.py`). `uploadId` stays 0 until you upload that file and paste
	    the new id. Playback then prefers the upload. Until then the cue is a stand-in, not the
	    original recording.

	A cue with neither an engine path nor a library id is a placeholder: it stays silent in
	Studio until the sample is uploaded. Those are the looping beds (`ambientArena`,
	`ambientLobby`). Everything else is marked playable.

	Volumes are cue-level. The buses in Settings scale them again. Nothing here is a song.
]]

export type Cue = {
	bus: string,
	volume: number,
	pitch: number,
	minGap: number,
	spatial: boolean,
	rollMin: number,
	rollMax: number,
	stop: number,
	loop: boolean,
	uploadId: number,
	engine: string,
	libraryId: number,
	sample: string,
	note: string,
}

local function c(
	bus: string,
	volume: number,
	pitch: number,
	minGap: number,
	spatial: boolean,
	rollMin: number,
	rollMax: number,
	stop: number,
	loop: boolean,
	engine: string,
	libraryId: number,
	sample: string,
	note: string
): Cue
	return {
		bus = bus,
		volume = volume,
		pitch = pitch,
		minGap = minGap,
		spatial = spatial,
		rollMin = rollMin,
		rollMax = rollMax,
		stop = stop,
		loop = loop,
		uploadId = 0,
		engine = engine,
		libraryId = libraryId,
		sample = sample,
		note = note,
	}
end

local S = true
local F = false

-- Library ids already shipped in this project (Roblox library / Pro Sound Effects). Do not add more.
-- 15675059323 click, 15675055424 pop, 9117841338 popAiry, 9113728756 register,
-- 9113849492 coins, 9126073001 ding, 9113584163 bell, 9114898444 fanfare,
-- 9113959343 crunch, 9120907511 swat, 9125594711 whoosh, 9119165436 hiss.

local cues: { [string]: Cue } = {
	-- Weapons. Each one uses a different engine file so a bow, spear, knife and shove read apart.
	bowDraw = c("weapons", 0.28, 1.12, 0.16, F, 8, 70, 0.32, F, "rbxasset://sounds/unsheath.mp3", 0, "bow-draw.wav", "String tension before a shot"),
	bowRelease = c("weapons", 0.4, 1.04, 0.12, S, 8, 78, 0.28, F, "rbxasset://sounds/Rubber band sling shot.mp3", 0, "bow-release.wav", "Bow string"),
	spearSwing = c("weapons", 0.38, 0.9, 0.12, S, 8, 64, 0.32, F, "rbxasset://sounds/swordlunge.mp3", 0, "spear-swing.wav", "Spear swing"),
	spearThrow = c("weapons", 0.36, 0.86, 0.16, S, 8, 90, 0.3, F, "rbxasset://sounds/swoosh.mp3", 0, "spear-throw.wav", "Thrown spear"),
	knifeSwing = c("weapons", 0.34, 1.22, 0.1, S, 6, 48, 0.22, F, "rbxasset://sounds/swordslash.mp3", 0, "knife-swing.wav", "Knife swing"),
	shove = c("weapons", 0.3, 1.05, 0.16, S, 6, 40, 0.28, F, "rbxasset://sounds/impact_bodyfall.mp3", 0, "shove.wav", "Shove"),
	equip = c("weapons", 0.26, 0.96, 0.18, F, 6, 40, 0.28, F, "rbxasset://sounds/unsheath.mp3", 0, "equip.wav", "Weapon into the hand"),

	-- Hits and knockouts. The shared bell is the count drop; the attacker also gets a short confirm.
	hitLight = c("hits", 0.4, 1.16, 0.08, F, 8, 55, 0.18, F, "rbxasset://sounds/hit.mp3", 0, "hit-light.wav", "Hit confirm"),
	hitHeavy = c("hits", 0.22, 0.9, 0.12, S, 8, 60, 0.24, F, "rbxasset://sounds/bass.mp3", 0, "hit-heavy.wav", "Heavier hit"),
	hurt = c("hits", 0.26, 1.0, 0.22, F, 8, 40, 0.18, F, "rbxasset://sounds/hit.mp3", 0, "hurt.wav", "You were hit"),
	knockout = c("hits", 0.4, 0.92, 0.4, F, 12, 120, 1.5, F, "", 9113584163, "knockout.wav", "One soft bell when someone is tapped out"),
	knockConfirm = c("hits", 0.28, 1.05, 0.2, F, 8, 40, 0.16, F, "rbxasset://sounds/snap.mp3", 0, "knock-confirm.wav", "Your own knockout confirm"),

	-- Footsteps, one family per surface. Quiet, short, and rate-limited in Audio.footInterval.
	footGrass = c("footsteps", 0.28, 1.0, 0.28, S, 4, 32, 0.12, F, "rbxasset://sounds/grass.mp3", 0, "foot-grass.wav", "Grass"),
	footDirt = c("footsteps", 0.26, 0.92, 0.28, S, 4, 32, 0.12, F, "rbxasset://sounds/grassstone.mp3", 0, "foot-dirt.wav", "Dirt and mud"),
	footStone = c("footsteps", 0.3, 1.0, 0.28, S, 4, 36, 0.1, F, "rbxasset://sounds/stone.mp3", 0, "foot-stone.wav", "Stone"),
	footWood = c("footsteps", 0.28, 1.0, 0.28, S, 4, 34, 0.12, F, "rbxasset://sounds/wood.mp3", 0, "foot-wood.wav", "Wood"),
	footMetal = c("footsteps", 0.22, 1.05, 0.28, S, 4, 40, 0.1, F, "rbxasset://sounds/metal.mp3", 0, "foot-metal.wav", "Metal"),
	footWater = c("footsteps", 0.2, 1.0, 0.34, S, 4, 28, 0.22, F, "rbxasset://sounds/impact_water.mp3", 0, "foot-water.wav", "Water"),
	footGlass = c("footsteps", 0.18, 1.15, 0.28, S, 4, 30, 0.1, F, "rbxasset://sounds/ice.mp3", 0, "foot-glass.wav", "Glass and ice"),
	footDefault = c("footsteps", 0.22, 1.0, 0.28, S, 4, 30, 0.12, F, "rbxasset://sounds/action_footsteps_plastic.mp3", 0, "foot-default.wav", "Other surfaces"),
	footLand = c("footsteps", 0.26, 1.0, 0.28, S, 4, 36, 0.16, F, "rbxasset://sounds/action_jump_land.mp3", 0, "foot-land.wav", "Landing"),

	-- Pickups and use.
	pickup = c("pickups", 0.34, 1.12, 0.08, F, 6, 40, 0.16, F, "rbxasset://sounds/snap.mp3", 0, "pickup.wav", "Item found"),
	crate = c("pickups", 0.24, 1.05, 0.2, S, 6, 36, 0.22, F, "rbxasset://sounds/collide.mp3", 0, "crate.wav", "Crate"),
	snack = c("pickups", 0.3, 1.0, 0.25, F, 6, 30, 0.35, F, "", 9113959343, "snack.wav", "Eat or drink"),
	token = c("pickups", 0.34, 1.0, 0.2, F, 6, 40, 0.7, F, "", 9113849492, "token.wav", "Jubilee Token"),
	parachute = c("pickups", 0.28, 1.0, 0.25, F, 8, 50, 0.55, F, "", 9117841338, "parachute.wav", "Parachute gift landing"),

	-- Interface, lobby, cutscene stingers.
	uiClick = c("ui", 0.3, 1.0, 0.04, F, 1, 1, 0.08, F, "rbxasset://sounds/button.mp3", 0, "ui-click.wav", "Buttons"),
	chime = c("ui", 0.32, 1.0, 0.12, F, 1, 1, 0.55, F, "", 9126073001, "chime.wav", "Confirm, pact offer, challenge"),
	win = c("ui", 0.3, 1.0, 0.5, F, 1, 1, 1.6, F, "", 9114898444, "win.wav", "Win stinger"),
	purchase = c("ui", 0.28, 1.0, 0.25, F, 1, 1, 0.7, F, "", 9113728756, "purchase.wav", "Purchase thanks"),
	giftSend = c("ui", 0.26, 1.12, 0.16, F, 1, 1, 0.22, F, "rbxasset://sounds/swoosh.mp3", 0, "gift.wav", "Gallery gift sent"),
	cutscene = c("ui", 0.26, 0.84, 0.3, F, 1, 1, 0.7, F, "", 9113584163, "cutscene.wav", "Draw and ceremony sting"),

	-- Sparse air, playable today. The looping beds below are upload placeholders.
	arenaAir = c("ambient", 0.1, 0.78, 10, F, 1, 1, 0.2, F, "rbxasset://sounds/grass3.mp3", 0, "arena-air.wav", "Occasional arena air, not a loop"),
	lobbyAir = c("ambient", 0.07, 0.72, 12, F, 1, 1, 0.2, F, "rbxasset://sounds/electronicpingshort.mp3", 0, "lobby-air.wav", "Occasional lobby tone"),
	ambientArena = c("ambient", 0.18, 1.0, 0, F, 1, 1, 0, S, "", 0, "ambient-arena.wav", "PLACEHOLDER loop. Silent until audio/samples/ambient-arena.wav is uploaded."),
	ambientLobby = c("ambient", 0.16, 1.0, 0, F, 1, 1, 0, S, "", 0, "ambient-lobby.wav", "PLACEHOLDER loop. Silent until audio/samples/ambient-lobby.wav is uploaded."),

	-- Veil. Touches are rate-limited so standing in the wall does not machine-gun.
	veilTouch = c("veil", 0.26, 0.9, 0.9, F, 1, 1, 0.4, F, "", 9119165436, "veil-touch.wav", "Contact with the Veil"),
	veilWarn = c("veil", 0.2, 0.62, 7, F, 1, 1, 0.35, F, "rbxasset://sounds/electronicpingshort.mp3", 0, "veil-warn.wav", "Near the wall while it closes"),
	veilSoon = c("veil", 0.16, 0.8, 8, F, 1, 1, 0.28, F, "rbxasset://sounds/switch.mp3", 0, "veil-soon.wav", "Shrink is close and you are near the edge"),
	veilCore = c("veil", 0.22, 1.25, 1.2, F, 1, 1, 0.3, F, "rbxasset://sounds/electronicpingshort.mp3", 0, "veil-core.wav", "Veil Core lights"),
	veilBreak = c("veil", 0.2, 1.15, 1.0, F, 1, 1, 0.45, F, "rbxasset://sounds/bass.mp3", 0, "veil-break.wav", "Dome calmed"),
	hazard = c("veil", 0.22, 0.78, 1.4, F, 1, 1, 0.3, F, "rbxasset://sounds/collide.mp3", 0, "hazard.wav", "Hazard called"),
	pactWarn = c("veil", 0.24, 0.55, 0.45, F, 1, 1, 0.28, F, "rbxasset://sounds/button.mp3", 0, "pact-warn.wav", "Pact snap warning"),
}

return cues

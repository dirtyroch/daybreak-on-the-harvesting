--!strict
-- Sound effects. Every id is a sound from Roblox's own licensed library (ProSoundEffects or the
-- Roblox account), so the game needs no uploaded audio. Swap a sound by changing one number.
-- `stop` cuts long files short (seconds). `volume` is relative to the SFX group.
return {
	click = { id = 15675059323, volume = 0.35 }, -- Roblox_UI_Bright_Click (buttons)
	pop = { id = 15675055424, volume = 0.5 }, -- Roblox_UI_Cute_Pop (pickups)
	popAiry = { id = 9117841338, volume = 0.5 }, -- Pop Airy 1 (parachute lands)
	register = { id = 9113728756, volume = 0.45 }, -- Cash Register 5 (purchase thanks)
	coins = { id = 9113849492, volume = 0.5 }, -- Coins Or Keys Jingle 6 (token found)
	ding = { id = 9126073001, volume = 0.45 }, -- Synth Sparkle Tone Ding (challenge done)
	bell = { id = 9113584163, volume = 0.6, stop = 2.6 }, -- Brass Hand Bell 1 (knockout / Harvesting)
	fanfare = { id = 9114898444, volume = 0.55 }, -- Kazoo Fanfare 3 (win)
	crunch = { id = 9113959343, volume = 0.7 }, -- Crack Egg Crunchy 11 (snack)
	swat = { id = 9120907511, volume = 0.6 }, -- Wood Impact 5 (melee hit)
	whoosh = { id = 9125594711, volume = 0.4 }, -- Metal Spatula Impact (bow release stand-in)
	hiss = { id = 9119165436, volume = 0.45 }, -- Sizzle Sear (Veil touch)
} :: { [string]: { id: number, volume: number?, stop: number?, loop: boolean? } }

--!strict
-- Pure audio rules: which file plays, how loud, how often, and which surface a footstep is.
-- The client (Sfx.luau) performs playback. This module never touches instances.
local Audio = {}

local SfxIds: { [string]: any }
if script then
	SfxIds = require(script.Parent.SfxIds)
else
	SfxIds = (require :: any)("./SfxIds")
end

Audio.CUES = SfxIds

-- Names older call sites still use. They point at the more specific cue.
local alias: { [string]: string } = {
	click = "uiClick",
	pop = "pickup",
	popAiry = "parachute",
	register = "purchase",
	coins = "token",
	ding = "chime",
	bell = "knockout",
	fanfare = "win",
	crunch = "snack",
	swat = "hitLight",
	whoosh = "giftSend",
	hiss = "veilTouch",
}
Audio.ALIAS = alias

-- The only numeric asset ids allowed. These twelve were already in the project.
local library: { [number]: boolean } = {
	[15675059323] = true,
	[15675055424] = true,
	[9117841338] = true,
	[9113728756] = true,
	[9113849492] = true,
	[9126073001] = true,
	[9113584163] = true,
	[9114898444] = true,
	[9113959343] = true,
	[9120907511] = true,
	[9125594711] = true,
	[9119165436] = true,
}
Audio.LIBRARY = library

-- Engine one-shots only. No soundtrack files, no character voices.
local engines: { [string]: boolean } = {
	["rbxasset://sounds/Rubber band sling shot.mp3"] = true,
	["rbxasset://sounds/unsheath.mp3"] = true,
	["rbxasset://sounds/swordlunge.mp3"] = true,
	["rbxasset://sounds/swordslash.mp3"] = true,
	["rbxasset://sounds/swoosh.mp3"] = true,
	["rbxasset://sounds/impact_bodyfall.mp3"] = true,
	["rbxasset://sounds/hit.mp3"] = true,
	["rbxasset://sounds/bass.mp3"] = true,
	["rbxasset://sounds/snap.mp3"] = true,
	["rbxasset://sounds/button.mp3"] = true,
	["rbxasset://sounds/switch.mp3"] = true,
	["rbxasset://sounds/collide.mp3"] = true,
	["rbxasset://sounds/electronicpingshort.mp3"] = true,
	["rbxasset://sounds/grass.mp3"] = true,
	["rbxasset://sounds/grass3.mp3"] = true,
	["rbxasset://sounds/grassstone.mp3"] = true,
	["rbxasset://sounds/stone.mp3"] = true,
	["rbxasset://sounds/wood.mp3"] = true,
	["rbxasset://sounds/metal.mp3"] = true,
	["rbxasset://sounds/ice.mp3"] = true,
	["rbxasset://sounds/impact_water.mp3"] = true,
	["rbxasset://sounds/action_footsteps_plastic.mp3"] = true,
	["rbxasset://sounds/action_jump_land.mp3"] = true,
}
Audio.ENGINES = engines

Audio.BUSES = { "weapons", "hits", "footsteps", "pickups", "ui", "ambient", "veil", "voice" }

local volumeKey: { [string]: string } = {
	weapons = "volWeapons",
	hits = "volHits",
	footsteps = "volFootsteps",
	pickups = "volPickups",
	ui = "volUi",
	ambient = "volAmbient",
	veil = "volVeil",
	voice = "volVoice",
}
Audio.VOLUME_KEY = volumeKey

-- Bus multipliers. Combined with cue volumes these stay under a shout.
local defaultVolume: { [string]: number } = {
	weapons = 0.7,
	hits = 0.62,
	footsteps = 0.38,
	pickups = 0.55,
	ui = 0.42,
	ambient = 0.22,
	veil = 0.36,
	voice = 0.48,
}
Audio.DEFAULT_VOLUME = defaultVolume

local surfaces: { [string]: string } = {
	grass = "footGrass",
	dirt = "footDirt",
	stone = "footStone",
	wood = "footWood",
	metal = "footMetal",
	water = "footWater",
	glass = "footGlass",
	default = "footDefault",
}
Audio.SURFACES = surfaces

local weapons: { [string]: string } = {
	bow = "bowRelease",
	spear = "spearSwing",
	spearThrow = "spearThrow",
	knife = "knifeSwing",
	shove = "shove",
}
Audio.WEAPONS = weapons

function Audio.alias(name: string): string
	return Audio.ALIAS[name] or name
end

function Audio.cue(name: string): any
	return Audio.CUES[Audio.alias(name)]
end

function Audio.clampVolume(n: number): number
	if n ~= n then
		return 0
	end
	return math.clamp(n, 0, 1)
end

-- What to actually play. Original upload wins, then the engine stand-in, then a library id.
-- "placeholder" means silence until someone pastes an uploadId.
function Audio.playback(cue: any): (string, string)
	if type(cue) ~= "table" then
		return "", "placeholder"
	end
	local uploadId = cue.uploadId
	if type(uploadId) == "number" and uploadId > 0 then
		return "rbxassetid://" .. tostring(math.floor(uploadId)), "original"
	end
	if type(cue.engine) == "string" and cue.engine ~= "" then
		return cue.engine, "engine"
	end
	local libraryId = cue.libraryId
	if type(libraryId) == "number" and libraryId > 0 then
		return "rbxassetid://" .. tostring(math.floor(libraryId)), "library"
	end
	return "", "placeholder"
end

function Audio.status(cue: any): string
	local _, kind = Audio.playback(cue)
	if kind == "placeholder" then
		return "placeholder"
	end
	return "playable"
end

function Audio.effective(masterOn: boolean, busVol: number, cueVol: number): number
	if not masterOn then
		return 0
	end
	return Audio.clampVolume(busVol) * math.clamp(cueVol, 0, 1)
end

function Audio.allow(last: number?, now: number, gap: number): boolean
	if gap <= 0 then
		return true
	end
	if last == nil then
		return true
	end
	return now - last >= gap
end

-- Spatial repeats from different people should not share one cooldown.
function Audio.gapKey(name: string, at: { x: number, y: number, z: number }?): string
	if not at then
		return name
	end
	return string.format("%s:%d:%d", name, math.floor(at.x / 12), math.floor(at.z / 12))
end

-- Drop extra footsteps and air when a lot of sounds just started. Hits and weapons stay.
function Audio.admit(started: number, bus: string): boolean
	if started < 4 then
		return true
	end
	if bus == "footsteps" or bus == "ambient" then
		return false
	end
	return started < 7
end

-- Seconds between steps. Nil when nearly still. Never faster than 0.3s.
function Audio.footInterval(speed: number): number?
	if speed < 1.5 then
		return nil
	end
	return math.clamp(7.2 / speed, 0.3, 0.62)
end

function Audio.surfaceFromMaterial(material: string): string
	local m = string.lower(material)
	if m == "water" then
		return "water"
	end
	if m == "grass" or m == "leafygrass" then
		return "grass"
	end
	if m == "mud" or m == "ground" or m == "sand" or m == "snow" or m == "salt" then
		return "dirt"
	end
	if m == "wood" or m == "woodplanks" then
		return "wood"
	end
	if m == "metal" or m == "corrodedmetal" or m == "diamondplate" or m == "foil" then
		return "metal"
	end
	if m == "glass" or m == "ice" or m == "glacier" then
		return "glass"
	end
	if m == "slate" or m == "cobblestone" or m == "concrete" or m == "rock" or m == "limestone" or m == "basalt" or m == "pavement" or m == "asphalt" or m == "brick" or m == "pebble" or m == "sandstone" or m == "granite" or m == "marble" then
		return "stone"
	end
	return "default"
end

function Audio.footCue(material: string): string
	local surface = Audio.surfaceFromMaterial(material)
	return Audio.SURFACES[surface] or Audio.SURFACES.default
end

-- outside: in the wall. margin: studs of safe ground left (negative when outside).
function Audio.veilEvent(outside: boolean, margin: number, shrinking: boolean, nextIn: number?): string?
	if outside then
		return "veilTouch"
	end
	if shrinking and margin < 90 then
		return "veilWarn"
	end
	if nextIn and nextIn > 0 and nextIn <= 10 and margin < 140 then
		return "veilSoon"
	end
	return nil
end

function Audio.weaponCue(kind: string, thrown: boolean?): string?
	if thrown or kind == "spearThrow" then
		return Audio.WEAPONS.spearThrow
	end
	return Audio.WEAPONS[kind]
end

return Audio

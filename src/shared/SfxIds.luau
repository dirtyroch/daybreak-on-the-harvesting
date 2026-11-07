--!strict
--[[
	Sound catalog.

	Each cue plays one of two sources, in this order:
	  1. uploadId  — an original file in audio/original/, after you upload it and paste the id.
	     Every uploadId ships as 0, so nothing here is fetched from the catalog.
	  2. builtin   — a verified Roblox client sound (rbxasset://). These play with no upload.
	     They are a small set, so several cues share a file and differ by pitch. The originals
	     are the distinct versions.

	retired lists the numeric catalog ids an earlier build referenced. They are NOT played.
	Permission for this experience was not verified. Do not paste them back without checking
	them in Studio (they often stay silent unless the experience is allowed to use them).

	status from AudioMix.resolve:
	  working_builtin — heard today
	  uploaded        — heard after you set uploadId
	  missing         — would be silent (should not happen for the cues below)
]]

export type Cue = {
	bus: string,
	kind: string,
	volume: number,
	minGap: number,
	pitch: number,
	stop: number?,
	loop: boolean?,
	spatial: boolean?,
	minDist: number?,
	maxDist: number?,
	builtin: string,
	uploadId: number,
	uploadFile: string,
}

local function C(bus: string, kind: string, volume: number, minGap: number, pitch: number, builtin: string, file: string, extra: any?): Cue
	local cue: Cue = {
		bus = bus,
		kind = kind,
		volume = volume,
		minGap = minGap,
		pitch = pitch,
		builtin = builtin,
		uploadId = 0,
		uploadFile = file,
	}
	if extra then
		for k, v in pairs(extra) do
			(cue :: any)[k] = v
		end
	end
	return cue
end

local PING = "rbxasset://sounds/electronicpingshort.wav"
local JUMP = "rbxasset://sounds/action_jump.mp3"
local LAND = "rbxasset://sounds/action_jump_land.mp3"
local GETUP = "rbxasset://sounds/action_get_up.mp3"
local FALL = "rbxasset://sounds/action_falling.mp3"
local STEPS = "rbxasset://sounds/action_footsteps_plastic.mp3"

local cues: { [string]: Cue } = {
	-- menus
	click = C("ui", "ui", 0.28, 0.05, 1.35, PING, "audio/original/ui.wav", { stop = 0.12 }),
	ding = C("ui", "ui", 0.3, 0.12, 1.05, PING, "audio/original/ui.wav", { stop = 0.18 }),
	register = C("ui", "ui", 0.3, 0.2, 0.9, PING, "audio/original/ui.wav", { stop = 0.22 }),
	-- pickups and tokens
	pop = C("effects", "pickup", 0.34, 0.1, 1.4, JUMP, "audio/original/pickup.wav", { stop = 0.22 }),
	coins = C("effects", "pickup", 0.32, 0.2, 1.15, PING, "audio/original/token.wav", { stop = 0.28 }),
	popAiry = C("effects", "air", 0.26, 0.3, 1.15, FALL, "audio/original/air.wav", { stop = 0.4 }),
	whoosh = C("effects", "air", 0.3, 0.12, 1.2, JUMP, "audio/original/air.wav", { stop = 0.28 }),
	-- hits and knockouts
	swat = C("effects", "hit", 0.32, 0.12, 1.35, LAND, "audio/original/hit.wav", { stop = 0.16 }),
	hurt = C("effects", "hit", 0.3, 0.25, 0.85, LAND, "audio/original/hurt.wav", { stop = 0.22 }),
	bell = C("effects", "knockout", 0.38, 0.45, 0.62, PING, "audio/original/knockout.wav", { stop = 0.42 }),
	crunch = C("effects", "snack", 0.3, 0.2, 1.05, GETUP, "audio/original/snack.wav", { stop = 0.2 }),
	fanfare = C("effects", "win", 0.36, 0.8, 0.95, PING, "audio/original/win.wav", { stop = 0.7 }),
	-- weapons (spatial). Originals differ; stand-ins are separate client files where we have them.
	weapon_bow = C("effects", "weapon", 0.4, 0.16, 1.22, JUMP, "audio/original/weapon_bow.wav", { stop = 0.3, spatial = true, minDist = 8, maxDist = 90 }),
	weapon_knife = C("effects", "weapon", 0.32, 0.14, 1.45, GETUP, "audio/original/weapon_knife.wav", { stop = 0.16, spatial = true, minDist = 6, maxDist = 50 }),
	weapon_spear = C("effects", "weapon", 0.4, 0.16, 0.72, LAND, "audio/original/weapon_spear.wav", { stop = 0.26, spatial = true, minDist = 8, maxDist = 60 }),
	weapon_shove = C("effects", "weapon", 0.3, 0.16, 1.05, LAND, "audio/original/weapon_shove.wav", { stop = 0.18, spatial = true, minDist = 6, maxDist = 40 }),
	weapon_throw = C("effects", "weapon", 0.4, 0.2, 0.8, FALL, "audio/original/weapon_throw.wav", { stop = 0.32, spatial = true, minDist = 8, maxDist = 100 }),
	-- body and world
	footstep = C("effects", "footstep", 0.26, 0.28, 1.25, STEPS, "audio/original/footstep.wav", { stop = 0.14, spatial = true, minDist = 4, maxDist = 64 }),
	interact = C("effects", "interact", 0.3, 0.12, 1.1, GETUP, "audio/original/interact.wav", { stop = 0.16, spatial = true, minDist = 6, maxDist = 48 }),
	ambience = C("ambience", "ambience", 0.34, 1, 0.85, FALL, "audio/original/ambience.wav", { loop = true }),
	-- Veil warning pulses. Same original file, different level and gap. Never a fast beep train.
	veil_far = C("ambience", "veil", 0.14, 3.2, 0.5, PING, "audio/original/veil.wav", { stop = 0.28 }),
	veil_near = C("ambience", "veil", 0.22, 1.8, 0.44, PING, "audio/original/veil.wav", { stop = 0.32 }),
	veil_out = C("ambience", "veil", 0.3, 1.15, 0.38, PING, "audio/original/veil.wav", { stop = 0.36 }),
	hiss = C("ambience", "veil", 0.26, 0.8, 0.55, PING, "audio/original/veil.wav", { stop = 0.3 }),
}

local SfxIds = {
	cues = cues,
	-- Earlier catalog ids. needs_permission: not played. See PUBLISHING.md.
	retired = {
		{ name = "click", id = 15675059323, note = "needs_permission" },
		{ name = "pop", id = 15675055424, note = "needs_permission" },
		{ name = "popAiry", id = 9117841338, note = "needs_permission" },
		{ name = "register", id = 9113728756, note = "needs_permission" },
		{ name = "coins", id = 9113849492, note = "needs_permission" },
		{ name = "ding", id = 9126073001, note = "needs_permission" },
		{ name = "bell", id = 9113584163, note = "needs_permission" },
		{ name = "fanfare", id = 9114898444, note = "needs_permission" },
		{ name = "crunch", id = 9113959343, note = "needs_permission" },
		{ name = "swat", id = 9120907511, note = "needs_permission" },
		{ name = "whoosh", id = 9125594711, note = "needs_permission" },
		{ name = "hiss", id = 9119165436, note = "needs_permission" },
	},
}

function SfxIds.get(name: string): Cue?
	return cues[name]
end

return SfxIds

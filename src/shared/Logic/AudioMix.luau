--!strict
-- Mixer rules for Daybreak's sounds. Pure: no Instances. The client applies the result.
-- Volumes are 0–100 in the save and 0–1 at playback. A cue can never be made louder than
-- its catalog volume, and a caller can only lengthen a gap, never shorten it.
local AudioMix = {}

AudioMix.BUSES = { master = true, effects = true, ambience = true, voice = true, ui = true }

-- These rbxasset:// paths ship inside the Roblox client. The character controller
-- (RbxCharacterSounds) uses the action_* / impact / uuhhh set; electronicpingshort.wav
-- is the ping this game already uses for Rusty's stand-in voice. Anything else is not
-- played until an uploaded original replaces it.
AudioMix.VERIFIED = {
	["rbxasset://sounds/action_footsteps_plastic.mp3"] = true,
	["rbxasset://sounds/action_falling.mp3"] = true,
	["rbxasset://sounds/action_get_up.mp3"] = true,
	["rbxasset://sounds/action_jump.mp3"] = true,
	["rbxasset://sounds/action_jump_land.mp3"] = true,
	["rbxasset://sounds/impact_water.mp3"] = true,
	["rbxasset://sounds/action_swim.mp3"] = true,
	["rbxasset://sounds/uuhhh.mp3"] = true,
	["rbxasset://sounds/electronicpingshort.wav"] = true,
}

AudioMix.MAX_CUE_VOLUME = 0.45
AudioMix.SPATIAL_CAP = 10
AudioMix.SPATIAL_WINDOW = 0.5
AudioMix.FOOT_MIN_GAP = 0.28

local DEFAULT_VOLUMES = { master = 80, effects = 85, ambience = 40, voice = 70, ui = 55 }

function AudioMix.gain(settings: any, bus: string): number
	if not AudioMix.BUSES[bus] then
		return 0
	end
	if type(settings) ~= "table" or settings.sfx == false then
		return 0
	end
	local volumes = settings.volumes
	if type(volumes) ~= "table" then
		volumes = DEFAULT_VOLUMES
	end
	local master = math.clamp((tonumber(volumes.master) or DEFAULT_VOLUMES.master) / 100, 0, 1)
	if bus == "master" then
		return master
	end
	local muted = settings.muted
	if type(muted) == "table" and muted[bus] == true then
		return 0
	end
	local own = math.clamp((tonumber(volumes[bus]) or 80) / 100, 0, 1)
	return master * own
end

-- uploadId > 0 plays the owner's upload. Otherwise a verified client sound. Never a catalog id.
function AudioMix.resolve(cue: any): (string, string)
	if type(cue) ~= "table" then
		return "", "missing"
	end
	local upload = tonumber(cue.uploadId)
	if upload and upload > 0 and upload == math.floor(upload) and upload < 1e15 then
		return "rbxassetid://" .. tostring(upload), "uploaded"
	end
	if type(cue.builtin) == "string" and AudioMix.VERIFIED[cue.builtin] == true then
		return cue.builtin, "working_builtin"
	end
	return "", "missing"
end

function AudioMix.gap(cue: any, requested: number?): number
	local floorGap = 0
	if type(cue) == "table" and type(cue.minGap) == "number" then
		floorGap = cue.minGap
	end
	if type(requested) == "number" and requested == requested and requested > floorGap then
		return requested
	end
	return floorGap
end

function AudioMix.speed(cue: any, requested: number?): number
	local base = 1
	if type(cue) == "table" and type(cue.pitch) == "number" then
		base = cue.pitch
	end
	local mult = 1
	if type(requested) == "number" and requested == requested then
		mult = requested
	end
	return math.clamp(base * mult, 0.55, 1.45)
end

function AudioMix.cueVolume(cue: any): number
	local v = 0.3
	if type(cue) == "table" and type(cue.volume) == "number" then
		v = cue.volume
	end
	return math.clamp(v, 0, AudioMix.MAX_CUE_VOLUME)
end

function AudioMix.gapKey(name: string, emitter: string?): string
	if emitter and emitter ~= "" then
		return name .. ":" .. emitter
	end
	return name
end

function AudioMix.inRange(distance: number, maxDist: number): boolean
	return distance >= 0 and distance <= maxDist
end

-- Non-local spatial sounds share a budget so a full field of footsteps cannot stack.
-- The local player's own sounds always pass.
function AudioMix.admit(nonLocalHeard: number, isLocal: boolean): boolean
	if isLocal then
		return true
	end
	return nonLocalHeard < AudioMix.SPATIAL_CAP
end

function AudioMix.footstepInterval(speed: number): number?
	if type(speed) ~= "number" or speed < 1.5 then
		return nil
	end
	local gap = 0.5 - math.clamp(speed, 0, 28) * 0.008
	if gap < AudioMix.FOOT_MIN_GAP then
		return AudioMix.FOOT_MIN_GAP
	end
	return gap
end

function AudioMix.footPitch(material: string): number
	if material == "Grass" or material == "LeafyGrass" then
		return 0.92
	elseif material == "Sand" or material == "Mud" or material == "Ground" then
		return 0.84
	elseif material == "Wood" or material == "WoodPlanks" then
		return 1.08
	elseif material == "Metal" or material == "DiamondPlate" or material == "CorrodedMetal" then
		return 1.18
	elseif material == "Water" then
		return 0.8
	end
	return 1
end

-- margin = veil radius minus flat distance from the arena center. Negative means outside.
-- Far from the edge: silence. Closer: a slower, quieter pulse. Outside: a steadier pulse.
-- Gaps stay above a second so the warning cannot chatter.
function AudioMix.veilCue(margin: number): string?
	if type(margin) ~= "number" then
		return nil
	end
	if margin > 80 then
		return nil
	elseif margin < 0 then
		return "veil_out"
	elseif margin < 28 then
		return "veil_near"
	end
	return "veil_far"
end

return AudioMix

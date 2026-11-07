--!strict
-- Saved settings that the server will accept. Booleans, mixer levels and field of view.
-- `view` is presentation only. MatchService does not read it.
-- This module does not require its siblings: the test runner loads each logic file on its own.
local Settings = {}

Settings.BUSES = { master = true, effects = true, ambience = true, voice = true, ui = true }

Settings.VOLUME_ROWS = {
	{ bus = "master", label = "Master volume" },
	{ bus = "effects", label = "Effects (weapons, steps, hits)" },
	{ bus = "ambience", label = "Arena and Veil" },
	{ bus = "voice", label = "Rusty voice" },
	{ bus = "ui", label = "Menu clicks" },
}

-- Mute toggles. Master silence stays on settings.sfx, which already existed.
Settings.MUTE_OF = {
	muteEffects = "effects",
	muteAmbience = "ambience",
	muteVoice = "voice",
	muteUi = "ui",
}

local BOOL_KEYS = { autoQueue = true, sfx = true, shortReaping = true, reduceMotion = true }

function Settings.applyBool(settings: any, key: any, value: any): boolean
	if type(settings) ~= "table" or type(key) ~= "string" or type(value) ~= "boolean" then
		return false
	end
	if key == "viewFirst" then
		settings.view = if value then "first" else "third"
		return true
	end
	local bus = Settings.MUTE_OF[key]
	if bus then
		if type(settings.muted) ~= "table" then
			settings.muted = {}
		end
		settings.muted[bus] = value
		return true
	end
	if not BOOL_KEYS[key] then
		return false
	end
	settings[key] = value
	return true
end

function Settings.setVolume(settings: any, bus: any, value: any): boolean
	if type(settings) ~= "table" or type(bus) ~= "string" or not Settings.BUSES[bus] then
		return false
	end
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return false
	end
	if type(settings.volumes) ~= "table" then
		settings.volumes = {}
	end
	settings.volumes[bus] = math.clamp(math.floor(value + 0.5), 0, 100)
	return true
end

function Settings.setFov(settings: any, value: any): boolean
	if type(settings) ~= "table" or type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return false
	end
	-- Same steps as Presentation.clampFov: never wider than 70.
	local fov = 70
	if value < 63 then
		fov = 60
	elseif value < 68 then
		fov = 65
	end
	settings.fov = fov
	return true
end

return Settings

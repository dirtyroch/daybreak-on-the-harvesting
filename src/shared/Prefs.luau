--!strict
-- Persisted preferences. New keys fill in on old saves through Reconcile; nothing here is wiped.
local Prefs = {}

local boolKeys: { [string]: boolean } = {
	autoQueue = true,
	sfx = true,
	shortReaping = true,
	viewFirst = true,
	reduceMotion = true,
}
Prefs.BOOL = boolKeys

local numberKeys: { [string]: boolean } = {
	volWeapons = true,
	volHits = true,
	volFootsteps = true,
	volPickups = true,
	volUi = true,
	volAmbient = true,
	volVeil = true,
	volVoice = true,
}
Prefs.NUMBER = numberKeys

function Prefs.defaultSettings(): { [string]: any }
	return {
		autoQueue = true,
		sfx = true,
		shortReaping = false,
		mode = "", -- "" = auto (Modes.preferred). Changed only by setMode.
		viewFirst = false, -- third person stays the default
		reduceMotion = false,
		volWeapons = 0.7,
		volHits = 0.62,
		volFootsteps = 0.38,
		volPickups = 0.55,
		volUi = 0.42,
		volAmbient = 0.22,
		volVeil = 0.36,
		volVoice = 0.48,
	}
end

-- Returns whether the write is allowed, and the value to store. `false` is a valid boolean.
function Prefs.sanitize(key: any, value: any): (boolean, any)
	if type(key) ~= "string" then
		return false, nil
	end
	if key == "mode" then
		return false, nil
	end
	if Prefs.BOOL[key] then
		if type(value) ~= "boolean" then
			return false, nil
		end
		return true, value
	end
	if Prefs.NUMBER[key] then
		if type(value) ~= "number" or value ~= value then
			return false, nil
		end
		return true, math.clamp(value, 0, 1)
	end
	return false, nil
end

return Prefs

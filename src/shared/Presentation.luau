--!strict
--[[
	First-person presentation, as numbers only.

	The first-person camera is a view. It does not feed hit detection. Shots use `shotAim`,
	which starts 12.5 studs behind the head (a normal third-person zoom) and runs along the
	look line through the head. `eyePosition` is only where the picture is drawn, 0.6 studs
	in front of the head on that same line, so sliding the lens forward does not invent a
	tighter ray. The client never passes the camera position into `shotAim`. The server
	still casts from the chest toward the aim point.

	Hands live on the viewmodel, in front of the lens and below the center, so the crosshair
	stays clear. Head, hair and hats are hidden locally. Field of view stays at 70, or 72
	while sprinting when reduced motion is off.
]]
local Presentation = {}

Presentation.FOV = 70
Presentation.FOV_SPRINT = 72
Presentation.FOV_MAX = 74
Presentation.AIM_ZOOM = 12.5
Presentation.AIM_REACH = 500
Presentation.EYE_FORWARD = 0.6
Presentation.PITCH_MIN = -1.396 -- about -80 degrees
Presentation.PITCH_MAX = 1.396
Presentation.MOUSE_SENS = 0.0022
Presentation.STICK_SPEED = 2.1

local hideParts: { [string]: boolean } = { Head = true }
local hideClasses: { [string]: boolean } = { Accessory = true, Accoutrement = true, Hat = true }
Presentation.HIDE_PART_NAMES = hideParts
Presentation.HIDE_CLASSES = hideClasses
-- The local body is hidden while the viewmodel draws the hands, so hair and shoulders cannot fill the lens.
Presentation.HIDE_LOCAL_BODY = true

-- Camera space: -Z is in front of the lens, +Y is up. Hands sit low and off the center dot.
local hands: { [string]: { x: number, y: number, z: number } } = {
	right = { x = 0.58, y = -0.46, z = -1.35 },
	left = { x = -0.22, y = -0.5, z = -1.05 },
}
Presentation.HANDS = hands

local function mag(v: { x: number, y: number, z: number }): number
	return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

function Presentation.unit(v: { x: number, y: number, z: number }): { x: number, y: number, z: number }
	local m = mag(v)
	if m < 1e-6 then
		return { x = 0, y = 0, z = -1 }
	end
	return { x = v.x / m, y = v.y / m, z = v.z / m }
end

function Presentation.shoulderOrigin(focus: { x: number, y: number, z: number }, look: { x: number, y: number, z: number }, zoom: number?): { x: number, y: number, z: number }
	local l = Presentation.unit(look)
	local z = zoom or Presentation.AIM_ZOOM
	return { x = focus.x - l.x * z, y = focus.y - l.y * z, z = focus.z - l.z * z }
end

function Presentation.eyePosition(focus: { x: number, y: number, z: number }, look: { x: number, y: number, z: number }, forward: number?): { x: number, y: number, z: number }
	local l = Presentation.unit(look)
	local f = forward or Presentation.EYE_FORWARD
	return { x = focus.x + l.x * f, y = focus.y + l.y * f, z = focus.z + l.z * f }
end

local function along(origin: { x: number, y: number, z: number }, look: { x: number, y: number, z: number }, reach: number): { x: number, y: number, z: number }
	return { x = origin.x + look.x * reach, y = origin.y + look.y * reach, z = origin.z + look.z * reach }
end

-- World point sent to the server. Always the shoulder ray, never the eye.
function Presentation.shotAim(focus: { x: number, y: number, z: number }, look: { x: number, y: number, z: number }): { x: number, y: number, z: number }
	local l = Presentation.unit(look)
	return along(Presentation.shoulderOrigin(focus, l, Presentation.AIM_ZOOM), l, Presentation.AIM_REACH)
end

-- Where an eye-level ray would land. The client does not call this. Tests use it to show the lens is not the aim origin.
function Presentation.eyeAim(focus: { x: number, y: number, z: number }, look: { x: number, y: number, z: number }): { x: number, y: number, z: number }
	local l = Presentation.unit(look)
	return along(Presentation.eyePosition(focus, l, Presentation.EYE_FORWARD), l, Presentation.AIM_REACH)
end

function Presentation.dirFrom(from: { x: number, y: number, z: number }, aim: { x: number, y: number, z: number }): { x: number, y: number, z: number }
	return Presentation.unit({ x = aim.x - from.x, y = aim.y - from.y, z = aim.z - from.z })
end

function Presentation.fov(sprinting: boolean, reduce: boolean): number
	if reduce or not sprinting then
		return Presentation.FOV
	end
	return math.min(Presentation.FOV_SPRINT, Presentation.FOV_MAX)
end

function Presentation.bob(t: number, speed: number, reduce: boolean): { x: number, y: number, z: number }
	if reduce or speed < 0.75 then
		return { x = 0, y = 0, z = 0 }
	end
	local s = math.clamp(speed / 16, 0, 1.35)
	return {
		x = math.sin(t * 8) * 0.018 * s,
		y = math.abs(math.sin(t * 8)) * 0.032 * s,
		z = 0,
	}
end

function Presentation.hidesPart(name: string): boolean
	return Presentation.HIDE_PART_NAMES[name] == true
end

function Presentation.hidesClass(className: string): boolean
	return Presentation.HIDE_CLASSES[className] == true
end

function Presentation.crosshairVisible(first: boolean, arena: boolean, panelOpen: boolean, held: boolean): boolean
	return first and arena and not panelOpen and not held
end

return Presentation

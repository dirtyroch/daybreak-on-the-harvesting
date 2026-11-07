--!strict
-- First-person presentation. Camera, hands and the reticle only.
-- Hit tests stay in Combat / MatchService and do not read anything in this module.
-- Field of view cannot go wider than the third-person default (70), so the view
-- never shows more of the arena than third person at the same setting.
local Presentation = {}

Presentation.FOV_MAX = 70
Presentation.FOV_MIN = 60
Presentation.FOV_DEFAULT = 70

Presentation.HEAD_ATTACH = {
	HatAttachment = true,
	HairAttachment = true,
	FaceFrontAttachment = true,
	FaceCenterAttachment = true,
	NeckAttachment = true,
}

-- Real arms are hidden locally because the viewmodel draws them. The torso and legs stay.
Presentation.ARM = {
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
}

-- Camera-space grip. +X right, +Y up, -Z forward (Roblox cameras look down -Z).
-- `reach` is the weapon's longest half-extent in studs before scale, used to keep the
-- mesh off the center of the screen where the reticle sits.
Presentation.GRIPS = {
	bow = { x = 0.72, y = -0.55, z = -1.9, pitch = 8, yaw = 210, roll = 8, scale = 0.38, reach = 1.15 },
	spear = { x = 0.95, y = -0.72, z = -2.1, pitch = 70, yaw = 25, roll = 0, scale = 0.22, reach = 1.6 },
	knife = { x = 0.55, y = -0.42, z = -1.45, pitch = -20, yaw = 160, roll = 10, scale = 0.9, reach = 0.55 },
	hands = { x = 0.45, y = -0.48, z = -1.3, pitch = 0, yaw = 0, roll = 0, scale = 1, reach = 0.3 },
}

-- Both arms sit in the lower-right of the lens so the center mark stays clear.
Presentation.ARMS = {
	{ name = "RightForearm", size = { 0.26, 0.62, 0.26 }, x = 0.55, y = -0.38, z = -1.15 },
	{ name = "LeftForearm", size = { 0.26, 0.62, 0.26 }, x = 0.22, y = -0.48, z = -1.25 },
	{ name = "RightHand", size = { 0.22, 0.2, 0.24 }, x = 0.62, y = -0.46, z = -1.4 },
	{ name = "LeftHand", size = { 0.22, 0.2, 0.24 }, x = 0.28, y = -0.55, z = -1.45 },
}

function Presentation.clampFov(n: number): number
	if type(n) ~= "number" or n ~= n or math.abs(n) == math.huge then
		return Presentation.FOV_DEFAULT
	end
	if n < 63 then
		return Presentation.FOV_MIN
	elseif n < 68 then
		return 65
	end
	return Presentation.FOV_MAX
end

function Presentation.viewOf(settings: any): string
	if type(settings) == "table" and settings.view == "first" then
		return "first"
	end
	return "third"
end

function Presentation.motionReduced(settingFlag: boolean, osFlag: boolean): boolean
	return settingFlag == true or osFlag == true
end

-- First person only while you are in the match and no scripted camera or menu owns the screen.
function Presentation.shouldForceFirst(view: string, mode: string, panelsOpen: boolean, cutscene: boolean, scriptedCamera: boolean): boolean
	return view == "first" and mode == "arena" and not panelsOpen and not cutscene and not scriptedCamera
end

export type HideInfo = { head: boolean, held: boolean, accessory: string? }

-- `accessory` nil means this part is not an accessory. "" means it is one but the
-- attachment name is unknown, so it is hidden (a hat with no attachment still clips).
function Presentation.localHide(partName: string, info: HideInfo): boolean
	if info.head or info.held then
		return true
	end
	if info.accessory ~= nil then
		if info.accessory == "" or Presentation.HEAD_ATTACH[info.accessory] == true then
			return true
		end
	end
	if Presentation.ARM[partName] == true then
		return true
	end
	return false
end

function Presentation.grip(slot: string): any
	return Presentation.GRIPS[slot] or Presentation.GRIPS.hands
end

function Presentation.aimClear(slot: string): boolean
	local g = Presentation.grip(slot)
	local lateral = math.sqrt(g.x * g.x + g.y * g.y)
	return g.z < -0.8 and lateral > (g.reach * g.scale) + 0.05
end

function Presentation.armsClear(): boolean
	for _, a in ipairs(Presentation.ARMS) do
		if a.z >= -0.8 then
			return false
		end
		local d = math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
		if d < 0.9 then
			return false
		end
		local half = math.max(a.size[1], a.size[2]) * 0.5
		local lateral = math.sqrt(a.x * a.x + a.y * a.y)
		if lateral <= half + 0.04 then
			return false
		end
	end
	return true
end

-- Viewmodel bob only. Never applied to the world camera, so it cannot move the aim ray.
function Presentation.bob(speed: number, t: number, reduced: boolean): (number, number, number)
	if reduced or type(speed) ~= "number" or speed < 0.5 then
		return 0, 0, 0
	end
	local s = math.clamp(speed / 16, 0, 1.2)
	local y = math.sin(t * 8) * 0.03 * s
	local x = math.cos(t * 4) * 0.015 * s
	return x, y, 0
end

function Presentation.swing(slot: string, age: number, reduced: boolean): (number, number, number)
	if reduced or type(age) ~= "number" or age < 0 or age > 0.18 then
		return 0, 0, 0
	end
	local k = math.sin((age / 0.18) * math.pi) * 0.1
	if slot == "bow" then
		return 0, 0, -k
	elseif slot == "spear" then
		return 0, k * 0.6, -k
	end
	return k * 0.5, -k * 0.3, 0
end

function Presentation.reticle(touch: boolean): { dot: number, ring: number }
	if touch then
		return { dot = 5, ring = 22 }
	end
	return { dot = 3, ring = 14 }
end

return Presentation

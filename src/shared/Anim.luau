--!strict
--[[
	Anim.luau: podium poses and emotes as keyframes generated in code.

	Each clip is a list of keyframes over R15 joints (Motor6D names), in degrees. The client's
	AnimPlayer samples a clip every frame and writes Motor6D.Transform, so every pose and emote
	really moves the character with no uploaded animation. When Mike uploads a polished
	animation and puts its id on the Store item (`anim`), that plays instead.

	Rotations: X+ swings a limb forward/up, Z+ lifts the right arm out to the side (Z- for the
	left arm), Waist X- bends forward, Root Y spins the whole body.
]]
local Anim = {}

export type Rot = { number } -- { x, y, z } degrees
export type Key = { t: number, pose: { [string]: Rot } }
export type Clip = { length: number, loop: boolean, hold: boolean?, keys: { Key }, prop: string?, propJoint: string? }

Anim.JOINTS = {
	"Root", "Waist", "Neck",
	"RightShoulder", "RightElbow", "RightWrist",
	"LeftShoulder", "LeftElbow", "LeftWrist",
	"RightHip", "RightKnee", "LeftHip", "LeftKnee",
}
local JOINT_SET: { [string]: boolean } = {}
for _, j in ipairs(Anim.JOINTS) do
	JOINT_SET[j] = true
end
Anim.JOINT_SET = JOINT_SET

local function K(t: number, pose: { [string]: Rot }): Key
	return { t = t, pose = pose }
end

-- Poses play once and hold the last frame (podium, Hall of Champions statues).
-- Emotes play once (or loop a few times) and return to rest.
Anim.CLIPS = {
	pose_heart = { length = 1.0, loop = false, hold = true, keys = {
		K(0, {}),
		K(0.5, { RightShoulder = { 55, 0, 35 }, RightElbow = { 105, 0, 0 }, Neck = { 8, 0, 0 } }),
		K(1.0, { RightShoulder = { 60, 0, 40 }, RightElbow = { 115, 0, 0 }, Neck = { -6, 0, 0 }, Waist = { 4, 0, 0 } }),
	} },
	pose_bow = { length = 1.4, loop = false, hold = true, keys = {
		K(0, {}),
		K(0.6, { Waist = { -38, 0, 0 }, Neck = { -15, 0, 0 }, RightShoulder = { 40, 0, -20 }, RightElbow = { 90, 0, 0 }, LeftShoulder = { 20, 0, -50 } }),
		K(1.4, { Waist = { -42, 0, 0 }, Neck = { -18, 0, 0 }, RightShoulder = { 42, 0, -22 }, RightElbow = { 95, 0, 0 }, LeftShoulder = { 25, 0, -60 } }),
	} },
	pose_lantern = { length = 1.2, loop = false, hold = true, prop = "lantern", propJoint = "RightHand", keys = {
		K(0, {}),
		K(0.7, { RightShoulder = { 175, 0, 10 }, RightElbow = { 10, 0, 0 }, Neck = { 20, 0, 0 }, LeftShoulder = { 0, 0, -25 }, LeftElbow = { 60, 0, 0 } }),
		K(1.2, { RightShoulder = { 178, 0, 8 }, RightElbow = { 5, 0, 0 }, Neck = { 25, 0, 0 }, LeftShoulder = { 0, 0, -30 }, LeftElbow = { 70, 0, 0 } }),
	} },
	pose_crown = { length = 2.0, loop = false, hold = true, prop = "crown", propJoint = "Head", keys = {
		K(0, {}),
		K(0.5, { RightShoulder = { 170, 0, 15 }, LeftShoulder = { 170, 0, -15 }, Neck = { 25, 0, 0 } }),
		K(1.0, { RightShoulder = { 120, 0, 25 }, LeftShoulder = { 120, 0, -25 }, RightElbow = { 40, 0, 0 }, LeftElbow = { 40, 0, 0 }, Neck = { 30, 0, 0 } }),
		K(1.6, { RightShoulder = { 30, 0, 50 }, LeftShoulder = { 30, 0, -50 }, Neck = { 0, 0, 0 }, Waist = { 6, 0, 0 } }),
		K(2.0, { RightShoulder = { 20, 0, 55 }, LeftShoulder = { 20, 0, -55 }, Waist = { 8, 0, 0 } }),
	} },
	pose_regent = { length = 1.5, loop = false, hold = true, keys = {
		K(0, {}),
		K(0.8, { RightShoulder = { 30, 0, 70 }, LeftShoulder = { 30, 0, -70 }, Neck = { 18, 0, 0 }, Waist = { 8, 0, 0 }, RightHip = { 0, 0, 8 }, LeftHip = { 0, 0, -8 } }),
		K(1.5, { RightShoulder = { 35, 0, 75 }, LeftShoulder = { 35, 0, -75 }, Neck = { 22, 0, 0 }, Waist = { 10, 0, 0 }, RightHip = { 0, 0, 10 }, LeftHip = { 0, 0, -10 } }),
	} },
	pose_firstlight = { length = 1.3, loop = false, hold = true, keys = {
		K(0, {}),
		K(0.6, { RightShoulder = { 160, 0, 30 }, RightElbow = { 0, 0, 0 }, LeftShoulder = { 0, 0, -20 }, Neck = { 15, 0, 0 } }),
		K(1.3, { RightShoulder = { 165, 0, 28 }, LeftShoulder = { 10, 0, -25 }, Neck = { 20, 0, 0 }, Waist = { 6, 0, 0 } }),
	} },
	pose_reaper = { length = 1.2, loop = false, hold = true, keys = {
		K(0, {}),
		K(0.6, { RightHip = { 50, 0, 0 }, RightKnee = { -80, 0, 0 }, LeftHip = { -10, 0, 0 }, Waist = { -10, 0, 0 }, RightShoulder = { 60, 0, 20 }, RightElbow = { 80, 0, 0 } }),
		K(1.2, { RightHip = { 55, 0, 0 }, RightKnee = { -85, 0, 0 }, LeftHip = { -12, 0, 0 }, Waist = { -12, 0, 0 }, RightShoulder = { 62, 0, 22 }, RightElbow = { 85, 0, 0 }, Neck = { 10, 0, 0 } }),
	} },
	pose_moon = { length = 1.4, loop = false, hold = true, prop = "lantern", propJoint = "LeftHand", keys = {
		K(0, {}),
		K(0.7, { LeftShoulder = { 140, 0, -20 }, RightShoulder = { 0, 0, 30 }, Neck = { 25, 0, 0 }, Waist = { 0, 15, 0 } }),
		K(1.4, { LeftShoulder = { 145, 0, -22 }, RightShoulder = { 0, 0, 35 }, Neck = { 28, 0, 0 }, Waist = { 0, 18, 0 } }),
	} },
	emote_tip = { length = 1.4, loop = false, keys = {
		K(0, {}),
		K(0.4, { RightShoulder = { 150, 0, 30 }, RightElbow = { 110, 0, 0 } }),
		K(0.7, { RightShoulder = { 150, 0, 30 }, RightElbow = { 110, 0, 0 }, Neck = { -20, 0, 0 }, Waist = { -10, 0, 0 } }),
		K(1.0, { RightShoulder = { 120, 0, 40 }, RightElbow = { 60, 0, 0 } }),
		K(1.4, {}),
	} },
	emote_toast = { length = 2.0, loop = false, prop = "thermos", propJoint = "RightHand", keys = {
		K(0, {}),
		K(0.5, { RightShoulder = { 100, 0, 10 }, RightElbow = { 40, 0, 0 } }),
		K(0.9, { RightShoulder = { 160, 0, 10 }, RightElbow = { 10, 0, 0 }, Neck = { 15, 0, 0 } }),
		K(1.4, { RightShoulder = { 120, 0, 10 }, RightElbow = { 120, 0, 0 }, Neck = { 25, 0, 0 } }),
		K(2.0, {}),
	} },
	emote_twirl = { length = 1.6, loop = false, prop = "ribbon", propJoint = "RightHand", keys = {
		K(0, {}),
		K(0.4, { Root = { 0, 120, 0 }, RightShoulder = { 0, 0, 80 }, LeftShoulder = { 0, 0, -80 } }),
		K(0.8, { Root = { 0, 240, 0 }, RightShoulder = { 0, 0, 90 }, LeftShoulder = { 0, 0, -90 } }),
		K(1.2, { Root = { 0, 360, 0 }, RightShoulder = { 0, 0, 80 }, LeftShoulder = { 0, 0, -80 } }),
		K(1.6, { Root = { 0, 360, 0 } }),
	} },
	emote_lantern = { length = 2.4, loop = false, prop = "lantern", propJoint = "RightHand", keys = {
		K(0, {}),
		K(0.4, { RightShoulder = { 170, 0, 20 } }),
		K(0.8, { RightShoulder = { 170, 0, -10 }, Waist = { 0, 0, -6 } }),
		K(1.2, { RightShoulder = { 170, 0, 40 }, Waist = { 0, 0, 6 } }),
		K(1.6, { RightShoulder = { 170, 0, -10 }, Waist = { 0, 0, -6 } }),
		K(2.0, { RightShoulder = { 170, 0, 30 } }),
		K(2.4, {}),
	} },
	emote_clap = { length = 1.6, loop = false, keys = {
		K(0, {}),
		K(0.3, { RightShoulder = { 80, 0, -20 }, LeftShoulder = { 80, 0, 20 }, RightElbow = { 30, 0, 0 }, LeftElbow = { 30, 0, 0 } }),
		K(0.5, { RightShoulder = { 80, 0, 5 }, LeftShoulder = { 80, 0, -5 }, RightElbow = { 30, 0, 0 }, LeftElbow = { 30, 0, 0 } }),
		K(0.7, { RightShoulder = { 80, 0, -20 }, LeftShoulder = { 80, 0, 20 }, RightElbow = { 30, 0, 0 }, LeftElbow = { 30, 0, 0 } }),
		K(0.9, { RightShoulder = { 80, 0, 5 }, LeftShoulder = { 80, 0, -5 }, RightElbow = { 30, 0, 0 }, LeftElbow = { 30, 0, 0 } }),
		K(1.1, { RightShoulder = { 80, 0, -20 }, LeftShoulder = { 80, 0, 20 }, RightElbow = { 30, 0, 0 }, LeftElbow = { 30, 0, 0 } }),
		K(1.6, {}),
	} },
	emote_harvest = { length = 2.2, loop = false, keys = {
		K(0, {}),
		K(0.5, { Waist = { -30, 0, 0 }, RightShoulder = { 60, 0, 0 }, LeftShoulder = { 60, 0, 0 }, RightKnee = { -30, 0, 0 }, LeftKnee = { -30, 0, 0 }, RightHip = { 25, 0, 0 }, LeftHip = { 25, 0, 0 } }),
		K(1.2, { Waist = { 5, 0, 0 }, RightShoulder = { 170, 0, 20 }, LeftShoulder = { 170, 0, -20 }, Neck = { 20, 0, 0 } }),
		K(1.7, { Waist = { 5, 0, 0 }, RightShoulder = { 170, 0, 30 }, LeftShoulder = { 170, 0, -30 }, Neck = { 25, 0, 0 } }),
		K(2.2, {}),
	} },
	emote_patron = { length = 1.8, loop = false, keys = {
		K(0, {}),
		K(0.6, { RightShoulder = { 90, -30, 0 }, RightElbow = { 90, 0, 0 }, Waist = { -15, 0, 0 }, Neck = { -10, 0, 0 } }),
		K(1.2, { RightShoulder = { 60, 0, 60 }, RightElbow = { 10, 0, 0 }, Waist = { -20, 0, 0 } }),
		K(1.8, {}),
	} },
} :: { [string]: Clip }

-- Free poses everyone can use (so the podium always animates).
Anim.DEFAULT_POSE = "pose_firstlight"

local function ease(a: number): number
	return 0.5 - math.cos(a * math.pi) * 0.5
end

local function rotOf(k: Key, j: string): Rot
	return k.pose[j] or { 0, 0, 0 }
end

-- Sample a clip at time t. Returns joint -> { x, y, z } degrees for every joint the clip uses.
function Anim.sample(clip: Clip, t: number): { [string]: Rot }
	local keys = clip.keys
	if clip.loop then
		t = t % clip.length
	else
		t = math.clamp(t, 0, clip.length)
	end
	local a, b = keys[1], keys[#keys]
	for i = 1, #keys - 1 do
		if t >= keys[i].t and t <= keys[i + 1].t then
			a, b = keys[i], keys[i + 1]
			break
		end
	end
	local span = b.t - a.t
	local f = span > 0 and ease((t - a.t) / span) or 1
	local used: { [string]: boolean } = {}
	for _, k in ipairs(keys) do
		for j in pairs(k.pose) do
			used[j] = true
		end
	end
	local out = {}
	for j in pairs(used) do
		local ra, rb = rotOf(a, j), rotOf(b, j)
		out[j] = { ra[1] + (rb[1] - ra[1]) * f, ra[2] + (rb[2] - ra[2]) * f, ra[3] + (rb[3] - ra[3]) * f }
	end
	return out
end

function Anim.validate(): { string }
	local errs = {}
	for id, c in pairs(Anim.CLIPS) do
		if #c.keys < 2 then
			table.insert(errs, id .. " needs 2+ keys")
		end
		local last = -1
		for _, k in ipairs(c.keys) do
			if k.t <= last then
				table.insert(errs, id .. " keys out of order")
			end
			last = k.t
			for j, r in pairs(k.pose) do
				if not JOINT_SET[j] then
					table.insert(errs, id .. " bad joint " .. j)
				end
				for _, v in ipairs(r) do
					if v ~= v or math.abs(v) > 400 then
						table.insert(errs, id .. " bad angle on " .. j)
					end
				end
			end
		end
		if math.abs(c.keys[#c.keys].t - c.length) > 1e-6 then
			table.insert(errs, id .. " last key must be at length")
		end
		if not c.hold and not c.loop then
			for j, r in pairs(c.keys[#c.keys].pose) do
				for _, v in ipairs(r) do
					if v % 360 ~= 0 then
						table.insert(errs, id .. " emote must end at rest (" .. j .. ")")
					end
				end
			end
		end
	end
	return errs
end

-- Small props held during some clips, as Arms-style part specs (grip at the hand).
Anim.PROPS = {
	lantern = {
		{ name = "Handle", shape = "Block", size = { 0.08, 0.6, 0.08 }, pos = { 0, -0.3, 0 }, color = "#3A2A22", mat = "Metal" },
		{ name = "Lantern", shape = "Block", size = { 0.55, 0.7, 0.55 }, pos = { 0, -0.9, 0 }, color = "#FFC86B", mat = "Neon", trans = 0.2, glow = true },
		{ name = "Cap", shape = "Block", size = { 0.65, 0.1, 0.65 }, pos = { 0, -0.52, 0 }, color = "#7A2E1E", mat = "Metal" },
	},
	thermos = {
		{ name = "Thermos", shape = "Cylinder", size = { 0.8, 0.36, 0.36 }, pos = { 0, -0.2, 0 }, rot = { 0, 0, 90 }, color = "#C9A04E", mat = "Foil" },
		{ name = "Lid", shape = "Cylinder", size = { 0.16, 0.4, 0.4 }, pos = { 0, 0.25, 0 }, rot = { 0, 0, 90 }, color = "#5A3A1E", mat = "Metal" },
	},
	crown = {
		{ name = "Crown", shape = "Cylinder", size = { 0.25, 1.3, 1.3 }, pos = { 0, 0.7, 0 }, rot = { 0, 0, 90 }, color = "#F2D27A", mat = "Fabric" },
	},
	ribbon = {
		{ name = "Stick", shape = "Block", size = { 0.06, 0.8, 0.06 }, pos = { 0, -0.4, 0 }, color = "#8C5A2B", mat = "Wood" },
		{ name = "Ribbon", shape = "Block", size = { 0.04, 1.8, 0.25 }, pos = { 0, -1.6, 0.2 }, rot = { 25, 0, 0 }, color = "#FF9EC7", mat = "Fabric" },
	},
}

return Anim

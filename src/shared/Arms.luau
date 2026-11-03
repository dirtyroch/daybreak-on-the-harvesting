--!nocheck
--[[
	Arms.luau: held weapon models built from plain Parts in code (no uploaded meshes needed).

	Every weapon skin is a list of part specs (shape, size, offset, rotation, color, material),
	so a Gilded Bow, an Ember Spear and a plain bow look clearly different in your hand, on the
	podium, on Hall of Champions statues and in the shop's try-on. Same stats for every skin.

	Local frame: the grip is at the origin and the weapon runs along +Y. Arms.build() returns a
	Model whose PrimaryPart "Grip" sits at the hand; Arms.attach() welds it to a character.
	Mastery (Mastery.luau) adds visible upgrades on top: a gold trim band, then a sparkle,
	then gilded edges. It only works through `env`, so Lune tests can build every skin too.
]]
local Arms = {}

export type PartSpec = {
	name: string,
	shape: string, -- "Block" | "Ball" | "Cylinder" | "Wedge"
	size: { number },
	pos: { number },
	rot: { number }?, -- degrees, applied X then Y then Z
	color: string,
	mat: string, -- Enum.Material name
	trans: number?,
	glow: boolean?, -- adds a PointLight
}
export type Spec = { id: string, slot: string, name: string, parts: { PartSpec }, fx: { sparkle: string?, light: string?, fire: string? } }

local function P(name, shape, size, pos, rot, color, mat, extra)
	local p = { name = name, shape = shape, size = size, pos = pos, rot = rot, color = color, mat = mat }
	if extra then
		for k, v in pairs(extra) do
			p[k] = v
		end
	end
	return p
end

-- ===== bows =====
-- o: wood, mat, grip, string, tip ("ball" | "leaf" | "crystal" | "sun"), accent, accentMat, width
local function bow(o)
	local w = o.width or 1
	local parts = {
		P("Grip", "Block", { 0.34, 0.75, 0.42 }, { 0, 0, 0 }, nil, o.grip, o.gripMat or "Fabric"),
		P("LimbUpA", "Block", { 0.24 * w, 1.15, 0.3 * w }, { 0, 0.92, 0.1 }, { -12, 0, 0 }, o.wood, o.mat),
		P("LimbUpB", "Block", { 0.2 * w, 1.05, 0.26 * w }, { 0, 1.88, 0.36 }, { -26, 0, 0 }, o.wood, o.mat),
		P("LimbDnA", "Block", { 0.24 * w, 1.15, 0.3 * w }, { 0, -0.92, 0.1 }, { 12, 0, 0 }, o.wood, o.mat),
		P("LimbDnB", "Block", { 0.2 * w, 1.05, 0.26 * w }, { 0, -1.88, 0.36 }, { 26, 0, 0 }, o.wood, o.mat),
		P("String", "Block", { 0.05, 4.7, 0.05 }, { 0, 0, 0.62 }, nil, o.string or "#EDE6D6", "SmoothPlastic"),
	}
	local tip = o.tip or "ball"
	for _, s in ipairs({ 1, -1 }) do
		local y = 2.36 * s
		if tip == "ball" then
			table.insert(parts, P("Tip", "Ball", { 0.24, 0.24, 0.24 }, { 0, y, 0.62 }, nil, o.accent or o.wood, o.accentMat or o.mat))
		elseif tip == "leaf" then
			table.insert(parts, P("Leaf", "Wedge", { 0.08, 0.55, 0.32 }, { 0, y + 0.12 * s, 0.6 }, { s > 0 and 0 or 180, 0, 0 }, o.accent, o.accentMat or "Foil"))
			table.insert(parts, P("LeafB", "Wedge", { 0.08, 0.4, 0.26 }, { 0, y - 0.25 * s, 0.48 }, { s > 0 and 180 or 0, 0, 0 }, o.accent, o.accentMat or "Foil"))
		elseif tip == "crystal" then
			table.insert(parts, P("Crystal", "Block", { 0.22, 0.6, 0.22 }, { 0, y + 0.15 * s, 0.6 }, { 0, 45, 18 * s }, o.accent, "Ice", { trans = 0.15 }))
			table.insert(parts, P("CrystalB", "Block", { 0.16, 0.42, 0.16 }, { 0.12, y - 0.1 * s, 0.5 }, { 0, 45, -30 * s }, o.accent, "Ice", { trans = 0.15 }))
		elseif tip == "sun" then
			table.insert(parts, P("Crest", "Cylinder", { 0.1, 0.5, 0.5 }, { 0, y + 0.1 * s, 0.6 }, { 0, 90, 0 }, o.accent, "Foil"))
			table.insert(parts, P("CrestGem", "Ball", { 0.2, 0.2, 0.2 }, { 0, y + 0.1 * s, 0.68 }, nil, o.glowColor or "#FFB347", "Neon"))
		end
	end
	if o.bands then
		for i = 1, o.bands do
			local y = 0.55 + (i - 1) * 0.55
			table.insert(parts, P("Band", "Block", { 0.3 * w, 0.08, 0.36 * w }, { 0, y, 0.14 + (i - 1) * 0.08 }, { -14 - i * 4, 0, 0 }, o.accent, o.accentMat or "Foil"))
			table.insert(parts, P("Band", "Block", { 0.3 * w, 0.08, 0.36 * w }, { 0, -y, 0.14 + (i - 1) * 0.08 }, { 14 + i * 4, 0, 0 }, o.accent, o.accentMat or "Foil"))
		end
	end
	if o.inlay then
		table.insert(parts, P("Inlay", "Block", { 0.06, 3.2, 0.06 }, { 0, 0, -0.12 }, nil, o.inlay, "Neon"))
	end
	if o.disk then
		table.insert(parts, P("SunDisk", "Cylinder", { 0.12, 0.95, 0.95 }, { 0, 0, -0.24 }, { 0, 90, 0 }, o.accent, "Foil"))
		table.insert(parts, P("SunCore", "Cylinder", { 0.14, 0.5, 0.5 }, { 0, 0, -0.27 }, { 0, 90, 0 }, o.glowColor or "#FFB347", "Neon", { glow = true }))
	end
	return parts
end

-- ===== spears =====
-- o: shaft, shaftMat, head ("leaf" | "ember" | "glass" | "stone" | "wheat"), headColor, headMat, accent
local function spear(o)
	local parts = {
		P("Shaft", "Cylinder", { 6.6, 0.22, 0.22 }, { 0, 1.2, 0 }, { 0, 0, 90 }, o.shaft, o.shaftMat or "Wood"),
		P("Wrap", "Cylinder", { 0.7, 0.27, 0.27 }, { 0, 0, 0 }, { 0, 0, 90 }, o.wrap or "#4A3424", "Fabric"),
		P("Butt", "Ball", { 0.3, 0.3, 0.3 }, { 0, -2.15, 0 }, nil, o.accent or "#6B6B6B", o.accentMat or "Metal"),
		P("Collar", "Cylinder", { 0.22, 0.3, 0.3 }, { 0, 4.5, 0 }, { 0, 0, 90 }, o.accent or "#6B6B6B", o.accentMat or "Metal"),
	}
	local h = o.head or "leaf"
	local hc, hm = o.headColor or "#9AA3AD", o.headMat or "Metal"
	if h == "leaf" or h == "stone" then
		table.insert(parts, P("HeadA", "Wedge", { 0.08, 0.9, 0.36 }, { 0, 5.05, 0 }, nil, hc, hm))
		table.insert(parts, P("HeadB", "Wedge", { 0.08, 0.5, 0.36 }, { 0, 4.35, 0 }, { 180, 0, 0 }, hc, hm))
	elseif h == "ember" then
		table.insert(parts, P("HeadA", "Wedge", { 0.12, 1.1, 0.42 }, { 0, 5.15, 0 }, nil, "#2B2522", "Slate"))
		table.insert(parts, P("HeadB", "Wedge", { 0.12, 0.5, 0.42 }, { 0, 4.35, 0 }, { 180, 0, 0 }, "#2B2522", "Slate"))
		table.insert(parts, P("EmberCore", "Wedge", { 0.14, 0.75, 0.22 }, { 0, 5.02, 0 }, nil, hc, "Neon", { glow = true }))
		table.insert(parts, P("EmberRing", "Cylinder", { 0.1, 0.36, 0.36 }, { 0, 4.72, 0 }, { 0, 0, 90 }, hc, "Neon"))
	elseif h == "glass" then
		table.insert(parts, P("HeadA", "Wedge", { 0.14, 1.0, 0.4 }, { 0, 5.1, 0 }, nil, hc, "Glass", { trans = 0.25 }))
		table.insert(parts, P("HeadB", "Wedge", { 0.14, 0.45, 0.4 }, { 0, 4.38, 0 }, { 180, 0, 0 }, hc, "Glass", { trans = 0.25 }))
		table.insert(parts, P("Drop", "Ball", { 0.26, 0.26, 0.26 }, { 0, 4.6, 0 }, nil, "#DFF7FF", "Glass", { trans = 0.1 }))
	elseif h == "wheat" then
		table.insert(parts, P("HeadA", "Wedge", { 0.08, 0.9, 0.34 }, { 0, 5.05, 0 }, nil, hc, hm))
		table.insert(parts, P("HeadB", "Wedge", { 0.08, 0.45, 0.34 }, { 0, 4.38, 0 }, { 180, 0, 0 }, hc, hm))
		for i, a in ipairs({ -35, 35, -55, 55 }) do
			table.insert(parts, P("Ear", "Block", { 0.1, 0.42, 0.14 }, { (a > 0 and 0.16 or -0.16) * (i > 2 and 1.4 or 1), 4.25 - (i > 2 and 0.3 or 0), 0 }, { 0, 0, a }, "#E9C46A", "Fabric"))
		end
	end
	if h == "fork" then
		table.insert(parts, P("ForkBar", "Block", { 0.12, 0.12, 0.9 }, { 0, 4.62, 0 }, nil, hc, hm))
		for i, z in ipairs({ -0.38, 0, 0.38 }) do
			table.insert(parts, P("Tine" .. i, "Cylinder", { 0.9, 0.09, 0.09 }, { 0, 5.08, z }, { 0, 0, 90 }, hc, hm))
		end
	end
	if o.ribbon then
		table.insert(parts, P("Ribbon", "Block", { 0.04, 0.9, 0.18 }, { 0.16, 4.05, 0 }, { 0, 0, 12 }, o.ribbon, "Fabric"))
	end
	return parts
end

-- ===== knives =====
local function knife(o)
	return {
		P("Handle", "Block", { 0.22, 0.6, 0.26 }, { 0, 0, 0 }, nil, o.handle or "#3B2A1E", o.handleMat or "Wood"),
		P("Guard", "Block", { 0.5, 0.08, 0.3 }, { 0, 0.33, 0 }, nil, o.accent or "#8A8A8A", o.accentMat or "Metal"),
		P("Blade", "Wedge", { 0.06, 0.95, 0.24 }, { 0, 0.85, 0 }, nil, o.blade, o.bladeMat or "Metal", { trans = o.bladeTrans }),
		P("Pommel", "Ball", { 0.2, 0.2, 0.2 }, { 0, -0.34, 0 }, nil, o.accent or "#8A8A8A", o.accentMat or "Metal"),
		o.edge and P("Edge", "Block", { 0.02, 0.85, 0.03 }, { 0, 0.82, 0.11 }, nil, o.edge, "Neon") or nil,
	}
end

-- Default (free) looks and every skin. Keys are Store item ids; "" = default for the slot.
Arms.SKINS = {
	bow = {
		[""] = function() return bow({ wood = "#7A4E2A", mat = "Wood", grip = "#4A3424" }) end,
		skin_bow_ashen = function() return bow({ wood = "#C9B79C", mat = "WoodPlanks", grip = "#2F2A26", accent = "#5C544C" }) end,
		skin_bow_gilded = function() return bow({ wood = "#E8B84A", mat = "Foil", grip = "#6B3B1E", tip = "leaf", accent = "#FFE08A", bands = 2 }) end,
		skin_bow_mirror = function() return bow({ wood = "#D7E6EE", mat = "Glass", grip = "#5D6B75", accent = "#FFFFFF", accentMat = "Glass", inlay = "#BFE7FF" }) end,
		skin_bow_frost = function() return bow({ wood = "#A8DDF0", mat = "Ice", grip = "#2E4A5A", tip = "crystal", accent = "#E9FBFF", string = "#BFF3FF" }) end,
		skin_bow_regent = function() return bow({ wood = "#C98A2E", mat = "Foil", grip = "#5A1E1E", tip = "sun", accent = "#FFD36B", bands = 3, disk = true, width = 1.25, glowColor = "#FFB347" }) end,
		skin_bow_harvest = function() return bow({ wood = "#8C5A2B", mat = "Wood", grip = "#3E2A18", tip = "leaf", accent = "#E9C46A", accentMat = "Fabric", bands = 1, string = "#F2D27A" }) end,
		skin_bow_comet = function() return bow({ wood = "#2A2F55", mat = "SmoothPlastic", grip = "#14172B", tip = "crystal", accent = "#BFD4FF", inlay = "#9DB4FF" }) end,
		skin_bow_s2_orchard = function() return bow({ wood = "#7A3B2A", mat = "Wood", grip = "#2E1B12", tip = "leaf", accent = "#C8553D", accentMat = "Fabric", bands = 2, string = "#E9C46A" }) end,
		skin_bow_founders = function() return bow({ wood = "#E6D8BE", mat = "Wood", grip = "#7A2E1E", tip = "sun", accent = "#F4C27A", accentMat = "Fabric", bands = 1, glowColor = "#FFB38A" }) end,
	},
	spear = {
		[""] = function() return spear({ shaft = "#8A6A3A", head = "leaf" }) end,
		skin_spear_ashen = function() return spear({ shaft = "#5E5952", shaftMat = "Slate", head = "stone", headColor = "#A8A29A", headMat = "Slate", accent = "#3A3633" }) end,
		skin_spear_ember = function() return spear({ shaft = "#3A2A22", head = "ember", headColor = "#FF7A3D", accent = "#B8572A" }) end,
		skin_spear_lake = function() return spear({ shaft = "#C9D9DE", shaftMat = "Marble", head = "glass", headColor = "#6FD3E8", accent = "#8FB8C6", ribbon = "#6FD3E8" }) end,
		skin_spear_wheat = function() return spear({ shaft = "#C8A05A", head = "wheat", headColor = "#D9B45A", headMat = "Foil", accent = "#8C6A2E", ribbon = "#E9C46A" }) end,
		skin_spear_regent = function() return spear({ shaft = "#5A1E1E", shaftMat = "Fabric", head = "leaf", headColor = "#FFD36B", headMat = "Foil", accent = "#FFD36B", accentMat = "Foil", ribbon = "#FFB347" }) end,
		skin_spear_s2_pitch = function() return spear({ shaft = "#9C6B3E", head = "fork", headColor = "#5E5F63", headMat = "Metal", accent = "#3A3633" }) end,
	},
	knife = {
		[""] = function() return knife({ blade = "#BFC6CF" }) end,
		skin_knife_copper = function() return knife({ blade = "#D98A4E", bladeMat = "Foil", accent = "#8C4B24", handle = "#2B1D14" }) end,
		skin_knife_night = function() return knife({ blade = "#2A2440", bladeMat = "Glass", accent = "#8E7CFF", handle = "#141020", edge = "#8E7CFF" }) end,
		skin_knife_lantern = function() return knife({ blade = "#F2E3C0", bladeMat = "Marble", accent = "#FFC86B", accentMat = "Neon", handle = "#7A2E1E" }) end,
		skin_knife_s2_sickle = function() return knife({ blade = "#CFD8E3", bladeMat = "Metal", accent = "#6B7480", handle = "#4A3424", edge = "#EAF2FF" }) end,
	},
}

-- Mastery overlays (levels from Mastery.luau). Applied on top of any skin, including defaults.
local function masteryParts(slot: string, level: number): { PartSpec }
	local out = {}
	if level >= 3 then
		local y = slot == "spear" and 0.45 or (slot == "knife" and 0.42 or 0.42)
		table.insert(out, P("MasteryTrim", "Cylinder", { 0.1, 0.4, 0.46 }, { 0, y, 0 }, { 0, 0, 90 }, "#FFD36B", "Foil"))
		table.insert(out, P("MasteryTrim", "Cylinder", { 0.1, 0.4, 0.46 }, { 0, -y, 0 }, { 0, 0, 90 }, "#FFD36B", "Foil"))
	end
	if level >= 5 then
		local len = slot == "spear" and 6.4 or (slot == "knife" and 0.9 or 3.4)
		local y = slot == "spear" and 1.3 or (slot == "knife" and 0.6 or 0)
		table.insert(out, P("MasteredEdge", "Block", { 0.04, len, 0.04 }, { 0.15, y, 0 }, nil, "#FFE9A8", "Neon"))
	end
	return out
end

local FX = {
	skin_bow_gilded = { light = "#FFD36B" },
	skin_bow_frost = { sparkle = "#E9FBFF" },
	skin_bow_regent = { light = "#FFB347", sparkle = "#FFD36B" },
	skin_bow_comet = { sparkle = "#BFD4FF" },
	skin_spear_ember = { fire = "#FF7A3D", light = "#FF7A3D" },
	skin_spear_lake = { light = "#6FD3E8" },
	skin_spear_regent = { light = "#FFD36B" },
	skin_knife_night = { light = "#8E7CFF" },
	skin_knife_lantern = { light = "#FFC86B" },
	skin_bow_founders = { light = "#FFB38A" },
	skin_knife_s2_sickle = { light = "#EAF2FF" },
}

function Arms.has(slot: string, skinId: string): boolean
	return Arms.SKINS[slot] ~= nil and Arms.SKINS[slot][skinId] ~= nil
end

-- The full spec for a slot + skin + mastery level. Unknown skins fall back to the default look.
function Arms.spec(slot: string, skinId: string?, mastery: number?): Spec
	local set = Arms.SKINS[slot] or Arms.SKINS.bow
	local key = (skinId and set[skinId]) and skinId or ""
	local parts = set[key]()
	local clean = {}
	for _, p in ipairs(parts) do
		if p then
			table.insert(clean, p)
		end
	end
	for _, p in ipairs(masteryParts(slot, mastery or 0)) do
		table.insert(clean, p)
	end
	local fx = table.clone(FX[key] or {})
	if (mastery or 0) >= 4 then
		fx.sparkle = fx.sparkle or "#FFE9A8"
	end
	return { id = key, slot = slot, name = key == "" and ("Default " .. slot) or key, parts = clean, fx = fx }
end

-- A short fingerprint of a spec, used by tests to prove skins look different.
function Arms.signature(spec: Spec): string
	local bits = {}
	for _, p in ipairs(spec.parts) do
		table.insert(bits, p.shape .. p.color .. p.mat)
	end
	table.sort(bits)
	return table.concat(bits, "|")
end

-- ===== building =====
local function cfOf(E, p)
	local r = p.rot or { 0, 0, 0 }
	return E.CFrame.new(p.pos[1], p.pos[2], p.pos[3]) * E.CFrame.Angles(math.rad(r[1]), math.rad(r[2]), math.rad(r[3]))
end

-- Builds the model at `at` (the grip CFrame). Parts are unanchored, massless, welded to Grip.
function Arms.build(E, spec: Spec, at): any
	local m = E.Instance.new("Model")
	m.Name = "Held"
	m:SetAttribute("Skin", spec.id)
	local grip = E.Instance.new("Part")
	grip.Name = "Grip"
	grip.Size = E.Vector3.new(0.2, 0.2, 0.2)
	grip.Transparency = 1
	grip.CanCollide = false
	grip.CanQuery = false
	grip.CanTouch = false
	grip.Massless = true
	grip.CFrame = at
	grip.Parent = m
	m.PrimaryPart = grip
	for _, s in ipairs(spec.parts) do
		local p
		if s.shape == "Wedge" then
			p = E.Instance.new("WedgePart")
		else
			p = E.Instance.new("Part")
			p.Shape = E.Enum.PartType[s.shape]
		end
		p.Name = s.name
		p.Size = E.Vector3.new(s.size[1], s.size[2], s.size[3])
		p.Color = E.Color3.fromHex(s.color)
		p.Material = E.Enum.Material[s.mat]
		p.Transparency = s.trans or 0
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.CFrame = at * cfOf(E, s)
		if s.glow then
			local l = E.Instance.new("PointLight")
			l.Color = p.Color
			l.Range = 6
			l.Brightness = 1.2
			l.Parent = p
		end
		local w = E.Instance.new("WeldConstraint")
		w.Part0 = grip
		w.Part1 = p
		w.Parent = p
		p.Parent = m
	end
	if spec.fx.light then
		local l = E.Instance.new("PointLight")
		l.Color = E.Color3.fromHex(spec.fx.light)
		l.Range = 7
		l.Brightness = 0.9
		l.Parent = grip
	end
	if spec.fx.sparkle then
		local s = E.Instance.new("ParticleEmitter")
		s.Name = "Sparkle"
		s.Color = E.ColorSequence.new(E.Color3.fromHex(spec.fx.sparkle))
		s.LightEmission = 1
		s.Rate = 6
		s.Lifetime = E.NumberRange.new(0.4, 0.8)
		s.Speed = E.NumberRange.new(0.5, 1.2)
		s.Size = E.NumberSequence.new(0.15, 0)
		s.SpreadAngle = E.Vector2.new(180, 180)
		s.Parent = grip
	end
	if spec.fx.fire then
		local f = E.Instance.new("ParticleEmitter")
		f.Name = "Embers"
		f.Color = E.ColorSequence.new(E.Color3.fromHex(spec.fx.fire), E.Color3.fromHex("#FFE08A"))
		f.LightEmission = 1
		f.Rate = 10
		f.Lifetime = E.NumberRange.new(0.3, 0.7)
		f.Speed = E.NumberRange.new(1, 2)
		f.Size = E.NumberSequence.new(0.12, 0)
		f.Parent = m:FindFirstChild("EmberCore") or grip
	end
	return m
end

-- How the grip sits in the right hand for each slot (hand frame: -Y runs down the fingers).
function Arms.gripOffset(E, slot: string)
	if slot == "knife" then
		return E.CFrame.new(0, -0.25, -0.1) * E.CFrame.Angles(math.rad(-90), 0, 0)
	elseif slot == "spear" then
		return E.CFrame.new(0, -0.2, 0) * E.CFrame.Angles(math.rad(-90), 0, 0)
	end
	return E.CFrame.new(0, -0.2, 0) * E.CFrame.Angles(0, math.rad(90), 0)
end

-- Builds and welds a held weapon to a character's right hand. Returns the model.
function Arms.attach(E, character, slot: string, skinId: string?, mastery: number?): any
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand then
		return nil
	end
	local old = character:FindFirstChild("Held")
	if old then
		old:Destroy()
	end
	local spec = Arms.spec(slot, skinId, mastery)
	local m = Arms.build(E, spec, hand.CFrame * Arms.gripOffset(E, slot))
	local w = E.Instance.new("WeldConstraint")
	w.Part0 = hand
	w.Part1 = m.PrimaryPart
	w.Parent = m.PrimaryPart
	m.Parent = character
	return m
end

return Arms

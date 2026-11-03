--!nocheck
--[[
	MapBuilder — builds the whole world out of plain Parts (no uploaded assets needed):
	  * the 2400-stud arena: the golden Sundial hub (no horn of plenty), 48 lift plates, the
	    Gilded Meadow, Mirror Lake, Whisperwood, Ashen Ridge, Old Glassford ruins, scattered crates,
	    24 token spots and the Veil dome;
	  * the Viewing Gallery lounge floating above the hub;
	  * the lobby: the Reach square with the Harvesting stage, glass globe, jumbotron, Herald,
	    Rusty, camera marks for the reaping cutscene, the Draw Gate queue, boards and a range.
	It only uses Instance.new + datatypes passed in through `env`, so it runs both in Roblox (the
	server builds the map at startup if Workspace.Map is missing) and in Lune (scripts/bake-map
	bakes it into DaybreakOnTheHarvesting.rbxlx so it shows in Studio edit mode and in renders).
]]
local MapBuilder = {}

local E -- env (Roblox globals)

function MapBuilder.setEnv(env)
	E = env
end

local function hex(h)
	return E.Color3.fromHex(h)
end

local function part(parent, name, size, cf, color, material, props)
	local p = E.Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = hex(color)
	p.Material = material or E.Enum.Material.SmoothPlastic
	p.TopSurface = E.Enum.SurfaceType.Smooth
	p.BottomSurface = E.Enum.SurfaceType.Smooth
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end
MapBuilder.part = part

local function model(parent, name)
	local m = E.Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function folder(parent, name)
	local f = E.Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function V(x, y, z)
	return E.Vector3.new(x, y, z)
end

local function lookAt(a, b)
	if E.CFrame.lookAt then
		return E.CFrame.lookAt(a, b)
	end
	return E.CFrame.new(a, b)
end

local function cyl(parent, name, length, diameter, cf, color, material, props)
	-- Roblox cylinders run along X. `cf` is the center.
	local p = part(parent, name, V(length, diameter, diameter), cf, color, material, props)
	p.Shape = E.Enum.PartType.Cylinder
	return p
end

local function _ball(parent, name, d, cf, color, material, props)
	local p = part(parent, name, V(d, d, d), cf, color, material, props)
	p.Shape = E.Enum.PartType.Ball
	return p
end

local function prompt(parent, kind, action, object, hold, dist, extra)
	local pp = E.Instance.new("ProximityPrompt")
	pp.Name = "Prompt"
	pp.ActionText = action
	pp.ObjectText = object or ""
	pp.HoldDuration = hold or 0
	pp.MaxActivationDistance = dist or 10
	pp.RequiresLineOfSight = false
	pp:SetAttribute("Kind", kind)
	if extra then
		for k, v in pairs(extra) do
			pp[k] = v
		end
	end
	pp.Parent = parent
	return pp
end
MapBuilder.prompt = prompt

local function surfaceText(p, face, text, textColor, bg, font)
	local sg = E.Instance.new("SurfaceGui")
	sg.Name = "SignGui"
	sg.Face = face or E.Enum.NormalId.Front
	sg.SizingMode = E.Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.Parent = p
	local tl = E.Instance.new("TextLabel")
	tl.Name = "Text"
	tl.Size = E.UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = bg and 0 or 1
	if bg then
		tl.BackgroundColor3 = hex(bg)
	end
	tl.TextColor3 = hex(textColor or "#FFFFFF")
	tl.Font = font or E.Enum.Font.FredokaOne
	tl.TextScaled = true
	tl.Text = text
	tl.Parent = sg
	return tl
end
MapBuilder.surfaceText = surfaceText

-- `studs` (optional {w, h}) sizes the label in world studs instead of pixels, so labels on
-- closely spaced things (smoker row, grill spots, customer tables) shrink with distance
-- instead of piling on top of each other.
local function billboard(adornee, name, text, offsetY, maxDist, color, w, h, studs: { number }?)
	local b = E.Instance.new("BillboardGui")
	b.Name = name
	if studs then
		b.Size = E.UDim2.new(studs[1], 0, studs[2], 0)
	else
		b.Size = E.UDim2.new(0, w or 160, 0, h or 40)
	end
	b.StudsOffset = V(0, offsetY or 3, 0)
	b.AlwaysOnTop = false
	b.MaxDistance = maxDist or 80
	b.LightInfluence = 0
	b.Parent = adornee
	local tl = E.Instance.new("TextLabel")
	tl.Name = "Text"
	tl.Size = E.UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.TextColor3 = hex(color or "#FFFFFF")
	tl.TextStrokeTransparency = 0.3
	tl.Font = E.Enum.Font.FredokaOne
	tl.TextScaled = true
	tl.Text = text
	tl.Parent = b
	return b
end
MapBuilder.billboard = billboard

-- Decorative parts: no collision, query or touch (shadow is opt-in).
local function deco(parent, name, size, cf, color, material, shadow)
	return part(parent, name, size, cf, color, material, { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = shadow == true })
end
local function dball(parent, name, d, cf, color, material, shadow)
	local p = deco(parent, name, V(d, d, d), cf, color, material, shadow)
	p.Shape = E.Enum.PartType.Ball
	return p
end
local function _dcyl(parent, name, length, diameter, cf, color, material, shadow)
	local p = deco(parent, name, V(length, diameter, diameter), cf, color, material, shadow)
	p.Shape = E.Enum.PartType.Cylinder
	return p
end

local function _upright()
	return E.CFrame.Angles(0, 0, math.pi / 2) -- turns an X-axis cylinder upright
end

-- Ellipsoid part (a Part with a Sphere SpecialMesh) for soft, round shapes.
local function sph(parent, name, size, cf, color, material, props)
	local p = part(parent, name, size, cf, color, material, props)
	local mesh = E.Instance.new("SpecialMesh")
	mesh.MeshType = E.Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- A round, chibi-proportioned NPC: a big head, a soft pear-shaped body, mitten hands, and
-- shiny eyes with rosy cheeks. Feet at `cf`, facing -Z. Part names Head and Torso are what
-- the game looks up (prompts and name tags hang off them).
-- Options: skin, shirt, pants, shoes, hair, hat ("cowboy" | "cap" | "bun"), hatColor, apron,
-- apronText, glasses, mustache, beard, belly, brows, label, labelColor, scale.
function MapBuilder.npc(parent, name, cf, o)
	o = o or {}
	local m = model(parent, name)
	local skin = o.skin or "#E0AC69"
	local shirt = o.shirt or "#4A6FA5"
	local pants = o.pants or "#3B3B3B"
	local shoes = o.shoes or "#3A2A1E"
	local dark = "#2A1E1A"
	local s = o.scale or 1
	local function at(x, y, z, rx, ry, rz)
		return cf * E.CFrame.new(x * s, y * s, z * s) * E.CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
	end
	local function e(n, sx, sy, sz, c, x, y, z, rx, ry, rz, mat)
		return sph(m, n, V(sx * s, sy * s, sz * s), at(x, y, z, rx, ry, rz), c, mat)
	end
	-- legs and shoes
	local legL = cyl(m, "LeftLeg", 1.3 * s, 0.8 * s, at(-0.45, 1.0, 0) * E.CFrame.Angles(0, 0, math.pi / 2), pants)
	local legR = cyl(m, "RightLeg", 1.3 * s, 0.8 * s, at(0.45, 1.0, 0) * E.CFrame.Angles(0, 0, math.pi / 2), pants)
	if o.sandals then
		-- socks with sandals: white socks on a brown sole with a strap
		for _, side in { -1, 1 } do
			e("Sock", 0.85, 0.75, 1.2, "#F7F7F2", side * 0.47, 0.42, -0.12)
			e("Sole", 1.0, 0.22, 1.45, "#7A4A2A", side * 0.47, 0.1, -0.15)
			deco(m, "Strap", V(0.9 * s, 0.16 * s, 0.25 * s), at(side * 0.47, 0.55, -0.55), "#7A4A2A", E.Enum.Material.SmoothPlastic, false)
		end
	else
		e("ShoeL", 0.95, 0.6, 1.35, shoes, -0.47, 0.3, -0.15)
		e("ShoeR", 0.95, 0.6, 1.35, shoes, 0.47, 0.3, -0.15)
	end
	-- body: hips + a soft torso (rounder for a belly)
	e("Hips", 2.0, 1.1, 1.6, pants, 0, 1.75, 0)
	if o.buckle then
		e("Belt", 2.05, 0.3, 1.65, "#3A2414", 0, 2.05, 0)
		e("Buckle", 0.6, 0.42, 0.2, o.buckle, 0, 2.05, -0.82, 0, 0, 0, E.Enum.Material.Foil)
	end
	local bw, bd = o.belly and 2.6 or 2.2, o.belly and 2.3 or 1.75
	local torso = sph(m, "Torso", V(bw * s, 2.5 * s, bd * s), at(0, 2.75, 0), shirt)
	if o.apron then
		-- a soft bib that hugs the front of the torso, with a flat name patch on it
		e("ApronBib", bw * 0.78, 2.3, bd * 1.0, o.apron, 0, 2.6, -bd * 0.12, 0, 0, 0)
		local ap = part(m, "Apron", V(1.25 * s, 0.6 * s, 0.05 * s), at(0, 2.55, -bd * 0.62 - 0.01), o.apron, E.Enum.Material.Fabric)
		ap.CanCollide = false
		if o.apronText then
			surfaceText(ap, E.Enum.NormalId.Front, o.apronText, "#FFFFFF", nil)
		end
	end
	-- arms: sleeves angled out a little, mitten hands
	for _, side in { -1, 1 } do
		local ax = side * (bw / 2 + 0.2)
		e(side < 0 and "LeftArm" or "RightArm", 0.75, 1.7, 0.75, shirt, ax, 2.85, 0, 0, 0, side * 16)
		e(side < 0 and "HandL" or "HandR", 0.7, 0.7, 0.7, skin, ax + side * 0.25, 1.95, -0.05)
	end
	-- head: a big round face
	local head = sph(m, "Head", V(2.5 * s, 2.4 * s, 2.35 * s), at(0, 4.85, 0), skin)
	e("EarL", 0.38, 0.6, 0.35, skin, -1.24, 4.85, 0.05)
	e("EarR", 0.38, 0.6, 0.35, skin, 1.24, 4.85, 0.05)
	for _, side in { -1, 1 } do
		e(side < 0 and "EyeL" or "EyeR", 0.34, 0.5, 0.2, dark, side * 0.45, 5.0, -1.08)
		e(side < 0 and "ShineL" or "ShineR", 0.13, 0.13, 0.08, "#FFFFFF", side * 0.45 - 0.07, 5.12, -1.18, 0, 0, 0, E.Enum.Material.Neon)
		e(side < 0 and "CheekL" or "CheekR", 0.5, 0.3, 0.12, "#F28B82", side * 0.78, 4.6, -0.98)
		if o.brows ~= false then
			deco(m, "Brow", V(0.5 * s, 0.12 * s, 0.1 * s), at(side * 0.45, 5.42, -1.06, 0, 0, side * -8), o.hair or dark, E.Enum.Material.SmoothPlastic, false)
		end
	end
	e("Nose", 0.4, 0.34, 0.3, skin, 0, 4.68, -1.18)
	if o.mustache then
		e("Mustache", 1.25, 0.36, 0.4, o.mustache, 0, 4.42, -1.12)
		e("Smile", 0.5, 0.16, 0.12, "#7A2E2E", 0, 4.18, -1.13)
	else
		e("Smile", 0.66, 0.2, 0.12, "#7A2E2E", 0, 4.32, -1.14)
	end
	if o.beard then
		e("Beard", 1.7, 0.9, 1.0, o.beard, 0, 3.9, -0.75)
	end
	if o.glasses then
		for _, side in { -1, 1 } do
			local lens = cyl(m, "Glasses", 0.08 * s, 0.75 * s, at(side * 0.45, 5.0, -1.2) * E.CFrame.Angles(0, math.pi / 2, 0), "#BFE3FF", E.Enum.Material.Glass, { Transparency = 0.55 })
			lens.CanCollide = false
			deco(m, "GlassesRim", V(0.8 * s, 0.08 * s, 0.06 * s), at(side * 0.45, 5.38, -1.2), "#3A2A1E", E.Enum.Material.SmoothPlastic, false)
		end
		deco(m, "GlassesBridge", V(0.2 * s, 0.07 * s, 0.06 * s), at(0, 5.1, -1.22), "#3A2A1E", E.Enum.Material.SmoothPlastic, false)
	end
	-- hair and hats
	if o.hair and o.hat ~= "cowboy" then
		e("Hair", 2.6, 1.35, 2.5, o.hair, 0, 5.55, 0.12)
	end
	if o.hat == "cowboy" then
		local hc = o.hatColor or "#3B2A1A"
		cyl(m, "HatBrim", 0.18 * s, 4.3 * s, at(0, 5.75, 0) * E.CFrame.Angles(0, 0, math.pi / 2), hc)
		e("HatBrimCurlL", 0.9, 0.5, 3.6, hc, -1.85, 5.95, 0)
		e("HatBrimCurlR", 0.9, 0.5, 3.6, hc, 1.85, 5.95, 0)
		e("HatCrown", 2.3, 1.6, 2.1, hc, 0, 6.4, 0)
		cyl(m, "HatBand", 0.3 * s, 2.32 * s, at(0, 6.0, 0) * E.CFrame.Angles(0, 0, math.pi / 2), o.hatBand or "#8B5A2B")
	elseif o.hat == "cap" then
		local hc = o.hatColor or "#B22222"
		e("Cap", 2.6, 1.5, 2.5, hc, 0, 5.6, 0.05)
		e("Bill", 1.8, 0.2, 1.3, hc, 0, 5.4, -1.2)
		e("CapButton", 0.3, 0.2, 0.3, "#FFFFFF", 0, 6.33, 0.05)
	elseif o.hat == "bun" then
		e("Hair", 2.6, 1.35, 2.5, o.hatColor or "#DDDDDD", 0, 5.55, 0.12)
		e("Bun", 1.15, 1.05, 1.15, o.hatColor or "#DDDDDD", 0, 6.25, 0.45)
		if o.pearls then
			for k = -2, 2 do
				dball(m, "Pearl", 0.22 * s, at(k * 0.32, 3.95 - math.abs(k) * 0.05, -0.82 + math.abs(k) * 0.08), "#FFF8E7", E.Enum.Material.SmoothPlastic, false)
			end
		end
	end
	for _, c in ipairs(m:GetDescendants()) do
		if c:IsA("BasePart") then
			c.CanCollide = c == torso or c == legL or c == legR
		end
	end
	m.PrimaryPart = torso
	if o.label then
		billboard(head, "NameTag", o.label, 2.8, 60, o.labelColor or "#FFE9A8", 200, 36)
	end
	return m, head, torso
end

-- ===================== palette (from the plan's "Color & Look") =====================
local PAL = {
	marble = "#E9E4DA",
	gold = "#D4A72C",
	goldHi = "#F2CF63",
	slate = "#4A505C",
	soot = "#2B2D33",
	haze = "#F7B27A",
	meadow = "#3FBF5A",
	meadowDeep = "#2F9447",
	bloom = "#FF4FB8",
	finch = "#FF8AD8",
	lake = "#49C6E5",
	wood = "#2E5A3A",
	woodDark = "#244A2F",
	veil = "#7FF3FF",
	field = { "#5F8A45", "#6A9450", "#58803F" },
	fieldDusk = "#4F7440",
	ridge = { "#5A5C63", "#4A505C", "#666870" },
	sand = "#C9B88E",
	trunk = "#4A3426",
	brick = { "#5A4A44", "#4E4A52", "#625750" },
	window = "#FFC870",
	rustyHair = "#B89A5E",
	rustyRoots = "#7E6740",
	rustyShirt = "#C9A13B",
	rustyPlaid = "#2F7F86",
	rustyPants = "#5C5A52",
	thermos = "#3E8E5E",
}
MapBuilder.PALETTE = PAL

local seed = 20261102
local function rnd()
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end
local function rr(a, b)
	return a + (b - a) * rnd()
end
local function pick(t)
	return t[1 + math.floor(rnd() * #t) % #t]
end
local function at(pos)
	return E.CFrame.new(pos)
end
local function yaw(r)
	return E.CFrame.Angles(0, r, 0)
end
local function disc(parent, name, d, thick, pos, color, material, props)
	-- upright cylinder (a flat disc) centered at pos
	return cyl(parent, name, thick, d, at(pos) * E.CFrame.Angles(0, 0, math.pi / 2), color, material, props)
end
local function mark(parent, name, cf)
	return part(parent, name, V(1, 1, 1), cf, "#FFFFFF", E.Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
end
local function inCircle(x, z, c)
	local dx, dz = x - c.x, z - c.z
	return dx * dx + dz * dz < c.r * c.r
end

-- Which biome is at (x, z)? Used for ground color, scatter and token zones.
function MapBuilder.biomeAt(x, z, cfg)
	local M = cfg.Map
	if math.sqrt(x * x + z * z) < 140 then
		return "hub"
	elseif inCircle(x, z, M.LAKE) then
		return "lake"
	elseif inCircle(x, z, M.MEADOW) then
		return "meadow"
	elseif z < -720 then
		return "ridge"
	elseif inCircle(x, z, M.RUINS) then
		return "ruins"
	elseif x < -300 then
		return "wood"
	end
	return "field"
end

-- ===================== props =====================
local function pine(parent, pos, s)
	local m = model(parent, "Pine")
	deco(m, "Trunk", V(1.6 * s, 10 * s, 1.6 * s), at(pos + V(0, 5 * s, 0)), PAL.trunk, E.Enum.Material.Wood, false)
	local c = pick({ PAL.wood, PAL.woodDark, "#35663F" })
	sph(m, "Needles1", V(11 * s, 9 * s, 11 * s), at(pos + V(0, 10 * s, 0)), c, E.Enum.Material.Grass, { CanCollide = false, CanQuery = false, CastShadow = true })
	sph(m, "Needles2", V(8 * s, 8 * s, 8 * s), at(pos + V(0, 16 * s, 0)), c, E.Enum.Material.Grass, { CanCollide = false, CanQuery = false, CastShadow = true })
	sph(m, "Needles3", V(4.5 * s, 6 * s, 4.5 * s), at(pos + V(0, 21 * s, 0)), c, E.Enum.Material.Grass, { CanCollide = false, CanQuery = false, CastShadow = false })
	part(m, "Hitbox", V(2 * s, 12 * s, 2 * s), at(pos + V(0, 6 * s, 0)), PAL.trunk, E.Enum.Material.Wood, { Transparency = 1, CastShadow = false })
	return m
end

local function broadleaf(parent, pos, s)
	local m = model(parent, "Tree")
	deco(m, "Trunk", V(2 * s, 9 * s, 2 * s), at(pos + V(0, 4.5 * s, 0)), PAL.trunk, E.Enum.Material.Wood, false)
	local c = pick({ "#4F7D3C", "#5E8A44", "#6E8F3A", "#8A8A3A" })
	dball(m, "Canopy", 12 * s, at(pos + V(0, 11 * s, 0)), c, E.Enum.Material.Grass, true)
	dball(m, "Canopy2", 8 * s, at(pos + V(4 * s, 9.5 * s, 2 * s)), c, E.Enum.Material.Grass, false)
	part(m, "Hitbox", V(2.2 * s, 9 * s, 2.2 * s), at(pos + V(0, 4.5 * s, 0)), PAL.trunk, E.Enum.Material.Wood, { Transparency = 1, CastShadow = false })
	return m
end

local function rock(parent, pos, s, color)
	local p = sph(parent, "Rock", V(rr(6, 10) * s, rr(4, 7) * s, rr(6, 10) * s), at(pos + V(0, 1.5 * s, 0)) * yaw(rr(0, 6.28)), color or pick(PAL.ridge), E.Enum.Material.Slate)
	return p
end

local function crate(parent, name, pos, loot, rot)
	local c = part(parent, name, V(4, 3, 3), at(pos + V(0, 1.5, 0)) * yaw(rot or 0), loot == "hub" and "#8A6A3A" or "#6E5236", E.Enum.Material.Wood)
	c:SetAttribute("Loot", loot)
	c:SetAttribute("Crate", true)
	deco(c, "Band", V(4.1, 0.5, 3.1), c.CFrame, loot == "meadow" and PAL.bloom or PAL.gold, E.Enum.Material.Metal, false)
	deco(c, "Band2", V(0.5, 3.1, 3.1), c.CFrame, loot == "meadow" and PAL.bloom or PAL.gold, E.Enum.Material.Metal, false)
	local band = c:FindFirstChild("Band")
	if band then
		band.Parent = parent
		band.Name = name .. "_Band"
	end
	local band2 = c:FindFirstChild("Band2")
	if band2 then
		band2.Parent = parent
		band2.Name = name .. "_Band2"
	end
	prompt(c, "crate", "Open", "Crate", 0.6, 9)
	return c
end

local function townsperson(parent, cf, colors)
	-- a simple low-detail figure for the lobby crowd
	local m = model(parent, "Townsperson")
	local s = rr(0.9, 1.08)
	local function a(x, y, z)
		return cf * E.CFrame.new(x * s, y * s, z * s)
	end
	sph(m, "Legs", V(1.6 * s, 2.2 * s, 1.2 * s), a(0, 1.1, 0), colors[2], E.Enum.Material.Fabric, { CanCollide = false })
	sph(m, "Body", V(2.2 * s, 2.6 * s, 1.6 * s), a(0, 3.0, 0), colors[1], E.Enum.Material.Fabric, { CanCollide = false })
	sph(m, "Head", V(1.7 * s, 1.8 * s, 1.7 * s), a(0, 4.9, 0), colors[3], E.Enum.Material.SmoothPlastic, { CanCollide = false })
	sph(m, "Hair", V(1.8 * s, 0.9 * s, 1.8 * s), a(0, 5.5, 0.1), colors[4], E.Enum.Material.SmoothPlastic, { CanCollide = false })
	return m
end

-- Rusty Dunmore: the scruffy, kind mentor. Built on the shared NPC body with his own details.
function MapBuilder.rusty(env, parent, cf, label)
	if env then
		E = env
	end
	local m, head, torso = MapBuilder.npc(parent, "Rusty", cf, {
		skin = "#D9A877",
		shirt = PAL.rustyShirt,
		pants = PAL.rustyPants,
		shoes = "#3A2E26",
		hair = PAL.rustyHair,
		beard = PAL.rustyRoots,
		brows = true,
		label = label,
		labelColor = "#F2CF63",
	})
	local function a(x, y, z)
		return cf * E.CFrame.new(x, y, z)
	end
	-- messy hair tufts with darker roots
	for i = 1, 5 do
		local ang = (i - 3) * 0.45
		sph(m, "Tuft", V(1.1, 0.9, 1.0), a(math.sin(ang) * 1.1, 6.05 + (i % 2) * 0.2, 0.2 + math.cos(ang) * 0.3) * E.CFrame.Angles(0, 0, ang), i % 2 == 0 and PAL.rustyRoots or PAL.rustyHair, E.Enum.Material.SmoothPlastic, { CanCollide = false })
	end
	-- open plaid overshirt panels
	for _, side in { -1, 1 } do
		sph(m, "Plaid", V(0.9, 2.4, 1.85), a(side * 0.85, 2.75, -0.05), PAL.rustyPlaid, E.Enum.Material.Fabric, { CanCollide = false })
	end
	-- the green thermos in his right hand
	local th = cyl(m, "Thermos", 1.3, 0.6, a(1.6, 2.1, -0.3) * E.CFrame.Angles(0, 0, math.pi / 2), PAL.thermos, E.Enum.Material.Metal, { CanCollide = false })
	cyl(m, "ThermosCap", 0.3, 0.64, a(1.6, 2.85, -0.3) * E.CFrame.Angles(0, 0, math.pi / 2), "#2A2A2A", E.Enum.Material.Metal, { CanCollide = false })
	return m, head, torso, th
end

-- ===================== arena =====================
local function buildGround(root, cfg)
	local g = folder(root, "Ground")
	local half = cfg.Map.ARENA_SIZE / 2
	local tile = 300
	for i = 0, cfg.Map.ARENA_SIZE / tile - 1 do
		for j = 0, cfg.Map.ARENA_SIZE / tile - 1 do
			local x = -half + tile * (i + 0.5)
			local z = -half + tile * (j + 0.5)
			local b = MapBuilder.biomeAt(x, z, cfg)
			local color = pick(PAL.field)
			local mat = E.Enum.Material.Grass
			if b == "ridge" then
				color, mat = "#5E5F58", E.Enum.Material.Ground
			elseif b == "wood" then
				color = "#3F6436"
			elseif b == "ruins" then
				color, mat = "#7A7562", E.Enum.Material.Ground
			end
			part(g, "Tile", V(tile, 16, tile), at(V(x, -8, z)), color, mat)
		end
	end
	-- outer skirt (outside the Veil) and distant hills to frame the sky
	for i = -3, 2 do
		for j = -3, 2 do
			local x, z = 600 * (i + 0.5), 600 * (j + 0.5)
			if math.abs(x) > half or math.abs(z) > half then
				part(g, "Skirt", V(600, 16, 600), at(V(x, -8.5, z)), PAL.fieldDusk, E.Enum.Material.Grass)
			end
		end
	end
	for k = 1, 28 do
		local a = k / 28 * math.pi * 2 + rr(-0.05, 0.05)
		local r = rr(1550, 1750)
		local s = rr(260, 520)
		local color = a > math.pi * 1.1 and a < math.pi * 1.9 and "#575960" or pick({ "#3E5E3A", "#4A6A3E", "#3A5236" })
		sph(g, "Hill", V(s * 1.6, s * 0.7, s), at(V(math.cos(a) * r, -s * 0.12, math.sin(a) * r)) * yaw(-a), color, E.Enum.Material.Grass, { CanCollide = false, CastShadow = false })
	end
end

local function buildHub(root, cfg, names)
	local h = folder(root, "Sundial")
	local R = cfg.Map.HUB_RADIUS
	disc(h, "Apron", R * 2 + 40, 1, V(0, 0.5, 0), "#BFB8A8", E.Enum.Material.Pavement)
	disc(h, "Base", R * 2, 2, V(0, 1.5, 0), PAL.marble, E.Enum.Material.Marble)
	disc(h, "GoldRing", R * 2 - 6, 2.4, V(0, 1.7, 0), PAL.gold, E.Enum.Material.Foil)
	disc(h, "Face", R * 2 - 10, 2.6, V(0, 1.8, 0), PAL.marble, E.Enum.Material.Marble)
	disc(h, "Inlay", 30, 2.8, V(0, 1.9, 0), PAL.goldHi, E.Enum.Material.Foil)
	-- 12 hour marks
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		local r = R - 9
		part(h, "HourMark", V(2, 0.6, 7), at(V(math.cos(a) * r, 3.2, math.sin(a) * r)) * yaw(-a + math.pi / 2), PAL.gold, E.Enum.Material.Foil, { CanCollide = false })
	end
	-- the gnomon: a tall golden blade casting the hub's shadow
	local gnomon = part(h, "Gnomon", V(3, 46, 26), at(V(0, 20, 6)) * E.CFrame.Angles(math.rad(-28), 0, 0), PAL.gold, E.Enum.Material.Foil)
	local light = E.Instance.new("PointLight")
	light.Color = E.Color3.fromHex("#FFD36B")
	light.Brightness = 3
	light.Range = 60
	light.Parent = gnomon
	part(h, "GnomonCap", V(4, 3, 4), at(V(0, 41, -4)), PAL.goldHi, E.Enum.Material.Neon, { CanCollide = false })
	billboard(gnomon, "Label", names.HUB:gsub("^the ", "The "), 30, 900, "#FFE9A8", 220, 40)
	-- crate rings around the dial
	local crates = folder(root, "HubCrates")
	for i = 1, cfg.HUB_CRATES do
		local ring = (i % 3)
		local r = 16 + ring * 9 + (ring == 2 and 4 or 0)
		local a = i / cfg.HUB_CRATES * math.pi * 2 + ring * 0.2
		crate(crates, "HubCrate" .. i, V(math.cos(a) * r, 3.1, math.sin(a) * r), "hub", -a)
	end
	-- 48 lift plates
	local plates = folder(root, "LiftPlates")
	for i = 1, cfg.MATCH_SIZE do
		local a = (i - 1) / cfg.MATCH_SIZE * math.pi * 2
		local pos = V(math.cos(a) * cfg.Map.PLATE_RADIUS, 0, math.sin(a) * cfg.Map.PLATE_RADIUS)
		local p = disc(plates, string.format("Plate%02d", i), 8, 1.2, pos + V(0, 0.6, 0), "#8E949E", E.Enum.Material.DiamondPlate)
		p:SetAttribute("Index", i)
		disc(plates, string.format("Plate%02d_Ring", i), 9, 0.9, pos + V(0, 0.5, 0), PAL.veil, E.Enum.Material.Neon, { CanCollide = false, CanQuery = false })
	end
end

local function buildMeadow(root, cfg)
	local m = folder(root, "GildedMeadow")
	local M = cfg.Map.MEADOW
	disc(m, "Meadow", M.r * 2, 0.4, V(M.x, 0.2, M.z), PAL.meadow, E.Enum.Material.Grass, { CanCollide = false })
	disc(m, "MeadowInner", M.r * 1.3, 0.5, V(M.x, 0.25, M.z), "#4ACB63", E.Enum.Material.Grass, { CanCollide = false })
	local zone = disc(m, "MeadowZone", M.r * 2, 60, V(M.x, 30, M.z), PAL.bloom, E.Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	zone:SetAttribute("Zone", "meadow")
	local flowers = model(m, "Flowers")
	for _ = 1, 360 do
		local a, d = rr(0, math.pi * 2), math.sqrt(rnd()) * (M.r - 8)
		local x, z = M.x + math.cos(a) * d, M.z + math.sin(a) * d
		local h = rr(1.2, 2.6)
		deco(flowers, "Stem", V(0.25, h, 0.25), at(V(x, h / 2, z)), "#2F8A3E", E.Enum.Material.Grass, false)
		local c = rnd() < 0.55 and PAL.goldHi or (rnd() < 0.6 and PAL.bloom or "#FFFFFF")
		dball(flowers, "Bloom", rr(0.9, 1.6), at(V(x, h + 0.3, z)), c, rnd() < 0.3 and E.Enum.Material.Neon or E.Enum.Material.SmoothPlastic, false)
	end
	-- golden pollen emitters (off until a Meadow Bloom)
	for k = 1, 7 do
		local a = k / 7 * math.pi * 2
		local p = mark(m, "PollenEmitter", at(V(M.x + math.cos(a) * M.r * 0.55, 4, M.z + math.sin(a) * M.r * 0.55)))
		p.Size = V(M.r * 0.7, 2, M.r * 0.7)
		local pe = E.Instance.new("ParticleEmitter")
		pe.Name = "Pollen"
		pe.Enabled = false
		pe.Rate = 60
		pe.Lifetime = E.NumberRange.new(4, 7)
		pe.Speed = E.NumberRange.new(1, 3)
		pe.SpreadAngle = E.Vector2.new(180, 180)
		pe.LightEmission = 0.8
		pe.Color = E.ColorSequence.new(E.Color3.fromHex("#FFD36B"), E.Color3.fromHex("#FF4FB8"))
		pe.Size = E.NumberSequence.new(0.6)
		pe.Parent = p
	end
	local crates = folder(root, "MeadowCrates")
	for i = 1, cfg.MEADOW_CRATES do
		local a = i / cfg.MEADOW_CRATES * math.pi * 2
		local d = M.r * (i % 2 == 0 and 0.35 or 0.7)
		crate(crates, "MeadowCrate" .. i, V(M.x + math.cos(a) * d, 0.4, M.z + math.sin(a) * d), "meadow", a)
	end
end

local function buildLake(root, cfg)
	local l = folder(root, "MirrorLake")
	local L = cfg.Map.LAKE
	disc(l, "Shore", L.r * 2 + 40, 0.6, V(L.x, 0.3, L.z), PAL.sand, E.Enum.Material.Sand, { CanCollide = false })
	disc(l, "Bed", L.r * 2, 0.7, V(L.x, 0.35, L.z), "#2D6F7E", E.Enum.Material.Slate, { CanCollide = false })
	local w = disc(l, "Water", L.r * 2 - 4, 1.2, V(L.x, 0.6, L.z), PAL.lake, E.Enum.Material.Glass, { Transparency = 0.18, Reflectance = 0.35, CanCollide = false })
	w:SetAttribute("Zone", "lake")
	-- a small island with a reed bed and a token spot
	disc(l, "Island", 46, 2.2, V(L.x + 40, 1.1, L.z - 30), PAL.sand, E.Enum.Material.Sand)
	broadleaf(l, V(L.x + 40, 2.2, L.z - 30), 1.2)
	for _ = 1, 50 do
		local a = rr(0, math.pi * 2)
		local d = L.r + rr(-6, 14)
		deco(l, "Reed", V(0.4, rr(3, 6), 0.4), at(V(L.x + math.cos(a) * d, 2, L.z + math.sin(a) * d)) * E.CFrame.Angles(rr(-0.2, 0.2), 0, rr(-0.2, 0.2)), "#6E8A3A", E.Enum.Material.Grass, false)
	end
end

local function buildWood(root, cfg)
	local w = folder(root, "Whisperwood")
	local n = 0
	local tries = 0
	while n < 300 and tries < 3000 do
		tries += 1
		local x, z = rr(-1180, -320), rr(-700, 1180)
		if MapBuilder.biomeAt(x, z, cfg) == "wood" then
			pine(w, V(x, 0, z), rr(1.3, 2.3))
			n += 1
		end
	end
	for _ = 1, 40 do
		rock(w, V(rr(-1150, -350), 0, rr(-680, 1150)), rr(0.6, 1.2), "#4E5650")
	end
end

local function buildRidge(root, _cfg)
	local r = folder(root, "AshenRidge")
	for _ = 1, 46 do
		local x = rr(-1150, 1150)
		local z = rr(-1180, -760)
		local h = rr(30, 150) * (1 + math.max(0, (-z - 900) / 400))
		local w = rr(60, 150)
		local p = part(r, "Cliff", V(w, h, rr(50, 120)), at(V(x, h / 2 - 4, z)) * yaw(rr(0, 6.28)) * E.CFrame.Angles(rr(-0.08, 0.08), 0, rr(-0.08, 0.08)), pick(PAL.ridge), E.Enum.Material.Slate)
		if rnd() < 0.4 then
			part(r, "Ledge", V(w * 0.6, 6, 30), p.CFrame * E.CFrame.new(0, -h / 4, 40), "#5A5C63", E.Enum.Material.Slate)
		end
	end
	for _ = 1, 40 do
		rock(r, V(rr(-1150, 1150), 0, rr(-760, -640)), rr(0.8, 1.8))
	end
end

local function buildRuins(root, cfg)
	local f = folder(root, "OldGlassford")
	local R = cfg.Map.RUINS
	for b = 1, 7 do
		local a = b / 7 * math.pi * 2
		local cx, cz = R.x + math.cos(a) * R.r * 0.55, R.z + math.sin(a) * R.r * 0.55
		local L, W, H = rr(50, 80), rr(26, 36), rr(16, 24)
		local cf = at(V(cx, 0, cz)) * yaw(rr(0, 3.14))
		local m = model(f, "Greenhouse")
		part(m, "Floor", V(L, 1, W), cf * E.CFrame.new(0, 0.5, 0), "#8F8778", E.Enum.Material.Cobblestone)
		local posts = math.floor(L / 10)
		for i = 0, posts do
			for _, side in { -1, 1 } do
				local broken = rnd() < 0.25
				local hh = broken and H * rr(0.3, 0.7) or H
				part(m, "Post", V(1, hh, 1), cf * E.CFrame.new(-L / 2 + i * L / posts, hh / 2, side * W / 2), "#3A3F44", E.Enum.Material.Metal)
				if not broken and i < posts and rnd() < 0.6 then
					part(m, "Pane", V(L / posts - 1, H - 2, 0.3), cf * E.CFrame.new(-L / 2 + (i + 0.5) * L / posts, H / 2, side * W / 2), "#9FD8C8", E.Enum.Material.Glass, { Transparency = 0.55 })
				end
			end
		end
		if rnd() < 0.6 then
			part(m, "Roof", V(L, 0.6, W), cf * E.CFrame.new(0, H, 0), "#3A3F44", E.Enum.Material.Metal, { Transparency = 0 })
		end
		for _ = 1, 4 do
			deco(m, "Planter", V(rr(4, 8), 2, 3), cf * E.CFrame.new(rr(-L / 3, L / 3), 2, rr(-W / 3, W / 3)), "#6B4A33", E.Enum.Material.Wood, false)
		end
	end
end

local function buildScatter(root, cfg)
	local f = folder(root, "Field")
	for _ = 1, 170 do
		local x, z = rr(-1150, 1150), rr(-700, 1150)
		local b = MapBuilder.biomeAt(x, z, cfg)
		if b == "field" or b == "ruins" then
			if rnd() < 0.7 then
				broadleaf(f, V(x, 0, z), rr(1, 1.8))
			else
				rock(f, V(x, 0, z), rr(0.6, 1.4))
			end
		end
	end
	-- field crates (avoid the lake)
	local crates = folder(root, "FieldCrates")
	local n, tries = 0, 0
	while n < cfg.FIELD_CRATES and tries < 2000 do
		tries += 1
		local x, z = rr(-1120, 1120), rr(-1120, 1120)
		local b = MapBuilder.biomeAt(x, z, cfg)
		if b ~= "lake" and b ~= "hub" and b ~= "meadow" and math.sqrt(x * x + z * z) > 160 then
			n += 1
			crate(crates, "FieldCrate" .. n, V(x, 0, z), "field", rr(0, 6.28))
		end
	end
end

local function buildTokens(root, cfg, content)
	local f = folder(root, "TokenSpots")
	local M = cfg.Map
	local centers = {
		hub = { x = 0, z = 0, r = 30 },
		meadow = M.MEADOW,
		lake = { x = M.LAKE.x, z = M.LAKE.z, r = M.LAKE.r + 20 },
		wood = M.WOOD,
		ridge = { x = M.RIDGE.x, z = M.RIDGE.z, r = 300 },
		ruins = M.RUINS,
		field = { x = 300, z = 300, r = 300 },
	}
	for i, t in ipairs(content.TOKENS) do
		local c = centers[t.zone]
		local a = i * 2.39996
		local d = c.r * (t.zone == "lake" and 1 or rr(0.25, 0.8))
		local p = mark(f, "TokenSpot" .. i, at(V(c.x + math.cos(a) * d, 3, c.z + math.sin(a) * d)))
		p:SetAttribute("TokenIndex", i)
	end
end

local function buildVeil(root, cfg)
	local f = folder(root, "Veil")
	local n = 72
	local r = cfg.Map.ARENA_SIZE / 2
	local w = 2 * math.pi * r / n * 1.04
	for i = 1, n do
		local a = (i - 0.5) / n * math.pi * 2
		local pos = V(math.cos(a) * r, 300, math.sin(a) * r)
		local p = part(f, "Panel" .. i, V(w, 640, 1), lookAt(pos, V(0, 300, 0)), PAL.veil, E.Enum.Material.ForceField, { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Transparency = 0.1 })
		p:SetAttribute("Angle", a)
	end
end

local function buildGallery(root, cfg, names)
	local g = folder(root, "ViewingGallery")
	local c = V(cfg.Map.GALLERY_CENTER[1], cfg.Map.GALLERY_CENTER[2], cfg.Map.GALLERY_CENTER[3])
	disc(g, "Deck", 150, 2, c, PAL.soot, E.Enum.Material.Marble)
	disc(g, "Rim", 156, 1.6, c + V(0, 0.4, 0), PAL.gold, E.Enum.Material.Foil, { CanCollide = false })
	disc(g, "Window", 70, 2.2, c + V(0, 0.1, 0), "#BFEFFF", E.Enum.Material.Glass, { Transparency = 0.6 })
	disc(g, "WindowRing", 74, 2.1, c + V(0, 0.05, 0), PAL.goldHi, E.Enum.Material.Neon, { CanCollide = false })
	local n = 36
	for i = 1, n do
		local a = i / n * math.pi * 2
		local rp = V(math.cos(a) * 74, 0, math.sin(a) * 74)
		part(g, "Rail", V(13, 5, 0.4), lookAt(c + rp + V(0, 3.5, 0), c + V(0, 3.5, 0)), "#D8F6FF", E.Enum.Material.Glass, { Transparency = 0.5 })
		if i % 2 == 0 then
			local sp = V(math.cos(a) * 52, 0, math.sin(a) * 52)
			local seatCf = lookAt(c + sp + V(0, 2, 0), c + V(0, 2, 0))
			local seatColor = i % 6 == 0 and PAL.gold or "#7A2E3A"
			part(g, "Seat", V(4, 1.2, 4), seatCf, seatColor, E.Enum.Material.Fabric)
			part(g, "Back", V(4, 4, 0.8), seatCf * E.CFrame.new(0, 2, 2), seatColor, E.Enum.Material.Fabric)
		end
	end
	-- halo roof
	for i = 1, 24 do
		local a = i / 24 * math.pi * 2
		local p = V(math.cos(a) * 70, 22, math.sin(a) * 70)
		part(g, "Halo", V(19, 1.5, 3), lookAt(c + p, c + V(0, 22, 0)), PAL.goldHi, E.Enum.Material.Neon, { CanCollide = false })
		if i % 4 == 0 then
			part(g, "Pillar", V(1.5, 22, 1.5), at(c + V(math.cos(a) * 72, 11, math.sin(a) * 72)), PAL.marble, E.Enum.Material.Marble)
		end
	end
	local board = part(g, "GiftBoard", V(30, 12, 1), lookAt(c + V(0, 14, -60), c + V(0, 14, 0)), PAL.soot, E.Enum.Material.SmoothPlastic)
	surfaceText(board, E.Enum.NormalId.Front, names.GALLERY:gsub("^the ", "The ") .. "\nSend gifts · Vote hazards · Encore", "#F4EFE6", "#23283A")
	local sp = E.Instance.new("SpawnLocation")
	sp.Name = "GallerySpawn"
	sp.Anchored = true
	sp.Enabled = false
	sp.Size = V(8, 1, 8)
	sp.CFrame = at(c + V(0, 1.6, 50))
	sp.Transparency = 1
	sp.CanCollide = false
	sp.Neutral = true
	sp.Parent = g
end

-- ===================== lobby: the Reach square and the Harvesting stage =====================
local function buildLobby(root, cfg, names, _content)
	local L = V(cfg.Map.LOBBY_CENTER[1], cfg.Map.LOBBY_CENTER[2], cfg.Map.LOBBY_CENTER[3])
	local lb = folder(root, "Lobby")
	local function P(x, y, z)
		return L + V(x, y, z)
	end
	part(lb, "Plaza", V(360, 4, 360), at(P(0, -2, 0)), "#5B5A5C", E.Enum.Material.Cobblestone)
	part(lb, "Aisle", V(10, 4.05, 120), at(P(0, -2, -10)), "#7A7066", E.Enum.Material.Brick)
	-- Reach buildings around the square (soot and slate, warm windows)
	for side = 1, 4 do
		for k = -3, 3 do
			local w, h = rr(30, 44), rr(34, 70)
			local off = k * 46
			local pos, rot
			if side == 1 then
				pos, rot = P(off, h / 2, -200), 0
			elseif side == 2 then
				pos, rot = P(off, h / 2, 200), math.pi
			elseif side == 3 then
				pos, rot = P(-200, h / 2, off), math.pi / 2
			else
				pos, rot = P(200, h / 2, off), -math.pi / 2
			end
			if not (side == 2 and math.abs(k) <= 1) then
				local cf = at(pos) * yaw(rot)
				local b = part(lb, "Building", V(w, h, 30), cf, pick(PAL.brick), E.Enum.Material.Brick)
				part(lb, "Roof", V(w + 2, 3, 32), cf * E.CFrame.new(0, h / 2 + 1.5, 0), PAL.soot, E.Enum.Material.Slate)
				for wy = 1, math.floor(h / 12) do
					for wx = -1, 1 do
						if rnd() < 0.75 then
							deco(lb, "Window", V(4, 5, 0.4), b.CFrame * E.CFrame.new(wx * w / 3.2, -h / 2 + wy * 11, 15.1), rnd() < 0.6 and PAL.window or "#3A3F4A", rnd() < 0.6 and E.Enum.Material.Neon or E.Enum.Material.Glass, false)
						end
					end
				end
				if rnd() < 0.5 then
					deco(lb, "Banner", V(8, 18, 0.4), b.CFrame * E.CFrame.new(0, h / 2 - 12, 15.4), PAL.gold, E.Enum.Material.Fabric, false)
				end
			end
		end
	end
	-- the stage (faces +Z toward the crowd)
	local st = folder(lb, "Stage")
	part(st, "Platform", V(76, 6, 30), at(P(0, 3, -88)), PAL.marble, E.Enum.Material.Marble)
	part(st, "Trim", V(77, 1.2, 30.5), at(P(0, 5.6, -88)), PAL.gold, E.Enum.Material.Foil)
	for i = 1, 3 do
		part(st, "Step" .. i, V(14, 2 * i, 4), at(P(0, i, -73 + -(i - 1) * 4 + 8)), PAL.marble, E.Enum.Material.Marble)
	end
	local _back = part(st, "Backdrop", V(100, 44, 4), at(P(0, 22, -106)), PAL.marble, E.Enum.Material.Marble)
	for i = -2, 2 do
		part(st, "Pillar", V(5, 46, 5), at(P(i * 24, 23, -102)), "#D9D2C4", E.Enum.Material.Marble)
	end
	-- the Halcyon sun emblem (original): a gold disc and twelve rays
	disc(st, "Sun", 16, 1, P(0, 30, -103.6), PAL.gold, E.Enum.Material.Foil, { CanCollide = false }).CFrame = at(P(0, 30, -103.6)) * E.CFrame.Angles(0, math.pi / 2, 0)
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		part(st, "Ray", V(1.4, 8, 0.6), at(P(math.cos(a) * 12, 30 + math.sin(a) * 12, -103.6)) * E.CFrame.Angles(0, 0, a - math.pi / 2), PAL.goldHi, E.Enum.Material.Neon, { CanCollide = false })
	end
	local jumbo = part(st, "Jumbotron", V(46, 24, 2), at(P(0, 62, -104)), "#14161C", E.Enum.Material.SmoothPlastic)
	surfaceText(jumbo, E.Enum.NormalId.Back, names.TITLE:upper() .. "\n" .. names.EVENT:gsub("^the ", "The ") .. " · Jubilee Year", "#FFE9A8", "#14161C")
	part(st, "JumboFrame", V(48, 26, 1.6), at(P(0, 62, -104.6)), PAL.gold, E.Enum.Material.Foil)
	local flash = part(st, "Flashback", V(18, 11, 1), at(P(42, 40, -103.4)), "#23283A", E.Enum.Material.SmoothPlastic)
	surfaceText(flash, E.Enum.NormalId.Back, "25 years ago...\n" .. names.MENTOR_SHORT .. ", age 16", "#F4EFE6", "#23283A")
	-- glass globe of names
	cyl(st, "GlobeStand", 6, 3, at(P(-14, 9, -88)) * E.CFrame.Angles(0, 0, math.pi / 2), PAL.gold, E.Enum.Material.Foil)
	local globe = part(st, "Globe", V(8, 8, 8), at(P(-14, 16, -88)), "#DDF4FF", E.Enum.Material.Glass, { Transparency = 0.55, Shape = E.Enum.PartType.Ball })
	for _ = 1, 26 do
		deco(st, "Slip", V(0.9, 0.08, 0.5), at(P(-14 + rr(-2.2, 2.2), 14 + rr(-1.5, 2.2), -88 + rr(-2.2, 2.2))) * E.CFrame.Angles(rr(0, 3), rr(0, 3), rr(0, 3)), "#FFF8E7", E.Enum.Material.SmoothPlastic, false)
	end
	globe:SetAttribute("Globe", true)
	-- mic stand
	cyl(st, "Mic", 6, 0.3, at(P(4, 9, -80)) * E.CFrame.Angles(0, 0, math.pi / 2), "#2A2A2A", E.Enum.Material.Metal)
	dball(st, "MicHead", 0.7, at(P(4, 12.2, -80)), "#2A2A2A", E.Enum.Material.Metal, false)
	-- the Herald (faces the crowd)
	local herald = MapBuilder.npc(st, "Herald", at(P(8, 6, -84)) * yaw(math.pi), {
		skin = "#F1C9A5",
		shirt = "#F2CF63",
		pants = "#E9E4DA",
		shoes = "#D4A72C",
		hair = "#FF8A3D",
		hat = "bun",
		hatColor = "#FF8A3D",
		pearls = true,
		label = names.HERALD,
		labelColor = "#FFE9A8",
	})
	herald:SetAttribute("Role", "Herald")
	-- Rusty waits beside the crowd, then walks up to the stage during the reaping
	local rusty = MapBuilder.rusty(nil, lb, at(P(-44, 0, -30)) * yaw(-math.pi / 2), names.MENTOR)
	rusty:SetAttribute("Role", "Mentor")
	-- crowd pens and townsfolk
	local crowd = folder(lb, "Crowd")
	for row = 0, 5 do
		for _, side in { -1, 1 } do
			part(crowd, "Rope", V(40, 0.4, 0.4), at(P(side * 26, 3, -50 + row * 14)), "#B3262E", E.Enum.Material.Fabric, { CanCollide = false })
			for _, px in { 6, 46 } do
				cyl(crowd, "Post", 3.5, 0.6, at(P(side * px, 1.75, -50 + row * 14)) * E.CFrame.Angles(0, 0, math.pi / 2), PAL.gold, E.Enum.Material.Metal)
			end
		end
	end
	local outfits = { { PAL.slate, "#3A3A40", "#E0AC69", "#3B2A1A" }, { "#5C5A52", "#2B2D33", "#C68642", "#1E1A18" }, { "#6B5B4B", "#3A3A40", "#F1C9A5", "#8A6A3A" }, { "#4A505C", "#5C5A52", "#8D5524", "#111111" }, { "#7A6A55", "#2B2D33", "#F1C9A5", "#B89A5E" } }
	for row = 0, 5 do
		for _, side in { -1, 1 } do
			for k = 0, 6 do
				local x = side * (10 + k * 5.4 + rr(-0.8, 0.8))
				townsperson(crowd, at(P(x, 0, -45 + row * 14 + rr(-2, 2))) * yaw(math.pi + rr(-0.3, 0.3)), pick(outfits))
			end
		end
	end
	-- cutscene marks (invisible). Each Cam* part's CFrame is a camera pose.
	local marks = folder(lb, "CutsceneMarks")
	local function cam(name, pos, look)
		mark(marks, name, lookAt(P(pos[1], pos[2], pos[3]), P(look[1], look[2], look[3])))
	end
	cam("CamWide", { 0, 46, 70 }, { 0, 18, -80 })
	cam("CamGlobe", { -6, 18, -70 }, { -14, 16, -88 })
	cam("CamHerald", { 14, 14, -66 }, { 8, 11, -84 })
	cam("CamCrowd", { 0, 9, -62 }, { 0, 5, 0 })
	cam("CamPlayer", { 6, 7, -18 }, { 0, 5, -8 })
	cam("CamRusty", { -30, 9, -44 }, { -44, 5, -30 })
	cam("CamStage", { 0, 16, -46 }, { -2, 9, -84 })
	cam("CamPull", { 0, 70, 120 }, { 0, 20, -80 })
	mark(marks, "CrowdMark", at(P(0, 3, -6)))
	mark(marks, "AisleMark", at(P(0, 3, -62)))
	mark(marks, "StageMark", at(P(-2, 9, -82)))
	mark(marks, "RustyStart", at(P(-44, 3, -30)))
	mark(marks, "RustyMark", at(P(-8, 9, -84)))
	mark(marks, "PartnerMark", at(P(3, 9, -82)))
	-- queue: the Draw Gate (walk in or press Play in the menu)
	local q = folder(lb, "DrawGate")
	part(q, "PillarL", V(5, 34, 5), at(P(-18, 17, 120)), PAL.marble, E.Enum.Material.Marble)
	part(q, "PillarR", V(5, 34, 5), at(P(18, 17, 120)), PAL.marble, E.Enum.Material.Marble)
	local lintel = part(q, "Lintel", V(44, 6, 6), at(P(0, 36, 120)), PAL.gold, E.Enum.Material.Foil)
	surfaceText(lintel, E.Enum.NormalId.Back, "THE DRAW GATE", "#1C1F2B", nil)
	local pad = disc(q, "QueuePad", 30, 0.8, P(0, 0.4, 120), PAL.veil, E.Enum.Material.Neon)
	prompt(pad, "queue", "Join the Draw", names.EVENT_SHORT, 0, 18)
	-- boards
	local function board(name, pos, rot, text)
		local b = part(lb, name, V(30, 18, 1.5), at(P(pos[1], pos[2], pos[3])) * yaw(rot), "#23283A", E.Enum.Material.SmoothPlastic)
		part(lb, name .. "Frame", V(31.5, 19.5, 1.2), b.CFrame * E.CFrame.new(0, 0, 0.3), PAL.gold, E.Enum.Material.Foil)
		surfaceText(b, E.Enum.NormalId.Back, text, "#F4EFE6", "#23283A")
		prompt(b, name:lower(), "Open", name, 0, 16)
		return b
	end
	board("SeasonBoard", { 70, 12, 110 }, 0, names.TRACK .. "\nSeason 1: First Light")
	board("ChallengeBoard", { -70, 12, 110 }, 0, "Daily & Weekly\nChallenges")
	board("ReachBoard", { 140, 12, 30 }, math.pi / 2, names.REGION .. " Standings\nThis week")
	-- training range (pregame score is cosmetic)
	local tr = folder(lb, "TrainingRange")
	for k = 1, 5 do
		local t = disc(tr, "Target" .. k, 5, 0.6, P(-150, 6, -40 + k * 14), "#F4EFE6", E.Enum.Material.SmoothPlastic)
		t.CFrame = at(P(-150, 6, -40 + k * 14)) * E.CFrame.Angles(0, 0, 0)
		disc(tr, "Bull" .. k, 2, 0.7, P(-149.9, 6, -40 + k * 14), "#B3262E", E.Enum.Material.SmoothPlastic, { CanCollide = false }).CFrame = at(P(-149.6, 6, -40 + k * 14))
		part(tr, "TargetPost" .. k, V(0.6, 4, 0.6), at(P(-150, 2, -40 + k * 14)), "#4A3426", E.Enum.Material.Wood)
	end
	local trPad = disc(tr, "RangePad", 16, 0.6, P(-110, 0.3, 0), PAL.gold, E.Enum.Material.Foil)
	prompt(trPad, "training", "Train", "Target Range", 0, 12)
	-- lamps
	for k = 1, 12 do
		local a = k / 12 * math.pi * 2
		local pos = P(math.cos(a) * 150, 0, math.sin(a) * 150)
		part(lb, "LampPost", V(1, 16, 1), at(pos + V(0, 8, 0)), PAL.soot, E.Enum.Material.Metal)
		local bulb = part(lb, "Lamp", V(2.4, 2.4, 2.4), at(pos + V(0, 17, 0)), PAL.window, E.Enum.Material.Neon, { CanCollide = false })
		local pl = E.Instance.new("PointLight")
		pl.Color = E.Color3.fromHex("#FFC870")
		pl.Range = 30
		pl.Brightness = 1.4
		pl.Parent = bulb
	end
	local spawn = E.Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = V(16, 1, 16)
	spawn.CFrame = at(P(0, 0.5, 80))
	spawn.Color = E.Color3.fromHex(PAL.gold)
	spawn.Material = E.Enum.Material.Foil
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = lb
	return lb
end

-- ===================== templates the server clones =====================
local function buildTemplates(root)
	local t = folder(root, "Templates")
	-- Candyfinch: a round, sugary pink bird
	local f = model(t, "Candyfinch")
	local body = sph(f, "Body", V(1.6, 1.3, 2), at(V(0, 0, 0)), PAL.finch, E.Enum.Material.SmoothPlastic, { CanCollide = false, Anchored = true })
	sph(f, "Head", V(1.1, 1.1, 1.1), at(V(0, 0.5, -0.9)), "#FFB3E6", E.Enum.Material.SmoothPlastic, { CanCollide = false })
	part(f, "Beak", V(0.3, 0.3, 0.5), at(V(0, 0.45, -1.5)), PAL.goldHi, E.Enum.Material.SmoothPlastic, { CanCollide = false })
	for _, s in { -1, 1 } do
		sph(f, "Wing", V(1.6, 0.25, 1.2), at(V(s * 1, 0.2, 0)) * E.CFrame.Angles(0, 0, s * 0.3), "#FF5CC8", E.Enum.Material.SmoothPlastic, { CanCollide = false })
		dball(f, "Eye", 0.2, at(V(s * 0.3, 0.65, -1.35)), "#1C1F2B", E.Enum.Material.SmoothPlastic, false)
	end
	f.PrimaryPart = body
	-- Parachute gift
	local pc = model(t, "Parachute")
	local box = part(pc, "Box", V(3, 3, 3), at(V(0, 0, 0)), "#8A6A3A", E.Enum.Material.Wood, { CanCollide = false })
	sph(pc, "Canopy", V(12, 5, 12), at(V(0, 9, 0)), "#F4EFE6", E.Enum.Material.Fabric, { CanCollide = false })
	sph(pc, "Stripe", V(12.1, 2, 12.1), at(V(0, 9.2, 0)), PAL.gold, E.Enum.Material.Fabric, { CanCollide = false })
	for _, o in { { -4, -4 }, { 4, -4 }, { -4, 4 }, { 4, 4 } } do
		part(pc, "String", V(0.1, 8, 0.1), lookAt(V(o[1] / 2, 4.5, o[2] / 2), V(o[1], 9, o[2])) * E.CFrame.Angles(math.pi / 2, 0, 0), "#FFFFFF", E.Enum.Material.SmoothPlastic, { CanCollide = false })
	end
	pc.PrimaryPart = box
	-- Jubilee token
	local tk = model(t, "Token")
	local coin = cyl(tk, "Coin", 0.4, 2.6, at(V(0, 0, 0)), PAL.goldHi, E.Enum.Material.Neon, { CanCollide = false })
	tk.PrimaryPart = coin
	return t
end

-- Build everything under workspace.Map and return it.
function MapBuilder.build(env, ws, cfg, names, content)
	E = env
	MapBuilder.setEnv(env)
	seed = 20261102
	local map = model(ws, "Map")
	local arena = folder(map, "Arena")
	buildGround(arena, cfg)
	buildHub(arena, cfg, names)
	buildMeadow(arena, cfg)
	buildLake(arena, cfg)
	buildWood(arena, cfg)
	buildRidge(arena, cfg)
	buildRuins(arena, cfg)
	buildScatter(arena, cfg)
	buildTokens(arena, cfg, content)
	buildVeil(arena, cfg)
	buildGallery(map, cfg, names)
	buildLobby(map, cfg, names, content)
	buildTemplates(map)
	return map
end

return MapBuilder

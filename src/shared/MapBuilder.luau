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

-- A realistically proportioned human (about 7.5 heads tall, R15 part names) built from parts,
-- so the world reads as people, not toys, even before real meshes are swapped in.
-- This is a stand-in: LookService replaces it at runtime with a real R15 rig (Dynamic Head with
-- FACS expressions + layered clothing) for every NPC whose asset IDs are filled in Look.luau.
-- Feet at `cf`, facing -Z. Returns model, Head, UpperTorso.
-- Options: skin, shirt, pants, shoes, hair, hairStyle ("short" | "messy" | "bun" | "slick" |
-- "long" | "bald"), coat, coatLong, vest, scarf, tie, beard, stubble, mustache, brows, glasses,
-- hat ("cowboy" | "cap" | "flat"), hatColor, expr ("neutral" | "smile" | "wry" | "stern"),
-- build ("lean" | "average" | "broad"), height (multiplier), label, labelColor, scale, age.
function MapBuilder.npc(parent, name, cf, o)
	o = o or {}
	local m = model(parent, name)
	local skin = o.skin or "#C99A74"
	local shirt = o.shirt or "#5A5F66"
	local pants = o.pants or "#3A3A3C"
	local shoes = o.shoes or "#2E2621"
	local s = (o.scale or 1) * (o.height or 1)
	local w = o.build == "broad" and 1.12 or (o.build == "lean" and 0.92 or 1)
	local skinMat = E.Enum.Material.SmoothPlastic
	local cloth = E.Enum.Material.Fabric
	local function at(x, y, z, rx, ry, rz)
		return cf * E.CFrame.new(x * s, y * s, z * s) * E.CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
	end
	local function e(n, sx, sy, sz, c, x, y, z, rx, ry, rz, mat)
		return sph(m, n, V(sx * s, sy * s, sz * s), at(x, y, z, rx, ry, rz), c, mat or cloth, { CanCollide = false })
	end
	-- a limb segment between two points (local coords), as a rounded cylinder
	local function limb(n, a, b, d, c, mat)
		local pa = cf * E.CFrame.new(a[1] * s, a[2] * s, a[3] * s)
		local pb = cf * E.CFrame.new(b[1] * s, b[2] * s, b[3] * s)
		local mid = (pa.Position + pb.Position) / 2
		local len = (pb.Position - pa.Position).Magnitude
		local x = (pb.Position - pa.Position).Unit
		local ref = math.abs(x.Y) > 0.9 and V(0, 0, 1) or V(0, 1, 0)
		local y = ref:Cross(x).Unit
		local look = E.CFrame.fromMatrix(mid, x, y)
		local p = cyl(m, n, len, d * s, look, c, mat or cloth, { CanCollide = false })
		sph(m, n .. "Joint", V(d * s, d * s, d * s), E.CFrame.new(pb.Position), c, mat or cloth, { CanCollide = false })
		return p
	end
	-- legs: thigh 1.55, shin 1.45, ankle at 0.22 (hips at 3.05)
	local legL = limb("LeftUpperLeg", { -0.36 * w, 3.0, 0 }, { -0.38 * w, 1.6, -0.04 }, 0.62 * w, pants)
	local legR = limb("RightUpperLeg", { 0.36 * w, 3.0, 0 }, { 0.38 * w, 1.6, -0.04 }, 0.62 * w, pants)
	limb("LeftLowerLeg", { -0.38 * w, 1.6, -0.04 }, { -0.4 * w, 0.28, 0.02 }, 0.48, pants)
	limb("RightLowerLeg", { 0.38 * w, 1.6, -0.04 }, { 0.4 * w, 0.28, 0.02 }, 0.48, pants)
	for _, side in { -1, 1 } do
		local fx = side * 0.4 * w
		e(side < 0 and "LeftFoot" or "RightFoot", 0.46, 0.32, 1.02, shoes, fx, 0.17, -0.2, 0, 0, 0, E.Enum.Material.Leather)
		e("Sole", 0.48, 0.1, 1.04, "#1E1A17", fx, 0.05, -0.2, 0, 0, 0, E.Enum.Material.Rubber)
		if o.boots then
			limb("BootShaft", { fx, 0.3, 0.02 }, { fx, 1.15, 0 }, 0.52, shoes, E.Enum.Material.Leather)
		end
	end
	-- torso: pelvis, waist, ribcage (V-taper), shoulders
	e("LowerTorso", 1.32 * w, 0.78, 0.82, pants, 0, 3.12, 0)
	if o.belt ~= false then
		e("Belt", 1.3 * w, 0.18, 0.84, "#2A221C", 0, 3.42, 0, 0, 0, 0, E.Enum.Material.Leather)
	end
	e("Waist", 1.18 * w, 0.95, 0.74, shirt, 0, 3.72, 0)
	local torso = sph(m, "UpperTorso", V(1.62 * w * s, 1.35 * s, 0.86 * s), at(0, 4.3, 0), shirt, cloth)
	e("Shoulders", 1.86 * w, 0.42, 0.78, shirt, 0, 4.72, 0.02)
	if o.vest then
		e("Vest", 1.66 * w, 1.3, 0.9, o.vest, 0, 4.2, -0.01)
	end
	if o.coat then
		-- layered outer coat that hugs the body: a shell over the ribcage and shoulders, a skirt
		-- over the hips (long for coatLong), an open front showing the shirt, flat lapels
		local len = o.coatLong and 2.7 or 1.6
		e("CoatTorso", 1.72 * w, 1.42, 0.94, o.coat, 0, 4.28, 0.01)
		e("CoatShoulders", 1.98 * w, 0.46, 0.88, o.coat, 0, 4.72, 0.03)
		e("CoatSkirt", 1.44 * w, len, 0.92, o.coat, 0, 3.95 - len / 2 + 0.35, 0.02)
		e("CoatCollar", 0.9, 0.3, 0.8, o.coatTrim or o.coat, 0, 4.95, 0.06)
		e("ShirtFront", 0.36, 1.25, 0.16, shirt, 0, 4.2, -0.43)
		if not o.tie then
			e("ShirtFrontLow", 0.3, 0.7, 0.16, shirt, 0, 3.55, -0.4)
		end
		for _, side in { -1, 1 } do
			e("Lapel", 0.2, 0.72, 0.07, o.coatTrim or o.coat, side * 0.23, 4.48, -0.455, 0, 0, side * -14)
		end
	end
	if o.tie then
		e("Tie", 0.2, 1.15, 0.12, o.tie, 0, 4.15, -0.43)
	end
	if o.scarf then
		e("Scarf", 0.95, 0.38, 0.85, o.scarf, 0, 4.98, -0.02)
		e("ScarfTail", 0.3, 1.0, 0.14, o.scarf, 0.22, 4.4, -0.44, 0, 0, 8)
	end
	-- arms (sleeves) hang naturally, hands at mid-thigh
	local sleeve = o.coat or shirt
	for _, side in { -1, 1 } do
		local sx = side * 0.98 * w
		limb(side < 0 and "LeftUpperArm" or "RightUpperArm", { sx, 4.72, 0.02 }, { sx + side * 0.12, 3.55, 0.06 }, 0.38, sleeve)
		limb(side < 0 and "LeftLowerArm" or "RightLowerArm", { sx + side * 0.12, 3.55, 0.06 }, { sx + side * 0.14, 2.62, -0.06 }, 0.32, sleeve)
		e(side < 0 and "LeftHand" or "RightHand", 0.24, 0.5, 0.36, skin, sx + side * 0.15, 2.36, -0.07, 0, 0, 0, skinMat)
	end
	-- neck + head (head 0.82 tall: chin 5.08, crown 5.9)
	limb("Neck", { 0, 4.86, 0.02 }, { 0, 5.18, 0.0 }, 0.36, skin, skinMat)
	local head = sph(m, "Head", V(0.68 * s, 0.84 * s, 0.76 * s), at(0, 5.48, 0), skin, skinMat, { CanCollide = false })
	e("Jaw", 0.56, 0.36, 0.6, skin, 0, 5.24, -0.06, 0, 0, 0, skinMat)
	e("EarL", 0.08, 0.22, 0.14, skin, -0.34, 5.48, 0.02, 0, 0, 0, skinMat)
	e("EarR", 0.08, 0.22, 0.14, skin, 0.34, 5.48, 0.02, 0, 0, 0, skinMat)
	-- face: small, set-in eyes, a real nose and a closed mouth (expression via brow/mouth angle)
	local expr = o.expr or "neutral"
	local browTilt = expr == "stern" and 10 or (expr == "wry" and -6 or 0)
	local mouthCurve = expr == "smile" and 5 or (expr == "wry" and 8 or (expr == "stern" and -3 or 0))
	for _, side in { -1, 1 } do
		e("EyeWhite", 0.13, 0.065, 0.05, "#E8E2D8", side * 0.13, 5.53, -0.355, 0, 0, 0, skinMat)
		e("Iris", 0.06, 0.06, 0.03, o.eyes or "#3A2C22", side * 0.13, 5.53, -0.375, 0, 0, 0, skinMat)
		e("Lid", 0.15, 0.04, 0.06, skin, side * 0.13, 5.565, -0.35, 0, 0, 0, skinMat)
		if o.brows ~= false then
			deco(m, "Brow", V(0.17 * s, 0.035 * s, 0.04 * s), at(side * 0.135, 5.63, -0.355, 0, 0, side * browTilt), o.browColor or o.hair or "#2A1E1A", cloth, false)
		end
		if o.age and o.age > 40 then
			deco(m, "Crease", V(0.06 * s, 0.012 * s, 0.02 * s), at(side * 0.23, 5.52, -0.335, 0, 0, side * 20), "#8A6A55", skinMat, false)
		end
	end
	e("Nose", 0.09, 0.2, 0.12, skin, 0, 5.44, -0.385, -12, 0, 0, skinMat)
	e("NoseTip", 0.1, 0.07, 0.08, skin, 0, 5.36, -0.41, 0, 0, 0, skinMat)
	deco(m, "Mouth", V(0.2 * s, 0.025 * s, 0.03 * s), at(0, 5.26, -0.355, 0, 0, expr == "wry" and 8 or 0), o.lips or "#8C5A4E", skinMat, false)
	if mouthCurve ~= 0 then
		for _, side in { -1, 1 } do
			deco(m, "MouthCorner", V(0.05 * s, 0.022 * s, 0.03 * s), at(side * 0.115, 5.265 + (mouthCurve > 0 and 0.012 or -0.012) * (side == 1 and expr == "wry" and 2 or 1), -0.35, 0, 0, side * mouthCurve * 3), o.lips or "#8C5A4E", skinMat, false)
		end
	end
	if o.stubble then
		e("Stubble", 0.6, 0.34, 0.6, o.stubble, 0, 5.22, -0.075, 0, 0, 0, cloth).Transparency = 0.35
	end
	if o.beard then
		e("Beard", 0.62, 0.42, 0.62, o.beard, 0, 5.18, -0.08, 0, 0, 0, cloth)
	end
	if o.mustache then
		e("Mustache", 0.26, 0.06, 0.08, o.mustache, 0, 5.31, -0.37, 0, 0, 0, cloth)
	end
	if o.glasses then
		for _, side in { -1, 1 } do
			local lens = cyl(m, "Glasses", 0.02 * s, 0.17 * s, at(side * 0.13, 5.53, -0.4) * E.CFrame.Angles(0, math.pi / 2, 0), "#BFD3DA", E.Enum.Material.Glass, { Transparency = 0.6, CanCollide = false })
			lens.CanQuery = false
		end
		deco(m, "GlassesBridge", V(0.08 * s, 0.02 * s, 0.02 * s), at(0, 5.55, -0.41), "#2A2420", E.Enum.Material.Metal, false)
	end
	-- hair
	local hair = o.hair or "#3A2A1E"
	local style = o.hairStyle or "short"
	if style ~= "bald" and o.hat ~= "cowboy" then
		e("Hair", 0.74, 0.5, 0.8, hair, 0, 5.74, 0.03, -8, 0, 0, cloth)
		if style == "messy" then
			for k = 2, 5 do
				local a = (k - 3.5) * 0.5
				e("Tuft", 0.24, 0.1, 0.28, hair, math.sin(a) * 0.28, 5.92 + (k % 2) * 0.02, -0.12 + math.cos(a) * 0.1, -20 + (k % 3) * 8, k * 30, (k % 2) * 14, cloth)
			end
		elseif style == "slick" then
			e("HairBack", 0.72, 0.5, 0.5, hair, 0, 5.6, 0.2, 0, 0, 0, E.Enum.Material.SmoothPlastic)
		elseif style == "bun" then
			e("HairBack", 0.72, 0.6, 0.5, hair, 0, 5.56, 0.18, 0, 0, 0, cloth)
			e("Bun", 0.36, 0.32, 0.32, hair, 0, 5.82, 0.42, 0, 0, 0, cloth)
		elseif style == "long" then
			e("HairBack", 0.78, 1.15, 0.5, hair, 0, 5.15, 0.22, 0, 0, 0, cloth)
		else
			e("HairBack", 0.7, 0.4, 0.45, hair, 0, 5.56, 0.2, 0, 0, 0, cloth)
		end
	end
	if o.hat == "cowboy" then
		local hc = o.hatColor or "#3B2E22"
		cyl(m, "HatBrim", 0.05 * s, 1.5 * s, at(0, 5.8, 0.02) * E.CFrame.Angles(0, 0, math.pi / 2), hc, E.Enum.Material.Leather, { CanCollide = false })
		e("HatCrown", 0.74, 0.4, 0.8, hc, 0, 5.98, 0.02, 0, 0, 0, E.Enum.Material.Leather)
	elseif o.hat == "cap" or o.hat == "flat" then
		local hc = o.hatColor or "#4A4038"
		e("Cap", 0.76, 0.32, 0.82, hc, 0, 5.86, 0.02, 0, 0, 0, cloth)
		e("Bill", 0.5, 0.05, 0.34, hc, 0, 5.8, -0.4, -8, 0, 0, cloth)
	end
	for _, c in ipairs(m:GetDescendants()) do
		if c:IsA("BasePart") then
			c.CanCollide = c == torso or c == legL or c == legR
			c.CastShadow = c == torso or c == head or c.Name:find("Coat") ~= nil or c.Name:find("Leg") ~= nil
		end
	end
	m.PrimaryPart = torso
	m:SetAttribute("Realistic", true)
	if o.label then
		billboard(head, "NameTag", o.label, 1.4, 60, o.labelColor or "#E9DFC6", 200, 32)
	end
	return m, head, torso
end

-- ===================== palette (from the plan's "Color & Look") =====================
local PAL = {
	-- Realism pass: a desaturated, filmic palette. Aged brass instead of bright gold, weathered
	-- stone, olive grass and a muted rose for the meadow blooms.
	marble = "#CFC8BC",
	gold = "#9C8048",
	goldHi = "#B89A5C",
	slate = "#474B52",
	soot = "#2A2B2F",
	haze = "#D9A57E",
	meadow = "#7A844C",
	meadowDeep = "#646E3E",
	bloom = "#A85A78",
	finch = "#C98AA8",
	lake = "#4A737A",
	wood = "#2F4430",
	woodDark = "#263828",
	veil = "#9ADCE4",
	field = { "#68704A", "#707850", "#5F6844" },
	fieldDusk = "#555C3F",
	ridge = { "#5A5B5E", "#4A4D52", "#636468" },
	sand = "#A89C80",
	trunk = "#3E3128",
	brick = { "#54463F", "#4A464C", "#5A5049" },
	window = "#E2B26C",
	rustyHair = "#A68C5C",
	rustyRoots = "#5E4C34",
	rustyShirt = "#A68A44",
	rustyPlaid = "#3E5E60",
	rustyPants = "#4E4C46",
	thermos = "#3E6A4E",
	grass = { "#6E7748", "#7A8250", "#626B40", "#858A56" },
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
	local c = pick({ PAL.wood, PAL.woodDark, "#344A36" })
	sph(m, "Needles1", V(11 * s, 9 * s, 11 * s), at(pos + V(0, 10 * s, 0)), c, E.Enum.Material.LeafyGrass, { CanCollide = false, CanQuery = false, CastShadow = true })
	sph(m, "Needles2", V(8 * s, 8 * s, 8 * s), at(pos + V(0, 16 * s, 0)), c, E.Enum.Material.LeafyGrass, { CanCollide = false, CanQuery = false, CastShadow = true })
	sph(m, "Needles3", V(4.5 * s, 6 * s, 4.5 * s), at(pos + V(0, 21 * s, 0)), c, E.Enum.Material.LeafyGrass, { CanCollide = false, CanQuery = false, CastShadow = false })
	part(m, "Hitbox", V(2 * s, 12 * s, 2 * s), at(pos + V(0, 6 * s, 0)), PAL.trunk, E.Enum.Material.Wood, { Transparency = 1, CastShadow = false })
	return m
end

local function broadleaf(parent, pos, s)
	local m = model(parent, "Tree")
	deco(m, "Trunk", V(2 * s, 9 * s, 2 * s), at(pos + V(0, 4.5 * s, 0)), PAL.trunk, E.Enum.Material.Wood, false)
	local c = pick({ "#4E6038", "#58683E", "#646C40", "#6E6C44" })
	dball(m, "Canopy", 12 * s, at(pos + V(0, 11 * s, 0)), c, E.Enum.Material.LeafyGrass, true)
	dball(m, "Canopy2", 8 * s, at(pos + V(4 * s, 9.5 * s, 2 * s)), c, E.Enum.Material.LeafyGrass, false)
	part(m, "Hitbox", V(2.2 * s, 9 * s, 2.2 * s), at(pos + V(0, 4.5 * s, 0)), PAL.trunk, E.Enum.Material.Wood, { Transparency = 1, CastShadow = false })
	return m
end

local function rock(parent, pos, s, color)
	local p = sph(parent, "Rock", V(rr(6, 10) * s, rr(4, 7) * s, rr(6, 10) * s), at(pos + V(0, 1.5 * s, 0)) * yaw(rr(0, 6.28)), color or pick(PAL.ridge), E.Enum.Material.Rock)
	return p
end

local function crate(parent, name, pos, loot, rot)
	local c = part(parent, name, V(4, 3, 3), at(pos + V(0, 1.5, 0)) * yaw(rot or 0), loot == "hub" and "#6E5A40" or "#5A4834", E.Enum.Material.WoodPlanks)
	c:SetAttribute("Loot", loot)
	c:SetAttribute("Crate", true)
	deco(c, "Band", V(4.1, 0.5, 3.1), c.CFrame, loot == "meadow" and "#6E3E4E" or "#5A4A3A", E.Enum.Material.CorrodedMetal, false)
	deco(c, "Band2", V(0.5, 3.1, 3.1), c.CFrame, loot == "meadow" and "#6E3E4E" or "#5A4A3A", E.Enum.Material.CorrodedMetal, false)
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
	-- realistic, low-detail townsfolk for the lobby crowd (worn, muted work clothes)
	local m = MapBuilder.npc(parent, "Townsperson", cf, {
		shirt = colors[1],
		pants = colors[2],
		skin = colors[3],
		hair = colors[4],
		coat = rnd() < 0.4 and pick({ "#4A443C", "#3E4248", "#55483A" }) or nil,
		hairStyle = pick({ "short", "short", "messy", "long", "bun", "bald" }),
		hat = rnd() < 0.2 and "flat" or nil,
		stubble = rnd() < 0.3 and colors[4] or nil,
		expr = pick({ "neutral", "neutral", "stern", "wry" }),
		build = pick({ "lean", "average", "broad" }),
		height = rr(0.93, 1.06),
		brows = true,
	})
	return m
end

-- Rusty Dunmore: the scruffy, kind mentor in his forties. Worn plaid overshirt over a faded
-- mustard tee, work boots, two-tone hair grown out, a week of stubble, and his green thermos.
function MapBuilder.rusty(env, parent, cf, label)
	if env then
		E = env
	end
	local m, head, torso = MapBuilder.npc(parent, "Rusty", cf, {
		skin = "#C49272",
		shirt = PAL.rustyShirt,
		pants = PAL.rustyPants,
		shoes = "#3A2C22",
		boots = true,
		coat = PAL.rustyPlaid,
		coatTrim = "#2C4446",
		hair = PAL.rustyHair,
		browColor = PAL.rustyRoots,
		hairStyle = "messy",
		stubble = PAL.rustyRoots,
		mustache = PAL.rustyRoots,
		expr = "wry",
		age = 44,
		build = "average",
		height = 1.02,
		label = label,
		labelColor = "#E3C987",
	})
	local s = 1.02
	local function a(x, y, z)
		return cf * E.CFrame.new(x * s, y * s, z * s)
	end
	-- darker roots under the grown-out hair (real plaid comes from the layered shirt in Studio)
	sph(m, "Roots", V(0.66 * s, 0.22 * s, 0.7 * s), a(0, 5.74, 0.08), PAL.rustyRoots, E.Enum.Material.Fabric, { CanCollide = false })
	-- the dented green thermos in his right hand
	local th = cyl(m, "Thermos", 0.95, 0.34, a(1.14, 2.3, -0.3) * E.CFrame.Angles(0, 0, math.pi / 2), PAL.thermos, E.Enum.Material.CorrodedMetal, { CanCollide = false })
	cyl(m, "ThermosCap", 0.18, 0.37, a(1.14, 2.82, -0.3) * E.CFrame.Angles(0, 0, math.pi / 2), "#2A2A2A", E.Enum.Material.Metal, { CanCollide = false })
	m:SetAttribute("LookId", "Rusty")
	return m, head, torso, th
end

-- Monty Gleam: the Capital's interview host. Silver-streaked slick hair, midnight suit, a
-- practiced TV smile.
function MapBuilder.monty(parent, cf, label)
	local m, head = MapBuilder.npc(parent, "Monty", cf, {
		skin = "#B98466",
		shirt = "#D8D2C6",
		pants = "#1F2430",
		shoes = "#151515",
		coat = "#232A3A",
		coatTrim = "#1A1F2B",
		tie = "#6B2430",
		hair = "#4A4440",
		hairStyle = "slick",
		expr = "smile",
		age = 52,
		build = "lean",
		height = 1.03,
		label = label,
		labelColor = "#E3C987",
	})
	deco(m, "PocketSquare", V(0.14, 0.08, 0.04), cf * E.CFrame.new(-0.42, 4.55, -0.47), "#C9A24A", E.Enum.Material.Fabric, false)
	m:SetAttribute("LookId", "Monty")
	return m, head
end

-- Herald Marigold Vane: the Capital escort. Tailored ochre long coat with a cream collar,
-- copper hair in a tight bun, pearls, a bright smile that never quite reaches her eyes.
function MapBuilder.herald(parent, cf, label)
	local m, head = MapBuilder.npc(parent, "Herald", cf, {
		skin = "#E2B99A",
		shirt = "#E8DFCF",
		pants = "#5A4632",
		shoes = "#3A2A1E",
		coat = "#9C7A3C",
		coatLong = true,
		coatTrim = "#E8DFCF",
		hair = "#A2512A",
		hairStyle = "bun",
		lips = "#9A4A48",
		expr = "smile",
		build = "lean",
		height = 0.97,
		label = label,
		labelColor = "#E3C987",
	})
	for k = -2, 2 do
		dball(m, "Pearl", 0.07, cf * E.CFrame.new(k * 0.08, 4.86 - math.abs(k) * 0.02, -0.36 + math.abs(k) * 0.03), "#EFE8DA", E.Enum.Material.SmoothPlastic, false)
	end
	m:SetAttribute("LookId", "Herald")
	return m, head
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
			local mat = E.Enum.Material.LeafyGrass
			if b == "ridge" then
				color, mat = "#5E5C55", E.Enum.Material.Ground
			elseif b == "wood" then
				color = "#4A5638"
			elseif b == "ruins" then
				color, mat = "#6E685A", E.Enum.Material.Mud
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
		local color = a > math.pi * 1.1 and a < math.pi * 1.9 and "#55565A" or pick({ "#465440", "#4E5A44", "#424C3C" })
		sph(g, "Hill", V(s * 1.6, s * 0.7, s), at(V(math.cos(a) * r, -s * 0.12, math.sin(a) * r)) * yaw(-a), color, E.Enum.Material.Grass, { CanCollide = false, CastShadow = false })
	end
end

local function buildHub(root, cfg, names)
	local h = folder(root, "Sundial")
	local R = cfg.Map.HUB_RADIUS
	disc(h, "Apron", R * 2 + 40, 1, V(0, 0.5, 0), "#9C968A", E.Enum.Material.Cobblestone)
	disc(h, "Base", R * 2, 2, V(0, 1.5, 0), PAL.marble, E.Enum.Material.Limestone)
	disc(h, "GoldRing", R * 2 - 6, 2.4, V(0, 1.7, 0), PAL.gold, E.Enum.Material.Metal)
	disc(h, "Face", R * 2 - 10, 2.6, V(0, 1.8, 0), PAL.marble, E.Enum.Material.Limestone)
	disc(h, "Inlay", 30, 2.8, V(0, 1.9, 0), PAL.goldHi, E.Enum.Material.Metal)
	-- 12 hour marks
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		local r = R - 9
		part(h, "HourMark", V(2, 0.6, 7), at(V(math.cos(a) * r, 3.2, math.sin(a) * r)) * yaw(-a + math.pi / 2), PAL.gold, E.Enum.Material.Metal, { CanCollide = false })
	end
	-- the gnomon: a tall golden blade casting the hub's shadow
	local gnomon = part(h, "Gnomon", V(3, 46, 26), at(V(0, 20, 6)) * E.CFrame.Angles(math.rad(-28), 0, 0), PAL.gold, E.Enum.Material.Metal)
	local light = E.Instance.new("PointLight")
	light.Color = E.Color3.fromHex("#FFD36B")
	light.Brightness = 3
	light.Range = 60
	light.Parent = gnomon
	part(h, "GnomonCap", V(4, 3, 4), at(V(0, 41, -4)), PAL.goldHi, E.Enum.Material.Metal, { CanCollide = false })
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
		local p = disc(plates, string.format("Plate%02d", i), 8, 1.2, pos + V(0, 0.6, 0), "#6E6A64", E.Enum.Material.DiamondPlate)
		p:SetAttribute("Index", i)
		disc(plates, string.format("Plate%02d_Ring", i), 9, 0.9, pos + V(0, 0.5, 0), PAL.veil, E.Enum.Material.Neon, { CanCollide = false, CanQuery = false })
	end
end

local function buildMeadow(root, cfg)
	local m = folder(root, "GildedMeadow")
	local M = cfg.Map.MEADOW
	disc(m, "Meadow", M.r * 2, 0.4, V(M.x, 0.2, M.z), PAL.meadow, E.Enum.Material.LeafyGrass, { CanCollide = false })
	disc(m, "MeadowInner", M.r * 1.3, 0.5, V(M.x, 0.25, M.z), "#808A4E", E.Enum.Material.LeafyGrass, { CanCollide = false })
	local zone = disc(m, "MeadowZone", M.r * 2, 60, V(M.x, 30, M.z), PAL.bloom, E.Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	zone:SetAttribute("Zone", "meadow")
	local flowers = model(m, "Flowers")
	for _ = 1, 420 do
		local a, d = rr(0, math.pi * 2), math.sqrt(rnd()) * (M.r - 8)
		local x, z = M.x + math.cos(a) * d, M.z + math.sin(a) * d
		local h = rr(1.4, 2.8)
		deco(flowers, "Stem", V(0.12, h, 0.12), at(V(x, h / 2, z)) * E.CFrame.Angles(rr(-0.15, 0.15), 0, rr(-0.15, 0.15)), "#4E5A34", E.Enum.Material.LeafyGrass, false)
		local c = rnd() < 0.5 and "#C2A050" or (rnd() < 0.6 and PAL.bloom or "#DCD5C4")
		dball(flowers, "Bloom", rr(0.45, 0.85), at(V(x, h + 0.1, z)), c, E.Enum.Material.Fabric, false)
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
		pe.LightEmission = 0.35
		pe.Color = E.ColorSequence.new(E.Color3.fromHex("#E8C878"), E.Color3.fromHex("#C98AA8"))
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
	disc(l, "Bed", L.r * 2, 0.7, V(L.x, 0.35, L.z), "#33494C", E.Enum.Material.Mud, { CanCollide = false })
	local w = disc(l, "Water", L.r * 2 - 4, 1.2, V(L.x, 0.6, L.z), PAL.lake, E.Enum.Material.Glass, { Transparency = 0.25, Reflectance = 0.3, CanCollide = false })
	w:SetAttribute("Zone", "lake")
	-- a small island with a reed bed and a token spot
	disc(l, "Island", 46, 2.2, V(L.x + 40, 1.1, L.z - 30), PAL.sand, E.Enum.Material.Sand)
	broadleaf(l, V(L.x + 40, 2.2, L.z - 30), 1.2)
	for _ = 1, 50 do
		local a = rr(0, math.pi * 2)
		local d = L.r + rr(-6, 14)
		deco(l, "Reed", V(0.4, rr(3, 6), 0.4), at(V(L.x + math.cos(a) * d, 2, L.z + math.sin(a) * d)) * E.CFrame.Angles(rr(-0.2, 0.2), 0, rr(-0.2, 0.2)), "#6E7044", E.Enum.Material.LeafyGrass, false)
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
		part(m, "Floor", V(L, 1, W), cf * E.CFrame.new(0, 0.5, 0), "#7A7468", E.Enum.Material.Cobblestone)
		local posts = math.floor(L / 10)
		for i = 0, posts do
			for _, side in { -1, 1 } do
				local broken = rnd() < 0.25
				local hh = broken and H * rr(0.3, 0.7) or H
				part(m, "Post", V(1, hh, 1), cf * E.CFrame.new(-L / 2 + i * L / posts, hh / 2, side * W / 2), "#4A3E36", E.Enum.Material.CorrodedMetal)
				if not broken and i < posts and rnd() < 0.6 then
					part(m, "Pane", V(L / posts - 1, H - 2, 0.3), cf * E.CFrame.new(-L / 2 + (i + 0.5) * L / posts, H / 2, side * W / 2), "#8FAAA2", E.Enum.Material.Glass, { Transparency = 0.5 })
				end
			end
		end
		if rnd() < 0.6 then
			part(m, "Roof", V(L, 0.6, W), cf * E.CFrame.new(0, H, 0), "#4A3E36", E.Enum.Material.CorrodedMetal, { Transparency = 0 })
		end
		for _ = 1, 4 do
			deco(m, "Planter", V(rr(4, 8), 2, 3), cf * E.CFrame.new(rr(-L / 3, L / 3), 2, rr(-W / 3, W / 3)), "#5A4433", E.Enum.Material.WoodPlanks, false)
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
	disc(g, "Rim", 156, 1.6, c + V(0, 0.4, 0), PAL.gold, E.Enum.Material.Metal, { CanCollide = false })
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
	part(lb, "Plaza", V(360, 4, 360), at(P(0, -2, 0)), "#56534F", E.Enum.Material.Cobblestone)
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
							deco(lb, "Window", V(4, 5, 0.4), b.CFrame * E.CFrame.new(wx * w / 3.2, -h / 2 + wy * 11, 15.1), rnd() < 0.6 and PAL.window or "#3A3F4A", rnd() < 0.35 and E.Enum.Material.Neon or E.Enum.Material.Glass, false)
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
	part(st, "Trim", V(77, 1.2, 30.5), at(P(0, 5.6, -88)), PAL.gold, E.Enum.Material.Metal)
	for i = 1, 3 do
		part(st, "Step" .. i, V(14, 2 * i, 4), at(P(0, i, -73 + -(i - 1) * 4 + 8)), PAL.marble, E.Enum.Material.Marble)
	end
	local _back = part(st, "Backdrop", V(100, 44, 4), at(P(0, 22, -106)), PAL.marble, E.Enum.Material.Marble)
	for i = -2, 2 do
		part(st, "Pillar", V(5, 46, 5), at(P(i * 24, 23, -102)), "#D9D2C4", E.Enum.Material.Marble)
	end
	-- the Halcyon sun emblem (original): a gold disc and twelve rays
	disc(st, "Sun", 16, 1, P(0, 30, -103.6), PAL.gold, E.Enum.Material.Metal, { CanCollide = false }).CFrame = at(P(0, 30, -103.6)) * E.CFrame.Angles(0, math.pi / 2, 0)
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		part(st, "Ray", V(1.4, 8, 0.6), at(P(math.cos(a) * 12, 30 + math.sin(a) * 12, -103.6)) * E.CFrame.Angles(0, 0, a - math.pi / 2), PAL.goldHi, E.Enum.Material.Metal, { CanCollide = false })
	end
	local jumbo = part(st, "Jumbotron", V(46, 24, 2), at(P(0, 62, -104)), "#14161C", E.Enum.Material.SmoothPlastic)
	surfaceText(jumbo, E.Enum.NormalId.Back, names.TITLE:upper() .. "\n" .. names.EVENT:gsub("^the ", "The ") .. " · Jubilee Year", "#FFE9A8", "#14161C")
	part(st, "JumboFrame", V(48, 26, 1.6), at(P(0, 62, -104.6)), PAL.gold, E.Enum.Material.Metal)
	local flash = part(st, "Flashback", V(18, 11, 1), at(P(42, 40, -103.4)), "#23283A", E.Enum.Material.SmoothPlastic)
	surfaceText(flash, E.Enum.NormalId.Back, "25 years ago...\n" .. names.MENTOR_SHORT .. ", age 16", "#F4EFE6", "#23283A")
	-- glass globe of names
	cyl(st, "GlobeStand", 6, 3, at(P(-14, 9, -88)) * E.CFrame.Angles(0, 0, math.pi / 2), PAL.gold, E.Enum.Material.Metal)
	local globe = part(st, "Globe", V(8, 8, 8), at(P(-14, 16, -88)), "#DDF4FF", E.Enum.Material.Glass, { Transparency = 0.55, Shape = E.Enum.PartType.Ball })
	for _ = 1, 26 do
		deco(st, "Slip", V(0.9, 0.08, 0.5), at(P(-14 + rr(-2.2, 2.2), 14 + rr(-1.5, 2.2), -88 + rr(-2.2, 2.2))) * E.CFrame.Angles(rr(0, 3), rr(0, 3), rr(0, 3)), "#FFF8E7", E.Enum.Material.SmoothPlastic, false)
	end
	globe:SetAttribute("Globe", true)
	-- mic stand
	cyl(st, "Mic", 6, 0.3, at(P(4, 9, -80)) * E.CFrame.Angles(0, 0, math.pi / 2), "#2A2A2A", E.Enum.Material.Metal)
	dball(st, "MicHead", 0.7, at(P(4, 12.2, -80)), "#2A2A2A", E.Enum.Material.Metal, false)
	-- the Herald (faces the crowd)
	local herald = MapBuilder.herald(st, at(P(8, 6, -84)) * yaw(math.pi), names.HERALD)
	herald:SetAttribute("Role", "Herald")
	-- Rusty waits beside the crowd, then walks up to the stage during the reaping
	local rusty = MapBuilder.rusty(nil, lb, at(P(-44, 0, -30)) * yaw(-math.pi / 2), names.MENTOR)
	rusty:SetAttribute("Role", "Mentor")
	-- the interview set: Monty Gleam's couch corner beside the stage
	local iv = folder(lb, "InterviewSet")
	part(iv, "Riser", V(30, 2, 20), at(P(100, 1, -74)), "#3A2E28", E.Enum.Material.WoodPlanks)
	part(iv, "Rug", V(16, 0.1, 10), at(P(100, 2.05, -74)), "#5A2E2E", E.Enum.Material.Fabric, { CanCollide = false })
	for _, xc in { 95.5, 104.5 } do
		part(iv, "Chair", V(3.2, 1.6, 3), at(P(xc, 2.8, -74)), "#4A3A30", E.Enum.Material.Leather)
		part(iv, "ChairBack", V(3.2, 3.2, 0.6), at(P(xc, 4.4, -72.7)), "#4A3A30", E.Enum.Material.Leather)
	end
	part(iv, "SideTable", V(2, 2.2, 2), at(P(100, 3.1, -73)), "#2E2622", E.Enum.Material.Wood)
	local ivBack = part(iv, "Backdrop", V(32, 16, 1), at(P(100, 9, -84.5)), "#22252C", E.Enum.Material.Fabric)
	surfaceText(ivBack, E.Enum.NormalId.Back, "TONIGHT WITH " .. names.HOST:upper(), "#D9C38C", "#22252C")
	for _, xc in { 88, 112 } do
		part(iv, "LightStand", V(0.3, 10, 0.3), at(P(xc, 6, -62)), "#2A2A2A", E.Enum.Material.Metal)
		local lamp = part(iv, "StudioLamp", V(2, 1.4, 1.4), at(P(xc, 11, -62)), "#D8CFB8", E.Enum.Material.Neon, { CanCollide = false })
		local sl = E.Instance.new("SpotLight")
		sl.Face = E.Enum.NormalId.Back
		sl.Range = 28
		sl.Angle = 60
		sl.Brightness = 2
		sl.Color = E.Color3.fromHex("#FFE2B8")
		sl.Parent = lamp
	end
	local monty = MapBuilder.monty(iv, at(P(95.5, 2, -74)) * yaw(math.pi * 1.15), names.HOST)
	monty:SetAttribute("Role", "Host")
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
	cam("CamInterview", { 103, 8.6, -58 }, { 100, 6.4, -73 })
	cam("CamRange", { -118, 9, 4 }, { -150, 6, -4 })
	mark(marks, "InterviewSeat", at(P(104.5, 2.2, -73)) * yaw(math.pi * 0.85))
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
	local lintel = part(q, "Lintel", V(44, 6, 6), at(P(0, 36, 120)), PAL.gold, E.Enum.Material.Metal)
	surfaceText(lintel, E.Enum.NormalId.Back, "THE DRAW GATE", "#1C1F2B", nil)
	local pad = disc(q, "QueuePad", 30, 0.8, P(0, 0.4, 120), PAL.veil, E.Enum.Material.Neon)
	prompt(pad, "queue", "Join the Draw", names.EVENT_SHORT, 0, 18)
	-- boards
	local function board(name, pos, rot, text)
		local b = part(lb, name, V(30, 18, 1.5), at(P(pos[1], pos[2], pos[3])) * yaw(rot), "#23283A", E.Enum.Material.SmoothPlastic)
		part(lb, name .. "Frame", V(31.5, 19.5, 1.2), b.CFrame * E.CFrame.new(0, 0, 0.3), PAL.gold, E.Enum.Material.Metal)
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
	local trPad = disc(tr, "RangePad", 16, 0.6, P(-110, 0.3, 0), PAL.gold, E.Enum.Material.Metal)
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
	spawn.Material = E.Enum.Material.Metal
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = lb
	return lb
end

-- ===================== realism: vegetation + ambient particles =====================
-- A clump of four narrow, splayed blades per tuft (reads as grass, not slabs); muted olive
-- greens; no collision so they never snag movement. Terrain grass decoration replaces most of
-- this at runtime when Look.terrainGrass is on.
local function tuft(parent, pos, scale)
	local m = model(parent, "Tuft")
	local c = pick(PAL.grass)
	local r = rr(0, 6.28)
	for k = 0, 3 do
		local h = rr(0.9, 2.1) * scale
		local a = r + k * 1.57 + rr(-0.3, 0.3)
		local tilt = rr(0.18, 0.42)
		local off = V(math.cos(a), 0, math.sin(a)) * (math.sin(tilt) * h / 2)
		deco(m, "Blade", V(0.05, h, rr(0.14, 0.24) * scale), at(pos + off + V(0, h / 2 * math.cos(tilt), 0)) * yaw(-a) * E.CFrame.Angles(0, 0, -tilt), c, E.Enum.Material.LeafyGrass, false)
	end
	return m
end

local function bush(parent, pos, s)
	local m = model(parent, "Bush")
	local c = pick({ "#4A5634", "#56603A", "#3F4A30", "#5E6340" })
	for k = 1, 3 do
		local o = V(rr(-1.2, 1.2) * s, 0, rr(-1.2, 1.2) * s)
		local d = rr(2.4, 4) * s
		sph(m, "Leaves", V(d * 1.2, d * 0.8, d), at(pos + o + V(0, d * 0.32, 0)) * yaw(rr(0, 3)), c, E.Enum.Material.LeafyGrass, { CanCollide = false, CanQuery = false, CastShadow = k == 1 })
	end
	return m
end

local function buildVegetation(root, cfg)
	local f = folder(root, "Vegetation")
	local M, L = cfg.Map.MEADOW, cfg.Map.LAKE
	-- the open field around the Sundial (where most fights start)
	local n, tries = 0, 0
	while n < 1100 and tries < 6000 do
		tries += 1
		local a, d = rr(0, math.pi * 2), rr(150, 700)
		local x, z = math.cos(a) * d, math.sin(a) * d
		local b = MapBuilder.biomeAt(x, z, cfg)
		if b == "field" or b == "wood" or b == "ruins" then
			tuft(f, V(x, 0, z), 1)
			n += 1
		end
	end
	-- denser, taller grass through the Gilded Meadow
	for _ = 1, 650 do
		local a, d = rr(0, math.pi * 2), math.sqrt(rnd()) * (M.r - 6)
		tuft(f, V(M.x + math.cos(a) * d, 0.4, M.z + math.sin(a) * d), 1.25)
	end
	-- reeds and grass on the lake shore
	for _ = 1, 220 do
		local a = rr(0, math.pi * 2)
		local d = L.r + rr(4, 34)
		tuft(f, V(L.x + math.cos(a) * d, 0.5, L.z + math.sin(a) * d), 1.1)
	end
	-- bushes
	local b, bt = 0, 0
	while b < 240 and bt < 3000 do
		bt += 1
		local x, z = rr(-1100, 1100), rr(-700, 1100)
		local bi = MapBuilder.biomeAt(x, z, cfg)
		if (bi == "field" or bi == "wood" or bi == "meadow") and math.sqrt(x * x + z * z) > 170 then
			bush(f, V(x, bi == "meadow" and 0.4 or 0, z), rr(0.8, 1.5))
			b += 1
		end
	end
end

local function emitter(parent, name, size, pos, o)
	local p = mark(parent, name, at(pos))
	p.Size = size
	local pe = E.Instance.new("ParticleEmitter")
	pe.Name = name
	pe.Shape = E.Enum.ParticleEmitterShape.Box
	pe.ShapeStyle = E.Enum.ParticleEmitterShapeStyle.Volume
	pe.Rate = o.rate
	pe.Lifetime = E.NumberRange.new(o.life[1], o.life[2])
	pe.Speed = E.NumberRange.new(o.speed[1], o.speed[2])
	pe.SpreadAngle = E.Vector2.new(180, 180)
	pe.Size = E.NumberSequence.new(o.size)
	pe.Transparency = E.NumberSequence.new(o.transparency)
	pe.LightEmission = o.light or 0
	pe.LightInfluence = 1
	pe.Color = E.ColorSequence.new(E.Color3.fromHex(o.color))
	pe.Rotation = E.NumberRange.new(0, 360)
	pe.RotSpeed = E.NumberRange.new(-8, 8)
	pe.Drag = o.drag or 0
	pe.Acceleration = o.accel or V(0, 0, 0)
	if o.texture then
		pe.Texture = o.texture
	end
	pe.Parent = p
	return p, pe
end

-- Dust motes drifting in the low sun (lobby, Sundial, ruins) and mist rolling on Mirror Lake.
local function buildAmbience(map, cfg)
	local f = folder(map, "Ambience")
	local Lc = cfg.Map.LOBBY_CENTER
	local LB = V(Lc[1], Lc[2], Lc[3])
	local dust = { rate = 14, life = { 8, 14 }, speed = { 0.1, 0.5 }, size = 0.09, transparency = 0.35, light = 0.5, color = "#F2DDB8", drag = 1, accel = V(0.15, 0.02, 0) }
	emitter(f, "DustMotes", V(220, 26, 220), LB + V(0, 13, -20), dust)
	emitter(f, "DustMotes", V(200, 30, 200), V(0, 15, 0), dust)
	local R = cfg.Map.RUINS
	emitter(f, "DustMotes", V(R.r * 1.4, 24, R.r * 1.4), V(R.x, 12, R.z), dust)
	local L = cfg.Map.LAKE
	local mist = { rate = 4, life = { 12, 18 }, speed = { 0.4, 1.2 }, size = 26, transparency = 0.88, light = 0.1, color = "#D8DEDE", drag = 0.3, accel = V(0.6, 0.05, 0.2), texture = "rbxasset://textures/particles/smoke_main.dds" }
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		emitter(f, "LakeMist", V(L.r * 0.9, 4, L.r * 0.9), V(L.x + math.cos(a) * L.r * 0.4, 4, L.z + math.sin(a) * L.r * 0.4), mist)
	end
	local M = cfg.Map.MEADOW
	emitter(f, "MeadowHaze", V(M.r * 1.6, 6, M.r * 1.6), V(M.x, 4, M.z), { rate = 2, life = { 14, 20 }, speed = { 0.2, 0.6 }, size = 30, transparency = 0.92, color = "#E6D6B8", texture = "rbxasset://textures/particles/smoke_main.dds" })
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
	buildVegetation(arena, cfg)
	buildTokens(arena, cfg, content)
	buildVeil(arena, cfg)
	buildGallery(map, cfg, names)
	buildLobby(map, cfg, names, content)
	buildAmbience(map, cfg)
	buildTemplates(map)
	return map
end

return MapBuilder

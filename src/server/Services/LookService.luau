--!strict
--[[
	LookService — the realism pass at runtime.
	  * Swaps NPC stand-ins for real R15 rigs (Dynamic Head + FACS expression + layered clothing)
	    once their asset IDs are filled in Shared/Look.luau.
	  * Builds Stand-In bodies: a real R15 rig for movement/animation with the realistic
	    part-built body welded on, limb by limb, until real bundles are configured.
	  * Applies PBR MaterialVariants as base-material overrides (when texture IDs are set).
	  * Converts the arena ground to Terrain grass with decoration (animated grass blades).
	  * Nudges player avatar scales toward realistic proportions.
	Everything is pcall-guarded: a missing asset never breaks the match.
]]
local Players = game:GetService("Players")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Look = require(Shared.Look)
local MapBuilder = require(Shared.MapBuilder) :: any

local LookService = {}

local ENV = {
	Instance = Instance,
	Vector3 = Vector3,
	CFrame = CFrame,
	Color3 = Color3,
	Enum = Enum,
	UDim2 = UDim2,
	NumberSequence = NumberSequence,
	NumberRange = NumberRange,
	ColorSequence = ColorSequence,
	Vector2 = Vector2,
}

local function idList(ids: { number }): string
	local out = {}
	for _, id in ipairs(ids) do
		if id ~= 0 then
			table.insert(out, tostring(id))
		end
	end
	return table.concat(out, ",")
end

local LAYER_TYPES: { [string]: Enum.AccessoryType } = {
	TShirt = Enum.AccessoryType.TShirt,
	Shirt = Enum.AccessoryType.Shirt,
	Jacket = Enum.AccessoryType.Jacket,
	Sweater = Enum.AccessoryType.Sweater,
	Pants = Enum.AccessoryType.Pants,
	Shorts = Enum.AccessoryType.Shorts,
	Shoes = Enum.AccessoryType.LeftShoe,
	DressSkirt = Enum.AccessoryType.DressSkirt,
}

-- A HumanoidDescription from an NPC spec (asset IDs from Look.luau).
local function describe(spec: Look.NpcSpec): HumanoidDescription
	local d = Instance.new("HumanoidDescription")
	local b = spec.body
	d.Head = spec.dynamicHead ~= 0 and spec.dynamicHead or b.head
	d.Torso = b.torso
	d.LeftArm = b.leftArm
	d.RightArm = b.rightArm
	d.LeftLeg = b.leftLeg
	d.RightLeg = b.rightLeg
	d.HairAccessory = idList(spec.hair)
	d.HatAccessory = idList(spec.accessories)
	if spec.idle ~= 0 then
		d.IdleAnimation = spec.idle
	end
	local skin = Color3.fromHex(spec.skin)
	d.HeadColor, d.TorsoColor = skin, skin
	d.LeftArmColor, d.RightArmColor, d.LeftLegColor, d.RightLegColor = skin, skin, skin, skin
	d.HeightScale = spec.scales.height
	d.WidthScale = spec.scales.width
	d.DepthScale = spec.scales.width
	d.HeadScale = spec.scales.head
	d.BodyTypeScale = spec.scales.bodyType
	d.ProportionScale = spec.scales.proportion
	local layered: { any } = {}
	for _, l in ipairs(spec.layered) do
		local t = LAYER_TYPES[l.kind]
		if l.id ~= 0 and t then
			table.insert(layered, { Order = l.order, AssetId = l.id, AccessoryType = t, IsLayered = true })
		end
	end
	if #layered > 0 then
		d:SetAccessories(layered, true)
	end
	return d
end

-- FACS expression on a Dynamic Head.
local function express(model: Model, expr: Look.Expression)
	local head = model:FindFirstChild("Head")
	local fc = head and head:FindFirstChildOfClass("FaceControls")
	if fc then
		for k, v in pairs(expr) do
			pcall(function()
				(fc :: any)[k] = v
			end)
		end
	end
end

-- Replace one part-built NPC with a real rig (only when its spec has a body).
local function upgradeNpc(old: Model)
	local id = old:GetAttribute("LookId")
	local spec = type(id) == "string" and Look.NPCS[id] or nil
	if not spec or not Look.hasBody(spec.body) then
		return
	end
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(describe(spec), Enum.HumanoidRigType.R15, Enum.AssetTypeVerification.Always)
	end)
	if not ok or not rig then
		warn("[Look] couldn't build", id, rig)
		return
	end
	local hum = rig:FindFirstChildOfClass("Humanoid")
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root then
		rig:Destroy()
		return
	end
	local base = old.PrimaryPart and old.PrimaryPart.CFrame or old:GetPivot()
	local box, size = old:GetBoundingBox()
	local floorY = box.Position.Y - size.Y / 2
	root.Anchored = true
	rig.Name = old.Name
	for _, a in ipairs({ "Role", "LookId" }) do
		rig:SetAttribute(a, old:GetAttribute(a))
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	-- keep the name tag and props (Rusty's thermos) from the stand-in
	local tag = old:FindFirstChild("NameTag", true)
	local head = rig:FindFirstChild("Head") :: BasePart?
	if tag and head then
		(tag :: BillboardGui).Adornee = head
		tag.Parent = head
	end
	local thermos = old:FindFirstChild("Thermos") :: BasePart?
	local hand = rig:FindFirstChild("RightHand") :: BasePart?
	rig.Parent = old.Parent
	-- stand on the same spot: the old model's lowest point is the floor
	rig:PivotTo(CFrame.new(base.Position.X, floorY + hum.HipHeight + root.Size.Y / 2, base.Position.Z) * (base - base.Position))
	if thermos and hand then
		for _, n in ipairs({ "Thermos", "ThermosCap" }) do
			local p = old:FindFirstChild(n) :: BasePart?
			if p then
				p.Anchored = false
				p.CFrame = hand.CFrame * CFrame.new(0, -0.2 - (n == "ThermosCap" and -0.45 or 0), -0.1) * CFrame.Angles(0, 0, math.pi / 2)
				local w = Instance.new("WeldConstraint")
				w.Part0 = hand
				w.Part1 = p
				w.Parent = p
				p.Parent = rig
			end
		end
	end
	express(rig, spec.expression)
	old:Destroy()
end

-- Bots: a real R15 rig (moves + animates) wearing either real assets or the realistic
-- part-built body welded on limb by limb.
local SKIN = { "#E2B99A", "#C99A74", "#B07A56", "#8C5A3C", "#5E3C28", "#D8AC8A" }
local CLOTH = { "#4A4D52", "#55504A", "#5E5446", "#3E5458", "#5A3A3A", "#3E4A3A", "#6A5A44", "#2E3036", "#4E5A66", "#6A5640" }
local PANTS = { "#2E3036", "#3A3A3C", "#4E4C46", "#3E3128", "#46423A" }
local HAIR = { "#2A1E16", "#4A3424", "#8A6A44", "#1A1A1A", "#6A3A22", "#7A746A" }

function LookService.standIn(name: string, rng: Random): Model?
	local S = Look.STAND_IN
	local function any(list: { number }): number
		return #list > 0 and list[rng:NextInteger(1, #list)] or 0
	end
	local ok, rig = pcall(function()
		local d = Instance.new("HumanoidDescription")
		local body = #S.bodies > 0 and S.bodies[rng:NextInteger(1, #S.bodies)] or nil
		if body then
			d.Torso, d.LeftArm, d.RightArm, d.LeftLeg, d.RightLeg = body.torso, body.leftArm, body.rightArm, body.leftLeg, body.rightLeg
			d.Head = any(S.dynamicHeads) ~= 0 and any(S.dynamicHeads) or body.head
			d.HairAccessory = tostring(any(S.hair))
			local layered: { any } = {}
			local pools: { { number } } = { S.tops, S.bottoms, S.shoes }
			local kinds: { Enum.AccessoryType } = { Enum.AccessoryType.Jacket, Enum.AccessoryType.Pants, Enum.AccessoryType.LeftShoe }
			for k = 1, 3 do
				local id = any(pools[k])
				if id ~= 0 then
					table.insert(layered, { Order = k, AssetId = id, AccessoryType = kinds[k], IsLayered = true })
				end
			end
			if #layered > 0 then
				d:SetAccessories(layered, true)
			end
		end
		local skin = Color3.fromHex(SKIN[rng:NextInteger(1, #SKIN)])
		d.HeadColor, d.TorsoColor, d.LeftArmColor, d.RightArmColor, d.LeftLegColor, d.RightLegColor = skin, skin, skin, skin, skin, skin
		d.HeightScale = rng:NextNumber(S.scales.height[1], S.scales.height[2])
		d.WidthScale = rng:NextNumber(S.scales.width[1], S.scales.width[2])
		d.DepthScale = d.WidthScale
		d.HeadScale = S.scales.head
		d.BodyTypeScale = S.scales.bodyType
		d.ProportionScale = rng:NextNumber(S.scales.proportion[1], S.scales.proportion[2])
		local m = Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
		m:SetAttribute("RealAssets", body ~= nil)
		return m
	end)
	if not ok or not rig then
		return nil
	end
	rig.Name = name
	if rig:GetAttribute("RealAssets") then
		return rig
	end
	-- dress the rig in the realistic part-built body
	local hum = rig:FindFirstChildOfClass("Humanoid")
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root then
		return rig
	end
	MapBuilder.setEnv(ENV)
	local hip = hum.HipHeight + root.Size.Y / 2
	local s = math.clamp((hum.HipHeight + 0.2) / 3.0, 0.7, 1.05)
	local feet = root.CFrame * CFrame.new(0, -hip, 0)
	local holder = Instance.new("Folder")
	local body = MapBuilder.npc(holder, "Body", feet, {
		skin = SKIN[rng:NextInteger(1, #SKIN)],
		shirt = CLOTH[rng:NextInteger(1, #CLOTH)],
		pants = PANTS[rng:NextInteger(1, #PANTS)],
		coat = rng:NextNumber() < 0.5 and CLOTH[rng:NextInteger(1, #CLOTH)] or nil,
		hair = HAIR[rng:NextInteger(1, #HAIR)],
		hairStyle = ({ "short", "messy", "long", "bun", "slick", "short" })[rng:NextInteger(1, 6)],
		stubble = rng:NextNumber() < 0.3 and "#3A2E24" or nil,
		boots = rng:NextNumber() < 0.6,
		expr = ({ "neutral", "stern", "wry" })[rng:NextInteger(1, 3)],
		build = ({ "lean", "average", "broad" })[rng:NextInteger(1, 3)],
		scale = s,
	})
	local inv = feet:Inverse()
	for _, p in ipairs(body:GetDescendants()) do
		if p:IsA("BasePart") then
			local lp = inv * p.Position
			local target = rig:FindFirstChild(Look.limbFor(p.Name, lp.X / s, lp.Y / s)) :: BasePart?
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			if target then
				local w = Instance.new("WeldConstraint")
				w.Part0 = target
				w.Part1 = p
				w.Parent = p
			end
		end
	end
	for _, p in ipairs(rig:GetDescendants()) do
		if (p:IsA("BasePart") and p.Name ~= "HumanoidRootPart") or p:IsA("Decal") then
			(p :: any).Transparency = 1
		end
	end
	body.PrimaryPart = nil
	body.Parent = rig
	return rig
end

local function applyMaterials()
	for name, v in pairs(Look.MATERIALS) do
		if v.colorMap ~= "" then
			pcall(function()
				local mv = Instance.new("MaterialVariant")
				mv.Name = name
				mv.BaseMaterial = (Enum.Material :: any)[v.base]
				mv.ColorMap = v.colorMap
				mv.NormalMap = v.normalMap
				mv.RoughnessMap = v.roughnessMap
				mv.MetalnessMap = v.metalnessMap
				mv.StudsPerTile = v.studsPerTile
				mv.Parent = MaterialService
				MaterialService:SetBaseMaterialOverride(mv.BaseMaterial, name)
			end)
		end
	end
end

-- Arena ground -> Terrain grass (with animated grass decoration).
local function terrainGround()
	local terrain = workspace.Terrain
	pcall(function()
		terrain.Decoration = true
		for mat, hex in pairs(Look.TERRAIN) do
			terrain:SetMaterialColor((Enum.Material :: any)[mat], Color3.fromHex(hex))
		end
	end)
	local map = workspace:FindFirstChild("Map")
	local ground = map and map:FindFirstChild("Arena") and (map :: any).Arena:FindFirstChild("Ground")
	if not ground then
		return
	end
	local n = 0
	for _, tile in ipairs(ground:GetChildren()) do
		if tile:IsA("BasePart") and tile.Name == "Tile" then
			local mat = tile.Material == Enum.Material.LeafyGrass and Enum.Material.Grass or tile.Material
			local ok = pcall(function()
				terrain:FillBlock(tile.CFrame, tile.Size, mat)
			end)
			if ok then
				tile:Destroy()
			end
			n += 1
			if n % 8 == 0 then
				task.wait()
			end
		end
	end
	-- the meadow and its inner disc become grass too (blades show through)
	local meadow = map and (map :: any).Arena:FindFirstChild("GildedMeadow")
	if meadow then
		for _, nm in ipairs({ "Meadow", "MeadowInner" }) do
			local d = meadow:FindFirstChild(nm) :: BasePart?
			if d then
				d.Transparency = 1
			end
		end
	end
end

local function nudge(player: Player)
	player.CharacterAppearanceLoaded:Connect(function(char: Model)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum or char:GetAttribute("ScaleNudged") then
			return
		end
		char:SetAttribute("ScaleNudged", true)
		pcall(function()
			local d = hum:GetAppliedDescription()
			local h, w, hd, bt, pr, changed = Look.clampScales(d.HeightScale, d.WidthScale, d.HeadScale, d.BodyTypeScale, d.ProportionScale)
			if changed then
				d.HeightScale, d.WidthScale, d.DepthScale, d.HeadScale, d.BodyTypeScale, d.ProportionScale = h, w, math.max(d.DepthScale, w), hd, bt, pr
				hum:ApplyDescriptionAsync(d)
			end
		end)
	end)
end

function LookService.start()
	applyMaterials()
	local map = workspace:FindFirstChild("Map")
	if map then
		for _, m in ipairs(map:GetDescendants()) do
			if m:IsA("Model") and m:GetAttribute("LookId") then
				upgradeNpc(m)
			end
		end
	end
	if Look.terrainGrass then
		task.spawn(terrainGround)
	end
	if Look.nudgeAvatars then
		Players.PlayerAdded:Connect(nudge)
		for _, p in ipairs(Players:GetPlayers()) do
			nudge(p)
		end
	end
end

return LookService

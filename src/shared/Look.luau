--!strict
--[[
	Look — the realism asset spec, in code. Every ID here is 0 until Mike drops real assets in
	from Studio / the Creator Store (we can't upload meshes from the build box). PUBLISHING.md
	has the same table with what to search for and where each one goes.

	What happens at runtime (LookService):
	  * NPCs (Rusty, Herald Marigold Vane, Monty Gleam): if `body` IDs are set, the part-built
	    stand-in is swapped for a real R15 rig made from a HumanoidDescription: realistic body
	    bundle parts, a Dynamic Head (FACS expressions via FaceControls) and layered clothing.
	    With IDs still 0 they keep the realistic part-built body from MapBuilder.npc.
	  * Stand-Ins (bots): always a real R15 rig (so they walk and animate). With no body IDs the
	    rig is hidden and the realistic part-built body is welded onto it limb by limb, so they
	    never look like default blocky mannequins.
	  * MaterialVariants: created and set as base-material overrides when a colorMap is set.
	  * Ground: converted to Terrain grass (animated grass blades) when `terrainGrass` is on.
	  * Player avatars: scales nudged toward realistic proportions (`playerScales`).
]]
local Look = {}

-- Turn the realism runtime features on/off.
Look.terrainGrass = true -- swap the arena's ground tiles for Terrain grass with decoration
Look.nudgeAvatars = true -- clamp player avatar scales toward realistic proportions

-- Player avatar scale clamps (Roblox ranges: Height 0.9–1.05, Width 0.7–1, Head 0.95–1,
-- BodyType 0–1 (1 = Rthro / realistic), Proportion 0–1 (0 = classic, 1 = slender)).
Look.playerScales = {
	bodyTypeMin = 0.6,
	headMax = 1.0,
	headMin = 0.95,
	widthMin = 0.85,
	proportionMax = 0.5,
}

export type Expression = { [string]: number } -- FaceControls property -> 0..1
export type NpcSpec = {
	-- body parts from a realistic body bundle (e.g. a Rthro / "realistic" bundle): asset IDs
	body: { head: number, torso: number, leftArm: number, rightArm: number, leftLeg: number, rightLeg: number },
	dynamicHead: number, -- a Dynamic Head asset (has FaceControls for FACS expressions)
	hair: { number }, -- hair accessories (layered or rigid)
	layered: { { id: number, kind: string, order: number } }, -- layered clothing: Shirt, Jacket, Pants, Shoes...
	accessories: { number }, -- rigid accessories (hat, glasses, thermos handle...)
	idle: number, -- idle animation asset (0 = default)
	skin: string,
	scales: { height: number, width: number, head: number, bodyType: number, proportion: number },
	expression: Expression,
}

local function blankBody()
	return { head = 0, torso = 0, leftArm = 0, rightArm = 0, leftLeg = 0, rightLeg = 0 }
end

Look.NPCS = {
	-- Rusty Dunmore: scruffy mentor, 40s. Search: "realistic man body", "stubble beard",
	-- "messy grown-out hair", "open plaid flannel jacket (layered)", "faded tee (layered)",
	-- "work boots (layered)", "worn jeans (layered)".
	Rusty = {
		body = blankBody(),
		dynamicHead = 0,
		hair = { 0 },
		layered = { { id = 0, kind = "TShirt", order = 1 }, { id = 0, kind = "Jacket", order = 3 }, { id = 0, kind = "Pants", order = 2 }, { id = 0, kind = "Shoes", order = 1 } },
		accessories = { 0 },
		idle = 0,
		skin = "#C49272",
		scales = { height = 1.03, width = 0.97, head = 0.95, bodyType = 1, proportion = 0.2 },
		expression = { LeftLipCornerPuller = 0.35, RightLipCornerPuller = 0.1, LeftBrowLowerer = 0.15, RightOuterBrowRaiser = 0.2 },
	},
	-- Herald Marigold Vane: Capital escort. Search: "realistic woman body", "copper hair bun",
	-- "tailored long coat (layered)", "pearl necklace", "heeled boots (layered)".
	Herald = {
		body = blankBody(),
		dynamicHead = 0,
		hair = { 0 },
		layered = { { id = 0, kind = "Shirt", order = 1 }, { id = 0, kind = "Jacket", order = 3 }, { id = 0, kind = "Pants", order = 2 }, { id = 0, kind = "Shoes", order = 1 } },
		accessories = { 0 },
		idle = 0,
		skin = "#E2B99A",
		scales = { height = 0.98, width = 0.88, head = 0.95, bodyType = 1, proportion = 0.6 },
		expression = { LeftLipCornerPuller = 0.6, RightLipCornerPuller = 0.6, LeftCheekRaiser = 0.2, RightCheekRaiser = 0.2 },
	},
	-- Monty Gleam: TV host, 50s. Search: "realistic man body", "slicked-back grey hair",
	-- "suit jacket (layered)", "dress shirt and tie (layered)", "suit trousers", "oxford shoes".
	Monty = {
		body = blankBody(),
		dynamicHead = 0,
		hair = { 0 },
		layered = { { id = 0, kind = "Shirt", order = 1 }, { id = 0, kind = "Jacket", order = 3 }, { id = 0, kind = "Pants", order = 2 }, { id = 0, kind = "Shoes", order = 1 } },
		accessories = { 0 },
		idle = 0,
		skin = "#B98466",
		scales = { height = 1.04, width = 0.92, head = 0.95, bodyType = 1, proportion = 0.4 },
		expression = { LeftLipCornerPuller = 0.8, RightLipCornerPuller = 0.8, LeftCheekRaiser = 0.4, RightCheekRaiser = 0.4, JawDrop = 0.1 },
	},
} :: { [string]: NpcSpec }

-- Stand-In bots: pools mixed per bot. Add several of each so the field looks varied.
Look.STAND_IN = {
	bodies = {} :: { { head: number, torso: number, leftArm: number, rightArm: number, leftLeg: number, rightLeg: number } },
	dynamicHeads = {} :: { number },
	hair = {} :: { number },
	tops = {} :: { number }, -- layered jackets / shirts
	bottoms = {} :: { number }, -- layered pants
	shoes = {} :: { number }, -- layered shoes / boots
	scales = { height = { 0.96, 1.05 }, width = { 0.85, 1 }, head = 0.95, bodyType = 1, proportion = { 0.1, 0.5 } },
}

-- PBR MaterialVariants (texture IDs from the Creator Store "PBR" packs or your own scans).
export type Variant = { base: string, colorMap: string, normalMap: string, roughnessMap: string, metalnessMap: string, studsPerTile: number }
Look.MATERIALS = {
	WeatheredWood = { base = "WoodPlanks", colorMap = "", normalMap = "", roughnessMap = "", metalnessMap = "", studsPerTile = 8 },
	RustedMetal = { base = "CorrodedMetal", colorMap = "", normalMap = "", roughnessMap = "", metalnessMap = "", studsPerTile = 6 },
	WornStone = { base = "Limestone", colorMap = "", normalMap = "", roughnessMap = "", metalnessMap = "", studsPerTile = 10 },
	OldCobbles = { base = "Cobblestone", colorMap = "", normalMap = "", roughnessMap = "", metalnessMap = "", studsPerTile = 10 },
	MeadowGrass = { base = "LeafyGrass", colorMap = "", normalMap = "", roughnessMap = "", metalnessMap = "", studsPerTile = 12 },
	TrailDirt = { base = "Mud", colorMap = "", normalMap = "", roughnessMap = "", metalnessMap = "", studsPerTile = 12 },
} :: { [string]: Variant }

-- Terrain colors once the ground is converted (desaturated, filmic).
Look.TERRAIN = {
	Grass = "#6B7247",
	Ground = "#5E5A50",
	Mud = "#5A5246",
	LeafyGrass = "#6E7448",
}

-- Optional vegetation meshes (MeshPart asset IDs) to replace the part-built tufts/bushes/trees.
Look.VEGETATION = { grassClump = 0, fern = 0, bush = 0, pine = 0, oak = 0, reeds = 0 }

-- Does a spec have real assets yet?
function Look.hasBody(b: { head: number, torso: number, leftArm: number, rightArm: number, leftLeg: number, rightLeg: number }?): boolean
	return b ~= nil and b.torso ~= 0 and b.leftLeg ~= 0 and b.rightLeg ~= 0
end

-- Clamp avatar scales toward realistic proportions. Returns the new values and whether any changed.
function Look.clampScales(height: number, width: number, head: number, bodyType: number, proportion: number): (number, number, number, number, number, boolean)
	local P = Look.playerScales
	local nh = height
	local nw = math.max(width, P.widthMin)
	local nhead = math.clamp(head, P.headMin, P.headMax)
	local nb = math.max(bodyType, P.bodyTypeMin)
	local np = math.min(proportion, P.proportionMax)
	local changed = nw ~= width or nhead ~= head or nb ~= bodyType or np ~= proportion
	return nh, nw, nhead, nb, np, changed
end

-- Which R15 limb a part of the part-built body should follow (for welding onto a rig).
-- `x`, `y` are in body space (feet at y = 0, body ~6 units tall, -x = left).
function Look.limbFor(name: string, x: number, y: number): string
	for _, limb in ipairs({ "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot", "UpperTorso", "LowerTorso", "Head" }) do
		if string.sub(name, 1, #limb) == limb then
			return limb
		end
	end
	if y >= 5.0 then
		return "Head"
	elseif y >= 3.5 then
		return "UpperTorso"
	elseif y >= 2.75 or math.abs(x) < 0.12 then
		return "LowerTorso"
	end
	local side = x < 0 and "Left" or "Right"
	if y >= 1.6 then
		return side .. "UpperLeg"
	elseif y >= 0.36 then
		return side .. "LowerLeg"
	end
	return side .. "Foot"
end

return Look

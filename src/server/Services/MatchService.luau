--!strict
--[[
	MatchService — the Jubilee loop, all in one server for v1:
	  Lobby/Queue -> Pregame (reaping cutscene, parade, interview, training; played on clients)
	  -> Launch (10 s frozen on lift plates around the Sundial) -> Arena (12:00 cap)
	  -> Podium -> "Next match in 10s" (auto-queue keeps your play streak going).
	Humans fill first; labeled Stand-In bots fill the rest of the 48 plates.
	Every hit is validated here (range, arc/line of sight, cooldown, ammo, partner immunity).
	Knockouts are stylized: the contender lights up gold and dissolves into light. No gore.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Names = require(Shared.Names)
local Content = require(Shared.Content)
local Veil = require(Shared.Logic.Veil)
local Queue = require(Shared.Logic.Queue)
local Combat = require(Shared.Logic.Combat)
local Loot = require(Shared.Logic.Loot)
local Twists = require(Shared.Logic.Twists)
local NearMiss = require(Shared.Logic.NearMiss)
local TimeUtil = require(Shared.Logic.TimeUtil)

local MatchService = {}
local ctx: any = nil
local rng = Random.new()

export type Contender = {
	id: string,
	kind: string, -- "human" | "bot"
	player: Player?,
	name: string,
	reach: string,
	partner: string?,
	model: Model?,
	pep: number,
	alive: boolean,
	place: number?,
	knocks: number,
	crates: number,
	tokens: number,
	inv: { string },
	slots: number,
	ammo: number,
	equipped: number,
	lastUse: { [string]: number },
	lastHitBy: string?,
	lastHitWeapon: string?,
	lastHitDist: number?,
	encore: boolean,
	slowUntil: number,
	knockedAt: number?,
	awarded: boolean,
}

MatchService.state = "Lobby"
MatchService.contenders = {} :: { [string]: Contender }
MatchService.order = {} :: { string }
MatchService.radius = Config.Map.ARENA_SIZE / 2
MatchService.t = 0
MatchService.twist = nil :: any
MatchService.weekly = nil :: any
MatchService.hazard = nil :: string?
MatchService.matchNo = 0

local queue: { Player } = {}
local queueSince = 0
local forceLaunchAt: number? = nil
local partnerOf: { [Player]: Player } = {}
local invites: { [Player]: Player } = {} -- invitee -> inviter
local byModel: { [Model]: string } = {}
local arenaStart = 0
local phases: { Veil.Phase } = Config.VeilPhases
local veilPanels: { BasePart } = {}
local tokenFolder: Folder? = nil
local hazardState: any = {}
local rustyGiftGiven = false
local stateEndsAt = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function map(): any
	return workspace:WaitForChild("Map")
end

function MatchService.rootOf(c: Contender): BasePart?
	local m = c.model
	if not m then
		return nil
	end
	return (m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart) :: BasePart?
end

function MatchService.contenderOf(player: Player): Contender?
	return MatchService.contenders["u" .. player.UserId]
end

function MatchService.aliveCount(): number
	local n = 0
	for _, c in pairs(MatchService.contenders) do
		if c.alive then
			n += 1
		end
	end
	return n
end

local function matchHumans(): { Player }
	local out = {}
	for _, c in pairs(MatchService.contenders) do
		if c.player and c.player.Parent then
			table.insert(out, c.player)
		end
	end
	return out
end

local function pushMatch(kind: string, payload: any)
	-- everyone in the server sees the live match (lobby screens + Gallery)
	ctx.pushAll(kind, payload)
end

local function inQueue(p: Player): boolean
	return table.find(queue, p) ~= nil
end

-- ===================== inventory + held item visuals =====================
local function setHeld(c: Contender)
	local m = c.model
	if not m then
		return
	end
	local old = m:FindFirstChild("Held")
	if old then
		old:Destroy()
	end
	local item = c.inv[c.equipped]
	if not item then
		return
	end
	local hand = (m:FindFirstChild("RightHand") or m:FindFirstChild("Right Arm") or MatchService.rootOf(c)) :: BasePart?
	if not hand then
		return
	end
	local p = Instance.new("Part")
	p.Name = "Held"
	p.CanCollide = false
	p.CanQuery = false
	p.Massless = true
	p.Material = Enum.Material.Wood
	if item == "bow" then
		p.Size = Vector3.new(0.3, 4.2, 0.6)
		p.Color = Color3.fromHex("#7A4E2A")
	elseif item == "spear" then
		p.Size = Vector3.new(0.3, 7, 0.3)
		p.Color = Color3.fromHex("#8A6A3A")
	elseif item == "knife" then
		p.Size = Vector3.new(0.2, 1.4, 0.4)
		p.Color = Color3.fromHex("#BFC6CF")
		p.Material = Enum.Material.Metal
	else
		p.Size = Vector3.new(0.8, 0.8, 0.8)
		p.Color = Color3.fromHex("#D4A72C")
		p.Shape = Enum.PartType.Ball
	end
	p.CFrame = hand.CFrame * CFrame.new(0, -0.6, -0.3)
	local w = Instance.new("WeldConstraint")
	w.Part0 = hand
	w.Part1 = p
	w.Parent = p
	p.Parent = m
end

local function pushInv(c: Contender)
	if c.player then
		ctx.push(c.player, "inv", { inv = c.inv, slots = c.slots, ammo = c.ammo, equipped = c.equipped, pep = c.pep })
	end
end

-- Adds an item. Returns false when the backpack is full.
function MatchService.give(c: Contender, item: string): boolean
	local def = Config.Items[item]
	if not def then
		return false
	end
	if def.kind == "ammo" then
		c.ammo += def.ammo or 6
	elseif def.kind == "backpack" then
		c.slots = math.max(c.slots, Config.BACKPACK_SLOTS_BIG)
	else
		if #c.inv >= c.slots then
			return false
		end
		table.insert(c.inv, item)
		if def.kind == "weapon" and item == "bow" then
			c.ammo += 4
		end
		if #c.inv == 1 or (def.kind == "weapon" and not Config.Items[c.inv[c.equipped] or ""]) then
			c.equipped = #c.inv
		end
	end
	setHeld(c)
	pushInv(c)
	return true
end

local function itemName(item: string): string
	local d = Config.Items[item]
	return d and d.name or item
end

-- ===================== damage + knockouts =====================
local function fadeColor(c: Contender): Color3
	local fade = "fade_gold"
	if c.player then
		local data = ctx.Progress.dataOf(c.player)
		if data and data.equipped and Content.FADES[data.equipped.fade] then
			fade = data.equipped.fade
		end
	end
	return Color3.fromHex(Content.FADES[fade].color)
end

-- The knockout effect: glow, float a little, dissolve into a column of light.
local function dissolve(c: Contender)
	local m = c.model
	if not m then
		return
	end
	local color = fadeColor(c)
	local h = Instance.new("Highlight")
	h.FillColor = color
	h.OutlineColor = Color3.new(1, 1, 1)
	h.FillTransparency = 0.15
	h.Parent = m
	local root = MatchService.rootOf(c)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			TweenService:Create(d, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		elseif d:IsA("Decal") then
			TweenService:Create(d, TweenInfo.new(1.8), { Transparency = 1 }):Play()
		end
	end
	if root then
		local beam = Instance.new("Part")
		beam.Name = "LightColumn"
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.Material = Enum.Material.Neon
		beam.Color = color
		beam.Shape = Enum.PartType.Cylinder
		beam.Size = Vector3.new(2, 3, 3)
		beam.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, 0, math.pi / 2)
		beam.Transparency = 0.2
		beam.Parent = workspace
		TweenService:Create(beam, TweenInfo.new(2.2), { Size = Vector3.new(120, 1, 1), CFrame = CFrame.new(root.Position + Vector3.new(0, 60, 0)) * CFrame.Angles(0, 0, math.pi / 2), Transparency = 1 }):Play()
		task.delay(2.4, function()
			beam:Destroy()
		end)
	end
end

local function toGallery(player: Player)
	task.spawn(function()
		player:LoadCharacterAsync()
		local char = player.Character or player.CharacterAdded:Wait()
		local spawn = map():FindFirstChild("ViewingGallery") and map().ViewingGallery:FindFirstChild("GallerySpawn")
		if spawn then
			char:PivotTo((spawn :: BasePart).CFrame * CFrame.new(rng:NextNumber(-20, 20), 4, rng:NextNumber(-10, 10)))
		end
		ctx.Gallery.addSpectator(player)
	end)
end

local endIfDone: () -> () -- assigned below

function MatchService.knockout(c: Contender, cause: string)
	if not c.alive then
		return
	end
	local place = MatchService.aliveCount()
	c.alive = false
	c.place = place
	c.knockedAt = now()
	local attacker = c.lastHitBy and MatchService.contenders[c.lastHitBy] or nil
	if attacker and attacker ~= c then
		attacker.knocks += 1
		if attacker.player then
			ctx.Progress.bump(attacker.player, "knocks", 1)
			if c.lastHitWeapon == "bow" then
				ctx.Progress.bump(attacker.player, "bowknocks", 1)
			end
			ctx.push(attacker.player, "knocked", { name = c.name, reach = c.reach, left = place - 1 })
		end
	end
	dissolve(c)
	pushMatch("feed", {
		victim = c.name,
		by = attacker and attacker.name or nil,
		cause = cause,
		weapon = c.lastHitWeapon,
		left = place - 1,
	})
	local root = MatchService.rootOf(c)
	if c.player then
		local player = c.player
		-- "How you got tapped": a kill-cam replay of the last hit + the near-miss card
		local aroot = attacker and MatchService.rootOf(attacker) or nil
		local leader: Contender? = nil
		for _, o in pairs(MatchService.contenders) do
			if o.alive and (leader == nil or o.pep > leader.pep) then
				leader = o
			end
		end
		local result = ctx.Progress.award(player, {
			place = place,
			size = Config.MATCH_SIZE,
			knocks = c.knocks,
			crates = c.crates,
			tokens = c.tokens,
			gifts = 0,
			votes = 0,
			encore = false,
			survived = MatchService.t,
			partner = c.partner ~= nil and string.sub(c.partner, 1, 1) == "u",
			bonusStars = Twists.mod({ MatchService.weekly }, "bonusStars", 0),
		})
		c.awarded = true
		local data = ctx.Progress.dataOf(player)
		local nm = {
			place = place,
			size = Config.MATCH_SIZE,
			knocks = c.knocks,
			survived = MatchService.t,
			bestPlace = result.prevBest or 0,
			nextKnockGoal = ctx.Progress.nextGoal(player, "knocks"),
			winnerPepLeft = place == 2 and leader and leader.pep or nil,
		}
		ctx.push(player, "eliminated", {
			headline = NearMiss.headline(nm),
			lines = NearMiss.lines(nm),
			cause = cause,
			by = attacker and attacker.name or nil,
			byReach = attacker and attacker.reach or nil,
			byPep = attacker and attacker.pep or nil,
			weapon = c.lastHitWeapon and itemName(c.lastHitWeapon) or nil,
			dist = c.lastHitDist,
			from = aroot and aroot.Position or nil,
			at = root and root.Position or nil,
			byModel = attacker and attacker.model or nil,
			place = place,
			result = result,
			autoQueue = data and data.settings.autoQueue or false,
		})
		task.delay(3.2, function()
			if player.Parent then
				toGallery(player)
			end
		end)
	else
		local m = c.model
		task.delay(2.5, function()
			if m then
				byModel[m] = nil
				m:Destroy()
			end
		end)
		c.model = nil
	end
	endIfDone()
end

function MatchService.damage(target: Contender, amount: number, attacker: Contender?, weapon: string, dist: number?)
	if not target.alive or MatchService.state ~= "Arena" then
		return
	end
	if attacker and attacker ~= target then
		if not attacker.alive then
			return
		end
		if not Combat.canHurt(attacker.reach, target.reach, MatchService.aliveCount(), Config.ALLIES_UNTIL) then
			return
		end
		target.lastHitBy = attacker.id
		target.lastHitWeapon = weapon
		target.lastHitDist = dist
		if attacker.player then
			ctx.push(attacker.player, "hitmark", { amount = amount, name = target.name })
		end
	elseif weapon == "veil" or weapon == "finches" or weapon == "bloom" then
		target.lastHitWeapon = weapon
	end
	local pep, ko = Combat.hit(target.pep, amount)
	target.pep = pep
	if target.player then
		ctx.push(target.player, "pep", { pep = pep, from = weapon })
	end
	if ko then
		local cause = weapon
		if weapon == "veil" then
			cause = "touched " .. Names.VEIL
		elseif weapon == "finches" then
			cause = "chased by " .. Names.FINCHES
		elseif weapon == "bloom" then
			cause = "caught in the " .. Names.BLOOM
		end
		MatchService.knockout(target, cause)
	end
end

-- ===================== attacks (humans via the "use" action, bots via BotService) =====================
function MatchService.attack(c: Contender, wid: string, aim: Vector3?): boolean
	local w = Config.Weapons[wid]
	if not w or not c.alive or MatchService.state ~= "Arena" then
		return false
	end
	local t = now()
	if not Combat.ready(c.lastUse[wid], t, w.cooldown) then
		return false
	end
	local root = MatchService.rootOf(c)
	if not root then
		return false
	end
	c.lastUse[wid] = t
	local mult = c.kind == "bot" and Config.Bots.damageMult or 1
	if w.kind == "ranged" then
		if c.ammo <= 0 then
			if c.player then
				ctx.toast(c.player, "Out of arrows! Find a crate or ask the Gallery.", "info")
			end
			return false
		end
		c.ammo -= 1
		local range = w.range * Twists.mod({ MatchService.twist }, "bowRange", 1)
		local origin = root.Position + Vector3.new(0, 1.6, 0)
		local target = aim or (origin + root.CFrame.LookVector * range)
		local dir = target - origin
		if dir.Magnitude < 0.1 then
			dir = root.CFrame.LookVector
		end
		dir = dir.Unit * range
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { c.model :: any, map().Arena.Veil }
		local hit = workspace:Raycast(origin, dir, params)
		local to = hit and hit.Position or (origin + dir)
		pushMatch("tracer", { from = origin, to = to })
		if hit then
			local m = hit.Instance:FindFirstAncestorOfClass("Model")
			while m and not byModel[m] do
				m = m:FindFirstAncestorOfClass("Model")
			end
			local id = m and byModel[m]
			local victim = id and MatchService.contenders[id]
			if victim and victim ~= c then
				local d = (to - origin).Magnitude
				MatchService.damage(victim, math.floor(Combat.bowDamage(w.damage, d, range) * mult + 0.5), c, wid, math.floor(d))
			end
		end
		pushInv(c)
		return true
	end
	-- melee: nearest valid target in the arc in front
	local look = root.CFrame.LookVector
	if aim then
		local d = aim - root.Position
		if Vector3.new(d.X, 0, d.Z).Magnitude > 0.5 then
			look = d.Unit
		end
	end
	local best: Contender? = nil
	local bestD = math.huge
	for _, o in pairs(MatchService.contenders) do
		if o ~= c and o.alive then
			local orr = MatchService.rootOf(o)
			if orr then
				local d = (orr.Position - root.Position).Magnitude
				if d <= w.range + 2 and d < bestD then
					local a = root.Position
					local b = orr.Position
					if Combat.inArc({ x = a.X, y = a.Y, z = a.Z }, { x = look.X, y = 0, z = look.Z }, { x = b.X, y = b.Y, z = b.Z }, w.arc or 70) then
						best, bestD = o, d
					end
				end
			end
		end
	end
	pushMatch("swing", { id = c.id, weapon = wid })
	if best then
		MatchService.damage(best, math.floor(w.damage * mult + 0.5), c, wid, math.floor(bestD))
	end
	return true
end

function MatchService.eat(c: Contender, slot: number): boolean
	local item = c.inv[slot]
	local def = item and Config.Items[item]
	if not def or def.kind ~= "snack" then
		return false
	end
	table.remove(c.inv, slot)
	c.equipped = math.clamp(c.equipped, 1, math.max(1, #c.inv))
	c.pep = math.min(Config.PEP_MAX, c.pep + (def.heal or 0))
	if c.player then
		ctx.Progress.bump(c.player, "snacks", 1)
		ctx.push(c.player, "pep", { pep = c.pep, from = "snack" })
	end
	setHeld(c)
	pushInv(c)
	return true
end

-- Use the equipped slot: weapon -> attack, snack -> eat, nothing -> shove.
function MatchService.use(c: Contender, aim: Vector3?): boolean
	local item = c.inv[c.equipped]
	local def = item and Config.Items[item]
	if def and def.kind == "weapon" and def.weapon then
		return MatchService.attack(c, def.weapon, aim)
	elseif def and def.kind == "snack" then
		return MatchService.eat(c, c.equipped)
	end
	return MatchService.attack(c, "shove", aim)
end

-- ===================== crates + tokens =====================
local function lootTable(kind: string): { [string]: number }
	local t: { [string]: number } = Config.LootField
	if kind == "hub" then
		t = Config.LootHub
	elseif kind == "meadow" then
		t = Config.LootMeadow
	end
	local snacks = Twists.mod({ MatchService.twist }, "snacks", 1)
	if snacks == 1 then
		return t
	end
	local out: { [string]: number } = {}
	for k, v in pairs(t) do
		local d = Config.Items[k]
		out[k] = (d and d.kind == "snack") and v * snacks or v
	end
	return out
end

function MatchService.openCrate(c: Contender, crate: BasePart): boolean
	if MatchService.state ~= "Arena" or not c.alive or crate:GetAttribute("Opened") then
		return false
	end
	local root = MatchService.rootOf(c)
	if not root or (root.Position - crate.Position).Magnitude > 14 then
		return false
	end
	local kind = tostring(crate:GetAttribute("Loot") or "field")
	local item = Loot.pick(lootTable(kind), rng:NextNumber())
	if not MatchService.give(c, item) then
		if c.player then
			ctx.toast(c.player, "Backpack full! Drop or eat something first.", "info")
		end
		return false
	end
	crate:SetAttribute("Opened", true)
	crate.Transparency = 0.7
	local pp = crate:FindFirstChildOfClass("ProximityPrompt")
	if pp then
		pp.Enabled = false
	end
	c.crates += 1
	if c.player then
		ctx.Progress.bump(c.player, "crates", 1)
		if kind == "hub" then
			ctx.Progress.bump(c.player, "hubloot", 1)
		elseif kind == "meadow" then
			ctx.Progress.bump(c.player, "meadow", 1)
		end
		ctx.push(c.player, "loot", { item = item, name = itemName(item) })
	end
	return true
end

local function allCrates(): { BasePart }
	local out = {}
	for _, f in ipairs({ "HubCrates", "FieldCrates", "MeadowCrates" }) do
		local folder = map().Arena:FindFirstChild(f)
		if folder then
			for _, p in ipairs(folder:GetChildren()) do
				if p:IsA("BasePart") and p:GetAttribute("Crate") then
					table.insert(out, p)
				end
			end
		end
	end
	return out
end
MatchService.allCrates = allCrates

local function resetCrates()
	for _, p in ipairs(allCrates()) do
		p:SetAttribute("Opened", nil)
		p.Transparency = 0
		local pp = p:FindFirstChildOfClass("ProximityPrompt")
		if pp then
			pp.Enabled = true
		end
	end
end

local function spawnTokens()
	if tokenFolder then
		tokenFolder:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "Tokens"
	f.Parent = map().Arena
	tokenFolder = f
	local spots = map().Arena.TokenSpots:GetChildren()
	local n = math.floor(Twists.mod({ MatchService.weekly }, "tokens", Config.TOKENS_PER_MATCH))
	local template = (ServerStorage:FindFirstChild("Templates") :: any).Token
	for _ = 1, math.min(n, #spots) do
		local i = rng:NextInteger(1, #spots)
		local spot = table.remove(spots, i) :: BasePart
		local idx = spot:GetAttribute("TokenIndex") :: number
		local def = Content.TOKENS[idx]
		local tk = template:Clone()
		tk:PivotTo(spot.CFrame * CFrame.Angles(0, 0, math.pi / 2))
		local coin = tk.PrimaryPart :: BasePart
		coin.Anchored = true
		coin.CanTouch = true
		coin.Size = Vector3.new(0.6, 3.2, 3.2)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromHex("#FFD36B")
		light.Range = 14
		light.Parent = coin
		tk:SetAttribute("TokenId", def.id)
		tk.Parent = f
		local taken = false
		coin.Touched:Connect(function(hit: BasePart)
			if taken then
				return
			end
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			local c = player and MatchService.contenderOf(player)
			if not player or not c or not c.alive then
				return
			end
			taken = true
			tk:Destroy()
			c.tokens += 1
			local data = ctx.Progress.dataOf(player)
			local isNew = data and not data.tokens[def.id]
			if data then
				data.tokens[def.id] = true
			end
			ctx.Progress.bump(player, "tokens", 1)
			ctx.push(player, "token", { name = def.name, new = isNew })
		end)
	end
end

-- ===================== Veil + hazards =====================
local function setVeil(radius: number)
	MatchService.radius = radius
	local n = #veilPanels
	if n == 0 then
		return
	end
	local r = math.max(radius, 2)
	local w = 2 * math.pi * r / n * 1.06
	for i, p in ipairs(veilPanels) do
		local a = (i - 0.5) / n * math.pi * 2
		local pos = Vector3.new(math.cos(a) * r, 300, math.sin(a) * r)
		p.Size = Vector3.new(math.max(w, 0.5), 640, 1)
		p.CFrame = CFrame.lookAt(pos, Vector3.new(0, 300, 0))
		p.Transparency = radius <= 1 and 1 or 0.1
	end
end

function MatchService.startHazard(id: string)
	if MatchService.state ~= "Arena" then
		return
	end
	local H = Config.Hazards
	if id == "supply" then
		for _ = 1, H.supply.crates do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(20, math.min(200, MatchService.radius * 0.6))
			ctx.Gallery.dropCrate(Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		end
		pushMatch("hazard", { id = id, name = "Supply Drop", text = "Three parachute crates are falling near " .. Names.HUB .. "!" })
		return
	end
	if hazardState[id] then
		return
	end
	if id == "finches" then
		-- target the biggest group of alive contenders
		local best: Contender? = nil
		local bestN = -1
		for _, c in pairs(MatchService.contenders) do
			local r = if c.alive then MatchService.rootOf(c) else nil
			if r then
				local n = 0
				for _, o in pairs(MatchService.contenders) do
					local orr = if o.alive then MatchService.rootOf(o) else nil
					if orr and (orr.Position - r.Position).Magnitude < 80 then
						n += 1
					end
				end
				if n > bestN then
					best, bestN = c, n
				end
			end
		end
		local target = best and MatchService.rootOf(best)
		if not target then
			return
		end
		local center = target.Position + Vector3.new(rng:NextNumber(-60, 60), 0, rng:NextNumber(-60, 60))
		local folder = Instance.new("Folder")
		folder.Name = "Candyfinches"
		folder.Parent = workspace
		local template = (ServerStorage:FindFirstChild("Templates") :: any).Candyfinch
		local birds = {}
		for i = 1, H.finches.birds do
			local b = template:Clone()
			b:SetAttribute("Phase", i / H.finches.birds * math.pi * 2)
			b.Parent = folder
			table.insert(birds, b)
		end
		hazardState.finches = { center = center, target = best and best.id, untilT = now() + H.finches.warn + H.finches.duration, startT = now() + H.finches.warn, folder = folder, birds = birds }
		pushMatch("hazard", { id = id, name = Names.FINCHES, text = "A sugary flock is coming! Spread out.", warn = H.finches.warn, at = center })
	elseif id == "bloom" then
		hazardState.bloom = { untilT = now() + H.bloom.warn + H.bloom.duration, startT = now() + H.bloom.warn }
		for _, e in ipairs(map().Arena.GildedMeadow:GetChildren()) do
			local pe = e:FindFirstChild("Pollen")
			if pe then
				(pe :: ParticleEmitter).Enabled = true
			end
		end
		pushMatch("hazard", { id = id, name = Names.BLOOM, text = "Gilded pollen is rising in " .. Names.MEADOW .. ". Get out!", warn = H.bloom.warn })
	end
end

local function stopHazards()
	local f = hazardState.finches
	if f and f.folder then
		f.folder:Destroy()
	end
	hazardState = {}
	local ok, meadow = pcall(function()
		return map().Arena.GildedMeadow
	end)
	if ok and meadow then
		for _, e in ipairs(meadow:GetChildren()) do
			local pe = e:FindFirstChild("Pollen")
			if pe then
				(pe :: ParticleEmitter).Enabled = false
			end
		end
	end
end

local lastSecond = 0
local function tickHazards(dt: number, wholeSecond: boolean)
	local t = now()
	local H = Config.Hazards
	local f = hazardState.finches
	if f then
		if t > f.untilT then
			f.folder:Destroy()
			hazardState.finches = nil
		else
			local tgt = f.target and MatchService.contenders[f.target]
			local tr = tgt and if tgt.alive then MatchService.rootOf(tgt) else nil
			if t >= f.startT and tr then
				local d = tr.Position - f.center
				local step = math.min(d.Magnitude, H.finches.speed * dt)
				if d.Magnitude > 0.1 then
					f.center += d.Unit * step
				end
			end
			for i, b in ipairs(f.birds) do
				local ph = (b:GetAttribute("Phase") or i) + t * 3
				local r = H.finches.radius * 0.6
				local pos = f.center + Vector3.new(math.cos(ph) * r, 8 + math.sin(ph * 2) * 3, math.sin(ph) * r)
				b:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(-math.sin(ph), 0, math.cos(ph))))
			end
			if wholeSecond and t >= f.startT then
				for _, c in pairs(MatchService.contenders) do
					local r = if c.alive then MatchService.rootOf(c) else nil
					if r and (Vector3.new(r.Position.X, 0, r.Position.Z) - Vector3.new(f.center.X, 0, f.center.Z)).Magnitude < H.finches.radius then
						MatchService.damage(c, H.finches.dps, nil, "finches", nil)
					end
				end
			end
		end
	end
	local b = hazardState.bloom
	if b then
		if t > b.untilT then
			stopHazards()
		elseif t >= b.startT then
			local M = Config.Map.MEADOW
			for _, c in pairs(MatchService.contenders) do
				local r = if c.alive then MatchService.rootOf(c) else nil
				if r then
					local dx, dz = r.Position.X - M.x, r.Position.Z - M.z
					if dx * dx + dz * dz < M.r * M.r then
						c.slowUntil = t + 1.2
						if wholeSecond then
							MatchService.damage(c, H.bloom.dps, nil, "bloom", nil)
						end
					end
				end
			end
		end
	end
end

-- ===================== state machine =====================
local function clearArena()
	stopHazards()
	for _, c in pairs(MatchService.contenders) do
		if c.kind == "bot" and c.model then
			c.model:Destroy()
		end
	end
	byModel = {}
	MatchService.contenders = {}
	MatchService.order = {}
	if tokenFolder then
		tokenFolder:Destroy()
		tokenFolder = nil
	end
	resetCrates()
	setVeil(Config.Map.ARENA_SIZE / 2)
	Lighting.ClockTime = 6.4
	workspace.Gravity = 196.2
end

local function lobbyStatus()
	local humans = #queue
	local waited = now() - queueSince
	local secs = Queue.secondsLeft(humans, waited, Config.MATCH_SIZE, Config.Matchmaking, not Config.Matchmaking.crossServer)
	if forceLaunchAt and humans > 0 then
		secs = math.max(0, forceLaunchAt - now())
	end
	for _, p in ipairs(Players:GetPlayers()) do
		local partner = partnerOf[p]
		ctx.push(p, "lobby", {
			state = MatchService.state,
			queued = humans,
			size = Config.MATCH_SIZE,
			seconds = secs,
			inQueue = inQueue(p),
			partner = partner and partner.DisplayName or nil,
			invite = invites[p] and invites[p].DisplayName or nil,
			inviteFrom = invites[p] and invites[p].UserId or nil,
			weekly = MatchService.weekly,
			alive = MatchService.state == "Arena" and MatchService.aliveCount() or nil,
			t = MatchService.t,
		})
	end
end

local function startPregame()
	MatchService.matchNo += 1
	local wk = TimeUtil.week(os.time())
	MatchService.weekly = Twists.weekly(wk)
	MatchService.twist = Twists.forMatch(MatchService.matchNo, wk)
	local humans = {}
	for _, p in ipairs(queue) do
		if p.Parent and #humans < Config.MATCH_SIZE then
			table.insert(humans, p)
		end
	end
	queue = {}
	forceLaunchAt = nil
	local entries = {}
	local byId: { [string]: Player } = {}
	for _, p in ipairs(humans) do
		local data = ctx.Progress.dataOf(p)
		local partner = partnerOf[p]
		local id = "u" .. p.UserId
		byId[id] = p
		table.insert(entries, {
			id = id,
			reach = data and data.reach ~= "" and data.reach or nil,
			partner = partner and table.find(humans, partner) and ("u" .. partner.UserId) or nil,
		})
	end
	local botIds = {}
	for i = 1, Config.MATCH_SIZE - #humans do
		table.insert(botIds, "b" .. i)
	end
	local slots = Queue.assign(entries, botIds, Names.REACH_LIST, Config.PER_REACH)
	local names = table.clone(Content.BOT_NAMES)
	MatchService.contenders = {}
	MatchService.order = {}
	for _, s in ipairs(slots) do
		local p = byId[s.id]
		local nm: string
		if p then
			nm = p.DisplayName
		else
			nm = table.remove(names, rng:NextInteger(1, #names)) or "Rowan"
		end
		MatchService.contenders[s.id] = {
			id = s.id,
			kind = p and "human" or "bot",
			player = p,
			name = p and nm or (Names.BOT_TAG .. " · " .. nm),
			reach = s.reach,
			partner = s.partner,
			model = nil,
			pep = Config.PEP_MAX,
			alive = true,
			place = nil,
			knocks = 0,
			crates = 0,
			tokens = 0,
			inv = {},
			slots = Config.BACKPACK_SLOTS,
			ammo = 0,
			equipped = 1,
			lastUse = {},
			encore = false,
			slowUntil = 0,
			awarded = false,
		}
		table.insert(MatchService.order, s.id)
	end
	-- pregame length: full reaping if anyone hasn't seen it yet
	local anyNew = false
	for _, p in ipairs(humans) do
		local data = ctx.Progress.dataOf(p)
		if data and not data.seenReaping and not data.settings.shortReaping then
			anyNew = true
		end
	end
	local P = Config.Pregame
	local total = Config.pregameTotal() - (anyNew and 0 or (P.reaping - P.reapingShort))
	MatchService.state = "Pregame"
	stateEndsAt = now() + total
	local roster = {}
	for _, id in ipairs(MatchService.order) do
		local c = MatchService.contenders[id]
		table.insert(roster, { name = c.name, reach = c.reach, bot = c.kind == "bot" })
	end
	for _, p in ipairs(humans) do
		local c = MatchService.contenders["u" .. p.UserId]
		local data = ctx.Progress.dataOf(p)
		local partner = c and c.partner and MatchService.contenders[c.partner]
		ctx.push(p, "pregame", {
			seconds = total,
			reach = c and c.reach,
			partnerName = partner and partner.name or nil,
			short = data and (data.seenReaping or data.settings.shortReaping) or false,
			roster = roster,
			twist = MatchService.twist,
			weekly = MatchService.weekly,
			quip = data and Content.QUIPS[data.quip] or Content.QUIPS[1],
			humans = #humans,
		})
	end
	pushMatch("matchStart", { humans = #humans, bots = #botIds, twist = MatchService.twist })
end

local function startLaunch()
	MatchService.state = "Launch"
	stateEndsAt = now() + Config.Pregame.launch
	-- twist effects
	local tw = MatchService.twist
	if tw then
		if tw.mods.clock then
			Lighting.ClockTime = tw.mods.clock
		end
		if tw.mods.gravity then
			workspace.Gravity = 196.2 * tw.mods.gravity
		end
		phases = Veil.scaled(Config.VeilPhases, tw.mods.veil or 1)
	else
		phases = Config.VeilPhases
	end
	setVeil(Config.Map.ARENA_SIZE / 2)
	local plates = map().Arena.LiftPlates
	for i, id in ipairs(MatchService.order) do
		local c = MatchService.contenders[id]
		local plate = plates:FindFirstChild(string.format("Plate%02d", i)) :: BasePart?
		local cf = plate and (CFrame.lookAt(plate.Position + Vector3.new(0, 4, 0), Vector3.new(0, plate.Position.Y + 4, 0))) or CFrame.new(0, 10, 0)
		if c.player then
			local char = c.player.Character
			if not char or not char.Parent then
				c.player:LoadCharacterAsync()
				char = c.player.Character
			end
			if char then
				char:PivotTo(cf)
				c.model = char
				byModel[char] = c.id
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.BreakJointsOnDeath = false
					hum.Died:Connect(function()
						if c.alive and MatchService.state == "Arena" then
							MatchService.knockout(c, "a long fall")
						end
					end)
				end
				local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp then
					hrp.Anchored = true
				end
				char:SetAttribute("SpeedMult", 1)
			end
			if ctx.Progress.hasPass(c.player, "StarterSatchel") and not Config.RANKED then
				MatchService.give(c, "apple")
				MatchService.give(c, "canteen")
			end
			pushInv(c)
		else
			local m = ctx.Bots.spawn(c, cf)
			c.model = m
			if m then
				byModel[m] = c.id
			end
		end
	end
	resetCrates()
	spawnTokens()
	rustyGiftGiven = false
	pushMatch("launch", { seconds = Config.Pregame.launch, twist = MatchService.twist })
end

local function startArena()
	MatchService.state = "Arena"
	arenaStart = now()
	MatchService.t = 0
	stateEndsAt = arenaStart + Config.HARD_CAP
	for _, c in pairs(MatchService.contenders) do
		if c.player and c.model then
			local hrp = c.model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				hrp.Anchored = false
			end
		end
	end
	ctx.Gallery.onArenaStart()
	ctx.Bots.onArenaStart()
	pushMatch("arena", { size = Config.MATCH_SIZE })
end

local function startPodium()
	MatchService.state = "Podium"
	stateEndsAt = now() + Config.PODIUM_SECONDS
	-- the winner is the last one standing (or the highest Pep at the hard cap)
	local winner: Contender? = nil
	for _, c in pairs(MatchService.contenders) do
		if c.alive and (winner == nil or c.pep > winner.pep) then
			winner = c
		end
	end
	local alive = {}
	for _, c in pairs(MatchService.contenders) do
		if c.alive and c ~= winner then
			table.insert(alive, c)
		end
	end
	table.sort(alive, function(a: Contender, b: Contender): boolean
		return a.pep > b.pep
	end)
	for i, c in ipairs(alive) do
		c.place = i + 1
		c.alive = false
	end
	local podium = {}
	if winner then
		winner.place = 1
		winner.alive = false
	end
	local all = {}
	for _, c in pairs(MatchService.contenders) do
		table.insert(all, c)
	end
	table.sort(all, function(a: Contender, b: Contender): boolean
		return (a.place or 99) < (b.place or 99)
	end)
	for i = 1, math.min(3, #all) do
		table.insert(podium, { name = all[i].name, reach = all[i].reach, place = all[i].place, knocks = all[i].knocks })
	end
	for _, c in ipairs(all) do
		if c.player and c.player.Parent and not c.awarded then
			c.awarded = true
			local data = ctx.Progress.dataOf(c.player)
			local prevBest = data and data.stats.bestPlace or 0
			local result = ctx.Progress.award(c.player, {
				place = c.place or 2,
				size = Config.MATCH_SIZE,
				knocks = c.knocks,
				crates = c.crates,
				tokens = c.tokens,
				gifts = 0,
				votes = 0,
				encore = c.encore,
				survived = MatchService.t,
				partner = c.partner ~= nil and string.sub(c.partner, 1, 1) == "u",
				bonusStars = Twists.mod({ MatchService.weekly }, "bonusStars", 0),
			})
			local nm = { place = c.place or 2, size = Config.MATCH_SIZE, knocks = c.knocks, survived = MatchService.t, bestPlace = prevBest, nextKnockGoal = ctx.Progress.nextGoal(c.player, "knocks"), winnerPepLeft = winner and winner.pep }
			ctx.push(c.player, "finished", { headline = NearMiss.headline(nm), lines = NearMiss.lines(nm), place = c.place, result = result })
		end
	end
	pushMatch("podium", { podium = podium, winner = winner and winner.name or "", reach = winner and winner.reach or "", next = Config.PODIUM_SECONDS + Config.Matchmaking.nextMatchSeconds })
	ctx.Gallery.onArenaEnd()
	ctx.Bots.onArenaEnd()
end

local function backToLobby()
	local players = matchHumans()
	clearArena()
	MatchService.state = "Lobby"
	MatchService.t = 0
	for _, p in ipairs(Players:GetPlayers()) do
		ctx.Gallery.removeSpectator(p)
	end
	for _, p in ipairs(players) do
		task.spawn(function()
			p:LoadCharacterAsync()
		end)
	end
	-- auto-queue: everyone with auto-queue on goes straight back in; the next match starts in 10s
	for _, p in ipairs(Players:GetPlayers()) do
		local data = ctx.Progress.dataOf(p)
		local was = table.find(players, p) ~= nil
		if data and data.settings.autoQueue and (was or inQueue(p)) and not inQueue(p) then
			table.insert(queue, p)
		end
	end
	queueSince = now()
	if #queue > 0 then
		forceLaunchAt = now() + Config.Matchmaking.nextMatchSeconds
	end
	pushMatch("requeue", { seconds = Config.Matchmaking.nextMatchSeconds, queued = #queue })
end

endIfDone = function()
	if MatchService.state ~= "Arena" then
		return
	end
	local alive = MatchService.aliveCount()
	if alive <= 1 then
		task.defer(startPodium)
	end
end

-- Encore: bring a knocked-out contender back with some Pep (GalleryService picks who).
function MatchService.revive(c: Contender): boolean
	if MatchService.state ~= "Arena" or c.alive then
		return false
	end
	local a = rng:NextNumber(0, math.pi * 2)
	local r = math.min(MatchService.radius * 0.5, 300)
	local pos = Vector3.new(math.cos(a) * r, 6, math.sin(a) * r)
	c.alive = true
	c.place = nil
	c.pep = Config.Encore.pep
	c.encore = true
	c.inv = {}
	c.slots = Config.BACKPACK_SLOTS
	c.equipped = 1
	MatchService.give(c, "knife")
	if c.player then
		local player = c.player
		ctx.Gallery.removeSpectator(player)
		local char = player.Character
		if char then
			char:PivotTo(CFrame.new(pos))
			c.model = char
			byModel[char] = c.id
		end
		ctx.Progress.bump(player, "encore", 1)
		ctx.push(player, "encore", { pep = c.pep })
		pushInv(c)
	else
		local m = ctx.Bots.spawn(c, CFrame.new(pos))
		c.model = m
		if m then
			byModel[m] = c.id
		end
	end
	pushMatch("feed", { victim = c.name, cause = "voted back in by " .. Names.GALLERY, encore = true, left = MatchService.aliveCount() })
	return true
end

-- ===================== intents =====================
local function joinQueue(player: Player): (boolean, string?)
	if MatchService.contenderOf(player) and MatchService.state ~= "Lobby" then
		return false, "You're in a match right now."
	end
	if inQueue(player) then
		return true, nil
	end
	table.insert(queue, player)
	if #queue == 1 then
		queueSince = now()
	end
	lobbyStatus()
	if MatchService.state ~= "Lobby" then
		return true, "Queued! You'll go in the next " .. Names.EVENT_SHORT .. "."
	end
	return true, "Queued for " .. Names.DRAW .. "!"
end

local function leaveQueue(player: Player): (boolean, string?)
	local i = table.find(queue, player)
	if i then
		table.remove(queue, i)
	end
	lobbyStatus()
	return true, "Left the queue."
end

local function invite(player: Player, userId: any): (boolean, string?)
	if type(userId) ~= "number" then
		return false, nil
	end
	local other = Players:GetPlayerByUserId(userId)
	if not other or other == player then
		return false, "They're not in this server."
	end
	if invites[player] == other then
		-- they already invited us: accept
		partnerOf[player] = other
		partnerOf[other] = player
		invites[player] = nil
		ctx.toast(other, player.DisplayName .. " is your partner! Same " .. Names.REGION .. ", side by side.", "good")
		lobbyStatus()
		return true, "Partnered with " .. other.DisplayName .. "!"
	end
	invites[other] = player
	ctx.toast(other, player.DisplayName .. " wants to partner up. Open Partner to accept.", "info")
	lobbyStatus()
	return true, "Invite sent."
end

local function unpartner(player: Player): (boolean, string?)
	local o = partnerOf[player]
	partnerOf[player] = nil
	if o then
		partnerOf[o] = nil
		ctx.toast(o, player.DisplayName .. " left your partnership.", "info")
	end
	lobbyStatus()
	return true, nil
end

local function use(player: Player, aim: any): (boolean, string?)
	local c = MatchService.contenderOf(player)
	if not c or not c.alive or MatchService.state ~= "Arena" then
		return false, nil
	end
	local a = typeof(aim) == "Vector3" and aim or nil
	return MatchService.use(c, a), nil
end

local function equipSlot(player: Player, i: any): (boolean, string?)
	local c = MatchService.contenderOf(player)
	if not c or type(i) ~= "number" or not c.inv[i] then
		return false, nil
	end
	c.equipped = math.floor(i)
	setHeld(c)
	pushInv(c)
	return true, nil
end

local function drop(player: Player, i: any): (boolean, string?)
	local c = MatchService.contenderOf(player)
	if not c or type(i) ~= "number" or not c.inv[i] then
		return false, nil
	end
	table.remove(c.inv, i)
	c.equipped = math.clamp(c.equipped, 1, math.max(1, #c.inv))
	setHeld(c)
	pushInv(c)
	return true, nil
end

local function watch(player: Player): (boolean, string?)
	if MatchService.state ~= "Arena" then
		return false, "No live " .. Names.EVENT_SHORT .. " to watch right now."
	end
	local c = MatchService.contenderOf(player)
	if c and c.alive then
		return false, nil
	end
	toGallery(player)
	return true, "Welcome to " .. Names.GALLERY .. "!"
end

local function training(_player: Player, score: any): (boolean, string?)
	if type(score) ~= "number" then
		return false, nil
	end
	local s = math.clamp(math.floor(score), 0, 12)
	return true, string.format("%s rates your training a %d out of 12.", Names.MENTOR_SHORT, s)
end

function MatchService.onLeave(player: Player)
	local i = table.find(queue, player)
	if i then
		table.remove(queue, i)
	end
	local o = partnerOf[player]
	if o then
		partnerOf[o] = nil
	end
	partnerOf[player] = nil
	invites[player] = nil
	local c = MatchService.contenderOf(player)
	if c and c.alive and MatchService.state == "Arena" then
		MatchService.knockout(c, "left the arena")
	end
	if c then
		c.player = nil
	end
end

function MatchService.init(c: any)
	ctx = c
	ctx.handle("queue", joinQueue)
	ctx.handle("leave", leaveQueue)
	ctx.handle("invite", invite)
	ctx.handle("unpartner", unpartner)
	ctx.handle("use", use)
	ctx.handle("equipSlot", equipSlot)
	ctx.handle("drop", drop)
	ctx.handle("watch", watch)
	ctx.handle("training", training)
end

function MatchService.start()
	-- templates move out of Workspace so they aren't visible
	local tpl = map():FindFirstChild("Templates")
	if tpl then
		tpl.Parent = ServerStorage
	end
	for _, p in ipairs(map().Arena.Veil:GetChildren()) do
		if p:IsA("BasePart") then
			table.insert(veilPanels, p)
		end
	end
	table.sort(veilPanels, function(a: BasePart, b: BasePart): boolean
		return ((a:GetAttribute("Angle") or 0) :: number) < ((b:GetAttribute("Angle") or 0) :: number)
	end)
	-- crate prompts
	for _, crate in ipairs(allCrates()) do
		local pp = crate:FindFirstChildOfClass("ProximityPrompt")
		if pp then
			pp.Triggered:Connect(function(player: Player)
				local c = MatchService.contenderOf(player)
				if c then
					MatchService.openCrate(c, crate)
				end
			end)
		end
	end
	-- lobby prompts
	local lobby = map().Lobby
	for _, d in ipairs(lobby:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			d.Triggered:Connect(function(player: Player)
				local kind = d:GetAttribute("Kind")
				if kind == "queue" then
					local ok, msg = joinQueue(player)
					if msg then
						ctx.toast(player, msg, ok and "good" or "info")
					end
				else
					ctx.push(player, "openPanel", { kind = kind })
				end
			end)
		end
	end
	-- main loop
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.25)
			local t0 = os.clock()
			local dt = t0 - last
			last = t0
			local ok, err = pcall(function()
				local t = now()
				local wholeSecond = math.floor(t) ~= lastSecond
				lastSecond = math.floor(t)
				if MatchService.state == "Lobby" then
					-- drop players who left
					for i = #queue, 1, -1 do
						if not queue[i].Parent then
							table.remove(queue, i)
						end
					end
					local go = false
					if forceLaunchAt and #queue > 0 then
						go = t >= forceLaunchAt
					else
						go = Queue.shouldLaunch(#queue, t - queueSince, Config.MATCH_SIZE, Config.Matchmaking, not Config.Matchmaking.crossServer)
					end
					if go then
						startPregame()
					elseif wholeSecond then
						lobbyStatus()
					end
				elseif MatchService.state == "Pregame" then
					if t >= stateEndsAt then
						startLaunch()
					end
				elseif MatchService.state == "Launch" then
					if t >= stateEndsAt then
						startArena()
					end
				elseif MatchService.state == "Arena" then
					MatchService.t = t - arenaStart
					local r = Veil.radiusAt(MatchService.t, phases, Config.Map.ARENA_SIZE / 2)
					if math.abs(r - MatchService.radius) > 0.05 then
						setVeil(r)
					end
					tickHazards(dt, wholeSecond)
					if wholeSecond then
						local dmg = Veil.damage(MatchService.t, phases, Config.VEIL_DAMAGE)
						for _, c in pairs(MatchService.contenders) do
							local root = if c.alive then MatchService.rootOf(c) else nil
							if root then
								if Veil.outside(root.Position.X, root.Position.Z, MatchService.radius) then
									MatchService.damage(c, dmg, nil, "veil", nil)
								end
								if c.model then
									c.model:SetAttribute("SpeedMult", c.slowUntil > t and Config.Hazards.bloom.slow or 1)
								end
							end
						end
						-- scheduled hazards (Finch Day doubles the flock)
						for _, h in ipairs(Config.Hazards.scheduled) do
							if math.floor(MatchService.t) == h.at then
								MatchService.startHazard(h.id)
							end
						end
						if MatchService.twist and MatchService.twist.mods.finches and math.floor(MatchService.t) == 450 then
							MatchService.startHazard("finches")
						end
						-- Rusty's gift at the final 8
						if not rustyGiftGiven and MatchService.aliveCount() <= Config.RUSTY_GIFT_AT then
							local low: Contender? = nil
							for _, c in pairs(MatchService.contenders) do
								if c.alive and c.player and (low == nil or c.pep < low.pep) then
									low = c
								end
							end
							if low then
								rustyGiftGiven = true
								ctx.Gallery.dropGift(low, "sweettea", Names.MENTOR_SHORT, Content.RUSTY.gift)
							end
						end
						local nextIn, target = Veil.nextShrink(MatchService.t, phases)
						pushMatch("match", {
							t = MatchService.t,
							alive = MatchService.aliveCount(),
							radius = MatchService.radius,
							nextIn = nextIn,
							target = target,
							shrinking = Veil.isShrinking(MatchService.t, phases),
							twist = MatchService.twist and MatchService.twist.name,
						})
						if t >= stateEndsAt then
							startPodium()
						end
					end
				elseif MatchService.state == "Podium" then
					if t >= stateEndsAt then
						backToLobby()
					end
				end
			end)
			if not ok then
				warn("[MatchService] " .. tostring(err))
			end
		end
	end)
end

return MatchService

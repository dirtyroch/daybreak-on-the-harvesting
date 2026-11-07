--!strict
--[[
	MatchService — the Jubilee loop, all in one server for v1:
	  Lobby/Queue -> Pregame (reaping cutscene, parade, interview, training; played on clients)
	  -> Launch (10 s frozen on lift plates around the Sundial) -> Arena (12:00 cap)
	  -> Podium -> "Next match in 10s" (auto-queue keeps your play streak going).
	Humans fill first; labeled Stand-In bots fill the rest of the 48 plates.
	Every hit is validated here (range, arc/line of sight, cooldown, ammo, partner + pact immunity).
	v2: pacts with a telegraphed Pact Snap, server-owned stamina + speed check, Food/Water meters,
	the spear throw (bounces off the Veil) and the Veil Breaker finale, the real pregame training
	round, and the Encore top-up so a voted-back contender is paid for their best finish once.
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
local Pacts = require(Shared.Logic.Pacts)
local Training = require(Shared.Logic.Training)
local Stamina = require(Shared.Logic.Stamina)
local Meters = require(Shared.Logic.Meters)
local Throw = require(Shared.Logic.Throw)
local Store = require(Shared.Store)
local Arms = require(Shared.Arms) :: any
local Mastery = require(Shared.Mastery)
local Offers = require(Shared.Offers)
local Finishers = require(Shared.Finishers)
local Modes = require(Shared.Logic.Modes)
local Party = require(Shared.Logic.Party)
local Onboarding = require(Shared.Logic.Onboarding)
local Events = require(Shared.Logic.Events)
local Moments = require(Shared.Logic.Moments)

-- Globals handed to shared builders (Arms) so the same code runs in Lune tests.
local E = {
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
	-- v2
	training: number?,
	quip: number?,
	stam: Stamina.S?,
	meters: Meters.M?,
	pactKept: boolean,
	firstResult: any?,
	toppedUp: boolean,
	lastGood: Vector3?,
	speedStrikes: number,
	lastHitBetrayal: boolean,
	-- v5
	veilBreaker: boolean?,
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
MatchService.mode = Modes.get(Modes.JUBILEE) -- v5: Jubilee or Quick Trials, picked per match
MatchService.archive = false -- v5: Founders' Dawn Archive Reel match
MatchService.party = Party.new() -- v5: friend/family parties of up to 10

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
local pacts = Pacts.new()
local pactsEnded = false
local trainingSeed = 1
local boardSent = false
local pregameStart = 0
local pregameShort = false
local veilShift = 0 -- seconds the Veil clock was paused (Veil Breaker calm)
local calmUntil = 0
local veilCore: BasePart? = nil
local coreAngle = 0
local veilBroken = false
local thrownFolder: Folder? = nil
local veilStepDone = false
local familyPartyAt: { [string]: number } = {} -- contender id -> party id (snapshot at match start)
local STAMINA_RULES: Stamina.Rules = { max = Config.STAMINA_MAX, drain = Config.STAMINA_DRAIN, regen = Config.STAMINA_REGEN, resume = Config.STAMINA_RESUME }

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

-- Reach partners until the final few, plus pacts.
function MatchService.canHurt(a: Contender, b: Contender): boolean
	if not Combat.canHurt(a.reach, b.reach, MatchService.aliveCount(), Config.ALLIES_UNTIL) then
		return false
	end
	-- v5 Family Rules (private servers, on by default): the whole party is allied until 4 are left
	local pa, pb = familyPartyAt[a.id], familyPartyAt[b.id]
	if pa and pa == pb and MatchService.aliveCount() > Config.ALLIES_UNTIL then
		return false
	end
	return Pacts.canHurt(pacts, a.id, b.id)
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
-- The equipped weapon skin and its Mastery level for a contender (bots use the default look).
local function looksOf(c: Contender, slot: string): (string, number)
	if not c.player then
		return "", 0
	end
	local data = ctx.Progress.dataOf(c.player)
	if not data or not data.equipped then
		return "", 0
	end
	local skin = data.equipped[slot] or ""
	local pts = data.mastery and data.mastery[Mastery.key(slot, skin)] or 0
	return skin, Mastery.level(pts)
end
MatchService.looksOf = looksOf

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
	-- v4: weapons are full part-built models per skin (Arms.luau), with Mastery trim on top
	if item == "bow" or item == "spear" or item == "knife" then
		local skin, lvl = looksOf(c, item)
		if Arms.attach(E, m, item, skin, lvl) then
			return
		end
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
	p.Size = Vector3.new(0.8, 0.8, 0.8)
	p.Color = Color3.fromHex("#D4A72C")
	p.Shape = Enum.PartType.Ball
	p.CFrame = hand.CFrame * CFrame.new(0, -0.6, -0.3)
	local w = Instance.new("WeldConstraint")
	w.Part0 = hand
	w.Part1 = p
	w.Parent = p
	p.Parent = m
end

-- Rebuild a player's held weapon (after a Mastery level-up or a Locker change).
function MatchService.refreshHeld(player: Player)
	local c = MatchService.contenderOf(player)
	if c and c.alive then
		setHeld(c)
	end
end

local function pushInv(c: Contender)
	if c.player then
		ctx.push(c.player, "inv", { inv = c.inv, slots = c.slots, ammo = c.ammo, equipped = c.equipped, pep = c.pep })
	end
end

local function pushPact(c: Contender)
	if not c.player then
		return
	end
	local names = {}
	for _, id in ipairs(Pacts.allies(pacts, c.id)) do
		local o = MatchService.contenders[id]
		if o then
			table.insert(names, o.name)
		end
	end
	local o = pacts.offers[c.id]
	local from = o and MatchService.contenders[o.from]
	ctx.push(c.player, "pact", {
		allies = names,
		offer = from and { name = from.name, reach = from.reach } or nil,
		snapping = pacts.snaps[c.id] ~= nil,
		ended = pactsEnded,
	})
end

local function pushPactsAll()
	for _, c in pairs(MatchService.contenders) do
		if c.alive and c.player then
			pushPact(c)
		end
	end
end

local vitalsAt: { [string]: number } = {}
local function pushVitals(c: Contender, force: boolean?)
	local st, m = c.stam, c.meters
	local t = os.clock()
	if not force and (vitalsAt[c.id] or 0) + 0.25 > t then
		return
	end
	vitalsAt[c.id] = t
	if c.player and st and m then
		ctx.push(c.player, "vitals", { stamina = st.value, tired = st.tired, sprinting = st.sprinting, food = m.food, water = m.water })
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
		if def.kind == "weapon" and c.player and MatchService.state == "Arena" then
			ctx.Progress.onboard(c.player, "weapon")
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
-- Cosmetic weapon skin color (Item Shop "Arms"). Same stats; only the streak color changes.
local function skinColor(c: Contender, slot: string): string?
	if not c.player then
		return nil
	end
	local data = ctx.Progress.dataOf(c.player)
	local id = data and data.equipped and data.equipped[slot]
	local it = id and Store.byId[id]
	return it and it.color or nil
end

-- Private-server rules (owner with Spire VIP). Public servers always use the seeded twist.
MatchService.psRules = { twist = "", noBetrayals = false, family = true }
local function isPrivate(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0
end
MatchService.isPrivate = isPrivate

-- v4: the KNOCKER's fade plays (so a fade is seen by the whole lobby every time it's used);
-- with no knocker (Veil, falls) the victim's own fade plays.
local function fadeOf(c: Contender, by: Contender?): string
	for _, who in ipairs({ by, c }) do
		if who and who.player then
			local data = ctx.Progress.dataOf(who.player)
			if data and data.equipped and Content.FADES[data.equipped.fade] then
				return data.equipped.fade
			end
		end
	end
	return "fade_gold"
end
MatchService.fadeOf = fadeOf

-- The knockout effect: glow, float a little, dissolve with the fade's animated finisher.
local function dissolve(c: Contender, by: Contender?)
	local m = c.model
	if not m then
		return
	end
	local fid = fadeOf(c, by)
	local f = Content.FADES[fid]
	local color = Color3.fromHex(f.color)
	local h = Instance.new("Highlight")
	h.FillColor = color
	h.OutlineColor = Color3.new(1, 1, 1)
	h.FillTransparency = 0.15
	h.Parent = m
	if f.style == "shimmer" then
		TweenService:Create(h, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 6, true), { FillTransparency = 0.7 }):Play()
	end
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
		Finishers.play(f.style, root.Position, color)
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

-- v5: the one share-worthy moment for a finished contender (or nil), with its launch data.
function MatchService.momentFor(c: Contender): any
	if not c.player then
		return nil
	end
	local best = true
	local pid = Party.partyOf(MatchService.party, c.player.UserId)
	if pid then
		for _, uid in ipairs(MatchService.party.members[pid] or {}) do
			local o = MatchService.contenders["u" .. uid]
			if o and o ~= c and (o.alive or (o.place or 99) < (c.place or 99)) then
				best = false
			end
		end
	else
		best = false
	end
	local m = Moments.pick({
		place = c.place or 99,
		knocks = c.knocks,
		veilBreaker = c.veilBreaker,
		encoreWon = c.encore and (c.place or 99) <= 5,
		archive = MatchService.archive,
		partyBest = best and MatchService.state == "Podium",
	})
	if not m then
		return nil
	end
	return { id = m.id, title = m.title, caption = m.caption, launch = Moments.launchData(c.player.UserId, m.id), place = c.place, knocks = c.knocks }
end

-- v5: one results card per party that played: everyone's place and the party's total knockouts.
function MatchService.sendPartyCards()
	local seen: { [number]: boolean } = {}
	for _, c in pairs(MatchService.contenders) do
		local pl = c.player
		local pid = pl and Party.partyOf(MatchService.party, pl.UserId)
		if pid and not seen[pid] then
			seen[pid] = true
			local lines = {}
			local who = {}
			for _, uid in ipairs(MatchService.party.members[pid] or {}) do
				local o = MatchService.contenders["u" .. uid]
				if o and o.player then
					table.insert(lines, { name = o.name, place = o.place or 99, knocks = o.knocks })
					table.insert(who, o.player)
				end
			end
			if #lines >= 2 then
				local sum = Party.summary(lines)
				for _, p in ipairs(who) do
					if p.Parent then
						ctx.push(p, "partyCard", { lines = sum.lines, knocks = sum.knocks, best = sum.best and sum.best.name or "" })
					end
				end
			end
		end
	end
end

function MatchService.knockout(c: Contender, cause: string)
	if not c.alive then
		return
	end
	local place = MatchService.aliveCount()
	c.alive = false
	c.place = place
	c.knockedAt = now()
	local wasAllies = Pacts.allies(pacts, c.id)
	Pacts.remove(pacts, c.id)
	for _, id in ipairs(wasAllies) do
		local a = MatchService.contenders[id]
		if a then
			pushPact(a)
		end
	end
	local attacker = c.lastHitBy and MatchService.contenders[c.lastHitBy] or nil
	if attacker and attacker ~= c then
		attacker.knocks += 1
		if attacker.player then
			ctx.Progress.bump(attacker.player, "knocks", 1)
			if c.lastHitWeapon == "bow" then
				ctx.Progress.bump(attacker.player, "bowknocks", 1)
			end
			local wpn = c.lastHitWeapon
			if wpn == "bow" or wpn == "spear" or wpn == "knife" then
				local skin = select(1, looksOf(attacker, wpn))
				ctx.Progress.addMastery(attacker.player, wpn, skin, Mastery.PER_KNOCK)
			end
			ctx.push(attacker.player, "knocked", { name = c.name, reach = c.reach, left = place - 1 })
		end
	end
	dissolve(c, attacker)
	local byStars = ""
	if attacker and c.lastHitWeapon then
		local _, lvl = looksOf(attacker, c.lastHitWeapon)
		byStars = lvl >= Mastery.MAX and "✦" or string.rep("★", lvl)
	end
	pushMatch("feed", {
		victim = c.name,
		by = attacker and attacker.name or nil,
		byStars = byStars ~= "" and byStars or nil,
		fade = attacker and attacker.player and fadeOf(c, attacker) or nil,
		fadeColor = attacker and attacker.player and Content.FADES[fadeOf(c, attacker)].color or nil,
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
		local r = {
			place = place,
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
			pactKept = c.pactKept,
			archive = MatchService.archive,
		}
		local result: any
		if c.awarded and c.firstResult then
			-- knocked out again after an Encore: pay only the difference
			result = ctx.Progress.topUp(player, c.firstResult, r)
			c.toppedUp = true
		else
			result = ctx.Progress.award(player, r)
			c.firstResult = r
		end
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
			betrayed = c.lastHitBetrayal,
			place = place,
			result = result,
			autoQueue = data and data.settings.autoQueue or false,
			preview = ctx.Purchase.previewFor(player, c.knocks),
			moment = MatchService.momentFor(c),
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
		if not MatchService.canHurt(attacker, target) then
			return
		end
		local mult, strike = Pacts.hitMult(pacts, Config.Pacts, attacker.id, target.id, now())
		-- v5: Stand-In bots go easier on a contender's first 3 matches (never real players)
		if attacker.kind == "bot" and target.player then
			local td = ctx.Progress.dataOf(target.player)
			mult *= Onboarding.botDamageMult(td and td.stats.matches or 0)
		end
		amount = math.max(1, math.floor(amount * mult + 0.5))
		target.lastHitBetrayal = strike
		if strike then
			-- the betrayal moment: everyone sees it, the victim gets a beat to react
			pushMatch("feed", { kind = "betrayal", victim = target.name, by = attacker.name, left = MatchService.aliveCount() })
			if target.player then
				ctx.push(target.player, "betrayed", { by = attacker.name, line = Content.RUSTY.snapped })
			end
		end
		target.lastHitBy = attacker.id
		target.lastHitWeapon = weapon
		target.lastHitDist = dist
		if attacker.player then
			ctx.push(attacker.player, "hitmark", { amount = amount, name = target.name })
		end
	elseif weapon == "veil" or weapon == "finches" or weapon == "bloom" then
		if weapon == "veil" and now() < calmUntil then
			return
		end
		target.lastHitWeapon = weapon
		target.lastHitBetrayal = false
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
		pushMatch("tracer", { from = origin, to = to, color = skinColor(c, "bow"), bright = select(2, looksOf(c, "bow")) >= 2, by = c.player and c.player.UserId or 0 })
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
	pushMatch("swing", { id = c.id, weapon = wid, at = root.Position, by = c.player and c.player.UserId or 0 })
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
	if c.stam and def.stamina then
		Stamina.add(c.stam, STAMINA_RULES, def.stamina)
	end
	if c.meters then
		Meters.eat(c.meters, Config.Meters, def.food, def.water)
	end
	pushVitals(c)
	if c.player then
		ctx.Progress.onboard(c.player, "eat")
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

-- ===================== spear throw + Veil Breaker =====================
local function placeCore()
	local core = veilCore
	if not core then
		return
	end
	local r = math.max(MatchService.radius - 1, 4)
	local pos = Vector3.new(math.cos(coreAngle) * r, 14, math.sin(coreAngle) * r)
	core.CFrame = CFrame.lookAt(pos, Vector3.new(0, 14, 0))
end

-- Final four: the Veil Core lights up on the wall.
local function lightCore()
	if veilCore or veilBroken then
		return
	end
	coreAngle = rng:NextNumber(0, math.pi * 2)
	local core = Instance.new("Part")
	core.Name = "VeilCore"
	core.Anchored = true
	core.CanCollide = false
	core.Shape = Enum.PartType.Ball
	core.Material = Enum.Material.Neon
	core.Color = Color3.fromHex("#9FF6FF")
	local sz = Config.VeilBreaker.coreSize
	core.Size = Vector3.new(sz, sz, sz)
	local light = Instance.new("PointLight")
	light.Color = core.Color
	light.Range = 40
	light.Brightness = 3
	light.Parent = core
	core.Parent = workspace
	veilCore = core
	placeCore()
	pushMatch("veilCore", { pos = core.Position })
end

local function breakVeil(by: Contender)
	if veilBroken then
		return
	end
	veilBroken = true
	calmUntil = now() + Config.VeilBreaker.calmSeconds
	stateEndsAt += Config.VeilBreaker.calmSeconds
	if veilCore then
		veilCore:Destroy()
		veilCore = nil
	end
	for _, p in ipairs(veilPanels) do
		p.Transparency = 0.7
	end
	by.veilBreaker = true
	pushMatch("veilBroken", { by = by.name, reach = by.reach, seconds = Config.VeilBreaker.calmSeconds })
	if by.player then
		ctx.Progress.grant(by.player, Config.VeilBreaker.title, "You shattered the dome! Title unlocked: " .. tostring(Content.TITLES[Config.VeilBreaker.title]))
		ctx.Progress.bump(by.player, "veilbreak", 1)
	end
end

-- The thrown spear lands as a pickup anyone can grab.
local function dropSpear(at: Vector3)
	if not thrownFolder then
		local f = Instance.new("Folder")
		f.Name = "ThrownSpears"
		f.Parent = workspace
		thrownFolder = f
	end
	local p = Instance.new("Part")
	p.Name = "ThrownSpear"
	p.Anchored = true
	p.CanCollide = false
	p.Size = Vector3.new(0.3, 7, 0.3)
	p.Color = Color3.fromHex("#8A6A3A")
	p.Material = Enum.Material.Wood
	p.CFrame = CFrame.new(at + Vector3.new(0, 2.5, 0)) * CFrame.Angles(math.rad(25), 0, 0)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "Pick up"
	pp.ObjectText = "Spear"
	pp.MaxActivationDistance = 10
	pp.Parent = p
	pp.Triggered:Connect(function(player: Player)
		local c = MatchService.contenderOf(player)
		if c and c.alive and p.Parent and MatchService.give(c, "spear") then
			p:Destroy()
		end
	end)
	p.Parent = thrownFolder
end

-- Throw the equipped spear. It flies flat, bounces off the Veil once, and hits the first
-- contender on its path. A bounced spear that crosses the lit Veil Core breaks the dome.
function MatchService.throw(c: Contender, aim: Vector3?): boolean
	local w = Config.Weapons.spearThrow
	if not c.alive or MatchService.state ~= "Arena" or c.inv[c.equipped] ~= "spear" then
		return false
	end
	local t = now()
	if not Combat.ready(c.lastUse.spearThrow, t, w.cooldown) then
		return false
	end
	local root = MatchService.rootOf(c)
	if not root then
		return false
	end
	c.lastUse.spearThrow = t
	table.remove(c.inv, c.equipped)
	c.equipped = math.clamp(c.equipped, 1, math.max(1, #c.inv))
	setHeld(c)
	pushInv(c)
	local origin = root.Position + Vector3.new(0, 1.6, 0)
	local dir = (aim and (aim - origin) or root.CFrame.LookVector)
	local legs = Throw.legs({ x = origin.X, z = origin.Z }, { x = dir.X, z = dir.Z }, w.range, MatchService.radius, Config.VeilBreaker.bounces)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { c.model :: any, map().Arena.Veil }
	local mult = c.kind == "bot" and Config.Bots.damageMult or 1
	local landed = origin
	for _, leg in ipairs(legs) do
		local a = Vector3.new(leg.from.x, origin.Y, leg.from.z)
		local b = Vector3.new(leg.to.x, origin.Y, leg.to.z)
		local hit = workspace:Raycast(a, b - a, params)
		local stop = hit and hit.Position or b
		pushMatch("tracer", { from = a, to = stop, spear = true, color = skinColor(c, "spear"), bright = select(2, looksOf(c, "spear")) >= 2, by = c.player and c.player.UserId or 0 })
		-- Veil Breaker: only a rebounded spear counts
		local core = veilCore
		if leg.bounced and core and Throw.segDist(leg.from, { x = stop.X, z = stop.Z }, { x = core.Position.X, z = core.Position.Z }) <= Config.VeilBreaker.coreSize * 0.6 then
			breakVeil(c)
		end
		landed = stop
		if hit then
			local m = hit.Instance:FindFirstAncestorOfClass("Model")
			while m and not byModel[m] do
				m = m:FindFirstAncestorOfClass("Model")
			end
			local id = m and byModel[m]
			local victim = id and MatchService.contenders[id]
			if victim and victim ~= c then
				MatchService.damage(victim, math.floor(w.damage * mult + 0.5), c, "spear", math.floor((stop - origin).Magnitude))
			end
			break
		end
	end
	dropSpear(Vector3.new(landed.X, 0, landed.Z))
	return true
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
		ctx.Progress.onboard(c.player, "crate")
		ctx.Progress.bump(c.player, "crates", 1)
		if kind == "hub" then
			ctx.Progress.bump(c.player, "hubloot", 1)
		elseif kind == "meadow" then
			ctx.Progress.bump(c.player, "meadow", 1)
		end
		ctx.push(c.player, "loot", { item = item, name = itemName(item) })
	end
	pushMatch("crate", { at = crate.Position })
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
		p.Transparency = radius <= 1 and 1 or (if now() < calmUntil then 0.7 else 0.1)
	end
	placeCore()
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
	if veilCore then
		veilCore:Destroy()
		veilCore = nil
	end
	if thrownFolder then
		thrownFolder:Destroy()
		thrownFolder = nil
	end
	pacts = Pacts.new()
	pactsEnded = false
	veilBroken = false
	calmUntil = 0
	veilShift = 0
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
	if isPrivate() and MatchService.psRules.twist ~= "" then
		for _, t in ipairs(Twists.MATCH) do
			if t.id == MatchService.psRules.twist then
				MatchService.twist = t
			end
		end
	end
	-- v5: parties are never split: a party goes in whole or waits for the next match
	local ids = {}
	local byUser: { [number]: Player } = {}
	for _, p in ipairs(queue) do
		if p.Parent then
			table.insert(ids, p.UserId)
			byUser[p.UserId] = p
		end
	end
	local humans = {}
	for _, uid in ipairs(Party.fill(MatchService.party, ids, Config.MATCH_SIZE)) do
		table.insert(humans, byUser[uid])
	end
	local left = {}
	for _, p in ipairs(queue) do
		if p.Parent and not table.find(humans, p) then
			table.insert(left, p)
		end
	end
	queue = left
	if #left > 0 then
		queueSince = now()
	end
	forceLaunchAt = nil
	-- v5: Quick Trials or the full Jubilee, by majority of the queued players' picks
	local prefs = {}
	for _, p in ipairs(humans) do
		local d = ctx.Progress.dataOf(p)
		table.insert(prefs, Modes.preferred(d and d.settings.mode or "", d and d.stats.matches or 0))
	end
	MatchService.mode = Modes.get(Modes.pick(prefs))
	local fest = Events.active(os.time())
	MatchService.archive = fest ~= nil and fest.id == "founders_dawn" and Events.isArchiveMatch(MatchService.matchNo)
	familyPartyAt = {}
	if isPrivate() and MatchService.psRules.family then
		for _, p in ipairs(humans) do
			local pid = Party.partyOf(MatchService.party, p.UserId)
			if pid then
				familyPartyAt["u" .. p.UserId] = pid
			end
		end
	end
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
			if MatchService.archive and s.id == botIds[1] then
				nm = "Young " .. Names.MENTOR_SHORT -- the Archive Reel: Rusty's own Trials, 25 years ago
			end
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
			pactKept = false,
			toppedUp = false,
			speedStrikes = 0,
			lastHitBetrayal = false,
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
	local quick = not MatchService.mode.ceremony
	if quick then
		total = Modes.pregame(MatchService.mode, total, P.reapingShort)
		anyNew = false
	end
	MatchService.state = "Pregame"
	pacts = Pacts.new()
	pactsEnded = false
	trainingSeed = MatchService.matchNo * 7919 + os.time() % 100000
	boardSent = quick -- Quick Trials skips the training round and its board
	veilStepDone = false
	pregameStart = now()
	pregameShort = not anyNew
	stateEndsAt = now() + total
	for _, id in ipairs(MatchService.order) do
		local c = MatchService.contenders[id]
		if c.kind == "bot" then
			c.training = Training.botScore(trainingSeed, c.id)
			c.quip = (TimeUtil.hash(trainingSeed + #c.id * 31 + string.byte(c.id, -1)) % #Content.QUIPS) + 1
		end
	end
	local roster = {}
	for _, id in ipairs(MatchService.order) do
		local c = MatchService.contenders[id]
		table.insert(roster, { name = c.name, reach = c.reach, bot = c.kind == "bot", quip = c.quip })
	end
	for _, p in ipairs(humans) do
		local c = MatchService.contenders["u" .. p.UserId]
		local data = ctx.Progress.dataOf(p)
		local partner = c and c.partner and MatchService.contenders[c.partner]
		if c then
			c.quip = data and data.quip or 1
		end
		ctx.push(p, "pregame", {
			seconds = total,
			reach = c and c.reach,
			partnerName = partner and partner.name or nil,
			short = data and (data.seenReaping or data.settings.shortReaping) or false,
			roster = roster,
			twist = MatchService.twist,
			weekly = MatchService.weekly,
			quip = data and Content.QUIPS[data.quip] or Content.QUIPS[1],
			quipIndex = data and data.quip or 1,
			question = Content.QUESTIONS[(TimeUtil.hash(trainingSeed + p.UserId % 997) % #Content.QUESTIONS) + 1],
			trainingSeed = trainingSeed,
			humans = #humans,
			quick = quick,
			mode = MatchService.mode.name,
			archive = MatchService.archive,
			party = Party.size(MatchService.party, Party.partyOf(MatchService.party, p.UserId) or 0),
		})
	end
	pushMatch("matchStart", { humans = #humans, bots = #botIds, twist = MatchService.twist, mode = MatchService.mode.name, archive = MatchService.archive })
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
		phases = Modes.phases(MatchService.mode, Config.VeilPhases, tw.mods.veil or 1)
	else
		phases = Modes.phases(MatchService.mode, Config.VeilPhases)
	end
	-- v5 Archive Reel: the broadcast goes sepia, like footage from 25 years ago
	local cc = Lighting:FindFirstChild("ArchiveReel") :: ColorCorrectionEffect?
	if MatchService.archive and not cc then
		local fx = Instance.new("ColorCorrectionEffect")
		fx.Name = "ArchiveReel"
		fx.Saturation = -0.75
		fx.Contrast = 0.12
		fx.TintColor = Color3.fromRGB(255, 232, 196)
		fx.Parent = Lighting
	elseif not MatchService.archive and cc then
		cc:Destroy()
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
			c.stam = Stamina.new(STAMINA_RULES)
			c.meters = Meters.new(Config.Meters)
			c.lastGood = nil
			c.training = c.training or 5
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
	stateEndsAt = arenaStart + Modes.cap(MatchService.mode, Config.HARD_CAP)
	for _, c in pairs(MatchService.contenders) do
		if c.player and c.model then
			local hrp = c.model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				hrp.Anchored = false
			end
			c.lastGood = nil
			c.speedStrikes = 0
			pushVitals(c, true)
		end
	end
	ctx.Gallery.onArenaStart()
	ctx.Bots.onArenaStart()
	pushMatch("arena", { size = Config.MATCH_SIZE, mode = MatchService.mode.name })
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
	local statues = {}
	for i = 1, math.min(3, #all) do
		local entry = { name = all[i].name, reach = all[i].reach, place = all[i].place, knocks = all[i].knocks }
		local pl = all[i].player
		local pd = pl and ctx.Progress.dataOf(pl)
		if pd and pd.equipped then
			local pose = Store.byId[pd.equipped.pose or ""]
			local banner = Store.byId[pd.equipped.banner or ""]
			entry.pose = pose and { name = pose.name, icon = pose.icon, color = pose.color } or nil
			entry.banner = banner and banner.name or nil
		end
		table.insert(podium, entry)
		-- v4: statues on the lobby Victory Podium in their real loadout (bots: default looks)
		local l = pl and ctx.Hall.loadoutOf(pl)
			or { userId = 0, name = all[i].name, pose = "pose_firstlight", weapon = "bow", skin = "", mastery = 0, fade = "fade_gold", banner = "", title = "" }
		table.insert(statues, { place = i, loadout = l })
	end
	if winner and winner.player then
		ctx.Hall.recordWin(winner.player)
	end
	ctx.Hall.podium(statues)
	for _, c in ipairs(all) do
		-- Encore fix: someone paid at an earlier knockout and voted back in is topped up to
		-- their final place here, once (v1 skipped them because `awarded` was already set).
		local needsTopUp = c.awarded and c.encore and c.firstResult ~= nil and not c.toppedUp
		if c.player and c.player.Parent and (not c.awarded or needsTopUp) then
			local data = ctx.Progress.dataOf(c.player)
			local prevBest = data and data.stats.bestPlace or 0
			local r = {
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
				pactKept = c.pactKept,
				archive = MatchService.archive,
			}
			local result: any
			if needsTopUp then
				result = ctx.Progress.topUp(c.player, c.firstResult, r)
				c.toppedUp = true
			else
				result = ctx.Progress.award(c.player, r)
				c.firstResult = r
			end
			c.awarded = true
			local nm = { place = c.place or 2, size = Config.MATCH_SIZE, knocks = c.knocks, survived = MatchService.t, bestPlace = prevBest, nextKnockGoal = ctx.Progress.nextGoal(c.player, "knocks"), winnerPepLeft = winner and winner.pep }
			local firstWin = c.place == 1 and ctx.Progress.firstWin(c.player)
			ctx.push(c.player, "finished", {
				headline = NearMiss.headline(nm),
				lines = NearMiss.lines(nm),
				place = c.place,
				result = result,
				preview = ctx.Purchase.previewFor(c.player, c.knocks),
				firstWin = firstWin and Offers.firstWin(c.player.DisplayName) or nil,
				moment = MatchService.momentFor(c),
			})
		end
	end
	pushMatch("podium", { podium = podium, winner = winner and winner.name or "", reach = winner and winner.reach or "", next = Config.PODIUM_SECONDS + Config.Matchmaking.nextMatchSeconds })
	MatchService.sendPartyCards()
	ctx.Gallery.onArenaEnd()
	ctx.Bots.onArenaEnd()
end

local function backToLobby()
	local players = matchHumans()
	clearArena()
	local cc = Lighting:FindFirstChild("ArchiveReel")
	if cc then
		cc:Destroy()
	end
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
	c.lastGood = nil
	c.speedStrikes = 0
	if c.player then
		c.stam = Stamina.new(STAMINA_RULES)
		c.meters = Meters.new(Config.Meters)
	end
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

-- ===================== v5 parties (up to 10) =====================
local function partyPush()
	for _, p in ipairs(Players:GetPlayers()) do
		local s = MatchService.party
		local pid = Party.partyOf(s, p.UserId)
		local members = {}
		for _, uid in ipairs(Party.membersOf(s, p.UserId)) do
			local m = Players:GetPlayerByUserId(uid)
			table.insert(members, { userId = uid, name = m and m.DisplayName or "?", leader = pid ~= nil and s.leader[pid] == uid, queued = m ~= nil and inQueue(m) })
		end
		local from = s.invites[p.UserId]
		local fp = from and Players:GetPlayerByUserId(from)
		ctx.push(p, "party", { members = pid and members or {}, max = Party.MAX, invite = fp and fp.DisplayName or nil, family = isPrivate() and MatchService.psRules.family })
	end
end
MatchService.partyPush = partyPush

local function partyInvite(player: Player, userId: any): (boolean, string?)
	local other = type(userId) == "number" and Players:GetPlayerByUserId(userId) or nil
	if not other then
		return false, "They're not in this server."
	end
	local ok, msg = Party.invite(MatchService.party, player.UserId, other.UserId)
	if ok then
		ctx.toast(other, player.DisplayName .. " invited you to their party. Open Party to join.", "info")
		partyPush()
		return true, "Party invite sent to " .. other.DisplayName .. "."
	end
	return false, msg
end

local function partyAccept(player: Player): (boolean, string?)
	local ok, msg = Party.accept(MatchService.party, player.UserId)
	partyPush()
	if not ok then
		return false, msg
	end
	-- queue together: if anyone in the party is queued, the newcomer joins the queue too
	for _, uid in ipairs(Party.membersOf(MatchService.party, player.UserId)) do
		local m = Players:GetPlayerByUserId(uid)
		if m and m ~= player and inQueue(m) and not inQueue(player) then
			table.insert(queue, player)
			break
		end
	end
	return true, "You're in the party!"
end

local function partyLeave(player: Player): (boolean, string?)
	Party.leave(MatchService.party, player.UserId)
	partyPush()
	return true, "Left the party."
end

-- The leader queues (or leaves the queue) for the whole party.
local function partyQueue(player: Player, on: any): (boolean, string?)
	local s = MatchService.party
	local pid = Party.partyOf(s, player.UserId)
	if not pid or s.leader[pid] ~= player.UserId then
		return false, "Only the party leader can queue everyone."
	end
	local wasEmpty = #queue == 0
	for _, uid in ipairs(s.members[pid]) do
		local m = Players:GetPlayerByUserId(uid)
		if m then
			local i = table.find(queue, m)
			if on ~= false and not i then
				table.insert(queue, m)
			elseif on == false and i then
				table.remove(queue, i)
			end
		end
	end
	if wasEmpty and #queue > 0 then
		queueSince = now()
	end
	lobbyStatus()
	partyPush()
	return true, on ~= false and "Party queued together." or "Party left the queue."
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

-- Training round: the client sends which targets it hit and when (seconds since the round
-- began). The server re-creates the seeded targets and scores the clicks itself.
local function training(player: Player, clicks: any): (boolean, string?)
	local c = MatchService.contenderOf(player)
	if not c or MatchService.state ~= "Pregame" or type(clicks) ~= "table" or c.training then
		return false, nil
	end
	local list = {}
	for k, v in ipairs(clicks) do
		if k > 12 then
			break
		end
		if type(v) == "table" and type(v.i) == "number" and type(v.t) == "number" then
			table.insert(list, { i = math.floor(v.i), t = v.t })
		end
	end
	local targets = Training.targets(trainingSeed, Config.Training.targets, Config.Training.duration)
	local score = Training.score(targets, list, Config.Training.max)
	c.training = score
	return true, nil
end

-- Interview: pick one of the preset answers. Index only, never text.
local function interview(player: Player, i: any): (boolean, string?)
	local c = MatchService.contenderOf(player)
	if not c or MatchService.state ~= "Pregame" or type(i) ~= "number" or not Content.QUIPS[i] then
		return false, nil
	end
	local q = math.floor(i)
	c.quip = q
	for _, p in ipairs(matchHumans()) do
		if p ~= player then
			ctx.push(p, "interviewLine", { name = c.name, reach = c.reach, quip = Content.QUIPS[q] })
		end
	end
	return true, nil
end

-- ===== pacts =====
local function nearestFor(c: Contender, range: number): Contender?
	local root = MatchService.rootOf(c)
	if not root then
		return nil
	end
	local best: Contender? = nil
	local bestD = range
	for _, o in pairs(MatchService.contenders) do
		if o ~= c and o.alive and o.reach ~= c.reach and not Pacts.same(pacts, c.id, o.id) then
			local r = MatchService.rootOf(o)
			if r then
				local d = (r.Position - root.Position).Magnitude
				if d < bestD then
					best, bestD = o, d
				end
			end
		end
	end
	return best
end

local function botAnswer(bot: Contender, from: Contender)
	task.delay(rng:NextNumber(1, 2.5), function()
		if not bot.alive or not from.alive or MatchService.state ~= "Arena" then
			return
		end
		if bot.pep >= 30 and rng:NextNumber() < 0.6 then
			local p = Pacts.accept(pacts, Config.Pacts, bot.id, MatchService.aliveCount(), now())
			if p and from.player then
				ctx.toast(from.player, bot.name .. " accepted your pact.", "good")
				pushMatch("feed", { kind = "pact", victim = bot.name, by = from.name, left = MatchService.aliveCount() })
			end
		else
			Pacts.decline(pacts, bot.id)
			if from.player then
				ctx.toast(from.player, bot.name .. " turned you down.", "info")
			end
		end
		pushPact(from)
	end)
end

function MatchService.offerPact(c: Contender, target: Contender?): (boolean, string?)
	if MatchService.state ~= "Arena" or not c.alive then
		return false, nil
	end
	local o = target or nearestFor(c, Config.Pacts.offerRange)
	if not o then
		return false, "Nobody close enough. Get within " .. Config.Pacts.offerRange .. " studs."
	end
	local ok, why = Pacts.offer(pacts, Config.Pacts, c.id, o.id, MatchService.aliveCount(), now())
	if not ok then
		return false, why
	end
	if o.player then
		pushPact(o)
		ctx.push(o.player, "pactOffer", { name = c.name, reach = c.reach, seconds = Config.Pacts.offerSeconds })
	else
		botAnswer(o, c)
	end
	return true, "Pact offered to " .. o.name .. "."
end

local function pactOffer(player: Player): (boolean, string?)
	local c = MatchService.contenderOf(player)
	if not c then
		return false, nil
	end
	return MatchService.offerPact(c, nil)
end

local function pactAccept(player: Player): (boolean, string?)
	local c = MatchService.contenderOf(player)
	if not c or not c.alive or MatchService.state ~= "Arena" then
		return false, nil
	end
	local p, why = Pacts.accept(pacts, Config.Pacts, c.id, MatchService.aliveCount(), now())
	pushPactsAll()
	if not p then
		return false, why
	end
	local names = {}
	for _, id in ipairs(p.members) do
		local m = MatchService.contenders[id]
		if m then
			table.insert(names, m.name)
			if m.player and m ~= c then
				ctx.toast(m.player, c.name .. " joined your pact.", "good")
			end
		end
	end
	pushMatch("feed", { kind = "pact", victim = table.concat(names, " + "), left = MatchService.aliveCount() })
	return true, "Pact formed. " .. Content.RUSTY.pact
end

local function pactDecline(player: Player): (boolean, string?)
	local c = MatchService.contenderOf(player)
	if c then
		Pacts.decline(pacts, c.id)
		pushPact(c)
	end
	return true, nil
end

function MatchService.snapPact(c: Contender): (boolean, string?)
	if MatchService.state ~= "Arena" or not c.alive then
		return false, nil
	end
	if isPrivate() and MatchService.psRules.noBetrayals then
		return false, "This private server has No Betrayals on."
	end
	local sn, why = Pacts.snap(pacts, Config.Pacts, c.id, now())
	if not sn then
		return false, why
	end
	-- telegraph: the allies are warned and the snapper glows red for the wind-up
	for _, id in ipairs(Pacts.allies(pacts, c.id)) do
		local a = MatchService.contenders[id]
		if a and a.player then
			ctx.push(a.player, "pactWarning", { name = c.name, seconds = Config.Pacts.snapSeconds })
		end
	end
	if c.model then
		local h = Instance.new("Highlight")
		h.Name = "PactSnap"
		h.FillColor = Color3.fromHex("#E2463A")
		h.FillTransparency = 0.55
		h.OutlineColor = Color3.fromHex("#FFB0A8")
		h.Parent = c.model
		task.delay(Config.Pacts.snapSeconds + 0.2, function()
			h:Destroy()
		end)
	end
	pushPact(c)
	return true, string.format("Snapping your pact in %ds…", Config.Pacts.snapSeconds)
end

local function pactSnap(player: Player): (boolean, string?)
	local c = MatchService.contenderOf(player)
	if not c then
		return false, nil
	end
	return MatchService.snapPact(c)
end

local function tickPacts()
	for _, ev in ipairs(Pacts.tick(pacts, Config.Pacts, now())) do
		local who = ev.who and MatchService.contenders[ev.who]
		local names = {}
		for _, id in ipairs(ev.with or {}) do
			local v = MatchService.contenders[id]
			if v then
				table.insert(names, v.name)
				if v.player then
					ctx.push(v.player, "pactSnapped", { name = who and who.name or "?", line = Content.RUSTY.snapped, guard = Config.Pacts.guardSeconds })
				end
			end
		end
		if who then
			if who.player then
				ctx.Progress.grant(who.player, "title_turncoat", "Title unlocked: " .. Content.TITLES.title_turncoat)
				ctx.push(who.player, "pactSnapDone", { names = names, window = Config.Pacts.betrayWindow })
			end
			pushMatch("feed", { kind = "pactSnap", by = who.name, victim = table.concat(names, " + "), left = MatchService.aliveCount() })
		end
		pushPactsAll()
	end
	-- final few: every pact ends; those still in one get the "pact kept" bonus
	if not pactsEnded and MatchService.aliveCount() <= Config.Pacts.endAt then
		pactsEnded = true
		for _, p in ipairs(Pacts.endAll(pacts)) do
			for _, id in ipairs(p.members) do
				local m = MatchService.contenders[id]
				if m and m.alive then
					m.pactKept = true
				end
			end
		end
		pushMatch("pactsEnded", { left = MatchService.aliveCount() })
		pushPactsAll()
	end
end

-- Stand-Ins make the odd offer to nearby players, and sometimes snap late in the match.
local function botPacts()
	local alive = MatchService.aliveCount()
	if pactsEnded then
		return
	end
	for _, b in pairs(MatchService.contenders) do
		if b.kind == "bot" and b.alive then
			if pacts.memberOf[b.id] then
				if alive <= 8 and rng:NextNumber() < 0.04 then
					MatchService.snapPact(b)
				end
			elseif rng:NextNumber() < 0.01 then
				local o = nearestFor(b, Config.Pacts.offerRange)
				if o and o.player and not pacts.offers[o.id] then
					MatchService.offerPact(b, o)
				end
			end
		end
	end
end

-- ===== sprint + throw =====
local function sprint(player: Player, on: any): (boolean, string?)
	local c = MatchService.contenderOf(player)
	if c and c.stam and type(on) == "boolean" then
		c.stam.wants = on
	end
	return true, nil
end

local function throw(player: Player, aim: any): (boolean, string?)
	local c = MatchService.contenderOf(player)
	if not c then
		return false, nil
	end
	if c.inv[c.equipped] ~= "spear" then
		return false, "Equip a spear to throw it."
	end
	return MatchService.throw(c, typeof(aim) == "Vector3" and aim or nil), nil
end

-- Server-owned stamina, Food/Water and WalkSpeed, plus a simple speed check (every tick).
local function tickBodies(dt: number, wholeSecond: boolean)
	local t = now()
	for _, c in pairs(MatchService.contenders) do
		local st, m = c.stam, c.meters
		local root = if c.alive and c.player then MatchService.rootOf(c) else nil
		local hum = c.model and c.model:FindFirstChildOfClass("Humanoid")
		if root and hum and st and m then
			local v = root.AssemblyLinearVelocity
			local moving = Vector3.new(v.X, 0, v.Z).Magnitude > 2
			Meters.step(m, Config.Meters, dt, 1)
			local regen = Meters.regenMult(m, Config.Meters)
			if c.player and ctx.Progress.hasPass(c.player, "TrailBoots") and not Config.RANKED and MatchService.aliveCount() > Config.FairPlay.perksOffAtLeft then
				regen *= 1 + Config.FairPlay.bootsRegen
			end
			Stamina.step(st, STAMINA_RULES, dt, moving, regen)
			local slow = c.slowUntil > t and Config.Hazards.bloom.slow or 1
			hum.WalkSpeed = (st.sprinting and Config.SPRINT_SPEED or Config.WALK_SPEED) * slow
			pushVitals(c)
			if wholeSecond then
				local pos = root.Position
				local last = c.lastGood
				if last then
					local d = Vector3.new(pos.X - last.X, 0, pos.Z - last.Z).Magnitude
					local S = Config.SpeedCheck
					if Stamina.tooFast(d, 1, Config.SPRINT_SPEED, S.slack, S.grace) then
						c.speedStrikes += 1
						if c.speedStrikes >= S.strikes then
							c.speedStrikes = 0
							(c.model :: Model):PivotTo(CFrame.new(last + Vector3.new(0, 3, 0)))
							ctx.toast(c.player, "Whoa, too fast! Moved you back.", "info")
						end
					else
						c.speedStrikes = math.max(0, c.speedStrikes - 1)
						c.lastGood = pos
					end
				else
					c.lastGood = pos
				end
			end
		end
	end
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
	Party.leave(MatchService.party, player.UserId)
	MatchService.party.invites[player.UserId] = nil
	task.defer(partyPush)
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
	ctx.handle("interview", interview)
	ctx.handle("pactOffer", pactOffer)
	ctx.handle("pactAccept", pactAccept)
	ctx.handle("pactDecline", pactDecline)
	ctx.handle("pactSnap", pactSnap)
	ctx.handle("sprint", sprint)
	ctx.handle("throw", throw)
	ctx.handle("partyInvite", partyInvite)
	ctx.handle("partyAccept", partyAccept)
	ctx.handle("partyLeave", partyLeave)
	ctx.handle("partyQueue", partyQueue)
	ctx.handle("setMode", function(player: Player, mode: any): (boolean, string?)
		if mode ~= "" and mode ~= Modes.QUICK and mode ~= Modes.JUBILEE then
			return false, nil
		end
		local d = ctx.Progress.dataOf(player)
		if not d then
			return false, nil
		end
		d.settings.mode = mode
		ctx.Progress.markDirty(player)
		task.defer(ctx.Progress.sendState, player)
		return true, mode == "" and "Match type: auto." or ("Match type: " .. Modes.get(mode).name .. ".")
	end)
	ctx.handle("psRule", function(player: Player, key: any, value: any): (boolean, string?)
		local owner = isPrivate() and game.PrivateServerOwnerId == player.UserId
		local studio = game:GetService("RunService"):IsStudio()
		-- Family Rules is free for any private-server owner (party allied until 4 are left)
		if key == "family" and type(value) == "boolean" and (owner or studio) then
			MatchService.psRules.family = value
			partyPush()
			return true, value and "Family Rules on: your party is allied until the final 4." or "Family Rules off: everyone for themselves."
		end
		if not (owner or studio) or not ctx.Progress.hasPass(player, "VIP") then
			return false, "Private server rules need Spire VIP and your own private server."
		end
		if key == "twist" and type(value) == "string" then
			MatchService.psRules.twist = value
			return true, value == "" and "Twist: random each match." or ("Next twist set: " .. value)
		elseif key == "noBetrayals" and type(value) == "boolean" then
			MatchService.psRules.noBetrayals = value
			return true, value and "No Betrayals is on." or "Pact Snaps are allowed again."
		end
		return false, nil
	end)
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
					-- training board: everyone's score, shown as the round ends
					local P = Config.Pregame
					local boardAt = pregameStart + (pregameShort and P.reapingShort or P.reaping) + P.parade + P.interview + Config.Training.duration + 0.5
					if not boardSent and t >= boardAt then
						boardSent = true
						local board = {}
						for _, id in ipairs(MatchService.order) do
							local c = MatchService.contenders[id]
							c.training = c.training or 5
							table.insert(board, { name = c.name, reach = c.reach, score = c.training, me = false })
						end
						table.sort(board, function(a: any, b: any): boolean
							return a.score > b.score
						end)
						for _, p in ipairs(matchHumans()) do
							local mine = MatchService.contenderOf(p)
							ctx.push(p, "trainingBoard", { board = board, mine = mine and mine.training, underdogAt = Config.Training.underdogAt })
						end
					end
					if t >= stateEndsAt then
						startLaunch()
					end
				elseif MatchService.state == "Launch" then
					if t >= stateEndsAt then
						startArena()
					end
				elseif MatchService.state == "Arena" then
					MatchService.t = t - arenaStart
					-- Veil Breaker calm: the Veil clock pauses while the dome is broken
					if t < calmUntil then
						veilShift += dt
					end
					local vt = MatchService.t - veilShift
					local r = Veil.radiusAt(vt, phases, Config.Map.ARENA_SIZE / 2)
					if math.abs(r - MatchService.radius) > 0.05 then
						setVeil(r)
					end
					tickHazards(dt, wholeSecond)
					tickBodies(dt, wholeSecond)
					tickPacts()
					if wholeSecond then
						botPacts()
						if not veilBroken and not veilCore and MatchService.aliveCount() <= Config.VeilBreaker.at and MatchService.aliveCount() > 1 then
							lightCore()
						end
						local dmg = Veil.damage(vt, phases, Config.VEIL_DAMAGE)
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
							if math.floor(MatchService.t) == Modes.at(MatchService.mode, h.at) then
								MatchService.startHazard(h.id)
							end
						end
						if MatchService.twist and MatchService.twist.mods.finches and math.floor(MatchService.t) == Modes.at(MatchService.mode, 450) then
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
						-- v5 onboarding: still standing after the first shrink
						if not veilStepDone and phases[1] and vt >= phases[1].at + phases[1].dur then
							veilStepDone = true
							for _, c in pairs(MatchService.contenders) do
								if c.alive and c.player then
									ctx.Progress.onboard(c.player, "veil")
								end
							end
						end
						local nextIn, target = Veil.nextShrink(vt, phases)
						pushMatch("match", {
							t = MatchService.t,
							alive = MatchService.aliveCount(),
							radius = MatchService.radius,
							nextIn = nextIn,
							target = target,
							shrinking = t >= calmUntil and Veil.isShrinking(vt, phases),
							calm = t < calmUntil and math.ceil(calmUntil - t) or nil,
							core = veilCore ~= nil,
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

--!strict
--[[
	BotService — Stand-In contenders that fill empty plates so a match always has 48.
	Every bot is labeled "Stand-In · Name (Reach)" so nobody mistakes it for a person.
	A simple 4 Hz brain: grab a crate, eat when low, fight what's close, flee the Veil.
	Bots deal 80% damage and aim with some spread so new players can win.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Veil = require(Shared.Logic.Veil)

local BotService = {}
local ctx: any = nil
local rng = Random.new()
local brains: { [string]: any } = {}
local running = false

local SKIN = { "#F1C9A5", "#E0AC69", "#C68642", "#8D5524", "#5C3A21", "#FFDBAC" }
local SHIRT = { "#4A505C", "#5C5A52", "#6B5B4B", "#2F7F86", "#7A2E3A", "#3E8E5E", "#B8793A", "#2B2D33" }
local PANTS = { "#2B2D33", "#3A3A40", "#5C5A52", "#4A3426" }

local function color(h: string): Color3
	return Color3.fromHex(h)
end

local function simpleRig(name: string): Model
	-- fallback when avatar rigs can't be created (e.g. offline Studio tests)
	local m = Instance.new("Model")
	m.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Parent = m
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Color = color(SHIRT[rng:NextInteger(1, #SHIRT)])
	torso.CFrame = root.CFrame
	torso.Parent = m
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.Shape = Enum.PartType.Ball
	head.Color = color(SKIN[rng:NextInteger(1, #SKIN)])
	head.CFrame = root.CFrame * CFrame.new(0, 1.6, 0)
	head.Parent = m
	local legs = Instance.new("Part")
	legs.Name = "Legs"
	legs.Size = Vector3.new(1.8, 2, 1)
	legs.Color = color(PANTS[rng:NextInteger(1, #PANTS)])
	legs.CFrame = root.CFrame * CFrame.new(0, -2, 0)
	legs.Parent = m
	for _, p in ipairs({ torso, head, legs }) do
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = p
	end
	local hum = Instance.new("Humanoid")
	hum.HipHeight = 2
	hum.Parent = m
	m.PrimaryPart = root
	return m
end

local function makeRig(name: string): Model
	-- realistic R15 Stand-In (see LookService / Shared/Look.luau); blocky fallback only offline
	local rig = ctx and ctx.Look and ctx.Look.standIn(name, rng)
	if rig then
		return rig
	end
	return simpleRig(name)
end

function BotService.spawn(c: any, cf: CFrame): Model?
	local m = makeRig(c.name)
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayName = string.format("%s (%s)", c.name, c.reach)
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		hum.NameDisplayDistance = 60
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.BreakJointsOnDeath = false
		hum.WalkSpeed = 14
		hum.MaxHealth = 1e6
		hum.Health = 1e6
	end
	m:SetAttribute("StandIn", true)
	m:PivotTo(cf)
	local folder = workspace:FindFirstChild("StandIns")
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "StandIns"
		f.Parent = workspace
		folder = f
	end
	m.Parent = folder
	local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = true
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	brains[c.id] = {
		next = 0,
		goal = nil,
		crate = nil,
		target = nil,
		react = rng:NextNumber(Config.Bots.reaction[1], Config.Bots.reaction[2]),
		brave = rng:NextNumber() < Config.Bots.hubBrave,
	}
	return m
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function safePoint(radius: number): Vector3
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(0, math.max(10, radius * 0.7))
	return Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end

local function nearestCrate(pos: Vector3, maxD: number): BasePart?
	local best: BasePart? = nil
	local bestD = maxD
	for _, crate in ipairs(ctx.Match.allCrates()) do
		if not crate:GetAttribute("Opened") then
			local d = (crate.Position - pos).Magnitude
			if d < bestD then
				best, bestD = crate, d
			end
		end
	end
	return best
end

local function think(c: any, b: any, _t: number)
	local M = ctx.Match
	local root = M.rootOf(c)
	local hum = c.model and c.model:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		return
	end
	local pos = root.Position
	hum.WalkSpeed = 14 * ((c.model:GetAttribute("SpeedMult") or 1) :: number)
	-- 1) flee the Veil
	local _, target = Veil.nextShrink(M.t, Config.VeilPhases)
	local safeR = math.min(M.radius, target or M.radius)
	if Veil.outside(pos.X, pos.Z, safeR * 0.92) then
		local inward = -flat(pos)
		if inward.Magnitude > 1 then
			hum:MoveTo(pos + inward.Unit * 60)
		end
		return
	end
	-- 2) eat when low
	if c.pep < 55 then
		for i, item in ipairs(c.inv) do
			local d = Config.Items[item]
			if d and d.kind == "snack" then
				M.eat(c, i)
				return
			end
		end
	end
	-- pick best weapon
	local bestSlot, bestDmg = 0, 0
	for i, item in ipairs(c.inv) do
		local d = Config.Items[item]
		local w = d and d.weapon and Config.Weapons[d.weapon]
		if w and (w.kind ~= "ranged" or c.ammo > 0) and w.damage > bestDmg then
			bestSlot, bestDmg = i, w.damage
		end
	end
	if bestSlot > 0 then
		c.equipped = bestSlot
	end
	-- 3) fight what's close
	local enemy: any = nil
	local enemyD = Config.Bots.sight
	for _, o in pairs(M.contenders) do
		if o ~= c and o.alive and M.canHurt(c, o) then
			local orr = M.rootOf(o)
			if orr then
				local d = (orr.Position - pos).Magnitude
				if d < enemyD then
					enemy, enemyD = o, d
				end
			end
		end
	end
	if enemy and (bestSlot > 0 or enemyD < 10) then
		local er = M.rootOf(enemy)
		if er then
			local item = c.inv[c.equipped]
			local d = item and Config.Items[item]
			local w = d and d.weapon and Config.Weapons[d.weapon] or Config.Weapons.shove
			if w.kind == "ranged" then
				if enemyD > w.range * 0.7 then
					hum:MoveTo(er.Position)
				else
					hum:MoveTo(pos + (pos - er.Position).Unit:Cross(Vector3.yAxis) * 8)
				end
				local spread = Config.Bots.aimSpread * enemyD
				local aim = er.Position + Vector3.new(rng:NextNumber(-spread, spread), rng:NextNumber(-1, 1), rng:NextNumber(-spread, spread))
				root.CFrame = CFrame.lookAt(pos, Vector3.new(er.Position.X, pos.Y, er.Position.Z))
				M.attack(c, w.id, aim)
			else
				hum:MoveTo(er.Position)
				if enemyD <= w.range + 1 then
					M.attack(c, w.id, er.Position)
				end
			end
			return
		end
	end
	-- 4) loot
	if #c.inv < c.slots then
		local crate = b.crate
		if not crate or crate:GetAttribute("Opened") then
			crate = nearestCrate(pos, b.brave and 400 or 220)
			b.crate = crate
		end
		if crate then
			if (crate.Position - pos).Magnitude < 9 then
				M.openCrate(c, crate)
				b.crate = nil
			else
				hum:MoveTo(crate.Position)
			end
			return
		end
	end
	-- 5) wander inside the safe zone
	if not b.goal or (flat(b.goal) - flat(pos)).Magnitude < 12 or Veil.outside(b.goal.X, b.goal.Z, safeR * 0.85) then
		b.goal = safePoint(safeR)
	end
	hum:MoveTo(b.goal)
end

function BotService.onArenaStart()
	running = true
	for id, c in pairs(ctx.Match.contenders) do
		if c.kind == "bot" and c.model then
			local root = c.model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				root.Anchored = false
				pcall(function()
					root:SetNetworkOwner(nil)
				end)
			end
			local b = brains[id]
			if b then
				b.next = workspace:GetServerTimeNow() + b.react
			end
		end
	end
end

function BotService.onArenaEnd()
	running = false
	brains = {}
end

function BotService.init(c: any)
	ctx = c
end

function BotService.start()
	task.spawn(function()
		while true do
			task.wait(Config.Bots.tick)
			if running then
				local t = workspace:GetServerTimeNow()
				for id, c in pairs(ctx.Match.contenders) do
					local b = brains[id]
					if c.kind == "bot" and c.alive and b and t >= b.next then
						b.next = t + Config.Bots.tick
						local ok, err = pcall(function(): any
							think(c, b, t)
							return nil
						end)
						if not ok then
							warn("[BotService] " .. tostring(err))
						end
					end
				end
			end
		end
	end)
end

return BotService

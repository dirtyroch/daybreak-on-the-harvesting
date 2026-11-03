--!strict
--[[
	GalleryService — the Viewing Gallery. Knocked-out players (and anyone who taps "Watch") keep
	playing from a glass lounge above the arena:
	  * Favor: +1 every 5 s while watching (Big Sponsor pass doubles the rate). Never sold.
	  * Parachute gifts to any contender (pricier late in the match; partner discount).
	  * Hazard votes every 90 s: 3 cards, one always friendly (Supply Drop).
	  * Encore: once a match, the Gallery votes one knocked-out contender back in.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Names = require(Shared.Names)
local Content = require(Shared.Content)
local Gifts = require(Shared.Logic.Gifts)
local Vote = require(Shared.Logic.Vote)
local Twists = require(Shared.Logic.Twists)
local Training = require(Shared.Logic.Training)
local Store = require(Shared.Store)
local Offers = require(Shared.Offers)

local GalleryService = {}
local ctx: any = nil
local rng = Random.new()

local spectators: { [Player]: { favor: number, gifts: number, votes: number } } = {}
local lastGift: { [string]: number } = {}
local inAir = 0
local hazardBallot: Vote.Ballot? = nil
local hazardEnds = 0
local nextHazardVote = 0
local encoreBallot: Vote.Ballot? = nil
local encoreEnds = 0
local encoresLeft = 0
local live = false

local function now(): number
	return workspace:GetServerTimeNow()
end
local partnerMoments: () -> ()
local partnerShown: { [Player]: boolean } = {}

function GalleryService.isSpectator(p: Player): boolean
	return spectators[p] ~= nil
end

function GalleryService.addSpectator(p: Player)
	if not spectators[p] then
		-- sponsor letters bank a Favor head start for the next visit
		local bank = ctx.Progress.takeFavorBank(p)
		spectators[p] = { favor = Config.Gallery.favorStart + bank, gifts = 0, votes = 0 }
		if bank > 0 then
			ctx.toast(p, string.format("Your patrons sent +%d %s for today's gifts.", bank, Names.FAVOR), "good")
		end
	end
	ctx.push(p, "gallery", GalleryService.view(p))
end

function GalleryService.removeSpectator(p: Player)
	if spectators[p] then
		spectators[p] = nil
		ctx.push(p, "galleryClose", {})
	end
end

local function tmpl(name: string): Instance?
	local t = ServerStorage:FindFirstChild("Templates")
	return t and t:FindFirstChild(name)
end

-- Parachute down onto a position; calls onLand when it touches down.
local function parachute(pos: Vector3, label: string?, onLand: () -> (), wrap: string?)
	local t = tmpl("Parachute")
	if not t then
		onLand()
		return
	end
	inAir += 1
	local m = (t :: Model):Clone()
	local start = pos + Vector3.new(0, 140, 0)
	m:PivotTo(CFrame.new(start))
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			-- Gift Wraps (Item Shop) recolor the canopy stripe and the crate
			if wrap and (d.Name == "Stripe" or d.Name == "Box") then
				d.Color = Color3.fromHex(wrap)
			end
		end
	end
	if label then
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(0, 200, 0, 30)
		bb.StudsOffset = Vector3.new(0, 14, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 250
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.TextScaled = true
		tl.Font = Enum.Font.FredokaOne
		tl.TextColor3 = Color3.fromHex("#FFE9A8")
		tl.TextStrokeTransparency = 0.3
		tl.Text = label
		tl.Parent = bb
		bb.Parent = m.PrimaryPart
	end
	m.Parent = workspace
	local v = Instance.new("CFrameValue")
	v.Value = CFrame.new(start)
	v.Changed:Connect(function(cf: CFrame)
		if m.Parent then
			m:PivotTo(cf)
		end
	end)
	local tw = TweenService:Create(v, TweenInfo.new(6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Value = CFrame.new(pos + Vector3.new(0, 1.5, 0)) })
	tw.Completed:Connect(function()
		inAir -= 1
		onLand()
		task.delay(1.5, function()
			m:Destroy()
			v:Destroy()
		end)
	end)
	tw:Play()
end

-- A gift lands on a contender (from a spectator, or from Rusty).
function GalleryService.dropGift(c: any, item: string, fromName: string, note: string?, wrap: string?)
	local root = ctx.Match.rootOf(c)
	if not root then
		return
	end
	local def = Config.Items[item]
	parachute(root.Position, def and def.name or item, function()
		if not c.alive then
			return
		end
		if not ctx.Match.give(c, item) and def and def.heal then
			c.pep = math.min(Config.PEP_MAX, c.pep + def.heal)
			if c.player then
				ctx.push(c.player, "pep", { pep = c.pep, from = "gift" })
			end
		end
		if c.player then
			ctx.push(c.player, "gift", { from = fromName, item = def and def.name or item, note = note })
		end
	end, wrap)
	ctx.pushAll("giftFeed", { from = fromName, to = c.name, item = def and def.name or item })
end

-- A free supply crate on a parachute (the friendly hazard card).
function GalleryService.dropCrate(pos: Vector3)
	parachute(pos, "Supply Crate", function()
		local p = Instance.new("Part")
		p.Name = "SupplyCrate"
		p.Anchored = true
		p.Size = Vector3.new(4, 3, 3)
		p.Color = Color3.fromHex("#D4A72C")
		p.Material = Enum.Material.Wood
		p.CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0))
		p:SetAttribute("Loot", "hub")
		p:SetAttribute("Crate", true)
		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = "Open"
		pp.ObjectText = "Supply Crate"
		pp.HoldDuration = 0.6
		pp.MaxActivationDistance = 9
		pp.RequiresLineOfSight = false
		pp.Parent = p
		local folder = workspace:WaitForChild("Map").Arena:FindFirstChild("FieldCrates")
		p.Parent = folder or workspace
		pp.Triggered:Connect(function(player: Player)
			local c = ctx.Match.contenderOf(player)
			if c and ctx.Match.openCrate(c, p) then
				task.delay(1, function()
					p:Destroy()
				end)
			end
		end)
		task.delay(240, function()
			if p.Parent then
				p:Destroy()
			end
		end)
	end)
end

function GalleryService.view(p: Player): any
	local s = spectators[p]
	local mine = ctx.Match.contenderOf(p)
	local alive = {}
	local weekMult = Twists.mod({ ctx.Match.weekly }, "giftCost", 1)
	local count = ctx.Match.aliveCount()
	for _, id in ipairs(ctx.Match.order) do
		local c = ctx.Match.contenders[id]
		if c and c.alive then
			local isPartner = mine ~= nil and mine.partner == c.id
			local under = Training.giftMult(c.training, Config.Training.underdogAt, Config.Training.underdogGiftMult) < 1
			-- v4: spectators see each contender's equipped cosmetics (weapon skin + Mastery, fade)
			local held = c.inv and c.inv[c.equipped] or "bow"
			local slot = (held == "spear" or held == "knife") and held or "bow"
			local skin, lvl = ctx.Match.looksOf(c, slot)
			local sk = Store.byId[skin]
			local fade = c.player and ctx.Match.fadeOf(c, nil) or "fade_gold"
			local look = {
				weapon = sk and sk.name or ("Default " .. slot),
				weaponColor = sk and sk.color or nil,
				stars = lvl >= 5 and "✦" or string.rep("★", lvl),
				fade = Content.FADES[fade] and Content.FADES[fade].name or nil,
				fadeColor = Content.FADES[fade] and Content.FADES[fade].color or nil,
			}
			table.insert(alive, { id = c.id, name = c.name, reach = c.reach, pep = c.pep, partner = isPartner, bot = c.kind == "bot", underdog = under, training = c.training, look = look })
		end
	end
	local gifts = {}
	for _, g in ipairs(Config.Gifts) do
		table.insert(gifts, { id = g.id, name = g.name, cost = Gifts.cost(g.cost, count, false, Config.Gallery.partnerDiscount, weekMult), partnerCost = Gifts.cost(g.cost, count, true, Config.Gallery.partnerDiscount, weekMult), underdogCost = Gifts.cost(g.cost, count, false, Config.Gallery.partnerDiscount, weekMult * Config.Training.underdogGiftMult) })
	end
	local cheers = nil
	if ctx.Progress.hasPass(p, "PatronPicks") then
		cheers = Config.CheerGifts
	end
	local hb = hazardBallot
	local eb = encoreBallot
	local encoreNames = {}
	if eb then
		for _, id in ipairs(eb.options) do
			local c = ctx.Match.contenders[id]
			table.insert(encoreNames, { id = id, name = c and c.name or id })
		end
	end
	return {
		favor = s and s.favor or 0,
		alive = alive,
		gifts = gifts,
		cheers = cheers,
		hazard = hb and { options = hb.options, counts = Vote.counts(hb), ends = hazardEnds, mine = hb.votes[tostring(p.UserId)] } or nil,
		hazardCards = Content.HAZARD_CARDS,
		encore = eb and { options = encoreNames, counts = Vote.counts(eb), ends = encoreEnds, mine = eb.votes[tostring(p.UserId)] } or nil,
		t = ctx.Match.t,
	}
end

local function pushViews()
	for p in pairs(spectators) do
		if p.Parent then
			ctx.push(p, "gallery", GalleryService.view(p))
		else
			spectators[p] = nil
		end
	end
end

-- ===== intents =====
local function wrapOf(player: Player): string?
	local pd = ctx.Progress.dataOf(player)
	local id = pd and pd.equipped and pd.equipped.wrap
	local it = id and Store.byId[id]
	return it and it.color or nil
end

-- Patron Picks: a firework flare or a cheering banner over a contender. Cosmetic only.
local lastCheer: { [string]: number } = {}
local function cheer(player: Player, s: any, c: any, id: string): (boolean, string?)
	local g = nil
	for _, x in ipairs(Config.CheerGifts) do
		if x.id == id then
			g = x
		end
	end
	if not g then
		return false, nil
	end
	if not ctx.Progress.hasPass(player, "PatronPicks") then
		return false, "Cheers come with the Patron Picks pass."
	end
	local key = player.UserId .. ":" .. c.id
	if lastCheer[key] and now() - lastCheer[key] < Config.CheerCooldown then
		return false, "You just cheered for them!"
	end
	if s.favor < g.cost then
		return false, string.format("Needs %d %s.", g.cost, Names.FAVOR)
	end
	s.favor -= g.cost
	lastCheer[key] = now()
	local root = ctx.Match.rootOf(c)
	ctx.pushAll("cheer", { kind = g.id, from = player.DisplayName, to = c.name, at = root and root.Position or nil, color = wrapOf(player) or "#FFD36B" })
	if c.player then
		ctx.push(c.player, "toast", { text = string.format("📣 %s is cheering for you!", player.DisplayName), kind = "good" })
	end
	pushViews()
	return true, g.id == "flare" and "🎆 Flare away!" or "📣 Cheer sent!"
end
local function gift(player: Player, targetId: any, giftId: any): (boolean, string?)
	local s = spectators[player]
	if not s then
		return false, "Gifts are sent from " .. Names.GALLERY .. "."
	end
	if type(targetId) ~= "string" or type(giftId) ~= "string" then
		return false, nil
	end
	local c = ctx.Match.contenders[targetId]
	if not c or not c.alive then
		return false, "They're out already."
	end
	local g = nil
	for _, x in ipairs(Config.Gifts) do
		if x.id == giftId then
			g = x
		end
	end
	if not g then
		return cheer(player, s, c, giftId)
	end
	local ok, wait = Gifts.canSend(lastGift, targetId, now(), Config.Gallery.giftCooldown)
	if not ok then
		return false, string.format("%s just got a gift. Try again in %ds.", c.name, math.ceil(wait))
	end
	if inAir >= Config.Gallery.maxInAir then
		return false, "The sky is full of parachutes! Wait a moment."
	end
	local mine = ctx.Match.contenderOf(player)
	local isPartner = mine ~= nil and mine.partner == c.id
	-- underdog rule: a low training score makes gifts to that contender cheaper
	local under = Training.giftMult(c.training, Config.Training.underdogAt, Config.Training.underdogGiftMult)
	local cost = Gifts.cost(g.cost, ctx.Match.aliveCount(), isPartner, Config.Gallery.partnerDiscount, Twists.mod({ ctx.Match.weekly }, "giftCost", 1) * under)
	if s.favor < cost then
		return false, string.format("Needs %d %s. You earn it by watching.", cost, Names.FAVOR)
	end
	s.favor -= cost
	s.gifts += 1
	lastGift[targetId] = now()
	GalleryService.dropGift(c, g.item, player.DisplayName, nil, wrapOf(player))
	ctx.Progress.bump(player, "gifts", 1)
	ctx.Progress.onboard(player, "gallery")
	local pd = ctx.Progress.dataOf(player)
	if pd then
		pd.stats.gifts += 1
	end
	pushViews()
	return true, "Gift away! 🪂"
end

local function vote(player: Player, kind: any, option: any): (boolean, string?)
	if not spectators[player] or type(option) ~= "string" then
		return false, nil
	end
	local b = (kind == "encore") and encoreBallot or hazardBallot
	if not b then
		return false, "No vote open right now."
	end
	local first = b.votes[tostring(player.UserId)] == nil
	if not Vote.cast(b, tostring(player.UserId), option) then
		return false, nil
	end
	ctx.Progress.onboard(player, "gallery")
	if first then
		spectators[player].votes += 1
		ctx.Progress.bump(player, "votes", 1)
	end
	pushViews()
	return true, nil
end

function GalleryService.onArenaStart()
	table.clear(partnerShown)
	live = true
	lastGift = {}
	inAir = 0
	hazardBallot = nil
	encoreBallot = nil
	nextHazardVote = math.floor(Config.Hazards.voteFirstAt * ctx.Match.mode.pace)
	encoresLeft = math.floor(Twists.mod({ ctx.Match.weekly }, "encores", 1))
end

function GalleryService.onArenaEnd()
	live = false
	hazardBallot = nil
	encoreBallot = nil
	pushViews()
end

-- v4: the Gallery partner moment. Once a match, when your partner reaches the last 10 or runs
-- low on Pep, a calm card offers a Favor gift (earned currency, never Robux).
partnerMoments = function()
	local M = ctx.Match
	local alive = M.aliveCount()
	for p, s in pairs(spectators) do
		if not partnerShown[p] then
			local mine = M.contenderOf(p)
			local partner = mine and mine.partner and M.contenders[mine.partner]
			if partner and partner.alive and Offers.partnerMoment(alive, partner.pep, Config.PEP_MAX) then
				partnerShown[p] = true
				local g = Config.Gifts[1]
				for _, x in ipairs(Config.Gifts) do
					if x.id == (partner.pep <= Config.PEP_MAX * 0.35 and "bandage" or "water") then
						g = x
					end
				end
				local cost = Gifts.cost(g.cost, alive, true, Config.Gallery.partnerDiscount, Twists.mod({ M.weekly }, "giftCost", 1))
				local wid = (ctx.Progress.dataOf(p) or { equipped = {} }).equipped.wrap
				local w = Store.byId[wid or ""]
				local card = Offers.partnerCard(partner.name, g.name, cost, s.favor, w and w.name or nil)
				card.target = partner.id
				card.gift = g.id
				ctx.push(p, "partnerMoment", card)
			end
		end
	end
end

local function tick()
	local M = ctx.Match
	local t = M.t
	-- Favor
	for p, s in pairs(spectators) do
		local rate = ctx.Progress.hasPass(p, "BigSponsor") and 2 or 1
		s.favor += rate
	end
	-- hazard votes
	if hazardBallot and now() >= hazardEnds then
		local winner = Vote.winner(hazardBallot)
		hazardBallot = nil
		M.startHazard(winner)
	elseif not hazardBallot and t >= nextHazardVote and next(spectators) ~= nil then
		nextHazardVote = t + math.max(45, math.floor(Config.Hazards.voteEvery * M.mode.pace))
		local opts = {}
		for _, card in ipairs(Content.HAZARD_CARDS) do
			table.insert(opts, card.id)
		end
		hazardBallot = Vote.new(opts)
		hazardEnds = now() + Config.Hazards.voteLength
		ctx.pushAll("vote", { kind = "hazard", seconds = Config.Hazards.voteLength })
	end
	-- Encore
	local E = Config.Encore
	if encoreBallot and now() >= encoreEnds then
		local winner = Vote.winner(encoreBallot)
		encoreBallot = nil
		local c = M.contenders[winner]
		if c then
			M.revive(c)
		end
	elseif not encoreBallot and encoresLeft > 0 and t >= (E.at + (1 - encoresLeft) * 120) * M.mode.pace and M.aliveCount() >= E.minAlive then
		local out = {}
		for _, c in pairs(M.contenders) do
			if not c.alive and c.place and not c.encore then
				table.insert(out, c)
			end
		end
		table.sort(out, function(a: any, b: any): boolean
			local ah = a.player and 1 or 0
			local bh = b.player and 1 or 0
			if ah ~= bh then
				return ah > bh
			end
			return a.knocks > b.knocks
		end)
		if #out > 0 then
			encoresLeft -= 1
			local opts = {}
			for i = 1, math.min(E.candidates, #out) do
				table.insert(opts, out[i].id)
			end
			encoreBallot = Vote.new(opts)
			encoreEnds = now() + E.length
			ctx.pushAll("vote", { kind = "encore", seconds = E.length })
		end
	end
	partnerMoments()
	pushViews()
end

function GalleryService.init(c: any)
	ctx = c
	ctx.handle("gift", gift)
	ctx.handle("vote", vote)
	ctx.handle("leaveGallery", function(player: Player): (boolean, string?)
		local mine = ctx.Match.contenderOf(player)
		if mine and mine.alive then
			return false, nil
		end
		GalleryService.removeSpectator(player)
		task.spawn(function()
			player:LoadCharacterAsync()
		end)
		return true, nil
	end)
end

function GalleryService.start()
	Players.PlayerRemoving:Connect(function(p)
		spectators[p] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Config.Gallery.favorEvery)
			if live then
				local ok, err = pcall(function(): any
					tick()
					return nil
				end)
				if not ok then
					warn("[GalleryService] " .. tostring(err))
				end
			end
		end
	end)
	local _ = rng
end

return GalleryService

--!strict
-- The always-on HUD: progress bar, lobby queue card, arena vitals, hotbar and menu buttons.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(script.Parent.UI)
local Net = require(script.Parent.Net)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Names = require(Shared.Names)
local T = UI.Theme

local Hud = {}
local panels: any = nil
local lastTier: number? = nil
local premiumNoted = false
Hud.note = function(_text: string) end -- set by Main (Fx.toast)
function Hud.openPanel(id: string)
	if panels then
		panels.open(id)
	end
end
local refs: { [string]: any } = {}
Hud.lobby = nil :: any
Hud.match = nil :: any
Hud.inv = nil :: any
Hud.pep = Config.PEP_MAX
Hud.vitals = nil :: any -- server-owned stamina + Food/Water
Hud.pact = nil :: any
Hud.mode = "lobby" -- "lobby" | "pregame" | "arena" | "gallery"

local function secs(n: number?): string
	n = math.max(0, math.floor(n or 0))
	return string.format("%d:%02d", (n :: number) // 60, (n :: number) % 60)
end

local function topBar(parent: Frame)
	local bar = UI.frame({ Name = "TopBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.new(0, 560, 0, 56), BackgroundTransparency = 0.1, Parent = parent })
	UI.corner(bar, 14)
	UI.stroke(bar, T.gold, 1.5)
	UI.pad(bar, 8)
	refs.level = UI.label("Lv 1", { Size = UDim2.new(0, 120, 0, 22), TextSize = 20, TextColor3 = T.gold, Parent = bar })
	refs.rank = UI.label("Reaped", { Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(0, 120, 0, 18), TextSize = 14, TextColor3 = T.dim, Font = T.body, Parent = bar })
	local back, fill = UI.bar(bar, T.gold, { Position = UDim2.new(0, 124, 0, 6), Size = UDim2.new(1, -300, 0, 12) })
	refs.xpFill = fill
	refs.xp = UI.label("", { Position = UDim2.new(0, 124, 0, 20), Size = UDim2.new(1, -300, 0, 18), TextSize = 14, Font = T.body, TextColor3 = T.dim, Parent = bar })
	local _ = back
	refs.streak = UI.label("🔥 0", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 170, 0, 22), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Right, Parent = bar })
	refs.play = UI.label("", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 22), Size = UDim2.new(0, 170, 0, 18), TextSize = 14, Font = T.body, TextColor3 = T.dim, TextXAlignment = Enum.TextXAlignment.Right, Parent = bar })
end

local MENU = {
	{ id = "season", text = "🌅 " .. Names.TRACK },
	{ id = "challenges", text = "📜 Challenges" },
	{ id = "letters", text = "✉️ Letters" },
	{ id = "reach", text = "🏳️ My Reach" },
	{ id = "tokens", text = "🪙 " .. Names.TOKENS },
	{ id = "shop", text = "🛍️ Shop" },
	{ id = "profile", text = "👤 Profile" },
	{ id = "settings", text = "⚙️ Settings" },
}

local function menu(parent: Frame)
	local col = UI.frame({ Name = "Menu", BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0.5, -192), Size = UDim2.new(0, 190, 0, 384), Parent = parent })
	UI.list(col, nil, 6)
	refs.badges = {}
	for i, m in ipairs(MENU) do
		local b = UI.button(m.text, T.card, { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 40), TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Left, Parent = col }, function()
			panels.open(m.id)
		end)
		UI.pad(b, 10)
		local badge = UI.label("", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 4, 0.5, 0), Size = UDim2.new(0, 26, 0, 26), BackgroundColor3 = T.red, BackgroundTransparency = 0, TextXAlignment = Enum.TextXAlignment.Center, TextSize = 14, Visible = false, Parent = b })
		UI.corner(badge, 13)
		refs.badges[m.id] = badge
	end
	refs.menu = col
end

local function lobbyCard(parent: Frame)
	local card = UI.frame({ Name = "LobbyCard", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.new(0, 520, 0, 150), BackgroundTransparency = 0.05, Parent = parent })
	UI.corner(card, 16)
	UI.stroke(card, T.gold, 1.5)
	UI.pad(card, 12)
	refs.lobbyTitle = UI.label(Names.EVENT, { Size = UDim2.new(1, 0, 0, 26), TextSize = 22, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
	refs.lobbyStatus = UI.label("", { Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, 0, 0, 22), TextSize = 17, Font = T.body, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
	refs.lobbyRule = UI.label("", { Position = UDim2.new(0, 0, 0, 50), Size = UDim2.new(1, 0, 0, 20), TextSize = 14, Font = T.body, TextColor3 = T.dim, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
	local row = UI.frame({ BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -48), Size = UDim2.new(1, 0, 0, 46), Parent = card })
	UI.list(row, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center)
	refs.queueBtn = UI.button("Enter the " .. Names.DRAW, T.gold, { LayoutOrder = 1, Size = UDim2.new(0, 230, 0, 44), TextSize = 20, Parent = row }, function()
		if Hud.lobby and Hud.lobby.inQueue then
			Net.act("leave")
		else
			Net.act("queue")
		end
	end)
	refs.partnerBtn = UI.button("👥 Partner", T.blue, { LayoutOrder = 2, Size = UDim2.new(0, 120, 0, 44), Parent = row }, function()
		panels.open("partner")
	end)
	refs.autoBtn = UI.button("Auto: ON", T.card, { LayoutOrder = 3, Size = UDim2.new(0, 110, 0, 44), TextColor3 = T.text, Parent = row }, function()
		local s = Net.state and Net.state.settings
		Net.act("setting", "autoQueue", not (s and s.autoQueue))
	end)
	refs.lobbyCard = card
end

local function arenaHud(parent: Frame)
	local box = UI.frame({ Name = "Vitals", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -14), Size = UDim2.new(0, 300, 0, 112), BackgroundTransparency = 0.1, Parent = parent })
	UI.corner(box, 12)
	UI.pad(box, 10)
	refs.pepLabel = UI.label("Pep 100", { Size = UDim2.new(1, 0, 0, 20), TextSize = 17, Parent = box })
	local _, pepFill = UI.bar(box, Color3.fromHex("#E0B44A"), { Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, 0, 0, 14) })
	refs.pepFill = pepFill
	local function small(y: number, color: Color3, label: string, x: number, w: number): Frame
		UI.label(label, { Position = UDim2.new(x, 0, 0, y), Size = UDim2.new(w, -4, 0, 14), TextSize = 12, Font = T.body, TextColor3 = T.dim, Parent = box })
		local _, fill = UI.bar(box, color, { Position = UDim2.new(x, 0, 0, y + 15), Size = UDim2.new(w, -6, 0, 8) })
		return fill
	end
	refs.stamFill = small(42, Color3.fromHex("#8FD27A"), "Stamina", 0, 0.34)
	refs.foodFill = small(42, Color3.fromHex("#D9A15B"), "Food", 0.34, 0.33)
	refs.waterFill = small(42, Color3.fromHex("#6FB6E0"), "Water", 0.67, 0.33)
	refs.ammo = UI.label("", { Position = UDim2.new(0, 0, 0, 70), Size = UDim2.new(1, 0, 0, 18), TextSize = 13, Font = T.body, TextColor3 = T.dim, TextWrapped = true, Parent = box })
	refs.vitals = box

	-- Pact box: who you're allied with, offers, and the snap button.
	local pb = UI.frame({ Name = "Pact", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 188), Size = UDim2.new(0, 250, 0, 96), BackgroundTransparency = 0.1, Parent = parent })
	UI.corner(pb, 12)
	UI.pad(pb, 8)
	refs.pactText = UI.label("", { Size = UDim2.new(1, 0, 0, 40), TextSize = 14, Font = T.body, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = pb })
	local prow = UI.frame({ BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -36), Size = UDim2.new(1, 0, 0, 34), Parent = pb })
	UI.list(prow, Enum.FillDirection.Horizontal, 6)
	refs.pactA = UI.button("Offer pact (P)", T.blue, { LayoutOrder = 1, Size = UDim2.new(0.5, -3, 1, 0), TextSize = 13, Parent = prow }, function()
		local p = Hud.pact
		if p and p.offer then
			Net.act("pactAccept")
		elseif p and #p.allies > 0 then
			Net.act("pactSnap")
		else
			Net.act("pactOffer")
		end
	end)
	refs.pactB = UI.button("Decline (N)", T.card, { LayoutOrder = 2, Size = UDim2.new(0.5, -3, 1, 0), TextSize = 13, TextColor3 = T.text, Parent = prow }, function()
		Net.act("pactDecline")
	end)
	refs.pact = pb

	local info = UI.frame({ Name = "MatchInfo", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 74), Size = UDim2.new(0, 250, 0, 106), BackgroundTransparency = 0.1, Parent = parent })
	UI.corner(info, 12)
	UI.pad(info, 10)
	refs.alive = UI.label("48 left", { Size = UDim2.new(1, 0, 0, 30), TextSize = 28, TextColor3 = T.gold, Parent = info })
	refs.veil = UI.label("", { Position = UDim2.new(0, 0, 0, 34), Size = UDim2.new(1, 0, 0, 20), TextSize = 15, Font = T.body, TextColor3 = T.veil, Parent = info })
	refs.twist = UI.label("", { Position = UDim2.new(0, 0, 0, 56), Size = UDim2.new(1, 0, 0, 30), TextSize = 13, Font = T.body, TextColor3 = T.dim, Parent = info })
	refs.info = info

	local bar = UI.frame({ Name = "Hotbar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.new(0, 6 * 70, 0, 66), BackgroundTransparency = 1, Parent = parent })
	UI.list(bar, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center)
	refs.slots = {}
	for i = 1, 6 do
		local s = UI.button("", T.card, { LayoutOrder = i, Size = UDim2.new(0, 64, 0, 64), TextSize = 13, TextColor3 = T.text, TextWrapped = true, Parent = bar }, function()
			Net.act("equipSlot", i)
		end)
		UI.label(tostring(i), { Position = UDim2.new(0, 4, 0, 2), Size = UDim2.new(0, 14, 0, 14), TextSize = 12, TextColor3 = T.dim, Parent = s })
		refs.slots[i] = s
	end
	refs.hotbar = bar

	-- Veil compass: tells you which way is safe when you're near the edge.
	refs.edge = UI.label("", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 72), Size = UDim2.new(0, 520, 0, 26), TextSize = 20, TextColor3 = T.veil, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4, Parent = parent })

	refs.viewBtn = UI.button("View: 3rd", T.card, {
		Name = "ViewToggle",
		Position = UDim2.new(0, 14, 0, 72),
		Size = UDim2.new(0, 124, 0, 32),
		TextSize = 14,
		TextColor3 = T.text,
		Visible = false,
		Parent = parent,
	}, function()
		local s = Net.state and Net.state.settings
		Net.act("setting", "viewFirst", not (s and s.viewFirst == true))
	end)
end

function Hud.mount(parent: Frame, p: any)
	panels = p
	topBar(parent)
	menu(parent)
	lobbyCard(parent)
	arenaHud(parent)
	Net.on("lobby", function(d)
		Hud.lobby = d
	end)
	Net.on("match", function(d)
		Hud.match = d
	end)
	Net.on("inv", function(d)
		Hud.inv = d
		Hud.pep = d.pep
	end)
	Net.on("pep", function(d)
		Hud.pep = d.pep
	end)
	Net.on("vitals", function(d)
		Hud.vitals = d
	end)
	Net.on("pact", function(d)
		Hud.pact = d
	end)
	Net.on("matchStart", function()
		Hud.pact = nil
		Hud.vitals = nil
	end)
	Net.on("arena", function()
		Hud.mode = "arena"
	end)
end

local ITEM_ICON: { [string]: string } = { bow = "🏹", spear = "🔱", knife = "🔪", arrows = "➶", backpack = "🎒", trailmix = "🥜", apple = "🍎", canteen = "🧴", bandage = "🩹", sweettea = "🍵" }

function Hud.update()
	local s = Net.state
	if s then
		refs.level.Text = string.format("Lv %d", s.level)
		refs.rank.Text = s.prestige > 0 and string.format("%s ★%d", s.rank, s.prestige) or s.rank
		refs.xpFill.Size = UDim2.new(math.clamp(s.xp / math.max(1, s.xpNext), 0, 1), 0, 1, 0)
		refs.xp.Text = string.format("%d / %d %s", s.xp, s.xpNext, Names.XP)
		refs.streak.Text = string.format("🔥 %d-day streak", s.streak)
		refs.play.Text = s.play > 0 and string.format("Match streak ×%.1f %s", s.playMult, Names.XP) or "Play again soon for a streak bonus"
		refs.autoBtn.Text = (s.settings and s.settings.autoQueue) and "Auto: ON" or "Auto: OFF"
		local first = s.settings and s.settings.viewFirst == true
		refs.viewBtn.Text = first and "View: 1st" or "View: 3rd"
		refs.viewBtn.Visible = true
		local openChallenges = 0
		for _, c in ipairs(s.daily) do
			if not c.done then
				openChallenges += 1
			end
		end
		local seasonBadge = s.season and s.season.unclaimed or 0
		-- one calm note per session when a tier is reached without the Premium lane
		if s.season and lastTier and s.season.tier > lastTier and not s.season.premium and not premiumNoted then
			premiumNoted = true
			Hud.note("Tier " .. s.season.tier .. " reached! The Premium lane has a ✦ reward here too. See it in the " .. Names.TRACK .. ".")
		end
		lastTier = s.season and s.season.tier or lastTier
		refs.badges.season.Visible = seasonBadge > 0
		refs.badges.season.Text = tostring(seasonBadge)
		refs.badges.challenges.Visible = openChallenges > 0
		refs.badges.challenges.Text = tostring(openChallenges)
		local letters = s.letters and s.letters.waiting or 0
		refs.badges.letters.Visible = letters > 0
		refs.badges.letters.Text = tostring(letters)
		-- a calm dot when this week's shop picks are new to you (no countdown)
		refs.badges.shop.Visible = s.store ~= nil and s.store.isNew == true
		refs.badges.shop.Text = "•"
	end
	local inArena = Hud.mode == "arena"
	refs.vitals.Visible = inArena
	refs.hotbar.Visible = inArena
	refs.info.Visible = inArena or Hud.mode == "gallery"
	refs.menu.Visible = Hud.mode == "lobby"
	refs.lobbyCard.Visible = Hud.mode == "lobby"
	refs.edge.Visible = inArena
	local pa = Hud.pact
	refs.pact.Visible = inArena and not (pa and pa.ended)
	if inArena then
		if pa and pa.offer then
			refs.pactText.Text = string.format("🤝 %s (%s) offers a pact.", pa.offer.name, pa.offer.reach)
			refs.pactA.Text = "Accept (Y)"
			refs.pactB.Visible = true
		elseif pa and #pa.allies > 0 then
			refs.pactText.Text = (pa.snapping and "Snapping… " or "Pact: ") .. table.concat(pa.allies, ", ")
			refs.pactA.Text = pa.snapping and "Snapping…" or "Snap pact (X)"
			refs.pactA.BackgroundColor3 = T.red
			refs.pactB.Visible = false
		else
			refs.pactText.Text = "No pact. Get close to someone from another " .. Names.REGION .. " and offer one."
			refs.pactA.Text = "Offer pact (P)"
			refs.pactA.BackgroundColor3 = T.blue
			refs.pactB.Visible = false
		end
	end
	local l = Hud.lobby
	if l then
		if l.state == "Arena" or l.state == "Pregame" or l.state == "Launch" then
			refs.lobbyStatus.Text = string.format("A %s is live (%s left). %s", Names.EVENT_SHORT, tostring(l.alive or "?"), l.inQueue and "You're in the next one." or "Queue for the next one!")
		elseif l.inQueue then
			refs.lobbyStatus.Text = string.format("In the %s: %d player%s. Stand-Ins fill to %d. Starts in %ds", Names.DRAW, l.queued, l.queued == 1 and "" or "s", l.size, math.ceil(l.seconds or 0))
		else
			refs.lobbyStatus.Text = string.format("%d in the %s. Step on the gold pad or press the button.", l.queued, Names.DRAW)
		end
		refs.queueBtn.Text = l.inQueue and "Leave the " .. Names.DRAW or "Enter the " .. Names.DRAW
		refs.queueBtn.BackgroundColor3 = l.inQueue and T.red or T.gold
		refs.queueBtn.TextColor3 = l.inQueue and Color3.new(1, 1, 1) or T.dark
		refs.partnerBtn.Text = l.partner and ("👥 " .. l.partner) or (l.invite and "👥 Invite!" or "👥 Partner")
		refs.lobbyRule.Text = l.weekly and ("This week: " .. l.weekly.name .. " · " .. l.weekly.text) or ""
	end
	local m = Hud.match
	if m and (inArena or Hud.mode == "gallery") then
		refs.alive.Text = string.format("%d left", m.alive)
		if m.calm then
			refs.veil.Text = string.format("Dome broken! %s calm for %ds", Names.VEIL, m.calm)
		elseif m.core then
			refs.veil.Text = "The Veil Core is lit: bounce a spear into it"
		elseif m.shrinking then
			refs.veil.Text = string.format("%s is closing!", Names.VEIL)
		elseif m.nextIn then
			refs.veil.Text = string.format("%s moves in %s", Names.VEIL, secs(m.nextIn))
		else
			refs.veil.Text = string.format("%s is at its smallest", Names.VEIL)
		end
		refs.twist.Text = m.twist and ("Twist: " .. m.twist) or ""
		local char = game:GetService("Players").LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp and inArena then
			local flat = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
			local d = flat.Magnitude
			if d > m.radius then
				refs.edge.Text = "⚠ Outside " .. Names.VEIL .. "! Head toward " .. Names.HUB .. "."
			elseif m.radius - d < 60 then
				refs.edge.Text = "Near " .. Names.VEIL .. " edge"
			else
				refs.edge.Text = ""
			end
		end
	end
	if inArena then
		local pep = Hud.pep
		refs.pepLabel.Text = string.format("Pep %d", math.floor(pep))
		refs.pepFill.Size = UDim2.new(math.clamp(pep / Config.PEP_MAX, 0, 1), 0, 1, 0)
		refs.pepFill.BackgroundColor3 = pep < 30 and T.red or Color3.fromHex("#E0B44A")
		local inv = Hud.inv
		for i = 1, 6 do
			local slot = refs.slots[i]
			local item = inv and inv.inv[i]
			local locked = inv == nil or i > inv.slots
			slot.Text = item and ((ITEM_ICON[item] or "•") .. "\n" .. ((Config.Items[item] and Config.Items[item].name) or item)) or (locked and "🔒" or "")
			slot.BackgroundColor3 = (inv and inv.equipped == i) and T.cardHi or T.card
			local stroke = slot:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = (inv and inv.equipped == i) and T.gold or Color3.fromHex("#0E1018")
			end
		end
		refs.ammo.Text = inv and string.format("Arrows %d · Bag %d/%d · Click use · Shift sprint · Q throw spear", inv.ammo, #inv.inv, inv.slots) or ""
		local v = Hud.vitals
		local M = Config.Meters
		refs.stamFill.Size = UDim2.new(math.clamp((v and v.stamina or Config.STAMINA_MAX) / Config.STAMINA_MAX, 0, 1), 0, 1, 0)
		refs.stamFill.BackgroundColor3 = (v and v.tired) and T.red or Color3.fromHex("#8FD27A")
		refs.foodFill.Size = UDim2.new(math.clamp((v and v.food or M.start) / M.max, 0, 1), 0, 1, 0)
		refs.waterFill.Size = UDim2.new(math.clamp((v and v.water or M.start) / M.max, 0, 1), 0, 1, 0)
	end
end

return Hud

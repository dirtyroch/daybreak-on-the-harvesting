--!strict
-- Lobby menus: Season Track, Challenges, My Reach, Tokens, Shop, Profile, Settings, Partner.
-- One modal window; each tab rebuilds its content from the latest state snapshot.
-- Shop copy stays calm: "Buy for R$ X", no timers, no "last chance".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(script.Parent.UI)
local Net = require(script.Parent.Net)
local Hud = require(script.Parent.Hud)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Names = require(Shared.Names)
local Content = require(Shared.Content)
local T = UI.Theme

local Panels = {}
local win: Frame = nil :: any
local title: TextLabel = nil :: any
local body: ScrollingFrame = nil :: any
local current: string? = nil

local function row(h: number?, order: number?): Frame
	local f = UI.frame({ BackgroundColor3 = T.card, Size = UDim2.new(1, -8, 0, h or 54), LayoutOrder = order or 0, Parent = body })
	UI.corner(f, 10)
	UI.pad(f, 8)
	return f
end

local function heading(text: string, order: number)
	UI.label(text, { Size = UDim2.new(1, -8, 0, 26), TextSize = 20, TextColor3 = T.gold, LayoutOrder = order, Parent = body })
end

local function note(text: string, order: number)
	UI.label(text, { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 15, Font = T.body, TextColor3 = T.dim, LayoutOrder = order, Parent = body })
end

local builders: { [string]: (any) -> () } = {}

builders.season = function(s: any)
	local se = s.season
	title.Text = "🌅 " .. Names.TRACK .. " · " .. se.name
	note(string.format("Tier %d of %d. %d %s, %d per tier. Earn %s from every match and every challenge. Tiers are never sold.", se.tier, #se.tiers, se.stars, Names.STARS, se.perTier, Names.STARS), 0)
	for i, tier in ipairs(se.tiers) do
		local f = row(58, i)
		local reached = i <= se.tier
		UI.label(string.format("Tier %d", i), { Size = UDim2.new(0, 70, 1, 0), TextSize = 18, TextColor3 = reached and T.gold or T.dim, Parent = f })
		UI.label("Free: " .. tier.free, { Position = UDim2.new(0, 76, 0, 0), Size = UDim2.new(0.5, -110, 1, 0), TextSize = 15, Font = T.body, Parent = f })
		UI.label("Premium: " .. tier.premium, { Position = UDim2.new(0.5, -30, 0, 0), Size = UDim2.new(0.5, -150, 1, 0), TextSize = 15, Font = T.body, TextColor3 = se.premium and T.text or T.dim, Parent = f })
		local freeDone = se.claimedFree[tostring(i)] or se.claimedFree[i]
		local premDone = se.claimedPremium[tostring(i)] or se.claimedPremium[i]
		if reached and not freeDone then
			UI.button("Claim", T.gold, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -86, 0.5, 0), Size = UDim2.new(0, 76, 0, 34), TextSize = 15, Parent = f }, function()
				Net.act("claimTier", i, "free")
			end)
		end
		if reached and se.premium and not premDone then
			UI.button("Claim ✦", T.blue, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 80, 0, 34), TextSize = 15, Parent = f }, function()
				Net.act("claimTier", i, "premium")
			end)
		end
	end
	if not se.premium then
		note("The Premium lane is an optional cosmetic pass. Find it in the Shop if you want it.", 999)
	end
end

local function challengeList(list: { any }, order: number)
	for i, c in ipairs(list) do
		local f = row(50, order + i)
		UI.label((c.done and "✅ " or "◻️ ") .. c.text, { Size = UDim2.new(1, -170, 1, 0), TextSize = 16, Font = T.body, Parent = f })
		UI.label(string.format("%d/%d · +%d %s · +%d ★", math.min(c.progress, c.goal), c.goal, c.xp, Names.XP, c.stars), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 170, 1, 0), TextSize = 14, Font = T.body, TextColor3 = T.dim, TextXAlignment = Enum.TextXAlignment.Right, Parent = f })
	end
end

builders.challenges = function(s: any)
	title.Text = "📜 Challenges"
	heading("Today", 0)
	challengeList(s.daily, 0)
	note(string.format("New daily challenges in %dh %dm. Rewards are added automatically when you finish.", s.dailyResetIn // 3600, (s.dailyResetIn % 3600) // 60), 50)
	heading("This week", 100)
	challengeList(s.weekly, 100)
	heading("Weekly " .. Names.EVENT_SHORT .. " rule", 200)
	note(s.weeklyRule.name .. ": " .. s.weeklyRule.text, 201)
end

builders.reach = function(s: any)
	title.Text = "🏳️ My " .. Names.REGION
	note(string.format("Pick a home %s. Every match you play earns it points on the weekly board. The top 3 %s each week give all their players a banner. You can switch once a week.", Names.REGION, Names.REGIONS), 0)
	heading("This week's board", 1)
	for i, r in ipairs(s.reachTop) do
		if i > 8 then
			break
		end
		local f = row(36, 1 + i)
		UI.label(string.format("#%d  %s", i, r.reach), { Size = UDim2.new(0.7, 0, 1, 0), TextSize = 16, TextColor3 = r.reach == s.reach and T.gold or T.text, Parent = f })
		UI.label(tostring(r.points), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.3, 0, 1, 0), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, Parent = f })
	end
	heading(s.canChangeReach and "Choose your " .. Names.REGION or ("Home: " .. (s.reach ~= "" and s.reach or "none")), 50)
	if s.canChangeReach or s.reach == "" then
		local grid = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 51, Parent = body })
		UI.new("UIGridLayout", { CellSize = UDim2.new(0, 150, 0, 36), CellPadding = UDim2.new(0, 6, 0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
		for i, name in ipairs(Names.REACH_LIST) do
			UI.button(name, name == s.reach and T.gold or T.card, { LayoutOrder = i, TextSize = 14, TextColor3 = name == s.reach and T.dark or T.text, Parent = grid }, function()
				Net.act("setReach", name)
			end)
		end
	end
end

builders.tokens = function(s: any)
	title.Text = "🪙 " .. Names.TOKENS
	note(string.format("%d of %d found. Tokens appear in the arena each match. Each one you find stays in your book forever.", s.tokens, s.tokenTotal), 0)
	local grid = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = body })
	UI.new("UIGridLayout", { CellSize = UDim2.new(0, 150, 0, 60), CellPadding = UDim2.new(0, 6, 0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	for i, t in ipairs(Content.TOKENS) do
		local have = s.tokenBook[t.id] ~= nil
		local f = UI.frame({ BackgroundColor3 = have and T.cardHi or T.card, LayoutOrder = i, Parent = grid })
		UI.corner(f, 10)
		UI.pad(f, 6)
		UI.label(have and t.name or "???", { Size = UDim2.new(1, 0, 0, 22), TextSize = 15, TextColor3 = have and T.gold or T.dim, Parent = f })
		UI.label("Found in: " .. t.zone, { Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, 0, 0, 18), TextSize = 12, Font = T.body, TextColor3 = T.dim, Parent = f })
	end
end

builders.shop = function(s: any)
	title.Text = "🛍️ Shop"
	note("Everything here is cosmetic or a convenience. Nothing is random, and Robux never buys tiers, Stars, or Favor.", 0)
	local shop = s.shop
	if not shop.visible then
		note("The shop is loading your store rules. Check back in a moment.", 1)
		return
	end
	local order = 1
	heading("Passes", order)
	for key, p in pairs(shop.catalog.passes) do
		order += 1
		local f = row(70, order)
		UI.label(p.icon .. " " .. p.name, { Size = UDim2.new(1, -150, 0, 22), TextSize = 17, Parent = f })
		UI.label(p.desc, { Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, -150, 0, 32), TextSize = 13, Font = T.body, TextColor3 = T.dim, Parent = f })
		local owned = s.passes[key]
		local avail = shop.passes[key]
		UI.button(owned and "Owned" or (avail and ("Buy for R$ " .. p.price) or "Not on sale yet"), owned and T.green or (avail and T.gold or T.card), { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 140, 0, 38), TextSize = 15, Parent = f }, function()
			if not owned and avail then
				Net.act("buy", "pass", key)
			end
		end)
	end
	order += 1
	heading("Items", order)
	for key, p in pairs(shop.catalog.products) do
		order += 1
		local f = row(70, order)
		UI.label(p.icon .. " " .. p.name .. "  ·  " .. p.category, { Size = UDim2.new(1, -150, 0, 22), TextSize = 17, Parent = f })
		UI.label(p.desc, { Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, -150, 0, 32), TextSize = 13, Font = T.body, TextColor3 = T.dim, Parent = f })
		local avail = shop.products[key]
		UI.button(avail and ("Buy for R$ " .. p.price) or "Not on sale yet", avail and T.gold or T.card, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 140, 0, 38), TextSize = 15, Parent = f }, function()
			if avail then
				Net.act("buy", "product", key)
			end
		end)
	end
	if shop.studio then
		note("Studio test mode: items with ID 0 are granted free here so you can try them. They're hidden in the live game until real IDs are set.", order + 1)
	end
end

builders.profile = function(s: any)
	title.Text = "👤 " .. Players.LocalPlayer.DisplayName
	local st = s.stats
	note(string.format("Level %d · %s%s · Home %s: %s", s.level, s.rank, s.prestige > 0 and (" ★" .. s.prestige) or "", Names.REGION, s.reach ~= "" and s.reach or "none"), 0)
	local lines = {
		{ "Matches", st.matches },
		{ "Wins", st.wins },
		{ "Top 5 finishes", st.top5 },
		{ "Best place", st.bestPlace > 0 and ("#" .. st.bestPlace) or "-" },
		{ "Knockouts", st.knocks },
		{ "Top 10 finishes", st.top10 },
		{ "Gifts sent", st.gifts },
		{ "Encores", st.encores },
		{ "Best day streak", s.bestStreak },
	}
	for i, l in ipairs(lines) do
		local f = row(34, i)
		UI.label(l[1], { Size = UDim2.new(0.6, 0, 1, 0), TextSize = 16, Font = T.body, Parent = f })
		UI.label(tostring(l[2]), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.4, 0, 1, 0), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, Parent = f })
	end
	heading("Knockout fade", 20)
	local grid = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 44), LayoutOrder = 21, Parent = body })
	UI.list(grid, Enum.FillDirection.Horizontal, 6)
	for id, f in pairs(Content.FADES) do
		local owned = id == "fade_gold" or s.owned[id]
		UI.button(f.name, s.equipped.fade == id and T.gold or T.card, { Size = UDim2.new(0, 140, 0, 38), TextSize = 14, TextColor3 = s.equipped.fade == id and T.dark or (owned and T.text or T.dim), Parent = grid }, function()
			Net.act("equip", "fade", id)
		end)
	end
	heading("Title", 25)
	local tgrid = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 44), LayoutOrder = 26, Parent = body })
	UI.list(tgrid, Enum.FillDirection.Horizontal, 6)
	UI.button("None", s.equipped.title == "" and T.gold or T.card, { Size = UDim2.new(0, 90, 0, 38), TextSize = 14, TextColor3 = s.equipped.title == "" and T.dark or T.text, Parent = tgrid }, function()
		Net.act("equip", "title", "")
	end)
	for id, name in pairs(Content.TITLES) do
		if s.owned[id] then
			UI.button(name, s.equipped.title == id and T.gold or T.card, { Size = UDim2.new(0, 170, 0, 38), TextSize = 14, TextColor3 = s.equipped.title == id and T.dark or T.text, Parent = tgrid }, function()
				Net.act("equip", "title", id)
			end)
		end
	end
	heading("Interview line (your default answer)", 30)
	for i, q in ipairs(Content.QUIPS) do
		UI.button((s.quip == i and "● " or "○ ") .. q, s.quip == i and T.cardHi or T.card, { LayoutOrder = 30 + i, Size = UDim2.new(1, -8, 0, 34), TextSize = 14, TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Left, Parent = body }, function()
			Net.act("quip", i)
		end)
	end
	if s.canPrestige then
		UI.button("Prestige to " .. Names.rank(s.prestige + 1), T.gold, { LayoutOrder = 60, Size = UDim2.new(0, 260, 0, 42), Parent = body }, function()
			Net.act("prestige")
		end)
	end
end

builders.letters = function(s: any)
	title.Text = "✉️ Sponsor letters"
	local L = s.letters or { waiting = 0, from = {}, perLetter = {} }
	note("Patrons you've won over send one letter a day, even on days you don't play. Up to 3 wait for you. Nothing in a letter is random or sold.", 0)
	heading(L.waiting > 0 and string.format("%d letter%s waiting", L.waiting, L.waiting == 1 and "" or "s") or "No letters waiting. The next one arrives tomorrow.", 1)
	if L.waiting > 0 then
		UI.button(string.format("Open (+%d %s, +%d %s head start)", L.perLetter.renown * L.waiting, Names.XP, L.perLetter.favor * L.waiting, Names.FAVOR), T.gold, { LayoutOrder = 2, Size = UDim2.new(1, -8, 0, 44), TextSize = 17, Parent = body }, function()
			Net.act("claimLetters")
		end)
	end
	heading("Your patrons", 10)
	for i, name in ipairs(L.from) do
		note("• " .. name, 10 + i)
	end
	if L.next then
		note(string.format("Next patron: %s (%s %d/%d)", L.next.name, L.next.stat, L.next.have, L.next.need), 40)
	end
	if L.cosmeticIn then
		note(string.format("A cosmetic rides along in %d more letter%s.", L.cosmeticIn, L.cosmeticIn == 1 and "" or "s"), 41)
	end
	if s.favorBank and s.favorBank > 0 then
		note(string.format("Banked %s for your next %s visit: %d", Names.FAVOR, Names.GALLERY, s.favorBank), 42)
	end
end

builders.settings = function(s: any)
	title.Text = "⚙️ Settings"
	local opts = {
		{ key = "autoQueue", text = "Auto-queue the next match" },
		{ key = "shortReaping", text = "Short " .. Names.DRAW .. " cutscene" },
		{ key = "sfx", text = "Sound effects" },
	}
	for i, o in ipairs(opts) do
		local on = s.settings[o.key] ~= false
		if o.key == "shortReaping" then
			on = s.settings.shortReaping == true
		end
		local f = row(48, i)
		UI.label(o.text, { Size = UDim2.new(1, -110, 1, 0), TextSize = 17, Font = T.body, Parent = f })
		UI.button(on and "ON" or "OFF", on and T.green or T.card, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 90, 0, 34), TextColor3 = T.text, Parent = f }, function()
			Net.act("setting", o.key, not on)
		end)
	end
end

builders.partner = function(_s: any)
	title.Text = "👥 Partner"
	note("Queue with a partner: you'll share a " .. Names.REGION .. ", start side by side, and gifts to each other cost less. Invite someone; if they invite you back, you're partners.", 0)
	local l = Hud.lobby
	if l and l.partner then
		local f = row(48, 1)
		UI.label("Partnered with " .. l.partner, { Size = UDim2.new(1, -130, 1, 0), TextSize = 17, Parent = f })
		UI.button("Split up", T.red, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 120, 0, 34), Parent = f }, function()
			Net.act("unpartner")
		end)
	end
	local n = 1
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= Players.LocalPlayer then
			n += 1
			local f = row(48, n)
			local invitedMe = l and l.inviteFrom == p.UserId
			UI.label(p.DisplayName .. (invitedMe and "  · invited you!" or ""), { Size = UDim2.new(1, -130, 1, 0), TextSize = 17, Parent = f })
			UI.button(invitedMe and "Accept" or "Invite", invitedMe and T.green or T.blue, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 120, 0, 34), Parent = f }, function()
				Net.act("invite", p.UserId)
			end)
		end
	end
	if n == 1 then
		note("Nobody else is here yet. Invite a friend to the experience!", 2)
	end
end

local ALIAS: { [string]: string } = { seasonboard = "season", challengeboard = "challenges", reachboard = "reach" }

function Panels.refresh()
	if not current or not Net.state then
		return
	end
	UI.clear(body)
	local ok, err = pcall(function(): any
		builders[current :: string](Net.state)
		return nil
	end)
	if not ok then
		warn("[Panels] " .. tostring(err))
	end
end

function Panels.open(id: string)
	id = ALIAS[id] or id
	if not builders[id] then
		return
	end
	current = id
	win.Visible = true
	body.CanvasPosition = Vector2.zero
	Panels.refresh()
end

function Panels.close()
	current = nil
	win.Visible = false
end

function Panels.isOpen(): boolean
	return current ~= nil
end

function Panels.mount(parent: Frame)
	win = UI.frame({ Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.new(0, 720, 0, 520), Visible = false, ZIndex = 5, Parent = parent })
	UI.corner(win, 16)
	UI.stroke(win, T.gold, 2)
	UI.pad(win, 14)
	title = UI.label("", { Size = UDim2.new(1, -50, 0, 34), TextSize = 26, TextColor3 = T.gold, Parent = win })
	UI.button("✕", T.red, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 38, 0, 38), Parent = win }, Panels.close)
	body = UI.new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0, 0, 0, 44), Size = UDim2.new(1, 0, 1, -44), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, ScrollBarImageColor3 = T.gold, Parent = win })
	UI.list(body, nil, 6)
	Net.changed.Event:Connect(Panels.refresh)
	Net.on("lobby", function()
		if current == "partner" then
			Panels.refresh()
		end
	end)
	Net.on("openPanel", function(d)
		if d.kind == "training" then
			return
		end
		Panels.open(d.kind)
	end)
end

return Panels

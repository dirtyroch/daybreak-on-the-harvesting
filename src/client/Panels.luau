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
local Shop = require(Shared.Store)
local Settings = require(Shared.Logic.Settings)
local Mastery = require(Shared.Mastery)
local TryOn = require(script.Parent.TryOn)
local SocialService = game:GetService("SocialService")
Shop.addReachPride(Names.REACH_LIST)
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
	note(string.format("Tier %d of %d. %d %s, %d per tier. Earn %s from every match and every challenge. Tier Skips in the shop only move you along; every reward is cosmetic.", se.tier, #se.tiers, se.stars, Names.STARS, se.perTier, Names.STARS), 0)
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

-- ===================== Item Shop (v3) =====================
-- Tabs: This Week, Arms, Style, Reach, Bundles, Passes & Club. Every buy goes through a
-- confirm card that names the exact item and price. Nothing is random; rotation is a fixed
-- weekly schedule, so "Back in N weeks" is always true.
local shopTab = "week"
local confirm: Frame? = nil
local friendCache: { [number]: boolean } = {}

local function closeConfirm()
	if confirm then
		confirm:Destroy()
		confirm = nil
	end
end

local function isFriend(p: Player): boolean
	local v = friendCache[p.UserId]
	if v == nil then
		local ok, res = pcall(function()
			return Players.LocalPlayer:IsFriendsWithAsync(p.UserId)
		end)
		v = ok and res == true
		friendCache[p.UserId] = v
	end
	return v :: boolean
end

local function openConfirm(o: any, store: any)
	closeConfirm()
	task.spawn(Net.act, "shopStep", "item_view")
	local c = UI.frame({ BackgroundColor3 = T.bg, BackgroundTransparency = 0.15, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = win })
	confirm = c
	UI.corner(c, 14)
	local card = UI.frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 420, 0, 300), BackgroundColor3 = T.panel, ZIndex = 21, Parent = c })
	UI.corner(card, 14)
	UI.stroke(card, T.gold, 2)
	UI.pad(card, 16)
	UI.label(o.icon .. " " .. o.name, { Size = UDim2.new(1, 0, 0, 34), TextSize = 24, TextColor3 = T.gold, ZIndex = 22, Parent = card })
	UI.label(o.desc or "", { Position = UDim2.new(0, 0, 0, 38), Size = UDim2.new(1, 0, 0, 52), TextSize = 15, Font = T.body, TextColor3 = T.dim, TextWrapped = true, ZIndex = 22, Parent = card })
	local voucher = store.vouchers and Shop.voucherFor(store.vouchers, o.price)
	local gifting: Player? = nil
	local status = UI.label("", { Position = UDim2.new(0, 0, 0, 92), Size = UDim2.new(1, 0, 0, 22), TextSize = 14, Font = T.body, TextColor3 = T.text, ZIndex = 22, Parent = card })
	local function refreshStatus()
		status.Text = (gifting and ("🎁 Gift to " .. gifting.DisplayName) or "For you") .. (voucher and "  ·  you have a voucher for this" or "")
	end
	refreshStatus()
	local function buy(useVoucher: boolean)
		Net.act("shopBuy", o.kind, o.id, { to = gifting and gifting.UserId or nil, voucher = useVoucher })
		closeConfirm()
	end
	UI.button("Buy for R$ " .. o.price, T.gold, { Position = UDim2.new(0, 0, 1, -96), Size = UDim2.new(0.5, -4, 0, 42), TextSize = 17, ZIndex = 22, Parent = card }, function()
		buy(false)
	end)
	UI.button("Not now", T.card, { Position = UDim2.new(0.5, 4, 1, -96), Size = UDim2.new(0.5, -4, 0, 42), TextSize = 17, TextColor3 = T.text, ZIndex = 22, Parent = card }, closeConfirm)
	if voucher then
		UI.button("Use voucher (R$ " .. voucher .. ")", T.green, { Position = UDim2.new(0, 0, 1, -48), Size = UDim2.new(0.5, -4, 0, 40), TextSize = 15, TextColor3 = T.text, ZIndex = 22, Parent = card }, function()
			buy(true)
		end)
	end
	if not o.once then
		UI.button("🎁 Gift to a friend", T.blue, { Position = UDim2.new(0.5, 4, 1, -48), Size = UDim2.new(0.5, -4, 0, 40), TextSize = 15, TextColor3 = T.text, ZIndex = 22, Parent = card }, function()
			local picker = UI.frame({ Position = UDim2.new(0, 0, 0, 118), Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1, ZIndex = 23, Parent = card })
			UI.list(picker, Enum.FillDirection.Horizontal, 6)
			local any = false
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= Players.LocalPlayer and isFriend(p) then
					any = true
					UI.button(p.DisplayName, gifting == p and T.gold or T.card, { Size = UDim2.new(0, 120, 0, 34), TextSize = 14, TextColor3 = gifting == p and T.dark or T.text, ZIndex = 24, Parent = picker }, function()
						gifting = p
						refreshStatus()
						picker:Destroy()
					end)
				end
			end
			if not any then
				UI.label("Gifts go to a friend in this server. None here right now.", { Size = UDim2.new(1, 0, 0, 30), TextSize = 14, Font = T.body, TextColor3 = T.dim, ZIndex = 24, Parent = picker })
			end
		end)
	end
end

local function itemCard(parent: Instance, it: any, order: number, store: any)
	local f = UI.frame({ BackgroundColor3 = it.owned and T.cardHi or T.card, LayoutOrder = order, Parent = parent })
	UI.corner(f, 10)
	UI.pad(f, 6)
	local sw = UI.frame({ BackgroundColor3 = Color3.fromHex(it.color or "#F4EFE6"), Size = UDim2.new(1, 0, 0, 6), Parent = f })
	UI.corner(sw, 3)
	UI.label(it.icon, { Position = UDim2.new(0, 0, 0, 10), Size = UDim2.new(1, 0, 0, 40), TextSize = 32, TextXAlignment = Enum.TextXAlignment.Center, Parent = f })
	UI.label(it.name, { Position = UDim2.new(0, 0, 0, 52), Size = UDim2.new(1, 0, 0, 20), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, Parent = f })
	if not it.owned and TryOn.canTry(it.id) then
		UI.button("👁 Try", T.blue, { Position = UDim2.new(0, 0, 1, -64), Size = UDim2.new(1, 0, 0, 26), TextSize = 12, TextColor3 = T.text, Parent = f }, function()
			task.spawn(Net.act, "shopStep", "try_on")
			Panels.close()
			TryOn.show(it.id)
		end)
	end
	local label = it.owned and "Owned" or ("R$ " .. it.price)
	local color = it.owned and T.green or T.gold
	if not it.owned and not it.canBuy then
		label = it.why or "Not now"
		color = T.card
	end
	UI.button(label, color, { Position = UDim2.new(0, 0, 1, -32), Size = UDim2.new(1, 0, 0, 32), TextSize = 13, TextColor3 = color == T.gold and T.dark or T.text, Parent = f }, function()
		if it.owned then
			Panels.open("profile")
		elseif it.canBuy then
			openConfirm({ kind = "item", id = it.id, name = it.name, icon = it.icon, price = it.price, desc = it.desc }, store)
		end
	end)
end

local function grid(order: number, h: number?): Frame
	local g = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = body })
	UI.new("UIGridLayout", { CellSize = UDim2.new(0, 132, 0, h or 166), CellPadding = UDim2.new(0, 8, 0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = g })
	return g
end

local SHOP_TABS = {
	{ id = "week", text = "This Week" },
	{ id = "arms", text = "Arms" },
	{ id = "style", text = "Style" },
	{ id = "reach", text = "Reach Pride" },
	{ id = "bundles", text = "Bundles" },
	{ id = "passes", text = "Passes & Club" },
}
local TAB_CATS: { [string]: { string } } = {
	arms = { "Arms" },
	style = { "Fades", "Poses", "Emotes", "Wraps", "Nametags", "Parade", "Rusty" },
	reach = { "Reach" },
}

builders.shop = function(s: any)
	title.Text = "🛍️ Daybreak Shop"
	closeConfirm()
	local shop = s.shop
	local store = s.store
	if not shop.visible or not store then
		note("The shop is loading your store rules. Check back in a moment.", 0)
		return
	end
	if store.isNew then
		Net.act("seenShop")
	end
	local tabs = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 40), LayoutOrder = 0, Parent = body })
	UI.list(tabs, Enum.FillDirection.Horizontal, 6)
	for _, t in ipairs(SHOP_TABS) do
		UI.button(t.text, shopTab == t.id and T.gold or T.card, { Size = UDim2.new(0, 112, 0, 36), TextSize = 14, TextColor3 = shopTab == t.id and T.dark or T.text, Parent = tabs }, function()
			shopTab = t.id
			Panels.refresh()
		end)
	end
	local order = 1
	if shopTab == "week" then
		if store.dropName then
			heading("🌾 This week's drop: " .. store.dropName, order)
			order += 1
		end
		note(string.format("New picks every Monday. Today's six change on %s. Every item comes back on a fixed %d-week cycle. Cosmetic only, never random.", store.changesOn, store.cycle), order)
		order += 1
		local g = grid(order)
		for i, it in ipairs(store.featured) do
			itemCard(g, it, i, store)
		end
		order += 1
		local st = nil
		for _, b in ipairs(store.bundles) do
			if b.once then
				st = b
			end
		end
		if st and st.canBuy then
			local f = row(70, order)
			UI.label(st.icon .. " " .. st.name, { Size = UDim2.new(1, -150, 0, 24), TextSize = 18, TextColor3 = T.gold, Parent = f })
			UI.label(string.format("%s Worth R$ %d on its own. One per account.", st.desc, st.value), { Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, -150, 0, 32), TextSize = 13, Font = T.body, TextColor3 = T.dim, TextWrapped = true, Parent = f })
			UI.button("R$ " .. st.price, T.gold, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 120, 0, 38), TextSize = 16, Parent = f }, function()
				openConfirm({ kind = "bundle", id = st.id, name = st.name, icon = st.icon, price = st.price, desc = st.desc, once = true }, store)
			end)
		end
		-- v5: the yearly festival shelf and its set (value shown plainly; it returns every year)
		if store.festival then
			order += 1
			heading("🏮 " .. store.festival.name, order)
			order += 1
			note(store.festival.blurb .. " Festival items come back every year at the same time.", order)
			order += 1
			local fg = grid(order)
			for i, it in ipairs(store.festival.items) do
				itemCard(fg, it, i, store)
			end
			for _, b in ipairs(store.bundles) do
				if b.event and b.canBuy then
					order += 1
					local f = row(70, order)
					UI.label(b.icon .. " " .. b.name, { Size = UDim2.new(1, -150, 0, 24), TextSize = 17, TextColor3 = T.gold, Parent = f })
					UI.label(string.format("%d items · R$ %d on their own · R$ %d less as a set", b.count, b.missing, b.saving or 0), { Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, -150, 0, 32), TextSize = 13, Font = T.body, TextColor3 = T.dim, Parent = f })
					UI.button("R$ " .. b.price, T.gold, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 120, 0, 38), TextSize = 16, Parent = f }, function()
						openConfirm({ kind = "bundle", id = b.id, name = b.name, icon = b.icon, price = b.price, desc = b.desc, once = b.once }, store)
					end)
				end
			end
		end
		-- v4: next week's names, so players can plan (no countdowns, no "last chance")
		if store.upcoming and #store.upcoming > 0 then
			order += 1
			heading("Next week" .. (store.nextDropName and (": " .. store.nextDropName) or ""), order)
			order += 1
			local up = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 34), LayoutOrder = order, Parent = body })
			UI.list(up, Enum.FillDirection.Horizontal, 6)
			for _, u in ipairs(store.upcoming) do
				local chip = UI.label((u.new and "✨ " or "") .. u.icon .. " " .. u.name, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextSize = 13, Font = T.body, BackgroundTransparency = 0, BackgroundColor3 = T.card, Parent = up })
				UI.corner(chip, 8)
				UI.pad(chip, 6)
			end
		end
	elseif TAB_CATS[shopTab] then
		if shopTab == "arms" then
			note("Weapon skins change your bow and spear streaks, your hotbar and the kill feed. Same damage as every other skin.", order)
		elseif shopTab == "reach" then
			note("Fly your home " .. Names.REGION .. "'s colors: a banner under your name and on the podium, a parade sash and a nametag.", order)
		else
			note("Fades color your knockout light, poses play on the podium, emotes (B) work in the lobby and Gallery, wraps color your gift parachutes.", order)
		end
		for _, cat in ipairs(TAB_CATS[shopTab]) do
			order += 1
			local items = {}
			for _, it in ipairs(store.shelves[cat] or {}) do
				if shopTab ~= "reach" or it.name:find(s.reach ~= "" and s.reach or "", 1, true) or s.reach == "" then
					table.insert(items, it)
				end
			end
			for _, it in ipairs(store.featured) do
				if it.cat == cat then
					table.insert(items, it)
				end
			end
			if #items > 0 then
				heading(cat, order)
				order += 1
				local g = grid(order)
				for i, it in ipairs(items) do
					itemCard(g, it, i, store)
				end
			end
		end
	elseif shopTab == "bundles" then
		note("A bundle is only offered while the items you don't own yet are worth more than its price.", order)
		for _, b in ipairs(store.bundles) do
			local otherReach = b.id:sub(1, 6) == "pride_" and s.reach ~= "" and not b.name:find(s.reach, 1, true)
			if otherReach or (b.once and not b.canBuy) then
				continue
			end
			order += 1
			local f = row(70, order)
			UI.label(b.icon .. " " .. b.name, { Size = UDim2.new(1, -150, 0, 24), TextSize = 17, Parent = f })
			UI.label(string.format("%d items · R$ %d of them you don't own · R$ %d less as a set", b.count, b.missing, b.saving or 0), { Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, -150, 0, 32), TextSize = 13, Font = T.body, TextColor3 = T.dim, Parent = f })
			UI.button(b.canBuy and ("R$ " .. b.price) or (b.why or "Not now"), b.canBuy and T.gold or T.card, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 140, 0, 38), TextSize = 13, TextColor3 = b.canBuy and T.dark or T.text, Parent = f }, function()
				if b.canBuy then
					openConfirm({ kind = "bundle", id = b.id, name = b.name, icon = b.icon, price = b.price, desc = b.desc, once = b.once }, store)
				end
			end)
		end
	else
		heading("Passes", order)
		local keys = {}
		for key in pairs(shop.catalog.passes) do
			table.insert(keys, key)
		end
		table.sort(keys, function(a, b)
			return shop.catalog.passes[a].price < shop.catalog.passes[b].price
		end)
		for _, key in ipairs(keys) do
			local p = shop.catalog.passes[key]
			order += 1
			local f = row(70, order)
			UI.label(p.icon .. " " .. p.name, { Size = UDim2.new(1, -150, 0, 22), TextSize = 17, Parent = f })
			UI.label(p.desc, { Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, -150, 0, 32), TextSize = 13, Font = T.body, TextColor3 = T.dim, TextWrapped = true, Parent = f })
			local owned = s.passes[key]
			local avail = shop.passes[key]
			UI.button(owned and "Owned" or (avail and ("R$ " .. p.price) or "Not on sale yet"), owned and T.green or (avail and T.gold or T.card), { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 140, 0, 38), TextSize = 15, Parent = f }, function()
				if not owned and avail then
					Net.act("buy", "pass", key)
				end
			end)
		end
		order += 1
		heading("Season and boosts", order)
		for key, p in pairs(shop.catalog.products) do
			if p.category ~= "Shop" then
				order += 1
				local f = row(62, order)
				UI.label(p.icon .. " " .. p.name, { Size = UDim2.new(1, -150, 0, 22), TextSize = 17, Parent = f })
				UI.label(p.desc, { Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, -150, 0, 30), TextSize = 13, Font = T.body, TextColor3 = T.dim, TextWrapped = true, Parent = f })
				local avail = shop.products[key]
				UI.button(avail and ("R$ " .. p.price) or "Not on sale yet", avail and T.gold or T.card, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 140, 0, 38), TextSize = 15, Parent = f }, function()
					if avail then
						Net.act("buy", "product", key)
					end
				end)
			end
		end
		local sub = shop.subscription
		if sub then
			order += 1
			heading("Patron Club", order)
			order += 1
			local f = row(96, order)
			UI.label(sub.icon .. " " .. sub.name .. " · R$ " .. sub.price .. " a month", { Size = UDim2.new(1, -150, 0, 24), TextSize = 17, Parent = f })
			UI.label(table.concat(sub.perks, " · ") .. ". Cancel any time in Roblox settings.", { Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, -150, 0, 56), TextSize = 13, Font = T.body, TextColor3 = T.dim, TextWrapped = true, Parent = f })
			UI.button(sub.active and "Member" or (sub.available and "See Price" or "Not available"), sub.active and T.green or (sub.available and T.gold or T.card), { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 140, 0, 38), TextSize = 15, Parent = f }, function()
				if sub.available and not sub.active then
					Net.act("subscribe")
				end
			end)
		end
		order += 1
		local f = row(62, order)
		UI.label("🏰 Private servers · R$ " .. (shop.privateServerPrice or 99) .. " a month", { Size = UDim2.new(1, 0, 0, 22), TextSize = 16, Parent = f })
		UI.label("Play with friends. Spire VIP owners can pick the twist and turn on No Betrayals. Private matches don't count for Reach standings.", { Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 0, 32), TextSize = 13, Font = T.body, TextColor3 = T.dim, TextWrapped = true, Parent = f })
		if store.psOwner then
			order += 1
			local g = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 40), LayoutOrder = order, Parent = body })
			UI.list(g, Enum.FillDirection.Horizontal, 6)
			UI.button("No Betrayals", T.blue, { Size = UDim2.new(0, 150, 0, 36), TextSize = 14, TextColor3 = T.text, Parent = g }, function()
				Net.act("psRule", "noBetrayals", true)
			end)
			UI.button("Random twist", T.card, { Size = UDim2.new(0, 150, 0, 36), TextSize = 14, TextColor3 = T.text, Parent = g }, function()
				Net.act("psRule", "twist", "")
			end)
		end
		order += 1
		heading("Roblox Premium / Plus members", order)
		order += 1
		local mi = Shop.byId[shop.memberItem or ""]
		local mf = row(78, order)
		UI.label(string.format("Members get a free cosmetic every month%s, plus the member nametag. Free for members, never sold.", mi and (": this month " .. mi.icon .. " " .. mi.name) or ""), { Size = UDim2.new(1, -170, 1, 0), TextSize = 14, Font = T.body, TextWrapped = true, Parent = mf })
		if shop.member then
			UI.label("✔ Claimed", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 150, 0, 38), TextSize = 15, TextColor3 = T.green, TextXAlignment = Enum.TextXAlignment.Right, Parent = mf })
		elseif shop.plusAvailable then
			UI.button("➕ About Roblox Plus", T.card, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 160, 0, 38), TextSize = 13, TextColor3 = T.text, Parent = mf }, function()
				Net.act("plus")
			end)
		end
	end
	order += 100
	note(string.format("Robux spent here so far: R$ %d. Your purchase history is in Profile.", store.spent or 0), order)
	if shop.studio then
		note("Studio test mode: anything with ID 0 is free here so you can try it. Hidden in the live game until real IDs are set.", order + 1)
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
	if s.dailyTen then
		local d = s.dailyTen
		local f = row(40, 9)
		local mins = math.floor(math.min(d.seconds, d.goal) / 60)
		UI.label(d.claimed and "☀ Daily Ten done for today: +XP and ★ added." or string.format("☀ Daily Ten: %d of %d minutes played today (bonus XP and ★ at %d).", mins, math.floor(d.goal / 60), math.floor(d.goal / 60)), { Size = UDim2.new(1, -150, 1, 0), TextSize = 14, Font = T.body, Parent = f })
		UI.button("🔗 Invite a friend", T.blue, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 140, 0, 32), TextSize = 13, TextColor3 = T.text, Parent = f }, function()
			Panels.invite()
		end)
	end
	heading("Locker", 10)
	local LOCKER = {
		{ slot = "fade", label = "Knockout fade" },
		{ slot = "bow", label = "Bow skin" },
		{ slot = "spear", label = "Spear skin" },
		{ slot = "knife", label = "Knife skin" },
		{ slot = "pose", label = "Podium pose" },
		{ slot = "emote", label = "Emote (B)" },
		{ slot = "wrap", label = "Gift wrap" },
		{ slot = "nametag", label = "Nametag" },
		{ slot = "banner", label = "Banner" },
		{ slot = "parade", label = "Parade" },
		{ slot = "rusty", label = "Rusty pack" },
	}
	for i, L in ipairs(LOCKER) do
		local f = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 10 + i, Parent = body })
		UI.new("UIGridLayout", { CellSize = UDim2.new(0, 150, 0, 34), CellPadding = UDim2.new(0, 6, 0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = f })
		local eq = s.equipped[L.slot] or ""
		local lbl = L.label
		if (L.slot == "bow" or L.slot == "spear" or L.slot == "knife") and s.store then
			local pts = (s.store.mastery or {})[Mastery.key(L.slot, eq ~= "" and eq or nil)] or 0
			local stars = Mastery.stars(pts)
			if stars ~= "" then
				lbl = lbl .. " " .. stars
			end
		end
		UI.label(lbl, { LayoutOrder = 0, TextSize = 14, TextColor3 = T.dim, Parent = f })
		local opts: { { id: string, name: string } } = {}
		if L.slot == "fade" then
			for id, fd in pairs(Content.FADES) do
				if id == "fade_gold" or s.owned[id] then
					table.insert(opts, { id = tostring(id), name = fd.name })
				end
			end
		else
			table.insert(opts, { id = "", name = "Default" })
			for _, it in ipairs(Shop.ITEMS) do
				if it.slot == L.slot and s.owned[it.id] then
					table.insert(opts, { id = it.id, name = it.icon .. " " .. it.name })
				end
			end
			if L.slot == "nametag" and s.passes.VIP then
				table.insert(opts, { id = "tag_vip", name = "👑 VIP Gold" })
			end
			if L.slot == "parade" then
				for id in pairs(s.owned) do
					if string.sub(id, 1, 13) == "patron_cloak_" then
						table.insert(opts, { id = id, name = "📜 Patron Cloak " .. string.sub(id, 14) })
					end
				end
			end
		end
		for j, o in ipairs(opts) do
			UI.button(o.name, eq == o.id and T.gold or T.card, { LayoutOrder = j, TextSize = 13, TextColor3 = eq == o.id and T.dark or T.text, Parent = f }, function()
				Net.act("equip", L.slot, o.id)
			end)
		end
		-- v4: try on what's in the shop this week for this slot (free, only you see it)
		if s.store and s.store.featured then
			for k, it in ipairs(s.store.featured) do
				local fits = (it.slot == L.slot) or (L.slot == "fade" and it.slot == "fade")
				if fits and not it.owned and TryOn.canTry(it.id) then
					UI.button("👁 Try " .. it.name, T.panel, { LayoutOrder = 100 + k, TextSize = 12, TextColor3 = T.dim, Parent = f }, function()
						Panels.close()
						TryOn.show(it.id)
					end)
				end
			end
		end
	end
	local store = s.store
	if store and store.log and #store.log > 0 then
		heading(string.format("Purchase history · R$ %d spent", store.spent or 0), 70)
		for i, l in ipairs(store.log) do
			note(string.format("%s · %s · R$ %d%s", os.date("%b %d", l.t), l.name, l.price, l.gift and (" · gift to " .. l.gift) or ""), 70 + i)
		end
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
		{ key = "autoQueue", text = "Auto-queue the next match", invert = false },
		{ key = "shortReaping", text = "Short " .. Names.DRAW .. " cutscene", invert = true },
		{ key = "sfx", text = "Master sound", invert = false },
		{ key = "reduceMotion", text = "Reduce motion", invert = true },
	}
	for i, o in ipairs(opts) do
		local on = if o.invert then s.settings[o.key] == true else s.settings[o.key] ~= false
		local f = row(48, i)
		UI.label(o.text, { Size = UDim2.new(1, -110, 1, 0), TextSize = 17, Font = T.body, Parent = f })
		UI.button(on and "ON" or "OFF", on and T.green or T.card, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 90, 0, 34), TextColor3 = T.text, Parent = f }, function()
			Net.act("setting", o.key, not on)
		end)
	end
	local order = #opts
	-- v5: match type. Auto = Quick Trials for your first 2 matches, then the full Jubilee.
	local modes = { { id = "", text = "Auto" }, { id = "quick", text = "Quick" }, { id = "jubilee", text = "Full" } }
	order += 1
	local f = row(48, order)
	UI.label("Match type (Quick Trials ≈ 5 min)", { Size = UDim2.new(1, -300, 1, 0), TextSize = 17, Font = T.body, Parent = f })
	local box = UI.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 290, 0, 34), Parent = f })
	UI.list(box, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)
	local cur = s.settings.mode or ""
	for i, m in ipairs(modes) do
		UI.button(m.text, cur == m.id and T.gold or T.card, { LayoutOrder = i, Size = UDim2.new(0, 90, 0, 34), TextColor3 = cur == m.id and T.dark or T.text, Parent = box }, function()
			Net.act("setMode", m.id)
		end)
	end
	order += 1
	local view = s.settings.view == "first"
	local vf = row(48, order)
	UI.label("View in a match", { Size = UDim2.new(1, -300, 1, 0), TextSize = 17, Font = T.body, Parent = vf })
	local vbox = UI.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 280, 0, 34), Parent = vf })
	UI.list(vbox, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)
	UI.button("Third", not view and T.gold or T.card, { LayoutOrder = 1, Size = UDim2.new(0, 130, 0, 34), TextColor3 = not view and T.dark or T.text, Parent = vbox }, function()
		Net.act("setting", "viewFirst", false)
	end)
	UI.button("First", view and T.gold or T.card, { LayoutOrder = 2, Size = UDim2.new(0, 130, 0, 34), TextColor3 = view and T.dark or T.text, Parent = vbox }, function()
		Net.act("setting", "viewFirst", true)
	end)
	order += 1
	local fov = s.settings.fov or 70
	local ff = row(48, order)
	UI.label("Field of view (70 is the widest)", { Size = UDim2.new(1, -300, 1, 0), TextSize = 17, Font = T.body, Parent = ff })
	local fbox = UI.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 280, 0, 34), Parent = ff })
	UI.list(fbox, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)
	for i, n in ipairs({ 60, 65, 70 }) do
		UI.button(tostring(n), fov == n and T.gold or T.card, { LayoutOrder = i, Size = UDim2.new(0, 84, 0, 34), TextColor3 = fov == n and T.dark or T.text, Parent = fbox }, function()
			Net.act("setFov", n)
		end)
	end
	local volumes = s.settings.volumes or {}
	local muted = s.settings.muted or {}
	for _, rowDef in ipairs(Settings.VOLUME_ROWS) do
		order += 1
		local level = volumes[rowDef.bus] or 0
		local muteKey = nil
		for key, bus in pairs(Settings.MUTE_OF) do
			if bus == rowDef.bus then
				muteKey = key
			end
		end
		local isMuted = muteKey ~= nil and muted[rowDef.bus] == true
		local rf = row(48, order)
		UI.label(string.format("%s  %d", rowDef.label, level), { Size = UDim2.new(1, -250, 1, 0), TextSize = 16, Font = T.body, Parent = rf })
		local controls = UI.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 240, 0, 34), Parent = rf })
		UI.list(controls, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)
		UI.button("−", T.card, { LayoutOrder = 1, Size = UDim2.new(0, 44, 0, 34), TextColor3 = T.text, Parent = controls }, function()
			Net.act("setVolume", rowDef.bus, level - 10)
		end)
		UI.button("+", T.card, { LayoutOrder = 2, Size = UDim2.new(0, 44, 0, 34), TextColor3 = T.text, Parent = controls }, function()
			Net.act("setVolume", rowDef.bus, level + 10)
		end)
		if muteKey then
			UI.button(isMuted and "Muted" or "On", isMuted and T.card or T.green, { LayoutOrder = 3, Size = UDim2.new(0, 90, 0, 34), TextColor3 = T.text, Parent = controls }, function()
				Net.act("setting", muteKey, not isMuted)
			end)
		end
	end
	order += 1
	note("First person shows your hands and weapon during a match. Shots still come from your character, the same as third person. V, the View button, or a right-stick click switches it. Reduce motion turns off the small sway.", order)
	order += 1
	note("Weapon, hit, step, pickup and Veil sounds are quiet by default. Original recordings are ready to upload; until then you hear short sounds that ship with Roblox. Master sound off silences every bus.", order)
	-- v6: Rusty's checklist. Skipped (or timed out) players can bring it back and still earn the reward.
	local cl = s.checklist
	if cl then
		order += 1
		local r = row(48, order)
		local status = if cl.finished then ("Rusty's checklist: done. " .. cl.rewardName .. " unlocked")
			elseif cl.canReopen then ("Rusty's checklist (finish it for the " .. cl.rewardName .. " title)")
			else "Rusty's checklist: showing in the top-left"
		UI.label(status, { Name = "ChecklistStatus", Size = UDim2.new(1, -200, 1, 0), TextSize = 17, Font = T.body, TextWrapped = true, Parent = r })
		if cl.canReopen then
			UI.button("Reopen", T.green, { Name = "ReopenChecklist", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 150, 0, 34), Parent = r }, function()
				Net.act("onboardReopen")
			end)
		end
	end
end

local partyState: any = nil

local function partySection(start: number): number
	local ps = partyState or { members = {}, max = 10 }
	local n = start
	heading(string.format("👨‍👩‍👧 Party (%d/%d)", #ps.members, ps.max or 10), n)
	n += 1
	note("Parties of up to 10 always land in the same match. In a private server, Family Rules keeps your party allied until the final 4.", n)
	if ps.invite then
		n += 1
		local f = row(48, n)
		UI.label(ps.invite .. " invited you to their party", { Size = UDim2.new(1, -130, 1, 0), TextSize = 16, Parent = f })
		UI.button("Join", T.green, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 120, 0, 34), Parent = f }, function()
			Net.act("partyAccept")
		end)
	end
	local me = Players.LocalPlayer.UserId
	local inParty: { [number]: boolean } = {}
	local iLead = false
	for _, m in ipairs(ps.members) do
		inParty[m.userId] = true
		if m.userId == me and m.leader then
			iLead = true
		end
		n += 1
		local f = row(40, n)
		UI.label((m.leader and "👑 " or "• ") .. m.name .. (m.queued and "  · queued" or ""), { Size = UDim2.new(1, 0, 1, 0), TextSize = 16, Font = T.body, Parent = f })
	end
	if #ps.members > 0 then
		n += 1
		local f = row(48, n)
		UI.list(f, Enum.FillDirection.Horizontal, 8)
		if iLead then
			UI.button("Queue the party", T.gold, { Size = UDim2.new(0, 170, 0, 36), TextColor3 = T.dark, Parent = f }, function()
				Net.act("partyQueue", true)
			end)
		end
		UI.button("Leave party", T.red, { Size = UDim2.new(0, 140, 0, 36), Parent = f }, function()
			Net.act("partyLeave")
		end)
		if ps.family ~= nil and Net.state and Net.state.store and Net.state.store.psOwner then
			UI.button("Family Rules: " .. (ps.family and "ON" or "OFF"), ps.family and T.green or T.card, { Size = UDim2.new(0, 180, 0, 36), TextColor3 = T.text, Parent = f }, function()
				Net.act("psRule", "family", not ps.family)
			end)
		end
	end
	if #ps.members < (ps.max or 10) then
		for _, p in ipairs(Players:GetPlayers()) do
			if p.UserId ~= me and not inParty[p.UserId] then
				n += 1
				local f = row(44, n)
				UI.label(p.DisplayName, { Size = UDim2.new(1, -130, 1, 0), TextSize = 16, Font = T.body, Parent = f })
				UI.button("Add to party", T.blue, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 120, 0, 32), TextSize = 13, Parent = f }, function()
					Net.act("partyInvite", p.UserId)
				end)
			end
		end
	end
	return n + 1
end

builders.partner = function(_s: any)
	title.Text = "👥 Party & Partner"
	local base = partySection(100)
	heading("🤝 Partner (one person)", base)
	note("Queue with a partner: you'll share a " .. Names.REGION .. ", start side by side, and gifts to each other cost less. Invite someone; if they invite you back, you're partners.", base + 1)
	local l = Hud.lobby
	if l and l.partner then
		local f = row(48, base + 2)
		UI.label("Partnered with " .. l.partner, { Size = UDim2.new(1, -130, 1, 0), TextSize = 17, Parent = f })
		UI.button("Split up", T.red, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 120, 0, 34), Parent = f }, function()
			Net.act("unpartner")
		end)
	end
	local n = base + 2
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
	if n == base + 2 then
		note("Nobody else is here yet. Invite a friend to the experience!", base + 3)
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
	if id == "shop" and current ~= "shop" then
		task.spawn(Net.act, "shopStep", "shop_open")
	end
	current = id
	win.Visible = true
	body.CanvasPosition = Vector2.zero
	Panels.refresh()
end

-- Open the shop with one item's buy card (used by the post-match fade preview).
function Panels.openItem(id: string)
	Panels.open("shop")
	local store = Net.state and Net.state.store
	if not store then
		return
	end
	local found = nil
	for _, it in ipairs(store.featured or {}) do
		if it.id == id then
			found = it
		end
	end
	for _, list in pairs(store.shelves or {}) do
		for _, it in ipairs(list) do
			if it.id == id then
				found = it
			end
		end
	end
	if found and found.canBuy then
		openConfirm({ kind = "item", id = found.id, name = found.name, icon = found.icon, price = found.price, desc = found.desc }, store)
	elseif found then
		Hud.note(found.why or "Not in the shop right now.")
	end
end

-- Roblox invite prompt; the friend's join carries "ref:<you>" so you both get the Torchbearer Sash.
function Panels.invite()
	local ok = pcall(function()
		local opts = Instance.new("ExperienceInviteOptions")
		opts.PromptMessage = "Play a round of " .. Names.EVENT_SHORT .. " with me"
		opts.LaunchData = "ref:" .. tostring(Players.LocalPlayer.UserId)
		if SocialService:CanSendGameInviteAsync(Players.LocalPlayer) then
			SocialService:PromptGameInvite(Players.LocalPlayer, opts)
		end
	end)
	if not ok then
		Hud.note("Invites aren't available on this device.")
	end
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
	Net.on("party", function(d)
		partyState = d
		if current == "partner" then
			Panels.refresh()
		end
	end)
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

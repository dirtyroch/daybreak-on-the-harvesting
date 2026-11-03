--!strict
--[[
	PurchaseService — Game Passes and Developer Products.
	  * ProcessReceipt is idempotent: each PurchaseId is recorded in the player's save
	    (ReceiptLedger) and the save must succeed before we tell Roblox "PurchaseGranted".
	  * IDs live in ReplicatedStorage.Shared.Monetization. Items with id 0 are hidden in the
	    live game; in Studio they get a free "Studio test" grant so you can try everything.
	  * Nothing sold here is random. Robux never buys Favor, Stars or tiers.
	  * PolicyService: each player's store rules are read with GetPolicyInfoForPlayerAsync
	    (in pcall, with retries). The shop stays hidden until that loads (fail closed), and any
	    item marked random/tradable is withheld where the policy says so (Logic/Policy.luau).
	    The Patron Club subscription also needs IsEligibleToPurchaseSubscription.
	  * v3 Item Shop (Store.luau): one developer product per price point. The player's choice is
	    saved as an "intent" before the prompt; a receipt with no matching intent becomes a Shop
	    Voucher, so a purchase is never lost. Gifts go to a friend in the same server; if they
	    leave first, the buyer gets the voucher.
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PolicyService = game:GetService("PolicyService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Monetization = require(Shared.Monetization)
local ReceiptLedger = require(Shared.Logic.ReceiptLedger)
local Policy = require(Shared.Logic.Policy)
local Store = require(Shared.Store)
local Names = require(Shared.Names)
local Content = require(Shared.Content)
local Offers = require(Shared.Offers)
Store.addReachPride(Names.REACH_LIST)

local PurchaseService = {}
local ctx: any = nil
local RECEIPT_MEMORY = 50
local IS_STUDIO = RunService:IsStudio()

local productById: { [number]: string } = {}
local passById: { [number]: string } = {}
for key, p in pairs(Monetization.Products) do
	if p.id ~= 0 then
		productById[p.id] = key
	end
end
for key, p in pairs(Monetization.Passes) do
	if p.id ~= 0 then
		passById[p.id] = key
	end
end

local policies: { [Player]: Policy.Info } = {}

function PurchaseService.policyOf(player: Player): Policy.Info
	return policies[player] or Policy.unknown()
end

-- Read the player's store rules. Three tries, then stay closed (Studio falls back to open so
-- you can test the shop offline).
function PurchaseService.loadPolicy(player: Player)
	for attempt = 1, 3 do
		local ok, raw = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if ok and type(raw) == "table" then
			policies[player] = Policy.fromRaw(raw)
			return
		end
		task.wait(2 * attempt)
		if not player.Parent then
			return
		end
	end
	if IS_STUDIO then
		policies[player] = Policy.fromRaw({ ArePaidRandomItemsRestricted = true, IsPaidItemTradingAllowed = false })
	else
		policies[player] = Policy.unknown()
		warn("[PurchaseService] PolicyService unavailable for " .. player.Name .. "; shop stays hidden")
	end
end

function PurchaseService.availability(player: Player?): any
	local pol = if player then PurchaseService.policyOf(player) else Policy.unknown()
	local out = { products = {}, passes = {}, studio = IS_STUDIO, visible = Policy.shopVisible(pol), catalog = { passes = {}, products = {} } }
	for key, p in pairs(Monetization.Products) do
		out.products[key] = (p.id ~= 0 or IS_STUDIO) and Policy.canSell(pol, p :: any)
		out.catalog.products[key] = { name = p.name, price = p.price, desc = p.desc, icon = p.icon, category = p.category }
	end
	for key, p in pairs(Monetization.Passes) do
		out.passes[key] = (p.id ~= 0 or IS_STUDIO) and Policy.canSell(pol, p :: any)
		out.catalog.passes[key] = { name = p.name, price = p.price, desc = p.desc, icon = p.icon }
	end
	local sub = Monetization.Subscriptions.PatronClub
	out.subscription = {
		name = sub.name,
		price = sub.price,
		desc = sub.desc,
		icon = sub.icon,
		perks = sub.perks,
		available = (sub.id ~= "" or IS_STUDIO) and Policy.canSell(pol, { subscription = true }),
		active = player ~= nil and PurchaseService.isPatron(player),
	}
	out.privateServerPrice = Monetization.PRIVATE_SERVER_PRICE
	out.member = player ~= nil and PurchaseService.isMember(player)
	out.memberItem = Store.memberItemFor(tonumber(os.date("!%Y%m")) or 0)
	out.plusAvailable = Policy.shopVisible(pol)
	return out
end

function PurchaseService.isPatron(player: Player): boolean
	local r = ctx.Progress.runtime[player]
	return r ~= nil and r.sub == true
end

-- The Item Shop view for one player: this week's rotation, always-on shelves, bundles.
function PurchaseService.shopView(player: Player): any
	local data = ctx.Progress.dataOf(player)
	local wk = Store.week(os.time())
	local owned = data and data.owned or {}
	local flags = data and data.shopFlags or {}
	local function card(it: any): any
		local ok, why = Store.canReceive(assert(Store.offer("item", it.id)), owned, wk, flags)
		return { id = it.id, name = it.name, cat = it.cat, slot = it.slot, price = it.price, icon = it.icon, color = it.color, desc = it.desc, rot = it.rot, owned = owned[it.id] == true, canBuy = ok, why = why }
	end
	local featured = {}
	for _, it in ipairs(Store.rotation(wk)) do
		table.insert(featured, card(it))
	end
	local shelves = {}
	for _, it in ipairs(Store.ITEMS) do
		if not it.rot and not it.earned then
			shelves[it.cat] = shelves[it.cat] or {}
			table.insert(shelves[it.cat], card(it))
		end
	end
	local bundles = {}
	for _, b in ipairs(Store.BUNDLES) do
		local o = assert(Store.offer("bundle", b.id))
		local ok, why = Store.canReceive(o, owned, wk, flags)
		table.insert(bundles, { id = b.id, name = b.name, price = b.price, icon = b.icon, desc = b.desc, value = Store.value(b, nil), missing = Store.value(b, owned), canBuy = ok, why = why, once = b.once, count = #b.items })
	end
	local nextWeek = Store.weekStart(wk + 1)
	-- v4: what's coming next week (names only, so players can plan; no countdown copy)
	local upcoming = {}
	for _, it in ipairs(Store.rotation(wk + 1)) do
		table.insert(upcoming, { id = it.id, name = it.name, icon = it.icon, color = it.color, new = it.drop ~= nil and not Store.released(it, wk) })
	end
	local dropNow = Store.dropOf(wk)
	local dropNext = Store.dropOf(wk + 1)
	return {
		week = wk,
		upcoming = upcoming,
		dropName = dropNow and Store.DROP_NAMES[dropNow] or nil,
		nextDropName = dropNext and Store.DROP_NAMES[dropNext] or nil,
		mastery = data and data.mastery or {},
		changesOn = os.date("!%A %b %d", nextWeek),
		cycle = Store.cycleWeeks(),
		featured = featured,
		shelves = shelves,
		bundles = bundles,
		vouchers = data and data.vouchers or {},
		spent = data and data.spent or 0,
		log = data and data.buyLog or {},
		isNew = data ~= nil and data.shopSeenWeek ~= wk,
		isPrivate = game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0,
		psOwner = game.PrivateServerOwnerId == player.UserId and player.UserId ~= 0,
	}
end

function PurchaseService.loadPasses(player: Player): { [string]: boolean }
	local owned = {}
	for key, p in pairs(Monetization.Passes) do
		if p.id ~= 0 then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, p.id)
			end)
			if ok and has then
				owned[key] = true
			end
		end
	end
	local data = ctx.Progress.dataOf(player)
	if IS_STUDIO and data then
		for key in pairs(Monetization.Passes) do
			if data.owned["pass:" .. key] then
				owned[key] = true
			end
		end
	end
	return owned
end

local function grantProduct(player: Player, data: any, key: string): string
	local p = Monetization.Products[key]
	if p.kind == "boost" then
		ctx.Progress.addBoost(data, p.minutes or 30, Config.FairPlay.boostMult)
		-- Fair Play: everyone else in the server gets a free Renown Shower.
		for _, other in ipairs(Players:GetPlayers()) do
			local od = other ~= player and ctx.Progress.dataOf(other) or nil
			if od and od.boost.untilT <= os.time() then
				ctx.Progress.addBoost(od, Config.FairPlay.showerMinutes, Config.FairPlay.showerMult)
				ctx.toast(other, string.format("✨ Renown Shower from %s! +%d%% Renown for %d min.", player.DisplayName, math.floor(Config.FairPlay.showerMult * 100), Config.FairPlay.showerMinutes), "good")
			end
		end
	elseif p.kind == "skip" then
		ctx.Progress.skipTiers(player, p.tiers or 1)
	end
	ctx.Progress.markDirty(player)
	ctx.Progress.sendState(player)
	return "Thanks! " .. p.icon .. " " .. p.name .. " is yours."
end

local function grantPass(player: Player, key: string)
	local r = ctx.Progress.runtime[player]
	if not r then
		return
	end
	r.passes[key] = true
	ctx.toast(player, "Thanks! " .. Monetization.Passes[key].icon .. " " .. Monetization.Passes[key].name .. " is active.", "good")
	ctx.Progress.sendState(player)
end

local function prompt(player: Player, kind: any, key: any): (boolean, string?)
	local data = ctx.Progress.dataOf(player)
	if not data or type(kind) ~= "string" or type(key) ~= "string" then
		return false, nil
	end
	local pol = PurchaseService.policyOf(player)
	if not Policy.shopVisible(pol) then
		return false, "The shop is still loading."
	end
	if kind == "pass" then
		local p = Monetization.Passes[key]
		if not p then
			return false, "Not found."
		end
		if not Policy.canSell(pol, p :: any) then
			return false, "Not available in your region."
		end
		if ctx.Progress.hasPass(player, key) then
			return false, "You already have this."
		end
		if p.id == 0 then
			if IS_STUDIO then
				data.owned["pass:" .. key] = true
				grantPass(player, key)
				return true, "Studio test: pass granted for free (only in Studio)."
			end
			return false, "Not on sale yet."
		end
		MarketplaceService:PromptGamePassPurchase(player, p.id)
		return true, nil
	end
	local p = Monetization.Products[key]
	if not p then
		return false, "Not found."
	end
	if not Policy.canSell(pol, p :: any) then
		return false, "Not available in your region."
	end
	if p.kind == "shop" then
		return false, "Pick an item in the shop."
	end
	if p.id == 0 then
		if IS_STUDIO then
			return true, "Studio test (free): " .. grantProduct(player, data, key)
		end
		return false, "Not on sale yet."
	end
	MarketplaceService:PromptProductPurchase(player, p.id)
	return true, nil
end

local function logBuy(data: any, name: string, price: number, gift: string?)
	data.spent = (data.spent or 0) + price
	data.buyLog = data.buyLog or {}
	table.insert(data.buyLog, 1, { t = os.time(), name = name, price = price, gift = gift })
	while #data.buyLog > 20 do
		table.remove(data.buyLog)
	end
end

local function friendInServer(player: Player, userId: any): Player?
	if type(userId) ~= "number" or userId == player.UserId then
		return nil
	end
	local other = Players:GetPlayerByUserId(userId)
	if not other then
		return nil
	end
	local ok, friends = pcall(function()
		return player:IsFriendsWithAsync(userId)
	end)
	if ok and friends then
		return other
	end
	return nil
end

-- Grant an offer to `to` (or the buyer). Returns the toast text.
local function deliver(buyer: Player, buyerData: any, o: Store.Offer, toId: number?): string
	if toId then
		local other = Players:GetPlayerByUserId(toId)
		local od = other and ctx.Progress.dataOf(other)
		if other and od and Store.canReceive(o, od.owned, Store.week(os.time()), od.shopFlags) then
			Store.grant(o, od.owned, od.shopFlags)
			ctx.Progress.markDirty(other)
			ctx.Progress.sendState(other)
			ctx.toast(other, string.format("🎁 %s sent you %s %s!", buyer.DisplayName, o.icon, o.name), "good")
			logBuy(buyerData, o.name, o.price, other.DisplayName)
			return string.format("Gift sent! %s now has %s.", other.DisplayName, o.name)
		end
		Store.addVoucher(buyerData.vouchers, o.price)
		logBuy(buyerData, "Shop Voucher (gift couldn't be delivered)", o.price, nil)
		return string.format("Your friend left before the gift arrived, so you got a R$ %d Shop Voucher to use on anything at that price or lower.", o.price)
	end
	Store.grant(o, buyerData.owned, buyerData.shopFlags)
	logBuy(buyerData, o.name, o.price, nil)
	return "Thanks! " .. o.icon .. " " .. o.name .. " is yours. Equip it in the Locker."
end

-- Player picked an item or bundle in the shop. Shows the Roblox prompt for that price point.
local function shopBuy(player: Player, kind: any, id: any, opts: any): (boolean, string?)
	local toId = type(opts) == "table" and opts.to or nil
	local useVoucher = type(opts) == "table" and opts.voucher == true
	local data = ctx.Progress.dataOf(player)
	if not data or type(kind) ~= "string" or type(id) ~= "string" then
		return false, nil
	end
	local pol = PurchaseService.policyOf(player)
	if not Policy.shopVisible(pol) then
		return false, "The shop is still loading."
	end
	local o = Store.offer(kind, id)
	if not o then
		return false, "Not found."
	end
	local wk = Store.week(os.time())
	local target: Player? = nil
	if toId ~= nil then
		target = friendInServer(player, toId)
		if not target then
			return false, "Gifts go to a friend who is in this server."
		end
		if o.once then
			return false, "The Starter Pack can't be gifted."
		end
		local td = ctx.Progress.dataOf(target :: Player)
		if not td then
			return false, "Your friend is still loading."
		end
		local ok, why = Store.canReceive(o, td.owned, wk, td.shopFlags)
		if not ok then
			return false, (target :: Player).DisplayName .. ": " .. tostring(why)
		end
	else
		local ok, why = Store.canReceive(o, data.owned, wk, data.shopFlags)
		if not ok then
			return false, why
		end
	end
	local toUser = target and (target :: Player).UserId or nil
	if useVoucher then
		if not Store.useVoucher(data.vouchers, o.price) then
			return false, "No voucher covers this price."
		end
		local msg = deliver(player, data, o, toUser)
		data.spent -= o.price -- vouchers were already counted when paid
		ctx.Progress.markDirty(player)
		ctx.Progress.sendState(player)
		return true, msg
	end
	local key = Store.tierKey(o.price)
	local product = key and Monetization.Products[key]
	if not product then
		return false, "Not on sale."
	end
	if product.id == 0 then
		if IS_STUDIO then
			local msg = deliver(player, data, o, toUser)
			ctx.Progress.markDirty(player)
			ctx.Progress.sendState(player)
			return true, "Studio test (free): " .. msg
		end
		return false, "Not on sale yet."
	end
	data.intent = { kind = o.kind, id = o.id, price = o.price, to = toUser, t = os.time() }
	ctx.Progress.markDirty(player)
	MarketplaceService:PromptProductPurchase(player, product.id)
	return true, nil
end

local function grantShopReceipt(player: Player, data: any, key: string): string
	local p = Monetization.Products[key]
	local intent = Store.matchIntent(data.intent, p.price, os.time())
	data.intent = nil
	local o = intent and Store.offer(intent.kind, intent.id)
	if not o then
		Store.addVoucher(data.vouchers, p.price)
		logBuy(data, "Shop Voucher", p.price, nil)
		return string.format("You have a R$ %d Shop Voucher. Use it on any item at that price or lower.", p.price)
	end
	return deliver(player, data, o, intent and intent.to)
end

local function subscribe(player: Player): (boolean, string?)
	local sub = Monetization.Subscriptions.PatronClub
	if not Policy.canSell(PurchaseService.policyOf(player), { subscription = true }) then
		return false, "Subscriptions aren't available on this account."
	end
	if PurchaseService.isPatron(player) then
		return false, "You're already in the Patron Club."
	end
	if sub.id == "" then
		if IS_STUDIO then
			local r = ctx.Progress.runtime[player]
			if r then
				r.sub = true
			end
			PurchaseService.patronPerks(player)
			return true, "Studio test: Patron Club active for this session."
		end
		return false, "Not on sale yet."
	end
	local ok = pcall(function()
		(MarketplaceService :: any):PromptSubscriptionPurchase(player, sub.id)
	end)
	return ok, nil
end

-- Monthly perks for Patron Club members, granted once per calendar month (UTC).
function PurchaseService.patronPerks(player: Player)
	local data = ctx.Progress.dataOf(player)
	if not data or not PurchaseService.isPatron(player) then
		return
	end
	local month = tonumber(os.date("!%Y%m")) or 0
	if data.patronMonth == month then
		return
	end
	data.patronMonth = month
	data.owned["patron_seal"] = true
	data.owned["patron_cloak_" .. month] = true
	data.owned["emote_patron"] = true
	ctx.Progress.skipTiers(player, Config.FairPlay.patronSkips)
	ctx.toast(player, "📜 Patron Club: this month's cloak and 2 Tier Skips are in your Locker. Thank you!", "good")
end

function PurchaseService.checkSubscription(player: Player)
	local sub = Monetization.Subscriptions.PatronClub
	if sub.id == "" then
		return
	end
	local ok, status = pcall(function()
		return (MarketplaceService :: any):GetUserSubscriptionStatusAsync(player, sub.id)
	end)
	local r = ctx.Progress.runtime[player]
	if r then
		r.sub = ok and type(status) == "table" and status.IsSubscribed == true
	end
	PurchaseService.patronPerks(player)
end

-- ===== v4: member perk, fade preview =====
-- Roblox Plus subscribers (and legacy Premium members) get one fixed free cosmetic a month.
-- Roblox no longer runs Premium Payouts; Plus pays creators per signup and per subscriber
-- engagement instead (see PUBLISHING.md 6h), so this is the thank-you that brings them back.
function PurchaseService.isMember(player: Player): boolean
	local ok, sub = pcall(function()
		return (player :: any).HasRobloxSubscription
	end)
	if ok and sub == true then
		return true
	end
	return player.MembershipType == Enum.MembershipType.Premium
end

function PurchaseService.memberPerk(player: Player)
	local data = ctx.Progress.dataOf(player)
	if not data or not PurchaseService.isMember(player) then
		return
	end
	local month = tonumber(os.date("!%Y%m")) or 0
	if data.memberMonth == month then
		return
	end
	data.memberMonth = month
	local id = Store.memberItemFor(month)
	local it = Store.byId[id]
	data.owned[id] = true
	ctx.Progress.markDirty(player)
	ctx.toast(player, "➕ Thanks for being a Roblox member: " .. (it and it.name or id) .. " is in your Locker.", "good")
end

-- After a match with a knockout: one calm "see your knockout with this fade" card, at most
-- Offers.MAX_PER_SESSION times a session, never for accounts whose policy hides the shop.
local previewsShown: { [Player]: number } = {}
function PurchaseService.previewFor(player: Player, knocks: number): any?
	if not Policy.shopVisible(PurchaseService.policyOf(player)) then
		return nil
	end
	if (previewsShown[player] or 0) >= Offers.MAX_PER_SESSION then
		return nil
	end
	local data = ctx.Progress.dataOf(player)
	if not data then
		return nil
	end
	local card = Offers.fadePreview(data.owned, Store.week(os.time()), knocks)
	if card then
		previewsShown[player] = (previewsShown[player] or 0) + 1
		local f = Content.FADES[card.itemId or ""]
		card.style = f and f.style or "column"
		card.color = f and f.color or "#FFD36B"
	end
	return card
end

-- Roblox Plus: calm card in the shop; Roblox pays the game for each new member it brings in.
local function plus(player: Player): (boolean, string?)
	local ok = pcall(function()
		(MarketplaceService :: any):PromptRobloxSubscriptionPurchase(player)
	end)
	if not ok then
		return false, "Roblox Plus isn't available here."
	end
	return true, nil
end

local function seenShop(player: Player): (boolean, string?)
	local data = ctx.Progress.dataOf(player)
	if data then
		data.shopSeenWeek = Store.week(os.time())
		ctx.Progress.markDirty(player)
	end
	return true, nil
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = ctx.Data.waitFor(player, 10)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = profile.data
	local purchaseId = tostring(info.PurchaseId)
	if ReceiptLedger.has(data.receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key = productById[info.ProductId]
	if not key then
		warn("[PurchaseService] unknown product id " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local grantFn = Monetization.Products[key].kind == "shop" and grantShopReceipt or grantProduct
	local ok, msg = pcall(grantFn, player, data, key)
	if not ok then
		warn("[PurchaseService] grant failed: " .. tostring(msg))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	ReceiptLedger.add(data.receipts, purchaseId, RECEIPT_MEMORY)
	if not ctx.Data.save(profile, false) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	ctx.toast(player, msg, "good")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function PurchaseService.init(c: any)
	ctx = c
	ctx.handle("buy", prompt)
	ctx.handle("shopBuy", shopBuy)
	ctx.handle("subscribe", subscribe)
	ctx.handle("plus", plus)
	ctx.handle("seenShop", seenShop)
end

function PurchaseService.start()
	local function onJoin(player: Player)
		PurchaseService.loadPolicy(player)
		if player.Parent then
			ctx.Progress.sendState(player)
		end
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onJoin, player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		policies[player] = nil
		previewsShown[player] = nil
	end)
	MarketplaceService.ProcessReceipt = processReceipt
	pcall(function()
		(MarketplaceService :: any).UserSubscriptionStatusChanged:Connect(function(player: Player, subId: string)
			if subId == Monetization.Subscriptions.PatronClub.id then
				PurchaseService.checkSubscription(player)
				ctx.Progress.sendState(player)
			end
		end)
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		local key = passById[passId]
		if purchased and key then
			grantPass(player, key)
		end
	end)
end

return PurchaseService

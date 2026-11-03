--!strict
--[[
	PurchaseService — Game Passes and Developer Products.
	  * ProcessReceipt is idempotent: each PurchaseId is recorded in the player's save
	    (ReceiptLedger) and the save must succeed before we tell Roblox "PurchaseGranted".
	  * IDs live in ReplicatedStorage.Shared.Monetization. Items with id 0 are hidden in the
	    live game; in Studio they get a free "Studio test" grant so you can try everything.
	  * Nothing sold here is random. Robux never buys Favor, Stars or tiers.
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Monetization = require(Shared.Monetization)
local ReceiptLedger = require(Shared.Logic.ReceiptLedger)

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

function PurchaseService.availability(): any
	local out = { products = {}, passes = {}, studio = IS_STUDIO, catalog = { passes = {}, products = {} } }
	for key, p in pairs(Monetization.Products) do
		out.products[key] = p.id ~= 0 or IS_STUDIO
		out.catalog.products[key] = { name = p.name, price = p.price, desc = p.desc, icon = p.icon, category = p.category }
	end
	for key, p in pairs(Monetization.Passes) do
		out.passes[key] = p.id ~= 0 or IS_STUDIO
		out.catalog.passes[key] = { name = p.name, price = p.price, desc = p.desc, icon = p.icon }
	end
	return out
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
	else
		for _, id in ipairs(p.grants or {}) do
			data.owned[id] = true
		end
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
	if kind == "pass" then
		local p = Monetization.Passes[key]
		if not p then
			return false, "Not found."
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
	if p.kind == "cosmetic" and p.grants then
		local all = true
		for _, id in ipairs(p.grants) do
			if not data.owned[id] then
				all = false
			end
		end
		if all then
			return false, "You already own this."
		end
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
	local ok, msg = pcall(grantProduct, player, data, key)
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
end

function PurchaseService.start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		local key = passById[passId]
		if purchased and key then
			grantPass(player, key)
		end
	end)
end

return PurchaseService

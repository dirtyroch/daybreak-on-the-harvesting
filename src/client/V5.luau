--!strict
--[[
	v5 client pieces:
	  * First-match checklist: one step at a time from Rusty, top-left, hidden once done.
	  * "Share this moment": after a win, top 3, Veil Breaker, Encore or five knockouts, one card
	    offers Roblox's own share sheet with a screenshot (only when PolicyService allows content
	    sharing). Friends who open it join with "ref:<you>;m:<moment>", which counts as an invite.
	  * Party results card after every match a party played together.
	  * Welcome-back card, Quick Trials / Archive Reel / festival notes and the festival banner.
]]
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local CaptureService = game:GetService("CaptureService")
local Lighting = game:GetService("Lighting")

local UI = require(script.Parent.UI)
local Net = require(script.Parent.Net)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local Hud = require(script.Parent.Hud)
local Rusty = require(script.Parent.Rusty)
local OfferCard = require(script.Parent.OfferCard)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Onboarding = require(Shared.Logic.Onboarding)
local T = UI.Theme

local V5 = {}
local checklist: Frame = nil :: any
local stepTitle: TextLabel = nil :: any
local stepTip: TextLabel = nil :: any
local stepCount: TextLabel = nil :: any
local stepReward: TextLabel = nil :: any
local skipAsk: Frame = nil :: any
local skipAskText: TextLabel = nil :: any
local banner: TextLabel = nil :: any
local partyCard: Frame = nil :: any
local shareAllowed: boolean? = nil

local function canShare(): boolean
	if shareAllowed == nil then
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(Players.LocalPlayer)
		end)
		shareAllowed = ok and type(info) == "table" and (info :: any).IsContentSharingAllowed == true
	end
	return shareAllowed == true
end

-- Take a screenshot and offer the Roblox share sheet. Returns quietly if anything is unavailable.
function V5.share(m: any)
	if not canShare() then
		Fx.toast("Sharing isn't available on this account.", "info")
		return
	end
	local cs = CaptureService :: any
	local ok = pcall(function()
		cs:TakeScreenshotCaptureAsync(function(capture: any)
			pcall(function()
				cs:PromptShareCapture(Content.fromObject(capture), m.launch, function()
					Net.act("shared", m.id)
				end, function() end)
			end)
		end)
	end)
	if not ok then
		Fx.toast("Couldn't take the picture this time.", "info")
	end
end

local function showMoment(m: any)
	if not m then
		return
	end
	task.delay(1.2, function()
		if not canShare() then
			return
		end
		OfferCard.show({
			kind = "moment",
			title = "📸 " .. m.title,
			body = m.caption .. " Share a picture? Friends who join from it get the Torchbearer Sash with you.",
			tryLabel = "Share",
			noLabel = "Not now",
			color = "#FFD36B",
		}, {
			try = function()
				V5.share(m)
			end,
		}, 20)
	end)
end

local function refreshChecklist()
	local s = Net.state
	local ob = s and s.onboarding
	checklist.Visible = ob ~= nil and (Hud.mode == "lobby" or Hud.mode == "arena")
	if ob then
		stepTitle.Text = "Rusty's tip: " .. ob.title
		stepTip.Text = ob.tip
		stepCount.Text = string.format("%d / %d", ob.done, ob.total)
		stepReward.Text = "🎁 " .. (ob.reward or "")
		skipAskText.Text = ob.skipAsk or ""
	else
		skipAsk.Visible = false
	end
	local f = s and s.festival
	banner.Visible = f ~= nil and Hud.mode == "lobby"
	if f then
		local got = 0
		for _, r in ipairs(f.rewards) do
			if r.got then
				got += 1
			end
		end
		banner.Text = string.format("🏮 %s · free festival rewards %d/%d · matches %d", f.name, got, #f.rewards, f.matches)
	end
end

local function showPartyCard(d: any)
	UI.clear(partyCard)
	UI.list(partyCard, nil, 4)
	UI.label("👨‍👩‍👧 Party results", { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 26), TextSize = 20, TextColor3 = T.gold, Parent = partyCard })
	for i, l in ipairs(d.lines) do
		local place = l.place < 99 and ("#" .. l.place) or "-"
		UI.label(string.format("%s  %s  ·  %d knockout%s", place, l.name, l.knocks, l.knocks == 1 and "" or "s"), { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 20), TextSize = 15, Font = T.body, Parent = partyCard })
	end
	UI.label(string.format("Best finish: %s · party knockouts: %d", d.best, d.knocks), { LayoutOrder = 50, Size = UDim2.new(1, 0, 0, 20), TextSize = 14, Font = T.body, TextColor3 = T.dim, Parent = partyCard })
	partyCard.Visible = true
	task.delay(12, function()
		partyCard.Visible = false
	end)
end

function V5.mount(parent: Frame)
	checklist = UI.frame({ Name = "FirstSteps", Position = UDim2.new(0, 16, 0, 120), Size = UDim2.new(0, 320, 0, 128), BackgroundColor3 = T.panel, BackgroundTransparency = 0.1, Visible = false, ZIndex = 4, Parent = parent })
	UI.corner(checklist, 12)
	UI.stroke(checklist, T.gold, 1)
	UI.pad(checklist, 8)
	stepTitle = UI.label("", { Size = UDim2.new(1, -50, 0, 22), TextSize = 16, TextColor3 = T.gold, ZIndex = 5, Parent = checklist })
	stepCount = UI.label("", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 48, 0, 22), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5, Parent = checklist })
	stepTip = UI.label("", { Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, 0, 0, 34), TextSize = 13, Font = T.body, TextWrapped = true, TextColor3 = T.text, ZIndex = 5, Parent = checklist })
	-- v6: the finish reward, stated plainly, and a clear Skip button with a calm confirm.
	stepReward = UI.label("", { Name = "Reward", Position = UDim2.new(0, 0, 0, 60), Size = UDim2.new(1, -70, 0, 50), TextSize = 13, Font = T.body, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = T.gold, ZIndex = 5, Parent = checklist })
	UI.button("Skip", T.card, { Name = "Skip", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.new(0, 62, 0, 28), TextSize = 14, ZIndex = 5, Parent = checklist }, function()
		skipAsk.Visible = true
	end)
	skipAsk = UI.frame({ Name = "SkipConfirm", Position = UDim2.new(0, 0, 1, 8), Size = UDim2.new(1, 0, 0, 118), BackgroundColor3 = T.panel, Visible = false, ZIndex = 8, Parent = checklist })
	UI.corner(skipAsk, 10)
	UI.stroke(skipAsk, T.gold, 1)
	UI.pad(skipAsk, 8)
	skipAskText = UI.label("", { Size = UDim2.new(1, 0, 0, 66), TextSize = 13, Font = T.body, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 9, Parent = skipAsk })
	UI.button(Onboarding.COPY.skipNo, T.green, { Name = "KeepGoing", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(0.5, -4, 0, 30), TextSize = 14, ZIndex = 9, Parent = skipAsk }, function()
		skipAsk.Visible = false
	end)
	UI.button(Onboarding.COPY.skipYes, T.card, { Name = "ConfirmSkip", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.new(0.5, -4, 0, 30), TextSize = 14, ZIndex = 9, Parent = skipAsk }, function()
		skipAsk.Visible = false
		Net.act("onboardSkip")
	end)
	banner = UI.label("", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.new(0, 520, 0, 30), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0.2, BackgroundColor3 = Color3.fromHex("#5A2E12"), TextColor3 = Color3.fromHex("#FFD9A0"), Visible = false, ZIndex = 4, Parent = parent })
	UI.corner(banner, 10)
	partyCard = UI.frame({ Name = "PartyCard", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -150), Size = UDim2.new(0, 320, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.panel, Visible = false, ZIndex = 9, Parent = parent })
	UI.corner(partyCard, 12)
	UI.stroke(partyCard, T.gold, 2)
	UI.pad(partyCard, 10)

	Net.changed.Event:Connect(refreshChecklist)
	Net.on("onboard", function(d)
		Sfx.play("coins")
		Fx.toast(string.format("✅ %s  +%d", d.done, d.xp), "good")
		if d.finished and d.line then
			Fx.toast("“" .. d.line .. "”", "good")
			if d.reward then
				Fx.toast("🏅 Title unlocked: " .. d.reward .. " (equip it in the Locker)", "good")
			end
		elseif d.nextTitle then
			Fx.toast("Next: " .. d.nextTitle, "info")
		end
	end)
	Net.on("welcomeBack", function(d)
		Sfx.play("ding")
		Fx.announce("Welcome back!", T.gold, 2.6)
		local bits = { string.format("+%d Favor banked", d.favor), string.format("+50%% Renown for %d matches", d.matches) }
		if d.catchUpTier and d.catchUpTier > 0 then
			table.insert(bits, string.format("double stars up to tier %d", d.catchUpTier))
		end
		OfferCard.show({ kind = "welcome", title = "🏡 " .. d.days .. " days away. Rusty kept your seat.", body = "“" .. d.line .. "” " .. table.concat(bits, " · ") .. (d.festival and (" · " .. d.festival .. " is on!") or ""), noLabel = "Thanks" }, {}, 20)
	end)
	Net.on("pregame", function(d)
		if d.quick then
			Fx.toast("⚡ Quick Trials: straight to the plates, about 5 minutes.", "info")
		end
		if d.archive then
			Fx.announce("🎞️ Archive Reel", Color3.fromHex("#C9A97A"), 3)
			Rusty.say("archive", "info")
		elseif (d.party or 0) >= 2 then
			Rusty.say("party", "info")
		end
	end)
	Net.on("eliminated", function(d)
		showMoment(d.moment)
	end)
	Net.on("finished", function(d)
		showMoment(d.moment)
	end)
	Net.on("partyCard", showPartyCard)
	-- letters opened (this push had no listener before v5; the toast came only from the reply)
	Net.on("letters", function(d)
		Sfx.play("coins")
		local n = type(d.letters) == "number" and d.letters or (type(d.letters) == "table" and #d.letters or 0)
		Fx.announce(string.format("✉️ %d letter%s opened", n, n == 1 and "" or "s"), T.gold, 2.2)
	end)
	Net.on("matchStart", function()
		partyCard.Visible = false
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			pcall(refreshChecklist)
		end
	end)
	local _ = Lighting
end

return V5

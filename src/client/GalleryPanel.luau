--!strict
-- The Viewing Gallery panel: Favor, gift any contender, vote on hazards and on the Encore.
local Players = game:GetService("Players")

local UI = require(script.Parent.UI)
local Net = require(script.Parent.Net)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local Hud = require(script.Parent.Hud)
local T = UI.Theme
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Names = require(ReplicatedStorage:WaitForChild("Shared").Names)

local GalleryPanel = {}
local win: Frame = nil :: any
local favor: TextLabel = nil :: any
local list: ScrollingFrame = nil :: any
local gifts: Frame = nil :: any
local voteBox: Frame = nil :: any
local selected: string? = nil
local view: any = nil
local lastBuild = 0

local function rebuild()
	if not view then
		return
	end
	favor.Text = string.format("🪙 %d %s  ·  earn +1 every 5 s while you watch", view.favor, Names.FAVOR)
	UI.clear(list)
	for i, c in ipairs(view.alive) do
		local b = UI.button(string.format("%s%s  (%s)  Pep %d%s", c.partner and "👥 " or "", c.name, c.reach, math.floor(c.pep), c.underdog and "  · underdog −20%" or ""), selected == c.id and T.gold or T.card, { LayoutOrder = i, Size = UDim2.new(1, -8, 0, 34), TextSize = 14, TextColor3 = selected == c.id and T.dark or T.text, TextXAlignment = Enum.TextXAlignment.Left, Parent = list }, function()
			selected = c.id
			rebuild()
		end)
		UI.pad(b, 8)
		-- v4: show each contender's look (weapon skin + mastery stars, fade) on the right
		local look = c.look
		if look and (look.weapon or look.fade) then
			local txt = (look.weapon or "") .. ((look.stars and look.stars ~= "") and (" " .. look.stars) or "") .. (look.fade and ("  ✦ " .. look.fade) or "")
			UI.label(txt, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.45, 0, 1, 0), TextSize = 12, Font = T.body, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = look.weaponColor and Color3.fromHex(look.weaponColor) or T.dim, Parent = b })
		end
	end
	UI.clear(gifts)
	for i, g in ipairs(view.gifts) do
		local target = nil
		for _, c in ipairs(view.alive) do
			if c.id == selected then
				target = c
			end
		end
		local cost = target and target.partner and g.partnerCost or g.cost
		if target and target.underdog and not target.partner then
			cost = g.underdogCost
		end
		UI.button(string.format("🪂 %s · %d", g.name, cost), (target and view.favor >= cost) and T.blue or T.card, { LayoutOrder = i, Size = UDim2.new(0, 150, 0, 40), TextSize = 14, TextColor3 = T.text, Parent = gifts }, function()
			if not selected then
				Fx.toast("Pick a contender first.", "info")
				return
			end
			if Net.act("gift", selected, g.id) then
				Sfx.play("whoosh")
			end
		end)
	end
	UI.clear(voteBox)
	local function ballot(kind: string, b: any, labels: { [string]: string })
		local secs = math.max(0, math.ceil(b.ends - workspace:GetServerTimeNow()))
		UI.label((kind == "encore" and "Encore vote: bring one back!" or "Hazard vote") .. string.format(" · %ds", secs), { Size = UDim2.new(1, 0, 0, 22), TextSize = 17, TextColor3 = T.gold, LayoutOrder = 0, Parent = voteBox })
		for i, opt in ipairs(b.options) do
			local id = type(opt) == "table" and opt.id or opt
			local label = labels[id] or (type(opt) == "table" and opt.name) or id
			local n = b.counts[id] or 0
			UI.button(string.format("%s%s  (%d)", b.mine == id and "✔ " or "", label, n), b.mine == id and T.gold or T.card, { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 34), TextSize = 14, TextColor3 = b.mine == id and T.dark or T.text, Parent = voteBox }, function()
				Net.act("vote", kind, id)
			end)
		end
	end
	if view.encore then
		ballot("encore", view.encore, {})
	elseif view.hazard then
		local labels = {}
		for _, card in ipairs(view.hazardCards) do
			labels[card.id] = card.name .. ": " .. card.text
		end
		ballot("hazard", view.hazard, labels)
	else
		UI.label("Next vote soon. Votes pick hazards and bring one contender back.", { Size = UDim2.new(1, 0, 0, 40), TextSize = 14, Font = T.body, TextColor3 = T.dim, Parent = voteBox })
	end
end

function GalleryPanel.mount(parent: Frame)
	win = UI.frame({ Name = "Gallery", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 20), Size = UDim2.new(0, 360, 0, 560), Visible = false, BackgroundTransparency = 0.05, Parent = parent })
	UI.corner(win, 14)
	UI.stroke(win, T.blue, 2)
	UI.pad(win, 10)
	UI.label("🎟️ " .. Names.GALLERY, { Size = UDim2.new(1, 0, 0, 28), TextSize = 22, TextColor3 = T.gold, Parent = win })
	favor = UI.label("", { Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, 0, 0, 20), TextSize = 14, Font = T.body, TextColor3 = T.dim, Parent = win })
	list = UI.new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0, 0, 0, 52), Size = UDim2.new(1, 0, 0, 180), AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 5, Parent = win })
	UI.list(list, nil, 4)
	gifts = UI.frame({ BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 238), Size = UDim2.new(1, 0, 0, 134), Parent = win })
	UI.new("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 40), CellPadding = UDim2.new(0, 6, 0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = gifts })
	voteBox = UI.frame({ BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 378), Size = UDim2.new(1, 0, 0, 130), Parent = win })
	UI.list(voteBox, nil, 4)
	UI.button("Back to the lobby", T.card, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 0, 0, 36), TextColor3 = T.text, Parent = win }, function()
		Net.act("leaveGallery")
	end)
	Net.on("gallery", function(v)
		view = v
		win.Visible = true
		Hud.mode = "gallery"
		local now = os.clock()
		if now - lastBuild > 0.4 then
			lastBuild = now
			rebuild()
		end
	end)
	Net.on("galleryClose", function()
		win.Visible = false
		view = nil
		Hud.mode = "lobby"
	end)
	Net.on("vote", function(d)
		Sfx.play("ding")
		Fx.toast(d.kind == "encore" and "Encore vote is open in " .. Names.GALLERY .. "!" or "Hazard vote is open in " .. Names.GALLERY .. "!", "info")
	end)
	Net.on("giftFeed", function(d)
		if win.Visible then
			Fx.toast(string.format("🪂 %s sent %s to %s", d.from, d.item, d.to), "info")
		end
	end)
	local _ = Players
end

return GalleryPanel

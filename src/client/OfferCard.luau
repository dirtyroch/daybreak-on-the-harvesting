--!strict
--[[
	OfferCard: one small, calm card in the lower right (never a full-screen popup, never a timer).
	Used for the post-match fade preview, the first-win gift and the Gallery partner moment.
	"No thanks" on a shop-linked card hides that kind for the rest of the session.
]]
local UI = require(script.Parent.UI)
local T = UI.Theme

local OfferCard = {}
local holder: Frame = nil :: any
local dismissed: { [string]: boolean } = {}

function OfferCard.mount(parent: Frame)
	holder = UI.frame({ Name = "OfferCard", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -150), Size = UDim2.new(0, 340, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 30, Parent = parent })
	UI.list(holder, nil, 8)
end

-- card: Offers.Card. handlers.try / handlers.buy run when those buttons are pressed.
function OfferCard.show(card: any, handlers: { try: (() -> ())?, buy: (() -> ())? }, seconds: number?)
	if not holder or dismissed[card.kind] then
		return
	end
	for _, c in ipairs(holder:GetChildren()) do
		if c:IsA("Frame") and c:GetAttribute("Kind") == card.kind then
			c:Destroy()
		end
	end
	local f = UI.frame({ BackgroundColor3 = T.panel, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 31, Parent = holder })
	f:SetAttribute("Kind", card.kind)
	UI.corner(f, 12)
	UI.stroke(f, card.color and Color3.fromHex(card.color) or T.gold, 2)
	UI.pad(f, 12)
	UI.list(f, nil, 6)
	UI.label(card.title, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 18, TextColor3 = T.gold, TextWrapped = true, ZIndex = 32, Parent = f })
	UI.label(card.body, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 14, Font = T.body, TextColor3 = T.text, TextWrapped = true, ZIndex = 32, Parent = f })
	local row = UI.frame({ LayoutOrder = 3, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), ZIndex = 32, Parent = f })
	UI.list(row, Enum.FillDirection.Horizontal, 6)
	local function close()
		f:Destroy()
	end
	if card.tryLabel and handlers.try then
		UI.button(card.tryLabel, T.blue, { Size = UDim2.new(0, 120, 0, 34), TextSize = 13, TextColor3 = T.text, ZIndex = 33, Parent = row }, function()
			(handlers.try :: () -> ())()
			if card.kind ~= "fadePreview" then
				close()
			end
		end)
	end
	if card.buyLabel and handlers.buy then
		UI.button(card.buyLabel, T.card, { Size = UDim2.new(0, 110, 0, 34), TextSize = 13, TextColor3 = T.text, ZIndex = 33, Parent = row }, function()
			close();
			(handlers.buy :: () -> ())()
		end)
	end
	UI.button(card.noLabel, T.card, { Size = UDim2.new(0, 84, 0, 34), TextSize = 13, TextColor3 = T.dim, ZIndex = 33, Parent = row }, function()
		if card.itemId and card.kind == "fadePreview" then
			dismissed[card.kind] = true
		end
		close()
	end)
	task.delay(seconds or 20, function()
		if f.Parent then
			close()
		end
	end)
end

return OfferCard

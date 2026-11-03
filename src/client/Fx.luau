--!strict
-- Screen effects: toasts, big announcements, pops, arrow tracers, hit flashes, the cannon bell.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local UI = require(script.Parent.UI)
local Sfx = require(script.Parent.Sfx)
local T = UI.Theme

local Fx = {}
local root: Frame = nil :: any
local toasts: Frame = nil :: any
local banner: TextLabel = nil :: any
local flash: Frame = nil :: any

function Fx.mount(parent: Frame)
	root = parent
	toasts = UI.frame({ Name = "Toasts", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 74), Size = UDim2.new(0, 520, 0, 220), Parent = root })
	UI.list(toasts, nil, 6, Enum.HorizontalAlignment.Center)
	banner = UI.label("", {
		Name = "Announce",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.new(0.9, 0, 0, 70),
		TextSize = 46,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		TextTransparency = 1,
		TextStrokeColor3 = T.bg,
		ZIndex = 20,
		Parent = root,
	})
	flash = UI.frame({ Name = "HitFlash", BackgroundColor3 = T.red, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1, Active = false, Parent = root })
end

local KIND_COLOR: { [string]: Color3 } = {
	good = Color3.fromHex("#2E7D4F"),
	bad = Color3.fromHex("#B3262E"),
	info = Color3.fromHex("#2E3449"),
}

function Fx.toast(text: string, kind: string?)
	if not toasts then
		return
	end
	local f = UI.frame({ BackgroundColor3 = KIND_COLOR[kind or "info"] or KIND_COLOR.info, Size = UDim2.new(0, 500, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = toasts })
	UI.corner(f, 10)
	UI.pad(f, 10)
	UI.label(text, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 18, Font = T.body, TextXAlignment = Enum.TextXAlignment.Center, Parent = f })
	Debris:AddItem(f, 4)
	if #toasts:GetChildren() > 5 then
		for _, c in ipairs(toasts:GetChildren()) do
			if c:IsA("Frame") then
				c:Destroy()
				break
			end
		end
	end
end

function Fx.announce(text: string, color: Color3?, hold: number?)
	if not banner then
		return
	end
	banner.Text = text
	banner.TextColor3 = color or T.gold
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0.4
	local id = {}
	;(banner :: any):SetAttribute("Seq", tostring(id))
	task.delay(hold or 2.4, function()
		if (banner :: any):GetAttribute("Seq") == tostring(id) then
			TweenService:Create(banner, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

function Fx.pop(text: string, color: Color3?, size: number?)
	local l = UI.label(text, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.1, 0.45),
		Size = UDim2.new(0, 500, 0, 60),
		TextSize = size or 30,
		TextColor3 = color or T.gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
		ZIndex = 15,
		Parent = root,
	})
	TweenService:Create(l, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = l.Position - UDim2.fromOffset(0, 70), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(l, 1.2)
end

function Fx.hit()
	flash.BackgroundTransparency = 0.75
	TweenService:Create(flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
end

-- A glowing arrow streak from bow to target.
function Fx.tracer(from: Vector3, to: Vector3, color: string?)
	local d = (to - from).Magnitude
	if d < 1 then
		return
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromHex(color or "#FFE9A8")
	p.Size = Vector3.new(0.15, 0.15, d)
	p.CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to)
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(0.3), { Transparency = 1 }):Play()
	Debris:AddItem(p, 0.35)
end

-- A floating bubble over someone's head (emotes and Gallery cheers).
function Fx.bubble(adornee: BasePart, text: string, color: string?, seconds: number?)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 220, 0, 50)
	bb.StudsOffset = Vector3.new(0, 4.2, 0)
	bb.MaxDistance = 80
	bb.Adornee = adornee
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.Font = Enum.Font.FredokaOne
	tl.TextScaled = true
	tl.TextStrokeTransparency = 0.3
	tl.TextColor3 = Color3.fromHex(color or "#FFE9A8")
	tl.Text = text
	tl.Parent = bb
	bb.Parent = adornee
	TweenService:Create(bb, TweenInfo.new(seconds or 3), { StudsOffset = Vector3.new(0, 6, 0) }):Play()
	Debris:AddItem(bb, seconds or 3)
end

-- Patron Picks firework flare: a bright spark that rises and pops. Cosmetic only.
function Fx.flare(at: Vector3, color: string?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromHex(color or "#FFD36B")
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(at + Vector3.new(0, 4, 0))
	p.Parent = workspace
	local up = TweenService:Create(p, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(at + Vector3.new(0, 40, 0)) })
	up.Completed:Connect(function()
		TweenService:Create(p, TweenInfo.new(0.6), { Size = Vector3.new(14, 14, 14), Transparency = 1 }):Play()
	end)
	up:Play()
	Debris:AddItem(p, 2)
end

-- The knockout bell: one soft ring per knockout so everyone hears the count drop.
function Fx.bell()
	Sfx.play("bell", 0.9, 0.2)
end

return Fx

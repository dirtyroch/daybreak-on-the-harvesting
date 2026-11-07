--!strict
-- Optional first person. Hands and the held weapon are a local viewmodel parented to the
-- camera. The world camera is not bobbed and its field of view cannot exceed 70, which is
-- the third-person default. Nothing here raycasts, changes damage, or writes an aim point.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(script.Parent.Net)
local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)
local Cutscene = require(script.Parent.Cutscene)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arms = require(Shared.Arms)
local Mastery = require(Shared.Mastery)
local Presentation = require(Shared.Logic.Presentation)

local FirstPerson = {}
local player = Players.LocalPlayer
local pending: string? = nil
local applied = false
local swingAt = -10
local viewmodel: Model? = nil
local rels: { [BasePart]: CFrame } = {}
local builtKey = ""

local ENV = {
	Instance = Instance,
	Vector3 = Vector3,
	CFrame = CFrame,
	Color3 = Color3,
	Enum = Enum,
	Vector2 = Vector2,
	NumberRange = NumberRange,
	NumberSequence = NumberSequence,
	ColorSequence = ColorSequence,
}

local function osReduced(): boolean
	local gui = game:GetService("GuiService")
	local ok, v = pcall(function()
		return (gui :: any).ReducedMotionEnabled
	end)
	if ok and v == true then
		return true
	end
	return false
end

function FirstPerson.reduced(): boolean
	local s = Net.state and Net.state.settings
	local flag = type(s) == "table" and s.reduceMotion == true
	return Presentation.motionReduced(flag, osReduced())
end

function FirstPerson.view(): string
	if pending then
		return pending
	end
	return Presentation.viewOf(Net.state and Net.state.settings)
end

function FirstPerson.toggle()
	local nextView = if FirstPerson.view() == "first" then "third" else "first"
	pending = nextView
	task.spawn(Net.act, "setting", "viewFirst", nextView == "first")
end

function FirstPerson.pulse()
	swingAt = os.clock()
end

local function clearHide(char: Model)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			(d :: any).LocalTransparencyModifier = 0
		end
	end
end

local function accessoryName(part: Instance): string?
	local acc = part:FindFirstAncestorOfClass("Accessory")
	if not acc then
		return nil
	end
	local handle = acc:FindFirstChild("Handle")
	if handle then
		local att = handle:FindFirstChildOfClass("Attachment")
		if att then
			return att.Name
		end
	end
	return ""
end

local function hideCharacter(char: Model)
	local parts: { BasePart } = {}
	local decals: { Decal } = {}
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		elseif d:IsA("Decal") then
			table.insert(decals, d)
		end
	end
	for _, d in ipairs(parts) do
		local head = d.Name == "Head" or d:FindFirstAncestor("Head") ~= nil
		local held = d.Name == "Held" or d:FindFirstAncestor("Held") ~= nil
		local hide = Presentation.localHide(d.Name, { head = head, held = held, accessory = accessoryName(d) })
		d.LocalTransparencyModifier = if hide then 1 else 0
	end
	for _, d in ipairs(decals) do
		local parent = d.Parent
		local hide = true
		if parent and parent:IsA("BasePart") and parent.LocalTransparencyModifier < 1 then
			hide = false
		end
		d.LocalTransparencyModifier = if hide then 1 else 0
	end
end

local function destroyView()
	if viewmodel then
		viewmodel:Destroy()
		viewmodel = nil
	end
	table.clear(rels)
	builtKey = ""
end

local function skinColor(char: Model): Color3
	local bc = char:FindFirstChildOfClass("BodyColors")
	if bc and bc:IsA("BodyColors") then
		return bc.RightArmColor3
	end
	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	if hand and hand:IsA("BasePart") then
		return hand.Color
	end
	return Color3.fromRGB(196, 146, 114)
end

local function remember(root: BasePart, part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	rels[part] = root.CFrame:ToObjectSpace(part.CFrame)
end

local function slotNow(): string
	local inv = Hud.inv
	if type(inv) ~= "table" or type(inv.inv) ~= "table" then
		return "hands"
	end
	local item = inv.inv[inv.equipped]
	if item == "bow" or item == "spear" or item == "knife" then
		return item
	end
	return "hands"
end

local function equippedSkin(slot: string): string
	local eq = Net.state and Net.state.equipped
	if type(eq) == "table" and type(eq[slot]) == "string" then
		return eq[slot]
	end
	return ""
end

local function masteryLevel(slot: string, skin: string): number
	local store = Net.state and Net.state.mastery
	if type(store) ~= "table" then
		return 0
	end
	local raw = store[Mastery.key(slot, skin)]
	if type(raw) ~= "number" then
		return 0
	end
	return Mastery.level(raw)
end

local function buildView(char: Model, slot: string)
	destroyView()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local model = Instance.new("Model")
	model.Name = "DaybreakView"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	local color = skinColor(char)
	for _, a in ipairs(Presentation.ARMS) do
		local p = Instance.new("Part")
		p.Name = a.name
		p.Size = Vector3.new(a.size[1], a.size[2], a.size[3])
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CFrame = CFrame.new(a.x, a.y, a.z)
		p.Parent = model
		remember(root, p)
	end
	remember(root, root)
	if slot == "bow" or slot == "spear" or slot == "knife" then
		local g = Presentation.grip(slot)
		local skin = equippedSkin(slot)
		local spec = Arms.spec(slot, skin, masteryLevel(slot, skin))
		local at = CFrame.new(g.x, g.y, g.z) * CFrame.Angles(math.rad(g.pitch), math.rad(g.yaw), math.rad(g.roll))
		local ok, held = pcall(function()
			return Arms.build(ENV, spec, at)
		end)
		if ok and held then
			local grip = held.PrimaryPart :: BasePart?
			if grip then
				local pivot = grip.CFrame
				for _, d in ipairs(held:GetDescendants()) do
					if d:IsA("BasePart") then
						local rel = pivot:ToObjectSpace(d.CFrame)
						local rot = rel - rel.Position
						d.Size = d.Size * g.scale
						d.CFrame = pivot * CFrame.new(rel.Position * g.scale) * rot
					end
				end
			end
			held.Parent = model
			for _, d in ipairs(held:GetDescendants()) do
				if d:IsA("BasePart") then
					remember(root, d)
				end
			end
		end
	end
	model.Parent = cam
	viewmodel = model
	builtKey = slot .. ":" .. equippedSkin(slot)
end

local function placeView(char: Model)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local slot = slotNow()
	local key = slot .. ":" .. equippedSkin(slot)
	if viewmodel == nil or key ~= builtKey then
		buildView(char, slot)
	end
	local model = viewmodel
	local root = model and model.PrimaryPart
	if not model or not root then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local speed = 0
	if hrp and hrp:IsA("BasePart") then
		local vel = hrp.AssemblyLinearVelocity
		speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	elseif hum then
		speed = hum.MoveDirection.Magnitude * hum.WalkSpeed
	end
	local reduced = FirstPerson.reduced()
	local bx, by, bz = Presentation.bob(speed, os.clock(), reduced)
	local age = os.clock() - swingAt
	local sx, sy, sz = Presentation.swing(slot, age, reduced)
	local cf = cam.CFrame * CFrame.new(bx + sx, by + sy, bz + sz)
	for part, rel in pairs(rels) do
		if part.Parent then
			part.CFrame = cf * rel
		end
	end
end

local dot: Frame? = nil
local ring: Frame? = nil

local function ensureReticle(parent: Instance)
	if dot then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "DaybreakViewUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 2
	gui.Parent = parent
	local ringFrame = Instance.new("Frame")
	ring = ringFrame
	ringFrame.Name = "Ring"
	ringFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	ringFrame.Position = UDim2.fromScale(0.5, 0.5)
	ringFrame.BackgroundTransparency = 1
	ringFrame.Visible = false
	ringFrame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(244, 239, 230)
	stroke.Transparency = 0.45
	stroke.Thickness = 1
	stroke.Parent = ringFrame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ringFrame
	local dotFrame = Instance.new("Frame")
	dot = dotFrame
	dotFrame.Name = "Dot"
	dotFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	dotFrame.Position = UDim2.fromScale(0.5, 0.5)
	dotFrame.BackgroundColor3 = Color3.fromRGB(244, 239, 230)
	dotFrame.BackgroundTransparency = 0.25
	dotFrame.BorderSizePixel = 0
	dotFrame.Visible = false
	dotFrame.Parent = gui
	local dc = Instance.new("UICorner")
	dc.CornerRadius = UDim.new(1, 0)
	dc.Parent = dotFrame
end

local function showReticle(on: boolean)
	local touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	local size = Presentation.reticle(touch)
	if dot then
		dot.Visible = on
		dot.Size = UDim2.fromOffset(size.dot, size.dot)
	end
	if ring then
		ring.Visible = on
		ring.Size = UDim2.fromOffset(size.ring, size.ring)
	end
end

local function restoreCamera()
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 128
	local char = player.Character
	if char then
		clearHide(char)
	end
	destroyView()
	showReticle(false)
	applied = false
end

local function applyCamera(char: Model)
	local cam = workspace.CurrentCamera
	local settings = Net.state and Net.state.settings
	local fov = Presentation.clampFov(type(settings) == "table" and settings.fov or Presentation.FOV_DEFAULT)
	if cam and cam.CameraType ~= Enum.CameraType.Scriptable then
		cam.FieldOfView = fov
	end
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 0.5
	hideCharacter(char)
	placeView(char)
	showReticle(true)
	applied = true
end

local function step()
	local settings = Net.state and Net.state.settings
	if pending and type(settings) == "table" and settings.view == pending then
		pending = nil
	end
	local cam = workspace.CurrentCamera
	local char = player.Character
	local scripted = Cutscene.playing or (cam ~= nil and cam.CameraType == Enum.CameraType.Scriptable)
	-- A scripted camera (draw, podium, try-on) owns the lens. Drop our lock once and leave it.
	if scripted then
		if applied then
			if char then
				clearHide(char)
			end
			destroyView()
			showReticle(false)
			player.CameraMode = Enum.CameraMode.Classic
			player.CameraMinZoomDistance = 0.5
			player.CameraMaxZoomDistance = 128
			applied = false
		end
		return
	end
	local fov = Presentation.clampFov(type(settings) == "table" and settings.fov or Presentation.FOV_DEFAULT)
	local force = Presentation.shouldForceFirst(FirstPerson.view(), Hud.mode, Panels.isOpen(), false, false)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if force and char and hum then
		applyCamera(char)
	elseif applied then
		restoreCamera()
	elseif cam then
		cam.FieldOfView = fov
	end
end

function FirstPerson.start(guiParent: Instance)
	ensureReticle(guiParent)
	RunService:BindToRenderStep("DaybreakFirstPerson", Enum.RenderPriority.Camera.Value + 1, step)
	player.CharacterAdded:Connect(function()
		builtKey = ""
	end)
end

return FirstPerson

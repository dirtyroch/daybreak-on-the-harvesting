--!strict
-- Optional first person. The picture moves to the eyes; the shot does not.
-- Head, hair, hats and the local body are hidden so nothing clips the lens.
-- Hands and the held weapon are a local viewmodel (CanQuery false, not replicated).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(script.Parent.UI)
local Net = require(script.Parent.Net)
local Hud = require(script.Parent.Hud)
local Cutscene = require(script.Parent.Cutscene)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Presentation = require(Shared.Presentation)
local Config = require(Shared.Config)
local Arms = require(Shared.Arms) :: any
local Mastery = require(Shared.Mastery)

local View = {}
local player = Players.LocalPlayer
local T = UI.Theme

local E = {
	Instance = Instance,
	Vector3 = Vector3,
	CFrame = CFrame,
	Color3 = Color3,
	Enum = Enum,
	UDim2 = UDim2,
	NumberSequence = NumberSequence,
	NumberRange = NumberRange,
	ColorSequence = ColorSequence,
	Vector2 = Vector2,
}

local wantsFirst = false
local reduceMotion = false
local holds = 0
local applied = false
local savedMin = 0.5
local savedMax = 128
local remembered = false
local hidden: { BasePart } = {}
local viewModel: Model? = nil
local weaponModel: Model? = nil
local weaponKey = ""
local rel: { [BasePart]: CFrame } = {}
local aimMark: Frame? = nil
local useBtn: TextButton? = nil
local throwBtn: TextButton? = nil
local started = false

-- Set by Main so this module does not require Panels (Panels already requires TryOn).
View.menuOpen = function(): boolean
	return false
end
View.onUse = function() end
View.onThrow = function() end

function View.hold()
	holds += 1
end

function View.release()
	holds = math.max(0, holds - 1)
end

function View.isFirst(): boolean
	return wantsFirst and holds == 0 and not Cutscene.playing and not View.menuOpen()
end

function View.apply(settings: any)
	if type(settings) ~= "table" then
		return
	end
	wantsFirst = settings.viewFirst == true
	reduceMotion = settings.reduceMotion == true
end

local function engineReduce(): boolean
	local ok, v = pcall(function()
		return (game:GetService("GuiService") :: any).ReducedMotionEnabled == true
	end)
	return ok and v == true
end

local function motionOff(): boolean
	return reduceMotion or engineReduce()
end

local function showBody()
	for _, p in ipairs(hidden) do
		if p.Parent then
			p.LocalTransparencyModifier = 0
		end
	end
	table.clear(hidden)
end

local function hideBody(char: Model)
	table.clear(hidden)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
			table.insert(hidden, d)
		end
	end
end

local function clearWeapon()
	if weaponModel then
		weaponModel:Destroy()
		weaponModel = nil
	end
	table.clear(rel)
	weaponKey = ""
end

local function clearView()
	clearWeapon()
	if viewModel then
		viewModel:Destroy()
		viewModel = nil
	end
end

local function armColor(char: Model): Color3
	local bc = char:FindFirstChildOfClass("BodyColors")
	if bc then
		return bc.RightArmColor3
	end
	local arm = char:FindFirstChild("RightLowerArm") or char:FindFirstChild("Right Arm")
	if arm and arm:IsA("BasePart") then
		return arm.Color
	end
	return Color3.fromRGB(196, 146, 114)
end

local function ensureModel(): Model
	if viewModel and viewModel.Parent then
		return viewModel
	end
	local m = Instance.new("Model")
	m.Name = "ViewHands"
	local cam = workspace.CurrentCamera
	m.Parent = cam
	viewModel = m
	return m
end

local function limb(parent: Model, name: string, color: Color3, size: Vector3): Part
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Part") then
		return existing
	end
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function placeBar(part: Part, from: Vector3, to: Vector3, thickness: number)
	local delta = to - from
	local len = math.max(delta.Magnitude, 0.05)
	part.Size = Vector3.new(thickness, thickness, len)
	part.CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to)
end

local function skinOf(slot: string): (string, number)
	local s = Net.state
	local skin = (s and s.equipped and s.equipped[slot]) or ""
	local pts = (s and s.mastery and s.mastery[Mastery.key(slot, skin)]) or 0
	return skin, Mastery.level(pts)
end

local function heldSlot(): string?
	local inv = Hud.inv
	if not inv then
		return nil
	end
	local item = inv.inv[inv.equipped]
	local def = item and Config.Items[item]
	if def and def.kind == "weapon" and def.weapon then
		return def.weapon
	end
	return nil
end

-- Wrist pose: fingers point along the camera look, slightly down, so Arms.gripOffset reads naturally.
local function handCf(cam: Camera, side: string): CFrame
	local h = Presentation.HANDS[side]
	return cam.CFrame * CFrame.new(h.x, h.y, h.z) * CFrame.Angles(math.rad(78), math.rad(side == "right" and 168 or -168), 0)
end

local function syncWeapon(cam: Camera)
	local slot = heldSlot()
	local key = slot or ""
	local skin, lvl = "", 0
	if slot then
		skin, lvl = skinOf(slot)
		key = slot .. ":" .. skin .. ":" .. tostring(lvl)
	end
	if key ~= weaponKey then
		clearWeapon()
		weaponKey = key
		if slot then
			local spec = Arms.spec(slot, skin, lvl)
			local grip = handCf(cam, "right") * Arms.gripOffset(E, slot)
			local m = Arms.build(E, spec, grip)
			m.Name = "ViewWeapon"
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanQuery = false
					d.CanTouch = false
					d.CanCollide = false
					d.CastShadow = false
					rel[d] = grip:ToObjectSpace(d.CFrame)
				end
			end
			m.Parent = ensureModel()
			weaponModel = m
		end
	end
	if weaponModel and slot then
		local grip = handCf(cam, "right") * Arms.gripOffset(E, slot)
		for part, offset in pairs(rel) do
			if part.Parent then
				part.CFrame = grip * offset
			end
		end
	end
end

local function syncHands(cam: Camera, char: Model)
	local m = ensureModel()
	if m.Parent ~= cam then
		m.Parent = cam
	end
	local color = armColor(char)
	local right = Presentation.HANDS.right
	local left = Presentation.HANDS.left
	local function world(h: { x: number, y: number, z: number }, back: number): Vector3
		return (cam.CFrame * CFrame.new(h.x * 0.55, h.y + 0.28, h.z + back)).Position
	end
	local rHand = (cam.CFrame * CFrame.new(right.x, right.y, right.z)).Position
	local lHand = (cam.CFrame * CFrame.new(left.x, left.y, left.z)).Position
	placeBar(limb(m, "RightArm", color, Vector3.new(0.28, 0.28, 0.8)), world(right, 0.55), rHand, 0.26)
	placeBar(limb(m, "LeftArm", color, Vector3.new(0.26, 0.26, 0.7)), world(left, 0.5), lHand, 0.24)
	local rh = limb(m, "RightHand", color, Vector3.new(0.22, 0.2, 0.24))
	rh.CFrame = handCf(cam, "right")
	local lh = limb(m, "LeftHand", color, Vector3.new(0.2, 0.18, 0.22))
	lh.CFrame = handCf(cam, "left")
	syncWeapon(cam)
end

local function relaxLock(keepType: boolean)
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMinZoomDistance = savedMin
	player.CameraMaxZoomDistance = savedMax
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	showBody()
	clearView()
	local cam = workspace.CurrentCamera
	if cam then
		cam.FieldOfView = Presentation.FOV
		if not keepType and cam.CameraType == Enum.CameraType.Scriptable then
			cam.CameraType = Enum.CameraType.Custom
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				cam.CameraSubject = hum
			end
		end
	end
	applied = false
end

local function rememberZoom()
	if remembered then
		return
	end
	savedMin = player.CameraMinZoomDistance
	savedMax = player.CameraMaxZoomDistance
	if savedMax < 20 then
		savedMax = 128
	end
	remembered = true
end

function View.shotAim(): Vector3
	local cam = workspace.CurrentCamera
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local focusPos = if head and head:IsA("BasePart") then head.Position elseif hrp then hrp.Position + Vector3.new(0, 1.5, 0) else nil
	local look = cam and cam.CFrame.LookVector
	if not focusPos or not look then
		return player:GetMouse().Hit.Position
	end
	local aim = Presentation.shotAim({ x = focusPos.X, y = focusPos.Y, z = focusPos.Z }, { x = look.X, y = look.Y, z = look.Z })
	return Vector3.new(aim.x, aim.y, aim.z)
end

local function refreshChrome()
	local arena = Hud.mode == "arena"
	local show = Presentation.crosshairVisible(wantsFirst, arena, View.menuOpen() or Cutscene.playing or holds > 0, false)
	if aimMark then
		aimMark.Visible = show
	end
	local touch = UserInputService.TouchEnabled and show
	if useBtn then
		useBtn.Visible = touch
	end
	if throwBtn then
		throwBtn.Visible = touch
	end
end

local function step()
	refreshChrome()
	local blocked = holds > 0 or Cutscene.playing or View.menuOpen()
	if not wantsFirst or blocked then
		if applied then
			relaxLock(blocked)
		end
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not hum or not hrp or hum.Health <= 0 then
		if applied then
			relaxLock(false)
		end
		return
	end
	rememberZoom()
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 0.5
	applied = true
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local look = cam.CFrame.LookVector
	local reduce = motionOff()
	local speed = hrp.AssemblyLinearVelocity.Magnitude
	local bob = Presentation.bob(os.clock(), speed, reduce)
	local pos = cam.CFrame.Position + look * Presentation.EYE_FORWARD + cam.CFrame.RightVector * bob.x + cam.CFrame.UpVector * bob.y
	cam.CFrame = CFrame.lookAt(pos, pos + look)
	local sprinting = hum.WalkSpeed > Config.WALK_SPEED + 1
	cam.FieldOfView = Presentation.fov(sprinting, reduce)
	if Presentation.HIDE_LOCAL_BODY then
		hideBody(char)
	elseif Presentation.hidesPart("Head") then
		local head = char:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			head.LocalTransparencyModifier = 1
		end
	end
	syncHands(cam, char)
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
end

local function tick(parent: Instance, name: string, pos: UDim2, rot: number): Frame
	local f = UI.frame({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(2, 6),
		Rotation = rot,
		BackgroundColor3 = T.text,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = parent,
	})
	return f
end

function View.mount(parent: Frame)
	local mark = UI.frame({
		Name = "AimMark",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 6,
		Parent = parent,
	})
	aimMark = mark
	-- Short ticks with a gap, so the mark shows the center without covering it.
	tick(mark, "N", UDim2.new(0.5, 0, 0, 2), 0)
	tick(mark, "S", UDim2.new(0.5, 0, 1, -2), 0)
	tick(mark, "W", UDim2.new(0, 2, 0.5, 0), 90)
	tick(mark, "E", UDim2.new(1, -2, 0.5, 0), 90)
	local dot = UI.frame({
		Name = "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(3, 3),
		BackgroundColor3 = T.gold,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = mark,
	})
	UI.corner(dot, 2)

	useBtn = UI.button("Use", T.gold, {
		Name = "FirstPersonUse",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -96),
		Size = UDim2.fromOffset(88, 44),
		Visible = false,
		ZIndex = 7,
		Parent = parent,
	}, function()
		View.onUse()
	end)
	throwBtn = UI.button("Throw", T.card, {
		Name = "FirstPersonThrow",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -112, 1, -96),
		Size = UDim2.fromOffset(88, 44),
		TextColor3 = T.text,
		Visible = false,
		ZIndex = 7,
		Parent = parent,
	}, function()
		View.onThrow()
	end)
end

function View.start()
	if started then
		return
	end
	started = true
	RunService:BindToRenderStep("DaybreakView", Enum.RenderPriority.Camera.Value + 1, step)
end

return View

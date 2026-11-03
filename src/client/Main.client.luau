--!strict
-- Client entry: builds the UI in code, wires server pushes, and handles arena input
-- (click to use the held item, 1–6 to pick a slot, Shift to sprint).
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(script.Parent.UI)
local Net = require(script.Parent.Net)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)
local Cutscene = require(script.Parent.Cutscene)
local GalleryPanel = require(script.Parent.GalleryPanel)
local Results = require(script.Parent.Results)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Names = require(Shared.Names)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = UI.new("ScreenGui", { Name = "Daybreak", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui })
-- Scale everything down on phones; the scaled root is sized 1/scale so edge-anchored pieces stay on the edges.
local root = UI.new("Frame", { Name = "Root", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = screen })
local scale = UI.new("UIScale", { Parent = root })
local function rescale()
	local cam = workspace.CurrentCamera
	local v = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local s = math.clamp(math.min(v.X / 1280, v.Y / 760), 0.55, 1)
	scale.Scale = s
	root.Size = UDim2.fromScale(1 / s, 1 / s)
end
rescale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

Sfx.mount()
UI.onClick = function()
	Sfx.play("click", nil, 0.05)
end
Fx.mount(root)
Panels.mount(root)
Hud.mount(root, Panels)
GalleryPanel.mount(root)
Results.mount(root)
Cutscene.mount(root)
Net.notify = Fx.toast

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

Net.on("toast", function(p)
	Fx.toast(p.text, p.kind)
end)
Net.on("arena", function()
	Hud.mode = "arena"
	Fx.announce("GO!", UI.Theme.gold, 1.6)
	Sfx.play("bell", 1.1)
end)
Net.on("matchStart", function(d)
	Fx.toast(string.format("%s begins: %d players + %d %ss.", Names.EVENT_SHORT, d.humans, d.bots, Names.BOT_TAG), "info")
end)
Net.on("hazard", function(d)
	Sfx.play("hiss", nil, 1)
	Fx.announce(d.name, UI.Theme.red, 2.4)
	Fx.toast(d.text, "bad")
end)
Net.on("tracer", function(d)
	Fx.tracer(d.from, d.to)
end)
Net.on("hitmark", function(d)
	Sfx.play("swat", 1.1, 0.05)
	Fx.pop("-" .. tostring(math.floor(d.amount)), UI.Theme.gold, 22)
end)
Net.on("pep", function(d)
	if d.from ~= "snack" and d.from ~= "gift" then
		Fx.hit()
	end
end)
Net.on("loot", function(d)
	Sfx.play("pop", nil, 0.05)
	Fx.toast("Found: " .. d.name, "good")
end)
Net.on("token", function(d)
	Sfx.play("coins")
	Fx.pop((d.new and "New token! " or "Token: ") .. d.name, UI.Theme.gold, 28)
end)
Net.on("gift", function(d)
	Sfx.play("ding")
	Fx.announce("🪂 Gift from " .. d.from .. "!", UI.Theme.blue, 2.4)
	if d.note then
		Fx.toast("“" .. d.note .. "”", "good")
	end
end)

-- ===== arena input =====
local stamina = Config.STAMINA_MAX
local sprinting = false

local function arena(): boolean
	return Hud.mode == "arena" and not Cutscene.playing
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if arena() and not Panels.isOpen() then
			local mouse = player:GetMouse()
			Net.act("use", mouse.Hit.Position)
		end
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		sprinting = true
	elseif input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
		Panels.close()
		Cutscene.skip()
	else
		local n = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
		if arena() and n >= 1 and n <= 6 then
			Net.act("equipSlot", n)
		end
	end
end)
UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		sprinting = false
	end
end)

RunService.Heartbeat:Connect(function(dt: number)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or not char then
		return
	end
	local mult = (char:GetAttribute("SpeedMult") or 1) :: number
	local moving = hum.MoveDirection.Magnitude > 0.1
	if arena() and sprinting and moving and stamina > 0 then
		stamina = math.max(0, stamina - Config.STAMINA_DRAIN * dt)
		hum.WalkSpeed = Config.SPRINT_SPEED * mult
	else
		stamina = math.min(Config.STAMINA_MAX, stamina + Config.STAMINA_REGEN * dt)
		hum.WalkSpeed = Config.WALK_SPEED * mult
	end
end)

task.spawn(function()
	while true do
		task.wait(0.1)
		local ok, err = pcall(function(): any
			Hud.update()
			if Net.state and Net.state.settings then
				local want = Net.state.settings.sfx ~= false
				if want ~= Sfx.isEnabled() then
					Sfx.setEnabled(want)
				end
			end
			return nil
		end)
		if not ok then
			warn("[Hud] " .. tostring(err))
		end
	end
end)

task.delay(2, function()
	if not Net.state then
		Net.act("refresh")
	end
end)

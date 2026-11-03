--!strict
-- Client entry: builds the UI in code, wires server pushes, and handles arena input
-- (click to use the held item, 1–6 to pick a slot, Shift to sprint, Q / right-click to throw a
-- spear, P to offer a pact, Y/N to answer one, X to snap yours). Stamina is server-owned: the
-- client only says "I want to sprint" and shows what the server sends back.
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

Hud.note = function(text: string)
	Fx.toast(text, "info")
end
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
	Fx.tracer(d.from, d.to, d.color)
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
Net.on("pactOffer", function(d)
	Sfx.play("ding")
	Fx.announce("🤝 " .. d.name .. " offers a pact", UI.Theme.blue, 2.2)
	Fx.toast(string.format("%s (%s) wants a pact. Y to accept, N to decline (%ds).", d.name, d.reach, d.seconds), "info")
end)
Net.on("pactWarning", function(d)
	Sfx.play("hiss", 1.3)
	Fx.announce("⚠ " .. d.name .. " is snapping your pact!", UI.Theme.red, d.seconds)
end)
Net.on("pactSnapped", function(d)
	Fx.announce("💔 " .. d.name .. " broke your pact", UI.Theme.red, 2.4)
	Fx.toast("“" .. d.line .. "” (Guarded for " .. d.guard .. "s)", "info")
end)
Net.on("pactSnapDone", function(d)
	Fx.announce("Pact snapped", UI.Theme.red, 1.6)
	Fx.toast(string.format("Your first hit on %s in %ds is a Pact Snap strike.", table.concat(d.names, " or "), d.window), "info")
end)
Net.on("pactsEnded", function(d)
	Fx.announce(string.format("Final %d: every pact is over", d.left), UI.Theme.gold, 2.4)
end)
Net.on("veilCore", function()
	Sfx.play("hiss", 0.7)
	Fx.announce("The Veil Core is glowing", UI.Theme.veil, 2.6)
	Fx.toast("Bounce a thrown spear off " .. Names.VEIL .. " into the Core to break the dome.", "info")
end)
Net.on("veilBroken", function(d)
	Sfx.play("fanfare")
	Fx.announce(string.format("💥 %s broke the dome!", d.by), UI.Theme.veil, 3)
	Fx.toast(string.format("%s is calm for %ds.", Names.VEIL, d.seconds), "good")
end)
Net.on("betrayed", function(d)
	Fx.hit()
	Fx.toast("“" .. d.line .. "”", "bad")
end)
local function headOf(userId: number): BasePart?
	local p = Players:GetPlayerByUserId(userId)
	local head = p and p.Character and p.Character:FindFirstChild("Head")
	return head and head:IsA("BasePart") and head or nil
end
Net.on("emote", function(d)
	local head = headOf(d.user)
	if head then
		Fx.bubble(head, d.icon .. " " .. d.name, d.color, 3)
	end
end)
Net.on("cheer", function(d)
	if d.kind == "flare" and d.at then
		Fx.flare(d.at, d.color)
	end
	Fx.toast(string.format("%s %s cheers for %s!", d.kind == "flare" and "🎆" or "📣", d.from, d.to), "info")
end)
Net.on("gift", function(d)
	Sfx.play("ding")
	Fx.announce("🪂 Gift from " .. d.from .. "!", UI.Theme.blue, 2.4)
	if d.note then
		Fx.toast("“" .. d.note .. "”", "good")
	end
end)

-- ===== arena input =====
local sprinting = false
local function setSprint(on: boolean)
	if on ~= sprinting then
		sprinting = on
		task.spawn(Net.act, "sprint", on)
	end
end

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
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Q then
		if arena() and not Panels.isOpen() then
			Net.act("throw", player:GetMouse().Hit.Position)
		end
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		setSprint(true)
	elseif input.KeyCode == Enum.KeyCode.B and not arena() and not Panels.isOpen() then
		task.spawn(Net.act, "emote", "")
	elseif input.KeyCode == Enum.KeyCode.P and arena() then
		Net.act("pactOffer")
	elseif input.KeyCode == Enum.KeyCode.Y and arena() then
		Net.act("pactAccept")
	elseif input.KeyCode == Enum.KeyCode.N and arena() then
		Net.act("pactDecline")
	elseif input.KeyCode == Enum.KeyCode.X and arena() then
		Net.act("pactSnap")
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
		setSprint(false)
	end
end)
Net.on("arena", function()
	if sprinting then
		task.spawn(Net.act, "sprint", true)
	end
end)
local _ = RunService
local _c = Config

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

--!strict
--[[
	After a knockout or a finish:
	  * Kill-cam "How you got tapped": the camera swings from your spot to whoever got you, with
	    their weapon, distance and Pep left.
	  * Near-miss card: what you almost did ("2 more knockouts for a new best") plus your rewards.
	  * Requeue: "Next match in 10s" with your match streak, plus Watch / Lobby buttons.
	Copy is encouraging and factual. No "you'll lose your streak!" style pressure.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(script.Parent.UI)
local Net = require(script.Parent.Net)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local Hud = require(script.Parent.Hud)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Names = require(Shared.Names)
local Content = require(Shared.Content)
local T = UI.Theme

local Results = {}
local card: Frame = nil :: any
local head: TextLabel = nil :: any
local sub: TextLabel = nil :: any
local lines: Frame = nil :: any
local reward: TextLabel = nil :: any
local countdown: TextLabel = nil :: any
local requeueAt = 0

local function showCard(place: number?, headline: string, nm: { string }, result: any, extra: string?)
	card.Visible = true
	head.Text = place == 1 and ("🌅 " .. Names.CHAMPION .. "!") or string.format("#%d of 48", place or 0)
	sub.Text = headline
	UI.clear(lines)
	for i, l in ipairs(nm) do
		UI.label("• " .. l, { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 22), TextSize = 16, Font = T.body, Parent = lines })
	end
	if extra then
		UI.label(extra, { LayoutOrder = 10, Size = UDim2.new(1, 0, 0, 22), TextSize = 15, Font = T.body, TextColor3 = T.dim, Parent = lines })
	end
	if result then
		local parts = { string.format("+%d %s", result.xp or 0, Names.XP) }
		if (result.stars or 0) > 0 then
			table.insert(parts, string.format("+%d ★", result.stars))
		end
		if (result.playStreak or 0) > 1 then
			table.insert(parts, string.format("match streak %d (×%.1f)", result.playStreak, result.playMult or 1))
		end
		if (result.tiersUp or 0) > 0 then
			table.insert(parts, string.format("%d new %s tier%s!", result.tiersUp, Names.TRACK, result.tiersUp == 1 and "" or "s"))
		end
		reward.Text = table.concat(parts, "  ·  ")
		if result.streakMsg then
			Fx.toast(result.streakMsg, "good")
		end
	end
end

local function killcam(d: any)
	local cam = workspace.CurrentCamera
	if not cam or not d.at then
		return
	end
	local from: Vector3 = d.from or (d.at + Vector3.new(0, 8, 14))
	cam.CameraType = Enum.CameraType.Scriptable
	local mid = d.at:Lerp(from, 0.5) + Vector3.new(0, 10, 0)
	cam.CFrame = CFrame.lookAt(d.at + Vector3.new(6, 6, 6), d.at)
	TweenService:Create(cam, TweenInfo.new(1.4, Enum.EasingStyle.Sine), { CFrame = CFrame.lookAt(mid + (mid - d.at).Unit:Cross(Vector3.yAxis) * 12, from) }):Play()
	if d.byModel and d.byModel:FindFirstChild("HumanoidRootPart") then
		local hl = Instance.new("Highlight")
		hl.FillColor = T.red
		hl.OutlineColor = T.gold
		hl.Parent = d.byModel
		game:GetService("Debris"):AddItem(hl, 3)
	end
	task.delay(3, function()
		cam.CameraType = Enum.CameraType.Custom
	end)
end

function Results.mount(parent: Frame)
	card = UI.frame({ Name = "Results", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.new(0, 520, 0, 300), Visible = false, ZIndex = 8, Parent = parent })
	UI.corner(card, 16)
	UI.stroke(card, T.gold, 2)
	UI.pad(card, 14)
	head = UI.label("", { Size = UDim2.new(1, 0, 0, 40), TextSize = 36, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
	sub = UI.label("", { Position = UDim2.new(0, 0, 0, 42), Size = UDim2.new(1, 0, 0, 24), TextSize = 19, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
	lines = UI.frame({ BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 72), Size = UDim2.new(1, 0, 0, 100), Parent = card })
	UI.list(lines, nil, 2)
	reward = UI.label("", { Position = UDim2.new(0, 0, 0, 176), Size = UDim2.new(1, 0, 0, 24), TextSize = 17, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
	countdown = UI.label("", { Position = UDim2.new(0, 0, 0, 204), Size = UDim2.new(1, 0, 0, 22), TextSize = 16, Font = T.body, TextColor3 = T.dim, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
	local row = UI.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 42), Parent = card })
	UI.list(row, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center)
	UI.button("Play again", T.gold, { LayoutOrder = 1, Size = UDim2.new(0, 150, 0, 40), Parent = row }, function()
		Net.act("queue")
	end)
	UI.button("Watch", T.blue, { LayoutOrder = 2, Size = UDim2.new(0, 120, 0, 40), Parent = row }, function()
		card.Visible = false
		Net.act("watch")
	end)
	UI.button("Close", T.card, { LayoutOrder = 3, Size = UDim2.new(0, 110, 0, 40), TextColor3 = T.text, Parent = row }, function()
		card.Visible = false
	end)

	Net.on("eliminated", function(d)
		Sfx.play("bell", 0.85)
		Hud.mode = "gallery"
		local how = d.by and string.format("Tapped by %s (%s) with %s%s. They had %d Pep left.", d.by, d.byReach or "?", d.weapon or "a shove", d.dist and string.format(" from %d studs", math.floor(d.dist)) or "", math.floor(d.byPep or 0)) or ("Knocked out by " .. tostring(d.cause))
		Fx.announce("How you got tapped", T.red, 2.6)
		Fx.toast(how, "info")
		killcam(d)
		task.delay(1.6, function()
			showCard(d.place, d.headline, d.lines, d.result, how)
			countdown.Text = d.autoQueue and "You're watching from " .. Names.GALLERY .. ". You'll be in the next match automatically." or "Watch from " .. Names.GALLERY .. " or play again."
		end)
	end)
	Net.on("finished", function(d)
		if d.place == 1 then
			Sfx.play("fanfare")
			Fx.announce("🌅 " .. Names.CHAMPION .. "!", T.gold, 3.5)
			Fx.toast("“" .. Content.RUSTY.win .. "”", "good")
		end
		showCard(d.place, d.headline, d.lines, d.result, nil)
	end)
	Net.on("podium", function(d)
		Hud.mode = "lobby"
		Fx.announce(string.format("%s of %s wins!", d.winner, d.reach), T.gold, 3)
		requeueAt = workspace:GetServerTimeNow() + d.next
	end)
	Net.on("requeue", function(d)
		requeueAt = workspace:GetServerTimeNow() + d.seconds
		Fx.toast(string.format("Next match in %ds. %d queued.", d.seconds, d.queued), "info")
	end)
	Net.on("knocked", function(d)
		Sfx.play("crunch")
		Fx.pop(string.format("Knocked out %s! %d left", d.name, d.left), T.gold, 30)
	end)
	Net.on("feed", function(d)
		Fx.bell()
		if d.encore then
			Fx.toast(string.format("✨ %s is back! %s", d.victim, d.cause), "good")
		end
	end)
	Net.on("levelup", function(d)
		Sfx.play("fanfare")
		Fx.announce(string.format("Level %d!", d.level), T.gold, 2.5)
	end)
	Net.on("challenge", function(d)
		Sfx.play("coins")
		Fx.toast(string.format("📜 Challenge done: %s  +%d %s  +%d ★", d.text, d.xp, Names.XP, d.stars), "good")
	end)
	Net.on("encore", function()
		card.Visible = false
		Hud.mode = "arena"
		Fx.announce("Encore! You're back in!", T.veil, 3)
	end)
	Net.on("matchStart", function()
		card.Visible = false
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			if card.Visible and requeueAt > 0 then
				local left = math.ceil(requeueAt - workspace:GetServerTimeNow())
				if left > 0 then
					countdown.Text = string.format("Next match in %ds", left)
				end
			end
		end
	end)
	local _ = Players
end

return Results

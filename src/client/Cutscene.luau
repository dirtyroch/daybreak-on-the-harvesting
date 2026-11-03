--!strict
--[[
	The pregame show, played locally for each contender:
	  1. The Harvesting (full on your first match, short after that or with the setting):
	     wide shot of the plaza, the Herald at the glass globe, a slip is drawn, your own avatar
	     (a local clone) walks up the aisle, and Rusty Dunmore walks over to meet you on stage.
	  2. The Parade (7 s): six Reach floats roll down the avenue; yours carries your avatar and
	     the camera rides alongside.
	  3. The Interview (7 s): Monty Gleam asks one question; you tap one of three preset answers
	     (your lobby pick is the default). No chat, no free text. Other contenders' picks scroll by.
	  4. Training (6 s + board): five targets pop up; click them. The server re-scores your clicks
	     (1 to 10), then everyone's scores appear on the board. A low score makes Gallery gifts to
	     you cheaper, so it never pays to be good at faking.
	Skippable at any time; skipping just jumps to the launch countdown. Depth of field is on while
	a cutscene plays.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(script.Parent.UI)
local Net = require(script.Parent.Net)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local Rusty = require(script.Parent.Rusty)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Names = require(Shared.Names)
local Content = require(Shared.Content)
local Training = require(Shared.Logic.Training)
local Lighting = game:GetService("Lighting")
local T = UI.Theme

local Cutscene = {}
local player = Players.LocalPlayer
local layer: Frame = nil :: any
local caption: TextLabel = nil :: any
local sub: TextLabel = nil :: any
local bars: { Frame } = {}
local seq = 0
local cleanup: { () -> () } = {}
Cutscene.playing = false

local function marks(): Instance?
	local map = workspace:FindFirstChild("Map")
	local lobby = map and map:FindFirstChild("Lobby")
	return lobby and lobby:FindFirstChild("CutsceneMarks")
end

local function markCF(name: string): CFrame?
	local m = marks()
	local p = m and m:FindFirstChild(name)
	return p and (p :: BasePart).CFrame or nil
end

local function camTo(name: string, time: number)
	local cf = markCF(name)
	local cam = workspace.CurrentCamera
	if not cf or not cam then
		return
	end
	if time <= 0 then
		cam.CFrame = cf
	else
		TweenService:Create(cam, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = cf }):Play()
	end
end

local function say(text: string, small: string?)
	caption.Text = text
	sub.Text = small or ""
end

local function alive(id: number): boolean
	return seq == id and Cutscene.playing
end

local function wait(id: number, s: number): boolean
	task.wait(s)
	return alive(id)
end

local function tweenModel(m: Model, to: CFrame, time: number)
	local v = Instance.new("CFrameValue")
	v.Value = m:GetPivot()
	v.Changed:Connect(function(cf: CFrame)
		if m.Parent then
			m:PivotTo(cf)
		end
	end)
	local tw = TweenService:Create(v, TweenInfo.new(time, Enum.EasingStyle.Linear), { Value = to })
	tw.Completed:Connect(function()
		v:Destroy()
	end)
	tw:Play()
end

-- A local, anchored copy of your avatar for the walk to the stage.
local function cloneMe(at: CFrame): Model?
	local char = player.Character
	if not char then
		return nil
	end
	char.Archivable = true
	local ok, copy = pcall(function()
		return char:Clone()
	end)
	if not ok or not copy then
		return nil
	end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("ForceField") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	local hum = copy:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	copy.Name = "ReapingDouble"
	copy:PivotTo(at)
	copy.Parent = workspace
	table.insert(cleanup, function()
		copy:Destroy()
	end)
	return copy
end

local function dof(on: boolean)
	local d = Lighting:FindFirstChild("CutsceneDOF")
	if d and d:IsA("DepthOfFieldEffect") then
		d.Enabled = on
	end
end

local panel: Frame = nil :: any -- interview buttons / training targets / board live here
local function clearPanel()
	if panel then
		for _, ch in ipairs(panel:GetChildren()) do
			ch:Destroy()
		end
		panel.Visible = false
	end
end

local function stop()
	Cutscene.playing = false
	dof(false)
	clearPanel()
	seq += 1
	for _, fn in ipairs(cleanup) do
		pcall(fn)
	end
	cleanup = {}
	layer.Visible = false
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if h then
			cam.CameraSubject = h
		end
	end
end

local function reaping(id: number, d: any, short: boolean)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	camTo("CamWide", 0)
	say(Names.DRAW, string.format("%s · %s", Names.EVENT, d.reach or ""))
	Sfx.play("bell", 0.8)
	if short then
		camTo("CamStage", 1.2)
		if not wait(id, 1.4) then
			return
		end
		say("Contender for " .. tostring(d.reach) .. ": " .. player.DisplayName, d.partnerName and ("with " .. d.partnerName) or nil)
		wait(id, 1.6)
		return
	end
	if not wait(id, 1.6) then
		return
	end
	camTo("CamGlobe", 1.6)
	say(Names.HERALD .. " reaches into the globe…")
	if not wait(id, 2.0) then
		return
	end
	camTo("CamHerald", 0.8)
	say("“From " .. tostring(d.reach) .. "… " .. player.DisplayName .. "!”")
	Sfx.play("ding")
	if not wait(id, 1.6) then
		return
	end
	-- you walk up the aisle
	local aisle, stage = markCF("AisleMark"), markCF("StageMark")
	local crowd = markCF("CrowdMark")
	local double = crowd and cloneMe(crowd * CFrame.Angles(0, math.pi, 0))
	camTo("CamCrowd", 0.6)
	say("The crowd steps aside.")
	if double and aisle and stage then
		tweenModel(double, CFrame.lookAt(aisle.Position, stage.Position), 1.6)
		task.delay(1.6, function()
			if double.Parent then
				tweenModel(double, CFrame.lookAt(stage.Position, stage.Position + Vector3.new(0, 0, 10)), 1.2)
			end
		end)
	end
	if not wait(id, 1.4) then
		return
	end
	camTo("CamPlayer", 1.2)
	if not wait(id, 1.6) then
		return
	end
	-- Rusty walks over to meet you
	local lobby = workspace:FindFirstChild("Map") and (workspace :: any).Map:FindFirstChild("Lobby")
	local rusty = lobby and lobby:FindFirstChild("Rusty") :: Model?
	local rStart, rMark = markCF("RustyStart"), markCF("RustyMark")
	if rusty and rStart and rMark then
		local home = rusty:GetPivot()
		table.insert(cleanup, function()
			rusty:PivotTo(home)
		end)
		tweenModel(rusty, CFrame.lookAt(rMark.Position, rMark.Position + Vector3.new(1, 0, 0)), 2.2)
	end
	camTo("CamRusty", 1.0)
	say(Names.MENTOR .. " climbs the steps.", "“" .. Content.RUSTY.reaping .. "”")
	Rusty.voice(Content.RUSTY.reaping, Net.state and Net.state.equipped and Net.state.equipped.rusty)
	if not wait(id, 2.6) then
		return
	end
	camTo("CamPull", 1.6)
	say(Names.CONTENDERS .. " of " .. tostring(d.reach), d.partnerName and ("You and " .. d.partnerName .. ". Stick together.") or "Twenty-four Reaches. Forty-eight contenders. One sunrise.")
	wait(id, 1.8)
end

-- ===== the Parade =====
local function float(parent: Instance, reach: string, color: Color3, at: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "ParadeFloat"
	local function p(name: string, size: Vector3, off: CFrame, c: Color3, mat: Enum.Material, shape: Enum.PartType?): Part
		local x = Instance.new("Part")
		x.Name = name
		x.Anchored = true
		x.CanCollide = false
		x.Size = size
		x.CFrame = at * off
		x.Color = c
		x.Material = mat
		if shape then
			x.Shape = shape
		end
		x.Parent = m
		return x
	end
	local base = p("Deck", Vector3.new(16, 2, 10), CFrame.new(0, 2.6, 0), Color3.fromHex("#4A3A2C"), Enum.Material.WoodPlanks)
	p("Skirt", Vector3.new(16.2, 1.4, 10.2), CFrame.new(0, 1.6, 0), color, Enum.Material.Fabric)
	for _, w in ipairs({ { -5.5, -5.2 }, { 5.5, -5.2 }, { -5.5, 5.2 }, { 5.5, 5.2 } }) do
		p("Wheel", Vector3.new(0.8, 3, 3), CFrame.new(w[1], 1.5, w[2]) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromHex("#2E2A26"), Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
	end
	local pole = p("BannerPole", Vector3.new(0.3, 9, 0.3), CFrame.new(-6.5, 8, 0), Color3.fromHex("#3B3530"), Enum.Material.CorrodedMetal)
	local banner = p("Banner", Vector3.new(0.1, 3.4, 5.2), CFrame.new(-6.5, 10.6, 2.6), color, Enum.Material.Fabric)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Right
	g.CanvasSize = Vector2.new(260, 170)
	g.Parent = banner
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.Font = Enum.Font.GothamBold
	tl.TextScaled = true
	tl.TextColor3 = Color3.fromHex("#EDE6D6")
	tl.Text = reach
	tl.Parent = g
	local _ = pole
	m.PrimaryPart = base
	m.Parent = parent
	return m
end

local REACH_TINTS = { "#6E4A3A", "#3F5560", "#5A5A3E", "#4E3E58", "#6A5A40", "#3E5A4A" }

local function parade(id: number, d: any)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local L = Config.Map.LOBBY_CENTER
	local origin = Vector3.new(L[1], L[2], L[3])
	local z = 158
	local folder = Instance.new("Folder")
	folder.Name = "Parade"
	folder.Parent = workspace
	table.insert(cleanup, function()
		folder:Destroy()
	end)
	local reaches = { tostring(d.reach) }
	for _, r in ipairs(d.roster or {}) do
		if #reaches >= 6 then
			break
		end
		if r.reach ~= d.reach and not table.find(reaches, r.reach) then
			table.insert(reaches, r.reach)
		end
	end
	local floats: { Model } = {}
	for k, reach in ipairs(reaches) do
		local cf = CFrame.new(origin + Vector3.new(-150 - (k - 1) * 22, 0, z)) * CFrame.Angles(0, -math.pi / 2, 0)
		floats[k] = float(folder, reach, Color3.fromHex(REACH_TINTS[(k - 1) % #REACH_TINTS + 1]), cf)
	end
	local mine = floats[1]
	local double = cloneMe(mine:GetPivot() * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, math.pi / 2, 0))
	say("The " .. Names.CAPITAL .. " Parade", tostring(d.reach) .. " rolls out first. Wave to the crowd!")
	Sfx.play("bell", 1.1)
	local dur = Config.Pregame.parade - 0.4
	local t0 = os.clock()
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		if not alive(id) then
			conn:Disconnect()
			return
		end
		local a = math.clamp((os.clock() - t0) / dur, 0, 1)
		local dx = 230 * a
		for k, f in ipairs(floats) do
			f:PivotTo(CFrame.new(origin + Vector3.new(-150 - (k - 1) * 22 + dx, 0, z)) * CFrame.Angles(0, -math.pi / 2, 0))
		end
		if double and double.Parent then
			double:PivotTo(mine:GetPivot() * CFrame.new(0, 3.6 + math.sin(os.clock() * 3) * 0.05, 0) * CFrame.Angles(0, math.pi / 2, 0))
		end
		local fp = mine:GetPivot().Position
		cam.CFrame = CFrame.lookAt(fp + Vector3.new(10 - 6 * a, 9, -26), fp + Vector3.new(0, 5, 0))
	end)
	table.insert(cleanup, function()
		conn:Disconnect()
	end)
	wait(id, dur)
	conn:Disconnect()
end

-- ===== the Interview =====
local function interview(id: number, d: any)
	camTo("CamInterview", 0)
	local default = tonumber(d.quipIndex) or 1
	local seat = markCF("InterviewSeat")
	if seat then
		cloneMe(seat)
	end
	say(Names.HOST .. ": “" .. tostring(d.question or Content.QUESTIONS[1]) .. "”", "Pick an answer. (Default: your lobby line.)")
	Sfx.play("ding")
	panel.Visible = true
	local picks = { default, default % #Content.QUIPS + 1, (default + 2) % #Content.QUIPS + 1 }
	local chosen = false
	local function choose(i: number)
		if chosen or not alive(id) then
			return
		end
		chosen = true
		clearPanel()
		Net.act("interview", i)
		say("You: “" .. Content.QUIPS[i] .. "”", Names.HOST .. " beams. The crowd cheers.")
		Sfx.play("coins", 1.2)
	end
	for k, i in ipairs(picks) do
		UI.button(Content.QUIPS[i], k == 1 and T.gold or T.card, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.52 + (k - 1) * 0.075, 0),
			Size = UDim2.new(0, 520, 0, 40),
			TextSize = 17,
			TextColor3 = k == 1 and Color3.fromHex("#1C1F2B") or T.text,
			ZIndex = 33,
			Parent = panel,
		}, function()
			choose(i)
		end)
	end
	if not wait(id, 4.2) then
		return
	end
	choose(default)
	wait(id, Config.Pregame.interview - 4.4)
end

-- ===== Training =====
local pendingBoard: any = nil
local function showBoard(b: any)
	clearPanel()
	panel.Visible = true
	local mine = b.mine or 5
	say("Training score: " .. mine .. " / " .. Config.Training.max, mine <= b.underdogAt and "Underdog! Gallery gifts to you cost 20% less." or Names.MENTOR_SHORT .. " nods. “Not bad, kid.”")
	Sfx.play(mine >= 8 and "fanfare" or "ding")
	local box = UI.frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.new(0, 360, 0, 230), BackgroundTransparency = 0.15, ZIndex = 33, Parent = panel })
	UI.corner(box, 12)
	UI.pad(box, 10)
	UI.list(box, Enum.FillDirection.Vertical, 4)
	UI.label("Training board · top 6", { Size = UDim2.new(1, 0, 0, 24), TextSize = 18, TextColor3 = T.gold, ZIndex = 34, LayoutOrder = 0, Parent = box })
	for k = 1, math.min(6, #b.board) do
		local r = b.board[k]
		UI.label(string.format("%d. %s (%s) · %d", k, r.name, r.reach, r.score), { Size = UDim2.new(1, 0, 0, 22), TextSize = 15, Font = T.body, ZIndex = 34, LayoutOrder = k, Parent = box })
	end
end

local function trainingRound(id: number, d: any)
	camTo("CamRange", 0.8)
	say("Training", "Click the targets. Five of them, quick!")
	clearPanel()
	panel.Visible = true
	local targets = Training.targets(tonumber(d.trainingSeed) or 1, Config.Training.targets, Config.Training.duration)
	local clicks = {}
	local t0 = os.clock()
	local hits = 0
	for _, tg in ipairs(targets) do
		task.delay(tg.at, function()
			if not alive(id) then
				return
			end
			local b = Instance.new("TextButton")
			b.Text = "◎"
			b.TextScaled = true
			b.TextColor3 = Color3.fromHex("#B3262E")
			b.BackgroundColor3 = Color3.fromHex("#EDE6D6")
			b.AnchorPoint = Vector2.new(0.5, 0.5)
			b.Position = UDim2.fromScale(tg.x, tg.y)
			b.Size = UDim2.new(0, 74, 0, 74)
			b.ZIndex = 34
			UI.corner(b, 37)
			b.Parent = panel
			b.Activated:Connect(function()
				table.insert(clicks, { i = tg.i, t = os.clock() - t0 })
				hits += 1
				Sfx.play("pop")
				b:Destroy()
			end)
			task.delay(tg.life, function()
				if b.Parent then
					b:Destroy()
				end
			end)
		end)
	end
	if not wait(id, Config.Training.duration) then
		return
	end
	Net.act("training", clicks)
	clearPanel()
	say(string.format("%d of %d hit", hits, #targets), "Scores coming in…")
	if not wait(id, 0.9) then
		return
	end
	if pendingBoard then
		showBoard(pendingBoard)
		pendingBoard = nil
	end
	if not wait(id, 2.0) then
		return
	end
	if d.twist then
		clearPanel()
		say("Today's twist: " .. d.twist.name, d.twist.text)
		wait(id, 1.4)
	end
end

local function ceremony(id: number, d: any)
	parade(id, d)
	if not alive(id) then
		return
	end
	interview(id, d)
	if not alive(id) then
		return
	end
	trainingRound(id, d)
end

function Cutscene.play(d: any)
	stop()
	seq += 1
	local id = seq
	Cutscene.playing = true
	layer.Visible = true
	pendingBoard = nil
	dof(true)
	task.spawn(function()
		-- v5: Quick Trials always uses the short draw and skips the ceremony
		local short = d.short == true or d.quick == true
		reaping(id, d, short)
		if not alive(id) then
			return
		end
		Net.act("seenReaping")
		if not d.quick then
			ceremony(id, d)
		end
		if alive(id) then
			stop()
		end
	end)
end

function Cutscene.skip()
	if Cutscene.playing then
		Net.act("seenReaping")
		stop()
		Fx.toast("Skipped. Get ready to launch!", "info")
	end
end

function Cutscene.mount(parent: Frame)
	layer = UI.frame({ Name = "Cutscene", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 30, Parent = parent })
	for i, y in ipairs({ 0, 1 }) do
		bars[i] = UI.frame({ BackgroundColor3 = Color3.new(0, 0, 0), AnchorPoint = Vector2.new(0, y), Position = UDim2.fromScale(0, y), Size = UDim2.new(1, 0, 0.11, 0), ZIndex = 30, Parent = layer })
	end
	caption = UI.label("", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.86, 0), Size = UDim2.new(0.8, 0, 0, 44), TextSize = 34, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3, ZIndex = 31, Parent = layer })
	sub = UI.label("", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.885, 4), Size = UDim2.new(0.8, 0, 0, 26), TextSize = 19, Font = T.body, TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4, ZIndex = 31, Parent = layer })
	UI.button("Skip ▸▸", T.card, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0.11, 10), Size = UDim2.new(0, 110, 0, 38), TextColor3 = T.text, ZIndex = 32, Parent = layer }, Cutscene.skip)
	panel = UI.frame({ Name = "CeremonyPanel", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 33, Parent = layer })
	Net.on("pregame", Cutscene.play)
	Net.on("trainingBoard", function(b)
		if Cutscene.playing and #panel:GetChildren() > 0 then
			pendingBoard = b -- still clicking targets; show it when the round ends
		elseif Cutscene.playing then
			showBoard(b)
		else
			Fx.toast(string.format("Training score: %d / %d", b.mine or 5, Config.Training.max), "info")
		end
	end)
	Net.on("interviewLine", function(l)
		if Cutscene.playing then
			Fx.toast(string.format("%s (%s): “%s”", l.name, l.reach, l.quip), "info")
		end
	end)
	Net.on("launch", function(d)
		stop()
		Fx.announce("Stand on your plate!", T.gold, 2)
		Fx.toast(string.format("Launch in %ds. Don't step off early.", d.seconds), "info")
		Rusty.say("launch", "info")
	end)
	local _ = Config
end

return Cutscene

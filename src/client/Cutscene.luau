--!strict
--[[
	The pregame show, played locally for each contender:
	  1. The Harvesting (full on your first match, short after that or with the setting):
	     wide shot of the plaza, the Herald at the glass globe, a slip is drawn, your own avatar
	     (a local clone) walks up the aisle, and Rusty Dunmore walks over to meet you on stage.
	  2. Parade, interview and training: v1 stubs (a camera flyby + title cards + your chosen
	     interview line + a cosmetic training score).
	Skippable at any time; skipping just jumps to the launch countdown.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(script.Parent.UI)
local Net = require(script.Parent.Net)
local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Names = require(Shared.Names)
local Content = require(Shared.Content)
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

local function stop()
	Cutscene.playing = false
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
	if not wait(id, 2.6) then
		return
	end
	camTo("CamPull", 1.6)
	say(Names.CONTENDERS .. " of " .. tostring(d.reach), d.partnerName and ("You and " .. d.partnerName .. ". Stick together.") or "Twenty-four Reaches. Forty-eight contenders. One sunrise.")
	wait(id, 1.8)
end

local function stubs(id: number, d: any)
	-- v1 stubs: parade flyby, interview card, training score
	camTo("CamWide", 1.0)
	say("The " .. Names.CAPITAL .. " Parade", "Coming soon: chariots, coats and capes. (v1 stub)")
	if not wait(id, 1.8) then
		return
	end
	say("Interview with " .. Names.HOST, "“" .. tostring(d.quip) .. "”")
	if not wait(id, 1.8) then
		return
	end
	local score = math.random(6, 11)
	say("Training score: " .. score .. " / 12", Names.MENTOR_SHORT .. " nods. (cosmetic only)")
	Net.act("training", score)
	if not wait(id, 1.4) then
		return
	end
	if d.twist then
		say("Today's twist: " .. d.twist.name, d.twist.text)
		wait(id, 1.8)
	end
end

function Cutscene.play(d: any)
	stop()
	seq += 1
	local id = seq
	Cutscene.playing = true
	layer.Visible = true
	task.spawn(function()
		local short = d.short == true
		reaping(id, d, short)
		if not alive(id) then
			return
		end
		Net.act("seenReaping")
		stubs(id, d)
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
	Net.on("pregame", Cutscene.play)
	Net.on("launch", function(d)
		stop()
		Fx.announce("Stand on your plate!", T.gold, 2)
		Fx.toast(string.format("Launch in %ds. Don't step off early. %s", d.seconds, Content.RUSTY.launch), "info")
	end)
	local _ = Config
end

return Cutscene

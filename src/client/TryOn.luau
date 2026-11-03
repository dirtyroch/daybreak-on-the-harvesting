--!strict
--[[
	TryOn: see a cosmetic on your own "practice double" before buying. Only you can see it
	(everything here is client-side). Weapons appear in the double's hand, poses and emotes play,
	fades play a full knockout dissolve on the double with the real finishing effect.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fx = require(script.Parent.Fx)
local AnimPlayer = require(script.Parent.AnimPlayer)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arms = require(Shared.Arms) :: any
local Anim = require(Shared.Anim)
local Store = require(Shared.Store)
local Content = require(Shared.Content)
local Finishers = require(Shared.Finishers)

local TryOn = {}

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

local double: Model? = nil
local token = 0

function TryOn.stop()
	token += 1
	if double then
		AnimPlayer.stop(double)
		double:Destroy()
		double = nil
	end
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
	end
end

local function makeDouble(): Model?
	local char = Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not hrp then
		return nil
	end
	char.Archivable = true
	local m = char:Clone()
	char.Archivable = false
	if not m then
		return nil
	end
	m.Name = "PracticeDouble"
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("BillboardGui") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.Anchored = d.Name == "HumanoidRootPart"
		end
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.PlatformStand = true
	end
	m:PivotTo(hrp.CFrame * CFrame.new(0, 0, -9) * CFrame.Angles(0, math.pi, 0))
	m.Parent = workspace
	return m
end

local function focus(m: Model, seconds: number)
	local cam = workspace.CurrentCamera
	local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not cam or not root then
		return
	end
	cam.CameraType = Enum.CameraType.Scriptable
	local at = root.Position
	local from = at + root.CFrame.LookVector * 9 + Vector3.new(2.5, 2.5, 0)
	TweenService:Create(cam, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { CFrame = CFrame.lookAt(from, at + Vector3.new(0, 0.5, 0)) }):Play()
	local my = token
	task.delay(seconds, function()
		if token == my then
			TryOn.stop()
		end
	end)
end

local function dissolve(m: Model, fadeId: string)
	local f = Content.FADES[fadeId] or Content.FADES.fade_gold
	local color = Color3.fromHex(f.color)
	local h = Instance.new("Highlight")
	h.FillColor = color
	h.OutlineColor = Color3.new(1, 1, 1)
	h.FillTransparency = 0.15
	h.Parent = m
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			TweenService:Create(d, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		end
	end
	local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		Finishers.play(f.style, root.Position, color)
	end
end

-- Try an item by id (weapon skin, pose, emote or fade). Returns false for other slots.
function TryOn.show(id: string): boolean
	local it = Store.byId[id]
	local fade = Content.FADES[id]
	if not it and not fade then
		return false
	end
	local slot = it and it.slot or "fade"
	if slot ~= "bow" and slot ~= "spear" and slot ~= "knife" and slot ~= "pose" and slot ~= "emote" and slot ~= "fade" then
		return false
	end
	TryOn.stop()
	local m = makeDouble()
	if not m then
		return false
	end
	double = m
	local name = it and it.name or (fade and fade.name) or id
	if slot == "bow" or slot == "spear" or slot == "knife" then
		Arms.attach(E, m, slot, id, 0)
		AnimPlayer.play(m, "pose_heart", { seconds = 5 })
		focus(m, 5)
	elseif slot == "pose" or slot == "emote" then
		local clip = (it and it.clip) or id
		AnimPlayer.play(m, (Anim.CLIPS :: any)[clip] and clip or Anim.DEFAULT_POSE, { seconds = 5 })
		focus(m, 5)
	else
		focus(m, 4.5)
		task.delay(1.2, function()
			if double == m then
				dissolve(m, id)
			end
		end)
	end
	Fx.toast("👁 Trying " .. name .. " on your practice double. Only you can see this.", "info")
	return true
end

function TryOn.canTry(id: string): boolean
	local it = Store.byId[id]
	if Content.FADES[id] then
		return true
	end
	return it ~= nil and (it.slot == "bow" or it.slot == "spear" or it.slot == "knife" or it.slot == "pose" or it.slot == "emote")
end

return TryOn

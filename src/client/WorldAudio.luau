--!strict
-- Footsteps, arena bed, Veil pulses, crate and weapon sounds.
-- Weapons are heard from the server's tracer / swing events, which already happened
-- after the server accepted the action. This module does not decide hits.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sfx = require(script.Parent.Sfx)
local Hud = require(script.Parent.Hud)
local Net = require(script.Parent.Net)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioMix = require(Shared.Logic.AudioMix)

local WorldAudio = {}
local player = Players.LocalPlayer
local hooked: { [Model]: boolean } = {}
local steppedAt: { [Model]: number } = {}

local function isLocal(model: Model): boolean
	return player.Character == model
end

local function nearMe(pos: Vector3): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - pos).Magnitude < 8
end

local function watch(model: Model)
	if hooked[model] then
		return
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not hum or not root or not root:IsA("BasePart") then
		return
	end
	hooked[model] = true
	hum.Running:Connect(function(speed: number)
		local gap = AudioMix.footstepInterval(speed)
		if not gap or hum.FloorMaterial == Enum.Material.Air then
			return
		end
		local now = os.clock()
		local prev = steppedAt[model]
		if prev and now - prev < gap then
			return
		end
		steppedAt[model] = now
		local r = model:FindFirstChild("HumanoidRootPart")
		if r and r:IsA("BasePart") then
			Sfx.playAt("footstep", r.Position, AudioMix.footPitch(hum.FloorMaterial.Name), gap, model:GetFullName(), isLocal(model))
		end
	end)
	model.Destroying:Connect(function()
		hooked[model] = nil
		steppedAt[model] = nil
	end)
end

function WorldAudio.update()
	local inArena = Hud.mode == "arena"
	Sfx.setLoop("ambience", inArena)
	if not inArena then
		return
	end
	local m = Hud.match
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not m or type(m.radius) ~= "number" or not root or not root:IsA("BasePart") then
		return
	end
	local flat = Vector3.new(root.Position.X, 0, root.Position.Z).Magnitude
	local cue = AudioMix.veilCue(m.radius - flat)
	if cue then
		Sfx.play(cue)
	end
end

function WorldAudio.start()
	local function consider(inst: Instance)
		if inst:IsA("Humanoid") and inst.Parent and inst.Parent:IsA("Model") then
			watch(inst.Parent)
		end
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		consider(d)
	end
	workspace.DescendantAdded:Connect(consider)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		if who ~= player then
			return
		end
		local host = prompt.Parent
		if host and host:GetAttribute("Crate") then
			return
		end
		local pos = nil :: Vector3?
		if host and host:IsA("BasePart") then
			pos = host.Position
		elseif host and host:IsA("Attachment") then
			pos = host.WorldPosition
		end
		if pos then
			Sfx.playAt("interact", pos, nil, nil, "prompt", true)
		else
			Sfx.play("interact")
		end
	end)

	Net.on("tracer", function(d)
		if typeof(d.from) ~= "Vector3" then
			return
		end
		local name = if d.spear then "weapon_throw" else "weapon_bow"
		local mine = type(d.by) == "number" and d.by == player.UserId or nearMe(d.from)
		Sfx.playAt(name, d.from, nil, nil, tostring(d.by or "shot"), mine)
	end)
	Net.on("swing", function(d)
		local name = if d.weapon == "knife" then "weapon_knife" elseif d.weapon == "spear" then "weapon_spear" else "weapon_shove"
		if typeof(d.at) == "Vector3" then
			local mine = type(d.by) == "number" and d.by == player.UserId or nearMe(d.at)
			Sfx.playAt(name, d.at, nil, nil, tostring(d.by or d.id or "swing"), mine)
		else
			Sfx.play(name)
		end
	end)
	Net.on("crate", function(d)
		if typeof(d.at) == "Vector3" then
			Sfx.playAt("interact", d.at, nil, nil, "crate", nearMe(d.at))
		else
			Sfx.play("interact")
		end
	end)
end

return WorldAudio

--!strict
-- World-driven sounds: footsteps, landings, weapon releases, the Veil, and a little air.
-- Rates and surface choice live in Audio.luau so they can be tested without Studio.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(script.Parent.Net)
local Sfx = require(script.Parent.Sfx)
local Hud = require(script.Parent.Hud)
local Cutscene = require(script.Parent.Cutscene)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Audio = require(Shared.Audio)
local Config = require(Shared.Config)

local WorldAudio = {}
local player = Players.LocalPlayer
local started = false
local stepDebt = 0
local lastWeapon = ""
local weaponReady = false

local function root(): BasePart?
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	return nil
end

local function playAt(name: string, at: any)
	if typeof(at) == "Vector3" then
		Sfx.play(name, nil, nil, at)
	else
		Sfx.play(name)
	end
end

function WorldAudio.start()
	if started then
		return
	end
	started = true

	Net.on("tracer", function(d)
		playAt(if d.spear then "spearThrow" else "bowRelease", d.from)
	end)
	Net.on("swing", function(d)
		local cue = Audio.weaponCue(tostring(d.weapon or ""), false) or "shove"
		playAt(cue, d.at)
	end)
	Net.on("loot", function(d)
		local def = d.item and Config.Items[d.item]
		if def and def.kind == "weapon" then
			Sfx.play("equip")
		elseif def and (def.kind == "snack" or def.kind == "ammo") then
			Sfx.play("pickup")
		else
			Sfx.play("crate")
		end
	end)
	Net.on("pep", function(d)
		if d.from == "snack" then
			Sfx.play("snack")
		elseif d.from == "veil" then
			Sfx.play("veilTouch")
		elseif d.from ~= "gift" then
			Sfx.play("hurt")
		end
	end)
	Net.on("inv", function(d)
		local item = d.inv and d.inv[d.equipped]
		local def = item and Config.Items[item]
		local slot = (def and def.weapon) or ""
		if weaponReady and slot ~= "" and slot ~= lastWeapon then
			Sfx.play("equip")
		end
		lastWeapon = slot
		weaponReady = true
	end)

	local function bind(char: Model)
		local hum = char:WaitForChild("Humanoid", 8)
		if hum and hum:IsA("Humanoid") then
			hum.StateChanged:Connect(function(_, new)
				if new == Enum.HumanoidStateType.Landed and Hud.mode == "arena" then
					local hrp = char:FindFirstChild("HumanoidRootPart")
					if hrp and hrp:IsA("BasePart") then
						Sfx.play("footLand", nil, nil, hrp.Position)
					end
				end
			end)
		end
	end
	if player.Character then
		task.spawn(bind, player.Character)
	end
	player.CharacterAdded:Connect(bind)

	RunService.Heartbeat:Connect(function(dt)
		if Cutscene.playing then
			return
		end
		if Hud.mode == "arena" then
			Sfx.play("arenaAir")
			local hrp = root()
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.FloorMaterial ~= Enum.Material.Air then
				local vel = hrp.AssemblyLinearVelocity
				local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
				local interval = Audio.footInterval(speed)
				if interval then
					stepDebt += dt
					if stepDebt >= interval then
						stepDebt = 0
						local params = RaycastParams.new()
						params.FilterType = Enum.RaycastFilterType.Exclude
						params.FilterDescendantsInstances = { player.Character :: any }
						local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -6, 0), params)
						local mat = if hit then hit.Material.Name else hum.FloorMaterial.Name
						Sfx.play(Audio.footCue(mat), nil, nil, hrp.Position)
					end
				else
					stepDebt = 0
				end
			end
			local m = Hud.match
			if hrp and m and type(m.radius) == "number" then
				local flat = Vector3.new(hrp.Position.X, 0, hrp.Position.Z).Magnitude
				local cue = Audio.veilEvent(flat > m.radius, m.radius - flat, m.shrinking == true, m.nextIn)
				if cue then
					Sfx.play(cue)
				end
			end
		elseif Hud.mode == "lobby" then
			stepDebt = 0
			Sfx.play("lobbyAir")
		else
			stepDebt = 0
		end
	end)
end

return WorldAudio

--!strict
--[[
	Rusty's voice. Every line shows as a toast and a speech bubble over Rusty in the lobby, and
	plays a voice: a recorded line if the equipped pack has a `sound` id (Content.RUSTY_VOICE,
	PUBLISHING.md 6g), otherwise a short "babble" made from a stock Roblox client sound, pitched
	per pack. Respects the sound setting.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Net = require(script.Parent.Net)
local Fx = require(script.Parent.Fx)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Content = require(Shared.Content)

local Rusty = {}

local function pack(): string?
	local s = Net.state
	return s and s.equipped and s.equipped.rusty or nil
end

local function soundOn(): boolean
	local s = Net.state
	return not (s and s.settings and s.settings.sfx == false)
end

local function rustyHead(): BasePart?
	local map = workspace:FindFirstChild("Map")
	if not map then
		return nil
	end
	for _, d in ipairs(map:GetDescendants()) do
		if d:IsA("Model") and d:GetAttribute("LookId") == "Rusty" then
			return (d:FindFirstChild("Head") or d.PrimaryPart) :: BasePart?
		end
	end
	return nil
end

function Rusty.voice(line: string, p: string?)
	if not soundOn() then
		return
	end
	local v = Content.rustyVoice(p)
	if v.sound ~= 0 then
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. v.sound
		s.Volume = 0.8
		s.Parent = SoundService
		s:Play()
		Debris:AddItem(s, 12)
		return
	end
	for _, b in ipairs(Content.babble(line, p)) do
		task.delay(b.t, function()
			local s = Instance.new("Sound")
			s.SoundId = Content.RUSTY_BABBLE
			s.PlaybackSpeed = b.pitch
			s.Volume = 0.22
			s.Parent = SoundService
			s:Play()
			Debris:AddItem(s, 1)
		end)
	end
end

-- Say one of Rusty's lines (key from Content.RUSTY) with the equipped pack.
function Rusty.say(key: string, kind: string?)
	local p = pack()
	local line = Content.rustyLine(p, key)
	Fx.toast("“" .. line .. "”", kind)
	local head = rustyHead()
	if head then
		Fx.bubble(head, line, "#E8D9B5", 4)
	end
	Rusty.voice(line, p)
	return line
end

return Rusty

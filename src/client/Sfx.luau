--!strict
-- Sound effects: one SoundGroup of short one-shots. Players can turn them off in Settings.
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SfxIds = require(Shared.SfxIds) :: { [string]: any }

local Sfx = {}
local group: SoundGroup = nil :: any
local base: { [string]: Sound } = {}
local enabled = true
local lastPlayed: { [string]: number } = {}

function Sfx.mount()
	group = Instance.new("SoundGroup")
	group.Name = "DaybreakSfx"
	group.Volume = 0.8
	group.Parent = SoundService
	local list = {}
	for name, def in pairs(SfxIds) do
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = "rbxassetid://" .. tostring(def.id)
		s.Volume = def.volume or 0.5
		s.SoundGroup = group
		s.Parent = group
		base[name] = s
		table.insert(list, s)
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
end

function Sfx.setEnabled(on: boolean)
	enabled = on
	if group then
		group.Volume = on and 0.8 or 0
	end
end

function Sfx.isEnabled(): boolean
	return enabled
end

-- Play a one-shot. `minGap` stops spam from rapid repeats.
function Sfx.play(name: string, pitch: number?, minGap: number?)
	local s = base[name]
	if not enabled or not s then
		return
	end
	local now = os.clock()
	if minGap and lastPlayed[name] and now - lastPlayed[name] < minGap then
		return
	end
	lastPlayed[name] = now
	local c = s:Clone()
	c.PlaybackSpeed = pitch or 1
	c.Parent = group
	c:Play()
	local def = SfxIds[name]
	local life = (def and def.stop) or 6
	task.delay(life, function()
		if c.IsPlaying then
			c:Stop()
		end
		c:Destroy()
	end)
end

return Sfx

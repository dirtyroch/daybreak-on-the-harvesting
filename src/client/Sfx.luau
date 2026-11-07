--!strict
-- Mixer: one SoundGroup per bus, spatial one-shots, and a hard gap so nothing stacks into a shout.
-- Placeholders (no engine path and no library id, uploadId still 0) are silent.
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Audio = require(Shared.Audio)

local Sfx = {}
local master: SoundGroup? = nil
local buses: { [string]: SoundGroup } = {}
local enabled = true
local lastPlayed: { [string]: number } = {}
local recent: { number } = {}
local busVolume: { [string]: number } = {}

local function recentCount(now: number): number
	local keep = {}
	local n = 0
	for _, t in ipairs(recent) do
		if now - t < 0.2 then
			table.insert(keep, t)
			n += 1
		end
	end
	recent = keep
	return n
end

function Sfx.mount()
	local mix = Instance.new("SoundGroup")
	mix.Name = "DaybreakMix"
	mix.Volume = 0.85
	mix.Parent = SoundService
	master = mix
	for _, name in ipairs(Audio.BUSES) do
		local g = Instance.new("SoundGroup")
		g.Name = "Daybreak" .. name
		g.Volume = Audio.DEFAULT_VOLUME[name] or 0.5
		g.Parent = mix
		buses[name] = g
		busVolume[name] = g.Volume
	end
	local list = {}
	for _, cue in pairs(Audio.CUES) do
		local uri = Audio.playback(cue)
		if uri ~= "" then
			local s = Instance.new("Sound")
			s.SoundId = uri
			table.insert(list, s)
		end
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
		for _, s in ipairs(list) do
			s:Destroy()
		end
	end)
end

function Sfx.bus(name: string): SoundGroup?
	return buses[name]
end

function Sfx.setEnabled(on: boolean)
	enabled = on
	if master then
		master.Volume = on and 0.85 or 0
	end
end

function Sfx.isEnabled(): boolean
	return enabled
end

function Sfx.apply(settings: any)
	if type(settings) ~= "table" then
		return
	end
	Sfx.setEnabled(settings.sfx ~= false)
	for bus, key in pairs(Audio.VOLUME_KEY) do
		local g = buses[bus]
		local raw = settings[key]
		local v = Audio.clampVolume(if type(raw) == "number" then raw else (Audio.DEFAULT_VOLUME[bus] or 0.5))
		busVolume[bus] = v
		if g then
			g.Volume = v
		end
	end
end

function Sfx.busVolume(name: string): number
	return busVolume[name] or 0
end

-- `at` parents the sound to a silent part so it falls off with distance.
function Sfx.play(name: string, pitch: number?, minGap: number?, at: Vector3?)
	local cue = Audio.cue(name)
	if not cue or not enabled or not master then
		return
	end
	local uri, kind = Audio.playback(cue)
	if uri == "" or kind == "placeholder" then
		return
	end
	local now = os.clock()
	local gap = cue.minGap or 0
	if minGap then
		gap = math.max(gap, minGap)
	end
	local key = Audio.gapKey(Audio.alias(name), if at then { x = at.X, y = at.Y, z = at.Z } else nil)
	if not Audio.allow(lastPlayed[key], now, gap) then
		return
	end
	local busName = cue.bus or "ui"
	if not Audio.admit(recentCount(now), busName) then
		return
	end
	lastPlayed[key] = now
	table.insert(recent, now)
	local group = buses[busName] or master
	local sound = Instance.new("Sound")
	sound.Name = Audio.alias(name)
	sound.SoundId = uri
	sound.Volume = cue.volume or 0.3
	sound.PlaybackSpeed = pitch or cue.pitch or 1
	sound.SoundGroup = group
	local life = (cue.stop ~= nil and cue.stop > 0) and cue.stop or 4
	if at and cue.spatial then
		local p = Instance.new("Part")
		p.Name = "SfxAt"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		p.CFrame = CFrame.new(at)
		p.Parent = workspace
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = cue.rollMin or 8
		sound.RollOffMaxDistance = cue.rollMax or 70
		sound.Parent = p
		Debris:AddItem(p, life + 0.15)
	else
		sound.Parent = group
		Debris:AddItem(sound, life + 0.15)
	end
	sound:Play()
	if cue.stop and cue.stop > 0 then
		task.delay(cue.stop, function()
			if sound.Parent and sound.IsPlaying then
				sound:Stop()
			end
		end)
	end
end

return Sfx

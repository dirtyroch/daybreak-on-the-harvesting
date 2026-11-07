--!strict
-- Playback. One SoundGroup per bus, so a saved mute or volume scales every cue in that bus.
-- Spatial one-shots sit on a tiny invisible part. The part cannot be queried, so it never
-- blocks an aim ray. Cue gaps are a floor: callers can wait longer, not fire faster.
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SfxIds = require(Shared.SfxIds)
local AudioMix = require(Shared.Logic.AudioMix)

local Sfx = {}

local groups: { [string]: SoundGroup } = {}
local loops: { [string]: Sound } = {}
local lastPlayed: { [string]: number } = {}
local settings: any = nil
local ears: Folder? = nil
local budgetCount = 0
local budgetAt = 0

local function ensure()
	if groups.effects then
		return
	end
	for _, bus in ipairs({ "effects", "ambience", "voice", "ui" }) do
		local g = Instance.new("SoundGroup")
		g.Name = "Daybreak_" .. bus
		g.Volume = 1
		g.Parent = SoundService
		groups[bus] = g
	end
end

local function ear(pos: Vector3): Part
	if not ears or not ears.Parent then
		local f = Instance.new("Folder")
		f.Name = "DaybreakEars"
		f.Parent = workspace
		ears = f
	end
	local p = Instance.new("Part")
	p.Name = "Ear"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(pos)
	p.Parent = ears
	return p
end

function Sfx.mount()
	ensure()
	Sfx.apply({
		sfx = true,
		volumes = { master = 80, effects = 85, ambience = 40, voice = 70, ui = 55 },
		muted = {},
	})
end

function Sfx.apply(s: any)
	settings = s
	ensure()
	for bus, g in pairs(groups) do
		g.Volume = AudioMix.gain(s, bus)
	end
end

function Sfx.setEnabled(on: boolean)
	if type(settings) ~= "table" then
		settings = {}
	end
	settings.sfx = on
	Sfx.apply(settings)
end

function Sfx.isEnabled(): boolean
	return not (type(settings) == "table" and settings.sfx == false)
end

function Sfx.audible(bus: string): boolean
	return AudioMix.gain(settings, bus) > 0
end

function Sfx.group(bus: string): SoundGroup?
	ensure()
	return groups[bus]
end

local function admit(isLocal: boolean): boolean
	local now = os.clock()
	if now - budgetAt > AudioMix.SPATIAL_WINDOW then
		budgetAt = now
		budgetCount = 0
	end
	if not AudioMix.admit(budgetCount, isLocal) then
		return false
	end
	if not isLocal then
		budgetCount += 1
	end
	return true
end

local function spawn(name: string, where: Vector3?, pitch: number?, minGap: number?, emitter: string?, isLocal: boolean?)
	local cue = SfxIds.get(name)
	if not cue or cue.loop then
		return
	end
	local id = AudioMix.resolve(cue)
	if id == "" then
		return
	end
	local gap = AudioMix.gap(cue, minGap)
	local key = AudioMix.gapKey(name, emitter)
	local now = os.clock()
	if lastPlayed[key] and now - lastPlayed[key] < gap then
		return
	end
	if where then
		local cam = workspace.CurrentCamera
		local maxDist = cue.maxDist or 70
		if cam and not AudioMix.inRange((cam.CFrame.Position - where).Magnitude, maxDist) then
			return
		end
		if not admit(isLocal == true) then
			return
		end
	end
	lastPlayed[key] = now
	ensure()
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Volume = AudioMix.cueVolume(cue)
	s.PlaybackSpeed = AudioMix.speed(cue, pitch)
	s.SoundGroup = groups[cue.bus] or groups.effects
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	local life = cue.stop or 2
	if where then
		s.RollOffMinDistance = cue.minDist or 6
		s.RollOffMaxDistance = cue.maxDist or 70
		local host = ear(where)
		s.Parent = host
		s:Play()
		Debris:AddItem(host, life + 0.25)
	else
		s.Parent = s.SoundGroup
		s:Play()
		Debris:AddItem(s, life + 0.25)
	end
	if cue.stop then
		task.delay(cue.stop, function()
			if s.Parent and s.IsPlaying then
				s:Stop()
			end
		end)
	end
end

function Sfx.play(name: string, pitch: number?, minGap: number?)
	spawn(name, nil, pitch, minGap, nil, true)
end

function Sfx.playAt(name: string, pos: Vector3, pitch: number?, minGap: number?, emitter: string?, isLocal: boolean?)
	spawn(name, pos, pitch, minGap, emitter, isLocal)
end

function Sfx.setLoop(name: string, on: boolean)
	local cue = SfxIds.get(name)
	if not cue or not cue.loop then
		return
	end
	local id = AudioMix.resolve(cue)
	if id == "" then
		return
	end
	ensure()
	local existing = loops[name]
	local s: Sound
	if existing then
		s = existing
	else
		s = Instance.new("Sound")
		s.Name = name
		s.Looped = true
		s.Volume = AudioMix.cueVolume(cue)
		s.PlaybackSpeed = cue.pitch
		local bus = groups[cue.bus] or groups.ambience
		if bus then
			s.SoundGroup = bus
			s.Parent = bus
		else
			s.Parent = SoundService
		end
		loops[name] = s
	end
	if s.SoundId ~= id then
		s.SoundId = id
	end
	if on then
		if not s.IsPlaying then
			s:Play()
		end
	elseif s.IsPlaying then
		s:Stop()
	end
end

return Sfx

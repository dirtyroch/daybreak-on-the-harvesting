--!strict
-- Finishers.luau: the animated knockout effect for each fade style. Runs on the server for real
-- knockouts and on the client for the free "see your knockout with this fade" preview and the
-- Locker try-on, so both always look identical. Cosmetic only, about 2.5 seconds.
local TweenService = game:GetService("TweenService")

local Finishers = {}

local function fxPart(name: string, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	if shape then
		p.Shape = shape
	end
	p.Parent = workspace
	return p
end

-- Particle settings per finisher style (all cosmetic, ~2.5 s).
local STYLE_PARTICLES = {
	embers = { rate = 0, burst = 60, speed = { 4, 10 }, life = { 1, 1.8 }, size = 0.35, accel = Vector3.new(0, 6, 0) },
	petals = { rate = 0, burst = 50, speed = { 3, 7 }, life = { 1.5, 2.2 }, size = 0.45, accel = Vector3.new(0, -2, 0), rot = true },
	lanterns = { rate = 0, burst = 14, speed = { 1, 3 }, life = { 2, 2.6 }, size = 0.8, accel = Vector3.new(0, 4, 0) },
	ash = { rate = 0, burst = 70, speed = { 1, 4 }, life = { 1.5, 2.5 }, size = 0.3, accel = Vector3.new(0, 1, 0) },
	stars = { rate = 0, burst = 40, speed = { 6, 14 }, life = { 0.8, 1.4 }, size = 0.5, accel = Vector3.new(0, -8, 0) },
	comet = { rate = 0, burst = 30, speed = { 2, 5 }, life = { 0.8, 1.2 }, size = 0.6, accel = Vector3.new(0, 30, 0) },
	shimmer = { rate = 0, burst = 40, speed = { 0.5, 2 }, life = { 1, 1.6 }, size = 0.25, accel = Vector3.new(0, 2, 0) },
}

-- The animated finishing effect for a fade style at a position.
function Finishers.play(style: string, pos: Vector3, color: Color3)
	local anchor = fxPart("FadeFx", Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), color)
	anchor.Transparency = 1
	local ps = STYLE_PARTICLES[style]
	if ps then
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
		e.LightEmission = 1
		e.Rate = 0
		e.Speed = NumberRange.new(ps.speed[1], ps.speed[2])
		e.Lifetime = NumberRange.new(ps.life[1], ps.life[2])
		e.Size = NumberSequence.new(ps.size, 0)
		e.Acceleration = ps.accel
		e.SpreadAngle = Vector2.new(180, 180)
		if ps.rot then
			e.RotSpeed = NumberRange.new(-180, 180)
		end
		e.Parent = anchor
		e:Emit(ps.burst)
	end
	if style == "column" or style == "comet" or style == "lanterns" then
		local beam = fxPart("LightColumn", Vector3.new(2, 3, 3), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.PartType.Cylinder)
		beam.Transparency = 0.2
		TweenService:Create(beam, TweenInfo.new(2.2), { Size = Vector3.new(120, 1, 1), CFrame = CFrame.new(pos + Vector3.new(0, 60, 0)) * CFrame.Angles(0, 0, math.pi / 2), Transparency = 1 }):Play()
		task.delay(2.4, function()
			beam:Destroy()
		end)
	elseif style == "burst" then
		for i = 0, 2 do
			task.delay(i * 0.25, function()
				local ring = fxPart("SunRing", Vector3.new(0.3, 2, 2), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.PartType.Cylinder)
				ring.Transparency = 0.3
				TweenService:Create(ring, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Size = Vector3.new(0.1, 26, 26), Transparency = 1 }):Play()
				task.delay(1.3, function()
					ring:Destroy()
				end)
			end)
		end
	elseif style == "ribbons" then
		for i = 0, 2 do
			local a = i * math.pi * 2 / 3
			local r = fxPart("AuroraRibbon", Vector3.new(0.3, 6, 1.6), CFrame.new(pos + Vector3.new(math.cos(a) * 2, 0, math.sin(a) * 2)) * CFrame.Angles(0, a, 0), color)
			r.Transparency = 0.25
			TweenService:Create(r, TweenInfo.new(2.2, Enum.EasingStyle.Sine), { CFrame = CFrame.new(pos + Vector3.new(math.cos(a + 3) * 5, 22, math.sin(a + 3) * 5)) * CFrame.Angles(0, a + 3, 0.6), Transparency = 1 }):Play()
			task.delay(2.3, function()
				r:Destroy()
			end)
		end
	end
	task.delay(3, function()
		anchor:Destroy()
	end)
end


return Finishers

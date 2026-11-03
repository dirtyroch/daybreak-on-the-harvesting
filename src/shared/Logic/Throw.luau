--!strict
--[[
	Spear throw path, as pure 2D-in-XZ math, plus the Veil bounce used by the Veil Breaker finale.
	The server walks the path in short segments: if a segment leaves the Veil circle, the spear
	reflects off the wall (once per `bounces`) and continues with whatever range is left.
]]
local Throw = {}

export type V = { x: number, z: number }
export type Leg = { from: V, to: V, bounced: boolean }

local function len(v: V): number
	return math.sqrt(v.x * v.x + v.z * v.z)
end

-- Where does the ray from `p` along unit `d` cross the circle of radius `r` (center origin)?
-- Assumes p is inside. Returns distance along the ray.
function Throw.exitDistance(p: V, d: V, r: number): number
	local b = p.x * d.x + p.z * d.z
	local c = p.x * p.x + p.z * p.z - r * r
	local disc = b * b - c
	if disc < 0 then
		return 0
	end
	return -b + math.sqrt(disc)
end

-- Split a throw into legs, bouncing off the Veil up to `bounces` times.
function Throw.legs(from: V, dir: V, range: number, radius: number, bounces: number): { Leg }
	local out: { Leg } = {}
	local l = len(dir)
	if l < 1e-6 or range <= 0 then
		return out
	end
	local d = { x = dir.x / l, z = dir.z / l }
	local p = { x = from.x, z = from.z }
	local left = range
	local bounced = false
	local n = 0
	while left > 0.01 do
		local inside = len(p) < radius
		local hitAt = if inside then Throw.exitDistance(p, d, radius) else math.huge
		if inside and hitAt < left and n < bounces then
			local q = { x = p.x + d.x * hitAt, z = p.z + d.z * hitAt }
			table.insert(out, { from = p, to = q, bounced = bounced })
			-- reflect around the wall normal (pointing outward)
			local nl = len(q)
			local nx, nz = q.x / nl, q.z / nl
			local dot = d.x * nx + d.z * nz
			d = { x = d.x - 2 * dot * nx, z = d.z - 2 * dot * nz }
			p = { x = q.x - nx * 0.5, z = q.z - nz * 0.5 }
			left -= hitAt
			bounced = true
			n += 1
		else
			local q = { x = p.x + d.x * left, z = p.z + d.z * left }
			table.insert(out, { from = p, to = q, bounced = bounced })
			left = 0
		end
	end
	return out
end

-- Distance from point c to segment ab (XZ).
function Throw.segDist(a: V, b: V, c: V): number
	local abx, abz = b.x - a.x, b.z - a.z
	local L = abx * abx + abz * abz
	local t = 0
	if L > 0 then
		t = math.clamp(((c.x - a.x) * abx + (c.z - a.z) * abz) / L, 0, 1)
	end
	local px, pz = a.x + abx * t - c.x, a.z + abz * t - c.z
	return math.sqrt(px * px + pz * pz)
end

return Throw

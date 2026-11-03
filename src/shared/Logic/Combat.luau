--!strict
-- Pure combat helpers the server uses to validate every hit. The client only sends intent.
local Combat = {}

export type V3 = { x: number, y: number, z: number }

function Combat.dist(a: V3, b: V3): number
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Is `target` inside a melee arc of `arcDeg` in front of `from` facing `look` (flat, XZ)?
function Combat.inArc(from: V3, look: V3, target: V3, arcDeg: number): boolean
	local dx, dz = target.x - from.x, target.z - from.z
	local d = math.sqrt(dx * dx + dz * dz)
	if d < 0.5 then
		return true
	end
	local ll = math.sqrt(look.x * look.x + look.z * look.z)
	if ll < 1e-6 then
		return false
	end
	local cos = (dx * look.x + dz * look.z) / (d * ll)
	return cos >= math.cos(math.rad(arcDeg / 2))
end

-- Partners from the same Reach cannot hurt each other until `alliesUntil` remain.
function Combat.canHurt(aReach: string, bReach: string, alive: number, alliesUntil: number): boolean
	if aReach == bReach and alive > alliesUntil then
		return false
	end
	return true
end

-- Bow damage falls off a little past half range so close shots matter.
function Combat.bowDamage(base: number, distance: number, range: number): number
	if distance > range then
		return 0
	end
	if distance <= range / 2 then
		return base
	end
	local a = (distance - range / 2) / (range / 2)
	return math.floor(base * (1 - 0.3 * a) + 0.5)
end

-- Apply damage to Pep. Returns new pep and whether this hit knocked them out.
function Combat.hit(pep: number, damage: number): (number, boolean)
	local n = math.max(0, pep - damage)
	return n, n <= 0 and pep > 0
end

-- Placement: if N are alive and one is knocked, they finish in place N.
function Combat.placeOnKnock(aliveBefore: number): number
	return aliveBefore
end

-- Can the client's claimed cooldown be honoured? (server keeps its own clock)
function Combat.ready(lastUse: number?, now: number, cooldown: number): boolean
	return lastUse == nil or now - lastUse >= cooldown * 0.9
end

return Combat

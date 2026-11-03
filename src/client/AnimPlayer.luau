--!strict
--[[
	AnimPlayer: plays the code-made keyframe clips in Shared/Anim.luau on any R15 model by
	writing Motor6D.Transform every frame (RunService.Stepped, after the default Animator has
	written its pose, so ours wins for the joints a clip uses). Transform doesn't replicate, so
	every client plays every emote and statue pose itself from the server's pushes and tags.

	Studio check (PUBLISHING.md 6i): if a joint looks frozen on your own character, move the
	write to RunService.PreSimulation; the default Animate script timing varies by version.
]]
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Anim = require(Shared.Anim)
local Arms = require(Shared.Arms) :: any

local AnimPlayer = {}

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

type Active = { clip: any, t0: number, joints: { [string]: Motor6D }, prop: Model?, repeatEvery: number?, untilT: number? }
local active: { [Model]: Active } = {}

local function jointsOf(m: Model): { [string]: Motor6D }
	local out = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Motor6D") and Anim.JOINT_SET[d.Name] then
			out[d.Name] = d
		end
	end
	return out
end

local function resetJoints(a: Active)
	for _, j in pairs(a.joints) do
		j.Transform = CFrame.identity
	end
end

function AnimPlayer.stop(m: Model)
	local a = active[m]
	if a then
		resetJoints(a)
		if a.prop then
			a.prop:Destroy()
		end
		active[m] = nil
	end
end

-- Play a clip on a model. opts.repeatEvery restarts it (statues), opts.seconds stops a held pose.
function AnimPlayer.play(m: Model, clipId: string, opts: { repeatEvery: number?, seconds: number? }?): boolean
	local clip = (Anim.CLIPS :: any)[clipId]
	if not clip then
		return false
	end
	AnimPlayer.stop(m)
	local a: Active = { clip = clip, t0 = os.clock(), joints = jointsOf(m), repeatEvery = opts and opts.repeatEvery, untilT = opts and opts.seconds and (os.clock() + opts.seconds) or nil }
	if clip.prop and (Anim.PROPS :: any)[clip.prop] then
		local hand = m:FindFirstChild(clip.propJoint or "RightHand", true) :: BasePart?
		if hand then
			local spec = { id = "prop_" .. clip.prop, slot = "prop", name = clip.prop, parts = (Anim.PROPS :: any)[clip.prop], fx = {} }
			local pm = Arms.build(E, spec, hand.CFrame)
			pm.Name = "AnimProp"
			local w = Instance.new("WeldConstraint")
			w.Part0 = hand
			w.Part1 = pm.PrimaryPart
			w.Parent = pm.PrimaryPart
			pm.Parent = m
			a.prop = pm
		end
	end
	active[m] = a
	return true
end

function AnimPlayer.isPlaying(m: Model): boolean
	return active[m] ~= nil
end

local function step()
	local now = os.clock()
	for m, a in pairs(active) do
		if not m.Parent then
			active[m] = nil
			continue
		end
		local t = now - a.t0
		if a.repeatEvery and t > math.max(a.repeatEvery, a.clip.length) then
			a.t0 = now
			t = 0
		end
		local pose = Anim.sample(a.clip, t)
		for name, r in pairs(pose) do
			local j = a.joints[name]
			if j then
				j.Transform = CFrame.Angles(math.rad(r[1]), math.rad(r[2]), math.rad(r[3]))
			end
		end
		local done = (not a.clip.loop and not a.clip.hold and not a.repeatEvery and t >= a.clip.length) or (a.untilT ~= nil and now >= a.untilT)
		if done then
			AnimPlayer.stop(m)
		end
	end
end

local function onTagged(inst: Instance)
	if inst:IsA("Model") then
		local clip = inst:GetAttribute("Clip")
		local rep = inst:GetAttribute("Repeat")
		if type(clip) == "string" then
			-- let the rig finish streaming in
			task.delay(0.5, function()
				if inst.Parent then
					AnimPlayer.play(inst, clip, { repeatEvery = type(rep) == "number" and rep or nil })
				end
			end)
		end
	end
end

function AnimPlayer.start()
	RunService.Stepped:Connect(step)
	CollectionService:GetInstanceAddedSignal("DaybreakPose"):Connect(onTagged)
	CollectionService:GetInstanceRemovedSignal("DaybreakPose"):Connect(function(inst: Instance)
		if inst:IsA("Model") then
			AnimPlayer.stop(inst)
		end
	end)
	for _, inst in ipairs(CollectionService:GetTagged("DaybreakPose")) do
		onTagged(inst)
	end
end

return AnimPlayer

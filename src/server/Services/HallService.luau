--!strict
--[[
	HallService (v4): status you can see.
	  * Victory Podium: after every match the top three stand on the lobby podium as statues in
	    their equipped weapon skin, pose, fade aura and banner. Every player in the server gets
	    a short camera visit ("podiumShow") and the poses play on every client.
	  * Hall of Champions: this week's top five winners (OrderedDataStore, across servers) stand
	    on plinths in the lobby in their saved loadout. Falls back to this server's recent
	    winners if DataStores are unavailable (Studio without API access).
	Statues are plain models: only the HumanoidRootPart is anchored so the Motor6Ds can pose.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Content = require(Shared.Content)
local Store = require(Shared.Store)
local Anim = require(Shared.Anim)
local Mastery = require(Shared.Mastery)
local TimeUtil = require(Shared.Logic.TimeUtil)
local Arms = require(Shared.Arms) :: any

local HallService = {}
local ctx: any = nil

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

HallService.TAG = "DaybreakPose"
HallService.HALL_SIZE = 5
HallService.REFRESH = 300

export type Loadout = { userId: number, name: string, pose: string, weapon: string, skin: string, mastery: number, fade: string, banner: string, title: string, wins: number? }

local recent: { Loadout } = {} -- this server's winners, newest first (fallback)
local winsStore: OrderedDataStore? = nil
local loadoutStore: DataStore? = nil

local function lobby(): Instance?
	local map = workspace:FindFirstChild("Map")
	return map and map:FindFirstChild("Lobby")
end

-- The loadout a player shows off: equipped pose, their best-mastered weapon skin, fade, banner.
function HallService.loadoutOf(player: Player): Loadout?
	local data = ctx.Progress.dataOf(player)
	if not data then
		return nil
	end
	local eq = data.equipped or {}
	local best, bestPts = "bow", -1
	for _, slot in ipairs(Mastery.SLOTS) do
		local pts = (data.mastery or {})[Mastery.key(slot, eq[slot])] or 0
		if pts > bestPts or (pts == bestPts and (eq[slot] or "") ~= "" and (eq[best] or "") == "") then
			best, bestPts = slot, pts
		end
	end
	return {
		userId = player.UserId,
		name = player.DisplayName,
		pose = (eq.pose ~= nil and eq.pose ~= "") and eq.pose or Anim.DEFAULT_POSE,
		weapon = best,
		skin = eq[best] or "",
		mastery = Mastery.level(math.max(bestPts, 0)),
		fade = eq.fade or "fade_gold",
		banner = eq.banner or "",
		title = eq.title or "",
	}
end

local function rig(userId: number, name: string): Model?
	if userId > 0 then
		local ok, m = pcall(function()
			return Players:CreateHumanoidModelFromUserId(userId)
		end)
		if ok and m then
			return m
		end
	end
	local standIn = ctx.Look and ctx.Look.standIn(name, Random.new(#name * 7919))
	return standIn
end

-- Builds a posed statue standing on `spot`.
function HallService.statue(l: Loadout, spot: BasePart, parent: Instance, label: string?): Model?
	local m = rig(l.userId, l.name)
	if not m then
		return nil
	end
	m.Name = "Statue_" .. l.name
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.PlatformStand = true
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.Anchored = d.Name == "HumanoidRootPart"
		end
	end
	local hrp = m:FindFirstChild("HumanoidRootPart") :: BasePart?
	local height = hum and (hum.HipHeight + (hrp and hrp.Size.Y / 2 or 1)) or 3
	m:PivotTo(spot.CFrame * CFrame.new(0, height, 0))
	Arms.attach(E, m, l.weapon, l.skin, l.mastery)
	-- fade aura: a soft column of the fade's particles around the plinth
	local f = Content.FADES[l.fade] or Content.FADES.fade_gold
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "FadeAura"
	aura.Color = ColorSequence.new(Color3.fromHex(f.color))
	aura.LightEmission = 1
	aura.Rate = 5
	aura.Lifetime = NumberRange.new(1.5, 2.5)
	aura.Speed = NumberRange.new(1, 2)
	aura.Size = NumberSequence.new(0.3, 0)
	aura.SpreadAngle = Vector2.new(30, 30)
	aura.Acceleration = Vector3.new(0, 2, 0)
	aura.Parent = spot
	-- name card with banner, title and mastery star
	local bb = Instance.new("BillboardGui")
	bb.Name = "Card"
	bb.Size = UDim2.new(0, 220, 0, 54)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.MaxDistance = 140
	bb.AlwaysOnTop = false
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextColor3 = Color3.fromHex("#FFE9A8")
	t.TextStrokeTransparency = 0.4
	local banner = Store.byId[l.banner]
	local title = Content.TITLES and Content.TITLES[l.title]
	local stars = l.mastery >= Mastery.MAX and " ✦" or ""
	t.Text = (label and (label .. "  ") or "") .. l.name .. stars .. "\n" .. (title or (banner and banner.name) or f.name)
	t.Parent = bb
	bb.Parent = hrp or m
	m:SetAttribute("Clip", Anim.CLIPS[l.pose] and l.pose or Anim.DEFAULT_POSE)
	m:SetAttribute("Repeat", 9) -- statues re-strike their pose every 9 s
	m.Parent = parent
	CollectionService:AddTag(m, HallService.TAG)
	return m
end

local function clearSpots(folder: Instance)
	for _, d in ipairs(folder:GetChildren()) do
		if d:IsA("Model") and d.Name:sub(1, 7) == "Statue_" then
			d:Destroy()
		end
		local aura = d:FindFirstChild("FadeAura")
		if aura then
			aura:Destroy()
		end
	end
end

-- ===== Victory Podium =====
export type PodiumEntry = { place: number, loadout: Loadout }
function HallService.podium(entries: { PodiumEntry })
	local lb = lobby()
	local vp = lb and lb:FindFirstChild("VictoryPodium")
	if not vp then
		return
	end
	task.spawn(function()
		clearSpots(vp)
		local show = {}
		for _, e in ipairs(entries) do
			local spot = vp:FindFirstChild("Spot" .. e.place) :: BasePart?
			if spot then
				local m = HallService.statue(e.loadout, spot, vp, ({ "🥇", "🥈", "🥉" })[e.place])
				if m then
					table.insert(show, { place = e.place, name = e.loadout.name, clip = m:GetAttribute("Clip"), model = m, skin = e.loadout.skin, fade = e.loadout.fade })
				end
			end
		end
		local cam = vp:FindFirstChild("CameraMark") :: BasePart?
		ctx.pushAll("podiumShow", { entries = show, camera = cam and cam.CFrame or nil, seconds = 6 })
	end)
end

-- ===== Hall of Champions =====
local function weekKey(): string
	return tostring(TimeUtil.week(os.time()))
end

function HallService.recordWin(player: Player)
	local l = HallService.loadoutOf(player)
	if not l then
		return
	end
	-- local fallback list
	for i = #recent, 1, -1 do
		if recent[i].userId == l.userId then
			table.remove(recent, i)
		end
	end
	table.insert(recent, 1, l)
	while #recent > HallService.HALL_SIZE do
		table.remove(recent)
	end
	task.spawn(function()
		if winsStore then
			pcall(function()
				(winsStore :: OrderedDataStore):IncrementAsync(tostring(l.userId), 1)
			end)
		end
		if loadoutStore then
			pcall(function()
				(loadoutStore :: DataStore):SetAsync(tostring(l.userId), l)
			end)
		end
	end)
end

-- Top winners this week with their saved loadouts; falls back to this server's winners.
function HallService.top(): { Loadout }
	local out: { Loadout } = {}
	if winsStore and loadoutStore then
		local ok, page = pcall(function()
			return (winsStore :: OrderedDataStore):GetSortedAsync(false, HallService.HALL_SIZE):GetCurrentPage()
		end)
		if ok and page then
			for _, row in ipairs(page) do
				local okL, l = pcall(function()
					return (loadoutStore :: DataStore):GetAsync(row.key)
				end)
				if okL and type(l) == "table" then
					l.wins = row.value
					table.insert(out, l)
				end
			end
		end
	end
	if #out == 0 then
		for _, l in ipairs(recent) do
			table.insert(out, l)
		end
	end
	return out
end

function HallService.refresh()
	local lb = lobby()
	local hall = lb and lb:FindFirstChild("HallOfChampions")
	if not hall then
		return
	end
	local top = HallService.top()
	clearSpots(hall)
	for k = 1, 5 do
		local spot = hall:FindFirstChild("HallSpot" .. k) :: BasePart?
		local rank: number = spot and tonumber(spot:GetAttribute("Rank")) or 0
		local l = top[rank]
		if spot and l then
			HallService.statue(l, spot, hall, l.wins and ("#" .. rank .. " · " .. tostring(l.wins) .. " wins") or ("#" .. rank))
		end
	end
end

function HallService.init(c: any)
	ctx = c
	local ok = pcall(function()
		winsStore = DataStoreService:GetOrderedDataStore("HallWins_" .. weekKey())
		loadoutStore = DataStoreService:GetDataStore("HallLoadout")
	end)
	if not ok then
		winsStore, loadoutStore = nil, nil
	end
end

function HallService.start()
	task.spawn(function()
		while true do
			pcall(HallService.refresh)
			task.wait(HallService.REFRESH)
			-- roll over to the new week's board on Monday
			pcall(function()
				winsStore = DataStoreService:GetOrderedDataStore("HallWins_" .. weekKey())
			end)
		end
	end)
end

return HallService

--!strict
-- Server entry point: builds the map (if it wasn't baked), remotes, wires services, starts them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Names = require(Shared.Names)
local Content = require(Shared.Content)
local MapBuilder = require(Shared.MapBuilder) :: any
local RateLimiter = require(Shared.Logic.RateLimiter)

local Services = script.Parent:WaitForChild("Services")

if not workspace:FindFirstChild("Map") then
	MapBuilder.build({
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
	}, workspace, Config, Names, Content)
end

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local action = Instance.new("RemoteFunction")
action.Name = "Action"
action.Parent = remotes
local push = Instance.new("RemoteEvent")
push.Name = "Push"
push.Parent = remotes
remotes.Parent = ReplicatedStorage

Players.CharacterAutoLoads = true

local ctx: any = {
	Data = require(Services.DataService),
	Progress = require(Services.ProgressService),
	Match = require(Services.MatchService),
	Bots = require(Services.BotService),
	Gallery = require(Services.GalleryService),
	Purchase = require(Services.PurchaseService),
	Look = require(Services.LookService),
	Remotes = { Action = action, Push = push },
}

function ctx.push(player: Player, kind: string, payload: any)
	push:FireClient(player, kind, payload)
end
function ctx.pushAll(kind: string, payload: any)
	push:FireAllClients(kind, payload)
end
function ctx.toast(player: Player, text: string, kind: string?)
	push:FireClient(player, "toast", { text = text, kind = kind or "info" })
end

-- One RemoteFunction for every intent, rate-limited per player and per action.
local globalLimiter = RateLimiter.new(30, 15)
local actionLimiter = RateLimiter.new(8, 5)
local handlers: { [string]: (Player, any, any, any) -> (boolean, string?) } = {}
function ctx.handle(name: string, fn: (Player, any, any, any) -> (boolean, string?))
	handlers[name] = fn
end

for _, name in ipairs({ "Progress", "Bots", "Match", "Gallery", "Purchase" }) do
	local svc = ctx[name]
	if svc.init then
		svc.init(ctx)
	end
end

action.OnServerInvoke = function(player: Player, name: any, a: any, b: any, c: any)
	if type(name) ~= "string" then
		return { ok = false }
	end
	local now = os.clock()
	if not RateLimiter.allow(globalLimiter, player, now) or not RateLimiter.allow(actionLimiter, tostring(player.UserId) .. name, now) then
		return { ok = false, msg = "Slow down a little!" }
	end
	local fn = handlers[name]
	if not fn then
		return { ok = false }
	end
	local ok, res, msg = pcall(fn, player, a, b, c)
	if not ok then
		warn("[Action " .. name .. "] " .. tostring(res))
		return { ok = false, msg = "Something went wrong." }
	end
	return { ok = res == true, msg = msg }
end

Players.PlayerRemoving:Connect(function(p)
	RateLimiter.forget(globalLimiter, p)
end)

ctx.Data.start()
for _, name in ipairs({ "Look", "Progress", "Bots", "Gallery", "Purchase", "Match" }) do
	local svc = ctx[name]
	if svc.start then
		svc.start()
	end
end
print("[" .. Names.TITLE .. "] server ready · " .. Config.VERSION)

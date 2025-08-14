--!strict
local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")


local SpawnQueue = require(ServerScriptService.Modules.SpawnQueue)

export type TimersConfig = {
	legendaryIntervalSeconds: number,
	mythicIntervalSeconds: number,
	debug: boolean?,
	channelLegendary: string?,
	channelMythic: string?,
}

local GlobalTimers = {}

local cfg: TimersConfig = {
	legendaryIntervalSeconds = 600,
	mythicIntervalSeconds = 900,
	debug = false,
	channelLegendary = "GLOBAL_LEGENDARY",
	channelMythic = "GLOBAL_MYTHIC",
}

local function setLabel(path: {string}, text: string)
	local node: Instance? = Workspace
	for _, name in ipairs(path) do
		if not node then return end
		node = node:FindFirstChild(name)
	end
	if node and node:IsA("TextLabel") then
		node.Text = text
	end
end

local function fmt(sec: number): string
	if sec < 0 then sec = 0 end
	local m = math.floor(sec / 60)
	local s = math.floor(sec % 60)
	return string.format("%02d:%02d", m, s)
end

local function subscribe(channel: string, onMessage: (data: any) -> ())
	local ok, err = pcall(function()
		MessagingService:SubscribeAsync(channel, function(msg)
			onMessage(msg.Data)
		end)
	end)
	if not ok and cfg.debug then warn("Subscribe failed:", err) end
end

local function publish(channel: string, data: any)
	pcall(function()
		MessagingService:PublishAsync(channel, data)
	end)
end

function GlobalTimers.configure(newCfg: TimersConfig)
	for k, v in newCfg do
		(cfg :: any)[k] = v
	end
end

function GlobalTimers.start()
	local nextLegendary: number? = nil
	local nextMythic: number? = nil

	subscribe(cfg.channelLegendary :: string, function(serverTime: number)
		nextLegendary = serverTime
	end)
	subscribe(cfg.channelMythic :: string, function(serverTime: number)
		nextMythic = serverTime
	end)

	task.spawn(function()
		RunService.Heartbeat:Wait()
		if not nextLegendary then
			local t = os.time() + cfg.legendaryIntervalSeconds
			nextLegendary = t
			publish(cfg.channelLegendary :: string, t)
		end
		if not nextMythic then
			local t2 = os.time() + cfg.mythicIntervalSeconds
			nextMythic = t2
			publish(cfg.channelMythic :: string, t2)
		end
	end)

	task.spawn(function()
		while true do
			RunService.Heartbeat:Wait()
			local now = os.time()
			if nextLegendary then
				local remain = nextLegendary - now
				setLabel({"LegendaryTimer","SurfaceGui","Timer"}, fmt(remain))
				if remain <= 0 then
					SpawnQueue.enqueueForced("Legendary")
					nextLegendary = now + cfg.legendaryIntervalSeconds
					publish(cfg.channelLegendary :: string, nextLegendary)
				end
			end
			if nextMythic then
				local remain2 = nextMythic - now
				setLabel({"MythicTimer","SurfaceGui","Timer"}, fmt(remain2))
				if remain2 <= 0 then
					SpawnQueue.enqueueForced("Mythic")
					nextMythic = now + cfg.mythicIntervalSeconds
					publish(cfg.channelMythic :: string, nextMythic)
				end
			end
		end
	end)
end

return GlobalTimers

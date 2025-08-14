--!strict
local RunService = game:GetService("RunService")

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type Callbacks = {
	getIntervalSeconds: () -> number,
	spawnWeighted: () -> (),
	spawnForced: (rarity: Rarity) -> (),
	debug: boolean?,
	debugTag: string?,
}

local SpawnQueue = {}

local forcedQueue: {Rarity} = {}
local running = false
local thread: thread? = nil
local cb: Callbacks? = nil

function SpawnQueue.enqueueForced(rarity: Rarity)
	table.insert(forcedQueue, rarity)
end

function SpawnQueue.start(callbacks: Callbacks)
	if running then return end
	running = true
	cb = callbacks
	thread = task.spawn(function()
		local getInterval = callbacks.getIntervalSeconds
		local debug = callbacks.debug
		local tag = callbacks.debugTag or "SpawnQueue"
		local nextAt = os.clock()
		while running do
			local now = os.clock()
			if now >= nextAt then
				local rarity = table.remove(forcedQueue, 1)
				if rarity then
					callbacks.spawnForced(rarity)
				else
					callbacks.spawnWeighted()
				end
				if debug then
					local lag = now - nextAt
					if math.abs(lag) > 0.02 then
						print(string.format("[%s] drift=%.3fs", tag, lag))
					end
				end
				nextAt = now + math.max(0.05, getInterval())
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

function SpawnQueue.stop()
	running = false
	thread = nil
end

return SpawnQueue

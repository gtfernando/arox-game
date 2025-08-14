--!strict
export type Rarity = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type Callbacks = {
    getIntervalSeconds: () -> number,
    spawnWeighted: () -> (),
    spawnForced: (rarity: Rarity) -> (),
    debug: boolean?,
    debugTag: string?,
}

local SpawnQueue = {}
local running = false
local forcedQueue: {Rarity} = {}

function SpawnQueue.enqueueForced(rarity: Rarity)
    table.insert(forcedQueue, rarity)
end

local function run(getIntervalSeconds: () -> number, spawnWeighted: () -> (), spawnForced: (rarity: Rarity) -> (), debugTag: string?, debug: boolean?)
    if running then return end
    running = true
    task.spawn(function()
        local interval = math.max(0.01, getIntervalSeconds())
        local nextAt = os.clock() + interval
        while running do
            local now = os.clock()
            if now >= nextAt then
                local lateness = now - nextAt
                local forced = table.remove(forcedQueue, 1)
                local ok, err
                if forced then
                    ok, err = pcall(spawnForced, forced)
                else
                    ok, err = pcall(spawnWeighted)
                end
                if debug then
                    print(("[%s] tick lateness=%.3fs queue=%d ok=%s"):format(debugTag or "Queue", lateness, #forcedQueue, tostring(ok)))
                    if not ok and err then
                        warn(("[%s] spawn error: %s"):format(debugTag or "Queue", tostring(err)))
                    end
                end
                interval = math.max(0.01, getIntervalSeconds())
                nextAt = now + interval
            end
            task.wait(0.02)
        end
    end)
end

function SpawnQueue.start(a: any, b: any, c: any, d: any, e: any)
    if typeof(a) == "table" then
        local cb = a :: Callbacks
        return run(cb.getIntervalSeconds, cb.spawnWeighted, cb.spawnForced, cb.debugTag, cb.debug)
    else
        return run(a :: () -> number, b :: () -> (), c :: (rarity: Rarity) -> (), d :: string?, e :: boolean?)
    end
end

function SpawnQueue.stop()
    running = false
    table.clear(forcedQueue)
end

return SpawnQueue
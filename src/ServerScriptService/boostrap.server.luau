
math.randomseed(os.time())

local SSS = game:GetService("ServerScriptService")
local Modules = SSS:WaitForChild("Modules")
local Spawner = require(Modules:WaitForChild("Spawner"))
local GlobalTimers = require(Modules:WaitForChild("GlobalTimers"))

Spawner:Start()
GlobalTimers.configure({
	legendaryIntervalSeconds = 10,
	mythicIntervalSeconds = 20,
	debug = false,
})
GlobalTimers.start()

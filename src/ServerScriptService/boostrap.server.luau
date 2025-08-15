math.randomseed(os.time())

local SSS = game:GetService("ServerScriptService")
local Modules = SSS:WaitForChild("Modules")
local Spawner = require(Modules:WaitForChild("Spawner"))
local GlobalTimers = require(Modules:WaitForChild("GlobalTimers"))
local Warmup = require(Modules:WaitForChild("Warmup"))


-- TODO remove this later, just for test NOTE: (BaseNumber -> IMPORTANT ATTRIBUTE ON PLAYER)
game.Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("BaseNumber", math.random(1, 8))
end)

Warmup.run()
Spawner:Start()
GlobalTimers.configure({
	legendaryIntervalSeconds = 120,
	mythicIntervalSeconds = 200,
	debug = false,
})
GlobalTimers.start()
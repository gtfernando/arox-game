
math.randomseed(os.time())

local SSS = game:GetService("ServerScriptService")
local Modules = SSS:WaitForChild("Modules")
local Spawner = require(Modules:WaitForChild("Spawner"))
local GlobalTimers = require(Modules:WaitForChild("GlobalTimers"))

game.Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("BaseNumber", 4)
end)

Spawner:Start()
GlobalTimers.configure({
	legendaryIntervalSeconds = 120,
	mythicIntervalSeconds = 200,
	debug = false,
})
GlobalTimers.start()

-- test func remove later
--!strict
-- Server bootstrap: starts the NPC spawner

math.randomseed(os.time())

local SSS = game:GetService("ServerScriptService")
local Modules = SSS:WaitForChild("Modules")
local Spawner = require(Modules:WaitForChild("Spawner"))

Spawner:Start()

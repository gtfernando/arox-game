--!strict

local PathfindingService = game:GetService("PathfindingService")
local Debris = game:GetService("Debris")

local Warmup = {}

function Warmup.run()
	pcall(function()
		local p = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = false, WaypointSpacing = 2})
		p:ComputeAsync(Vector3.new(0, 0, 0), Vector3.new(1, 0, 1))
		p:GetWaypoints()
	end)

	pcall(function()
		local f = Instance.new("Folder")
		f.Name = "_warmup"
		Debris:AddItem(f, 0)
	end)
end

return Warmup

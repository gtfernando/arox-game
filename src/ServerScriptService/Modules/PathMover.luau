--!strict
-- PathMover: moves a Humanoid from A to B with PathfindingService

local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

export type PathSettings = {
	agentRadius: number?,
	agentHeight: number?,
	walkSpeed: number?,
}

local PathMover = {}

local function buildPath(agentParams: PathSettings): Path
	local p = PathfindingService:CreatePath({
		AgentRadius = agentParams.agentRadius or 2,
		AgentHeight = agentParams.agentHeight or 5,
		AgentCanJump = false,
		WaypointSpacing = 2,
	})
	return p
end

local function moveTo(humanoid: Humanoid, point: Vector3)
	-- Use MoveTo for consistent velocity; humanoid will follow
	humanoid:MoveTo(point)
end

function PathMover.go(model: Model, destination: Vector3, agentParams: PathSettings, onArrived: (() -> ())?)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp or not hrp:IsA("BasePart") then
		return
	end
	local function followPath()
		local try = 0
		while try < 3 do
			try += 1
			local path = buildPath(agentParams)
			path:ComputeAsync(hrp.Position, destination)
			if path.Status ~= Enum.PathStatus.Success then
				-- brief yield and retry; then fallback
				task.wait(0.05)
			else
				local waypoints = path:GetWaypoints()
				for i = 1, #waypoints do
					local wp = waypoints[i]
					moveTo(humanoid, wp.Position)
					local reached = false
					local conn
					conn = humanoid.MoveToFinished:Connect(function(ok)
						reached = true
						if conn then conn:Disconnect() end
					end)
					local dist = (hrp.Position - wp.Position).Magnitude
					local speed = agentParams.walkSpeed or humanoid.WalkSpeed
					local timeout = math.max(2, math.min(8, (dist / math.max(2, speed)) * 2))
					local start = os.clock()
					while not reached and os.clock() - start < timeout do
						RunService.Heartbeat:Wait()
					end
					if not reached then
						-- blocked; recompute outer loop
						break
					end
					if (hrp.Position - destination).Magnitude <= 6 then
						if onArrived then onArrived() end
						return
					end
				end
				-- If close enough to destination, finish
				if (hrp.Position - destination).Magnitude <= 8 then
					if onArrived then onArrived() end
					return
				end
			end
		end
		-- Fallback: direct move toward destination; let watcher handle cleanup
		moveTo(humanoid, destination)
	end

	followPath()
end

return PathMover

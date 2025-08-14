--!strict
-- Spawner: interval-based NPC spawns that path from Workspace.Flw.Spawn to Workspace.Flw.Ends
-- Pure ModuleScript API: Start() / Stop()

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local RarityConfig = require(script.Parent:WaitForChild("RarityConfig"))
local CharacterSelector = require(script.Parent:WaitForChild("CharacterSelector"))
local CollisionSetup = require(script.Parent:WaitForChild("CollisionSetup"))
local PathMover = require(script.Parent:WaitForChild("PathMover"))
local Animator = require(script.Parent:WaitForChild("Animator"))

export type Handle = {
	Start: (self: Handle) -> (),
	Stop: (self: Handle) -> (),
}

local running = false
local loopThread: thread? = nil
-- spacing is controlled by time-based scheduling derived from desiredGapStuds/walkSpeed

local function findPoints(): (BasePart?, BasePart?)
	local flw = Workspace:FindFirstChild("Flw")
	if not flw then return nil, nil end
	local spawnPart = flw:FindFirstChild("Spawn")
	local endsPart = flw:FindFirstChild("Ends")
	if spawnPart and endsPart and spawnPart:IsA("BasePart") and endsPart:IsA("BasePart") then
		return spawnPart, endsPart
	end
	return nil, nil
end

local function computeSpawnCFrame(spawnPart: BasePart, defaultRig: Model?): CFrame
	local defaultHRP = if defaultRig then defaultRig:FindFirstChild("HumanoidRootPart") else nil
	if defaultHRP and defaultHRP:IsA("BasePart") then
		-- Place model matching DefaultRig's offset relative to Spawn
		local offset = spawnPart.CFrame:ToObjectSpace(defaultHRP.CFrame)
		return spawnPart.CFrame * offset
	end
	return spawnPart.CFrame + Vector3.new(0, 3, 0)
end

local function prepareCharacter(model: Model, walkSpeed: number)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	-- Ensure PrimaryPart is HRP for consistent pivot/move
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		pcall(function()
			model.PrimaryPart = hrp
		end)
	end
	-- movement tuning
	humanoid:ChangeState(Enum.HumanoidStateType.Running)
	humanoid.WalkSpeed = walkSpeed
	humanoid.AutoRotate = true
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
	Animator.apply(model)
end

local function setNetworkOwnerServer(model: Model)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		pcall(function()
			hrp:SetNetworkOwner(nil)
		end)
	end
end

local function spawnOne(spawnPart: BasePart, endsPart: BasePart)
	local settings = RarityConfig.getSettings()
	local weights = RarityConfig.getWeights()
	local t0 = os.clock()
	local model = CharacterSelector.pick(weights)
	if not model then return end
	model.Name = model.Name -- keep original name for AnimationOverrides key
	
	-- Ensure HRP exists
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		model:Destroy()
		return
	end

	-- Collision + physics setup first
	CollisionSetup.assign(model)

	-- Parent to Workspace under a dedicated folder for clarity
	local container = Workspace:FindFirstChild("NPCs")
	if not container then
		container = Instance.new("Folder")
		container.Name = "NPCs"
		container.Parent = Workspace
	end
	model.Parent = container

	-- Position at spawn using DefaultRig offset if available
	local defaultRig = CharacterSelector.getDefaultRig()
	local spawnCF = computeSpawnCFrame(spawnPart, defaultRig)
	-- Face toward the destination for immediate forward motion
	spawnCF = CFrame.new(spawnCF.Position, endsPart.Position)
	model:PivotTo(spawnCF)

	-- Server owns physics for stability
	setNetworkOwnerServer(model)

	-- Walk settings and animations
	prepareCharacter(model, settings.walkSpeed)

	-- Start path move; cleanup on arrival
	local destroyRequested = false
	local function cleanup()
		if destroyRequested then return end
		destroyRequested = true
		if model and model.Parent then
			model:Destroy()
		end
	end

	-- Also guard with distance check in case of direct move fallback
	task.spawn(function()
		local arrival = settings.arrivalDestroyDistance or 6
		while model.Parent do
			local root = model:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				if (root.Position - endsPart.Position).Magnitude <= arrival then
					cleanup()
					break
				end
			else
				break
			end
			task.wait(0.1)
		end
	end)

	task.spawn(function()
		local useDirect = settings.useDirectMove == true
		if useDirect then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:MoveTo(endsPart.Position)
				-- Cleanup handled by distance watcher to avoid mid-path despawn
			else
				cleanup()
			end
		else
			PathMover.go(model, endsPart.Position, {
				agentRadius = settings.pathAgentRadius,
				agentHeight = settings.pathAgentHeight,
				walkSpeed = settings.walkSpeed,
			}, cleanup)
		end
	end)

	-- No per-NPC spacing tracking; cadence is time-driven
	if settings.debug then
		print(string.format("[%s] Spawned %s in %.3fs", settings.debugTag or "Spawner", model.Name, os.clock() - t0))
	end
end

local Spawner: Handle = {} :: any

function Spawner:Start()
	if running then return end
	running = true
	CollisionSetup.init()
	
	local spawnPart, endsPart = findPoints()
	if not spawnPart or not endsPart then
		warn("Spawner: Missing Workspace.Flw.Spawn or Workspace.Flw.Ends parts.")
		return
	end
	
	local settings = RarityConfig.getSettings()
	loopThread = task.spawn(function()
		local interval = settings.spawnIntervalSeconds
		if settings.desiredGapStuds and settings.walkSpeed > 0 then
			interval = settings.desiredGapStuds / settings.walkSpeed
		end
		interval = math.max(0.05, interval)
		local nextAt = os.clock()
		-- strict time-based cadence; spacing emerges from desiredGapStuds/walkSpeed
		while running do
			local now = os.clock()
			if now >= nextAt then
				task.defer(spawnOne, spawnPart :: BasePart, endsPart :: BasePart)
				if settings.debug then
					local lag = now - nextAt
					if math.abs(lag) > 0.02 then
						print(string.format("[%s] drift=%.3fs", settings.debugTag or "Spawner", lag))
					end
				end
				nextAt = now + interval
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

function Spawner:Stop()
	running = false
	if loopThread then
		-- Let it exit naturally on next tick
		loopThread = nil
	end
end

return Spawner

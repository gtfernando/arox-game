--!strict

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local RarityConfig = require(script.Parent:WaitForChild("RarityConfig"))
local CharacterSelector = require(script.Parent:WaitForChild("CharacterSelector"))
local CollisionSetup = require(script.Parent:WaitForChild("CollisionSetup"))
local PathMover = require(script.Parent:WaitForChild("PathMover"))
local Animator = require(script.Parent:WaitForChild("Animator"))

export type Handle = {
	Start: (self: Handle) -> (),
	Stop: (self: Handle) -> (),
	SpawnForced: (self: Handle, rarity: string) -> (),
}

local running = false
local SpawnQueue = require(script.Parent:WaitForChild("SpawnQueue"))

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

		local offset = spawnPart.CFrame:ToObjectSpace(defaultHRP.CFrame)
		return spawnPart.CFrame * offset
	end
	return spawnPart.CFrame + Vector3.new(0, 3, 0)
end

local function prepareCharacter(model: Model, walkSpeed: number)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		pcall(function()
			model.PrimaryPart = hrp
		end)
	end

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
	
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		model:Destroy()
		return
	end

	CollisionSetup.ApplyToNPC(model)

	local container = Workspace:FindFirstChild("NPCs")
	if not container then
		container = Instance.new("Folder")
		container.Name = "NPCs"
		container.Parent = Workspace
	end
	model.Parent = container

	pcall(function()
		model.PrimaryPart = hrp
	end)

	local defaultRig = CharacterSelector.getDefaultRig()
	local spawnCF = computeSpawnCFrame(spawnPart, defaultRig)

	spawnCF = CFrame.new(spawnCF.Position, endsPart.Position)
	model:PivotTo(spawnCF)

	setNetworkOwnerServer(model)

	prepareCharacter(model, settings.walkSpeed)

	local destroyRequested = false
	local function cleanup()
		if destroyRequested then return end
		destroyRequested = true
		if model and model.Parent then
			model:Destroy()
		end
	end

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

	if settings.debug then
		print(string.format("[%s] Spawned %s in %.3fs", settings.debugTag or "Spawner", model.Name, os.clock() - t0))
	end
end

local Spawner: Handle = {} :: any

function Spawner:Start()
	if running then return end
	running = true
	CollisionSetup.Init()
	
	local spawnPart, endsPart = findPoints()
	if not spawnPart or not endsPart then
		warn("Spawner: Missing Workspace.Flw.Spawn or Workspace.Flw.Ends parts.")
		return
	end
	
	local settings = RarityConfig.getSettings()
	SpawnQueue.start({
		getIntervalSeconds = function()
			if settings.desiredGapStuds and settings.walkSpeed > 0 then
				return settings.desiredGapStuds / settings.walkSpeed
			end
			return settings.spawnIntervalSeconds
		end,
		spawnWeighted = function()
			spawnOne(spawnPart :: BasePart, endsPart :: BasePart)
		end,
		spawnForced = function(r)
			self:SpawnForced(r :: any)
		end,
		debug = settings.debug,
		debugTag = settings.debugTag,
	})
end

function Spawner:Stop()
	running = false
	SpawnQueue.stop()
end

function Spawner:SpawnForced(rarity: string)
	local spawnPart, endsPart = findPoints()
	if not spawnPart or not endsPart then return end
	local m = CharacterSelector.pickFromRarity(rarity :: any)
	if not m then return end
	local settings = RarityConfig.getSettings()
	local container = Workspace:FindFirstChild("NPCs")
	if not container then
		container = Instance.new("Folder")
		container.Name = "NPCs"
		container.Parent = Workspace
	end
	local hrp = m:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		m:Destroy()
		return
	end
	CollisionSetup.ApplyToNPC(m)
	m.Parent = container
	pcall(function() m.PrimaryPart = hrp end)
	local defaultRig = CharacterSelector.getDefaultRig()
	local spawnCF = computeSpawnCFrame(spawnPart, defaultRig)
	spawnCF = CFrame.new(spawnCF.Position, endsPart.Position)
	m:PivotTo(spawnCF)
	setNetworkOwnerServer(m)
	prepareCharacter(m, settings.walkSpeed)
	local destroyRequested = false
	local function cleanup()
		if destroyRequested then return end
		destroyRequested = true
		if m and m.Parent then
			m:Destroy()
		end
	end
	task.spawn(function()
		local arrival = settings.arrivalDestroyDistance or 6
		while m.Parent do
			local root = m:FindFirstChild("HumanoidRootPart")
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
		if settings.useDirectMove == true then
			local humanoid = m:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid:MoveTo(endsPart.Position) end
		else
			PathMover.go(m, endsPart.Position, {
				agentRadius = settings.pathAgentRadius,
				agentHeight = settings.pathAgentHeight,
				walkSpeed = settings.walkSpeed,
			}, cleanup)
		end
	end)
end

return Spawner

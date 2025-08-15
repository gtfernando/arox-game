--!strict

local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ServerScriptService.Modules
local RarityConfig = require(Modules:WaitForChild("RarityConfig"))
local CharacterSelector = require(Modules:WaitForChild("CharacterSelector"))
local CollisionSetup = require(Modules:WaitForChild("CollisionSetup"))
local PathMover = require(Modules:WaitForChild("PathMover"))
local Animator = require(Modules:WaitForChild("Animator"))
local CharactersPrices = require(Modules:WaitForChild("Config"):WaitForChild("CharConfig"))
local EventBus = require(Modules.Singleton:WaitForChild("EventBus"))
local SafeDestroy = require(Modules:WaitForChild("SafeDestroy"))

export type Handle = {
	Start: (self: Handle) -> (),
	Stop: (self: Handle) -> (),
	SpawnForced: (self: Handle, rarity: string) -> (),
}

type PromptArgs = {
    name: string,
    parent: Instance,
    ActionText: string,
    ObjectText: string,
    HoldDuration: number,
	modelSaved: Model?
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

local function CreateProximityPrompt(opts: PromptArgs): ProximityPrompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = opts.name
    prompt.ActionText = opts.ActionText
    prompt.ObjectText = opts.ObjectText
    prompt.HoldDuration = opts.HoldDuration
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 16
    prompt.Parent = opts.parent
    prompt.Enabled = true

	prompt.Triggered:Connect(function(player)
        EventBus.NPCPrompt:Fire(player, opts.modelSaved)
    end)
    return prompt
end

local function formatNumber(n)
    local formatted = tostring(math.floor(n))
    formatted = formatted:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if formatted:sub(1, 1) == "," then
        formatted = formatted:sub(2)
    end
    return formatted
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

	local parentPart = (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or hrp) :: BasePart?
    if parentPart then
        local attach = parentPart:FindFirstChild("PromptAttachment")
        if not attach or not attach:IsA("Attachment") then
            attach = Instance.new("Attachment")
            attach.Name = "PromptAttachment"
            attach.Parent = parentPart
        end

        CreateProximityPrompt({
			name = model.Name .. "BuyPrompt",
			parent = model:FindFirstChild("UpperTorso"),
			ActionText = tostring(formatNumber(CharactersPrices[model.Name].Price)) .. "$",
			ObjectText = "BUY " .. model.Name,
			HoldDuration = 1,
			modelSaved = model
		})
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
		SafeDestroy.destroy(model)
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
			PathMover.cancel(model)
			SafeDestroy.destroy(model)
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
		SafeDestroy.destroy(m)
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
			PathMover.cancel(m)
			SafeDestroy.destroy(m)
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

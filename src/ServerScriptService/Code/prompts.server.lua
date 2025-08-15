--!strict
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ServerScriptService:WaitForChild("Modules")
local Transmission = ReplicatedStorage:WaitForChild("Transmission")

type CharEntry = { Price: number }
local CharConfig = require(Modules.Config.CharConfig) :: { [string]: CharEntry }

type ProfileData = { Dinero: number }
type PlayerProfile = { Data: ProfileData }
local ProfileManager = require(Modules.Manager.ProfileManager) :: { Profiles: { [Player]: PlayerProfile } }

type PromptSignal = { Connect: (self: any, handler: (player: Player, model: Model?) -> ()) -> RBXScriptConnection }
local EventBus = require(Modules.Singleton.EventBus) :: { NPCPrompt: PromptSignal }
local PathMover = require(Modules:WaitForChild("PathMover"))
local RarityConfig = require(Modules:WaitForChild("RarityConfig"))
local SafeDestroy = require(Modules:WaitForChild("SafeDestroy"))

local function getPlaceholderForPlayer(player: Player): BasePart?
    local baseAttr = player:GetAttribute("BaseNumber")
    if baseAttr == nil then return nil end
    local folder = Workspace:FindFirstChild("PlaceHolders")
    if not folder then return nil end
    local key = if typeof(baseAttr) == "number" then tostring(baseAttr) elseif typeof(baseAttr) == "string" then (baseAttr :: string) else nil
    if key == nil then return nil end
    local target = folder:FindFirstChild(key)
    if target and target:IsA("BasePart") then
        return target
    end
    return nil
end

local function moveModelToPlaceholder(model: Model, target: BasePart)
    local settings = RarityConfig.getSettings()
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp or not hrp:IsA("BasePart") then return end
    humanoid.WalkSpeed = settings.walkSpeed
    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    humanoid:ChangeState(Enum.HumanoidStateType.Running)
    local destroyed = false
    
    local function cleanup()
        if destroyed then return end
        destroyed = true
        if model and model.Parent then
            print(model.Name .. " has reached its destination, cleaning up.")
            PathMover.cancel(model)
            SafeDestroy.destroy(model)
        end
    end

    task.spawn(function()
        local arrival = settings.arrivalDestroyDistance or 6
        while model.Parent do
            local root = model:FindFirstChild("HumanoidRootPart")
            if root and root:IsA("BasePart") then
                if (root.Position - target.Position).Magnitude <= arrival then
                    cleanup()
                    break
                end
            else
                break
            end
            task.wait(0.1)
        end
    end)

    pcall(function()
        humanoid:MoveTo(target.Position)
    end)
    PathMover.go(model, target.Position, {
        agentRadius = settings.pathAgentRadius,
        agentHeight = settings.pathAgentHeight,
        walkSpeed = settings.walkSpeed,
    }, cleanup)
end

EventBus.NPCPrompt:Connect(function(player: Player, model: Model?)
    if not model then return end
    local cfg = CharConfig[model.Name]
    if not cfg then return end
    local profile = ProfileManager.Profiles[player]
    if not profile then return end
    local data = profile.Data
    if not data then return end

    if data.Dinero >= cfg.Price then
        local target = getPlaceholderForPlayer(player)
        if target then
            data.Dinero -= cfg.Price

            Transmission.HideProximityPrompts:FireAllClients({
                model = model,
                user = player,
                proximity = model:FindFirstChild("UpperTorso"):FindFirstChild(model.Name .. "BuyPrompt")
            })
            PathMover.cancel(model)
            task.wait() 
            moveModelToPlaceholder(model, target)
        else
            warn("[Prompts] No placeholder found for BaseNumber, skipping move")
        end
    end
end)
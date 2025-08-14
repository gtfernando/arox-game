--!strict
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local CollisionSetup = {}
local GROUP_NPCS = "NPCs"
local GROUP_PLAYERS = "Players"

local function groupExists(name: string): boolean
    for _, info in ipairs(PhysicsService:GetCollisionGroups()) do
        if info.name == name then
            return true
        end
    end
    return false
end

local function ensureGroups()
    if not groupExists(GROUP_NPCS) then
        PhysicsService:RegisterCollisionGroup(GROUP_NPCS)
    end
    if not groupExists(GROUP_PLAYERS) then
        PhysicsService:RegisterCollisionGroup(GROUP_PLAYERS)
    end
    PhysicsService:CollisionGroupSetCollidable(GROUP_NPCS, GROUP_NPCS, false)
    PhysicsService:CollisionGroupSetCollidable(GROUP_NPCS, GROUP_PLAYERS, false)
end

function CollisionSetup.Init()
    ensureGroups()
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if char then CollisionSetup.ApplyToPlayerCharacter(char) end
        plr.CharacterAdded:Connect(function(c) CollisionSetup.ApplyToPlayerCharacter(c) end)
    end
    Players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(function(c) CollisionSetup.ApplyToPlayerCharacter(c) end)
    end)
end

function CollisionSetup.ApplyToNPC(model: Model)
    ensureGroups()
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            local p = d :: BasePart
            p.CollisionGroup = GROUP_NPCS
            p.Anchored = false
        end
    end
end

function CollisionSetup.ApplyToPlayerCharacter(model: Model)
    ensureGroups()
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            (d :: BasePart).CollisionGroup = GROUP_PLAYERS
        end
    end
end

return CollisionSetup
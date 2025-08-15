--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ServerScriptService:WaitForChild("Modules")
local ProfileManager = require(Modules.Manager.ProfileManager)
local BaseLockConfig = require(Modules.Config.BaseLockConfig)

local placeholders = Workspace:WaitForChild("PlaceHolders") :: Folder

type BaseInfo = {
    OwnedBy: Player?
}

type FreeBasesType = {
    ["1"]: BaseInfo,
    ["2"]: BaseInfo,
    ["3"]: BaseInfo,
    ["4"]: BaseInfo,
    ["5"]: BaseInfo,
    ["6"]: BaseInfo,
    ["7"]: BaseInfo,
    ["8"]: BaseInfo
}

local FreeBases: FreeBasesType = {
    ["1"] = { OwnedBy = nil },
    ["2"] = { OwnedBy = nil },
    ["3"] = { OwnedBy = nil },
    ["4"] = { OwnedBy = nil },
    ["5"] = { OwnedBy = nil },
    ["6"] = { OwnedBy = nil },
    ["7"] = { OwnedBy = nil },
    ["8"] = { OwnedBy = nil }
}

local freeBaseIDs = { "1","2","3","4","5","6","7","8" }

local playerToBase: {[Player]: string} = {}
local basePrompts: {[string]: ProximityPrompt} = {}

local baseTimers: {[string]: { version: number, lastTouch: number? }} = {}
local baseTouchConn: {[string]: RBXScriptConnection} = {}

local function BroadcastDoorState(baseID: string, isUnlocked: boolean, cooldownSeconds: number?)
    print(string.format("[BaseSelector] BroadcastDoorState | base=%s | unlocked=%s | cooldown=%s", baseID, tostring(isUnlocked), tostring(cooldownSeconds)))
    ReplicatedStorage.Base.UnLockDoors:FireAllClients({
        baseId = baseID,
        lock = isUnlocked,
        global = true,
        cooldown = cooldownSeconds,
    })
end

local function ScheduleUnlock(baseID: string, seconds: number)
    if baseTimers[baseID] == nil then baseTimers[baseID] = { version = 0 } end
    baseTimers[baseID].version += 1
    local myVersion = baseTimers[baseID].version
    print(string.format("[BaseSelector] ScheduleUnlock | base=%s | in=%ds | version=%d", baseID, seconds, myVersion))
    task.delay(seconds, function()
        local t = baseTimers[baseID]
        if t and t.version == myVersion then
            print(string.format("[BaseSelector] Unlocking base %s now (version %d)", baseID, myVersion))
            BroadcastDoorState(baseID, true, nil) 
        end
    end)
end

local function OnPromptTriggered(triggerPlayer: Player, baseID: string)
    local owner = FreeBases[baseID].OwnedBy :: Player
    if not owner then
        print("La base no tiene dueño.")
        return
    end

    local prompt = basePrompts[baseID]
    if not prompt then
        warn("No se encontró el prompt de la base " .. baseID)
        return
    end

    local isLocked = prompt:GetAttribute("Lock")
    if isLocked == nil then
        isLocked = true
    end

    isLocked = not isLocked
    prompt:SetAttribute("Lock", isLocked)

    local friendsPart = prompt.Parent :: BasePart
    if friendsPart then
        if isLocked then
            friendsPart.Color = Color3.fromRGB(163, 162, 165) -- verde
            prompt.ActionText = "AMIGOS PERMITIDOS: NO"
        else
            friendsPart.Color = Color3.fromRGB(71, 249, 0) -- gris
            prompt.ActionText = "AMIGOS PERMITIDOS: SI"
        end
    end

    local friendsOnline: {Player} = {}
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= owner then
            local success, result = pcall(function()
                return owner:IsFriendsWith(otherPlayer.UserId)
            end)
            if success and result then
                table.insert(friendsOnline, otherPlayer)
            end
        end
    end

    if #friendsOnline > 0 then
        print("Amigos conectados de " .. owner.Name .. ": " .. table.concat(
            table.map(friendsOnline, function(p) return p.Name end), ", "
        ))

        for _, friend in ipairs(friendsOnline) do
            print(string.format("[BaseSelector] Friend toggle | base=%s | friend=%s | friendsAllowed=%s", baseID, friend.Name, tostring(not isLocked)))
            ReplicatedStorage.Base.UnLockDoors:FireClient(friend, {
                baseId = baseID,
                lock = isLocked, 
                friendAllowed = not isLocked,
                global = false,
            })
        end
    end
end

local function SetOwnerBase(player: Player, baseID: string)
    local Base = Workspace.Bases:FindFirstChild("Base" .. baseID) :: Model
    local Configuration = Base.Configuration :: Configuration
    local playerValue = Configuration.PlayerOwner :: StringValue
    playerValue.Value = player

    basePrompts[baseID] = Base.Friends.FriendsProximity
    local prompt = basePrompts[baseID]
    if prompt then
        prompt.Triggered:Connect(function(triggerPlayer)
            OnPromptTriggered(triggerPlayer, baseID)
        end)
    end

    local Sign = Base["Base_" .. baseID].Sign :: BasePart
    local gui = Sign.SurfaceGui :: SurfaceGui
    local label = gui.TextLabel :: TextLabel
    label.Text = player.Name .. "'s Base"

    local num = tonumber(baseID)
    if num then
        player:SetAttribute("BaseNumber", num)
    else
        player:SetAttribute("BaseNumber", baseID)
    end

    BroadcastDoorState(baseID, false, BaseLockConfig.InitialCooldownSeconds)
    ScheduleUnlock(baseID, BaseLockConfig.InitialCooldownSeconds)

    local lockPart = Base:FindFirstChild("Lock")
    if lockPart and lockPart:IsA("BasePart") then
        if baseTouchConn[baseID] then baseTouchConn[baseID]:Disconnect() end
        baseTouchConn[baseID] = lockPart.Touched:Connect(function(otherPart: BasePart)
            local character = otherPart.Parent
            if not character then return end
            local toucher = Players:GetPlayerFromCharacter(character)
            if toucher ~= player then return end

            if baseTimers[baseID] == nil then baseTimers[baseID] = { version = 0 } end
            local last = baseTimers[baseID].lastTouch or 0
            if os.clock() - last < 1 then return end
            baseTimers[baseID].lastTouch = os.clock()

            local profile = ProfileManager and ProfileManager.Profiles and ProfileManager.Profiles[player]
            local rebirths = 0
            if profile and profile.Data and typeof(profile.Data.Rebirths) == "number" then
                rebirths = profile.Data.Rebirths
            end
            local waitSeconds = BaseLockConfig.getRelockCooldownSeconds(rebirths)
            print(string.format("[BaseSelector] Owner re-lock | base=%s | owner=%s | rebirths=%d | cooldown=%ds", baseID, player.Name, rebirths, waitSeconds))

            BroadcastDoorState(baseID, false, waitSeconds)
            ScheduleUnlock(baseID, waitSeconds)
        end)
    end
end


local function TeleportPlayerToBase(player: Player, baseID: string)
    local placeholder = placeholders:FindFirstChild(baseID)
    if placeholder and placeholder:IsA("BasePart") then
        local char = player.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if hrp then
            hrp.CFrame = placeholder.CFrame + Vector3.new(0, 5, 0)
            SetOwnerBase(player, baseID)
        end
    else
        warn("No se encontró el placeholder para la base " .. baseID)
    end
end

local function AssignBaseToPlayer(player: Player)
    if #freeBaseIDs == 0 then
        warn("No hay bases libres para " .. player.Name)
        return
    end

    local baseID = freeBaseIDs[#freeBaseIDs]
    freeBaseIDs[#freeBaseIDs] = nil

    FreeBases[baseID].OwnedBy = player
    playerToBase[player] = baseID

    print(player.Name .. " ha tomado la base " .. baseID)

    TeleportPlayerToBase(player, baseID)
end

local function FreePlayerBase(player: Player)
    local baseID = playerToBase[player]
    if baseID then
        FreeBases[baseID].OwnedBy = nil
        table.insert(freeBaseIDs, baseID) -- push O(1)
        playerToBase[player] = nil
        print("La base " .. baseID .. " ahora está libre")

        -- Cleanup timers / touch connections, and ensure doors are locked/closed
        if baseTimers[baseID] then
            baseTimers[baseID].version += 1 -- cancel pending
        end
        if baseTouchConn[baseID] then
            baseTouchConn[baseID]:Disconnect()
            baseTouchConn[baseID] = nil
        end
        BroadcastDoorState(baseID, false)
    end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        AssignBaseToPlayer(player)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    FreePlayerBase(player)
end)
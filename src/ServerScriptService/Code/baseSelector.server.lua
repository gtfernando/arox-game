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
local baseFriendsAllowed: {[string]: boolean} = {}
local baseUnlocked: {[string]: boolean} = {} -- true when globally unlocked

local function BroadcastDoorState(baseID: string, isUnlocked: boolean, cooldownSeconds: number?)
    --print(string.format("[BaseSelector] BroadcastDoorState | base=%s | unlocked=%s | cooldown=%s", baseID, tostring(isUnlocked), tostring(cooldownSeconds)))
    baseUnlocked[baseID] = isUnlocked
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
    --print(string.format("[BaseSelector] ScheduleUnlock | base=%s | in=%ds | version=%d", baseID, seconds, myVersion))
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

    -- Only base owner can toggle friends access
    if triggerPlayer ~= owner then
        warn(string.format("[BaseSelector] %s intentó cambiar amigos en base %s sin ser dueño", triggerPlayer.Name, baseID))
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

    -- Persist friend-allowed state for this base: when isLocked == false => friends allowed
    local allowFriends = (isLocked == false)
    baseFriendsAllowed[baseID] = allowFriends

    if #friendsOnline > 0 then
        --print("Amigos conectados de " .. owner.Name .. ": " .. table.concat(
        --    table.map(friendsOnline, function(p) return p.Name end), ", "
        --))
        for _, friend in ipairs(friendsOnline) do
            ReplicatedStorage.Base.UnLockDoors:FireClient(friend, {
                baseId = baseID,
                lock = isLocked,
                friendAllowed = allowFriends,
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
        print("ASAD")
    else
        print("SADSA")
        player:SetAttribute("BaseNumber", baseID)
    end

    baseFriendsAllowed[baseID] = false
    baseUnlocked[baseID] = false
    BroadcastDoorState(baseID, false, BaseLockConfig.InitialCooldownSeconds)
    ScheduleUnlock(baseID, BaseLockConfig.InitialCooldownSeconds)

    ReplicatedStorage.Base.UnLockDoors:FireClient(player, {
        baseId = baseID,
        lock = false,
        friendAllowed = true,
        global = false,
    })

    task.delay(1, function()
        if player and player.Parent == Players then
            ReplicatedStorage.Base.UnLockDoors:FireClient(player, {
                baseId = baseID,
                lock = false,
                friendAllowed = true,
                global = false,
            })
        end
    end)

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
            --print(string.format("[BaseSelector] Owner re-lock | base=%s | owner=%s | rebirths=%d | cooldown=%ds", baseID, player.Name, rebirths, waitSeconds))

            BroadcastDoorState(baseID, false, waitSeconds)
            -- If friends are allowed for this base, re-open for friends right away
            if baseFriendsAllowed[baseID] == true then
                local friendsOnline: {Player} = {}
                for _, otherPlayer in ipairs(Players:GetPlayers()) do
                    if otherPlayer ~= player then
                        local success, result = pcall(function()
                            return player:IsFriendsWith(otherPlayer.UserId)
                        end)
                        if success and result then
                            table.insert(friendsOnline, otherPlayer)
                        end
                    end
                end
                for _, friend in ipairs(friendsOnline) do
                    ReplicatedStorage.Base.UnLockDoors:FireClient(friend, {
                        baseId = baseID,
                        lock = false,
                        friendAllowed = true,
                        global = false,
                    })
                end
            end
            -- Always ensure owner can pass after re-lock
            ReplicatedStorage.Base.UnLockDoors:FireClient(player, {
                baseId = baseID,
                lock = false,
                friendAllowed = true,
                global = false,
            })
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

    local index = math.random(1, #freeBaseIDs)
    local baseID = freeBaseIDs[index]

    freeBaseIDs[index] = freeBaseIDs[#freeBaseIDs]
    freeBaseIDs[#freeBaseIDs] = nil

    FreeBases[baseID].OwnedBy = player
    playerToBase[player] = baseID

    print(player.Name .. " ha tomado la base " .. baseID)

    SetOwnerBase(player, baseID)
end


local function FreePlayerBase(player: Player)
    local baseID = playerToBase[player]
    if baseID then
        local Base = Workspace.Bases:FindFirstChild("Base" .. baseID) :: Model
        local Sign = Base["Base_" .. baseID].Sign :: BasePart
        Sign.SurfaceGui.TextLabel.Text = "Label"

        FreeBases[baseID].OwnedBy = nil
        table.insert(freeBaseIDs, baseID)
        playerToBase[player] = nil
        print("La base " .. baseID .. " ahora está libre")

        if baseTimers[baseID] then
            baseTimers[baseID].version += 1 
        end
        if baseTouchConn[baseID] then
            baseTouchConn[baseID]:Disconnect()
            baseTouchConn[baseID] = nil
        end
    baseFriendsAllowed[baseID] = nil
    baseUnlocked[baseID] = nil
        BroadcastDoorState(baseID, false)
    end
end

Players.PlayerAdded:Connect(function(player)
    AssignBaseToPlayer(player)

    player.CharacterAdded:Connect(function()
        local baseID = playerToBase[player]
        if baseID then
            TeleportPlayerToBase(player, baseID)
            -- After teleport, if the base is still globally locked, ensure owner access again
            if baseUnlocked[baseID] == false then
                ReplicatedStorage.Base.UnLockDoors:FireClient(player, {
                    baseId = baseID,
                    lock = false,
                    friendAllowed = true,
                    global = false,
                })
            end
        end
    end)

    -- If any base is locked and allows friends, grant access to joining friends
    for baseID, allow in pairs(baseFriendsAllowed) do
        if allow == true then
            local owner = FreeBases[baseID].OwnedBy
            if owner and owner ~= player and baseUnlocked[baseID] == false then
                local ok, isFriend = pcall(function()
                    return owner:IsFriendsWith(player.UserId)
                end)
                if ok and isFriend then
                    ReplicatedStorage.Base.UnLockDoors:FireClient(player, {
                        baseId = baseID,
                        lock = false,
                        friendAllowed = true,
                        global = false,
                    })
                end
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    FreePlayerBase(player)
end)
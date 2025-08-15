--!strict
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Base = ReplicatedStorage:WaitForChild("Base")

local countdowns: { [string]: { endsAt: number, conn: RBXScriptConnection? } } = {}

local function setLasersTransparency(lasers: Instance, alpha: number)
    for _, inst in ipairs(lasers:GetDescendants()) do
        if inst:IsA("BasePart") then
            inst.Transparency = alpha
        elseif inst:IsA("Decal") then
            inst.Transparency = alpha
        end
    end
end

local function stopCountdown(baseId: string)
    local c = countdowns[baseId]
    if c and c.conn then
        c.conn:Disconnect()
        c.conn = nil
    end
    countdowns[baseId] = nil
end

local function startCountdown(baseId: string, uiTimer: TextLabel, seconds: number)
    stopCountdown(baseId)
    local endsAt = os.time() + math.max(0, math.floor(seconds))
    countdowns[baseId] = { endsAt = endsAt }

    countdowns[baseId].conn = game:GetService("RunService").Heartbeat:Connect(function()
        local now = os.time()
        local remaining = math.max(0, endsAt - now)
    uiTimer.Text = tostring(remaining) .. "s"
        if remaining <= 0 then
            stopCountdown(baseId)
        end
    end)
end

Base.UnLockDoors.OnClientEvent:Connect(function(data: {baseId: string, lock: boolean, global: boolean?, cooldown: number?})
    print(string.format("[BaseClient] Event | base=%s | global=%s | lock=%s | cooldown=%s", tostring(data.baseId), tostring(data.global ~= false), tostring(data.lock), tostring(data.cooldown)))
    local BaseModel = Workspace.Bases:FindFirstChild("Base" .. data.baseId) :: Model
    if not BaseModel then return end
    local Floors = BaseModel:FindFirstChild("Floors") :: Folder
    if not Floors then return end
    local Floor1 = Floors:FindFirstChild("Floor1") :: Model
    if not Floor1 then return end
    local Doors = Floor1.Doors:FindFirstChild("Door1") :: Model
    if not Doors then return end

    local isUnlocked = data.lock == true

    local doorHitbox = Doors:FindFirstChild("Hitbox")
    local lp = Players.LocalPlayer
    local myBaseAttr = lp:GetAttribute("BaseNumber")
    local isOwner = (myBaseAttr ~= nil and tostring(myBaseAttr) == tostring(data.baseId))
    if not isOwner then
        local cfg = BaseModel:FindFirstChild("Configuration")
        local ownerVal = cfg and cfg:FindFirstChild("PlayerOwner")
        if ownerVal then
            if ownerVal:IsA("ObjectValue") and ownerVal.Value == lp then
                isOwner = true
            elseif ownerVal:IsA("StringValue") then
                if ownerVal.Value == lp.Name or ownerVal.Value == tostring(lp.UserId) then
                    isOwner = true
                end
            elseif ownerVal:IsA("IntValue") and ownerVal.Value == lp.UserId then
                isOwner = true
            end
        end
    end
    if isOwner then
        print("[BaseClient] Owner detected for base " .. tostring(data.baseId))
    end
    local function setHitboxCollide(part: Instance?, collide: boolean)
        if part and part:IsA("BasePart") then
            part.CanCollide = collide
            print(string.format("[BaseClient] Hitbox=%s | CanCollide=%s", part:GetFullName(), tostring(collide)))
        end
    end
    if data.global ~= false then
        setHitboxCollide(doorHitbox, not isUnlocked)
        if not isUnlocked and isOwner then
            setHitboxCollide(doorHitbox, false)
        end
    end

    if data.global ~= false then
        local lasers = Doors:FindFirstChild("Lasers")
        if lasers then
            setLasersTransparency(lasers, if isUnlocked then 1 else 0.5)
        end

        local lockObj = BaseModel:FindFirstChild("Lock")
        if lockObj then
            local blockUI = lockObj:FindFirstChild("BlockUI")
            if blockUI and blockUI:IsA("BillboardGui") then
                local timerLabel = blockUI:FindFirstChild("Timer")
                local stateLabel = blockUI:FindFirstChild("TextLabel")
                if stateLabel and stateLabel:IsA("TextLabel") then
                    stateLabel.Text = if isUnlocked then "Base bloqueada: No" else "Base bloqueada: Si"
                end

                if timerLabel and timerLabel:IsA("TextLabel") then
                    if data.cooldown and not isUnlocked then
                        startCountdown(data.baseId, timerLabel, data.cooldown)
                    else
                        stopCountdown(data.baseId)
                        timerLabel.Text = "0s"
                    end
                end
            end
        end
    else
        local allow = (data.friendAllowed == true)
        if allow then
            setHitboxCollide(doorHitbox, false)
        end

        if isOwner then
            setHitboxCollide(doorHitbox, false)
        end
    end
end)
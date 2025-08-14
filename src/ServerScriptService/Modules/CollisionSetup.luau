--!strict
-- CollisionSetup: ensures a collision group for NPCs that doesn't collide with players or itself

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local GROUP_NPC = "NPCs"
local GROUP_PLAYERS = "Players" -- common group name; if not present we won't error

local CollisionSetup = {}

local function ensureGroup(name: string)
	local ok = true
	pcall(function()
		PhysicsService:CreateCollisionGroup(name)
	end)
	return ok
end

local function safeSet(groupA: string, groupB: string, canCollide: boolean)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(groupA, groupB, canCollide)
	end)
end

function CollisionSetup.init()
	ensureGroup(GROUP_NPC)
	-- NPCs don't collide with themselves
	safeSet(GROUP_NPC, GROUP_NPC, false)
	-- Try to avoid colliding with Players group if it exists/configured
	safeSet(GROUP_NPC, GROUP_PLAYERS, false)
	safeSet(GROUP_PLAYERS, GROUP_NPC, false)

	-- Optionally put player character parts into Players group
	Players.PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(function(char)
			for _, d in ipairs(char:GetDescendants()) do
				if d:IsA("BasePart") then
					pcall(function()
						PhysicsService:SetPartCollisionGroup(d, GROUP_PLAYERS)
					end)
				end
			end
		end)
	end)

	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if char then
			for _, d in ipairs(char:GetDescendants()) do
				if d:IsA("BasePart") then
					pcall(function()
						PhysicsService:SetPartCollisionGroup(d, GROUP_PLAYERS)
					end)
				end
			end
		end
	end
end

function CollisionSetup.assign(model: Model)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function()
				PhysicsService:SetPartCollisionGroup(part, GROUP_NPC)
			end)
			-- Ensure parts are movable
			part.Anchored = false
		end
	end
end

return CollisionSetup

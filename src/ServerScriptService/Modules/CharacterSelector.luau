--!strict
-- CharacterSelector: selects an NPC rig from ServerStorage by rarity weights

local ServerStorage = game:GetService("ServerStorage")

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic"

local CharacterSelector = {}

local function chooseRarity(weights: { [Rarity]: number }): Rarity
	local total = 0
	for _, w in weights do
		total += w
	end
	local roll = math.random() * total
	local accum = 0
	for rarity, w in weights do
		accum += w
		if roll <= accum then
			return rarity :: Rarity
		end
	end
	return "Common"
end

local function getFolderForRarity(rarity: Rarity): Folder?
	local base = ServerStorage:FindFirstChild("Characters")
	if not base or not base:IsA("Folder") then return nil end
	local normal = base:FindFirstChild("Normal")
	if not normal or not normal:IsA("Folder") then return nil end
	local folder = normal:FindFirstChild(rarity)
	if not folder or not folder:IsA("Folder") then return nil end
	return folder
end

function CharacterSelector.pick(weights: { [Rarity]: number }): Model?
	local rarity = chooseRarity(weights)
	local folder = getFolderForRarity(rarity)
	if not folder then return nil end
	local choices = folder:GetChildren()
	local pool = {} :: {Model}
	for _, v in ipairs(choices) do
		if v:IsA("Model") then
			table.insert(pool, v)
		end
	end
	if #pool == 0 then return nil end
	local idx = math.random(1, #pool)
	return pool[idx]:Clone()
end

function CharacterSelector.getDefaultRig(): Model?
	local base = ServerStorage:FindFirstChild("Characters")
	if not base or not base:IsA("Folder") then return nil end
	local rigFolder = base:FindFirstChild("DefaultRig")
	if rigFolder and rigFolder:IsA("Model") then
		return rigFolder
	end
	return nil
end

return CharacterSelector

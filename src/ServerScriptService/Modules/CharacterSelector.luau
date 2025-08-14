--!strict

local ServerStorage = game:GetService("ServerStorage")
local RarityConfig = require(script.Parent:WaitForChild("RarityConfig"))

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
	local settings = RarityConfig.getSettings()
	local function collect(f: Folder?): {Model}
		local pool = {} :: {Model}
		if not f then return pool end
		for _, v in ipairs(f:GetChildren()) do
			if v:IsA("Model") then
				table.insert(pool, v)
			end
		end
		return pool
	end
	local pool = collect(folder)
	if #pool == 0 then

		local all: {Model} = {}
		for _, r in ipairs({"Common","Rare","Epic","Legendary","Mythic"} :: {Rarity}) do
			local pf = getFolderForRarity(r)
			for _, m in ipairs(collect(pf)) do table.insert(all, m) end
		end
		if settings.debug then
			warn(string.format("[CharacterSelector] Empty rarity '%s', fallback to any (%d available)", rarity, #all))
		end
		pool = all
	end
	if #pool == 0 then
		if settings.debug then
			warn("[CharacterSelector] No NPC models found under ServerStorage/Characters/Normal/*")
		end
		return nil
	end
	local idx = math.random(1, #pool)
	return pool[idx]:Clone()
end

function CharacterSelector.pickFromRarity(rarity: Rarity): Model?
	local function collect(f: Folder?): {Model}
		local pool = {} :: {Model}
		if not f then return pool end
		for _, v in ipairs(f:GetChildren()) do
			if v:IsA("Model") then
				table.insert(pool, v)
			end
		end
		return pool
	end
	local folder = getFolderForRarity(rarity)
	local pool = collect(folder)
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

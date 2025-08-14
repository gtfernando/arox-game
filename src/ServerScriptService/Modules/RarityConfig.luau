--!strict
-- RarityConfig: weights and spawn settings
-- Edit these values to customize spawn frequency, path agent, and speed

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type Weights = {
	Common: number,
	Rare: number,
	Epic: number,
	Legendary: number,
	Mythic: number,
}

export type Settings = {
	spawnIntervalSeconds: number, -- how often to spawn an NPC
	walkSpeed: number, -- uniform humanoid WalkSpeed for all NPCs
	pathAgentRadius: number?, -- optional: pathfinding agent radius
	pathAgentHeight: number?, -- optional: pathfinding agent height
	arrivalDestroyDistance: number?, -- how close to Ends before destroying
	useDirectMove: boolean?, -- prefer direct MoveTo to Ends for a straight lane (uniform spacing)
	desiredGapStuds: number?, -- if set, the spawner derives interval = desiredGapStuds / walkSpeed
	debug: boolean?, -- enable debug prints
	debugTag: string?, -- tag prefix for logs
}

local RarityConfig = {}

local weights: Weights = {
	Common = 60,
	Rare = 20,
	Epic = 12,
	Legendary = 6,
	Mythic = 2,
}

local settings: Settings = {
	spawnIntervalSeconds = 3,
	walkSpeed = 12,
	pathAgentRadius = 2,
	pathAgentHeight = 5,
	arrivalDestroyDistance = 6,
	useDirectMove = false,
	desiredGapStuds = 18,
	debug = false,
	debugTag = "Spawner",
}

function RarityConfig.getWeights(): Weights
	return weights
end

function RarityConfig.getSettings(): Settings
	return settings
end

return RarityConfig

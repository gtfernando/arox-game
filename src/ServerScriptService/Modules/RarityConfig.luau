--!strict

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type Weights = {
	Common: number,
	Rare: number,
	Epic: number,
	Legendary: number,
	Mythic: number,
}

export type Settings = {
	spawnIntervalSeconds: number,
	walkSpeed: number,
	pathAgentRadius: number?,
	pathAgentHeight: number?,
	arrivalDestroyDistance: number?,
	useDirectMove: boolean?,
	desiredGapStuds: number?,
	debug: boolean?,
	debugTag: string?,
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
	spawnIntervalSeconds = 6,
	walkSpeed = 12,
	pathAgentRadius = 2,
	pathAgentHeight = 5,
	arrivalDestroyDistance = 6,
	useDirectMove = false,
	desiredGapStuds = nil,
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

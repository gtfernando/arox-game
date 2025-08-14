--!strict
-- AnimationOverrides: per-NPC optional animation IDs; defaults otherwise
-- Key by model name under ServerStorage.Characters
-- Only names present here will override defaults

export type Override = {
	walkId: number?,
	idleId: number?,
}

local overrides: { [string]: Override } = {
	-- Example:
	-- ["MythicKnight"] = { walkId = 1234567890, idleId = 2345678901 },
}

local DEFAULTS = {
	walkId = 2510238627, -- default requested
	idleId = 0, -- 0 means none; Humanoid will use built-in idle if present
}

local AnimationOverrides = {}

function AnimationOverrides.get(name: string): Override
	return overrides[name] or {}
end

function AnimationOverrides.getDefaults(): Override
	return DEFAULTS
end

return AnimationOverrides

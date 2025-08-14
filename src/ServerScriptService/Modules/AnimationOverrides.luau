--!strict

export type Override = {
	walkId: number?,
	idleId: number?,
}

local overrides: { [string]: Override } = {
	-- Example:
	-- ["MythicKnight"] = { walkId = 1234567890, idleId = 2345678901 },
}

local DEFAULTS = { walkId = 2510238627, idleId = 0 }

local AnimationOverrides = {}

function AnimationOverrides.get(name: string): Override
	return overrides[name] or {}
end

function AnimationOverrides.getDefaults(): Override
	return DEFAULTS
end

return AnimationOverrides

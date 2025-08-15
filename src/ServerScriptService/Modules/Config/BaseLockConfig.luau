--!strict

type RebirthCooldownMap = { [number]: number }

export type BaseLockConfigType = {
    InitialCooldownSeconds: number,
    DefaultRelockCooldownSeconds: number,
    RebirthCooldowns: RebirthCooldownMap,
    getRelockCooldownSeconds: (rebirths: number) -> number
}

local BaseLockConfig: BaseLockConfigType = {}

-- Cooldown inicial cuando el jugador entra al juego
BaseLockConfig.InitialCooldownSeconds = 30

-- Cooldown default para un jugador sin rebirths o que no estén en override
BaseLockConfig.DefaultRelockCooldownSeconds = 60

-- Overrides opcionales: cooldown por rebirths
-- Ejemplo: [1] = 100 significa que los jugadores con exactamente 1 rebirth obtienen 100s de cooldown
-- Dejar vacío {} para usar el valor predeterminado para todos los jugadores
BaseLockConfig.RebirthCooldowns = {} :: RebirthCooldownMap

function BaseLockConfig.getRelockCooldownSeconds(rebirths: number): number
    local override: number? = BaseLockConfig.RebirthCooldowns[rebirths]

    if override then
        assert(override >= 0, ("Cooldown para rebirth %d no puede ser negativo"):format(rebirths))
        return override
    end

    return BaseLockConfig.DefaultRelockCooldownSeconds
end

return BaseLockConfig
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Modules = ServerScriptService:WaitForChild("Modules")

type CharEntry = { Price: number }
local CharConfig = require(Modules.Config.CharConfig) :: { [string]: CharEntry }

type ProfileData = { Dinero: number }
type PlayerProfile = { Data: ProfileData }
local ProfileManager = require(Modules.Manager.ProfileManager) :: { Profiles: { [Player]: PlayerProfile } }

type PromptSignal = { Connect: (self: any, handler: (player: Player, model: Model?) -> ()) -> RBXScriptConnection }
local EventBus = require(Modules.Singleton.EventBus) :: { NPCPrompt: PromptSignal }

EventBus.NPCPrompt:Connect(function(player: Player, model: Model?)
    if not model then return end
    if not CharConfig[model.Name] then return end
    if not ProfileManager.Profiles[player] then return end
    if not ProfileManager.Profiles[player].Data then return end

    local cfg = CharConfig[model.Name]
    local data = ProfileManager.Profiles[player].Data

    if data.Dinero >= cfg.Price then
        data.Dinero = data.Dinero - cfg.Price

        print(data.Dinero)
    end
end)
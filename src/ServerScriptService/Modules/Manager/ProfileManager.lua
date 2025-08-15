local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local ProfileStore = require(ServerScriptService.Modules.Manager.ProfileStore)

local PROFILE_TEMPLATE = {
   Dinero = 10000000,
   Items = {},
   Rebirths = 0
}

local Players = game:GetService("Players")

local PlayerStore = ProfileStore.New("testStore", PROFILE_TEMPLATE)
local Profiles: {[Player]: typeof(PlayerStore:StartSessionAsync())} = {}

local function CreateNPCKey(name: string)
    local cleanName = string.lower(name)
    cleanName = string.gsub(cleanName, "%s+", "_")
    return cleanName .. "-" .. HttpService:GenerateGUID(false)
end

local function SaveNPCData(player: Player, name: string, slot_id: string, rarity: string)
    local profile = Profiles[player]
    if not profile or not profile.Data then
        warn("No profile loaded for player:", player.Name)
        return
    end

    profile.Data.Items = profile.Data.Items or {}

    profile.Data.Items[CreateNPCKey(name)] = {
        Rarity = rarity,
        SlotId = slot_id
    }
end


local function PlayerAdded(player)

   local profile = PlayerStore:StartSessionAsync(`{player.UserId}`, {
      Cancel = function()
         return player.Parent ~= Players
      end,
   })


   if profile ~= nil then

      profile:AddUserId(player.UserId)
      profile:Reconcile() 

      profile.OnSessionEnd:Connect(function()
         Profiles[player] = nil
         player:Kick(`Profile session end - Please rejoin`)
      end)

      if player.Parent == Players then
         Profiles[player] = profile
      else
         profile:EndSession()
      end

   else
      player:Kick(`Profile load fail - Please rejoin`)
   end

end

for _, player in Players:GetPlayers() do
   task.spawn(PlayerAdded, player)
end

Players.PlayerAdded:Connect(PlayerAdded)

Players.PlayerRemoving:Connect(function(player)
   local profile = Profiles[player]
   if profile ~= nil then
      profile:EndSession()
   end
end)

return {
    Profiles = Profiles
}
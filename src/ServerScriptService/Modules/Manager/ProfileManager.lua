local ServerScriptService = game:GetService("ServerScriptService")
local ProfileStore = require(ServerScriptService.Modules.Manager.ProfileStore)

local PROFILE_TEMPLATE = {
   Dinero = 10000000,
   Items = {},
   Rebirths = 0
}

local Players = game:GetService("Players")

local PlayerStore = ProfileStore.New("testStore", PROFILE_TEMPLATE)
local Profiles: {[Player]: typeof(PlayerStore:StartSessionAsync())} = {}

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
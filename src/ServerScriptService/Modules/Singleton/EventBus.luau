--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Resources = ServerScriptService:WaitForChild("Resources")
local GoodSignal = require(Resources:WaitForChild("GoodSignal"))

type PromptSignal = {
    Connect: (self: any, handler: (player: Player, model: Model?) -> ()) -> RBXScriptConnection,
    Fire: (self: any, player: Player, model: Model?) -> (),
}

local EventBus = {}
local npcPrompt = GoodSignal.new() :: any

(EventBus :: any).NPCPrompt = npcPrompt :: PromptSignal

return EventBus
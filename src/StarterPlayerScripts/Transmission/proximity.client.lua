--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Transmission = ReplicatedStorage:WaitForChild("Transmission")

Transmission.HideProximityPrompts.OnClientEvent:Connect(function(opts: {model: Model, user: Player, proximity: ProximityPrompt})
    if opts.user == game.Players.LocalPlayer then
        if opts.proximity and opts.proximity.Parent == opts.model:FindFirstChild("UpperTorso") then
            opts.proximity.Enabled = false
        end
    else
        if opts.proximity and opts.proximity.Parent == opts.model:FindFirstChild("UpperTorso") then
            opts.proximity.Enabled = true
        end
    end
end)
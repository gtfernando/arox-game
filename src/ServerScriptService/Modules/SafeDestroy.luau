--!strict

-- Defers instance destruction to avoid frame hitches from large, immediate :Destroy() calls.
-- Also stops any playing animation tracks on Humanoids to reduce cleanup work.

local Debris = game:GetService("Debris")

local SafeDestroy = {}

local function stopAnimations(model: Model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then return end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		pcall(function()
			track:Stop(0)
		end)
	end
end

function SafeDestroy.destroy(inst: Instance)
	if inst == nil then return end
	pcall(function()
		if inst:IsA("Model") then
			stopAnimations(inst)
		end
		(inst :: any).Parent = nil

		Debris:AddItem(inst, 0.05)
	end)
end

return SafeDestroy

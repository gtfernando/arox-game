--!strict
local AnimationOverrides = require(script.Parent:WaitForChild("AnimationOverrides"))

local Animator = {}

local function loadAnim(humanoid: Humanoid, animId: number): AnimationTrack?
	if animId == 0 then return nil end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://" .. tostring(animId)
	local track = animator:LoadAnimation(anim)
	return track
end

function Animator.apply(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local override = AnimationOverrides.get(model.Name)
	local defaults = AnimationOverrides.getDefaults()
	local walkId = (override.walkId or defaults.walkId) :: number
	local idleId = (override.idleId or defaults.idleId) :: number

	local walkTrack = loadAnim(humanoid, walkId)
	if walkTrack then
		walkTrack.Priority = Enum.AnimationPriority.Movement
		walkTrack:Play(0.2, 1.0, 1.0)
	end
	local idleTrack = loadAnim(humanoid, idleId)
	if idleTrack then
		idleTrack.Priority = Enum.AnimationPriority.Idle
		idleTrack:Play(0.2, 1.0, 0.8)
	end
end

return Animator

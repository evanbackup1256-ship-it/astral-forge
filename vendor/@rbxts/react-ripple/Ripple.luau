-- This file is mounted both as @rbxts.react-ripple.Ripple and as the @rbxts.Ripple
-- alias, so the ripple package is either a sibling of this script or a sibling
-- of its parent.
local function findPackage(name)
	local current = script.Parent
	for _ = 1, 3 do
		if current == nil then
			break
		end
		local found = current:FindFirstChild(name)
		if found ~= nil then
			return found
		end
		current = current.Parent
	end
	error(`{name} package was not found from {script:GetFullName()}`)
end
local Ripple = require(findPackage("ripple").src)

export type Animatable = Ripple.Animatable
export type Easing = Ripple.Easing
export type Motion<T = any> = Ripple.Motion<T>
export type MotionOptions<T = any> = Ripple.MotionOptions<T>
export type Spring<T = any> = Ripple.Spring<T>
export type SpringOptions<T = any> = Ripple.SpringOptions<T>
export type Tween<T = any> = Ripple.Tween<T>
export type TweenOptions<T = any> = Ripple.TweenOptions<T>

return Ripple

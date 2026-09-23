--!strict
local types = require(script.Parent:WaitForChild('types'))
type Goal = types.Goal

local function instant(targetValue): Goal
	return {
		step = function()
			return {
				value = targetValue,
				complete = true,
			}
		end,
	}
end

return instant

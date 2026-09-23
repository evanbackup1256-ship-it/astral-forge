-- Compiled with roblox-ts v2.2.0
local Types
do
	local _inverse = {}
	Types = setmetatable({}, {
		__index = _inverse,
	})
	Types.Keyboard = 0
	_inverse[0] = "Keyboard"
	Types.Mouse = 1
	_inverse[1] = "Mouse"
	Types.Touch = 2
	_inverse[2] = "Touch"
	Types.DeviceMovement = 3
	_inverse[3] = "DeviceMovement"
	Types.Gamepad = 4
	_inverse[4] = "Gamepad"
	Types.UX = 5
	_inverse[5] = "UX"
	Types.None = 6
	_inverse[6] = "None"
end
local RobloxInputType3AMap = {
	[Types.Keyboard] = { Enum.UserInputType.Keyboard },
	[Types.Mouse] = { Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseButton3, Enum.UserInputType.MouseMovement, Enum.UserInputType.MouseWheel },
	[Types.Touch] = { Enum.UserInputType.Touch },
	[Types.DeviceMovement] = { Enum.UserInputType.Accelerometer, Enum.UserInputType.Gyro },
	[Types.Gamepad] = { Enum.UserInputType.Gamepad1, Enum.UserInputType.Gamepad2, Enum.UserInputType.Gamepad3, Enum.UserInputType.Gamepad4, Enum.UserInputType.Gamepad5, Enum.UserInputType.Gamepad6, Enum.UserInputType.Gamepad7, Enum.UserInputType.Gamepad8 },
	[Types.UX] = { Enum.UserInputType.TextInput },
	[Types.None] = { Enum.UserInputType.Focus, Enum.UserInputType.None, Enum.UserInputType.InputMethod },
}
local RobloxInputType3AReverseMap = {}
for k, v in pairs(RobloxInputType3AMap) do
	local _arg0 = function(it)
		local _it = it
		RobloxInputType3AReverseMap[_it] = k
		return RobloxInputType3AReverseMap
	end
	for _k, _v in v do
		_arg0(_v, _k - 1, v)
	end
end
return {
	Types = Types,
	RobloxInputType3AMap = RobloxInputType3AMap,
	RobloxInputType3AReverseMap = RobloxInputType3AReverseMap,
}

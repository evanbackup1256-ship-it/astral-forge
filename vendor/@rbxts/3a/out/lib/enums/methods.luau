-- Compiled with roblox-ts v2.2.0
local TS = _G[script]
local Types = TS.import(script, script.Parent, "types").Types
local Methods
do
	local _inverse = {}
	Methods = setmetatable({}, {
		__index = _inverse,
	})
	Methods.KeyboardMouse = 0
	_inverse[0] = "KeyboardMouse"
	Methods.Gamepad = 1
	_inverse[1] = "Gamepad"
	Methods.Touchscreen = 2
	_inverse[2] = "Touchscreen"
	Methods.None = 3
	_inverse[3] = "None"
end
local RobloxInputMethod3AMap = {
	[Methods.KeyboardMouse] = { Types.Keyboard, Types.Mouse },
	[Methods.Gamepad] = { Types.Gamepad },
	[Methods.Touchscreen] = { Types.Touch, Types.DeviceMovement },
	[Methods.None] = { Types.None },
}
local RobloxInputMethod3AReverseMap = {}
for k, v in pairs(RobloxInputMethod3AMap) do
	local _arg0 = function(it)
		local _it = it
		RobloxInputMethod3AReverseMap[_it] = k
		return RobloxInputMethod3AReverseMap
	end
	for _k, _v in v do
		_arg0(_v, _k - 1, v)
	end
end
return {
	Methods = Methods,
	RobloxInputMethod3AMap = RobloxInputMethod3AMap,
	RobloxInputMethod3AReverseMap = RobloxInputMethod3AReverseMap,
}

local importTsModule = require(game.ReplicatedStorage.rbxts_include.TSImport)
local _3a = importTsModule(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["3a"])
local Input = _3a.Input
local InputMethod = _3a.InputMethod
local UserInputService = game:GetService("UserInputService")
local TouchGestureService = require(script.Parent.input.TouchGestureService)
local GamepadNavigationService = require(script.Parent.input.GamepadNavigationService)
local configured = false
local function configureInputPlatform()
	if configured then
		return function() end
	end
	local methods = if UserInputService.TouchEnabled then { InputMethod.Touchscreen } elseif UserInputService.GamepadEnabled then { InputMethod.Gamepad } else { InputMethod.KeyboardMouse }
	local ok, problem = pcall(function()
		return Input.setMethods(methods)
	end)
	if not ok then
		warn("[ERROR] [INPUT] setMethods failed | Error: " .. tostring(problem))
	end
	TouchGestureService.Init()
	GamepadNavigationService.Init()
	configured = true
	return function()
		TouchGestureService.Stop()
		GamepadNavigationService.Stop()
		configured = false
	end
end
return {
	configureInputPlatform = configureInputPlatform,
}

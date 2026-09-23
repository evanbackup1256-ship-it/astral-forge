-- Compiled with roblox-ts v2.2.0
local TS = _G[script]
local _services = TS.import(script, TS.getModule(script, "@rbxts", "services"))
local RunService = _services.RunService
local UserInputService = _services.UserInputService
local previousPos = UserInputService:GetMouseLocation()
RunService.Heartbeat:Connect(function()
	previousPos = UserInputService:GetMouseLocation()
end)
local function getMouseDelta()
	if UserInputService.MouseBehavior == Enum.MouseBehavior.Default then
		local _exp = UserInputService:GetMouseLocation()
		local _previousPos = previousPos
		return _exp - _previousPos
	else
		return UserInputService:GetMouseDelta()
	end
end
return {
	getMouseDelta = getMouseDelta,
}

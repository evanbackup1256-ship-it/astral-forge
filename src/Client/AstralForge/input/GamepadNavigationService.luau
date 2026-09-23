--!strict
-- Controller navigation and TV-safe layout support. Console compliance still
-- requires Studio/physical-device validation.

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local GamepadService = game:GetService("GamepadService")

local GamepadNavigationService = {}
GamepadNavigationService.__index = GamepadNavigationService

local TV_SAFE_MARGIN_RATIO = 0.08
local isConsoleMode = false
local inputConnection: RBXScriptConnection? = nil
local connectedConnection: RBXScriptConnection? = nil
local disconnectedConnection: RBXScriptConnection? = nil
local initialized = false
local previousAutoSelect = false
local previousNavigation = false

local tabCycleCallback: ((delta: number) -> ())? = nil
local modalCloseCallback: (() -> ())? = nil
local quickVaultCallback: (() -> ())? = nil

function GamepadNavigationService.GetTVSafeInsets(viewportSize: Vector2): { top: number, bottom: number, left: number, right: number }
	local marginX = math.floor(viewportSize.X * TV_SAFE_MARGIN_RATIO)
	local marginY = math.floor(viewportSize.Y * TV_SAFE_MARGIN_RATIO)
	return { top = marginY, bottom = marginY, left = marginX, right = marginX }
end

function GamepadNavigationService.Init()
	if initialized then return end
	initialized = true
	previousAutoSelect = GuiService.AutoSelectGuiEnabled
	previousNavigation = GuiService.GuiNavigationEnabled
	local function syncGamepadMode()
		isConsoleMode = UserInputService.GamepadEnabled
		if isConsoleMode then
			GamepadService:DisableGamepadCursor()
			GuiService.AutoSelectGuiEnabled = true
			GuiService.GuiNavigationEnabled = true
		else
			GuiService.AutoSelectGuiEnabled = previousAutoSelect
			GuiService.GuiNavigationEnabled = previousNavigation
		end
	end
	syncGamepadMode()
	connectedConnection = UserInputService.GamepadConnected:Connect(syncGamepadMode)
	disconnectedConnection = UserInputService.GamepadDisconnected:Connect(syncGamepadMode)

	-- Directional focus and explicit shortcuts. Certification still requires device testing.
	inputConnection = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or input.UserInputType ~= Enum.UserInputType.Gamepad1 then return end
		local code = input.KeyCode

		if code == Enum.KeyCode.ButtonB and modalCloseCallback then
			modalCloseCallback()
		elseif code == Enum.KeyCode.ButtonY and quickVaultCallback then
			quickVaultCallback()
		elseif code == Enum.KeyCode.ButtonL1 and tabCycleCallback then
			tabCycleCallback(-1)
		elseif code == Enum.KeyCode.ButtonR1 and tabCycleCallback then
			tabCycleCallback(1)
		end
	end)
end

function GamepadNavigationService.Stop()
	if inputConnection then inputConnection:Disconnect(); inputConnection = nil end
	if connectedConnection then connectedConnection:Disconnect(); connectedConnection = nil end
	if disconnectedConnection then disconnectedConnection:Disconnect(); disconnectedConnection = nil end
	if initialized then
		GuiService.AutoSelectGuiEnabled = previousAutoSelect
		GuiService.GuiNavigationEnabled = previousNavigation
	end
	initialized = false
	isConsoleMode = false
	tabCycleCallback = nil
	modalCloseCallback = nil
	quickVaultCallback = nil
end

function GamepadNavigationService.SetTabCycleCallback(callback: (delta: number) -> ()) tabCycleCallback = callback end
function GamepadNavigationService.SetModalCloseCallback(callback: () -> ()) modalCloseCallback = callback end
function GamepadNavigationService.SetQuickVaultCallback(callback: () -> ()) quickVaultCallback = callback end
function GamepadNavigationService.IsConsole(): boolean return isConsoleMode end
return GamepadNavigationService

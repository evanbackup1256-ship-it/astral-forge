--!strict
-- Controller navigation and TV-safe layout support. Console compliance still
-- requires Studio/physical-device validation.
-- Ten-foot shells already own the side nav; this service only wires focus,
-- shortcuts, and shared hint copy for overlays / bottom chrome.

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
local overchargeCallback: (() -> ())? = nil
local settingsCallback: (() -> ())? = nil

local CONTROLLER_HINTS = {
	{ id = "pages", label = "LB / RB pages" },
	{ id = "vault", label = "Y vault" },
	{ id = "overcharge", label = "X overcharge" },
	{ id = "buy", label = "LT / RT buy ×" },
	{ id = "back", label = "B back" },
	{ id = "hide", label = "View hide" },
	{ id = "settings", label = "Start settings" },
}

local TUTORIAL_HINTS = {
	{ id = "confirm", label = "A confirm" },
	{ id = "back", label = "B back" },
}

function GamepadNavigationService.GetTVSafeInsets(viewportSize: Vector2): { top: number, bottom: number, left: number, right: number }
	local marginX = math.floor(viewportSize.X * TV_SAFE_MARGIN_RATIO)
	local marginY = math.floor(viewportSize.Y * TV_SAFE_MARGIN_RATIO)
	return { top = marginY, bottom = marginY, left = marginX, right = marginX }
end

function GamepadNavigationService.GetHints(kind: string?): { { id: string, label: string } }
	if kind == "tutorial" then
		return TUTORIAL_HINTS
	end
	return CONTROLLER_HINTS
end

function GamepadNavigationService.GetHintLabels(kind: string?): { string }
	local source = GamepadNavigationService.GetHints(kind)
	local labels = table.create(#source)
	for index, entry in source do
		labels[index] = entry.label
	end
	return labels
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

	inputConnection = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or input.UserInputType ~= Enum.UserInputType.Gamepad1 then return end
		local code = input.KeyCode
		if code == Enum.KeyCode.ButtonB and modalCloseCallback then
			modalCloseCallback()
		elseif code == Enum.KeyCode.ButtonY and quickVaultCallback then
			quickVaultCallback()
		elseif code == Enum.KeyCode.ButtonX and overchargeCallback then
			overchargeCallback()
		elseif (code == Enum.KeyCode.ButtonStart or code == Enum.KeyCode.ButtonSelect) and settingsCallback then
			settingsCallback()
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
	overchargeCallback = nil
	settingsCallback = nil
end

function GamepadNavigationService.SetTabCycleCallback(callback: (delta: number) -> ()) tabCycleCallback = callback end
function GamepadNavigationService.SetModalCloseCallback(callback: () -> ()) modalCloseCallback = callback end
function GamepadNavigationService.SetQuickVaultCallback(callback: () -> ()) quickVaultCallback = callback end
function GamepadNavigationService.SetOverchargeCallback(callback: () -> ()) overchargeCallback = callback end
function GamepadNavigationService.SetSettingsCallback(callback: () -> ()) settingsCallback = callback end
function GamepadNavigationService.IsConsole(): boolean return isConsoleMode end
return GamepadNavigationService

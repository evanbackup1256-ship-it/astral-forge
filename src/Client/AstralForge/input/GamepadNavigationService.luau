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
local overlayFocusDepth = 0
local overlayPreviousSelection: GuiObject? = nil

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

-- README checklist: crate reveal claim must be D-pad/A reachable.
local CRATE_HINTS = {
	{ id = "confirm", label = "A claim / skip" },
	{ id = "back", label = "B claim / skip" },
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
	if kind == "crate" then
		return CRATE_HINTS
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

function GamepadNavigationService.IsValidFocusTarget(object: Instance?): boolean
	if object == nil or not object:IsA("GuiObject") then
		return false
	end
	local gui = object :: GuiObject
	if not gui.Visible or gui.AbsoluteSize.X < 2 or gui.AbsoluteSize.Y < 2 then
		return false
	end
	if gui:IsA("GuiButton") then
		local button = gui :: GuiButton
		if not button.Selectable or not button.Active then
			return false
		end
	elseif not gui.Selectable then
		return false
	end
	local current: Instance? = gui
	while current ~= nil do
		if current:IsA("GuiObject") and (current :: GuiObject).Visible == false then
			return false
		end
		current = current.Parent
	end
	return true
end

function GamepadNavigationService.AssignSelection(object: Instance?)
	if not GamepadNavigationService.IsValidFocusTarget(object) then
		return false
	end
	local ok = pcall(function()
		GuiService.SelectedObject = object :: GuiObject
	end)
	return ok
end

function GamepadNavigationService.ClearSelection()
	pcall(function()
		GuiService.SelectedObject = nil
	end)
end

-- Claim / skip / ready / confirm / buy path for overlays and session CTAs: enable Gui
-- navigation and park Selection on the highest-priority valid GuiButton under `root`.
-- Priority prefers commit actions (claim/confirm/buy) over staging (ready) or dismiss.
function GamepadNavigationService.FocusClaim(root: Instance?): GuiObject?
	if not UserInputService.GamepadEnabled then
		return nil
	end
	if root == nil or root.Parent == nil then
		return nil
	end
	GuiService.GuiNavigationEnabled = true
	GuiService.AutoSelectGuiEnabled = true
	local TAG_PRIORITY = {
		claim = 1,
		confirm = 1,
		buy = 2,
		dismiss = 2,
		continue = 2,
		ready = 3,
		skip = 4,
	}
	local function tagScore(instance: Instance): number?
		local current: Instance? = instance
		local best: number? = nil
		while current ~= nil and current ~= root do
			local name = string.lower(current.Name)
			for tag, rank in TAG_PRIORITY do
				if string.find(name, tag, 1, true) then
					if best == nil or rank < best then
						best = rank
					end
				end
			end
			current = current.Parent
		end
		return best
	end
	local preferred: GuiObject? = nil
	local preferredScore = math.huge
	local fallback: GuiObject? = nil
	for _, child in root:GetDescendants() do
		if child:IsA("GuiButton") and GamepadNavigationService.IsValidFocusTarget(child) then
			local score = tagScore(child)
			if score ~= nil and score < preferredScore then
				preferred = child
				preferredScore = score
			elseif fallback == nil then
				fallback = child
			end
		end
	end
	local target = preferred or fallback
	if target ~= nil then
		GamepadNavigationService.AssignSelection(target)
	end
	return target
end

-- Begin a modal overlay focus session (crate reveal, empty reveal). Call EndOverlayFocus on exit.
function GamepadNavigationService.BeginOverlayFocus()
	if overlayFocusDepth == 0 then
		overlayPreviousSelection = GuiService.SelectedObject
		GuiService.GuiNavigationEnabled = false
		GuiService.AutoSelectGuiEnabled = false
		GamepadNavigationService.ClearSelection()
	end
	overlayFocusDepth += 1
end

function GamepadNavigationService.EndOverlayFocus()
	if overlayFocusDepth <= 0 then
		return
	end
	overlayFocusDepth -= 1
	if overlayFocusDepth > 0 then
		return
	end
	local restore = overlayPreviousSelection
	overlayPreviousSelection = nil
	if isConsoleMode then
		GuiService.GuiNavigationEnabled = true
		GuiService.AutoSelectGuiEnabled = true
	else
		GuiService.GuiNavigationEnabled = previousNavigation
		GuiService.AutoSelectGuiEnabled = previousAutoSelect
	end
	if GamepadNavigationService.IsValidFocusTarget(restore) then
		GamepadNavigationService.AssignSelection(restore)
	else
		GamepadNavigationService.ClearSelection()
	end
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
	overlayFocusDepth = 0
	overlayPreviousSelection = nil
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

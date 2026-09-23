local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local usesDesktopStructure = require(script.Parent.interaction).usesDesktopStructure
local GamepadNavigationService = require(script.Parent.input.GamepadNavigationService)
local _theme = require(script.Parent.theme)
local Breakpoints = _theme.Breakpoints
local Layout = _theme.Layout
local ViewportScaleContext = React.createContext(nil)
local function computeViewportScale(screenWidth, screenHeight)
	local width = math.max(1, screenWidth)
	local height = math.max(1, screenHeight)
	local raw = math.min(width / Layout.referenceWidth, height / Layout.referenceHeight)
	return math.clamp(raw, Layout.minScale, Layout.maxScale)
end
local function useViewportScale()
	local _result = React.useContext(ViewportScaleContext)
	if _result ~= nil then
		_result = _result.scale
	end
	local _condition = _result
	if _condition == nil then
		_condition = 1
	end
	return _condition
end
local function readSafeInsets()
	-- AutoScale is mounted inside a CoreUISafeInsets ScreenGui. Roblox has already
	-- applied notch, topbar, home-indicator, and rounded-corner insets to this frame.
	-- Applying GetGuiInset again shifted controls away from the actual safe center.
	return { top = 0, bottom = 0, left = 0, right = 0 }
end
-- How much of the screen the software keyboard leaves usable, as an absolute Y coordinate.
local function keyboardTop(screenHeight, screenOriginY)
	if not UserInputService.TouchEnabled or not UserInputService.OnScreenKeyboardVisible then
		return screenHeight
	end
	local position = UserInputService.OnScreenKeyboardPosition
	local size = UserInputService.OnScreenKeyboardSize
	-- Roblox reports the keyboard through two properties that disagree across platforms: some
	-- report a valid Position with a zero Size, others the reverse, and a keyboard that has not
	-- finished animating in reports a Position at the very bottom of the screen. Prefer whichever
	-- pair produces a plausible top edge, and fall back to a conservative half-screen reservation
	-- rather than pretending the keyboard covers nothing.
	local fromPosition = if position.Y > screenOriginY then position.Y - screenOriginY else math.huge
	local fromSize = if size.Y > 0 then screenHeight - size.Y else math.huge
	local reportedTop = math.min(fromPosition, fromSize)
	if reportedTop >= screenHeight or reportedTop == math.huge then
		reportedTop = screenHeight * 0.55
	end
	-- Never shrink the usable area below a third of the screen — a bogus report should degrade
	-- into a cramped layout, not a zero-height one that collapses every panel.
	return math.clamp(reportedTop, screenHeight * 0.34, screenHeight)
end
-- Scrolls whatever the player is typing into back above the software keyboard. Walks *every*
-- scrolling ancestor rather than stopping at the first: a field inside a horizontal carousel that
-- sits inside a vertical page needs the outer page to move, and the innermost frame — which cannot
-- scroll on Y at all — used to swallow the reveal and leave the field hidden under the keyboard.
local function revealFocusedControl(keyboardTopY)
	local focused = UserInputService:GetFocusedTextBox()
	if focused == nil then
		return nil
	end
	local ancestor = focused.Parent
	while ancestor ~= nil do
		if ancestor:IsA("ScrollingFrame") then
			local scroll = ancestor
			if scroll.ScrollingEnabled and scroll.ScrollingDirection ~= Enum.ScrollingDirection.X then
				local current = scroll.CanvasPosition
				local localTop = focused.AbsolutePosition.Y - scroll.AbsolutePosition.Y + current.Y
				local localBottom = localTop + focused.AbsoluteSize.Y
				-- Clip the visible window at the keyboard's top edge when the frame extends under
				-- it, so a field is scrolled to somewhere the player can actually see.
				local rawWindow = math.max(1, scroll.AbsoluteWindowSize.Y)
				local occluded = if keyboardTopY ~= nil then math.max(0, scroll.AbsolutePosition.Y + rawWindow - keyboardTopY) else 0
				local windowHeight = math.max(64, rawWindow - occluded)
				local padding = 12
				local targetY = current.Y
				if localTop < current.Y + padding then
					targetY = localTop - padding
				elseif localBottom > current.Y + windowHeight - padding then
					targetY = localBottom - windowHeight + padding
				end
				local maxY = math.max(0, scroll.AbsoluteCanvasSize.Y - rawWindow)
				scroll.CanvasPosition = Vector2.new(current.X, math.clamp(targetY, 0, maxY))
			end
		end
		ancestor = ancestor.Parent
	end
end
local function AutoScale(_param)
	local children = _param.children
	local safeHostRef = React.useRef(nil)
	local screen, setScreen = React.useState(function()
		local rect = GuiService:GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets)
		return rect.Max - rect.Min
	end)
	local insets, setInsets = React.useState(function()
		return readSafeInsets()
	end)
	local _, setEnvironmentRevision = React.useState(0)
	React.useEffect(function()
		local host = safeHostRef.current
		if not host then return nil end
		local function sync()
			local size = host.AbsoluteSize
			if size.X > 0 and size.Y > 0 then setScreen(size) end
		end
		sync()
		local connection = host:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync)
		return function() connection:Disconnect() end
	end, {})
	React.useEffect(function()
		local sizeConnection
		local alive = true
		-- An orientation flip changes ViewportSize first and only publishes the rotated safe area
		-- a frame or two later, so the inset read that rides along with the resize returns the
		-- *previous* orientation's notch. Re-read on a short trailing schedule as well, otherwise
		-- a portrait->landscape flip leaves the notch padding on the wrong edge until something
		-- else happens to touch the insets.
		local pending = {}
		local resettle = function()
			for _1, item in pending do
				task.cancel(item)
			end
			table.clear(pending)
			for _1, delay in { 0, 0.12, 0.3 } do
				local _arg0 = task.delay(delay, function()
					if not alive then
						return nil
					end
					setInsets(readSafeInsets())
				end)
				table.insert(pending, _arg0)
			end
		end
		local attach = function()
			local _result = sizeConnection
			if _result ~= nil then
				_result:Disconnect()
			end
			local camera = Workspace.CurrentCamera
			if not camera then
				return nil
			end
			local host = safeHostRef.current
			setScreen(if host and host.AbsoluteSize.X > 0 then host.AbsoluteSize else camera.ViewportSize)
			resettle()
			sizeConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				local currentHost = safeHostRef.current
				setScreen(if currentHost and currentHost.AbsoluteSize.X > 0 then currentHost.AbsoluteSize else camera.ViewportSize)
				resettle()
			end)
		end
		attach()
		local cameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(attach)
		return function()
			alive = false
			for _1, item in pending do
				task.cancel(item)
			end
			local _result = sizeConnection
			if _result ~= nil then
				_result:Disconnect()
			end
			cameraConnection:Disconnect()
		end
	end, {})
	React.useEffect(function()
		local sync = function()
			return setInsets(readSafeInsets())
		end
		sync()
		local connection = GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(sync)
		return function()
			return connection:Disconnect()
		end
	end, {})
	React.useEffect(function()
		local queued = false
		local alive = true
		local sync = function()
			if queued then
				return nil
			end
			queued = true
			task.defer(function()
				if not alive then
					return nil
				end
				queued = false
				setEnvironmentRevision(function(revision)
					return revision + 1
				end)
				setInsets(readSafeInsets())
			end)
		end
		local connections = { UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(sync), UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(sync), UserInputService:GetPropertyChangedSignal("MouseEnabled"):Connect(sync), UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(sync), UserInputService:GetPropertyChangedSignal("GamepadEnabled"):Connect(sync), UserInputService:GetPropertyChangedSignal("OnScreenKeyboardVisible"):Connect(sync), UserInputService:GetPropertyChangedSignal("OnScreenKeyboardPosition"):Connect(sync), UserInputService:GetPropertyChangedSignal("OnScreenKeyboardSize"):Connect(sync) }
		return function()
			alive = false
			-- ▼ ReadonlyArray.forEach ▼
			local _callback = function(connection)
				return connection:Disconnect()
			end
			for _k, _v in connections do
				_callback(_v, _k - 1, connections)
			end
			-- ▲ ReadonlyArray.forEach ▲
		end
	end, {})
	local screenWidth = math.max(1, screen.X)
	local screenHeight = math.max(1, screen.Y)
	local safeOriginY = if safeHostRef.current then safeHostRef.current.AbsolutePosition.Y else 0
	local keyboardOpen = UserInputService.TouchEnabled and UserInputService.OnScreenKeyboardVisible
	local usableScreenHeight = keyboardTop(screenHeight, safeOriginY)
	local chromeScale = Layout.chromeScale
	local tvSafe = if UserInputService.GamepadEnabled and GuiService.ViewportDisplaySize == Enum.DisplaySize.Large
		then GamepadNavigationService.GetTVSafeInsets(Vector2.new(screenWidth, screenHeight))
		else { top = 0, bottom = 0, left = 0, right = 0 }
	local hostWidth = math.round(math.min(Layout.maxShellWidth, math.max(1, screenWidth - tvSafe.left - tvSafe.right)))
	local hostHeight = math.round(math.max(1, usableScreenHeight - tvSafe.top - tvSafe.bottom))
	local layoutWidth = math.max(1, math.floor(hostWidth / chromeScale))
	-- This used to be floored at 240px so panels could never collapse to nothing, but the host
	-- frame is sized in raw offsets: whenever the software keyboard left less than 240px, the
	-- frame was taller than the visible area and the bottom of the UI sat underneath the keyboard
	-- where it could not be reached or scrolled to. Track the real usable height instead — the
	-- keyboard reader already refuses to report less than a third of the screen, so this cannot
	-- degenerate, and `short` (below) now flips so the layout switches to its compact chrome.
	local layoutHeight = math.max(1, math.floor(hostHeight / chromeScale))
	local desktop = usesDesktopStructure(screenWidth, screenHeight)
	local scale = computeViewportScale(layoutWidth, layoutHeight)
	local scaledInset = math.max(0, math.ceil(insets.top / chromeScale))
	-- While the keyboard is up the layout already stops above it, so the home-indicator inset is
	-- off-screen entirely. Still reserving it stacked a phantom gap on top of the keyboard and
	-- squeezed the very rows the player was trying to type into.
	local bottomInset = if keyboardOpen then 0 else math.max(0, math.ceil(insets.bottom / chromeScale))
	local sideInset = math.max(0, math.ceil(math.max(insets.left, insets.right) / chromeScale))
	local compact = layoutWidth < Breakpoints.compact
	local tight = layoutWidth < Breakpoints.tight
	-- `compact` and `tight` are measured against the *layout* box, so `short` has to be too —
	-- measuring it against the raw screen meant a phone with the keyboard up (or a letterboxed
	-- host frame) kept its tall-screen chrome while only a sliver of height was actually usable.
	local short = math.min(layoutHeight, screenHeight) < Breakpoints.short
	local info = React.useMemo(function()
		return {
			scale = scale,
			width = layoutWidth,
			height = layoutHeight,
			topInset = scaledInset,
			bottomInset = bottomInset,
			sideInset = sideInset,
			screenWidth = screenWidth,
			screenHeight = screenHeight,
			keyboardOpen = keyboardOpen,
			desktop = desktop,
			compact = compact,
			tight = tight,
			short = short,
		}
	end, { bottomInset, compact, desktop, keyboardOpen, layoutHeight, layoutWidth, scale, scaledInset, screenHeight, screenWidth, short, sideInset, tight })
	React.useEffect(function()
		if not keyboardOpen then
			return nil
		end
		-- The keyboard animates in, and on some platforms it also resizes underneath us (predictive
		-- text bar, orientation flip, language switch). A single deferred reveal caught only the
		-- first frame of that, so re-check a few times across the animation and again whenever the
		-- reported keyboard geometry changes — `usableScreenHeight` in the deps covers the latter.
		local _exp = { 0.05, 0.16, 0.34 }
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#_exp)
		local _callback = function(delay)
			return task.delay(delay, function()
			return revealFocusedControl(safeOriginY + usableScreenHeight)
			end)
		end
		for _k, _v in _exp do
			_newValue[_k] = _callback(_v, _k - 1, _exp)
		end
		-- ▲ ReadonlyArray.map ▲
		local attempts = _newValue
		return function()
			for _1, attempt in attempts do
				task.cancel(attempt)
			end
		end
	end, { keyboardOpen, layoutHeight, usableScreenHeight })
	return React.createElement("frame", {
		ref = safeHostRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(layoutWidth, layoutHeight),
		Position = UDim2.new(0.5, 0, 0, tvSafe.top),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uiscale", {
		Scale = chromeScale,
	}), React.createElement(ViewportScaleContext.Provider, {
		value = info,
	}, children)))
end
return {
	computeViewportScale = computeViewportScale,
	useViewportScale = useViewportScale,
	AutoScale = AutoScale,
	ViewportScaleContext = ViewportScaleContext,
}

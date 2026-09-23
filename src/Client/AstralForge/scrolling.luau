local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local LayoutUtil = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].layoututil.src)
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Audio = require(script.Parent.audio).Audio
local PACK_BREAKPOINTS = require(script.Parent.flexbox).PACK_BREAKPOINTS
local installed = false
local scrollPreference = 0.6
local momentumPreference = 0.75
local titleFxHoldGeneration = 0
local titleFxHeld = false
local motions = {}
local motionCount = 0
local gamepadAxis = Vector2.zero
local lastScrollSound = -math.huge
local motionDriver
local globalConnections = {}
-- Touch/console: coast on Heartbeat at half rate so RenderStepped stays free
-- for layout/input. Desktop keeps RenderStepped for snappier mouse-wheel feel.
local CONSTRAINED_SCROLL = (UserInputService.TouchEnabled and not UserInputService.MouseEnabled)
	or (UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled)
local function holdTitleFx()
	if not titleFxHeld then
		titleFxHeld = true
		pcall(function()
			return Workspace:SetAttribute("AF_TitleFxHold", true)
		end)
	end
	titleFxHoldGeneration += 1
	local generation = titleFxHoldGeneration
	task.delay(0.16, function()
		if generation ~= titleFxHoldGeneration then
			return nil
		end
		titleFxHeld = false
		pcall(function()
			return Workspace:SetAttribute("AF_TitleFxHold", false)
		end)
	end)
end
local function disposeScrollPerformance()
	installed = false
	titleFxHoldGeneration += 1
	titleFxHeld = false
	pcall(function()
		return Workspace:SetAttribute("AF_TitleFxHold", false)
	end)
	for _, connection in globalConnections do
		connection:Disconnect()
	end
	table.clear(globalConnections)
	local _result = motionDriver
	if _result ~= nil then
		_result:Disconnect()
	end
	motionDriver = nil
	table.clear(motions)
	motionCount = 0
	gamepadAxis = Vector2.zero
end
local function setScrollSpeed(value)
	scrollPreference = math.clamp(value, 0, 1)
end
local function setScrollMomentum(value)
	momentumPreference = math.clamp(value, 0, 1)
end
local function scrollingAncestor(instance)
	local cursor = instance
	while cursor ~= nil do
		if cursor:IsA("ScrollingFrame") and cursor.Visible and cursor.ScrollingEnabled then
			return cursor
		end
		cursor = cursor.Parent
	end
	return nil
end
local function frameUnderPointer(pointer)
	if pointer == nil then
		pointer = UserInputService:GetMouseLocation()
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local objects = playerGui:GetGuiObjectsAtPosition(math.floor(pointer.X), math.floor(pointer.Y))
	for _, object in objects do
		local frame = scrollingAncestor(object)
		if frame ~= nil then
			return frame
		end
	end
	return nil
end
-- GetGuiObjectsAtPosition wants coordinates in the same space GetMouseLocation reports, i.e. with
-- the topbar inset already subtracted. Raw InputObject.Position includes that inset, so hit tests
-- fed straight from an input event landed one topbar-height too low and picked the wrong frame
-- (or nothing at all) near the top of the screen.
local function frameUnderInput(position)
	local ok, topLeft = pcall(function()
		return GuiService:GetGuiInset()
	end)
	local inset = if ok and topLeft ~= nil and typeof(topLeft) == "Vector2" then topLeft else Vector2.zero
	return frameUnderPointer(Vector2.new(position.X - inset.X, position.Y - inset.Y))
end
-- Width of the band along each screen edge that the OS reserves for its own back/home gestures.
-- A touch that starts inside it belongs to the system, so the game must not also fling a list —
-- otherwise an edge-swipe-back both leaves the page and scrolls whatever was under the thumb.
local EDGE_GESTURE_BAND = 22
local function inSystemGestureZone(position)
	if not UserInputService.TouchEnabled then
		return false
	end
	local _viewport = Workspace.CurrentCamera
	if _viewport ~= nil then
		_viewport = _viewport.ViewportSize
	end
	local viewport = _viewport
	if viewport == nil then
		return false
	end
	if position.X <= EDGE_GESTURE_BAND or position.X >= viewport.X - EDGE_GESTURE_BAND then
		return true
	end
	-- The bottom band is the home-indicator swipe area, which every gesture-navigation phone
	-- reserves for itself.
	return position.Y >= viewport.Y - EDGE_GESTURE_BAND
end
local function bounds(frame)
	return Vector2.new(math.max(0, frame.AbsoluteCanvasSize.X - frame.AbsoluteWindowSize.X), math.max(0, frame.AbsoluteCanvasSize.Y - frame.AbsoluteWindowSize.Y))
end
local function clampFor(frame, value)
	local maximum = bounds(frame)
	return Vector2.new(math.clamp(value.X, 0, maximum.X), math.clamp(value.Y, 0, maximum.Y))
end
local ensureMotionDriver
local function targetFor(frame)
	local _frame = frame
	local existing = motions[_frame]
	if existing ~= nil then
		return existing
	end
	local created = {
		target = clampFor(frame, frame.CanvasPosition),
		lastTouched = os.clock(),
	}
	local _frame_1 = frame
	motions[_frame_1] = created
	motionCount += 1
	ensureMotionDriver()
	return created
end
local addImpulse
function ensureMotionDriver()
	if not installed then
		return nil
	end
	if motionDriver ~= nil then
		return nil
	end
	local frameSkip = 0
	local signal = if CONSTRAINED_SCROLL then RunService.Heartbeat else RunService.RenderStepped
	motionDriver = signal:Connect(function(deltaTime)
		-- Constrained: advance coast every other heartbeat (~30Hz).
		if CONSTRAINED_SCROLL then
			frameSkip += 1
			if frameSkip % 2 == 1 and gamepadAxis.Magnitude <= 0.16 then
				return nil
			end
		end
		local selectedFrame = scrollingAncestor(GuiService.SelectedObject)
		if selectedFrame ~= nil and gamepadAxis.Magnitude > 0.16 then
			local speed = 260 + scrollPreference * 220
			local _gamepadAxis = gamepadAxis
			local _arg0 = speed * math.min(deltaTime, 0.05)
			local delta = _gamepadAxis * _arg0
			if selectedFrame.ScrollingDirection == Enum.ScrollingDirection.X then
				delta = Vector2.new(delta.X, 0)
			elseif selectedFrame.ScrollingDirection == Enum.ScrollingDirection.Y then
				delta = Vector2.new(0, delta.Y)
			end
			addImpulse(selectedFrame, delta, false)
		end
		local response = 14 - momentumPreference * 5
		local alpha = 1 - math.exp(-response * math.min(deltaTime, 0.05))
		local now = os.clock()
		for frame, motion in motions do
			if frame.Parent == nil or not frame.Visible or not frame.ScrollingEnabled then
				motions[frame] = nil
				motionCount = math.max(0, motionCount - 1)
				continue
			end
			motion.target = clampFor(frame, motion.target)
			local current = frame.CanvasPosition
			local settledPosition = current:Lerp(motion.target, alpha)
			frame.CanvasPosition = settledPosition
			local _target = motion.target
			local _condition = (settledPosition - _target).Magnitude < 0.45
			if _condition then
				_condition = now - motion.lastTouched > 0.08
			end
			if _condition then
				frame.CanvasPosition = motion.target
				motions[frame] = nil
				motionCount = math.max(0, motionCount - 1)
			end
		end
		local _condition = motionCount <= 0
		if _condition then
			_condition = gamepadAxis.Magnitude <= 0.16
		end
		if _condition then
			local _result = motionDriver
			if _result ~= nil then
				_result:Disconnect()
			end
			motionDriver = nil
			motionCount = 0
		end
	end)
end
function addImpulse(frame, delta, audible)
	if audible == nil then
		audible = true
	end
	if not installed then
		return nil
	end
	holdTitleFx()
	local motion = targetFor(frame)
	local _exp = frame
	local _target = motion.target
	local _delta = delta
	motion.target = clampFor(_exp, _target + _delta)
	motion.lastTouched = os.clock()
	if audible and os.clock() - lastScrollSound >= 0.095 then
		lastScrollSound = os.clock()
		Audio:play("scroll", math.clamp(0.92 + delta.Magnitude / 900, 0.92, 1.16))
	end
end
local function revealSelection(selected)
	if not installed then
		return nil
	end
	local frame = scrollingAncestor(selected)
	if frame == nil or selected == nil then
		return nil
	end
	local windowOrigin = frame.AbsolutePosition
	local windowSize = frame.AbsoluteWindowSize
	local itemOrigin = selected.AbsolutePosition
	local itemSize = selected.AbsoluteSize
	local margin = 14
	local deltaX = 0
	local deltaY = 0
	if itemOrigin.X < windowOrigin.X + margin then
		deltaX = itemOrigin.X - (windowOrigin.X + margin)
	elseif itemOrigin.X + itemSize.X > windowOrigin.X + windowSize.X - margin then
		deltaX = itemOrigin.X + itemSize.X - (windowOrigin.X + windowSize.X - margin)
	end
	if itemOrigin.Y < windowOrigin.Y + margin then
		deltaY = itemOrigin.Y - (windowOrigin.Y + margin)
	elseif itemOrigin.Y + itemSize.Y > windowOrigin.Y + windowSize.Y - margin then
		deltaY = itemOrigin.Y + itemSize.Y - (windowOrigin.Y + windowSize.Y - margin)
	end
	if frame.ScrollingDirection == Enum.ScrollingDirection.X then
		deltaY = 0
	end
	if frame.ScrollingDirection == Enum.ScrollingDirection.Y then
		deltaX = 0
	end
	if math.abs(deltaX) > 0.5 or math.abs(deltaY) > 0.5 then
		addImpulse(frame, Vector2.new(deltaX, deltaY), false)
	end
end
local boundScrolls = {}
local function bindLayoutUtil(frame)
	local _frame = frame
	if boundScrolls[_frame] ~= nil then
		return nil
	end
	local _frame_1 = frame
	boundScrolls[_frame_1] = true
	local resizeConnection
	local apply = function()
		if frame.Parent == nil then
			return nil
		end
		local _result = resizeConnection
		if _result ~= nil then
			_result:Disconnect()
		end
		resizeConnection = nil
		local layout = frame:FindFirstChildWhichIsA("UIListLayout") or frame:FindFirstChildWhichIsA("UIGridLayout")
		if layout == nil then
			return nil
		end
		if layout:IsA("UIGridLayout") then
			pcall(function()
				return LayoutUtil.grid(layout, frame.AbsoluteSize)
			end)
		end
		local axis = if frame.ScrollingDirection == Enum.ScrollingDirection.X then Enum.AutomaticSize.X elseif frame.ScrollingDirection == Enum.ScrollingDirection.XY then Enum.AutomaticSize.XY else Enum.AutomaticSize.Y
		local ok, connection = pcall(function()
			return LayoutUtil.resize(frame, layout, axis)
		end)
		if ok and connection ~= nil then
			resizeConnection = connection
		end
	end
	task.defer(apply)
	local added = frame.ChildAdded:Connect(function()
		return task.defer(apply)
	end)
	local scrolled = frame:GetPropertyChangedSignal("CanvasPosition"):Connect(holdTitleFx)
	frame.Destroying:Once(function()
		added:Disconnect()
		scrolled:Disconnect()
		local _result = resizeConnection
		if _result ~= nil then
			_result:Disconnect()
		end
		local _frame_2 = frame
		boundScrolls[_frame_2] = nil
	end)
end
local function watchPlayerGui(playerGui)
	for _, descendant in playerGui:GetDescendants() do
		if descendant:IsA("ScrollingFrame") then
			bindLayoutUtil(descendant)
		end
	end
	return playerGui.DescendantAdded:Connect(function(instance)
		if instance:IsA("ScrollingFrame") then
			bindLayoutUtil(instance)
		end
	end)
end
local function installScrollPerformance()
	if installed then
		return disposeScrollPerformance
	end
	installed = true
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui ~= nil then
		local _arg0 = watchPlayerGui(playerGui)
		table.insert(globalConnections, _arg0)
	else
		local _arg0 = Players.LocalPlayer.ChildAdded:Connect(function(child)
			if child:IsA("PlayerGui") then
				local _arg0_1 = watchPlayerGui(child)
				table.insert(globalConnections, _arg0_1)
			end
		end)
		table.insert(globalConnections, _arg0)
	end
	local _arg0 = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return nil
		end
		-- Nothing is coasting, so there is nothing to stop — skip the rest entirely. This is the
		-- common case for every tap on a phone and GetGuiObjectsAtPosition is not cheap.
		if motionCount <= 0 then
			return nil
		end
		local position = Vector2.new(input.Position.X, input.Position.Y)
		-- A touch that starts on a system gesture edge is the OS's, not ours. Leave every list
		-- exactly as it is so an edge-swipe-back does not also drag the page underneath it.
		if input.UserInputType == Enum.UserInputType.Touch and inSystemGestureZone(position) then
			return nil
		end
		-- Stop the fling the finger actually landed on, not every fling in the game. Clearing the
		-- whole map meant a tap on one panel froze an unrelated list mid-scroll, and two nested
		-- surfaces (a horizontal carousel inside a vertical page) cancelled each other constantly.
		local frame = frameUnderInput(position)
		if frame ~= nil and motions[frame] ~= nil then
			motions[frame] = nil
			motionCount = math.max(0, motionCount - 1)
		end
	end)
	table.insert(globalConnections, _arg0)
	local _arg0_1 = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local direction = input.Position.Z
			if direction == 0 then
				return nil
			end
			task.defer(function()
				if not installed then
					return nil
				end
				local frame = frameUnderPointer()
				if frame == nil then
					return nil
				end
				local travel = 78 + scrollPreference * 110
				local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
				local horizontal = frame.ScrollingDirection == Enum.ScrollingDirection.X or (shift and frame.ScrollingDirection == Enum.ScrollingDirection.XY)
				addImpulse(frame, if horizontal then Vector2.new(-direction * travel, 0) else Vector2.new(0, -direction * travel))
			end)
			return nil
		end
		if input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick2 then
			gamepadAxis = Vector2.new(input.Position.X, -input.Position.Y)
			if gamepadAxis.Magnitude > 0.16 then
				ensureMotionDriver()
			end
		end
	end)
	table.insert(globalConnections, _arg0_1)
	local _arg0_2 = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick2 then
			gamepadAxis = Vector2.zero
		end
	end)
	table.insert(globalConnections, _arg0_2)
	local _arg0_3 = GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
		task.defer(function()
			if installed then
				revealSelection(GuiService.SelectedObject)
			end
		end)
	end)
	table.insert(globalConnections, _arg0_3)
	return disposeScrollPerformance
end
local function breakpointColumns(width, fallback, breakpoints)
	if breakpoints == nil or #breakpoints == 0 then
		return fallback
	end
	local resolved = 1
	for _, point in breakpoints do
		if width >= point.minWidth then
			resolved = point.columns
		end
	end
	return resolved
end
local function AutoGrid(_param)
	local columns = _param.columns
	local cellHeight = _param.cellHeight
	local gap = _param.gap
	if gap == nil then
		gap = 8
	end
	local rowGap = _param.rowGap
	if rowGap == nil then
		rowGap = gap
	end
	local columnGap = _param.columnGap
	if columnGap == nil then
		columnGap = gap
	end
	local minColumns = _param.minColumns
	if minColumns == nil then
		minColumns = 1
	end
	local minCellWidth = _param.minCellWidth
	local maxCellWidth = _param.maxCellWidth
	local cellAspectRatio = _param.cellAspectRatio
	local breakpoints = _param.breakpoints
	local pack = _param.pack
	if pack == nil then
		pack = false
	end
	local horizontalAlignment = _param.horizontalAlignment
	if horizontalAlignment == nil then
		horizontalAlignment = Enum.HorizontalAlignment.Center
	end
	local verticalAlignment = _param.verticalAlignment
	if verticalAlignment == nil then
		verticalAlignment = Enum.VerticalAlignment.Top
	end
	local startCorner = _param.startCorner
	if startCorner == nil then
		startCorner = Enum.StartCorner.TopLeft
	end
	local fillDirection = _param.fillDirection
	if fillDirection == nil then
		fillDirection = Enum.FillDirection.Horizontal
	end
	local sortOrder = _param.sortOrder
	if sortOrder == nil then
		sortOrder = Enum.SortOrder.LayoutOrder
	end
	local autoCanvas = _param.autoCanvas
	if autoCanvas == nil then
		autoCanvas = false
	end
	local canvasTail = _param.canvasTail
	if canvasTail == nil then
		canvasTail = 0
	end
	local onLayout = _param.onLayout
	local layoutRef = React.useRef()
	local callbackRef = React.useRef(onLayout)
	callbackRef.current = onLayout
	React.useEffect(function()
		local layout = layoutRef.current
		local _parent = layout
		if _parent ~= nil then
			_parent = _parent.Parent
		end
		local parent = _parent
		if layout == nil or parent == nil or not parent:IsA("GuiObject") then
			return nil
		end
		local alive = true
		local scheduled = false
		local previous = ""
		local sync = function()
			scheduled = false
			if not alive or layout.Parent == nil or parent.Parent == nil then
				return nil
			end
			local parentWidth = math.max(1, math.floor(parent.AbsoluteSize.X + 0.5))
			local preferred = breakpointColumns(parentWidth, columns, if pack then PACK_BREAKPOINTS else breakpoints)
			local widthDriven = if minCellWidth ~= nil then math.floor((parentWidth + columnGap) / math.max(1, minCellWidth + columnGap)) else preferred
			local maximumColumns = math.max(1, math.floor(columns))
			local minimumColumns = math.clamp(math.floor(minColumns), 1, maximumColumns)
			local count = math.clamp(math.min(preferred, widthDriven), minimumColumns, maximumColumns)
			local available = math.max(1, parentWidth - columnGap * (count - 1))
			local _condition = maxCellWidth
			if _condition == nil then
				_condition = math.huge
			end
			local resolvedWidth = math.max(1, math.floor(math.min(_condition, available / count)))
			local resolvedHeight = if cellAspectRatio ~= nil and cellAspectRatio > 0 then math.max(1, math.floor(resolvedWidth / cellAspectRatio + 0.5)) else math.max(1, math.floor(cellHeight))
			local signature = `{count}:{resolvedWidth}:{resolvedHeight}:{columnGap}:{rowGap}`
			if signature ~= previous then
				previous = signature
				layout.CellPadding = UDim2.fromOffset(columnGap, rowGap)
				layout.CellSize = UDim2.fromOffset(resolvedWidth, resolvedHeight)
				layout.FillDirectionMaxCells = count
				local _result = callbackRef.current
				if _result ~= nil then
					_result({
						columns = count,
						cellWidth = resolvedWidth,
						cellHeight = resolvedHeight,
						contentWidth = resolvedWidth * count + columnGap * (count - 1),
					})
				end
			end
			if autoCanvas and parent:IsA("ScrollingFrame") then
				local height = math.max(0, math.ceil(layout.AbsoluteContentSize.Y + canvasTail))
				if parent.CanvasSize.Y.Offset ~= height or parent.CanvasSize.Y.Scale ~= 0 then
					parent.CanvasSize = UDim2.new(parent.CanvasSize.X.Scale, parent.CanvasSize.X.Offset, 0, height)
				end
			end
		end
		local schedule = function()
			if scheduled then
				return nil
			end
			scheduled = true
			task.defer(sync)
		end
		sync()
		local sizeConnection = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(schedule)
		local contentConnection = layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(schedule)
		return function()
			alive = false
			sizeConnection:Disconnect()
			contentConnection:Disconnect()
		end
	end, { autoCanvas, breakpoints, canvasTail, cellAspectRatio, cellHeight, columnGap, columns, maxCellWidth, minCellWidth, minColumns, pack, rowGap })
	local count = math.max(1, math.floor(columns))
	return React.createElement("uigridlayout", {
		ref = layoutRef,
		CellSize = UDim2.new(1 / count, -(columnGap * (count - 1)) / count, 0, cellHeight),
		CellPadding = UDim2.fromOffset(columnGap, rowGap),
		FillDirection = fillDirection,
		FillDirectionMaxCells = count,
		HorizontalAlignment = horizontalAlignment,
		VerticalAlignment = verticalAlignment,
		StartCorner = startCorner,
		SortOrder = sortOrder,
	})
end
--[[
	*
	 * Virtualizes a fixed-row-height grid (1..N columns) inside an existing ScrollingFrame:
	 * only mounts item instances whose row overlaps the visible viewport (+ overscanRows of
	 * slack on each side), instead of building every row's full subtree up front. Newly
	 * revealed rows mount one row-batch per heartbeat rather than all at once, so a big scroll
	 * jump (drag-to-bottom, PageDown) doesn't spike a single frame with dozens of instance
	 * creations. Positions itself absolutely (Position prop on the host frame) so it composes
	 * inside a page that lays out sections with a uilistlayout — the host's own Size still
	 * participates in that layout normally.
	 
]]
local function VirtualGrid(_param)
	local scrollRef = _param.scrollRef
	local count = _param.count
	local columns = _param.columns
	local cellHeight = _param.cellHeight
	local gap = _param.gap
	local overscanRows = _param.overscanRows
	if overscanRows == nil or overscanRows < 1 then
		-- One extra row stays mounted so a card that is half on screen is not
		-- unmounted and clipped while the page is still scrolling.
		overscanRows = 1
	end
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local position = _param.position
	local itemKey = _param.itemKey
	local renderItem = _param.renderItem
	local hostRef = React.useRef()
	local rows = math.ceil(count / math.max(1, columns))
	local stride = cellHeight + gap
	local height = math.max(0, rows * cellHeight + math.max(0, rows - 1) * gap)
	local seedLast = if count <= 0 then -1 else math.min(count - 1, math.max(columns * 3, columns) - 1)
	local initial = {
		first = 0,
		last = seedLast,
	}
	local window, setWindow = React.useState(initial)
	local latest = React.useRef(initial)
	React.useEffect(function()
		local host = hostRef.current
		local scroll = scrollRef.current
		if host == nil or scroll == nil or count <= 0 then
			return nil
		end
		local alive = true
		local sync = function()
			if not alive or host.Parent == nil or scroll.Parent == nil then
				return nil
			end
			local viewportTop = scroll.AbsolutePosition.Y
			local viewportBottom = viewportTop + math.max(1, scroll.AbsoluteWindowSize.Y)
			local hostTop = host.AbsolutePosition.Y
			local hostBottom = hostTop + host.AbsoluteSize.Y
			local first = 0
			local last = -1
			if hostBottom >= viewportTop - stride * overscanRows and hostTop <= viewportBottom + stride * overscanRows then
				local firstRow = math.clamp(math.floor((viewportTop - hostTop) / stride) - overscanRows, 0, math.max(0, rows - 1))
				local lastRow = math.clamp(math.floor((viewportBottom - hostTop) / stride) + overscanRows, firstRow, math.max(0, rows - 1))
				first = firstRow * columns
				last = math.min(count - 1, (lastRow + 1) * columns - 1)
			end
			local previous = latest.current
			if previous.first == first and previous.last == last then
				return nil
			end
			local nextWindow = {
				first = first,
				last = last,
			}
			latest.current = nextWindow
			setWindow(nextWindow)
		end
		local connections = { scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(sync), scroll:GetPropertyChangedSignal("AbsolutePosition"):Connect(sync), scroll:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(sync), host:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync) }
		task.defer(sync)
		return function()
			alive = false
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, { cellHeight, columns, count, gap, overscanRows, rows, scrollRef, stride })
	local visible = {}
	if window.last >= window.first then
		do
			local index = window.first
			local _shouldIncrement = false
			while true do
				if _shouldIncrement then
					index += 1
				else
					_shouldIncrement = true
				end
				if not (index <= window.last) then
					break
				end
				local row = math.floor(index / columns)
				local column = index % columns
				visible[itemKey(index)] = React.createElement("frame", {
					Size = UDim2.new(1 / columns, -(gap * (columns - 1)) / columns, 0, cellHeight),
					Position = UDim2.new(column / columns, (column * gap) / columns, 0, row * stride),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Active = false,
				}, renderItem(index))
			end
		end
	end
	return React.createElement("frame", {
		ref = hostRef,
		Size = UDim2.new(1, 0, 0, height),
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Active = false,
		ClipsDescendants = false,
	}, visible)
end
local function useVirtualWindow(count, stride, topOffset, overscan)
	if overscan == nil then
		-- Constrained devices mount fewer offscreen rows; one row of slack is enough
		-- and cuts React mounts during fast flings roughly in half vs overscan=2.
		overscan = if CONSTRAINED_SCROLL then 1 else 2
	end
	overscan = math.max(1, overscan)
	local frame = React.useRef()
	local initial = {
		first = 0,
		last = math.min(math.max(0, count - 1), if CONSTRAINED_SCROLL then 6 else 10),
	}
	local window, setWindow = React.useState(initial)
	local latest = React.useRef(initial)
	React.useEffect(function()
		local scrolling = frame.current
		if not scrolling then
			return nil
		end
		local scheduled = false
		local alive = true
		local sync = function()
			scheduled = false
			if not alive then
				return nil
			end
			if count <= 0 then
				local empty = {
					first = 0,
					last = -1,
				}
				latest.current = empty
				setWindow(empty)
				return nil
			end
			local top = scrolling.CanvasPosition.Y
			local height = math.max(1, scrolling.AbsoluteWindowSize.Y)
			local first = math.clamp(math.floor((top - topOffset) / stride) - overscan, 0, count - 1)
			local last = math.clamp(math.ceil((top + height - topOffset) / stride) + overscan, first, count - 1)
			local previous = latest.current
			if previous.first == first and previous.last == last then
				return nil
			end
			local range = {
				first = first,
				last = last,
			}
			latest.current = range
			setWindow(range)
		end
		-- Coalesce CanvasPosition storms from flings into one defer per frame.
		local schedule = function()
			if scheduled then
				return nil
			end
			scheduled = true
			task.defer(sync)
		end
		sync()
		local moved = scrolling:GetPropertyChangedSignal("CanvasPosition"):Connect(schedule)
		local resized = scrolling:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(schedule)
		return function()
			alive = false
			moved:Disconnect()
			resized:Disconnect()
		end
	end, { count, overscan, stride, topOffset })
	return {
		frame = frame,
		first = window.first,
		last = window.last,
	}
end
return {
	disposeScrollPerformance = disposeScrollPerformance,
	setScrollSpeed = setScrollSpeed,
	setScrollMomentum = setScrollMomentum,
	installScrollPerformance = installScrollPerformance,
	AutoGrid = AutoGrid,
	VirtualGrid = VirtualGrid,
	useVirtualWindow = useVirtualWindow,
}

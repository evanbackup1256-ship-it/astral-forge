local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReactRoblox = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["react-roblox"])
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local _motion = require(script.Parent.motion)
local useExitTransition = _motion.useExitTransition
local useFlipperSpring = _motion.useFlipperSpring
local usePulse = _motion.usePulse
local useViewport = _motion.useViewport
local EDIT_BOUNDS = require(script.Parent.mobileLayout).EDIT_BOUNDS
local _theme = require(script.Parent.theme)
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local surfaceGradient = _theme.surfaceGradient
local _ui = require(script.Parent.ui)
local Button = _ui.Button
local Text = _ui.Text
local _format = require(script.Parent.format)
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local Audio = require(script.Parent.audio).Audio
local dragHandles = {}
local editMode = false
local dragId
local dragInput
local dragOffset = Vector2.zero
local dragLastCell = Vector2.zero
local dragChanged
local dragEnded
local dragFocusReleased
local dragMenuOpened
local function cancelDrag()
	dragId = nil
	dragInput = nil
end
local function clampDrag(pos, bounds)
	return Vector2.new(math.clamp(pos.X, bounds.minX, bounds.maxX), math.clamp(pos.Y, bounds.minY, bounds.maxY))
end
local function ensureDragging()
	if dragChanged ~= nil then
		return nil
	end
	dragChanged = UserInputService.InputChanged:Connect(function(input)
		if not editMode or dragId == nil or dragInput == nil then
			return nil
		end
		if dragInput.UserInputType == Enum.UserInputType.Touch then
			if input ~= dragInput then
				return nil
			end
		elseif dragInput.UserInputType == Enum.UserInputType.MouseButton1 then
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then
				return nil
			end
		else
			return nil
		end
		local _dragId = dragId
		local handle = dragHandles[_dragId]
		if handle == nil then
			return nil
		end
		local raw = Vector2.new(input.Position.X - dragOffset.X, input.Position.Y - dragOffset.Y)
		local _condition = handle.snap
		if _condition == nil then
			_condition = 1
		end
		local grid = math.max(1, _condition)
		local cellX = math.round(raw.X / grid)
		local cellY = math.round(raw.Y / grid)
		local resolvedPosition = clampDrag(Vector2.new(cellX * grid, cellY * grid), handle.bounds)
		handle.position = resolvedPosition
		local _result = handle.onMove
		if _result ~= nil then
			_result(resolvedPosition)
		end
		-- Tick only when the snapped cell actually changes, not every frame —
		-- a per-pixel sound during drag would just be noise, but a tick each
		-- time the element locks to a new grid cell gives real tactile feedback.
		if cellX ~= dragLastCell.X or cellY ~= dragLastCell.Y then
			dragLastCell = Vector2.new(cellX, cellY)
			Audio:play("sliderStep", 1.1)
		end
	end)
	dragEnded = UserInputService.InputEnded:Connect(function(input)
		if dragInput == nil then
			return nil
		end
		local exactTouch = dragInput.UserInputType == Enum.UserInputType.Touch and input == dragInput
		local mouseRelease = dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1
		if exactTouch or mouseRelease then
			cancelDrag()
		end
	end)
	dragFocusReleased = UserInputService.WindowFocusReleased:Connect(cancelDrag)
	dragMenuOpened = GuiService.MenuOpened:Connect(cancelDrag)
end
local MobileDragging = {
	setEditMode = function(self, on)
		editMode = on
		if not on then
			cancelDrag()
		end
		ensureDragging()
	end,
	register = function(self, handle)
		ensureDragging()
		local _id = handle.id
		local _handle = handle
		dragHandles[_id] = _handle
		return function()
			local _id_1 = handle.id
			dragHandles[_id_1] = nil
			if dragId == handle.id then
				cancelDrag()
			end
		end
	end,
	beginDrag = function(self, id, input)
		if not editMode then
			return nil
		end
		local _id = id
		local handle = dragHandles[_id]
		if handle == nil then
			return nil
		end
		Audio:play("filterPick", 0.92)
		dragId = id
		dragInput = input
		dragOffset = Vector2.new(input.Position.X - handle.position.X, input.Position.Y - handle.position.Y)
		local _condition = handle.snap
		if _condition == nil then
			_condition = 1
		end
		local grid = math.max(1, _condition)
		dragLastCell = Vector2.new(math.round(handle.position.X / grid), math.round(handle.position.Y / grid))
	end,
	setPosition = function(self, id, pos)
		local _id = id
		local handle = dragHandles[_id]
		if handle == nil then
			return nil
		end
		handle.position = clampDrag(pos, handle.bounds)
		local _result = handle.onMove
		if _result ~= nil then
			_result(handle.position)
		end
	end,
	dispose = function(self)
		local _result = dragChanged
		if _result ~= nil then
			_result:Disconnect()
		end
		local _result_1 = dragEnded
		if _result_1 ~= nil then
			_result_1:Disconnect()
		end
		local _result_2 = dragFocusReleased
		if _result_2 ~= nil then
			_result_2:Disconnect()
		end
		local _result_3 = dragMenuOpened
		if _result_3 ~= nil then
			_result_3:Disconnect()
		end
		dragChanged = nil
		dragEnded = nil
		dragFocusReleased = nil
		dragMenuOpened = nil
		table.clear(dragHandles)
		cancelDrag()
		editMode = false
	end,
}
local function slotPixels(slot, width, height)
	local _condition = slot.width
	if _condition == nil then
		_condition = 112
	end
	local slotW = _condition
	local _condition_1 = slot.height
	if _condition_1 == nil then
		_condition_1 = 62
	end
	local slotH = _condition_1
	local _exp = slot.x * width
	local _condition_2 = slot.anchorX
	if _condition_2 == nil then
		_condition_2 = 0.5
	end
	local _exp_1 = _exp - slotW * _condition_2
	local _exp_2 = slot.y * height
	local _condition_3 = slot.anchorY
	if _condition_3 == nil then
		_condition_3 = 0.5
	end
	return Vector2.new(_exp_1, _exp_2 - slotH * _condition_3)
end
local function slotBounds(slot, width, height, sideInset, topInset, bottomInset)
	local _condition = slot.width
	if _condition == nil then
		_condition = 112
	end
	local slotW = _condition
	local _condition_1 = slot.height
	if _condition_1 == nil then
		_condition_1 = 62
	end
	local slotH = _condition_1
	local minX = math.max(8, sideInset + 8)
	local _exp = topInset + 8
	local _condition_2 = slot.safeTop
	if _condition_2 == nil then
		_condition_2 = 0
	end
	local minY = math.max(48, _exp, _condition_2)
	return {
		minX = minX,
		maxX = math.max(minX, width - sideInset - slotW - 8),
		minY = minY,
		maxY = math.max(minY, height - bottomInset - slotH - 8),
	}
end
local function safeSlotPosition(slot, position, width, height, sideInset, topInset, bottomInset)
	local bounds = slotBounds(slot, width, height, sideInset, topInset, bottomInset)
	return Vector2.new(math.clamp(position.X, bounds.minX, bounds.maxX), math.clamp(position.Y, bounds.minY, bounds.maxY))
end
local function MobileControls(_param)
	local slots = _param.slots
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local visible = _param.visible
	local onClose = _param.onClose
	local scales = _param.scales
	local opacities = _param.opacities
	local viewport = useViewport()
	local editing, setEditing = React.useState(false)
	local snap, setSnap = React.useState(true)
	local snapStep, setSnapStep = React.useState(16)
	local fine, setFine = React.useState(false)
	local showThirds, setShowThirds = React.useState(false)
	local selectedId, setSelectedId = React.useState()
	local locked, setLocked = React.useState({})
	local history, setHistory = React.useState({})
	local redo, setRedo = React.useState({})
	local positions, setPositions = React.useState({})
	local _binding = useExitTransition(reducedMotion, 0.38, visible)
	local exit = _binding[1]
	local exiting = _binding[2]
	local beginExit = _binding[3]
	local requestClose = React.useCallback(function()
		if not exiting then
			beginExit(onClose)
		end
	end, { beginExit, exiting, onClose })
	local screen = React.useState(function()
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		local rootScreen = playerGui:FindFirstChild("AstralForgeStudioUI")
		return if rootScreen ~= nil and rootScreen:IsA("ScreenGui") then rootScreen else playerGui
	end)
	local positionsRef = React.useRef(positions)
	positionsRef.current = positions
	React.useEffect(function()
		return function()
			MobileDragging:dispose()
		end
	end, {})
	React.useEffect(function()
		if not visible then
			return nil
		end
		local initialPositions = {}
		for _, slot in slots do
			initialPositions[slot.id] = safeSlotPosition(slot, slotPixels(slot, viewport.width, viewport.height), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		end
		positionsRef.current = initialPositions
		setPositions(initialPositions)
	end, { slots, viewport.bottomInset, viewport.height, viewport.sideInset, viewport.topInset, viewport.width, visible })
	React.useEffect(function()
		if not visible then
			MobileDragging:setEditMode(false)
			setEditing(false)
			return nil
		end
		local cleanups = {}
		local _object = table.clone(positionsRef.current)
		setmetatable(_object, nil)
		local corrected = _object
		local correctedAny = false
		for _, slot in slots do
			local bounds = slotBounds(slot, viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
			local raw = positionsRef.current[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			local position = safeSlotPosition(slot, raw, viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
			if position.X ~= raw.X or position.Y ~= raw.Y then
				corrected[slot.id] = position
				correctedAny = true
			end
			local _arg0 = MobileDragging:register({
				id = slot.id,
				position = position,
				bounds = bounds,
				snap = if snap then snapStep else 1,
				onMove = function(nextPosition)
					return setPositions(function(current)
						local _object_1 = table.clone(current)
						setmetatable(_object_1, nil)
						_object_1[slot.id] = nextPosition
						return _object_1
					end)
				end,
			})
			table.insert(cleanups, _arg0)
		end
		if correctedAny then
			positionsRef.current = corrected
			setPositions(corrected)
		end
		return function()
			for _, dispose in cleanups do
				dispose()
			end
		end
	end, { slots, snap, snapStep, viewport.bottomInset, viewport.height, viewport.sideInset, viewport.topInset, viewport.width, visible })
	React.useEffect(function()
		MobileDragging:setEditMode(editing and visible)
		return function()
			return MobileDragging:setEditMode(false)
		end
	end, { editing, visible })
	local layoutOverlaps = function(source)
		for index = 0, #slots - 1 do
			local slot = slots[index + 1]
			local pos = source[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			local _condition = slot.width
			if _condition == nil then
				_condition = 112
			end
			local width = _condition
			local _condition_1 = slot.height
			if _condition_1 == nil then
				_condition_1 = 62
			end
			local height = _condition_1
			do
				local otherIndex = index + 1
				local _shouldIncrement = false
				while true do
					if _shouldIncrement then
						otherIndex += 1
					else
						_shouldIncrement = true
					end
					if not (otherIndex < #slots) then
						break
					end
					local other = slots[otherIndex + 1]
					local otherPos = source[other.id] or slotPixels(other, viewport.width, viewport.height)
					local _condition_2 = other.width
					if _condition_2 == nil then
						_condition_2 = 112
					end
					local otherWidth = _condition_2
					local _condition_3 = other.height
					if _condition_3 == nil then
						_condition_3 = 62
					end
					local otherHeight = _condition_3
					local separated = pos.X + width + 6 <= otherPos.X or otherPos.X + otherWidth + 6 <= pos.X or pos.Y + height + 6 <= otherPos.Y or otherPos.Y + otherHeight + 6 <= pos.Y
					if not separated then
						return true
					end
				end
			end
		end
		return false
	end
	local save = function(source)
		if source == nil then
			source = positionsRef.current
		end
		if layoutOverlaps(source) then
			return false
		end
		local values = {}
		for _, slot in slots do
			local raw = source[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			local pos = safeSlotPosition(slot, raw, viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
			local _condition = slot.width
			if _condition == nil then
				_condition = 112
			end
			local slotW = _condition
			local _condition_1 = slot.height
			if _condition_1 == nil then
				_condition_1 = 62
			end
			local slotH = _condition_1
			local _exp = pos.X
			local _condition_2 = slot.anchorX
			if _condition_2 == nil then
				_condition_2 = 0.5
			end
			values[slot.xKey] = math.clamp((_exp + slotW * _condition_2) / viewport.width, 0, 1)
			local _exp_1 = pos.Y
			local _condition_3 = slot.anchorY
			if _condition_3 == nil then
				_condition_3 = 0.5
			end
			values[slot.yKey] = math.clamp((_exp_1 + slotH * _condition_3) / viewport.height, 0, 1)
		end
		dispatch("SetMobileLayout", {
			Values = values,
		})
		return true
	end
	local finishEditing = function()
		if not save() then
			return false
		end
		setEditing(false)
		return true
	end
	local capStack = function(source, extra)
		local _array = {}
		local _length = #_array
		table.move(source, 1, #source, _length + 1, _array)
		local nextHist = _array
		local _object = table.clone(extra)
		setmetatable(_object, nil)
		table.insert(nextHist, _object)
		if #nextHist <= 12 then
			return nextHist
		end
		local trimmed = {}
		for index = #nextHist - 12, #nextHist - 1 do
			local _arg0 = nextHist[index + 1]
			table.insert(trimmed, _arg0)
		end
		return trimmed
	end
	local applyPositions = function(nextPos)
		positionsRef.current = nextPos
		setPositions(nextPos)
		for _, slot in slots do
			local pos = nextPos[slot.id]
			if pos ~= nil then
				MobileDragging:setPosition(slot.id, pos)
			end
		end
	end
	local pushHistory = function(source)
		setHistory(function(current)
			return capStack(current, source)
		end)
		setRedo({})
	end
	local undoLayout = function()
		if #history == 0 then
			return nil
		end
		local prior = history[#history]
		if prior == nil then
			return nil
		end
		setRedo(function(current)
			return capStack(current, positionsRef.current)
		end)
		setHistory(function(current)
			-- ▼ ReadonlyArray.filter ▼
			local _newValue = {}
			local _callback = function(_, index)
				return index < #current - 1
			end
			local _length = 0
			for _k, _v in current do
				if _callback(_v, _k - 1, current) == true then
					_length += 1
					_newValue[_length] = _v
				end
			end
			-- ▲ ReadonlyArray.filter ▲
			return _newValue
		end)
		applyPositions(prior)
		Audio:play("close", 0.94)
	end
	local redoLayout = function()
		if #redo == 0 then
			return nil
		end
		local upcoming = redo[#redo]
		if upcoming == nil then
			return nil
		end
		setHistory(function(current)
			return capStack(current, positionsRef.current)
		end)
		setRedo(function(current)
			-- ▼ ReadonlyArray.filter ▼
			local _newValue = {}
			local _callback = function(_, index)
				return index < #current - 1
			end
			local _length = 0
			for _k, _v in current do
				if _callback(_v, _k - 1, current) == true then
					_length += 1
					_newValue[_length] = _v
				end
			end
			-- ▲ ReadonlyArray.filter ▲
			return _newValue
		end)
		applyPositions(upcoming)
		Audio:play("open", 1.04)
	end
	local nudgeSelected = function(dx, dy)
		local _condition = selectedId
		if _condition == nil then
			local _result = slots[1]
			if _result ~= nil then
				_result = _result.id
			end
			_condition = _result
		end
		local id = _condition
		if id == nil or locked[id] == true then
			return nil
		end
		-- ▼ ReadonlyArray.find ▼
		local _callback = function(entry)
			return entry.id == id
		end
		local _result
		for _i, _v in slots do
			if _callback(_v, _i - 1, slots) == true then
				_result = _v
				break
			end
		end
		-- ▲ ReadonlyArray.find ▲
		local slot = _result
		if slot == nil then
			return nil
		end
		pushHistory(positionsRef.current)
		local current = positionsRef.current[id] or slotPixels(slot, viewport.width, viewport.height)
		local step = if fine then 1 else (if snap then snapStep else 4)
		local moved = safeSlotPosition(slot, Vector2.new(current.X + dx * step, current.Y + dy * step), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		local _object = table.clone(positionsRef.current)
		setmetatable(_object, nil)
		_object[id] = moved
		applyPositions(_object)
	end
	local alignSelected = function(mode)
		local _condition = selectedId
		if _condition == nil then
			local _result = slots[1]
			if _result ~= nil then
				_result = _result.id
			end
			_condition = _result
		end
		local id = _condition
		if id == nil or locked[id] == true then
			return nil
		end
		-- ▼ ReadonlyArray.find ▼
		local _callback = function(entry)
			return entry.id == id
		end
		local _result
		for _i, _v in slots do
			if _callback(_v, _i - 1, slots) == true then
				_result = _v
				break
			end
		end
		-- ▲ ReadonlyArray.find ▲
		local slot = _result
		if slot == nil then
			return nil
		end
		pushHistory(positionsRef.current)
		local current = positionsRef.current[id] or slotPixels(slot, viewport.width, viewport.height)
		local _condition_1 = slot.width
		if _condition_1 == nil then
			_condition_1 = 112
		end
		local slotW = _condition_1
		local _condition_2 = slot.height
		if _condition_2 == nil then
			_condition_2 = 62
		end
		local slotH = _condition_2
		local bounds = slotBounds(slot, viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		local x = current.X
		local y = current.Y
		if mode == "left" then
			x = bounds.minX
		end
		if mode == "right" then
			x = bounds.maxX
		end
		if mode == "top" then
			y = bounds.minY
		end
		if mode == "bottom" then
			y = bounds.maxY
		end
		if mode == "cx" then
			x = math.floor((viewport.width - slotW) / 2)
		end
		if mode == "cy" then
			y = math.floor((viewport.height - slotH) / 2)
		end
		local _object = table.clone(positionsRef.current)
		setmetatable(_object, nil)
		_object[id] = safeSlotPosition(slot, Vector2.new(x, y), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		applyPositions(_object)
	end
	local unstackOverlaps = function()
		pushHistory(positionsRef.current)
		local _object = table.clone(positionsRef.current)
		setmetatable(_object, nil)
		local nextPos = _object
		for index = 0, #slots - 1 do
			local slot = slots[index + 1]
			if locked[slot.id] == true then
				continue
			end
			local pos = nextPos[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			local _condition = slot.width
			if _condition == nil then
				_condition = 112
			end
			local width = _condition
			local _condition_1 = slot.height
			if _condition_1 == nil then
				_condition_1 = 62
			end
			local height = _condition_1
			for otherIndex = 0, #slots - 1 do
				if otherIndex == index then
					continue
				end
				local other = slots[otherIndex + 1]
				local otherPos = nextPos[other.id] or slotPixels(other, viewport.width, viewport.height)
				local _condition_2 = other.width
				if _condition_2 == nil then
					_condition_2 = 112
				end
				local otherW = _condition_2
				local _condition_3 = other.height
				if _condition_3 == nil then
					_condition_3 = 62
				end
				local otherH = _condition_3
				local separated = pos.X + width + 8 <= otherPos.X or otherPos.X + otherW + 8 <= pos.X or pos.Y + height + 8 <= otherPos.Y or otherPos.Y + otherH + 8 <= pos.Y
				if separated then
					continue
				end
				pos = safeSlotPosition(slot, Vector2.new(pos.X, otherPos.Y + otherH + 12), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
			end
			nextPos[slot.id] = pos
		end
		applyPositions(nextPos)
		save(nextPos)
	end
	local bumpSelectedSetting = function(kind, delta)
		local _condition = selectedId
		if _condition == nil then
			local _result = slots[1]
			if _result ~= nil then
				_result = _result.id
			end
			_condition = _result
		end
		local id = _condition
		if id == nil then
			return nil
		end
		local key = if id == "quick" then (if kind == "scale" then "MobileQuickScale" else "MobileQuickOpacity") elseif id == "dock" then (if kind == "scale" then "MobileDockScale" else "MobileDockOpacity") else (if kind == "scale" then "MobileToastScale" else "MobileToastOpacity")
		local _result
		if kind == "scale" then
			local _result_1 = scales
			if _result_1 ~= nil then
				_result_1 = _result_1[id]
			end
			local _condition_1 = _result_1
			if _condition_1 == nil then
				_condition_1 = 0.5
			end
			_result = _condition_1
		else
			local _result_1 = opacities
			if _result_1 ~= nil then
				_result_1 = _result_1[id]
			end
			local _condition_1 = _result_1
			if _condition_1 == nil then
				_condition_1 = 0.85
			end
			_result = _condition_1
		end
		local current = _result
		dispatch("SetSetting", {
			Key = key,
			Value = math.clamp(current + delta, 0, 1),
		})
	end
	local resetLayout = function()
		local fresh = {}
		for _, slot in slots do
			local _object = table.clone(slot)
			setmetatable(_object, nil)
			_object.x = slot.defaultX
			_object.y = slot.defaultY
			local resetSlot = _object
			fresh[slot.id] = safeSlotPosition(slot, slotPixels(resetSlot, viewport.width, viewport.height), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		end
		if layoutOverlaps(fresh) then
			return nil
		end
		for _, slot in slots do
			MobileDragging:setPosition(slot.id, fresh[slot.id])
		end
		positionsRef.current = fresh
		setPositions(fresh)
		save(fresh)
	end
	local applyPreset = function(side)
		pushHistory(positionsRef.current)
		Audio:play("filterPick", 1.02)
		local fresh = {}
		for _, slot in slots do
			local x = slot.defaultX
			local y = slot.defaultY
			if side == "left" then
				if slot.id == "quick" then
					x = 0.28
					y = 0.72
				end
				if slot.id == "toasts" then
					x = 0.22
					y = 0.24
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "right" then
				if slot.id == "quick" then
					x = 0.72
					y = 0.72
				end
				if slot.id == "toasts" then
					x = 0.78
					y = 0.24
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "top" then
				if slot.id == "quick" then
					x = 0.5
					y = 0.22
				end
				if slot.id == "toasts" then
					x = 0.82
					y = 0.38
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "thumbs" then
				if slot.id == "quick" then
					x = 0.5
					y = 0.78
				end
				if slot.id == "toasts" then
					x = 0.5
					y = 0.18
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.93
				end
			elseif side == "tl" then
				if slot.id == "quick" then
					x = 0.22
					y = 0.22
				end
				if slot.id == "toasts" then
					x = 0.78
					y = 0.22
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "tr" then
				if slot.id == "quick" then
					x = 0.78
					y = 0.22
				end
				if slot.id == "toasts" then
					x = 0.22
					y = 0.22
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "bl" then
				if slot.id == "quick" then
					x = 0.22
					y = 0.78
				end
				if slot.id == "toasts" then
					x = 0.22
					y = 0.24
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			elseif side == "br" then
				if slot.id == "quick" then
					x = 0.78
					y = 0.78
				end
				if slot.id == "toasts" then
					x = 0.78
					y = 0.24
				end
				if slot.id == "dock" then
					x = 0.5
					y = 0.92
				end
			end
			local _object = table.clone(slot)
			setmetatable(_object, nil)
			_object.x = x
			_object.y = y
			fresh[slot.id] = safeSlotPosition(slot, slotPixels(_object, viewport.width, viewport.height), viewport.width, viewport.height, viewport.sideInset, viewport.topInset, viewport.bottomInset)
		end
		if layoutOverlaps(fresh) then
			return nil
		end
		applyPositions(fresh)
		save(fresh)
		if side == "left" or side == "bl" then
			dispatch("SetSetting", {
				Key = "MobileQuickReverse",
				Value = 1,
			})
		end
		if side == "right" or side == "br" then
			dispatch("SetSetting", {
				Key = "MobileQuickReverse",
				Value = 0,
			})
		end
	end
	local overlaps = function(slot, pos)
		local _condition = slot.width
		if _condition == nil then
			_condition = 112
		end
		local w = _condition
		local _condition_1 = slot.height
		if _condition_1 == nil then
			_condition_1 = 62
		end
		local h = _condition_1
		for _, other in slots do
			if other.id == slot.id then
				continue
			end
			local otherPos = positions[other.id] or slotPixels(other, viewport.width, viewport.height)
			local _condition_2 = other.width
			if _condition_2 == nil then
				_condition_2 = 112
			end
			local otherW = _condition_2
			local _condition_3 = other.height
			if _condition_3 == nil then
				_condition_3 = 62
			end
			local otherH = _condition_3
			local separated = pos.X + w + 6 <= otherPos.X or otherPos.X + otherW + 6 <= pos.X or pos.Y + h + 6 <= otherPos.Y or otherPos.Y + otherH + 6 <= pos.Y
			if not separated then
				return true
			end
		end
		return false
	end
	local collisionPresent = layoutOverlaps(positions)
	if not visible then
		return ReactRoblox.createPortal(React.createElement("frame", {
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}), screen)
	end
	local editorToolbarY = math.max(if viewport.width > viewport.height and viewport.height < 500 then 56 else 8, viewport.topInset + 8)
	local topToolbarBottom = editorToolbarY + TapTarget * 2 + 16 + 8
	local bottomBarY = math.max(topToolbarBottom, viewport.height - viewport.bottomInset - (TapTarget * 2 + 16))
	local gridMarks = if showThirds then { 1 / 3, 0.5, 2 / 3 } else { 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9 }
	-- ▼ ReadonlyArray.find ▼
	local _callback = function(entry)
		local _exp = entry.id
		local _condition = selectedId
		if _condition == nil then
			local _result = slots[1]
			if _result ~= nil then
				_result = _result.id
			end
			_condition = _result
		end
		return _exp == _condition
	end
	local _result
	for _i, _v in slots do
		if _callback(_v, _i - 1, slots) == true then
			_result = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local selectedSlot = _result
	local selectedPos = if selectedSlot ~= nil then (positions[selectedSlot.id] or slotPixels(selectedSlot, viewport.width, viewport.height)) else nil
	local selectedLocked = selectedSlot ~= nil and locked[selectedSlot.id] == true
	local _condition = editing
	if _condition then
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#gridMarks)
		local _callback_1 = function(x)
			return React.createElement("frame", {
				key = `grid-x-{x}`,
				Size = UDim2.new(0, 1, 1, 0),
				Position = UDim2.new(x, 0, 0, 0),
				BackgroundColor3 = if x == 0.5 then Palette.mint else Palette.cyan,
				BackgroundTransparency = if x == 0.5 then 0.72 else 0.9,
				BorderSizePixel = 0,
				ZIndex = 500,
				Active = false,
			})
		end
		for _k, _v in gridMarks do
			_newValue[_k] = _callback_1(_v, _k - 1, gridMarks)
		end
		-- ▲ ReadonlyArray.map ▲
		_condition = _newValue
	end
	local _condition_1 = editing
	if _condition_1 then
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#gridMarks)
		local _callback_1 = function(y)
			return React.createElement("frame", {
				key = `grid-y-{y}`,
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.new(0, 0, y, 0),
				BackgroundColor3 = if y == 0.5 then Palette.mint else Palette.cyan,
				BackgroundTransparency = if y == 0.5 then 0.72 else 0.9,
				BorderSizePixel = 0,
				ZIndex = 500,
				Active = false,
			})
		end
		for _k, _v in gridMarks do
			_newValue[_k] = _callback_1(_v, _k - 1, gridMarks)
		end
		-- ▲ ReadonlyArray.map ▲
		_condition_1 = _newValue
	end
	local _condition_2 = editing
	if _condition_2 then
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#slots)
		local _callback_1 = function(slot)
			local _condition_3 = slot.width
			if _condition_3 == nil then
				_condition_3 = 112
			end
			local slotW = _condition_3
			local _condition_4 = slot.height
			if _condition_4 == nil then
				_condition_4 = 62
			end
			local slotH = _condition_4
			local pos = positions[slot.id] or slotPixels(slot, viewport.width, viewport.height)
			local collision = overlaps(slot, pos)
			local isLocked = locked[slot.id] == true
			local accent = if collision then Palette.coral elseif selectedId == slot.id then Palette.mint elseif isLocked then Palette.mango else EDIT_BOUNDS
			local pctX = math.floor(((pos.X + slotW * 0.5) / viewport.width) * 100)
			local pctY = math.floor(((pos.Y + slotH * 0.5) / viewport.height) * 100)
			return React.createElement("frame", {
				key = slot.id,
				Size = UDim2.fromOffset(slotW, slotH),
				Position = UDim2.fromOffset(pos.X, pos.Y),
				BackgroundColor3 = Palette.panelRaised,
				BackgroundTransparency = 0.04,
				BorderSizePixel = 0,
				ZIndex = 502,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 14),
			}), React.createElement("uistroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				LineJoinMode = Enum.LineJoinMode.Round,
				Color = accent,
				Thickness = if collision then 3 else 2,
				Transparency = 0.08,
			}), React.createElement("frame", {
				Size = UDim2.fromOffset(22, 22),
				Position = UDim2.fromOffset(-7, -7),
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
				ZIndex = 505,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(1, 0),
			}), React.createElement(Text, {
				value = if isLocked then "L" else "+",
				size = 14,
				color = Palette.ink,
				weight = Enum.FontWeight.Heavy,
				align = Enum.TextXAlignment.Center,
				sizeConstraint = UDim2.fromScale(1, 1),
				zIndex = 506,
			})), React.createElement(Text, {
				value = slot.label,
				size = 11,
				color = Palette.cream,
				weight = Enum.FontWeight.Bold,
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(4, 8),
				sizeConstraint = UDim2.new(1, -8, 0, 18),
				zIndex = 503,
			}), React.createElement(Text, {
				value = `{pctX}%  {pctY}%`,
				size = 9,
				color = Palette.creamSoft,
				weight = Enum.FontWeight.Heavy,
				align = Enum.TextXAlignment.Center,
				position = UDim2.new(0, 4, 1, -22),
				sizeConstraint = UDim2.new(1, -8, 0, 14),
				zIndex = 503,
			}), collision and React.createElement(Text, {
				value = "OVERLAP",
				size = 8,
				color = Palette.coral,
				weight = Enum.FontWeight.Heavy,
				align = Enum.TextXAlignment.Center,
				position = UDim2.new(0, 0, 1, -36),
				sizeConstraint = UDim2.new(1, 0, 0, 14),
				zIndex = 506,
			}), React.createElement("imagebutton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Selectable = false,
				Active = true,
				ZIndex = 504,
				Event = {
					InputBegan = function(_button, input)
						if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
							setSelectedId(slot.id)
							if not isLocked then
								MobileDragging:beginDrag(slot.id, input)
							end
						end
					end,
				},
			}))
		end
		for _k, _v in slots do
			_newValue[_k] = _callback_1(_v, _k - 1, slots)
		end
		-- ▲ ReadonlyArray.map ▲
		_condition_2 = _newValue
	end
	local _condition_3 = editing
	if _condition_3 then
		local _exp = React.createElement("frame", {
			Size = UDim2.new(1, -(viewport.sideInset * 2 + 16), 0, TapTarget),
			Position = UDim2.fromOffset(viewport.sideInset + 8, editorToolbarY),
			BackgroundColor3 = Palette.panelRaised,
			BackgroundTransparency = 0.02,
			BorderSizePixel = 0,
			ZIndex = 510,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 13),
		}), React.createElement("uistroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Round,
			Color = Palette.cyan,
			Thickness = 1,
			Transparency = 0.42,
		}), React.createElement("frame", {
			Size = UDim2.new(0.2, -3, 1, 0),
			BackgroundTransparency = 1,
		}, React.createElement(Button, {
			text = if collisionPresent then "OVERLAP" else "SAVE",
			onClick = if collisionPresent then unstackOverlaps else finishEditing,
			color = if collisionPresent then Palette.coral else EDIT_BOUNDS,
			textColor = Palette.ink,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
		})), React.createElement("frame", {
			Size = UDim2.new(0.2, -3, 1, 0),
			Position = UDim2.new(0.2, 1, 0, 0),
			BackgroundTransparency = 1,
		}, React.createElement(Button, {
			text = if snap then `SNAP {snapStep}` else "FREE",
			onClick = function()
				if not snap then
					setSnap(true)
					setSnapStep(4)
				elseif snapStep == 4 then
					setSnapStep(8)
				elseif snapStep == 8 then
					setSnapStep(16)
				elseif snapStep == 16 then
					setSnapStep(32)
				else
					setSnap(false)
					setSnapStep(8)
				end
			end,
			color = if snap then Palette.cyan else Palette.panelSoft,
			textColor = if snap then Palette.ink else Palette.creamSoft,
			outline = not snap,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
		})), React.createElement("frame", {
			Size = UDim2.new(0.2, -3, 1, 0),
			Position = UDim2.new(0.4, 2, 0, 0),
			BackgroundTransparency = 1,
		}, React.createElement(Button, {
			text = "UNDO",
			onClick = undoLayout,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			outline = true,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
		})), React.createElement("frame", {
			Size = UDim2.new(0.2, -3, 1, 0),
			Position = UDim2.new(0.6, 3, 0, 0),
			BackgroundTransparency = 1,
		}, React.createElement(Button, {
			text = "REDO",
			onClick = redoLayout,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			outline = true,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
		})), React.createElement("frame", {
			Size = UDim2.new(0.2, -3, 1, 0),
			Position = UDim2.new(0.8, 4, 0, 0),
			BackgroundTransparency = 1,
		}, React.createElement(Button, {
			text = "DONE",
			onClick = function()
				if finishEditing() then
					requestClose()
				end
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			outline = true,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
			disabled = exiting,
		})))
		local _exp_1 = React.createElement("frame", {
			Size = UDim2.new(1, -(viewport.sideInset * 2 + 16), 0, TapTarget),
			Position = UDim2.fromOffset(viewport.sideInset + 8, editorToolbarY + TapTarget + 8),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 510,
		}, React.createElement(Button, {
			text = "←",
			onClick = function()
				return nudgeSelected(-1, 0)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "↑",
			onClick = function()
				return nudgeSelected(0, -1)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			position = UDim2.new(0.16, 1, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "↓",
			onClick = function()
				return nudgeSelected(0, 1)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			position = UDim2.new(0.32, 2, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "→",
			onClick = function()
				return nudgeSelected(1, 0)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			position = UDim2.new(0.48, 3, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = if fine then "1px" else "STEP",
			onClick = function()
				return setFine(not fine)
			end,
			color = if fine then Palette.mint else Palette.panelSoft,
			textColor = if fine then Palette.ink else Palette.cream,
			size = UDim2.new(0.18, -3, 1, 0),
			position = UDim2.new(0.64, 4, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = if showThirds then "1/3" else "10%",
			onClick = function()
				return setShowThirds(not showThirds)
			end,
			color = if showThirds then Palette.cyan else Palette.panelSoft,
			textColor = if showThirds then Palette.ink else Palette.cream,
			size = UDim2.new(0.18, -3, 1, 0),
			position = UDim2.new(0.82, 5, 0, 0),
			reducedMotion = reducedMotion,
		}))
		local _exp_2 = React.createElement("frame", {
			Size = UDim2.new(1, -(viewport.sideInset * 2 + 16), 0, TapTarget),
			Position = UDim2.fromOffset(viewport.sideInset + 8, bottomBarY),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 510,
		}, React.createElement(Button, {
			text = "L",
			onClick = function()
				return alignSelected("left")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "R",
			onClick = function()
				return alignSelected("right")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			position = UDim2.new(1 / 6, 1, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "T",
			onClick = function()
				return alignSelected("top")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			position = UDim2.new(2 / 6, 2, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "B",
			onClick = function()
				return alignSelected("bottom")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			position = UDim2.new(3 / 6, 3, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "CX",
			onClick = function()
				return alignSelected("cx")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			position = UDim2.new(4 / 6, 4, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "CY",
			onClick = function()
				return alignSelected("cy")
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(1 / 6, -4, 1, 0),
			position = UDim2.new(5 / 6, 5, 0, 0),
			reducedMotion = reducedMotion,
		}))
		local _exp_3 = React.createElement("frame", {
			Size = UDim2.new(1, -(viewport.sideInset * 2 + 16), 0, TapTarget),
			Position = UDim2.fromOffset(viewport.sideInset + 8, bottomBarY + TapTarget + 6),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 510,
		}, React.createElement(Button, {
			text = if selectedLocked then "UNLOCK" else "LOCK",
			onClick = function()
				if selectedSlot == nil then
					return nil
				end
				setLocked(function(current)
					local _object = table.clone(current)
					setmetatable(_object, nil)
					_object[selectedSlot.id] = not selectedLocked
					return _object
				end)
			end,
			color = if selectedLocked then Palette.mango else Palette.panelSoft,
			textColor = if selectedLocked then Palette.ink else Palette.cream,
			size = UDim2.new(0.18, -3, 1, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "SZ-",
			onClick = function()
				return bumpSelectedSetting("scale", -0.08)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.14, -3, 1, 0),
			position = UDim2.new(0.18, 1, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "SZ+",
			onClick = function()
				return bumpSelectedSetting("scale", 0.08)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.14, -3, 1, 0),
			position = UDim2.new(0.32, 2, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "FADE-",
			onClick = function()
				return bumpSelectedSetting("opacity", -0.08)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			position = UDim2.new(0.46, 3, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "FADE+",
			onClick = function()
				return bumpSelectedSetting("opacity", 0.08)
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.new(0.16, -3, 1, 0),
			position = UDim2.new(0.62, 4, 0, 0),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "CLEAR",
			onClick = unstackOverlaps,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			outline = true,
			size = UDim2.new(0.22, -3, 1, 0),
			position = UDim2.new(0.78, 5, 0, 0),
			reducedMotion = reducedMotion,
		}))
		local _attributes = {}
		local _result_1
		if selectedPos ~= nil then
			local _result_2 = selectedSlot
			if _result_2 ~= nil then
				_result_2 = _result_2.label
			end
			local _condition_4 = _result_2
			if _condition_4 == nil then
				_condition_4 = "HUD"
			end
			_result_1 = `{_condition_4}  ·  drag, nudge, align, size  ·  red means overlap`
		else
			_result_1 = "DRAG A BLOCK"
		end
		_attributes.value = _result_1
		_attributes.size = 10
		_attributes.color = Palette.cyan
		_attributes.weight = Enum.FontWeight.Heavy
		_attributes.align = Enum.TextXAlignment.Center
		_attributes.position = UDim2.new(0, viewport.sideInset + 12, 0, editorToolbarY + TapTarget * 2 + 16)
		_attributes.sizeConstraint = UDim2.new(1, -(viewport.sideInset * 2 + 24), 0, 18)
		_attributes.zIndex = 506
		_condition_3 = React.createElement(React.Fragment, nil, _exp, _exp_1, _exp_2, _exp_3, React.createElement(Text, _attributes))
	end
	return ReactRoblox.createPortal(React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = exit:map(function(amount)
			return 1 - amount * (if editing then 0.62 else 0.88)
		end),
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 500,
		ClipsDescendants = true,
		Visible = exit:map(function(amount)
			return amount > 0.01
		end),
	}, _condition, _condition_1, _condition_2, _condition_3, not editing and React.createElement("frame", {
		Size = UDim2.fromOffset(math.min(440, viewport.width - viewport.sideInset * 2 - 24), 292),
		Position = UDim2.new(0.5, 0, 1, -(304 + viewport.bottomInset)),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Palette.panelRaised,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ZIndex = 510,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 16),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.cyan,
		Thickness = 1,
		Transparency = 0.55,
	}), React.createElement(Button, {
		text = "EDIT HUD LAYOUT",
		onClick = function()
			return setEditing(true)
		end,
		color = EDIT_BOUNDS,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, TapTarget),
		reducedMotion = reducedMotion,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 56),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("frame", {
		Size = UDim2.new(0.2, -4, 1, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "LEFT",
		onClick = function()
			return applyPreset("left")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.2, -4, 1, 0),
		Position = UDim2.new(0.2, 1, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "HOME",
		onClick = function()
			return applyPreset("default")
		end,
		color = Palette.panelSoft,
		textColor = Palette.cyan,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.2, -4, 1, 0),
		Position = UDim2.new(0.4, 2, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "RIGHT",
		onClick = function()
			return applyPreset("right")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.2, -4, 1, 0),
		Position = UDim2.new(0.6, 3, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "TOP",
		onClick = function()
			return applyPreset("top")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.2, -4, 1, 0),
		Position = UDim2.new(0.8, 4, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "THUMB",
		onClick = function()
			return applyPreset("thumbs")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	}))), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 104),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("frame", {
		Size = UDim2.new(0.25, -4, 1, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "TL",
		onClick = function()
			return applyPreset("tl")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.25, -4, 1, 0),
		Position = UDim2.new(0.25, 1, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "TR",
		onClick = function()
			return applyPreset("tr")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.25, -4, 1, 0),
		Position = UDim2.new(0.5, 2, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "BL",
		onClick = function()
			return applyPreset("bl")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.25, -4, 1, 0),
		Position = UDim2.new(0.75, 3, 0, 0),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "BR",
		onClick = function()
			return applyPreset("br")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	}))), React.createElement("frame", {
		Size = UDim2.new(0.5, -4, 0, TapTarget),
		Position = UDim2.fromOffset(0, 152),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "RESET",
		onClick = resetLayout,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.5, -4, 0, TapTarget),
		Position = UDim2.new(0.5, 4, 0, 152),
		BackgroundTransparency = 1,
	}, React.createElement(Button, {
		text = "CLOSE",
		onClick = requestClose,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = exiting,
	})), React.createElement(Text, {
		value = "Move vault, dock, and alerts. Size, fade, lock, and snap stay. Nothing is removed.",
		size = 10,
		color = Palette.muted,
		wrap = true,
		align = Enum.TextXAlignment.Center,
		fit = false,
		position = UDim2.fromOffset(8, 212),
		sizeConstraint = UDim2.new(1, -16, 0, 56),
	})), React.createElement("frame", {
		Size = exit:map(function(amount)
			return UDim2.new(1, 0, 0.5 * (1 - amount), 1)
		end),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 900,
	}), React.createElement("frame", {
		Size = exit:map(function(amount)
			return UDim2.new(1, 0, 0.5 * (1 - amount), 1)
		end),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 900,
	})), screen)
end
local function MobileQuickBar(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local height = _param.height
	local bottomOffset = _param.bottomOffset
	local edgePad = _param.edgePad
	local hudX = _param.hudX
	local hudY = _param.hudY
	local hudScale = _param.hudScale
	local hudOpacity = _param.hudOpacity
	local buttonSpacing = _param.buttonSpacing
	local minTop = _param.minTop
	local reversed = _param.reversed
	if reversed == nil then
		reversed = false
	end
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local vaultFill = if asFlux(state.Capacity) > 0 then math.clamp(asFlux(state.Vault) / asFlux(state.Capacity), 0, 1) else 0
	local vaultReady = asFlux(state.Vault) >= 1
	local fillSpring = useFlipperSpring(vaultFill, reducedMotion, 280, 28)
	local side = math.max(edgePad, chrome.sideSafe)
	local _condition = buttonSpacing
	if _condition == nil then
		_condition = 0.5
	end
	local gap = 4 + math.floor(math.clamp(_condition, 0, 1) * 10)
	local btnH = TapTarget
	local _condition_1 = hudScale
	if _condition_1 == nil then
		_condition_1 = 0.5
	end
	local scale = 0.72 + math.clamp(_condition_1, 0, 1) * 0.28
	local width = math.max(200, (viewport.width - side * 2) * scale)
	local _condition_2 = hudX
	if _condition_2 == nil then
		_condition_2 = 0.5
	end
	local x = math.clamp(_condition_2, (side + width / 2) / viewport.width, 1 - (side + width / 2) / viewport.width)
	local yFallback = 1 - (bottomOffset - height / 2) / viewport.height
	local _condition_3 = hudY
	if _condition_3 == nil then
		_condition_3 = yFallback
	end
	local y = math.clamp(_condition_3, (math.max(viewport.topInset, minTop) + height / 2 + 8) / viewport.height, 1 - (viewport.bottomInset + height / 2 + 8) / viewport.height)
	local _condition_4 = hudOpacity
	if _condition_4 == nil then
		_condition_4 = 0.85
	end
	local surfaceTransparency = math.clamp(0.48 - math.clamp(_condition_4, 0, 1) * 0.48, 0, 0.48)
	local readyPulse = usePulse(vaultReady and vaultFill > 0.8, 2.4)
	local tapReadyAt, setTapReadyAt = React.useState(0)
	local tapLeft, setTapLeft = React.useState(0)
	React.useEffect(function()
		if tapReadyAt <= 0 then
			setTapLeft(0)
			return nil
		end
		local alive = true
		local worker = task.spawn(function()
			while alive do
				local left = math.max(0, tapReadyAt - os.clock())
				setTapLeft(left)
				if left <= 0 then
					break
				end
				task.wait(0.05)
			end
		end)
		return function()
			alive = false
			task.cancel(worker)
		end
	end, { tapReadyAt })
	local tap = function()
		if os.clock() < tapReadyAt then
			return nil
		end
		setTapReadyAt(os.clock() + 0.45)
		setTapLeft(0.45)
		dispatch("Overcharge")
	end
	local bank = function()
		if not vaultReady then
			Audio:play("locked")
			return nil
		end
		dispatch("CollectVault")
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(width, height),
		Position = UDim2.fromScale(x, y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 60,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panel,
		BackgroundTransparency = surfaceTransparency,
		BorderSizePixel = 0,
		ZIndex = 61,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 16),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel),
		Rotation = 90,
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = if vaultFill > 0.8 then Palette.green else Palette.lineSoft,
		Thickness = if vaultFill > 0.8 then 2 else 1,
		Transparency = readyPulse:map(function(amount)
			return if vaultFill > 0.8 then 0.42 - amount * 0.22 else 0.45
		end),
	}), React.createElement("frame", {
		Size = UDim2.new(1, -16, 0, 3),
		Position = UDim2.fromOffset(8, 1),
		BackgroundColor3 = Palette.line,
		BorderSizePixel = 0,
		ZIndex = 62,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = fillSpring:map(function(amount)
			return UDim2.new(math.clamp(amount, 0.02, 1), 0, 1, 0)
		end),
		BackgroundColor3 = if vaultFill > 0.92 then Palette.mango else Palette.green,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))), React.createElement("frame", {
		Size = UDim2.new(1, -16, 0, btnH),
		Position = UDim2.fromOffset(8, height - btnH - 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 63,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}), React.createElement("frame", {
		Size = UDim2.new(0.58, -gap / 2, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = if reversed then 2 else 1,
	}, React.createElement(Button, {
		text = if vaultReady then `BANK  {compactNumber(state.Vault)}` else "VAULT EMPTY",
		icon = "Flux",
		onClick = bank,
		color = if vaultReady then Palette.green else Palette.panelSoft,
		textColor = if vaultReady then Palette.ink else Palette.muted,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = not vaultReady,
		highlight = vaultReady and vaultFill > 0.5,
	})), React.createElement("frame", {
		Size = UDim2.new(0.42, -gap / 2, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = if reversed then 1 else 2,
	}, React.createElement(Button, {
		text = if tapLeft > 0.02 then string.format("%.1fs", tapLeft) else "TAP",
		icon = "Forge",
		onClick = tap,
		color = if tapLeft > 0.02 then Palette.panelSoft else Palette.cyan,
		textColor = if tapLeft > 0.02 then Palette.muted else Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = tapLeft > 0.02,
		highlight = tapLeft <= 0.02,
	}))), chrome.landscape and React.createElement(Text, {
		value = `{compactNumber(state.Production)}/s`,
		size = 9,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Right,
		position = UDim2.new(1, -12, 0, 6),
		sizeConstraint = UDim2.fromOffset(80, 12),
		zIndex = 64,
	})))
end
return {
	MobileControls = MobileControls,
	MobileQuickBar = MobileQuickBar,
}

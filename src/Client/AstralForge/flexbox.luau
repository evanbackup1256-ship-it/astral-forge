local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local _interaction = require(script.Parent.interaction)
local isGamepadDevice = _interaction.isGamepadDevice
local isTouchDevice = _interaction.isTouchDevice
local useViewport = require(script.Parent.motion).useViewport
local TapTarget = require(script.Parent.theme).TapTarget
local function flexSurface()
	if isGamepadDevice() then
		return "gamepad"
	end
	if isTouchDevice() then
		return "touch"
	end
	return "desktop"
end
local function useFlexPlatform()
	local surface = flexSurface()
	if surface == "touch" then
		return {
			surface = surface,
			wrap = true,
			gap = 8,
			minWidth = TapTarget,
			minHeight = TapTarget,
			justify = "fill",
		}
	end
	if surface == "gamepad" then
		return {
			surface = surface,
			wrap = false,
			gap = 14,
			minWidth = TapTarget + 16,
			minHeight = TapTarget + 8,
			justify = "space-between",
		}
	end
	return {
		surface = surface,
		wrap = true,
		gap = 12,
		minWidth = 120,
		minHeight = 48,
		justify = "fill",
	}
end
local function justifyEnum(value)
	if value == "fill" then
		return Enum.UIFlexAlignment.Fill
	end
	if value == "space-between" then
		return Enum.UIFlexAlignment.SpaceBetween
	end
	if value == "space-around" then
		return Enum.UIFlexAlignment.SpaceAround
	end
	if value == "space-evenly" then
		return Enum.UIFlexAlignment.SpaceEvenly
	end
	return Enum.UIFlexAlignment.None
end
local function alignEnum(value)
	if value == "start" then
		return Enum.ItemLineAlignment.Start
	end
	if value == "center" then
		return Enum.ItemLineAlignment.Center
	end
	if value == "end" then
		return Enum.ItemLineAlignment.End
	end
	if value == "stretch" then
		return Enum.ItemLineAlignment.Stretch
	end
	return Enum.ItemLineAlignment.Automatic
end
local function modeEnum(value)
	if value == "grow" then
		return Enum.UIFlexMode.Grow
	end
	if value == "shrink" then
		return Enum.UIFlexMode.Shrink
	end
	if value == "fill" then
		return Enum.UIFlexMode.Fill
	end
	if value == "custom" then
		return Enum.UIFlexMode.Custom
	end
	return Enum.UIFlexMode.None
end
local function mainAlign(direction, align)
	if direction == "row" then
		return {
			horizontal = Enum.HorizontalAlignment.Left,
			vertical = if align == "end" then Enum.VerticalAlignment.Bottom elseif align == "start" then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Center,
		}
	end
	return {
		horizontal = if align == "end" then Enum.HorizontalAlignment.Right elseif align == "start" then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Center,
		vertical = Enum.VerticalAlignment.Top,
	}
end
local function Flex(_param)
	local children = _param.children
	local direction = _param.direction
	if direction == nil then
		direction = "row"
	end
	local wrap = _param.wrap
	local justify = _param.justify
	local align = _param.align
	if align == nil then
		align = "center"
	end
	local gap = _param.gap
	local size = _param.size
	if size == nil then
		size = UDim2.fromScale(1, 1)
	end
	local position = _param.position
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 1
	end
	local clips = _param.clips
	if clips == nil then
		clips = false
	end
	local exact = _param.exact
	if exact == nil then
		exact = false
	end
	local platform = useFlexPlatform()
	local _condition = wrap
	if _condition == nil then
		_condition = (if exact then false else platform.wrap)
	end
	local wraps = _condition
	local _condition_1 = gap
	if _condition_1 == nil then
		_condition_1 = (if exact then 8 else platform.gap)
	end
	local padding = _condition_1
	local distribution = justify or (if exact then "none" else platform.justify)
	local main = mainAlign(direction, align)
	local axis = if direction == "column" then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
	local horizontalFlex = if direction == "row" then justifyEnum(distribution) else Enum.UIFlexAlignment.None
	local verticalFlex = if direction == "column" then justifyEnum(distribution) else Enum.UIFlexAlignment.None
	return React.createElement("frame", {
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ZIndex = zIndex,
		ClipsDescendants = clips,
	}, React.createElement("uilistlayout", {
		FillDirection = axis,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, padding),
		Wraps = wraps,
		HorizontalFlex = horizontalFlex,
		VerticalFlex = verticalFlex,
		ItemLineAlignment = alignEnum(align),
		HorizontalAlignment = main.horizontal,
		VerticalAlignment = main.vertical,
	}), children)
end
local function FlexItem(_param)
	local children = _param.children
	local mode = _param.mode
	if mode == nil then
		mode = "grow"
	end
	local grow = _param.grow
	local shrink = _param.shrink
	local minWidth = _param.minWidth
	local minHeight = _param.minHeight
	local maxWidth = _param.maxWidth
	local maxHeight = _param.maxHeight
	local size = _param.size
	local automaticSize = _param.automaticSize
	if automaticSize == nil then
		automaticSize = Enum.AutomaticSize.None
	end
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 1
	end
	local platform = useFlexPlatform()
	local _condition = minWidth
	if _condition == nil then
		_condition = platform.minWidth
	end
	local floorX = _condition
	local _condition_1 = minHeight
	if _condition_1 == nil then
		_condition_1 = platform.minHeight
	end
	local floorY = _condition_1
	local itemSize = size or (if mode == "fill" or mode == "grow" then UDim2.new(0, floorX, 0, floorY) else UDim2.fromOffset(floorX, floorY))
	local _attributes = {
		FlexMode = modeEnum(mode),
	}
	local _condition_2 = grow
	if _condition_2 == nil then
		_condition_2 = 1
	end
	_attributes.GrowRatio = _condition_2
	local _condition_3 = shrink
	if _condition_3 == nil then
		_condition_3 = 1
	end
	_attributes.ShrinkRatio = _condition_3
	local _exp = React.createElement("uiflexitem", _attributes)
	local _attributes_1 = {
		MinSize = Vector2.new(floorX, floorY),
	}
	local _condition_4 = maxWidth
	if _condition_4 == nil then
		_condition_4 = math.huge
	end
	local _condition_5 = maxHeight
	if _condition_5 == nil then
		_condition_5 = math.huge
	end
	_attributes_1.MaxSize = Vector2.new(_condition_4, _condition_5)
	return React.createElement("frame", {
		Size = itemSize,
		AutomaticSize = automaticSize,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ZIndex = zIndex,
		ClipsDescendants = false,
	}, _exp, React.createElement("uisizeconstraint", _attributes_1), children)
end
local function packColumns(width, surface)
	if surface == nil then
		surface = flexSurface()
	end
	if surface == "touch" or width < 640 then
		return 2
	end
	if surface == "gamepad" or width < 1100 then
		return 3
	end
	return 4
end
local function isFlexChildList(value)
	local _value = value
	if not (type(_value) == "table") then
		return false
	end
	local record = value
	if record.component ~= nil or record.type ~= nil or record.props ~= nil then
		return false
	end
	local numeric = 0
	local named = 0
	for key in pairs(record) do
		if type(key) == "number" then
			numeric += 1
		else
			named += 1
		end
	end
	return numeric > 0 and named == 0
end
local function flattenFlexChildren(value, into)
	if into == nil then
		into = {}
	end
	if value == nil or value == false or value == true then
		return into
	end
	if isFlexChildList(value) then
		for _, child in value do
			flattenFlexChildren(child, into)
		end
		return into
	end
	local _into = into
	local _value = value
	table.insert(_into, _value)
	return into
end
local function useShopColumns()
	local viewport = useViewport()
	local contentW = math.max(280, viewport.width - (if viewport.width >= 1100 then 320 elseif viewport.width >= 760 then 96 else 36))
	if contentW < 540 then
		return 1
	end
	if contentW < 900 then
		return 2
	end
	return 3
end
local function usePackColumns()
	local viewport = useViewport()
	return packColumns(viewport.width, flexSurface())
end
local PACK_BREAKPOINTS = { {
	minWidth = 0,
	columns = 2,
}, {
	minWidth = 640,
	columns = 3,
}, {
	minWidth = 1100,
	columns = 4,
} }
local function FlexGrid(_param)
	local children = _param.children
	local columns = _param.columns
	local gap = _param.gap
	local _cellMinWidth = _param.cellMinWidth
	local cellMinHeight = _param.cellMinHeight
	if cellMinHeight == nil then
		cellMinHeight = 160
	end
	local size = _param.size
	if size == nil then
		size = UDim2.new(1, 0, 0, 0)
	end
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local packed = usePackColumns()
	local _condition = columns
	if _condition == nil then
		_condition = packed
	end
	local cols = math.max(1, _condition)
	local platform = useFlexPlatform()
	local _condition_1 = gap
	if _condition_1 == nil then
		_condition_1 = platform.gap
	end
	local gapPx = _condition_1
	local nodes = flattenFlexChildren(children)
	local _exp = React.createElement("uigridlayout", {
		CellSize = UDim2.new(1 / cols, -math.ceil((gapPx * (cols - 1)) / cols), 0, cellMinHeight),
		CellPadding = UDim2.new(0, gapPx, 0, gapPx),
		FillDirection = Enum.FillDirection.Horizontal,
		FillDirectionMaxCells = cols,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#nodes)
	local _callback = function(child, index)
		return React.createElement("frame", {
			key = `pack-{index}`,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = index,
			ClipsDescendants = false,
		}, child)
	end
	for _k, _v in nodes do
		_newValue[_k] = _callback(_v, _k - 1, nodes)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = size,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ClipsDescendants = false,
	}, _exp, _newValue)
end
return {
	flexSurface = flexSurface,
	useFlexPlatform = useFlexPlatform,
	Flex = Flex,
	FlexItem = FlexItem,
	packColumns = packColumns,
	useShopColumns = useShopColumns,
	usePackColumns = usePackColumns,
	FlexGrid = FlexGrid,
	PACK_BREAKPOINTS = PACK_BREAKPOINTS,
}

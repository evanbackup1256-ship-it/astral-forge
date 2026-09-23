local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useVirtualWindow = require(script.Parent.scrolling).useVirtualWindow
local Palette = require(script.Parent.theme).Palette
local function virtualRange(count, stride, topOffset, scrollY, viewHeight, overscan)
	if overscan == nil then
		overscan = 2
	end
	if count <= 0 or stride <= 0 then
		return {
			first = 0,
			last = -1,
		}
	end
	local height = math.max(1, viewHeight)
	local first = math.clamp(math.floor((scrollY - topOffset) / stride) - overscan, 0, count - 1)
	local last = math.clamp(math.ceil((scrollY + height - topOffset) / stride) + overscan, first, count - 1)
	return {
		first = first,
		last = last,
	}
end
local function useVirtualizedList(count, itemHeight, headerHeight, overscan)
	if headerHeight == nil then
		headerHeight = 0
	end
	-- nil overscan lets useVirtualWindow pick the constrained-aware default.
	return useVirtualWindow(count, itemHeight, headerHeight, overscan)
end
local function resolveKey(item, index, extractor)
	if extractor ~= nil then
		return extractor(item, index)
	end
	local record = item
	local _id = record.Id
	local _condition = type(_id) == "string"
	if _condition then
		_condition = #record.Id > 0
	end
	if _condition then
		return record.Id
	end
	local _id_1 = record.id
	local _condition_1 = type(_id_1) == "string"
	if _condition_1 then
		_condition_1 = #record.id > 0
	end
	if _condition_1 then
		return record.id
	end
	local _uid = record.uid
	local _condition_2 = type(_uid) == "string"
	if _condition_2 then
		_condition_2 = #record.uid > 0
	end
	if _condition_2 then
		return record.uid
	end
	return tostring(index)
end
local VirtualRow
local function VirtualizedList(props)
	local data = props.data
	local itemHeight = math.max(1, props.itemHeight)
	local _condition = props.headerHeight
	if _condition == nil then
		_condition = 0
	end
	local headerHeight = math.max(0, _condition)
	local _condition_1 = props.footerHeight
	if _condition_1 == nil then
		_condition_1 = 0
	end
	local footerHeight = math.max(0, _condition_1)
	-- Pass nil through so scrolling.useVirtualWindow can apply the constrained
	-- overscan=1 default instead of forcing desktop overscan=2 on phones.
	local overscan = props.overscan
	local count = #data
	local window = useVirtualWindow(count, itemHeight, headerHeight, overscan)
	local embedded = props.embedded == true
	local rangeFirst = if embedded then 0 else window.first
	local rangeLast = if embedded then count - 1 else window.last
	local ownedRef = React.useRef()
	local bindRef = function(frame)
		ownedRef.current = frame
		window.frame.current = frame
		if props.frameRef ~= nil then
			(props.frameRef).current = frame
		end
	end
	local rows = {}
	do
		local index = rangeFirst
		local _shouldIncrement = false
		while true do
			if _shouldIncrement then
				index += 1
			else
				_shouldIncrement = true
			end
			if not (index <= rangeLast) then
				break
			end
			local item = data[index + 1]
			if item == nil then
				continue
			end
			local _arg0 = React.createElement(VirtualRow, {
				key = resolveKey(item, index, props.keyExtractor),
				index = index,
				height = itemHeight,
				top = headerHeight + index * itemHeight,
			}, props.renderItem({
				item = item,
				index = index,
			}))
			table.insert(rows, _arg0)
		end
	end
	local _exp = headerHeight + math.max(count, if count == 0 and props.ListEmptyComponent ~= nil then 1 else 0) * (if count > 0 then itemHeight else 0) + footerHeight
	local _condition_3 = props.canvasTail
	if _condition_3 == nil then
		_condition_3 = 0
	end
	local canvasH = _exp + _condition_3
	local _exp_1 = headerHeight + (if count == 0 and props.ListEmptyComponent ~= nil then 150 else 0) + footerHeight
	local _condition_4 = props.canvasTail
	if _condition_4 == nil then
		_condition_4 = 0
	end
	local emptyCanvas = _exp_1 + _condition_4
	local _attributes = {
		ref = bindRef,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.fromOffset(0, 0),
		CanvasSize = UDim2.new(0, 0, 0, if count > 0 then canvasH else emptyCanvas),
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}
	local _condition_5 = props.scrollBarThickness
	if _condition_5 == nil then
		_condition_5 = 3
	end
	_attributes.ScrollBarThickness = _condition_5
	_attributes.ScrollBarImageColor3 = props.scrollBarColor or Palette.cyan
	local _condition_6 = props.scrollBarTransparency
	if _condition_6 == nil then
		_condition_6 = 0.28
	end
	_attributes.ScrollBarImageTransparency = _condition_6
	_attributes.ClipsDescendants = true
	_attributes.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	_attributes.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	_attributes.Active = not embedded
	if embedded then
		-- The page scaffold is the only scroller. An inner ScrollingFrame steals
		-- the wheel and fights that parent.
		_attributes.ScrollingEnabled = false
		_attributes.ScrollBarThickness = 0
		_attributes.ClipsDescendants = false
		_attributes.Size = UDim2.new(1, 0, 0, if count > 0 then canvasH else emptyCanvas)
	end
	_attributes.Selectable = false
	_attributes.ZIndex = props.ZIndex
	_attributes.LayoutOrder = props.layoutOrder
	return React.createElement("scrollingframe", _attributes, props.ListHeaderComponent, count == 0 and props.ListEmptyComponent, rows, props.ListFooterComponent)
end
function VirtualRow(_param)
	local height = _param.height
	local top = _param.top
	local children = _param.children
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, height),
		Position = UDim2.fromOffset(0, top),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, children)
end
local function FlatList(props)
	local _attributes = table.clone(props)
	setmetatable(_attributes, nil)
	return React.createElement(VirtualizedList, _attributes)
end
return {
	virtualRange = virtualRange,
	useVirtualizedList = useVirtualizedList,
	VirtualizedList = VirtualizedList,
	FlatList = FlatList,
}

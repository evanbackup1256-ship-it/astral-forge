local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Palette = require(script.Parent.theme).Palette
local planFillHeight = require(script.Parent.pageScaffoldPlan).planFillHeight
local planFittedHeights = require(script.Parent.pageScaffoldPlan).planFittedHeights
local function SpringSection(props)
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, math.max(0, props.height)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ClipsDescendants = false,
	}, props.element)
end
-- PageScaffold — the one vertical-stack layout primitive pages should use instead of hand-
-- computed absolute bands. Every "mobile layout bug" class this project has hit (negative
-- heights from `Size = 1, -(a + b + c)`, action bars landing on top of lists, content that
-- can never be scrolled to) came from pages positioning fixed-height sections against the
-- viewport themselves. This component removes the entire class:
--
--   - Sections are declared as `fixed` (intrinsic pixel height) or `fill` (takes whatever
--     space is left over, never less than `minHeight`, and never less than an optional
--     intrinsic `height` content floor used by hostRef VirtualGrid lists).
--   - The scaffold measures its own rendered height, so it works identically in a page, an
--     overlay, or a drawer — no caller passes viewport math in.
--   - If the sections' minimum total exceeds the available space, the whole thing becomes a
--     scrolling flow. Content is always reachable; nothing ever goes negative or overlaps.
--
-- Usage mirrors how the desktop pages were already built (list of sections), so the same
-- structure now renders correctly at 1440x900 and at 568x320 with zero per-device math.
local function PageScaffold(_param)
	local sections = _param.sections
	local gap = _param.gap
	if gap == nil then
		gap = 10
	end
	local tailPad = _param.tailPad
	if tailPad == nil then
		tailPad = 8
	end
	local inset = _param.inset
	if inset == nil then
		inset = 0
	end
	local scrollBarThickness = _param.scrollBarThickness
	if scrollBarThickness == nil then
		scrollBarThickness = 3
	end
	local scrollBarColor = _param.scrollBarColor
	local size = _param.size
	if size == nil then
		size = UDim2.fromScale(1, 1)
	end
	local position = _param.position
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 1
	end
	-- Optional hostRef lets VirtualGrid / focus callers bind the same ScrollingFrame
	-- PageScaffold owns (Command-style lists) without a second outer scroll.
	local internalRef = React.useRef()
	local hostRef = _param.hostRef
	if hostRef == nil then
		hostRef = internalRef
	end
	local available, setAvailable = React.useState(0)
	React.useEffect(function()
		local host = hostRef.current
		if host == nil then
			return nil
		end
		local sync = function()
			local height = math.max(0, math.floor(host.AbsoluteSize.Y + 0.5))
			setAvailable(function(current)
				return if current == height then current else height
			end)
		end
		sync()
		local connection = host:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync)
		return function()
			return connection:Disconnect()
		end
	end, {})
	-- ▼ ReadonlyArray.find ▼
	local _callback = function(section)
		return section.fill == true
	end
	local _result
	for _i, _v in sections do
		if _callback(_v, _i - 1, sections) == true then
			_result = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local fillSection = _result
	local fittedHeights = planFittedHeights(sections, available, gap, tailPad)
	local _exp = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, gap),
	})
	local _exp_1 = inset > 0 and React.createElement("uipadding", {
		PaddingLeft = UDim.new(0, inset),
		PaddingRight = UDim.new(0, inset),
		PaddingTop = UDim.new(0, inset),
		PaddingBottom = UDim.new(0, inset),
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#sections)
	local _callback_2 = function(section, index)
		local _attributes = {
			key = section.id,
		}
		local _result_3 = fittedHeights[index + 1]
		if _result_3 == nil then
			_result_3 = 0
		end
		_attributes.height = _result_3
		_attributes.layoutOrder = index
		_attributes.element = section.element
		return React.createElement(SpringSection, _attributes)
	end
	for _k, _v in sections do
		_newValue[_k] = _callback_2(_v, _k - 1, sections)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("scrollingframe", {
		ref = hostRef,
		Size = size,
		Position = position,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = scrollBarThickness,
		ScrollBarImageColor3 = scrollBarColor or Palette.muted,
		ScrollBarImageTransparency = 0.42,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		ClipsDescendants = true,
		Active = true,
		Selectable = false,
		ZIndex = zIndex,
	}, _exp, _exp_1, _newValue, tailPad > 0 and React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, tailPad),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = #sections,
	}))
end
return {
	PageScaffold = PageScaffold,
	planFillHeight = planFillHeight,
}

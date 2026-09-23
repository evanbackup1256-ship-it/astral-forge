--[=[
	@within EgooE
	@function tableCell
	@tag widgets
	@param options { column: number? } | (() -> ())
	@param children () -> ()

	Adds one cell to current `tableRow`.
]=]

local Runtime = require(script.Parent.Parent.Runtime)
local create = require(script.Parent.Parent.create)
local Contexts = require(script.Parent.Parent.contexts)

local function getCellBackground(tableState, rowState, columnIndex)
	if rowState.isHeader then
		return tableState.headerColor, tableState.headerTransparency
	end

	local bodyRowIndex = if tableState.header then rowState.rowIndex - 1 else rowState.rowIndex
	if tableState.stripeRows and bodyRowIndex > 0 and bodyRowIndex % 2 == 0 then
		return tableState.stripeRowColor, tableState.stripeRowTransparency
	end

	if tableState.stripeColumns and columnIndex % 2 == 0 then
		return tableState.stripeColumnColor, tableState.stripeColumnTransparency
	end

	return tableState.headerColor, 1
end

return Runtime.widget(function(options, fn)
	if type(options) == "function" and fn == nil then
		fn = options
		options = {}
	end

	options = options or {}

	local rowState = Runtime.useContext(Contexts.tableRowState)
	if not rowState then
		error("EgooE.tableCell must be used inside EgooE.tableRow", 2)
	end

	local tableState = rowState.tableState
	local columnIndex = math.max(options.column or rowState.nextColumn, rowState.nextColumn)
	rowState.nextColumn = columnIndex + 1

	local cellWidth = tableState.columnWidths[columnIndex] or 0
	local cellColor, cellTransparency = getCellBackground(tableState, rowState, columnIndex)

	local refs = Runtime.useInstance(function(ref)
		local cellFrame = create("Frame", {
			[ref] = "frame",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Size = UDim2.new(0, cellWidth, 1, 0),

			create("Frame", {
				[ref] = "background",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 1, 0),
			}),

			create("Frame", {
				[ref] = "leftDivider",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(0, 1, 1, 0),
				ZIndex = 5,
			}),

			create("Frame", {
				[ref] = "content",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 1, 0),

				create("UIListLayout", {
					[ref] = "layout",
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 2),
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),

				create("UIPadding", {
					[ref] = "padding",
				}),
			}),
		})

		return cellFrame, ref.content
	end)

	refs.frame.Size = UDim2.new(0, cellWidth, 1, 0)
	refs.background.BackgroundColor3 = cellColor
	refs.background.BackgroundTransparency = cellTransparency

	refs.leftDivider.Visible = tableState.borders and columnIndex > 1
	refs.leftDivider.BackgroundColor3 = tableState.borderColor
	refs.leftDivider.BackgroundTransparency = tableState.borderTransparency

	refs.padding.PaddingLeft = UDim.new(0, tableState.cellPadding.X)
	refs.padding.PaddingRight = UDim.new(0, tableState.cellPadding.X)
	refs.padding.PaddingTop = UDim.new(0, tableState.cellPadding.Y)
	refs.padding.PaddingBottom = UDim.new(0, tableState.cellPadding.Y)

	Runtime.provideContext(Contexts.tableCellState, {
		centered = true,
	})
	Runtime.scope(fn)
end)

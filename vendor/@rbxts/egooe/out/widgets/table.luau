--[=[
	@within EgooE
	@interface TableOptions

	.columns? { { width: number?, fill: boolean? } } -- Column sizing, defaults to one fill column
	.header? boolean -- Treat first row as header
	.rowHeight? number -- Fixed row height in pixels
	.cellPadding? Vector2 -- Inner cell padding
	.borders? boolean -- Draw outer border and inner grid lines
	.stripeRows? boolean -- Alternate body row colors
	.stripeColumns? boolean -- Alternate column colors
	.stripeRowColor? Color3 -- Override striped row color
	.stripeColumnColor? Color3 -- Override striped column color
	.stripeRowTransparency? number -- Override striped row transparency
	.stripeColumnTransparency? number -- Override striped column transparency
]=]

--[=[
	@within EgooE
	@function table
	@tag widgets
	@param options TableOptions
	@param children () -> ()

	Immediate-mode table container. Use with `tableRow` and `tableCell`.

	```lua
	table({
		header = true,
		borders = true,
		columns = {
			{ width = 120 },
			{ fill = true },
			{ width = 90 },
		},
	}, function()
		tableRow(function()
			tableCell(function() label("Name") end)
			tableCell(function() label("Role") end)
			tableCell(function() label("Ready") end)
		end)
	end)
	```
]=]

local Runtime = require(script.Parent.Parent.Runtime)
local Style = require(script.Parent.Parent.Style)
local create = require(script.Parent.Parent.create)
local Contexts = require(script.Parent.Parent.contexts)

local function normalizeColumns(columns)
	if columns and #columns > 0 then
		return columns
	end

	return {
		{ fill = true },
	}
end

local function computeColumnWidths(totalWidth, columns)
	local widths = table.create(#columns)
	local fixedWidth = 0
	local fillCount = 0

	for index, column in ipairs(columns) do
		local width = column.width or 0
		widths[index] = width
		fixedWidth += width

		if column.fill or width <= 0 then
			fillCount += 1
		end
	end

	local remainingWidth = math.max(0, totalWidth - fixedWidth)
	local fillWidth = if fillCount > 0 then remainingWidth / fillCount else 0

	for index, column in ipairs(columns) do
		if column.fill or (column.width or 0) <= 0 then
			widths[index] = fillWidth
		end
	end

	return widths
end

return Runtime.widget(function(options, fn)
	options = options or {}

	local refs = Runtime.useInstance(function(ref)
		local style = Style.get()

		return create("Frame", {
			[ref] = "frame",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			ClipsDescendants = true,

			create("UIStroke", {
				[ref] = "border",
				Color = style.tableBorderColor,
				Transparency = style.tableBorderTransparency,
				Thickness = 1,
				Enabled = false,
			}),

			create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),
		})
	end)

	local style = Style.get()
	local columns = normalizeColumns(options.columns)
	local absoluteWidth = refs.frame.AbsoluteSize.X

	if absoluteWidth <= 0 and refs.frame.Parent and refs.frame.Parent:IsA("GuiObject") then
		absoluteWidth = refs.frame.Parent.AbsoluteSize.X
	end
	if absoluteWidth <= 0 then
		absoluteWidth = 300
	end

	local tableState = {
		columns = columns,
		columnWidths = computeColumnWidths(absoluteWidth, columns),
		rowHeight = options.rowHeight or style.tableRowHeight or style.itemHeight,
		cellPadding = options.cellPadding or style.tableCellPadding or style.framePadding,
		borders = options.borders or false,
		header = options.header or false,
		stripeRows = options.stripeRows or false,
		stripeColumns = options.stripeColumns or false,
		stripeRowColor = options.stripeRowColor or style.tableStripeRowColor,
		stripeColumnColor = options.stripeColumnColor or style.tableStripeColumnColor,
		stripeRowTransparency = if options.stripeRowTransparency ~= nil
			then options.stripeRowTransparency
			else style.tableStripeRowTransparency,
		stripeColumnTransparency = if options.stripeColumnTransparency ~= nil
			then options.stripeColumnTransparency
			else style.tableStripeColumnTransparency,
		headerColor = style.tableHeaderColor,
		headerTransparency = style.tableHeaderTransparency,
		borderColor = style.tableBorderColor,
		borderTransparency = style.tableBorderTransparency,
		rowIndex = 0,
	}

	refs.border.Enabled = tableState.borders
	refs.border.Color = tableState.borderColor
	refs.border.Transparency = tableState.borderTransparency

	Runtime.provideContext(Contexts.tableState, tableState)
	Runtime.scope(fn)
end)

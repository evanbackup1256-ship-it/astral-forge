--[=[
	@within EgooE
	@function tableRow
	@tag widgets
	@param options { header: boolean? } | (() -> ())
	@param children () -> ()

	Adds one row to current `table`.
]=]

local Runtime = require(script.Parent.Parent.Runtime)
local Style = require(script.Parent.Parent.Style)
local create = require(script.Parent.Parent.create)
local Contexts = require(script.Parent.Parent.contexts)

return Runtime.widget(function(options, fn)
	if type(options) == "function" and fn == nil then
		fn = options
		options = {}
	end

	options = options or {}

	local tableState = Runtime.useContext(Contexts.tableState)
	if not tableState then
		error("EgooE.tableRow must be used inside EgooE.table", 2)
	end

	tableState.rowIndex += 1
	local rowIndex = tableState.rowIndex
	local isHeader = if options.header ~= nil then options.header else (tableState.header and rowIndex == 1)

	local refs = Runtime.useInstance(function(ref)
		local style = Style.get()

		return create("Frame", {
			[ref] = "frame",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, tableState.rowHeight),

			create("Frame", {
				[ref] = "topDivider",
				BackgroundColor3 = style.tableBorderColor,
				BackgroundTransparency = style.tableBorderTransparency,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 1),
				Visible = false,
				ZIndex = 5,
			}),

			create("Frame", {
				[ref] = "content",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 1, 0),

				create("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 0),
				}),
			}),
		})
	end)

	refs.frame.Size = UDim2.new(1, 0, 0, tableState.rowHeight)
	refs.topDivider.Visible = tableState.borders and rowIndex > 1
	refs.topDivider.BackgroundColor3 = tableState.borderColor
	refs.topDivider.BackgroundTransparency = tableState.borderTransparency

	local rowState = {
		tableState = tableState,
		rowIndex = rowIndex,
		isHeader = isHeader,
		nextColumn = 1,
	}

	Runtime.provideContext(Contexts.tableRowState, rowState)
	Runtime.scope(function()
		Runtime.useInstance(function()
			return nil, refs.content
		end)
		Runtime.scope(fn)
	end)
end)

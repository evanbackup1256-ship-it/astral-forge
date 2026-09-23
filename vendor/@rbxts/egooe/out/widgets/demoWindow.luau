--[=[
	@within EgooE
	@function demoWindow
	@tag widgets

	Opens gallery window with broad inline examples plus dedicated widget demo launchers.
	Call this once per frame inside a `start` loop to display the demo.

	```lua
	EgooE.start(node, function()
		EgooE.demoWindow()
	end)
	```
]=]

local Runtime = require(script.Parent.Parent.Runtime)

local window = require(script.Parent.window)
local button = require(script.Parent.button)
local checkbox = require(script.Parent.checkbox)
local slider = require(script.Parent.slider)
local input = require(script.Parent.input)
local label = require(script.Parent.label)
local heading = require(script.Parent.heading)
local separator = require(script.Parent.separator)
local row = require(script.Parent.row)
local space = require(script.Parent.space)
local radioButton = require(script.Parent.radioButton)
local selectableLabel = require(script.Parent.selectableLabel)
local comboBox = require(script.Parent.comboBox)
local dragValue = require(script.Parent.dragValue)
local progressBar = require(script.Parent.progressBar)
local collapsingHeader = require(script.Parent.collapsingHeader)
local toggle = require(script.Parent.toggle)
local clickableLabel = require(script.Parent.clickableLabel)
local modal = require(script.Parent.modal)
local popup = require(script.Parent.popup)
local childWindow = require(script.Parent.childWindow)
local tableWidget = require(script.Parent.table)
local tableRowWidget = require(script.Parent.tableRow)
local tableCellWidget = require(script.Parent.tableCell)

return Runtime.widget(function()
	local activeTab, setActiveTab = Runtime.useState("Gallery")

	local clickCount, setClickCount = Runtime.useState(0)
	local cb1, setCb1 = Runtime.useState(false)
	local cb2, setCb2 = Runtime.useState(true)
	local sliderVal1, setSliderVal1 = Runtime.useState(0)
	local sliderVal2, setSliderVal2 = Runtime.useState(50)
	local inputText, setInputText = Runtime.useState("")
	local submitLog, setSubmitLog = Runtime.useState("")
	local radioChoice, setRadioChoice = Runtime.useState("First")
	local selectableTab, setSelectableTab = Runtime.useState(1)
	local comboSelected, setComboSelected = Runtime.useState("First")
	local dragVal, setDragVal = Runtime.useState(112)
	local progressVal, setProgressVal = Runtime.useState(0.31)
	local toggleOn, setToggleOn = Runtime.useState(false)
	local galleryTableEnabled, setGalleryTableEnabled = Runtime.useState(true)

	local rowDemoOpen, setRowDemoOpen = Runtime.useState(false)
	local rowDemoCentered, setRowDemoCentered = Runtime.useState(false)
	local rowDemoTight, setRowDemoTight = Runtime.useState(false)

	local windowDemoOpen, setWindowDemoOpen = Runtime.useState(false)
	local winClosable, setWinClosable = Runtime.useState(true)
	local winMinimizable, setWinMinimizable = Runtime.useState(true)
	local winMovable, setWinMovable = Runtime.useState(true)
	local winResizable, setWinResizable = Runtime.useState(true)
	local winScrollX, setWinScrollX = Runtime.useState(false)
	local winScrollY, setWinScrollY = Runtime.useState(true)

	local childDemoOpen, setChildDemoOpen = Runtime.useState(false)
	local childTitleInput, setChildTitleInput = Runtime.useState("Scrollable Section")
	local childHeight, setChildHeight = Runtime.useState(120)
	local childMinimizable, setChildMinimizable = Runtime.useState(true)
	local childScrollX, setChildScrollX = Runtime.useState(false)
	local childScrollY, setChildScrollY = Runtime.useState(true)

	local popupDemoOpen, setPopupDemoOpen = Runtime.useState(false)
	local popupVisible, setPopupVisible = Runtime.useState(false)
	local popupExplicitPosition, setPopupExplicitPosition = Runtime.useState(false)

	local modalDemoOpen, setModalDemoOpen = Runtime.useState(false)
	local modalVisible, setModalVisible = Runtime.useState(false)
	local modalClosable, setModalClosable = Runtime.useState(true)
	local modalResult, setModalResult = Runtime.useState("")

	local tableDemoOpen, setTableDemoOpen = Runtime.useState(false)
	local tableBorders, setTableBorders = Runtime.useState(true)
	local tableStripeRows, setTableStripeRows = Runtime.useState(true)
	local tableStripeColumns, setTableStripeColumns = Runtime.useState(false)
	local tableUseWideName, setTableUseWideName = Runtime.useState(false)
	local tableFeatureEnabled, setTableFeatureEnabled = Runtime.useState(true)
	local tableActionCount, setTableActionCount = Runtime.useState(0)
	local tableTuning, setTableTuning = Runtime.useState(25)

	local function renderDemoEntry(title, open, setOpen, fn, options)
		options = options or {}

		childWindow({
			title = title,
			height = options.height or 110,
			minimizable = true,
			scrollY = true,
		}, function()
			row(function()
				if button(open and "Close" or "Open", { width = 80 }).clicked() then
					setOpen(not open)
				end
				label(open and "Status: Open" or "Status: Closed", {
					color = open and Color3.fromRGB(100, 220, 100) or Color3.fromRGB(170, 170, 170),
				})
			end)

			space(4)
			fn()
		end)
	end

	window({
		title = "Widget Gallery",
		closable = false,
		minimizable = true,
		movable = true,
		resizable = true,
		size = Vector2.new(400, 660),
		position = Vector2.new(30, 30),
	}, function()
		heading("Demo Window")
		separator()

		row({ padding = 6 }, function()
			for _, tabName in ipairs({ "Gallery", "Demos" }) do
				local captured = tabName
				if selectableLabel(tabName, { selected = activeTab == tabName }).clicked() then
					setActiveTab(captured)
				end
			end
		end)

		space(6)

		if activeTab == "Gallery" then
			label("Broad widget reference. Open Demos tab for side-by-side playgrounds.")
			space(6)

			heading("Label")
			separator()
			label("Welcome to widget gallery!")
			label("Muted text", { color = Color3.fromRGB(128, 128, 128) })
			label("This is longer piece of text that wraps when it reaches edge of window.", { wrapped = true })

			space(6)

			heading("Button")
			separator()
			if button("Click me!").clicked() then
				setClickCount(clickCount + 1)
			end
			label("Clicked " .. tostring(clickCount) .. " time(s)")

			row(function()
				button("Small A", { width = 90 })
				button("Disabled", { width = 90, disabled = true })
			end)

			space(6)

			heading("ClickableLabel")
			separator()
			if clickableLabel("View source on GitHub ->").clicked() then
				setClickCount(clickCount + 1)
			end

			space(6)

			heading("Checkbox")
			separator()
			if checkbox("Click to toggle", { checked = cb1 }).clicked() then
				setCb1(not cb1)
			end
			if checkbox("Pre-checked", { checked = cb2 }).clicked() then
				setCb2(not cb2)
			end
			checkbox("Disabled", { checked = true, disabled = true })

			space(6)

			heading("RadioButton")
			separator()
			for _, opt in ipairs({ "First", "Second", "Third" }) do
				local capturedOpt = opt
				if radioButton(opt, { selected = radioChoice == opt }).clicked() then
					setRadioChoice(capturedOpt)
				end
			end
			label("Selected: " .. radioChoice)

			space(6)

			heading("SelectableLabel")
			separator()
			row(function()
				for i, name in ipairs({ "First", "Second", "Third" }) do
					local capturedIndex = i
					if selectableLabel(name, { selected = selectableTab == i }).clicked() then
						setSelectableTab(capturedIndex)
					end
				end
			end)
			label("Tab: " .. tostring(selectableTab))

			space(6)

			heading("ComboBox")
			separator()
			local combo = comboBox({ items = { "First", "Second", "Third", "Fourth", "Fifth" } })
			if combo.changed() then
				setComboSelected(combo.value())
			end
			label("Pick: " .. comboSelected)

			space(6)

			heading("Slider")
			separator()
			local alphaValue = slider({ min = 0, max = 1, initial = sliderVal1, label = "Alpha" })
			setSliderVal1(alphaValue)

			local speedValue = slider({ min = 0, max = 100, initial = sliderVal2, label = "Speed" })
			setSliderVal2(speedValue)

			space(6)

			heading("DragValue")
			separator()
			local nextDragValue = dragValue({ min = -200, max = 200, initial = dragVal, step = 1, label = "Value" })
			setDragVal(nextDragValue)

			space(6)

			heading("ProgressBar")
			separator()
			progressBar({ value = progressVal })
			label(math.floor(progressVal * 100) .. "%")
			row(function()
				if button("-10%", { width = 60 }).clicked() then
					setProgressVal(math.max(0, progressVal - 0.1))
				end
				if button("+10%", { width = 60 }).clicked() then
					setProgressVal(math.min(1, progressVal + 0.1))
				end
			end)

			space(6)

			heading("Toggle")
			separator()
			if toggle("Enable feature", { on = toggleOn }).clicked() then
				setToggleOn(not toggleOn)
			end
			toggle("Disabled toggle", { on = true, disabled = true })

			space(6)

			heading("TextEdit")
			separator()
			local handle = input({ placeholder = "Write something here", label = "Text" })
			if handle.changed() then
				setInputText(handle.value())
			end
			if handle.submitted() then
				setSubmitLog("Submitted: " .. handle.value())
			end
			if inputText ~= "" then
				label("Live: " .. inputText)
			end
			if submitLog ~= "" then
				label(submitLog, { color = Color3.fromRGB(100, 220, 100) })
			end

			space(6)

			heading("Separator")
			separator()
			label("Above")
			separator()
			label("Below")

			space(6)

			heading("Row")
			separator()
			row(function()
				button("A")
				button("B")
				button("C")
			end)

			space(6)

			heading("CollapsingHeader")
			separator()
			collapsingHeader("Click to see what is hidden!", function()
				label("You found hidden content!")
				label("Sliders work inside collapsing headers too.")
				slider({ min = 0, max = 10, label = "Inner" })
			end)

			space(6)

			heading("ChildWindow")
			separator()
			childWindow({ title = "Inline Child Window", height = 100, minimizable = true }, function()
				for i = 1, 8 do
					label("Row " .. tostring(i))
				end
			end)

			space(6)

			heading("Table")
			separator()
			tableWidget({
				header = true,
				borders = true,
				stripeRows = true,
				rowHeight = 30,
				columns = {
					{ width = 110 },
					{ fill = true },
					{ width = 80 },
				},
			}, function()
				tableRowWidget(function()
					tableCellWidget(function() label("Widget") end)
					tableCellWidget(function() label("Preview") end)
					tableCellWidget(function() label("Live") end)
				end)

				tableRowWidget(function()
					tableCellWidget(function() label("Checkbox") end)
					tableCellWidget(function() label("Nested widget inside cell") end)
					tableCellWidget(function()
						if checkbox("On", { checked = galleryTableEnabled }).clicked() then
							setGalleryTableEnabled(not galleryTableEnabled)
						end
					end)
				end)
			end)
		else
			label("Open side demos. Each entry has own controls and test window.")
			space(6)

			childWindow({
				title = "Demo Browser",
				height = 560,
				minimizable = true,
				scrollY = true,
			}, function()
				collapsingHeader("Layout", function()
					renderDemoEntry("Row Demo", rowDemoOpen, setRowDemoOpen, function()
						if checkbox("Center align", { checked = rowDemoCentered }).clicked() then
							setRowDemoCentered(not rowDemoCentered)
						end
						if checkbox("Tight padding", { checked = rowDemoTight }).clicked() then
							setRowDemoTight(not rowDemoTight)
						end
					end)
				end)

				collapsingHeader("Windows", function()
					renderDemoEntry("Window Demo", windowDemoOpen, setWindowDemoOpen, function()
						if checkbox("closable", { checked = winClosable }).clicked() then setWinClosable(not winClosable) end
						if checkbox("minimizable", { checked = winMinimizable }).clicked() then setWinMinimizable(not winMinimizable) end
						if checkbox("movable", { checked = winMovable }).clicked() then setWinMovable(not winMovable) end
						if checkbox("resizable", { checked = winResizable }).clicked() then setWinResizable(not winResizable) end
						if checkbox("scrollX", { checked = winScrollX }).clicked() then setWinScrollX(not winScrollX) end
						if checkbox("scrollY", { checked = winScrollY }).clicked() then setWinScrollY(not winScrollY) end
					end, { height = 180 })

					renderDemoEntry("ChildWindow Demo", childDemoOpen, setChildDemoOpen, function()
						local childTitleHandle = input({ text = childTitleInput, label = "Title" })
						if childTitleHandle.changed() then
							setChildTitleInput(childTitleHandle.value())
						end

						local nextChildHeight = slider({
							min = 80,
							max = 220,
							initial = childHeight,
							label = "Height",
						})
						setChildHeight(math.floor(nextChildHeight + 0.5))

						if checkbox("minimizable", { checked = childMinimizable }).clicked() then
							setChildMinimizable(not childMinimizable)
						end
						if checkbox("scrollX", { checked = childScrollX }).clicked() then
							setChildScrollX(not childScrollX)
						end
						if checkbox("scrollY", { checked = childScrollY }).clicked() then
							setChildScrollY(not childScrollY)
						end
					end, { height = 210 })
				end)

				collapsingHeader("Overlays", function()
					renderDemoEntry("Popup Demo", popupDemoOpen, setPopupDemoOpen, function()
						if checkbox("popup visible", { checked = popupVisible }).clicked() then
							setPopupVisible(not popupVisible)
						end
						if checkbox("explicit position", { checked = popupExplicitPosition }).clicked() then
							setPopupExplicitPosition(not popupExplicitPosition)
						end
					end)

					renderDemoEntry("Modal Demo", modalDemoOpen, setModalDemoOpen, function()
						if checkbox("closable", { checked = modalClosable }).clicked() then
							setModalClosable(not modalClosable)
						end
						if button("Open modal", { width = 100 }).clicked() then
							setModalVisible(true)
							setModalResult("")
						end
						if modalResult ~= "" then
							label(modalResult, { color = Color3.fromRGB(100, 220, 100) })
						end
					end)
				end)

				collapsingHeader("Data", function()
					renderDemoEntry("Table Demo", tableDemoOpen, setTableDemoOpen, function()
						if checkbox("borders", { checked = tableBorders }).clicked() then
							setTableBorders(not tableBorders)
						end
						if checkbox("stripe rows", { checked = tableStripeRows }).clicked() then
							setTableStripeRows(not tableStripeRows)
						end
						if checkbox("stripe cols", { checked = tableStripeColumns }).clicked() then
							setTableStripeColumns(not tableStripeColumns)
						end
						if checkbox("wide first col", { checked = tableUseWideName }).clicked() then
							setTableUseWideName(not tableUseWideName)
						end
					end, { height = 150 })
				end)
			end)
		end
	end)

	if rowDemoOpen then
		local rowDemoWindow = window({
			title = "Row Demo",
			closable = true,
			minimizable = true,
			movable = true,
			resizable = true,
			size = Vector2.new(330, 250),
			position = Vector2.new(460, 30),
		}, function()
			label("Use Demos tab controls to change alignment and padding.")
			space(6)

			heading("Equal fill")
			separator()
			row({
				padding = rowDemoTight and 4 or 8,
				alignment = rowDemoCentered and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left,
			}, function()
				button("A")
				button("B")
				button("C")
			end)

			space(6)

			heading("Mixed fixed + fill")
			separator()
			row({
				padding = rowDemoTight and 4 or 8,
				alignment = rowDemoCentered and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left,
			}, function()
				button("80px", { width = 80 })
				button("Fill")
			end)

			space(6)

			heading("Footer")
			separator()
			row({
				padding = rowDemoTight and 4 or 8,
				alignment = rowDemoCentered and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left,
			}, function()
				button("Confirm", { width = 100 })
				button("Cancel", { width = 100 })
			end)
		end)

		if rowDemoWindow.closed() then
			setRowDemoOpen(false)
		end
	end

	if windowDemoOpen then
		local windowDemo = window({
			title = "Window Demo",
			closable = winClosable,
			minimizable = winMinimizable,
			movable = winMovable,
			resizable = winResizable,
			scrollX = winScrollX,
			scrollY = winScrollY,
			size = Vector2.new(320, 260),
			position = Vector2.new(460, 300),
		}, function()
			label("Double-click title bar to minimize.")
			label("Drag still works when movable enabled.")
			space(6)
			for i = 1, 8 do
				label("Window content row " .. tostring(i))
			end
			if winScrollX then
				label("Very long horizontal line to test scroll width -> 1234567890 ABCDEFGHIJKLMNOPQRSTUVWXYZ", {
					wrapped = false,
				})
			end
		end)

		if windowDemo.closed() then
			setWindowDemoOpen(false)
		end
	end

	if childDemoOpen then
		local childDemoWindow = window({
			title = "ChildWindow Demo Host",
			closable = true,
			minimizable = true,
			movable = true,
			resizable = true,
			size = Vector2.new(340, 290),
			position = Vector2.new(800, 30),
		}, function()
			label("Single-click child header to minimize.")
			space(6)
			childWindow({
				title = childTitleInput ~= "" and childTitleInput or "Child Demo",
				height = childHeight,
				minimizable = childMinimizable,
				scrollX = childScrollX,
				scrollY = childScrollY,
			}, function()
				for i = 1, 10 do
					label("Child row " .. tostring(i))
				end
				if childScrollX then
					label("Horizontal scroll sample -> 1234567890 ABCDEFGHIJKLMNOPQRSTUVWXYZ", { wrapped = false })
				end
			end)
		end)

		if childDemoWindow.closed() then
			setChildDemoOpen(false)
		end
	end

	if popupDemoOpen then
		local popupDemoWindow = window({
			title = "Popup Demo",
			closable = true,
			minimizable = true,
			movable = true,
			resizable = true,
			size = Vector2.new(300, 190),
			position = Vector2.new(800, 340),
		}, function()
			label("Anchor popup in window or force explicit position.")
			space(6)
			if button(popupVisible and "Hide popup" or "Show popup", { width = 110 }).clicked() then
				setPopupVisible(not popupVisible)
			end

			popup({
				open = popupVisible,
				position = if popupExplicitPosition then Vector2.new(920, 410) else nil,
			}, function()
				label("Popup menu")
				separator()
				if clickableLabel("Action A").clicked() then
					setPopupVisible(false)
				end
				if clickableLabel("Action B").clicked() then
					setPopupVisible(false)
				end
			end)
		end)

		if popupDemoWindow.closed() then
			setPopupDemoOpen(false)
			setPopupVisible(false)
		end
	end

	if modalDemoOpen then
		local modalDemoWindow = window({
			title = "Modal Demo",
			closable = true,
			minimizable = true,
			movable = true,
			resizable = true,
			size = Vector2.new(300, 180),
			position = Vector2.new(460, 580),
		}, function()
			label("Modal opens above whole UI.")
			space(6)
			if button("Open modal", { width = 110 }).clicked() then
				setModalVisible(true)
				setModalResult("")
			end
			if modalResult ~= "" then
				label(modalResult, { color = Color3.fromRGB(100, 220, 100) })
			end
		end)

		if modalDemoWindow.closed() then
			setModalDemoOpen(false)
			setModalVisible(false)
		end
	end

	local modalHandle = modal({
		title = "Demo Modal",
		open = modalDemoOpen and modalVisible,
		closable = modalClosable,
	}, function()
		label("Modal widget test content.")
		label("Use Demos tab to toggle closable state.")
		space(6)
		row(function()
			if button("Confirm", { width = 100 }).clicked() then
				setModalVisible(false)
				setModalResult("Confirmed!")
			end
			if button("Cancel", { width = 100 }).clicked() then
				setModalVisible(false)
				setModalResult("Cancelled.")
			end
		end)
	end)

	if modalHandle.closed() then
		setModalVisible(false)
		setModalResult("Closed from title bar.")
	end

	if tableDemoOpen then
		local tableDemoWindow = window({
			title = "Table Demo",
			closable = true,
			minimizable = true,
			movable = true,
			resizable = true,
			size = Vector2.new(420, 260),
			position = Vector2.new(860, 30),
		}, function()
			label("Cells can host widgets. Toggle styling from Demos tab.")
			space(6)

			tableWidget({
				header = true,
				borders = tableBorders,
				stripeRows = tableStripeRows,
				stripeColumns = tableStripeColumns,
				rowHeight = 40,
				columns = if tableUseWideName
					then {
						{ width = 150 },
						{ fill = true },
						{ width = 100 },
					}
					else {
						{ width = 110 },
						{ fill = true },
						{ width = 100 },
					},
			}, function()
				tableRowWidget(function()
					tableCellWidget(function() label("Setting") end)
					tableCellWidget(function() label("Preview") end)
					tableCellWidget(function() label("Action") end)
				end)

				tableRowWidget(function()
					tableCellWidget(function() label("Feature Flag") end)
					tableCellWidget(function() label("Checkbox widget in cell") end)
					tableCellWidget(function()
						if checkbox("Enabled", { checked = tableFeatureEnabled }).clicked() then
							setTableFeatureEnabled(not tableFeatureEnabled)
						end
					end)
				end)

				tableRowWidget(function()
					tableCellWidget(function() label("Tuning") end)
					tableCellWidget(function() label("Slider widget in cell") end)
					tableCellWidget(function()
						local nextTuning = slider({
							min = 0,
							max = 100,
							initial = tableTuning,
							label = "Tune",
						})
						setTableTuning(math.floor(nextTuning + 0.5))
					end)
				end)

				tableRowWidget(function()
					tableCellWidget(function() label("Action") end)
					tableCellWidget(function() label("Button widget in cell") end)
					tableCellWidget(function()
						if button("Run", { width = 70 }).clicked() then
							setTableActionCount(tableActionCount + 1)
						end
					end)
				end)
			end)

			space(6)
			label("Run count: " .. tostring(tableActionCount))
		end)

		if tableDemoWindow.closed() then
			setTableDemoOpen(false)
		end
	end
end)

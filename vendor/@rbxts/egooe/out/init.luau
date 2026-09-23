--- @class EgooE
-- An immediate-mode UI framework for Roblox with Iris visual style and Plasma-compatible API.
-- No automatic sizing: all widgets use explicit sizes.

local Runtime = require(script.Runtime)
local Style = require(script.Style)

-- Pre-require widget modules that expose handle types
local _button = require(script.widgets.button)
local _checkbox = require(script.widgets.checkbox)
local _input = require(script.widgets.input)
local _window = require(script.widgets.window)
local _radioButton = require(script.widgets.radioButton)
local _selectableLabel = require(script.widgets.selectableLabel)
local _comboBox = require(script.widgets.comboBox)
local _toggle = require(script.widgets.toggle)
local _collapsingHeader = require(script.widgets.collapsingHeader)
local _clickableLabel = require(script.widgets.clickableLabel)
local _modal = require(script.widgets.modal)
local _childWindow = require(script.widgets.childWindow)
local _table = require(script.widgets.table)
local _tableRow = require(script.widgets.tableRow)
local _tableCell = require(script.widgets.tableCell)

-- Handle types
type ButtonHandle = _button.ButtonHandle
type CheckboxHandle = _checkbox.CheckboxHandle
type InputHandle = _input.InputHandle
type WindowHandle = _window.WindowHandle
type RadioButtonHandle = _radioButton.RadioButtonHandle
type SelectableLabelHandle = _selectableLabel.SelectableLabelHandle
type ComboBoxHandle = _comboBox.ComboBoxHandle
type ToggleHandle = _toggle.ToggleHandle
type CollapsingHeaderHandle = _collapsingHeader.CollapsingHeaderHandle
type ClickableLabelHandle = _clickableLabel.ClickableLabelHandle
type ModalHandle = _modal.ModalHandle
type ChildWindowHandle = _childWindow.ChildWindowHandle

-- Option types
type ButtonOptions = { width: (UDim | number)?, disabled: boolean? }
type CheckboxOptions = { checked: boolean?, disabled: boolean? }
type SliderOptions = { min: number?, max: number?, initial: number?, label: string?, width: number? }
type DragValueOptions = { min: number?, max: number?, initial: number?, step: number?, label: string? }
type InputOptions = { text: string?, placeholder: string?, label: string? }
type WindowOptions = {
	title: string?,
	closable: boolean?,
	minimizable: boolean?,
	movable: boolean?,
	resizable: boolean?,
	scrollX: boolean?,
	scrollY: boolean?,
	size: Vector2?,
	position: Vector2?,
}
type LabelOptions = { textSize: number?, color: Color3?, wrapped: boolean? }
type ClickableLabelOptions = { textSize: number?, color: Color3? }
type HeadingOptions = { textSize: number?, font: Enum.Font? }
type RowOptions = {
	padding: (number | UDim)?,
	alignment: Enum.HorizontalAlignment?,
	verticalAlignment: Enum.VerticalAlignment?,
}
type RadioButtonOptions = { selected: boolean?, disabled: boolean? }
type SelectableLabelOptions = { selected: boolean?, disabled: boolean? }
type ComboBoxOptions = { items: { string }, selected: string?, label: string? }
type ProgressBarOptions = { value: number, label: string? }
type ToggleOptions = { on: boolean?, disabled: boolean? }
type ModalOptions = { title: string?, open: boolean?, closable: boolean? }
type ChildWindowOptions = { title: string?, height: number?, minimizable: boolean?, scrollX: boolean?, scrollY: boolean? }
type PopupOptions = { open: boolean?, position: Vector2? }
type TableColumn = { width: number?, fill: boolean? }
type TableOptions = {
	columns: { TableColumn }?,
	header: boolean?,
	rowHeight: number?,
	cellPadding: Vector2?,
	borders: boolean?,
	stripeRows: boolean?,
	stripeColumns: boolean?,
	stripeRowColor: Color3?,
	stripeColumnColor: Color3?,
	stripeRowTransparency: number?,
	stripeColumnTransparency: number?,
}
type TableRowOptions = { header: boolean? }
type TableCellOptions = { column: number? }

return {
	-- Runtime API (Plasma-compatible)
	new = Runtime.new,
	start = Runtime.start,
	continueFrame = Runtime.continueFrame,
	beginFrame = Runtime.beginFrame,
	finishFrame = Runtime.finishFrame,
	scope = Runtime.scope,
	widget = Runtime.widget,
	useState = Runtime.useState,
	useInstance = Runtime.useInstance,
	useEffect = Runtime.useEffect,
	useKey = Runtime.useKey,
	useRootInstance = Runtime.useRootInstance,
	setEventCallback = Runtime.setEventCallback,
	createContext = Runtime.createContext,
	useContext = Runtime.useContext,
	provideContext = Runtime.provideContext,

	-- Style API
	useStyle = Style.get,
	setStyle = Style.set,

	-- Utilities
	create = require(script.create),

	-- Widgets
	window = _window :: (options: string | WindowOptions, children: () -> ()) -> WindowHandle,
	button = _button :: (text: string, options: ButtonOptions?) -> ButtonHandle,
	checkbox = _checkbox :: (text: string, options: CheckboxOptions?) -> CheckboxHandle,
	slider = require(script.widgets.slider) :: (options: (SliderOptions | number)?) -> number,
	label = require(script.widgets.label) :: (text: string, options: LabelOptions?) -> (),
	heading = require(script.widgets.heading) :: (text: string, options: HeadingOptions?) -> (),
	separator = require(script.widgets.separator) :: () -> (),
	input = _input :: (options: InputOptions?) -> InputHandle,
	row = require(script.widgets.row) :: (options: (RowOptions | (() -> ()))?, children: (() -> ())?) -> (),
	space = require(script.widgets.space) :: (size: number?) -> (),
	portal = require(script.widgets.portal) :: (targetInstance: Instance, children: () -> ()) -> (),

	-- New egui-style widgets
	radioButton = _radioButton :: (text: string, options: RadioButtonOptions?) -> RadioButtonHandle,
	selectableLabel = _selectableLabel :: (text: string, options: SelectableLabelOptions?) -> SelectableLabelHandle,
	comboBox = _comboBox :: (options: ComboBoxOptions) -> ComboBoxHandle,
	dragValue = require(script.widgets.dragValue) :: (options: DragValueOptions?) -> number,
	progressBar = require(script.widgets.progressBar) :: (options: ProgressBarOptions) -> (),
	collapsingHeader = _collapsingHeader :: (text: string, children: () -> ()) -> CollapsingHeaderHandle,
	toggle = _toggle :: (text: string, options: ToggleOptions?) -> ToggleHandle,
	clickableLabel = _clickableLabel :: (text: string, options: ClickableLabelOptions?) -> ClickableLabelHandle,
	modal = _modal :: (options: ModalOptions, children: () -> ()) -> ModalHandle,
	popup = require(script.widgets.popup) :: (options: PopupOptions, children: () -> ()) -> (),
	childWindow = _childWindow :: (options: string | ChildWindowOptions, children: () -> ()) -> ChildWindowHandle,
	table = _table :: (options: TableOptions, children: () -> ()) -> (),
	tableRow = _tableRow :: (options: (TableRowOptions | (() -> ()))?, children: (() -> ())?) -> (),
	tableCell = _tableCell :: (options: (TableCellOptions | (() -> ()))?, children: (() -> ())?) -> (),

	demoWindow = require(script.widgets.demoWindow) :: () -> (),
}

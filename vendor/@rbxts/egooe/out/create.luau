local Runtime = require(script.Parent.Runtime)

local GUI_BASE_2D = {
	"CanvasGroup",
	"Frame",
	"ImageButton",
	"ImageLabel",
	"ScrollingFrame",
	"TextLabel",
	"TextButton",
	"ViewportFrame",
	"TextBox",
	"VideoFrame",
	"ScreenGui",
	"BillboardGui",
	"SurfaceGui",
}

--[=[
	@within EgooE
	@function create
	@param className string -- The class name of the Instance to create
	@param props table
	@return Instance -- The created instance

	Creates an Instance tree.

	- String keys set properties
	- Number keys are children
	- Function values are event handlers
	- Table keys store references: `[ref] = "name"` stores the instance at `ref.name`
]=]
local function create(className, props)
	props = props or {}

	local eventCallback = Runtime.useEventCallback()

	local instance = Instance.new(className)

	if props["AutoLocalize"] == nil and table.find(GUI_BASE_2D, className) then
		props["AutoLocalize"] = false
	end

	for key, value in pairs(props) do
		if type(value) == "function" then
			if eventCallback then
				eventCallback(instance, key, value)
			else
				instance[key]:Connect(value)
			end
		elseif type(key) == "number" then
			value.Parent = instance
		elseif type(key) == "table" then
			key[value] = instance

			if props.Name == nil then
				instance.Name = value
			end
		else
			instance[key] = value
		end
	end

	return instance
end

return create

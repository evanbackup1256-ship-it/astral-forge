--!nonstrict

local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ui = require(script.Parent.UiCore)("ui")
local Palette = require(script.Parent.CoreKit)("theme").Palette

return function(props)
	local host = React.useRef(nil)
	local dimensions, setDimensions = React.useState(Vector2.new(800, 120))
	local softMotion = props.reducedMotion == true

	React.useEffect(function()
		local frame = host.current
		if not frame then
			return nil
		end

		local function measure()
			setDimensions(frame.AbsoluteSize)
		end

		measure()
		local connection = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
		return function()
			connection:Disconnect()
		end
	end, {})

	local stacked = props.stack or dimensions.X < 600
	local hasAction = props.action ~= nil and props.cta ~= ""
	local actionWidth = if stacked then 0 else 204
	local copyWidth = UDim2.new(1, -(actionWidth + (if stacked then 0 else 24)), 0, 28)
	local meterY = dimensions.Y - (if stacked and hasAction then 62 else 8)
	local bodyHeight = math.max(24, meterY - 62)
	local children = {
		Eyebrow = React.createElement(ui.Text, {
			value = "Next goal",
			size = 12,
			color = props.accent,
			weight = Enum.FontWeight.Bold,
			sizeConstraint = UDim2.new(1, 0, 0, 18),
		}),
		Title = React.createElement(ui.Text, {
			value = props.title,
			size = 20,
			minSize = 15,
			fit = true,
			weight = Enum.FontWeight.Heavy,
			position = UDim2.fromOffset(0, 22),
			sizeConstraint = copyWidth,
		}),
		Description = React.createElement(ui.Text, {
			value = props.body,
			size = 14,
			color = Palette.creamSoft,
			wrap = true,
			position = UDim2.fromOffset(0, 56),
			sizeConstraint = UDim2.new(1, copyWidth.X.Offset, 0, bodyHeight),
		}),
		Progress = React.createElement(ui.Meter, {
			value = props.progress,
			color = props.accent,
			reducedMotion = softMotion,
			position = UDim2.fromOffset(0, meterY),
			size = UDim2.new(1, copyWidth.X.Offset, 0, 6),
		}),
	}

	if not stacked then
		children.Value = React.createElement(ui.Text, {
			value = props.value,
			size = 24,
			color = props.accent,
			weight = Enum.FontWeight.Heavy,
			align = Enum.TextXAlignment.Right,
			fit = true,
			position = UDim2.new(1, -actionWidth, 0, 0),
			sizeConstraint = UDim2.fromOffset(actionWidth, 32),
		})
		children.ValueLabel = React.createElement(ui.Text, {
			value = props.label,
			size = 12,
			color = Palette.muted,
			align = Enum.TextXAlignment.Right,
			position = UDim2.new(1, -actionWidth, 0, 34),
			sizeConstraint = UDim2.fromOffset(actionWidth, 20),
		})
	end

	if hasAction then
		children.Action = React.createElement(ui.Button, {
			text = props.cta,
			onClick = props.action,
			color = props.accent,
			reducedMotion = softMotion,
			size = if stacked then UDim2.new(1, 0, 0, 48) else UDim2.fromOffset(actionWidth, 48),
			position = if stacked then UDim2.new(0, 0, 1, -48) else UDim2.new(1, -actionWidth, 1, -48),
		})
	end

	return React.createElement("Frame", {
		Name = "GoalSummary",
		ref = host,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, children)
end

--!strict
-- Boot status text that rolls like NumberSpinner: each glyph rides a vertical reel
-- when the status string changes. Clipped host, fixed height, no AbsoluteSize bombs.

local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local _theme = require(script.Parent.theme)
local Palette = _theme.Palette

local ROLL = 0.42
local CHAR_W = 8.2
local MAX_CHARS = 42

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

local function easeOutCubic(t: number): number
	local u = 1 - clamp01(t)
	return 1 - u * u * u
end

export type Props = {
	text: string,
	clock: React.Binding<number>,
	leaving: React.Binding<number>?,
	reducedMotion: boolean?,
	textSize: number?,
	color: Color3?,
	width: number?,
	height: number?,
}

local function BootStageText(props: Props)
	local text = props.text or ""
	local clock = props.clock
	local leaving = props.leaving
	local reducedMotion = props.reducedMotion == true
	local textSize = props.textSize or 12
	local color = props.color or Palette.muted
	local width = props.width or 340
	local height = props.height or 20
	local idleLeave = React.useBinding(0)
	local exitBinding = leaving or idleLeave

	local prevRef = React.useRef(text)
	local fromRef = React.useRef(text)
	local rollStartRef = React.useRef(0)
	local rollingRef = React.useRef(false)

	React.useEffect(function()
		if text == prevRef.current then
			return
		end
		fromRef.current = prevRef.current
		prevRef.current = text
		if reducedMotion then
			rollingRef.current = false
			return
		end
		rollingRef.current = true
		-- Capture clock at change via a one-shot join; use os.clock as fallback anchor.
		rollStartRef.current = os.clock()
	end, { text, reducedMotion } :: { any })

	local glyphCount = math.min(MAX_CHARS, math.max(#text, #fromRef.current, 8))
	local children = table.create(glyphCount)

	for i = 1, glyphCount do
		local targetChar = string.sub(text, i, i)
		if targetChar == "" then
			targetChar = " "
		end
		local fromChar = string.sub(fromRef.current, i, i)
		if fromChar == "" then
			fromChar = " "
		end
		local x = (i - 0.5) * CHAR_W + (width - glyphCount * CHAR_W) * 0.5

		local motion = React.joinBindings({
			clock = clock,
			leaving = exitBinding,
		}):map(function(values)
			local fade = clamp01(values.leaving)
			local elapsed = os.clock() - rollStartRef.current
			local rolling = rollingRef.current and not reducedMotion
			local amount = if rolling then easeOutCubic(elapsed / ROLL) else 1
			if rolling and amount >= 1 then
				rollingRef.current = false
			end
			local y = if rolling and fromChar ~= targetChar then (1 - amount) * height else 0
			local ghostAlpha = if rolling and fromChar ~= targetChar then (1 - amount) else 0
			return {
				y = y,
				ghost = ghostAlpha,
				fade = fade,
			}
		end)

		children[i] = React.createElement("frame", {
			key = `boot-ch-{i}`,
			Size = UDim2.fromOffset(math.ceil(CHAR_W), height),
			Position = UDim2.fromOffset(x, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 4,
		}, React.createElement("textlabel", {
			Size = UDim2.fromOffset(math.ceil(CHAR_W) + 2, height),
			Position = motion:map(function(v)
				return UDim2.fromOffset(0, v.y)
			end),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = targetChar,
			TextColor3 = color,
			TextTransparency = motion:map(function(v)
				return clamp01(0.08 + v.fade)
			end),
			TextSize = textSize,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 5,
		}), React.createElement("textlabel", {
			Size = UDim2.fromOffset(math.ceil(CHAR_W) + 2, height),
			Position = motion:map(function(v)
				return UDim2.fromOffset(0, v.y - height)
			end),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = fromChar,
			TextColor3 = color,
			TextTransparency = motion:map(function(v)
				return clamp01(0.15 + (1 - v.ghost) + v.fade)
			end),
			TextSize = textSize,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 4,
			Visible = motion:map(function(v)
				return v.ghost > 0.02 and v.fade < 0.96
			end),
		}))
	end

	return React.createElement("frame", {
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 4,
	}, children)
end

return {
	BootStageText = BootStageText,
}

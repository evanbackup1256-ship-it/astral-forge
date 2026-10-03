local Digit = require(script:WaitForChild("Digit"))

local NumberSpinner = {}

local READ_ONLY = {
	Frame = true,
	Digits = true,
	CommaLabels = true,
	Text = true,
}
local CUSTOM_PROPS = {
	Value = "number",
	Duration = "number",
	Decimals = "number",
	Prefix = "string",
	Suffix = "string",
	Commas = "boolean",
}
local TEXT_TO_LAYOUT = {
	[Enum.TextXAlignment.Center] = Enum.HorizontalAlignment.Center,
	[Enum.TextXAlignment.Left] = Enum.HorizontalAlignment.Left,
	[Enum.TextXAlignment.Right] = Enum.HorizontalAlignment.Right,
}

local DUMMY_FRAME = Instance.new("Frame")
local DUMMY_LABEL = Instance.new("TextLabel")
DUMMY_LABEL.TextSize = 16
DUMMY_LABEL.TextColor3 = Color3.fromRGB(255, 255, 255)
-- GothamBlack — same family as Astral Forge chrome. SourceSans fails to load in Studio ("Temp read failed").
DUMMY_LABEL.FontFace = Font.fromEnum(Enum.Font.GothamBlack)

-- Doubles stay exact for integers up to 2^53 (~9e15). Above that we still render a rounded string.
-- Cap past septillion so sextillion+ catch-up stays readable without scientific notation.
local MAX_ABS = 1e24

local function clampNumber(value: number): number
	if typeof(value) ~= "number" or value ~= value then
		return 0
	end
	if value >= math.huge then
		return MAX_ABS
	end
	if value <= -math.huge then
		return -MAX_ABS
	end
	return math.clamp(value, -MAX_ABS, MAX_ABS)
end

-- Build a plain digit string without scientific notation (%.0f / %d break past ~1e14–1e15).
local function wholeDigitString(absValue: number): string
	local n = math.floor(absValue + 0.5)
	if n < 0 then
		n = 0
	end
	if n < 1e15 then
		return string.format("%.0f", n)
	end
	-- Chunk into 9-digit groups so each piece stays %.0f-safe.
	local parts = table.create(4)
	while n >= 1 do
		local chunk = math.floor(n % 1e9 + 0.5)
		n = math.floor(n / 1e9)
		if n >= 1 then
			table.insert(parts, 1, string.format("%09d", chunk))
		else
			table.insert(parts, 1, string.format("%d", chunk))
		end
	end
	if #parts == 0 then
		return "0"
	end
	return table.concat(parts)
end

local function fractionalString(absValue: number, decimals: number): string?
	if decimals <= 0 then
		return nil
	end
	local factor = 10 ^ decimals
	local scaled = math.floor(absValue * factor + 0.5)
	local frac = scaled % factor
	return string.format("%0" .. decimals .. ".0f", frac)
end

local function newSpinner()
	local Spinner = {
		-- Props
		Value = 0,
		Duration = 0.78,
		Decimals = 2,
		Prefix = "$",
		Suffix = "",
		Commas = false,

		-- Internal
		Digits = {
			Whole = table.create(3),
			Decimal = table.create(2),
		},
		CommaLabels = table.create(2),

		-- UIs (populated later)
		Frame = nil,
		Layout = nil,
		PrefixLabel = nil,
		SuffixLabel = nil,
		DecimalLabel = nil,
		NegativeLabel = nil,
	}

	local SpinnerProxy = setmetatable({}, {
		__index = function(_, key)
			local Direct = Spinner[key]
			if Direct then
				return Direct
			end

			local propExistsForFrame = pcall(function()
				local _ = DUMMY_FRAME[key]
			end)
			if propExistsForFrame then
				return Spinner.Frame[key]
			end

			local propExistsForLabel, labelProp = pcall(function()
				return DUMMY_LABEL[key]
			end)
			if propExistsForLabel then
				local digit = Spinner.Digits.Whole[1]
				if digit then
					return digit[key]
				else
					return labelProp
				end
			end

			return nil
		end,
		__newindex = function(_, key, value)
			if READ_ONLY[key] then
				warn("Attempted to set read-only value Spinner." .. key)
				return
			end

			local propExistsForFrame = pcall(function()
				local _ = DUMMY_FRAME[key]
			end)
			if propExistsForFrame then
				local t = typeof(DUMMY_FRAME[key])
				if (t ~= "nil") and (t ~= typeof(value)) then
					warn("Attempted to set Spinner." .. key .. " to invalid value (" .. tostring(value) .. ")")
					return
				end
				Spinner.Frame[key] = value
				return
			end

			if key == "TextXAlignment" then
				Spinner.Layout.HorizontalAlignment = TEXT_TO_LAYOUT[value]
				return
			end

			local propExistsForLabel = pcall(function()
				local _ = DUMMY_LABEL[key]
			end)
			if propExistsForLabel then
				local propType = typeof(DUMMY_LABEL[key])
				if (propType ~= "nil") and (propType ~= typeof(value)) then
					warn("Attempted to set Spinner." .. key .. " to invalid value (" .. tostring(value) .. ")")
					return
				end
				for _, digit in pairs(Spinner.Digits.Whole) do
					digit[key] = value
				end
				for _, digit in pairs(Spinner.Digits.Decimal) do
					digit[key] = value
				end
				for _, comma in pairs(Spinner.CommaLabels) do
					comma[key] = value
				end
				Spinner.PrefixLabel[key] = value
				Spinner.SuffixLabel[key] = value
				Spinner.DecimalLabel[key] = value
				Spinner.NegativeLabel[key] = value
				return
			end

			if CUSTOM_PROPS[key] then
				if typeof(value) ~= CUSTOM_PROPS[key] then
					warn("Attempted to set Spinner." .. key .. " to invalid value (" .. tostring(value) .. ")")
					return
				end
				if key == "Value" then
					Spinner[key] = clampNumber(value)
				else
					Spinner[key] = value
				end
				Spinner:Update(key, Spinner[key])
				return
			end
		end,
	})

	function Spinner:Destroy()
		self.Frame:Destroy()
		table.clear(self)
	end

	function Spinner:Update(Type)
		if Type == "Prefix" then
			Spinner.PrefixLabel.Text = Spinner.Prefix
			return
		elseif Type == "Suffix" then
			Spinner.SuffixLabel.Text = Spinner.Suffix
			return
		end

		local AbsValue = math.abs(clampNumber(Spinner.Value))
		local isNegative = Spinner.Value < 0

		if Spinner.NegativeLabel then
			Spinner.NegativeLabel.Visible = isNegative
		end

		local whole = wholeDigitString(AbsValue)
		local decimal = fractionalString(AbsValue, Spinner.Decimals)
		local numWhole = #whole
		if numWhole < 1 then
			whole = "0"
			numWhole = 1
		end

		for i = 1, numWhole do
			local digit = Spinner.Digits.Whole[i]
			local digitValue = tonumber(string.sub(whole, i, i)) or 0

			if digit then
				digit.Duration = Spinner.Duration
				digit.Value = digitValue
			else
				digit = Digit.new(SpinnerProxy, (i * 2) - 900, digitValue)
				Spinner.Digits.Whole[i] = digit
			end
		end
		for i = numWhole + 1, #Spinner.Digits.Whole do
			local digit = Spinner.Digits.Whole[i]
			if digit then
				digit:Destroy()
				Spinner.Digits.Whole[i] = nil
			end
		end

		if Spinner.Commas then
			-- Place commas from the RIGHT (…XX,XXX,XXX) — left-step layout broke past 6 digits.
			local commaIndex = 0
			for fromRight = 3, numWhole - 1, 3 do
				local afterDigit = numWhole - fromRight
				if afterDigit <= 0 then
					break
				end
				commaIndex += 1
				local CommaLabel = Spinner.CommaLabels[commaIndex]
				if not CommaLabel then
					CommaLabel = Instance.new("TextLabel")
					CommaLabel.Name = "Comma"
					CommaLabel.BackgroundTransparency = 1
					CommaLabel.Size = UDim2.new(0, 0, 1, 0)
					CommaLabel.FontFace = SpinnerProxy.FontFace
					CommaLabel.TextSize = SpinnerProxy.TextSize
					CommaLabel.TextColor3 = SpinnerProxy.TextColor3
					CommaLabel.Text = ","
					CommaLabel.TextXAlignment = Enum.TextXAlignment.Center
					CommaLabel.TextYAlignment = Enum.TextYAlignment.Center
					CommaLabel.TextStrokeTransparency = 1
					CommaLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
					CommaLabel.AutomaticSize = Enum.AutomaticSize.X
					CommaLabel.Parent = Spinner.Frame

					Spinner.CommaLabels[commaIndex] = CommaLabel
				end

				-- Between digit `afterDigit` (order i*2-900) and the next digit.
				CommaLabel.LayoutOrder = afterDigit * 2 - 899
				CommaLabel.Visible = true
			end

			for i = commaIndex + 1, #Spinner.CommaLabels do
				local leftover = Spinner.CommaLabels[i]
				if leftover then
					leftover:Destroy()
					Spinner.CommaLabels[i] = nil
				end
			end
		else
			for i, leftover in pairs(Spinner.CommaLabels) do
				leftover:Destroy()
				Spinner.CommaLabels[i] = nil
			end
		end

		if not decimal then
			if Spinner.DecimalLabel then
				Spinner.DecimalLabel.Visible = false
			end
			for _, digit in ipairs(Spinner.Digits.Decimal) do
				digit:Destroy()
			end
			table.clear(Spinner.Digits.Decimal)
			return
		end

		if Spinner.DecimalLabel then
			Spinner.DecimalLabel.Visible = true
		end
		for i = 1, #decimal do
			local digit = Spinner.Digits.Decimal[i]
			local digitValue = tonumber(string.sub(decimal, i, i)) or 0

			if digit then
				digit.Duration = Spinner.Duration
				digit.Value = digitValue
			else
				digit = Digit.new(SpinnerProxy, i, digitValue)
				Spinner.Digits.Decimal[i] = digit
			end
		end
		for i = #decimal + 1, #Spinner.Digits.Decimal do
			local digit = Spinner.Digits.Decimal[i]
			if digit then
				digit:Destroy()
				Spinner.Digits.Decimal[i] = nil
			end
		end
	end

	return SpinnerProxy, Spinner
end

function NumberSpinner.new()
	local Spinner, RawSpinner = newSpinner()

	local Frame = Instance.new("Frame")
	Frame.BackgroundTransparency = 1
	-- Must stay true — Host used to clear this for autoWidth and digit rolls spilled everywhere.
	Frame.ClipsDescendants = true
	Frame.Size = UDim2.new(0, 200, 0, 50)
	Frame.Position = UDim2.new(0, 0, 0, 0)

	local Layout = Instance.new("UIListLayout")
	Layout.SortOrder = Enum.SortOrder.LayoutOrder
	Layout.FillDirection = Enum.FillDirection.Horizontal
	Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Layout.VerticalAlignment = Enum.VerticalAlignment.Center
	Layout.Padding = UDim.new(0, 0)
	Layout.Parent = Frame

	local function styleChromeLabel(label: TextLabel, text: string, layoutOrder: number)
		label.LayoutOrder = layoutOrder
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(0, 0, 1, 0)
		label.FontFace = Spinner.FontFace
		label.TextSize = Spinner.TextSize
		label.TextColor3 = Spinner.TextColor3
		label.Text = text
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextScaled = false
		label.TextStrokeTransparency = 1
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Parent = Frame
	end

	local Prefix = Instance.new("TextLabel")
	Prefix.Name = "Prefix"
	styleChromeLabel(Prefix, Spinner.Prefix, -1000)

	local Suffix = Instance.new("TextLabel")
	Suffix.Name = "Suffix"
	styleChromeLabel(Suffix, Spinner.Suffix, 1000)

	local Decimal = Instance.new("TextLabel")
	Decimal.Name = "Decimal"
	styleChromeLabel(Decimal, ".", 0)

	local Negative = Instance.new("TextLabel")
	Negative.Name = "Negative"
	styleChromeLabel(Negative, "-", -999)

	RawSpinner.Frame = Frame
	RawSpinner.Layout = Layout
	RawSpinner.PrefixLabel = Prefix
	RawSpinner.SuffixLabel = Suffix
	RawSpinner.DecimalLabel = Decimal
	RawSpinner.NegativeLabel = Negative

	Spinner:Update()

	return Spinner
end

function NumberSpinner.fromGuiObject(GuiObject)
	if typeof(GuiObject) ~= "Instance" then
		return
	end
	if not GuiObject:IsA("GuiObject") then
		return
	end

	local Spinner = NumberSpinner.new()

	Spinner.Name = "Spinner_" .. GuiObject.Name
	Spinner.SizeConstraint = GuiObject.SizeConstraint
	Spinner.Size = GuiObject.Size
	Spinner.Position = GuiObject.Position
	Spinner.AnchorPoint = GuiObject.AnchorPoint
	Spinner.Rotation = GuiObject.Rotation
	Spinner.LayoutOrder = GuiObject.LayoutOrder
	Spinner.ZIndex = GuiObject.ZIndex
	Spinner.Visible = GuiObject.Visible
	Spinner.BackgroundColor3 = GuiObject.BackgroundColor3
	Spinner.BorderColor3 = GuiObject.BorderColor3
	Spinner.BorderSizePixel = GuiObject.BorderSizePixel
	Spinner.BackgroundTransparency = GuiObject.BackgroundTransparency

	if GuiObject:IsA("TextLabel") or GuiObject:IsA("TextButton") or GuiObject:IsA("TextBox") then
		Spinner.FontFace = GuiObject.FontFace
		Spinner.TextSize = GuiObject.TextSize
		Spinner.TextColor3 = GuiObject.TextColor3
		Spinner.TextTransparency = GuiObject.TextTransparency
		-- Never inherit TextStroke — stroke paints outside ClipsDescendants and reads as a
		-- misaligned black duplicate of every digit (especially under UIScale).
		Spinner.TextStrokeColor3 = Color3.new(0, 0, 0)
		Spinner.TextStrokeTransparency = 1

		Spinner.Layout.HorizontalAlignment = TEXT_TO_LAYOUT[GuiObject.TextXAlignment]
	end

	Spinner.Parent = GuiObject.Parent

	GuiObject.Visible = false

	return Spinner
end

return NumberSpinner

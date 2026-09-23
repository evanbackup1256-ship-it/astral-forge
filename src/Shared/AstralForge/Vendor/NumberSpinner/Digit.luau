local TweenService = game:GetService("TweenService")

-- Soft collapse when a digit is removed (width → 0). Create/update uses fixed width — no async bounds races.
local COLLAPSE_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)

local Digit = {}

-- Quart Out: crisp odometer settle without Back overshoot.
-- Roblox enum is Quart — Quartic is invalid and crashes Digit.new.
local function rollTweenInfo(duration: number): TweenInfo
	return TweenInfo.new(math.max(0.08, duration), Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
end

local function digitSize(textSize: number): (number, number)
	-- Pad taller than TextSize so GothamBlack glyphs aren't clipped into a dark fringe.
	-- (ClipsDescendants + flush height made adjacent-strip edges look like a black shadow.)
	local h = math.max(14, math.floor(textSize + 4))
	-- Slightly roomier than condensed metrics so columns don't shear into neighbors.
	local w = math.max(6, math.floor(textSize * 0.7 + 0.5))
	return w, h
end

function Digit.new(Spinner, LayoutOrder, Value)
	local digit = {
		Duration = Spinner.Duration,
		Value = Value,
		Shown = Value,

		Labels = table.create(10),
		CanvasTweens = table.create(10),
	}
	local tweenInfo = rollTweenInfo(Spinner.Duration)
	local activeTween: Tween? = nil
	local collapsing = false

	local w, h = digitSize(Spinner.TextSize)
	local Frame = Instance.new("Frame")
	Frame.Name = "digit"
	Frame.LayoutOrder = LayoutOrder
	Frame.BackgroundTransparency = 1
	Frame.Size = UDim2.new(0, w, 0, h)
	Frame.ClipsDescendants = true

	local Canvas = Instance.new("Frame")
	Canvas.Name = "canvas"
	Canvas.Size = UDim2.new(1, 0, 10, 0)
	Canvas.BackgroundTransparency = 1
	Canvas.Parent = Frame

	Canvas.Position = UDim2.new(0, 0, -digit.Value, 0)

	for i = 0, 9 do
		local n = Instance.new("TextLabel")
		n.Name = "n_" .. i
		n.BackgroundTransparency = 1
		n.TextSize = Spinner.TextSize
		n.TextColor3 = Spinner.TextColor3
		n.FontFace = Spinner.FontFace
		n.Text = tostring(i)
		n.TextYAlignment = Enum.TextYAlignment.Center
		n.TextXAlignment = Enum.TextXAlignment.Center
		n.TextScaled = false
		-- TextStroke is NOT clipped by ClipsDescendants — any visible stroke paints a
		-- black ghost of adjacent odometer digits offset from the current glyph.
		n.TextStrokeTransparency = 1
		n.TextStrokeColor3 = Color3.new(0, 0, 0)
		n.Size = UDim2.new(1, 0, 0.1, 0)
		n.Position = UDim2.new(0, 0, i * 0.1, 0)
		n.Parent = Canvas
		digit.Labels[i] = n
		digit.CanvasTweens[i] = TweenService:Create(Canvas, tweenInfo, { Position = UDim2.new(0, 0, -i, 0) })
	end

	Frame.Parent = Spinner.Frame

	local function applyChromeSize()
		if collapsing then
			return
		end
		local dw, dh = digitSize(Spinner.TextSize)
		Frame.Size = UDim2.new(0, dw, 0, dh)
	end

	local digitProxy = setmetatable({}, {
		__index = function(_, key)
			local Direct = digit[key]
			if Direct then
				return Direct
			end

			local propExistsForLabel = pcall(function()
				local _ = digit.Labels[1][key]
			end)
			if propExistsForLabel then
				return digit.Labels[1][key]
			end

			return nil
		end,
		__newindex = function(_, key, value)
			local Direct = digit[key]
			if Direct ~= nil or key == "Duration" or key == "Value" or key == "Shown" then
				if key == "Value" then
					digit._from = digit.Shown
				end
				digit[key] = value
				digit:Update(key, value)
				return
			end

			local propExistsForLabel = pcall(function()
				local _ = digit.Labels[1][key]
			end)
			if propExistsForLabel then
				for i = 0, 9 do
					digit.Labels[i][key] = value
				end
				digit:Update(key, value)
			end
		end,
	})

	function digit:Destroy()
		if collapsing then
			return
		end
		collapsing = true
		if activeTween then
			activeTween:Cancel()
			activeTween = nil
		end
		local tween = TweenService:Create(Frame, COLLAPSE_TWEEN, { Size = UDim2.new(0, 0, 0, Frame.Size.Y.Offset) })
		tween.Completed:Connect(function()
			Frame:Destroy()
			table.clear(digit)
			tween:Destroy()
		end)
		tween:Play()
	end

	function digit:Update(Type, UpdateValue)
		if Type == "Duration" then
			tweenInfo = rollTweenInfo(UpdateValue)
			for i = 0, 9 do
				digit.CanvasTweens[i] = TweenService:Create(Canvas, tweenInfo, { Position = UDim2.new(0, 0, -i, 0) })
			end
		elseif Type == "Value" then
			local target = UpdateValue
			if typeof(target) ~= "number" then
				return
			end
			target = math.clamp(math.floor(target), 0, 9)
			local from = digit._from
			if typeof(from) ~= "number" then
				from = digit.Shown
			end
			digit.Shown = target
			digit._from = nil

			if activeTween then
				activeTween:Cancel()
				activeTween = nil
			end

			-- Near-zero duration: snap (high-rate production ticks / huge catch-up).
			if digit.Duration <= 0.12 then
				Canvas.Position = UDim2.new(0, 0, -target, 0)
				return
			end

			-- Same-digit force-roll only on deliberate slow rolls (buys / vault).
			-- Continuous FLUX catch-up used to spin every unchanged digit and looked broken.
			if from == target then
				if digit.Duration < 0.34 then
					Canvas.Position = UDim2.new(0, 0, -target, 0)
					return
				end
				local offset = (target + 4) % 10
				Canvas.Position = UDim2.new(0, 0, -offset, 0)
			end

			local tween = TweenService:Create(Canvas, tweenInfo, { Position = UDim2.new(0, 0, -target, 0) })
			digit.CanvasTweens[target] = tween
			activeTween = tween
			tween:Play()
		elseif Type == "TextSize" or Type == "FontFace" then
			applyChromeSize()
		end
	end

	return digitProxy
end

return Digit

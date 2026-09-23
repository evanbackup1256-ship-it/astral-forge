local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local compactSpinParts = require(script.Parent.format).compactSpinParts
local ClientLog = require(script.Parent.log).ClientLog
local useMotionSettings = require(script.Parent.motion).useMotionSettings
local _theme = require(script.Parent.theme)
local Palette = _theme.Palette
local lighten = _theme.lighten
local AUTO_WIDTH_PAD = 4
local function estimateLabelWidth(text, textSize)
	return math.max(4, math.ceil(#text * textSize * 0.7)) + AUTO_WIDTH_PAD
end
local SPINNER_FONT = Font.fromEnum(Enum.Font.RobotoMono)
local function findSpinnerLayout(host)
	for _, child in host:GetChildren() do
		if not child:IsA("GuiObject") or child.Name == "NumberSpinnerGuide" then
			continue
		end
		local layout = child:FindFirstChildOfClass("UIListLayout")
		if layout ~= nil then
			return layout
		end
	end
	return nil
end
local function hugSpinnerContent(host)
	for _, child in host:GetChildren() do
		if not child:IsA("GuiObject") or child.Name == "NumberSpinnerGuide" then
			continue
		end
		local layout = child:FindFirstChildOfClass("UIListLayout")
		if layout == nil then
			continue
		end
		child.AutomaticSize = Enum.AutomaticSize.X
		child.Size = UDim2.new(0, 0, 1, 0)
		child.ClipsDescendants = true
		return layout
	end
	return nil
end
local SPINNER_RS_PATH = "ReplicatedStorage.AstralForge.Shared.NumberSpinner"
local cachedModule
local loadFailed = false
local pendingWarned = false
local function resolveModuleScript(node)
	if node:IsA("ModuleScript") then
		return node
	end
	local initChild = node:FindFirstChild("init")
	if initChild ~= nil and initChild:IsA("ModuleScript") then
		return initChild
	end
	return nil
end
local function childNames(parent)
	local names = {}
	for _, child in parent:GetChildren() do
		local _name = child.Name
		table.insert(names, _name)
	end
	return if #names > 0 then table.concat(names, ", ") else "(none)"
end
local function loadModule()
	if cachedModule ~= nil then
		return cachedModule
	end
	if loadFailed then
		return nil
	end
	local astral = ReplicatedStorage:FindFirstChild("AstralForge")
	if astral == nil then
		if not pendingWarned then
			pendingWarned = true
			ClientLog:warnEvery("spinner-root", 15, "spinner", `{SPINNER_RS_PATH} is not replicated`)
		end
		return nil
	end
	local sharedFolder = astral:FindFirstChild("Shared")
	if sharedFolder == nil then
		if not pendingWarned then
			pendingWarned = true
			ClientLog:warnEvery("spinner-shared", 15, "spinner", `Shared folder missing (have {childNames(astral)})`)
		end
		return nil
	end
	local node = sharedFolder:FindFirstChild("NumberSpinner")
	if node == nil then
		if not pendingWarned then
			pendingWarned = true
			ClientLog:warnEvery("spinner-module", 15, "spinner", `NumberSpinner missing (have {childNames(sharedFolder)})`)
		end
		return nil
	end
	local moduleScript = resolveModuleScript(node)
	if moduleScript == nil then
		ClientLog:warn("spinner", `NumberSpinner is a {node.ClassName}, not a ModuleScript`)
		loadFailed = true
		return nil
	end
	local ok, result = pcall(function()
		return require(moduleScript)
	end)
	if not ok or result == nil then
		ClientLog:warn("spinner", `couldn't load NumberSpinner: {tostring(result)}`)
		loadFailed = true
		return nil
	end
	local _new = result.new
	if type(_new) == "function" ~= true then
		ClientLog:warn("spinner", "loaded module has no constructor")
		loadFailed = true
		return nil
	end
	cachedModule = result
	pendingWarned = false
	return cachedModule
end
local function sanitizeValue(value, decimals)
	local _value = value
	local _condition = not (type(_value) == "number")
	if not _condition then
		_condition = value ~= value or value == math.huge or value == -math.huge
	end
	if _condition then
		return 0
	end
	local capped = math.clamp(value, -1e100, 1e100)
	if decimals <= 0 then
		return math.floor(capped + (if capped >= 0 then 0.5 else -0.5))
	end
	local factor = 10 ^ decimals
	return math.floor(capped * factor + (if capped >= 0 then 0.5 else -0.5)) / factor
end
local function spinDisplay(raw, extraSuffix)
	local parts = compactSpinParts(raw)
	return {
		value = parts.value,
		suffix = `{parts.suffix}{extraSuffix}`,
		decimals = parts.decimals,
		band = parts.suffix,
	}
end
local function formatRawLabel(value, prefix, extraSuffix)
	local display = spinDisplay(value, extraSuffix)
	local amount = sanitizeValue(display.value, display.decimals)
	local abs = math.abs(amount)
	local body = string.format(if display.decimals <= 0 then "%.0f" elseif display.decimals == 1 then "%.1f" else "%.2f", abs)
	return `{prefix}{if amount < 0 then "-" else ""}{body}{display.suffix}`
end
local function applyChrome(spinner, opts)
	spinner.Duration = opts.duration
	spinner.Decimals = opts.decimals
	spinner.Prefix = opts.prefix
	spinner.Suffix = opts.suffix
	spinner.TextSize = opts.size
	spinner.TextColor3 = opts.color
	spinner.TextStrokeTransparency = 1
	spinner.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	spinner.FontFace = SPINNER_FONT
	spinner.TextXAlignment = opts.align
	spinner.Commas = false
	spinner.ClipsDescendants = true
end
local function setDigitTracking(spinner, scale, gap)
	spinner.Layout.Padding = UDim.new(0, math.clamp(math.floor(gap), -3, 6))
	if scale >= 0.995 then
		return nil
	end
	local baseWidth = math.max(6, math.floor(spinner.TextSize * 0.7 + 0.5))
	local width = math.max(6, math.floor(baseWidth * math.clamp(scale, 0.65, 1) + 0.5))
	for _, child in spinner.Frame:GetChildren() do
		if not child:IsA("Frame") or child.Name ~= "digit" then
			continue
		end
		child.Size = UDim2.fromOffset(width, child.Size.Y.Offset)
	end
end
local function rollDurationForJump(base, fromRaw, toRaw, fromBand, toBand, motionScale)
	local scale = math.clamp(if motionScale == nil then 1 else motionScale, 0.35, 1.35)
	if fromBand ~= toBand then
		return 0.04 * scale
	end
	local jump = math.abs(toRaw - fromRaw)
	local magnitude = math.log10(math.max(1, jump))
	local rel = if fromRaw > 0 then jump / fromRaw else jump
	if magnitude >= 6 or rel >= 0.35 then
		return 0.08 * scale
	end
	if magnitude >= 4 or rel >= 0.12 then
		return 0.16 * scale
	end
	local fromParts = compactSpinParts(fromRaw)
	local toParts = compactSpinParts(toRaw)
	local mantJump = math.abs(toParts.value - fromParts.value)
	if mantJump >= 50 then
		return 0.14 * scale
	end
	if mantJump >= 8 then
		return 0.24 * scale
	end
	return math.clamp(base * 0.62 * scale, 0.26, 0.48)
end
local VELOCITY_TICK_HZ = 5
local VELOCITY_TICK_DT = 1 / VELOCITY_TICK_HZ
local VELOCITY_ROLL = 0.07
local function NumberSpinnerHost(_param)
	local value = _param.value
	local requestedReducedMotion = _param.reducedMotion
	if requestedReducedMotion == nil then
		requestedReducedMotion = false
	end
	local duration = _param.duration
	if duration == nil then
		duration = 0.78
	end
	local prefix = _param.prefix
	if prefix == nil then
		prefix = ""
	end
	local extraSuffix = _param.extraSuffix
	if extraSuffix == nil then
		extraSuffix = ""
	end
	local _decimals = _param.decimals
	if _decimals == nil then
		_decimals = 0
	end
	local velocity = _param.velocity
	if velocity == nil then
		velocity = 0
	end
	local size = _param.size
	if size == nil then
		size = 16
	end
	local color = _param.color
	if color == nil then
		color = Palette.white
	end
	local align = _param.align
	if align == nil then
		align = Enum.TextXAlignment.Left
	end
	local position = _param.position
	local sizeConstraint = _param.sizeConstraint
	if sizeConstraint == nil then
		sizeConstraint = UDim2.fromScale(1, 1)
	end
	local autoWidth = _param.autoWidth
	if autoWidth == nil then
		autoWidth = false
	end
	local digitWidthScale = _param.digitWidthScale
	if digitWidthScale == nil then
		digitWidthScale = 1
	end
	local digitGap = _param.digitGap
	if digitGap == nil then
		digitGap = 0
	end
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 1
	end
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local _binding = useMotionSettings()
	local numberScale = _binding.numberScale
	if numberScale == nil then
		numberScale = 1
	end
	local motionScale = _binding.motionScale
	if motionScale == nil then
		motionScale = 1
	end
	local reducedMotion = requestedReducedMotion or numberScale <= 0.02
	local hostRef = React.useRef()
	local spinnerRef = React.useRef()
	local guideRef = React.useRef()
	local fallbackRef = React.useRef()
	local lastRawRef = React.useRef(nil)
	local lastBandRef = React.useRef("")
	local lastMantissaRef = React.useRef(nil)
	local targetRef = React.useRef(value)
	local velocityRef = React.useRef(velocity)
	local autoWidthRef = React.useRef(autoWidth)
	local styleRef = React.useRef({
		duration = duration,
		prefix = prefix,
		extraSuffix = extraSuffix,
		size = size,
		color = color,
		align = align,
		digitWidthScale = digitWidthScale,
		digitGap = digitGap,
	})
	local velocitySnapRef = React.useRef(false)
	local pulseResetRef = React.useRef()
	local motionScaleRef = React.useRef(motionScale)
	motionScaleRef.current = motionScale
	local live, setLive = React.useState(false)
	local label = formatRawLabel(value, prefix, extraSuffix)
	local contentWidth, setContentWidth = React.useState(function()
		return estimateLabelWidth(label, size)
	end)
	targetRef.current = value
	velocityRef.current = velocity
	autoWidthRef.current = autoWidth
	styleRef.current = {
		duration = duration,
		prefix = prefix,
		extraSuffix = extraSuffix,
		size = size,
		color = color,
		align = align,
		digitWidthScale = digitWidthScale,
		digitGap = digitGap,
	}
	local pulseAccent = React.useCallback(function(spinner, base)
		if pulseResetRef.current ~= nil then
			task.cancel(pulseResetRef.current)
		end
		spinner.TextColor3 = lighten(base, 0.48)
		pulseResetRef.current = task.delay(0.18, function()
			pulseResetRef.current = nil
			if spinnerRef.current ~= spinner then
				return nil
			end
			spinner.TextColor3 = styleRef.current.color
		end)
	end, {})
	local destroySpinner = React.useCallback(function()
		if pulseResetRef.current ~= nil then
			task.cancel(pulseResetRef.current)
			pulseResetRef.current = nil
		end
		local spinner = spinnerRef.current
		spinnerRef.current = nil
		lastRawRef.current = nil
		lastMantissaRef.current = nil
		lastBandRef.current = ""
		if spinner ~= nil then
			pcall(function()
				return spinner.Destroy()
			end)
		end
		local guide = guideRef.current
		if guide ~= nil then
			guide:Destroy()
			guideRef.current = nil
		end
		local fallback = fallbackRef.current
		if fallback ~= nil then
			fallback.Visible = true
			fallback.TextTransparency = 0
		end
		setLive(false)
	end, {})
	local pushDisplay = React.useCallback(function(spinner, raw, roll, pulse)
		local style = styleRef.current
		local display = spinDisplay(raw, style.extraSuffix)
		local mantissa = sanitizeValue(display.value, display.decimals)
		applyChrome(spinner, {
			duration = roll,
			decimals = display.decimals,
			prefix = style.prefix,
			suffix = display.suffix,
			size = style.size,
			color = style.color,
			align = style.align,
		})
		local prevMantissa = lastMantissaRef.current
		local bandChanged = lastBandRef.current ~= display.band
		lastRawRef.current = raw
		lastBandRef.current = display.band
		if prevMantissa ~= mantissa or bandChanged then
			spinner.Value = mantissa
			setDigitTracking(spinner, style.digitWidthScale, style.digitGap)
			lastMantissaRef.current = mantissa
			if pulse and prevMantissa ~= nil then
				pulseAccent(spinner, style.color)
			end
		end
	end, { pulseAccent })
	local ensureSpinner = React.useCallback(function()
		if reducedMotion then
			return nil
		end
		local existing = spinnerRef.current
		if existing ~= nil and existing.Parent ~= nil then
			return existing
		end
		destroySpinner()
		local host = hostRef.current
		local mod = loadModule()
		if host == nil or mod == nil then
			return nil
		end
		local fallback = fallbackRef.current
		if fallback ~= nil then
			fallback.Visible = false
			fallback.TextTransparency = 1
		end
		local style = styleRef.current
		local guide = Instance.new("TextLabel")
		guide.Name = "NumberSpinnerGuide"
		guide.BackgroundTransparency = 1
		guide.BorderSizePixel = 0
		guide.Size = if autoWidthRef.current then UDim2.new(0, 0, 1, 0) else UDim2.fromScale(1, 1)
		guide.AutomaticSize = if autoWidthRef.current then Enum.AutomaticSize.X else Enum.AutomaticSize.None
		guide.FontFace = SPINNER_FONT
		guide.TextSize = style.size
		guide.TextColor3 = style.color
		guide.TextXAlignment = style.align
		guide.TextYAlignment = Enum.TextYAlignment.Center
		guide.TextScaled = false
		guide.TextStrokeTransparency = 1
		guide.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		guide.Text = ""
		guide.Parent = host
		guideRef.current = guide
		local spinner = if mod.fromGuiObject ~= nil then mod.fromGuiObject(guide) else nil
		if spinner == nil then
			spinner = mod.new()
			spinner.Parent = host
			spinner.Size = if autoWidthRef.current then UDim2.new(0, 0, 1, 0) else UDim2.fromScale(1, 1)
			spinner.Position = UDim2.fromScale(0, 0)
			spinner.BackgroundTransparency = 1
			spinner.FontFace = guide.FontFace
			guide.Visible = false
		end
		if autoWidthRef.current then
			spinner.AutomaticSize = Enum.AutomaticSize.X
			spinner.Size = UDim2.new(0, 0, 1, 0)
			spinner.ClipsDescendants = true
			hugSpinnerContent(host)
		end
		local initialRaw = targetRef.current
		local display = spinDisplay(initialRaw, style.extraSuffix)
		applyChrome(spinner, {
			duration = 0.08,
			decimals = display.decimals,
			prefix = style.prefix,
			suffix = display.suffix,
			size = style.size,
			color = style.color,
			align = style.align,
		})
		local mantissa = sanitizeValue(display.value, display.decimals)
		spinner.Value = mantissa
		setDigitTracking(spinner, style.digitWidthScale, style.digitGap)
		lastRawRef.current = initialRaw
		lastBandRef.current = display.band
		lastMantissaRef.current = mantissa
		spinnerRef.current = spinner
		setLive(true)
		return spinner
	end, { destroySpinner, reducedMotion })
	React.useEffect(function()
		if reducedMotion then
			destroySpinner()
			return nil
		end
		local cancelled = false
		local attempts = 0
		local retryJob
		local tryMount
		tryMount = function()
			if cancelled then
				return nil
			end
			attempts += 1
			if ensureSpinner() == nil and attempts < 100 then
				retryJob = task.delay(0.1, tryMount)
			end
		end
		local mountJob = task.defer(tryMount)
		return function()
			cancelled = true
			if mountJob ~= nil then
				task.cancel(mountJob)
			end
			if retryJob ~= nil then
				task.cancel(retryJob)
			end
			mountJob = nil
			retryJob = nil
			destroySpinner()
		end
	end, { destroySpinner, ensureSpinner, reducedMotion })
	React.useEffect(function()
		if reducedMotion then
			return nil
		end
		local spinner = ensureSpinner()
		if spinner == nil then
			return nil
		end
		local style = styleRef.current
		local previous = lastRawRef.current
		local producing = velocityRef.current > 0
		if producing and previous ~= nil then
			local jump = math.abs(value - previous)
			if jump > 0 and jump < math.max(3, velocityRef.current * 0.35) then
				return nil
			end
		end
		local fromBand = if previous ~= nil then spinDisplay(previous, style.extraSuffix).band else ""
		local toBand = spinDisplay(value, style.extraSuffix).band
		local roll = if previous ~= nil then rollDurationForJump(style.duration, previous, value, fromBand, toBand, motionScaleRef.current) else 0.08
		velocitySnapRef.current = false
		local jump = if previous ~= nil then math.abs(value - previous) else 0
		local shouldPulse = previous ~= nil and jump >= math.max(18, math.abs(previous) * 0.03 + 1)
		pushDisplay(spinner, value, roll, shouldPulse)
	end, { align, color, duration, ensureSpinner, extraSuffix, prefix, pushDisplay, reducedMotion, size, value })
	React.useEffect(function()
		if not live or reducedMotion or velocity <= 0 then
			return nil
		end
		local alive = true
		local _condition = lastRawRef.current
		if _condition == nil then
			_condition = targetRef.current
		end
		local displayRaw = _condition
		local previousAt = os.clock()
		local worker = task.spawn(function()
			while alive do
				task.wait(VELOCITY_TICK_DT)
				if not alive then
					break
				end
				local now = os.clock()
				local dt = math.min(1, now - previousAt)
				previousAt = now
				local spinner = ensureSpinner()
				if spinner == nil then
					continue
				end
				local server = targetRef.current
				local rate = math.max(0, velocityRef.current)
				if server > displayRaw then
					displayRaw = server
				end
				displayRaw += rate * dt
				local ceiling = server + rate * 2
				if displayRaw > ceiling then
					displayRaw = ceiling
				end
				local style = styleRef.current
				local compact = spinDisplay(displayRaw, style.extraSuffix)
				local mantissa = sanitizeValue(compact.value, compact.decimals)
				if mantissa == lastMantissaRef.current and compact.band == lastBandRef.current then
					lastRawRef.current = displayRaw
					continue
				end
				local bandChanged = lastBandRef.current ~= compact.band
				local roll = if bandChanged then 0.03 else VELOCITY_ROLL
				if not velocitySnapRef.current or bandChanged then
					velocitySnapRef.current = true
				end
				applyChrome(spinner, {
					duration = roll,
					decimals = compact.decimals,
					prefix = style.prefix,
					suffix = compact.suffix,
					size = style.size,
					color = style.color,
					align = style.align,
				})
				spinner.Value = mantissa
				lastRawRef.current = displayRaw
				lastBandRef.current = compact.band
				lastMantissaRef.current = mantissa
			end
		end)
		return function()
			alive = false
			task.cancel(worker)
		end
	end, { ensureSpinner, live, reducedMotion, velocity })
	React.useEffect(function()
		if not autoWidth then
			return nil
		end
		if reducedMotion or not live then
			setContentWidth(estimateLabelWidth(label, size))
			return nil
		end
		local host = hostRef.current
		if host == nil then
			return nil
		end
		local connections = {}
		local boundLayout
		local layoutConnection
		local settleJob
		local cancelled = false
		local sync
		sync = function()
			if cancelled then
				return nil
			end
			local layout = hugSpinnerContent(host) or findSpinnerLayout(host)
			if layout == nil then
				return nil
			end
			if boundLayout ~= layout then
				local _result = layoutConnection
				if _result ~= nil then
					_result:Disconnect()
				end
				boundLayout = layout
				layoutConnection = layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(sync)
			end
			local measured = math.ceil(layout.AbsoluteContentSize.X) + AUTO_WIDTH_PAD
			if measured > AUTO_WIDTH_PAD then
				setContentWidth(function(current)
					return math.max(current, measured)
				end)
			end
			if settleJob ~= nil then
				task.cancel(settleJob)
			end
			settleJob = task.delay(0.24, function()
				settleJob = nil
				if cancelled or boundLayout == nil then
					return nil
				end
				local settled = math.ceil(boundLayout.AbsoluteContentSize.X) + AUTO_WIDTH_PAD
				if settled > AUTO_WIDTH_PAD then
					setContentWidth(settled)
				end
			end)
		end
		sync()
		local _arg0 = host.ChildAdded:Connect(sync)
		table.insert(connections, _arg0)
		return function()
			cancelled = true
			if settleJob ~= nil then
				task.cancel(settleJob)
			end
			local _result = layoutConnection
			if _result ~= nil then
				_result:Disconnect()
			end
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, { autoWidth, live, reducedMotion, size })
	React.useEffect(function()
		if not autoWidth or (not reducedMotion and live) then
			return nil
		end
		setContentWidth(estimateLabelWidth(label, size))
	end, { autoWidth, label, live, reducedMotion, size })
	local height = if sizeConstraint.Y.Offset > 0 then sizeConstraint.Y.Offset else size + 8
	local frameSize = if autoWidth then UDim2.fromOffset(math.max(1, contentWidth), height) else sizeConstraint
	local hostSize = if autoWidth then UDim2.new(0, 0, 1, 0) else UDim2.fromScale(1, 1)
	return React.createElement("frame", {
		Size = frameSize,
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = zIndex,
		LayoutOrder = layoutOrder,
	}, React.createElement("frame", {
		ref = hostRef,
		Size = hostSize,
		AutomaticSize = if autoWidth then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = zIndex + 1,
	}), (reducedMotion or not live) and (if autoWidth then React.createElement("textlabel", {
		ref = fallbackRef,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = label,
		TextColor3 = color,
		TextSize = size,
		FontFace = SPINNER_FONT,
		TextXAlignment = align,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextStrokeTransparency = 1,
		ZIndex = zIndex,
	}) else React.createElement("textlabel", {
		ref = fallbackRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = label,
		TextColor3 = color,
		TextSize = size,
		FontFace = SPINNER_FONT,
		TextXAlignment = align,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextStrokeTransparency = 1,
		ZIndex = zIndex,
	})))
end
return {
	NumberSpinnerHost = NumberSpinnerHost,
}

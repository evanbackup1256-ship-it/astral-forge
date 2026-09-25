local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Audio = require(script.Parent.Parent.audio).Audio
local _motion = require(script.Parent.Parent.motion)
local useFlash = _motion.useFlash
local useFlipperSpring = _motion.useFlipperSpring
local _theme = require(script.Parent.Parent.theme)
local contrastOn = _theme.contrastOn
local darken = _theme.darken
local lighten = _theme.lighten
local Palette = _theme.Palette
--[[
	*
	 * Shared "something happened" acknowledgement for buttons.
	 *
	 * Roblox buttons already ripple on press, but a press only says "I registered your
	 * finger" — it never says "the action landed". `useButtonNotice` adds a short badge +
	 * surface flash that fires *after* an action runs, so Buy All / Claim / Equip / Confirm
	 * all confirm themselves in place instead of relying purely on a toast that may be
	 * scrolled off, suppressed, or hidden behind mobile chrome.
	 
]]
local TONE_ACCENT = {
	success = Palette.mint,
	info = Palette.cyan,
	warn = Palette.mango,
	error = Palette.coral,
	pending = Palette.violet,
}
local TONE_LABEL = {
	success = "DONE",
	info = "SENT",
	warn = "HOLD",
	error = "FAILED",
	pending = "WORKING",
}
local TONE_SOUND = {
	success = "noticeSuccess",
	info = "noticeInfo",
	warn = "noticeWarning",
	error = "noticeError",
	pending = "tick",
}
local function buttonNoticeAccent(tone)
	return TONE_ACCENT[tone]
end
local function useButtonNotice(options)
	if options == nil then
		options = {}
	end
	local reducedMotion = options.reducedMotion == true
	local _condition = options.holdSeconds
	if _condition == nil then
		_condition = 1.35
	end
	local hold = math.clamp(_condition, 0.35, 6)
	local _condition_1 = options.label
	if _condition_1 == nil then
		_condition_1 = TONE_LABEL[options.tone or "success"]
	end
	local fallbackLabel = _condition_1
	local fallbackTone = options.tone or "success"
	local sound = options.sound
	local trigger, setTrigger = React.useState(0)
	local count, setCount = React.useState(0)
	local active, setActive = React.useState(false)
	local label, setLabel = React.useState(fallbackLabel)
	local tone, setTone = React.useState(fallbackTone)
	local lastAt = React.useRef(0)
	local flash = useFlash(trigger, reducedMotion, 0.46)
	local pop = useFlipperSpring(if active then 1 else 0, reducedMotion, 820, 26)
	React.useEffect(function()
		if not active then
			return nil
		end
		local alive = true
		local token = task.delay(hold, function()
			if alive then
				setActive(false)
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, token)
		end
	end, { active, hold, trigger })
	local notify = React.useCallback(function(nextLabel, nextTone)
		local resolvedTone = nextTone or fallbackTone
		setTone(resolvedTone)
		local _condition_2 = nextLabel
		if _condition_2 == nil then
			_condition_2 = (if nextTone ~= nil then TONE_LABEL[resolvedTone] else fallbackLabel)
		end
		setLabel(_condition_2)
		setTrigger(function(current)
			return current + 1
		end)
		setCount(function(current)
			return current + 1
		end)
		setActive(true)
		lastAt.current = os.clock()
		if sound ~= false then
			Audio:play(sound or TONE_SOUND[resolvedTone], 1)
		end
	end, { fallbackLabel, fallbackTone, sound })
	local wrap = React.useCallback(function(handler, nextLabel, nextTone)
		return function()
			handler()
			notify(nextLabel, nextTone)
		end
	end, { notify })
	local clear = React.useCallback(function()
		return setActive(false)
	end, {})
	return {
		active = active,
		count = count,
		label = label,
		tone = tone,
		accent = TONE_ACCENT[tone],
		flash = flash,
		pop = pop,
		lastAt = lastAt.current,
		notify = notify,
		wrap = wrap,
		clear = clear,
	}
end
--[[
	*
	 * Drop this inside a `<Button>` as a child. It paints a short white wash across the
	 * button surface plus a small pill in the top-right corner.
	 
]]
local function ButtonNoticeBadge(_param)
	local notice = _param.notice
	local radius = _param.radius
	if radius == nil then
		radius = 9
	end
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 40
	end
	local corner = _param.corner
	if corner == nil then
		corner = "tr"
	end
	local showLabel = _param.showLabel
	if showLabel == nil then
		showLabel = true
	end
	local accent = notice.accent
	local ink = contrastOn(accent)
	local caption = if notice.label == "" then TONE_LABEL[notice.tone] else notice.label
	local pillWidth = if showLabel then math.clamp(18 + #caption * 7, 30, 92) else 14
	local pillHeight = if showLabel then 18 else 14
	local anchor = if corner == "tr" then Vector2.new(1, 0) elseif corner == "tl" then Vector2.new(0, 0) elseif corner == "br" then Vector2.new(1, 1) else Vector2.new(0, 1)
	local pillPosition = if corner == "tr" then UDim2.new(1, -5, 0, 4) elseif corner == "tl" then UDim2.new(0, 5, 0, 4) elseif corner == "br" then UDim2.new(1, -5, 1, -4) else UDim2.new(0, 5, 1, -4)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		Active = false,
		ClipsDescendants = false,
	}, React.createElement("frame", {
		Key = "wash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = lighten(accent, 0.42),
		BackgroundTransparency = notice.flash:map(function(amount)
			return math.clamp(1 - amount * 0.46, 0, 1)
		end),
		BorderSizePixel = 0,
		ZIndex = zIndex,
		Active = false,
		Visible = notice.flash:map(function(amount)
			return amount > 0.015
		end),
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	})), React.createElement("frame", {
		Key = "pill",
		Size = UDim2.fromOffset(pillWidth, pillHeight),
		Position = pillPosition,
		AnchorPoint = anchor,
		BackgroundColor3 = accent,
		BackgroundTransparency = notice.pop:map(function(amount)
			return math.clamp(1 - amount, 0, 1)
		end),
		BorderSizePixel = 0,
		ZIndex = zIndex + 1,
		Active = false,
		Visible = notice.pop:map(function(amount)
			return amount > 0.02
		end),
	}, React.createElement("uiscale", {
		Scale = notice.pop:map(function(amount)
			return 0.72 + math.clamp(amount, 0, 1.15) * 0.28
		end),
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = darken(accent, 0.45),
		Thickness = 1,
		Transparency = notice.pop:map(function(amount)
			return math.clamp(1 - amount * 0.7, 0, 1)
		end),
	}), if showLabel then React.createElement("textlabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = caption,
		TextColor3 = ink,
		TextTransparency = notice.pop:map(function(amount)
			return math.clamp(1 - amount, 0, 1)
		end),
		TextSize = 11,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = zIndex + 2,
	}) else nil))
end
--[[
	*
	 * Minimal variant: a single pip, no caption. Good for tiny icon-only buttons.
	 
]]
local function ButtonNoticePip(_param)
	local notice = _param.notice
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 40
	end
	return ButtonNoticeBadge({
		notice = notice,
		zIndex = zIndex,
		showLabel = false,
	})
end
return {
	buttonNoticeAccent = buttonNoticeAccent,
	useButtonNotice = useButtonNotice,
	ButtonNoticeBadge = ButtonNoticeBadge,
	ButtonNoticePip = ButtonNoticePip,
}

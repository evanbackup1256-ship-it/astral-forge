local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Audio = require(script.Parent.Parent.audio).Audio
local formatReward = require(script.Parent.Parent.format).formatReward
local Icon = require(script.Parent.Parent.Icon).Icon
local ClientLog = require(script.Parent.Parent.log).ClientLog
local _motion = require(script.Parent.Parent.motion)
local useEntrance = _motion.useEntrance
local useFlipperSpring = _motion.useFlipperSpring
local usePulse = _motion.usePulse
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.theme)
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local darken = _theme.darken
local Layout = _theme.Layout
local TapTarget = _theme.TapTarget
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local _ui = require(script.Parent.Parent.ui)
local Badge = _ui.Badge
local Button = _ui.Button
local Meter = _ui.Meter
local meterFill = _ui.meterFill
local Text = _ui.Text
local function illuminate(text, accent)
	local rgb = `{math.floor(accent.R * 255)},{math.floor(accent.G * 255)},{math.floor(accent.B * 255)}`
	local result = text
	for _, phrase in { "Bay Seven", "Stellar Core", "ILYRA VALE", "Astral Forge", "Hollow Star", "stars" } do
		local _result = result
		local _arg1 = `<font color="rgb({rgb})"><b>{phrase}</b></font>`
		local updated = string.gsub(_result, phrase, _arg1)
		result = updated
	end
	return result
end
local function ArchiveMark(_param)
	local accent = _param.accent
	local active = _param.active
	local reducedMotion = _param.reducedMotion
	local beat = _param.beat
	local total = _param.total
	local compact = _param.compact
	local finished = _param.finished
	local unlocked = _param.unlocked
	local unlockProgress = _param.unlockProgress
	if unlockProgress == nil then
		unlockProgress = 0
	end
	local unlockLabel = _param.unlockLabel
	local pulse = usePulse(active and not reducedMotion, 1.2)
	local enter = useEntrance(reducedMotion)
	local progress = if active then meterFill(beat + 1, math.max(1, total)) elseif finished then 1 else math.clamp(unlockProgress, 0, 1)
	local statusLabel = if not active and finished then "REPLAY" elseif active then "READING" elseif unlocked then "READY" else "LOCKED"
	local _result
	if active then
		_result = `Part {beat + 1} / {math.max(1, total)}`
	else
		local _result_1
		if finished then
			_result_1 = "Finished chapter"
		else
			local _result_2
			if unlocked then
				_result_2 = "Ready to read"
			else
				local _condition = unlockLabel
				if _condition == nil then
					_condition = "Bay Seven"
				end
				_result_2 = _condition
			end
			_result_1 = _result_2
		end
		_result = _result_1
	end
	local detail = _result
	if compact then
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = darken(accent, 0.92),
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 12),
		}), React.createElement("uigradient", {
			Color = ColorSequence.new(darken(accent, 0.86), Palette.void),
			Rotation = 90,
		}), React.createElement("frame", {
			Size = UDim2.new(0, 3, 1, -16),
			Position = UDim2.fromOffset(0, 8),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 2),
		})), React.createElement(Icon, {
			kind = "Story",
			color = Palette.cream,
			accent = accent,
			size = 32,
			position = UDim2.fromOffset(14, 14),
			spin = false,
			reducedMotion = reducedMotion,
		}), React.createElement(Text, {
			value = statusLabel,
			size = 11,
			color = accent,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			position = UDim2.fromOffset(56, 12),
			sizeConstraint = UDim2.new(1, -70, 0, 16),
		}), React.createElement(Text, {
			value = detail,
			size = 13,
			color = Palette.cream,
			weight = Enum.FontWeight.Bold,
			fit = false,
			position = UDim2.fromOffset(56, 30),
			sizeConstraint = UDim2.new(1, -70, 0, 18),
		}), React.createElement(Meter, {
			value = progress,
			color = accent,
			reducedMotion = reducedMotion,
			position = UDim2.fromOffset(14, 54),
			size = UDim2.new(1, -28, 0, 5),
		}))
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = darken(accent, 0.92),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(darken(accent, 0.86), Palette.void),
		Rotation = 112,
	}), React.createElement("frame", {
		Size = UDim2.new(0, 3, 0.5, 0),
		Position = UDim2.new(0, 2, 0.25, 0),
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 2),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(84, 84),
		Position = UDim2.new(0.5, 0, 0, 28),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Palette.panel,
		BackgroundTransparency = enter:map(function(amount)
			return 1 - amount
		end),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uiscale", {
		Scale = pulse:map(function(amount)
			return 1 + amount * 0.03
		end),
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 22),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 1,
		Transparency = 0.28,
	}), React.createElement(Icon, {
		kind = "Story",
		color = Palette.cream,
		accent = accent,
		size = 48,
		position = UDim2.fromOffset(18, 18),
		spin = false,
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.86, 0, 0, 64),
		Position = UDim2.new(0.07, 0, 0, 124),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Text, {
		value = statusLabel,
		size = 12,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Text, {
		value = detail,
		size = 12,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		fit = false,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, 20),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	}), React.createElement(Meter, {
		value = progress,
		color = accent,
		reducedMotion = reducedMotion,
		position = UDim2.fromOffset(0, 46),
		size = UDim2.new(1, 0, 0, 6),
	})))
end
local function ChapterRailRow(_param)
	local chapter = _param.chapter
	local entry = _param.entry
	local selected = _param.selected
	local onSelect = _param.onSelect
	local layoutOrder = _param.layoutOrder
	local open = chapter.Unlocked
	local done = chapter.Claimed or chapter.Read
	local label = if not open then "LOCK" elseif done then "DONE" else "NEW"
	local accent = entry.Color
	return React.createElement("textbutton", {
		Size = UDim2.new(1, -4, 0, 58),
		BackgroundColor3 = if selected then Palette.panel else Palette.ink,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = true,
		Selectable = true,
		LayoutOrder = layoutOrder,
		Event = {
			Activated = function()
				if open then
					onSelect()
					Audio:play("storyPage")
				else
					Audio:play("locked")
				end
			end,
			MouseEnter = function()
				return Audio:play("hover")
			end,
			SelectionGained = function()
				return Audio:play("hover")
			end,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		Color = if selected then accent else Palette.lineSoft,
		Thickness = 1,
		Transparency = if selected then 0.15 else 0.55,
	}), React.createElement("frame", {
		Size = UDim2.new(0, 3, 1, -12),
		Position = UDim2.fromOffset(0, 6),
		BackgroundColor3 = if open then accent else Palette.muted,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 2),
	})), React.createElement(Text, {
		value = entry.Chapter,
		size = 10,
		color = if open then accent else Palette.muted,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(12, 8),
		sizeConstraint = UDim2.new(1, -84, 0, 14),
	}), React.createElement(Text, {
		value = entry.Title,
		size = 13,
		color = if open then Palette.cream else Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(12, 24),
		sizeConstraint = UDim2.new(1, -84, 0, 18),
	}), not open and React.createElement(Text, {
		value = `{math.floor(chapter.Progress)} / {chapter.Target}`,
		size = 10,
		color = Palette.muted,
		fit = false,
		position = UDim2.fromOffset(12, 42),
		sizeConstraint = UDim2.new(1, -84, 0, 12),
	}), React.createElement(Badge, {
		value = label,
		accent = if open then (if done then Palette.mint else accent) else Palette.muted,
		filled = open,
		position = UDim2.new(1, -70, 0.5, -11),
		size = UDim2.fromOffset(62, 22),
	}))
end
local function StoryBeat(_param)
	local text = _param.text
	local index = _param.index
	local total = _param.total
	local color = _param.color
	local reducedMotion = _param.reducedMotion
	local claimed = _param.claimed
	local reward = _param.reward
	local replay = _param.replay
	local onBack = _param.onBack
	local onNext = _param.onNext
	local onClaim = _param.onClaim
	local onClose = _param.onClose
	local onResonate = _param.onResonate
	local stack = _param.stack
	local condensed = _param.condensed
	local enter = useEntrance(reducedMotion)
	local visible, setVisible = React.useBinding(if reducedMotion then #text else 0)
	local needsWarmup = not stack and not replay
	local tuning, setTuning = React.useState(if needsWarmup then 0 else 3)
	local tuneSpring = useFlipperSpring(tuning / 3, reducedMotion, 700, 32)
	local tuned = tuning >= 3 or replay or stack
	React.useEffect(function()
		local alive = true
		local revealWorker
		setVisible(if reducedMotion then #text else 0)
		setTuning(if needsWarmup then 0 else 3)
		Audio:play("storyBeat")
		if not reducedMotion then
			revealWorker = task.spawn(function()
				local count = 0
				local step = math.max(1, math.floor(#text / 72))
				while alive and count < #text do
					count = math.min(#text, count + step)
					setVisible(count)
					task.wait(0.022)
				end
			end)
		end
		return function()
			alive = false
			if revealWorker ~= nil then
				task.cancel(revealWorker)
			end
		end
	end, { index, needsWarmup, reducedMotion, replay, text })
	local final = index >= total - 1
	local resonate = function()
		if tuned then
			return nil
		end
		Audio:play("reactor")
		setTuning(function(current)
			return math.min(3, current + 1)
		end)
		onResonate()
	end
	local action = if not tuned then resonate elseif final then if claimed then onClose else onClaim else onNext
	local actionText = if not tuned then `Warm up  {tuning} / 3` elseif final then if claimed then "Done" else "Collect reward" else "Continue"
	local actionIcon = if not tuned then "Anomaly" elseif final then if claimed then "Check" else "Gift" else "Chevron"
	local tipText = if replay then "Replay — browse freely" elseif tuned then `Part {index + 1} of {total}` else "Tap Warm up three times to continue"
	local decorated = illuminate(text, color)
	local btnH = if stack then TapTarget else 48
	local showTip = not condensed and (not stack or not tuned)
	local tipH = if showTip then (if stack then 36 else 32) else 0
	local tipGap = if showTip then (if stack then 8 else Layout.stackGap) else 0
	local actionsH = if stack and not condensed then btnH * 2 + 10 else btnH
	local bottomReserve = tipH + tipGap + actionsH + 6
	local headerH = if stack then 28 else 40
	local bodySize = if stack then 17 else 20
	local lineHeight = if stack then 1.36 else 1.42
	local partFill = meterFill(index + 1, total)
	local tipAccent = if tuned then Palette.green else color
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, not stack and React.createElement(React.Fragment, nil, React.createElement(Text, {
		value = `Part {index + 1} of {total}`,
		size = 13,
		color = color,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 20),
		transparency = enter:map(function(amount)
			return 1 - amount
		end),
	}), React.createElement(Meter, {
		value = partFill,
		color = color,
		reducedMotion = reducedMotion,
		shimmer = final,
		position = UDim2.fromOffset(0, 26),
		size = UDim2.new(1, 0, 0, 5),
	})), stack and React.createElement(Meter, {
		value = partFill,
		color = color,
		reducedMotion = reducedMotion,
		shimmer = final,
		position = UDim2.fromOffset(0, 4),
		size = UDim2.new(1, 0, 0, 4),
	}), React.createElement("scrollingframe", {
		Size = UDim2.new(1, 0, 1, -(bottomReserve + headerH)),
		Position = UDim2.fromOffset(0, headerH),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = if stack then 4 else 3,
		ScrollBarImageColor3 = color,
		ScrollBarImageTransparency = 0.28,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ClipsDescendants = true,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		Active = true,
		Selectable = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, if stack then 16 else Layout.panelGap),
	}), React.createElement("uipadding", {
		PaddingRight = UDim.new(0, if stack then 4 else Layout.stackGap),
		PaddingBottom = UDim.new(0, 12),
	}), React.createElement("textlabel", {
		Size = UDim2.new(1, -4, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = decorated,
		RichText = true,
		TextColor3 = Palette.cream,
		TextSize = bodySize,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = lineHeight,
		MaxVisibleGraphemes = visible,
		TextTransparency = enter:map(function(amount)
			return 1 - amount
		end),
		TextScaled = false,
		TextTruncate = Enum.TextTruncate.None,
		LayoutOrder = 0,
	}), final and React.createElement("frame", {
		Size = UDim2.new(1, -4, 0, 56),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		Color = color,
		Thickness = 1,
		Transparency = 0.35,
	}), React.createElement("frame", {
		Size = UDim2.new(0, 3, 1, -12),
		Position = UDim2.fromOffset(0, 6),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 2),
	})), React.createElement(Text, {
		value = if claimed then "REWARD CLAIMED" else "REWARD",
		size = 11,
		color = color,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(16, 8),
		sizeConstraint = UDim2.new(1, -28, 0, 16),
	}), React.createElement(Text, {
		value = reward,
		size = 15,
		color = Palette.cream,
		weight = Enum.FontWeight.Bold,
		wrap = true,
		fit = false,
		position = UDim2.fromOffset(16, 26),
		sizeConstraint = UDim2.new(1, -28, 0, 24),
	})), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, if stack then 24 else 16),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 2,
	})), showTip and stack and React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, tipH),
		Position = UDim2.new(0, 0, 1, -(actionsH + tipGap + tipH)),
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 3,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		Color = tipAccent,
		Thickness = 1,
		Transparency = 0.45,
	}), React.createElement(Text, {
		value = tipText,
		size = 12,
		color = if tuned then Palette.green else Palette.cream,
		weight = Enum.FontWeight.Bold,
		wrap = true,
		fit = false,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.fromScale(1, 1),
	})), showTip and not stack and React.createElement("frame", {
		Size = UDim2.fromOffset(0, tipH),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(0, 0, 1, -(actionsH + tipGap + tipH)),
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 3,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement("uistroke", {
		Color = tipAccent,
		Thickness = 1,
		Transparency = 0.4,
	}), React.createElement("uipadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}), not tuned and React.createElement("frame", {
		Size = tuneSpring:map(function(amount)
			return UDim2.new(amount, 0, 1, 0)
		end),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	})), React.createElement("textlabel", {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = tipText,
		TextColor3 = if tuned then Palette.green else Palette.cream,
		TextSize = 12,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		ZIndex = 4,
	})), if stack and not condensed then React.createElement(React.Fragment, nil, React.createElement(Button, {
		text = actionText,
		icon = actionIcon,
		onClick = action,
		color = if not tuned then color elseif final then color else Palette.mint,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, btnH),
		position = UDim2.new(0, 0, 1, -(btnH * 2 + 10)),
		reducedMotion = reducedMotion,
		highlight = not claimed or not tuned or replay,
	}), React.createElement(Button, {
		text = "Back",
		icon = "Back",
		onClick = onBack,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.new(1, 0, 0, btnH),
		position = UDim2.new(0, 0, 1, -btnH),
		disabled = index <= 0,
		reducedMotion = reducedMotion,
	})) else React.createElement(React.Fragment, nil, React.createElement(Button, {
		text = "Back",
		icon = "Back",
		onClick = onBack,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromOffset(128, btnH),
		position = UDim2.new(0, 0, 1, -btnH),
		disabled = index <= 0,
		reducedMotion = reducedMotion,
	}), React.createElement(Button, {
		text = actionText,
		icon = actionIcon,
		onClick = action,
		color = if not tuned then color elseif final then color else Palette.mint,
		textColor = Palette.ink,
		size = UDim2.new(1, -140, 0, btnH),
		position = UDim2.new(0, 140, 1, -btnH),
		reducedMotion = reducedMotion,
		highlight = not claimed or not tuned or replay,
	})))
end
local function chapterConfig(config, id)
	local _exp = config.Story
	-- ▼ ReadonlyArray.find ▼
	local _callback = function(entry)
		return entry.Id == id
	end
	local _result
	for _i, _v in _exp do
		if _callback(_v, _i - 1, _exp) == true then
			_result = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	return _result
end
local function pickDefaultChapter(chapters)
	for _, chapter in chapters do
		if chapter.Unlocked and not chapter.Claimed then
			return chapter.Id
		end
	end
	for _, chapter in chapters do
		if chapter.Unlocked then
			return chapter.Id
		end
	end
	local _result = chapters[1]
	if _result ~= nil then
		_result = _result.Id
	end
	return _result
end
local function StoryView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local shortLandscape = chrome.landscape and viewport.height < 500
	local chapters = state.Story or {}
	local selectedId, setSelectedId = React.useState(function()
		return pickDefaultChapter(chapters)
	end)
	local started, setStarted = React.useState(false)
	local beat, setBeat = React.useState(0)
	React.useEffect(function()
		Audio:play("storyOpen")
		ClientLog:debug("nav", "story opened")
	end, {})
	React.useEffect(function()
		local _condition = selectedId == nil
		if not _condition then
			-- ▼ ReadonlyArray.find ▼
			local _callback = function(chapter)
				return chapter.Id == selectedId
			end
			local _result
			for _i, _v in chapters do
				if _callback(_v, _i - 1, chapters) == true then
					_result = _v
					break
				end
			end
			-- ▲ ReadonlyArray.find ▲
			_condition = not _result
		end
		if _condition then
			setSelectedId(pickDefaultChapter(chapters))
			setStarted(false)
			setBeat(0)
		end
	end, { chapters, selectedId })
	React.useEffect(function()
		if not started or selectedId == nil then
			return nil
		end
		ClientLog:debug("story", `{selectedId} beat {beat + 1}`)
	end, { beat, selectedId, started })
	-- ▼ ReadonlyArray.find ▼
	local _callback = function(chapter)
		return chapter.Id == selectedId
	end
	local _result
	for _i, _v in chapters do
		if _callback(_v, _i - 1, chapters) == true then
			_result = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local status = _result
	local story = if status then chapterConfig(config, status.Id) else nil
	local intro = useEntrance(reducedMotion)
	local archivePulse = usePulse(not reducedMotion and not started, 3.4)
	if not story or not status then
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		})
	end
	local finished = status.Read == true or status.Claimed == true
	local locked = not status.Unlocked
	local unlockFill = meterFill(status.Progress, math.max(1, status.Target), status.Unlocked)
	local unlockLabel = if locked then `{math.floor(status.Progress)} / {status.Target}` else story.Chapter
	local begin = function()
		if locked then
			return nil
		end
		setBeat(0)
		setStarted(true)
		Audio:play("storyOpen")
		if not status.Read then
			dispatch("ReadStoryChapter", {
				Id = story.Id,
			})
		end
	end
	local closeReplay = function()
		Audio:play("close")
		setStarted(false)
		setBeat(0)
	end
	local selectChapter = function(id)
		Audio:play("page")
		setSelectedId(id)
		setStarted(false)
		setBeat(0)
	end
	local advance = function()
		Audio:play("storyReveal")
		setBeat(math.min(#story.Body - 1, beat + 1))
	end
	local rewind = function()
		Audio:play("close")
		setBeat(math.max(0, beat - 1))
	end
	local readingMobile = stack and started
	-- On a landscape phone the 68px archive mark costs more than half the entire page height;
	-- drop it there and give the chapter selector the full frame (same call as reading mode).
	local markH = if readingMobile then 0 else (if stack then (if chrome.landscape then 0 else 68) else 76)
	local railGap = 14
	local railShare = 0.26
	local chapterCount = #chapters
	local unlockedCount = 0
	local claimedCount = 0
	for _, chapter in chapters do
		if chapter.Unlocked then
			unlockedCount += 1
		end
		if chapter.Claimed then
			claimedCount += 1
		end
	end
	local multi = chapterCount > 1
	local railMarkH = if multi and not stack then (if shortLandscape then 76 else 180) else (if stack then markH else 0)
	local readerPad = if shortLandscape then 12 elseif stack then (if started then 12 else 14) else Layout.contentInset
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	})
	local _exp_1 = React.createElement("uistroke", {
		Color = story.Color,
		Thickness = 1,
		Transparency = 0.52,
	})
	local _condition = not reducedMotion
	if _condition then
		local _exp_2 = { 0, 1, 2 }
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#_exp_2)
		local _callback_1 = function(index)
			return React.createElement("frame", {
				key = `archive-orbit-{index}`,
				Size = archivePulse:map(function(amount)
					return UDim2.fromOffset(260 + index * 82 + amount * 16, 260 + index * 82 + amount * 16)
				end),
				Position = UDim2.new(1, 50 - index * 32, 0, -70 + index * 28),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Rotation = index * 17,
				ZIndex = 0,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(1, 0),
			}), React.createElement("uistroke", {
				Color = if index == 1 then Palette.cyan else story.Color,
				Thickness = 1,
				Transparency = 0.9 + index * 0.02,
			}))
		end
		for _k, _v in _exp_2 do
			_newValue[_k] = _callback_1(_v, _k - 1, _exp_2)
		end
		-- ▲ ReadonlyArray.map ▲
		_condition = _newValue
	end
	local _condition_1 = not readingMobile and markH > 0
	if _condition_1 then
		local _exp_2 = (stack or multi) and React.createElement("frame", {
			Size = if stack then UDim2.fromScale(1, 1) else UDim2.new(1, 0, 0, railMarkH),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement(ArchiveMark, {
			accent = story.Color,
			active = started,
			reducedMotion = reducedMotion,
			beat = beat,
			total = #story.Body,
			compact = stack or multi,
			finished = finished,
			unlocked = status.Unlocked,
			unlockProgress = unlockFill,
			unlockLabel = unlockLabel,
		}))
		local _condition_2 = not stack and multi
		if _condition_2 then
			local _exp_3 = React.createElement("uilistlayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			})
			local _exp_4 = React.createElement(Text, {
				value = "CHAPTERS",
				size = 10,
				color = Palette.muted,
				weight = Enum.FontWeight.Heavy,
				fit = false,
				sizeConstraint = UDim2.new(1, 0, 0, 16),
			})
			-- ▼ ReadonlyArray.map ▼
			local _newValue = table.create(#chapters)
			local _callback_1 = function(chapter, index)
				local entry = chapterConfig(config, chapter.Id)
				if not entry then
					return nil
				end
				return React.createElement(ChapterRailRow, {
					key = chapter.Id,
					chapter = chapter,
					entry = entry,
					selected = chapter.Id == status.Id,
					onSelect = function()
						return selectChapter(chapter.Id)
					end,
					layoutOrder = index + 1,
				})
			end
			for _k, _v in chapters do
				_newValue[_k] = _callback_1(_v, _k - 1, chapters)
			end
			-- ▲ ReadonlyArray.map ▲
			_condition_2 = React.createElement("scrollingframe", {
				Size = UDim2.new(1, 0, 1, -(railMarkH + 10)),
				Position = UDim2.fromOffset(0, railMarkH + 10),
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarThickness = 3,
				ScrollBarImageColor3 = story.Color,
				ScrollBarImageTransparency = 0.28,
				VerticalScrollBarInset = Enum.ScrollBarInset.None,
				ClipsDescendants = true,
				ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
				Active = true,
				Selectable = false,
			}, _exp_3, _exp_4, _newValue, React.createElement("frame", {
				Size = UDim2.new(1, 0, 0, 8),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = 99,
			}))
		end
		_condition_1 = React.createElement("frame", {
			Size = if stack then UDim2.new(1, 0, 0, markH) else UDim2.new(railShare, -railGap / 2, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, _exp_2, _condition_2, not stack and not multi and React.createElement(ArchiveMark, {
			accent = story.Color,
			active = started,
			reducedMotion = reducedMotion,
			beat = beat,
			total = #story.Body,
			compact = false,
			finished = finished,
			unlocked = status.Unlocked,
			unlockProgress = unlockFill,
			unlockLabel = unlockLabel,
		}))
	end
	local _exp_2 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	})
	local _exp_3 = React.createElement("uistroke", {
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.6,
	})
	local _exp_4 = not stack and React.createElement("frame", {
		Size = UDim2.new(0, 2, 1, -32),
		Position = UDim2.fromOffset(0, 16),
		BackgroundColor3 = story.Color,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 2),
	}))
	local _condition_2 = not started and multi and stack
	if _condition_2 then
		local _attributes = {
			inset = 16,
			gap = 8,
			tailPad = 4,
			scrollBarColor = story.Color,
		}
		local _exp_5 = {
			id = "archive-head",
			height = 26,
			element = React.createElement("frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, React.createElement(Badge, {
				value = "STORY",
				accent = story.Color,
				filled = true,
				position = UDim2.fromOffset(0, 2),
				size = UDim2.fromOffset(88, 24),
			}), React.createElement(Text, {
				value = `{claimedCount}/{chapterCount} archived  ·  {unlockedCount} open`,
				size = 13,
				color = story.Color,
				weight = Enum.FontWeight.Heavy,
				fit = false,
				align = Enum.TextXAlignment.Right,
				position = UDim2.new(0, 100, 0, 4),
				sizeConstraint = UDim2.new(1, -100, 0, 20),
			})),
		}
		local _exp_6 = {
			id = "archive-title",
			height = 32,
			element = React.createElement(Text, {
				value = "Bay Seven",
				size = 22,
				color = Palette.cream,
				weight = Enum.FontWeight.Heavy,
				wrap = true,
				sizeConstraint = UDim2.new(1, 0, 0, 32),
			}),
		}
		local _object = {
			id = "archive-chapters",
			fill = true,
			minHeight = 140,
		}
		local _left = "element"
		local _exp_7 = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		})
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#chapters)
		local _callback_1 = function(chapter, index)
			local entry = chapterConfig(config, chapter.Id)
			if not entry then
				return nil
			end
			return React.createElement(ChapterRailRow, {
				key = chapter.Id,
				chapter = chapter,
				entry = entry,
				selected = chapter.Id == status.Id,
				onSelect = function()
					return selectChapter(chapter.Id)
				end,
				layoutOrder = index,
			})
		end
		for _k, _v in chapters do
			_newValue[_k] = _callback_1(_v, _k - 1, chapters)
		end
		-- ▲ ReadonlyArray.map ▲
		_object[_left] = React.createElement("scrollingframe", {
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = story.Color,
			ScrollBarImageTransparency = 0.28,
			VerticalScrollBarInset = Enum.ScrollBarInset.None,
			ClipsDescendants = true,
			ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
			Active = true,
			Selectable = false,
		}, _exp_7, _newValue, React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 8),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 99,
		}))
		_attributes.sections = { _exp_5, _exp_6, _object, {
			id = "archive-read",
			height = TapTarget,
			element = React.createElement(Button, {
				text = if locked then "Locked" elseif finished then "Open selected" else "Read selected",
				icon = "Story",
				onClick = begin,
				color = if locked then Palette.panelSoft else story.Color,
				textColor = if locked then Palette.muted else Palette.ink,
				size = UDim2.fromScale(1, 1),
				disabled = locked,
				reducedMotion = reducedMotion,
				highlight = not locked,
			}),
		} }
		_condition_2 = React.createElement(PageScaffold, _attributes)
	end
	local _exp_5 = not started and (not multi or not stack) and React.createElement("frame", {
		Size = UDim2.new(1, -(readerPad * 2), 1, if shortLandscape then -16 else -36),
		Position = intro:map(function(amount)
			return UDim2.new(0, readerPad + math.floor((1 - amount) * 12), 0, if shortLandscape then 8 else 18)
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Badge, {
		value = if multi then "CHAPTER" else "STORY",
		accent = story.Color,
		filled = true,
		position = UDim2.fromOffset(0, 2),
		size = UDim2.fromOffset(110, 26),
	}), React.createElement(Text, {
		value = story.Chapter,
		size = 13,
		color = story.Color,
		weight = Enum.FontWeight.Heavy,
		wrap = true,
		fit = false,
		align = Enum.TextXAlignment.Right,
		position = UDim2.new(0, 120, 0, 4),
		sizeConstraint = UDim2.new(1, -120, 0, 20),
	})), React.createElement(Text, {
		value = story.Title,
		size = if shortLandscape then 22 elseif stack then 22 else 34,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		wrap = true,
		position = UDim2.fromOffset(0, if shortLandscape then 34 else 40),
		sizeConstraint = UDim2.new(1, if shortLandscape then -224 else 0, 0, if shortLandscape then 34 elseif stack then 64 else 78),
	}), not shortLandscape and React.createElement(Text, {
		value = story.Summary,
		size = if stack then 14 else 16,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, if stack then 112 else 128),
		sizeConstraint = UDim2.new(1, 0, 0, if stack then 96 else 80),
	}), not shortLandscape and React.createElement(Text, {
		value = if finished then "Finished — open anytime to re-read." elseif locked then "Keep playing to unlock this chapter." elseif multi then "Pick a chapter, then start reading." else "Short chapters from under Bay Seven.",
		size = 13,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(0, if stack then 220 else 224),
		sizeConstraint = UDim2.new(1, 0, 0, 40),
	}), React.createElement(Button, {
		text = if locked then "Locked" elseif finished then "Replay" else "Start reading",
		icon = "Story",
		onClick = begin,
		color = if locked then Palette.panelSoft else story.Color,
		textColor = if locked then Palette.muted else Palette.ink,
		size = if shortLandscape then UDim2.fromOffset(210, TapTarget) elseif stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.new(0.5, 0, 0, 52),
		position = if shortLandscape then UDim2.new(1, -210, 1, -TapTarget) else UDim2.new(0, 0, 1, -(if stack then TapTarget + 4 else 56)),
		disabled = locked,
		reducedMotion = reducedMotion,
		highlight = not locked,
	}))
	local _condition_3 = started
	if _condition_3 then
		local _attributes = {
			key = `{story.Id}:{beat}:{if finished then "replay" else "live"}`,
		}
		local _condition_4 = story.Body[beat + 1]
		if _condition_4 == nil then
			_condition_4 = ""
		end
		_attributes.text = _condition_4
		_attributes.index = beat
		_attributes.total = #story.Body
		_attributes.color = story.Color
		_attributes.reducedMotion = reducedMotion
		_attributes.claimed = status.Claimed
		_attributes.reward = formatReward(story.Reward)
		_attributes.replay = finished
		_attributes.onBack = rewind
		_attributes.onNext = advance
		_attributes.onClaim = function()
			ClientLog:debug("story", `claim {story.Id}`)
			dispatch("ClaimStoryChapter", {
				Id = story.Id,
			})
		end
		_attributes.onClose = closeReplay
		_attributes.onResonate = function()
			return nil
		end
		_attributes.stack = stack
		_attributes.condensed = viewport.height < 620 or viewport.keyboardOpen or chrome.landscape
		_condition_3 = React.createElement("frame", {
			Size = UDim2.new(1, -(readerPad * 2), 1, -(if stack then 20 else 32)),
			Position = UDim2.fromOffset(readerPad, if stack then 10 else 16),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, React.createElement(StoryBeat, _attributes))
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, _exp, _exp_1, _condition, _condition_1, React.createElement("frame", {
		Size = if readingMobile then UDim2.fromScale(1, 1) else (if stack then UDim2.new(1, 0, 1, -(markH + 6)) else UDim2.new(1 - railShare, -railGap / 2, 1, 0)),
		Position = if readingMobile then UDim2.fromOffset(0, 0) else (if stack then UDim2.fromOffset(0, markH + 6) else UDim2.new(railShare, railGap / 2, 0, 0)),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, _exp_2, _exp_3, _exp_4, _condition_2, _exp_5, _condition_3))
end
return {
	StoryView = StoryView,
}

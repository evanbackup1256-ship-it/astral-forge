--!nonstrict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("PagesStory: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("PagesStory: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

__defs["StoryView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local formatReward = require(script.Parent.Parent.CoreKit)("format").formatReward
local Icon = require(script.Parent.Parent.ArtKit)("Icon").Icon
local ClientLog = require(script.Parent.Parent.CoreKit)("log").ClientLog
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local FlatList = require(script.Parent.Parent.LayoutKit)("virtualizedList").FlatList
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useEntrance = _motion.useEntrance
local useFlipperSpring = _motion.useFlipperSpring
local usePulse = _motion.usePulse
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local darken = _theme.darken
local Layout = _theme.Layout
local TapTarget = _theme.TapTarget
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local Meter = _ui.Meter
local meterFill = _ui.meterFill
local measureWrappedTextHeight = _ui.measureWrappedTextHeight
local Text = _ui.Text
local SearchField = _ui.SearchField
local Browse = require(script.Parent.Parent.BrowseKit)
local CHAPTER_ROW_H = 58
local CHAPTER_ROW_GAP = 8
local CHAPTER_ROW_STRIDE = CHAPTER_ROW_H + CHAPTER_ROW_GAP
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
	local statusLabel = if not active and finished then "REPLAY" elseif active then "OPEN" elseif unlocked then "READY" else "LOCKED"
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
			kind = "Story.2",
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
		kind = "Story.3",
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
		Size = UDim2.new(1, -4, 0, CHAPTER_ROW_H),
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
	local stack = _param.stack
	local condensed = _param.condensed
	local softMotion = reducedMotion
	local enter = useEntrance(reducedMotion)
	local visible, setVisible = React.useBinding(0)
	local tuned = true
	React.useEffect(function()
		local alive = true
		local revealWorker
		setVisible(0)
		Audio:play("storyBeat")
		local stepDiv = if reducedMotion then 28 else 72
		local stepWait = if reducedMotion then 0.012 else 0.022
		revealWorker = task.spawn(function()
			local count = 0
			local step = math.max(1, math.floor(#text / stepDiv))
			while alive and count < #text do
				count = math.min(#text, count + step)
				if not alive then
					break
				end
				setVisible(count)
				task.wait(stepWait)
			end
		end)
		return function()
			alive = false
			if revealWorker ~= nil then
				pcall(function()
					task.cancel(revealWorker)
				end)
			end
		end
	end, { index, reducedMotion, replay, text })
	local final = index >= total - 1
	local action = if final then if claimed then onClose else onClaim else onNext
	local actionText = if final then if claimed then "Done" else "Collect reward" else "Continue"
	local actionIcon = if final then if claimed then "Check" else "Gift" else "Chevron"
	local tipText = if replay then "Replay: read any part" else `Part {index + 1} of {total}`
	local decorated = illuminate(text, color)
	local btnH = if stack then TapTarget else 48
	local showTip = not condensed and (not stack or not tuned)
	local tipH = if showTip then (if stack then 36 else 32) else 0
	local actionsH = if stack and not condensed then btnH * 2 + 10 else btnH
	local headerH = if stack then 28 else 40
	local bodySize = if stack then 17 else 20
	local lineHeight = if stack then 1.36 else 1.42
	local partFill = meterFill(index + 1, total)
	local tipAccent = if tuned then Palette.green else color
	local bodyGap = if stack then 16 else Layout.panelGap
	local bodyPadR = if stack then 4 else Layout.stackGap
	local viewport = useViewport()
	local storyActionsHostRef = React.useRef(nil)
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = storyActionsHostRef.current
		if host == nil then
			return nil
		end
		local selectJob = task.defer(function()
			if host.Parent == nil then
				return
			end
			GamepadNavigationService.FocusClaim(host)
		end)
		return function()
			pcall(task.cancel, selectJob)
		end
	end, { index, tuned, claimed, actionText })
	local measureWidth = math.max(160, math.floor((viewport.width or 390) * (if stack then 0.92 else 0.55)) - bodyPadR - 12)
	local textH = math.max(64, math.ceil(measureWrappedTextHeight(text, measureWidth, bodySize, Enum.FontWeight.Medium) * lineHeight) + 8)
	local estimatedBodyH = textH + (if final then 56 + bodyGap else 0) + (if stack then 24 else 16) + 12
	local headerElement = if stack then React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Meter, {
		value = partFill,
		color = color,
		reducedMotion = reducedMotion,
		shimmer = final,
		position = UDim2.fromOffset(0, 4),
		size = UDim2.new(1, 0, 0, 4),
	})) else React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Text, {
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
	}))
	local bodyElement = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, bodyGap),
	}), React.createElement("uipadding", {
		PaddingRight = UDim.new(0, bodyPadR),
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
	}))
	local tipElement = if not showTip then nil elseif stack then React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
		ClipsDescendants = false,
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
	})) else React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(0, tipH),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement("uistroke", {
		Color = tipAccent,
		Thickness = 1,
		Transparency = 0.4,
	}), React.createElement("uipadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}), React.createElement("textlabel", {
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
	})))
	local continueSlot = React.createElement("frame", {
		Name = if final and not claimed then "StoryClaim" else "StoryContinue",
		Size = if stack and not condensed then UDim2.new(1, 0, 0, btnH) else UDim2.new(1, -140, 0, btnH),
		Position = if stack and not condensed then nil else UDim2.fromOffset(140, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 0,
	}, React.createElement(Button, {
		text = actionText,
		icon = actionIcon,
		onClick = action,
		color = if not tuned then color elseif final then color else Palette.mint,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		highlight = not claimed or not tuned or replay,
	}))
	local backSlot = React.createElement("frame", {
		Name = "StoryBack",
		Size = if stack and not condensed then UDim2.new(1, 0, 0, btnH) else UDim2.fromOffset(128, btnH),
		Position = if stack and not condensed then nil else UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 1,
	}, React.createElement(Button, {
		text = "Back",
		icon = "Back.2",
		onClick = onBack,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		outline = true,
		size = UDim2.fromScale(1, 1),
		disabled = index <= 0,
		reducedMotion = reducedMotion,
	}))
	local actionsElement = if stack and not condensed then React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	}), continueSlot, backSlot) else React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, backSlot, continueSlot)
	local sections = {
		{
			id = "beat-header",
			height = headerH,
			element = headerElement,
		},
		{
			id = "beat-body",
			fill = true,
			minHeight = 72,
			height = estimatedBodyH,
			element = bodyElement,
		},
	}
	if showTip and tipElement ~= nil then
		table.insert(sections, {
			id = "beat-tip",
			height = tipH,
			element = tipElement,
		})
	end
	local actionsGap = 8
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, -(actionsH + actionsGap)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement(PageScaffold, {
		gap = if showTip then (if stack then 8 else Layout.stackGap) else 6,
		tailPad = 4,
		scrollBarColor = color,
		scrollBarThickness = if stack then 4 else 3,
		sections = sections,
	})), React.createElement("frame", {
		ref = storyActionsHostRef,
		Name = "StoryBeatActions",
		Size = UDim2.new(1, 0, 0, actionsH),
		Position = UDim2.new(0, 0, 1, -actionsH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 6,
	}, actionsElement))
end

local function chapterConfig(config, id)
	local _exp = config.Story
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
	local status = _result
	local story = if status then chapterConfig(config, status.Id) else nil
	local antilag = useAntilag()
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local intro = useEntrance(softMotion)
	local archivePulse = usePulse(not softMotion and not started, 3.4)
	local archiveReveal = useStagger(0, softMotion)
	local archiveMotionEnabled = softMotion
	local chapterBrowse = Browse.useBrowse({
		id = "Story",
		items = chapters,
		text = function(chapter)
			local entry = chapterConfig(config, chapter.Id)
			return { if entry then entry.Title else chapter.Id, if entry then entry.Chapter else nil, if entry then entry.Summary else nil }
		end,
		categories = {
			{ id = "All", label = "All" },
			{ id = "New", label = "New", test = function(chapter)
				return chapter.Unlocked == true and chapter.Read ~= true
			end },
			{ id = "Reward", label = "Reward", test = function(chapter)
				return chapter.Unlocked == true and chapter.Claimed ~= true and chapter.Read == true
			end },
			{ id = "Read", label = "Read", test = function(chapter)
				return chapter.Read == true
			end },
			{ id = "Locked", label = "Locked", test = function(chapter)
				return chapter.Unlocked ~= true
			end },
		},
	})
	-- a deep link from Quick Find opens the best match directly
	React.useEffect(function()
		if chapterBrowse.searching and chapterBrowse.relevance and chapterBrowse.results[1] ~= nil then
			local top = chapterBrowse.results[1]
			if top.Id ~= selectedId then
				setSelectedId(top.Id)
				setStarted(false)
				setBeat(0)
			end
		end
	end, { chapterBrowse.query })
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
	local railMarkH = if multi and not stack then 84 else (if stack then markH else 0) -- the mark is ~76px of content; taller only left an empty card
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
			reducedMotion = softMotion,
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
			local railChapters = {}
			for _, chapter in chapterBrowse.results do
				local entry = chapterConfig(config, chapter.Id)
				if entry ~= nil then
					table.insert(railChapters, {
						chapter = chapter,
						entry = entry,
					})
				end
			end
			local railListTop = railMarkH + 10
			local railHeaderH = 20 + TapTarget + 8 + Browse.CHIP_H + 8
			_condition_2 = React.createElement("frame", {
				Size = UDim2.new(1, 0, 1, -railListTop),
				Position = UDim2.fromOffset(0, railListTop),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, React.createElement(Text, {
				value = "CHAPTERS",
				size = 10,
				color = Palette.muted,
				weight = Enum.FontWeight.Heavy,
				fit = false,
				sizeConstraint = UDim2.new(1, 0, 0, 16),
				transparency = archiveReveal:map(function(amount)
					return 1 - amount
				end),
			}), React.createElement(SearchField, {
				value = chapterBrowse.query,
				onChange = chapterBrowse.setQuery,
				placeholder = "Search chapters",
				accent = story.Color,
				reducedMotion = softMotion,
				position = UDim2.fromOffset(0, 20),
				size = UDim2.new(1, -4, 0, TapTarget),
				zIndex = 12,
			}), React.createElement(Browse.ChipRow, {
				options = chapterBrowse.categories,
				value = chapterBrowse.category,
				onChange = chapterBrowse.setCategory,
				counts = chapterBrowse.counts,
				accent = story.Color,
				position = UDim2.fromOffset(0, 20 + TapTarget + 8),
				size = UDim2.new(1, -4, 0, Browse.CHIP_H),
			}), #railChapters == 0 and React.createElement(Text, {
				value = "No chapters match.",
				size = 13,
				color = Palette.muted,
				position = UDim2.fromOffset(0, railHeaderH + 8),
				sizeConstraint = UDim2.new(1, 0, 0, 20),
			}), React.createElement(FlatList, {
				data = railChapters,
				itemHeight = CHAPTER_ROW_STRIDE,
				headerHeight = 0,
				overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
				canvasTail = 8,
				Size = UDim2.new(1, 0, 1, -railHeaderH),
				Position = UDim2.fromOffset(0, railHeaderH),
				scrollBarColor = story.Color,
				scrollBarThickness = 3,
				keyExtractor = function(item)
					return item.chapter.Id
				end,
				renderItem = function(_param_1)
					local item = _param_1.item
					local index = _param_1.index
					return React.createElement(ChapterRailRow, {
						chapter = item.chapter,
						entry = item.entry,
						selected = item.chapter.Id == status.Id,
						onSelect = function()
							return selectChapter(item.chapter.Id)
						end,
						layoutOrder = index,
					})
				end,
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
			reducedMotion = softMotion,
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
		local archiveChapterCount = 0
		for _, chapter in chapterBrowse.results do
			if chapterConfig(config, chapter.Id) ~= nil then
				archiveChapterCount += 1
			end
		end
		local _object = {
			id = "archive-chapters",
			fill = true,
			minHeight = 140,
			height = math.max(140, archiveChapterCount * CHAPTER_ROW_STRIDE + 8),
		}
		local _left = "element"
		local _exp_7 = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		})
		local shownChapters = chapterBrowse.results
		local _newValue = table.create(#shownChapters)
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
		for _k, _v in shownChapters do
			_newValue[_k] = _callback_1(_v, _k - 1, shownChapters)
		end
		_object[_left] = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		}, _exp_7, _newValue, React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 8),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 99,
		}))
		_attributes.sections = { _exp_5, _exp_6, {
			id = "archive-browse",
			height = Browse.barHeight(true, true),
			element = React.createElement(Browse.BrowseBar, {
				browse = chapterBrowse,
				placeholder = "Search chapters",
				accent = story.Color,
				stack = true,
				reducedMotion = softMotion,
				zIndex = 30,
			}),
		}, _object, {
			id = "archive-read",
			height = TapTarget,
			element = React.createElement(Button, {
				text = if locked then "Locked" elseif finished then "Open selected" else "Read selected",
				icon = "Story.4",
				onClick = begin,
				color = if locked then Palette.panelSoft else story.Color,
				textColor = if locked then Palette.muted else Palette.ink,
				size = UDim2.fromScale(1, 1),
				disabled = locked,
				reducedMotion = softMotion,
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
		value = if finished then "Finished. Open it any time to read again." elseif locked then "Keep playing to unlock this chapter." elseif multi then "Pick a chapter, then start reading." else "Short chapters from under Bay Seven.",
		size = 13,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(0, if stack then 220 else 224),
		sizeConstraint = UDim2.new(1, 0, 0, 40),
	}), React.createElement(Button, {
		text = if locked then "Locked" elseif finished then "Replay" else "Start reading",
		icon = "Story.5",
		onClick = begin,
		color = if locked then Palette.panelSoft else story.Color,
		textColor = if locked then Palette.muted else Palette.ink,
		size = if shortLandscape then UDim2.fromOffset(210, TapTarget) elseif stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.new(0.5, 0, 0, 52),
		position = if shortLandscape then UDim2.new(1, -210, 1, -TapTarget) else UDim2.new(0, 0, 1, -(if stack then TapTarget + 4 else 56)),
		disabled = locked,
		reducedMotion = softMotion,
		highlight = not locked,
	}))
	local _condition_3 = started
	if _condition_3 then
		local _attributes = {
			key = `{story.Id}:{beat}:{if finished then "replay" else "live"}`,
		}
		local body = story.Body
		if type(body) ~= "table" then
			body = {}
		end
		local _condition_4 = body[beat + 1]
		if _condition_4 == nil then
			_condition_4 = ""
		end
		_attributes.text = _condition_4
		_attributes.index = beat
		_attributes.total = math.max(1, #body)
		_attributes.color = story.Color
		_attributes.reducedMotion = softMotion
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
end

__defs["EchoForgeView"] = function()
-- The Echoes page: the loom (charge and the four tracks), the strike, the chord, every echo you
-- keep, and the journal. Every rule shown here is EchoMath's, so the numbers match the server.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Icon = require(script.Parent.Parent.ArtKit)("Icon").Icon
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local usePulse = _motion.usePulse
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local compactNumber = require(script.Parent.Parent.CoreKit)("format").compactNumber
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Button = _ui.Button
local Meter = _ui.Meter
local Panel = _ui.Panel
local SectionLabel = _ui.SectionLabel
local Text = _ui.Text
local EchoMath = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("EchoMath"))
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local UserInputService = game:GetService("UserInputService")
local h = React.createElement

local TIER_COLOR = { Faint = Palette.muted, Clear = Palette.cyan, Vivid = Palette.violet, Perfect = Palette.mango }
local TRACK_ART = {
	Collect = { icon = "Collect.echoTrack", color = Palette.mint, label = "Collecting" },
	Surge = { icon = "Overcharge.echoTrack", color = Palette.coral, label = "Overcharging" },
	Build = { icon = "Forge.echoTrack", color = Palette.mango, label = "Building" },
	Explore = { icon = "World.echoTrack", color = Palette.violet, label = "Exploring" },
}
-- each place a trait appears in has its own art for it
local TRAIT_ART = {
	draft = {
		FurnaceMemory = { icon = "Ember.echoDraftFurnace" },
		DeepReservoir = { icon = "Vault.echoDraftReservoir" },
		StrikeGhost = { icon = "Overcharge.echoDraftGhost" },
		LuckyAfterimage = { icon = "Jackpot.echoDraftAfterimage" },
		ClockworkEcho = { icon = "Timer.echoDraftClockwork" },
		LatticeRecall = { icon = "Domain.echoDraftLattice" },
		NightShift = { icon = "Anomaly.echoDraftNight" },
		VoidPulse = { icon = "Continuum.echoDraftVoid" },
	},
	chord = {
		FurnaceMemory = { icon = "Ember.echoChordFurnace" },
		DeepReservoir = { icon = "Vault.echoChordReservoir" },
		StrikeGhost = { icon = "Overcharge.echoChordGhost" },
		LuckyAfterimage = { icon = "Jackpot.echoChordAfterimage" },
		ClockworkEcho = { icon = "Timer.echoChordClockwork" },
		LatticeRecall = { icon = "Domain.echoChordLattice" },
		NightShift = { icon = "Anomaly.echoChordNight" },
		VoidPulse = { icon = "Continuum.echoChordVoid" },
	},
	vault = {
		FurnaceMemory = { icon = "Ember.echoVaultFurnace" },
		DeepReservoir = { icon = "Vault.echoVaultReservoir" },
		StrikeGhost = { icon = "Overcharge.echoVaultGhost" },
		LuckyAfterimage = { icon = "Jackpot.echoVaultAfterimage" },
		ClockworkEcho = { icon = "Timer.echoVaultClockwork" },
		LatticeRecall = { icon = "Domain.echoVaultLattice" },
		NightShift = { icon = "Anomaly.echoVaultNight" },
		VoidPulse = { icon = "Continuum.echoVaultVoid" },
	},
	journal = {
		FurnaceMemory = { icon = "Ember.echoJournalFurnace" },
		DeepReservoir = { icon = "Vault.echoJournalReservoir" },
		StrikeGhost = { icon = "Overcharge.echoJournalGhost" },
		LuckyAfterimage = { icon = "Jackpot.echoJournalAfterimage" },
		ClockworkEcho = { icon = "Timer.echoJournalClockwork" },
		LatticeRecall = { icon = "Domain.echoJournalLattice" },
		NightShift = { icon = "Anomaly.echoJournalNight" },
		VoidPulse = { icon = "Continuum.echoJournalVoid" },
	},
}
local function traitIcon(place, traitId)
	local art = TRAIT_ART[place] and TRAIT_ART[place][traitId]
	return if art then art.icon else nil
end
local KIND_WORDS = {
	Production = "production", Capacity = "vault capacity", Tap = "overcharge power",
	Critical = "critical chance", Automation = "auto-collect", Offline = "offline earnings",
}
local function pct(value)
	local p = value * 100
	return if p >= 10 then string.format("+%d%%", math.floor(p + 0.5)) else string.format("+%.1f%%", p)
end
local function effectLines(effects)
	local lines = {}
	for _, kind in EchoMath.KINDS do
		local v = effects[kind]
		if v and v > 0 then
			table.insert(lines, `{pct(v)} {KIND_WORDS[kind]}`)
		end
	end
	return table.concat(lines, "  ·  ")
end
local function chip(text, color, order)
	return h("textlabel", {
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = order,
		BackgroundColor3 = darken(color, 0.6),
		Text = text,
		TextSize = 12,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		TextColor3 = color,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uipadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }))
end

-- one echo as a card: trait art, name, tier, level, what it does, and what you can do with it
local function EchoCard(props)
	local echo = props.echo
	local trait = EchoMath.trait(echo.Trait)
	local tierColor = TIER_COLOR[echo.Tier] or Palette.cream
	local effects = echo.Effects or EchoMath.effects(echo)
	local reveal = useStagger(props.index or 0, props.reducedMotion)
	return h(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = tierColor,
		background = Palette.panel,
		padding = 12,
		reveal = reveal,
		reducedMotion = props.reducedMotion,
	}, h(Icon, {
		kind = traitIcon(props.place, echo.Trait) or "Wave.echoUnknown",
		size = 44,
		position = UDim2.fromOffset(0, 0),
	}), h(Text, {
		value = trait and trait.Name or echo.Trait,
		size = 15,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(54, 0),
		sizeConstraint = UDim2.new(1, -54, 0, 20),
	}), h(Text, {
		value = `{string.upper(echo.Tier)}  ·  LEVEL {echo.Level}{if echo.Locked then "  ·  LOCKED" else ""}`,
		size = 11,
		color = tierColor,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(54, 22),
		sizeConstraint = UDim2.new(1, -54, 0, 16),
	}), h(Text, {
		value = effectLines(effects),
		size = 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 52),
		sizeConstraint = UDim2.new(1, 0, 0, 34),
	}), #(echo.Imprints or {}) > 0 and h(Text, {
		value = "Imprints: " .. table.concat((function()
			local words = {}
			for _, kind in echo.Imprints do
				table.insert(words, KIND_WORDS[kind] or kind)
			end
			return words
		end)(), ", "),
		size = 11,
		color = Palette.muted,
		position = UDim2.fromOffset(0, 86),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), props.actions and h("frame", {
		Size = UDim2.new(1, 0, 0, props.actionsHeight or TapTarget),
		Position = UDim2.new(0, 0, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
	}, props.actions))
end

local function EchoForgeView(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local echoes = state.ForgeEchoes or {}
	-- a controller lands on Strike the moment the charge is full
	local strikeHost = React.useRef(nil)
	React.useEffect(function()
		if not (echoes.Ready and UserInputService.GamepadEnabled) then
			return nil
		end
		local job = task.defer(function()
			if strikeHost.current ~= nil and strikeHost.current.Parent ~= nil then
				GamepadNavigationService.FocusClaim(strikeHost.current)
			end
		end)
		return function()
			pcall(task.cancel, job)
		end
	end, { echoes.Ready })
	local armed, setArmed = React.useState(nil)
	local slotting, setSlotting = React.useState(nil)
	local readyPulse = usePulse(echoes.Ready == true and not softMotion, 1.6)
	React.useEffect(function()
		if armed == nil then
			return nil
		end
		local lapse = task.delay(4, function()
			setArmed(nil)
		end)
		return function()
			pcall(task.cancel, lapse)
		end
	end, { armed })
	local function act(payload)
		dispatch("EchoAct", payload)
	end
	if echoes.Version ~= 2 then
		return h(Panel, { size = UDim2.new(1, 0, 0, 120), accent = Palette.cyan, padding = 16 }, h(Text, {
			value = "Your echoes are being carried over to the new forge. Give it a moment.",
			size = 14,
			color = Palette.creamSoft,
			wrap = true,
			sizeConstraint = UDim2.fromScale(1, 1),
		}))
	end
	local sections = {}
	local gap = if stack then 10 else 14

	-- the loom: charge, tracks, strike
	local tracks = {}
	local trackTotal = 0
	for _, track in EchoMath.TRACKS do
		trackTotal += echoes.Tracks[track] or 0
	end
	for index, track in EchoMath.TRACKS do
		local art = TRACK_ART[track]
		local share = (echoes.Tracks[track] or 0) / math.max(1, trackTotal)
		tracks["t" .. track] = h("frame", {
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = index,
			BackgroundTransparency = 1,
		}, h(Icon, { kind = art.icon, size = 26, position = UDim2.fromOffset(0, 2) }), h(Text, {
			value = art.label .. (if echoes.Dominant == track and trackTotal > 0 then "  ·  leading" else ""),
			size = 12,
			color = if echoes.Dominant == track and trackTotal > 0 then art.color else Palette.creamSoft,
			weight = Enum.FontWeight.Bold,
			position = UDim2.fromOffset(34, 0),
			sizeConstraint = UDim2.new(0.45, -34, 0, 16),
		}), h(Meter, {
			value = share,
			color = art.color,
			size = UDim2.new(0.55, -10, 0, 6),
			position = UDim2.new(0.45, 10, 0, 12),
		}))
	end
	local charge = echoes.Charge / math.max(1, echoes.ChargeTarget)
	table.insert(sections, {
		id = "loom",
		height = if stack then 300 else 236,
		element = h(Panel, {
			size = UDim2.fromScale(1, 1),
			accent = Palette.cyan,
			background = Palette.panel,
			padding = 16,
			reducedMotion = softMotion,
		}, h(SectionLabel, { value = "THE LOOM", color = Palette.cyan }), h(Text, {
			value = if echoes.Ready then "The charge is full. Strike to see what answers." else `{math.floor(charge * 100)}% charged. Play leaves a trace: whatever you do most shapes the first echo.`,
			size = 13,
			color = Palette.creamSoft,
			wrap = true,
			position = UDim2.fromOffset(0, 28),
			sizeConstraint = UDim2.new(1, 0, 0, 36),
		}), h(Meter, {
			value = charge,
			color = if echoes.Ready then Palette.mango else Palette.cyan,
			size = UDim2.new(1, 0, 0, 10),
			position = UDim2.fromOffset(0, 70),
		}), h("frame", {
			Size = UDim2.new(if stack then 1 else 0.6, 0, 0, 4 * 34),
			Position = UDim2.fromOffset(0, 92),
			BackgroundTransparency = 1,
		}, h("uilistlayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }), tracks), h("frame", {
			Name = "EchoClaimActions",
			ref = strikeHost,
			ClipsDescendants = false,
			Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.new(0.36, 0, 0, TapTarget),
			Position = if stack then UDim2.new(0, 0, 1, -TapTarget) else UDim2.new(1, 0, 0, 100),
			AnchorPoint = if stack then Vector2.zero else Vector2.new(1, 0),
			BackgroundTransparency = 1,
		}, h("uiscale", { Scale = readyPulse:map(function(p)
			return 1 + p * 0.03
		end) }), h(Button, {
			text = if #(echoes.Draft or {}) > 0 then "Pick an echo below" elseif echoes.Ready then "Strike" else "Charging",
			onClick = function()
				act({ Op = "Strike" })
			end,
			disabled = not echoes.Ready or #(echoes.Draft or {}) > 0,
			color = Palette.mango,
			textColor = Palette.ink,
			highlight = echoes.Ready,
			size = UDim2.fromScale(1, 1),
			reducedMotion = softMotion,
		}))),
	})

	-- the strike: three echoes, keep one (or reroll once for resonance)
	if #(echoes.Draft or {}) > 0 then
		local cards = {}
		for index, choice in echoes.Draft do
			cards["c" .. index] = h("frame", {
				Size = if stack then UDim2.new(1, 0, 0, 170) else UDim2.new(1 / 3, -8, 1, 0),
				LayoutOrder = index,
				BackgroundTransparency = 1,
			}, h(EchoCard, {
				echo = choice,
				place = "draft",
				index = index,
				reducedMotion = softMotion,
				actions = h(Button, {
					text = "Keep this one",
					onClick = function()
						act({ Op = "Keep", Choice = index })
					end,
					color = TIER_COLOR[choice.Tier] or Palette.mango,
					textColor = Palette.ink,
					size = UDim2.fromScale(1, 1),
					reducedMotion = softMotion,
				}),
			}))
		end
		local cardsH = if stack then 3 * 178 else 178
		table.insert(sections, {
			id = "draft",
			height = 32 + cardsH + 8 + TapTarget,
			element = h("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, h(SectionLabel, {
				value = "WHAT ANSWERED",
				color = Palette.mango,
			}), h("frame", {
				Size = UDim2.new(1, 0, 0, cardsH),
				Position = UDim2.fromOffset(0, 32),
				BackgroundTransparency = 1,
			}, h("uilistlayout", {
				FillDirection = if stack then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}), cards), h("frame", {
				Size = UDim2.new(0, 260, 0, TapTarget),
				Position = UDim2.new(1, 0, 1, 0),
				AnchorPoint = Vector2.new(1, 1),
				BackgroundTransparency = 1,
			}, h(Button, {
				text = if echoes.Rerolled then "Already rerolled" else `Reroll for {EchoMath.REROLL_RESONANCE} resonance`,
				onClick = function()
					act({ Op = "Reroll" })
				end,
				disabled = echoes.Rerolled or echoes.Resonance < EchoMath.REROLL_RESONANCE,
				color = Palette.panelSoft,
				textColor = Palette.cream,
				size = UDim2.fromScale(1, 1),
				reducedMotion = softMotion,
			}))),
		})
	end

	-- the chord: four slots, its bonuses and what it all adds up to
	local byUid = {}
	for _, echo in echoes.Inventory do
		byUid[echo.Uid] = echo
	end
	local slots = {}
	for _, slot in echoes.Chord do
		local echo = byUid[slot.Uid]
		local placing = slotting ~= nil and slot.Open
		slots["s" .. slot.Slot] = h("textbutton", {
			Size = if stack then UDim2.new(0.5, -4, 0, 96) else UDim2.new(0.25, -6, 1, 0),
			LayoutOrder = slot.Slot,
			BackgroundColor3 = if placing then darken(Palette.mango, 0.6) else Palette.panelSoft,
			AutoButtonColor = false,
			Text = "",
			Event = {
				Activated = function()
					if slotting ~= nil and slot.Open then
						act({ Op = "Slot", Slot = slot.Slot, Uid = slotting })
						setSlotting(nil)
					elseif echo ~= nil then
						act({ Op = "Slot", Slot = slot.Slot, Uid = "" })
					end
				end,
			},
		}, h("uicorner", { CornerRadius = UDim.new(0, 12) }), h("uistroke", {
			Color = if echo then (TIER_COLOR[echo.Tier] or Palette.line) elseif placing then Palette.mango else Palette.line,
			Thickness = if placing then 2 else 1,
		}), h("uipadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 10) }), if echo then h(Icon, {
			kind = traitIcon("chord", echo.Trait) or "Wave.echoChordUnknown",
			size = 34,
		}) else nil, h(Text, {
			value = if echo then EchoMath.trait(echo.Trait).Name elseif slot.Open then (if placing then "Put it here" else "Empty") else `Opens at {slot.NeedsCaptures} kept`,
			size = 12,
			color = if echo then Palette.cream else Palette.muted,
			weight = Enum.FontWeight.Bold,
			fit = true,
			minSize = 9,
			position = UDim2.fromOffset(0, if echo then 40 else 8),
			sizeConstraint = UDim2.new(1, 0, 0, 16),
		}), echo and h(Text, {
			value = `{echo.Tier} · L{echo.Level}`,
			size = 11,
			color = TIER_COLOR[echo.Tier] or Palette.muted,
			position = UDim2.fromOffset(0, 58),
			sizeConstraint = UDim2.new(1, 0, 0, 14),
		}))
	end
	local bonusChips = {}
	local order = 0
	for _, entry in { { "Harmony", "HARMONY +15%", Palette.mint }, { "Unison", "UNISON +10%", Palette.cyan }, { "Spectrum", "SPECTRUM +20%", Palette.mango } } do
		if echoes.Bonuses and echoes.Bonuses[entry[1]] then
			order += 1
			bonusChips["b" .. order] = chip(entry[2], entry[3], order)
		end
	end
	local totals = {}
	for _, kind in EchoMath.KINDS do
		local v = echoes.Totals and echoes.Totals[kind] or 0
		if v > 0 then
			table.insert(totals, `{pct(v)} {KIND_WORDS[kind]}`)
		end
	end
	local slotsH = if stack then 200 else 110
	table.insert(sections, {
		id = "chord",
		height = 32 + slotsH + 8 + 22 + 8 + 36,
		element = h("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, h(SectionLabel, {
			value = if slotting then "THE CHORD · PICK A SLOT" else "THE CHORD",
			color = Palette.violet,
		}), h("frame", {
			Size = UDim2.new(1, 0, 0, slotsH),
			Position = UDim2.fromOffset(0, 32),
			BackgroundTransparency = 1,
		}, h("uigridlayout", {
			CellSize = if stack then UDim2.new(0.5, -4, 0, 96) else UDim2.new(0.25, -6, 1, 0),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}), slots), h("frame", {
			Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.fromOffset(0, 32 + slotsH + 8),
			BackgroundTransparency = 1,
		}, h("uilistlayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }), bonusChips), h(Text, {
			value = if #totals > 0 then "The chord adds " .. table.concat(totals, ", ") .. "." else "Put echoes in the chord to feel them. Matching affinities add Harmony; a matched pair adds Unison; four different affinities make a Spectrum.",
			size = 12,
			color = Palette.creamSoft,
			wrap = true,
			position = UDim2.fromOffset(0, 32 + slotsH + 8 + 26),
			sizeConstraint = UDim2.new(1, 0, 0, 36),
		})),
	})

	-- the vault: every echo you keep
	local columns = if stack then 1 elseif viewport.width >= 1500 then 3 else 2
	local cardH = 186
	local vault = {}
	for index, echo in echoes.Inventory do
		local partner = nil
		for _, other in echoes.Inventory do
			if other.Uid ~= echo.Uid and other.Trait == echo.Trait and other.Tier == echo.Tier and not other.Locked then
				partner = other
			end
		end
		local canFuse = partner ~= nil and not echo.Locked and EchoMath.nextTier(echo.Tier) ~= nil
		local isArmed = armed == echo.Uid
		local actionList = {
			{ "Slot", function()
				setSlotting(if slotting == echo.Uid then nil else echo.Uid)
			end, Palette.violet, false },
			{ `Tune · {compactNumber(echo.TuneCost)}`, function()
				act({ Op = "Tune", Uid = echo.Uid })
			end, Palette.cyan, (tonumber(state.Stardust) or 0) < echo.TuneCost or echo.Level >= EchoMath.MAX_LEVEL },
			{ "Fuse", function()
				act({ Op = "Fuse", A = echo.Uid, B = partner.Uid })
			end, Palette.mango, not canFuse },
			{ if echo.Locked then "Unlock" else "Lock", function()
				act({ Op = "Lock", Uid = echo.Uid })
			end, Palette.panelSoft, false },
			{ if isArmed then "Sure?" else `Break · +{echo.Resonance}`, function()
				if isArmed then
					setArmed(nil)
					act({ Op = "Dismantle", Uid = echo.Uid })
				else
					setArmed(echo.Uid)
				end
			end, if isArmed then Palette.coral else Palette.panelSoft, echo.Locked },
		}
		local buttons = {}
		for i, a in actionList do
			buttons["a" .. i] = h("frame", {
				Size = UDim2.new(1 / #actionList, -6, 1, 0),
				LayoutOrder = i,
				BackgroundTransparency = 1,
			}, h(Button, {
				text = a[1],
				onClick = a[2],
				color = a[3],
				textColor = if a[3] == Palette.panelSoft then Palette.cream else Palette.ink,
				disabled = a[4],
				size = UDim2.fromScale(1, 1),
				reducedMotion = softMotion,
			}))
		end
		vault["v" .. echo.Uid] = h("frame", {
			LayoutOrder = index,
			BackgroundTransparency = 1,
		}, h(EchoCard, {
			echo = echo,
			place = "vault",
			index = index,
			reducedMotion = softMotion,
			actionsHeight = 34,
			actions = h("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, h("uilistlayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}), buttons),
		}))
	end
	local rows = math.max(1, math.ceil(#echoes.Inventory / columns))
	table.insert(sections, {
		id = "vault",
		height = 32 + (if #echoes.Inventory == 0 then 80 else rows * cardH + (rows - 1) * 8),
		element = h("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, h(SectionLabel, {
			value = `KEPT · {#echoes.Inventory}/{echoes.InventoryLimit}  ·  {compactNumber(echoes.Resonance)} RESONANCE`,
			color = Palette.cyan,
		}), h("frame", {
			Size = UDim2.new(1, 0, 1, -32),
			Position = UDim2.fromOffset(0, 32),
			BackgroundTransparency = 1,
		}, #echoes.Inventory > 0 and h("uigridlayout", {
			CellSize = UDim2.new(1 / columns, -8 * (columns - 1) / columns, 0, cardH),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}), if #echoes.Inventory > 0 then vault else h(Text, {
			value = "Nothing kept yet. Fill the charge and strike.",
			size = 13,
			color = Palette.muted,
			sizeConstraint = UDim2.new(1, 0, 0, 20),
		}))),
	})

	-- the journal: every trait at every tier
	local journalRows = {}
	for index, trait in EchoMath.TRAITS do
		local reached = echoes.Journal and echoes.Journal[trait.Id] or 0
		local pips = {}
		for t, tier in EchoMath.TIERS do
			pips["p" .. t] = chip(string.upper(tier), if t <= reached then TIER_COLOR[tier] else Palette.lineSoft, t)
		end
		journalRows["j" .. index] = h("frame", {
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = index,
			BackgroundTransparency = 1,
		}, h(Icon, { kind = traitIcon("journal", trait.Id), size = 24, position = UDim2.fromOffset(0, 3) }), h(Text, {
			value = trait.Name .. (if reached >= #EchoMath.TIERS then "  ·  complete, +3% for good" else ""),
			size = 12,
			color = if reached >= #EchoMath.TIERS then Palette.mango else Palette.creamSoft,
			weight = Enum.FontWeight.Bold,
			fit = true,
			minSize = 9,
			position = UDim2.fromOffset(32, 7),
			sizeConstraint = UDim2.new(0.4, -32, 0, 16),
		}), h("frame", {
			Size = UDim2.new(0.6, 0, 1, 0),
			Position = UDim2.fromScale(0.4, 0),
			BackgroundTransparency = 1,
		}, h("uilistlayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }), pips))
	end
	table.insert(sections, {
		id = "journal",
		height = 32 + #EchoMath.TRAITS * 34 + 16,
		element = h(Panel, {
			size = UDim2.fromScale(1, 1),
			accent = Palette.lineSoft,
			background = Palette.panel,
			padding = 14,
		}, h(SectionLabel, { value = "JOURNAL · KEEP EVERY TIER OF A TRAIT FOR A PERMANENT BONUS", color = Palette.mango }), h("frame", {
			Size = UDim2.new(1, 0, 1, -30),
			Position = UDim2.fromOffset(0, 30),
			BackgroundTransparency = 1,
		}, h("uilistlayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }), journalRows)),
	})

	return React.createElement(PageScaffold, {
		gap = gap,
		tailPad = scrollTail(chrome.stack, chrome.bottomSafe, if stack then 72 else 56),
		scrollBarColor = Palette.cyan,
		scrollBarThickness = 4,
		sections = sections,
	})
end
return {
	EchoForgeView = EchoForgeView,
}
end

__defs["InventoryView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local itemIconKind = require(script.Parent.Parent.ArtKit)("Icon").itemIconKind
local _format = require(script.Parent.Parent.CoreKit)("format")
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useFlipperSpring = _motion.useFlipperSpring
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local useWallClock = _motion.useWallClock
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local Layout = _theme.Layout
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local contrastOn = _theme.contrastOn
local scrollTail = _theme.scrollTail
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local FlatList = require(script.Parent.Parent.LayoutKit)("virtualizedList").FlatList
local InventoryMath = require(script.Parent.Parent.CoreKit)("inventoryMath")
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local Dropdown = _ui.Dropdown
local EmptyState = _ui.EmptyState
local IconTile = _ui.IconTile
local Meter = _ui.Meter
local Panel = _ui.Panel
local SCROLL_EDGE = _ui.SCROLL_EDGE
local SearchField = _ui.SearchField
local SectionLabel = _ui.SectionLabel
local SegmentedTabs = _ui.SegmentedTabs
local ShimmerText = _ui.ShimmerText
local Text = _ui.Text
local RELIC_ROW_SHOWN = React.createBinding(1)
local TABS = { "Relics", "Crates", "Market", "Loadout" }
local _newValue = table.create(#TABS)
local _callback = function(id)
	return {
		id = id,
		label = string.upper(id),
	}
end
for _k, _v in TABS do
	_newValue[_k] = _callback(_v, _k - 1, TABS)
end
local TAB_OPTIONS = _newValue
local FILTERS = { {
	id = "All",
	label = "All relics",
}, {
	id = "Machine",
	label = "Machine slot",
}, {
	id = "Research",
	label = "Research slot",
}, {
	id = "Equipped",
	label = "Equipped only",
}, {
	id = "Unequipped",
	label = "Unequipped only",
}, {
	id = "Protected",
	label = "Protected only",
}, {
	id = "Duplicates",
	label = "Duplicates",
}, {
	id = "Starred",
	label = "Starred only",
} }
local SORTS = { {
	id = "Rarity",
	label = "Rarity first",
}, {
	id = "Power",
	label = "Highest power",
}, {
	id = "Level",
	label = "Highest level",
}, {
	id = "Newest",
	label = "Newest first",
}, {
	id = "Stars",
	label = "Most stars",
}, {
	id = "Salvage",
	label = "Salvage value",
}, {
	id = "Name",
	label = "Name A-Z",
} }
local RARITY_FILTERS = { {
	id = "Any",
	label = "Any rarity",
}, {
	id = "Common",
	label = "Common",
}, {
	id = "Uncommon",
	label = "Uncommon",
}, {
	id = "Rare",
	label = "Rare",
}, {
	id = "Epic",
	label = "Epic",
}, {
	id = "Legendary",
	label = "Legendary",
}, {
	id = "Mythic",
	label = "Mythic",
}, {
	id = "Celestial",
	label = "Celestial",
}, {
	id = "Astral",
	label = "Astral",
} }
local AUTO_RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
local HERO_H = 96
local HERO_H_STACK = 124
local ROW_GAP = 10
local SCROLL_PAD = 24 + 16
local TOOL_FIELD_DESK = 50
local BULK_DOCK_H = 58
local function InventoryTools(_param)
	local search = _param.search
	local setSearch = _param.setSearch
	local filter = _param.filter
	local setFilter = _param.setFilter
	local rarity = _param.rarity
	local setRarity = _param.setRarity
	local sort = _param.sort
	local setSort = _param.setSort
	local bulkMode = _param.bulkMode
	local setBulkMode = _param.setBulkMode
	local autoOpen = _param.autoOpen
	local setAutoOpen = _param.setAutoOpen
	local equipBest = _param.equipBest
	local reducedMotion = _param.reducedMotion
	local stack = _param.stack
	local filled = _param.filled
	local limit = _param.limit
	local essence = _param.essence
	local fieldH = if stack then math.max(TapTarget, 52) else TOOL_FIELD_DESK
	local gap = if stack then 8 else 10
	local pad = if stack then 8 else 12
	local filterOptions = FILTERS
	local rarityOptions = RARITY_FILTERS
	local sortOptions = SORTS
	local bagW = if stack then 100 else 104
	local essW = if stack then 112 else 116
	local metaW = bagW + essW + gap
	local filterH = if stack then fieldH * 2 + gap else fieldH
	local actionW = UDim2.new(1 / 3, -math.ceil((gap * 2) / 3), 0, fieldH)
	local accent = if bulkMode then Palette.coral elseif autoOpen then Palette.mango else Palette.violet
	local bagBadge = React.createElement(Badge, {
		value = `{filled} / {limit} BAG`,
		accent = Palette.violet,
		filled = true,
		size = UDim2.fromOffset(bagW, 26),
	})
	local essBadge = React.createElement(Badge, {
		value = `{compactNumber(essence)} ESS`,
		accent = Palette.mango,
		size = UDim2.fromOffset(essW, 26),
	})
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = accent,
		Thickness = 1.5,
		Transparency = 0.28,
	}), React.createElement("uipadding", {
		PaddingTop = UDim.new(0, pad),
		PaddingBottom = UDim.new(0, pad),
		PaddingLeft = UDim.new(0, pad + 2),
		PaddingRight = UDim.new(0, pad + 2),
	}), React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, gap),
	}), stack and React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}), bagBadge, essBadge), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, filterH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		ClipsDescendants = false,
	}, if stack then React.createElement(React.Fragment, nil, React.createElement(SearchField, {
		value = search,
		onChange = setSearch,
		placeholder = "Search relics, effects, or ID",
		accent = Palette.violet,
		size = UDim2.new(1, 0, 0, fieldH),
		reducedMotion = reducedMotion,
		zIndex = 62,
	}), React.createElement(Dropdown, {
		options = filterOptions,
		value = filter,
		onChange = setFilter,
		accent = Palette.violet,
		position = UDim2.fromOffset(0, fieldH + gap),
		size = UDim2.new(1 / 3, -6, 0, fieldH),
		reducedMotion = reducedMotion,
		zIndex = 61,
	}), React.createElement(Dropdown, {
		options = rarityOptions,
		value = rarity,
		onChange = setRarity,
		accent = Palette.mango,
		position = UDim2.new(1 / 3, 2, 0, fieldH + gap),
		size = UDim2.new(1 / 3, -6, 0, fieldH),
		reducedMotion = reducedMotion,
		zIndex = 60,
	}), React.createElement(Dropdown, {
		options = sortOptions,
		value = sort,
		onChange = setSort,
		accent = Palette.cyan,
		position = UDim2.new(2 / 3, 4, 0, fieldH + gap),
		size = UDim2.new(1 / 3, -4, 0, fieldH),
		reducedMotion = reducedMotion,
		zIndex = 59,
	})) else React.createElement(React.Fragment, nil, React.createElement("frame", {
		Size = UDim2.fromOffset(metaW, fieldH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}), bagBadge, essBadge), React.createElement("frame", {
		Size = UDim2.new(1, -(metaW + gap), 0, fieldH),
		Position = UDim2.fromOffset(metaW + gap, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(SearchField, {
		value = search,
		onChange = setSearch,
		placeholder = "Search relics, effects, or ID",
		accent = Palette.violet,
		size = UDim2.new(0.4, -6, 0, fieldH),
		reducedMotion = reducedMotion,
		zIndex = 62,
	}), React.createElement(Dropdown, {
		options = filterOptions,
		value = filter,
		onChange = setFilter,
		accent = Palette.violet,
		position = UDim2.new(0.4, 0, 0, 0),
		size = UDim2.new(0.2, -6, 0, fieldH),
		reducedMotion = reducedMotion,
		zIndex = 61,
	}), React.createElement(Dropdown, {
		options = rarityOptions,
		value = rarity,
		onChange = setRarity,
		accent = Palette.mango,
		position = UDim2.new(0.6, 0, 0, 0),
		size = UDim2.new(0.2, -6, 0, fieldH),
		reducedMotion = reducedMotion,
		zIndex = 60,
	}), React.createElement(Dropdown, {
		options = sortOptions,
		value = sort,
		onChange = setSort,
		accent = Palette.cyan,
		position = UDim2.new(0.8, 0, 0, 0),
		size = UDim2.new(0.2, 0, 0, fieldH),
		reducedMotion = reducedMotion,
		zIndex = 59,
	})))), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, fieldH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 2,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Button, {
		text = if stack then "BEST" else "EQUIP BEST",
		icon = "Loadout.2",
		onClick = equipBest,
		color = Palette.mint,
		textColor = Palette.ink,
		size = actionW,
		reducedMotion = reducedMotion,
		highlight = true,
	}), React.createElement(Button, {
		text = if bulkMode then "DONE" elseif stack then "SELECT" else "MULTI SALVAGE",
		icon = if bulkMode then "Check.18" else "Dust.5",
		onClick = function()
			setBulkMode(not bulkMode)
			setAutoOpen(false)
		end,
		color = if bulkMode then Palette.coral else Palette.panelSoft,
		textColor = if bulkMode then Palette.ink else Palette.creamSoft,
		size = actionW,
		reducedMotion = reducedMotion,
		outline = not bulkMode,
	}), React.createElement(Button, {
		text = if stack then "RECYCLE" else "AUTO-SALVAGE",
		icon = "Inventory.5",
		onClick = function()
			setAutoOpen(not autoOpen)
			setBulkMode(false)
		end,
		color = if autoOpen then Palette.mango else Palette.panelSoft,
		textColor = if autoOpen then Palette.ink else Palette.creamSoft,
		size = actionW,
		reducedMotion = reducedMotion,
		outline = not autoOpen,
	})))
end
local function BulkDock(_param)
	local selectedCount = _param.selectedCount
	local selectableCount = _param.selectableCount
	local selectionEssence = _param.selectionEssence
	local selectVisible = _param.selectVisible
	local clearSelection = _param.clearSelection
	local salvageSelected = _param.salvageSelected
	local bulkBusy = _param.bulkBusy
	local reducedMotion = _param.reducedMotion
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ZIndex = 30,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.coral,
		Thickness = 1.5,
		Transparency = 0.28,
	}), React.createElement("uipadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	}), React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}), React.createElement(Button, {
		text = if selectableCount > 0 then `SELECT {math.min(25, selectableCount)}` else "NONE TO PICK",
		icon = "Check.19",
		onClick = selectVisible,
		color = Palette.violet,
		textColor = Palette.cream,
		size = UDim2.new(0.42, -4, 1, 0),
		reducedMotion = reducedMotion,
		disabled = selectableCount == 0,
		outline = true,
	}), React.createElement(Button, {
		text = if bulkBusy then "SALVAGING" elseif selectedCount > 0 and _param.bulkArmed then `TAP AGAIN · SALVAGE {selectedCount}` elseif selectedCount > 0 then `SALVAGE {selectedCount}  +{compactNumber(selectionEssence)} ESS` else "CLEAR PICKS",
		icon = "Dust.6",
		onClick = if selectedCount > 0 then salvageSelected else clearSelection,
		color = if selectedCount > 0 then Palette.coral else Palette.panelSoft,
		textColor = if selectedCount > 0 then Palette.ink else Palette.muted,
		size = UDim2.new(0.58, -4, 1, 0),
		reducedMotion = reducedMotion,
		disabled = bulkBusy,
		highlight = selectedCount > 0,
	}))
end
local function AutoSalvageSheet(_param)
	local passOwned = _param.passOwned
	local rules = _param.rules
	local updateRules = _param.updateRules
	local autoBusy = _param.autoBusy
	local openShop = _param.openShop
	local runNow = _param.runNow
	local reducedMotion = _param.reducedMotion
	local stack = _param.stack
	local config = _param.config
	local onClose = _param.onClose
	local sheetHostRef = React.useRef(nil)
	local fieldH = if stack then math.max(TapTarget, 52) else TOOL_FIELD_DESK
	local rarityH = if stack then TapTarget else 36
	React.useEffect(function()
		GamepadNavigationService.BeginOverlayFocus()
		return function()
			GamepadNavigationService.EndOverlayFocus()
		end
	end, {})
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = sheetHostRef.current
		if host == nil then
			return nil
		end
		local selectJob = task.defer(function()
			if host.Parent == nil then
				return
			end
			GamepadNavigationService.FocusClaim(host)
		end)
		return function()
			pcall(task.cancel, selectJob)
		end
	end, { passOwned, autoBusy })
	local toggleAutoRarity = function(entry)
		if entry == "Any" then
			return nil
		end
		local updated = {}
		for key, value in pairs(rules.Rarities) do
			updated[key] = value
		end
		if rules.Rarities[entry] == true then
			local _entry = entry
			updated[_entry] = nil
		else
			local _entry = entry
			updated[_entry] = true
		end
		local packed = {}
		local _callback_1 = function(value, key)
			packed[key] = value
		end
		for _k, _v in updated do
			_callback_1(_v, _k, updated)
		end
		local _object = table.clone(rules)
		setmetatable(_object, nil)
		_object.Rarities = packed
		updateRules(_object)
	end
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	})
	local _exp_1 = React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = if passOwned then Palette.mango else Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.4,
	})
	local _exp_2 = React.createElement("uipadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	})
	local _exp_3 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	})
	local _exp_4 = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 0,
	}, React.createElement(Text, {
		value = "AUTO-SALVAGE",
		size = 12,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, -44, 1, 0),
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -28, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Button, {
		text = "",
		icon = "Close.7",
		onClick = onClose,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})))
	local _result
	if not passOwned then
		_result = React.createElement(React.Fragment, nil, React.createElement(Text, {
			value = "Pick rarities once. Later crate drops of those rarities turn into essence.",
			size = 11,
			color = Palette.creamSoft,
			wrap = true,
			layoutOrder = 1,
			sizeConstraint = UDim2.new(1, 0, 0, if stack then 32 else 18),
		}), React.createElement(Button, {
			text = "VIEW PASS",
			icon = "Shop.10",
			onClick = openShop,
			color = Palette.mango,
			textColor = Palette.ink,
			size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(132, TapTarget),
			reducedMotion = reducedMotion,
			highlight = true,
		}))
	else
		local _exp_5 = React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, fieldH),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 1,
			ClipsDescendants = false,
		}, React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}), React.createElement(Button, {
			text = if autoBusy then "SAVING" elseif rules.Enabled then "ON" else "OFF",
			icon = if rules.Enabled then "Check.20" else "Inventory.6",
			onClick = function()
				local _object = table.clone(rules)
				setmetatable(_object, nil)
				_object.Enabled = not rules.Enabled
				return updateRules(_object)
			end,
			color = if rules.Enabled then Palette.mint else Palette.panelSoft,
			textColor = if rules.Enabled then Palette.ink else Palette.creamSoft,
			size = UDim2.new(0.28, -6, 0, fieldH),
			reducedMotion = reducedMotion,
			disabled = autoBusy,
			outline = not rules.Enabled,
		}), React.createElement(Button, {
			text = if rules.KeepNew then "KEEP NEW" else "RECYCLE NEW",
			icon = if rules.KeepNew then "Lock.12" else "Dust.7",
			onClick = function()
				local _object = table.clone(rules)
				setmetatable(_object, nil)
				_object.KeepNew = not rules.KeepNew
				return updateRules(_object)
			end,
			color = if rules.KeepNew then Palette.violet else Palette.coral,
			textColor = if rules.KeepNew then Palette.cream else Palette.ink,
			size = UDim2.new(0.44, -6, 0, fieldH),
			reducedMotion = reducedMotion,
			disabled = autoBusy,
			outline = true,
		}), React.createElement(Button, {
			text = "RUN",
			icon = "Dust.8",
			onClick = runNow,
			color = Palette.mango,
			textColor = Palette.ink,
			size = UDim2.new(0.28, -6, 0, fieldH),
			reducedMotion = reducedMotion,
			disabled = autoBusy or not rules.Enabled,
			highlight = rules.Enabled,
		}))
		local _newValue_1 = table.create(#AUTO_RARITIES)
		local _callback_1 = function(entry, index)
			local active = rules.Rarities[entry] == true
			local cols = if stack then 3 else 6
			local col = index % cols
			local row = math.floor(index / cols)
			local label = if stack and entry == "Legendary" then "LEGEND" else string.upper(entry)
			return React.createElement(Button, {
				key = entry,
				text = label,
				onClick = function()
					return toggleAutoRarity(entry)
				end,
				color = if active then InventoryMath.RarityColor(config, entry, Palette.muted) else Palette.panelSoft,
				textColor = if active then Palette.ink else Palette.muted,
				position = UDim2.new(col / cols, if col == 0 then 0 else 4, 0, row * (rarityH + 8)),
				size = UDim2.new(1 / cols, -6, 0, rarityH),
				reducedMotion = reducedMotion,
				disabled = autoBusy,
				outline = not active,
			})
		end
		for _k, _v in AUTO_RARITIES do
			_newValue_1[_k] = _callback_1(_v, _k - 1, AUTO_RARITIES)
		end
		_result = React.createElement(React.Fragment, nil, _exp_5, React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, if stack then rarityH * 2 + 8 else rarityH),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 2,
			ClipsDescendants = false,
		}, _newValue_1))
	end
	return React.createElement("frame", {
		ref = sheetHostRef,
		Name = "AutoSalvageSheet",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 40,
		ClipsDescendants = false,
	}, React.createElement("frame", {
		Name = "AutoSalvageClaim",
		Size = UDim2.new(1, -8, 0, 0),
		Position = UDim2.fromOffset(4, 6),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ZIndex = 41,
		ClipsDescendants = false,
	}, _exp, _exp_1, _exp_2, _exp_3, _exp_4, _result))
end
local function RelicRow(_param)
	local item = _param.item
	local config = _param.config
	local selected = _param.selected
	local bulkSelected = _param.bulkSelected
	local bulkMode = _param.bulkMode
	local onSelect = _param.onSelect
	local reducedMotion = _param.reducedMotion
	local y = _param.y
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local stack = _param.stack
	if stack == nil then
		stack = false
	end
	local accent = InventoryMath.RarityColor(config, item.definition.Rarity, Palette.muted)
	local textW = if stack then -(58 + 8) else -176
	local locked = item.instance.Locked == true
	local height = InventoryMath.RelicRowHeight(stack)
	return React.createElement("imagebutton", {
		Size = UDim2.new(1, 0, 0, height),
		Position = if y ~= nil then UDim2.fromOffset(0, y) else nil,
		LayoutOrder = layoutOrder,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = true,
		Event = {
			Activated = function()
				Audio:play("tick")
				onSelect()
			end,
			MouseEnter = function()
				return Audio:play("hover")
			end,
			SelectionGained = function()
				return Audio:play("hover")
			end,
		},
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = if bulkSelected then Palette.coral else accent,
		background = if selected or bulkSelected then Palette.panelRaised else Palette.panel,
		padding = if stack then 12 else 14,
		interactive = true,
		highlight = selected or bulkSelected,
		reducedMotion = reducedMotion,
		reveal = RELIC_ROW_SHOWN,
		clips = true,
	}, React.createElement(IconTile, {
		kind = itemIconKind(item.instance.DefinitionId, item.definition.Slot),
		accent = accent,
		size = if stack then 44 else 46,
		radius = 11,
		position = UDim2.fromOffset(0, if stack then 4 else 8),
		reducedMotion = reducedMotion,
		glow = selected,
	}), React.createElement(Text, {
		value = item.definition.Name,
		size = if stack then 15 else 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 12,
		position = UDim2.fromOffset(58, 0),
		sizeConstraint = UDim2.new(1, textW, 0, 22),
	}), React.createElement(Text, {
		value = `{item.definition.Description}  ·  {InventoryMath.EffectLabel(item.definition, item.instance.Level, item.instance.Stars)}`,
		size = 11,
		color = accent,
		wrap = false,
		position = UDim2.fromOffset(58, 24),
		sizeConstraint = UDim2.new(1, textW, 0, 18),
	}), React.createElement(Text, {
		value = if item.equippedOn ~= nil then `On {InventoryMath.SocketLabel(item.equippedOn)}` elseif locked then "Protected" else `{item.definition.Slot} relic`,
		size = 11,
		color = if item.equippedOn ~= nil then Palette.mint elseif locked then Palette.mango else Palette.creamSoft,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(58, 44),
		sizeConstraint = UDim2.new(1, textW, 0, 16),
	}), React.createElement("frame", {
		Size = if stack then UDim2.new(1, -(58 + 8), 0, 22) else UDim2.fromOffset(84, 86),
		Position = if stack then UDim2.fromOffset(58, 68) else UDim2.new(1, -84, 0, 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, if stack then React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}) else React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Badge, {
		value = string.upper(item.definition.Rarity),
		accent = accent,
		filled = true,
		size = if stack then UDim2.fromOffset(78, 20) else UDim2.fromOffset(84, 20),
	}), React.createElement(Badge, {
		value = if (tonumber(item.instance.Stars) or 0) > 0 then `LV {item.instance.Level} {string.rep("★", math.min(5, item.instance.Stars))}` else `LV {item.instance.Level}`,
		accent = Palette.mango,
		size = if stack then UDim2.fromOffset(if (tonumber(item.instance.Stars) or 0) > 0 then 92 else 56, 20) else UDim2.fromOffset(84, 20),
	}), not stack and React.createElement(Badge, {
		value = `#{string.sub(item.uid, -4)}`,
		accent = Palette.lineSoft,
		size = UDim2.fromOffset(84, 20),
	}), locked and not bulkMode and stack and React.createElement(Badge, {
		value = "LOCK",
		accent = Palette.mango,
		filled = true,
		size = UDim2.fromOffset(44, 20),
	}), bulkMode and React.createElement(Badge, {
		value = if bulkSelected then "ON" elseif locked then "LOCK" elseif item.equippedOn ~= nil then "USED" else "PICK",
		accent = if bulkSelected then Palette.coral elseif locked or item.equippedOn ~= nil then Palette.lineSoft else accent,
		filled = bulkSelected,
		size = if stack then UDim2.fromOffset(52, 20) else UDim2.fromOffset(84, 20),
	}))))
end
local INSPECT_PAD = InventoryMath.INSPECT_PAD
local INSPECT_BTN_GAP = InventoryMath.INSPECT_BTN_GAP
local INSPECT_FOOTER_H = InventoryMath.INSPECT_FOOTER_H
local ACTION_BTN = InventoryMath.ACTION_BTN
local function DetailPanel(_param)
	local item = _param.item
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local layoutOrder = _param.layoutOrder
	local stack = _param.stack
	if stack == nil then
		stack = false
	end
	local fill = _param.fill
	if fill == nil then
		fill = false
	end
	local inspectActionsHostRef = React.useRef(nil)
	local accent = InventoryMath.RarityColor(config, item.definition.Rarity, Palette.muted)
	local _result = state.Items
	if _result ~= nil then
		_result = _result.Essence
	end
	local _condition = _result
	if _condition == nil then
		_condition = 0
	end
	local essence = _condition
	local cost = InventoryMath.UpgradeCost(item.definition, item.instance.Level)
	local canUpgrade, maxed = InventoryMath.UpgradeState(
		item.instance.Level,
		item.definition.MaxLevel,
		essence,
		cost
	)
	local targets = React.useMemo(function()
		return InventoryMath.SocketTargets(state, config, item.definition)
	end, { config, item.definition, state.Machines, state.Research })
	local _condition_1 = item.equippedOn
	if _condition_1 == nil then
		local _result_1 = targets[1]
		if _result_1 ~= nil then
			_result_1 = _result_1.id
		end
		_condition_1 = _result_1
		if _condition_1 == nil then
			_condition_1 = ""
		end
	end
	local target, setTarget = React.useState(_condition_1)
	local salvageArmedFor, setSalvageArmedFor = React.useState(nil)
	React.useEffect(function()
		if salvageArmedFor == nil then
			return nil
		end
		local lapse = task.delay(4, function()
			setSalvageArmedFor(nil)
		end)
		return function()
			pcall(task.cancel, lapse)
		end
	end, { salvageArmedFor })
	React.useEffect(function()
		setTarget(function(current)
			if item.equippedOn ~= nil then
				return item.equippedOn
			end
			local _result_1 = false
			local _callback_1 = function(candidate)
				return candidate.id == current
			end
			for _k, _v in targets do
				if _callback_1(_v, _k - 1, targets) then
					_result_1 = true
					break
				end
			end
			if _result_1 then
				return current
			end
			local _result_2 = targets[1]
			if _result_2 ~= nil then
				_result_2 = _result_2.id
			end
			local _condition_2 = _result_2
			if _condition_2 == nil then
				_condition_2 = ""
			end
			return _condition_2
		end)
	end, { item.uid, item.equippedOn, targets })
	local salvage = InventoryMath.SalvagePreview(config, item.definition, item.instance.Level)
	local equipped = item.equippedOn ~= nil
	local locked = item.instance.Locked == true
	local chipCols = if stack then 2 else 3
	local chipRows = InventoryMath.ChipRows(#targets, stack)
	local socketBlock = InventoryMath.InspectSocketBlock(equipped, #targets, chipRows, stack, TapTarget)
	local chipHeight = if stack then TapTarget else 40
	local chipStep = if stack then TapTarget + 6 else 42
	local actionsH = InventoryMath.InspectActionsHeight(stack)
	local detailH = InventoryMath.InspectPanelHeight(socketBlock, stack)
	local actionSize = if stack then UDim2.new(0.5, -5, 0, ACTION_BTN) else UDim2.new(0.25, -7, 0, ACTION_BTN)
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = inspectActionsHostRef.current
		if host == nil then
			return nil
		end
		local selectJob = task.defer(function()
			if host.Parent == nil then
				return
			end
			GamepadNavigationService.FocusClaim(host)
		end)
		return function()
			pcall(task.cancel, selectJob)
		end
	end, { item.uid, equipped, locked, canUpgrade, target })
	local socketBtn = function(size, position)
		return if equipped then React.createElement(Button, {
			text = "DETACH",
			icon = "Close.8",
			onClick = function()
				return dispatch("UnequipItem", {
					Target = item.equippedOn,
				})
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = size,
			position = position,
			reducedMotion = reducedMotion,
			outline = true,
		}) else React.createElement(Button, {
			text = "SOCKET",
			icon = "Loadout.3",
			onClick = function()
				if target ~= "" then
					dispatch("EquipItem", {
						Uid = item.uid,
						Target = target,
					})
				end
			end,
			color = Palette.mint,
			textColor = Palette.ink,
			size = size,
			position = position,
			reducedMotion = reducedMotion,
			disabled = target == "",
			highlight = target ~= "",
		})
	end
	local upgradeBtn = function(size, position)
		return React.createElement(Button, {
			text = if maxed then "MAXED" else `UPGRADE  {compactNumber(cost)}`,
			icon = "StarGrid.5",
			onClick = function()
				return dispatch("UpgradeItem", {
					Uid = item.uid,
				})
			end,
			color = if canUpgrade then Palette.mango else Palette.panelSoft,
			textColor = if canUpgrade then Palette.ink else Palette.muted,
			size = size,
			position = position,
			reducedMotion = reducedMotion,
			disabled = not canUpgrade,
			highlight = canUpgrade,
		})
	end
	-- salvaging destroys the relic, so it takes a second tap within a few seconds
	local salvageArmed = salvageArmedFor == item.uid
	local salvageBtn = function(size, position)
		return React.createElement(Button, {
			text = if salvageArmed then `TAP AGAIN TO SALVAGE · +{salvage}` else `SALVAGE  +{salvage}`,
			icon = "Dust.9",
			onClick = function()
				if not salvageArmed then
					setSalvageArmedFor(item.uid)
					return nil
				end
				setSalvageArmedFor(nil)
				return dispatch("SalvageItem", {
					Uid = item.uid,
				})
			end,
			color = if equipped or locked then Palette.panelSoft else Palette.coral,
			textColor = if equipped or locked then Palette.muted else Palette.ink,
			size = size,
			position = position,
			reducedMotion = reducedMotion,
			disabled = equipped or locked,
			outline = equipped or locked,
		})
	end
	local lockBtn = function(size, position)
		return React.createElement(Button, {
			text = if locked then "UNPROTECT" else "PROTECT",
			icon = "Lock.13",
			onClick = function()
				Audio:play(if locked then "favoriteOff" else "favoriteOn")
				return dispatch("ToggleItemLock", {
					Uid = item.uid,
				})
			end,
			color = if locked then Palette.mango else Palette.panelSoft,
			textColor = if locked then Palette.ink else Palette.creamSoft,
			size = size,
			position = position,
			reducedMotion = reducedMotion,
			outline = not locked,
		})
	end
	local _exp = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, INSPECT_BTN_GAP),
	})
	local _exp_1 = equipped and React.createElement(Text, {
		value = `Socketed on {InventoryMath.SocketLabel(item.equippedOn)}`,
		size = 13,
		color = Palette.mint,
		weight = Enum.FontWeight.Bold,
		fit = false,
		layoutOrder = 0,
		sizeConstraint = UDim2.new(1, 0, 0, 20),
	})
	local _condition_2 = not equipped and #targets > 0
	if _condition_2 then
		local _newValue_1 = table.create(#targets)
		local _callback_1 = function(entry, index)
			local active = entry.id == target
			local col = index % chipCols
			local row = math.floor(index / chipCols)
			return React.createElement("imagebutton", {
				key = entry.id,
				Size = UDim2.new(1 / chipCols, -6, 0, chipHeight),
				Position = UDim2.new(col / chipCols, 0, 0, row * chipStep),
				BackgroundColor3 = if active then accent else Palette.panelSoft,
				BackgroundTransparency = if active then 0.15 else 0.2,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Active = true,
				Selectable = true,
				Event = {
					Activated = function()
						setTarget(entry.id)
						Audio:play("tick")
					end,
					MouseEnter = function()
						return Audio:play("hover")
					end,
					SelectionGained = function()
						return Audio:play("hover")
					end,
				},
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 8),
			}), React.createElement("uistroke", {
				Color = if active then accent else Palette.lineSoft,
				Thickness = 1,
				Transparency = if active then 0.2 else 0.55,
			}), React.createElement(Text, {
				value = entry.label,
				size = 12,
				color = if active then contrastOn(accent) else Palette.cream,
				weight = Enum.FontWeight.Bold,
				align = Enum.TextXAlignment.Center,
				fit = false,
				position = UDim2.fromOffset(6, 0),
				sizeConstraint = UDim2.new(1, -12, 1, 0),
			}))
		end
		for _k, _v in targets do
			_newValue_1[_k] = _callback_1(_v, _k - 1, targets)
		end
		_condition_2 = React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, chipRows * chipStep),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 0,
		}, _newValue_1)
	end
	return React.createElement(Panel, {
		size = if fill then UDim2.fromScale(1, 1) else UDim2.new(1, 0, 0, detailH),
		accent = accent,
		background = Palette.panelRaised,
		padding = INSPECT_PAD,
		layoutOrder = layoutOrder,
		clips = false,
		zIndex = 20,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, _exp, _exp_1, _condition_2, not equipped and #targets == 0 and React.createElement(Text, {
		value = "Unlock a matching machine/research to socket this.",
		size = 12,
		color = Palette.mango,
		wrap = true,
		layoutOrder = 0,
		sizeConstraint = UDim2.new(1, 0, 0, 28),
	}), React.createElement("frame", {
		ref = inspectActionsHostRef,
		Name = "InspectClaimActions",
		Size = UDim2.new(1, 0, 0, actionsH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 2,
		ClipsDescendants = false,
	}, if stack then React.createElement(React.Fragment, nil, React.createElement("frame", {
		Name = "InspectSocketClaim",
		Size = actionSize,
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, socketBtn(UDim2.fromScale(1, 1), nil)), React.createElement("frame", {
		Name = "InspectUpgradeClaim",
		Size = actionSize,
		Position = UDim2.new(0.5, 5, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, upgradeBtn(UDim2.fromScale(1, 1), nil)), React.createElement("frame", {
		Name = "InspectProtect",
		Size = actionSize,
		Position = UDim2.fromOffset(0, ACTION_BTN + INSPECT_BTN_GAP),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, lockBtn(UDim2.fromScale(1, 1), nil)), React.createElement("frame", {
		Name = "InspectSalvage",
		Size = actionSize,
		Position = UDim2.new(0.5, 5, 0, ACTION_BTN + INSPECT_BTN_GAP),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, salvageBtn(UDim2.fromScale(1, 1), nil))) else React.createElement(React.Fragment, nil, React.createElement("frame", {
		Name = "InspectSocketClaim",
		Size = actionSize,
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, socketBtn(UDim2.fromScale(1, 1), nil)), React.createElement("frame", {
		Name = "InspectUpgradeClaim",
		Size = actionSize,
		Position = UDim2.new(0.25, 2, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, upgradeBtn(UDim2.fromScale(1, 1), nil)), React.createElement("frame", {
		Name = "InspectProtect",
		Size = actionSize,
		Position = UDim2.new(0.5, 4, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, lockBtn(UDim2.fromScale(1, 1), nil)), React.createElement("frame", {
		Name = "InspectSalvage",
		Size = actionSize,
		Position = UDim2.new(0.75, 6, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, salvageBtn(UDim2.fromScale(1, 1), nil)))), React.createElement(Text, {
		value = if equipped then "Detach before salvaging." elseif locked then "Protected relics cannot be salvaged." else `Essence bank: {compactNumber(essence)}`,
		size = 12,
		color = Palette.muted,
		fit = false,
		layoutOrder = 3,
		sizeConstraint = UDim2.new(1, 0, 0, INSPECT_FOOTER_H),
	})))
end
local function CrateCard(_param)
	local crate = _param.crate
	local keys = _param.keys
	local pity = _param.pity
	local onOpen = _param.onOpen
	local busy = _param.busy
	local reducedMotion = _param.reducedMotion
	local layoutOrder = _param.layoutOrder
	local stack = _param.stack
	local reveal = useStagger(layoutOrder, reducedMotion)
	local cardH = if stack then 248 else 160
	local actions = if stack then React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, TapTarget * 2 + 8),
		Position = UDim2.new(0, 0, 1, -(TapTarget * 2 + 14)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Button, {
		text = if busy then "…" else "OPEN 1",
		icon = "Crate.7",
		onClick = function()
			return onOpen(1)
		end,
		sound = "open",
		color = if keys >= 1 and not busy then crate.Color else Palette.panelSoft,
		textColor = if keys >= 1 and not busy then Palette.ink else Palette.muted,
		size = UDim2.new(1, 0, 0, TapTarget),
		reducedMotion = reducedMotion,
		disabled = keys < 1 or busy,
		highlight = keys >= 1 and not busy,
	}), React.createElement(Button, {
		text = if busy then "…" else "OPEN 5",
		icon = "Crate.8",
		onClick = function()
			return onOpen(5)
		end,
		sound = "open",
		color = if keys >= 5 and not busy then Palette.mango else Palette.panelSoft,
		textColor = if keys >= 5 and not busy then Palette.ink else Palette.muted,
		size = UDim2.new(1, 0, 0, TapTarget),
		reducedMotion = reducedMotion,
		disabled = keys < 5 or busy,
		highlight = keys >= 5 and not busy,
	})) else React.createElement("frame", {
		Size = UDim2.fromOffset(0, TapTarget),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Button, {
		text = if busy then "…" else "OPEN 1",
		icon = "Crate.9",
		onClick = function()
			return onOpen(1)
		end,
		sound = "open",
		color = if keys >= 1 and not busy then crate.Color else Palette.panelSoft,
		textColor = if keys >= 1 and not busy then Palette.ink else Palette.muted,
		size = UDim2.fromOffset(0, TapTarget),
		hug = true,
		reducedMotion = reducedMotion,
		disabled = keys < 1 or busy,
		highlight = keys >= 1 and not busy,
	}), React.createElement(Button, {
		text = if busy then "…" else "OPEN 5",
		icon = "Crate.10",
		onClick = function()
			return onOpen(5)
		end,
		sound = "open",
		color = if keys >= 5 and not busy then Palette.mango else Palette.panelSoft,
		textColor = if keys >= 5 and not busy then Palette.ink else Palette.muted,
		size = UDim2.fromOffset(0, TapTarget),
		hug = true,
		reducedMotion = reducedMotion,
		disabled = keys < 5 or busy,
		highlight = keys >= 5 and not busy,
	}))
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, cardH),
		accent = crate.Color,
		background = Palette.panelRaised,
		padding = if stack then 16 else 18,
		layoutOrder = layoutOrder,
		reveal = reveal,
		highlight = keys >= 1 and not busy,
		clips = false,
	}, React.createElement(IconTile, {
		kind = "Crate",
		accent = crate.Color,
		size = 48,
		radius = 12,
		position = UDim2.fromOffset(0, if stack then 8 else 24),
		reducedMotion = reducedMotion,
		glow = keys >= 1,
		filled = keys >= 1,
	}), React.createElement("frame", {
		Position = UDim2.fromOffset(60, 4),
		Size = UDim2.new(1, if stack then -(60 + 16) else -280, 0, 24),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}), React.createElement(Text, {
		value = crate.Name,
		size = 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 12,
		layoutOrder = 0,
		sizeConstraint = UDim2.new(0, 150, 0, 24),
	}), React.createElement(Badge, {
		value = if keys > 0 then `{keys} KEYS` else "NO KEYS",
		accent = if keys > 0 then crate.Color else Palette.muted,
		size = UDim2.fromOffset(64, 18),
		filled = keys > 0,
		layoutOrder = 1,
	})), React.createElement(Text, {
		value = crate.Description,
		size = 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(60, 32),
		sizeConstraint = UDim2.new(1, if stack then -(60 + 16) else -280, 0, 36),
	}), React.createElement(Text, {
		value = `Guaranteed {crate.PityRarity} at {crate.PityAfter} ({pity}/{crate.PityAfter})`,
		size = 11,
		color = crate.Color,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(60, 72),
		sizeConstraint = UDim2.new(1, if stack then -(60 + 16) else -280, 0, 16),
	}), React.createElement(Meter, {
		value = math.clamp(pity / math.max(1, crate.PityAfter), 0, 1),
		color = crate.Color,
		reducedMotion = reducedMotion,
		position = UDim2.fromOffset(60, 92),
		size = UDim2.new(1, if stack then -(60 + 16) else -280, 0, 4),
	}), actions)
end
local MARKET_BANNER_H = 126
local MARKET_CARD_H = 176
local MARKET_CARD_H_STACK = 210
local function MarketBanner(_param)
	local refreshText = _param.refreshText
	local reducedMotion = _param.reducedMotion
	local layoutOrder = _param.layoutOrder
	local stack = _param.stack
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, if stack then 132 else MARKET_BANNER_H),
		accent = Palette.mango,
		background = Palette.panelRaised,
		padding = if stack then 14 else 16,
		layoutOrder = layoutOrder,
		highlight = true,
		reducedMotion = reducedMotion,
		clips = false,
	}, React.createElement(IconTile, {
		kind = "Shop",
		accent = Palette.mango,
		size = if stack then 44 else 48,
		radius = 12,
		position = UDim2.fromOffset(0, if stack then 6 else 12),
		reducedMotion = reducedMotion,
	}), React.createElement(Text, {
		value = "MARKET DOCK",
		size = 10,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(if stack then 56 else 64, 0),
		sizeConstraint = UDim2.new(1, if stack then -(56 + 12) else -16, 0, 14),
	}), React.createElement(Text, {
		value = refreshText,
		size = if stack then 16 else 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(if stack then 56 else 64, 18),
		sizeConstraint = UDim2.new(1, if stack then -(56 + 12) else -16, 0, 24),
	}), React.createElement(Text, {
		value = "Daily keys restock at UTC midnight. Rarer offers restock a little at a time.",
		size = 11,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(if stack then 56 else 64, 48),
		sizeConstraint = UDim2.new(1, if stack then -(56 + 12) else -16, 0, if stack then 44 else 36),
	}), not stack and React.createElement(React.Fragment, nil, React.createElement(Badge, {
		value = "DAILY KEYS",
		accent = Palette.cyan,
		filled = true,
		position = UDim2.new(1, -208, 1, -30),
		size = UDim2.fromOffset(98, 24),
	}), React.createElement(Badge, {
		value = "LIVE STOCK",
		accent = Palette.violet,
		position = UDim2.new(1, -100, 1, -30),
		size = UDim2.fromOffset(92, 24),
	})), stack and React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0, 0, 1, -28),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Badge, {
		value = "DAILY KEYS",
		accent = Palette.cyan,
		filled = true,
		size = UDim2.fromOffset(98, 24),
	}), React.createElement(Badge, {
		value = "LIVE STOCK",
		accent = Palette.violet,
		size = UDim2.fromOffset(92, 24),
	})))
end
local function MarketCard(_param)
	local offer = _param.offer
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local layoutOrder = _param.layoutOrder
	local cash = _param.cash
	local stardust = _param.stardust
	local cores = _param.cores
	local refreshShort = _param.refreshShort
	local stack = _param.stack
	if stack == nil then
		stack = false
	end
	local balance = if offer.Currency == "Cash" then asFlux(cash) elseif offer.Currency == "Stardust" then stardust else cores
	local _binding = InventoryMath.OfferStock(offer)
	local stock = _binding.stock
	local stockMax = _binding.stockMax
	local soldOut = _binding.soldOut
	local daily = _binding.daily
	local canBuy = not soldOut and balance >= offer.Price
	local priceLabel = if offer.Price <= 0 then "FREE" else `{compactNumber(offer.Price)} {offer.Currency}`
	local accent = if soldOut then Palette.muted else offer.Color
	local stockBadge = if daily then (if soldOut then (if offer.Price <= 0 then "CLAIMED" else "BOUGHT") elseif stockMax > 1 then `DAILY {stock}/{stockMax}` else "DAILY") else (if soldOut then "SOLD OUT" else `STOCK {stock}`)
	local stockBadgeAccent = if soldOut then Palette.coral elseif daily then Palette.cyan else Palette.violet
	local statusLine = if daily then (if soldOut then (if offer.Price <= 0 then "Claimed today. The free key returns at restock." else "Bought today. Available again at restock.") else `Refreshes daily · {stock} of {stockMax} left`) else (if soldOut then "Sold out. More comes in at restock." else `Limited stock · {stock} of {stockMax} remaining`)
	local buttonText = if soldOut then (if daily then "WAIT FOR RESTOCK" else "SOLD OUT") else "BUY"
	local cardH = if stack then MARKET_CARD_H_STACK else MARKET_CARD_H
	local textReserve = if stack then -(56 + 16) else -240
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, cardH),
		accent = accent,
		background = if soldOut then Palette.panelSoft else Palette.panelRaised,
		padding = if stack then 16 else 18,
		layoutOrder = layoutOrder,
		clips = false,
		highlight = canBuy,
		reducedMotion = reducedMotion,
	}, React.createElement(IconTile, {
		kind = if offer.Kind == "Essence" then "Dust" elseif offer.Kind == "Key" then "Gift" else "Loadout",
		accent = accent,
		size = 44,
		radius = 11,
		position = UDim2.fromOffset(0, if stack then 8 else 32),
		reducedMotion = reducedMotion,
	}), React.createElement(Text, {
		value = offer.Name,
		size = 16,
		color = if soldOut then Palette.creamSoft else Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(56, 4),
		sizeConstraint = UDim2.new(1, if stack then -(56 + 16) else -260, 0, 22),
	}), if stack then React.createElement(Badge, {
		value = stockBadge,
		accent = stockBadgeAccent,
		filled = not soldOut,
		position = UDim2.fromOffset(56, 28),
		size = UDim2.fromOffset(140, 24),
	}) else React.createElement(Badge, {
		value = stockBadge,
		accent = stockBadgeAccent,
		filled = not soldOut,
		position = UDim2.new(1, -150, 0, 4),
		size = UDim2.fromOffset(140, 26),
	}), React.createElement(Text, {
		value = offer.Description,
		size = 11,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(56, if stack then 56 else 30),
		sizeConstraint = UDim2.new(1, textReserve, 0, 34),
	}), React.createElement(Text, {
		value = priceLabel,
		size = 13,
		color = if soldOut then Palette.muted else offer.Color,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(56, if stack then 94 else 70),
		sizeConstraint = UDim2.new(1, textReserve, 0, 18),
	}), React.createElement(Text, {
		value = statusLine,
		size = 10,
		color = if soldOut then Palette.coral else Palette.muted,
		weight = Enum.FontWeight.Bold,
		wrap = true,
		fit = false,
		position = UDim2.fromOffset(56, if stack then 114 else 94),
		sizeConstraint = UDim2.new(1, textReserve, 0, 28),
	}), soldOut and daily and refreshShort ~= nil and (React.createElement(Text, {
		value = refreshShort,
		size = 10,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(56, if stack then 142 else 124),
		sizeConstraint = UDim2.new(1, textReserve, 0, 14),
	})), if stack then React.createElement(Button, {
		text = buttonText,
		icon = if soldOut then "Lock.14" else "Shop.11",
		onClick = function()
			return dispatch("BuyItemOffer", {
				Id = offer.Id,
			})
		end,
		color = if canBuy then offer.Color else Palette.panelSoft,
		textColor = if canBuy then Palette.ink else Palette.muted,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -(TapTarget + 8)),
		reducedMotion = reducedMotion,
		disabled = not canBuy,
		highlight = canBuy,
	}) else React.createElement("frame", {
		Size = UDim2.fromOffset(0, 48),
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(Button, {
		text = buttonText,
		icon = if soldOut then "Lock.15" else "Shop.12",
		onClick = function()
			return dispatch("BuyItemOffer", {
				Id = offer.Id,
			})
		end,
		color = if canBuy then offer.Color else Palette.panelSoft,
		textColor = if canBuy then Palette.ink else Palette.muted,
		size = UDim2.fromOffset(0, 48),
		hug = true,
		reducedMotion = reducedMotion,
		disabled = not canBuy,
		highlight = canBuy,
	})))
end
local function LoadoutBoard(_param)
	local state = _param.state
	local config = _param.config
	local layoutOrder = _param.layoutOrder
	local stack = _param.stack
	local items = state.Items
	local _effects = items
	if _effects ~= nil then
		_effects = _effects.Effects
	end
	local effects = _effects
	local paletteById = {
		Production = Palette.green,
		Capacity = Palette.cyan,
		Tap = Palette.mango,
		Critical = Palette.pink,
		Automation = Palette.mint,
		Offline = Palette.violet,
	}
	local lines = {}
	for _, entry in InventoryMath.LoadoutEffectLines(effects) do
		table.insert(lines, {
			id = entry.id,
			label = entry.label,
			value = entry.value,
			color = paletteById[entry.id] or Palette.muted,
		})
	end
	local equipped = {}
	local byId = {}
	local _result_6 = config.Items
	if _result_6 ~= nil then
		_result_6 = _result_6.Definitions
	end
	local _condition_6 = _result_6
	if _condition_6 == nil then
		_condition_6 = {}
	end
	for _, definition in _condition_6 do
		local _id = definition.Id
		byId[_id] = definition
	end
	if items ~= nil then
		for target, uid in pairs(items.Equipped) do
			if not (type(uid) == "string") then
				continue
			end
			local instance = items.Inventory[uid]
			local _result_7
			if instance ~= nil then
				local _definitionId = instance.DefinitionId
				_result_7 = byId[_definitionId]
			else
				_result_7 = nil
			end
			local definition = _result_7
			if definition == nil then
				continue
			end
			local _arg0 = {
				target = target,
				name = `{definition.Name} LV{instance.Level}`,
				rarity = definition.Rarity,
			}
			table.insert(equipped, _arg0)
		end
	end
	local cols = if stack then 2 else 3
	local tileH = if stack then 58 else 54
	local tileGap = 8
	local gridH = math.ceil(#lines / cols) * (tileH + tileGap)
	local listH = 28 + math.max(1, #equipped) * 32
	local _exp = React.createElement(Text, {
		value = "ACTIVE BONUSES",
		size = 10,
		color = Palette.violet,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	})
	local _newValue_1 = table.create(#lines)
	local _callback_1 = function(line, index)
		local col = index % cols
		local row = math.floor(index / cols)
		return React.createElement("frame", {
			key = line.id,
			Size = UDim2.new(1 / cols, -tileGap, 0, tileH),
			Position = UDim2.new(col / cols, if col == 0 then 0 else tileGap / 2, 0, row * (tileH + tileGap)),
			BackgroundColor3 = Palette.panelSoft,
			BackgroundTransparency = 0.04,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 10),
		}), React.createElement("uistroke", {
			Color = if line.value > 0 then line.color else Palette.lineSoft,
			Transparency = 0.28,
			Thickness = 1.5,
		}), React.createElement(Text, {
			value = line.label,
			size = 10,
			color = Palette.creamSoft,
			weight = Enum.FontWeight.Bold,
			fit = false,
			position = UDim2.fromOffset(10, 8),
			sizeConstraint = UDim2.new(1, -20, 0, 14),
		}), React.createElement(Text, {
			value = `+{math.floor(line.value * 1000 + 0.5) / 10}%`,
			size = 16,
			color = if line.value > 0 then line.color else Palette.muted,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			position = UDim2.fromOffset(10, 24),
			sizeConstraint = UDim2.new(1, -20, 0, 22),
		}))
	end
	for _k, _v in lines do
		_newValue_1[_k] = _callback_1(_v, _k - 1, lines)
	end
	local _exp_1 = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, gridH),
		Position = UDim2.fromOffset(0, 22),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, _newValue_1)
	local _exp_2 = React.createElement(Text, {
		value = "SOCKETED RELICS",
		size = 10,
		color = Palette.mint,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 28 + gridH),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	})
	local _exp_3 = #equipped == 0 and React.createElement(Text, {
		value = "No relics socketed yet.",
		size = 12,
		color = Palette.muted,
		fit = false,
		position = UDim2.fromOffset(0, 48 + gridH),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	})
	local _newValue_2 = table.create(#equipped)
	local _callback_2 = function(entry, index)
		return React.createElement("frame", {
			key = entry.target,
			Size = UDim2.new(1, 0, 0, 28),
			Position = UDim2.fromOffset(0, 48 + gridH + index * 32),
			BackgroundColor3 = Palette.ink,
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 8),
		}), React.createElement(Text, {
			value = `{InventoryMath.SocketLabel(entry.target)}  ·  {entry.name}`,
			size = 12,
			color = InventoryMath.RarityColor(config, entry.rarity, Palette.muted),
			weight = Enum.FontWeight.Bold,
			fit = false,
			position = UDim2.fromOffset(10, 0),
			sizeConstraint = UDim2.new(1, -20, 1, 0),
		}))
	end
	for _k, _v in equipped do
		_newValue_2[_k] = _callback_2(_v, _k - 1, equipped)
	end
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, 40 + gridH + 22 + listH),
		accent = Palette.violet,
		background = Palette.panelRaised,
		padding = if stack then 14 else 18,
		layoutOrder = layoutOrder,
		clips = false,
		highlight = true,
	}, _exp, _exp_1, _exp_2, _exp_3, _newValue_2)
end
local function InventoryView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local crateRevealActive = _param.crateRevealActive
	if crateRevealActive == nil then
		crateRevealActive = false
	end
	local onCrateReveal = _param.onCrateReveal
	local openShop = _param.openShop
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local stack = chrome.contentStack
	local touchLayout = chrome.mobile
	local headerReveal = useStagger(0, softMotion)
	local tabsReveal = useStagger(1, softMotion)
	local inspectReveal = useStagger(2, softMotion)
	local bulkReveal = useStagger(3, softMotion)
	local inventorySoft = softMotion or tabsReveal == nil or inspectReveal == nil or bulkReveal == nil
	local tab, setTab = React.useState("Relics")
	local activeTabIndex = math.max(0, (table.find(TABS, tab) or 0) - 1)
	local paneTravel = useFlipperSpring(activeTabIndex, reducedMotion, 1540, 40)
	local panePosition = paneTravel:map(function(position)
		return UDim2.new(0, math.round(math.clamp(position - activeTabIndex, -1, 1) * 22), 0, 0)
	end)
	local filter, setFilter = React.useState("All")
	local sort, setSort = React.useState("Rarity")
	local rarity, setRarity = React.useState("Any")
	local search, setSearch = require(script.Parent.Parent.BrowseKit).useLinkedQuery("Inventory")
	local bulkMode, setBulkModeState = React.useState(false)
	local bulkSelected, setBulkSelected = React.useState({})
	local bulkBusy, setBulkBusy = React.useState(false)
	local autoOpen, setAutoOpen = React.useState(false)
	local autoBusy, setAutoBusy = React.useState(false)
	local autoDraft, setAutoDraft = React.useState()
	local selectedUid, setSelectedUid = React.useState(nil)
	local crateBusy, setCrateBusy = React.useState(false)
	local mountedRef = React.useRef(true)
	local crateAttemptRef = React.useRef(0)
	React.useEffect(function()
		return function()
			mountedRef.current = false
			crateAttemptRef.current += 1
		end
	end, {})
	local items = state.Items
	local _exp = function()
		return InventoryMath.CollectOwned(state, config)
	end
	local _exp_1 = config.Items
	local _result = items
	if _result ~= nil then
		_result = _result.Equipped
	end
	local _result_1 = items
	if _result_1 ~= nil then
		_result_1 = _result_1.Inventory
	end
	local owned = React.useMemo(_exp, { _exp_1, _result, _result_1 })
	local filtered = React.useMemo(function()
		return InventoryMath.SortOwned(InventoryMath.SearchOwned(InventoryMath.FilterOwned(owned, filter), search, rarity, require(script.Parent.Parent.BrowseKit).matches), config, sort)
	end, { config.Items, filter, owned, rarity, search, sort })
	local _callback_1 = function(entry)
		return entry.uid == selectedUid
	end
	local _result_2
	for _i, _v in filtered do
		if _callback_1(_v, _i - 1, filtered) == true then
			_result_2 = _v
			break
		end
	end
	local _condition = _result_2
	if _condition == nil then
		_condition = filtered[1]
	end
	local selected = _condition
	local relicListRef = React.useRef()
	local relicRowStride = InventoryMath.RelicRowHeight(stack) + ROW_GAP
	React.useEffect(function()
		if selected ~= nil and selected.uid ~= selectedUid then
			setSelectedUid(selected.uid)
		end
		if #filtered == 0 then
			setSelectedUid(nil)
		end
	end, { filtered, selected, selectedUid })
	local _exp_2 = function()
		local frame = relicListRef.current
		if frame == nil or selected == nil or bulkMode or tab ~= "Relics" then
			return nil
		end
		local selectedIndex = 0
		for index, item in filtered do
			if item.uid == selected.uid then
				selectedIndex = index - 1
				break
			end
		end
		local top = SCROLL_PAD + selectedIndex * relicRowStride
		local block = InventoryMath.RelicRowHeight(stack)
		local view = frame.AbsoluteWindowSize.Y
		if view <= 1 then
			return nil
		end
		local pos = frame.CanvasPosition.Y
		if top < pos + 8 then
			frame.CanvasPosition = Vector2.new(0, math.max(0, top - 8))
		elseif top + block > pos + view - 8 then
			frame.CanvasPosition = Vector2.new(0, math.max(0, top + block - view + 8))
		end
	end
	local _exp_3 = #filtered
	local _result_3 = selected
	if _result_3 ~= nil then
		_result_3 = _result_3.uid
	end
	React.useEffect(_exp_2, { bulkMode, filter, _exp_3, rarity, relicRowStride, search, _result_3, sort, stack, tab })
	local _exp_4 = function()
		local present = {}
		for _, item in owned do
			local _uid = item.uid
			present[_uid] = true
		end
		setBulkSelected(function(current)
			local _newValue_1 = {}
			local _callback_2 = function(uid)
				local _uid = uid
				return present[_uid] ~= nil
			end
			local _length = 0
			for _k, _v in current do
				if _callback_2(_v, _k - 1, current) == true then
					_length += 1
					_newValue_1[_length] = _v
				end
			end
			return _newValue_1
		end)
	end
	local _result_4 = items
	if _result_4 ~= nil then
		_result_4 = _result_4.Inventory
	end
	React.useEffect(_exp_4, { _result_4 })
	local filled = #owned
	local _result_5 = items
	if _result_5 ~= nil then
		_result_5 = _result_5.InventoryLimit
	end
	local _condition_1 = _result_5
	if _condition_1 == nil then
		local _result_6 = config.Items
		if _result_6 ~= nil then
			_result_6 = _result_6.InventoryLimit
		end
		_condition_1 = _result_6
		if _condition_1 == nil then
			_condition_1 = 100
		end
	end
	local limit = _condition_1
	local _result_6 = items
	if _result_6 ~= nil then
		_result_6 = _result_6.Essence
	end
	local _condition_2 = _result_6
	if _condition_2 == nil then
		_condition_2 = 0
	end
	local essence = _condition_2
	local heroH = if stack then HERO_H_STACK else HERO_H
	local pageGap = if stack then ROW_GAP else Layout.panelGap
	local toolPad = if stack then 8 else 12
	local toolGap = if stack then 8 else 10
	local tabH = if touchLayout then 54 else 56
	local fieldH = if stack then math.max(TapTarget, 52) else TOOL_FIELD_DESK
	local toolsH = if tab == "Relics" then toolPad * 2 + (if stack then 26 + toolGap else 0) + (if stack then fieldH * 2 + toolGap else fieldH) + toolGap + fieldH else 0
	local _exp_5 = function()
		return if selected ~= nil then InventoryMath.SocketTargets(state, config, selected.definition) else {}
	end
	local _result_7 = selected
	if _result_7 ~= nil then
		_result_7 = _result_7.uid
	end
	local targetsForSelected = React.useMemo(_exp_5, { config, _result_7, state.Machines, state.Research })
	local chipRows = if selected ~= nil and selected.equippedOn == nil and #targetsForSelected > 0
		then InventoryMath.ChipRows(#targetsForSelected, stack)
		else 0
	local inspectPanelH = if tab == "Relics" and selected ~= nil and not bulkMode then InventoryMath.InspectPanelHeight(InventoryMath.InspectSocketBlock(selected.equippedOn ~= nil, #targetsForSelected, chipRows, stack, TapTarget), stack) else 0
	local detailH = if inspectPanelH > 0 then inspectPanelH + ROW_GAP else 0
	local listH = math.max(1, #filtered) * relicRowStride
	local listStart = heroH + pageGap + tabH + pageGap + toolsH + detailH + SCROLL_EDGE
	local _result_8 = config.Items
	if _result_8 ~= nil then
		_result_8 = _result_8.Crates
	end
	local _condition_3 = _result_8
	if _condition_3 == nil then
		_condition_3 = {}
	end
	local crates = _condition_3
	local _result_9 = items
	if _result_9 ~= nil then
		_result_9 = _result_9.Shop
	end
	local _condition_4 = _result_9
	if _condition_4 == nil then
		_condition_4 = {}
	end
	local shopOffers = _condition_4
	local marketNow = useWallClock(tab == "Market")
	local _result_10 = items
	if _result_10 ~= nil then
		_result_10 = _result_10.ShopRefreshAt
	end
	local _condition_5 = _result_10
	if _condition_5 == nil then
		_condition_5 = 0
	end
	local shopRefreshAt = _condition_5
	local marketBannerH = if stack then 132 else MARKET_BANNER_H
	local keysRefreshText = marketNow:map(function(timestamp)
		local remaining = math.max(0, shopRefreshAt - timestamp)
		return if remaining > 0 then `Keys refresh in {InventoryMath.RestockClock(remaining)}` else "Keys refreshing now…"
	end)
	local refreshShort = marketNow:map(function(timestamp)
		local remaining = math.max(0, shopRefreshAt - timestamp)
		return if remaining > 0 then `Restock in {InventoryMath.RestockClock(remaining)}` else "Restocking…"
	end)
	local selectedForBulk = React.useMemo(function()
		local _newValue_1 = {}
		local _callback_2 = function(item)
			local _uid = item.uid
			local _condition_6 = (table.find(bulkSelected, _uid) or 0) - 1 >= 0
			if _condition_6 then
				_condition_6 = item.equippedOn == nil and item.instance.Locked ~= true
			end
			return _condition_6
		end
		local _length = 0
		for _k, _v in owned do
			if _callback_2(_v, _k - 1, owned) == true then
				_length += 1
				_newValue_1[_length] = _v
			end
		end
		return _newValue_1
	end, { bulkSelected, owned })
	local selectableVisible = React.useMemo(function()
		local _newValue_1 = {}
		local _callback_2 = function(item)
			return item.equippedOn == nil and item.instance.Locked ~= true
		end
		local _length = 0
		for _k, _v in filtered do
			if _callback_2(_v, _k - 1, filtered) == true then
				_length += 1
				_newValue_1[_length] = _v
			end
		end
		return _newValue_1
	end, { filtered })
	local selectionEssence = 0
	for _, item in selectedForBulk do
		selectionEssence += InventoryMath.SalvagePreview(config, item.definition, item.instance.Level)
	end
	local _result_11 = state.Shop
	if _result_11 ~= nil then
		_result_11 = _result_11.OwnedPasses.AutoSalvage
	end
	local passOwned = _result_11 == true
	local _result_12 = items
	if _result_12 ~= nil then
		_result_12 = _result_12.AutoSalvage
	end
	local _condition_6 = _result_12
	if _condition_6 == nil then
		_condition_6 = {
			Enabled = false,
			KeepNew = true,
			Rarities = {
				Common = true,
				Uncommon = true,
			},
		}
	end
	local serverAutoRules = _condition_6
	local autoRules = autoDraft or serverAutoRules
	local serverAutoSignature = InventoryMath.AutoSalvageSignature(serverAutoRules, AUTO_RARITIES)
	local draftAutoSignature = if autoDraft ~= nil then InventoryMath.AutoSalvageSignature(autoDraft, AUTO_RARITIES) else nil
	React.useEffect(function()
		if draftAutoSignature ~= nil and draftAutoSignature == serverAutoSignature then
			setAutoDraft(nil)
		end
	end, { draftAutoSignature, serverAutoSignature })
	local setBulkMode = function(value)
		setBulkModeState(value)
		if not value then
			setBulkSelected({})
		end
	end
	local toggleBulkItem = function(item)
		if item.equippedOn ~= nil or item.instance.Locked == true then
			Audio:play("error")
			return nil
		end
		setBulkSelected(function(current)
			local _current = current
			local _uid = item.uid
			local index = (table.find(_current, _uid) or 0) - 1
			if index >= 0 then
				local _newValue_1 = {}
				local _callback_2 = function(uid)
					return uid ~= item.uid
				end
				local _length = 0
				for _k, _v in current do
					if _callback_2(_v, _k - 1, current) == true then
						_length += 1
						_newValue_1[_length] = _v
					end
				end
				return _newValue_1
			end
			if #current >= 25 then
				return current
			end
			local _array = {}
			local _length = #_array
			local _currentLength = #current
			table.move(current, 1, _currentLength, _length + 1, _array)
			_length += _currentLength
			_array[_length + 1] = item.uid
			return _array
		end)
	end
	local selectVisible = function()
		local _newValue_1 = {}
		local _callback_2 = function(_, index)
			return index < 25
		end
		local _length = 0
		for _k, _v in selectableVisible do
			if _callback_2(_v, _k - 1, selectableVisible) == true then
				_length += 1
				_newValue_1[_length] = _v
			end
		end
		local _newValue_2 = table.create(#_newValue_1)
		local _callback_3 = function(item)
			return item.uid
		end
		for _k, _v in _newValue_1 do
			_newValue_2[_k] = _callback_3(_v, _k - 1, _newValue_1)
		end
		setBulkSelected(_newValue_2)
		Audio:play("filterPick")
	end
	local clearSelection = function()
		return setBulkSelected({})
	end
	local bulkArmed, setBulkArmed = React.useState(false)
	React.useEffect(function()
		if not bulkArmed then
			return nil
		end
		local lapse = task.delay(4, function()
			setBulkArmed(false)
		end)
		return function()
			pcall(task.cancel, lapse)
		end
	end, { bulkArmed, #selectedForBulk })
	local runAutoNow = function()
		if autoBusy or bulkBusy or not passOwned or not autoRules.Enabled then
			return nil
		end
		local uids = {}
		for _, item in owned do
			if item.equippedOn ~= nil or item.instance.Locked == true then
				continue
			end
			if autoRules.Rarities[item.definition.Rarity] ~= true then
				continue
			end
			local _uid = item.uid
			table.insert(uids, _uid)
			if #uids >= 25 then
				break
			end
		end
		if #uids == 0 then
			Audio:play("error")
			return nil
		end
		setBulkBusy(true)
		dispatch("BulkSalvageItems", {
			Uids = uids,
		}, function(response)
			if not mountedRef.current then
				return nil
			end
			setBulkBusy(false)
			if response.ok then
				Audio:play("reward")
			end
		end)
	end
	local salvageSelected = function()
		if #selectedForBulk == 0 or bulkBusy then
			return nil
		end
		-- first press arms (the button asks again), the second within 4 seconds salvages
		if not bulkArmed then
			setBulkArmed(true)
			return nil
		end
		setBulkArmed(false)
		setBulkBusy(true)
		local _object = {}
		local _left = "Uids"
		local _newValue_1 = table.create(#selectedForBulk)
		local _callback_2 = function(item)
			return item.uid
		end
		for _k, _v in selectedForBulk do
			_newValue_1[_k] = _callback_2(_v, _k - 1, selectedForBulk)
		end
		_object[_left] = _newValue_1
		dispatch("BulkSalvageItems", _object, function(response)
			if not mountedRef.current then
				return nil
			end
			setBulkBusy(false)
			if response.ok then
				setBulkSelected({})
				Audio:play("reward")
			end
		end)
	end
	local updateAutoRules = function(updatedRules)
		if autoBusy or not passOwned then
			return nil
		end
		local rarities = {}
		for _, entry in AUTO_RARITIES do
			if entry ~= "Any" and updatedRules.Rarities[entry] == true then
				table.insert(rarities, entry)
			end
		end
		if updatedRules.Enabled and #rarities == 0 then
			table.insert(rarities, "Common")
			table.insert(rarities, "Uncommon")
			local _object = table.clone(updatedRules)
			setmetatable(_object, nil)
			local _left = "Rarities"
			local _object_1 = table.clone(updatedRules.Rarities)
			setmetatable(_object_1, nil)
			_object_1.Common = true
			_object_1.Uncommon = true
			_object[_left] = _object_1
			updatedRules = _object
		end
		setAutoDraft(updatedRules)
		setAutoBusy(true)
		dispatch("SetItemAutoSalvage", {
			Enabled = updatedRules.Enabled,
			KeepNew = updatedRules.KeepNew,
			Rarities = rarities,
		}, function(response)
			if not mountedRef.current then
				return nil
			end
			setAutoBusy(false)
			if not response.ok then
				setAutoDraft(nil)
			else
				Audio:play("filterPick")
			end
		end)
	end
	local canvasHeight = listStart + scrollTail(chrome.stack, chrome.bottomSafe, SCROLL_PAD)
	if tab == "Relics" then
		canvasHeight = listStart + listH + scrollTail(chrome.stack, chrome.bottomSafe, SCROLL_PAD)
	elseif tab == "Crates" then
		canvasHeight = listStart + #crates * ((if stack then 248 else 160) + pageGap) + scrollTail(chrome.stack, chrome.bottomSafe, SCROLL_PAD)
	elseif tab == "Market" then
		local marketCardH = if stack then MARKET_CARD_H_STACK else MARKET_CARD_H
		canvasHeight = listStart + marketBannerH + pageGap + math.max(1, #shopOffers) * (marketCardH + pageGap) + scrollTail(chrome.stack, chrome.bottomSafe, SCROLL_PAD)
	else
		local equippedCount = 0
		if items ~= nil then
			for _, uid in pairs(items.Equipped) do
				if type(uid) == "string" and items.Inventory[uid] ~= nil then
					equippedCount += 1
				end
			end
		end
		local cols = if stack then 2 else 3
		local gridH = math.ceil(6 / cols) * (if stack then 66 else 62)
		canvasHeight = listStart + 54 + gridH + 18 + 28 + math.max(1, equippedCount) * 32 + scrollTail(chrome.stack, chrome.bottomSafe, SCROLL_PAD)
	end
	local paneHeight = math.max(1, canvasHeight - heroH - tabH - pageGap * 2)
	local openCrate = function(crate, count)
		if crateBusy or crateRevealActive then
			return nil
		end
		local attempt = crateAttemptRef.current + 1
		crateAttemptRef.current = attempt
		setCrateBusy(true)
		dispatch("OpenItemCrate", {
			Id = crate.Id,
			Count = count,
		}, function(response)
			if not mountedRef.current or crateAttemptRef.current ~= attempt then
				return nil
			end
			setCrateBusy(false)
			if not response.ok then
				return nil
			end
			local rolls = response.Rolls
			if rolls == nil or #rolls == 0 then
				return nil
			end
			onCrateReveal({
				crateId = crate.Id,
				crateName = crate.Name,
				accent = crate.Color,
				rolls = rolls,
			})
			setTab("Relics")
		end)
	end
	local tabsBar = React.createElement(SegmentedTabs, {
		options = TAB_OPTIONS,
		value = tab,
		onChange = function(entry)
			setTab(entry)
			if entry ~= "Relics" then
				setBulkMode(false)
				setAutoOpen(false)
			end
		end,
		accent = Palette.violet,
		columns = #TABS,
		gap = pageGap,
		size = UDim2.new(1, 0, 0, tabH),
		layoutOrder = 1,
		reducedMotion = softMotion,
	})
	local toolsBar = React.createElement(InventoryTools, {
		search = search,
		setSearch = setSearch,
		filter = filter,
		setFilter = setFilter,
		rarity = rarity,
		setRarity = setRarity,
		sort = sort,
		setSort = setSort,
		bulkMode = bulkMode,
		setBulkMode = setBulkMode,
		autoOpen = autoOpen,
		setAutoOpen = setAutoOpen,
		equipBest = function()
			return dispatch("EquipBestItems")
		end,
		reducedMotion = softMotion,
		stack = stack,
		filled = filled,
		limit = limit,
		essence = essence,
	})
	local heroPanel = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.violet,
		background = Palette.panelRaised,
		padding = if stack then 14 else 18,
		layoutOrder = 0,
		reveal = if reducedMotion then tabsReveal else headerReveal,
		highlight = not inventorySoft,
		reducedMotion = softMotion,
		clips = false,
	}, React.createElement(IconTile, {
		kind = "Loadout",
		accent = Palette.violet,
		size = if stack then 38 else 44,
		radius = 11,
		position = UDim2.fromOffset(0, if stack then 4 else 6),
		spin = false,
		reducedMotion = softMotion,
		glow = true,
	}), React.createElement(Text, {
		value = "INVENTORY",
		size = 12,
		color = Palette.violet,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(if stack then 50 else 56, 2),
		sizeConstraint = UDim2.new(1, if stack then -58 else -20, 0, 16),
	}), React.createElement(ShimmerText, {
		value = if tab == "Crates" then "Open crates for new relics" elseif tab == "Market" then "Crate keys and live stock" elseif tab == "Loadout" then "What your sockets add" else `{filled} of {limit} relics in your bag`,
		size = if stack then 18 else 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(if stack then 50 else 56, 20),
		sizeConstraint = UDim2.new(1, if stack then -58 else -20, 0, 26),
		enabled = not softMotion,
		periodSeconds = 4.8,
	}), React.createElement("frame", {
		-- the Relics toolbar already shows bag and essence; the hero only repeats them on other tabs
		Visible = tab ~= "Relics",
		Size = if stack then UDim2.new(1, 0, 0, 28) else UDim2.fromOffset(220, 30),
		Position = if stack then UDim2.new(0, 0, 1, -28) else UDim2.new(1, -220, 0.5, -15),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = if stack then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Badge, {
		value = `{filled} / {limit} BAG`,
		accent = Palette.violet,
		filled = true,
		size = UDim2.fromOffset(if stack then 108 else 118, 28),
	}), React.createElement(Badge, {
		value = `{compactNumber(essence)} ESS`,
		accent = Palette.mango,
		size = UDim2.fromOffset(if stack then 100 else 112, 28),
	})))
	if tab == "Relics" then
		local listPane = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		}, React.createElement(SectionLabel, {
			value = if bulkMode then "SELECT RELICS" else "RELIC BAY",
			color = if bulkMode then Palette.coral else Palette.violet,
		}), React.createElement(FlatList, {
			data = filtered,
			itemHeight = relicRowStride,
			headerHeight = SCROLL_PAD,
			overscan = if softMotion then 0 else (if antilag.tier <= 1 or antilag.constrained then 1 else 2),
			canvasTail = SCROLL_PAD,
			frameRef = relicListRef,
			Size = UDim2.new(1, 0, 1, -34),
			Position = UDim2.fromOffset(0, 34),
			scrollBarColor = Palette.violet,
			scrollBarThickness = 4,
			scrollBarTransparency = 0.22,
			keyExtractor = function(item)
				return item.uid
			end,
			renderItem = function(_param_1)
				local item = _param_1.item
				local _attributes = {
					item = item,
					config = config,
				}
				local _result_13 = selected
				if _result_13 ~= nil then
					_result_13 = _result_13.uid
				end
				_attributes.selected = _result_13 == item.uid
				local _uid = item.uid
				_attributes.bulkSelected = (table.find(bulkSelected, _uid) or 0) - 1 >= 0
				_attributes.bulkMode = bulkMode
				_attributes.onSelect = function()
					Audio:play("tick")
					if bulkMode then
						toggleBulkItem(item)
					else
						setSelectedUid(item.uid)
					end
				end
				_attributes.reducedMotion = softMotion
				_attributes.layoutOrder = 0
				_attributes.stack = stack
				return React.createElement(RelicRow, _attributes)
			end,
			ListEmptyComponent = React.createElement(EmptyState, {
				icon = "Loadout.4",
				title = if #owned == 0 then "No relics yet" else "Nothing matches",
				body = if #owned == 0 then ((config.ClientPageGuides and config.ClientPageGuides.Inventory and config.ClientPageGuides.Inventory.EmptyItems) or "Open crates or buy a starter coupler from the Market tab.") else "Clear the search or set the filters back to All relics.",
				accent = Palette.violet,
				layoutOrder = 0,
			}),
		}))
		local sections = {
			{
				id = "hero",
				height = heroH,
				element = heroPanel,
			},
			{
				id = "tabs",
				height = tabH,
				element = tabsBar,
			},
			{
				id = "tools",
				height = toolsH,
				element = toolsBar,
			},
		}
		if inspectPanelH > 0 and selected ~= nil then
			table.insert(sections, {
				id = "inspect",
				height = inspectPanelH,
				element = React.createElement(DetailPanel, {
					item = selected,
					state = state,
					config = config,
					dispatch = dispatch,
					reducedMotion = reducedMotion,
					layoutOrder = 0,
					stack = stack,
					fill = true,
				}),
			})
		end
		table.insert(sections, {
			id = "list",
			fill = true,
			minHeight = math.max(160, InventoryMath.RelicRowHeight(stack) + 48),
			element = listPane,
		})
		if bulkMode then
			table.insert(sections, {
				id = "bulk",
				height = BULK_DOCK_H,
				element = React.createElement(BulkDock, {
					selectedCount = #selectedForBulk,
					selectableCount = #selectableVisible,
					selectionEssence = selectionEssence,
					selectVisible = selectVisible,
					clearSelection = clearSelection,
					salvageSelected = salvageSelected,
		bulkArmed = bulkArmed,
					bulkBusy = bulkBusy,
					reducedMotion = reducedMotion,
				}),
			})
		end
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		}, React.createElement(PageScaffold, {
			gap = pageGap,
			tailPad = if stack then 10 else 14,
			scrollBarColor = Palette.violet,
			scrollBarThickness = 4,
			sections = sections,
		}), autoOpen and React.createElement(AutoSalvageSheet, {
			passOwned = passOwned,
			rules = autoRules,
			updateRules = updateAutoRules,
			autoBusy = autoBusy,
			openShop = openShop,
			runNow = runAutoNow,
			reducedMotion = reducedMotion,
			stack = stack,
			config = config,
			onClose = function()
				return setAutoOpen(false)
			end,
		}))
	end
	local sections = {
		{
			id = "hero",
			height = heroH,
			element = heroPanel,
		},
		{
			id = "tabs",
			height = tabH,
			element = tabsBar,
		},
	}
	if tab == "Crates" then
		local crateCardH = if stack then 248 else 160
		local crateStride = crateCardH + pageGap
		local crateLabelH = 28
		local crateList = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		}, React.createElement(FlatList, {
			data = crates,
			itemHeight = crateStride,
			headerHeight = crateLabelH + pageGap,
			overscan = if softMotion then 0 else (if antilag.tier <= 1 or antilag.constrained then 1 else 2),
			canvasTail = SCROLL_PAD,
			Size = UDim2.fromScale(1, 1),
			scrollBarColor = Palette.violet,
			scrollBarThickness = 4,
			scrollBarTransparency = 0.22,
			keyExtractor = function(crate)
				return crate.Id
			end,
			renderItem = function(_param_1)
				local crate = _param_1.item
				local keysTable = if items ~= nil then items.Keys else nil
				local pityTable = if items ~= nil then items.Pity else nil
				local keyCount = if type(keysTable) == "table" then keysTable[crate.Id] else nil
				local pityCount = if type(pityTable) == "table" then pityTable[crate.Id] else nil
				return React.createElement(CrateCard, {
					crate = crate,
					keys = if type(keyCount) == "number" then keyCount else 0,
					pity = if type(pityCount) == "number" then pityCount else 0,
					onOpen = function(count)
						return openCrate(crate, count)
					end,
					busy = crateBusy,
					reducedMotion = reducedMotion,
					layoutOrder = 0,
					stack = stack,
				})
			end,
			ListHeaderComponent = React.createElement(SectionLabel, {
				value = "CRATE CHANNELS",
				color = Palette.violet,
				layoutOrder = 0,
			}),
			ListEmptyComponent = React.createElement(EmptyState, {
				icon = "Crate.11",
				title = "No crate channels",
				body = "More crate channels open as you progress through the story and the Lab.",
				accent = Palette.violet,
				layoutOrder = 0,
				reducedMotion = reducedMotion,
			}),
		}))
		table.insert(sections, {
			id = "crates",
			fill = true,
			minHeight = math.max(160, crateLabelH + crateCardH + pageGap * 2),
			element = crateList,
		})
	elseif tab == "Market" then
		local marketCardH = if stack then MARKET_CARD_H_STACK else MARKET_CARD_H
		local marketStride = marketCardH + pageGap
		local marketList = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		}, React.createElement(FlatList, {
			data = shopOffers,
			itemHeight = marketStride,
			headerHeight = marketBannerH + pageGap,
			overscan = if softMotion then 0 else (if antilag.tier <= 1 or antilag.constrained then 1 else 2),
			canvasTail = SCROLL_PAD,
			Size = UDim2.fromScale(1, 1),
			scrollBarColor = Palette.mango,
			scrollBarThickness = 4,
			scrollBarTransparency = 0.22,
			keyExtractor = function(offer)
				return offer.Id
			end,
			renderItem = function(_param_1)
				local offer = _param_1.item
				return React.createElement(MarketCard, {
					offer = offer,
					dispatch = dispatch,
					reducedMotion = reducedMotion,
					layoutOrder = 0,
					cash = state.Cash,
					stardust = state.Stardust,
					cores = state.Cores,
					refreshShort = refreshShort,
					stack = stack,
				})
			end,
			ListHeaderComponent = React.createElement(MarketBanner, {
				refreshText = keysRefreshText,
				reducedMotion = reducedMotion,
				layoutOrder = 0,
				stack = stack,
			}),
			ListEmptyComponent = React.createElement(EmptyState, {
				icon = "Shop.13",
				title = "Market offline",
				body = ((config.ClientPageGuides and config.ClientPageGuides.Inventory and config.ClientPageGuides.Inventory.EmptyMarket) or "No dock offers right now. More arrive at the next restock."),
				accent = Palette.mango,
				layoutOrder = 0,
				reducedMotion = reducedMotion,
			}),
		}))
		table.insert(sections, {
			id = "market",
			fill = true,
			minHeight = math.max(160, marketBannerH + marketCardH + pageGap * 2),
			element = marketList,
		})
	else
		local equippedCount = 0
		if items ~= nil then
			for _, uid in pairs(items.Equipped) do
				if type(uid) == "string" and items.Inventory[uid] ~= nil then
					equippedCount += 1
				end
			end
		end
		local cols = if stack then 2 else 3
		local tileH = if stack then 58 else 54
		local tileGap = 8
		local gridH = math.ceil(6 / cols) * (tileH + tileGap)
		local loadoutH = 40 + gridH + 22 + 28 + math.max(1, equippedCount) * 32
		table.insert(sections, {
			id = "loadout-label",
			height = 28,
			element = React.createElement(SectionLabel, {
				value = "SOCKET SUMMARY",
				color = Palette.mint,
				layoutOrder = 0,
			}),
		})
		table.insert(sections, {
			id = "loadout",
			height = loadoutH,
			element = React.createElement(LoadoutBoard, {
				state = state,
				config = config,
				reducedMotion = reducedMotion,
				layoutOrder = 0,
				stack = stack,
			}),
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(PageScaffold, {
		gap = pageGap,
		tailPad = if stack then 10 else 14,
		scrollBarColor = if tab == "Market" then Palette.mango else Palette.violet,
		scrollBarThickness = 4,
		sections = sections,
	}))
end
return {
	InventoryView = InventoryView,
}
end

local __members = {}
for name in __defs do
	table.insert(__members, name)
end
table.sort(__members)
table.freeze(__members)
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		if name == "__members" then
			return __members
		end
		return __load(name)
	end,
})

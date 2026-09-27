local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local GamepadNavigationService = require(script.Parent.input.GamepadNavigationService)
local Audio = require(script.Parent.audio).Audio
local useAntilag = require(script.Parent.antilag).useAntilag
local _motion = require(script.Parent.motion)
local composePresence = _motion.composePresence
local ScaleFromCenter = _motion.ScaleFromCenter
local useEntrance = _motion.useEntrance
local useExitTransition = _motion.useExitTransition
local useViewport = _motion.useViewport
local _theme = require(script.Parent.theme)
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local _ui = require(script.Parent.ui)
local Button = _ui.Button
local OverlayPresence = _ui.OverlayPresence
local Text = _ui.Text
local useGamepadAutofocus = _ui.useGamepadAutofocus
local compactNumber = require(script.Parent.format).compactNumber

-- The Forge Level roadmap: the whole progression ladder on one screen, laid
-- out as a timeline. A rail runs down the left edge and fills up to the
-- player's level; each level is one quiet row -- its goal, and what it opens.
--
-- Visual rules (kept deliberately plain):
--   * Type does the work: goal text is the primary line, everything else is
--     secondary and muted. No pills, badges, icons, glows or outlines.
--   * The tier colour appears in exactly three places: the tier name, the
--     player's own node on the rail, and progress fills.
--   * One spacing unit (4px) and one left edge for all text.
--
-- The ladder comes from ForgeLevels (shared, via config.Levels); the player's
-- level and next-goal progress come from the server snapshot (state.Level).

local UNIT = 4
local ROW_H = 54
local TIER_H = 44
local RAIL_X = 14
local TEXT_X = 40

-- The ladder warms as it climbs.
local TIER_ACCENT_KEYS = {
	Beginner = "mint",
	Apprentice = "cyan",
	Journeyman = "blue",
	Expert = "violet",
	Master = "mango",
	Legend = "pink",
}

local function tierAccent(tier)
	local key = if type(tier) == "string" then TIER_ACCENT_KEYS[tier] else nil
	return if key ~= nil then Palette[key] else Palette.cyan
end

-- Display names for feature ids, from the live unlock states.
local function featureNames(state, ids)
	local names = {}
	if type(ids) ~= "table" then
		return names
	end
	local unlocks = if state ~= nil then state.FeatureUnlocks else nil
	for _, id in ids do
		local row = if type(unlocks) == "table" then unlocks[id] else nil
		table.insert(names, if type(row) == "table" and type(row.Name) == "string" then row.Name else tostring(id))
	end
	return names
end

-- "Missions, Leaderboards and Guild".
local function joinNames(names)
	local count = #names
	if count == 0 then
		return ""
	elseif count == 1 then
		return names[1]
	end
	return table.concat(names, ", ", 1, count - 1) .. " and " .. names[count]
end

-- The player's level state, tolerant of a snapshot from before levels existed.
local function readLevelState(state)
	local levelState = if state ~= nil then state.Level else nil
	if type(levelState) ~= "table" then
		return 1, "Beginner", nil
	end
	local level = if type(levelState.Level) == "number" then math.max(1, math.floor(levelState.Level)) else 1
	local tier = if type(levelState.Tier) == "string" then levelState.Tier else "Beginner"
	local nextStep = if type(levelState.Next) == "table" then levelState.Next else nil
	return level, tier, nextStep
end

local function progressText(nextStep)
	return `{compactNumber(nextStep.Progress)} / {compactNumber(nextStep.Target)}`
end

local function progressFraction(nextStep)
	if nextStep == nil then
		return 1
	end
	return math.clamp((tonumber(nextStep.Progress) or 0) / math.max(1, tonumber(nextStep.Target) or 1), 0, 1)
end

-- A thin progress track: a hairline of the line colour with the filled part in
-- the tier colour. Used in the header and on the next level's row.
local function Track(props)
	return React.createElement("frame", {
		Size = props.size,
		Position = props.position,
		BackgroundColor3 = Palette.line,
		BorderSizePixel = 0,
		ZIndex = props.zIndex,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = UDim2.fromScale(math.clamp(props.value, 0, 1), 1),
		BackgroundColor3 = props.color,
		BorderSizePixel = 0,
		ZIndex = props.zIndex,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end

local function TierHeading(_param)
	return React.createElement("frame", {
		Size = UDim2.new(1, -UNIT * 2, 0, TIER_H),
		Position = UDim2.fromOffset(0, _param.y),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 476,
	}, React.createElement(Text, {
		value = string.upper(_param.tier),
		size = 11,
		color = tierAccent(_param.tier),
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(TEXT_X, 12),
		sizeConstraint = UDim2.new(1, -TEXT_X, 0, 14),
		zIndex = 477,
	}), _param.blurb ~= "" and React.createElement(Text, {
		value = _param.blurb,
		size = 11,
		color = Palette.muted,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(TEXT_X, 27),
		sizeConstraint = UDim2.new(1, -TEXT_X, 0, 14),
		zIndex = 477,
	}))
end

-- The node where a row meets the rail.
local function RailNode(_param)
	local status = _param.status
	local accent = _param.accent
	local here = status == "here"
	local reached = status == "done" or here
	local size = if here then 12 else 8
	return React.createElement("frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(RAIL_X, _param.centerY),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = if here then accent elseif reached then Palette.creamSoft else Palette.panelRaised,
		BorderSizePixel = 0,
		ZIndex = 478,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), not reached and React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = if status == "next" then Palette.creamSoft else Palette.lineSoft,
		Thickness = 1.5,
	}))
end

local function LevelRow(_param)
	local def = _param.def
	local status = _param.status
	local nextStep = _param.nextStep
	local y = _param.y
	local accent = _param.accent
	local here = status == "here"
	local isNext = status == "next"
	local ahead = status == "ahead"
	local rightW = _param.rightW
	local goalText = if def.Goal ~= nil and type(def.Goal.Text) == "string" then def.Goal.Text else "Where every forge starts"
	local detail = if _param.opens ~= "" then `Level {def.Level} · Opens {_param.opens}` else `Level {def.Level}`
	local rightText = if here then "Current" elseif isNext and nextStep ~= nil then progressText(nextStep) else ""
	return React.createElement("frame", {
		Size = UDim2.new(1, -UNIT * 2, 0, ROW_H),
		Position = UDim2.fromOffset(0, y),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 476,
	}, React.createElement(RailNode, {
		status = status,
		accent = accent,
		centerY = 17,
	}), React.createElement(Text, {
		value = goalText,
		size = 14,
		color = if ahead then Palette.creamSoft else Palette.cream,
		weight = if here or isNext then Enum.FontWeight.Bold else Enum.FontWeight.Medium,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(TEXT_X, 8),
		sizeConstraint = UDim2.new(1, -(TEXT_X + rightW + UNIT * 3), 0, 18),
		zIndex = 477,
	}), React.createElement(Text, {
		value = detail,
		size = 11,
		color = Palette.muted,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(TEXT_X, 28),
		sizeConstraint = UDim2.new(1, -(TEXT_X + rightW + UNIT * 3), 0, 14),
		zIndex = 477,
	}), rightText ~= "" and React.createElement(Text, {
		value = rightText,
		size = 11,
		color = if here then accent else Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Right,
		fit = true,
		minSize = 9,
		position = UDim2.new(1, -rightW, 0, 9),
		sizeConstraint = UDim2.fromOffset(rightW, 14),
		zIndex = 477,
	}), isNext and nextStep ~= nil and React.createElement(Track, {
		value = progressFraction(nextStep),
		color = accent,
		size = UDim2.fromOffset(rightW, 3),
		position = UDim2.new(1, -rightW, 0, 30),
		zIndex = 477,
	}))
end

local function LevelRoadmap(_param)
	local state = _param.state
	local config = _param.config
	local onClose = _param.onClose
	local reducedMotion = _param.reducedMotion
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — LevelRoadmap.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local compact = chrome.stack or viewport.width < 620 or viewport.height < 560

	local level, tier, nextStep = readLevelState(state)
	local ladder = if config ~= nil and type(config.Levels) == "table" then config.Levels else {}
	local blurbs = if config ~= nil and type(config.LevelTierBlurbs) == "table" then config.LevelTierBlurbs else {}
	local maxLevel = #ladder
	local accent = tierAccent(tier)

	React.useEffect(function()
		Audio:play("modalOpen")
	end, {})
	local enter = useEntrance(softMotion)
	local _binding = useExitTransition(softMotion)
	local leave = _binding[1]
	local closing = _binding[2]
	local beginExit = _binding[3]
	local motion = composePresence(enter, leave)
	local close = React.useCallback(function()
		if closing then
			return nil
		end
		Audio:play("close")
		beginExit(onClose)
		return nil
	end, { beginExit, closing, onClose })
	React.useEffect(function()
		local actionName = "AstralForgeLevelRoadmapClose"
		ContextActionService:BindActionAtPriority(actionName, function(_name, inputState)
			if inputState == Enum.UserInputState.Begin then
				close()
			end
			return Enum.ContextActionResult.Sink
		end, false, 2400, Enum.KeyCode.ButtonB)
		return function()
			return ContextActionService:UnbindAction(actionName)
		end
	end, { close })
	local padFocus = useGamepadAutofocus(true)
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
		local host = padFocus.current
		if host == nil then
			return nil
		end
		local job = task.defer(function()
			if host.Parent == nil then
				return
			end
			GamepadNavigationService.FocusClaim(host)
		end)
		return function()
			task.cancel(job)
		end
	end, {})

	local side = chrome.sideSafe + UNIT * 4
	local width = math.min(viewport.width - side * 2, 600)
	local safeHeight = math.max(1, viewport.height - viewport.topInset - chrome.bottomSafe - UNIT * 4)
	local height = math.min(if compact then 580 else 640, safeHeight)
	local pad = if compact then UNIT * 4 else UNIT * 6
	local headerH = if nextStep ~= nil then 132 else 104
	local listTop = headerH + UNIT * 3
	local listH = math.max(60, height - pad * 2 - listTop)
	local rightW = if compact then 64 else 88

	-- Lay the ladder out top to bottom, a heading at the start of each tier.
	local rows = {}
	local y = 0
	local focusY = 0
	local firstNodeY: number? = nil
	local lastNodeY = 0
	local reachedNodeY = 0
	local lastTier = nil
	for _, def in ladder do
		if def.Tier ~= lastTier then
			lastTier = def.Tier
			rows[`Tier_{def.Tier}`] = React.createElement(TierHeading, {
				tier = def.Tier,
				blurb = blurbs[def.Tier] or "",
				y = y,
			})
			y += TIER_H
		end
		local nodeY = y + 17
		if firstNodeY == nil then
			firstNodeY = nodeY
		end
		lastNodeY = nodeY
		if def.Level <= level then
			reachedNodeY = nodeY
		end
		if def.Level == level then
			focusY = y
		end
		local status = if def.Level < level then "done" elseif def.Level == level then "here" elseif def.Level == level + 1 then "next" else "ahead"
		rows[`Level_{def.Level}`] = React.createElement(LevelRow, {
			def = def,
			status = status,
			opens = joinNames(featureNames(state, def.Unlocks)),
			nextStep = if status == "next" then nextStep else nil,
			accent = accent,
			rightW = rightW,
			y = y,
		})
		y += ROW_H
	end
	local canvasH = y + UNIT * 2
	local railTop = firstNodeY or 0
	-- The rail: the whole ladder in the line colour, filled to the player's node.
	rows.Rail = React.createElement("frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(RAIL_X, railTop),
		Size = UDim2.fromOffset(2, math.max(0, lastNodeY - railTop)),
		BackgroundColor3 = Palette.line,
		BorderSizePixel = 0,
		ZIndex = 476,
	})
	rows.RailFill = React.createElement("frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(RAIL_X, railTop),
		Size = UDim2.fromOffset(2, math.max(0, reachedNodeY - railTop)),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = 477,
	})

	-- Open scrolled to the player's own level, with a little of what's behind.
	local listRef = React.useRef(nil)
	React.useEffect(function()
		local list = listRef.current
		if list == nil then
			return nil
		end
		list.CanvasPosition = Vector2.new(0, math.max(0, math.min(focusY - TIER_H, canvasH - listH)))
		return nil
	end, {})

	local cardPosition = motion:map(function(amount)
		return UDim2.new(0.5, 0, 0.5, math.round((1 - amount) * 12))
	end)
	local cardScale = motion:map(function(amount)
		return 0.96 + amount * 0.04
	end)
	local fade = motion:map(function(amount)
		return 1 - amount
	end)
	local opensNext = if nextStep ~= nil then joinNames(featureNames(state, nextStep.Unlocks)) else ""

	return React.createElement(OverlayPresence, {
		amount = motion,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 470,
		Visible = motion:map(function(amount)
			return amount > 0.003
		end),
	}, React.createElement("imagebutton", {
		-- Scrim: tapping outside the card closes the roadmap.
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = motion:map(function(amount)
			return 1 - amount * 0.6
		end),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 470,
		Event = {
			Activated = function()
				close()
			end,
		},
	}), React.createElement("frame", {
		ref = function(node)
			padFocus.current = node
		end,
		Size = UDim2.fromOffset(width, height),
		Position = cardPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 471,
		Visible = motion:map(function(amount)
			return amount > 0.002
		end),
	}, React.createElement(ScaleFromCenter, {
		scale = cardScale,
		zIndex = 471,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panelRaised,
		BackgroundTransparency = fade,
		BorderSizePixel = 0,
		ZIndex = 472,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 16),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.35,
	})), React.createElement("frame", {
		Size = UDim2.new(1, -pad * 2, 1, -pad * 2),
		Position = UDim2.fromOffset(pad, pad),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 473,
	}, React.createElement(Text, {
		value = "Forge Level",
		size = 12,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(0, 0),
		sizeConstraint = UDim2.new(1, -(TapTarget + UNIT * 3), 0, 16),
		zIndex = 474,
	}), React.createElement(Text, {
		value = `Level {level}`,
		size = if compact then 24 else 28,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 18,
		position = UDim2.fromOffset(0, 18),
		sizeConstraint = UDim2.fromOffset(if compact then 112 else 128, 34),
		zIndex = 474,
	}), React.createElement(Text, {
		value = `{tier}  ·  {level} of {maxLevel}`,
		size = 13,
		color = accent,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(if compact then 116 else 134, 28),
		sizeConstraint = UDim2.new(1, -((if compact then 116 else 134) + TapTarget + UNIT * 3), 0, 18),
		zIndex = 474,
	}), React.createElement(Button, {
		text = "",
		icon = "Close",
		onClick = close,
		color = Palette.panel,
		textColor = Palette.creamSoft,
		size = UDim2.fromOffset(TapTarget, TapTarget),
		position = UDim2.new(1, -TapTarget, 0, 0),
		reducedMotion = softMotion,
		disabled = closing,
	}), nextStep ~= nil and React.createElement(Text, {
		value = nextStep.Text,
		size = 14,
		color = Palette.cream,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(0, 66),
		sizeConstraint = UDim2.new(1, -96, 0, 18),
		zIndex = 474,
	}), nextStep ~= nil and React.createElement(Text, {
		value = progressText(nextStep),
		size = 12,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Right,
		fit = true,
		minSize = 9,
		position = UDim2.new(1, -92, 0, 67),
		sizeConstraint = UDim2.fromOffset(92, 16),
		zIndex = 474,
	}), React.createElement(Track, {
		value = progressFraction(nextStep),
		color = accent,
		size = UDim2.new(1, 0, 0, 4),
		position = UDim2.fromOffset(0, if nextStep ~= nil then 92 else 66),
		zIndex = 474,
	}), nextStep ~= nil and React.createElement(Text, {
		value = if opensNext ~= "" then `Level {nextStep.Level} opens {opensNext}` else `Next: Level {nextStep.Level}`,
		size = 12,
		color = Palette.muted,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(0, 104),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
		zIndex = 474,
	}), nextStep == nil and React.createElement(Text, {
		value = "Every level reached. This is the top of the forge.",
		size = 12,
		color = Palette.muted,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(0, 76),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
		zIndex = 474,
	}), React.createElement("frame", {
		-- Hairline between the header and the ladder.
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.fromOffset(0, headerH),
		BackgroundColor3 = Palette.lineSoft,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 474,
	}), React.createElement("scrollingframe", {
		ref = listRef,
		Size = UDim2.new(1, 0, 0, listH),
		Position = UDim2.fromOffset(0, listTop),
		CanvasSize = UDim2.fromOffset(0, canvasH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Palette.lineSoft,
		ScrollBarImageTransparency = 0.2,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ClipsDescendants = true,
		Active = true,
		Selectable = false,
		ZIndex = 475,
	}, rows))))))
end

-- Open state lives here rather than in the app shell. The shell's main
-- component sits near Luau's 200-local limit (Studio compiles at O0 when the
-- debugger is on, where every local counts), and the level bar that opens the
-- roadmap lives deep inside the workspace. A tiny store both sides can reach
-- keeps the shell at zero new locals and avoids threading a prop through.
local openListeners: { [(boolean) -> ()]: boolean } = {}
local roadmapOpen = false

local function setRoadmapOpen(value: boolean)
	if roadmapOpen == value then
		return
	end
	roadmapOpen = value
	for listener in openListeners do
		listener(value)
	end
end

local function openRoadmap()
	setRoadmapOpen(true)
end

-- Mounted once by the app shell; renders the roadmap while it is open.
local function LevelRoadmapHost(_param)
	local open, setOpen = React.useState(roadmapOpen)
	React.useEffect(function()
		local listener = function(value: boolean)
			setOpen(value)
		end
		openListeners[listener] = true
		setOpen(roadmapOpen)
		return function()
			openListeners[listener] = nil
		end
	end, {})
	if not open then
		return nil
	end
	return React.createElement(LevelRoadmap, {
		state = _param.state,
		config = _param.config,
		reducedMotion = _param.reducedMotion,
		onClose = function()
			setRoadmapOpen(false)
		end,
	})
end

return {
	LevelRoadmap = LevelRoadmap,
	LevelRoadmapHost = LevelRoadmapHost,
	openRoadmap = openRoadmap,
	tierAccent = tierAccent,
	featureNames = featureNames,
	readLevelState = readLevelState,
	joinNames = joinNames,
	progressFraction = progressFraction,
}

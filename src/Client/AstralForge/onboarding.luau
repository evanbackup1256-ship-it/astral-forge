local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local GamepadNavigationService = require(script.Parent.input.GamepadNavigationService)
local Audio = require(script.Parent.audio).Audio
local _motion = require(script.Parent.motion)
local composePresence = _motion.composePresence
local useEntrance = _motion.useEntrance
local useExitTransition = _motion.useExitTransition
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.theme)
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local _ui = require(script.Parent.ui)
local Badge = _ui.Badge
local Button = _ui.Button
local Meter = _ui.Meter
local OverlayPresence = _ui.OverlayPresence
local Panel = _ui.Panel
local Text = _ui.Text
local useGamepadAutofocus = _ui.useGamepadAutofocus
local function TutorialOverlay(_param)
	local copy = _param.copy
	local step = _param.step
	local count = _param.count
	local viewportWidth = _param.viewportWidth
	local reducedMotion = _param.reducedMotion
	local ctaLabel = _param.ctaLabel
	local onCta = _param.onCta
	local onNext = _param.onNext
	local onBack = _param.onBack
	local onSkip = _param.onSkip
	local onJump = _param.onJump
	local viewport = useViewport()
	React.useEffect(function()
		Audio:play("modalOpen")
	end, {})
	React.useEffect(function()
		if step > 1 then
			Audio:play("tutorialStep")
		end
	end, { step })
	local sideInset = math.max(10, viewport.sideInset)
	local bottomInset = math.max(12, viewport.bottomInset)
	local phone = viewport.width < 720 or viewport.height < 560
	local enter = useEntrance(reducedMotion)
	local _binding = useExitTransition(reducedMotion)
	local exit = _binding[1]
	local exiting = _binding[2]
	local beginExit = _binding[3]
	local reveal = composePresence(enter, exit)
	local dockW = math.min(if phone then viewportWidth - sideInset * 2 else 560, viewportWidth - sideInset * 2)
	local hasCta = ctaLabel ~= nil and onCta ~= nil
	local hasGoal = copy.goal ~= nil and copy.goal ~= ""
	local hasHint = copy.hint ~= nil and copy.hint ~= ""
	local hasControls = copy.controls ~= nil and copy.controls ~= ""
	local dockH = (if phone then 178 else 164) + (if hasGoal then 18 else 0) + (if hasHint then 18 else 0) + (if hasControls then 16 else 0) + (if hasCta then TapTarget + 8 else 0)
	local nextLabel = if step >= count then "FINISH" else "CONTINUE"
	local requestNext = React.useCallback(function()
		if exiting then
			return nil
		end
		if step >= count then
			beginExit(onNext)
		else
			onNext()
		end
	end, { beginExit, count, exiting, onNext, step })
	local requestSkip = React.useCallback(function()
		if not exiting then
			beginExit(onSkip)
		end
	end, { beginExit, exiting, onSkip })
	React.useEffect(function()
		local actionName = "AstralForgeTutorialBack"
		ContextActionService:BindActionAtPriority(actionName, function(_name, inputState)
			if inputState == Enum.UserInputState.Begin and step > 1 and not exiting then
				onBack()
			end
			return Enum.ContextActionResult.Sink
		end, false, 2300, Enum.KeyCode.ButtonB)
		return function()
			return ContextActionService:UnbindAction(actionName)
		end
	end, { exiting, onBack, step })
	React.useEffect(function()
		local actionName = "AstralForgeTutorialConfirm"
		ContextActionService:BindActionAtPriority(actionName, function(_name, inputState)
			if inputState == Enum.UserInputState.Begin and not exiting then
				if hasCta and onCta ~= nil then
					onCta()
				else
					requestNext()
				end
			end
			return Enum.ContextActionResult.Sink
		end, false, 2300, Enum.KeyCode.ButtonA)
		return function()
			return ContextActionService:UnbindAction(actionName)
		end
	end, { exiting, hasCta, onCta, requestNext })
	local bodyTop = if hasGoal then 72 else 54
	local hintTop = bodyTop + (if phone then 42 else 36)
	local controlsTop = hintTop + (if hasHint then 18 else 0)
	local padFocus = useGamepadAutofocus(true)

	local overlayHostRef = React.useRef(nil)
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
		local host = overlayHostRef.current or padFocus.current
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
	local _exp = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	local _exp_1 = table.create(count, 0)
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#_exp_1)
	local _callback = function(_, index)
		local n = index + 1
		local active = n == step
		local done = n < step
		return React.createElement("imagebutton", {
			key = `step-{n}`,
			Size = UDim2.fromOffset(if active then 34 else 24, 40),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Active = not exiting,
			Selectable = not exiting,
			LayoutOrder = n,
			Event = {
				Activated = function()
					if not exiting and n ~= step then
						onJump(n)
					end
				end,
			},
		}, React.createElement("frame", {
			Size = UDim2.fromOffset(if active then 28 else 18, 18),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if active then Palette.mint elseif done then Palette.cyan else Palette.panelSoft,
			BackgroundTransparency = if active then 0 elseif done then 0.15 else 0.2,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), active and React.createElement(Text, {
			value = tostring(n),
			size = 10,
			color = Palette.ink,
			weight = Enum.FontWeight.Heavy,
			align = Enum.TextXAlignment.Center,
			sizeConstraint = UDim2.fromScale(1, 1),
		})))
	end
	for _k, _v in _exp_1 do
		_newValue[_k] = _callback(_v, _k - 1, _exp_1)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement(OverlayPresence, {
		amount = reveal,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 300,
		Visible = reveal:map(function(amount)
			return amount > 0.015
		end),
	}, React.createElement("frame", {
		ref = function(node)
			padFocus.current = node
			overlayHostRef.current = node
		end,
		Size = UDim2.new(0, dockW, 0, dockH),
		Position = reveal:map(function(amount)
			return UDim2.new(0.5, 0, 1, -(bottomInset + 10) + math.floor((1 - amount) * 24))
		end),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 310,
		Active = true,
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.mint,
		background = Palette.panelRaised,
		padding = if phone then 12 else 14,
		zIndex = 310,
		reveal = reveal,
		clips = false,
	}, React.createElement("frame", {
		Size = UDim2.new(1, -92, 0, 22),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 312,
	}, _exp, _newValue), React.createElement(Text, {
		value = `{step} / {count}`,
		size = 11,
		color = Palette.mint,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Right,
		fit = false,
		position = UDim2.new(1, -88, 0, 2),
		sizeConstraint = UDim2.fromOffset(88, 18),
		zIndex = 312,
	}), React.createElement(Text, {
		value = copy.title,
		size = if phone then 18 else 20,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 14,
		position = UDim2.fromOffset(0, 28),
		sizeConstraint = UDim2.new(1, 0, 0, 24),
		zIndex = 312,
	}), hasGoal and React.createElement(Text, {
		value = `GOAL · {copy.goal}`,
		size = 11,
		color = Palette.mint,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(0, 54),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
		zIndex = 312,
	}), React.createElement(Text, {
		value = copy.body,
		size = 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, bodyTop),
		sizeConstraint = UDim2.new(1, 0, 0, if phone then 40 else 34),
		zIndex = 312,
	}), hasHint and React.createElement(Text, {
		value = copy.hint,
		size = 11,
		color = Palette.cyan,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(0, hintTop),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
		zIndex = 312,
	}), hasControls and React.createElement(Text, {
		value = copy.controls,
		size = 10,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(0, controlsTop),
		sizeConstraint = UDim2.new(1, 0, 0, 14),
		zIndex = 312,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, if hasCta then TapTarget * 2 + 8 else TapTarget),
		Position = UDim2.new(0, 0, 1, -(if hasCta then TapTarget * 2 + 8 else TapTarget)),
		BackgroundTransparency = 1,
		ZIndex = 312,
	}, hasCta and React.createElement(Button, {
		text = ctaLabel,
		onClick = onCta,
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, TapTarget),
		reducedMotion = reducedMotion,
		disabled = exiting,
		highlight = true,
		zIndex = 312,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, TapTarget),
		Position = UDim2.fromOffset(0, if hasCta then TapTarget + 8 else 0),
		BackgroundTransparency = 1,
		ZIndex = 312,
	}, React.createElement(Button, {
		text = "SKIP",
		onClick = requestSkip,
		sound = "close",
		color = Palette.panelSoft,
		textColor = Palette.muted,
		size = UDim2.new(0.22, -4, 1, 0),
		reducedMotion = reducedMotion,
		disabled = exiting,
		zIndex = 312,
	}), React.createElement(Button, {
		text = "BACK",
		onClick = onBack,
		sound = "tutorialStep",
		disabled = step <= 1 or exiting,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		size = UDim2.new(0.26, -4, 1, 0),
		position = UDim2.new(0.22, 2, 0, 0),
		reducedMotion = reducedMotion,
		zIndex = 312,
	}), React.createElement(Button, {
		text = nextLabel,
		onClick = requestNext,
		sound = if step >= count then "tutorialFinish" else "tutorialStep",
		color = if hasCta then Palette.panelSoft else Palette.mint,
		textColor = if hasCta then Palette.cream else Palette.ink,
		size = UDim2.new(0.52, -2, 1, 0),
		position = UDim2.new(0.48, 4, 0, 0),
		reducedMotion = reducedMotion,
		disabled = exiting,
		highlight = not hasCta,
		zIndex = 312,
	})))))))
end
local VERSION_ROW_H = 48
local HIGHLIGHT_ROW_H = 46
local VERSION_RIGHT_COLUMN_W = 72
local function versionCardHeight(entry, expanded)
	if not expanded then
		return VERSION_ROW_H
	end
	return VERSION_ROW_H + #entry.Highlights * HIGHLIGHT_ROW_H + 18
end
local function VersionCard(_param)
	local entry = _param.entry
	local index = _param.index
	local current = _param.current
	local expanded = _param.expanded
	local onToggle = _param.onToggle
	local reducedMotion = _param.reducedMotion
	local reveal = useStagger(index, reducedMotion, 0.03, 0.26)
	local accent = if current then Palette.mint else Palette.violet
	local height = versionCardHeight(entry, expanded)
	local _exp = React.createElement("textbutton", {
		Size = UDim2.new(1, 0, 0, VERSION_ROW_H),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 328,
		Event = {
			Activated = function()
				Audio:play("tabSwitch")
				onToggle()
			end,
		},
	})
	local _exp_1 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	})
	local _exp_2 = React.createElement("uistroke", {
		Color = accent,
		Thickness = if current then 1.5 else 1,
		Transparency = if current then 0.32 else 0.68,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	local _exp_3 = React.createElement("frame", {
		Size = UDim2.fromOffset(3, 22),
		Position = UDim2.fromOffset(10, 13),
		BackgroundColor3 = accent,
		BackgroundTransparency = reveal:map(function(amount)
			return 1 - amount
		end),
		BorderSizePixel = 0,
		ZIndex = 326,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))
	local _exp_4 = React.createElement("frame", {
		Size = UDim2.new(1, -(VERSION_RIGHT_COLUMN_W + 28), 0, VERSION_ROW_H),
		Position = UDim2.fromOffset(20, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 326,
	}, React.createElement(Text, {
		value = entry.Version,
		size = 11,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(0, 8),
		sizeConstraint = UDim2.new(1, 0, 0, 14),
		transparency = reveal:map(function(amount)
			return 1 - amount
		end),
		zIndex = 326,
	}), React.createElement(Text, {
		value = entry.Title,
		size = 13,
		color = Palette.cream,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(0, 24),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
		transparency = reveal:map(function(amount)
			return 1 - amount
		end),
		zIndex = 326,
	}))
	local _exp_5 = React.createElement("frame", {
		Size = UDim2.fromOffset(VERSION_RIGHT_COLUMN_W, VERSION_ROW_H),
		Position = UDim2.new(1, -(VERSION_RIGHT_COLUMN_W + 10), 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 327,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Text, {
		value = entry.Date,
		size = 9,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Right,
		fit = true,
		minSize = 7,
		layoutOrder = 0,
		sizeConstraint = UDim2.new(1, 0, 0, 12),
		transparency = reveal:map(function(amount)
			return 1 - amount
		end),
		zIndex = 327,
	}), current and React.createElement("frame", {
		Size = UDim2.fromOffset(VERSION_RIGHT_COLUMN_W, 17),
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 328,
	}, React.createElement(Badge, {
		value = "LATEST",
		accent = Palette.mint,
		filled = true,
		size = UDim2.fromScale(1, 1),
		zIndex = 328,
	})), React.createElement(Text, {
		value = if expanded then "HIDE" else "VIEW",
		size = 9,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Right,
		fit = true,
		layoutOrder = 2,
		sizeConstraint = UDim2.new(1, 0, 0, 13),
		transparency = reveal:map(function(amount)
			return 1 - amount
		end),
		zIndex = 327,
	}))
	local _condition = expanded
	if _condition then
		local _exp_6 = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		local _exp_7 = entry.Highlights
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#_exp_7)
		local _callback = function(line, lineIndex)
			return React.createElement(Text, {
				key = lineIndex,
				value = `•  {line}`,
				size = 12,
				color = Palette.creamSoft,
				wrap = true,
				fit = false,
				layoutOrder = lineIndex,
				sizeConstraint = UDim2.new(1, 0, 0, HIGHLIGHT_ROW_H - 6),
				zIndex = 327,
			})
		end
		for _k, _v in _exp_7 do
			_newValue[_k] = _callback(_v, _k - 1, _exp_7)
		end
		-- ▲ ReadonlyArray.map ▲
		_condition = React.createElement("frame", {
			Size = UDim2.new(1, -30, 0, #entry.Highlights * HIGHLIGHT_ROW_H),
			Position = UDim2.fromOffset(20, VERSION_ROW_H),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 326,
		}, _exp_6, _newValue)
	end
	return React.createElement("frame", {
		Size = UDim2.new(1, -8, 0, height),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = index,
		ClipsDescendants = false,
	}, _exp, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panel,
		BackgroundTransparency = reveal:map(function(amount)
			return 1 - amount
		end),
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 325,
	}, _exp_1, _exp_2, _exp_3, _exp_4, _exp_5, _condition))
end
local function ReleaseNotesModal(_param)
	local version = _param.version
	local season = _param.season
	local announcement = _param.announcement
	local notes = _param.notes
	local history = _param.history
	if history == nil then
		history = {}
	end
	local viewportWidth = _param.viewportWidth
	local viewportHeight = _param.viewportHeight
	local reducedMotion = _param.reducedMotion
	local onClose = _param.onClose
	local onOpenMail = _param.onOpenMail
	local viewport = useViewport()
	React.useEffect(function()
		Audio:play("modalOpen")
	end, {})
	local enter = useEntrance(reducedMotion)
	local _binding = useExitTransition(reducedMotion)
	local exit = _binding[1]
	local exiting = _binding[2]
	local beginExit = _binding[3]
	local reveal = composePresence(enter, exit)
	local closeGuard = React.useRef(false)
	local closeOnce = React.useCallback(function()
		if closeGuard.current then
			return nil
		end
		closeGuard.current = true
		Audio:play("close")
		beginExit(onClose)
	end, { beginExit, onClose })
	React.useEffect(function()
		local actionName = "AstralForgeReleaseClose"
		ContextActionService:BindActionAtPriority(actionName, function(_name, inputState)
			if inputState == Enum.UserInputState.Begin then
				closeOnce()
			end
			return Enum.ContextActionResult.Sink
		end, false, 2300, Enum.KeyCode.ButtonB)
		return function()
			return ContextActionService:UnbindAction(actionName)
		end
	end, { closeOnce })
	local openMail = React.useCallback(function()
		if closeGuard.current or onOpenMail == nil then
			return nil
		end
		closeGuard.current = true
		beginExit(onOpenMail)
	end, { beginExit, onOpenMail })
	local safeTop = math.max(8, viewport.topInset)
	local safeBottom = math.max(8, viewport.bottomInset)
	local safeSide = math.max(8, viewport.sideInset)
	local width = math.max(240, math.min(650, viewportWidth - safeSide * 2 - 16))
	local availableHeight = math.max(160, viewportHeight - safeTop - safeBottom - 16)
	local height = math.min(530, availableHeight)
	local veryShort = height < 280
	local condensed = height < 420
	local padding = if condensed then 12 else 22
	local contentHeight = math.max(1, height - padding * 2)
	local stackActions = onOpenMail ~= nil and (viewport.compact or width < 430) and height >= 320
	local actionHeight = if stackActions then TapTarget * 2 + 8 else TapTarget
	local headerHeight = if veryShort then 68 elseif condensed then 112 else 148
	local scrollHeight = math.max(1, contentHeight - headerHeight - actionHeight - 10)
	local centerY = safeTop + math.max(0, (viewportHeight - safeTop - safeBottom) / 2)
	local effectiveHistory = if #history > 0 then history else { {
		Version = version,
		Title = season,
		Date = "",
		Highlights = notes,
	} }
	local expandedVersions, setExpandedVersions = React.useState(function()
		return if #effectiveHistory > 0 then { effectiveHistory[1].Version } else {}
	end)
	local toggleVersion = React.useCallback(function(entryVersion)
		setExpandedVersions(function(current)
			local _current = current
			local _entryVersion = entryVersion
			local _result
			if (table.find(_current, _entryVersion) or 0) - 1 >= 0 then
				-- ▼ ReadonlyArray.filter ▼
				local _newValue = {}
				local _callback = function(id)
					return id ~= entryVersion
				end
				local _length = 0
				for _k, _v in current do
					if _callback(_v, _k - 1, current) == true then
						_length += 1
						_newValue[_length] = _v
					end
				end
				-- ▲ ReadonlyArray.filter ▲
				_result = _newValue
			else
				local _array = {}
				local _length = #_array
				local _currentLength = #current
				table.move(current, 1, _currentLength, _length + 1, _array)
				_length += _currentLength
				_array[_length + 1] = entryVersion
				_result = _array
			end
			return _result
		end)
	end, {})
	-- ▼ ReadonlyArray.reduce ▼
	local _result = 0
	local _callback = function(total, entry)
		local _exp = total
		local _exp_1 = entry
		local _version = entry.Version
		return _exp + versionCardHeight(_exp_1, (table.find(expandedVersions, _version) or 0) - 1 >= 0)
	end
	for _i = 1, #effectiveHistory do
		_result = _callback(_result, effectiveHistory[_i], _i - 1, effectiveHistory)
	end
	-- ▲ ReadonlyArray.reduce ▲
	local canvasH = _result + math.max(0, #effectiveHistory - 1) * 8
	local padFocus = useGamepadAutofocus(true)

	local overlayHostRef = React.useRef(nil)
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
		local host = overlayHostRef.current or padFocus.current
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
	local _exp = React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = reveal:map(function(amount)
			return 1 - amount * 0.84
		end),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 321,
	})
	local _exp_1 = React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 322,
	})
	local _exp_2 = React.createElement(Text, {
		value = "WHAT'S NEW",
		size = 10,
		color = Palette.violet,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		sizeConstraint = UDim2.new(1, -60, 0, 16),
		zIndex = 325,
	})
	local _exp_3 = React.createElement(Text, {
		value = season,
		size = if veryShort then 18 else 25,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(0, if veryShort then 16 else 20),
		sizeConstraint = UDim2.new(1, -60, 0, if veryShort then 26 else 34),
		zIndex = 325,
	})
	local _exp_4 = React.createElement(Text, {
		value = `VERSION {version}`,
		size = 10,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(0, if veryShort then 43 else 56),
		sizeConstraint = UDim2.new(1, -60, 0, 15),
		zIndex = 325,
	})
	local _exp_5 = not veryShort and React.createElement(Text, {
		value = announcement,
		size = 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 78),
		sizeConstraint = UDim2.new(1, -4, 0, if condensed then 26 else 42),
		zIndex = 325,
	})
	local _exp_6 = React.createElement(Meter, {
		value = 1,
		color = Palette.violet,
		position = UDim2.fromOffset(0, if veryShort then 64 elseif condensed then 104 else 130),
		size = UDim2.new(1, 0, 0, 3),
		reducedMotion = reducedMotion,
		shimmer = true,
	})
	local _exp_7 = React.createElement("frame", {
		Size = UDim2.fromOffset(TapTarget, TapTarget),
		Position = UDim2.new(1, -TapTarget, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 328,
	}, React.createElement(Button, {
		text = "",
		icon = "Close",
		onClick = closeOnce,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = exiting,
		zIndex = 328,
	}))
	local _exp_8 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#effectiveHistory)
	local _callback_1 = function(entry, index)
		local _attributes = {
			key = entry.Version,
			entry = entry,
			index = index,
			current = entry.Version == version,
		}
		local _version = entry.Version
		_attributes.expanded = (table.find(expandedVersions, _version) or 0) - 1 >= 0
		_attributes.onToggle = function()
			return toggleVersion(entry.Version)
		end
		_attributes.reducedMotion = reducedMotion
		return React.createElement(VersionCard, _attributes)
	end
	for _k, _v in effectiveHistory do
		_newValue[_k] = _callback_1(_v, _k - 1, effectiveHistory)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement(OverlayPresence, {
		amount = reveal,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 320,
		Visible = reveal:map(function(amount)
			return amount > 0.01
		end),
	}, _exp, React.createElement("frame", {
		ref = function(node)
			padFocus.current = node
			overlayHostRef.current = node
		end,
		Size = UDim2.fromOffset(width, height),
		Position = reveal:map(function(amount)
			return UDim2.new(0.5, 0, 0, centerY + math.floor((1 - amount) * 18))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 322,
		Visible = reveal:map(function(amount)
			return amount > 0.015
		end),
	}, _exp_1, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.violet,
		background = Palette.panelRaised,
		padding = padding,
		zIndex = 323,
		reveal = reveal,
	}, _exp_2, _exp_3, _exp_4, _exp_5, _exp_6, _exp_7, React.createElement("scrollingframe", {
		Size = UDim2.new(1, 0, 0, scrollHeight),
		Position = UDim2.fromOffset(0, headerHeight),
		CanvasSize = UDim2.new(0, 0, 0, canvasH),
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Palette.violet,
		ScrollBarImageTransparency = 0.28,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		ClipsDescendants = true,
		Active = true,
		Selectable = false,
		ZIndex = 324,
	}, _exp_8, _newValue), if stackActions then React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, actionHeight),
		Position = UDim2.fromOffset(0, contentHeight - actionHeight),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 327,
	}, React.createElement(Button, {
		text = "GOT IT",
		icon = "Close",
		onClick = closeOnce,
		color = Palette.violet,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, TapTarget),
		reducedMotion = reducedMotion,
		disabled = exiting,
		zIndex = 327,
	}), onOpenMail ~= nil and React.createElement(Button, {
		text = "OPEN MAIL",
		icon = "Mail",
		onClick = openMail,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.fromOffset(0, TapTarget + 8),
		reducedMotion = reducedMotion,
		disabled = exiting,
		zIndex = 327,
	})) else React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, TapTarget),
		Position = UDim2.fromOffset(0, contentHeight - TapTarget),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 327,
	}, onOpenMail ~= nil and React.createElement(Button, {
		text = "OPEN MAIL",
		icon = "Mail",
		onClick = openMail,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.new(0.5, -4, 1, 0),
		reducedMotion = reducedMotion,
		disabled = exiting,
		zIndex = 327,
	}), React.createElement(Button, {
		text = "GOT IT",
		icon = "Close",
		onClick = closeOnce,
		color = Palette.violet,
		textColor = Palette.ink,
		size = if onOpenMail ~= nil then UDim2.new(0.5, -4, 1, 0) else UDim2.fromScale(1, 1),
		position = if onOpenMail ~= nil then UDim2.new(0.5, 4, 0, 0) else nil,
		reducedMotion = reducedMotion,
		disabled = exiting,
		zIndex = 327,
	}))))))
end
return {
	TutorialOverlay = TutorialOverlay,
	ReleaseNotesModal = ReleaseNotesModal,
}

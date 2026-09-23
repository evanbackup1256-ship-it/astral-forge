local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Icon = require(script.Parent.Parent.Icon).Icon
local _ui = require(script.Parent.Parent.ui)
local IconTile = _ui.IconTile
local Panel = _ui.Panel
local Button = _ui.Button
local Text = _ui.Text
local Meter = _ui.Meter
local Badge = _ui.Badge
local SCROLL_EDGE = _ui.SCROLL_EDGE
local ScrollPads = _ui.ScrollPads
local _motion = require(script.Parent.Parent.motion)
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.theme)
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local Layout = _theme.Layout
local lighten = _theme.lighten
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local _format = require(script.Parent.Parent.format)
local compactNumber = _format.compactNumber
local formatReward = _format.formatReward
local FORGE_PATH_STEPS = require(script.Parent.Parent.types).FORGE_PATH_STEPS
-- Reward chips + claim button need to fit inside the padded content area (row height minus
-- 2x the Panel's 12px padding). 168 clears two lines of description text plus the chip row
-- plus the claim button on the narrowest supported width without truncating anything -- on
-- desktop, where the claim button sits in its own right-hand column instead of stacking below
-- the text. Stack mode has no side column to put the button in (see the -200px reservation
-- below, which used to apply unconditionally even on a 320px-wide phone, leaving ~120px for
-- icon + two lines of text before the button ever entered the picture) -- the button and its
-- row therefore both need real extra height on mobile, not the same fixed constant desktop uses.
local STEP_ROW_HEIGHT = 168
local STEP_ROW_HEIGHT_STACK = 224
local EMPTY_FORGE_PATH = {
	ClaimedSteps = {},
	XP = 0,
}
local function effectLabel(step)
	local names = {
		Production = "production",
		TapPower = "tap power",
		Capacity = "vault capacity",
		CriticalChance = "critical chance",
		AutoCollect = "auto-collect rate",
		Offline = "offline income",
		CriticalMultiplier = "critical multiplier",
		RebirthMultiplier = "rebirth multiplier",
	}
	local _exp = step.EffectAmount
	local _condition = names[step.EffectKind]
	if _condition == nil then
		_condition = step.EffectKind
	end
	return `+{_exp}% {_condition}`
end
local function rewardChips(reward, accent)
	local chips = {}
	local _condition = reward.Cash
	if _condition == nil then
		_condition = 0
	end
	if _condition > 0 then
		local _arg0 = {
			label = `{compactNumber(reward.Cash)} flux`,
			icon = "Flux",
		}
		table.insert(chips, _arg0)
	end
	local _condition_1 = reward.Stardust
	if _condition_1 == nil then
		_condition_1 = 0
	end
	if _condition_1 > 0 then
		local _arg0 = {
			label = `{compactNumber(reward.Stardust)} dust`,
			icon = "Dust",
		}
		table.insert(chips, _arg0)
	end
	local _condition_2 = reward.Cores
	if _condition_2 == nil then
		_condition_2 = 0
	end
	if _condition_2 > 0 then
		local _arg0 = {
			label = `{compactNumber(reward.Cores)} cores`,
			icon = "Core",
		}
		table.insert(chips, _arg0)
	end
	local _condition_3 = reward.Essence
	if _condition_3 == nil then
		_condition_3 = 0
	end
	if _condition_3 > 0 then
		local _arg0 = {
			label = `{compactNumber(reward.Essence)} essence`,
			icon = "StarGrid",
		}
		table.insert(chips, _arg0)
	end
	if reward.Boost ~= nil then
		local _arg0 = {
			label = reward.Boost,
			icon = "Boost",
		}
		table.insert(chips, _arg0)
	end
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#chips)
	local _callback = function(chip, index)
		return React.createElement("frame", {
			key = index,
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = darken(accent, 0.55),
			BorderSizePixel = 0,
			LayoutOrder = index,
			ClipsDescendants = false,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 7),
		}), React.createElement("uigradient", {
			Color = ColorSequence.new(lighten(darken(accent, 0.5), 0.06), darken(accent, 0.2)),
			Rotation = 90,
		}), React.createElement("uipadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		}), React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}), React.createElement("frame", {
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 0,
			ClipsDescendants = true,
		}, React.createElement(Icon, {
			kind = chip.icon,
			color = Palette.cream,
			accent = accent,
			size = 16,
			spin = false,
			clipSafe = true,
		})), React.createElement("textlabel", {
			Size = UDim2.fromOffset(0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = chip.label,
			TextColor3 = Palette.cream,
			TextSize = 11,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 1,
		}))
	end
	for _k, _v in chips do
		_newValue[_k] = _callback(_v, _k - 1, chips)
	end
	-- ▲ ReadonlyArray.map ▲
	return _newValue
end
local function ForgePathRow(_param)
	local step = _param.step
	local claimed = _param.claimed
	local unlockedForClaim = _param.unlockedForClaim
	local affordable = _param.affordable
	local xp = _param.xp
	local onClaim = _param.onClaim
	local reducedMotion = _param.reducedMotion
	local index = _param.index
	local stack = _param.stack
	local reveal = useStagger(index, reducedMotion, 0.015, 0.12)
	local ready = not claimed and unlockedForClaim and affordable
	local locked = not claimed and not unlockedForClaim
	local accent = if claimed then Palette.muted elseif ready then step.Color else Palette.mango
	local progressFrac = math.clamp(xp / math.max(1, step.XPCost), 0, 1)
	local statusText = if claimed then "CLAIMED" elseif locked then "CLAIM THE PREVIOUS STEP FIRST" else `{compactNumber(math.min(xp, step.XPCost))} / {compactNumber(step.XPCost)} XP`
	-- Desktop reserves a 200px right-hand column for the claim button/badge and lets the meter/
	-- status sit in the remaining width. Stack mode has no side column -- everything runs the
	-- full row width, and the claim control moves below the meter/status as a full-width,
	-- TapTarget-tall button instead of a small side badge (this used to be a fixed 140x32
	-- button/badge at a fixed right-side offset even in stack mode, cramming a below-minimum
	-- tap target and 200px of dead reserved space into a phone-width row).
	local rowH = if stack then STEP_ROW_HEIGHT_STACK else STEP_ROW_HEIGHT
	local textW = if stack then -48 else -200
	return React.createElement("frame", {
		Size = UDim2.new(1, -4, 0, rowH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = index,
		ClipsDescendants = false,
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = accent,
		background = Palette.panel,
		padding = 12,
		reveal = reveal,
		highlight = ready,
		reducedMotion = reducedMotion,
		clips = false,
	}, React.createElement(IconTile, {
		kind = step.Icon,
		accent = if claimed then Palette.muted else step.Color,
		size = 38,
		radius = 10,
		position = UDim2.fromOffset(0, 4),
		spin = false,
		reducedMotion = reducedMotion,
	}), React.createElement(Text, {
		value = `STEP {step.Step}`,
		size = 10,
		color = if claimed then Palette.muted else step.Color,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(48, 2),
		sizeConstraint = UDim2.new(1, textW, 0, 16),
	}), React.createElement(Text, {
		value = effectLabel(step),
		size = 14,
		color = if claimed then Palette.muted else Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(48, 20),
		sizeConstraint = UDim2.new(1, textW, 0, 20),
	}), React.createElement(Text, {
		value = formatReward(step.Reward),
		size = 10,
		color = Palette.mango,
		weight = Enum.FontWeight.Bold,
		wrap = true,
		position = UDim2.fromOffset(48, 42),
		sizeConstraint = UDim2.new(1, textW, 0, 16),
	}), React.createElement("frame", {
		Size = UDim2.new(1, textW, 0, 26),
		Position = UDim2.fromOffset(48, 60),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), rewardChips(step.Reward, if claimed then Palette.muted else step.Color)), React.createElement(Meter, {
		value = progressFrac,
		color = if claimed then Palette.muted elseif locked then Palette.lineSoft else step.Color,
		reducedMotion = reducedMotion,
		position = UDim2.fromOffset(48, 92),
		size = UDim2.new(1, textW, 0, 6),
	}), React.createElement(Text, {
		value = statusText,
		size = 9,
		color = if locked then Palette.muted else Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		wrap = true,
		fit = false,
		position = UDim2.fromOffset(48, 100),
		sizeConstraint = UDim2.new(1, textW, 0, 24),
	}), if stack then (if claimed then React.createElement(Badge, {
		value = "CLAIMED",
		accent = Palette.muted,
		filled = true,
		position = UDim2.new(0, 0, 1, -TapTarget),
		size = UDim2.new(1, 0, 0, TapTarget),
	}) else React.createElement(Button, {
		text = if ready then "CLAIM" elseif locked then "LOCKED" else "NEED XP",
		icon = "Check",
		onClick = function()
			return onClaim(step.Step)
		end,
		color = if ready then step.Color else Palette.panelSoft,
		textColor = if ready then Palette.ink else Palette.muted,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -TapTarget),
		reducedMotion = reducedMotion,
		disabled = not ready,
		highlight = ready,
	})) else (if claimed then React.createElement(Badge, {
		value = "CLAIMED",
		accent = Palette.muted,
		filled = true,
		position = UDim2.new(1, -150, 0, 26),
		size = UDim2.fromOffset(140, 32),
	}) else React.createElement(Button, {
		text = if ready then "CLAIM" elseif locked then "LOCKED" else "NEED XP",
		icon = "Check",
		onClick = function()
			return onClaim(step.Step)
		end,
		color = if ready then step.Color else Palette.panelSoft,
		textColor = if ready then Palette.ink else Palette.muted,
		size = UDim2.fromOffset(140, 32),
		position = UDim2.new(1, -150, 0, 26),
		reducedMotion = reducedMotion,
		disabled = not ready,
		highlight = ready,
	}))))
end
local function ForgePathViewComponent(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local forgePath = state.ForgePath or EMPTY_FORGE_PATH
	local _set = {}
	for _, _v in forgePath.ClaimedSteps do
		_set[_v] = true
	end
	local claimedSet = _set
	local claimedCount = #forgePath.ClaimedSteps
	local totalCount = #FORGE_PATH_STEPS
	local onClaim = function(step)
		return dispatch("ClaimForgePathStep", {
			Step = step,
		})
	end
	local headerReveal = useStagger(0, reducedMotion)
	local listGap = if stack then chrome.panelGap else Layout.panelGap
	local headerH = if stack then 132 else 112
	local stepRowHeight = if stack then STEP_ROW_HEIGHT_STACK else STEP_ROW_HEIGHT
	local canvasHeight = headerH + listGap * (totalCount + 1) + totalCount * stepRowHeight + scrollTail(stack, chrome.bottomSafe, 48) + SCROLL_EDGE * 2
	local _exp = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, listGap),
	})
	local _exp_1 = React.createElement(ScrollPads)
	local _exp_2 = React.createElement(Panel, {
		size = UDim2.new(1, -4, 0, headerH),
		accent = Palette.violet,
		background = Palette.panelRaised,
		padding = if stack then 14 else 16,
		reveal = headerReveal,
		clips = false,
	}, React.createElement(IconTile, {
		kind = "Forge",
		accent = Palette.violet,
		size = if stack then 48 else 56,
		radius = 14,
		position = UDim2.fromOffset(0, if stack then 4 else 18),
		glow = true,
		spin = false,
		reducedMotion = reducedMotion,
	}), React.createElement(Text, {
		value = "FORGE PATH",
		size = 10,
		color = Palette.violet,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(if stack then 0 else 72, if stack then 60 else 0),
		sizeConstraint = UDim2.new(1, if stack then -8 else -220, 0, 16),
	}), React.createElement(Text, {
		value = "One track. Every step pays out.",
		size = if stack then 18 else 24,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(if stack then 0 else 72, if stack then 78 else 18),
		sizeConstraint = UDim2.new(1, if stack then -8 else -220, 0, 32),
	}), React.createElement(Text, {
		value = `{claimedCount} / {totalCount} steps claimed  ·  {compactNumber(forgePath.XP)} XP banked`,
		size = 11,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(if stack then 0 else 72, if stack then 108 else 56),
		sizeConstraint = UDim2.new(1, if stack then -8 else -220, 0, 24),
	}), not stack and React.createElement("frame", {
		Size = UDim2.new(0, 200, 0, 40),
		Position = UDim2.new(1, -200, 0.5, -20),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Text, {
		value = `{compactNumber(forgePath.XP)}`,
		size = 26,
		color = Palette.violet,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(0, 0),
		sizeConstraint = UDim2.new(1, 0, 0, 32),
	}), React.createElement(Text, {
		value = "FORGE XP",
		size = 10,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(0, 34),
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	})))
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#FORGE_PATH_STEPS)
	local _callback = function(step, index)
		local _step = step.Step
		local claimed = claimedSet[_step] ~= nil
		local _condition = step.Step == 1
		if not _condition then
			local _arg0 = step.Step - 1
			_condition = claimedSet[_arg0] ~= nil
		end
		local unlockedForClaim = _condition
		local affordable = forgePath.XP >= step.XPCost
		return React.createElement(ForgePathRow, {
			key = step.Step,
			step = step,
			claimed = claimed,
			unlockedForClaim = unlockedForClaim,
			affordable = affordable,
			xp = forgePath.XP,
			onClaim = onClaim,
			reducedMotion = reducedMotion,
			index = index,
			stack = stack,
		})
	end
	for _k, _v in FORGE_PATH_STEPS do
		_newValue[_k] = _callback(_v, _k - 1, FORGE_PATH_STEPS)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("scrollingframe", {
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(0, 0, 0, canvasHeight),
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Palette.violet,
		ScrollBarImageTransparency = 0.28,
		ClipsDescendants = true,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		Active = true,
		Selectable = false,
	}, _exp, _exp_1, _exp_2, _newValue)
end
-- state changes every ~5s on any server snapshot (production ticks, other pages' actions,
-- etc.), which would otherwise re-render all 40 step rows on every push even when nothing
-- about the Forge Path itself changed. Only re-render when the slice this page actually
-- reads — ForgePath — is a genuinely different value.
local ForgePathView = React.memo(ForgePathViewComponent, function(previous, incoming)
	local _condition = previous.dispatch == incoming.dispatch and previous.reducedMotion == incoming.reducedMotion
	if _condition then
		local _result = previous.state.ForgePath
		if _result ~= nil then
			_result = _result.XP
		end
		local _result_1 = incoming.state.ForgePath
		if _result_1 ~= nil then
			_result_1 = _result_1.XP
		end
		_condition = _result == _result_1
		if _condition then
			local _result_2 = previous.state.ForgePath
			if _result_2 ~= nil then
				_result_2 = #_result_2.ClaimedSteps
			end
			local _result_3 = incoming.state.ForgePath
			if _result_3 ~= nil then
				_result_3 = #_result_3.ClaimedSteps
			end
			_condition = _result_2 == _result_3
		end
	end
	return _condition
end)
return {
	ForgePathView = ForgePathView,
}

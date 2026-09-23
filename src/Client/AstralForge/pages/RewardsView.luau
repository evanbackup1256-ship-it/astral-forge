local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local _motion = require(script.Parent.Parent.motion)
local useFlipperSpring = _motion.useFlipperSpring
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _ui = require(script.Parent.Parent.ui)
local Button = _ui.Button
local IconTile = _ui.IconTile
local Panel = _ui.Panel
local Text = _ui.Text
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local _theme = require(script.Parent.Parent.theme)
local Layout = _theme.Layout
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local lighten = _theme.lighten
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local _format = require(script.Parent.Parent.format)
local clockText = _format.clockText
local formatReward = _format.formatReward

local function RewardChargeRail(_param)
	local value = _param.value
	local accent = _param.accent
	local ready = _param.ready
	local reducedMotion = _param.reducedMotion
	local position = _param.position
	local size = _param.size
	local antilag = useAntilag()
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	local progress = useFlipperSpring(math.clamp(value, 0, 1), softMotion, 420, 32)
	local emphasis = useFlipperSpring(if ready then 1 else 0, softMotion, 460, 32)
	local fillSize = progress:map(function(amount)
		return UDim2.new(math.clamp(amount, 0, 1), 0, 1, 0)
	end)
	local markerPosition = progress:map(function(amount)
		return UDim2.new(math.clamp(amount, 0, 1), 0, 0.5, 0)
	end)
	local markerScale = emphasis:map(function(amount)
		return 0.78 + math.clamp(amount, 0, 1) * 0.22
	end)
	return React.createElement("frame", {
		Size = size,
		Position = position,
		BackgroundColor3 = Palette.panelSoft,
		BackgroundTransparency = 0.22,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = fillSize,
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(darken(accent, 0.18), lighten(accent, 0.3)),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = markerPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = 45,
		BackgroundColor3 = if ready then Palette.cream else accent,
		BackgroundTransparency = progress:map(function(amount)
			return if amount > 0.025 then 0 else 1
		end),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uiscale", {
		Scale = markerScale,
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = accent,
		Thickness = 1,
		Transparency = emphasis:map(function(amount)
			return 0.68 - math.clamp(amount, 0, 1) * 0.46
		end),
	})))
end
local function TimedRewardQueue(_param)
	local entries = _param.entries
	local played = _param.played
	local reducedMotion = _param.reducedMotion
	local layoutOrder = _param.layoutOrder
	local pending = {}
	for _, entry in entries do
		if not entry.Claimed and #pending < 3 then
			table.insert(pending, entry)
		end
	end
	local reveal = useStagger(3, reducedMotion)
	local _exp = React.createElement(Text, {
		value = "COMING UP",
		size = 10,
		color = Palette.cyan,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	})
	local _exp_1 = #pending == 0 and React.createElement(Text, {
		value = "Today's playtime drops are all collected.",
		size = 13,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(0, 27),
		sizeConstraint = UDim2.new(1, 0, 0, 36),
	})
	local _condition = #pending > 0
	if _condition then
		local _exp_2 = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		})
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#pending)
		local _callback = function(entry, index)
			local ready = played >= entry.Seconds
			local accent = if ready then Palette.mint else Palette.cyan
			local _exp_3 = React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 8),
			})
			local _exp_4 = React.createElement("uistroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				LineJoinMode = Enum.LineJoinMode.Round,
				Color = accent,
				Thickness = 1,
				Transparency = if ready then 0.34 else 0.76,
			})
			local _exp_5 = React.createElement(Text, {
				value = if ready then "READY" else `IN {clockText(entry.Seconds - played)}`,
				size = 9,
				color = accent,
				weight = Enum.FontWeight.Heavy,
				fit = true,
				position = UDim2.fromOffset(10, 5),
				sizeConstraint = UDim2.new(1, -20, 0, 14),
			})
			local _attributes = {}
			local _condition_1 = formatReward(entry.Reward)
			if not (_condition_1 ~= "" and _condition_1) then
				_condition_1 = "Mystery parcel"
			end
			_attributes.value = _condition_1
			_attributes.size = 10
			_attributes.color = Palette.creamSoft
			_attributes.weight = Enum.FontWeight.Bold
			_attributes.fit = true
			_attributes.position = UDim2.fromOffset(10, 23)
			_attributes.sizeConstraint = UDim2.new(1, -20, 0, 20)
			return React.createElement("frame", {
				key = entry.Index,
				Size = UDim2.new(0.333, -6, 1, 0),
				LayoutOrder = index,
				BackgroundColor3 = if ready then Palette.panelRaised else Palette.panelSoft,
				BorderSizePixel = 0,
			}, _exp_3, _exp_4, _exp_5, React.createElement(Text, _attributes), React.createElement(RewardChargeRail, {
				value = played / math.max(1, entry.Seconds),
				accent = accent,
				ready = ready,
				reducedMotion = reducedMotion,
				position = UDim2.new(0, 8, 1, -4),
				size = UDim2.new(1, -16, 0, 3),
			}))
		end
		for _k, _v in pending do
			_newValue[_k] = _callback(_v, _k - 1, pending)
		end
		-- ▲ ReadonlyArray.map ▲
		_condition = React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 52),
			Position = UDim2.fromOffset(0, 24),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, _exp_2, _newValue)
	end
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, 104),
		accent = Palette.cyan,
		background = Palette.panel,
		padding = 14,
		layoutOrder = layoutOrder,
		reveal = reveal,
	}, _exp, _exp_1, _condition)
end
local function RewardsView(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local antilag = useAntilag()
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local dailyReady = state.Daily.CanClaim == true
	local timedEntries = state.TimedRewards.Rewards or {}
	-- ▼ ReadonlyArray.find ▼
	local _callback = function(entry)
		return not entry.Claimed
	end
	local _result
	for _i, _v in timedEntries do
		if _callback(_v, _i - 1, timedEntries) == true then
			_result = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local nextTimed = _result
	local _condition = state.TimedRewards.PlaySeconds
	if _condition == nil then
		_condition = 0
	end
	local played = _condition
	local timedReady = nextTimed ~= nil and played >= nextTimed.Seconds
	local timedProgress = if nextTimed ~= nil then math.clamp(played / math.max(1, nextTimed.Seconds), 0, 1) else 1
	local dailyReward = state.Daily.Rewards[state.Daily.RewardIndex]
	local headerReveal = useStagger(0, softMotion)
	local dailyReveal = useStagger(1, softMotion)
	local timedReveal = useStagger(2, softMotion)
	local rewardCardH = if stack then 172 else 110
	local rewardsTail = scrollTail(stack, chrome.bottomSafe, 48)
	local rewardsClaimHostRef = React.useRef(nil)
	-- Gamepad: park Selection on Daily Claim or Timed CLAIM (FocusClaim prefers Claim-named hosts).
	local rewardsClaimReady = dailyReady or timedReady
	React.useEffect(function()
		if not rewardsClaimReady or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = rewardsClaimHostRef.current
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
			task.cancel(selectJob)
		end
	end, { dailyReady, timedReady, rewardsClaimReady })
	local headerPanel = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.pink,
		background = Palette.panelRaised,
		padding = 14,
		layoutOrder = 0,
		reveal = headerReveal,
		clips = false,
	}, React.createElement(Text, {
		value = "REWARDS",
		size = 10,
		color = Palette.pink,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, -120, 0, 14),
	}), React.createElement(Text, {
		value = "Dailies and playtime drops. Boosts moved to their own page.",
		size = 20,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 18),
		sizeConstraint = UDim2.new(1, -16, 0, 28),
	}))
	local _exp_3 = React.createElement(IconTile, {
		kind = "Calendar",
		accent = if dailyReady then Palette.mint else Palette.panelSoft,
		size = 46,
		radius = 12,
		position = UDim2.fromOffset(0, if stack then 4 else 18),
		glow = dailyReady,
		reducedMotion = softMotion,
	})
	local _exp_4 = React.createElement(Text, {
		value = "Daily parcel",
		size = 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(60, 6),
		sizeConstraint = UDim2.new(1, if stack then -60 else -230, 0, 23),
	})
	local _attributes = {}
	local _condition_1 = formatReward(dailyReward)
	if not (_condition_1 ~= "" and _condition_1) then
		_condition_1 = (if dailyReady then "Ready to open" else "Already collected today")
	end
	_attributes.value = _condition_1
	_attributes.size = 11
	_attributes.color = Palette.muted
	_attributes.wrap = true
	_attributes.position = UDim2.fromOffset(60, 32)
	_attributes.sizeConstraint = UDim2.new(1, if stack then -60 else -230, 0, 20)
	local dailyPanel = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.mint,
		background = Palette.panel,
		padding = 14,
		layoutOrder = 1,
		reveal = dailyReveal,
		highlight = dailyReady,
		reducedMotion = softMotion,
		clips = false,
	}, _exp_3, _exp_4, React.createElement(Text, _attributes), React.createElement(Text, {
		value = "Streak " .. tostring(state.Daily.Streak) .. "  ·  next at " .. tostring(state.Daily.NextStreak),
		size = 10,
		color = Palette.mint,
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(60, 56),
		sizeConstraint = UDim2.new(1, if stack then -60 else -230, 0, 16),
	}), React.createElement(RewardChargeRail, {
		value = 1,
		accent = if dailyReady then Palette.mint else Palette.lineSoft,
		ready = dailyReady,
		reducedMotion = softMotion,
		position = UDim2.fromOffset(if stack then 0 else 60, if stack then 80 else 76),
		size = UDim2.new(1, if stack then 0 else -230, 0, 5),
	}), React.createElement("frame", {
		Name = "RewardsDailyClaimActions",
		Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(150, 44),
		Position = if stack then UDim2.new(0, 0, 1, -(TapTarget + 4)) else UDim2.new(1, -150, 0.5, -22),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ref = if dailyReady then rewardsClaimHostRef else nil,
	}, React.createElement(Button, {
		text = if dailyReady then "Claim" else "Claimed",
		icon = "Calendar",
		onClick = function()
			return dispatch("ClaimDaily")
		end,
		color = if dailyReady then Palette.mint else Palette.panelSoft,
		textColor = if dailyReady then Palette.ink else Palette.muted,
		size = UDim2.fromScale(1, 1),
		reducedMotion = softMotion,
		disabled = not dailyReady,
		highlight = dailyReady,
	})))
	local _exp_6 = React.createElement(IconTile, {
		kind = "Timer",
		accent = if timedReady then Palette.violet else Palette.panelSoft,
		size = 46,
		radius = 12,
		position = UDim2.fromOffset(0, if stack then 4 else 18),
		glow = timedReady,
		reducedMotion = softMotion,
	})
	local _exp_7 = React.createElement(Text, {
		value = "Timed drop",
		size = 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(60, 6),
		sizeConstraint = UDim2.new(1, if stack then -60 else -230, 0, 23),
	})
	local _attributes_1 = {}
	local _result_1
	if nextTimed ~= nil then
		local _condition_2 = formatReward(nextTimed.Reward)
		if not (_condition_2 ~= "" and _condition_2) then
			_condition_2 = (if timedReady then "Ready to collect" else clockText(played) .. " of " .. clockText(nextTimed.Seconds) .. " played")
		end
		_result_1 = _condition_2
	else
		_result_1 = "All caught up"
	end
	_attributes_1.value = _result_1
	_attributes_1.size = 10
	_attributes_1.color = Palette.muted
	_attributes_1.fit = true
	_attributes_1.position = UDim2.fromOffset(60, 32)
	_attributes_1.sizeConstraint = UDim2.new(1, if stack then -60 else -230, 0, 17)
	local timedPanel = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.violet,
		background = Palette.panel,
		padding = 14,
		layoutOrder = 2,
		reveal = timedReveal,
		highlight = timedReady,
		reducedMotion = softMotion,
		clips = false,
	}, _exp_6, _exp_7, React.createElement(Text, _attributes_1), React.createElement(RewardChargeRail, {
		value = timedProgress,
		accent = if timedReady then Palette.violet else Palette.cyan,
		ready = timedReady,
		reducedMotion = softMotion,
		position = UDim2.fromOffset(if stack then 0 else 60, if stack then 76 else 58),
		size = UDim2.new(1, if stack then 0 else -230, 0, 6),
	}), React.createElement("frame", {
		Name = "RewardsTimedClaimActions",
		Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(150, 44),
		Position = if stack then UDim2.new(0, 0, 1, -(TapTarget + 4)) else UDim2.new(1, -150, 0.5, -22),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		-- Prefer Daily Claim when both ready; otherwise park on Timed CLAIM.
		ref = if timedReady and not dailyReady then rewardsClaimHostRef else nil,
	}, React.createElement(Button, {
		text = if timedReady then "CLAIM" else "CHARGING",
		icon = "Timer",
		onClick = function()
			if nextTimed ~= nil then
				dispatch("ClaimTimedReward", {
					Index = nextTimed.Index,
				})
			end
		end,
		color = if timedReady then Palette.violet else Palette.panelSoft,
		textColor = if timedReady then Palette.ink else Palette.muted,
		size = UDim2.fromScale(1, 1),
		reducedMotion = softMotion,
		disabled = not timedReady,
		highlight = timedReady,
	})))
	local queuePanel =  React.createElement(TimedRewardQueue, {
		entries = timedEntries,
		played = played,
		reducedMotion = softMotion,
		layoutOrder = 3,
	})
	return React.createElement(PageScaffold, {
		gap = 12,
		tailPad = rewardsTail,
		scrollBarColor = Palette.pink,
		scrollBarThickness = 4,
		sections = {
			{
				id = "header",
				height = 72,
				element = headerPanel,
			},
			{
				id = "daily",
				height = rewardCardH,
				element = dailyPanel,
			},
			{
				id = "timed",
				height = rewardCardH,
				element = timedPanel,
			},
			{
				id = "queue",
				height = 104,
				element = queuePanel,
			},
		},
	})
end
return {
	RewardsView = RewardsView,
}

local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local _motion = require(script.Parent.Parent.motion)
local useFlash = _motion.useFlash
local usePulse = _motion.usePulse
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _ui = require(script.Parent.Parent.ui)
local Badge = _ui.Badge
local Button = _ui.Button
local Dropdown = _ui.Dropdown
local EmptyState = _ui.EmptyState
local IconTile = _ui.IconTile
local Meter = _ui.Meter
local Panel = _ui.Panel
local SCROLL_EDGE = _ui.SCROLL_EDGE
local Stroke = _ui.Stroke
local Text = _ui.Text
local _theme = require(script.Parent.Parent.theme)
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local scrollTail = _theme.scrollTail
local _format = require(script.Parent.Parent.format)
local compactNumber = _format.compactNumber
local formatReward = _format.formatReward
local _MissionsView = require(script.Parent.MissionsView)
local TASK_FILTERS = _MissionsView.TASK_FILTERS
local taskFilterCounts = _MissionsView.taskFilterCounts
local taskMatchesFilter = _MissionsView.taskMatchesFilter
local FlatList = require(script.Parent.Parent.virtualizedList).FlatList
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local NEAR_COMPLETE_THRESHOLD = 0.85
local function ProgressCloseGlow(_param)
	local progress = _param.progress
	local ready = _param.ready
	local accent = _param.accent
	local reducedMotion = _param.reducedMotion
	local position = _param.position
	local size = _param.size
	local antilag = useAntilag()
	local near = not ready and progress >= NEAR_COMPLETE_THRESHOLD and progress < 1
	local active = near and antilag.allowAmbient and antilag.tier >= 1 and not reducedMotion
	local pulse = usePulse(active, 2.4)
	if not near then
		return nil
	end
	return React.createElement("frame", {
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, React.createElement(Stroke, {
		color = accent,
		thickness = 1.5,
		transparency = if active then pulse:map(function(amount)
			return math.clamp(0.65 - amount * 0.45, 0.18, 0.65)
		end) else 0.5,
	}))
end
local function useReadyPop(ready, reducedMotion)
	local antilag = useAntilag()
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	local wasReady = React.useRef(ready)
	local trigger, setTrigger = React.useState(0)
	React.useEffect(function()
		if ready and not wasReady.current then
			setTrigger(function(current)
				return current + 1
			end)
		end
		wasReady.current = ready
	end, { ready })
	return useFlash(trigger, softMotion, 0.6)
end
local function MilestoneRow(_param)
	local achievement = _param.achievement
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local position = _param.position
	local stack = _param.stack
	local ready = not achievement.Claimed and achievement.Progress >= achievement.Target
	local reward = formatReward(achievement.Reward)
	local accent = if achievement.Claimed then Palette.muted elseif ready then Palette.green else Palette.mango
	local rowH = if stack then 220 else 148
	local pad = if stack then 14 else 16
	local contentH = rowH - pad * 2
	local btnReserve = if stack then TapTarget + 14 else 0
	local meterY = if stack then contentH - btnReserve - 8 else 108
	local progressY = meterY - 18
	local progressFrac = math.clamp(achievement.Progress / math.max(1, achievement.Target), 0, 1)
	local meterSize = UDim2.new(1, if stack then 0 else -182, 0, 8)
	local meterPosition = UDim2.fromOffset(0, meterY)
	local readyPop = useReadyPop(ready, reducedMotion)
	local iconScale = readyPop:map(function(amount)
		return 1 + amount * 0.22
	end)
	local _exp = React.createElement("frame", {
		Size = UDim2.fromOffset(42, 42),
		Position = UDim2.fromOffset(0, if stack then 4 else 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uiscale", {
		Scale = iconScale,
	}), React.createElement(IconTile, {
		kind = "Milestone",
		accent = if achievement.Claimed then Palette.mango else accent,
		size = 42,
		radius = 11,
		glow = ready,
		reducedMotion = reducedMotion,
	}))
	local _exp_1 = React.createElement(Text, {
		value = achievement.Name,
		size = if stack then 17 else 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(56, 2),
		sizeConstraint = UDim2.new(1, if stack then -(56 + 12) else -182, 0, 22),
	})
	local _attributes = {}
	local _condition = achievement.Description
	if _condition == nil then
		_condition = ""
	end
	_attributes.value = _condition
	_attributes.size = if stack then 12 else 11
	_attributes.color = Palette.muted
	_attributes.wrap = true
	_attributes.position = UDim2.fromOffset(56, 26)
	_attributes.sizeConstraint = UDim2.new(1, if stack then -(56 + 12) else -182, 0, if stack then 36 else 28)
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, rowH),
		position = position,
		accent = accent,
		background = Palette.panel,
		padding = pad,
		interactive = true,
		highlight = ready,
		reducedMotion = reducedMotion,
	}, _exp, _exp_1, React.createElement(Text, _attributes), reward ~= "" and React.createElement(Text, {
		value = reward,
		size = 11,
		color = Palette.mango,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(56, if stack then 66 else 58),
		sizeConstraint = UDim2.new(1, if stack then -(56 + 12) else -182, 0, 16),
	}), React.createElement(Text, {
		value = `{compactNumber(achievement.Progress)} / {compactNumber(achievement.Target)}`,
		size = 11,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, progressY),
		sizeConstraint = UDim2.new(0, 160, 0, 16),
	}), React.createElement(Meter, {
		value = if achievement.Claimed or ready then 1 else progressFrac,
		color = if achievement.Claimed then Palette.muted else accent,
		reducedMotion = reducedMotion,
		shimmer = ready,
		position = meterPosition,
		size = meterSize,
	}), React.createElement(ProgressCloseGlow, {
		progress = progressFrac,
		ready = ready,
		accent = accent,
		reducedMotion = reducedMotion,
		position = meterPosition,
		size = meterSize,
	}), if stack then React.createElement(Button, {
		text = if achievement.Claimed then "CLAIMED" elseif ready then "CLAIM" else "LOCKED",
		icon = "Wheel",
		onClick = function()
			return dispatch("ClaimAchievement", {
				Id = achievement.Id,
			})
		end,
		color = if ready then Palette.green else Palette.panelSoft,
		textColor = if ready then Palette.ink else Palette.creamSoft,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -(TapTarget + 6)),
		reducedMotion = reducedMotion,
		disabled = achievement.Claimed or not ready,
		highlight = ready,
	}) else React.createElement(Button, {
		text = if achievement.Claimed then "CLAIMED" elseif ready then "CLAIM" else "LOCKED",
		icon = "Wheel",
		onClick = function()
			return dispatch("ClaimAchievement", {
				Id = achievement.Id,
			})
		end,
		color = if ready then Palette.green else Palette.panelSoft,
		textColor = if ready then Palette.ink else Palette.creamSoft,
		size = UDim2.fromOffset(166, 44),
		position = UDim2.new(1, -166, 0.5, -22),
		reducedMotion = reducedMotion,
		disabled = achievement.Claimed or not ready,
		highlight = ready,
	}))
end
local function MilestonesView(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local stack = chrome.contentStack
	local list = state.Achievements or {}
	local filter, setFilter = React.useState("All")
	local counts = taskFilterCounts(list)
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#TASK_FILTERS)
	local _callback = function(option)
		local _object = table.clone(option)
		setmetatable(_object, nil)
		_object.count = counts[option.id]
		return _object
	end
	for _k, _v in TASK_FILTERS do
		_newValue[_k] = _callback(_v, _k - 1, TASK_FILTERS)
	end
	-- ▲ ReadonlyArray.map ▲
	local options = _newValue
	-- ▼ ReadonlyArray.filter ▼
	local _newValue_1 = {}
	local _callback_1 = function(achievement)
		return taskMatchesFilter(achievement, filter)
	end
	local _length = 0
	for _k, _v in list do
		if _callback_1(_v, _k - 1, list) == true then
			_length += 1
			_newValue_1[_length] = _v
		end
	end
	-- ▲ ReadonlyArray.filter ▲
	local visible = _newValue_1
	local headerReveal = useStagger(0, reducedMotion)
	local headerHeight = if stack then (if chrome.landscape then 144 else 176) else 148
	local rowStride = (if stack then 220 else 148) + 16
	local pageGap = if stack then chrome.panelGap else 10
	local headerPanel = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.mango,
		background = Palette.panelRaised,
		padding = 16,
		reveal = headerReveal,
		zIndex = 30,
		clips = false,
	},  if stack then React.createElement(React.Fragment, nil, not chrome.landscape and React.createElement(React.Fragment, nil, React.createElement(Text, {
			value = "MILESTONES",
			size = 10,
			color = Palette.mango,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			sizeConstraint = UDim2.new(1, -8, 0, 16),
		}), React.createElement(Text, {
			value = "Long-term goals.",
			size = 20,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			position = UDim2.fromOffset(0, 16),
			sizeConstraint = UDim2.new(1, -8, 0, 30),
		})), React.createElement(Text, {
			value = "Big achievements that stay even after a rebirth.",
			size = 12,
			color = Palette.muted,
			wrap = true,
			position = UDim2.fromOffset(0, if chrome.landscape then 0 else 48),
			sizeConstraint = UDim2.new(1, -8, 0, if chrome.landscape then 28 else 32),
		}), React.createElement(Dropdown, {
			options = options,
			value = filter,
			onChange = setFilter,
			accent = Palette.mango,
			position = UDim2.new(0, 0, 1, -(TapTarget + 8)),
			size = UDim2.new(1, 0, 0, TapTarget),
			reducedMotion = reducedMotion,
			zIndex = 44,
		})) else React.createElement(React.Fragment, nil, React.createElement(Text, {
			value = "MILESTONES",
			size = 10,
			color = Palette.mango,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			sizeConstraint = UDim2.new(1, -160, 0, 16),
		}), React.createElement(Text, {
			value = "Long-term goals.",
			size = 22,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			position = UDim2.fromOffset(0, 16),
			sizeConstraint = UDim2.new(1, -180, 0, 30),
		}), React.createElement(Text, {
			value = "Big achievements that stay even after a rebirth.",
			size = 10,
			color = Palette.muted,
			wrap = true,
			position = UDim2.fromOffset(0, 48),
			sizeConstraint = UDim2.new(1, -180, 0, 16),
		}), React.createElement(Dropdown, {
			options = options,
			value = filter,
			onChange = setFilter,
			accent = Palette.mango,
			position = UDim2.new(0, 0, 0, 70),
			size = UDim2.fromOffset(224, 48),
			reducedMotion = reducedMotion,
			zIndex = 44,
		}), React.createElement(Text, {
			value = `{counts.Done} / {#list}`,
			size = 18,
			color = Palette.mango,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			position = UDim2.new(1, -120, 0, 4),
			sizeConstraint = UDim2.new(0, 120, 0, 26),
			align = Enum.TextXAlignment.Right,
		}), counts.Ready > 0 and React.createElement(Badge, {
			value = `{counts.Ready} READY`,
			accent = Palette.green,
			filled = true,
			position = UDim2.new(1, -120, 0, 34),
			size = UDim2.fromOffset(120, 22),
		}), React.createElement(Text, {
			value = `{#visible} shown`,
			size = 10,
			color = Palette.muted,
			weight = Enum.FontWeight.Bold,
			fit = true,
			align = Enum.TextXAlignment.Right,
			position = UDim2.new(1, -120, 0, 72),
			sizeConstraint = UDim2.new(0, 120, 0, 24),
		})))
	local milestonesList = React.createElement(FlatList, {
		data = visible,
		itemHeight = rowStride,
		headerHeight = 0,
		overscan = 2,
		canvasTail = 8,
		Size = UDim2.fromScale(1, 1),
		scrollBarColor = Palette.mango,
		scrollBarThickness = 3,
		scrollBarTransparency = 0.28,
		keyExtractor = function(achievement)
			return achievement.Id
		end,
		renderItem = function(_param_1)
			local item = _param_1.item
			return React.createElement(MilestoneRow, {
				achievement = item,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
				position = UDim2.fromOffset(0, 0),
				stack = stack,
			})
		end,
		ListEmptyComponent = if #visible == 0 then React.createElement(EmptyState, {
			icon = "Settings",
			title = if #list == 0 then "No milestones yet" else "Nothing in this filter",
			body = if #list == 0 then "Keep playing — they'll show up." else "Switch the filter back to Everything.",
			accent = Palette.mango,
			size = UDim2.fromScale(1, 1),
		}) else nil,
	})
	return React.createElement(PageScaffold, {
		gap = pageGap,
		tailPad = scrollTail(stack, chrome.bottomSafe, 24),
		scrollBarColor = Palette.mango,
		scrollBarThickness = 4,
		sections = {
			{
				id = "hero",
				height = headerHeight,
				element = headerPanel,
			},
			{
				id = "list",
				fill = true,
				minHeight = math.max(160, rowStride * 2),
				element = milestonesList,
			},
		},
	})
end
return {
	MilestonesView = MilestonesView,
}

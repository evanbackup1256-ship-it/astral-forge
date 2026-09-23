local exports = {}
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local PageReadyMath = require(script.Parent.Parent.pageReadyMath)
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local _motion = require(script.Parent.Parent.motion)
local useEntrance = _motion.useEntrance
local useFlash = _motion.useFlash
local usePulse = _motion.usePulse
local useViewport = _motion.useViewport
local _ui = require(script.Parent.Parent.ui)
local Badge = _ui.Badge
local Button = _ui.Button
local Dropdown = _ui.Dropdown
local EmptyState = _ui.EmptyState
local IconTile = _ui.IconTile
local Meter = _ui.Meter
local Panel = _ui.Panel
local Stroke = _ui.Stroke
local Text = _ui.Text
local _theme = require(script.Parent.Parent.theme)
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local scrollTail = _theme.scrollTail
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local _format = require(script.Parent.Parent.format)
local compactNumber = _format.compactNumber
local formatReward = _format.formatReward
local _taskFilter = require(script.Parent.Parent.taskFilter)
local taskFilterCounts = _taskFilter.taskFilterCounts
local taskMatchesFilter = _taskFilter.taskMatchesFilter
local FlatList = require(script.Parent.Parent.virtualizedList).FlatList
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
local _taskFilter_1 = require(script.Parent.Parent.taskFilter)
exports.taskFilterCounts = _taskFilter_1.taskFilterCounts
exports.taskMatchesFilter = _taskFilter_1.taskMatchesFilter
local TASK_FILTERS = { {
	id = "All",
	label = "Everything",
}, {
	id = "Ready",
	label = "Ready to claim",
}, {
	id = "Active",
	label = "Still in progress",
}, {
	id = "Done",
	label = "Already claimed",
} }
local function MissionRow(_param)
	local quest = _param.quest
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — MissionRow.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local position = _param.position
	local stack = _param.stack
	local ready = not quest.Claimed and quest.Progress >= quest.Target
	local reward = formatReward(quest.Reward)
	local accent = if quest.Claimed then Palette.muted elseif ready then Palette.green else Palette.cyan
	local rowH = if stack then 220 else 148
	local pad = if stack then 14 else 16
	local contentH = rowH - pad * 2
	local btnReserve = if stack then TapTarget + 14 else 0
	local meterY = if stack then contentH - btnReserve - 8 else 108
	local progressY = meterY - 18
	local progressFrac = math.clamp(quest.Progress / math.max(1, quest.Target), 0, 1)
	local meterSize = UDim2.new(1, if stack then 0 else -182, 0, 8)
	local meterPosition = UDim2.fromOffset(0, meterY)
	local readyPop = useReadyPop(ready, softMotion)
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
		kind = "Mission",
		accent = if quest.Claimed then Palette.cyan else accent,
		size = 42,
		radius = 11,
		glow = ready,
		reducedMotion = softMotion,
	}))
	local _exp_1 = React.createElement(Text, {
		value = quest.Name,
		size = if stack then 17 else 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(56, 2),
		sizeConstraint = UDim2.new(1, if stack then -(56 + 12) else -182, 0, 22),
	})
	local _attributes = {}
	local _condition = quest.Description
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
		reducedMotion = softMotion,
	}, _exp, _exp_1, React.createElement(Text, _attributes), reward ~= "" and React.createElement(Text, {
		value = reward,
		size = 11,
		color = Palette.mango,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(56, if stack then 66 else 58),
		sizeConstraint = UDim2.new(1, if stack then -(56 + 12) else -182, 0, 16),
	}), React.createElement(Text, {
		value = `{compactNumber(quest.Progress)} / {compactNumber(quest.Target)}`,
		size = 11,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, progressY),
		sizeConstraint = UDim2.new(0, 160, 0, 16),
	}), React.createElement(Meter, {
		value = if quest.Claimed or ready then 1 else progressFrac,
		color = if quest.Claimed then Palette.muted else accent,
		reducedMotion = softMotion,
		shimmer = ready,
		position = meterPosition,
		size = meterSize,
	}), React.createElement(ProgressCloseGlow, {
		progress = progressFrac,
		ready = ready,
		accent = accent,
		reducedMotion = softMotion,
		position = meterPosition,
		size = meterSize,
	}), if stack then React.createElement(Button, {
		text = if quest.Claimed then "CLAIMED" elseif ready then "CLAIM" else "IN PROGRESS",
		icon = "Mission",
		onClick = function()
			return dispatch("ClaimQuest", {
				Id = quest.Id,
			})
		end,
		color = if ready then Palette.green else Palette.panelSoft,
		textColor = if ready then Palette.ink else Palette.creamSoft,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -(TapTarget + 6)),
		reducedMotion = softMotion,
		disabled = quest.Claimed or not ready,
		highlight = ready,
	}) else React.createElement(Button, {
		text = if quest.Claimed then "CLAIMED" elseif ready then "CLAIM" else "IN PROGRESS",
		icon = "Mission",
		onClick = function()
			return dispatch("ClaimQuest", {
				Id = quest.Id,
			})
		end,
		color = if ready then Palette.green else Palette.panelSoft,
		textColor = if ready then Palette.ink else Palette.creamSoft,
		size = UDim2.fromOffset(166, 44),
		position = UDim2.new(1, -166, 0.5, -22),
		reducedMotion = softMotion,
		disabled = quest.Claimed or not ready,
		highlight = ready,
	}))
end
local function MissionsView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — MissionsView
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local enter = useEntrance(softMotion)
	local stack = chrome.contentStack
	local quests = state.Quests
	local filter, setFilter = React.useState("All")
	local counts = taskFilterCounts(quests)
	local missionClaimHostRef = React.useRef(nil)
	-- Gamepad: park Selection on CLAIM ALL when ready.
	React.useEffect(function()
		if counts.Ready <= 0 or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = missionClaimHostRef.current
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
	end, { counts.Ready, filter })
	local guide = if config ~= nil and config.ClientPageGuides ~= nil then config.ClientPageGuides.Missions else nil
	local claimAllReady = function()
		-- Partial Quests bags / incomplete entries must not throw Progress>=Target compares.
		if type(quests) ~= "table" then
			return
		end
		for _, quest in quests do
			if type(quest) == "table" and not quest.Claimed then
				local progress = tonumber(quest.Progress) or 0
				local target = tonumber(quest.Target) or 0
				if target > 0 and progress >= target then
					dispatch("ClaimQuest", { Id = quest.Id })
				end
			end
		end
	end
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
	local _callback_1 = function(quest)
		return taskMatchesFilter(quest, filter)
	end
	local _length = 0
	for _k, _v in quests do
		if _callback_1(_v, _k - 1, quests) == true then
			_length += 1
			_newValue_1[_length] = _v
		end
	end
	-- ▲ ReadonlyArray.filter ▲
	local visible = _newValue_1
	local headerHeight = if stack then (if chrome.landscape then 188 else 204) else 168
	local rowStride = (if stack then 220 else 148) + 16
	local pageGap = 10
	local headerPanel = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.cyan,
		background = Palette.panelRaised,
		padding = 16,
		reveal = enter,
		reducedMotion = softMotion,
		zIndex = 30,
		clips = false,
	}, if stack then React.createElement(React.Fragment, nil, React.createElement(Text, {
		value = "Finish these for flux and stardust. They refresh every day.",
		size = 12,
		color = Palette.muted,
		wrap = true,
		sizeConstraint = UDim2.new(1, -8, 0, if chrome.landscape then 28 else 36),
	}), counts.Ready > 0 and React.createElement("frame", {
		Name = "MissionClaimActions",
		Size = UDim2.new(1, 0, 0, TapTarget),
		Position = UDim2.new(0, 0, 1, -(TapTarget * 2 + 16)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ref = missionClaimHostRef,
	}, React.createElement(Button, {
		text = `CLAIM ALL READY · {counts.Ready}`,
		icon = "Gift",
		onClick = claimAllReady,
		color = Palette.green,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = softMotion,
		highlight = true,
	})), React.createElement(Dropdown, {
		options = options,
		value = filter,
		onChange = setFilter,
		accent = Palette.cyan,
		position = UDim2.new(0, 0, 1, -(TapTarget + 8)),
		size = UDim2.new(1, 0, 0, TapTarget),
		reducedMotion = softMotion,
		zIndex = 44,
	})) else React.createElement(React.Fragment, nil, React.createElement(Text, {
		value = "MISSIONS",
		size = 10,
		color = Palette.cyan,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, -160, 0, 16),
	}), React.createElement(Text, {
		value = "Daily checklist.",
		size = 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 16),
		sizeConstraint = UDim2.new(1, -180, 0, 30),
	}), React.createElement(Text, {
		value = "Finish these for flux and stardust. They refresh every day.",
		size = 10,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(0, 48),
		sizeConstraint = UDim2.new(1, -180, 0, 16),
	}), React.createElement(Dropdown, {
		options = options,
		value = filter,
		onChange = setFilter,
		accent = Palette.cyan,
		position = UDim2.new(0, 0, 0, 70),
		size = UDim2.fromOffset(224, 48),
		reducedMotion = softMotion,
		zIndex = 44,
	}), counts.Ready > 0 and React.createElement("frame", {
		Name = "MissionClaimActions",
		Size = UDim2.fromOffset(168, 40),
		Position = UDim2.new(0, 236, 0, 74),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ref = missionClaimHostRef,
	}, React.createElement(Button, {
		text = `CLAIM ALL · {counts.Ready}`,
		icon = "Gift",
		onClick = claimAllReady,
		color = Palette.green,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = softMotion,
		highlight = true,
	})), React.createElement(Text, {
		value = `{counts.Done} / {#quests}`,
		size = 18,
		color = Palette.cyan,
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
	local missionsList = React.createElement(FlatList, {
		data = visible,
		itemHeight = rowStride,
		headerHeight = 0,
		overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
		canvasTail = 8,
		Size = UDim2.fromScale(1, 1),
		scrollBarColor = Palette.cyan,
		scrollBarThickness = 3,
		scrollBarTransparency = 0.28,
		keyExtractor = function(quest)
			return quest.Id
		end,
		renderItem = function(_param_1)
			local item = _param_1.item
			return React.createElement(MissionRow, {
				quest = item,
				dispatch = dispatch,
				reducedMotion = softMotion,
				position = UDim2.fromOffset(0, 0),
				stack = stack,
			})
		end,
		ListEmptyComponent = if #visible == 0 then React.createElement(EmptyState, {
			icon = "Mission",
			title = if #quests == 0 then "No missions yet" else "Nothing in this filter",
			body = if #quests == 0 then ((guide and guide.EmptyNone) or "New dailies land at reset.") else ((guide and guide.EmptyFilter) or "Switch the filter back to Everything."),
			accent = Palette.cyan,
			size = UDim2.fromScale(1, 1),
		}) else nil,
	})
	return React.createElement(PageScaffold, {
		gap = pageGap,
		tailPad = scrollTail(stack, chrome.bottomSafe, 24),
		scrollBarColor = Palette.cyan,
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
				element = missionsList,
			},
		},
	})
end
exports.MissionsView = MissionsView
exports.TASK_FILTERS = TASK_FILTERS
return exports

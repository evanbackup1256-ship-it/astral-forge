local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local _format = require(script.Parent.Parent.format)
local amountPayload = _format.amountPayload
local bulkCost = _format.bulkCost
local compactNumber = _format.compactNumber
local gteFlux = _format.gteFlux
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local _motion = require(script.Parent.Parent.motion)
local useFlash = _motion.useFlash
local usePulse = _motion.usePulse
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.theme)
local Layout = _theme.Layout
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local scrollTail = _theme.scrollTail
local _ui = require(script.Parent.Parent.ui)
local AmountToggle = _ui.AmountToggle
local Badge = _ui.Badge
local Button = _ui.Button
local IconTile = _ui.IconTile
local Meter = _ui.Meter
local meterFill = _ui.meterFill
local Panel = _ui.Panel
local SCROLL_EDGE = _ui.SCROLL_EDGE
local SectionLabel = _ui.SectionLabel
local Stroke = _ui.Stroke
local Text = _ui.Text
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local FlatList = require(script.Parent.Parent.virtualizedList).FlatList
local GRID_CHUNK = 8
local GRID_MAX_VISIBLE = 16
local VIRT_NODE_MIN = 8
local BRANCH_H = 140
local BRANCH_H_STACK = 132
local NODE_H = 136
local NODE_H_STACK = 198
local SCROLL_BAR = 4
local BADGE_W = 118
local BADGE_H = 30
local NEAR_COMPLETE_THRESHOLD = 0.85
-- Only nodes that are close to their next level cap or just changed state pay for a live
-- pulse subscription; the other ~110 nodes on screen render this as a static, disabled frame.
local function NodeProgressGlow(_param)
	local near = _param.near
	local maxed = _param.maxed
	local accent = _param.accent
	local reducedMotion = _param.reducedMotion
	local position = _param.position
	local size = _param.size
	local antilag = useAntilag()
	local active = near and not maxed and antilag.allowAmbient and antilag.tier >= 1 and not reducedMotion
	local pulse = usePulse(active, 2.4)
	if not near or maxed then
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
-- Fires a brief flourish only on the false->true edge (node just became buyable or was just
-- maxed out), so idle nodes never carry a flash subscription.
local function useNodeUnlockPop(unlocked, reducedMotion)
	local antilag = useAntilag()
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	local wasUnlocked = React.useRef(unlocked)
	local trigger, setTrigger = React.useState(0)
	React.useEffect(function()
		if unlocked and not wasUnlocked.current then
			setTrigger(function(current)
				return current + 1
			end)
		end
		wasUnlocked.current = unlocked
	end, { unlocked })
	return useFlash(trigger, softMotion, 0.6)
end
local function branchIcon(branchId)
	if branchId == "Output" or branchId == "Throughput" or branchId == "Helix" then
		return "Forge"
	end
	if branchId == "Vault" or branchId == "Reservoir" or branchId == "Aegis" then
		return "Vault"
	end
	if branchId == "Charge" or branchId == "Pulse" or branchId == "Ember" then
		return "Overcharge"
	end
	if branchId == "Critical" or branchId == "Apex" or branchId == "Nova" then
		return "Jackpot"
	end
	if branchId == "Offline" or branchId == "Drift" then
		return "Timer"
	end
	if branchId == "Automation" or branchId == "Swarm" then
		return "Grid"
	end
	return "StarGrid"
end
local function BranchHeader(_param)
	local branch = _param.branch
	local levels = _param.levels
	local maxLevels = _param.maxLevels
	local active = _param.active
	local onSelect = _param.onSelect
	local reducedMotion = _param.reducedMotion
	local stack = _param.stack
	local staggerIndex = _param.staggerIndex
	local layoutOrder = _param.layoutOrder
	local antilag = useAntilag()
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local reveal = useStagger(staggerIndex, softMotion)
	local rowH = if stack then BRANCH_H_STACK else BRANCH_H
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, rowH),
		accent = branch.Color,
		background = Palette.panelRaised,
		padding = 16,
		layoutOrder = layoutOrder,
		reveal = reveal,
		reducedMotion = reducedMotion,
	}, React.createElement(IconTile, {
		kind = branchIcon(branch.Id),
		accent = branch.Color,
		size = if stack then 56 else 72,
		radius = 16,
		position = UDim2.fromOffset(0, if stack then 10 else 8),
		reducedMotion = reducedMotion,
	}), React.createElement(Text, {
		value = branch.Name,
		size = if stack then 20 else 24,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(if stack then 72 else 90, 8),
		sizeConstraint = UDim2.new(1, if stack then -90 else -(BADGE_W + 110), 0, 30),
	}), React.createElement(Text, {
		value = branch.Description,
		size = 13,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(if stack then 72 else 90, 42),
		sizeConstraint = UDim2.new(1, if stack then -90 else -(BADGE_W + 110), 0, if stack then 40 else 28),
	}), if stack then React.createElement(React.Fragment, nil, React.createElement(Button, {
		text = if active then "ACTIVE" else "VIEW",
		onClick = onSelect,
		color = branch.Color,
		textColor = if active then Palette.ink else branch.Color,
		outline = not active,
		highlight = active,
		size = UDim2.fromOffset(88, TapTarget),
		position = UDim2.new(1, -220, 1, -42),
		reducedMotion = reducedMotion,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(BADGE_W - 8, BADGE_H),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Badge, {
		value = `{compactNumber(levels)} / {compactNumber(maxLevels)}`,
		accent = branch.Color,
		filled = true,
		size = UDim2.fromScale(1, 1),
	}))) else React.createElement(React.Fragment, nil, React.createElement(Badge, {
		value = `{compactNumber(levels)} / {compactNumber(maxLevels)}`,
		accent = branch.Color,
		filled = true,
		position = UDim2.new(1, -(BADGE_W + 16), 0, 14),
		size = UDim2.fromOffset(BADGE_W, BADGE_H),
	}), React.createElement(Button, {
		text = if active then "ACTIVE ROUTE" else "VIEW ROUTE",
		onClick = onSelect,
		color = branch.Color,
		textColor = if active then Palette.ink else branch.Color,
		outline = not active,
		highlight = active,
		size = UDim2.fromOffset(BADGE_W, TapTarget),
		position = UDim2.new(1, -(BADGE_W + 16), 0, 56),
		reducedMotion = reducedMotion,
	})))
end
local function NodeRow(_param)
	local upgrade = _param.upgrade
	local branch = _param.branch
	local level = _param.level
	local buyAmount = _param.buyAmount
	local stardust = _param.stardust
	local rebirths = _param.rebirths
	local grid = _param.grid
	local previousMaxLevel = _param.previousMaxLevel
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local stack = _param.stack
	local staggerIndex = _param.staggerIndex
	local layoutOrder = _param.layoutOrder
	local antilag = useAntilag()
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local reveal = useStagger(staggerIndex, softMotion)
	local rowH = if stack then NODE_H_STACK else NODE_H
	local _condition = upgrade.PreviousId == nil
	if not _condition then
		local _condition_1 = grid[upgrade.PreviousId]
		if _condition_1 == nil then
			_condition_1 = 0
		end
		_condition = _condition_1 >= previousMaxLevel
	end
	local previousComplete = _condition
	local lock = if rebirths < upgrade.RequiredRebirths then `{upgrade.RequiredRebirths} rebirths` elseif not previousComplete then "Previous node" else nil
	local maxed = level >= upgrade.MaxLevel
	local cost = bulkCost(upgrade.BaseCost, upgrade.CostScale, level, buyAmount, upgrade.MaxLevel, stardust)
	local canBuy = not maxed and lock == nil and gteFlux(stardust, cost) and gteFlux(cost, 0.01)
	local fill = meterFill(level, upgrade.MaxLevel, maxed)
	local _result
	if maxed then
		_result = "NODE COMPLETE"
	else
		local _condition_1 = lock
		if _condition_1 == nil then
			_condition_1 = `{compactNumber(cost)} dust`
		end
		_result = _condition_1
	end
	local cta = _result
	local btnW = 240
	local near = not maxed and fill >= NEAR_COMPLETE_THRESHOLD
	local meterPosition = UDim2.fromOffset(82, 76)
	local meterSize = UDim2.new(1, if stack then -96 else -(btnW + 100 + SCROLL_BAR), 0, 10)
	local unlockPop = useNodeUnlockPop(canBuy or maxed, reducedMotion)
	local tierScale = unlockPop:map(function(amount)
		return 1 + amount * 0.16
	end)
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, rowH),
		accent = if maxed then Palette.lineSoft else branch.Color,
		background = Palette.panel,
		padding = 15,
		layoutOrder = layoutOrder,
		reveal = reveal,
		interactive = not maxed,
		highlight = canBuy,
		reducedMotion = reducedMotion,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(64, 64),
		Position = UDim2.fromOffset(2, if stack then 10 else 22),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uiscale", {
		Scale = tierScale,
	}), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		Color = branch.Color,
		Thickness = 1,
		Transparency = 0.35,
	}), React.createElement(Text, {
		value = string.format("%02d", upgrade.Tier),
		size = 20,
		color = if maxed then Palette.muted else branch.Color,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.fromScale(1, 1),
	}))), React.createElement(Text, {
		value = upgrade.Name,
		size = 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(82, 6),
		sizeConstraint = UDim2.new(1, if stack then -96 else -(btnW + 100 + SCROLL_BAR), 0, 26),
	}), React.createElement(Text, {
		value = `{compactNumber(level)} / {compactNumber(upgrade.MaxLevel)}  ·  {upgrade.Description}`,
		size = 13,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(82, 36),
		sizeConstraint = UDim2.new(1, if stack then -96 else -(btnW + 100 + SCROLL_BAR), 0, 32),
	}), React.createElement(Meter, {
		value = fill,
		color = if maxed then Palette.muted else branch.Color,
		reducedMotion = reducedMotion,
		shimmer = canBuy,
		position = meterPosition,
		size = meterSize,
	}), React.createElement(NodeProgressGlow, {
		near = near,
		maxed = maxed,
		accent = branch.Color,
		reducedMotion = reducedMotion,
		position = meterPosition,
		size = meterSize,
	}), if stack then React.createElement(Button, {
		text = cta,
		icon = if maxed then "Check" else "Dust",
		onClick = function()
			if not canBuy then
				return nil
			end
			dispatch("BuyGridUpgrade", {
				Id = upgrade.Id,
				Amount = amountPayload(buyAmount),
			})
		end,
		color = if maxed then Palette.panelSoft else branch.Color,
		textColor = if maxed then Palette.muted else Palette.ink,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -(TapTarget + 10)),
		disabled = not canBuy,
		reducedMotion = reducedMotion,
		highlight = canBuy,
	}) else React.createElement(Button, {
		text = cta,
		icon = if maxed then "Check" else "Dust",
		onClick = function()
			if not canBuy then
				return nil
			end
			dispatch("BuyGridUpgrade", {
				Id = upgrade.Id,
				Amount = amountPayload(buyAmount),
			})
		end,
		color = if maxed then Palette.panelSoft else branch.Color,
		textColor = if maxed then Palette.muted else Palette.ink,
		size = UDim2.fromOffset(btnW, 52),
		position = UDim2.new(1, -(btnW + SCROLL_BAR + 10), 0.5, -26),
		disabled = not canBuy,
		reducedMotion = reducedMotion,
		highlight = canBuy,
	}))
end
local function StarGridViewComponent(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local buyAmount = _param.buyAmount
	local setBuyAmount = _param.setBuyAmount
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local touchLayout = chrome.mobile
	local antilag = useAntilag()
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local buyAllHostRef = React.useRef(nil)
	local branches = config.GridBranches or {}
	local grid = state.GridUpgrades or {}
	local nodesByBranch = React.useMemo(function()
		local grouped = {}
		for _, branch in branches do
			grouped[branch.Id] = {}
		end
		for _, upgrade in config.GridUpgrades or {} do
			local bucket = grouped[upgrade.Branch]
			if bucket ~= nil then
				table.insert(bucket, upgrade)
			end
		end
		return grouped
	end, { branches, config.GridUpgrades })
	local upgradesById = React.useMemo(function()
		local indexed = {}
		for _, upgrade in config.GridUpgrades or {} do
			indexed[upgrade.Id] = upgrade
		end
		return indexed
	end, { config.GridUpgrades })
	local headerH = if stack then 188 else 148
	local headerTextReserve = if stack then 0 else -292
	local branchH = if stack then BRANCH_H_STACK else BRANCH_H
	local nodeH = if stack then NODE_H_STACK else NODE_H
	local visible, setVisible = React.useState({})
	local windowStart, setWindowStart = React.useState({})
	local activeBranch, setActiveBranch = React.useState(function()
		local _result = branches[1]
		if _result ~= nil then
			_result = _result.Id
		end
		local _condition = _result
		if _condition == nil then
			_condition = ""
		end
		return _condition
	end)
	React.useEffect(function()
		-- ▼ ReadonlyArray.find ▼
		local _callback = function(branch)
			return branch.Id == activeBranch
		end
		local _result
		for _i, _v in branches do
			if _callback(_v, _i - 1, branches) == true then
				_result = _v
				break
			end
		end
		-- ▲ ReadonlyArray.find ▲
		if _result ~= nil then
			return nil
		end
		local _result_1 = branches[1]
		if _result_1 ~= nil then
			_result_1 = _result_1.Id
		end
		local _condition = _result_1
		if _condition == nil then
			_condition = ""
		end
		setActiveBranch(_condition)
	end, { activeBranch, branches })
	local visibleFor = function(branchId, total)
		if total <= 0 then
			return 0
		end
		local _condition = visible[branchId]
		if _condition == nil then
			_condition = GRID_CHUNK
		end
		local current = _condition
		return math.clamp(current, 1, math.min(total, GRID_MAX_VISIBLE))
	end
	local startFor = function(branchId, total, shown)
		local _condition = windowStart[branchId]
		if _condition == nil then
			_condition = 0
		end
		local start = _condition
		return math.clamp(start, 0, math.max(0, total - shown))
	end
	local expandBranch = function(branchId, total)
		local _condition = visible[branchId]
		if _condition == nil then
			_condition = GRID_CHUNK
		end
		local currentShown = _condition
		if currentShown < math.min(total, GRID_MAX_VISIBLE) then
			setVisible(function(prev)
				local _object = table.clone(prev)
				setmetatable(_object, nil)
				_object[branchId] = math.min(total, GRID_MAX_VISIBLE, currentShown + GRID_CHUNK)
				return _object
			end)
			return nil
		end
		local _condition_1 = windowStart[branchId]
		if _condition_1 == nil then
			_condition_1 = 0
		end
		local start = _condition_1
		local shown = math.min(total, GRID_MAX_VISIBLE)
		if start + shown >= total then
			return nil
		end
		setWindowStart(function(prev)
			local _object = table.clone(prev)
			setmetatable(_object, nil)
			_object[branchId] = math.min(math.max(0, total - GRID_MAX_VISIBLE), start + GRID_CHUNK)
			return _object
		end)
	end
	local collapseBranch = function(branchId)
		setVisible(function(prev)
			local _object = table.clone(prev)
			setmetatable(_object, nil)
			_object[branchId] = GRID_CHUNK
			return _object
		end)
		setWindowStart(function(prev)
			local _object = table.clone(prev)
			setmetatable(_object, nil)
			_object[branchId] = 0
			return _object
		end)
	end
	local bodyIntrinsic = 24
	local nodeStride = nodeH + Layout.panelGap
	for _, branch in branches do
		local nodes = nodesByBranch[branch.Id] or {}
		local shown = visibleFor(branch.Id, #nodes)
		local canMore = shown < #nodes
		local canLess = shown > GRID_CHUNK
		bodyIntrinsic += branchH + Layout.panelGap
		if branch.Id == activeBranch then
			-- Long node boards virtualize inside a fixed viewport so PageScaffold stays scrollable.
			if shown >= VIRT_NODE_MIN then
				bodyIntrinsic += math.min(shown, 6) * nodeStride
			else
				bodyIntrinsic += shown * nodeStride
			end
			if canMore or canLess then
				bodyIntrinsic += TapTarget + Layout.panelGap + 8
			end
		end
	end
	local order = 1
	local stagger = 0
	local _exp = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(SectionLabel, {
		value = "YOUR CONSTELLATION",
		color = Palette.mango,
	}), React.createElement(Text, {
		value = "Build the Star Grid",
		size = if stack then 28 else 34,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 28),
		sizeConstraint = UDim2.new(1, headerTextReserve, 0, 40),
	}), React.createElement(Text, {
		value = `Spend stardust on lasting routes. Bank: {compactNumber(state.Stardust)} dust.`,
		size = 14,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(0, 74),
		sizeConstraint = UDim2.new(1, headerTextReserve, 0, 40),
	}), React.createElement(AmountToggle, {
		value = buyAmount,
		onChange = setBuyAmount,
		accent = Palette.mango,
		position = if stack then UDim2.new(0, 0, 0, 124) else UDim2.new(1, -280, 0, 28),
		size = if stack then UDim2.new(0.62, -6, 0, TapTarget) else UDim2.fromOffset(268, if touchLayout then TapTarget else 42),
		reducedMotion = reducedMotion,
	}), React.createElement("frame", {
		-- FocusClaim prefers Buy-named hosts for Star Grid bulk purchase.
		Name = "StarGridBuyClaimActions",
		Size = if stack then UDim2.new(0.38, -6, 0, TapTarget) else UDim2.fromOffset(268, 36),
		Position = if stack then UDim2.new(0.62, 6, 0, 124) else UDim2.new(1, -280, 0, 72),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ref = buyAllHostRef,
	}, React.createElement(Button, {
		text = "BUY ALL",
		icon = "Dust",
		onClick = function()
			for _, upgrade in config.GridUpgrades or {} do
				local _condition = grid[upgrade.Id]
				if _condition == nil then
					_condition = 0
				end
				local level = _condition
				if level >= upgrade.MaxLevel then
					continue
				end
				if state.Rebirths < upgrade.RequiredRebirths then
					continue
				end
				local previous = if upgrade.PreviousId ~= nil then upgradesById[upgrade.PreviousId] else nil
				local _condition_1 = previous ~= nil
				if _condition_1 then
					local _condition_2 = grid[previous.Id]
					if _condition_2 == nil then
						_condition_2 = 0
					end
					_condition_1 = _condition_2 < previous.MaxLevel
				end
				if _condition_1 then
					continue
				end
				local cost = bulkCost(upgrade.BaseCost, upgrade.CostScale, level, 0, upgrade.MaxLevel, state.Stardust)
				if not gteFlux(state.Stardust, cost) then
					continue
				end
				dispatch("BuyGridUpgrade", {
					Id = upgrade.Id,
					Amount = "Max",
				})
			end
		end,
		color = Palette.mango,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		highlight = true,
	})))
	-- Gamepad: park Selection on BUY ALL for Controller Emulator FocusClaim path.
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = buyAllHostRef.current
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
	end, { buyAmount, state.Stardust, state.Rebirths })
	local _exp_1 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, Layout.panelGap),
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#branches)
	local _callback = function(branch)
		local nodes = nodesByBranch[branch.Id] or {}
		local active = branch.Id == activeBranch
		local levels = 0
		local maxLevels = 0
		for _, node in nodes do
			local _condition = grid[node.Id]
			if _condition == nil then
				_condition = 0
			end
			levels += _condition
			maxLevels += node.MaxLevel
		end
		local shown = visibleFor(branch.Id, #nodes)
		local start = startFor(branch.Id, #nodes, shown)
		local remaining = math.max(0, #nodes - (start + shown))
		local canMore = remaining > 0
		local canLess = shown > GRID_CHUNK or start > 0
		local headerOrder = order
		order += 1
		local headerStagger = math.min(stagger, 5)
		stagger += 1
		local _result
		if active then
			-- ▼ ReadonlyArray.filter ▼
			local _newValue_1 = {}
			local _callback_1 = function(_, index)
				return index >= start and index < start + shown
			end
			local _length = 0
			for _k, _v in nodes do
				if _callback_1(_v, _k - 1, nodes) == true then
					_length += 1
					_newValue_1[_length] = _v
				end
			end
			-- ▲ ReadonlyArray.filter ▲
			_result = _newValue_1
		else
			_result = {}
		end
		local slice = _result
		local virtNodes = #slice >= VIRT_NODE_MIN
		local _exp_2 = React.createElement(BranchHeader, {
			branch = branch,
			levels = levels,
			maxLevels = maxLevels,
			active = active,
			onSelect = function()
				return setActiveBranch(branch.Id)
			end,
			reducedMotion = reducedMotion,
			stack = stack,
			staggerIndex = headerStagger,
			layoutOrder = headerOrder,
		})
		local _condition = active
		if _condition then
			local renderNode = function(upgrade, index)
				local nodeOrder = order
				order += 1
				local nodeStagger = math.min(stagger, 5)
				stagger += 1
				local _result_1
				if upgrade.PreviousId ~= nil then
					local _result_2 = upgradesById[upgrade.PreviousId]
					if _result_2 ~= nil then
						_result_2 = _result_2.MaxLevel
					end
					local _condition_1 = _result_2
					if _condition_1 == nil then
						_condition_1 = upgrade.MaxLevel
					end
					_result_1 = _condition_1
				else
					_result_1 = 0
				end
				local previousMaxLevel = _result_1
				local _attributes = {
					key = upgrade.Id,
					upgrade = upgrade,
					branch = branch,
				}
				local _condition_1 = grid[upgrade.Id]
				if _condition_1 == nil then
					_condition_1 = 0
				end
				_attributes.level = _condition_1
				_attributes.buyAmount = buyAmount
				_attributes.stardust = state.Stardust
				_attributes.rebirths = state.Rebirths
				_attributes.grid = grid
				_attributes.previousMaxLevel = previousMaxLevel
				_attributes.dispatch = dispatch
				_attributes.reducedMotion = reducedMotion
				_attributes.stack = stack
				_attributes.staggerIndex = nodeStagger
				_attributes.layoutOrder = nodeOrder
				return React.createElement(NodeRow, _attributes)
			end
			if virtNodes then
				local viewportH = math.min(#slice, 6) * nodeStride
				local listOrder = order
				order += 1
				_condition = React.createElement("frame", {
					Size = UDim2.new(1, -4, 0, viewportH),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					LayoutOrder = listOrder,
				}, React.createElement(FlatList, {
					data = slice,
					itemHeight = nodeStride,
					overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
					canvasTail = 4,
					Size = UDim2.fromScale(1, 1),
					scrollBarColor = Palette.mango,
					scrollBarThickness = SCROLL_BAR,
					keyExtractor = function(upgrade)
						return upgrade.Id
					end,
					renderItem = function(_param_1)
						return renderNode(_param_1.item, _param_1.index)
					end,
				}))
			else
				-- ▼ ReadonlyArray.map ▼
				local _newValue_1 = table.create(#slice)
				for _k, _v in slice do
					_newValue_1[_k] = renderNode(_v, _k - 1)
				end
				-- ▲ ReadonlyArray.map ▲
				_condition = _newValue_1
			end
		end
		local _condition_1 = active and (canMore or canLess)
		if _condition_1 then
			local _attributes = {
				Size = UDim2.new(1, -4, 0, TapTarget + 8),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}
			local _original = order
			order += 1
			_attributes.LayoutOrder = _original
			_condition_1 = React.createElement("frame", _attributes, if canMore then React.createElement(Button, {
				text = `SHOW MORE  ({remaining} left)`,
				icon = "Chevron",
				onClick = function()
					return expandBranch(branch.Id, #nodes)
				end,
				color = Palette.panelSoft,
				textColor = Palette.cream,
				size = UDim2.new(1, 0, 0, TapTarget),
				reducedMotion = reducedMotion,
				outline = true,
			}) else React.createElement(Button, {
				text = "SHOW LESS",
				icon = "Chevron",
				onClick = function()
					return collapseBranch(branch.Id)
				end,
				color = Palette.panelSoft,
				textColor = Palette.cream,
				size = UDim2.new(1, 0, 0, TapTarget),
				reducedMotion = reducedMotion,
				outline = true,
			}))
		end
		return React.createElement(React.Fragment, {
			key = branch.Id,
		}, _exp_2, _condition, _condition_1)
	end
	for _k, _v in branches do
		_newValue[_k] = _callback(_v, _k - 1, branches)
	end
	-- ▲ ReadonlyArray.map ▲
	local bodyPane = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, _exp_1, _newValue)
	return React.createElement(PageScaffold, {
		gap = Layout.panelGap,
		tailPad = scrollTail(stack, chrome.bottomSafe),
		scrollBarColor = Palette.mango,
		scrollBarThickness = 4,
		sections = {
			{
				id = "header",
				height = headerH,
				element = _exp,
			},
			{
				id = "body",
				fill = true,
				minHeight = 160,
				height = bodyIntrinsic,
				element = bodyPane,
			},
		},
	})
end
local function sameNumberMap(left, right)
	if left == right then
		return true
	end
	if left == nil or right == nil then
		return false
	end
	local leftCount = 0
	local rightCount = 0
	for key, value in pairs(left) do
		leftCount += 1
		if right[key] ~= value then
			return false
		end
	end
	for _key in pairs(right) do
		rightCount += 1
	end
	return leftCount == rightCount
end
local StarGridView = React.memo(StarGridViewComponent, function(previous, incoming)
	return previous.config == incoming.config and previous.dispatch == incoming.dispatch and previous.setBuyAmount == incoming.setBuyAmount and previous.buyAmount == incoming.buyAmount and previous.reducedMotion == incoming.reducedMotion and previous.state.Stardust == incoming.state.Stardust and previous.state.Rebirths == incoming.state.Rebirths and sameNumberMap(previous.state.GridUpgrades, incoming.state.GridUpgrades)
end)
return {
	StarGridView = StarGridView,
}

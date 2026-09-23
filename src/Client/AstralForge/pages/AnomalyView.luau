-- Shift Plan
-- One card tells you the single best action for progress. Under it, the same
-- reactor actions stay available in plain language: pulse, bank, one boost,
-- permanent upgrades, and today's jobs.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local FlatList = require(script.Parent.Parent.virtualizedList).FlatList
local _format = require(script.Parent.Parent.format)
local compactNumber = _format.compactNumber
local gteFlux = _format.gteFlux
local scaledCost = _format.scaledCost
local _motion = require(script.Parent.Parent.motion)
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.theme)
local chromeFor = _theme.chromeFor
local Layout = _theme.Layout
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local _ui = require(script.Parent.Parent.ui)
local Button = _ui.Button
local EmptyState = _ui.EmptyState
local Meter = _ui.Meter
local Panel = _ui.Panel
local Text = _ui.Text

local PROTOCOL_ROW = 72

local function protocolLevel(anomaly, id)
	local levels = anomaly.Protocols
	if type(levels) ~= "table" then
		return 0
	end
	local level = levels[id]
	if type(level) ~= "number" then
		return 0
	end
	return level
end

local function loadoutHas(anomaly, id)
	local loadout = anomaly.Loadout
	if type(loadout) ~= "table" then
		return anomaly.Channel == id
	end
	for _, entry in loadout do
		if entry == id then
			return true
		end
	end
	return anomaly.Channel == id
end

local function claimableDirective(anomaly)
	local directives = anomaly.Directives
	if type(directives) ~= "table" then
		return nil
	end
	for _, directive in directives do
		if directive.Claimed ~= true and (tonumber(directive.Progress) or 0) >= (tonumber(directive.Target) or 1) then
			return directive
		end
	end
	return nil
end

local function cheapestProtocol(anomaly, protocols)
	local best = nil
	local bestCost = math.huge
	for _, protocol in protocols do
		local level = protocolLevel(anomaly, protocol.Id)
		local maxLevel = protocol.MaxLevel
		if maxLevel == nil or level < maxLevel then
			local cost = scaledCost(protocol.BaseCost, protocol.CostScale, level)
			local numeric = tonumber(cost)
			if numeric ~= nil and numeric < bestCost and gteFlux(anomaly.Fragments, cost) then
				best = protocol
				bestCost = numeric
			end
		end
	end
	return best
end

local function readyMilestone(anomaly)
	local milestones = anomaly.Milestones
	if type(milestones) ~= "table" then
		return nil
	end
	local done = tonumber(anomaly.Stabilizations) or 0
	for _, entry in milestones do
		if entry.Claimed ~= true and done >= (tonumber(entry.Required) or 1) then
			return entry
		end
	end
	return nil
end

local function nextStep(anomaly, config)
	local milestone = readyMilestone(anomaly)
	if milestone ~= nil then
		return {
			title = "Claim the rank reward",
			body = `You have banked enough charges for tier {compactNumber(milestone.Tier)}. Claim it before you spend fragments.`,
			accent = Palette.mango,
		}
	end
	local job = claimableDirective(anomaly)
	if job ~= nil then
		return {
			title = "Claim today's job",
			body = `{job.Name} is finished. Claiming it pays fragments you can spend on a permanent upgrade.`,
			accent = Palette.mint,
		}
	end
	if anomaly.Ready == true then
		return {
			title = "Bank the charge",
			body = "The bar is full. Banking pays rewards and starts a fresh charge. Do this before you pulse again.",
			accent = Palette.mango,
		}
	end
	local protocol = cheapestProtocol(anomaly, config.Protocols or {})
	if protocol ~= nil then
		return {
			title = `Buy {protocol.Name}`,
			body = `{protocol.Description} Permanent upgrades beat another pulse when you can already afford one.`,
			accent = Palette.cyan,
		}
	end
	local charge = math.clamp((tonumber(anomaly.Charge) or 0) / math.max(1, tonumber(anomaly.Target) or 1), 0, 1)
	return {
		title = "Pulse the charge",
		body = `The bar is {math.floor(charge * 100)}% full. Each pulse fills it. Bank it when it hits 100%.`,
		accent = Palette.pink,
	}
end

local function StepCard(props)
	local step = props.step
	return React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = step.accent,
		background = Palette.panelRaised,
		padding = 16,
		highlight = true,
		reducedMotion = props.reducedMotion,
	}, React.createElement(Text, {
		value = "DO THIS NEXT",
		size = 11,
		color = step.accent,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
		reducedMotion = props.reducedMotion,
	}), React.createElement(Text, {
		value = step.title,
		size = 24,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 16,
		position = UDim2.fromOffset(0, 20),
		sizeConstraint = UDim2.new(1, 0, 0, 32),
		reducedMotion = props.reducedMotion,
	}), React.createElement(Text, {
		value = step.body,
		size = 14,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 58),
		sizeConstraint = UDim2.new(1, 0, 0, 40),
		reducedMotion = props.reducedMotion,
	}))
end

local function ActionRow(props)
	return React.createElement("frame", {
		Size = UDim2.new(if props.wide then 1 else 0.5, if props.wide then 0 else -4, 0, TapTarget),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.order,
	}, React.createElement(Button, {
		text = props.text,
		size = UDim2.fromScale(1, 1),
		color = if props.highlight then (props.color or Palette.cyan) else Palette.panelSoft,
		textColor = if props.highlight then Palette.ink else Palette.cream,
		disabled = props.disabled,
		highlight = false,
		reducedMotion = props.reducedMotion,
		onClick = props.onClick,
	}))
end

local function ProtocolRow(props)
	local protocol = props.protocol
	local level = protocolLevel(props.anomaly, protocol.Id)
	local cost = scaledCost(protocol.BaseCost, protocol.CostScale, level)
	local affordable = gteFlux(props.anomaly.Fragments, cost)
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, PROTOCOL_ROW - 8),
		BackgroundColor3 = Palette.panel,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement(Text, {
		value = `{protocol.Name}  ·  level {compactNumber(level)}`,
		size = 14,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(10, 6),
		sizeConstraint = UDim2.new(1, -150, 0, 18),
		reducedMotion = props.reducedMotion,
	}), React.createElement(Text, {
		value = protocol.Description,
		size = 12,
		color = Palette.creamSoft,
		position = UDim2.fromOffset(10, 28),
		sizeConstraint = UDim2.new(1, -150, 0, 18),
		reducedMotion = props.reducedMotion,
	}), React.createElement(Button, {
		text = `BUY {compactNumber(cost)}`,
		disabled = not affordable,
		highlight = affordable,
		reducedMotion = props.reducedMotion,
		position = UDim2.new(1, -132, 0.5, -18),
		size = UDim2.fromOffset(122, 36),
		onClick = function()
			props.dispatch("BuyAnomalyProtocol", { Id = protocol.Id })
		end,
	}))
end

local function channelRows(config)
	local rows = {}
	local channels = config.Channels or {}
	for id, channel in channels do
		table.insert(rows, {
			id = id,
			name = channel.Name or id,
			description = channel.Description or "",
		})
	end
	table.sort(rows, function(left, right)
		return left.name < right.name
	end)
	return rows
end

local function ShiftPlan(_param)
	local anomaly = _param.anomaly
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — AnomalyView.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local claimRef = React.useRef(nil)
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = claimRef.current
		if host == nil then
			return nil
		end
		local selectJob = task.defer(function()
			if host.Parent ~= nil then
				GamepadNavigationService.FocusClaim(host)
			end
		end)
		return function()
			task.cancel(selectJob)
		end
	end, { anomaly.Ready, anomaly.Charge })
	local step = nextStep(anomaly, config)
	local charge = math.clamp((tonumber(anomaly.Charge) or 0) / math.max(1, tonumber(anomaly.Target) or 1), 0, 1)
	local protocols = config.Protocols or {}
	local channels = channelRows(config)
	local job = claimableDirective(anomaly)
	local milestone = readyMilestone(anomaly)
	local channelH = 36 + #channels * 40
	local sectionGap = if stack then chrome.panelGap else Layout.panelGap
	local sections = {
		{
			id = "step",
			height = 132,
			element = React.createElement(StepCard, {
				step = step,
				reducedMotion = softMotion,
			}),
		},
		{
			id = "actions",
			height = 80 + (if stack then TapTarget * 2 + 8 else TapTarget),
			element = React.createElement(Panel, {
				size = UDim2.fromScale(1, 1),
				accent = Palette.pink,
				background = Palette.panel,
				padding = 12,
				reducedMotion = softMotion,
				clips = false,
			}, React.createElement(Text, {
				value = `Charge {math.floor(charge * 100)}%    ·    {compactNumber(anomaly.Fragments)} fragments`,
				size = 13,
				color = Palette.cream,
				weight = Enum.FontWeight.Heavy,
				sizeConstraint = UDim2.new(1, 0, 0, 18),
				reducedMotion = softMotion,
			}), React.createElement(Meter, {
				value = charge,
				color = Palette.pink,
				reducedMotion = softMotion,
				position = UDim2.fromOffset(0, 24),
				size = UDim2.new(1, 0, 0, 8),
			}), React.createElement("frame", {
				Name = "AnomalyClaimActions",
				Size = UDim2.new(1, 0, 0, if stack then TapTarget * 2 + 8 else TapTarget),
				Position = UDim2.fromOffset(0, 44),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = false,
				ref = claimRef,
			}, React.createElement("uilistlayout", {
				FillDirection = if stack then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}), React.createElement(ActionRow, {
				order = 0,
				wide = stack,
				text = "PULSE",
				color = Palette.pink,
				highlight = anomaly.Ready ~= true,
				reducedMotion = softMotion,
				onClick = function()
					dispatch("PulseAnomaly", {})
				end,
			}), React.createElement(ActionRow, {
				order = 1,
				wide = stack,
				text = "BANK",
				color = Palette.mint,
				disabled = anomaly.Ready ~= true,
				highlight = anomaly.Ready == true,
				reducedMotion = softMotion,
				onClick = function()
					dispatch("StabilizeAnomaly", {})
				end,
			}))),
		},
		{
			id = "boost",
			height = channelH + 28,
			element = React.createElement(Panel, {
				size = UDim2.fromScale(1, 1),
				accent = Palette.cyan,
				background = Palette.panelRaised,
				padding = 12,
				reducedMotion = softMotion,
			}, React.createElement(Text, {
				value = "ONE BOOST  ·  switch it when your goal changes",
				size = 11,
				color = Palette.muted,
				weight = Enum.FontWeight.Heavy,
				sizeConstraint = UDim2.new(1, 0, 0, 16),
				reducedMotion = softMotion,
			}), (function()
				local children = {}
				for index, channel in channels do
					local on = loadoutHas(anomaly, channel.id)
					children[index] = React.createElement(Button, {
						key = channel.id,
						text = if on then `{channel.name}  ON` else channel.name,
						color = if on then Palette.cyan else Palette.panelSoft,
						textColor = if on then Palette.ink else Palette.cream,
						highlight = false,
						reducedMotion = softMotion,
						position = UDim2.fromOffset(0, 24 + (index - 1) * 40),
						size = UDim2.new(1, 0, 0, 34),
						onClick = function()
							dispatch("SetAnomalyLoadout", {
								Loadout = { channel.id },
							})
						end,
					})
				end
				return React.createElement("frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, table.unpack(children))
			end)()),
		},
		{
			id = "upgrades",
			height = 36 + math.max(1, #protocols) * PROTOCOL_ROW,
			element = React.createElement(FlatList, {
				data = protocols,
				itemHeight = PROTOCOL_ROW,
				headerHeight = 28,
				overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
				canvasTail = 8,
				Size = UDim2.fromScale(1, 1),
				scrollBarColor = Palette.cyan,
				scrollBarThickness = 3,
				keyExtractor = function(protocol)
					return protocol.Id
				end,
				renderItem = function(row)
					return React.createElement(ProtocolRow, {
						protocol = row.item,
						anomaly = anomaly,
						dispatch = dispatch,
						reducedMotion = softMotion,
					})
				end,
				ListHeaderComponent = React.createElement("frame", {
					Size = UDim2.new(1, 0, 0, 28),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, React.createElement(Text, {
					value = "PERMANENT UPGRADES  ·  bought with fragments",
					size = 11,
					color = Palette.muted,
					weight = Enum.FontWeight.Heavy,
					sizeConstraint = UDim2.new(1, 0, 0, 16),
					reducedMotion = softMotion,
				})),
			}),
		},
	}
	if milestone ~= nil then
		table.insert(sections, 3, {
			id = "milestone",
			height = 88,
			element = React.createElement(Panel, {
				size = UDim2.fromScale(1, 1),
				accent = Palette.mango,
				background = Palette.panelRaised,
				padding = 12,
				reducedMotion = softMotion,
			}, React.createElement(Text, {
				value = `Tier {compactNumber(milestone.Tier)} reward is ready`,
				size = 16,
				color = Palette.cream,
				weight = Enum.FontWeight.Heavy,
				sizeConstraint = UDim2.new(1, -140, 0, 22),
				reducedMotion = softMotion,
			}), React.createElement(Button, {
				text = "CLAIM",
				highlight = true,
				reducedMotion = softMotion,
				position = UDim2.new(1, -120, 0.5, -18),
				size = UDim2.fromOffset(110, 36),
				onClick = function()
					dispatch("ClaimAnomalyMilestone", { Tier = milestone.Tier })
				end,
			})),
		})
	end
	if job ~= nil then
		table.insert(sections, 3, {
			id = "job",
			height = 88,
			element = React.createElement(Panel, {
				size = UDim2.fromScale(1, 1),
				accent = Palette.mint,
				background = Palette.panelRaised,
				padding = 12,
				reducedMotion = softMotion,
			}, React.createElement(Text, {
				value = job.Name,
				size = 16,
				color = Palette.cream,
				weight = Enum.FontWeight.Heavy,
				sizeConstraint = UDim2.new(1, -140, 0, 22),
				reducedMotion = softMotion,
			}), React.createElement(Button, {
				text = "CLAIM",
				highlight = true,
				reducedMotion = softMotion,
				position = UDim2.new(1, -120, 0.5, -18),
				size = UDim2.fromOffset(110, 36),
				onClick = function()
					dispatch("ClaimAnomalyDirective", { Id = job.Id })
				end,
			})),
		})
	end
	return React.createElement(PageScaffold, {
		gap = sectionGap,
		tailPad = scrollTail(stack, chrome.bottomSafe, if stack then 56 else 40),
		scrollBarColor = Palette.pink,
		scrollBarThickness = 4,
		sections = sections,
	})
end

local function loadoutKey(anomaly)
	if type(anomaly.Loadout) ~= "table" then
		return tostring(anomaly.Channel)
	end
	return table.concat(anomaly.Loadout, ",")
end

local function protocolKey(anomaly)
	if type(anomaly.Protocols) ~= "table" then
		return ""
	end
	local parts = {}
	for id, level in anomaly.Protocols do
		table.insert(parts, `{id}:{level}`)
	end
	table.sort(parts)
	return table.concat(parts, ",")
end

local function AnomalyViewComponent(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	if state.Anomaly == nil or config.Anomalies == nil then
		return React.createElement(EmptyState, {
			icon = "Anomaly",
			title = "Shift plan resting",
			body = "Come back when the next charge window starts.",
			accent = Palette.pink,
		})
	end
	return React.createElement(ShiftPlan, {
		anomaly = state.Anomaly,
		config = config.Anomalies,
		dispatch = dispatch,
		reducedMotion = reducedMotion,
	})
end

local AnomalyView = React.memo(AnomalyViewComponent, function(previous, incoming)
	local left = previous.state.Anomaly
	local right = incoming.state.Anomaly
	if left == right then
		return previous.reducedMotion == incoming.reducedMotion and previous.config == incoming.config and previous.dispatch == incoming.dispatch
	end
	if left == nil or right == nil then
		return false
	end
	return previous.config == incoming.config
		and previous.dispatch == incoming.dispatch
		and previous.reducedMotion == incoming.reducedMotion
		and left.Charge == right.Charge
		and left.Target == right.Target
		and left.Ready == right.Ready
		and left.Fragments == right.Fragments
		and left.Channel == right.Channel
		and loadoutKey(left) == loadoutKey(right)
		and protocolKey(left) == protocolKey(right)
		and left.Stabilizations == right.Stabilizations
		and #(left.Directives or {}) == #(right.Directives or {})
		and #(left.Milestones or {}) == #(right.Milestones or {})
end)

return {
	AnomalyView = AnomalyView,
}

local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local PlayerMark = require(script.Parent.Parent.Icon).PlayerMark
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local _motion = require(script.Parent.Parent.motion)
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _ui = require(script.Parent.Parent.ui)
local Button = _ui.Button
local EmptyState = _ui.EmptyState
local Meter = _ui.Meter
local meterFill = _ui.meterFill
local Panel = _ui.Panel
local Text = _ui.Text
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local FlatList = require(script.Parent.Parent.virtualizedList).FlatList
local _theme = require(script.Parent.Parent.theme)
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local lighten = _theme.lighten
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local _format = require(script.Parent.Parent.format)
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local AppHelpers = require(script.Parent.Parent.appNav).AppHelpers
local PageReadyMath = require(script.Parent.Parent.pageReadyMath)
local PageBoardHeights = require(script.Parent.Parent.pageBoardHeights)

local function CrewRow(_param)
	local player = _param.player
	local visiting = _param.visiting
	local visitorsHere = _param.visitorsHere
	local onVisit = _param.onVisit
	local onNudge = _param.onNudge
	local reducedMotion = _param.reducedMotion
	local layoutOrder = _param.layoutOrder
	local stack = _param.stack
	local reveal = useStagger(math.min(layoutOrder, 8), reducedMotion)
	local accent = if player.IsLocal then Palette.green else Palette.blue
	local rowH = if stack then (if player.IsLocal then 118 else 158) else 100
	local pad = if stack then 14 else 12
	local _exp = React.createElement("frame", {
		Size = UDim2.fromOffset(if stack then 48 else 44, if stack then 48 else 44),
		Position = UDim2.fromOffset(0, if stack then 8 else 14),
		BackgroundColor3 = darken(accent, 0.62),
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(accent, 0.12), darken(accent, 0.48)),
		Rotation = 120,
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = accent,
		Thickness = 1,
		Transparency = 0.32,
	}), React.createElement(PlayerMark, {
		userId = player.UserId,
		color = Palette.ink,
		accent = accent,
		size = if stack then 42 else 38,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	}))
	local _exp_1 = React.createElement(Text, {
		value = if player.IsLocal then "YOU" else player.DisplayName,
		size = if stack then 17 else 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(58, 2),
		sizeConstraint = UDim2.new(1, if stack then -(58 + 16) else -280, 0, 22),
	})
	local _exp_2 = React.createElement(Text, {
		value = `World {player.CurrentZone}`,
		size = if stack then 12 else 10,
		color = Palette.muted,
		fit = false,
		position = UDim2.fromOffset(58, 28),
		sizeConstraint = UDim2.fromOffset(80, 16),
	})
	local _exp_3 = React.createElement(Text, {
		value = `{compactNumber(player.Production)} /s`,
		size = if stack then 12 else 10,
		color = Palette.muted,
		fit = false,
		position = UDim2.fromOffset(144, 28),
		sizeConstraint = UDim2.new(1, -160, 0, 16),
	})
	local _condition = not player.IsLocal
	if _condition then
		local _attributes = {}
		local _condition_1 = player.CurrentPage
		if _condition_1 == nil then
			_condition_1 = "Overview"
		end
		_attributes.value = `Browsing {AppHelpers:pageEntry(_condition_1).label}`
		_attributes.size = if stack then 11 else 9
		_attributes.color = if player.PresenceAge ~= nil and player.PresenceAge >= 0 and player.PresenceAge < 12 then Palette.mint else Palette.muted
		_attributes.weight = Enum.FontWeight.Bold
		_attributes.fit = true
		_attributes.minSize = 8
		_attributes.position = UDim2.fromOffset(58, if stack then 52 else 56)
		_attributes.sizeConstraint = UDim2.new(1, if stack then -(58 + 16) else -16, 0, 16)
		_condition = React.createElement(Text, _attributes)
	end
	return React.createElement(Panel, {
		size = UDim2.new(1, -4, 0, rowH),
		accent = accent,
		background = if visiting then Palette.panelRaised else Palette.panel,
		padding = pad,
		layoutOrder = layoutOrder,
		reveal = reveal,
		interactive = not player.IsLocal,
		highlight = visiting,
		reducedMotion = reducedMotion,
		clips = false,
	}, _exp, _exp_1, _exp_2, _exp_3, _condition, if player.IsLocal then React.createElement(Text, {
		value = if visitorsHere > 0 then `{visitorsHere} visiting your shop` else `{player.Rebirths} resets`,
		size = if stack then 12 else 10,
		color = if visitorsHere > 0 then Palette.mango else accent,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(58, if stack then 52 else 56),
		sizeConstraint = UDim2.new(1, if stack then -(58 + 16) else -16, 0, 18),
	}) elseif stack then React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, TapTarget),
		Position = UDim2.new(0, 0, 1, -(TapTarget + 2)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement("frame", {
		Size = UDim2.new(0.5, -4, 0, TapTarget),
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Button, {
		text = "WAVE",
		icon = "Wave",
		onClick = onNudge,
		color = Palette.cyan,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Name = "CrewVisitConfirm",
		Size = UDim2.new(0.5, -4, 0, TapTarget),
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(Button, {
		text = if visiting then "HERE" else "VISIT",
		icon = "Visit",
		onClick = onVisit,
		color = if visiting then Palette.green else Palette.blue,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = visiting,
		highlight = visiting,
	}))) else React.createElement("frame", {
		Size = UDim2.fromOffset(0, TapTarget),
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Button, {
		text = "WAVE",
		icon = "Wave",
		onClick = onNudge,
		color = Palette.cyan,
		textColor = Palette.ink,
		size = UDim2.fromOffset(0, TapTarget),
		hug = true,
		reducedMotion = reducedMotion,
	}), React.createElement("frame", {
		Name = "CrewVisitConfirm",
		Size = UDim2.fromOffset(0, TapTarget),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		LayoutOrder = 2,
	}, React.createElement(Button, {
		text = if visiting then "HERE" else "VISIT",
		icon = "Visit",
		onClick = onVisit,
		color = if visiting then Palette.green else Palette.blue,
		textColor = Palette.ink,
		size = UDim2.fromOffset(0, TapTarget),
		hug = true,
		reducedMotion = reducedMotion,
		disabled = visiting,
		highlight = visiting,
	}))))
end
local function VisitPanel(_param)
	local visit = _param.visit
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local layoutOrder = _param.layoutOrder
	local stack = _param.stack
	local reveal = useStagger(0, reducedMotion)
	local vaultFill = meterFill(asFlux(visit.Vault), asFlux(visit.Capacity))
	local machineBits = {}
	for id, level in pairs(visit.Machines) do
		if #machineBits < 4 then
			local _arg0 = `{id} {level}`
			table.insert(machineBits, _arg0)
		end
	end
	local lineWord = if visit.MachineKinds == 1 then "line" else "lines"
	local machineLine = if #machineBits > 0 then `{visit.MachineKinds} {lineWord} · {machineBits[1]}{if machineBits[2] ~= nil then `  ·  {machineBits[2]}` else ""}{if machineBits[3] ~= nil then `  ·  {machineBits[3]}` else ""}` else "No machines built yet"
	local _exp = React.createElement(Text, {
		value = "VISITING",
		size = 10,
		color = Palette.blue,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, if stack then 0 else -160, 0, 16),
	})
	local _exp_1 = React.createElement(Text, {
		value = visit.DisplayName,
		size = 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 20),
		sizeConstraint = UDim2.new(1, if stack then 0 else -160, 0, 30),
	})
	local _exp_2 = React.createElement(Text, {
		value = `World {visit.CurrentZone}  ·  {visit.Rebirths} resets  ·  live`,
		size = 11,
		color = Palette.creamSoft,
		fit = false,
		position = UDim2.fromOffset(0, 54),
		sizeConstraint = UDim2.new(1, if stack then 0 else -160, 0, 18),
	})
	local _exp_3 = React.createElement(Button, {
		text = "LEAVE",
		icon = "Close",
		onClick = function()
			return dispatch("LeavePlot")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(120, 40),
		position = if stack then UDim2.new(0, 0, 1, -(TapTarget + 4)) else UDim2.new(1, -120, 0, 12),
		reducedMotion = reducedMotion,
	})
	local _exp_4 = { {
		label = "FLUX / SEC",
		value = visit.Production,
		color = Palette.green,
	}, {
		label = "BALANCE",
		value = visit.Cash,
		color = Palette.cream,
	}, {
		label = "CORES",
		value = visit.Cores,
		color = Palette.violet,
	}, {
		label = "STARDUST",
		value = visit.Stardust,
		color = Palette.cyan,
	} }
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#_exp_4)
	local _callback = function(stat, index)
		return React.createElement("frame", {
			key = stat.label,
			Size = if stack then UDim2.new(0.5, -4, 0, 72) else UDim2.new(0.25, -6, 1, 0),
			Position = if stack then UDim2.new(if index % 2 == 0 then 0 else 0.5, if index % 2 == 0 then 0 else 4, 0, if index < 2 then 0 else 80) else UDim2.new(index * 0.25, if index == 0 then 0 else 2, 0, 0),
			BackgroundColor3 = Palette.panel,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 10),
		}), React.createElement(Text, {
			value = stat.label,
			size = 9,
			color = Palette.muted,
			weight = Enum.FontWeight.Bold,
			fit = false,
			position = UDim2.fromOffset(10, 10),
			sizeConstraint = UDim2.new(1, -20, 0, 14),
		}), React.createElement(NumberSpinnerHost, {
			value = asFlux(stat.value),
			reducedMotion = reducedMotion,
			duration = 0.4,
			size = 16,
			color = stat.color,
			position = UDim2.fromOffset(10, 32),
			sizeConstraint = UDim2.new(1, -20, 0, 24),
		}))
	end
	for _k, _v in _exp_4 do
		_newValue[_k] = _callback(_v, _k - 1, _exp_4)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, PageBoardHeights.Visit(stack)),
		accent = Palette.blue,
		background = Palette.panelRaised,
		padding = 16,
		layoutOrder = layoutOrder,
		reveal = reveal,
		highlight = true,
		reducedMotion = reducedMotion,
		clips = false,
	}, _exp, _exp_1, _exp_2, _exp_3, React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, if stack then 152 else 72),
		Position = UDim2.fromOffset(0, if stack then 76 else 86),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, _newValue), React.createElement(Text, {
		value = `Vault {compactNumber(visit.Vault)} / {compactNumber(visit.Capacity)}`,
		size = 10,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, if stack then 238 else 170),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Meter, {
		value = vaultFill,
		color = Palette.blue,
		reducedMotion = reducedMotion,
		position = UDim2.fromOffset(0, if stack then 258 else 192),
		size = UDim2.new(1, 0, 0, 7),
	}), React.createElement(Text, {
		value = machineLine,
		size = 10,
		color = Palette.creamSoft,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(0, if stack then 274 else 210),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	}))
end
local function sameCrewSnapshot(left, right)
	return PageReadyMath.SameCrewSnapshot(left, right)
end
local function CrewView(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local visit = _param.visit
	local setVisit = _param.setVisit
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — Crew roster FlatList overscan drops on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local players, setPlayers = React.useState({})
	local mountedRef = React.useRef(true)
	local visitAttemptRef = React.useRef(0)
	local crewHostRef = React.useRef(nil)
	React.useEffect(function()
		return function()
			mountedRef.current = false
			visitAttemptRef.current += 1
		end
	end, {})
	local refresh = React.useCallback(function()
		return dispatch("GetPlayers", {}, function(response)
			if not mountedRef.current or not response.ok then
				return nil
			end
			local raw = response.Players or {}
			local cleaned = {}
			for _, entry in raw do
				local _userId = entry.UserId
				local id = if type(_userId) == "number" then math.floor(entry.UserId) else tonumber(tostring(entry.UserId))
				if id == nil or id ~= id or id == 0 then
					continue
				end
				local _object = table.clone(entry)
				setmetatable(_object, nil)
				_object.UserId = id
				table.insert(cleaned, _object)
			end
			setPlayers(function(current)
				return if sameCrewSnapshot(current, cleaned) then current else cleaned
			end)
		end)
	end, { dispatch })
	React.useEffect(function()
		refresh()
	end, { refresh })
	React.useEffect(function()
		local joined = Players.PlayerAdded:Connect(refresh)
		local left = Players.PlayerRemoving:Connect(refresh)
		return function()
			joined:Disconnect()
			left:Disconnect()
		end
	end, { refresh })
	React.useEffect(function()
		local worker = task.spawn(function()
			while true do
				task.wait(4)
				refresh()
			end
		end)
		return function()
			pcall(function()
				return task.cancel(worker)
			end)
		end
	end, { refresh })
	-- Gamepad: park Selection on VISIT (FocusClaim prefers Confirm-named hosts).
	local crewFocusReady = #players > 0
	React.useEffect(function()
		if not crewFocusReady or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = crewHostRef.current
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
	end, { crewFocusReady, #players })
	local _visitUserId = visit
	if _visitUserId ~= nil then
		_visitUserId = _visitUserId.UserId
	end
	local visitUserId = _visitUserId
	local coerceCrewId = function(raw)
		local _raw = raw
		local _result
		if type(_raw) == "number" then
			_result = raw
		else
			local _raw_1 = raw
			_result = if type(_raw_1) == "string" then tonumber(raw) else nil
		end
		local asNumber = _result
		if asNumber == nil or asNumber ~= asNumber then
			return nil
		end
		local id = math.floor(asNumber + (if asNumber >= 0 then 1e-9 else -1e-9))
		if id == 0 then
			return nil
		end
		return id
	end
	local startVisit = function(userId)
		local id = coerceCrewId(userId)
		if id == nil then
			return nil
		end
		local attempt = visitAttemptRef.current + 1
		visitAttemptRef.current = attempt
		dispatch("VisitPlot", {
			UserId = id,
			userId = id,
		}, function(response)
			if not mountedRef.current or visitAttemptRef.current ~= attempt then
				return nil
			end
			if not response.ok then
				return nil
			end
			if response.Visit then
				setVisit(response.Visit)
			else
				local _result = response.State
				if _result ~= nil then
					_result = _result.Visit
				end
				if _result then
					setVisit(response.State.Visit)
				end
			end
		end)
	end
	local nudgeCrew = function(userId)
		local id = coerceCrewId(userId)
		if id == nil then
			return nil
		end
		dispatch("NudgeCrew", {
			UserId = id,
			userId = id,
		})
	end
	local headerReveal = useStagger(0, softMotion)
	local _result = state.Visitors
	if _result ~= nil then
		_result = #_result
	end
	local _condition = _result
	if _condition == nil then
		_condition = 0
	end
	local visitorsHere = _condition
	local rowStride = if stack then 176 else 124
	local headerH = if stack then 130 else 112
	local listGap = if visit ~= nil then math.max(chrome.panelGap, 18) else math.max(chrome.panelGap, 12)
	local visitBlock = if visit ~= nil then PageBoardHeights.Visit(stack) else 0
	local crewTail = scrollTail(stack, chrome.bottomSafe, 48)
	local headerPanel = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.blue,
		background = Palette.panelRaised,
		padding = chrome.cardPadding,
		layoutOrder = 0,
		reveal = headerReveal,
		clips = false,
	}, React.createElement(Text, {
		value = "CREW ROSTER",
		size = 10,
		color = Palette.blue,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, if stack then -8 else -160, 0, 18),
	}), React.createElement(Text, {
		value = "Crew on this server",
		size = if stack then 20 else 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 20),
		sizeConstraint = UDim2.new(1, if stack then -8 else -190, 0, 30),
	}), React.createElement(Text, {
		value = if visitorsHere > 0 then `{visitorsHere} visiting your forge. Pick someone below to visit or send a wave.` else "See what everyone's up to live, visit a forge, or send a wave. Invites and friend boosts live in Playerlist.",
		size = chrome.labelText,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(0, 54),
		sizeConstraint = UDim2.new(1, if stack then -8 else -190, 0, 38),
	}), React.createElement(Button, {
		text = if stack then "REFRESH" else "REFRESH CREW",
		icon = "Refresh",
		onClick = refresh,
		sound = "tick",
		color = Palette.blue,
		textColor = Palette.ink,
		size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(170, 44),
		position = if stack then UDim2.new(0, 0, 1, -TapTarget) else UDim2.new(1, -170, 0, 24),
		reducedMotion = softMotion,
	}))
	local visitPanel = visit ~= nil and React.createElement(VisitPanel, {
		visit = visit,
		dispatch = dispatch,
		reducedMotion = softMotion,
		layoutOrder = 1,
		stack = stack,
	})
	local emptyPanel = #players == 0 and React.createElement(EmptyState, {
		icon = "Crew",
		title = "No one else is on shift",
		body = "Crew shows up here once someone else is online with you.",
		accent = Palette.blue,
		layoutOrder = 2,
	})
	local sections = {
		{
			id = "header",
			height = headerH,
			element = headerPanel,
		},
	}
	if visitPanel then
		table.insert(sections, {
			id = "visit",
			height = PageBoardHeights.Visit(stack),
			element = visitPanel,
		})
	end
	if emptyPanel then
		table.insert(sections, {
			id = "empty",
			height = 180,
			element = emptyPanel,
		})
	end
	-- Long crew rosters virtualize inside FlatList; short lists keep per-row PageScaffold sections.
	local virtRoster = #players >= 8
	if virtRoster then
		local rosterCards = table.create(#players)
		for index, player in players do
			rosterCards[index] = React.createElement(CrewRow, {
				key = player.UserId,
				player = player,
				visiting = visitUserId == player.UserId,
				visitorsHere = if player.IsLocal then visitorsHere else 0,
				onVisit = function()
					return startVisit(player.UserId)
				end,
				onNudge = function()
					return nudgeCrew(player.UserId)
				end,
				reducedMotion = softMotion,
				layoutOrder = index,
				stack = stack,
			})
		end
		table.insert(sections, {
			id = "roster",
			fill = true,
			minHeight = 120,
			element = React.createElement(FlatList, {
				data = players,
				itemHeight = rowStride,
				overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
				canvasTail = 8,
				Size = UDim2.fromScale(1, 1),
				scrollBarColor = Palette.blue,
				scrollBarThickness = 4,
				keyExtractor = function(player)
					return player.UserId
				end,
				renderItem = function(_param_1)
					local index = _param_1.index
					return rosterCards[index + 1]
				end,
			}),
		})
	else
		for index, player in players do
			table.insert(sections, {
				id = "crew-" .. tostring(index),
				height = rowStride,
				element = React.createElement(CrewRow, {
					key = player.UserId,
					player = player,
					visiting = visitUserId == player.UserId,
					visitorsHere = if player.IsLocal then visitorsHere else 0,
					onVisit = function()
						return startVisit(player.UserId)
					end,
					onNudge = function()
						return nudgeCrew(player.UserId)
					end,
					reducedMotion = softMotion,
					layoutOrder = index + 3,
					stack = stack,
				}),
			})
		end
	end
	return React.createElement("frame", {
		ref = crewHostRef,
		Name = "CrewVisitClaim",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(PageScaffold, {
		gap = listGap,
		tailPad = crewTail,
		scrollBarColor = Palette.blue,
		scrollBarThickness = 4,
		sections = sections,
	}))
end

return {
	CrewView = CrewView,
}

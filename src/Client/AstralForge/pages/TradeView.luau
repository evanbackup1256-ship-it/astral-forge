local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.Parent.audio).Audio
local unixNow = require(script.Parent.Parent.deadlines).unixNow
local _format = require(script.Parent.Parent.format)
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local Icon = require(script.Parent.Parent.Icon).Icon
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local _motion = require(script.Parent.Parent.motion)
local useEntrance = _motion.useEntrance
local useViewport = _motion.useViewport
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local _theme = require(script.Parent.Parent.theme)
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local Layout = _theme.Layout
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local _ui = require(script.Parent.Parent.ui)
local Badge = _ui.Badge
local Button = _ui.Button
local EmptyState = _ui.EmptyState
local IconTile = _ui.IconTile
local Panel = _ui.Panel
local QuantityStepper = _ui.QuantityStepper
local SearchField = _ui.SearchField
local SectionLabel = _ui.SectionLabel
local SegmentedTabs = _ui.SegmentedTabs
local Stroke = _ui.Stroke
local Text = _ui.Text
local BOOSTS = { "DomainSurge", "Overdrive", "Hyperdrive", "VaultSurge", "NightShift", "FoundryRush", "Afterburner", "SteadyBurn", "CoreSurge", "StarforgeFlow", "EchoDrive", "Ionstorm", "TwinCatalyst", "MidnightForge" }
local KEYS = { "ForgeCrate", "CrystalCrate", "HorizonCrate", "NebulaCrate", "OrbitCrate", "SingularityCrate", "EchoCrate" }
local BOOST_LABELS = {
	Overdrive = "Overdrive",
	Hyperdrive = "Hyperdrive",
	VaultSurge = "Vault Surge",
	DomainSurge = "Domain Surge",
	NightShift = "Night Shift",
	FoundryRush = "Foundry Rush",
	Afterburner = "Afterburner",
	SteadyBurn = "Steady Burn",
	CoreSurge = "Core Surge",
	StarforgeFlow = "Starforge Flow",
	EchoDrive = "Echo Drive",
	Ionstorm = "Ionstorm",
	TwinCatalyst = "Twin Catalyst",
	MidnightForge = "Midnight Forge",
}
local KEY_LABELS = {
	ForgeCrate = "Forge key",
	CrystalCrate = "Crystal key",
	HorizonCrate = "Horizon key",
	NebulaCrate = "Nebula key",
	OrbitCrate = "Orbit key",
	SingularityCrate = "Singularity key",
	EchoCrate = "Echo key",
}
local function emptyOffer()
	return {
		Cash = 0,
		Stardust = 0,
		Cores = 0,
		Signals = 0,
		Essence = 0,
		Boosts = {
			DomainSurge = 0,
			Overdrive = 0,
			Hyperdrive = 0,
			VaultSurge = 0,
			NightShift = 0,
			FoundryRush = 0,
			Afterburner = 0,
			SteadyBurn = 0,
			CoreSurge = 0,
			StarforgeFlow = 0,
			EchoDrive = 0,
			Ionstorm = 0,
			TwinCatalyst = 0,
			MidnightForge = 0,
		},
		Keys = {
			ForgeCrate = 0,
			CrystalCrate = 0,
			HorizonCrate = 0,
			NebulaCrate = 0,
			OrbitCrate = 0,
			SingularityCrate = 0,
			EchoCrate = 0,
		},
		ItemIds = {},
		Items = {},
	}
end
local function itemName(config, definitionId)
	local _result = config.Items
	if _result ~= nil then
		_result = _result.Definitions
	end
	local _condition = _result
	if _condition == nil then
		_condition = {}
	end
	for _, definition in _condition do
		if definition.Id == definitionId then
			return definition.Name
		end
	end
	return definitionId
end
local function clockLabel(deadline, now)
	local left = math.max(0, math.floor(deadline - now))
	local minutes = math.floor(left / 60)
	local seconds = left % 60
	return if minutes > 0 then `{minutes}:{string.format("%02d", seconds)}` else `{seconds}s`
end
local function offerEmpty(offer)
	if offer.Cash > 0 or offer.Stardust > 0 or offer.Cores > 0 or offer.Signals > 0 or offer.Essence > 0 then
		return false
	end
	for _, id in BOOSTS do
		local _condition = offer.Boosts[id]
		if _condition == nil then
			_condition = 0
		end
		if _condition > 0 then
			return false
		end
	end
	for _, id in KEYS do
		local _condition = offer.Keys[id]
		if _condition == nil then
			_condition = 0
		end
		if _condition > 0 then
			return false
		end
	end
	return #offer.ItemIds == 0
end
local function offerLines(offer, config, inventory)
	local lines = {}
	if offer.Cash > 0 then
		local _arg0 = {
			key = "cash",
			label = `{compactNumber(offer.Cash)} Flux`,
			detail = "Currency",
			accent = Palette.cyan,
			icon = "Flux",
		}
		table.insert(lines, _arg0)
	end
	if offer.Stardust > 0 then
		local _arg0 = {
			key = "dust",
			label = `{compactNumber(offer.Stardust)} Stardust`,
			detail = "Dust",
			accent = Palette.mango,
			icon = "Dust",
		}
		table.insert(lines, _arg0)
	end
	if offer.Cores > 0 then
		local _arg0 = {
			key = "cores",
			label = `{offer.Cores} Cores`,
			detail = "Prestige",
			accent = Palette.violet,
			icon = "Core",
		}
		table.insert(lines, _arg0)
	end
	if offer.Signals > 0 then
		local _arg0 = {
			key = "signals",
			label = `{offer.Signals} Signals`,
			detail = "Command",
			accent = Palette.cyan,
			icon = "Command",
		}
		table.insert(lines, _arg0)
	end
	if offer.Essence > 0 then
		local _arg0 = {
			key = "essence",
			label = `{offer.Essence} Essence`,
			detail = "Relic craft",
			accent = Palette.pink,
			icon = "Artifact",
		}
		table.insert(lines, _arg0)
	end
	for _, id in BOOSTS do
		local _condition = offer.Boosts[id]
		if _condition == nil then
			_condition = 0
		end
		local count = _condition
		if count > 0 then
			local _object = {
				key = `boost-{id}`,
			}
			local _left = "label"
			local _condition_1 = BOOST_LABELS[id]
			if _condition_1 == nil then
				_condition_1 = id
			end
			_object[_left] = `{count}× {_condition_1}`
			_object.detail = "Boost"
			_object.accent = Palette.coral
			_object.icon = "Boost"
			table.insert(lines, _object)
		end
	end
	for _, id in KEYS do
		local _condition = offer.Keys[id]
		if _condition == nil then
			_condition = 0
		end
		local count = _condition
		if count > 0 then
			local _object = {
				key = `key-{id}`,
			}
			local _left = "label"
			local _condition_1 = KEY_LABELS[id]
			if _condition_1 == nil then
				_condition_1 = id
			end
			_object[_left] = `{count}× {_condition_1}`
			_object.detail = "Crate key"
			_object.accent = Palette.mango
			_object.icon = "Crate"
			table.insert(lines, _object)
		end
	end
	local previews = offer.Items or {}
	if #previews > 0 then
		for _, preview in previews do
			local _arg0 = {
				key = preview.Uid,
				label = preview.Name,
				detail = "Relic",
				accent = Palette.mint,
				icon = "Inventory",
			}
			table.insert(lines, _arg0)
		end
	else
		for _, uid in offer.ItemIds do
			local instance = inventory[uid]
			local _arg0 = {
				key = uid,
				label = if instance ~= nil then itemName(config, instance.DefinitionId) else "Relic",
				detail = "Relic",
				accent = Palette.mint,
				icon = "Inventory",
			}
			table.insert(lines, _arg0)
		end
	end
	return lines
end
local function useSecondClock()
	local now, setNow = React.useState(unixNow())
	React.useEffect(function()
		local worker = task.spawn(function()
			while true do
				task.wait(0.5)
				setNow(unixNow())
			end
		end)
		return function()
			return task.cancel(worker)
		end
	end, {})
	return now
end
local function AvatarMark(_param)
	local userId = _param.userId
	local accent = _param.accent
	local size = _param.size
	local position = _param.position
	return React.createElement("frame", {
		Size = UDim2.fromOffset(size, size),
		Position = position,
		BackgroundColor3 = darken(accent, 0.62),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement(Stroke, {
		color = accent,
		thickness = 1,
		transparency = 0.28,
	}), React.createElement("imagelabel", {
		Size = UDim2.new(1, -4, 1, -4),
		Position = UDim2.fromOffset(2, 2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`,
		ScaleType = Enum.ScaleType.Crop,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end
local function StatusChip(_param)
	local label = _param.label
	local live = _param.live
	local accent = _param.accent
	return React.createElement("frame", {
		Size = UDim2.fromOffset(0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = if live then darken(accent, 0.72) else Palette.panelSoft,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement(Stroke, {
		color = if live then accent else Palette.lineSoft,
		thickness = 1,
		transparency = if live then 0.2 else 0.55,
	}), React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement("uipadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 12),
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(7, 7),
		BackgroundColor3 = if live then accent else Palette.muted,
		BorderSizePixel = 0,
		LayoutOrder = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement(Text, {
		value = label,
		size = 12,
		color = if live then Palette.cream else Palette.muted,
		weight = Enum.FontWeight.Bold,
		layoutOrder = 1,
		sizeConstraint = UDim2.new(0, math.max(78, #label * 8), 1, 0),
	}))
end
local function OfferRow(_param)
	local line = _param.line
	local touch = _param.touch
	if touch == nil then
		touch = false
	end
	local rowH = if touch then 56 else 50
	local tile = if touch then 40 else 36
	local textX = tile + 16
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, rowH),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement(Stroke, {
		color = line.accent,
		thickness = 1,
		transparency = 0.5,
	}), React.createElement(IconTile, {
		kind = line.icon,
		accent = line.accent,
		size = tile,
		radius = 10,
		position = UDim2.fromOffset(8, math.floor((rowH - tile) / 2)),
		spin = false,
		reducedMotion = true,
	}), React.createElement(Text, {
		value = line.label,
		size = 15,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(textX, if touch then 6 else 5),
		sizeConstraint = UDim2.new(1, -(textX + 12), 0, 22),
	}), React.createElement(Text, {
		value = line.detail,
		size = 12,
		color = line.accent,
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(textX, if touch then 30 else 28),
		sizeConstraint = UDim2.new(1, -(textX + 12), 0, 16),
	}))
end
local function RelicPick(_param)
	local uid = _param.uid
	local name = _param.name
	local picked = _param.picked
	local reducedMotion = _param.reducedMotion
	local onToggle = _param.onToggle
	local touch = _param.touch
	if touch == nil then
		touch = false
	end
	return React.createElement(Button, {
		text = `{if picked then "IN OFFER  ·  " else ""}{name}`,
		icon = "Inventory",
		onClick = onToggle,
		color = if picked then Palette.mint else Palette.panelSoft,
		textColor = if picked then Palette.ink else Palette.cream,
		size = UDim2.new(1, 0, 0, if touch then TapTarget else 40),
		reducedMotion = reducedMotion,
		highlight = picked,
	})
end
local function TradeView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local enter = useEntrance(reducedMotion)
	local now = useSecondClock()
	local trade = state.Trade
	local _result = trade
	if _result ~= nil then
		_result = _result.Unlocked
	end
	local unlocked = _result == true
	local _session = trade
	if _session ~= nil then
		_session = _session.Session
	end
	local session = _session
	local _invite = trade
	if _invite ~= nil then
		_invite = _invite.Invite
	end
	local invite = _invite
	local _outgoing = trade
	if _outgoing ~= nil then
		_outgoing = _outgoing.Outgoing
	end
	local outgoing = _outgoing
	local _daily = trade
	if _daily ~= nil then
		_daily = _daily.Daily
	end
	local daily = _daily
	local rows, setRows = React.useState({})
	local query, setQuery = React.useState("")
	local selected, setSelected = React.useState(0)
	local draft, setDraft = React.useState(emptyOffer())
	local youReadyLocal, setYouReadyLocal = React.useState(false)
	local busy, setBusy = React.useState("")
	local shakeAction, setShakeAction = React.useState()
	local offerTab, setOfferTab = React.useState("You")
	local dirtyRef = React.useRef(false)
	local flushRef = React.useRef(nil)
	local sessionActionsHostRef = React.useRef(nil)
	local _result_1 = state.Items
	if _result_1 ~= nil then
		_result_1 = _result_1.Inventory
	end
	local _condition = _result_1
	if _condition == nil then
		_condition = {}
	end
	local inventory = _condition
	local equippedUids = {}
	local _result_2 = state.Items
	if _result_2 ~= nil then
		_result_2 = _result_2.Equipped
	end
	local _condition_1 = _result_2
	if _condition_1 == nil then
		_condition_1 = {}
	end
	for _, uid in pairs(_condition_1) do
		if uid ~= "" then
			equippedUids[uid] = true
		end
	end
	local loadRoster = React.useCallback(function()
		dispatch("GetPlayers", {}, function(response)
			if not response.ok then
				return nil
			end
			local roster = {}
			for _, row in response.Players or {} do
				if not row.IsLocal then
					table.insert(roster, row)
				end
			end
			setRows(roster)
			if selected == 0 and #roster > 0 then
				setSelected(roster[1].UserId)
			end
		end)
	end, { dispatch, selected })
	local _exp = function()
		loadRoster()
		local added = Players.PlayerAdded:Connect(function()
			return loadRoster()
		end)
		local removed = Players.PlayerRemoving:Connect(function()
			return loadRoster()
		end)
		local pulse = task.spawn(function()
			while true do
				task.wait(4)
				if session == nil then
					loadRoster()
				end
			end
		end)
		return function()
			added:Disconnect()
			removed:Disconnect()
			task.cancel(pulse)
		end
	end
	local _result_3 = session
	if _result_3 ~= nil then
		_result_3 = _result_3.Id
	end
	React.useEffect(_exp, { loadRoster, _result_3 })
	local _exp_1 = function()
		if session == nil then
			setDraft(emptyOffer())
			setYouReadyLocal(false)
			dirtyRef.current = false
			return nil
		end
		setYouReadyLocal(session.YouReady)
		if not dirtyRef.current then
			setDraft(session.You)
		end
	end
	local _result_4 = session
	if _result_4 ~= nil then
		_result_4 = _result_4.Id
	end
	local _result_5 = trade
	if _result_5 ~= nil then
		_result_5 = _result_5.Epoch
	end
	local _result_6 = session
	if _result_6 ~= nil then
		_result_6 = _result_6.YouReady
	end
	local _result_7 = session
	if _result_7 ~= nil then
		_result_7 = _result_7.ThemReady
	end
	local _result_8 = session
	if _result_8 ~= nil then
		_result_8 = _result_8.YouConfirmed
	end
	React.useEffect(_exp_1, { _result_4, _result_5, _result_6, _result_7, _result_8 })
	React.useEffect(function()
		return function()
			if flushRef.current ~= nil then
				task.cancel(flushRef.current)
			end
		end
	end, {})
	local queueOffer = function(offer)
		setDraft(offer)
		setYouReadyLocal(false)
		dirtyRef.current = true
		if flushRef.current ~= nil then
			task.cancel(flushRef.current)
		end
		flushRef.current = task.delay(0.14, function()
			flushRef.current = nil
			dirtyRef.current = false
			dispatch("UpdateTradeOffer", {
				Offer = offer,
			})
		end)
	end
	local run = function(action, payload)
		if payload == nil then
			payload = {}
		end
		if busy ~= "" then
			return nil
		end
		setBusy(action)
		dispatch(action, payload, function(response)
			setBusy("")
			if not response.ok then
				setShakeAction(function(current)
					local _object = {
						action = action,
					}
					local _left = "token"
					local _result_9 = current
					if _result_9 ~= nil then
						_result_9 = _result_9.action
					end
					_object[_left] = (if _result_9 == action then current.token else 0) + 1
					return _object
				end)
			end
		end)
	end
	local shakeFor = function(action)
		local _result_9 = shakeAction
		if _result_9 ~= nil then
			_result_9 = _result_9.action
		end
		return if _result_9 == action then shakeAction.token else 0
	end
	local cap = function(key, owned)
		local _result_9 = daily
		if _result_9 ~= nil then
			_result_9 = _result_9.PerTrade[key]
		end
		local per = _result_9
		local _result_10 = daily
		if _result_10 ~= nil then
			_result_10 = _result_10.Sent[key]
		end
		local used = _result_10
		local _result_11 = daily
		if _result_11 ~= nil then
			_result_11 = _result_11.Caps[key]
		end
		local _condition_2 = _result_11
		if _condition_2 == nil then
			_condition_2 = owned
		end
		local _condition_3 = used
		if _condition_3 == nil then
			_condition_3 = 0
		end
		local dailyLeft = _condition_2 - _condition_3
		local _exp_2 = owned
		local _condition_4 = per
		if _condition_4 == nil then
			_condition_4 = owned
		end
		return math.max(0, math.min(_exp_2, _condition_4, dailyLeft))
	end
	local _lock = state.FeatureUnlocks
	if _lock ~= nil then
		_lock = _lock.Trade
	end
	local lock = _lock
	local accent = Palette.mint
	local fade = enter:map(function(amount)
		return 1 - math.clamp(amount, 0, 1)
	end)
	local phone = chrome.stack or chrome.mobile
	local compactTrade = phone or chrome.landscape or viewport.height < 700
	local needle = string.lower(query)
	local visibleRows = (function()
		local matches = {}
		for _, row in rows do
			if needle == "" then
				table.insert(matches, row)
				continue
			end
			if (string.find(string.lower(row.DisplayName), needle, 1, true)) ~= nil or (string.find(string.lower(row.Name), needle, 1, true)) ~= nil then
				table.insert(matches, row)
			end
		end
		return matches
	end)()
	-- ▼ ReadonlyArray.find ▼
	local _callback = function(row)
		return row.UserId == selected
	end
	local _result_9
	for _i, _v in visibleRows do
		if _callback(_v, _i - 1, visibleRows) == true then
			_result_9 = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local _condition_2 = _result_9
	if _condition_2 == nil then
		-- ▼ ReadonlyArray.find ▼
		local _callback_1 = function(row)
			return row.UserId == selected
		end
		local _result_10
		for _i, _v in rows do
			if _callback_1(_v, _i - 1, rows) == true then
				_result_10 = _v
				break
			end
		end
		-- ▲ ReadonlyArray.find ▲
		_condition_2 = _result_10
	end
	local selectedRow = _condition_2
	local inviteLive = invite ~= nil and invite.ExpiresAt > now
	local outgoingLive = outgoing ~= nil and outgoing.ExpiresAt > now
	local sessionLeft = if session ~= nil then math.max(0, session.ExpiresAt - now) else 0
	local confirmLeft = if session ~= nil and session.ConfirmEndsAt > 0 then math.max(0, session.ConfirmEndsAt - now) else 0
	local tableEmpty = session ~= nil and offerEmpty(draft) and offerEmpty(session.Them)
	local _condition_3 = youReadyLocal
	if _condition_3 then
		local _result_10 = session
		if _result_10 ~= nil then
			_result_10 = _result_10.ThemReady
		end
		_condition_3 = (_result_10 == true)
	end
	local bothReady = _condition_3
	local lockBanner = not unlocked
	local actionH = if compactTrade then TapTarget * 3 + 24 else TapTarget + 8
	local headerH = 36
	local statusH = 40
	local lockH = if lockBanner and session == nil then (if compactTrade then 92 else 72) else 0
	local inviteH = if inviteLive and session == nil then (if compactTrade then 126 else 92) else 0
	local outgoingH = if outgoingLive and session == nil and not inviteLive then (if compactTrade then 136 else 72) else 0
	local noticeH = lockH + inviteH + outgoingH
	local rosterRowH = if compactTrade then 96 else 66
	local searchH = TapTarget
	local relics = {}
	for uid, instance in pairs(inventory) do
		if equippedUids[uid] ~= nil or instance.Locked == true then
			continue
		end
		local _arg0 = {
			uid = uid,
			name = itemName(config, instance.DefinitionId),
		}
		table.insert(relics, _arg0)
		if #relics >= 40 then
			break
		end
	end
	local yourLines = offerLines(draft, config, inventory)
	local theirLines = if session ~= nil then offerLines(session.Them, config, inventory) else {}
	local offerBody = function(editor, lines)
		local _exp_2 = editor and not offerEmpty(draft) and React.createElement(Button, {
			text = "CLEAR OFFER",
			icon = "Refresh",
			onClick = function()
				return queueOffer(emptyOffer())
			end,
			color = Palette.panelSoft,
			textColor = Palette.creamSoft,
			size = UDim2.new(1, 0, 0, if phone then TapTarget else 34),
			reducedMotion = reducedMotion,
		})
		local _condition_4 = editor
		if _condition_4 then
			local _exp_3 = React.createElement(QuantityStepper, {
				label = "Flux",
				detail = if cap("Cash", asFlux(state.Cash)) <= 0 then "None tradable" else `{compactNumber(draft.Cash)} / {compactNumber(cap("Cash", asFlux(state.Cash)))}`,
				value = draft.Cash,
				max = cap("Cash", asFlux(state.Cash)),
				accent = Palette.cyan,
				reducedMotion = reducedMotion,
				onChange = function(value)
					local _object = table.clone(draft)
					setmetatable(_object, nil)
					_object.Cash = value
					return queueOffer(_object)
				end,
			})
			local _exp_4 = React.createElement(QuantityStepper, {
				label = "Stardust",
				value = draft.Stardust,
				max = cap("Stardust", state.Stardust),
				accent = Palette.mango,
				reducedMotion = reducedMotion,
				onChange = function(value)
					local _object = table.clone(draft)
					setmetatable(_object, nil)
					_object.Stardust = value
					return queueOffer(_object)
				end,
			})
			local _exp_5 = React.createElement(QuantityStepper, {
				label = "Cores",
				value = draft.Cores,
				max = cap("Cores", state.Cores),
				accent = Palette.violet,
				reducedMotion = reducedMotion,
				onChange = function(value)
					local _object = table.clone(draft)
					setmetatable(_object, nil)
					_object.Cores = value
					return queueOffer(_object)
				end,
			})
			local _attributes = {
				label = "Signals",
				value = draft.Signals,
			}
			local _result_10 = state.Command
			if _result_10 ~= nil then
				_result_10 = _result_10.Signals
			end
			local _condition_5 = _result_10
			if _condition_5 == nil then
				_condition_5 = 0
			end
			_attributes.max = cap("Signals", _condition_5)
			_attributes.accent = Palette.cyan
			_attributes.reducedMotion = reducedMotion
			_attributes.onChange = function(value)
				local _object = table.clone(draft)
				setmetatable(_object, nil)
				_object.Signals = value
				return queueOffer(_object)
			end
			local _exp_6 = React.createElement(QuantityStepper, _attributes)
			local _attributes_1 = {
				label = "Essence",
				value = draft.Essence,
			}
			local _result_11 = state.Items
			if _result_11 ~= nil then
				_result_11 = _result_11.Essence
			end
			local _condition_6 = _result_11
			if _condition_6 == nil then
				_condition_6 = 0
			end
			_attributes_1.max = cap("Essence", _condition_6)
			_attributes_1.accent = Palette.pink
			_attributes_1.reducedMotion = reducedMotion
			_attributes_1.onChange = function(value)
				local _object = table.clone(draft)
				setmetatable(_object, nil)
				_object.Essence = value
				return queueOffer(_object)
			end
			local _exp_7 = React.createElement(QuantityStepper, _attributes_1)
			-- ▼ ReadonlyArray.map ▼
			local _newValue = table.create(#BOOSTS)
			local _callback_1 = function(id)
				local _result_12 = daily
				if _result_12 ~= nil then
					_result_12 = _result_12.PerTrade.Boost
				end
				local _condition_7 = _result_12
				if _condition_7 == nil then
					_condition_7 = 3
				end
				local perTradeBoostCap = _condition_7
				-- ▼ ReadonlyArray.reduce ▼
				local _result_13 = 0
				local _callback_2 = function(sum, other)
					local _exp_8 = sum
					local _result_14
					if other == id then
						_result_14 = 0
					else
						local _condition_8 = draft.Boosts[other]
						if _condition_8 == nil then
							_condition_8 = 0
						end
						_result_14 = _condition_8
					end
					return _exp_8 + _result_14
				end
				for _i = 1, #BOOSTS do
					_result_13 = _callback_2(_result_13, BOOSTS[_i], _i - 1, BOOSTS)
				end
				-- ▲ ReadonlyArray.reduce ▲
				local otherBoostsUsed = _result_13
				local remainingBudget = math.max(0, perTradeBoostCap - otherBoostsUsed)
				local _attributes_2 = {
					key = id,
				}
				local _condition_8 = BOOST_LABELS[id]
				if _condition_8 == nil then
					_condition_8 = id
				end
				_attributes_2.label = _condition_8
				local _condition_9 = draft.Boosts[id]
				if _condition_9 == nil then
					_condition_9 = 0
				end
				_attributes_2.value = _condition_9
				local _result_14 = state.BoostInventory
				if _result_14 ~= nil then
					_result_14 = _result_14[id]
				end
				local _condition_10 = _result_14
				if _condition_10 == nil then
					_condition_10 = 0
				end
				_attributes_2.max = math.min(remainingBudget, _condition_10)
				_attributes_2.accent = Palette.coral
				_attributes_2.reducedMotion = reducedMotion
				_attributes_2.onChange = function(value)
					local _object = table.clone(draft)
					setmetatable(_object, nil)
					local _left = "Boosts"
					local _object_1 = table.clone(draft.Boosts)
					setmetatable(_object_1, nil)
					_object_1[id] = value
					_object[_left] = _object_1
					return queueOffer(_object)
				end
				return React.createElement(QuantityStepper, _attributes_2)
			end
			for _k, _v in BOOSTS do
				_newValue[_k] = _callback_1(_v, _k - 1, BOOSTS)
			end
			-- ▲ ReadonlyArray.map ▲
			-- ▼ ReadonlyArray.map ▼
			local _newValue_1 = table.create(#KEYS)
			local _callback_2 = function(id)
				local _attributes_2 = {
					key = id,
				}
				local _condition_7 = KEY_LABELS[id]
				if _condition_7 == nil then
					_condition_7 = id
				end
				_attributes_2.label = _condition_7
				local _condition_8 = draft.Keys[id]
				if _condition_8 == nil then
					_condition_8 = 0
				end
				_attributes_2.value = _condition_8
				local _result_12 = daily
				if _result_12 ~= nil then
					_result_12 = _result_12.PerTrade.Keys
				end
				local _condition_9 = _result_12
				if _condition_9 == nil then
					_condition_9 = 5
				end
				local _result_13 = state.Items
				if _result_13 ~= nil then
					_result_13 = _result_13.Keys[id]
				end
				local _condition_10 = _result_13
				if _condition_10 == nil then
					_condition_10 = 0
				end
				_attributes_2.max = math.min(_condition_9, _condition_10)
				_attributes_2.accent = Palette.mango
				_attributes_2.reducedMotion = reducedMotion
				_attributes_2.onChange = function(value)
					local _object = table.clone(draft)
					setmetatable(_object, nil)
					local _left = "Keys"
					local _object_1 = table.clone(draft.Keys)
					setmetatable(_object_1, nil)
					_object_1[id] = value
					_object[_left] = _object_1
					return queueOffer(_object)
				end
				return React.createElement(QuantityStepper, _attributes_2)
			end
			for _k, _v in KEYS do
				_newValue_1[_k] = _callback_2(_v, _k - 1, KEYS)
			end
			-- ▲ ReadonlyArray.map ▲
			local _exp_8 = React.createElement(SectionLabel, {
				value = "Relics",
			})
			local _exp_9 = #relics == 0 and React.createElement(Text, {
				value = "No tradeable relics. Equipped and locked pieces stay home.",
				size = 13,
				color = Palette.muted,
				wrap = true,
				sizeConstraint = UDim2.new(1, 0, 0, 36),
			})
			-- ▼ ReadonlyArray.map ▼
			local _newValue_2 = table.create(#relics)
			local _callback_3 = function(relic)
				local _itemIds = draft.ItemIds
				local _uid = relic.uid
				local picked = table.find(_itemIds, _uid) ~= nil
				return React.createElement(RelicPick, {
					key = relic.uid,
					uid = relic.uid,
					name = relic.name,
					picked = picked,
					touch = phone,
					reducedMotion = reducedMotion,
					onToggle = function()
						local pickedIds = {}
						if picked then
							for _, id in draft.ItemIds do
								if id ~= relic.uid then
									table.insert(pickedIds, id)
								end
							end
						else
							local _exp_10 = #draft.ItemIds
							local _result_12 = daily
							if _result_12 ~= nil then
								_result_12 = _result_12.PerTrade.Items
							end
							local _condition_7 = _result_12
							if _condition_7 == nil then
								_condition_7 = 6
							end
							if _exp_10 < _condition_7 then
								for _, id in draft.ItemIds do
									table.insert(pickedIds, id)
								end
								local _uid_1 = relic.uid
								table.insert(pickedIds, _uid_1)
							else
								return nil
							end
						end
						local _object = table.clone(draft)
						setmetatable(_object, nil)
						_object.ItemIds = pickedIds
						queueOffer(_object)
					end,
				})
			end
			for _k, _v in relics do
				_newValue_2[_k] = _callback_3(_v, _k - 1, relics)
			end
			-- ▲ ReadonlyArray.map ▲
			_condition_4 = React.createElement(React.Fragment, nil, _exp_3, _exp_4, _exp_5, _exp_6, _exp_7, _newValue, _newValue_1, _exp_8, _exp_9, _newValue_2)
		end
		local _condition_5 = not editor
		if _condition_5 then
			-- ▼ ReadonlyArray.map ▼
			local _newValue = table.create(#lines)
			local _callback_1 = function(line)
				return React.createElement(OfferRow, {
					key = line.key,
					line = line,
					touch = phone,
				})
			end
			for _k, _v in lines do
				_newValue[_k] = _callback_1(_v, _k - 1, lines)
			end
			-- ▲ ReadonlyArray.map ▲
			_condition_5 = _newValue
		end
		return React.createElement(React.Fragment, nil, _exp_2, _condition_4, _condition_5, not editor and #lines == 0 and React.createElement(Text, {
			value = "Nothing on their side yet.",
			size = 13,
			color = Palette.muted,
			wrap = true,
			sizeConstraint = UDim2.new(1, 0, 0, 32),
		}))
	end
	local offerPane = function(title, partnerName, ready, confirmed, lines, editor, flow, flowOrder)
		if flow == nil then
			flow = false
		end
		local paneAccent = if editor then accent else Palette.cyan
		local header = if flow then React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 78),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 4,
			LayoutOrder = 0,
		}, React.createElement(Text, {
			value = title,
			size = 14,
			color = paneAccent,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			sizeConstraint = UDim2.new(1, 0, 0, 20),
		}), React.createElement(Text, {
			value = partnerName,
			size = 13,
			color = Palette.creamSoft,
			fit = true,
			position = UDim2.fromOffset(0, 22),
			sizeConstraint = UDim2.new(1, 0, 0, 18),
		}), React.createElement(Badge, {
			value = if confirmed then "CONFIRMED" elseif ready then "READY" else "EDITING",
			accent = if confirmed then Palette.mango elseif ready then Palette.mint else Palette.muted,
			filled = confirmed or ready,
			position = UDim2.fromOffset(0, 46),
			size = UDim2.fromOffset(120, 28),
		})) else React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 4,
			LayoutOrder = 0,
		}, React.createElement(Text, {
			value = title,
			size = 13,
			color = paneAccent,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			sizeConstraint = UDim2.new(1, -120, 0, 18),
		}), React.createElement(Text, {
			value = partnerName,
			size = 12,
			color = Palette.creamSoft,
			fit = true,
			position = UDim2.fromOffset(0, 22),
			sizeConstraint = UDim2.new(1, -120, 0, 18),
		}), React.createElement(Badge, {
			value = if confirmed then "CONFIRMED" elseif ready then "READY" else "EDITING",
			accent = if confirmed then Palette.mango elseif ready then Palette.mint else Palette.muted,
			filled = confirmed or ready,
			position = UDim2.new(1, -108, 0, 8),
			size = UDim2.fromOffset(108, 28),
		}))
		if flow then
			return React.createElement("frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Palette.panel,
				BorderSizePixel = 0,
				ClipsDescendants = false,
				LayoutOrder = flowOrder,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 12),
			}), React.createElement(Stroke, {
				color = paneAccent,
				thickness = 1,
				transparency = 0.42,
			}), React.createElement("uipadding", {
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}), React.createElement("uilistlayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}), header, offerBody(editor, lines))
		end
		return React.createElement(Panel, {
			size = UDim2.fromScale(1, 1),
			accent = paneAccent,
			padding = if compactTrade then 12 else Layout.cardPadding,
			clips = true,
			reducedMotion = reducedMotion,
		}, header, React.createElement("scrollingframe", {
			Size = UDim2.new(1, 0, 1, -58),
			Position = UDim2.fromOffset(0, 56),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = paneAccent,
			ScrollBarImageTransparency = 0.2,
			VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
			ClipsDescendants = true,
			Active = true,
			Selectable = false,
		}, React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}), offerBody(editor, lines)))
	end
	-- daily.Limit has shown up empty in the wild despite the type claiming it's
	-- always a number — falling back to the client's own config mirror keeps
	-- this line readable even if a future server response omits it again.
	local _result_10 = daily
	if _result_10 ~= nil then
		_result_10 = _result_10.Limit
	end
	local _condition_4 = _result_10
	if _condition_4 == nil then
		local _result_11 = config.Trading
		if _result_11 ~= nil then
			_result_11 = _result_11.DailyTrades
		end
		_condition_4 = _result_11
	end
	local dailyLimit = _condition_4
	local dailyLabel = if daily ~= nil and dailyLimit ~= nil then `{daily.Completed} / {dailyLimit} trades today` else "Daily limits on every side"
	-- Shared action handlers for CONFIRM_TRADE_TREE:compact (sessionActions) and
	-- CONFIRM_TRADE_TREE:desktop (inline horizontal bar). Layout differs; behavior must stay identical.
	local function onReadyClick()
		if tableEmpty and not youReadyLocal then
			return nil
		end
		local following = not youReadyLocal
		setYouReadyLocal(following)
		run("SetTradeReady", {
			Ready = following,
		})
	end
	local function onConfirmClick()
		return run("ConfirmTrade")
	end
	local function onCancelClick()
		return run("CancelTrade")
	end
	local readyDisabled = busy ~= "" or (tableEmpty and not youReadyLocal)
	local confirmDisabled = busy ~= "" or not bothReady
	-- Gamepad: Ready/Confirm must be Selection-reachable (FocusClaim prefers Confirm when live).
	React.useEffect(function()
		if session == nil or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = sessionActionsHostRef.current
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
	end, { session ~= nil, bothReady, youReadyLocal, tableEmpty, busy, readyDisabled, confirmDisabled })
	-- CONFIRM_TRADE_TREE:compact
	local sessionActions = if session ~= nil then React.createElement("frame", {
		ref = sessionActionsHostRef,
		Name = "TradeSessionActions",
		Size = UDim2.new(1, 0, 0, TapTarget * 3 + 16),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}), React.createElement("frame", {
		Name = "TradeReady",
		Size = UDim2.new(1, 0, 0, TapTarget),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 1,
	}, React.createElement(Button, {
		text = if youReadyLocal then "UNREADY" elseif tableEmpty then "ADD SOMETHING FIRST" else "READY",
		onClick = onReadyClick,
		color = if youReadyLocal then Palette.panelSoft else accent,
		textColor = if youReadyLocal then Palette.cream else Palette.ink,
		size = UDim2.fromScale(1, 1),
		disabled = readyDisabled,
		loading = busy == "SetTradeReady",
		shakeToken = shakeFor("SetTradeReady"),
		reducedMotion = reducedMotion,
		highlight = not youReadyLocal and not tableEmpty,
		selectable = not readyDisabled,
	})), React.createElement("frame", {
		Name = "TradeConfirm",
		Size = UDim2.new(1, 0, 0, TapTarget),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 2,
	}, React.createElement(Button, {
		text = if session.YouConfirmed then "CONFIRMED" elseif confirmLeft > 0 then `CONFIRM  {clockLabel(session.ConfirmEndsAt, now)}` else "CONFIRM",
		onClick = onConfirmClick,
		color = Palette.mango,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		disabled = confirmDisabled,
		loading = busy == "ConfirmTrade",
		shakeToken = shakeFor("ConfirmTrade"),
		reducedMotion = reducedMotion,
		highlight = bothReady and not session.YouConfirmed,
		selectable = not confirmDisabled,
	})), React.createElement("frame", {
		Name = "TradeCancel",
		Size = UDim2.new(1, 0, 0, TapTarget),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 3,
	}, React.createElement(Button, {
		text = "CANCEL",
		onClick = onCancelClick,
		color = Palette.coral,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		disabled = busy ~= "",
		loading = busy == "CancelTrade",
		shakeToken = shakeFor("CancelTrade"),
		reducedMotion = reducedMotion,
		selectable = busy == "",
	}))) else nil
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#visibleRows)
	local _callback_1 = function(row, index)
		local active = row.UserId == selected
		local _condition_5 = outgoingLive
		if _condition_5 then
			local _result_11 = outgoing
			if _result_11 ~= nil then
				_result_11 = _result_11.ToUserId
			end
			_condition_5 = _result_11 == row.UserId
		end
		local waiting = _condition_5
		return React.createElement(Panel, {
			key = row.UserId,
			size = UDim2.new(1, 0, 0, rosterRowH),
			accent = if active then accent else Palette.line,
			background = if active then darken(accent, 0.82) else Palette.panel,
			padding = 10,
			interactive = true,
			reducedMotion = reducedMotion,
			layoutOrder = 6 + index,
		}, React.createElement("textbutton", {
			Size = UDim2.new(1, if compactTrade then 0 else -118, 0, if compactTrade then 48 else 46),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			Active = true,
			Selectable = false,
			Event = {
				Activated = function()
					Audio:play("tick")
					setSelected(row.UserId)
				end,
				MouseEnter = function()
					return Audio:play("hover")
				end,
			},
		}), React.createElement(AvatarMark, {
			userId = row.UserId,
			accent = if active then accent else Palette.cyan,
			size = 44,
		}), React.createElement(Text, {
			value = row.DisplayName,
			size = 16,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			position = UDim2.fromOffset(56, 4),
			sizeConstraint = UDim2.new(1, if compactTrade then -56 else -176, 0, 22),
		}), React.createElement(Text, {
			value = `{row.Rebirths} rebirths · world {row.CurrentZone}`,
			size = 12,
			color = Palette.creamSoft,
			fit = true,
			position = UDim2.fromOffset(56, 28),
			sizeConstraint = UDim2.new(1, if compactTrade then -56 else -176, 0, 18),
		}), React.createElement(Button, {
			text = if waiting then "WAITING" else "INVITE",
			onClick = function()
				setSelected(row.UserId)
				if not waiting then
					run("InviteTrade", {
						UserId = row.UserId,
					})
				end
			end,
			color = if waiting then Palette.panelSoft else accent,
			textColor = if waiting then Palette.cream else Palette.ink,
			size = if compactTrade then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(110, 40),
			position = if compactTrade then UDim2.new(0, 0, 1, -TapTarget) else UDim2.new(1, -110, 0.5, -20),
			disabled = busy ~= "" or waiting or not unlocked,
			loading = busy == "InviteTrade",
			shakeToken = shakeFor("InviteTrade"),
			reducedMotion = reducedMotion,
			highlight = not waiting,
		}))
	end
	for _k, _v in visibleRows do
		_newValue[_k] = _callback_1(_v, _k - 1, visibleRows)
	end
	-- ▲ ReadonlyArray.map ▲
	local rosterCards = _newValue
	if compactTrade and session ~= nil then
		-- The old fixed-position layout reserved 60 (status) + 48 (tabs) + 168 (action stack) +
		-- gaps = ~300px before the offer pane got a single pixel, all in *negative* height math
		-- (Size = 1, -(fixed total)) — on a short screen the body frame collapsed to zero or
		-- negative and the action bar landed on top of the tabs. PageScaffold removes that class
		-- entirely: fixed sections keep intrinsic heights, the offer pane fills whatever is left
		-- (its own internal list scrolls, exactly like the desktop pane), and if the minimum
		-- total ever exceeds the screen the whole stack scrolls.
		return React.createElement(PageScaffold, {
			scrollBarColor = accent,
			scrollBarThickness = 4,
			tailPad = scrollTail(true, chrome.bottomSafe, if chrome.landscape then 28 else 36),
			gap = if chrome.landscape then 8 else Layout.stackGap,
			sections = { {
				id = "status",
				height = if chrome.landscape then 52 else 60,
				element = React.createElement("frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, React.createElement(Text, {
					value = if bothReady then "Both ready — confirm to finish." elseif youReadyLocal then `Waiting on {session.PartnerName}.` else "Add your offer, then tap Ready.",
					size = 13,
					color = if bothReady then Palette.mango else Palette.creamSoft,
					wrap = true,
					sizeConstraint = UDim2.new(1, 0, 0, 32),
				}), React.createElement(Text, {
					value = if sessionLeft > 0 then `Table {clockLabel(session.ExpiresAt, now)}` else "Table expired",
					size = 11,
					color = if sessionLeft > 12 then Palette.mint else Palette.coral,
					weight = Enum.FontWeight.Bold,
					fit = true,
					position = UDim2.fromOffset(0, 34),
					sizeConstraint = UDim2.new(1, 0, 0, 18),
				})),
			}, {
				id = "tabs",
				height = TapTarget,
				element = React.createElement("frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, React.createElement(SegmentedTabs, {
					options = { {
						id = "You",
						label = `YOUR OFFER{if youReadyLocal then " ✓" else ""}`,
					}, {
						id = "Them",
						label = `{string.upper(session.PartnerName)}{if session.ThemReady then " ✓" else ""}`,
					} },
					value = offerTab,
					onChange = setOfferTab,
					accent = accent,
					columns = 2,
					size = UDim2.fromScale(1, 1),
					reducedMotion = reducedMotion,
				})),
			}, {
				id = "offer",
				fill = true,
				minHeight = 180,
				element = if offerTab == "You" then offerPane("YOUR OFFER", `{#yourLines} on the table`, youReadyLocal, session.YouConfirmed, yourLines, true) else offerPane(string.upper(session.PartnerName), if session.ThemReady then "They locked their side" else "Still arranging", session.ThemReady, session.ThemConfirmed, theirLines, false),
			}, {
				id = "actions",
				height = actionH,
				element = React.createElement("frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, React.createElement("uilistlayout", {
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				}), sessionActions),
			} },
		})
	end
	if compactTrade then
		local _exp_2 = React.createElement("uipadding", {
			PaddingBottom = UDim.new(0, scrollTail(true, chrome.bottomSafe, if chrome.landscape then 24 else 32)),
		})
		local _exp_3 = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, if chrome.landscape then 8 else Layout.stackGap),
		})
		local _exp_4 = React.createElement(Text, {
			value = dailyLabel,
			size = 14,
			color = Palette.mint,
			weight = Enum.FontWeight.Bold,
			layoutOrder = 0,
			sizeConstraint = UDim2.new(1, 0, 0, 22),
			transparency = fade,
		})
		local _condition_5 = lockBanner and session == nil
		if _condition_5 then
			local _exp_5 = React.createElement(Text, {
				value = "Player trading is locked",
				size = 15,
				color = Palette.cream,
				weight = Enum.FontWeight.Heavy,
				sizeConstraint = UDim2.new(1, 0, 0, 22),
			})
			local _attributes = {}
			local _result_11 = lock
			if _result_11 ~= nil then
				_result_11 = _result_11.Requirement
			end
			local _condition_6 = _result_11
			if _condition_6 == nil then
				_condition_6 = "Complete your first rebirth."
			end
			_attributes.value = _condition_6
			_attributes.size = 13
			_attributes.color = Palette.creamSoft
			_attributes.wrap = true
			_attributes.position = UDim2.fromOffset(0, 26)
			_attributes.sizeConstraint = UDim2.new(1, 0, 0, 48)
			_condition_5 = React.createElement(Panel, {
				size = UDim2.new(1, 0, 0, 86),
				accent = Palette.muted,
				padding = if compactTrade then 12 else Layout.cardPadding,
				reducedMotion = reducedMotion,
				layoutOrder = 1,
			}, _exp_5, React.createElement(Text, _attributes))
		end
		local _exp_5 = inviteLive and session == nil and React.createElement(Panel, {
			size = UDim2.new(1, 0, 0, 128),
			accent = Palette.cyan,
			padding = if compactTrade then 12 else Layout.cardPadding,
			reducedMotion = reducedMotion,
			layoutOrder = 2,
		}, React.createElement(AvatarMark, {
			userId = invite.FromUserId,
			accent = Palette.cyan,
			size = 44,
		}), React.createElement(Text, {
			value = `{invite.FromName} invited you`,
			size = 16,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			position = UDim2.fromOffset(56, 2),
			sizeConstraint = UDim2.new(1, -64, 0, 22),
		}), React.createElement(Text, {
			value = `Accept to open a live table · {clockLabel(invite.ExpiresAt, now)} left`,
			size = 13,
			color = Palette.creamSoft,
			fit = true,
			position = UDim2.fromOffset(56, 26),
			sizeConstraint = UDim2.new(1, -64, 0, 20),
		}), React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, TapTarget),
			Position = UDim2.new(0, 0, 1, -TapTarget),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement(Button, {
			text = "ACCEPT",
			onClick = function()
				return run("RespondTrade", {
					Accept = true,
				})
			end,
			color = Palette.mint,
			textColor = Palette.ink,
			size = UDim2.new(0.48, -4, 1, 0),
			disabled = busy ~= "",
			loading = busy == "RespondTrade",
			shakeToken = shakeFor("RespondTrade"),
			reducedMotion = reducedMotion,
			highlight = true,
		}), React.createElement(Button, {
			text = "DECLINE",
			onClick = function()
				return run("RespondTrade", {
					Accept = false,
				})
			end,
			color = Palette.coral,
			textColor = Palette.ink,
			size = UDim2.new(0.48, -4, 1, 0),
			position = UDim2.new(0.52, 4, 0, 0),
			disabled = busy ~= "",
			loading = busy == "RespondTrade",
			shakeToken = shakeFor("RespondTrade"),
			reducedMotion = reducedMotion,
		})))
		local _exp_6 = outgoingLive and session == nil and not inviteLive and React.createElement(Panel, {
			size = UDim2.new(1, 0, 0, 124),
			accent = Palette.mango,
			padding = if compactTrade then 12 else Layout.cardPadding,
			reducedMotion = reducedMotion,
			layoutOrder = 3,
		}, React.createElement(Icon, {
			kind = "Timer",
			color = Palette.mango,
			accent = Palette.mango,
			size = 22,
			position = UDim2.fromOffset(2, 6),
			clipSafe = true,
			spin = false,
		}), React.createElement(Text, {
			value = `Waiting on {outgoing.ToName}`,
			size = 15,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			position = UDim2.fromOffset(32, 2),
			sizeConstraint = UDim2.new(1, -40, 0, 22),
		}), React.createElement(Text, {
			value = `Invite expires in {clockLabel(outgoing.ExpiresAt, now)}`,
			size = 13,
			color = Palette.mango,
			weight = Enum.FontWeight.Bold,
			fit = true,
			position = UDim2.fromOffset(32, 26),
			sizeConstraint = UDim2.new(1, -40, 0, 18),
		}), React.createElement(Button, {
			text = "CANCEL",
			onClick = function()
				return run("CancelTrade")
			end,
			color = Palette.coral,
			textColor = Palette.ink,
			size = UDim2.new(1, 0, 0, TapTarget),
			position = UDim2.new(0, 0, 1, -TapTarget),
			disabled = busy ~= "",
			loading = busy == "CancelTrade",
			shakeToken = shakeFor("CancelTrade"),
			reducedMotion = reducedMotion,
		}))
		local _exp_7 = session == nil and React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, searchH),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 4,
		}, React.createElement(SearchField, {
			value = query,
			onChange = setQuery,
			accent = accent,
			placeholder = "Find a forgemaster",
			size = UDim2.new(1, -(searchH + 8), 0, searchH),
			reducedMotion = reducedMotion,
		}), React.createElement(Button, {
			text = "",
			icon = "Refresh",
			onClick = function()
				return loadRoster()
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.fromOffset(searchH, searchH),
			position = UDim2.new(1, -searchH, 0, 0),
			reducedMotion = reducedMotion,
		}))
		local _exp_8 = session == nil and #visibleRows == 0 and React.createElement(EmptyState, {
			icon = "Crew",
			title = if #rows == 0 then "Server is quiet" else "No match",
			body = if #rows == 0 then ((config.ClientPageGuides and config.ClientPageGuides.Trade and config.ClientPageGuides.Trade.EmptySession) or "Nobody else is in this server. Invites only work here.") else "Try a different name.",
			accent = accent,
			compact = true,
			layoutOrder = 5,
			reducedMotion = reducedMotion,
		})
		local _exp_9 = session == nil and rosterCards
		local _condition_6 = session == nil
		if _condition_6 then
			local _attributes = {
				text = if selectedRow ~= nil then `INVITE  {string.upper(selectedRow.DisplayName)}` else "CHOOSE SOMEONE",
				icon = "Send",
				onClick = function()
					if selected ~= 0 then
						run("InviteTrade", {
							UserId = selected,
						})
					end
				end,
				color = accent,
				textColor = Palette.ink,
				size = UDim2.new(1, 0, 0, TapTarget),
			}
			local _condition_7 = selected == 0 or busy ~= ""
			if not _condition_7 then
				local _condition_8 = outgoingLive
				if _condition_8 then
					local _result_11 = outgoing
					if _result_11 ~= nil then
						_result_11 = _result_11.ToUserId
					end
					_condition_8 = _result_11 == selected
				end
				_condition_7 = _condition_8
				if not _condition_7 then
					_condition_7 = not unlocked
				end
			end
			_attributes.disabled = _condition_7
			_attributes.reducedMotion = reducedMotion
			_attributes.highlight = true
			_condition_6 = React.createElement("frame", {
				Size = UDim2.new(1, 0, 0, TapTarget),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = 7,
			}, React.createElement(Button, _attributes))
		end
		return React.createElement("scrollingframe", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = accent,
			ScrollBarImageTransparency = 0.2,
			VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			CanvasSize = UDim2.new(0, 0, 0, 1200),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
			ClipsDescendants = true,
			Active = true,
			Selectable = false,
		}, _exp_2, _exp_3, _exp_4, _condition_5, _exp_5, _exp_6, _exp_7, _exp_8, _exp_9, _condition_6, session ~= nil and React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 40),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 10,
		}, React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Wraps = true,
		}), React.createElement(StatusChip, {
			label = if sessionLeft > 0 then `Table {clockLabel(session.ExpiresAt, now)}` else "Table expired",
			live = sessionLeft > 12,
			accent = if sessionLeft > 12 then Palette.mint else Palette.coral,
		}), confirmLeft > 0 and React.createElement(StatusChip, {
			label = `Confirm {clockLabel(session.ConfirmEndsAt, now)}`,
			live = true,
			accent = Palette.mango,
		}), React.createElement(StatusChip, {
			label = if youReadyLocal then "You ready" else "You editing",
			live = youReadyLocal,
			accent = accent,
		}), React.createElement(StatusChip, {
			label = if session.ThemReady then `{session.PartnerName} ready` else `Waiting on {session.PartnerName}`,
			live = session.ThemReady,
			accent = Palette.cyan,
		}), React.createElement(StatusChip, {
			label = if session.YouConfirmed then "You confirmed" elseif bothReady then "Tap confirm" else "Ready first",
			live = session.YouConfirmed,
			accent = Palette.mango,
		})), session ~= nil and offerPane("YOUR OFFER", `{#yourLines} on the table`, youReadyLocal, session.YouConfirmed, yourLines, true, true), session ~= nil and offerPane(string.upper(session.PartnerName), if session.ThemReady then "They locked their side" else "Still arranging", session.ThemReady, session.ThemConfirmed, theirLines, false, true), session ~= nil and sessionActions)
	end
	local _exp_2 = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, headerH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Text, {
		value = dailyLabel,
		size = 13,
		color = Palette.mint,
		weight = Enum.FontWeight.Bold,
		fit = true,
		layoutOrder = 0,
		sizeConstraint = UDim2.new(0, 220, 1, 0),
		transparency = fade,
	}), session ~= nil and React.createElement(StatusChip, {
		label = if sessionLeft > 0 then `Table {clockLabel(session.ExpiresAt, now)}` else "Table expired",
		live = sessionLeft > 12,
		accent = if sessionLeft > 12 then Palette.mint else Palette.coral,
	}), confirmLeft > 0 and React.createElement(StatusChip, {
		label = `Confirm {clockLabel(session.ConfirmEndsAt, now)}`,
		live = true,
		accent = Palette.mango,
	}))
	local _condition_5 = lockBanner and session == nil
	if _condition_5 then
		local _exp_3 = React.createElement(Text, {
			value = "Player trading is locked",
			size = 14,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			sizeConstraint = UDim2.new(1, 0, 0, 20),
		})
		local _attributes = {}
		local _result_11 = lock
		if _result_11 ~= nil then
			_result_11 = _result_11.Requirement
		end
		local _condition_6 = _result_11
		if _condition_6 == nil then
			_condition_6 = "Complete your first rebirth."
		end
		_attributes.value = _condition_6
		_attributes.size = 12
		_attributes.color = Palette.creamSoft
		_attributes.wrap = true
		_attributes.position = UDim2.fromOffset(0, 22)
		_attributes.sizeConstraint = UDim2.new(1, 0, 0, 36)
		_condition_5 = React.createElement(Panel, {
			size = UDim2.new(1, 0, 0, lockH - 6),
			position = UDim2.fromOffset(0, headerH + 6),
			accent = Palette.muted,
			padding = if compactTrade then 12 else Layout.cardPadding,
			reducedMotion = reducedMotion,
		}, _exp_3, React.createElement(Text, _attributes))
	end
	local _exp_3 = inviteLive and session == nil and React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, inviteH),
		position = UDim2.fromOffset(0, headerH + 6 + lockH),
		accent = Palette.cyan,
		padding = if compactTrade then 12 else Layout.cardPadding,
		reducedMotion = reducedMotion,
	}, React.createElement(AvatarMark, {
		userId = invite.FromUserId,
		accent = Palette.cyan,
		size = 44,
	}), React.createElement(Text, {
		value = `{invite.FromName} invited you`,
		size = 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(56, 2),
		sizeConstraint = UDim2.new(1, if compactTrade then -56 else -236, 0, 22),
	}), React.createElement(Text, {
		value = `Accept to open a live table · {clockLabel(invite.ExpiresAt, now)} left`,
		size = 12,
		color = Palette.creamSoft,
		fit = true,
		position = UDim2.fromOffset(56, 26),
		sizeConstraint = UDim2.new(1, if compactTrade then -56 else -236, 0, 18),
	}), if compactTrade then React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, TapTarget),
		Position = UDim2.new(0, 0, 1, -TapTarget),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Button, {
		text = "ACCEPT",
		onClick = function()
			return run("RespondTrade", {
				Accept = true,
			})
		end,
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.new(0.48, -4, 1, 0),
		disabled = busy ~= "",
		loading = busy == "RespondTrade",
		shakeToken = shakeFor("RespondTrade"),
		reducedMotion = reducedMotion,
		highlight = true,
	}), React.createElement(Button, {
		text = "DECLINE",
		onClick = function()
			return run("RespondTrade", {
				Accept = false,
			})
		end,
		color = Palette.coral,
		textColor = Palette.ink,
		size = UDim2.new(0.48, -4, 1, 0),
		position = UDim2.new(0.52, 4, 0, 0),
		disabled = busy ~= "",
		loading = busy == "RespondTrade",
		shakeToken = shakeFor("RespondTrade"),
		reducedMotion = reducedMotion,
	})) else React.createElement("frame", {
		Size = UDim2.new(0, 220, 0, 40),
		Position = UDim2.new(1, -220, 0.5, -20),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Button, {
		text = "ACCEPT",
		onClick = function()
			return run("RespondTrade", {
				Accept = true,
			})
		end,
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.new(0.48, -4, 1, 0),
		disabled = busy ~= "",
		loading = busy == "RespondTrade",
		shakeToken = shakeFor("RespondTrade"),
		reducedMotion = reducedMotion,
		highlight = true,
	}), React.createElement(Button, {
		text = "DECLINE",
		onClick = function()
			return run("RespondTrade", {
				Accept = false,
			})
		end,
		color = Palette.coral,
		textColor = Palette.ink,
		size = UDim2.new(0.48, -4, 1, 0),
		position = UDim2.new(0.52, 4, 0, 0),
		disabled = busy ~= "",
		loading = busy == "RespondTrade",
		shakeToken = shakeFor("RespondTrade"),
		reducedMotion = reducedMotion,
	})))
	local _exp_4 = outgoingLive and session == nil and not inviteLive and React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, 64),
		position = UDim2.fromOffset(0, headerH + 6 + lockH),
		accent = Palette.mango,
		padding = if compactTrade then 12 else Layout.cardPadding,
		reducedMotion = reducedMotion,
	}, React.createElement(Icon, {
		kind = "Timer",
		color = Palette.mango,
		accent = Palette.mango,
		size = 22,
		position = UDim2.fromOffset(2, 6),
		clipSafe = true,
		spin = false,
	}), React.createElement(Text, {
		value = `Waiting on {outgoing.ToName}`,
		size = 15,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(32, 2),
		sizeConstraint = UDim2.new(1, -140, 0, 22),
	}), React.createElement(Text, {
		value = `Invite expires in {clockLabel(outgoing.ExpiresAt, now)}`,
		size = 12,
		color = Palette.mango,
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(32, 26),
		sizeConstraint = UDim2.new(1, -140, 0, 16),
	}), React.createElement(Button, {
		text = "CANCEL",
		onClick = function()
			return run("CancelTrade")
		end,
		color = Palette.coral,
		textColor = Palette.ink,
		size = if phone then UDim2.fromOffset(84, TapTarget) else UDim2.fromOffset(96, 36),
		position = if phone then UDim2.new(1, -84, 0.5, -TapTarget / 2) else UDim2.new(1, -96, 0.5, -18),
		disabled = busy ~= "",
		loading = busy == "CancelTrade",
		shakeToken = shakeFor("CancelTrade"),
		reducedMotion = reducedMotion,
	}))
	local _condition_6 = session == nil
	if _condition_6 then
		local _exp_5 = React.createElement(SearchField, {
			value = query,
			onChange = setQuery,
			accent = accent,
			placeholder = "Find a forgemaster",
			size = UDim2.new(1, -(searchH + 8), 0, searchH),
			reducedMotion = reducedMotion,
		})
		local _exp_6 = React.createElement(Button, {
			text = "",
			icon = "Refresh",
			onClick = function()
				return loadRoster()
			end,
			color = Palette.panelSoft,
			textColor = Palette.cream,
			size = UDim2.fromOffset(searchH, searchH),
			position = UDim2.new(1, -searchH, 0, 0),
			reducedMotion = reducedMotion,
		})
		local _exp_7 = React.createElement("scrollingframe", {
			Size = UDim2.new(1, 0, 1, -(searchH + 8 + TapTarget + 8)),
			Position = UDim2.fromOffset(0, searchH + 8),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = accent,
			ScrollBarImageTransparency = 0.2,
			VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
			ClipsDescendants = true,
			Active = true,
			Selectable = false,
		}, React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}), #visibleRows == 0 and React.createElement(EmptyState, {
			icon = "Crew",
			title = if #rows == 0 then "Server is quiet" else "No match",
			body = if #rows == 0 then ((config.ClientPageGuides and config.ClientPageGuides.Trade and config.ClientPageGuides.Trade.EmptyBoard) or "Nobody else is in this server. Invites only work here.") else "Try a different name.",
			accent = accent,
			compact = true,
			reducedMotion = reducedMotion,
		}), rosterCards)
		local _attributes = {
			text = if selectedRow ~= nil then `INVITE  {string.upper(selectedRow.DisplayName)}` else "CHOOSE SOMEONE",
			icon = "Send",
			onClick = function()
				if selected ~= 0 then
					run("InviteTrade", {
						UserId = selected,
					})
				end
			end,
			color = accent,
			textColor = Palette.ink,
			size = UDim2.new(1, 0, 0, TapTarget),
			position = UDim2.new(0, 0, 1, -TapTarget),
		}
		local _condition_7 = selected == 0 or busy ~= ""
		if not _condition_7 then
			local _condition_8 = outgoingLive
			if _condition_8 then
				local _result_11 = outgoing
				if _result_11 ~= nil then
					_result_11 = _result_11.ToUserId
				end
				_condition_8 = _result_11 == selected
			end
			_condition_7 = _condition_8
			if not _condition_7 then
				_condition_7 = not unlocked
			end
		end
		_attributes.disabled = _condition_7
		_attributes.loading = busy == "InviteTrade"
		_attributes.shakeToken = shakeFor("InviteTrade")
		_attributes.reducedMotion = reducedMotion
		_attributes.highlight = true
		_condition_6 = React.createElement("frame", {
			Size = UDim2.new(1, 0, 1, -(headerH + 8 + noticeH)),
			Position = UDim2.fromOffset(0, headerH + 8 + noticeH),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, _exp_5, _exp_6, _exp_7, React.createElement(Button, _attributes))
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, _exp_2, _condition_5, _exp_3, _exp_4, _condition_6, session ~= nil and React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, -(headerH + 8)),
		Position = UDim2.fromOffset(0, headerH + 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("scrollingframe", {
		Size = UDim2.new(1, 0, 0, statusH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		ClipsDescendants = false,
		Active = true,
		Selectable = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(StatusChip, {
		label = if sessionLeft > 0 then `Table {clockLabel(session.ExpiresAt, now)}` else "Table expired",
		live = sessionLeft > 12,
		accent = if sessionLeft > 12 then Palette.mint else Palette.coral,
	}), confirmLeft > 0 and React.createElement(StatusChip, {
		label = `Confirm {clockLabel(session.ConfirmEndsAt, now)}`,
		live = true,
		accent = Palette.mango,
	}), React.createElement(StatusChip, {
		label = if youReadyLocal then "You ready" else "You editing",
		live = youReadyLocal,
		accent = accent,
	}), React.createElement(StatusChip, {
		label = if session.ThemReady then `{session.PartnerName} ready` else `Waiting on {session.PartnerName}`,
		live = session.ThemReady,
		accent = Palette.cyan,
	}), React.createElement(StatusChip, {
		label = if session.YouConfirmed then "You confirmed" elseif bothReady then "Tap confirm" else "Ready first",
		live = session.YouConfirmed,
		accent = Palette.mango,
	})), React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, -(statusH + 10 + actionH)),
		Position = UDim2.fromOffset(0, statusH + 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("frame", {
		Size = UDim2.new(0.49, -4, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, offerPane("YOUR OFFER", `{#yourLines} on the table`, youReadyLocal, session.YouConfirmed, yourLines, true)), React.createElement("frame", {
		Size = UDim2.new(0.49, -4, 1, 0),
		Position = UDim2.new(0.51, 4, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, offerPane(string.upper(session.PartnerName), if session.ThemReady then "They locked their side" else "Still arranging", session.ThemReady, session.ThemConfirmed, theirLines, false))), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, actionH),
		Position = UDim2.new(0, 0, 1, -actionH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("frame", {
		-- CONFIRM_TRADE_TREE:desktop
		ref = sessionActionsHostRef,
		Name = "TradeSessionActions",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
	}), React.createElement("frame", {
		Name = "TradeReady",
		Size = UDim2.new(0, 0, 0, TapTarget),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 1,
	}, React.createElement("uiflexitem", {
		FlexMode = Enum.UIFlexMode.Fill,
	}), React.createElement(Button, {
		text = if youReadyLocal then "UNREADY" elseif tableEmpty then "ADD SOMETHING FIRST" else "READY",
		onClick = onReadyClick,
		color = if youReadyLocal then Palette.panelSoft else accent,
		textColor = if youReadyLocal then Palette.cream else Palette.ink,
		size = UDim2.fromScale(1, 1),
		disabled = readyDisabled,
		loading = busy == "SetTradeReady",
		shakeToken = shakeFor("SetTradeReady"),
		reducedMotion = reducedMotion,
		highlight = not youReadyLocal and not tableEmpty,
		selectable = not readyDisabled,
	})), React.createElement("frame", {
		Name = "TradeConfirm",
		Size = UDim2.new(0, 0, 0, TapTarget),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 2,
	}, React.createElement("uiflexitem", {
		FlexMode = Enum.UIFlexMode.Fill,
	}), React.createElement(Button, {
		text = if session.YouConfirmed then "CONFIRMED" elseif confirmLeft > 0 then `CONFIRM  {clockLabel(session.ConfirmEndsAt, now)}` else "CONFIRM",
		onClick = onConfirmClick,
		color = Palette.mango,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		disabled = confirmDisabled,
		loading = busy == "ConfirmTrade",
		shakeToken = shakeFor("ConfirmTrade"),
		reducedMotion = reducedMotion,
		highlight = bothReady and not session.YouConfirmed,
		selectable = not confirmDisabled,
	})), React.createElement("frame", {
		Name = "TradeCancel",
		Size = UDim2.new(0, 0, 0, TapTarget),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 3,
	}, React.createElement("uiflexitem", {
		FlexMode = Enum.UIFlexMode.Fill,
	}), React.createElement(Button, {
		text = "CANCEL",
		onClick = onCancelClick,
		color = Palette.coral,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		disabled = busy ~= "",
		loading = busy == "CancelTrade",
		shakeToken = shakeFor("CancelTrade"),
		reducedMotion = reducedMotion,
		selectable = busy == "",
	})))))

end
return {
	TradeView = TradeView,
}

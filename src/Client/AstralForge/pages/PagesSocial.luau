--!nonstrict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("PagesSocial: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("PagesSocial: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

__defs["TradeView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local unixNow = require(script.Parent.Parent.CoreKit)("deadlines").unixNow
local _format = require(script.Parent.Parent.CoreKit)("format")
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local Icon = require(script.Parent.Parent.ArtKit)("Icon").Icon
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useEntrance = _motion.useEntrance
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local FlatList = require(script.Parent.Parent.LayoutKit)("virtualizedList").FlatList
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local Layout = _theme.Layout
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local _ui = require(script.Parent.Parent.UiCore)("ui")
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
		local alive = true
		local worker = task.spawn(function()
			while alive do
				task.wait(0.5)
				if not alive then
					break
				end
				setNow(unixNow())
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, worker)
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
	local antilag = useAntilag()
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local enter = useEntrance(reducedMotion)
	local reveal = useStagger(0, softMotion)
	local boardReveal = useStagger(1, reducedMotion)
	local inviteReveal = useStagger(2, reducedMotion)
	local confirmReveal = useStagger(3, reducedMotion)
	local deskReveal = useStagger(4, reducedMotion)
	local dailyReveal = useStagger(5, reducedMotion)
	local softInvite = softMotion or inviteReveal ~= nil
	local softConfirm = softMotion or confirmReveal ~= nil
	local tradeSoft = softMotion or deskReveal == nil or dailyReveal == nil
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
		local alive = true
		local pulse = task.spawn(function()
			while alive do
				task.wait(4)
				if not alive then
					break
				end
				if session == nil then
					loadRoster()
				end
			end
		end)
		return function()
			alive = false
			added:Disconnect()
			removed:Disconnect()
			pcall(task.cancel, pulse)
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
				pcall(task.cancel, flushRef.current)
			end
		end
	end, {})
	local queueOffer = function(offer)
		setDraft(offer)
		setYouReadyLocal(false)
		dirtyRef.current = true
		if flushRef.current ~= nil then
			pcall(task.cancel, flushRef.current)
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
	local _condition_2 = _result_9
	if _condition_2 == nil then
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
	local lockH = if lockBanner and session == nil then (if compactTrade then 92 else 72) else 0
	local inviteH = if inviteLive and session == nil then (if compactTrade then 126 else 92) else 0
	local outgoingH = if outgoingLive and session == nil and not inviteLive then (if compactTrade then 136 else 72) else 0
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
			reducedMotion = softInvite,
		})
		local _condition_4 = editor
		if _condition_4 then
			local _exp_3 = React.createElement(QuantityStepper, {
				label = "Flux",
				detail = if cap("Cash", asFlux(state.Cash)) <= 0 then "None tradable" else `{compactNumber(draft.Cash)} / {compactNumber(cap("Cash", asFlux(state.Cash)))}`,
				value = draft.Cash,
				max = cap("Cash", asFlux(state.Cash)),
				accent = Palette.cyan,
				reducedMotion = softConfirm,
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
				reducedMotion = softMotion,
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
				reducedMotion = softMotion,
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
			_attributes.reducedMotion = softMotion
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
			_attributes_1.reducedMotion = softMotion
			_attributes_1.onChange = function(value)
				local _object = table.clone(draft)
				setmetatable(_object, nil)
				_object.Essence = value
				return queueOffer(_object)
			end
			local _exp_7 = React.createElement(QuantityStepper, _attributes_1)
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
				_attributes_2.reducedMotion = softMotion
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
				_attributes_2.reducedMotion = softMotion
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
					reducedMotion = softMotion,
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
			_condition_4 = React.createElement(React.Fragment, nil, _exp_3, _exp_4, _exp_5, _exp_6, _exp_7, _newValue, _newValue_1, _exp_8, _exp_9, _newValue_2)
		end
		local _condition_5 = not editor
		if _condition_5 then
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
		if flow == false then
			flow = true
		end
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
	React.useEffect(function()
		if session == nil then
			GamepadNavigationService.EndOverlayFocus()
			return nil
		end
		GamepadNavigationService.BeginOverlayFocus()
		return function()
			GamepadNavigationService.EndOverlayFocus()
		end
	end, { session ~= nil })
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
			pcall(task.cancel, selectJob)
		end
	end, { session ~= nil, bothReady, youReadyLocal, tableEmpty, busy, readyDisabled, confirmDisabled })
	local function buildConfirmActions(orientation)
		if session == nil then
			return nil
		end
		local vertical = orientation == "vertical"
		local readySlot = React.createElement("frame", {
			Name = "TradeReady",
			Size = if vertical then UDim2.new(1, 0, 0, TapTarget) else UDim2.new(0, 0, 0, TapTarget),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 1,
		}, not vertical and React.createElement("uiflexitem", {
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
			reducedMotion = softMotion,
			highlight = not youReadyLocal and not tableEmpty,
			selectable = not readyDisabled,
		}))
		local confirmSlot = React.createElement("frame", {
			Name = "TradeConfirm",
			Size = if vertical then UDim2.new(1, 0, 0, TapTarget) else UDim2.new(0, 0, 0, TapTarget),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 2,
		}, not vertical and React.createElement("uiflexitem", {
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
		}))
		local cancelSlot = React.createElement("frame", {
			Name = "TradeCancel",
			Size = if vertical then UDim2.new(1, 0, 0, TapTarget) else UDim2.new(0, 0, 0, TapTarget),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 3,
		}, not vertical and React.createElement("uiflexitem", {
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
		}))
		if vertical then
			return React.createElement("frame", {
				ref = sessionActionsHostRef,
				Name = "TradeSessionActions",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = false,
			}, React.createElement("uilistlayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}), readySlot, confirmSlot, cancelSlot)
		end
		return React.createElement("frame", {
			ref = sessionActionsHostRef,
			Name = "TradeSessionActions",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		}, React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		}), readySlot, confirmSlot, cancelSlot)
	end
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
			reveal = if reducedMotion then deskReveal else boardReveal,
			reducedMotion = reducedMotion or tradeSoft,
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
	local rosterCards = _newValue
	if session ~= nil then
		local pinnedActions = buildConfirmActions(if compactTrade then "vertical" else "horizontal")
		local stepRow = if phone then TapTarget + 10 else 48
		local lineRow = if phone then 64 else 58
		local function offerFloor(editor, lines)
			local header = 96
			if not editor then
				return header + math.max(#lines, 1) * lineRow + 24
			end
			return header + 40 + 6 * stepRow + 140 + math.min(#relics, 24) * stepRow
		end
		local youFloor = offerFloor(true, yourLines)
		local themFloor = offerFloor(false, theirLines)
		local offerContentFloor = if compactTrade then (if offerTab == "You" then youFloor else themFloor) else math.max(youFloor, themFloor)
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		}, React.createElement("frame", {
			Size = UDim2.new(1, 0, 1, -(actionH + 8)),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, React.createElement(PageScaffold, {
			scrollBarColor = accent,
			scrollBarThickness = 4,
			tailPad = scrollTail(true, chrome.bottomSafe, if chrome.landscape then 16 else 20),
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
				minHeight = 120,
				height = offerContentFloor,
				element = if compactTrade then (
					if offerTab == "You" then offerPane("YOUR OFFER", `{#yourLines} on the table`, youReadyLocal, session.YouConfirmed, yourLines, true, true) else offerPane(string.upper(session.PartnerName), if session.ThemReady then "They locked their side" else "Still arranging", session.ThemReady, session.ThemConfirmed, theirLines, false, true)
				) else React.createElement("frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, React.createElement("frame", {
					Size = UDim2.new(0.49, -4, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, offerPane("YOUR OFFER", `{#yourLines} on the table`, youReadyLocal, session.YouConfirmed, yourLines, true, true)), React.createElement("frame", {
					Size = UDim2.new(0.49, -4, 0, 0),
					Position = UDim2.new(0.51, 4, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, offerPane(string.upper(session.PartnerName), if session.ThemReady then "They locked their side" else "Still arranging", session.ThemReady, session.ThemConfirmed, theirLines, false, true))),
			} },
		})), React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, actionH),
			Position = UDim2.new(0, 0, 1, -actionH),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 6,
		}, pinnedActions))
	end
	do
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
			value = `{(invite and invite.FromName) or "Someone"} invited you`,
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
			value = `Waiting on {(outgoing and outgoing.ToName) or "partner"}`,
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
		local rosterStride = rosterRowH + (if chrome.landscape then 8 else Layout.stackGap)
		local rosterFloor = if #visibleRows == 0 then 140 else #visibleRows * rosterStride
		local sections = {
			{
				id = "daily",
				height = 22,
				element = _exp_4,
			},
		}
		if _condition_5 then
			table.insert(sections, {
				id = "lock",
				height = 86,
				element = _condition_5,
			})
		end
		if _exp_5 then
			table.insert(sections, {
				id = "invite",
				height = 128,
				element = _exp_5,
			})
		end
		if _exp_6 then
			table.insert(sections, {
				id = "outgoing",
				height = 124,
				element = _exp_6,
			})
		end
		if _exp_7 then
			table.insert(sections, {
				id = "search",
				height = searchH,
				element = _exp_7,
			})
		end
		local rosterElement = if _exp_8 then _exp_8 elseif #visibleRows >= 8 then React.createElement(FlatList, {
			data = visibleRows,
			itemHeight = rosterStride,
			overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
			canvasTail = 8,
			Size = UDim2.fromScale(1, 1),
			scrollBarColor = accent,
			scrollBarThickness = 4,
			keyExtractor = function(row)
				return row.UserId
			end,
			renderItem = function(_param_1)
				local index = _param_1.index
				return rosterCards[index + 1]
			end,
		}) else React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, if chrome.landscape then 8 else Layout.stackGap),
		}), rosterCards)
		table.insert(sections, {
			id = "roster",
			fill = #visibleRows >= 4,
			minHeight = rosterFloor,
			height = rosterFloor,
			element = rosterElement,
		})
		if _condition_6 then
			table.insert(sections, {
				id = "invite-cta",
				height = TapTarget,
				element = _condition_6,
			})
		end
		return React.createElement(PageScaffold, {
			scrollBarColor = accent,
			scrollBarThickness = 4,
			tailPad = scrollTail(true, chrome.bottomSafe, if chrome.landscape then 24 else 32),
			gap = if chrome.landscape then 8 else Layout.stackGap,
			sections = sections,
		})
	end
end
return {
	TradeView = TradeView,
}
end

__defs["CrewView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local PlayerMark = require(script.Parent.Parent.ArtKit)("Icon").PlayerMark
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Button = _ui.Button
local EmptyState = _ui.EmptyState
local Meter = _ui.Meter
local meterFill = _ui.meterFill
local Panel = _ui.Panel
local Text = _ui.Text
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local NumberSpinnerHost = require(script.Parent.Parent.ReactHosts)("NumberSpinnerHost").NumberSpinnerHost
local FlatList = require(script.Parent.Parent.LayoutKit)("virtualizedList").FlatList
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local lighten = _theme.lighten
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local _format = require(script.Parent.Parent.CoreKit)("format")
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local AppHelpers = require(script.Parent.Parent.CoreKit)("appNav").AppHelpers
local PageReadyMath = require(script.Parent.Parent.LayoutKit)("pageReadyMath")
local PageBoardHeights = require(script.Parent.Parent.CoreKit)("pageBoardHeights")

local function CrewRow(_param)
	local player = _param.player
	local visiting = _param.visiting
	local visitorsHere = _param.visitorsHere
	local onVisit = _param.onVisit
	local onNudge = _param.onNudge
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local layoutOrder = _param.layoutOrder
	local stack = _param.stack
	local reveal = useStagger(math.min(layoutOrder, 8), softMotion)
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
		reducedMotion = softMotion,
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
		reducedMotion = softMotion,
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
		reducedMotion = softMotion,
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
		reducedMotion = softMotion,
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
		reducedMotion = softMotion,
		disabled = visiting,
		highlight = visiting,
	}))))
end
local function VisitPanel(_param)
	local visit = _param.visit
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local layoutOrder = _param.layoutOrder
	local stack = _param.stack
	local reveal = useStagger(0, softMotion)
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
		reducedMotion = softMotion,
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
			reducedMotion = softMotion,
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
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, PageBoardHeights.Visit(stack)),
		accent = Palette.blue,
		background = Palette.panelRaised,
		padding = 16,
		layoutOrder = layoutOrder,
		reveal = reveal,
		highlight = true,
		reducedMotion = softMotion,
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
		reducedMotion = softMotion,
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
	local softMotion = reducedMotion
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
		local alive = true
		local worker = task.spawn(function()
			while alive do
				task.wait(4)
				if not alive then
					break
				end
				refresh()
			end
		end)
		return function()
			alive = false
			pcall(function()
				return task.cancel(worker)
			end)
		end
	end, { refresh })
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
			pcall(task.cancel, selectJob)
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
				reducedMotion = reducedMotion,
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
					reducedMotion = reducedMotion,
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
end

__defs["GuildView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local PlayerMark = require(script.Parent.Parent.ArtKit)("Icon").PlayerMark
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local _format = require(script.Parent.Parent.CoreKit)("format")
local clockText = _format.clockText
local compactNumber = _format.compactNumber
local formatReward = _format.formatReward
local gteFlux = _format.gteFlux
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useEntrance = _motion.useEntrance
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local useWallClock = _motion.useWallClock
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local ensureContrast = _theme.ensureContrast
local Layout = _theme.Layout
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local EmptyState = _ui.EmptyState
local Meter = _ui.Meter
local Panel = _ui.Panel
local SectionLabel = _ui.SectionLabel
local Text = _ui.Text
local Social = require(game.ReplicatedStorage.AstralForge.Shared.SocialProgression)(require(game.ReplicatedStorage.AstralForge.Shared.OmegaMath))
local createRequest = require(script.Parent.Parent.ActionRequest)
local ROLE_RANK = {
	Leader = 0,
	Officer = 1,
	Member = 2,
}
local UPGRADE_ACCENTS = {
	ProductionBoost = Palette.coral,
	VaultBoost = Palette.mango,
	OfflineBoost = Palette.cyan,
	AutomationBoost = Palette.mint,
	TapBoost = Palette.violet,
}
local function effectAtLevel(config, level)
	local safe = math.max(0, math.floor(level))
	if safe <= 0 then
		return 0
	end
	local tiers = config.Tiers
	if tiers == nil or #tiers == 0 then
		return safe * config.EffectPerLevel
	end
	local named = math.min(safe, #tiers)
	local total = 0
	do
		local index = 0
		local _shouldIncrement = false
		while true do
			if _shouldIncrement then
				index += 1
			else
				_shouldIncrement = true
			end
			if not (index < named) then
				break
			end
			local tier = tiers[index + 1]
			local effect = if type(tier) == "table" then tier.Effect else nil
			total += if type(effect) == "number" then effect else 0
		end
	end
	if safe > named then
		total += (safe - named) * config.EffectPerLevel
	end
	return total
end
local function costAtLevel(config, level)
	local tiers = config.Tiers
	local nextIndex = level + 1
	if tiers ~= nil and nextIndex >= 1 and nextIndex <= #tiers then
		local tierCost = tiers[nextIndex].Cost
		if type(tierCost) == "number" then
			return math.floor(tierCost + 0.5)
		end
	end
	return math.floor(config.BaseCost * config.CostScale ^ math.max(0, level) + 0.5)
end
local function percentText(value)
	local scaled = value * 100
	if scaled >= 10 or scaled % 1 == 0 then
		return `+{math.floor(scaled + 0.5)}%`
	end
	return `+{string.format("%.1f", scaled)}%`
end
local function buildUpgradeRows(config, guild)
	local guildConfig = config.Guild
	if guildConfig == nil then
		return {}
	end
	local order = guildConfig.UpgradeOrder or {}
	local ids = {}
	for _, id in order do
		if guildConfig.Upgrades[id] ~= nil then
			table.insert(ids, id)
		end
	end
	for id in pairs(guildConfig.Upgrades) do
		if not (table.find(ids, id) ~= nil) then
			table.insert(ids, id)
		end
	end
	local rows = {}
	for _, id in ids do
		local upgrade = guildConfig.Upgrades[id]
		local _condition = guild.Upgrades[id]
		if _condition == nil then
			_condition = 0
		end
		local level = _condition
		local maxed = level >= upgrade.MaxLevel
		local cost = costAtLevel(upgrade, level)
		local bank = if upgrade.Currency == "Cash" then guild.BankCash else guild.BankDust
		local tiers = upgrade.Tiers
		local _result = tiers
		if _result ~= nil then
			_result = #_result
		end
		local _condition_1 = _result
		if _condition_1 == nil then
			_condition_1 = 0
		end
		local tierCount = _condition_1
		local _arg0 = {
			id = id,
			config = upgrade,
			level = level,
			cost = cost,
			currentEffect = effectAtLevel(upgrade, level),
			nextEffect = effectAtLevel(upgrade, level + 1),
			tierName = if level > 0 and tiers ~= nil and level <= tierCount then tiers[level].Name elseif level > 0 then "Endless" else "Not installed",
			nextTierName = if tiers ~= nil and level < tierCount then tiers[level + 1].Name else nil,
			tierIndex = math.min(level, tierCount),
			tierCount = tierCount,
			affordable = not maxed and gteFlux(bank, cost),
			maxed = maxed,
			accent = UPGRADE_ACCENTS[id] or Palette.violet,
		}
		table.insert(rows, _arg0)
	end
	return rows
end
local function goalConfigFor(config, typeId)
	local _result = config.Guild
	if _result ~= nil then
		_result = _result.Goal
		if _result ~= nil then
			_result = _result.Types
		end
	end
	local _condition = _result
	if _condition == nil then
		_condition = {}
	end
	for _, entry in _condition do
		if entry.Id == typeId then
			return entry
		end
	end
	return nil
end
local function goalUnitLabel(metric)
	if metric == "ContributeCash" then
		return "flux banked"
	end
	if metric == "ContributeDust" then
		return "dust banked"
	end
	return "upgrades bought"
end
local function GuildGoalCard(_param)
	local guild = _param.guild
	local config = _param.config
	local layoutOrder = _param.layoutOrder
	local stack = _param.stack
	local reducedMotion = _param.reducedMotion
	local dispatch = _param.dispatch
	local busy = _param.busy
	local shakeToken = _param.shakeToken
	local goal = guild.Goal
	local now = useWallClock(goal ~= nil)
	local localKey = tostring(Players.LocalPlayer.UserId)
	if goal == nil then
		return React.createElement(Panel, {
			size = UDim2.new(1, 0, 0, 116),
			accent = Palette.mint,
			background = Palette.panelRaised,
			padding = if stack then 16 else 18,
			layoutOrder = layoutOrder,
			reducedMotion = reducedMotion,
		}, React.createElement(Text, {
			value = "GUILD GOAL",
			size = 10,
			color = Palette.mint,
			weight = Enum.FontWeight.Heavy,
			sizeConstraint = UDim2.new(1, 0, 0, 14),
		}), React.createElement(Text, {
			value = "The next shared goal is being drawn up.",
			size = 12,
			color = Palette.creamSoft,
			wrap = true,
			position = UDim2.fromOffset(0, 22),
			sizeConstraint = UDim2.new(1, 0, 0, 34),
		}))
	end
	local definition = goalConfigFor(config, goal.TypeId)
	local fill = math.clamp(goal.Progress / math.max(1, goal.Target), 0, 1)
	local _condition = goal.Contributors[localKey]
	if _condition == nil then
		_condition = 0
	end
	local mine = _condition
	local _result = config.Guild
	if _result ~= nil then
		_result = _result.Goal
		if _result ~= nil then
			_result = _result.MinContributionForReward
		end
	end
	local _condition_1 = _result
	if _condition_1 == nil then
		_condition_1 = 1
	end
	local helped = mine >= _condition_1
	local claimed = goal.Claimed[localKey] == true
	local canClaim = goal.Completed and helped and not claimed
	local accent = if goal.Completed then Palette.mint else Palette.mango
	local surface = darken(accent, 0.9)
	local height = if stack then 234 else 196
	local claimHostRef = React.useRef(nil)
	React.useEffect(function()
		if not canClaim or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = claimHostRef.current
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
			pcall(task.cancel, selectJob)
		end
	end, { canClaim, goal.TypeId, goal.Completed })
	local _exp = React.createElement(Text, {
		value = if goal.Completed then "GUILD GOAL • COMPLETE" else "GUILD GOAL",
		size = 10,
		color = ensureContrast(surface, accent),
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, -120, 0, 14),
	})
	local _attributes = {}
	local _result_1 = definition
	if _result_1 ~= nil then
		_result_1 = _result_1.Name
	end
	local _condition_2 = _result_1
	if _condition_2 == nil then
		_condition_2 = "Shared objective"
	end
	_attributes.value = _condition_2
	_attributes.size = if stack then 20 else 25
	_attributes.color = ensureContrast(surface, Palette.cream)
	_attributes.weight = Enum.FontWeight.Heavy
	_attributes.fit = true
	_attributes.minSize = 15
	_attributes.position = UDim2.fromOffset(0, 18)
	_attributes.sizeConstraint = UDim2.new(1, -8, 0, 32)
	local _exp_1 = React.createElement(Text, _attributes)
	local _attributes_1 = {}
	local _result_2 = definition
	if _result_2 ~= nil then
		_result_2 = _result_2.Description
	end
	local _condition_3 = _result_2
	if _condition_3 == nil then
		_condition_3 = "Work together to finish this goal."
	end
	_attributes_1.value = _condition_3
	_attributes_1.size = 11
	_attributes_1.color = ensureContrast(surface, Palette.creamSoft)
	_attributes_1.wrap = true
	_attributes_1.position = UDim2.fromOffset(0, if stack then 50 else 52)
	_attributes_1.sizeConstraint = UDim2.new(1, -8, 0, 30)
	local _exp_2 = React.createElement(Text, _attributes_1)
	local _exp_3 = React.createElement(Text, {
		value = now:map(function(timestamp)
			return if goal.EndsAt > timestamp then `{clockText(math.max(0, goal.EndsAt - timestamp))} LEFT` else "WINDOW CLOSED"
		end),
		size = 10,
		color = ensureContrast(surface, Palette.muted),
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Right,
		position = UDim2.new(1, -150, 0, 0),
		sizeConstraint = UDim2.fromOffset(150, 16),
	})
	local _exp_4 = React.createElement(Meter, {
		value = fill,
		color = accent,
		position = UDim2.new(0, 0, 0, if stack then 92 else 94),
		size = UDim2.new(1, 0, 0, 9),
		reducedMotion = reducedMotion,
		shimmer = goal.Completed,
	})
	local _attributes_2 = {}
	local _exp_5 = compactNumber(goal.Progress)
	local _exp_6 = compactNumber(goal.Target)
	local _result_3 = definition
	if _result_3 ~= nil then
		_result_3 = _result_3.Metric
	end
	local _condition_4 = _result_3
	if _condition_4 == nil then
		_condition_4 = ""
	end
	_attributes_2.value = `{_exp_5} / {_exp_6} {goalUnitLabel(_condition_4)}`
	_attributes_2.size = 10
	_attributes_2.color = ensureContrast(surface, Palette.creamSoft)
	_attributes_2.fit = true
	_attributes_2.minSize = 8
	_attributes_2.position = UDim2.fromOffset(0, if stack then 106 else 108)
	_attributes_2.sizeConstraint = UDim2.new(1, 0, 0, 16)
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, height),
		accent = accent,
		background = surface,
		padding = 16,
		layoutOrder = layoutOrder,
		highlight = canClaim,
		reducedMotion = reducedMotion,
		clips = false,
	}, _exp, _exp_1, _exp_2, _exp_3, _exp_4, React.createElement(Text, _attributes_2), React.createElement(Text, {
		value = if mine > 0 then `YOU HELPED WITH {compactNumber(mine)}` else "YOU HAVE NOT HELPED YET",
		size = 10,
		color = ensureContrast(surface, if mine > 0 then Palette.mint else Palette.muted),
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(0, if stack then 126 else 128),
		sizeConstraint = UDim2.new(1, if stack then 0 else -170, 0, 16),
	}), definition ~= nil and React.createElement(Text, {
		value = `REWARD  {formatReward(definition.Reward)}`,
		size = 10,
		color = ensureContrast(surface, Palette.muted),
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(0, if stack then 146 else 148),
		sizeConstraint = UDim2.new(1, if stack then 0 else -170, 0, 16),
	}), React.createElement("frame", {
		Name = "GuildClaimActions",
		Size = if stack then UDim2.new(1, 0, 0, 46) else UDim2.fromOffset(160, 46),
		Position = if stack then UDim2.new(0, 0, 1, -46) else UDim2.new(1, -160, 1, -46),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ref = if canClaim then claimHostRef else nil,
	}, React.createElement(Button, {
		text = if claimed then "CLAIMED" elseif canClaim then "CLAIM REWARD" elseif goal.Completed then "NOT ELIGIBLE" else "IN PROGRESS",
		icon = if claimed then "Check" else "Gift",
		onClick = function()
			if canClaim and not busy then
				dispatch("ClaimGuildGoal", {})
			end
		end,
		color = if canClaim then Palette.mint else Palette.panelSoft,
		textColor = if canClaim then Palette.ink else Palette.creamSoft,
		disabled = not canClaim or busy,
		loading = canClaim and busy,
		shakeToken = if canClaim then shakeToken else 0,
		highlight = canClaim,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})))
end
local function UpgradeCard(_param)
	local row = _param.row
	local guild = _param.guild
	local canBuy = _param.canBuy
	local stack = _param.stack
	local reducedMotion = _param.reducedMotion
	local dispatch = _param.dispatch
	local busy = _param.busy
	local shakeToken = _param.shakeToken
	local layoutOrder = _param.layoutOrder
	local currencyLabel = if row.config.Currency == "Cash" then "flux" else "dust"
	local bank = if row.config.Currency == "Cash" then guild.BankCash else guild.BankDust
	local fill = if row.maxed then 1 else math.clamp(bank / math.max(1, row.cost), 0, 1)
	local actionable = canBuy and row.affordable and not row.maxed
	local height = if stack then 180 else 140
	local _exp = React.createElement(Text, {
		value = row.config.Name,
		size = if stack then 15 else 17,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 12,
		sizeConstraint = UDim2.new(1, if stack then -90 else -260, 0, 22),
	})
	local _exp_1 = React.createElement(Badge, {
		value = if row.tierCount > 0 then `TIER {row.tierIndex}/{row.tierCount}` else `LV {compactNumber(row.level)}`,
		accent = row.accent,
		filled = row.level > 0,
		position = UDim2.new(1, if stack then -84 else -254, 0, 0),
		size = UDim2.fromOffset(84, 24),
	})
	local _exp_2 = React.createElement(Text, {
		value = row.config.Description,
		size = 10,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(0, 26),
		sizeConstraint = UDim2.new(1, if stack then 0 else -260, 0, 28),
	})
	local _attributes = {}
	local _result
	if row.maxed then
		_result = `{percentText(row.currentEffect)} — fully installed`
	else
		local _exp_3 = percentText(row.currentEffect)
		local _exp_4 = percentText(row.nextEffect)
		local _condition = row.nextTierName
		if _condition == nil then
			_condition = "the next level"
		end
		_result = `{_exp_3} now  →  {_exp_4} at {_condition}`
	end
	_attributes.value = _result
	_attributes.size = 11
	_attributes.color = if row.maxed then Palette.mint else Palette.creamSoft
	_attributes.weight = Enum.FontWeight.Bold
	_attributes.fit = true
	_attributes.minSize = 8
	_attributes.position = UDim2.fromOffset(0, if stack then 58 else 60)
	_attributes.sizeConstraint = UDim2.new(1, if stack then 0 else -260, 0, 18)
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, height),
		accent = row.accent,
		background = Palette.panelRaised,
		padding = if stack then 14 else 16,
		layoutOrder = layoutOrder,
		interactive = actionable,
		highlight = actionable,
		reducedMotion = reducedMotion,
		clips = false,
	}, _exp, _exp_1, _exp_2, React.createElement(Text, _attributes), React.createElement(Meter, {
		value = fill,
		color = row.accent,
		position = UDim2.fromOffset(0, if stack then 82 else 84),
		size = UDim2.new(1, if stack then 0 else -260, 0, 6),
		reducedMotion = reducedMotion,
	}), React.createElement(Text, {
		value = if row.maxed then "MAXED" else `BANK {compactNumber(bank)} / {compactNumber(row.cost)} {currencyLabel}`,
		size = 10,
		color = if row.affordable then Palette.mint else Palette.muted,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(0, if stack then 96 else 98),
		sizeConstraint = UDim2.new(1, if stack then 0 else -260, 0, 16),
	}), React.createElement(Button, {
		text = if row.maxed then "MAXED" elseif row.affordable then `BUY {compactNumber(row.cost)}` else "NEED MORE",
		icon = if row.maxed then "Check" else "Forge",
		onClick = function()
			if actionable and not busy then
				dispatch("BuyGuildUpgrade", {
					Id = row.id,
				})
			end
		end,
		color = if actionable then row.accent else Palette.panelSoft,
		textColor = if actionable then Palette.ink else Palette.creamSoft,
		disabled = not actionable or busy,
		loading = actionable and busy,
		shakeToken = if actionable then shakeToken else 0,
		highlight = actionable,
		size = if stack then UDim2.new(1, 0, 0, 44) else UDim2.fromOffset(240, 44),
		position = if stack then UDim2.new(0, 0, 1, -44) else UDim2.new(1, -240, 1, -44),
		reducedMotion = reducedMotion,
	}))
end
local function MemberRow(_param)
	local userKey = _param.userKey
	local name = _param.name
	local role = _param.role
	local contributed = _param.contributed
	local goalShare = _param.goalShare
	local share = _param.share
	local isLocal = _param.isLocal
	local canManage = _param.canManage
	local isLeader = _param.isLeader
	local stack = _param.stack
	local reducedMotion = _param.reducedMotion
	local dispatch = _param.dispatch
	local busy = _param.busy
	local shakeToken = _param.shakeToken
	local layoutOrder = _param.layoutOrder
	local accent = if role == "Leader" then Palette.mango elseif role == "Officer" then Palette.cyan else Palette.steel
	local surface = if isLocal then darken(Palette.green, 0.88) else Palette.panel
	local _condition = tonumber(userKey)
	if _condition == nil then
		_condition = 0
	end
	local userId = _condition
	local manageable = canManage and Social.canManage({Role=_param.myRole or "Leader"},{Role=role},"Kick")
	local canPromote = (_param.myRole or "Leader") == "Leader"
	local height = if stack then 122 elseif manageable then 112 else 84
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, height),
		accent = if isLocal then Palette.green else accent,
		background = surface,
		padding = if stack then 12 else 14,
		layoutOrder = layoutOrder,
		reducedMotion = reducedMotion,
		clips = false,
	}, React.createElement(PlayerMark, {
		userId = userId,
		accent = accent,
		size = 34,
		position = UDim2.fromOffset(0, 2),
	}), React.createElement(Text, {
		value = name,
		size = 14,
		color = ensureContrast(surface, Palette.cream),
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(44, 0),
		sizeConstraint = UDim2.new(1, if stack then -44 else -44, 0, 20),
	}), React.createElement(Text, {
		value = string.upper(role),
		size = 9,
		color = ensureContrast(surface, accent),
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(44, 20),
		sizeConstraint = UDim2.new(0, 90, 0, 14),
	}), React.createElement(Text, {
		value = `{compactNumber(contributed)} banked  •  {math.floor(share * 100 + 0.5)}% of all deposits`,
		size = 10,
		color = ensureContrast(surface, Palette.muted),
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(44, 36),
		sizeConstraint = UDim2.new(1, if stack then -44 else -44, 0, 16),
	}), goalShare > 0 and React.createElement(Text, {
		value = `{compactNumber(goalShare)} toward this goal`,
		size = 9,
		color = ensureContrast(surface, Palette.mint),
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(44, 52),
		sizeConstraint = UDim2.new(1, if stack then -44 else -44, 0, 14),
	}), manageable and React.createElement(React.Fragment, nil, React.createElement(Button, {
		text = if not canPromote then "LEADER ONLY" elseif role == "Officer" then "DEMOTE" else "PROMOTE",
		onClick = function()
			if not busy then
				dispatch("SetGuildRole", {
					UserId = userId,
					Role = if role == "Officer" then "Member" else "Officer",
				})
			end
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		disabled = busy or not canPromote,
		loading = busy,
		shakeToken = shakeToken,
		size = if stack then UDim2.new(0.5, -4, 0, 40) else UDim2.new(0.5, -4, 0, 40),
		position = if stack then UDim2.new(0, 0, 1, -40) else UDim2.new(0, 0, 1, -40),
		reducedMotion = reducedMotion,
	}), React.createElement(Button, {
		text = if _param.confirmKick then "CONFIRM KICK" else "KICK",
		onClick = function()
			if not busy then
				dispatch("KickGuildMember", {
					UserId = userId,
				})
			end
		end,
		color = Palette.panelSoft,
		textColor = Palette.coral,
		disabled = busy,
		loading = busy,
		shakeToken = shakeToken,
		size = if stack then UDim2.new(0.5, -4, 0, 40) else UDim2.new(0.5, -4, 0, 40),
		position = if stack then UDim2.new(0.5, 4, 1, -40) else UDim2.new(0.5, 4, 1, -40),
		reducedMotion = reducedMotion,
	})))
end
local function sanitizeGuildTag(value)
	return string.sub((string.gsub(string.upper(value), "[^A-Z0-9]", "")), 1, 4)
end
local function JoinOrCreate(_param)
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local busy = _param.busy
	local shakeToken = _param.shakeToken
	local stack = _param.stack
	local cash = _param.cash
	local name, setName = React.useState("")
	local tag, setTag = React.useState("")
	local joinTag, setJoinTag = React.useState("")
	local nameRef = React.useRef(name)
	local tagRef = React.useRef(tag)
	local joinRef = React.useRef(joinTag)
	local _result = config.Guild
	if _result ~= nil then
		_result = _result.CreateCost
	end
	local _condition = _result
	if _condition == nil then
		_condition = 5000
	end
	local createCost = _condition
	local canAfford = gteFlux(cash, createCost)
	local canCharter = not busy and #name >= 3 and #tag >= 3 and canAfford
	local canJoin = not busy and #joinTag >= 3
	local fieldStyle = {
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
	}
	local charter = function()
		local nextName = (string.gsub((string.gsub(nameRef.current, "^%s+", "")), "%s+$", ""))
		local nextTag = sanitizeGuildTag(tagRef.current)
		if busy or #nextName < 3 or #nextTag < 3 or not canAfford then
			return nil
		end
		dispatch("CreateGuild", {
			Name = nextName,
			Tag = nextTag,
		})
	end
	local join = function()
		local nextTag = sanitizeGuildTag(joinRef.current)
		if busy or #nextTag < 3 then
			return nil
		end
		dispatch("JoinGuild", {
			Tag = nextTag,
		})
	end
	local _exp = React.createElement(Text, {
		value = "CHARTER A GUILD",
		size = 10,
		color = Palette.violet,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	})
	local _exp_1 = React.createElement(Text, {
		value = "Start your own hall",
		size = if stack then 21 else 26,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 16,
		position = UDim2.fromOffset(0, 18),
		sizeConstraint = UDim2.new(1, 0, 0, 32),
	})
	local _exp_2 = React.createElement(Text, {
		value = `Costs {compactNumber(createCost)} flux · you have {compactNumber(cash)}. You lead it and share every hall upgrade.`,
		size = 11,
		color = if canAfford then Palette.creamSoft else Palette.coral,
		wrap = true,
		position = UDim2.fromOffset(0, 52),
		sizeConstraint = UDim2.new(1, 0, 0, 32),
	})
	local _attributes = {
		Size = UDim2.new(1, 0, 0, 42),
		Position = UDim2.fromOffset(0, 90),
		PlaceholderText = "Guild name (3-28 characters)",
		Text = name,
		ClearTextOnFocus = false,
		TextColor3 = Palette.cream,
		PlaceholderColor3 = Palette.muted,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		Change = {
			Text = function(box)
				local value = string.sub(box.Text, 1, 28)
				nameRef.current = value
				setName(value)
			end,
		},
		Event = {
			Focused = function()
				return Audio:play("inputFocus")
			end,
		},
	}
	for _k, _v in fieldStyle do
		_attributes[_k] = _v
	end
	local _exp_3 = React.createElement("textbox", _attributes, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		Color = Palette.line,
		Thickness = 1,
		Transparency = 0.55,
	}), React.createElement("uipadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}))
	local _attributes_1 = {
		Size = UDim2.new(1, 0, 0, 42),
		Position = UDim2.fromOffset(0, 138),
		PlaceholderText = "Tag (3-4 letters or numbers)",
		Text = tag,
		ClearTextOnFocus = false,
		TextColor3 = Palette.cream,
		PlaceholderColor3 = Palette.muted,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		Change = {
			Text = function(box)
				local value = sanitizeGuildTag(box.Text)
				tagRef.current = value
				setTag(value)
			end,
		},
		Event = {
			Focused = function()
				return Audio:play("inputFocus")
			end,
		},
	}
	for _k, _v in fieldStyle do
		_attributes_1[_k] = _v
	end
	local _exp_4 = React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, 276),
		accent = Palette.violet,
		background = Palette.panelRaised,
		padding = 18,
		layoutOrder = 1,
		reducedMotion = reducedMotion,
		clips = false,
	}, _exp, _exp_1, _exp_2, _exp_3, React.createElement("textbox", _attributes_1, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		Color = Palette.line,
		Thickness = 1,
		Transparency = 0.55,
	}), React.createElement("uipadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	})), React.createElement(Button, {
		text = if not canAfford then `NEED {compactNumber(createCost)} FLUX` else "CHARTER GUILD",
		icon = "Forge",
		onClick = charter,
		color = if canCharter then Palette.violet else Palette.panelSoft,
		textColor = if canCharter then Palette.ink else Palette.muted,
		disabled = not canCharter,
		loading = canAfford and busy,
		shakeToken = if canAfford then shakeToken else 0,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -TapTarget),
		reducedMotion = reducedMotion,
	}))
	local _exp_5 = React.createElement(Text, {
		value = "JOIN A GUILD",
		size = 10,
		color = Palette.mint,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	})
	local _exp_6 = React.createElement(Text, {
		value = "Already know a tag? Type it in and jump into the hall.",
		size = 11,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 20),
		sizeConstraint = UDim2.new(1, 0, 0, 30),
	})
	local _attributes_2 = {
		Size = UDim2.new(1, 0, 0, 42),
		Position = UDim2.fromOffset(0, 56),
		PlaceholderText = "Guild tag",
		Text = joinTag,
		ClearTextOnFocus = false,
		TextColor3 = Palette.cream,
		PlaceholderColor3 = Palette.muted,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		Change = {
			Text = function(box)
				local value = sanitizeGuildTag(box.Text)
				joinRef.current = value
				setJoinTag(value)
			end,
		},
		Event = {
			Focused = function()
				return Audio:play("inputFocus")
			end,
		},
	}
	for _k, _v in fieldStyle do
		_attributes_2[_k] = _v
	end
	return React.createElement(React.Fragment, nil, _exp_4, React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, 192),
		accent = Palette.mint,
		padding = 18,
		layoutOrder = 2,
		reducedMotion = reducedMotion,
		clips = false,
	}, _exp_5, _exp_6, React.createElement("textbox", _attributes_2, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		Color = Palette.line,
		Thickness = 1,
		Transparency = 0.55,
	}), React.createElement("uipadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	})), React.createElement(Button, {
		text = "JOIN GUILD",
		icon = "Crew",
		onClick = join,
		color = if canJoin then Palette.mint else Palette.panelSoft,
		textColor = if canJoin then Palette.ink else Palette.muted,
		disabled = not canJoin,
		loading = canJoin and busy,
		shakeToken = if canJoin then shakeToken else 0,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -TapTarget),
		reducedMotion = reducedMotion,
	})))
end
local function GuildView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local stack = chrome.contentStack
	local enter = useEntrance(softMotion)
	local reveal = useStagger(0, softMotion)
	local bankReveal = useStagger(1, softMotion)
	local membersReveal = useStagger(2, softMotion)
	local goalReveal = useStagger(3, softMotion)
	local _, refreshRequest = React.useState(0)
	local request = React.useMemo(function()
		return createRequest(dispatch,task.delay,function() refreshRequest(function(v) return v+1 end) end)
	end,{dispatch})
	React.useEffect(function() request.alive=true;return function() request.dispose() end end,{request})
	local busy=request.busy
	local confirmation=React.useRef(nil)
	local pane,setPane=React.useState(_param.initialTab or "Overview")
	local shakeToken, setShakeToken = React.useState(0)
	local contributeCash, setContributeCash = React.useState("")
	local contributeDust, setContributeDust = React.useState("")
	local guild = state.Guild
	local localPlayer = Players.LocalPlayer
	local localKey = if localPlayer ~= nil then tostring(localPlayer.UserId) else ""
	React.useEffect(function()
		dispatch("GetGuild", {})
	end, { dispatch })
	local send = function(action,payload,callback)
		if request.busy then return false end
		if action=="LeaveGuild" or action=="DisbandGuild" or action=="KickGuildMember" then
			local key=action..":"..tostring(payload and payload.UserId or "")
			if not confirmation.current or confirmation.current.key~=key or os.clock()>confirmation.current.untilTime then
				confirmation.current={key=key,untilTime=os.clock()+8}
				request.status="Press the same action again within 8 seconds to confirm. Leaving a guild does not refund contributions."
				refreshRequest(function(v) return v+1 end)
				return false
			end
		end
		confirmation.current=nil
		return request.run(action,payload,function(response)
			if not response.ok then setShakeToken(function(token) return token+1 end) end
			if callback then callback(response) end
		end)
	end
	local function statusSection()
		return {id="guild-feedback",height=96,element=React.createElement(Panel,{size=UDim2.fromScale(1,1),padding=16,accent=Palette.cyan},React.createElement(Text,{value=if request.status~="" then request.status else "Guild actions show their results here. Your role determines which actions are available.",size=13,wrap=true,sizeConstraint=UDim2.new(1,0,0,64)}))}
	end
	if guild == nil or guild.Id == "" then
		local guide = if config.ClientPageGuides ~= nil then config.ClientPageGuides.Guild else nil
		local pageGap = if stack then 12 else Layout.panelGap
		local joinBlockH = 276 + pageGap + 192
		return React.createElement(PageScaffold, {
			gap = pageGap,
			tailPad = scrollTail(chrome.stack, chrome.bottomSafe, 80),
			scrollBarColor = Palette.violet,
			scrollBarThickness = 4,
			sections = {
				statusSection(),
				{
					id = "empty-hero",
					height = 128,
					element = React.createElement(Panel, {
						size = UDim2.fromScale(1, 1),
						accent = Palette.violet,
						background = Palette.panelRaised,
						padding = if stack then 16 else 20,
						highlight = true,
						reveal = enter,
						reducedMotion = softMotion,
						clips = false,
					}, React.createElement(Text, {
						value = (guide and guide.EmptyTitle) or "No guild yet",
						size = 20,
						color = Palette.cream,
						weight = Enum.FontWeight.Heavy,
						sizeConstraint = UDim2.new(1, 0, 0, 28),
					}), React.createElement(Text, {
						value = (guide and guide.EmptyBody) or "Charter one for shared upgrades, or join with a tag.",
						size = 12,
						color = Palette.creamSoft,
						wrap = true,
						position = UDim2.fromOffset(0, 34),
						sizeConstraint = UDim2.new(1, 0, 0, 36),
					}), React.createElement(Text, {
						value = (guide and guide.Benefits) or "Shared production, vault, offline, automation, and tap boosts.",
						size = 11,
						color = Palette.violet,
						weight = Enum.FontWeight.Bold,
						wrap = true,
						position = UDim2.fromOffset(0, 78),
						sizeConstraint = UDim2.new(1, 0, 0, 28),
					})),
				},
				{
					id = "join",
					height = joinBlockH,
					element = React.createElement("frame", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
					}, React.createElement("uilistlayout", {
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, pageGap),
					}), React.createElement(JoinOrCreate, {
						config = config,
						dispatch = send,
						reducedMotion = softMotion,
						busy = busy,
						shakeToken = shakeToken,
						stack = stack,
						cash = state.Cash,
					})),
				},
			},
		})
	end
	local members = {}
	for key, member in pairs(guild.Members) do
		local _arg0 = {
			key = key,
			name = member.Name,
			role = member.Role,
			contributed = member.Contributed,
		}
		table.insert(members, _arg0)
	end
	table.sort(members, function(left, right)
		local _condition = ROLE_RANK[left.role]
		if _condition == nil then
			_condition = 3
		end
		local leftRank = _condition
		local _condition_1 = ROLE_RANK[right.role]
		if _condition_1 == nil then
			_condition_1 = 3
		end
		local rightRank = _condition_1
		if leftRank ~= rightRank then
			return leftRank < rightRank
		end
		return left.contributed > right.contributed
	end)
	local totalContributed = 0
	for _, member in members do
		totalContributed += member.contributed
	end
	local _result = guild.Members[localKey]
	if _result ~= nil then
		_result = _result.Role
	end
	local _condition = _result
	if _condition == nil then
		_condition = "Member"
	end
	local myRole = _condition
	local canManage = myRole == "Leader"
	local canBuy = myRole == "Leader" or myRole == "Officer"
	local rows = buildUpgradeRows(config, guild)
	local _goalContributors = guild.Goal
	if _goalContributors ~= nil then
		_goalContributors = _goalContributors.Contributors
	end
	local goalContributors = _goalContributors
	local pageGap = if stack then 12 else Layout.panelGap
	local heroHeight = if stack then 218 else 188
	local goalHeight = if guild.Goal == nil then 116 elseif stack then 234 else 196
	local bankHeight = if stack then 310 else 216
	local upgradeHeight = if stack then 180 else 140
	local memberHeight = if stack then 122 elseif canBuy then 112 else 84
	local sectionLabelH = 34
	local heroSurface = darken(Palette.violet, 0.9)
	local _attributes = {}
	local _exp_2 = guild.Tag
	local _exp_3 = #members
	local _result_1 = config.Guild
	if _result_1 ~= nil then
		_result_1 = _result_1.MaxMembers
	end
	local _condition_1 = _result_1
	if _condition_1 == nil then
		_condition_1 = 20
	end
	_attributes.value = `[{_exp_2}]  •  {_exp_3}/{_condition_1} MEMBERS`
	_attributes.size = 10
	_attributes.color = ensureContrast(heroSurface, Palette.violet)
	_attributes.weight = Enum.FontWeight.Heavy
	_attributes.sizeConstraint = UDim2.new(1, -8, 0, 14)
	local _exp_4 = React.createElement(Text, _attributes)
	local _exp_5 = React.createElement(Text, {
		value = guild.Name,
		size = if stack then 24 else 31,
		color = ensureContrast(heroSurface, Palette.cream),
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 17,
		position = UDim2.fromOffset(0, 20),
		sizeConstraint = UDim2.new(1, -8, 0, 38),
	})
	local _exp_6 = React.createElement(Text, {
		value = `ACTIVITY {compactNumber(guild.Activity)}  •  YOU ARE {string.upper(myRole)}`,
		size = 11,
		color = ensureContrast(heroSurface, Palette.creamSoft),
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(0, if stack then 62 else 64),
		sizeConstraint = UDim2.new(1, -8, 0, 18),
	})
	local _attributes_1 = {}
	local _result_2 = state.GuildBonuses
	if _result_2 ~= nil then
		_result_2 = _result_2.Production
	end
	local _condition_2 = _result_2
	if _condition_2 == nil then
		_condition_2 = 0
	end
	local _exp_7 = percentText(_condition_2)
	local _result_3 = state.GuildBonuses
	if _result_3 ~= nil then
		_result_3 = _result_3.Capacity
	end
	local _condition_3 = _result_3
	if _condition_3 == nil then
		_condition_3 = 0
	end
	local _exp_8 = percentText(_condition_3)
	local _result_4 = state.GuildBonuses
	if _result_4 ~= nil then
		_result_4 = _result_4.Offline
	end
	local _condition_4 = _result_4
	if _condition_4 == nil then
		_condition_4 = 0
	end
	local _exp_9 = percentText(_condition_4)
	local _result_5 = state.GuildBonuses
	if _result_5 ~= nil then
		_result_5 = _result_5.Automation
	end
	local _condition_5 = _result_5
	if _condition_5 == nil then
		_condition_5 = 0
	end
	local _exp_10 = percentText(_condition_5)
	local _result_6 = state.GuildBonuses
	if _result_6 ~= nil then
		_result_6 = _result_6.Tap
	end
	local _condition_6 = _result_6
	if _condition_6 == nil then
		_condition_6 = 0
	end
	_attributes_1.value = `SHARED BONUSES  {_exp_7} production  •  {_exp_8} vault  •  {_exp_9} offline  •  {_exp_10} auto  •  {percentText(_condition_6)} tap`
	_attributes_1.size = 10
	_attributes_1.color = ensureContrast(heroSurface, Palette.mint)
	_attributes_1.wrap = true
	_attributes_1.position = UDim2.fromOffset(0, if stack then 86 else 88)
	_attributes_1.sizeConstraint = UDim2.new(1, -8, 0, if stack then 46 else 32)
	local _exp_11 = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.violet,
		background = heroSurface,
		padding = if stack then 16 else 20,
		reveal = if reducedMotion then bankReveal else reveal,
		highlight = not reducedMotion and membersReveal ~= nil and goalReveal ~= nil,
		reducedMotion = softMotion,
		clips = false,
	}, _exp_4, _exp_5, _exp_6, React.createElement(Text, _attributes_1), if canManage and #members == 1 then React.createElement(Button, {
		text = if confirmation.current and confirmation.current.key=="DisbandGuild:" then "CONFIRM DISBAND" else "DISBAND",
		onClick = function()
			if not busy then
				send("DisbandGuild", {})
			end
		end,
		color = Palette.panelSoft,
		textColor = Palette.coral,
		disabled = busy,
		loading = busy,
		shakeToken = shakeToken,
		size = if stack then UDim2.new(1, 0, 0, 42) else UDim2.fromOffset(140, 42),
		position = if stack then UDim2.new(0, 0, 1, -42) else UDim2.new(1, -140, 1, -42),
		reducedMotion = softMotion,
	}) else React.createElement(Button, {
		text = if confirmation.current and confirmation.current.key=="LeaveGuild:" then "CONFIRM LEAVE" else "LEAVE",
		onClick = function()
			if not busy then
				send("LeaveGuild", {})
			end
		end,
		color = Palette.panelSoft,
		textColor = Palette.coral,
		disabled = busy,
		loading = busy,
		shakeToken = shakeToken,
		size = if stack then UDim2.new(1, 0, 0, 42) else UDim2.fromOffset(140, 42),
		position = if stack then UDim2.new(0, 0, 1, -42) else UDim2.new(1, -140, 1, -42),
		reducedMotion = softMotion,
	}))
	local _exp_12 = React.createElement(GuildGoalCard, {
		guild = guild,
		config = config,
		layoutOrder = 0,
		stack = stack,
		reducedMotion = reducedMotion,
		dispatch = send,
		busy = busy,
		shakeToken = shakeToken,
	})
	local _exp_13 = React.createElement(Text, {
		value = "GUILD BANK",
		size = 10,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	})
	local _exp_14 = React.createElement(Text, {
		value = `{compactNumber(guild.BankCash)} flux  •  {compactNumber(guild.BankDust)} dust`,
		size = if stack then 17 else 20,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 13,
		position = UDim2.fromOffset(0, 18),
		sizeConstraint = UDim2.new(1, 0, 0, 26),
	})
	local _exp_15 = React.createElement(Text, {
		value = "Deposits fund every hall upgrade and count toward the guild goal.",
		size = 10,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(0, 46),
		sizeConstraint = UDim2.new(1, 0, 0, 26),
	})
	local _exp_16 = React.createElement("textbox", {
		Size = if stack then UDim2.new(1, 0, 0, 40) else UDim2.new(0.5, -6, 0, 40),
		Position = UDim2.fromOffset(0, 76),
		PlaceholderText = "Flux amount",
		Text = contributeCash,
		ClearTextOnFocus = false,
		TextColor3 = Palette.cream,
		PlaceholderColor3 = Palette.muted,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		Change = {
			Text = function(box)
				return setContributeCash(box.Text)
			end,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		Color = Palette.line,
		Thickness = 1,
		Transparency = 0.55,
	}), React.createElement("uipadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}))
	local _attributes_2 = {
		text = "DEPOSIT FLUX",
		onClick = function()
			local amount = tonumber(contributeCash)
			if amount ~= nil and amount >= 1 and not busy then
				send("ContributeGuild", {
					Amount = math.floor(amount),
					Currency = "Cash",
				})
				setContributeCash("")
			end
		end,
		color = Palette.mango,
		textColor = Palette.ink,
	}
	local _condition_7 = busy
	if not _condition_7 then
		local _condition_8 = tonumber(contributeCash)
		if _condition_8 == nil then
			_condition_8 = 0
		end
		_condition_7 = _condition_8 < 1
	end
	_attributes_2.disabled = _condition_7
	_attributes_2.size = if stack then UDim2.new(1, 0, 0, 42) else UDim2.new(0.5, -6, 0, 42)
	_attributes_2.position = if stack then UDim2.fromOffset(0, 126) else UDim2.new(0, 0, 0, 128)
	_attributes_2.reducedMotion = reducedMotion
	local _exp_17 = React.createElement(Button, _attributes_2)
	local _exp_18 = React.createElement("textbox", {
		Size = if stack then UDim2.new(1, 0, 0, 40) else UDim2.new(0.5, -6, 0, 40),
		Position = if stack then UDim2.fromOffset(0, 172) else UDim2.new(0.5, 6, 0, 76),
		PlaceholderText = "Dust amount",
		Text = contributeDust,
		ClearTextOnFocus = false,
		TextColor3 = Palette.cream,
		PlaceholderColor3 = Palette.muted,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		Change = {
			Text = function(box)
				return setContributeDust(box.Text)
			end,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		Color = Palette.line,
		Thickness = 1,
		Transparency = 0.55,
	}), React.createElement("uipadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}))
	local _attributes_3 = {
		text = "DEPOSIT DUST",
		onClick = function()
			local amount = tonumber(contributeDust)
			if amount ~= nil and amount >= 1 and not busy then
				send("ContributeGuild", {
					Amount = math.floor(amount),
					Currency = "Dust",
				})
				setContributeDust("")
			end
		end,
		color = Palette.cyan,
		textColor = Palette.ink,
	}
	local _condition_8 = busy
	if not _condition_8 then
		local _condition_9 = tonumber(contributeDust)
		if _condition_9 == nil then
			_condition_9 = 0
		end
		_condition_8 = _condition_9 < 1
	end
	_attributes_3.disabled = _condition_8
	_attributes_3.size = if stack then UDim2.new(1, 0, 0, 42) else UDim2.new(0.5, -6, 0, 42)
	_attributes_3.position = if stack then UDim2.fromOffset(0, 222) else UDim2.new(0.5, 6, 0, 128)
	_attributes_3.reducedMotion = reducedMotion
	local _exp_19 = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.mango,
		background = Palette.panelRaised,
		padding = if stack then 16 else 18,
		reducedMotion = reducedMotion,
		clips = false,
	}, _exp_13, _exp_14, _exp_15, _exp_16, _exp_17, _exp_18, React.createElement(Button, _attributes_3))
	local _exp_20 = React.createElement(SectionLabel, {
		value = "HALL UPGRADES",
		color = Palette.violet,
	})
	local upgradeChildren = {}
	if #rows == 0 then
		upgradeChildren[1] = React.createElement(EmptyState, {
			key = "empty-upgrades",
			title = "No hall upgrades",
			body = "Upgrade definitions are still loading.",
			icon = "Forge",
			accent = Palette.violet,
			size = UDim2.new(1, 0, 0, 72),
			layoutOrder = 1,
		})
	else
		for index, row in rows do
			upgradeChildren[index] = React.createElement(UpgradeCard, {
				key = row.id,
				row = row,
				guild = guild,
				canBuy = canBuy,
				stack = stack,
				reducedMotion = reducedMotion,
				dispatch = send,
				busy = busy,
				shakeToken = shakeToken,
				layoutOrder = index,
			})
		end
	end
	local upgradeBlockH = if #rows == 0 then 72 else #rows * upgradeHeight + math.max(0, #rows - 1) * pageGap
	local upgradeList = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, pageGap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), upgradeChildren)
	local memberChildren = {}
	for index, member in members do
		local share = 0
		if goalContributors ~= nil then
			share = goalContributors[member.key] or 0
		end
		memberChildren[index] = React.createElement(MemberRow, {
			key = member.key,
			userKey = member.key,
			name = member.name,
			role = member.role,
			contributed = member.contributed,
			goalShare = share,
			share = if totalContributed > 0 then member.contributed / totalContributed else 0,
			isLocal = member.key == localKey,
			canManage = canBuy and member.key ~= localKey,
			myRole = myRole,
			confirmKick = confirmation.current and confirmation.current.key=="KickGuildMember:"..tostring(member.key),
			isLeader = member.role == "Leader",
			stack = stack,
			reducedMotion = reducedMotion,
			dispatch = send,
			busy = busy,
			shakeToken = shakeToken,
			layoutOrder = index,
		})
	end
	local memberBlockH = if #members == 0 then 72 else #members * memberHeight + math.max(0, #members - 1) * pageGap
	local overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2
	local memberList = if #members == 0 then React.createElement(EmptyState, {
		title = "No members",
		body = "Members show up here.",
		icon = "Pilot",
		accent = Palette.cyan,
		size = UDim2.new(1, 0, 0, 72),
	}) else React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, pageGap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), memberChildren)
	local hall=Social.hall(guild)
	local tabs={}
	local columns=if stack then 2 else 4
	for index,id in {"Overview","Treasury","Upgrades","Members"} do
		tabs[index]=React.createElement(Button,{text=string.upper(id),size=UDim2.new(1/columns,-6,0,48),position=UDim2.new(((index-1)%columns)/columns,0,0,math.floor((index-1)/columns)*56),color=if pane==id then Palette.violet else Palette.panelSoft,onClick=function() setPane(id) end,reducedMotion=softMotion})
	end
	local sections={
		{id="hero",height=heroHeight,element=_exp_11},
		statusSection(),
		{id="guild-navigation",height=if stack then 112 else 56,element=React.createElement("frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1},tabs)},
	}
	local function add(id,height,element) table.insert(sections,{id=id,height=height,element=element}) end
	if pane=="Overview" then
		add("hall-progress",174,React.createElement(Panel,{size=UDim2.fromScale(1,1),padding=16,accent=Palette.mint},
			React.createElement(Text,{value=`HALL LEVEL {hall.Level} · {hall.Title}`,size=19,wrap=true,sizeConstraint=UDim2.new(1,0,0,42)}),
			React.createElement(Meter,{value=hall.Progress,position=UDim2.fromOffset(0,52),size=UDim2.new(1,0,0,10),color=Palette.mint,reducedMotion=softMotion}),
			React.createElement(Text,{value=`{hall.Remaining} more hall upgrades to level up. Every five installed upgrade levels earn a hall level. Hall titles celebrate progress; upgrade bonuses apply separately.`,position=UDim2.fromOffset(0,78),size=13,wrap=true,sizeConstraint=UDim2.new(1,0,0,64)})))
		add("goal",goalHeight,_exp_12)
	elseif pane=="Treasury" then
		add("bank",bankHeight,_exp_19)
	elseif pane=="Upgrades" then
		add("upgrades-label",sectionLabelH,_exp_20)
		add("upgrades",upgradeBlockH,upgradeList)
	else
		add("role-policy",176,React.createElement(Panel,{size=UDim2.fromScale(1,1),padding=16,accent=Palette.cyan},
			React.createElement(Text,{value="ROLES & SUCCESSION",size=17,sizeConstraint=UDim2.new(1,0,0,28)}),
			React.createElement(Text,{value="Leader: assigns roles and manages the hall. Officer: buys upgrades and removes members. Member: contributes and earns goal rewards. If the leader leaves, an officer succeeds first, then the earliest joiner; user ID breaks ties.",position=UDim2.fromOffset(0,40),size=13,wrap=true,sizeConstraint=UDim2.new(1,0,0,104)})))
		add("members",memberBlockH,memberList)
	end
	return React.createElement(PageScaffold,{gap=12,tailPad=scrollTail(chrome.stack,chrome.bottomSafe,80),scrollBarColor=Palette.violet,scrollBarThickness=4,sections=sections})

end
return {
	GuildView = GuildView,
}
end

__defs["MailboxView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local formatReward = require(script.Parent.Parent.CoreKit)("format").formatReward
local Icon = require(script.Parent.Parent.ArtKit)("Icon").Icon
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useFlipperSpring = _motion.useFlipperSpring
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local Layout = _theme.Layout
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local darken = _theme.darken
local TapTarget = _theme.TapTarget
local FlatList = require(script.Parent.Parent.LayoutKit)("virtualizedList").FlatList
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local EmptyState = _ui.EmptyState
local Text = _ui.Text
local measureWrappedTextHeight = _ui.measureWrappedTextHeight
local ScriptedText = require(script.Parent.Parent.ReactHosts)("RichTextHost").ScriptedText
local LIST_HEADER = 72
local LIST_CARD = 124
local LIST_CARD_MOBILE = 132
local LIST_GAP = 10
local DETAIL_HEADER = 96
local FOOTER_HEIGHT = 84
local FOOTER_HEIGHT_MOBILE = 168
local function paragraphHeight(value, width, size)
	return math.max(20, measureWrappedTextHeight(value, width, size, Enum.FontWeight.Regular) + 4)
end
local function MailRow(_param)
	local item = _param.item
	local active = _param.active
	local unread = _param.unread
	local cardH = _param.cardH
	local stack = _param.stack
	local reducedMotion = _param.reducedMotion
	local layoutOrder = _param.layoutOrder
	local onChoose = _param.onChoose
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local reveal = useStagger(layoutOrder, softMotion)
	return React.createElement("imagebutton", {
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, -4, 0, cardH),
		BackgroundTransparency = reveal:map(function(amount)
			return 1 - amount
		end),
		BackgroundColor3 = if active then item.Color:Lerp(Palette.panelRaised, 0.82) else Palette.panelRaised,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = true,
		ClipsDescendants = false,
		Event = {
			Activated = function()
				return onChoose(item.Id)
			end,
			MouseEnter = function()
				return Audio:play("hover")
			end,
			SelectionGained = function()
				return Audio:play("hover")
			end,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		Color = if active or unread then item.Color else Palette.lineSoft,
		Thickness = 1,
		Transparency = if active then 0.16 elseif unread then 0.38 else 0.7,
	}), unread and React.createElement("frame", {
		Size = UDim2.new(0, 3, 1, -18),
		Position = UDim2.fromOffset(0, 9),
		BackgroundColor3 = item.Color,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 2),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(TapTarget, TapTarget),
		Position = UDim2.fromOffset(12, math.floor((cardH - TapTarget) / 2)),
		BackgroundColor3 = item.Color,
		BackgroundTransparency = if unread then 0.08 else 0.8,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement(Icon, {
		kind = "Mail",
		color = if unread then Palette.ink else Palette.creamSoft,
		accent = item.Color,
		size = 26,
		position = UDim2.fromOffset(11, 11),
		spin = false,
			reducedMotion = softMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(1, -80, 1, -16),
		Position = UDim2.fromOffset(72, 12),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(Text, {
		value = item.Subject,
		size = if stack then 15 else 14,
		color = Palette.cream,
		weight = if unread then Enum.FontWeight.Heavy else Enum.FontWeight.Bold,
		fit = true,
		minSize = 10,
		sizeConstraint = UDim2.new(1, -14, 0, 22),
	}), React.createElement(Text, {
		value = item.Sender,
		size = 13,
		color = item.Color,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(0, 26),
		sizeConstraint = UDim2.new(1, -14, 0, 18),
	}), React.createElement(Text, {
		value = item.Preview,
		size = 12,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(0, 48),
		sizeConstraint = UDim2.new(1, -10, 0, 52),
	})), unread and React.createElement("frame", {
		Size = UDim2.fromOffset(9, 9),
		Position = UDim2.new(1, -18, 0, 14),
		BackgroundColor3 = item.Color,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end
local function MailboxView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local mountedRef = React.useRef(true)
	local mailActionsHostRef = React.useRef(nil)
	React.useEffect(function()
		return function()
			mountedRef.current = false
		end
	end, {})
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local stack = chrome.contentStack
	local mobileRoute = chrome.mobile
	local compactChrome = chrome.landscape or viewport.keyboardOpen or viewport.height < 700
	local listHeaderH = if compactChrome then 56 else LIST_HEADER
	local detailHeaderH = if compactChrome then 56 else DETAIL_HEADER
	local cardH = if stack then LIST_CARD_MOBILE else LIST_CARD
	local footerH = if stack then FOOTER_HEIGHT_MOBILE else FOOTER_HEIGHT
	local rowStride = cardH + LIST_GAP
	local listReveal = useStagger(0, softMotion)
	local detailSoftReveal = useStagger(1, softMotion)
	local footerReveal = useStagger(2, softMotion)
	local mailboxSoft = softMotion or listReveal == nil or detailSoftReveal == nil or footerReveal == nil
	local _result = state.Mailbox
	if _result ~= nil then
		_result = _result.Messages
	end
	local _condition = _result
	if _condition == nil then
		_condition = {}
	end
	local messages = _condition
	local inboxRows = {}
	for _, mailState in messages do
		local mailDef
		for _, value in config.Mail do
			if value.Id == mailState.Id then
				mailDef = value
				break
			end
		end
		if mailDef ~= nil then
			table.insert(inboxRows, {
				Id = mailDef.Id,
				item = mailDef,
				mailState = mailState,
			})
		end
	end
	local _result_1 = state.Mailbox
	if _result_1 ~= nil then
		_result_1 = _result_1.Unread
	end
	local _condition_1 = _result_1
	if _condition_1 == nil then
		_condition_1 = 0
	end
	local unreadCount = _condition_1
	local _result_2 = 0
	local _callback = function(count, item)
		return count + (if item.Claimed then 0 else 1)
	end
	for _i = 1, #messages do
		_result_2 = _callback(_result_2, messages[_i], _i - 1, messages)
	end
	local claimableCount = _result_2
	local _result_3 = messages[1]
	if _result_3 ~= nil then
		_result_3 = _result_3.Id
	end
	local _condition_2 = _result_3
	if _condition_2 == nil then
		_condition_2 = ""
	end
	local firstId = _condition_2
	local selectedId, setSelectedId = React.useState(if mobileRoute then "" else firstId)
	local _callback_1 = function(item)
		return item.Id == selectedId
	end
	local _result_4
	for _i, _v in messages do
		if _callback_1(_v, _i - 1, messages) == true then
			_result_4 = _v
			break
		end
	end
	local explicitSelection = _result_4
	local selectedState = explicitSelection or (if mobileRoute then nil else messages[1])
	local _exp = config.Mail
	local _callback_2 = function(item)
		local _exp_1 = item.Id
		local _result_5 = selectedState
		if _result_5 ~= nil then
			_result_5 = _result_5.Id
		end
		return _exp_1 == _result_5
	end
	local _result_5
	for _i, _v in _exp do
		if _callback_2(_v, _i - 1, _exp) == true then
			_result_5 = _v
			break
		end
	end
	local message = _result_5
	local detailPaneWidth = if mobileRoute or stack then viewport.width else viewport.width * 0.66 - 7
	local paragraphWidth = math.max(40, detailPaneWidth - 8)
	local bodyTextSize = if stack then 16 else 15
	local _result_7 = selectedState
	if _result_7 ~= nil then
		_result_7 = _result_7.Claimed
	end
	local claimed = _result_7 == true
	local inboxEmpty = #inboxRows == 0
	local showMobileDetail = mobileRoute and explicitSelection ~= nil
	local detailReveal = useFlipperSpring(if showMobileDetail then 1 else 0, softMotion, 720, 40)
	local _exp_1 = function()
		if not explicitSelection or explicitSelection.Read then
			return nil
		end
		dispatch("ReadMail", {
			Id = explicitSelection.Id,
		})
	end
	local _result_8 = explicitSelection
	if _result_8 ~= nil then
		_result_8 = _result_8.Id
	end
	local _result_9 = explicitSelection
	if _result_9 ~= nil then
		_result_9 = _result_9.Read
	end
	React.useEffect(_exp_1, { _result_8, _result_9 })
	React.useEffect(function()
		if message == nil or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = mailActionsHostRef.current
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
			pcall(task.cancel, selectJob)
		end
	end, { selectedId, claimed, message ~= nil })
	local choose = function(id)
		if id == selectedId then
			return nil
		end
		Audio:play("mailRead")
		setSelectedId(id)
	end
	local listPanePosition = if mobileRoute then detailReveal:map(function(amount)
		return UDim2.new(-math.clamp(amount, 0, 1), 0, 0, 0)
	end) else nil
	local _exp_2 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	})
	local _exp_3 = React.createElement("uistroke", {
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.36,
	})
	local _exp_4 = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, listHeaderH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.fromOffset(14, math.floor((listHeaderH - 36) / 2)),
		BackgroundColor3 = darken(Palette.cyan, 0.7),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement(Icon, {
		kind = "Mail",
		color = Palette.cream,
		accent = Palette.cyan,
		size = 24,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		reducedMotion = softMotion,
	})), React.createElement(Text, {
		value = "INBOX",
		size = 11,
		color = Palette.cyan,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(60, 14),
		sizeConstraint = UDim2.new(1, -180, 0, 18),
	}), React.createElement(Text, {
		value = if inboxEmpty then "No letters" else `{#inboxRows} letter{if #inboxRows == 1 then "" else "s"}`,
		size = 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(60, 34),
		sizeConstraint = UDim2.new(1, -180, 0, 24),
	}), if claimableCount > 0 then React.createElement(Button, {
		text = if compactChrome then "CLAIM ALL" else `CLAIM ALL ({claimableCount})`,
		icon = "Gift",
		onClick = function()
			return dispatch("ClaimAllMail", {})
		end,
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.fromOffset(if compactChrome then 108 else 132, TapTarget),
		reducedMotion = softMotion,
		highlight = not mailboxSoft,
	}) else React.createElement(Badge, {
		value = if unreadCount > 0 then `{unreadCount} NEW` else "CAUGHT UP",
		accent = if unreadCount > 0 then Palette.coral else Palette.mint,
		filled = unreadCount > 0,
		position = UDim2.new(1, -118, 0.5, -13),
		size = UDim2.fromOffset(106, 26),
	}))
	local _result_10
	if inboxEmpty then
		_result_10 = React.createElement("frame", {
			Size = UDim2.new(1, -16, 1, -(listHeaderH + 12)),
			Position = UDim2.fromOffset(8, listHeaderH + 4),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement(EmptyState, {
			icon = "Mail",
			title = "Tray empty",
			body = "Patch notes and gifts land here.",
			accent = Palette.cyan,
			size = UDim2.fromScale(1, 1),
			titleSize = 20,
			bodySize = 15,
			iconSize = 52,
			reducedMotion = softMotion,
		}))
	else
		local _result_11 = selectedState
		if _result_11 ~= nil then
			_result_11 = _result_11.Id
		end
		local selectedRowId = _result_11
		_result_10 = React.createElement(FlatList, {
			data = inboxRows,
			itemHeight = rowStride,
			headerHeight = 0,
			footerHeight = TapTarget + 8,
			overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
			canvasTail = 4,
			Size = UDim2.new(1, -20, 1, -(listHeaderH + 12)),
			Position = UDim2.fromOffset(10, listHeaderH + 4),
			scrollBarColor = Palette.cyan,
			scrollBarThickness = 3,
			scrollBarTransparency = 0.28,
			keyExtractor = function(row)
				return row.Id
			end,
			renderItem = function(_param_1)
				local row = _param_1.item
				return React.createElement(MailRow, {
					item = row.item,
					active = row.Id == selectedRowId,
					unread = not row.mailState.Read,
					cardH = cardH,
					stack = stack,
					reducedMotion = softMotion,
					layoutOrder = 0,
					onChoose = choose,
				})
			end,
			ListFooterComponent = React.createElement("frame", {
				Size = UDim2.new(1, -4, 0, TapTarget),
				Position = UDim2.fromOffset(0, #inboxRows * rowStride + 4),
				BackgroundColor3 = Palette.panelRaised,
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 10),
			}), React.createElement(Text, {
				value = if #inboxRows == 1 then "Caught up" else "End of inbox",
				size = 13,
				color = Palette.muted,
				weight = Enum.FontWeight.Bold,
				align = Enum.TextXAlignment.Center,
				fit = false,
				sizeConstraint = UDim2.fromScale(1, 1),
			})),
		})
	end
	local stackListH = if stack and not mobileRoute then math.clamp(listHeaderH + cardH + 28, math.floor(viewport.height * 0.28), math.floor(viewport.height * 0.38)) else 0
	local listPane = React.createElement("frame", {
		Size = if mobileRoute then UDim2.fromScale(1, 1) elseif stack then UDim2.new(1, 0, 0, stackListH) else UDim2.new(0.34, -7, 1, 0),
		Position = listPanePosition,
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, _exp_2, _exp_3, _exp_4, _result_10)
	local detailPanePosition = if mobileRoute then detailReveal:map(function(amount)
		return UDim2.new(1 - math.clamp(amount, 0, 1), 0, 0, 0)
	end) elseif stack then UDim2.new(0, 0, 0, stackListH + 8) else UDim2.new(0.34, 7, 0, 0)
	local _exp_5 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	})
	local _attributes = {}
	local _result_11 = message
	if _result_11 ~= nil then
		_result_11 = _result_11.Color
	end
	local _condition_4 = _result_11
	if _condition_4 == nil then
		_condition_4 = Palette.lineSoft
	end
	_attributes.Color = _condition_4
	_attributes.Thickness = 1
	_attributes.Transparency = 0.45
	local _exp_6 = React.createElement("uistroke", _attributes)
	local _exp_7 = message == nil and React.createElement("frame", {
		Size = UDim2.new(1, -40, 1, -40),
		Position = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(EmptyState, {
		icon = "Mail",
		title = "Inbox empty",
		body = "Patch notes, letters, and gifts land here.",
		accent = Palette.cyan,
		size = UDim2.fromScale(1, 1),
		titleSize = 24,
		bodySize = 16,
		iconSize = 64,
		reducedMotion = reducedMotion,
	}))
	local _condition_5 = message ~= nil
	if _condition_5 then
		local _exp_8 = React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, detailHeaderH),
			Position = UDim2.fromOffset(0, 0),
			BackgroundColor3 = message.Color,
			BackgroundTransparency = 0.9,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			ZIndex = 5,
		}, mobileRoute and React.createElement(Button, {
			text = "",
			icon = "Back",
			onClick = function()
				return setSelectedId("")
			end,
			color = Palette.panelSoft,
			textColor = message.Color,
			outline = true,
			size = UDim2.fromOffset(TapTarget, TapTarget),
			position = UDim2.fromOffset(8, math.floor((detailHeaderH - TapTarget) / 2)),
			reducedMotion = reducedMotion,
			zIndex = 8,
		}), not mobileRoute and React.createElement(Icon, {
			kind = "Mail",
			color = Palette.cream,
			accent = message.Color,
			size = 42,
			position = UDim2.fromOffset(18, math.floor((detailHeaderH - 42) / 2)),
			reducedMotion = softMotion,
		}), React.createElement(Text, {
			value = message.Subject,
			size = if compactChrome then 16 elseif stack then 18 else 20,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			minSize = 12,
			position = UDim2.fromOffset(if mobileRoute then 66 else 74, if compactChrome then 7 else 18),
			sizeConstraint = UDim2.new(1, if mobileRoute then -78 else -94, 0, if compactChrome then 22 else 30),
		}), React.createElement(Text, {
			value = `From {message.Sender}`,
			size = if compactChrome then 11 else 13,
			color = message.Color,
			weight = Enum.FontWeight.Bold,
			fit = true,
			minSize = 9,
			position = UDim2.fromOffset(if mobileRoute then 66 else 74, if compactChrome then 30 else 54),
			sizeConstraint = UDim2.new(1, if mobileRoute then -78 elseif stack then -24 else -220, 0, 18),
		}), not stack and React.createElement(Text, {
			value = message.Date,
			size = 12,
			color = Palette.muted,
			weight = Enum.FontWeight.Bold,
			fit = false,
			align = Enum.TextXAlignment.Right,
			position = UDim2.new(1, -200, 0, 56),
			sizeConstraint = UDim2.fromOffset(180, 16),
		}))
		local _exp_10 = message.Body
		local bodyRows = table.create(#_exp_10)
		local bodyStride = 28
		for index, paragraph in _exp_10 do
			local height = paragraphHeight(paragraph, paragraphWidth, bodyTextSize)
			bodyStride = math.max(bodyStride, height + 8)
			bodyRows[index] = {
				Id = `{message.Id}:{index}`,
				Text = paragraph,
				Index = index - 1,
				Height = height,
			}
		end
		_condition_5 = React.createElement(React.Fragment, nil, _exp_8, React.createElement(FlatList, {
			key = message.Id,
			data = bodyRows,
			itemHeight = bodyStride,
			overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
			canvasTail = 8,
			Size = UDim2.new(1, -40, 1, -(detailHeaderH + footerH + 8)),
			Position = UDim2.fromOffset(20, detailHeaderH + 4),
			scrollBarColor = message.Color,
			scrollBarThickness = 3,
			scrollBarTransparency = 0.18,
			keyExtractor = function(row)
				return row.Id
			end,
			renderItem = function(_param_1)
				local row = _param_1.item
				local index = row.Index
				local paragraph = row.Text
				if index == 0 then
					return React.createElement(ScriptedText, {
						key = row.Id,
						layoutOrder = 0,
						text = paragraph,
						width = paragraphWidth,
						height = row.Height,
						size = bodyTextSize,
						color = Palette.creamSoft,
						weight = Enum.FontWeight.SemiBold,
						typewriterInterval = 0.012,
						reducedMotion = softMotion,
					})
				end
				return React.createElement(Text, {
					key = row.Id,
					layoutOrder = index,
					value = paragraph,
					size = bodyTextSize,
					color = Palette.creamSoft,
					wrap = true,
					weight = Enum.FontWeight.Regular,
					sizeConstraint = UDim2.new(1, -8, 0, row.Height),
				})
			end,
		}), React.createElement("frame", {
			ref = mailActionsHostRef,
			key = "footer",
			Name = "MailClaimActions",
			Size = UDim2.new(1, 0, 0, footerH),
			Position = UDim2.new(0, 0, 1, -footerH),
			BackgroundColor3 = Palette.panel,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			ZIndex = 6,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 12),
		}), React.createElement("uistroke", {
			Color = Palette.lineSoft,
			Thickness = 1,
			Transparency = 0.58,
		}), React.createElement(Icon, {
			kind = "Gift",
			color = Palette.cream,
			accent = message.Color,
			size = 30,
			position = UDim2.fromOffset(14, 20),
				reducedMotion = softMotion,
		}), React.createElement(Text, {
			value = "ATTACHMENT",
			size = 12,
			color = message.Color,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			position = UDim2.fromOffset(56, 14),
			sizeConstraint = UDim2.new(1, if stack then -(56 + 20) else -300, 0, 16),
		}), React.createElement(Text, {
			value = formatReward(message.Attachment),
			size = 14,
			color = Palette.cream,
			weight = Enum.FontWeight.Bold,
			fit = true,
			minSize = 10,
			position = UDim2.fromOffset(56, 34),
			sizeConstraint = UDim2.new(1, if stack then -(56 + 20) else -300, 0, 22),
		}), if stack then React.createElement("frame", {
			Size = UDim2.new(1, -16, 0, TapTarget * 2 + 8),
			Position = UDim2.new(0, 8, 1, -(TapTarget * 2 + 18)),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		}, React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, chrome.controlGap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}), React.createElement("frame", {
			Name = "MailClaim",
			Size = UDim2.new(1, 0, 0, TapTarget),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			LayoutOrder = 1,
		}, React.createElement(Button, {
			text = if claimed then "COLLECTED" else "CLAIM",
			icon = "Gift",
			onClick = function()
				return dispatch("ClaimMail", {
					Id = message.Id,
				})
			end,
			color = if claimed then Palette.panelSoft else message.Color,
			textColor = if claimed then Palette.muted else Palette.ink,
			size = UDim2.fromScale(1, 1),
			disabled = claimed,
				reducedMotion = softMotion,
			highlight = not claimed,
		})), React.createElement("frame", {
			Name = "MailArchive",
			Size = UDim2.new(1, 0, 0, TapTarget),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 2,
		}, React.createElement(Button, {
			text = "ARCHIVE",
			icon = "Close",
			onClick = function()
				return dispatch("DeleteMail", {
					Id = message.Id,
				}, function(response)
					if mountedRef.current and response.ok then
						setSelectedId("")
					end
				end)
			end,
			color = Palette.coral,
			textColor = if claimed then Palette.cream else Palette.muted,
			outline = true,
			size = UDim2.fromScale(1, 1),
			disabled = not claimed,
				reducedMotion = softMotion,
		}))) else React.createElement("frame", {
			Size = UDim2.fromOffset(0, TapTarget),
			AutomaticSize = Enum.AutomaticSize.X,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		}, React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, Layout.controlGap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}), React.createElement("frame", {
			Name = "MailClaim",
			Size = UDim2.fromOffset(0, TapTarget),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			LayoutOrder = 1,
		}, React.createElement(Button, {
			text = if claimed then "COLLECTED" else "CLAIM",
			icon = "Gift",
			onClick = function()
				return dispatch("ClaimMail", {
					Id = message.Id,
				})
			end,
			color = if claimed then Palette.panelSoft else message.Color,
			textColor = if claimed then Palette.muted else Palette.ink,
			size = UDim2.fromOffset(0, TapTarget),
			hug = true,
			disabled = claimed,
				reducedMotion = softMotion,
			highlight = not claimed,
		})), React.createElement("frame", {
			Name = "MailArchive",
			Size = UDim2.fromOffset(0, TapTarget),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 2,
		}, React.createElement(Button, {
			text = "ARCHIVE",
			icon = "Close",
			onClick = function()
				return dispatch("DeleteMail", {
					Id = message.Id,
				}, function(response)
					if mountedRef.current and response.ok then
						setSelectedId("")
					end
				end)
			end,
			color = Palette.coral,
			textColor = if claimed then Palette.cream else Palette.muted,
			outline = true,
			size = UDim2.fromOffset(0, TapTarget),
			hug = true,
			disabled = not claimed,
				reducedMotion = softMotion,
		})))))
	end

	local detailPane = React.createElement("frame", {
		Size = if mobileRoute then UDim2.fromScale(1, 1) elseif stack then UDim2.new(1, 0, 1, -(stackListH + 8)) else UDim2.new(0.66, -7, 1, 0),
		Position = detailPanePosition,
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, _exp_5, _exp_6, _exp_7, _condition_5)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, listPane, detailPane)
end
return {
	MailboxView = MailboxView,
}
end

__defs["ChatView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local _AnimatedTitle = require(script.Parent.Parent.ReactHosts)("AnimatedTitle")
local AnimatedTitle = _AnimatedTitle.AnimatedTitle
local titleFxAccent = _AnimatedTitle.titleFxAccent
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local _Icon = require(script.Parent.Parent.ArtKit)("Icon")
local Icon = _Icon.Icon
local PlayerMark = _Icon.PlayerMark
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useFlipperSpring = _motion.useFlipperSpring
local usePulse = _motion.usePulse
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local Layout = _theme.Layout
local darken = _theme.darken
local lighten = _theme.lighten
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local Text = _ui.Text
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local FlatList = require(script.Parent.Parent.LayoutKit)("virtualizedList").FlatList
local ROW_HEIGHT = 98
local CARD_H = 90
local SYSTEM_CARD_H = 66
local STATUS_HEIGHT = 64
local BANNER_HEIGHT = 52
local INPUT_HEIGHT = 60
local GAP = Layout.stackGap
local SIDE_INSET = 12
local STATUS_RESERVE = 128
local NEAR_BOTTOM = 96
local ChatText = require(script.Parent.Parent.CoreKit)("chatText")
local EMPTY_CHAT = {
	messages = {}, unread = 0, connected = false,
	send = function(_, done) if done then done(false, "Chat is still connecting.") end end,
	clear = function() end,
}
local TAG_COLORS = { Palette.cyan, Palette.mint, Palette.violet, Palette.mango, Palette.pink, Palette.blue }
local function userColor(userId)
	return TAG_COLORS[math.abs(userId) % #TAG_COLORS + 1]
end
local function useMessageEntrance(animate, reducedMotion)
	local shouldAnimate = React.useRef(animate and not reducedMotion)
	local live, setLive = React.useState(not shouldAnimate.current)
	React.useEffect(function()
		if not shouldAnimate.current then
			setLive(true)
			return nil
		end
		setLive(false)
		local alive = true
		local job = task.defer(function()
			if alive then
				setLive(true)
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, job)
		end
	end, {})
	return useFlipperSpring(if live then 1 else 0, reducedMotion, 780, 38)
end
local function MessageRow(_param)
	local message = _param.message
	local position = _param.position
	local reducedMotion = _param.reducedMotion
	local bodySize = _param.bodySize
	local animate = _param.animate
	local rowHeight = _param.rowHeight
	local softMotion = reducedMotion
	local enter = useMessageEntrance(animate, reducedMotion)
	local accent = if message.system then Palette.mango else userColor(message.userId)
	local pulse = usePulse(not message.system, 2.4 + math.abs(message.userId % 5) * 0.14)
	local fade = enter:map(function(amount)
		return 1 - amount
	end)
	local cardY = if message.system then math.floor((rowHeight - SYSTEM_CARD_H) / 2) else 4
	local cardH = if message.system then SYSTEM_CARD_H else math.max(CARD_H, rowHeight - 8)
	if message.system then
		return React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, rowHeight),
			Position = position,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, React.createElement("frame", {
			Size = UDim2.new(1, -4, 0, cardH),
			Position = enter:map(function(amount)
				return UDim2.fromOffset(math.round((1 - amount) * 14), cardY + math.round((1 - amount) * 8))
			end),
			AnchorPoint = Vector2.new(0, 0),
			BackgroundColor3 = Palette.panelRaised,
			BackgroundTransparency = fade:map(function(amount)
				return 0.08 + amount * 0.92
			end),
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, React.createElement("uiscale", {
			Scale = enter:map(function(amount)
				return 0.97 + amount * 0.03
			end),
		}), React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 12),
		}), React.createElement("uistroke", {
			Color = accent,
			Thickness = 1,
			Transparency = fade:map(function(amount)
				return 0.42 + amount * 0.58
			end),
		}), React.createElement("frame", {
			Size = UDim2.new(0, 3, 1, -12),
			Position = UDim2.fromOffset(0, 6),
			BackgroundColor3 = accent,
			BackgroundTransparency = fade,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 2),
		})), React.createElement("frame", {
			Size = UDim2.fromOffset(38, 38),
			Position = UDim2.fromOffset(14, 14),
			BackgroundColor3 = darken(accent, 0.62),
			BackgroundTransparency = fade,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 10),
		}), React.createElement(Icon, {
			kind = "Chat",
			color = Palette.ink,
			accent = accent,
			size = 22,
			position = UDim2.fromOffset(8, 8),
			spin = false,
		})), React.createElement(Text, {
			value = "GAME MESSAGE",
			size = 12,
			color = accent,
			weight = Enum.FontWeight.Bold,
			fit = false,
			position = UDim2.fromOffset(64, 12),
			sizeConstraint = UDim2.new(1, -78, 0, 16),
			transparency = fade,
		}), React.createElement(Text, {
			value = message.text,
			size = bodySize,
			color = Palette.cream,
			weight = Enum.FontWeight.Medium,
			wrap = true,
			position = UDim2.fromOffset(64, 32),
			sizeConstraint = UDim2.new(1, -78, 0, 28),
			transparency = fade,
		})))
	end
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, rowHeight),
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("frame", {
		Size = UDim2.new(1, -4, 0, cardH),
		Position = enter:map(function(amount)
			return UDim2.fromOffset(math.round((1 - amount) * 14), cardY + math.round((1 - amount) * 10))
		end),
		BackgroundColor3 = if message.localPlayer then darken(accent, 0.88) else Palette.panel,
		BackgroundTransparency = fade:map(function(amount)
			return 0.04 + amount * 0.96
		end),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uiscale", {
		Scale = enter:map(function(amount)
			return 0.97 + amount * 0.03
		end),
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 1,
		Transparency = fade:map(function(amount)
			return (if message.localPlayer then 0.32 else 0.58) + amount * 0.42
		end),
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(42, 42),
		Position = UDim2.fromOffset(12, 17),
		BackgroundColor3 = darken(accent, 0.5),
		BackgroundTransparency = fade,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 1,
		Transparency = pulse:map(function(amount)
			return 0.2 + amount * 0.4
		end),
	}), React.createElement(PlayerMark, {
		userId = message.userId,
		color = Palette.ink,
		accent = accent,
		size = 26,
		position = UDim2.fromOffset(8, 8),
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(10, 10),
		Position = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Palette.green,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.ink,
		Thickness = 1,
	}))), React.createElement(Text, {
		value = message.displayName,
		size = 15,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(66, 8),
		sizeConstraint = UDim2.new(1, -(STATUS_RESERVE + 72), 0, 18),
		transparency = fade,
	}), if message.titleName ~= nil then React.createElement(AnimatedTitle, {
		text = message.titleName,
		fx = message.titleFx,
		size = 12,
		reducedMotion = reducedMotion,
		inline = true,
		position = UDim2.fromOffset(66, 28),
		sizeConstraint = UDim2.new(1, -(STATUS_RESERVE + 72), 0, 18),
		transparency = fade,
	}) else React.createElement(Text, {
		value = `@{message.username}`,
		size = 12,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(66, 28),
		sizeConstraint = UDim2.new(1, -80, 0, 16),
		transparency = fade,
	}), React.createElement(Badge, {
		value = if message.localPlayer then "YOU" else `WORLD {message.world}`,
		accent = if message.titleFx ~= nil then titleFxAccent(message.titleFx) else accent,
		filled = true,
		position = UDim2.new(1, -72, 0, 10),
		size = UDim2.fromOffset(62, 26),
	}), message.titleName ~= nil and React.createElement(Text, {
		value = `@{message.username}`,
		size = 11,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(66, 46),
		sizeConstraint = UDim2.new(1, -80, 0, 14),
		transparency = fade,
	}), React.createElement(Text, {
		value = message.text,
		size = bodySize + 1,
		color = Palette.cream,
		weight = Enum.FontWeight.Medium,
		wrap = true,
		position = UDim2.fromOffset(66, if message.titleName ~= nil then 62 else 48),
		sizeConstraint = UDim2.new(1, -78, 0, math.max(if message.titleName ~= nil then 26 else 34, cardH - (if message.titleName ~= nil then 70 else 56))),
		transparency = fade,
	})))
end
local function ChatView(_param)
	local chat = _param.chat or EMPTY_CHAT
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local bodySize = if chrome.mobile then 16 else 15
	local rowHeight = if chrome.mobile then 144 else ROW_HEIGHT
	local condensed = chrome.landscape or viewport.keyboardOpen or viewport.height < 700
	local showStatus = not condensed
	local showBanner = not condensed and viewport.height >= 760
	local chromeGap = if condensed then 6 else GAP
	local inputHeight = if condensed then 52 else INPUT_HEIGHT
	local draft, setDraft = React.useState("")
	local failure, setFailure = React.useState("")
	local viewHeight, setViewHeight = React.useState(0)
	local input = React.useRef()
	local stickBottom = React.useRef(true)
	local lastMessageId = React.useRef(nil)
	local sendAttempt = React.useRef(0)
	local chatClaimHostRef = React.useRef(nil)
	local headerReveal = useStagger(0, softMotion)
	local bannerReveal = useStagger(1, softMotion)
	local composerReveal = useStagger(2, softMotion)
	local statusReveal = useStagger(3, softMotion)
	React.useEffect(function()
		return function()
			sendAttempt.current += 1
		end
	end, {})
	local enteredIds = React.useRef({})
	local listFrame = React.useRef(nil)
	local count = #chat.messages
	local latestMessageId = if count > 0 then chat.messages[count].id else nil
	local stackH = math.max(0, count) * rowHeight
	local topPad = if viewHeight > 0 then math.max(0, viewHeight - stackH) else 0
	local renderedIds = {}
	do
		local index = 0
		while index < count do
			local message = chat.messages[index + 1]
			if message ~= nil then
				local _current = enteredIds.current
				local _id = message.id
				local animate = not (_current[_id] ~= nil)
				if animate then
					local _current_1 = enteredIds.current
					local _id_1 = message.id
					_current_1[_id_1] = true
				end
				renderedIds[message.id] = animate
			end
			index += 1
		end
	end
	local _size = 0
	for _ in enteredIds.current do
		_size += 1
	end
	if _size > count + 8 then
		local live = {}
		for _, message in chat.messages do
			local _id = message.id
			live[_id] = true
		end
		enteredIds.current = live
	end
	local scrollToBottom = React.useCallback(function(force)
		task.defer(function()
			local frame = listFrame.current
			if not frame then
				return nil
			end
			if force ~= true and not stickBottom.current then
				return nil
			end
			local bottom = math.max(0, frame.CanvasSize.Y.Offset - frame.AbsoluteWindowSize.Y)
			frame.CanvasPosition = Vector2.new(0, bottom)
			stickBottom.current = true
		end)
	end, { listFrame })
	React.useEffect(function()
		local frame = listFrame.current
		if not frame then
			return nil
		end
		local syncSize = function()
			return setViewHeight(math.max(0, frame.AbsoluteWindowSize.Y))
		end
		syncSize()
		local sizeConn = frame:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(syncSize)
		local scrollConn = frame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			local maxY = math.max(0, frame.CanvasSize.Y.Offset - frame.AbsoluteWindowSize.Y)
			stickBottom.current = frame.CanvasPosition.Y >= maxY - NEAR_BOTTOM
		end)
		return function()
			sizeConn:Disconnect()
			scrollConn:Disconnect()
		end
	end, { listFrame, count, topPad })
	React.useEffect(function()
		if latestMessageId ~= lastMessageId.current then
			scrollToBottom()
		end
		lastMessageId.current = latestMessageId
	end, { latestMessageId, scrollToBottom })
	React.useEffect(function()
		scrollToBottom(true)
	end, { scrollToBottom })
	local submit = function()
		local box = input.current
		local outgoing = if box ~= nil then box.Text else draft
		if (string.gsub(outgoing, "%s", "")) == "" then
			return nil
		end
		local attempt = sendAttempt.current + 1
		sendAttempt.current = attempt
		setFailure("")
		setDraft("")
		if box ~= nil then
			box.Text = ""
			task.defer(function()
				if input.current == box then
					box:CaptureFocus()
				end
			end)
		end
		stickBottom.current = true
		chat.send(outgoing, function(ok, reason)
			if attempt ~= sendAttempt.current then
				return nil
			end
			if ok then
				setFailure("")
				scrollToBottom(true)
			else
				local restore = input.current
				if restore ~= nil then
					if (string.gsub(restore.Text, "%s", "")) == "" then
						restore.Text = outgoing
						setDraft(outgoing)
					end
				else
					setDraft(function(current)
						return if (string.gsub(current, "%s", "")) == "" then outgoing else current
					end)
				end
				local _condition = reason
				if _condition == nil then
					_condition = "Message not sent."
				end
				setFailure(_condition)
			end
		end)
	end
	local canSend = chat.connected and (string.gsub(draft, "%s", "")) ~= ""
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = chatClaimHostRef.current
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
			pcall(task.cancel, selectJob)
		end
	end, { condensed, canSend })
	local statusLabel = if chat.connected then "ONLINE" else "CONNECTING"
	local statusAccent = if chat.connected then Palette.green else Palette.mango
	local placeholder = if failure ~= "" then failure else "Say something... (/help)"
	local statusElement = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 20,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.5,
	}), React.createElement("frame", {
		Size = UDim2.new(0, 3, 1, -16),
		Position = UDim2.fromOffset(0, 8),
		BackgroundColor3 = Palette.cyan,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 2),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(42, 42),
		Position = UDim2.fromOffset(14, 11),
		BackgroundColor3 = darken(Palette.cyan, 0.72),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 11),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(Palette.cyan, 0.15), darken(Palette.cyan, 0.45)),
		Rotation = 120,
	}), React.createElement(Icon, {
		kind = "Chat",
		color = Palette.ink,
		accent = Palette.cyan,
		size = 26,
		position = UDim2.fromOffset(8, 8),
		spin = false,
		reducedMotion = softMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(1, -(STATUS_RESERVE + 68), 0, 48),
		Position = UDim2.fromOffset(68, 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(Text, {
		value = "Chat",
		size = 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 24),
		transparency = headerReveal:map(function(amount)
			return 1 - amount
		end),
	}), React.createElement(Text, {
		value = `{count} log{if count == 1 then "" else "s"}  ·  Roblox-filtered`,
		size = 13,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, 28),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
		transparency = (if showBanner then bannerReveal else statusReveal):map(function(amount)
			return 1 - amount
		end),
	})), React.createElement(Badge, {
		value = statusLabel,
		accent = statusAccent,
		filled = true,
		position = UDim2.new(1, -(STATUS_RESERVE - 4), 0.5, -13),
		size = UDim2.fromOffset(STATUS_RESERVE - 16, 26),
	}))
	local composerSoft = reducedMotion or composerReveal == nil
	local _chatSoftKeep = if composerSoft then bannerReveal else statusReveal
	local messagesElement = React.createElement(FlatList, {
		data = chat.messages,
		itemHeight = rowHeight,
		headerHeight = topPad,
		overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
		canvasTail = 0,
		Size = UDim2.fromScale(1, 1),
		scrollBarColor = Palette.cyan,
		scrollBarThickness = 4,
		scrollBarTransparency = 0.12,
		ZIndex = 10,
		frameRef = listFrame,
		keyExtractor = function(message)
			return message.id
		end,
		renderItem = function(_param_1)
			local message = _param_1.item
			local animate = renderedIds[message.id] == true
			return React.createElement(MessageRow, {
				message = message,
				reducedMotion = softMotion,
				bodySize = bodySize,
				animate = animate,
				rowHeight = rowHeight,
			})
		end,
	})
	local bannerElement = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 20,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, Layout.cardRadius),
	}), React.createElement("uistroke", {
		Color = Palette.mango,
		Thickness = 1,
		Transparency = 0.32,
	}), React.createElement("frame", {
		Size = UDim2.new(0, 3, 1, -12),
		Position = UDim2.fromOffset(0, 6),
		BackgroundColor3 = Palette.mango,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 2),
	})), React.createElement(Icon, {
		kind = "Forge",
		color = Palette.ink,
		accent = Palette.mango,
		size = 24,
		position = UDim2.fromOffset(14, 14),
		spin = false,
				reducedMotion = softMotion,
	}), React.createElement(Text, {
		value = "KEEP IT CLEAN",
		size = 12,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(48, 8),
		sizeConstraint = UDim2.new(1, -60, 0, 16),
	}), React.createElement(Text, {
		value = "Roblox filters messages. Type /help for shortcuts.",
		size = 13,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(48, 28),
		sizeConstraint = UDim2.new(1, -60, 0, 16),
	}))
	local inputElement = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 20,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		Color = if failure ~= "" then Palette.coral else Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.45,
	}), React.createElement("textbox", {
		ref = input,
		Size = UDim2.new(1, -148, 1, -14),
		Position = UDim2.fromOffset(14, 7),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Text = draft,
		PlaceholderText = placeholder,
		PlaceholderColor3 = if failure ~= "" then Palette.coral else Palette.muted,
		TextColor3 = Palette.cream,
		TextSize = 16,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		TextScaled = false,
		MultiLine = false,
		TextEditable = true,
		MaxVisibleGraphemes = 160,
		Change = {
			Text = function(box)
				return setDraft(ChatText.limit(box.Text, 160))
			end,
		},
		Event = {
			Focused = function()
				return Audio:play("inputFocus")
			end,
			FocusLost = function(_box, enterPressed)
				if enterPressed then
					submit()
				end
			end,
		},
	}), React.createElement("frame", {
		Name = "ChatClaimActions",
		Size = UDim2.fromOffset(0, 48),
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ref = chatClaimHostRef,
	}, React.createElement(Button, {
		text = "SEND",
		icon = "Send",
		onClick = submit,
		color = Palette.cyan,
		textColor = Palette.ink,
		size = UDim2.fromOffset(0, 48),
		hug = true,
		disabled = not canSend,
		reducedMotion = reducedMotion,
		highlight = canSend,
	})))
	local sections = {}
	if showStatus then
		table.insert(sections, {
			id = "status",
			height = STATUS_HEIGHT,
			element = statusElement,
		})
	end
	table.insert(sections, {
		id = "messages",
		fill = true,
		minHeight = 120,
		element = messagesElement,
	})
	if showBanner then
		table.insert(sections, {
			id = "banner",
			height = BANNER_HEIGHT,
			element = bannerElement,
		})
	end
	table.insert(sections, {
		id = "input",
		height = inputHeight,
		element = inputElement,
	})
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, Layout.cardRadius),
	}), React.createElement("uistroke", {
		Color = Palette.cyan,
		Thickness = 1,
		Transparency = 0.55,
	}), React.createElement(PageScaffold, {
		gap = chromeGap,
		inset = SIDE_INSET,
		tailPad = chromeGap,
		scrollBarColor = Palette.cyan,
		scrollBarThickness = 0,
		sections = sections,
	}))
end
return {
	ChatView = ChatView,
}
end

local __members = {}
for name in __defs do
	table.insert(__members, name)
end
table.sort(__members)
table.freeze(__members)
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		if name == "__members" then
			return __members
		end
		return __load(name)
	end,
})

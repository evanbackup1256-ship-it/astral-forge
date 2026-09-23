local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Rodux = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].rodux)
local EMPTY_BOOT_STATUS = {
	marks = {
		bridge = false,
		remotes = false,
		state = false,
		audio = false,
		assets = false,
		fonts = false,
		modules = false,
		shell = false,
		mail = false,
		research = false,
		forge = false,
		trade = false,
		boosts = false,
		settings = false,
		mobile = false,
	},
	ready = false,
	progress = 0,
	reducedMotion = false,
}
local INITIAL_STATE = {
	navigation = {
		page = "Overview",
	},
	boot = {
		status = EMPTY_BOOT_STATUS,
		visible = true,
	},
	domain = {
		busy = false,
	},
}
local function optimisticSession(session, action, payload, gameVersion)
	if session == nil then
		return nil
	end
	if action == "SetSetting" then
		local _object = table.clone(session.Settings)
		setmetatable(_object, nil)
		local settings = _object
		local batch = payload.Values
		if type(batch) == "table" then
			for key, value in pairs(batch) do
				if type(value) == "number" then
					settings[key] = math.clamp(value, 0, 1)
				end
			end
			local _object_1 = table.clone(session)
			setmetatable(_object_1, nil)
			_object_1.Settings = settings
			return _object_1
		end
		local _key = payload.Key
		local _condition = type(_key) == "string"
		if _condition then
			local _value = payload.Value
			_condition = type(_value) == "number"
		end
		if _condition then
			settings[payload.Key] = payload.Value
			local _object_1 = table.clone(session)
			setmetatable(_object_1, nil)
			_object_1.Settings = settings
			return _object_1
		end
	end
	local _condition = action == "SetMobileLayout"
	if _condition then
		local _values = payload.Values
		_condition = type(_values) == "table"
	end
	if _condition then
		local _object = table.clone(session)
		setmetatable(_object, nil)
		local _left = "Settings"
		local _object_1 = table.clone(session.Settings)
		setmetatable(_object_1, nil)
		for _k, _v in (payload.Values) do
			_object_1[_k] = _v
		end
		_object[_left] = _object_1
		return _object
	end
	local _condition_1 = action == "SetTutorialStep"
	if _condition_1 then
		local _step = payload.Step
		_condition_1 = type(_step) == "number"
	end
	if _condition_1 then
		local _object = table.clone(session)
		setmetatable(_object, nil)
		local _left = "Flags"
		local _object_1 = table.clone(session.Flags)
		setmetatable(_object_1, nil)
		_object_1.TutorialStep = math.max(1, math.floor(payload.Step))
		_object[_left] = _object_1
		return _object
	end
	if action == "ReplayTutorial" then
		local _object = table.clone(session)
		setmetatable(_object, nil)
		local _left = "Flags"
		local _object_1 = table.clone(session.Flags)
		setmetatable(_object_1, nil)
		_object_1.TutorialDone = false
		_object_1.TutorialStep = 1
		_object[_left] = _object_1
		return _object
	end
	if action == "CompleteTutorial" then
		local _object = table.clone(session)
		setmetatable(_object, nil)
		local _left = "Flags"
		local _object_1 = table.clone(session.Flags)
		setmetatable(_object_1, nil)
		_object_1.TutorialDone = true
		_object[_left] = _object_1
		return _object
	end
	if action == "DismissRelease" then
		local _object = table.clone(session)
		setmetatable(_object, nil)
		local _left = "Flags"
		local _object_1 = table.clone(session.Flags)
		setmetatable(_object_1, nil)
		local _left_1 = "LastSeenVersion"
		local _condition_2 = gameVersion
		if _condition_2 == nil then
			_condition_2 = session.Game.Version
		end
		_object_1[_left_1] = _condition_2
		_object[_left] = _object_1
		return _object
	end
	if action == "OpenRelease" then
		local _object = table.clone(session)
		setmetatable(_object, nil)
		local _left = "Flags"
		local _object_1 = table.clone(session.Flags)
		setmetatable(_object_1, nil)
		_object_1.LastSeenVersion = ""
		_object[_left] = _object_1
		return _object
	end
	local _condition_2 = action == "ReadStoryChapter"
	if _condition_2 then
		local _id = payload.Id
		_condition_2 = type(_id) == "string"
		if _condition_2 then
			_condition_2 = session.Story ~= nil
		end
	end
	if _condition_2 then
		local _object = table.clone(session)
		setmetatable(_object, nil)
		local _left = "Story"
		local _exp = session.Story
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#_exp)
		local _callback = function(chapter)
			local _result
			if chapter.Id == payload.Id then
				local _object_1 = table.clone(chapter)
				setmetatable(_object_1, nil)
				_object_1.Read = true
				_result = _object_1
			else
				_result = chapter
			end
			return _result
		end
		for _k, _v in _exp do
			_newValue[_k] = _callback(_v, _k - 1, _exp)
		end
		-- ▲ ReadonlyArray.map ▲
		_object[_left] = _newValue
		return _object
	end
	local _condition_3 = action == "ReadMail"
	if _condition_3 then
		local _id = payload.Id
		_condition_3 = type(_id) == "string"
		if _condition_3 then
			_condition_3 = session.Mailbox ~= nil
		end
	end
	if _condition_3 then
		local newlyRead = false
		local _exp = session.Mailbox.Messages
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#_exp)
		local _callback = function(message)
			if message.Id ~= payload.Id or message.Read then
				return message
			end
			newlyRead = true
			local _object = table.clone(message)
			setmetatable(_object, nil)
			_object.Read = true
			return _object
		end
		for _k, _v in _exp do
			_newValue[_k] = _callback(_v, _k - 1, _exp)
		end
		-- ▲ ReadonlyArray.map ▲
		local messages = _newValue
		local _object = table.clone(session)
		setmetatable(_object, nil)
		_object.Mailbox = {
			Messages = messages,
			Unread = math.max(0, session.Mailbox.Unread - (if newlyRead then 1 else 0)),
		}
		return _object
	end
	local _condition_4 = action == "SetAutoForge" and session.AutoForge ~= nil
	if _condition_4 then
		local _enabled = payload.Enabled
		_condition_4 = type(_enabled) == "boolean"
		if _condition_4 then
			local _machineId = payload.MachineId
			_condition_4 = type(_machineId) == "string"
			if _condition_4 then
				local _reserve = payload.Reserve
				_condition_4 = type(_reserve) == "number"
			end
		end
	end
	if _condition_4 then
		local _object = table.clone(session)
		setmetatable(_object, nil)
		local _left = "AutoForge"
		local _object_1 = table.clone(session.AutoForge)
		setmetatable(_object_1, nil)
		_object_1.Enabled = payload.Enabled
		_object_1.MachineId = payload.MachineId
		_object_1.Reserve = payload.Reserve
		_object[_left] = _object_1
		return _object
	end
	local _condition_5 = action == "RouteLabPower" and session.Lab ~= nil
	if _condition_5 then
		local _channel = payload.Channel
		_condition_5 = type(_channel) == "string"
		if _condition_5 then
			local _delta = payload.Delta
			_condition_5 = type(_delta) == "number"
		end
	end
	if _condition_5 then
		local _object = table.clone(session.Lab.Routing)
		setmetatable(_object, nil)
		local routing = _object
		local _condition_6 = routing[payload.Channel]
		if _condition_6 == nil then
			_condition_6 = 0
		end
		local current = _condition_6
		local wanted = math.floor(payload.Delta)
		local actual = if wanted > 0 then math.min(wanted, session.Lab.AvailableCells) else -math.min(-wanted, current)
		routing[payload.Channel] = math.max(0, current + actual)
		local _object_1 = table.clone(session)
		setmetatable(_object_1, nil)
		local _left = "Lab"
		local _object_2 = table.clone(session.Lab)
		setmetatable(_object_2, nil)
		_object_2.Routing = routing
		_object_2.AvailableCells = math.clamp(session.Lab.AvailableCells - actual, 0, session.Lab.TotalCells)
		_object_1[_left] = _object_2
		return _object_1
	end
	local _condition_6 = action == "SetAnomalyChannel" and session.Anomaly ~= nil
	if _condition_6 then
		local _id = payload.Id
		_condition_6 = type(_id) == "string"
	end
	if _condition_6 then
		local _object = table.clone(session)
		setmetatable(_object, nil)
		local _left = "Anomaly"
		local _object_1 = table.clone(session.Anomaly)
		setmetatable(_object_1, nil)
		_object_1.Channel = payload.Id
		_object[_left] = _object_1
		return _object
	end
	local _condition_7 = action == "ClaimAnomalyDirective" and session.Anomaly ~= nil
	if _condition_7 then
		local _id = payload.Id
		_condition_7 = type(_id) == "string"
	end
	if _condition_7 then
		local changed = false
		local _exp = session.Anomaly.Directives
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#_exp)
		local _callback = function(directive)
			if directive.Id ~= payload.Id or directive.Claimed or directive.Progress < directive.Target then
				return directive
			end
			changed = true
			local _object = table.clone(directive)
			setmetatable(_object, nil)
			_object.Claimed = true
			return _object
		end
		for _k, _v in _exp do
			_newValue[_k] = _callback(_v, _k - 1, _exp)
		end
		-- ▲ ReadonlyArray.map ▲
		local directives = _newValue
		local _result
		if changed then
			local _object = table.clone(session)
			setmetatable(_object, nil)
			local _left = "Anomaly"
			local _object_1 = table.clone(session.Anomaly)
			setmetatable(_object_1, nil)
			_object_1.Directives = directives
			_object[_left] = _object_1
			_result = _object
		else
			_result = session
		end
		return _result
	end
	local _condition_8 = action == "ClaimAnomalyMilestone" and session.Anomaly ~= nil
	if _condition_8 then
		local _tier = payload.Tier
		_condition_8 = type(_tier) == "number"
	end
	if _condition_8 then
		local anomaly = session.Anomaly
		local changed = false
		local _exp = anomaly.Milestones
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#_exp)
		local _callback = function(milestone)
			if milestone.Tier ~= payload.Tier or milestone.Claimed or anomaly.Stabilizations < milestone.Required then
				return milestone
			end
			changed = true
			local _object = table.clone(milestone)
			setmetatable(_object, nil)
			_object.Claimed = true
			return _object
		end
		for _k, _v in _exp do
			_newValue[_k] = _callback(_v, _k - 1, _exp)
		end
		-- ▲ ReadonlyArray.map ▲
		local milestones = _newValue
		local _result
		if changed then
			local _object = table.clone(session)
			setmetatable(_object, nil)
			local _left = "Anomaly"
			local _object_1 = table.clone(anomaly)
			setmetatable(_object_1, nil)
			_object_1.Milestones = milestones
			_object[_left] = _object_1
			_result = _object
		else
			_result = session
		end
		return _result
	end
	if action == "CollectVault" then
		local _object = table.clone(session)
		setmetatable(_object, nil)
		_object.Vault = 0
		return _object
	end
	local _condition_9 = action == "SelectZone"
	if _condition_9 then
		local _id = payload.Id
		_condition_9 = type(_id) == "number"
	end
	if _condition_9 then
		local _object = table.clone(session)
		setmetatable(_object, nil)
		_object.CurrentZone = math.max(1, math.floor(payload.Id))
		return _object
	end
	local _condition_10 = action == "EquipTitle"
	if _condition_10 then
		local _id = payload.Id
		_condition_10 = type(_id) == "string"
		if _condition_10 then
			_condition_10 = session.Command ~= nil
		end
	end
	if _condition_10 then
		local _exp = session.Command.Titles
		-- ▼ ReadonlyArray.find ▼
		local _callback = function(title)
			return title.Id == payload.Id
		end
		local _result
		for _i, _v in _exp do
			if _callback(_v, _i - 1, _exp) == true then
				_result = _v
				break
			end
		end
		-- ▲ ReadonlyArray.find ▲
		local selected = _result
		if selected == nil or not selected.Unlocked or selected.Equipped then
			return session
		end
		local _object = table.clone(session)
		setmetatable(_object, nil)
		local _left = "Command"
		local _object_1 = table.clone(session.Command)
		setmetatable(_object_1, nil)
		local _left_1 = "Titles"
		local _exp_1 = session.Command.Titles
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#_exp_1)
		local _callback_1 = function(title)
			local _object_2 = table.clone(title)
			setmetatable(_object_2, nil)
			_object_2.Equipped = title.Id == payload.Id
			return _object_2
		end
		for _k, _v in _exp_1 do
			_newValue[_k] = _callback_1(_v, _k - 1, _exp_1)
		end
		-- ▲ ReadonlyArray.map ▲
		_object_1[_left_1] = _newValue
		_object[_left] = _object_1
		return _object
	end
	return session
end
local function clientReducer(state, action)
	if state == nil then
		state = INITIAL_STATE
	end
	local _exp = action.type
	repeat
		if _exp == "session/snapshot" then
			if state.session ~= nil then
				if action.snapshot.Revision < state.session.Revision then
					return state
				end
				if action.snapshot.Revision == state.session.Revision and action.snapshot.SnapshotId < state.session.SnapshotId then
					return state
				end
			end
			local _object = table.clone(state)
			setmetatable(_object, nil)
			_object.session = action.snapshot
			_object.visit = action.snapshot.Visit
			return _object
		end
		if _exp == "session/patch" then
			if state.session == nil then
				return state
			end
			local _object = table.clone(state)
			setmetatable(_object, nil)
			local _left = "session"
			local _object_1 = table.clone(state.session)
			setmetatable(_object_1, nil)
			for _k, _v in action.patch do
				_object_1[_k] = _v
			end
			_object[_left] = _object_1
			return _object
		end
		if _exp == "session/optimistic" then
			local session = optimisticSession(state.session, action.action, action.payload, action.gameVersion)
			local _result
			if session == state.session then
				_result = state
			else
				local _object = table.clone(state)
				setmetatable(_object, nil)
				_object.session = session
				_result = _object
			end
			return _result
		end
		if _exp == "session/visit" then
			local _result
			if state.visit == action.visit then
				_result = state
			else
				local _object = table.clone(state)
				setmetatable(_object, nil)
				_object.visit = action.visit
				_result = _object
			end
			return _result
		end
		if _exp == "navigation/open" then
			local _result
			if state.navigation.page == action.page then
				_result = state
			else
				local _object = table.clone(state)
				setmetatable(_object, nil)
				_object.navigation = {
					page = action.page,
				}
				_result = _object
			end
			return _result
		end
		if _exp == "boot/status" then
			local _result
			if state.boot.status == action.status then
				_result = state
			else
				local _object = table.clone(state)
				setmetatable(_object, nil)
				local _left = "boot"
				local _object_1 = table.clone(state.boot)
				setmetatable(_object_1, nil)
				_object_1.status = action.status
				_object[_left] = _object_1
				_result = _object
			end
			return _result
		end
		if _exp == "boot/visible" then
			local _result
			if state.boot.visible == action.visible then
				_result = state
			else
				local _object = table.clone(state)
				setmetatable(_object, nil)
				local _left = "boot"
				local _object_1 = table.clone(state.boot)
				setmetatable(_object_1, nil)
				_object_1.visible = action.visible
				_object[_left] = _object_1
				_result = _object
			end
			return _result
		end
		if _exp == "domain/overlay" then
			local _result
			if state.domain.overlay == action.overlay then
				_result = state
			else
				local _object = table.clone(state)
				setmetatable(_object, nil)
				local _left = "domain"
				local _object_1 = table.clone(state.domain)
				setmetatable(_object_1, nil)
				_object_1.overlay = action.overlay
				_object[_left] = _object_1
				_result = _object
			end
			return _result
		end
		if _exp == "domain/busy" then
			local _result
			if state.domain.busy == action.busy then
				_result = state
			else
				local _object = table.clone(state)
				setmetatable(_object, nil)
				local _left = "domain"
				local _object_1 = table.clone(state.domain)
				setmetatable(_object_1, nil)
				_object_1.busy = action.busy
				_object[_left] = _object_1
				_result = _object
			end
			return _result
		end
		if _exp == "runtime/reset" then
			return INITIAL_STATE
		end
		return state
	until true
end
local activeClientStore
local ClientActions = {
	setSnapshot = function(snapshot)
		return {
			type = "session/snapshot",
			snapshot = snapshot,
		}
	end,
	patchSession = function(patch)
		return {
			type = "session/patch",
			patch = patch,
		}
	end,
	applyOptimistic = function(action, payload, gameVersion)
		return {
			type = "session/optimistic",
			action = action,
			payload = payload,
			gameVersion = gameVersion,
		}
	end,
	setVisit = function(visit)
		return {
			type = "session/visit",
			visit = visit,
		}
	end,
	navigate = function(page)
		return {
			type = "navigation/open",
			page = page,
		}
	end,
	setBootStatus = function(status)
		return {
			type = "boot/status",
			status = status,
		}
	end,
	setBootVisible = function(visible)
		return {
			type = "boot/visible",
			visible = visible,
		}
	end,
	setDomainOverlay = function(overlay)
		return {
			type = "domain/overlay",
			overlay = overlay,
		}
	end,
	setDomainBusy = function(busy)
		return {
			type = "domain/busy",
			busy = busy,
		}
	end,
	reset = function()
		return {
			type = "runtime/reset",
		}
	end,
}
local function createClientStore()
	local _result = activeClientStore
	if _result ~= nil then
		_result:destruct()
	end
	activeClientStore = Rodux.Store.new(clientReducer, INITIAL_STATE)
	return activeClientStore
end
local function getActiveClientStore()
	return activeClientStore
end
local function destroyClientStore(store)
	if activeClientStore == store then
		activeClientStore = nil
	end
	store:destruct()
end
local ClientStoreContext = React.createContext(nil)
local function ClientStoreProvider(_param)
	local store = _param.store
	local children = _param.children
	return React.createElement(ClientStoreContext.Provider, {
		value = store,
	}, children)
end
local function useClientStore()
	local store = React.useContext(ClientStoreContext)
	if store == nil then
		error("ClientStoreProvider is missing", 2)
	end
	return store
end
local function useClientDispatch()
	local store = useClientStore()
	return React.useCallback(function(action)
		return store:dispatch(action)
	end, { store })
end
local function useClientSelector(selector, equal)
	if equal == nil then
		equal = function(left, right)
			return left == right
		end
	end
	local store = useClientStore()
	local selectorRef = React.useRef(selector)
	local equalRef = React.useRef(equal)
	selectorRef.current = selector
	equalRef.current = equal
	local selected, setSelected = React.useState(function()
		return selector(store:getState())
	end)
	local selectedRef = React.useRef(selected)
	selectedRef.current = selected
	React.useEffect(function()
		local sync = function(nextState)
			local selectedNext = selectorRef.current(nextState)
			if equalRef.current(selectedRef.current, selectedNext) then
				return nil
			end
			selectedRef.current = selectedNext
			setSelected(selectedNext)
		end
		sync(store:getState())
		local connection = store.changed:connect(sync)
		return function()
			return connection:disconnect()
		end
	end, { store })
	return selected
end
return {
	createClientStore = createClientStore,
	getActiveClientStore = getActiveClientStore,
	destroyClientStore = destroyClientStore,
	ClientStoreProvider = ClientStoreProvider,
	useClientStore = useClientStore,
	useClientDispatch = useClientDispatch,
	useClientSelector = useClientSelector,
	ClientActions = ClientActions,
}

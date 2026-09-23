local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.Parent.audio).Audio
local ForgeAnvil2D = require(script.Parent.Parent.ForgeAnvil2D).ForgeAnvil2D
local _format = require(script.Parent.Parent.format)
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local gteFlux = _format.gteFlux
local scaledCost = _format.scaledCost
local Icon = require(script.Parent.Parent.Icon).Icon
local InteractionFeedback = require(script.Parent.Parent.interaction).InteractionFeedback
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local _motion = require(script.Parent.Parent.motion)
local useClock = _motion.useClock
local useFlipperSpring = _motion.useFlipperSpring
local usePulse = _motion.usePulse
local useViewport = _motion.useViewport
local _ui = require(script.Parent.Parent.ui)
local Button = _ui.Button
local meterFill = _ui.meterFill
local Text = _ui.Text
local _theme = require(script.Parent.Parent.theme)
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local TapTarget = _theme.TapTarget
local _floorFx = require(script.Parent.floorFx)
local ClickPops = _floorFx.ClickPops
local ComboBanner = _floorFx.ComboBanner
local CoreAura = _floorFx.CoreAura
local FluxRiver = _floorFx.FluxRiver
local HeatHaze = _floorFx.HeatHaze
local ShockRing = _floorFx.ShockRing
local SparkBurst = _floorFx.SparkBurst
local WorldHaze = _floorFx.WorldHaze
local BEAT_SECONDS = 1.15
local PERFECT_WINDOW = 0.11
local GOOD_WINDOW = 0.2
local SCRAP_LIFE = 4.2
local RIFT_LIFE = 7.5
local STATION_SLOTS = { {
	x = 0.14,
	y = 0.38,
}, {
	x = 0.86,
	y = 0.38,
}, {
	x = 0.08,
	y = 0.62,
}, {
	x = 0.92,
	y = 0.62,
}, {
	x = 0.22,
	y = 0.78,
}, {
	x = 0.78,
	y = 0.78,
}, {
	x = 0.34,
	y = 0.28,
}, {
	x = 0.66,
	y = 0.28,
} }
local function machineIcon(machine)
	return (machine.Icon) or "Forge"
end
local function ownedStations(state, config)
	local out = {}
	local slot = 0
	for _, machine in config.Machines do
		local _condition = state.Machines[machine.Id]
		if _condition == nil then
			_condition = 0
		end
		local level = _condition
		if level <= 0 then
			continue
		end
		local place = STATION_SLOTS[slot + 1] or STATION_SLOTS[#STATION_SLOTS]
		local _arg0 = {
			machine = machine,
			level = level,
			x = place.x,
			y = place.y,
		}
		table.insert(out, _arg0)
		slot += 1
		if slot >= #STATION_SLOTS then
			break
		end
	end
	if #out == 0 and config.Machines[1] ~= nil then
		local _arg0 = {
			machine = config.Machines[1],
			level = 0,
			x = STATION_SLOTS[1].x,
			y = STATION_SLOTS[1].y,
		}
		table.insert(out, _arg0)
	end
	return out
end
local function nextBuyable(state, config)
	for _, machine in config.Machines do
		local _condition = state.Machines[machine.Id]
		if _condition == nil then
			_condition = 0
		end
		local level = _condition
		if level >= machine.MaxLevel then
			continue
		end
		local _exp = state.Zone
		local _condition_1 = machine.RequiredZone
		if _condition_1 == nil then
			_condition_1 = 1
		end
		if _exp < _condition_1 then
			continue
		end
		local _exp_1 = state.Rebirths
		local _condition_2 = machine.RequiredRebirths
		if _condition_2 == nil then
			_condition_2 = 0
		end
		if _exp_1 < _condition_2 then
			continue
		end
		local _condition_3 = machine.PreviousId ~= nil
		if _condition_3 then
			local _condition_4 = state.Machines[machine.PreviousId]
			if _condition_4 == nil then
				_condition_4 = 0
			end
			local _condition_5 = machine.PreviousLevel
			if _condition_5 == nil then
				_condition_5 = 1
			end
			_condition_3 = _condition_4 < _condition_5
		end
		if _condition_3 then
			continue
		end
		return machine
	end
	return nil
end
local StationPad
local function ForgeFloorView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local effectsPaused = _param.effectsPaused
	local openWorkshop = _param.openWorkshop
	local openDomain = _param.openDomain
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	local quiet = reducedMotion or effectsPaused
	local stack = chrome.contentStack
	local zone = if config.ResolveZone ~= nil then config.ResolveZone(state.CurrentZone) else config.Zones[state.CurrentZone]
	local _result = zone
	if _result ~= nil then
		_result = _result.Color
	end
	local _condition = _result
	if _condition == nil then
		_condition = Palette.cyan
	end
	local worldColor = _condition
	local stations = React.useMemo(function()
		return ownedStations(state, config)
	end, { config, state.Machines, state.CurrentZone })
	local nextMachine = React.useMemo(function()
		return nextBuyable(state, config)
	end, { config, state.Machines, state.Zone, state.Rebirths })
	local vaultFill = meterFill(asFlux(state.Vault), asFlux(state.Capacity))
	local canBank = asFlux(state.Vault) >= 0.01
	local vaultFull = vaultFill >= 0.99
	local canRebirth = gteFlux(state.PrestigeReward, 1)
	local anomaly = state.Anomaly
	local _result_1 = anomaly
	if _result_1 ~= nil then
		_result_1 = _result_1.Ready
	end
	local riftReady = _result_1 == true
	local combo, setCombo = React.useState(0)
	local heat, setHeat = React.useState(0)
	local best, setBest = React.useState(0)
	local strikeReadyAt, setStrikeReadyAt = React.useState(0)
	local strikeLeft, setStrikeLeft = React.useState(0)
	local shock, setShock = React.useState(0)
	local perfectPulse, setPerfectPulse = React.useState(false)
	local lastGrade, setLastGrade = React.useState("GOOD")
	local sparks, setSparks = React.useState({})
	local pops, setPops = React.useState({})
	local orbs, setOrbs = React.useState({})
	local rifts, setRifts = React.useState({})
	local caught, setCaught = React.useState(0)
	local sealed, setSealed = React.useState(0)
	local sparkId = React.useRef(0)
	local popId = React.useRef(0)
	local orbId = React.useRef(0)
	local riftId = React.useRef(0)
	local beatPhase = React.useRef(0)
	local finaleTimeline, setFinaleTimeline = React.useBinding(0)
	local fade = React.useBinding(0)
	local pressed, setPressed = React.useState(false)
	local beat = useClock(not quiet, 1 / BEAT_SECONDS)
	local floorPulse = usePulse(not quiet, 1.25)
	local heatSpring = useFlipperSpring(heat, quiet, 280, 26)
	local vaultSpring = useFlipperSpring(vaultFill, quiet, 240, 24)
	local squash = useFlipperSpring(if pressed then 0.86 else 1, quiet, 720, 28)
	React.useEffect(function()
		if strikeReadyAt <= 0 then
			setStrikeLeft(0)
			return nil
		end
		local alive = true
		local worker = task.spawn(function()
			while alive do
				local left = math.max(0, strikeReadyAt - os.clock())
				setStrikeLeft(left)
				if left <= 0 then
					break
				end
				task.wait(0.04)
			end
		end)
		return function()
			alive = false
			pcall(function()
				return task.cancel(worker)
			end)
		end
	end, { strikeReadyAt })
	React.useEffect(function()
		if quiet then
			return nil
		end
		local alive = true
		local worker = task.spawn(function()
			while alive do
				task.wait(0.18)
				setHeat(function(current)
					return math.max(0, current - 0.028)
				end)
			end
		end)
		return function()
			alive = false
			pcall(function()
				return task.cancel(worker)
			end)
		end
	end, { quiet })
	React.useEffect(function()
		if quiet or #stations == 0 then
			return nil
		end
		local alive = true
		local worker = task.spawn(function()
			while alive do
				task.wait(1.15 + math.random() * 0.55)
				if not alive then
					break
				end
				local station = stations[math.floor(math.random() * #stations) + 1]
				if station == nil then
					continue
				end
				orbId.current += 1
				local id = orbId.current
				setOrbs(function(current)
					local _array = {}
					local _length = #_array
					local _currentLength = #current
					table.move(current, 1, _currentLength, _length + 1, _array)
					_length += _currentLength
					_array[_length + 1] = {
						id = id,
						x = station.x + (math.random() - 0.5) * 0.08,
						y = station.y + (math.random() - 0.5) * 0.06,
						vx = (math.random() - 0.5) * 0.04,
						vy = -0.018 - math.random() * 0.02,
						born = os.clock(),
						life = SCRAP_LIFE,
						color = station.machine.Color,
						worth = 1,
					}
					local updated = _array
					while #updated > 10 do
						table.remove(updated, 1)
					end
					return updated
				end)
			end
		end)
		return function()
			alive = false
			pcall(function()
				return task.cancel(worker)
			end)
		end
	end, { quiet, stations })
	React.useEffect(function()
		if quiet then
			return nil
		end
		local alive = true
		local worker = task.spawn(function()
			while alive do
				task.wait(6.5 + math.random() * 4)
				if not alive then
					break
				end
				riftId.current += 1
				local id = riftId.current
				setRifts(function(current)
					local _array = {}
					local _length = #_array
					local _currentLength = #current
					table.move(current, 1, _currentLength, _length + 1, _array)
					_length += _currentLength
					_array[_length + 1] = {
						id = id,
						x = 0.22 + math.random() * 0.56,
						y = 0.32 + math.random() * 0.36,
						born = os.clock(),
						life = RIFT_LIFE,
						charged = riftReady,
					}
					local updated = _array
					while #updated > 3 do
						table.remove(updated, 1)
					end
					return updated
				end)
			end
		end)
		return function()
			alive = false
			pcall(function()
				return task.cancel(worker)
			end)
		end
	end, { quiet, riftReady })
	React.useEffect(function()
		local alive = true
		local worker = task.spawn(function()
			while alive do
				task.wait(0.12)
				local now = os.clock()
				setOrbs(function(current)
					-- ▼ ReadonlyArray.filter ▼
					local _newValue = {}
					local _callback = function(orb)
						return now - orb.born < orb.life
					end
					local _length = 0
					for _k, _v in current do
						if _callback(_v, _k - 1, current) == true then
							_length += 1
							_newValue[_length] = _v
						end
					end
					-- ▲ ReadonlyArray.filter ▲
					-- ▼ ReadonlyArray.map ▼
					local _newValue_1 = table.create(#_newValue)
					local _callback_1 = function(orb)
						local _object = table.clone(orb)
						setmetatable(_object, nil)
						_object.x = math.clamp(orb.x + orb.vx, 0.06, 0.94)
						_object.y = math.clamp(orb.y + orb.vy, 0.12, 0.88)
						_object.vy = orb.vy + 0.0016
						return _object
					end
					for _k, _v in _newValue do
						_newValue_1[_k] = _callback_1(_v, _k - 1, _newValue)
					end
					-- ▲ ReadonlyArray.map ▲
					return _newValue_1
				end)
				setRifts(function(current)
					-- ▼ ReadonlyArray.filter ▼
					local _newValue = {}
					local _callback = function(rift)
						return now - rift.born < rift.life
					end
					local _length = 0
					for _k, _v in current do
						if _callback(_v, _k - 1, current) == true then
							_length += 1
							_newValue[_length] = _v
						end
					end
					-- ▲ ReadonlyArray.filter ▲
					return _newValue
				end)
			end
		end)
		return function()
			alive = false
			pcall(function()
				return task.cancel(worker)
			end)
		end
	end, {})
	local burst = function(kind, color, x, y, count)
		if x == nil then
			x = 0.5
		end
		if y == nil then
			y = 0.54
		end
		if count == nil then
			count = 10
		end
		local added = {}
		do
			local index = 0
			local _shouldIncrement = false
			while true do
				if _shouldIncrement then
					index += 1
				else
					_shouldIncrement = true
				end
				if not (index < count) then
					break
				end
				sparkId.current += 1
				local _arg0 = {
					id = sparkId.current,
					x = x + (math.random() - 0.5) * 0.12,
					y = y + (math.random() - 0.5) * 0.07,
					color = if index % 3 == 0 then Palette.cream elseif index % 2 == 0 then color else Palette.brass,
					kind = kind,
				}
				table.insert(added, _arg0)
			end
		end
		setSparks(function(current)
			local _array = {}
			local _length = #_array
			local _currentLength = #current
			table.move(current, 1, _currentLength, _length + 1, _array)
			_length += _currentLength
			table.move(added, 1, #added, _length + 1, _array)
			local updated = _array
			while #updated > 24 do
				table.remove(updated, 1)
			end
			return updated
		end)
		task.delay(0.78, function()
			local _result_2 = added[1]
			if _result_2 ~= nil then
				_result_2 = _result_2.id
			end
			local _condition_1 = _result_2
			if _condition_1 == nil then
				_condition_1 = 0
			end
			local cutoff = _condition_1
			setSparks(function(current)
				-- ▼ ReadonlyArray.filter ▼
				local _newValue = {}
				local _callback = function(spark)
					return spark.id < cutoff or spark.id > sparkId.current
				end
				local _length = 0
				for _k, _v in current do
					if _callback(_v, _k - 1, current) == true then
						_length += 1
						_newValue[_length] = _v
					end
				end
				-- ▲ ReadonlyArray.filter ▲
				return _newValue
			end)
		end)
	end
	local floatPop = function(text, color, critical, x, y)
		if x == nil then
			x = 0.5
		end
		if y == nil then
			y = 0.46
		end
		popId.current += 1
		local id = popId.current
		setPops(function(current)
			local _array = {}
			local _length = #_array
			local _currentLength = #current
			table.move(current, 1, _currentLength, _length + 1, _array)
			_length += _currentLength
			_array[_length + 1] = {
				id = id,
				text = text,
				x = x + (math.random() - 0.5) * 0.16,
				y = y + (math.random() - 0.5) * 0.06,
				color = color,
				critical = critical,
			}
			local updated = _array
			while #updated > 8 do
				table.remove(updated, 1)
			end
			return updated
		end)
		task.delay(0.9, function()
			return setPops(function(current)
				-- ▼ ReadonlyArray.filter ▼
				local _newValue = {}
				local _callback = function(pop)
					return pop.id ~= id
				end
				local _length = 0
				for _k, _v in current do
					if _callback(_v, _k - 1, current) == true then
						_length += 1
						_newValue[_length] = _v
					end
				end
				-- ▲ ReadonlyArray.filter ▲
				return _newValue
			end)
		end)
	end
	local gradeStrike = function()
		local phase = beatPhase.current % 1
		local dist = math.min(phase, 1 - phase)
		if dist <= PERFECT_WINDOW then
			return "PERFECT"
		end
		-- GOOD_WINDOW used to fall through to the same EARLY/LATE branch as a
		-- total miss — "GOOD" was declared as a grade and even had its own
		-- timing-ring color (cyan, below), but gradeStrike() could never
		-- actually return it, so the combo chain (which only extends on
		-- PERFECT || GOOD) had no real middle ground: PERFECT or reset.
		if dist <= GOOD_WINDOW then
			return "GOOD"
		end
		return if phase < 0.5 then "EARLY" else "LATE"
	end
	local strike = function()
		if os.clock() < strikeReadyAt or heat >= 0.98 then
			return nil
		end
		local grade = gradeStrike()
		local perfect = grade == "PERFECT"
		local wait = 0.08
		setStrikeReadyAt(os.clock() + wait)
		setStrikeLeft(wait)
		setLastGrade(grade)
		setPerfectPulse(perfect)
		setPressed(true)
		task.delay(0.08, function()
			return setPressed(false)
		end)
		setShock(function(value)
			return value + 1
		end)
		setHeat(function(current)
			return math.clamp(current + (if perfect then 0.05 elseif grade == "GOOD" then 0.07 else 0.09), 0, 1)
		end)
		setCombo(function(current)
			local chain = if perfect or grade == "GOOD" then current + 1 else 1
			setBest(function(old)
				return math.max(old, chain)
			end)
			return chain
		end)
		local pitchMultiplier = 1 + math.min(combo, 25) * 0.014
		Audio:play(if perfect then "confirm" else "reactorPulse", pitchMultiplier)
		InteractionFeedback.tap()
		local tapPower = asFlux(state.TapPower)
		local shown = math.max(1, tapPower * (if perfect then math.max(1.4, state.CriticalMultiplier) else 1))
		floatPop(`+{compactNumber(shown)}`, if perfect then Palette.mango else Palette.cream, perfect)
		-- Escalate the strike's own juice with the streak going into it, so a long combo
		-- visibly and audibly ramps up instead of every tap looking identical whether it's
		-- the 1st or the 40th in a row — capped so it settles rather than growing forever.
		local comboScale = 1 + math.min(combo, 30) / 30
		burst(if perfect then "perfect" else "strike", if perfect then Palette.mango else Palette.brass, 0.5, 0.54, math.floor((if perfect then 20 else 13) * comboScale))
		if combo > 0 and combo % 10 == 0 then
			Audio:play("discovery", 1 + math.min(math.floor(combo / 10), 4) * 0.06)
		end
		dispatch("Overcharge")
	end
	local bank = function()
		if not canBank then
			Audio:play("locked")
			return nil
		end
		Audio:play("vaultBank")
		InteractionFeedback.tap()
		floatPop(`+{compactNumber(state.Vault)}`, Palette.mint, true, 0.5, 0.78)
		burst("bank", Palette.mint, 0.5, 0.78, 14)
		setCombo(function(current)
			return current + 1
		end)
		dispatch("CollectVault")
	end
	local catchOrb = function(orb)
		setOrbs(function(current)
			-- ▼ ReadonlyArray.filter ▼
			local _newValue = {}
			local _callback = function(entry)
				return entry.id ~= orb.id
			end
			local _length = 0
			for _k, _v in current do
				if _callback(_v, _k - 1, current) == true then
					_length += 1
					_newValue[_length] = _v
				end
			end
			-- ▲ ReadonlyArray.filter ▲
			return _newValue
		end)
		setCaught(function(value)
			return value + 1
		end)
		setCombo(function(current)
			return current + 1
		end)
		setHeat(function(current)
			return math.max(0, current - 0.06)
		end)
		Audio:play("tick")
		burst("scrap", orb.color, orb.x, orb.y, 4)
	end
	local sealRift = function(rift)
		setRifts(function(current)
			-- ▼ ReadonlyArray.filter ▼
			local _newValue = {}
			local _callback = function(entry)
				return entry.id ~= rift.id
			end
			local _length = 0
			for _k, _v in current do
				if _callback(_v, _k - 1, current) == true then
					_length += 1
					_newValue[_length] = _v
				end
			end
			-- ▲ ReadonlyArray.filter ▲
			return _newValue
		end)
		setSealed(function(value)
			return value + 1
		end)
		setCombo(function(current)
			return current + 2
		end)
		Audio:play("reactorPulse")
		burst("rift", Palette.pink, rift.x, rift.y, 8)
		if riftReady then
			dispatch("StabilizeAnomaly")
		else
			dispatch("PulseAnomaly")
		end
	end
	local buyStation = function(machine)
		local _condition_1 = state.Machines[machine.Id]
		if _condition_1 == nil then
			_condition_1 = 0
		end
		local level = _condition_1
		local price = scaledCost(machine.BaseCost, machine.CostScale, level)
		if not gteFlux(state.Cash, price) then
			Audio:play("locked")
			return nil
		end
		Audio:play("confirm")
		burst("strike", machine.Color, 0.5, 0.42, 5)
		dispatch("BuyMachine", {
			Id = machine.Id,
			Amount = 1,
		})
	end
	local buyStationRef = React.useRef(buyStation)
	buyStationRef.current = buyStation
	local onTuneStation = React.useCallback(function(machine)
		return buyStationRef.current(machine)
	end, {})
	React.useEffect(function()
		local connection = UserInputService.InputBegan:Connect(function(input, processed)
			if processed or UserInputService:GetFocusedTextBox() ~= nil then
				return nil
			end
			if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonX then
				strike()
			elseif input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonY then
				bank()
			end
		end)
		return function()
			return connection:Disconnect()
		end
	end)
	local ringPhase = beat:map(function(phase)
		beatPhase.current = phase % 1
		return phase % 1
	end)
	local ringScale = ringPhase:map(function(phase)
		local dist = math.min(phase, 1 - phase)
		return 0.72 + (1 - dist * 4) * 0.18
	end)
	local ringColor = ringPhase:map(function(phase)
		local dist = math.min(phase, 1 - phase)
		if dist <= PERFECT_WINDOW then
			return Palette.mango
		end
		if dist <= GOOD_WINDOW then
			return Palette.cyan
		end
		return Palette.lineSoft
	end)
	local overheated = heat >= 0.98
	local strikeLabel = if overheated then "COOLING" elseif strikeLeft > 0.02 then string.format("%.1fs", strikeLeft) elseif lastGrade == "PERFECT" then "PERFECT" else "STRIKE"
	local _result_2
	if nextMachine ~= nil then
		local _exp = nextMachine.BaseCost
		local _exp_1 = nextMachine.CostScale
		local _condition_1 = state.Machines[nextMachine.Id]
		if _condition_1 == nil then
			_condition_1 = 0
		end
		_result_2 = scaledCost(_exp, _exp_1, _condition_1)
	else
		_result_2 = 0
	end
	local nextPrice = _result_2
	local canBuyNext = nextMachine ~= nil and gteFlux(state.Cash, nextPrice)
	local _exp = React.createElement(WorldHaze, {
		color = worldColor,
		reducedMotion = quiet,
	})
	local _exp_1 = React.createElement(HeatHaze, {
		heat = heat,
		reducedMotion = quiet,
	})
	local _attributes = {}
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#stations)
	local _callback = function(station)
		return {
			x = station.x,
			y = station.y,
			color = station.machine.Color,
			live = station.level > 0,
		}
	end
	for _k, _v in stations do
		_newValue[_k] = _callback(_v, _k - 1, stations)
	end
	-- ▲ ReadonlyArray.map ▲
	_attributes.stations = _newValue
	_attributes.reducedMotion = quiet
	_attributes.accent = Palette.brass
	local _exp_2 = React.createElement(FluxRiver, _attributes)
	local _exp_3 = React.createElement("frame", {
		Size = UDim2.new(1, -28, 0, if stack then 78 else 70),
		Position = UDim2.fromOffset(14, 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 30,
	}, React.createElement(Text, {
		value = compactNumber(state.Cash),
		size = if stack then 34 else 42,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 22,
		sizeConstraint = UDim2.new(1, 0, 0, if stack then 40 else 46),
	}), React.createElement(Text, {
		value = `{compactNumber(state.Production)} flux / sec`,
		size = 13,
		color = Palette.brass,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = false,
		position = UDim2.fromOffset(0, if stack then 42 else 48),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	}), React.createElement("frame", {
		Size = UDim2.new(0.56, 0, 0, 7),
		Position = UDim2.new(0.22, 0, 1, -6),
		BackgroundColor3 = Palette.line,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = vaultSpring:map(function(amount)
			return UDim2.new(math.clamp(amount, 0.02, 1), 0, 1, 0)
		end),
		BackgroundColor3 = if vaultFull then Palette.mango else Palette.mint,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))))
	local _exp_4 = React.createElement(ComboBanner, {
		combo = combo,
		heat = heat,
		perfect = perfectPulse,
		reducedMotion = quiet,
	})
	local _exp_5 = React.createElement(CoreAura, {
		color = if perfectPulse then Palette.mango else Palette.brass,
		heat = heat,
		squash = squash,
		reducedMotion = quiet,
	})
	local _exp_6 = React.createElement("frame", {
		Size = UDim2.fromScale(if stack then 0.92 else 0.86, if stack then 0.92 else 0.86),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 20,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 20,
	}, React.createElement("uiscale", {
		Scale = squash,
	}), React.createElement("frame", {
		Size = ringScale:map(function(amount)
			return UDim2.fromScale(amount, amount)
		end),
		Position = UDim2.fromScale(0.5, 0.54),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 21,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = ringColor,
		Thickness = 4,
		Transparency = floorPulse:map(function(amount)
			return 0.12 + amount * 0.2
		end),
	})), React.createElement(ForgeAnvil2D, {
		size = UDim2.fromScale(0.88, 0.88),
		position = UDim2.fromScale(0.5, 0.54),
		reducedMotion = quiet,
		lowQuality = antilag.tier <= 1,
		finaleActive = false,
		finaleTimeline = finaleTimeline,
		fade = fade,
		onStrike = function()
			if not quiet then
				setFinaleTimeline((beatPhase.current + 0.01) % 1)
			end
		end,
		zIndex = 24,
	})), React.createElement("imagebutton", {
		Size = UDim2.fromScale(0.7, 0.7),
		Position = UDim2.fromScale(0.5, 0.54),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = true,
		ZIndex = 40,
		Event = {
			Activated = function()
				return strike()
			end,
			InputBegan = function(_b, input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					setPressed(true)
				end
			end,
			InputEnded = function()
				return setPressed(false)
			end,
		},
	}))
	-- ▼ ReadonlyArray.map ▼
	local _newValue_1 = table.create(#stations)
	local _callback_1 = function(station)
		return React.createElement(StationPad, {
			key = station.machine.Id,
			station = station,
			cash = state.Cash,
			reducedMotion = quiet,
			onTune = onTuneStation,
		})
	end
	for _k, _v in stations do
		_newValue_1[_k] = _callback_1(_v, _k - 1, stations)
	end
	-- ▲ ReadonlyArray.map ▲
	-- ▼ ReadonlyArray.map ▼
	local _newValue_2 = table.create(#orbs)
	local _callback_2 = function(orb)
		return React.createElement("imagebutton", {
			key = orb.id,
			Size = UDim2.fromOffset(TapTarget, TapTarget),
			Position = UDim2.fromScale(orb.x, orb.y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Active = true,
			Selectable = true,
			ZIndex = 50,
			Event = {
				Activated = function()
					return catchOrb(orb)
				end,
			},
		}, React.createElement("frame", {
			Size = UDim2.fromOffset(22, 22),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = orb.color,
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uistroke", {
			Color = Palette.cream,
			Thickness = 1,
			Transparency = 0.35,
		})))
	end
	for _k, _v in orbs do
		_newValue_2[_k] = _callback_2(_v, _k - 1, orbs)
	end
	-- ▲ ReadonlyArray.map ▲
	-- ▼ ReadonlyArray.map ▼
	local _newValue_3 = table.create(#rifts)
	local _callback_3 = function(rift)
		return React.createElement("imagebutton", {
			key = rift.id,
			Size = UDim2.fromOffset(54, 54),
			Position = UDim2.fromScale(rift.x, rift.y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = darken(Palette.pink, 0.55),
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Active = true,
			Selectable = true,
			ZIndex = 51,
			Event = {
				Activated = function()
					return sealRift(rift)
				end,
			},
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uistroke", {
			Color = if rift.charged then Palette.mango else Palette.pink,
			Thickness = 2,
			Transparency = 0.2,
		}), React.createElement(Icon, {
			kind = "Anomaly",
			color = Palette.cream,
			accent = Palette.pink,
			size = 28,
			spin = not quiet,
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
		}))
	end
	for _k, _v in rifts do
		_newValue_3[_k] = _callback_3(_v, _k - 1, rifts)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, _exp, _exp_1, _exp_2, _exp_3, _exp_4, _exp_5, _exp_6, _newValue_1, _newValue_2, _newValue_3, React.createElement(ShockRing, {
		trigger = shock,
		color = if perfectPulse then Palette.mango else Palette.brass,
		reducedMotion = quiet,
		size = (if stack then 240 else 320) * (1 + math.min(combo, 30) / 60),
	}), React.createElement(SparkBurst, {
		sparks = sparks,
		reducedMotion = quiet,
	}), React.createElement(ClickPops, {
		pops = pops,
		reducedMotion = quiet,
	}), React.createElement("frame", {
		Size = UDim2.new(0.42, 0, 0, 8),
		Position = UDim2.new(0.29, 0, 1, if stack then -124 else -108),
		BackgroundColor3 = Palette.line,
		BorderSizePixel = 0,
		ZIndex = 35,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = heatSpring:map(function(amount)
			return UDim2.new(math.clamp(amount, 0.02, 1), 0, 1, 0)
		end),
		BackgroundColor3 = if overheated then Palette.coral else Palette.brass,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))), React.createElement(Text, {
		value = if overheated then "TOO HOT" elseif lastGrade == "PERFECT" then "CRIT" else "CLICK THE FORGE",
		size = 11,
		color = if overheated then Palette.coral elseif lastGrade == "PERFECT" then Palette.mango else Palette.creamSoft,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.new(0, 12, 1, if stack then -112 else -96),
		sizeConstraint = UDim2.new(1, -24, 0, 16),
		zIndex = 35,
	}), React.createElement("frame", {
		Size = UDim2.new(1, -24, 0, if stack then 104 else 92),
		Position = UDim2.new(0, 12, 1, if stack then -108 else -88),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 36,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, TapTarget),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 1,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement("frame", {
		Size = UDim2.new(0.5, -4, 1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	}, React.createElement(Button, {
		text = strikeLabel,
		icon = "Overcharge",
		onClick = strike,
		color = if overheated or strikeLeft > 0.02 then Palette.panelSoft else Palette.mango,
		textColor = if overheated or strikeLeft > 0.02 then Palette.muted else Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = overheated or strikeLeft > 0.02,
		highlight = strikeLeft <= 0.02 and not overheated,
	})), React.createElement("frame", {
		Size = UDim2.new(0.5, -4, 1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, React.createElement(Button, {
		text = if canBank then `BANK  {compactNumber(state.Vault)}` else "WELL EMPTY",
		icon = "Collect",
		onClick = bank,
		color = if canBank then Palette.mint else Palette.panelSoft,
		textColor = if canBank then Palette.ink else Palette.muted,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = not canBank,
		highlight = vaultFill >= 0.7,
	}))), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, TapTarget),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 2,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement("frame", {
		Size = UDim2.new(0.5, -4, 1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	}, React.createElement(Button, {
		text = if nextMachine ~= nil then (if canBuyNext then `BUY  {nextMachine.Name}` else `NEED  {compactNumber(nextPrice)} FOR {nextMachine.Name}`) else "OPEN WORKSHOP",
		icon = "Forge",
		onClick = function()
			if nextMachine ~= nil then
				buyStation(nextMachine)
			else
				openWorkshop()
			end
		end,
		color = if canBuyNext then worldColor else Palette.panelSoft,
		textColor = if canBuyNext then Palette.ink else Palette.creamSoft,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = nextMachine == nil,
		highlight = canBuyNext,
	})), React.createElement("frame", {
		Size = UDim2.new(0.5, -4, 1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, React.createElement(Button, {
		text = if canRebirth then "REWRITE" elseif riftReady then "SEAL RIFT" else "OPEN BAY",
		icon = if canRebirth then "Rebirth" elseif riftReady then "Anomaly" else "World",
		onClick = function()
			if canRebirth then
				openDomain()
			elseif riftReady then
				dispatch("StabilizeAnomaly")
			else
				openWorkshop()
			end
		end,
		color = if canRebirth then Palette.pink elseif riftReady then Palette.violet else Palette.panelSoft,
		textColor = if canRebirth or riftReady then Palette.ink else Palette.cream,
		outline = not canRebirth and not riftReady,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		highlight = canRebirth or riftReady,
	})))))
end
StationPad = React.memo(function(props)
	local _binding = props
	local station = _binding.station
	local cash = _binding.cash
	local reducedMotion = _binding.reducedMotion
	local onTune = _binding.onTune
	local pulse = usePulse(not reducedMotion and station.level > 0, 1.1 + (station.level % 5) * 0.07)
	local price = scaledCost(station.machine.BaseCost, station.machine.CostScale, station.level)
	local ready = gteFlux(cash, price)
	return React.createElement("imagebutton", {
		Size = UDim2.fromOffset(72, 72),
		Position = UDim2.fromScale(station.x, station.y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = true,
		ZIndex = 28,
		Event = {
			Activated = function()
				return onTune(station.machine)
			end,
		},
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = darken(station.machine.Color, 0.62),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
	}, React.createElement("uiscale", {
		Scale = pulse:map(function(amount)
			return 1 + amount * 0.04
		end),
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 16),
	}), React.createElement("uistroke", {
		Color = if ready then station.machine.Color else Palette.lineSoft,
		Thickness = if ready then 2 else 1,
		Transparency = if ready then 0.18 else 0.55,
	}), React.createElement(Icon, {
		kind = machineIcon(station.machine),
		color = Palette.cream,
		accent = station.machine.Color,
		size = 28,
		spin = not reducedMotion and station.level > 0,
		position = UDim2.fromOffset(22, 8),
	}), React.createElement(Text, {
		value = `Lv {compactNumber(station.level)}`,
		size = 10,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(4, 40),
		sizeConstraint = UDim2.new(1, -8, 0, 14),
	}), React.createElement(Text, {
		value = if ready then "TUNE" else compactNumber(price),
		size = 9,
		color = if ready then station.machine.Color else Palette.muted,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(4, 54),
		sizeConstraint = UDim2.new(1, -8, 0, 12),
	})))
end, function(prev, incoming)
	return prev.station.machine == incoming.station.machine and prev.station.level == incoming.station.level and prev.station.x == incoming.station.x and prev.station.y == incoming.station.y and prev.cash == incoming.cash and prev.reducedMotion == incoming.reducedMotion and prev.onTune == incoming.onTune
end)
return {
	ForgeFloorView = ForgeFloorView,
}

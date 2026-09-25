local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.Parent.audio).Audio
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local InteractionFeedback = require(script.Parent.Parent.interaction).InteractionFeedback
local _motion = require(script.Parent.Parent.motion)
local easeOutCubic = _motion.easeOutCubic
local useBoatTween = _motion.useBoatTween
local useExitTransition = _motion.useExitTransition
local useFlash = _motion.useFlash
local useFlipperSpring = _motion.useFlipperSpring
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.theme)
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local _ui = require(script.Parent.Parent.ui)
local Button = _ui.Button
local Panel = _ui.Panel
local Text = _ui.Text
local useGamepadAutofocus = _ui.useGamepadAutofocus
local CrateRevealStage = require(script.Parent.CrateRevealStageSimple).CrateRevealStage
local CARD_W = 156
local CARD_H = 132
local CARD_GAP = 12
local STRIDE = CARD_W + CARD_GAP
local START_SLOT = 2
local WIN_SLOT = 15
local FILLER_COUNT = 19
local START_OFFSET = START_SLOT * STRIDE
local TARGET_OFFSET = WIN_SLOT * STRIDE
local SPIN_SECONDS = 3.8
local BATCH_SPIN_SECONDS = 1.42
local EXIT_SETTLE = 0.42
local function rarityColor(config, rarity)
	local _result = config.Items
	if _result ~= nil then
		_result = _result.Rarities[rarity]
		if _result ~= nil then
			_result = _result.Color
		end
	end
	local _condition = _result
	if _condition == nil then
		_condition = Palette.mango
	end
	return _condition
end
local function definitionName(config, definitionId)
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
local function buildStrip(config, session, roll, rollIndex)
	local _result = config.Items
	if _result ~= nil then
		_result = _result.Crates
	end
	local _condition = _result
	if _condition == nil then
		_condition = {}
	end
	-- ▼ ReadonlyArray.find ▼
	local _callback = function(entry)
		return entry.Id == session.crateId
	end
	local _result_1
	for _i, _v in _condition do
		if _callback(_v, _i - 1, _condition) == true then
			_result_1 = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local crate = _result_1
	local _result_2 = crate
	if _result_2 ~= nil then
		_result_2 = _result_2.Weights
	end
	local _condition_1 = _result_2
	if _condition_1 == nil then
		_condition_1 = {
			Common = 1,
		}
	end
	local weights = _condition_1
	local _result_3 = config.Items
	if _result_3 ~= nil then
		_result_3 = _result_3.Definitions
	end
	local _condition_2 = _result_3
	if _condition_2 == nil then
		_condition_2 = {}
	end
	local definitions = _condition_2
	local pools = {}
	for _, definition in definitions do
		local _rarity = definition.Rarity
		local pool = pools[_rarity]
		if pool == nil then
			pool = {}
			local _rarity_1 = definition.Rarity
			local _pool = pool
			pools[_rarity_1] = _pool
		end
		table.insert(pool, definition)
	end
	local weighted = {}
	local totalWeight = 0
	for rarity, rawWeight in pairs(weights) do
		local weight = math.max(0, rawWeight)
		if weight <= 0 then
			continue
		end
		local _arg0 = {
			rarity = rarity,
			weight = weight,
		}
		table.insert(weighted, _arg0)
		totalWeight += weight
	end
	table.sort(weighted, function(a, b)
		return a.rarity < b.rarity
	end)
	local fillerAt = function(seed)
		if #definitions == 0 then
			return nil
		end
		if totalWeight <= 0 then
			return definitions[seed % #definitions + 1]
		end
		local sample = ((math.abs(math.sin(seed * 12.9898)) * 43758.5453) % 1) * totalWeight
		local selected
		for _, entry in weighted do
			sample -= entry.weight
			if sample <= 0 then
				selected = entry.rarity
				break
			end
		end
		local _result_4
		if selected ~= nil then
			local _selected = selected
			_result_4 = pools[_selected]
		else
			_result_4 = nil
		end
		local pool = _result_4
		if pool == nil or #pool == 0 then
			return definitions[seed % #definitions + 1]
		end
		return pool[seed % #pool + 1]
	end
	local cards = {}
	for index = 0, FILLER_COUNT - 1 do
		if index == WIN_SLOT then
			local _arg0 = {
				key = `winner-{roll.Uid}-{rollIndex}`,
				definitionId = roll.DefinitionId,
				name = definitionName(config, roll.DefinitionId),
				rarity = roll.Rarity,
				accent = rarityColor(config, roll.Rarity),
				winner = true,
				tag = if roll.New == true then "NEW" elseif roll.Pity == true then "PITY" else "WIN",
			}
			table.insert(cards, _arg0)
			continue
		end
		local filler = fillerAt(rollIndex * 97 + index * 13 + 11)
		local _object = {
			key = if filler ~= nil then `filler-{rollIndex}-{index}-{filler.Id}` else `fallback-{rollIndex}-{index}`,
		}
		local _left = "definitionId"
		local _result_4 = filler
		if _result_4 ~= nil then
			_result_4 = _result_4.Id
		end
		local _condition_3 = _result_4
		if _condition_3 == nil then
			_condition_3 = roll.DefinitionId
		end
		_object[_left] = _condition_3
		local _left_1 = "name"
		local _result_5 = filler
		if _result_5 ~= nil then
			_result_5 = _result_5.Name
		end
		local _condition_4 = _result_5
		if _condition_4 == nil then
			_condition_4 = definitionName(config, roll.DefinitionId)
		end
		_object[_left_1] = _condition_4
		local _left_2 = "rarity"
		local _result_6 = filler
		if _result_6 ~= nil then
			_result_6 = _result_6.Rarity
		end
		local _condition_5 = _result_6
		if _condition_5 == nil then
			_condition_5 = roll.Rarity
		end
		_object[_left_2] = _condition_5
		local _left_3 = "accent"
		local _exp = config
		local _result_7 = filler
		if _result_7 ~= nil then
			_result_7 = _result_7.Rarity
		end
		local _condition_6 = _result_7
		if _condition_6 == nil then
			_condition_6 = roll.Rarity
		end
		_object[_left_3] = rarityColor(_exp, _condition_6)
		_object.winner = false
		table.insert(cards, _object)
	end
	return cards
end
local function reelProgress(t, travel)
	local x = math.clamp(t, 0, 1)
	if x <= 0.13 then
		local u = x / 0.13
		return 0.055 * u * u * u
	end
	if x <= 0.67 then
		local u = (x - 0.13) / 0.54
		return 0.055 + 0.735 * (u + math.sin(u * math.pi) * 0.035)
	end
	if x <= 0.92 then
		local u = (x - 0.67) / 0.25
		return 0.79 + 0.21 * (1 - math.pow(1 - u, 3.7))
	end
	local u = (x - 0.92) / 0.08
	local overshoot = math.min(0.018, STRIDE * 0.34 / math.max(STRIDE, travel))
	return 1 + math.sin(u * math.pi * 2) * math.exp(-3.6 * u) * overshoot
end
local function CrateRevealExperience(_param)
	local session = _param.session
	local config = _param.config
	local reducedMotion = _param.reducedMotion
	local onClose = _param.onClose
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local reelFrameRate = 60
	local rollIndex, setRollIndex = React.useState(0)
	local phase, setPhase = React.useState("enter")
	local offset, setOffset = React.useBinding(START_OFFSET)
	local spinEnergy, setSpinEnergy = React.useBinding(0)
	local spinProgress, setSpinProgress = React.useBinding(0)
	local tickEnergy, setTickEnergy = React.useBinding(0)
	local closedRef = React.useRef(false)
	local spinSettledRef = React.useRef(false)
	local quickLandAtRef = React.useRef(-1)
	local quickLandOffsetRef = React.useRef(START_OFFSET)
	local brakeSoundedRef = React.useRef(false)
	local live, setLive = React.useState(false)
	local _binding = useExitTransition(reducedMotion, EXIT_SETTLE)
	local exitAmount = _binding[1]
	local exiting = _binding[2]
	local beginExit = _binding[3]
	React.useEffect(function()
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
	local present = live
	-- Soft boat tweens on antilag tiers avoid Flipper spring chatter during claim/earn moments.
	local motionScale = if reducedMotion then 0.55 else 1
	local boatShow = useBoatTween(if present then 1 else 0, (if present then 0.3 else EXIT_SETTLE) * motionScale, false, easeOutCubic, 0)
	local showSpring = useFlipperSpring(if present then 1 else 0, false, 720, 36)
	local showBoat = useBoatTween(if present then 1 else 0, (if present then 0.28 else EXIT_SETTLE) * motionScale, false, easeOutCubic, 0)
	local show = showSpring
	local landHold = phase == "land" or phase == "done" or phase == "exit"
	local claimHold = phase == "done" or phase == "exit"
	local landPopSpring = useFlipperSpring(if landHold then 1 else 0, false, 640, 14)
	local landPopBoat = useBoatTween(if landHold then 1 else 0, 0.22 * motionScale, false, easeOutCubic, 0)
	local landPop = landPopSpring
	local claimSlideSpring = useFlipperSpring(if claimHold then 1 else 0, false, 520, 24)
	local claimSlideBoat = useBoatTween(if claimHold then 1 else 0, 0.2 * motionScale, false, easeOutCubic, 0)
	local claimSlide = claimSlideSpring
	local landFlash = useFlash(if phase == "land" then rollIndex + 1 else 0, false, 0.62 * motionScale)
	-- Claim CTA flash — intentional polish without noisy springs on low tiers.
	local claimFlash = useFlash(if phase == "done" then rollIndex + 11 else 0, false, 0.48 * motionScale)
	local chargePulseSpring = useFlipperSpring(if phase == "charge" then 1 else 0, false, 360, 19)
	local chargePulseBoat = useBoatTween(if phase == "charge" then 1 else 0, 0.18 * motionScale, false, easeOutCubic, 0)
	local chargePulse = chargePulseSpring
	local rolls = session.rolls
	if type(rolls) ~= "table" then
		rolls = {}
	end
	local currentRoll = rolls[math.clamp(rollIndex, 0, math.max(0, #rolls - 1)) + 1]
	local strip = React.useMemo(function()
		return buildStrip(config, session, currentRoll, rollIndex)
	end, { config, currentRoll, rollIndex, session })
	local travelDistance = TARGET_OFFSET - START_OFFSET
	React.useEffect(function()
		local previousTouch = GuiService.TouchControlsEnabled
		GamepadNavigationService.BeginOverlayFocus()
		GuiService.TouchControlsEnabled = false
		return function()
			GamepadNavigationService.EndOverlayFocus()
			GuiService.TouchControlsEnabled = previousTouch
		end
	end, {})
	React.useEffect(function()
		if phase ~= "enter" then
			return nil
		end
		local alive = true
		local job = task.delay(if reducedMotion then 0.12 else 0.2, function()
			if alive then
				setPhase("charge")
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, job)
		end
	end, { phase, reducedMotion })
	React.useEffect(function()
		if phase ~= "charge" then
			return nil
		end
		Audio:play("crateCharge")
		local alive = true
		local job = task.delay(if reducedMotion then 0.28 else 0.48, function()
			if alive then
				setPhase("spin")
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, job)
		end
	end, { phase, reducedMotion })
	local landCurrent = React.useCallback(function()
		if spinSettledRef.current then
			return nil
		end
		spinSettledRef.current = true
		setOffset(TARGET_OFFSET)
		setSpinEnergy(0)
		setSpinProgress(1)
		setTickEnergy(1)
		setPhase("land")
		if currentRoll ~= nil then
			local mythic = currentRoll.Rarity == "Mythic"
			local special = currentRoll.New == true or currentRoll.Pity == true or currentRoll.Rarity == "Legendary" or mythic
			if mythic then
				Audio:playCelebration({ "crateRare", "discovery", "reward" }, 0.08)
			else
				Audio:play(if special then "crateRare" else "crateLand")
			end
		else
			Audio:play("crateLand")
		end
		InteractionFeedback.reward()
	end, { currentRoll, setOffset, setSpinEnergy, setSpinProgress, setTickEnergy })
	local skipSpin = React.useCallback(function()
		if phase ~= "spin" then
			return nil
		end
		Audio:play("crateNear")
		if quickLandAtRef.current < 0 then
			quickLandAtRef.current = os.clock()
			quickLandOffsetRef.current = START_OFFSET
		end
	end, { phase })
	React.useEffect(function()
		if phase ~= "spin" then
			return nil
		end
		spinSettledRef.current = false
		setOffset(START_OFFSET)
		setSpinEnergy(0)
		setSpinProgress(0)
		setTickEnergy(0)
		quickLandAtRef.current = -1
		quickLandOffsetRef.current = START_OFFSET
		brakeSoundedRef.current = false
		Audio:play("crateOpen")
		local startedAt = os.clock()
		local lastVisualAt = startedAt - 1 / reelFrameRate
		local duration = (if rollIndex == 0 then SPIN_SECONDS else BATCH_SPIN_SECONDS) * (if reducedMotion then 0.55 else 1)
		local lastTickSlot = -1
		local lastTickAt = -math.huge
		local previousValue = START_OFFSET
		local tick = 0
		local connection
		connection = RunService.RenderStepped:Connect(function()
			if spinSettledRef.current then
				connection:Disconnect()
				return nil
			end
			local now = os.clock()
			local elapsed = now - startedAt
			local raw = math.clamp(elapsed / duration, 0, 1)
			if raw < 1 and now - lastVisualAt < 1 / reelFrameRate then
				return nil
			end
			local visualDelta = math.max(1 / 240, now - lastVisualAt)
			lastVisualAt = now
			local value
			if quickLandAtRef.current >= 0 then
				if quickLandOffsetRef.current == START_OFFSET then
					quickLandOffsetRef.current = previousValue
				end
				local quick = math.clamp((now - quickLandAtRef.current) / 0.34, 0, 1)
				value = quickLandOffsetRef.current + (TARGET_OFFSET - quickLandOffsetRef.current) * (1 - math.pow(1 - quick, 4))
				raw = 0.94 + quick * 0.06
			else
				value = START_OFFSET + travelDistance * reelProgress(raw, travelDistance)
			end
			setOffset(value)
			setSpinProgress(raw)
			local cardsPerSecond = math.abs(value - previousValue) / visualDelta / STRIDE
			previousValue = value
			local authoredEnergy = if raw < 0.1 then raw / 0.1 elseif raw < 0.7 then 1 else math.clamp((0.97 - raw) / 0.27, 0, 1)
			setSpinEnergy(math.clamp(cardsPerSecond / 18, 0, 1) * authoredEnergy)
			if raw >= 0.69 and not brakeSoundedRef.current then
				brakeSoundedRef.current = true
				Audio:play("crateBrake")
			end
			tick *= math.exp(-visualDelta * 18)
			local slot = math.floor(value / STRIDE + 0.5)
			local tickGap = if rollIndex == 0 then 0.045 else 0.065
			if slot ~= lastTickSlot and raw < 0.97 and elapsed - lastTickAt >= tickGap then
				lastTickSlot = slot
				lastTickAt = elapsed
				tick = if raw > 0.72 then 1 else 0.58
				Audio:play("crateTick", 0.94 + raw * 0.18)
				if raw > 0.72 then
					InteractionFeedback.tick()
				end
			end
			setTickEnergy(tick)
			if raw >= 1 then
				connection:Disconnect()
				landCurrent()
			end
		end)
		return function()
			return connection:Disconnect()
		end
	end, { landCurrent, phase, reducedMotion, reelFrameRate, rollIndex, setOffset, setSpinEnergy, setSpinProgress, setTickEnergy, travelDistance })
	React.useEffect(function()
		if phase ~= "land" then
			return nil
		end
		local alive = true
		local job = task.delay(if rollIndex >= #rolls - 1 then 0.72 else 0.62, function()
			if not alive then
				return nil
			end
			if rollIndex >= #rolls - 1 then
				setPhase("done")
			else
				setRollIndex(function(value)
					return value + 1
				end)
				setPhase("spin")
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, job)
		end
	end, { phase, rollIndex, rolls })
	local finish = React.useCallback(function()
		if closedRef.current or phase == "exit" or exiting then
			return nil
		end
		GamepadNavigationService.ClearSelection()
		Audio:play("crateClaim")
		InteractionFeedback.confirm()
		setPhase("exit")
		beginExit(function()
			if not closedRef.current then
				closedRef.current = true
				onClose()
			end
		end)
	end, { beginExit, exiting, onClose, phase })
	React.useEffect(function()
		local actionName = "AstralForgeCrateClose"
		ContextActionService:BindActionAtPriority(actionName, function(_name, inputState)
			if inputState == Enum.UserInputState.Begin then
				if phase == "spin" then
					skipSpin()
				elseif phase == "done" then
					finish()
				end
			end
			return Enum.ContextActionResult.Sink
		end, false, 2300, Enum.KeyCode.ButtonB)
		local input = UserInputService.InputBegan:Connect(function(event, processed)
			if processed then
				return nil
			end
			local activate = event.KeyCode == Enum.KeyCode.ButtonA or event.KeyCode == Enum.KeyCode.Return or event.KeyCode == Enum.KeyCode.Space
			if not activate then
				return nil
			end
			if phase == "spin" then
				skipSpin()
			elseif phase == "done" then
				finish()
			end
		end)
		return function()
			input:Disconnect()
			ContextActionService:UnbindAction(actionName)
		end
	end, { finish, phase, skipSpin })
	local count = #rolls
	local safeRoll = currentRoll or {
		Rarity = "Common",
		DefinitionId = "Unknown",
		New = false,
		Pity = false,
		AutoSalvaged = false,
		Essence = 0,
	}
	local winnerAccent = rarityColor(config, safeRoll.Rarity)
	local _result
	if safeRoll.AutoSalvaged == true then
		local _condition = safeRoll.Essence
		if _condition == nil then
			_condition = 0
		end
		_result = `+{_condition} ESSENCE`
	else
		_result = if safeRoll.New == true then "NEW FIND" elseif safeRoll.Pity == true then "PITY DROP" else "OWNED"
	end
	local resultTag = _result
	local resultDetail = if safeRoll.AutoSalvaged == true then "Relic Recycler converted this drop into essence." elseif safeRoll.Pity == true then "Pity protection delivered this rarity." elseif safeRoll.New == true then "Added to your relic inventory." else "Added to your inventory."
	local _exp = rolls
	-- ▼ ReadonlyArray.every ▼
	local _result_1 = true
	local _callback = function(roll)
		return roll.AutoSalvaged == true
	end
	for _k, _v in _exp do
		if not _callback(_v, _k - 1, _exp) then
			_result_1 = false
			break
		end
	end
	-- ▲ ReadonlyArray.every ▲
	local claimText = if _result_1 then "BANK ESSENCE" elseif count == 1 then "CLAIM RELIC" else `CLAIM {count} DROPS`
	local visualShow = React.joinBindings({ show, boatShow, exitAmount }):map(function(values)
		return math.clamp(math.min(values[1], values[2], values[3]), 0, 1)
	end)
	local winnerCardScale = React.joinBindings({ landPop, landFlash, claimFlash }):map(function(values)
		return 0.94 + values[1] * 0.075 + values[2] * 0.025 + values[3] * 0.02
	end)
	return React.createElement(CrateRevealStage, {
		crateName = session.crateName,
		sessionAccent = session.accent,
		cards = strip,
		cardWidth = CARD_W,
		cardHeight = CARD_H,
		stride = STRIDE,
		reelOffset = offset,
		phase = phase,
		rollIndex = rollIndex,
		rollCount = count,
		winnerName = definitionName(config, safeRoll.DefinitionId),
		winnerRarity = safeRoll.Rarity,
		winnerAccent = winnerAccent,
		resultTag = resultTag,
		resultDetail = resultDetail,
		claimText = claimText,
		reducedMotion = reducedMotion,
		shortLandscape = chrome.landscape and viewport.height < 400,
		portrait = chrome.portrait,
		viewportWidth = viewport.width,
		viewportHeight = viewport.height,
		topInset = viewport.topInset,
		bottomSafe = math.max(chrome.bottomSafe, 8),
		sideSafe = math.max(chrome.sideSafe, viewport.sideInset),
		fxBudget = antilag.fxBudget,
		glowScale = antilag.glowScale,
		allowAmbient = antilag.allowAmbient,
		economyMode = chrome.mobile or antilag.tier <= 1,
		visualShow = visualShow,
		spinEnergy = spinEnergy,
		spinProgress = spinProgress,
		tickEnergy = tickEnergy,
		landFlash = landFlash,
		landPop = landPop,
		claimSlide = claimSlide,
		chargePulse = chargePulse,
		winnerCardScale = winnerCardScale,
		onQuickLand = skipSpin,
		onClaim = finish,
	})
end
local function EmptyCrateReveal(_param)
	local reducedMotion = _param.reducedMotion
	local onClose = _param.onClose
	local viewport = useViewport()
	local safeGutter = viewport.sideInset + 10
	local width = math.max(1, math.min(360, viewport.width - safeGutter * 2))
	local focusRef = useGamepadAutofocus(true)
	React.useEffect(function()
		GamepadNavigationService.BeginOverlayFocus()
		return function()
			GamepadNavigationService.EndOverlayFocus()
		end
	end, {})
	React.useEffect(function()
		local host = focusRef.current
		if host == nil then
			return nil
		end
		local job = task.defer(function()
			if host.Parent == nil then
				return
			end
			GamepadNavigationService.FocusClaim(host)
		end)
		return function()
			pcall(task.cancel, job)
		end
	end, {})
	return React.createElement("frame", {
		ref = focusRef,
		Name = "CrateClaim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
		-- FocusClaim CLAIM CTA must not clip overshoot (Stage/StageSimple already false).
		ClipsDescendants = false,
		Active = true,
		ZIndex = 400,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(width, 164),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 410,
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.coral,
		background = Palette.panelRaised,
		padding = 16,
		clips = false,
		zIndex = 411,
	}, React.createElement(Text, {
		value = "Crate didn't open",
		size = 20,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 14,
		sizeConstraint = UDim2.new(1, 0, 0, 28),
		zIndex = 412,
	}), React.createElement(Text, {
		value = "Nothing was taken. Try opening it again.",
		size = 12,
		color = Palette.creamSoft,
		align = Enum.TextXAlignment.Center,
		wrap = true,
		position = UDim2.fromOffset(0, 36),
		sizeConstraint = UDim2.new(1, 0, 0, 40),
		zIndex = 412,
	}), React.createElement(Button, {
		text = "BACK TO INVENTORY",
		icon = "Close",
		onClick = onClose,
		color = Palette.coral,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -TapTarget),
		reducedMotion = reducedMotion,
		selectable = true,
		highlight = true,
		zIndex = 413,
	}))))
end
local function CrateRevealOverlay(props)
	local session = props.session
	local rolls = if session ~= nil then session.rolls else nil
	local hasRolls = type(rolls) == "table" and #rolls > 0
	local _result
	if hasRolls then
		local _attributes = table.clone(props)
		setmetatable(_attributes, nil)
		_result = React.createElement(CrateRevealExperience, _attributes)
	else
		_result = React.createElement(EmptyCrateReveal, {
			reducedMotion = props.reducedMotion,
			onClose = props.onClose,
		})
	end
	return _result
end
return {
	CrateRevealOverlay = CrateRevealOverlay,
}

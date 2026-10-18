--!nonstrict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("PagesCore: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("PagesCore: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

__defs["OverviewView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local _flexbox = require(script.Parent.Parent.MotionKit)("flexbox")
local Flex = _flexbox.Flex
local FlexItem = _flexbox.FlexItem
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useClock = _motion.useClock
local useFlash = _motion.useFlash
local usePulse = _motion.usePulse
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local IconTile = _ui.IconTile
local Meter = _ui.Meter
local meterFill = _ui.meterFill
local Panel = _ui.Panel
local ShimmerText = _ui.ShimmerText
local Text = _ui.Text
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local NumberSpinnerHost = require(script.Parent.Parent.ReactHosts)("NumberSpinnerHost").NumberSpinnerHost
local RebirthPanel = __load("RebirthPanel").RebirthPanel
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local Layout = _theme.Layout
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local scrollTail = _theme.scrollTail
local surfaceGradient = _theme.surfaceGradient
local TapTarget = _theme.TapTarget
local _format = require(script.Parent.Parent.CoreKit)("format")
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local overviewGoal = require(script.Parent.Parent.OverviewGoals)(require(game.ReplicatedStorage.AstralForge.Shared.OmegaMath), compactNumber)
local gteFlux = _format.gteFlux
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local AppHelpers = require(script.Parent.Parent.CoreKit)("appNav").AppHelpers
local LayoutSectionPlan = require(script.Parent.Parent.LayoutKit)("layoutSectionPlan")
local VaultCollectEligibility = require(script.Parent.Parent.CoreKit)("vaultCollectEligibility")
local PageReadyMath = require(script.Parent.Parent.LayoutKit)("pageReadyMath")
local ReadyBoard = require(script.Parent.Parent.ReadyBoard)
local ReleaseClockMath = require(script.Parent.Parent.CoreKit)("releaseClockMath")
local JourneyMath = require(script.Parent.Parent.CoreKit)("journeyMath")

local function ReleaseCountdown(_param)
	local releaseAt = _param.releaseAt
	local reducedMotion = _param.reducedMotion
	local stack = _param.stack
	local layoutOrder = _param.layoutOrder
	local viewport = useViewport()
	local softMotion = reducedMotion
	local Workspace = game:GetService("Workspace")
	local function syncedNow()
		local ok, value = pcall(function()
			return Workspace:GetServerTimeNow()
		end)
		if ok and type(value) == "number" then
			return math.floor(value)
		end
		return os.time()
	end
	local now, setNow = React.useState(syncedNow())
	React.useEffect(function()
		local alive = true
		local worker = task.spawn(function()
			while alive do
				task.wait(0.5)
				if alive then
					setNow(syncedNow())
				end
			end
		end)
		return function()
			alive = false
			pcall(function()
				return task.cancel(worker)
			end)
		end
	end, {})
	local remaining = ReleaseClockMath.Remaining(releaseAt, now)
	local live = ReleaseClockMath.IsLive(releaseAt, now)
	local slam, setSlam = React.useState(0)
	local wasLive = React.useRef(live)
	React.useEffect(function()
		if live and not wasLive.current then
			wasLive.current = true
			setSlam(function(n)
				return n + 1
			end)
			if not reducedMotion then
				Audio:play("prestige")
				Audio:play("bootFinaleBang")
			end
		end
		if not live then
			wasLive.current = false
		end
	end, { live, reducedMotion })
	local animateLive = live
	local pulse = usePulse(animateLive, 2.15)
	local flash = useFlash(slam, reducedMotion, 1.2)
	local orbit = useClock(animateLive, 0.48, 1, true)
	local values = { {
		label = "DAYS",
		value = math.floor(remaining / 86400),
		color = Palette.cyan,
	}, {
		label = "HOURS",
		value = math.floor(remaining / 3600) % 24,
		color = Palette.violet,
	}, {
		label = "MINUTES",
		value = math.floor(remaining / 60) % 60,
		color = Palette.pink,
	}, {
		label = "SECONDS",
		value = remaining % 60,
		color = Palette.mango,
	} }
	local railBelowCopy = stack or viewport.width < 1080
	local height = if live then (if railBelowCopy then 170 else 148) elseif railBelowCopy then 162 else 132
	local railTop = if live then (if railBelowCopy then 78 else 36) elseif railBelowCopy then 68 else 28
	local railLeft = if live then 0 elseif railBelowCopy then 0 else 360
	local accent = if live then Palette.mint else Palette.cyan
	local wash = if live then pulse:map(function(amount)
		return 0.88 - amount * 0.22
	end) else 1
	local _exp = live and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.mint,
		BackgroundTransparency = wash,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}))
	local _exp_1 = React.createElement(IconTile, {
		kind = "Calendar",
		accent = accent,
		size = 46,
		radius = 12,
		position = UDim2.fromOffset(0, 2),
		glow = live,
		spin = live and not reducedMotion,
		reducedMotion = reducedMotion,
	})
	local _exp_2 = React.createElement(Text, {
		value = if live then "LAUNCH" else "RELEASE COUNTDOWN",
		size = 11,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(58, 2),
		sizeConstraint = UDim2.new(1, if railBelowCopy then -58 else -420, 0, 16),
	})
	local _exp_3 = React.createElement(Text, {
		value = if live then "Astral Forge is now live." else "Official launch is August 31, 2026.",
		size = if railBelowCopy then 17 else 20,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 13,
		position = UDim2.fromOffset(58, 21),
		sizeConstraint = UDim2.new(1, if railBelowCopy then -58 else -420, 0, 28),
	})
	local _result
	if live then
		local _condition = not reducedMotion
		if _condition then
			local _exp_4 = { 0, 1, 2, 3, 4, 5, 6, 7 }
			local _newValue = table.create(#_exp_4)
			local _callback = function(index)
				return React.createElement("frame", {
					key = index,
					Size = flash:map(function(amount)
						return UDim2.fromOffset(5 + math.floor(amount * 6), 5 + math.floor(amount * 6))
					end),
					Position = orbit:map(function(turn)
						local angle = turn * math.pi * 2 + index * (math.pi / 4)
						local radius = 36 + math.sin(turn * math.pi * 2 + index) * 4
						return UDim2.new(0.5, math.floor(math.cos(angle) * radius), 0.5, math.floor(math.sin(angle) * 12))
					end),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = if index % 2 == 0 then Palette.mint else Palette.cyan,
					BackgroundTransparency = pulse:map(function(amount)
						return 0.08 + (1 - amount) * 0.5
					end),
					BorderSizePixel = 0,
					ZIndex = 4,
				}, React.createElement("uicorner", {
					CornerRadius = UDim.new(1, 0),
				}))
			end
			for _k, _v in _exp_4 do
				_newValue[_k] = _callback(_v, _k - 1, _exp_4)
			end
			_condition = _newValue
		end
		_result = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, _condition, React.createElement("frame", {
			Size = UDim2.new(0.62, 0, 1, -4),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Palette.ink,
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, React.createElement("uiscale", {
			Scale = flash:map(function(amount)
				return 1 + amount * 0.28
			end),
		}), React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 12),
		}), React.createElement("uistroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Round,
			Color = Palette.mint,
			Thickness = flash:map(function(amount)
				return 1.2 + amount * 2.4
			end),
			Transparency = pulse:map(function(amount)
				return 0.08 + (1 - amount) * 0.32
			end),
		}), React.createElement(ShimmerText, {
			value = "LIVE",
			size = if stack then 26 else 32,
			color = Palette.mint,
			weight = Enum.FontWeight.Heavy,
			align = Enum.TextXAlignment.Center,
			fit = true,
			minSize = 16,
			sizeConstraint = UDim2.fromScale(1, 1),
			enabled = not reducedMotion,
			periodSeconds = 1.6,
			reducedMotion = reducedMotion,
		})))
	else
		local _newValue = table.create(#values)
		local _callback = function(entry, index)
			return React.createElement("frame", {
				key = entry.label,
				Size = UDim2.new(0.25, -6, 1, 0),
				Position = UDim2.new(index * 0.25, if index == 0 then 0 else 6, 0, 0),
				BackgroundColor3 = Palette.ink,
				BackgroundTransparency = 0.04,
				BorderSizePixel = 0,
				ClipsDescendants = false,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 10),
			}), React.createElement("uigradient", {
				Color = surfaceGradient(Palette.ink, 0.8),
				Rotation = 90,
			}), React.createElement("uistroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				LineJoinMode = Enum.LineJoinMode.Round,
				Color = entry.color,
				Thickness = 1,
				Transparency = 0.42,
			}), React.createElement("frame", {
				Size = UDim2.new(0.42, 0, 0, 2),
				Position = UDim2.new(0.29, 0, 0, 0),
				BackgroundColor3 = entry.color,
				BorderSizePixel = 0,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(1, 0),
			})), React.createElement(NumberSpinnerHost, {
				value = entry.value,
				reducedMotion = reducedMotion,
				duration = 0.36,
				size = if stack then 20 else 24,
				color = entry.color,
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(0, 5),
				sizeConstraint = UDim2.new(1, 0, 0, 30),
			}), React.createElement(Text, {
				value = entry.label,
				size = 10,
				color = Palette.creamSoft,
				weight = Enum.FontWeight.Heavy,
				align = Enum.TextXAlignment.Center,
				fit = false,
				position = UDim2.new(0, 0, 1, -22),
				sizeConstraint = UDim2.new(1, 0, 0, 16),
			}))
		end
		for _k, _v in values do
			_newValue[_k] = _callback(_v, _k - 1, values)
		end
		_result = _newValue
	end
	return React.createElement(Panel, {
		layoutOrder = layoutOrder,
		size = UDim2.new(1, 0, 0, height),
		accent = accent,
		background = Palette.panelRaised,
		padding = 16,
		reducedMotion = reducedMotion,
		highlight = live,
		clips = false,
	}, _exp, _exp_1, _exp_2, _exp_3, React.createElement("frame", {
		Size = UDim2.new(1, -railLeft, 0, if railBelowCopy then 58 else 68),
		Position = UDim2.fromOffset(railLeft, railTop),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 3,
	}, _result))
end

local function Metric(_param)
	local label = _param.label
	local value = _param.value
	local detail = _param.detail
	local accent = _param.accent
	local size = _param.size
	if size == nil then
		size = UDim2.new(1, 0, 0, 92)
	end
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local reveal = _param.reveal
	local compact = _param.compact
	if compact == nil then
		compact = false
	end
	return React.createElement(Panel, {
		size = size,
		accent = accent,
		background = Palette.panelRaised,
		padding = if compact then 8 else 10,
		layoutOrder = layoutOrder,
		reveal = reveal,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Text, {
		value = label,
		size = 10,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		layoutOrder = 0,
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	}), React.createElement(Text, {
		value = value,
		size = if compact then 18 else 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		layoutOrder = 1,
		sizeConstraint = UDim2.new(1, 0, 0, if compact then 22 else 26),
	}), React.createElement(Text, {
		value = detail,
		size = 11,
		color = accent,
		weight = Enum.FontWeight.Bold,
		fit = true,
		layoutOrder = 2,
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	}))
end

local function listedFluxPerSec(machine): number
	local base = if type(machine) == "table" then machine.BaseProduction else nil
	if type(base) ~= "number" or base <= 0 then
		return 0
	end
	return base
end

local function firstRebirthStardust(config): number
	local economy = if config ~= nil and type(config.Economy) == "table" then config.Economy else nil
	local bag = if economy ~= nil and type(economy.Rebirth) == "table" then economy.Rebirth else nil
	local scale = if type(bag) == "table" and type(bag.StardustSqrtScale) == "number" then bag.StardustSqrtScale else 5
	local minimum = if type(bag) == "table" and type(bag.StardustMinimum) == "number" then bag.StardustMinimum else 4
	return math.max(minimum, math.floor(math.sqrt(1) * scale))
end

local function levelGoalLine(state): string?
	local levelState = state.Level
	local nextStep = if type(levelState) == "table" then levelState.Next else nil
	if type(nextStep) ~= "table" or type(nextStep.Text) ~= "string" then
		return nil
	end
	return `Level {nextStep.Level}: {nextStep.Text} · {compactNumber(nextStep.Progress)}/{compactNumber(nextStep.Target)}`
end

local function nextMachineGateLine(state, config): string?
	if config == nil or type(config.Machines) ~= "table" or type(state.Machines) ~= "table" then
		return nil
	end
	local names = {}
	for _, machine in config.Machines do
		if type(machine) == "table" and type(machine.Id) == "string" then
			names[machine.Id] = if type(machine.Name) == "string" then machine.Name else machine.Id
		end
	end
	for _, machine in config.Machines do
		if type(machine) ~= "table" or type(machine.PreviousId) ~= "string" then
			continue
		end
		local needLevel = if type(machine.PreviousLevel) == "number" then machine.PreviousLevel else 1
		local haveLevel = state.Machines[machine.PreviousId]
		if type(haveLevel) ~= "number" then
			haveLevel = 0
		end
		local rebirthsNeed = if type(machine.RequiredRebirths) == "number" then machine.RequiredRebirths else 0
		local zoneNeed = if type(machine.RequiredZone) == "number" then machine.RequiredZone else 1
		local rebirthsHave = math.max(0, math.floor(tonumber(state.Rebirths) or 0))
		local zoneHave = math.max(0, math.floor(tonumber(state.Zone) or 0))
		local machineName = if type(machine.Name) == "string" then machine.Name else machine.Id
		local rate = listedFluxPerSec(machine)
		local rateBit = if rate > 0 then ` +{compactNumber(rate)}/sec` else ""
		if rebirthsHave < rebirthsNeed then
			return `{machineName}{rateBit} · {rebirthsHave}/{rebirthsNeed} rebirths`
		elseif zoneHave < zoneNeed then
			return `{machineName}{rateBit} · world {zoneHave}/{zoneNeed}`
		elseif haveLevel < needLevel then
			local prevName = names[machine.PreviousId] or machine.PreviousId
			return `{machineName}{rateBit} · {prevName} {haveLevel}/{needLevel}`
		end
	end
	return nil
end

local function rebirthPayoutLine(state, config): string?
	if gteFlux(state.PrestigeReward, 1) then
		return nil
	end
	local economy = if config ~= nil then config.Economy else nil
	local target = if type(economy) == "table" and type(economy.PrestigeRequirement) == "number" then economy.PrestigeRequirement else 0
	if target <= 0 then
		return nil
	end
	local have = math.max(0, asFlux(state.RunCash)) + math.max(0, asFlux(state.Vault))
	if have >= target then
		return nil
	end
	local dust = firstRebirthStardust(config)
	return `1 core + {compactNumber(dust)} stardust · {compactNumber(have)}/{compactNumber(target)} flux`
end

local function progressLadder(state, config, limit: number): { string }
	local lines = {}
	local function push(line: string?)
		if line ~= nil and line ~= "" and #lines < limit then
			table.insert(lines, line)
		end
	end
	push(levelGoalLine(state))
	push(nextMachineGateLine(state, config))
	local unlocks = state.FeatureUnlocks
	local rebirthGate = if type(unlocks) == "table" then unlocks.Rebirth else nil
	if type(rebirthGate) == "table" and rebirthGate.Unlocked == true then
		push(rebirthPayoutLine(state, config))
	end
	return lines
end

-- puts the "Ready now" strip first when it is shown
-- With the Ready strip on screen, the "ops" card (claims across Missions, Lab, Forge Path) only
-- repeated it lower down, so it is left out.
local function withReady(entry, sections)
	if entry ~= nil then
		for index = #sections, 1, -1 do
			if sections[index].id == "ops" then
				table.remove(sections, index)
			end
		end
		table.insert(sections, 1, entry)
	end
	return sections
end
local function OverviewView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local effectsPaused = _param.effectsPaused
	local openWorkshop = _param.openWorkshop
	local openDomain = _param.openDomain
	local releaseAt = _param.releaseAt
	local navigate = _param.navigate
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local quietMotion = softMotion or effectsPaused or antilag.skipEntrance
	local stack = chrome.contentStack
	local phone = chrome.stack
	local canCollect = VaultCollectEligibility.isEligible(asFlux(state.Vault))
	local canRebirth = gteFlux(state.PrestigeReward, 1)
	local target = asFlux(state.NextPrestigeTarget)
	local progress = if canRebirth then 1 else meterFill(asFlux(state.RunCash), math.max(1, target))
	local vaultFill = meterFill(asFlux(state.Vault), asFlux(state.Capacity))
	local vaultFull = VaultCollectEligibility.isFull(vaultFill)
	local vaultNearFull = VaultCollectEligibility.isNearFull(vaultFill)
	local _condition = state.CapacitySeconds
	if _condition == nil then
		_condition = 0
	end
	local stellarLevel = state.Machines.StellarCore
	if stellarLevel == nil then
		stellarLevel = 0
	end
	local tutorialDone = false
	local flags = state.Flags
	if flags ~= nil and flags.TutorialDone == true then
		tutorialDone = true
	end
	local firstRun = (not tutorialDone) or stellarLevel < 1
	local showOvercharge = tutorialDone and stellarLevel >= 1
	local offlineHours = state.OfflineHours
	if type(offlineHours) ~= "number" then
		offlineHours = 0
	end
	offlineHours = math.floor(offlineHours + 0.5)
	local rebirthVisible = AppHelpers:featureUnlocked(state, "Rebirth")
	local domainVisible = AppHelpers:featureUnlocked(state, "Domain")
	local heroReveal = useStagger(0, quietMotion)
	local metricsReveal = useStagger(1, quietMotion)
	local rebirthReveal = useStagger(2, quietMotion)
	local domainReveal = useStagger(3, quietMotion)
	local notesReveal = useStagger(4, quietMotion)
	local opsReveal = useStagger(5, quietMotion)
	local collectTrigger, setCollectTrigger = React.useState(0)
	local collectFlash = useFlash(collectTrigger, reducedMotion, 0.42)
	local fireCollect = function()
		if not canCollect then
			return nil
		end
		setCollectTrigger(function(value)
			return value + 1
		end)
		return dispatch("CollectVault")
	end
	local missionsReady = PageReadyMath.CountReadyQuests(state.Quests)
	local labReady = PageReadyMath.CountReadyLabOrders(state.Lab)
	local pathReady = PageReadyMath.ForgePathReady(state, config)
	local opsClaims = PageReadyMath.OpsClaims(missionsReady, labReady, pathReady, false)
	local opsGuide = if config ~= nil and config.ClientPageGuides ~= nil then config.ClientPageGuides.Overview else nil
	local overchargeTrigger, setOverchargeTrigger = React.useState(0)
	local overchargeReadyAt, setOverchargeReadyAt = React.useState(0)
	local overchargeLeft, setOverchargeLeft = React.useState(0)
	local overchargeFlash = useFlash(overchargeTrigger, reducedMotion, 0.3)
	React.useEffect(function()
		if overchargeReadyAt <= 0 then
			setOverchargeLeft(0)
			return nil
		end
		local alive = true
		local worker = task.spawn(function()
			while alive do
				local left = math.max(0, overchargeReadyAt - os.clock())
				if not alive then
					break
				end
				setOverchargeLeft(math.ceil(left * 10) / 10)
				if left <= 0 then
					break
				end
				task.wait(math.max(0.016, left - (math.ceil(left * 10) - 1) / 10))
			end
		end)
		return function()
			alive = false
			pcall(function()
				task.cancel(worker)
			end)
		end
	end, { overchargeReadyAt })
	local fireOvercharge = function()
		if os.clock() < overchargeReadyAt then
			return nil
		end
		Audio:play("reactorPulse")
		setOverchargeTrigger(function(value)
			return value + 1
		end)
		setOverchargeReadyAt(os.clock() + 0.45)
		setOverchargeLeft(0.45)
		dispatch("Overcharge")
	end
	local overchargeLabel = if overchargeLeft > 0.02 then `WAIT {string.format("%.1f", overchargeLeft)}s` elseif state.TapPower ~= nil then `OVERCHARGE  +{compactNumber(state.TapPower)}` else "OVERCHARGE"
	local vaultClaimHostRef = React.useRef(nil)
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = vaultClaimHostRef.current
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
	end, { canCollect, overchargeLeft })
	local landscapePhone = phone and chrome.landscape
	local primaryIsBuy = (not canCollect) and stellarLevel < 1
	local primaryText = if primaryIsBuy then (if landscapePhone then "Buy machine" else "Buy a machine") else (if landscapePhone then "Collect" else "Collect stored Flux")
	local primaryClick = if primaryIsBuy then openWorkshop else fireCollect
	local primaryDisabled = if primaryIsBuy then false else not canCollect
	local primaryIcon = if primaryIsBuy then "Forge" else "Collect"
	local primaryColor = if primaryIsBuy then Palette.coral else Palette.green
	local primaryHighlight = if primaryIsBuy then true elseif canCollect then (firstRun or vaultFill >= 0.85) else false
	local comebackLine = `Earns for {offlineHours}h while you're away. Then collect.`
	local wideOverview = not stack and viewport.width >= 1180
	local ultraOverview = not stack and viewport.width >= 1680
	local countdownInPage = type(releaseAt) == "number" and releaseAt > (function()
		local ok, value = pcall(function()
			return game:GetService("Workspace"):GetServerTimeNow()
		end)
		if ok and type(value) == "number" then
			return value
		end
		return os.time()
	end)()
	local fitHeight = nil
	if chrome.short == true and not stack then
		local shellTop = 6 + chrome.topbarRows + chrome.panelGap
		local workspaceChrome = chrome.workspaceHeaderH + 32 + chrome.contentInset
		local bottom = chrome.bottomSafe + chrome.pagePadding + 12
		fitHeight = math.max(280, math.floor(viewport.height - shellTop - workspaceChrome - bottom))
	end
	local overviewPlan = LayoutSectionPlan.planOverview({
		stack = stack,
		phone = phone,
		landscapePhone = landscapePhone,
		wideOverview = wideOverview,
		ultraOverview = ultraOverview,
		rebirthVisible = rebirthVisible,
		domainVisible = domainVisible,
		countdownInPage = countdownInPage,
		short = chrome.short == true,
		chromePanelGap = chrome.panelGap,
		layoutPanelGap = Layout.panelGap,
		fitHeight = fitHeight,
	})
	local heroH = overviewPlan.heroH
	local rebirthH = overviewPlan.rebirthH
	local domainH = overviewPlan.domainH
	local notesH = overviewPlan.notesH
	local opsH = overviewPlan.opsH
	local metricCardH = overviewPlan.metricCardH
	local metricsH = overviewPlan.metricsH
	local countdownH = overviewPlan.countdownH
	local sectionGap = overviewPlan.sectionGap
	local topBandH = overviewPlan.topBandH
	local overviewTail = overviewPlan.overviewTail
	local columnMax = if stack then math.huge else Layout.contentMaxWidth
	local columnPad = if not stack and viewport.width >= Layout.contentMaxWidth + 80 then 12 else 0
	local denseHero = chrome.short == true and wideOverview and not phone
	local readoutRow = if denseHero then heroH - metricCardH - 8 else heroH
	local ctaH = if denseHero then 40 else TapTarget
	local heroReadoutH = if landscapePhone then 118 elseif phone then 168 else 0
	local phoneCtaBlockH = if landscapePhone then ctaH + 8 else ctaH * 2 + 12
	local opsButtonRows = if stack then 2 else 1
	local opsButtonH = TapTarget * opsButtonRows + (if stack then 8 else 0)
	local journey = JourneyMath.Build(state)
	local journeyNext = journey.Next
	local journeyRecent = {}
	for index = #journey.Done, math.max(1, #journey.Done - 2), -1 do
		table.insert(journeyRecent, journey.Done[index].Title)
	end
	local journalH = (if phone then 118 else 104) + (if stack then chrome.cardPadding * 2 else 32)
	local domain = state.Domain or {
		Rank = 0,
		Essence = 0,
		LastExpandedAt = 0,
		TotalRebirthsSpent = 0,
		TotalCoresSpent = 0,
		RequiredRebirths = 10,
		RequiredCores = 25,
		CanExpand = false,
		EssenceReward = 3,
		StardustReward = 250,
		ProductionMultiplier = 1,
		CapacityMultiplier = 1,
		OfflineBonus = 0,
		SkillPoints = 0,
		Nodes = {},
	}
	local readyList = ReadyBoard.collect(state, config)
	local readySection = if tutorialDone and navigate ~= nil then {
		id = "ready",
		height = if phone then 52 else 58,
		element = React.createElement(ReadyBoard.Strip, {
			list = readyList,
			compact = phone,
			pillHeight = if phone then 48 else 44,
			onOpen = navigate,
			onFind = function()
				require(script.Parent.Parent.QuickFind).open()
			end,
		}),
	} else nil
	local domainProgress = math.min(math.clamp(asFlux(state.Rebirths) / math.max(1, asFlux(domain.RequiredRebirths)), 0, 1), math.clamp(asFlux(state.Cores) / math.max(1, asFlux(domain.RequiredCores)), 0, 1))
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("frame", {
		Size = UDim2.new(1, -columnPad * 2, 1, 0),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uisizeconstraint", {
		MaxSize = Vector2.new(columnMax, math.huge),
	}), React.createElement(PageScaffold, {
		gap = sectionGap,
		tailPad = scrollTail(stack, chrome.bottomSafe, overviewTail),
		scrollBarColor = Palette.green,
		scrollBarThickness = 4,
		sections = withReady(readySection, {
			{
				id = "top",
				height = topBandH,
				element = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 0,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = if denseHero then Enum.FillDirection.Vertical elseif wideOverview then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, if denseHero then 8 elseif wideOverview then (if ultraOverview then 16 else 12) else sectionGap),
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}), React.createElement(Panel, {
		layoutOrder = 0,
		size = if denseHero then UDim2.new(1, 0, 0, readoutRow) elseif wideOverview then UDim2.new(0.62, -6, 1, 0) else UDim2.new(1, 0, 0, heroH),
		accent = if vaultFill >= 0.99 then Palette.mango else Palette.green,
		background = Palette.panelRaised,
		padding = if stack then chrome.cardPadding elseif denseHero then 10 elseif ultraOverview then 22 else 20,
		reveal = heroReveal,
		highlight = vaultFill >= 0.99 and not effectsPaused,
		reducedMotion = softMotion,
		clips = false,
	}, React.createElement("uigradient", {
		Color = surfaceGradient(if vaultFill >= 0.99 then Palette.mango else Palette.green, 0.94),
		Rotation = 62,
	}), not phone and React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 16),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
	}), React.createElement("frame", {
		Size = if phone then UDim2.new(1, 0, 0, heroReadoutH) else UDim2.new(0, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		LayoutOrder = 0,
		ZIndex = 2,
	}, React.createElement("uiflexitem", {
		FlexMode = Enum.UIFlexMode.Fill,
	}), React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, if landscapePhone or denseHero then 4 else 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 0,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}), React.createElement(Text, {
		value = if firstRun then "YOUR FORGE" else "CURRENT RUN",
		size = 11,
		color = if vaultFill >= 0.99 then Palette.mango else Palette.green,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		layoutOrder = 0,
		sizeConstraint = UDim2.new(0, if phone then 96 else 110, 1, 0),
	}), vaultFill >= 0.99 and React.createElement(Badge, {
		value = "FULL",
		accent = Palette.mango,
		size = UDim2.fromOffset(if phone then 56 else 62, 18),
		filled = false,
		layoutOrder = 1,
	})), React.createElement(Text, {
		value = compactNumber(state.Vault),
		size = if landscapePhone then 32 elseif stack then 38 else 46,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 22,
		layoutOrder = 1,
		sizeConstraint = UDim2.new(1, 0, 0, if landscapePhone or denseHero then 36 else 54),
	}), React.createElement(Text, {
		value = `Flux stored · vault holds {compactNumber(state.Capacity)}`,
		size = if stack then chrome.labelText else 12,
		color = Palette.creamSoft,
		wrap = true,
		layoutOrder = 2,
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	}), React.createElement(Meter, {
		value = vaultFill,
		rainbow = true,
		color = if vaultFill >= 0.99 then Palette.mango else Palette.green,
		reducedMotion = softMotion,
		shimmer = vaultFill >= 0.99 and not effectsPaused,
		layoutOrder = 3,
		size = UDim2.new(1, 0, 0, 10),
	}), React.createElement(Text, {
		value = if vaultFill >= 0.99 then "Vault full. Machines stop until you collect." elseif firstRun then "Machines earn Flux into this vault. Collect it, then buy more." else `{compactNumber(state.Production)} Flux per second flowing in`,
		size = if stack then chrome.labelText else 11,
		color = if vaultFill >= 0.99 then Palette.mango else Palette.muted,
		weight = Enum.FontWeight.Bold,
		wrap = true,
		layoutOrder = 4,
		sizeConstraint = UDim2.new(1, 0, 0, if landscapePhone then 22 elseif denseHero then 16 else 28),
	})), if phone then React.createElement("frame", {
		Name = "OverviewVaultClaimActions",
		ref = vaultClaimHostRef,
		Size = UDim2.new(1, 0, 0, phoneCtaBlockH),
		Position = UDim2.new(0, 0, 1, -(phoneCtaBlockH + 4)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = if landscapePhone and showOvercharge then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}), React.createElement(Button, {
		text = primaryText,
		icon = primaryIcon,
		onClick = primaryClick,
		color = primaryColor,
		textColor = Palette.ink,
		size = if landscapePhone and showOvercharge then UDim2.new(0.5, -4, 0, ctaH) else UDim2.new(1, 0, 0, ctaH),
		reducedMotion = reducedMotion,
		disabled = primaryDisabled,
		highlight = primaryHighlight,
	}), showOvercharge and React.createElement(Button, {
		text = overchargeLabel,
		icon = "Overcharge.3",
		onClick = fireOvercharge,
		sound = "reactorPulse",
		color = if overchargeLeft > 0.02 then Palette.panelSoft else Palette.mango,
		textColor = if overchargeLeft > 0.02 then Palette.muted else Palette.ink,
		size = if landscapePhone then UDim2.new(0.5, -4, 0, ctaH) else UDim2.new(1, 0, 0, ctaH),
		reducedMotion = reducedMotion,
		disabled = overchargeLeft > 0.02,
	}), (not showOvercharge and not landscapePhone) and React.createElement(Text, {
		value = comebackLine,
		size = if stack then chrome.labelText else 12,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		wrap = true,
		sizeConstraint = UDim2.new(1, 0, 0, ctaH),
	}), showOvercharge and not landscapePhone and React.createElement(Meter, {
		value = if overchargeLeft > 0 then 1 - overchargeLeft / 0.45 else 1,
		color = Palette.mango,
		reducedMotion = softMotion,
		position = UDim2.new(0, 0, 1, -4),
		size = UDim2.new(1, 0, 0, 4),
	}), React.createElement("frame", {
		Size = React.joinBindings({ collectFlash, overchargeFlash }):map(function(values)
			local amount = math.max(values[1], values[2])
			return UDim2.new(amount, 0, 0, 2)
		end),
		Position = UDim2.new(0.5, 0, 1, -2),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Palette.cream,
		BackgroundTransparency = React.joinBindings({ collectFlash, overchargeFlash }):map(function(values)
			return 1 - math.max(values[1], values[2])
		end),
		BorderSizePixel = 0,
		ZIndex = 8,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))) else React.createElement("frame", {
		Name = "OverviewVaultClaimActions",
		ref = vaultClaimHostRef,
		Size = if denseHero then UDim2.new(0, 250, 1, 0) else UDim2.fromOffset(230, 168),
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, if denseHero then 4 else Layout.controlGap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Button, {
		text = primaryText,
		icon = primaryIcon,
		onClick = primaryClick,
		color = primaryColor,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, ctaH),
		reducedMotion = reducedMotion,
		disabled = primaryDisabled,
		highlight = primaryHighlight,
	}), showOvercharge and React.createElement(Button, {
		text = overchargeLabel,
		icon = "Overcharge.4",
		onClick = fireOvercharge,
		sound = "reactorPulse",
		color = if overchargeLeft > 0.02 then Palette.panelSoft else Palette.mango,
		textColor = if overchargeLeft > 0.02 then Palette.muted else Palette.ink,
		size = UDim2.new(1, 0, 0, ctaH),
		reducedMotion = reducedMotion,
		disabled = overchargeLeft > 0.02,
	}), showOvercharge and React.createElement(Meter, {
		value = if overchargeLeft > 0 then 1 - overchargeLeft / 0.45 else 1,
		color = Palette.mango,
		reducedMotion = softMotion,
		size = UDim2.new(1, 0, 0, 4),
	}), React.createElement(Text, {
		value = if not showOvercharge then comebackLine elseif overchargeLeft > 0.02 then `Ready in {string.format("%.1f", overchargeLeft)}s` else "Tap for an instant burst of flux",
		size = 10,
		color = if overchargeLeft > 0.02 then Palette.mango else Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		wrap = not showOvercharge,
		sizeConstraint = UDim2.new(1, 0, 0, if showOvercharge then 16 else 32),
		align = Enum.TextXAlignment.Center,
	}), React.createElement("frame", {
		Size = collectFlash:map(function(amount)
			return UDim2.new(amount, 0, 0, 2)
		end),
		Position = UDim2.new(0.5, 0, 1, 0),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Palette.cream,
		BackgroundTransparency = collectFlash:map(function(amount)
			return 1 - amount
		end),
		BorderSizePixel = 0,
		ZIndex = 8,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))), React.createElement(Flex, {
		direction = if denseHero then "row" elseif wideOverview or stack then "column" else "row",
		wrap = false,
		justify = "fill",
		align = "stretch",
		gap = if stack then 10 elseif denseHero then 8 elseif ultraOverview then 12 elseif wideOverview then 8 else 12,
		size = if denseHero then UDim2.new(1, 0, 0, metricCardH) elseif wideOverview then UDim2.new(0.38, -6, 1, 0) else UDim2.new(1, 0, 0, metricsH),
		layoutOrder = 1,
		exact = true,
	}, React.createElement(FlexItem, {
		mode = "fill",
		minWidth = if stack then 160 else 160,
		minHeight = if stack then metricCardH elseif wideOverview then metricCardH else 72,
		layoutOrder = 0,
	}, React.createElement(Metric, {
		label = if firstRun then "Earning now" else "LIVE OUTPUT",
		value = `{compactNumber(state.Production)} / sec`,
		detail = if firstRun then `{compactNumber(state.RawProduction)} before bonuses` else `{compactNumber(state.RawProduction)} base`,
		accent = Palette.cyan,
		size = UDim2.fromScale(1, 1),
		compact = stack or denseHero,
		reveal = metricsReveal,
	})), React.createElement(FlexItem, {
		mode = "fill",
		minWidth = if stack then 160 else 180,
		minHeight = if stack then metricCardH elseif wideOverview then metricCardH else 72,
		layoutOrder = 1,
	}, React.createElement(Metric, {
		label = if firstRun then "Cash to spend" else "BANKED FLUX",
		value = compactNumber(state.Cash),
		detail = `{compactNumber(state.RunCash)} this run`,
		accent = Palette.mango,
		size = UDim2.fromScale(1, 1),
		compact = stack or denseHero,
		reveal = metricsReveal,
	})), React.createElement(FlexItem, {
		mode = "fill",
		minWidth = if stack then 160 else 180,
		minHeight = if stack then metricCardH elseif wideOverview then metricCardH else 72,
		layoutOrder = 2,
	}, React.createElement(Metric, {
		label = if firstRun then "Bonus that stays" else "LONG-TERM",
		value = `{compactNumber(state.PermanentMultiplier)}x`,
		detail = if firstRun then `{compactNumber(state.Rebirths)} rebirths` else `{compactNumber(state.Rebirths)} resets`,
		accent = Palette.violet,
		size = UDim2.fromScale(1, 1),
		compact = stack or denseHero,
		reveal = metricsReveal,
	})))),
			},
			{
				id = "notes",
				height = notesH,
				element = React.createElement(Panel, {
		layoutOrder = 2,
		size = UDim2.fromScale(1, 1),
		accent = Palette.cyan,
		background = Palette.panel,
		padding = if stack then chrome.cardPadding elseif ultraOverview then 20 else 18,
		reveal = notesReveal,
		clips = false,
	}, (function()
		local stellarRate = 0
		if config ~= nil and type(config.Machines) == "table" then
			for _, machine in config.Machines do
				if type(machine) == "table" and machine.Id == "StellarCore" then
					stellarRate = listedFluxPerSec(machine)
					break
				end
			end
		end
		local coreDust = firstRebirthStardust(config)
		local title = "Push toward rebirth"
		local fillLine = `Full bar pays 1 core + {compactNumber(coreDust)} stardust.`
		local body = `Filling this bar pays 1 core + {compactNumber(coreDust)} stardust. You keep earning for {offlineHours}h away.`
		local meter = progress
		local accent = Palette.cyan
		local cta = ""
		local ctaAction
		local statValue = `{math.floor(progress * 100 + 0.5)}%`
		local statLabel = "PAYS 1 CORE"
		if vaultFill >= 0.99 then
			title = "Collect stored Flux"
			body = "The vault is full, so machines stopped earning. Collect now, then buy another level."
			meter = 1
			accent = Palette.mango
			cta = "Collect stored Flux"
			ctaAction = function()
				return dispatch("CollectVault")
			end
			statValue = "FULL"
			statLabel = "VAULT"
		else
			local _condition_1 = state.Machines.StellarCore
			if _condition_1 == nil then
				_condition_1 = 0
			end
			if _condition_1 < 1 then
				if canCollect then
					title = "Collect stored Flux"
					body = if stellarRate > 0
						then `Collect this into cash, then buy Stellar Core (+{compactNumber(stellarRate)}/sec). You keep earning for {offlineHours}h while you're away.`
						else `Collect this into cash, then buy Stellar Core. You keep earning for {offlineHours}h while you're away.`
					fillLine = if stellarRate > 0
						then `Collect pays cash for Stellar Core (+{compactNumber(stellarRate)}/sec).`
						else "Collect pays cash for Stellar Core."
					meter = vaultFill
					accent = Palette.green
					cta = "Collect stored Flux"
					ctaAction = fireCollect
					statValue = compactNumber(state.Vault)
					statLabel = "INTO CASH"
				else
					title = "Buy a machine"
					body = if stellarRate > 0
						then `Stellar Core earns {compactNumber(stellarRate)} Flux/sec into this vault once you buy it. You keep earning for {offlineHours}h while you're away.`
						else `Stellar Core earns Flux into this vault every second. You keep earning for {offlineHours}h while you're away.`
					fillLine = if stellarRate > 0
						then `Buying Stellar Core starts {compactNumber(stellarRate)} Flux/sec.`
						else "Buying Stellar Core starts Flux every second."
					meter = 0.08
					cta = "Buy a machine"
					ctaAction = openWorkshop
					statValue = if stellarRate > 0 then `+{compactNumber(stellarRate)}` else "0"
					statLabel = if stellarRate > 0 then "FLUX/SEC" else "MACHINES"
				end
			else
				local _condition_2 = state.Research.Efficiency
				if _condition_2 == nil then
					_condition_2 = 0
				end
				if _condition_2 < 3 then
					title = "Buy Efficiency to 3"
					body = "When this bar fills, Storage unlocks. Efficiency stays after rebirth."
					fillLine = "Full bar unlocks Storage."
					local _condition_3 = state.Research.Efficiency
					if _condition_3 == nil then
						_condition_3 = 0
					end
					meter = math.clamp(_condition_3 / 3, 0, 1)
					cta = "Open Research"
					ctaAction = function()
						local _result = navigate
						if _result ~= nil then
							_result = _result("Research")
						end
						return _result
					end
					local _condition_4 = state.Research.Efficiency
					if _condition_4 == nil then
						_condition_4 = 0
					end
					statValue = `{_condition_4}/3`
					statLabel = "UNLOCKS STORAGE"
				else
					local _condition_3 = state.Research.Storage
					if _condition_3 == nil then
						_condition_3 = 0
					end
					if _condition_3 < 3 then
						title = "Buy Storage to 3"
						body = "When this bar fills, the offline relay unlocks. Storage lets the vault hold more."
						fillLine = "Full bar unlocks the offline relay."
						local _condition_4 = state.Research.Storage
						if _condition_4 == nil then
							_condition_4 = 0
						end
						meter = math.clamp(_condition_4 / 3, 0, 1)
						cta = "Open Research"
						ctaAction = function()
							local _result = navigate
							if _result ~= nil then
								_result = _result("Research")
							end
							return _result
						end
						local _condition_5 = state.Research.Storage
						if _condition_5 == nil then
							_condition_5 = 0
						end
						statValue = `{_condition_5}/3`
						statLabel = "UNLOCKS RELAY"
					else
						local _condition_4 = state.Research.Offline
						if _condition_4 == nil then
							_condition_4 = 0
						end
						if _condition_4 < 1 then
							title = "Buy the offline relay"
							body = "When you buy this, Deep-Space Relay pays you for longer while you're away."
							fillLine = "This buy pays you longer while you're away."
							meter = 0.15
							cta = "Open Research"
							ctaAction = function()
								local _result = navigate
								if _result ~= nil then
									_result = _result("Research")
								end
								return _result
							end
							statValue = "NEXT"
							statLabel = "LONGER AFK"
						else
							local _condition_5 = state.Research.Overcharge
							if _condition_5 == nil then
								_condition_5 = 0
							end
							if _condition_5 < 1 then
								title = "Buy the tap bonus"
								body = "When you buy this, Overcharge Coil makes the tap button stronger."
								fillLine = "This buy makes taps stronger."
								meter = 0.2
								cta = "Open Research"
								ctaAction = function()
									local _result = navigate
									if _result ~= nil then
										_result = _result("Research")
									end
									return _result
								end
								statValue = "NEXT"
								statLabel = "STRONGER TAPS"
							elseif canRebirth then
								title = "Rebirth for Cores"
								body = `Reset this run's machines and keep Research. Collect {compactNumber(state.PrestigeReward)} Cores from the panel below.`
								fillLine = `Collect {compactNumber(state.PrestigeReward)} cores below.`
								meter = 1
								accent = Palette.pink
								statValue = `+{compactNumber(state.PrestigeReward)}`
								statLabel = "CORES READY"
							elseif progress < 0.45 then
								title = "Buy more machines"
								body = `Buy machines and collect often. Filling this bar pays 1 core + {compactNumber(coreDust)} stardust.`
								fillLine = `Full bar pays 1 core + {compactNumber(coreDust)} stardust.`
								cta = "Buy a machine"
								ctaAction = openWorkshop
								statValue = `{math.floor(progress * 100 + 0.5)}%`
								statLabel = "PAYS 1 CORE"
							end
						end
					end
				end
			end
		end
		local adaptiveGoal = if vaultFill < 0.99 then overviewGoal(state, { missions = missionsReady, lab = labReady, path = pathReady }) else nil
		if adaptiveGoal then
			title, body, fillLine = adaptiveGoal.title, adaptiveGoal.body, ""
			meter, statValue, statLabel = adaptiveGoal.progress, adaptiveGoal.value, adaptiveGoal.label
			cta, ctaAction = adaptiveGoal.cta or "", nil
			if adaptiveGoal.page == "Domain" then ctaAction = openDomain
			elseif adaptiveGoal.page and navigate then ctaAction = function() navigate(adaptiveGoal.page) end end
		end
		local meterTop = if stack then notesH - (if cta ~= "" then TapTarget + 28 else 28) else notesH - 52
		local bodyRoom = math.max(16, meterTop - 52 - 6)
		local ladderSlots = math.clamp(math.floor(bodyRoom / 13), 1, 3)
		local ladder = if vaultFill >= 0.99 or adaptiveGoal then {} else progressLadder(state, config, ladderSlots)
		if #ladder > 0 then
			local keep = {}
			local limit = if fillLine ~= "" then math.max(0, ladderSlots - 1) else ladderSlots
			for index = 1, math.min(limit, #ladder) do
				keep[index] = ladder[index]
			end
			if fillLine ~= "" and #keep > 0 then
				body = fillLine .. "\n" .. table.concat(keep, "\n")
			elseif fillLine ~= "" then
				body = fillLine
			else
				body = table.concat(ladder, "\n")
			end
		end
		local copyLeft = if stack then 0 else 48
		local copyWidth = if stack then 0 else -220
		local action = ctaAction
		local showCta = not stack and cta ~= "" and action ~= nil
		return React.createElement(React.Fragment, nil, not stack and React.createElement(IconTile, {
			kind = "Milestone",
			accent = accent,
			size = 34,
			radius = 10,
			position = UDim2.fromOffset(0, 0),
			spin = false,
			reducedMotion = quietMotion,
		}), React.createElement(Text, {
			value = "NEXT GOAL",
			size = 10,
			color = accent,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			position = UDim2.fromOffset(copyLeft, if stack then 0 else 2),
			sizeConstraint = UDim2.new(1, copyWidth - copyLeft, 0, 16),
		}), React.createElement(Text, {
			value = title,
			size = if stack then 19 else 20,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			minSize = 14,
			position = UDim2.fromOffset(copyLeft, 22),
			sizeConstraint = UDim2.new(1, copyWidth - copyLeft, 0, 28),
		}), React.createElement(Text, {
			value = body,
			size = if #ladder > 0 then 11 elseif stack then chrome.labelText else 12,
			color = Palette.creamSoft,
			wrap = true,
			position = UDim2.fromOffset(copyLeft, 52),
			sizeConstraint = UDim2.new(1, copyWidth - copyLeft, 0, if #ladder > 0 then bodyRoom else (if stack then 48 else 36)),
		}), React.createElement(Meter, {
			value = meter,
			color = accent,
			reducedMotion = softMotion,
			shimmer = meter >= 0.99 and not effectsPaused,
			position = UDim2.fromOffset(copyLeft, if stack then notesH - (if cta ~= "" then TapTarget + 28 else 28) else notesH - 52),
			size = UDim2.new(1, copyWidth - copyLeft, 0, 8),
		}), not stack and React.createElement("frame", {
			Size = UDim2.fromOffset(196, 112),
			Position = UDim2.new(1, -196, 0.5, -56),
			BackgroundColor3 = Palette.ink,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 12),
		}), React.createElement("uistroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Round,
			Color = accent,
			Thickness = 1,
			Transparency = 0.55,
		}), React.createElement(Text, {
			value = statValue,
			size = 22,
			color = accent,
			weight = Enum.FontWeight.Heavy,
			align = Enum.TextXAlignment.Center,
			fit = true,
			minSize = 14,
			position = UDim2.fromOffset(8, if showCta then 8 else 24),
			sizeConstraint = UDim2.new(1, -16, 0, 32),
		}), React.createElement(Text, {
			value = statLabel,
			size = 10,
			color = Palette.creamSoft,
			weight = Enum.FontWeight.Heavy,
			align = Enum.TextXAlignment.Center,
			fit = false,
			position = UDim2.fromOffset(8, if showCta then 40 else 58),
			sizeConstraint = UDim2.new(1, -16, 0, 16),
		}), showCta and action ~= nil and React.createElement(Button, {
			text = cta,
			onClick = action,
			color = accent,
			textColor = Palette.ink,
			size = UDim2.new(1, -16, 0, 36),
			position = UDim2.fromOffset(8, 64),
			reducedMotion = softMotion,
			highlight = meter >= 0.99,
		})), stack and cta ~= "" and action ~= nil and React.createElement(Button, {
			text = cta,
			onClick = action,
			color = accent,
			textColor = Palette.ink,
			size = UDim2.new(1, 0, 0, TapTarget),
			position = UDim2.new(0, 0, 1, -TapTarget),
			reducedMotion = softMotion,
			highlight = meter >= 0.99,
		}))
	end)()),
			},
			{
				id = "ops",
				height = opsH,
				element = React.createElement(Panel, {
		layoutOrder = 3,
		size = UDim2.fromScale(1, 1),
		accent = if opsClaims > 0 then Palette.green else Palette.cyan,
		background = Palette.panel,
		padding = if stack then chrome.cardPadding else 16,
		reveal = opsReveal,
		highlight = opsClaims > 0 and not effectsPaused,
		reducedMotion = softMotion,
		clips = false,
	}, React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, -(opsButtonH + 8)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement(Text, {
		value = if firstRun and opsClaims == 0 then "Rewards later" else ((opsGuide and opsGuide.OpsTitle) or "OPS PULSE"),
		size = 10,
		color = if opsClaims > 0 then Palette.green else Palette.cyan,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Text, {
		value = if opsClaims > 0 then `{opsClaims} ready to claim` else ((opsGuide and opsGuide.EmptyClaims) or "Nothing to claim yet. Keep forging."),
		size = if stack then 17 else 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(0, 18),
		sizeConstraint = UDim2.new(1, 0, 0, 24),
	}), React.createElement(Text, {
		value = if firstRun and opsClaims == 0 then "Missions and other rewards unlock as you earn Flux. Do the highlighted step above first." else ((opsGuide and opsGuide.OpsBody) or "Claims waiting across Missions, Lab, Forge Path, and Anomaly."),
		size = if stack then chrome.labelText else 11,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 46),
		sizeConstraint = UDim2.new(1, 0, 0, 28),
	})), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, opsButtonH),
		Position = UDim2.new(0, 0, 1, -opsButtonH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
		VerticalFlex = Enum.UIFlexAlignment.Fill,
		Wraps = stack,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Button, {
		text = if missionsReady > 0 then `MISSIONS · {missionsReady}` else "MISSIONS",
		icon = "Mission.2",
		onClick = function()
			local _result = navigate
			if _result ~= nil then
				_result = _result("Missions")
			end
			return _result
		end,
		color = if missionsReady > 0 then Palette.cyan else Palette.panelSoft,
		textColor = if missionsReady > 0 then Palette.ink else Palette.creamSoft,
		size = if stack then UDim2.new(0.5, -4, 0, TapTarget) else UDim2.new(0.25, -6, 0, TapTarget),
		reducedMotion = reducedMotion,
		highlight = missionsReady > 0,
		layoutOrder = 0,
	}), React.createElement(Button, {
		text = if labReady > 0 then `LAB · {labReady}` else "LAB",
		icon = "Lab.3",
		onClick = function()
			local _result = navigate
			if _result ~= nil then
				_result = _result("Lab")
			end
			return _result
		end,
		color = if labReady > 0 then Palette.mint else Palette.panelSoft,
		textColor = if labReady > 0 then Palette.ink else Palette.creamSoft,
		size = if stack then UDim2.new(0.5, -4, 0, TapTarget) else UDim2.new(0.25, -6, 0, TapTarget),
		reducedMotion = reducedMotion,
		highlight = labReady > 0,
		layoutOrder = 1,
	}), React.createElement(Button, {
		text = if pathReady then "FORGE PATH · READY" else "FORGE PATH",
		icon = "Forge.6",
		onClick = function()
			local _result = navigate
			if _result ~= nil then
				_result = _result("ForgePath")
			end
			return _result
		end,
		color = if pathReady then Palette.violet else Palette.panelSoft,
		textColor = if pathReady then Palette.ink else Palette.creamSoft,
		size = if stack then UDim2.new(0.5, -4, 0, TapTarget) else UDim2.new(0.25, -6, 0, TapTarget),
		reducedMotion = reducedMotion,
		highlight = pathReady,
		layoutOrder = 2,
	}), React.createElement(Button, {
		text = "BLACK MARKET",
		icon = "Shop.3",
		onClick = function()
			local _result = navigate
			if _result ~= nil then
				_result = _result("Bazaar")
			end
			return _result
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		size = if stack then UDim2.new(0.5, -4, 0, TapTarget) else UDim2.new(0.25, -6, 0, TapTarget),
		reducedMotion = reducedMotion,
		highlight = false,
		layoutOrder = 3,
	}))),
			},
			{
				id = "countdown",
				height = if countdownInPage then countdownH else 0,
				element = if countdownInPage then React.createElement(ReleaseCountdown, {
					releaseAt = releaseAt,
					reducedMotion = reducedMotion,
					stack = stack,
					layoutOrder = 6,
				}) else React.createElement("frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}),
			},
			{
				id = "rebirth",
				height = if rebirthVisible then rebirthH else 0,
				element = if rebirthVisible then React.createElement(RebirthPanel, {
					state = state,
					config = config,
					dispatch = dispatch,
					reducedMotion = reducedMotion,
					effectsPaused = effectsPaused,
					height = rebirthH,
					reveal = rebirthReveal,
					openWorkshop = openWorkshop,
					layoutOrder = 4,
				}) else React.createElement("frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}),
			},
			{
				id = "domain",
				height = if domainVisible then domainH else 0,
				element = if domainVisible then React.createElement(Panel, {
		layoutOrder = 5,
		size = UDim2.fromScale(1, 1),
		accent = Palette.pink,
		background = darken(Palette.violet, 0.9),
		padding = if stack then chrome.cardPadding else 18,
		reveal = domainReveal,
		highlight = domain.CanExpand and not effectsPaused,
		reducedMotion = softMotion,
		clips = false,
	}, React.createElement("uigradient", {
		Color = surfaceGradient(Palette.violet, 0.88),
		Rotation = 62,
	}), React.createElement(IconTile, {
		kind = "World",
		accent = if domain.CanExpand then Palette.pink else Palette.violet,
		size = if phone then 54 else 62,
		radius = 16,
		position = UDim2.fromOffset(0, if phone then 4 else 18),
		glow = domain.CanExpand and not effectsPaused,
		spin = domain.CanExpand and not effectsPaused,
		reducedMotion = softMotion,
	}), React.createElement("frame", {
		Size = if phone then UDim2.new(1, -68, 0, 132) else UDim2.new(1, -290, 1, 0),
		Position = UDim2.fromOffset(if phone then 66 else 80, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement(Text, {
		value = `DOMAIN RANK {domain.Rank}`,
		size = 10,
		color = Palette.pink,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Text, {
		value = if domain.CanExpand then `Domain rank {domain.Rank + 1} is ready`
			elseif asFlux(state.Rebirths) < asFlux(domain.RequiredRebirths) then `{compactNumber(math.max(1, asFlux(domain.RequiredRebirths) - asFlux(state.Rebirths)))} more rebirths to Domain rank {domain.Rank + 1}`
			else `More astral cores for Domain rank {domain.Rank + 1}`,
		size = if phone then 20 else 23,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		wrap = true,
		fit = false,
		position = UDim2.fromOffset(0, 22),
		sizeConstraint = UDim2.new(1, 0, 0, 34),
	}), React.createElement(Text, {
		value = "Costs rebirths and cores. This run's machines and worlds reset. Research, relics, and Stardust stay.",
		size = if phone then chrome.labelText else 11,
		color = Palette.creamSoft,
		wrap = true,
		fit = false,
		position = UDim2.fromOffset(0, 60),
		sizeConstraint = UDim2.new(1, 0, 0, if phone then 58 else 44),
	}), not phone and React.createElement(Text, {
		value = `Permanent: {compactNumber(domain.ProductionMultiplier)}x production  /  {compactNumber(domain.CapacityMultiplier)}x vault time  /  +{math.floor(domain.OfflineBonus * 100 + 0.5)}% offline`,
		size = 10,
		color = Palette.cyan,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, 112),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	})), if phone then React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 186),
		Position = UDim2.new(0, 0, 1, -190),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement(Text, {
		value = `{compactNumber(state.Rebirths)} / {compactNumber(domain.RequiredRebirths)} rebirths`,
		size = chrome.labelText,
		color = if state.Rebirths >= domain.RequiredRebirths then Palette.green else Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Text, {
		value = `{compactNumber(state.Cores)} / {compactNumber(domain.RequiredCores)} astral cores`,
		size = chrome.labelText,
		color = if state.Cores >= domain.RequiredCores then Palette.green else Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, 18),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Meter, {
		value = domainProgress,
		rainbow = true,
		color = Palette.pink,
		reducedMotion = quietMotion,
		shimmer = domain.CanExpand and not effectsPaused,
		position = UDim2.fromOffset(0, 40),
		size = UDim2.new(1, 0, 0, 8),
	}), React.createElement(Text, {
		value = `Next: +{domain.EssenceReward} essence  ·  +{compactNumber(domain.StardustReward)} stardust`,
		size = chrome.labelText,
		color = Palette.mango,
		weight = Enum.FontWeight.Bold,
		wrap = true,
		fit = false,
		position = UDim2.fromOffset(0, 54),
		sizeConstraint = UDim2.new(1, 0, 0, 28),
	}), React.createElement(Button, {
		text = if domain.CanExpand then "OPEN DOMAIN GATE" else "VIEW DOMAIN",
		icon = "Domain.2",
		onClick = openDomain,
		color = if domain.CanExpand then Palette.pink else Palette.panelSoft,
		textColor = if domain.CanExpand then Palette.ink else Palette.cream,
		outline = not domain.CanExpand,
		size = UDim2.new(1, 0, 0, ctaH),
		position = UDim2.new(0, 0, 1, -ctaH),
		reducedMotion = reducedMotion,
		highlight = domain.CanExpand,
	})) else React.createElement("frame", {
		Size = UDim2.fromOffset(270, 188),
		Position = UDim2.new(1, -270, 0, 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement(Badge, {
		value = `{compactNumber(domain.Essence)} DOMAIN ESSENCE`,
		accent = Palette.pink,
		filled = true,
		position = UDim2.fromOffset(0, 0),
		size = UDim2.new(1, 0, 0, 26),
	}), React.createElement(Text, {
		value = `{compactNumber(state.Rebirths)} / {compactNumber(domain.RequiredRebirths)} rebirths`,
		size = 10,
		color = if state.Rebirths >= domain.RequiredRebirths then Palette.green else Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, 34),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Text, {
		value = `{compactNumber(state.Cores)} / {compactNumber(domain.RequiredCores)} astral cores`,
		size = 10,
		color = if state.Cores >= domain.RequiredCores then Palette.green else Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, 52),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Meter, {
		value = domainProgress,
		rainbow = true,
		color = Palette.pink,
		reducedMotion = quietMotion,
		shimmer = domain.CanExpand and not effectsPaused,
		position = UDim2.fromOffset(0, 74),
		size = UDim2.new(1, 0, 0, 8),
	}), React.createElement(Button, {
		text = if domain.CanExpand then "OPEN DOMAIN GATE" else "VIEW REQUIREMENTS",
		icon = "Domain.3",
		onClick = openDomain,
		color = if domain.CanExpand then Palette.pink else Palette.panelSoft,
		textColor = if domain.CanExpand then Palette.ink else Palette.cream,
		outline = not domain.CanExpand,
		size = UDim2.new(1, 0, 0, ctaH),
		position = UDim2.fromOffset(0, 96),
		reducedMotion = reducedMotion,
		highlight = domain.CanExpand,
	}))) else React.createElement("frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}),
			},
			{
				id = "journal",
				height = journalH,
				element = React.createElement(Panel, {
					layoutOrder = 7,
					size = UDim2.fromScale(1, 1),
					accent = Palette.mango,
					background = Palette.panelRaised,
					padding = if stack then chrome.cardPadding else 16,
					reducedMotion = softMotion,
					clips = true,
				}, React.createElement(Text, {
					value = `FORGE JOURNAL  ·  {journey.Count} / {journey.Total} CHAPTERS`,
					size = 10,
					color = Palette.mango,
					weight = Enum.FontWeight.Heavy,
					fit = false,
					sizeConstraint = UDim2.new(1, 0, 0, 16),
				}), React.createElement(Text, {
					value = if journeyNext then `Next: {journeyNext.Title}` else "Every chapter written.",
					size = if phone then 17 else 19,
					color = Palette.cream,
					weight = Enum.FontWeight.Heavy,
					fit = false,
					position = UDim2.fromOffset(0, 20),
					sizeConstraint = UDim2.new(1, 0, 0, 26),
				}), React.createElement(Text, {
					value = if journeyNext
						then `{journeyNext.Line}  {compactNumber(journeyNext.Have)} / {compactNumber(journeyNext.Target)} {journeyNext.Unit}`
						else "The forge remembers everything you've done here.",
					size = chrome.labelText,
					color = Palette.creamSoft,
					fit = false,
					wrap = phone,
					position = UDim2.fromOffset(0, 48),
					sizeConstraint = UDim2.new(1, 0, 0, if phone then 32 else 16),
				}), React.createElement(Meter, {
					value = if journeyNext then journeyNext.Progress else 1,
					color = Palette.mango,
					reducedMotion = quietMotion,
					shimmer = false,
					position = UDim2.fromOffset(0, if phone then 84 else 70),
					size = UDim2.new(1, 0, 0, 6),
				}), React.createElement(Text, {
					value = if #journeyRecent > 0 then `Written: {table.concat(journeyRecent, "  ·  ")}` else "Written: nothing yet. Buy a machine to start.",
					size = chrome.labelText,
					color = Palette.muted,
					weight = Enum.FontWeight.Bold,
					fit = false,
					position = UDim2.fromOffset(0, if phone then 96 else 82),
					sizeConstraint = UDim2.new(1, 0, 0, 16),
				})),
			},
			{
				-- this session, live
				id = "session",
				height = require(script.Parent.Parent.SessionStats).height(if phone then 2 else 4) + 56,
				element = React.createElement(Panel, {
					layoutOrder = 8,
					size = UDim2.fromScale(1, 1),
					accent = Palette.cyan,
					background = Palette.panelRaised,
					padding = if stack then chrome.cardPadding else 16,
					reducedMotion = softMotion,
					clips = true,
				}, React.createElement(Text, {
					value = "THIS SESSION",
					size = 10,
					color = Palette.cyan,
					weight = Enum.FontWeight.Heavy,
					fit = false,
					sizeConstraint = UDim2.new(1, 0, 0, 16),
				}), React.createElement(require(script.Parent.Parent.SessionStats).Card, {
					columns = if phone then 2 else 4,
					position = UDim2.fromOffset(0, 24),
					reducedMotion = softMotion,
				})),
			},
		}),
	})))
end

return {
	OverviewView = OverviewView,
}
end

__defs["RebirthPanel"] = function()
-- The rebirth card on the overview, and the chamber it opens. The card is the run at a glance: how
-- far the flux has come, the run clock, the vow you swore and what a rebirth pays right now. The
-- chamber is where a run ends: the payout and its grade, the vow for the next run, keepsakes,
-- stars waiting to be lit, the run log, and the two-step ignition. The rules are RebirthMath's,
-- and the payout is the server's own quote, so the numbers here are the numbers you get.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReactRoblox = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["react-roblox"])
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local _format = require(script.Parent.Parent.CoreKit)("format")
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local InteractionFeedback = require(script.Parent.Parent.CoreKit)("interaction").InteractionFeedback
local Icon = require(script.Parent.Parent.ArtKit)("Icon").Icon
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useFlash = _motion.useFlash
local usePulse = _motion.usePulse
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local darken = _theme.darken
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local IconTile = _ui.IconTile
local Meter = _ui.Meter
local Panel = _ui.Panel
local Text = _ui.Text
local meterFill = _ui.meterFill
local acquireDropdownPortal = _ui.acquireDropdownPortal
local releaseDropdownPortal = _ui.releaseDropdownPortal
local RebirthMath = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("RebirthMath"))
local Tooltip = require(script.Parent.Parent.Tooltip)
local h = React.createElement

local VOW_ART = {
	[""] = { icon = "Hide.rebirthVowNone", color = Palette.muted, name = "No vow", line = "Run however you like." },
	Swift = { icon = "Timer.rebirthVowSwift", color = Palette.cyan },
	Lean = { icon = "Grid.rebirthVowLean", color = Palette.mint },
	Homebound = { icon = "World.rebirthVowHomebound", color = Palette.mango },
	Overflow = { icon = "Vault.rebirthVowOverflow", color = Palette.violet },
}
local PERK_ART = {
	HeadStart = { icon = "Core.rebirthStarHeadStart", color = Palette.cyan },
	StartCash = { icon = "Flux.rebirthStarSeed", color = Palette.mango },
	CoreYield = { icon = "Production.rebirthStarCores", color = Palette.violet },
	DustYield = { icon = "Dust.rebirthStarDust", color = Palette.cream },
	VowPower = { icon = "Lock.rebirthStarVow", color = Palette.coral },
	KeepShare = { icon = "Loadout.rebirthStarKeep", color = Palette.mint },
	VaultCarry = { icon = "Ember.rebirthStarPurse", color = Palette.mango },
}
-- art chosen in code: the card's dial, its vow line, and keepsakes (only first-world machines)
local REBIRTH_ICONS = {
	Dial = "Rebirth.rebirthDial",
	PanelVowNone = "Hide.rebirthPanelVowNone",
	PanelVowSwift = "Timer.rebirthPanelVowSwift",
	PanelVowLean = "Grid.rebirthPanelVowLean",
	PanelVowHomebound = "World.rebirthPanelVowHomebound",
	PanelVowOverflow = "Vault.rebirthPanelVowOverflow",
	KeepStellarCore = "Core.rebirthKeepStellar",
	KeepLunarExtractor = "Production.rebirthKeepLunar",
	KeepPrismRefinery = "Forge.rebirthKeepPrism",
	KeepOther = "Loadout.rebirthKeepOther",
}
local GRADE_COLOR = { S = Palette.mango, A = Palette.mint, B = Palette.cyan, C = Palette.muted }
local GRADE_LINE = {
	S = "A new best, with the vow kept.",
	A = "A new best or a kept vow.",
	B = "At least half your best run.",
	C = "Under half your best run.",
}

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, seconds % 60)
	end
	return string.format("%d:%02d", minutes, seconds % 60)
end

-- the server's rebirth snapshot, or a quiet empty one before the first state arrives
local function rebirthOf(state)
	local info = state.Rebirth
	if type(info) == "table" then
		return info
	end
	return {
		Ready = false, Cores = 0, Stardust = 0, Grade = "C", Vow = "", VowHolds = false, VowStatus = "",
		VowOpen = false, KeptVows = {}, RunStartedAt = state.ServerTime or 0, Lifetime = tonumber(state.Rebirths) or 0,
		Stars = {}, Pending = {}, Keep = {}, KeepSlots = 0, Runs = {}, BestCores = 0, FastestSeconds = 0,
	}
end

local function vowName(id: string): string
	local vow = RebirthMath.vow(id)
	return if vow then vow.Name else VOW_ART[""].name
end

-- the run clock ticks on the client between state pushes
local function useRunClock(startedAt: number, serverTime: number?)
	local offset = React.useMemo(function()
		return (tonumber(serverTime) or os.time()) - os.time()
	end, { serverTime })
	local seconds, setSeconds = React.useState(0)
	React.useEffect(function()
		local alive = true
		local job = task.spawn(function()
			while alive do
				setSeconds(os.time() + offset - startedAt)
				task.wait(1)
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, job)
		end
	end, { startedAt, offset })
	return seconds
end

local function featuresOpeningOnNextRebirth(config, nextCount: number): string
	local unlocks = if config ~= nil and type(config.Unlocks) == "table" then config.Unlocks else nil
	if unlocks == nil then
		return ""
	end
	local names = {}
	for _, rule in unlocks do
		if type(rule) == "table" and rule.Kind == "Rebirths" and rule.Target == nextCount and type(rule.Name) == "string" then
			table.insert(names, rule.Name)
		end
	end
	table.sort(names)
	return table.concat(names, ", ")
end

local function rebirthGate(config, rebirths: number)
	local bestName = ""
	local bestNeed = math.huge
	local lastNeed = 0
	local function consider(list)
		if type(list) ~= "table" then
			return
		end
		for _, entry in list do
			if type(entry) == "table" and type(entry.Name) == "string" then
				local need = if type(entry.RequiredRebirths) == "number" then entry.RequiredRebirths else 0
				if need > rebirths and need < bestNeed then
					bestNeed = need
					bestName = entry.Name
				elseif need <= rebirths and need > lastNeed then
					lastNeed = need
				end
			end
		end
	end
	if config ~= nil then
		consider(config.Machines)
		consider(config.Zones)
	end
	if bestName == "" then
		return nil
	end
	return { name = bestName, need = bestNeed, last = lastNeed }
end

local DIAL_DOTS = 18

-- ring of dots around the rebirth glyph; fills with run progress, then with the ignition charge
local function ChargeDial(props)
	local size = props.size
	local radius = size * 0.5 - 4
	local children = {}
	for i = 1, DIAL_DOTS do
		local angle = -math.pi / 2 + (i - 1) / DIAL_DOTS * math.pi * 2
		local threshold = (i - 0.5) / DIAL_DOTS
		children["d" .. i] = h("frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.cos(angle) * radius, 0.5, math.sin(angle) * radius),
			Size = props.fill:map(function(amount)
				return if amount >= threshold then UDim2.fromOffset(5, 5) else UDim2.fromOffset(3, 3)
			end),
			BorderSizePixel = 0,
			BackgroundColor3 = props.fill:map(function(amount)
				return if amount >= threshold then props.accent else Palette.panelSoft
			end),
			BackgroundTransparency = props.fill:map(function(amount)
				return if amount >= threshold then 0 else 0.4
			end),
			ZIndex = props.zIndex,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))
	end
	return h("frame", {
		Name = "ChargeDial",
		Size = UDim2.fromOffset(size, size),
		Position = props.position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = props.zIndex,
	}, children, h("frame", {
		Name = "ChargeHalo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = props.charge:map(function(amount)
			return UDim2.fromOffset(size - 6 + amount * 8, size - 6 + amount * 8)
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = props.zIndex,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
		Color = props.accent,
		Thickness = 2,
		Transparency = props.charge:map(function(amount)
			return 1 - amount * 0.8
		end),
	})), props.children)
end

-- a titled block inside the chamber
local function Section(props)
	return h("frame", {
		Name = props.name,
		LayoutOrder = props.order,
		Size = UDim2.new(1, 0, 0, props.height),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 903,
	}, h(Text, {
		value = props.title,
		size = 10,
		color = props.accent or Palette.muted,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, -120, 0, 14),
		zIndex = 904,
	}), props.note and h(Text, {
		value = props.note,
		size = 10,
		color = Palette.muted,
		align = Enum.TextXAlignment.Right,
		fit = false,
		position = UDim2.new(1, -220, 0, 0),
		sizeConstraint = UDim2.fromOffset(220, 14),
		zIndex = 904,
	}), h("frame", {
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 1, -22),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 903,
	}, props.children))
end

-- one choosable card: a vow, a star's perk, a keepsake
local function ChoiceCard(props)
	local hover, setHover = React.useState(false)
	local chosen = props.chosen
	local tint = props.color
	local cardRef = React.useRef(nil)
	Tooltip.useTooltip(cardRef, props.tooltip)
	return h("textbutton", {
		ref = cardRef,
		Name = props.name,
		LayoutOrder = props.order,
		Size = props.size,
		Position = props.position,
		BackgroundColor3 = if chosen then darken(tint, 0.62) elseif hover then Palette.panelSoft else Palette.ink,
		BackgroundTransparency = if chosen then 0 else 0.25,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		ZIndex = 905,
		Event = {
			Activated = function()
				if props.disabled then
					Audio:play("error")
					return
				end
				Audio:play(props.sound or "tabSwitch")
				props.onPick()
			end,
			MouseEnter = function()
				setHover(true)
			end,
			MouseLeave = function()
				setHover(false)
			end,
		},
	}, h("uicorner", { CornerRadius = UDim.new(0, 10) }), h("uistroke", {
		Color = tint,
		Thickness = if chosen then 2 else 1,
		Transparency = if chosen then 0.05 elseif hover then 0.35 else 0.7,
	}), h(Icon, {
		kind = props.icon,
		size = props.iconSize or 30,
		position = UDim2.fromOffset(10, 10),
		zIndex = 906,
	}), h(Text, {
		value = props.title,
		size = 13,
		color = if props.disabled then Palette.muted else Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset((props.iconSize or 30) + 18, 9),
		sizeConstraint = UDim2.new(1, -((props.iconSize or 30) + 26), 0, 17),
		zIndex = 906,
	}), h(Text, {
		value = props.body,
		size = 10,
		color = if props.disabled then Palette.muted else Palette.creamSoft,
		wrap = true,
		fit = false,
		position = UDim2.fromOffset((props.iconSize or 30) + 18, 28),
		sizeConstraint = UDim2.new(1, -((props.iconSize or 30) + 26), 1, -32),
		zIndex = 906,
	}), props.tag and h(Text, {
		value = props.tag,
		size = 9,
		color = tint,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Right,
		fit = false,
		position = UDim2.new(1, -96, 0, 10),
		sizeConstraint = UDim2.fromOffset(86, 12),
		zIndex = 906,
	}))
end

-- the last runs as bars: height is the payout, colour is the grade, a dot marks a kept vow
local function RunLog(props)
	local runs = props.runs
	local best = 1
	for _, run in runs do
		best = math.max(best, tonumber(run.Cores) or 0)
	end
	local bars = {}
	local count = RebirthMath.LOG_LIMIT
	for i = 1, count do
		local run = runs[#runs - count + i]
		local share = if run then math.clamp((tonumber(run.Cores) or 0) / best, 0.06, 1) else 0
		local tint = if run then GRADE_COLOR[run.Grade] or Palette.muted else Palette.panelSoft
		bars["b" .. i] = h("frame", {
			Size = UDim2.new(1 / count, -6, 1, -18),
			Position = UDim2.new((i - 1) / count, 3, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 905,
		}, h("frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = props.grow:map(function(amount)
				return UDim2.new(1, 0, if run then share * amount else 0.04, 0)
			end),
			BackgroundColor3 = tint,
			BackgroundTransparency = if run then 0.1 else 0.6,
			BorderSizePixel = 0,
			ZIndex = 906,
		}, h("uicorner", { CornerRadius = UDim.new(0, 4) })), run and h(Text, {
			value = run.Grade,
			size = 10,
			color = tint,
			weight = Enum.FontWeight.Heavy,
			align = Enum.TextXAlignment.Center,
			fit = false,
			position = UDim2.new(0, 0, 1, 2),
			sizeConstraint = UDim2.new(1, 0, 0, 14),
			zIndex = 906,
		}))
	end
	return h("frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 904,
	}, bars)
end

local function RebirthChamber(props)
	local state = props.state
	local config = props.config
	local dispatch = props.dispatch
	local effectsPaused = props.effectsPaused
	local reducedMotion = props.reducedMotion
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local info = rebirthOf(state)
	local portal = React.useState(acquireDropdownPortal)
	React.useEffect(function()
		return function()
			releaseDropdownPortal()
		end
	end, {})
	local nextVow, setNextVow = React.useState(info.Vow or "")
	local keep, setKeep = React.useState(function()
		return table.clone(info.Keep or {})
	end)
	local confirming, setConfirming = React.useState(false)
	local busy, setBusy = React.useState(false)
	local igniting, setIgniting = React.useState(false)
	local shakeToken, setShakeToken = React.useState(0)
	local ignite, setIgnite = React.useBinding(0)
	local mountedRef = React.useRef(true)
	local ignitionRef = React.useRef(nil)
	local confirmArmedRef = React.useRef(nil)
	local rebirthClaimHostRef = React.useRef(nil)
	local enter = useStagger(0, softMotion)
	local grow = useStagger(2, softMotion)
	local gradeGlow = usePulse(not softMotion and not effectsPaused and info.Ready == true, 1.8)
	local runSeconds = useRunClock(tonumber(info.RunStartedAt) or 0, state.ServerTime)
	local canRebirth = info.Ready == true
	local function stopIgnition()
		local connection = ignitionRef.current
		if connection ~= nil then
			ignitionRef.current = nil
			connection:Disconnect()
		end
	end
	React.useEffect(function()
		return function()
			mountedRef.current = false
			stopIgnition()
		end
	end, {})
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = rebirthClaimHostRef.current
		if host == nil then
			return nil
		end
		local selectJob = task.defer(function()
			if host.Parent ~= nil then
				GamepadNavigationService.FocusClaim(host)
			end
		end)
		return function()
			pcall(task.cancel, selectJob)
		end
	end, { canRebirth, confirming, busy })
	React.useEffect(function()
		if not canRebirth then
			stopIgnition()
			setIgnite(0)
			setIgniting(false)
			setConfirming(false)
		end
	end, { canRebirth })
	React.useEffect(function()
		if not confirming or igniting or busy then
			return nil
		end
		local lapse = task.delay(6, function()
			if mountedRef.current then
				setConfirming(false)
			end
		end)
		return function()
			pcall(task.cancel, lapse)
		end
	end, { confirming, igniting, busy })
	local close = function()
		if igniting or busy then
			return
		end
		Audio:play("close")
		props.onClose()
	end
	React.useEffect(function()
		local connection = UserInputService.InputBegan:Connect(function(input, processed)
			if input.KeyCode == Enum.KeyCode.ButtonB or (input.KeyCode == Enum.KeyCode.Escape and not processed) then
				close()
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { igniting, busy })
	local commit = function()
		setBusy(true)
		dispatch("Rebirth", { Vow = nextVow, Keep = keep }, function(response)
			if not mountedRef.current then
				return nil
			end
			setBusy(false)
			setIgnite(0)
			if response.ok then
				setConfirming(false)
				props.onClose()
			else
				setShakeToken(function(token)
					return token + 1
				end)
			end
		end)
	end
	-- a short, cancellable charge before the reset actually fires; softMotion compresses it
	local beginIgnition = function()
		if igniting or ignitionRef.current ~= nil then
			return
		end
		setIgniting(true)
		Audio:play("rebirthCharge")
		local duration = if softMotion then 0.35 else 1.15
		local ticks = if softMotion then 0 else 6
		local started = os.clock()
		local ticked = 0
		local connection
		connection = RunService.Heartbeat:Connect(function()
			local amount = math.clamp((os.clock() - started) / duration, 0, 1)
			setIgnite(amount)
			local due = math.floor(amount * ticks)
			if due > ticked and due < ticks then
				ticked = due
				Audio:play("countTick", 0.9 + due * 0.08)
			end
			if amount >= 1 then
				connection:Disconnect()
				if ignitionRef.current == connection then
					ignitionRef.current = nil
				end
				if not mountedRef.current then
					return
				end
				setIgniting(false)
				InteractionFeedback.reward()
				commit()
			end
		end)
		ignitionRef.current = connection
	end
	local cancelIgnition = function()
		stopIgnition()
		setIgnite(0)
		setIgniting(false)
		Audio:play("close")
	end
	-- The confirm step disarms itself: a second press only counts within CONFIRM_WINDOW seconds of the
	-- first and not as part of the same double-click, so a stray tap later can never start a reset.
	local CONFIRM_WINDOW, CONFIRM_MIN_GAP = 6, 0.35
	local rebirth = function()
		if not canRebirth or busy or igniting then
			return nil
		end
		local armedAt = confirmArmedRef.current
		local elapsed = if armedAt ~= nil then os.clock() - armedAt else math.huge
		if not confirming or elapsed > CONFIRM_WINDOW then
			confirmArmedRef.current = os.clock()
			setConfirming(true)
			Audio:play("preview")
			return nil
		end
		if elapsed < CONFIRM_MIN_GAP then
			return nil
		end
		beginIgnition()
	end

	local accent = if igniting then Palette.mango elseif confirming then Palette.coral else Palette.violet
	local gradeColor = GRADE_COLOR[info.Grade] or Palette.muted
	local width = math.min(760, viewport.width - 24)
	local top = math.max(viewport.topInset, 36) + 10
	local bottom = math.max(chrome.bottomSafe, viewport.bottomInset, 8) + 10
	local height = math.min(720, viewport.height - top - bottom)
	local innerW = width - 40
	local footerH = TapTarget + 30
	local vow = RebirthMath.vow(info.Vow)

	-- the payout: grade, cores, stardust, and why
	local reasons = {}
	if vow then
		table.insert(reasons, if info.VowHolds then `{vow.Name} holds: ×{string.format("%.2f", RebirthMath.vowMultiplier({ Kept = info.KeptVows, Stars = info.Stars }, vow.Id))} {string.lower(vow.Pays)}` else `{vow.Name} broken: {info.VowStatus}`)
	else
		table.insert(reasons, "No vow this run.")
	end
	local gradeBonus = RebirthMath.GRADE_BONUS[info.Grade] or 0
	if gradeBonus > 0 then
		table.insert(reasons, `Grade {info.Grade}: +{math.floor(gradeBonus * 100)}% stardust`)
	end
	local fx = RebirthMath.effects({ Stars = info.Stars })
	if fx.CoreYield > 0 then
		table.insert(reasons, `Stars: +{math.floor(fx.CoreYield * 100 + 0.5)}% cores`)
	end
	if fx.DustYield > 0 then
		table.insert(reasons, `Stars: +{math.floor(fx.DustYield * 100 + 0.5)}% stardust`)
	end
	local sections = {}
	sections.layout = h("uilistlayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 22),
	})
	sections.pad = h("uipadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 20),
		PaddingRight = UDim.new(0, 6),
	})
	sections.payout = h(Section, {
		name = "RebirthPayout",
		order = 1,
		height = 118,
		title = if canRebirth then "WHAT THIS REBIRTH PAYS" else "NOT READY YET",
		note = `run time {clock(runSeconds)}`,
	}, h("frame", {
		Size = UDim2.fromOffset(78, 78),
		BackgroundColor3 = darken(gradeColor, 0.7),
		BorderSizePixel = 0,
		ZIndex = 905,
	}, h("uicorner", { CornerRadius = UDim.new(0, 14) }), h("uistroke", {
		Color = gradeColor,
		Thickness = 2,
		Transparency = gradeGlow:map(function(amount)
			return 0.1 + amount * 0.45
		end),
	}), h(Text, {
		value = if canRebirth then info.Grade else "–",
		size = 44,
		color = gradeColor,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = false,
		position = UDim2.fromOffset(0, 8),
		sizeConstraint = UDim2.new(1, 0, 0, 48),
		zIndex = 906,
	}), h(Text, {
		value = "GRADE",
		size = 9,
		color = Palette.muted,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = false,
		position = UDim2.fromOffset(0, 58),
		sizeConstraint = UDim2.new(1, 0, 0, 12),
		zIndex = 906,
	})), h(Text, {
		value = if canRebirth then `+{compactNumber(info.Cores)} cores` else `{compactNumber(math.max(0, asFlux(state.NextPrestigeTarget) - (asFlux(state.RunCash) + asFlux(state.Vault))))} more flux to go`,
		size = if stack then 20 else 24,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(94, 0),
		sizeConstraint = UDim2.new(1, -94, 0, 30),
		zIndex = 905,
	}), canRebirth and h(Text, {
		value = `+{compactNumber(info.Stardust)} stardust  ·  {GRADE_LINE[info.Grade] or ""}`,
		size = 12,
		color = Palette.mint,
		fit = false,
		position = UDim2.fromOffset(94, 32),
		sizeConstraint = UDim2.new(1, -94, 0, 16),
		zIndex = 905,
	}), h(Text, {
		value = table.concat(reasons, "   ·   "),
		size = 10,
		color = Palette.creamSoft,
		wrap = true,
		fit = false,
		position = UDim2.fromOffset(94, 54),
		sizeConstraint = UDim2.new(1, -94, 0, 34),
		zIndex = 905,
	}))

	-- stars waiting: the first one, its two perks side by side
	local pending = info.Pending or {}
	if #pending > 0 then
		local index = pending[1]
		local pair = RebirthMath.pair(index)
		local cards = {}
		for slot, perk in pair do
			local def = RebirthMath.PERKS[perk]
			local art = PERK_ART[perk]
			cards[perk] = h(ChoiceCard, {
				name = "Star" .. perk,
				icon = art.icon,
				color = art.color,
				title = def.Name,
				body = def.Line,
				iconSize = 34,
				size = UDim2.new(0.5, -6, 1, 0),
				position = UDim2.new((slot - 1) * 0.5, if slot == 2 then 6 else 0, 0, 0),
				sound = "reward",
				tooltip = {
					title = def.Name,
					body = "Permanent, and it stacks with every other star you light. The other choice is gone for this star.",
					hint = if RebirthMath.STARS[index + 1] then `Next star at rebirth {RebirthMath.STARS[index + 1]}.` else "This is the last star.",
					accent = art.color,
				},
				onPick = function()
					dispatch("RebirthAct", { Op = "Star", Index = index, Pick = slot })
				end,
			})
		end
		sections.stars = h(Section, {
			name = "RebirthStars",
			order = 2,
			height = 22 + 74,
			title = `STAR {index} IS LIT · CHOOSE ONE, IT'S PERMANENT`,
			accent = Palette.mango,
			note = if #pending > 1 then `{#pending - 1} more waiting` else nil,
		}, cards)
	end

	-- the vow for the next run
	local vowIds = { "", "Swift", "Lean", "Homebound", "Overflow" }
	local vowCards = {}
	local vowCols = if stack then 1 else 3
	local vowCardH = if stack then 56 else 78
	local vowGap = 10
	for i, id in vowIds do
		local def = RebirthMath.vow(id)
		local art = VOW_ART[id]
		local col = (i - 1) % vowCols
		local row = (i - 1) // vowCols
		local mastery = if def then RebirthMath.mastery({ Kept = info.KeptVows }, id) else 0
		local kept = if def and type(info.KeptVows) == "table" then tonumber(info.KeptVows[id]) or 0 else 0
		vowCards[id ~= "" and id or "None"] = h(ChoiceCard, {
			name = "Vow" .. (if id == "" then "None" else id),
			icon = art.icon,
			color = art.color,
			chosen = nextVow == id,
			title = if def then def.Name else art.name,
			body = if def then `{def.Line} ×{string.format("%.2f", RebirthMath.vowMultiplier({ Kept = info.KeptVows, Stars = info.Stars }, id))} {string.lower(def.Pays)}.` else art.line,
			tag = if def and kept > 0 then `KEPT {kept}{if mastery > 0 then " · M" .. mastery else ""}` else nil,
			tooltip = if def then {
				title = def.Name,
				body = `Checked the moment you rebirth. Kept, it multiplies your {string.lower(def.Pays)}; broken, you just get the normal payout.`,
				hint = if mastery >= RebirthMath.MASTERY_MAX then `Kept {kept} times, fully mastered.` else `Kept {kept} times. {RebirthMath.MASTERY_EVERY - kept % RebirthMath.MASTERY_EVERY} more to make it {math.floor(RebirthMath.MASTERY_STEP * 100)}% stronger.`,
				accent = art.color,
			} else nil,
			size = UDim2.new(1 / vowCols, -(vowGap * (vowCols - 1)) / vowCols, 0, vowCardH),
			position = UDim2.new(col / vowCols, col * vowGap / vowCols, 0, row * (vowCardH + vowGap)),
			onPick = function()
				setNextVow(id)
			end,
		})
	end
	local vowRows = math.ceil(#vowIds / vowCols)
	sections.vows = h(Section, {
		name = "RebirthVows",
		order = 3,
		height = 22 + vowRows * vowCardH + (vowRows - 1) * vowGap,
		title = "VOW FOR THE NEXT RUN",
		note = "keep it and the payout grows",
	}, vowCards)

	-- keepsakes: machines that come along at a share of their level
	local slots = tonumber(info.KeepSlots) or 0
	local fxShare = RebirthMath.KEEP_SHARE + fx.KeepShare
	local owned = {}
	for _, machine in (config and config.Machines) or {} do
		local level = state.Machines and tonumber(state.Machines[machine.Id]) or 0
		if level >= 1 and (tonumber(machine.RequiredZone) or 1) <= 1 then
			table.insert(owned, { id = machine.Id, name = machine.Name, level = level, icon = machine.Icon })
		end
	end
	table.sort(owned, function(a, b)
		return a.level > b.level
	end)
	if slots > 0 then
		local chips = {}
		local cols = if stack then 2 else 3
		local chipH = 54
		for i, entry in owned do
			if i > 9 then
				break
			end
			local chosen = table.find(keep, entry.id) ~= nil
			local full = not chosen and #keep >= slots
			local col = (i - 1) % cols
			local row = (i - 1) // cols
			chips[entry.id] = h(ChoiceCard, {
				name = "Keep" .. entry.id,
				icon = REBIRTH_ICONS["Keep" .. entry.id] or REBIRTH_ICONS.KeepOther,
				color = Palette.mint,
				chosen = chosen,
				disabled = full,
				title = entry.name,
				body = `Lv {compactNumber(entry.level)} → Lv {math.clamp(math.floor(entry.level * fxShare), 1, RebirthMath.KEEP_CAP)}`,
				iconSize = 26,
				size = UDim2.new(1 / cols, -(8 * (cols - 1)) / cols, 0, chipH),
				position = UDim2.new(col / cols, col * 8 / cols, 0, row * (chipH + 8)),
				onPick = function()
					local nextKeep = table.clone(keep)
					local at = table.find(nextKeep, entry.id)
					if at then
						table.remove(nextKeep, at)
					elseif #nextKeep < slots then
						table.insert(nextKeep, entry.id)
					end
					setKeep(nextKeep)
				end,
			})
		end
		local rows = math.max(1, math.ceil(math.min(#owned, 9) / cols))
		sections.keep = h(Section, {
			name = "RebirthKeepsakes",
			order = 4,
			height = 22 + rows * chipH + (rows - 1) * 8,
			title = `KEEPSAKES · {#keep} OF {slots}`,
			note = `keeps {math.floor(fxShare * 100 + 0.5)}% of the level`,
		}, chips)
	else
		local nextAt = RebirthMath.KEEP_SLOTS_AT[1]
		sections.keep = h(Section, {
			name = "RebirthKeepsakes",
			order = 4,
			height = 22 + 18,
			title = "KEEPSAKES",
		}, h(Text, {
			value = `After rebirth {nextAt}, one machine can come with you into the next run.`,
			size = 11,
			color = Palette.muted,
			fit = false,
			sizeConstraint = UDim2.new(1, 0, 0, 16),
			zIndex = 905,
		}))
	end

	-- what stays and what goes
	local function ledgerColumn(title, body, tint, x, icon)
		return h("frame", {
			Size = UDim2.new(0.5, -6, 1, 0),
			Position = UDim2.new(x, if x > 0 then 6 else 0, 0, 0),
			BackgroundColor3 = Palette.ink,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			ZIndex = 905,
		}, h("uicorner", { CornerRadius = UDim.new(0, 10) }), h("uistroke", {
			Color = tint,
			Transparency = 0.55,
		}), h(Icon, {
			kind = icon,
			size = 22,
			position = UDim2.fromOffset(10, 10),
			zIndex = 906,
		}), h(Text, {
			value = title,
			size = 10,
			color = tint,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			position = UDim2.fromOffset(40, 13),
			sizeConstraint = UDim2.new(1, -50, 0, 14),
			zIndex = 906,
		}), h(Text, {
			value = body,
			size = 11,
			color = Palette.creamSoft,
			wrap = true,
			fit = false,
			position = UDim2.fromOffset(12, 38),
			sizeConstraint = UDim2.new(1, -24, 1, -44),
			zIndex = 906,
		}))
	end
	local keepNames = {}
	for _, id in keep do
		for _, entry in owned do
			if entry.id == id then
				table.insert(keepNames, entry.name)
			end
		end
	end
	local keepCopy = "Cores, stardust, research, relics, milestones, Domain and every lit star"
	if #keepNames > 0 then
		keepCopy ..= ", plus " .. table.concat(keepNames, " and ")
	end
	sections.ledger = h(Section, {
		name = "RebirthLedger",
		order = 5,
		height = 22 + (if stack then 120 else 96),
		title = "WHAT STAYS, WHAT GOES",
	}, ledgerColumn("YOU KEEP", keepCopy, Palette.mint, 0, "Check.rebirthKeeps"), ledgerColumn("RESETS", "Run flux, the vault, worlds and machines. The Stellar Core starts again" .. (if fx.HeadStart > 0 then ` at Lv {1 + fx.HeadStart}.` else " at Lv 1."), Palette.coral, 0.5, "Refresh.rebirthResets"))

	-- the run log
	local runs = info.Runs or {}
	sections.log = h(Section, {
		name = "RebirthRunLog",
		order = 6,
		height = 22 + 110,
		title = `LAST {math.min(#runs, RebirthMath.LOG_LIMIT)} RUNS`,
		note = if #runs > 0 then `best {compactNumber(info.BestCores)} cores · fastest {clock(info.FastestSeconds)}` else nil,
	}, if #runs > 0 then h(RunLog, { runs = runs, grow = grow:map(function(amount)
		return math.clamp(amount, 0, 1)
	end) }) else h(Text, {
		value = "Your runs show up here: how long they took, what they paid and their grade.",
		size = 11,
		color = Palette.muted,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
		zIndex = 905,
	}))

	local claimText = if busy then "REBIRTHING…" elseif igniting then "IGNITING…" elseif confirming then "IGNITE REBIRTH" elseif canRebirth then `REBIRTH · {vowName(nextVow)} next` else "NOT READY"
	return ReactRoblox.createPortal(h("frame", {
		Name = "RebirthChamber",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 900,
	}, h("textbutton", {
		Name = "Scrim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.night,
		BackgroundTransparency = enter:map(function(amount)
			return 1 - math.clamp(amount, 0, 1) * 0.42
		end),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Selectable = false,
		ZIndex = 900,
		Event = {
			Activated = close,
		},
	}), h("frame", {
		Name = "Sheet",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(width, height),
		Position = enter:map(function(amount)
			return UDim2.new(0.5, 0, 0, top + math.round((1 - math.clamp(amount, 0, 1)) * 18))
		end),
		BackgroundColor3 = if confirming then darken(accent, 0.9) else Palette.panelRaised,
		BorderSizePixel = 0,
		ZIndex = 901,
	}, h("uicorner", { CornerRadius = UDim.new(0, 18) }), h("uistroke", {
		Color = accent,
		Thickness = 1,
		Transparency = 0.45,
	}), h(ChargeDial, {
		size = 54,
		position = UDim2.fromOffset(16, 14),
		accent = accent,
		fill = ignite,
		charge = ignite,
		zIndex = 903,
	}, h(Icon, {
		kind = "Rebirth.rebirthChamber",
		size = 34,
		position = UDim2.fromOffset(10, 10),
		zIndex = 904,
	})), h(Text, {
		value = if igniting then "IGNITING" elseif confirming then "CHECK YOUR REBIRTH" else `REBIRTH {(tonumber(info.Lifetime) or 0) + 1}`,
		size = 10,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(84, 18),
		sizeConstraint = UDim2.new(1, -160, 0, 14),
		zIndex = 903,
	}), h(Text, {
		value = if igniting then "Stop now or the run resets." elseif confirming then "Press again to ignite." else "End this run",
		size = if stack then 18 else 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(84, 34),
		sizeConstraint = UDim2.new(1, -160, 0, 28),
		zIndex = 903,
	}), h(Button, {
		text = "",
		icon = "Close.rebirthChamber",
		onClick = close,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.fromOffset(TapTarget, TapTarget),
		position = UDim2.new(1, -(TapTarget + 16), 0, 18),
		reducedMotion = softMotion,
		disabled = igniting or busy,
		zIndex = 903,
	}), h("scrollingframe", {
		Name = "Body",
		Position = UDim2.fromOffset(20, 84),
		Size = UDim2.new(1, -28, 1, -(84 + footerH + 6)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = accent,
		ZIndex = 902,
	}, sections), h("frame", {
		Name = "RebirthClaimActions",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -16),
		Size = UDim2.new(1, -40, 0, TapTarget + 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 903,
		ref = rebirthClaimHostRef,
	}, h(Button, {
		text = claimText,
		icon = "Rebirth.rebirthIgnite",
		onClick = rebirth,
		color = if canRebirth then accent else Palette.panelSoft,
		textColor = if canRebirth then Palette.ink else Palette.muted,
		size = UDim2.new(if stack then 0.62 else 0.7, -6, 0, TapTarget),
		reducedMotion = softMotion,
		disabled = not canRebirth or busy,
		loading = busy,
		shakeToken = shakeToken,
		highlight = canRebirth and not igniting and not softMotion,
		zIndex = 904,
	}), h("frame", {
		Name = "IgnitionBar",
		Size = ignite:map(function(amount)
			return UDim2.new((if stack then 0.62 else 0.7) * amount, -6, 0, 4)
		end),
		Position = UDim2.fromOffset(0, TapTarget + 3),
		BackgroundColor3 = Palette.mango,
		BorderSizePixel = 0,
		Visible = igniting,
		ZIndex = 904,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) })), h(Button, {
		text = if igniting then "STOP" elseif confirming then "CANCEL" else "CLOSE",
		icon = "Close.rebirthIgniteStop",
		onClick = if igniting then cancelIgnition elseif confirming then function()
			setConfirming(false)
		end else close,
		sound = if igniting then nil else "close",
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.new(if stack then 0.38 else 0.3, -6, 0, TapTarget),
		position = UDim2.new(if stack then 0.62 else 0.7, 6, 0, 0),
		reducedMotion = softMotion,
		disabled = busy,
		zIndex = 904,
	})))), portal)
end

local function RebirthPanel(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local effectsPaused = _param.effectsPaused
	local height = _param.height
	local reveal = _param.reveal
	local openWorkshop = _param.openWorkshop
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 2
	end
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local stack = chrome.contentStack
	local info = rebirthOf(state)
	local canRebirth = info.Ready == true
	local target = math.max(1, asFlux(state.NextPrestigeTarget))
	local conversionFlux = math.max(0, asFlux(state.RunCash)) + math.max(0, asFlux(state.Vault))
	local progress = if canRebirth then 1 else meterFill(conversionFlux, target)
	local rebirths = math.max(0, math.floor(tonumber(state.Rebirths) or 0))
	local seconds = useRunClock(tonumber(info.RunStartedAt) or 0, state.ServerTime)
	local chamberOpen, setChamberOpen = React.useState(false)
	local readiness = useFlash(if canRebirth then 1 else 0, softMotion or effectsPaused, 0.8)
	local heroReveal = useStagger(1, softMotion)
	local starPulse = usePulse(#(info.Pending or {}) > 0 and not softMotion and not effectsPaused, 1.4)
	local dialFill, setDialFill = React.useBinding(progress)
	local ignite = React.useBinding(0)
	React.useEffect(function()
		setDialFill(progress)
	end, { progress })
	local vow = RebirthMath.vow(info.Vow)
	local vowArt = VOW_ART[info.Vow] or VOW_ART[""]
	local opens = featuresOpeningOnNextRebirth(config, rebirths + 1)
	local gate = rebirthGate(config, rebirths)
	local accent = if canRebirth then Palette.violet else Palette.steel
	local pending = #(info.Pending or {})
	local vowLine = if vow == nil
		then (if info.VowOpen then "No vow yet. You can still swear one this run." else "No vow this run.")
		elseif info.VowHolds then `{vow.Name}: {info.VowStatus}`
		else `{vow.Name} broken. {info.VowStatus}`
	local notes = {}
	if opens ~= "" then
		table.insert(notes, `Opens {opens}.`)
	end
	if gate ~= nil then
		table.insert(notes, `{gate.name} at rebirth {gate.need}.`)
	end
	local colW = if stack then 0 else 286
	return h(Panel, {
		layoutOrder = layoutOrder,
		size = UDim2.new(1, 0, 0, height),
		accent = accent,
		background = Palette.panelRaised,
		padding = if stack then chrome.cardPadding else 18,
		reveal = reveal or heroReveal,
		highlight = canRebirth and not effectsPaused and not softMotion,
		reducedMotion = softMotion or effectsPaused,
		clips = false,
	}, h(ChargeDial, {
		size = if stack then 56 else 64,
		position = UDim2.fromOffset(-3, if stack then 2 else 6),
		accent = accent,
		fill = dialFill,
		charge = ignite,
	}, h(IconTile, {
		kind = REBIRTH_ICONS.Dial,
		accent = accent,
		size = (if stack then 56 else 64) - 18,
		radius = 14,
		position = UDim2.fromOffset(9, 9),
		glow = canRebirth and not effectsPaused and not softMotion,
		spin = canRebirth and not effectsPaused and not softMotion,
		reducedMotion = softMotion or effectsPaused,
	})), h("frame", {
		Size = UDim2.new(1, -((if stack then 66 else 76) + colW + (if stack then 0 else 16)), 0, if stack then 134 else height - 36),
		Position = UDim2.fromOffset(if stack then 66 else 76, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, h(Text, {
		value = `REBIRTH · {rebirths} DONE · RUN {clock(seconds)}`,
		size = 10,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), h(Text, {
		value = if canRebirth then `+{compactNumber(info.Cores)} cores ready · grade {info.Grade}` elseif rebirths < 1 then "Your first rebirth pays you back." else `{math.floor(math.clamp(conversionFlux / target, 0, 1) * 100)}% of the way to rebirth {rebirths + 1}`,
		size = if stack then 18 else 21,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 20),
		sizeConstraint = UDim2.new(1, 0, 0, 28),
	}), h("frame", {
		Name = "RebirthVowLine",
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, h(Icon, {
		kind = REBIRTH_ICONS["PanelVow" .. (if info.Vow == "" then "None" else info.Vow)] or REBIRTH_ICONS.PanelVowNone,
		size = 20,
		position = UDim2.fromOffset(0, 1),
	}), h(Text, {
		value = vowLine,
		size = 11,
		color = if vow == nil then Palette.muted elseif info.VowHolds then vowArt.color else Palette.coral,
		fit = false,
		position = UDim2.fromOffset(26, 3),
		sizeConstraint = UDim2.new(1, -26, 0, 16),
	})), h(Meter, {
		value = progress,
		rainbow = true,
		color = accent,
		reducedMotion = softMotion or effectsPaused,
		shimmer = canRebirth and not effectsPaused and not softMotion,
		position = UDim2.fromOffset(0, 86),
		size = UDim2.new(1, 0, 0, 9),
	}), h(Text, {
		value = if canRebirth then `+{compactNumber(info.Stardust)} stardust too. {table.concat(notes, " ")}` else `{compactNumber(conversionFlux)} / {compactNumber(target)} flux. {table.concat(notes, " ")}`,
		size = 10,
		color = if canRebirth then Palette.mint else Palette.muted,
		wrap = true,
		fit = false,
		position = UDim2.fromOffset(0, 102),
		sizeConstraint = UDim2.new(1, 0, 0, 30),
	})), h("frame", {
		Size = if stack then UDim2.new(1, 0, 0, TapTarget * 2 + 44) else UDim2.fromOffset(colW, height - 36),
		Position = if stack then UDim2.new(0, 0, 1, -(TapTarget * 2 + 44)) else UDim2.new(1, -colW, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, h(Badge, {
		value = if pending > 0 then `STAR LIT · CHOOSE` else `{compactNumber(state.PermanentMultiplier)}× PRODUCTION`,
		accent = if pending > 0 then Palette.mango else Palette.mint,
		filled = pending > 0,
		size = UDim2.new(1, 0, 0, 26),
	}), pending > 0 and h("frame", {
		Size = UDim2.new(1, 4, 0, 30),
		Position = UDim2.fromOffset(-2, -2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
		Color = Palette.mango,
		Thickness = 2,
		Transparency = starPulse:map(function(amount)
			return 0.25 + amount * 0.6
		end),
	})), h(Button, {
		text = if canRebirth then "REBIRTH…" elseif pending > 0 then "LIGHT A STAR" else "PLAN REBIRTH",
		icon = "Rebirth.rebirthPlan",
		onClick = function()
			setChamberOpen(true)
		end,
		sound = "page",
		color = if canRebirth or pending > 0 then accent else Palette.panelSoft,
		textColor = if canRebirth or pending > 0 then Palette.ink else Palette.cream,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.fromOffset(0, 36),
		reducedMotion = softMotion,
		highlight = canRebirth and not softMotion,
	}), h(Button, {
		text = "OPEN WORKSHOP",
		icon = "Forge.rebirthWorkshop",
		onClick = openWorkshop,
		sound = "page",
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.fromOffset(0, 44 + TapTarget),
		reducedMotion = softMotion,
	})), canRebirth and not effectsPaused and not softMotion and h("frame", {
		Size = readiness:map(function(amount)
			return UDim2.fromOffset(18 + amount * 54, 18 + amount * 54)
		end),
		Position = UDim2.fromOffset(29, 38),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 8,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
		Color = accent,
		Thickness = 2,
		Transparency = readiness:map(function(amount)
			return 1 - amount * 0.54
		end),
	})), chamberOpen and h(RebirthChamber, {
		state = state,
		config = config,
		dispatch = dispatch,
		reducedMotion = softMotion,
		effectsPaused = effectsPaused,
		onClose = function()
			setChamberOpen(false)
		end,
	}))
end
return {
	RebirthPanel = RebirthPanel,
	RebirthChamber = RebirthChamber,
}
end

__defs["RewardsView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useFlipperSpring = _motion.useFlipperSpring
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Button = _ui.Button
local IconTile = _ui.IconTile
local Panel = _ui.Panel
local Text = _ui.Text
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local lighten = _theme.lighten
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local _format = require(script.Parent.Parent.CoreKit)("format")
local clockText = _format.clockText
local formatReward = _format.formatReward
local Icon = require(script.Parent.Parent.ArtKit)("Icon").Icon
local Browse = require(script.Parent.Parent.BrowseKit)

local function RewardChargeRail(_param)
	local value = _param.value
	local accent = _param.accent
	local ready = _param.ready
	local reducedMotion = _param.reducedMotion
	local position = _param.position
	local size = _param.size
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local progress = useFlipperSpring(math.clamp(value, 0, 1), softMotion, 420, 32)
	local emphasis = useFlipperSpring(if ready then 1 else 0, softMotion, 460, 32)
	local fillSize = progress:map(function(amount)
		return UDim2.new(math.clamp(amount, 0, 1), 0, 1, 0)
	end)
	local markerPosition = progress:map(function(amount)
		return UDim2.new(math.clamp(amount, 0, 1), 0, 0.5, 0)
	end)
	local markerScale = emphasis:map(function(amount)
		return 0.78 + math.clamp(amount, 0, 1) * 0.22
	end)
	return React.createElement("frame", {
		Size = size,
		Position = position,
		BackgroundColor3 = Palette.panelSoft,
		BackgroundTransparency = 0.22,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = fillSize,
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(darken(accent, 0.18), lighten(accent, 0.3)),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = markerPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = 45,
		BackgroundColor3 = if ready then Palette.cream else accent,
		BackgroundTransparency = progress:map(function(amount)
			return if amount > 0.025 then 0 else 1
		end),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uiscale", {
		Scale = markerScale,
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = accent,
		Thickness = 1,
		Transparency = emphasis:map(function(amount)
			return 0.68 - math.clamp(amount, 0, 1) * 0.46
		end),
	})))
end
local function StreakStrip(_param)
	local daily = _param.daily
	local softMotion = _param.reducedMotion
	local reducedMotion = softMotion
	local rewards = daily.Rewards or {}
	local count = math.max(1, #rewards)
	local canClaim = daily.CanClaim == true
	local current = if canClaim then (tonumber(daily.NextStreak) or 1) else (tonumber(daily.Streak) or 0)
	current = math.max(1, current)
	local weekStart = ((current - 1) // 7) * 7 + 1
	local cells = {
		layout = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	}
	for offset = 0, 6 do
		local day = weekStart + offset
		local reward = rewards[((day - 1) % count) + 1]
		local claimed = day < current or (day == current and not canClaim)
		local today = day == current and canClaim
		local accent = if today then Palette.mint elseif claimed then Palette.muted else Palette.cyan
		cells["d" .. day] = React.createElement("frame", {
			Size = UDim2.new(1 / 7, -6 * 6 / 7, 1, 0),
			LayoutOrder = offset,
			BackgroundColor3 = if today then darken(Palette.mint, 0.55) else Palette.panelSoft,
			BackgroundTransparency = if claimed then 0.45 else 0,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 9),
		}), React.createElement("uistroke", {
			Color = accent,
			Transparency = if today then 0.1 else 0.7,
			Thickness = if today then 1.5 else 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}), React.createElement(Text, {
			value = if today then "TODAY" else `DAY {day}`,
			size = 11,
			color = accent,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			minSize = 8,
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(4, 6),
			sizeConstraint = UDim2.new(1, -8, 0, 14),
		}), claimed and React.createElement("frame", {
			Size = UDim2.fromOffset(18, 18),
			Position = UDim2.new(0.5, 0, 0, 24),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
		}, React.createElement(Icon, {
			kind = "Check.3",
			color = Palette.muted,
			accent = Palette.muted,
			size = 18,
			spin = false,
		})) or React.createElement(Text, {
			value = formatReward(reward),
			size = 11,
			color = if today then Palette.cream else Palette.creamSoft,
			weight = Enum.FontWeight.Bold,
			wrap = true,
			fit = true,
			minSize = 8,
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(4, 22),
			sizeConstraint = UDim2.new(1, -8, 1, -26),
		}))
	end
	return React.createElement("frame", {
		Size = _param.size,
		Position = _param.position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, cells)
end
local function TimedTimeline(_param)
	local entries = _param.entries
	local played = _param.played
	local dispatch = _param.dispatch
	local columns = _param.columns
	local softMotion = _param.reducedMotion
	local reducedMotion = softMotion
	local cellH = 92
	local cells = {
		grid = React.createElement("uigridlayout", {
			CellSize = UDim2.new(1 / columns, -math.ceil(8 * (columns - 1) / columns), 0, cellH),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, entry in entries do
		local seconds = tonumber(entry.Seconds) or 0
		local ready = not entry.Claimed and played >= seconds
		local accent = if entry.Claimed then Palette.muted elseif ready then Palette.violet else Palette.cyan
		local reward = formatReward(entry.Reward)
		cells["t" .. tostring(entry.Index or index)] = React.createElement("frame", {
			LayoutOrder = index,
			BackgroundColor3 = if ready then Palette.panelRaised else Palette.panelSoft,
			BackgroundTransparency = if entry.Claimed then 0.45 else 0,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 10),
		}), React.createElement("uistroke", {
			Color = accent,
			Transparency = if ready then 0.2 else 0.72,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}), React.createElement(Text, {
			value = if entry.Claimed then `{clockText(seconds)} · COLLECTED` elseif ready then "READY" else `AT {clockText(seconds)} · IN {clockText(seconds - played)}`,
			size = 11,
			color = accent,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			minSize = 8,
			position = UDim2.fromOffset(10, 8),
			sizeConstraint = UDim2.new(1, -20, 0, 14),
		}), React.createElement(Text, {
			value = if reward ~= "" then reward else "Mystery parcel",
			size = 13,
			color = if entry.Claimed then Palette.muted else Palette.cream,
			weight = Enum.FontWeight.Bold,
			fit = true,
			minSize = 9,
			position = UDim2.fromOffset(10, 26),
			sizeConstraint = UDim2.new(1, -20, 0, 18),
		}), if ready then React.createElement(Button, {
			text = "CLAIM",
			icon = "Timer.2",
			onClick = function()
				dispatch("ClaimTimedReward", { Index = entry.Index })
			end,
			color = Palette.violet,
			textColor = Palette.ink,
			size = UDim2.new(1, -16, 0, 34),
			position = UDim2.new(0, 8, 1, -40),
			reducedMotion = softMotion,
			highlight = true,
		}) else React.createElement(RewardChargeRail, {
			value = if entry.Claimed then 1 else played / math.max(1, seconds),
			accent = accent,
			ready = false,
			reducedMotion = reducedMotion,
			position = UDim2.new(0, 10, 1, -16),
			size = UDim2.new(1, -20, 0, 5),
		}))
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, cells)
end
local function ShortcutTile(_param)
	local softMotion = _param.reducedMotion
	local reducedMotion = softMotion
	return React.createElement("frame", {
		LayoutOrder = _param.layoutOrder,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Button, {
		text = if _param.badge and _param.badge > 0 then `{_param.label} · {_param.badge}` else _param.label,
		icon = _param.icon,
		onClick = _param.onClick,
		color = if _param.badge and _param.badge > 0 then _param.accent else Palette.panelSoft,
		textColor = if _param.badge and _param.badge > 0 then Palette.ink else Palette.cream,
		outline = not (_param.badge and _param.badge > 0),
		highlight = _param.badge ~= nil and _param.badge > 0,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	}))
end
local function RewardsView(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local navigate = _param.navigate
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local daily = state.Daily or {}
	local dailyReady = daily.CanClaim == true
	local timed = state.TimedRewards or {}
	local timedEntries = timed.Rewards or {}
	local played = tonumber(timed.PlaySeconds) or 0
	local nextTimed = nil
	local readyTimed = {}
	for _, entry in timedEntries do
		if not entry.Claimed then
			if nextTimed == nil then
				nextTimed = entry
			end
			if played >= (tonumber(entry.Seconds) or math.huge) then
				table.insert(readyTimed, entry)
			end
		end
	end
	local timedReady = nextTimed ~= nil and played >= nextTimed.Seconds
	local timedProgress = if nextTimed ~= nil then math.clamp(played / math.max(1, nextTimed.Seconds), 0, 1) else 1
	local dailyReward = (daily.Rewards or {})[daily.RewardIndex]
	local now = Browse.useServerNow(1)
	local resetIn = Browse.untilUtcReset(now)
	local headerReveal = useStagger(0, softMotion)
	local dailyReveal = useStagger(1, softMotion)
	local timedReveal = useStagger(2, softMotion)
	local streakReveal = useStagger(3, softMotion)
	local rewardsTail = scrollTail(stack, chrome.bottomSafe, 48)
	local rewardsClaimHostRef = React.useRef(nil)
	local readyCount = (if dailyReady then 1 else 0) + #readyTimed
	local rewardsClaimReady = readyCount > 0
	React.useEffect(function()
		if not rewardsClaimReady or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = rewardsClaimHostRef.current
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
	end, { dailyReady, timedReady, rewardsClaimReady })
	local claimEverything = function()
		if dailyReady then
			dispatch("ClaimDaily")
		end
		for _, entry in readyTimed do
			dispatch("ClaimTimedReward", { Index = entry.Index })
		end
	end

	-- counts for the shortcut tiles
	local readyMissions = 0
	for _, quest in (if type(state.Quests) == "table" then state.Quests else {}) do
		if type(quest) == "table" and not quest.Claimed and (tonumber(quest.Progress) or 0) >= (tonumber(quest.Target) or math.huge) then
			readyMissions += 1
		end
	end
	local readyMilestones = 0
	for _, achievement in state.Achievements or {} do
		if type(achievement) == "table" and not achievement.Claimed and (tonumber(achievement.Progress) or 0) >= (tonumber(achievement.Target) or math.huge) then
			readyMilestones += 1
		end
	end

	local heroH = if stack then 116 + (if readyCount > 0 then TapTarget + 8 else 0) else 96
	local headerPanel = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.pink,
		background = Palette.panelRaised,
		padding = 14,
		layoutOrder = 0,
		reveal = headerReveal,
		reducedMotion = softMotion,
		clips = false,
	}, React.createElement(Text, {
		value = "REWARDS",
		size = 11,
		color = Palette.pink,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, -120, 0, 14),
	}), React.createElement(Text, {
		value = if readyCount > 0 then `{readyCount} reward{if readyCount == 1 then "" else "s"} waiting.` else "All caught up.",
		size = if stack then 20 else 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 14,
		position = UDim2.fromOffset(0, 18),
		sizeConstraint = UDim2.new(1, if stack then 0 else -240, 0, 28),
	}), React.createElement(Text, {
		value = `Daily parcel and playtime drops reset in {Browse.shortDuration(resetIn)} (midnight UTC).`,
		size = 12,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(0, 50),
		sizeConstraint = UDim2.new(1, if stack then 0 else -240, 0, if stack then 32 else 16),
	}), readyCount > 0 and React.createElement("frame", {
		Name = "RewardsClaimAllActions",
		Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(220, 44),
		Position = if stack then UDim2.new(0, 0, 1, -TapTarget) else UDim2.new(1, -220, 0.5, -22),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ref = rewardsClaimHostRef,
	}, React.createElement(Button, {
		text = `CLAIM EVERYTHING · {readyCount}`,
		icon = "Gift.2",
		onClick = claimEverything,
		color = Palette.pink,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = softMotion,
		highlight = true,
	})))

	local stripH = 72
	local stripY = if stack then 80 + TapTarget + 8 else 84
	local dailyCardH = stripY + stripH + 28
	local dailyPanel = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.mint,
		background = Palette.panel,
		padding = 14,
		layoutOrder = 1,
		reveal = dailyReveal,
		highlight = dailyReady,
		reducedMotion = softMotion,
		clips = false,
	}, React.createElement(IconTile, {
		kind = "Calendar",
		accent = if dailyReady then Palette.mint else Palette.panelSoft,
		size = 46,
		radius = 12,
		position = UDim2.fromOffset(0, if stack then 4 else 18),
		glow = dailyReady,
		reducedMotion = softMotion,
	}), React.createElement(Text, {
		value = "Daily parcel",
		size = 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(60, 6),
		sizeConstraint = UDim2.new(1, if stack then -60 else -230, 0, 23),
	}), React.createElement(Text, {
		value = if formatReward(dailyReward) ~= "" then formatReward(dailyReward) elseif dailyReady then "Ready to open" else "Already collected today",
		size = 12,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(60, 32),
		sizeConstraint = UDim2.new(1, if stack then -60 else -230, 0, 20),
	}), React.createElement(Text, {
		value = if dailyReady
			then `Streak {daily.Streak or 0} → {daily.NextStreak or 1} when you claim`
			else `Streak {daily.Streak or 0} · next parcel in {Browse.shortDuration(resetIn)}`,
		size = 12,
		color = Palette.mint,
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(60, 56),
		sizeConstraint = UDim2.new(1, if stack then -60 else -230, 0, 16),
	}), React.createElement("frame", {
		Name = "RewardsDailyClaimActions",
		Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(150, 44),
		Position = if stack then UDim2.fromOffset(0, 80) else UDim2.new(1, -150, 0, 18),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ref = if dailyReady and readyCount == 0 then rewardsClaimHostRef else nil,
	}, React.createElement(Button, {
		text = if dailyReady then "Claim" else "Claimed",
		icon = "Calendar.2",
		onClick = function()
			return dispatch("ClaimDaily")
		end,
		color = if dailyReady then Palette.mint else Palette.panelSoft,
		textColor = if dailyReady then Palette.ink else Palette.muted,
		size = UDim2.fromScale(1, 1),
		reducedMotion = softMotion,
		disabled = not dailyReady,
		highlight = dailyReady,
	})), React.createElement(StreakStrip, {
		daily = daily,
		reducedMotion = softMotion,
		position = UDim2.fromOffset(0, stripY),
		size = UDim2.new(1, 0, 0, stripH),
	}))

	local timedCardH = if stack then 172 else 110
	local timedPanel = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.violet,
		background = Palette.panel,
		padding = 14,
		layoutOrder = 2,
		reveal = if timedReady then streakReveal else timedReveal,
		highlight = timedReady and not softMotion,
		reducedMotion = softMotion,
		clips = false,
	}, React.createElement(IconTile, {
		kind = "Timer",
		accent = if timedReady then Palette.violet else Palette.panelSoft,
		size = 46,
		radius = 12,
		position = UDim2.fromOffset(0, if stack then 4 else 18),
		glow = timedReady,
		reducedMotion = softMotion,
	}), React.createElement(Text, {
		value = "Next playtime drop",
		size = 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(60, 6),
		sizeConstraint = UDim2.new(1, if stack then -60 else -230, 0, 23),
	}), React.createElement(Text, {
		value = if nextTimed == nil then "All caught up for today"
			elseif formatReward(nextTimed.Reward) ~= "" then formatReward(nextTimed.Reward)
			elseif timedReady then "Ready to collect"
			else clockText(played) .. " of " .. clockText(nextTimed.Seconds) .. " played",
		size = 12,
		color = Palette.muted,
		fit = true,
		position = UDim2.fromOffset(60, 32),
		sizeConstraint = UDim2.new(1, if stack then -60 else -230, 0, 17),
	}), React.createElement(RewardChargeRail, {
		value = timedProgress,
		accent = if timedReady then Palette.violet else Palette.cyan,
		ready = timedReady,
		reducedMotion = softMotion,
		position = UDim2.fromOffset(if stack then 0 else 60, if stack then 76 else 58),
		size = UDim2.new(1, if stack then 0 else -230, 0, 6),
	}), React.createElement("frame", {
		Name = "RewardsTimedClaimActions",
		Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(150, 44),
		Position = if stack then UDim2.new(0, 0, 1, -(TapTarget + 4)) else UDim2.new(1, -150, 0.5, -22),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(Button, {
		text = if timedReady then "CLAIM" elseif nextTimed == nil then "DONE" else `IN {clockText(nextTimed.Seconds - played)}`,
		icon = "Timer.3",
		onClick = function()
			if nextTimed ~= nil then
				dispatch("ClaimTimedReward", {
					Index = nextTimed.Index,
				})
			end
		end,
		color = if timedReady then Palette.violet else Palette.panelSoft,
		textColor = if timedReady then Palette.ink else Palette.muted,
		size = UDim2.fromScale(1, 1),
		reducedMotion = softMotion,
		disabled = not timedReady,
		highlight = timedReady,
	})))

	local columns = if stack then 2 elseif viewport.width >= 1200 then 4 else 3
	local timelineRows = math.max(1, math.ceil(#timedEntries / columns))
	local timelineH = 40 + timelineRows * 100
	local timelinePanel = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.cyan,
		background = Palette.panel,
		padding = 14,
		layoutOrder = 3,
		reveal = streakReveal,
		reducedMotion = softMotion,
		clips = false,
	}, React.createElement(Text, {
		value = `TODAY'S PLAYTIME DROPS · {clockText(played)} PLAYED`,
		size = 11,
		color = Palette.cyan,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, -26),
		Position = UDim2.fromOffset(0, 26),
		BackgroundTransparency = 1,
	}, React.createElement(TimedTimeline, {
		entries = timedEntries,
		played = played,
		dispatch = dispatch,
		columns = columns,
		reducedMotion = softMotion,
	})))

	local shortcuts = {
		{ id = "Wheel", label = "SPIN THE WHEEL", icon = "Wheel.3", accent = Palette.mango },
		{ id = "Missions", label = "MISSIONS", icon = "Mission.3", accent = Palette.green, badge = readyMissions },
		{ id = "Milestones", label = "MILESTONES", icon = "Milestone.2", accent = Palette.mango, badge = readyMilestones },
		{ id = "Boosts", label = "BOOSTS", icon = "Boost.9", accent = Palette.pink },
	}
	local shortcutCols = if stack then 2 else 4
	local shortcutChildren = {
		grid = React.createElement("uigridlayout", {
			CellSize = UDim2.new(1 / shortcutCols, -math.ceil(8 * (shortcutCols - 1) / shortcutCols), 0, TapTarget),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, entry in shortcuts do
		shortcutChildren[entry.id] = React.createElement(ShortcutTile, {
			label = entry.label,
			icon = entry.icon,
			accent = entry.accent,
			badge = entry.badge,
			layoutOrder = index,
			reducedMotion = softMotion,
			onClick = function()
				if navigate ~= nil then
					navigate(entry.id)
				end
			end,
		})
	end
	local shortcutsH = math.ceil(#shortcuts / shortcutCols) * (TapTarget + 8)
	local shortcutsRow = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, shortcutChildren)

	local sections = {
		{ id = "header", height = heroH, element = headerPanel },
		{ id = "daily", height = dailyCardH, element = dailyPanel },
		{ id = "timed", height = timedCardH, element = timedPanel },
	}
	if #timedEntries > 0 then
		table.insert(sections, { id = "timeline", height = timelineH, element = timelinePanel })
	end
	if navigate ~= nil then
		table.insert(sections, { id = "shortcuts", height = shortcutsH, element = shortcutsRow })
	end
	return React.createElement(PageScaffold, {
		gap = 12,
		tailPad = rewardsTail,
		scrollBarColor = Palette.pink,
		scrollBarThickness = 4,
		sections = sections,
	})
end
return {
	RewardsView = RewardsView,
}
end

__defs["MilestonesView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useEntrance = _motion.useEntrance
local useFlash = _motion.useFlash
local usePulse = _motion.usePulse
local useViewport = _motion.useViewport
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local Dropdown = _ui.Dropdown
local EmptyState = _ui.EmptyState
local IconTile = _ui.IconTile
local Meter = _ui.Meter
local Panel = _ui.Panel
local Stroke = _ui.Stroke
local Text = _ui.Text
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local scrollTail = _theme.scrollTail
local _format = require(script.Parent.Parent.CoreKit)("format")
local compactNumber = _format.compactNumber
local formatReward = _format.formatReward
local _MissionsView = __load("MissionsView")
local TASK_FILTERS = _MissionsView.TASK_FILTERS
local taskFilterCounts = _MissionsView.taskFilterCounts
local taskMatchesFilter = _MissionsView.taskMatchesFilter
local TaskSummary = _MissionsView.TaskSummary
local FlatList = require(script.Parent.Parent.LayoutKit)("virtualizedList").FlatList
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local Browse = require(script.Parent.Parent.BrowseKit)
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
	local softMotion = reducedMotion
	reducedMotion = softMotion
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
	return useFlash(trigger, reducedMotion, 0.6)
end
local function MilestoneRow(_param)
	local achievement = _param.achievement
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local position = _param.position
	local stack = _param.stack
	local claimHostRef = _param.claimHostRef
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
		kind = "Milestone",
		accent = if achievement.Claimed then Palette.mango else accent,
		size = 42,
		radius = 11,
		glow = ready,
		filled = ready,
		reducedMotion = softMotion,
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
		reducedMotion = softMotion,
	}, _exp, _exp_1, React.createElement(Text, _attributes), reward ~= "" and React.createElement("frame", {
		Size = UDim2.fromOffset(math.min(220, #reward * 7 + 24), 20),
		Position = UDim2.fromOffset(56, if stack then 66 else 56),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 6),
	}), React.createElement("uistroke", {
		Color = Palette.mango,
		Thickness = 1,
		Transparency = 0.65,
	}), React.createElement(Text, {
		value = reward,
		size = 11,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(6, 2),
		sizeConstraint = UDim2.new(1, -12, 1, -4),
	})), React.createElement(Text, {
		value = if ready then "Reward ready" elseif achievement.Claimed then "Claimed" else `{compactNumber(achievement.Progress)} / {compactNumber(achievement.Target)}  ·  {math.floor(progressFrac * 100)}%`,
		size = 11,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, progressY),
		sizeConstraint = UDim2.new(0, 220, 0, 16),
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
	}), if stack then React.createElement("frame", {
		Name = "MilestoneClaimActions",
		Size = UDim2.new(1, 0, 0, TapTarget),
		Position = UDim2.new(0, 0, 1, -(TapTarget + 6)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ref = if ready then claimHostRef else nil,
	}, React.createElement(Button, {
		text = if achievement.Claimed then "CLAIMED" elseif ready then "CLAIM REWARD" else "LOCKED",
		icon = "Wheel.4",
		onClick = function()
			return dispatch("ClaimAchievement", {
				Id = achievement.Id,
			})
		end,
		color = if ready then Palette.green else Palette.panelSoft,
		textColor = if ready then Palette.ink else Palette.creamSoft,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = achievement.Claimed or not ready,
		highlight = ready,
	})) else React.createElement("frame", {
		Name = "MilestoneClaimActions",
		Size = UDim2.fromOffset(166, 44),
		Position = UDim2.new(1, -166, 0.5, -22),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ref = if ready then claimHostRef else nil,
	}, React.createElement(Button, {
		text = if achievement.Claimed then "CLAIMED" elseif ready then "CLAIM REWARD" else "LOCKED",
		icon = "Wheel.5",
		onClick = function()
			return dispatch("ClaimAchievement", {
				Id = achievement.Id,
			})
		end,
		color = if ready then Palette.green else Palette.panelSoft,
		textColor = if ready then Palette.ink else Palette.creamSoft,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = achievement.Claimed or not ready,
		highlight = ready,
	})))
end
local function taskProgress(entry)
	return math.clamp((tonumber(entry.Progress) or 0) / math.max(1, tonumber(entry.Target) or 1), 0, 1)
end
local function taskRank(entry)
	if not entry.Claimed and (tonumber(entry.Progress) or 0) >= (tonumber(entry.Target) or 0) then
		return 0
	elseif entry.Claimed then
		return 2
	end
	return 1
end
local function MilestonesView(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	local enter = useEntrance(softMotion)
	local stack = chrome.contentStack
	local list = state.Achievements or {}
	local counts = taskFilterCounts(list)
	local categories = {}
	for _, option in TASK_FILTERS do
		table.insert(categories, {
			id = option.id,
			label = option.short or option.label,
			test = if option.id == "All" then nil else function(achievement)
				return taskMatchesFilter(achievement, option.id)
			end,
		})
	end
	local browse = Browse.useBrowse({
		id = "Milestones",
		items = list,
		text = function(achievement)
			return { achievement.Name, achievement.Description, formatReward(achievement.Reward) }
		end,
		categories = categories,
		sorts = {
			{ id = "Recommended", label = "Ready first", compare = function(a, b)
				return taskRank(a) < taskRank(b)
			end },
			{ id = "Closest", label = "Almost done", compare = function(a, b)
				local ra, rb = taskRank(a), taskRank(b)
				if ra ~= rb then
					return ra < rb
				end
				return taskProgress(a) > taskProgress(b)
			end },
			{ id = "Name", label = "A to Z", compare = function(a, b)
				return tostring(a.Name) < tostring(b.Name)
			end },
		},
	})
	local visible = browse.results
	local claimHostRef = React.useRef(nil)
	local firstReadyId = nil
	for _, achievement in visible do
		if taskRank(achievement) == 0 then
			firstReadyId = achievement.Id
			break
		end
	end
	React.useEffect(function()
		if firstReadyId == nil or not UserInputService.GamepadEnabled then
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
	end, { firstReadyId, browse.category })
	local claimAllReady = function()
		for _, achievement in list do
			if type(achievement) == "table" and taskRank(achievement) == 0 then
				dispatch("ClaimAchievement", { Id = achievement.Id })
			end
		end
	end
	local barH = Browse.barHeight(stack, true)
	local introH = if stack then 40 else 70
	local claimRowH = if stack and counts.Ready > 0 then TapTarget + 10 else 0
	local headerHeight = 32 + introH + claimRowH + 10 + barH
	local rowStride = (if stack then 220 else 148) + 16
	local pageGap = if stack then chrome.panelGap else 10
	local headerPanel = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.mango,
		background = Palette.panelRaised,
		padding = 16,
		reveal = enter,
		reducedMotion = softMotion,
		zIndex = 30,
		clips = false,
	}, if stack then React.createElement(Text, {
		value = "MILESTONES · KEPT THROUGH REBIRTH",
		size = 13,
		color = if counts.Ready > 0 then Palette.green else Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		wrap = true,
		sizeConstraint = UDim2.new(1, -8, 0, 34),
	}) else React.createElement(React.Fragment, nil, React.createElement(Text, {
		value = "MILESTONES",
		size = 11,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, -420, 0, 16),
	}), React.createElement(Text, {
		value = if counts.Ready > 0 then `{counts.Ready} ready to claim · {counts.Done} of {#list} done` else `{counts.Done} of {#list} reached`,
		size = 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 16),
		sizeConstraint = UDim2.new(1, -420, 0, 30),
	}), React.createElement(Text, {
		value = "Big achievements that stay even after a rebirth.",
		size = 12,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(0, 48),
		sizeConstraint = UDim2.new(1, -420, 0, 16),
	}), React.createElement(TaskSummary, {
		done = counts.Done,
		total = #list,
		accent = Palette.mango,
		reducedMotion = softMotion,
		position = UDim2.new(1, -190, 0, 4),
		size = UDim2.fromOffset(190, 56),
	})), counts.Ready > 0 and React.createElement("frame", {
		Name = "MilestoneClaimAllActions",
		Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(200, 44),
		Position = if stack then UDim2.fromOffset(0, introH) else UDim2.new(1, -404, 0, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(Button, {
		text = `CLAIM ALL · {counts.Ready}`,
		icon = "Gift.3",
		onClick = claimAllReady,
		color = Palette.green,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = softMotion,
		highlight = true,
	})), React.createElement(Browse.BrowseBar, {
		browse = browse,
		placeholder = "Search milestones and rewards",
		accent = Palette.mango,
		stack = stack,
		reducedMotion = softMotion,
		position = UDim2.fromOffset(0, introH + claimRowH + 10),
		zIndex = 40,
	}))
	local milestonesList = React.createElement(FlatList, {
		data = visible,
		itemHeight = rowStride,
		headerHeight = 0,
		overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
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
				reducedMotion = softMotion,
				query = browse.query,
				position = UDim2.fromOffset(0, 0),
				stack = stack,
				claimHostRef = if item.Id == firstReadyId then claimHostRef else nil,
			})
		end,
		ListEmptyComponent = if #visible == 0 then React.createElement(Browse.NoResults, {
			browse = browse,
			noun = "milestones",
			icon = "Milestone.3",
			emptyBody = "Keep playing and they will show up.",
			accent = Palette.mango,
			reducedMotion = softMotion,
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
end

__defs["MissionsView"] = function()
local exports = {}
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local PageReadyMath = require(script.Parent.Parent.LayoutKit)("pageReadyMath")
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useEntrance = _motion.useEntrance
local useFlash = _motion.useFlash
local usePulse = _motion.usePulse
local useViewport = _motion.useViewport
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local Dropdown = _ui.Dropdown
local EmptyState = _ui.EmptyState
local IconTile = _ui.IconTile
local Meter = _ui.Meter
local Panel = _ui.Panel
local Stroke = _ui.Stroke
local Text = _ui.Text
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local scrollTail = _theme.scrollTail
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local _format = require(script.Parent.Parent.CoreKit)("format")
local compactNumber = _format.compactNumber
local formatReward = _format.formatReward
local _taskFilter = require(script.Parent.Parent.CoreKit)("taskFilter")
local taskFilterCounts = _taskFilter.taskFilterCounts
local taskMatchesFilter = _taskFilter.taskMatchesFilter
local FlatList = require(script.Parent.Parent.LayoutKit)("virtualizedList").FlatList
local Browse = require(script.Parent.Parent.BrowseKit)
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
	local softMotion = reducedMotion
	reducedMotion = softMotion
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
	return useFlash(trigger, reducedMotion, 0.6)
end
local _taskFilter_1 = require(script.Parent.Parent.CoreKit)("taskFilter")
exports.taskFilterCounts = _taskFilter_1.taskFilterCounts
exports.taskMatchesFilter = _taskFilter_1.taskMatchesFilter
local TASK_FILTERS = { {
	id = "All",
	label = "Everything",
	short = "All",
}, {
	id = "Ready",
	label = "Ready to claim",
	short = "Ready",
}, {
	id = "Active",
	label = "Still in progress",
	short = "In progress",
}, {
	id = "Done",
	label = "Already claimed",
	short = "Claimed",
} }
local function MissionRow(_param)
	local quest = _param.quest
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
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
		filled = ready,
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
	}, _exp, _exp_1, React.createElement(Text, _attributes), reward ~= "" and React.createElement("frame", {
		Size = UDim2.fromOffset(math.min(220, #reward * 7 + 24), 20),
		Position = UDim2.fromOffset(56, if stack then 66 else 56),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 6),
	}), React.createElement("uistroke", {
		Color = Palette.cyan,
		Thickness = 1,
		Transparency = 0.65,
	}), React.createElement(Text, {
		value = reward,
		size = 11,
		color = Palette.cyan,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(6, 2),
		sizeConstraint = UDim2.new(1, -12, 1, -4),
	})), React.createElement(Text, {
		value = if ready then "Reward ready" elseif quest.Claimed then "Claimed" else `{compactNumber(quest.Progress)} / {compactNumber(quest.Target)}  ·  {math.floor(progressFrac * 100)}%`,
		size = 11,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(0, progressY),
		sizeConstraint = UDim2.new(0, 300, 0, 16),
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
		text = if quest.Claimed then "CLAIMED" elseif ready then "CLAIM" else "NOT YET",
		icon = "Mission.4",
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
		text = if quest.Claimed then "CLAIMED" elseif ready then "CLAIM" else "NOT YET",
		icon = "Mission.5",
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
local function TaskSummary(_param)
	local softMotion = _param.reducedMotion
	local reducedMotion = softMotion
	local done = _param.done
	local total = _param.total
	local accent = _param.accent
	local fraction = if total > 0 then done / total else 0
	return React.createElement("frame", {
		Size = _param.size,
		Position = _param.position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Text, {
		-- the headline beside this already gives the count; lead with how far along you are
		value = `{math.floor(fraction * 100 + 0.5)}%`,
		size = 20,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		align = Enum.TextXAlignment.Right,
		sizeConstraint = UDim2.new(1, 0, 0, 26),
	}), React.createElement(Text, {
		value = if done >= total and total > 0 then "all done" else "complete",
		size = 12,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		align = Enum.TextXAlignment.Right,
		position = UDim2.fromOffset(0, 26),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Meter, {
		value = fraction,
		color = accent,
		reducedMotion = reducedMotion,
		position = UDim2.fromOffset(0, 46),
		size = UDim2.new(1, 0, 0, 6),
	}))
end
local function questRank(quest)
	if not quest.Claimed and (tonumber(quest.Progress) or 0) >= (tonumber(quest.Target) or 0) then
		return 0
	elseif quest.Claimed then
		return 2
	end
	return 1
end
local function questFraction(quest)
	return math.clamp((tonumber(quest.Progress) or 0) / math.max(1, tonumber(quest.Target) or 1), 0, 1)
end
local function MissionsView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local enter = useEntrance(softMotion)
	local stack = chrome.contentStack
	local quests = if type(state.Quests) == "table" then state.Quests else {}
	local counts = taskFilterCounts(quests)
	local categories = {}
	for _, option in TASK_FILTERS do
		table.insert(categories, {
			id = option.id,
			label = option.short or option.label,
			test = if option.id == "All" then nil else function(quest)
				return taskMatchesFilter(quest, option.id)
			end,
		})
	end
	local browse = Browse.useBrowse({
		id = "Missions",
		items = quests,
		text = function(quest)
			return { quest.Name, quest.Description, formatReward(quest.Reward), quest.Kind }
		end,
		categories = categories,
		sorts = {
			{ id = "Recommended", label = "Ready first", compare = function(a, b)
				return questRank(a) < questRank(b)
			end },
			{ id = "Closest", label = "Almost done", compare = function(a, b)
				local ra, rb = questRank(a), questRank(b)
				if ra ~= rb then
					return ra < rb
				end
				return questFraction(a) > questFraction(b)
			end },
			{ id = "List", label = "Daily order" },
		},
	})
	local visible = browse.results
	local missionClaimHostRef = React.useRef(nil)
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
			pcall(task.cancel, selectJob)
		end
	end, { counts.Ready, browse.category })
	local guide = if config ~= nil and config.ClientPageGuides ~= nil then config.ClientPageGuides.Missions else nil
	local claimAllReady = function()
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
	local barH = Browse.barHeight(stack, true)
	local introH = if stack then 40 else 70
	local claimRowH = if stack and counts.Ready > 0 then TapTarget + 10 else 0
	local headerHeight = 32 + introH + claimRowH + 10 + barH
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
	}, if stack then React.createElement(Text, {
		value = "TODAY'S MISSIONS · NEW EACH DAY",
		size = 13,
		color = if counts.Ready > 0 then Palette.green else Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		wrap = true,
		sizeConstraint = UDim2.new(1, -8, 0, 34),
	}) else React.createElement(React.Fragment, nil, React.createElement(Text, {
		value = "MISSIONS",
		size = 11,
		color = Palette.cyan,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, -420, 0, 16),
	}), React.createElement(Text, {
		value = if counts.Ready > 0 then `{counts.Ready} ready to claim · {counts.Done} of {#quests} done` else `{counts.Done} of {#quests} done today`,
		size = 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 16),
		sizeConstraint = UDim2.new(1, -420, 0, 30),
	}), React.createElement(Text, {
		value = "Finish these for flux and stardust. They refresh every day.",
		size = 12,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(0, 48),
		sizeConstraint = UDim2.new(1, -420, 0, 16),
	}), React.createElement(TaskSummary, {
		done = counts.Done,
		total = #quests,
		accent = Palette.cyan,
		reducedMotion = softMotion,
		position = UDim2.new(1, -190, 0, 4),
		size = UDim2.fromOffset(190, 56),
	})), counts.Ready > 0 and React.createElement("frame", {
		Name = "MissionClaimActions",
		Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(200, 44),
		Position = if stack then UDim2.fromOffset(0, introH) else UDim2.new(1, -404, 0, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ref = missionClaimHostRef,
	}, React.createElement(Button, {
		text = `CLAIM ALL · {counts.Ready}`,
		icon = "Gift.4",
		onClick = claimAllReady,
		color = Palette.green,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = softMotion,
		highlight = true,
	})), React.createElement(Browse.BrowseBar, {
		browse = browse,
		placeholder = "Search missions and rewards",
		accent = Palette.cyan,
		stack = stack,
		reducedMotion = softMotion,
		position = UDim2.fromOffset(0, introH + claimRowH + 10),
		zIndex = 40,
	}))
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
		ListEmptyComponent = if #visible == 0 then React.createElement(Browse.NoResults, {
			browse = browse,
			noun = "missions",
			icon = "Mission.6",
			emptyBody = (guide and guide.EmptyNone) or "New dailies land at reset.",
			filteredBody = (guide and guide.EmptyFilter) or "Switch the filter back to All.",
			accent = Palette.cyan,
			reducedMotion = softMotion,
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
exports.TaskSummary = TaskSummary
return exports
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

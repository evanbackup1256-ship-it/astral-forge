local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local _flexbox = require(script.Parent.Parent.flexbox)
local Flex = _flexbox.Flex
local FlexItem = _flexbox.FlexItem
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local _motion = require(script.Parent.Parent.motion)
local useClock = _motion.useClock
local useFlash = _motion.useFlash
local usePulse = _motion.usePulse
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _ui = require(script.Parent.Parent.ui)
local Badge = _ui.Badge
local Button = _ui.Button
local IconTile = _ui.IconTile
local Meter = _ui.Meter
local meterFill = _ui.meterFill
local Panel = _ui.Panel
local ShimmerText = _ui.ShimmerText
local Text = _ui.Text
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local NumberSpinnerHost = require(script.Parent.Parent.NumberSpinnerHost).NumberSpinnerHost
local RebirthPanel = require(script.Parent.RebirthPanel).RebirthPanel
local _theme = require(script.Parent.Parent.theme)
local Layout = _theme.Layout
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local scrollTail = _theme.scrollTail
local surfaceGradient = _theme.surfaceGradient
local TapTarget = _theme.TapTarget
local _format = require(script.Parent.Parent.format)
local asFlux = _format.asFlux
local clockText = _format.clockText
local compactNumber = _format.compactNumber
local gteFlux = _format.gteFlux
local Audio = require(script.Parent.Parent.audio).Audio
local AppHelpers = require(script.Parent.Parent.appNav).AppHelpers
local LayoutSectionPlan = require(script.Parent.Parent.layoutSectionPlan)
local VaultCollectEligibility = require(script.Parent.Parent.vaultCollectEligibility)
local PageReadyMath = require(script.Parent.Parent.pageReadyMath)
local ReleaseClockMath = require(script.Parent.Parent.releaseClockMath)

local function ReleaseCountdown(_param)
	local releaseAt = _param.releaseAt
	local reducedMotion = _param.reducedMotion
	local stack = _param.stack
	local layoutOrder = _param.layoutOrder
	local viewport = useViewport()
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — ReleaseCountdown.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
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
	-- The live release wash and orbit stay on for the whole countdown.
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
			-- ▼ ReadonlyArray.map ▼
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
			-- ▲ ReadonlyArray.map ▲
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
		-- ▼ ReadonlyArray.map ▼
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
		-- ▲ ReadonlyArray.map ▲
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

local LADDER_UNLOCKS = { "Research", "Mail", "Rewards", "Story", "Missions", "Worlds", "Shop", "Milestones", "Wheel", "StarGrid", "Rebirth", "Anomaly", "Crew", "Trade", "Command", "Lab", "Echoes", "Convergence", "Continuum" }

local function ladderUnit(kind: string): string
	if kind == "LifetimeCash" then
		return "flux"
	elseif kind == "MachineLevels" then
		return "levels"
	elseif kind == "Rebirths" then
		return "rebirths"
	elseif kind == "PlayTime" then
		return "sec"
	end
	return ""
end

-- Listed machine rate from config. Matches the workshop card (BaseProduction), not multiplied output.
local function listedFluxPerSec(machine): number
	local base = if type(machine) == "table" then machine.BaseProduction else nil
	if type(base) ~= "number" or base <= 0 then
		return 0
	end
	return base
end

-- First core is paid when run flux hits the prestige bar (ratio 1). Stardust follows the rebirth bag.
local function firstRebirthStardust(config): number
	local economy = if config ~= nil and type(config.Economy) == "table" then config.Economy else nil
	local bag = if economy ~= nil and type(economy.Rebirth) == "table" then economy.Rebirth else nil
	local scale = if type(bag) == "table" and type(bag.StardustSqrtScale) == "number" then bag.StardustSqrtScale else 5
	local minimum = if type(bag) == "table" and type(bag.StardustMinimum) == "number" then bag.StardustMinimum else 4
	return math.max(minimum, math.floor(math.sqrt(1) * scale))
end

local function totalMachineLevels(state): number
	local total = 0
	local machines = state.Machines
	if type(machines) ~= "table" then
		return 0
	end
	for _, level in machines do
		if type(level) == "number" and level > 0 then
			total += level
		end
	end
	return total
end

local function unlockGateLine(state, config, id: string): string?
	local unlocks = state.FeatureUnlocks
	local row = if type(unlocks) == "table" then unlocks[id] else nil
	local rules = if config ~= nil and type(config.Unlocks) == "table" then config.Unlocks else nil
	local rule = if rules ~= nil then rules[id] else nil
	local kind = if type(rule) == "table" and type(rule.Kind) == "string" then rule.Kind else nil
	local name = if type(row) == "table" and type(row.Name) == "string" then row.Name elseif type(rule) == "table" and type(rule.Name) == "string" then rule.Name else id
	local target = if type(row) == "table" and type(row.Target) == "number" then row.Target elseif type(rule) == "table" and type(rule.Target) == "number" then rule.Target else 0
	if kind == "Always" or target <= 0 then
		return nil
	end
	local progress
	if type(row) == "table" and row.Progress ~= nil then
		progress = asFlux(row.Progress)
	elseif kind == "LifetimeCash" then
		progress = asFlux(state.LifetimeCash)
	elseif kind == "MachineLevels" then
		progress = totalMachineLevels(state)
	elseif kind == "Rebirths" then
		progress = math.max(0, math.floor(tonumber(state.Rebirths) or 0))
	elseif kind == "PlayTime" then
		local stats = state.Stats
		progress = math.max(0, math.floor(tonumber(stats and stats.PlayTime) or 0))
	else
		progress = 0
	end
	local unlocked = if type(row) == "table" then row.Unlocked == true else progress >= target
	if unlocked or progress >= target then
		return nil
	end
	local unit = ladderUnit(kind or "")
	local suffix = if unit ~= "" then ` {unit}` else ""
	return `Unlock {name} · {compactNumber(progress)}/{compactNumber(target)}{suffix}`
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
	for _, id in LADDER_UNLOCKS do
		if #lines >= limit then
			break
		end
		push(unlockGateLine(state, config, id))
		if id == "Research" then
			push(nextMachineGateLine(state, config))
		elseif id == "Rebirth" then
			push(rebirthPayoutLine(state, config))
		end
	end
	return lines
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
	-- Canonical softMotion antilag gate — effectsPaused/skipEntrance stay on quietMotion
	-- so decorative Overview stagger can mute without folding pause into reducedMotion.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
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
	local vaultSeconds = _condition
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
	local anomalyReady = PageReadyMath.AnomalyReady(state.Anomaly)
	local opsClaims = PageReadyMath.OpsClaims(missionsReady, labReady, pathReady, anomalyReady)
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
				setOverchargeLeft(left)
				if left <= 0 then
					break
				end
				task.wait(0.05)
			end
		end)
		return function()
			alive = false
			-- The worker exits on its own when the cooldown hits zero. Cancelling a
			-- finished thread throws, which used to fire on the next Overcharge.
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
	local overchargeLabel = if overchargeLeft > 0.02 then `WAIT {string.format("%.1f", overchargeLeft)}s` else "OVERCHARGE"
	local vaultClaimHostRef = React.useRef(nil)
	-- Gamepad: park Selection on COLLECT/OVERCHARGE (FocusClaim prefers Claim-named hosts).
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
	-- Wide PC: vault hero sits beside the metrics column instead of stacking full-width bands.
	local wideOverview = not stack and viewport.width >= 1180
	local ultraOverview = not stack and viewport.width >= 1680
	-- Portrait stacks CTAs under the vault readout; landscape puts them side-by-side so both
	-- stay above the fold on ~320–390px-tall screens. Desktop keeps the right-rail CTA column.
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
	local heroReadoutH = if landscapePhone then 108 elseif phone then 168 else 0
	local phoneCtaBlockH = if landscapePhone then ctaH + 8 else ctaH * 2 + 12
	local opsButtonRows = if stack then 2 else 1
	local opsButtonH = TapTarget * opsButtonRows + (if stack then 8 else 0)
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
		sections = {
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
	}), React.createElement(Text, {
		value = if firstRun then "YOUR FORGE" else "CURRENT RUN",
		size = 11,
		color = if vaultFill >= 0.99 then Palette.mango else Palette.green,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		layoutOrder = 0,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Text, {
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
		color = if vaultFill >= 0.99 then Palette.mango else Palette.green,
		reducedMotion = softMotion,
		shimmer = vaultFill >= 0.99 and not effectsPaused,
		layoutOrder = 3,
		size = UDim2.new(1, 0, 0, 10),
	}), React.createElement(Text, {
		value = if vaultFill >= 0.99 then "Vault full — machines stopped. Collect now." elseif firstRun then "Machines earn Flux into this vault. Collect it, then buy more." else `{compactNumber(state.Production)} Flux per second flowing in`,
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
		-- FocusClaim COLLECT/OVERCHARGE must not clip CTA overshoot.
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
		icon = "Overcharge",
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
		-- FocusClaim COLLECT/OVERCHARGE must not clip CTA overshoot.
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
		icon = "Overcharge",
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
		value = if not showOvercharge then comebackLine elseif overchargeLeft > 0.02 then `Ready in {string.format("%.1f", overchargeLeft)}s` else "Tap for a quick vault burst",
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
		local meterTop = if stack then notesH - (if cta ~= "" then TapTarget + 28 else 28) else notesH - 52
		local bodyRoom = math.max(16, meterTop - 52 - 6)
		local ladderSlots = math.clamp(math.floor(bodyRoom / 13), 1, 3)
		local ladder = if vaultFill >= 0.99 then {} else progressLadder(state, config, ladderSlots)
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
		value = if opsClaims > 0 then `{opsClaims} ready to claim` else ((opsGuide and opsGuide.EmptyClaims) or "Nothing ready to claim — keep forging."),
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
		icon = "Mission",
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
		icon = "Lab",
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
		icon = "Forge",
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
		text = if anomalyReady then "ANOMALY · READY" else "ANOMALY",
		icon = "Anomaly",
		onClick = function()
			local _result = navigate
			if _result ~= nil then
				_result = _result("Anomaly")
			end
			return _result
		end,
		color = if anomalyReady then Palette.pink else Palette.panelSoft,
		textColor = if anomalyReady then Palette.ink else Palette.creamSoft,
		size = if stack then UDim2.new(0.5, -4, 0, TapTarget) else UDim2.new(0.25, -6, 0, TapTarget),
		reducedMotion = reducedMotion,
		highlight = anomalyReady,
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
		value = "Spend this run to rank Domain.",
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
		icon = "Domain",
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
		color = Palette.pink,
		reducedMotion = quietMotion,
		shimmer = domain.CanExpand and not effectsPaused,
		position = UDim2.fromOffset(0, 74),
		size = UDim2.new(1, 0, 0, 8),
	}), React.createElement(Button, {
		text = if domain.CanExpand then "OPEN DOMAIN GATE" else "VIEW REQUIREMENTS",
		icon = "Domain",
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
		},
	})))
end

return {
	OverviewView = OverviewView,
}


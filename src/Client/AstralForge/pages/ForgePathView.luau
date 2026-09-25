local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local Icon = require(script.Parent.Parent.Icon).Icon
local _ui = require(script.Parent.Parent.ui)
local IconTile = _ui.IconTile
local Panel = _ui.Panel
local Button = _ui.Button
local Text = _ui.Text
local Meter = _ui.Meter
local Badge = _ui.Badge
local EmptyState = _ui.EmptyState
local _motion = require(script.Parent.Parent.motion)
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local _theme = require(script.Parent.Parent.theme)
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local Layout = _theme.Layout
local lighten = _theme.lighten
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local FlatList = require(script.Parent.Parent.virtualizedList).FlatList
local _format = require(script.Parent.Parent.format)
local compactNumber = _format.compactNumber
local formatReward = _format.formatReward
local decorateForgePathSteps = require(script.Parent.Parent.types).decorateForgePathSteps
local STEP_ROW_HEIGHT = 168
local STEP_ROW_HEIGHT_STACK = 224
local SPOTLIGHT_H = 148
local SPOTLIGHT_H_STACK = 188
local EMPTY_FORGE_PATH = { ClaimedSteps = {}, XP = 0 }
local function pageGuide(config)
	local guides = config and config.ClientPageGuides
	return if guides ~= nil then guides.ForgePath else nil
end
local function effectLabel(step)
	local noun = step.Noun
	if noun == nil or noun == "" then
		local names = {
			Production = "production", TapPower = "tap power", Capacity = "vault capacity",
			CriticalChance = "critical chance", AutoCollect = "auto-collect rate", Offline = "offline income",
			CriticalMultiplier = "critical multiplier", RebirthMultiplier = "rebirth multiplier",
		}
		noun = names[step.EffectKind] or step.EffectKind
	end
	return `+{step.EffectAmount}% {noun}`
end
local function rewardChips(reward, accent)
	local chips = {}
	if (reward.Cash or 0) > 0 then table.insert(chips, { label = `{compactNumber(reward.Cash)} flux`, icon = "Flux" }) end
	if (reward.Stardust or 0) > 0 then table.insert(chips, { label = `{compactNumber(reward.Stardust)} dust`, icon = "Dust" }) end
	if (reward.Cores or 0) > 0 then table.insert(chips, { label = `{compactNumber(reward.Cores)} cores`, icon = "Core" }) end
	if (reward.Essence or 0) > 0 then table.insert(chips, { label = `{compactNumber(reward.Essence)} essence`, icon = "StarGrid" }) end
	if reward.Boost ~= nil then table.insert(chips, { label = reward.Boost, icon = "Boost" }) end
	local nodes = table.create(#chips)
	for index, chip in chips do
		nodes[index] = React.createElement("frame", {
			key = index, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = darken(accent, 0.55), BorderSizePixel = 0, LayoutOrder = index, ClipsDescendants = false,
		}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 7) }), React.createElement("uigradient", {
			Color = ColorSequence.new(lighten(darken(accent, 0.5), 0.06), darken(accent, 0.2)), Rotation = 90,
		}), React.createElement("uipadding", {
			PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
		}), React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center,
		}), React.createElement("frame", {
			Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = 0, ClipsDescendants = true,
		}, React.createElement(Icon, { kind = chip.icon, color = Palette.cream, accent = accent, size = 16, spin = false, clipSafe = true })), React.createElement("textlabel", {
			Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, BorderSizePixel = 0,
			Text = chip.label, TextColor3 = Palette.cream, TextSize = 11, FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, LayoutOrder = 1,
		}))
	end
	return nodes
end
local function ForgePathRow(_param)
	local step, claimed, unlockedForClaim, affordable, xp = _param.step, _param.claimed, _param.unlockedForClaim, _param.affordable, _param.xp
	local onClaim, reducedMotion, index, stack = _param.onClaim, _param.reducedMotion, _param.index, _param.stack
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — ForgePathRow.
	-- Canonical softMotion antilag gate — ForgePathView.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	local reveal = useStagger(index, reducedMotion, 0.015, 0.12)
	local ready = not claimed and unlockedForClaim and affordable
	local locked = not claimed and not unlockedForClaim
	local accent = if claimed then Palette.muted elseif ready then step.Color else Palette.mango
	local progressFrac = math.clamp(xp / math.max(1, step.XPCost), 0, 1)
	local statusText = if claimed then "CLAIMED" elseif locked then "CLAIM THE PREVIOUS STEP FIRST" else `{compactNumber(math.min(xp, step.XPCost))} / {compactNumber(step.XPCost)} XP`
	local rowH = if stack then STEP_ROW_HEIGHT_STACK else STEP_ROW_HEIGHT
	local textW = if stack then -48 else -200
	return React.createElement("frame", {
		Size = UDim2.new(1, -4, 0, rowH), BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = index, ClipsDescendants = false,
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1), accent = accent, background = Palette.panel, padding = 12, reveal = reveal, highlight = ready, reducedMotion = reducedMotion, clips = false,
	}, React.createElement(IconTile, { kind = step.Icon, accent = if claimed then Palette.muted else step.Color, size = 38, radius = 10, position = UDim2.fromOffset(0, 4), spin = false, reducedMotion = reducedMotion }),
	React.createElement(Text, { value = `STEP {step.Step}`, size = 10, color = if claimed then Palette.muted else step.Color, weight = Enum.FontWeight.Heavy, fit = true, position = UDim2.fromOffset(48, 2), sizeConstraint = UDim2.new(1, textW, 0, 16) }),
	React.createElement(Text, { value = effectLabel(step), size = 14, color = if claimed then Palette.muted else Palette.cream, weight = Enum.FontWeight.Heavy, fit = true, position = UDim2.fromOffset(48, 20), sizeConstraint = UDim2.new(1, textW, 0, 20) }),
	React.createElement(Text, { value = formatReward(step.Reward), size = 10, color = Palette.mango, weight = Enum.FontWeight.Bold, wrap = true, position = UDim2.fromOffset(48, 42), sizeConstraint = UDim2.new(1, textW, 0, 16) }),
	React.createElement("frame", { Size = UDim2.new(1, textW, 0, 26), Position = UDim2.fromOffset(48, 60), BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = false },
		React.createElement("uilistlayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }),
		rewardChips(step.Reward, if claimed then Palette.muted else step.Color)),
	React.createElement(Meter, { value = if claimed then 1 else progressFrac, color = accent, reducedMotion = reducedMotion, shimmer = ready, position = UDim2.fromOffset(0, if stack then 98 else 104), size = UDim2.new(1, if stack then 0 else -200, 0, 8) }),
	React.createElement(Text, { value = statusText, size = 10, color = if ready then step.Color else Palette.muted, weight = Enum.FontWeight.Bold, fit = false, position = UDim2.fromOffset(0, if stack then 112 else 118), sizeConstraint = UDim2.new(1, if stack then 0 else -200, 0, 16) }),
	if stack then (if claimed then React.createElement(Badge, { value = "CLAIMED", accent = Palette.muted, filled = true, size = UDim2.new(1, 0, 0, TapTarget), position = UDim2.new(0, 0, 1, -TapTarget) })
		else React.createElement(Button, { text = if ready then "CLAIM STEP" elseif locked then "LOCKED" else "NEED XP", icon = "Check", onClick = function() return onClaim(step.Step) end, color = if ready then step.Color else Palette.panelSoft, textColor = if ready then Palette.ink else Palette.muted, size = UDim2.new(1, 0, 0, TapTarget), position = UDim2.new(0, 0, 1, -TapTarget), reducedMotion = reducedMotion, disabled = not ready, highlight = ready }))
	else (if claimed then React.createElement(Badge, { value = "CLAIMED", accent = Palette.muted, filled = true, position = UDim2.new(1, -150, 0, 26), size = UDim2.fromOffset(140, 32) })
		else React.createElement(Button, { text = if ready then "CLAIM" elseif locked then "LOCKED" else "NEED XP", icon = "Check", onClick = function() return onClaim(step.Step) end, color = if ready then step.Color else Palette.panelSoft, textColor = if ready then Palette.ink else Palette.muted, size = UDim2.fromOffset(140, 32), position = UDim2.new(1, -150, 0, 26), reducedMotion = reducedMotion, disabled = not ready, highlight = ready }))))
end
local function SpotlightPanel(_param)
	local step, xp, ready, complete, guide = _param.step, _param.xp, _param.ready, _param.complete, _param.guide
	local onClaim, reducedMotion, stack = _param.onClaim, _param.reducedMotion, _param.stack
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — SpotlightPanel.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	local claimHostRef = React.useRef(nil)
	-- Gamepad: park Selection on CLAIM NOW when ready.
	React.useEffect(function()
		if not ready or complete or step == nil or not UserInputService.GamepadEnabled then
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
	end, { ready, complete, if step ~= nil then step.Step else 0 })
	if complete then
		return React.createElement(Panel, { size = UDim2.fromScale(1, 1), accent = Palette.mint, background = Palette.panelRaised, padding = if stack then 14 else 16, clips = false },
			React.createElement(EmptyState, { icon = "Check", title = "Forge Path complete", body = (guide and guide.Complete) or "Path cleared. Permanent bonuses stay through rebirth.", accent = Palette.mint, compact = true, size = UDim2.fromScale(1, 1), reducedMotion = reducedMotion }))
	end
	if step == nil then
		return React.createElement(Panel, { size = UDim2.fromScale(1, 1), accent = Palette.violet, background = Palette.panelRaised, padding = if stack then 14 else 16, clips = false },
			React.createElement(EmptyState, { icon = "Forge", title = "No steps configured", body = "Forge Path steps come from GameConfig.", accent = Palette.violet, compact = true, size = UDim2.fromScale(1, 1), reducedMotion = reducedMotion }))
	end
	local progressFrac = math.clamp(xp / math.max(1, step.XPCost), 0, 1)
	local needXp = not ready and xp < step.XPCost
	return React.createElement(Panel, {
		size = UDim2.fromScale(1, 1), accent = if ready then step.Color else Palette.violet, background = Palette.panelRaised,
		padding = if stack then 14 else 16, highlight = ready, reducedMotion = reducedMotion, clips = false,
	}, React.createElement(Text, { value = if ready then "READY TO CLAIM" else "NEXT STEP", size = 10, color = if ready then step.Color else Palette.violet, weight = Enum.FontWeight.Heavy, sizeConstraint = UDim2.new(1, if stack then 0 else -180, 0, 16) }),
	React.createElement(Text, { value = `Step {step.Step} · {effectLabel(step)}`, size = if stack then 18 else 22, color = Palette.cream, weight = Enum.FontWeight.Heavy, fit = true, position = UDim2.fromOffset(0, 18), sizeConstraint = UDim2.new(1, if stack then 0 else -180, 0, 28) }),
	React.createElement(Text, { value = if needXp then ((guide and guide.NeedXp) or "Earn Forge Path XP by banking flux — it trickles in as you play.") else formatReward(step.Reward), size = 11, color = if needXp then Palette.creamSoft else Palette.mango, wrap = true, position = UDim2.fromOffset(0, 50), sizeConstraint = UDim2.new(1, if stack then 0 else -180, 0, 32) }),
	React.createElement(Meter, { value = progressFrac, color = if ready then step.Color else Palette.violet, reducedMotion = reducedMotion, shimmer = ready, position = UDim2.fromOffset(0, if stack then 96 else 92), size = UDim2.new(1, if stack then 0 else -180, 0, 8) }),
	React.createElement(Text, { value = `{compactNumber(math.min(xp, step.XPCost))} / {compactNumber(step.XPCost)} XP`, size = 10, color = Palette.muted, weight = Enum.FontWeight.Bold, position = UDim2.fromOffset(0, if stack then 110 else 106), sizeConstraint = UDim2.new(1, if stack then 0 else -180, 0, 16) }),
	if stack then React.createElement("frame", { Name = "ForgePathClaimActions", Size = UDim2.new(1, 0, 0, TapTarget), Position = UDim2.new(0, 0, 1, -TapTarget), BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = false, ref = claimHostRef },
		React.createElement(Button, { text = if ready then "CLAIM NOW" else "NEED MORE XP", icon = "Check", onClick = function() return onClaim(step.Step) end, color = if ready then step.Color else Palette.panelSoft, textColor = if ready then Palette.ink else Palette.muted, size = UDim2.fromScale(1, 1), reducedMotion = reducedMotion, disabled = not ready, highlight = ready }))
	else React.createElement("frame", { Name = "ForgePathClaimActions", Size = UDim2.fromOffset(160, TapTarget), Position = UDim2.new(1, -160, 0.5, -TapTarget / 2), BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = false, ref = claimHostRef },
		React.createElement(Button, { text = if ready then "CLAIM NOW" else "NEED XP", icon = "Check", onClick = function() return onClaim(step.Step) end, color = if ready then step.Color else Palette.panelSoft, textColor = if ready then Palette.ink else Palette.muted, size = UDim2.fromScale(1, 1), reducedMotion = reducedMotion, disabled = not ready, highlight = ready })))
end
local function ForgePathViewComponent(_param)
	local state, config, dispatch, reducedMotion = _param.state, _param.config, _param.dispatch, _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local antilag = useAntilag()
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local forgePath = state.ForgePath or EMPTY_FORGE_PATH
	local guide = pageGuide(config)
	local steps = React.useMemo(function()
		local raw = if config ~= nil and config.ForgePath ~= nil then config.ForgePath.Steps else nil
		return decorateForgePathSteps(raw)
	end, { config })
	local claimedSet = {}
	for _, stepId in forgePath.ClaimedSteps do claimedSet[stepId] = true end
	local claimedCount, totalCount = #forgePath.ClaimedSteps, #steps
	local nextStep, nextReady = nil, false
	for _, step in steps do
		if claimedSet[step.Step] == nil then
			local unlocked = step.Step == 1 or claimedSet[step.Step - 1] ~= nil
			if unlocked then nextStep = step; nextReady = forgePath.XP >= step.XPCost; break end
		end
	end
	local pathComplete = totalCount > 0 and claimedCount >= totalCount
	local onClaim = function(step) return dispatch("ClaimForgePathStep", { Step = step }) end
	local headerReveal = useStagger(0, softMotion)
	local listGap = if stack then chrome.panelGap else Layout.panelGap
	local headerH = if stack then 148 else 128
	local spotlightH = if stack then SPOTLIGHT_H_STACK else SPOTLIGHT_H
	local stepRowHeight = if stack then STEP_ROW_HEIGHT_STACK else STEP_ROW_HEIGHT
	local stepsBlockH = if totalCount == 0 then 160 else totalCount * stepRowHeight + math.max(0, totalCount - 1) * listGap
	local progressFrac = if totalCount > 0 then claimedCount / totalCount else 0
	local heroBlurb = (guide and guide.HeroBlurb) or "One track. Every step pays out."
	local stepStride = stepRowHeight + listGap
	local stepsElement = if totalCount == 0 then React.createElement(EmptyState, {
		icon = "Forge",
		title = "Forge Path offline",
		body = "Steps load from GameConfig.ForgePath.Steps.",
		accent = Palette.violet,
		reducedMotion = softMotion,
	}) else React.createElement(FlatList, {
		data = steps,
		itemHeight = stepStride,
		overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
		canvasTail = 8,
		Size = UDim2.fromScale(1, 1),
		scrollBarColor = Palette.violet,
		scrollBarThickness = 4,
		keyExtractor = function(step)
			return step.Step
		end,
		renderItem = function(_param_1)
			local step = _param_1.item
			local index = _param_1.index
			return React.createElement(ForgePathRow, {
				step = step,
				claimed = claimedSet[step.Step] ~= nil,
				unlockedForClaim = step.Step == 1 or claimedSet[step.Step - 1] ~= nil,
				affordable = forgePath.XP >= step.XPCost,
				xp = forgePath.XP,
				onClaim = onClaim,
				reducedMotion = reducedMotion,
				index = index + 1,
				stack = stack,
			})
		end,
	})
	return React.createElement(PageScaffold, {
		gap = listGap,
		tailPad = scrollTail(stack, chrome.bottomSafe, 48),
		scrollBarColor = Palette.violet,
		scrollBarThickness = 4,
		sections = {
			{
				id = "hero",
				height = headerH,
				element = React.createElement(Panel, {
					size = UDim2.fromScale(1, 1), accent = Palette.violet, background = Palette.panelRaised, padding = if stack then 14 else 16,
					reveal = headerReveal, clips = false,
				}, React.createElement(IconTile, { kind = "Forge", accent = Palette.violet, size = if stack then 48 else 56, radius = 14, position = UDim2.fromOffset(0, if stack then 4 else 18), glow = true, spin = false, reducedMotion = softMotion }),
				React.createElement(Text, { value = "FORGE PATH", size = 10, color = Palette.violet, weight = Enum.FontWeight.Heavy, position = UDim2.fromOffset(if stack then 0 else 72, if stack then 60 else 0), sizeConstraint = UDim2.new(1, if stack then -8 else -220, 0, 16) }),
				React.createElement(Text, { value = heroBlurb, size = if stack then 16 else 18, color = Palette.cream, weight = Enum.FontWeight.Heavy, fit = false, wrap = true, position = UDim2.fromOffset(if stack then 0 else 72, if stack then 78 else 16), sizeConstraint = UDim2.new(1, if stack then -8 else -220, 0, 44) }),
				React.createElement(Meter, { value = progressFrac, color = Palette.violet, reducedMotion = softMotion, shimmer = nextReady, position = UDim2.fromOffset(if stack then 0 else 72, if stack then 114 else 56), size = UDim2.new(1, if stack then -8 else -220, 0, 8) }),
				React.createElement(Text, { value = `{claimedCount} / {totalCount} steps claimed  ·  {compactNumber(forgePath.XP)} XP banked`, size = 11, color = Palette.creamSoft, wrap = true, position = UDim2.fromOffset(if stack then 0 else 72, if stack then 126 else 70), sizeConstraint = UDim2.new(1, if stack then -8 else -220, 0, 24) }),
				not stack and React.createElement("frame", { Size = UDim2.new(0, 200, 0, 40), Position = UDim2.new(1, -200, 0.5, -20), BackgroundTransparency = 1, BorderSizePixel = 0 },
					React.createElement(Text, { value = `{compactNumber(forgePath.XP)}`, size = 26, color = Palette.violet, weight = Enum.FontWeight.Heavy, fit = true, position = UDim2.fromOffset(0, 0), sizeConstraint = UDim2.new(1, 0, 0, 32) }),
					React.createElement(Text, { value = "FORGE XP", size = 10, color = Palette.muted, weight = Enum.FontWeight.Bold, fit = true, position = UDim2.fromOffset(0, 34), sizeConstraint = UDim2.new(1, 0, 0, 14) }))),
			},
			{
				id = "spotlight",
				height = spotlightH,
				element = React.createElement(SpotlightPanel, { step = nextStep, xp = forgePath.XP, ready = nextReady, complete = pathComplete, guide = guide, onClaim = onClaim, reducedMotion = reducedMotion, stack = stack }),
			},
			{
				id = "steps",
				fill = true,
				minHeight = math.max(160, stepStride * 2),
				element = stepsElement,
			},
		},
	})
end
local ForgePathView = React.memo(ForgePathViewComponent, function(previous, incoming)
	local prevXp = previous.state.ForgePath and previous.state.ForgePath.XP
	local nextXp = incoming.state.ForgePath and incoming.state.ForgePath.XP
	local prevClaimed = previous.state.ForgePath and #previous.state.ForgePath.ClaimedSteps
	local nextClaimed = incoming.state.ForgePath and #incoming.state.ForgePath.ClaimedSteps
	local prevSteps = previous.config and previous.config.ForgePath and previous.config.ForgePath.Steps
	local nextSteps = incoming.config and incoming.config.ForgePath and incoming.config.ForgePath.Steps
	return previous.dispatch == incoming.dispatch and previous.reducedMotion == incoming.reducedMotion and prevXp == nextXp and prevClaimed == nextClaimed and prevSteps == nextSteps
end)
return { ForgePathView = ForgePathView }

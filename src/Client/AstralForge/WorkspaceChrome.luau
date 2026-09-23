local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local Icon = require(script.Parent.Icon).Icon
local useAntilag = require(script.Parent.antilag).useAntilag
local GamepadNavigationService = require(script.Parent.input.GamepadNavigationService)
local _motion = require(script.Parent.motion)
local EntranceMotionSuppressedContext = _motion.EntranceMotionSuppressedContext
local useFlash = _motion.useFlash
local useTokenEntrance = _motion.useTokenEntrance
local useViewport = _motion.useViewport
local _ui = require(script.Parent.ui)
local Button = _ui.Button
local IconTile = _ui.IconTile
local meterFill = _ui.meterFill
local ScrollEdgeFade = _ui.ScrollEdgeFade
local ShimmerText = _ui.ShimmerText
local Text = _ui.Text
local _theme = require(script.Parent.theme)
local Layout = _theme.Layout
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local ensureContrast = _theme.ensureContrast
local lighten = _theme.lighten
local surfaceGradient = _theme.surfaceGradient
local TapTarget = _theme.TapTarget
local _format = require(script.Parent.format)
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local AppHelpers = require(script.Parent.appNav).AppHelpers
local LayoutSectionPlan = require(script.Parent.layoutSectionPlan)
local VaultCollectEligibility = require(script.Parent.vaultCollectEligibility)

local function VaultPill(_param)
	local state = _param.state
	local reducedMotion = _param.reducedMotion
	local accent = _param.accent
	local top = _param.top
	if top == nil then
		top = 8
	end
	local fill = meterFill(asFlux(state.Vault), asFlux(state.Capacity))
	local ready = VaultCollectEligibility.isEligible(asFlux(state.Vault))
	local full = VaultCollectEligibility.isFull(fill)
	local bar = if full then Palette.mango else accent
	-- This number updates on every production tick for the whole session, so it can't afford a
	-- continuously-running tween -- instead, a brief flash on genuine gains via useFlash (a
	-- short spring that settles and goes idle) gives it a felt reaction without any per-tick
	-- motor cost between updates.
	local gains, setGains = React.useState(0)
	local previousVault = React.useRef(state.Vault)
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — VaultPill flash drops on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	React.useEffect(function()
		if asFlux(state.Vault) > asFlux(previousVault.current) then
			setGains(function(current)
				return current + 1
			end)
		end
		previousVault.current = state.Vault
	end, { state.Vault })
	local vaultFlash = useFlash(gains, softMotion, 0.5)
	local vaultTextColor = vaultFlash:map(function(amount)
		return ensureContrast(Palette.panelRaised, if ready then Palette.cream else Palette.muted):Lerp(bar, amount * 0.7)
	end)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(248, 52),
		Position = UDim2.new(1, -316, 0, top),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 22,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("frame", {
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 13),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = if full then Palette.mango else Palette.lineSoft,
		Thickness = 1,
		Transparency = if full then 0.35 else 0.72,
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.fromOffset(10, 10),
		BackgroundColor3 = darken(bar, 0.62),
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement(Icon, {
		kind = "Vault",
		color = Palette.cream,
		accent = bar,
		size = 18,
		spin = false,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	})), React.createElement(Text, {
		value = compactNumber(state.Vault),
		size = 15,
		color = vaultTextColor,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 12,
		position = UDim2.fromOffset(50, 7),
		sizeConstraint = UDim2.new(1, -62, 0, 20),
	}), React.createElement(Text, {
		value = `of {compactNumber(state.Capacity)}`,
		size = 11,
		color = ensureContrast(Palette.panelRaised, Palette.muted),
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(50, 26),
		sizeConstraint = UDim2.new(1, -62, 0, 14),
	}), React.createElement("frame", {
		Size = UDim2.new(1, -20, 0, 4),
		Position = UDim2.new(0, 10, 1, -8),
		BackgroundColor3 = Palette.line,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = UDim2.new(math.clamp(fill, 0.02, 1), 0, 1, 0),
		BackgroundColor3 = bar,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))))
end
local function NextUnlockStrip(_param)
	local state = _param.state
	local reducedMotion = _param.reducedMotion
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — NextUnlockStrip motion drops on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local goal = AppHelpers:nextUnlock(state)
	local fill = if goal ~= nil then meterFill(goal.Progress, goal.Target) else 1
	local accent = if goal ~= nil then Palette.cyan else Palette.mint
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = Palette.night,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uigradient", {
		Color = surfaceGradient(Palette.night, 0.7),
		Rotation = 90,
	}), React.createElement(Text, {
		value = if goal ~= nil then "NEXT UNLOCK" else "FORGE OPEN",
		size = 9,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(12, 0),
		sizeConstraint = UDim2.new(0, 96, 1, 0),
	}), React.createElement(Text, {
		value = if goal ~= nil then goal.Name else "Every feature unlocked",
		size = 13,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(112, 0),
		sizeConstraint = UDim2.new(0.42, -112, 1, 0),
	}), React.createElement(Text, {
		value = if goal ~= nil then goal.Requirement else "Keep pushing worlds and ranks.",
		size = 11,
		color = Palette.creamSoft,
		fit = true,
		minSize = 10,
		position = UDim2.new(0.42, 8, 0, 0),
		sizeConstraint = UDim2.new(0.58, -20, 1, 0),
	}), React.createElement("frame", {
		Size = UDim2.new(1, -24, 0, 4),
		Position = UDim2.new(0, 12, 1, -5),
		BackgroundColor3 = Palette.line,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = UDim2.new(math.clamp(fill, 0.03, 1), 0, 1, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(accent, 0.28), accent),
	}))))
end
local function Workspace(_param)
	local page = _param.page
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local children = _param.children
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — Workspace entrance drops on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local keyboardCompact = viewport.keyboardOpen
	local _condition = chrome.stack
	if _condition then
		local _condition_1 = state.Settings.MobileCompactHeaders
		if _condition_1 == nil then
			_condition_1 = 1
		end
		_condition = _condition_1 >= 0.5
	end
	local mobileHeaderCompact = _condition
	local accent = AppHelpers:pageAccent(page)
	local entry = AppHelpers:pageEntry(page)
	local enter = useTokenEntrance(page, reducedMotion, 0.2)
	local entranceLock, setEntranceLock = React.useState({
		page = page,
		suppress = false,
	})
	local suppressEntrance = entranceLock.page == page and entranceLock.suppress
	React.useEffect(function()
		setEntranceLock({
			page = page,
			suppress = false,
		})
		local job = task.delay(0.34, function()
			return setEntranceLock({
				page = page,
				suppress = true,
			})
		end)
		return function()
			return task.cancel(job)
		end
	end, { page })
	local inset = if keyboardCompact then 6 elseif chrome.stack then chrome.contentInset else Layout.contentInset
	local showNextGoal = true
	do
		local setting = state.Settings.ShowNextGoal
		if setting == nil then
			setting = 1
		end
		showNextGoal = setting >= 0.5
	end
	local workspacePlan = LayoutSectionPlan.planWorkspace({
		keyboardCompact = keyboardCompact,
		stack = chrome.stack,
		landscape = chrome.landscape,
		workspaceHeaderH = chrome.workspaceHeaderH,
		layoutWorkspaceHeaderHeight = Layout.workspaceHeaderHeight,
		tapTarget = TapTarget,
		showNextGoal = showNextGoal,
	})
	local headerHeight = workspacePlan.headerHeight
	local unlockH = workspacePlan.unlockH
	local vaultBtn = if chrome.stack then TapTarget else 44
	local ready = VaultCollectEligibility.isEligible(asFlux(state.Vault))
	local vaultCollectHostRef = React.useRef(nil)
	-- Gamepad: park Selection on Workspace COLLECT (FocusClaim prefers Claim-named hosts).
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = vaultCollectHostRef.current
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
	end, { ready, page })
	local contentPosition = enter:map(function(amount)
		local t = math.clamp(amount, 0, 1)
		local lift = math.round((1 - t) * 12)
		return UDim2.new(0, inset, 0, headerHeight + unlockH + inset + lift)
	end)
	local revealFade = enter:map(function(amount)
		return 1 - math.clamp(amount, 0, 1)
	end)
	local contentFade = enter:map(function(amount)
		local t = math.clamp(amount, 0, 1)
		return (1 - t) * 0.4
	end)
	local titleLeft = if keyboardCompact then 54 elseif chrome.stack then 66 else 84
	-- Desktop reserves room for the right-side VaultPill (248px wide, anchored at -316): the
	-- title block must stop before it. -392 used to run 8px into the pill; -344 keeps a 6px
	-- clearance on every desktop width.
	local titleReserve = if keyboardCompact then -(titleLeft + vaultBtn + 18) else (if chrome.stack then -(vaultBtn + 18) elseif chrome.tight then -(vaultBtn + 28) else -344) - (titleLeft - (if chrome.stack then 14 else 22))
	local denseHeader = not keyboardCompact and not chrome.landscape and not chrome.stack and headerHeight < 74
	local titleBlockH = if keyboardCompact then 32 elseif chrome.landscape then 28 elseif chrome.stack then 36 elseif denseHeader then 44 else 72
	local headerIconSize = if keyboardCompact then 28 elseif chrome.landscape then 28 elseif chrome.stack then 32 elseif denseHeader then 36 else 48
	local headerTitleY = if keyboardCompact then 6 elseif chrome.landscape then 10 elseif chrome.stack then 12 else math.max(10, math.floor((headerHeight - titleBlockH) / 2))
	local vaultPillY = math.max(8, math.floor((headerHeight - 52) / 2))
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		ZIndex = 5,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.58,
	}), headerHeight > 0 and React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, headerHeight),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ZIndex = 20,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel, 0.58),
		Rotation = 90,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 1, -14),
		BackgroundColor3 = darken(Palette.panel, 0.24),
		BorderSizePixel = 0,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(78, 2),
		Position = UDim2.fromOffset(18, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.04), NumberSequenceKeypoint.new(0.68, 0.18), NumberSequenceKeypoint.new(1, 1) }),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(headerIconSize, headerIconSize),
		Position = enter:map(function(amount)
			return UDim2.fromOffset((if keyboardCompact then 8 elseif chrome.stack then 14 else 20) - math.round((1 - math.clamp(amount, 0, 1)) * 10), math.floor((headerHeight - headerIconSize) / 2))
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 4,
	}, React.createElement(IconTile, {
		kind = entry.icon,
		accent = accent,
		size = headerIconSize,
		radius = 12,
		spin = false,
		reducedMotion = reducedMotion,
		zIndex = 4,
	})), React.createElement("frame", {
		Size = UDim2.new(1, titleReserve, 0, titleBlockH),
		Position = UDim2.fromOffset(titleLeft, headerTitleY),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 3,
	}, React.createElement(ShimmerText, {
		value = if entry.label == "Games" then "Mini Games" elseif entry.label == "Ranks" then "Leaderboards" else entry.label,
		size = if chrome.stack then chrome.titleText elseif denseHeader then 18 else 22,
		color = ensureContrast(Palette.panel, Palette.cream),
		weight = Enum.FontWeight.Heavy,
		fit = false,
		minSize = 14,
		position = enter:map(function(amount)
			return UDim2.new(0, math.round((1 - math.clamp(amount, 0, 1)) * 6), 0, if chrome.landscape then 4 else 2)
		end),
		sizeConstraint = UDim2.new(1, 0, 0, if chrome.landscape then 22 elseif chrome.stack then 24 elseif denseHeader then 22 else 28),
		reducedMotion = reducedMotion,
		enabled = not reducedMotion,
		periodSeconds = 4.2,
	}), not keyboardCompact and not mobileHeaderCompact and not chrome.landscape and React.createElement(Text, {
		value = if page == "Overview" then `World {state.CurrentZone}  /  {compactNumber(state.Production)}/s` else entry.eyebrow,
		size = if chrome.stack then chrome.labelText else 12,
		color = ensureContrast(Palette.panel, accent),
		weight = Enum.FontWeight.Bold,
		wrap = true,
		position = enter:map(function(amount)
			return UDim2.new(0, math.round((1 - math.clamp(amount, 0, 1)) * 10), 0, if chrome.stack then 28 elseif denseHeader then 26 else 32)
		end),
		sizeConstraint = UDim2.new(1, 0, 0, if chrome.stack then 32 elseif denseHeader then 16 else 28),
		transparency = revealFade,
	})), not chrome.stack and React.createElement(VaultPill, {
		state = state,
		reducedMotion = reducedMotion,
		accent = accent,
		top = vaultPillY,
	}), React.createElement("frame", {
		Name = "VaultCollectClaim",
		ref = vaultCollectHostRef,
		Size = UDim2.fromOffset(vaultBtn, vaultBtn),
		Position = UDim2.new(1, -(vaultBtn + 14), 0, math.floor((headerHeight - vaultBtn) / 2)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 22,
		-- FocusClaim COLLECT must not clip CTA overshoot.
		ClipsDescendants = false,
	}, React.createElement(Button, {
		text = "",
		icon = "Collect",
		onClick = function()
			return dispatch("CollectVault")
		end,
		color = if ready then accent else Palette.panelSoft,
		textColor = if ready then Palette.ink else Palette.muted,
		size = UDim2.fromScale(1, 1),
		disabled = not ready,
		reducedMotion = reducedMotion,
		highlight = asFlux(state.Vault) >= asFlux(state.Capacity) * VaultCollectEligibility.NEAR_FULL,
		zIndex = 22,
	}))), unlockH > 0 and React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, unlockH),
		Position = UDim2.fromOffset(0, headerHeight),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 19,
	}, React.createElement(NextUnlockStrip, {
		state = state,
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(1, -inset * 2, 1, -(headerHeight + unlockH + inset * 2)),
		Position = contentPosition,
		BackgroundTransparency = contentFade,
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		ZIndex = 1,
		ClipsDescendants = true,
	}, React.createElement(EntranceMotionSuppressedContext.Provider, {
		value = suppressEntrance,
	}, children), React.createElement(ScrollEdgeFade, {
		color = Palette.ink,
		height = if chrome.stack then 18 else 16,
		zIndex = 200,
	})))
end

return {
	Workspace = Workspace,
	VaultPill = VaultPill,
	NextUnlockStrip = NextUnlockStrip,
}

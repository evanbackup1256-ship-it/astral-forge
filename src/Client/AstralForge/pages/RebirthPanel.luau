local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.Parent.audio).Audio
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local _format = require(script.Parent.Parent.format)
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local gteFlux = _format.gteFlux
local InteractionFeedback = require(script.Parent.Parent.interaction).InteractionFeedback
local _motion = require(script.Parent.Parent.motion)
local useFlash = _motion.useFlash
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.theme)
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local darken = _theme.darken
local _ui = require(script.Parent.Parent.ui)
local Badge = _ui.Badge
local Button = _ui.Button
local IconTile = _ui.IconTile
local Meter = _ui.Meter
local Panel = _ui.Panel
local Text = _ui.Text
local meterFill = _ui.meterFill
local function RebirthPanel(_param)
	local state = _param.state
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
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate (effectsPaused stays a separate decorative mute).
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local stack = chrome.contentStack
	local canRebirth = gteFlux(state.PrestigeReward, 1)
	local target = math.max(1, asFlux(state.NextPrestigeTarget))
	local conversionFlux = math.max(0, asFlux(state.RunCash)) + math.max(0, asFlux(state.Vault))
	local progress = if canRebirth then 1 else meterFill(conversionFlux, target)
	local stardustReward = math.max(1, math.floor(math.sqrt(math.max(0, asFlux(state.PrestigeReward))) * 2))
	local confirming, setConfirming = React.useState(false)
	local busy, setBusy = React.useState(false)
	local shakeToken, setShakeToken = React.useState(0)
	local mountedRef = React.useRef(true)
	local rebirthClaimHostRef = React.useRef(nil)
	local readiness = useFlash(if canRebirth then math.floor(conversionFlux) + 1 else 0, softMotion or effectsPaused, 0.8)
	-- Gamepad: park Selection on REBIRTH/CONFIRM (FocusClaim prefers Confirm/Claim tags).
	React.useEffect(function()
		if not canRebirth or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = rebirthClaimHostRef.current
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
	end, { canRebirth, confirming, busy })
	React.useEffect(function()
		return function()
			mountedRef.current = false
		end
	end, {})
	React.useEffect(function()
		if not canRebirth then
			setConfirming(false)
		end
	end, { canRebirth })
	local rebirth = function()
		if not canRebirth or busy then
			return nil
		end
		if not confirming then
			setConfirming(true)
			Audio:play("preview")
			return nil
		end
		setBusy(true)
		Audio:play("prestige")
		task.delay(0.16, function()
			return Audio:play("domainCrack")
		end)
		task.delay(0.38, function()
			return Audio:play("unlock")
		end)
		InteractionFeedback.reward()
		dispatch("Rebirth", {}, function(response)
			if not mountedRef.current then
				return nil
			end
			setBusy(false)
			if response.ok then
				setConfirming(false)
			else
				setShakeToken(function(token)
					return token + 1
				end)
			end
		end)
	end
	local accent = if confirming then Palette.coral else Palette.violet
	local ctaH = TapTarget
	return React.createElement(Panel, {
		layoutOrder = layoutOrder,
		size = UDim2.new(1, 0, 0, height),
		accent = accent,
		background = if confirming then darken(Palette.coral, 0.92) else Palette.panelRaised,
		padding = if stack then chrome.cardPadding else 18,
		reveal = reveal,
		highlight = (canRebirth or confirming) and not effectsPaused,
		reducedMotion = softMotion or effectsPaused,
		clips = false,
	}, React.createElement(IconTile, {
		kind = "Rebirth",
		accent = accent,
		size = if stack then 52 else 58,
		radius = 16,
		position = UDim2.fromOffset(0, if stack then 4 else 10),
		glow = canRebirth and not effectsPaused,
		spin = canRebirth and not effectsPaused,
		reducedMotion = softMotion or effectsPaused,
	}), React.createElement("frame", {
		Size = if stack then UDim2.new(1, -66, 0, 126) else UDim2.new(1, -(76 + 310), 1, 0),
		Position = UDim2.fromOffset(if stack then 66 else 76, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(Text, {
		value = if confirming then "CHECK YOUR REBIRTH" else "REBIRTH",
		size = 10,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Text, {
		value = if confirming then "Reset this run for permanent power?" else "Turn this run into permanent cores.",
		size = if stack then 19 else 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 21),
		sizeConstraint = UDim2.new(1, 0, 0, 31),
	}), React.createElement(Text, {
		value = if confirming then "You lose flux, machines, and unlocked worlds from this run. You keep research, relics, Stardust, milestones, Domain, and Continuum." else "Run flux and vault flux both count. Every core permanently boosts all future production.",
		size = if stack then 11 else 10,
		color = Palette.creamSoft,
		wrap = true,
		fit = false,
		position = UDim2.fromOffset(0, 57),
		sizeConstraint = UDim2.new(1, 0, 0, if stack then 52 else 38),
	}), not stack and React.createElement(Text, {
		value = `{compactNumber(conversionFlux)} / {compactNumber(target)} flux needed`,
		size = 10,
		color = if canRebirth then Palette.violet else Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, 108),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), not stack and React.createElement(Meter, {
		value = progress,
		color = accent,
		reducedMotion = softMotion or effectsPaused,
		shimmer = canRebirth and not effectsPaused,
		position = UDim2.fromOffset(0, 132),
		size = UDim2.new(1, 0, 0, 9),
	}), not stack and React.createElement(Text, {
		value = if canRebirth then `Ready: +{compactNumber(state.PrestigeReward)} cores and +{compactNumber(stardustReward)} stardust` else `{compactNumber(math.max(0, target - conversionFlux))} convertible flux remaining`,
		size = 10,
		color = if canRebirth then Palette.mint else Palette.muted,
		fit = false,
		position = UDim2.fromOffset(0, 149),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	})), stack and React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 78),
		Position = UDim2.fromOffset(0, 136),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 11),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 1,
		Transparency = 0.52,
	}), React.createElement(Text, {
		value = `{compactNumber(conversionFlux)} / {compactNumber(target)} FLUX NEEDED`,
		size = 10,
		color = if canRebirth then accent else Palette.muted,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(12, 10),
		sizeConstraint = UDim2.new(1, -24, 0, 16),
	}), React.createElement(Meter, {
		value = progress,
		color = accent,
		reducedMotion = softMotion or effectsPaused,
		shimmer = canRebirth and not effectsPaused,
		position = UDim2.fromOffset(12, 34),
		size = UDim2.new(1, -24, 0, 9),
	}), React.createElement(Text, {
		value = if canRebirth then `+{compactNumber(state.PrestigeReward)} cores  ·  +{compactNumber(stardustReward)} stardust` else `{compactNumber(math.max(0, target - conversionFlux))} remaining`,
		size = 10,
		color = if canRebirth then Palette.mint else Palette.muted,
		fit = false,
		position = UDim2.fromOffset(12, 51),
		sizeConstraint = UDim2.new(1, -24, 0, 16),
	})), React.createElement("frame", {
		Size = if stack then UDim2.new(1, 0, 0, 30) else UDim2.fromOffset(286, 30),
		Position = if stack then UDim2.fromOffset(0, 224) else UDim2.new(1, -286, 0, 2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Badge, {
		value = `+{compactNumber(state.PrestigeReward)} CORES`,
		accent = accent,
		filled = canRebirth,
		position = UDim2.fromOffset(0, 0),
		size = UDim2.new(0.48, -4, 0, 26),
	}), React.createElement(Badge, {
		value = `{compactNumber(state.PermanentMultiplier)}× PRODUCTION`,
		accent = Palette.mint,
		position = UDim2.new(0.48, 4, 0, 0),
		size = UDim2.new(0.52, -4, 0, 26),
	})), React.createElement("frame", {
		Name = "RebirthClaimActions",
		Size = if stack then UDim2.new(1, 0, 0, ctaH * 2 + 8) else UDim2.fromOffset(286, ctaH * 2 + 8),
		Position = if stack then UDim2.new(0, 0, 1, -(ctaH * 2 + 8)) else UDim2.new(1, -286, 0, 40),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ref = rebirthClaimHostRef,
	}, React.createElement(Button, {
		text = if busy then "REBIRTHING…" elseif confirming then "CONFIRM REBIRTH" elseif canRebirth then "REBIRTH" else "NOT READY",
		icon = "Rebirth",
		onClick = rebirth,
		color = if canRebirth then accent else Palette.panelSoft,
		textColor = if canRebirth then Palette.ink else Palette.muted,
		size = UDim2.new(1, 0, 0, ctaH),
		reducedMotion = softMotion,
		disabled = not canRebirth or busy,
		loading = busy,
		shakeToken = shakeToken,
		highlight = canRebirth,
	}), React.createElement(Button, {
		text = if confirming then "CANCEL" else "OPEN WORKSHOP",
		icon = if confirming then "Close" else "Forge",
		onClick = if confirming then function()
			return setConfirming(false)
		end else openWorkshop,
		sound = "page",
		color = Palette.panelSoft,
		textColor = Palette.cream,
		outline = true,
		size = UDim2.new(1, 0, 0, ctaH),
		position = UDim2.fromOffset(0, ctaH + 8),
		reducedMotion = softMotion,
		disabled = busy,
	})), canRebirth and not effectsPaused and not softMotion and React.createElement("frame", {
		Size = readiness:map(function(amount)
			return UDim2.fromOffset(18 + amount * 54, 18 + amount * 54)
		end),
		Position = UDim2.new(1, -143, 0, 98),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 8,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 2,
		Transparency = readiness:map(function(amount)
			return 1 - amount * 0.54
		end),
	})))
end
return {
	RebirthPanel = RebirthPanel,
}

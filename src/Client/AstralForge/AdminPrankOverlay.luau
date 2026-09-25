local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useAntilag = require(script.Parent.antilag).useAntilag
local UserInputService = game:GetService("UserInputService")
local GamepadNavigationService = require(script.Parent.input.GamepadNavigationService)
local _motion = require(script.Parent.motion)
local useClock = _motion.useClock
local useRotation = _motion.useRotation
local useViewport = _motion.useViewport
local _theme = require(script.Parent.theme)
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local _ui = require(script.Parent.ui)
local Button = _ui.Button
local Panel = _ui.Panel
local Text = _ui.Text
local HUD_STAGE_KINDS = {
	["InvertHud"] = true,
	["SpinHud"] = true,
	["TinyHud"] = true,
	["GiantHud"] = true,
	["ShakeHud"] = true,
}
local function PrankCard(_param)
	local title = _param.title
	local body = _param.body
	local action = _param.action
	local accent = _param.accent
	local height = _param.height
	local reducedMotion = _param.reducedMotion
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — AdminPrankOverlay.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local onClose = _param.onClose
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local width = if chrome.stack then UDim2.new(1, -math.max(24, chrome.sideSafe * 2 + 16), 0, height) else UDim2.new(0, 420, 0, height)
	return React.createElement("frame", {
		Size = width,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 422,
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = accent,
		background = Palette.panelRaised,
		padding = 18,
		zIndex = 422,
		clips = false,
	}, React.createElement(Text, {
		value = "ASTRAL FORGE",
		size = 10,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Text, {
		value = title,
		size = 20,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		wrap = true,
		sizeConstraint = UDim2.new(1, 0, 0, 48),
		position = UDim2.fromOffset(0, 22),
	}), React.createElement(Text, {
		value = body,
		size = 13,
		color = Palette.creamSoft,
		wrap = true,
		sizeConstraint = UDim2.new(1, 0, 0, 72),
		position = UDim2.fromOffset(0, 74),
	}), React.createElement(Button, {
		text = action,
		onClick = onClose,
		color = accent,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -TapTarget),
		reducedMotion = reducedMotion,
		highlight = true,
	})))
end
local function ConfettiBits()
	local bits = {}
	for index = 0, 27 do
		local accent = if index % 4 == 0 then Palette.mango elseif index % 4 == 1 then Palette.cyan elseif index % 4 == 2 then Palette.pink else Palette.violet
		local _arg0 = React.createElement("frame", {
			key = `bit-{index}`,
			Size = UDim2.fromOffset(9 + (index % 3) * 3, 16 + (index % 2) * 6),
			Position = UDim2.new(((index * 37) % 100) / 100, 0, ((index * 53) % 100) / 100, 0),
			Rotation = (index * 27) % 360,
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			ZIndex = 421,
		})
		table.insert(bits, _arg0)
	end
	return React.createElement(React.Fragment, nil, bits)
end
local function HudPrankStage(_param)
	local prank = _param.prank
	local reducedMotion = _param.reducedMotion
	local children = _param.children
	local _result = prank
	if _result ~= nil then
		_result = _result.kind
	end
	local _condition = _result
	if _condition == nil then
		_condition = ""
	end
	local kind = _condition
	local spinning = kind == "SpinHud"
	local shaking = kind == "ShakeHud"
	local invert = kind == "InvertHud"
	local tiny = kind == "TinyHud"
	local giant = kind == "GiantHud"
	local rotation = useRotation(spinning and not reducedMotion, 80)
	local shake = useClock(shaking and not reducedMotion, 16, math.pi * 2, true)
	local frameRotation = if spinning then (if reducedMotion then 24 else rotation) elseif invert then 180 else 0
	local size = if tiny then UDim2.fromScale(0.4, 0.4) elseif giant then UDim2.fromScale(1.82, 1.82) else UDim2.fromScale(1, 1)
	local restPosition = if tiny or giant then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0, 0)
	local position = if shaking and not reducedMotion then shake:map(function(phase)
		return UDim2.new(0, math.sin(phase * 3.2) * 16, 0, math.cos(phase * 2.5) * 12)
	end) else restPosition
	local anchor = if tiny or giant then Vector2.new(0.5, 0.5) else Vector2.new(0, 0)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = tiny or giant or shaking,
	}, React.createElement("frame", {
		Size = size,
		Position = position,
		AnchorPoint = anchor,
		Rotation = frameRotation,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, children))
end
local function AdminPrankOverlay(_param)
	local prank = _param.prank
	local reducedMotion = _param.reducedMotion
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — AdminPrankOverlay.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	local onClose = _param.onClose
	local kind = prank.kind
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local overlayHostRef = React.useRef(nil)
	local _exp = chrome.bottomSafe
	local _condition = viewport.bottomInset
	if _condition == nil then
		_condition = 0
	end
	local toastInset = math.max(_exp, _condition, 8)
	local now, setNow = React.useState(os.clock())
	React.useEffect(function()
		GamepadNavigationService.BeginOverlayFocus()
		return function()
			GamepadNavigationService.EndOverlayFocus()
		end
	end, {})
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = overlayHostRef.current
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
			task.cancel(job)
		end
	end, { prank.kind })
	React.useEffect(function()
		local worker = task.spawn(function()
			while os.clock() < prank.endsAt do
				task.wait(0.2)
				setNow(os.clock())
			end
			onClose()
		end)
		return function()
			return task.cancel(worker)
		end
	end, { onClose, prank.endsAt, prank.kind })
	local left = math.max(0, prank.endsAt - now)
	local washOn = kind == "DiscoHud" or kind == "RainbowHud"
	local wash = useClock(washOn and not softMotion, 0.42, 1, true)
	local washColor = wash:map(function(alpha)
		return Color3.fromHSV(alpha, if kind == "RainbowHud" then 0.55 else 0.88, 1)
	end)
	local loadSpin = useRotation(kind == "LoadingForever" and not softMotion, 240)
	local caption = if prank.caption ~= nil and prank.caption ~= "" then prank.caption else "CLOWN"
	local stageOnly = HUD_STAGE_KINDS[kind] ~= nil
	local blind = kind == "Blind"
	local fakeBan = kind == "FakeBan"
	local fakeCrash = kind == "FakeCrash"
	local jump = kind == "Jumpscare"
	local confetti = kind == "ConfettiStorm"
	local disco = kind == "DiscoHud"
	local rainbow = kind == "RainbowHud"
	local fakeRebirth = kind == "FakeRebirth"
	local fakeTrade = kind == "FakeTrade"
	local fakeRob = kind == "FakeRob"
	local loading = kind == "LoadingForever"
	local blue = kind == "BlueScreen"
	local battery = kind == "LowBattery"
	local update = kind == "UpdateForced"
	local clown = kind == "ClownTitle"
	local muteToasts = kind == "MuteToasts"
	local emptyBag = kind == "EmptyBagScare"
	local fill = if blind then Palette.void elseif fakeBan or fakeCrash then Palette.ink elseif jump then Palette.coral elseif blue then Color3.fromRGB(0, 94, 184) elseif battery then Palette.void elseif loading then Palette.void elseif confetti then Palette.void elseif clown then Palette.ink else Palette.void
	local fillAlpha = if blind then 0.04 elseif fakeBan or fakeCrash or fakeRebirth or fakeTrade or fakeRob or update or jump then 0.14 elseif blue then 0 elseif battery then 0.28 elseif loading then 0.18 elseif confetti then 0.78 elseif disco or rainbow then 0.48 elseif clown then 0.22 elseif muteToasts then 1 elseif emptyBag then 0.22 elseif stageOnly then 0.86 else 0.7
	local banner = if stageOnly then (if kind == "InvertHud" then "HUD INVERTED" elseif kind == "SpinHud" then "HUD SPINNING" elseif kind == "TinyHud" then "TINY HUD" elseif kind == "GiantHud" then "GIANT HUD" else "HUD SHAKING") else nil
	return React.createElement("frame", {
		ref = overlayHostRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = if washOn then washColor else fill,
		BackgroundTransparency = fillAlpha,
		BorderSizePixel = 0,
		ZIndex = 420,
	}, banner ~= nil and React.createElement(Text, {
		value = `{banner}  {string.format("%.1f", left)}s`,
		size = 16,
		color = Palette.cyan,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.new(1, -24, 0, 24),
		position = UDim2.new(0, 12, 0.06, 0),
	}), fakeBan and React.createElement(PrankCard, {
		title = "You were removed",
		body = "This session was closed by an administrator. You can rejoin from the experience page.",
		action = "OK",
		accent = Palette.coral,
		height = 248,
		reducedMotion = softMotion,
		onClose = onClose,
	}), fakeCrash and React.createElement(PrankCard, {
		title = "Couldn't reach the forge",
		body = "The server stopped answering. Check your connection, then try again.",
		action = "RETRY",
		accent = Palette.mango,
		height = 248,
		reducedMotion = softMotion,
		onClose = onClose,
	}), jump and React.createElement(PrankCard, {
		title = "BEHIND YOU",
		body = "Got you. Admin's bored.",
		action = "OK FINE",
		accent = Palette.coral,
		height = 240,
		reducedMotion = softMotion,
		onClose = onClose,
	}), fakeRebirth and React.createElement(PrankCard, {
		title = "REBIRTH NOW?",
		body = "Fake prompt. You keep everything.",
		action = "NOT TODAY",
		accent = Palette.violet,
		height = 268,
		reducedMotion = softMotion,
		onClose = onClose,
	}), fakeTrade and React.createElement(PrankCard, {
		title = "INCOMING TRADE",
		body = "xXVoidLordXx wants your whole bag for 3 flux. This trade isn't real.",
		action = "DECLINE JOKE",
		accent = Palette.cyan,
		height = 268,
		reducedMotion = reducedMotion,
		onClose = onClose,
	}), fakeRob and React.createElement(PrankCard, {
		title = "WALLET COMPROMISED",
		body = "Flux 0, vault 0, cores 0. Fake card. Your wallet is fine.",
		action = "RECOVER",
		accent = Palette.coral,
		height = 268,
		reducedMotion = reducedMotion,
		onClose = onClose,
	}), update and React.createElement(PrankCard, {
		title = "UPDATE REQUIRED",
		body = "There is no 9.9.9. This screen goes away on its own.",
		action = "REMIND ME NEVER",
		accent = Palette.mango,
		height = 268,
		reducedMotion = reducedMotion,
		onClose = onClose,
	}), confetti and React.createElement(React.Fragment, nil, React.createElement(ConfettiBits), React.createElement(Text, {
		value = "CONFETTI TAX",
		size = 32,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.new(1, -24, 0, 40),
		position = UDim2.new(0, 12, 0.42, 0),
	})), (disco or rainbow) and React.createElement(Text, {
		value = if disco then "DISCO FORGE" else "RAINBOW WASH",
		size = 28,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.new(1, -24, 0, 36),
		position = UDim2.new(0, 12, 0.44, 0),
	}), blind and React.createElement(Text, {
		value = `LIGHTS OUT  {string.format("%.1f", left)}s`,
		size = 16,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.new(1, -24, 0, 24),
		position = UDim2.new(0, 12, 0.9, 0),
	}), loading and React.createElement(React.Fragment, nil, React.createElement("frame", {
		Size = UDim2.fromOffset(52, 52),
		Position = UDim2.new(0.5, 0, 0.38, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Rotation = loadSpin,
		ZIndex = 422,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.cyan,
		Thickness = 4,
	})), React.createElement(Text, {
		value = "SYNCING PROFILE",
		size = 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.new(1, -24, 0, 30),
		position = UDim2.new(0, 12, 0.5, 0),
	}), React.createElement(Text, {
		value = `Fake load. {string.format("%.1f", left)}s left.`,
		size = 13,
		color = Palette.muted,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.new(1, -24, 0, 20),
		position = UDim2.new(0, 12, 0.56, 0),
	}), React.createElement(Button, {
		text = "SKIP JOKE",
		onClick = onClose,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		size = UDim2.new(0.42, 0, 0, 44),
		position = UDim2.new(0.29, 0, 0.66, 0),
		reducedMotion = softMotion,
	})), blue and React.createElement(React.Fragment, nil, React.createElement(Text, {
		value = ":(",
		size = 72,
		color = Palette.white,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Left,
		sizeConstraint = UDim2.new(1, -64, 0, 80),
		position = UDim2.fromOffset(40, 70),
	}), React.createElement(Text, {
		value = "Your forge ran into a problem and needs to restart.",
		size = 18,
		color = Palette.white,
		wrap = true,
		align = Enum.TextXAlignment.Left,
		sizeConstraint = UDim2.new(1, -80, 0, 56),
		position = UDim2.fromOffset(40, 170),
	}), React.createElement(Text, {
		value = `Stop code: ADMIN_PRANK_{string.format("%.0f", left)}`,
		size = 14,
		color = Color3.fromRGB(190, 220, 255),
		align = Enum.TextXAlignment.Left,
		sizeConstraint = UDim2.new(1, -80, 0, 22),
		position = UDim2.fromOffset(40, 240),
	}), React.createElement(Button, {
		text = "THIS IS FAKE",
		onClick = onClose,
		color = Palette.white,
		textColor = Color3.fromRGB(0, 94, 184),
		size = UDim2.new(0.36, 0, 0, 44),
		position = UDim2.new(0, 40, 0, 290),
		reducedMotion = reducedMotion,
		highlight = true,
	})), battery and React.createElement(React.Fragment, nil, React.createElement("frame", {
		Size = UDim2.new(0.72, 0, 0, 18),
		Position = UDim2.new(0.14, 0, 0.08, 0),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ZIndex = 422,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 6),
	}), React.createElement("frame", {
		Size = UDim2.new(0.08, 0, 1, 0),
		BackgroundColor3 = Palette.coral,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 5),
	}))), React.createElement(Text, {
		value = "LOW BATTERY",
		size = 28,
		color = Palette.coral,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.new(1, -24, 0, 36),
		position = UDim2.new(0, 12, 0.42, 0),
	}), React.createElement(Text, {
		value = "Your battery is fine. This bar is fake.",
		size = 14,
		color = Palette.creamSoft,
		wrap = true,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.new(1, -40, 0, 40),
		position = UDim2.new(0, 20, 0.5, 0),
	})), clown and React.createElement(Text, {
		value = string.upper(caption),
		size = 36,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		wrap = true,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.new(1, -32, 0, 120),
		position = UDim2.new(0, 16, 0.38, 0),
	}), muteToasts and React.createElement("frame", {
		Size = UDim2.fromOffset(math.min(280, viewport.width - chrome.sideSafe * 2 - 24), 72),
		Position = UDim2.new(1, -math.max(16, chrome.sideSafe), 1, -math.max(16, toastInset)),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 430,
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.coral,
		background = Palette.panel,
		padding = 12,
		zIndex = 430,
		clips = false,
	}, React.createElement(Text, {
		value = "Could not save",
		size = 13,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	}), React.createElement(Text, {
		value = "The vault is fine. This toast is a joke.",
		size = 11,
		color = Palette.creamSoft,
		wrap = true,
		sizeConstraint = UDim2.new(1, 0, 0, 28),
		position = UDim2.fromOffset(0, 22),
	}))), emptyBag and React.createElement(PrankCard, {
		title = "Inventory",
		body = "0 / 100 bag. No relics. This is a fake empty-bag card — your relics are still there.",
		action = "CLOSE",
		accent = Palette.violet,
		height = 248,
		reducedMotion = reducedMotion,
		onClose = onClose,
	}))
end
return {
	HudPrankStage = HudPrankStage,
	AdminPrankOverlay = AdminPrankOverlay,
}

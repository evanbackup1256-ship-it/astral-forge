--!nonstrict
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ui = require(script.Parent.UiCore)("ui")
local motion = require(script.Parent.MotionKit)("motion")
local Palette = require(script.Parent.CoreKit)("theme").Palette
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local CAS = game:GetService("ContextActionService")
local createElement = React.createElement
local COPY = {
	pending = { "Roblox checkout", "Choose whether to complete the purchase in Roblox's checkout." },
	verifying = { "Confirming your purchase", "Checkout finished. Waiting for the server to save your reward." },
	success = { "Purchase complete", "Your purchase has been confirmed and added to your account." },
	cancelled = { "Purchase cancelled", "Checkout was cancelled. No reward was granted." },
	fail = { "Checkout unavailable", "The purchase could not be completed. Please try again later." },
	delayed = {
		"Receipt still pending",
		"Confirmation is taking longer than usual. A completed purchase will be delivered automatically.",
	},
}
local function PurchaseOverlay(props)
	local phase = props.phase or "hidden"
	local shown = phase ~= "hidden"
	local waiting = phase == "pending" or phase == "verifying"
	local motionSettings = motion.useMotionSettings()
	local softMotion = props.reducedMotion == true or motionSettings.soft == true
	local viewport = motion.useViewport()
	local host = React.useRef(nil)
	local closing = React.useRef(false)
	local latest = React.useRef(props.onDismiss)
	latest.current = props.onDismiss
	local currentPhase = React.useRef(phase)
	currentPhase.current = phase
	local entrance = motion.useBoatTween(if shown then 1 else 0, 0.24, softMotion, motion.easeOutCubic, 0)
	local exit = motion.useExitTransition(softMotion, 0.18, phase == "pending" or phase == "hidden")
	local amount = React.joinBindings({ entrance, exit[1] }):map(function(v)
		return math.min(v[1], v[2])
	end)
	local clock = motion.useClock(shown and not softMotion, 0.35, math.tau)
	local function dismiss()
		if waiting or not shown or closing.current then
			return
		end
		closing.current = true
		Audio:play("purchaseExit")
		exit[3](function()
			if currentPhase.current == phase and latest.current then
				latest.current()
			end
		end)
	end
	React.useEffect(function()
		closing.current = false
		if phase == "success" then
			Audio:play("purchaseResult")
		elseif phase == "fail" then
			Audio:play("error")
		end
	end, { phase })
	React.useEffect(function()
		if not shown then
			return
		end
		GamepadNavigationService.BeginOverlayFocus()
		if not waiting and host.current then
			GamepadNavigationService.FocusClaim(host.current)
		end
		CAS:BindActionAtPriority("AstralPurchaseDismiss", function(_, state)
			if state == Enum.UserInputState.Begin then
				dismiss()
			end
			return Enum.ContextActionResult.Sink
		end, false, 2500, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)
		return function()
			CAS:UnbindAction("AstralPurchaseDismiss")
			GamepadNavigationService.EndOverlayFocus()
		end
	end, { phase, shown, waiting })
	local accent = if phase == "success"
		then Palette.mint
		elseif phase == "fail" then Palette.coral
		elseif phase == "delayed" then Palette.mango
		else Palette.cyan
	local copy = COPY[phase] or COPY.pending
	local short = viewport.height < 460
	local width = math.min(
		if short then 580 else 490,
		math.max(240, viewport.width - 32 - math.max(0, viewport.sideInset or 0) * 2)
	)
	local height = math.min(
		if short then 270 else 400,
		viewport.height - 24 - (viewport.topInset or 0) - (viewport.bottomInset or 0)
	)
	local copyX = if short then 106 else 24
	local titleY = if short then 28 else 180
	local steps = {}
	local progress = if phase == "success" then 3 elseif phase == "verifying" or phase == "delayed" then 2 else 1
	for i, name in { "CHECKOUT", "CONFIRM", "DELIVERED" } do
		steps[name] = createElement("textlabel", {
			Size = UDim2.new(1 / 3, -4, 0, 28),
			Position = UDim2.new((i - 1) / 3, 0, 0, 0),
			BackgroundColor3 = if i <= progress then accent:Lerp(Palette.panelSoft, 0.8) else Palette.panelSoft,
			Text = name,
			TextSize = 11,
			Font = Enum.Font.BuilderSansBold,
			TextColor3 = if i <= progress then accent else Palette.muted,
			BorderSizePixel = 0,
			ZIndex = 412,
		}, createElement("uicorner", { CornerRadius = UDim.new(0, 8) }))
	end
	local hero = {}
	for i = 1, 3 do
		hero["Ring" .. i] = createElement("frame", {
			Size = UDim2.fromScale(1 - i * 0.12, 1 - i * 0.12),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 411,
			Rotation = clock:map(function(t)
				return t * 180 / math.pi * (if i % 2 == 0 then -1 else 1)
			end),
		}, {
			Corner = createElement("uicorner", { CornerRadius = UDim.new(0, if i == 1 then 28 else 18) }),
			Stroke = createElement(
				"uistroke",
				{ Color = accent, Thickness = if i == 1 then 1 else 2, Transparency = 0.3 + i * 0.14 }
			),
		})
	end
	hero.Icon = createElement(Icon, {
		kind = if phase == "success"
			then "Check"
			elseif phase == "cancelled" or phase == "fail" then "Close"
			else "Gift",
		color = Palette.cream,
		accent = accent,
		size = 54,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		spin = false,
	})
	return createElement(
		"frame",
		{
			Name = "PurchaseOverlayHost",
			ref = host,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 400,
			Visible = amount:map(function(v)
				return v > 0.001
			end),
		},
		createElement(ui.OverlayPresence, { amount = amount }, {
			Backdrop = createElement("textbutton", {
				Name = "PurchaseDismissBackdrop",
				Text = "",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Palette.ink,
				BackgroundTransparency = amount:map(function(v)
					return 1 - v * 0.72
				end),
				AutoButtonColor = false,
				Modal = shown,
				Selectable = false,
				ZIndex = 400,
				Event = { Activated = dismiss },
			}),
			Card = createElement("frame", {
				Name = "PurchaseCard",
				Size = UDim2.fromOffset(width, height),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = amount:map(function(v)
					return UDim2.new(0.5, 0, 0.5, (1 - v) * 18)
				end),
				BackgroundColor3 = Palette.panelRaised,
				BorderSizePixel = 0,
				ZIndex = 410,
			}, {
				Corner = createElement("uicorner", { CornerRadius = UDim.new(0, 24) }),
				Stroke = createElement("uistroke", { Color = accent, Thickness = 1.5, Transparency = 0.35 }),
				Hero = createElement("frame", {
					Size = UDim2.fromOffset(if short then 72 else 130, if short then 72 else 130),
					Position = if short then UDim2.fromOffset(22, 32) else UDim2.new(0.5, -65, 0, 28),
					BackgroundTransparency = 1,
					ZIndex = 411,
				}, hero),
				Title = createElement(ui.Text, {
					value = copy[1],
					size = if short then 18 else 25,
					weight = Enum.FontWeight.Heavy,
					color = Palette.cream,
					position = UDim2.fromOffset(copyX, titleY),
					sizeConstraint = UDim2.new(1, -copyX - 24, 0, 40),
					wrap = true,
					zIndex = 412,
				}),
				Detail = createElement(ui.Text, {
					value = props.detail or copy[2],
					size = 14,
					color = Palette.muted,
					position = UDim2.fromOffset(copyX, titleY + 44),
					sizeConstraint = UDim2.new(1, -copyX - 24, 0, 64),
					wrap = true,
					zIndex = 412,
				}),
				Offer = props.label and createElement(ui.Text, {
					value = props.label,
					size = 12,
					color = accent,
					position = UDim2.fromOffset(copyX, titleY - 20),
					sizeConstraint = UDim2.new(1, -copyX - 24, 0, 18),
					zIndex = 412,
				}),
				Steps = createElement("frame", {
					Size = UDim2.new(1, -48, 0, 28),
					Position = UDim2.new(0, 24, 1, -104),
					BackgroundTransparency = 1,
					ZIndex = 412,
				}, steps),
				Action = if waiting
					then createElement(ui.Text, {
						value = if phase == "verifying" then "Saving your reward…" else "Waiting for checkout…",
						size = 13,
						color = accent,
						position = UDim2.new(0, 24, 1, -60),
						sizeConstraint = UDim2.new(1, -48, 0, 48),
						zIndex = 412,
					})
					else createElement(ui.Button, {
						text = if phase == "delayed" then "Continue playing" else "Continue",
						size = UDim2.new(1, -48, 0, 48),
						position = UDim2.new(0, 24, 1, -64),
						color = accent,
						textColor = Palette.ink,
						onClick = dismiss,
						reducedMotion = softMotion,
						zIndex = 413,
						sound = "close",
					}),
			}),
		})
	)
end
return {
	PurchaseOverlay = PurchaseOverlay,
	PURCHASE_RESULT_HOLD = 4,
	PURCHASE_RESULT_HOLD_REDUCED = 4,
	PURCHASE_PENDING_FAILSAFE = 45,
}

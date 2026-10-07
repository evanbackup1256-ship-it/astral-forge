--!nonstrict
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReactRoblox = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["react-roblox"])
local ui = require(script.Parent.UiCore)("ui")
local motion = require(script.Parent.MotionKit)("motion")
local Palette = require(script.Parent.CoreKit)("theme").Palette
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local Players = game:GetService("Players")
local CAS = game:GetService("ContextActionService")
local h = React.createElement
local COPY = {
	pending = { "Purchase in progress", "Waiting for Roblox to finish the purchase." },
	verifying = { "Confirming purchase", "Waiting for your purchase to be saved." },
	success = { "You're all set", "Your purchase is ready to use." },
	cancelled = { "Purchase cancelled", "You can return to the shop whenever you're ready." },
	fail = { "Checkout didn't open", "Please try again in a moment." },
	delayed = { "Still confirming", "A completed purchase will arrive automatically. You can keep playing." },
}

local function cardLayout(width, height, top, bottom, side)
	local usableWidth = math.max(1, width - side * 2 - 24)
	local usableHeight = math.max(1, height - top - bottom - 24)
	return {
		width = math.min(440, usableWidth),
		height = math.min(364, usableHeight),
		offsetY = (top - bottom) / 2,
		compact = usableHeight < 330,
	}
end

local function PurchaseStatus(props)
	local phase = props.phase or "hidden"
	local shown = phase ~= "hidden"
	local waiting = phase == "pending" or phase == "verifying"
	local viewport = motion.useViewport()
	local softMotion = props.reducedMotion == true or motion.useMotionSettings().soft == true
	local host = React.useRef(nil)
	local layer = React.useRef(nil)
	local closing = React.useRef(false)
	local current = React.useRef(props)
	current.current = props
	local entrance = motion.useBoatTween(if shown then 1 else 0, 0.2, softMotion, motion.easeOutCubic, 0)
	local exit = motion.useExitTransition(softMotion, 0.16, shown)
	local amount = React.joinBindings({ entrance, exit[1] }):map(function(values)
		return math.min(values[1], values[2])
	end)
	local clock = motion.useClock(shown and waiting and not softMotion, 1, math.tau)
	local function dismiss()
		if waiting or not shown or closing.current then
			return
		end
		closing.current = true
		local token = props.token
		exit[3](function()
			local latest = current.current
			if latest.phase == phase and latest.token == token and latest.onDismiss then
				latest.onDismiss()
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
	end, { phase, props.token })
	React.useEffect(function()
		if host.current then
			host.current:SetAttribute("LayoutGuardMode", "observe")
		end
		if layer.current then
			layer.current:SetAttribute("LayoutGuardMode", "observe")
		end
	end, {})
	React.useEffect(function()
		if not shown then
			return
		end
		GamepadNavigationService.BeginOverlayFocus()
		if not waiting and host.current then
			GamepadNavigationService.FocusClaim(host.current)
		end
		-- Let Roblox own cancel/back input while its purchase prompt is active.
		if not waiting then
			CAS:BindActionAtPriority("AstralPurchaseDismiss", function(_, state)
				if state == Enum.UserInputState.Begin then
					dismiss()
				end
				return Enum.ContextActionResult.Sink
			end, false, 2500, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)
		end
		return function()
			CAS:UnbindAction("AstralPurchaseDismiss")
			GamepadNavigationService.EndOverlayFocus()
		end
	end, { phase, props.token })
	local accent = if phase == "success"
		then Palette.mint
		elseif phase == "fail" then Palette.coral
		elseif phase == "delayed" then Palette.mango
		else Palette.cyan
	local layout = cardLayout(
		viewport.screenWidth or viewport.width,
		viewport.screenHeight or viewport.height,
		viewport.topInset or 0,
		viewport.bottomInset or 0,
		viewport.sideInset or 0
	)
	local compact = layout.compact
	local copy = COPY[phase] or COPY.pending
	local iconY = if compact then 16 else 28
	local titleY = if compact then 62 else 104
	local dots = {}
	for index = 1, 3 do
		dots["Dot" .. index] = h("frame", {
			Name = "PurchaseDot" .. index,
			Size = UDim2.fromOffset(8, 8),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = clock:map(function(time)
				local bounce = if softMotion then 0 else math.max(0, math.sin(time * 5.2 - (index - 1) * 0.65)) * 7
				return UDim2.fromOffset(18 + (index - 1) * 18, 14 - bounce)
			end),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			ZIndex = 412,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }))
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local vrLayer = playerGui and playerGui:FindFirstChild("AstralForgeVR")
	local vrOverlay = vrLayer
		and workspace:GetAttribute("AstralForgeVRCanvasWidth")
		and vrLayer:FindFirstChild("Overlay")
	local body = h(
		"frame",
		{
			Name = "PurchaseOverlayHost",
			ref = host,
			Size = if vrOverlay then UDim2.new(1, 0, 1, -64) else UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = amount:map(function(value)
				return value > 0.001
			end),
			ZIndex = 400,
		},
		h(ui.OverlayPresence, { amount = amount }, {
			Backdrop = h("textbutton", {
				Name = "PurchaseDismissBackdrop",
				Text = "",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Palette.ink,
				BackgroundTransparency = amount:map(function(value)
					return 1 - value * 0.64
				end),
				AutoButtonColor = false,
				Selectable = false,
				Modal = shown,
				ZIndex = 400,
				Event = { Activated = dismiss },
			}),
			Card = h("frame", {
				Name = "PurchaseCard",
				Size = UDim2.fromOffset(layout.width, layout.height),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, layout.offsetY),
				BackgroundColor3 = Palette.panelRaised,
				BorderSizePixel = 0,
				ZIndex = 410,
			}, {
				Corner = h("uicorner", { CornerRadius = UDim.new(0, 20) }),
				Border = h("uistroke", { Color = Palette.lineSoft, Transparency = 0.3, Thickness = 1 }),
				Scale = h("uiscale", { Scale = amount:map(function(value)
					return 0.96 + value * 0.04
				end) }),
				Body = h("scrollingframe", {
					Name = "PurchaseStatusBody",
					Size = UDim2.new(1, 0, 1, if waiting then -64 else -84),
					CanvasSize = UDim2.fromOffset(0, titleY + 68 + (if compact then 64 else 72) + 8),
					ScrollingDirection = Enum.ScrollingDirection.Y,
					ScrollBarThickness = 2,
					ScrollBarImageColor3 = accent,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ClipsDescendants = true,
					ZIndex = 411,
				}, {
					Status = h(
						"frame",
						{
							Size = UDim2.fromOffset(if compact then 36 else 56, if compact then 36 else 56),
							AnchorPoint = Vector2.new(0.5, 0),
							Position = UDim2.new(0.5, 0, 0, iconY),
							BackgroundTransparency = 1,
							ZIndex = 411,
						},
						h(Icon, {
							kind = if phase == "success" then "Check" elseif phase == "fail" then "Close" else "Shop",
							color = accent,
							accent = accent,
							size = if compact then 36 else 56,
							spin = false,
						})
					),
					Title = h(ui.Text, {
						value = copy[1],
						size = if compact then 21 else 25,
						color = Palette.cream,
						weight = Enum.FontWeight.Heavy,
						align = Enum.TextXAlignment.Center,
						position = UDim2.fromOffset(20, titleY),
						sizeConstraint = UDim2.new(1, -40, 0, 34),
						fit = true,
						minSize = 18,
						zIndex = 412,
					}),
					Offer = h(ui.Text, {
						value = props.label or "",
						size = 13,
						color = accent,
						align = Enum.TextXAlignment.Center,
						position = UDim2.fromOffset(20, titleY + 38),
						sizeConstraint = UDim2.new(1, -40, 0, 22),
						fit = true,
						minSize = 11,
						zIndex = 412,
					}),
					Detail = h(ui.Text, {
						value = props.detail or copy[2],
						size = 14,
						color = Palette.muted,
						align = Enum.TextXAlignment.Center,
						wrap = true,
						position = UDim2.fromOffset(24, titleY + 68),
						sizeConstraint = UDim2.new(1, -48, 0, if compact then 64 else 72),
						zIndex = 412,
					}),
				}),
				Dots = waiting and h("frame", {
					Name = "PurchaseBouncingDots",
					Size = UDim2.fromOffset(72, 28),
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 1, -54),
					BackgroundTransparency = 1,
					ZIndex = 412,
				}, dots),
				Continue = not waiting and h(ui.Button, {
					text = if phase == "delayed" then "Keep playing" else "Continue",
					size = UDim2.new(1, -48, 0, 48),
					position = UDim2.new(0, 24, 1, -68),
					color = accent,
					textColor = Palette.ink,
					onClick = dismiss,
					reducedMotion = softMotion,
					zIndex = 413,
					sound = "purchaseExit",
				}),
			}),
		})
	)
	if vrOverlay then
		return ReactRoblox.createPortal(body, vrOverlay)
	end
	return ReactRoblox.createPortal(
		h("screengui", {
			Name = "AstralForgePurchase",
			ref = layer,
			IgnoreGuiInset = true,
			ScreenInsets = Enum.ScreenInsets.None,
			ResetOnSpawn = false,
			DisplayOrder = 100,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}, body),
		playerGui
	)
end

local function PurchaseOverlay(props)
	-- A new status owns a fresh exit transition, including late confirmation during dismissal.
	local statusProps = table.clone(props)
	statusProps.key = tostring(props.token) .. ":" .. tostring(props.phase)
	return h(PurchaseStatus, statusProps)
end

return {
	PurchaseOverlay = PurchaseOverlay,
	cardLayout = cardLayout,
	PURCHASE_RESULT_HOLD = 4,
	PURCHASE_RESULT_HOLD_REDUCED = 4,
	PURCHASE_PENDING_FAILSAFE = 45,
}

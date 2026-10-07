--!nonstrict
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Marketplace = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local SharedData = require(game.ReplicatedStorage.AstralForge.Shared.SharedData)
local Catalog = SharedData("MonetizationConfig")
local ui = require(script.Parent.UiCore)("ui")
local motion = require(script.Parent.MotionKit)("motion")
local Palette = require(script.Parent.CoreKit)("theme").Palette
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local Icon = require(script.Parent.ArtKit)("Icon").Icon
local PageScaffold = require(script.Parent.LayoutKit)("pageScaffold").PageScaffold
local PurchaseOverlay = require(script.Parent.PurchasePresentation).PurchaseOverlay
local Signals = require(script.Parent.PurchaseSignals)
local Session = require(script.Parent.PurchaseSession)
local h = React.createElement
local dispatchShop = nil
local prices = {}
local TAB_OPTIONS = {
	{ id = "Featured", label = "Featured" },
	{ id = "Passes", label = "Passes" },
	{ id = "Packs", label = "Packs" },
	{ id = "Codes", label = "Codes" },
}
local checkout = Session.new({
	schedule = function(seconds, callback)
		local job = task.delay(seconds, callback)
		return function()
			pcall(task.cancel, job)
		end
	end,
	prompt = function(kind, id)
		if kind == "pass" then
			Marketplace:PromptGamePassPurchase(Players.LocalPlayer, id)
		else
			Marketplace:PromptProductPurchase(Players.LocalPlayer, id)
		end
	end,
	verifyPass = function(key, done)
		if dispatchShop then
			dispatchShop("SyncShop", {}, function(response)
				done(
					type(response) == "table"
						and response.ok == true
						and type(response.OwnedPasses) == "table"
						and response.OwnedPasses[key] == true
				)
			end)
		end
	end,
})
-- Bind once per client lifetime, not once per shop mount.
Signals.subscribe(checkout.receipt)
Marketplace.PromptProductPurchaseFinished:Connect(function(userId, id, purchased)
	if userId == Players.LocalPlayer.UserId then
		checkout.promptFinished("product", id, purchased)
	end
end)
Marketplace.PromptGamePassPurchaseFinished:Connect(function(player, id, purchased)
	if player == Players.LocalPlayer then
		checkout.promptFinished("pass", id, purchased)
	end
end)

local function catalogOffers(tab)
	local list = {}
	if tab == "Passes" or tab == "Featured" then
		for _, offer in Catalog.GamePasses do
			if tab ~= "Featured" or #list < 2 then
				table.insert(list, { kind = "pass", offer = offer })
			end
		end
	end
	if tab == "Packs" or tab == "Featured" then
		local packs = 0
		for _, offer in Catalog.DevProducts do
			if not offer.Donation and (tab ~= "Featured" or packs < 4) then
				table.insert(list, { kind = "product", offer = offer })
				packs += 1
			end
		end
	end
	return list
end

local function shopLayout(width)
	local content = math.max(1, math.min(1040, width - 24))
	local columns = if content >= 880 then 3 elseif content >= 570 then 2 else 1
	return {
		width = content,
		columns = columns,
		gap = 16,
		cardHeight = 264,
		tabHeight = if content < 570 then 104 else 48,
	}
end

local function OfferCard(props)
	local offer = props.entry.offer
	local pass = props.entry.kind == "pass"
	local id = if pass then offer.PassId else offer.ProductId
	local accent = Color3.fromRGB(table.unpack(offer.Accent or { 255, 191, 78 }))
	local data = prices[props.entry.kind .. tostring(id)]
	local available = id > 0 and (data == nil or data.IsForSale ~= false)
	local cost = if data and type(data.PriceInRobux) == "number" then `R$ {data.PriceInRobux}` else "View price"
	return h(ui.Panel, {
		size = UDim2.fromScale(1, 1),
		padding = 16,
		accent = accent,
		background = Palette.panelRaised,
		reducedMotion = props.soft,
		clips = true,
	}, {
		Icon = h("frame", {
			Size = UDim2.fromOffset(42, 42),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 0),
			BackgroundTransparency = 1,
		}, h(Icon, { kind = offer.Icon or "Shop", color = accent, accent = accent, size = 42, spin = false })),
		Name = h(ui.Text, {
			value = offer.Name,
			size = 19,
			weight = Enum.FontWeight.Heavy,
			color = Palette.cream,
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(0, 52),
			sizeConstraint = UDim2.new(1, 0, 0, 28),
			fit = true,
			minSize = 14,
		}),
		Type = h(ui.Text, {
			value = if pass then "PERMANENT PASS" else "ONE-TIME PACK",
			size = 11,
			color = accent,
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(0, 84),
			sizeConstraint = UDim2.new(1, 0, 0, 18),
		}),
		Detail = h(ui.Text, {
			value = offer.Description,
			size = 14,
			fit = true,
			minSize = 12,
			color = Palette.muted,
			wrap = true,
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(0, 108),
			sizeConstraint = UDim2.new(1, 0, 0, 60),
		}),
		Action = h(ui.Button, {
			text = if props.owned then "Owned" elseif not available then "Unavailable" else cost,
			size = UDim2.new(1, 0, 0, 48),
			position = UDim2.new(0, 0, 1, -52),
			disabled = props.owned or not available or props.busy,
			color = if props.owned then Palette.panelSoft else accent,
			textColor = if props.owned then Palette.muted else Palette.ink,
			reducedMotion = props.soft,
			sound = "purchasePress",
			onClick = function()
				checkout.begin(offer, props.entry.kind)
			end,
		}),
	})
end

local function PremiumShop(props)
	local state = props.state or {}
	local viewport = motion.useViewport()
	local reducedMotion = props.reducedMotion == true
	local softMotion = reducedMotion or motion.useMotionSettings().soft == true
	local tab, setTab = React.useState("Featured")
	local code, setCode = React.useState("")
	local feedback, setFeedback = React.useState("")
	local redeemBusy, setRedeemBusy = React.useState(false)
	local _, refreshPrice = React.useReducer(function(value)
		return value + 1
	end, 0)
	local purchase, setPurchase = React.useState(checkout.snapshot())
	local measured, setMeasured = React.useState(math.max(1, viewport.width - 100))
	local outer = React.useRef(nil)
	local shopHostRef = React.useRef(nil)
	local redeemToken = React.useRef(0)
	local redeemLatch = React.useRef(false)
	local mounted = React.useRef(true)
	local presentationCallback = React.useRef(props.onPurchasePresentationChange)
	presentationCallback.current = props.onPurchasePresentationChange
	local owned = state.Shop and state.Shop.OwnedPasses or {}
	React.useEffect(function()
		dispatchShop = props.dispatch
		checkout.reconcile(owned)
	end, { props.dispatch, owned })
	React.useEffect(function()
		mounted.current = true
		local off = checkout.subscribe(setPurchase)
		props.dispatch("SyncShop")
		return function()
			mounted.current = false
			redeemToken.current += 1
			off()
			if presentationCallback.current then
				presentationCallback.current(false)
			end
		end
	end, {})
	React.useEffect(function()
		if presentationCallback.current then
			presentationCallback.current(purchase.phase ~= "hidden")
		end
	end, { purchase.phase })
	React.useEffect(function()
		local frame = outer.current
		if not frame then
			return
		end
		local function measure()
			setMeasured(math.max(1, frame.AbsoluteSize.X))
		end
		measure()
		local connection = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
		return function()
			connection:Disconnect()
		end
	end, {})
	React.useEffect(function()
		local active = true
		local worker = task.spawn(function()
			local all = catalogOffers("Passes")
			for _, entry in catalogOffers("Packs") do
				table.insert(all, entry)
			end
			for _, entry in all do
				if not active then
					return
				end
				local id = if entry.kind == "pass" then entry.offer.PassId else entry.offer.ProductId
				local key = entry.kind .. tostring(id)
				if id > 0 and prices[key] == nil then
					local ok, result = pcall(function()
						return Marketplace:GetProductInfo(
							id,
							if entry.kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
						)
					end)
					if ok and type(result) == "table" then
						prices[key] = result
						if active then
							refreshPrice()
						end
					end
					task.wait(0.08)
				end
			end
		end)
		return function()
			active = false
			pcall(task.cancel, worker)
		end
	end, {})
	React.useEffect(function()
		if shopHostRef.current then
			GamepadNavigationService.FocusClaim(shopHostRef.current)
		end
	end, { tab, purchase.phase })
	local function redeem()
		local trimmed = string.match(code, "^%s*(.-)%s*$") or ""
		if redeemLatch.current or purchase.awaiting or trimmed == "" then
			return
		end
		redeemLatch.current = true
		setRedeemBusy(true)
		setFeedback("Checking code…")
		redeemToken.current += 1
		local token = redeemToken.current
		local function finish(response)
			if not mounted.current or token ~= redeemToken.current then
				return
			end
			redeemToken.current += 1
			redeemLatch.current = false
			setRedeemBusy(false)
			local result = if type(response) == "table" then response else {}
			local ok = result.ok == true
			setFeedback(
				if ok then result.message or "Reward claimed." else result.error or "Code could not be checked."
			)
			if ok then
				setCode("")
			end
		end
		task.delay(12, function()
			finish({ error = "No response yet. Check your rewards before trying again." })
		end)
		local ok = pcall(props.dispatch, "RedeemCode", { Code = trimmed }, finish)
		if not ok then
			finish({ error = "Connection interrupted. Please try again." })
		end
	end
	local layout = shopLayout(measured)
	local offers = catalogOffers(tab)
	local sections = {
		{
			id = "heading",
			height = 90,
			element = h("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
				Title = h(ui.Text, {
					value = "Premium shop",
					size = 28,
					weight = Enum.FontWeight.Heavy,
					align = Enum.TextXAlignment.Center,
					sizeConstraint = UDim2.new(1, 0, 0, 36),
				}),
				Detail = h(ui.Text, {
					value = "Permanent passes and resource packs.",
					size = 14,
					color = Palette.muted,
					wrap = true,
					align = Enum.TextXAlignment.Center,
					position = UDim2.fromOffset(0, 44),
					sizeConstraint = UDim2.new(1, 0, 0, 40),
				}),
			}),
		},
		{
			id = "tabs",
			height = layout.tabHeight,
			element = h(ui.SegmentedTabs, {
				options = TAB_OPTIONS,
				value = tab,
				onChange = setTab,
				columns = if layout.columns == 1 then 2 else 4,
				gap = 8,
				size = UDim2.fromScale(1, 1),
				accent = Palette.mango,
				reducedMotion = softMotion,
			}),
		},
	}
	if purchase.awaiting and purchase.phase == "hidden" then
		table.insert(sections, {
			id = "pendingPurchase",
			height = 100,
			element = h(ui.Panel, {
				size = UDim2.fromScale(1, 1),
				padding = 12,
				accent = Palette.cyan,
				reducedMotion = softMotion,
			}, {
				Message = h(ui.Text, {
					value = "A purchase is still confirming. Your rewards will arrive automatically.",
					size = 13,
					wrap = true,
					fit = true,
					minSize = 11,
					align = Enum.TextXAlignment.Center,
					sizeConstraint = UDim2.new(1, 0, 0, 30),
				}),
				Status = h(ui.Button, {
					text = "View purchase status",
					size = UDim2.new(1, 0, 0, 40),
					position = UDim2.fromOffset(0, 36),
					color = Palette.cyan,
					textColor = Palette.ink,
					reducedMotion = softMotion,
					onClick = checkout.resume,
				}),
			}),
		})
	end
	if tab == "Codes" then
		table.insert(sections, {
			id = "codes",
			height = 240,
			element = h(ui.Panel, {
				size = UDim2.fromScale(1, 1),
				padding = 20,
				accent = Palette.mango,
				reducedMotion = softMotion,
			}, {
				Title = h(ui.Text, {
					value = "Redeem a code",
					size = 22,
					weight = Enum.FontWeight.Heavy,
					align = Enum.TextXAlignment.Center,
					sizeConstraint = UDim2.new(1, 0, 0, 30),
				}),
				Input = h(ui.SearchField, {
					value = code,
					onChange = setCode,
					placeholder = "Enter code",
					size = UDim2.new(1, 0, 0, 48),
					position = UDim2.fromOffset(0, 44),
					reducedMotion = softMotion,
				}),
				ActionHost = h(
					"frame",
					{
						Name = "ShopClaimCode",
						ClipsDescendants = false,
						ref = if tab == "Codes" then shopHostRef else nil,
						Size = UDim2.new(1, 0, 0, 48),
						Position = UDim2.fromOffset(0, 104),
						BackgroundTransparency = 1,
					},
					h(ui.Button, {
						text = "Redeem",
						onClick = redeem,
						loading = redeemBusy,
						disabled = purchase.awaiting == true or string.match(code, "^%s*$") ~= nil,
						size = UDim2.fromScale(1, 1),
						color = Palette.mango,
						textColor = Palette.ink,
						reducedMotion = softMotion,
					})
				),
				Feedback = h(ui.Text, {
					value = feedback,
					size = 14,
					color = Palette.muted,
					wrap = true,
					align = Enum.TextXAlignment.Center,
					position = UDim2.fromOffset(0, 166),
					sizeConstraint = UDim2.new(1, 0, 0, 32),
				}),
			}),
		})
	else
		for first = 1, #offers, layout.columns do
			local cells = {}
			local count = math.min(layout.columns, #offers - first + 1)
			local cellWidth = (layout.width - (layout.columns - 1) * layout.gap) / layout.columns
			local rowWidth = count * cellWidth + (count - 1) * layout.gap
			for column = 1, count do
				local entry = offers[first + column - 1]
				cells[entry.kind .. entry.offer.Key] = h(
					"frame",
					{
						Size = UDim2.fromOffset(cellWidth, layout.cardHeight),
						Position = UDim2.fromOffset(
							(layout.width - rowWidth) / 2 + (column - 1) * (cellWidth + layout.gap),
							0
						),
						BackgroundTransparency = 1,
					},
					h(OfferCard, {
						entry = entry,
						owned = entry.kind == "pass" and owned[entry.offer.Key] == true,
						busy = purchase.busy or redeemBusy or purchase.awaiting == true,
						soft = softMotion,
					})
				)
			end
			table.insert(sections, {
				id = "row" .. first,
				height = layout.cardHeight,
				element = h("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, cells),
			})
		end
	end
	return h(
		"frame",
		{ Name = "ShopViewHost", ref = outer, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 },
		{
			Content = h(
				"frame",
				{
					ref = if tab ~= "Codes" then shopHostRef else nil,
					Size = UDim2.new(0, layout.width, 1, 0),
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0),
					BackgroundTransparency = 1,
				},
				h(PageScaffold, {
					sections = sections,
					gap = layout.gap,
					tailPad = 28,
					scrollBarColor = Palette.mango,
					scrollBarThickness = 4,
				})
			),
			Purchase = h(PurchaseOverlay, {
				phase = purchase.phase,
				token = purchase.token,
				label = purchase.label,
				detail = purchase.detail,
				reducedMotion = softMotion,
				onDismiss = checkout.dismiss,
			}),
		}
	)
end

return { ShopView = PremiumShop, shopLayout = shopLayout, catalogOffers = catalogOffers }

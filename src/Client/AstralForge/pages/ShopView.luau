local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local _flexbox = require(script.Parent.Parent.flexbox)
local FlexGrid = _flexbox.FlexGrid
local useShopColumns = _flexbox.useShopColumns
local Icon = require(script.Parent.Parent.Icon).Icon
local easeOutCubic = require(script.Parent.Parent.motion).easeOutCubic
local _motion = require(script.Parent.Parent.motion)
local useBoatTween = _motion.useBoatTween
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local PurchaseOverlay = require(script.Parent.Parent.purchaseOverlay).PurchaseOverlay
local _theme = require(script.Parent.Parent.theme)
local Layout = _theme.Layout
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local darken = _theme.darken
local TapTarget = _theme.TapTarget
local scrollTail = _theme.scrollTail
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local _ui = require(script.Parent.Parent.ui)
local Badge = _ui.Badge
local Button = _ui.Button
local EmptyState = _ui.EmptyState
local IconTile = _ui.IconTile
local Panel = _ui.Panel
local SectionLabel = _ui.SectionLabel
local SegmentedTabs = _ui.SegmentedTabs
local Text = _ui.Text
local FlatList = require(script.Parent.Parent.virtualizedList).FlatList
local ClientLog = require(script.Parent.Parent.log).ClientLog
local Audio = require(script.Parent.Parent.audio).Audio
local SHOP_TABS = { "Featured", "Passes", "Supplies", "Codes" }
local SHOP_TAB_TIPS = {
	Featured = "What's on sale.",
	Passes = "Permanent upgrades. Buy once, keep forever.",
	Supplies = "One-time packs — flux, dust, boosts, and extras.",
	Codes = "Type a promo code for a free reward.",
}
local PRODUCT_PENDING_FAILSAFE = 40
local REDEEM_DEBOUNCE = 0.85
local function loadMonetization()
	local astral = ReplicatedStorage:WaitForChild("AstralForge", 12)
	local _shared = astral
	if _shared ~= nil then
		_shared = _shared:WaitForChild("Shared", 6)
	end
	local shared = _shared
	local _catalogModule = shared
	if _catalogModule ~= nil then
		_catalogModule = _catalogModule:WaitForChild("MonetizationConfig", 6)
	end
	local catalogModule = _catalogModule
	if catalogModule == nil or not catalogModule:IsA("ModuleScript") then
		ClientLog:warn("shop", "shop catalog missing")
		return {
			DevProducts = {},
			GamePasses = {},
		}
	end
	local loaded, result = pcall(function()
		return require(catalogModule)
	end)
	if not loaded then
		ClientLog:warn("shop", `couldn't load shop catalog: {tostring(result)}`)
		return {
			DevProducts = {},
			GamePasses = {},
		}
	end
	return result
end
local EMPTY_CATALOG = {
	DevProducts = {},
	GamePasses = {},
}
local function useMonetization()
	local catalog, setCatalog = React.useState(EMPTY_CATALOG)
	React.useEffect(function()
		local alive = true
		local worker = task.spawn(function()
			local loaded = loadMonetization()
			if alive then
				setCatalog(loaded)
			end
		end)
		return function()
			alive = false
			pcall(function()
				return task.cancel(worker)
			end)
		end
	end, {})
	return catalog
end
local SCROLL_PAD = 16 + 16
local TAB_LABELS = {
	Featured = "Picks",
	Passes = "Passes",
	Supplies = "Packs",
	Codes = "Codes",
}
-- ▼ ReadonlyArray.map ▼
local _newValue = table.create(#SHOP_TABS)
local _callback = function(id)
	return {
		id = id,
		label = TAB_LABELS[id],
	}
end
for _k, _v in SHOP_TABS do
	_newValue[_k] = _callback(_v, _k - 1, SHOP_TABS)
end
-- ▲ ReadonlyArray.map ▲
local SHOP_TAB_OPTIONS = _newValue
local function accentOf(rgb)
	local _condition = rgb[1]
	if _condition == nil then
		_condition = 255
	end
	local _condition_1 = rgb[2]
	if _condition_1 == nil then
		_condition_1 = 255
	end
	local _condition_2 = rgb[3]
	if _condition_2 == nil then
		_condition_2 = 255
	end
	return Color3.fromRGB(_condition, _condition_1, _condition_2)
end
local function iconOf(name)
	local known = { "Dust", "Flux", "Forge", "Core", "StarGrid", "Research", "Vault", "Shop", "Gift", "Chat" }
	for _, entry in known do
		if entry == name then
			return entry
		end
	end
	return "Shop"
end
local function rewardLine(reward)
	local parts = {}
	if reward.Cash ~= nil then
		local _arg0 = `{reward.Cash} flux`
		table.insert(parts, _arg0)
	end
	if reward.Stardust ~= nil then
		local _arg0 = `{reward.Stardust} stardust`
		table.insert(parts, _arg0)
	end
	if reward.Cores ~= nil then
		local _arg0 = `{reward.Cores} cores`
		table.insert(parts, _arg0)
	end
	if reward.Boost ~= nil then
		local _arg0 = `{reward.Boost} boost`
		table.insert(parts, _arg0)
	end
	if reward.Signals ~= nil then
		local _arg0 = `{reward.Signals} signals`
		table.insert(parts, _arg0)
	end
	if reward.CashMinutes ~= nil then
		local _arg0 = `{reward.CashMinutes}m of production`
		table.insert(parts, _arg0)
	end
	return if #parts > 0 then table.concat(parts, " · ") else "Bonus stash"
end
local function passBenefitLine(pass)
	local parts = {}
	if pass.ProductionBonus ~= nil then
		local _arg0 = `+{math.floor(pass.ProductionBonus * 100)}% output`
		table.insert(parts, _arg0)
	end
	if pass.CapacityBonus ~= nil then
		local _arg0 = `+{math.floor(pass.CapacityBonus * 100)}% vault`
		table.insert(parts, _arg0)
	end
	if pass.Key == "AutoSalvage" then
		table.insert(parts, "Configurable relic recycling")
	end
	return if #parts > 0 then table.concat(parts, " · ") else "Permanent account upgrade"
end
local function priceText(label, studioPrice, offerId)
	if offerId > 0 then
		return `{label}{studioPrice}`
	end
	if RunService:IsStudio() then
		return `Test · {studioPrice}`
	end
	return "Unavailable"
end
local function TabPane(_param)
	local reducedMotion = _param.reducedMotion
	local height = _param.height
	local children = _param.children
	local enter = useBoatTween(1, if reducedMotion then 0.01 else 0.12, reducedMotion, easeOutCubic, 0)
	local slide = enter:map(function(amount)
		return UDim2.new(0, 0, 0, math.round((1 - math.clamp(amount, 0, 1)) * 10))
	end)
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = slide,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, children))
end
local function OfferTile(_param)
	local title = _param.title
	local detail = _param.detail
	local meta = _param.meta
	local accent = _param.accent
	local icon = _param.icon
	local cta = _param.cta
	local disabled = _param.disabled
	local owned = _param.owned
	local onClick = _param.onClick
	local layoutOrder = _param.layoutOrder
	local reducedMotion = _param.reducedMotion
	local staggerIndex = _param.staggerIndex
	local packed = _param.packed
	if packed == nil then
		packed = false
	end
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = packed or chrome.contentStack
	local reveal = useStagger(staggerIndex, reducedMotion, 0.036, 0.26)
	local canBuy = owned ~= true and not disabled
	local rowH = if packed then 244 elseif stack then 184 else 168
	local ctaH = if stack then TapTarget else 44
	return React.createElement("frame", {
		Size = if packed then UDim2.fromScale(1, 1) else UDim2.new(1, -4, 0, rowH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ClipsDescendants = false,
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = accent,
		background = Palette.panelRaised,
		padding = if packed then 12 else 16,
		reveal = reveal,
		interactive = owned ~= true,
		reducedMotion = reducedMotion,
		clips = false,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(50, 50),
		Position = UDim2.fromOffset(0, if stack then 0 else 8),
		BackgroundColor3 = darken(accent, 0.32),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 1.5,
		Transparency = 0.28,
	}), React.createElement(Icon, {
		kind = icon,
		color = Palette.cream,
		accent = accent,
		size = 32,
		position = UDim2.fromOffset(9, 9),
		reducedMotion = reducedMotion,
		spin = false,
	})), React.createElement("frame", {
		Size = if stack then UDim2.new(1, if packed then 0 else -64, 0, if packed then 78 else 86) else UDim2.new(1, -174, 0, 96),
		Position = UDim2.fromOffset(if packed then 0 else 64, if packed then 56 elseif stack then 0 else 6),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement(Text, {
		value = title,
		size = if packed then 15 elseif stack then 17 else 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		sizeConstraint = UDim2.new(1, 0, 0, 22),
	}), React.createElement(Text, {
		value = detail,
		size = if stack then chrome.labelText else 11,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 24),
		sizeConstraint = UDim2.new(1, 0, 0, if packed then 32 else 38),
	}), React.createElement(Text, {
		value = meta,
		size = if stack then chrome.labelText else 11,
		color = accent,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, if packed then 58 else 66),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	})), if owned == true then React.createElement(Badge, {
		value = "OWNED",
		accent = Palette.green,
		filled = true,
		position = UDim2.new(if stack then 0 else 1, if stack then 0 else -150, 1, -(ctaH + 4)),
		size = if stack then UDim2.new(1, 0, 0, ctaH) else UDim2.fromOffset(136, ctaH),
	}) else React.createElement("frame", {
		Name = "ShopBuyCta",
		Size = if stack then UDim2.new(1, 0, 0, ctaH) else UDim2.fromOffset(148, ctaH),
		Position = UDim2.new(if stack then 0 else 1, if stack then 0 else -158, 1, -(ctaH + 4)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Button, {
		text = cta,
		icon = if disabled then "Lock" else "Shop",
		onClick = onClick,
		color = if disabled then Palette.panelSoft else accent,
		textColor = if disabled then Palette.creamSoft else Palette.ink,
		size = UDim2.fromScale(1, 1),
		disabled = not canBuy,
		reducedMotion = reducedMotion,
		highlight = canBuy,
		selectable = canBuy,
	}))))
end
local function ShopView(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local onPurchasePresentationChange = _param.onPurchasePresentationChange
	local monetization = useMonetization()
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — ShopView.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local stack = chrome.contentStack
	local tab, setTab = React.useState("Featured")
	local code, setCode = React.useState("")
	local codeFeedback, setCodeFeedback = React.useState("")
	local followFeedback, setFollowFeedback = React.useState("")
	local followBusy, setFollowBusy = React.useState(false)
	local busy, setBusy = React.useState(false)
	local banner, setBanner = React.useState("Buy a pack, a pass, or enter a code.")
	local purchasePhase, setPurchasePhase = React.useState("hidden")
	local purchaseDetail, setPurchaseDetail = React.useState()
	local heroReveal = useStagger(0, softMotion)
	-- Canonical softMotion antilag gate — ShopCatalog.
	local catalogReveal = useStagger(1, softMotion)
	local _result = state.Shop
	if _result ~= nil then
		_result = _result.OwnedPasses
	end
	local _condition = _result
	if _condition == nil then
		_condition = {}
	end
	local owned = _condition
	local pendingLabel = React.useRef("Item")
	local pendingOffer = React.useRef()
	local failsafe = React.useRef(nil)
	local busyRef = React.useRef(false)
	local sessionRef = React.useRef(0)
	local mountedRef = React.useRef(true)
	local lastRedeemAt = React.useRef(0)
	local purchasePhaseRef = React.useRef("hidden")
	purchasePhaseRef.current = purchasePhase
	local purchasePresentationCallback = React.useRef(onPurchasePresentationChange)
	purchasePresentationCallback.current = onPurchasePresentationChange
	React.useEffect(function()
		local _result_1 = purchasePresentationCallback.current
		if _result_1 ~= nil then
			_result_1(purchasePhase ~= "hidden")
		end
	end, { purchasePhase })
	React.useEffect(function()
		return function()
			local _result_1 = purchasePresentationCallback.current
			if _result_1 ~= nil then
				_result_1 = _result_1(false)
			end
			return _result_1
		end
	end, {})
	local setBusyGate = function(value)
		busyRef.current = value
		setBusy(value)
	end
	local clearFailsafe = function()
		if failsafe.current ~= nil then
			task.cancel(failsafe.current)
			failsafe.current = nil
		end
	end
	local dismissPurchase = React.useCallback(function()
		clearFailsafe()
		sessionRef.current += 1
		pendingOffer.current = nil
		setPurchasePhase("hidden")
		setPurchaseDetail(nil)
		setBusyGate(false)
	end, {})
	local openPending = function(label, seconds)
		if seconds == nil then
			seconds = PRODUCT_PENDING_FAILSAFE
		end
		pendingLabel.current = label
		local _result_1 = purchasePresentationCallback.current
		if _result_1 ~= nil then
			_result_1(true)
		end
		local session = sessionRef.current + 1
		sessionRef.current = session
		setPurchasePhase("pending")
		setPurchaseDetail(nil)
		clearFailsafe()
		failsafe.current = task.delay(seconds, function()
			if sessionRef.current ~= session then
				return nil
			end
			setPurchasePhase("fail")
			setBusyGate(false)
			setBanner("That took too long — try again.")
		end)
	end
	local finishPurchase = function(ok, detail)
		clearFailsafe()
		sessionRef.current += 1
		pendingOffer.current = nil
		setPurchasePhase(if ok then "success" else "fail")
		setPurchaseDetail(detail)
		setBusyGate(false)
	end
	React.useEffect(function()
		mountedRef.current = true
		dispatch("SyncShop")
		local productConn = MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
			if userId ~= Players.LocalPlayer.UserId then
				return nil
			end
			local pending = pendingOffer.current
			if pending == nil or pending.kind ~= "product" or pending.id ~= productId then
				return nil
			end
			if isPurchased then
				local session = sessionRef.current
				local label = pendingLabel.current
				dispatch("SyncShop", {}, function(response)
					if sessionRef.current ~= session then
						return nil
					end
					finishPurchase(response.ok ~= false)
					local _result_1
					if response.ok == false then
						local _condition_1 = response.error
						if _condition_1 == nil then
							_condition_1 = "Purchase pending — check again shortly."
						end
						_result_1 = _condition_1
					else
						_result_1 = `{label} bought.`
					end
					setBanner(_result_1)
				end)
			else
				finishPurchase(false)
				setBanner("Cancelled — no charge.")
			end
		end)
		local passConn = MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
			if player ~= Players.LocalPlayer then
				return nil
			end
			local pending = pendingOffer.current
			if pending == nil or pending.kind ~= "pass" or pending.id ~= passId then
				return nil
			end
			if purchased then
				local session = sessionRef.current
				dispatch("SyncShop", {}, function(response)
					if sessionRef.current ~= session then
						return nil
					end
					finishPurchase(response.ok ~= false)
					local _result_1
					if response.ok == false then
						local _condition_1 = response.error
						if _condition_1 == nil then
							_condition_1 = "Pass pending — reopen Shop in a moment."
						end
						_result_1 = _condition_1
					else
						_result_1 = "Pass unlocked — bonuses are live."
					end
					setBanner(_result_1)
				end)
			else
				finishPurchase(false)
				setBanner("Cancelled — no charge.")
			end
		end)
		return function()
			mountedRef.current = false
			sessionRef.current += 1
			productConn:Disconnect()
			passConn:Disconnect()
			clearFailsafe()
		end
	end, {})
	local promptProduct = function(product)
		if busyRef.current or purchasePhaseRef.current == "pending" then
			return nil
		end
		local run = function()
			if not mountedRef.current then
				return nil
			end
			if busyRef.current or purchasePhaseRef.current == "pending" then
				return nil
			end
			if product.ProductId <= 0 then
				if RunService:IsStudio() then
					setBusyGate(true)
					openPending(product.Name)
					local session = sessionRef.current
					dispatch("StudioGrantProduct", {
						Id = product.Key,
					}, function(response)
						if sessionRef.current ~= session then
							return nil
						end
						if response.ok then
							finishPurchase(true)
							local _condition_1 = response.message
							if _condition_1 == nil then
								_condition_1 = "Test grant applied."
							end
							setBanner(_condition_1)
						else
							finishPurchase(false, response.error)
							local _condition_1 = response.error
							if _condition_1 == nil then
								_condition_1 = "Test purchase could not be completed."
							end
							setBanner(_condition_1)
						end
					end)
					return nil
				end
				setBanner("This pack isn’t for sale yet.")
				return nil
			end
			setBusyGate(true)
			pendingOffer.current = {
				kind = "product",
				id = product.ProductId,
			}
			openPending(product.Name)
			local ok = pcall(function()
				return MarketplaceService:PromptProductPurchase(Players.LocalPlayer, product.ProductId)
			end)
			if not ok then
				finishPurchase(false)
				setBanner("Couldn't open checkout.")
			end
		end
		task.defer(run)
	end
	local promptPass = function(pass)
		if busyRef.current or owned[pass.Key] == true or purchasePhaseRef.current == "pending" then
			return nil
		end
		local run = function()
			if not mountedRef.current then
				return nil
			end
			if busyRef.current or purchasePhaseRef.current == "pending" or owned[pass.Key] == true then
				return nil
			end
			if pass.PassId <= 0 then
				if RunService:IsStudio() then
					setBusyGate(true)
					openPending(pass.Name)
					local session = sessionRef.current
					dispatch("StudioGrantProduct", {
						Id = pass.Key,
					}, function(response)
						if sessionRef.current ~= session then
							return nil
						end
						if response.ok then
							finishPurchase(true)
							local _condition_1 = response.message
							if _condition_1 == nil then
								_condition_1 = "Test pass unlocked."
							end
							setBanner(_condition_1)
						else
							finishPurchase(false, response.error)
							local _condition_1 = response.error
							if _condition_1 == nil then
								_condition_1 = "Test pass could not be unlocked."
							end
							setBanner(_condition_1)
						end
					end)
					return nil
				end
				setBanner("This pass isn’t for sale yet.")
				return nil
			end
			setBusyGate(true)
			pendingOffer.current = {
				kind = "pass",
				id = pass.PassId,
			}
			openPending(pass.Name)
			local ok = pcall(function()
				return MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, pass.PassId)
			end)
			if not ok then
				finishPurchase(false)
				setBanner("Couldn't open checkout.")
			end
		end
		task.defer(run)
	end
	local redeem = function()
		local trimmed = (string.gsub((string.gsub(code, "^%s+", "")), "%s+$", ""))
		local now = os.clock()
		if trimmed == "" or busyRef.current or purchasePhaseRef.current == "pending" then
			return nil
		end
		if now - lastRedeemAt.current < REDEEM_DEBOUNCE then
			return nil
		end
		lastRedeemAt.current = now
		setBusyGate(true)
		setCodeFeedback("Checking code…")
		clearFailsafe()
		local session = sessionRef.current + 1
		sessionRef.current = session
		dispatch("RedeemCode", {
			Code = trimmed,
		}, function(response)
			if sessionRef.current ~= session then
				return nil
			end
			setBusyGate(false)
			if response.ok then
				setCode("")
				local _condition_1 = response.message
				if _condition_1 == nil then
					_condition_1 = "Code claimed."
				end
				setBanner(_condition_1)
				local _condition_2 = response.message
				if _condition_2 == nil then
					_condition_2 = "Reward claimed."
				end
				setCodeFeedback(_condition_2)
			else
				local _condition_1 = response.error
				if _condition_1 == nil then
					_condition_1 = "That code didn’t work."
				end
				setBanner(_condition_1)
				local _condition_2 = response.error
				if _condition_2 == nil then
					_condition_2 = "That code didn’t work."
				end
				setCodeFeedback(_condition_2)
			end
		end)
	end
	local _result_1 = state.SocialRewards
	if _result_1 ~= nil then
		_result_1 = _result_1.CreatorFollowClaimed
	end
	local followClaimed = _result_1 == true
	local _result_2 = state.SocialRewards
	if _result_2 ~= nil then
		_result_2 = _result_2.CreatorName
	end
	local _condition_1 = _result_2
	if _condition_1 == nil then
		_condition_1 = "usingINales"
	end
	local creatorName = _condition_1
	local verifyFollow = function()
		if followBusy or followClaimed or busyRef.current then
			return nil
		end
		setFollowBusy(true)
		setFollowFeedback(`Checking your follow for @{creatorName}…`)
		dispatch("VerifyCreatorFollow", {}, function(response)
			setFollowBusy(false)
			local _result_3
			if response.ok then
				local _condition_2 = response.message
				if _condition_2 == nil then
					_condition_2 = "Follower reward claimed."
				end
				_result_3 = _condition_2
			else
				local _condition_2 = response.error
				if _condition_2 == nil then
					_condition_2 = "Follow check failed."
				end
				_result_3 = _condition_2
			end
			local message = _result_3
			setFollowFeedback(message)
			setBanner(message)
		end)
	end
	local products = monetization.DevProducts
	local passes = monetization.GamePasses
	-- ▼ ReadonlyArray.filter ▼
	local _newValue_1 = {}
	local _callback_1 = function(_, index)
		return index < 2
	end
	local _length = 0
	for _k, _v in products do
		if _callback_1(_v, _k - 1, products) == true then
			_length += 1
			_newValue_1[_length] = _v
		end
	end
	-- ▲ ReadonlyArray.filter ▲
	local featuredProducts = _newValue_1
	-- ▼ ReadonlyArray.filter ▼
	local _newValue_2 = {}
	local _callback_2 = function(pass, index)
		return index < 1 or pass.Key == "AutoSalvage"
	end
	local _length_1 = 0
	for _k, _v in passes do
		if _callback_2(_v, _k - 1, passes) == true then
			_length_1 += 1
			_newValue_2[_length_1] = _v
		end
	end
	-- ▲ ReadonlyArray.filter ▲
	local featuredPasses = _newValue_2
	local listCount = if tab == "Codes" then 1 elseif tab == "Featured" then #featuredProducts + #featuredPasses elseif tab == "Passes" then #passes else #products
	local packCols = useShopColumns()
	local packedH = if stack then 208 else 244
	local codePanelH = if stack then 214 else 176
	local followPanelH = if stack then 186 else 148
	local codesH = codePanelH + Layout.panelGap + followPanelH
	local pageGap = if stack then Layout.stackGap else Layout.panelGap
	local offerStride = packedH + pageGap
	local heroH = if stack then 104 else 124
	local tabRowH = if stack then TapTarget else 50
	local sectionLabelH = 34
	local codeReady = (string.gsub(code, "%s", "")) ~= ""
	local redeemDisabled = busy or not codeReady or purchasePhase == "pending"
	local shopHostRef = React.useRef(nil)
	-- Flatten pass/product offers into row chunks so FlatList virtualizes long Supplies/Passes catalogs.
	local offerRows = {}
	if tab ~= "Codes" then
		local passList = if tab == "Featured" then featuredPasses elseif tab == "Passes" then passes else {}
		local productList = if tab == "Featured" then featuredProducts elseif tab == "Supplies" then products else {}
		local flatOffers = {}
		for _, pass in passList do
			table.insert(flatOffers, {
				kind = "pass",
				key = pass.Key,
				pass = pass,
			})
		end
		for _, product in productList do
			table.insert(flatOffers, {
				kind = "product",
				key = product.Key,
				product = product,
			})
		end
		do
			local index = 1
			while index <= #flatOffers do
				local row = {
					Id = `row-{tab}-{index}`,
					cells = {},
				}
				for col = 1, packCols do
					local entry = flatOffers[index]
					if entry == nil then
						break
					end
					table.insert(row.cells, entry)
					index += 1
				end
				table.insert(offerRows, row)
			end
		end
	end
	React.useEffect(function()
		if purchasePhase ~= "hidden" or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = shopHostRef.current
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
	end, { tab, purchasePhase, listCount, redeemDisabled })
	local heroPanel = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.mango,
		background = Palette.panelRaised,
		padding = if stack then 14 else 20,
		reveal = heroReveal,
		highlight = true,
		reducedMotion = softMotion,
		clips = false,
	}, if stack then React.createElement(React.Fragment, nil, React.createElement(Badge, {
		value = "SHOP",
		accent = Palette.mango,
		filled = true,
		size = UDim2.fromOffset(68, 20),
	}), React.createElement(Text, {
		value = "Buy a pack. Keep the edge.",
		size = 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 26),
		sizeConstraint = UDim2.new(1, 0, 0, 24),
	}), React.createElement(Text, {
		value = banner,
		size = 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 52),
		sizeConstraint = UDim2.new(1, 0, 0, 36),
	})) else React.createElement(React.Fragment, nil, React.createElement(IconTile, {
		kind = "Shop",
		accent = Palette.mango,
		size = 52,
		radius = 14,
		position = UDim2.fromOffset(0, 16),
		glow = true,
		reducedMotion = softMotion,
	}), React.createElement("frame", {
		Size = UDim2.new(1, -68, 0, 94),
		Position = UDim2.fromOffset(64, 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(Badge, {
		value = "SHOP",
		accent = Palette.mango,
		filled = true,
		size = UDim2.fromOffset(68, 20),
	}), React.createElement(Text, {
		value = "Passes, packs, and codes.",
		size = 26,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 22),
		sizeConstraint = UDim2.new(1, 0, 0, 32),
	}), React.createElement(Text, {
		value = banner,
		size = 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 58),
		sizeConstraint = UDim2.new(1, 0, 0, 28),
	}))))
	local tabsBar = React.createElement(SegmentedTabs, {
		options = SHOP_TAB_OPTIONS,
		value = tab,
		onChange = function(entry)
			setTab(entry)
			setBanner(SHOP_TAB_TIPS[entry])
		end,
		accent = Palette.mango,
		columns = #SHOP_TABS,
		gap = Layout.stackGap,
		size = UDim2.fromScale(1, 1),
		reducedMotion = softMotion,
	})
	local sectionLabel = React.createElement(SectionLabel, {
		value = if tab == "Codes" then "REDEEM" elseif tab == "Passes" then "GAME PASSES" elseif tab == "Supplies" then "SUPPLY PACKS" else "FEATURED OFFERS",
		color = Palette.mango,
	})
	local codesPane = React.createElement(TabPane, {
		key = "Codes",
		reducedMotion = softMotion,
		height = codesH,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, pageGap),
	}), React.createElement(Panel, {
		layoutOrder = 1,
		size = UDim2.new(1, -4, 0, codePanelH),
		accent = Palette.cyan,
		background = Palette.panelRaised,
		padding = if stack then 14 else 18,
		reducedMotion = softMotion,
		clips = false,
	}, React.createElement(Text, {
		value = "Promo codes",
		size = 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		sizeConstraint = UDim2.new(1, 0, 0, 26),
	}), React.createElement(Text, {
		value = "Enter a code, then claim the reward once.",
		size = 12,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(0, 30),
		sizeConstraint = UDim2.new(1, 0, 0, 26),
	}), React.createElement("frame", {
		Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.new(1, -168, 0, 48),
		Position = UDim2.fromOffset(0, 66),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		Color = if codeFeedback ~= "" then Palette.cyan else Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.5,
	}), React.createElement("textbox", {
		Size = UDim2.new(1, -20, 1, -12),
		Position = UDim2.fromOffset(10, 6),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Text = code,
		PlaceholderText = "ENTER CODE",
		PlaceholderColor3 = Palette.muted,
		TextColor3 = Palette.cream,
		TextSize = 14,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		MultiLine = false,
		TextEditable = not busy,
		MaxVisibleGraphemes = 24,
		Change = {
			Text = function(box)
				setCode(string.sub(string.upper(box.Text), 1, 24))
				if codeFeedback ~= "" then
					setCodeFeedback("")
				end
			end,
		},
		Event = {
			Focused = function()
				return Audio:play("inputFocus")
			end,
			FocusLost = function(_box, enter)
				if enter then
					redeem()
				end
			end,
		},
	})), React.createElement("frame", {
		Name = "ShopClaimCode",
		Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(148, 48),
		Position = if stack then UDim2.fromOffset(0, 122) else UDim2.new(1, -148, 0, 66),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		-- FocusClaim prefers Claim-named hosts; park Selection on CLAIM CODE when Codes tab is live.
		ref = if tab == "Codes" then shopHostRef else nil,
	}, React.createElement(Button, {
		text = if busy then "CHECKING…" else "CLAIM CODE",
		icon = "Code",
		onClick = redeem,
		color = Palette.cyan,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		disabled = redeemDisabled,
		reducedMotion = softMotion,
		highlight = not redeemDisabled,
		selectable = not redeemDisabled,
	})), codeFeedback ~= "" and React.createElement(Text, {
		value = codeFeedback,
		size = 11,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(0, if stack then 174 else 120),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	})), React.createElement(Panel, {
		layoutOrder = 2,
		size = UDim2.new(1, -4, 0, followPanelH),
		accent = Palette.mint,
		background = Palette.panelRaised,
		padding = 16,
		reducedMotion = softMotion,
	}, React.createElement(Icon, {
		kind = "Pilot",
		color = Palette.cream,
		accent = Palette.mint,
		size = if stack then 38 else 42,
		spin = false,
		position = UDim2.fromOffset(0, 2),
	}), React.createElement(Text, {
		value = `Follow @{creatorName}`,
		size = 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(52, 0),
		sizeConstraint = UDim2.new(1, if stack then -52 else -230, 0, 24),
	}), React.createElement(Text, {
		value = if followFeedback ~= "" then followFeedback elseif followClaimed then "Reward claimed. Thanks for following!" else "Follow the creator on Roblox, then check it here for a one-time reward.",
		size = 11,
		color = if followClaimed or followFeedback ~= "" then Palette.mint else Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(52, 28),
		sizeConstraint = UDim2.new(1, if stack then -52 else -230, 0, if stack then 42 else 36),
	}), React.createElement(Button, {
		text = if followClaimed then "CLAIMED" elseif followBusy then "CHECKING…" else "CHECK FOLLOW",
		icon = if followClaimed then "Check" else "Search",
		onClick = verifyFollow,
		color = if followClaimed then Palette.panelSoft else Palette.mint,
		textColor = if followClaimed then Palette.muted else Palette.ink,
		size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(190, 48),
		position = if stack then UDim2.new(0, 0, 1, -TapTarget) else UDim2.new(1, -190, 0.5, -24),
		disabled = followClaimed or followBusy,
		reducedMotion = softMotion,
		highlight = not followClaimed and not followBusy,
	}))))
	local offerList = React.createElement(FlatList, {
		data = offerRows,
		itemHeight = offerStride,
		headerHeight = 0,
		overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
		canvasTail = 8,
		Size = UDim2.fromScale(1, 1),
		scrollBarColor = Palette.mango,
		scrollBarThickness = 3,
		scrollBarTransparency = 0.28,
		keyExtractor = function(row)
			return row.Id
		end,
		renderItem = function(_param_1)
			local row = _param_1.item
			local rowIndex = _param_1.index
			return React.createElement(FlexGrid, {
				columns = packCols,
				cellMinHeight = packedH,
				size = UDim2.fromScale(1, 1),
			}, (function()
				local tiles = {}
				for cellIndex, entry in row.cells do
					local staggerIndex = rowIndex * packCols + (cellIndex - 1)
					if entry.kind == "pass" then
						local pass = entry.pass
						local cta = if owned[pass.Key] == true then "Owned" else priceText(pass.PriceLabel, pass.StudioPrice, pass.PassId)
						local unavailable = pass.PassId <= 0 and not RunService:IsStudio()
						table.insert(tiles, React.createElement(OfferTile, {
							key = `{tab}-{pass.Key}`,
							layoutOrder = cellIndex,
							staggerIndex = staggerIndex,
							title = pass.Name,
							detail = pass.Description,
							meta = passBenefitLine(pass),
							accent = accentOf(pass.Accent),
							icon = iconOf(pass.Icon),
							cta = cta,
							disabled = unavailable or busy,
							owned = owned[pass.Key] == true,
							onClick = function()
								return promptPass(pass)
							end,
							reducedMotion = softMotion,
							packed = true,
						}))
					else
						local product = entry.product
						local unavailable = product.ProductId <= 0 and not RunService:IsStudio()
						table.insert(tiles, React.createElement(OfferTile, {
							key = `{tab}-{product.Key}`,
							layoutOrder = cellIndex,
							staggerIndex = staggerIndex,
							title = product.Name,
							detail = product.Description,
							meta = rewardLine(product.Reward),
							accent = accentOf(product.Accent),
							icon = iconOf(product.Icon),
							cta = priceText(product.PriceLabel, product.StudioPrice, product.ProductId),
							disabled = unavailable or busy,
							onClick = function()
								return promptProduct(product)
							end,
							reducedMotion = softMotion,
							packed = true,
						}))
					end
				end
				return tiles
			end)())
		end,
		ListEmptyComponent = React.createElement(EmptyState, {
			key = "shop-empty",
			icon = "Shop",
			title = "Nothing listed",
			body = "Nothing listed in this tab right now.",
			accent = Palette.mango,
			layoutOrder = 0,
			reducedMotion = softMotion,
		}),
	})
	local sections = {
		{
			id = "hero",
			height = heroH,
			element = heroPanel,
		},
		{
			id = "tabs",
			height = tabRowH,
			element = tabsBar,
		},
		{
			id = "label",
			height = sectionLabelH,
			element = sectionLabel,
		},
	}
	if tab == "Codes" then
		table.insert(sections, {
			id = "list",
			height = codesH,
			element = codesPane,
		})
	else
		table.insert(sections, {
			id = "list",
			fill = true,
			minHeight = math.max(180, offerStride * 2),
			element = React.createElement(Panel, {
				size = UDim2.fromScale(1, 1),
				accent = Palette.mango,
				background = Palette.panel,
				padding = 0,
				reveal = catalogReveal,
				reducedMotion = softMotion,
				clips = false,
			}, offerList),
		})
	end
	return React.createElement("frame", {
		ref = if tab ~= "Codes" then shopHostRef else nil,
		Name = "ShopViewHost",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(PageScaffold, {
		gap = pageGap,
		tailPad = scrollTail(stack, chrome.bottomSafe, SCROLL_PAD),
		scrollBarColor = Palette.mango,
		scrollBarThickness = 4,
		sections = sections,
	}), React.createElement(PurchaseOverlay, {
		phase = purchasePhase,
		reducedMotion = softMotion,
		detail = purchaseDetail,
		onDismiss = dismissPurchase,
	}))

end
return {
	ShopView = ShopView,
}

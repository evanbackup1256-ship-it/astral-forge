--!nonstrict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("PagesShop: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("PagesShop: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

__defs["ShopView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local _flexbox = require(script.Parent.Parent.MotionKit)("flexbox")
local FlexGrid = _flexbox.FlexGrid
local useShopColumns = _flexbox.useShopColumns
local Icon = require(script.Parent.Parent.ArtKit)("Icon").Icon
local easeOutCubic = require(script.Parent.Parent.MotionKit)("motion").easeOutCubic
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useBoatTween = _motion.useBoatTween
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local PurchaseOverlay = require(script.Parent.Parent.UiOverlays)("purchaseOverlay").PurchaseOverlay
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local Layout = _theme.Layout
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local darken = _theme.darken
local TapTarget = _theme.TapTarget
local scrollTail = _theme.scrollTail
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local EmptyState = _ui.EmptyState
local IconTile = _ui.IconTile
local Panel = _ui.Panel
local SectionLabel = _ui.SectionLabel
local SegmentedTabs = _ui.SegmentedTabs
local Text = _ui.Text
local FlatList = require(script.Parent.Parent.LayoutKit)("virtualizedList").FlatList
local ClientLog = require(script.Parent.Parent.CoreKit)("log").ClientLog
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local SHOP_TABS = { "Featured", "Passes", "Supplies", "Codes" }
local SHOP_TAB_TIPS = {
	Featured = "What's on sale.",
	Passes = "Permanent upgrades. Buy once, keep forever.",
	Supplies = "One-time packs of flux, dust and boosts.",
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
		_catalogModule = _catalogModule:WaitForChild("SharedData", 6)
	end
	local catalogModule = _catalogModule
	if catalogModule == nil or not catalogModule:IsA("ModuleScript") then
		ClientLog:warn("shop", "shop catalog missing")
		return {
			DevProducts = {},
			GamePasses = {},
			Error = "The shop couldn't load. Close it and try again.",
		}
	end
	local loaded, result = pcall(function()
		return require(catalogModule)("MonetizationConfig")
	end)
	if not loaded or type(result) ~= "table" or type(result.DevProducts) ~= "table" or type(result.GamePasses) ~= "table" then
		ClientLog:warn("shop", `couldn't load shop catalog: {tostring(result)}`)
		return {
			DevProducts = {},
			GamePasses = {},
			Error = "The shop couldn't load. Close it and try again.",
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
	local softMotion = reducedMotion
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
			pcall(task.cancel, failsafe.current)
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
			failsafe.current = nil
			if not mountedRef.current or sessionRef.current ~= session then
				return nil
			end
			setPurchasePhase("fail")
			setBusyGate(false)
			setBanner("That took too long. Try again.")
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
							_condition_1 = "Purchase pending. Roblox is still confirming it."
						end
						_result_1 = _condition_1
					else
						_result_1 = `{label} bought.`
					end
					setBanner(_result_1)
				end)
			else
				finishPurchase(false)
				setBanner("Cancelled. You weren't charged.")
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
							_condition_1 = "Pass pending. Reopen the Shop in a moment."
						end
						_result_1 = _condition_1
					else
						_result_1 = "Pass unlocked. Its bonuses are active now."
					end
					setBanner(_result_1)
				end)
			else
				finishPurchase(false)
				setBanner("Cancelled. You weren't charged.")
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
			if not mountedRef.current then
				return nil
			end
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
	local featuredProducts = _newValue_1
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
	local featuredPasses = _newValue_2
	local listCount = if tab == "Codes" then 1 elseif tab == "Featured" then #featuredProducts + #featuredPasses elseif tab == "Passes" then #passes else #products
	local packCols = useShopColumns()
	local packedH = if stack then 208 else 244
	local codePanelH = if stack then 214 else 176
	local followPanelH = if stack then 186 else 148
	local codesH = codePanelH + Layout.panelGap + followPanelH
	local pageGap = if stack then Layout.stackGap else Layout.panelGap
	local offerStride = packedH + pageGap
	local heroH = if stack then 104 else 92 -- same height as the other shop tabs' headers
	local tabRowH = if stack then TapTarget else 50
	local sectionLabelH = 34
	local codeReady = (string.gsub(code, "%s", "")) ~= ""
	local redeemDisabled = busy or not codeReady or purchasePhase == "pending"
	local shopHostRef = React.useRef(nil)
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
			pcall(task.cancel, selectJob)
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
		value = "Support the game and speed up your forge.",
		size = 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 26),
		sizeConstraint = UDim2.new(1, 0, 0, 24),
	}), React.createElement(Text, {
		value = monetization.Error or banner,
		size = 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 52),
		sizeConstraint = UDim2.new(1, 0, 0, 36),
	})) else React.createElement(React.Fragment, nil, React.createElement(IconTile, {
		kind = "Shop",
		accent = Palette.mango,
		size = 44,
		radius = 12,
		position = UDim2.fromOffset(0, 4),
		glow = true,
		reducedMotion = softMotion,
	}), React.createElement("frame", {
		Size = UDim2.new(1, -60, 0, 60),
		Position = UDim2.fromOffset(60, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(Text, {
		value = "Passes, packs and codes",
		size = 24,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 0),
		sizeConstraint = UDim2.new(1, 0, 0, 30),
	}), React.createElement(Text, {
		value = monetization.Error or banner,
		size = 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 32),
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
	local catalogH = math.max(offerStride, #offerRows * offerStride)
	local offerList = React.createElement(FlatList, {
		data = offerRows,
		itemHeight = offerStride,
		headerHeight = 0,
		overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
		canvasTail = 8,
		embedded = true,
		Size = UDim2.new(1, 0, 0, catalogH),
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
							reducedMotion = reducedMotion,
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
			reducedMotion = reducedMotion,
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
		local catalogH = math.max(offerStride, #offerRows * offerStride)
		table.insert(sections, {
			id = "list",
			height = catalogH,
			element = React.createElement(Panel, {
				size = UDim2.new(1, 0, 0, catalogH),
				accent = Palette.mango,
				background = Palette.panel,
				padding = 0,
				reveal = catalogReveal,
				reducedMotion = reducedMotion,
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
		reducedMotion = reducedMotion,
		detail = purchaseDetail,
		onDismiss = dismissPurchase,
	}))

end
return {
	ShopView = ShopView,
}
end

__defs["StoreFront"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useViewport = _motion.useViewport
local useStagger = _motion.useStagger
local useWallClock = _motion.useWallClock
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local scrollTail = _theme.scrollTail
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local IconTile = _ui.IconTile
local Meter = _ui.Meter
local Panel = _ui.Panel
local SegmentedTabs = _ui.SegmentedTabs
local Text = _ui.Text
local _crate = require(script.Parent.Parent.UiCore)("crateModel")
local CrateModel = _crate.CrateModel
local skinAccent = _crate.skinAccent
local _prism = require(script.Parent.Parent.UiCore)("prismFx")
local PrismAura = _prism.PrismAura
local isAscended = _prism.isAscended
local Icon = require(script.Parent.Parent.ArtKit)("Icon").Icon
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local SharedData = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))
local ShopCatalog = SharedData("ShopCatalog")
local RelicSystem = SharedData("RelicSystem")
local Browse = require(script.Parent.Parent.BrowseKit)
local _elementFx = require(script.Parent.Parent.ElementFx)
local ElementFx = _elementFx.ElementFx
local elementSheet = _elementFx.sheet

local h = React.createElement
local GAP = 10
local SECTIONS = {
	{ id = "Daily", label = "Daily" },
	{ id = "Crates", label = "Crates" },
	{ id = "Skins", label = "Skins" },
	{ id = "Codex", label = "Codex" },
	{ id = "Artifacts", label = "Artifacts" },
	{ id = "Premium", label = "Premium" },
}
local function sectionTabLayout(width, rowHeight)
	local gap = 6
	local columns = math.clamp(math.floor((math.max(1, width) + gap) / (96 + gap)), 1, #SECTIONS)
	local rows = math.ceil(#SECTIONS / columns)
	return columns, rows * rowHeight + (rows - 1) * gap
end
local ARTIFACT_RARITY = {
	COMMON = { rank = 1, color = Color3.fromRGB(200, 196, 188), label = "Common" },
	UNCOMMON = { rank = 2, color = Color3.fromRGB(120, 220, 150), label = "Uncommon" },
	RARE = { rank = 3, color = Color3.fromRGB(110, 190, 255), label = "Rare" },
	EPIC = { rank = 4, color = Color3.fromRGB(190, 120, 255), label = "Epic" },
	LEGENDARY = { rank = 5, color = Color3.fromRGB(255, 190, 70), label = "Legendary" },
	MYTHIC = { rank = 6, color = Color3.fromRGB(255, 110, 150), label = "Mythic" },
}
local CURRENCY_ICON = { Stardust = "Dust", Cores = "Core" }
local compactNumber = require(script.Parent.Parent.CoreKit)("format").compactNumber
local KIND_ICON = { Key = "Crate", Essence = "Artifact", Flux = "Flux", Boost = "Boost", Cache = "Gift", Skin = "Crate" }
local TIER_COLOR = {
	Common = Color3.fromRGB(200, 196, 188),
	Rare = Color3.fromRGB(110, 190, 255),
	Epic = Color3.fromRGB(190, 120, 255),
	Legendary = Color3.fromRGB(255, 190, 70),
	Mythic = Color3.fromRGB(255, 110, 150),
}

local function commas(value)
	local text = tostring(math.floor(math.max(0, tonumber(value) or 0)))
	local spaced = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
	return (string.gsub(spaced, "^,", ""))
end

local function currencyColor(currency)
	return if currency == "Cores" then Palette.cyan else Palette.violet
end

local function rarityColor(config, rarity)
	local rarities = config and config.Items and config.Items.Rarities
	local entry = rarities and rarities[rarity]
	return if entry ~= nil and entry.Color ~= nil then entry.Color else Palette.cream
end

local function crateById(config, id)
	for _, crate in (config and config.Items and config.Items.Crates) or {} do
		if crate.Id == id then
			return crate
		end
	end
	return nil
end

local function clockText(seconds)
	local left = math.max(0, math.floor(seconds))
	local hours = left // 3600
	local minutes = (left % 3600) // 60
	if hours > 0 then
		return `{hours}h {minutes}m`
	end
	return `{minutes}m {left % 60}s`
end

local function rowsHeight(count, columns, cell)
	local rows = math.max(1, math.ceil(count / math.max(1, columns)))
	return rows * cell + (rows - 1) * GAP
end

local function Grid(props)
	local children = table.clone(props.cells)
	children.Layout = h("uigridlayout", {
		CellSize = UDim2.new(1 / props.columns, -math.ceil(GAP * (props.columns - 1) / props.columns), 0, props.cell),
		CellPadding = UDim2.fromOffset(GAP, GAP),
		FillDirectionMaxCells = props.columns,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	return h("frame", {
		Size = UDim2.new(1, 0, 0, props.height),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, children)
end

local function Wallet(props)
	local state = props.state or {}
	local chips = {
		Layout = h("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = if props.left then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, currency in { "Stardust", "Cores" } do
		chips[currency] = h("frame", {
			Size = UDim2.fromOffset(112, 30),
			BackgroundColor3 = Palette.panelSoft,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			LayoutOrder = index,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
			Color = currencyColor(currency),
			Transparency = 0.55,
			Thickness = 1,
		}), h(Icon, {
			kind = CURRENCY_ICON[currency],
			color = Palette.cream,
			accent = currencyColor(currency),
			size = 20,
			position = UDim2.fromOffset(6, 5),
			spin = false,
		}), h(Text, {
			value = compactNumber(state[currency]),
			size = 13,
			color = Palette.cream,
			weight = Enum.FontWeight.Bold,
			fit = true,
			minSize = 9,
			position = UDim2.fromOffset(32, 6),
			sizeConstraint = UDim2.new(1, -40, 0, 18),
		}))
	end
	return h("frame", {
		Size = props.size,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, chips)
end

local function Hero(props)
	local stack = props.stack
	local textW = if stack then -56 else -300
	return h(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = props.accent,
		background = Palette.panelRaised,
		padding = 14,
		reveal = props.reveal,
		highlight = true,
		reducedMotion = props.reducedMotion,
		clips = false,
	}, h(IconTile, {
		kind = props.icon,
		accent = props.accent,
		size = 44,
		radius = 12,
		position = UDim2.fromOffset(0, 2),
		glow = true,
		reducedMotion = props.reducedMotion,
	}), h(Text, {
		value = props.title,
		size = if stack then 18 else 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 13,
		position = UDim2.fromOffset(56, 0),
		sizeConstraint = UDim2.new(1, textW, 0, 28),
	}), h(Text, {
		value = props.body,
		size = 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(56, 30),
		sizeConstraint = UDim2.new(1, textW, 0, 34),
	}), h(Wallet, {
		state = props.state,
		left = stack,
		size = if stack then UDim2.new(1, 0, 0, 30) else UDim2.fromOffset(240, 30),
		position = if stack then UDim2.new(0, 0, 1, -30) else UDim2.fromScale(1, 0),
		anchorPoint = if stack then nil else Vector2.new(1, 0),
	}), props.extra)
end

local function heroHeight(stack)
	return if stack then 124 else 92
end

local function offerDetail(offer, config)
	if offer.Kind == "Key" then
		local crate = crateById(config, offer.CrateId)
		return `{offer.Amount} key{if offer.Amount == 1 then "" else "s"} for the {if crate then crate.Name else offer.CrateId}. Open {if offer.Amount == 1 then "it" else "them"} under Crates.`
	elseif offer.Kind == "Essence" then
		return `+{commas(offer.Amount)} relic essence, for levelling relics.`
	elseif offer.Kind == "Flux" then
		local span = if offer.Minutes >= 60 then `{offer.Minutes // 60} hour{if offer.Minutes >= 120 then "s" else ""}` else `{offer.Minutes} minutes`
		return `{span} of your current flux output, paid at once.`
	elseif offer.Kind == "Boost" then
		local boost = config and config.Boosts and config.Boosts[offer.BoostId]
		local name = if boost and boost.Name then boost.Name else (string.gsub(tostring(offer.BoostId), "(%l)(%u)", "%1 %2"))
		return `{offer.Amount} {name} {if offer.Amount == 1 then "charge" else "charges"}. Use it from Boosts.`
	elseif offer.Kind == "Cache" then
		return `One {offer.Rarity} relic, guaranteed, revealed on the spot.`
	elseif offer.Kind == "Skin" then
		local skin = ShopCatalog.skin(offer.SkinId)
		return `Crate skin. {if skin then skin.Blurb else ""}`
	end
	return ""
end

local function offerAccent(offer, config)
	if offer.Kind == "Skin" then
		return skinAccent(offer.SkinId)
	elseif offer.Kind == "Cache" then
		return rarityColor(config, offer.Rarity)
	elseif offer.Kind == "Key" then
		local crate = crateById(config, offer.CrateId)
		return if crate ~= nil and typeof(crate.Color) == "Color3" then crate.Color else Palette.cyan
	end
	return if offer.Deal then Palette.mango else Palette.cyan
end

local function OfferCard(props)
	local offer = props.offer
	local accent = offerAccent(offer, props.config)
	local reveal = useStagger(props.index, props.reducedMotion, 0.04, 0.26)
	local left = props.left
	local soldOut = left <= 0
	local have = tonumber(props.state[offer.Currency]) or 0
	local short = math.max(0, offer.Price - have)
	local canBuy = not soldOut and short == 0 and not props.busy
	local fullPrice = if offer.Deal then math.floor(offer.Price / (1 - ShopCatalog.DEAL_DISCOUNT) + 0.5) else nil
	local cta = if soldOut then "SOLD OUT" elseif short > 0 then `NEED {commas(short)}` elseif props.pending then "BUYING…" else "BUY"
	return h(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = accent,
		background = Palette.panelRaised,
		padding = 12,
		reveal = reveal,
		interactive = canBuy,
		highlight = offer.Deal,
		reducedMotion = props.reducedMotion,
		clips = false,
		layoutOrder = props.index,
	}, h("frame", {
		Size = UDim2.fromOffset(62, 62),
		BackgroundColor3 = darken(accent, 0.4),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, h("uicorner", { CornerRadius = UDim.new(0, 12) }), h("uistroke", {
		Color = accent,
		Thickness = 1.5,
		Transparency = 0.3,
	}), if offer.Kind == "Skin" then h(CrateModel, {
		skin = offer.SkinId,
		live = offer.Deal and not props.reducedMotion,
		spin = true,
		zoom = 0.95,
	}) else h(Icon, {
		kind = KIND_ICON[offer.Kind] or "Shop",
		color = Palette.cream,
		accent = accent,
		size = 38,
		position = UDim2.fromOffset(12, 12),
		spin = false,
		reducedMotion = props.reducedMotion,
	})), h(Text, {
		value = offer.Name,
		size = 15,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(74, 0),
		sizeConstraint = UDim2.new(1, -74 - (if offer.Deal then 76 else 0), 0, 22),
	}), h(Text, {
		value = offerDetail(offer, props.config),
		size = 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(74, 24),
		sizeConstraint = UDim2.new(1, -74, 0, 44),
	}), offer.Deal and h(Badge, {
		value = `DEAL -{math.floor(ShopCatalog.DEAL_DISCOUNT * 100)}%`,
		accent = Palette.mango,
		filled = true,
		size = UDim2.fromOffset(72, 20),
		position = UDim2.new(1, -72, 0, 0),
	}), h(Text, {
		value = if soldOut then "Bought out today" else `{left} left today`,
		size = 11,
		color = if soldOut then Palette.muted else accent,
		weight = Enum.FontWeight.Bold,
		position = UDim2.fromOffset(0, 74),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), h(Icon, {
		kind = CURRENCY_ICON[offer.Currency] or "Dust",
		color = Palette.cream,
		accent = currencyColor(offer.Currency),
		size = 22,
		position = UDim2.new(0, 0, 1, if fullPrice ~= nil then -38 else -31),
		spin = false,
	}), h(Text, {
		value = commas(offer.Price),
		size = 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.new(0, 28, 1, if fullPrice ~= nil then -40 else -32),
		sizeConstraint = UDim2.fromOffset(80, 24),
	}), fullPrice ~= nil and h(Text, {
		value = `was {commas(fullPrice)}`,
		size = 11,
		color = Palette.muted,
		position = UDim2.new(0, 28, 1, -15),
		sizeConstraint = UDim2.fromOffset(80, 14),
	}), h("frame", {
		Name = "DailyBuy",
		Size = UDim2.fromOffset(124, 48),
		Position = UDim2.new(1, -124, 1, -48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, h(Button, {
		text = cta,
		icon = if soldOut then "Check" elseif short > 0 then "Lock" else "Shop",
		onClick = props.onBuy,
		color = if canBuy then accent else Palette.panelSoft,
		textColor = if canBuy then Palette.ink else Palette.creamSoft,
		size = UDim2.fromScale(1, 1),
		disabled = not canBuy,
		reducedMotion = props.reducedMotion,
		highlight = canBuy,
		selectable = canBuy,
	})))
end

local function useDay()
	local day, setDay = React.useState(function()
		return ShopCatalog.day(workspace:GetServerTimeNow())
	end)
	React.useEffect(function()
		local job = task.delay(ShopCatalog.secondsLeft(workspace:GetServerTimeNow()) + 1, function()
			setDay(ShopCatalog.day(workspace:GetServerTimeNow()))
		end)
		return function()
			pcall(task.cancel, job)
		end
	end, { day })
	return day
end

local function DailySection(props)
	local state = props.state
	local config = props.config
	local stack = props.stack
	local day = useDay()
	local wall = useWallClock(true)
	local pendingSlot, setPendingSlot = React.useState(nil)
	local mounted = React.useRef(true)
	React.useEffect(function()
		mounted.current = true
		return function()
			mounted.current = false
		end
	end, {})
	local daily = state.DailyShop or {}
	local current = daily.Day == day
	local owned = if current and type(daily.Owned) == "table" then daily.Owned else (state.Cosmetics and state.Cosmetics.CrateSkins) or {}
	local bought = if current then daily.Bought or {} else {}
	local offers = ShopCatalog.roll(Players.LocalPlayer.UserId, day, owned)
	local columns = if stack then 1 elseif props.width >= 1000 then 3 else 2
	local cellH = 178
	local buy = function(offer)
		if pendingSlot ~= nil then
			return
		end
		setPendingSlot(offer.Slot)
		props.dispatch("BuyDailyOffer", { Slot = offer.Slot }, function(response)
			if not mounted.current then
				return
			end
			setPendingSlot(nil)
			if response.ok and type(response.Rolls) == "table" and #response.Rolls > 0 and props.onCrateReveal ~= nil then
				local roll = response.Rolls[1]
				props.onCrateReveal({
					crateId = "ForgeCrate",
					crateName = offer.Name,
					accent = rarityColor(config, roll.Rarity),
					rolls = response.Rolls,
				})
			elseif response.ok then
				Audio:play("purchase")
			end
		end)
	end
	local cells = {}
	for index, offer in offers do
		cells[`Offer{offer.Slot}`] = h(OfferCard, {
			key = `{day}-{offer.Id}`,
			offer = offer,
			index = index,
			config = config,
			state = state,
			left = ShopCatalog.remaining(offer, bought),
			busy = pendingSlot ~= nil,
			pending = pendingSlot == offer.Slot,
			reducedMotion = props.reducedMotion,
			onBuy = function()
				buy(offer)
			end,
		})
	end
	local gridH = rowsHeight(#offers, columns, cellH)
	local resetText = wall:map(function(now)
		return `New offers in {clockText(ShopCatalog.secondsLeft(now))}`
	end)
	local marketH = if stack then 132 else 96
	return React.createElement(PageScaffold, {
		gap = GAP,
		tailPad = props.tailPad,
		scrollBarColor = Palette.mango,
		sections = {
			{
				id = "hero",
				height = heroHeight(stack),
				element = h(Hero, {
					title = "Daily Shop",
					body = "Six offers picked for you each day. The first is the Deal of the Day.",
					accent = Palette.mango,
					icon = "Calendar",
					state = state,
					stack = stack,
					reveal = props.reveal,
					reducedMotion = props.reducedMotion,
				}),
			},
			{
				id = "clock",
				height = 22,
				element = h(Text, {
					value = resetText,
					size = 13,
					color = Palette.mango,
					weight = Enum.FontWeight.Bold,
					sizeConstraint = UDim2.new(1, 0, 0, 20),
				}),
			},
			{
				id = "offers",
				height = gridH,
				element = h(Grid, { columns = columns, cell = cellH, height = gridH, cells = cells }),
			},
			{
				id = "market",
				height = marketH,
				element = h(Panel, {
					size = UDim2.fromScale(1, 1),
					accent = Palette.coral,
					background = Palette.panel,
					padding = 14,
					reducedMotion = props.reducedMotion,
					clips = false,
				}, h(Icon, {
					kind = "Jackpot",
					color = Palette.cream,
					accent = Palette.coral,
					size = 38,
					position = UDim2.fromOffset(0, 4),
					spin = false,
				}), h(Text, {
					value = "The Black Market",
					size = 16,
					color = Palette.cream,
					weight = Enum.FontWeight.Heavy,
					position = UDim2.fromOffset(50, 0),
					sizeConstraint = UDim2.new(1, if stack then -50 else -220, 0, 22),
				}), h(Text, {
					value = "Keys, materials and boosts from the Black Market's hourly shipments.",
					size = 12,
					color = Palette.creamSoft,
					wrap = true,
					position = UDim2.fromOffset(50, 24),
					sizeConstraint = UDim2.new(1, if stack then -50 else -220, 0, 36),
				}), h(Button, {
					text = "VISIT MARKET",
					icon = "Visit",
					onClick = function()
						if props.navigate then
							props.navigate("Bazaar")
						end
					end,
					color = Palette.coral,
					textColor = Palette.ink,
					size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(190, 44),
					position = if stack then UDim2.new(0, 0, 1, -TapTarget) else UDim2.new(1, -190, 0.5, -22),
					reducedMotion = props.reducedMotion,
					highlight = true,
				})),
			},
		},
	})
end

local function OddsRow(props)
	local row = props.row
	local color = rarityColor(props.config, row.rarity)
	return h("frame", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundColor3 = color,
		BackgroundTransparency = if isAscended(row.rarity) then 0.86 else 1,
		BorderSizePixel = 0,
		LayoutOrder = props.order,
	}, h("uicorner", { CornerRadius = UDim.new(0, 6) }), isAscended(row.rarity) and h(PrismAura, {
		rarity = row.rarity,
		intensity = 0.8,
		rays = false,
		sparks = false,
		thickness = 1.5,
		corner = 6,
	}), h("frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.new(0, 6, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Rotation = 45,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}), h(Text, {
		value = row.rarity,
		size = 12,
		color = if isAscended(row.rarity) then Palette.cream else color,
		weight = Enum.FontWeight.Bold,
		position = UDim2.fromOffset(22, 2),
		sizeConstraint = UDim2.new(0.6, -22, 0, 16),
	}), h(Text, {
		value = RelicSystem.chanceText(row.chance),
		size = 12,
		color = Palette.cream,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Right,
		position = UDim2.new(0.4, 0, 0, 2),
		sizeConstraint = UDim2.new(0.6, -8, 0, 16),
	}))
end

local function CrateStage(props)
	local crate = props.crate
	local config = props.config
	local stack = props.stack
	local keys = props.keys
	local odds = RelicSystem.odds(crate.Weights)
	local accent = if typeof(crate.Color) == "Color3" then crate.Color else Palette.violet
	local oddsRows = {
		Layout = h("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index = #odds, 1, -1 do
		local row = odds[index]
		oddsRows[row.rarity] = h(OddsRow, { row = row, config = config, order = #odds - index })
	end
	local modelH = if stack then 190 else 280
	local infoX = if stack then 0 else 300
	local infoY = if stack then modelH + 6 else 0
	local pity = (props.pity or 0)
	local pityLine = if crate.PityAfter and crate.PityRarity then `Pity: a {crate.PityRarity} or better within {math.max(1, crate.PityAfter - pity)} opens.` else ""
	local openButton = function(count, order)
		local can = keys >= count and not props.busy
		return h(Button, {
			text = if keys >= count then `OPEN {count}` else `NEED {count - keys} KEY{if count - keys == 1 then "" else "S"}`,
			icon = if keys >= count then "Crate" else "Lock",
			onClick = function()
				props.onOpen(count)
			end,
			color = if can then accent else Palette.panelSoft,
			textColor = if can then Palette.ink else Palette.creamSoft,
			size = UDim2.new(0.5, -4, 1, 0),
			position = UDim2.fromScale(if order == 1 then 0 else 0.5, 0),
			disabled = not can,
			reducedMotion = props.reducedMotion,
			highlight = can,
			selectable = can,
		})
	end
	return h(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = accent,
		background = Palette.panelRaised,
		padding = 14,
		reveal = props.reveal,
		reducedMotion = props.reducedMotion,
		clips = false,
	}, h("frame", {
		Size = if stack then UDim2.new(1, 0, 0, modelH) else UDim2.fromOffset(286, modelH),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	}, h("uicorner", { CornerRadius = UDim.new(0, 14) }), h("uigradient", {
		Color = ColorSequence.new(darken(accent, 0.55), Palette.void),
		Rotation = 90,
	}), h(CrateModel, {
		skin = require(game.ReplicatedStorage.AstralForge.Shared.CrateAppearance).resolve(props.skin, crate.Id, config.Items.Crates),
		spin = true,
		open = if props.busy then 0.35 else 0,
		shake = if props.busy then 1 else 0,
		live = not props.reducedMotion,
		zoom = 0.85,
	}), h(Badge, {
		value = `{keys} KEY{if keys == 1 then "" else "S"}`,
		accent = if keys > 0 then accent else Palette.lineSoft,
		filled = keys > 0,
		size = UDim2.fromOffset(78, 22),
		position = UDim2.fromOffset(10, 10),
	})), h("frame", {
		Size = if stack then UDim2.new(1, 0, 1, -infoY) else UDim2.new(1, -infoX, 1, 0),
		Position = UDim2.fromOffset(infoX, infoY),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, h(Text, {
		value = crate.Name,
		size = 20,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 13,
		sizeConstraint = UDim2.new(1, 0, 0, 26),
	}), h(Text, {
		value = crate.Description or "",
		size = 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 28),
		sizeConstraint = UDim2.new(1, 0, 0, 30),
	}), h(Text, {
		value = pityLine,
		size = 11,
		color = accent,
		weight = Enum.FontWeight.Bold,
		position = UDim2.fromOffset(0, 60),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), h("frame", {
		Size = UDim2.new(1, 0, 0, #odds * 22),
		Position = UDim2.fromOffset(0, 82),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, oddsRows), h("frame", {
		Name = "CrateOpen",
		Size = UDim2.new(1, 0, 0, TapTarget),
		Position = UDim2.new(0, 0, 1, -TapTarget),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, openButton(1, 1), openButton(5, 2))))
end

local function crateStageHeight(stack, crate)
	local rows = #RelicSystem.odds(crate and crate.Weights)
	local info = 82 + rows * 22 + 10 + TapTarget + 28
	return if stack then 190 + 6 + info else math.max(280, info) + 28
end

local function CrateChip(props)
	local crate = props.crate
	local accent = if typeof(crate.Color) == "Color3" then crate.Color else Palette.violet
	return h("textbutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = if props.selected then darken(accent, 0.45) else Palette.panel,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = props.order,
		Event = {
			Activated = function()
				Audio:play("tabSwitch")
				props.onSelect()
			end,
		},
	}, h("uicorner", { CornerRadius = UDim.new(0, 12) }), h("uistroke", {
		Color = accent,
		Thickness = if props.selected then 2 else 1,
		Transparency = if props.selected then 0 else 0.6,
	}), h(Icon, {
		kind = "Crate",
		color = Palette.cream,
		accent = accent,
		size = 30,
		position = UDim2.new(0, 10, 0.5, -15),
		spin = false,
	}), h(Text, {
		value = crate.Name,
		size = 13,
		color = Palette.cream,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(48, 8),
		sizeConstraint = UDim2.new(1, -56, 0, 18),
	}), h(Text, {
		value = if props.keys > 0 then `{props.keys} key{if props.keys == 1 then "" else "s"}` else "No keys",
		size = 11,
		color = if props.keys > 0 then accent else Palette.muted,
		weight = Enum.FontWeight.Bold,
		position = UDim2.fromOffset(48, 28),
		sizeConstraint = UDim2.new(1, -56, 0, 16),
	}))
end

local function CratesSection(props)
	local state = props.state
	local config = props.config
	local stack = props.stack
	local crates = (config.Items and config.Items.Crates) or {}
	local items = state.Items or {}
	local keys = items.Keys or {}
	local firstWithKeys = nil
	for _, crate in crates do
		if (keys[crate.Id] or 0) > 0 then
			firstWithKeys = crate.Id
			break
		end
	end
	local selected, setSelected = React.useState(firstWithKeys or (crates[1] and crates[1].Id))
	local busy, setBusy = React.useState(false)
	local attempt = React.useRef(0)
	local mounted = React.useRef(true)
	React.useEffect(function()
		mounted.current = true
		return function()
			mounted.current = false
		end
	end, {})
	local crate = crateById(config, selected) or crates[1]
	if crate == nil then
		return h(Text, { value = "No crates right now.", size = 14, color = Palette.creamSoft })
	end
	local skin = state.Cosmetics and state.Cosmetics.CrateSkin
	local onOpen = function(count)
		if busy or props.crateRevealActive then
			return
		end
		attempt.current += 1
		local mine = attempt.current
		setBusy(true)
		props.dispatch("OpenItemCrate", { Id = crate.Id, Count = count }, function(response)
			if not mounted.current or attempt.current ~= mine then
				return
			end
			setBusy(false)
			if response.ok and type(response.Rolls) == "table" and #response.Rolls > 0 and props.onCrateReveal ~= nil then
				props.onCrateReveal({
					crateId = crate.Id,
					crateName = crate.Name,
					accent = crate.Color,
					rolls = response.Rolls,
				})
			end
		end)
	end
	local columns = if stack then 2 elseif props.width >= 1000 then 4 else 3
	local chips = {}
	for index, entry in crates do
		chips[entry.Id] = h(CrateChip, {
			crate = entry,
			order = index,
			keys = keys[entry.Id] or 0,
			selected = entry.Id == crate.Id,
			onSelect = function()
				setSelected(entry.Id)
			end,
		})
	end
	local chipsH = rowsHeight(#crates, columns, 58)
	return React.createElement(PageScaffold, {
		gap = GAP,
		tailPad = props.tailPad,
		scrollBarColor = Palette.violet,
		sections = {
			{
				id = "hero",
				height = heroHeight(stack),
				element = h(Hero, {
					title = "Crates",
					body = "Every crate's odds, all the way up to Celestial and Astral. Your crate skin opens every one.",
					accent = Palette.violet,
					icon = "Crate",
					state = state,
					stack = stack,
					reveal = props.reveal,
					reducedMotion = props.reducedMotion,
				}),
			},
			{
				id = "stage",
				height = crateStageHeight(stack, crate),
				element = h(CrateStage, {
					key = crate.Id,
					crate = crate,
					config = config,
					stack = stack,
					keys = keys[crate.Id] or 0,
					pity = items.Pity and items.Pity[crate.Id] or 0,
					skin = skin,
					busy = busy or props.crateRevealActive == true,
					onOpen = onOpen,
					reducedMotion = props.reducedMotion,
				}),
			},
			{
				id = "chips",
				height = chipsH,
				element = h(Grid, { columns = columns, cell = 58, height = chipsH, cells = chips }),
			},
		},
	})
end

local function skinStatus(skin, cosmetics)
	local owned = cosmetics.CrateSkins and cosmetics.CrateSkins[skin.Id] == true or skin.Default == true
	local equipped = (cosmetics.CrateSkin or ShopCatalog.DEFAULT_SKIN) == skin.Id
	return owned, equipped
end

local function SkinPreview(props)
	local skin = props.skin
	local stack = props.stack
	local owned, equipped = skinStatus(skin, props.cosmetics)
	local accent = skinAccent(skin.Id)
	local price = skin.Price
	local have = if price then tonumber(props.state[price.Currency]) or 0 else 0
	local short = if price then math.max(0, price.Amount - have) else 0
	local peek, setPeek = React.useState(false)
	local action, label, enabled
	if equipped then
		action, label, enabled = nil, "EQUIPPED", false
	elseif owned then
		action, label, enabled = "EquipCrateSkin", "EQUIP", true
	elseif skin.DailyOnly then
		action, label, enabled = nil, "DAILY SHOP ONLY", false
	elseif short > 0 then
		action, label, enabled = nil, `NEED {commas(short)} {string.upper(price.Currency)}`, false
	else
		action, label, enabled = "BuyCrateSkin", `BUY · {commas(price.Amount)} {string.upper(price.Currency)}`, true
	end
	enabled = enabled and not props.busy
	local modelSize = if stack then 200 else 250
	return h(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = accent,
		background = Palette.panelRaised,
		padding = 14,
		highlight = true,
		reducedMotion = props.reducedMotion,
		clips = false,
	}, h("textbutton", {
		Size = if stack then UDim2.new(1, 0, 0, modelSize) else UDim2.fromOffset(modelSize, modelSize),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Event = {
			Activated = function()
				setPeek(not peek)
				Audio:play(if peek then "close" else "crateOpen")
			end,
		},
	}, h("uicorner", { CornerRadius = UDim.new(0, 14) }), h("uigradient", {
		Color = ColorSequence.new(darken(accent, 0.5), Palette.void),
		Rotation = 90,
	}), h(CrateModel, {
		skin = skin.Id,
		spin = true,
		open = if peek then 1 else 0,
		live = not props.reducedMotion,
		zoom = 0.82,
	}), h(Text, {
		value = if peek then "Tap to close" else "Tap to look inside",
		size = 11,
		color = Palette.muted,
		align = Enum.TextXAlignment.Center,
		position = UDim2.new(0, 0, 1, -20),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	})), h("frame", {
		Size = if stack then UDim2.new(1, 0, 1, -(modelSize + 8)) else UDim2.new(1, -(modelSize + 16), 1, 0),
		Position = if stack then UDim2.fromOffset(0, modelSize + 8) else UDim2.fromOffset(modelSize + 16, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, h(Badge, {
		value = string.upper(skin.Tier or "Common"),
		accent = TIER_COLOR[skin.Tier] or accent,
		filled = true,
		size = UDim2.fromOffset(92, 20),
	}), h(Text, {
		value = skin.Name,
		size = 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 14,
		position = UDim2.fromOffset(0, 26),
		sizeConstraint = UDim2.new(1, 0, 0, 30),
	}), h(Text, {
		value = skin.Blurb,
		size = 13,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 60),
		sizeConstraint = UDim2.new(1, 0, 0, 40),
	}), h(Text, {
		value = if owned then "Yours. Every crate you open wears the equipped skin." else "Equip this skin for its guaranteed essence bonus.",
		size = 11,
		color = accent,
		weight = Enum.FontWeight.Bold,
		wrap = true,
		position = UDim2.fromOffset(0, 104),
		sizeConstraint = UDim2.new(1, 0, 0, 30),
	}), h("frame", {
		Name = "SkinClaim",
		Size = UDim2.new(1, 0, 0, TapTarget),
		Position = UDim2.new(0, 0, 1, -TapTarget),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, h(Button, {
		text = label,
		icon = if equipped then "Check" elseif enabled then "Shop" else "Lock",
		onClick = function()
			if action ~= nil then
				props.onAction(action, skin.Id)
			end
		end,
		color = if enabled then accent else Palette.panelSoft,
		textColor = if enabled then Palette.ink else Palette.creamSoft,
		size = UDim2.fromScale(1, 1),
		disabled = not enabled,
		reducedMotion = props.reducedMotion,
		highlight = enabled,
		selectable = enabled,
	}))))
end

local function SkinCard(props)
	local skin = props.skin
	local owned, equipped = skinStatus(skin, props.cosmetics)
	local accent = skinAccent(skin.Id)
	return h("textbutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = if props.selected then darken(accent, 0.5) else Palette.panel,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = props.order,
		Event = {
			Activated = function()
				Audio:play("tabSwitch")
				props.onSelect()
			end,
		},
	}, h("uicorner", { CornerRadius = UDim.new(0, 14) }), h("uistroke", {
		Color = accent,
		Thickness = if props.selected then 2 else 1,
		Transparency = if props.selected then 0 else 0.55,
	}), h(CrateModel, {
		skin = skin.Id,
		live = false,
		size = UDim2.new(1, 0, 1, -40),
		zoom = 0.9,
	}), skin.Id == "Celestial" and h(PrismAura, {
		rarity = "Celestial",
		intensity = 0.7,
		rays = false,
		corner = 14,
	}), h(Text, {
		value = skin.Name,
		size = 13,
		color = Palette.cream,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 10,
		align = Enum.TextXAlignment.Center,
		position = UDim2.new(0, 6, 1, -38),
		sizeConstraint = UDim2.new(1, -12, 0, 18),
	}), h(Text, {
		value = if equipped then "EQUIPPED" elseif owned then "OWNED" elseif skin.DailyOnly then "DAILY SHOP" else `{commas(skin.Price.Amount)} {string.upper(skin.Price.Currency)}`,
		size = 11,
		color = if equipped then Palette.mint elseif owned then Palette.creamSoft else accent,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Center,
		position = UDim2.new(0, 6, 1, -20),
		sizeConstraint = UDim2.new(1, -12, 0, 16),
	}))
end

local function SkinsSection(props)
	local state = props.state
	local stack = props.stack
	local cosmetics = state.Cosmetics or { CrateSkins = { Classic = true }, CrateSkin = ShopCatalog.DEFAULT_SKIN }
	local selected, setSelected = React.useState(cosmetics.CrateSkin or ShopCatalog.DEFAULT_SKIN)
	local busy, setBusy = React.useState(false)
	local mounted = React.useRef(true)
	React.useEffect(function()
		mounted.current = true
		return function()
			mounted.current = false
		end
	end, {})
	local skin = ShopCatalog.skin(selected) or ShopCatalog.skin(ShopCatalog.DEFAULT_SKIN)
	local onAction = function(action, id)
		if busy then
			return
		end
		setBusy(true)
		props.dispatch(action, { Id = id }, function(response)
			if not mounted.current then
				return
			end
			setBusy(false)
			if response.ok then
				Audio:play(if action == "BuyCrateSkin" then "purchase" else "confirm")
			end
		end)
	end
	local columns = if stack then 2 elseif props.width >= 1000 then 4 else 3
	local ownedSkins = cosmetics.CrateSkins or {}
	local skinBrowse = Browse.useBrowse({
		id = "Skins",
		items = ShopCatalog.SKINS,
		text = function(entry)
			return { entry.Name, entry.Description, entry.Rarity }
		end,
		categories = {
			{ id = "All", label = "All" },
			{ id = "Owned", label = "Owned", test = function(entry)
				return ownedSkins[entry.Id] == true
			end },
			{ id = "Locked", label = "Not owned", test = function(entry)
				return ownedSkins[entry.Id] ~= true
			end },
		},
	})
	local cells = {}
	for index, entry in skinBrowse.results do
		cells[entry.Id] = h(SkinCard, {
			skin = entry,
			order = index,
			cosmetics = cosmetics,
			selected = entry.Id == skin.Id,
			onSelect = function()
				setSelected(entry.Id)
			end,
		})
	end
	local cellH = 156
	local gridH = rowsHeight(math.max(1, #skinBrowse.results), columns, cellH)
	return React.createElement(PageScaffold, {
		gap = GAP,
		tailPad = props.tailPad,
		scrollBarColor = Palette.cyan,
		sections = {
			{
				id = "hero",
				height = heroHeight(stack),
				element = h(Hero, {
					title = "Crate Skins",
					body = "Dress the crate you open. The Celestial Ark only ever turns up in the Daily Shop.",
					accent = Palette.cyan,
					icon = "Crate",
					state = state,
					stack = stack,
					reveal = props.reveal,
					reducedMotion = props.reducedMotion,
				}),
			},
			{
				id = "preview",
				height = if stack then 200 + 8 + 140 + TapTarget + 28 else 278,
				element = h(SkinPreview, {
					key = skin.Id,
					skin = skin,
					state = state,
					cosmetics = cosmetics,
					stack = stack,
					busy = busy,
					onAction = onAction,
					reducedMotion = props.reducedMotion,
				}),
			},
			{
				id = "filter",
				height = Browse.CHIP_H,
				element = h(Browse.ChipRow, {
					options = skinBrowse.categories,
					value = skinBrowse.category,
					onChange = skinBrowse.setCategory,
					counts = skinBrowse.counts,
					accent = Palette.cyan,
				}),
			},
			{
				id = "grid",
				height = gridH,
				element = h(Grid, { columns = columns, cell = cellH, height = gridH, cells = cells }),
			},
		},
	})
end

local function CodexProgress(props)
	local config = props.config
	local progress = props.progress
	local bonuses = (config.Items and config.Items.CodexBonus) or {}
	local rows = {
		Layout = h("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, rarity in RelicSystem.ORDER do
		local row = progress[rarity]
		if row == nil or row.total == 0 then
			continue
		end
		local done = row.found == row.total
		local color = rarityColor(config, rarity)
		rows[rarity] = h("frame", {
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = index,
		}, h(Text, {
			value = rarity,
			size = 12,
			color = color,
			weight = Enum.FontWeight.Bold,
			position = UDim2.fromOffset(0, 3),
			sizeConstraint = UDim2.new(0, 84, 0, 16),
		}), h(Meter, {
			value = row.found / row.total,
			color = color,
			size = UDim2.new(1, -230, 0, 8),
			position = UDim2.fromOffset(90, 7),
			reducedMotion = props.reducedMotion,
		}), h(Text, {
			value = `{row.found}/{row.total}`,
			size = 12,
			color = Palette.cream,
			weight = Enum.FontWeight.Bold,
			align = Enum.TextXAlignment.Right,
			position = UDim2.new(1, -134, 0, 3),
			sizeConstraint = UDim2.fromOffset(44, 16),
		}), h(Text, {
			value = `{if done then "✓ " else ""}+{math.floor((tonumber(bonuses[rarity]) or 0) * 1000 + 0.5) / 10}%`,
			size = 12,
			color = if done then Palette.mint else Palette.muted,
			weight = Enum.FontWeight.Bold,
			align = Enum.TextXAlignment.Right,
			position = UDim2.new(1, -84, 0, 3),
			sizeConstraint = UDim2.fromOffset(84, 16),
		}))
	end
	return h(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.mint,
		background = Palette.panelRaised,
		padding = 14,
		reducedMotion = props.reducedMotion,
		clips = false,
	}, h(Text, {
		value = `Codex bonus: +{math.floor((tonumber(props.bonus) or 0) * 1000 + 0.5) / 10}% production`,
		size = 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, 0, 0, 22),
	}), h(Text, {
		value = "Find every relic of a rarity to earn its bonus for good.",
		size = 12,
		color = Palette.creamSoft,
		position = UDim2.fromOffset(0, 24),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	}), h("frame", {
		Size = UDim2.new(1, 0, 1, -50),
		Position = UDim2.fromOffset(0, 50),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, rows))
end

local function RelicCell(props)
	local definition = props.definition
	local found = props.found
	local color = rarityColor(props.config, definition.Rarity)
	local ascended = isAscended(definition.Rarity)
	return h("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = if found then darken(color, 0.72) else Palette.panel,
		BorderSizePixel = 0,
		LayoutOrder = props.order,
	}, h("uicorner", { CornerRadius = UDim.new(0, 12) }), h("uistroke", {
		Color = if found then color else Palette.line,
		Thickness = 1,
		Transparency = if found then 0.25 else 0.5,
	}), found and ascended and h(PrismAura, {
		rarity = definition.Rarity,
		intensity = 1,
		rays = false,
		corner = 12,
	}), h(Text, {
		value = if found then definition.Name else "???",
		size = 13,
		color = if found then Palette.cream else Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(10, 8),
		sizeConstraint = UDim2.new(1, -20, 0, 18),
	}), h(Text, {
		value = if found then (if props.copies > 0 then `{props.copies} owned{if props.stars > 0 then "  " .. string.rep("★", props.stars) else ""}` else "Found before") else `{definition.Slot} relic · not found yet`,
		size = 11,
		color = if found then color else Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(10, 28),
		sizeConstraint = UDim2.new(1, -20, 0, 16),
	}), props.canFuse and h(Button, {
		text = "FUSE",
		icon = "Forge",
		onClick = props.onFuse,
		color = color,
		textColor = Palette.ink,
		size = UDim2.new(1, -20, 0, 30),
		position = UDim2.new(0, 10, 1, -38),
		disabled = props.busy,
		reducedMotion = props.reducedMotion,
		highlight = not props.busy,
	}))
end

local function CodexSection(props)
	local state = props.state
	local config = props.config
	local stack = props.stack
	local items = state.Items or {}
	local discovered = items.Discovered or {}
	local inventory = items.Inventory or {}
	local definitions = (config.Items and config.Items.Definitions) or {}
	local maxStars = (config.Items and config.Items.MaxStars) or 5
	local busy, setBusy = React.useState(false)
	local mounted = React.useRef(true)
	React.useEffect(function()
		mounted.current = true
		return function()
			mounted.current = false
		end
	end, {})
	local progress = RelicSystem.codex(discovered, config.Items)
	local copies, stars = {}, {}
	for _, instance in inventory do
		if type(instance) == "table" and type(instance.DefinitionId) == "string" then
			local id = instance.DefinitionId
			copies[id] = (copies[id] or 0) + 1
			stars[id] = math.max(stars[id] or 0, RelicSystem.stars(instance))
		end
	end
	local function isFound(definition)
		return discovered[definition.Id] == true or (copies[definition.Id] or 0) > 0
	end
	local function canFuseRelic(definition)
		return (copies[definition.Id] or 0) >= 2 and RelicSystem.fusionPair(inventory, items.Equipped, definition.Id, maxStars) ~= nil
	end
	local codexBrowse = Browse.useBrowse({
		id = "Codex",
		items = definitions,
		textKey = tostring(#inventory),
		text = function(definition)
			-- undiscovered relics only match on slot and rarity, so search never spoils names
			if isFound(definition) then
				return { definition.Name, definition.Description, definition.Rarity, definition.Slot, definition.EffectKind }
			end
			return { nil, nil, definition.Rarity, definition.Slot }
		end,
		categories = {
			{ id = "All", label = "All" },
			{ id = "Found", label = "Found", test = isFound },
			{ id = "Missing", label = "Missing", test = function(definition)
				return not isFound(definition)
			end },
			{ id = "Owned", label = "Owned", test = function(definition)
				return (copies[definition.Id] or 0) > 0
			end },
			{ id = "Fuse", label = "Can fuse", test = canFuseRelic },
		},
	})
	local shownIds = {}
	for _, definition in codexBrowse.results do
		shownIds[definition.Id] = true
	end
	local fuse = function(definition)
		if busy then
			return
		end
		setBusy(true)
		props.dispatch("FuseRelics", { Id = definition.Id }, function(response)
			if not mounted.current then
				return
			end
			setBusy(false)
			if response.ok then
				Audio:play("autoForge")
			end
		end)
	end
	local columns = if stack then 2 elseif props.width >= 1000 then 4 else 3
	local cellH = 96
	local sections = {
		{
			id = "hero",
			height = heroHeight(stack),
			element = h(Hero, {
				title = "Relic Codex",
				body = `Every relic in the forge. Fuse a spare copy into a relic for a star: +{math.floor(((config.Items and config.Items.StarBonus) or 0.25) * 100)}% effect each, up to {maxStars}.`,
				accent = Palette.mint,
				icon = "Artifact",
				state = state,
				stack = stack,
				reveal = props.reveal,
				reducedMotion = props.reducedMotion,
			}),
		},
	}
	local progressRows = 0
	for _, rarity in RelicSystem.ORDER do
		if progress[rarity] and progress[rarity].total > 0 then
			progressRows += 1
		end
	end
	table.insert(sections, {
		id = "progress",
		height = 50 + progressRows * 26 + 24,
		element = h(CodexProgress, {
			config = config,
			progress = progress,
			bonus = items.CodexBonus,
			reducedMotion = props.reducedMotion,
		}),
	})
	table.insert(sections, {
		id = "browse",
		height = Browse.barHeight(stack, true),
		element = h(Browse.BrowseBar, {
			browse = codexBrowse,
			placeholder = "Search relics by name, slot or rarity",
			accent = Palette.mint,
			stack = stack,
			reducedMotion = props.reducedMotion,
			zIndex = 30,
		}),
	})
	if #codexBrowse.results == 0 then
		table.insert(sections, {
			id = "none",
			height = 220,
			element = h(Browse.NoResults, {
				browse = codexBrowse,
				noun = "relics",
				icon = "Artifact",
				accent = Palette.mint,
				reducedMotion = props.reducedMotion,
				size = UDim2.fromScale(1, 1),
			}),
		})
	end
	for index = #RelicSystem.ORDER, 1, -1 do
		local rarity = RelicSystem.ORDER[index]
		local cells = {}
		local count = 0
		for order, definition in definitions do
			if definition.Rarity ~= rarity or not shownIds[definition.Id] then
				continue
			end
			count += 1
			local canFuse = canFuseRelic(definition)
			cells[definition.Id] = h(RelicCell, {
				definition = definition,
				order = order,
				config = config,
				found = discovered[definition.Id] == true or (copies[definition.Id] or 0) > 0,
				copies = copies[definition.Id] or 0,
				stars = stars[definition.Id] or 0,
				canFuse = canFuse,
				busy = busy,
				onFuse = function()
					fuse(definition)
				end,
				reducedMotion = props.reducedMotion,
			})
		end
		if count == 0 then
			continue
		end
		local gridH = rowsHeight(count, columns, cellH)
		local color = rarityColor(config, rarity)
		table.insert(sections, {
			id = `label{rarity}`,
			height = 22,
			element = h(Text, {
				value = `{string.upper(rarity)}  ·  {progress[rarity].found}/{progress[rarity].total}`,
				size = 13,
				color = color,
				weight = Enum.FontWeight.Heavy,
				sizeConstraint = UDim2.new(1, 0, 0, 20),
			}),
		})
		table.insert(sections, {
			id = `grid{rarity}`,
			height = gridH,
			element = h(Grid, { columns = columns, cell = cellH, height = gridH, cells = cells }),
		})
	end
	return React.createElement(PageScaffold, {
		gap = GAP,
		tailPad = props.tailPad,
		scrollBarColor = Palette.mint,
		sections = sections,
	})
end

local function artifactEffectText(artifact)
	local per = tonumber(artifact.EffectPerLevel) or 0
	if artifact.EffectKind == "OfflineHours" then
		return `+{string.format("%.2f", per)}h offline cap per level`
	end
	return `+{string.format("%.1f", per * 100)}% {artifact.EffectKind} per level`
end

local function ArtifactCard(props)
	local artifact = props.artifact
	local tone = ARTIFACT_RARITY[artifact.Rarity] or ARTIFACT_RARITY.COMMON
	local accent = artifact.Color or tone.color
	local element = artifact.Element or "Void"
	local sheet = elementSheet(element)
	local elementColor = if sheet then sheet.Color else accent
	local elementGlow = if sheet then sheet.Glow else accent
	local owned = props.owned
	local price = props.price
	local cost = if price == nil then nil elseif owned then price.Refill else price.Stardust
	local have = tonumber(props.dust) or 0
	local enabled = cost ~= nil and have >= cost and not props.busy
	local label = if cost == nil
		then "NOT SOLD"
		elseif have < cost then `NEED {commas(cost - have)} DUST`
		elseif owned then `+{price.Fragments} FRAGMENTS · {commas(cost)}`
		else `ACQUIRE · {commas(cost)} DUST`
	local hovered, setHovered = React.useState(false)
	local lightH = if props.stack then 116 else 132
	local fxSize = lightH
	local elementBadgeW = math.max(62, #(if sheet then sheet.Label else element) * 7 + 14)
	return h("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		LayoutOrder = props.order,
		Event = {
			MouseEnter = function()
				setHovered(true)
			end,
			MouseLeave = function()
				setHovered(false)
			end,
		},
	}, h("uicorner", { CornerRadius = UDim.new(0, 14) }), h("uistroke", {
		Color = elementColor:Lerp(accent, 0.35),
		Thickness = if hovered or tone.rank >= 5 then 2 else 1,
		Transparency = if hovered then 0.05 elseif owned then 0.3 else 0.55,
	}), h("uipadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	}), h("frame", {
		Name = "Stage",
		Size = UDim2.new(1, 0, 0, lightH),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, h("uicorner", { CornerRadius = UDim.new(0, 12) }), h("uigradient", {
		Color = ColorSequence.new(darken(elementColor, 0.6), Palette.void),
		Rotation = 90,
	}), h(ElementFx, {
		element = element,
		size = UDim2.fromOffset(fxSize, fxSize),
		position = UDim2.fromScale(0.5, 0.5),
		framerate = 24,
		-- acquiring the artifact plays its companion's reveal
		reaction = "reveal",
		reactionKey = owned == true,
		reducedMotion = props.reducedMotion,
		zIndex = 2,
	}), h(Badge, {
		value = string.upper(tone.label),
		accent = tone.color,
		filled = tone.rank >= 4,
		size = UDim2.fromOffset(84, 18),
		position = UDim2.fromOffset(6, 6),
	}), h(Badge, {
		value = if sheet then sheet.Label else string.upper(element),
		accent = elementColor,
		filled = true,
		size = UDim2.fromOffset(elementBadgeW, 18),
		position = UDim2.new(1, -(elementBadgeW + 6), 0, 6),
	}), if artifact.ShopOnly and not owned
		then h(Badge, {
			value = "Shop exclusive",
			accent = elementGlow,
			filled = false,
			size = UDim2.fromOffset(106, 18),
			position = UDim2.new(1, -112, 1, -24),
		})
		else nil, if owned
		then h(Badge, {
			value = `LV {owned.Level or 1} · {owned.Fragments or 0} FRAG`,
			accent = Palette.cream,
			filled = false,
			size = UDim2.fromOffset(112, 18),
			position = UDim2.new(0, 6, 1, -24),
		})
		else nil), h(Text, {
		value = artifact.Name,
		size = 15,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(2, lightH + 8),
		sizeConstraint = UDim2.new(1, -4, 0, 20),
	}), h(Text, {
		value = artifactEffectText(artifact),
		size = 11,
		color = elementColor:Lerp(Palette.cream, 0.25),
		weight = Enum.FontWeight.Bold,
		position = UDim2.fromOffset(2, lightH + 28),
		sizeConstraint = UDim2.new(1, -4, 0, 14),
	}), h(Text, {
		value = artifact.Description,
		size = 11,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(2, lightH + 44),
		sizeConstraint = UDim2.new(1, -4, 0, 28),
	}), h("frame", {
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.new(0, 0, 1, -36),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, h(Button, {
		text = label,
		icon = if enabled then "Shop" else "Lock",
		onClick = function()
			if enabled then
				props.onBuy(artifact)
			end
		end,
		color = if enabled then elementColor else Palette.panelSoft,
		textColor = if enabled then Palette.ink else Palette.creamSoft,
		size = UDim2.fromScale(1, 1),
		disabled = not enabled,
		reducedMotion = props.reducedMotion,
		highlight = enabled and tone.rank >= 4,
		selectable = enabled,
	})))
end

local function ArtifactsSection(props)
	local state = props.state
	local config = props.config
	local stack = props.stack
	local ops = config.Operations or {}
	local artifacts = ops.Artifacts or {}
	local prices = ops.ArtifactShop or {}
	local owned = (state.Command and state.Command.Artifacts) or {}
	local busy, setBusy = React.useState(false)
	local mounted = React.useRef(true)
	React.useEffect(function()
		mounted.current = true
		return function()
			mounted.current = false
		end
	end, {})
	local ordered = table.clone(artifacts)
	table.sort(ordered, function(a, b)
		local ra = (ARTIFACT_RARITY[a.Rarity] or ARTIFACT_RARITY.COMMON).rank
		local rb = (ARTIFACT_RARITY[b.Rarity] or ARTIFACT_RARITY.COMMON).rank
		if ra ~= rb then
			return ra > rb
		end
		return a.Name < b.Name
	end)
	local dust = tonumber(state.Stardust) or 0
	local browse = Browse.useBrowse({
		id = "Artifacts",
		items = ordered,
		textKey = tostring(dust),
		text = function(artifact)
			return { artifact.Name, artifact.Description, artifact.Rarity, artifact.EffectKind }
		end,
		categories = {
			{ id = "All", label = "All" },
			{ id = "Missing", label = "Missing", test = function(artifact)
				return owned[artifact.Id] == nil
			end },
			{ id = "Owned", label = "Owned", test = function(artifact)
				return owned[artifact.Id] ~= nil
			end },
			{ id = "Exclusive", label = "Shop exclusive", test = function(artifact)
				return artifact.ShopOnly == true
			end },
			{ id = "Affordable", label = "Affordable", test = function(artifact)
				local price = prices[artifact.Rarity]
				local cost = price and (if owned[artifact.Id] then price.Refill else price.Stardust)
				return cost ~= nil and dust >= cost
			end },
		},
	})
	local onBuy = function(artifact)
		if busy then
			return
		end
		setBusy(true)
		props.dispatch("BuyArtifact", { Id = artifact.Id }, function(response)
			if not mounted.current then
				return
			end
			setBusy(false)
			Audio:play(if response.ok then "purchase" else "error")
		end)
	end
	local columns = if stack then 2 elseif props.width >= 1000 then 4 else 3
	local cellH = if stack then 262 else 282
	local cells = {}
	for order, artifact in browse.results do
		cells[artifact.Id] = h(ArtifactCard, {
			artifact = artifact,
			order = order,
			owned = owned[artifact.Id],
			price = prices[artifact.Rarity],
			dust = dust,
			busy = busy,
			stack = stack,
			onBuy = onBuy,
			reducedMotion = props.reducedMotion,
		})
	end
	local ownedCount = 0
	for _, artifact in artifacts do
		if owned[artifact.Id] ~= nil then
			ownedCount += 1
		end
	end
	local sections = {
		{
			id = "hero",
			height = heroHeight(stack),
			element = h(Hero, {
				title = "Artifact Vault",
				body = `Buy rare artifacts outright for stardust. Ones you hold restock as upgrade fragments. {ownedCount}/{#artifacts} held.`,
				accent = Palette.violet,
				icon = "Artifact",
				state = state,
				stack = stack,
				reveal = props.reveal,
				reducedMotion = props.reducedMotion,
			}),
		},
		{
			id = "browse",
			height = Browse.barHeight(stack, true),
			element = h(Browse.BrowseBar, {
				browse = browse,
				placeholder = "Search artifacts by name, effect or rarity",
				accent = Palette.violet,
				stack = stack,
				reducedMotion = props.reducedMotion,
				zIndex = 30,
			}),
		},
	}
	if #browse.results == 0 then
		table.insert(sections, {
			id = "none",
			height = 220,
			element = h(Browse.NoResults, {
				browse = browse,
				noun = "artifacts",
				icon = "Artifact",
				accent = Palette.violet,
				reducedMotion = props.reducedMotion,
				size = UDim2.fromScale(1, 1),
			}),
		})
	else
		local gridH = rowsHeight(#browse.results, columns, cellH)
		table.insert(sections, {
			id = "grid",
			height = gridH,
			element = h(Grid, { columns = columns, cell = cellH, height = gridH, cells = cells }),
		})
	end
	return React.createElement(PageScaffold, {
		gap = GAP,
		tailPad = props.tailPad,
		scrollBarColor = Palette.violet,
		sections = sections,
	})
end

local function StoreFront(props)
	local viewport = useViewport()
	local hostRef = React.useRef(nil)
	local contentWidth, setContentWidth = React.useState(viewport.width)
	React.useEffect(function()
		local host = hostRef.current
		if host == nil then
			return nil
		end
		local function measure()
			if host.AbsoluteSize.X > 0 then
				setContentWidth(host.AbsoluteSize.X)
			end
		end
		measure()
		local connection = host:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
		return function()
			connection:Disconnect()
		end
	end, {})
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local softMotion = props.reducedMotion
	local linked = Browse.Model.recall("Shop")
	local section, setSection = React.useState(props.initialSection or (linked and linked.category) or "Daily")
	-- Quick Find opens a section directly ("crates", "codex", "skins" ...)
	React.useEffect(function()
		return Browse.Model.listen("Shop", function(entry)
			if entry.category ~= nil then
				setSection(entry.category)
			end
		end)
	end, {})
	React.useEffect(function()
		Browse.Model.remember("Shop", { query = "", category = section })
	end, { section })
	local reveal = useStagger(0, softMotion)
	local tabColumns, tabH = sectionTabLayout(contentWidth, if stack then TapTarget else 44)
	local shared = {
		key = section,
		state = props.state or {},
		config = props.config or {},
		dispatch = props.dispatch,
		reducedMotion = softMotion,
		stack = stack,
		width = viewport.width,
		reveal = reveal,
		tailPad = scrollTail(stack, chrome.bottomSafe, 32),
		navigate = props.navigate,
		onCrateReveal = props.onCrateReveal,
		crateRevealActive = props.crateRevealActive,
	}
	local body
	if section == "Daily" then
		body = h(DailySection, shared)
	elseif section == "Crates" then
		body = h(CratesSection, shared)
	elseif section == "Skins" then
		body = h(SkinsSection, shared)
	elseif section == "Codex" then
		body = h(CodexSection, shared)
	elseif section == "Artifacts" then
		body = h(ArtifactsSection, shared)
	else
		body = h(__load("ShopView").ShopView, {
			state = props.state,
			dispatch = props.dispatch,
			reducedMotion = softMotion,
			onPurchasePresentationChange = props.onPurchasePresentationChange,
		})
	end
	return h("frame", {
		Name = "StoreFrontHost",
		ref = hostRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, h("frame", {
		Name = "StoreSections",
		Size = UDim2.new(1, 0, 0, tabH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, h(SegmentedTabs, {
		options = SECTIONS,
		value = section,
		onChange = function(entry)
			setSection(entry)
		end,
		accent = Palette.mango,
		columns = tabColumns,
		gap = 6,
		size = UDim2.fromScale(1, 1),
		reducedMotion = softMotion,
	})), h("frame", {
		Name = "StoreSection",
		Size = UDim2.new(1, 0, 1, -(tabH + GAP)),
		Position = UDim2.fromOffset(0, tabH + GAP),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, body))
end

return {
	StoreFront = StoreFront,
}
end

__defs["WheelView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local _format = require(script.Parent.Parent.CoreKit)("format")
local clockText = _format.clockText
local compactNumber = _format.compactNumber
local formatReward = _format.formatReward
local _Icon = require(script.Parent.Parent.ArtKit)("Icon")
local Icon = _Icon.Icon
local InteractionFeedback = require(script.Parent.Parent.CoreKit)("interaction").InteractionFeedback
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useFlash = _motion.useFlash
local useGlowStroke = _motion.useGlowStroke
local useRotation = _motion.useRotation
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local useWallClock = _motion.useWallClock
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local Layout = _theme.Layout
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local lighten = _theme.lighten
local scrollTail = _theme.scrollTail
local surfaceGradient = _theme.surfaceGradient
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local FlatList = require(script.Parent.Parent.LayoutKit)("virtualizedList").FlatList
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local IconTile = _ui.IconTile
local Meter = _ui.Meter
local Panel = _ui.Panel
local Text = _ui.Text
-- The spin, in five parts. Angles in degrees, time in seconds.
--   windup  a short pull back against the spin
--   launch  ease in up to cruise speed
--   cruise  constant speed until the server has picked the prize
--   brake   quartic ease-out onto the prize (+ a little overshoot); it starts at exactly the
--           cruise speed so there is no hitch, and spends its last second crawling past pegs
--   settle  the peg catches the overshoot and the wheel rocks back onto the prize
local WHEEL_OMEGA = 1440
local WHEEL_OMEGA_LOW = 1080
local WHEEL_WINDUP_SECONDS = 0.3
local WHEEL_WINDUP_DEGREES = 18
local WHEEL_LAUNCH_SECONDS = 0.55
local WHEEL_MIN_CRUISE_SECONDS = 0.45
local WHEEL_SETTLE_SECONDS = 0.45
local WHEEL_OVERSHOOT_DEGREES = 4
local function sampleSpin(plan, elapsed)
	local omega = plan.omega
	if elapsed < WHEEL_WINDUP_SECONDS then
		local u = elapsed / WHEEL_WINDUP_SECONDS
		return plan.base - WHEEL_WINDUP_DEGREES * math.sin(u * math.pi / 2), 0
	end
	local start = plan.base - WHEEL_WINDUP_DEGREES
	local launched = elapsed - WHEEL_WINDUP_SECONDS
	if launched < WHEEL_LAUNCH_SECONDS then
		local u = launched / WHEEL_LAUNCH_SECONDS
		-- speed rises as u^2, so distance is the integral u^3 / 3
		return start + omega * WHEEL_LAUNCH_SECONDS * u * u * u / 3, omega * u * u
	end
	return start + omega * WHEEL_LAUNCH_SECONDS / 3 + omega * (launched - WHEEL_LAUNCH_SECONDS), omega
end
-- brake + settle: where the wheel is `elapsed` seconds after braking began
local function sampleBrake(plan, elapsed)
	if elapsed < plan.duration then
		local remaining = 1 - elapsed / plan.duration
		local r3 = remaining * remaining * remaining
		return plan.base + plan.distance * (1 - r3 * remaining), 4 * plan.distance / plan.duration * r3, false
	end
	local u = math.clamp((elapsed - plan.duration) / WHEEL_SETTLE_SECONDS, 0, 1)
	-- from +overshoot back to the prize, rocking once past it
	local rock = plan.overshoot * (1 - u) * math.cos(u * math.pi * 1.5)
	return plan.base + plan.distance - plan.overshoot + rock, 0, u >= 1
end
local function positiveModulo(value, modulus)
	return ((value % modulus) + modulus) % modulus
end
local unresolvedSpin = nil
local function wheelPrizeIndex(rewards, index, id)
	if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #rewards then return nil end
	if type(id) ~= "string" or rewards[index].Id ~= id then return nil end
	return index - 1
end
local function useWheelController(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local onLand = _param.onLand
	local antilag = useAntilag()
	local rewardCount = math.max(1, #config.Wheel.Rewards)
	local segment = 360 / rewardCount
	local receipt = state.Wheel.LastReceipt
	local restoredIndex = -1
	if receipt then
		restoredIndex = wheelPrizeIndex(config.Wheel.Rewards, receipt.PrizeIndex, receipt.PrizeId) or -1
	end
	local phase, setPhase = React.useState(if unresolvedSpin or (receipt and restoredIndex < 0) then "error" elseif restoredIndex >= 0 then "landed" else "idle")
	local winner, setWinner = React.useState(restoredIndex)
	local failure, setFailure = React.useState(if unresolvedSpin then "Confirm your interrupted spin before starting another."
		elseif receipt and restoredIndex < 0 then "Your saved reward does not match this wheel. Refresh before spinning." else nil)
	local launchNonce, setLaunchNonce = React.useState(0)
	local impactNonce, setImpactNonce = React.useState(0)
	local restoredRotation = if restoredIndex >= 0 then positiveModulo(360 - restoredIndex * segment, 360) else 0
	local rotation, setRotation = React.useBinding(restoredRotation)
	local pointerKick, setPointerKick = React.useBinding(0)
	local spinEnergy, setSpinEnergy = React.useBinding(0)
	local rotationValue = React.useRef(restoredRotation)
	local pointerKickValue = React.useRef(0)
	local busy = React.useRef(false)
	local mounted = React.useRef(true)
	local token = React.useRef(0)
	local timeout = React.useRef()
	local pendingResult = React.useRef()
	local launchFinished = React.useRef(false)
	local beginBrakeRef = React.useRef(function()
		return nil
	end)
	local motor = React.useRef({
		active = false,
		mode = "spin",
		base = 0,
		omega = WHEEL_OMEGA,
		startedAt = 0,
		lastSegment = 0,
		lastSoundAt = -math.huge,
	})
	local omegaRef = React.useRef(WHEEL_OMEGA)
	omegaRef.current = if antilag.tier <= 1 then WHEEL_OMEGA_LOW else WHEEL_OMEGA
	local spinning = phase == "launch" or phase == "coast" or phase == "brake"
	local audioTicks = not reducedMotion and antilag.fxBudget > 0.22
	local audioTicksRef = React.useRef(audioTicks)
	audioTicksRef.current = audioTicks
	local completeLanding = React.useCallback(function(result, finalRotation)
		if not mounted.current or not busy.current then
			return nil
		end
		local normalized = positiveModulo(finalRotation, 360)
		rotationValue.current = normalized
		pointerKickValue.current = 0
		setRotation(normalized)
		setPointerKick(0)
		setSpinEnergy(0)
		setWinner(result.index)
		setImpactNonce(function(value)
			return value + 1
		end)
		setPhase("landed")
		busy.current = false
		pendingResult.current = nil
		Audio:play("wheelLand")
		InteractionFeedback.reward()
		local _result = onLand
		if _result ~= nil then
			_result(result.message)
		end
	end, { onLand, setPointerKick, setRotation, setSpinEnergy })
	local beginBrake = React.useCallback(function(result)
		if not mounted.current or not busy.current then
			return nil
		end
		local wanted = positiveModulo(360 - result.index * segment, 360)
		if reducedMotion then
			Audio:play("wheelBrake")
			completeLanding(result, wanted)
			return nil
		end
		local now = os.clock()
		local plan = motor.current
		local current, speed = sampleSpin(plan, now - plan.startedAt)
		speed = math.max(speed, 360)
		local delta = positiveModulo(wanted - positiveModulo(current, 360), 360)
		local overshoot = math.min(WHEEL_OVERSHOOT_DEGREES, segment * 0.3)
		-- at least two full turns on the way down (three when the device has room for it)
		local distance = (if antilag.tier <= 1 then 720 else 1080) + delta + overshoot
		motor.current = {
			active = true,
			mode = "brake",
			base = current,
			omega = plan.omega,
			distance = distance,
			overshoot = overshoot,
			-- the quartic's opening speed is 4 * distance / duration: match the cruise exactly
			duration = 4 * distance / speed,
			startedAt = now,
			lastSegment = math.floor((current + segment / 2) / segment),
			lastSoundAt = plan.lastSoundAt,
			result = result,
		}
		rotationValue.current = current
		setPhase("brake")
		Audio:play("wheelBrake")
	end, { antilag.tier, completeLanding, reducedMotion, segment })
	beginBrakeRef.current = beginBrake
	React.useEffect(function()
		if not spinning then
			return nil
		end
		local connection = RunService.RenderStepped:Connect(function(deltaTime)
			-- the pointer springs back after each peg flicks it
			if pointerKickValue.current > 0 then
				pointerKickValue.current = math.max(0, pointerKickValue.current - deltaTime * 9)
				setPointerKick(pointerKickValue.current)
			end
			local plan = motor.current
			if not plan.active then
				return nil
			end
			local now = os.clock()
			local elapsed = now - plan.startedAt
			local braking = plan.mode == "brake"
			local value, speed, settled
			if braking then
				value, speed, settled = sampleBrake(plan, elapsed)
			else
				value, speed = sampleSpin(plan, elapsed)
			end
			rotationValue.current = value
			setRotation(value)
			local energy = math.clamp(speed / plan.omega, 0, 1)
			setSpinEnergy(energy)
			-- pegs sit on the segment edges; crossing one flicks the pointer and clicks
			local currentSegment = math.floor((value + segment / 2) / segment)
			if currentSegment ~= plan.lastSegment then
				plan.lastSegment = currentSegment
				-- a slow wheel gives the pointer time to swing further
				pointerKickValue.current = math.max(pointerKickValue.current, 0.4 + (1 - energy) * 0.6)
				setPointerKick(pointerKickValue.current)
				local interval = if energy > 0.6 then 0.055 else 0
				if audioTicksRef.current and now - plan.lastSoundAt >= interval then
					plan.lastSoundAt = now
					Audio:play(if braking and energy < 0.25 then "wheelSlow" else "wheelTick", 0.86 + energy * 0.3)
				end
			end
			if not braking then
				local result = pendingResult.current
				if result ~= nil and elapsed >= WHEEL_WINDUP_SECONDS + WHEEL_LAUNCH_SECONDS + WHEEL_MIN_CRUISE_SECONDS then
					beginBrakeRef.current(result)
				end
				return nil
			end
			if settled then
				plan.active = false
				completeLanding(plan.result, plan.base + plan.distance - plan.overshoot)
			end
		end)
		return function()
			return connection:Disconnect()
		end
	end, { completeLanding, segment, setPointerKick, setRotation, setSpinEnergy, spinning })
	React.useEffect(function()
		return function()
			mounted.current = false
			busy.current = false
			token.current += 1
			motor.current.active = false
			motor.current.onComplete = nil
			if timeout.current ~= nil then
				pcall(task.cancel, timeout.current)
			end
		end
	end, {})
	React.useEffect(function()
		if busy.current or not receipt then return end
		if unresolvedSpin and unresolvedSpin.ExpectedSpin == receipt.ExpectedSpin then unresolvedSpin = nil end
		if unresolvedSpin then return end
		local index = wheelPrizeIndex(config.Wheel.Rewards, receipt.PrizeIndex, receipt.PrizeId)
		if index == nil then
			setPhase("error")
			setFailure("Your saved reward does not match this wheel. Refresh before spinning.")
			return
		end
		local value = positiveModulo(360 - index * segment, 360)
		rotationValue.current = value
		setRotation(value)
		setWinner(index)
		setFailure(nil)
		setPhase("landed")
	end, { receipt, spinning, config.Wheel.Rewards, segment, setRotation })
	local spin = function()
		if busy.current or (not unresolvedSpin and not state.Wheel.CanSpin) then
			return nil
		end
		local order = unresolvedSpin or { ExpectedSpin = state.Wheel.Spins }
		unresolvedSpin = order
		busy.current = true
		local requestToken = token.current + 1
		token.current = requestToken
		pendingResult.current = nil
		launchFinished.current = false
		pointerKickValue.current = 0
		setPointerKick(0)
		setWinner(-1)
		setFailure(nil)
		setLaunchNonce(function(value)
			return value + 1
		end)
		Audio:play("wheelStart")
		InteractionFeedback.tap()
		if reducedMotion then
			launchFinished.current = true
			motor.current.active = false
			setPhase("coast")
		else
			motor.current = {
				active = true,
				mode = "spin",
				base = rotationValue.current,
				omega = omegaRef.current,
				startedAt = os.clock(),
				lastSegment = math.floor((rotationValue.current + segment / 2) / segment),
				lastSoundAt = -math.huge,
			}
			setPhase("launch")
		end
		if timeout.current ~= nil then
			pcall(task.cancel, timeout.current)
		end
		timeout.current = task.delay(12, function()
			timeout.current = nil
			if not mounted.current or token.current ~= requestToken or not busy.current then
				return nil
			end
			token.current += 1
			busy.current = false
			pendingResult.current = nil
			motor.current.active = false
			pointerKickValue.current = 0
			setPointerKick(0)
			setSpinEnergy(0)
			setPhase("error")
			setFailure("No result yet. Confirm the previous spin to check its saved reward.")
			Audio:play("requestTimeout")
		end)
		dispatch("SpinWheel", order, function(response)
			if response.Uncertain ~= true and unresolvedSpin == order then unresolvedSpin = nil end
			if not mounted.current or token.current ~= requestToken then
				return nil
			end
			if timeout.current ~= nil then
				pcall(task.cancel, timeout.current)
				timeout.current = nil
			end
			if not response.ok or response.PrizeIndex == nil then
				busy.current = false
				pendingResult.current = nil
				motor.current.active = false
				pointerKickValue.current = 0
				setPointerKick(0)
				setSpinEnergy(0)
				setPhase("error")
				local _condition = if response.Uncertain then "Connection interrupted. Confirm the previous spin before starting another." else response.error
				if _condition == nil then
					_condition = "The draw could not be completed."
				end
				setFailure(_condition)
				Audio:play("error")
				return nil
			end
			local resultIndex = wheelPrizeIndex(config.Wheel.Rewards, response.PrizeIndex, response.PrizeId)
			if resultIndex == nil then
				busy.current = false
				motor.current.active = false
				setPhase("error")
				setFailure("Your reward was saved, but its artwork is unavailable. Reopen the wheel to refresh.")
				return
			end
			local result = {
				index = resultIndex,
				message = response.message,
			}
			pendingResult.current = result
			if reducedMotion then
				beginBrakeRef.current(result)
			end
		end)
	end
	return {
		phase = phase,
		spinning = spinning,
		winner = winner,
		failure = failure,
		retry = unresolvedSpin ~= nil,
		launchNonce = launchNonce,
		impactNonce = impactNonce,
		rotation = rotation,
		pointerKick = pointerKick,
		spinEnergy = spinEnergy,
		spin = spin,
	}
end
local function PrizeWheelMachine(props)
	return React.createElement(require(script.Parent.Parent.PrizeWheel), props)
end
local function WheelConsole(_param)
	local state = _param.state
	local config = _param.config
	local controller = _param.controller
	local onSpin = _param.onSpin
	local height = _param.height
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local spinClaimHostRef = _param.spinClaimHostRef
	local compact = _param.compact
	if compact == nil then
		compact = false
	end
	local prize = if controller.winner >= 0 then config.Wheel.Rewards[controller.winner + 1] else nil
	local canSpin = state.Wheel.CanSpin == true or controller.retry
	local _condition = state.Wheel.PityMisses
	if _condition == nil then
		_condition = 0
	end
	local pityMisses = _condition
	local _condition_1 = state.Wheel.PityAfter
	if _condition_1 == nil then
		_condition_1 = config.Wheel.PityAfter
		if _condition_1 == nil then
			_condition_1 = 8
		end
	end
	local pityAfter = _condition_1
	local pityArmed = state.Wheel.PityArmed == true or pityMisses + 1 >= pityAfter
	local pityFill = if pityArmed then 1 else math.clamp(pityMisses / math.max(1, pityAfter), 0, 1)
	local now = useWallClock(not canSpin)
	local cooldown = now:map(function(timestamp)
		return `Ready again in {clockText(math.max(0, state.Wheel.ReadyAt - timestamp))}`
	end)
	local status = if controller.spinning then "SPINNING" elseif controller.failure ~= nil then "SPIN PAUSED" elseif prize ~= nil then "YOU WON" elseif canSpin then "READY TO SPIN" else "COOLING DOWN"
	local _result
	if controller.failure ~= nil then
		_result = if controller.retry then "Confirm your previous spin" else "Spin unavailable"
	else
		local _result_1 = prize
		if _result_1 ~= nil then
			_result_1 = _result_1.Name
		end
		local _condition_2 = _result_1
		if _condition_2 == nil then
			_condition_2 = (if controller.spinning then "Spinning…" elseif canSpin then "Spin ready" else "Next spin soon")
		end
		_result = _condition_2
	end
	local title = _result
	local _condition_2 = controller.failure
	if _condition_2 == nil then
		local _result_1 = prize
		if _result_1 ~= nil then
			_result_1 = _result_1.ShortLabel
		end
		_condition_2 = _result_1
		if _condition_2 == nil then
			local _result_2
			if controller.spinning then
				_result_2 = ""
			else
				local _result_3
				if canSpin then
					local _condition_3 = state.Wheel.FreeSpins
					if _condition_3 == nil then
						_condition_3 = 0
					end
					_result_3 = (if _condition_3 > 0 then `{compactNumber(state.Wheel.FreeSpins)} free spin{if state.Wheel.FreeSpins == 1 then "" else "s"} ready.` elseif pityArmed then ((config.ClientPageGuides and config.ClientPageGuides.Wheel and config.ClientPageGuides.Wheel.PityArmed) or "Guarantee ready: your next spin lands Rare or better.") elseif compact then "Tap once to spin." else ((config.ClientPageGuides and config.ClientPageGuides.Wheel and config.ClientPageGuides.Wheel.Ready) or "Tap SPIN in the middle of the wheel."))
				else
					_result_3 = cooldown
				end
				_result_2 = _result_3
			end
			_condition_2 = _result_2
		end
	end
	local detail = _condition_2
	local _result_1
	if controller.failure ~= nil then
		_result_1 = Palette.coral
	else
		local _result_2 = prize
		if _result_2 ~= nil then
			_result_2 = _result_2.Color
		end
		local _condition_3 = _result_2
		if _condition_3 == nil then
			_condition_3 = (if canSpin then Palette.mango else Palette.lineSoft)
		end
		_result_1 = _condition_3
	end
	local accent = _result_1
	local edge = if compact then 10 else 14
	local iconBox = if compact then 58 else 72
	local iconInset = if compact then 7 else 9
	local prizeIcon = if compact then 44 else 54
	local copyX = if compact then 78 else 98
	local copyRight = if compact then 88 else 112
	local statsTop = if compact then 176 else 156
	local statsHeight = if compact then 42 else 52
	local buttonHeight = if compact then 48 else 50
	local buttonBottom = if compact then 10 else 14
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	})
	local _exp_1 = React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel, 0.62),
		Rotation = 90,
	})
	local _exp_2 = React.createElement("uistroke", {
		Color = accent,
		Thickness = 1,
		Transparency = 0.42,
	})
	local _exp_3 = React.createElement("frame", {
		Size = UDim2.new(0.46, 0, 0, 3),
		Position = UDim2.fromOffset(edge, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.06), NumberSequenceKeypoint.new(1, 1) }),
	}))
	local _exp_4 = React.createElement("frame", {
		Size = UDim2.fromOffset(iconBox, iconBox),
		Position = UDim2.fromOffset(edge, if compact then 12 else 16),
		BackgroundColor3 = darken(accent, 0.76):Lerp(Palette.panelRaised, 0.42),
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = if prize ~= nil then 2 else 1,
		Transparency = if prize ~= nil then 0.08 else 0.46,
	}), if prize ~= nil then React.createElement("frame", {
		Size = UDim2.fromOffset(prizeIcon, prizeIcon),
		Position = UDim2.fromOffset(iconInset, iconInset),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Icon, {
		kind = _Icon.rewardIconKind(prize.Reward),
		color = prize.Color,
		accent = prize.Color,
		size = prizeIcon,
		reducedMotion = true,
		clipSafe = true,
	})) else React.createElement(Icon, {
		kind = "Wheel",
		color = Palette.cream,
		accent = Palette.mango,
		size = if compact then 40 else 48,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		reducedMotion = reducedMotion,
		clipSafe = true,
	}))
	local _exp_5 = React.createElement(Badge, {
		value = status,
		accent = accent,
		filled = prize ~= nil or controller.failure ~= nil,
		position = UDim2.fromOffset(copyX, if compact then 12 else 16),
		size = UDim2.new(1, -copyRight, 0, if compact then 22 else 24),
	})
	local _attributes = {
		value = title,
		size = if compact then 15 else 18,
	}
	local _result_2
	if controller.failure ~= nil then
		_result_2 = Palette.coral
	else
		local _result_3 = prize
		if _result_3 ~= nil then
			_result_3 = _result_3.Color
		end
		local _condition_3 = _result_3
		if _condition_3 == nil then
			_condition_3 = Palette.cream
		end
		_result_2 = _condition_3
	end
	_attributes.color = _result_2
	_attributes.weight = Enum.FontWeight.Heavy
	_attributes.fit = false
	_attributes.wrap = true
	_attributes.position = UDim2.fromOffset(copyX, if compact then 38 else 44)
	_attributes.sizeConstraint = UDim2.new(1, -copyRight, 0, 42)
	local _exp_6 = React.createElement(Text, _attributes)
	local _exp_7 = React.createElement(Text, {
		value = detail,
		size = 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(copyX, if compact then 82 else 88),
		sizeConstraint = UDim2.new(1, -copyRight, 0, if compact then 84 else 60),
	})
	local _exp_8 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 9),
	})
	local _exp_9 = React.createElement("uistroke", {
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.64,
	})
	local _attributes_1 = {}
	local _condition_3 = state.Wheel.FreeSpins
	if _condition_3 == nil then
		_condition_3 = 0
	end
	_attributes_1.value = if _condition_3 > 0 then "FREE SPINS" else "TOTAL SPINS"
	_attributes_1.size = 12
	_attributes_1.color = Palette.muted
	_attributes_1.weight = Enum.FontWeight.Heavy
	_attributes_1.position = UDim2.fromOffset(10, 5)
	_attributes_1.sizeConstraint = UDim2.new(1, -20, 0, 15)
	local _exp_10 = React.createElement(Text, _attributes_1)
	local _attributes_2 = {}
	local _condition_4 = state.Wheel.FreeSpins
	if _condition_4 == nil then
		_condition_4 = 0
	end
	_attributes_2.value = compactNumber(if _condition_4 > 0 then state.Wheel.FreeSpins else state.Wheel.Spins)
	_attributes_2.size = if compact then 14 else 16
	_attributes_2.color = Palette.cream
	_attributes_2.weight = Enum.FontWeight.Heavy
	_attributes_2.position = UDim2.fromOffset(10, if compact then 21 else 23)
	_attributes_2.sizeConstraint = UDim2.new(1, -20, 0, if compact then 18 else 22)
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, _exp, _exp_1, _exp_2, _exp_3, _exp_4, _exp_5, _exp_6, _exp_7, React.createElement("frame", {
		Size = UDim2.new(1, -edge * 2, 0, statsHeight),
		Position = UDim2.fromOffset(edge, statsTop),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("frame", {
		Size = UDim2.new(0.34, -5, 1, 0),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
	}, _exp_8, _exp_9, _exp_10, React.createElement(Text, _attributes_2)), React.createElement("frame", {
		Size = UDim2.new(0.66, -5, 1, 0),
		Position = UDim2.new(0.34, 5, 0, 0),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 9),
	}), React.createElement("uistroke", {
		Color = if pityArmed then Palette.mango else Palette.lineSoft,
		Thickness = 1,
		Transparency = if pityArmed then 0.28 else 0.64,
	}), React.createElement(Text, {
		value = "GUARANTEE",
		size = 12,
		color = if pityArmed then Palette.mango else Palette.muted,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(10, 5),
		sizeConstraint = UDim2.new(0.65, -10, 0, 15),
	}), React.createElement(Text, {
		value = if pityArmed then "Ready" else `{pityMisses} / {pityAfter}`,
		size = 12,
		color = if pityArmed then Palette.mango else Palette.creamSoft,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Right,
		position = UDim2.new(0.65, 0, 0, 5),
		sizeConstraint = UDim2.new(0.35, -10, 0, 15),
	}), React.createElement(Meter, {
		value = pityFill,
		color = if pityArmed then Palette.mango else Palette.violet,
		reducedMotion = reducedMotion,
		shimmer = pityArmed,
		position = UDim2.fromOffset(10, if compact then 27 else 31),
		size = UDim2.new(1, -20, 0, if compact then 6 else 7),
	}))), React.createElement("frame", {
		Name = "WheelSpinClaimActions",
		Size = UDim2.new(1, -edge * 2, 0, buttonHeight),
		Position = UDim2.new(0, edge, 1, -(buttonHeight + buttonBottom)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ref = spinClaimHostRef,
	}, React.createElement(Button, {
		text = if controller.spinning then "Spinning..." elseif controller.retry then "Confirm previous spin"
			elseif canSpin then (if pityArmed then "Spin · guaranteed rarity" else "Spin prize wheel") else "Next spin not ready",
		icon = "Wheel",
		onClick = onSpin,
		color = if canSpin and not controller.spinning then Palette.mango else Palette.panelSoft,
		textColor = if canSpin and not controller.spinning then Palette.ink else Palette.muted,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = controller.spinning or not canSpin,
		highlight = canSpin and not controller.spinning,
	})))
end
local PRIZE_ROW_H = 84
local function PrizeCatalogRow(_param)
	local reward = _param.reward
	local weightTotal = _param.weightTotal
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	local chance = if weightTotal > 0 then (reward.Weight / weightTotal) * 100 else 0
	local iconKind = if reward.Reward then _Icon.rewardIconKind(reward.Reward) else "Wheel"
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, PRIZE_ROW_H - 6),
		accent = reward.Color,
		background = Palette.panel,
		padding = 10,
		reducedMotion = softMotion,
		clips = false,
	}, React.createElement(IconTile, {
		kind = iconKind,
		accent = reward.Color,
		size = 40,
		radius = 10,
		glow = reward.Rarity == "Legendary" or reward.Rarity == "Exotic",
		filled = true,
		reducedMotion = softMotion,
	}), React.createElement(Text, {
		value = `{_param.index}. {reward.Name or reward.Id}`,
		size = 14,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		wrap = true,
		position = UDim2.fromOffset(50, 0),
		sizeConstraint = UDim2.new(1, -160, 0, 38),
	}), React.createElement(Text, {
		value = `{reward.Rarity} · {string.format("%.1f", chance)}%`,
		size = 11,
		color = reward.Color,
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(50, 42),
		sizeConstraint = UDim2.new(1, -160, 0, 18),
	}), React.createElement(Badge, {
		value = reward.ShortLabel or formatReward(reward.Reward),
		accent = reward.Color,
		filled = true,
		position = UDim2.new(1, -100, 0, 6),
		size = UDim2.fromOffset(100, 24),
	}))
end
local function WheelView(props)
	local _binding = props
	local state = _binding.state
	local config = _binding.config
	local reducedMotion = _binding.reducedMotion
	local viewport = useViewport()
	local pageWidth, setPageWidth = React.useState(nil)
	local availableWidth = pageWidth or math.max(100, viewport.width - 280)
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local spinClaimHostRef = React.useRef(nil)
	local controller = useWheelController(props)
	React.useEffect(function()
		if state.Wheel.CanSpin ~= true or controller.spinning or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = spinClaimHostRef.current
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
	end, { state.Wheel.CanSpin, controller.spinning })
	local rewards = config.Wheel.Rewards
	local landscape = chrome.landscape or (viewport.width > viewport.height * 1.35 and viewport.height < 680)
	local shortLandscape = landscape and viewport.width >= 480 and viewport.width < 900 and viewport.height <= 430
	local split = not chrome.contentStack and availableWidth >= 760
	local narrowPortrait = not landscape and viewport.width <= 360
	local widthCap = if split then availableWidth * 0.48 - Layout.cardPadding * 2 - 24 else availableWidth - Layout.cardPadding * 2 - 24
	local heightCap = if shortLandscape then 240 elseif split then 420 else 360
	local wheelDiameter = math.floor(if shortLandscape then math.clamp(math.min(widthCap, heightCap), 190, 220) else math.clamp(math.min(widthCap, heightCap), if chrome.contentStack then 140 else 180, if split then 410 else 340))
	wheelDiameter = math.max(100, math.min(wheelDiameter, widthCap))
	local headerH = if shortLandscape then 74 elseif narrowPortrait then 100 else 92
	local consoleH = if shortLandscape or chrome.contentStack then 300 else 280
	local stageH = if split then math.max(wheelDiameter + 24, consoleH) else wheelDiameter + 40 + consoleH
	local panelH = headerH + stageH + Layout.cardPadding * 2
	-- The legend shares the page scroll, so the wheel no longer needs to shrink
	-- to make an artificial nested prize viewport fit above the fold.
	local headerReveal = useStagger(0, softMotion)
	local _result
	if controller.winner >= 0 then
		local _result_1 = rewards[controller.winner + 1]
		if _result_1 ~= nil then
			_result_1 = _result_1.Color
		end
		local _condition = _result_1
		if _condition == nil then
			_condition = Palette.mango
		end
		_result = _condition
	else
		_result = Palette.mango
	end
	local accent = _result
	local headline = "The prize wheel"
	local descriptor = `{#rewards} prizes · free spin every {clockText(config.Wheel.CooldownSeconds)}`
	local containedEffects = chrome.portrait or shortLandscape or viewport.width <= 420 or (landscape and viewport.height <= 480)
	local weightTotal = 0
	for _, reward in rewards do
		weightTotal += reward.Weight or 0
	end
	local recentSpins = {}
	for _, entry in (if type(state.Wheel.History) == "table" then state.Wheel.History else {}) do
		local name = entry.PrizeId
		for index, reward in rewards do
			if reward.Id == entry.PrizeId then name = `{index}. {reward.Name or reward.Id}` end
		end
		table.insert(recentSpins, `{os.date("%b %d, %H:%M", entry.At)}   {name}{if entry.Pity then "  (guaranteed)" else ""}`)
	end
	-- One page scroll owns the complete legend: no clipped nested prize viewport.
	local prizeRows = { layout = React.createElement("uilistlayout", {
		SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6),
	}) }
	for index, reward in rewards do
		prizeRows[reward.Id] = React.createElement("frame", {
			Size = UDim2.new(1, -6, 0, PRIZE_ROW_H - 6),
			BackgroundTransparency = 1, LayoutOrder = index,
		}, React.createElement(PrizeCatalogRow, {
			reward = reward, index = index, weightTotal = weightTotal, reducedMotion = softMotion,
		}))
	end
	local prizeList = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
	}, prizeRows)
	return React.createElement("frame", {
		Name = "WheelPage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		[React.Change.AbsoluteSize] = function(host)
			local scale = if workspace:GetAttribute("AstralForgeVRCanvasWidth") then 1 else Layout.chromeScale
			local width = math.floor(host.AbsoluteSize.X / scale)
			if width > 0 then setPageWidth(width) end
		end,
	}, React.createElement(PageScaffold, {
		gap = 0,
		tailPad = scrollTail(chrome.stack, chrome.bottomSafe, 40),
		scrollBarColor = accent,
		scrollBarThickness = 4,
		sections = {
			{
				id = "wheel",
				height = panelH,
				element = React.createElement(Panel, {
					size = UDim2.fromScale(1, 1),
					accent = accent,
					background = Palette.panelRaised,
					padding = Layout.cardPadding,
					reveal = headerReveal,
					reducedMotion = softMotion,
					clips = false,
				}, React.createElement(Text, {
					value = "PRIZE WHEEL",
					size = 12,
					color = Palette.mango,
					weight = Enum.FontWeight.Heavy,
					fit = false,
					sizeConstraint = UDim2.new(1, 0, 0, if shortLandscape then 14 else 16),
				}), React.createElement(Text, {
					value = headline,
					size = if shortLandscape then 16 elseif chrome.contentStack then 18 else 21,
					color = Palette.cream,
					weight = Enum.FontWeight.Heavy,
					fit = false,
					wrap = narrowPortrait,
					position = UDim2.fromOffset(0, if shortLandscape then 14 else 18),
					sizeConstraint = UDim2.new(1, 0, 0, if narrowPortrait then 36 elseif shortLandscape then 22 else 28),
				}), React.createElement(Text, {
					value = descriptor,
					size = 12,
					color = Palette.muted,
					fit = false,
					wrap = true,
					position = UDim2.fromOffset(0, if narrowPortrait then 57 elseif shortLandscape then 36 else 46),
					sizeConstraint = UDim2.new(1, 0, 0, 30),
				}), React.createElement("frame", {
					Size = UDim2.fromOffset(wheelDiameter, wheelDiameter),
					Position = if split then UDim2.new(0.25, 0, 0, headerH + stageH / 2) else UDim2.new(0.5, 0, 0, headerH),
					AnchorPoint = if split then Vector2.new(0.5, 0.5) else Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ClipsDescendants = true,
				}, React.createElement(PrizeWheelMachine, {
					rewards = rewards,
					controller = controller,
					diameter = wheelDiameter,
					canSpin = state.Wheel.CanSpin == true,
					reducedMotion = softMotion,
					containedEffects = containedEffects,
				})), React.createElement("frame", {
					Size = if split then UDim2.new(0.48, -10, 0, consoleH) else UDim2.new(1, 0, 0, consoleH),
					Position = if split then UDim2.new(0.52, 10, 0, headerH + (stageH - consoleH) / 2) else UDim2.fromOffset(0, headerH + wheelDiameter + 40),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, React.createElement(WheelConsole, {
					state = state,
					config = config,
					controller = controller,
					onSpin = controller.spin,
					height = consoleH,
						reducedMotion = softMotion,
					spinClaimHostRef = spinClaimHostRef,
					compact = shortLandscape or chrome.contentStack,
				}))),
			},
			{
				-- the last spins this player made, newest first (server keeps 10)
				id = "recent-spins",
				height = 36 + math.max(1, #recentSpins) * 24,
				element = React.createElement(Panel, {
					size = UDim2.fromScale(1, 1), accent = Palette.mango, background = Palette.panel, padding = 12, clips = false,
				}, React.createElement(Text, {
					value = "Recent spins", size = 14, color = Palette.mango, weight = Enum.FontWeight.Heavy,
					sizeConstraint = UDim2.new(1, 0, 0, 20),
				}), React.createElement(Text, {
					value = if #recentSpins == 0 then "No spins yet. Your prizes will be listed here." else table.concat(recentSpins, "\n"),
					size = 13, color = Palette.creamSoft, wrap = true, position = UDim2.fromOffset(0, 24),
					sizeConstraint = UDim2.new(1, 0, 0, math.max(1, #recentSpins) * 24),
				})),
			},
			{
				id = "prizes-label",
				height = 32,
				element = React.createElement(Text, {
					value = "Prizes · standard odds",
					size = 13,
					color = Palette.mango,
					weight = Enum.FontWeight.Heavy,
					sizeConstraint = UDim2.new(1, 0, 0, 20),
				}),
			},
			{
				id = "prizes-odds",
				height = 64,
				element = React.createElement(Text, {
					value = `Numbers match the wheel. Guaranteed spins only land {(function(r) return string.upper(string.sub(r, 1, 1)) .. string.lower(string.sub(r, 2)) end)(config.Wheel.PityRarity or "RARE")} or better.`,
					size = 12, color = Palette.creamSoft, wrap = true, fit = false,
					sizeConstraint = UDim2.new(1, 0, 1, 0),
				}),
			},
			{
				id = "prizes",
				height = PRIZE_ROW_H * #rewards + 8,
				element = prizeList,
			},
		},
	}))
end
return {
	WheelView = WheelView,
}
end

__defs["CrateRevealStage"] = function()
	return require(script.Parent.CrateRevealStage)
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

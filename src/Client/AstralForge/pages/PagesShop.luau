--!nonstrict
--[=[
	PagesShop: merged module suite.
	Members (3): ShopView, WheelView, CrateRevealStage.

	Each member keeps its original source inside its own closure (so every member
	still has its own local-register budget) and is evaluated lazily, exactly once,
	on first access.  Use `require(<this module>)("<Member>")` (or index the returned
	table with the member name) to get a member's exports.
]=]

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

-- ======================================================================
-- Module: ShopView   (merged from ShopView.luau, 1206 lines)
-- ======================================================================
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

-- ======================================================================
-- Module: WheelView   (merged from WheelView.luau, 1349 lines)
-- ======================================================================
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
local WheelPrizeViewport = _Icon.WheelPrizeViewport
local prizeShapeFromReward = _Icon.prizeShapeFromReward
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
local Meter = _ui.Meter
local Panel = _ui.Panel
local Text = _ui.Text
local IMPACT_RAYS = { 0, 60, 120, 180, 240, 300 }
local RIM_NOTCHES = { 0, 45, 90, 135, 180, 225, 270, 315 }
-- One continuous motion, so the wheel never lurches between phases: it
-- accelerates for WHEEL_LAUNCH_SECONDS, cruises at a constant speed until the
-- server answers, then brakes on a cubic ease-out that STARTS at the cruise speed
-- (initial speed = 3 * distance / duration, so duration = 3 * distance / speed).
local WHEEL_OMEGA = 1440
local WHEEL_OMEGA_LOW = 1080
local WHEEL_LAUNCH_SECONDS = 0.65
-- Cruise this long after launch even when the answer is already in, so the spin
-- reads as a spin and not a snap.
local WHEEL_MIN_CRUISE_SECONDS = 0.35
local function sampleSpin(plan, elapsed)
	local omega = plan.omega
	if elapsed < WHEEL_LAUNCH_SECONDS then
		return plan.base + omega * elapsed * elapsed / (2 * WHEEL_LAUNCH_SECONDS), omega * elapsed / WHEEL_LAUNCH_SECONDS
	end
	return plan.base + omega * WHEEL_LAUNCH_SECONDS / 2 + omega * (elapsed - WHEEL_LAUNCH_SECONDS), omega
end
local function positiveModulo(value, modulus)
	return ((value % modulus) + modulus) % modulus
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
	local phase, setPhase = React.useState("idle")
	local winner, setWinner = React.useState(-1)
	local failure, setFailure = React.useState()
	local launchNonce, setLaunchNonce = React.useState(0)
	local impactNonce, setImpactNonce = React.useState(0)
	local rotation, setRotation = React.useBinding(0)
	local pointerKick, setPointerKick = React.useBinding(0)
	local spinEnergy, setSpinEnergy = React.useBinding(0)
	local rotationValue = React.useRef(0)
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
		-- Brake from wherever the wheel is, at the speed it is doing: the cubic
		-- ease-out's opening speed is 3 * distance / duration, so choosing
		-- duration = 3 * distance / speed makes the hand-over seamless.
		local now = os.clock()
		local plan = motor.current
		local current, speed = sampleSpin(plan, now - plan.startedAt)
		local delta = positiveModulo(wanted - positiveModulo(current, 360), 360)
		local distance = (if antilag.tier <= 1 then 720 else 1080) + delta
		motor.current = {
			active = true,
			mode = "brake",
			base = current,
			omega = plan.omega,
			distance = distance,
			duration = 3 * distance / math.max(speed, 240),
			startedAt = now,
			lastSegment = math.floor(current / segment),
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
			if pointerKickValue.current > 0 then
				pointerKickValue.current = math.max(0, pointerKickValue.current - deltaTime * 11.5)
				setPointerKick(pointerKickValue.current)
			end
			local plan = motor.current
			if not plan.active then
				return nil
			end
			local now = os.clock()
			local elapsed = now - plan.startedAt
			local braking = plan.mode == "brake"
			local value, speed, progress
			if braking then
				progress = math.clamp(elapsed / plan.duration, 0, 1)
				local remaining = 1 - progress
				value = plan.base + plan.distance * (1 - remaining * remaining * remaining)
				speed = 3 * plan.distance / plan.duration * remaining * remaining
			else
				progress = 0
				value, speed = sampleSpin(plan, elapsed)
			end
			rotationValue.current = value
			setRotation(value)
			setSpinEnergy(math.clamp(speed / plan.omega, 0, 1))
			local currentSegment = math.floor(value / segment)
			if currentSegment ~= plan.lastSegment then
				plan.lastSegment = currentSegment
				pointerKickValue.current = if braking and progress > 0.66 then 1 else 0.58
				setPointerKick(pointerKickValue.current)
				-- Fast spin ticks are a blur; only the slowing wheel earns clicks.
				local interval = if braking then 0.06 + progress * 0.16 else 0.14
				if audioTicksRef.current and now - plan.lastSoundAt >= interval then
					plan.lastSoundAt = now
					Audio:play(if braking and progress > 0.65 then "wheelSlow" else "wheelTick", 0.92 + (1 - progress) * 0.16)
				end
			end
			if not braking then
				local result = pendingResult.current
				if result ~= nil and elapsed >= WHEEL_LAUNCH_SECONDS + WHEEL_MIN_CRUISE_SECONDS then
					beginBrakeRef.current(result)
				end
				return nil
			end
			if progress >= 1 then
				plan.active = false
				completeLanding(plan.result, plan.base + plan.distance)
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
	local spin = function()
		if busy.current or not state.Wheel.CanSpin then
			return nil
		end
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
				lastSegment = math.floor(rotationValue.current / segment),
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
			setFailure("That spin took too long. Check Rewards before trying again.")
			Audio:play("requestTimeout")
		end)
		dispatch("SpinWheel", {}, function(response)
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
				local _condition = response.error
				if _condition == nil then
					_condition = "The draw could not be completed."
				end
				setFailure(_condition)
				Audio:play("error")
				return nil
			end
			local result = {
				index = math.clamp(math.floor(response.PrizeIndex) - 1, 0, rewardCount - 1),
				message = response.message,
			}
			pendingResult.current = result
			-- Reduced motion has no frame loop to pick the result up.
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
		launchNonce = launchNonce,
		impactNonce = impactNonce,
		rotation = rotation,
		pointerKick = pointerKick,
		spinEnergy = spinEnergy,
		spin = spin,
	}
end
local function WheelBurst(_param)
	local flash = _param.flash
	local active = _param.active
	local accent = _param.accent
	local budget = _param.budget
	local launch = _param.launch
	if launch == nil then
		launch = false
	end
	local contained = _param.contained
	if contained == nil then
		contained = false
	end
	if not active then
		return React.createElement(React.Fragment)
	end
	local ringCount = if launch then (if budget >= 0.55 then 2 else 1) elseif budget >= 0.3 then 2 else 1
	local rings = {}
	for index = 0, ringCount - 1 do
		local _index = index
		table.insert(rings, _index)
	end
	local overscan = if contained then 0 else 80
	local _exp = not launch and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.cream,
		BackgroundTransparency = flash:map(function(amount)
			return 1 - amount * (0.035 + budget * 0.025)
		end),
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#rings)
	local _callback = function(ring)
		return React.createElement("frame", {
			key = `ring-{ring}`,
			Size = flash:map(function(amount)
				local decay = 1 - amount
				local freeScale = 0.64 + ring * 0.14 + decay * (0.48 + ring * 0.14)
				local scale = if contained then math.min(0.96, 0.54 + ring * 0.08 + decay * (0.3 + ring * 0.05)) else freeScale
				return UDim2.fromScale(scale, scale)
			end),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Rotation = ring * 17,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uistroke", {
			Color = if ring == 1 then Palette.cream else accent,
			Thickness = if ring == 0 then 2.2 else 1.25,
			Transparency = flash:map(function(amount)
				return 1 - amount * (0.58 - ring * 0.1)
			end),
		}))
	end
	for _k, _v in rings do
		_newValue[_k] = _callback(_v, _k - 1, rings)
	end
	-- ▲ ReadonlyArray.map ▲
	local _condition = not launch and budget >= 0.62
	if _condition then
		-- ▼ ReadonlyArray.map ▼
		local _newValue_1 = table.create(#IMPACT_RAYS)
		local _callback_1 = function(angle, index)
			return React.createElement("frame", {
				key = `ray-{angle}`,
				Size = flash:map(function(amount)
					return UDim2.new(0, ((if contained then 38 else 50) + index % 3 * (if contained then 10 else 16)) * (1 - amount), 0, 2)
				end),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				Rotation = angle + 5,
				BackgroundColor3 = if index % 3 == 0 then Palette.cream elseif index % 2 == 0 then accent else Palette.cyan,
				BackgroundTransparency = flash:map(function(amount)
					return 1 - amount * 0.48
				end),
				BorderSizePixel = 0,
			}, React.createElement("uigradient", {
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.08), NumberSequenceKeypoint.new(1, 1) }),
			}))
		end
		for _k, _v in IMPACT_RAYS do
			_newValue_1[_k] = _callback_1(_v, _k - 1, IMPACT_RAYS)
		end
		-- ▲ ReadonlyArray.map ▲
		_condition = _newValue_1
	end
	return React.createElement("frame", {
		Size = UDim2.new(1, overscan, 1, overscan),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 70,
	}, _exp, _newValue, _condition)
end
local function PrizeWheelMachine(_param)
	local rewards = _param.rewards
	local controller = _param.controller
	local diameter = _param.diameter
	local canSpin = _param.canSpin
	local reducedMotion = _param.reducedMotion
	local containedEffects = _param.containedEffects
	if containedEffects == nil then
		containedEffects = false
	end
	local antilag = useAntilag()
	-- Decorative springs soft-gate under low antilag; spin gameplay keeps reducedMotion only.
	local softMotion = reducedMotion
	local count = math.max(1, #rewards)
	local segment = 360 / count
	local innerDiameter = math.floor(diameter * 0.84)
	local compactMachine = diameter < 230
	local roughRadius = innerDiameter / 2 - 24
	local span = (2 * math.pi * math.max(48, roughRadius)) / count
	local medallionSize = math.floor(math.clamp(math.min(diameter * 0.11, span * 0.56), 22, 40))
	local hubSize = math.floor(math.clamp(diameter * 0.2, if compactMachine then 52 else 60, 84))
	local orbitRadius = innerDiameter / 2 - medallionSize / 2 - 10
	local landing = useFlash(controller.impactNonce, reducedMotion, if antilag.tier < 1 then 0.34 else 0.56)
	local launch = useFlash(controller.launchNonce, reducedMotion, 0.58)
	local decorateOrbit = true
	local hubStroke = useGlowStroke(canSpin and not controller.spinning and decorateOrbit, reducedMotion or not decorateOrbit, 0.58, 0.12, 0.7, 1.8)
	local idleOrbit = useRotation(not reducedMotion and not controller.spinning and canSpin and decorateOrbit, 5.5)
	local reverseOrbit = idleOrbit:map(function(angle)
		return -angle * 0.62
	end)
	local carrierScale = React.joinBindings({
		landing = landing,
		launch = launch,
		energy = controller.spinEnergy,
	}):map(function(_param_1)
		local hit = _param_1.landing
		local start = _param_1.launch
		local energy = _param_1.energy
		return 1 + hit * (0.045 + antilag.fxBudget * 0.025) - start * 0.025 + energy * 0.012
	end)
	local carrierPosition = React.joinBindings({
		landing = landing,
		energy = controller.spinEnergy,
	}):map(function(_param_1)
		local hit = _param_1.landing
		local energy = _param_1.energy
		return UDim2.new(0.5, 0, 0.5, -math.round(energy * 2) + math.round(math.sin((1 - hit) * math.pi * 3) * hit * 3))
	end)
	local pointerScale = React.joinBindings({
		tick = controller.pointerKick,
		landing = landing,
	}):map(function(_param_1)
		local tick = _param_1.tick
		local hit = _param_1.landing
		return 1 + tick * 0.16 + hit * 0.22
	end)
	local pointerY = React.joinBindings({
		tick = controller.pointerKick,
		landing = landing,
	}):map(function(_param_1)
		local tick = _param_1.tick
		local hit = _param_1.landing
		return UDim2.new(0.5, 0, 0, 10 - tick * 3 - hit * 3)
	end)
	local wheelGlow = controller.spinEnergy:map(function(energy)
		return 0.95 - energy * 0.16 * antilag.glowScale
	end)
	local _exp = React.createElement(WheelBurst, {
		flash = launch,
		active = controller.launchNonce > 0 and not reducedMotion,
		accent = Palette.mango,
		budget = antilag.fxBudget,
		launch = true,
		contained = containedEffects,
	})
	local _attributes = {
		flash = landing,
		active = controller.impactNonce > 0 and not reducedMotion,
	}
	local _result = rewards[controller.winner + 1]
	if _result ~= nil then
		_result = _result.Color
	end
	local _condition = _result
	if _condition == nil then
		_condition = Palette.mango
	end
	_attributes.accent = _condition
	_attributes.budget = antilag.fxBudget
	_attributes.contained = containedEffects
	local _exp_1 = React.createElement(WheelBurst, _attributes)
	local _exp_2 = React.createElement("uiscale", {
		Scale = carrierScale,
	})
	local _exp_3 = React.createElement("frame", {
		Size = UDim2.new(1, -16, 1, -16),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = idleOrbit,
		BackgroundColor3 = Palette.mango,
		BackgroundTransparency = wheelGlow,
		BorderSizePixel = 0,
		ZIndex = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(Palette.cyan, Palette.mango),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.08), NumberSequenceKeypoint.new(0.5, 0.9), NumberSequenceKeypoint.new(1, 0.08) }),
	}))
	local _exp_4 = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panelRaised, 0.72),
		Rotation = 90,
	}), React.createElement("uistroke", {
		Color = Palette.lineSoft,
		Thickness = 2,
		Transparency = 0.2,
	}))
	local _exp_5 = React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})
	local _exp_6 = React.createElement("uistroke", {
		Color = Palette.mango,
		Thickness = 2,
		Transparency = 0.46,
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#RIM_NOTCHES)
	local _callback = function(angle)
		return React.createElement("frame", {
			key = `rim-{angle}`,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = angle,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement("frame", {
			Size = UDim2.fromOffset(if angle % 90 == 0 then 20 else 12, 4),
			Position = UDim2.new(0.5, 0, 0, -2),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = if angle % 90 == 0 then Palette.mango else Palette.creamSoft,
			BackgroundTransparency = 0.16,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		})))
	end
	for _k, _v in RIM_NOTCHES do
		_newValue[_k] = _callback(_v, _k - 1, RIM_NOTCHES)
	end
	-- ▲ ReadonlyArray.map ▲
	local _exp_7 = React.createElement("frame", {
		Size = UDim2.new(1, -14, 1, -14),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Rotation = reverseOrbit,
		ZIndex = 2,
	}, _exp_5, _exp_6, _newValue)
	local _exp_8 = React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})
	local _exp_9 = React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(Palette.panel, 0.04), darken(Palette.ink, 0.22)),
		Rotation = 90,
	})
	local _exp_10 = React.createElement("uistroke", {
		Color = Palette.creamSoft,
		Thickness = 1,
		Transparency = 0.62,
	})
	local _exp_11 = React.createElement("frame", {
		Size = UDim2.fromScale(0.66, 0.66),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.66,
	}))
	-- ▼ ReadonlyArray.map ▼
	local _newValue_1 = table.create(#rewards)
	local _callback_1 = function(reward, index)
		return React.createElement("frame", {
			key = `divider-{reward.Id}`,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = index * segment - segment / 2,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement("frame", {
			Size = UDim2.fromOffset(2, orbitRadius - hubSize * 0.22),
			Position = UDim2.new(0.5, 0, 0.5, -(orbitRadius - hubSize * 0.22) / 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = reward.Color,
			BackgroundTransparency = 0.58,
			BorderSizePixel = 0,
		}, React.createElement("uigradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) }),
		})))
	end
	for _k, _v in rewards do
		_newValue_1[_k] = _callback_1(_v, _k - 1, rewards)
	end
	-- ▲ ReadonlyArray.map ▲
	-- ▼ ReadonlyArray.map ▼
	local _newValue_2 = table.create(#rewards)
	local _callback_2 = function(reward, index)
		local won = controller.winner == index
		local counterRotation = controller.rotation:map(function(turn)
			return -(turn + index * segment)
		end)
		return React.createElement("frame", {
			key = reward.Id,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = index * segment,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, React.createElement("frame", {
			Size = UDim2.new(0, medallionSize + 16, 0, 5),
			Position = UDim2.new(0.5, 0, 0.5, -orbitRadius - 4),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = reward.Color,
			BackgroundTransparency = if won then 0.02 else 0.26,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uigradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.24, 0), NumberSequenceKeypoint.new(0.76, 0), NumberSequenceKeypoint.new(1, 1) }),
		})), React.createElement("frame", {
			Size = UDim2.fromOffset(medallionSize, medallionSize),
			Position = UDim2.new(0.5, 0, 0.5, -orbitRadius),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = counterRotation,
			BackgroundColor3 = darken(reward.Color, 0.72):Lerp(Palette.panelRaised, 0.42),
			BorderSizePixel = 0,
			ClipsDescendants = false,
		}, won and React.createElement("uiscale", {
			Scale = landing:map(function(amount)
				return 1 + amount * 0.18
			end),
		}), React.createElement("uicorner", {
			CornerRadius = UDim.new(0, math.floor(medallionSize * 0.28)),
		}), React.createElement("uigradient", {
			Color = ColorSequence.new(lighten(Palette.panelRaised, 0.08), darken(Palette.panelRaised, 0.22)),
			Rotation = 90,
		}), React.createElement("uistroke", {
			Color = if won then Palette.cream else reward.Color,
			Thickness = if won then 2.5 else 1.25,
			Transparency = if won then 0.02 else 0.18,
		}), React.createElement("frame", {
			Size = UDim2.new(1, -8, 1, -8),
			Position = UDim2.fromOffset(4, 4),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement(WheelPrizeViewport, {
			color = reward.Color,
			shape = prizeShapeFromReward(reward.Reward, reward.Rarity),
			size = medallionSize - 8,
			spin = won and not reducedMotion,
		}))))
	end
	for _k, _v in rewards do
		_newValue_2[_k] = _callback_2(_v, _k - 1, rewards)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = UDim2.fromOffset(diameter, diameter),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, _exp, _exp_1, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = carrierPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, _exp_2, _exp_3, _exp_4, _exp_7, React.createElement("frame", {
		Size = UDim2.fromOffset(innerDiameter, innerDiameter),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = controller.rotation,
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 3,
	}, _exp_8, _exp_9, _exp_10, _exp_11, _newValue_1, _newValue_2), React.createElement("frame", {
		Size = UDim2.fromOffset(hubSize + 16, hubSize + 16),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.shadow,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.mango,
		Thickness = 2,
		Transparency = 0.5,
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(hubSize, hubSize),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ZIndex = 7,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panelRaised, 0.75),
		Rotation = 90,
	}), React.createElement("uistroke", {
		Color = Palette.mango,
		Thickness = 3,
		Transparency = hubStroke,
	}), React.createElement(Icon, {
		kind = "Wheel",
		color = Palette.cream,
		accent = Palette.mango,
		size = math.floor(hubSize * 0.58),
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		spin = controller.spinning,
		clipSafe = true,
		reducedMotion = reducedMotion,
	}))), React.createElement("frame", {
		Size = UDim2.fromOffset(38, 42),
		Position = pointerY,
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 90,
		ClipsDescendants = false,
	}, React.createElement("uiscale", {
		Scale = pointerScale,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(28, 18),
		Position = UDim2.fromOffset(19, 2),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 7),
	}), React.createElement("uistroke", {
		Color = Palette.creamSoft,
		Thickness = 1,
		Transparency = 0.28,
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.fromOffset(19, 18),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = 45,
		BackgroundColor3 = Palette.mango,
		BorderSizePixel = 0,
		ZIndex = 91,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 5),
	}), React.createElement("uistroke", {
		Color = Palette.cream,
		Thickness = 2,
		Transparency = 0.08,
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(7, 7),
		Position = UDim2.fromOffset(19, 18),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		ZIndex = 92,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))))
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
	local canSpin = state.Wheel.CanSpin == true
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
		_result = "Connection interrupted"
	else
		local _result_1 = prize
		if _result_1 ~= nil then
			_result_1 = _result_1.Name
		end
		local _condition_2 = _result_1
		if _condition_2 == nil then
			_condition_2 = (if controller.spinning then "Forging your outcome" elseif canSpin then "Your daily draw is ready" else "The wheel is recharging")
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
				_result_2 = (if compact then "Your prize is coming up." else "The wheel is slowing down. Watch the pointer.")
			else
				local _result_3
				if canSpin then
					local _condition_3 = state.Wheel.FreeSpins
					if _condition_3 == nil then
						_condition_3 = 0
					end
					_result_3 = (if _condition_3 > 0 then `{compactNumber(state.Wheel.FreeSpins)} free spin{if state.Wheel.FreeSpins == 1 then "" else "s"} ready.` elseif pityArmed then ((config.ClientPageGuides and config.ClientPageGuides.Wheel and config.ClientPageGuides.Wheel.PityArmed) or "Pity is armed — the next spin is weighted toward a better prize.") elseif compact then "Tap once to spin." else ((config.ClientPageGuides and config.ClientPageGuides.Wheel and config.ClientPageGuides.Wheel.Ready) or "Give it a spin and see what lands."))
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
	local statsTop = if compact then 92 else 106
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
	}, React.createElement(WheelPrizeViewport, {
		color = prize.Color,
		shape = prizeShapeFromReward(prize.Reward, prize.Rarity),
		size = prizeIcon,
		spin = false,
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
	_attributes.fit = true
	_attributes.minSize = if compact then 9 else 11
	_attributes.position = UDim2.fromOffset(copyX, if compact then 38 else 44)
	_attributes.sizeConstraint = UDim2.new(1, -copyRight, 0, if compact then 20 else 24)
	local _exp_6 = React.createElement(Text, _attributes)
	local _exp_7 = React.createElement(Text, {
		value = detail,
		size = if compact then 9 else 11,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(copyX, if compact then 59 else 69),
		sizeConstraint = UDim2.new(1, -copyRight, 0, if compact then 28 else 36),
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
	_attributes_1.value = if _condition_3 > 0 then "FREE DRAWS" else "TOTAL DRAWS"
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
		value = if compact then "RARITY" else "RARITY PRESSURE",
		size = 12,
		color = if pityArmed then Palette.mango else Palette.muted,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(10, 5),
		sizeConstraint = UDim2.new(0.65, -10, 0, 15),
	}), React.createElement(Text, {
		value = if pityArmed then "PRIMED" else `{pityMisses} / {pityAfter}`,
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
		text = if controller.spinning then "SPINNING" elseif canSpin then (if pityArmed then (if compact then "SPIN · PITY" else "SPIN · PITY ARMED") elseif compact then "SPIN WHEEL" else "SPIN PRIZE WHEEL") else "DRAW NOT READY",
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
local PRIZE_ROW_H = 56
local function PrizeCatalogRow(_param)
	local reward = _param.reward
	local weightTotal = _param.weightTotal
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	local chance = if weightTotal > 0 then (reward.Weight / weightTotal) * 100 else 0
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, PRIZE_ROW_H - 6),
		accent = reward.Color,
		background = Palette.panel,
		padding = 10,
		reducedMotion = reducedMotion,
		clips = false,
	}, React.createElement(Text, {
		value = reward.Name or reward.Id,
		size = 14,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		sizeConstraint = UDim2.new(1, -110, 0, 20),
	}), React.createElement(Text, {
		value = `{reward.Rarity} · {string.format("%.1f", chance)}%`,
		size = 11,
		color = reward.Color,
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(0, 22),
		sizeConstraint = UDim2.new(1, -110, 0, 16),
	}), React.createElement(Badge, {
		value = reward.ShortLabel or formatReward(reward.Reward),
		accent = reward.Color,
		filled = true,
		position = UDim2.new(1, -100, 0.5, -12),
		size = UDim2.fromOffset(100, 24),
	}))
end
local function WheelView(props)
	local _binding = props
	local state = _binding.state
	local config = _binding.config
	local reducedMotion = _binding.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local spinClaimHostRef = React.useRef(nil)
	local controller = useWheelController(props)
	-- Gamepad: park Selection on SPIN CTA.
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
	local split = shortLandscape or (not chrome.contentStack and viewport.width >= 720)
	local narrowPortrait = not landscape and viewport.width <= 360
	local widthCap = if shortLandscape then viewport.width * 0.4 - 18 elseif split then viewport.width * (if landscape then 0.43 else 0.48) - 54 else viewport.width - 58
	local heightCap = if shortLandscape then viewport.height - 105 elseif landscape then viewport.height - 250 elseif split then viewport.height - 390 else viewport.height - 300
	local wheelDiameter = math.floor(if shortLandscape then math.clamp(math.min(widthCap, heightCap), 190, 220) else math.clamp(math.min(widthCap, heightCap), if chrome.contentStack then 226 else 264, if split then 410 else 340))
	local headerH = if shortLandscape then 52 elseif narrowPortrait then 78 elseif chrome.contentStack then 66 else 60
	local consoleH = if shortLandscape then 198 elseif chrome.contentStack then 230 else 232
	local stageH = if split then math.max(wheelDiameter, consoleH) else wheelDiameter + 16 + consoleH
	local panelH = headerH + stageH + Layout.cardPadding * 2
	local tablePeek = 28 + 140
	local pageBudget = math.max(420, viewport.height - 110)
	if panelH + tablePeek > pageBudget then
		local shrink = panelH + tablePeek - pageBudget
		wheelDiameter = math.max(200, wheelDiameter - shrink)
		stageH = if split then math.max(wheelDiameter, consoleH) else wheelDiameter + 16 + consoleH
		panelH = headerH + stageH + Layout.cardPadding * 2
	end
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
	local headline = if narrowPortrait then "Spin it. Win something." else "Your next prize is one spin away."
	local descriptor = if narrowPortrait then `{#rewards} prizes / rare-win protection` else `{#rewards} prizes  /  better odds after every miss`
	local containedEffects = chrome.portrait or shortLandscape or viewport.width <= 420 or (landscape and viewport.height <= 480)
	local weightTotal = 0
	for _, reward in rewards do
		weightTotal += reward.Weight or 0
	end
	local prizeList = React.createElement(FlatList, {
		data = rewards,
		itemHeight = PRIZE_ROW_H,
		overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
		canvasTail = 8,
		Size = UDim2.fromScale(1, 1),
		scrollBarColor = accent,
		scrollBarThickness = 3,
		keyExtractor = function(reward)
			return reward.Id
		end,
		renderItem = function(_param_1)
			return React.createElement(PrizeCatalogRow, {
				reward = _param_1.item,
				weightTotal = weightTotal,
				reducedMotion = softMotion,
			})
		end,
	})
	return React.createElement(PageScaffold, {
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
					size = if shortLandscape then 9 else 10,
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
					minSize = if narrowPortrait then 10 else 15,
					wrap = narrowPortrait,
					position = UDim2.fromOffset(0, if shortLandscape then 14 else 18),
					sizeConstraint = UDim2.new(1, 0, 0, if narrowPortrait then 36 elseif shortLandscape then 22 else 28),
				}), React.createElement(Text, {
					value = descriptor,
					size = if narrowPortrait then 9 else 10,
					color = Palette.muted,
					fit = false,
					wrap = narrowPortrait,
					position = UDim2.fromOffset(0, if narrowPortrait then 57 elseif shortLandscape then 36 else 46),
					sizeConstraint = UDim2.new(1, 0, 0, if narrowPortrait then 18 else 16),
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
					Position = if split then UDim2.new(0.52, 10, 0, headerH + (stageH - consoleH) / 2) else UDim2.fromOffset(0, headerH + wheelDiameter + 16),
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
					compact = shortLandscape,
				}))),
			},
			{
				id = "prizes-label",
				height = 28,
				element = React.createElement(Text, {
					value = "PRIZE TABLE",
					size = 11,
					color = Palette.mango,
					weight = Enum.FontWeight.Heavy,
					sizeConstraint = UDim2.new(1, 0, 0, 20),
				}),
			},
			{
				id = "prizes",
				fill = true,
				minHeight = math.max(140, PRIZE_ROW_H * 3),
				element = prizeList,
			},
		},
	})
end
return {
	WheelView = WheelView,
}
end

-- ======================================================================
-- Module: CrateRevealStage   (merged from CrateRevealStage.luau, 1254 lines)
-- ======================================================================
__defs["CrateRevealStage"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local itemIconKind = require(script.Parent.Parent.ArtKit)("Icon").itemIconKind
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local ScaleFromCenter = require(script.Parent.Parent.MotionKit)("motion").ScaleFromCenter
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local darken = _theme.darken
local lighten = _theme.lighten
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local IconTile = _ui.IconTile
local Panel = _ui.Panel
local Text = _ui.Text

local RunService = game:GetService("RunService")

-- ─── easing helpers ────────────────────────────────────────────────────────────
local function easeOutExpo(t)
	return t == 1 and 1 or 1 - math.pow(2, -10 * t)
end
local function easeOutBack(t)
	local c1, c3 = 1.70158, 1.70158 + 1
	return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
end

-- shimmer clock shared across cards (increments each frame, wraps at 1)
local shimmerClock = React.createContext(0)

local function useShimmerClock()
	return React.useContext(shimmerClock)
end

-- ShimmerProvider: one RunService loop feeds all card shimmer animations
local function ShimmerProvider(props)
	local clock, setClock = React.useBinding(0)
	React.useEffect(function()
		local conn = RunService.RenderStepped:Connect(function(dt)
			setClock((clock:getValue() + dt * 0.72) % 1)
		end)
		return function() conn:Disconnect() end
	end, {})
	return React.createElement(shimmerClock.Provider, { value = clock }, props.children)
end

-- ─── Layout resolver (unchanged logic, same API) ────────────────────────────────
local function resolveLayout(props)
	local edge = if props.portrait then 10 else 18
	local leftEdge = edge + props.sideSafe
	local rightEdge = edge + props.sideSafe
	local usableWidth = math.max(1, props.viewportWidth - leftEdge - rightEdge)
	if props.shortLandscape then
		local columnGap = 12
		local availableRight = math.max(1, usableWidth - columnGap - 1)
		local rightWidth = math.min(availableRight, math.min(218, math.max(132, math.floor(usableWidth * 0.36))))
		local leftWidth = math.max(1, usableWidth - columnGap - rightWidth)
		local headerTop = props.topInset + 5
		local headerHeight = 52
		local stageTop = headerTop + headerHeight + 8
		local stageBottom = props.viewportHeight - props.bottomSafe - 8
		local stageHeight = math.max(1, math.min(202, stageBottom - stageTop))
		return {
			compactHeight = false,
			headerSize = UDim2.fromOffset(leftWidth, headerHeight),
			headerPosition = UDim2.fromOffset(leftEdge, headerTop),
			headerAnchor = Vector2.zero,
			stageSize = UDim2.fromOffset(leftWidth, stageHeight),
			stagePosition = UDim2.fromOffset(leftEdge, stageTop),
			stageAnchor = Vector2.zero,
			reelWidth = math.max(1, leftWidth - 24),
			reelHeight = math.max(1, stageHeight - 58),
			resultSize = UDim2.fromOffset(rightWidth, 126),
			resultPosition = UDim2.new(1, -rightEdge, 0, props.topInset + 12),
			resultAnchor = Vector2.new(1, 0),
			actionSize = UDim2.fromOffset(rightWidth, TapTarget),
			actionPosition = UDim2.new(1, -rightEdge, 1, -(props.bottomSafe + 8)),
			actionAnchor = Vector2.new(1, 1),
		}
	end
	if props.viewportHeight < 540 then
		local stageWidth = math.min(usableWidth, 390)
		local headerTop = props.topInset + 4
		local headerHeight = 44
		local actionBottom = props.bottomSafe + 8
		local actionTop = props.viewportHeight - actionBottom - TapTarget
		local stageTop = headerTop + headerHeight + 6
		local stageBottom = math.max(stageTop + 1, actionTop - 8)
		local stageHeight = stageBottom - stageTop
		local resultHeight = math.max(1, math.min(100, stageHeight - 12))
		return {
			compactHeight = true,
			headerSize = UDim2.fromOffset(stageWidth, headerHeight),
			headerPosition = UDim2.new(0.5, 0, 0, headerTop),
			headerAnchor = Vector2.new(0.5, 0),
			stageSize = UDim2.fromOffset(stageWidth, stageHeight),
			stagePosition = UDim2.new(0.5, 0, 0, stageTop),
			stageAnchor = Vector2.new(0.5, 0),
			reelWidth = math.max(1, stageWidth - 24),
			reelHeight = math.max(1, stageHeight - 58),
			resultSize = UDim2.fromOffset(math.max(1, stageWidth - 24), resultHeight),
			resultPosition = UDim2.fromOffset(math.floor(props.viewportWidth / 2), math.floor(stageTop + stageHeight / 2)),
			resultAnchor = Vector2.new(0.5, 0.5),
			actionSize = UDim2.fromOffset(stageWidth, TapTarget),
			actionPosition = UDim2.new(0.5, 0, 1, -actionBottom),
			actionAnchor = Vector2.new(0.5, 1),
		}
	end
	local stageWidth = math.min(usableWidth, if props.portrait then 390 else 850)
	local stageHeight = if props.portrait then math.clamp(math.floor(props.viewportHeight * 0.37), 204, 232) else math.clamp(math.floor(props.viewportHeight * 0.38), 232, 286)
	local headerHeight = if props.portrait then 74 else 82
	local resultHeight = if props.portrait then 88 else 94
	local resultWidth = math.min(if props.portrait then stageWidth else 470, usableWidth)
	local actionWidth = math.min(if props.portrait then stageWidth else 260, usableWidth)
	local actionBottom = props.bottomSafe + 10
	local resultBottom = actionBottom + TapTarget + 10
	local freeTop = props.topInset + headerHeight + 16
	local freeBottom = props.viewportHeight - resultBottom - resultHeight - 10
	local stageCenter = math.floor((freeTop + freeBottom) * 0.5)
	return {
		compactHeight = false,
		headerSize = UDim2.fromOffset(math.min(stageWidth, 620), headerHeight),
		headerPosition = UDim2.new(0.5, 0, 0, props.topInset + 8),
		headerAnchor = Vector2.new(0.5, 0),
		stageSize = UDim2.fromOffset(stageWidth, stageHeight),
		stagePosition = UDim2.fromOffset(math.floor(props.viewportWidth / 2), stageCenter),
		stageAnchor = Vector2.new(0.5, 0.5),
		reelWidth = math.max(1, stageWidth - 24),
		reelHeight = stageHeight - 58,
		resultSize = UDim2.fromOffset(resultWidth, resultHeight),
		resultPosition = UDim2.new(0.5, 0, 1, -resultBottom),
		resultAnchor = Vector2.new(0.5, 1),
		actionSize = UDim2.fromOffset(actionWidth, TapTarget),
		actionPosition = UDim2.new(0.5, 0, 1, -actionBottom),
		actionAnchor = Vector2.new(0.5, 1),
	}
end

-- ─── ForgeBackdrop ─────────────────────────────────────────────────────────────
local function ForgeBackdrop(_param)
	local props = _param.props
	local layout = _param.layout
	local contained = props.shortLandscape or layout.compactHeight or props.viewportHeight < 600
	local burstBase = if contained then 110 else 180
	local burstTravel = if contained then math.min(160, layout.reelWidth * 0.42) else 420
	local center = UDim2.new(
		layout.stagePosition.X.Scale, layout.stagePosition.X.Offset + (0.5 - layout.stageAnchor.X) * layout.stageSize.X.Offset,
		layout.stagePosition.Y.Scale, layout.stagePosition.Y.Offset + (0.5 - layout.stageAnchor.Y) * layout.stageSize.Y.Offset
	)

	-- rotating energy ring (spins during "spin" phase, holds at land)
	local ringRotation, setRingRotation = React.useBinding(0)
	local ringConn = React.useRef(nil)
	React.useEffect(function()
		local conn = RunService.RenderStepped:Connect(function(dt)
			local speed = if props.phase == "spin" then 38 else 12
			setRingRotation((ringRotation:getValue() + dt * speed) % 360)
		end)
		ringConn.current = conn
		return function() conn:Disconnect() end
	end, { props.phase })

	local gridLines = {}
	if props.allowAmbient then
		-- horizontal grid lines
		for index = 0, 4 do
			gridLines[`h{index}`] = React.createElement("frame", {
				key = `forge-grid-h-{index}`,
				Size = UDim2.new(0.68, 0, 0, 1),
				Position = UDim2.new(0.5, 0, 0.28 + index * 0.1, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = props.sessionAccent,
				BackgroundTransparency = 0.94,
				BorderSizePixel = 0,
			})
		end
		-- vertical grid lines
		for index = 0, 6 do
			gridLines[`v{index}`] = React.createElement("frame", {
				key = `forge-grid-v-{index}`,
				Size = UDim2.new(0, 1, 0.54, 0),
				Position = UDim2.new(0.26 + index * 0.08, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = props.sessionAccent,
				BackgroundTransparency = 0.96,
				BorderSizePixel = 0,
			})
		end
	end

	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 405,
		Active = false,
	},
		-- top divider line
		React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.fromScale(0, 0.18),
			BackgroundColor3 = Palette.line,
			BackgroundTransparency = 0.78,
			BorderSizePixel = 0,
		}),
		-- bottom divider line
		React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.fromScale(0, 0.82),
			BackgroundColor3 = Palette.line,
			BackgroundTransparency = 0.84,
			BorderSizePixel = 0,
		}),
		-- ambient grid
		props.allowAmbient and React.createElement(React.Fragment, nil, table.unpack(
			(function()
				local items = {}
				for _, v in gridLines do table.insert(items, v) end
				return items
			end)()
		)),
		-- rotating accent energy ring
		props.allowAmbient and React.createElement("frame", {
			Size = props.landFlash:map(function(f)
				local base = if contained then 72 else 130
				return UDim2.fromOffset(base + f * 60, base + f * 60)
			end),
			Position = center,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 406,
			Rotation = ringRotation,
		}, React.createElement("uistroke", {
			Color = props.sessionAccent,
			Thickness = 1.5,
			Transparency = props.spinEnergy:map(function(e)
				return 1 - e * 0.55 * props.glowScale
			end),
		}), React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 6),
		})),
		-- burst diamond
		React.createElement("frame", {
			Size = props.landFlash:map(function(amount)
				return UDim2.fromOffset(burstBase + amount * burstTravel, burstBase + amount * burstTravel)
			end),
			Position = center,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = props.sessionAccent,
			BackgroundTransparency = props.landFlash:map(function(amount)
				return 1 - amount * (if contained then 0.045 else 0.08)
			end),
			BorderSizePixel = 0,
			Rotation = 45,
			ZIndex = 406,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uistroke", {
			Color = lighten(props.sessionAccent, 0.32),
			Thickness = 2,
			Transparency = props.landFlash:map(function(amount)
				return 1 - amount * (if contained then 0.32 else 0.46)
			end),
		})),
		-- spin speed bar
		React.createElement("frame", {
			Size = UDim2.new(if contained then 0.58 else 0.82, 0, 0, 2),
			Position = center,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Palette.cream,
			BackgroundTransparency = props.spinEnergy:map(function(amount)
				return 1 - amount * 0.12
			end),
			BorderSizePixel = 0,
			ZIndex = 406,
		})
	)
end

-- ─── RevealHeader ──────────────────────────────────────────────────────────────
local function RevealHeader(_param)
	local props = _param.props
	local layout = _param.layout
	local status = if props.phase == "charge" then "GET READY"
		elseif props.phase == "spin" then "ROLLING"
		elseif props.phase == "land" then "YOU GOT"
		elseif props.phase == "done" or props.phase == "exit" then "READY"
		else "OPENING"

	-- animated status dot
	local dotPulse, setDotPulse = React.useBinding(0)
	React.useEffect(function()
		local conn = RunService.RenderStepped:Connect(function(dt)
			setDotPulse((dotPulse:getValue() + dt * 2.8) % 1)
		end)
		return function() conn:Disconnect() end
	end, {})

	local dotColor = if props.phase == "spin" then Palette.cyan
		elseif props.phase == "land" then props.winnerAccent or Palette.mint
		elseif props.phase == "done" then Palette.mint
		else Palette.muted

	local narrowShort = props.shortLandscape and layout.headerSize.X.Offset < 260
	local simplifiedHeader = narrowShort or layout.compactHeight

	return React.createElement("frame", {
		Size = layout.headerSize,
		Position = layout.headerPosition,
		AnchorPoint = layout.headerAnchor,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 420,
	},
		-- category label
		not simplifiedHeader and React.createElement(Text, {
			value = "RELIC CRATE",
			size = 9,
			color = props.sessionAccent,
			weight = Enum.FontWeight.Heavy,
			align = if props.shortLandscape then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			sizeConstraint = UDim2.new(1, if props.shortLandscape then -128 else 0, 0, 14),
			zIndex = 421,
		}),
		-- crate name
		React.createElement(Text, {
			value = props.crateName,
			size = if props.shortLandscape then 21 elseif props.portrait then 23 else 27,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			align = if props.shortLandscape and not simplifiedHeader then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			fit = true,
			minSize = 12,
			position = UDim2.fromOffset(0, if simplifiedHeader then 0 elseif props.shortLandscape then 15 else 16),
			sizeConstraint = UDim2.new(1, if props.shortLandscape and not simplifiedHeader then -128 else 0, 0, if props.shortLandscape then 28 else 34),
			zIndex = 421,
		}),
		-- status line with animated dot
		React.createElement("frame", {
			Size = if simplifiedHeader then UDim2.new(1, 0, 0, 15) elseif props.shortLandscape then UDim2.fromOffset(128, 36) else UDim2.new(1, 0, 0, 14),
			Position = if simplifiedHeader then UDim2.fromOffset(0, 27) elseif props.shortLandscape then UDim2.new(1, -128, 0, 6) else UDim2.fromOffset(0, 53),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 421,
		},
			-- animated dot
			React.createElement("frame", {
				Size = UDim2.fromOffset(6, 6),
				Position = UDim2.new(if props.shortLandscape and not simplifiedHeader then 0 else 0.5, -48, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = dotColor,
				BackgroundTransparency = dotPulse:map(function(t)
					return 0.1 + math.sin(t * math.pi * 2) * 0.35
				end),
				BorderSizePixel = 0,
				ZIndex = 422,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) })),
			React.createElement(Text, {
				value = `{status}  •  {props.rollIndex + 1}/{props.rollCount}`,
				size = 9,
				color = Palette.muted,
				weight = Enum.FontWeight.Bold,
				align = if props.shortLandscape and not simplifiedHeader then Enum.TextXAlignment.Right else Enum.TextXAlignment.Center,
				fit = true,
				minSize = 8,
				sizeConstraint = UDim2.fromScale(1, 1),
				zIndex = 421,
			})
		),
		-- progress bar (non-compact, non-landscape)
		not props.shortLandscape and not layout.compactHeight and React.createElement("frame", {
			Size = UDim2.fromOffset(math.min(190, props.rollCount * 22), 4),
			Position = UDim2.new(0.5, 0, 1, -2),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Palette.line,
			BorderSizePixel = 0,
			ZIndex = 421,
		}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }),
			React.createElement("frame", {
				Size = UDim2.new(math.clamp((props.rollIndex + 1) / math.max(1, props.rollCount), 0, 1), 0, 1, 0),
				BackgroundColor3 = props.sessionAccent,
				BorderSizePixel = 0,
				ZIndex = 422,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
		)
	)
end

-- ─── ReelCard ──────────────────────────────────────────────────────────────────
local function ReelCard(_param)
	local card = _param.card
	local x = _param.x
	local width = _param.width
	local height = _param.height
	local emphasize = _param.emphasize
	local detailed = _param.detailed
	local fitScale = _param.fitScale
	local reducedMotion = _param.reducedMotion
	local winnerScale = _param.winnerScale
	local shimmerPhase = _param.shimmerPhase or 0  -- 0..1 offset per card

	local clock = useShimmerClock()
	local scale = if emphasize then winnerScale:map(function(amount)
		return amount * fitScale
	end) else 0.94 * fitScale
	local cardZ = if emphasize then 433 else 431

	-- shimmer strip position driven by global clock + per-card phase offset
	local shimmerX = React.joinBindings({ clock }):map(function(vals)
		local t = (vals[1] + shimmerPhase) % 1
		-- only show shimmer for a short burst window
		local sweep = if t < 0.22 then easeOutExpo(t / 0.22) else if t < 0.35 then 1 - (t - 0.22) / 0.13 else -0.15
		return UDim2.new(sweep, -28, 0, 0)
	end)

	-- winner glow halo: glowing outline ring that breathes
	local haloGlow
	if emphasize and not reducedMotion then
		haloGlow = React.createElement("frame", {
			Size = UDim2.new(1, 16, 1, 16),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = cardZ - 1,
		}, React.createElement("uistroke", {
			Color = lighten(card.accent, 0.18),
			Thickness = winnerScale:map(function(amt)
				return 1.5 + amt * 2.5
			end),
			Transparency = winnerScale:map(function(amt)
				return 1 - amt * 0.72
			end),
		}), React.createElement("uicorner", { CornerRadius = UDim.new(0, 17) }))
	end

	return React.createElement("frame", {
		Size = UDim2.fromOffset(width, height),
		Position = UDim2.fromOffset(x, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = cardZ,
	},
		-- outer halo glow (winner only)
		haloGlow,
		React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = cardZ,
		}, React.createElement("uiscale", { Scale = scale }),
			-- drop shadow
			React.createElement("frame", {
				Size = UDim2.new(1, -8, 1, -10),
				Position = UDim2.fromOffset(4, 6),
				BackgroundColor3 = Palette.shadow or Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 0.36,
				BorderSizePixel = 0,
				ZIndex = cardZ,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 12) })),
			-- card body
			React.createElement("frame", {
				Size = UDim2.new(1, -4, 1, -4),
				BackgroundColor3 = Palette.panelRaised,
				BorderSizePixel = 0,
				ZIndex = cardZ + 1,
				ClipsDescendants = true,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 12) }),
				React.createElement("uistroke", {
					Color = if emphasize then lighten(card.accent, 0.3) else card.accent,
					Thickness = if emphasize then 2 else 1,
					Transparency = if emphasize then 0.04 else 0.42,
				}),
				React.createElement("uigradient", {
					Color = ColorSequence.new(lighten(Palette.panelRaised, 0.05), darken(Palette.panelRaised, 0.18)),
					Rotation = 90,
				}),
				-- rarity color cap strip
				React.createElement("frame", {
					Size = UDim2.new(1, -18, 0, 3),
					Position = UDim2.fromOffset(9, 8),
					BackgroundColor3 = card.accent,
					BackgroundTransparency = if emphasize then 0 else 0.18,
					BorderSizePixel = 0,
					ZIndex = cardZ + 2,
				}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) })),
				-- shimmer sweep (over card body, clipped)
				not reducedMotion and React.createElement("frame", {
					Size = UDim2.fromOffset(28, height),
					Position = shimmerX,
					AnchorPoint = Vector2.new(0, 0),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Rotation = 12,
					ZIndex = cardZ + 5,
				}, React.createElement("uigradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Palette.cream),
						ColorSequenceKeypoint.new(0.5, Palette.cream),
						ColorSequenceKeypoint.new(1, Palette.cream),
					}),
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.35, if emphasize then 0.38 else 0.72),
						NumberSequenceKeypoint.new(0.5, if emphasize then 0.22 else 0.58),
						NumberSequenceKeypoint.new(0.65, if emphasize then 0.38 else 0.72),
						NumberSequenceKeypoint.new(1, 1),
					}),
				})),
				-- content
				if detailed then React.createElement(React.Fragment, nil,
					React.createElement(IconTile, {
						kind = itemIconKind(card.definitionId),
						accent = card.accent,
						size = 52,
						radius = 12,
						position = UDim2.new(0.5, 0, 0, 19),
						anchorPoint = Vector2.new(0.5, 0),
						reducedMotion = reducedMotion,
						glow = emphasize,
						filled = true,
						zIndex = cardZ + 3,
					}),
					React.createElement(Badge, {
						value = string.upper(card.rarity),
						accent = card.accent,
						filled = true,
						position = UDim2.new(0.5, -50, 0, 76),
						size = UDim2.fromOffset(100, 20),
						zIndex = cardZ + 4,
					}),
					React.createElement(Text, {
						value = card.name,
						size = 12,
						color = Palette.cream,
						weight = Enum.FontWeight.Heavy,
						align = Enum.TextXAlignment.Center,
						fit = true,
						minSize = 9,
						position = UDim2.fromOffset(8, 99),
						sizeConstraint = UDim2.new(1, -16, 0, 22),
						zIndex = cardZ + 4,
					})
				) else React.createElement(React.Fragment, nil,
					React.createElement("frame", {
						Size = UDim2.fromOffset(52, 52),
						Position = UDim2.new(0.5, 0, 0, 24),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = darken(card.accent, 0.6),
						BorderSizePixel = 0,
						ZIndex = cardZ + 3,
					}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 12) }),
						React.createElement("uistroke", {
							Color = card.accent,
							Thickness = 1,
							Transparency = 0.42,
						}),
						React.createElement("frame", {
							Size = UDim2.fromOffset(24, 24),
							Position = UDim2.fromScale(0.5, 0.5),
							AnchorPoint = Vector2.new(0.5, 0.5),
							Rotation = 45,
							BackgroundColor3 = card.accent,
							BorderSizePixel = 0,
							ZIndex = cardZ + 4,
						}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 6) })),
						React.createElement("frame", {
							Size = UDim2.fromOffset(8, 8),
							Position = UDim2.fromScale(0.5, 0.5),
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = Palette.cream,
							BorderSizePixel = 0,
							ZIndex = cardZ + 5,
						}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
					),
					React.createElement("frame", {
						Size = UDim2.new(1, -34, 0, 3),
						Position = UDim2.new(0.5, 0, 1, -24),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = card.accent,
						BackgroundTransparency = 0.32,
						BorderSizePixel = 0,
						ZIndex = cardZ + 3,
					}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
				),
				-- winner tag badge
				card.tag ~= nil and emphasize and React.createElement(Badge, {
					value = card.tag,
					accent = if card.tag == "NEW" then Palette.mint else card.accent,
					filled = true,
					position = UDim2.new(1, -54, 0, -8),
					size = UDim2.fromOffset(48, 18),
					zIndex = cardZ + 5,
				})
			)
		)
	)
end

-- ─── ForgeReel ─────────────────────────────────────────────────────────────────
local function ForgeReel(_param)
	local props = _param.props
	local layout = _param.layout
	local landed = props.phase == "land" or props.phase == "done" or props.phase == "exit"
	local cardFitScale = math.min(1, math.max(0.01, (layout.reelHeight - 4) / props.cardHeight))

	local pressOffset = React.joinBindings({ props.tickEnergy, props.landFlash, props.chargePulse }):map(function(values)
		return math.round(values[1] * 5 + values[2] * 12 + values[3] * 3)
	end)
	local selectorScale = React.joinBindings({ props.tickEnergy, props.landPop, props.landFlash }):map(function(values)
		return 1 + values[1] * 0.025 + values[2] * 0.035 + values[3] * 0.02
	end)
	local progressWidth = props.spinProgress:map(function(amount)
		return UDim2.new(math.clamp(amount, 0, 1), 0, 1, 0)
	end)

	-- afterimage speed bars (visible when spinning fast)
	local speedBars = {}
	if props.allowAmbient then
		for index = 0, 5 do
			speedBars[index + 1] = React.createElement("frame", {
				key = `rail-speed-{index}`,
				Size = UDim2.fromOffset(52 + index * 12, 2),
				Position = UDim2.new(0.12 + index * 0.15, 0, 0.5, if index % 2 == 0 then -32 else 32),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = if index % 2 == 0 then props.sessionAccent else Palette.cream,
				BackgroundTransparency = props.spinEnergy:map(function(amount)
					return 1 - amount * (0.22 + index * 0.025) * props.glowScale
				end),
				BorderSizePixel = 0,
				ZIndex = 428,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
		end
	end

	-- reel cards with shimmer phase offsets
	local cardElements = {}
	for i, card in props.cards do
		local besideWinner = (props.cards[i] and props.cards[i].winner == true) or (props.cards[i + 2] and props.cards[i + 2].winner == true)
		local detailed = not props.economyMode or i <= 4 or card.winner or besideWinner
		cardElements[i] = React.createElement(ReelCard, {
			key = card.key,
			card = card,
			x = i * props.stride,
			width = props.cardWidth,
			height = props.cardHeight,
			emphasize = card.winner and landed,
			detailed = detailed,
			fitScale = cardFitScale,
			reducedMotion = props.reducedMotion,
			winnerScale = props.winnerCardScale,
			shimmerPhase = (i * 0.13) % 1,
		})
	end

	return React.createElement("frame", {
		Size = layout.stageSize,
		Position = layout.stagePosition,
		AnchorPoint = layout.stageAnchor,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 425,
		ClipsDescendants = false,
	},
		-- outer shadow
		React.createElement("frame", {
			Size = UDim2.new(1, 6, 1, 8),
			Position = UDim2.fromOffset(-3, 7),
			BackgroundColor3 = Palette.shadow or Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			ZIndex = 424,
		}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 18) })),
		-- main stage frame
		React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Palette.panel,
			BorderSizePixel = 0,
			ZIndex = 425,
			ClipsDescendants = false,
		}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 18) }),
			React.createElement("uistroke", {
				Color = if landed then props.winnerAccent else props.sessionAccent,
				Thickness = if landed then 2 else 1.25,
				Transparency = if landed then 0.08 else 0.28,
			}),
			React.createElement("uigradient", {
				Color = ColorSequence.new(lighten(Palette.panel, 0.045), darken(Palette.panel, 0.16)),
				Rotation = 90,
			}),
			-- YOUR ROLL header strip
			React.createElement("frame", {
				Size = UDim2.new(1, -24, 0, 30),
				Position = UDim2.fromOffset(12, 8),
				BackgroundColor3 = Palette.night,
				BackgroundTransparency = 0.08,
				BorderSizePixel = 0,
				ZIndex = 426,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 9) }),
				React.createElement(Text, {
					value = "YOUR ROLL",
					size = 9,
					color = Palette.muted,
					weight = Enum.FontWeight.Heavy,
					position = UDim2.fromOffset(10, 0),
					sizeConstraint = UDim2.new(1, -98, 1, 0),
					zIndex = 427,
				}),
				React.createElement(Text, {
					value = if props.phase == "spin" then "ROLLING" elseif landed then "LANDED" else "READY",
					size = 9,
					color = if landed then props.winnerAccent else props.sessionAccent,
					weight = Enum.FontWeight.Heavy,
					align = Enum.TextXAlignment.Right,
					position = UDim2.new(1, -76, 0, 0),
					sizeConstraint = UDim2.fromOffset(66, 30),
					zIndex = 427,
				})
			),
			-- reel track
			React.createElement("frame", {
				Size = UDim2.fromOffset(layout.reelWidth, layout.reelHeight),
				Position = UDim2.new(0.5, 0, 1, -10),
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = Palette.void,
				BackgroundTransparency = 0.05,
				BorderSizePixel = 0,
				ZIndex = 427,
				ClipsDescendants = true,
				Visible = not layout.compactHeight or not landed,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 12) }),
				React.createElement("uistroke", {
					Color = Palette.line,
					Thickness = 1,
					Transparency = 0.35,
				}),
				-- center guide line
				React.createElement("frame", {
					Size = UDim2.new(1, -16, 0, 4),
					Position = UDim2.new(0.5, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Palette.lineSoft,
					BackgroundTransparency = 0.36,
					BorderSizePixel = 0,
					ZIndex = 428,
				}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) })),
				-- speed afterimage bars
				table.unpack(speedBars),
				-- card strip
				React.createElement(ShimmerProvider, {},
					React.createElement("frame", {
						Size = UDim2.fromOffset(#props.cards * props.stride, props.cardHeight),
						Position = props.reelOffset:map(function(offset)
							return UDim2.fromOffset(layout.reelWidth / 2 - props.cardWidth / 2 - offset, math.floor((layout.reelHeight - props.cardHeight) / 2))
						end),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ZIndex = 429,
					}, table.unpack(cardElements))
				),
				-- left edge fade vignette
				React.createElement("frame", {
					Size = UDim2.new(0, math.min(54, layout.reelWidth * 0.16), 1, 0),
					BackgroundColor3 = Palette.void,
					BackgroundTransparency = 0.05,
					BorderSizePixel = 0,
					ZIndex = 438,
				}, React.createElement("uigradient", {
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
				})),
				-- right edge fade vignette
				React.createElement("frame", {
					Size = UDim2.new(0, math.min(54, layout.reelWidth * 0.16), 1, 0),
					Position = UDim2.fromScale(1, 0),
					AnchorPoint = Vector2.new(1, 0),
					BackgroundColor3 = Palette.void,
					BackgroundTransparency = 0.05,
					BorderSizePixel = 0,
					ZIndex = 438,
				}, React.createElement("uigradient", {
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
				})),
				-- selection highlight bracket
				React.createElement("frame", {
					Size = UDim2.fromOffset(props.cardWidth + 12, props.cardHeight + 8),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = if landed then props.winnerAccent else props.sessionAccent,
					BackgroundTransparency = if landed then 0.91 else 0.95,
					BorderSizePixel = 0,
					ZIndex = 439,
				}, React.createElement("uiscale", {
					Scale = selectorScale:map(function(amount)
						return amount * cardFitScale
					end),
				}), React.createElement("uicorner", { CornerRadius = UDim.new(0, 14) }),
					React.createElement("uistroke", {
						Color = if landed then props.winnerAccent else props.sessionAccent,
						Thickness = if landed then 2.5 else 1.5,
						Transparency = if landed then 0.04 else 0.18,
					})
				),
				-- center tick needle
				React.createElement("frame", {
					Size = UDim2.new(0, 2, 1, -12),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Palette.cream,
					BackgroundTransparency = props.tickEnergy:map(function(amount)
						return 0.62 - amount * 0.36
					end),
					BorderSizePixel = 0,
					ZIndex = 440,
				})
			),
			-- skip caret pill
			React.createElement("frame", {
				Size = UDim2.fromOffset(68, 12),
				Position = pressOffset:map(function(value)
					return UDim2.new(0.5, 0, 0, 33 + value)
				end),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Palette.creamSoft,
				BorderSizePixel = 0,
				ZIndex = 445,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 4) }),
				React.createElement("uigradient", {
					Color = ColorSequence.new(Palette.cream, Palette.lineSoft),
					Rotation = 90,
				}),
				React.createElement("frame", {
					Size = UDim2.fromOffset(28, 9),
					Position = UDim2.fromScale(0.5, 1),
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundColor3 = if landed then props.winnerAccent else props.sessionAccent,
					BorderSizePixel = 0,
					ZIndex = 446,
				}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 3) }))
			),
			-- spin progress bar
			React.createElement("frame", {
				Size = UDim2.new(1, -24, 0, 3),
				Position = UDim2.new(0.5, 0, 1, -5),
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = Palette.line,
				BorderSizePixel = 0,
				ZIndex = 447,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }),
				React.createElement("frame", {
					Size = progressWidth,
					BackgroundColor3 = if landed then props.winnerAccent else props.sessionAccent,
					BorderSizePixel = 0,
					ZIndex = 448,
				}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
			)
		)
	)
end

-- ─── LandingBurst ──────────────────────────────────────────────────────────────
local function LandingBurst(_param)
	local props = _param.props
	local layout = _param.layout
	if props.phase ~= "land" then return nil end

	local count = math.clamp(math.floor(5 + props.fxBudget * 8), 5, 13)
	local center = UDim2.new(
		layout.stagePosition.X.Scale, layout.stagePosition.X.Offset + (0.5 - layout.stageAnchor.X) * layout.stageSize.X.Offset,
		layout.stagePosition.Y.Scale, layout.stagePosition.Y.Offset + (0.5 - layout.stageAnchor.Y) * layout.stageSize.Y.Offset
	)

	-- spark particles
	local sparks = {}
	if not props.reducedMotion and props.allowAmbient then
		for index = 0, 12 do
			if index >= count then break end
			local angle = (index / count) * math.pi * 2 - math.pi / 2
			local distance = 58 + (index % 4) * 22
			local sizeW = if index % 3 == 0 then 8 else 5
			local sizeH = if index % 2 == 0 then 3 else 5
			local travel = props.landFlash:map(function(amount)
				return 1 - amount
			end)
			sparks[index + 1] = React.createElement("frame", {
				key = `crate-spark-{index}`,
				Size = UDim2.fromOffset(sizeW, sizeH),
				Position = travel:map(function(amount)
					return UDim2.new(
						center.X.Scale, center.X.Offset + math.cos(angle) * distance * amount,
						center.Y.Scale, center.Y.Offset + math.sin(angle) * distance * amount
					)
				end),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = index * 37,
				BackgroundColor3 = if index % 3 == 0 then Palette.cream else props.winnerAccent,
				BackgroundTransparency = travel:map(function(amount)
					return math.clamp(amount * 1.2, 0, 1)
				end),
				BorderSizePixel = 0,
				ZIndex = 448,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
		end
	end

	-- vertical column beams (shooting upward on land)
	local beams = {}
	if not props.reducedMotion and props.allowAmbient then
		for i = 0, 2 do
			local bx = -60 + i * 60
			beams[i + 1] = React.createElement("frame", {
				key = `land-beam-{i}`,
				Size = props.landFlash:map(function(f)
					return UDim2.fromOffset(2 + i, math.round(f * (140 + i * 40)))
				end),
				Position = UDim2.new(center.X.Scale, center.X.Offset + bx, center.Y.Scale, center.Y.Offset),
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = if i == 1 then Palette.cream else props.winnerAccent,
				BackgroundTransparency = props.landFlash:map(function(f)
					return 1 - f * (0.55 - i * 0.1)
				end),
				BorderSizePixel = 0,
				ZIndex = 448,
			}, React.createElement("uigradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.6, 0.3),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Rotation = 90,
			}), React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
		end
	end

	-- shockwave ring
	local shockRing = not props.reducedMotion and React.createElement("frame", {
		Size = props.landFlash:map(function(f)
			local s = easeOutExpo(f) * 160
			return UDim2.fromOffset(s, s)
		end),
		Position = center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 449,
	}, React.createElement("uistroke", {
		Color = props.winnerAccent,
		Thickness = 2,
		Transparency = props.landFlash:map(function(f)
			return 0.05 + (1 - f) * 0.85
		end),
	}), React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))

	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 448,
		Active = false,
	},
		table.unpack(sparks),
		table.unpack(beams),
		shockRing,
		-- horizontal flash bar
		React.createElement("frame", {
			Size = props.landFlash:map(function(amount)
				return UDim2.fromOffset(150 + amount * 460, 3 + amount * 3)
			end),
			Position = center,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Palette.cream,
			BackgroundTransparency = props.landFlash:map(function(amount)
				return 1 - amount * 0.82
			end),
			BorderSizePixel = 0,
			ZIndex = 448,
		}, React.createElement("uigradient", {
			Color = ColorSequence.new(props.winnerAccent, Palette.cream),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.42, 0.05),
				NumberSequenceKeypoint.new(0.58, 0.05),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}))
	)
end

-- ─── ResultPanel ───────────────────────────────────────────────────────────────
local function ResultPanel(_param)
	local props = _param.props
	local layout = _param.layout
	local visible = props.phase == "land" or props.phase == "done" or props.phase == "exit"
	-- Hooks stay above the visibility return. This panel is not the live overlay,
	-- but mounting it across phases used to skip useBinding/useEffect.
	local accentLineWidth, setAccentLineWidth = React.useBinding(0)
	React.useEffect(function()
		if not visible then
			return nil
		end
		local start = os.clock()
		local dur = 0.55
		local conn = RunService.RenderStepped:Connect(function()
			local t = math.clamp((os.clock() - start) / dur, 0, 1)
			setAccentLineWidth(easeOutBack(t))
		end)
		return function() conn:Disconnect() end
	end, { props.winnerName, visible })
	if not visible then return nil end

	return React.createElement("frame", {
		Size = layout.resultSize,
		Position = props.landPop:map(function(amount)
			return UDim2.new(
				layout.resultPosition.X.Scale, layout.resultPosition.X.Offset,
				layout.resultPosition.Y.Scale, layout.resultPosition.Y.Offset + math.round((1 - amount) * 18)
			)
		end),
		AnchorPoint = layout.resultAnchor,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 450,
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = props.winnerAccent,
		background = Palette.panelRaised,
		padding = if props.shortLandscape then 10 else 12,
		highlight = true,
		reducedMotion = props.reducedMotion,
		clips = false,
		zIndex = 450,
	},
		-- rarity • roll counter
		React.createElement(Text, {
			value = `{string.upper(props.winnerRarity)}  •  ROLL {props.rollIndex + 1}/{props.rollCount}`,
			size = 9,
			color = props.winnerAccent,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			minSize = 7,
			sizeConstraint = UDim2.new(1, if props.shortLandscape then 0 else -118, 0, 14),
			zIndex = 452,
		}),
		-- item name
		React.createElement(Text, {
			value = props.winnerName,
			size = if props.shortLandscape then 16 else 19,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			minSize = 9,
			position = UDim2.fromOffset(0, 18),
			sizeConstraint = UDim2.new(1, if props.shortLandscape then 0 else -118, 0, 26),
			zIndex = 452,
		}),
		-- animated accent underline
		React.createElement("frame", {
			Size = accentLineWidth:map(function(t)
				return UDim2.new(t * (if props.shortLandscape then 0.55 else 0.42), 0, 0, 2)
			end),
			Position = UDim2.fromOffset(0, 44),
			BackgroundColor3 = props.winnerAccent,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ZIndex = 453,
		}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) })),
		-- detail text
		React.createElement(Text, {
			value = props.resultDetail,
			size = 9,
			color = Palette.creamSoft,
			fit = true,
			minSize = 7,
			wrap = true,
			position = UDim2.fromOffset(0, 47),
			sizeConstraint = UDim2.new(1, if props.shortLandscape then 0 else -118, 0, if props.shortLandscape then 32 else 24),
			zIndex = 452,
		}),
		-- result tag badge
		React.createElement(Badge, {
			value = props.resultTag,
			accent = if props.resultTag == "NEW FIND" then Palette.mint else props.winnerAccent,
			filled = true,
			position = if props.shortLandscape then UDim2.new(0, 0, 1, -27) else UDim2.new(1, -106, 0.5, -14),
			size = if props.shortLandscape then UDim2.new(1, 0, 0, 22) else UDim2.fromOffset(106, 28),
			zIndex = 453,
		})
	))
end

-- ─── CrateRevealStage (root) ───────────────────────────────────────────────────
local function CrateRevealStage(props)
	local layout = resolveLayout(props)
	local antilag = useAntilag()
	local softMotion = props.reducedMotion == true
	local reducedMotion = softMotion
	local allowAmbient = not reducedMotion and props.allowAmbient ~= false and antilag.allowAmbient
	local actionHostRef = React.useRef(nil)
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = actionHostRef.current
		if host == nil then
			return nil
		end
		if props.phase ~= "spin" and props.phase ~= "done" then
			GamepadNavigationService.ClearSelection()
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
	end, { props.phase })
	local dimmer = props.visualShow:map(function(amount)
		return 1 - math.clamp(amount, 0, 1) * 0.985
	end)
	local accentWash = props.visualShow:map(function(amount)
		return 1 - math.clamp(amount, 0, 1) * 0.08
	end)
	local showingClaim = props.phase == "done" or props.phase == "exit"

	-- Fold reducedMotion into downstream props without mutating the caller table.
	local stageProps = table.clone(props)
	stageProps.reducedMotion = reducedMotion
	stageProps.allowAmbient = allowAmbient

	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 400,
	},
		-- full-screen tap-to-interact backdrop
		React.createElement("imagebutton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Palette.void,
			BackgroundTransparency = dimmer,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Selectable = false,
			Active = props.phase == "spin" or props.phase == "done",
			ZIndex = 401,
			Event = {
				Activated = function()
					if props.phase == "spin" then
						Audio:play("crateBrake")
						props.onQuickLand()
					elseif props.phase == "done" then
						Audio:play("crateClaim")
						props.onClaim()
					end
				end,
			},
		}),
		-- accent gradient wash overlay
		React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = darken(props.sessionAccent, 0.6),
			BackgroundTransparency = accentWash,
			BorderSizePixel = 0,
			ZIndex = 402,
		}, React.createElement("uigradient", {
			Color = ColorSequence.new(darken(props.sessionAccent, 0.78), Palette.void),
			Rotation = 90,
		})),
		-- main content (scaled from center on enter/exit)
		React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 404,
			ClipsDescendants = true,
			Visible = props.visualShow:map(function(amount)
				return amount > 0.015
			end),
		}, React.createElement(ScaleFromCenter, {
			scale = props.shellScale,
			zIndex = 404,
		},
			React.createElement(ForgeBackdrop, { props = stageProps, layout = layout }),
			React.createElement(RevealHeader, { props = stageProps, layout = layout }),
			React.createElement(ForgeReel, { props = stageProps, layout = layout }),
			React.createElement(LandingBurst, { props = stageProps, layout = layout }),
			React.createElement(ResultPanel, { props = stageProps, layout = layout }),
			-- SKIP button (during spin)
			props.phase == "spin" and React.createElement("frame", {
				ref = actionHostRef,
				Name = "CrateSkip",
				Size = layout.actionSize,
				Position = layout.actionPosition,
				AnchorPoint = layout.actionAnchor,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 455,
			}, React.createElement(Button, {
				text = "SKIP TO RESULT",
				icon = "Chevron",
				onClick = props.onQuickLand,
				color = Palette.panelSoft,
				textColor = Palette.creamSoft,
				outline = true,
				size = UDim2.fromScale(1, 1),
				reducedMotion = reducedMotion,
				selectable = true,
			})),
			-- CLAIM button (after land)
			showingClaim and React.createElement("frame", {
				ref = actionHostRef,
				Name = "CrateClaim",
				Size = layout.actionSize,
				Position = props.claimSlide:map(function(amount)
					return UDim2.new(
						layout.actionPosition.X.Scale, layout.actionPosition.X.Offset,
						layout.actionPosition.Y.Scale, layout.actionPosition.Y.Offset + math.round((1 - amount) * 24)
					)
				end),
				AnchorPoint = layout.actionAnchor,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = false,
				ZIndex = 456,
			}, React.createElement(Button, {
				text = props.claimText,
				icon = "Gift",
				onClick = props.onClaim,
				color = props.sessionAccent,
				textColor = Palette.ink,
				size = UDim2.fromScale(1, 1),
				reducedMotion = reducedMotion,
				highlight = true,
				selectable = true,
				disabled = props.phase == "exit",
			}))
		))
	)
end

return {
	CrateRevealStage = CrateRevealStage,
}
end

-- ======================================================================
-- Suite entry point
-- ======================================================================
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		return __load(name)
	end,
})

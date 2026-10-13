--!nonstrict
local __defs = {}
__defs["BazaarView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Ui = require(script.Parent.Parent.UiCore)("ui")
local Theme = require(script.Parent.Parent.CoreKit)("theme")
local Format = require(script.Parent.Parent.CoreKit)("format")
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local Browse = require(script.Parent.Parent.BrowseKit)
local h, Palette = React.createElement, Theme.Palette
local CATEGORIES = {
	{ id = "All", label = "All supplies" }, { id = "Resources", label = "Resources" },
	{ id = "Keys", label = "Keys" }, { id = "Boosts", label = "Boosts" },
	{ id = "Command", label = "Command" }, { id = "Tokens", label = "Wheel tokens" },
	{ id = "Rare", label = "Rare finds" }, { id = "Saved", label = "Saved" },
	{ id = "Requests", label = "Requests" },
	{ id = "History", label = "Purchases" },
}
local ACCENTS = { Resources = Palette.mango, Keys = Palette.violet, Boosts = Palette.cyan, Command = Palette.green, Tokens = Palette.pink, Rare = Palette.creamSoft }
local sessionOrder

local function MerchantPortrait(props)
	local accent = props.accent
	local function round(radius) return h("uicorner", { CornerRadius = radius }) end
	return h("frame", {
		Size = props.size, Position = props.position, BackgroundColor3 = Palette.panelSoft, BorderSizePixel = 0, ClipsDescendants = true,
	}, round(UDim.new(0, 12)), h("uistroke", { Color = accent, Thickness = 1, Transparency = 0.35 }),
		h("frame", {
			Size = UDim2.fromScale(1, 0.55), Position = UDim2.fromScale(0, 0.45), BorderSizePixel = 0,
			BackgroundColor3 = accent, BackgroundTransparency = 0.82,
		}),
		h("frame", {
			Size = UDim2.fromScale(0.78, 0.42), Position = UDim2.fromScale(0.11, 0.7), BorderSizePixel = 0,
			BackgroundColor3 = Palette.panelRaised,
		}, round(UDim.new(0.45, 0)), h("uistroke", { Color = accent, Thickness = 1.5, Transparency = 0.2 })),
		h("frame", {
			Size = UDim2.fromScale(0.16, 0.2), Position = UDim2.fromScale(0.42, 0.56), BorderSizePixel = 0,
			BackgroundColor3 = Palette.panelRaised,
		}),
		h("frame", {
			Size = UDim2.fromScale(0.44, 0.44), Position = UDim2.fromScale(0.28, 0.18), BorderSizePixel = 0,
			BackgroundColor3 = Palette.panelRaised,
		}, round(UDim.new(0.5, 0)), h("uistroke", { Color = accent, Thickness = 1.5, Transparency = 0.2 })),
		h("frame", {
			Size = UDim2.fromScale(0.6, 0.08), Position = UDim2.fromScale(0.2, 0.2), BorderSizePixel = 0,
			BackgroundColor3 = accent, BackgroundTransparency = 0.15, Rotation = props.tilt or -4,
		}, round(UDim.new(0.5, 0))),
		h("frame", {
			Size = UDim2.fromScale(0.36, 0.14), Position = UDim2.fromScale(0.32, 0.09), BorderSizePixel = 0,
			BackgroundColor3 = accent, BackgroundTransparency = 0.15, Rotation = props.tilt or -4,
		}, round(UDim.new(0.3, 0))),
		h("frame", {
			Size = UDim2.fromScale(0.04, 0.22), Position = UDim2.fromScale(0.48, 0.76), BorderSizePixel = 0,
			BackgroundColor3 = accent, BackgroundTransparency = 0.3,
		}))
end

local function orderTotal(price, quantity)
	local value = tonumber(price)
	if value and value < math.huge and value * quantity < math.huge then return value * quantity end
	local logarithm = Format.log10Flux(price) + math.log(quantity) / math.log(10)
	if logarithm == math.huge then return "inf" end
	local exponent = math.floor(logarithm)
	return string.format("%.8fe%d", 10 ^ (logarithm - exponent), exponent)
end

local function supplyUnit(reward)
	local identity, units
	for kind, value in reward do
		if identity then return nil end
		if kind == "Keys" then
			for crate, count in value do
				if identity then return nil end
				identity, units = "Keys:" .. crate, count
			end
		elseif kind == "Boost" then
			identity, units = "Boost:" .. value, 1
		elseif type(value) == "number" and value > 0 then
			identity, units = kind, value
		else
			return nil
		end
	end
	return identity, units
end

local function BazaarView(props)
	local market = props.state.Bazaar and props.state.Bazaar.Market
	local category, setCategory = Browse.useLinkedTab("Bazaar", "All", props.initialCategory)
	local query, setQuery = Browse.useLinkedQuery("Bazaar", props.initialQuery)
	local sort, setSort = React.useState("Discount")
	local amount, setAmount = React.useState("One")
	local inspected, setInspected = React.useState(nil)
	local saved = if market then market.Saved or {} else {}
	local note, setNote = React.useState("")
	local busy, setBusy = React.useState(false)
	local width, setWidth = React.useState(320)
	local now, setNow = React.useState(workspace:GetServerTimeNow())
	local scrollRef = React.useRef(nil)
	local pending = React.useRef(false)
	local nonce = React.useRef(0)
	local live = React.useRef(true)
	local timeout = React.useRef(nil)
	local unresolved = React.useRef(sessionOrder)
	React.useEffect(function()
		live.current = true
		local host = scrollRef.current
		local connection
		if host then
			local function measure() if host.AbsoluteSize.X > 0 then setWidth(host.AbsoluteSize.X) end end
			measure()
			connection = host:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
		end
		local clock = task.spawn(function()
			while live.current do
				task.wait(1)
				if live.current then setNow(workspace:GetServerTimeNow()) end
			end
		end)
		return function()
			live.current = false
			nonce.current += 1
			if connection then connection:Disconnect() end
			task.cancel(clock)
			if timeout.current then task.cancel(timeout.current) end
		end
	end, {})
	local function request(action, payload)
		if pending.current then return end
		if action == "BazaarPlay" then
			local previous = unresolved.current
			if previous then
				if previous.Pick ~= payload.Pick or previous.Quantity ~= payload.Quantity then
					setNote("Resolve the previous order before buying something else. Retry that same item and quantity.")
					return
				end
				payload = previous
			else
				unresolved.current = payload
				sessionOrder = payload
			end
		end
		pending.current = true
		nonce.current += 1
		local token = nonce.current
		setBusy(true)
		timeout.current = task.delay(20, function()
			if live.current and nonce.current == token then
				nonce.current += 1
				pending.current = false
				timeout.current = nil
				setBusy(false)
				setNote("No response yet. Retry the same order to check its receipt without buying twice.")
			end
		end)
		props.dispatch(action, payload, function(response)
			if action == "BazaarPlay" and response.Uncertain ~= true then
				if sessionOrder and sessionOrder.RequestId == payload.RequestId then sessionOrder = nil end
				if unresolved.current and unresolved.current.RequestId == payload.RequestId then unresolved.current = nil end
			end
			if not live.current or nonce.current ~= token then return end
			if timeout.current then task.cancel(timeout.current); timeout.current = nil end
			pending.current = false
			setBusy(false)
			setNote(if response.Uncertain then "The connection interrupted your order. Retry it below to check the original receipt."
				elseif response.ok then response.message or "Stock updated." else response.error or "The order could not be completed.")
			Audio:play(if response.ok then "successChime" else "error")
		end)
	end
	local sections = {}
	local viewportWidth = if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize.X else nil
	local function add(id, height, element) table.insert(sections, { id = id, height = height, element = element }) end
	local left = if market then math.max(0, market.EndsAt - now) else 0
	local expired = market ~= nil and left == 0
	-- one row: title on the left, the next shipment and Refresh on the right; one line of rules below
	add("market-header", if viewportWidth ~= nil and viewportWidth < 760 then 148 else 112, h(Ui.Panel, {
		size = UDim2.fromScale(1, 1), padding = 16, accent = Palette.violet, background = Palette.panelRaised,
		reducedMotion = props.reducedMotion,
	}, h(Ui.Text, { value = "Black Market", size = 28, weight = Enum.FontWeight.Heavy, sizeConstraint = UDim2.new(1, -300, 0, 38) }),
		h(Ui.Text, {
			value = if expired then "New stock is ready" elseif market then "Next shipment in " .. Format.clockText(left) else "Waiting for stock",
			size = 14, weight = Enum.FontWeight.Bold, color = Palette.violet, align = Enum.TextXAlignment.Right,
			position = UDim2.new(1, -292, 0, 2), sizeConstraint = UDim2.fromOffset(170, 36),
		}), h(Ui.Button, {
			text = "Refresh", size = UDim2.fromOffset(112, 40), position = UDim2.new(1, -112, 0, 0),
			color = Palette.violet, disabled = busy, reducedMotion = props.reducedMotion,
			onClick = function() request("GetState", {}) end,
		}), h(Ui.Text, {
			value = (if market then `{#market.Offers} shipments from a {market.CatalogSize}-item catalog. Stock limits are yours alone. ` else "Opening the supply ledger... ")
				.. "Prices follow your steady production, with a 1,000-flux minimum.",
			size = 13, wrap = true, color = Palette.muted, position = UDim2.fromOffset(0, 50), sizeConstraint = UDim2.new(1, 0, 0, 44),
		})))
	if note ~= "" then
		add("receipt", 80, h(Ui.Text, { value = note, size = 14, wrap = true, sizeConstraint = UDim2.fromScale(1, 1), color = Palette.creamSoft }))
	end
	local merchant = market and market.Merchant
	local reputation = market and market.Reputation
	if merchant and reputation then
		local accent = Color3.fromRGB(merchant.Accent[1], merchant.Accent[2], merchant.Accent[3])
		local progress = if reputation.NextAt then reputation.Units / reputation.NextAt else 1
		add("merchant", 212, h(Ui.Panel, {
			size = UDim2.fromScale(1, 1), padding = 14, accent = accent, background = Palette.panel, reducedMotion = props.reducedMotion,
		}, h(MerchantPortrait, { accent = accent, size = UDim2.fromOffset(84, 96), position = UDim2.fromOffset(0, 0), tilt = (#merchant.Name % 3 - 1) * 5 }),
			h(Ui.Text, {
				value = merchant.Name, size = 19, weight = Enum.FontWeight.Heavy, position = UDim2.fromOffset(98, 0),
				sizeConstraint = UDim2.new(1, -98, 0, 26),
			}), h(Ui.Text, {
				value = `{merchant.Title} · this hour's picks lean toward {string.lower(merchant.Favors)}`, size = 12, color = accent, wrap = true,
				position = UDim2.fromOffset(98, 28), sizeConstraint = UDim2.new(1, -98, 0, 32),
			}), h(Ui.Text, {
				value = "\u{201C}" .. merchant.Line .. "\u{201D}", size = 13, color = Palette.creamSoft, wrap = true,
				position = UDim2.fromOffset(98, 60), sizeConstraint = UDim2.new(1, -98, 0, 40),
			}), h(Ui.Text, {
				value = `Standing: {reputation.Name}` .. (if reputation.Bonus > 0 then ` · +{reputation.Bonus} stock on regular shelves` else "")
					.. (if reputation.Next then ` · {math.max(0, reputation.NextAt - reputation.Units)} more units bought for {reputation.Next}` else " · highest standing"),
				size = 12, wrap = true, color = Palette.muted, position = UDim2.fromOffset(0, 108), sizeConstraint = UDim2.new(1, 0, 0, 40),
			}), h(Ui.Meter, {
				value = math.clamp(progress, 0, 1), color = accent, reducedMotion = props.reducedMotion,
				position = UDim2.fromOffset(0, 154), size = UDim2.new(1, 0, 0, 6),
			}), h(Ui.Text, {
				value = if reputation.CanProcure then "Requests are open: ask for any supply and it is held for you."
					else `Supply requests open at {reputation.ProcureTier} standing.`,
				size = 12, wrap = true, color = Palette.muted, position = UDim2.fromOffset(0, 166), sizeConstraint = UDim2.new(1, 0, 0, 22),
			})))
	end
	if market and market.Watched and #market.Watched > 0 then
		add("watched", 64, h(Ui.Text, {
			value = "Saved supplies in stock: " .. table.concat(market.Watched, ", "),
			size = 14, wrap = true, color = Palette.green, sizeConstraint = UDim2.fromScale(1, 1),
		}))
	end
	if unresolved.current then
		add("retry-order", 48, h(Ui.Button, {
			text = "Retry previous order", size = UDim2.fromScale(1, 1), color = Palette.violet,
			disabled = busy, reducedMotion = props.reducedMotion,
			onClick = function() request("BazaarPlay", unresolved.current) end,
		}))
	end
	if market and Format.compareFlux(market.Refunded or 0, 0) > 0 then
		add("legacy-refund", 64, h(Ui.Text, {
			value = `{Format.compactNumber(market.Refunded)} flux returned from retired Bazaar savings, terms, prizes and held tickets.`,
			size = 13, wrap = true, color = Palette.green, sizeConstraint = UDim2.fromScale(1, 1),
		}))
	end
	if market and market.RecoveryPending then
		add("legacy-pending", 96, h(Ui.Text, {
			value = "A retired Bazaar claim is awaiting settlement. It has not been discarded. Refresh to retry, or include this in a support report.",
			size = 14, wrap = true, color = Palette.mango, sizeConstraint = UDim2.fromScale(1, 1),
		}))
	end
	add("search", 48, h(Ui.SearchField, {
		value = query, onChange = setQuery, placeholder = "Search supplies or rewards",
		size = UDim2.fromScale(1, 1), accent = Palette.violet, reducedMotion = props.reducedMotion,
	}))
	local columns = math.max(1, math.min(4, math.floor((width + 6) / 130)))
	local rows = math.ceil(#CATEGORIES / columns)
	add("categories", rows * 48 + (rows - 1) * 6, h(Ui.SegmentedTabs, {
		options = CATEGORIES, value = category, columns = columns, gap = 6,
		size = UDim2.fromScale(1, 1), reducedMotion = props.reducedMotion, onChange = setCategory, accent = Palette.violet,
	}))
	if category == "Requests" then
		local procure = market and market.Procure
		local canProcure = reputation and reputation.CanProcure
		local status
		if not market then status = "Opening the supply ledger..."
		elseif procure and procure.Name then
			status = if procure.State == "Pending" then `{procure.Name} is requested. It arrives with the next shipment and is held for 24 hours.`
				elseif procure.State == "Listed" then `{procure.Name} is on your shelf now at 20% off. It stays until bought or the request lapses.`
				elseif procure.State == "Filled" then `Your request for {procure.Name} was filled. Place a new request any time.`
				else `Your request for {procure.Name} lapsed. Place it again to restart the 24-hour hold.`
		else
			status = if canProcure then "No open request. Choose one supply below; it is added to your next shipment and held for 24 hours."
				else `Requests open at {reputation and reputation.ProcureTier or "Regular"} standing. Every unit you buy counts toward it.`
		end
		add("request-status", 112, h(Ui.Panel, {
			size = UDim2.fromScale(1, 1), padding = 14, accent = Palette.violet, reducedMotion = props.reducedMotion,
		}, h(Ui.Text, { value = status, size = 14, wrap = true, sizeConstraint = UDim2.new(1, 0, 0, 82) })))
		if procure and procure.Name and procure.State ~= "Filled" and procure.State ~= "Expired" then
			add("request-cancel", 48, h(Ui.Button, {
				text = "Cancel request", size = UDim2.fromScale(1, 1), color = Palette.panelSoft,
				disabled = busy, reducedMotion = props.reducedMotion,
				onClick = function() request("RequestProcurement", { Id = "" }) end,
			}))
		end
		local shown = 0
		for _, entry in if market then market.Catalog or {} else {} do
			if query ~= "" and not entry.Name:lower():find(query:lower(), 1, true) then continue end
			shown += 1
			local current = procure and procure.Id == entry.Id and (procure.State == "Pending" or procure.State == "Listed")
			add("request-" .. entry.Id, 64, h(Ui.Panel, {
				size = UDim2.fromScale(1, 1), padding = 8, accent = ACCENTS[entry.Category] or Palette.violet, reducedMotion = props.reducedMotion,
			}, h(Ui.Text, {
				value = entry.Name, size = 15, wrap = true, sizeConstraint = UDim2.new(1, -132, 0, 24),
			}), h(Ui.Text, {
				value = entry.Category, size = 11, color = Palette.muted, position = UDim2.fromOffset(0, 26), sizeConstraint = UDim2.new(1, -132, 0, 20),
			}), h(Ui.Button, {
				text = if current then "Requested" else "Request", size = UDim2.fromOffset(120, 48), position = UDim2.new(1, -120, 0, 0),
				color = Palette.violet, disabled = busy or current or not canProcure, reducedMotion = props.reducedMotion,
				onClick = function() request("RequestProcurement", { Id = entry.Id }) end,
			})))
		end
		if shown == 0 and market then
			add("request-empty", 64, h(Ui.Text, { value = "No supplies match that search.", size = 15, wrap = true, sizeConstraint = UDim2.fromScale(1, 1) }))
		end
		return h(PageScaffold, { hostRef = scrollRef, sections = sections, gap = 12, tailPad = 72, scrollBarColor = Palette.violet })
	end
	if category == "History" then
		local history = if market then market.History or {} else {}
		local shown = 0
		for index, entry in history do
			local name = entry.Name
			if query ~= "" and not name:lower():find(query:lower(), 1, true) then continue end
			shown += 1
			add("purchase-" .. index, 112, h(Ui.Panel, {
				size = UDim2.fromScale(1, 1), padding = 14, accent = Palette.violet, reducedMotion = props.reducedMotion,
			}, h(Ui.Text, {
				value = `{entry.Quantity} × {name}`, size = 17, wrap = true,
				sizeConstraint = UDim2.new(1, 0, 0, 46),
			}), h(Ui.Text, {
				value = `{Format.compactNumber(entry.Cost)} flux · {DateTime.fromUnixTimestamp(entry.At):FormatUniversalTime("MMM D, HH:mm", "en-us")} UTC`,
				size = 13, wrap = true, color = Palette.muted, position = UDim2.fromOffset(0, 50),
				sizeConstraint = UDim2.new(1, 0, 0, 38),
			})))
		end
		if shown == 0 then
			add("history-empty", 96, h(Ui.Text, {
				value = if #history == 0 then "Your completed purchases will appear here. The last 50 orders are kept after rejoining."
					else "No purchases match that search.",
				size = 15, wrap = true, sizeConstraint = UDim2.fromScale(1, 1),
			}))
		end
		return h(PageScaffold, { hostRef = scrollRef, sections = sections, gap = 12, tailPad = 72, scrollBarColor = Palette.violet })
	end
	local optionColumns = math.max(1, math.min(3, math.floor((width + 6) / 120)))
	local optionRows = math.ceil(3 / optionColumns)
	local optionHeight = optionRows * 48 + (optionRows - 1) * 6
	add("sort", optionHeight, h(Ui.SegmentedTabs, {
		options = { { id = "Discount", label = "Best deals" }, { id = "Price", label = "Lowest price" }, { id = "Name", label = "By name" } },
		value = sort, onChange = setSort, columns = optionColumns, gap = 6, size = UDim2.fromScale(1, 1), reducedMotion = props.reducedMotion,
	}))
	add("quantity", optionHeight, h(Ui.SegmentedTabs, {
		options = { { id = "One", label = "Buy 1" }, { id = "Three", label = "Buy 3" }, { id = "Shelf", label = "Buy stock" } },
		value = amount, onChange = setAmount, columns = optionColumns, gap = 6, size = UDim2.fromScale(1, 1), reducedMotion = props.reducedMotion,
	}))
	local selected
	for _, offer in if market then market.Offers else {} do
		if offer.Id == inspected then selected = offer; break end
	end
	if selected then
		add("inspection-heading", 138, h(Ui.Panel, {
			size = UDim2.fromScale(1, 1), padding = 14, accent = Palette.violet, reducedMotion = props.reducedMotion,
		}, h(Ui.Text, {
			value = "Inspecting " .. selected.Name, size = 19, wrap = true, sizeConstraint = UDim2.new(1, 0, 0, 48),
		}), h(Ui.Button, {
			text = "Close inspection", size = UDim2.new(1, 0, 0, 48), position = UDim2.fromOffset(0, 52),
			color = Palette.panelSoft, reducedMotion = props.reducedMotion, onClick = function() setInspected(nil) end,
		})))
		local holdings = {}
		for _, entry in selected.Holdings or {} do
			table.insert(holdings, entry.Label .. ": " .. Format.compactNumber(entry.Count))
		end
		local quantity = if amount == "Three" then 3 elseif amount == "Shelf" then math.clamp(selected.Left, 1, 8) else 1
		add("inspection-detail", 198, h(Ui.Text, {
			value = Format.formatReward(selected.Reward) .. " per unit\n\n"
				.. (if #holdings > 0 then "Currently held\n" .. table.concat(holdings, "\n") else "Inventory information is loading. Refresh to check your holdings.")
				.. `\n\nOrder: {quantity} units for {Format.compactNumber(orderTotal(selected.Price, quantity))} flux`
				.. `\nPersonal limit: {selected.Left} of {selected.Stock} units remaining this hour.`,
			size = 14, wrap = true, sizeConstraint = UDim2.fromScale(1, 1),
		}))
		local identity = supplyUnit(selected.Reward)
		local comparisons = {}
		if identity then
			for _, offer in market.Offers do
				local other, units = supplyUnit(offer.Reward)
				if other == identity then
					table.insert(comparisons, { Offer = offer, Units = units, UnitPrice = orderTotal(offer.Price, 1 / units) })
				end
			end
		end
		table.sort(comparisons, function(a, b)
			local comparison = Format.compareFlux(a.UnitPrice, b.UnitPrice)
			return if comparison ~= 0 then comparison < 0 else a.Offer.Name < b.Offer.Name
		end)
		add("comparison-heading", 76, h(Ui.Text, {
			value = if #comparisons > 1 then "Same supply, compared by flux per reward unit. Sold-out offers remain listed for reference."
				else "No matching single-supply offers in this shipment. Mixed kits and different keys or boosts are not compared.",
			size = 14, wrap = true, color = Palette.muted, sizeConstraint = UDim2.fromScale(1, 1),
		}))
		for _, comparison in comparisons do
			local offer = comparison.Offer
			add("compare-" .. offer.Id, 112, h(Ui.Panel, {
				size = UDim2.fromScale(1, 1), padding = 14, accent = Palette.violet, reducedMotion = props.reducedMotion,
			}, h(Ui.Text, {
				value = offer.Name .. (if offer.Id == selected.Id then " (selected)" else ""),
				size = 16, wrap = true, sizeConstraint = UDim2.new(1, 0, 0, 44),
			}), h(Ui.Text, {
				value = `{Format.compactNumber(comparison.UnitPrice)} flux per reward unit · {comparison.Units} per pack · {offer.Left} packs left`,
				size = 13, wrap = true, color = Palette.muted, position = UDim2.fromOffset(0, 48), sizeConstraint = UDim2.new(1, 0, 0, 40),
			})))
		end
	elseif inspected then
		add("inspection-expired", 96, h(Ui.Text, {
			value = "The inspected supply is no longer in this shipment. Choose another item to inspect its current quote.",
			size = 14, wrap = true, color = Palette.muted, sizeConstraint = UDim2.fromScale(1, 1),
		}))
	end
	local offers = {}
	for _, offer in if market then market.Offers else {} do
		local text = string.lower(offer.Name .. " " .. Format.formatReward(offer.Reward))
		if (category == "All" or offer.Category == category or category == "Saved" and saved[offer.Id])
			and (query == "" or string.find(text, string.lower(query), 1, true)) then table.insert(offers, offer) end
	end
	table.sort(offers, function(a, b)
		if sort == "Price" then
			local comparison = Format.compareFlux(a.Price, b.Price)
			if comparison ~= 0 then return comparison < 0 end
		elseif sort == "Discount" and a.Discount ~= b.Discount then return a.Discount > b.Discount end
		return a.Name < b.Name
	end)
	local cardColumns = math.max(1, math.min(3, math.floor((width + 12) / 300)))
	local cardHeight, gap = 346, 12
	for first = 1, #offers, cardColumns do
		local cards = {}
		for offset = 0, cardColumns - 1 do
			local offer = offers[first + offset]
			if not offer then break end
			local quantity = if amount == "Three" then 3 elseif amount == "Shelf" then math.clamp(offer.Left, 1, 8) else 1
			local total = orderTotal(offer.Price, quantity)
			local enough = Format.gteFlux(props.state.Cash, total)
			local accent = ACCENTS[offer.Category] or Palette.violet
			cards[offer.Id] = h("frame", {
				Size = UDim2.new(1 / cardColumns, -gap * (cardColumns - 1) / cardColumns, 1, 0),
				Position = UDim2.new(offset / cardColumns, gap * offset / cardColumns, 0, 0),
				BackgroundTransparency = 1,
			}, h(Ui.Panel, {
				size = UDim2.fromScale(1, 1), padding = 14, accent = accent, background = Palette.panel,
				reducedMotion = props.reducedMotion,
			}, h(Ui.Text, { value = (if offer.Rare then "Rare find" elseif offer.Procured then "Your request" elseif offer.Featured then offer.Category .. " · merchant's pick" else offer.Category) .. "  /  " .. math.floor(offer.Discount * 100) .. "% off", size = 11, color = accent, sizeConstraint = UDim2.new(1, -64, 0, 20) }),
				h(Ui.Button, {
					text = if saved[offer.Id] then "Saved" else "Save", color = Palette.panelSoft,
					size = UDim2.fromOffset(60, 48), position = UDim2.new(1, -60, 0, 0), reducedMotion = props.reducedMotion,
					onClick = function()
						request("SetMarketFavorite", { Id = offer.Id, Saved = saved[offer.Id] ~= true })
					end,
					disabled = busy,
				}),
				h(Ui.Text, {
					value = offer.Name, size = 19, weight = Enum.FontWeight.Heavy, wrap = true,
					position = UDim2.fromOffset(0, 28), sizeConstraint = UDim2.new(1, -68, 0, 58),
				}), h(Ui.Text, {
					value = Format.formatReward(offer.Reward) .. " per unit", size = 13, color = Palette.muted, wrap = true,
					position = UDim2.fromOffset(0, 90), sizeConstraint = UDim2.new(1, 0, 0, 48),
				}), h(Ui.Text, {
					value = `{offer.Left}/{offer.Stock} left this shipment  ·  {Format.compactNumber(offer.Price)} flux each`,
					size = 12, wrap = true, color = Palette.creamSoft, position = UDim2.fromOffset(0, 144), sizeConstraint = UDim2.new(1, 0, 0, 36),
				}), h(Ui.Meter, {
					value = offer.Left / math.max(1, offer.Stock), color = accent, reducedMotion = props.reducedMotion,
					position = UDim2.fromOffset(0, 186), size = UDim2.new(1, 0, 0, 6),
				}), h(Ui.Button, {
					text = if inspected == offer.Id then "Inspecting" else "Inspect / compare",
					size = UDim2.new(1, 0, 0, 48), position = UDim2.fromOffset(0, 204), color = Palette.panelSoft,
					reducedMotion = props.reducedMotion, onClick = function() setInspected(offer.Id) end,
				}), h(Ui.Button, {
					text = if expired then "Refresh stock" elseif offer.Left == 0 then "Sold out" elseif offer.Left < quantity then "Not enough stock"
						else `Buy {quantity}  ·  {Format.compactNumber(total)} flux`,
					size = UDim2.new(1, 0, 0, 48), position = UDim2.fromOffset(0, 264), color = accent,
					disabled = busy or expired or not enough or offer.Left < quantity, reducedMotion = props.reducedMotion,
					onClick = function() request("BazaarPlay", {
						Game = "Market", Pick = offer.Id, Bucket = market.Bucket, Quantity = quantity,
						UnitPrice = offer.Price, Currency = "Flux", RequestId = game:GetService("HttpService"):GenerateGUID(false),
						Rotation = market.Rotation,
					}) end,
				})))
		end
		add("shelf-" .. first, cardHeight, h("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, cards))
	end
	if #offers == 0 and market then
		add("empty", 100, h(Ui.Text, {
			value = if category == "Saved" then "No saved supplies on this shipment. Save an item to keep it in view." else "No supplies match those filters.",
			size = 15, wrap = true, sizeConstraint = UDim2.fromScale(1, 1),
		}))
	end
	return React.createElement(PageScaffold, { hostRef = scrollRef, sections = sections, gap = 12, tailPad = 72, scrollBarColor = Palette.violet })
end
return { BazaarView = BazaarView }
end
local cache = {}
return function(name)
	if not __defs[name] then error("PagesBazaar: unknown module " .. tostring(name), 2) end
	if not cache[name] then cache[name] = __defs[name]() end
	return cache[name]
end

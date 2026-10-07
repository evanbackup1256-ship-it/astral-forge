--!strict
-- Purpose: browse and create player-to-player Bazaar listings.
-- Owner: marketplace presentation. Dependencies: GameConfig and shared UI controls.
-- Last-reviewed: 2026-10-07.

local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local GameConfig = require(game.ReplicatedStorage.AstralForge.Shared.GameConfig)
local compactNumber = require(script.Parent.Parent.CoreKit)("format").compactNumber
local theme = require(script.Parent.Parent.CoreKit)("theme")
local ui = require(script.Parent.Parent.UiCore)("ui")

local Palette = theme.Palette
local Text = ui.Text
local Button = ui.Button

local PAGE_SIZE = 6

type ItemRecord = {
	DefinitionId: string,
	Level: number?,
	Locked: boolean?,
}

type ListingRecord = {
	Id: string,
	SellerUserId: number?,
	ItemUid: string,
	Item: ItemRecord,
	Price: number | string,
	CreatedAt: number?,
	ExpiresAt: number?,
	Status: string?,
	PayoutClaimed: boolean?,
	PurchasedAt: number?,
}

type GameState = {
	Cash: number | string,
	Items: {
		Inventory: { [string]: ItemRecord },
		Equipped: { [string]: string },
	},
}

type Reply = {
	ok: boolean,
	error: string?,
	message: string?,
	Listings: { ListingRecord }?,
	Receipts: { ListingRecord }?,
	NextCursor: number?,
	Total: number?,
}

type Dispatch = (string, { [string]: any }, (Reply) -> ()) -> ()

type Props = {
	state: GameState,
	dispatch: Dispatch,
	viewportWidth: number,
}

local definitionsById: { [string]: any } = {}
for _, definition in GameConfig.Items.Definitions do
	definitionsById[definition.Id] = definition
end

local function itemName(item: ItemRecord): string
	local definition = definitionsById[item.DefinitionId]
	return if definition and type(definition.Name) == "string" then definition.Name else "Unknown relic"
end

local function itemRarity(item: ItemRecord): (string, Color3)
	local definition = definitionsById[item.DefinitionId]
	local rarity = if definition and type(definition.Rarity) == "string" then definition.Rarity else "Common"
	local rarityDefinition = GameConfig.Items.Rarities[rarity]
	return rarity,
		if rarityDefinition and typeof(rarityDefinition.Color) == "Color3"
			then rarityDefinition.Color
			else Palette.muted
end

local function displayPrice(value: number | string): string
	local formatted = tostring(value)
	if string.match(formatted, "^%d+$") == nil then
		return "0"
	end
	formatted = string.gsub(formatted, "^0+", "")
	if formatted == "" then
		formatted = "0"
	end
	local reversed = string.reverse(formatted)
	local grouped = string.gsub(reversed, "(%d%d%d)", "%1,")
	grouped = string.reverse(grouped)
	if string.sub(grouped, 1, 1) == "," then
		grouped = string.sub(grouped, 2)
	end
	return grouped
end

local function textBox(value: string, placeholder: string, onChanged: (string) -> (), width: UDim2, position: UDim2?)
	return React.createElement("textbox", {
		Size = width,
		Position = position or UDim2.new(),
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.GothamMedium,
		PlaceholderColor3 = Palette.muted,
		PlaceholderText = placeholder,
		Text = value,
		TextColor3 = Palette.cream,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextEditable = true,
		Change = { Text = onChanged },
	}, {
		Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }),
		Padding = React.createElement("uipadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
	})
end

local function ListingCard(props)
	local listing: ListingRecord = props.listing
	local name = itemName(listing.Item)
	local rarity, rarityColor = itemRarity(listing.Item)
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 82),
		Position = props.position,
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
		LayoutOrder = props.order,
	}, {
		Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 12) }),
		Stroke = React.createElement("uistroke", { Color = rarityColor, Transparency = 0.35, Thickness = 1 }),
		Name = React.createElement(Text, {
			value = name,
			size = 15,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			position = UDim2.fromOffset(14, 10),
			sizeConstraint = UDim2.new(1, -160, 0, 21),
		}),
		Details = React.createElement(Text, {
			value = props.details
				or `{rarity} · Level {listing.Item.Level or 1} · seller {listing.SellerUserId or "Unknown"}`,
			size = 11,
			color = rarityColor,
			position = UDim2.fromOffset(14, 36),
			sizeConstraint = UDim2.new(1, -160, 0, 16),
		}),
		Price = React.createElement(Text, {
			value = `{displayPrice(listing.Price)} FLUX`,
			size = 12,
			color = Palette.mint,
			weight = Enum.FontWeight.Bold,
			position = UDim2.fromOffset(14, 57),
			sizeConstraint = UDim2.new(1, -160, 0, 16),
		}),
		Action = React.createElement(Button, {
			text = props.busy and "PLEASE WAIT" or props.actionText or "BUY",
			onClick = props.onAction,
			size = UDim2.fromOffset(104, 46),
			position = UDim2.new(1, -116, 0, 18),
			color = Palette.mint,
			textColor = Palette.ink,
			disabled = props.busy or props.actionDisabled,
			highlight = not props.busy,
		}),
	})
end

local function InventoryCard(props)
	local item: ItemRecord = props.item
	local rarity, rarityColor = itemRarity(item)
	local selected = props.selected == props.uid
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 58),
		Position = props.position,
		BackgroundColor3 = if selected then Palette.panelRaised else Palette.panelSoft,
		BorderSizePixel = 0,
		LayoutOrder = props.order,
	}, {
		Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = React.createElement("uistroke", {
			Color = if selected then Palette.violet else rarityColor,
			Thickness = if selected then 2 else 1,
			Transparency = 0.3,
		}),
		Name = React.createElement(Text, {
			value = `{itemName(item)} · {rarity} · Lv {item.Level or 1}`,
			size = 12,
			color = Palette.cream,
			position = UDim2.fromOffset(12, 8),
			sizeConstraint = UDim2.new(1, -120, 0, 18),
		}),
		Status = React.createElement(Text, {
			value = if props.blocked then "Locked or equipped" else "Ready to list",
			size = 10,
			color = if props.blocked then Palette.muted else Palette.mint,
			position = UDim2.fromOffset(12, 31),
			sizeConstraint = UDim2.new(1, -120, 0, 15),
		}),
		Choose = React.createElement(Button, {
			text = if selected then "SELECTED" else "SELECT",
			onClick = props.onSelect,
			size = UDim2.fromOffset(92, 38),
			position = UDim2.new(1, -102, 0, 10),
			color = if selected then Palette.violet else Palette.panelRaised,
			textColor = Palette.cream,
			disabled = props.blocked or props.busy,
		}),
	})
end

local function BazaarListings(props: Props)
	local viewportWidth = props.viewportWidth
	local compact = viewportWidth < 650
	local rowGap = compact and 8 or 10
	local tab, setTab = React.useState("Browse")
	local listings, setListings = React.useState({} :: { ListingRecord })
	local myListings, setMyListings = React.useState({} :: { ListingRecord })
	local purchaseHistory, setPurchaseHistory = React.useState({} :: { ListingRecord })
	local myCursor, setMyCursor = React.useState(0)
	local myNextCursor, setMyNextCursor = React.useState(nil :: number?)
	local myTotal, setMyTotal = React.useState(0)
	local purchaseCursor, setPurchaseCursor = React.useState(0)
	local purchaseNextCursor, setPurchaseNextCursor = React.useState(nil :: number?)
	local purchaseTotal, setPurchaseTotal = React.useState(0)
	local loading, setLoading = React.useState(false)
	local loadingMine, setLoadingMine = React.useState(false)
	local loadingPurchases, setLoadingPurchases = React.useState(false)
	local busy, setBusy = React.useState(false)
	local message, setMessage = React.useState("Browse current offers or list one eligible relic from your inventory.")
	local messageGood, setMessageGood = React.useState(true :: boolean?)
	local query, setQuery = React.useState("")
	local sort, setSort = React.useState("Newest")
	local page, setPage = React.useState(1)
	local sellQuery, setSellQuery = React.useState("")
	local sellPage, setSellPage = React.useState(1)
	local selectedUid, setSelectedUid = React.useState("")
	local price, setPrice = React.useState("")
	local pendingPurchase, setPendingPurchase = React.useState(nil :: ListingRecord?)
	local mounted = React.useRef(true)
	local requestGeneration = React.useRef(0)
	local mineGeneration = React.useRef(0)
	local purchaseGeneration = React.useRef(0)
	local busyRef = React.useRef(false)

	local function loadListings()
		if busyRef.current or loading then
			return
		end
		requestGeneration.current += 1
		local generation = requestGeneration.current
		setLoading(true)
		props.dispatch("GetBazaarListings", {}, function(response)
			if not mounted.current or generation ~= requestGeneration.current then
				return
			end
			setLoading(false)
			if response.ok then
				setListings(response.Listings or {})
				setMessage(response.message or "Listings are up to date.")
				setMessageGood(true)
			else
				setMessage(response.error or "Listings could not load. Try again.")
				setMessageGood(false)
			end
		end)
	end

	local function loadMine(cursor: number?)
		if busyRef.current or loadingMine then
			return
		end
		local requestedCursor = math.clamp(math.floor(cursor or 0), 0, 150)
		mineGeneration.current += 1
		local generation = mineGeneration.current
		setLoadingMine(true)
		props.dispatch("GetMyBazaarListings", { Cursor = requestedCursor }, function(response)
			if not mounted.current or generation ~= mineGeneration.current then
				return
			end
			setLoadingMine(false)
			if response.ok then
				setMyListings(response.Listings or {})
				setMyCursor(requestedCursor)
				setMyNextCursor(response.NextCursor)
				setMyTotal(response.Total or 0)
				setMessage(response.message or "Your listings are up to date.")
				setMessageGood(true)
			else
				setMessage(response.error or "Your listings could not load. Try again.")
				setMessageGood(false)
			end
		end)
	end

	local function loadPurchases(cursor: number?)
		if busyRef.current or loadingPurchases then
			return
		end
		local requestedCursor = math.clamp(math.floor(cursor or 0), 0, 100)
		purchaseGeneration.current += 1
		local generation = purchaseGeneration.current
		setLoadingPurchases(true)
		props.dispatch("GetMyBazaarPurchases", { Cursor = requestedCursor }, function(response)
			if not mounted.current or generation ~= purchaseGeneration.current then
				return
			end
			setLoadingPurchases(false)
			if response.ok then
				setPurchaseHistory(response.Receipts or {})
				setPurchaseCursor(requestedCursor)
				setPurchaseNextCursor(response.NextCursor)
				setPurchaseTotal(response.Total or 0)
				setMessage(response.message or "Your purchase history is up to date.")
				setMessageGood(true)
			else
				setMessage(response.error or "Your purchase history could not load. Try again.")
				setMessageGood(false)
			end
		end)
	end

	local function openTab(nextTab: string)
		setTab(nextTab)
		if nextTab == "My Listings" then
			loadMine(0)
		elseif nextTab == "Purchase History" then
			loadPurchases(0)
		elseif nextTab == "Browse" then
			loadListings()
		end
	end

	React.useEffect(function()
		mounted.current = true
		loadListings()
		return function()
			mounted.current = false
			requestGeneration.current += 1
			purchaseGeneration.current += 1
		end
	end, {})

	local function perform(action: string, payload: { [string]: any }, successText: string, onSettled: ((Reply) -> ())?)
		if busyRef.current then
			return
		end
		busyRef.current = true
		setBusy(true)
		props.dispatch(action, payload, function(response)
			if not mounted.current then
				return
			end
			busyRef.current = false
			setBusy(false)
			if response.ok then
				setMessage(response.message or successText)
				setMessageGood(true)
				if action == "CreateBazaarListing" then
					setTab("My Listings")
					loadMine(0)
				elseif action == "CancelBazaarListing" or action == "ClaimBazaarPayout" then
					loadMine(myCursor)
					loadListings()
				elseif action == "PurchaseBazaarListing" then
					loadListings()
					loadPurchases(0)
				else
					loadListings()
				end
			else
				setMessage(response.error or "That request did not go through. Refresh and try again.")
				setMessageGood(false)
			end
			if onSettled then
				onSettled(response)
			end
		end)
	end

	local sourceListings = if tab == "My Listings"
		then myListings
		elseif tab == "Purchase History" then purchaseHistory
		else listings
	local filteredListings = {}
	local loweredQuery = string.lower(query)
	for _, listing in sourceListings do
		local matches = loweredQuery == ""
			or string.find(string.lower(itemName(listing.Item)), loweredQuery, 1, true) ~= nil
			or string.find(tostring(listing.SellerUserId), loweredQuery, 1, true) ~= nil
		if matches then
			table.insert(filteredListings, listing)
		end
	end
	if sort == "Lowest price" then
		table.sort(filteredListings, function(left, right)
			local leftPrice = string.gsub(tostring(left.Price), "^0+", "")
			local rightPrice = string.gsub(tostring(right.Price), "^0+", "")
			if #leftPrice ~= #rightPrice then
				return #leftPrice < #rightPrice
			end
			return leftPrice < rightPrice
		end)
	else
		table.sort(filteredListings, function(left, right)
			local leftTime = left.PurchasedAt or left.CreatedAt or 0
			local rightTime = right.PurchasedAt or right.CreatedAt or 0
			if leftTime ~= rightTime then
				return leftTime > rightTime
			end
			return left.Id < right.Id
		end)
	end
	local isServerPaged = tab == "My Listings" or tab == "Purchase History"
	local serverTotal = if tab == "My Listings" then myTotal else purchaseTotal
	local serverCursor = if tab == "My Listings" then myCursor else purchaseCursor
	local pageCount = if isServerPaged
		then math.max(1, math.ceil(serverTotal / PAGE_SIZE))
		else math.max(1, math.ceil(#filteredListings / PAGE_SIZE))
	local safePage = if isServerPaged then math.floor(serverCursor / PAGE_SIZE) + 1 else math.clamp(page, 1, pageCount)
	local visibleListings = {}
	if isServerPaged then
		visibleListings = filteredListings
	else
		for index = (safePage - 1) * PAGE_SIZE + 1, math.min(safePage * PAGE_SIZE, #filteredListings) do
			visibleListings[#visibleListings + 1] = filteredListings[index]
		end
	end

	local equipped = {}
	for _, uid in props.state.Items.Equipped do
		equipped[uid] = true
	end
	local inventory = {}
	local loweredSellQuery = string.lower(sellQuery)
	for uid, item in props.state.Items.Inventory do
		local matches = loweredSellQuery == ""
			or string.find(string.lower(itemName(item)), loweredSellQuery, 1, true) ~= nil
		if matches then
			table.insert(inventory, { Uid = uid, Item = item })
		end
	end
	table.sort(inventory, function(left, right)
		return itemName(left.Item) < itemName(right.Item)
	end)
	local sellPageCount = math.max(1, math.ceil(#inventory / PAGE_SIZE))
	local safeSellPage = math.clamp(sellPage, 1, sellPageCount)
	local visibleInventory = {}
	for index = (safeSellPage - 1) * PAGE_SIZE + 1, math.min(safeSellPage * PAGE_SIZE, #inventory) do
		visibleInventory[#visibleInventory + 1] = inventory[index]
	end
	local selectedItem = props.state.Items.Inventory[selectedUid]
	local selectedEligible = selectedItem ~= nil and selectedItem.Locked ~= true and equipped[selectedUid] ~= true

	local children = {
		Header = React.createElement(Text, {
			value = "PLAYER MARKET",
			size = 12,
			color = Palette.violet,
			weight = Enum.FontWeight.Heavy,
			sizeConstraint = UDim2.new(1, 0, 0, 18),
		}),
		Description = React.createElement(Text, {
			value = "Relics move between players. Flux and items stay in server-checked escrow until settlement.",
			size = 11,
			color = Palette.muted,
			position = UDim2.fromOffset(0, 22),
			sizeConstraint = UDim2.new(1, 0, 0, 30),
		}),
		Message = React.createElement(Text, {
			value = message,
			size = 11,
			color = if messageGood == true then Palette.mint else Palette.coral,
			position = UDim2.fromOffset(0, 52),
			sizeConstraint = UDim2.new(1, 0, 0, 28),
		}),
		Tabs = React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 38),
			Position = UDim2.fromOffset(0, 84),
			BackgroundTransparency = 1,
		}, {
			Browse = React.createElement(Button, {
				text = if compact then "MARKET" else "BROWSE",
				onClick = function()
					openTab("Browse")
				end,
				size = UDim2.new(0.25, -4, 1, 0),
				color = if tab == "Browse" then Palette.violet else Palette.panelSoft,
				textColor = if tab == "Browse" then Palette.ink else Palette.cream,
			}),
			Sell = React.createElement(Button, {
				text = "SELL",
				onClick = function()
					setTab("Sell")
				end,
				size = UDim2.new(0.25, -4, 1, 0),
				position = UDim2.new(0.25, 0, 0, 0),
				color = if tab == "Sell" then Palette.violet else Palette.panelSoft,
				textColor = if tab == "Sell" then Palette.ink else Palette.cream,
			}),
			MyListings = React.createElement(Button, {
				text = if compact then "MINE" else "LISTED",
				onClick = function()
					openTab("My Listings")
				end,
				size = UDim2.new(0.25, -4, 1, 0),
				position = UDim2.new(0.5, 0, 0, 0),
				color = if tab == "My Listings" then Palette.violet else Palette.panelSoft,
				textColor = if tab == "My Listings" then Palette.ink else Palette.cream,
			}),
			PurchaseHistory = React.createElement(Button, {
				text = "BOUGHT",
				onClick = function()
					openTab("Purchase History")
				end,
				size = UDim2.new(0.25, -4, 1, 0),
				position = UDim2.new(0.75, 0, 0, 0),
				color = if tab == "Purchase History" then Palette.violet else Palette.panelSoft,
				textColor = if tab == "Purchase History" then Palette.ink else Palette.cream,
			}),
		}),
	}

	if tab == "Browse" or tab == "My Listings" or tab == "Purchase History" then
		local isMine = tab == "My Listings"
		local isHistory = tab == "Purchase History"
		children.Refresh = React.createElement(Button, {
			text = if isMine and loadingMine
				then "LOADING LISTINGS"
				elseif isHistory and loadingPurchases then "LOADING RECEIPTS"
				elseif loading then "LOADING MARKET"
				elseif isMine then "REFRESH MY LISTINGS"
				elseif isHistory then "REFRESH PURCHASES"
				else "REFRESH MARKET",
			onClick = if tab == "My Listings"
				then function()
					loadMine(myCursor)
				end
				elseif isHistory then function()
					loadPurchases(purchaseCursor)
				end
				else loadListings,
			size = UDim2.fromOffset(178, 38),
			position = UDim2.new(1, -178, 0, 174),
			color = Palette.panelSoft,
			disabled = loading or loadingMine or loadingPurchases or busy,
		})
		children.Search = textBox(
			query,
			if isMine
				then "Search your listings"
				elseif isHistory then "Search bought relics or seller ID"
				else "Search relics or seller ID",
			function(value)
				setQuery(value)
				setPage(1)
			end,
			UDim2.new(1, -164, 0, 38),
			UDim2.fromOffset(0, 128)
		)
		children.SortPrice = React.createElement(Button, {
			text = if sort == "Lowest price" then "PRICE ↑" else "NEWEST",
			onClick = function()
				setSort(if sort == "Newest" then "Lowest price" else "Newest")
				setPage(1)
			end,
			size = UDim2.fromOffset(154, 38),
			position = UDim2.new(1, -154, 0, 128),
			color = Palette.panelSoft,
		})
		local rowChildren = {}
		local emptyMessage = if isMine
			then if loadingMine
				then "Loading your listings…"
				elseif myTotal == 0 then "You have no listings yet. List a relic to see it here."
				else "No matching listings on this page. Clear the search to see them."
			elseif isHistory then if loadingPurchases
				then "Loading your receipts…"
				elseif purchaseTotal == 0 then "Completed player-market purchases will appear here."
				else "No matching receipts on this page. Clear the search to see them."
			else if loading
				then "Loading the public listings…"
				else "No matching listings yet. Check back later."
		if #visibleListings == 0 then
			rowChildren.Empty = React.createElement(Text, {
				value = emptyMessage,
				size = 13,
				color = Palette.muted,
				position = UDim2.fromOffset(0, 220),
				sizeConstraint = UDim2.new(1, 0, 0, 26),
			})
		end
		for index, listing in visibleListings do
			local status = listing.Status or "Active"
			local canCancel = isMine and (status == "Active" or status == "Escrowed")
			local canClaim = isMine and status == "Sold" and listing.PayoutClaimed ~= true
			local actionText = if tab == "Browse"
				then "BUY"
				elseif isHistory then "PURCHASED"
				elseif canCancel then "CANCEL"
				elseif canClaim then "CLAIM FLUX"
				elseif status == "Sold" then "PAID"
				elseif status == "Cancelled" then "CANCELLED"
				elseif status == "Expired" then "EXPIRED"
				else status:upper()
			rowChildren[`listing_{listing.Id}`] = React.createElement(ListingCard, {
				listing = listing,
				details = if isMine
					then `{status} · Level {listing.Item.Level or 1}`
					elseif
						isHistory
					then `Bought {os.date("%Y-%m-%d", listing.PurchasedAt or 0)} · seller {listing.SellerUserId or "Unknown"}`
					else nil,
				order = index,
				position = UDim2.fromOffset(0, 220 + (index - 1) * (82 + rowGap)),
				busy = busy,
				actionText = actionText,
				onAction = function()
					if tab == "Browse" then
						setPendingPurchase(listing)
					elseif canCancel then
						perform("CancelBazaarListing", { Id = listing.Id }, "Your relic is back in your inventory.")
					elseif canClaim then
						perform("ClaimBazaarPayout", { Id = listing.Id }, "Sale proceeds added to your Flux balance.")
					end
				end,
				actionDisabled = tab ~= "Browse",
			})
		end
		for key, child in rowChildren do
			children[key] = child
		end
		children.Paging = React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 40),
			Position = UDim2.new(0, 0, 0, 220 + math.min(PAGE_SIZE, #visibleListings) * (82 + rowGap)),
			BackgroundTransparency = 1,
		}, {
			Count = React.createElement(Text, {
				value = if isMine
					then `{math.min(myCursor + 1, myTotal)}–{math.min(myCursor + #myListings, myTotal)} of {myTotal} listings`
					elseif isHistory then `{math.min(purchaseCursor + 1, purchaseTotal)}–{math.min(
						purchaseCursor + #purchaseHistory,
						purchaseTotal
					)} of {purchaseTotal} purchases`
					else `Page {safePage}/{pageCount} · {#filteredListings} listings`,
				size = 11,
				color = Palette.muted,
				sizeConstraint = UDim2.new(0.55, 0, 1, 0),
			}),
			Previous = React.createElement(Button, {
				text = "PREVIOUS",
				onClick = function()
					if isMine then
						loadMine(math.max(0, myCursor - PAGE_SIZE))
					elseif isHistory then
						loadPurchases(math.max(0, purchaseCursor - PAGE_SIZE))
					else
						setPage(math.max(1, safePage - 1))
					end
				end,
				size = UDim2.fromOffset(96, 34),
				position = UDim2.new(1, -202, 0, 2),
				disabled = if isMine
					then myCursor <= 0 or loadingMine
					elseif isHistory then purchaseCursor <= 0 or loadingPurchases
					else safePage <= 1,
			}),
			Next = React.createElement(Button, {
				text = "NEXT",
				onClick = function()
					if isMine then
						if myNextCursor ~= nil then
							loadMine(myNextCursor)
						end
					elseif isHistory then
						if purchaseNextCursor ~= nil then
							loadPurchases(purchaseNextCursor)
						end
					else
						setPage(math.min(pageCount, safePage + 1))
					end
				end,
				size = UDim2.fromOffset(96, 34),
				position = UDim2.new(1, -96, 0, 2),
				disabled = if isMine
					then myNextCursor == nil or loadingMine
					elseif isHistory then purchaseNextCursor == nil or loadingPurchases
					else safePage >= pageCount,
			}),
		})
	elseif tab == "Sell" then
		children.Refresh = nil
		children.SellSearch = textBox(sellQuery, "Find a relic in your inventory", function(value)
			setSellQuery(value)
			setSellPage(1)
		end, UDim2.new(1, 0, 0, 38), UDim2.fromOffset(0, 128))
		children.PriceLabel = React.createElement(Text, {
			value = "ASKING PRICE · WHOLE FLUX AMOUNT",
			size = 10,
			color = Palette.violet,
			weight = Enum.FontWeight.Heavy,
			position = UDim2.fromOffset(0, 174),
			sizeConstraint = UDim2.new(1, 0, 0, 15),
		})
		children.Price = textBox(price, "Example: 25000", setPrice, UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, 194))
		local priceIsValid = #price > 0
			and #price <= 80
			and string.match(price, "^%d+$") ~= nil
			and string.match(price, "^0+$") == nil
		local inventoryRows = {}
		for index, entry in visibleInventory do
			local blocked = entry.Item.Locked == true or equipped[entry.Uid] == true
			inventoryRows[`inventory_{entry.Uid}`] = React.createElement(InventoryCard, {
				uid = entry.Uid,
				item = entry.Item,
				selected = selectedUid,
				blocked = blocked,
				busy = busy,
				order = index,
				position = UDim2.fromOffset(0, 242 + (index - 1) * 66),
				onSelect = function()
					setSelectedUid(entry.Uid)
				end,
			})
		end
		for key, child in inventoryRows do
			children[key] = child
		end
		children.InventoryCount = React.createElement(Text, {
			value = `Inventory · {#inventory} items · page {safeSellPage}/{sellPageCount}`,
			size = 11,
			color = Palette.muted,
			position = UDim2.fromOffset(0, 238),
			sizeConstraint = UDim2.new(1, 0, 0, 18),
		})
		children.SellPaging = React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 38),
			Position = UDim2.fromOffset(0, 242 + math.min(PAGE_SIZE, #visibleInventory) * 66),
			BackgroundTransparency = 1,
		}, {
			Previous = React.createElement(Button, {
				text = "PREVIOUS",
				onClick = function()
					setSellPage(math.max(1, safeSellPage - 1))
				end,
				size = UDim2.fromOffset(96, 34),
				disabled = safeSellPage <= 1,
			}),
			Next = React.createElement(Button, {
				text = "NEXT",
				onClick = function()
					setSellPage(math.min(sellPageCount, safeSellPage + 1))
				end,
				size = UDim2.fromOffset(96, 34),
				position = UDim2.new(1, -96, 0, 0),
				disabled = safeSellPage >= sellPageCount,
			}),
		})
		local inventoryEnd = 242 + math.min(PAGE_SIZE, #visibleInventory) * 66
		local sellButtonTop = inventoryEnd + 44
		children.Sell = React.createElement(Button, {
			text = busy and "SECURING ITEM" or "LIST RELIC IN ESCROW",
			onClick = function()
				if not selectedUid or selectedUid == "" or not priceIsValid then
					setMessage("Choose an eligible relic and enter a whole-number price above zero.")
					setMessageGood(false)
					return
				end
				perform("CreateBazaarListing", { Uid = selectedUid, Price = price }, "The relic is listed.")
			end,
			size = UDim2.new(1, 0, 0, 46),
			position = UDim2.new(0, 0, 0, sellButtonTop),
			color = Palette.violet,
			textColor = Palette.ink,
			disabled = busy or not selectedEligible or not priceIsValid,
			highlight = not busy and selectedEligible and priceIsValid,
		})
		children.FeeNote = React.createElement(Text, {
			value = if priceIsValid
				then `No listing fee. The seller receives {displayPrice(price)} FLUX after a completed sale. The server checks item ownership and eligibility.`
				else "No listing fee. The seller receives the listed amount after a completed sale. The server checks item ownership and eligibility.",
			size = 10,
			color = Palette.muted,
			position = UDim2.new(0, 0, 0, sellButtonTop + 52),
			sizeConstraint = UDim2.new(1, 0, 0, 32),
		})
	end

	if pendingPurchase then
		local pendingRarity, pendingRarityColor = itemRarity(pendingPurchase.Item)
		children.PurchaseConfirmation = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Palette.ink,
			BackgroundTransparency = 0.28,
			BorderSizePixel = 0,
			Active = true,
			ZIndex = 20,
		}, {
			Card = React.createElement("frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(if compact then 0.96 else 0.68, 0, 0, 310),
				BackgroundColor3 = Palette.panelRaised,
				BorderSizePixel = 0,
				ZIndex = 21,
			}, {
				Corner = React.createElement("uicorner", { CornerRadius = UDim.new(0, 18) }),
				Stroke = React.createElement("uistroke", {
					Color = pendingRarityColor,
					Thickness = 2,
					Transparency = 0.18,
				}),
				Title = React.createElement(Text, {
					value = if compact then "CONFIRM PURCHASE" else "CONFIRM PLAYER MARKET PURCHASE",
					size = 13,
					color = Palette.violet,
					weight = Enum.FontWeight.Heavy,
					position = UDim2.fromOffset(16, 20),
					sizeConstraint = UDim2.new(1, -32, 0, 22),
					zIndex = 22,
				}),
				Item = React.createElement(Text, {
					value = itemName(pendingPurchase.Item),
					size = 20,
					color = Palette.cream,
					weight = Enum.FontWeight.Heavy,
					position = UDim2.fromOffset(16, 56),
					sizeConstraint = UDim2.new(1, -32, 0, 28),
					zIndex = 22,
				}),
				Details = React.createElement(Text, {
					value = `{pendingRarity} · Level {pendingPurchase.Item.Level or 1} · player {pendingPurchase.SellerUserId or "Unknown"}`,
					size = 12,
					color = pendingRarityColor,
					position = UDim2.fromOffset(16, 91),
					sizeConstraint = UDim2.new(1, -32, 0, 20),
					zIndex = 22,
				}),
				Cost = React.createElement(Text, {
					value = `Cost: {displayPrice(pendingPurchase.Price)} FLUX  ·  Balance: {compactNumber(
						props.state.Cash
					)}`,
					size = 13,
					color = Palette.mint,
					weight = Enum.FontWeight.Bold,
					position = UDim2.fromOffset(16, 126),
					sizeConstraint = UDim2.new(1, -32, 0, 48),
					wrap = true,
					zIndex = 22,
				}),
				Disclosure = React.createElement(Text, {
					value = "The server rechecks the listing and your balance before charging. Purchases cannot be undone once delivered.",
					size = 11,
					color = Palette.muted,
					position = UDim2.fromOffset(16, 180),
					sizeConstraint = UDim2.new(1, -32, 0, 48),
					wrap = true,
					zIndex = 22,
				}),
				Cancel = React.createElement(Button, {
					text = "GO BACK",
					onClick = function()
						setPendingPurchase(nil)
					end,
					size = UDim2.new(0.46, 0, 0, 44),
					position = UDim2.new(0.03, 0, 1, -60),
					color = Palette.panelSoft,
					textColor = Palette.cream,
					zIndex = 22,
				}),
				Confirm = React.createElement(Button, {
					text = if busy then "PURCHASING" else "CONFIRM BUY",
					onClick = function()
						perform("PurchaseBazaarListing", { Id = pendingPurchase.Id }, "Purchase complete.", function()
							setPendingPurchase(nil)
						end)
					end,
					size = UDim2.new(0.46, 0, 0, 44),
					position = UDim2.new(0.51, 0, 1, -60),
					color = Palette.mint,
					textColor = Palette.ink,
					disabled = busy,
					highlight = not busy,
					zIndex = 22,
				}),
			}),
		})
	end

	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, children)
end

return table.freeze({ BazaarListings = BazaarListings })

--!strict
-- Purpose: persist player listings and protect item escrow across profile/store boundaries.
-- Owner: bazaar.
-- Dependencies: DataService, StoreAccess, BazaarMath, BazaarListingMath, HttpService.
-- Last-reviewed: 2026-10-07.

local StoreAccess = require(script.Parent.Parent.Modules.StoreAccess)
local ServerConfig = require(script.Parent.Parent.ServerConfig)
local BazaarMath = require(script.Parent.Parent.Modules.BazaarMath)
local BazaarListingMath = require(script.Parent.Parent.Modules.BazaarListingMath)
local TradeOfferMath = require(script.Parent.Parent.Modules.TradeSuite)("TradeOfferMath")
local Economy = require(script.Parent.Parent.Modules.EconomyMath)("Economy")
local ProfileBagMath = require(script.Parent.Parent.Modules.ProfileBagMath)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedRoot = ReplicatedStorage:WaitForChild("AstralForge", 10)
assert(SharedRoot, "BazaarListingService: shared package did not replicate")
local SharedModules = SharedRoot:WaitForChild("Shared", 10)
assert(SharedModules, "BazaarListingService: shared modules did not replicate")
local GameConfigModule = SharedModules:WaitForChild("GameConfig", 10)
assert(GameConfigModule, "BazaarListingService: GameConfig did not replicate")
local GameConfig = require(GameConfigModule)
local itemDefinitionById = {}
for _, definition in GameConfig.Items.Definitions do
	itemDefinitionById[definition.Id] = definition
end

export type Reply = { ok: boolean, message: string?, error: string?, [string]: any }
export type Transform = (any) -> Reply
export type Context = {
	mutate: (Player, Transform) -> Reply,
	get: (Player) -> any?,
	save: (Player) -> boolean,
	newId: () -> string,
	log: (string, number, string) -> (),
}

local MAX_SELLER_LISTINGS = 50
local MAX_SELLER_HISTORY = 100
local MAX_SELLER_CURSOR = MAX_SELLER_LISTINGS + MAX_SELLER_HISTORY
local LIST_PAGE_SIZE = 20
local MY_LIST_PAGE_SIZE = 6
local MAX_PRICE_DIGITS = 80
local LIFETIME_SECONDS = 7 * 86400

return function(context: Context)
	local listingStore = StoreAccess.data(ServerConfig.BazaarListingStoreName)
	local indexStore = StoreAccess.ordered(ServerConfig.BazaarListingIndexStoreName)
	local Marketplace = {}

	local function responseError(message: string): Reply
		return { ok = false, error = message }
	end

	local function responseSuccess(message: string, extra: { [string]: any }?): Reply
		local result: { [string]: any } = extra or {}
		result.ok = true
		result.message = message
		return result :: Reply
	end

	local function keyFor(id: string): string
		return "L_" .. id
	end

	local function readListing(id: string): any?
		local ok, value = pcall(function()
			return listingStore:GetAsync(keyFor(id))
		end)
		if not ok then
			return nil
		end
		return BazaarListingMath.Normalize(value)
	end

	local function writeListing(id: string, transform: (any?) -> any?): (boolean, any?)
		local ok, value = pcall(function()
			return listingStore:UpdateAsync(keyFor(id), function(previous)
				return transform(previous)
			end)
		end)
		if not ok then
			return false, nil
		end
		return true, BazaarListingMath.Normalize(value)
	end

	local function setStatus(id: string, expected: string, nextStatus: string, now: number): (boolean, any?)
		return writeListing(id, function(previous)
			local current = BazaarListingMath.Normalize(previous)
			if current == nil or current.Status ~= expected then
				return current
			end
			local nextListing = table.clone(current)
			nextListing.Status = nextStatus
			nextListing.Revision += 1
			if nextStatus == "Cancelled" then
				nextListing.LeaseToken = nil
				nextListing.LeaseUntil = nil
			end
			if nextStatus == "Active" then
				nextListing.CreatedAt = math.max(1, nextListing.CreatedAt)
				nextListing.ExpiresAt = math.min(nextListing.ExpiresAt, now + LIFETIME_SECONDS)
			end
			return nextListing
		end)
	end

	local function reserveForBuyer(id: string, buyerId: number, token: string, now: number): (any?, string)
		local current = readListing(id)
		if current == nil then
			return nil, "That listing could not be found."
		end
		if current.Status == "Sold" then
			if current.BuyerUserId == buyerId then
				return current, ""
			end
			return nil, "That listing has already sold."
		end
		if current.Status == "Reserved" and current.BuyerUserId == buyerId then
			return current, ""
		end
		if current.Status == "Reserved" and current.PaymentIntent then
			return nil, "A purchase is being recovered for this listing."
		end
		if current.Status == "Reserved" and current.LeaseUntil ~= nil and current.LeaseUntil <= now then
			local released, _ = writeListing(id, function(previous)
				local latest = BazaarListingMath.Normalize(previous)
				if
					latest == nil
					or latest.Status ~= "Reserved"
					or latest.Revision ~= current.Revision
					or latest.PaymentIntent
				then
					return latest
				end
				return BazaarListingMath.ReleaseExpired(latest, now)
			end)
			if not released then
				return nil, "The listing changed; refresh and retry."
			end
			current = readListing(id)
		end
		if current == nil then
			return nil, "That listing could not be found."
		end
		if current.Status ~= "Active" then
			return nil,
				if current.Status == "Cancelled"
					then "That listing was cancelled."
					else "That listing is already being purchased."
		end
		local proposed, problem = BazaarListingMath.Reserve(current, buyerId, token, now, 90)
		if proposed == nil then
			return nil, problem
		end
		local wrote, result = writeListing(id, function(previous)
			local latest = BazaarListingMath.Normalize(previous)
			if latest == nil or latest.Status ~= "Active" or latest.Revision ~= current.Revision then
				return latest
			end
			return proposed
		end)
		if not wrote or result == nil or result.Status ~= "Reserved" or result.BuyerUserId ~= buyerId then
			return nil, "That listing changed. Refresh and try again."
		end
		return result, ""
	end

	local function beginPaymentIntent(id: string, buyerId: number, token: string): (boolean, any?)
		return writeListing(id, function(previous)
			local current = BazaarListingMath.Normalize(previous)
			if
				current == nil
				or current.Status ~= "Reserved"
				or current.BuyerUserId ~= buyerId
				or current.LeaseToken ~= token
			then
				return current
			end
			if current.PaymentIntent then
				return current
			end
			local nextListing = table.clone(current)
			nextListing.PaymentIntent = true
			nextListing.Revision += 1
			return nextListing
		end)
	end

	local function releaseBuyerReservation(id: string, buyerId: number, token: string, now: number): boolean
		local wrote, result = writeListing(id, function(previous)
			local current = BazaarListingMath.Normalize(previous)
			if
				current == nil
				or current.Status ~= "Reserved"
				or current.BuyerUserId ~= buyerId
				or current.LeaseToken ~= token
			then
				return current
			end
			local nextListing = table.clone(current)
			nextListing.Status = "Active"
			nextListing.Revision += 1
			nextListing.BuyerUserId = nil
			nextListing.LeaseToken = nil
			nextListing.LeaseUntil = nil
			nextListing.PaymentIntent = false
			return nextListing
		end)
		return wrote and result ~= nil and (result.Status == "Active" or result.BuyerUserId == buyerId)
	end

	local function settlePayment(id: string, buyerId: number, token: string, now: number): (boolean, any?)
		return writeListing(id, function(previous)
			local current = BazaarListingMath.Normalize(previous)
			if current == nil then
				return nil
			end
			if current.Status == "Sold" and current.BuyerUserId == buyerId then
				return current
			end
			if current.Status ~= "Reserved" or current.BuyerUserId ~= buyerId or current.LeaseToken ~= token then
				return current
			end
			local sold = BazaarListingMath.Settle(current, buyerId, token, now)
			return sold
		end)
	end

	local function deliverPurchase(player: Player, listing: any, token: string): Reply
		local result = context.mutate(player, function(profile)
			profile.Bazaar = BazaarMath.Ensure(profile.Bazaar)
			local bazaar = profile.Bazaar
			if bazaar.CompletedPurchases[listing.Id] == true then
				return responseSuccess("That item was already delivered.", { ListingId = listing.Id })
			end
			local pending = bazaar.PendingPurchases[listing.Id]
			if pending == nil or pending.Token ~= token then
				return responseError("The saved purchase record is missing. Contact support before retrying.")
			end
			local definition = itemDefinitionById[listing.Item.DefinitionId]
			if definition == nil then
				return responseError("The item definition is unavailable; the purchase is safely held.")
			end
			local items = ProfileBagMath.EnsureItems(profile)
			local inventoryCount = 0
			for _ in items.Inventory do
				inventoryCount += 1
			end
			if inventoryCount >= GameConfig.Items.InventoryLimit then
				return responseError("Free one inventory slot to receive this purchase.")
			end
			local uid
			repeat
				uid = string.format("IT%07d", items.NextId)
				items.NextId += 1
			until items.Inventory[uid] == nil
			items.Inventory[uid] = {
				DefinitionId = listing.Item.DefinitionId,
				Level = listing.Item.Level,
				AcquiredAt = os.time(),
			}
			items.Discovered[listing.Item.DefinitionId] = true
			bazaar.PendingPurchases[listing.Id] = nil
			bazaar.CompletedPurchases[listing.Id] = true
			ProfileBagMath.BumpStat(profile, "ItemsFound", 1)
			return responseSuccess(
				"Purchase complete. The item is in your inventory.",
				{ ListingId = listing.Id, ItemUid = uid }
			)
		end)
		if not result.ok then
			return result
		end
		if not context.save(player) then
			return responseError("The item delivery is waiting for its profile save. Retry the same listing shortly.")
		end
		return result
	end

	local function chargeBuyer(player: Player, listing: any, token: string): Reply
		local price = tostring(listing.Price)
		local result = context.mutate(player, function(profile)
			profile.Bazaar = BazaarMath.Ensure(profile.Bazaar)
			local bazaar = profile.Bazaar
			if bazaar.CompletedPurchases[listing.Id] == true then
				return responseSuccess("That item is already in your inventory.", { Completed = true })
			end
			local pending = bazaar.PendingPurchases[listing.Id]
			if pending ~= nil then
				if pending.Token ~= token or pending.Price ~= price then
					return responseError("A different purchase is already recorded for this listing.")
				end
				return responseSuccess("Payment is already recorded.")
			end
			if not Economy.Gte(profile.Cash, price) then
				return responseError("You do not have enough Flux for this listing.")
			end
			profile.Cash = Economy.Sub(profile.Cash, price)
			bazaar.PendingPurchases[listing.Id] = { Token = token, Price = price }
			return responseSuccess("Payment secured.")
		end)
		if not result.ok then
			return result
		end
		if result.Completed == true then
			return result
		end
		if not context.save(player) then
			return responseError("Payment is safely recorded. Retry this listing after your profile save recovers.")
		end
		return result
	end

	function Marketplace.Purchase(player: Player, listingId: any, now: number): Reply
		if type(listingId) ~= "string" or #listingId < 8 or #listingId > 64 then
			return responseError("Choose a valid Bazaar listing.")
		end
		local profile = context.get(player)
		if profile == nil then
			return responseError("Your profile is still loading. Try again shortly.")
		end
		profile.Bazaar = BazaarMath.Ensure(profile.Bazaar)
		local savedBazaar = profile.Bazaar
		if savedBazaar.CompletedPurchases[listingId] == true then
			return responseSuccess(
				"That item is already in your inventory.",
				{ ListingId = listingId, Completed = true }
			)
		end
		local savedPending = savedBazaar.PendingPurchases[listingId]
		local listing = readListing(listingId)
		if listing == nil then
			return responseError("That listing could not be loaded. Retry shortly.")
		end
		if listing.Status == "Sold" then
			if listing.BuyerUserId ~= player.UserId then
				return responseError("That listing has already sold.")
			end
			if savedPending == nil then
				return responseError("This sale is awaiting purchase-record recovery. Contact support before retrying.")
			end
			return deliverPurchase(player, listing, savedPending.Token)
		end

		local token = if savedPending ~= nil then savedPending.Token else context.newId()
		local reserved, reserveError = reserveForBuyer(listingId, player.UserId, token, now)
		if reserved == nil then
			return responseError(reserveError)
		end
		token = reserved.LeaseToken or token
		if reserved.Status ~= "Reserved" or reserved.BuyerUserId ~= player.UserId then
			return responseError("That listing is not reserved for your purchase.")
		end

		local intentOk, intentListing = beginPaymentIntent(listingId, player.UserId, token)
		if not intentOk or intentListing == nil or not intentListing.PaymentIntent then
			return responseError("The purchase reservation changed. Refresh and retry.")
		end
		local payment = chargeBuyer(player, intentListing, token)
		if not payment.ok then
			if payment.error == "You do not have enough Flux for this listing." then
				releaseBuyerReservation(listingId, player.UserId, token, now)
			end
			return payment
		end
		if payment.Completed == true then
			return payment
		end

		local settled, sold = settlePayment(listingId, player.UserId, token, now)
		if not settled or sold == nil or sold.Status ~= "Sold" or sold.BuyerUserId ~= player.UserId then
			context.log("listing_settlement_pending", player.UserId, listingId)
			return responseError("Payment is safely recorded. The market is finishing the sale; retry shortly.")
		end
		local delivered = deliverPurchase(player, sold, token)
		if delivered.ok then
			context.log("listing_purchased", player.UserId, listingId)
		end
		return delivered
	end

	function Marketplace.ClaimPayout(player: Player, listingId: any): Reply
		if type(listingId) ~= "string" or #listingId < 8 or #listingId > 64 then
			return responseError("Choose a sold listing to claim.")
		end
		local listing = readListing(listingId)
		if listing == nil then
			return responseError("That listing could not be loaded. Retry shortly.")
		end
		if listing.SellerUserId ~= player.UserId or listing.Status ~= "Sold" then
			return responseError("Only the seller can claim proceeds from a completed sale.")
		end
		local result = context.mutate(player, function(profile)
			profile.Bazaar = BazaarMath.Ensure(profile.Bazaar)
			local bazaar = profile.Bazaar
			if bazaar.ClaimedPayouts[listingId] == true then
				return responseSuccess("Those sale proceeds were already collected.", { AlreadyClaimed = true })
			end
			profile.Cash = Economy.Add(profile.Cash, listing.Price)
			bazaar.ClaimedPayouts[listingId] = true
			local history = table.clone(bazaar.EscrowListings[listingId] or listing)
			history.Status = "Sold"
			history.PayoutClaimed = true
			bazaar.EscrowListings[listingId] = nil
			bazaar.ListingHistory[listingId] = history
			profile.Bazaar = BazaarMath.Ensure(bazaar)
			return responseSuccess("Sale proceeds added to your Flux balance.", { Price = tostring(listing.Price) })
		end)
		if not result.ok then
			return result
		end
		if not context.save(player) then
			return responseError("Sale proceeds are recorded and waiting for the profile save. Retry shortly.")
		end
		local wrote, claimed = writeListing(listingId, function(previous)
			local current = BazaarListingMath.Normalize(previous)
			if current == nil or current.Status ~= "Sold" or current.SellerUserId ~= player.UserId then
				return current
			end
			return BazaarListingMath.ClaimPayout(current, player.UserId) or current
		end)
		if not wrote or claimed == nil then
			context.log("listing_payout_marker_pending", player.UserId, listingId)
		end
		context.log("listing_payout_claimed", player.UserId, listingId)
		return result
	end

	local function activateListing(id: string, sellerId: number, escrowed: any, now: number): (boolean, any?)
		return writeListing(id, function(previous)
			local current = BazaarListingMath.Normalize(previous)
			if current == nil then
				return nil
			end
			if current.Status == "Active" then
				return current
			end
			if current.Status ~= "Escrowed" or current.SellerUserId ~= sellerId then
				return current
			end
			local nextListing = table.clone(current)
			nextListing.ItemUid = escrowed.ItemUid
			nextListing.Item = escrowed.Item
			nextListing.Price = escrowed.Price
			nextListing.Status = "Active"
			nextListing.Revision += 1
			nextListing.CreatedAt = now
			nextListing.ExpiresAt = now + LIFETIME_SECONDS
			return nextListing
		end)
	end

	local function countEscrow(bazaar): number
		local count = 0
		for _, listing in bazaar.EscrowListings do
			if listing.Status == "Escrowed" or listing.Status == "Active" then
				count += 1
			end
		end
		return count
	end

	local function equipped(profile, uid: string): boolean
		return TradeOfferMath.ItemEquipped(profile, uid)
	end

	function Marketplace.Create(player: Player, uid: any, rawPrice: any, now: number): Reply
		if type(uid) ~= "string" or #uid < 3 or #uid > 48 then
			return responseError("Choose an item from your inventory.")
		end
		if
			type(rawPrice) ~= "string"
			or #rawPrice > MAX_PRICE_DIGITS
			or string.match(rawPrice, "^%d+$") == nil
			or string.match(rawPrice, "^0+$") ~= nil
		then
			return responseError("Enter a whole-number Flux price above zero.")
		end

		local listingId = string.gsub(context.newId(), "[^%w%-]", "")
		if #listingId < 8 or #listingId > 64 then
			return responseError("The market could not create a listing ID. Please retry.")
		end
		local listing = {
			Id = listingId,
			SellerUserId = player.UserId,
			ItemUid = uid,
			Item = { DefinitionId = "pending", Level = 1, AcquiredAt = now },
			Price = rawPrice,
			Status = "Escrowed",
			Revision = 1,
			CreatedAt = now,
			ExpiresAt = now + LIFETIME_SECONDS,
			PayoutClaimed = false,
		}

		local reserved, initial = writeListing(listingId, function(previous)
			if previous ~= nil then
				return previous
			end
			return listing
		end)
		if not reserved or initial == nil or initial.Id ~= listingId or initial.Status ~= "Escrowed" then
			return responseError("The market is busy. Your item was not moved; please retry.")
		end

		local moved = context.mutate(player, function(profile)
			profile.Bazaar = BazaarMath.Ensure(profile.Bazaar)
			local bazaar = profile.Bazaar
			if countEscrow(bazaar) >= MAX_SELLER_LISTINGS then
				return responseError("You have reached the 50 active-listing limit.")
			end
			local items = profile.Items
			local item = type(items) == "table" and type(items.Inventory) == "table" and items.Inventory[uid]
			if type(item) ~= "table" or type(item.DefinitionId) ~= "string" then
				return responseError("That item is no longer in your inventory.")
			end
			if item.Locked == true or equipped(profile, uid) then
				return responseError("Unlock and unequip that item before listing it.")
			end
			local definition = itemDefinitionById[item.DefinitionId]
			if type(definition) ~= "table" then
				return responseError("That item cannot be listed on the market.")
			end
			listing.Item = {
				DefinitionId = item.DefinitionId,
				Level = math.clamp(math.floor(tonumber(item.Level) or 1), 1, 1000),
				AcquiredAt = math.clamp(math.floor(tonumber(item.AcquiredAt) or now), 0, 2 ^ 31 - 1),
			}
			local normalized = BazaarListingMath.Normalize(listing)
			if normalized == nil then
				return responseError("That item listing could not be validated.")
			end
			items.Inventory[uid] = nil
			bazaar.EscrowListings[listingId] = normalized
			return responseSuccess("Item secured in market escrow.", { ListingId = listingId, Listing = normalized })
		end)
		if not moved.ok then
			setStatus(listingId, "Escrowed", "Cancelled", now)
			return moved
		end
		if not context.save(player) then
			context.mutate(player, function(profile)
				local bazaar = BazaarMath.Ensure(profile.Bazaar)
				local escrowed = bazaar.EscrowListings[listingId]
				if escrowed and not profile.Items.Inventory[uid] then
					profile.Items.Inventory[uid] = escrowed.Item
					bazaar.EscrowListings[listingId] = nil
				end
				return responseSuccess("Escrow rollback applied.")
			end)
			setStatus(listingId, "Escrowed", "Cancelled", now)
			return responseError("Your profile did not save; the item was returned from escrow.")
		end

		local activated, activeListing = activateListing(listingId, player.UserId, moved.Listing, now)
		if not activated or activeListing == nil or activeListing.Status ~= "Active" then
			context.log("listing_activate_pending", player.UserId, listingId)
			return responseSuccess("Your item is secured. Market activation is pending; retry from My Listings.", {
				ListingId = listingId,
				Pending = true,
			})
		end
		local indexed = pcall(function()
			indexStore:SetAsync(keyFor(listingId), now)
		end)
		if not indexed then
			context.log("listing_index_pending", player.UserId, listingId)
		end
		context.log("listing_created", player.UserId, listingId)
		return responseSuccess("Your item is listed in the Bazaar.", { ListingId = listingId })
	end

	function Marketplace.Cancel(player: Player, listingId: any, now: number): Reply
		if type(listingId) ~= "string" or #listingId < 8 or #listingId > 64 then
			return responseError("Choose one of your listings.")
		end
		local current = readListing(listingId)
		if current == nil then
			return responseError("That listing could not be found right now.")
		end
		if current.SellerUserId ~= player.UserId then
			return responseError("Only the seller can cancel this listing.")
		end
		if current.Status == "Active" or current.Status == "Escrowed" then
			local wrote, cancelled = setStatus(listingId, current.Status, "Cancelled", now)
			if not wrote or cancelled == nil or cancelled.Status ~= "Cancelled" then
				return responseError("The listing changed. Refresh and try again.")
			end
		elseif current.Status ~= "Cancelled" then
			return responseError("That listing cannot be cancelled in its current state.")
		end

		local restored = context.mutate(player, function(profile)
			profile.Bazaar = BazaarMath.Ensure(profile.Bazaar)
			local bazaar = profile.Bazaar
			if bazaar.RestoredListings[listingId] == true then
				return responseSuccess("That item was already returned.")
			end
			local escrowed = bazaar.EscrowListings[listingId]
			if escrowed == nil then
				return responseError("The listing is cancelled; escrow recovery needs support.")
			end
			local inventory = profile.Items.Inventory
			local inventoryCount = 0
			for _ in inventory do
				inventoryCount += 1
			end
			if inventoryCount >= GameConfig.Items.InventoryLimit then
				return responseError("Free one inventory slot before returning this item.")
			end
			if inventory[escrowed.ItemUid] ~= nil then
				return responseError("Item recovery stopped because its inventory ID is already occupied.")
			end
			inventory[escrowed.ItemUid] = escrowed.Item
			bazaar.EscrowListings[listingId] = nil
			bazaar.RestoredListings[listingId] = true
			return responseSuccess("Listing cancelled. Your item is back in your inventory.")
		end)
		if not restored.ok then
			return restored
		end
		if not context.save(player) then
			return responseError("Item return is queued for save; keep this window open and retry shortly.")
		end
		context.log("listing_cancelled", player.UserId, listingId)
		return restored
	end

	function Marketplace.Latest(): Reply
		local ok, pages = pcall(function()
			return indexStore:GetSortedAsync(false, LIST_PAGE_SIZE)
		end)
		if not ok or pages == nil then
			return responseError("The Bazaar listings could not load. Please retry.")
		end
		local listings = {}
		local rows = pages:GetCurrentPage()
		for _, row in rows do
			local id = if type(row.key) == "string" then string.gsub(row.key, "^L_", "") else ""
			if id ~= "" then
				local listing = readListing(id)
				if listing and listing.Status == "Active" and listing.ExpiresAt > os.time() then
					listings[#listings + 1] = {
						Id = listing.Id,
						SellerUserId = listing.SellerUserId,
						ItemUid = listing.ItemUid,
						Item = listing.Item,
						Price = listing.Price,
						CreatedAt = listing.CreatedAt,
						ExpiresAt = listing.ExpiresAt,
					}
				end
			end
		end
		return responseSuccess("Bazaar listings loaded.", { Listings = listings })
	end

	function Marketplace.Mine(player: Player, cursorValue: any): Reply
		local cursor = if type(cursorValue) == "number" and cursorValue == cursorValue
			then math.clamp(math.floor(cursorValue), 0, MAX_SELLER_CURSOR)
			else 0
		local profile = context.get(player)
		if type(profile) ~= "table" then
			return responseError("Your profile is still loading. Try again shortly.")
		end
		profile.Bazaar = BazaarMath.Ensure(profile.Bazaar)
		local saved = profile.Bazaar
		local entries = {}
		local entryById = {}
		for id, listing in saved.EscrowListings do
			entryById[id] = { Id = id, CreatedAt = listing.CreatedAt, Listing = listing }
		end
		for id, listing in saved.ListingHistory do
			entryById[id] = entryById[id] or { Id = id, CreatedAt = listing.CreatedAt, Listing = listing }
		end
		for _, entry in entryById do
			entries[#entries + 1] = entry
		end
		table.sort(entries, function(left, right)
			if left.CreatedAt ~= right.CreatedAt then
				return left.CreatedAt > right.CreatedAt
			end
			return left.Id < right.Id
		end)

		local mine = {}
		local finish = math.min(#entries, cursor + MY_LIST_PAGE_SIZE)
		for index = cursor + 1, finish do
			local entry = entries[index]
			local latest = readListing(entry.Id) or entry.Listing
			mine[#mine + 1] = {
				Id = latest.Id,
				SellerUserId = latest.SellerUserId,
				ItemUid = latest.ItemUid,
				Item = latest.Item,
				Price = latest.Price,
				Status = latest.Status,
				CreatedAt = latest.CreatedAt,
				ExpiresAt = latest.ExpiresAt,
				PayoutClaimed = latest.PayoutClaimed == true or saved.ClaimedPayouts[entry.Id] == true,
			}
		end
		local nextCursor = if finish < #entries then finish else nil
		return responseSuccess("Your listings loaded.", {
			Listings = mine,
			NextCursor = nextCursor,
			Total = #entries,
		})
	end

	return table.freeze(Marketplace)
end

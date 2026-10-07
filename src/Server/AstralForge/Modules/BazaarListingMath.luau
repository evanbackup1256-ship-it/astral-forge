--!strict
-- Purpose: validate and advance durable player-market listing records.
-- Owner: bazaar.
-- Dependencies: none; this module is pure so every transition can be fixture-tested.
-- Last-reviewed: 2026-10-07.

local BazaarListingMath = {}

export type ListingStatus = "Escrowed" | "Active" | "Reserved" | "Sold" | "Cancelled"

export type ItemSnapshot = {
	DefinitionId: string,
	Level: number,
	AcquiredAt: number,
}

export type Listing = {
	Id: string,
	SellerUserId: number,
	ItemUid: string,
	Item: ItemSnapshot,
	Price: number | string,
	Status: ListingStatus,
	Revision: number,
	CreatedAt: number,
	ExpiresAt: number,
	BuyerUserId: number?,
	LeaseToken: string?,
	LeaseUntil: number?,
	SoldAt: number?,
	PayoutClaimed: boolean,
	PaymentIntent: boolean,
}

local MAX_LISTING_LIFETIME = 30 * 86400
local MIN_LEASE_SECONDS = 15
local MAX_LEASE_SECONDS = 120
local MAX_PRICE_TEXT_LENGTH = 80

local validStatuses: { [string]: boolean } = {
	Escrowed = true,
	Active = true,
	Reserved = true,
	Sold = true,
	Cancelled = true,
}

local function finiteInteger(value: any, minimum: number, maximum: number): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	if value % 1 ~= 0 or value < minimum or value > maximum then
		return nil
	end
	return value
end

local function validPrice(value: any): boolean
	if type(value) == "number" then
		return value == value and value > 0 and value < math.huge and value % 1 == 0
	end
	if type(value) ~= "string" or #value == 0 or #value > MAX_PRICE_TEXT_LENGTH then
		return false
	end
	if string.match(value, "^%d+$") == nil then
		return false
	end
	return string.match(value, "^0+$") == nil
end

function BazaarListingMath.Normalize(value: any): Listing?
	if type(value) ~= "table" then
		return nil
	end
	local id = value.Id
	local itemUid = value.ItemUid
	local item = value.Item
	local status = value.Status
	local sellerId = finiteInteger(value.SellerUserId, 1, 2 ^ 31 - 1)
	local revision = finiteInteger(value.Revision, 1, 2 ^ 31 - 1)
	local createdAt = finiteInteger(value.CreatedAt, 1, 2 ^ 31 - 1)
	local expiresAt = finiteInteger(value.ExpiresAt, 1, 2 ^ 31 - 1)
	if
		type(id) ~= "string"
		or #id < 8
		or #id > 64
		or type(itemUid) ~= "string"
		or #itemUid < 3
		or #itemUid > 48
		or type(item) ~= "table"
		or type(item.DefinitionId) ~= "string"
		or #item.DefinitionId < 1
		or #item.DefinitionId > 64
		or not validStatuses[status]
		or not validPrice(value.Price)
		or sellerId == nil
		or revision == nil
		or createdAt == nil
		or expiresAt == nil
		or expiresAt <= createdAt
		or expiresAt - createdAt > MAX_LISTING_LIFETIME
	then
		return nil
	end
	local level = finiteInteger(item.Level, 1, 1000)
	local acquiredAt = finiteInteger(item.AcquiredAt, 0, 2 ^ 31 - 1)
	if level == nil or acquiredAt == nil then
		return nil
	end
	local buyerId = if value.BuyerUserId == nil then nil else finiteInteger(value.BuyerUserId, 1, 2 ^ 31 - 1)
	local leaseUntil = if value.LeaseUntil == nil then nil else finiteInteger(value.LeaseUntil, 1, 2 ^ 31 - 1)
	local soldAt = if value.SoldAt == nil then nil else finiteInteger(value.SoldAt, 1, 2 ^ 31 - 1)
	if
		(value.BuyerUserId ~= nil and buyerId == nil)
		or (value.LeaseUntil ~= nil and leaseUntil == nil)
		or (value.SoldAt ~= nil and soldAt == nil)
		or (status == "Reserved" and (buyerId == nil or type(value.LeaseToken) ~= "string" or #value.LeaseToken < 8 or leaseUntil == nil))
		or (status == "Sold" and (buyerId == nil or soldAt == nil))
	then
		return nil
	end
	return {
		Id = id,
		SellerUserId = sellerId,
		ItemUid = itemUid,
		Item = { DefinitionId = item.DefinitionId, Level = level, AcquiredAt = acquiredAt },
		Price = value.Price,
		Status = status :: ListingStatus,
		Revision = revision,
		CreatedAt = createdAt,
		ExpiresAt = expiresAt,
		BuyerUserId = buyerId,
		LeaseToken = if status == "Reserved" then value.LeaseToken else nil,
		LeaseUntil = if status == "Reserved" then leaseUntil else nil,
		SoldAt = if status == "Sold" then soldAt else nil,
		PayoutClaimed = value.PayoutClaimed == true,
		PaymentIntent = value.PaymentIntent == true,
	}
end

function BazaarListingMath.CanReserve(listing: Listing, buyerUserId: number, now: number): (boolean, string)
	if finiteInteger(buyerUserId, 1, 2 ^ 31 - 1) == nil or finiteInteger(now, 0, 2 ^ 31 - 1) == nil then
		return false, "Invalid purchase request."
	end
	if buyerUserId == listing.SellerUserId then
		return false, "You cannot buy your own listing."
	end
	if listing.Status ~= "Active" then
		return false, "That listing is no longer available."
	end
	if now >= listing.ExpiresAt then
		return false, "That listing has expired."
	end
	return true, ""
end

function BazaarListingMath.Reserve(
	listing: Listing,
	buyerUserId: number,
	leaseToken: string,
	now: number,
	leaseSeconds: number
): (Listing?, string)
	local allowed, reason = BazaarListingMath.CanReserve(listing, buyerUserId, now)
	local durationInput = finiteInteger(leaseSeconds, 0, 2 ^ 31 - 1)
	local duration = if durationInput == nil
		then MIN_LEASE_SECONDS
		else math.clamp(durationInput, MIN_LEASE_SECONDS, MAX_LEASE_SECONDS)
	if not allowed then
		return nil, reason
	end
	if type(leaseToken) ~= "string" or #leaseToken < 8 or #leaseToken > 64 then
		return nil, "Invalid reservation token."
	end
	local nextListing = table.clone(listing)
	nextListing.Status = "Reserved"
	nextListing.Revision += 1
	nextListing.BuyerUserId = buyerUserId
	nextListing.LeaseToken = leaseToken
	nextListing.LeaseUntil = math.min(now + duration, listing.ExpiresAt)
	return nextListing, ""
end

function BazaarListingMath.ReleaseExpired(listing: Listing, now: number): Listing?
	if listing.Status ~= "Reserved" or listing.LeaseUntil == nil or now < listing.LeaseUntil then
		return nil
	end
	local nextListing = table.clone(listing)
	nextListing.Status = if now >= listing.ExpiresAt then "Cancelled" else "Active"
	nextListing.Revision += 1
	nextListing.BuyerUserId = nil
	nextListing.LeaseToken = nil
	nextListing.LeaseUntil = nil
	return nextListing
end

function BazaarListingMath.Settle(
	listing: Listing,
	buyerUserId: number,
	leaseToken: string,
	now: number
): (Listing?, string)
	if
		listing.Status ~= "Reserved"
		or listing.BuyerUserId ~= buyerUserId
		or listing.LeaseToken ~= leaseToken
		or listing.LeaseUntil == nil
		or (now >= listing.LeaseUntil and not listing.PaymentIntent)
		or (now >= listing.ExpiresAt and not listing.PaymentIntent)
	then
		return nil, "That purchase reservation expired."
	end
	local nextListing = table.clone(listing)
	nextListing.Status = "Sold"
	nextListing.Revision += 1
	nextListing.SoldAt = now
		nextListing.PayoutClaimed = false
		nextListing.PaymentIntent = listing.PaymentIntent
	nextListing.LeaseToken = nil
	return nextListing, ""
end

function BazaarListingMath.ClaimPayout(listing: Listing, sellerUserId: number): Listing?
	if listing.Status ~= "Sold" or listing.SellerUserId ~= sellerUserId or listing.PayoutClaimed then
		return nil
	end
	local nextListing = table.clone(listing)
	nextListing.Revision += 1
	nextListing.PayoutClaimed = true
	return nextListing
end

return table.freeze(BazaarListingMath)

--!strict
local BazaarListingMath = require("../src/Server/AstralForge/Modules/BazaarListingMath")
local BazaarMath = require("../src/Server/AstralForge/Modules/BazaarMath")

local function expect(condition: boolean, message: string)
	if not condition then
		error("Bazaar listing regression: " .. message, 2)
	end
end

local base = {
	Id = "LISTING-0001",
	SellerUserId = 10,
	ItemUid = "IT0000001",
	Item = { DefinitionId = "ember_relic", Level = 3, AcquiredAt = 100 },
	Price = "10000000000000000000000000000000000000000000000000000000000000000000000000000000",
	Status = "Active",
	Revision = 1,
	CreatedAt = 100,
	ExpiresAt = 1000,
	PayoutClaimed = false,
}

local normalized = BazaarListingMath.Normalize(base)
expect(normalized ~= nil and normalized.Price == base.Price, "normalization preserves big-integer currency text")
local dirty = table.clone(base)
dirty.Price = -10
expect(BazaarListingMath.Normalize(dirty) == nil, "negative numeric price is rejected")
dirty = table.clone(base)
dirty.Item = { DefinitionId = "item", Level = 0, AcquiredAt = 100 }
expect(BazaarListingMath.Normalize(dirty) == nil, "invalid item level is rejected")
dirty = table.clone(base)
dirty.ExpiresAt = dirty.CreatedAt + 31 * 86400
expect(BazaarListingMath.Normalize(dirty) == nil, "unbounded listing lifetime is rejected")

local canBuy, why = BazaarListingMath.CanReserve(normalized :: any, 10, 200)
expect(not canBuy and why ~= "", "self-purchase is denied")
canBuy = BazaarListingMath.CanReserve(normalized :: any, 11, 1000)
expect(not canBuy, "expired listing is denied")

local reserved, reserveError = BazaarListingMath.Reserve(normalized :: any, 11, "TOKEN-0001", 200, 999)
expect(reserved ~= nil and reserveError == "", "eligible buyer reserves listing")
expect(
	reserved.Status == "Reserved" and reserved.Revision == 2 and reserved.LeaseUntil == 320,
	"lease duration is clamped and revision increments"
)
expect(BazaarListingMath.Settle(reserved, 12, "TOKEN-0001", 201) == nil, "another buyer cannot settle reservation")
expect(BazaarListingMath.Settle(reserved, 11, "TOKEN-other", 201) == nil, "wrong token cannot settle reservation")

local released = BazaarListingMath.ReleaseExpired(reserved, 319)
expect(released == nil, "live lease cannot be released")
released = BazaarListingMath.ReleaseExpired(reserved, 320)
expect(released ~= nil and released.Status == "Active" and released.BuyerUserId == nil, "expired lease is reusable")
local sold, settleError = BazaarListingMath.Settle(reserved, 11, "TOKEN-0001", 250)
expect(sold ~= nil and settleError == "" and sold.Status == "Sold", "valid reserved buyer settles")
expect(BazaarListingMath.Settle(sold, 11, "TOKEN-0001", 251) == nil, "sold listing cannot settle twice")

local payout = BazaarListingMath.ClaimPayout(sold, 10)
expect(
	payout ~= nil and payout.PayoutClaimed and payout.Revision == sold.Revision + 1,
	"seller payout claim is persisted once"
)
expect(BazaarListingMath.ClaimPayout(payout, 10) == nil, "seller payout is idempotent")
expect(BazaarListingMath.ClaimPayout(sold, 11) == nil, "buyer cannot claim seller proceeds")

local activeEscrow = table.clone(base)
activeEscrow.Id = "LISTING-ACTIVE"
activeEscrow.Status = "Escrowed"
local archivedSale = table.clone(sold)
archivedSale.Id = "LISTING-SOLD"
archivedSale.PayoutClaimed = true
local sellerBazaar = BazaarMath.Ensure({
	EscrowListings = { [activeEscrow.Id] = activeEscrow },
	ListingHistory = { [archivedSale.Id] = archivedSale },
})
expect(sellerBazaar.EscrowListings[activeEscrow.Id] ~= nil, "an unsettled item remains in the seller's active escrow")
expect(sellerBazaar.EscrowListings[archivedSale.Id] == nil, "a claimed sale does not consume an active listing slot")
expect(
	sellerBazaar.ListingHistory[archivedSale.Id] ~= nil
		and sellerBazaar.ListingHistory[archivedSale.Id].Status == "Sold"
		and sellerBazaar.ListingHistory[archivedSale.Id].PayoutClaimed,
	"a claimed sale remains as a validated seller-history record"
)

local historyInput = {}
for index = 1, 105 do
	local record = table.clone(archivedSale)
	record.Id = string.format("LISTING-H%03d", index)
	record.CreatedAt = 100 + index
	historyInput[record.Id] = record
end
local boundedHistory = BazaarMath.Ensure({ ListingHistory = historyInput }).ListingHistory
local historyCount, oldestSaved = 0, false
for _, record in boundedHistory do
	historyCount += 1
	oldestSaved = oldestSaved or record.Id == "LISTING-H006"
end
expect(historyCount == 100 and oldestSaved, "only the newest one hundred valid sales are retained deterministically")

local expiring, expiringErr = BazaarListingMath.Reserve(normalized :: any, 11, "TOKEN-0002", 990, 120)
expect(expiring ~= nil and expiring.LeaseUntil == 1000, "lease never extends beyond listing expiry")
local cancelled = BazaarListingMath.ReleaseExpired(expiring :: any, 1000)
expect(cancelled ~= nil and cancelled.Status == "Cancelled", "expired listing with lease is retired")

print(
	"[TEST] Bazaar listing math passed | price sanitization, self-buy protection, bounded leases, sale idempotency and archived payout history"
)

--!strict
local fs = require("./_memberfs")(require("@lune/fs"))

local server = fs.readFile("src/Server/AstralForge/Services/BazaarListingService.luau")
local gameService = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
local bazaarMath = fs.readFile("src/Server/AstralForge/Modules/BazaarMath.luau")
local profile = fs.readFile("src/Server/AstralForge/DataTemplate.luau")
local config = fs.readFile("src/Server/AstralForge/ServerConfig.luau")
local protocol = fs.readFile("src/Shared/AstralForge/Shared/Protocol.luau")
local firewall = fs.readFile("src/Server/AstralForge/Services/RemoteFirewall.luau")
local validators = fs.readFile("src/Server/AstralForge/Modules/ProfileMath.luau")
local client = fs.readFile("src/Client/AstralForge/CoreKit.luau")
local listingsUI = fs.readFile("src/Client/AstralForge/pages/BazaarListings.luau")
local bazaarPage = fs.readFile("src/Client/AstralForge/pages/PagesBazaar.luau")

local function has(source: string, literal: string, message: string)
	assert(string.find(source, literal, 1, true) ~= nil, message)
end

for _, action in
	{
		"GetBazaarListings",
		"GetMyBazaarListings",
		"GetMyBazaarPurchases",
		"CreateBazaarListing",
		"CancelBazaarListing",
		"PurchaseBazaarListing",
		"ClaimBazaarPayout",
	}
do
	has(protocol, action .. ' = "' .. action .. '"', "protocol action missing: " .. action)
	has(firewall, "Protocol.Actions." .. action, "firewall lacks action rule: " .. action)
	has(gameService, "Protocol.Actions." .. action, "server dispatch lacks action: " .. action)
end
has(client, '["CreateBazaarListing"] = true', "listing creation must carry an authenticated session grant")
has(client, '["CancelBazaarListing"] = true', "listing cancellation must carry an authenticated session grant")
has(client, '["PurchaseBazaarListing"] = true', "purchases must carry an authenticated session grant")
has(client, '["ClaimBazaarPayout"] = true', "payout claims must carry an authenticated session grant")
has(validators, "GetBazaarListings = true", "listing reads must be read-only")
has(validators, "GetMyBazaarListings = true", "seller listing reads must be read-only")
has(validators, "GetMyBazaarPurchases = true", "buyer receipt reads must be read-only")
has(validators, "CreateBazaarListing = true", "escrow creation must be a high-value session action")
has(validators, "CancelBazaarListing = true", "escrow return must be a high-value session action")
has(validators, "PurchaseBazaarListing = true", "market purchases must be high-value session actions")
has(validators, "ClaimBazaarPayout = true", "payout claims must be high-value session actions")
has(firewall, 'not stringField(payload, "Uid", 3, 48)', "listing UID must be bounded")
has(firewall, 'not stringField(payload, "Price", 1, 80)', "listing price must be bounded")
has(firewall, 'not stringField(payload, "Id", 8, 64)', "listing ID must be bounded")
has(firewall, 'numberField(payload, "Cursor", 0, 100, true)', "buyer receipt pagination must be bounded")
has(
	firewall,
	"[Protocol.Actions.GetMyBazaarPurchases] = { Cost = 0.8, Cooldown = 1.5 }",
	"buyer receipt reads must be rate limited"
)

has(config, "BazaarListingStoreName", "a separate durable listing store must be configured")
has(config, "BazaarListingIndexStoreName", "a separate ordered browse index must be configured")
has(profile, "EscrowListings = {}", "profile schema must preserve escrow references")
has(profile, "ListingHistory = {}", "profile schema must preserve the bounded completed-sale history")
has(profile, "PurchaseHistory = {}", "profile schema must preserve bounded buyer receipts")
has(profile, "RestoredListings = {}", "profile schema must preserve idempotent returns")
has(bazaarMath, "validEscrowListing(id, listing)", "profile sanitization must validate escrowed listings")

local globalWrite = string.find(server, "listingStore:UpdateAsync", 1, true)
local profileMove = string.find(server, "items.Inventory[uid] = nil", 1, true)
local profileSave = string.find(server, "context.save(player)", 1, true)
local activation = string.find(server, "activateListing(listingId", 1, true)
assert(
	globalWrite and profileMove and profileSave and activation,
	"listing activation must span global reservation, profile escrow/save, and active transition"
)
assert(
	profileMove < activation and profileSave < activation,
	"listing cannot become visible before escrow has been saved"
)
has(server, "bazaar.EscrowListings[listingId] = normalized", "seller profile must durably retain the item snapshot")
has(server, "bazaar.RestoredListings[listingId] == true", "item return must be idempotent")
has(server, "function Marketplace.Purchase", "purchase settlement must be implemented")
has(server, "function Marketplace.ClaimPayout", "seller payout claim must be implemented")
has(server, "bazaar.EscrowListings[listingId] = nil", "claiming proceeds must free a completed listing slot")
has(server, "bazaar.ListingHistory[listingId] = history", "claimed sales must remain visible in seller history")
has(
	server,
	"function Marketplace.Mine",
	"seller history must reconcile durable local records with latest global listing state"
)
has(server, "function Marketplace.Purchases", "buyers must be able to load saved receipts")
has(server, "bazaar.PurchaseHistory[listing.Id] =", "delivery must persist a receipt in the buyer profile")
has(server, "PurchasedAt = listing.SoldAt or acquiredAt", "receipt timestamp must use server settlement time")
has(server, "local MY_LIST_PAGE_SIZE = 6", "seller history page size must match the six-card layout")
has(
	server,
	"local MAX_SELLER_CURSOR = MAX_SELLER_LISTINGS + MAX_SELLER_HISTORY",
	"seller history pagination must cover active and archived records"
)
has(
	firewall,
	'numberField(payload, "Cursor", 0, 150, true)',
	"seller pagination firewall must admit the bounded history range"
)
has(
	server,
	"local latest = readListing(entry.Id) or entry.Listing",
	"seller history must recover when global state is temporarily unavailable"
)
has(server, "bazaar.CompletedPurchases[listing.Id] == true", "delivery must be idempotent")
has(server, "bazaar.ClaimedPayouts[listingId] == true", "seller payout must be idempotent")
has(server, "beginPaymentIntent(listingId", "payment intents must be durable before buyer debit")
has(server, "settlePayment(listingId", "reserved listings must be atomically settled")
has(server, "indexStore:SetAsync(keyFor(listingId), now)", "active listings must be inserted into the browse index")
has(server, 'current.Status ~= "Escrowed"', "activation must reject state changes")
has(server, 'elseif current.Status ~= "Cancelled" then', "cancel retry must proceed to profile recovery")
has(gameService, "self._data:Save(player, false)", "profile escrow needs a save boundary")
has(gameService, "self._bazaarListings.Purchases(player", "receipt reads must dispatch through the listing service")
has(
	bazaarPage,
	"require(script.Parent.BazaarListings).BazaarListings",
	"player listings must be integrated into the Bazaar page"
)
has(bazaarPage, '{ id = "Listings", label = "Player Listings"', "player listings must have a dedicated Bazaar tab")
has(bazaarPage, "Listings = 920", "the listing page needs enough scroll height for its controls")
has(
	listingsUI,
	'props.dispatch("GetMyBazaarListings", { Cursor = requestedCursor }',
	"seller history UI must load server-paged records"
)
has(
	listingsUI,
	'props.dispatch("GetMyBazaarPurchases", { Cursor = requestedCursor }',
	"buyer history UI must load server-paged receipts"
)
has(listingsUI, 'openTab("Purchase History")', "Bazaar must expose purchase history")
has(listingsUI, 'actionDisabled = tab ~= "Browse"', "saved receipts must never expose active purchase actions")
has(listingsUI, 'perform("CreateBazaarListing"', "seller UI must create escrowed listings")
has(listingsUI, 'perform("CancelBazaarListing"', "seller UI must offer cancellation and item recovery")
has(listingsUI, 'perform("ClaimBazaarPayout"', "seller UI must expose unclaimed sale proceeds")
has(listingsUI, 'perform("PurchaseBazaarListing"', "browse UI must use the server-validated purchase route")
has(listingsUI, "children.PurchaseConfirmation =", "buyers must confirm the item and cost before purchase")
has(
	listingsUI,
	"value = `Cost: {displayPrice(pendingPurchase.Price)} FLUX",
	"confirmation must disclose the exact listing price"
)
has(
	listingsUI,
	'text = if busy then "PURCHASING" else "CONFIRM BUY"',
	"purchase confirmation must expose a separate, busy-guarded final action"
)
has(listingsUI, "No listing fee.", "listing form must disclose the zero-fee seller payout")
has(listingsUI, "local selectedEligible =", "the sell action must recheck current inventory eligibility")
has(
	listingsUI,
	"local sellButtonTop = inventoryEnd + 44",
	"the sell action must follow inventory paging without overlapping its note"
)

print(
	"[TEST] Bazaar listing service wiring passed | bounded authenticated routes, versioned stores, saved escrow before activation, idempotent seller recovery"
)

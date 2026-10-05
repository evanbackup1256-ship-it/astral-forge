--!nocheck
-- Execute the real receipt handler with an isolated data store and marketplace decisions.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Catalog = require("../src/Shared/AstralForge/Shared/CommerceCatalog")
local Ledger = require("../src/Server/AstralForge/Modules/ReceiptLedger")
local source = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau"):gsub("\r\n", "\n")
local first = assert(source:find("\tfunction GameService:_processReceipt(receiptInfo)", 1, true))
local last = assert(source:find("\n\tfunction GameService:_syncShop", first, true))
local handler = source:sub(first, last - 1)
local def = { Key = "Tip25", ProductId = 25, Donation = true, StudioPrice = 25, Name = "Tip Jar" }
local profile = { Receipts = {} }
local player = { UserId = 1 }
local saved, attempts, grants = false, 0, 0
local effects = {}
local service = {
	_data = {
		Update = function(_, _, fn)
			fn(profile)
			return true
		end,
		Save = function()
			attempts += 1
			saved = attempts > 1
			return saved
		end,
		Get = function()
			return profile
		end,
	},
	_effect = {
		FireClient = function(_, _, event)
			assert(saved, "celebration cannot precede durable save")
			table.insert(effects, event)
		end,
	},
	_grantDevProduct = function()
		grants += 1
		return "Thanks"
	end,
	_syncLeaderstats = function() end,
	_pushState = function() end,
	_toastPlayer = function() end,
}
local env = {
	GameService = {},
	Players = {
		GetPlayerByUserId = function()
			return player
		end,
	},
	MonetizationConfig = {
		FindDevProductByProductId = function(id)
			return if id == 25 then def else nil
		end,
	},
	ReceiptLedger = Ledger,
	ModuleLog = { Warn = function() end },
	ReplicatedStorage = { AstralForge = { Shared = { CommerceCatalog = "catalog" } } },
	require = function(name)
		assert(name == "catalog")
		return Catalog
	end,
	Enum = { ProductPurchaseDecision = { NotProcessedYet = "Retry", PurchaseGranted = "Granted" } },
}
setmetatable(env, { __index = getfenv() })
local fn = luau.load(handler .. "\nreturn GameService._processReceipt", { environment = env })()
local receipt = { PlayerId = 1, ProductId = 25, PurchaseId = "verified-receipt", CurrencySpent = 25 }
assert(fn(service, receipt) == "Retry" and #effects == 0)
assert(fn(service, receipt) == "Granted" and #effects == 2)
assert(
	grants == 1 and profile.Donations.Total == 25 and profile.Donations.Count == 1,
	"retry cannot duplicate grants or donation totals"
)
assert(effects[1].Type == "Donation" and effects[1].Key == receipt.PurchaseId)
assert(effects[2].Type == "PurchaseConfirmed" and effects[2].Key == receipt.PurchaseId and effects[2].ProductId == 25)
assert(fn(service, { PlayerId = 1, ProductId = 999, PurchaseId = "unknown" }) == "Retry")
print("[TEST] confirmed donation receipt, durable-save retry, idempotent grant and unknown-product rejection passed")

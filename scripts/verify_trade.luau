-- Run with: lune run scripts/verify_trade.luau
-- Trade apply/revert roundtrip + settle-path / ConfirmTrade dual-tree source invariants.
-- No Studio. Does not touch vendor/ or Packages/.

local fs = require("@lune/fs")

local OmegaMath = require("../src/Shared/AstralForge/Shared/OmegaMath")
local TradeExchange = require("../src/Server/AstralForge/Modules/TradeExchange")
local ProfileVersionGuard = require("../src/Server/AstralForge/Modules/ProfileVersionGuard")

local gameConfig = {
	Items = { InventoryLimit = 100 },
	Trading = {
		DailyTrades = 12,
		MaxItems = 6,
		PerTrade = {
			Cash = 5_000_000,
			Stardust = 2_500,
			Cores = 12,
			Signals = 350,
			Essence = 600,
			Boost = 3,
			Keys = 5,
			Items = 6,
		},
		Daily = {
			Cash = 20_000_000,
			Stardust = 8_000,
			Cores = 30,
			Signals = 1_000,
			Essence = 1_800,
			Boost = 8,
			Keys = 12,
			Items = 18,
		},
	},
}

local function emptyOffer()
	local offer = {
		Cash = 0,
		Stardust = 0,
		Cores = 0,
		Signals = 0,
		Essence = 0,
		Boosts = {},
		Keys = {},
		ItemIds = {},
	}
	for _, id in TradeExchange.BOOST_IDS do
		offer.Boosts[id] = 0
	end
	for _, id in TradeExchange.KEY_IDS do
		offer.Keys[id] = 0
	end
	return offer
end

local function makeProfile(cash, stardust, itemUid, definitionId)
	return {
		Cash = cash,
		Stardust = stardust,
		Cores = 4,
		Command = { Signals = 20 },
		Items = {
			Essence = 50,
			Keys = { ForgeCrate = 2 },
			Inventory = {
				[itemUid] = { DefinitionId = definitionId, Uid = itemUid },
			},
		},
		BoostInventory = { Overdrive = 1 },
		Trade = {
			Day = -1,
			Completed = 0,
			Sent = { Cash = 0, Stardust = 0, Cores = 0, Signals = 0, Essence = 0, Boost = 0, Keys = 0, Items = 0 },
		},
	}
end

------------------------------------------------------------------------
-- 1. Apply → Revert roundtrip (cash + relic + key + boost)
------------------------------------------------------------------------
do
	local now = os.time()
	local host = makeProfile(10_000, 100, "uid-host-1", "RelicA")
	local guest = makeProfile(3_000, 40, "uid-guest-1", "RelicB")
	local hostSnap = {
		Cash = host.Cash,
		Stardust = host.Stardust,
		Cores = host.Cores,
		Signals = host.Command.Signals,
		Essence = host.Items.Essence,
		Keys = host.Items.Keys.ForgeCrate,
		Boost = host.BoostInventory.Overdrive,
		Completed = 0,
	}

	local give = emptyOffer()
	give.Cash = 500
	give.Stardust = 10
	give.Keys.ForgeCrate = 1
	give.Boosts.Overdrive = 1
	give.ItemIds = { "uid-host-1" }

	local take = emptyOffer()
	take.Cash = 200
	take.ItemIds = { "uid-guest-1" }

	local giveItems = TradeExchange.SnapshotOfferItems(give, host)
	local takeItems = TradeExchange.SnapshotOfferItems(take, guest)

	local applyErr = TradeExchange.ApplyExchange(gameConfig, OmegaMath, host, give, take, giveItems, takeItems, now, nil)
	assert(applyErr == nil, "apply should succeed: " .. tostring(applyErr))
	assert(host.Items.Inventory["uid-host-1"] == nil, "gave relic should leave host inventory")
	assert(host.Items.Inventory["uid-guest-1"] ~= nil, "taken relic should land on host")
	assert(host.Trade.Completed == 1, "completed should bump")
	local cashAfter = OmegaMath.ToNumber(host.Cash)
	assert(math.abs(cashAfter - 9700) < 0.01, "cash net after apply, got " .. tostring(cashAfter))

	TradeExchange.RevertExchange(OmegaMath, host, give, take, giveItems, takeItems, now)
	assert(host.Items.Inventory["uid-host-1"] ~= nil, "revert restores given relic")
	assert(host.Items.Inventory["uid-guest-1"] == nil, "revert removes taken relic")
	assert(host.Trade.Completed == 0, "completed should roll back")
	local cashRestored = OmegaMath.ToNumber(host.Cash)
	assert(math.abs(cashRestored - OmegaMath.ToNumber(hostSnap.Cash)) < 0.01, "cash restored")
	assert(host.Stardust == hostSnap.Stardust, "stardust restored")
	assert(host.Cores == hostSnap.Cores, "cores restored")
	assert(host.Command.Signals == hostSnap.Signals, "signals restored")
	assert(host.Items.Essence == hostSnap.Essence, "essence restored")
	assert(host.Items.Keys.ForgeCrate == hostSnap.Keys, "keys restored")
	assert(host.BoostInventory.Overdrive == hostSnap.Boost, "boost restored")
end

------------------------------------------------------------------------
-- 2. Inventory limit rejected on apply
------------------------------------------------------------------------
do
	local now = os.time()
	local tightConfig = { Items = { InventoryLimit = 1 } }
	local profile = makeProfile(100, 0, "keep", "RelicA")
	local give = emptyOffer()
	local take = emptyOffer()
	take.ItemIds = { "incoming" }
	local takeItems = { incoming = { DefinitionId = "RelicB", Uid = "incoming" } }
	local err = TradeExchange.ApplyExchange(tightConfig, OmegaMath, profile, give, take, {}, takeItems, now, nil)
	assert(err ~= nil, "over-capacity apply must fail")
	assert(profile.Items.Inventory.incoming == nil, "failed apply must not mutate inventory")
	assert(profile.Trade.Completed == 0, "failed apply must not bump completed")
end

------------------------------------------------------------------------
-- 3. Settle lock semantics (TradeSettle pure helpers)
------------------------------------------------------------------------
do
	local TradeSettle = require("../src/Server/AstralForge/Modules/TradeSettle")
	local session = {
		Host = 1,
		Guest = 2,
		Confirmed = { [1] = true, [2] = true },
		Settling = false,
		Status = "Confirming",
		ConfirmEndsAt = 0,
	}
	assert(TradeSettle.TryBegin(session) == true, "first settle claim wins")
	assert(TradeSettle.TryBegin(session) == false, "second settle claim must lose (race guard)")
	assert(session.Status == "Settling", "status settles")
end

------------------------------------------------------------------------
-- 4. DataVersion / PlatformBadges hard constraints
------------------------------------------------------------------------
do
	local cfg = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
	assert(string.find(cfg, "DataVersion = 21", 1, true), "DataVersion must remain 21")
	local badges = string.match(cfg, "PlatformBadges = %{(.-)\n\t%},")
	assert(badges, "PlatformBadges missing")
	for id, value in string.gmatch(badges, "(%w+)%s*=%s*(%d+)") do
		assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
	end
	assert(ProfileVersionGuard.ReadCompatible({ DataVersion = 21 }, 21) == 21)
	assert(not pcall(ProfileVersionGuard.ReadCompatible, { DataVersion = 22 }, 21))
end

------------------------------------------------------------------------
-- 5. Source invariants: settle path + dual ConfirmTrade trees
------------------------------------------------------------------------
do
	local services = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
	assert(string.find(services, "TryBeginSettle", 1, true), "ConfirmTrade must use TryBeginSettle")
	assert(string.find(services, "FailSettle", 1, true), "ConfirmTrade must FailSettle on abort")
	assert(string.find(services, "trade-revert", 1, true), "guest-fail path must revert host")
	assert(string.find(services, "TradeSettle.RunHostGuest", 1, true), "ConfirmTrade must orchestrate via RunHostGuest")
	assert(string.find(services, "revertHostOnce", 1, true), "ConfirmTrade must inject revertHostOnce")
	local revertCount = 0
	for _ in string.gmatch(services, '"trade%-revert"') do
		revertCount += 1
	end
	assert(revertCount >= 1, "host revert AtomicUpdate must remain in ConfirmTrade hooks")
	local settleSrc = fs.readFile("src/Server/AstralForge/Modules/TradeSettle.luau")
	assert(string.find(settleSrc, "RevertWithRetries", 1, true), "revert retries stay in TradeSettle")
	assert(string.find(settleSrc, "function TradeSettle.RunHostGuest", 1, true), "RunHostGuest exported")

	local desk = fs.readFile("src/Server/AstralForge/Modules/TradeDesk.luau")
	assert(string.find(desk, "function TradeDesk:TryBeginSettle", 1, true))
	assert(string.find(desk, "function TradeDesk:FailSettle", 1, true))
	assert(string.find(desk, "TradeSettle.TryBegin", 1, true), "desk must delegate settle begin")
	assert(string.find(desk, "TradeExchange.ApplyExchange", 1, true), "desk must delegate apply")
	assert(string.find(desk, "TradeExchange.RevertExchange", 1, true), "desk must delegate revert")
	assert(not string.find(desk, "vendor/", 1, true))
	assert(not string.find(desk, "Packages/", 1, true))

	local view = fs.readFile("src/Client/AstralForge/pages/TradeView.luau")
	assert(string.find(view, "CONFIRM_TRADE_TREE:shared", 1, true), "shared ConfirmTrade tree marker")
	assert(not string.find(view, "CONFIRM_TRADE_TREE:compact", 1, true), "compact Confirm tree must be collapsed into shared")
	assert(not string.find(view, "CONFIRM_TRADE_TREE:desktop", 1, true), "desktop Confirm tree must be collapsed into shared")
	assert(string.find(view, "CONFIRM_TRADE_PANEL", 1, true), "shared Confirm panel marker")
	assert(string.find(view, "buildConfirmActions", 1, true), "shared Confirm panel builder")
	assert(string.find(view, "onConfirmClick", 1, true), "shared confirm handler")
	local confirmRuns = 0
	for _ in string.gmatch(view, 'run%("ConfirmTrade"%)') do
		confirmRuns += 1
	end
	assert(confirmRuns == 1, "ConfirmTrade should funnel through one shared handler, got " .. tostring(confirmRuns))
	assert(
		string.find(view, 'local confirmDisabled = busy ~= "" or not bothReady', 1, true),
		"confirmDisabled must share the bothReady gate"
	)
	assert(
		string.find(view, 'local readyDisabled = busy ~= "" or (tableEmpty and not youReadyLocal)', 1, true),
		"readyDisabled must share the tableEmpty gate"
	)
	local disabledConfirm = 0
	for _ in string.gmatch(view, "disabled = confirmDisabled") do
		disabledConfirm += 1
	end
	assert(disabledConfirm == 1, "shared Confirm panel must declare confirmDisabled once, got " .. tostring(disabledConfirm))
	local loadingConfirm = 0
	for _ in string.gmatch(view, 'loading = busy == "ConfirmTrade"') do
		loadingConfirm += 1
	end
	assert(loadingConfirm == 1, "shared Confirm panel must declare ConfirmTrade loading once, got " .. tostring(loadingConfirm))
	assert(string.find(view, "TradeReady", 1, true) and string.find(view, "TradeConfirm", 1, true), "Ready/Confirm must be named for FocusClaim")
	assert(string.find(view, "GamepadNavigationService.FocusClaim", 1, true), "session actions must FocusClaim")
	assert(string.find(view, "GamepadNavigationService.BeginOverlayFocus", 1, true), "session actions must BeginOverlayFocus")
	assert(string.find(view, "GamepadNavigationService.EndOverlayFocus", 1, true), "session actions must EndOverlayFocus on exit")
	assert(not string.find(view, 'createElement("scrollingframe"', 1, true), "TradeView must have zero raw scrollingframes")
	assert(string.find(view, "FlatList", 1, true), "Trade roster must FlatList long catalogs")
	-- Shared pin+PageScaffold tree: orientation differs; handlers + pin stay identical.
	assert(
		string.find(view, "Shared action handlers for CONFIRM_TRADE_TREE", 1, true),
		"TradeView must document shared handlers across Confirm trees"
	)
	assert(
		string.find(view, 'Position = UDim2.new(0, 0, 1, -actionH)', 1, true),
		"Ready/Confirm must pin to bottom on shared session chrome"
	)
	local pinCount = 0
	for _ in string.gmatch(view, 'Position = UDim2%.new%(0, 0, 1, %-actionH%)') do
		pinCount += 1
	end
	assert(pinCount >= 1, "shared Confirm tree must pin actions, got " .. tostring(pinCount))
end


------------------------------------------------------------------------
-- 6. Cancel refused while Settling (trade residual guard)
------------------------------------------------------------------------
do
	local TradeSettle = require("../src/Server/AstralForge/Modules/TradeSettle")
	local deskSrc = fs.readFile("src/Server/AstralForge/Modules/TradeDesk.luau")
	assert(string.find(deskSrc, "TradeSettle.CancelBlocked", 1, true), "Cancel must gate via TradeSettle")
	assert(string.find(deskSrc, "RevertFailedReason", 1, true) or string.find(deskSrc, "TradeSettle.Fail", 1, true), "FailSettle permanent must stamp RevertFailedReason")
	local services = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
	assert(string.find(services, "cancelErr", 1, true), "ConfirmTrade Cancel path must surface cancelErr")
	assert(string.find(services, "outcome.log", 1, true), "permanent settle failure must ModuleLog outcome.log")
	local settleSrc = fs.readFile("src/Server/AstralForge/Modules/TradeSettle.luau")
	assert(string.find(settleSrc, "FormatRevertFailedLog", 1, true), "TradeSettle must format RevertFailed logs")
	assert(string.find(settleSrc, "admin note:", 1, true), "RevertFailed log must cite admin note")
	assert(string.find(settleSrc, "Trade settle recovery", 1, true), "TradeSettle must cite Trade settle recovery")
	local adminFields = fs.readFile("src/Client/AstralForge/adminFields.luau")
	assert(string.find(adminFields, "Trade settle recovery", 1, true), "admin reasons must include Trade settle recovery")
	local adminService = fs.readFile("src/Server/AstralForge/Services/AdminService.luau")
	assert(string.find(adminService, '["Trade settle recovery"] = true', 1, true), "Trade settle recovery must be audit-only")

	local session = {
		Host = 1,
		Guest = 2,
		Confirmed = { [1] = true, [2] = true },
		Settling = true,
		Status = "Settling",
		ConfirmEndsAt = 0,
	}
	local blocked, err = TradeSettle.CancelBlocked(session)
	assert(blocked == true and err == "That trade is already settling.", "cancel during settle must refuse")
	session.Settling = false
	session.Status = "RevertFailed"
	blocked = TradeSettle.CancelBlocked(session)
	assert(blocked == false, "cancel after RevertFailed must be allowed to clear residual")
end

------------------------------------------------------------------------
-- 7. SteadyProduction nil-safe Research + SessionGate txn _get
------------------------------------------------------------------------
do
	local economySrc = fs.readFile("src/Server/AstralForge/Modules/Economy.luau")
	assert(string.find(economySrc, 'type(research) == "table"', 1, true), "SteadyProduction must nil-safe Research")
	local gateSrc = fs.readFile("src/Server/AstralForge/Services/SessionGate.luau")
	local getCount = 0
	for _ in string.gmatch(gateSrc, "self:_get%(player%)") do
		getCount += 1
	end
	assert(getCount >= 4, "Hello/Beat/Txn helpers should share _get")
end

print("[INFO] [TEST] trade exchange roundtrip + settle invariants passed")

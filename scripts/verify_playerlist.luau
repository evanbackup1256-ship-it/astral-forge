--!strict
-- Player list and reports:
--  * PlayerlistModel cleans rows, sorts with the local player pinned, searches and filters,
--  * client and server agree on the report reasons,
--  * ReportLedger stops repeat reports, rate-limits a reporter and tallies a target.

local luau = require("@lune/luau")
local fs = require("./_memberfs")(require("@lune/fs"))

local Model = luau.load(fs.readFile("src/Shared/AstralForge/Shared/SharedData.luau#PlayerlistModel"), { chunkName = "PlayerlistModel" })() :: any
local Ledger = luau.load(fs.readFile("src/Server/AstralForge/Modules/ProfileMath.luau#ReportLedger"), { chunkName = "ReportLedger" })() :: any

-- Rows
local rows = Model.clean({
	{ UserId = 1, Name = "me", DisplayName = "Me", IsLocal = true, Production = 1 },
	{ UserId = 2, Name = "zed", DisplayName = "Zed", Production = 500, Rebirths = 1 },
	{ UserId = "3", Name = "amy", DisplayName = "Amy", Production = 50, Rebirths = 9 },
	{ UserId = 2, Name = "dup" },
	{ UserId = -4, Name = "bad" },
	{ UserId = 0 / 0, Name = "nan" },
	{ UserId = 77, Name = "bot" },
	"junk",
	{ UserId = 5, Production = "lots" },
}, 77)
assert(#rows == 4, "bad, duplicate and skipped ids drop, got " .. #rows)
assert(rows[3].UserId == 3, "string ids coerce")
assert(rows[4].Name == "5" and rows[4].DisplayName == "5" and rows[4].Production == 0, "missing names and junk numbers default")
assert(rows[4].CurrentZone == 1, "worlds start at 1")

local byOutput = Model.view(rows, "Production")
assert(byOutput[1].IsLocal and byOutput[2].UserId == 2 and byOutput[3].UserId == 3, "output sort, local first")
local byRebirths = Model.view(rows, "Rebirths")
assert(byRebirths[1].IsLocal and byRebirths[2].UserId == 3, "rebirth sort")
local byName = Model.view(rows, "Name")
assert(byName[1].IsLocal and byName[2].DisplayName == "5" and byName[3].DisplayName == "Amy", "name sort")
local searched = Model.view(rows, "Production", "  AM ")
assert(#searched == 2 and searched[2].UserId == 3, "search trims, ignores case, keeps the local row")
local friendsView = Model.view(rows, "Production", "", true, { [2] = true })
assert(#friendsView == 2 and friendsView[2].UserId == 2, "friends filter")

assert(Model.playTime(3 * 3600 + 12 * 60) == "3h 12m" and Model.playTime(59) == "<1m", "play time label")
assert(Model.accountAge(800) == "2y" and Model.accountAge(45) == "1mo" and Model.accountAge(3) == "3d", "account age label")
assert(#Model.details(string.rep("x", 900)) == Model.DETAILS_MAX, "details clamp to the server limit")
assert(Model.details("  hi  ") == "hi", "details trim")

-- Reasons agree
assert(#Model.REASONS == #Ledger.REASONS, "client and server list the same number of reasons")
for index, reason in Model.REASONS do
	assert(reason.id == Ledger.REASONS[index], "reason " .. reason.id .. " matches the server")
	assert(#reason.id >= 3 and #reason.id <= 16, reason.id .. " fits the firewall's 3-16 chars")
	assert(reason.detail ~= "", reason.id .. " explains itself")
end
assert(Ledger.isReason("Scamming") and not Ledger.isReason("scamming") and not Ledger.isReason(nil), "isReason")

-- Ledger
local ledger = Ledger.new()
local now = 1000
assert(ledger:canReport(1, 2, now), "first report is fine")
local total, distinct = ledger:record(1, 2, "Spam", now)
assert(total == 1 and distinct == 1, "tally after one report")
local ok, why = ledger:canReport(1, 2, now + 60)
assert(not ok and string.find(why, "already reported", 1, true), "repeat report blocked")
assert(string.find(why, "9 min", 1, true), "says when they can report again: " .. why)
assert(ledger:canReport(1, 2, now + Ledger.REPEAT_SECONDS), "allowed again after the repeat window")
ledger:record(3, 2, "Spam", now + 10)
ledger:record(3, 9, "Spam", now + 11)
total, distinct = ledger:tally(2, now + 20)
assert(total == 2 and distinct == 2, "tally counts reports and distinct reporters")
for target = 10, 10 + Ledger.MAX_PER_WINDOW - 2 do
	ledger:record(4, target, "Other", now)
end
assert(ledger:canReport(4, 99, now), "under the hourly cap")
ledger:record(4, 99, "Other", now)
ok, why = ledger:canReport(4, 100, now + 1)
assert(not ok and string.find(why, "this hour", 1, true), "hourly cap")
assert(ledger:canReport(4, 100, now + Ledger.WINDOW_SECONDS), "cap resets after the window")
total = ledger:tally(2, now + Ledger.WINDOW_SECONDS + 20)
assert(total == 0, "old reports age out of the tally")
ledger:forgetReporter(4)
assert(ledger:canReport(4, 100, now + 2), "leaving clears a reporter's history")

-- Wiring
local server = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(server, "reportLedger:canReport(player.UserId, targetUserId, now)", 1, true), "server checks the ledger")
assert(string.find(server, "reportLedger:record(player.UserId, targetUserId, reason, now)", 1, true), "server records reports")
local view = fs.readFile("src/Client/AstralForge/UiCore.luau#PlayerlistOverlay")
assert(string.find(view, 'SharedData("PlayerlistModel")', 1, true), "player list uses the model")
assert(string.find(view, "local function ReportSheet", 1, true), "report sheet")

print("verify_playerlist: ok")

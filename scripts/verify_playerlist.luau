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
local huge = Model.clean({ { UserId = 8, Name = "big", Production = "3.520000000000e34" } }, 0)
assert(huge[1].Production == "3.520000000000e34", "big-number output survives instead of reading as 0/s")

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
local publicRecord = fs.readFile("src/Server/AstralForge/Modules/ProfileMath.luau#PublicPlayerRecord")
for _, field in { "DetailedInventory", "EquippedItems", "ItemCount", "Boosts =" } do
	assert(not string.find(publicRecord, field, 1, true), "public player records must not expose " .. field)
end
local view = fs.readFile("src/Client/AstralForge/UiCore.luau#PlayerlistOverlay")
assert(string.find(view, 'SharedData("PlayerlistModel")', 1, true), "player list uses the model")
assert(not string.find(view, "WatchInventory", 1, true) and not string.find(view, "PlayerInventoryViewerModal", 1, true), "inventory viewer removed completely")
assert(string.find(view, "local function ReportSheet", 1, true), "report sheet")
local start = assert(view:find("local function playerActionLayout(", 1, true))
local finish = assert(view:find("local function PlayerRow(", start, true))
local geometry = view:sub(start, finish - 1)
local tapTarget = 48
local layout, height = luau.load(geometry .. "\nreturn playerActionLayout, detailsHeight", {
	environment = setmetatable({ TapTarget = tapTarget }, { __index = getfenv(0) }),
})()
for _, width in { 266, 288, 339, 359, 360, 417, 439, 440, 460, 544 } do
	local action = layout(width)
	local available = width - 16
	assert(action.columns * action.cellWidth + (action.columns - 1) * action.gap <= available, "integer cells must not wrap to an unreserved row")
	assert(action.rows * action.columns == 8, "all eight social actions have reserved slots with no orphan cell")
	assert(action.gap >= 10 and action.groupGap > action.gap, "actions have room between them, and more between the two groups")
	local actionTop = 8 + 2 * 40 + 6 + 22
	assert(height({ IsLocal = false }, width) >= actionTop + action.height + 10, "report button and shadow stay inside the expanded card")
	local groupRows = action.rows / 2
	assert(action.primaryHeight == groupRows * tapTarget + (groupRows - 1) * action.gap, "primary actions keep the full touch-target height")
	assert(action.secondaryCellHeight >= 40, "secondary actions stay comfortably tappable")
	assert(action.height == action.primaryHeight + action.groupGap + action.secondaryHeight, "both groups are reserved")
end
assert(view:find("actionGroup(\"Primary\", 0, actionLayout.primaryHeight, TapTarget", 1, true), "primary cells use tested integer geometry")
assert(view:find("CellSize = UDim2.fromOffset(actionLayout.cellWidth, cellHeight)", 1, true), "rendered cells use tested integer geometry")
assert(view:find("FillDirectionMaxCells = actionLayout.columns", 1, true), "rendered action columns are explicit")
assert(view:find("FillDirectionMaxCells = 3", 1, true), "stat grid stays three columns")
assert(view:find('text = "MESSAGE"', 1, true) and view:find("onMessage(row.UserId)", 1, true), "player card can open a private message")
assert(view:find('dispatch("VisitPlot", { UserId = row.UserId })', 1, true), "player card can visit their plot")
assert(view:find('dispatch("CrewInvite", { UserId = row.UserId }', 1, true) and view:find('text = if _param.crewmate then "IN CREW" else "CREW"', 1, true), "player card can invite to a crew")
local shell = fs.readFile("src/Client/AstralForge/UiCore.luau")
assert(shell:find('navigate("Chat")\n\t\t\tchat.openWhisper(userId)', 1, true), "MESSAGE routes into Chat on the whisper thread")
assert(shell:find("useGameChat(page == \"Chat\", true, dispatch, state.Settings)", 1, true), "chat hook gets dispatch for whispers and global")
assert(view:find("setWidth(math.floor(host.AbsoluteSize.X))",1,true),"card geometry follows its actual padded/scrollbar-constrained width")
assert(view:find("connection:Disconnect()",1,true),"card measurement unsubscribes on unmount")
for _,file in {
	"src/Client/AstralForge/LayoutKit.luau",
	"src/Client/AstralForge/pages/PagesCore.luau",
	"src/Client/AstralForge/pages/PagesProgress.luau",
} do
	local source=fs.readFile(file)
	assert(not source:find("CellSize = UDim2.new(1 / count, -(columnGap",1,true), "shared grid must reserve integer gutters")
	assert(not source:find("CellSize = UDim2.new(1 / columns, -8 *",1,true), "inventory grid must reserve integer gutters")
	assert(not source:find("CellSize = UDim2.new(1 / shortcutCols, -8 *",1,true), "shortcut grid must reserve integer gutters")
	assert(not source:find("-math.floor(rowGap * (worldColumns",1,true), "world grid must round gutter reservation up")
end
for columns=2,6 do
	for gap=6,10 do
		for width=266,550 do
			local cell=math.floor(width/columns-math.ceil(gap*(columns-1)/columns))
			assert(cell*columns+gap*(columns-1)<=width, "scale grids must fit their declared columns at every pixel width")
		end
	end
end

print("verify_playerlist: ok")

--!strict
-- Actual preview backends: gating, transaction cancellation, serialization and pagination.
local Ordered = require("../src/Server/AstralForge/Modules/PreviewStores")
local Data = require("../src/Server/AstralForge/Modules/PreviewDataStores")

assert(Ordered.enabled(true, 0, true))
assert(not Ordered.enabled(false, 0, true))
assert(not Ordered.enabled(true, 10767559102, true))
assert(not Ordered.enabled(true, 0, false))
local function nativeFail(_name: string): never
	error("Native accessor must not run in an allowed preview")
end
local store = Data.data("ProfileFixture", true, nativeFail)
assert(store == Data.data("ProfileFixture", true, nativeFail))
assert(not pcall(function()
	Data.data("ProfileFixture", false, nativeFail)
end), "published/native failures must propagate")
local profile = { Cash = "1e400", Keys = { Titan = 5 }, Flag = false }
store:SetAsync("Player", profile, { 42 })
profile.Keys.Titan = 999
local value, keyInfo = store:GetAsync("Player")
assert(type(value) == "table" and value.Cash == "1e400" and value.Flag == false)
assert(type(value.Keys) == "table" and value.Keys.Titan == 5)
assert(keyInfo ~= nil and keyInfo:GetUserIds()[1] == 42)
value.Keys.Titan = 77
local copy = store:GetAsync("Player")
assert(type(copy) == "table" and type(copy.Keys) == "table" and copy.Keys.Titan == 5)
store:UpdateAsync("Player", function(draft)
	assert(type(draft) == "table")
	draft.Cash = "erased"
	return nil
end)
assert(not pcall(function()
	store:UpdateAsync("Player", function()
		error("transform failure")
	end)
end))
assert(not pcall(function()
	store:UpdateAsync("Player", function()
		coroutine.yield()
		return "bad"
	end)
end))
copy = store:GetAsync("Player")
assert(type(copy) == "table" and copy.Cash == "1e400", "cancel/error/yield must not commit")
assert(not pcall(function()
	store:SetAsync("Player", math.huge)
end))
local cycle: Data.Dictionary = {}
cycle.Self = cycle
assert(not pcall(function()
	store:SetAsync("Player", cycle)
end))
store:UpdateAsync("Player", function(draft)
	assert(type(draft) == "table")
	draft.Cash = "1e500"
	return draft, { 43 }, { Source = "Preview" }
end)
local updated, metadata = store:GetAsync("Player")
assert(type(updated) == "table" and updated.Cash == "1e500")
assert(metadata ~= nil and metadata:GetMetadata().Source == "Preview" and metadata:GetUserIds()[1] == 43)
store:SetAsync("False", false)
assert(store:GetAsync("False") == false)
store:RemoveAsync("False")
assert(store:GetAsync("False") == nil)
store:SetAsync("Queue_B", "B")
store:SetAsync("Queue_A", "A")
local keys = store:ListKeysAsync("Queue_", 1)
assert(not keys.IsFinished and keys:GetCurrentPage()[1].KeyName == "Queue_A")
keys:AdvanceToNextPageAsync()
assert(keys.IsFinished and keys:GetCurrentPage()[1].KeyName == "Queue_B")
assert(#store:ListKeysAsync("Absent"):GetCurrentPage() == 0)

local board = Ordered.ordered("RankFixture", true, nativeFail)
board:SetAsync("B", 20)
board:SetAsync("A", 20)
board:SetAsync("C", 5)
local pages = board:GetSortedAsync(false, 2)
assert(not pages.IsFinished)
local rows = pages:GetCurrentPage()
assert(rows[1].key == "A" and rows[2].key == "B")
rows[1].value = 0
assert(pages:GetCurrentPage()[1].value == 20)
pages:AdvanceToNextPageAsync()
assert(pages.IsFinished and pages:GetCurrentPage()[1].key == "C")
assert(#board:GetSortedAsync(true, 100, 10, 20):GetCurrentPage() == 2)
assert(not pcall(function()
	board:SetAsync("Invalid", 0 / 0)
end))
print(
	"[TEST] unpublished-only preview gating, clone isolation, canceled/failed/yielding writes, metadata and sorted pages passed"
)

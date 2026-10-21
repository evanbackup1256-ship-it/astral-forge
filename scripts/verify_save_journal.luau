--!nocheck
-- Recovery journal size: saves written before the compact journal held 12 full copies of the
-- big bags (a maxed star grid is ~200 KB), which put Meta at ~2.4 MB of the 4 MB DataStore cap.
-- A bloated fixture must load and save with Meta under 100 KB, losslessly (every entry still
-- resolves to the snapshot it held, Restore still works), and integrity recovery still works.
local H = require("./_server_harness")
local serde = require("@lune/serde")
local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end
local function deepCopy(v) if type(v) ~= "table" then return v end local o = {} for k, x in v do o[k] = deepCopy(x) end return o end
local function deepEqual(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in a do if not deepEqual(v, b[k]) then return false end end
	for k in b do if a[k] == nil then return false end end
	return true
end
local function kb(v) return #serde.encode("json", v) / 1024 end

local DS = H.load("Server/AstralForge/Services/DataService")
local PI = H.load("Server/AstralForge/Services/Security/ProfileIntegrity")
local DataTemplate = H.load("Server/AstralForge/DataTemplate")
local GameConfig = H.load("Shared/AstralForge/Shared/GameConfig")
local SaveSize = H.load("Server/AstralForge/Modules/SaveSize")

-- a late-game save: every star grid node owned
local profile = DataTemplate.New()
profile.Rebirths = 5000
local grid = 0
for _, node in GameConfig.GridUpgrades do
	grid += 1
	profile.GridUpgrades[node.Id] = math.min(node.MaxLevel or 1, 3)
end
for _, machine in GameConfig.Machines do profile.Machines[machine.Id] = 5 end
check(grid > 5000, "fixture owns the whole star grid (" .. grid .. " nodes)")
profile = DS.normalizeStoredProfile(profile)

-- legacy journal: 12 entries, each a full copy, the grid changing a little between saves
local legacyMeta = profile.Meta
legacyMeta.Transactions = {}
local legacy = {}
for i = 1, 12 do
	local ids = {}
	for id in profile.GridUpgrades do table.insert(ids, id) end
	table.sort(ids)
	profile.GridUpgrades[ids[i]] = (profile.GridUpgrades[ids[i]] or 0) + 1
	profile.Cash = 1000 * i
	local snapshot = {
		Cash = profile.Cash, Vault = profile.Vault, Cores = profile.Cores, Stardust = profile.Stardust,
		Rebirths = profile.Rebirths, RunCash = profile.RunCash, LifetimeCash = profile.LifetimeCash,
		Zone = profile.Zone, CurrentZone = profile.CurrentZone,
		Domain = deepCopy(profile.Domain), Continuum = deepCopy(profile.Continuum),
		Machines = deepCopy(profile.Machines), Research = deepCopy(profile.Research),
		GridUpgrades = deepCopy(profile.GridUpgrades), BoostInventory = deepCopy(profile.BoostInventory),
		Items = { NextId = 1, Essence = 0, Keys = {} }, Anomaly = { Fragments = 0, Stabilizations = 0 },
	}
	local entry = { Id = "e" .. i, At = i, Revision = i, Label = "save", Snapshot = snapshot, Hash = PI.Hash(snapshot) }
	table.insert(legacyMeta.Transactions, entry)
	legacy[i] = { Id = entry.Id, Hash = entry.Hash, Snapshot = deepCopy(snapshot) }
end
PI.Seal(profile)
-- deepCopy stands in for the DataStore round trip (sizes are measured as JSON)
local stored = deepCopy(profile)
local beforeMeta, beforeSave = kb(stored.Meta), kb(stored)
check(beforeMeta > 1500, string.format("legacy Meta is bloated (%.0f KB)", beforeMeta))
local measure = SaveSize.Measure(stored, function(v) return serde.encode("json", v) end)
check(measure.Top[1].Field == "Meta" and measure.MetaTop[1].Field == "Transactions", "size warning breaks Meta down and names Transactions")
check(string.find(SaveSize.Describe(measure), "Meta: Transactions", 1, true) ~= nil, "warning text lists the Meta subkeys")

-- load: integrity verifies the legacy save, then normalize migrates the journal
local verified, vmsg = PI.VerifyAndRecover(stored)
check(verified == true, "legacy save verifies")
local loaded = DS.normalizeStoredProfile(stored)
local resolved = PI.ResolveJournal(loaded)
local lossless = true
for i = 1, 12 do
	if not deepEqual(resolved[i], legacy[i].Snapshot) or PI.Hash(resolved[i]) ~= legacy[i].Hash then lossless = false end
end
check(lossless, "every migrated entry resolves to exactly its old snapshot and hash")

-- save: what the server writes (Record + CompactForSave on the save snapshot)
local snapshot = DS.normalizeStoredProfile(deepCopy(loaded))
PI.Record(snapshot, "save", 13)
PI.CompactForSave(snapshot)
PI.Seal(snapshot)
local written = deepCopy(snapshot)
local afterMeta = kb(written.Meta)
check(afterMeta < 100, string.format("saved Meta is under 100 KB (%.1f KB, was %.0f KB)", afterMeta, beforeMeta))
check(#written.Meta.Transactions == 12, "journal still keeps 12 entries")
print(string.format("  journal: Meta %.0f KB -> %.1f KB; whole save %.0f KB -> %.0f KB", beforeMeta, afterMeta, beforeSave, kb(written)))

-- next load of the compact save: verifies, every entry valid, rollback restores the old grid
check(PI.VerifyAndRecover(deepCopy(written)) == true, "compact save verifies on load")
local again = DS.normalizeStoredProfile(deepCopy(written))
local allValid = true
for _, row in PI.Journal(again) do if not row.Valid then allValid = false end end
check(allValid, "every journal entry is valid after a compact round trip")
local again2 = PI.ResolveJournal(again)
check(deepEqual(again2[11].GridUpgrades, legacy[12].Snapshot.GridUpgrades), "an old entry still holds its full grid after the round trip")
local ok = PI.Restore(again, "e3")
check(ok == true and deepEqual(again.GridUpgrades, legacy[3].Snapshot.GridUpgrades) and again.Cash == legacy[3].Snapshot.Cash, "admin rollback to an old entry restores its grid and Flux")
local resaved = DS.normalizeStoredProfile(deepCopy(again))
PI.Record(resaved, "save", 14)
PI.CompactForSave(resaved)
check(kb(resaved.Meta) < 100, "Meta stays small save after save")

-- integrity recovery: a damaged currency recovers from the newest entry
local damaged = deepCopy(written)
damaged.Cash = 99999999
local okD, msgD = PI.VerifyAndRecover(damaged)
check(okD == false and string.find(msgD, "recovered critical state", 1, true) ~= nil and damaged.Cash == written.Meta.Transactions[12].Snapshot.Cash, "damaged Flux is recovered from the journal")
-- a damaged big bag can't use the anchor, but currencies still recover (load is not rejected)
local damagedGrid = deepCopy(written)
local anyId = next(damagedGrid.GridUpgrades)
damagedGrid.GridUpgrades[anyId] = 777
damagedGrid.Cash = 1
local okG, msgG = PI.VerifyAndRecover(damagedGrid)
check(okG == false and string.find(msgG, "recovered critical state", 1, true) ~= nil, "a damaged grid still recovers currencies (" .. tostring(msgG) .. ")")
check(damagedGrid.Cash == written.Meta.Transactions[12].Snapshot.Cash, "and Flux comes back")

if #failures > 0 then
	for _, f in failures do print("  FAIL: " .. f) end
	error(string.format("save journal failed: %d problems", #failures))
end
print(string.format("[TEST] save journal: %d checks (bloated legacy journal migrates losslessly, Meta under 100 KB, rollback and recovery still work) passed", checks))

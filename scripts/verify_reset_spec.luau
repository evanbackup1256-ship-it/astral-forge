--!nocheck
-- Rewrite 08: Rebirth and Ascension resets come from ResetSpec. Checks the field lists, that
-- carried machines keep their relics, that Ascension drops machine relics, stops AutoForge,
-- resets Lab routing and keeps Domain lifetime totals. Run `npx rbxtsc` first.
local H = require("./_server_harness")

local failures, checks = {}, 0
local function check(cond, label)
	checks += 1
	if not cond then table.insert(failures, label) end
end

local R = H.load("Shared/AstralForge/Shared/ResetSpec")
local ctx = { StartingCash = 250, LabBaseCells = 12 }

-- field lists are the contract
local rf = table.concat(R.fieldsOf(R.Rebirth), ",")
check(rf == "Cash,Vault,RunCash,Zone,CurrentZone,Machines", "rebirth fields: " .. rf)
local af = table.concat(R.fieldsOf(R.Ascension), ",")
check(af == "Domain,Cash,Vault,Cores,Rebirths,RunCash,Zone,CurrentZone,Machines", "ascension fields: " .. af)

-- rebirth
do
	local p = {
		Cash = 9e9, Vault = 5, RunCash = 7, Zone = 4, CurrentZone = 3, Cores = 42, Rebirths = 6, Stardust = 3,
		Machines = { StellarCore = 9, Fuser = 4 },
		Items = { Equipped = { ["Machine:StellarCore"] = "a", ["Machine:Fuser"] = "b", ["Companion:Slot"] = "c" } },
	}
	R.applyReset(R.Rebirth, p, { StartingCash = 250, LabBaseCells = 12, Carry = { Cash = 1000, Machines = { StellarCore = 2 } } })
	check(p.Cash == 1000 and p.Vault == 0 and p.RunCash == 0 and p.Zone == 1 and p.CurrentZone == 1, "rebirth resets the run")
	check(p.Machines.StellarCore == 2 and p.Machines.Fuser == nil, "rebirth takes the carried machines")
	check(p.Cores == 42 and p.Rebirths == 6 and p.Stardust == 3, "rebirth leaves cores, count and Stardust to the caller")
	check(p.Items.Equipped["Machine:StellarCore"] == "a", "carried machine keeps its relic")
	check(p.Items.Equipped["Machine:Fuser"] == nil, "dropped machine loses its relic")
	check(p.Items.Equipped["Companion:Slot"] == "c", "non-machine slots untouched")
end

-- ascension
do
	local p = {
		Cash = 1, Vault = 2, Cores = 3, Rebirths = 40, RunCash = 4, Zone = 6, CurrentZone = 6,
		Machines = { StellarCore = 50, Fuser = 2 },
		Domain = { Rank = 9, Essence = 77, TotalRebirthsSpent = 12.7, TotalCoresSpent = -5, SkillPoints = 3, Links = { x = 1 } },
		AutoForge = { Enabled = true, MachineId = "Fuser" },
		Lab = { Routing = { Production = 1, Storage = 5, Tap = 6 } },
		Items = { Equipped = { ["Machine:StellarCore"] = "a", ["Companion:Slot"] = "c" } },
		Ascension = { Rank = 2 },
	}
	R.applyReset(R.Ascension, p, ctx)
	check(p.Cash == 250 and p.Vault == 0 and p.Cores == 0 and p.Rebirths == 0 and p.Zone == 1, "ascension resets currencies")
	check(p.Machines.StellarCore == 1 and p.Machines.Fuser == nil, "ascension restarts on one Stellar Core")
	check(p.Domain.Rank == 0 and p.Domain.Essence == 0 and next(p.Domain.Links) == nil, "domain resets")
	check(p.Domain.TotalRebirthsSpent == 12 and p.Domain.TotalCoresSpent == 0, "domain lifetime totals kept and cleaned")
	check(p.AutoForge.Enabled == false and p.AutoForge.MachineId == "StellarCore", "AutoForge stops")
	check(p.Lab.Routing.Production == 12 and p.Lab.Routing.Storage == 0 and p.Lab.Routing.Tap == 0, "lab routing reset")
	check(p.Items.Equipped["Machine:StellarCore"] == nil and p.Items.Equipped["Companion:Slot"] == "c", "machine relics unequipped only")
	check(p.Ascension.Rank == 2, "ascension state left to the caller")
end

-- each reset builds a fresh table, never a shared one
do
	local a, b = { Domain = {} }, { Domain = {} }
	R.applyReset(R.Ascension, a, ctx)
	R.applyReset(R.Ascension, b, ctx)
	check(a.Machines ~= b.Machines and a.Domain ~= b.Domain, "fresh tables per reset")
end

-- missing optional sections are fine
do
	local p = {}
	R.applyReset(R.Ascension, p, ctx)
	check(p.AutoForge == nil and p.Lab == nil and p.Items == nil, "absent sections are not created")
end

if #failures > 0 then
	for _, f in failures do print("FAIL " .. f) end
	error(`verify_reset_spec: {#failures}/{checks} failed`)
end
print(`verify_reset_spec: {checks} checks passed`)

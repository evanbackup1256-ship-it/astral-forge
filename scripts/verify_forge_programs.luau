--!nocheck
-- Forge Programs (v8 #8): rule schema and pairings, save cleanup, the unlock, ProgramAct
-- (save/toggle/delete, five-rule cap), which rules are due and their cooldowns, the pause flag,
-- and rules carried out through GameService's own actions. Run `npx rbxtsc` first.
local H = require("./_server_harness")

local failures = {}
local checks = 0
local function check(cond, label)
	checks += 1
	if not cond then table.insert(failures, label) end
end

H.mock("Server/AstralForge/Runtime/ServerNetwork", { ServerEvents = H.Stub, ServerFunctions = H.Stub })
H.env.Enum = setmetatable({}, { __index = function(_, cat)
	return setmetatable({}, { __index = function(_, item) return cat .. "." .. item end })
end })
local Programs = H.load("Shared/AstralForge/Shared/ForgePrograms")
local Service = H.load("Server/AstralForge/Services/Gameplay/ForgePrograms")
local HotFlags = H.load("Server/AstralForge/Services/Security/HotFlags")
local GS = H.load("Server/AstralForge/Services/GameService").GameService
local DataTemplate = H.load("Server/AstralForge/DataTemplate")
local DataService = H.load("Server/AstralForge/Services/DataService")

local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in v do out[k] = deepCopy(x) end
	return out
end
local function ascended()
	local p = DataTemplate.New()
	p.Ascension.Rank = 1
	return p
end

-- schema
check(Programs.cleanRule({ Do = "Rebirth", When = "RebirthGain", Arg = 2.2 }).Arg == 2, "args snap to their step")
check(Programs.cleanRule({ Do = "Rebirth", When = "RebirthGain", Arg = 99 }).Arg == 10, "args clamp to their range")
check(Programs.cleanRule({ Do = "Rebirth", When = "RebirthGain" }).Arg == 2, "a missing arg takes the default")
check(Programs.cleanRule({ Do = "Rebirth", When = "Always" }) == nil, "an action only takes its own conditions")
check(Programs.cleanRule({ Do = "Nope", When = "Always" }) == nil, "unknown actions are refused")
check(Programs.cleanRule({ Do = "EquipBest", When = "Always", Enabled = false }).Enabled == false, "a rule can be saved off")
check(Programs.cleanRule({ Do = "EquipBest", When = "Always" }).Arg == nil, "conditions without a number carry none")

-- saves
do
	local untouched = DataService.normalizeStoredProfile(deepCopy(DataTemplate.New()))
	check(untouched.AutoForge.Programs == nil, "a save that never used programs stays without them")
	local p = DataTemplate.New()
	p.AutoForge.Programs = { Rules = {
		{ Do = "EquipBest", When = "Always" }, { Do = "Rebirth", When = "Always" }, "junk",
		{ Do = "BuyCheapestMachine", When = "Affordable" }, { Do = "EquipBest", When = "AfterRebirth" },
		{ Do = "SalvageCommons", When = "InventoryOver", Arg = 5 }, { Do = "EquipBest", When = "Always" },
		{ Do = "EquipBest", When = "Always" },
	} }
	local clean = DataService.normalizeStoredProfile(deepCopy(p))
	local rules = clean.AutoForge.Programs.Rules
	check(#rules == 5, "bad rules are dropped and five are kept")
	check(rules[4].Arg == 10, "a saved number is clamped")
	check(clean.AutoForge.Enabled == false and clean.AutoForge.MachineId == "StellarCore", "Auto-Forge itself is untouched")
	local again = DataService.normalizeStoredProfile(deepCopy(clean))
	check(#again.AutoForge.Programs.Rules == 5 and again.AutoForge.Programs.Rules[4].Arg == 10, "loading twice changes nothing")
end

-- ProgramAct
do
	HotFlags.Reset()
	local fresh = DataTemplate.New()
	check(not Service.Act(fresh, { Op = "Save", Rule = { Do = "EquipBest", When = "Always" } }), "locked before the first ascension")
	local p = ascended()
	check(Service.Act(p, { Op = "Save", Rule = { Do = "EquipBest", When = "Always" } }), "a rule saves")
	check(#p.AutoForge.Programs.Rules == 1, "and is stored")
	check(not Service.Act(p, { Op = "Save", Rule = { Do = "Rebirth", When = "Always" } }), "a bad pairing is refused")
	check(Service.Act(p, { Op = "Save", Index = 1, Rule = { Do = "Rebirth", When = "RebirthGain", Arg = 3 } }), "a rule can be replaced")
	check(p.AutoForge.Programs.Rules[1].Do == "Rebirth" and p.AutoForge.Programs.Rules[1].Arg == 3, "the replacement is stored")
	check(Service.Act(p, { Op = "Toggle", Index = 1 }) and p.AutoForge.Programs.Rules[1].Enabled == false, "toggle turns it off")
	check(Service.Act(p, { Op = "Toggle", Index = 1 }) and p.AutoForge.Programs.Rules[1].Enabled == true, "and on again")
	check(not Service.Act(p, { Op = "Toggle", Index = 4 }), "a missing rule is refused")
	for _ = 1, 4 do Service.Act(p, { Op = "Save", Rule = { Do = "EquipBest", When = "Always" } }) end
	check(not Service.Act(p, { Op = "Save", Rule = { Do = "EquipBest", When = "Always" } }), "five rules at most")
	check(Service.Act(p, { Op = "Delete", Index = 1 }) and #p.AutoForge.Programs.Rules == 4, "delete removes it")
	HotFlags.Set("ForgeProgramsPaused", true, os.time() + 10)
	check(not Service.Act(p, { Op = "Delete", Index = 1 }), "paused programs can't be edited")
	HotFlags.Reset()
end

-- Due
do
	HotFlags.Reset()
	local p = ascended()
	p.AutoForge.Programs = { Rules = {
		{ Do = "BuyCheapestMachine", When = "Affordable", Enabled = true },
		{ Do = "SalvageCommons", When = "InventoryOver", Arg = 10, Enabled = true },
		{ Do = "EquipBest", When = "AfterRebirth", Enabled = true },
		{ Do = "Rebirth", When = "RebirthGain", Arg = 2, Enabled = true },
		{ Do = "EquipBest", When = "Always", Enabled = false },
	} }
	local runtime = {}
	local facts = { Now = 1000, Rebirths = 4, RebirthReady = true, RebirthCores = 150, LastRunCores = 100, CheapestAffordable = "StellarCore", CommonCount = 11 }
	local steps = Service.Due(p, runtime, facts)
	local names = {}
	for _, s in steps do table.insert(names, s.Do) end
	check(table.concat(names, ",") == "BuyCheapestMachine,SalvageCommons", "affordable buy and salvage are due; 1.5x isn't 2x; nothing was reborn; off rules skip")
	steps = Service.Due(p, runtime, facts)
	check(#steps == 0, "cooldowns hold rules back")
	facts.Now, facts.RebirthCores = 1100, 250
	steps = Service.Due(p, runtime, facts)
	names = {}
	for _, s in steps do table.insert(names, s.Do) end
	check(table.find(names, "Rebirth") ~= nil, "2.5x the last run triggers the rebirth rule")
	check(names[#names] == "Rebirth", "nothing runs after a rebirth in the same tick")
	facts.Now, facts.Rebirths = 1200, 5
	steps = Service.Due(p, runtime, facts)
	names = {}
	for _, s in steps do table.insert(names, s.Do) end
	check(table.find(names, "EquipBest") ~= nil, "equip best runs right after a rebirth")
	facts.Now = 1300
	steps = Service.Due(p, runtime, facts)
	for _, s in steps do check(s.Do ~= "EquipBest", "only once per rebirth") end
	HotFlags.Set("ForgeProgramsPaused", true, os.time() + 10)
	facts.Now = 5000
	check(#Service.Due(p, runtime, facts) == 0, "paused programs don't run")
	HotFlags.Reset()
	local fresh = DataTemplate.New()
	fresh.AutoForge.Programs = p.AutoForge.Programs
	check(#Service.Due(fresh, {}, facts) == 0, "programs don't run before the first ascension")
end

-- through GameService
local function service(profile, player)
	local data = { profile = profile }
	function data:AtomicUpdate(_, cb)
		local draft = deepCopy(self.profile)
		local r = cb(draft)
		if type(r) == "table" and r.ok == false then return false, r end
		self.profile = draft
		return true, r
	end
	function data:Get() return self.profile end
	function data:IsBusy() return false end
	return setmetatable({
		_data = data, _runtime = { [player] = {} }, _running = true,
		_toastPlayer = function() end,
		_queueStatePush = function() end,
	}, { __index = function(_, k)
		local v = GS[k]
		if v ~= nil then return v end
		return H.Stub
	end }), data
end

do
	HotFlags.Reset()
	local player = H.player("Program owner")
	local p = ascended()
	p.Cash = 1e9
	p.Items.Inventory = {}
	for i = 1, 13 do
		p.Items.Inventory["c" .. i] = { DefinitionId = "IonCoupler", Level = 1, AcquiredAt = i }
	end
	p.Items.Inventory.c13.Locked = true
	p.AutoForge.Programs = { Rules = {
		{ Do = "BuyCheapestMachine", When = "Affordable", Enabled = true },
		{ Do = "SalvageCommons", When = "InventoryOver", Arg = 10, Enabled = true },
	} }
	local s, data = service(p, player)
	local levels = 0
	for _, level in p.Machines do levels += level end
	local r = s:_programAct(player, { Op = "Toggle", Index = 2 })
	check(r and r.ok and data.profile.AutoForge.Programs.Rules[2].Enabled == false, "ProgramAct goes through _mutate")
	s:_programAct(player, { Op = "Toggle", Index = 2 })
	s:_tickForgePrograms(player, {})
	local after = 0
	for _, level in data.profile.Machines do after += level end
	check(after == levels + 1, "the buy rule bought one machine level")
	check(data.profile.Cash < 1e9, "and paid for it")
	local left = 0
	for _ in data.profile.Items.Inventory do left += 1 end
	check(left == 11, "salvage kept the protected relic plus ten commons")
	check(data.profile.Items.Inventory.c1 == nil and data.profile.Items.Inventory.c2 == nil and data.profile.Items.Inventory.c13 ~= nil, "oldest commons go first; protected relics stay")
end

if #failures > 0 then
	for _, f in failures do print("[FAIL] " .. f) end
	error(string.format("forge programs: %d of %d checks failed", #failures, checks))
end
print(string.format("[TEST] forge programs: %d checks (schema, saves, unlock, ProgramAct, due and cooldowns, pause, GameService actions) passed", checks))

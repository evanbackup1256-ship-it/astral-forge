--!nocheck
-- Expeditions v2: stances, crew roles and synergies, the forecast both sides share, odds locked at
-- launch, one-roll outcomes (Setback / Clean / Triumph), the streak, the Preview op, and v8 slots
-- without v2 fields reading as Steady with their old crew odds. Run `npx rbxtsc` first.
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
local Board = H.load("Shared/AstralForge/Shared/ExpeditionBoard")
local Service = H.load("Server/AstralForge/Services/Gameplay/ExpeditionBoard")
local HotFlags = H.load("Server/AstralForge/Services/Security/HotFlags")
local DataTemplate = H.load("Server/AstralForge/DataTemplate")
local DataService = H.load("Server/AstralForge/Services/DataService")

local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in v do out[k] = deepCopy(x) end
	return out
end
local function roller(value) return { NextNumber = function() return value end } end

local function profileWith()
	local p = DataTemplate.New()
	p.Items.Inventory = {
		a = { DefinitionId = "IonCoupler", Level = 1, AcquiredAt = 1 },
		b = { DefinitionId = "CapacityCoil", Level = 1, AcquiredAt = 2, Stars = 2 },
		c = { DefinitionId = "IonCoupler", Level = 1, AcquiredAt = 3 },
	}
	p.Items.Equipped = {}
	return p
end
local function finish(p, slot)
	p.Progression.Expeditions.Slots[slot].EndsAt = os.time() - 1
	if slot == 1 then p.Command.ActiveExpedition.EndsAt = os.time() - 1 end
end

local haul = { Rarity = "Rare", EffectKind = "Production", Stars = 0 }
local guard = { Rarity = "Rare", EffectKind = "Capacity", Stars = 0 }
local scout = { Rarity = "Rare", EffectKind = "Tap", Stars = 0 }

-- roles and route roles
do
	check(Board.roleOf("Production") == "Haul" and Board.roleOf("OfflineHours") == "Guard" and Board.roleOf("Critical") == "Scout", "effects map to roles")
	check(Board.roleOf("SomethingNew") == "Haul" and Board.roleOf(nil) == "Haul", "unknown effects default to Haul")
	check(Board.routeRole("LunarSurvey") == Board.routeRole("LunarSurvey"), "a route's role is stable")
	local seen = {}
	for i = 1, 40 do seen[Board.routeRole("HorizonRun_" .. i)] = true end
	check(seen.Haul and seen.Guard and seen.Scout, "routes spread across all three roles")
end

-- stances
do
	local careful = Board.forecast("LunarSurvey", "Careful", {}, nil, 0)
	local steady = Board.forecast("LunarSurvey", "Steady", {}, nil, 0)
	local daring = Board.forecast("LunarSurvey", "Daring", {}, nil, 0)
	check(careful.Time > steady.Time and steady.Time > daring.Time, "Careful is slowest, Daring fastest")
	check(careful.Yield < steady.Yield and steady.Yield < daring.Yield, "Daring hauls the most")
	check(careful.Risk == 0 and steady.Risk == 0 and daring.Risk > 0, "only Daring carries risk")
	check(steady.Find == 0 and #steady.Synergies == 0, "a solo run finds nothing extra and has no synergies")
	check(Board.forecast("LunarSurvey", "Bogus", {}, nil, 0).Stance == "Steady", "a bad stance reads as Steady")
end

-- crew roles, favoured route, balanced and resonant crews, companion, streak
do
	local route = "LunarSurvey"
	local role = Board.routeRole(route)
	local match = role == "Haul" and haul or role == "Guard" and guard or scout
	local other = role == "Haul" and guard or haul
	local fav = Board.forecast(route, "Steady", { match }, nil, 0)
	local plain = Board.forecast(route, "Steady", { other }, nil, 0)
	check(table.find(fav.Synergies, "Favoured") ~= nil and table.find(plain.Synergies, "Favoured") == nil, "a crew in the route's role is favoured")
	local guarded = Board.forecast(route, "Daring", { guard, guard }, nil, 0)
	local bare = Board.forecast(route, "Daring", {}, nil, 0)
	check(guarded.Risk < bare.Risk, "Guard crew cut the risk")
	local hauled = Board.forecast(route, "Steady", { haul }, nil, 0)
	check(hauled.Yield > 1, "Haul crew grow the haul")
	local scouted = Board.forecast(route, "Steady", { scout }, nil, 0)
	check(scouted.Time < 1, "Scout crew shorten the trip")
	local balanced = Board.forecast(route, "Steady", { haul, guard, scout }, nil, 0)
	check(table.find(balanced.Synergies, "Balanced") ~= nil, "three roles make a balanced crew")
	local resonant = Board.forecast(route, "Steady", { haul, haul, haul }, nil, 0)
	check(table.find(resonant.Synergies, "Resonant") ~= nil, "three of one role resonate")
	local withCompanion = Board.forecast(route, "Steady", {}, match.EffectKind, 0)
	check(table.find(withCompanion.Synergies, "Companion") ~= nil and withCompanion.Yield > 1, "a matching companion adds to the haul")
	local streak5 = Board.forecast(route, "Steady", {}, nil, 5)
	local streak50 = Board.forecast(route, "Steady", {}, nil, 50)
	check(streak5.Yield > 1 and streak50.Yield == 1 + Board.STREAK_STEP * Board.STREAK_CAP, "the streak adds to the haul up to its cap")
	local stacked = Board.forecast(route, "Daring", { { Rarity = "Astral", EffectKind = "Capacity", Stars = 5 }, { Rarity = "Astral", EffectKind = "Capacity", Stars = 5 }, { Rarity = "Astral", EffectKind = "Capacity", Stars = 5 } }, "Capacity", 99)
	check(stacked.Risk >= 0 and stacked.Find <= 0.95 and stacked.Time >= 0.35 and stacked.Yield <= 10, "odds stay in range")
end

-- outcome rolls
do
	check(Board.outcomeFor(0.1, 0.3, 0.5) == "Setback", "a roll under the risk is a setback")
	check(Board.outcomeFor(0.4, 0.3, 0.5) == "Triumph", "the next part of the range is a triumph")
	check(Board.outcomeFor(0.9, 0.3, 0.5) == "Clean", "the rest is clean")
	check(Board.outcomeFor(0, 0, 0) == "Clean", "no crew, no risk: always clean")
end

-- odds lock in at launch and survive a save round trip
do
	HotFlags.Reset()
	local p = profileWith()
	local ok, msg, extra = Service.Launch(p, { Slot = 1, Id = "LunarSurvey", Crew = { "a", "b" }, Stance = "Daring" })
	check(ok, "a Daring launch works (" .. tostring(msg) .. ")")
	check(extra and extra.Stance == "Daring" and type(extra.Synergies) == "table", "launch reports the stance and synergies")
	local slot = p.Progression.Expeditions.Slots[1]
	check(slot.Stance == "Daring" and slot.Risk > 0 and slot.Yield > 1 and slot.Find > 0, "the slot stores its odds")
	local steady = profileWith()
	Service.Launch(steady, { Slot = 1, Id = "LunarSurvey" })
	local s2 = steady.Progression.Expeditions.Slots[1]
	check(slot.EndsAt - slot.StartedAt < s2.EndsAt - s2.StartedAt or s2.EndsAt - s2.StartedAt <= 10, "Daring comes back sooner")
	check(s2.Stance == "Steady", "no stance launches Steady")
	local clean = DataService.normalizeStoredProfile(deepCopy(p))
	local back = clean.Progression.Expeditions.Slots[1]
	check(back.Stance == "Daring" and back.Risk == slot.Risk and back.Yield == slot.Yield and back.Find == slot.Find, "odds survive load")
	local state = Service.State(p)
	check(state.Slots[1].Stance == "Daring" and state.Slots[1].Risk == slot.Risk and state.Streak == 0, "state carries the odds and streak")
end

-- setback, clean and triumph claims, and the streak
do
	HotFlags.Reset()
	local p = profileWith()
	Service.Launch(p, { Slot = 1, Id = "LunarSurvey", Crew = { "a" }, Stance = "Daring" })
	local risk = p.Progression.Expeditions.Slots[1].Risk
	finish(p, 1)
	local cash = p.Cash
	local ok, text, extra = Service.Claim(p, { Slot = 1 }, roller(risk * 0.5))
	check(ok and extra.Outcome == "Setback", "a low roll on Daring is a setback (" .. tostring(text) .. ")")
	check(extra.Bonus == nil and extra.ArtifactId == nil, "a setback finds nothing extra")
	check(extra.Streak == 0 and p.Progression.Expeditions.Streak == nil, "a setback leaves no streak")
	check(p.Command.ExpeditionsCompleted == 1, "a setback still counts as a trip")

	Service.Launch(p, { Slot = 1, Id = "LunarSurvey", Crew = { "a" } })
	finish(p, 1)
	local ok2, _, extra2 = Service.Claim(p, { Slot = 1 }, roller(0.999))
	check(ok2 and extra2.Outcome == "Clean" and extra2.Bonus == nil, "a high roll is clean")
	check(extra2.Streak == 1 and p.Progression.Expeditions.Streak == 1, "a clean run starts a streak")

	Service.Launch(p, { Slot = 2, Id = "LunarSurvey", Crew = { "b", "c" } })
	finish(p, 2)
	local ok3, _, extra3 = Service.Claim(p, { Slot = 2 }, roller(0))
	check(ok3 and extra3.Outcome == "Triumph" and extra3.Bonus ~= nil, "a crewed Steady run with a low roll triumphs and pays loot")
	check(extra3.Streak == 2 and p.Progression.Expeditions.Best == 2, "the streak and best grow")
	local saved = DataService.normalizeStoredProfile(deepCopy(p))
	check(saved.Progression.Expeditions.Streak == 2 and saved.Progression.Expeditions.Best == 2, "the streak survives load")

	-- recall keeps the streak
	Service.Launch(p, { Slot = 3, Id = "LunarSurvey" })
	Service.Recall(p, { Slot = 3 })
	check(p.Progression.Expeditions.Streak == 2, "recalling doesn't break the streak")
	-- an early claim is refused and leaves the run alone
	Service.Launch(p, { Slot = 3, Id = "LunarSurvey" })
	check(not Service.Claim(p, { Slot = 3 }, roller(0)) and p.Progression.Expeditions.Slots[3].Id == "LunarSurvey", "an unfinished run can't be claimed")
end

-- v8 slots (no stance) read as Steady with the old crew odds
do
	local p = profileWith()
	p.Progression.Expeditions = { Slots = { { Id = "LunarSurvey", Crew = { "a" }, StartedAt = 1, EndsAt = 2 } } }
	local clean = DataService.normalizeStoredProfile(deepCopy(p))
	local slot = clean.Progression.Expeditions.Slots[1]
	check(slot.Id == "LunarSurvey" and slot.Stance == nil, "a v8 slot loads unchanged")
	local state = Service.State(clean)
	check(state.Slots[1].Stance == "Steady" and state.Slots[1].Risk == 0 and state.Slots[1].Find > 0.45, "it reads as Steady with the v8 crew odds")
	local ok, _, extra = Service.Claim(clean, { Slot = 1 }, roller(0))
	check(ok and extra.Outcome == "Triumph", "it claims with the v8 rules")
	-- junk odds are clamped
	local junk = profileWith()
	junk.Progression.Expeditions = { Slots = { { Id = "LunarSurvey", Crew = {}, StartedAt = 1, EndsAt = 2, Stance = "Daring", Yield = 1e9, Risk = 7, Find = -3 } } }
	local j = DataService.normalizeStoredProfile(deepCopy(junk)).Progression.Expeditions.Slots[1]
	check(j.Yield <= 10 and j.Risk <= 0.9 and j.Find >= 0, "stored odds are clamped")
end

-- Preview matches what Launch locks in
do
	HotFlags.Reset()
	local p = profileWith()
	local ok, _, odds = Service.Preview(p, { Id = "LunarSurvey", Crew = { "a", "b" }, Stance = "Careful" })
	check(ok and odds.Stance == "Careful", "preview answers")
	Service.Launch(p, { Slot = 1, Id = "LunarSurvey", Crew = { "a", "b" }, Stance = "Careful" })
	local slot = p.Progression.Expeditions.Slots[1]
	check(slot.Yield == odds.Yield and slot.Risk == odds.Risk and slot.Find == odds.Find, "launch locks in the previewed odds")
	check(not Service.Preview(p, { Id = "LunarSurvey", Crew = { "a" } }), "preview refuses crew that's away")
	check(Service.Act(p, { Op = "Preview", Id = "LunarSurvey" }), "Preview is an ExpeditionAct op")
end

if #failures > 0 then
	for _, f in failures do print("[FAIL] " .. f) end
	error(string.format("expeditions v2: %d of %d checks failed", #failures, checks))
end
print(string.format("[TEST] expeditions v2: %d checks (stances, roles, synergies, outcomes, streak, v8 slots, preview) passed", checks))

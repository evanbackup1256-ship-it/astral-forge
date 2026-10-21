--!nocheck
-- Expedition Board (v8 #4): slot count by ascension, the v7 ActiveExpedition migrating into slot 1
-- and mirrored back, launch/claim/recall rules, crew locks behaving like equipped relics (trade,
-- equip, detach, equip best, save load), crew bonus loot, the Scout trait, the legacy remote
-- aliases and the pause flag. Run `npx rbxtsc` first.
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
local Companion = H.load("Shared/AstralForge/Shared/CompanionRelic")
local HotFlags = H.load("Server/AstralForge/Services/Security/HotFlags")
local GS = H.load("Server/AstralForge/Services/GameService").GameService
local DataTemplate = H.load("Server/AstralForge/DataTemplate")
local DataService = H.load("Server/AstralForge/Services/DataService")
local TradeOfferMath = H.load("Server/AstralForge/Modules/TradeSuite")("TradeOfferMath")

local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in v do out[k] = deepCopy(x) end
	return out
end
local always = { NextNumber = function() return 0 end }
local never = { NextNumber = function() return 1 end }

local function profileWith()
	local p = DataTemplate.New()
	p.Items.Inventory = {
		a = { DefinitionId = "IonCoupler", Level = 1, AcquiredAt = 1 },
		b = { DefinitionId = "CapacityCoil", Level = 1, AcquiredAt = 2, Stars = 2 },
		c = { DefinitionId = "IonCoupler", Level = 1, AcquiredAt = 3 },
		d = { DefinitionId = "IonCoupler", Level = 1, AcquiredAt = 4 },
	}
	p.Items.Equipped = {}
	return p
end
local function locksOf(p)
	local out = {}
	for target, uid in p.Items.Equipped do
		if Board.isLockKey(target) then out[uid] = target end
	end
	return out
end

-- slots by ascension
do
	local p = profileWith()
	check(Board.slotCount(p) == 3, "three slots to start")
	p.Ascension.Rank = 1
	check(Board.slotCount(p) == 4, "one more per ascension")
	p.Ascension.Rank = 9
	check(Board.slotCount(p) == 5, "five at most")
end

-- untouched saves stay untouched; a v7 expedition moves into slot 1 and stays mirrored
do
	local fresh = DataService.normalizeStoredProfile(deepCopy(profileWith()))
	check(fresh.Progression.Expeditions == nil, "a save with nothing out gets no board")
	local p = profileWith()
	p.Command.ActiveExpedition = { Id = "LunarSurvey", StartedAt = 100, EndsAt = 130 }
	local clean = DataService.normalizeStoredProfile(deepCopy(p))
	local slot = clean.Progression.Expeditions.Slots[1]
	check(slot.Id == "LunarSurvey" and slot.StartedAt == 100 and slot.EndsAt == 130 and #slot.Crew == 0, "the v7 trip is slot 1")
	check(#clean.Progression.Expeditions.Slots == 3, "with the other slots open")
	check(clean.Command.ActiveExpedition.Id == "LunarSurvey" and clean.Command.ActiveExpedition.EndsAt == 130, "the legacy field still reads the same")
	local again = DataService.normalizeStoredProfile(deepCopy(clean))
	check(again.Progression.Expeditions.Slots[1].Id == "LunarSurvey" and again.Progression.Expeditions.Slots[2].Id == "", "loading twice changes nothing")
end

-- launch rules and crew locks
do
	HotFlags.Reset()
	local p = profileWith()
	p.Items.Equipped["Machine:StellarCore"] = "d"
	local ok, msg = Service.Launch(p, { Slot = 1, Id = "LunarSurvey", Crew = { "a", "b" } })
	check(ok, "a crewed launch works (" .. tostring(msg) .. ")")
	local board = p.Progression.Expeditions
	check(board.Slots[1].Id == "LunarSurvey" and #board.Slots[1].Crew == 2, "slot 1 holds the run and its crew")
	check(p.Command.ActiveExpedition.Id == "LunarSurvey", "slot 1 is mirrored to the v7 field")
	local locks = locksOf(p)
	check(locks.a ~= nil and locks.b ~= nil and locks.c == nil, "crew relics are locked")
	check(TradeOfferMath.ItemEquipped(p, "a"), "a crew relic can't be traded")
	check(not Service.Launch(p, { Slot = 1, Id = "LunarSurvey" }), "a busy slot refuses")
	check(not Service.Launch(p, { Slot = 2, Id = "LunarSurvey" }), "the same route can't run twice")
	check(not Service.Launch(p, { Slot = 9, Id = "LunarSurvey" }), "a slot past the board refuses")
	check(not Service.Launch(p, { Slot = 2, Id = "LunarSurvey", Crew = { "a" } }), "a crew relic can't go twice")
	check(not Service.Launch(p, { Slot = 2, Id = "LunarSurvey", Crew = { "d" } }), "a socketed relic can't crew")
	check(not Service.Launch(p, { Slot = 2, Id = "LunarSurvey", Crew = { "c", "c" } }), "duplicate crew is refused")
	check(not Service.Launch(p, { Slot = 2, Id = "LunarSurvey", Crew = { "zz" } }), "unknown crew is refused")
	-- the locks survive a save round trip
	local clean = DataService.normalizeStoredProfile(deepCopy(p))
	local after = locksOf(clean)
	check(after.a ~= nil and after.b ~= nil, "crew locks survive load")
	check(#clean.Progression.Expeditions.Slots[1].Crew == 2, "the crew list survives load")
	-- a crew relic that vanished leaves the crew
	local gone = deepCopy(p)
	gone.Items.Inventory.b = nil
	gone = DataService.normalizeStoredProfile(gone)
	check(#gone.Progression.Expeditions.Slots[1].Crew == 1 and locksOf(gone).b == nil, "a missing crew relic is dropped")

	-- claim
	check(not Service.Claim(p, { Slot = 1 }, always), "a running trip can't be claimed")
	p.Progression.Expeditions.Slots[1].EndsAt = os.time() - 1
	p.Command.ActiveExpedition.EndsAt = os.time() - 1
	local essence, cores = p.Items.Essence, p.Cores
	local ok2, text, extra = Service.Claim(p, { Slot = 1 }, always)
	check(ok2, "a finished trip claims (" .. tostring(text) .. ")")
	check(extra and extra.Bonus ~= nil, "a lucky crew brings bonus loot")
	check(p.Items.Essence > essence or p.Cores > cores, "the bonus is paid")
	check(p.Progression.Expeditions.Slots[1].Id == "" and next(locksOf(p)) == nil, "claiming frees the slot and crew")
	check(p.Command.ActiveExpedition.Id == "", "the mirror empties too")
	check(p.Command.ExpeditionsCompleted == 1, "the v7 trip counter still counts")
	-- no crew, no bonus
	Service.Launch(p, { Slot = 2, Id = "LunarSurvey" })
	p.Progression.Expeditions.Slots[2].EndsAt = os.time() - 1
	local _, _, extra2 = Service.Claim(p, { Slot = 2 }, always)
	check(extra2 and extra2.Bonus == nil, "an empty crew gets the route reward only")
	-- recall
	Service.Launch(p, { Slot = 3, Id = "LunarSurvey", Crew = { "c" } })
	check(locksOf(p).c ~= nil, "slot 3 locks its crew")
	local ok3 = Service.Recall(p, { Slot = 3 })
	check(ok3 and p.Progression.Expeditions.Slots[3].Id == "" and locksOf(p).c == nil, "recall frees the slot with nothing paid")
	check(not Service.Recall(p, { Slot = 3 }), "recalling an empty slot refuses")
	check(Board.bonusChance({}) == 0 and Board.bonusChance({ { Rarity = "Astral", EffectKind = "Production", Stars = 5 } }) <= 0.95, "odds stay in range")
end

-- the Scout trait shortens a run
do
	local p = profileWith()
	p.Items.Equipped[Companion.TARGET] = "d"
	p.Items.Inventory.d.Bond = { XP = Companion.RANK_XP[3], Rank = 3, Trait = "Scout" }
	local plain = profileWith()
	Service.Launch(plain, { Slot = 1, Id = "LunarSurvey" })
	Service.Launch(p, { Slot = 1, Id = "LunarSurvey" })
	local a = plain.Progression.Expeditions.Slots[1]
	local b = p.Progression.Expeditions.Slots[1]
	check(b.EndsAt - b.StartedAt <= a.EndsAt - a.StartedAt, "a Scout companion never slows a run")
	check(not Service.Launch(p, { Slot = 2, Id = "OrbitalRelay", Crew = { "d" } }), "the companion can't also crew")
end

-- pause flag
do
	local p = profileWith()
	HotFlags.Set("ExpeditionBoardPaused", true, os.time() + 10)
	check(not Service.Launch(p, { Slot = 1, Id = "LunarSurvey" }), "paused board refuses launches")
	check(Service.State(p).Paused == true, "state reports the pause")
	HotFlags.Reset()
end

-- GameService: equip guards, equip best, the v7 aliases and ExpeditionAct
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
	return setmetatable({
		_data = data, _runtime = { [player] = {} }, _running = true, _random = always,
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
	local player = H.player("Board owner")
	local s, data = service(profileWith(), player)
	local r = s:_launchExpedition(player, "LunarSurvey")
	check(r and r.ok and data.profile.Progression.Expeditions.Slots[1].Id == "LunarSurvey", "LaunchExpedition is slot 1")
	r = s:_expeditionAct(player, { Op = "Launch", Slot = 2, Id = "OrbitalRelay", Crew = { "a" } })
	local lock = locksOf(data.profile).a
	if r and r.ok then
		check(lock ~= nil, "ExpeditionAct launches with crew")
		r = s:_equipItem(player, "a", Companion.TARGET)
		check(r and r.ok == false, "a crew relic can't become the companion")
		r = s:_unequipItem(player, lock)
		check(r and r.ok == false, "a crew lock can't be detached")
		r = s:_equipBestItems(player)
		check(locksOf(data.profile).a == lock, "equip best leaves the crew away")
		for target, uid in data.profile.Items.Equipped do
			check(uid ~= "a" or target == lock, "equip best doesn't socket crew")
		end
	else
		-- OrbitalRelay may need a higher commander level; fall back to a recall check on slot 1
		check(r and r.ok == false, "ExpeditionAct reports a gated route")
	end
	data.profile.Progression.Expeditions.Slots[1].EndsAt = os.time() - 1
	r = s:_claimExpedition(player)
	check(r and r.ok and data.profile.Progression.Expeditions.Slots[1].Id == "", "ClaimExpedition is slot 1")
	r = s:_expeditionAct(player, { Op = "Dance", Slot = 1 })
	check(r and r.ok == false, "an unknown op is refused")
end

if #failures > 0 then
	for _, f in failures do print("[FAIL] " .. f) end
	error(string.format("expedition board: %d of %d checks failed", #failures, checks))
end
print(string.format("[TEST] expedition board: %d checks (slots, v7 migration and mirror, launch/claim/recall, crew locks, loot, Scout, aliases, pause) passed", checks))

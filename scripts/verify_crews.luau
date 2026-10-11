-- Crews: small in-server parties with a capped production bonus and a shared daily goal.
local fs = require("@lune/fs")
local CrewMath = require("../src/Shared/AstralForge/Shared/CrewMath")
local ChatRules = require("../src/Shared/AstralForge/Shared/ChatRules")

-- bonus: each other member adds a little, never more than a full crew
assert(CrewMath.multiplier(1) == 1 and CrewMath.multiplier(0) == 1, "solo players get no bonus")
assert(math.abs(CrewMath.multiplier(2) - 1.03) < 1e-9, "one crewmate adds 3%")
assert(math.abs(CrewMath.multiplier(4) - 1.09) < 1e-9, "a full crew adds 9%")
assert(CrewMath.multiplier(40) == CrewMath.multiplier(CrewMath.MAX_MEMBERS), "bonus is capped at the crew size")

-- goal tiers
assert(CrewMath.tierReached(0) == 0 and CrewMath.tierReached(14) == 0, "below the first tier")
assert(CrewMath.tierReached(15) == 1 and CrewMath.tierReached(79) == 2 and CrewMath.tierReached(500) == 3, "tiers reached")

-- daily record: resets on a new day, rejects junk
local today = CrewMath.dayOf(1_800_000_000)
local fresh = CrewMath.normalizeRecord(today - 1, 7, today)
assert(fresh.Day == today and fresh.Claimed == 0, "yesterday's claims reset")
assert(CrewMath.normalizeRecord(nil, "x", today).Claimed == 0, "junk record reads empty")
assert(CrewMath.normalizeRecord(today, 99, today).Claimed == 7, "mask clamps to the known tiers")

-- claiming: once per tier per day, only after the crew reaches it and the member pitched in
local record = CrewMath.normalizeRecord(today, 0, today)
assert(not CrewMath.canClaim(record, 1, 14, 10), "crew must reach the tier")
local ok, reason = CrewMath.canClaim(record, 1, 15, 2)
assert(not ok and string.find(reason, "1 more time", 1, true), "a member who barely collected must pitch in first")
assert(CrewMath.canClaim(record, 1, 15, 3), "an active member can claim")
record = CrewMath.markClaimed(record, 1)
assert(CrewMath.isClaimed(record, 1) and not CrewMath.isClaimed(record, 2), "claim marks only that tier")
assert(not CrewMath.canClaim(record, 1, 80, 30), "no double claims")
assert(CrewMath.markClaimed(record, 1).Claimed == record.Claimed, "marking twice changes nothing")
record = CrewMath.markClaimed(CrewMath.markClaimed(record, 2), 3)
assert(record.Claimed == 7, "all three tiers claimed")
assert(not CrewMath.canClaim(record, 4, 999, 99), "unknown tiers are rejected")
local daily = 0
for _, tier in CrewMath.GOAL_TIERS do daily += tier.Stardust end
assert(daily <= 100, "a player can earn at most a modest amount of stardust from crews per day")

-- names
assert(CrewMath.cleanName("  Night   Shift  ") == "Night Shift", "names are trimmed and collapsed")
assert(CrewMath.cleanName("x") == nil and CrewMath.cleanName(string.rep("a", 21)) == nil and CrewMath.cleanName(5) == nil, "bad names rejected")

-- chat channel naming and command
assert(ChatRules.crewChannel("ab12cd34") == "AFCrew:ab12cd34" and ChatRules.isCrewChannel("AFCrew:ab12cd34"), "crew channel names")
assert(not ChatRules.isCrewChannel("RBXGeneral") and ChatRules.whisperPeer("AFCrew:ab12cd34", 1) == nil, "crew channels are not whispers")
assert(ChatRules.parse("/c hello crew").kind == "c" and ChatRules.parse("/party hi").kind == "c", "crew chat shortcut")
assert(table.find(ChatRules.CHANNELS, "crew"), "crew tab exists")

-- wiring
local server = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(select(2, string.gsub(server, "self%._crews:Multiplier%(player%)", "")) == 3, "the crew bonus applies wherever production is computed")
assert(server:find("if action == Protocol.Actions.CollectVault then self._crews:RecordCollect(player) end", 1, true), "collects feed the crew goal")
local service = fs.readFile("src/Server/AstralForge/Services/CrewService.luau")
assert(service:find("self._data:AtomicUpdate(player, function(profile)", 1, true), "goal claims save atomically")
assert(service:find("CrewMath.canClaim(record, tier, pooled, contribution)", 1, true), "claims are validated inside the save")
print("[TEST] crews: bonus cap, daily goal tiers, single claims, contribution gate, names, chat channel and wiring passed")

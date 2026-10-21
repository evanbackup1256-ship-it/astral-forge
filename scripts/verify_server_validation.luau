--!nocheck
-- Server validation, read from the compiled TS (out/) through scripts/_server_harness:
-- RemoteFirewall payload checks for every Protocol action, SessionGate beats/grants/txns,
-- Progression quests/daily, wheel math, and DataService load normalization / migration of
-- old save shapes. Run `npx rbxtsc` first.
local H = require("./_server_harness")

local failures = {}
local checks = 0
local function check(cond, label)
	checks += 1
	if not cond then table.insert(failures, label) end
end

---------------------------------------------------------------- RemoteFirewall
local Protocol = H.load("Shared/AstralForge/Shared/Protocol")
local FirewallModule = H.load("Server/AstralForge/Services/Security/RemoteFirewall")
local telemetry = setmetatable({}, { __index = function() return function() end end })
local firewall = FirewallModule.RemoteFirewall.new(telemetry)

-- fresh player per call so cooldowns / strikes from one case never leak into another
local function fw(action, payload)
	local ok, reason = firewall:Check(H.player(), action, payload)
	return ok, reason
end

local cyclic = {}
cyclic.Self = cyclic
local deep = {}
do
	local cursor = deep
	for _ = 1, 40 do cursor.Next = {} cursor = cursor.Next end
end
local wide = {}
for i = 1, 5000 do wide["k" .. i] = i end

local actionCount = 0
for name, action in Protocol.Actions do
	actionCount += 1
	for label, junk in { string = "x", number = 5, boolean = true, cyclic = cyclic, deep = deep, wide = wide } do
		local ok, threw = pcall(fw, action, junk)
		check(ok, name .. ": Check threw on " .. label .. " payload")
		check(not threw, name .. ": accepted a " .. label .. " payload")
	end
	local ok, accepted = pcall(fw, action, nil)
	check(ok and type(accepted) == "boolean", name .. ": nil payload gives a verdict")
	local ok2, accepted2 = pcall(fw, action, {})
	check(ok2 and type(accepted2) == "boolean", name .. ": empty payload gives a verdict")
end
check(actionCount > 100, "Protocol.Actions enumerates every action")
check(fw("NotAnAction", {}) == false, "unknown action rejected")
check(fw(42, {}) == false, "non-string action rejected")
do
	local gone = H.player()
	gone.Parent = nil
	check(firewall:Check(gone, Protocol.Actions.GetState, nil) == false, "player outside Players rejected")
end

local A = Protocol.Actions
local cases = {
	-- phone tab pins (Flags.MobileTabPins)
	{ A.SetMobileLayout, { Pins = { "Overview", "Shop" } }, true, "pins accepted" },
	{ A.SetMobileLayout, { Pins = {} }, true, "empty pins (clear) accepted" },
	{ A.SetMobileLayout, { Pins = { "Overview", "Shop", "Research", "Inventory", "Missions" } }, true, "five pins accepted" },
	{ A.SetMobileLayout, { Pins = { "Overview", "Shop", "Research", "Inventory", "Missions", "Rewards" } }, false, "six pins rejected" },
	{ A.SetMobileLayout, { Pins = { "Overview", "Overview" } }, false, "duplicate pin rejected" },
	{ A.SetMobileLayout, { Pins = { "NotAPage" } }, false, "unknown pin rejected" },
	{ A.SetMobileLayout, { Pins = { Overview = true } }, false, "keyed pins rejected" },
	{ A.SetMobileLayout, { Pins = "Overview" }, false, "string pins rejected" },
	{ A.SetMobileLayout, { Values = { MobileQuickX = 0.5 } }, true, "layout value accepted" },
	{ A.SetMobileLayout, { Values = { MobileQuickX = 2 } }, false, "layout value out of range rejected" },
	{ A.SetMobileLayout, { Values = { Cash = 0.5 } }, false, "unknown layout key rejected" },
	{ A.SetMobileLayout, {}, false, "empty layout rejected" },
	-- one-time hints (Flags.SeenHints)
	{ A.MarkHintSeen, { Id = "QuickFind" }, true, "known hint accepted" },
	{ A.MarkHintSeen, { Id = "NotAHint" }, false, "unknown hint rejected" },
	{ A.MarkHintSeen, { Id = 5 }, false, "numeric hint rejected" },
	{ A.MarkHintSeen, { Id = string.rep("Q", 40) }, false, "long hint rejected" },
	{ A.MarkHintSeen, nil, false, "missing hint payload rejected" },
	-- tutorial / convergence / codes / settings
	{ A.SetTutorialStep, { Step = 3 }, true, "tutorial step accepted" },
	{ A.SetTutorialStep, { Step = 0 }, false, "tutorial step 0 rejected" },
	{ A.SetTutorialStep, { Step = 16 }, false, "tutorial step 16 rejected" },
	{ A.SetTutorialStep, { Step = 2.5 }, false, "fractional tutorial step rejected" },
	{ A.ClaimConvergenceReward, { Tier = 1 }, true, "convergence tier accepted" },
	{ A.ClaimConvergenceReward, { Tier = 11 }, false, "convergence tier 11 rejected" },
	{ A.RedeemCode, { Code = "HELLO" }, true, "code accepted" },
	{ A.RedeemCode, { Code = "" }, false, "empty code rejected" },
	{ A.RedeemCode, { Code = string.rep("A", 33) }, false, "33-char code rejected" },
	{ A.SetSetting, { Key = "SoundVolume", Value = 0.5 }, true, "setting accepted" },
	{ A.SetSetting, { Key = "SoundVolume", Value = 2 }, false, "setting out of range rejected" },
	-- no-payload actions
	{ A.GetState, nil, true, "GetState without payload accepted" },
	{ A.CollectVault, { Cash = 1e30 }, false, "no-payload action rejects extra fields" },
}
for _, case in cases do
	local ok, verdict = pcall(fw, case[1], case[2])
	check(ok and verdict == case[3], "firewall: " .. case[4])
end

---------------------------------------------------------------- SessionGate
local SessionGate = H.load("Server/AstralForge/Services/Security/SessionGate").SessionGate
do
	local gate = SessionGate.new()
	local p = H.player()
	check(gate:CheckGrant(p, 1, "x", true) == false, "grant without a session refused")
	local gen, nonce = gate:Hello(p)
	check(type(gen) == "number" and type(nonce) == "string", "hello issues gen + nonce")
	local okBeat, why = gate:Beat(p, gen, 1, "wrong")
	check(okBeat == false and why == "nonce mismatch", "beat with wrong nonce refused")
	check(select(2, gate:Beat(p, gen + 5, 1, nonce)) == "gen mismatch", "beat with wrong gen refused")
	check(select(2, gate:Beat(p, "1", 1, nonce)) == "malformed beat", "malformed beat refused")
	local okFirst, _, gen2, nonce2 = gate:Beat(p, gen, 1, nonce)
	check(okFirst == true, "valid beat authenticates")
	check(gen2 == gen + 1 and nonce2 ~= nonce, "first beat rotates the nonce")
	check(select(2, gate:Beat(p, gen2, 1, nonce2)) == "replay", "replayed beat id refused")
	check(gate:CheckGrant(p, gen2, nonce2, true) == true, "grant with current gen + nonce")
	check(gate:CheckGrant(p, gen2, "stale", true) == false, "grant with wrong nonce refused")
	check(gate:CheckGrant(p, gen2, nil, false) == true, "nonce-free grant with current gen")
	check(gate:CheckGrant(p, gen2 + 1, nonce2, true) == false, "grant with future gen refused")
	-- in the rotation grace window the previous gen/nonce still work
	check(gate:CheckGrant(p, gen, nonce, true) == true, "previous gen + nonce valid in grace")
	-- transaction ring
	check(gate:TxnClaim(p, "t1") == "new", "first claim is new")
	check(gate:TxnClaim(p, "t1") == "busy", "second claim while pending is busy")
	check(gate:TxnLookup(p, "t1") == false, "pending txn has no stored result")
	gate:TxnStore(p, "t1", { ok = true })
	local status, stored = gate:TxnClaim(p, "t1")
	check(status == "done" and stored.ok == true, "stored txn replays its result")
	check(gate:TxnClaim(p, "t2") == "new", "t2 new")
	gate:TxnRelease(p, "t2")
	check(gate:TxnClaim(p, "t2") == "new", "released txn can be claimed again")
	for i = 1, 70 do gate:TxnStore(p, "r" .. i, i) end
	check(gate:TxnLookup(p, "r1") == false and select(2, gate:TxnLookup(p, "r70")) == 70, "txn ring keeps the newest 64")
	gate:Forget(p)
	check(gate:Peek(p) == nil, "forget drops the session")
end

---------------------------------------------------------------- Progression
local DataTemplate = H.load("Server/AstralForge/DataTemplate")
local Progression = H.load("Server/AstralForge/Services/Gameplay/Progression")
do
	local profile = DataTemplate.New()
	check(Progression.EnsureQuests(profile, 7) == true, "quests generated for a new day")
	check(Progression.EnsureQuests(profile, 7) == false, "same day keeps the quests")
	local quests = profile.Quests.Items
	check(#quests == 3, "three daily missions")
	local tap = quests[2]
	check(Progression.ClaimQuest(profile, tap.Id) == false, "unfinished mission cannot be claimed")
	Progression.Progress(profile, "Tap", tap.Target + 50)
	check(tap.Progress == tap.Target, "progress clamps at the target")
	local cashBefore = profile.Cash
	check(Progression.ClaimQuest(profile, tap.Id) == true, "finished mission claims")
	check(Progression.ClaimQuest(profile, tap.Id) == false, "mission cannot be claimed twice")
	check(profile.Cash ~= cashBefore, "mission reward applied")
	check(Progression.ClaimQuest(profile, "nope") == false, "unknown mission refused")

	local day = math.floor(os.time() / 86400)
	local daily = Progression.DailyState(profile)
	check(daily.CanClaim == true and daily.NextStreak == 1, "fresh profile can claim day 1")
	check(Progression.ClaimDaily(profile) == true, "daily claims")
	check(Progression.ClaimDaily(profile) == false, "daily cannot be claimed twice a day")
	check(profile.Daily.Streak == 1, "streak starts at 1")
	profile.Daily.LastClaimDay -= 1
	Progression.ClaimDaily(profile)
	check(profile.Daily.Streak == 2, "consecutive day extends the streak")
	-- each missed day spends one streak shield (two missed days here)
	profile.Daily.LastClaimDay -= 3
	profile.Command.StreakShields = 2
	Progression.ClaimDaily(profile)
	check(profile.Daily.Streak == 3 and profile.Command.StreakShields == 0, "shields keep the streak")
	profile.Daily.LastClaimDay -= 3
	Progression.ClaimDaily(profile)
	check(profile.Daily.Streak == 1, "missed day without a shield resets the streak")
	check(profile.Daily.LastClaimDay == day or profile.Daily.LastClaimDay >= day - 1, "claim day recorded")
end

---------------------------------------------------------------- Wheel math
local EconomyMath = H.load("Server/AstralForge/Modules/EconomyMath")
local Wheel = EconomyMath("WheelMath")
do
	local bag = Wheel.Ensure({ LastSpinAt = -5, Spins = 2.7, PityMisses = "x", FreeSpins = 1 / 0 * 0, History = { { PrizeId = "A", At = 1 }, 5 } })
	check(bag.LastSpinAt == 0 and bag.Spins == 2 and bag.PityMisses == 0, "wheel bag clamps junk")
	check(#bag.History == 1, "wheel history drops junk entries")
	local fresh = Wheel.Ensure(nil)
	check(fresh.Spins == 0 and fresh.FreeSpins == 0, "missing wheel bag defaults")
	local snap = Wheel.Snapshot(100, { LastSpinAt = 50, Spins = 1, PityMisses = 7, FreeSpins = 0 }, 100, 8)
	check(snap.CanSpin == false and snap.ReadyAt == 150 and snap.PityArmed == true, "wheel cooldown + pity snapshot")
	local rewards = { { Rarity = "COMMON", Weight = 0 }, { Rarity = "COMMON", Weight = 10 }, { Rarity = "RARE", Weight = 5 } }
	local pool, total = Wheel.FullPool(rewards)
	check(total == 15, "pool weight")
	check(Wheel.PickEntry(pool, total, 0).Index == 2, "a zero roll never picks a zero-weight prize")
	check(Wheel.PickEntry(pool, total, 10).Index == 2, "roll on a boundary picks that prize")
	check(Wheel.PickEntry(pool, total, 10.01).Index == 3, "roll past the boundary picks the next")
	local pityPool, pityTotal = Wheel.BuildPool(rewards, true, 3)
	check(#pityPool == 1 and pityTotal == 5, "pity pool keeps only the floor rarity and up")
	check(Wheel.NextPityMisses(3, 3, 3) == 0 and Wheel.NextPityMisses(3, 1, 3) == 4, "pity misses reset / count")
	local history = { History = {} }
	for i = 1, 15 do Wheel.RecordHistory(history, "P" .. i, i, false) end
	check(#history.History == 10 and history.History[1].PrizeId == "P15", "wheel history newest first, bounded")
end

---------------------------------------------------------------- DataService load / migration
local DataServiceModule = H.load("Server/AstralForge/Services/DataService")
local normalize = DataServiceModule.normalizeStoredProfile
local migrate = DataServiceModule.migrateLegacyProfile
do
	-- an old save from before Flags existed
	local old = DataTemplate.New()
	old.Flags = nil
	local loaded = normalize(old)
	check(type(loaded.Flags) == "table", "missing Flags restored")
	check(type(loaded.Flags.SeenHints) == "table" and #loaded.Flags.SeenHints == 0, "missing SeenHints defaults to []")
	check(type(loaded.Flags.MobileTabPins) == "table" and #loaded.Flags.MobileTabPins == 0, "missing MobileTabPins defaults to []")
	check(loaded.Flags.TutorialStep == 1 and loaded.Flags.TutorialDone == false, "flag defaults restored")

	-- Flags present but from before pins / hints
	local mid = DataTemplate.New()
	mid.Flags = { TutorialDone = true, TutorialStep = 15, LastSeenVersion = "4.0" }
	local loadedMid = normalize(mid)
	check(loadedMid.Flags.TutorialDone == true and loadedMid.Flags.TutorialRewardClaimed == true, "existing flags kept")
	check(#loadedMid.Flags.SeenHints == 0 and #loadedMid.Flags.MobileTabPins == 0, "new flag lists added")

	-- damaged lists
	local bad = DataTemplate.New()
	bad.Flags.SeenHints = { "QuickFind", "Bogus", "QuickFind", 5 }
	bad.Flags.MobileTabPins = { "Shop", "Nope", "Shop", "Overview", "Research", "Inventory", "Missions", "Rewards" }
	local loadedBad = normalize(bad)
	check(#loadedBad.Flags.SeenHints == 1 and loadedBad.Flags.SeenHints[1] == "QuickFind", "SeenHints cleaned")
	check(#loadedBad.Flags.MobileTabPins == 5 and loadedBad.Flags.MobileTabPins[1] == "Shop", "MobileTabPins cleaned and capped")
	bad.Flags.SeenHints = "QuickFind"
	bad.Flags.MobileTabPins = 7
	local loadedJunk = normalize(bad)
	check(#loadedJunk.Flags.SeenHints == 0 and #loadedJunk.Flags.MobileTabPins == 0, "non-table lists reset")

	-- settings added later get their defaults
	local noAccent = DataTemplate.New()
	noAccent.Settings.ChatUseProfileAccent = nil
	check(normalize(noAccent).Settings.ChatUseProfileAccent == 1, "ChatUseProfileAccent defaults on")

	-- migration: an old-version save normalizes; a newer data version is refused
	local legacy = DataTemplate.New()
	legacy.DataVersion = 1
	legacy.Flags = nil
	local okMigrate, migrated = pcall(migrate, legacy)
	check(okMigrate and type(migrated.Flags.SeenHints) == "table", "old data version migrates")
	local future = DataTemplate.New()
	future.DataVersion = 10 ^ 6
	check(pcall(migrate, future) == false, "newer data version refused")
	-- an empty document becomes a full default profile
	local okEmpty, empty = pcall(normalize, {})
	check(okEmpty and type(empty.Flags) == "table" and empty.Cash ~= nil, "empty document becomes a default profile")
end

if #failures > 0 then
	error("server validation failed:\n  " .. table.concat(failures, "\n  "))
end
print(string.format("[TEST] server validation: %d checks (%d actions through RemoteFirewall, SessionGate, Progression, wheel, profile load) passed", checks, actionCount))

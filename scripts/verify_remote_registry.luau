--!nocheck
-- RemoteRegistry: every Protocol action has an entry, no-payload actions match the firewall's
-- old list, and each ported schema accepts and rejects exactly what the hand-written check did.
local load = require("./_out_loader")
local Protocol = load("out/Shared/AstralForge/Shared/Protocol")
local R = load("out/Shared/AstralForge/Shared/Data/RemoteRegistry")

local failures = 0
local function check(cond, msg)
	if not cond then failures += 1; print("FAIL: " .. msg) end
end

local count = 0
for name in Protocol.Actions do
	count += 1
	check(R.EntryFor(name) ~= nil, "no registry entry for " .. name)
end
check(R.EntryFor("NotAnAction") == nil, "unknown action has an entry")
local ok, reason = R.Validate("NotAnAction", {})
check(ok == false and reason == "unknown action", "unknown action passes")

local OLD_NO_PAYLOAD = { "GetState", "MeasureLatency", "GetPlayers", "GetTrade", "ConfirmTrade", "CancelTrade", "GetAdminState", "CollectVault", "Overcharge", "DomainExpansion", "UpgradeContinuum", "Ascend", "ClaimDaily", "ClaimExpedition", "CompleteTutorial", "ReplayTutorial", "DismissRelease", "OpenRelease", "PulseAnomaly", "StabilizeAnomaly", "ActivateAnomalySurge", "SyncShop", "LeavePlot", "GetGuild", "LeaveGuild", "DisbandGuild", "ClaimGuildGoal", "EquipBestItems", "ClaimAllMail", "VerifyCreatorFollow", "GetCrew", "CrewLeave" }
local set = {}
for _, n in OLD_NO_PAYLOAD do set[n] = true; check(R.TakesNoPayload(n), n .. " should take no payload") end
for name in Protocol.Actions do
	if not set[name] then check(not R.TakesNoPayload(name), name .. " wrongly marked no-payload") end
end

local function expect(action, payload, wantOk, wantReason)
	local got, why = R.Validate(action, payload)
	check(got == wantOk and (wantReason == nil or why == wantReason),
		string.format("%s: want %s/%s got %s/%s", action, tostring(wantOk), tostring(wantReason), tostring(got), tostring(why)))
end

-- SubmitFeedback
expect("SubmitFeedback", { Category = "Bug", Message = "it broke when I did X" }, true)
expect("SubmitFeedback", { Category = "Bug", Message = "short" }, false, "invalid feedback")
expect("SubmitFeedback", { Category = "Weird", Message = "long enough text" }, false, "invalid feedback category")
expect("SubmitFeedback", { Category = "Bug", Message = "long enough text", Impact = 2.5 }, false, "invalid feedback impact")
expect("SubmitFeedback", { Category = "Bug", Message = "long enough text", Impact = 0/0 }, false, "invalid feedback impact")
expect("SubmitFeedback", { Category = "Bug", Message = "long enough text", Page = "" }, false, "invalid feedback page")
expect("SubmitFeedback", { Category = "Other", Message = "long enough text", Impact = 5, Device = "PC", Screen = "1080p", Page = "Forge", TxnId = "x" }, true)
-- CompanionAct
expect("CompanionAct", { Op = "PickTrait", Trait = "Brave" }, true)
expect("CompanionAct", { Op = "Drop", Trait = "Brave" }, false, "invalid companion action")
expect("CompanionAct", { Op = "PickTrait" }, false, "invalid companion action")
-- ExpeditionAct
expect("ExpeditionAct", { Op = "Claim", Slot = 2 }, true)
expect("ExpeditionAct", { Op = "Claim", Slot = 2, Id = 5 }, true) -- legacy ignored Id off Launch
expect("ExpeditionAct", { Op = "Claim", Slot = 6 }, false, "invalid expedition slot")
expect("ExpeditionAct", { Op = "Launch", Slot = 1 }, false, "invalid expedition route")
expect("ExpeditionAct", { Op = "Launch", Slot = 1, Id = "Mine", Crew = { "a", "b" } }, true)
expect("ExpeditionAct", { Op = "Launch", Slot = 1, Id = "Mine", Crew = { "a", "b", "c", "d" } }, false, "invalid expedition crew")
expect("ExpeditionAct", { Op = "Launch", Slot = 1, Id = "Mine", Crew = { [1] = "a", [3] = "c" } }, false, "invalid expedition crew")
expect("ExpeditionAct", { Op = "Nope", Slot = 1 }, false, "invalid expedition action")
-- ProgramAct
expect("ProgramAct", { Op = "Toggle", Index = 1 }, true)
expect("ProgramAct", { Op = "Toggle" }, false, "invalid program index")
expect("ProgramAct", { Op = "Delete", Index = 9 }, false, "invalid program index")
expect("ProgramAct", { Op = "Save", Rule = { When = "Always", Do = "Collect" } }, true)
expect("ProgramAct", { Op = "Save", Rule = { When = "Always", Do = "Collect", Arg = 2000 } }, false, "invalid program value")
expect("ProgramAct", { Op = "Save", Rule = { When = "Always", Do = "Collect", Enabled = 1 } }, false, "invalid program switch")
expect("ProgramAct", { Op = "Save", Rule = "x" }, false, "invalid program rule")
-- legacy entries defer to the firewall
local lok, _, handled = R.Validate("BuyMachine", { Id = "x" })
check(lok == true and handled == false, "legacy entry should defer")

if failures > 0 then error(string.format("[TEST] remote registry: %d failures", failures)) end
print(string.format("[TEST] remote registry: %d actions covered, ported schemas match the legacy checks", count))

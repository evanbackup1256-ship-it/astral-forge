--!strict
-- AdminPolicy: role gates, unknown-role fallback, deep copy isolation, readable diffs, and dry-run wiring.

local fs = require("./_memberfs")(require("@lune/fs"))
local AdminPolicy = require("../out/Server/AstralForge/Modules/AdminPolicy")

local economy = { Category = "Economy" }
local moderation = { Category = "Moderation", Moderation = true }
local resets = { Category = "Resets" }

assert(AdminPolicy.Allows("Owner", "GrantFlux", economy), "owner grants")
assert(AdminPolicy.Allows("Studio Developer", "GlobalBan", moderation), "studio dev global ban")
assert(AdminPolicy.Allows("Developer", "GrantFlux", economy), "developer grants")
assert(not AdminPolicy.Allows("Developer", "GlobalBan", moderation), "developer cannot global ban")
assert(AdminPolicy.Allows("Moderator", "Kick", moderation), "moderator kicks")
assert(not AdminPolicy.Allows("Moderator", "GrantFlux", economy), "moderator cannot grant")
assert(AdminPolicy.Allows("Support", "ResetTutorial", resets), "support tutorial reset")
assert(AdminPolicy.Allows("Support", "ResetSettings", resets), "support can restore a player's preferences")
assert(not AdminPolicy.Allows("Support", "WipeFlux", resets), "support cannot wipe")
local troll = { Category = "Troll", World = true }
assert(AdminPolicy.Allows("Developer", "FakeRareDrop", troll), "developers can run client-only game pranks")
assert(not AdminPolicy.Allows("Moderator", "FakeEvent", troll), "moderators cannot run game pranks")
assert(AdminPolicy.Resolve("Community Helper") == "Support", "unknown roles fall back to Support")
assert(not AdminPolicy.Allows("Community Helper", "GrantEverything", economy), "unknown roles never escalate")
local denied, why = AdminPolicy.Allows(nil, "GrantFlux", economy)
assert(not denied and type(why) == "string", "nil role denied")

local source = { Cash = 10, Items = { Keys = { Nova = 1 } } }
local copy = AdminPolicy.DeepCopy(source)
copy.Items.Keys.Nova = 5
copy.Cash = 25
copy.Items.Essence = 3
assert(source.Items.Keys.Nova == 1 and source.Cash == 10, "deep copy isolates")
local lines, total = AdminPolicy.Diff(source, copy, 10)
assert(total == 3, "three leaves changed, got " .. total)
assert(lines[1] == "Cash: 10 → 25", lines[1])
assert(lines[2] == "Items.Essence: none → 3", lines[2])
assert(lines[3] == "Items.Keys.Nova: 1 → 5", lines[3])
local capped, cappedTotal = AdminPolicy.Diff({ a = 1, b = 1, c = 1 }, { a = 2, b = 2, c = 2 }, 2)
assert(#capped == 2 and cappedTotal == 3, "diff cap keeps total")
local same, sameTotal = AdminPolicy.Diff({ x = 0 / 0 }, { x = 0 / 0 })
assert(#same == 0 and sameTotal == 0, "NaN equality ignored")

local service = fs.readFile("src/Server/AstralForge/Services/AdminService.luau")
assert(string.find(service, "AdminPolicy.Allows(role, command :: string, definition)", 1, true), "Execute enforces policy")
assert(string.find(service, "if not AdminPolicy.Allows(role, id, definition) then", 1, true), "State hides denied commands")
assert(string.find(service, "local dryRun = payload.DryRun == true", 1, true), "dry run flag")
assert(string.find(service, 'ResetSettings = { Label = "Restore settings defaults"', 1, true), "admin has a support preference reset")
for _, command in {
	'FakeRareDrop = { Label = "Fake celestial relic drop", Option = false, Category = "Troll", World = true }',
	'JumbleHud = { Label = "Jumble the HUD", Option = false, Category = "Troll", World = true }',
	'FakeEvent = { Label = "False starfall alert", Option = false, Category = "Troll", World = true }',
} do
	assert(string.find(service, command, 1, true), "admin game-prank command missing: " .. command)
end
for _, forbidden in { "FakeBan =", "FakeCrash =", "BlueScreen =", "LoadingForever =", "UpdateForced =" } do
	assert(not string.find(service, forbidden, 1, true), "system-style fake screen command remains: " .. forbidden)
end
assert(string.find(service, "firePrank(target, command, duration, caption)", 1, true), "pranks stay client-only")
assert(string.find(service, "self:_record(actor, target, command, amount, option, reason, revision)", 1, true), "world pranks are audited")
local dryStart = string.find(service, "if dryRun then\n", 1, true) or string.find(service, "if dryRun then\r\n", 1, true)
local commit = string.find(service, "self._data:AtomicUpdate(target", 1, true)
assert(dryStart and commit and dryStart < commit, "dry run returns before the profile transaction")

local firewall = fs.readFile("src/Server/AstralForge/Services/RemoteFirewall.luau")
assert(string.find(firewall, "invalid admin preview flag", 1, true), "firewall types DryRun")
local prankOverlay = fs.readFile("src/Client/AstralForge/UiCore.luau#AdminPrankOverlay")
assert(string.find(prankOverlay, 'kind == "FakeRareDrop"', 1, true), "fake relic drops have an in-game presentation")
assert(string.find(prankOverlay, 'kind == "FakeEvent"', 1, true), "fake events have an in-game presentation")
for _, forbidden in { "This session was closed by an administrator", "Stop code:", "UPDATE REQUIRED", "LOW BATTERY" } do
	assert(not string.find(prankOverlay, forbidden, 1, true), "system-style prank presentation remains: " .. forbidden)
end
local server = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(server, "if target and targetProfile and result.World ~= true then", 1, true), "client-only pranks do not send a fake profile update")

print("verify_admin_policy: ok")

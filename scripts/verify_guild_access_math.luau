--!strict
-- Purpose: Test guild access policy defaults, capacity and invalid setting rejection.
-- Owner: Astral Forge verification. Dependencies: GuildAccessMath. Last-reviewed: 2026-10-07.

local GuildAccessMath = require("../src/Server/AstralForge/Modules/GuildAccessMath")

local mode, modeError = GuildAccessMath.NormalizeJoinMode(nil)
assert(mode == "Open" and modeError == nil, "legacy guilds must stay open by default")

local defaultCap, capError = GuildAccessMath.NormalizeMemberCap(nil, 3, 20)
assert(defaultCap == 20 and capError == nil, "legacy guilds must use the existing global member limit")

local canJoin, joinError = GuildAccessMath.CanJoin("Open", 4, 8, 20, false)
assert(canJoin and joinError == nil, "open guilds with capacity must accept new members")

canJoin, joinError = GuildAccessMath.CanJoin("Closed", 1, 8, 20, false)
assert(not canJoin and joinError == "This guild is closed to new members.", "closed guilds must reject new members")

canJoin, joinError = GuildAccessMath.CanJoin("Open", 8, 8, 20, false)
assert(not canJoin and joinError == "That guild is full.", "member cap must block joins at capacity")

canJoin, joinError = GuildAccessMath.CanJoin("Open", 1, "corrupt", 20, false)
assert(not canJoin and joinError == "That guild is full.", "corrupt persisted caps must fail closed")

canJoin, joinError = GuildAccessMath.CanJoin("Closed", 8, 8, 20, true)
assert(canJoin and joinError == nil, "existing members must not be locked out by access policy")

local _, invalidMode = GuildAccessMath.NormalizeJoinMode("InviteOnly")
assert(invalidMode ~= nil, "unsupported modes must be rejected until invitation acceptance exists")

local _, tooSmall = GuildAccessMath.NormalizeMemberCap(1, 1, 20)
assert(tooSmall ~= nil, "member cap must preserve room for the leader and one member")

local _, belowRoster = GuildAccessMath.NormalizeMemberCap(4, 5, 20)
assert(belowRoster ~= nil, "leaders must not lower the cap below the current roster")

local _, overLimit = GuildAccessMath.NormalizeMemberCap(21, 1, 20)
assert(overLimit ~= nil, "custom member caps must respect the game-wide ceiling")

local _, fractional = GuildAccessMath.NormalizeMemberCap(5.5, 1, 20)
assert(fractional ~= nil, "member caps must be whole numbers")

local _, malformed = GuildAccessMath.NormalizeMemberCap("20", 1, 20)
assert(malformed ~= nil, "persisted or direct-call member caps must be number-validated")

print("[TEST] guild access defaults, open/closed joins, existing member continuity, and cap boundaries passed")

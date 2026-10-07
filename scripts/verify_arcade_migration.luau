--!strict
-- Purpose: Verify legacy stake refunds conserve balances and cannot repeat after save/load or request retries.
-- Owner: Astral Forge verification. Dependencies: ArcadeMigration/OmegaMath/Lune serde. Last-reviewed: 2026-10-05.
local Migration = require("../src/Server/AstralForge/Modules/ArcadeMigration")
local Math = require("../src/Shared/AstralForge/Shared/OmegaMath")
local serde = require("@lune/serde")
local provider: Migration.MathProvider = { Add = Math.Add, Persist = Math.Persist }
local profile: Migration.Profile =
	{ Cash = 100, Casino = { Flip = { Active = true, Stake = 25 }, HighLow = { Active = true, Stake = 40 } } }
local record = Migration.apply(profile, provider, 1000)
assert(profile.Cash == 165 and record.Refunded == 65 and record.Rounds == 2)
assert(profile.Casino and profile.Casino.Flip and not profile.Casino.Flip.Active)
record.Refunded = 999
assert(profile.ArcadeMigration and profile.ArcadeMigration.Refunded == 65)
assert(Migration.apply(profile, provider, 2000).Refunded == 65 and profile.Cash == 165)
local restored: Migration.Profile = serde.decode("json", serde.encode("json", profile))
assert(Migration.apply(restored, provider, 3000).At == 1000 and restored.Cash == 165)
local inactive: Migration.Profile = { Cash = 100, Casino = { Flip = { Active = false, Stake = 80 } } }
assert(Migration.apply(inactive, provider, 1000).Refunded == 0 and inactive.Cash == 100)
local missing: Migration.Profile = { Cash = 50 }
assert(Migration.apply(missing, provider, 1000).Rounds == 0 and missing.Cash == 50)
local huge: Migration.Profile = { Cash = "1e400", Casino = { HighLow = { Active = true, Stake = "2e400" } } }
Migration.apply(huge, provider, 1000)
assert(Math.Compare(huge.Cash, "3e400") == 0)
local malformed: Migration.Profile =
	{ Cash = 50, Casino = { Flip = { Active = true, Stake = "not-money" }, HighLow = { Active = true, Stake = -25 } } }
Migration.apply(malformed, provider, 1000)
assert(malformed.Cash == 50)
print(
	"[TEST] archived-stake refunds, inactive/malformed/huge balances, immutable records and save/load idempotency passed"
)

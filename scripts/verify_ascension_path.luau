--!strict
-- Regression cases for legacy-tree migration and the server-priced respec transaction.

local AscensionPathMath = require("../src/Shared/AstralForge/Shared/AscensionPathMath")

local tree = {
	{ Id = "Root", Cost = 2 },
	{ Id = "Branch", Cost = 3, Requires = { "Root" } },
	{ Id = "Apex", Cost = 5, Requires = { "Branch" } },
}
local config = {
	SchemaVersion = 2,
	BaseStardust = 400,
	StardustPerRank = 125,
	RepeatScale = 1.35,
	MaxStardust = 1_000_000_000,
}

local legacy = {
	Rank = 3,
	SkillPoints = 4,
	Essence = 57,
	TotalRebirthsSpent = 123,
	Nodes = { Root = true, Branch = 1, unknownLegacyNode = true },
}
local migrated = AscensionPathMath.Migrate(legacy, config.SchemaVersion)
assert(migrated.TreeVersion == config.SchemaVersion, "the legacy tree receives the active schema version")
assert(migrated.Nodes.Root == true and migrated.Nodes.Branch == 1, "legacy branches remain unlocked")
assert(migrated.Nodes.unknownLegacyNode == true, "migration preserves unknown saved markers")
assert(migrated.Essence == legacy.Essence and migrated.TotalRebirthsSpent == legacy.TotalRebirthsSpent, "migration preserves unrelated Domain progress")

local quote = AscensionPathMath.QuoteRespec(legacy, tree, 10_000, config)
assert(quote.CanRespec, "an owned path and sufficient Stardust can be reset")
assert(quote.RefundPoints == 5 and quote.OwnedNodes == 2, "only known invested nodes determine the refund")
assert(quote.Cost == 775, "rank is included in the first respec price")
assert(not AscensionPathMath.QuoteRespec(legacy, tree, quote.Cost - 1, config).CanRespec, "insufficient Stardust is rejected")
assert(not AscensionPathMath.QuoteRespec({ Rank = 0, Nodes = { Root = true } }, tree, 10_000, config).CanRespec, "expansion gate is enforced")
assert(not AscensionPathMath.QuoteRespec({ Rank = 3, Nodes = {} }, tree, 10_000, config).CanRespec, "an empty path cannot be charged")
assert(
	AscensionPathMath.QuoteRespec({ Rank = 3, Nodes = { untrusted = true } }, tree, 10_000, config).OwnedNodes == 0,
	"unknown client-shaped nodes cannot create a refund"
)

local result, problem = AscensionPathMath.ApplyRespec(legacy, tree, 10_000, config)
assert(result ~= nil and problem == nil, "valid respec applies")
assert(result.Domain.Nodes.Root == nil and result.Domain.Nodes.Branch == nil, "all known branches are refunded")
assert(result.Domain.Nodes.unknownLegacyNode == true, "inert unknown data is preserved")
assert(result.Domain.SkillPoints == 9, "refund is added to unspent points")
assert(result.Domain.RespecCount == 1 and result.Domain.TreeVersion == config.SchemaVersion, "version and price history advance")
assert(result.Stardust == 9_225, "only the quoted server price is deducted")
local nextQuote = AscensionPathMath.QuoteRespec({
	Rank = result.Domain.Rank,
	Nodes = { Root = true },
	RespecCount = result.Domain.RespecCount,
	TreeVersion = result.Domain.TreeVersion,
}, tree, 10_000, config)
assert(nextQuote.Cost == 1_046, "repeat respec cost scales deterministically")

print("[TEST] Ascension Path migration, branches, point refunds, Stardust costs, repeat pricing, and unknown-data preservation passed")

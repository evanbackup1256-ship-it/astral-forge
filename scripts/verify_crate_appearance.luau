--!strict
local Appearance = require("../src/Shared/AstralForge/Shared/CrateAppearance")
local crates = { { Id = "ForgeCrate" }, { Id = "TitanCrate", ModelId = "Titan" } }
assert(Appearance.resolve("Classic", "TitanCrate", crates) == "Titan")
assert(Appearance.resolve(nil, "TitanCrate", crates) == "Titan")
assert(Appearance.resolve("Frost", "TitanCrate", crates) == "Frost")
assert(Appearance.resolve("Classic", "ForgeCrate", crates) == "Classic")
assert(Appearance.resolve("Classic", "Unknown", crates) == "Classic")
assert(Appearance.resolve(nil, nil, {}) == "Classic")
assert(Appearance.resolve("Classic", "Empty", { { Id = "Empty", ModelId = "" } }) == "Classic")
print("[TEST] crate shop/reveal default models, equipped-skin priority and legacy fallback passed")

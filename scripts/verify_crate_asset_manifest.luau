--!strict
local kit = require("../src/Shared/AstralForge/Shared/CrateKit")

assert(kit.Id > 0, "uploaded Blender crate kit must have an asset id")
assert(kit.TextureOverrides == nil, "use baked GLB materials until standalone texture delivery is verified")
assert(#kit.Skins == 20, "kit must contain both original and expanded crate skins")

local seen: { [string]: boolean } = {}
for _, skinId in kit.Skins do
	assert(type(skinId) == "string" and skinId ~= "", "skin ids must be non-empty strings")
	assert(not seen[skinId], "crate kit contains a duplicate skin id: " .. skinId)
	seen[skinId] = true
end

print("[TEST] uploaded crate kit manifest has 20 unique skins and preserves baked GLB materials")

local guard = require("../src/Server/AstralForge/Modules/ProfileVersionGuard")

assert(guard.ReadCompatible({}, 21) == 0)
assert(guard.ReadCompatible({ DataVersion = 21 }, 21) == 21)
assert(guard.ReadCompatible({ DataVersion = "20" }, 21) == 20)

for _, data in { false, { DataVersion = 22 }, { DataVersion = -1 }, { DataVersion = "broken" }, { DataVersion = 1.5 } } do
	local ok = pcall(guard.ReadCompatible, data, 21)
	assert(not ok, "unsafe profile version was accepted")
end

print("[INFO] [TEST] profile version guards passed")

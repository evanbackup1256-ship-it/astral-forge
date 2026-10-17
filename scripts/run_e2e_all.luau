--!strict
-- scripts/run_e2e_all.luau
-- Comprehensive E2E test runner executing Tiers 1, 2, 3, 4, and 5 suites

local Fw = require("./verify_e2e_framework")

_G.__E2E_SUITE_RUNNER__ = true

print("[INFO] [E2E] Registering Tier 1 (Functional) test cases...")
require("./verify_e2e_tier1")

print("[INFO] [E2E] Registering Tier 2 (Boundary & Edge Cases) test cases...")
require("./verify_e2e_tier2")

print("[INFO] [E2E] Registering Tier 3 (Cross-Domain Interactions) test cases...")
require("./verify_e2e_tier3")

print("[INFO] [E2E] Registering Tier 4 (Real-World Application Scenarios) test cases...")
require("./verify_e2e_tier4")

print("[INFO] [E2E] Registering Tier 5 (Adversarial Coverage Hardening) test cases...")
require("./verify_e2e_tier5")

print("[INFO] [E2E] Executing full suite across all registered tiers...")
local results = Fw.runAll()
_G.__E2E_SUITE_RUNNER__ = nil

if results.failed > 0 then
	error(string.format("[FATAL] [E2E] %d test(s) failed out of %d total!", results.failed, results.total))
else
	print(string.format("[INFO] [E2E] All %d test cases passed successfully! (100%% pass rate)", results.total))
end

return true


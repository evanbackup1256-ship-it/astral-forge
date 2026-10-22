--!nocheck
-- LogPolicy: level thresholds (global, per scope, the old AstralDebugLogs switch), warnings always
-- print, throttle and 1-in-N sampling report what they dropped. Run `npx rbxtsc` first.
local H = require("./_server_harness")
local P = H.load("Shared/AstralForge/Shared/LogPolicy")
local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end

local attrs = {}
P.setSource(function(name) return attrs[name] end)

check(P.threshold() == "info", "default threshold is info")
check(not P.enabled("DEBUG") and P.enabled("INFO") and P.enabled("NETWORK"), "default hides debug only")
attrs.AstralDebugLogs = true
check(P.enabled("DEBUG"), "AstralDebugLogs still turns on debug")
attrs.AstralLogLevel = "warn"
check(not P.enabled("INFO") and P.enabled("WARN") and P.enabled("ERROR"), "AstralLogLevel=warn hides info")
attrs.AstralLogLevel_layoutguard = "debug"
check(P.enabled("DEBUG", "LayoutGuard") and not P.enabled("INFO", "boot"), "per-scope level wins for that scope only")
attrs.AstralLogLevel = "fatal"
check(P.enabled("WARN") and P.enabled("ERROR"), "warnings and errors always print")
attrs.AstralLogLevel = "nonsense"
check(P.threshold() == "debug", "an unknown level falls back (debug flag still on)")
check(P.levelOf("NETWORK") == "net" and P.levelOf("weird") == "info", "severity names map to levels")

P.reset()
check(P.throttle("k", 10, 0) == 0, "first throttled line prints")
check(P.throttle("k", 10, 3) == nil and P.throttle("k", 10, 6) == nil, "lines inside the window drop")
check(P.throttle("k", 10, 11) == 2, "the next line reports 2 dropped")

local printed, lastDropped = 0, nil
for i = 1, 10 do
	local d = P.sample("s", 4)
	if d ~= nil then printed += 1 lastDropped = d end
end
check(printed == 3, "1-in-4 sampling prints lines 1, 5 and 9 (" .. printed .. ")")
check(lastDropped == 3, "a sampled line reports the 3 skipped before it")
check(P.sample("one", 1) == 0 and P.sample("one", 1) == 0, "rate 1 prints everything")
P.setSource(nil)

if #failures > 0 then
	for _, f in failures do print("  FAIL: " .. f) end
	error(string.format("log policy failed: %d problems", #failures))
end
print(string.format("[TEST] log policy: %d checks passed", checks))

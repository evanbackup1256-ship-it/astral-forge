--!nocheck
-- Remote traffic rate limits (audit follow-up): actions the firewall exempts from the category
-- buckets (GetState, taps, trade confirm) now have a flood ceiling of their own. A lag-spike
-- burst still passes, a flood is cut without strikes, each exempt action has its own bucket, and
-- the ceiling refills. Run rbxtsc first.
local H = require("./_server_harness")
local task = require("@lune/task")
local Protocol = H.load("Shared/AstralForge/Shared/Protocol")
local Buckets = H.load("Server/AstralForge/Services/Security/ActionBuckets")
local FirewallModule = H.load("Server/AstralForge/Services/Security/RemoteFirewall")
local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end

-- pure bucket math with an explicit clock
do
	local b = Buckets.ActionBuckets.new()
	local passed = 0
	for _ = 1, 500 do if b:TakeExempt("Overcharge", 10) then passed += 1 end end
	check(passed == Buckets.EXEMPT_RULES.Overcharge.Burst, "a tap flood stops at the burst")
	check(b:TakeExempt("Overcharge", 10.1), "taps refill over time")
	local after = 0
	for _ = 1, 100 do if b:TakeExempt("Overcharge", 11.1) then after += 1 end end
	check(after >= 42 and after <= 44, "one second refills PerSecond taps (plus the 3 left over)")
	check(b:TakeExempt("CollectVault", 11.1), "each exempt action has its own bucket")
	local unknown = 0
	for _ = 1, 100 do if b:TakeExempt("ClaimDaily", 0) then unknown += 1 end end
	check(unknown == Buckets.EXEMPT_DEFAULT.Burst, "unlisted exempt actions use the default ceiling")
	check(Buckets.EXEMPT_RULES.Overcharge.PerSecond >= 30, "tap ceiling stays far above human clicking")
end

-- through the firewall
do
	local telemetry = setmetatable({}, { __index = function() return function() end end })
	local fw = FirewallModule.RemoteFirewall.new(telemetry)
	local p = H.player("Flooder")
	local passed, slowed = 0, 0
	for _ = 1, 400 do
		local ok, why = fw:Check(p, Protocol.Actions.GetState, nil)
		if ok then passed += 1 elseif why == "Please slow down for a moment." then slowed += 1 end
	end
	check(passed >= 30 and passed <= 45, "a state-read flood is cut near the burst (" .. passed .. ")")
	check(slowed == 400 - passed, "the rest are told to slow down")
	local state = fw._states[p]
	check(state ~= nil and state.Strikes == 0 and state.QuarantineUntil == 0, "a flood of exempt reads is not a strike")
	local taps = 0
	for _ = 1, 400 do if fw:Check(p, Protocol.Actions.CollectVault, nil) then taps += 1 end end
	check(taps >= 110 and taps <= 130, "tap ceiling is separate from the state-read ceiling (" .. taps .. ")")
	task.wait(0.5)
	check(fw:Check(p, Protocol.Actions.GetState, nil) == true, "the ceiling refills")
	fw:Forget(p)
	check(fw._states[p] == nil, "leaving clears the player's buckets")
end

if #failures > 0 then error("rate limit failures:\n  " .. table.concat(failures, "\n  ")) end
print(string.format("[TEST] remote rate limits: %d checks (exempt flood ceilings, own buckets, refill, no strikes, firewall wiring) passed", checks))

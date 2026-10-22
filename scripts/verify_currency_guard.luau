--!nocheck
-- Negative currency guards (audit follow-up): an AtomicUpdate that would leave any wallet balance
-- below zero (or NaN) is refused whole, on the sanitized path and on the hot in-place paths, and
-- leaves the committed profile untouched; spending exactly the balance, earning, and updates on a
-- profile whose balance was already bad on load still go through. Run rbxtsc first.
local H = require("./_server_harness")
local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end

local Guard = H.load("Server/AstralForge/Modules/CurrencyGuard")
local Omega = H.load("Shared/AstralForge/Shared/OmegaMath")
local DataService = H.load("Server/AstralForge/Services/DataService").DataService
local AtomicState = H.load("Server/AstralForge/Services/Security/AtomicState")
local Template = H.load("Server/AstralForge/DataTemplate")

-- pure checks
local before = Guard.Read({ Cash = 10, Ore = { Emberite = 3 } })
check(Guard.Overdrawn(before, { Cash = -1, Ore = { Emberite = 3 } }, Omega) == "Cash", "negative cash caught")
check(Guard.Overdrawn(before, { Cash = 0, Ore = { Emberite = -2 } }, Omega) == "Ore.Emberite", "nested ore caught")
check(Guard.Overdrawn(before, { Cash = 0 / 0, Ore = { Emberite = 3 } }, Omega) == "Cash", "NaN caught")
check(Guard.Overdrawn(before, { Cash = 0, Ore = { Emberite = 0 } }, Omega) == nil, "spending to exactly zero is fine")
check(Guard.Overdrawn(Guard.Read({ Cash = "1e400" }), { Cash = "-1e399" }, Omega) == "Cash", "omega-string balances caught")
check(Guard.Overdrawn(Guard.Read({ Cash = "1e400" }), { Cash = "5e399" }, Omega) == nil, "omega-string spend ok")
check(Guard.Overdrawn(Guard.Read({ Cash = -5 }), { Cash = -5, Stardust = 3 }, Omega) == nil, "already-bad balance does not block other updates")

-- through DataService.AtomicUpdate
local function service(profile)
	local player = H.player("P")
	local svc = setmetatable({
		_profiles = { [player] = profile }, _atoms = { [player] = AtomicState.new(profile) },
		_releasing = {}, _writeGen = {}, _dirty = {}, _broken = {},
	}, { __index = DataService })
	function svc:_queueDocumentSync() end
	return svc, player
end
local function fresh()
	local p = Template.New()
	p.Cash, p.Stardust, p.Cores = 100, 50, 7
	return p
end
for _, label in { "shop", "production", "overcharge" } do
	local svc, player = service(fresh())
	local ok, result = svc:AtomicUpdate(player, function(draft)
		draft.Stardust = draft.Stardust - 80
		draft.Cash = 999
		return { ok = true }
	end, true, label)
	local now = svc._profiles[player]
	check(ok == true and type(result) == "table" and result.ok == false, label .. ": overdraw reports a soft failure")
	check(now.Stardust == 50 and now.Cash == 100, label .. ": overdraw leaves the profile untouched")
	local ok2, result2 = svc:AtomicUpdate(player, function(draft)
		draft.Stardust = draft.Stardust - 50
		return { ok = true }
	end, true, label)
	check(ok2 == true and result2.ok == true and svc._profiles[player].Stardust == 0, label .. ": spending the whole balance commits")
end
do
	local p = fresh()
	p.Cash = -3 -- bad on load; sanitize repairs it, it must not lock the player out
	local svc, player = service(p)
	local ok, result = svc:AtomicUpdate(player, function(draft) draft.Cores = draft.Cores + 1 return { ok = true } end, true, "production")
	check(ok == true and result.ok == true, "a pre-existing bad balance does not block unrelated updates")
end

if #failures > 0 then error("currency guard failures:\n  " .. table.concat(failures, "\n  ")) end
print(string.format("[TEST] currency guard: %d checks (cash, ore, NaN, omega strings, sanitized and hot paths, exact spend, bad-on-load) passed", checks))

--!nocheck
-- Crate opening through the real GameService._openItemCrate and _mutate on a real AtomicState:
-- a roll that fails or throws part-way through a multi-open rolls the whole transaction back,
-- including the key deduction, pity and any relics minted before the failure. Run `npx rbxtsc` first.
local H = require("./_server_harness")
local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end
local function deepEqual(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in a do if not deepEqual(v, b[k]) then return false end end
	for k in b do if a[k] == nil then return false end end
	return true
end
local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local out = {} for k, x in v do out[k] = deepCopy(x) end return out
end

H.mock("Server/AstralForge/Runtime/ServerNetwork", { ServerEvents = H.Stub, ServerFunctions = H.Stub })
H.env.Enum = setmetatable({}, { __index = function(_, cat)
	return setmetatable({}, { __index = function(_, item) return cat .. "." .. item end })
end })
local GS = H.load("Server/AstralForge/Services/GameService").GameService
local AtomicState = H.load("Server/AstralForge/Services/Security/AtomicState")
local DataTemplate = H.load("Server/AstralForge/DataTemplate")

local CRATE = "ForgeCrate"
local function service(failAt, mode)
	local player = H.player()
	local profile = DataTemplate.New()
	profile.Items.Keys = { [CRATE] = 10 }
	profile.Items.Pity = { [CRATE] = 3 }
	local atom = AtomicState.new(profile)
	local data = {}
	function data:Update(_, cb) local ok, r = atom:Transact(cb) return ok, r end
	function data:AtomicUpdate(p, cb) return self:Update(p, cb) end
	function data:Get() return (atom:Read()) end
	local rolls = 0
	local fields = {
		_data = data, _runtime = { [player] = {} }, _running = true, _random = H.env.Random.new(3),
		_antiCheat = { Observe = function() return true, false end },
		_toastPlayer = function() end, _pushState = function() end, _effect = H.Stub,
	}
	fields._rollItemDefinition = function(self, crate, pity)
		rolls += 1
		if rolls == failAt then
			if mode == "throw" then error("roll exploded") end
			return nil, "Common", false
		end
		return GS._rollItemDefinition(self, crate, pity)
	end
	local s = setmetatable(fields, { __index = function(_, k)
		local v = GS[k]
		if v ~= nil then return v end
		return H.Stub
	end })
	return s, player, atom
end

-- success: five keys spent, five relics, pity moved
do
	local s, p, atom = service(nil)
	local r = s:_openItemCrate(p, CRATE, 5)
	local after = atom:Read()
	local n = 0 for _ in after.Items.Inventory do n += 1 end
	check(r.ok == true, "five-open succeeds: " .. tostring(r.message))
	check(after.Items.Keys[CRATE] == 5, "five keys deducted")
	check(n == 5, "five relics added")
end
-- a roll fails part-way: nothing sticks
for _, mode in { "nil", "throw" } do
	local s, p, atom = service(3, mode)
	local before = deepCopy(atom:Read())
	local ok, r = pcall(s._openItemCrate, s, p, CRATE, 5)
	local after = atom:Read()
	check(not ok or r.ok == false, mode .. ": failed open reports failure")
	check(after.Items.Keys[CRATE] == 10, mode .. ": key deduction rolled back")
	check(after.Items.Pity[CRATE] == 3, mode .. ": pity rolled back")
	check(next(after.Items.Inventory) == nil, mode .. ": relics minted before the failure rolled back")
	check(deepEqual(after.Items, before.Items) and deepEqual(after.Stats, before.Stats), mode .. ": items and stats untouched")
end
-- too few keys: refused before any deduction
do
	local s, p, atom = service(nil)
	atom:Read().Items.Keys[CRATE] = 4
	local r = s:_openItemCrate(p, CRATE, 5)
	check(r.ok == false and atom:Read().Items.Keys[CRATE] == 4, "not enough keys refused, keys kept")
end

if #failures > 0 then
	for _, f in failures do print("  FAIL: " .. f) end
	error(string.format("crate rollback failed: %d problems", #failures))
end
print(string.format("[TEST] crate rollback: %d checks (multi-open success, mid-roll failure and throw roll back keys/pity/relics, key shortfall) passed", checks))

--!nocheck
-- Rollback semantics of AtomicState (Transact and TransactInPlace), read from the compiled TS
-- (out/). Pins exactly what a faster AtomicUpdate must preserve: a throw or an { ok = false }
-- result leaves the live profile identical (same table, same contents, same revision), and a
-- commit publishes every write. Run `npx rbxtsc` first.
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local task = require("@lune/task")

local function isTable(v)
	return type(v) == "table"
end
local TS = { import = function() return { isTable = isTable } end }
local stub = {}
function stub:GetService() return stub end
function stub:WaitForChild() return stub end
local env = setmetatable({ game = stub, script = stub, task = task, require = function() return TS end }, { __index = getfenv() })
local path = "out/Server/AstralForge/Services/Security/AtomicState.luau"
local AtomicState = luau.load(fs.readFile(path), { chunkName = path, environment = env })()

-- deterministic PRNG so failures reproduce
local seed = 0x2545F491
local function rand(n)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed % n + 1
end

local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local r = {}
	for k, c in v do r[k] = deepCopy(c) end
	return r
end
local function deepEqual(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then return false end
	end
	for k in b do
		if a[k] == nil then return false end
	end
	return true
end
-- every table reachable from root, so identity can be checked after a rollback
local function tablesOf(root, out)
	out = out or {}
	if type(root) == "table" and not out[root] then
		out[root] = true
		for _, c in root do tablesOf(c, out) end
	end
	return out
end

local function newProfile()
	local p = {
		Meta = { Revision = 7, LastSeen = 1 },
		Cash = 100, Vault = 5, Zone = 2,
		Machines = { Drill = 3, Press = 1 },
		Stats = { PlayTime = 10, Collected = 4 },
		Items = { Inventory = {}, Equipped = { Head = "a" } },
		Flags = { TutorialDone = false, SeenHints = { "QuickFind" } },
	}
	for i = 1, 40 do
		p.Items.Inventory["u" .. i] = { Id = "x" .. i, Level = i % 5, Rolls = { i, i + 1 } }
	end
	return p
end

-- a random edit anywhere in the profile: scalars, nested tables, new keys, removed keys,
-- replaced sections, array pushes
local SECTIONS = { "Machines", "Stats", "Items", "Flags", "Meta" }
local function mutate(p)
	local kind = rand(8)
	local section = SECTIONS[rand(#SECTIONS)]
	if kind == 1 then
		p.Cash = rand(1000)
	elseif kind == 2 then
		p[section]["k" .. rand(5)] = rand(50)
	elseif kind == 3 then
		p[section] = { Replaced = rand(9) }
	elseif kind == 4 then
		local inv = p.Items and p.Items.Inventory
		if type(inv) == "table" then
			local item = inv["u" .. rand(40)]
			if type(item) == "table" then
				item.Level = rand(99)
				if type(item.Rolls) == "table" then table.insert(item.Rolls, rand(7)) end
			end
		end
	elseif kind == 5 then
		p[section] = nil
	elseif kind == 6 then
		p["New" .. rand(3)] = { Deep = { Value = rand(5) } }
	elseif kind == 7 then
		local f = p.Flags
		if type(f) == "table" and type(f.SeenHints) == "table" then table.insert(f.SeenHints, "ChatWhisper") end
	else
		p.Zone = nil
	end
end

-- Transact: random edits then throw / soft-fail / commit
local rounds = 0
for _ = 1, 400 do
	local live = newProfile()
	local state = AtomicState.new(live)
	local before = deepCopy(live)
	local identities = tablesOf(live)
	local outcome = rand(3)
	local edits = rand(12)
	local ok, result, revision = state:Transact(function(draft)
		for _ = 1, edits do mutate(draft) end
		if outcome == 1 then error("boom") end
		if outcome == 2 then return { ok = false } end
		return { ok = true }
	end)
	local value, rev = state:Read()
	if outcome == 3 then
		assert(ok and result.ok == true, "commit reports success")
		assert(rev == 8, "commit bumps revision")
		if type(value.Meta) == "table" then
			assert(value.Meta.Revision == 8, "commit stamps Meta.Revision")
		end
		assert(deepEqual(before, live), "commit never writes through to the old value")
	else
		assert(value == live, "rollback keeps the same profile table")
		assert(deepEqual(before, live), "rollback leaves the profile untouched")
		for t in identities do
			assert(tablesOf(live)[t], "rollback keeps every nested table identity")
		end
		assert(rev == 7, "rollback keeps the revision")
		assert((outcome == 1) == (ok == false), "a throw reports failure, a soft fail reports success")
	end
	rounds += 1
end

-- incrementRevision = false commits without bumping
do
	local state = AtomicState.new(newProfile())
	state:Transact(function(d) d.Cash = 1 end, false)
	local v, rev = state:Read()
	assert(v.Cash == 1 and rev == 7 and v.Meta.Revision == 7, "no-bump commit")
end

-- TransactInPlace: edits confined to the declared sections roll back exactly; commits keep
-- table identity
local DEEP, SHALLOW = { "Items" }, { "Stats", "Meta" }
for _ = 1, 300 do
	local live = newProfile()
	local state = AtomicState.new(live)
	local before = deepCopy(live)
	local outcome = rand(3)
	local ok = state:TransactInPlace(function(p)
		for _ = 1, rand(10) do
			local k = rand(5)
			if k == 1 then p.Cash = rand(500)
			elseif k == 2 then p.Stats["s" .. rand(4)] = rand(9)
			elseif k == 3 then p.Items.Inventory["u" .. rand(40)].Level = rand(50)
			elseif k == 4 then p.Meta.LastSeen = rand(99)
			else p.Extra = rand(3) end
		end
		if outcome == 1 then error("boom") end
		if outcome == 2 then return { ok = false } end
	end, DEEP, SHALLOW)
	local value = state:Read()
	assert(value == live, "in-place keeps the profile table")
	if outcome ~= 3 then
		assert(deepEqual(before, live), "in-place rollback restores declared sections and root fields")
		assert((outcome == 1) == (ok == false), "in-place failure reporting")
	end
	rounds += 1
end

-- Structural diffs (rewrite 04): long mixed sequences on one cell match a deep-copy reference
-- model, every committed value is never written afterwards by Transact, unchanged sections are
-- shared by identity, and aliased or frozen tables a callback inserts behave like deep copies.
local function inPlaceEdit(p)
	local k = rand(4)
	if k == 1 then p.Cash = rand(500)
	elseif k == 2 and type(p.Stats) == "table" then p.Stats["s" .. rand(4)] = rand(9)
	elseif k == 3 then p.Meta.LastSeen = rand(99)
	else p.Extra = rand(3) end
end
for _ = 1, 60 do
	local state = AtomicState.new(newProfile())
	local model = deepCopy(newProfile())
	for _ = 1, 25 do
		local outcome = rand(3)
		local value = state:Read()
		local frozenBefore = deepCopy(value)
		if rand(4) == 1 then
			local seq = {}
			local ok = state:TransactInPlace(function(p)
				for _ = 1, rand(4) do
					local before = rand(1000000)
					seed = before
					inPlaceEdit(p)
					table.insert(seq, before)
				end
				if outcome == 1 then error("boom") end
				if outcome == 2 then return { ok = false } end
			end, { "Items" }, { "Stats", "Meta" })
			if outcome == 3 then
				for _, s0 in seq do seed = s0; inPlaceEdit(model) end
				model.Meta.Revision += 1
			end
		else
			local seq = {}
			local ok = state:Transact(function(draft)
				for _ = 1, rand(8) do
					local s0 = rand(1000000)
					seed = s0
					mutate(draft)
					table.insert(seq, s0)
				end
				if rand(5) == 1 then draft.Alias = draft.Machines end
				if rand(5) == 1 then draft.Frozen = table.freeze({ 1, 2 }) end
				if outcome == 1 then error("boom") end
				if outcome == 2 then return { ok = false } end
				return { ok = true, seq = seq }
			end)
			local committedValue = state:Read()
			if outcome == 3 then
				assert(deepEqual(frozenBefore, value), "commit never writes through to the old value")
				-- unchanged sections are shared, not copied
				for key, section in committedValue do
					if type(section) == "table" and deepEqual(section, frozenBefore[key]) and type(value[key]) == "table" then
						assert(section == value[key] or not deepEqual(section, value[key]), "an unchanged section keeps its table")
					end
				end
				model = deepCopy(committedValue)
			else
				assert(committedValue == value and deepEqual(frozenBefore, value), "rollback leaves the committed value untouched")
			end
		end
		assert(deepEqual(model, state:Read()), "cell matches the deep-copy reference model")
	end
	rounds += 1
end
-- a frozen table put in by a callback can be edited by the next transaction (it was thawed)
do
	local state = AtomicState.new(newProfile())
	assert(state:Transact(function(d) d.List = table.freeze({ 1 }) end))
	local ok = state:Transact(function(d) table.insert(d.List, 2) end)
	assert(ok and #state:Read().List == 2, "frozen tables are thawed like a deep copy would")
	-- aliasing inside one draft does not leak into the next transaction
	assert(state:Transact(function(d) d.A = { n = 1 }; d.B = d.A end))
	assert(state:Transact(function(d) d.A.n = 5 end))
	local v = state:Read()
	assert(v.A.n == 5 and v.B.n == 1, "aliased draft tables split on commit")
	-- an untouched section is the same table across commits
	local before = state:Read().Items
	assert(state:Transact(function(d) d.Cash = 1 end))
	assert(state:Read().Items == before, "untouched sections are shared by identity")
	rounds += 1
end

print(string.format("[TEST] atomic state rollback: %d randomized transactions match their pre-image", rounds))

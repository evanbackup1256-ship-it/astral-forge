--!strict
-- Purpose: Reproduce the old destroyed-model reparent and verify owned parked-cell cleanup and stale callbacks.
-- Owner: Astral Forge verification. Dependencies: actual reel callback and ViewportLifetime; Lune fs/luau. Last-reviewed: 2026-10-05.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
type Signal = { Connect: (Signal, () -> ()) -> { Disconnect: () -> () } }
type Owner = { Parent: boolean?, Destroying: Signal }
type Child = { Parent: Owner?, Destroy: () -> () }
type Lifetime = { alive: () -> boolean, own: (Child) -> (), dispose: () -> () }
type Factory = { new: (Owner) -> Lifetime }
local callbacks: { [() -> ()]: boolean } = {}
local signal: Signal = { Connect = function(_self: Signal, callback: () -> ()): { Disconnect: () -> () }
	callbacks[callback] = true
	return { Disconnect = function(): () callbacks[callback] = nil end }
end }
local owner: Owner = { Parent = true, Destroying = signal }
local closed = false
local writes = 0
local destroyed = 0
local cell: Child = setmetatable({ Destroy = function(): () destroyed += 1 end }, {
	__newindex = function(_self: Child, key: string, value: Owner?): ()
		if key == "Parent" then
			if closed then error("The Parent property of Model is locked") end
			writes += 1
		end
	end,
})
local factory: () -> Factory = luau.load(fs.readFile("src/Client/AstralForge/ViewportLifetime.luau"), { environment = { table = table } })
local lifetime = factory().new(owner)
lifetime.own(cell)
local function callback(source: string): () -> ()
	local start = assert(source:find("local function showAround(pos)", 1, true))
	local finish = assert(source:find("local baseLight", start, true))
	local fragment = source:sub(start, finish - 1)
	local build: () -> () -> () = luau.load("local front = nil\n" .. fragment .. "return function() showAround(1) end", {
		environment = { math = math, CYCLE = 20, VISIBLE_CELLS = 3, cells = { [1] = cell }, model = owner, lifetime = lifetime },
	})
	return build()
end
local before = callback(fs.readFile("audit/repro-fixtures/CASINO-DRUM.before.txt"))
local after = callback(fs.readFile("src/Client/AstralForge/pages/PagesCasino.luau"))
closed = true
owner.Parent = nil
for fn in table.clone(callbacks) do fn() end
local ok, problem = pcall(before)
assert(not ok and tostring(problem):find("Parent property", 1, true), "old callback must reproduce the supplied locked-parent trace")
assert(pcall(after), "new callback must not touch disposed geometry")
assert(writes == 0 and destroyed == 1 and not lifetime.alive())
lifetime.dispose()
assert(destroyed == 1, "cleanup must be idempotent")
print("[TEST] reproduced old destroyed-model reparent; stale callback and parked-cell cleanup now stop safely")

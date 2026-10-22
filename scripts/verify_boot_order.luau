--!nocheck
-- BootGraph: dependencies run first, ties keep declaration order, the server's construction
-- order is unchanged, and unknown dependencies, duplicates and cycles fail loudly.
-- Run `npx rbxtsc` first.
local H = require("./_server_harness")
local M = H.load("Server/AstralForge/Runtime/BootGraph")
local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end
local noop = function() end

local server = M.BootGraph.new()
server:add("player data construction", {}, noop)
server:add("administration construction", { "player data construction" }, noop)
server:add("integrity construction", { "player data construction" }, noop)
server:add("convergence construction", { "player data construction" }, noop)
server:add("gameplay construction", { "player data construction", "administration construction", "integrity construction", "convergence construction" }, noop)
check(table.concat(server:names(), ",") == "player data construction,administration construction,integrity construction,convergence construction,gameplay construction", "server construction order is unchanged")

local g = M.BootGraph.new()
g:add("c", { "b" }, noop)
g:add("a", {}, noop)
g:add("b", { "a" }, noop)
g:add("d", {}, noop)
check(table.concat(g:names(), ",") == "a,b,c,d", "dependencies first, then declaration order (" .. table.concat(g:names(), ",") .. ")")

local bad = M.BootGraph.new()
bad:add("x", { "missing" }, noop)
check(not pcall(function() bad:order() end), "an unknown dependency errors")
local dup = M.BootGraph.new()
dup:add("x", {}, noop)
check(not pcall(function() dup:add("x", {}, noop) end), "a duplicate step errors")
local cyc = M.BootGraph.new()
cyc:add("x", { "y" }, noop)
cyc:add("y", { "x" }, noop)
local ok, err = pcall(function() cyc:order() end)
check(not ok and string.find(tostring(err), "cycle", 1, true) ~= nil, "a cycle errors and names it")

-- CoreRuntime really declares its steps through the graph
local fs = require("@lune/fs")
local core = fs.readFile("src/Server/AstralForge/Runtime/CoreRuntime.ts")
check(string.find(core, "new BootGraph()", 1, true) ~= nil and string.find(core, "graph.order()", 1, true) ~= nil, "CoreRuntime boots through BootGraph")

if #failures > 0 then
	for _, f in failures do print("  FAIL: " .. f) end
	error(string.format("boot order failed: %d problems", #failures))
end
print(string.format("[TEST] boot order: %d checks passed", checks))

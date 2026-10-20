--!nocheck
-- Boot graph checks on the compiled out/ tree, mapped through default.project.json:
--  1. every Flamework constructor dependency ("flamework:parameters" id) names a module that
--     is actually required at boot, starting from the entry scripts and their addPaths folders
--     and following TS.import / require chains. roblox-ts drops imports that are only used as
--     types, so an injected class nobody imports is never registered and ignite fails.
--  2. every static instance lookup rooted at `script` or a service (script.Parent chains,
--     :WaitForChild("X"), TS.import paths, require chains) points at something that exists in
--     the project tree. Runtime-created children are listed in RUNTIME_CHILDREN.
-- Run `npx rbxtsc` first.
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local project = serde.decode("json", fs.readFile("default.project.json"))

-- children created at runtime (by the server or the engine) under folders the tree maps
local RUNTIME_CHILDREN = {}
local args = { ... }
local ROOT = args[1] or "."

local function join(a, b) return a == "" and b or (a .. "/" .. b) end
local function isFile(p) return fs.isFile(ROOT .. "/" .. p) end
local function isDir(p) return fs.isDir(ROOT .. "/" .. p) end

-- node: { tree = <project node or nil>, fs = <fs path or nil>, ipath = "A/B/C" }
local function treeChild(node, name)
	if node.tree and node.tree[name] and type(node.tree[name]) == "table" then
		local t = node.tree[name]
		return { tree = t, fs = t["$path"], ipath = join(node.ipath, name) }
	end
	if node.fs and isDir(node.fs) then
		local base = join(node.fs, name)
		for _, ext in { ".luau", ".server.luau", ".client.luau", ".lua", ".json", ".model.json", ".meta.json" } do
			if isFile(base .. ext) and ext ~= ".meta.json" then return { fs = base .. ext, ipath = join(node.ipath, name) } end
		end
		if isDir(base) then return { fs = base, ipath = join(node.ipath, name) } end
	end
	return nil
end
local function known(node) -- do we know the full child list of this node?
	return node.fs ~= nil and isDir(node.fs)
end
local function resolve(ipath)
	local node = { tree = project.tree, fs = nil, ipath = "" }
	for seg in string.gmatch(ipath, "[^/]+") do
		node = treeChild(node, seg)
		if not node then return nil end
	end
	return node
end
local function moduleFile(node)
	if not node or not node.fs then return nil end
	if isFile(node.fs) then return node.fs end
	for _, init in { "init.luau", "init.server.luau", "init.client.luau", "init.lua" } do
		if isFile(join(node.fs, init)) then return join(node.fs, init) end
	end
	return nil
end

-- fs file -> instance path, from the tree's $path roots
local roots = {}
local function collectRoots(t, ipath)
	for k, v in t do
		if type(v) == "table" and string.sub(k, 1, 1) ~= "$" then
			local ip = join(ipath, k)
			if v["$path"] then table.insert(roots, { fs = v["$path"], ipath = ip }) end
			collectRoots(v, ip)
		end
	end
end
collectRoots(project.tree, "")
local function instanceOf(file)
	for _, r in roots do
		if file == r.fs then return r.ipath end
		if string.sub(file, 1, #r.fs + 1) == r.fs .. "/" then
			local rel = string.sub(file, #r.fs + 2)
			rel = string.gsub(rel, "/init%.[%a]+%.?l?u?a?u?$", "")
			rel = string.gsub(rel, "/init%.luau$", "")
			rel = string.gsub(rel, "%.server%.luau$", ""); rel = string.gsub(rel, "%.client%.luau$", "")
			rel = string.gsub(rel, "%.luau$", ""); rel = string.gsub(rel, "%.lua$", "")
			if string.match(rel, "^init%.") then return r.ipath end
			return join(r.ipath, rel)
		end
	end
	return nil
end
local function parentOf(ipath) return string.match(ipath, "^(.*)/[^/]+$") or "" end

-- expression chain parser ------------------------------------------------------------------
-- returns ipath (or nil if not static), end position, and the list of steps for reporting
local function parseChain(src, pos, scriptPath, aliases)
	local ipath
	local s, e, svc = string.find(src, '^game:GetService%("([%w]+)"%)', pos)
	if s then
		ipath, pos = svc, e + 1
	else
		s, e = string.find(src, "^script", pos)
		if s and not string.match(string.sub(src, e + 1, e + 1), "[%w_]") then
			ipath, pos = scriptPath, e + 1
		else
			local s2, e2, id = string.find(src, "^([%a_][%w_]*)", pos)
			if s2 and aliases[id] then ipath, pos = aliases[id], e2 + 1 else return nil end
		end
	end
	local steps = {}
	while true do
		local a, b = string.find(src, "^%.Parent", pos)
		if a and not string.match(string.sub(src, b + 1, b + 1), "[%w_]") then
			ipath = parentOf(ipath); pos = b + 1
			table.insert(steps, { kind = "parent", ipath = ipath })
		else
			local c, d, name = string.find(src, '^:WaitForChild%(%s*"([^"]+)"%s*[,%)]', pos)
			if c then
				table.insert(steps, { kind = "child", parent = ipath, name = name })
				ipath = join(ipath, name)
				pos = d
				if string.sub(src, d, d) == "," then
					local close = string.find(src, ")", d, true)
					pos = close
				end
				pos += 1
			else
				break
			end
		end
	end
	return ipath, pos, steps
end

-- scan every compiled file --------------------------------------------------------------
local files = {}
local function scan(dir)
	for _, name in fs.readDir(ROOT .. "/" .. dir) do
		local p = join(dir, name)
		if isDir(p) then scan(p) elseif string.match(name, "%.luau$") then table.insert(files, p) end
	end
end
for _, r in roots do
	if string.sub(r.fs, 1, 4) == "out/" then
		if isDir(r.fs) then scan(r.fs) elseif isFile(r.fs) then table.insert(files, r.fs) end
	end
end
table.sort(files)

local failures = {}
local lookups = 0
local edges = {} -- file -> { file }
local paramIds = {} -- { file, id }
local entryPaths = {} -- file -> { ipath }
local unresolvedChild = function(file, parent, name)
	local node = resolve(parent)
	if node == nil then return false end -- parent itself unknown (runtime instance)
	if not known(node) and node.tree == nil then return false end
	if treeChild(node, name) then return false end
	if RUNTIME_CHILDREN[parent .. "/" .. name] then return false end
	if not known(node) then return false end -- tree-only node (a service): children can be runtime
	return true
end

for _, file in files do
	-- drop line comments (block comments are rare in compiled output and harmless here)
	local src = string.gsub(fs.readFile(ROOT .. "/" .. file), "%-%-[^\n]*", "")
	local scriptPath = instanceOf(file)
	local aliases = {}
	-- `local x = <static chain>` at the end of a line makes x an alias for that instance
	for name, at in string.gmatch(src, "local ([%a_][%w_]*) = ()") do
		local ip, e = parseChain(src, at, scriptPath, aliases)
		if ip and string.match(src, "^%s*\n", e) then aliases[name] = ip end
	end
	edges[file] = {}
	local function addEdge(ipath)
		local target = moduleFile(resolve(ipath))
		if target then table.insert(edges[file], target) end
	end
	local function checkSteps(steps, line)
		for _, st in steps do
			if st.kind == "child" then
				lookups += 1
				if unresolvedChild(file, st.parent, st.name) then
					table.insert(failures, string.format("%s:%d  %s has no child %q", file, line, st.parent, st.name))
				end
			elseif st.kind == "parent" and st.ipath == "" then
				table.insert(failures, string.format("%s:%d  .Parent climbs above the DataModel", file, line))
			end
		end
	end
	local function lineAt(p) local _, n = string.gsub(string.sub(src, 1, p), "\n", "") return n + 1 end
	-- every chain anywhere (script / service rooted)
	local pos = 1
	while true do
		local s = string.find(src, "[%w_:%.]", pos)
		if not s then break end
		local prev = s > 1 and string.sub(src, s - 1, s - 1) or ""
		if not string.match(prev, "[%w_%.:]") then
			local ipath, e, steps = parseChain(src, s, scriptPath, aliases)
			if ipath and steps and #steps > 0 then
				checkSteps(steps, lineAt(s))
				local before = string.sub(src, math.max(1, s - 8), s - 1)
				if string.match(before, "require%($") then addEdge(ipath) end
				pos = e
			else
				pos = (string.find(src, "[^%w_]", s) or #src) + 1
			end
		else
			pos = s + 1
		end
		if pos > #src then break end
	end
	-- TS.import(script, <base>, "a", "b", ...)
	for argsText in string.gmatch(src, "TS%.import%(script, ([^\n]-)%)[%.%s\n]") do
		local base, e = parseChain(argsText, 1, scriptPath, aliases)
		if base then
			local ip = base
			local rest = string.sub(argsText, e)
			local ok = true
			for name in string.gmatch(rest, '"([^"]+)"') do
				lookups += 1
				if unresolvedChild(file, ip, name) then
					table.insert(failures, string.format("%s  TS.import: %s has no child %q", file, ip, name))
					ok = false
					break
				end
				ip = join(ip, name)
			end
			if ok then addEdge(ip) end
		end
	end
	for list in string.gmatch(src, '"flamework:parameters", (%b{})') do
		for id in string.gmatch(list, '"([^"]+)"') do table.insert(paramIds, { file = file, id = id }) end
	end
	for list in string.gmatch(src, "Flamework%._addPaths%((%b{})%)") do
		entryPaths[file] = {}
		for inner in string.gmatch(string.sub(list, 2, -2), "%b{}") do
			local segs = {}
			for seg in string.gmatch(inner, '"([^"]+)"') do table.insert(segs, seg) end
			table.insert(entryPaths[file], table.concat(segs, "/"))
		end
	end
end

-- boot closure from each entry ------------------------------------------------------------
local entries = 0
for _, file in files do
	if string.match(file, "%.server%.luau$") or string.match(file, "%.client%.luau$") then
		entries += 1
		local loaded = {}
		local queue = { file }
		for _, ip in entryPaths[file] or {} do
			local node = resolve(ip)
			if not node then
				table.insert(failures, file .. "  addPaths folder missing: " .. ip)
			elseif node.fs then
				for _, f in files do
					if string.sub(f, 1, #node.fs + 1) == node.fs .. "/" then table.insert(queue, f) end
				end
			end
		end
		while #queue > 0 do
			local f = table.remove(queue)
			if not loaded[f] then
				loaded[f] = true
				for _, t in edges[f] or {} do table.insert(queue, t) end
			end
		end
		-- every injected id used by a class loaded from this entry must itself be loaded
		for _, p in paramIds do
			if loaded[p.file] then
				local modPath = string.match(p.id, "^(.-)@")
				if modPath and not string.match(modPath, "^@") and not string.match(p.id, "^@") then
					local target
					for _, f in files do
						if f == "out/" .. modPath .. ".luau" or f == "out/" .. modPath .. "/init.luau" then target = f break end
					end
					if target == nil then
						table.insert(failures, string.format("%s  injects %s, which has no compiled module", p.file, p.id))
					elseif not loaded[target] then
						table.insert(failures, string.format(
							"%s  injects %s, but %s is never required from %s (type-only import was elided)",
							p.file, p.id, target, file))
					end
				end
			end
		end
	end
end

if #failures > 0 then
	for _, line in failures do print("  " .. line) end
	error(string.format("boot graph failed: %d problems (listed above)", #failures))
end
print(string.format("[TEST] boot graph: %d files, %d entries, %d injected ids, %d static lookups resolve", #files, entries, #paramIds, lookups))

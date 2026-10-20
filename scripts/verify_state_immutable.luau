--!strict
-- Client code must never edit a session state section in place. The shell chrome memos
-- (UiCore/chromeMemo.ts) compare state sections by reference, and clientStore's
-- optimisticSession copies sections, so an in-place edit would leave the UI stale.
-- Fails on any of these through a `state` or `session` path:
--   state.X = / state.X.Y += / state["X"] = / state?.X = ...   (assignment through a path)
--   table.insert(state.X, ...) / table.remove(...) / table.clear(...) / rawset(state...)
--   state.X.push(...) / .pop() / .clear() / .unshift(...)      (roblox-ts array/map mutators)
-- `state.current` (React refs) is skipped. Files whose local `state` is not the session are
-- listed in ALLOWED with the reason, and the count must match exactly so stale entries fail.

local fs = require("@lune/fs")

local ROOT = "src/Client"

local ALLOWED: { [string]: number } = {
	-- `state` is the crate model's own animation table (t, yaw, open, shake), not the session
	["src/Client/AstralForge/UiCore/crateModel.ts"] = 4,
}

local function walk(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path, out)
		elseif string.match(name, "%.tsx?$") then
			table.insert(out, path)
		end
	end
end

-- strip a trailing // comment and string literals so text in them can't match
local function clean(line: string): string
	local out = string.gsub(line, '"[^"]*"', '""')
	out = string.gsub(out, "'[^']*'", "''")
	out = string.gsub(out, "`[^`]*`", "``")
	local cut = string.find(out, "//", 1, true)
	if cut then
		out = string.sub(out, 1, cut - 1)
	end
	return out
end

-- the root word must stand alone (not fooState, not state2)
local function rootAt(line: string, at: number, word: string): boolean
	local before = if at > 1 then string.sub(line, at - 1, at - 1) else ""
	return not string.match(before, "[%w_%.]")
end

-- read a path like `state.A?.B["c"][d]` starting at `at`; returns the end index and segment count
local function readPath(line: string, at: number, word: string): (number, number, string?)
	local i = at + #word
	local segments = 0
	local first: string? = nil
	while true do
		local dotted = string.match(line, "^%??%.([%a_][%w_]*)", i)
		if dotted then
			local s, e = string.find(line, "^%??%.[%a_][%w_]*", i)
			i = (e :: number) + 1
			segments += 1
			if first == nil then
				first = dotted
			end
			continue
		end
		local s, e = string.find(line, "^%b[]", i)
		if s then
			i = (e :: number) + 1
			segments += 1
			if first == nil then
				first = "[]"
			end
			continue
		end
		break
	end
	return i, segments, first
end

local MUTATORS = { "push", "pop", "clear", "unshift", "insert", "remove", "set", "delete" }

local BASE_ROOTS: { [string]: any } = { state = true, session = true }

-- roots: state/session plus this file's local aliases of a state path (alias = true)
local function lineHits(line: string, roots: { [string]: any }?): number
	local hits = 0
	local active: { [string]: any } = roots or BASE_ROOTS
	for word, isAlias in active do
		local from = 1
		while true do
			local s, e = string.find(line, word, from, true)
			if not s then
				break
			end
			from = (e :: number) + 1
			if not rootAt(line, s :: number, word) then
				continue
			end
			local afterWord = string.sub(line, (e :: number) + 1, (e :: number) + 1)
			if string.match(afterWord, "[%w_]") then
				continue
			end
			local stop, segments, first = readPath(line, s :: number, word)
			if segments == 0 or first == "current" then
				continue
			end
			local rest = string.sub(line, stop)
			-- assignment (=, +=, -=, *=, /=, %=, ..=) but not == / => / >= / <=
			if string.match(rest, "^%s*[%+%-%*/%%]?=[^=>]") or string.match(rest, "^%s*%.%.=") or string.match(rest, "^%s*[%+%-%*/%%]?=$") then
				hits += 1
				continue
			end
			-- trailing method mutator: state.X.push(...)
			if segments >= (if isAlias == "alias" then 1 else 2) then
				local lastDot = string.match(string.sub(line, s :: number, stop - 1), "%.([%a_][%w_]*)$")
				if lastDot and table.find(MUTATORS, lastDot) and string.match(rest, "^%s*%(") then
					hits += 1
					continue
				end
			end
		end
	end
	-- table.insert(state.X, ...), table.remove/clear, rawset(state...)
	for _, fn in { "table%.insert", "table%.remove", "table%.clear", "rawset" } do
		for target in string.gmatch(line, fn .. "%(%s*([%a_][%w_]*[%.%?%[]?)") do
			local root = string.match(target, "^([%a_][%w_]*)")
			local tail = string.sub(target, #(root :: string) + 1)
			local kind = if root then active[root :: string] else nil
			if kind ~= nil and (tail ~= "" or kind == "alias" or fn == "rawset" or fn == "table%.clear") then
				hits += 1
			end
		end
	end
	return hits
end

-- Single-file alias tracking, in one forward pass: `const flags = state.Flags;`,
-- `let list = session.Story ?? [];`, `const { Flags, Items: bag } = state;` and chains of those
-- (`const keys = bag.Keys;`) make the local name an alias of a state section from that line on,
-- so `flags.X = ...`, `list.push(...)` or `table.insert(keys, ...)` count as in-place edits.
-- Any later `const`/`let` of the same name that isn't an alias ends it (simple shadowing).
-- Copies (table.clone, spreads, .map, any call) are not aliases.
local function updateRoots(line: string, roots: { [string]: any })
	local name, rhs = string.match(line, "^%s*[cl][oe][nt]s?t?%s+([%a_][%w_]*)%s*[^=]*=%s*([^;]*);?%s*$")
	if name and rhs and roots[name] ~= true then
		local alias = false
		local root = string.match(rhs, "^([%a_][%w_]*)")
		if root and roots[root] ~= nil then
			local stop, segments = readPath(rhs, 1, root :: string)
			local rest = string.sub(rhs, stop)
			local plain = rest == "" or string.match(rest, "^%s*as%s") ~= nil or string.match(rest, "^%s*%?%?") ~= nil
			alias = (segments > 0 or roots[root] == "alias") and plain
		end
		roots[name] = if alias then "alias" else nil
	end
	local fields, droot = string.match(line, "^%s*[cl][oe][nt]s?t?%s+{([^}]*)}%s*[^=]*=%s*([%a_][%w_]*)[^;(]*;?%s*$")
	if fields then
		local alias = droot ~= nil and roots[droot] ~= nil
		for part in string.gmatch(fields, "[^,]+") do
			local local_ = string.match(part, ":%s*([%a_][%w_]*)%s*$") or string.match(part, "^%s*([%a_][%w_]*)%s*$")
			if local_ and roots[local_] ~= true then
				roots[local_] = if alias then "alias" else nil
			end
		end
	end
end

local function sourceHits(source: string, onHit: ((lineNo: number, raw: string, n: number) -> ())?): number
	local roots: { [string]: any } = { state = true, session = true }
	local total = 0
	local lineNo = 0
	for raw in string.gmatch(source .. "\n", "([^\n]*)\n") do
		lineNo += 1
		local line = clean(raw)
		local n = lineHits(line, roots)
		updateRoots(line, roots)
		if n > 0 then
			total += n
			if onHit then
				onHit(lineNo, raw, n)
			end
		end
	end
	return total
end

local files = {}
walk(ROOT, files)
table.sort(files)

local failures = {}
local total = 0
local counts: { [string]: number } = {}
for _, path in files do
	sourceHits(fs.readFile(path), function(lineNo, raw, n)
		counts[path] = (counts[path] or 0) + n
		if ALLOWED[path] == nil then
			table.insert(failures, `{path}:{lineNo}: state section edited in place: {string.gsub(raw, "^%s+", "")}`)
		end
	end)
end
for path, allowed in ALLOWED do
	local found = counts[path] or 0
	if found ~= allowed then
		table.insert(failures, `{path}: ALLOWED says {allowed} local-state writes, found {found}; update the list`)
	end
	total += found
end

-- self-check: the scanner must catch each mutation shape and ignore safe ones
local SHOULD_HIT = {
	"state.Cash = 5;", "state.Flags.TutorialDone = true;", 'session["Items"].Keys = {};', "state?.Mailbox.Unread += 1;",
	"table.insert(state.Story, chapter);", "state.Command.Weekly.push(entry);", "rawset(session, \"Cash\", 0)",
}
local SHOULD_MISS = {
	"const state = props.state;", "if (state.Cash === undefined) {", "const x = state.Cash;", "ref.state = next;",
	"state.current = {};", "const done = state.Flags?.TutorialDone !== true;", "setState(state.Cash)", "(s) => state.Cash >= s",
}
for _, sample in SHOULD_HIT do
	if lineHits(clean(sample)) == 0 then
		table.insert(failures, `self-check: missed mutation: {sample}`)
	end
end
for _, sample in SHOULD_MISS do
	if lineHits(clean(sample)) ~= 0 then
		table.insert(failures, `self-check: false positive: {sample}`)
	end
end

local ALIAS_HIT = {
	"const flags = state.Flags;\nflags.TutorialDone = true;",
	"let list = session.Story ?? [];\nlist.push(chapter);",
	"const { Items: bag } = state;\nconst keys = bag.Keys;\ntable.insert(keys, 1);",
}
local ALIAS_MISS = {
	"const flags = table.clone(state.Flags);\nflags.TutorialDone = true;",
	"const list = [...state.Story];\nlist.push(chapter);",
	"const rows = state.Quests.map((q) => q);\nrows.push(x);",
	"const flags = state.Flags;\nflags = other;",
	"const lines = session.Chat ?? [];\nconst lines: Row[] = [];\nlines.push(row);",
}
local function sampleHits(sample: string): number
	return sourceHits(sample)
end
for _, sample in ALIAS_HIT do
	if sampleHits(sample) == 0 then
		table.insert(failures, `self-check: missed alias mutation: {sample}`)
	end
end
for _, sample in ALIAS_MISS do
	if sampleHits(sample) ~= 0 then
		table.insert(failures, `self-check: alias false positive: {sample}`)
	end
end

if #failures > 0 then
	error("state immutability:\n" .. table.concat(failures, "\n"))
end
print(`[TEST] state immutable: {#files} client files, no in-place session section edits ({total} allowed local-state writes)`)

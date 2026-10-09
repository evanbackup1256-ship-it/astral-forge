--!nocheck
-- Deep audit: a broad static analysis of the game's Luau, well past what the build and the verify suite
-- check. It tokenizes every file (strings, interpolation and long brackets aware), walks scopes, and
-- cross-references the game's own registries.
--
--   lune run scripts/deep_audit.luau            write docs/audit-report.md and print a summary
--   lune run scripts/deep_audit.luau --strict   also exit 1 when any ERROR-level finding remains
--
-- Checks (severity in brackets):
--   compile        [error] every file compiles
--   undefined      [error] names read that are never defined (nil at runtime)
--   global-write   [error] assignments that create accidental globals
--   hooks          [error] React hooks called conditionally, in loops, or after an early return
--   dup-key        [error] duplicate keys in one table constructor (the first value is silently lost)
--   dup-local-fn   [warn]  a local function defined twice in the same scope
--   icon           [error] Icon kinds the icon atlas doesn't have (VectorIconFace indexes nil and errors)
--   palette        [error] Palette colours that don't exist
--   audio          [warn]  Audio cues with no mixer entry and no sound-sheet voice (play silently)
--   protocol       [error] dispatched actions missing from Protocol, the firewall, the server or the client allowlist
--   settings       [warn]  settings keys read by the client that the schema doesn't define
--   effect-deps    [warn]  useEffect / useMemo / useCallback with no dependency list (runs every render)
--   effect-leak    [warn]  effects that connect, start loops or create instances without a cleanup
--   busy-loop      [error] `while true` loops with no yield, break or return (freeze)
--   per-frame      [warn]  allocation, instance creation, tree walks or logging inside per-frame callbacks
--   player-leak    [warn]  tables keyed by player that are never cleared (grow with every join)
--   async-pcall    [warn]  yielding *Async calls outside pcall (an outage throws into game logic)
--   invoke-client  [error] RemoteFunction:InvokeClient on the server (a client can hang it forever)
--   client-clock   [warn]  os.time() on the client (the client clock is not the server's)
--   format-int     [info]  string.format %d/%x on values that may be fractional (Luau truncates toward zero; NaN/inf print as -9223372036854775808)
--   deprecated     [warn]  wait/spawn/delay globals, :connect, Instance.new(class, parent)
--   self-assign    [warn]  `x = x`
--   shadow-builtin [warn]  locals shadowing string/table/math/game/...
--   registers      [warn]  functions near Luau's 255-register / 200-upvalue limits
--   print          [info]  print() left in shipped code
--   long-function  [info]  functions longer than 600 lines

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local ROOTS = { "src/Client", "src/Server", "src/Shared/AstralForge" }
local SKIP_DIRS = { Packages = true, Vendor = true, node_modules = true }
local STRICT = table.find(process.args, "--strict") ~= nil

local findings = {}
-- `-- audit-ignore: <check>` on the flagged line or the line above silences one finding
local sourceLines = {}
local function suppressed(check, file, line)
	if not line or line < 1 then
		return false
	end
	local lines = sourceLines[file]
	if lines == nil then
		local ok, raw = pcall(fs.readFile, file)
		lines = if ok then string.split((string.gsub(raw, "\r\n", "\n")), "\n") else {}
		sourceLines[file] = lines
	end
	for _, at in { line, line - 1 } do
		local text = lines[at]
		if text and string.find(text, "audit%-ignore:[%w%s,%-]*" .. string.gsub(check, "%-", "%%-")) then
			return true
		end
	end
	return false
end

local function report(severity, check, file, line, message)
	if suppressed(check, file, line) then
		return
	end
	table.insert(findings, { severity = severity, check = check, file = file, line = line or 0, message = message })
end

-- --------------------------------------------------------------------------------------------------
-- files
-- --------------------------------------------------------------------------------------------------

local files = {}
local function walk(path)
	if fs.isDir(path) then
		for _, name in fs.readDir(path) do
			if not SKIP_DIRS[name] then
				walk(path .. "/" .. name)
			end
		end
	elseif string.sub(path, -5) == ".luau" or string.sub(path, -4) == ".lua" then
		table.insert(files, path)
	end
end
for _, root in ROOTS do
	if fs.isDir(root) then
		walk(root)
	end
end
table.sort(files)
local sources = {}
for _, path in files do
	sources[path] = (string.gsub(fs.readFile(path), "\r\n", "\n"))
end
local function isClient(path)
	return string.find(path, "src/Client/", 1, true) ~= nil
end
local function isServer(path)
	return string.find(path, "src/Server/", 1, true) ~= nil
end

-- --------------------------------------------------------------------------------------------------
-- tokenizer
-- --------------------------------------------------------------------------------------------------

local KEYWORDS = {}
for _, k in { "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while", "continue" } do
	KEYWORDS[k] = true
end

local function tokenize(src)
	local toks = {}
	local n = #src
	local i = 1
	local line = 1
	local function push(kind, value, extra)
		table.insert(toks, { kind = kind, value = value, line = line, text = extra })
	end
	local function countLines(s)
		local _, c = string.gsub(s, "\n", "")
		line += c
	end
	local interpStack = {}
	local function readInterp()
		local start = i
		while i <= n do
			local c = string.sub(src, i, i)
			if c == "\\" then
				if string.sub(src, i + 1, i + 1) == "\n" then
					line += 1
				end
				i += 2
			elseif c == "`" then
				i += 1
				push("string", "`", string.sub(src, start, i - 2))
				return
			elseif c == "{" then
				i += 1
				push("string", "`", string.sub(src, start, i - 2))
				push("op", "(")
				table.insert(interpStack, 0)
				return
			else
				if c == "\n" then
					line += 1
				end
				i += 1
			end
		end
	end
	while i <= n do
		local c = string.sub(src, i, i)
		if c == "\n" then
			line += 1
			i += 1
		elseif string.find(c, "%s") then
			i += 1
		elseif c == "-" and string.sub(src, i + 1, i + 1) == "-" then
			local eq = string.match(src, "^%[(=*)%[", i + 2)
			if eq then
				local close = "]" .. eq .. "]"
				local stop = string.find(src, close, i + 4 + #eq, true) or n
				countLines(string.sub(src, i, stop))
				i = stop + #close
			else
				i = string.find(src, "\n", i, true) or n + 1
			end
		elseif string.find(c, "[%a_]") then
			local word = string.match(src, "^[%w_]+", i)
			i += #word
			push(if KEYWORDS[word] then "kw" else "name", word)
		elseif string.find(c, "%d") or (c == "." and string.find(string.sub(src, i + 1, i + 1), "%d")) then
			local num = string.match(src, "^0[xX][%x_]+", i) or string.match(src, "^0[bB][01_]+", i) or string.match(src, "^[%d_]*%.?[%d_]*[eE][%+%-]?[%d_]+", i) or string.match(src, "^[%d_]*%.?[%d_]*", i)
			i += #num
			push("number", num)
		elseif c == "\"" or c == "'" then
			local start = i
			i += 1
			while i <= n do
				local d = string.sub(src, i, i)
				if d == "\\" then
					if string.sub(src, i + 1, i + 1) == "\n" then
						line += 1
					elseif string.sub(src, i + 1, i + 1) == "z" then
						local ws = string.match(src, "^%s*", i + 2)
						countLines(ws)
						i += #ws
					end
					i += 2
				elseif d == c then
					i += 1
					break
				elseif d == "\n" then
					break
				else
					i += 1
				end
			end
			push("string", string.sub(src, start + 1, i - 2))
		elseif c == "`" then
			i += 1
			readInterp()
		elseif c == "[" and string.find(src, "^%[=*%[", i) then
			local eq = string.match(src, "^%[(=*)%[", i)
			local close = "]" .. eq .. "]"
			local stop = string.find(src, close, i, true) or n
			local body = string.sub(src, i + 2 + #eq, stop - 1)
			countLines(string.sub(src, i, stop))
			i = stop + #close
			push("string", body)
		elseif c == "{" and #interpStack > 0 then
			interpStack[#interpStack] += 1
			push("op", "{")
			i += 1
		elseif c == "}" and #interpStack > 0 and interpStack[#interpStack] == 0 then
			table.remove(interpStack)
			push("op", ")")
			i += 1
			readInterp()
		elseif c == "}" and #interpStack > 0 then
			interpStack[#interpStack] -= 1
			push("op", "}")
			i += 1
		else
			local three = string.sub(src, i, i + 2)
			local two = string.sub(src, i, i + 1)
			if three == "..." or three == "..=" or three == "//=" then
				push("op", three)
				i += 3
			elseif two == "==" or two == "~=" or two == "<=" or two == ">=" or two == ".." or two == "::" or two == "->" or two == "+=" or two == "-=" or two == "*=" or two == "/=" or two == "%=" or two == "^=" or two == "//" then
				push("op", two)
				i += 2
			else
				push("op", c)
				i += 1
			end
		end
	end
	push("eof", "<eof>")
	return toks
end

-- --------------------------------------------------------------------------------------------------
-- registries the cross-reference checks compare against
-- --------------------------------------------------------------------------------------------------

local function read(path)
	return sources[path] or (fs.isFile(path) and (string.gsub(fs.readFile(path), "\r\n", "\n"))) or ""
end
local function memberOf(source, member)
	local header = `__defs["{member}"] = function()\n`
	local start = string.find(source, header, 1, true)
	if not start then
		return ""
	end
	local stop = string.find(source, "\n__defs[\"", start + #header, true) or #source
	return string.sub(source, start, stop)
end

local artKit = read("src/Client/AstralForge/ArtKit.luau")
local ICONS = {}
do
	local block = string.match(artKit, "local VECTOR_ICON_INDEX = (%b{})")
	for key in string.gmatch(block or "", "([%a_][%w_]*) = %d+") do
		ICONS[key] = true
	end
end

local coreKit = read("src/Client/AstralForge/CoreKit.luau")
local PALETTE = {}
do
	local block = string.match(coreKit, "local Palette = (%b{})")
	for key in string.gmatch(block or "", "\n%s*([%a_][%w_]*) =") do
		PALETTE[key] = true
	end
	for key in string.gmatch(coreKit, "Palette%.([%a_][%w_]*) =") do
		PALETTE[key] = true
	end
end

local audioKit = read("src/Client/AstralForge/AudioKit.luau")
local sharedData = read("src/Shared/AstralForge/Shared/SharedData.luau")
local CUES = {}
do
	local audio = memberOf(audioKit, "audio")
	local cueBlock = string.match(audio, "local CUES = (%b{})") or ""
	for key in string.gmatch(cueBlock, "\n\t([%a_][%w_]*) = {") do
		CUES[key] = true
	end
	local sheet = memberOf(audioKit, "soundSheet")
	for key in string.gmatch(sheet, "\n\t([%a_][%w_]*) = \"") do
		CUES[key] = true
	end
	local manifest = memberOf(sharedData, "AssetManifest")
	for key in string.gmatch(manifest, "\n\t\t([%a_][%w_]*) = { [%d%.]+, ") do
		CUES[key] = true
	end
end

local protocolSrc = read("src/Shared/AstralForge/Shared/Protocol.luau")
local ACTIONS = {}
for key, value in string.gmatch(protocolSrc, "\n%s*([%a_][%w_]*) = \"([%a_][%w_]*)\"") do
	if key == value then
		ACTIONS[key] = true
	end
end
local serverServices = read("src/Server/AstralForge/Services/ServerServices.luau")
local firewall = read("src/Server/AstralForge/Services/RemoteFirewall.luau")

local SETTINGS = {}
do
	local schema = memberOf(sharedData, "SettingsSchema")
	for key in string.gmatch(schema, "key = \"([%a_][%w_]*)\"") do
		SETTINGS[key] = true
	end
	for key in string.gmatch(schema, "toggle%(\"([%a_][%w_]*)\"") do
		SETTINGS[key] = true
	end
	for key in string.gmatch(schema, "slider%(\"([%a_][%w_]*)\"") do
		SETTINGS[key] = true
	end
	for key in string.gmatch(schema, "choice%(\"([%a_][%w_]*)\"") do
		SETTINGS[key] = true
	end
	for key in string.gmatch(schema, "\n%s*([%a_][%w_]*) = true,") do
		SETTINGS[key] = true
	end
	-- hidden keys are saved and accepted by the server but never shown in the panel
	local hidden = string.match(schema, "HIDDEN_KEYS = table%.freeze%((%b{})") or string.match(schema, "HIDDEN_KEYS = (%b{})")
	if hidden then
		for key in string.gmatch(hidden, "([%a_][%w_]*)%s*=") do
			SETTINGS[key] = true
		end
	end
end

-- --------------------------------------------------------------------------------------------------
-- the walker
-- --------------------------------------------------------------------------------------------------

local GLOBALS = {}
for _, g in string.split("assert error getmetatable setmetatable ipairs pairs next pcall xpcall print rawequal rawget rawset rawlen select tonumber tostring type typeof unpack require newproxy gcinfo _G _VERSION getfenv setfenv loadstring coroutine string table math os debug utf8 bit32 buffer vector task delay spawn wait tick time elapsedTime warn game workspace Game Workspace script plugin shared settings UserSettings Enum Instance Vector2 Vector3 Vector2int16 Vector3int16 CFrame Color3 ColorSequence ColorSequenceKeypoint NumberSequence NumberSequenceKeypoint NumberRange UDim UDim2 Rect Region3 Region3int16 Ray BrickColor TweenInfo Random DateTime Font Axes Faces PhysicalProperties RaycastParams OverlapParams PathWaypoint Path2DControlPoint SharedTable Content DockWidgetPluginGuiInfo CatalogSearchParams FloatCurveKey RotationCurveKey Secret stats version printidentity ypcall collectgarbage self", " ") do
	GLOBALS[g] = true
end
local BUILTIN_SHADOW = { string = true, table = true, math = true, type = true, typeof = true, pairs = true, ipairs = true, game = true, workspace = true, print = true, error = true, tostring = true, tonumber = true, next = true, select = true, task = true, os = true, require = true, script = true }
local PER_FRAME = { RenderStepped = true, Heartbeat = true, Stepped = true, PreRender = true, PreSimulation = true, PostSimulation = true, PreAnimation = true }
local HOOK_CALLS = { useState = true, useEffect = true, useLayoutEffect = true, useMemo = true, useCallback = true, useRef = true, useBinding = true, useContext = true, useReducer = true }
local DEPS_HOOKS = { useEffect = true, useLayoutEffect = true, useMemo = true, useCallback = true }

local function analyse(path, src)
	local toks = tokenize(src)
	local function tk(k)
		return toks[k] or toks[#toks]
	end
	local function is(k, v)
		local t = tk(k)
		return t.value == v and (t.kind == "op" or t.kind == "kw")
	end
	local scopes = { {} }
	local blocks = {}
	local frames = {}
	local brackets = {}
	local tables = {}
	local calls = {}
	local expectDo = {}
	local ifKinds = {}
	local lastElseExpr = false
	local pendingUntilLine = nil
	local pendingFrameName = nil
	local reads, definedGlobals = {}, {}

	local function declare(name, line)
		local scope = scopes[#scopes]
		if BUILTIN_SHADOW[name] and line then
			report("warn", "shadow-builtin", path, line, `local '{name}' shadows the builtin`)
		end
		scope[name] = true
		local frame = frames[#frames]
		if frame then
			frame.locals += 1
		end
	end
	local function resolves(name)
		for s = #scopes, 1, -1 do
			if scopes[s][name] then
				return true
			end
		end
		return GLOBALS[name] == true
	end
	local function pushScope(kind, line)
		table.insert(scopes, {})
		table.insert(blocks, { kind = kind, line = line, bracketDepth = #brackets })
	end
	local function popScope()
		if #scopes > 1 then
			local block = table.remove(blocks)
			table.remove(scopes)
			if block and block.kind == "function" then
				local frame = table.remove(frames)
				if frame then
					local length = (tk(math.max(1, frame.endTok or 1)).line or 0) - frame.line
					if frame.locals > 190 then
						report("warn", "registers", path, frame.line, `function declares {frame.locals} locals (Luau caps registers at 255)`)
					end
				end
			end
			return block
		end
		return nil
	end
	local function skipBalanced(k)
		local depth = 0
		while k <= #toks do
			local v, kind = tk(k).value, tk(k).kind
			if kind == "op" and (v == "(" or v == "{" or v == "[") then
				depth += 1
			elseif kind == "op" and (v == ")" or v == "}" or v == "]") then
				depth -= 1
				if depth == 0 then
					return k + 1
				end
			end
			k += 1
		end
		return k
	end
	local function skipAngle(k)
		local depth = 0
		while k <= #toks do
			local v = tk(k).value
			if v == "<" then
				depth += 1
			elseif v == ">" then
				depth -= 1
				if depth == 0 then
					return k + 1
				end
			elseif v == "(" or v == "{" then
				k = skipBalanced(k) - 1
			end
			k += 1
		end
		return k
	end
	local parseType
	local function parseSimple(k)
		local t = tk(k)
		if t.value == "(" and t.kind == "op" then
			k = skipBalanced(k)
			if is(k, "->") then
				k = parseType(k + 1)
			end
		elseif t.value == "<" then
			k = skipAngle(k)
			if is(k, "(") then
				k = skipBalanced(k)
			end
			if is(k, "->") then
				k = parseType(k + 1)
			end
		elseif t.value == "{" and t.kind == "op" then
			k = skipBalanced(k)
		elseif t.kind == "name" and t.value == "typeof" and is(k + 1, "(") then
			k = skipBalanced(k + 1)
		elseif t.kind == "name" or t.value == "nil" or t.value == "true" or t.value == "false" then
			k += 1
			while is(k, ".") and tk(k + 1).kind == "name" do
				k += 2
			end
			if is(k, "<") then
				k = skipAngle(k)
			end
			if is(k, "...") then
				k += 1
			end
		elseif t.kind == "string" then
			k += 1
		elseif t.value == "..." then
			k += 1
			local nt = tk(k)
			if nt.kind == "name" or (nt.kind == "op" and (nt.value == "{" or nt.value == "(")) then
				k = parseSimple(k)
			end
		else
			k += 1
		end
		while is(k, "?") do
			k += 1
		end
		return k
	end
	parseType = function(k)
		if is(k, "|") or is(k, "&") then
			k += 1
		end
		k = parseSimple(k)
		while is(k, "|") or is(k, "&") do
			k = parseSimple(k + 1)
		end
		return k
	end
	local function functionHead(k, method, line, name)
		if is(k, "<") then
			k = skipAngle(k)
		end
		pushScope("function", line)
		table.insert(frames, { line = line, locals = 0, sawReturn = false, name = name, component = name ~= nil and string.find(name, "^%u") ~= nil })
		if method then
			declare("self")
		end
		if is(k, "(") then
			k += 1
			while k <= #toks and not is(k, ")") do
				local t = tk(k)
				if t.kind == "name" then
					declare(t.value)
					k += 1
				elseif t.value == ":" then
					k = parseType(k + 1)
				else
					k += 1
				end
			end
			k += 1
			if is(k, ":") then
				k = parseType(k + 1)
			end
		end
		return k
	end
	-- the innermost function frame's block index
	local function frameBlockIndex()
		for b = #blocks, 1, -1 do
			if blocks[b].kind == "function" then
				return b
			end
		end
		return 0
	end
	local i = 1
	while i <= #toks do
		local t = tk(i)
		if t.kind == "eof" then
			break
		end
		if pendingUntilLine and t.line > pendingUntilLine and #brackets == 0 then
			pendingUntilLine = nil
			popScope()
		end
		local v = t.value
		-- type declarations
		if t.kind == "name" and (v == "type" or v == "export") and (function()
			local k = i
			if v == "export" then
				if tk(k + 1).value ~= "type" then
					return false
				end
				k += 1
			end
			return tk(k + 1).kind == "name" and (is(k + 2, "=") or is(k + 2, "<"))
		end)() then
			local k = i + (if v == "export" then 1 else 0) + 2
			if is(k, "<") then
				k = skipAngle(k)
			end
			k += 1
			if tk(k).kind == "name" and tk(k).value == "typeof" then
				i = k
			else
				i = parseType(k)
			end
		elseif t.kind == "op" and v == "@" then
			i += 2
		elseif t.kind == "kw" and v == "local" then
			if is(i + 1, "function") then
				local name = tk(i + 2).value
				local scope = scopes[#scopes]
				if scope["__fn_" .. name] then
					report("warn", "dup-local-fn", path, t.line, `local function '{name}' is defined twice in the same scope (first at line {scope["__fn_" .. name]})`)
				end
				scope["__fn_" .. name] = t.line
				declare(name, t.line)
				i = functionHead(i + 3, false, t.line, name)
			else
				local k = i + 1
				local names = {}
				while tk(k).kind == "name" do
					table.insert(names, tk(k).value)
					if BUILTIN_SHADOW[tk(k).value] then
						report("warn", "shadow-builtin", path, t.line, `local '{tk(k).value}' shadows the builtin`)
					end
					k += 1
					if is(k, ":") then
						k = parseType(k + 1)
					end
					if is(k, "<") and tk(k + 1).kind == "name" and is(k + 2, ">") then
						k += 3
					end
					if is(k, ",") then
						k += 1
					else
						break
					end
				end
				i = k
				if is(i, "=") then
					i += 1
					local scope = scopes[#scopes]
					scope.__pending = scope.__pending or {}
					table.insert(scope.__pending, { names = names, depth = #brackets })
					-- a local function stored in a variable named like a component counts as a frame name
					if is(i, "function") then
						-- anonymous function assigned to a local: the frame gets the local's name
						pendingFrameName = names[1]
					end
				else
					for _, name in names do
						declare(name)
					end
				end
			end
		elseif t.kind == "kw" and v == "function" then
			local k = i + 1
			local frameName = pendingFrameName
			pendingFrameName = nil
			if tk(k).kind == "name" then
				local root = tk(k).value
				frameName = root
				local simple = not (is(k + 1, ".") or is(k + 1, ":"))
				if simple and not resolves(root) then
					definedGlobals[root] = t.line
				elseif not resolves(root) then
					table.insert(reads, { name = root, line = t.line })
				end
				k += 1
				local method = false
				while is(k, ".") or is(k, ":") do
					if is(k, ":") then
						method = true
					end
					frameName = tk(k + 1).value
					k += 2
				end
				i = functionHead(k, method, t.line, frameName)
			else
				i = functionHead(k, false, t.line, frameName)
			end
		elseif t.kind == "kw" and v == "for" then
			pushScope("for", t.line)
			local k = i + 1
			while tk(k).kind == "name" do
				declare(tk(k).value)
				k += 1
				if is(k, ":") then
					k = parseType(k + 1)
				end
				if is(k, ",") then
					k += 1
				else
					break
				end
			end
			table.insert(expectDo, "for")
			i = k
		elseif t.kind == "kw" and v == "while" then
			table.insert(expectDo, "while")
			-- busy loop check: while true do ... end with no yield
			if is(i + 1, "true") and is(i + 2, "do") then
				local depth, k = 1, i + 3
				local yields = false
				while k <= #toks and depth > 0 do
					local tv, tkind = tk(k).value, tk(k).kind
					if tkind == "kw" and (tv == "do" or tv == "then" or tv == "function" or tv == "repeat") then
						if tv ~= "then" or true then
							depth += if tv == "then" then 0 else 1
						end
					end
					if tkind == "kw" and tv == "if" then
						depth += 1
					end
					if tkind == "kw" and (tv == "end" or tv == "until") then
						depth -= 1
					end
					if (tkind == "kw" and (tv == "break" or tv == "return")) or (tkind == "name" and (tv == "wait" or tv == "Wait" or tv == "yield" or tv == "WaitForChild" or string.find(tv, "Async$") or tv == "Invoke" or tv == "InvokeServer" or tv == "PromptPurchase")) then
						yields = true
					end
					k += 1
				end
				if not yields then
					report("error", "busy-loop", path, t.line, "`while true` loop never yields, breaks or returns")
				end
			end
			i += 1
		elseif t.kind == "kw" and v == "do" then
			local owner = table.remove(expectDo)
			if owner == "while" or owner == nil then
				pushScope("do", t.line)
			end
			i += 1
		elseif t.kind == "kw" and v == "if" then
			local prev = tk(i - 1)
			local expr = i > 1
				and ((prev.kind == "op" and prev.value ~= ")" and prev.value ~= "]" and prev.value ~= "}" and prev.value ~= ";" and prev.value ~= "?" and prev.value ~= ">" and prev.value ~= "...")
					or (prev.kind == "kw" and (prev.value == "return" or prev.value == "and" or prev.value == "or" or prev.value == "not" or prev.value == "in" or prev.value == "until" or (prev.value == "then" and ifKinds[#ifKinds] == "expr") or (prev.value == "else" and lastElseExpr))))
			table.insert(ifKinds, if expr then "expr" else "stmt")
			i += 1
		elseif t.kind == "kw" and v == "then" then
			if ifKinds[#ifKinds] ~= "expr" then
				pushScope("then", t.line)
			end
			i += 1
		elseif t.kind == "kw" and (v == "elseif" or v == "else") then
			if ifKinds[#ifKinds] == "expr" then
				lastElseExpr = v == "else"
				if v == "else" then
					table.remove(ifKinds)
				end
			else
				lastElseExpr = false
				popScope()
				if v == "else" then
					pushScope("else", t.line)
				end
			end
			i += 1
		elseif t.kind == "kw" and v == "repeat" then
			pushScope("repeat", t.line)
			i += 1
		elseif t.kind == "kw" and v == "until" then
			pendingUntilLine = t.line
			i += 1
		elseif t.kind == "kw" and v == "end" then
			local closing = blocks[#blocks]
			if closing and (closing.kind == "then" or closing.kind == "else") then
				table.remove(ifKinds)
			end
			if closing and closing.kind == "function" and frames[#frames] then
				frames[#frames].endTok = i
				local length = t.line - frames[#frames].line
				if length > 600 then
					report("info", "long-function", path, frames[#frames].line, `function '{frames[#frames].name or "?"}' is {length} lines long`)
				end
			end
			popScope()
			i += 1
		elseif t.kind == "kw" and v == "return" then
			local frame = frames[#frames]
			if frame then
				-- a return nested in a conditional block of this function makes later hooks conditional
				local fb = frameBlockIndex()
				if #blocks > fb then
					frame.sawReturn = true
				end
			end
			i += 1
		elseif t.kind == "op" and (v == "(" or v == "{" or v == "[") then
			table.insert(brackets, v)
			if v == "{" then
				table.insert(tables, { keys = {}, depth = #brackets })
			end
			i += 1
		elseif t.kind == "op" and (v == ")" or v == "}" or v == "]") then
			if v == "}" and tables[#tables] and tables[#tables].depth == #brackets then
				table.remove(tables)
			end
			-- closing a tracked call
			local call = calls[#calls]
			if v == ")" and call and call.depth == #brackets then
				table.remove(calls)
				if call.kind == "deps" and not call.comma then
					report("warn", "effect-deps", path, call.line, `{call.name} has no dependency list, so it runs on every render`)
				elseif call.kind == "effect" then
					if call.subscribes and not call.cleans then
						report("warn", "effect-leak", path, call.line, `effect {call.what} but never returns a cleanup function`)
					end
				end
			end
			table.remove(brackets)
			i += 1
		elseif t.kind == "op" and v == "," then
			local call = calls[#calls]
			if call and call.kind == "deps" and call.depth == #brackets and #blocks == call.blocks then
				call.comma = true
			end
			i += 1
		elseif t.kind == "op" and v == "::" then
			i = parseType(i + 1)
		elseif t.kind == "name" then
			local prev = tk(i - 1)
			local afterDot = prev.kind == "op" and (prev.value == "." or prev.value == ":")
			local inTable = tables[#tables] ~= nil and tables[#tables].depth == #brackets
			local isKey = inTable and is(i + 1, "=") and (prev.value == "{" or prev.value == "," or prev.value == ";")
			if isKey then
				local keys = tables[#tables].keys
				if keys[v] then
					report("error", "dup-key", path, t.line, `key '{v}' appears twice in one table (first at line {keys[v]}); the first value is lost`)
				end
				keys[v] = t.line
			end
			-- hooks
			if HOOK_CALLS[v] and is(i + 1, "(") and (prev.value == "." and tk(i - 2).value == "React" or not afterDot) then
				local frame = frames[#frames]
				local fb = frameBlockIndex()
				if frame and frame.component then
					local conditional = nil
					for b = fb + 1, #blocks do
						local kind = blocks[b].kind
						if kind == "then" or kind == "else" or kind == "for" or kind == "do" or kind == "repeat" then
							conditional = kind
						end
					end
					if conditional then
						report("error", "hooks", path, t.line, `{v} is called inside a{if conditional == "for" then " loop" elseif conditional == "do" then " loop/do block" else "n if"} in '{frame.name}' (hooks must run in the same order every render)`)
					elseif frame.sawReturn then
						report("error", "hooks", path, t.line, `{v} runs after an early return in '{frame.name}' (hooks must run every render)`)
					end
				end
				if DEPS_HOOKS[v] then
					table.insert(calls, { kind = "deps", name = v, depth = #brackets + 1, blocks = #blocks, comma = false, line = t.line })
				end
			end
			-- effects that subscribe without cleanup
			if (v == "useEffect" or v == "useLayoutEffect") and is(i + 1, "(") then
				-- scan the effect body for subscriptions and cleanups
				local endTok = skipBalanced(i + 1)
				local subscribes, cleans = nil, false
				for k = i + 2, endTok - 1 do
					local tv = tk(k).value
					if tk(k).kind == "name" then
						if (tv == "Connect" or tv == "Once") and tk(k - 1).value == ":" then
							subscribes = subscribes or "connects a signal"
						elseif (tv == "delay" or tv == "spawn" or tv == "defer") and tk(k - 1).value == "." and tk(k - 2).value == "task" then
							subscribes = subscribes or "starts a task"
						elseif tv == "BindToRenderStep" or tv == "BindAction" or tv == "BindActionAtPriority" then
							subscribes = subscribes or "binds input"
						end
					elseif tk(k).kind == "kw" and tv == "return" and is(k + 1, "function") then
						cleans = true
					end
				end
				if subscribes and not cleans then
					report("warn", "effect-leak", path, t.line, `effect {subscribes} but never returns a cleanup function`)
				end
			end
			if not afterDot and not isKey then
				if not resolves(v) then
					local assign = is(i + 1, "=") and #brackets == 0
					if assign then
						definedGlobals[v] = definedGlobals[v] or t.line
						report("error", "global-write", path, t.line, `'{v}' is assigned without 'local' (creates a global)`)
					else
						table.insert(reads, { name = v, line = t.line })
					end
				end
			end
			-- self assignment: x = x
			if not afterDot and is(i + 1, "=") and tk(i + 2).kind == "name" and tk(i + 2).value == v and #brackets == 0 then
				local after = tk(i + 3)
				local CONTINUE = { ["."] = true, [":"] = true, ["("] = true, ["["] = true, ["+"] = true, ["-"] = true, ["*"] = true, ["/"] = true, ["//"] = true, ["%"] = true, ["^"] = true, [".."] = true, ["=="] = true, ["~="] = true, ["<"] = true, [">"] = true, ["<="] = true, [">="] = true, ["::"] = true, ["{"] = true }
				local continues = after.kind == "op" and CONTINUE[after.value] == true
				if not continues and not (after.kind == "kw" and (after.value == "or" or after.value == "and")) and prev.value ~= "local" and prev.value ~= "," then
					report("warn", "self-assign", path, t.line, `'{v} = {v}' does nothing`)
				end
			end
			i += 1
		else
			i += 1
		end
		local scope = scopes[#scopes]
		if scope.__pending then
			local nt = tk(i)
			local pt = tk(i - 1)
			local continues = (nt.kind == "op" and nt.value ~= "(" and nt.value ~= "{" and nt.value ~= "[" and nt.value ~= ";")
				or (nt.kind == "kw" and (nt.value == "and" or nt.value == "or" or nt.value == "then"))
				or (pt.kind == "op" and pt.value ~= ")" and pt.value ~= "}" and pt.value ~= "]" and pt.value ~= ";")
				or (pt.kind == "kw" and (pt.value == "and" or pt.value == "or" or pt.value == "not" or pt.value == "function" or pt.value == "return" or pt.value == "in" or pt.value == "local"))
			for idx = #scope.__pending, 1, -1 do
				local p = scope.__pending[idx]
				if #brackets <= p.depth and (nt.kind == "eof" or (pt.kind == "op" and pt.value == ";") or (nt.line > pt.line and not continues) or (nt.kind == "kw" and (nt.value == "local" or nt.value == "return" or nt.value == "if" or nt.value == "for" or nt.value == "while" or nt.value == "end" or nt.value == "else" or nt.value == "elseif" or nt.value == "until"))) then
					for _, name in p.names do
						scope[name] = true
						local frame = frames[#frames]
						if frame then
							frame.locals += 1
						end
					end
					table.remove(scope.__pending, idx)
				end
			end
			if #scope.__pending == 0 then
				scope.__pending = nil
			end
		end
	end
	local seen = {}
	for _, r in reads do
		if not definedGlobals[r.name] and not seen[r.name .. r.line] then
			seen[r.name .. r.line] = true
			report("error", "undefined", path, r.line, `'{r.name}' is read but never defined (nil at runtime)`)
		end
	end
	return toks
end

-- --------------------------------------------------------------------------------------------------
-- per-file checks on top of the walker's tokens
-- --------------------------------------------------------------------------------------------------

local usedActions = {}
local playerTables = {}

local function lineChecks(path, src, toks)
	local lines = string.split(src, "\n")
	-- per-frame callbacks: scan their bodies by indentation
	for index, line in lines do
		local signal = string.match(line, "%.([%a]+):Connect%(function") or (string.find(line, "subscribeContinuous%(function") and "subscribeContinuous") or (string.find(line, "BindToRenderStep%(") and "BindToRenderStep")
		if signal and (PER_FRAME[signal] or signal == "subscribeContinuous" or signal == "BindToRenderStep") then
			local indent = string.match(line, "^(\t*)")
			local stop = index + 1
			while stop <= #lines do
				local l = lines[stop]
				if string.match(l, "^(\t*)") == indent and string.find(l, "^\t*end") then
					break
				end
				stop += 1
			end
			local problems = {}
			for k = index + 1, stop - 1 do
				local l = lines[k]
				if string.find(l, "Instance%.new%(") then
					problems["creates instances"] = k
				end
				if string.find(l, ":GetDescendants%(") or string.find(l, ":GetChildren%(") then
					problems["walks the instance tree"] = k
				end
				if string.find(l, ":FindFirstChild") or string.find(l, ":WaitForChild%(") then
					problems["searches for children"] = k
				end
				if string.find(l, "^%s*print%(") or string.find(l, "^%s*warn%(") then
					problems["logs"] = k
				end
				if string.find(l, "require%(") then
					problems["requires a module"] = k
				end
				if string.find(l, "= {[^}]") or string.find(l, "= {}") or string.find(l, "%(%s*{") then
					problems["allocates tables"] = problems["allocates tables"] or k
				end
			end
			for what, at in problems do
				report("warn", "per-frame", path, at, `per-frame {signal} callback {what} every frame`)
			end
		end
		-- deprecated
		if string.find(line, "[^%.%w_:]wait%(") or string.find(line, "^wait%(") then
			report("warn", "deprecated", path, index, "global wait() (throttled, use task.wait)")
		end
		if string.find(line, "[^%.%w_:]spawn%(") or string.find(line, "[^%.%w_:]delay%(") then
			report("warn", "deprecated", path, index, "global spawn()/delay() (use task.spawn / task.delay)")
		end
		if string.find(line, ":connect%(") and not string.find(line, "changed:connect%(") then
			report("warn", "deprecated", path, index, ":connect (use :Connect)")
		end
		if string.find(line, "Instance%.new%(%s*\"[%w]+\"%s*,") then
			report("warn", "deprecated", path, index, "Instance.new(class, parent) parents before properties are set (slow); set Parent last")
		end
		-- client clock
		local fallback = false
		for back = math.max(1, index - 6), index - 1 do
			if string.find(lines[back], "GetServerTimeNow", 1, true) then
				fallback = true
			end
		end
		if isClient(path) and string.find(line, "os%.time%(%)") and not fallback then
			report("warn", "client-clock", path, index, "os.time() on the client; compare server timestamps against workspace:GetServerTimeNow()")
		end
		-- server-only hazards
		if isServer(path) and string.find(line, ":InvokeClient%(") then
			report("error", "invoke-client", path, index, "RemoteFunction:InvokeClient on the server can hang forever if the client never answers")
		end
		if string.find(line, "^%s*print%(") then
			report("info", "print", path, index, "print() in shipped code")
		end
	end
	-- string.format with integer specifiers
	for k = 1, #toks - 4 do
		local t = toks[k]
		if t.kind == "name" and t.value == "format" and toks[k - 1] and toks[k - 1].value == "." and toks[k - 2] and toks[k - 2].value == "string" and toks[k + 1].value == "(" and toks[k + 2].kind == "string" then
			local fmt = toks[k + 2].value
			local specs = {}
			for spec in string.gmatch(fmt, "%%[%-%+ #0]*%d*%.?%d*([%a%%])") do
				if spec ~= "%" then
					table.insert(specs, spec)
				end
			end
			-- split the arguments at top-level commas
			local args, current, depth, j = {}, {}, 0, k + 3
			while j <= #toks do
				local tv = toks[j].value
				if toks[j].kind == "op" and (tv == "(" or tv == "{" or tv == "[") then
					depth += 1
				elseif toks[j].kind == "op" and (tv == ")" or tv == "}" or tv == "]") then
					if depth == 0 then
						break
					end
					depth -= 1
				end
				if depth == 0 and toks[j].kind == "op" and tv == "," then
					table.insert(args, current)
					current = {}
				else
					table.insert(current, toks[j])
				end
				j += 1
			end
			table.insert(args, current)
			if args[1] and #args[1] == 0 then
				table.remove(args, 1)
			end
			for n, spec in specs do
				if spec == "d" or spec == "i" or spec == "x" or spec == "X" then
					local arg = args[n]
					if arg then
						local safe = false
						for _, at in arg do
							if at.kind == "name" and (at.value == "floor" or at.value == "round" or at.value == "ceil" or at.value == "len" or at.value == "NextInteger") then
								safe = true
							elseif at.kind == "op" and (at.value == "#" or at.value == "//") then
								safe = true
							end
						end
						if #arg == 1 and arg[1].kind == "number" and not string.find(arg[1].value, "[%.eE]") then
							safe = true
						end
						if not safe then
							local text = {}
							for _, at in arg do
								table.insert(text, at.value)
							end
							report("info", "format-int", path, t.line, `%{spec} is given '{table.concat(text, " ")}', which may be fractional (truncated toward zero, NaN prints as a huge negative)`)
						end
					end
				end
			end
		end
	end
	-- Async calls outside pcall; Icon kinds; Palette; Audio; actions; settings; player tables
	local pcallDepth = {}
	local brackets = 0
	-- which component each table literal is the props of (createElement(X, { ... }) / h(X, { ... }))
	local ICON_OWNERS = { Icon = true, IconTile = true, GlyphFace = true, VectorIconFace = true }
	local braceOwners = {}
	for k, t in toks do
		if t.kind == "op" and t.value == "{" then
			local owner = nil
			if toks[k - 1] and toks[k - 1].value == "," and toks[k - 2] and toks[k - 2].kind == "name" and toks[k - 3] and toks[k - 3].value == "(" and toks[k - 4] and (toks[k - 4].value == "createElement" or toks[k - 4].value == "h") then
				owner = toks[k - 2].value
			end
			table.insert(braceOwners, owner or false)
		elseif t.kind == "op" and t.value == "}" then
			table.remove(braceOwners)
		end
		if t.kind == "op" and t.value == "(" then
			brackets += 1
			if toks[k - 1] and toks[k - 1].kind == "name" and (toks[k - 1].value == "pcall" or toks[k - 1].value == "xpcall" or toks[k - 1].value == "spawn" or toks[k - 1].value == "Retry") then
				table.insert(pcallDepth, brackets)
			end
		elseif t.kind == "op" and t.value == ")" then
			if pcallDepth[#pcallDepth] == brackets then
				table.remove(pcallDepth)
			end
			brackets -= 1
		elseif t.kind == "name" then
			local v = t.value
			local prev = toks[k - 1]
			if string.find(v, "Async$") and prev and (prev.value == ":" or prev.value == ".") and #pcallDepth == 0 and toks[k + 1] and toks[k + 1].value == "(" then
				local owner = toks[k - 2] and toks[k - 2].value or "?"
				if not (string.find(v, "^Prompt") or v == "PreloadAsync" or owner == "SaveUtil") then
					report("warn", "async-pcall", path, t.line, `{owner}:{v}(...) yields and can throw; wrap it in pcall`)
				end
			end
			if v == "kind" and toks[k + 1] and toks[k + 1].value == "=" and toks[k + 2] and toks[k + 2].kind == "string" and isClient(path) and ICON_OWNERS[braceOwners[#braceOwners] or ""] then
				local kind = toks[k + 2].value
				if next(ICONS) ~= nil and not ICONS[kind] then
					-- only count it when it's an icon-ish context (Icon / IconTile / EmptyState etc.)
					report("error", "icon", path, t.line, `icon kind "{kind}" is not in the icon atlas (VECTOR_ICON_INDEX); the icon errors when drawn`)
				end
			end
			if v == "icon" and toks[k + 1] and toks[k + 1].value == "=" and toks[k + 2] and toks[k + 2].kind == "string" and isClient(path) then
				local kind = toks[k + 2].value
				if next(ICONS) ~= nil and kind ~= "" and not ICONS[kind] then
					report("error", "icon", path, t.line, `icon "{kind}" is not in the icon atlas (VECTOR_ICON_INDEX)`)
				end
			end
			if v == "Palette" and toks[k + 1] and toks[k + 1].value == "." and toks[k + 2] and toks[k + 2].kind == "name" then
				local key = toks[k + 2].value
				if next(PALETTE) ~= nil and not PALETTE[key] then
					report("error", "palette", path, t.line, `Palette.{key} does not exist (nil colour)`)
				end
			end
			if v == "play" and prev and prev.value == ":" and toks[k - 2] and toks[k - 2].value == "Audio" and toks[k + 1].value == "(" and toks[k + 2].kind == "string" then
				local cue = toks[k + 2].value
				if next(CUES) ~= nil and not CUES[cue] then
					report("warn", "audio", path, t.line, `Audio cue "{cue}" has no mixer entry or sheet voice (plays nothing)`)
				end
			end
			if v == "dispatch" and toks[k + 1] and toks[k + 1].value == "(" and toks[k + 2] and toks[k + 2].kind == "string" and isClient(path) then
				usedActions[toks[k + 2].value] = usedActions[toks[k + 2].value] or { path = path, line = t.line }
			end
			if v == "Settings" and prev and prev.value == "." and toks[k + 1] and toks[k + 1].value == "." and toks[k + 2] and toks[k + 2].kind == "name" and isClient(path) then
				local key = toks[k + 2].value
				if next(SETTINGS) ~= nil and not SETTINGS[key] then
					report("warn", "settings", path, t.line, `state.Settings.{key} is not defined by SettingsSchema`)
				end
			end
			-- tables keyed by a player
			if isServer(path) and toks[k + 1] and toks[k + 1].value == "[" and toks[k + 2] and (toks[k + 2].value == "player" or toks[k + 2].value == "plr") and toks[k + 3] and toks[k + 3].value == "]" and toks[k + 4] and toks[k + 4].value == "=" and not (prev and (prev.value == "." or prev.value == ":")) then
				local key = path .. "::" .. v
				local entry = playerTables[key] or { path = path, name = v, line = t.line, cleared = false }
				playerTables[key] = entry
				if toks[k + 5] and toks[k + 5].value == "nil" then
					entry.cleared = true
				end
			end
		end
	end
end

-- --------------------------------------------------------------------------------------------------
-- run
-- --------------------------------------------------------------------------------------------------

local started = os.clock()
for _, path in files do
	local src = sources[path]
	local ok, err = pcall(luau.compile, src)
	if not ok then
		report("error", "compile", path, tonumber(string.match(tostring(err), ":(%d+):")) or 0, tostring(err))
	end
	local okAnalyse, toksOrErr = pcall(analyse, path, src)
	if okAnalyse then
		lineChecks(path, src, toksOrErr)
	else
		report("info", "analyser", path, 0, "could not analyse: " .. tostring(toksOrErr))
	end
end

-- player-keyed tables: cleared anywhere (X[player] = nil, table.clear(X), X[...] = nil) counts
for _, entry in playerTables do
	if not entry.cleared then
		local src = sources[entry.path]
		local name = entry.name
		local cleared = string.find(src, name .. "%[[%w_%.]+%] = nil") or string.find(src, "table%.clear%(" .. name) or string.find(src, name .. " = {}")
		if not cleared then
			report("warn", "player-leak", entry.path, entry.line, `'{name}[player]' is written but never cleared; it grows with every player who joins`)
		end
	end
end

-- dispatched actions against the protocol, firewall, server and client allowlist
local CLIENT_ONLY = { SyncShop = false }
for action, at in usedActions do
	if next(ACTIONS) ~= nil and not ACTIONS[action] then
		report("error", "protocol", at.path, at.line, `dispatch("{action}") but Protocol.Actions has no {action}`)
	elseif ACTIONS[action] then
		if not string.find(serverServices, "Protocol.Actions." .. action, 1, true) then
			report("error", "protocol", at.path, at.line, `{action} has no server handler`)
		end
		if not string.find(firewall, "Protocol.Actions." .. action, 1, true) then
			report("warn", "protocol", at.path, at.line, `{action} has no RemoteFirewall rule`)
		end
	end
end

-- --------------------------------------------------------------------------------------------------
-- report
-- --------------------------------------------------------------------------------------------------

local ORDER = { error = 1, warn = 2, info = 3 }
table.sort(findings, function(a, b)
	if ORDER[a.severity] ~= ORDER[b.severity] then
		return ORDER[a.severity] < ORDER[b.severity]
	end
	if a.check ~= b.check then
		return a.check < b.check
	end
	if a.file ~= b.file then
		return a.file < b.file
	end
	return a.line < b.line
end)
local counts, byCheck = { error = 0, warn = 0, info = 0 }, {}
for _, f in findings do
	counts[f.severity] += 1
	byCheck[f.check] = (byCheck[f.check] or 0) + 1
end
local lines = {
	"# Deep audit",
	"",
	`Files: {#files} · errors: {counts.error} · warnings: {counts.warn} · info: {counts.info} · {string.format("%.1f", os.clock() - started)}s`,
	"",
	"| Check | Findings |",
	"| --- | --- |",
}
local checkNames = {}
for check in byCheck do
	table.insert(checkNames, check)
end
table.sort(checkNames)
for _, check in checkNames do
	table.insert(lines, `| {check} | {byCheck[check]} |`)
end
table.insert(lines, "")
local current = nil
for _, f in findings do
	local heading = `## {string.upper(f.severity)} · {f.check}`
	if heading ~= current then
		current = heading
		table.insert(lines, "")
		table.insert(lines, heading)
		table.insert(lines, "")
	end
	table.insert(lines, `- \`{f.file}:{f.line}\` {f.message}`)
end
fs.writeFile("docs/audit-report.md", table.concat(lines, "\n") .. "\n")
print(lines[3])
for _, check in checkNames do
	print(string.format("  %-15s %d", check, byCheck[check]))
end
print("report: docs/audit-report.md")
if STRICT and counts.error > 0 then
	process.exit(1)
end

-- Static layout audit: extracts fixed panel heights, fixed-offset children, and
-- bottom-anchored elements so overlaps can be reviewed. Heuristic but complete
-- for the "button covers field" bug class.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function stripCommentsAndStrings(src)
	-- Replace string/comment contents with spaces, preserving length and newlines.
	local out = {}
	local i, n = 1, #src
	while i <= n do
		local c = src:sub(i, i)
		if c == "-" and src:sub(i + 1, i + 1) == "-" then
			-- line or block comment
			if src:sub(i + 2, i + 3) == "[[" then
				local e = src:find("]]", i + 4, true)
				local stop = e and (e + 1) or n
				table.insert(out, (src:sub(i, stop):gsub("[^\n]", " ")))
				i = stop + 1
			else
				local e = src:find("\n", i, true)
				local stop = e and (e - 1) or n
				table.insert(out, string.rep(" ", stop - i + 1))
				i = stop + 1
			end
		elseif c == '"' or c == "'" then
			local j = i + 1
			while j <= n do
				local d = src:sub(j, j)
				if d == "\\" then
					j += 2
				elseif d == c then
					break
				else
					j += 1
				end
			end
			table.insert(out, " " .. string.rep(" ", j - i - 1) .. " ")
			i = j + 1
		elseif c == "`" then
			-- backtick string: consume to matching backtick, tracking ${} nesting
			local j = i + 1
			local depth = 0
			while j <= n do
				local d = src:sub(j, j)
				if d == "\\" then
					j += 2
				elseif d == "$" and src:sub(j + 1, j + 1) == "{" then
					depth += 1
					j += 2
				elseif d == "{" and depth > 0 then
					depth += 1
					j += 1
				elseif d == "}" and depth > 0 then
					depth -= 1
					j += 1
				elseif d == "`" and depth == 0 then
					break
				else
					j += 1
				end
			end
			table.insert(out, " " .. (src:sub(i + 1, j - 1):gsub("[^\n]", " ")) .. " ")
			i = j + 1
		else
			table.insert(out, c)
			i += 1
		end
	end
	return table.concat(out)
end

local function lineOf(src, pos)
	local _, cnt = src:sub(1, pos):gsub("\n", "\n")
	return cnt + 1
end

local function audit(path)
	local raw = fs.readFile(path)
	local src = stripCommentsAndStrings(raw)
	local file = path:match("([^\\/]+)$")

	-- Collect numeric constants (file + function scope, order-independent best-effort)
	local consts = { TapTarget = 48, GAP = 14 }
	for name, val in src:gmatch("local%s+(%u[%u_]+)%s*=%s*(%d+)") do
		consts[name] = tonumber(val)
	end
	for name, val in src:gmatch("local%s+(%a[%w_]*)%s*=%s*(%d+)") do
		if consts[name] == nil then
			consts[name] = tonumber(val)
		end
	end

	-- Evaluate a simple numeric expression string -> number or nil
	local function evalNum(expr)
		if expr == nil then
			return nil
		end
		expr = expr:gsub("%s+", "")
		if expr:match("^if") then
			return nil
		end
		-- substitute constants
		local substituted = expr:gsub("[%a_][%w_]*", function(w)
			if consts[w] then
				return tostring(consts[w])
			end
			return w
		end)
		if substituted:match("[%a_]") then
			return nil
		end
		if substituted:match("[^%d%+%-%*/%(%)%.]") then
			return nil
		end
		local ok2, f = pcall(luau.load, "return " .. substituted)
		if not ok2 or type(f) ~= "function" then
			return nil
		end
		local ok, v = pcall(f)
		if ok and type(v) == "number" then
			return v
		end
		return nil
	end

	-- Collect element facts: every Size=/size= and Position=/position= near a line,
	-- plus Panel opens with their size + padding.
	local events = {}
	for sPos, h in src:gmatch("()size%s*=%s*UDim2%.new%(1,%s*0,%s*0,%s*([^%)]+)%)") do
		local hv = evalNum((h:gsub("%).*", "")))
		table.insert(events, { pos = sPos, kind = "sizeY", v = hv, raw = h })
	end
	for sPos, w, h in src:gmatch("()size%s*=%s*UDim2%.fromOffset%(([%d%.%-]+),%s*([^%)]+)%)") do
		table.insert(events, { pos = sPos, kind = "sizeOff", v = evalNum(h), raw = h })
	end
	for sPos, expr in src:gmatch("()position%s*=%s*UDim2%.fromOffset%(0,%s*([^%)]+)%)") do
		table.insert(events, { pos = sPos, kind = "topOff", v = evalNum((expr:gsub("%).*", ""))), raw = expr })
	end
	for sPos, expr in src:gmatch("()Position%s*=%s*UDim2%.fromOffset%(0,%s*([^%)]+)%)") do
		table.insert(events, { pos = sPos, kind = "topOff", v = evalNum((expr:gsub("%).*", ""))), raw = expr })
	end
	for sPos, expr in src:gmatch("()position%s*=%s*UDim2%.new%(0,%s*0,%s*1,%s*%-?([^%)]+)%)") do
		table.insert(events, { pos = sPos, kind = "bottomAnchor", v = evalNum("-" .. (expr:gsub("%).*", ""))), raw = expr })
	end
	for sPos, expr in src:gmatch("()Position%s*=%s*UDim2%.new%(0,%s*0,%s*1,%s*%-?([^%)]+)%)") do
		table.insert(events, { pos = sPos, kind = "bottomAnchor", v = evalNum("-" .. (expr:gsub("%).*", ""))), raw = expr })
	end
	for sPos, expr in src:gmatch("()position%s*=%s*UDim2%.new%(1,%s*%-[%d%.]+,%s*1,%s*%-?([^%)]+)%)") do
		table.insert(events, { pos = sPos, kind = "bottomAnchor", v = evalNum("-" .. (expr:gsub("%).*", ""))), raw = expr })
	end
	for sPos, pad in src:gmatch("()padding%s*=%s*(%d+)") do
		table.insert(events, { pos = sPos, kind = "padding", v = tonumber(pad) })
	end
	for sPos in src:gmatch("()React%.createElement%(Panel") do
		table.insert(events, { pos = sPos, kind = "panelOpen" })
	end
	for sPos in src:gmatch('()React%.createElement%("textbox"') do
		table.insert(events, { pos = sPos, kind = "textbox" })
	end
	for sPos in src:gmatch("()React%.createElement%(Button") do
		table.insert(events, { pos = sPos, kind = "button" })
	end
	table.sort(events, function(a, b)
		return a.pos < b.pos
	end)

	print("=== " .. file .. " ===")
	for _, e in events do
		print(string.format("  L%-5d %-13s %s", lineOf(src, e.pos), e.kind, tostring(e.v) .. " (" .. tostring(e.raw or "") .. ")"))
	end
end

local dir = "src/Client/AstralForge/pages"
for _, f in fs.readDir(dir) do
	if f:match("%.luau$") then
		audit(dir .. "/" .. f)
	end
end

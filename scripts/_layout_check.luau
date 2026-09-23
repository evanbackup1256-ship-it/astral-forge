-- Static layout checker for compiled React-Luau page files.
-- Parses createElement trees, evaluates UDim2 geometry, flags:
--   [COVER]    bottom-anchored sibling overlapping a top-anchored sibling
--   [SPILL]    top-anchored child extending past parent's inner bottom
--   [XSPILL]   child extending past parent's inner right edge
local fs = require("@lune/fs")

-- ============ LEXER ============
local function lex(src)
	local toks = {}
	local i, n = 1, #src
	while i <= n do
		local c = src:sub(i, i)
		local pos = i
		if c:match("%s") then
			i += 1
		elseif c == "-" and src:sub(i + 1, i + 1) == "-" then
			if src:sub(i + 2, i + 3) == "[[" then
				local e = src:find("]]", i + 4, true)
				i = e and (e + 2) or (n + 1)
			else
				local e = src:find("\n", i, true)
				i = e or (n + 1)
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
			toks[#toks + 1] = { t = "str", v = src:sub(i + 1, j - 1), pos = pos }
			i = j + 1
		elseif c == "`" then
			local j = i + 1
			local depth = 0
			while j <= n do
				local d = src:sub(j, j)
				if d == "\\" then
					j += 2
				elseif d == "{" then
					-- Luau interpolates with bare {expr}; nested strings inside
					-- can contain more braces — depth tracking keeps us in sync
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
			toks[#toks + 1] = { t = "str", v = "INTERP", pos = pos }
			i = j + 1
		elseif c:match("%d") then
			local j = i
			while j <= n and src:sub(j, j):match("[%w%.]") do
				j += 1
			end
			toks[#toks + 1] = { t = "num", v = tonumber(src:sub(i, j - 1)), pos = pos }
			i = j
		elseif c:match("[%a_]") then
			local j = i
			while j <= n and src:sub(j, j):match("[%w_]") do
				j += 1
			end
			local w = src:sub(i, j - 1)
			toks[#toks + 1] = { t = "name", v = w, pos = pos }
			i = j
		elseif src:sub(i, i + 1) == ".." or src:sub(i, i + 1) == "==" or src:sub(i, i + 1) == "~="
			or src:sub(i, i + 1) == "<=" or src:sub(i, i + 1) == ">=" or src:sub(i, i + 1) == "+=" or src:sub(i, i + 1) == "-=" then
			toks[#toks + 1] = { t = "sym", v = src:sub(i, i + 1), pos = pos }
			i += 2
		elseif src:sub(i, i + 2) == "..." then
			toks[#toks + 1] = { t = "name", v = "...", pos = pos }
			i += 3
		else
			toks[#toks + 1] = { t = "sym", v = c, pos = pos }
			i += 1
		end
	end
	toks[#toks + 1] = { t = "eof", pos = n + 1 }
	return toks
end

-- ============ VALUES ============
local function VNum(n)
	return { k = "num", s = { n } }
end
local function isNum(v)
	return v ~= nil and type(v) == "table" and v.k == "num"
end
local function VOpaque()
	return { k = "opaque" }
end
local function VTbl()
	return { k = "tbl", f = {}, a = {} }
end
local function unionNum(a, b)
	if isNum(a) and isNum(b) then
		local s = {}
		for _, x in a.s do
			s[#s + 1] = x
		end
		for _, x in b.s do
			s[#s + 1] = x
		end
		return { k = "num", s = s }
	end
	return VOpaque()
end
local function numBin(a, b, f)
	if isNum(a) and isNum(b) then
		local s = {}
		for _, x in a.s do
			for _, y in b.s do
				s[#s + 1] = f(x, y)
				if #s > 16 then
					return VOpaque()
				end
			end
		end
		return { k = "num", s = s }
	end
	return VOpaque()
end

-- ============ PARSER ============
local P = {}
P.__index = P

local function lineOf(src, pos)
	local _, cnt = src:sub(1, pos):gsub("\n", "\n")
	return cnt + 1
end

function P.new(src)
	return setmetatable({ toks = lex(src), i = 1, src = src }, P)
end
function P:peek()
	return self.toks[self.i] or { t = "eof", pos = 0 }
end
function P:peekAt(k)
	return self.toks[self.i + k] or { t = "eof", pos = 0 }
end
function P:take()
	local t = self.toks[self.i]
	self.i += 1
	return t
end
function P:sym(v)
	local t = self:peek()
	return t.t == "sym" and t.v == v
end
function P:name(v)
	local t = self:peek()
	return t.t == "name" and t.v == v
end
function P:takeSym(v)
	if self:sym(v) then
		self.i += 1
		return true
	end
	return false
end
function P:takeName(v)
	if self:name(v) then
		self.i += 1
		return true
	end
	return false
end
function P:err(msg)
	error(msg .. " @tok" .. self.i, 0)
end
function P:wantSym(v)
	if not self:takeSym(v) then
		self:err("want " .. v)
	end
end
function P:wantName(v)
	if not self:takeName(v) then
		self:err("want " .. v)
	end
end

-- skip balanced parens/braces/brackets from current position (starts on opener)
function P:skipBalanced()
	local depth = 0
	repeat
		local t = self:take()
		if t.t == "sym" and (t.v == "(" or t.v == "{" or t.v == "[") then
			depth += 1
		elseif t.t == "sym" and (t.v == ")" or t.v == "}" or t.v == "]") then
			depth -= 1
		end
	until depth <= 0 or t.t == "eof"
end

-- ============ EVALUATOR (env-aware) ============
local Eval = {}
Eval.__index = Eval

local GLOBALS = { TapTarget = VNum(48) }

-- layout discriminator locals get pinned per-run so if-expr branches correlate
local MODE_VARS = {
	stack = true, phone = true, compact = true, shortLandscape = true,
	multi = true, narrow = true, narrowPortrait = true, isMobile = true,
	touch = true, mobile = true, wide = true, landscape = true, packed = true,
	keyboardCompact = true, mobileHeaderCompact = true, railBelowCopy = true,
}
-- stack/mobile mode: stacked layouts, but keyboard/compact-header edge states off
local STACK_MODE = {}
for k in MODE_VARS do
	STACK_MODE[k] = k ~= "wide" and k ~= "landscape" and k ~= "keyboardCompact" and k ~= "mobileHeaderCompact"
end
-- chrome.<field> → MODE_VARS key it stands for (nil = leave opaque)
local CHROME_MODE_FIELDS = {
	stack = "stack", contentStack = "stack", landscape = "landscape",
	wide = "wide", compact = "compact", mobile = "mobile", phone = "phone",
	packed = "packed", narrow = "narrow", narrowPortrait = "narrowPortrait",
	keyboardOpen = "keyboardCompact", isMobile = "isMobile", touch = "touch",
	shortLandscape = "shortLandscape", mobileHeaderCompact = "mobileHeaderCompact",
}

function Eval.new(parser, mode)
	return setmetatable({ p = parser, mode = mode or {}, env = setmetatable({}, { __index = function(_, k)
		return GLOBALS[k]
	end }), findings = {}, elements = {} }, Eval)
end

function Eval:evalFile()
	while self.p:peek().t ~= "eof" do
		local before = self.p.i
		local ok, err = pcall(function()
			self:stat()
		end)
		if not ok then
			if self.firstErr == nil then
				local t = self.p.toks[self.p.i]
				self.firstErr = tostring(err) .. " @tok" .. self.p.i .. " near " .. tostring(t and t.v) .. " line~" .. lineOf(self.p.src, t and t.pos or 1)
			end
		end
		if self.p.i == before then
			self.p:take()
		end
	end
	return self.findings
end

function Eval:stat()
	local t = self.p:peek()
	if t.t == "sym" and t.v == ";" then
		self.p:take()
		return
	end
	if t.t == "name" then
		local kw = t.v
		if kw == "local" then
			self.p:take()
			if self.p:takeName("function") then
				local nt = self.p:take()
				if nt.t == "name" then
					self.env[nt.v] = { k = "fn" }
				end
				-- evaluate the body once for element coverage
				if self.p:sym("(") then
					self.p:skipBalanced()
				end
				self:block({ "end" })
				self.p:wantName("end")
				return
			end
			local names = {}
			while true do
				local nt = self.p:take()
				if nt.t ~= "name" then
					return
				end
				names[#names + 1] = nt.v
				if self.p:sym(":") then
					-- type annotation: skip until = or , or newline-ish boundary
					while true do
						local tt = self.p:peek()
						if tt.t == "eof" then
							return
						end
						if tt.t == "sym" and (tt.v == "=" or tt.v == ",") then
							break
						end
						if tt.t == "name" and (tt.v == "local" or tt.v == "return" or tt.v == "if" or tt.v == "for" or tt.v == "while" or tt.v == "do" or tt.v == "end" or tt.v == "function" or tt.v == "repeat") then
							break
						end
						self.p:take()
					end
				end
				if not self.p:takeSym(",") then
					break
				end
			end
			if self.p:takeSym("=") then
				for idx, nm in names do
					local v = self:expr()
					if MODE_VARS[nm] then
						v = { k = "bool", v = self.mode[nm] == true }
					end
					self.env[nm] = v
					if not self.p:takeSym(",") then
						break
					end
				end
				while self.p:takeSym(",") do
					self:expr()
				end
			end
			return
		elseif kw == "function" then
			self.p:take()
			-- function name.parts(...) / name:method(...)
			while self.p:peek().t == "name" or self.p:sym(".") or self.p:sym(":") do
				self.p:take()
			end
			if self.p:sym("(") then
				self.p:skipBalanced()
			end
			self:block({ "end" })
			self.p:wantName("end")
			return
		elseif kw == "return" then
			self.p:take()
			pcall(function()
				self:expr()
			end)
			while self.p:takeSym(",") do
				pcall(function()
					self:expr()
				end)
			end
			return
		elseif kw == "if" then
			self.p:take()
			pcall(function()
				self:expr()
			end)
			self.p:wantName("then")
			self:block({ "elseif", "else", "end" })
			while self.p:takeName("elseif") do
				pcall(function()
					self:expr()
				end)
				self.p:wantName("then")
				self:block({ "elseif", "else", "end" })
			end
			if self.p:takeName("else") then
				self:block({ "end" })
			end
			self.p:wantName("end")
			return
		elseif kw == "for" then
			self:forStat()
			return
		elseif kw == "while" then
			self.p:take()
			pcall(function()
				self:expr()
			end)
			self.p:wantName("do")
			self:block({ "end" })
			self.p:wantName("end")
			return
		elseif kw == "repeat" then
			self.p:take()
			self:block({ "until" })
			self.p:wantName("until")
			pcall(function()
				self:expr()
			end)
			return
		elseif kw == "do" then
			self.p:take()
			self:block({ "end" })
			self.p:wantName("end")
			return
		elseif kw == "end" or kw == "else" or kw == "elseif" or kw == "until" then
			return
		elseif kw == "break" or kw == "continue" then
			self.p:take()
			return
		end
	end
	self:exprStat()
end

function Eval:block(terminators)
	while true do
		local t = self.p:peek()
		if t.t == "eof" then
			return
		end
		if t.t == "name" then
			for _, term in terminators do
				if t.v == term then
					return
				end
			end
		end
		local before = self.p.i
		local ok, err = pcall(function()
			self:stat()
		end)
		if not ok then
			if self.firstErr == nil then
				local t = self.p.toks[self.p.i]
				self.firstErr = tostring(err) .. " @tok" .. self.p.i .. " near " .. tostring(t and t.v) .. " line~" .. lineOf(self.p.src, t and t.pos or 1)
			end
		end
		if not ok or self.p.i == before then
			self.p:take()
		end
	end
end

function Eval:skipFunc()
	-- expects params "(" ... ")" then body ... "end"
	if self.p:sym("(") then
		self.p:skipBalanced()
	end
	self.p:skipBlock()
end

function P:skipBlock()
	-- skip to matching "end" (for do/for/while/function/if bodies)
	local depth = 0
	while true do
		local t = self:take()
		if t.t == "eof" then
			return
		end
		if t.t == "name" then
			if t.v == "function" or t.v == "do" or t.v == "then" or t.v == "repeat" then
				depth += 1
			elseif t.v == "end" then
				if depth == 0 then
					return
				end
				depth -= 1
			elseif t.v == "until" then
				if depth == 0 then
					return
				end
				depth -= 1
			end
		end
	end
end

function Eval:forStat()
	-- for a,b in EXPR do ... end  |  for i=1,n do ... end
	local mark = self.p.i
	self.p:take() -- for
	local vars = {}
	local ok = pcall(function()
		while true do
			local nt = self.p:take()
			if nt.t ~= "name" then
				self.p:err("bad for var")
			end
			vars[#vars + 1] = nt.v
			if not self.p:takeSym(",") then
				break
			end
		end
	end)
	if not ok then
		self.p.i = mark + 1
		self.p:skipBlock()
		return
	end
	if self.p:takeName("in") then
		local srcExpr = self:expr()
		self.p:wantName("do")
		-- spread pattern: TGT[k] = v
		local save = self.p.i
		local spreadOk = pcall(function()
			local tn = self.p:take()
			if tn.t ~= "name" then
				self.p:err("no")
			end
			local tgt = tn.v
			self.p:wantSym("[")
			local kn = self.p:take()
			if kn.t ~= "name" or kn.v ~= vars[1] then
				self.p:err("no")
			end
			self.p:wantSym("]")
			self.p:wantSym("=")
			local vn = self.p:take()
			if vn.t ~= "name" or vn.v ~= vars[2] then
				self.p:err("no")
			end
			-- merge srcExpr table into tgt table
			local tgtVal = self.env[tgt]
			if tgtVal and tgtVal.k == "tbl" and srcExpr.k == "tbl" then
				for k, v in srcExpr.f do
					tgtVal.f[k] = v
				end
				for _, v in srcExpr.a do
					table.insert(tgtVal.a, v)
				end
			end
		end)
		if spreadOk then
			-- evaluate rest of loop body once for coverage
			self:block({ "end" })
		else
			self.p.i = save
			self:block({ "end" })
		end
		self.p:wantName("end")
	else
		-- numeric for
		while not (self.p:name("do") or self.p:peek().t == "eof") do
			self.p:take()
		end
		self.p:takeName("do")
		self:block({ "end" })
		self.p:wantName("end")
	end
end

function Eval:exprStat()
	-- assignment `a.b = e` / `a[i] = e` / `a.b.c = e` / `a += e` / call
	local save = self.p.i
	-- find if this is NAME (chain) = or += or -=
	local ok = pcall(function()
		local t = self.p:take()
		if t.t ~= "name" then
			self.p:err("not assign")
		end
		local root = t.v
		local path = {}
		while true do
			if self.p:takeSym(".") then
				local ft = self.p:take()
				if ft.t ~= "name" then
					self.p:err("bad field")
				end
				path[#path + 1] = { kind = "f", v = ft.v }
			elseif self.p:takeSym("[") then
				local idx = self:expr()
				self.p:wantSym("]")
				path[#path + 1] = { kind = "i", v = idx }
			else
				break
			end
		end
		if self.p:takeSym("=") then
			local v = self:expr()
			-- keep layout discriminators pinned across `if x == nil then x = default`
			-- reassignments compiled into the body
			if MODE_VARS[root] then
				v = { k = "bool", v = self.mode[root] == true }
			end
			-- apply
			if #path > 0 then
				local obj = self.env[root]
				for pi = 1, #path - 1 do
					local seg = path[pi]
					if obj and obj.k == "tbl" then
						if seg.kind == "f" then
							obj = obj.f[seg.v]
						else
							obj = VOpaque()
						end
					else
						obj = nil
					end
				end
				local last = path[#path]
				if obj and obj.k == "tbl" then
					if last.kind == "f" then
						obj.f[last.v] = v
					elseif isNum(last.v) and #last.v.s == 1 then
						obj.a[last.v.s[1]] = v
					end
				end
			else
				self.env[root] = v
			end
			return
		end
		if self.p:takeSym("+=") or self.p:takeSym("-=") then
			self:expr()
			return
		end
		self.p:err("no assign")
	end)
	if not ok then
		self.p.i = save
		pcall(function()
			self:expr()
		end)
		if self.p.i == save then
			self.p:take()
		end
	end
end

-- ============ EXPRESSIONS ============
local BINOPS = {
	["+"] = function(x, y) return x + y end,
	["-"] = function(x, y) return x - y end,
	["*"] = function(x, y) return x * y end,
	["/"] = function(x, y) return x / y end,
	["%"] = function(x, y) return x % y end,
}

function Eval:expr()
	return self:exprOr()
end
function Eval:exprOr()
	local v = self:exprAnd()
	while self.p:takeName("or") do
		local b = self:exprAnd()
		if v.k == "bool" then
			v = v.v and v or b
		elseif isNum(v) and isNum(b) then
			v = unionNum(v, b)
		else
			v = b
		end
	end
	return v
end
function Eval:exprAnd()
	local v = self:exprCmp()
	while self.p:takeName("and") do
		local b = self:exprCmp()
		if v.k == "bool" then
			v = v.v and b or v
		else
			v = b
		end
	end
	return v
end
function Eval:exprCmp()
	local v = self:exprConcat()
	while true do
		local t = self.p:peek()
		if t.t == "sym" and (t.v == "==" or t.v == "~=" or t.v == "<" or t.v == ">" or t.v == "<=" or t.v == ">=") then
			self.p:take()
			self:exprConcat()
			v = VOpaque()
		else
			return v
		end
	end
end
function Eval:exprConcat()
	local v = self:exprAdd()
	while self.p:takeSym("..") do
		self:exprAdd()
		v = VOpaque()
	end
	return v
end
function Eval:exprAdd()
	local v = self:exprMul()
	while true do
		local t = self.p:peek()
		if t.t == "sym" and (t.v == "+" or t.v == "-") then
			local op = BINOPS[t.v]
			self.p:take()
			v = numBin(v, self:exprMul(), op)
		else
			return v
		end
	end
end
function Eval:exprMul()
	local v = self:exprUnary()
	while true do
		local t = self.p:peek()
		if t.t == "sym" and BINOPS[t.v] and t.v ~= "+" and t.v ~= "-" then
			local op = BINOPS[t.v]
			self.p:take()
			v = numBin(v, self:exprUnary(), op)
		else
			return v
		end
	end
end
function Eval:exprUnary()
	local t = self.p:peek()
	if t.t == "sym" and t.v == "-" then
		self.p:take()
		local v = self:exprUnary()
		if isNum(v) then
			local s = {}
			for _, x in v.s do
				s[#s + 1] = -x
			end
			return { k = "num", s = s }
		end
		return VOpaque()
	end
	if t.t == "name" and t.v == "not" then
		self.p:take()
		local v = self:exprUnary()
		if v.k == "bool" then
			return { k = "bool", v = not v.v }
		end
		return VOpaque()
	end
	if t.t == "sym" and t.v == "#" then
		self.p:take()
		local v = self:exprUnary()
		if v.k == "tbl" then
			return VNum(#v.a)
		end
		return VOpaque()
	end
	return self:exprSuffix()
end

local KEYWORDS = {
	["if"] = true, ["then"] = true, ["else"] = true, ["elseif"] = true,
	["end"] = true, ["function"] = true, ["true"] = true, ["false"] = true,
	["nil"] = true, ["and"] = true, ["or"] = true, ["not"] = true,
	["for"] = true, ["while"] = true, ["do"] = true, ["repeat"] = true,
	["until"] = true, ["return"] = true, ["local"] = true, ["break"] = true,
	["continue"] = true, ["in"] = true,
}

-- suffix chain with callee-path tracking
function Eval:exprSuffix()
	local t = self.p:peek()
	local path = nil
	local v
	if t.t == "name" and not KEYWORDS[t.v] and t.v ~= "..." then
		self.p:take()
		path = t.v
		v = self.env[t.v]
		if v == nil or v.k == "opaque" then
			-- preserve the identifier for component-name resolution
			v = { k = "ref", name = t.v }
		end
	else
		v = self:primary()
	end
	while true do
		local nt = self.p:peek()
		if nt.t == "sym" and nt.v == "." then
			self.p:take()
			local ft = self.p:take()
			if ft.t ~= "name" then
				return VOpaque()
			end
			path = (path or "?") .. "." .. ft.v
			if v.k == "tbl" then
				v = v.f[ft.v] or VOpaque()
			elseif v.k == "ref" then
				-- chrome.<mode-field> reads get pinned like the locals so
				-- headerHeight/titleBlockH variants stay correlated
				if v.name == "chrome" then
					local mk = CHROME_MODE_FIELDS[ft.v]
					if mk ~= nil then
						v = { k = "bool", v = self.mode[mk] == true }
					else
						v = { k = "ref", name = ft.v }
					end
				else
					v = { k = "ref", name = ft.v }
				end
			else
				v = VOpaque()
			end
		elseif nt.t == "sym" and nt.v == "[" then
			self.p:take()
			local idx = self:expr()
			self.p:wantSym("]")
			path = nil
			if v.k == "tbl" and isNum(idx) and #idx.s == 1 then
				v = v.a[idx.s[1]] or VOpaque()
			elseif v.k == "tbl" and idx.k == "str" then
				v = v.f[idx.v] or VOpaque()
			else
				v = VOpaque()
			end
		elseif nt.t == "sym" and nt.v == ":" then
			self.p:take()
			local mt = self.p:take()
			if mt.t ~= "name" then
				return VOpaque()
			end
			path = (path or "?") .. ":" .. mt.v
			local callee = v
			local args = self:callArgs()
			v = self:dispatchCall(path, args, t.pos, callee)
			path = nil
		elseif nt.t == "sym" and (nt.v == "(" or nt.v == "{") then
			local callee = v
			local args = self:callArgs()
			v = self:dispatchCall(path, args, t.pos, callee)
			path = nil
		elseif nt.t == "str" then
			self.p:take()
			local callee = v
			v = self:dispatchCall(path, { { k = "str", v = nt.v } }, t.pos, callee)
			path = nil
		else
			return v
		end
	end
end

function Eval:callArgs()
	local t = self.p:peek()
	if t.t == "sym" and t.v == "{" then
		return { self:tableLit() }
	end
	if t.t == "str" then
		self.p:take()
		return { { k = "str", v = t.v } }
	end
	self.p:wantSym("(")
	local args = {}
	if not self.p:sym(")") then
		repeat
			args[#args + 1] = self:expr()
		until not self.p:takeSym(",")
	end
	self.p:wantSym(")")
	return args
end

function Eval:dispatchCall(path, args, pos, callee)
	if path == nil and (callee == nil or callee.k ~= "ref") then
		return VOpaque()
	end
	local pathS = path or ""
	local leaf = (path and pathS:match("[^.:%s]+$")) or (callee and callee.name) or ""
	if leaf == "createElement" or (callee ~= nil and callee.k == "ref" and callee.name == "createElement") then
		return self:makeElement(args, pos)
	end
	if pathS:match("UDim2%.fromOffset$") or leaf == "fromOffset" then
		return { k = "u2", xv = { { s = VNum(0), o = args[1] or VOpaque() } }, yv = { { s = VNum(0), o = args[2] or VOpaque() } } }
	end
	if leaf == "fromScale" then
		return { k = "u2", xv = { { s = args[1] or VOpaque(), o = VNum(0) } }, yv = { { s = args[2] or VOpaque(), o = VNum(0) } } }
	end
	if pathS:match("UDim2%.new$") or path == "UDim2.new" then
		if #args >= 4 then
			return { k = "u2", xv = { { s = args[1], o = args[2] } }, yv = { { s = args[3], o = args[4] } } }
		elseif #args == 2 then
			return { k = "u2", xv = { { s = args[1], o = VNum(0) } }, yv = { { s = args[2], o = VNum(0) } } }
		end
		return VOpaque()
	end
	if pathS:match("UDim%.new$") or path == "UDim.new" then
		return VOpaque()
	end
	if pathS:match("Vector2%.new$") then
		return { k = "v2", x = args[1] or VOpaque(), y = args[2] or VOpaque() }
	end
	if pathS:match("^math%.") then
		local fn = pathS:sub(6)
		if fn == "floor" then
			return numBin(args[1], VNum(1), math.floor)
		elseif fn == "ceil" then
			return numBin(args[1], VNum(1), math.ceil)
		elseif fn == "abs" then
			return numBin(args[1], VNum(1), math.abs)
		elseif fn == "max" or fn == "min" then
			local f = fn == "max" and math.max or math.min
			local acc = args[1]
			for i = 2, #args do
				acc = numBin(acc, args[i], f)
			end
			return acc
		elseif fn == "clamp" then
			return args[1] or VOpaque()
		end
		return VOpaque()
	end
	return VOpaque()
end

function Eval:makeElement(args, pos)
	local clsVal = args[1]
	local clsName = "?"
	if clsVal ~= nil then
		if clsVal.k == "str" then
			clsName = clsVal.v
		elseif clsVal.k == "ref" then
			clsName = clsVal.name
		end
	end
	local el = { k = "elem", cls = clsName, attrs = VTbl(), children = {}, line = lineOf(self.p.src, pos) }
	local a2 = args[2]
	if a2 ~= nil and a2.k == "tbl" then
		el.attrs = a2
	end
	for i = 3, #args do
		local c = args[i]
		if c ~= nil and c.k == "elem" then
			table.insert(el.children, c)
		elseif c ~= nil and c.k == "tbl" then
			-- child array
			for _, cc in c.a do
				if cc.k == "elem" then
					table.insert(el.children, cc)
				end
			end
		end
	end
	table.insert(self.elements, el)
	return el
end

function Eval:primary()
	local t = self.p:peek()
	if t.t == "num" then
		self.p:take()
		return VNum(t.v)
	end
	if t.t == "str" then
		self.p:take()
		return { k = "str", v = t.v }
	end
	if t.t == "name" then
		local kw = t.v
		if kw == "true" or kw == "false" or kw == "nil" then
			self.p:take()
			return VOpaque()
		elseif kw == "if" then
			return self:ifExpr()
		elseif kw == "function" then
			self.p:take()
			if self.p:sym("(") then
				self.p:skipBalanced()
			end
			self:block({ "end" })
			self.p:wantName("end")
			return VOpaque()
		elseif kw == "..." then
			self.p:take()
			return VOpaque()
		end
		self.p:err("bad primary name " .. kw)
	end
	if t.t == "sym" and t.v == "(" then
		self.p:take()
		local v = self:expr()
		self.p:wantSym(")")
		return v
	end
	if t.t == "sym" and t.v == "{" then
		return self:tableLit()
	end
	self.p:err("bad primary")
end

function Eval:ifExpr()
	self.p:wantName("if")
	-- collect branch values with a flag: keep=true means the branch can still
	-- be reached under the pinned mode vars (opaque or true condition)
	local c = self:expr()
	self.p:wantName("then")
	local vals = { self:expr() }
	local keeps = { c.k ~= "bool" or c.v }
	local decidable = c.k == "bool"
	local chosenIdx = (c.k == "bool" and c.v) and 1 or nil
	while self.p:takeName("elseif") do
		local c2 = self:expr()
		self.p:wantName("then")
		local v = self:expr()
		vals[#vals + 1] = v
		local keep = c2.k ~= "bool" or c2.v
		keeps[#keeps + 1] = keep
		if c2.k ~= "bool" then
			decidable = false
		elseif chosenIdx == nil and c2.v then
			chosenIdx = #vals
		end
	end
	self.p:wantName("else")
	vals[#vals + 1] = self:expr()
	keeps[#keeps + 1] = true
	-- fully decidable chain: return the first true branch (or else)
	if decidable then
		return vals[chosenIdx or #vals]
	end
	-- if an earlier branch was definitely taken, later branches are unreachable
	if chosenIdx ~= nil then
		for i = chosenIdx + 1, #keeps do
			keeps[i] = false
		end
	end
	local acc = nil
	for i, v in vals do
		if keeps[i] then
			if acc == nil then
				acc = v
			elseif isNum(acc) and isNum(v) then
				acc = unionNum(acc, v)
			elseif acc.k == "u2" and v.k == "u2" then
				-- union whole (scale,offset) pairs per axis — never cross-product fields
				local xv, yv = {}, {}
				for _, p in acc.xv do xv[#xv + 1] = p end
				for _, p in v.xv do xv[#xv + 1] = p end
				for _, p in acc.yv do yv[#yv + 1] = p end
				for _, p in v.yv do yv[#yv + 1] = p end
				if #xv > 8 or #yv > 8 then
					acc = VOpaque()
				else
					acc = { k = "u2", xv = xv, yv = yv }
				end
			elseif acc.k == "elem" or v.k == "elem" then
				acc = acc.k == "elem" and acc or v
			elseif acc.k == "opaque" then
				acc = v
			end
		end
	end
	return acc or VOpaque()
end

function Eval:tableLit()
	self.p:wantSym("{")
	local tbl = VTbl()
	while not self.p:sym("}") do
		local t = self.p:peek()
		if t.t == "eof" then
			break
		end
		if t.t == "name" and self.p:peekAt(1).t == "sym" and self.p:peekAt(1).v == "=" then
			local key = t.v
			self.p:take()
			self.p:take()
			tbl.f[key] = self:expr()
		elseif t.t == "sym" and t.v == "[" then
			self.p:take()
			self:expr()
			self.p:wantSym("]")
			self.p:wantSym("=")
			table.insert(tbl.a, self:expr())
		else
			table.insert(tbl.a, self:expr())
		end
		if not (self.p:takeSym(",") or self.p:takeSym(";")) then
			break
		end
	end
	self.p:wantSym("}")
	return tbl
end

-- ============ GEOMETRY ============
local function numSet(v)
	if isNum(v) then
		return v.s
	end
	return nil
end
local function attrOf(el, ...)
	if el.k ~= "tbl" and el.k ~= "elem" then
		return nil
	end
	local f = el.attrs.f
	for _, n in { ... } do
		local v = f[n]
		if v ~= nil then
			return v
		end
	end
	return nil
end
local function udim2Of(v)
	if v ~= nil and v.k == "u2" then
		return v
	end
	return nil
end

local function rectVariants(el, innerW, innerH)
	-- returns list of {top,bottom,left,right} in parent-inner coords, or nil
	local pos = udim2Of(attrOf(el, "Position", "position")) or { xv = { { s = VNum(0), o = VNum(0) } }, yv = { { s = VNum(0), o = VNum(0) } } }
	local size = udim2Of(attrOf(el, "Size", "size", "sizeConstraint"))
	if size == nil then
		return nil
	end
	local anchor = attrOf(el, "AnchorPoint")
	local axs, ays = { 0 }, { 0 }
	if anchor ~= nil and anchor.k == "v2" then
		axs = numSet(anchor.x) or { 0 }
		ays = numSet(anchor.y) or { 0 }
	end
	-- each axis is a list of whole {s=scale, o=offset} pairs; a pair is usable
	-- only when both halves resolved to numbers
	local function pairsOf(list)
		local out = {}
		for _, p in list do
			local ss = numSet(p.s)
			local oo = numSet(p.o)
			if ss and oo then
				for _, a in ss do
					for _, b in oo do
						out[#out + 1] = { a, b }
					end
				end
			end
		end
		if #out == 0 then
			return nil
		end
		return out
	end
	local pxp = pairsOf(pos.xv)
	local pyp = pairsOf(pos.yv)
	local sxp = pairsOf(size.xv)
	local syp = pairsOf(size.yv)
	if pxp == nil or pyp == nil or syp == nil then
		return nil
	end
	sxp = sxp or { { 0, 0 } }
	local rects = {}
	for _, pp in pxp do
		for _, qp in pyp do
			local left0 = pp[1] * innerW + pp[2]
			local top0 = qp[1] * innerH + qp[2]
			for _, sp in sxp do
				local w = sp[1] * innerW + sp[2]
				for _, tp in syp do
					local h = tp[1] * innerH + tp[2]
					for _, ax in axs do
						for _, ay in ays do
							local left = left0 - ax * w
							local top = top0 - ay * h
							rects[#rects + 1] = { l = left, t = top, r = left + w, b = top + h }
						end
					end
				end
			end
		end
	end
	return rects
end

local function padOf(el)
	local p = attrOf(el, "padding")
	if isNum(p) then
		local m = 0
		for _, v in p.s do
			m = math.max(m, v)
		end
		return m
	end
	return 0
end

local INTERACTIVE = { textbox = true, textbutton = true, imagebutton = true, Button = true, Dropdown = true, SearchField = true }

local function checkChildren(parent, innerW, innerH, file, out, path)
	-- parent inner box known; examine children
	local layoutDriven = false
	local scrolling = parent.cls == "scrollingframe"
	for _, c in parent.children do
		if c.cls == "uilistlayout" or c.cls == "uigridlayout" or c.cls == "uitableview" then
			layoutDriven = true
		end
	end
	local parentAuto = attrOf(parent, "AutomaticSize", "automaticSize")
	if parentAuto ~= nil and not (parentAuto.k == "str" and parentAuto.v == "None") then
		-- grows to fit; skip overflow checks
	end
	if layoutDriven then
		return
	end
	local childRects = {}
	for i, c in parent.children do
		local rects = rectVariants(c, innerW, innerH)
		childRects[i] = rects
		if not scrolling and rects then
			for _, r in rects do
				-- a child bigger than its parent on BOTH axes is a deliberate
				-- halo/glow layer (e.g. a 2x scale ring centered on a dot), not a spill
				local halo = (r.b - r.t) > innerH and (r.r - r.l) > innerW
				-- child anchored near top overflowing bottom
				if not halo and r.b > innerH + 3 and r.t < innerH - 3 then
					table.insert(out, string.format("%s:%d [SPILL] %s bottom %.0f past inner %.0f (parent %s L%d)", file, c.line, c.cls, r.b, innerH, parent.cls, parent.line))
				end
				if not halo and innerW < 7000 and r.r > innerW + 3 and r.l < innerW - 3 then
					table.insert(out, string.format("%s:%d [XSPILL] %s right %.0f past inner %.0f", file, c.line, c.cls, r.r, innerW))
				end
			end
		end
	end
	-- pairwise: bottom-anchored vs top-anchored overlap
	for i, c in parent.children do
		local ra = childRects[i]
		if not ra then
			continue
		end
		for j, d in parent.children do
			if j <= i then
				continue
			end
			local rb = childRects[j]
			if not rb then
				continue
			end
			for _, A in ra do
				for _, B in rb do
					local ox = math.min(A.r, B.r) - math.max(A.l, B.l)
					local oy = math.min(A.b, B.b) - math.max(A.t, B.t)
					if ox > 6 and oy > 6 then
						local aAnchor = (A.t > innerH * 0.5)
						local bAnchor = (B.t > innerH * 0.5)
						if aAnchor ~= bAnchor then
							local covered, cover = A, B
							local ce, cr = c, d
							if aAnchor then
								covered, cover = B, A
								ce, cr = d, c
							end
							if INTERACTIVE[covered.cls] or INTERACTIVE[c.cls] or INTERACTIVE[d.cls] then
								table.insert(out, string.format("%s:%d [COVER] %s(L%d) covers %s â€” overlap %dx%d", file, cr.line, cr.cls, cr.line, ce.cls, ox, oy))
							end
						end
					end
				end
			end
		end
	end
end


-- Inner-dimension variants standalone (parent-independent): only when height
-- is pure pixel offset (ys==0, yo numeric). Scale width uses a sentinel.
local function innerDimVariants(el)
	local sz = udim2Of(attrOf(el, "Size", "size"))
	if sz == nil then
		return nil
	end
	-- collect pure-pixel heights (scale==0, numeric offset)
	local pad = padOf(el)
	local iws = {}
	local sawScaleW = false
	for _, p in sz.xv do
		local ss, oo = numSet(p.s), numSet(p.o)
		if ss and oo then
			for _, a in ss do
				for _, b in oo do
					if a == 0 then
						iws[#iws + 1] = b - 2 * pad
					else
						sawScaleW = true
					end
				end
			end
		else
			sawScaleW = true
		end
	end
	if #iws == 0 or sawScaleW then
		iws = { 9999 } -- sentinel: unknown/scale width, suppresses X checks
	end
	local out = {}
	for _, p in sz.yv do
		local ss, oo = numSet(p.s), numSet(p.o)
		if ss and oo then
			for _, a in ss do
				for _, b in oo do
					if a == 0 and b > 0 then
						local ih = b - 2 * pad
						for _, iw in iws do
							out[#out + 1] = { iw = iw, ih = ih }
						end
					end
				end
			end
		end
	end
	if #out == 0 then
		return nil
	end
	return out
end

local function walkInner(el, iw, ih, file, out, depth, visited)
	if depth > 40 or visited[el] then
		return
	end
	visited[el] = true
	checkChildren(el, iw, ih, file, out)
	for _, c in el.children do
		local rects = rectVariants(c, iw, ih)
		if rects then
			for _, r in rects do
				local pad = padOf(c)
				local cw, ch = r.r - r.l - 2 * pad, r.b - r.t - 2 * pad
				if cw > 0 and ch > 0 then
					walkInner(c, cw, ch, file, out, depth + 1, visited)
				end
			end
		end
	end
end

-- ============ DRIVER ============
local dirs = { "src/Client/AstralForge/pages", "src/Client/AstralForge" }
local seen = {}
local allFindings = {}
local fileCount = 0
for _, dir in dirs do
	for _, f in fs.readDir(dir) do
		if f:match("%.luau$") and not seen[f] then
			seen[f] = true
			fileCount += 1
			local path = dir .. "/" .. f
			local src = fs.readFile(path)
			for modeIdx, modeOn in { false, true } do
				local parser = P.new(src)
				local ev = Eval.new(parser, modeOn and STACK_MODE or {})
				local ok, err = pcall(function()
					ev:evalFile()
				end)
				if not ok then
					print("PARSE-WARN " .. f .. " " .. tostring(err))
				end
				print("DBG " .. f .. " mode=" .. tostring(modeOn) .. " elems=" .. #ev.elements .. " err=" .. tostring(ev.firstErr))
				local ftag = f .. (modeOn and " [stack]" or " [desk]")
				local visited = {}
				for _, el in ev.elements do
					local dims = innerDimVariants(el)
					if dims then
						for _, d in dims do
							walkInner(el, d.iw, d.ih, ftag, allFindings, 1, visited)
						end
					end
				end
			end
		end
	end
end
-- Verified false positives the evaluator cannot prove safe:
--  AdminView:776 — the RUN button's offset (EXEC_TITLE + fieldSlots*FIELD_H) and the field
--    container's extent (EXEC_TITLE + fieldSlots*FIELD_H - 6) share the same fieldSlots
--    variable, so the gap is always exactly 6px; the checker evaluates the variable
--    independently per sibling and cross-pairs the extremes.
local SUPPRESSED = {
	{ file = "AdminView.luau", site = ":776 [COVER]" },
}
local seenF = {}
local outLines = {}
for _, line in allFindings do
	local suppressed = false
	for _, s in SUPPRESSED do
		if line:find(s.file, 1, true) and line:find(s.site, 1, true) then
			suppressed = true
		end
	end
	if suppressed then
		continue
	end
	if not seenF[line] then
		seenF[line] = true
		outLines[#outLines + 1] = line
	end
end
table.sort(outLines)
print(fileCount .. " files scanned, " .. #outLines .. " findings")
for _, l in outLines do
	print(l)
end


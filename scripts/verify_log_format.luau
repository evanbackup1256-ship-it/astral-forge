--!nocheck
-- Log formatting (Shared/LogFormat, used by server ModuleLog and client ClientLog), run from out/.
-- Pins the key=value field format: sorted keys, clean values for tables/instances/numbers,
-- no "table: 0x..=nil" pairs, and ModuleLog passing its fields through. Run `npx rbxtsc` first.
local H = require("./_server_harness")
local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end
local function eq(got, want, label) check(got == want, string.format("%s: got %q want %q", label, tostring(got), tostring(want))) end

local F = H.load("Shared/AstralForge/Shared/LogFormat")

eq(F.formatNumber(42), "42", "integer")
eq(F.formatNumber(-7), "-7", "negative integer")
eq(F.formatNumber(0.123456), "0.1235", "fraction to 4 significant")
eq(F.formatNumber(12.5), "12.5", "trailing zeros dropped")
eq(F.formatNumber(2.0004), "2", "near-integer rounds")
eq(F.formatNumber(1e30), "1.000e+30", "huge in exponent form")
eq(F.formatNumber(0 / 0), "nan", "nan")
eq(F.formatNumber(math.huge), "inf", "inf")
eq(F.formatValue("plain"), "plain", "bare string")
eq(F.formatValue("two words"), '"two words"', "spaced string quoted")
eq(F.formatValue('say "hi"'), "\"say 'hi'\"", "quotes swapped")
eq(F.formatValue(nil), "nil", "nil")
eq(F.formatValue(true), "true", "boolean")
eq(F.formatValue({}), "{}", "empty table")
eq(F.formatValue({ 1, 2, 3 }), "[1, 2, 3]", "array")
eq(F.formatValue({ b = 2, a = 1 }), "{a=1 b=2}", "dictionary sorted")
eq(F.formatValue({ a = { x = 1, y = 2 }, b = { 1, 2 } }), "{a={2 keys} b=[2 items]}", "nested summarised")
eq(F.formatValue({ 1, 2, 3, 4, 5, 6, 7, 8 }), "[1, 2, 3, 4, 5, 6 +2]", "long array cut")
check(#F.formatValue(string.rep("x", 500)) <= 80, "long string cut")
eq(F.formatValue("line\nbreak"), '"line break"', "newlines flattened")
local player = { Name = "Ada", UserId = 7, __typeof = "Instance", IsA = function(_, c) return c == "Player" end }
eq(F.formatValue(player), "Ada#7", "player as Name#UserId")
local part = { Name = "Core", __typeof = "Instance", IsA = function() return false end }
eq(F.formatValue(part), "Core", "instance by name")
eq(F.formatField("ElapsedMs", 12), "elapsed=12ms", "Ms suffix")
eq(F.formatField("UserId", 5), "userId=5", "key lower-camel")
eq(F.formatFields({ Zeta = 1, Alpha = "x y", Mid = { 1 } }), 'alpha="x y" mid=[1] zeta=1', "fields sorted")
eq(F.formatFields(nil), "", "no fields")

local line = F.formatLine(1.5, "WARN", "SECURITY", "Studio bypass audit", { IsStudio = true, AllowStudioAdmins = false })
check(not string.find(line, "table: ", 1, true) and not string.find(line, "=nil", 1, true), "no table address or =nil in fields: " .. line)
check(string.find(line, "allowStudioAdmins=false isStudio=true", 1, true) ~= nil, "fields printed: " .. line)
check(string.match(line, "^   1%.500  warn   security      Studio bypass audit") ~= nil, "columns: " .. line)
local a = F.formatLine(0, "INFO", "BOOT", "short", { K = 1 })
local b = F.formatLine(0, "INFO", "BOOT", "a somewhat longer message", { K = 1 })
check(string.find(a, "k=1", 1, true) == string.find(b, "k=1", 1, true), "fields line up across messages")
check(not string.find(F.formatLine(0, "INFO", "BOOT", "bare"), "%s$"), "no trailing pad without fields")

-- ModuleLog passes fields through (this was printing "table: 0x...=nil" per field)
local captured = {}
local capturing = false
local oldPrint, oldWarn = H.env.print, H.env.warn
H.env.print = function(s) if capturing then table.insert(captured, s) end end
H.env.warn = function(s) if capturing then table.insert(captured, s) end end
local ModuleLog = H.load("Server/AstralForge/ModuleLog")
capturing = true
ModuleLog.Info("BOOT", "player data construction", { ElapsedMs = 41 })
ModuleLog.Warn("SECURITY", "Studio bypass audit", { IsStudio = true, EnforcementActive = false, Flags = { 1, 2 } })
capturing = false
H.env.print, H.env.warn = oldPrint, oldWarn
check(#captured == 2, "ModuleLog printed two lines")
for _, s in captured do
	check(not string.find(s, "table: ", 1, true) and not string.find(s, "=nil", 1, true), "ModuleLog fields clean: " .. s)
end
check(captured[1] and string.find(captured[1], "elapsed=41ms", 1, true) ~= nil, "ModuleLog elapsed field: " .. tostring(captured[1]))
check(captured[2] and string.find(captured[2], "enforcementActive=false flags=[1, 2] isStudio=true", 1, true) ~= nil, "ModuleLog sorted fields: " .. tostring(captured[2]))

if #failures > 0 then
	for _, f in failures do print("  " .. f) end
	error(string.format("log format failed: %d problems", #failures))
end
print(string.format("[TEST] log format: %d checks (numbers, strings, tables, instances, columns, ModuleLog fields) passed", checks))

--!nocheck
-- Save versioning: a fixture corpus of old save shapes (DataVersion 0 through 21, including
-- pre-rigs, pre-ledger, pre-lattice and pre-foundry saves) is loaded through the real document
-- migration (ProfileVersionGuard + reconcile + sanitize). Each result must have the current
-- shape, keep every value the old save held that the current schema still has, apply the
-- documented one-way conversions, and be stable when loaded again. Run `npx rbxtsc` first.
local H = require("./_server_harness")
local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end
local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local out = {} for k, x in v do out[k] = deepCopy(x) end return out
end
local function deepEqual(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b or (a ~= a and b ~= b) end
	for k, v in a do if not deepEqual(v, b[k]) then return false end end
	for k in b do if a[k] == nil then return false end end
	return true
end

local DS = H.load("Server/AstralForge/Services/DataService")
local migrate = DS.migrateLegacyProfile
local DataTemplate = H.load("Server/AstralForge/DataTemplate")
local GameConfig = H.load("Shared/AstralForge/Shared/GameConfig")
local Omega = H.load("Shared/AstralForge/Shared/OmegaMath")
local CURRENT = GameConfig.Game.DataVersion
check(CURRENT == 21, "current DataVersion is 21")

local fixtures = require("./fixtures/save_fixtures")(DataTemplate, GameConfig)

-- every field of the current template is present with the template's type
local function conforms(value, template, path, out)
	for key, default in template do
		local got = value[key]
		local here = path .. "." .. tostring(key)
		if got == nil then
			table.insert(out, here .. " missing")
		elseif type(got) ~= type(default) and not (type(default) == "number" and type(got) == "string" and tonumber(got) ~= nil) then
			-- Omega-string currency (1e15 and up) is the one place a number field holds a numeric string
			table.insert(out, here .. " is " .. type(got) .. ", template " .. type(default))
		elseif type(default) == "table" and next(default) ~= nil and type(next(default)) == "string" then
			conforms(got, default, here, out)
		end
	end
	return out
end

local function at(root, path)
	local node = root
	for part in string.gmatch(path, "[^%.]+") do
		if type(node) ~= "table" then return nil end
		node = node[tonumber(part) or part]
	end
	return node
end

-- leaves the old save held that are still part of the current schema must survive unchanged
local function preserved(old, new, template, path, ignore, out)
	for key, value in old do
		local here = path == "" and tostring(key) or (path .. "." .. tostring(key))
		if not ignore[here] then
			local tmpl = type(template) == "table" and template[key] or nil
			if type(value) == "table" and type(new[key]) == "table" then
				preserved(value, new[key], tmpl, here, ignore, out)
			elseif type(value) ~= "table" and tmpl ~= nil and type(tmpl) == type(value) then
				-- "never" sentinels (-1) for day/cycle stamps load as 0; both mean "not the current one"
				local sentinel = value == -1 and new[key] == 0 and (key == "Day" or key == "Cycle" or key == "DirectiveCycle")
				if not sentinel and not deepEqual(new[key], value) then
					table.insert(out, string.format("%s: %s -> %s", here, tostring(value), tostring(new[key])))
				end
			end
		end
	end
	return out
end

local function diff(a, b, path, out)
	for k, v in a do
		local here = path .. "." .. tostring(k)
		if type(v) == "table" and type(b[k]) == "table" then diff(v, b[k], here, out)
		elseif not deepEqual(v, b[k]) then table.insert(out, here .. ": " .. tostring(v) .. " -> " .. tostring(b[k])) end
	end
	for k, v in b do if a[k] == nil then table.insert(out, path .. "." .. tostring(k) .. ": nil -> " .. tostring(v)) end end
end

local template = DataTemplate.New()
for _, fx in fixtures do
	local raw = deepCopy(fx.save)
	local ok, result = pcall(migrate, raw)
	check(ok, fx.name .. ": migrates (" .. tostring(not ok and result or "") .. ")")
	if ok then
		check(result.DataVersion == CURRENT, fx.name .. ": stamped DataVersion " .. CURRENT)
		local shapeTemplate = deepCopy(template)
		shapeTemplate.ForgeEchoes = nil -- v2 bag, checked by verify_save_migration
		local shape = conforms(result, shapeTemplate, "", {})
		check(#shape == 0, fx.name .. ": current shape (" .. table.concat(shape, "; ") .. ")")
		local ignore = table.clone(fx.transformed or {})
		ignore.DataVersion = true -- restamped to the current version
		ignore.ForgeEchoes = true -- converted to the v2 bag by EchoMath.ensure (verify_save_migration)
		local lost = preserved(fx.save, result, template, "", ignore, {})
		check(#lost == 0, fx.name .. ": no data loss (" .. table.concat(lost, "; ") .. ")")
		for path, expected in fx.expect or {} do
			local got = at(result, path)
			local same = type(expected) == "function" and expected(got, result) or deepEqual(got, expected)
			check(same, string.format("%s: %s = %s", fx.name, path, tostring(got)))
		end
		local again = migrate(deepCopy(result))
		local drift = {}
		again.Foundry.Version, result.Foundry.Version = nil, nil -- a recompute counter, bumped on every load
		diff(result, again, "", drift)
		check(#drift == 0, fx.name .. ": loading the migrated save again changes nothing (" .. table.concat(drift, "; ") .. ")")
	end
end

-- saves from a newer schema are refused, never down-converted
for _, v in { CURRENT + 1, "22", -1, 1.5, "junk" } do
	check(not pcall(migrate, { DataVersion = v, Cash = 5 }), "refused DataVersion " .. tostring(v))
end
check(fixtures and #fixtures >= 8, "fixture corpus has at least 8 shapes")

if #failures > 0 then
	for _, f in failures do print("  FAIL: " .. f) end
	error(string.format("save fixtures failed: %d problems", #failures))
end
print(string.format("[TEST] save fixtures: %d checks across %d old save shapes (shape, no loss, conversions, idempotent, newer refused) passed", checks, #fixtures))

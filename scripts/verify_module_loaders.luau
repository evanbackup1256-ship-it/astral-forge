local fs = require("@lune/fs")
local luau = require("@lune/luau")
local count = 0
local function walk(path)
	for _, name in fs.readDir(path) do
		local file = path .. "/" .. name
		if fs.isDir(file) then
			if name ~= "Vendor" then
				walk(file)
			end
		elseif name:match("%.luau$") then
			local source = fs.readFile(file):gsub("\r\n", "\n")
			local boundary = source:find('\n__defs["', 1, true)
			if boundary then
				local make = luau.load(source:sub(1, boundary - 1) .. "\nreturn __defs, __load")
				local defs, load = make()
				local calls = 0
				defs.False = function()
					calls += 1
					return false
				end
				assert(load("False") == false and load("False") == false and calls == 1, file .. ": cache false")
				defs.Nil = function()
					calls += 1
					return nil
				end
				assert(load("Nil") == nil and load("Nil") == nil and calls == 2, file .. ": cache nil")
				defs.Cycle = function()
					return load("Cycle")
				end
				local ok, reason = pcall(load, "Cycle")
				assert(not ok and tostring(reason):find("cyclic", 1, true), file .. ": cycle detection")
				defs.Cycle = function()
					return "recovered"
				end
				assert(load("Cycle") == "recovered", file .. ": clear failed loading state")
				assert(not pcall(load, "Unknown"), file .. ": reject unknown members")
				count += 1
			end
		end
	end
end
walk("src/Client/AstralForge")
walk("src/Server/AstralForge")
walk("src/Shared/AstralForge")
assert(count > 10, "suite loader coverage")
print(`[TEST] {count} suite loaders cache nil/false, reject cycles and recover after failures`)

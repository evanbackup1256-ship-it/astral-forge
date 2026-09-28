-- Compile every Luau file under src/ and build/ at O0, O1 and O2 (Studio uses
-- O0 with the debugger attached, where the 200-local limit bites hardest).
--   lune run scripts/compile_all.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
-- Compile at every optimization level Roblox may use. Studio compiles at O0
-- when the debugger is on, where every local counts toward the 200 limit.
local bad, n = 0, 0
local function walk(dir)
	for _, name in fs.readDir(dir) do
		local p = dir .. "/" .. name
		if fs.isDir(p) then walk(p)
		elseif p:match("%.luau?$") then
			n += 1
			local source = fs.readFile(p)
			for _, level in { 0, 1, 2 } do
				local ok, err = pcall(luau.compile, source, { optimizationLevel = level, debugLevel = 1 })
				if not ok then
					bad += 1
					print(("COMPILE FAIL O%d %s: %s"):format(level, p, (string.gsub(tostring(err), "\n.*", ""))))
					break
				end
			end
		end
	end
end
walk("src"); walk("build")
print(("checked %d files at O0/O1/O2, %d failures"):format(n, bad))
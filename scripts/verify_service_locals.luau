-- Luau allows 200 locals per function scope; a module's top level counts as one. Keep the big
-- services well under it so new bindings go into domain modules (rewrite 01).
local fs = require("@lune/fs")
local LIMIT = 170
local files = {
	"out/Server/AstralForge/Services/GameService.luau",
	"out/Server/AstralForge/Services/DataService.luau",
	"out/Server/AstralForge/Services/AdminService.luau",
}
for _, path in files do
	local count = 0
	for line in string.gmatch(fs.readFile(path), "[^\n]*") do
		if string.sub(line, 1, 6) == "local " then
			local names = string.match(line, "^local%s+function%s+([%w_]+)") or string.match(line, "^local%s+([%w_,%s]+)") or ""
			for _ in string.gmatch(names, "[%w_]+") do count += 1 end
		end
	end
	assert(count <= LIMIT, `{path}: {count} top-level locals (limit {LIMIT}); move bindings into a domain module`)
	print(`service locals: {path} {count}`)
end

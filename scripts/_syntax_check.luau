local fs = require("@lune/fs")
local luau = require("@lune/luau")
local files = {
	"src/Client/AstralForge/pages/AdminView.luau",
	"src/Client/AstralForge/pages/GuildView.luau",
	"src/Client/AstralForge/pages/PageRouter.luau",
	"src/Client/AstralForge/pages/ForgePathView.luau",
	"src/Client/AstralForge/pages/EchoForgeView.luau",
	"src/Client/AstralForge/layoutGuard.luau",
}
local bad = 0
for _, f in files do
	local ok, err = pcall(function()
		return luau.load(fs.readFile(f))
	end)
	if not ok then
		bad += 1
	end
	print((ok and "OK " or "FAIL ") .. f .. (ok and "" or (" " .. tostring(err))))
end
if bad > 0 then
	error(bad .. " file(s) failed to parse")
end

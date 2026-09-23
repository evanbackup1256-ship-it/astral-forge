local fs = require("@lune/fs")
local luau = require("@lune/luau")

-- Boot-parse gate for critical client entrypoints and server modules that
-- historically escaped CI (ui.luau / MainGame.luau parse failures blank the
-- client). Keep this list to files that load as pure chunks under Lune —
-- Studio-only test *runners* stay out; test modules are parse-checked only.
local files = {
	-- Client boot / shell
	"src/Client/AstralForge/init.client.luau",
	"src/Client/AstralForge/BootScreen.luau",
	"src/Client/AstralForge/MainGame.luau",
	"src/Client/AstralForge/ui.luau",
	"src/Client/AstralForge/framework.luau",
	"src/Client/AstralForge/clientStore.luau",
	"src/Client/AstralForge/layoutGuard.luau",
	-- Hot pages
	"src/Client/AstralForge/pages/PageRouter.luau",
	"src/Client/AstralForge/pages/AdminView.luau",
	"src/Client/AstralForge/pages/GuildView.luau",
	"src/Client/AstralForge/pages/ForgePathView.luau",
	"src/Client/AstralForge/pages/EchoForgeView.luau",
	"src/Client/AstralForge/pages/LabView.luau",
	"src/Client/AstralForge/pages/AnomalyView.luau",
	"src/Client/AstralForge/pages/ShopView.luau",
	"src/Client/AstralForge/pages/InventoryView.luau",
	"src/Client/AstralForge/pages/TradeView.luau",
	-- Shared catalog (parse only — no require)
	"src/Shared/AstralForge/Shared/GameConfig.luau",
	-- Server trade desk (offer validation / exchange)
	"src/Server/AstralForge/Modules/TradeDesk.luau",
	"src/Server/AstralForge/Modules/TradeExchange.luau",
	-- Client unit test modules: parse-only (runners need Studio + lunit)
	"src/Client/AstralForge/tests/format.test.luau",
	"src/Client/AstralForge/tests/taskFilter.test.luau",
	"src/Client/AstralForge/tests/virtualizedList.test.luau",
	"src/Client/AstralForge/tests/TestBootstrap.luau",
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

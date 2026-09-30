local fs = require("@lune/fs")
local luau = require("@lune/luau")

-- Boot-parse gate for critical client entrypoints and server modules that
-- historically escaped CI (ui.luau / MainGame.luau parse failures blank the
-- client). Keep this list to files that load as pure chunks under Lune —
-- Studio-only test *runners* stay out; test modules are parse-checked only.
local files = {
	-- Client boot / shell
	"src/Client/AstralForge/init.client.luau",
	"src/Client/AstralForge/ReactHosts.luau",
	"src/Client/AstralForge/CoreKit.luau",
	"src/Client/AstralForge/BootKit.luau",
	"src/Client/AstralForge/UiCore.luau",
	"src/Client/AstralForge/SanctuaryKit.luau",
	"src/Client/AstralForge/AudioKit.luau",
	"src/Client/AstralForge/LayoutKit.luau",
	"src/Shared/AstralForge/Shared/SharedData.luau",
	"src/Client/AstralForge/MotionKit.luau",
	"src/Client/AstralForge/play/floorFx.luau",
	"src/Client/AstralForge/framework.luau",
	"src/Client/AstralForge/layoutGuard.luau",
	-- Hot pages (keep in sync with scripts/verify_playability.luau HOT_PAGES)
	"src/Client/AstralForge/pages/PageRouter.luau",
	"src/Client/AstralForge/pages/PagesCore.luau",
	"src/Client/AstralForge/pages/PagesProgress.luau",
	"src/Client/AstralForge/pages/PagesSystem.luau",
	"src/Client/AstralForge/pages/PagesSocial.luau",
	"src/Client/AstralForge/pages/PagesStory.luau",
	"src/Client/AstralForge/pages/PagesShop.luau",
	"src/Client/AstralForge/UiOverlays.luau",
	"src/Client/AstralForge/input/InputKit.luau",
	-- Shared catalog (parse only — no require)
	"src/Shared/AstralForge/Shared/GameConfig.luau",
	-- Server trade desk (offer validation / exchange)
	"src/Server/AstralForge/Modules/TradeSuite.luau",
	"src/Server/AstralForge/Modules/EconomyMath.luau",
	"src/Server/AstralForge/Modules/LabOrderMath.luau",
	"src/Server/AstralForge/Modules/OpsMath.luau",
	"src/Server/AstralForge/Modules/ForgeEchoMath.luau",
	"src/Server/AstralForge/Modules/CommandMath.luau",
	"src/Server/AstralForge/Modules/ProfileBagMath.luau",
	"src/Server/AstralForge/Modules/ProfileMath.luau",
	"src/Server/AstralForge/Modules/DataSanitizeMath.luau",
	"src/Server/AstralForge/Services/AnomalyService.luau",
	"src/Server/AstralForge/Services/GuildService.luau",
	"src/Server/AstralForge/Services/ForgeEchoService.luau",
	"src/Server/AstralForge/Modules/OreMath.luau",
	"src/Server/AstralForge/Services/WorldServices.luau",
	-- Client unit test modules: parse-only (runners need Studio + lunit)
	"src/Client/AstralForge/tests/format.test.luau",
	"src/Client/AstralForge/tests/taskFilter.test.luau",
	"src/Client/AstralForge/tests/virtualizedList.test.luau",
	"src/Client/AstralForge/tests/TestBootstrap.luau",
}

local bad = 0
for _, f in files do
	local ok, err = pcall(function()
		local source = fs.readFile(f)
		-- Studio compiles at O0 when the debugger is attached, where every local
		-- counts toward Luau's 200-local limit; the default O1 folds some away.
		-- An O0-only overflow shows up as a blank client in Studio ("Out of local
		-- registers"), so compile at O0 explicitly as well.
		luau.compile(source, { optimizationLevel = 0, debugLevel = 1 })
		return luau.load(source)
	end)
	if not ok then
		bad += 1
	end
	print((ok and "OK " or "FAIL ") .. f .. (ok and "" or (" " .. tostring(err))))
end
if bad > 0 then
	error(bad .. " file(s) failed to parse")
end

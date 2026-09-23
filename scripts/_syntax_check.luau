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
	-- Hot pages (keep in sync with scripts/verify_playability.luau HOT_PAGES)
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
	"src/Client/AstralForge/pages/WheelView.luau",
	"src/Client/AstralForge/pages/CommandView.luau",
	"src/Client/AstralForge/pages/LeaderboardsView.luau",
	"src/Client/AstralForge/pages/CrateRevealOverlay.luau",
	"src/Client/AstralForge/pages/CrateRevealStage.luau",
	"src/Client/AstralForge/pages/CrateRevealStageSimple.luau",
	"src/Client/AstralForge/pages/MailboxView.luau",
	"src/Client/AstralForge/pages/StarGridView.luau",
	"src/Client/AstralForge/pages/MilestonesView.luau",
	"src/Client/AstralForge/pages/MissionsView.luau",
	"src/Client/AstralForge/pages/ContinuumView.luau",
	"src/Client/AstralForge/pages/ConvergenceView.luau",
	"src/Client/AstralForge/pages/ResearchView.luau",
	"src/Client/AstralForge/pages/BoostsView.luau",
	"src/Client/AstralForge/pages/StoryView.luau",
	"src/Client/AstralForge/OfflineRewardsOverlay.luau",
	"src/Client/AstralForge/DomainExpansionOverlay.luau",
	"src/Client/AstralForge/FeedbackOverlay.luau",
	"src/Client/AstralForge/AdminPrankOverlay.luau",
	"src/Client/AstralForge/DomainSkillTree.luau",
	"src/Client/AstralForge/pages/CreditsView.luau",
	"src/Client/AstralForge/pages/SettingsView.luau",
	"src/Client/AstralForge/input/GamepadNavigationService.luau",
	"src/Client/AstralForge/purchaseOverlay.luau",
	"src/Client/AstralForge/pageScaffold.luau",
	"src/Client/AstralForge/pageScaffoldPlan.luau",
	-- Shared catalog (parse only — no require)
	"src/Shared/AstralForge/Shared/GameConfig.luau",
	-- Server trade desk (offer validation / exchange)
	"src/Server/AstralForge/Modules/TradeDesk.luau",
	"src/Server/AstralForge/Modules/TradeExchange.luau",
	"src/Server/AstralForge/Services/AnomalyService.luau",
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

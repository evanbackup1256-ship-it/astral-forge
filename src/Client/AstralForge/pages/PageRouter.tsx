import React from "@rbxts/react";
import { LuauComponent, LuauProps } from "./luauKits";

const PAGE_SUITES: Record<string, string> = {
	AdminView: "PagesSystem",
	AnomalyView: "PagesSystem",
	BoostsView: "PagesProgress",
	ChatView: "PagesSocial",
	CommandView: "PagesSystem",
	ContinuumView: "PagesProgress",
	FoundryView: "PagesFoundry",
	ConvergenceView: "PagesProgress",
	CrateRevealStage: "PagesShop",
	BazaarView: "PagesBazaar",
	CrewView: "PagesSocial",
	EchoForgeView: "PagesStory",
	ForgePathView: "PagesProgress",
	GuildView: "PagesSocial",
	InventoryView: "PagesStory",
	LabView: "PagesProgress",
	LeaderboardsView: "PagesSystem",
	MailboxView: "PagesSocial",
	MilestonesView: "PagesCore",
	MissionsView: "PagesCore",
	OverviewView: "PagesCore",
	RebirthPanel: "PagesCore",
	ResearchView: "PagesProgress",
	RewardsView: "PagesCore",
	SettingsView: "PagesSystem",
	ShopView: "PagesShop",
	StoreFront: "PagesShop",
	SpecializationsView: "PagesSpecializations",
	AscensionView: "PagesAscension",
	StoryView: "PagesStory",
	TradeView: "PagesSocial",
	WheelView: "PagesShop",
	WorkshopView: "PagesProgress",
	WorldsView: "PagesProgress",
};

interface Thenable {
	andThen(resolve: (value: { default: LuauComponent }) => void, reject: (reason: unknown) => void): void;
}

// Suites are kits (or a function taking the view name); React's Luau lazy() only needs a thenable.
function lazyView(moduleName: string, exportName: string): LuauComponent {
	return React.lazy(() => {
		const thenable: Thenable = {
			andThen(resolve, reject) {
				const [ok, component] = pcall(() => {
					const suite = require(script.Parent!.FindFirstChild(PAGE_SUITES[moduleName]) as ModuleScript) as (
						name: string,
					) => Record<string, LuauComponent | undefined>;
					return suite(moduleName)[exportName];
				});
				if (ok && component !== undefined) {
					resolve({ default: component });
				} else {
					reject(ok ? `Page ${exportName} did not load` : component);
				}
			},
		};
		return thenable as unknown as Promise<{ default: LuauComponent }>;
	}) as unknown as LuauComponent;
}

const MissionsView = lazyView("MissionsView", "MissionsView");
const MilestonesView = lazyView("MilestonesView", "MilestonesView");
const AnomalyView = lazyView("AnomalyView", "AnomalyView");
const LabView = lazyView("LabView", "LabView");
const StoryView = lazyView("StoryView", "StoryView");
const SpecializationsView = lazyView("SpecializationsView", "SpecializationsView");
const AscensionView = lazyView("AscensionView", "AscensionView");
const CommandView = lazyView("CommandView", "CommandView");
const MailboxView = lazyView("MailboxView", "MailboxView");
const ChatView = lazyView("ChatView", "ChatView");
const StoreFront = lazyView("StoreFront", "StoreFront");
const InventoryView = lazyView("InventoryView", "InventoryView");
const GuildView = lazyView("GuildView", "GuildView");
const LeaderboardsView = lazyView("LeaderboardsView", "LeaderboardsView");
const TradeView = lazyView("TradeView", "TradeView");
const SettingsView = lazyView("SettingsView", "SettingsView");
const ContinuumView = lazyView("ContinuumView", "ContinuumView");
const FoundryView = lazyView("FoundryView", "FoundryView");
const ConvergenceView = lazyView("ConvergenceView", "ConvergenceView");
const AdminView = lazyView("AdminView", "AdminView");
const EchoForgeView = lazyView("EchoForgeView", "EchoForgeView");
const CinematicWheelView = lazyView("WheelView", "WheelView");
const ForgePathView = lazyView("ForgePathView", "ForgePathView");
const ResearchView = lazyView("ResearchView", "ResearchView");
const BoostsView = lazyView("BoostsView", "BoostsView");
const CrewView = lazyView("CrewView", "CrewView");
const OverviewView = lazyView("OverviewView", "OverviewView");
const WorldsView = lazyView("WorldsView", "WorldsView");
const RewardsView = lazyView("RewardsView", "RewardsView");
const WorkshopView = lazyView("WorkshopView", "WorkshopView");
const BazaarView = lazyView("BazaarView", "BazaarView");

interface PageConfig {
	Release: { CountdownAt?: number };
	[key: string]: unknown;
}

interface PageContentProps {
	page: string;
	state: unknown;
	config?: PageConfig;
	dispatch: unknown;
	reducedMotion?: boolean;
	navigate: (page: string) => unknown;
	[key: string]: unknown;
}

function PageContentInner(props: PageContentProps) {
	const { page, state, config, dispatch, reducedMotion } = props;
	if (config === undefined) {
		return <frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} />;
	}
	const base: LuauProps = { state, config, dispatch, reducedMotion };
	if (page === "Overview") {
		return (
			<OverviewView
				{...base}
				effectsPaused={props.domainOverlayActive}
				openWorkshop={props.openWorkshop}
				openDomain={props.openDomain}
				releaseAt={config.Release.CountdownAt ?? 1789272000}
				navigate={props.navigate}
			/>
		);
	}
	if (page === "Workshop") {
		return <WorkshopView {...base} buyAmount={props.buyAmount} setBuyAmount={props.setBuyAmount} />;
	}
	if (page === "Research") {
		return <ResearchView {...base} buyAmount={props.buyAmount} setBuyAmount={props.setBuyAmount} />;
	}
	if (page === "Ascension") {
		return <AscensionView state={state} dispatch={dispatch} reducedMotion={reducedMotion} />;
	}
	if (page === "StarGrid") {
		return <SpecializationsView {...base} buyAmount={props.buyAmount} setBuyAmount={props.setBuyAmount} />;
	}
	if (page === "Echoes") {
		return <EchoForgeView state={state} dispatch={dispatch} reducedMotion={reducedMotion} />;
	}
	if (page === "Continuum" || page === "Foundry") {
		// the Star Foundry replaced Continuum (and the Reactor below)
		return <FoundryView {...base} navigate={props.navigate} />;
	}
	if (page === "Convergence") {
		return <ConvergenceView state={state} dispatch={dispatch} reducedMotion={reducedMotion} />;
	}
	if (page === "Lab") {
		return <LabView {...base} />;
	}
	if (page === "Anomaly") {
		return <FoundryView {...base} navigate={props.navigate} />;
	}
	if (page === "Worlds") {
		return <WorldsView {...base} />;
	}
	if (page === "Missions") {
		return <MissionsView {...base} navigate={props.navigate} />;
	}
	if (page === "Milestones") {
		return <MilestonesView {...base} navigate={props.navigate} />;
	}
	if (page === "Wheel") {
		return <CinematicWheelView {...base} onLand={props.onWheelLand} />;
	}
	if (page === "Bazaar") {
		return <BazaarView {...base} />;
	}
	if (page === "Rewards") {
		return <RewardsView {...base} navigate={props.navigate} />;
	}
	if (page === "Boosts") {
		return <BoostsView {...base} />;
	}
	if (page === "Command") {
		return <CommandView {...base} onSectionChange={props.clearConfetti} />;
	}
	if (page === "Story") {
		return <StoryView {...base} />;
	}
	if (page === "Mail") {
		return <MailboxView {...base} />;
	}
	if (page === "Chat") {
		return <ChatView chat={props.chat} reducedMotion={reducedMotion} />;
	}
	if (page === "Crew") {
		return (
			<CrewView state={state} dispatch={dispatch} reducedMotion={reducedMotion} visit={props.visit} setVisit={props.setVisit} />
		);
	}
	if (page === "Guild") {
		return <GuildView {...base} />;
	}
	if (page === "Leaderboards") {
		return <LeaderboardsView state={state} dispatch={dispatch} reducedMotion={reducedMotion} />;
	}
	if (page === "Shop") {
		return (
			<StoreFront
				{...base}
				onPurchasePresentationChange={props.setPurchasePresentationActive}
				crateRevealActive={props.crateRevealActive}
				onCrateReveal={props.setCrateReveal}
				navigate={props.navigate}
			/>
		);
	}
	if (page === "Inventory") {
		return (
			<InventoryView
				{...base}
				crateRevealActive={props.crateRevealActive}
				onCrateReveal={props.setCrateReveal}
				openShop={() => props.navigate("Shop")}
			/>
		);
	}
	if (page === "Trade") {
		return <TradeView {...base} />;
	}
	if (page === "Settings") {
		return <SettingsView state={state} dispatch={dispatch} reducedMotion={reducedMotion} />;
	}
	if (page === "Admin") {
		return <AdminView {...base} />;
	}
	if (page === "ForgePath") {
		return <ForgePathView {...base} />;
	}
	return <frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} />;
}

export const PageContent = React.memo(PageContentInner);

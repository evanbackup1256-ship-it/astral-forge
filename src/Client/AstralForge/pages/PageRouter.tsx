import React from "@rbxts/react";
import { bulkCost, Flux, gteFlux } from "../CoreKit/format";
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

// Pages that only read a few top-level session fields. Snapshots reuse unchanged subtables by
// reference, so comparing just these keys lets a passive push (Cash ticking, stats) skip the page.
// Every other page compares the whole session as before. Keep a list in sync with its view: a
// field read but not listed here would go stale on that page.
const PAGE_STATE_KEYS: Record<string, string[] | undefined> = {
	Chat: [],
	Settings: ["Settings", "Game", "FeatureUnlocks", "Flags"],
	Mail: ["Mailbox"],
	Crew: ["CurrentZone", "Visitors"],
	// upgrade pages: everything they read except Cash, which goes through the affordability check below
	Workshop: ["Machines", "AutoForge", "Production", "Rebirths", "Zone", "Command", "FeatureUnlocks"],
	Research: ["Research", "Rebirths", "Zone", "Command", "FeatureUnlocks"],
};

// Upgrade pages only use Cash to decide which rows are affordable (on a fixed buy amount; Max
// quotes a cash-dependent count, so it keeps comparing Cash directly). With every price known,
// the affordable set is the same exactly when the number of prices at or under Cash is the same.
const CASH_GATED: Record<string, { config: string; levels: string } | undefined> = {
	Workshop: { config: "Machines", levels: "Machines" },
	Research: { config: "Research", levels: "Research" },
};

interface CostDef {
	Id?: string;
	BaseCost?: number;
	CostScale?: number;
	MaxLevel?: number;
}

function affordableCount(defs: unknown, levels: unknown, amount: number, cash: Flux): number {
	if (!typeIs(defs, "table")) {
		return -1;
	}
	const owned = (typeIs(levels, "table") ? levels : {}) as Record<string, number | undefined>;
	let count = 0;
	for (const [, raw] of pairs(defs as object)) {
		const def = raw as CostDef;
		if (!typeIs(def, "table") || def.Id === undefined || def.BaseCost === undefined || def.CostScale === undefined) {
			continue;
		}
		const level = tonumber(owned[def.Id]) ?? 0;
		const max = def.MaxLevel ?? math.huge;
		if (level >= max) {
			continue;
		}
		// the row price on this amount, and the one-level price the auto-forge target waits on
		if (gteFlux(cash, bulkCost(def.BaseCost, def.CostScale, level, amount, max))) {
			count += 1;
		}
		if (gteFlux(cash, bulkCost(def.BaseCost, def.CostScale, level, 1, max))) {
			count += 1;
		}
	}
	return count;
}

function samePageProps(previous: PageContentProps, nextProps: PageContentProps): boolean {
	for (const [key, value] of pairs(nextProps)) {
		if (key !== "state" && previous[key as string] !== value) {
			return false;
		}
	}
	for (const [key] of pairs(previous)) {
		if (key !== "state" && nextProps[key as string] === undefined) {
			return false;
		}
	}
	if (previous.state === nextProps.state) {
		return true;
	}
	const keys = PAGE_STATE_KEYS[nextProps.page];
	if (keys === undefined || !typeIs(previous.state, "table") || !typeIs(nextProps.state, "table")) {
		return false;
	}
	const before = previous.state as Record<string, unknown>;
	const after = nextProps.state as Record<string, unknown>;
	for (const key of keys) {
		if (before[key] !== after[key]) {
			return false;
		}
	}
	const gate = CASH_GATED[nextProps.page];
	if (gate === undefined || before.Cash === after.Cash) {
		return true;
	}
	const amount = nextProps.buyAmount;
	if (!typeIs(amount, "number") || amount <= 0) {
		return false;
	}
	const config = nextProps.config as Record<string, unknown> | undefined;
	const defs = config !== undefined ? config[gate.config] : undefined;
	const was = affordableCount(defs, before[gate.levels], amount, (before.Cash ?? 0) as Flux);
	const now = affordableCount(defs, after[gate.levels], amount, (after.Cash ?? 0) as Flux);
	return was >= 0 && was === now;
}

export const PageContent = React.memo(PageContentInner, samePageProps);

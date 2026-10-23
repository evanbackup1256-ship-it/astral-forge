import { countRedraw, redrawCounterEnabled } from "../UiCore/devRedrawCounter";
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
	RebirthView: "PagesCore",
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
	// ---- v8 C: Expedition Board ----
	ExpeditionsView: "PagesProgress",
	// ---- end v8 C: Expedition Board ----
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

// A view component is created the first time its route is drawn, so a page's suite is required
// only when the player first opens it. React.lazy then suspends until the suite resolves.
const viewCache = new Map<string, LuauComponent>();
function view(name: string): LuauComponent {
	let component = viewCache.get(name);
	if (component === undefined) {
		component = lazyView(name, name);
		viewCache.set(name, component);
	}
	return component;
}

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

interface Route {
	view: string;
	// extra props on top of the shared base; `bare` routes get only state, dispatch and reducedMotion
	props?: (props: PageContentProps, config: PageConfig) => LuauProps;
	bare?: boolean;
}

const withNavigate = (props: PageContentProps): LuauProps => ({ navigate: props.navigate });
const withBuyAmount = (props: PageContentProps): LuauProps => ({ buyAmount: props.buyAmount, setBuyAmount: props.setBuyAmount });
const withCrateReveal = (props: PageContentProps): LuauProps => ({
	crateRevealActive: props.crateRevealActive,
	onCrateReveal: props.setCrateReveal,
});

// Page id -> view. Several ids can share a view (the Star Foundry replaced Continuum and the Reactor).
const ROUTES: Record<string, Route | undefined> = {
	Overview: {
		view: "OverviewView",
		props: (props, config) => ({
			effectsPaused: props.domainOverlayActive,
			openWorkshop: props.openWorkshop,
			openDomain: props.openDomain,
			releaseAt: config.Release.CountdownAt ?? 1789272000,
			navigate: props.navigate,
		}),
	},
	Workshop: { view: "WorkshopView", props: withBuyAmount },
	Research: { view: "ResearchView", props: withBuyAmount },
	StarGrid: { view: "SpecializationsView", props: withBuyAmount },
	Ascension: { view: "AscensionView", bare: true },
	Rebirth: { view: "RebirthView" },
	Echoes: { view: "EchoForgeView", bare: true },
	Convergence: { view: "ConvergenceView", bare: true },
	Leaderboards: { view: "LeaderboardsView", bare: true },
	Settings: { view: "SettingsView", bare: true },
	Continuum: { view: "FoundryView", props: withNavigate },
	Foundry: { view: "FoundryView", props: withNavigate },
	Anomaly: { view: "FoundryView", props: withNavigate },
	Worlds: { view: "WorldsView", props: withNavigate },
	Missions: { view: "MissionsView", props: withNavigate },
	Milestones: { view: "MilestonesView", props: withNavigate },
	Rewards: { view: "RewardsView", props: withNavigate },
	Wheel: { view: "WheelView", props: (props) => ({ onLand: props.onWheelLand }) },
	Command: { view: "CommandView", props: (props) => ({ onSectionChange: props.clearConfetti }) },
	Shop: { view: "StoreFront", props: (props) => ({ ...withCrateReveal(props), navigate: props.navigate }) },
	Inventory: { view: "InventoryView", props: (props) => ({ ...withCrateReveal(props), openShop: () => props.navigate("Shop") }) },
	Lab: { view: "LabView" },
	Bazaar: { view: "BazaarView" },
	Boosts: { view: "BoostsView" },
	Story: { view: "StoryView" },
	Mail: { view: "MailboxView" },
	Guild: { view: "GuildView" },
	Trade: { view: "TradeView" },
	Admin: { view: "AdminView" },
	ForgePath: { view: "ForgePathView" },
	Expeditions: { view: "ExpeditionsView" },
};

// Chat and Crew take their own props rather than the shared base.
const CUSTOM: Record<string, ((props: PageContentProps) => React.Element) | undefined> = {
	Chat: (props) => {
		const ChatView = view("ChatView");
		return <ChatView chat={props.chat} reducedMotion={props.reducedMotion} />;
	},
	Crew: (props) => {
		const CrewView = view("CrewView");
		return (
			<CrewView
				state={props.state}
				dispatch={props.dispatch}
				reducedMotion={props.reducedMotion}
				visit={props.visit}
				setVisit={props.setVisit}
			/>
		);
	},
};

function EmptyPage() {
	return <frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} />;
}

function PageContentInner(props: PageContentProps) {
	const { page, state, config, dispatch, reducedMotion } = props;
	countRedraw(`page:${page}`, redrawCounterEnabled(state as { Admin?: { Access?: boolean } }));
	if (config === undefined) {
		return <EmptyPage />;
	}
	const custom = CUSTOM[page];
	if (custom !== undefined) {
		return custom(props);
	}
	const route = ROUTES[page];
	if (route === undefined) {
		return <EmptyPage />;
	}
	const View = view(route.view);
	const base: LuauProps = route.bare ? { state, dispatch, reducedMotion } : { state, config, dispatch, reducedMotion };
	const extra = route.props !== undefined ? route.props(props, config) : undefined;
	return <View {...base} {...extra} />;
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
	Workshop: ["Machines", "AutoForge", "Production", "Rebirths", "Zone", "Command", "FeatureUnlocks", "ForgePrograms"],
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

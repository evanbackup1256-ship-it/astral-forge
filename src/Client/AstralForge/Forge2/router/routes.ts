// Route table. Every legacy route is listed (so the rail is complete from day one); a route
// without a Forge2 page yet shows a quiet placeholder until its port lands.
import React from "@rbxts/react";
import { find, NAV_GROUPS } from "../../CoreKit/navRouteTable";
import type { MobileChrome } from "../../CoreKit/theme";
import type { Session } from "../../state";
import type { Request } from "../store/net";
import { OverviewPage } from "../pages/OverviewPage";
import { InventoryPage } from "../pages/InventoryPage";
import { FoundryPage } from "../pages/FoundryPage";
import { LabPage } from "../pages/LabPage";
import { ExpeditionsPage } from "../pages/ExpeditionsPage";
import { StoryPage } from "../pages/StoryPage";
import { ConvergencePage } from "../pages/ConvergencePage";
import { WorldsPage } from "../pages/WorldsPage";
import { AscensionPage } from "../pages/AscensionPage";
import { StarGridPage } from "../pages/StarGridPage";
import { EchoesPage } from "../pages/EchoesPage";
import { MailPage } from "../pages/MailPage";
import { ChatPage } from "../pages/ChatPage";
import { RewardsPage } from "../pages/RewardsPage";
import { MilestonesPage } from "../pages/MilestonesPage";
import { WheelPage } from "../pages/WheelPage";
import { ForgePathPage } from "../pages/ForgePathPage";
import { SettingsPage } from "../pages/SettingsPage";

export interface PageProps {
	session: Session;
	config: Record<string, unknown>;
	request: Request;
	navigate: (page: string) => void;
	phone: boolean;
	chrome: MobileChrome;
	busy: Readonly<Record<string, boolean>>;
}

export type PageComponent = (props: PageProps) => React.Element | undefined;

const PORTED: Record<string, PageComponent> = {
	Overview: OverviewPage,
	Inventory: InventoryPage,
	// the Star Foundry replaced Continuum and the Reactor; all three ids land on it
	Continuum: FoundryPage,
	Foundry: FoundryPage,
	Anomaly: FoundryPage,
	Lab: LabPage,
	Expeditions: ExpeditionsPage,
	Story: StoryPage,
	Convergence: ConvergencePage,
	Worlds: WorldsPage,
	Ascension: AscensionPage,
	StarGrid: StarGridPage,
	Echoes: EchoesPage,
	Mail: MailPage,
	Chat: ChatPage,
	Rewards: RewardsPage,
	Milestones: MilestonesPage,
	Wheel: WheelPage,
	ForgePath: ForgePathPage,
	Settings: SettingsPage,
};

export function pageFor(id: string): PageComponent | undefined {
	return PORTED[id];
}

export function labelOf(id: string): string {
	return find(id)?.label ?? id;
}

export interface NavGroupView {
	key: string;
	label: string;
	routes: string[];
}

/** Rail groups; Credits has no page of its own and is left out. */
export function navGroups(): NavGroupView[] {
	return NAV_GROUPS.map((group) => ({ key: group.key, label: group.label, routes: group.routes.filter((id) => id !== "Credits") }));
}

/** Phone bar: the ported pages first, then the old priority order. */
export const PHONE_TABS: ReadonlyArray<string> = ["Overview", "Inventory", "Workshop", "Shop", "Missions"];

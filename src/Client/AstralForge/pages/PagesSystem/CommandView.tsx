import React from "@rbxts/react";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { clockText, compactNumber, Flux, formatReward, gteFlux, Reward } from "../../CoreKit/format";
import { chromeFor, Layout, Palette, TapTarget } from "../../CoreKit/theme";
import { easeOutCubic, useBoatTween, useStagger, useViewport } from "../../MotionKit/motion";
import { BrowseApi, BrowseCategory, BrowseSort, clientModule, kitMember, LuauComponent } from "../luauKits";
import { useServerClock } from "../../hooks/useServerClock";

const UserInputService = game.GetService("UserInputService");

const DescribeGenerated = require(
	game.GetService("ReplicatedStorage").WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("DescribeGenerated") as ModuleScript,
) as {
	seasonTierName(this: void, tier: number): string;
	milestoneName(this: void, tier: number): string;
	tripLine(this: void, count: number, foundRelic: boolean): string;
};

const SeasonPremium = require(
	game.GetService("ReplicatedStorage").WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("SeasonPremium") as ModuleScript,
) as { PassKey: string; Reward(this: void, tier: number): Reward };

interface AnimatedTitleKit {
	AnimatedTitlePreview: LuauComponent;
	darkTitlePlate: (this: void, fx: string) => Color3;
	titleFxAccent: (this: void, fx: string) => Color3;
	titleTier: (this: void, fx: string) => string;
}
const { AnimatedTitlePreview, darkTitlePlate, titleFxAccent, titleTier } = kitMember<AnimatedTitleKit>("ReactHosts", "AnimatedTitle");
import { AutoPage } from "./AutoPage";

interface UiKit {
	Badge: LuauComponent;
	Button: LuauComponent;
	IconTile: LuauComponent;
	Meter: LuauComponent;
	Panel: LuauComponent;
	SectionLabel: LuauComponent;
	SegmentedTabs: LuauComponent;
	Text: LuauComponent;
	meterFill: (this: void, value: number, target: number, full?: boolean) => number;
}
const { Badge, Button, IconTile, Meter, meterFill, Panel, SectionLabel, SegmentedTabs, Text } = kitMember<UiKit>("UiCore", "ui");

const ElementFxModule = clientModule<{
	ElementFx: LuauComponent;
	sheet: (this: void, element: unknown) => { Color: Color3; Label: string } | undefined;
}>("ElementFx");
const ElementFx = ElementFxModule.ElementFx;
const elementSheet = ElementFxModule.sheet;
const Browse = clientModule<BrowseApi>("BrowseKit");

export interface Directive {
	Id: string;
	Name: string;
	Description?: string;
	Claimed?: boolean;
	Progress: number;
	Target: number;
	Reward?: Reward;
}

export interface TitleEntry {
	Id: string;
	Name: string;
	Description?: string;
	Unlocked?: boolean;
	Equipped?: boolean;
	Fx?: string;
}

export interface Expedition {
	Id: string;
	Name: string;
	Color: Color3;
	RequiredLevel: number;
	Duration: number;
	ArtifactChance: number;
	ArtifactId?: string;
	Reward?: Reward;
}

export interface ArtifactDef {
	Id: string;
	Name: string;
	Rarity: string;
	Color: Color3;
	Element: unknown;
	EffectKind: string;
	EffectPerLevel: number;
}

export interface SeasonTier {
	Tier: number;
	RequiredXP: number;
	Reward?: Reward;
}

export interface CommandState {
	Level: number;
	XP: number;
	LevelFloorXP: number;
	NextLevelXP: number;
	Rank?: string;
	Signals: number;
	ExpeditionsCompleted: number;
	StreakShields: number;
	ClaimableCommanderLevels: number[];
	ActiveExpedition?: { Id?: string; EndsAt?: number; StartedAt?: number };
	Weekly: Directive[];
	SeasonClaims: Record<string, boolean | undefined>;
	PremiumClaims?: Record<string, boolean | undefined>;
	SeasonPassOwned?: boolean;
	SeasonXP: number;
	Artifacts: Record<string, { Level: number; Fragments: number } | undefined>;
	EquippedArtifact?: string;
	Titles: TitleEntry[];
	Crew: Record<string, number | undefined>;
	MachineMastery: Record<string, number | undefined>;
}

export interface Operations {
	Expeditions: Expedition[];
	Artifacts: ArtifactDef[];
	SeasonTiers: SeasonTier[];
	SeasonName?: string;
	TitlesEnabled?: boolean;
	TitleStatus?: string;
	MaxCommanderLevel: number;
	Crew: Record<string, { Name: string; Color: Color3; BaseCost: number; MaxLevel: number; Description?: string } | undefined>;
}

export interface CommandProps {
	state: { Command?: CommandState; Stardust?: Flux; Cosmetics?: unknown; Rebirths?: unknown };
	config: { Operations?: Operations; Machines: Array<{ Id: string; Name: string; Color: Color3 }> };
	dispatch: (action: string, payload?: object, callback?: (response: { ok?: boolean; message?: string; ArtifactNew?: boolean }) => void) => unknown;
	reducedMotion?: boolean;
	onSectionChange?: () => void;
}

const TABS = ["Overview", "Titles", "Expeditions", "Artifacts", "Season", "Crew"];
const TAB_LABEL: Record<string, string> = {
	Overview: "COMMAND",
	Titles: "WARDROBE",
	Expeditions: "EXPEDITIONS",
	Artifacts: "RELIQUARY",
	Season: "SEASON",
	Crew: "CREW",
};
const TAB_OPTIONS = TABS.map((id) => ({ id, label: TAB_LABEL[id] }));

const { BrowseBar, NoResults } = Browse;

// A title's rarity is its look's tier; the rank orders the "Rarest first" sort
const TITLE_TIER_RANK: Record<string, number | undefined> = { MYTHIC: 1, LEGENDARY: 2, EPIC: 3, RARE: 4, COMMON: 5 };
function tierOf(entry: TitleEntry): string {
	return titleTier(entry.Fx ?? "shimmer").upper();
}
function tierRank(entry: TitleEntry): number {
	return TITLE_TIER_RANK[tierOf(entry)] ?? 9;
}
const TITLE_CATEGORIES: BrowseCategory<TitleEntry>[] = [
	{ id: "All", label: "All" },
	{ id: "Owned", label: "Owned", test: (entry) => entry.Unlocked === true },
	{ id: "Locked", label: "Locked", test: (entry) => entry.Unlocked !== true },
	...["Mythic", "Legendary", "Epic", "Rare", "Common"].map((tier) => ({
		id: tier,
		label: tier,
		test: (entry: TitleEntry) => tierOf(entry) === tier.upper(),
	})),
];
const TITLE_SORTS: BrowseSort<TitleEntry>[] = [
	{ id: "Default", label: "Recommended" },
	{ id: "Rarity", label: "Rarest first", compare: (a, b) => tierRank(a) < tierRank(b) },
	{ id: "Owned", label: "Owned first", compare: (a, b) => a.Unlocked === true && b.Unlocked !== true },
	{ id: "Name", label: "A to Z", compare: (a, b) => a.Name < b.Name },
];

const RARITY_COLORS: Record<string, Color3> = {
	Common: Color3.fromRGB(180, 190, 205),
	Rare: Color3.fromRGB(80, 180, 255),
	Epic: Color3.fromRGB(195, 110, 255),
	Legendary: Color3.fromRGB(255, 195, 60),
	Mythic: Color3.fromRGB(255, 95, 135),
	Divine: Color3.fromRGB(255, 235, 140),
};

const CREW_ROLES = ["Pilot", "Engineer", "Navigator"];
const CREW_PERKS: Record<string, string> = {
	Pilot: "+15% Expedition Speed per rank",
	Engineer: "+20% Artifact Fragment yield",
	Navigator: "+10% Rare Relic discovery rate",
};

function crewCost(base: number, level: number) {
	return math.floor(base * math.pow(level, 1.55));
}

function artifactEffect(artifact: ArtifactDef, level: number) {
	if (artifact.EffectKind === "OfflineHours") {
		return `+${"%.1f".format(artifact.EffectPerLevel * level)}h offline`;
	}
	return `+${"%.0f".format(artifact.EffectPerLevel * level * 100)}% ${artifact.EffectKind}`;
}

const ARTIFACT_ICONS: Record<string, string | undefined> = {
	SolarLens: "Forge",
	VaultPrism: "Vault",
	PulsarCoil: "Overcharge",
	EchoRelay: "Visit",
	DroneCrown: "Grid",
	CriticalShard: "Jackpot",
	CoreStabilizer: "Core",
	TimeCompass: "Timer",
	MagnetarSeal: "Anomaly",
	VoidKey: "Lock",
	AuroraMap: "World",
	CrownOfHours: "Milestone",
};

function artifactIcon(id: string) {
	return ARTIFACT_ICONS[id] ?? "Artifact";
}

let lastTripId: string | undefined;

function landsAt(unix: number): string {
	const [text] = string.gsub(os.date("%I:%M %p", math.floor(unix)), "^0", "");
	return text;
}

function useTripLanded(active: boolean, endsAt: number): boolean {
	const serverNow = () => game.GetService("Workspace").GetServerTimeNow();
	const [landed, setLanded] = React.useState(() => active && serverNow() >= endsAt);
	React.useEffect(() => {
		if (!active) {
			setLanded(false);
			return undefined;
		}
		const left = endsAt - serverNow();
		if (left <= 0) {
			setLanded(true);
			return undefined;
		}
		setLanded(false);
		const timer = task.delay(left, () => setLanded(true));
		return () => {
			pcall(() => task.cancel(timer));
		};
	}, [active, endsAt]);
	return landed;
}

function TabPane(props: { tabKey: string; reducedMotion?: boolean; children?: React.ReactNode }) {
	const reducedMotion = props.reducedMotion;
	const enter = useBoatTween(1, reducedMotion ? 0.01 : 0.22, reducedMotion, easeOutCubic, 0);
	return (
		<frame
			key={props.tabKey}
			Size={new UDim2(1, 0, 0, 0)}
			AutomaticSize={Enum.AutomaticSize.Y}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			LayoutOrder={20}
		>
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, Layout.panelGap)} />
			<frame
				Size={new UDim2(1, 0, 0, 0)}
				AutomaticSize={Enum.AutomaticSize.Y}
				Position={enter.map((a) => new UDim2(0, 0, 0, math.round((1 - math.clamp(a, 0, 1)) * 6)))}
				BackgroundTransparency={1}
				BorderSizePixel={0}
			>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, Layout.panelGap)} />
				{props.children}
			</frame>
		</frame>
	);
}

export function CommandView(props: CommandProps) {
	const { state, config, dispatch, onSectionChange } = props;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const reducedMotion = props.reducedMotion === true;
	const [contentWidth, setContentWidth] = React.useState(700);
	const stack = chrome.contentStack || contentWidth < 740;
	const scrollRef = React.useRef<ScrollingFrame>();

	const ops = config.Operations ?? {
		Expeditions: [],
		Artifacts: [],
		SeasonTiers: [],
		MaxCommanderLevel: 50,
		Crew: {},
	};
	const command = state.Command ?? {
		Level: 1,
		XP: 0,
		LevelFloorXP: 0,
		NextLevelXP: 1000,
		Signals: 0,
		ExpeditionsCompleted: 0,
		StreakShields: 0,
		ClaimableCommanderLevels: [],
		Weekly: [],
		SeasonClaims: {},
		SeasonXP: 0,
		Artifacts: {},
		Titles: [],
		Crew: {},
		MachineMastery: {},
	};

	const [tab, setTab] = React.useState("Overview");

	// Active expedition state
	const active = command.ActiveExpedition;
	const activeId = active?.Id ?? "";
	const activeEnds = active?.EndsAt ?? 0;
	const activeStarted = active?.StartedAt ?? 0;
	const expeditionReady = useTripLanded(activeId !== "", activeEnds);
	const serverNow = useServerClock(tab === "Expeditions" && activeId !== "" && !expeditionReady);

	if (activeId !== "") {
		lastTripId = activeId;
	}

	const [tripReport, setTripReport] = React.useState<{ name: string; haul: string; found: boolean } | undefined>(undefined);
	const [pendingKey, setPendingKey] = React.useState<string | undefined>(undefined);

	const sendAction = (key: string, action: string, payload: object) => {
		if (pendingKey !== undefined) return;
		setPendingKey(key);
		const timeout = task.delay(7, () => setPendingKey(undefined));
		dispatch(action, payload, (res) => {
			pcall(task.cancel, timeout);
			setPendingKey(undefined);
		});
	};

	// Measure container width
	React.useEffect(() => {
		const host = scrollRef.current;
		if (!host) return undefined;
		const measure = () => {
			if (host.AbsoluteSize.X > 0) {
				setContentWidth(host.AbsoluteSize.X);
			}
		};
		measure();
		const conn = host.GetPropertyChangedSignal("AbsoluteSize").Connect(measure);
		return () => conn.Disconnect();
	}, []);

	// Active equipped title
	const titlesList = command.Titles ?? [];
	const equippedTitle = titlesList.find((t) => t.Equipped === true) ?? titlesList[0];
	const [selectedTitleId, setSelectedTitleId] = React.useState<string>(equippedTitle?.Id ?? "");
	const currentPreviewTitle = titlesList.find((t) => t.Id === selectedTitleId) ?? equippedTitle;

	// Titles: search, rarity and sort come from the shared browse kit, like every other list page
	const titleBrowse = Browse.useBrowse<TitleEntry>({
		id: "CommandTitles",
		items: titlesList,
		text: (entry) => [entry.Name, entry.Description, tierOf(entry), entry.Fx],
		categories: TITLE_CATEGORIES,
		sorts: TITLE_SORTS,
	});

	// Commander Level calculations
	const maxedLevel = command.Level >= ops.MaxCommanderLevel;
	const levelRange = math.max(1, command.NextLevelXP - command.LevelFloorXP);
	const levelProgress = maxedLevel ? 1 : math.clamp((command.XP - command.LevelFloorXP) / levelRange, 0, 1);
	const nextClaimable = command.ClaimableCommanderLevels[0] as number | undefined;

	// Expeditions repeat
	const repeatTrip = activeId === "" && lastTripId !== undefined ? ops.Expeditions.find((item) => item.Id === lastTripId) : undefined;
	const canRepeat = repeatTrip !== undefined && command.Level >= repeatTrip.RequiredLevel;

	// Season pass calculations
	const passOwned = command.SeasonPassOwned === true;
	const nextSeasonTier = ops.SeasonTiers.find((tier) => command.SeasonClaims[tostring(tier.Tier)] !== true);
	const seasonFill = nextSeasonTier ? math.clamp(command.SeasonXP / math.max(1, nextSeasonTier.RequiredXP), 0, 1) : 1;

	// Render Tab Navigation Bar
	const tabRail = (
		<Panel
			size={new UDim2(1, 0, 0, stack ? 44 : 48)}
			accent={Palette.cyan}
			background={Palette.panel}
			padding={4}
			layoutOrder={1}
			reducedMotion={reducedMotion}
		>
			<SegmentedTabs
				options={TAB_OPTIONS}
				value={tab}
				onChange={(val: string) => {
					setTab(val);
					onSectionChange?.();
					if (scrollRef.current) {
						scrollRef.current.CanvasPosition = new Vector2(0, 0);
					}
				}}
				accent={Palette.cyan}
				columns={stack ? 3 : TABS.size()}
				gap={4}
				size={UDim2.fromScale(1, 1)}
				reducedMotion={reducedMotion}
			/>
		</Panel>
	);

	// --------------------------------------------------------------------------------------------
	// TAB 1: OVERVIEW (TACTICAL COMMAND HUB)
	// --------------------------------------------------------------------------------------------
	const overviewTab = (
		<TabPane tabKey="Overview" reducedMotion={reducedMotion}>
			{/* Hero Status Banner */}
			<Panel
				size={new UDim2(1, 0, 0, stack ? 160 : 138)}
				accent={Palette.cyan}
				background={Palette.panelRaised}
				padding={14}
				layoutOrder={1}
				reducedMotion={reducedMotion}
			>
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
					<frame Size={new UDim2(1, -120, 0, 26)} BackgroundTransparency={1}>
						<Text
							value={`COMMANDER RANK  ·  LEVEL ${command.Level}`}
							size={14}
							color={Palette.cream}
							weight={Enum.FontWeight.Heavy}
							align={Enum.TextXAlignment.Left}
						/>
					</frame>
					<frame Size={UDim2.fromOffset(110, 26)} Position={new UDim2(1, -110, 0, 0)} BackgroundTransparency={1}>
						<Badge filled={true}
							value={`${compactNumber(command.Signals)} SIGNALS`}
							accent={Palette.cyan}
						
							size={UDim2.fromScale(1, 1)}
						/>
					</frame>

					{/* XP Meter */}
					<frame Size={new UDim2(1, 0, 0, 18)} Position={UDim2.fromOffset(0, 36)} BackgroundTransparency={1}>
						<Meter
							value={levelProgress}
							color={Palette.cyan}
							size={UDim2.fromScale(1, 1)}
							reducedMotion={reducedMotion}
						/>
					</frame>
					<frame Size={new UDim2(1, 0, 0, 16)} Position={UDim2.fromOffset(0, 58)} BackgroundTransparency={1}>
						<Text
							value={maxedLevel ? "MAXIMUM RANK ATTAINED" : `${compactNumber(command.XP - command.LevelFloorXP)} / ${compactNumber(levelRange)} XP TO LEVEL ${command.Level + 1}`}
							size={11}
							color={Palette.muted}
							align={Enum.TextXAlignment.Left}
						/>
					</frame>

					{/* Action / Claim Button */}
					{nextClaimable !== undefined && (
						<Button
							text={`CLAIM RANK ${nextClaimable} REWARD`}
							icon="Gift"
							onClick={() => sendAction("ClaimLevel", "ClaimCommanderReward", { Level: nextClaimable })}
							color={Palette.mint}
							textColor={Palette.ink}
							size={new UDim2(1, 0, 0, 36)}
							position={new UDim2(0, 0, 1, -36)}
							loading={pendingKey === "ClaimLevel"}
							reducedMotion={reducedMotion}
						/>
					)}
				</frame>
			</Panel>

			{/* Active Fleet Expedition Card */}
			<Panel
				size={new UDim2(1, 0, 0, stack ? 130 : 110)}
				accent={Palette.violet}
				background={Palette.panel}
				padding={14}
				layoutOrder={2}
				reducedMotion={reducedMotion}
			>
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
					<SectionLabel value="ACTIVE FLEET DISPATCH" color={Palette.violet} />
					<Text
						value={
							activeId === ""
								? "No fleet currently deployed into deep space."
								: expeditionReady
								? "Fleet has returned with expedition spoils!"
								: `Fleet underway. Landing at ${landsAt(activeEnds)}.`
						}
						size={12}
						color={Palette.creamSoft}
						position={UDim2.fromOffset(0, 22)} sizeConstraint={new UDim2(1, 0, 0, 18)}
						align={Enum.TextXAlignment.Left}
					/>
					<frame Size={UDim2.fromOffset(160, 34)} Position={new UDim2(1, -160, 1, -34)} BackgroundTransparency={1}>
						{activeId === "" ? (
							<Button
								text={canRepeat ? "REPEAT TRIP" : "EXPEDITIONS"}
								icon="World"
								onClick={() => {
									if (canRepeat && repeatTrip) {
										sendAction("RepeatTrip", "LaunchExpedition", { Id: repeatTrip.Id });
									} else {
										setTab("Expeditions");
									}
								}}
								color={Palette.violet}
								textColor={Palette.ink}
								size={UDim2.fromScale(1, 1)}
								reducedMotion={reducedMotion}
							/>
						) : (
							<Button
								text={expeditionReady ? "COLLECT SPOILS" : "IN FLIGHT"}
								icon="Collect"
								onClick={() => {
									if (expeditionReady) {
										sendAction("ClaimExp", "ClaimExpedition", {});
									}
								}}
								color={expeditionReady ? Palette.mint : Palette.panelSoft}
								textColor={expeditionReady ? Palette.ink : Palette.muted}
								size={UDim2.fromScale(1, 1)}
								reducedMotion={reducedMotion}
							/>
						)}
					</frame>
				</frame>
			</Panel>

			{/* Tactical Directives List */}
			<Panel
				size={new UDim2(1, 0, 0, 0)}
				autoHeight={true}
				accent={Palette.mango}
				background={Palette.panel}
				padding={14}
				layoutOrder={3}
				reducedMotion={reducedMotion}
			>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 10)} />
				<SectionLabel value="TACTICAL DIRECTIVES" color={Palette.mango} />
				{(command.Weekly ?? []).map((directive, index) => {
					const finished = directive.Claimed === true;
					const canClaim = !finished && directive.Progress >= directive.Target;
					const progressFrac = math.clamp(directive.Progress / math.max(1, directive.Target), 0, 1);
					return (
						<frame
							key={directive.Id}
							Size={new UDim2(1, 0, 0, stack ? 84 : 64)}
							BackgroundColor3={Palette.panelSoft}
							BackgroundTransparency={0.2}
							BorderSizePixel={0}
							LayoutOrder={index + 1}
						>
							<uicorner CornerRadius={new UDim(0, Layout.buttonRadius)} />
							<uistroke Color={canClaim ? Palette.mango : Palette.lineSoft} Thickness={1} Transparency={0.5} />
							<frame Size={new UDim2(1, -140, 1, 0)} Position={UDim2.fromOffset(12, 0)} BackgroundTransparency={1}>
								<Text
									value={directive.Name}
									size={13}
									color={Palette.cream}
									weight={Enum.FontWeight.Heavy}
									align={Enum.TextXAlignment.Left}
									position={UDim2.fromOffset(0, 10)} sizeConstraint={new UDim2(1, 0, 0, 19)}
								/>
								<Text
									value={directive.Description ?? `${compactNumber(directive.Progress)}/${compactNumber(directive.Target)} completed`}
									size={11}
									color={Palette.muted}
									align={Enum.TextXAlignment.Left}
									position={UDim2.fromOffset(0, 28)} sizeConstraint={new UDim2(1, 0, 0, 17)}
								/>
								<frame Size={new UDim2(1, 0, 0, 6)} Position={UDim2.fromOffset(0, stack ? 64 : 46)} BackgroundTransparency={1}>
									<Meter value={progressFrac} color={Palette.mango} size={UDim2.fromScale(1, 1)} reducedMotion={reducedMotion} />
								</frame>
							</frame>
							<frame Size={UDim2.fromOffset(110, 36)} Position={new UDim2(1, -122, 0.5, -18)} BackgroundTransparency={1}>
								<Button
									text={finished ? "CLAIMED" : canClaim ? "CLAIM" : `${math.floor(progressFrac * 100)}%`}
									onClick={() => {
										if (canClaim) {
											sendAction(`Dir_${directive.Id}`, "ClaimDirective", { Id: directive.Id });
										}
									}}
									color={canClaim ? Palette.mango : Palette.panelRaised}
									textColor={canClaim ? Palette.ink : Palette.muted}
									size={UDim2.fromScale(1, 1)}
									loading={pendingKey === `Dir_${directive.Id}`}
									reducedMotion={reducedMotion}
								/>
							</frame>
						</frame>
					);
				})}
			</Panel>
		</TabPane>
	);

	// --------------------------------------------------------------------------------------------
	// TAB 2: TITLES & WARDROBE (BRAND NEW COMPLETE REVAMP)
	// --------------------------------------------------------------------------------------------
	const previewFx = currentPreviewTitle?.Fx ?? "shimmer";
	const previewAccent = titleFxAccent(previewFx);
	const previewTier = titleTier(previewFx).upper();
	const previewIsEquipped = currentPreviewTitle?.Equipped === true;
	const previewIsUnlocked = currentPreviewTitle?.Unlocked === true;

	const titlesTab = (
		<TabPane tabKey="Titles" reducedMotion={reducedMotion}>
			{/* Interactive Live Holographic Title Showcase Card */}
			<Panel
				size={new UDim2(1, 0, 0, stack ? 230 : 190)}
				accent={previewAccent}
				background={darkTitlePlate(previewFx)}
				padding={16}
				layoutOrder={1}
				reducedMotion={reducedMotion}
			>
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
					{/* Header tier and FX tag */}
					<frame Size={new UDim2(1, 0, 0, 20)} BackgroundTransparency={1}>
						<Badge filled={true}
							value={`${previewTier} · ${previewFx.upper()}`}
							accent={previewAccent}
						
							size={UDim2.fromOffset(140, 20)}
						/>
						<Text
							value={previewIsEquipped ? "EQUIPPED TITLE" : previewIsUnlocked ? "OWNED TITLE" : "LOCKED TITLE"}
							size={11}
							color={previewIsEquipped ? Palette.mint : previewIsUnlocked ? Palette.creamSoft : Palette.muted}
							weight={Enum.FontWeight.Heavy}
							align={Enum.TextXAlignment.Right}
							position={new UDim2(1, -120, 0, 0)}
							sizeConstraint={UDim2.fromOffset(120, 20)}
						/>
					</frame>

					{/* Live Animated Title Display */}
					<frame Size={new UDim2(1, 0, 0, 44)} Position={UDim2.fromOffset(0, 26)} BackgroundTransparency={1}>
						<AnimatedTitlePreview
							text={currentPreviewTitle?.Name ?? "Stellar Voyager"}
							fx={previewFx}
							size={stack ? 22 : 26}
							preview={!previewIsEquipped}
							reducedMotion={reducedMotion}
						/>
					</frame>

					{/* Simulated In-Game Chat & Overhead Preview */}
					<frame
						Size={new UDim2(1, 0, 0, 38)}
						Position={UDim2.fromOffset(0, 76)}
						BackgroundColor3={Palette.void}
						BackgroundTransparency={0.4}
						BorderSizePixel={0}
					>
						<uicorner CornerRadius={new UDim(0, 8)} />
						<uistroke Color={previewAccent} Thickness={1} Transparency={0.7} />
						<Text
							value={`[${previewTier.sub(1, 3)} · ${currentPreviewTitle?.Name ?? "Explorer"}] Player: System status online.`}
							size={11}
							color={Palette.cream}
							align={Enum.TextXAlignment.Left}
							position={UDim2.fromOffset(10, 2)}
							sizeConstraint={new UDim2(1, -20, 0, 16)}
						/>
						<Text
							value={currentPreviewTitle?.Description ?? "Earned through distinguished cosmic achievements."}
							size={11}
							color={Palette.muted}
							align={Enum.TextXAlignment.Left}
							position={UDim2.fromOffset(10, 20)}
							sizeConstraint={new UDim2(1, -20, 0, 14)}
						/>
					</frame>

					{/* Equip CTA Button */}
					<frame Size={new UDim2(1, 0, 0, 36)} Position={new UDim2(0, 0, 1, -36)} BackgroundTransparency={1}>
						{previewIsUnlocked && !previewIsEquipped ? (
							<Button
								text="EQUIP TITLE CREST"
								icon="Loadout"
								onClick={() => {
									if (currentPreviewTitle) {
										sendAction(`Equip_${currentPreviewTitle.Id}`, "EquipTitle", { Id: currentPreviewTitle.Id });
									}
								}}
								color={previewAccent}
								textColor={Palette.ink}
								size={UDim2.fromScale(1, 1)}
								loading={pendingKey === `Equip_${currentPreviewTitle?.Id}`}
								reducedMotion={reducedMotion}
							/>
						) : (
							<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.panelSoft} BorderSizePixel={0}>
								<uicorner CornerRadius={new UDim(0, Layout.buttonRadius)} />
								<uistroke Color={previewIsEquipped ? Palette.mint : Palette.lineSoft} Thickness={1} Transparency={0.5} />
								<Text
									value={previewIsEquipped ? "CREST IS CURRENTLY EQUIPPED" : "UNLOCK VIA GAMEPLAY TO EQUIP"}
									size={12}
									color={previewIsEquipped ? Palette.mint : Palette.muted}
									weight={Enum.FontWeight.Heavy}
								/>
							</frame>
						)}
					</frame>
				</frame>
			</Panel>

				{/* Search, sort and rarity chips: the same bar every list page uses */}
				<frame Size={new UDim2(1, 0, 0, Browse.barHeight(stack, true))} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2} ZIndex={30}>
					<BrowseBar browse={titleBrowse} placeholder="Search titles" accent={Palette.cyan} stack={stack} reducedMotion={reducedMotion} />
				</frame>

			{/* Titles Grid */}
				{titleBrowse.results.size() === 0 ? (
					<NoResults
						browse={titleBrowse}
						noun="titles"
						icon="Loadout"
						accent={Palette.violet}
						reducedMotion={reducedMotion}
						size={new UDim2(1, 0, 0, 220)}
						layoutOrder={3}
					/>
				) : (
			<Panel
				size={new UDim2(1, 0, 0, 0)}
				autoHeight={true}
				accent={Palette.violet}
				background={Palette.panel}
				padding={14}
				layoutOrder={3}
				reducedMotion={reducedMotion}
			>
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1}>
					<uigridlayout
						CellSize={new UDim2(stack ? 0.5 : 0.333, -8, 0, 160)}
						CellPadding={UDim2.fromOffset(8, 8)}
						SortOrder={Enum.SortOrder.LayoutOrder}
					/>
					{titleBrowse.results.map((item, idx) => {
						const fx = item.Fx ?? "shimmer";
						const cardAccent = titleFxAccent(fx);
						const cardTier = titleTier(fx).upper();
						const isSelected = item.Id === currentPreviewTitle?.Id;
						const isEquipped = item.Equipped === true;
						const isUnlocked = item.Unlocked === true;

						return (
							<frame
								key={item.Id}
								BackgroundColor3={darkTitlePlate(fx)}
								BackgroundTransparency={isEquipped ? 0.1 : isSelected ? 0.15 : 0.35}
								BorderSizePixel={0}
								LayoutOrder={idx + 1}
							>
								<uicorner CornerRadius={new UDim(0, 12)} />
								<uistroke
									Color={isEquipped ? Palette.mint : isSelected ? cardAccent : Palette.lineSoft}
									Thickness={isEquipped ? 2 : isSelected ? 1.6 : 1}
									Transparency={isEquipped ? 0.1 : isSelected ? 0.2 : 0.6}
								/>
								<frame Size={new UDim2(1, -16, 0, 16)} Position={UDim2.fromOffset(8, 8)} BackgroundTransparency={1}>
									<Text
										value={cardTier}
										size={11}
										color={cardAccent}
										weight={Enum.FontWeight.Heavy}
										align={Enum.TextXAlignment.Left}
									/>
									<Text
										value={isEquipped ? "ACTIVE" : isUnlocked ? "OWNED" : "LOCKED"}
										size={11}
										color={isEquipped ? Palette.mint : isUnlocked ? Palette.creamSoft : Palette.muted}
										weight={Enum.FontWeight.Heavy}
										align={Enum.TextXAlignment.Right}
									/>
								</frame>
								<frame Size={new UDim2(1, -16, 0, 36)} Position={UDim2.fromOffset(8, 28)} BackgroundTransparency={1}>
									<AnimatedTitlePreview
										text={item.Name}
										fx={fx}
										size={stack ? 14 : 16}
										preview={!isEquipped}
										reducedMotion={reducedMotion}
									/>
								</frame>
								<Text
									value={item.Description ?? "Cosmic title"}
									size={11}
									color={isUnlocked ? Palette.creamSoft : Palette.muted}
									align={Enum.TextXAlignment.Center}
									position={UDim2.fromOffset(8, 70)}
									sizeConstraint={new UDim2(1, -16, 0, 36)}
								/>
								<frame Size={new UDim2(1, -16, 0, 32)} Position={new UDim2(0, 8, 1, -38)} BackgroundTransparency={1}>
									<Button
										text={isEquipped ? "ACTIVE" : isUnlocked ? "EQUIP" : "PREVIEW"}
										onClick={() => {
											setSelectedTitleId(item.Id);
											if (isUnlocked && !isEquipped) {
												sendAction(`Equip_${item.Id}`, "EquipTitle", { Id: item.Id });
											}
										}}
										color={isEquipped ? Palette.mint : isUnlocked ? cardAccent : Palette.panelSoft}
										textColor={isEquipped ? Palette.ink : isUnlocked ? Palette.ink : Palette.cream}
										size={UDim2.fromScale(1, 1)}
										reducedMotion={reducedMotion}
									/>
								</frame>
							</frame>
						);
					})}
				</frame>
			</Panel>
				)}
		</TabPane>
	);

	// --------------------------------------------------------------------------------------------
	// TAB 3: EXPEDITIONS (FLEET OPERATIONS)
	// --------------------------------------------------------------------------------------------
	const expeditionsTab = (
		<TabPane tabKey="Expeditions" reducedMotion={reducedMotion}>
			{/* Active Flight Telemetry */}
			{activeId !== "" && (
				<Panel
					size={new UDim2(1, 0, 0, stack ? 140 : 120)}
					accent={Palette.violet}
					background={Palette.panelRaised}
					padding={14}
					layoutOrder={1}
					reducedMotion={reducedMotion}
				>
					<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
						<SectionLabel value="EXPEDITION TELEMETRY" color={Palette.violet} />
						<Text
							value={expeditionReady ? "MISSION COMPLETE  ·  READY FOR RECOVERY" : `ESTIMATED ARRIVAL: ${landsAt(activeEnds)} (${clockText(math.max(0, activeEnds - serverNow))} remaining)`}
							size={13}
							color={Palette.cream}
							weight={Enum.FontWeight.Heavy}
							position={UDim2.fromOffset(0, 20)} sizeConstraint={new UDim2(1, 0, 0, 19)}
							align={Enum.TextXAlignment.Left}
						/>
						<frame Size={new UDim2(1, 0, 0, 10)} Position={UDim2.fromOffset(0, 48)} BackgroundTransparency={1}>
							<Meter
								value={expeditionReady ? 1 : math.clamp((serverNow - activeStarted) / math.max(1, activeEnds - activeStarted), 0, 1)}
								color={Palette.violet}
								size={UDim2.fromScale(1, 1)}
								reducedMotion={reducedMotion}
							/>
						</frame>
						{expeditionReady && (
							<Button
								text="COLLECT SPOILS"
								icon="Collect"
								onClick={() => sendAction("ClaimExp", "ClaimExpedition", {})}
								color={Palette.mint}
								textColor={Palette.ink}
								size={new UDim2(1, 0, 0, 36)}
								position={new UDim2(0, 0, 1, -36)}
								loading={pendingKey === "ClaimExp"}
								reducedMotion={reducedMotion}
							/>
						)}
					</frame>
				</Panel>
			)}

			{/* Available Expeditions List */}
			<Panel
				size={new UDim2(1, 0, 0, 0)}
				autoHeight={true}
				accent={Palette.cyan}
				background={Palette.panel}
				padding={14}
				layoutOrder={2}
				reducedMotion={reducedMotion}
			>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 10)} />
				<SectionLabel value="ORBITAL MISSIONS" color={Palette.cyan} />
				{ops.Expeditions.map((mission, idx) => {
					const isLocked = command.Level < mission.RequiredLevel;
					const isRunning = activeId === mission.Id;
					return (
						<frame
							key={mission.Id}
							Size={new UDim2(1, 0, 0, stack ? 94 : 76)}
							BackgroundColor3={Palette.panelSoft}
							BackgroundTransparency={0.2}
							BorderSizePixel={0}
							LayoutOrder={idx + 1}
						>
							<uicorner CornerRadius={new UDim(0, Layout.buttonRadius)} />
							<uistroke Color={isLocked ? Palette.lineSoft : mission.Color ?? Palette.cyan} Thickness={1} Transparency={0.5} />
							<frame Size={new UDim2(1, -160, 1, 0)} Position={UDim2.fromOffset(14, 0)} BackgroundTransparency={1}>
								<Text
									value={mission.Name}
									size={14}
									color={isLocked ? Palette.muted : Palette.cream}
									weight={Enum.FontWeight.Heavy}
									align={Enum.TextXAlignment.Left}
									position={UDim2.fromOffset(0, 10)} sizeConstraint={new UDim2(1, 0, 0, 20)}
								/>
								<Text
									value={`Duration: ${clockText(mission.Duration)}  ·  Relic Chance: ${math.floor(mission.ArtifactChance * 100)}%`}
									size={11}
									color={Palette.muted}
									align={Enum.TextXAlignment.Left}
									position={UDim2.fromOffset(0, 32)} sizeConstraint={new UDim2(1, 0, 0, 17)}
								/>
								<Text
									value={formatReward(mission.Reward)}
									size={11}
									color={Palette.mint}
									align={Enum.TextXAlignment.Left}
									position={UDim2.fromOffset(0, stack ? 66 : 48)} sizeConstraint={new UDim2(1, 0, 0, 17)}
								/>
							</frame>
							<frame Size={UDim2.fromOffset(130, 36)} Position={new UDim2(1, -144, 0.5, -18)} BackgroundTransparency={1}>
								<Button
									text={isLocked ? `LVL ${mission.RequiredLevel}` : isRunning ? "IN FLIGHT" : activeId !== "" ? "BUSY" : "LAUNCH"}
									icon="World"
									onClick={() => {
										if (!isLocked && activeId === "") {
											sendAction(`Launch_${mission.Id}`, "LaunchExpedition", { Id: mission.Id });
										}
									}}
									color={isLocked || activeId !== "" ? Palette.panelRaised : Palette.cyan}
									textColor={isLocked || activeId !== "" ? Palette.muted : Palette.ink}
									size={UDim2.fromScale(1, 1)}
									loading={pendingKey === `Launch_${mission.Id}`}
									reducedMotion={reducedMotion}
								/>
							</frame>
						</frame>
					);
				})}
			</Panel>
		</TabPane>
	);

	// --------------------------------------------------------------------------------------------
	// TAB 4: ARTIFACTS (RELIQUARY)
	// --------------------------------------------------------------------------------------------
	const artifactsTab = (
		<TabPane tabKey="Artifacts" reducedMotion={reducedMotion}>
			<Panel
				size={new UDim2(1, 0, 0, 0)}
				autoHeight={true}
				accent={Palette.mango}
				background={Palette.panel}
				padding={14}
				layoutOrder={1}
				reducedMotion={reducedMotion}
			>
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1}>
					<uigridlayout
						CellSize={new UDim2(stack ? 1 : 0.5, -6, 0, 110)}
						CellPadding={UDim2.fromOffset(8, 8)}
						SortOrder={Enum.SortOrder.LayoutOrder}
					/>
					{ops.Artifacts.map((art, idx) => {
						const stateArt = command.Artifacts[art.Id];
						const level = stateArt?.Level ?? 0;
						const fragments = stateArt?.Fragments ?? 0;
						const isOwned = stateArt !== undefined;
						const isEquipped = command.EquippedArtifact === art.Id;

						return (
							<frame
								key={art.Id}
								BackgroundColor3={Palette.panelSoft}
								BackgroundTransparency={0.2}
								BorderSizePixel={0}
								LayoutOrder={idx + 1}
							>
								<uicorner CornerRadius={new UDim(0, Layout.buttonRadius)} />
								<uistroke Color={isEquipped ? Palette.mint : isOwned ? art.Color ?? Palette.mango : Palette.lineSoft} Thickness={1} Transparency={0.5} />
								<frame Size={UDim2.fromOffset(48, 48)} Position={UDim2.fromOffset(12, 12)} BackgroundTransparency={1}>
									<IconTile
										kind={artifactIcon(art.Id)}
										accent={art.Color ?? Palette.mango}
										size={UDim2.fromScale(1, 1)}
										reducedMotion={reducedMotion}
									/>
								</frame>
								<frame Size={new UDim2(1, -180, 1, 0)} Position={UDim2.fromOffset(68, 0)} BackgroundTransparency={1}>
									<Text
										value={art.Name}
										size={13}
										color={isOwned ? Palette.cream : Palette.muted}
										weight={Enum.FontWeight.Heavy}
										align={Enum.TextXAlignment.Left}
										position={UDim2.fromOffset(0, 10)} sizeConstraint={new UDim2(1, 0, 0, 19)}
									/>
									<Text
										value={isOwned ? artifactEffect(art, level) : "Not yet discovered"}
										size={11}
										color={Palette.creamSoft}
										align={Enum.TextXAlignment.Left}
										position={UDim2.fromOffset(0, 32)} sizeConstraint={new UDim2(1, 0, 0, 17)}
									/>
									<Text
										value={isOwned ? `RANK ${level}  ·  ${fragments} FRAGMENTS` : "Find on orbital expeditions"}
										size={11}
										color={Palette.muted}
										align={Enum.TextXAlignment.Left}
										position={UDim2.fromOffset(0, 54)} sizeConstraint={new UDim2(1, 0, 0, 17)}
									/>
								</frame>
								<frame Size={UDim2.fromOffset(100, 34)} Position={new UDim2(1, -112, 0.5, -17)} BackgroundTransparency={1}>
									{isOwned ? (
										<Button
											text={isEquipped ? "ACTIVE" : "EQUIP"}
											onClick={() => {
												if (!isEquipped) {
													sendAction(`Art_${art.Id}`, "EquipArtifact", { Id: art.Id });
												}
											}}
											color={isEquipped ? Palette.mint : Palette.panelRaised}
											textColor={isEquipped ? Palette.ink : Palette.cream}
											size={UDim2.fromScale(1, 1)}
											reducedMotion={reducedMotion}
										/>
									) : (
										<Badge filled={true} value="LOCKED" accent={Palette.panelRaised} size={UDim2.fromScale(1, 1)} />
									)}
								</frame>
							</frame>
						);
					})}
				</frame>
			</Panel>
		</TabPane>
	);

	// --------------------------------------------------------------------------------------------
	// TAB 5: SEASON TRACK (RANK TRACK)
	// --------------------------------------------------------------------------------------------
	const seasonTab = (
		<TabPane tabKey="Season" reducedMotion={reducedMotion}>
			<Panel
				size={new UDim2(1, 0, 0, stack ? 130 : 110)}
				accent={Palette.mango}
				background={Palette.panelRaised}
				padding={14}
				layoutOrder={1}
				reducedMotion={reducedMotion}
			>
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
					<SectionLabel value={ops.SeasonName ?? "GALACTIC SEASON DIRECTIVE"} color={Palette.mango} />
					<Text
						value={`SEASON XP: ${compactNumber(command.SeasonXP)}  ·  ${passOwned ? "SEASON PASS VIP ACTIVE" : "STANDARD TRACK"}`}
						size={13}
						color={Palette.cream}
						weight={Enum.FontWeight.Heavy}
						position={UDim2.fromOffset(0, 20)} sizeConstraint={new UDim2(1, 0, 0, 19)}
						align={Enum.TextXAlignment.Left}
					/>
					<frame Size={new UDim2(1, 0, 0, 10)} Position={UDim2.fromOffset(0, 48)} BackgroundTransparency={1}>
						<Meter value={seasonFill} color={Palette.mango} size={UDim2.fromScale(1, 1)} reducedMotion={reducedMotion} />
					</frame>
				</frame>
			</Panel>

			{/* Season Tier Reward Nodes */}
			<Panel
				size={new UDim2(1, 0, 0, 0)}
				autoHeight={true}
				accent={Palette.violet}
				background={Palette.panel}
				padding={14}
				layoutOrder={2}
				reducedMotion={reducedMotion}
			>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 8)} />
				<SectionLabel value="PROGRESSION TIERS" color={Palette.violet} />
				{ops.SeasonTiers.map((tier, idx) => {
					const isUnlocked = command.SeasonXP >= tier.RequiredXP;
					const isClaimed = command.SeasonClaims[tostring(tier.Tier)] === true;
					const canClaim = isUnlocked && !isClaimed;

					return (
						<frame
							key={`Tier_${tier.Tier}`}
							Size={new UDim2(1, 0, 0, 60)}
							BackgroundColor3={Palette.panelSoft}
							BackgroundTransparency={0.2}
							BorderSizePixel={0}
							LayoutOrder={idx + 1}
						>
							<uicorner CornerRadius={new UDim(0, Layout.buttonRadius)} />
							<uistroke Color={canClaim ? Palette.mango : Palette.lineSoft} Thickness={1} Transparency={0.5} />
							<frame Size={new UDim2(1, -140, 1, 0)} Position={UDim2.fromOffset(14, 0)} BackgroundTransparency={1}>
								<Text
									value={`TIER ${tier.Tier}  ·  ${DescribeGenerated.seasonTierName(tier.Tier)}`}
									size={12}
									color={Palette.cream}
									weight={Enum.FontWeight.Heavy}
									align={Enum.TextXAlignment.Left}
									position={UDim2.fromOffset(0, 10)} sizeConstraint={new UDim2(1, 0, 0, 18)}
								/>
								<Text
									value={formatReward(tier.Reward)}
									size={11}
									color={Palette.mint}
									align={Enum.TextXAlignment.Left}
									position={UDim2.fromOffset(0, 30)} sizeConstraint={new UDim2(1, 0, 0, 17)}
								/>
							</frame>
							<frame Size={UDim2.fromOffset(110, 34)} Position={new UDim2(1, -124, 0.5, -17)} BackgroundTransparency={1}>
								<Button
									text={isClaimed ? "CLAIMED" : canClaim ? "CLAIM" : `${compactNumber(tier.RequiredXP)} XP`}
									onClick={() => {
										if (canClaim) {
											sendAction(`Tier_${tier.Tier}`, "ClaimSeasonTier", { Tier: tier.Tier });
										}
									}}
									color={canClaim ? Palette.mango : Palette.panelRaised}
									textColor={canClaim ? Palette.ink : Palette.muted}
									size={UDim2.fromScale(1, 1)}
									loading={pendingKey === `Tier_${tier.Tier}`}
									reducedMotion={reducedMotion}
								/>
							</frame>
						</frame>
					);
				})}
			</Panel>
		</TabPane>
	);

	// --------------------------------------------------------------------------------------------
	// TAB 6: CREW QUARTERS
	// --------------------------------------------------------------------------------------------
	const crewTab = (
		<TabPane tabKey="Crew" reducedMotion={reducedMotion}>
			<Panel
				size={new UDim2(1, 0, 0, 0)}
				autoHeight={true}
				accent={Palette.cyan}
				background={Palette.panel}
				padding={14}
				layoutOrder={1}
				reducedMotion={reducedMotion}
			>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 10)} />
				<SectionLabel value="FLEET OFFICERS & STATIONS" color={Palette.cyan} />
				{CREW_ROLES.map((role, idx) => {
					const level = command.Crew[role] ?? 1;
					const conf = ops.Crew[role] ?? { Name: role, Color: Palette.cyan, BaseCost: 100, MaxLevel: 20 };
					const cost = crewCost(conf.BaseCost, level);
					const canUpgrade = level < conf.MaxLevel;

					return (
						<frame
							key={role}
							Size={new UDim2(1, 0, 0, 84)}
							BackgroundColor3={Palette.panelSoft}
							BackgroundTransparency={0.2}
							BorderSizePixel={0}
							LayoutOrder={idx + 1}
						>
							<uicorner CornerRadius={new UDim(0, Layout.buttonRadius)} />
							<uistroke Color={conf.Color ?? Palette.cyan} Thickness={1} Transparency={0.5} />
							<frame Size={new UDim2(1, -150, 1, 0)} Position={UDim2.fromOffset(14, 0)} BackgroundTransparency={1}>
								<Text
									value={`${conf.Name.upper()}  ·  RANK ${level}`}
									size={13}
									color={Palette.cream}
									weight={Enum.FontWeight.Heavy}
									align={Enum.TextXAlignment.Left}
									position={UDim2.fromOffset(0, 10)} sizeConstraint={new UDim2(1, 0, 0, 19)}
								/>
								<Text
									value={CREW_PERKS[role] ?? "Enhances fleet operations"}
									size={11}
									color={Palette.creamSoft}
									align={Enum.TextXAlignment.Left}
									position={UDim2.fromOffset(0, 32)} sizeConstraint={new UDim2(1, 0, 0, 17)}
								/>
								<Text
									value={canUpgrade ? `Promotion cost: ${cost} Signals` : "Max rank reached"}
									size={11}
									color={Palette.muted}
									align={Enum.TextXAlignment.Left}
									position={UDim2.fromOffset(0, 52)} sizeConstraint={new UDim2(1, 0, 0, 17)}
								/>
							</frame>
							<frame Size={UDim2.fromOffset(120, 36)} Position={new UDim2(1, -134, 0.5, -18)} BackgroundTransparency={1}>
								<Button
									text={canUpgrade ? "PROMOTE" : "MAXED"}
									icon="Crew"
									onClick={() => {
										if (canUpgrade) {
											sendAction(`Crew_${role}`, "UpgradeCrew", { Role: role });
										}
									}}
									color={canUpgrade ? Palette.cyan : Palette.panelRaised}
									textColor={canUpgrade ? Palette.ink : Palette.muted}
									size={UDim2.fromScale(1, 1)}
									loading={pendingKey === `Crew_${role}`}
									reducedMotion={reducedMotion}
								/>
							</frame>
						</frame>
					);
				})}
			</Panel>
		</TabPane>
	);

	return (
		<AutoPage accent={Palette.cyan} scrollRef={scrollRef}>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} BorderSizePixel={0}>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, Layout.panelGap)} />
				{tabRail}
				{tab === "Overview" && overviewTab}
				{tab === "Titles" && titlesTab}
				{tab === "Expeditions" && expeditionsTab}
				{tab === "Artifacts" && artifactsTab}
				{tab === "Season" && seasonTab}
				{tab === "Crew" && crewTab}
			</frame>
		</AutoPage>
	);
}

export default CommandView;

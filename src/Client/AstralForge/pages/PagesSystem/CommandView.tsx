import React from "@rbxts/react";
import { segmentedHeight } from "../../UiCore/ui";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { clockText, compactNumber, Flux, formatReward, gteFlux, Reward } from "../../CoreKit/format";
import { chromeFor, Layout, Palette, scrollTail, TapTarget } from "../../CoreKit/theme";
import { easeOutCubic, useBoatTween, useStagger, useViewport } from "../../MotionKit/motion";
import { BrowseApi, clientModule, kitMember, LuauComponent } from "../luauKits";
import { useServerClock } from "../../hooks/useServerClock";
import { ProfileStylePanel, profileStyleHeight } from "./ProfileStylePanel";

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
const { AutoGrid, VirtualGrid } = kitMember<{ AutoGrid: LuauComponent; VirtualGrid: LuauComponent }>("LayoutKit", "scrolling");
const { PageScaffold } = kitMember<{ PageScaffold: LuauComponent }>("LayoutKit", "pageScaffold");
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

interface Directive {
	Id: string;
	Name: string;
	Description?: string;
	Claimed?: boolean;
	Progress: number;
	Target: number;
	Reward?: Reward;
}
interface TitleEntry {
	Id: string;
	Name: string;
	Description?: string;
	Unlocked?: boolean;
	Equipped?: boolean;
	Fx?: string;
}
interface ShopOffer {
	Id: string;
	Name: string;
	Color: Color3;
	Price: number;
	Purchased?: boolean;
	Reward?: Reward;
}
interface CommandState {
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
	Shop: ShopOffer[];
	Crew: Record<string, number | undefined>;
	MachineMastery: Record<string, number | undefined>;
}
interface Expedition {
	Id: string;
	Name: string;
	Color: Color3;
	RequiredLevel: number;
	Duration: number;
	ArtifactChance: number;
	ArtifactId?: string;
	Reward?: Reward;
}
interface ArtifactDef {
	Id: string;
	Name: string;
	Rarity: string;
	Color: Color3;
	Element: unknown;
	EffectKind: string;
	EffectPerLevel: number;
}
interface SeasonTier {
	Tier: number;
	RequiredXP: number;
	Reward?: Reward;
}
interface Operations {
	Expeditions: Expedition[];
	Artifacts: ArtifactDef[];
	SeasonTiers: SeasonTier[];
	SeasonName?: string;
	TitlesEnabled?: boolean;
	TitleStatus?: string;
	MaxCommanderLevel: number;
	Crew: Record<string, { Name: string; Color: Color3; BaseCost: number; MaxLevel: number; Description?: string } | undefined>;
}
interface CommandProps {
	state: { Command?: CommandState; Stardust?: Flux; Cosmetics?: unknown; Rebirths?: unknown };
	config: { Operations?: Operations; Machines: Array<{ Id: string; Name: string; Color: Color3 }> };
	dispatch: (action: string, payload?: object, callback?: (response: { ok?: boolean; message?: string; ArtifactNew?: boolean }) => void) => unknown;
	reducedMotion?: boolean;
	onSectionChange?: () => void;
}

// The last trip this session, so the hero can offer it again once the crew is home.
let lastTripId: string | undefined;

/** "3:40 PM" in the player's own clock, for when a trip lands. */
function landsAt(unix: number): string {
	const [text] = string.gsub(os.date("%I:%M %p", math.floor(unix)), "^0", "");
	return text;
}

function gridPanelHeight(headerH: number, rows: number, cellH: number, gap: number, pad: number) {
	const safeRows = math.max(1, rows);
	const gridH = safeRows * cellH + math.max(0, safeRows - 1) * gap;
	return pad * 2 + headerH + gridH;
}
const TABS = ["Overview", "Expeditions", "Artifacts", "Season"];
const TITLE_FX_FALLBACKS = ["shimmer", "aurora", "pulse", "chrome", "wave", "glow"];
const TAB_LABEL: Record<string, string> = { Overview: "Overview", Expeditions: "Expeditions", Artifacts: "Artifacts", Season: "Rank Track" };
const TAB_OPTIONS = TABS.map((id) => ({ id, label: TAB_LABEL[id] }));
const CREW_ROLES = ["Pilot", "Engineer", "Navigator"];

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

function TabRail(props: { active: string; setActive: (tab: string) => void; reducedMotion?: boolean; stack: boolean; columns?: number }) {
	return (
		<SegmentedTabs
			options={TAB_OPTIONS}
			value={props.active}
			onChange={props.setActive}
			accent={Palette.cyan}
			columns={props.columns ?? TABS.size()}
			gap={4}
			size={UDim2.fromScale(1, 1)}
			reducedMotion={props.reducedMotion}
		/>
	);
}

function TabPane(props: { tabKey: string; reducedMotion?: boolean; children?: React.ReactNode }) {
	const reducedMotion = props.reducedMotion;
	const enter = useBoatTween(1, reducedMotion ? 0.01 : 0.2, reducedMotion, easeOutCubic, 0);
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
				Position={enter.map((a) => new UDim2(0, math.round((1 - math.clamp(a, 0, 1)) * 7), 0, 0))}
				BackgroundTransparency={1}
				BorderSizePixel={0}
			>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, Layout.panelGap)} />
				{props.children}
			</frame>
		</frame>
	);
}

interface TitleCardProps {
	id: string;
	name: string;
	description?: string;
	unlocked?: boolean;
	equipped?: boolean;
	fx: string;
	stack: boolean;
	reducedMotion?: boolean;
	dispatch: CommandProps["dispatch"];
}

const CommandTitleCard = React.memo((props: TitleCardProps) => {
	const accent = titleFxAccent(props.fx);
	const tierLabel = titleTier(props.fx).upper();
	const fxLabel = props.fx.gsub("-", " ")[0].upper();
	const effectName = `${tierLabel}  ${fxLabel}`;
	const equip = React.useCallback(() => props.dispatch("EquipTitle", { Id: props.id }), [props.dispatch, props.id]);
	const actionHeight = props.stack ? TapTarget : 34;
	const actionSize = new UDim2(1, -14, 0, actionHeight);
	const actionPosition = new UDim2(0, 7, 1, -(actionHeight + 7));
	const descText = props.description ?? "This is how the title looks in chat and on your nameplate.";
	return (
		<frame
			Size={UDim2.fromScale(1, 1)}
			BackgroundColor3={darkTitlePlate(props.fx)}
			BackgroundTransparency={props.equipped ? 0.06 : 0.28}
			BorderSizePixel={0}
			Active={false}
			ClipsDescendants={true}
		>
			<uicorner CornerRadius={new UDim(0, 14)} />
			<uistroke
				Color={props.equipped ? accent : props.unlocked ? accent : Palette.lineSoft}
				Thickness={props.equipped ? 1.8 : 1}
				Transparency={props.equipped ? 0.08 : props.unlocked ? 0.48 : 0.58}
			/>
			<frame Size={new UDim2(1, -16, 0, 16)} Position={UDim2.fromOffset(8, 6)} BackgroundTransparency={1} BorderSizePixel={0}>
				<frame
					Size={UDim2.fromOffset(6, 6)}
					Position={new UDim2(0, 2, 0.5, 0)}
					AnchorPoint={new Vector2(0, 0.5)}
					Rotation={45}
					BackgroundColor3={props.unlocked ? accent : Palette.muted}
					BorderSizePixel={0}
				/>
				<Text
					value={effectName}
					size={9}
					minSize={8}
					color={props.unlocked ? accent : Palette.muted}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					align={Enum.TextXAlignment.Left}
					position={UDim2.fromOffset(14, 1)}
					sizeConstraint={new UDim2(1, -68, 0, 14)}
				/>
				<Text
					value={props.equipped ? "ACTIVE" : props.unlocked ? "OWNED" : "LOCKED"}
					size={8}
					minSize={7}
					color={props.equipped ? Palette.mint : props.unlocked ? Palette.creamSoft : Palette.muted}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					align={Enum.TextXAlignment.Right}
					position={new UDim2(1, -52, 0, 1)}
					sizeConstraint={UDim2.fromOffset(52, 14)}
				/>
			</frame>
			<frame Size={new UDim2(1, -14, 0, 36)} Position={UDim2.fromOffset(7, 23)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
				<AnimatedTitlePreview
					text={props.name}
					fx={props.fx}
					size={props.stack ? 18 : 16}
					reducedMotion={props.reducedMotion}
					preview={!props.equipped}
					transparency={props.unlocked ? 0 : 0.42}
				/>
			</frame>
			<Text
				value={descText}
				size={10}
				color={props.unlocked ? Palette.creamSoft : Palette.muted}
				wrap={true}
				fit={true}
				minSize={9}
				align={Enum.TextXAlignment.Center}
				position={UDim2.fromOffset(9, 62)}
				sizeConstraint={new UDim2(1, -18, 0, 46)}
			/>
			{props.unlocked && !props.equipped ? (
				<Button
					text="EQUIP CREST"
					icon="Loadout.5"
					onClick={equip}
					color={accent}
					textColor={Palette.ink}
					size={actionSize}
					position={actionPosition}
					reducedMotion={props.reducedMotion}
				/>
			) : (
				<frame Size={actionSize} Position={actionPosition} BackgroundColor3={Palette.panelSoft} BorderSizePixel={0} Active={false}>
					<uicorner CornerRadius={new UDim(0, Layout.buttonRadius)} />
					<uistroke Color={props.equipped ? accent : Palette.lineSoft} Thickness={1} Transparency={0.52} />
					<Text
						value={props.equipped ? "EQUIPPED" : "LOCKED"}
						size={11}
						minSize={9}
						color={props.equipped ? accent : Palette.muted}
						weight={Enum.FontWeight.Heavy}
						fit={true}
						align={Enum.TextXAlignment.Center}
						sizeConstraint={UDim2.fromScale(1, 1)}
					/>
				</frame>
			)}
		</frame>
	);
});

// true once the running trip's EndsAt has passed. Flips with one timer at landing instead of a
// once-a-second clock, so the whole Command page re-renders once per trip, not once per second.
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

// the only part of the trip card that reads the clock: re-renders just what `render` returns,
// once a second while `ticking`; otherwise it renders once with the current time
function TripClock(props: { ticking: boolean; render: (now: number) => React.Element }) {
	const now = useServerClock(props.ticking);
	return props.render(props.ticking ? now : game.GetService("Workspace").GetServerTimeNow());
}

// weekly jobs roll over with the server's UTC week (UtcClockMath.Week)
const WEEK_SECONDS = 7 * 24 * 60 * 60;
function weeklyResetText(now: number): string {
	const left = math.max(0, (math.floor(now / WEEK_SECONDS) + 1) * WEEK_SECONDS - now);
	const days = math.floor(left / 86400);
	const hours = math.floor((left % 86400) / 3600);
	if (days > 0) {
		return `New jobs in ${days}d ${hours}h`;
	}
	const minutes = math.max(1, math.floor((left % 3600) / 60));
	return hours > 0 ? `New jobs in ${hours}h ${minutes}m` : `New jobs in ${minutes}m`;
}

function CommandViewReady(props: CommandProps) {
	const { state, config, dispatch, onSectionChange } = props;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const softMotion = props.reducedMotion;
	const reducedMotion = softMotion;
	const overviewReveal = useStagger(0, softMotion);
	const expeditionsReveal = useStagger(1, softMotion);
	const opsReveal = useStagger(2, softMotion);
	const commandSoft =
		softMotion || overviewReveal === undefined || expeditionsReveal === undefined || opsReveal === undefined;
	const claimHostRef = React.useRef<Frame>();
	const [contentWidth, setContentWidth] = React.useState(360);
	const stack = chrome.contentStack || contentWidth < 760;
	const ops = config.Operations!;
	const command = state.Command!;
	const [tab, setTab] = React.useState("Overview");
	const scrollRef = React.useRef<ScrollingFrame>();
	React.useEffect(() => {
		const host = scrollRef.current;
		if (!host) {
			return undefined;
		}
		const measure = () => {
			if (host.AbsoluteSize.X > 0) {
				setContentWidth(host.AbsoluteSize.X);
			}
		};
		measure();
		const connection = host.GetPropertyChangedSignal("AbsoluteSize").Connect(measure);
		return () => connection.Disconnect();
	}, []);
	React.useEffect(() => {
		const frame = scrollRef.current;
		if (frame) {
			frame.CanvasPosition = new Vector2(0, 0);
		}
	}, [tab]);
	const expeditionBrowse = Browse.useBrowse<Expedition>({
		id: "Expeditions",
		items: ops.Expeditions ?? [],
		text: (expedition) => [expedition.Name, formatReward(expedition.Reward), `level ${expedition.RequiredLevel}`],
		categories: [
			{ id: "All", label: "All" },
			{ id: "Available", label: "Available", test: (expedition) => command.Level >= expedition.RequiredLevel },
			{ id: "Locked", label: "Locked", test: (expedition) => command.Level < expedition.RequiredLevel },
		],
		sorts: [
			{ id: "Level", label: "By level" },
			{ id: "Shortest", label: "Shortest trip", compare: (a, b) => (tonumber(a.Duration) ?? 0) < (tonumber(b.Duration) ?? 0) },
			{ id: "Relic", label: "Best relic odds", compare: (a, b) => (tonumber(a.ArtifactChance) ?? 0) > (tonumber(b.ArtifactChance) ?? 0) },
		],
	});
	const expeditionList = expeditionBrowse.results;
	const titlesEnabled = ops.TitlesEnabled !== false;
	const maxed = command.Level >= ops.MaxCommanderLevel;
	const levelProgress = maxed
		? 1
		: meterFill(command.XP - command.LevelFloorXP, math.max(1, command.NextLevelXP - command.LevelFloorXP));
	const nextClaim = command.ClaimableCommanderLevels[0] as number | undefined;
	const active = command.ActiveExpedition;
	const activeId = active?.Id ?? "";
	const activeEnds = active?.EndsAt ?? 0;
	const activeStarted = active?.StartedAt ?? 0;
	// the page itself only needs to know when the trip lands (one re-render, at landing); the
	// per-second countdown text, meter and button label each tick inside a small TripClock
	const expeditionReady = useTripLanded(activeId !== "", activeEnds);
	const tripTicking = tab === "Expeditions" && activeId !== "" && !expeditionReady;
	const tripProgress = (now: number) =>
		activeId === "" ? 0 : math.clamp((now - activeStarted) / math.max(1, activeEnds - activeStarted), 0, 1);
	if (activeId !== "") {
		lastTripId = activeId;
	}
	const [tripReport, setTripReport] = React.useState<{ name: string; haul: string; found: boolean } | undefined>(undefined);
	// purchases and claims: the pressed button spins until the server answers, a refusal shakes it,
	// and nothing else can be sent meanwhile (no double buys or double claims)
	const [pendingKey, setPendingKey] = React.useState<string | undefined>(undefined);
	const [refusal, setRefusal] = React.useState<{ key: string; token: number }>({ key: "", token: 0 });
	const sendPending = (key: string, action: string, payload: object) => {
		if (pendingKey !== undefined) {
			return;
		}
		setPendingKey(key);
		// never leave the spinner up if the answer is lost
		const fallback = task.delay(8, () => setPendingKey(undefined));
		dispatch(action, payload, (response) => {
			pcall(task.cancel, fallback);
			setPendingKey(undefined);
			if (response.ok !== true) {
				setRefusal((current) => ({ key, token: current.token + 1 }));
			}
		});
	};
	const pendingProps = (key: string) => ({
		loading: pendingKey === key,
		shakeToken: refusal.key === key ? refusal.token : 0,
	});
	const repeatTrip = activeId === "" && lastTripId !== undefined ? ops.Expeditions.find((item) => item.Id === lastTripId) : undefined;
	const canRepeat = repeatTrip !== undefined && command.Level >= repeatTrip.RequiredLevel;
	const statusLine =
		activeId === ""
			? tripReport !== undefined
				? `${tripReport.name} came back with ${tripReport.haul}.`
				: "Launch an unlocked adventure below."
			: expeditionReady
				? "Crew is back. Collect their rewards."
				: undefined;
	const tripStatusAt = (now: number) => `Back in ${clockText(math.max(0, activeEnds - now))}, around ${landsAt(activeEnds)}`;
	const claimLabel =
		activeId === ""
			? canRepeat
				? "SEND AGAIN"
				: "Choose below"
			: expeditionReady
				? "COLLECT"
				: undefined;
	const tripLabelAt = (now: number) => clockText(math.max(0, activeEnds - now));
	const collectTrip = () => {
		const name = ops.Expeditions.find((item) => item.Id === activeId)?.Name ?? "Your crew";
		dispatch("ClaimExpedition", {}, (response) => {
			if (response.ok === true) {
				const haul = response.message !== undefined && response.message !== "" ? response.message : "their rewards";
				setTripReport({ name, haul, found: response.ArtifactNew === true });
			}
		});
	};
	const onHeroAction = () => {
		if (activeId === "" && canRepeat && repeatTrip !== undefined) {
			setTripReport(undefined);
			dispatch("LaunchExpedition", { Id: repeatTrip.Id });
		} else {
			collectTrip();
		}
	};
	let firstReadyWeeklyId: string | undefined;
	if (typeIs(command.Weekly, "table")) {
		for (const directive of command.Weekly) {
			if (!directive.Claimed && directive.Progress >= directive.Target) {
				firstReadyWeeklyId = directive.Id;
				break;
			}
		}
	}
	let firstReadySeasonTier: number | undefined;
	const passOwned = command.SeasonPassOwned === true;
	const premiumClaims = typeIs(command.PremiumClaims, "table") ? command.PremiumClaims : {};
	if (typeIs(ops.SeasonTiers, "table") && typeIs(command.SeasonClaims, "table")) {
		for (const tier of ops.SeasonTiers) {
			const claimed = command.SeasonClaims[tostring(tier.Tier)] === true;
			const passClaimed = !passOwned || premiumClaims[tostring(tier.Tier)] === true;
			const unlocked = command.SeasonXP >= tier.RequiredXP;
			if (unlocked && (!claimed || !passClaimed)) {
				firstReadySeasonTier = tier.Tier;
				break;
			}
		}
	}
	const commandClaimReady =
		(tab === "Overview" && (nextClaim !== undefined || firstReadyWeeklyId !== undefined)) ||
		(tab === "Expeditions" && expeditionReady) ||
		(tab === "Season" && firstReadySeasonTier !== undefined);
	React.useEffect(() => {
		if (!commandClaimReady || !UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = claimHostRef.current;
		if (host === undefined) {
			return undefined;
		}
		const selectJob = task.defer(() => {
			if (host.Parent === undefined) {
				return;
			}
			GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, selectJob);
		};
	}, [tab, nextClaim, firstReadyWeeklyId, expeditionReady, firstReadySeasonTier, commandClaimReady]);
	const activeConfig = ops.Expeditions.find((item) => item.Id === activeId);
	const ownedArtifacts = ops.Artifacts.filter((artifact) => command.Artifacts[artifact.Id] !== undefined).size();
	const nextTier = ops.SeasonTiers.find((tier) => command.SeasonClaims[tostring(tier.Tier)] !== true);
	const seasonFill = nextTier ? meterFill(command.SeasonXP, math.max(1, nextTier.RequiredXP)) : 1;
	const seasonStatus = nextTier
		? command.SeasonXP >= nextTier.RequiredXP
			? `Gift ${nextTier.Tier} is ready`
			: `${compactNumber(nextTier.RequiredXP - command.SeasonXP)} XP to gift ${nextTier.Tier}`
		: "All season gifts claimed";
	const passStatus = passOwned
		? "Season Pass active: every tier pays out twice."
		: "The Season Pass in the Shop adds a second reward to every tier.";
	const panelPad = 14;
	const gridGap = 8;
	const heroH = stack ? 196 : 168;
	const crewCols = stack ? 1 : 3;
	const crewCellH = 136;
	const crewRows = math.max(1, math.ceil(CREW_ROLES.size() / crewCols));
	const crewH = gridPanelHeight(54, crewRows, crewCellH, gridGap, panelPad);
	const weeklyItemH = stack ? 148 : 92;
	const weeklyStride = stack ? 156 : 100;
	const weeklyCount = math.max(1, command.Weekly.size());
	const weeklyH = panelPad * 2 + 36 + (weeklyCount - 1) * weeklyStride + weeklyItemH;
	const titleCols = math.max(1, math.min(4, math.floor((contentWidth - panelPad * 2 + gridGap) / (210 + gridGap))));
	const titleCellH = 176;
	const titleRows = math.max(1, math.ceil(math.max(1, command.Titles.size()) / titleCols));
	// closed titles: the 152px badge sits beside the 18px "Title wardrobe" header (~140px) when there's
	// room, otherwise on its own line under it (narrow phones), and the panel grows by that line
	const CLOSED_BADGE_W = 152;
	const closedBadgeOwnLine = contentWidth - panelPad * 2 < 140 + CLOSED_BADGE_W + 12;
	const closedBadgeLine = closedBadgeOwnLine ? 26 + 8 : 0;
	const titlesH = titlesEnabled ? gridPanelHeight(52, titleRows, titleCellH, gridGap, panelPad) : 112 + closedBadgeLine;
	const styleH = profileStyleHeight(stack) + panelPad * 2;
	const shopCols = math.max(1, math.min(4, math.floor((contentWidth - panelPad * 2 + gridGap) / (190 + gridGap))));
	const shopCellH = 180;
	const shopRows = math.max(1, math.ceil(math.max(1, command.Shop.size()) / shopCols));
	const shopH = gridPanelHeight(36, shopRows, shopCellH, gridGap, panelPad);
	const masteryCols = math.max(1, math.min(3, math.floor((contentWidth - panelPad * 2 + gridGap) / (210 + gridGap))));
	const masteryCellH = 64;
	const masteryRows = math.max(1, math.ceil(math.max(1, config.Machines.size()) / masteryCols));
	const masteryH = gridPanelHeight(36, masteryRows, masteryCellH, gridGap, panelPad);
	// phones in landscape get the side-by-side trip rows: the stacked row (button underneath)
	// would fill most of a 360px-tall screen
	const tripStack = stack && !chrome.landscape;
	const expeditionHeroH = tripStack ? 188 : 140;
	const expeditionRowH = tripStack ? 168 : 132;
	const artifactHeroH = 110;
	// relic rows follow the trip rows: side by side on landscape phones
	const artifactRowH = tripStack ? 180 : 140;
	const seasonHeroH = 164;
	const seasonRowH = stack ? 184 : 144;
	const heroInfoWidth = stack ? -100 : -(114 + 210 + 14);
	let tabContent = 0;
	let listContent = 0;
	let tabHeroH = 0;
	if (tab === "Overview") {
		tabContent = heroH + crewH + weeklyH + titlesH + styleH + shopH + masteryH + Layout.panelGap * 6;
	} else if (tab === "Expeditions") {
		tabHeroH = expeditionHeroH;
		listContent = ops.Expeditions.size() * expeditionRowH + math.max(0, ops.Expeditions.size() - 1) * Layout.panelGap;
	} else if (tab === "Artifacts") {
		tabHeroH = artifactHeroH;
		listContent = ops.Artifacts.size() * artifactRowH + math.max(0, ops.Artifacts.size() - 1) * Layout.panelGap;
	} else {
		tabHeroH = seasonHeroH;
		listContent = ops.SeasonTiers.size() * seasonRowH + math.max(0, ops.SeasonTiers.size() - 1) * Layout.panelGap;
	}
	const headerH = 56;
	const tabColumns = math.max(1, math.min(TABS.size(), math.floor((contentWidth + 4) / 140)));
	const tabsH = segmentedHeight(TABS.size(), tabColumns, viewport, 48, 4);
	const commandTail = scrollTail(stack, chrome.bottomSafe, stack ? 72 : 48);
	const useFillList = tab !== "Overview";
	let order = 0;
	const nextOrder = () => {
		order += 1;
		return order;
	};
	const changeTab = (nextTab: string) => {
		if (nextTab === tab) {
			return undefined;
		}
		onSectionChange?.();
		setTab(nextTab);
	};
	const header = (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} Active={false}>
			<SectionLabel value="Season" color={Palette.cyan} />
			<Text
				value={ops.SeasonName ?? "Deep Space Command"}
				size={stack ? 24 : 28}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={false}
				position={UDim2.fromOffset(0, 22)}
				sizeConstraint={new UDim2(1, 0, 0, 32)}
			/>
		</frame>
	);
	const tabsRow = (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} Active={false}>
			<TabRail active={tab} setActive={changeTab} reducedMotion={reducedMotion || commandSoft} stack={stack} columns={tabColumns} />
		</frame>
	);

	let overviewPane: React.Element | false = false;
	if (tab === "Overview") {
		const crewCells = CREW_ROLES.map((roleId, index) => {
			const role = ops.Crew[roleId];
			if (!role) {
				return undefined;
			}
			const level = command.Crew[roleId] ?? 1;
			const cost = crewCost(role.BaseCost, level);
			const maxRole = level >= role.MaxLevel;
			const can = !maxRole && command.Signals >= cost;
			return (
				<frame key={roleId} BackgroundColor3={Palette.panelRaised} BorderSizePixel={0} LayoutOrder={index}>
					<uicorner CornerRadius={new UDim(0, 10)} />
					<uistroke Color={role.Color} Thickness={1} Transparency={0.4} />
					<Text
						value={role.Name}
						size={13}
						color={role.Color}
						weight={Enum.FontWeight.Heavy}
						fit={false}
						position={UDim2.fromOffset(10, 8)}
						sizeConstraint={new UDim2(1, -20, 0, 18)}
					/>
					<Text
						value={
							role.MaxLevel >= 1000000000
								? `Lv ${compactNumber(level)}`
								: `Lv ${compactNumber(level)} / ${compactNumber(role.MaxLevel)}`
						}
						size={11}
						color={Palette.creamSoft}
						fit={false}
						position={UDim2.fromOffset(10, 30)}
						sizeConstraint={new UDim2(1, -20, 0, 16)}
					/>
					{role.Description !== undefined ? (
						<Text
							value={role.Description}
							size={11}
							color={Palette.muted}
							wrap={true}
							fit={true}
							minSize={9}
							position={UDim2.fromOffset(10, 50)}
							sizeConstraint={new UDim2(1, -20, 0, 30)}
						/>
					) : undefined}
					<Button
						text={maxRole ? "MAX" : `Train · ${compactNumber(cost)} signals`}
						onClick={() => dispatch("UpgradeCrew", { Role: roleId })}
						color={role.Color}
						textColor={Palette.ink}
						size={new UDim2(1, -20, 0, stack ? TapTarget : 36)}
						position={new UDim2(0, 10, 1, -(stack ? TapTarget + 8 : 44))}
						disabled={!can}
						reducedMotion={softMotion}
						highlight={can}
					/>
				</frame>
			);
		});
		const weeklyGrid = (
			<VirtualGrid
				scrollRef={scrollRef}
				count={command.Weekly.size()}
				columns={1}
				cellHeight={weeklyItemH}
				gap={weeklyStride - weeklyItemH}
				overscanRows={softMotion ? 0 : 1}
				position={UDim2.fromOffset(0, 36)}
				itemKey={(index: number) => {
					const directive = command.Weekly[index] as Directive | undefined;
					return directive !== undefined ? directive.Id : `weekly-${index}`;
				}}
				renderItem={(index: number) => {
					const directive = command.Weekly[index] as Directive | undefined;
					if (directive === undefined) {
						return undefined;
					}
					const ready = !directive.Claimed && directive.Progress >= directive.Target;
					const rewardLine = formatReward(directive.Reward);
					const claimRef = ready && nextClaim === undefined && directive.Id === firstReadyWeeklyId ? claimHostRef : undefined;
					const claimButton = (
						<Button
							text={directive.Claimed ? "DONE" : ready ? "CLAIM" : "NOT YET"}
							onClick={() => sendPending(`weekly:${directive.Id}`, "ClaimWeeklyDirective", { Id: directive.Id })}
							{...pendingProps(`weekly:${directive.Id}`)}
							color={Palette.green}
							textColor={Palette.ink}
							size={UDim2.fromScale(1, 1)}
							disabled={directive.Claimed || !ready}
							reducedMotion={reducedMotion}
							highlight={ready}
						/>
					);
					return (
						<frame Size={new UDim2(1, 0, 0, weeklyItemH)} BackgroundColor3={Palette.ink} BorderSizePixel={0}>
							<uicorner CornerRadius={new UDim(0, 10)} />
							<uistroke Color={ready ? Palette.green : Palette.lineSoft} Thickness={1} Transparency={0.45} />
							<Text
								value={directive.Name}
								size={13}
								color={ready ? Palette.green : Palette.cream}
								weight={Enum.FontWeight.Heavy}
								fit={false}
								position={UDim2.fromOffset(12, 8)}
								sizeConstraint={new UDim2(1, stack ? -24 : -156, 0, 18)}
							/>
							<Text
								value={directive.Description ?? ""}
								size={11}
								color={Palette.muted}
								fit={false}
								position={UDim2.fromOffset(12, 28)}
								sizeConstraint={new UDim2(1, stack ? -24 : -156, 0, 16)}
							/>
							<Text
								value={rewardLine !== "" ? rewardLine : `${compactNumber(directive.Progress)} / ${compactNumber(directive.Target)}`}
								size={10}
								color={Palette.creamSoft}
								wrap={true}
								fit={true}
								minSize={9}
								position={UDim2.fromOffset(12, 46)}
								sizeConstraint={new UDim2(1, stack ? -24 : -156, 0, 28)}
							/>
							<Meter
								value={meterFill(directive.Progress, directive.Target, directive.Claimed || ready)}
								color={Palette.green}
								reducedMotion={reducedMotion}
								position={UDim2.fromOffset(12, stack ? 78 : 76)}
								size={new UDim2(1, stack ? -24 : -156, 0, 7)}
							/>
							<frame
								key="CommandClaimActions"
								Size={stack ? new UDim2(1, -24, 0, TapTarget) : UDim2.fromOffset(140, 44)}
								Position={stack ? new UDim2(0, 12, 1, -(TapTarget + 8)) : new UDim2(1, -150, 0.5, -22)}
								BackgroundTransparency={1}
								BorderSizePixel={0}
								ClipsDescendants={false}
								ref={claimRef}
							>
								{claimButton}
							</frame>
						</frame>
					);
				}}
			/>
		);
		const titlesBody = titlesEnabled ? (
			<>
				<Text
					value="Each title shows as it looks on you."
					size={11}
					color={Palette.muted}
					fit={false}
					position={UDim2.fromOffset(0, 26)}
					sizeConstraint={new UDim2(1, 0, 0, 18)}
				/>
				<VirtualGrid
					scrollRef={scrollRef}
					count={command.Titles.size()}
					columns={titleCols}
					cellHeight={titleCellH}
					gap={gridGap}
					overscanRows={1}
					position={UDim2.fromOffset(0, 52)}
					itemKey={(index: number) => {
						const title = command.Titles[index] as TitleEntry | undefined;
						return title !== undefined ? title.Id : `title-${index}`;
					}}
					renderItem={(index: number) => {
						const title = command.Titles[index] as TitleEntry | undefined;
						if (title === undefined) {
							return undefined;
						}
						const titleFx = title.Fx ?? TITLE_FX_FALLBACKS[index % TITLE_FX_FALLBACKS.size()];
						return (
							<CommandTitleCard
								id={title.Id}
								name={title.Name}
								description={title.Description}
								unlocked={title.Unlocked}
								equipped={title.Equipped}
								fx={titleFx}
								stack={stack}
								reducedMotion={reducedMotion}
								dispatch={dispatch}
							/>
						);
					}}
				/>
			</>
		) : (
			<>
				<Badge
					value="TEMPORARILY CLOSED"
					accent={Palette.muted}
					size={UDim2.fromOffset(CLOSED_BADGE_W, 26)}
					position={closedBadgeOwnLine ? UDim2.fromOffset(0, 30) : new UDim2(1, -CLOSED_BADGE_W, 0, 0)}
				/>
				<Text
					value={ops.TitleStatus ?? "Titles are temporarily unavailable."}
					size={12}
					color={Palette.muted}
					wrap={true}
					fit={true}
					minSize={10}
					position={UDim2.fromOffset(0, 36 + closedBadgeLine)}
					sizeConstraint={new UDim2(1, 0, 0, 44)}
				/>
			</>
		);
		overviewPane = (
			<TabPane tabKey="Overview" reducedMotion={reducedMotion}>
				<Panel
					size={new UDim2(1, 0, 0, heroH)}
					accent={Palette.cyan}
					background={Palette.panelRaised}
					padding={16}
					layoutOrder={nextOrder()}
					reducedMotion={softMotion}
				>
					<frame Size={UDim2.fromOffset(stack ? 72 : 96, stack ? 72 : 96)} BackgroundColor3={Palette.ink} BorderSizePixel={0}>
						<uicorner CornerRadius={new UDim(0, 14)} />
						<uistroke Color={Palette.cyan} Thickness={2} Transparency={0.25} />
						<Text
							value={"%02d".format(command.Level)}
							size={stack ? 28 : 36}
							color={Palette.cyan}
							weight={Enum.FontWeight.Heavy}
							fit={false}
							align={Enum.TextXAlignment.Center}
							sizeConstraint={new UDim2(1, 0, 0.7, 0)}
						/>
						<Text
							value="LVL"
							size={11}
							color={Palette.muted}
							weight={Enum.FontWeight.Bold}
							fit={false}
							align={Enum.TextXAlignment.Center}
							position={UDim2.fromScale(0, 0.68)}
							sizeConstraint={new UDim2(1, 0, 0.28, 0)}
						/>
					</frame>
					<Text
						value={command.Rank ?? "Commander"}
						size={stack ? 18 : 22}
						color={Palette.cream}
						weight={Enum.FontWeight.Heavy}
						fit={true}
						minSize={13}
						position={UDim2.fromOffset(stack ? 88 : 114, 4)}
						sizeConstraint={new UDim2(1, heroInfoWidth, 0, 28)}
					/>
					<Text
						value={maxed ? "Top rank" : `${compactNumber(math.max(0, command.NextLevelXP - command.XP))} XP to next`}
						size={12}
						color={Palette.muted}
						fit={false}
						position={UDim2.fromOffset(stack ? 88 : 114, 36)}
						sizeConstraint={new UDim2(1, heroInfoWidth, 0, 18)}
					/>
					<Meter
						value={levelProgress}
						color={Palette.cyan}
						reducedMotion={softMotion}
						position={UDim2.fromOffset(stack ? 88 : 114, 60)}
						size={new UDim2(1, heroInfoWidth, 0, 8)}
					/>
					<Text
						value={`${compactNumber(command.Signals)} signals  ·  ${compactNumber(command.ExpeditionsCompleted)} ${
							command.ExpeditionsCompleted === 1 ? "trip" : "trips"
						}  ·  ${compactNumber(command.StreakShields)} ${command.StreakShields === 1 ? "shield" : "shields"}`}
						size={12}
						color={Palette.creamSoft}
						fit={true}
						minSize={10}
						wrap={true}
						position={UDim2.fromOffset(0, stack ? 90 : 112)}
						sizeConstraint={new UDim2(1, 0, 0, stack ? 34 : 18)}
					/>
					<frame
						key="CommandClaimActions"
						Size={stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(210, 46)}
						Position={stack ? new UDim2(0, 0, 1, -(TapTarget + 8)) : new UDim2(1, -210, 0, 16)}
						BackgroundTransparency={1}
						BorderSizePixel={0}
						ClipsDescendants={false}
						ref={nextClaim !== undefined ? claimHostRef : undefined}
					>
						<Button
							text={nextClaim !== undefined ? `Claim level ${nextClaim}` : "Rank gifts complete"}
							icon="Gift.15"
							onClick={() => {
								if (nextClaim !== undefined) {
									sendPending("commander", "ClaimCommanderReward", { Level: nextClaim });
								}
							}}
							color={Palette.cyan}
							textColor={Palette.ink}
							size={UDim2.fromScale(1, 1)}
							disabled={nextClaim === undefined}
							{...pendingProps("commander")}
							reducedMotion={softMotion}
							highlight={nextClaim !== undefined}
						/>
					</frame>
				</Panel>
				<Panel size={new UDim2(1, 0, 0, crewH)} accent={Palette.mango} background={Palette.panel} padding={panelPad} layoutOrder={nextOrder()} reducedMotion={reducedMotion}>
					<Text value="Officers" size={18} color={Palette.cream} weight={Enum.FontWeight.Heavy} fit={false} sizeConstraint={new UDim2(1, 0, 0, 24)} />
					<Text
						value="Train officers with signals."
						size={12}
						color={Palette.muted}
						fit={true}
						minSize={10}
						position={UDim2.fromOffset(0, 28)}
						sizeConstraint={new UDim2(1, 0, 0, 18)}
					/>
					<frame
						Size={new UDim2(1, 0, 0, crewRows * crewCellH + math.max(0, crewRows - 1) * gridGap)}
						Position={UDim2.fromOffset(0, 54)}
						BackgroundTransparency={1}
						BorderSizePixel={0}
						Active={false}
					>
						<AutoGrid columns={crewCols} cellHeight={crewCellH} rowGap={gridGap} columnGap={gridGap} />
						{crewCells}
					</frame>
				</Panel>
				<Panel
					size={new UDim2(1, 0, 0, weeklyH)}
					accent={Palette.green}
					background={Palette.panel}
					padding={14}
					layoutOrder={nextOrder()}
					reducedMotion={reducedMotion}
					clips={false}
				>
					<Text value="Weekly jobs" size={18} color={Palette.cream} weight={Enum.FontWeight.Heavy} fit={false} sizeConstraint={new UDim2(1, 0, 0, 24)} />
					<Text
						value={weeklyResetText(game.GetService("Workspace").GetServerTimeNow())}
						size={12}
						color={Palette.muted}
						fit={false}
						align={Enum.TextXAlignment.Right}
						position={UDim2.fromOffset(0, 4)}
						sizeConstraint={new UDim2(1, 0, 0, 18)}
					/>
					{weeklyGrid}
				</Panel>
				<Panel
					size={new UDim2(1, 0, 0, titlesH)}
					accent={titlesEnabled ? Palette.violet : Palette.muted}
					background={Palette.panel}
					padding={panelPad}
					layoutOrder={nextOrder()}
					reducedMotion={reducedMotion}
				>
					<Text value="Title wardrobe" size={18} color={Palette.cream} weight={Enum.FontWeight.Heavy} fit={true} minSize={12} sizeConstraint={new UDim2(1, titlesEnabled || closedBadgeOwnLine ? 0 : -(CLOSED_BADGE_W + 12), 0, 24)} />
					{titlesBody}
				</Panel>
				<Panel
					size={new UDim2(1, 0, 0, styleH)}
					accent={Palette.cyan}
					background={Palette.panel}
					padding={panelPad}
					layoutOrder={nextOrder()}
					reducedMotion={reducedMotion}
				>
					<Text value="Profile style" size={18} color={Palette.cream} weight={Enum.FontWeight.Heavy} fit={false} sizeConstraint={new UDim2(1, 0, 0, 24)} />
					<ProfileStylePanel
						cosmetics={state.Cosmetics}
						rebirths={state.Rebirths}
						dispatch={dispatch}
						stack={stack}
						reducedMotion={reducedMotion}
					/>
				</Panel>
				<Panel size={new UDim2(1, 0, 0, shopH)} accent={Palette.mango} background={Palette.panel} padding={panelPad} layoutOrder={nextOrder()} reducedMotion={reducedMotion}>
					<Text
						value={`Signal shop · ${compactNumber(command.Signals)} ready`}
						size={18}
						color={Palette.cream}
						weight={Enum.FontWeight.Heavy}
						fit={false}
						sizeConstraint={new UDim2(1, 0, 0, 24)}
					/>
					<VirtualGrid
						scrollRef={scrollRef}
						count={command.Shop.size()}
						columns={shopCols}
						cellHeight={shopCellH}
						gap={gridGap}
						position={UDim2.fromOffset(0, 36)}
						itemKey={(index: number) => {
							const offer = command.Shop[index] as ShopOffer | undefined;
							return offer !== undefined ? offer.Id : `shop-${index}`;
						}}
						renderItem={(index: number) => {
							const offer = command.Shop[index] as ShopOffer | undefined;
							if (offer === undefined) {
								return undefined;
							}
							const can = !offer.Purchased && command.Signals >= offer.Price;
							return (
								<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.ink} BorderSizePixel={0} Active={false}>
									<uicorner CornerRadius={new UDim(0, 10)} />
									<uistroke Color={offer.Color} Thickness={1} Transparency={0.35} />
									<Text
										value={offer.Name}
										size={12}
										color={offer.Color}
										weight={Enum.FontWeight.Heavy}
										fit={true}
										minSize={9}
										position={UDim2.fromOffset(8, 8)}
										sizeConstraint={new UDim2(1, -16, 0, 20)}
									/>
									<Text
										value={formatReward(offer.Reward)}
										fit={true}
										minSize={10}
										size={11}
										color={Palette.creamSoft}
										wrap={true}
										position={UDim2.fromOffset(8, 34)}
										sizeConstraint={new UDim2(1, -16, 0, 40)}
									/>
									<Button
										text={offer.Purchased ? "BOUGHT" : `${offer.Price} Signals`}
										onClick={() => sendPending(`signal:${offer.Id}`, "BuySignalOffer", { Id: offer.Id })}
										{...pendingProps(`signal:${offer.Id}`)}
										color={offer.Color}
										textColor={Palette.ink}
										size={new UDim2(1, -16, 0, stack ? TapTarget : 40)}
										position={new UDim2(0, 8, 1, -(stack ? TapTarget + 8 : 48))}
										disabled={!can}
										reducedMotion={reducedMotion}
										highlight={can}
									/>
								</frame>
							);
						}}
					/>
				</Panel>
				<Panel size={new UDim2(1, 0, 0, masteryH)} accent={Palette.blue} background={Palette.panel} padding={panelPad} layoutOrder={nextOrder()} reducedMotion={reducedMotion}>
					<Text value="Machine mastery" size={18} color={Palette.cream} weight={Enum.FontWeight.Heavy} fit={true} minSize={14} sizeConstraint={new UDim2(1, 0, 0, 24)} />
					<VirtualGrid
						scrollRef={scrollRef}
						count={config.Machines.size()}
						columns={masteryCols}
						cellHeight={masteryCellH}
						gap={gridGap}
						position={UDim2.fromOffset(0, 36)}
						itemKey={(index: number) => {
							const machine = config.Machines[index] as { Id: string } | undefined;
							return machine !== undefined ? machine.Id : `machine-${index}`;
						}}
						renderItem={(index: number) => {
							const machine = config.Machines[index] as { Id: string; Name: string; Color: Color3 } | undefined;
							if (machine === undefined) {
								return undefined;
							}
							const mastery = command.MachineMastery[machine.Id] ?? 0;
							const rank = math.floor(math.sqrt(mastery));
							const nextRank = math.pow(rank + 1, 2);
							const fill = rank >= 99 ? 1 : (mastery - rank * rank) / math.max(1, nextRank - rank * rank);
							return (
								<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.ink} BorderSizePixel={0} Active={false}>
									<uicorner CornerRadius={new UDim(0, 10)} />
									<Text
										value={machine.Name}
										size={12}
										color={Palette.cream}
										weight={Enum.FontWeight.Bold}
										fit={true}
										minSize={9}
										position={UDim2.fromOffset(8, 6)}
										sizeConstraint={new UDim2(1, -70, 0, 18)}
									/>
									<Badge value={`RANK ${rank}`} accent={machine.Color} filled={true} position={new UDim2(1, -58, 0, 6)} size={UDim2.fromOffset(48, 20)} />
									<Meter value={fill} color={machine.Color} reducedMotion={reducedMotion} position={UDim2.fromOffset(8, 34)} size={new UDim2(1, -16, 0, 6)} />
									<Text
										value={`${compactNumber(mastery)} built`}
										size={10}
										color={Palette.muted}
										fit={true}
										minSize={9}
										position={UDim2.fromOffset(8, 44)}
										sizeConstraint={new UDim2(1, -16, 0, 14)}
									/>
								</frame>
							);
						}}
					/>
				</Panel>
			</TabPane>
		);
	}

	let expeditionsPane: React.Element | false = false;
	if (tab === "Expeditions") {
		expeditionsPane = (
			<TabPane tabKey="Expeditions" reducedMotion={reducedMotion}>
				<Panel
					size={new UDim2(1, 0, 0, expeditionHeroH)}
					accent={expeditionReady ? Palette.green : Palette.cyan}
					background={Palette.panelRaised}
					padding={14}
					layoutOrder={nextOrder()}
					reducedMotion={reducedMotion}
				>
					<Text value={activeId === "" && tripReport !== undefined ? `"${DescribeGenerated.tripLine(command.ExpeditionsCompleted, tripReport.found)}"` : "Active trip"} size={12} color={Palette.muted} weight={Enum.FontWeight.Bold} fit={true} minSize={9} sizeConstraint={new UDim2(1, 0, 0, 16)} />
					<Text
						value={activeConfig?.Name ?? (canRepeat ? `Last trip: ${repeatTrip!.Name}` : "No trip underway")}
						size={tripStack ? 18 : 22}
						color={expeditionReady ? Palette.green : Palette.cream}
						weight={Enum.FontWeight.Heavy}
						fit={false}
						position={UDim2.fromOffset(0, 22)}
						sizeConstraint={new UDim2(1, tripStack ? 0 : -230, 0, 28)}
					/>
					<TripClock
						ticking={tripTicking}
						render={(now) => (
							<Text
								value={statusLine ?? tripStatusAt(now)}
								size={12}
								color={activeId === "" && tripReport !== undefined ? Palette.creamSoft : Palette.muted}
								fit={true}
								minSize={10}
								position={UDim2.fromOffset(0, 54)}
								sizeConstraint={new UDim2(1, tripStack ? 0 : -230, 0, 18)}
							/>
						)}
					/>
					<TripClock
						ticking={tripTicking}
						render={(now) => (
							<Meter
								value={expeditionReady ? 1 : tripProgress(now)}
								color={expeditionReady ? Palette.green : Palette.cyan}
								reducedMotion={reducedMotion}
								position={UDim2.fromOffset(0, 80)}
								size={new UDim2(1, tripStack ? 0 : -230, 0, 8)}
							/>
						)}
					/>
					<frame
						key="CommandClaimActions"
						Size={tripStack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(210, 48)}
						Position={tripStack ? new UDim2(0, 0, 1, -(TapTarget + 8)) : new UDim2(1, -210, 0.5, -24)}
						BackgroundTransparency={1}
						BorderSizePixel={0}
						ClipsDescendants={false}
						ref={expeditionReady ? claimHostRef : undefined}
					>
						<TripClock
							ticking={tripTicking}
							render={(now) => (
								<Button
									text={claimLabel ?? tripLabelAt(now)}
									icon={activeId === "" && canRepeat ? "Refresh.3" : "Gift.16"}
									onClick={onHeroAction}
									color={activeId === "" && canRepeat ? repeatTrip!.Color : Palette.green}
									textColor={Palette.ink}
									size={UDim2.fromScale(1, 1)}
									disabled={!expeditionReady && !(activeId === "" && canRepeat)}
									reducedMotion={reducedMotion}
									highlight={expeditionReady}
								/>
							)}
						/>
					</frame>
				</Panel>
				<Browse.BrowseBar
					browse={expeditionBrowse}
					placeholder="Search adventures by name or reward"
					accent={Palette.cyan}
					stack={stack}
					reducedMotion={softMotion}
					layoutOrder={nextOrder()}
					zIndex={30}
				/>
				{expeditionList.size() === 0 && (
					<Browse.NoResults
						browse={expeditionBrowse}
						noun="adventures"
						icon="World.7"
						accent={Palette.cyan}
						reducedMotion={softMotion}
						layoutOrder={nextOrder()}
					/>
				)}
				<VirtualGrid
					scrollRef={scrollRef}
					count={expeditionList.size()}
					columns={1}
					cellHeight={expeditionRowH}
					gap={Layout.panelGap}
					overscanRows={softMotion ? 0 : 1}
					layoutOrder={nextOrder()}
					itemKey={(index: number) => {
						const expedition = expeditionList[index] as Expedition | undefined;
						return expedition !== undefined ? expedition.Id : `expedition-${index}`;
					}}
					renderItem={(index: number) => {
						const expedition = expeditionList[index] as Expedition | undefined;
						if (expedition === undefined) {
							return undefined;
						}
						const locked = command.Level < expedition.RequiredLevel;
						const busy = activeId !== "";
						const can = !locked && !busy;
						const pilot = command.Crew.Pilot ?? 1;
						return (
							<Panel
								size={new UDim2(1, 0, 0, expeditionRowH)}
								accent={expedition.Color}
								background={Palette.panel}
								padding={14}
								interactive={true}
								highlight={can}
								reducedMotion={reducedMotion}
							>
								<IconTile
									kind={artifactIcon(expedition.ArtifactId ?? expedition.Id)}
									accent={expedition.Color}
									size={46}
									radius={14}
									position={UDim2.fromOffset(0, tripStack ? 6 : 18)}
									reducedMotion={reducedMotion}
								/>
								<Text
									value={`Lv ${expedition.RequiredLevel}  ·  ${clockText(
										math.max(10, math.floor(expedition.Duration * math.max(0.35, 1 - (pilot - 1) * 0.05))),
									)}`}
									size={11}
									color={expedition.Color}
									weight={Enum.FontWeight.Bold}
									fit={true}
									minSize={9}
									position={UDim2.fromOffset(58, 4)}
									sizeConstraint={new UDim2(1, tripStack ? -70 : -224, 0, 16)}
								/>
								<Text
									value={expedition.Name}
									size={17}
									color={Palette.cream}
									weight={Enum.FontWeight.Heavy}
									fit={true}
									minSize={12}
									position={UDim2.fromOffset(58, 24)}
									sizeConstraint={new UDim2(1, tripStack ? -70 : -224, 0, 24)}
								/>
								<Text
									value={`${formatReward(expedition.Reward)}  ·  ${"%.0f".format(expedition.ArtifactChance * 100)}% relic`}
									size={11}
									color={Palette.muted}
									wrap={true}
									fit={true}
									minSize={9}
									position={UDim2.fromOffset(58, 52)}
									sizeConstraint={new UDim2(1, tripStack ? -70 : -224, 0, 28)}
								/>
								<Button
									text={locked ? `Need lv ${expedition.RequiredLevel}` : busy ? "Crew away" : "LAUNCH"}
									onClick={() => dispatch("LaunchExpedition", { Id: expedition.Id })}
									color={expedition.Color}
									textColor={Palette.ink}
									size={tripStack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(200, 46)}
									position={tripStack ? new UDim2(0, 0, 1, -(TapTarget + 8)) : new UDim2(1, -210, 0.5, -23)}
									disabled={!can}
									reducedMotion={reducedMotion}
									highlight={can}
								/>
							</Panel>
						);
					}}
				/>
			</TabPane>
		);
	}

	const artifactsPane = tab === "Artifacts" && (
		<TabPane tabKey="Artifacts" reducedMotion={reducedMotion}>
			<Panel
				size={new UDim2(1, 0, 0, artifactHeroH)}
				accent={Palette.violet}
				background={Palette.panelRaised}
				padding={14}
				layoutOrder={nextOrder()}
				reducedMotion={reducedMotion}
			>
				<Text
					value={`Relics  ${ownedArtifacts}/${ops.Artifacts.size()}`}
					size={20}
					color={Palette.cream}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					minSize={14}
					sizeConstraint={new UDim2(1, 0, 0, 28)}
				/>
				<Text
					value="Equip one relic. Duplicates add spark fragments for upgrades."
					size={12}
					color={Palette.muted}
					fit={true}
					minSize={9}
					position={UDim2.fromOffset(0, 34)}
					sizeConstraint={new UDim2(1, 0, 0, 20)}
				/>
				<Meter
					value={ownedArtifacts / math.max(1, ops.Artifacts.size())}
					color={Palette.violet}
					reducedMotion={reducedMotion}
					position={UDim2.fromOffset(0, 68)}
					size={new UDim2(1, 0, 0, 8)}
				/>
			</Panel>
			<VirtualGrid
				scrollRef={scrollRef}
				count={ops.Artifacts.size()}
				columns={1}
				cellHeight={artifactRowH}
				gap={Layout.panelGap}
				layoutOrder={nextOrder()}
				itemKey={(index: number) => {
					const artifact = ops.Artifacts[index] as ArtifactDef | undefined;
					return artifact !== undefined ? artifact.Id : `artifact-${index}`;
				}}
				renderItem={(index: number) => {
					const artifact = ops.Artifacts[index] as ArtifactDef | undefined;
					if (artifact === undefined) {
						return undefined;
					}
					const owned = command.Artifacts[artifact.Id];
					const equipped = command.EquippedArtifact === artifact.Id;
					const fragmentCost = owned ? 4 + owned.Level * 2 : 0;
					const dustCost = owned ? 8 * owned.Level : 0;
					const canUpgrade =
						owned !== undefined && owned.Level < 10 && owned.Fragments >= fragmentCost && gteFlux(state.Stardust as Flux, dustCost);
					return (
						<Panel
							size={new UDim2(1, 0, 0, artifactRowH)}
							accent={owned ? artifact.Color : Palette.lineSoft}
							background={owned ? Palette.panel : Palette.panelSoft}
							padding={14}
							reducedMotion={reducedMotion}
						>
							<frame
								key="ElementTile"
								Size={UDim2.fromOffset(48, 48)}
								Position={UDim2.fromOffset(0, tripStack ? 5 : 17)}
								BackgroundColor3={Palette.void}
								BackgroundTransparency={0.15}
								BorderSizePixel={0}
								ClipsDescendants={true}
							>
								<uicorner CornerRadius={new UDim(0, 14)} />
								<uistroke
									Color={owned ? (elementSheet(artifact.Element) ?? { Color: artifact.Color }).Color : Palette.lineSoft}
									Transparency={equipped ? 0 : 0.45}
									Thickness={equipped ? 2 : 1}
								/>
								<ElementFx
									element={artifact.Element}
									size={UDim2.fromOffset(48, 48)}
									position={UDim2.fromScale(0.5, 0.5)}
									// undiscovered relics show a dim still of their element
									still={!owned}
									transparency={owned ? 0 : 0.7}
									reducedMotion={reducedMotion}
									// discovering the relic reveals its companion
									reaction="reveal"
									reactionKey={owned !== undefined}
								/>
							</frame>
							<Text
								value={
									owned
										? `${artifact.Rarity}  ·  ${(elementSheet(artifact.Element) ?? { Label: "" }).Label}  ·  Lv ${owned.Level}/10`
										: artifact.Rarity
								}
								size={11}
								color={owned ? artifact.Color : Palette.muted}
								weight={Enum.FontWeight.Bold}
								fit={true}
								minSize={9}
								position={UDim2.fromOffset(58, 4)}
								sizeConstraint={new UDim2(1, tripStack ? -70 : -286, 0, 16)}
							/>
							<Text
								value={owned ? artifact.Name : "Mystery relic"}
								size={17}
								color={Palette.cream}
								weight={Enum.FontWeight.Heavy}
								fit={true}
								minSize={12}
								position={UDim2.fromOffset(58, 24)}
								sizeConstraint={new UDim2(1, tripStack ? -70 : -286, 0, 24)}
							/>
							<Text
								value={
									owned
										? `${artifactEffect(artifact, owned.Level)}  ·  ${owned.Fragments}/${fragmentCost} sparks`
										: "Finish its expedition to discover it."
								}
								size={11}
								color={Palette.muted}
								fit={true}
								minSize={9}
								position={UDim2.fromOffset(58, 52)}
								sizeConstraint={new UDim2(1, tripStack ? -70 : -286, 0, 18)}
							/>
							<frame
								Size={tripStack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(260, 46)}
								Position={tripStack ? new UDim2(0, 0, 1, -(TapTarget + 8)) : new UDim2(1, -270, 0.5, -23)}
								BackgroundTransparency={1}
								BorderSizePixel={0}
							>
								<Button
									text={equipped ? "IN USE" : "EQUIP"}
									onClick={() => dispatch("EquipArtifact", { Id: artifact.Id })}
									color={artifact.Color}
									textColor={Palette.ink}
									size={new UDim2(0.5, -4, 1, 0)}
									disabled={!owned || equipped}
									reducedMotion={reducedMotion}
								/>
								<Button
									text={!owned ? "—" : owned.Level >= 10 ? "MAX" : `${dustCost} dust`}
									onClick={() => dispatch("UpgradeArtifact", { Id: artifact.Id })}
									color={Palette.mango}
									textColor={Palette.ink}
									size={new UDim2(0.5, -4, 1, 0)}
									position={new UDim2(0.5, 4, 0, 0)}
									disabled={!canUpgrade}
									reducedMotion={reducedMotion}
									highlight={canUpgrade}
								/>
							</frame>
						</Panel>
					);
				}}
			/>
		</TabPane>
	);

	const seasonPane = tab === "Season" && (
		<TabPane tabKey="Season" reducedMotion={reducedMotion}>
			<Panel
				size={new UDim2(1, 0, 0, seasonHeroH)}
				accent={Palette.mango}
				background={Palette.panelRaised}
				padding={20}
				layoutOrder={nextOrder()}
				reducedMotion={reducedMotion}
			>
				<Text value={ops.SeasonName} size={22} color={Palette.mango} weight={Enum.FontWeight.Heavy} fit={false} sizeConstraint={new UDim2(1, 0, 0, 28)} />
				<Text
					value={compactNumber(command.SeasonXP)}
					size={14}
					color={Palette.muted}
					fit={false}
					position={UDim2.fromOffset(0, 36)}
					sizeConstraint={new UDim2(1, 0, 0, 18)}
				/>
				<Meter value={seasonFill} color={Palette.mango} reducedMotion={reducedMotion} position={UDim2.fromOffset(0, 64)} size={new UDim2(1, 0, 0, 9)} />
				<Text
					value={seasonStatus}
					size={12}
					color={Palette.creamSoft}
					fit={false}
					position={UDim2.fromOffset(0, 82)}
					sizeConstraint={new UDim2(1, 0, 0, 18)}
				/>
				<Text
					value={passStatus}
					size={12}
					color={passOwned ? Palette.mango : Palette.muted}
					fit={true}
					minSize={10}
					position={UDim2.fromOffset(0, 104)}
					sizeConstraint={new UDim2(1, 0, 0, 18)}
				/>
			</Panel>
			<VirtualGrid
				scrollRef={scrollRef}
				count={ops.SeasonTiers.size()}
				columns={1}
				cellHeight={seasonRowH}
				gap={Layout.panelGap}
				overscanRows={softMotion ? 0 : 1}
				layoutOrder={nextOrder()}
				itemKey={(index: number) => {
					const tier = ops.SeasonTiers[index] as SeasonTier | undefined;
					return tier !== undefined ? tostring(tier.Tier) : `tier-${index}`;
				}}
				renderItem={(index: number) => {
					const tier = ops.SeasonTiers[index] as SeasonTier | undefined;
					if (tier === undefined) {
						return undefined;
					}
					const unlocked = command.SeasonXP >= tier.RequiredXP;
					const claimed = command.SeasonClaims[tostring(tier.Tier)] === true;
					const major = tier.Tier % 5 === 0;
					const passClaimed = premiumClaims[tostring(tier.Tier)] === true;
					const passReady = passOwned && unlocked && !passClaimed;
					const claimRef = unlocked && (!claimed || passReady) && tier.Tier === firstReadySeasonTier ? claimHostRef : undefined;
					const passButton = (
						<Button
							text={passClaimed ? "Done" : !passOwned || unlocked ? "Pass" : "Locked"}
							onClick={() => sendPending(`pass:${tier.Tier}`, "ClaimSeasonPremium", { Tier: tier.Tier })}
							{...pendingProps(`pass:${tier.Tier}`)}
							color={Palette.mango}
							textColor={Palette.ink}
							size={UDim2.fromScale(1, 1)}
							disabled={!passReady}
							reducedMotion={reducedMotion}
							highlight={passReady}
						/>
					);
					const freeButton = (
						<Button
							text={claimed ? "Done" : unlocked ? "Open" : "Locked"}
							onClick={() => sendPending(`season:${tier.Tier}`, "ClaimSeasonTier", { Tier: tier.Tier })}
							{...pendingProps(`season:${tier.Tier}`)}
							color={major ? Palette.mango : Palette.green}
							textColor={Palette.ink}
							size={UDim2.fromScale(1, 1)}
							disabled={claimed || !unlocked}
							reducedMotion={reducedMotion}
							highlight={unlocked && !claimed}
						/>
					);
					const claimButton = (
						<>
							<frame Size={new UDim2(0.5, -4, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0}>
								{freeButton}
							</frame>
							<frame Size={new UDim2(0.5, -4, 1, 0)} Position={new UDim2(0.5, 4, 0, 0)} BackgroundTransparency={1} BorderSizePixel={0}>
								{passButton}
							</frame>
						</>
					);
					return (
						<Panel
							size={new UDim2(1, 0, 0, seasonRowH)}
							accent={major ? Palette.mango : unlocked ? Palette.green : Palette.lineSoft}
							background={major ? Palette.panelRaised : Palette.panel}
							padding={18}
							reducedMotion={reducedMotion}
						>
							<frame
								Size={UDim2.fromOffset(56, 56)}
								BackgroundColor3={claimed ? Palette.green : unlocked ? Palette.mango : Palette.panelSoft}
								BorderSizePixel={0}
							>
								<uicorner CornerRadius={new UDim(1, 0)} />
								<Text
									value={"%02d".format(tier.Tier)}
									size={20}
									color={claimed || unlocked ? Palette.ink : Palette.muted}
									weight={Enum.FontWeight.Heavy}
									fit={false}
									align={Enum.TextXAlignment.Center}
									sizeConstraint={UDim2.fromScale(1, 1)}
								/>
							</frame>
							<Text
								value={DescribeGenerated.seasonTierName(tier.Tier)}
								size={14}
								color={major ? Palette.mango : Palette.cream}
								weight={Enum.FontWeight.Heavy}
								fit={true}
								minSize={11}
								position={UDim2.fromOffset(72, 8)}
								sizeConstraint={new UDim2(1, stack ? -(72 + 24) : -250, 0, 20)}
							/>
							<Text
								value={formatReward(tier.Reward)}
								size={12}
								color={Palette.muted}
								wrap={true}
								fit={true}
								minSize={9}
								position={UDim2.fromOffset(72, 32)}
								sizeConstraint={new UDim2(1, stack ? -(72 + 24) : -250, 0, 28)}
							/>
							<Text
								value={formatReward(SeasonPremium.Reward(tier.Tier))}
								size={11}
								color={passOwned ? Palette.mango : Palette.muted}
								fit={true}
								minSize={9}
								position={UDim2.fromOffset(72, 62)}
								sizeConstraint={new UDim2(1, stack ? -(72 + 24) : -250, 0, 16)}
							/>
							<Meter
								value={meterFill(command.SeasonXP, tier.RequiredXP, claimed || unlocked)}
								color={major ? Palette.mango : Palette.green}
								reducedMotion={reducedMotion}
								position={UDim2.fromOffset(72, stack ? 86 : 100)}
								size={new UDim2(1, stack ? -84 : -250, 0, 7)}
							/>
							{stack ? (
								<frame
									key="CommandClaimActions"
									Size={new UDim2(1, -24, 0, TapTarget)}
									Position={new UDim2(0, 12, 1, -(TapTarget + 8))}
									BackgroundTransparency={1}
									BorderSizePixel={0}
									ClipsDescendants={false}
									ref={claimRef}
								>
									{claimButton}
								</frame>
							) : (
								<>
									<frame
										key="CommandClaimActions"
										Size={UDim2.fromOffset(236, 44)}
										Position={new UDim2(1, -244, 0.5, -22)}
										BackgroundTransparency={1}
										BorderSizePixel={0}
										ClipsDescendants={false}
										ref={claimRef}
									>
										{claimButton}
									</frame>
								</>
							)}
						</Panel>
					);
				}}
			/>
		</TabPane>
	);

	const bodyPane = (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} Active={false}>
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, Layout.panelGap)} />
			{overviewPane}
			{expeditionsPane}
			{artifactsPane}
			{seasonPane}
		</frame>
	);
	const bodyIntrinsic = useFillList ? tabHeroH + listContent + Layout.panelGap : tabContent;
	return (
		<PageScaffold
			hostRef={scrollRef}
			gap={Layout.panelGap}
			tailPad={commandTail}
			scrollBarColor={Palette.cyan}
			scrollBarThickness={4}
			sections={[
				{ id: "header", height: headerH, element: header },
				{ id: "tabs", height: tabsH, element: tabsRow },
				{ id: "body", fill: true, minHeight: 200, height: bodyIntrinsic, element: bodyPane },
			]}
		/>
	);
}

export function CommandView(props: CommandProps) {
	const { state, config } = props;
	const ops = config.Operations;
	const command = state.Command;
	const [tab] = React.useState("Overview");
	useServerClock(tab === "Expeditions");
	const scrollRef = React.useRef<ScrollingFrame>();
	React.useEffect(() => {
		const frame = scrollRef.current;
		if (frame) {
			frame.CanvasPosition = new Vector2(0, 0);
		}
	}, [tab]);
	if (!ops || !command) {
		return (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
				<Text value="Loading your crew…" size={16} color={Palette.muted} align={Enum.TextXAlignment.Center} sizeConstraint={UDim2.fromScale(1, 1)} />
			</frame>
		);
	}
	return <CommandViewReady {...props} />;
}

import React from "@rbxts/react";
import { AppHelpers } from "../CoreKit/appNav";
import { Flux, asFlux, compactNumber } from "../CoreKit/format";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import * as NavRouteTable from "../CoreKit/navRouteTable";
import { Layout, Palette, Radius, TapTarget, chromeFor, darken, ensureContrast, strokeGradient, surfaceGradient } from "../CoreKit/theme";
import * as VaultCollectEligibility from "../CoreKit/vaultCollectEligibility";
import {
	EntranceMotionSuppressedContext,
	ExitPresenceContext,
	composePresence,
	useExitPresence,
	useFlash,
	useTokenEntrance,
	useViewport,
} from "../MotionKit/motion";
import * as PageTransition from "../MotionKit/pageTransition";
import { featureNames, openRoadmap, progressFraction, readLevelState, tierAccent } from "./levelRoadmap";
import {
	Button,
	IconTile,
	LooseComponent,
	ScrollEdgeFade,
	ShimmerText,
	Text,
	meterFill,
	resolvePressMotion,
} from "./ui";

const h = React.createElement as unknown as (component: unknown, props?: object, ...children: unknown[]) => React.Element;

const UserInputService = game.GetService("UserInputService");
const ReplicatedStorage = game.GetService("ReplicatedStorage");

const AstralForge = script.Parent!.Parent!;
const loadKit = (name: string) => require(AstralForge.WaitForChild(name) as ModuleScript) as (member: string) => unknown;

const Icon = (loadKit("ArtKit")("Icon") as { Icon: LooseComponent }).Icon;

interface AudioApi {
	play(name: string): void;
}
const Audio = (loadKit("AudioKit")("audio") as { Audio: AudioApi }).Audio;

interface JuiceFxModule {
	useTarget(this: void, name: string): LuaTuple<[React.MutableRefObject<GuiObject | undefined>, React.Binding<number>]>;
}
const JuiceFx = require(AstralForge.WaitForChild("JuiceFx") as ModuleScript) as JuiceFxModule;

interface WorkspacePlan {
	headerHeight: number;
	unlockH: number;
}
interface LayoutSectionPlanApi {
	planWorkspace(this: void, input: {
		keyboardCompact: boolean;
		stack: boolean;
		landscape: boolean;
		workspaceHeaderH: number;
		layoutWorkspaceHeaderHeight: number;
		tapTarget: number;
		showNextGoal: boolean;
	}): WorkspacePlan;
}
const LayoutSectionPlan = loadKit("LayoutKit")("layoutSectionPlan") as LayoutSectionPlanApi;

const SharedData = require(
	ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("SharedData") as ModuleScript,
) as (name: string) => unknown;

interface LevelRewardsApi {
	eta(this: void, kind: unknown, remaining: number, rate: number): number | undefined;
	etaText(this: void, eta: number | undefined): string;
}

interface ChromeState {
	Settings?: { MobileCompactHeaders?: unknown; ShowNextGoal?: unknown; MotionIntensity?: unknown };
	Level?: unknown;
	Vault?: Flux;
	Capacity?: Flux;
	Production?: unknown;
	CurrentZone?: unknown;
	FeatureUnlocks?: unknown;
	[key: string]: unknown;
}

const PAGE_ORDER: Record<string, string[] | undefined> = {};
function pageOrderFor(phone: boolean): string[] {
	const key = phone ? "phone" : "rail";
	const cached = PAGE_ORDER[key];
	if (cached !== undefined) {
		return cached;
	}
	const order: string[] = [];
	const seen: Record<string, boolean> = {};
	const add = (id: string) => {
		if (!seen[id]) {
			seen[id] = true;
			order.push(id);
		}
	};
	if (phone) {
		for (const id of NavRouteTable.MOBILE_TAB_PRIORITY) {
			add(id);
		}
	}
	for (const group of NavRouteTable.NAV_GROUPS) {
		for (const id of group.routes) {
			add(id);
		}
	}
	for (const id of NavRouteTable.allNavIds()) {
		add(id);
	}
	PAGE_ORDER[key] = order;
	return order;
}

export function VaultPill(_param: { state: ChromeState; reducedMotion?: boolean; accent: Color3; top?: number }) {
	const state = _param.state;
	const reducedMotion = _param.reducedMotion;
	const accent = _param.accent;
	const top = _param.top ?? 8;
	const fill = meterFill(asFlux(state.Vault), asFlux(state.Capacity));
	const ready = VaultCollectEligibility.isEligible(asFlux(state.Vault));
	const full = VaultCollectEligibility.isFull(fill);
	const bar = full ? Palette.mango : accent;
	const [gains, setGains] = React.useState(0);
	const previousVault = React.useRef(state.Vault);
	const softMotion = reducedMotion;
	React.useEffect(() => {
		if (asFlux(state.Vault) > asFlux(previousVault.current)) {
			setGains((current) => current + 1);
		}
		previousVault.current = state.Vault;
	}, [state.Vault]);
	const vaultFlash = useFlash(gains, softMotion, 0.5);
	const [juiceRef, juiceBump] = JuiceFx.useTarget("VAULT");
	// (no per-second number over the header: the island's counters already roll up with income)
	const vaultTextColor = vaultFlash.map((amount) =>
		ensureContrast(Palette.panelRaised, ready ? Palette.cream : Palette.muted).Lerp(bar, amount * 0.7),
	);
	return h(
		"frame",
		{
			Size: UDim2.fromOffset(248, 52),
			Position: new UDim2(1, -316, 0, top),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			ZIndex: 22,
			ref: juiceRef,
		},
		h("uiscale", {
			Scale: juiceBump.map((b) => 1 + math.sin(b * math.pi) * 0.08),
		}),
		h(
			"frame",
			{
				Size: UDim2.fromScale(1, 1),
				BackgroundColor3: Palette.panelRaised,
				BorderSizePixel: 0,
				ClipsDescendants: true,
			},
			h("uicorner", {
				CornerRadius: new UDim(0, Radius.lg),
			}),
			h(
				"frame",
				{
					Size: new UDim2(1, -2, 1, -2),
					Position: UDim2.fromOffset(1, 1),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
				},
				h("uicorner", {
					CornerRadius: new UDim(0, Radius.lg),
				}),
				h("uistroke", {
					ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
					LineJoinMode: Enum.LineJoinMode.Round,
					Color: full ? Palette.mango : Palette.lineSoft,
					Thickness: 1,
					Transparency: full ? 0.35 : 0.72,
				}),
			),
			h(
				"frame",
				{
					Size: UDim2.fromOffset(32, 32),
					Position: UDim2.fromOffset(10, 10),
					BackgroundColor3: darken(bar, 0.62),
					BorderSizePixel: 0,
				},
				h("uicorner", {
					CornerRadius: new UDim(0, Radius.md),
				}),
				h(Icon, {
					kind: "Vault.8",
					color: Palette.cream,
					accent: bar,
					size: 18,
					spin: false,
					position: UDim2.fromScale(0.5, 0.5),
					anchorPoint: new Vector2(0.5, 0.5),
				}),
			),
			h(Text, {
				value: compactNumber(state.Vault),
				size: 15,
				color: vaultTextColor,
				weight: Enum.FontWeight.Heavy,
				fit: true,
				minSize: 12,
				position: UDim2.fromOffset(50, 7),
				sizeConstraint: new UDim2(1, -62, 0, 20),
			}),
			h(Text, {
				value: `of ${compactNumber(state.Capacity)}`,
				size: 11,
				color: ensureContrast(Palette.panelRaised, Palette.muted),
				weight: Enum.FontWeight.Bold,
				fit: true,
				minSize: 10,
				position: UDim2.fromOffset(50, 26),
				sizeConstraint: new UDim2(1, -62, 0, 14),
			}),
			h(
				"frame",
				{
					Size: new UDim2(1, -20, 0, 4),
					Position: new UDim2(0, 10, 1, -8),
					BackgroundColor3: Palette.line,
					BorderSizePixel: 0,
					ClipsDescendants: true,
				},
				h("uicorner", {
					CornerRadius: new UDim(1, 0),
				}),
				h(
					"frame",
					{
						Size: new UDim2(math.clamp(fill, 0.02, 1), 0, 1, 0),
						BackgroundColor3: bar,
						BorderSizePixel: 0,
					},
					h("uicorner", {
						CornerRadius: new UDim(1, 0),
					}),
				),
			),
		),
	);
}

export function NextUnlockStrip(_param: { state: ChromeState; reducedMotion?: boolean; onOpen?: () => void }) {
	const state = _param.state;
	const reducedMotion = _param.reducedMotion;
	const onOpen = _param.onOpen;
	const viewport = useViewport();
	const narrow = chromeFor(viewport).stack || viewport.width < 720;
	const [level, tier, nextStep] = readLevelState(state);
	const accent = tierAccent(tier);
	const fill = nextStep !== undefined ? progressFraction(nextStep) : 1;
	const [hovered, setHovered] = React.useState(false);
	const levelW = narrow ? 58 : 64;
	const tierW = narrow ? 0 : 92;
	const goalLeft = 14 + levelW + (narrow ? 8 : tierW + 14);
	let progressW = narrow ? 72 : 88;
	const nextNames = nextStep !== undefined ? featureNames(state, nextStep.Unlocks) : [];
	const nextText =
		nextStep === undefined
			? ""
			: nextNames.size() === 0
				? "Production bonus"
				: nextNames.size() === 1
					? `Opens ${nextNames[0]}`
					: `Opens ${nextNames[0]} +${nextNames.size() - 1}`;
	const nextW = narrow || nextText === "" ? 0 : 150;
	const LevelRewards = SharedData("LevelRewards") as LevelRewardsApi;
	const rate = tonumber(state.Production) ?? 0;
	const eta =
		nextStep !== undefined
			? LevelRewards.eta(nextStep.Kind, asFlux(nextStep.Target) - asFlux(nextStep.Progress), rate)
			: undefined;
	const etaText = LevelRewards.etaText(eta);
	if (etaText !== "") {
		progressW += 44;
	}
	return h(
		"imagebutton",
		{
			Size: new UDim2(1, 0, 0, 32),
			BackgroundColor3: Palette.night,
			BackgroundTransparency: 0,
			BorderSizePixel: 0,
			AutoButtonColor: false,
			Active: onOpen !== undefined,
			Selectable: onOpen !== undefined,
			ClipsDescendants: true,
			Event: {
				Activated: () => {
					if (onOpen !== undefined) {
						Audio.play("open");
						onOpen();
					}
				},
				MouseEnter: () => {
					setHovered(true);
				},
				MouseLeave: () => {
					setHovered(false);
				},
			},
		},
		h("frame", {
			Size: UDim2.fromScale(1, 1),
			BackgroundColor3: Palette.cream,
			BackgroundTransparency: hovered ? 0.96 : 1,
			BorderSizePixel: 0,
		}),
		h(Text, {
			value: "NEXT UNLOCK",
			size: 11,
			color: Palette.cream,
			weight: Enum.FontWeight.Heavy,
			fit: true,
			minSize: 10,
			position: UDim2.fromOffset(14, 0),
			sizeConstraint: new UDim2(0, levelW, 1, -3),
		}),
		!narrow &&
			h(Text, {
				value: "",
				size: 12,
				color: Palette.muted,
				weight: Enum.FontWeight.Bold,
				fit: true,
				minSize: 9,
				position: UDim2.fromOffset(14 + levelW + 4, 0),
				sizeConstraint: new UDim2(0, tierW, 1, -3),
			}),
		!narrow &&
			h("frame", {
				Size: UDim2.fromOffset(1, 12),
				Position: new UDim2(0, goalLeft - 8, 0.5, -7),
				BackgroundColor3: Palette.lineSoft,
				BorderSizePixel: 0,
			}),
		h(Text, {
			value: nextStep !== undefined ? nextStep.Text : "Every feature is open",
			size: 12,
			color: Palette.creamSoft,
			weight: Enum.FontWeight.Bold,
			fit: true,
			minSize: 9,
			position: UDim2.fromOffset(goalLeft, 0),
			sizeConstraint: new UDim2(1, -(goalLeft + progressW + nextW + 38), 1, -3),
		}),
		nextStep !== undefined &&
			h(Text, {
				value:
					`${compactNumber(nextStep.Progress)} / ${compactNumber(nextStep.Target)}` +
					(etaText !== "" ? `  ·  ~${etaText}` : ""),
				size: 12,
				color: Palette.muted,
				weight: Enum.FontWeight.Bold,
				align: Enum.TextXAlignment.Right,
				fit: true,
				minSize: 9,
				position: new UDim2(1, -(progressW + nextW + 30), 0, 0),
				sizeConstraint: new UDim2(0, progressW, 1, -3),
			}),
		nextW > 0 &&
			h(Text, {
				value: nextText,
				size: 11,
				color: Palette.muted,
				align: Enum.TextXAlignment.Right,
				fit: true,
				minSize: 9,
				position: new UDim2(1, -(nextW + 26), 0, 0),
				sizeConstraint: new UDim2(0, nextW, 1, -3),
			}),
		onOpen !== undefined &&
			h(Text, {
				value: "›",
				size: 16,
				color: hovered ? Palette.cream : Palette.muted,
				weight: Enum.FontWeight.Bold,
				align: Enum.TextXAlignment.Center,
				fit: false,
				position: new UDim2(1, -22, 0, -1),
				sizeConstraint: UDim2.fromOffset(14, 30),
			}),
		h(
			"frame",
			{
				Size: new UDim2(1, 0, 0, 2),
				Position: new UDim2(0, 0, 1, -2),
				BackgroundColor3: Palette.line,
				BorderSizePixel: 0,
			},
			h("frame", {
				Size: UDim2.fromScale(math.clamp(fill, 0, 1), 1),
				BackgroundColor3: accent,
				BorderSizePixel: 0,
			}),
			nextStep !== undefined &&
				h("frame", {
					Size: UDim2.fromOffset(2, 6),
					Position: new UDim2(0.5, 0, 1, 0),
					AnchorPoint: new Vector2(0.5, 1),
					BackgroundColor3: fill >= 0.5 ? accent : Palette.lineSoft,
					BorderSizePixel: 0,
				}),
		),
	);
}

interface MissionGoal {
	Name: string;
	Progress: number;
	Target: number;
}

// Once every unlock is done, the same bar points at the mission you're closest to finishing.
function closestMission(state: ChromeState): MissionGoal | undefined {
	const quests = state.Quests;
	if (!typeIs(quests, "table")) return undefined;
	let best: MissionGoal | undefined;
	let bestFrac = -1;
	for (const [, raw] of pairs(quests as object)) {
		if (!typeIs(raw, "table")) continue;
		const quest = raw as { Name?: unknown; Progress?: unknown; Target?: unknown; Claimed?: unknown };
		if (quest.Claimed === true || !typeIs(quest.Name, "string")) continue;
		const target = math.max(1, tonumber(quest.Target) ?? 1);
		const progress = tonumber(quest.Progress) ?? 0;
		const frac = math.clamp(progress / target, 0, 1);
		if (frac > bestFrac) {
			bestFrac = frac;
			best = { Name: quest.Name, Progress: progress, Target: target };
		}
	}
	return best;
}

function MissionGoalStrip(_param: { goal: MissionGoal; onOpen?: () => void }) {
	const goal = _param.goal;
	const onOpen = _param.onOpen;
	const [hovered, setHovered] = React.useState(false);
	const ready = goal.Progress >= goal.Target;
	const fill = math.clamp(goal.Progress / goal.Target, 0, 1);
	const progressW = 96;
	return h(
		"imagebutton",
		{
			Size: new UDim2(1, 0, 0, 32),
			BackgroundColor3: Palette.night,
			BackgroundTransparency: 0,
			BorderSizePixel: 0,
			AutoButtonColor: false,
			Active: onOpen !== undefined,
			Selectable: onOpen !== undefined,
			ClipsDescendants: true,
			Event: {
				Activated: () => {
					if (onOpen !== undefined) {
						Audio.play("open");
						onOpen();
					}
				},
				MouseEnter: () => setHovered(true),
				MouseLeave: () => setHovered(false),
			},
		},
		h("frame", {
			Size: UDim2.fromScale(1, 1),
			BackgroundColor3: Palette.cream,
			BackgroundTransparency: hovered ? 0.96 : 1,
			BorderSizePixel: 0,
		}),
		h(Text, {
			value: ready ? "READY" : "MISSION",
			size: 11,
			color: ready ? Palette.green : Palette.cyan,
			weight: Enum.FontWeight.Heavy,
			fit: true,
			minSize: 10,
			position: UDim2.fromOffset(14, 0),
			sizeConstraint: new UDim2(0, 64, 1, -3),
		}),
		h(Text, {
			value: ready ? `${goal.Name} is done. Claim it in Missions.` : goal.Name,
			size: 12,
			color: Palette.creamSoft,
			weight: Enum.FontWeight.Bold,
			fit: true,
			minSize: 9,
			position: UDim2.fromOffset(86, 0),
			sizeConstraint: new UDim2(1, -(86 + progressW + 38), 1, -3),
		}),
		h(Text, {
			value: `${compactNumber(goal.Progress)} / ${compactNumber(goal.Target)}`,
			size: 12,
			color: Palette.muted,
			weight: Enum.FontWeight.Bold,
			align: Enum.TextXAlignment.Right,
			fit: true,
			minSize: 9,
			position: new UDim2(1, -(progressW + 30), 0, 0),
			sizeConstraint: new UDim2(0, progressW, 1, -3),
		}),
		onOpen !== undefined &&
			h(Text, {
				value: "›",
				size: 16,
				color: hovered ? Palette.cream : Palette.muted,
				weight: Enum.FontWeight.Bold,
				align: Enum.TextXAlignment.Center,
				fit: false,
				position: new UDim2(1, -22, 0, -1),
				sizeConstraint: UDim2.fromOffset(14, 30),
			}),
		h(
			"frame",
			{
				Size: new UDim2(1, 0, 0, 2),
				Position: new UDim2(0, 0, 1, -2),
				BackgroundColor3: Palette.line,
				BorderSizePixel: 0,
			},
			h("frame", {
				Size: UDim2.fromScale(fill, 1),
				BackgroundColor3: ready ? Palette.green : Palette.cyan,
				BorderSizePixel: 0,
			}),
		),
	);
}

interface WorkspaceProps {
	page: string;
	state: ChromeState;
	dispatch: (action: string, payload?: object) => void;
	reducedMotion?: boolean;
	children?: React.ReactNode;
	navigate?: (page: string) => unknown;
}

export function Workspace(_param: WorkspaceProps) {
	const page = _param.page;
	const state = _param.state;
	const dispatch = _param.dispatch;
	const reducedMotion = _param.reducedMotion;
	const children = _param.children;
	const navigate = _param.navigate;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const softMotion = reducedMotion;
	const keyboardCompact = viewport.keyboardOpen;
	const mobileHeaderCompact = chrome.stack && (tonumber(state.Settings?.MobileCompactHeaders) ?? 1) >= 0.5;
	const accent = AppHelpers.pageAccent(page);
	const entry = AppHelpers.pageEntry(page);
	// the shell keeps its own motion on, but page swaps honour the player's Reduced Motion choice
	const pageMotionCalm =
		game.GetService("GuiService").ReducedMotionEnabled === true || (tonumber(state.Settings?.MotionIntensity) ?? 1) < 0.3;
	const animatedEnter = useTokenEntrance(page, reducedMotion, PageTransition.ENTER_SECONDS);
	const settledEnter = React.useMemo(() => React.createBinding(1)[0], []);
	const enter = pageMotionCalm ? settledEnter : animatedEnter;
	const pageTrack = React.useRef<{ page: string; direction: 1 | -1 }>();
	if (pageTrack.current === undefined) {
		pageTrack.current = { page: page, direction: 1 };
	} else if (pageTrack.current.page !== page) {
		pageTrack.current = { page: page, direction: PageTransition.direction(pageTrack.current.page, page, pageOrderFor(chrome.stack)) };
	}
	const pageDirection = pageTrack.current.direction;
	const shellPresence = useExitPresence();
	const pagePresence = React.useMemo(() => composePresence(shellPresence, enter), [shellPresence, enter]);
	const [entranceLock, setEntranceLock] = React.useState({
		page: page,
		suppress: false,
	});
	const suppressEntrance = entranceLock.page === page && entranceLock.suppress;
	React.useEffect(() => {
		let alive = true;
		setEntranceLock({
			page: page,
			suppress: false,
		});
		const job = task.delay(0.34, () => {
			if (!alive) {
				return undefined;
			}
			setEntranceLock({
				page: page,
				suppress: true,
			});
		});
		return () => {
			alive = false;
			pcall(() => task.cancel(job));
		};
	}, [page]);
	const inset = keyboardCompact ? 6 : chrome.stack ? chrome.contentInset : Layout.contentInset;
	let showNextGoal = true;
	let missionGoal: MissionGoal | undefined;
	{
		let setting = state.Settings?.ShowNextGoal;
		if (setting === undefined) {
			setting = 1;
		}
		showNextGoal = (setting as number) >= 0.5;
		if (typeIs(state.Level, "table") && (state.Level as { Next?: unknown }).Next === undefined) {
			// every feature is open: point at a mission instead, or hide the bar if there's none
			missionGoal = showNextGoal ? closestMission(state) : undefined;
			showNextGoal = missionGoal !== undefined;
		}
	}
	const workspacePlan = LayoutSectionPlan.planWorkspace({
		keyboardCompact: keyboardCompact,
		stack: chrome.stack,
		landscape: chrome.landscape,
		workspaceHeaderH: chrome.workspaceHeaderH,
		layoutWorkspaceHeaderHeight: Layout.workspaceHeaderHeight,
		tapTarget: TapTarget,
		showNextGoal: showNextGoal,
	});
	const headerHeight = workspacePlan.headerHeight;
	const unlockH = workspacePlan.unlockH;
	const stripOpen: (() => void) | undefined =
		missionGoal !== undefined ? (navigate !== undefined ? () => navigate("Missions") : undefined) : openRoadmap;
	// how far the strip's tap area may reach below it: up to TapTarget, never past the content inset
	const stripTapH = math.min(TapTarget, unlockH + inset);
	const vaultBtn = chrome.stack ? TapTarget : 44;
	const ready = VaultCollectEligibility.isEligible(asFlux(state.Vault));
	const vaultCollectHostRef = React.useRef<GuiObject>();
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = vaultCollectHostRef.current;
		if (host === undefined) {
			return undefined;
		}
		let alive = true;
		const selectJob = task.defer(() => {
			if (!alive || host.Parent === undefined) {
				return;
			}
			GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			alive = false;
			pcall(() => task.cancel(selectJob));
		};
	}, [ready, page]);
	const slideAxis = chrome.stack ? ("x" as const) : ("y" as const);
	const slideDistance = PageTransition.distance(chrome.stack, softMotion);
	const contentPosition = enter.map((amount) => {
		const [dx, dy] = PageTransition.offset(amount, pageDirection, slideAxis, slideDistance);
		return new UDim2(0, inset + dx, 0, headerHeight + unlockH + inset + dy);
	});
	const veilTransparency = enter.map(PageTransition.veilTransparency);
	const veilVisible = enter.map((amount) => PageTransition.veilTransparency(amount) < 0.995);
	const revealFade = enter.map((amount) => 1 - math.clamp(amount, 0, 1));
	const contentFade = enter.map((amount) => {
		const t = math.clamp(amount, 0, 1);
		return (1 - t) * 0.4;
	});
	const titleLeft = keyboardCompact ? 54 : chrome.stack ? 66 : 84;
	const titleReserve = keyboardCompact
		? -(titleLeft + vaultBtn + 18)
		: (chrome.stack ? -(vaultBtn + 18) : chrome.tight ? -(vaultBtn + 28) : -344) - (titleLeft - (chrome.stack ? 14 : 22));
	const denseHeader = !keyboardCompact && !chrome.landscape && !chrome.stack && headerHeight < 74;
	const titleBlockH = keyboardCompact ? 32 : chrome.landscape ? 28 : chrome.stack ? 36 : denseHeader ? 44 : 72;
	const headerIconSize = keyboardCompact ? 28 : chrome.landscape ? 28 : chrome.stack ? 32 : denseHeader ? 36 : 48;
	const headerTitleY = keyboardCompact ? 6 : chrome.landscape ? 10 : chrome.stack ? 12 : math.max(10, math.floor((headerHeight - titleBlockH) / 2));
	const vaultPillY = math.max(8, math.floor((headerHeight - 52) / 2));
	return h(
		"frame",
		{
			Size: UDim2.fromScale(1, 1),
			BackgroundColor3: Palette.ink,
			BorderSizePixel: 0,
			ZIndex: 5,
			ClipsDescendants: false,
		},
		h("uicorner", {
			CornerRadius: new UDim(0, 18),
		}),
		h(
			"uistroke",
			{
				ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
				LineJoinMode: Enum.LineJoinMode.Round,
				Color: Palette.lineSoft,
				Thickness: 1,
				Transparency: 0.86,
			},
			h("uigradient", {
				Rotation: 90,
				Color: strokeGradient(Palette.lineSoft),
			}),
		),
		h("frame", { Name: "BrassRule", Size: new UDim2(1, -6, 1, -6), Position: UDim2.fromOffset(3, 3), BackgroundTransparency: 1, BorderSizePixel: 0, Active: false, ZIndex: 21 }, h("uicorner", { CornerRadius: new UDim(0, 15) }), h("uistroke", { Color: Palette.brass, Thickness: 1, Transparency: 0.75 })),
		headerHeight > 0 &&
			h(
				"frame",
				{
					Size: new UDim2(1, 0, 0, headerHeight),
					BackgroundColor3: Palette.panel,
					BorderSizePixel: 0,
					ZIndex: 20,
					ClipsDescendants: false,
				},
				h("uicorner", {
					CornerRadius: new UDim(0, 18),
				}),
				h("uigradient", {
					Color: surfaceGradient(Palette.panel, 0.58),
					Rotation: 90,
				}),
				h("frame", {
					Size: new UDim2(1, 0, 0, 14),
					Position: new UDim2(0, 0, 1, -14),
					BackgroundColor3: darken(Palette.panel, 0.24),
					BorderSizePixel: 0,
				}),
				h(
					"frame",
					{
						Size: UDim2.fromOffset(headerIconSize, headerIconSize),
						Position: enter.map((amount) =>
							UDim2.fromOffset(
								(keyboardCompact ? 8 : chrome.stack ? 14 : 20) - math.round((1 - math.clamp(amount, 0, 1)) * 10),
								math.floor((headerHeight - headerIconSize) / 2),
							),
						),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						ClipsDescendants: true,
						ZIndex: 4,
					},
					h(IconTile, {
						kind: entry.icon,
						accent: accent,
						size: headerIconSize,
						radius: Radius.control + 1,
						spin: false,
						reducedMotion: reducedMotion,
						zIndex: 4,
					}),
				),
				h(
					"frame",
					{
						Size: new UDim2(1, titleReserve, 0, titleBlockH),
						Position: UDim2.fromOffset(titleLeft, headerTitleY),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						ClipsDescendants: false,
						ZIndex: 3,
					},
					h(ShimmerText, {
						value: entry.label === "Ranks" ? "Leaderboards" : entry.label,
						size: chrome.stack ? chrome.titleText : denseHeader ? 20 : 24,
						color: ensureContrast(Palette.panel, Palette.cream),
						weight: Enum.FontWeight.Bold,
						fit: false,
						minSize: 14,
						position: enter.map(
							(amount) => new UDim2(0, math.round((1 - math.clamp(amount, 0, 1)) * 6), 0, chrome.landscape ? 4 : 2),
						),
						sizeConstraint: new UDim2(1, 0, 0, chrome.landscape ? 26 : chrome.stack ? 24 : denseHeader ? 24 : 28),
						reducedMotion: reducedMotion,
						// page titles sit still; the sweeping glint read as decoration, not information
						enabled: false,
						periodSeconds: 4.2,
					}),
					// the info line only stays where it carries live numbers (Overview); elsewhere it
					// restated the page name, so the title stands alone
					page === "Overview" &&
						!keyboardCompact &&
						!mobileHeaderCompact &&
						!chrome.landscape &&
						h(Text, {
							value:
								page === "Overview"
									? `World ${state.CurrentZone}  /  ${compactNumber(state.Production)}/s`
									: entry.eyebrow,
							size: chrome.stack ? chrome.labelText : 14,
							color: ensureContrast(Palette.panel, accent),
							weight: Enum.FontWeight.Bold,
							wrap: true, fit: true, minSize: 10,
							position: enter.map(
								(amount) =>
									new UDim2(0, math.round((1 - math.clamp(amount, 0, 1)) * 10), 0, chrome.stack ? 28 : denseHeader ? 28 : 32),
							),
							sizeConstraint: new UDim2(1, 0, 0, chrome.stack ? 32 : denseHeader ? 16 : 28),
							transparency: revealFade,
						}),
				),
				!chrome.stack &&
					h(VaultPill, {
						state: state,
						reducedMotion: reducedMotion,
						accent: accent,
						top: vaultPillY,
					}),
				h(
					"frame",
					{
						Name: "VaultCollectClaim",
						ref: vaultCollectHostRef,
						Size: UDim2.fromOffset(vaultBtn, vaultBtn),
						Position: new UDim2(1, -(vaultBtn + 14), 0, math.floor((headerHeight - vaultBtn) / 2)),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						ZIndex: 22,
						ClipsDescendants: false,
					},
					h(Button, {
						text: "",
						icon: "Collect.1",
						onClick: () => dispatch("CollectVault"),
						color: ready ? accent : Palette.panelSoft,
						textColor: ready ? Palette.ink : Palette.muted,
						size: UDim2.fromScale(1, 1),
						disabled: !ready,
						reducedMotion: reducedMotion,
						motion: resolvePressMotion({
							text: "",
							icon: "Collect.2",
							size: UDim2.fromOffset(vaultBtn, vaultBtn),
						}),
						highlight: asFlux(state.Vault) >= asFlux(state.Capacity) * VaultCollectEligibility.NEAR_FULL,
						zIndex: 22,
					}),
				),
			),
		unlockH > 0 &&
			h(
				"frame",
				{
					Name: "LevelBarTarget",
					// tall enough to hold the tap reach below the strip; content still starts at unlockH
					Size: new UDim2(1, 0, 0, math.max(unlockH, stripTapH)),
					Position: UDim2.fromOffset(0, headerHeight),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ZIndex: 19,
				},
				// the strip is drawn 32px tall; this invisible catch area just under it makes the tap
				// target 44px by reaching into the content inset (never into the content). It starts where
				// the strip ends so the two buttons don't overlap.
				stripOpen !== undefined &&
					stripTapH > unlockH &&
					h("textbutton", {
						Name: "StripTapArea",
						Size: new UDim2(1, 0, 0, stripTapH - unlockH),
						Position: UDim2.fromOffset(0, unlockH),
						BackgroundTransparency: 1,
						Text: "",
						AutoButtonColor: false,
						Selectable: false,
						ZIndex: 0,
						Event: {
							Activated: () => {
								Audio.play("open");
								stripOpen();
							},
						},
					}),
				missionGoal !== undefined
					? h(MissionGoalStrip, {
							goal: missionGoal,
							onOpen: stripOpen,
						})
					: h(NextUnlockStrip, {
							state: state,
							reducedMotion: reducedMotion,
							onOpen: stripOpen,
						}),
			),
		h(
			"frame",
			{
				Size: new UDim2(1, -inset * 2, 1, -(headerHeight + unlockH + inset * 2)),
				Position: contentPosition,
				BackgroundTransparency: contentFade,
				BackgroundColor3: Palette.ink,
				BorderSizePixel: 0,
				ZIndex: 1,
				ClipsDescendants: true,
			},
			h(
				EntranceMotionSuppressedContext.Provider,
				{
					value: suppressEntrance,
				},
				h(
					ExitPresenceContext.Provider,
					{
						value: pagePresence,
					},
					children,
				),
			),
			h("frame", {
				Name: "PageVeil",
				Size: UDim2.fromScale(1, 1),
				BackgroundColor3: Palette.ink,
				BackgroundTransparency: veilTransparency,
				BorderSizePixel: 0,
				Active: false,
				Selectable: false,
				Visible: veilVisible,
				ZIndex: 190,
			}),
			h(ScrollEdgeFade, {
				color: Palette.ink,
				height: chrome.stack ? 18 : 16,
				zIndex: 200,
			}),
		),
	);
}

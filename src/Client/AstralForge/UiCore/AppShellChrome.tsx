import React from "@rbxts/react";
import { Audio } from "../AudioKit/audio";
import { countRedraw, RedrawCounterHud, redrawCounterEnabled } from "./devRedrawCounter";
import BuffStrip = require("../BuffStrip");
import { useGameChat } from "../ClientRuntime/chat";
import { AppHelpers, NavState } from "../CoreKit/appNav";
import { ClientActions, useClientDispatch, useClientSelector } from "../CoreKit/clientStore";
import { asFlux, compactNumber, gteFlux, Flux } from "../CoreKit/format";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { ClientLog } from "../CoreKit/log";
import { setPresencePage } from "../CoreKit/session";
import { Layout, Palette, chromeFor } from "../CoreKit/theme";
import { AntilagContext, clampAntilagTier, setAntilagPreference, setAntilagScene, useAntilag } from "../MotionKit/antilag";
import { useDynamicLayoutNumber } from "../MotionKit/dynamicLayout";
import { Flex, FlexItem } from "../MotionKit/flexbox";
import { beginUiTransition, setClockBudget, useFlipperSpring, useViewport, useWallClock } from "../MotionKit/motion";
import { PageContent } from "../pages/PageRouter";
import QuickFind = require("../QuickFind");
import { PageFrame } from "../ReactHosts/reactHost";
import { useEventListener, useLatestCallback } from "../ReactHosts/reactModules";
import { notePage } from "../ReactHosts/vendorHost";
import { Session } from "../state";
import { ComboBadge, ComboReadout } from "./ComboBadge";
import { CrateRevealOverlay, CrateRevealProps } from "./CrateRevealOverlay";
import { UiEffectsPausedContext } from "../CoreKit/effectsPause";
import { CreditsOverlay } from "./CreditsView";
import { EffectLayer, PopEntry, StarField } from "./effects";
import { FeedbackOverlay } from "./FeedbackOverlay";
import { LevelMomentHost } from "./levelMoments";
import { LevelRoadmapHost } from "./levelRoadmap";
import { MobileHeader, MobileQuickActions, MobileTabBar } from "./MobileShell";
import { Navigation } from "./NavChrome";
import { OfflineRewardsOverlay } from "./OfflineRewardsOverlay";
import Juice = require("../JuiceFx");
import { ReleaseNotesModal, TutorialOverlay } from "./onboarding";
import { PlayerlistOverlay } from "./PlayerlistOverlay";
import { RebirthCeremonyHost } from "./RebirthCeremony";
import { ServerEventHost } from "./serverEventsUi";
import { AmbientLayer, TradeReturnPill } from "./ShellFx";
import { TopBar } from "./TopBarChrome";
import { Button, Text } from "./ui";
import { Workspace } from "./WorkspaceChrome";
import TutorialScript = require("../../../Shared/AstralForge/Shared/SharedData/TutorialScript");

type RevealSession = NonNullable<CrateRevealProps["session"]>;
type ReleaseProps = React.ComponentProps<typeof ReleaseNotesModal>;
type Dispatch = <Response = unknown>(action: string, payload?: object, callback?: (response: Response) => void) => void;
type ShellState = Session & NavState & React.ComponentProps<typeof MobileHeader>["state"] & {
	Capacity?: Flux;
	Production?: Flux;
	OfflineEfficiency: number;
	OfflineHours?: number;
	Offline?: {
		Reward?: Flux;
		Seconds: number;
		Efficiency?: number;
		Capped?: boolean;
		Production?: Flux;
		AwaySeconds?: number;
		CapHours?: number;
		Vault?: Flux;
	};
	ActiveBoost?: { Id: string; EndsAt: number };
	Trade?: { Session?: { Id: string }; Invite?: { FromUserId: number; ExpiresAt: number } };
	FeatureUnlocks?: Record<string, { Unlocked?: boolean; Name?: string; Requirement?: string; Progress?: number; Target?: number } | undefined>;
	Cosmetics?: { CrateSkin?: unknown };
	Machines?: Record<string, number | { Level?: number; level?: number }>;
};
type ShellConfig = CrateRevealProps["config"] & NonNullable<React.ComponentProps<typeof LevelRoadmapHost>["config"]> & {
	Game: { Version: string };
	Release: {
		CountdownAt?: number;
		Season: string;
		Announcement?: string;
		Notes: string[];
		History?: ReleaseProps["history"];
	};
	Boosts?: Record<string, unknown>;
	[key: string]: unknown;
};

interface ShellProps {
	state: ShellState;
	config: ShellConfig;
	dispatch: Dispatch;
	addNotice: (title: string, body: string, kind: string) => void;
	celebrate: () => void;
	confettiNonce?: number;
	clearConfetti: () => void;
	pops: PopEntry[];
	comboReadout?: ComboReadout;
	visit?: { DisplayName: string; [key: string]: unknown };
	setVisit: (visit: unknown) => void;
	openDomain: () => void;
	domainOverlayActive: boolean;
	setToastsSuppressed: (suppressed: boolean) => void;
	setPurchasePresentationActive: (active: boolean) => void;
}

export const pausePassivePaints = { current: false };
const TUTORIAL_STEPS = TutorialScript.STEPS;
const ContextActionService = game.GetService("ContextActionService");
const GuiService = game.GetService("GuiService");
const Players = game.GetService("Players");
const UserInputService = game.GetService("UserInputService");

// everything else that piled up while you were away, so the welcome card can take it in one go
function awayExtras(state: ShellState, dispatch: Dispatch) {
	const loose = state as unknown as {
		Daily?: { CanClaim?: boolean };
		Wheel?: { CanSpin?: boolean };
		Command?: { ActiveExpedition?: { Id?: string; EndsAt?: number } };
		Quests?: unknown;
	};
	const waiting: string[] = [];
	const claims: Array<[string, object | undefined]> = [];
	if (loose.Daily?.CanClaim === true) {
		waiting.push("your daily parcel");
		claims.push(["ClaimDaily", undefined]);
	}
	const trip = loose.Command?.ActiveExpedition;
	if (trip !== undefined && (trip.Id ?? "") !== "" && os.time() >= (tonumber(trip.EndsAt) ?? math.huge)) {
		waiting.push("a crew back from their trip");
		claims.push(["ClaimExpedition", {}]);
	}
	const readyIds: string[] = [];
	if (typeIs(loose.Quests, "table")) {
		for (const [, raw] of pairs(loose.Quests as object)) {
			if (!typeIs(raw, "table")) continue;
			const quest = raw as { Id?: unknown; Claimed?: unknown; Progress?: unknown; Target?: unknown };
			const target = tonumber(quest.Target) ?? 0;
			if (quest.Claimed !== true && typeIs(quest.Id, "string") && target > 0 && (tonumber(quest.Progress) ?? 0) >= target) {
				readyIds.push(quest.Id);
			}
		}
	}
	if (readyIds.size() > 0) {
		waiting.push(readyIds.size() === 1 ? "a finished mission" : `${readyIds.size()} finished missions`);
		for (const id of readyIds) claims.push(["ClaimQuest", { Id: id }]);
	}
	// a spin has to be spun by hand, so it's mentioned but not collected
	const spinNote = loose.Wheel?.CanSpin === true ? "Your free spin is waiting on the wheel." : undefined;
	return { waiting, claims, spinNote };
}

// Runs every claim, then sums what actually landed into one line once the last answer is back.
function collectEverything(state: ShellState, dispatch: Dispatch, claims: Array<[string, object | undefined]>, bankVault: boolean) {
	const loose = state as unknown as { Cash?: unknown; Stardust?: unknown; Cores?: unknown };
	const before = { cash: asFlux(loose.Cash), dust: asFlux(loose.Stardust), cores: asFlux(loose.Cores) };
	const queue = table.clone(claims);
	if (bankVault) queue.unshift(["CollectVault", undefined]);
	let pending = queue.size();
	const latest = { Cash: loose.Cash, Stardust: loose.Stardust, Cores: loose.Cores };
	let landed = 0;
	const finish = () => {
		pending -= 1;
		if (pending > 0 || landed === 0) return;
		const parts: string[] = [];
		const cash = asFlux(latest.Cash) - before.cash;
		const dust = asFlux(latest.Stardust) - before.dust;
		const cores = asFlux(latest.Cores) - before.cores;
		if (cash >= 1) parts.push(`${compactNumber(cash)} flux`);
		if (dust >= 1) parts.push(`${compactNumber(dust)} stardust`);
		if (cores >= 1) parts.push(`${compactNumber(cores)} ${cores >= 2 ? "cores" : "core"}`);
		if (parts.size() > 0) Juice.status(`Welcome back: +${parts.join(", ")}`, "success");
	};
	for (const [action, payload] of queue) {
		dispatch<{ ok?: boolean; State?: { Cash?: unknown; Stardust?: unknown; Cores?: unknown } }>(action, payload, (response) => {
			if (response.ok === true) {
				landed += 1;
				const after = response.State;
				if (after !== undefined) {
					if (after.Cash !== undefined) latest.Cash = after.Cash;
					if (after.Stardust !== undefined) latest.Stardust = after.Stardust;
					if (after.Cores !== undefined) latest.Cores = after.Cores;
				}
			}
			finish();
		});
	}
}

function offlineRewardsProps(state: ShellState, reducedMotion: boolean, dispatch: Dispatch, dismiss: () => void) {
	const offline = state.Offline;
	const extras = awayExtras(state, dispatch);
	return {
		reward: offline?.Reward ?? 0,
		seconds: offline?.Seconds ?? 0,
		efficiency: offline?.Efficiency ?? state.OfflineEfficiency,
		capped: offline?.Capped === true,
		production: offline?.Production ?? state.Production,
		awaySeconds: offline?.AwaySeconds,
		capHours: offline?.CapHours ?? state.OfflineHours,
		vault: offline?.Vault ?? state.Vault,
		reducedMotion,
		effectsEnabled: (tonumber(state.Settings.OfflineRewardEffects) ?? 1) >= 0.5,
		onCollect: () => dispatch("CollectVault"),
		waiting: extras.waiting,
		spinNote: extras.spinNote,
		onCollectAll: (bankVault: boolean) => collectEverything(state, dispatch, extras.claims, bankVault),
		onClose: dismiss,
	};
}

function AppShell(props: ShellProps) {
	const { state, config, dispatch, addNotice, celebrate, clearConfetti, pops, comboReadout, visit, setVisit,
		openDomain, domainOverlayActive, setToastsSuppressed, setPurchasePresentationActive } = props;
	const devRedraws = redrawCounterEnabled(state as { Admin?: { Access?: boolean } });
	countRedraw("shell", devRedraws);
	const [crateReveal, setCrateReveal] = React.useState<RevealSession>();
	const pageHostRef = React.useRef<unknown>();
	const cinematicOpen = crateReveal !== undefined || domainOverlayActive;
	React.useEffect(() => {
		pausePassivePaints.current = cinematicOpen;
		return () => { pausePassivePaints.current = false; };
	}, [cinematicOpen]);
	React.useEffect(() => {
		setAntilagPreference(tonumber(state.Settings.PerformanceBias) ?? 0.5);
	}, [state.Settings.PerformanceBias]);
	const [playerlistOpen, setPlayerlistOpen] = React.useState(false);
	const [feedbackOpen, setFeedbackOpen] = React.useState(false);
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const drawerNav = chrome.stack || (!viewport.desktop && UserInputService.TouchEnabled && viewport.compact);
	const page = useClientSelector((client) => client.navigation.page);
	const dispatchStore = useClientDispatch();
	const setPage = React.useCallback((nextPage: string) => dispatchStore(ClientActions.navigate(nextPage)), [dispatchStore]);
	React.useEffect(() => { setPresencePage(page); }, [page]);
	const [railOpen, setRailOpen] = React.useState(!drawerNav);
	const previousDrawerNav = React.useRef(drawerNav);
	React.useEffect(() => {
		if (previousDrawerNav.current === drawerNav) return;
		previousDrawerNav.current = drawerNav;
		setRailOpen(!drawerNav);
	}, [drawerNav]);
	const [arcadeBusy, setArcadeBusy] = React.useState(false);
	const [hidden, setHidden] = React.useState(false);
	const [buyAmount, setBuyAmount] = React.useState(1);
	const chat = useGameChat(page === "Chat", true, dispatch, state.Settings);
	const offlineReceiptKey = state.Offline !== undefined && state.Offline.Seconds >= 30
		? `${math.floor(state.Offline.Seconds)}:${compactNumber(state.Offline.Reward)}` : "";
	const [dismissedOfflineKey, setDismissedOfflineKey] = React.useState("");
	const offlineDismissed = offlineReceiptKey !== "" && dismissedOfflineKey === offlineReceiptKey;
	const densityScale = 0.82 + (tonumber(state.Settings.UiDensity) ?? 0.55) * 0.36;
	const edgePad = math.max(8, chrome.sideSafe, math.floor(chrome.pagePadding * densityScale));
	const topPad = chrome.stack ? 6 : Layout.topbarClearance;
	const keyboardShellCompact = viewport.keyboardOpen && chrome.mobile && (tonumber(state.Settings.MobileKeyboardCompact) ?? 1) >= 0.5;
	const topbarHeight = keyboardShellCompact ? 0 : chrome.stack ? chrome.topbarRows
		: (tonumber(state.Settings.CompactTopBar) ?? 0) >= 0.5 ? math.max(52, chrome.topbarRows - 8) : chrome.topbarRows;
	const tabBarH = keyboardShellCompact ? 0 : chrome.tabBarH;
	const shellTop = topPad + topbarHeight + chrome.panelGap;
	const quickActionsVisible = (tonumber(state.Settings.MobileQuickVisible) ?? 1) >= 0.5 && chrome.stack
		&& page === "Workshop" && !viewport.keyboardOpen && !arcadeBusy && crateReveal === undefined && !railOpen;
	const quickBottomOffset = tabBarH + 12;
	const bottomPad = keyboardShellCompact ? 4 : chrome.stack
		? quickActionsVisible ? tabBarH + 76 + chrome.panelGap : tabBarH + chrome.panelGap
		: math.max(8, math.floor(edgePad * 0.6));
	// The source intentionally keeps shell transitions animated regardless of the saved motion setting.
	const reducedMotion = false;
	const softMotion = false;
	const shellTopLive = useDynamicLayoutNumber(shellTop, softMotion);
	const topbarLive = useDynamicLayoutNumber(topbarHeight, softMotion);
	React.useEffect(() => { Audio.setView(page, false); }, [page]);
	const effectsScale = tonumber(state.Settings.EffectsIntensity) ?? 1;
	const accent = AppHelpers.pageAccent(page);
	const activeBoostId = state.ActiveBoost?.Id ?? "";
	const activeBoostEndsAt = state.ActiveBoost?.EndsAt ?? 0;
	const [activeBoostExpired, setActiveBoostExpired] = React.useState(activeBoostEndsAt <= game.GetService("Workspace").GetServerTimeNow());
	React.useEffect(() => {
		const remaining = activeBoostEndsAt - game.GetService("Workspace").GetServerTimeNow();
		setActiveBoostExpired(remaining <= 0);
		if (activeBoostId === "" || remaining <= 0) return;
		const expiry = task.delay(remaining + 0.05, () => setActiveBoostExpired(true));
		return () => task.cancel(expiry);
	}, [activeBoostEndsAt, activeBoostId]);
	const activeBoost = !activeBoostExpired && activeBoostId !== "" ? config.Boosts?.[activeBoostId] : undefined;
	const wallClock = useWallClock(activeBoost !== undefined);
	const hideAmount = useFlipperSpring(hidden ? 1 : 0, softMotion, 620, 42);
	const mobileShell = chrome.stack;
	const drawerWidth = math.min(Layout.sidebarWidth, math.max(248, viewport.width - edgePad * 2 - 36));
	const railTarget = railOpen ? drawerNav ? drawerWidth : viewport.compact ? Layout.sidebarCollapsedWidth : Layout.sidebarWidth : 0;
	const railWidth = useFlipperSpring(mobileShell ? 0 : railTarget, softMotion, 900, 46);
	const drawerProgress = railWidth.map((width) => drawerNav ? math.clamp(width / math.max(drawerWidth, 1), 0, 1) : 0);
	const drawerScrimTransparency = drawerProgress.map((amount) => 1 - amount * 0.58);
	const drawerScrimVisible = drawerProgress.map((amount) => amount > 0.01);
	const drawerPanelVisible = railWidth.map((width) => width > 6);
	const workspaceOffset = railWidth.map((width) => drawerNav ? UDim2.fromOffset(0, 0)
		: new UDim2(0, width > 1 ? width + Layout.panelGap : 0, 0, 0));
	const workspaceSize = railWidth.map((width) => drawerNav ? UDim2.fromScale(1, 1)
		: new UDim2(1, -(width > 1 ? width + Layout.panelGap : 0), 1, 0));
	const serverTutorialStep = math.clamp(math.floor(state.Flags.TutorialStep ?? 1), 1, TUTORIAL_STEPS.size());
	const [tutorialStep, setTutorialStep] = React.useState(serverTutorialStep);
	const tutorialHold = React.useRef(0);
	React.useEffect(() => {
		if (tutorialHold.current > 0 && serverTutorialStep < tutorialHold.current && !state.Flags.TutorialDone) return;
		tutorialHold.current = 0;
		setTutorialStep(serverTutorialStep);
	}, [serverTutorialStep, state.Flags.TutorialDone]);
	const tutorial = TUTORIAL_STEPS[tutorialStep - 1];
	const tutorialOpen = !state.Flags.TutorialDone && tutorial !== undefined;
	const [releaseClosedLocally, setReleaseClosedLocally] = React.useState(false);
	React.useEffect(() => {
		if (state.Flags.LastSeenVersion === "") setReleaseClosedLocally(false);
	}, [state.Flags.LastSeenVersion]);
	const showRelease = state.Flags.TutorialDone === true && state.Flags.LastSeenVersion !== config.Game.Version && !releaseClosedLocally;
	const offlineRewardsOpen = offlineReceiptKey !== "" && !offlineDismissed && state.Flags.TutorialDone === true
		&& gteFlux(state.Offline?.Reward ?? 0, 0.01) && !showRelease && page !== "Credits" && crateReveal === undefined
		&& !playerlistOpen && !feedbackOpen && !domainOverlayActive;
	const modalOwnsScreen = tutorialOpen || showRelease || page === "Credits" || crateReveal !== undefined || domainOverlayActive;
	React.useEffect(() => {
		setToastsSuppressed(modalOwnsScreen);
		return () => setToastsSuppressed(false);
	}, [modalOwnsScreen, setToastsSuppressed]);
	useEventListener(UserInputService.InputBegan, (input: InputObject, processed: boolean) => {
		if (UserInputService.GetFocusedTextBox() !== undefined || processed) return;
		if (input.KeyCode === Enum.KeyCode.Backquote) setHidden((current) => !current);
	}, { connected: !domainOverlayActive && !showRelease && !tutorialOpen });
	const navigate = (pageId: string) => {
		const entry = AppHelpers.pageEntry(pageId) as ReturnType<typeof AppHelpers.pageEntry> & { disabledReason?: string };
		if (entry.disabled === true) {
			Audio.play("locked");
			addNotice(`${entry.label} is closed`, entry.disabledReason ?? "Closed for now.", "Info");
			return;
		}
		if (!AppHelpers.navUnlocked(state, pageId, tutorial?.page)) {
			const lock = state.FeatureUnlocks?.[pageId];
			Audio.play("locked");
			let body = lock?.Requirement ?? "Not unlocked yet.";
			if (lock !== undefined && typeIs(lock.Requirement, "string") && lock.Requirement !== "") {
				const done = typeIs(lock.Progress, "number") && typeIs(lock.Target, "number")
					? ` (${compactNumber(lock.Progress)}/${compactNumber(lock.Target)})` : "";
				body = `${lock.Requirement} to open it${done}.`;
			}
			if (pageId === "Research") body += " Research bonuses stay after rebirth.";
			addNotice(`${lock?.Name ?? pageId} is locked`, body, "Info");
			return;
		}
		Audio.setView(pageId);
		ClientLog.debug("nav", pageId);
		beginUiTransition(0.1);
		setPage(pageId);
		if (drawerNav) setRailOpen(false);
	};
	const navigationStateRef = React.useRef(state);
	navigationStateRef.current = state;
	const tutorialPageRef = React.useRef(tutorial?.page);
	tutorialPageRef.current = tutorial?.page;
	const navigateRef = React.useRef(navigate);
	navigateRef.current = navigate;
	const navigateStable = useLatestCallback((pageId: string) => {
		notePage(pageId);
		navigateRef.current(pageId);
	}) as (pageId: string) => void;
	const openWorkshop = React.useCallback(() => navigateRef.current("Workshop"), []);
	const onWheelLand = React.useCallback(() => celebrate(), [celebrate]);
	// stable shell handlers (same bodies as the old inline arrows; navigateRef always holds this render's navigate)
	const navigateLatest = useLatestCallback((pageId: string) => navigateRef.current(pageId)) as (pageId: string) => void;
	const toggleRail = React.useCallback(() => setRailOpen((open) => !open), []);
	const hideUI = React.useCallback(() => setHidden(true), []);
	const showUI = React.useCallback(() => setHidden(false), []);
	const openFeedback = React.useCallback(() => { setPlayerlistOpen(false); setFeedbackOpen(true); }, []);
	const openBoosts = React.useCallback(() => navigateRef.current("Rewards"), []);
	const returnToTrade = React.useCallback(() => { setHidden(false); setRailOpen(false); navigateRef.current("Trade"); }, []);
	React.useEffect(() => {
		if (state.Flags.TutorialDone || tutorial === undefined || tutorial.startPage === undefined) return;
		setHidden(false);
		setPage(AppHelpers.navUnlocked(state, tutorial.startPage, tutorial.page) ? tutorial.startPage : "Overview");
	}, [state.Flags.TutorialDone, tutorial]);
	React.useEffect(() => {
		if (page !== "Trade" && !AppHelpers.navUnlocked(state, page, tutorial?.page)) setPage("Overview");
	}, [page, state.FeatureUnlocks, tutorial]);
	const tradeFocusKey = React.useRef("");
	React.useEffect(() => {
		const sessionId = state.Trade?.Session?.Id;
		const invite = state.Trade?.Invite;
		const key = sessionId !== undefined ? `session:${sessionId}` : invite !== undefined ? `invite:${invite.FromUserId}:${invite.ExpiresAt}` : "";
		if (key === "") { tradeFocusKey.current = ""; return; }
		if (key !== tradeFocusKey.current) {
			tradeFocusKey.current = key;
			Audio.play(sessionId !== undefined ? "confirm" : "invite");
			if (sessionId !== undefined) {
				setHidden(false);
				setPlayerlistOpen(false);
				setFeedbackOpen(false);
				if (drawerNav) setRailOpen(false);
				setPage("Trade");
			}
		}
	}, [drawerNav, state.Trade?.Invite?.ExpiresAt, state.Trade?.Invite?.FromUserId, state.Trade?.Session?.Id]);
	const tradeAwaySent = React.useRef(false);
	React.useEffect(() => {
		if (state.Trade?.Session === undefined) { tradeAwaySent.current = false; return; }
		const away = page !== "Trade";
		if (away === tradeAwaySent.current) return;
		tradeAwaySent.current = away;
		dispatch("TradeViewAway", { Away: away });
	}, [dispatch, page, state.Trade?.Session?.Id]);
	React.useEffect(() => {
		const player = Players.LocalPlayer;
		let unfocusedAt = -math.huge;
		let focused = true;
		const mark = (away: boolean) => {
			player.SetAttribute("AF_Away", away);
			player.SetAttribute("AF_AwayAt", away ? os.clock() : 0);
		};
		mark(false);
		const loseFocus = () => { focused = false; unfocusedAt = os.clock(); };
		const gainFocus = () => { focused = true; mark(false); };
		const lost = UserInputService.WindowFocusReleased.Connect(loseFocus);
		const gained = UserInputService.WindowFocused.Connect(gainFocus);
		const menuOpen = GuiService.MenuOpened.Connect(loseFocus);
		const menuClose = GuiService.MenuClosed.Connect(gainFocus);
		const pulse = task.spawn(() => {
			while (true) {
				task.wait(1);
				if (!focused && os.clock() - unfocusedAt >= 20) mark(true);
			}
		});
		return () => {
			lost.Disconnect(); gained.Disconnect(); menuOpen.Disconnect(); menuClose.Disconnect();
			task.cancel(pulse);
			mark(false);
		};
	}, []);
	React.useEffect(() => {
		GuiService.AutoSelectGuiEnabled = true;
		GuiService.GuiNavigationEnabled = true;
		const buySteps = [1, 5, 10, 25, 0];
		const cycleBuy = (direction: number) => {
			const at = math.max(0, buySteps.indexOf(buyAmount));
			setBuyAmount(buySteps[(at + direction + buySteps.size()) % buySteps.size()]);
			Audio.play("tick");
		};
		const actionName = "AstralForgeNavigation";
		ContextActionService.BindActionAtPriority(actionName, (_name, inputState, input) => {
			const pass = Enum.ContextActionResult.Pass;
			const sink = Enum.ContextActionResult.Sink;
			if (inputState !== Enum.UserInputState.Begin || UserInputService.GetFocusedTextBox() !== undefined || arcadeBusy) return pass;
			const key = input.KeyCode;
			if (key === Enum.KeyCode.ButtonB && page === "Credits") { navigateRef.current("Overview"); return sink; }
			if (key === Enum.KeyCode.ButtonB && playerlistOpen) { setPlayerlistOpen(false); return sink; }
			if (key === Enum.KeyCode.ButtonB && feedbackOpen) { setFeedbackOpen(false); return sink; }
			if (key === Enum.KeyCode.ButtonB && showRelease) { dispatch("DismissRelease"); return sink; }
			if (key === Enum.KeyCode.ButtonB && tutorialOpen) {
				if (tutorialStep > 1) dispatch("SetTutorialStep", { Step: tutorialStep - 1 });
				return sink;
			}
			if (crateReveal !== undefined || playerlistOpen || feedbackOpen || page === "Credits" || domainOverlayActive || showRelease || tutorialOpen) return sink;
			if (key === Enum.KeyCode.ButtonB) {
				if (hidden) setHidden(false); else if (railOpen) setRailOpen(false); else setRailOpen(true);
				return sink;
			}
			if (key === Enum.KeyCode.ButtonY) { Audio.play("vaultBank"); dispatch("CollectVault"); return sink; }
			if (key === Enum.KeyCode.ButtonX) { Audio.play("reactorPulse"); dispatch("Overcharge"); return sink; }
			if (key === Enum.KeyCode.ButtonSelect) { setHidden((current) => !current); return sink; }
			if (key === Enum.KeyCode.ButtonL2) { cycleBuy(-1); return sink; }
			if (key === Enum.KeyCode.ButtonR2) { cycleBuy(1); return sink; }
			if (key === Enum.KeyCode.ButtonStart) { navigateRef.current("Settings"); return sink; }
			const rail = AppHelpers.visibleNav(navigationStateRef.current, tutorialPageRef.current);
			if (rail.size() === 0) return pass;
			const index = math.max(0, rail.findIndex((entry) => entry.id === page));
			if (key === Enum.KeyCode.ButtonL1) navigateRef.current(rail[(index - 1 + rail.size()) % rail.size()].id);
			else if (key === Enum.KeyCode.ButtonR1) navigateRef.current(rail[(index + 1) % rail.size()].id);
			else return pass;
			return sink;
		}, false, 2200, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, Enum.KeyCode.ButtonY,
			Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonSelect, Enum.KeyCode.ButtonL2, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonStart);
		return () => ContextActionService.UnbindAction(actionName);
	}, [arcadeBusy, buyAmount, crateReveal, dispatch, domainOverlayActive, feedbackOpen, hidden, page, playerlistOpen, railOpen, showRelease, tutorialOpen, tutorialStep]);
	const requestChatFocus = chat.requestFocus;
	React.useEffect(() => {
		const actionName = "AstralForgeKeyboard";
		ContextActionService.BindActionAtPriority(actionName, (_name, inputState, input) => {
			if (inputState !== Enum.UserInputState.Begin || UserInputService.GetFocusedTextBox() !== undefined
				|| crateReveal !== undefined || tutorialOpen || showRelease || domainOverlayActive) return Enum.ContextActionResult.Pass;
			if (input.KeyCode === Enum.KeyCode.Slash) {
				setPlayerlistOpen(false);
				navigateRef.current("Chat");
				requestChatFocus?.();
				return Enum.ContextActionResult.Sink;
			}
			if (input.KeyCode === Enum.KeyCode.Tab) {
				setPlayerlistOpen((current) => !current);
				return Enum.ContextActionResult.Sink;
			}
			return Enum.ContextActionResult.Pass;
		}, false, 2100, Enum.KeyCode.Slash, Enum.KeyCode.Tab);
		return () => ContextActionService.UnbindAction(actionName);
	}, [crateReveal, domainOverlayActive, requestChatFocus, showRelease, tutorialOpen]);
	const [gamepadActive, setGamepadActive] = React.useState(false);
	React.useEffect(() => {
		const sync = (input: Enum.UserInputType) => setGamepadActive(input === Enum.UserInputType.Gamepad1
			|| input === Enum.UserInputType.Gamepad2 || input === Enum.UserInputType.Gamepad3 || input === Enum.UserInputType.Gamepad4);
		sync(UserInputService.GetLastInputType());
		const connection = UserInputService.LastInputTypeChanged.Connect(sync);
		return () => connection.Disconnect();
	}, []);
	const sampledAntilag = useAntilag();
	const performanceBias = tonumber(state.Settings.PerformanceBias) ?? 0.5;
	const performanceTierCap = performanceBias >= 0.88 ? 1 : performanceBias >= 0.68 ? 2 : 3;
	const rootAntilag = React.useMemo(() => clampAntilagTier(sampledAntilag, performanceTierCap), [performanceTierCap, sampledAntilag]);
	const backgroundDetail = tonumber(state.Settings.BackgroundDetail) ?? 0.8;
	const glowIntensity = tonumber(state.Settings.GlowIntensity) ?? 0.75;
	const suppressBackground = backgroundDetail < 0.34 || !rootAntilag.allowAmbient;
	const renderEffectsScale = effectsScale * (tonumber(state.Settings.ParticleDensity) ?? 0.75) * rootAntilag.fxBudget;
	// same array between renders unless the pops or the cap change, so the memoised EffectLayer
	// can skip the shell's per-push re-render (the trimmed copy used to be new every time)
	const maxPops = rootAntilag.maxPops;
	const visiblePops = React.useMemo(
		() => (pops.size() > maxPops ? pops.filter((_, index) => index >= pops.size() - maxPops) : pops),
		[pops, maxPops],
	);
	const heavyPage = page === "Worlds" || page === "Anomaly" || page === "StarGrid";
	const quietPage = page === "Story" || page === "Chat" || page === "Mail" || page === "Credits" || page === "Leaderboards" || page === "Admin";
	const pageAntilag = React.useMemo(() => arcadeBusy
		? { ...rootAntilag, allowConfetti: false, maxStars: 0, maxClocks: math.min(rootAntilag.maxClocks, 4) }
		: heavyPage ? { ...rootAntilag, maxStars: 0, maxClocks: math.min(rootAntilag.maxClocks, page === "Anomaly" ? 8 : 4) }
		: quietPage ? { ...rootAntilag, maxStars: math.min(rootAntilag.maxStars, 4) } : rootAntilag,
		[arcadeBusy, heavyPage, page, quietPage, rootAntilag]);
	React.useEffect(() => {
		setAntilagScene(cinematicOpen ? "cinematic" : arcadeBusy ? "arcade" : heavyPage ? "heavy" : "normal");
		return () => setAntilagScene("normal");
	}, [arcadeBusy, cinematicOpen, heavyPage]);
	React.useEffect(() => { setClockBudget(pageAntilag.maxClocks); }, [pageAntilag.maxClocks]);
	const gamepadReserve = gamepadActive ? 44 : 0;
	let ownedMachines = 0;
	if (state.Machines !== undefined) {
		for (const [, level] of pairs(state.Machines)) {
			const amount = typeIs(level, "table") ? level.Level ?? level.level ?? 0 : level;
			if (typeIs(amount, "number") && amount > 0) ownedMachines++;
		}
	}
	const openPlayerlist = React.useCallback(() => { setFeedbackOpen(false); setPlayerlistOpen(true); }, []);
	const notify = React.useCallback((title: string, body: string) => addNotice(title, body, "Info"), [addNotice]);
	const moveTutorial = (targetStep: number, sound: string) => {
		Audio.play(sound);
		tutorialHold.current = targetStep;
		setTutorialStep(targetStep);
		dispatch("SetTutorialStep", { Step: targetStep });
	};
	return (
		<AntilagContext.Provider value={rootAntilag}>
			<>
				<UiEffectsPausedContext.Provider value={hidden || crateReveal !== undefined}>
				<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.void} BackgroundTransparency={hideAmount}
					BorderSizePixel={0} ClipsDescendants={true} Visible={crateReveal === undefined}>
					<uigradient Color={new ColorSequence([new ColorSequenceKeypoint(0, Palette.void), new ColorSequenceKeypoint(0.5, Palette.graphite), new ColorSequenceKeypoint(1, Palette.void)])} Rotation={112} />
					<frame Size={new UDim2(1, 0, 0, 1)} BackgroundColor3={Palette.brass}
						BackgroundTransparency={hideAmount.map((amount) => math.clamp(0.8 + amount, 0, 1))} BorderSizePixel={0} ZIndex={2} />
					<frame Size={UDim2.fromScale(1, 1)} Position={hideAmount.map((amount) => new UDim2(0, 0, amount * 1.05, 0))} BackgroundTransparency={1} BorderSizePixel={0}>
						{(tonumber(state.Settings.BackgroundStars) ?? 1) >= 0.5 && backgroundDetail >= 0.2 && <StarField accent={accent} />}
						{(tonumber(state.Settings.AmbientGlow) ?? 1) >= 0.5 && !suppressBackground && <AmbientLayer reducedMotion={softMotion || heavyPage || quietPage || arcadeBusy} intensity={glowIntensity} />}
						{(tonumber(state.Settings.AmbientGlow) ?? 1) >= 0.5 && glowIntensity > 0.02 && backgroundDetail >= 0.45 &&
							<frame Size={UDim2.fromOffset(620, 620)} Position={new UDim2(1, 170, 1, 90)} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundColor3={accent}
								BackgroundTransparency={1 - 0.035 * math.clamp(glowIntensity, 0, 1)} BorderSizePixel={0} Rotation={-12}><uicorner CornerRadius={new UDim(1, 0)} /></frame>}
						{(tonumber(state.Settings.AmbientGlow) ?? 1) >= 0.5 && glowIntensity > 0.02 && backgroundDetail >= 0.7 &&
							<frame Size={UDim2.fromOffset(420, 420)} Position={new UDim2(0, -170, 0, -130)} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundColor3={Palette.cyan}
								BackgroundTransparency={1 - 0.025 * math.clamp(glowIntensity, 0, 1)} BorderSizePixel={0}><uicorner CornerRadius={new UDim(1, 0)} /></frame>}
						{!keyboardShellCompact && mobileShell && <>
							<MobileHeader state={state} page={page} accent={accent} topPad={topPad} barHeight={topbarHeight} edgePad={edgePad} reducedMotion={softMotion} openPlayerlist={openPlayerlist} />
							<BuffStrip.Island state={state} config={config} reducedMotion={softMotion} restHidden={true} maxWidth={viewport.width - edgePad * 2}
								position={new UDim2(0.5, 0, 0, topPad + topbarHeight + 6)} anchorPoint={new Vector2(0.5, 0)} />
						</>}
						{!keyboardShellCompact && !mobileShell && <TopBar state={state} page={page} railOpen={railOpen} toggleRail={toggleRail} hideUI={hideUI}
							tight={viewport.tight} width={viewport.width} topPad={topPad} barHeight={topbarHeight} barHeightMotion={topbarLive} edgePad={edgePad} reducedMotion={softMotion}
							releaseAt={config.Release.CountdownAt ?? 1789272000} visit={visit} config={config} navigate={setPage} openPlayerlist={openPlayerlist}
							openFeedback={openFeedback} />}
						<frame Size={shellTopLive.map((top) => new UDim2(1, -edgePad * 2, 1, -(top + bottomPad + gamepadReserve)))}
							Position={shellTopLive.map((top) => UDim2.fromOffset(edgePad, top))} BackgroundTransparency={1} BorderSizePixel={0}>
							<frame Size={workspaceSize} Position={workspaceOffset} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={5}>
								<AntilagContext.Provider value={pageAntilag}>
									<Workspace page={page} state={state} dispatch={dispatch} reducedMotion={reducedMotion} navigate={navigateStable}>
										<PageFrame page={page} ref={pageHostRef}>
											<PageContent key={page} page={page} state={state} config={config} dispatch={dispatch} reducedMotion={reducedMotion}
												domainOverlayActive={domainOverlayActive} openWorkshop={openWorkshop} openDomain={openDomain} buyAmount={buyAmount} setBuyAmount={setBuyAmount}
												onWheelLand={onWheelLand} wallClock={wallClock} activeBoostExpired={activeBoostExpired} clearConfetti={clearConfetti} chat={chat} visit={visit}
												setVisit={setVisit} addNotice={addNotice} crateRevealActive={crateReveal !== undefined} setCrateReveal={setCrateReveal} navigate={navigateStable}
												setArcadeBusy={setArcadeBusy} setPurchasePresentationActive={setPurchasePresentationActive} />
										</PageFrame>
									</Workspace>
								</AntilagContext.Provider>
							</frame>
							{!mobileShell && drawerNav && <imagebutton Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.void} BackgroundTransparency={drawerScrimTransparency} BorderSizePixel={0}
								AutoButtonColor={false} Selectable={false} Active={railOpen} Visible={drawerScrimVisible} ZIndex={28} Event={{ Activated: () => { setRailOpen(false); Audio.play("close"); } }} />}
							{!mobileShell && <frame Size={drawerNav ? new UDim2(0, drawerWidth, 1, 0) : railWidth.map((width) => new UDim2(0, math.max(0, width), 1, 0))}
								Position={drawerNav ? drawerProgress.map((amount) => new UDim2(0, -drawerWidth * (1 - amount), 0, 0)) : undefined}
								BackgroundTransparency={1} BorderSizePixel={0} ZIndex={drawerNav ? 30 : 10} ClipsDescendants={true} Visible={drawerNav ? drawerScrimVisible : drawerPanelVisible}>
								<Navigation page={page} setPage={navigateLatest} collapsed={!drawerNav && viewport.compact} width={railWidth} fixedWidth={drawerNav ? drawerWidth : undefined}
									reducedMotion={softMotion} state={state} chatUnread={chat.unread} tutorialPage={tutorial?.page} includeSecondary={true} fromMore={false}
									activeBoost={activeBoost} activeBoostEndsAt={activeBoostEndsAt} wallClock={wallClock} openBoosts={openBoosts} />
							</frame>}
						</frame>
						{state.Trade?.Session !== undefined && page !== "Trade" && <TradeReturnPill stack={chrome.stack} bottomPad={bottomPad} reducedMotion={softMotion}
							onReturn={returnToTrade} />}
						{mobileShell && <MobileTabBar page={page} setPage={navigateLatest} state={state} chatUnread={chat.unread} tutorialPage={tutorial?.page} reducedMotion={reducedMotion}
							height={tabBarH} bottomSafe={chrome.bottomSafe} visible={!keyboardShellCompact} />}
						{mobileShell && quickActionsVisible && <MobileQuickActions state={state} dispatch={dispatch} reducedMotion={reducedMotion} bottomOffset={quickBottomOffset} edgePad={edgePad} />}
						{!hidden && <ComboBadge readout={comboReadout} reducedMotion={reducedMotion} position={new UDim2(1, -18, 0, topPad + topbarHeight + 8)} anchorPoint={new Vector2(1, 0)} zIndex={65} />}
						{renderEffectsScale > 0.05 && <EffectLayer pops={visiblePops} />}
						<QuickFind.QuickFind state={state} dispatch={dispatch} navigate={navigateStable} chatUnread={chat.unread} reducedMotion={reducedMotion}
							enabled={!hidden && !tutorialOpen && !domainOverlayActive && !showRelease} />
					</frame>
					<frame Size={UDim2.fromOffset(186, 44)} Position={hideAmount.map((amount) => new UDim2(0, edgePad, 0, -64 + math.floor(amount * (topPad + 64))))} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={200}>
						<Button text="SHOW UI  ( ` )" icon="Hide.2" onClick={showUI} color={accent} textColor={Palette.ink} size={UDim2.fromScale(1, 1)} reducedMotion={reducedMotion} />
					</frame>
					{!state.Flags.TutorialDone && tutorial !== undefined && <TutorialOverlay copy={tutorial} step={tutorialStep} count={TUTORIAL_STEPS.size()} reducedMotion={reducedMotion}
						live={{ page, cash: compactNumber(state.Cash), vault: compactNumber(state.Vault), vaultFlux: asFlux(state.Vault), production: compactNumber(state.Production), ownedMachines, buyAmount }}
						ctaLabel={tutorial.ctaLabel} onCta={tutorial.cta === "collect" ? () => dispatch("CollectVault") : tutorial.cta === "workshop" ? () => navigate("Workshop") : tutorial.cta === "research" ? () => navigate("Research") : undefined}
						onBack={() => moveTutorial(math.max(1, tutorialStep - 1), "stepBack")}
						onNext={() => { if (tutorialStep >= TUTORIAL_STEPS.size()) dispatch("CompleteTutorial"); else moveTutorial(tutorialStep + 1, "stepNext"); }} onSkip={() => dispatch("CompleteTutorial")} />}
					{gamepadActive && !hidden && !tutorialOpen && <frame Size={new UDim2(1, -edgePad * 2, 0, 36)} Position={new UDim2(0, edgePad, 1, -(bottomPad + 36))} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={180}>
						<Flex direction="row" wrap={true} justify="space-evenly" align="center" gap={10} size={UDim2.fromScale(1, 1)} exact={true}>
							{GamepadNavigationService.GetHintLabels().map((hint, index) => <FlexItem key={hint} mode="grow" minWidth={88} minHeight={22} layoutOrder={index}>
								<Text value={hint} size={11} color={Palette.creamSoft} align={Enum.TextXAlignment.Center} fit={true} minSize={9} sizeConstraint={UDim2.fromScale(1, 1)} />
							</FlexItem>)}
						</Flex>
					</frame>}
					{showRelease && <ReleaseNotesModal version={config.Game.Version} season={config.Release.Season} announcement={config.Release.Announcement} notes={config.Release.Notes} history={config.Release.History}
						viewportWidth={viewport.width} viewportHeight={viewport.height} reducedMotion={reducedMotion} onClose={() => { setReleaseClosedLocally(true); dispatch("DismissRelease"); }}
						onOpenMail={() => { Audio.play("mail"); setReleaseClosedLocally(true); dispatch("DismissRelease"); setPage("Mail"); }} />}
					{page === "Credits" && <CreditsOverlay version={state.Game.Version} reducedMotion={reducedMotion} onClose={() => navigate("Overview")} />}
					{playerlistOpen && <PlayerlistOverlay state={state} dispatch={dispatch} reducedMotion={reducedMotion} onClose={() => setPlayerlistOpen(false)}
						onMessage={(userId) => { setPlayerlistOpen(false); navigate("Chat"); chat.openWhisper(userId); }} notify={notify} />}
					{feedbackOpen && <FeedbackOverlay dispatch={dispatch} page={page} reducedMotion={reducedMotion} onClose={() => setFeedbackOpen(false)} notify={notify} />}
					<LevelRoadmapHost state={state} config={config} reducedMotion={reducedMotion} />
					<LevelMomentHost />
					<ServerEventHost state={state} dispatch={dispatch} />
					{offlineRewardsOpen && <OfflineRewardsOverlay {...offlineRewardsProps(state, reducedMotion, dispatch, () => setDismissedOfflineKey(offlineReceiptKey))} />}
				</frame>
				</UiEffectsPausedContext.Provider>
				{crateReveal !== undefined && <CrateRevealOverlay session={crateReveal} config={config} skin={state.Cosmetics?.CrateSkin} reducedMotion={reducedMotion} onClose={() => setCrateReveal(undefined)} />}
				<RebirthCeremonyHost reducedMotion={reducedMotion} />
				<RedrawCounterHud enabled={devRedraws} />
			</>
		</AntilagContext.Provider>
	);
}

export function Shell(props: ShellProps) {
	return <AppShell {...props} />;
}

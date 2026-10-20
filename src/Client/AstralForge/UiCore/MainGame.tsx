import React from "@rbxts/react";
import { TooltipProvider } from "../Tooltip";
import { setEffectSwitches, setInGameReducedMotion } from "../MotionPreference";
const ContentProvider = game.GetService("ContentProvider");
const GuiService = game.GetService("GuiService");
const Players = game.GetService("Players");
const ReplicatedStorage = game.GetService("ReplicatedStorage");
const RunService = game.GetService("RunService");
const StarterPlayer = game.GetService("StarterPlayer");
const UserInputService = game.GetService("UserInputService");
const WorkspaceService = game.GetService("Workspace");
import { Session } from "../state";
import { setHapticIntensity, usesDesktopStructure, InteractionFeedback } from "../CoreKit/interaction";
import { Palette, applyAccessibilityTheme } from "../CoreKit/theme";
import { asFlux, compactNumber } from "../CoreKit/format";
import * as ActionCopy from "../CoreKit/actionCopy";
import * as NoticeMath from "../CoreKit/noticeMath";
import * as SnapshotEnvelopeMath from "../CoreKit/snapshotEnvelopeMath";
import { AppHelpers } from "../CoreKit/appNav";
import * as NetworkPolicy from "../CoreKit/networkPolicy";
import { ClientLog } from "../CoreKit/log";
import { GRANT_ACTIONS, adopt, attachGrantFields, isAuthed, whenAuthed } from "../CoreKit/session";
import { ClientActions, getActiveClientStore, useClientDispatch, useClientSelector } from "../CoreKit/clientStore";
import { preloadMountedGame, warmClientModules } from "../ClientRuntime/assetPreloader";
import { useClientIntegrityProbe } from "../ClientRuntime/clientIntegrity";
import { AntilagProvider } from "../MotionKit/antilag";
import { MotionSettings, MotionSettingsContext } from "../MotionKit/motion";
import { AutoScale } from "../MotionKit/autoScale";
import { POP_SECONDS } from "./effects";
import { AdminPrankOverlay, HudPrankStage, Prank } from "./AdminPrankOverlay";
import * as LevelMoments from "./levelMoments";
import * as ServerEventsUi from "./serverEventsUi";
import * as RebirthCeremony from "./RebirthCeremony";
import { Shell, pausePassivePaints } from "./AppShellChrome";
import { LooseComponent, LooseProps } from "./ui";

const AstralForge = script.Parent!.Parent!;
const load = <T,>(name: string): T => require(AstralForge.WaitForChild(name) as ModuleScript) as T;
const loadKit = <T,>(kit: string, member: string): T =>
	(require(AstralForge.WaitForChild(kit) as ModuleScript) as (member: string) => T)(member);

interface AudioApi {
	play(this: unknown, name: string, speedMult?: number): boolean;
	playCelebration(this: unknown, cues: string[], staggerSeconds?: number): boolean;
	start(this: unknown): void;
	whenWarm(this: unknown, callback: () => void): void;
	configurePreferences(this: unknown, settings: Record<string, unknown>): void;
	setVolume(this: unknown, value: number): void;
	setMusicVolume(this: unknown, value: number): void;
	setSfxVolume(this: unknown, value: number): void;
}
const Audio = loadKit<{ Audio: AudioApi }>("AudioKit", "audio").Audio;

interface BootKitModule {
	BootScreen: LooseComponent;
	bootChecklistReady(marks: Record<string, unknown>): boolean;
	bootProgress(marks: Record<string, unknown>): number;
	BOOT_MODULE_TIMEOUT: number;
	BOOT_MOTION: MotionSettings;
}
const Boot = loadKit<BootKitModule>("BootKit", "BootScreen");

interface BootLedgerApi {
	mark(this: void, key: string): void;
}

interface JuiceApi {
	setToastDensity(this: void, density: number): void;
	banner(this: void, title: string, subtitle?: string, color?: Color3, icon?: string, duration?: number, tone?: string): void;
	flash(this: void, color?: Color3, strength?: number): void;
	activity(this: void, kind: string, data: unknown): void;
	celebrateGains(this: void, before: unknown, after: unknown, options?: { spend?: boolean; big?: boolean; coins?: number; skipVault?: boolean }): number;
	burst(this: void, at?: Vector2, color?: Color3, scale?: number): void;
	ring(this: void, at?: Vector2, color?: Color3): void;
	number(this: void, text: string, color?: Color3, options?: { at?: Vector2; big?: boolean; icon?: string }): void;
	coins(this: void, target: string, color?: Color3, icon?: string, count?: number, from?: Vector2): boolean;
	moment(this: void, title: string, subtitle?: string, color?: Color3, icon?: string): void;
	status(this: void, text: string, tone?: string): void;
}
const Juice = load<JuiceApi>("JuiceFx");

interface SessionStatsApi {
	best(this: void, key: string, value: number): void;
	bump(this: void, key: string, amount?: number): void;
	addFlux(this: void, amount: unknown): void;
}
const SessionStats = load<SessionStatsApi>("SessionStats");


interface CrewState {
	crew?: unknown;
	invite?: unknown;
}
interface CrewStoreApi {
	NONE: unknown;
	get(this: void): CrewState;
	set(this: void, patch: Record<string, unknown>): void;
}
const CrewStore = load<CrewStoreApi>("CrewStore");

interface ScrollingApi {
	setScrollSpeed(this: void, value: number): void;
	setScrollMomentum(this: void, value: number): void;
}
const { setScrollSpeed, setScrollMomentum } = loadKit<ScrollingApi>("LayoutKit", "scrolling");

const NOOP = () => {};

type ActionResponse = Record<string, unknown> & {
	ok?: boolean;
	error?: string;
	message?: string;
	State?: Snapshot;
	Guild?: { Id?: string; [key: string]: unknown };
	Visit?: unknown;
	Rolls?: unknown[];
	Combo?: number;
	ComboMultiplier?: number;
	ComboMax?: number;
	ComboWindow?: number;
	DryRun?: boolean;
	Rebirths?: unknown;
	DomainRank?: unknown;
	Choices?: unknown;
	Level?: unknown;
	Resonance?: unknown;
	Uid?: unknown;
	MultiplierBefore?: unknown;
	MultiplierAfter?: unknown;
	Reward?: unknown;
	StardustReward?: unknown;
	Grade?: unknown;
	Vow?: unknown;
	VowKept?: unknown;
};
type ResponseCallback = (response: ActionResponse) => void;
type Dispatch = (action: string, payload?: Record<string, unknown>, callback?: ResponseCallback) => void;

type Snapshot = Session & {
	Reused?: string[];
	Trade?: { Epoch?: number };
	Overcharge?: { Combo?: number; ComboMultiplier?: number; ComboMax?: number; ComboWindow?: number };
	Daily?: { CanClaim?: boolean; Streak?: number };
	Wheel?: { CanSpin?: boolean };
	ForgePath?: { ClaimedSteps?: number[] };
	CurrentZone?: number;
};

interface ComboReadout {
	combo: number;
	comboMultiplier: number;
	comboMax: number;
	comboWindow: number;
	updatedAt: number;
}

interface DomainUi {
	open?: () => void;
	active?: boolean;
	render?: (state: Session, dispatch: Dispatch, content: React.Element | undefined) => React.Element;
}

interface MainGameProps {
	remotes: {
		Bridge?: Instance;
		Request: RemoteFunction;
		State: RemoteEvent;
		Toast: RemoteEvent;
		Effect: RemoteEvent;
	};
	config: { Game: { Version: string }; [key: string]: unknown };
	bootStartedAt?: number;
	externalBoot?: boolean;
	externalAntilag?: boolean;
	onBootStatus?: (status: Record<string, unknown>) => void;
	domainUi?: DomainUi;
}

export function MainGame(_param: MainGameProps) {
	const { remotes, config, bootStartedAt, externalBoot = false, externalAntilag = false, onBootStatus, domainUi } = _param;
	const destroyFontSamples = () => undefined;

	const appAlive = React.useRef(true);
	const requestWorkers = React.useRef(new Map<thread, true>());
	const requestTimeouts = React.useRef(new Map<thread, true>());
	const deferredJobs = React.useRef(new Map<thread, true>());
	React.useEffect(() => {
		appAlive.current = true;
		return () => {
			appAlive.current = false;
			for (const [worker] of requestWorkers.current) {
				pcall(() => task.cancel(worker));
			}
			for (const [timeout] of requestTimeouts.current) {
				pcall(() => task.cancel(timeout));
			}
			for (const [job] of deferredJobs.current) {
				pcall(() => task.cancel(job));
			}
			table.clear(requestWorkers.current);
			table.clear(requestTimeouts.current);
			table.clear(deferredJobs.current);
		};
	}, []);

	const state = useClientSelector((client) => client.session) as Snapshot | undefined;
	const visit = useClientSelector((client) => client.visit);
	const toastDensity = ((state?.Settings.ToastDensity as number | undefined) ?? 0.55) as number;
	React.useEffect(() => {
		Juice.setToastDensity(toastDensity);
	}, [toastDensity]);
	// tooltips follow the Tooltips switch and calm down with Reduced Motion
	const tooltipsOn = !((state?.Settings.Tooltips as number | undefined) === 0);
	const tooltipsCalm =
		GuiService.ReducedMotionEnabled === true ||
		((tonumber(state?.Settings.MotionIntensity) ?? 1) < 0.3) === true;
	React.useEffect(() => {
		applyAccessibilityTheme(
			((state?.Settings.HighContrast as number | undefined) ?? 0) >= 0.5,
			((state?.Settings.ColorblindMode as number | undefined) ?? 0) >= 0.5,
		);
	}, [state?.Settings.ColorblindMode, state?.Settings.HighContrast]);
	const dispatchStore = useClientDispatch();
	const setVisit = React.useCallback(
		(visitNext: unknown) => dispatchStore(ClientActions.setVisit(visitNext)),
		[dispatchStore],
	);
	const [, setToastsSuppressed] = React.useState(false);
	const purchasePresentationActive = React.useRef(false);
	const setPurchasePresentationActive = React.useCallback((active: boolean) => {
		purchasePresentationActive.current = active;
	}, []);
	const [confettiNonce, setConfettiNonce] = React.useState(0);
	const celebrationSeed = React.useRef(math.random(1, 100000));
	const [bootVisible, setBootVisible] = React.useState(!externalBoot);
	const [shellMounted, setShellMounted] = React.useState(!externalBoot);
	const shellMountedRef = React.useRef(shellMounted);
	shellMountedRef.current = shellMounted;
	const [bootMarks, setBootMarks] = React.useState<Record<string, boolean>>({
		bridge: true,
		remotes: remotes.Request !== undefined && remotes.State !== undefined && remotes.Toast !== undefined && remotes.Effect !== undefined,
		state: false,
		audio: false,
		assets: false,
		fonts: false,
		modules: false,
		shell: false,
		mail: false,
		research: false,
		forge: false,
		trade: false,
		boosts: false,
		settings: false,
		mobile: false,
	});
	const [assetProgress, setAssetProgress] = React.useState({ loaded: 0, total: 0 });
	const [moduleProgress, setModuleProgress] = React.useState({ loaded: 0, total: 0 });
	const onBootExitDone = React.useCallback(() => setBootVisible(false), []);
	const markBoot = React.useCallback((key: string) => {
		setBootMarks((current) => {
			if (current[key]) {
				return current;
			}
			const nextMarks = table.clone(current);
			nextMarks[key] = true;
			return nextMarks;
		});
	}, []);
	// the loading screen's stations follow the checklist
	React.useEffect(() => {
		const Ledger = loadKit<BootLedgerApi>("BootKit", "BootLedger");
		for (const [key, value] of pairs(bootMarks)) {
			if (value) {
				Ledger.mark(key as string);
			}
		}
	}, [bootMarks]);
	const bootReady = Boot.bootChecklistReady(bootMarks);
	const bootFill = Boot.bootProgress(bootMarks);
	const bootReducedMotion = false;
	React.useEffect(() => {
		const assetShare = assetProgress.total > 0 ? math.clamp(assetProgress.loaded / assetProgress.total, 0, 1) : bootMarks.assets ? 1 : 0;
		const moduleShare = moduleProgress.total > 0 ? math.clamp(moduleProgress.loaded / moduleProgress.total, 0, 1) : bootMarks.modules ? 1 : 0;
		onBootStatus?.({
			marks: bootMarks,
			ready: bootReady,
			progress: bootFill * 0.4 + assetShare * 0.3 + moduleShare * 0.3,
			reducedMotion: bootReducedMotion,
			assetsLoaded: assetProgress.loaded,
			assetsTotal: assetProgress.total,
			modulesLoaded: moduleProgress.loaded,
			modulesTotal: moduleProgress.total,
		});
	}, [
		assetProgress.loaded,
		assetProgress.total,
		bootFill,
		bootMarks,
		bootReady,
		bootReducedMotion,
		moduleProgress.loaded,
		moduleProgress.total,
		onBootStatus,
	]);
	const [adminPrank, setAdminPrank] = React.useState<Prank>();
	const [pops, setPops] = React.useState<Array<{ id: number; text: string; color?: Color3; critical?: boolean; offset: number }>>([]);
	const popId = React.useRef(0);
	const [comboReadout, setComboReadout] = React.useState<ComboReadout>();
	const lastComboTier = React.useRef(0);
	const lastNotice = React.useRef({ signature: "", at: 0 });
	const busy = React.useRef<Record<string, number | undefined>>({});
	const inFlight = React.useRef<Record<string, number | undefined>>({});
	const inFlightTotal = React.useRef(0);
	const requestSequence = React.useRef(0);
	const sentAt = React.useRef<Record<string, number | undefined>>({});
	const sentAtCount = React.useRef(0);
	const latestSnapshot = React.useRef(-1);
	const latestRevision = React.useRef(-1);
	const lastTradeEpoch = React.useRef(-1);
	const lastSnapshotPaintAt = React.useRef(-math.huge);
	const loggedFirstSnapshot = React.useRef(false);
	const streakToastSent = React.useRef(false);
	const lastAcceptedSnapshot = React.useRef<Snapshot>();
	const pendingPassive = React.useRef<Snapshot>();
	const passiveFlushJob = React.useRef<thread>();
	const acceptStateRef = React.useRef<(snapshot: Snapshot) => boolean>();
	// the last copy of every section the server sent; pushes leave out unchanged sections (listed in
	// Reused) and they are filled back in from here, keeping the same tables so nothing re-renders for them
	const sectionCache = React.useRef<Record<string, unknown>>({});
	const acceptState = React.useCallback(
		(rawSnapshot: Snapshot): boolean => {
			if (!typeIs(rawSnapshot, "table")) {
				ClientLog.warnEvery("state-envelope", 10, "UI", "ignored a bad state packet");
				return false;
			}
			const cache = sectionCache.current;
			const reused = rawSnapshot.Reused;
			if (reused !== undefined) {
				if (!typeIs(reused, "table")) {
					return false;
				}
				for (const key of reused) {
					let kept = cache[key];
					if (kept === undefined && typeIs(state, "table")) {
						kept = state[key];
					}
					if (kept === undefined) {
						// nothing to fill this from yet; a full snapshot will follow
						if (latestSnapshot.current >= 0) {
							ClientLog.warnEvery("state-reused", 10, "UI", "waiting for a full snapshot");
						}
						return false;
					}
					rawSnapshot[key] = kept;
				}
				rawSnapshot.Reused = undefined;
			}
			for (const [key, value] of pairs(rawSnapshot)) {
				if (typeIs(value, "table")) {
					cache[key as string] = value;
				}
			}
			const candidate = rawSnapshot;
			if (!SnapshotEnvelopeMath.IsValidEnvelope(candidate)) {
				ClientLog.warnEvery("state-envelope", 10, "UI", "ignored an incomplete snapshot");
				return false;
			}
			const snapshot = rawSnapshot;
			if (snapshot.Revision < latestRevision.current) {
				return true;
			}
			if (snapshot.Revision === latestRevision.current && snapshot.SnapshotId < latestSnapshot.current) {
				return true;
			}
			if (snapshot.Revision > latestRevision.current) {
				latestSnapshot.current = snapshot.SnapshotId;
			} else {
				latestSnapshot.current = math.max(latestSnapshot.current, snapshot.SnapshotId);
			}
			const now = os.clock();
			const revisionChanged = snapshot.Revision > latestRevision.current;
			const tradeEpoch = snapshot.Trade?.Epoch ?? -1;
			const tradeHot = tradeEpoch !== lastTradeEpoch.current;
			if (tradeHot) {
				lastTradeEpoch.current = tradeEpoch;
			}
			const passivePaintInterval = UserInputService.TouchEnabled ? 0.7 : 0.45;
			if (pausePassivePaints.current && !revisionChanged && !tradeHot) {
				return true;
			}
			if (latestRevision.current >= 0 && !revisionChanged && !tradeHot && now - lastSnapshotPaintAt.current < passivePaintInterval) {
				pendingPassive.current = snapshot;
				if (passiveFlushJob.current === undefined && appAlive.current) {
					const job = task.delay(
						math.max(0.02, passivePaintInterval - (now - lastSnapshotPaintAt.current)),
						() => {
							passiveFlushJob.current = undefined;
							deferredJobs.current.delete(job);
							const pending = pendingPassive.current;
							pendingPassive.current = undefined;
							const accept = acceptStateRef.current;
							if (pending !== undefined && accept !== undefined && appAlive.current) {
								accept(pending);
							}
						},
					);
					passiveFlushJob.current = job;
					deferredJobs.current.set(job, true);
				}
				return true;
			}
			pendingPassive.current = undefined;
			latestRevision.current = math.max(latestRevision.current, snapshot.Revision);
			lastSnapshotPaintAt.current = now;
			lastAcceptedSnapshot.current = snapshot;
			dispatchStore(ClientActions.setSnapshot(snapshot));
			if (!loggedFirstSnapshot.current) {
				loggedFirstSnapshot.current = true;
				ClientLog.once("profile-ready", "profile", `loaded world ${snapshot.CurrentZone}`);
			}
			return true;
		},
		[dispatchStore],
	);
	acceptStateRef.current = acceptState;
	const notificationDurationRef = React.useRef((state?.Settings.NotificationDuration as number | undefined) ?? 0.55);
	notificationDurationRef.current = (state?.Settings.NotificationDuration as number | undefined) ?? 0.55;
	const addNotice = React.useCallback((title: string, body: unknown, tone?: string, playSound = true): undefined => {
		const toneValue = tone ?? "Info";
		const bodyValue = ActionCopy.friendlyPlayerMessage(body as string | undefined) ?? body;
		const normalizedTitle = NoticeMath.NormalizeTitle(title);
		const signature = NoticeMath.Signature(normalizedTitle, bodyValue, toneValue);
		const now = os.clock();
		if (NoticeMath.ShouldDedupe(lastNotice.current.signature, lastNotice.current.at, signature, now)) {
			return undefined;
		}
		lastNotice.current = { signature, at: now };
		NoticeMath.Record(normalizedTitle, bodyValue, toneValue);
		if (playSound) {
			Audio.play(
				toneValue === "Special"
					? "noticeSpecial"
					: toneValue === "Success"
						? "noticeSuccess"
						: toneValue === "Warning" || toneValue === "Error"
							? "noticeWarning"
							: "noticeInfo",
			);
		}
		// every notice plays in the island (queued until it mounts); there is no other toast surface
		const lifetime = NoticeMath.Lifetime(notificationDurationRef.current);
		const color =
			toneValue === "Special"
				? Palette.violet
				: toneValue === "Success"
					? Palette.mint
					: toneValue === "Warning"
						? Palette.mango
						: toneValue === "Error"
							? Palette.coral
							: Palette.cyan;
		const icon =
			toneValue === "Special"
				? "Gift.17"
				: toneValue === "Success"
					? "Check.23"
					: toneValue === "Warning"
						? "Timer.7"
						: toneValue === "Error"
							? "Close.10"
							: "Wave.14";
		const bodyText = typeIs(bodyValue, "string") ? bodyValue : tostring(bodyValue ?? "");
		Juice.banner(normalizedTitle, bodyText !== "" ? bodyText : undefined, color, icon, lifetime, toneValue);
		return undefined;
	}, []);
	const celebrate = React.useCallback(() => {
		// the reward itself flies as droplets and sparks (JuiceFx) and is announced by the island;
		// this only warms the screen for a moment
		Juice.flash(Palette.cream, 0.14);
	}, []);
	const clearConfetti = React.useCallback((expectedSeed?: number) => {
		setConfettiNonce((current) => (expectedSeed === undefined || current === expectedSeed ? 0 : current));
	}, []);
	const addPop = React.useCallback((text: string, color?: Color3, critical?: boolean) => {
		const id = popId.current + 1;
		popId.current = id;
		setPops((current) => {
			const updated = [...current, { id, text, color, critical, offset: math.random(-90, 90) }];
			const excess = updated.size() - 12;
			if (excess > 0) {
				return updated.filter((_, index) => index >= excess);
			}
			return updated;
		});
		const job = task.delay(POP_SECONDS, () => {
			deferredJobs.current.delete(job);
			if (appAlive.current) {
				setPops((current) => {
					const kept = current.filter((pop) => pop.id !== id);
					return kept.size() === current.size() ? current : kept;
				});
			}
		});
		deferredJobs.current.set(job, true);
	}, []);
	const applyComboReadout = React.useCallback((combo: number, comboMultiplier: number, comboMax: number, comboWindow: number): undefined => {
		if (combo <= 0) {
			return undefined;
		}
		SessionStats.best("bestCombo", combo);
		Juice.activity("combo", { combo, multiplier: comboMultiplier, max: comboMax, window: comboWindow });
		setComboReadout({ combo, comboMultiplier, comboMax, comboWindow, updatedAt: os.clock() });
		return undefined;
	}, []);
	const applyResponse = React.useCallback(
		(responseRaw: ActionResponse, action: string, callback?: ResponseCallback): undefined => {
			const juiceBefore = lastAcceptedSnapshot.current;
			if (GRANT_ACTIONS[action] !== undefined) {
				adopt(responseRaw as never);
			}
			const rawError = responseRaw.error;
			const response = ActionCopy.friendlyActionResponse(responseRaw);
			if (response.State !== undefined) {
				acceptState(response.State);
			}
			if (action === "LeaveGuild" && response.ok === true) {
				dispatchStore(
					ClientActions.patchSession({
						Guild: undefined,
						GuildBonuses: { Production: 0, Capacity: 0, Offline: 0, Automation: 0, Tap: 0 },
					} as Partial<Session>),
				);
			} else if (response.Guild !== undefined) {
				const guild = response.Guild;
				dispatchStore(ClientActions.patchSession({ Guild: guild.Id === "" ? undefined : guild } as Partial<Session>));
			}
			callback?.(response);
			if (!(response.ok === true)) {
				const detail = response.error ?? "Try again in a moment.";
				const lowered = string.lower(rawError ?? detail);
				const expectedBusy =
					(action === "Overcharge" && string.find(lowered, "cooling", 1, true)[0] !== undefined) ||
					string.find(lowered, "still working", 1, true)[0] !== undefined ||
					string.find(lowered, "slow down", 1, true)[0] !== undefined;
				if (!expectedBusy && response.State === undefined && NetworkPolicy.IsOptimistic(action)) {
					const accepted = lastAcceptedSnapshot.current;
					if (accepted !== undefined && appAlive.current) {
						dispatchStore(ClientActions.setSnapshot(accepted));
					}
				}
				if (expectedBusy) {
					return undefined;
				}
				ClientLog.warn("action", `${action} failed — ${rawError ?? detail}`);
				if (AppHelpers.isPassiveRequest(action)) {
					return undefined;
				}
				const gated = string.find(string.lower(detail), "unlock", 1, true)[0] !== undefined;
				addNotice(ActionCopy.failureTitle(action, gated), ActionCopy.failureBody(action, rawError ?? detail), "Warning", false);
				return undefined;
			}
			{
				// game feel: what you gained flies into its counter, what you spent pops in red
				const after = response.State;
				const bigMoment = action === "Rebirth" || action === "DomainExpansion" || action === "Ascend" || action === "UnlockZone";
				const rewarding =
					string.sub(action, 1, 5) === "Claim" ||
					action === "RedeemCode" ||
					action === "StabilizeAnomaly" ||
					action === "SalvageItem" ||
					action === "BulkSalvageItems" ||
					action === "SpinWheel" ||
					bigMoment;
				const spending = string.sub(action, 1, 3) === "Buy" || string.sub(action, 1, 7) === "Upgrade" || action === "DomainLattice";
				if (after !== undefined && (rewarding || spending)) {
					const shown = Juice.celebrateGains(juiceBefore, after, { spend: spending, big: bigMoment, skipVault: true });
					if (rewarding) {
						SessionStats.bump("claims");
					} else if (spending) {
						SessionStats.bump("upgrades");
					}
					if (rewarding && shown > 0) {
						Juice.burst(undefined, Palette.mango, bigMoment ? 1.6 : 1);
					} else if (spending) {
						Juice.ring(undefined, Palette.cyan);
					}
				}
				if (bigMoment) {
					Juice.flash(Palette.cream, 0.45);
					if (action === "Rebirth") {
						Juice.moment(`REBIRTH ${response.Rebirths ?? ""}`, "Production multiplier up.", Palette.violet, "Rebirth.8");
					} else if (action === "DomainExpansion") {
						Juice.moment(`DOMAIN ${response.DomainRank ?? ""}`, "New tree points to spend.", Palette.pink, "Domain.5");
					} else if (action === "UnlockZone") {
						Juice.moment("NEW WORLD", response.message, Palette.cyan, "World.11");
					}
				}
				if (action === "OpenItemCrate" && typeIs(response.Rolls, "table") && response.Rolls.size() > 0) {
					Juice.burst(undefined, Palette.violet, 1.2);
				}
			}
			const machinePurchase = action === "BuyMachine";
			const progressionPurchase =
				action === "BuyResearch" ||
				action === "BuyGridUpgrade" ||
				action === "BuyAnomalyProtocol" ||
				action === "UpgradeContinuum" ||
				action === "UpgradeArtifact" ||
				action === "BuyArtifact" ||
				action === "UpgradeCrew" ||
				action === "BuyGuildUpgrade" ||
				action === "UpgradeItem";
			const purchase = machinePurchase || progressionPurchase || action === "BuySignalOffer" || action === "BuyItemOffer";
			const reward =
				action === "ClaimDaily" ||
				action === "ClaimTimedReward" ||
				action === "ClaimQuest" ||
				action === "ClaimAchievement" ||
				action === "ClaimLabOrder" ||
				action === "ClaimCommanderReward" ||
				action === "ClaimWeeklyDirective" ||
				action === "ClaimSeasonTier" ||
				action === "ClaimExpedition" ||
				action === "ClaimConvergenceReward" ||
				action === "ClaimAnomalyDirective" ||
				action === "ClaimAnomalyMilestone" ||
				action === "ClaimForgePathStep";
			// BuyArtifact opens the artifact reveal, which plays its own sound
			if (purchase && action !== "BuyArtifact") {
				Audio.play(
					machinePurchase
						? "machineInstall"
						: action === "UpgradeArtifact"
							? "artifactUpgrade"
							: progressionPurchase
								? "researchUnlock"
								: "purchase",
				);
				if (action === "BuySignalOffer" || action === "BuyItemOffer") {
					addNotice("Bought", response.message ?? "Purchase complete.", "Success");
				} else if (machinePurchase) {
					addNotice("Upgraded", response.message ?? "Station tuned.", "Success", false);
				} else if (progressionPurchase) {
					addNotice("Upgraded", response.message ?? "Level increased.", "Success", false);
				}
			} else if (reward) {
				let forgePathMajorStep = action === "ClaimForgePathStep";
				if (forgePathMajorStep) {
					forgePathMajorStep = response.State?.ForgePath !== undefined;
					if (forgePathMajorStep) {
						const steps = response.State!.ForgePath!.ClaimedSteps ?? [];
						let maxStep = 0;
						for (const step of steps) {
							maxStep = math.max(maxStep, step);
						}
						forgePathMajorStep = maxStep % 5 === 0;
					}
				}
				if (forgePathMajorStep) {
					Audio.playCelebration(["researchUnlock", "discovery", "reward"], 0.08);
				} else {
					Audio.play(
						action === "ClaimDaily"
							? "dailyClaim"
							: action === "ClaimTimedReward"
								? "timedClaim"
								: action === "ClaimAchievement"
									? "achievementClaim"
									: action === "ClaimSeasonTier" || action === "ClaimConvergenceReward"
										? "seasonClaim"
										: action === "ClaimExpedition"
											? "expeditionReturn"
											: action === "ClaimForgePathStep"
												? "researchUnlock"
												: "missionClaim",
					);
				}
				InteractionFeedback.reward();
				celebrate();
			} else if (action === "ContributeGuild") {
				Audio.play("guildDeposit");
				addNotice("Guild bank", response.message ?? "Contribution deposited.", "Success");
			} else if (action === "CreateGuild") {
				Audio.play("guildCreate");
				addNotice("Guild chartered", response.message ?? "Your hall is open.", "Special");
			} else if (action === "JoinGuild") {
				Audio.play("guildJoin");
				addNotice("Guild", response.message ?? "You're in.", "Success");
			} else if (action === "LeaveGuild") {
				Audio.play("guildLeave");
				addNotice("Guild", response.message ?? "Left the guild.", "Info");
			} else if (action === "DisbandGuild") {
				Audio.play("guildLeave");
				addNotice("Guild disbanded", response.message ?? "The guild is gone.", "Info");
			} else if (action === "KickGuildMember") {
				Audio.play("memberRemove");
				addNotice("Crew removed", response.message ?? "They're out of the guild.", "Info");
			} else if (action === "SetGuildRole") {
				Audio.play("roleChange");
				addNotice("Role updated", response.message ?? "Role changed.", "Success");
			} else if (action === "SalvageItem") {
				Audio.play("salvage");
				addNotice("Salvaged", response.message ?? "Dust recovered.", "Success");
			} else if (action === "EchoAct") {
				// the echoes screen plays its own moments; the reply only needs a sound
				Audio.play(
					response.Choices !== undefined
						? "echoCapture"
						: response.Level !== undefined
							? "echoTune"
							: response.Resonance !== undefined
								? "echoDismantle"
								: response.Uid !== undefined
									? "echoClaim"
									: "echoEquip",
				);
			} else if (action === "LaunchExpedition") {
				Audio.play("expeditionLaunch");
				addNotice("Expedition", response.message ?? "They're out.", "Success");
			} else if (action === "EquipArtifact") {
				Audio.play("artifactEquip");
				addNotice("Equipped", response.message ?? "Loadout updated.", "Info");
			} else if (action === "EquipTitle") {
				Audio.play("badgeEarn");
				addNotice("Title equipped", response.message ?? "Title updated.", "Success", false);
			} else if (action === "ClaimStoryChapter") {
				Audio.play("unlock");
				InteractionFeedback.reward();
				celebrate();
			} else if (action === "ClaimMail" || action === "ClaimAllMail") {
				Audio.play("mailClaim");
				InteractionFeedback.reward();
				celebrate();
			} else if (action === "RedeemCode") {
				Audio.play("codeReward");
				InteractionFeedback.reward();
				celebrate();
				addNotice("Code claimed", response.message ?? "Reward claimed.", "Special");
			} else if (action === "VerifyCreatorFollow") {
				const already = string.find(string.lower(response.message ?? ""), "already", 1, true)[0] !== undefined;
				if (!already) {
					Audio.play("codeReward");
					InteractionFeedback.reward();
					celebrate();
				}
				addNotice("Follow reward", response.message ?? "Thanks for following.", already ? "Info" : "Special");
			} else if (action === "StudioGrantProduct") {
				Audio.play("purchase");
			} else if (action === "AdminExecute") {
				const message = response.message ?? "Done.";
				if (response.DryRun === true) {
					addNotice("Preview ready", message, "Info");
				} else {
					Audio.play("confirm");
					addNotice("Change applied", message, "Success");
				}
			} else if (action === "InviteTrade") {
				Audio.play("invite");
				addNotice("Trade invite", response.message ?? "Invite sent.", "Info");
			} else if (action === "RespondTrade") {
				Audio.play("confirm");
			} else if (action === "ConfirmTrade") {
				Audio.play("purchase");
				addNotice("Trade", response.message ?? "Trade finished.", "Success");
			} else if (action === "CancelTrade") {
				Audio.play("close");
			} else if (action === "SpinWheel") {
			} else if (action === "OpenItemCrate") {
				if ((response.Rolls !== undefined && typeIs(response.Rolls, "table") ? response.Rolls.size() : 0) === 0) {
					celebrate();
				}
			} else if (action === "RouteLabPower") {
				Audio.play("labRoute");
			} else if (action === "SetAutoForge") {
				Audio.play("autoForge");
				addNotice("Auto-Forge", response.message ?? "Auto-forge set.", "Info");
			} else if (action === "SetAnomalyChannel") {
				Audio.play("toggleOn");
			} else if (action === "ActivateAnomalySurge") {
				Audio.play("reactorSurge");
			} else if (action === "DeleteMail") {
				Audio.play("close");
			} else if (action === "DomainExpansion") {
				Audio.play("domainImpact");
				const rewardJob = task.delay(0.2, () => {
					deferredJobs.current.delete(rewardJob);
					if (appAlive.current) {
						Audio.playCelebration(["domainReward", "discovery"], 0.1);
					}
				});
				deferredJobs.current.set(rewardJob, true);
				InteractionFeedback.reward();
				celebrate();
			} else if (action === "Rebirth") {
				// the ceremony owns the rebirth cues and timing; the notice still lands for the log
				RebirthCeremony.play({
					rebirths: response.Rebirths,
					before: response.MultiplierBefore,
					after: response.MultiplierAfter,
					reward: response.Reward,
					stardust: response.StardustReward,
					grade: response.Grade,
					vow: response.Vow,
					vowKept: response.VowKept,
				});
				celebrate();
				addNotice("Rebirth done", response.message ?? "The forge starts over, stronger.", "Special");
			} else if (action === "SetSetting") {
				if (response.message !== undefined && response.message !== "Setting updated.") {
					addNotice("Preset on", response.message, "Success");
				}
			} else if (action === "SetMobileLayout") {
			} else if (action === "ActivateBoost") {
				Audio.play("boostActivate");
				addNotice("Boost on", response.message ?? "Timer started.", "Success");
			} else if (action === "UnlockZone") {
				Audio.play("zoneUnlock");
				InteractionFeedback.reward();
				celebrate();
				addNotice("World unlocked", response.message ?? "A new world is open.", "Special", false);
			} else if (action === "NudgeCrew") {
				Audio.play("crewNudge");
				addNotice("Waved", response.message ?? "They’ll see it.", "Info");
			} else if (action === "VisitPlot") {
				const arrived = response.Visit ?? (response.State as { Visit?: unknown } | undefined)?.Visit;
				if (arrived !== undefined) {
					Audio.play("travel");
					if (response.Visit) {
						setVisit(response.Visit);
					}
					addNotice("Visiting", response.message ?? "You're in their shop.", "Info");
				} else {
					// the server said yes but sent no visit back; don't claim we arrived
					addNotice("Couldn't visit", "That forge didn't open. Try again in a moment.", "Warning", false);
				}
			} else if (action === "LeavePlot") {
				Audio.play("close");
				setVisit(undefined);
			} else if (action === "SelectZone") {
				Audio.play("zoneSelect");
			} else if (action === "EquipItem") {
				Audio.play("itemLink");
			} else if (action === "UnequipItem") {
				Audio.play("itemUnlink");
			} else if (action === "EquipBestItems") {
				Audio.play("itemLink");
				InteractionFeedback.tap();
				addNotice("Loadout optimized", response.message ?? "Best relics equipped.", "Success", false);
			} else if (action === "BulkSalvageItems") {
				Audio.play("salvage");
				InteractionFeedback.tap();
				addNotice("Salvaged", response.message ?? "Relics broken down.", "Success", false);
			} else if (action === "ToggleItemLock") {
				Audio.play("toggleOn");
				addNotice("Relic", response.message ?? "Lock updated.", "Info", false);
			} else if (action === "StabilizeAnomaly") {
				Audio.play("reactorStabilize");
				InteractionFeedback.reward();
				celebrate();
			} else if (action === "CompleteTutorial") {
				InteractionFeedback.reward();
				celebrate();
			} else if (action === "CollectVault") {
				Audio.play("vaultDeposit");
				InteractionFeedback.reward();
				InteractionFeedback.confirm();
				celebrate();
			} else if (action === "Overcharge") {
				if (response.Combo !== undefined && response.ComboMultiplier !== undefined) {
					applyComboReadout(response.Combo, response.ComboMultiplier, response.ComboMax ?? 12, response.ComboWindow ?? 1.8);
				}
			} else if (action === "PulseAnomaly") {
				Audio.play("reactorPulse");
			} else if (action === "ClaimAnomalyDirective" || action === "ClaimAnomalyMilestone") {
				Audio.play("collect");
				InteractionFeedback.reward();
			} else if (
				response.message !== undefined &&
				action !== "Overcharge" &&
				action !== "ActivateBoost" &&
				action !== "RouteLabPower" &&
				action !== "SetTutorialStep" &&
				action !== "ReplayTutorial" &&
				action !== "DismissRelease" &&
				action !== "OpenRelease" &&
				action !== "ReadStoryChapter" &&
				action !== "ReadMail" &&
				action !== "SetSetting" &&
				action !== "SetMobileLayout" &&
				action !== "ChatOpenWhisper" &&
				action !== "ChatGlobal" &&
				action !== "VisitPlot" &&
				action !== "LeavePlot" &&
				action !== "SyncShop" &&
				action !== "GetPlayers" &&
				action !== "GetLeaderboard" &&
				action !== "GetGuildLeaderboard" &&
				action !== "GetGuild" &&
				action !== "GetGuildChatHistory" &&
				action !== "GetGuildAnnouncements" &&
				action !== "GetGuildSettings" &&
				action !== "GetGuildLogoReview" &&
				action !== "SendGuildChat" &&
				action !== "CreateGuildAnnouncement" &&
				action !== "EditGuildAnnouncement" &&
				action !== "PinGuildAnnouncement" &&
				action !== "ArchiveGuildAnnouncement" &&
				action !== "SetGuildAnnouncementExpiry" &&
				action !== "SetGuildSettings" &&
				action !== "MuteGuildMember" &&
				action !== "UnmuteGuildMember" &&
				action !== "BanGuildMember" &&
				action !== "UnbanGuildMember" &&
				action !== "UploadGuildLogo" &&
				action !== "ModerateGuildLogo" &&
				action !== "GetTrade" &&
				action !== "UpdateTradeOffer" &&
				action !== "SetTradeReady" &&
				action !== "VerifyCreatorFollow" &&
				action !== "RedeemCode"
			) {
				addNotice("Done", response.message, "Info");
			}
			return undefined;
		},
		[acceptState, addNotice, applyComboReadout, celebrate, dispatchStore, setVisit],
	);
	const dispatch: Dispatch = React.useCallback(
		(action: string, payload: Record<string, unknown> = {}, callback?: ResponseCallback): undefined => {
			let value = typeIs(payload, "table") ? payload : {};
			const signature = AppHelpers.actionSignature(action, value);
			const pipelined = NetworkPolicy.IsPipelined(action);
			const reject = (message: string, uncertain?: boolean) => {
				callback?.({ ok: false, error: message, Uncertain: uncertain === true });
			};
			// Pre-flight refusals never reach the server, so applyResponse can't explain them.
			// Say something for real actions; background reads stay quiet.
			const refuse = (message: string) => {
				if (!AppHelpers.isPassiveRequest(action)) {
					Juice.status(message, "error");
				}
				reject(message);
			};
			if (!appAlive.current) {
				return undefined;
			}
			if (GRANT_ACTIONS[action] !== undefined) {
				if (!isAuthed()) {
					let settled = false;
					whenAuthed(() => {
						if (settled || !appAlive.current) {
							return;
						}
						settled = true;
						dispatch(action, payload, callback);
					});
					const authJob = task.delay(4, () => {
						deferredJobs.current.delete(authJob);
						if (settled || !appAlive.current) {
							return;
						}
						settled = true;
						if (isAuthed()) {
							dispatch(action, payload, callback);
							return;
						}
						refuse("Still connecting. Give it a second and try again.");
					});
					return undefined;
				}
				value = table.clone(value);
				attachGrantFields(value);
			}
			if (!pipelined && busy.current[signature] !== undefined) {
				reject("Already working on that.");
				return undefined;
			}
			const activeRequests = inFlight.current[signature] ?? 0;
			const requestLimit = NetworkPolicy.RequestLimit(pipelined);
			if (activeRequests >= requestLimit) {
				reject("Still working on your last tap.");
				return undefined;
			}
			if (inFlightTotal.current >= NetworkPolicy.MAX_PHYSICAL_REQUESTS) {
				refuse("Lots going on right now. Try that again in a moment.");
				return undefined;
			}
			const now = os.clock();
			const cooldown = NetworkPolicy.Cooldown(action);
			const previous = sentAt.current[signature];
			if (previous !== undefined && NetworkPolicy.IsCoolingDown(now, previous, cooldown)) {
				reject("Slow down a sec.");
				return undefined;
			}
			if (previous === undefined) {
				sentAtCount.current += 1;
			}
			sentAt.current[signature] = now;
			if (sentAtCount.current > 256) {
				let remaining = 0;
				for (const [key, timestamp] of pairs(sentAt.current)) {
					if (now - (timestamp as number) > 60) {
						sentAt.current[key as string] = undefined;
					} else {
						remaining += 1;
					}
				}
				if (remaining > 384) {
					// Evict oldest timestamps first so unrelated action signatures do not
					// lose their cooldowns arbitrarily.
					const entries: Array<{ key: string; timestamp: number }> = [];
					for (const [key, timestamp] of pairs(sentAt.current)) {
						entries.push({ key: key as string, timestamp: timestamp as number });
					}
					entries.sort((a, b) => a.timestamp < b.timestamp);
					const target = remaining - 256;
					for (let i = 0; i < target; i++) {
						sentAt.current[entries[i].key] = undefined;
					}
					remaining -= target;
				}
				sentAtCount.current = remaining;
			}
			if (action === "CollectVault" || action === "Overcharge") {
				// instant game feel on the press itself, from the state the player is looking at
				const store = getActiveClientStore();
				const session = store?.getState().session;
				if (action === "CollectVault" && session !== undefined && asFlux(session.Vault) > 0) {
					SessionStats.bump("collects");
					SessionStats.addFlux(session.Vault);
				} else if (action === "Overcharge") {
					SessionStats.bump("overcharges");
				}
				if (session !== undefined && action === "CollectVault" && asFlux(session.Vault) > 0) {
					Juice.number(`+${compactNumber(session.Vault)} flux`, Palette.cyan, { icon: "Flux.19", big: true });
					Juice.coins("FLUX", Palette.cyan, "Flux", 10);
					Juice.burst(undefined, Palette.cyan, 1);
				} else if (session !== undefined && action === "Overcharge" && session.TapPower !== undefined) {
					Juice.number(`+${compactNumber(session.TapPower)}`, Palette.mango, { icon: "Flux.20" });
					Juice.coins("VAULT", Palette.mango, "Flux", 3);
				}
			} else if (string.sub(action, 1, 5) === "Claim") {
				// a claim answers on the press; the amounts fly in when the server confirms
				Juice.burst(undefined, Palette.mango, 0.7);
			}
			if (NetworkPolicy.IsOptimistic(action)) {
				dispatchStore(ClientActions.applyOptimistic(action, value, config.Game.Version));
			}
			if (action === "Overcharge" || action === "PulseAnomaly") {
				Audio.play("reactorPulse");
			} else if (action === "CollectVault") {
				Audio.play("vaultBank");
			}
			const requestToken = requestSequence.current + 1;
			requestSequence.current = requestToken;
			inFlight.current[signature] = activeRequests + 1;
			inFlightTotal.current += 1;
			if (!pipelined) {
				busy.current[signature] = requestToken;
			}
			let requestTimedOut = false;
			let requestReleased = false;
			const releaseRequest = () => {
				if (requestReleased) {
					return;
				}
				requestReleased = true;
				const remaining = (inFlight.current[signature] ?? 1) - 1;
				if (remaining > 0) {
					inFlight.current[signature] = remaining;
				} else {
					inFlight.current[signature] = undefined;
				}
				inFlightTotal.current = math.max(0, inFlightTotal.current - 1);
			};
			let requestTimeout: thread | undefined;
			let requestWorker: thread | undefined;
			const timeoutSeconds = NetworkPolicy.Timeout(action);
			requestTimeout = task.delay(timeoutSeconds, () => {
				if (requestTimeout !== undefined) {
					requestTimeouts.current.delete(requestTimeout);
				}
				requestTimeout = undefined;
				const ownsControl = pipelined || busy.current[signature] === requestToken;
				if (!pipelined && ownsControl) {
					busy.current[signature] = undefined;
				}
				requestTimedOut = true;
				releaseRequest();
				if (!appAlive.current || !ownsControl) {
					return;
				}
				if (NetworkPolicy.IsOptimistic(action)) {
					const accepted = lastAcceptedSnapshot.current;
					if (accepted !== undefined) {
						dispatchStore(ClientActions.setSnapshot(accepted));
					}
				}
				ClientLog.warnEvery(`timeout:${action}`, 8, "UI", `${action} timed out after ${timeoutSeconds}s`);
				addNotice("Connection hiccup", "That action timed out. You can try it again now.", "Info", false);
				reject("That took too long. Try again.", true);
			});
			requestTimeouts.current.set(requestTimeout, true);
			requestWorker = task.defer(() => {
				const [ok, raw] = pcall(() => remotes.Request.InvokeServer(action, value));
				if (requestWorker !== undefined) {
					requestWorkers.current.delete(requestWorker);
				}
				requestWorker = undefined;
				if (requestTimeout !== undefined) {
					task.cancel(requestTimeout);
					requestTimeouts.current.delete(requestTimeout);
					requestTimeout = undefined;
				}
				if (!pipelined && busy.current[signature] === requestToken) {
					busy.current[signature] = undefined;
				}
				releaseRequest();
				if (!appAlive.current) {
					return;
				}
				if (requestTimedOut) {
					if (ok && typeIs(raw, "table")) {
						const lateResponse = raw as ActionResponse;
						if (GRANT_ACTIONS[action] !== undefined) {
							adopt(lateResponse as never);
						}
						if (lateResponse.State !== undefined) {
							acceptState(lateResponse.State);
						}
					}
					return;
				}
				if (!ok || !typeIs(raw, "table") || !typeIs((raw as ActionResponse).ok, "boolean")) {
					ClientLog.warnEvery(`request:${action}`, 5, "UI", `${action} got no answer`);
					addNotice("Connection hiccup", "That tap didn't go through. Try again.", "Info", false);
					reject("That tap didn't go through. Try again.", true);
					return;
				}
				applyResponse(raw as ActionResponse, action, callback);
			});
			requestWorkers.current.set(requestWorker, true);
			return undefined;
		},
		[acceptState, addNotice, applyResponse, config.Game.Version, dispatchStore, remotes],
	);
	useClientIntegrityProbe(dispatch);
	React.useEffect(() => {
		if (state === undefined) {
			return;
		}
		if (state.Daily?.CanClaim !== true) {
			streakToastSent.current = false;
			return;
		}
		if (streakToastSent.current) {
			return;
		}
		if (state.Daily.CanClaim === true && (state.Daily.Streak ?? 0) >= 1) {
			streakToastSent.current = true;
			const day = state.Daily.Streak ?? 0;
			addNotice(
				"Daily streak",
				day > 1 ? `Day ${day} is ready to claim in Rewards.` : "Today’s daily is ready in Rewards.",
				"Special",
			);
		}
	}, [addNotice, state?.Daily?.CanClaim, state?.Daily?.Streak]);
	const spinToastSent = React.useRef(false);
	React.useEffect(() => {
		if (state?.Wheel?.CanSpin !== true) {
			spinToastSent.current = false;
			return;
		}
		if (spinToastSent.current) return;
		spinToastSent.current = true;
		addNotice("Free spin", "The wheel's ready for you. Head to Rewards to spin it.", "Special");
	}, [addNotice, state?.Wheel?.CanSpin]);
	React.useEffect(() => {
		const snapshotCombo = state?.Overcharge;
		if (snapshotCombo === undefined || (snapshotCombo.Combo ?? 0) <= 0 || comboReadout !== undefined) {
			return;
		}
		setComboReadout({
			combo: snapshotCombo.Combo!,
			comboMultiplier: snapshotCombo.ComboMultiplier!,
			comboMax: snapshotCombo.ComboMax!,
			comboWindow: snapshotCombo.ComboWindow!,
			updatedAt: os.clock(),
		});
	}, [comboReadout, state?.Overcharge]);
	React.useEffect(() => {
		let alive = true;
		let fontWorker: thread | undefined;
		let fontTimeout: thread | undefined;
		let moduleWorker: thread | undefined;
		let stateWorker: thread | undefined;
		const cancelWorker = (worker?: thread) => {
			if (worker !== undefined) {
				pcall(() => task.cancel(worker));
			}
		};
		const stateConnection = remotes.State.OnClientEvent.Connect((snapshot) => {
			if (!alive || !typeIs(snapshot, "table")) {
				return;
			}
			if (!acceptState(snapshot as Snapshot)) {
				return;
			}
			markBoot("bridge");
			markBoot("state");
		});
		const toastConnection = remotes.Toast.OnClientEvent.Connect((payload) => {
			if (!alive || !typeIs(payload, "table")) {
				return;
			}
			const value = payload as { Tone?: string; Title?: unknown; Body?: unknown };
			addNotice(tostring(value.Title ?? "Update"), tostring(value.Body ?? "Something changed."), value.Tone ?? "Info");
		});
		const effectConnection = remotes.Effect.OnClientEvent.Connect((payload) => {
			if (!alive || !typeIs(payload, "table")) {
				return;
			}
			const value = payload as Record<string, unknown> & { UserId?: unknown };
			const kind = tostring(value.Type ?? "");
			const amount = typeIs(value.Amount, "number") ? (value.Amount as number) : 0;
			if (kind === "Collect" && amount > 0) {
				// the press already showed the gain where you tapped (JuiceFx)
			} else if (kind === "Overcharge" && amount > 0) {
				if (value.Critical === true) {
					Juice.number("CRIT!", Palette.mango, { big: true });
					SessionStats.bump("crits");
					Juice.burst(undefined, Palette.mango, 0.8);
				}
				const combo = typeIs(value.Combo, "number") ? (value.Combo as number) : undefined;
				const comboMultiplier = typeIs(value.ComboMultiplier, "number") ? (value.ComboMultiplier as number) : undefined;
				if (combo !== undefined && comboMultiplier !== undefined) {
					const comboMax = typeIs(value.ComboMax, "number") ? (value.ComboMax as number) : 12;
					const comboWindow = typeIs(value.ComboWindow, "number") ? (value.ComboWindow as number) : 1.8;
					applyComboReadout(combo, comboMultiplier, comboMax, comboWindow);
					if (combo <= 1) {
						lastComboTier.current = 0;
					}
					const tier = math.floor((combo / math.max(1, comboMax)) * 4);
					if (tier > lastComboTier.current && combo < comboMax) {
						Audio.play("tick");
					} else if (combo >= comboMax && lastComboTier.current < 4) {
						Audio.play("unlock");
					}
					lastComboTier.current = combo >= comboMax ? 4 : tier;
				}
			} else if (kind === "Ascension") {
				Audio.play("discovery");
				celebrate();
				if (value.UserId === Players.LocalPlayer.UserId) {
					Juice.moment(`ASCENSION ${value.Rank ?? ""}`, "Aether earned. Spend it on sigils.", Palette.mango, "Rebirth.9");
				}
			} else if (kind === "FeatureUnlocked" && !purchasePresentationActive.current) {
				Audio.play("unlock");
				InteractionFeedback.reward();
				celebrate();
				const featureName = value.Name ?? value.Feature ?? value.Id;
				Juice.moment(
					featureName !== undefined ? `${string.upper(tostring(featureName))} UNLOCKED` : "NEW FEATURE",
					"Find it in the menu.",
					Palette.mint,
					"Check.24",
				);
			} else if (kind === "LevelUp" && !purchasePresentationActive.current) {
				LevelMoments.pushLevelMoment(value);
				InteractionFeedback.reward();
				celebrate();
			} else if (kind === "ServerEvent") {
				ServerEventsUi.pushServerEvent(value);
			} else if (kind === "LevelReward") {
				LevelMoments.pushLevelMoment(value);
			} else if (kind === "AnomalyPulse") {
				Audio.play("reactor");
			} else if (kind === "AnomalyReady") {
				Audio.play("reactorReady");
			} else if (kind === "AnomalyStabilized") {
				Audio.play("discovery");
			} else if (kind === "ItemLinked") {
				Audio.play("equip");
			} else if (
				kind === "GuildChat" ||
				kind === "GuildAnnouncement" ||
				kind === "GuildSettings" ||
				kind === "GuildLogo" ||
				kind === "GuildModeration"
			) {
				if (kind === "GuildAnnouncement") {
					Audio.play("guildAnnounce");
				} else if (kind !== "GuildChat") {
					Audio.play("collect");
				}
			} else if (kind === "GuildBanned") {
				addNotice("Guild ban", "You have been removed from this guild.", "Warning");
			} else {
				if (kind === "VisitUpdate" && typeIs(value.Visit, "table")) {
					setVisit(value.Visit);
				} else if (kind === "VisitEnded") {
					setVisit(undefined);
				} else if (kind === "CrewState") {
					const wasInCrew = CrewStore.get().crew !== undefined;
					CrewStore.set({ crew: typeIs(value.Crew, "table") ? value.Crew : CrewStore.NONE });
					if (value.Crew === undefined && wasInCrew && typeIs(value.Reason, "string")) {
						addNotice("Crew", value.Reason as string, "Info");
					}
				} else if (kind === "CrewInvite") {
					CrewStore.set({
						invite: {
							FromUserId: value.FromUserId,
							FromName: value.FromName,
							CrewName: value.CrewName,
							ExpiresAt: value.ExpiresAt,
						},
					});
					Audio.play("invite");
					addNotice(
						"Crew invite",
						`${tostring(value.FromName ?? "Someone")} invited you to ${tostring(value.CrewName ?? "a crew")}. Open Crew to answer.`,
						"Special",
					);
				} else if (kind === "CrewNotice") {
					addNotice("Crew", tostring(value.Text ?? ""), "Info");
				} else if (kind === "CrewNudge") {
					Audio.play("crewNudge");
					InteractionFeedback.tap();
					const from = tostring(value.FromName ?? "Someone");
					addNotice("Crew nudge", `${from} waved at you.`, "Special");
				} else if (kind === "DomainExpansion" && tonumber(value.UserId) !== Players.LocalPlayer.UserId) {
					Audio.play("domainImpact");
					addNotice("Domain nearby", `Someone opened Domain ${math.floor(tonumber(value.Rank) ?? 1)}.`, "Special");
				} else if (kind === "AdminPrank") {
					const prankKind = tostring(value.Kind ?? "Jumpscare");
					const duration = math.clamp(tonumber(value.Duration) ?? 6, 2, 20);
					const caption = tostring(value.Caption ?? "");
					setAdminPrank({ kind: prankKind, endsAt: os.clock() + duration, caption, duration });
					Audio.play("adminExecute");
				}
			}
		});
		markBoot("remotes");
		Audio.start();
		Audio.whenWarm(() => {
			if (alive) {
				markBoot("audio");
			}
		});
		const fontFaces = [
			Font.fromEnum(Enum.Font.BuilderSans),
			Font.fromEnum(Enum.Font.BuilderSansMedium),
			Font.fromEnum(Enum.Font.BuilderSansBold),
			Font.fromEnum(Enum.Font.BuilderSansExtraBold),
			Font.fromEnum(Enum.Font.RobotoMono),
			Font.fromEnum(Enum.Font.Code),
			new Font("rbxasset://fonts/families/GothamSSm.json"),
		];
		let fontFinished = false;
		fontWorker = task.spawn(() => {
			pcall(() => ContentProvider.PreloadAsync(fontFaces as unknown as Instance[]));
			if (fontFinished) {
				return;
			}
			fontFinished = true;
			if (alive) {
				markBoot("fonts");
			}
		});
		fontTimeout = task.delay(6, () => {
			if (fontFinished) {
				return;
			}
			fontFinished = true;
			cancelWorker(fontWorker);
			fontWorker = undefined;
			destroyFontSamples();
			if (alive) {
				markBoot("fonts");
			}
		});
		moduleWorker = task.spawn(() => {
			const deadline = os.clock() + Boot.BOOT_MODULE_TIMEOUT;
			const waitChild = (parent: Instance, name: string, budget: number) => {
				const left = math.max(0.05, deadline - os.clock());
				return parent.WaitForChild(name, math.min(budget, left));
			};
			pcall(() => {
				const astral = waitChild(ReplicatedStorage, "AstralForge", 4);
				if (astral !== undefined) {
					waitChild(astral, "Shared", 3);
					const shared = astral.FindFirstChild("Shared");
					if (shared !== undefined) {
						const spinner = waitChild(shared, "NumberSpinner", 3);
						if (spinner !== undefined && spinner.IsA("ModuleScript")) {
							pcall(() => require(spinner));
						}
					}
					const vendor = astral.FindFirstChild("Vendor") ?? waitChild(astral, "Vendor", 2);
					if (vendor !== undefined) {
						const vendorSpinner = vendor.FindFirstChild("NumberSpinner");
						if (vendorSpinner !== undefined && vendorSpinner.IsA("ModuleScript")) {
							pcall(() => require(vendorSpinner));
						}
					}
				}
				const playerScripts =
					Players.LocalPlayer.FindFirstChild("PlayerScripts") ??
					Players.LocalPlayer.WaitForChild("PlayerScripts", math.max(0.1, deadline - os.clock()));
				if (playerScripts !== undefined) {
					waitChild(playerScripts, "AstralForge", 3);
				}
				pcall(() => {
					const starterScripts = StarterPlayer.FindFirstChild("StarterPlayerScripts");
					if (starterScripts !== undefined) {
						starterScripts.FindFirstChild("AstralForge");
					}
				});
				warmClientModules((loaded, total) => {
					if (alive) {
						setModuleProgress({ loaded, total });
					}
				});
			});
			if (alive) {
				markBoot("modules");
			}
		});
		stateWorker = task.spawn(() => {
			let attempt = 0;
			let lastConnectNotice = 0;
			while (alive && latestSnapshot.current < 0) {
				const bridgeReady = remotes.Bridge !== undefined && remotes.Bridge.GetAttribute("Ready") === true;
				if (bridgeReady) {
					markBoot("bridge");
				}
				if (bridgeReady) {
					const [ok, raw] = pcall(() => remotes.Request.InvokeServer("GetState", {}));
					if (alive && ok && typeIs(raw, "table")) {
						const response = raw as ActionResponse;
						if (response.State !== undefined && acceptState(response.State)) {
							markBoot("state");
							break;
						}
					}
				}
				attempt += 1;
				if (alive && attempt >= 20 && os.clock() - lastConnectNotice > 30) {
					lastConnectNotice = os.clock();
					addNotice(
						"Still connecting",
						"Your save is taking longer than usual to load. If Astral Forge is open on another device, close it there.",
						"Info",
						false,
					);
				}
				task.wait(math.min(0.2 + attempt * 0.08, 1.5));
			}
			if (alive && remotes.Bridge !== undefined && remotes.Bridge.GetAttribute("Ready") === true) {
				markBoot("bridge");
			}
		});
		return () => {
			alive = false;
			fontFinished = true;
			cancelWorker(fontWorker);
			cancelWorker(fontTimeout);
			cancelWorker(moduleWorker);
			cancelWorker(stateWorker);
			destroyFontSamples();
			stateConnection.Disconnect();
			toastConnection.Disconnect();
			effectConnection.Disconnect();
		};
	}, [acceptState, addNotice, addPop, applyComboReadout, celebrate, markBoot, remotes]);
	const stateLoaded = state !== undefined;
	React.useEffect(() => {
		if (!stateLoaded) {
			return;
		}
		let connection: RBXScriptConnection | undefined;
		const token = task.defer(() => {
			setShellMounted(true);
			let frames = 0;
			connection = RunService.Heartbeat.Connect(() => {
				frames += 1;
				if (frames < 2) {
					return;
				}
				connection?.Disconnect();
				connection = undefined;
				markBoot("shell");
				markBoot("mail");
				markBoot("research");
				markBoot("forge");
				markBoot("trade");
				markBoot("boosts");
				markBoot("settings");
				markBoot("mobile");
			});
		});
		return () => {
			task.cancel(token);
			connection?.Disconnect();
		};
	}, [markBoot, stateLoaded]);
	React.useEffect(() => {
		return preloadMountedGame(
			() => markBoot("assets"),
			(loaded, total) => setAssetProgress({ loaded, total }),
			() => shellMountedRef.current,
		);
	}, [markBoot]);
	React.useEffect(() => {
		Audio.start();
		Audio.configurePreferences({
			UiVolume: state?.Settings.UiVolume,
			GameplayVolume: state?.Settings.GameplayVolume,
			RewardVolume: state?.Settings.RewardVolume,
			AmbientVolume: state?.Settings.AmbientVolume,
			HoverSounds: state?.Settings.HoverSounds,
			NotificationSounds: state?.Settings.NotificationSounds,
			PageMusic: state?.Settings.PageMusic,
			SoundVariation: state?.Settings.SoundVariation,
		});
		Audio.setVolume((state?.Settings.SoundVolume as number | undefined) ?? 0.75);
		Audio.setMusicVolume((state?.Settings.MusicVolume as number | undefined) ?? 1);
		Audio.setSfxVolume((state?.Settings.SfxVolume as number | undefined) ?? 1);
	}, [
		state?.Settings.AmbientVolume,
		state?.Settings.GameplayVolume,
		state?.Settings.HoverSounds,
		state?.Settings.SoundVariation,
		state?.Settings.MusicVolume,
		state?.Settings.NotificationSounds,
		state?.Settings.PageMusic,
		state?.Settings.RewardVolume,
		state?.Settings.SfxVolume,
		state?.Settings.SoundVolume,
		state?.Settings.UiVolume,
	]);
	React.useEffect(() => {
		setScrollSpeed((state?.Settings.ScrollSpeed as number | undefined) ?? 0.65);
		setScrollMomentum((state?.Settings.ScrollMomentum as number | undefined) ?? 0.75);
		setHapticIntensity((state?.Settings.HapticIntensity as number | undefined) ?? 0.65);
	}, [state?.Settings.HapticIntensity, state?.Settings.ScrollMomentum, state?.Settings.ScrollSpeed]);
	const motionIntensity = (state?.Settings.MotionIntensity as number | undefined) ?? 1;
	const softFeel = GuiService.ReducedMotionEnabled === true || motionIntensity < 0.3;
	React.useEffect(() => {
		// non-React effects (button press motion, screen flashes, companion sprites) read this
		setInGameReducedMotion(motionIntensity < 0.3);
	}, [motionIntensity]);
	const screenFlashesSetting = (state?.Settings.ScreenFlashes as number | undefined) ?? 0.8;
	const confettiSetting = (state?.Settings.ConfettiEnabled as number | undefined) ?? 1;
	React.useEffect(() => {
		setEffectSwitches(screenFlashesSetting >= 0.5, confettiSetting >= 0.5);
	}, [screenFlashesSetting, confettiSetting]);
	const viewportSpeed = (state?.Settings.ViewportSpeed as number | undefined) ?? 1;
	const [viewportTick, setViewportTick] = React.useState(0);
	React.useEffect(() => {
		let sizeConnection: RBXScriptConnection | undefined;
		const attach = () => {
			if (sizeConnection !== undefined) {
				sizeConnection.Disconnect();
				sizeConnection = undefined;
			}
			const camera = WorkspaceService.CurrentCamera;
			if (camera !== undefined) {
				sizeConnection = camera.GetPropertyChangedSignal("ViewportSize").Connect(() => {
					setViewportTick((current) => current + 1);
				});
			}
		};
		attach();
		const cameraConnection = WorkspaceService.GetPropertyChangedSignal("CurrentCamera").Connect(() => {
			attach();
			setViewportTick((current) => current + 1);
		});
		return () => {
			cameraConnection.Disconnect();
			sizeConnection?.Disconnect();
		};
	}, []);
	const rawViewportSize = WorkspaceService.CurrentCamera?.ViewportSize ?? new Vector2(1280, 720);
	const isTouchUiHere = !usesDesktopStructure(rawViewportSize.X, rawViewportSize.Y) && UserInputService.TouchEnabled;
	const textScale = isTouchUiHere
		? 0.92 + ((state?.Settings.MobileTextScale as number | undefined) ?? 0.5) * 0.34
		: 0.96 + ((state?.Settings.DesktopTextScale as number | undefined) ?? 0.5) * 0.2;
	const motionSettings = React.useMemo<MotionSettings>(() => {
		return {
			motionScale: motionIntensity,
			viewportScale: viewportSpeed,
			textScale,
			soft: softFeel,
			reducedTransparency:
				state !== undefined && state.Settings !== undefined && (tonumber(state.Settings.ReducedTransparency) ?? 0) >= 0.5,
			shimmerScale:
				((state?.Settings.ButtonShimmers as number | undefined) ?? 1) >= 0.5
					? ((state?.Settings.ShimmerIntensity as number | undefined) ?? 0.8)
					: 0,
			panelHoverScale: ((state?.Settings.PanelHover as number | undefined) ?? 1) >= 0.5 ? 1 : 0,
			panelEntranceScale: ((state?.Settings.PanelEntrances as number | undefined) ?? 1) >= 0.5 ? 1 : 0,
			titleScale: ((state?.Settings.AnimatedTitles as number | undefined) ?? 1) >= 0.5 ? 1 : 0,
			iconScale: ((state?.Settings.IconAnimations as number | undefined) ?? 1) >= 0.5 ? 1 : 0,
			numberScale: ((state?.Settings.NumberAnimations as number | undefined) ?? 1) >= 0.5 ? 1 : 0,
			boldText: (state?.Settings.BoldText as number | undefined) ?? 0,
		} as MotionSettings;
	}, [
		motionIntensity,
		softFeel,
		state?.Settings.AnimatedTitles,
		state?.Settings.BoldText,
		state?.Settings.ButtonShimmers,
		state?.Settings.IconAnimations,
		state?.Settings.NumberAnimations,
		state?.Settings.PanelEntrances,
		state?.Settings.PanelHover,
		state?.Settings.ShimmerIntensity,
		state?.Settings.ReducedTransparency,
		textScale,
		viewportSpeed,
	]);
	const prankReveals: Record<string, string | undefined> = {
		FakeRareDrop: "No relic was added; the case is unchanged.",
		FakeEvent: "No server event started.",
		JumbleHud: "Your interface is back to normal.",
		FakeRebirth: "No progress or currency changed.",
		FakeTrade: "No trade session opened and no items moved.",
		FakeRob: "No balances changed.",
		EmptyBagScare: "Your relic inventory was never changed.",
	};
	const clearAdminPrank = React.useCallback(() => {
		const reveal = adminPrank !== undefined ? prankReveals[adminPrank.kind] : undefined;
		if (reveal !== undefined) {
			addNotice("Staff prank", reveal, "Info", false);
		}
		setAdminPrank(undefined);
	}, [addNotice, adminPrank, prankReveals]);
	const shellContent =
		state !== undefined && shellMounted
			? React.createElement(Shell as unknown as LooseComponent, {
					state,
					config,
					dispatch,
					addNotice,
					celebrate,
					confettiNonce,
					clearConfetti,
					pops,
					comboReadout,
					visit,
					setVisit,
					openDomain: domainUi?.open ?? NOOP,
					domainOverlayActive: domainUi?.active === true,
					setToastsSuppressed,
					setPurchasePresentationActive,
				} as LooseProps)
			: undefined;
	const domainContent =
		state !== undefined && shellMounted
			? React.createElement(AutoScale, undefined, domainUi !== undefined ? domainUi.render!(state, dispatch, shellContent) : shellContent)
			: shellContent;
	const content = (
		<MotionSettingsContext.Provider value={motionSettings}>
			<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.void} BackgroundTransparency={1} BorderSizePixel={0}>
				<HudPrankStage prank={adminPrank} reducedMotion={false}>
					{domainContent}
				</HudPrankStage>
				{adminPrank !== undefined && <AdminPrankOverlay prank={adminPrank} reducedMotion={false} onClose={clearAdminPrank} />}
				{!externalBoot && bootVisible && (
					<MotionSettingsContext.Provider value={Boot.BOOT_MOTION}>
						{React.createElement(Boot.BootScreen, {
							marks: bootMarks,
							ready: bootReady,
							progress: bootFill,
							version: config.Game.Version,
							reducedMotion: false,
							startedAt: bootStartedAt,
							assetsLoaded: assetProgress.loaded,
							assetsTotal: assetProgress.total,
							modulesLoaded: moduleProgress.loaded,
							modulesTotal: moduleProgress.total,
							onExitDone: onBootExitDone,
						} as LooseProps)}
					</MotionSettingsContext.Provider>
				)}
			</frame>
		</MotionSettingsContext.Provider>
	);
	const tipped = (
		<TooltipProvider enabled={tooltipsOn} reducedMotion={tooltipsCalm}>
			{content}
		</TooltipProvider>
	);
	return externalAntilag ? tipped : <AntilagProvider>{tipped}</AntilagProvider>;
}

// The rebirth card on the overview, and the chamber it opens. The card is the run at a glance: how
// far the flux has come, the run clock, the vow you swore and what a rebirth pays right now. The
// chamber is where a run ends: the payout and its grade, the vow for the next run, keepsakes,
// stars waiting to be lit, the run log, and the two-step ignition. The rules are RebirthMath's,
// and the payout is the server's own quote, so the numbers here are the numbers you get.
import React from "@rbxts/react";
import { useBackLayer } from "../../CoreKit/backLayer";
import ReactRoblox from "@rbxts/react-roblox";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { asFlux, compactNumber, Flux } from "../../CoreKit/format";
import { InteractionFeedback } from "../../CoreKit/interaction";
import { chromeFor, darken, Palette, TapTarget } from "../../CoreKit/theme";
import { useFlash, usePulse, useStagger, useViewport } from "../../MotionKit/motion";
import { TooltipContent, mergeEvents, useTooltip } from "../../Tooltip";
import { AudioPlayer, kitMember, LuauComponent, sharedModule } from "../luauKits";

const UserInputService = game.GetService("UserInputService");
const RunService = game.GetService("RunService");
const { Audio } = kitMember<{ Audio: AudioPlayer }>("AudioKit", "audio");
const { Icon } = kitMember<{ Icon: LuauComponent }>("ArtKit", "Icon");

interface UiKit {
	Badge: LuauComponent;
	Button: LuauComponent;
	IconTile: LuauComponent;
	Meter: LuauComponent;
	Panel: LuauComponent;
	Text: LuauComponent;
	EmptyState: LuauComponent;
	meterFill: (this: void, value: number, target: number) => number;
	acquireDropdownPortal: (this: void) => Instance;
	releaseDropdownPortal: (this: void) => void;
}
const { Badge, Button, EmptyState, IconTile, Meter, Panel, Text, meterFill, acquireDropdownPortal, releaseDropdownPortal } = kitMember<UiKit>(
	"UiCore",
	"ui",
);

interface VowDef {
	Id: string;
	Name: string;
	Line: string;
	Pays: string;
}
interface StarEffects {
	CoreYield: number;
	DustYield: number;
	KeepShare: number;
	HeadStart: number;
}
interface RebirthMathApi {
	vow(this: void, id: string): VowDef | undefined;
	vowMultiplier(this: void, state: { Kept?: unknown; Stars?: unknown }, id: string): number;
	mastery(this: void, state: { Kept?: unknown }, id: string): number;
	effects(this: void, state: { Stars?: unknown }): StarEffects;
	pair(this: void, index: number): string[];
	GRADE_BONUS: Record<string, number | undefined>;
	PERKS: Record<string, { Name: string; Line: string }>;
	STARS: number[];
	MASTERY_MAX: number;
	MASTERY_EVERY: number;
	MASTERY_STEP: number;
	KEEP_SHARE: number;
	KEEP_CAP: number;
	KEEP_SLOTS_AT: number[];
	LOG_LIMIT: number;
}
const RebirthMath = sharedModule<RebirthMathApi>("RebirthMath");

const VOW_ART: Record<string, { icon: string; color: Color3; name?: string; line?: string } | undefined> = {
	[""]: { icon: "Hide.rebirthVowNone", color: Palette.muted, name: "No vow", line: "Run however you like." },
	Swift: { icon: "Timer.rebirthVowSwift", color: Palette.cyan },
	Lean: { icon: "Grid.rebirthVowLean", color: Palette.mint },
	Homebound: { icon: "World.rebirthVowHomebound", color: Palette.mango },
	Overflow: { icon: "Vault.rebirthVowOverflow", color: Palette.violet },
};
const PERK_ART: Record<string, { icon: string; color: Color3 }> = {
	HeadStart: { icon: "Core.rebirthStarHeadStart", color: Palette.cyan },
	StartCash: { icon: "Flux.rebirthStarSeed", color: Palette.mango },
	CoreYield: { icon: "Production.rebirthStarCores", color: Palette.violet },
	DustYield: { icon: "Dust.rebirthStarDust", color: Palette.cream },
	VowPower: { icon: "Lock.rebirthStarVow", color: Palette.coral },
	KeepShare: { icon: "Loadout.rebirthStarKeep", color: Palette.mint },
	VaultCarry: { icon: "Ember.rebirthStarPurse", color: Palette.mango },
};
// art chosen in code: the card's dial, its vow line, and keepsakes (only first-world machines)
const REBIRTH_ICONS: Record<string, string | undefined> = {
	Dial: "Rebirth.rebirthDial",
	PanelVowNone: "Hide.rebirthPanelVowNone",
	PanelVowSwift: "Timer.rebirthPanelVowSwift",
	PanelVowLean: "Grid.rebirthPanelVowLean",
	PanelVowHomebound: "World.rebirthPanelVowHomebound",
	PanelVowOverflow: "Vault.rebirthPanelVowOverflow",
	KeepStellarCore: "Core.rebirthKeepStellar",
	KeepLunarExtractor: "Production.rebirthKeepLunar",
	KeepPrismRefinery: "Forge.rebirthKeepPrism",
	KeepOther: "Loadout.rebirthKeepOther",
};
const GRADE_COLOR: Record<string, Color3 | undefined> = { S: Palette.mango, A: Palette.mint, B: Palette.cyan, C: Palette.muted };
const GRADE_LINE: Record<string, string | undefined> = {
	S: "A new best, with the vow kept.",
	A: "A new best or a kept vow.",
	B: "At least half your best run.",
	C: "Under half your best run.",
};

interface RunEntry {
	Cores?: number;
	Grade: string;
	Seconds: number;
	Kept?: boolean;
	Vow: string;
}
interface RebirthInfo {
	Ready?: boolean;
	Cores: Flux;
	Stardust: Flux;
	Grade: string;
	Vow: string;
	VowHolds?: boolean;
	VowStatus: string;
	VowOpen?: boolean;
	KeptVows?: Record<string, number>;
	RunStartedAt?: number;
	Lifetime?: number;
	Stars?: unknown;
	Pending?: number[];
	Keep?: string[];
	KeepSlots?: number;
	Runs?: RunEntry[];
	BestCores: Flux;
	FastestSeconds: number;
}
interface MachineConfig {
	Id: string;
	Name?: string;
	Icon?: string;
	RequiredZone?: number;
	RequiredRebirths?: unknown;
}
interface RebirthConfig {
	Unlocks?: unknown;
	Machines?: MachineConfig[];
	Zones?: unknown;
	[key: string]: unknown;
}
interface RebirthState {
	Rebirth?: unknown;
	ServerTime?: number;
	Rebirths?: number;
	NextPrestigeTarget: Flux;
	RunCash: Flux;
	Vault: Flux;
	PermanentMultiplier?: Flux;
	Machines?: Record<string, number | undefined>;
	[key: string]: unknown;
}
type Dispatch = (action: string, payload?: object, callback?: (response: { ok?: boolean }) => void) => unknown;

function clock(raw: number): string {
	const seconds = math.max(0, math.floor(raw));
	const hours = math.floor(seconds / 3600);
	const minutes = math.floor((seconds % 3600) / 60);
	if (hours > 0) {
		return "%d:%02d:%02d".format(hours, minutes, seconds % 60);
	}
	return "%d:%02d".format(minutes, seconds % 60);
}

// the server's rebirth snapshot, or a quiet empty one before the first state arrives
function rebirthOf(state: RebirthState): RebirthInfo {
	const info = state.Rebirth;
	if (typeIs(info, "table")) {
		return info as RebirthInfo;
	}
	return {
		Ready: false,
		Cores: 0,
		Stardust: 0,
		Grade: "C",
		Vow: "",
		VowHolds: false,
		VowStatus: "",
		VowOpen: false,
		KeptVows: {},
		RunStartedAt: state.ServerTime ?? 0,
		Lifetime: tonumber(state.Rebirths) ?? 0,
		Stars: {},
		Pending: [],
		Keep: [],
		KeepSlots: 0,
		Runs: [],
		BestCores: 0,
		FastestSeconds: 0,
	};
}

function vowName(id: string): string {
	const vow = RebirthMath.vow(id);
	return vow ? vow.Name : VOW_ART[""]!.name!;
}

// the run clock ticks on the client between state pushes
function useRunClock(startedAt: number, serverTime?: number) {
	const offset = React.useMemo(() => (tonumber(serverTime) ?? os.time()) - os.time(), [serverTime]);
	const [seconds, setSeconds] = React.useState(0);
	React.useEffect(() => {
		let alive = true;
		const job = task.spawn(() => {
			while (alive) {
				setSeconds(os.time() + offset - startedAt);
				task.wait(1);
			}
		});
		return () => {
			alive = false;
			pcall(task.cancel, job);
		};
	}, [startedAt, offset]);
	return seconds;
}

function featuresOpeningOnNextRebirth(config: RebirthConfig | undefined, nextCount: number): string {
	const unlocks = config !== undefined && typeIs(config.Unlocks, "table") ? (config.Unlocks as unknown[]) : undefined;
	if (unlocks === undefined) {
		return "";
	}
	const names: string[] = [];
	for (const raw of unlocks) {
		const rule = raw as { Kind?: unknown; Target?: unknown; Name?: unknown };
		if (typeIs(raw, "table") && rule.Kind === "Rebirths" && rule.Target === nextCount && typeIs(rule.Name, "string")) {
			names.push(rule.Name);
		}
	}
	names.sort();
	return names.join(", ");
}

function rebirthGate(config: RebirthConfig | undefined, rebirths: number) {
	let bestName = "";
	let bestNeed = math.huge;
	let lastNeed = 0;
	const consider = (list: unknown) => {
		if (!typeIs(list, "table")) {
			return;
		}
		for (const raw of list as unknown[]) {
			const entry = raw as { Name?: unknown; RequiredRebirths?: unknown };
			if (typeIs(raw, "table") && typeIs(entry.Name, "string")) {
				const need = typeIs(entry.RequiredRebirths, "number") ? entry.RequiredRebirths : 0;
				if (need > rebirths && need < bestNeed) {
					bestNeed = need;
					bestName = entry.Name;
				} else if (need <= rebirths && need > lastNeed) {
					lastNeed = need;
				}
			}
		}
	};
	if (config !== undefined) {
		consider(config.Machines);
		consider(config.Zones);
	}
	if (bestName === "") {
		return undefined;
	}
	return { name: bestName, need: bestNeed, last: lastNeed };
}

const DIAL_DOTS = 18;

interface ChargeDialProps {
	size: number;
	position: UDim2;
	accent: Color3;
	fill: React.Binding<number>;
	charge: React.Binding<number>;
	zIndex?: number;
	children?: React.ReactNode;
}

// ring of dots around the rebirth glyph; fills with run progress, then with the ignition charge
function ChargeDial(props: ChargeDialProps) {
	const size = props.size;
	const radius = size * 0.5 - 4;
	const children: Record<string, React.Element> = {};
	for (let i = 1; i <= DIAL_DOTS; i++) {
		const angle = -math.pi / 2 + ((i - 1) / DIAL_DOTS) * math.pi * 2;
		const threshold = (i - 0.5) / DIAL_DOTS;
		children["d" + i] = (
			<frame
				AnchorPoint={new Vector2(0.5, 0.5)}
				Position={new UDim2(0.5, math.cos(angle) * radius, 0.5, math.sin(angle) * radius)}
				Size={props.fill.map((amount) => (amount >= threshold ? UDim2.fromOffset(5, 5) : UDim2.fromOffset(3, 3)))}
				BorderSizePixel={0}
				BackgroundColor3={props.fill.map((amount) => (amount >= threshold ? props.accent : Palette.panelSoft))}
				BackgroundTransparency={props.fill.map((amount) => (amount >= threshold ? 0 : 0.4))}
				ZIndex={props.zIndex}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
		);
	}
	return (
		<frame
			key="ChargeDial"
			Size={UDim2.fromOffset(size, size)}
			Position={props.position}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={props.zIndex}
		>
			{children}
			<frame
				key="ChargeHalo"
				AnchorPoint={new Vector2(0.5, 0.5)}
				Position={UDim2.fromScale(0.5, 0.5)}
				Size={props.charge.map((amount) => UDim2.fromOffset(size - 6 + amount * 8, size - 6 + amount * 8))}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ZIndex={props.zIndex}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke Color={props.accent} Thickness={2} Transparency={props.charge.map((amount) => 1 - amount * 0.8)} />
			</frame>
			{props.children}
		</frame>
	);
}

interface SectionProps {
	name: string;
	order: number;
	height: number;
	title: string;
	accent?: Color3;
	note?: string;
	children?: React.ReactNode;
}

// a titled block inside the chamber
function Section(props: SectionProps) {
	return (
		<frame
			key={props.name}
			LayoutOrder={props.order}
			Size={new UDim2(1, 0, 0, props.height)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={903}
		>
			<Text
				value={props.title}
				size={13}
				color={props.accent ?? Palette.creamSoft}
				weight={Enum.FontWeight.SemiBold}
				fit={false}
				sizeConstraint={new UDim2(1, -120, 0, 16)}
				zIndex={904}
			/>
			{props.note !== undefined && (
				<Text
					value={props.note}
					size={10}
					color={Palette.muted}
					align={Enum.TextXAlignment.Right}
					fit={false}
					position={new UDim2(1, -220, 0, 0)}
					sizeConstraint={UDim2.fromOffset(220, 14)}
					zIndex={904}
				/>
			)}
			<frame Position={UDim2.fromOffset(0, 22)} Size={new UDim2(1, 0, 1, -22)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={903}>
				{props.children}
			</frame>
		</frame>
	);
}

interface ChoiceCardProps {
	name: string;
	order?: number;
	size: UDim2;
	position: UDim2;
	chosen?: boolean;
	color: Color3;
	icon: string;
	iconSize?: number;
	title: string;
	body: string;
	tag?: string;
	disabled?: boolean;
	sound?: string;
	tooltip?: { title: string; body: string; hint: string; accent: Color3 };
	onPick: () => void;
}

// one choosable card: a vow, a star's perk, a keepsake
function ChoiceCard(props: ChoiceCardProps) {
	const [hover, setHover] = React.useState(false);
	const chosen = props.chosen;
	const tint = props.color;
	const tip = useTooltip(props.tooltip as TooltipContent | undefined);
	const iconSize = props.iconSize ?? 30;
	return (
		<textbutton
			key={props.name}
			LayoutOrder={props.order}
			Size={props.size}
			Position={props.position}
			BackgroundColor3={chosen ? darken(tint, 0.62) : hover ? Palette.panelSoft : Palette.ink}
			BackgroundTransparency={chosen ? 0 : 0.25}
			BorderSizePixel={0}
			AutoButtonColor={false}
			Text=""
			Selectable={true}
			ZIndex={905}
			Event={mergeEvents(tip, {
				Activated: () => {
					if (props.disabled) {
						Audio.play("error");
						return;
					}
					Audio.play(props.sound ?? "tabSwitch");
					props.onPick();
				},
				MouseEnter: () => setHover(true),
				MouseLeave: () => setHover(false),
			})}
		>
			<uicorner CornerRadius={new UDim(0, 10)} />
			<uistroke Color={tint} Thickness={chosen ? 2 : 1} Transparency={chosen ? 0.05 : hover ? 0.35 : 0.7} />
			<Icon kind={props.icon} size={iconSize} position={UDim2.fromOffset(10, 10)} zIndex={906} />
			<Text
				value={props.title}
				size={13}
				color={props.disabled ? Palette.muted : Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={false}
				position={UDim2.fromOffset(iconSize + 18, 9)}
				sizeConstraint={new UDim2(1, -(iconSize + 26), 0, 17)}
				zIndex={906}
			/>
			<Text
				value={props.body}
				size={10}
				color={props.disabled ? Palette.muted : Palette.creamSoft}
				wrap={true}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(iconSize + 18, 28)}
				sizeConstraint={new UDim2(1, -(iconSize + 26), 1, -32)}
				zIndex={906}
			/>
			{props.tag !== undefined && (
				<Text
					value={props.tag}
					size={9}
					color={tint}
					weight={Enum.FontWeight.Heavy}
					align={Enum.TextXAlignment.Right}
					fit={false}
					position={new UDim2(1, -96, 0, 10)}
					sizeConstraint={UDim2.fromOffset(86, 12)}
					zIndex={906}
				/>
			)}
		</textbutton>
	);
}

// the last runs as bars: height is the payout, colour is the grade, a dot marks a kept vow
function RunLog(props: { runs: RunEntry[]; grow: React.Binding<number> }) {
	const runs = props.runs;
	let best = 1;
	for (const run of runs) {
		best = math.max(best, tonumber(run.Cores) ?? 0);
	}
	const bars: Record<string, React.Element> = {};
	const count = RebirthMath.LOG_LIMIT;
	for (let i = 1; i <= count; i++) {
		const run = runs[runs.size() - count + i - 1] as RunEntry | undefined;
		const share = run ? math.clamp((tonumber(run.Cores) ?? 0) / best, 0.06, 1) : 0;
		const tint = run ? (GRADE_COLOR[run.Grade] ?? Palette.muted) : Palette.panelSoft;
		bars["b" + i] = (
			<frame
				Size={new UDim2(1 / count, -6, 1, -18)}
				Position={new UDim2((i - 1) / count, 3, 0, 0)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ZIndex={905}
			>
				<frame
					AnchorPoint={new Vector2(0, 1)}
					Position={UDim2.fromScale(0, 1)}
					Size={props.grow.map((amount) => new UDim2(1, 0, run ? share * amount : 0.04, 0))}
					BackgroundColor3={tint}
					BackgroundTransparency={run ? 0.1 : 0.6}
					BorderSizePixel={0}
					ZIndex={906}
				>
					<uicorner CornerRadius={new UDim(0, 6)} />
				</frame>
				{run && (
					<Text
						value={run.Grade}
						size={10}
						color={tint}
						weight={Enum.FontWeight.Heavy}
						align={Enum.TextXAlignment.Center}
						fit={false}
						position={new UDim2(0, 0, 1, 2)}
						sizeConstraint={new UDim2(1, 0, 0, 14)}
						zIndex={906}
					/>
				)}
			</frame>
		);
	}
	return (
		<frame Size={new UDim2(1, 0, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={904}>
			{bars}
		</frame>
	);
}

interface ChamberProps {
	state: RebirthState;
	config?: RebirthConfig;
	dispatch: Dispatch;
	effectsPaused?: boolean;
	reducedMotion?: boolean;
	onClose: () => void;
}

export function RebirthChamber(props: ChamberProps) {
	const { state, config, dispatch, effectsPaused } = props;
	const softMotion = props.reducedMotion;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const stack = chrome.contentStack;
	const info = rebirthOf(state);
	const [portal] = React.useState(acquireDropdownPortal);
	React.useEffect(() => {
		return () => {
			releaseDropdownPortal();
		};
	}, []);
	const [nextVow, setNextVow] = React.useState(info.Vow ?? "");
	const [keep, setKeep] = React.useState(() => table.clone(info.Keep ?? []));
	const [confirming, setConfirming] = React.useState(false);
	const [busy, setBusy] = React.useState(false);
	const [igniting, setIgniting] = React.useState(false);
	const [shakeToken, setShakeToken] = React.useState(0);
	const [ignite, setIgnite] = React.useBinding(0);
	// the star index whose permanent pick is in flight (one pick per star)
	const starSentRef = React.useRef<number | undefined>(undefined);
	const mountedRef = React.useRef(true);
	const ignitionRef = React.useRef<RBXScriptConnection>();
	const confirmArmedRef = React.useRef<number>();
	const rebirthClaimHostRef = React.useRef<Frame>();
	const enter = useStagger(0, softMotion);
	const grow = useStagger(2, softMotion);
	const gradeGlow = usePulse(!softMotion && !effectsPaused && info.Ready === true, 1.8);
	const runSeconds = useRunClock(tonumber(info.RunStartedAt) ?? 0, state.ServerTime);
	const canRebirth = info.Ready === true;
	const stopIgnition = () => {
		const connection = ignitionRef.current;
		if (connection !== undefined) {
			ignitionRef.current = undefined;
			connection.Disconnect();
		}
	};
	React.useEffect(() => {
		return () => {
			mountedRef.current = false;
			stopIgnition();
		};
	}, []);
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = rebirthClaimHostRef.current;
		if (host === undefined) {
			return undefined;
		}
		const selectJob = task.defer(() => {
			if (host.Parent !== undefined) {
				GamepadNavigationService.FocusClaim(host);
			}
		});
		return () => {
			pcall(task.cancel, selectJob);
		};
	}, [canRebirth, confirming, busy]);
	React.useEffect(() => {
		if (!canRebirth) {
			stopIgnition();
			setIgnite(0);
			setIgniting(false);
			setConfirming(false);
		}
	}, [canRebirth]);
	React.useEffect(() => {
		if (!confirming || igniting || busy) {
			return undefined;
		}
		const lapse = task.delay(6, () => {
			if (mountedRef.current) {
				setConfirming(false);
			}
		});
		return () => {
			pcall(task.cancel, lapse);
		};
	}, [confirming, igniting, busy]);
	const close = () => {
		if (igniting || busy) {
			return;
		}
		Audio.play("close");
		props.onClose();
	};
	React.useEffect(() => {
		const connection = UserInputService.InputBegan.Connect((input, processed) => {
			if (input.KeyCode === Enum.KeyCode.Escape && !processed) {
				close();
			}
		});
		return () => {
			connection.Disconnect();
		};
	}, [igniting, busy]);
	// B: same path as the close button, so it does nothing while igniting or rebirthing
	useBackLayer(true, close);
	const commit = () => {
		setBusy(true);
		dispatch("Rebirth", { Vow: nextVow, Keep: keep }, (response) => {
			if (!mountedRef.current) {
				return undefined;
			}
			setBusy(false);
			setIgnite(0);
			if (response.ok) {
				setConfirming(false);
				props.onClose();
			} else {
				setShakeToken((token) => token + 1);
			}
		});
	};
	// a short, cancellable charge before the reset actually fires; softMotion compresses it
	const beginIgnition = () => {
		if (igniting || ignitionRef.current !== undefined) {
			return;
		}
		setIgniting(true);
		Audio.play("rebirthCharge");
		const duration = softMotion ? 0.35 : 1.15;
		const ticks = softMotion ? 0 : 6;
		const started = os.clock();
		let ticked = 0;
		const connection: RBXScriptConnection = RunService.Heartbeat.Connect(() => {
			const amount = math.clamp((os.clock() - started) / duration, 0, 1);
			setIgnite(amount);
			const due = math.floor(amount * ticks);
			if (due > ticked && due < ticks) {
				ticked = due;
				Audio.play("countTick", 0.9 + due * 0.08);
			}
			if (amount >= 1) {
				connection.Disconnect();
				if (ignitionRef.current === connection) {
					ignitionRef.current = undefined;
				}
				if (!mountedRef.current) {
					return;
				}
				setIgniting(false);
				InteractionFeedback.reward();
				commit();
			}
		});
		ignitionRef.current = connection;
	};
	const cancelIgnition = () => {
		stopIgnition();
		setIgnite(0);
		setIgniting(false);
		Audio.play("close");
	};
	// The confirm step disarms itself: a second press only counts within CONFIRM_WINDOW seconds of the
	// first and not as part of the same double-click, so a stray tap later can never start a reset.
	const CONFIRM_WINDOW = 6;
	const CONFIRM_MIN_GAP = 0.35;
	const rebirth = () => {
		if (!canRebirth || busy || igniting) {
			return undefined;
		}
		const armedAt = confirmArmedRef.current;
		const elapsed = armedAt !== undefined ? os.clock() - armedAt : math.huge;
		if (!confirming || elapsed > CONFIRM_WINDOW) {
			confirmArmedRef.current = os.clock();
			setConfirming(true);
			Audio.play("preview");
			return undefined;
		}
		if (elapsed < CONFIRM_MIN_GAP) {
			return undefined;
		}
		beginIgnition();
	};

	const accent = igniting ? Palette.mango : confirming ? Palette.coral : Palette.violet;
	const gradeColor = GRADE_COLOR[info.Grade] ?? Palette.muted;
	const width = math.min(760, viewport.width - 24);
	const top = math.max(viewport.topInset, 36) + 10;
	const bottom = math.max(chrome.bottomSafe, viewport.bottomInset, 8) + 10;
	const height = math.min(720, viewport.height - top - bottom);
	const footerH = TapTarget + 30;
	const vow = RebirthMath.vow(info.Vow);

	// the payout: grade, cores, stardust, and why
	const reasons: string[] = [];
	if (vow) {
		reasons.push(
			info.VowHolds
				? `${vow.Name} holds: ×${"%.2f".format(RebirthMath.vowMultiplier({ Kept: info.KeptVows, Stars: info.Stars }, vow.Id))} ${vow.Pays.lower()}`
				: `${vow.Name} broken: ${info.VowStatus}`,
		);
	} else {
		reasons.push("No vow this run.");
	}
	const gradeBonus = RebirthMath.GRADE_BONUS[info.Grade] ?? 0;
	if (gradeBonus > 0) {
		reasons.push(`Grade ${info.Grade}: +${math.floor(gradeBonus * 100)}% stardust`);
	}
	const fx = RebirthMath.effects({ Stars: info.Stars });
	if (fx.CoreYield > 0) {
		reasons.push(`Stars: +${math.floor(fx.CoreYield * 100 + 0.5)}% cores`);
	}
	if (fx.DustYield > 0) {
		reasons.push(`Stars: +${math.floor(fx.DustYield * 100 + 0.5)}% stardust`);
	}
	const sections: Record<string, React.Element> = {};
	sections.layout = <uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 22)} />;
	sections.pad = <uipadding PaddingTop={new UDim(0, 4)} PaddingBottom={new UDim(0, 20)} PaddingRight={new UDim(0, 6)} />;
	sections.payout = (
		<Section
			name="RebirthPayout"
			order={1}
			height={118}
			title={canRebirth ? "This rebirth pays" : "Not ready yet"}
			note={`run time ${clock(runSeconds)}`}
		>
			<frame Size={UDim2.fromOffset(78, 78)} BackgroundColor3={darken(gradeColor, 0.7)} BorderSizePixel={0} ZIndex={905}>
				<uicorner CornerRadius={new UDim(0, 14)} />
				<uistroke Color={gradeColor} Thickness={1} Transparency={gradeGlow.map((amount) => 0.4 + amount * 0.4)} />
				<Text
					value={canRebirth ? info.Grade : "–"}
					size={44}
					color={gradeColor}
					weight={Enum.FontWeight.Heavy}
					align={Enum.TextXAlignment.Center}
					fit={false}
					position={UDim2.fromOffset(0, 15)}
					sizeConstraint={new UDim2(1, 0, 0, 48)}
					zIndex={906}
				/>
			</frame>
			<Text
				value={
					canRebirth
						? `+${compactNumber(info.Cores)} cores`
						: `${compactNumber(math.max(0, asFlux(state.NextPrestigeTarget) - (asFlux(state.RunCash) + asFlux(state.Vault))))} more flux to go`
				}
				size={stack ? 20 : 24}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={false}
				position={UDim2.fromOffset(94, 0)}
				sizeConstraint={new UDim2(1, -94, 0, 30)}
				zIndex={905}
			/>
			{canRebirth && (
				<Text
					value={`+${compactNumber(info.Stardust)} stardust  ·  ${GRADE_LINE[info.Grade] ?? ""}`}
					size={12}
					color={Palette.mint}
					fit={false}
					position={UDim2.fromOffset(94, 32)}
					sizeConstraint={new UDim2(1, -94, 0, 16)}
					zIndex={905}
				/>
			)}
			<Text
				value={reasons.join("   ·   ")}
				size={10}
				color={Palette.creamSoft}
				wrap={true}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(94, 54)}
				sizeConstraint={new UDim2(1, -94, 0, 34)}
				zIndex={905}
			/>
		</Section>
	);

	// stars waiting: the first one, its two perks side by side
	const pending = info.Pending ?? [];
	if (pending.size() > 0) {
		const index = pending[0];
		const pair = RebirthMath.pair(index);
		const cards: Record<string, React.Element> = {};
		pair.forEach((perk, i) => {
			const slot = i + 1;
			const def = RebirthMath.PERKS[perk];
			const art = PERK_ART[perk];
			// Luau STARS[index + 1] is the star after this one
			const nextStar = RebirthMath.STARS[index] as number | undefined;
			cards[perk] = (
				<ChoiceCard
					name={"Star" + perk}
					icon={art.icon}
					color={art.color}
					title={def.Name}
					body={def.Line}
					iconSize={34}
					size={new UDim2(0.5, -6, 1, 0)}
					position={new UDim2((slot - 1) * 0.5, slot === 2 ? 6 : 0, 0, 0)}
					sound="reward"
					tooltip={{
						title: def.Name,
						body: "Permanent, and it stacks with every other star you light. The other choice is gone for this star.",
						hint: nextStar !== undefined ? `Next star at rebirth ${nextStar}.` : "This is the last star.",
						accent: art.color,
					}}
					onPick={() => {
						// the choice is permanent: only the first tap counts until the server answers
						if (starSentRef.current === index) {
							return;
						}
						starSentRef.current = index;
						const fallback = task.delay(8, () => {
							starSentRef.current = undefined;
						});
						dispatch("RebirthAct", { Op: "Star", Index: index, Pick: slot }, (response: { ok?: boolean }) => {
							pcall(task.cancel, fallback);
							if (response.ok !== true) {
								starSentRef.current = undefined;
							}
						});
					}}
				/>
			);
		});
		sections.stars = (
			<Section
				name="RebirthStars"
				order={2}
				height={22 + 74}
				title={`Star ${index} is lit: choose one, it's permanent`}
				accent={Palette.mango}
				note={pending.size() > 1 ? `${pending.size() - 1} more waiting` : undefined}
			>
				{cards}
			</Section>
		);
	}

	// the vow for the next run
	const vowIds = ["", "Swift", "Lean", "Homebound", "Overflow"];
	const vowCards: Record<string, React.Element> = {};
	const vowCols = stack ? 1 : 3;
	const vowCardH = stack ? 56 : 78;
	const vowGap = 10;
	vowIds.forEach((id, i) => {
		const def = RebirthMath.vow(id);
		const art = VOW_ART[id]!;
		const col = i % vowCols;
		const row = math.floor(i / vowCols);
		const mastery = def ? RebirthMath.mastery({ Kept: info.KeptVows }, id) : 0;
		const kept = def && typeIs(info.KeptVows, "table") ? (tonumber(info.KeptVows[id]) ?? 0) : 0;
		vowCards[id !== "" ? id : "None"] = (
			<ChoiceCard
				name={"Vow" + (id === "" ? "None" : id)}
				icon={art.icon}
				color={art.color}
				chosen={nextVow === id}
				title={def ? def.Name : art.name!}
				body={
					def
						? `${def.Line} ×${"%.2f".format(RebirthMath.vowMultiplier({ Kept: info.KeptVows, Stars: info.Stars }, id))} ${def.Pays.lower()}.`
						: art.line!
				}
				tag={def && kept > 0 ? `Kept ${kept}${mastery > 0 ? " · M" + mastery : ""}` : undefined}
				tooltip={
					def
						? {
								title: def.Name,
								body: `Checked the moment you rebirth. Kept, it multiplies your ${def.Pays.lower()}; broken, you just get the normal payout.`,
								hint:
									mastery >= RebirthMath.MASTERY_MAX
										? `Kept ${kept} times, fully mastered.`
										: `Kept ${kept} times. ${RebirthMath.MASTERY_EVERY - (kept % RebirthMath.MASTERY_EVERY)} more to make it ${math.floor(RebirthMath.MASTERY_STEP * 100)}% stronger.`,
								accent: art.color,
							}
						: undefined
				}
				size={new UDim2(1 / vowCols, -(vowGap * (vowCols - 1)) / vowCols, 0, vowCardH)}
				position={new UDim2(col / vowCols, (col * vowGap) / vowCols, 0, row * (vowCardH + vowGap))}
				onPick={() => {
					setNextVow(id);
				}}
			/>
		);
	});
	const vowRows = math.ceil(vowIds.size() / vowCols);
	sections.vows = (
		<Section
			name="RebirthVows"
			order={3}
			height={22 + vowRows * vowCardH + (vowRows - 1) * vowGap}
			title="Vow for the next run"
			note="keep it and the payout grows"
		>
			{vowCards}
		</Section>
	);

	// keepsakes: machines that come along at a share of their level
	const slots = tonumber(info.KeepSlots) ?? 0;
	const fxShare = RebirthMath.KEEP_SHARE + fx.KeepShare;
	const owned: Array<{ id: string; name: string; level: number; icon?: string }> = [];
	for (const machine of (config && config.Machines) || []) {
		const level = state.Machines ? (tonumber(state.Machines[machine.Id]) ?? 0) : 0;
		if (level >= 1 && (tonumber(machine.RequiredZone) ?? 1) <= 1) {
			owned.push({ id: machine.Id, name: machine.Name ?? machine.Id, level, icon: machine.Icon });
		}
	}
	owned.sort((a, b) => a.level > b.level);
	if (slots > 0) {
		const chips: Record<string, React.Element> = {};
		const cols = stack ? 2 : 3;
		const chipH = 54;
		for (let i = 0; i < owned.size(); i++) {
			if (i + 1 > 9) {
				break;
			}
			const entry = owned[i];
			const chosen = keep.includes(entry.id);
			const full = !chosen && keep.size() >= slots;
			const col = i % cols;
			const row = math.floor(i / cols);
			chips[entry.id] = (
				<ChoiceCard
					name={"Keep" + entry.id}
					icon={REBIRTH_ICONS["Keep" + entry.id] ?? REBIRTH_ICONS.KeepOther!}
					color={Palette.mint}
					chosen={chosen}
					disabled={full}
					title={entry.name}
					body={`Lv ${compactNumber(entry.level)} to Lv ${math.clamp(math.floor(entry.level * fxShare), 1, RebirthMath.KEEP_CAP)}`}
					iconSize={26}
					size={new UDim2(1 / cols, -(8 * (cols - 1)) / cols, 0, chipH)}
					position={new UDim2(col / cols, (col * 8) / cols, 0, row * (chipH + 8))}
					onPick={() => {
						const nextKeep = table.clone(keep);
						const at = nextKeep.indexOf(entry.id);
						if (at !== -1) {
							nextKeep.remove(at);
						} else if (nextKeep.size() < slots) {
							nextKeep.push(entry.id);
						}
						setKeep(nextKeep);
					}}
				/>
			);
		}
		const rows = math.max(1, math.ceil(math.min(owned.size(), 9) / cols));
		sections.keep = (
			<Section
				name="RebirthKeepsakes"
				order={4}
				height={22 + rows * chipH + (rows - 1) * 8}
				title={`Keepsakes · ${keep.size()} of ${slots}`}
				note={`keeps ${math.floor(fxShare * 100 + 0.5)}% of the level`}
			>
				{chips}
			</Section>
		);
	} else {
		const nextAt = RebirthMath.KEEP_SLOTS_AT[0];
		sections.keep = (
			<Section name="RebirthKeepsakes" order={4} height={22 + 18} title="Keepsakes">
				<Text
					value={`After rebirth ${nextAt}, one machine can come with you into the next run.`}
					size={11}
					color={Palette.muted}
					fit={false}
					sizeConstraint={new UDim2(1, 0, 0, 16)}
					zIndex={905}
				/>
			</Section>
		);
	}

	// what stays and what goes
	const ledgerColumn = (title: string, body: string, tint: Color3, x: number, icon: string) => (
		<frame
			Size={new UDim2(0.5, -6, 1, 0)}
			Position={new UDim2(x, x > 0 ? 6 : 0, 0, 0)}
			BackgroundColor3={Palette.ink}
			BackgroundTransparency={0.3}
			BorderSizePixel={0}
			ZIndex={905}
		>
			<uicorner CornerRadius={new UDim(0, 10)} />
			<uistroke Color={tint} Transparency={0.55} />
			<Icon kind={icon} size={22} position={UDim2.fromOffset(10, 10)} zIndex={906} />
			<Text
				value={title}
				size={10}
				color={tint}
				weight={Enum.FontWeight.Heavy}
				fit={false}
				position={UDim2.fromOffset(40, 13)}
				sizeConstraint={new UDim2(1, -50, 0, 14)}
				zIndex={906}
			/>
			<Text
				value={body}
				size={11}
				color={Palette.creamSoft}
				wrap={true}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(12, 38)}
				sizeConstraint={new UDim2(1, -24, 1, -44)}
				zIndex={906}
			/>
		</frame>
	);
	const keepNames: string[] = [];
	for (const id of keep) {
		for (const entry of owned) {
			if (entry.id === id) {
				keepNames.push(entry.name);
			}
		}
	}
	let keepCopy = "Cores, Stardust, research, relics, milestones, Domain and every lit star";
	if (keepNames.size() > 0) {
		keepCopy += ", plus " + keepNames.join(" and ");
	}
	sections.ledger = (
		<Section name="RebirthLedger" order={5} height={22 + (stack ? 120 : 96)} title="What stays, what goes">
			{ledgerColumn("You keep", keepCopy, Palette.mint, 0, "Check.rebirthKeeps")}
			{ledgerColumn(
				"Resets",
				"Run Flux, the vault, worlds and machines. The Stellar Core starts again" +
					(fx.HeadStart > 0 ? ` at Lv ${1 + fx.HeadStart}.` : " at Lv 1."),
				Palette.coral,
				0.5,
				"Refresh.rebirthResets",
			)}
		</Section>
	);

	// the run log
	const runs = info.Runs ?? [];
	sections.log = (
		<Section
			name="RebirthRunLog"
			order={6}
			height={22 + 110}
			title={`Last ${math.min(runs.size(), RebirthMath.LOG_LIMIT)} runs`}
			note={runs.size() > 0 ? `best ${compactNumber(info.BestCores)} cores · fastest ${clock(info.FastestSeconds)}` : undefined}
		>
			{runs.size() > 0 ? (
				<RunLog runs={runs} grow={grow.map((amount) => math.clamp(amount, 0, 1))} />
			) : (
				<EmptyState
					icon="Rebirth"
					title="No runs yet"
					body="Rebirth once and your run shows up here."
					accent={Palette.violet}
					compact={true}
					size={new UDim2(1, 0, 0, 104)}
					zIndex={905}
				/>
			)}
		</Section>
	);

	const claimText = busy
		? "Rebirthing…"
		: igniting
			? "Igniting…"
			: confirming
				? "Ignite rebirth"
				: canRebirth
					? `REBIRTH · ${vowName(nextVow)} next`
					: "Not ready";
	return ReactRoblox.createPortal(
		<frame key="RebirthChamber" Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={900}>
			<textbutton
				key="Scrim"
				Size={UDim2.fromScale(1, 1)}
				BackgroundColor3={Palette.night}
				BackgroundTransparency={enter.map((amount) => 1 - math.clamp(amount, 0, 1) * 0.42)}
				BorderSizePixel={0}
				AutoButtonColor={false}
				Text=""
				Selectable={false}
				ZIndex={900}
				Event={{ Activated: close }}
			/>
			<frame
				key="Sheet"
				AnchorPoint={new Vector2(0.5, 0)}
				Size={UDim2.fromOffset(width, height)}
				Position={enter.map((amount) => new UDim2(0.5, 0, 0, top + math.round((1 - math.clamp(amount, 0, 1)) * 18)))}
				BackgroundColor3={confirming ? darken(accent, 0.9) : Palette.panelRaised}
				BorderSizePixel={0}
				ZIndex={901}
			>
				<uicorner CornerRadius={new UDim(0, 14)} />
				<uistroke Color={accent} Thickness={1} Transparency={0.45} />
				<ChargeDial size={54} position={UDim2.fromOffset(16, 14)} accent={accent} fill={ignite} charge={ignite} zIndex={903}>
					<Icon kind="Rebirth.rebirthChamber" size={34} position={UDim2.fromOffset(10, 10)} zIndex={904} />
				</ChargeDial>
				<Text
					value={igniting ? "Igniting" : confirming ? "Check your rebirth" : `Rebirth ${(tonumber(info.Lifetime) ?? 0) + 1}`}
					size={10}
					color={accent}
					weight={Enum.FontWeight.Heavy}
					fit={false}
					position={UDim2.fromOffset(84, 18)}
					sizeConstraint={new UDim2(1, -160, 0, 14)}
					zIndex={903}
				/>
				<Text
					value={igniting ? "Stop now or the run resets." : confirming ? "Press again to ignite." : "End this run"}
					size={stack ? 18 : 22}
					color={Palette.cream}
					weight={Enum.FontWeight.Heavy}
					fit={false}
					position={UDim2.fromOffset(84, 34)}
					sizeConstraint={new UDim2(1, -160, 0, 28)}
					zIndex={903}
				/>
				<Button
					text=""
					icon="Close.rebirthChamber"
					onClick={close}
					color={Palette.panelSoft}
					textColor={Palette.cream}
					outline={true}
					size={UDim2.fromOffset(TapTarget, TapTarget)}
					position={new UDim2(1, -(TapTarget + 16), 0, 18)}
					reducedMotion={softMotion}
					disabled={igniting || busy}
					zIndex={903}
				/>
				<scrollingframe
					key="Body"
					Position={UDim2.fromOffset(20, 84)}
					Size={new UDim2(1, -28, 1, -(84 + footerH + 6))}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					CanvasSize={UDim2.fromOffset(0, 0)}
					AutomaticCanvasSize={Enum.AutomaticSize.Y}
					ScrollingDirection={Enum.ScrollingDirection.Y}
					ScrollBarThickness={3}
					ScrollBarImageColor3={accent}
					ZIndex={902}
				>
					{sections}
				</scrollingframe>
				<frame
					key="RebirthClaimActions"
					AnchorPoint={new Vector2(0, 1)}
					Position={new UDim2(0, 20, 1, -16)}
					Size={new UDim2(1, -40, 0, TapTarget + 8)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					ClipsDescendants={false}
					ZIndex={903}
					ref={rebirthClaimHostRef}
				>
					<Button
						text={claimText}
						icon="Rebirth.rebirthIgnite"
						onClick={rebirth}
						color={canRebirth ? accent : Palette.panelSoft}
						textColor={canRebirth ? Palette.ink : Palette.muted}
						size={new UDim2(stack ? 0.62 : 0.7, -6, 0, TapTarget)}
						reducedMotion={softMotion}
						disabled={!canRebirth || busy}
						loading={busy}
						shakeToken={shakeToken}
						highlight={canRebirth && !igniting && !softMotion}
						zIndex={904}
					/>
					<frame
						key="IgnitionBar"
						Size={ignite.map((amount) => new UDim2((stack ? 0.62 : 0.7) * amount, -6, 0, 4))}
						Position={UDim2.fromOffset(0, TapTarget + 3)}
						BackgroundColor3={Palette.mango}
						BorderSizePixel={0}
						Visible={igniting}
						ZIndex={904}
					>
						<uicorner CornerRadius={new UDim(1, 0)} />
					</frame>
					<Button
						text={igniting ? "Stop" : confirming ? "Cancel" : "Close"}
						icon="Close.rebirthIgniteStop"
						onClick={igniting ? cancelIgnition : confirming ? () => setConfirming(false) : close}
						sound={igniting ? undefined : "close"}
						color={Palette.panelSoft}
						textColor={Palette.cream}
						outline={true}
						size={new UDim2(stack ? 0.38 : 0.3, -6, 0, TapTarget)}
						position={new UDim2(stack ? 0.62 : 0.7, 6, 0, 0)}
						reducedMotion={softMotion}
						disabled={busy}
						zIndex={904}
					/>
				</frame>
			</frame>
		</frame>,
		portal,
	);
}

interface RebirthPanelProps {
	state: RebirthState;
	config?: RebirthConfig;
	dispatch: Dispatch;
	reducedMotion?: boolean;
	effectsPaused?: boolean;
	height: number;
	reveal?: unknown;
	openWorkshop?: () => void;
	layoutOrder?: number;
}

export function RebirthPanel({
	state,
	config,
	dispatch,
	reducedMotion,
	effectsPaused,
	height,
	reveal,
	openWorkshop,
	layoutOrder = 2,
}: RebirthPanelProps) {
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const softMotion = reducedMotion;
	const stack = chrome.contentStack;
	const info = rebirthOf(state);
	const canRebirth = info.Ready === true;
	const target = math.max(1, asFlux(state.NextPrestigeTarget));
	const conversionFlux = math.max(0, asFlux(state.RunCash)) + math.max(0, asFlux(state.Vault));
	const progress = canRebirth ? 1 : meterFill(conversionFlux, target);
	const rebirths = math.max(0, math.floor(tonumber(state.Rebirths) ?? 0));
	const seconds = useRunClock(tonumber(info.RunStartedAt) ?? 0, state.ServerTime);
	const [chamberOpen, setChamberOpen] = React.useState(false);
	const readiness = useFlash(canRebirth ? 1 : 0, softMotion || effectsPaused, 0.8);
	const heroReveal = useStagger(1, softMotion);
	const starPulse = usePulse((info.Pending ?? []).size() > 0 && !softMotion && !effectsPaused, 1.4);
	const [dialFill, setDialFill] = React.useBinding(progress);
	const [ignite] = React.useBinding(0);
	React.useEffect(() => {
		setDialFill(progress);
	}, [progress]);
	const vow = RebirthMath.vow(info.Vow);
	const vowArt = VOW_ART[info.Vow] ?? VOW_ART[""]!;
	const opens = featuresOpeningOnNextRebirth(config, rebirths + 1);
	const gate = rebirthGate(config, rebirths);
	const accent = canRebirth ? Palette.violet : Palette.steel;
	const pending = (info.Pending ?? []).size();
	const vowLine =
		vow === undefined
			? info.VowOpen
				? "No vow yet. You can still swear one this run."
				: "No vow this run."
			: info.VowHolds
				? `${vow.Name}: ${info.VowStatus}`
				: `${vow.Name} broken. ${info.VowStatus}`;
	const runs = info.Runs ?? [];
	const lastRun = runs[runs.size() - 1] as RunEntry | undefined;
	const notes: string[] = [];
	if (opens !== "") {
		notes.push(`Opens ${opens}.`);
	}
	if (gate !== undefined) {
		notes.push(`${gate.name} at rebirth ${gate.need}.`);
	}
	const history: string[] = [];
	if (lastRun !== undefined) {
		history.push(
			`Last run ${clock(lastRun.Seconds)}, grade ${lastRun.Grade}, +${compactNumber(lastRun.Cores)} cores${
				lastRun.Kept && lastRun.Vow !== "" ? `, ${lastRun.Vow} kept` : ""
			}.`,
		);
		history.push(`Best payout ${compactNumber(info.BestCores)} cores, fastest run ${clock(info.FastestSeconds)}.`);
	}
	for (const line of notes) history.push(line);
	const historyTip = history.size() > 0 ? { title: "Runs", body: history.join("\n"), accent } : undefined;
	const colW = stack ? 0 : 286;
	const lively = canRebirth && !effectsPaused && !softMotion;
	return (
		<Panel
			layoutOrder={layoutOrder}
			size={new UDim2(1, 0, 0, height)}
			accent={accent}
			background={Palette.panelRaised}
			padding={stack ? chrome.cardPadding : 22}
			reveal={reveal ?? heroReveal}
			highlight={lively}
			reducedMotion={softMotion || effectsPaused}
			clips={false}
		>
			<ChargeDial size={stack ? 56 : 64} position={UDim2.fromOffset(-3, stack ? 2 : 6)} accent={accent} fill={dialFill} charge={ignite}>
				<IconTile
					kind={REBIRTH_ICONS.Dial}
					accent={accent}
					size={(stack ? 56 : 64) - 18}
					radius={14}
					position={UDim2.fromOffset(9, 9)}
					glow={lively}
					spin={lively}
					reducedMotion={softMotion || effectsPaused}
				/>
			</ChargeDial>
			<frame
				Size={new UDim2(1, -((stack ? 66 : 76) + colW + (stack ? 0 : 16)), 0, stack ? 134 : height - 36)}
				Position={UDim2.fromOffset(stack ? 66 : 76, 0)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={false}
			>
				<Text
					value={`${rebirths}  ·  ${clock(seconds)}`}
					size={10}
					color={accent}
					weight={Enum.FontWeight.Heavy}
					fit={false}
					sizeConstraint={new UDim2(1, 0, 0, 16)}
				/>
				<Text
					value={
						canRebirth
							? `+${compactNumber(info.Cores)}  ${info.Grade}`
							: rebirths < 1
								? "Rebirth"
								: `${math.floor(math.clamp(conversionFlux / target, 0, 1) * 100)}%`
					}
					size={stack ? 22 : 28}
					color={Palette.cream}
					weight={Enum.FontWeight.Heavy}
					fit={false}
					position={UDim2.fromOffset(0, 20)}
					sizeConstraint={new UDim2(1, 0, 0, 28)}
				/>
				<frame
					key="RebirthVowLine"
					Position={UDim2.fromOffset(0, 54)}
					Size={new UDim2(1, 0, 0, 22)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
				>
					<Icon
						kind={REBIRTH_ICONS["PanelVow" + (info.Vow === "" ? "None" : info.Vow)] ?? REBIRTH_ICONS.PanelVowNone}
						size={20}
						position={UDim2.fromOffset(0, 1)}
					/>
					<Text
						value={vowLine}
						size={11}
						color={vow === undefined ? Palette.muted : info.VowHolds ? vowArt.color : Palette.coral}
						fit={false}
						position={UDim2.fromOffset(26, 3)}
						sizeConstraint={new UDim2(1, -26, 0, 16)}
					/>
				</frame>
				<Meter
					value={progress}
					rainbow={true}
					color={accent}
					reducedMotion={softMotion || effectsPaused}
					shimmer={lively}
					position={UDim2.fromOffset(0, 86)}
					size={new UDim2(1, 0, 0, 5)}
				/>
				<Text
					value={
						canRebirth
							? `+${compactNumber(info.Stardust)} stardust`
							: `${compactNumber(conversionFlux)} / ${compactNumber(target)}`
					}
					size={10}
					color={canRebirth ? Palette.mint : Palette.muted}
					wrap={true}
					fit={true}
					minSize={9}
					position={UDim2.fromOffset(0, 102)}
					sizeConstraint={new UDim2(1, 0, 0, 30)}
				/>
			</frame>
			<frame
				Size={stack ? new UDim2(1, 0, 0, TapTarget * 2 + 44) : UDim2.fromOffset(colW, height - 36)}
				Position={stack ? new UDim2(0, 0, 1, -(TapTarget * 2 + 44)) : new UDim2(1, -colW, 0, 0)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={false}
			>
				<Badge
					value={pending > 0 ? `Star` : `${compactNumber(state.PermanentMultiplier)}×`}
					accent={pending > 0 ? Palette.mango : Palette.mint}
					filled={pending > 0}
					size={new UDim2(1, 0, 0, 26)}
				/>
				{pending > 0 && (
					<frame Size={new UDim2(1, 4, 0, 30)} Position={UDim2.fromOffset(-2, -2)} BackgroundTransparency={1} BorderSizePixel={0}>
						<uicorner CornerRadius={new UDim(1, 0)} />
						<uistroke Color={Palette.mango} Thickness={2} Transparency={starPulse.map((amount) => 0.25 + amount * 0.6)} />
					</frame>
				)}
				<Button
					text={canRebirth ? "Rebirth" : pending > 0 ? "Light star" : "Plan"}
					tooltip={historyTip}
					icon="Rebirth.rebirthPlan"
					onClick={() => setChamberOpen(true)}
					sound="page"
					color={canRebirth || pending > 0 ? accent : Palette.panelSoft}
					textColor={canRebirth || pending > 0 ? Palette.ink : Palette.cream}
					size={new UDim2(1, 0, 0, TapTarget)}
					position={UDim2.fromOffset(0, 36)}
					reducedMotion={softMotion}
					highlight={canRebirth && !softMotion}
				/>
				<Button
					text="Workshop"
					icon="Forge.rebirthWorkshop"
					onClick={openWorkshop}
					sound="page"
					color={Palette.panelSoft}
					textColor={Palette.cream}
					outline={true}
					size={new UDim2(1, 0, 0, TapTarget)}
					position={UDim2.fromOffset(0, 44 + TapTarget)}
					reducedMotion={softMotion}
				/>
			</frame>
			{lively && (
				<frame
					Size={readiness.map((amount) => UDim2.fromOffset(18 + amount * 54, 18 + amount * 54))}
					Position={UDim2.fromOffset(29, 38)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					ZIndex={8}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
					<uistroke Color={accent} Thickness={2} Transparency={readiness.map((amount) => 1 - amount * 0.54)} />
				</frame>
			)}
			{chamberOpen && (
				<RebirthChamber
					state={state}
					config={config}
					dispatch={dispatch}
					reducedMotion={softMotion}
					effectsPaused={effectsPaused}
					onClose={() => setChamberOpen(false)}
				/>
			)}
		</Panel>
	);
}

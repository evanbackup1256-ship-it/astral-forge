// The rebirth chamber, rebuilt on Forge2. Where a run ends: what this rebirth pays and why, a star
// to light (permanent), the vow for the next run, keepsakes, what stays and what resets (always on
// screen), the run log, and a two-step ignition that can be stopped until the very end.
// Remotes: Rebirth {Vow, Keep}, RebirthAct {Op: "Star", Index, Pick}. On success the shared
// RebirthCeremony plays at full strength.
import React from "@rbxts/react";
import { Audio } from "../../../AudioKit/audio";
import { asFlux, compactNumber, Flux } from "../../../CoreKit/format";
import { InteractionFeedback } from "../../../CoreKit/interaction";
import { useClock, useFlash, usePulse, useStagger } from "../../../MotionKit/motion";
import { TooltipContent, useTooltip } from "../../../Tooltip";
import { EmptyState, Tooltip } from "../../design/Layers";
import { ironFace } from "../../../UiCore/castIron";
import { RainbowGradient } from "../../../UiCore/rainbowFx";
import * as RebirthCeremony from "../../../UiCore/RebirthCeremony";
import RebirthMath = require("../../../../../Shared/AstralForge/Shared/RebirthMath");
import { ForgeButton as Button } from "../../design/ForgeButton";
import { Card, Panel } from "../../design/Panel";
import { Text, Title } from "../../design/Text";
import { Fonts, gap, HIT, Iron, Type } from "../../design/tokens";
import { useBack } from "../../input/input";
import { MotionFX, usePresenceOf } from "../../motion/motion";
import type { Request } from "../../store/net";

const RunService = game.GetService("RunService");

export interface RunEntry {
	Cores?: number;
	Grade: string;
	Seconds: number;
	Kept?: boolean;
	Vow: string;
}

export interface RebirthInfo {
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

export interface RebirthSession {
	Rebirth?: unknown;
	ServerTime?: number;
	Rebirths?: number;
	NextPrestigeTarget?: Flux;
	RunCash?: Flux;
	Vault?: Flux;
	PermanentMultiplier?: Flux;
	Machines?: Record<string, number | undefined>;
}

interface MachineDef {
	Id: string;
	Name?: string;
	RequiredZone?: number;
}

export const GRADE_LINE: Record<string, string> = {
	S: "A new best, with the vow kept.",
	A: "A new best or a kept vow.",
	B: "At least half your best run.",
	C: "Under half your best run.",
};

export const GRADE_COLOR: Record<string, () => Color3> = { S: Iron.brass, A: Iron.steel, B: Iron.soft, C: Iron.muted };
const VOW_IDS = ["", "Swift", "Lean", "Homebound", "Overflow"];

export function rebirthOf(session: RebirthSession): RebirthInfo {
	const info = session.Rebirth;
	if (typeIs(info, "table")) return info as RebirthInfo;
	return {
		Ready: false,
		Cores: 0,
		Stardust: 0,
		Grade: "C",
		Vow: "",
		VowStatus: "",
		RunStartedAt: session.ServerTime ?? 0,
		Lifetime: session.Rebirths ?? 0,
		BestCores: 0,
		FastestSeconds: 0,
	};
}

export function clock(raw: number): string {
	const seconds = math.max(0, math.floor(raw));
	const hours = math.floor(seconds / 3600);
	const minutes = math.floor((seconds % 3600) / 60);
	if (hours > 0) return "%d:%02d:%02d".format(hours, minutes, seconds % 60);
	return "%d:%02d".format(minutes, seconds % 60);
}

/** The run clock ticks on the client between state pushes. */
export function useRunClock(startedAt: number, serverTime?: number): number {
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

/** A ring of dots: fills with the run, then with the ignition charge. */
export function ChargeDial(props: { size: number; fill: React.Binding<number> | number; charge: React.Binding<number>; color: Color3; children?: React.ReactNode }) {
	const DOTS = 20;
	const radius = props.size / 2 - 4;
	const fill = typeIs(props.fill, "number") ? undefined : props.fill;
	const fixed = typeIs(props.fill, "number") ? props.fill : 0;
	const dots: React.Element[] = [];
	for (let i = 0; i < DOTS; i++) {
		const angle = -math.pi / 2 + (i / DOTS) * math.pi * 2;
		const at = (i + 0.5) / DOTS;
		const lit = (v: number) => v >= at;
		dots.push(
			<frame
				key={`d${i}`}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Position={new UDim2(0.5, math.cos(angle) * radius, 0.5, math.sin(angle) * radius)}
				Size={fill ? fill.map((v) => (lit(v) ? UDim2.fromOffset(6, 6) : UDim2.fromOffset(3, 3))) : lit(fixed) ? UDim2.fromOffset(6, 6) : UDim2.fromOffset(3, 3)}
				BackgroundColor3={props.color}
				BackgroundTransparency={fill ? fill.map((v) => (lit(v) ? 0 : 0.6)) : lit(fixed) ? 0 : 0.6}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>,
		);
	}
	return (
		<frame Size={UDim2.fromOffset(props.size, props.size)} BackgroundTransparency={1}>
			{dots}
			<frame
				AnchorPoint={new Vector2(0.5, 0.5)}
				Position={UDim2.fromScale(0.5, 0.5)}
				Size={props.charge.map((v) => UDim2.fromOffset(props.size - 6 + v * 10, props.size - 6 + v * 10))}
				BackgroundTransparency={1}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke Color={props.color} Thickness={2} Transparency={props.charge.map((v) => 1 - v * 0.85)} />
			</frame>
			{props.children}
		</frame>
	);
}

function Block(props: { title: string; note?: string; phone: boolean; order: number; children?: React.ReactNode }) {
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.order}>
			<uilistlayout Padding={new UDim(0, gap(props.phone, "s"))} SortOrder={Enum.SortOrder.LayoutOrder} />
			<frame Size={new UDim2(1, 0, 0, Type.body(props.phone) + 6)} BackgroundTransparency={1} LayoutOrder={0}>
				<Text text={props.title} size={Type.body(props.phone)} font={Fonts.heavy} box={new UDim2(0.6, 0, 1, 0)} />
				{props.note !== undefined && (
					<Text text={props.note} size={Type.small(props.phone)} color={Iron.muted()} align="Right" box={new UDim2(0.4, 0, 1, 0)} position={UDim2.fromScale(0.6, 0)} />
				)}
			</frame>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{props.children}
			</frame>
		</frame>
	);
}

function Choice(props: { title: string; body: string; tag?: string; color: Color3; chosen?: boolean; disabled?: boolean; width: UDim; order: number; phone: boolean; tip?: string; onPick: () => void }) {
	const [hover, setHover] = React.useState(false);
	return (
		<frame
			Size={new UDim2(props.width.Scale, props.width.Offset, 0, 0)}
			AutomaticSize={Enum.AutomaticSize.Y}
			BackgroundTransparency={1}
			LayoutOrder={props.order}
			Event={{ MouseEnter: () => setHover(true), MouseLeave: () => setHover(false) }}
		>
			<Card accent={props.color} selected={props.chosen} pad={gap(props.phone, "m")} spacing={2} onPress={props.disabled === true ? undefined : props.onPick}>
				<Text text={props.title} size={Type.body(props.phone)} font={Fonts.heavy} color={props.chosen === true ? props.color : props.disabled === true ? Iron.muted() : Iron.text()} order={0} />
				<Text text={props.body} size={Type.small(props.phone)} color={Iron.soft()} multiline order={1} />
				{props.tag !== undefined && <Text text={props.tag} size={Type.small(props.phone)} color={props.color} font={Fonts.heavy} order={2} />}
			</Card>
			{hover && props.tip !== undefined && (
				<frame Size={UDim2.fromOffset(260, 0)} AutomaticSize={Enum.AutomaticSize.Y} Position={new UDim2(0.5, 0, 0, -6)} AnchorPoint={new Vector2(0.5, 1)} BackgroundTransparency={1} ZIndex={70}>
					<Panel pad={10} color={Iron.sunk()}>
						<Text text={props.tip} size={13} color={Iron.soft()} multiline />
					</Panel>
				</frame>
			)}
		</frame>
	);
}

/** The last runs as bars: height is the payout, colour is the grade. */
function RunLog(props: { runs: RunEntry[]; phone: boolean }) {
	const grow = useStagger(2, false, 0, 0.5);
	let best = 1;
	for (const run of props.runs) best = math.max(best, tonumber(run.Cores) ?? 0);
	const count = RebirthMath.LOG_LIMIT;
	const bars: React.Element[] = [];
	for (let i = 1; i <= count; i++) {
		const run = props.runs[props.runs.size() - count + i - 1] as RunEntry | undefined;
		const share = run ? math.clamp((tonumber(run.Cores) ?? 0) / best, 0.06, 1) : 0;
		const tint = run ? (GRADE_COLOR[run.Grade] ?? Iron.muted)() : Iron.sunk();
		bars.push(
			<frame key={`b${i}`} Size={new UDim2(1 / count, -6, 1, -18)} Position={new UDim2((i - 1) / count, 3, 0, 0)} BackgroundTransparency={1}>
				<frame
					AnchorPoint={new Vector2(0, 1)}
					Position={UDim2.fromScale(0, 1)}
					Size={grow.map((g) => new UDim2(1, 0, run ? share * g : 0.04, 0))}
					BackgroundColor3={tint}
					BackgroundTransparency={run ? 0.1 : 0.6}
					BorderSizePixel={0}
				>
					<uicorner CornerRadius={new UDim(0, 4)} />
				</frame>
				{run && <Text text={run.Grade} size={11} font={Fonts.heavy} color={tint} align="Center" box={new UDim2(1, 0, 0, 14)} position={new UDim2(0, 0, 1, 2)} />}
			</frame>,
		);
	}
	return (
		<frame Size={new UDim2(1, 0, 0, props.phone ? 90 : 110)} BackgroundTransparency={1}>
			{bars}
		</frame>
	);
}

export interface ChamberProps {
	open: boolean;
	session: RebirthSession;
	config: Record<string, unknown>;
	request: Request;
	phone: boolean;
	onClose: () => void;
}

const CONFIRM_WINDOW = 6;
const CONFIRM_MIN_GAP = 0.35;

export function RebirthChamber(props: ChamberProps) {
	const [presence, mounted] = usePresenceOf(props.open);
	React.useEffect(() => {
		if (props.open) MotionFX.play("modeSwitch");
	}, [props.open]);
	if (!mounted) return undefined;
	return <ChamberBody {...props} presence={presence} />;
}

function ChamberBody(props: ChamberProps & { presence: React.Binding<number> }) {
	const { session, phone, request } = props;
	const info = rebirthOf(session);
	const canRebirth = info.Ready === true;
	const [nextVow, setNextVow] = React.useState(info.Vow ?? "");
	const [keep, setKeep] = React.useState<string[]>(() => table.clone(info.Keep ?? []));
	const [confirming, setConfirming] = React.useState(false);
	const [igniting, setIgniting] = React.useState(false);
	const [busy, setBusy] = React.useState(false);
	const [ignite, setIgnite] = React.useBinding(0);
	const starSent = React.useRef<number>();
	const armedAt = React.useRef<number>();
	const ignition = React.useRef<RBXScriptConnection>();
	const alive = React.useRef(true);
	const seconds = useRunClock(tonumber(info.RunStartedAt) ?? 0, session.ServerTime);
	const gradeGlow = usePulse(canRebirth, 1.8);
	const heat = useClock(igniting, 3);
	const [fails, setFails] = React.useState(0);
	const failFlash = useFlash(fails, false, 0.42);

	const stopIgnition = () => {
		ignition.current?.Disconnect();
		ignition.current = undefined;
	};
	React.useEffect(() => () => {
		alive.current = false;
		stopIgnition();
	}, []);
	React.useEffect(() => {
		if (!canRebirth) {
			stopIgnition();
			setIgnite(0);
			setIgniting(false);
			setConfirming(false);
		}
	}, [canRebirth]);
	React.useEffect(() => {
		if (!confirming || igniting || busy) return undefined;
		const lapse = task.delay(CONFIRM_WINDOW, () => alive.current && setConfirming(false));
		return () => {
			pcall(task.cancel, lapse);
		};
	}, [confirming, igniting, busy]);

	const close = () => {
		if (igniting || busy) return;
		Audio.play("close");
		props.onClose();
	};
	// B runs the same path as Close, so it does nothing mid-ignition
	useBack(props.open, close);

	const commit = () => {
		setBusy(true);
		request("Rebirth", { Vow: nextVow, Keep: keep }, (reply) => {
			if (!alive.current) return;
			setBusy(false);
			setIgnite(0);
			if (reply.ok === true) {
				setConfirming(false);
				RebirthCeremony.play({
					rebirths: reply.Rebirths,
					before: reply.MultiplierBefore,
					after: reply.MultiplierAfter,
					reward: reply.Reward,
					stardust: reply.StardustReward,
					grade: reply.Grade,
					vow: reply.Vow,
					vowKept: reply.VowKept,
				});
				MotionFX.play("milestone");
				props.onClose();
			} else {
				Audio.play("error");
				MotionFX.play("error");
				setFails((n) => n + 1);
			}
		});
	};

	const beginIgnition = () => {
		if (igniting || ignition.current !== undefined) return;
		setIgniting(true);
		Audio.play("rebirthCharge");
		const duration = 1.15;
		const ticks = 6;
		const started = os.clock();
		let ticked = 0;
		const connection = RunService.Heartbeat.Connect(() => {
			const amount = math.clamp((os.clock() - started) / duration, 0, 1);
			setIgnite(amount);
			const due = math.floor(amount * ticks);
			if (due > ticked && due < ticks) {
				ticked = due;
				Audio.play("countTick", 0.9 + due * 0.08);
			}
			if (amount >= 1) {
				connection.Disconnect();
				if (ignition.current === connection) ignition.current = undefined;
				if (!alive.current) return;
				setIgniting(false);
				InteractionFeedback.reward();
				commit();
			}
		});
		ignition.current = connection;
	};

	const cancelIgnition = () => {
		stopIgnition();
		setIgnite(0);
		setIgniting(false);
		Audio.play("close");
	};

	// two presses: the first arms, a second within the window (and not a double click) ignites
	const press = () => {
		if (!canRebirth || busy || igniting) return;
		const elapsed = armedAt.current !== undefined ? os.clock() - armedAt.current : math.huge;
		if (!confirming || elapsed > CONFIRM_WINDOW) {
			armedAt.current = os.clock();
			setConfirming(true);
			Audio.play("preview");
			return;
		}
		if (elapsed < CONFIRM_MIN_GAP) return;
		beginIgnition();
	};

	// ------ payout
	const vow = RebirthMath.vow(info.Vow);
	const reasons: string[] = [];
	if (vow) {
		reasons.push(
			info.VowHolds === true
				? `${vow.Name} holds  ×${"%.2f".format(RebirthMath.vowMultiplier({ Kept: info.KeptVows, Stars: info.Stars }, vow.Id))} ${vow.Pays.lower()}`
				: `${vow.Name} broken: ${info.VowStatus}`,
		);
	} else {
		reasons.push(info.VowOpen === true ? "No vow yet. You can still swear one this run." : "No vow this run.");
	}
	const gradeBonus = RebirthMath.GRADE_BONUS[info.Grade] ?? 0;
	if (gradeBonus > 0) reasons.push(`grade ${info.Grade} +${math.floor(gradeBonus * 100)}% stardust`);
	const fx = RebirthMath.effects({ Stars: info.Stars }) as Record<string, number>;
	if ((fx.CoreYield ?? 0) > 0) reasons.push(`stars +${math.floor(fx.CoreYield * 100 + 0.5)}% cores`);
	if ((fx.DustYield ?? 0) > 0) reasons.push(`stars +${math.floor(fx.DustYield * 100 + 0.5)}% stardust`);
	const gradeColor = (GRADE_COLOR[info.Grade] ?? Iron.muted)();
	const toGo = math.max(0, asFlux(session.NextPrestigeTarget ?? 0) - (asFlux(session.RunCash ?? 0) + asFlux(session.Vault ?? 0)));

	// ------ keepsakes
	const slots = tonumber(info.KeepSlots) ?? 0;
	const share = RebirthMath.KEEP_SHARE + (fx.KeepShare ?? 0);
	const owned: Array<{ id: string; name: string; level: number }> = [];
	for (const machine of ((props.config.Machines as MachineDef[] | undefined) ?? [])) {
		const level = tonumber(session.Machines?.[machine.Id]) ?? 0;
		if (level >= 1 && (tonumber(machine.RequiredZone) ?? 1) <= 1) owned.push({ id: machine.Id, name: machine.Name ?? machine.Id, level });
	}
	owned.sort((a, b) => a.level > b.level);
	const keepNames = owned.filter((m) => keep.includes(m.id)).map((m) => m.name);
	let keepCopy = "Cores, Stardust, research, relics, milestones, Domain and every lit star";
	if (keepNames.size() > 0) keepCopy += ", plus " + keepNames.join(" and ");
	const headStart = fx.HeadStart ?? 0;
	const resetCopy = `Run Flux, the vault, worlds and machines. The Stellar Core starts again at Lv ${1 + headStart}.`;

	const pending = info.Pending ?? [];
	const half = phone ? new UDim(1, 0) : new UDim(0.5, -4);
	const third = phone ? new UDim(1, 0) : new UDim(1 / 3, -6);
	const runs = info.Runs ?? [];
	const accent = igniting ? Iron.brass() : confirming ? Iron.ember() : Iron.steel();
	const claimText = busy ? "…" : igniting ? "Igniting…" : confirming ? "Ignite rebirth" : canRebirth ? "Rebirth" : "Not ready";
	const stepTitle = igniting ? "Igniting" : confirming ? "Check your rebirth" : `Rebirth ${(tonumber(info.Lifetime) ?? 0) + 1}`;
	const stepLine = igniting ? "Stop now or the run resets." : confirming ? "Press again to ignite." : "End this run";
	const gradeTip: TooltipContent = {
		title: canRebirth ? `Grade ${info.Grade}` : "Not ready yet",
		body: canRebirth ? GRADE_LINE[info.Grade] ?? "" : `${compactNumber(toGo)} more flux to go.`,
		hint: gradeBonus > 0 ? `+${math.floor(gradeBonus * 100)}% stardust` : undefined,
		accent: gradeColor,
	};
	const gradeEvents = useTooltip(gradeTip);
	const permanent = session.PermanentMultiplier;

	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Iron.void()} BackgroundTransparency={props.presence.map((p) => 1 - p * 0.55)} ZIndex={50}>
			<textbutton Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} Text="" Selectable={false} Event={{ Activated: close }} />
			<frame
				Size={new UDim2(phone ? 0.96 : 0, phone ? 0 : 720, 0.94, 0)}
				Position={props.presence.map((p) => new UDim2(0.5, 0, 0.5, (1 - p) * 28))}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundTransparency={1}
				ZIndex={51}
			>
				<uiscale Scale={props.presence.map((p) => 0.94 + p * 0.06)} />
				<uisizeconstraint MaxSize={new Vector2(math.huge, 760)} />
				<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Iron.face()} BorderSizePixel={0}>
					<uicorner CornerRadius={new UDim(0, 8)} />
					<uistroke Color={Iron.edge()} Transparency={0.55} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
					{ironFace()}
					<frame Size={new UDim2(1, -16, 0, 2)} Position={UDim2.fromOffset(8, 0)} BackgroundColor3={Color3.fromRGB(255, 255, 255)} BorderSizePixel={0} ZIndex={5}>
						<RainbowGradient base={Iron.brass()} state={{ rarity: "Mythic", active: true }} style="flow" />
					</frame>
					<scrollingframe
						Size={new UDim2(1, 0, 1, -(HIT + 40))}
						BackgroundTransparency={1}
						BorderSizePixel={0}
						CanvasSize={new UDim2()}
						AutomaticCanvasSize={Enum.AutomaticSize.Y}
						ScrollBarThickness={phone ? 0 : 4}
						ScrollBarImageColor3={Iron.brassDeep()}
					>
						<uipadding PaddingTop={new UDim(0, gap(phone, "l"))} PaddingBottom={new UDim(0, gap(phone, "l"))} PaddingLeft={new UDim(0, gap(phone, "l"))} PaddingRight={new UDim(0, gap(phone, "l"))} />
						<uilistlayout Padding={new UDim(0, gap(phone, "xl"))} SortOrder={Enum.SortOrder.LayoutOrder} />

						<Text text={canRebirth ? "This rebirth pays" : "Not ready yet"} size={Type.body(phone)} font={Fonts.heavy} color={Iron.muted()} order={-1} />
						<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0}>
							<frame Size={UDim2.fromOffset(phone ? 84 : 100, phone ? 84 : 100)} BackgroundColor3={Iron.sunk()} Active Event={gradeEvents as never}>
								<uicorner CornerRadius={new UDim(0, 12)} />
								<uistroke Color={gradeColor} Thickness={2} Transparency={gradeGlow.map((a) => 0.2 + a * 0.5)} />
								<Text text={canRebirth ? info.Grade : "-"} size={phone ? 44 : 56} font={Fonts.heavy} color={gradeColor} align="Center" box={UDim2.fromScale(1, 1)} />
							</frame>
							<frame Size={new UDim2(1, -(phone ? 100 : 124), 1, 0)} Position={UDim2.fromOffset(phone ? 100 : 124, 0)} BackgroundTransparency={1}>
								<uilistlayout Padding={new UDim(0, 4)} SortOrder={Enum.SortOrder.LayoutOrder} />
								<Title text={canRebirth ? `+${compactNumber(info.Cores)} cores` : `${compactNumber(toGo)} flux to go`} size={Type.title(phone)} order={0} />
								{canRebirth && <Text text={`+${compactNumber(info.Stardust)} stardust`} size={Type.body(phone)} color={Iron.brass()} font={Fonts.heavy} order={1} />}
								{canRebirth && <Text text={GRADE_LINE[info.Grade] ?? ""} size={Type.small(phone)} color={gradeColor} order={1} />}
								<Text text={reasons.join("   ")} size={Type.small(phone)} color={Iron.muted()} multiline order={2} />
								<Text text={clock(seconds)} size={Type.small(phone)} color={Iron.soft()} order={3} />
								{permanent !== undefined && (
									<Tooltip tip={`Permanent: every rebirth so far multiplies production by ${compactNumber(permanent)}×.`} size={new UDim2(1, 0, 0, Type.small(phone) + 6)} order={4}>
										<Text text={`${compactNumber(permanent)}× production`} size={Type.small(phone)} color={Iron.steel()} font={Fonts.heavy} />
									</Tooltip>
								)}
							</frame>
						</frame>

						{pending.size() > 0 && (
							<Block title={`Light star ${pending[0]}`} note={pending.size() > 1 ? `${pending.size() - 1} more waiting` : "permanent"} phone={phone} order={1}>
								{RebirthMath.pair(pending[0]).map((perk, i) => {
									const def = RebirthMath.PERKS[perk];
									const upcoming = RebirthMath.STARS[pending[0]] as number | undefined;
									const index = pending[0];
									return (
										<Choice
											key={perk}
											title={def.Name}
											body={def.Line}
											color={Iron.brass()}
											width={half}
											order={i}
											phone={phone}
											tip={`Permanent, and it stacks with every star you light. The other choice is gone for this star.${upcoming !== undefined ? ` Next star at rebirth ${upcoming}.` : " This is the last star."}`}
											onPick={() => {
												if (starSent.current === index) return;
												starSent.current = index;
												const fallback = task.delay(8, () => (starSent.current = undefined));
												request("RebirthAct", { Op: "Star", Index: index, Pick: i + 1 }, (reply) => {
													pcall(task.cancel, fallback);
													if (reply.ok !== true) starSent.current = undefined;
													else {
														Audio.play("successChime");
														MotionFX.play("success");
													}
												});
											}}
										/>
									);
								})}
							</Block>
						)}

						<Block title="Vow for the next run" note="keep it and the payout grows" phone={phone} order={2}>
							{VOW_IDS.map((id, i) => {
								const def = RebirthMath.vow(id);
								const kept = def !== undefined ? (tonumber(info.KeptVows?.[id]) ?? 0) : 0;
								const mastery = def !== undefined ? RebirthMath.mastery({ Kept: info.KeptVows }, id) : 0;
								const tip =
									def !== undefined
										? `Checked the moment you rebirth. Kept, it multiplies your ${def.Pays.lower()}; broken, you get the normal payout. ` +
											(mastery >= RebirthMath.MASTERY_MAX
												? `Kept ${kept} times, fully mastered.`
												: `Kept ${kept} times. ${RebirthMath.MASTERY_EVERY - (kept % RebirthMath.MASTERY_EVERY)} more to make it ${math.floor(RebirthMath.MASTERY_STEP * 100)}% stronger.`)
										: undefined;
								return (
									<Choice
										key={id === "" ? "None" : id}
										title={def !== undefined ? def.Name : "No vow"}
										body={def !== undefined ? `${def.Line}  ×${"%.2f".format(RebirthMath.vowMultiplier({ Kept: info.KeptVows, Stars: info.Stars }, id))} ${def.Pays.lower()}` : "Run however you like."}
										tag={def !== undefined && kept > 0 ? `kept ${kept}${mastery > 0 ? `  M${mastery}` : ""}` : undefined}
										color={def !== undefined ? Iron.steel() : Iron.muted()}
										chosen={nextVow === id}
										width={third}
										order={i}
										phone={phone}
										tip={tip}
										onPick={() => setNextVow(id)}
									/>
								);
							})}
						</Block>

						<Block
							title={slots > 0 ? `Keepsakes  ${keep.size()}/${slots}` : "Keepsakes"}
							note={slots > 0 ? `keep ${math.floor(share * 100 + 0.5)}% of the level` : undefined}
							phone={phone}
							order={3}
						>
							{slots > 0 ? (
								owned
									.filter((_, i) => i < 9)
									.map((m, i) => {
										const chosen = keep.includes(m.id);
										const full = !chosen && keep.size() >= slots;
										return (
											<Choice
												key={m.id}
												title={m.name}
												body={`Lv ${compactNumber(m.level)} to Lv ${math.clamp(math.floor(m.level * share), 1, RebirthMath.KEEP_CAP)}`}
												color={Iron.brass()}
												chosen={chosen}
												disabled={full}
												width={third}
												order={i}
												phone={phone}
												onPick={() => {
													const nextKeep = table.clone(keep);
													const at = nextKeep.indexOf(m.id);
													if (at !== -1) nextKeep.remove(at);
													else if (nextKeep.size() < slots) nextKeep.push(m.id);
													setKeep(nextKeep);
												}}
											/>
										);
									})
							) : (
								<Text text={`From rebirth ${RebirthMath.KEEP_SLOTS_AT[0]}, one machine can come with you.`} size={Type.small(phone)} color={Iron.muted()} />
							)}
						</Block>

						<Block title="What stays, what goes" phone={phone} order={4}>
							<frame Size={new UDim2(half.Scale, half.Offset, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0}>
								<Card accent={Iron.brass()} pad={gap(phone, "m")} spacing={4}>
									<Text text="You keep" size={Type.small(phone)} font={Fonts.heavy} color={Iron.brass()} order={0} />
									<Text text={keepCopy} size={Type.small(phone)} color={Iron.soft()} multiline order={1} />
								</Card>
							</frame>
							<frame Size={new UDim2(half.Scale, half.Offset, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
								<Card accent={Iron.ember()} pad={gap(phone, "m")} spacing={4}>
									<Text text="Resets" size={Type.small(phone)} font={Fonts.heavy} color={Iron.ember()} order={0} />
									<Text text={resetCopy} size={Type.small(phone)} color={Iron.soft()} multiline order={1} />
								</Card>
							</frame>
						</Block>

						<Block
							title={runs.size() > 0 ? `Last ${math.min(runs.size(), RebirthMath.LOG_LIMIT)} runs` : "Runs"}
							note={runs.size() > 0 ? `best ${compactNumber(info.BestCores)}   fastest ${clock(info.FastestSeconds)}` : undefined}
							phone={phone}
							order={5}
						>
							{runs.size() > 0 ? (
								<RunLog runs={runs} phone={phone} />
							) : (
								<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1}>
									<EmptyState title="No runs yet" body="Rebirth once and your run shows up here." phone={phone} />
								</frame>
							)}
						</Block>
					</scrollingframe>

					<frame Size={new UDim2(1, 0, 0, HIT + 40)} Position={new UDim2(0, 0, 1, -(HIT + 40))} BackgroundColor3={Iron.sunk()} BackgroundTransparency={0.3} BorderSizePixel={0} ZIndex={4}>
						<uipadding PaddingLeft={new UDim(0, gap(phone, "l"))} PaddingRight={new UDim(0, gap(phone, "l"))} />
						<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 12)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
						<frame Size={UDim2.fromOffset(48, 48)} BackgroundTransparency={1} LayoutOrder={0}>
							<uiscale Scale={heat.map((t) => (igniting ? 1 + math.sin(t * 6) * 0.04 : 1))} />
							<ChargeDial size={48} fill={ignite} charge={ignite} color={accent} />
						</frame>
						<frame Size={UDim2.fromOffset(phone ? 0 : 170, HIT)} BackgroundTransparency={1} LayoutOrder={3} Visible={!phone}>
							<Text text={stepTitle} size={Type.small(phone) + 1} font={Fonts.heavy} color={accent} box={new UDim2(1, 0, 0, 20)} />
							<Text text={stepLine} size={Type.small(phone)} color={Iron.muted()} box={new UDim2(1, 0, 0, 16)} position={UDim2.fromOffset(0, 22)} />
						</frame>
						<Button
							shakeToken={fails}
							text={claimText}
							tone={confirming || igniting ? "ember" : "brass"}
							width={phone ? 150 : 220}
							disabled={!canRebirth || busy}
							busy={busy}
							glint={canRebirth}
							onPress={press}
							order={1}
						/>
						<Button text={igniting ? "Stop" : confirming ? "Cancel" : "Close"} tone="iron" width={phone ? 100 : 130} disabled={busy} onPress={() => {
							if (igniting) cancelIgnition();
							else if (confirming) setConfirming(false);
							else close();
						}} order={2} />
					</frame>
					<frame
						Size={new UDim2(1, 0, 0, HIT + 40)}
						Position={new UDim2(0, 0, 1, -(HIT + 40))}
						BackgroundColor3={Iron.ember()}
						BackgroundTransparency={failFlash.map((v) => 1 - v * 0.5)}
						BorderSizePixel={0}
						Active={false}
						ZIndex={3}
						Visible={failFlash.map((v) => v > 0.02)}
					/>
				</frame>
			</frame>
		</frame>
	);
}

// Prize wheel, rebuilt on Forge2. The wheel itself is the shared PrizeWheel drawing (bulbs, speed
// veil, gloss, breathing hub, flicking pointer); this page owns the spin and everything around it.
//
// The spin runs in five parts (degrees / seconds), the same feel as before:
//   windup  a short pull back against the spin
//   launch  speed rises as u², up to cruise
//   cruise  constant speed until the server has picked the prize (and at least a short while)
//   brake   quartic ease-out onto the prize plus a little overshoot, starting at cruise speed
//   settle  the peg catches the overshoot and the wheel rocks back onto the prize
// Every peg crossed flicks the pointer and ticks. Remote unchanged: SpinWheel {ExpectedSpin};
// an interrupted spin is re-sent with the same ExpectedSpin so the server can confirm it.
import React from "@rbxts/react";
import { Audio } from "../../AudioKit/audio";
import { clockText, compactNumber, formatReward, Reward } from "../../CoreKit/format";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { InteractionFeedback } from "../../CoreKit/interaction";
import { useChangePop, useFlash, useListStagger, useStagger, useViewport, useWallClock } from "../../MotionKit/motion";
import { PressButton as Button } from "../design/PressButton";
import { Card, Meter, Panel } from "../design/Panel";
import { Text, Title } from "../design/Text";
import { Fonts, gap, Iron, Type } from "../design/tokens";
import { Burst, MotionFX } from "../motion/motion";
import type { PageProps } from "../router/routes";
import PrizeWheel = require("../../PrizeWheel");
import Juice = require("../../JuiceFx");

const RunService = game.GetService("RunService");
const UserInputService = game.GetService("UserInputService");

const OMEGA = 1440;
const WINDUP_S = 0.3;
const WINDUP_DEG = 18;
const LAUNCH_S = 0.55;
const MIN_CRUISE_S = 0.45;
const SETTLE_S = 0.45;
const OVERSHOOT_DEG = 4;
const TIMEOUT_S = 12;

interface Prize {
	Id: string;
	Name?: string;
	ShortLabel?: string;
	Color?: Color3;
	Rarity?: string;
	Weight?: number;
	Reward?: Reward;
}
interface WheelConfig {
	Rewards?: Prize[];
	CooldownSeconds?: number;
	PityAfter?: number;
	PityRarity?: string;
}
interface WheelState {
	CanSpin?: boolean;
	Spins?: number;
	FreeSpins?: number;
	ReadyAt?: number;
	PityMisses?: number;
	PityAfter?: number;
	PityArmed?: boolean;
	LastReceipt?: { PrizeIndex?: number; PrizeId?: string; ExpectedSpin?: number };
	History?: { PrizeId?: string; At?: number; Pity?: boolean }[];
}
type Phase = "idle" | "launch" | "brake" | "landed" | "error";
interface Plan {
	active: boolean;
	mode: "spin" | "brake";
	base: number;
	startedAt: number;
	lastSegment: number;
	lastSoundAt: number;
	distance: number;
	overshoot: number;
	duration: number;
	result?: Result;
}
interface Result {
	index: number;
	message?: string;
}

// an order the server may have taken but never answered; kept across remounts so it is confirmed, not repeated
let unresolved: { ExpectedSpin?: number } | undefined;

function mod(value: number, m: number): number {
	return ((value % m) + m) % m;
}

function prizeIndex(prizes: Prize[], index: unknown, id: unknown): number | undefined {
	if (!typeIs(index, "number") || index % 1 !== 0 || index < 1 || index > prizes.size()) return undefined;
	if (!typeIs(id, "string") || prizes[index - 1].Id !== id) return undefined;
	return index - 1;
}

function sampleSpin(plan: Plan, t: number): LuaTuple<[number, number]> {
	if (t < WINDUP_S) return $tuple(plan.base - WINDUP_DEG * math.sin(((t / WINDUP_S) * math.pi) / 2), 0);
	const start = plan.base - WINDUP_DEG;
	const launched = t - WINDUP_S;
	if (launched < LAUNCH_S) {
		const u = launched / LAUNCH_S;
		return $tuple(start + (OMEGA * LAUNCH_S * u * u * u) / 3, OMEGA * u * u);
	}
	return $tuple(start + (OMEGA * LAUNCH_S) / 3 + OMEGA * (launched - LAUNCH_S), OMEGA);
}

function sampleBrake(plan: Plan, t: number): LuaTuple<[number, number, boolean]> {
	if (t < plan.duration) {
		const left = 1 - t / plan.duration;
		const l3 = left * left * left;
		return $tuple(plan.base + plan.distance * (1 - l3 * left), ((4 * plan.distance) / plan.duration) * l3, false);
	}
	const u = math.clamp((t - plan.duration) / SETTLE_S, 0, 1);
	const rock = plan.overshoot * (1 - u) * math.cos(u * math.pi * 1.5);
	return $tuple(plan.base + plan.distance - plan.overshoot + rock, 0, u >= 1);
}

function useSpin(props: PageProps, prizes: Prize[], wheel: WheelState) {
	const segment = 360 / math.max(1, prizes.size());
	const receipt = wheel.LastReceipt;
	const restored = receipt !== undefined ? (prizeIndex(prizes, receipt.PrizeIndex, receipt.PrizeId) ?? -1) : -1;
	const [phase, setPhase] = React.useState<Phase>(unresolved !== undefined || (receipt !== undefined && restored < 0) ? "error" : restored >= 0 ? "landed" : "idle");
	const [winner, setWinner] = React.useState(restored);
	const [failure, setFailure] = React.useState<string | undefined>(
		unresolved !== undefined ? "Confirm your interrupted spin first." : receipt !== undefined && restored < 0 ? "Your saved prize doesn't match this wheel. Reopen it." : undefined,
	);
	const [impactNonce, setImpactNonce] = React.useState(0);
	const startRotation = restored >= 0 ? mod(360 - restored * segment, 360) : 0;
	const [rotation, setRotation] = React.useBinding(startRotation);
	const [pointerKick, setPointerKick] = React.useBinding(0);
	const [spinEnergy, setSpinEnergy] = React.useBinding(0);
	const rotationNow = React.useRef(startRotation);
	const kickNow = React.useRef(0);
	const busy = React.useRef(false);
	const alive = React.useRef(true);
	const token = React.useRef(0);
	const timeout = React.useRef<thread>();
	const pending = React.useRef<Result>();
	const plan = React.useRef<Plan>({ active: false, mode: "spin", base: 0, startedAt: 0, lastSegment: 0, lastSoundAt: -math.huge, distance: 0, overshoot: 0, duration: 1 });
	const spinning = phase === "launch" || phase === "brake";

	const stopMotion = () => {
		plan.current.active = false;
		kickNow.current = 0;
		setPointerKick(0);
		setSpinEnergy(0);
	};
	const land = (result: Result, final: number) => {
		if (!alive.current || !busy.current) return;
		const at = mod(final, 360);
		rotationNow.current = at;
		setRotation(at);
		stopMotion();
		setWinner(result.index);
		setImpactNonce((n) => n + 1);
		setPhase("landed");
		busy.current = false;
		pending.current = undefined;
		pcall(() => Juice.live("wheel", undefined));
		Audio.play("wheelLand");
		InteractionFeedback.reward();
		const prize = prizes[result.index];
		Burst.gain(prize?.ShortLabel ?? formatReward(prize?.Reward), prize?.Color ?? Iron.brass(), "Wheel.6");
		MotionFX.play(prize?.Rarity === "Legendary" || prize?.Rarity === "Exotic" ? "milestone" : "success");
	};
	const brake = (result: Result) => {
		if (!alive.current || !busy.current) return;
		const wanted = mod(360 - result.index * segment, 360);
		const now = os.clock();
		const [current, rawSpeed] = sampleSpin(plan.current, now - plan.current.startedAt);
		const speed = math.max(rawSpeed, 360);
		const overshoot = math.min(OVERSHOOT_DEG, segment * 0.3);
		// three full turns on the way down, then onto the prize
		const distance = 1080 + mod(wanted - mod(current, 360), 360) + overshoot;
		plan.current = {
			...plan.current,
			active: true,
			mode: "brake",
			base: current,
			distance,
			overshoot,
			duration: (4 * distance) / speed,
			startedAt: now,
			lastSegment: math.floor((current + segment / 2) / segment),
			result,
		};
		rotationNow.current = current;
		setPhase("brake");
		Audio.play("wheelBrake");
	};
	const brakeRef = React.useRef(brake);
	brakeRef.current = brake;
	const landRef = React.useRef(land);
	landRef.current = land;

	React.useEffect(() => {
		if (!spinning) return undefined;
		const connection = RunService.RenderStepped.Connect((dt) => {
			if (kickNow.current > 0) {
				kickNow.current = math.max(0, kickNow.current - dt * 9);
				setPointerKick(kickNow.current);
			}
			const p = plan.current;
			if (!p.active) return;
			const now = os.clock();
			const t = now - p.startedAt;
			const braking = p.mode === "brake";
			let value: number;
			let speed: number;
			let settled = false;
			if (braking) {
				[value, speed, settled] = sampleBrake(p, t);
			} else {
				[value, speed] = sampleSpin(p, t);
			}
			rotationNow.current = value;
			setRotation(value);
			const energy = math.clamp(speed / OMEGA, 0, 1);
			setSpinEnergy(energy);
			// pegs sit on the wedge edges: crossing one flicks the pointer and clicks
			const seg = math.floor((value + segment / 2) / segment);
			if (seg !== p.lastSegment) {
				p.lastSegment = seg;
				kickNow.current = math.max(kickNow.current, 0.4 + (1 - energy) * 0.6);
				setPointerKick(kickNow.current);
				if (now - p.lastSoundAt >= (energy > 0.6 ? 0.055 : 0)) {
					p.lastSoundAt = now;
					Audio.play(braking && energy < 0.25 ? "wheelSlow" : "wheelTick", 0.86 + energy * 0.3);
				}
			}
			if (!braking) {
				const result = pending.current;
				if (result !== undefined && t >= WINDUP_S + LAUNCH_S + MIN_CRUISE_S) brakeRef.current(result);
				return;
			}
			if (settled && p.result !== undefined) landRef.current(p.result, p.base + p.distance - p.overshoot);
		});
		return () => connection.Disconnect();
	}, [spinning, segment]);

	React.useEffect(() => {
		return () => {
			alive.current = false;
			busy.current = false;
			token.current += 1;
			plan.current.active = false;
			pcall(() => Juice.live("wheel", undefined));
			if (timeout.current !== undefined) pcall(task.cancel, timeout.current);
		};
	}, []);

	// a receipt from the server (e.g. after a reconnect) settles the wheel on its saved prize
	React.useEffect(() => {
		if (busy.current || receipt === undefined) return;
		if (unresolved !== undefined && unresolved.ExpectedSpin === receipt.ExpectedSpin) unresolved = undefined;
		if (unresolved !== undefined) return;
		const index = prizeIndex(prizes, receipt.PrizeIndex, receipt.PrizeId);
		if (index === undefined) {
			setPhase("error");
			setFailure("Your saved prize doesn't match this wheel. Reopen it.");
			return;
		}
		const at = mod(360 - index * segment, 360);
		rotationNow.current = at;
		setRotation(at);
		setWinner(index);
		setFailure(undefined);
		setPhase("landed");
	}, [receipt, spinning, prizes, segment]);

	const fail = (message: string, cue = "error") => {
		busy.current = false;
		pending.current = undefined;
		stopMotion();
		setPhase("error");
		setFailure(message);
		pcall(() => Juice.live("wheel", undefined));
		Audio.play(cue);
		MotionFX.play("warning");
	};

	const spin = () => {
		if (busy.current || (unresolved === undefined && wheel.CanSpin !== true)) return;
		const order = unresolved ?? { ExpectedSpin: wheel.Spins };
		unresolved = order;
		busy.current = true;
		token.current += 1;
		const mine = token.current;
		pending.current = undefined;
		kickNow.current = 0;
		setPointerKick(0);
		setWinner(-1);
		setFailure(undefined);
		Audio.play("wheelStart");
		InteractionFeedback.tap();
		MotionFX.play("modeSwitch");
		pcall(() => Juice.live("wheel", { title: "Wheel spinning", value: "…", icon: "Wheel.6", color: Iron.brass(), ttl: 14, priority: 2, expiresAt: 0, updatedAt: 0 }));
		plan.current = {
			...plan.current,
			active: true,
			mode: "spin",
			base: rotationNow.current,
			startedAt: os.clock(),
			lastSegment: math.floor((rotationNow.current + segment / 2) / segment),
			lastSoundAt: -math.huge,
		};
		setPhase("launch");
		if (timeout.current !== undefined) pcall(task.cancel, timeout.current);
		timeout.current = task.delay(TIMEOUT_S, () => {
			timeout.current = undefined;
			if (!alive.current || token.current !== mine || !busy.current) return;
			token.current += 1;
			fail("No answer yet. Confirm the spin to check its prize.", "requestTimeout");
		});
		props.request("SpinWheel", order, (reply) => {
			if (reply.Uncertain !== true && unresolved === order) unresolved = undefined;
			if (!alive.current || token.current !== mine) return;
			if (timeout.current !== undefined) {
				pcall(task.cancel, timeout.current);
				timeout.current = undefined;
			}
			if (reply.ok !== true || reply.PrizeIndex === undefined) {
				fail(reply.Uncertain === true ? "Connection dropped. Confirm the spin first." : (reply.error ?? "The draw didn't finish."));
				return;
			}
			const index = prizeIndex(prizes, reply.PrizeIndex, reply.PrizeId);
			if (index === undefined) {
				fail("Prize saved, but its art is missing. Reopen the wheel.");
				return;
			}
			pending.current = { index, message: reply.message };
		});
	};

	return { phase, spinning, winner, failure, retry: unresolved !== undefined, impactNonce, rotation, pointerKick, spinEnergy, spin };
}

function PrizeRow(props: { prize: Prize; index: number; chance: number; phone: boolean; won: boolean }) {
	const rise = useListStagger(props.index);
	const color = props.prize.Color ?? Iron.brass();
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.index}>
			<uiscale Scale={rise.map((p) => 0.96 + p * 0.04)} />
			<Card accent={color} pad={gap(props.phone, "m")} spacing={2} selected={props.won} rarity={props.prize.Rarity} layout="row">
				<Text text={props.prize.Name ?? props.prize.Id} size={Type.body(props.phone)} font={Fonts.heavy} color={Iron.text().Lerp(color, 0.25)} box={new UDim2(0.5, 0, 0, Type.body(props.phone) + 6)} order={0} />
				<Text text={props.prize.ShortLabel ?? formatReward(props.prize.Reward)} size={Type.small(props.phone)} color={color} box={new UDim2(0.3, 0, 0, 18)} order={1} />
				<Text text={string.format("%.1f%%", props.chance)} size={Type.small(props.phone)} color={Iron.muted()} align="Right" box={new UDim2(0.2, -8, 0, 18)} order={2} />
			</Card>
		</frame>
	);
}

export function WheelPage(props: PageProps) {
	const phone = props.phone;
	const viewport = useViewport();
	const config = (props.config.Wheel ?? {}) as WheelConfig;
	const prizes = config.Rewards ?? [];
	const wheel = ((props.session as unknown as { Wheel?: WheelState }).Wheel ?? {}) as WheelState;
	const spin = useSpin(props, prizes, wheel);
	const canSpin = wheel.CanSpin === true || spin.retry;
	const prize = spin.winner >= 0 ? prizes[spin.winner] : undefined;
	const misses = wheel.PityMisses ?? 0;
	const pityAfter = wheel.PityAfter ?? config.PityAfter ?? 8;
	const pityArmed = wheel.PityArmed === true || misses + 1 >= pityAfter;
	const free = wheel.FreeSpins ?? 0;
	const clock = useWallClock(!canSpin);
	const heroIn = useStagger(0);
	const landFlash = useFlash(spin.impactNonce, false, 0.5);
	const titlePop = useChangePop(spin.winner);

	// gamepad lands on Spin whenever a spin is ready
	const focusRef = React.useRef<Frame>();
	React.useEffect(() => {
		if (wheel.CanSpin !== true || spin.spinning || !UserInputService.GamepadEnabled) return undefined;
		const job = task.defer(() => {
			const host = focusRef.current;
			if (host !== undefined && host.Parent !== undefined) GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [wheel.CanSpin, spin.spinning]);

	const space = gap(phone, "l");
	const split = !phone && viewport.width >= 1000;
	const avail = phone ? viewport.width - space * 2 - 24 : split ? (viewport.width - 196) * 0.48 - 48 : viewport.width - 196 - 96;
	const diameter = math.floor(math.clamp(math.min(avail, split ? 420 : 360), phone ? 140 : 200, split ? 420 : 360));

	let weightTotal = 0;
	for (const p of prizes) weightTotal += p.Weight ?? 0;

	const headline = spin.failure !== undefined ? (spin.retry ? "Confirm your spin" : "Spin paused") : prize !== undefined ? (prize.Name ?? prize.Id) : spin.spinning ? "…" : canSpin ? "Ready" : "Soon";
	const detail =
		spin.failure ??
		(prize !== undefined
			? (prize.ShortLabel ?? formatReward(prize.Reward))
			: spin.spinning
				? ""
				: canSpin
					? free > 0
						? `${compactNumber(free)} free spin${free === 1 ? "" : "s"}`
						: pityArmed
							? `Next spin lands ${config.PityRarity ?? "Rare"} or better`
							: ""
					: undefined);
	const accent = spin.failure !== undefined ? Iron.ember() : (prize?.Color ?? Iron.brass());

	const history: string[] = [];
	for (const entry of wheel.History ?? []) {
		const found = prizes.find((p) => p.Id === entry.PrizeId);
		history.push(`${os.date("%b %d  %H:%M", entry.At ?? 0)}   ${found?.Name ?? entry.PrizeId ?? "?"}${entry.Pity === true ? "  ★" : ""}`);
	}

	const deck = (
		<frame Size={new UDim2(split ? 0.5 : 1, split ? -space / 2 : 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
			<uilistlayout Padding={new UDim(0, gap(phone, "m"))} SortOrder={Enum.SortOrder.LayoutOrder} />
			<frame Size={new UDim2(1, 0, 0, Type.title(phone) + 14)} BackgroundTransparency={1} LayoutOrder={0}>
				<uiscale Scale={titlePop} />
				<Title text={headline} size={Type.title(phone) + 4} color={Iron.text().Lerp(accent, 0.4)} rarity={prize?.Rarity} tags={prize !== undefined ? ["wave"] : undefined} />
			</frame>
			{detail !== undefined ? (
				<Text text={detail} size={Type.body(phone)} color={spin.failure !== undefined ? Iron.ember() : Iron.soft()} multiline order={1} />
			) : (
				<textlabel
					Size={new UDim2(1, 0, 0, Type.body(phone) + 6)}
					BackgroundTransparency={1}
					Text={clock.map((now) => clockText(math.max(0, (wheel.ReadyAt ?? 0) - now)))}
					FontFace={Fonts.heavy}
					TextColor3={Iron.muted()}
					TextSize={Type.body(phone)}
					TextXAlignment={Enum.TextXAlignment.Left}
					LayoutOrder={1}
				/>
			)}
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, gap(phone, "l"))} VerticalAlignment={Enum.VerticalAlignment.Bottom} SortOrder={Enum.SortOrder.LayoutOrder} />
				<frame Size={UDim2.fromOffset(phone ? 70 : 90, 44)} BackgroundTransparency={1} LayoutOrder={0}>
					<Text text={compactNumber(free > 0 ? free : (wheel.Spins ?? 0))} size={phone ? 22 : 28} font={Fonts.heavy} box={new UDim2(1, 0, 0, phone ? 26 : 32)} />
					<Text text={free > 0 ? "free" : "spins"} size={Type.small(phone)} color={Iron.muted()} box={new UDim2(1, 0, 0, 14)} position={new UDim2(0, 0, 1, -14)} />
				</frame>
				<frame Size={new UDim2(1, -(phone ? 70 : 90) - gap(phone, "l"), 0, 44)} BackgroundTransparency={1} LayoutOrder={1}>
					<Text text={pityArmed ? "★ guaranteed" : `${misses} / ${pityAfter}`} size={Type.small(phone)} color={pityArmed ? Iron.brass() : Iron.muted()} box={new UDim2(1, 0, 0, 18)} />
					<frame Size={new UDim2(1, 0, 0, 8)} Position={new UDim2(0, 0, 1, -12)} BackgroundTransparency={1}>
						<Meter value={pityArmed ? 1 : misses / math.max(1, pityAfter)} color={pityArmed ? Iron.brass() : Iron.steel()} height={8} />
					</frame>
				</frame>
			</frame>
			<frame ref={focusRef} Size={new UDim2(1, 0, 0, 56)} BackgroundTransparency={1} LayoutOrder={3}>
				<Button
					text={spin.spinning ? "Spinning" : spin.retry ? "Confirm spin" : canSpin ? (pityArmed ? "Spin  ★" : "Spin") : "Not yet"}
					onPress={spin.spin}
					disabled={!canSpin || spin.spinning}
					busy={spin.spinning}
					stretch
					height={56}
					textSize={21}
				/>
			</frame>
		</frame>
	);

	return (
		<scrollingframe
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			CanvasSize={new UDim2()}
			AutomaticCanvasSize={Enum.AutomaticSize.Y}
			ScrollBarThickness={phone ? 0 : 4}
			ScrollBarImageColor3={Iron.brassDeep()}
			ScrollingEnabled={!spin.spinning || !phone}
		>
			<uipadding PaddingTop={new UDim(0, space)} PaddingBottom={new UDim(0, space * 3)} PaddingLeft={new UDim(0, space)} PaddingRight={new UDim(0, space)} />
			<uilistlayout Padding={new UDim(0, space)} SortOrder={Enum.SortOrder.LayoutOrder} />

			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0} Position={heroIn.map((p) => UDim2.fromOffset(0, (1 - p) * 16))}>
				<Panel pad={gap(phone, "xl")} spacing={gap(phone, "l")} seam={canSpin || prize !== undefined} rarity={prize?.Rarity ?? "Legendary"} scale={landFlash.map((v) => 1 + v * 0.025)}>
					<Title text="Prize wheel" size={Type.title(phone)} tags={["wave"]} order={0} />
					<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
						<uilistlayout
							FillDirection={split ? Enum.FillDirection.Horizontal : Enum.FillDirection.Vertical}
							HorizontalAlignment={split ? Enum.HorizontalAlignment.Left : Enum.HorizontalAlignment.Center}
							VerticalAlignment={Enum.VerticalAlignment.Center}
							Padding={new UDim(0, space)}
							SortOrder={Enum.SortOrder.LayoutOrder}
						/>
						<frame Size={new UDim2(split ? 0.5 : 1, split ? -space / 2 : 0, 0, diameter + 12)} BackgroundTransparency={1} LayoutOrder={0}>
							<frame Size={UDim2.fromOffset(diameter, diameter)} Position={UDim2.fromScale(0.5, 0.5)} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundTransparency={1} ClipsDescendants>
								<PrizeWheel rewards={prizes as never} controller={spin as never} diameter={diameter} canSpin={wheel.CanSpin === true} reducedMotion={false} />
							</frame>
						</frame>
						{deck}
					</frame>
				</Panel>
			</frame>

			{history.size() > 0 && (
				<Panel pad={gap(phone, "l")} spacing={6} order={1} color={Iron.sunk()}>
					{history.map((line, i) => (
						<Text key={`h${i}`} text={line} size={Type.small(phone)} color={i === 0 ? Iron.text() : Iron.soft()} order={i} />
					))}
				</Panel>
			)}

			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2}>
				<uilistlayout Padding={new UDim(0, gap(phone, "s"))} SortOrder={Enum.SortOrder.LayoutOrder} />
				<Text text={`Odds  ·  guaranteed spins land ${config.PityRarity ?? "Rare"}+  ·  free spin every ${clockText(config.CooldownSeconds ?? 0)}`} size={Type.small(phone)} color={Iron.muted()} multiline order={0} />
				{prizes.map((p, i) => (
					<PrizeRow key={p.Id} prize={p} index={i + 1} chance={weightTotal > 0 ? ((p.Weight ?? 0) / weightTotal) * 100 : 0} phone={phone} won={i === spin.winner} />
				))}
			</frame>
		</scrollingframe>
	);
}

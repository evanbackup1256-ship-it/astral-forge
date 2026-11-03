// The prize wheel page: the wheel and its console (status, guarantee meter, spin button), recent
// spins, and the full prize list with odds. useWheelController owns the spin: it asks the server for
// the prize and plays the motion; the server's answer always decides where the wheel stops.
import React from "@rbxts/react";
import { Icon, rewardIconKind } from "../../ArtKit/Icon";
import { clockText, compactNumber, formatReward } from "../../CoreKit/format";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { InteractionFeedback } from "../../CoreKit/interaction";
import { chromeFor, darken, Layout, Palette, scrollTail, surfaceGradient } from "../../CoreKit/theme";
import { useAntilag } from "../../MotionKit/antilag";
import { useStagger, useViewport, useWallClock } from "../../MotionKit/motion";
import Juice = require("../../JuiceFx");
import PrizeWheel = require("../../PrizeWheel");
import { Badge, Button, IconTile, Meter, Panel, Text } from "../../UiCore/ui";
import { loadAudio, loadPageScaffold, named } from "../luauDeps";

const UserInputService = game.GetService("UserInputService");
const RunService = game.GetService("RunService");
const Audio = loadAudio();
const PageScaffold = loadPageScaffold();

// The spin, in five parts. Angles in degrees, time in seconds.
//   windup  a short pull back against the spin
//   launch  ease in up to cruise speed
//   cruise  constant speed until the server has picked the prize
//   brake   quartic ease-out onto the prize (+ a little overshoot); it starts at exactly the
//           cruise speed so there is no hitch, and spends its last second crawling past pegs
//   settle  the peg catches the overshoot and the wheel rocks back onto the prize
const WHEEL_OMEGA = 1440;
const WHEEL_OMEGA_LOW = 1080;
const WHEEL_WINDUP_SECONDS = 0.3;
const WHEEL_WINDUP_DEGREES = 18;
const WHEEL_LAUNCH_SECONDS = 0.55;
const WHEEL_MIN_CRUISE_SECONDS = 0.45;
const WHEEL_SETTLE_SECONDS = 0.45;
const WHEEL_OVERSHOOT_DEGREES = 4;
const PRIZE_ROW_H = 84;

interface WheelReward {
	Id: string;
	Name?: string;
	ShortLabel?: string;
	Reward: unknown;
	Color: Color3;
	Rarity?: string;
	Weight?: number;
}
interface Receipt {
	PrizeIndex?: number;
	PrizeId?: string;
	ExpectedSpin?: number;
}
interface WheelState {
	CanSpin?: boolean;
	Spins?: number;
	FreeSpins?: number;
	ReadyAt?: number;
	PityMisses?: number;
	PityAfter?: number;
	PityArmed?: boolean;
	LastReceipt?: Receipt;
	History?: Array<{ PrizeId: string; At: number; Pity?: boolean }>;
}
interface WheelConfig {
	Rewards: WheelReward[];
	CooldownSeconds: number;
	PityAfter?: number;
	PityRarity?: string;
}
interface SpinReply {
	ok?: boolean;
	error?: string;
	message?: string;
	Uncertain?: boolean;
	PrizeIndex?: number;
	PrizeId?: string;
}
interface Props {
	state: { Wheel: WheelState };
	config: { Wheel: WheelConfig; ClientPageGuides?: { Wheel?: { PityArmed?: string; Ready?: string } } };
	dispatch: (action: string, payload: object, callback: (response: SpinReply) => void) => unknown;
	reducedMotion?: boolean;
	onLand?: (message?: string) => void;
}
interface SpinResult {
	index: number;
	message?: string;
}
interface Motor {
	active: boolean;
	mode: "spin" | "brake";
	base: number;
	omega: number;
	startedAt: number;
	lastSegment: number;
	lastSoundAt: number;
	// brake only
	distance: number;
	overshoot: number;
	duration: number;
	result?: SpinResult;
}
type Phase = "idle" | "launch" | "coast" | "brake" | "landed" | "error";

/** Where the wheel is (degrees) and how fast it turns, `elapsed` seconds into windup + launch + cruise. */
function sampleSpin(plan: Motor, elapsed: number): LuaTuple<[number, number]> {
	const omega = plan.omega;
	if (elapsed < WHEEL_WINDUP_SECONDS) {
		const u = elapsed / WHEEL_WINDUP_SECONDS;
		return $tuple(plan.base - WHEEL_WINDUP_DEGREES * math.sin((u * math.pi) / 2), 0);
	}
	const start = plan.base - WHEEL_WINDUP_DEGREES;
	const launched = elapsed - WHEEL_WINDUP_SECONDS;
	if (launched < WHEEL_LAUNCH_SECONDS) {
		const u = launched / WHEEL_LAUNCH_SECONDS;
		// speed rises as u^2, so distance is the integral u^3 / 3
		return $tuple(start + (omega * WHEEL_LAUNCH_SECONDS * u * u * u) / 3, omega * u * u);
	}
	return $tuple(start + (omega * WHEEL_LAUNCH_SECONDS) / 3 + omega * (launched - WHEEL_LAUNCH_SECONDS), omega);
}

/** Brake + settle: where the wheel is `elapsed` seconds after braking began, its speed, and whether it has settled. */
function sampleBrake(plan: Motor, elapsed: number): LuaTuple<[number, number, boolean]> {
	if (elapsed < plan.duration) {
		const remaining = 1 - elapsed / plan.duration;
		const r3 = remaining * remaining * remaining;
		return $tuple(plan.base + plan.distance * (1 - r3 * remaining), ((4 * plan.distance) / plan.duration) * r3, false);
	}
	const u = math.clamp((elapsed - plan.duration) / WHEEL_SETTLE_SECONDS, 0, 1);
	// from +overshoot back to the prize, rocking once past it
	const rock = plan.overshoot * (1 - u) * math.cos(u * math.pi * 1.5);
	return $tuple(plan.base + plan.distance - plan.overshoot + rock, 0, u >= 1);
}

const positiveModulo = (value: number, modulus: number) => ((value % modulus) + modulus) % modulus;

// A spin whose server answer never arrived. It outlives the page (module scope), so reopening the
// wheel asks the player to confirm it instead of starting a second draw.
let unresolvedSpin: { ExpectedSpin?: number } | undefined;

/** The 0-based wheel slot for a server prize, if it names a real prize on this wheel. */
function wheelPrizeIndex(rewards: WheelReward[], index: unknown, id: unknown): number | undefined {
	if (!typeIs(index, "number") || index % 1 !== 0 || index < 1 || index > rewards.size()) return undefined;
	if (!typeIs(id, "string") || rewards[index - 1].Id !== id) return undefined;
	return index - 1;
}

function useWheelController({ state, config, dispatch, reducedMotion, onLand }: Props) {
	const antilag = useAntilag();
	const rewards = config.Wheel.Rewards;
	const segment = 360 / math.max(1, rewards.size());
	const receipt = state.Wheel.LastReceipt;
	const restoredIndex = receipt !== undefined ? (wheelPrizeIndex(rewards, receipt.PrizeIndex, receipt.PrizeId) ?? -1) : -1;
	const mismatched = receipt !== undefined && restoredIndex < 0;
	const [phase, setPhase] = React.useState<Phase>(unresolvedSpin !== undefined || mismatched ? "error" : restoredIndex >= 0 ? "landed" : "idle");
	const [winner, setWinner] = React.useState(restoredIndex);
	const [failure, setFailure] = React.useState<string | undefined>(
		unresolvedSpin !== undefined
			? "Confirm your interrupted spin before starting another."
			: mismatched
				? "Your saved reward does not match this wheel. Refresh before spinning."
				: undefined,
	);
	const [launchNonce, setLaunchNonce] = React.useState(0);
	const [impactNonce, setImpactNonce] = React.useState(0);
	const restoredRotation = restoredIndex >= 0 ? positiveModulo(360 - restoredIndex * segment, 360) : 0;
	const [rotation, setRotation] = React.useBinding(restoredRotation);
	const [pointerKick, setPointerKick] = React.useBinding(0);
	const [spinEnergy, setSpinEnergy] = React.useBinding(0);
	const rotationValue = React.useRef(restoredRotation);
	const pointerKickValue = React.useRef(0);
	const busy = React.useRef(false);
	const mounted = React.useRef(true);
	// bumped whenever a spin ends or is abandoned, so a late server reply for it is ignored
	const token = React.useRef(0);
	const timeout = React.useRef<thread>();
	const pendingResult = React.useRef<SpinResult>();
	const beginBrakeRef = React.useRef<(result: SpinResult) => void>(() => {});
	const motor = React.useRef<Motor>({
		active: false,
		mode: "spin",
		base: 0,
		omega: WHEEL_OMEGA,
		startedAt: 0,
		lastSegment: 0,
		lastSoundAt: -math.huge,
		distance: 0,
		overshoot: 0,
		duration: 1,
	});
	const omega = antilag.tier <= 1 ? WHEEL_OMEGA_LOW : WHEEL_OMEGA;
	const spinning = phase === "launch" || phase === "coast" || phase === "brake";
	const audioTicksRef = React.useRef(false);
	audioTicksRef.current = !reducedMotion && antilag.fxBudget > 0.22;

	/** Stop every motion and put the wheel back in the player's hands. */
	const halt = () => {
		busy.current = false;
		pendingResult.current = undefined;
		motor.current.active = false;
		pointerKickValue.current = 0;
		setPointerKick(0);
		setSpinEnergy(0);
	};

	const completeLanding = React.useCallback(
		(result: SpinResult, finalRotation: number) => {
			if (!mounted.current || !busy.current) return;
			const normalized = positiveModulo(finalRotation, 360);
			rotationValue.current = normalized;
			pointerKickValue.current = 0;
			setRotation(normalized);
			setPointerKick(0);
			setSpinEnergy(0);
			setWinner(result.index);
			setImpactNonce((value) => value + 1);
			setPhase("landed");
			busy.current = false;
			pendingResult.current = undefined;
			pcall(() => Juice.live("wheel", undefined));
			Audio.play("wheelLand");
			InteractionFeedback.reward();
			onLand?.(result.message);
		},
		[onLand, setPointerKick, setRotation, setSpinEnergy],
	);

	const beginBrake = React.useCallback(
		(result: SpinResult) => {
			if (!mounted.current || !busy.current) return;
			const wanted = positiveModulo(360 - result.index * segment, 360);
			if (reducedMotion) {
				Audio.play("wheelBrake");
				completeLanding(result, wanted);
				return;
			}
			const now = os.clock();
			const plan = motor.current;
			const [current, rawSpeed] = sampleSpin(plan, now - plan.startedAt);
			const speed = math.max(rawSpeed, 360);
			const delta = positiveModulo(wanted - positiveModulo(current, 360), 360);
			const overshoot = math.min(WHEEL_OVERSHOOT_DEGREES, segment * 0.3);
			// at least two full turns on the way down (three when the device has room for it)
			const distance = (antilag.tier <= 1 ? 720 : 1080) + delta + overshoot;
			motor.current = {
				active: true,
				mode: "brake",
				base: current,
				omega: plan.omega,
				distance,
				overshoot,
				duration: (4 * distance) / speed,
				startedAt: now,
				lastSegment: math.floor((current + segment / 2) / segment),
				lastSoundAt: plan.lastSoundAt,
				result,
			};
			rotationValue.current = current;
			setPhase("brake");
			Audio.play("wheelBrake");
		},
		[antilag.tier, completeLanding, reducedMotion, segment],
	);
	beginBrakeRef.current = beginBrake;

	React.useEffect(() => {
		if (!spinning) return undefined;
		const connection = RunService.RenderStepped.Connect((deltaTime) => {
			// the pointer springs back after each peg flicks it
			if (pointerKickValue.current > 0) {
				pointerKickValue.current = math.max(0, pointerKickValue.current - deltaTime * 9);
				setPointerKick(pointerKickValue.current);
			}
			const plan = motor.current;
			if (!plan.active) return;
			const now = os.clock();
			const elapsed = now - plan.startedAt;
			const braking = plan.mode === "brake";
			let value: number;
			let speed: number;
			let settled = false;
			if (braking) {
				[value, speed, settled] = sampleBrake(plan, elapsed);
			} else {
				[value, speed] = sampleSpin(plan, elapsed);
			}
			rotationValue.current = value;
			setRotation(value);
			const energy = math.clamp(speed / plan.omega, 0, 1);
			setSpinEnergy(energy);
			// pegs sit on the segment edges; crossing one flicks the pointer and clicks
			const currentSegment = math.floor((value + segment / 2) / segment);
			if (currentSegment !== plan.lastSegment) {
				plan.lastSegment = currentSegment;
				// a slow wheel gives the pointer time to swing further
				pointerKickValue.current = math.max(pointerKickValue.current, 0.4 + (1 - energy) * 0.6);
				setPointerKick(pointerKickValue.current);
				const interval = energy > 0.6 ? 0.055 : 0;
				if (audioTicksRef.current && now - plan.lastSoundAt >= interval) {
					plan.lastSoundAt = now;
					Audio.play(braking && energy < 0.25 ? "wheelSlow" : "wheelTick", 0.86 + energy * 0.3);
				}
			}
			if (!braking) {
				const result = pendingResult.current;
				if (result !== undefined && elapsed >= WHEEL_WINDUP_SECONDS + WHEEL_LAUNCH_SECONDS + WHEEL_MIN_CRUISE_SECONDS) {
					beginBrakeRef.current(result);
				}
				return;
			}
			if (settled && plan.result !== undefined) {
				plan.active = false;
				completeLanding(plan.result, plan.base + plan.distance - plan.overshoot);
			}
		});
		return () => connection.Disconnect();
	}, [completeLanding, segment, setPointerKick, setRotation, setSpinEnergy, spinning]);

	React.useEffect(
		() => () => {
			mounted.current = false;
			busy.current = false;
			pcall(() => Juice.live("wheel", undefined));
			token.current += 1;
			motor.current.active = false;
			if (timeout.current !== undefined) pcall(task.cancel, timeout.current);
		},
		[],
	);

	// a receipt from the server (this session or a saved one) puts the wheel on its prize
	React.useEffect(() => {
		if (busy.current || receipt === undefined) return;
		if (unresolvedSpin !== undefined && unresolvedSpin.ExpectedSpin === receipt.ExpectedSpin) unresolvedSpin = undefined;
		if (unresolvedSpin !== undefined) return;
		const index = wheelPrizeIndex(rewards, receipt.PrizeIndex, receipt.PrizeId);
		if (index === undefined) {
			setPhase("error");
			setFailure("Your saved reward does not match this wheel. Refresh before spinning.");
			return;
		}
		const value = positiveModulo(360 - index * segment, 360);
		rotationValue.current = value;
		setRotation(value);
		setWinner(index);
		setFailure(undefined);
		setPhase("landed");
	}, [receipt, spinning, rewards, segment, setRotation]);

	const spin = () => {
		if (busy.current || (unresolvedSpin === undefined && !state.Wheel.CanSpin)) return;
		const order = unresolvedSpin ?? { ExpectedSpin: state.Wheel.Spins };
		unresolvedSpin = order;
		busy.current = true;
		token.current += 1;
		const requestToken = token.current;
		pendingResult.current = undefined;
		pointerKickValue.current = 0;
		setPointerKick(0);
		setWinner(-1);
		setFailure(undefined);
		setLaunchNonce((value) => value + 1);
		Audio.play("wheelStart");
		InteractionFeedback.tap();
		// the spin is pinned to the island until it lands (or 14 s at most)
		pcall(() => Juice.live("wheel", { title: "Wheel spinning", value: "…", icon: "Wheel.6", color: Palette.mango, ttl: 14, priority: 2 }));
		if (reducedMotion) {
			motor.current.active = false;
			setPhase("coast");
		} else {
			motor.current = {
				...motor.current,
				active: true,
				mode: "spin",
				base: rotationValue.current,
				omega,
				startedAt: os.clock(),
				lastSegment: math.floor((rotationValue.current + segment / 2) / segment),
				lastSoundAt: -math.huge,
				result: undefined,
			};
			setPhase("launch");
		}
		if (timeout.current !== undefined) pcall(task.cancel, timeout.current);
		timeout.current = task.delay(12, () => {
			timeout.current = undefined;
			if (!mounted.current || token.current !== requestToken || !busy.current) return;
			token.current += 1;
			halt();
			setPhase("error");
			setFailure("No result yet. Confirm the previous spin to check its saved reward.");
			Audio.play("requestTimeout");
		});
		dispatch("SpinWheel", order, (response) => {
			if (response.Uncertain !== true && unresolvedSpin === order) unresolvedSpin = undefined;
			if (!mounted.current || token.current !== requestToken) return;
			if (timeout.current !== undefined) {
				pcall(task.cancel, timeout.current);
				timeout.current = undefined;
			}
			if (!response.ok || response.PrizeIndex === undefined) {
				halt();
				setPhase("error");
				setFailure(
					response.Uncertain
						? "Connection interrupted. Confirm the previous spin before starting another."
						: (response.error ?? "The draw could not be completed."),
				);
				Audio.play("error");
				return;
			}
			const resultIndex = wheelPrizeIndex(rewards, response.PrizeIndex, response.PrizeId);
			if (resultIndex === undefined) {
				busy.current = false;
				motor.current.active = false;
				setPhase("error");
				setFailure("Your reward was saved, but its artwork is unavailable. Reopen the wheel to refresh.");
				return;
			}
			const result = { index: resultIndex, message: response.message };
			pendingResult.current = result;
			if (reducedMotion) beginBrakeRef.current(result);
		});
	};

	return {
		phase,
		spinning,
		winner,
		failure,
		retry: unresolvedSpin !== undefined,
		launchNonce,
		impactNonce,
		rotation,
		pointerKick,
		spinEnergy,
		spin,
	};
}
type WheelController = ReturnType<typeof useWheelController>;

interface ConsoleProps {
	state: Props["state"];
	config: Props["config"];
	controller: WheelController;
	height: number;
	reducedMotion?: boolean;
	spinClaimHostRef: React.MutableRefObject<Frame | undefined>;
	compact: boolean;
}

/** Status, prize, free-spin and guarantee tiles, and the spin button. */
function WheelConsole({ state, config, controller, height, reducedMotion, spinClaimHostRef, compact }: ConsoleProps) {
	const wheel = state.Wheel;
	const prize = controller.winner >= 0 ? config.Wheel.Rewards[controller.winner] : undefined;
	const failed = controller.failure !== undefined;
	const canSpin = wheel.CanSpin === true || controller.retry;
	const pityMisses = wheel.PityMisses ?? 0;
	const pityAfter = wheel.PityAfter ?? config.Wheel.PityAfter ?? 8;
	const pityArmed = wheel.PityArmed === true || pityMisses + 1 >= pityAfter;
	const pityFill = pityArmed ? 1 : math.clamp(pityMisses / math.max(1, pityAfter), 0, 1);
	const freeSpins = wheel.FreeSpins ?? 0;
	const now = useWallClock(!canSpin);
	const cooldown = now.map((timestamp) => `Ready again in ${clockText(math.max(0, (wheel.ReadyAt ?? 0) - timestamp))}`);
	const guide = config.ClientPageGuides?.Wheel;
	const status = controller.spinning ? "Spinning" : failed ? "Spin paused" : prize !== undefined ? "You won" : canSpin ? "Ready to spin" : "Cooling down";
	const title = failed
		? controller.retry
			? "Confirm your previous spin"
			: "Spin unavailable"
		: (prize?.Name ?? (controller.spinning ? "Spinning…" : canSpin ? "Spin ready" : "Next spin soon"));
	let detail: string | React.Binding<string>;
	if (failed) {
		detail = controller.failure!;
	} else if (prize?.ShortLabel !== undefined) {
		detail = prize.ShortLabel;
	} else if (controller.spinning) {
		detail = "";
	} else if (!canSpin) {
		detail = cooldown;
	} else if (freeSpins > 0) {
		detail = `${compactNumber(freeSpins)} free spin${freeSpins === 1 ? "" : "s"} ready.`;
	} else if (pityArmed) {
		detail = guide?.PityArmed ?? "Guarantee ready: your next spin lands Rare or better.";
	} else {
		detail = compact ? "Tap once to spin." : (guide?.Ready ?? "Tap Spin in the middle of the wheel.");
	}
	const accent = failed ? Palette.coral : (prize?.Color ?? (canSpin ? Palette.mango : Palette.lineSoft));
	const live = canSpin && !controller.spinning;
	const edge = compact ? 10 : 14;
	const iconBox = compact ? 58 : 72;
	const iconInset = compact ? 7 : 9;
	const prizeIcon = compact ? 44 : 54;
	const copyX = compact ? 78 : 98;
	const copyRight = compact ? 88 : 112;
	const statsTop = compact ? 176 : 156;
	const statsHeight = compact ? 42 : 52;
	const buttonHeight = compact ? 48 : 50;
	const buttonBottom = compact ? 10 : 14;
	return (
		<frame Size={new UDim2(1, 0, 0, height)} BackgroundColor3={Palette.ink} BorderSizePixel={0} ClipsDescendants={true}>
			<uicorner CornerRadius={new UDim(0, 14)} />
			<uigradient Color={surfaceGradient(Palette.panel, 0.62)} Rotation={90} />
			<uistroke Color={accent} Thickness={1} Transparency={0.42} />
			<frame Size={new UDim2(0.46, 0, 0, 3)} Position={UDim2.fromOffset(edge, 0)} BackgroundColor3={accent} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uigradient Transparency={new NumberSequence([new NumberSequenceKeypoint(0, 0.06), new NumberSequenceKeypoint(1, 1)])} />
			</frame>
			<frame
				Size={UDim2.fromOffset(iconBox, iconBox)}
				Position={UDim2.fromOffset(edge, compact ? 12 : 16)}
				BackgroundColor3={darken(accent, 0.76).Lerp(Palette.panelRaised, 0.42)}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(0, 14)} />
				<uistroke Color={accent} Thickness={prize !== undefined ? 2 : 1} Transparency={prize !== undefined ? 0.08 : 0.46} />
				{prize !== undefined ? (
					<frame Size={UDim2.fromOffset(prizeIcon, prizeIcon)} Position={UDim2.fromOffset(iconInset, iconInset)} BackgroundTransparency={1} BorderSizePixel={0}>
						<Icon kind={rewardIconKind(prize.Reward as never)} color={prize.Color} accent={prize.Color} size={prizeIcon} />
					</frame>
				) : (
					<Icon kind="Wheel.7" color={Palette.cream} accent={Palette.mango} size={compact ? 40 : 48} position={UDim2.fromScale(0.5, 0.5)} anchorPoint={new Vector2(0.5, 0.5)} />
				)}
			</frame>
			<Badge
				value={status}
				accent={accent}
				filled={prize !== undefined || failed}
				position={UDim2.fromOffset(copyX, compact ? 12 : 16)}
				size={new UDim2(1, -copyRight, 0, compact ? 22 : 24)}
			/>
			<Text
				value={title}
				size={compact ? 15 : 18}
				color={failed ? Palette.coral : (prize?.Color ?? Palette.cream)}
				weight={Enum.FontWeight.Heavy}
				wrap={true}
				fit={true}
				minSize={12}
				position={UDim2.fromOffset(copyX, compact ? 38 : 44)}
				sizeConstraint={new UDim2(1, -copyRight, 0, 42)}
			/>
			<Text
				value={detail}
				size={12}
				color={Palette.creamSoft}
				wrap={true}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(copyX, compact ? 82 : 88)}
				sizeConstraint={new UDim2(1, -copyRight, 0, compact ? 84 : 60)}
			/>
			<frame Size={new UDim2(1, -edge * 2, 0, statsHeight)} Position={UDim2.fromOffset(edge, statsTop)} BackgroundTransparency={1} BorderSizePixel={0}>
				<frame Size={new UDim2(0.34, -5, 1, 0)} BackgroundColor3={Palette.panelRaised} BorderSizePixel={0}>
					<uicorner CornerRadius={new UDim(0, 9)} />
					<uistroke Color={Palette.lineSoft} Thickness={1} Transparency={0.64} />
					<Text
						value={freeSpins > 0 ? "Free spins" : "Total spins"}
						size={12}
						color={Palette.muted}
						weight={Enum.FontWeight.Heavy}
						position={UDim2.fromOffset(10, 5)}
						sizeConstraint={new UDim2(1, -20, 0, 15)}
					/>
					<Text
						value={compactNumber(freeSpins > 0 ? freeSpins : (wheel.Spins ?? 0))}
						size={compact ? 14 : 16}
						color={Palette.cream}
						weight={Enum.FontWeight.Heavy}
						position={UDim2.fromOffset(10, compact ? 21 : 23)}
						sizeConstraint={new UDim2(1, -20, 0, compact ? 18 : 22)}
					/>
				</frame>
				<frame Size={new UDim2(0.66, -5, 1, 0)} Position={new UDim2(0.34, 5, 0, 0)} BackgroundColor3={Palette.panelRaised} BorderSizePixel={0}>
					<uicorner CornerRadius={new UDim(0, 9)} />
					<uistroke Color={pityArmed ? Palette.mango : Palette.lineSoft} Thickness={1} Transparency={pityArmed ? 0.28 : 0.64} />
					<Text
						value="Guarantee"
						size={12}
						color={pityArmed ? Palette.mango : Palette.muted}
						weight={Enum.FontWeight.Heavy}
						position={UDim2.fromOffset(10, 5)}
						sizeConstraint={new UDim2(0.65, -10, 0, 15)}
					/>
					<Text
						value={pityArmed ? "Ready" : `${pityMisses} / ${pityAfter}`}
						size={12}
						color={pityArmed ? Palette.mango : Palette.creamSoft}
						weight={Enum.FontWeight.Heavy}
						align={Enum.TextXAlignment.Right}
						position={new UDim2(0.65, 0, 0, 5)}
						sizeConstraint={new UDim2(0.35, -10, 0, 15)}
					/>
					<Meter
						value={pityFill}
						color={pityArmed ? Palette.mango : Palette.violet}
						reducedMotion={reducedMotion}
						shimmer={pityArmed}
						position={UDim2.fromOffset(10, compact ? 27 : 31)}
						size={new UDim2(1, -20, 0, compact ? 6 : 7)}
					/>
				</frame>
			</frame>
			<frame
				{...named("WheelSpinClaimActions")}
				ref={spinClaimHostRef}
				Size={new UDim2(1, -edge * 2, 0, buttonHeight)}
				Position={new UDim2(0, edge, 1, -(buttonHeight + buttonBottom))}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={false}
			>
				<Button
					text={
						controller.spinning
							? "Spinning..."
							: controller.retry
								? "Confirm previous spin"
								: canSpin
									? pityArmed
										? "Spin, rarity guaranteed"
										: "Spin prize wheel"
									: "Next spin not ready"
					}
					icon="Wheel.8"
					onClick={controller.spin}
					color={live ? Palette.mango : Palette.panelSoft}
					textColor={live ? Palette.ink : Palette.muted}
					size={UDim2.fromScale(1, 1)}
					reducedMotion={reducedMotion}
					disabled={controller.spinning || !canSpin}
					highlight={live}
				/>
			</frame>
		</frame>
	);
}

function PrizeCatalogRow({ reward, index, weightTotal, reducedMotion }: { reward: WheelReward; index: number; weightTotal: number; reducedMotion?: boolean }) {
	const chance = weightTotal > 0 ? ((reward.Weight ?? 0) / weightTotal) * 100 : 0;
	return (
		<Panel size={new UDim2(1, 0, 0, PRIZE_ROW_H - 6)} accent={reward.Color} background={Palette.panel} padding={10} reducedMotion={reducedMotion} clips={false}>
			<IconTile
				kind={reward.Reward !== undefined ? rewardIconKind(reward.Reward as never) : "Wheel"}
				accent={reward.Color}
				size={40}
				radius={10}
				glow={reward.Rarity === "Legendary" || reward.Rarity === "Exotic"}
				filled={true}
				reducedMotion={reducedMotion}
			/>
			<Text
				value={`${index}. ${reward.Name ?? reward.Id}`}
				size={14}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={11}
				wrap={true}
				position={UDim2.fromOffset(50, 0)}
				sizeConstraint={new UDim2(1, -160, 0, 38)}
			/>
			<Text
				value={`${reward.Rarity} · ${string.format("%.1f", chance)}%`}
				size={11}
				color={reward.Color}
				weight={Enum.FontWeight.Bold}
				fit={true}
				position={UDim2.fromOffset(50, 42)}
				sizeConstraint={new UDim2(1, -160, 0, 18)}
			/>
			<Badge
				value={reward.ShortLabel ?? formatReward(reward.Reward as never)}
				accent={reward.Color}
				filled={true}
				position={new UDim2(1, -100, 0, 6)}
				size={UDim2.fromOffset(100, 24)}
			/>
		</Panel>
	);
}

const titleCase = (word: string) => string.upper(word.sub(1, 1)) + string.lower(word.sub(2));

function WheelView(props: Props) {
	const { state, config } = props;
	const softMotion = props.reducedMotion;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const [pageWidth, setPageWidth] = React.useState<number>();
	const availableWidth = pageWidth ?? math.max(100, viewport.width - 280);
	const spinClaimHostRef = React.useRef<Frame>();
	const controller = useWheelController(props);
	const canSpin = state.Wheel.CanSpin === true;
	// a controller lands on Spin whenever a spin is ready
	React.useEffect(() => {
		const host = spinClaimHostRef.current;
		if (!canSpin || controller.spinning || !UserInputService.GamepadEnabled || host === undefined) return undefined;
		const selectJob = task.defer(() => {
			if (host.Parent !== undefined) GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, selectJob);
		};
	}, [canSpin, controller.spinning]);

	const rewards = config.Wheel.Rewards;
	const landscape = chrome.landscape || (viewport.width > viewport.height * 1.35 && viewport.height < 680);
	const shortLandscape = landscape && viewport.width >= 480 && viewport.width < 900 && viewport.height <= 430;
	const split = !chrome.contentStack && availableWidth >= 760;
	const narrowPortrait = !landscape && viewport.width <= 360;
	const widthCap = (split ? availableWidth * 0.48 : availableWidth) - chrome.cardPadding * 2 - 24;
	const heightCap = shortLandscape ? 240 : split ? 420 : 360;
	const fitted = shortLandscape
		? math.clamp(math.min(widthCap, heightCap), 190, 220)
		: math.clamp(math.min(widthCap, heightCap), chrome.contentStack ? 140 : 180, split ? 410 : 340);
	const wheelDiameter = math.max(100, math.min(math.floor(fitted), widthCap));
	const headerH = shortLandscape ? 74 : narrowPortrait ? 100 : 92;
	const consoleH = shortLandscape || chrome.contentStack ? 300 : 280;
	const stageH = split ? math.max(wheelDiameter + 24, consoleH) : wheelDiameter + 40 + consoleH;
	const panelH = headerH + stageH + chrome.cardPadding * 2;
	// The legend shares the page scroll, so the wheel no longer needs to shrink
	// to make an artificial nested prize viewport fit above the fold.
	const headerReveal = useStagger(0, softMotion);
	const accent = controller.winner >= 0 ? (rewards[controller.winner]?.Color ?? Palette.mango) : Palette.mango;
	let weightTotal = 0;
	for (const reward of rewards) weightTotal += reward.Weight ?? 0;
	const recentSpins = (typeIs(state.Wheel.History, "table") ? state.Wheel.History : []).map((entry) => {
		let name = entry.PrizeId;
		rewards.forEach((reward, i) => {
			if (reward.Id === entry.PrizeId) name = `${i + 1}. ${reward.Name ?? reward.Id}`;
		});
		return `${os.date("%b %d, %H:%M", entry.At)}   ${name}${entry.Pity ? "  (guaranteed)" : ""}`;
	});
	const recentH = math.max(1, recentSpins.size()) * 24;

	return (
		<frame
			{...named("WheelPage")}
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			Change={{
				AbsoluteSize: (host) => {
					const absoluteX = host.AbsoluteSize.X;
					if (absoluteX <= 0) return;
					let scale = game.GetService("Workspace").GetAttribute("AstralForgeVRCanvasWidth") !== undefined ? 1 : Layout.chromeScale;
					if (!typeIs(scale, "number") || scale <= 0) scale = 1;
					const width = math.floor(absoluteX / scale);
					// Same width again must not schedule another render; a size fight retriggers AbsoluteSize.
					if (width > 0 && width !== pageWidth) setPageWidth(width);
				},
			}}
		>
			<PageScaffold
				gap={0}
				tailPad={scrollTail(chrome.stack, chrome.bottomSafe, 40)}
				scrollBarColor={accent}
				scrollBarThickness={4}
				sections={[
					{
						id: "wheel",
						height: panelH,
						element: (
							<Panel
								size={UDim2.fromScale(1, 1)}
								accent={accent}
								background={Palette.panelRaised}
								padding={chrome.cardPadding}
								reveal={headerReveal}
								reducedMotion={softMotion}
								clips={false}
							>
								<Text
									value="Prize wheel"
									size={12}
									color={Palette.mango}
									weight={Enum.FontWeight.Heavy}
									fit={false}
									sizeConstraint={new UDim2(1, 0, 0, shortLandscape ? 14 : 16)}
								/>
								<Text
									value="The prize wheel"
									size={shortLandscape ? 16 : chrome.contentStack ? 18 : 21}
									color={Palette.cream}
									weight={Enum.FontWeight.Heavy}
									fit={narrowPortrait}
									minSize={14}
									wrap={narrowPortrait}
									position={UDim2.fromOffset(0, shortLandscape ? 14 : 18)}
									sizeConstraint={new UDim2(1, 0, 0, narrowPortrait ? 36 : shortLandscape ? 22 : 28)}
								/>
								<Text
									value={`${rewards.size()} prizes · free spin every ${clockText(config.Wheel.CooldownSeconds)}`}
									size={12}
									color={Palette.muted}
									wrap={true}
									fit={true}
									minSize={11}
									position={UDim2.fromOffset(0, narrowPortrait ? 57 : shortLandscape ? 36 : 46)}
									sizeConstraint={new UDim2(1, 0, 0, 30)}
								/>
								<frame
									Size={UDim2.fromOffset(wheelDiameter, wheelDiameter)}
									Position={split ? new UDim2(0.25, 0, 0, headerH + stageH / 2) : new UDim2(0.5, 0, 0, headerH)}
									AnchorPoint={split ? new Vector2(0.5, 0.5) : new Vector2(0.5, 0)}
									BackgroundTransparency={1}
									BorderSizePixel={0}
									ClipsDescendants={true}
								>
									<PrizeWheel rewards={rewards} controller={controller} diameter={wheelDiameter} canSpin={canSpin} reducedMotion={softMotion} />
								</frame>
								<frame
									Size={split ? new UDim2(0.48, -10, 0, consoleH) : new UDim2(1, 0, 0, consoleH)}
									Position={split ? new UDim2(0.52, 10, 0, headerH + (stageH - consoleH) / 2) : UDim2.fromOffset(0, headerH + wheelDiameter + 40)}
									BackgroundTransparency={1}
									BorderSizePixel={0}
								>
									<WheelConsole
										state={state}
										config={config}
										controller={controller}
										height={consoleH}
										reducedMotion={softMotion}
										spinClaimHostRef={spinClaimHostRef}
										compact={shortLandscape || chrome.contentStack}
									/>
								</frame>
							</Panel>
						),
					},
					{
						id: "recent-spins",
						height: 36 + recentH,
						element: (
							<Panel size={UDim2.fromScale(1, 1)} accent={Palette.mango} background={Palette.panel} padding={12} clips={false}>
								<Text value="Recent spins" size={14} color={Palette.mango} weight={Enum.FontWeight.Heavy} sizeConstraint={new UDim2(1, 0, 0, 20)} />
								<Text
									value={recentSpins.size() === 0 ? "No spins yet. Your prizes will be listed here." : recentSpins.join("\n")}
									size={13}
									color={Palette.creamSoft}
									wrap={true}
									fit={true}
									minSize={11}
									position={UDim2.fromOffset(0, 24)}
									sizeConstraint={new UDim2(1, 0, 0, recentH)}
								/>
							</Panel>
						),
					},
					{
						id: "prizes-label",
						height: 32,
						element: <Text value="Prizes · standard odds" size={13} color={Palette.mango} weight={Enum.FontWeight.Heavy} sizeConstraint={new UDim2(1, 0, 0, 20)} />,
					},
					{
						id: "prizes-odds",
						height: 64,
						element: (
							<Text
								value={`Numbers match the wheel. Guaranteed spins only land ${titleCase(config.Wheel.PityRarity ?? "Rare")} or better.`}
								size={12}
								color={Palette.creamSoft}
								wrap={true}
								fit={false}
								sizeConstraint={new UDim2(1, 0, 1, 0)}
							/>
						),
					},
					{
						id: "prizes",
						height: PRIZE_ROW_H * rewards.size() + 8,
						// one page scroll owns the complete legend: no clipped nested prize viewport
						element: (
							<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
								<uilistlayout key="layout" SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 6)} />
								{rewards.map((reward, i) => (
									<frame key={reward.Id} Size={new UDim2(1, -6, 0, PRIZE_ROW_H - 6)} BackgroundTransparency={1} LayoutOrder={i + 1}>
										<PrizeCatalogRow reward={reward} index={i + 1} weightTotal={weightTotal} reducedMotion={softMotion} />
									</frame>
								))}
							</frame>
						),
					},
				]}
			/>
		</frame>
	);
}

export = { WheelView };

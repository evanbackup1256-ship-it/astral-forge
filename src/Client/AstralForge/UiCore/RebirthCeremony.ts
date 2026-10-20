import React from "@rbxts/react";
import { asFlux, compactNumber, Flux } from "../CoreKit/format";
import { InteractionFeedback } from "../CoreKit/interaction";
import { Palette } from "../CoreKit/theme";
import { useAntilag } from "../MotionKit/antilag";
import { resolveIntent, useViewport } from "../MotionKit/motion";
import { celebrationsAllowed, flashesAllowed, isReducedMotion } from "../MotionPreference";
import Juice = require("../JuiceFx");
import { SHELL_PAD_KEYS, usePadSink } from "../CoreKit/padSink";

const h = React.createElement as unknown as (component: unknown, props?: object, ...children: unknown[]) => React.Element;

const RunService = game.GetService("RunService");
const AstralForge = script.Parent!.Parent!;

interface AudioApi {
	play(name: string, pitch?: number): void;
}
const Audio = (
	(require(AstralForge.WaitForChild("AudioKit") as ModuleScript) as (member: string) => unknown)("audio") as { Audio: AudioApi }
).Audio;

const GOLDEN = math.pi * (3 - math.sqrt(5));
const HEAVY = Font.fromEnum(Enum.Font.BuilderSansExtraBold);
const BOLD = Font.fromEnum(Enum.Font.BuilderSansBold);
interface Timeline {
	shock: number;
	count0: number;
	count1: number;
	ascend: number;
	fade: number;
	finish: number;
}
const FULL: Timeline = { shock: 0.55, count0: 0.85, count1: 1.75, ascend: 1.95, fade: 2.8, finish: 3.4 };
const MILESTONE: Timeline = { shock: 0.75, count0: 1.05, count1: 2.15, ascend: 2.35, fade: 3.5, finish: 4.1 };
const CALM: Timeline = { shock: 0, count0: 0.12, count1: 0.6, ascend: 0.7, fade: 1.35, finish: 1.7 };

type Listener = (payload: unknown) => void;
const listeners: Listener[] = [];
function subscribe(listener: Listener) {
	listeners.push(listener);
	return () => {
		const index = listeners.indexOf(listener);
		if (index !== -1) {
			listeners.remove(index);
		}
	};
}
// payload: { rebirths, before, after, reward, stardust }
export function play(payload: unknown) {
	for (const listener of table.clone(listeners)) {
		task.spawn(listener, payload);
	}
}

function ramp(t: number, a: number, b: number) {
	if (b <= a) {
		return t >= b ? 1 : 0;
	}
	return math.clamp((t - a) / (b - a), 0, 1);
}
function outCubic(x: number) {
	const y = 1 - x;
	return 1 - y * y * y;
}
function outBack(x: number) {
	const c = 1.55;
	const y = x - 1;
	return 1 + (c + 1) * y * y * y + c * y * y;
}
// multipliers may be persisted big-number strings; blend in log space so the count never lurches
function blendMultiplier(before: unknown, after: unknown, k: number): unknown {
	if (k >= 1) {
		return after;
	}
	const [a, b] = [asFlux(before as Flux) as unknown, asFlux(after as Flux) as unknown];
	if (
		!typeIs(a, "number") ||
		!typeIs(b, "number") ||
		a !== a ||
		b !== b ||
		a <= 0 ||
		b <= 0 ||
		a === math.huge ||
		b === math.huge
	) {
		return before;
	}
	return math.exp(math.log(a) + (math.log(b) - math.log(a)) * k);
}
function multiplierText(value: unknown) {
	const n = asFlux(value as Flux) as unknown;
	if (typeIs(n, "number") && n < 1000) {
		return string.format("×%.2f", n);
	}
	return "×" + compactNumber(value);
}

function corner(radius?: UDim) {
	return h("uicorner", { CornerRadius: radius ?? new UDim(1, 0) });
}

interface LayerProps {
	clock: React.Binding<number>;
	tl: Timeline;
	count: number;
}

function Motes(props: LayerProps) {
	const [clock, tl, count] = [props.clock, props.tl, props.count];
	const children: Record<string, unknown> = {};
	for (let i = 1; i <= count; i++) {
		const angle = i * GOLDEN;
		const radius = 230 + (i % 5) * 34;
		const lead = (i / count) * 0.2;
		const tint = i % 3 === 0 ? Palette.mint : i % 3 === 1 ? Palette.violet : Palette.pink;
		children["m" + i] = h(
			"frame",
			{
				AnchorPoint: new Vector2(0.5, 0.5),
				Size: UDim2.fromOffset(i % 4 === 0 ? 8 : 5, i % 4 === 0 ? 8 : 5),
				BackgroundColor3: tint,
				BorderSizePixel: 0,
				Position: clock.map((t) => {
					const pull = outCubic(ramp(t, lead, tl.shock));
					const swirl = angle + pull * 1.1;
					const r = radius * (1 - pull);
					return new UDim2(0.5, math.cos(swirl) * r, 0.5, math.sin(swirl) * r * 0.82);
				}),
				BackgroundTransparency: clock.map((t) => {
					if (t >= tl.shock) {
						return 1;
					}
					return 1 - 0.9 * ramp(t, lead, lead + 0.14);
				}),
			},
			corner(),
		);
	}
	return h(React.Fragment, undefined, children);
}

function Rings(props: { clock: React.Binding<number>; tl: Timeline }) {
	const [clock, tl] = [props.clock, props.tl];
	const children: Record<string, unknown> = {};
	for (let k = 0; k <= 2; k++) {
		const start = tl.shock + k * 0.09;
		children["r" + k] = h(
			"frame",
			{
				AnchorPoint: new Vector2(0.5, 0.5),
				Position: UDim2.fromScale(0.5, 0.5),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				Size: clock.map((t) => {
					const p = outCubic(ramp(t, start, start + 0.7));
					return UDim2.fromScale(0.04 + p * (1.25 - k * 0.22), 0.04 + p * (1.25 - k * 0.22));
				}),
				Visible: clock.map((t) => t >= start && t < start + 0.7),
			},
			corner(),
			h("uiaspectratioconstraint", { AspectRatio: 1 }),
			h("uistroke", {
				Color: k === 1 ? Palette.mint : Palette.violet,
				Thickness: 3,
				Transparency: clock.map((t) => 0.15 + 0.85 * ramp(t, start, start + 0.7)),
			}),
		);
	}
	return h(React.Fragment, undefined, children);
}

function Streaks(props: LayerProps) {
	const [clock, tl, count] = [props.clock, props.tl, props.count];
	const children: Record<string, unknown> = {};
	for (let i = 1; i <= count; i++) {
		const x = (i * 0.618034) % 1;
		const start = tl.ascend + (i % 4) * 0.05;
		const length = 0.55 + (i % 3) * 0.14;
		const tall = 70 + ((i * 37) % 90);
		children["s" + i] = h(
			"frame",
			{
				AnchorPoint: new Vector2(0.5, 0),
				Size: UDim2.fromOffset(i % 5 === 0 ? 3 : 2, tall),
				BackgroundColor3: i % 2 === 0 ? Palette.violet : Palette.cream,
				BorderSizePixel: 0,
				Position: clock.map((t) => {
					const p = ramp(t, start, start + length);
					return new UDim2(0.06 + x * 0.88, 0, 1.08 - p * 1.35, 0);
				}),
				BackgroundTransparency: clock.map((t) => {
					if (t < start) {
						return 1;
					}
					return 0.2 + 0.8 * ramp(t, start + length * 0.5, start + length);
				}),
			},
			h("uigradient", {
				Rotation: 90,
				Transparency: new NumberSequence([new NumberSequenceKeypoint(0, 0), new NumberSequenceKeypoint(1, 1)]),
			}),
		);
	}
	return h(React.Fragment, undefined, children);
}

interface CeremonyPayload {
	rebirths?: unknown;
	grade?: unknown;
	vow?: unknown;
	vowKept?: unknown;
	before?: unknown;
	after?: unknown;
	reward?: unknown;
	stardust?: unknown;
}

interface AntilagLike {
	tier?: unknown;
	particleBudget?: number;
	glowScale?: number;
	allowConfetti?: boolean;
}

function RebirthCeremonyHostImpl(props: { reducedMotion?: boolean }) {
	const antilag = ((useAntilag() as unknown) ?? {}) as AntilagLike;
	const [session, setSession] = React.useState<{ id: number; payload: CeremonyPayload } | undefined>(undefined);
	const [clock, setClock] = React.useBinding(0);
	// the 450px card shrinks to fit narrow phones; 1 (unchanged) anywhere it already fits
	const ceremonyViewport = useViewport();
	const cardScale = math.clamp((ceremonyViewport.width - 24) / 450, 0.6, 1);
	const jobsRef = React.useRef<thread[]>([]);
	const skipRef = React.useRef(0);
	const cancelJobs = () => {
		for (const job of jobsRef.current) {
			pcall(task.cancel, job);
		}
		jobsRef.current = [];
	};
	React.useEffect(() => {
		const unsubscribe = subscribe((payload) => {
			setSession({ id: os.clock(), payload: (typeIs(payload, "table") ? payload : {}) as CeremonyPayload });
		});
		return () => {
			unsubscribe();
			cancelJobs();
		};
	}, []);
	const reduced = props.reducedMotion === true || isReducedMotion();
	// nothing in the shell reacts to the pad while the ceremony plays
	usePadSink(session !== undefined, "AstralForgeRebirthCeremonySink", SHELL_PAD_KEYS);
	const plan = resolveIntent({
		role: "ceremony",
		emphasis: 1,
		reduced: reduced,
		tier: antilag.tier,
		particleBudget: antilag.particleBudget,
		glowScale: antilag.glowScale,
		allowConfetti: antilag.allowConfetti,
	});
	const calm = plan.reduced;
	// every fifth rebirth is a milestone: the hold before the count runs longer and it lands in gold
	const milestoneCount = session !== undefined ? math.floor(tonumber(session.payload.rebirths) ?? 1) : 1;
	const milestone = milestoneCount % 5 === 0;
	const tl = calm ? CALM : milestone ? MILESTONE : FULL;
	React.useEffect(() => {
		if (session === undefined) {
			return undefined;
		}
		cancelJobs();
		skipRef.current = 0;
		setClock(0);
		const at = (seconds: number, fn: () => void) => {
			jobsRef.current.push(task.delay(seconds, fn));
		};
		if (calm) {
			Audio.play("rebirthTierUp");
		} else {
			Audio.play("rebirthIgnite");
			at(tl.shock, () => {
				Audio.play("rebirthShockwave");
				InteractionFeedback.reward();
				if (celebrationsAllowed()) {
					const camera = game.GetService("Workspace").CurrentCamera;
					const centre = camera ? camera.ViewportSize.div(2) : undefined;
					Juice.burst(centre, milestone ? Palette.mango : Palette.violet, milestone ? 1.7 : 1.2);
					Juice.shockwave(centre, milestone ? Palette.mango : Palette.mint, milestone ? 1.2 : 0.9);
				}
			});
			// the multiplier lands with a second beat once the count finishes
			at(tl.count1, () => {
				InteractionFeedback.confirm();
				if (celebrationsAllowed()) {
					Juice.burst(undefined, Palette.mint, 0.7);
				}
			});
			at(tl.count0 + 0.04, () => Audio.play("rebirthTierUp"));
			const ticks = 7;
			for (let i = 1; i <= ticks; i++) {
				at(tl.count0 + ((tl.count1 - tl.count0) * i) / (ticks + 1), () => Audio.play("countTick", 0.92 + i * 0.05));
			}
			at(tl.ascend, () => Audio.play("rebirthAscend"));
		}
		const started = os.clock();
		let done = false;
		const connection = RunService.RenderStepped.Connect(() => {
			if (done) {
				return;
			}
			const t = os.clock() - started + skipRef.current;
			setClock(t);
			if (t >= tl.finish) {
				done = true;
				connection.Disconnect();
				setSession(undefined);
			}
		});
		return () => {
			done = true;
			connection.Disconnect();
			cancelJobs();
		};
	}, [session]);
	if (session === undefined) {
		return undefined;
	}
	const payload = session.payload;
	const newCount = math.max(1, math.floor(tonumber(payload.rebirths) ?? 1));
	// the run's grade, and the vow if one was sworn, head the card
	let heading = `REBIRTH ${newCount}`;
	if (typeIs(payload.grade, "string")) {
		heading += `  ·  GRADE ${payload.grade}`;
	}
	if (typeIs(payload.vow, "string") && payload.vow !== "") {
		heading += payload.vowKept !== undefined && payload.vowKept !== false
			? `  ·  ${string.upper(payload.vow)} KEPT`
			: `  ·  ${string.upper(payload.vow)} BROKEN`;
	}
	const oldCount = newCount - 1;
	const noFlash = !flashesAllowed();
	const before = payload.before !== undefined ? payload.before : 1;
	const after = payload.after !== undefined ? payload.after : before;
	const particles = plan.particles as number;
	const moteCount = calm ? 0 : math.clamp(particles * 2, 8, 26);
	const streakCount = calm ? 0 : math.clamp(particles, 5, 16);
	const shakeAmp = calm ? 0 : math.clamp((plan.shake as number) * 2, 3, 12);
	const fadeOut = (t: number) => ramp(t, tl.fade, tl.finish);
	const contentIn = (t: number) => outCubic(ramp(t, tl.count0 - 0.18, tl.count0 + 0.16));
	const skip = () => {
		const t = clock.getValue();
		if (t < tl.fade) {
			skipRef.current += tl.fade - t;
			cancelJobs();
		}
	};
	const rewardLine: string[] = [];
	if (payload.reward !== undefined) {
		rewardLine.push("+" + compactNumber(payload.reward) + " cores");
	}
	if (payload.stardust !== undefined) {
		rewardLine.push("+" + compactNumber(payload.stardust) + " Stardust");
	}
	const shown = (t: number) => 1 - contentIn(t) * (1 - fadeOut(t));
	return h(
		"frame",
		{ Name: "RebirthCeremony", Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 500 },
		h(
			"frame",
			{
				Name: "Veil",
				Size: UDim2.fromScale(1, 1),
				BackgroundColor3: Palette.void,
				BorderSizePixel: 0,
				BackgroundTransparency: clock.map((t) => 1 - 0.78 * ramp(t, 0, 0.28) * (1 - fadeOut(t))),
			},
			h("uigradient", {
				Transparency: new NumberSequence([
					new NumberSequenceKeypoint(0, 0),
					new NumberSequenceKeypoint(0.5, 0.22),
					new NumberSequenceKeypoint(1, 0),
				]),
				Rotation: 90,
			}),
		),
		h(
			"frame",
			{
				Name: "Stage",
				Size: UDim2.fromScale(1, 1),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				Position: clock.map((t) => {
					if (shakeAmp <= 0 || t < tl.shock) {
						return new UDim2();
					}
					const decay = 1 - ramp(t, tl.shock, tl.shock + 0.42);
					return UDim2.fromOffset(math.sin(t * 83) * shakeAmp * decay, math.cos(t * 67) * shakeAmp * 0.7 * decay);
				}),
			},
			moteCount > 0 && h(Motes, { clock: clock, tl: tl, count: moteCount }),
			!calm &&
				h(
					"frame",
					{
						Name: "Core",
						AnchorPoint: new Vector2(0.5, 0.5),
						Position: UDim2.fromScale(0.5, 0.5),
						BackgroundColor3: Palette.cream,
						BorderSizePixel: 0,
						Size: clock.map((t) => {
							const grow = outCubic(ramp(t, 0.05, tl.shock)) * 32;
							const pop = math.sin(math.pi * ramp(t, tl.shock, tl.shock + 0.3)) * 52;
							const gone = 1 - ramp(t, tl.shock + 0.15, tl.shock + 0.4);
							const s = (grow + pop) * gone;
							return UDim2.fromOffset(s, s);
						}),
					},
					corner(),
					h("uistroke", { Color: Palette.violet, Thickness: 3, Transparency: 0.25 }),
				),
			!calm &&
				h(
					"frame",
					{
						Name: "ShockwaveBeam",
						AnchorPoint: new Vector2(0.5, 0.5),
						Position: UDim2.fromScale(0.5, 0.5),
						Size: clock.map((t) => {
							const p = ramp(t, tl.shock, tl.shock + 0.36);
							return new UDim2(outCubic(p) * 1.8, 0, 0, math.floor(10 * (1 - p)));
						}),
						BackgroundColor3: Palette.cream,
						BorderSizePixel: 0,
						BackgroundTransparency: clock.map((t) => {
							if (t < tl.shock) {
								return 1;
							}
							return 0.12 + 0.88 * ramp(t, tl.shock + 0.04, tl.shock + 0.36);
						}),
					},
					corner(),
					h("uigradient", {
						Color: new ColorSequence([
							new ColorSequenceKeypoint(0, Palette.violet),
							new ColorSequenceKeypoint(0.5, Palette.cream),
							new ColorSequenceKeypoint(1, Palette.violet),
						]),
						Transparency: new NumberSequence([
							new NumberSequenceKeypoint(0, 1),
							new NumberSequenceKeypoint(0.5, 0),
							new NumberSequenceKeypoint(1, 1),
						]),
					}),
				),
			!calm && h(Rings, { clock: clock, tl: tl }),
			streakCount > 0 && h(Streaks, { clock: clock, tl: tl, count: streakCount }),
			h(
				"frame",
				{
					Name: "Card",
					AnchorPoint: new Vector2(0.5, 0.5),
					Size: UDim2.fromOffset(450, 276),
					BackgroundColor3: Color3.fromRGB(12, 14, 22),
					BackgroundTransparency: clock.map((t) => 1 - 0.94 * contentIn(t) * (1 - fadeOut(t))),
					BorderSizePixel: 0,
					Position: clock.map((t) => {
						const rise = outCubic(ramp(t, tl.ascend, tl.fade)) * 22 + fadeOut(t) * 18;
						return new UDim2(0.5, 0, 0.5, (1 - contentIn(t)) * 18 - rise);
					}),
				},
				corner(new UDim(0, 16)),
				cardScale < 1 && h("uiscale", { Scale: cardScale }),
				h("uistroke", { Color: Palette.violet, Thickness: 1.5, Transparency: clock.map((t) => 0.2 + 0.8 * fadeOut(t)) }),
				h(
					"frame",
					{
						Name: "TopJewelLine",
						AnchorPoint: new Vector2(0.5, 0),
						Position: new UDim2(0.5, 0, 0, 0),
						Size: new UDim2(0.38, 0, 0, 2),
						BackgroundColor3: Palette.violet,
						BorderSizePixel: 0,
						BackgroundTransparency: clock.map(shown),
					},
					corner(new UDim(1, 0)),
				),
				h("uiscale", { Scale: clock.map((t) => 0.92 + 0.08 * outBack(ramp(t, tl.count0 - 0.18, tl.count0 + 0.3))) }),
				h("textlabel", {
					Position: UDim2.fromOffset(0, 12),
					Size: new UDim2(1, 0, 0, 20),
					BackgroundTransparency: 1,
					FontFace: HEAVY,
					Text: heading,
					TextSize: 12,
					TextColor3: Palette.violet,
					TextTransparency: clock.map(shown),
				}),
				h(
					"frame",
					{
						Name: "Count",
						Position: UDim2.fromOffset(0, 34),
						Size: new UDim2(1, 0, 0, 86),
						BackgroundTransparency: 1,
						ClipsDescendants: true,
					},
					h("textlabel", {
						Size: UDim2.fromScale(1, 1),
						BackgroundTransparency: 1,
						FontFace: HEAVY,
						Text: tostring(oldCount),
						TextSize: 84,
						TextColor3: Palette.muted,
						Position: clock.map((t) => UDim2.fromScale(0, -outCubic(ramp(t, tl.count0, tl.count0 + 0.3)))),
						TextTransparency: clock.map((t) => 1 - contentIn(t) * (1 - ramp(t, tl.count0, tl.count0 + 0.24))),
					}),
					h(
						"textlabel",
						{
							Size: UDim2.fromScale(1, 1),
							BackgroundTransparency: 1,
							FontFace: HEAVY,
							Text: tostring(newCount),
							TextSize: 84,
							TextColor3: Palette.cream,
							Position: clock.map((t) => UDim2.fromScale(0, 1 - outBack(ramp(t, tl.count0 + 0.06, tl.count0 + 0.42)))),
							TextTransparency: clock.map((t) => fadeOut(t)),
						},
						h("uistroke", {
							Color: Palette.violet,
							Thickness: 2,
							Transparency: clock.map((t) => 0.35 + 0.65 * fadeOut(t)),
						}),
					),
				),
				h("textlabel", {
					Position: UDim2.fromOffset(0, 122),
					Size: new UDim2(1, 0, 0, 18),
					BackgroundTransparency: 1,
					FontFace: BOLD,
					Text: milestone ? `Milestone · ${newCount} rebirths` : `${newCount} rebirths so far`,
					TextSize: 12,
					TextColor3: milestone ? Palette.mango : Palette.mint,
					TextTransparency: clock.map(shown),
				}),
				h(
					"frame",
					{
						Name: "MultiplierPlate",
						Position: UDim2.fromOffset(24, 144),
						Size: new UDim2(1, -48, 0, 52),
						BackgroundColor3: Color3.fromRGB(18, 20, 32),
						BackgroundTransparency: clock.map((t) => 1 - 0.75 * contentIn(t) * (1 - fadeOut(t))),
						BorderSizePixel: 0,
					},
					corner(new UDim(0, 10)),
					h("uistroke", { Color: Palette.line, Thickness: 1, Transparency: clock.map((t) => 0.4 + 0.6 * fadeOut(t)) }),
					h("textlabel", {
						Position: UDim2.fromOffset(0, 6),
						Size: new UDim2(1, 0, 0, 12),
						BackgroundTransparency: 1,
						FontFace: BOLD,
						Text: "PRODUCTION MULTIPLIER, KEPT FOR GOOD",
						TextSize: 9,
						TextColor3: Palette.muted,
						TextTransparency: clock.map(shown),
					}),
					h("textlabel", {
						Position: UDim2.fromOffset(0, 18),
						Size: new UDim2(1, 0, 0, 30),
						BackgroundTransparency: 1,
						FontFace: HEAVY,
						TextSize: 24,
						TextColor3: milestone ? Palette.mango : Palette.mint,
						Text: clock.map((t) => {
							const k = outCubic(ramp(t, tl.count0, tl.count1));
							return `${multiplierText(before)}   →   ${multiplierText(blendMultiplier(before, after, k))}`;
						}),
						TextTransparency: clock.map(shown),
					}),
				),
				h("textlabel", {
					Position: UDim2.fromOffset(0, 204),
					Size: new UDim2(1, 0, 0, 22),
					BackgroundTransparency: 1,
					FontFace: BOLD,
					TextSize: 15,
					TextColor3: Palette.creamSoft,
					Text: rewardLine.size() > 0 ? rewardLine.join("    ·    ") : "Permanent production raised",
					TextTransparency: clock.map((t) => 1 - ramp(t, tl.count1 - 0.2, tl.count1 + 0.1) * (1 - fadeOut(t))),
				}),
			),
		),
		h("frame", {
			Name: "Flash",
			Size: UDim2.fromScale(1, 1),
			BackgroundColor3: Palette.white,
			BorderSizePixel: 0,
			BackgroundTransparency: clock.map((t) => {
				if (calm || noFlash || t < tl.shock) {
					return 1;
				}
				return 0.5 + 0.5 * outCubic(ramp(t, tl.shock, tl.shock + 0.3));
			}),
		}),
		h("textlabel", {
			AnchorPoint: new Vector2(0.5, 1),
			Position: new UDim2(0.5, 0, 1, -28),
			Size: UDim2.fromOffset(240, 18),
			BackgroundTransparency: 1,
			FontFace: BOLD,
			TextSize: 13,
			TextColor3: Palette.muted,
			Text: "tap to skip",
			TextTransparency: clock.map((t) => 1 - 0.75 * ramp(t, 0.6, 1) * (1 - ramp(t, tl.fade - 0.2, tl.fade))),
		}),
		h("textbutton", {
			Name: "Skip",
			Size: UDim2.fromScale(1, 1),
			BackgroundTransparency: 1,
			Text: "",
			AutoButtonColor: false,
			Selectable: false,
			Event: { Activated: skip },
		}),
	);
}
// driven by its own subscription; the shell's state pushes never change its one prop
export const RebirthCeremonyHost = React.memo(RebirthCeremonyHostImpl);

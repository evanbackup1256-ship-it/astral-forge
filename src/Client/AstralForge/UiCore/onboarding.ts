import React from "@rbxts/react";
import { ModalSelectionScope } from "./overlayCore";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { Palette, Space, TapTarget } from "../CoreKit/theme";

import {
	MotionSettingsContext,
	revealOffset,
	usePresence,
	useStagger,
	useViewport,
} from "../MotionKit/motion";
import {
	AutoHeightText,
	Badge,
	Button,
	measureWrappedTextHeight,
	Meter,
	OverlayPresence,
	Panel,
	Text,
	useGamepadAutofocus,
} from "./ui";

// breathing room between release cards (uirevamp spacing)
const CARD_GAP = Space.md;

const h = React.createElement as unknown as (component: unknown, props?: object, ...children: unknown[]) => React.Element;

const ContextActionService = game.GetService("ContextActionService");
const UserInputService = game.GetService("UserInputService");
const GuiService = game.GetService("GuiService");
const Players = game.GetService("Players");
const RunService = game.GetService("RunService");

const AstralForge = script.Parent!.Parent!;
const loadKit = (name: string) => require(AstralForge.WaitForChild(name) as ModuleScript) as (member: string) => unknown;

interface AudioApi {
	play(name: string): void;
}
const Audio = (loadKit("AudioKit")("audio") as { Audio: AudioApi }).Audio;
const Icon = (loadKit("ArtKit")("Icon") as { Icon: unknown }).Icon;

type Rect = { x: number; y: number; w: number; h: number };
type Spot = Rect & { a: number };

interface TutorialCopy {
	watch?: string;
	target?: string | string[];
	auto?: boolean;
	task?: string;
	title: string;
	line: string;
	controls?: string;
}

interface TutorialScriptModule {
	goalMet(this: void, copy: TutorialCopy, live: object, collected: boolean): boolean;
	needsAction(this: void, copy: TutorialCopy): boolean;
	calloutPlacement(
		this: void,
		lit: Spot | undefined,
		screenW: number,
		screenH: number,
		cardW: number,
		cardH: number,
		top: number,
		bottom: number,
	): LuaTuple<[number, number, unknown]>;
	leader(
		this: void,
		lit: Spot | undefined,
		side: unknown,
		x: number,
		y: number,
		cardW: number,
		cardH: number,
	): LuaTuple<[number | undefined, number, number, number]>;
}

const SharedDataSuite = require(
	game.GetService("ReplicatedStorage").WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("SharedData") as ModuleScript,
) as (name: string) => unknown;
const TutorialScript = SharedDataSuite("TutorialScript") as TutorialScriptModule;

interface JuiceFxModule {
	burst(this: void, position: Vector2, color: Color3, scale: number): void;
}

const CARD_W = 360;
const AUTO_ADVANCE_SECONDS = 0.9;
const MISSING_NOTE_AFTER = 2.5;
const WHITE_HOT = Color3.fromRGB(255, 244, 222);
function approach(current: number, goal: number, rate: number, dt: number) {
	return current + (goal - current) * (1 - math.exp(-rate * dt));
}
function easeOut(t: number) {
	const u = 1 - math.clamp(t, 0, 1);
	return 1 - u * u * u;
}

interface GuideFrame {
	spot: Spot;
	card: { x: number; y: number };
	leader?: { x1: number; y1: number; x2: number; y2: number };
	missing: boolean;
	t: number;
	stepAge?: number;
	stampAge?: number;
}

function blankFrame(width: number, height: number): GuideFrame {
	return {
		spot: { x: 0, y: 0, w: 0, h: 0, a: 0 },
		card: { x: (width - CARD_W) / 2, y: height - 240 },
		leader: undefined,
		missing: false,
		t: 0,
	};
}

function shown(instance: Instance | undefined): instance is GuiObject {
	if (instance === undefined || instance.Parent === undefined || !instance.IsA("GuiObject")) {
		return false;
	}
	if (instance.AbsoluteSize.X < 4 || instance.AbsoluteSize.Y < 4) {
		return false;
	}
	let node: Instance | undefined = instance;
	while (node !== undefined) {
		if (node.IsA("GuiObject") && !node.Visible) {
			return false;
		}
		if (node.IsA("LayerCollector")) {
			return node.Enabled;
		}
		node = node.Parent;
	}
	return false;
}
function findTarget(name: string | string[] | undefined): GuiObject | undefined {
	if (typeIs(name, "table")) {
		for (const candidate of name as string[]) {
			const found = findTarget(candidate);
			if (found !== undefined) {
				return found;
			}
		}
		return undefined;
	}
	if (name === undefined) {
		return undefined;
	}
	const playerGui = Players.LocalPlayer && Players.LocalPlayer.FindFirstChildOfClass("PlayerGui");
	if (playerGui === undefined) {
		return undefined;
	}
	const quick = playerGui.FindFirstChild(name, true);
	if (shown(quick)) {
		return quick;
	}
	for (const candidate of playerGui.GetDescendants()) {
		if (candidate.Name === name && shown(candidate)) {
			return candidate;
		}
	}
	return undefined;
}

// the task box's check, stamped in when the player does the thing
function StampedCheck(props: { scale: React.Binding<number> }) {
	return h(
		"frame",
		{
			Size: UDim2.fromOffset(20, 20),
			Position: UDim2.fromScale(0.5, 0.5),
			AnchorPoint: new Vector2(0.5, 0.5),
			BackgroundTransparency: 1,
			ZIndex: 406,
		},
		h("uiscale", { Scale: props.scale }),
		h(Icon, { kind: "Check.29", color: Palette.ink, size: 20, spin: false }),
	);
}

interface TutorialOverlayProps {
	copy: TutorialCopy;
	step: number;
	count: number;
	reducedMotion?: boolean;
	ctaLabel?: string;
	onCta?: () => void;
	onNext: () => void;
	onBack: () => void;
	onSkip: () => void;
	live?: unknown;
}

interface GuideState {
	spot: Spot;
	card?: { x: number; y: number };
	target?: GuiObject;
	targetName?: string | string[];
	lastSearch: number;
	missingSince: number;
	stepAt: number;
	stampAt: number;
	t: number;
}

interface ControlState {
	step: number;
	exiting: boolean;
	met: boolean;
	needsAction: boolean;
	onBack: () => void;
	onCta?: () => void;
	requestNext: () => void;
}

export function TutorialOverlay(param: TutorialOverlayProps) {
	const copy = param.copy;
	const step = param.step;
	const count = param.count;
	const reducedMotion = param.reducedMotion;
	const ctaLabel = param.ctaLabel;
	const onCta = param.onCta;
	const onNext = param.onNext;
	const onBack = param.onBack;
	const onSkip = param.onSkip;
	const viewport = useViewport();
	const soft = React.useContext(MotionSettingsContext).soft === true;
	const live = (typeIs(param.live, "table") ? param.live : {}) as { vaultFlux?: unknown };

	const vaultNow = typeIs(live.vaultFlux, "number") ? live.vaultFlux : 0;
	const [collected, setCollected] = React.useState(false);
	const vaultMark = React.useRef(vaultNow);
	React.useEffect(() => {
		setCollected(false);
		vaultMark.current = vaultNow;
	}, [step]);
	React.useEffect(() => {
		if (copy.watch === "collect" && vaultNow < vaultMark.current - 0.5) {
			setCollected(true);
		}
	}, [step, vaultNow]);
	const met = TutorialScript.goalMet(copy, live, collected);
	const needsAction = TutorialScript.needsAction(copy);

	const [reveal, exiting, beginExit] = usePresence(reducedMotion);
	const requestNext = React.useCallback(() => {
		if (exiting) {
			return undefined;
		}
		if (step >= count) {
			beginExit(onNext);
		} else {
			onNext();
		}
	}, [beginExit, count, exiting, onNext, step]);
	const requestSkip = React.useCallback(() => {
		if (!exiting) {
			beginExit(onSkip);
		}
	}, [beginExit, exiting, onSkip]);

	React.useEffect(() => {
		Audio.play(step === 1 ? "modalOpen" : "tutorialStep");
	}, [step]);
	React.useEffect(() => {
		if (!(met && needsAction && copy.auto)) {
			return undefined;
		}
		const job = task.delay(AUTO_ADVANCE_SECONDS, () => {
			requestNext();
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [met, needsAction, step, requestNext]);

	const stateRef = React.useRef<ControlState>({} as ControlState);
	stateRef.current = { step, exiting, met, needsAction, onBack, onCta, requestNext };
	React.useEffect(() => {
		ContextActionService.BindActionAtPriority(
			"AstralForgeTutorialBack",
			(_name, inputState) => {
				const current = stateRef.current;
				if (inputState === Enum.UserInputState.Begin && current.step > 1 && !current.exiting) {
					current.onBack();
				}
				return Enum.ContextActionResult.Sink;
			},
			false,
			2300,
			Enum.KeyCode.ButtonB,
		);
		ContextActionService.BindActionAtPriority(
			"AstralForgeTutorialConfirm",
			(_name, inputState) => {
				const current = stateRef.current;
				if (!current.exiting && current.needsAction && !current.met && current.onCta === undefined) {
					return Enum.ContextActionResult.Pass;
				}
				if (inputState === Enum.UserInputState.Begin && !current.exiting) {
					if (current.needsAction && !current.met && current.onCta !== undefined) {
						current.onCta();
					} else if (current.met) {
						current.requestNext();
					}
				}
				return Enum.ContextActionResult.Sink;
			},
			false,
			2300,
			Enum.KeyCode.ButtonA,
		);
		GamepadNavigationService.BeginOverlayFocus();
		return () => {
			ContextActionService.UnbindAction("AstralForgeTutorialBack");
			ContextActionService.UnbindAction("AstralForgeTutorialConfirm");
			GamepadNavigationService.EndOverlayFocus();
		};
	}, []);

	const phone = viewport.width < 720 || viewport.height < 560;
	const cardW = math.min(CARD_W, viewport.width - 24);
	const innerW = cardW - 32;
	const hasCta = ctaLabel !== undefined && onCta !== undefined && needsAction && !met;
	const layoutRef = React.useRef({ cardW: 0, top: 0, bottom: 0 });
	layoutRef.current = { cardW, top: viewport.topInset, bottom: viewport.bottomInset };

	const rootRef = React.useRef<Frame>();
	const probeRef = React.useRef<Frame>();
	const dockRef = React.useRef<Frame>();
	const [frame, setFrame] = React.useBinding(blankFrame(viewport.width, viewport.height));
	const guide = React.useRef<GuideState>();
	if (guide.current === undefined) {
		guide.current = {
			spot: { x: 0, y: 0, w: 0, h: 0, a: 0 },
			card: undefined,
			target: undefined,
			targetName: undefined,
			lastSearch: 0,
			missingSince: 0,
			stepAt: 0,
			stampAt: -10,
			t: 0,
		};
	}
	React.useEffect(() => {
		let redirecting = false;
		const constrainSelection = () => {
			if (redirecting || !UserInputService.GamepadEnabled) {
				return;
			}
			const selected = GuiService.SelectedObject;
			const root = rootRef.current;
			const target = guide.current!.target;
			if (
				selected === undefined ||
				(root && selected.IsDescendantOf(root)) ||
				(target && (selected === target || selected.IsDescendantOf(target)))
			) {
				return;
			}
			redirecting = true;
			let assigned = target !== undefined && GamepadNavigationService.AssignSelection(target);
			for (const scope of [target, dockRef.current]) {
				if (scope && !assigned) {
					for (const candidate of scope.GetDescendants()) {
						if (candidate.IsA("GuiButton") && GamepadNavigationService.AssignSelection(candidate)) {
							assigned = true;
							break;
						}
					}
				}
			}
			if (!assigned) {
				GamepadNavigationService.ClearSelection();
			}
			redirecting = false;
		};
		const connection = GuiService.GetPropertyChangedSignal("SelectedObject").Connect(constrainSelection);
		constrainSelection();
		return () => connection.Disconnect();
	}, []);
	React.useEffect(() => {
		guide.current!.stepAt = guide.current!.t;
	}, [step]);
	// doing the thing: the check stamps in and the target throws a burst
	React.useEffect(() => {
		if (!(met && needsAction)) {
			return undefined;
		}
		const g = guide.current!;
		g.stampAt = g.t;
		Audio.play("successChime");
		const target = g.target;
		if (target !== undefined && shown(target) && !reducedMotion) {
			pcall(() => {
				const Juice = require(AstralForge.WaitForChild("JuiceFx") as ModuleScript) as JuiceFxModule;
				Juice.burst(target.AbsolutePosition.add(target.AbsoluteSize.div(2)), Palette.mango, 1.1);
			});
		}
		return undefined;
	}, [met, needsAction, step]);

	React.useEffect(() => {
		const rectBuf: Rect = { x: 0, y: 0, w: 0, h: 0 };
		const connection = RunService.RenderStepped.Connect((rawDt) => {
			const dt = math.min(rawDt, 1 / 20);
			const g = guide.current!;
			const root = rootRef.current;
			const probe = probeRef.current;
			if (root === undefined || probe === undefined) {
				return;
			}
			g.t += dt;
			const t = g.t;
			const k = math.max(0.01, probe.AbsoluteSize.X / 100);
			const origin = root.AbsolutePosition;
			const screenW = root.AbsoluteSize.X / k;
			const screenH = root.AbsoluteSize.Y / k;
			const layout = layoutRef.current;

			if (g.targetName !== copy.target) {
				g.targetName = copy.target;
				g.target = undefined;
				g.lastSearch = 0;
			}
			if ((g.target === undefined || !shown(g.target)) && t - g.lastSearch > 0.25) {
				g.lastSearch = t;
				g.target = findTarget(copy.target);
			}
			let rect: Rect | undefined = undefined;
			if (g.target !== undefined && shown(g.target)) {
				const pad = 6;
				const p = g.target.AbsolutePosition.sub(origin).div(k);
				const s = g.target.AbsoluteSize.div(k);
				rectBuf.x = p.X - pad;
				rectBuf.y = p.Y - pad;
				rectBuf.w = s.X + pad * 2;
				rectBuf.h = s.Y + pad * 2;
				rect = rectBuf;
			}
			if (copy.target !== undefined && rect === undefined) {
				if (g.missingSince <= 0) {
					g.missingSince = t;
				}
			} else {
				g.missingSince = 0;
			}
			const spot = g.spot;
			const ease = 1 - math.exp(-dt * 11);
			if (rect !== undefined) {
				if (spot.a < 0.02) {
					spot.x = rect.x - 40;
					spot.y = rect.y - 40;
					spot.w = rect.w + 80;
					spot.h = rect.h + 80;
				}
				spot.x += (rect.x - spot.x) * ease;
				spot.y += (rect.y - spot.y) * ease;
				spot.w += (rect.w - spot.w) * ease;
				spot.h += (rect.h - spot.h) * ease;
				spot.a += (1 - spot.a) * ease;
			} else {
				spot.a += (0 - spot.a) * ease;
			}
			const lit = spot.a > 0.3 ? spot : undefined;

			const dock = dockRef.current;
			const cardH = dock !== undefined && dock.AbsoluteSize.Y > 1 ? dock.AbsoluteSize.Y / k : 220;
			const [goalX, goalY, side] = TutorialScript.calloutPlacement(
				lit,
				screenW,
				screenH,
				layout.cardW,
				cardH,
				layout.top / k,
				layout.bottom / k,
			);
			if (g.card === undefined) {
				g.card = { x: goalX, y: goalY };
			}
			g.card.x = approach(g.card.x, goalX, 12, dt);
			g.card.y = approach(g.card.y, goalY, 12, dt);
			const [x1, y1, x2, y2] = TutorialScript.leader(lit, side, g.card.x, g.card.y, layout.cardW, cardH);
			setFrame({
				spot: { x: spot.x, y: spot.y, w: spot.w, h: spot.h, a: spot.a },
				card: { x: g.card.x, y: g.card.y },
				leader: x1 !== undefined ? { x1, y1, x2, y2 } : undefined,
				missing: g.missingSince > 0 && t - g.missingSince > MISSING_NOTE_AFTER,
				t: t,
				stepAge: t - g.stepAt,
				stampAge: t - g.stampAt,
			});
		});
		return () => connection.Disconnect();
	}, [copy]);

	// the dim around the target (blocks taps outside it, never takes gamepad focus)
	const dim = (key: string, sizeFn: (f: GuideFrame) => UDim2, posFn: (f: GuideFrame) => UDim2) =>
		h("textbutton", {
			key: key,
			Text: "",
			AutoButtonColor: false,
			Selectable: false,
			Size: frame.map(sizeFn),
			Position: frame.map(posFn),
			BackgroundColor3: Palette.void,
			BackgroundTransparency: reveal.map((amount) => 1 - math.clamp(amount, 0, 1) * 0.74),
			BorderSizePixel: 0,
			Active: true,
			ZIndex: 380,
		});
	// registration marks on the target's corners, breathing in and out
	const corners: Record<string, unknown> = {};
	for (const [index, corner] of ipairs([
		[0, 0],
		[1, 0],
		[0, 1],
		[1, 1],
	])) {
		const [cx, cy] = [corner[0], corner[1]];
		const at = (f: GuideFrame): [number, number] => {
			const breathe = 5 + math.sin(f.t * 3.4) * 2;
			const x = f.spot.x + cx * f.spot.w + (cx === 0 ? -breathe : breathe);
			const y = f.spot.y + cy * f.spot.h + (cy === 0 ? -breathe : breathe);
			return [x, y];
		};
		for (let arm = 1; arm <= 2; arm++) {
			const horizontal = arm === 1;
			corners[`c${index}${arm}`] = h("frame", {
				Size: UDim2.fromOffset(horizontal ? 16 : 3, horizontal ? 3 : 16),
				Position: frame.map((f) => {
					const [x, y] = at(f);
					return UDim2.fromOffset(x, y);
				}),
				AnchorPoint: new Vector2(horizontal ? cx : cx === 0 ? 0 : 1, horizontal ? (cy === 0 ? 0 : 1) : cy),
				BackgroundColor3: WHITE_HOT,
				BackgroundTransparency: frame.map((f) => 1 - math.clamp(f.spot.a, 0, 1)),
				BorderSizePixel: 0,
				ZIndex: 383,
			});
		}
	}
	const spotlight = h(
		React.Fragment,
		undefined,
		dim(
			"top",
			(f) => new UDim2(1, 0, 0, math.max(0, f.spot.y)),
			() => UDim2.fromScale(0, 0),
		),
		dim(
			"bottom",
			(f) => new UDim2(1, 0, 1, -math.max(0, f.spot.y + f.spot.h)),
			(f) => UDim2.fromOffset(0, f.spot.y + f.spot.h),
		),
		dim(
			"left",
			(f) => UDim2.fromOffset(math.max(0, f.spot.x), math.max(0, f.spot.h)),
			(f) => UDim2.fromOffset(0, f.spot.y),
		),
		dim(
			"right",
			(f) => new UDim2(1, -math.max(0, f.spot.x + f.spot.w), 0, math.max(0, f.spot.h)),
			(f) => UDim2.fromOffset(f.spot.x + f.spot.w, f.spot.y),
		),
		h(
			"frame",
			{
				// a fuse of heat running round the outline
				key: "fuse",
				Size: frame.map((f) => UDim2.fromOffset(f.spot.w, f.spot.h)),
				Position: frame.map((f) => UDim2.fromOffset(f.spot.x, f.spot.y)),
				BackgroundTransparency: 1,
				Active: false,
				Visible: frame.map((f) => f.spot.a > 0.05),
				ZIndex: 381,
			},
			h("uicorner", { CornerRadius: new UDim(0, 8) }),
			h(
				"uistroke",
				{
					Color: Palette.white,
					Thickness: 2,
					Transparency: frame.map((f) => 1 - math.clamp(f.spot.a, 0, 1)),
				},
				h("uigradient", {
					Color: new ColorSequence([
						new ColorSequenceKeypoint(0, Palette.ember),
						new ColorSequenceKeypoint(0.44, Palette.mango),
						new ColorSequenceKeypoint(0.5, WHITE_HOT),
						new ColorSequenceKeypoint(0.56, Palette.mango),
						new ColorSequenceKeypoint(1, Palette.ember),
					]),
					Rotation: frame.map((f) => (f.t * (reducedMotion || soft ? 60 : 150)) % 360),
				}),
			),
		),
		h(React.Fragment, undefined, corners),
	);

	// the leader line from the card to the target, with a beat travelling along it
	const leaderValue = <T>(
		f: GuideFrame,
		fallback: T,
		fn: (l: NonNullable<GuideFrame["leader"]>, dx: number, dy: number) => T,
	): T => {
		const l = f.leader;
		if (l === undefined) {
			return fallback;
		}
		return fn(l, l.x2 - l.x1, l.y2 - l.y1);
	};
	const leader = h(
		React.Fragment,
		undefined,
		h("frame", {
			key: "line",
			Size: frame.map((f) => leaderValue(f, new UDim2(), (_, dx, dy) => UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), 2))),
			Position: frame.map((f) => leaderValue(f, new UDim2(), (l) => UDim2.fromOffset((l.x1 + l.x2) / 2, (l.y1 + l.y2) / 2))),
			Rotation: frame.map((f) => leaderValue(f, 0, (_, dx, dy) => math.deg(math.atan2(dy, dx)))),
			AnchorPoint: new Vector2(0.5, 0.5),
			BackgroundColor3: Palette.mango,
			BackgroundTransparency: React.joinBindings([frame, reveal] as React.Binding<unknown>[]).map((values) => {
				const f = values[0] as GuideFrame;
				return f.leader === undefined ? 1 : 1 - math.clamp(f.spot.a, 0, 1) * math.clamp(values[1] as number, 0, 1) * 0.85;
			}),
			BorderSizePixel: 0,
			ZIndex: 384,
		}),
		h(
			"frame",
			{
				key: "beat",
				Size: UDim2.fromOffset(6, 6),
				Position: frame.map((f) =>
					leaderValue(f, UDim2.fromOffset(-20, -20), (l) => {
						const p = (f.t * 0.9) % 1;
						return UDim2.fromOffset(l.x1 + (l.x2 - l.x1) * p, l.y1 + (l.y2 - l.y1) * p);
					}),
				),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundColor3: WHITE_HOT,
				BackgroundTransparency: frame.map((f) => (f.leader === undefined || reducedMotion ? 1 : 1 - math.clamp(f.spot.a, 0, 1))),
				BorderSizePixel: 0,
				ZIndex: 385,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
		),
		h(
			"frame",
			{
				key: "pin",
				Size: frame.map((f) => {
					const d = 9 + math.sin(f.t * 5) * 2;
					return UDim2.fromOffset(d, d);
				}),
				Position: frame.map((f) => leaderValue(f, UDim2.fromOffset(-20, -20), (l) => UDim2.fromOffset(l.x2, l.y2))),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundColor3: WHITE_HOT,
				BackgroundTransparency: frame.map((f) => (f.leader === undefined ? 1 : 1 - math.clamp(f.spot.a, 0, 1))),
				BorderSizePixel: 0,
				ZIndex: 385,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uistroke", { Color: Palette.mango, Thickness: 2 }),
		),
	);

	// the card
	const segments: Record<string, unknown> = {};
	for (let n = 1; n <= count; n++) {
		segments["s" + n] = h(
			"frame",
			{
				Size: new UDim2(1 / count, -3, 1, 0),
				Position: new UDim2((n - 1) / count, 0, 0, 0),
				BackgroundColor3:
					n < step || (n === step && met && needsAction) ? Palette.mango : n === step ? WHITE_HOT : Palette.lineSoft,
				BackgroundTransparency: n === step ? frame.map((f) => 0.15 + (math.sin(f.t * 4) + 1) * 0.2) : 0,
				BorderSizePixel: 0,
				ZIndex: 403,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
		);
	}
	const textArrive = frame.map((f) => easeOut((f.stepAge ?? 1) / 0.32));
	const arriving = (base: number) =>
		React.joinBindings([textArrive, reveal]).map((values) =>
			math.clamp(base + (1 - values[0]) + (1 - math.clamp(values[1], 0, 1)), 0, 1),
		);
	const goalDone = met && needsAction;
	let primary: { text: string; color: Color3; onClick: () => void } | undefined = undefined;
	if (met || !needsAction) {
		primary = { text: step >= count ? "Finish" : "Next", color: Palette.mango, onClick: requestNext };
	} else if (hasCta) {
		primary = { text: ctaLabel!, color: Palette.mango, onClick: onCta! };
	}
	const stampScale = frame.map((f) => {
		const age = f.stampAge ?? 99;
		if (!goalDone) {
			return 0;
		}
		return 1 + (1 - easeOut(age / 0.26)) * 0.9;
	});
	const taskRow =
		needsAction &&
		h(
			"frame",
			{ Size: new UDim2(1, 0, 0, 26), LayoutOrder: 4, BackgroundTransparency: 1, ZIndex: 402 },
			h(
				"frame",
				{
					Size: UDim2.fromOffset(22, 22),
					Position: new UDim2(0, 0, 0.5, 0),
					AnchorPoint: new Vector2(0, 0.5),
					BackgroundColor3: goalDone ? Palette.mint : Palette.panel,
					BorderSizePixel: 0,
					ZIndex: 404,
				},
				h("uicorner", { CornerRadius: new UDim(0, 8) }),
				h("uistroke", {
					Color: goalDone ? Palette.mint : Palette.mango,
					Thickness: 1.5,
					Transparency: goalDone ? 0 : frame.map((f) => 0.2 + (math.sin(f.t * 4) + 1) * 0.25),
				}),
				goalDone && h(StampedCheck, { scale: stampScale }),
			),
			h(Text, {
				value: copy.task ?? copy.title,
				size: 13,
				color: goalDone ? Palette.mint : Palette.cream,
				weight: Enum.FontWeight.Bold,
				fit: true,
				minSize: 10,
				position: UDim2.fromOffset(32, 0),
				sizeConstraint: new UDim2(1, -32, 1, 0),
				zIndex: 403,
			}),
		);
	const missingRow =
		needsAction &&
		!met &&
		h("textlabel", {
			Size: new UDim2(1, 0, 0, 14),
			BackgroundTransparency: 1,
			Text: "Waiting for it to appear on screen.",
			TextColor3: Palette.muted,
			TextSize: 11,
			FontFace: Font.fromEnum(Enum.Font.BuilderSansMedium),
			TextXAlignment: Enum.TextXAlignment.Left,
			Visible: frame.map((f) => f.missing),
			LayoutOrder: 5,
			ZIndex: 402,
		});
	const buttons = h(
		"frame",
		{ Size: new UDim2(1, 0, 0, TapTarget), LayoutOrder: 7, BackgroundTransparency: 1, ZIndex: 402 },
		step > 1 &&
			h(Button, {
				text: "Back",
				icon: "Back.1",
				onClick: () => {
					if (!exiting) {
						onBack();
					}
				},
				color: Palette.panelSoft,
				textColor: Palette.cream,
				outline: true,
				size: new UDim2(0, 96, 1, 0),
				zIndex: 403,
			}),
		primary !== undefined
			? h(
					"frame",
					{
						Size: new UDim2(0, math.min(170, innerW * 0.55), 1, 0),
						Position: UDim2.fromScale(1, 0),
						AnchorPoint: new Vector2(1, 0),
						BackgroundTransparency: 1,
					},
					h(Button, {
						text: primary.text,
						onClick: primary.onClick,
						color: primary.color,
						textColor: Palette.ink,
						size: UDim2.fromScale(1, 1),
						reducedMotion: reducedMotion,
						disabled: exiting,
						highlight: true,
						zIndex: 403,
					}),
				)
			: h(Text, {
					value: "Use the highlighted control",
					size: 12,
					color: Palette.mango,
					weight: Enum.FontWeight.Bold,
					align: Enum.TextXAlignment.Right,
					fit: true,
					minSize: 9,
					position: new UDim2(1, -200, 0, 0),
					sizeConstraint: new UDim2(0, 200, 1, 0),
					zIndex: 403,
				}),
	);
	const dock = h(
		"frame",
		{
			ref: dockRef,
			Size: UDim2.fromOffset(cardW, 0),
			AutomaticSize: Enum.AutomaticSize.Y,
			Position: React.joinBindings([frame, reveal] as React.Binding<unknown>[]).map((values) => {
				const f = values[0] as GuideFrame;
				const slide = (1 - math.clamp(values[1] as number, 0, 1)) * 18;
				return UDim2.fromOffset(f.card.x, f.card.y + slide);
			}),
			BackgroundColor3: Palette.panelRaised,
			BorderSizePixel: 0,
			Active: true,
			ZIndex: 400,
		},
		h("uicorner", { CornerRadius: new UDim(0, 12) }),
		h("uistroke", { Color: Palette.mango, Thickness: 1.5, Transparency: 0.45 }),
		h("uipadding", {
			PaddingTop: new UDim(0, 16),
			PaddingBottom: new UDim(0, 16),
			PaddingLeft: new UDim(0, 20),
			PaddingRight: new UDim(0, 20),
		}),
		h("uilistlayout", {
			FillDirection: Enum.FillDirection.Vertical,
			Padding: new UDim(0, 8),
			SortOrder: Enum.SortOrder.LayoutOrder,
		}),
		h(
			"frame",
			{ Size: new UDim2(1, 0, 0, 28), LayoutOrder: 1, BackgroundTransparency: 1, ZIndex: 402 },
			h("textlabel", {
				Size: new UDim2(0, 120, 1, 0),
				BackgroundTransparency: 1,
				RichText: true,
				Text: `${string.format("%02d", step)}<font color="#8c7a80" size="13"> / ${string.format("%02d", count)}</font>`,
				TextColor3: Palette.mango,
				TextSize: 24,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
				TextXAlignment: Enum.TextXAlignment.Left,
				ZIndex: 403,
			}),
			// phones: a 44px (TapTarget) invisible catch area under the 28px button, so a slightly-off
			// thumb still skips; the visible button sits above it and keeps its own press sound and look
			phone &&
				h("textbutton", {
					Size: new UDim2(0, 124, 0, TapTarget),
					Position: new UDim2(1, -116, 0.5, -TapTarget / 2),
					BackgroundTransparency: 1,
					Text: "",
					AutoButtonColor: false,
					Selectable: false,
					ZIndex: 402,
					Event: {
						Activated: () => {
							Audio.play("click");
							requestSkip();
						},
					},
				}),
			h(Button, {
				text: "Skip guide",
				onClick: requestSkip,
				color: Palette.panelSoft,
				textColor: Palette.muted,
				outline: true,
				size: new UDim2(0, 108, 1, 0),
				position: new UDim2(1, -108, 0, 0),
				zIndex: 403,
			}),
		),
		h("frame", { Size: new UDim2(1, 0, 0, 3), LayoutOrder: 2, BackgroundTransparency: 1, ZIndex: 402 }, segments),
		h(
			"frame",
			{
				Size: new UDim2(1, 0, 0, 0),
				AutomaticSize: Enum.AutomaticSize.Y,
				LayoutOrder: 3,
				BackgroundTransparency: 1,
				ZIndex: 402,
			},
			h("uilistlayout", {
				FillDirection: Enum.FillDirection.Vertical,
				Padding: new UDim(0, 4),
				SortOrder: Enum.SortOrder.LayoutOrder,
			}),
			h(Text, {
				value: copy.title,
				size: phone ? 17 : 19,
				color: Palette.cream,
				weight: Enum.FontWeight.Heavy,
				fit: true,
				minSize: 12,
				transparency: arriving(0),
				sizeConstraint: new UDim2(1, 0, 0, 24),
				layoutOrder: 1,
				zIndex: 402,
			}),
			h(AutoHeightText, {
				value: copy.line,
				width: innerW,
				size: 13,
				color: Palette.creamSoft,
				transparency: arriving(0.05),
				layoutOrder: 2,
				zIndex: 402,
			}),
		),
		taskRow,
		missingRow,
		copy.controls !== undefined &&
			h(Text, {
				value: copy.controls,
				size: 10,
				color: Palette.muted,
				fit: true,
				minSize: 9,
				sizeConstraint: new UDim2(1, 0, 0, 14),
				layoutOrder: 6,
				zIndex: 402,
			}),
		buttons,
	);

	return h(
		OverlayPresence,
		{ amount: reveal },
		h(
			"frame",
			{
				Name: "TutorialClaimActions",
				ref: rootRef,
				Size: UDim2.fromScale(1, 1),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				Active: false,
				ZIndex: 379,
			},
			h("frame", {
				ref: probeRef,
				Size: UDim2.fromOffset(100, 100),
				BackgroundTransparency: 1,
				Visible: true,
				Active: false,
			}),
			spotlight,
			leader,
			dock,
		),
	);
}

const VERSION_ROW_H = 48;
const HIGHLIGHT_ROW_H = 46;
const VERSION_RIGHT_COLUMN_W = 72;
// Each highlight is as tall as its wrapped text, so one-line notes don't leave a gap under them.
const HIGHLIGHT_GAP = 6;
function highlightHeight(line: string, textWidth: unknown) {
	if (!typeIs(textWidth, "number") || textWidth <= 0) {
		return HIGHLIGHT_ROW_H - HIGHLIGHT_GAP;
	}
	// measured as rendered: the 12px label draws at 14px bold once the text-size setting applies
	return math.max(18, measureWrappedTextHeight(`•  ${line}`, textWidth, 14, Enum.FontWeight.Bold) + 4);
}

interface VersionEntry {
	Version: string;
	Title: string;
	Date: string;
	Highlights: string[];
}

function versionCardHeight(entry: VersionEntry, expanded: boolean, textWidth: unknown) {
	if (!expanded) {
		return VERSION_ROW_H;
	}
	let total = 0;
	for (const line of entry.Highlights) {
		total += highlightHeight(line, textWidth) + HIGHLIGHT_GAP;
	}
	return VERSION_ROW_H + total + 12;
}

interface VersionCardProps {
	entry: VersionEntry;
	index: number;
	current: boolean;
	expanded: boolean;
	onToggle: () => void;
	reducedMotion?: boolean;
	textWidth: number;
}

function VersionCard(param: VersionCardProps) {
	const entry = param.entry;
	const index = param.index;
	const current = param.current;
	const expanded = param.expanded;
	const onToggle = param.onToggle;
	const reducedMotion = param.reducedMotion;
	const reveal = useStagger(index, reducedMotion, 0.03, 0.26);
	const accent = current ? Palette.mint : Palette.violet;
	const height = versionCardHeight(entry, expanded, param.textWidth);
	const fade = () => reveal.map((amount) => 1 - amount);
	const hitbox = h("textbutton", {
		Size: new UDim2(1, 0, 0, VERSION_ROW_H),
		BackgroundTransparency: 1,
		BorderSizePixel: 0,
		Text: "",
		AutoButtonColor: false,
		Active: true,
		Selectable: false,
		ZIndex: 328,
		Event: {
			Activated: () => {
				Audio.play("tabSwitch");
				onToggle();
			},
		},
	});
	const corner = h("uicorner", { CornerRadius: new UDim(0, 8) });
	const stroke = h("uistroke", {
		Color: accent,
		Thickness: current ? 1.5 : 1,
		Transparency: current ? 0.32 : 0.68,
		ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
	});
	const rail = h(
		"frame",
		{
			Size: UDim2.fromOffset(3, 22),
			Position: UDim2.fromOffset(10, 13),
			BackgroundColor3: accent,
			BackgroundTransparency: fade(),
			BorderSizePixel: 0,
			ZIndex: 326,
		},
		h("uicorner", { CornerRadius: new UDim(1, 0) }),
	);
	const titles = h(
		"frame",
		{
			Size: new UDim2(1, -(VERSION_RIGHT_COLUMN_W + 28), 0, VERSION_ROW_H),
			Position: UDim2.fromOffset(20, 0),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			ZIndex: 326,
		},
		h(Text, {
			value: entry.Version,
			size: 11,
			color: accent,
			weight: Enum.FontWeight.Heavy,
			fit: true,
			minSize: 8,
			position: UDim2.fromOffset(0, 8),
			sizeConstraint: new UDim2(1, 0, 0, 14),
			transparency: fade(),
			zIndex: 326,
		}),
		h(Text, {
			value: entry.Title,
			size: 13,
			color: Palette.cream,
			weight: Enum.FontWeight.Bold,
			fit: true,
			minSize: 9,
			position: UDim2.fromOffset(0, 24),
			sizeConstraint: new UDim2(1, 0, 0, 16),
			transparency: fade(),
			zIndex: 326,
		}),
	);
	const rightColumn = h(
		"frame",
		{
			Size: UDim2.fromOffset(VERSION_RIGHT_COLUMN_W, VERSION_ROW_H),
			Position: new UDim2(1, -(VERSION_RIGHT_COLUMN_W + 10), 0, 0),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			ZIndex: 327,
		},
		h("uilistlayout", {
			FillDirection: Enum.FillDirection.Vertical,
			HorizontalAlignment: Enum.HorizontalAlignment.Right,
			VerticalAlignment: Enum.VerticalAlignment.Center,
			Padding: new UDim(0, 3),
			SortOrder: Enum.SortOrder.LayoutOrder,
		}),
		h(Text, {
			value: entry.Date,
			size: 9,
			color: Palette.muted,
			weight: Enum.FontWeight.Bold,
			align: Enum.TextXAlignment.Right,
			fit: true,
			minSize: 7,
			layoutOrder: 0,
			sizeConstraint: new UDim2(1, 0, 0, 12),
			transparency: fade(),
			zIndex: 327,
		}),
		current &&
			h(
				"frame",
				{
					Size: UDim2.fromOffset(VERSION_RIGHT_COLUMN_W, 17),
					LayoutOrder: 1,
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ZIndex: 328,
				},
				h(Badge, { value: "Latest", accent: Palette.mint, filled: true, size: UDim2.fromScale(1, 1), zIndex: 328 }),
			),
		h(Text, {
			value: expanded ? "Hide" : "View",
			size: 9,
			color: accent,
			weight: Enum.FontWeight.Heavy,
			align: Enum.TextXAlignment.Right,
			fit: true,
			layoutOrder: 2,
			sizeConstraint: new UDim2(1, 0, 0, 13),
			transparency: fade(),
			zIndex: 327,
		}),
	);
	let highlights: React.Element | false = false;
	if (expanded) {
		const lines = entry.Highlights.map((line, lineIndex) =>
			h(Text, {
				key: lineIndex,
				value: `•  ${line}`,
				size: 12,
				color: Palette.creamSoft,
				wrap: true,
				fit: true, minSize: 10,
				layoutOrder: lineIndex,
				sizeConstraint: new UDim2(1, 0, 0, highlightHeight(line, param.textWidth)),
				zIndex: 327,
			}),
		);
		highlights = h(
			"frame",
			{
				Size: new UDim2(1, -30, 0, height - VERSION_ROW_H),
				Position: UDim2.fromOffset(20, VERSION_ROW_H),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				ZIndex: 326,
			},
			h("uilistlayout", {
				FillDirection: Enum.FillDirection.Vertical,
				Padding: new UDim(0, 6),
				SortOrder: Enum.SortOrder.LayoutOrder,
			}),
			lines,
		);
	}
	return h(
		"frame",
		{
			Size: new UDim2(1, -8, 0, height),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			LayoutOrder: index,
			ClipsDescendants: false,
		},
		hitbox,
		h(
			"frame",
			{
				Size: UDim2.fromScale(1, 1),
				BackgroundColor3: Palette.panel,
				BackgroundTransparency: fade(),
				BorderSizePixel: 0,
				ClipsDescendants: false,
				ZIndex: 325,
			},
			corner,
			stroke,
			rail,
			titles,
			rightColumn,
			highlights,
		),
	);
}

interface ReleaseNotesModalProps {
	version: string;
	season: string;
	announcement?: string;
	notes: string[];
	history?: VersionEntry[];
	viewportWidth: number;
	viewportHeight: number;
	reducedMotion?: boolean;
	onClose: () => void;
	onOpenMail?: () => void;
}

export function ReleaseNotesModal(param: ReleaseNotesModalProps) {
	const version = param.version;
	const season = param.season;
	const announcement = param.announcement;
	const notes = param.notes;
	let history = param.history;
	if (history === undefined) {
		history = [];
	}
	const viewportWidth = param.viewportWidth;
	const viewportHeight = param.viewportHeight;
	const reducedMotion = param.reducedMotion;
	const onClose = param.onClose;
	const onOpenMail = param.onOpenMail;
	const viewport = useViewport();
	React.useEffect(() => {
		Audio.play("modalOpen");
	}, []);
	const [reveal, exiting, beginExit] = usePresence(reducedMotion);
	const closeGuard = React.useRef(false);
	const closeOnce = React.useCallback(() => {
		if (closeGuard.current) {
			return undefined;
		}
		closeGuard.current = true;
		Audio.play("close");
		beginExit(onClose);
	}, [beginExit, onClose]);
	const closeOnceRef = React.useRef(closeOnce);
	closeOnceRef.current = closeOnce;
	React.useEffect(() => {
		const actionName = "AstralForgeReleaseClose";
		ContextActionService.BindActionAtPriority(
			actionName,
			(_name, inputState) => {
				if (inputState === Enum.UserInputState.Begin) {
					closeOnceRef.current();
				}
				return Enum.ContextActionResult.Sink;
			},
			false,
			2300,
			Enum.KeyCode.ButtonB,
		);
		return () => ContextActionService.UnbindAction(actionName);
	}, []);
	const openMail = React.useCallback(() => {
		if (closeGuard.current || onOpenMail === undefined) {
			return undefined;
		}
		closeGuard.current = true;
		beginExit(onOpenMail);
	}, [beginExit, onOpenMail]);
	const safeTop = math.max(8, viewport.topInset);
	const safeBottom = math.max(8, viewport.bottomInset);
	const safeSide = math.max(8, viewport.sideInset);
	const width = math.max(240, math.min(650, viewportWidth - safeSide * 2 - 16));
	const availableHeight = math.max(160, viewportHeight - safeTop - safeBottom - 16);
	const height = math.min(530, availableHeight);
	const veryShort = height < 280;
	const condensed = height < 420;
	const padding = veryShort ? 12 : condensed ? Space.lg : Space.xl;
	const contentHeight = math.max(1, height - padding * 2);
	const stackActions = onOpenMail !== undefined && (viewport.compact || width < 430) && height >= 320;
	const actionHeight = stackActions ? TapTarget * 2 + 8 : TapTarget;
	const headerHeight = veryShort ? 70 : condensed ? 118 : 146;
	// the width a highlight label really has inside the version card
	const highlightTextWidth = math.max(120, width - padding * 2 - 30); // matches the 577px the labels measure at 650 wide
	const scrollHeight = math.max(1, contentHeight - headerHeight - actionHeight - Space.md);
	const centerY = safeTop + math.max(0, (viewportHeight - safeTop - safeBottom) / 2);
	const effectiveHistory: VersionEntry[] =
		history.size() > 0 ? history : [{ Version: version, Title: season, Date: "", Highlights: notes }];
	const [expandedVersions, setExpandedVersions] = React.useState<string[]>(() =>
		effectiveHistory.size() > 0 ? [effectiveHistory[0].Version] : [],
	);
	const toggleVersion = React.useCallback((entryVersion: string) => {
		setExpandedVersions((current) =>
			current.includes(entryVersion) ? current.filter((id) => id !== entryVersion) : [...current, entryVersion],
		);
	}, []);
	const canvasH =
		effectiveHistory.reduce(
			(total, entry) => total + versionCardHeight(entry, expandedVersions.includes(entry.Version), highlightTextWidth),
			0,
		) +
		math.max(0, effectiveHistory.size() - 1) * CARD_GAP;
	const padFocus = useGamepadAutofocus(true, reveal) as React.MutableRefObject<Instance | undefined>;

	const overlayHostRef = React.useRef<Instance>();
	React.useEffect(() => {
		GamepadNavigationService.BeginOverlayFocus();
		return () => GamepadNavigationService.EndOverlayFocus();
	}, []);
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = overlayHostRef.current ?? padFocus.current;
		if (host === undefined) {
			return undefined;
		}
		let alive = true;
		const job = task.defer(() => {
			if (!alive || host.Parent === undefined) {
				return;
			}
			GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			alive = false;
			pcall(task.cancel, job);
		};
	}, []);
	const backdrop = h("imagebutton", {
		Size: UDim2.fromScale(1, 1),
		BackgroundColor3: Palette.void,
		BackgroundTransparency: reveal.map((amount) => 1 - amount * 0.84),
		BorderSizePixel: 0,
		AutoButtonColor: false,
		Active: true,
		Selectable: false,
		ZIndex: 321,
	});
	const blocker = h("imagebutton", {
		Size: UDim2.fromScale(1, 1),
		BackgroundTransparency: 1,
		BorderSizePixel: 0,
		AutoButtonColor: false,
		Active: true,
		Selectable: false,
		ZIndex: 322,
	});
	const seasonTitle = h(Text, {
		value: season,
		size: veryShort ? 18 : 25,
		color: Palette.cream,
		weight: Enum.FontWeight.Heavy,
		fit: true,
		position: UDim2.fromOffset(0, veryShort ? 2 : 4),
		sizeConstraint: new UDim2(1, -(TapTarget + Space.md), 0, veryShort ? 26 : 34),
		zIndex: 325,
	});
	const firstEntry = history[0] as VersionEntry | undefined;
	const versionLine = h(Text, {
		value:
			typeIs(history, "table") && firstEntry !== undefined && typeIs(firstEntry.Title, "string")
				? firstEntry.Title
				: `Version ${version}`,
		size: 12,
		color: Palette.muted,
		weight: Enum.FontWeight.SemiBold,
		fit: true,
		position: UDim2.fromOffset(0, veryShort ? 32 : 44),
		sizeConstraint: new UDim2(1, -(TapTarget + Space.md), 0, 16),
		zIndex: 325,
	});
	const announcementText =
		!veryShort &&
		h(Text, {
			value: announcement,
			size: 13,
			color: Palette.creamSoft,
			wrap: true, fit: true, minSize: 10,
			position: UDim2.fromOffset(0, 72),
			sizeConstraint: new UDim2(1, -4, 0, condensed ? 26 : 44),
			zIndex: 325,
		});
	const meter = h(Meter, {
		value: 1,
		color: Palette.violet,
		position: UDim2.fromOffset(0, veryShort ? 56 : condensed ? 104 : 126),
		size: new UDim2(1, 0, 0, 2),
		reducedMotion: reducedMotion,
	});
	const closeButton = h(
		"frame",
		{
			Size: UDim2.fromOffset(TapTarget, TapTarget),
			Position: new UDim2(1, -TapTarget, 0, 0),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			ZIndex: 328,
		},
		h(Button, {
			text: "",
			icon: "Close.20",
			onClick: closeOnce,
			color: Palette.panelSoft,
			textColor: Palette.cream,
			outline: true,
			size: UDim2.fromScale(1, 1),
			reducedMotion: reducedMotion,
			disabled: exiting,
			zIndex: 328,
		}),
	);
	const listLayout = h("uilistlayout", {
		FillDirection: Enum.FillDirection.Vertical,
		Padding: new UDim(0, CARD_GAP),
		SortOrder: Enum.SortOrder.LayoutOrder,
	});
	const cards = effectiveHistory.map((entry, index) =>
		h(VersionCard, {
			key: entry.Version,
			entry: entry,
			index: index,
			current: entry.Version === version,
			expanded: expandedVersions.includes(entry.Version),
			onToggle: () => toggleVersion(entry.Version),
			reducedMotion: reducedMotion,
			textWidth: highlightTextWidth,
		}),
	);
	return h(
		OverlayPresence,
		{ amount: reveal },
		h(
			"frame",
			{
				Size: UDim2.fromScale(1, 1),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				ZIndex: 320,
				Visible: reveal.map((amount) => amount > 0.01),
			},
			backdrop,
			h(
				"frame",
				{
					ref: (node: Instance | undefined) => {
						padFocus.current = node;
						overlayHostRef.current = node;
					},
					...ModalSelectionScope,
					Size: UDim2.fromOffset(width, height),
					Position: reveal.map((amount) => new UDim2(0.5, 0, 0, centerY + revealOffset(amount))),
					AnchorPoint: new Vector2(0.5, 0.5),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ZIndex: 322,
					Visible: reveal.map((amount) => amount > 0.015),
				},
				blocker,
				h(
					Panel,
					{
						size: UDim2.fromScale(1, 1),
						accent: Palette.violet,
						background: Palette.panelRaised,
						padding: padding,
						zIndex: 323,
						reveal: reveal,
					},
					seasonTitle,
					versionLine,
					announcementText,
					meter,
					closeButton,
					h(
						"scrollingframe",
						{
							Size: new UDim2(1, 0, 0, scrollHeight),
							Position: UDim2.fromOffset(0, headerHeight),
							CanvasSize: new UDim2(0, 0, 0, canvasH),
							AutomaticCanvasSize: Enum.AutomaticSize.None,
							BackgroundTransparency: 1,
							BorderSizePixel: 0,
							ScrollBarThickness: 3,
							ScrollBarImageColor3: Palette.violet,
							ScrollBarImageTransparency: 0.28,
							ScrollingDirection: Enum.ScrollingDirection.Y,
							VerticalScrollBarInset: Enum.ScrollBarInset.ScrollBar,
							ElasticBehavior: Enum.ElasticBehavior.WhenScrollable,
							ClipsDescendants: true,
							Active: true,
							Selectable: false,
							ZIndex: 324,
						},
						listLayout,
						cards,
					),
					stackActions
						? h(
								"frame",
								{
									Size: new UDim2(1, 0, 0, actionHeight),
									Position: UDim2.fromOffset(0, contentHeight - actionHeight),
									BackgroundTransparency: 1,
									BorderSizePixel: 0,
									ZIndex: 327,
								},
								h(Button, {
									text: "Got it",
									icon: "Close.21",
									onClick: closeOnce,
									color: Palette.violet,
									textColor: Palette.ink,
									size: new UDim2(1, 0, 0, TapTarget),
									reducedMotion: reducedMotion,
									disabled: exiting,
									zIndex: 327,
								}),
								onOpenMail !== undefined &&
									h(Button, {
										text: "Open mail",
										icon: "Mail.6",
										onClick: openMail,
										color: Palette.panelSoft,
										textColor: Palette.cream,
										outline: true,
										size: new UDim2(1, 0, 0, TapTarget),
										position: UDim2.fromOffset(0, TapTarget + 8),
										reducedMotion: reducedMotion,
										disabled: exiting,
										zIndex: 327,
									}),
							)
						: h(
								"frame",
								{
									Size: new UDim2(1, 0, 0, TapTarget),
									Position: UDim2.fromOffset(0, contentHeight - TapTarget),
									BackgroundTransparency: 1,
									BorderSizePixel: 0,
									ZIndex: 327,
								},
								onOpenMail !== undefined &&
									h(Button, {
										text: "Open mail",
										icon: "Mail.7",
										onClick: openMail,
										color: Palette.panelSoft,
										textColor: Palette.cream,
										outline: true,
										size: new UDim2(0.5, -4, 1, 0),
										reducedMotion: reducedMotion,
										disabled: exiting,
										zIndex: 327,
									}),
								h(Button, {
									text: "Got it",
									icon: "Close.22",
									onClick: closeOnce,
									color: Palette.violet,
									textColor: Palette.ink,
									size: onOpenMail !== undefined ? new UDim2(0.5, -4, 1, 0) : UDim2.fromScale(1, 1),
									position: onOpenMail !== undefined ? new UDim2(0.5, 4, 0, 0) : undefined,
									reducedMotion: reducedMotion,
									disabled: exiting,
									zIndex: 327,
								}),
							),
				),
			),
		),
	);
}

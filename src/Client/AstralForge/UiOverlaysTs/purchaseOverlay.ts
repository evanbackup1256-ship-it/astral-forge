import React from "@rbxts/react";
import { Audio } from "../AudioKit/audio";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { Icon } from "../ArtKit/Icon";
import {
	easeOutBack,
	easeOutCubic,
	ScaleFromCenter,
	useBoatTween,
	useClock,
	useExitTransition,
	useFlash,
	useFlipperSpring,
	useViewport,
} from "../MotionKit/motion";
import { darken, Palette, surfaceGradient } from "../CoreKit/theme";
import { Button, OverlayPresence, Text } from "../UiCore/ui";
import { joinTuple } from "../lua";

const UserInputService = game.GetService("UserInputService");

// Props stay as loose tables, exactly as the Luau overlay built them.
const h = React.createElement as unknown as (component: unknown, props?: unknown, ...children: unknown[]) => React.Element;

const PURCHASE_RESULT_HOLD = 2.2;
const PURCHASE_RESULT_HOLD_REDUCED = 1.65;
const PURCHASE_PENDING_FAILSAFE = 45;
const DOT_COLORS = [Palette.mango, Palette.cyan, Palette.mint];

function ForgeDot(props: {
	index: number;
	clock: React.Binding<number>;
	morph: React.Binding<number>;
	reducedMotion?: boolean;
}) {
	const index = props.index;
	const clock = props.clock;
	const morph = props.morph;
	const reducedMotion = props.reducedMotion;
	const color = DOT_COLORS[index];
	const x = (index - 1) * 26;
	const position = joinTuple(clock, morph).map(([time, amount]) => {
		const wave = reducedMotion ? 0 : math.pow((math.sin(time * math.pi * 2 - index * 0.82) + 1) * 0.5, 1.6);
		return new UDim2(0.5, math.round(x * (1 - amount)), 0.5, math.round(9 - wave * 18));
	});
	const scale = joinTuple(clock, morph).map(([time, amount]) => {
		const pulse = reducedMotion ? 1 : 0.82 + (math.sin(time * math.pi * 2 - index * 0.82) + 1) * 0.13;
		return math.max(0.05, pulse * (1 - amount));
	});
	return h(
		"frame",
		{
			Size: UDim2.fromOffset(14, 14),
			Position: position,
			AnchorPoint: new Vector2(0.5, 0.5),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			ZIndex: 414,
		},
		h(
			ScaleFromCenter,
			{ scale, zIndex: 414 },
			h(
				"frame",
				{
					Size: UDim2.fromScale(1, 1),
					BackgroundColor3: color,
					BackgroundTransparency: morph.map((amount) => math.clamp(amount * 1.2, 0, 1)),
					BorderSizePixel: 0,
					ZIndex: 414,
				},
				h("uicorner", { CornerRadius: new UDim(1, 0) }),
				h("uistroke", { Color: Palette.white, Thickness: 1, Transparency: 0.42 }),
				h(
					"frame",
					{
						Size: new UDim2(1.35, 0, 0, 3),
						Position: new UDim2(0.5, 0, 1, 9),
						AnchorPoint: new Vector2(0.5, 0.5),
						BackgroundColor3: darken(color, 0.28),
						BackgroundTransparency: 0.54,
						BorderSizePixel: 0,
					},
					h("uicorner", { CornerRadius: new UDim(1, 0) }),
				),
			),
		),
	);
}

function ResultGlyph(props: { phase: string; amount: React.Binding<number>; accent: Color3 }) {
	const phase = props.phase;
	const amount = props.amount;
	const accent = props.accent;
	const kind = phase === "success" ? "Check" : "Close";
	return h(
		"frame",
		{
			Size: UDim2.fromOffset(78, 78),
			Position: UDim2.fromScale(0.5, 0.5),
			AnchorPoint: new Vector2(0.5, 0.5),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			ZIndex: 415,
		},
		h(
			ScaleFromCenter,
			{ scale: amount.map((value) => 0.24 + value * 0.76), zIndex: 415 },
			h(
				"frame",
				{
					Size: UDim2.fromScale(1, 1),
					BackgroundColor3: darken(accent, 0.78),
					BackgroundTransparency: amount.map((value) => 1 - value * 0.22),
					BorderSizePixel: 0,
					ZIndex: 415,
				},
				h("uicorner", { CornerRadius: new UDim(0, 22) }),
				h("uistroke", {
					Color: accent,
					Thickness: 2,
					Transparency: amount.map((value) => 1 - value * 0.92),
				}),
				h(Icon, {
					kind,
					color: Palette.cream,
					accent,
					size: 54,
					spin: false,
					position: UDim2.fromScale(0.5, 0.5),
					anchorPoint: new Vector2(0.5, 0.5),
				}),
			),
		),
	);
}

interface PurchaseOverlayProps {
	phase: string;
	reducedMotion?: boolean;
	detail?: string;
	onDismiss?: () => void;
}

function PurchaseOverlay(props: PurchaseOverlayProps) {
	const phase = props.phase;
	const reducedMotion = props.reducedMotion;
	const softMotion = reducedMotion;
	const detail = props.detail;
	const onDismiss = props.onDismiss;
	const visible = phase !== "hidden";
	const result = phase === "success" || phase === "fail";
	const show = useBoatTween(visible ? 1 : 0, visible ? 0.25 : 0.18, softMotion, easeOutCubic, 0);
	const card = useBoatTween(visible ? 1 : 0, visible ? 0.34 : 0.15, softMotion, easeOutBack, 0);
	const [exitAmount, exiting, beginExit] = useExitTransition(softMotion, 0.32, phase === "hidden");
	const morph = useFlipperSpring(result ? 1 : 0, softMotion, 500, 30);
	const clock = useClock(phase === "pending" && !reducedMotion, 1.4, 1);
	const viewport = useViewport();
	const [nonce, setNonce] = React.useState(0);
	const dismissRef = React.useRef(onDismiss);
	const dismissStarted = React.useRef(false);
	const overlayHostRef = React.useRef<Frame>();
	dismissRef.current = onDismiss;
	const previousPhase = React.useRef("hidden");
	React.useEffect(() => {
		if (phase === previousPhase.current) {
			return undefined;
		}
		previousPhase.current = phase;
		if (phase === "success") {
			Audio.play("purchaseResult");
		} else if (phase === "fail") {
			Audio.play("error");
		}
	}, [phase]);
	React.useEffect(() => {
		if (result) {
			setNonce((value) => value + 1);
		}
	}, [phase, result]);
	const flash = useFlash(nonce, reducedMotion, phase === "fail" ? 0.62 : 0.48);
	const dismiss = React.useCallback(() => {
		if (!result || exiting || dismissStarted.current) {
			return undefined;
		}
		dismissStarted.current = true;
		Audio.play("purchaseExit");
		beginExit(() => {
			dismissRef.current?.();
		});
	}, [beginExit, exiting, result]);
	React.useEffect(() => {
		if (phase === "pending" || phase === "hidden") {
			dismissStarted.current = false;
		}
	}, [phase]);
	React.useEffect(() => {
		if (!result) {
			return undefined;
		}
		let alive = true;
		const worker = task.delay(reducedMotion ? PURCHASE_RESULT_HOLD_REDUCED : PURCHASE_RESULT_HOLD, () => {
			if (alive) {
				dismiss();
			}
		});
		return () => {
			alive = false;
			pcall(task.cancel, worker);
		};
	}, [dismiss, phase, reducedMotion, result]);
	React.useEffect(() => {
		if (phase === "hidden") {
			GamepadNavigationService.EndOverlayFocus();
			return undefined;
		}
		GamepadNavigationService.BeginOverlayFocus();
		return () => {
			GamepadNavigationService.EndOverlayFocus();
		};
	}, [phase]);
	React.useEffect(() => {
		if (!result || !UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = overlayHostRef.current;
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
			pcall(task.cancel, selectJob);
		};
	}, [phase, result]);
	const accent = phase === "fail" ? Palette.coral : phase === "success" ? Palette.mint : Palette.mango;
	const title = phase === "pending" ? "BUYING..." : phase === "success" ? "BOUGHT" : "COULDN'T BUY";
	const detailText =
		phase === "pending"
			? "Waiting on Roblox checkout"
			: phase === "success"
				? "It's in your account now"
				: detail ?? "You weren't charged";
	const shortLandscape = viewport.height < 430 && viewport.width > viewport.height * 1.14;
	const sideSafe = math.max(viewport.sideInset, 8);
	const topSafe = math.max(viewport.topInset, 8);
	const bottomSafe = math.max(viewport.bottomInset, 8);
	const safeHeight = math.max(184, viewport.height - topSafe - bottomSafe);
	const availableWidth = math.max(280, viewport.width - (sideSafe + 12) * 2);
	const cardWidth = math.min(shortLandscape ? 540 : 430, availableWidth);
	const cardHeight = shortLandscape ? math.clamp(safeHeight - 16, 184, 218) : math.clamp(safeHeight - 20, 232, 272);
	const compactVertical = !shortLandscape && cardHeight < 260;
	const presence = joinTuple(show, card, exitAmount).map(([a, b, c]) => math.min(a, b, c));
	const cardTravel = 22;
	const cardPosition = presence.map((amount) => new UDim2(0.5, 0, 0.5, math.floor((1 - amount) * cardTravel)));
	const cardScale = joinTuple(presence, flash).map(
		([amount, pulse]) => 0.94 + math.clamp(amount, 0, 1) * 0.06 + pulse * 0.025,
	);
	const orbSize = shortLandscape ? math.min(106, cardHeight - 32) : compactVertical ? 104 : 118;
	const orbPosition = shortLandscape ? UDim2.fromOffset(20, math.floor(cardHeight * 0.5)) : new UDim2(0.5, 0, 0, 24);
	const orbAnchor = shortLandscape ? new Vector2(0, 0.5) : new Vector2(0.5, 0);
	const copyLeft = shortLandscape ? orbSize + 42 : 18;
	const copyWidth = shortLandscape ? -(copyLeft + 20) : -36;
	const titleY = shortLandscape
		? math.max(28, math.floor(cardHeight * 0.5) - 44)
		: orbSize + (compactVertical ? 32 : 40);
	const detailY = titleY + (shortLandscape ? 28 : 24);
	const railLeft = shortLandscape ? copyLeft : 26;
	const railBottom = shortLandscape ? 28 : compactVertical ? 29 : 38;
	const dots = [0, 1, 2].map((index) =>
		h(ForgeDot, { key: index, index, clock, morph, reducedMotion }),
	);
	const content = h(
		OverlayPresence,
		{ amount: presence },
		h(
			"frame",
			{
				Size: UDim2.fromScale(1, 1),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				ZIndex: 400,
				Active: presence.map((amount) => amount > 0.02 && !exiting),
				Visible: presence.map((amount) => amount > 0.005),
				ClipsDescendants: false,
				Event: {
					InputBegan: (_frame: unknown, input: InputObject) => {
						if (
							result &&
							!exiting &&
							(input.UserInputType === Enum.UserInputType.MouseButton1 ||
								input.UserInputType === Enum.UserInputType.Touch)
						) {
							dismiss();
						}
					},
				},
			},
			h("frame", {
				Size: UDim2.fromScale(1, 1),
				BackgroundColor3: Palette.void,
				BackgroundTransparency: presence.map((amount) => 1 - amount * 0.68),
				BorderSizePixel: 0,
				ZIndex: 400,
			}),
			h("imagebutton", {
				Name: "PurchaseDismissBackdrop",
				Size: UDim2.fromScale(1, 1),
				BackgroundTransparency: 1,
				Image: "",
				AutoButtonColor: false,
				Active: visible && !exiting,
				Selectable: false,
				Modal: visible,
				ZIndex: 401,
				Event: {
					Activated: () => {
						if (result && !exiting) {
							dismiss();
						}
					},
				},
			}),
			h(
				"frame",
				{
					Size: UDim2.fromOffset(cardWidth, cardHeight),
					Position: cardPosition,
					AnchorPoint: new Vector2(0.5, 0.5),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ZIndex: 405,
					ClipsDescendants: false,
				},
				h(
					ScaleFromCenter,
					{ scale: cardScale, zIndex: 405 },
					h(
						"frame",
						{
							Size: new UDim2(1, 0, 1, 4),
							Position: UDim2.fromOffset(0, 5),
							BackgroundColor3: Palette.shadow,
							BackgroundTransparency: 0.24,
							BorderSizePixel: 0,
							ZIndex: 405,
						},
						h("uicorner", { CornerRadius: new UDim(0, 22) }),
					),
					h(
						"frame",
						{
							Size: UDim2.fromScale(1, 1),
							BackgroundColor3: Palette.panel,
							BorderSizePixel: 0,
							ClipsDescendants: true,
							ZIndex: 406,
						},
						h("uicorner", { CornerRadius: new UDim(0, 22) }),
						h("uigradient", { Color: surfaceGradient(Palette.panelRaised, 0.62), Rotation: 90 }),
						h("uistroke", {
							Color: accent,
							Thickness: 2,
							Transparency: presence.map((amount) => 1 - amount * 0.8),
						}),
						h(
							"frame",
							{
								Size: new UDim2(0.56, 0, 0, 3),
								Position: UDim2.fromScale(0.5, 0),
								AnchorPoint: new Vector2(0.5, 0),
								BackgroundColor3: accent,
								BorderSizePixel: 0,
								ZIndex: 407,
							},
							h("uicorner", { CornerRadius: new UDim(1, 0) }),
							h("uigradient", {
								Transparency: new NumberSequence([
									new NumberSequenceKeypoint(0, 1),
									new NumberSequenceKeypoint(0.5, 0),
									new NumberSequenceKeypoint(1, 1),
								]),
							}),
						),
						h(
							"frame",
							{
								Size: UDim2.fromOffset(orbSize, orbSize),
								Position: orbPosition,
								AnchorPoint: orbAnchor,
								BackgroundColor3: darken(accent, 0.86),
								BackgroundTransparency: 0.18,
								BorderSizePixel: 0,
								ZIndex: 410,
							},
							h("uicorner", { CornerRadius: new UDim(1, 0) }),
							h("uistroke", { Color: accent, Thickness: 2, Transparency: 0.5 }),
							dots,
							phase === "success" && h(ResultGlyph, { phase: "success", amount: morph, accent }),
							phase === "fail" && h(ResultGlyph, { phase: "fail", amount: morph, accent }),
						),
						h(Text, {
							value: title,
							size: shortLandscape ? 15 : 16,
							color: Palette.cream,
							weight: Enum.FontWeight.Heavy,
							align: shortLandscape ? Enum.TextXAlignment.Left : Enum.TextXAlignment.Center,
							fit: true,
							minSize: 11,
							position: UDim2.fromOffset(copyLeft, titleY),
							sizeConstraint: new UDim2(1, copyWidth, 0, 26),
							zIndex: 410,
						}),
						h(Text, {
							value: detailText,
							size: 11,
							color: Palette.creamSoft,
							align: shortLandscape ? Enum.TextXAlignment.Left : Enum.TextXAlignment.Center,
							fit: true,
							minSize: 9,
							position: UDim2.fromOffset(copyLeft, detailY),
							sizeConstraint: new UDim2(1, copyWidth, 0, 28),
							zIndex: 410,
						}),
						h(
							"frame",
							{
								Size: new UDim2(1, -(railLeft + (shortLandscape ? 20 : 26)), 0, 3),
								Position: new UDim2(0, railLeft, 1, -railBottom),
								BackgroundColor3: Palette.lineSoft,
								BackgroundTransparency: 0.52,
								BorderSizePixel: 0,
								ZIndex: 409,
								ClipsDescendants: true,
							},
							h("uicorner", { CornerRadius: new UDim(1, 0) }),
							h(
								"frame",
								{
									Size: phase === "pending" ? clock.map(() => new UDim2(0.22, 0, 1, 0)) : UDim2.fromScale(1, 1),
									Position:
										phase === "pending"
											? clock.map((time) => new UDim2((time * 1.25) % 1, 0, 0, 0))
											: UDim2.fromScale(0, 0),
									BackgroundColor3: accent,
									BorderSizePixel: 0,
								},
								h("uicorner", { CornerRadius: new UDim(1, 0) }),
								h("uigradient", { Color: new ColorSequence(Palette.white, accent) }),
							),
						),
						result &&
							h(
								"frame",
								{
									Name: "PurchaseContinue",
									Size: new UDim2(1, -(copyLeft + (shortLandscape ? 20 : 26)), 0, 36),
									Position: new UDim2(0, copyLeft, 1, -44),
									BackgroundTransparency: 1,
									BorderSizePixel: 0,
									ZIndex: 412,
								},
								h(Button, {
									text: "CONTINUE",
									onClick: dismiss,
									color: accent,
									textColor: Palette.ink,
									size: UDim2.fromScale(1, 1),
									reducedMotion,
									highlight: true,
									selectable: true,
									zIndex: 412,
								}),
							),
					),
				),
			),
		),
	);
	return h(
		"frame",
		{
			ref: overlayHostRef,
			Name: "PurchaseOverlayHost",
			Size: UDim2.fromScale(1, 1),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			ZIndex: 400,
		},
		content,
	);
}

export { PurchaseOverlay, PURCHASE_RESULT_HOLD, PURCHASE_RESULT_HOLD_REDUCED, PURCHASE_PENDING_FAILSAFE };

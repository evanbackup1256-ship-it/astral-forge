// Surfaces: the one look shared by Quick Find, Credits and tooltips.
//
// A surface is a flat panel on Palette.panel with a hairline edge, 14px corners and 14px padding.
// Rows inside it are 44px or taller, sit 2px apart and light up with a tinted plate plus a 3px
// accent edge. Small caps labels name sections; kind chips and key hints are 20-22px pills.
// Panels enter and leave exactly like the rest of the game (usePresence + revealOffset, the same
// code Panel uses); hover, selection and row entrances run on the same smooth spring, and Reduced
// Motion makes them instant. Nothing here glows, and no gradients. Edges are near-invisible at rest
// (revamp r1a): whitespace and the fill step separate surfaces, not outlines.
import React from "@rbxts/react";
import { darken, Palette, Pad, Radius, TapTarget } from "../CoreKit/theme";
import * as MotionTokens from "../MotionKit/motionTokens";
import { revealOffset, useFlipperSpring } from "../MotionKit/motion";
import { Icon } from "../ArtKit/Icon";
import { Audio } from "../AudioKit/audio";
import { InteractionFeedback } from "../CoreKit/interaction";
import { joinTuple } from "../lua";

const UserInputService = game.GetService("UserInputService");

export const SurfaceMetrics = {
	radius: Radius.lg,
	innerRadius: Radius.md,
	pad: Pad.panel,
	gap: 12,
	rowH: TapTarget,
	rowGap: 4,
	edgeW: 3,
	chipH: 20,
	keyH: 22,
} as const;

// type scale: eyebrow labels, row titles, body copy, small print, display names
export const SurfaceType = {
	label: { size: 12, weight: Enum.FontWeight.SemiBold },
	title: { size: 16, weight: Enum.FontWeight.SemiBold },
	body: { size: 13, weight: Enum.FontWeight.Medium },
	small: { size: 12, weight: Enum.FontWeight.Medium },
	hint: { size: 11, weight: Enum.FontWeight.Bold },
	display: { size: 24, weight: Enum.FontWeight.Bold },
} as const;
export type SurfaceTypeName = keyof typeof SurfaceType;

const fonts = new Map<Enum.FontWeight, Font>();
export function surfaceFont(weight: Enum.FontWeight): Font {
	let font = fonts.get(weight);
	if (font === undefined) {
		font = Font.fromName("BuilderSans", weight);
		fonts.set(weight, font);
	}
	return font;
}

// one spring for hover, selection, enter and exit: smooth and critically damped, no overshoot
export const SurfaceMotion = {
	stiffness: MotionTokens.SPRING.smooth.stiffness,
	damping: MotionTokens.SPRING.smooth.damping,
	/** seconds between rows in an entering list, and the most rows that wait their turn */
	stagger: MotionTokens.STAGGER_STEP,
	staggerRows: 10,
} as const;

/** 0..1 toward `goal` on the surface spring; instant with reduced motion. Retargeting never stacks. */
export function useSurfaceSpring(goal: number, reduced: boolean | undefined): React.Binding<number> {
	return useFlipperSpring(goal, reduced === true, SurfaceMotion.stiffness, SurfaceMotion.damping);
}

/** Enter (0 -> 1) on mount: for rows, cards and anything that appears inside an open surface. */
export function useSurfaceEnter(reduced: boolean | undefined, delaySeconds = 0): React.Binding<number> {
	const [goal, setGoal] = React.useState(reduced === true || delaySeconds <= 0 ? 1 : 0);
	React.useEffect(() => {
		if (goal === 1) {
			return undefined;
		}
		const job = task.delay(delaySeconds, () => setGoal(1));
		return () => {
			pcall(task.cancel, job);
		};
	}, []);
	return useFlipperSpring(goal, reduced === true, SurfaceMotion.stiffness, SurfaceMotion.damping, reduced === true ? 1 : 0);
}

const clamp01 = (value: number) => math.clamp(value, 0, 1);

// ── Surface ────────────────────────────────────────────────────────────────────

export interface SurfaceProps {
	size?: UDim2;
	position?: UDim2 | React.Binding<UDim2>;
	anchor?: Vector2;
	zIndex?: number;
	/** 0..1 presence (usePresence): fades the panel; callers move it by revealOffset */
	appear?: React.Binding<number>;
	/** "base" floats over the game; "inset" sits inside another surface */
	tone?: "base" | "inset";
	/** edge tint; a hairline in lineSoft otherwise */
	accent?: Color3;
	autoSize?: boolean;
	padding?: number;
	clips?: boolean;
	active?: boolean;
	frameRef?: React.Ref<Frame>;
	children?: React.ReactNode;
	/** corner radius override (forge cards use 18) */
	radius?: number;
	/** forge card treatment: 1px brass inner rule 3px inside the edge */
	rule?: boolean;
}

export function Surface(props: SurfaceProps) {
	const appear = props.appear;
	const inset = props.tone === "inset";
	const fill = inset ? Palette.panelSoft : Palette.panel;
	const restFill = inset ? 0.35 : 0.03;
	const restEdge = props.accent !== undefined ? 0.7 : 0.86;
	const pad = props.padding ?? SurfaceMetrics.pad;
	return (
		<frame
			ref={props.frameRef as React.Ref<Frame> as never}
			Size={props.size ?? (props.autoSize ? UDim2.fromOffset(0, 0) : UDim2.fromScale(1, 1))}
			AutomaticSize={props.autoSize ? Enum.AutomaticSize.XY : Enum.AutomaticSize.None}
			Position={props.position}
			AnchorPoint={props.anchor}
			BackgroundColor3={fill}
			BackgroundTransparency={appear !== undefined ? appear.map((a) => 1 - (1 - restFill) * clamp01(a)) : restFill}
			BorderSizePixel={0}
			ClipsDescendants={props.clips === true}
			Active={props.active === true}
			Selectable={false}
			ZIndex={props.zIndex}
		>
			<uicorner CornerRadius={new UDim(0, props.radius ?? (inset ? SurfaceMetrics.innerRadius : SurfaceMetrics.radius))} />
			{props.rule === true && (
				<frame
					Size={new UDim2(1, pad * 2 - 6, 1, pad * 2 - 6)}
					Position={UDim2.fromOffset(3 - pad, 3 - pad)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					Active={false}
					ZIndex={props.zIndex}
				>
					<uicorner CornerRadius={new UDim(0, math.max(1, (props.radius ?? SurfaceMetrics.radius) - 3))} />
					<uistroke
						Color={Palette.brass}
						Thickness={1}
						Transparency={appear !== undefined ? appear.map((a) => 1 - 0.25 * clamp01(a)) : 0.75}
					/>
				</frame>
			)}
			<uistroke
				Color={props.accent ?? Palette.lineSoft}
				Thickness={1}
				ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
				Transparency={appear !== undefined ? appear.map((a) => 1 - (1 - restEdge) * clamp01(a)) : restEdge}
			/>
			{pad > 0 && (
				<uipadding
					PaddingLeft={new UDim(0, pad)}
					PaddingRight={new UDim(0, pad)}
					PaddingTop={new UDim(0, pad)}
					PaddingBottom={new UDim(0, pad)}
				/>
			)}
			{props.children}
		</frame>
	);
}

// ── Text ───────────────────────────────────────────────────────────────────────

export interface SurfaceTextProps {
	text: string;
	type?: SurfaceTypeName;
	color?: Color3 | React.Binding<Color3>;
	size?: UDim2;
	position?: UDim2;
	anchor?: Vector2;
	align?: Enum.TextXAlignment;
	yAlign?: Enum.TextYAlignment;
	wrap?: boolean;
	rich?: boolean;
	/** shrink to fit (down to minSize, 11 by default) instead of cutting off */
	fit?: boolean;
	minSize?: number;
	maxWidth?: number;
	autoSize?: boolean;
	/** grow to the wrapped text height at the given width */
	autoHeight?: boolean;
	transparency?: number | React.Binding<number>;
	order?: number;
	zIndex?: number;
	textRef?: React.Ref<TextLabel>;
	onFits?: (fits: boolean) => void;
}

export function SurfaceText(props: SurfaceTextProps) {
	const style = SurfaceType[props.type ?? "body"];
	const shrink = (props.fit === true || props.minSize !== undefined) && !props.autoSize && !props.autoHeight;
	const onFits = props.onFits;
	return (
		<textlabel
			ref={(label: TextLabel | undefined) => {
				if (typeIs(props.textRef, "function")) {
					(props.textRef as (value: TextLabel | undefined) => void)(label);
				} else if (props.textRef !== undefined) {
					(props.textRef as { current?: TextLabel }).current = label;
				}
				if (label !== undefined && onFits !== undefined) {
					task.defer(() => onFits(label.TextFits));
				}
			}}
			Size={props.size ?? (props.autoSize ? UDim2.fromOffset(0, 0) : UDim2.fromScale(1, 1))}
			AutomaticSize={props.autoSize ? Enum.AutomaticSize.XY : props.autoHeight ? Enum.AutomaticSize.Y : Enum.AutomaticSize.None}
			Position={props.position}
			AnchorPoint={props.anchor}
			LayoutOrder={props.order}
			BackgroundTransparency={1}
			Text={props.text}
			RichText={props.rich === true}
			FontFace={surfaceFont(style.weight)}
			TextSize={style.size}
			TextScaled={shrink}
			TextColor3={props.color ?? Palette.cream}
			TextTransparency={props.transparency ?? 0}
			TextWrapped={props.wrap === true}
			TextXAlignment={props.align ?? Enum.TextXAlignment.Left}
			TextYAlignment={props.yAlign ?? (props.wrap ? Enum.TextYAlignment.Top : Enum.TextYAlignment.Center)}
			TextTruncate={props.wrap || shrink ? Enum.TextTruncate.None : Enum.TextTruncate.AtEnd}
			ZIndex={props.zIndex}
			Change={onFits !== undefined ? { TextFits: (label: TextLabel) => onFits(label.TextFits) } : undefined}
		>
			{shrink && <uitextsizeconstraint MinTextSize={props.minSize ?? 11} MaxTextSize={style.size} />}
			{props.maxWidth !== undefined && <uisizeconstraint MaxSize={new Vector2(props.maxWidth, math.huge)} />}
		</textlabel>
	);
}

// ── Rows ───────────────────────────────────────────────────────────────────────

/** 3px accent bar on a row's left edge; grows from the middle as `lit` goes to 1. */
export function AccentEdge(props: { lit: React.Binding<number>; color: Color3; zIndex?: number }) {
	return (
		<frame
			Size={props.lit.map((a) => new UDim2(0, SurfaceMetrics.edgeW, clamp01(a) * 0.62, 0))}
			Position={new UDim2(0, 3, 0.5, 0)}
			AnchorPoint={new Vector2(0, 0.5)}
			BackgroundColor3={props.color}
			BackgroundTransparency={props.lit.map((a) => 1 - clamp01(a))}
			BorderSizePixel={0}
			ZIndex={props.zIndex}
		>
			<uicorner CornerRadius={new UDim(1, 0)} />
		</frame>
	);
}

/** The lit state of a row: a plate tinted from the row's own accent, its edge and the accent bar. */
export function RowPlate(props: { lit: React.Binding<number>; accent: Color3; zIndex?: number }) {
	const lit = props.lit;
	return (
		<frame
			Size={UDim2.fromScale(1, 1)}
			BackgroundColor3={darken(props.accent, 0.72)}
			BackgroundTransparency={lit.map((a) => 1 - 0.7 * clamp01(a))}
			BorderSizePixel={0}
			ZIndex={props.zIndex}
		>
			<uicorner CornerRadius={new UDim(0, SurfaceMetrics.innerRadius)} />
			<uistroke
				Color={props.accent}
				Thickness={1}
				ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
				Transparency={lit.map((a) => 1 - 0.25 * clamp01(a))}
			/>
			<AccentEdge lit={lit} color={props.accent} zIndex={props.zIndex !== undefined ? props.zIndex + 1 : undefined} />
		</frame>
	);
}

export interface SurfaceRowProps {
	height?: number;
	width?: UDim;
	order?: number;
	accent: Color3;
	/** 0..1 lit amount, usually useSurfaceSpring(selected ? 1 : 0) */
	lit: React.Binding<number>;
	/** 0..1 entrance; rows rise by revealOffset while it runs, like Panel */
	enter?: React.Binding<number>;
	selectable?: boolean;
	zIndex?: number;
	events?: React.InstanceEvent<TextButton>;
	buttonRef?: React.Ref<TextButton>;
	children?: React.ReactNode;
}

/** A tappable row (44px minimum) with the shared lit plate behind its content. */
export function SurfaceRow(props: SurfaceRowProps) {
	const z = props.zIndex ?? 1;
	const enter = props.enter;
	return (
		<textbutton
			ref={props.buttonRef}
			Size={new UDim2(props.width ?? new UDim(1, 0), new UDim(0, math.max(SurfaceMetrics.rowH, props.height ?? SurfaceMetrics.rowH)))}
			LayoutOrder={props.order}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			AutoButtonColor={false}
			Selectable={props.selectable === true}
			Text=""
			ZIndex={z}
			Event={props.events}
		>
			<RowPlate lit={props.lit} accent={props.accent} zIndex={z} />
			<frame
				Size={UDim2.fromScale(1, 1)}
				Position={enter !== undefined ? enter.map((a) => UDim2.fromOffset(0, revealOffset(a))) : undefined}
				BackgroundTransparency={1}
				ZIndex={z + 2}
			>
				{props.children}
			</frame>
		</textbutton>
	);
}

/** Square icon tile used at the start of rows and in spotlights. */
export function SurfaceIconTile(props: {
	size: number;
	accent: Color3;
	position?: UDim2;
	anchor?: Vector2;
	zIndex?: number;
	children?: React.ReactNode;
}) {
	return (
		<frame
			Size={UDim2.fromOffset(props.size, props.size)}
			Position={props.position}
			AnchorPoint={props.anchor}
			BackgroundColor3={darken(props.accent, 0.62)}
			BorderSizePixel={0}
			ZIndex={props.zIndex}
		>
			<uicorner CornerRadius={new UDim(0, math.floor(props.size * 0.3))} />
			<uistroke Color={props.accent} Transparency={0.85} Thickness={1} />
			{props.children}
		</frame>
	);
}

// ── Labels ─────────────────────────────────────────────────────────────────────

/** Small caps section label with an optional count and a hairline to the right. */
export function SurfaceSectionLabel(props: { text: string; count?: number; order?: number; accent?: Color3; height?: number; zIndex?: number }) {
	const label = props.count !== undefined ? `${props.text}  ${props.count}` : props.text;
	return (
		<frame Size={new UDim2(1, 0, 0, props.height ?? 26)} LayoutOrder={props.order} BackgroundTransparency={1} ZIndex={props.zIndex}>
			<uilistlayout
				FillDirection={Enum.FillDirection.Horizontal}
				VerticalAlignment={Enum.VerticalAlignment.Bottom}
				Padding={new UDim(0, 8)}
				SortOrder={Enum.SortOrder.LayoutOrder}
			/>
			<uipadding PaddingLeft={new UDim(0, 12)} PaddingBottom={new UDim(0, 6)} />
			<SurfaceText text={label} type="label" color={props.accent ?? Palette.mango} autoSize={true} order={1} zIndex={props.zIndex} />
			<frame
				Size={new UDim2(1, -160, 0, 1)}
				LayoutOrder={2}
				BackgroundColor3={Palette.lineSoft}
				BackgroundTransparency={0.5}
				BorderSizePixel={0}
				ZIndex={props.zIndex}
			>
				<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
			</frame>
		</frame>
	);
}

/** "Page", "Setting", "Developer": a small pill that says what something is. */
export function KindChip(props: { text: string; accent?: Color3; order?: number; zIndex?: number }) {
	return (
		<textlabel
			Size={UDim2.fromOffset(0, SurfaceMetrics.chipH)}
			AutomaticSize={Enum.AutomaticSize.X}
			LayoutOrder={props.order}
			BackgroundColor3={props.accent !== undefined ? darken(props.accent, 0.68) : Palette.panelSoft}
			BackgroundTransparency={0.2}
			BorderSizePixel={0}
			Text={props.text}
			FontFace={surfaceFont(SurfaceType.hint.weight)}
			TextSize={SurfaceType.hint.size}
			TextColor3={props.accent ?? Palette.creamSoft}
			ZIndex={props.zIndex}
		>
			<uicorner CornerRadius={new UDim(1, 0)} />
			<uipadding PaddingLeft={new UDim(0, 8)} PaddingRight={new UDim(0, 8)} />
		</textlabel>
	);
}

/** A key cap and what it does: [Esc] Close. */
export function KeyHint(props: { keys: string; label: string; order?: number; zIndex?: number }) {
	return (
		<frame
			Size={UDim2.fromOffset(0, 24)}
			AutomaticSize={Enum.AutomaticSize.X}
			LayoutOrder={props.order}
			BackgroundTransparency={1}
			ZIndex={props.zIndex}
		>
			<uilistlayout
				FillDirection={Enum.FillDirection.Horizontal}
				VerticalAlignment={Enum.VerticalAlignment.Center}
				Padding={new UDim(0, 6)}
				SortOrder={Enum.SortOrder.LayoutOrder}
			/>
			<textlabel
				Size={UDim2.fromOffset(0, SurfaceMetrics.keyH)}
				AutomaticSize={Enum.AutomaticSize.X}
				LayoutOrder={1}
				BackgroundColor3={Palette.panelRaised}
				BorderSizePixel={0}
				Text={props.keys}
				FontFace={surfaceFont(SurfaceType.hint.weight)}
				TextSize={12}
				TextColor3={Palette.cream}
				ZIndex={props.zIndex}
			>
				<uicorner CornerRadius={new UDim(0, Radius.sm)} />
				<uistroke Color={Palette.lineSoft} Transparency={0.4} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
				<uipadding PaddingLeft={new UDim(0, 7)} PaddingRight={new UDim(0, 7)} />
			</textlabel>
			{props.label !== "" && (
				<SurfaceText text={props.label} type="small" color={Palette.creamSoft} autoSize={true} order={2} zIndex={props.zIndex} />
			)}
		</frame>
	);
}

// ── SearchField ────────────────────────────────────────────────────────────────
//
// The one search box. 44px tall wherever it sits: magnifier, text, an optional count on the right,
// and a clear button that slides in once there is something to clear. Focus draws the edge in the
// caller's accent and grows a short accent bar on the left, on the surface spring.
// Tap anywhere on the field to type (touch), A on a selected field to type (gamepad), Esc or B to
// let go. Callers get onChange after a short pause; pass debounce={0} to hear every keystroke.

export const SEARCH_H = SurfaceMetrics.rowH;

export interface SearchFieldProps {
	value: string;
	onChange?: (text: string) => void;
	/** Enter pressed while typing */
	onSubmit?: (text: string) => void;
	placeholder?: string;
	accent?: Color3;
	/** small right-aligned note, e.g. "12 found"; hidden while empty */
	hint?: string;
	/** seconds of quiet before onChange; 0 = every keystroke */
	debounce?: number;
	autoFocus?: boolean;
	boxRef?: React.MutableRefObject<TextBox | undefined>;
	position?: UDim2 | React.Binding<UDim2>;
	/** width comes from here; the height is always 44 */
	size?: UDim2;
	anchor?: Vector2;
	layoutOrder?: number;
	reducedMotion?: boolean;
	zIndex?: number;
}

export function SearchField(props: SearchFieldProps) {
	const accent = props.accent ?? Palette.mango;
	const z = props.zIndex ?? 10;
	const reduced = props.reducedMotion === true;
	const wait = props.debounce ?? 0.08;
	const width = props.size ?? UDim2.fromOffset(220, 0);
	const ownRef = React.useRef<TextBox>();
	const boxRef = props.boxRef ?? ownRef;
	const [draft, setDraft] = React.useState(props.value);
	const [focused, setFocused] = React.useState(false);
	const [pointed, setPointed] = React.useState(false);
	const [clearLit, setClearLit] = React.useState(false);
	const emitted = React.useRef(props.value);
	const pending = React.useRef<thread>();
	const onChangeRef = React.useRef(props.onChange);
	onChangeRef.current = props.onChange;

	const cancelPending = () => {
		if (pending.current !== undefined) {
			pcall(task.cancel, pending.current);
			pending.current = undefined;
		}
	};
	const emit = (text: string) => {
		cancelPending();
		if (text === emitted.current) {
			return;
		}
		emitted.current = text;
		onChangeRef.current?.(text);
	};
	const schedule = (text: string) => {
		cancelPending();
		if (wait <= 0) {
			emit(text);
			return;
		}
		pending.current = task.delay(wait, () => {
			pending.current = undefined;
			emit(text);
		});
	};
	const clear = () => {
		cancelPending();
		setDraft("");
		emit("");
		Audio.play("inputClear");
		InteractionFeedback.tap();
		boxRef.current?.CaptureFocus();
	};

	// the parent owns the query: follow it whenever we aren't mid-edit
	React.useEffect(() => {
		if (!focused || props.value === "") {
			emitted.current = props.value;
			setDraft(props.value);
		}
	}, [props.value, focused]);
	React.useEffect(() => cancelPending, []);
	React.useEffect(() => {
		if (props.autoFocus !== true) {
			return undefined;
		}
		const job = task.defer(() => {
			const box = boxRef.current;
			if (box !== undefined && box.Parent !== undefined) {
				box.CaptureFocus();
			}
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, []);
	React.useEffect(() => {
		if (!focused) {
			return undefined;
		}
		const conn = UserInputService.InputBegan.Connect((input) => {
			if (input.KeyCode === Enum.KeyCode.Escape || input.KeyCode === Enum.KeyCode.ButtonB) {
				boxRef.current?.ReleaseFocus();
			}
		});
		return () => conn.Disconnect();
	}, [focused]);

	const hasText = draft !== "";
	const focus = useSurfaceSpring(focused ? 1 : 0, reduced);
	const lit = useSurfaceSpring(focused ? 1 : pointed ? 0.35 : 0, reduced);
	const clearIn = useSurfaceSpring(hasText ? 1 : 0, reduced);
	const clearHover = useSurfaceSpring(clearLit ? 1 : 0, reduced);
	const hint = hasText ? props.hint : undefined;
	const hintW = hint !== undefined ? 76 : 0;
	const clearW = SurfaceMetrics.rowH - 8;

	return (
		<textbutton
			Size={new UDim2(width.X.Scale, width.X.Offset, 0, SEARCH_H)}
			Position={props.position}
			AnchorPoint={props.anchor}
			LayoutOrder={props.layoutOrder}
			BackgroundColor3={Palette.panelSoft}
			BackgroundTransparency={lit.map((a) => 0.35 - 0.2 * clamp01(a))}
			BorderSizePixel={0}
			AutoButtonColor={false}
			Text=""
			Selectable={false}
			ClipsDescendants={true}
			ZIndex={z}
			Event={{
				Activated: () => boxRef.current?.CaptureFocus(),
				MouseEnter: () => setPointed(true),
				MouseLeave: () => setPointed(false),
			}}
		>
			<uicorner CornerRadius={new UDim(0, SurfaceMetrics.innerRadius)} />
			<uistroke
				ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
				Color={focus.map((a) => Palette.lineSoft.Lerp(accent, clamp01(a)))}
				Thickness={1}
				Transparency={lit.map((a) => 0.4 - 0.3 * clamp01(a))}
			/>
			{/* the focus tell: a short accent bar that grows from the middle of the left edge */}
			<frame
				AnchorPoint={new Vector2(0, 0.5)}
				Position={new UDim2(0, 0, 0.5, 0)}
				Size={focus.map((a) => new UDim2(0, SurfaceMetrics.edgeW, 0, math.round(18 * clamp01(a))))}
				BackgroundColor3={accent}
				BackgroundTransparency={focus.map((a) => 1 - clamp01(a))}
				BorderSizePixel={0}
				ZIndex={z + 1}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
			<frame
				Size={UDim2.fromOffset(18, 18)}
				Position={new UDim2(0, 14, 0.5, 0)}
				AnchorPoint={new Vector2(0, 0.5)}
				BackgroundTransparency={1}
				ZIndex={z + 1}
			>
				<Icon kind="Search.11" color={focused ? accent : Palette.muted} accent={accent} size={18} spin={false} />
			</frame>
			<textbox
				ref={boxRef as React.Ref<TextBox> as never}
				Size={clearIn.map((a) => new UDim2(1, -(42 + 10 + hintW + (clearW + 4) * clamp01(a)), 1, 0))}
				Position={UDim2.fromOffset(42, 0)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				Text={draft}
				PlaceholderText={props.placeholder ?? "Search"}
				PlaceholderColor3={Palette.muted}
				TextColor3={Palette.cream}
				TextSize={15}
				FontFace={surfaceFont(Enum.FontWeight.Medium)}
				TextXAlignment={Enum.TextXAlignment.Left}
				TextTruncate={Enum.TextTruncate.AtEnd}
				ClearTextOnFocus={false}
				ClipsDescendants={true}
				Selectable={true}
				ZIndex={z + 1}
				Change={{
					Text: (box) => {
						const text = box.Text;
						if (text === draft) {
							return;
						}
						if (box.IsFocused() && text.size() > draft.size()) {
							Audio.play("searchType");
						}
						setDraft(text);
						schedule(text);
					},
				}}
				Event={{
					Focused: () => {
						setFocused(true);
						Audio.play("inputFocus");
						InteractionFeedback.tick();
					},
					FocusLost: (box, enter) => {
						setFocused(false);
						emit(box.Text);
						if (enter) {
							props.onSubmit?.(box.Text);
						}
					},
					SelectionGained: () => setPointed(true),
					SelectionLost: () => setPointed(false),
				}}
			/>
			{hint !== undefined && (
				<SurfaceText
					text={hint}
					type="hint"
					color={Palette.creamSoft}
					align={Enum.TextXAlignment.Right}
					size={UDim2.fromOffset(hintW, 20)}
					position={new UDim2(1, -(8 + clearW + 4), 0.5, 0)}
					anchor={new Vector2(1, 0.5)}
					zIndex={z + 1}
				/>
			)}
			<textbutton
				AnchorPoint={new Vector2(1, 0.5)}
				Position={clearIn.map((a) => new UDim2(1, -4 + math.round((1 - clamp01(a)) * 12), 0.5, 0))}
				Size={UDim2.fromOffset(clearW, clearW)}
				BackgroundColor3={Palette.panelRaised}
				BackgroundTransparency={joinTuple<[number, number]>(clearIn, clearHover).map(
					([shown, hover]) => 1 - clamp01(shown) * (0.45 + 0.4 * clamp01(hover)),
				)}
				BorderSizePixel={0}
				AutoButtonColor={false}
				Text=""
				Active={hasText}
				Selectable={hasText}
				Visible={clearIn.map((a) => a > 0.02)}
				ZIndex={z + 2}
				Event={{
					Activated: clear,
					MouseEnter: () => setClearLit(true),
					MouseLeave: () => setClearLit(false),
					SelectionGained: () => setClearLit(true),
					SelectionLost: () => setClearLit(false),
				}}
			>
				<uicorner CornerRadius={new UDim(0, Radius.sm)} />
				<Icon
					kind="Close.9"
					color={Palette.creamSoft}
					accent={Palette.muted}
					size={14}
					spin={false}
					position={UDim2.fromScale(0.5, 0.5)}
					anchorPoint={new Vector2(0.5, 0.5)}
				/>
			</textbutton>
		</textbutton>
	);
}

/** @deprecated use SurfaceIconTile; ui.tsx IconTile is the glyph tile, this one is the bare framed square. */
export const IconTile = SurfaceIconTile;
/** @deprecated use SurfaceSectionLabel; ui.tsx SectionLabel is the page heading, this one is the small-caps list divider. */
export const SectionLabel = SurfaceSectionLabel;

import React from "@rbxts/react";
import { TooltipContent, labelFor, mergeEvents, useTooltip } from "../Tooltip";
import ReactRoblox from "@rbxts/react-roblox";
import { compactNumber } from "../CoreKit/format";
import { InteractionFeedback } from "../CoreKit/interaction";
import {
	Chrome,
	Layout,
	Elevation,
	Pad,
	Palette,
	StrokeWidth,
	TapTarget,
	chromeFor,
	contrastOn,
	darken,
	ensureContrast,
	lighten,
	strokeGradient,
	surfaceGradient,
} from "../CoreKit/theme";
import * as TouchGestureService from "../CoreKit/TouchGestureService";
import { Bindable, joinTuple } from "../lua";
import {
	ExitPresenceContext,
	MotionIntent,
	ScaleFromCenter,
	composePresence,
	useClock,
	useEntrance,
	useExitPresence,
	useFlash,
	useFlipperSpring,
	useGlowStroke,
	useMotionSettings,
	useOptionalFlipperSpring,
	usePulse,
	useRotation,
	useSpring,
	useSprScale,
	useViewport,
} from "../MotionKit/motion";
import * as ShimmerMath from "../MotionKit/shimmer";

const GuiService = game.GetService("GuiService");
const Players = game.GetService("Players");
const TextService = game.GetService("TextService");
const UserInputService = game.GetService("UserInputService");


// phones and touch-only tablets: true where small controls should get a 44px invisible hit area.
// Mouse desktops stay false, so nothing changes there.
function useTouchHitShell(): boolean {
	const stack = chromeFor(useViewport()).stack;
	return stack || (UserInputService.TouchEnabled && !UserInputService.MouseEnabled);
}

// ---------- unconverted sibling modules (Luau), loaded the way Luau loads them ----------
const AstralForge = script.Parent!.Parent!;
type LuaKit = (name: string) => unknown;
function kitMember<T>(kit: string, member: string): T {
	return (require(AstralForge.WaitForChild(kit) as ModuleScript) as LuaKit)(member) as T;
}

// Props for components that live in unconverted kits: loosely typed until those kits are ported.
export type LooseProps = { [key: string]: unknown; children?: React.ReactNode };
export type LooseComponent = (props: LooseProps) => React.ReactNode;

interface ArtIcon {
	WORDMARK_ASSET: string;
	COMPACT_MARK_ASSET: string;
	Icon: LooseComponent;
}
interface AudioApi {
	Audio: { play(cue: unknown, energy?: number): void };
	buttonAudioCue(this: void, text: string, icon?: unknown): string | false;
	hoverCueFor(this: void, sound: unknown): string;
}
interface RainbowApi {
	at(this: void, t: number): ColorSequence;
	family(this: void, color: Color3, t: number, depth: number): ColorSequence;
}
interface DebouncedCallback<A extends unknown[]> {
	run(this: void, ...args: A): void;
	flush(this: void): void;
	cancel(this: void): void;
}
interface ReactModules {
	useDebounceCallback<A extends unknown[]>(this: void, callback: (...args: A) => void, options: { wait: number }): DebouncedCallback<A>;
	useUpdateEffect(this: void, effect: () => void, deps: unknown[]): void;
	useUnmountEffect(this: void, effect: () => void): void;
	useEventListener<A extends unknown[]>(
		this: void,
		signal: RBXScriptSignal,
		listener: (...args: A) => void,
		options: { connected: boolean },
	): void;
}

const _Icon = kitMember<ArtIcon>("ArtKit", "Icon");
const WORDMARK_ASSET = _Icon.WORDMARK_ASSET;
const COMPACT_MARK_ASSET = _Icon.COMPACT_MARK_ASSET;
const Icon = _Icon.Icon;
const _audio = kitMember<AudioApi>("AudioKit", "audio");
const Audio = _audio.Audio;
const buttonAudioCue = _audio.buttonAudioCue;
const hoverCueFor = _audio.hoverCueFor;
const Rainbow = require(AstralForge.WaitForChild("Rainbow") as ModuleScript) as RainbowApi;
const classifyIntent = (MotionIntent as unknown as { classify(this: void, text: string): string | undefined }).classify;

// ---------- dropdown portal ----------
let dropdownPortal: Instance | undefined;
let dropdownPortalUsers = 0;
export function acquireDropdownPortal(): Instance {
	if (dropdownPortal === undefined || dropdownPortal.Parent === undefined) {
		const playerGui = Players.LocalPlayer.WaitForChild("PlayerGui");
		const vrScreen = playerGui.FindFirstChild("AstralForgeVR") as ScreenGui | undefined;
		const rootScreen =
			vrScreen && vrScreen.Enabled ? vrScreen.FindFirstChild("Content") : playerGui.FindFirstChild("AstralForgeStudioUI");
		if (rootScreen !== undefined) {
			dropdownPortal = rootScreen;
		} else {
			dropdownPortal = playerGui;
		}
	}
	dropdownPortalUsers += 1;
	return dropdownPortal;
}
export function releaseDropdownPortal() {
	dropdownPortalUsers = math.max(0, dropdownPortalUsers - 1);
	if (dropdownPortalUsers === 0) {
		dropdownPortal = undefined;
	}
}

// ---------- Stroke ----------
export interface StrokeProps {
	color: Bindable<Color3>;
	thickness?: Bindable<number>;
	transparency?: Bindable<number>;
}
export function Stroke({ color, thickness = 1, transparency = 0 }: StrokeProps) {
	const gradientColor = React.useMemo((): Bindable<ColorSequence> => {
		if (typeOf(color) === "Color3") {
			return strokeGradient(color as Color3);
		} else if (typeIs(color, "table") && typeIs((color as unknown as { map?: unknown }).map, "function")) {
			return (color as React.Binding<Color3>).map((value) => {
				if (typeOf(value) !== "Color3") {
					return strokeGradient(Palette.lineSoft);
				}
				return strokeGradient(value);
			});
		}
		return strokeGradient(Palette.lineSoft);
	}, [color]);
	return (
		<uistroke
			ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
			LineJoinMode={Enum.LineJoinMode.Round}
			Color={color}
			Thickness={thickness}
			Transparency={transparency}
		>
			<uigradient Rotation={90} Color={gradientColor} />
		</uistroke>
	);
}

// the readability floor every Text owns; callers asking for 8-10 px get this instead
const MIN_UI_TEXT_SIZE = 11;
const BUTTON_LABEL_SIZE = 15;
const buttonLabelWidthCache = new Map<string, number>();
let buttonLabelWidthCacheCount = 0;
function measureButtonLabel(label: string): number {
	const cached = buttonLabelWidthCache.get(label);
	if (cached !== undefined) {
		return cached;
	}
	const width = math.ceil(TextService.GetTextSize(label, BUTTON_LABEL_SIZE, Enum.Font.BuilderSansBold, new Vector2(2400, 48)).X) + 6;
	if (buttonLabelWidthCacheCount >= 256) {
		buttonLabelWidthCache.clear();
		buttonLabelWidthCacheCount = 0;
	}
	buttonLabelWidthCache.set(label, width);
	buttonLabelWidthCacheCount += 1;
	return width;
}
function buttonContentWidth(label: string, hasIcon: boolean): number {
	const textW = measureButtonLabel(label);
	return hasIcon ? 10 + 22 + 8 + textW + 10 : 10 + textW + 10;
}
function pinButtonLabel(instance: TextLabel | undefined) {
	if (instance !== undefined) {
		instance.Name = "ButtonLabel";
	}
}
function pinLayoutGuardIgnore(instance: Instance | undefined) {
	if (instance !== undefined) {
		instance.SetAttribute("LayoutGuardIgnore", true);
	}
}
const SHIMMER_GLINT = ShimmerMath.GLINT;
const SHIMMER_TRAIL = ShimmerMath.TRAIL;
const SHIMMER_SWEEP_SPEED = ShimmerMath.SWEEP_SPEED;
export const shimmerOffset = ShimmerMath.offset;

// ---------- input cancellation ----------
const inputCancelListeners = new Set<() => void>();
let inputCancelConnection: RBXScriptConnection | undefined;
let menuCancelConnection: RBXScriptConnection | undefined;
export function subscribeInputCancellation(listener: () => void): () => void {
	inputCancelListeners.add(listener);
	if (inputCancelConnection === undefined) {
		const cancelAll = () => {
			for (const cancel of inputCancelListeners) {
				cancel();
			}
		};
		inputCancelConnection = UserInputService.WindowFocusReleased.Connect(cancelAll);
		menuCancelConnection = GuiService.MenuOpened.Connect(cancelAll);
	}
	return () => {
		inputCancelListeners.delete(listener);
		if (inputCancelListeners.size() > 0) {
			return;
		}
		inputCancelConnection?.Disconnect();
		menuCancelConnection?.Disconnect();
		inputCancelConnection = undefined;
		menuCancelConnection = undefined;
	};
}

// ---------- gamepad autofocus ----------
function isValidSelectionTarget(object: Instance | undefined): object is GuiObject {
	if (object === undefined || !object.IsA("GuiObject") || object.Parent === undefined) {
		return false;
	}
	if (object.AbsoluteSize.X < 2 || object.AbsoluteSize.Y < 2) {
		return false;
	}
	const layer = object.FindFirstAncestorWhichIsA("LayerCollector");
	if (layer === undefined) {
		return false;
	}
	let current: Instance | undefined = object;
	while (current !== undefined && current !== layer) {
		if (current.IsA("GuiObject") && current.Visible === false) {
			return false;
		}
		current = current.Parent;
	}
	if (object.IsA("GuiButton") && (!object.Selectable || !object.Active)) {
		return false;
	}
	return true;
}
function assignSelectedObject(object: Instance | undefined) {
	if (!isValidSelectionTarget(object)) {
		return;
	}
	pcall(() => {
		GuiService.SelectedObject = object;
	});
}
function lastInputIsGamepad(): boolean {
	const inputType = UserInputService.GetLastInputType();
	return (
		inputType === Enum.UserInputType.Gamepad1 ||
		inputType === Enum.UserInputType.Gamepad2 ||
		inputType === Enum.UserInputType.Gamepad3 ||
		inputType === Enum.UserInputType.Gamepad4
	);
}
export function useGamepadAutofocus(active: boolean): React.MutableRefObject<GuiObject | undefined> {
	const rootRef = React.useRef<GuiObject>();
	React.useEffect(() => {
		if (!active || !lastInputIsGamepad()) {
			return undefined;
		}
		const previous = GuiService.SelectedObject;
		const worker = task.delay(0.16, () => {
			const root = rootRef.current;
			if (root === undefined) {
				return;
			}
			for (const child of root.GetDescendants()) {
				if (child.IsA("GuiButton") && isValidSelectionTarget(child)) {
					assignSelectedObject(child);
					return;
				}
			}
		});
		return () => {
			task.cancel(worker);
			if (isValidSelectionTarget(previous)) {
				assignSelectedObject(previous);
			}
		};
	}, [active]);
	return rootRef;
}

export const UiEffectsPausedContext = React.createContext(false);

function withExitFade(localFade: Bindable<number>, presence: React.Binding<number>): React.Binding<number> {
	if (typeIs(localFade, "number") && localFade === 0) {
		return presence.map((shown) => math.clamp(1 - shown, 0, 1));
	}
	if (typeIs(localFade, "number")) {
		return presence.map((shown) => math.clamp(localFade + (1 - shown), 0, 1));
	}
	return joinTuple<[number, number]>(localFade, presence).map((values) => math.clamp(values[0] + (1 - values[1]), 0, 1));
}

const fontFaceCache = new Map<Enum.Font, Font>();
function fontFaceFor(font: Enum.Font): Font {
	let face = fontFaceCache.get(font);
	if (face === undefined) {
		face = Font.fromEnum(font);
		fontFaceCache.set(font, face);
	}
	return face;
}

// ---------- Text ----------
export interface TextProps {
	value?: string;
	size?: number;
	color?: Bindable<Color3>;
	surface?: Color3;
	weight?: Enum.FontWeight;
	align?: Enum.TextXAlignment;
	fit?: boolean;
	wrap?: boolean;
	minSize?: number;
	position?: Bindable<UDim2>;
	sizeConstraint?: UDim2;
	zIndex?: number;
	layoutOrder?: number;
	transparency?: Bindable<number>;
	autoWidth?: boolean;
	shadow?: boolean;
}
export function Text(props: TextProps) {
	const {
		value,
		size = 16,
		color = Palette.cream,
		surface,
		weight = Enum.FontWeight.Medium,
		align = Enum.TextXAlignment.Left,
		fit = false,
		wrap = false,
		minSize,
		position,
		sizeConstraint,
		zIndex = 1,
		layoutOrder = 0,
		transparency = 0,
	} = props;
	const settings = useMotionSettings();
	const textScale = settings.textScale;
	const boldText = settings.boldText ?? 0;
	const presence = useExitPresence();
	const faded = React.useMemo(() => withExitFade(transparency, presence), [transparency, presence]);
	let scaledSize = math.clamp(math.floor(size * textScale + 0.5), MIN_UI_TEXT_SIZE, 42);
	// a larger text setting must never push a single line out of its own box
	if (!wrap && sizeConstraint !== undefined && sizeConstraint.Y.Scale === 0 && sizeConstraint.Y.Offset > 0) {
		scaledSize = math.max(8, math.min(scaledSize, sizeConstraint.Y.Offset));
	}
	const font =
		weight === Enum.FontWeight.Heavy
			? Enum.Font.BuilderSansExtraBold
			: weight === Enum.FontWeight.Bold || boldText >= 0.5
				? Enum.Font.BuilderSansBold
				: Enum.Font.BuilderSansMedium;
	const painted = surface !== undefined && typeOf(color) === "Color3" ? ensureContrast(surface, color as Color3) : color;
	let constraint: React.Element | false = false;
	if (fit) {
		const floorSize = minSize ?? math.max(12, size * 0.85);
		constraint = (
			<uitextsizeconstraint
				MinTextSize={math.clamp(math.floor(floorSize * textScale), math.min(12, scaledSize), scaledSize)}
				MaxTextSize={scaledSize}
			/>
		);
	}
	// autoWidth: the box is as wide as its text (for a title with a badge right after it in a row)
	const autoWidth = props.autoWidth === true && !wrap;
	const faceSize = autoWidth ? UDim2.fromScale(0, 1) : UDim2.fromScale(1, 1);
	const faceAutomaticSize = autoWidth ? Enum.AutomaticSize.X : undefined;
	const faceScaled = autoWidth ? false : fit;
	const fontFace = fontFaceFor(font);
	// phones: a single-line label in a bounded box ends with an ellipsis instead of spilling past it
	const phoneShell = chromeFor(useViewport()).stack;
	const truncate =
		phoneShell && !wrap && !faceScaled && !autoWidth && sizeConstraint !== undefined &&
		(sizeConstraint.X.Scale > 0 || sizeConstraint.X.Offset > 0)
			? Enum.TextTruncate.AtEnd
			: Enum.TextTruncate.None;
	const yAlign = wrap ? Enum.TextYAlignment.Top : Enum.TextYAlignment.Center;
	const lineHeight = wrap ? 1.12 : 1;
	if (autoWidth) {
		constraint = false;
	}
	return (
		<frame
			Size={
				autoWidth
					? new UDim2(0, 0, sizeConstraint ? sizeConstraint.Y.Scale : 1, sizeConstraint ? sizeConstraint.Y.Offset : 0)
					: sizeConstraint ?? UDim2.fromScale(1, 1)
			}
			AutomaticSize={autoWidth ? Enum.AutomaticSize.X : undefined}
			Position={position}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={zIndex}
			LayoutOrder={layoutOrder}
		>
			{props.shadow !== false && (
				<textlabel
					{...{ Name: "TextShadow" }}
					Size={faceSize}
					AutomaticSize={faceAutomaticSize}
					Position={UDim2.fromOffset(0, 1)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					AutoLocalize={true}
					Text={value}
					TextColor3={Palette.void}
					TextSize={scaledSize}
					TextTransparency={faded.map((v) => 0.78 + v * 0.22)}
					FontFace={fontFace}
					TextXAlignment={align}
					TextYAlignment={yAlign}
					TextWrapped={wrap}
					TextScaled={faceScaled}
					LineHeight={lineHeight}
					TextTruncate={truncate}
					ZIndex={zIndex}
					ref={(label: TextLabel | undefined) => {
						if (label) {
							label.SetAttribute("LayoutGuardIgnore", true);
						}
					}}
				>
					{constraint}
				</textlabel>
			)}
			<textlabel
				Size={faceSize}
				AutomaticSize={faceAutomaticSize}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				AutoLocalize={true}
				Text={value}
				TextColor3={painted}
				TextSize={scaledSize}
				TextTransparency={faded}
				FontFace={fontFace}
				TextXAlignment={align}
				TextYAlignment={yAlign}
				TextWrapped={wrap}
				TextScaled={faceScaled}
				LineHeight={lineHeight}
				TextTruncate={truncate}
				ZIndex={zIndex + 1}
			>
				{constraint}
			</textlabel>
		</frame>
	);
}

export function useGuiSize(ref: React.RefObject<Instance>, useParent?: boolean): React.Binding<Vector2> {
	const [size, setSize] = React.useBinding(Vector2.zero);
	React.useEffect(() => {
		const node = ref.current;
		const host = node !== undefined && useParent ? node.Parent : node;
		if (host === undefined || !host.IsA("GuiObject")) {
			return undefined;
		}
		const update = () => {
			setSize(host.AbsoluteSize);
		};
		update();
		const connection = host.GetPropertyChangedSignal("AbsoluteSize").Connect(update);
		return () => {
			connection.Disconnect();
		};
	}, [ref, useParent]);
	return size;
}

export function pixelPosition(size: Vector2, xScale: number, xPixels: number, yScale: number, yPixels: number): UDim2 {
	// UDim offsets are integers; scale coordinates retain fractional pixel travel.
	if (size.X <= 0 || size.Y <= 0) {
		return new UDim2(xScale, xPixels, yScale, yPixels);
	}
	return UDim2.fromScale(xScale + xPixels / size.X, yScale + yPixels / size.Y);
}

function fontForWeight(weight: Enum.FontWeight): Enum.Font {
	return weight === Enum.FontWeight.Heavy
		? Enum.Font.BuilderSansExtraBold
		: weight === Enum.FontWeight.Bold
			? Enum.Font.BuilderSansBold
			: Enum.Font.BuilderSansMedium;
}
const WRAPPED_LINE_HEIGHT = 1.12;
export function measureWrappedTextHeight(text: unknown, width: unknown, size = 16, weight: Enum.FontWeight = Enum.FontWeight.Medium): number {
	if (!typeIs(text, "string") || text === "" || !typeIs(width, "number") || width <= 0) {
		return 0;
	}
	const font = fontForWeight(weight);
	const bounds = TextService.GetTextSize(text, math.max(1, math.floor(size)), font, new Vector2(math.max(1, math.floor(width)), 4000));
	return math.ceil(bounds.Y * WRAPPED_LINE_HEIGHT);
}

export interface AutoHeightTextProps {
	value?: string;
	width?: number;
	size?: number;
	color?: Bindable<Color3>;
	weight?: Enum.FontWeight;
	align?: Enum.TextXAlignment;
	position?: Bindable<UDim2>;
	minHeight?: number;
	maxHeight?: number;
	onHeightChange?: (height: number) => void;
	zIndex?: number;
	layoutOrder?: number;
	transparency?: Bindable<number>;
}
export function AutoHeightText({
	value,
	width,
	size = 13,
	color = Palette.creamSoft,
	weight = Enum.FontWeight.Medium,
	align = Enum.TextXAlignment.Left,
	position,
	minHeight = 0,
	maxHeight,
	onHeightChange,
	zIndex = 1,
	layoutOrder = 0,
	transparency = 0,
}: AutoHeightTextProps) {
	const settings = useMotionSettings();
	const textScale = settings.textScale;
	const boldText = settings.boldText ?? 0;
	const scaledSize = math.clamp(math.floor(size * textScale + 0.5), MIN_UI_TEXT_SIZE, 42);
	const font = fontForWeight(weight === Enum.FontWeight.Bold && boldText >= 0.5 ? Enum.FontWeight.Bold : weight);
	const safeValue = typeIs(value, "string") ? value : "";
	const safeWidth = typeIs(width, "number") && width === width ? width : 0;
	const measured =
		safeValue === ""
			? 0
			: math.ceil(
					TextService.GetTextSize(safeValue, scaledSize, font, new Vector2(math.max(1, math.floor(safeWidth)), 4000)).Y *
						WRAPPED_LINE_HEIGHT,
				);
	const clamped = math.max(minHeight, maxHeight !== undefined ? math.min(maxHeight, measured) : measured);
	const lastReported = React.useRef<number>();
	const lastReportedTo = React.useRef<(height: number) => void>();
	React.useEffect(() => {
		if (onHeightChange === undefined) {
			return;
		}
		if (lastReported.current === clamped && lastReportedTo.current === onHeightChange) {
			return;
		}
		lastReported.current = clamped;
		lastReportedTo.current = onHeightChange;
		onHeightChange(clamped);
	}, [clamped, onHeightChange]);
	return (
		<textlabel
			Size={new UDim2(0, safeWidth, 0, clamped)}
			Position={position}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			AutoLocalize={true}
			Text={safeValue}
			TextColor3={color}
			TextSize={scaledSize}
			TextTransparency={transparency}
			FontFace={Font.fromEnum(font)}
			TextXAlignment={align}
			TextYAlignment={Enum.TextYAlignment.Top}
			TextWrapped={true}
			LineHeight={1.12}
			TextTruncate={Enum.TextTruncate.None}
			ZIndex={zIndex}
			LayoutOrder={layoutOrder}
		/>
	);
}

export function OverlayPresence({ amount, children }: { amount: React.Binding<number>; children?: React.ReactNode }) {
	return <ExitPresenceContext.Provider value={amount}>{children}</ExitPresenceContext.Provider>;
}

export interface ShimmerTextProps {
	value?: string;
	size?: number;
	color?: Color3;
	weight?: Enum.FontWeight;
	align?: Enum.TextXAlignment;
	fit?: boolean;
	minSize?: number;
	position?: Bindable<UDim2>;
	sizeConstraint?: UDim2;
	zIndex?: number;
	layoutOrder?: number;
	reducedMotion?: boolean;
	enabled?: boolean;
	periodSeconds?: number;
}
export function ShimmerText({
	value,
	size = 22,
	color = Palette.cream,
	weight = Enum.FontWeight.Heavy,
	align = Enum.TextXAlignment.Left,
	fit = false,
	minSize,
	position,
	sizeConstraint,
	zIndex = 1,
	layoutOrder = 0,
	reducedMotion = false,
	enabled = false,
	periodSeconds = 3.6,
}: ShimmerTextProps) {
	const effectsPaused = React.useContext(UiEffectsPausedContext);
	const settings = useMotionSettings();
	const textScale = settings.textScale;
	const shimmerScale = settings.shimmerScale ?? 1;
	const want = enabled && !reducedMotion && !effectsPaused && shimmerScale > 0.02;
	const speed = (1 / math.max(1.2, periodSeconds)) * math.clamp(0.45 + shimmerScale * 0.55, 0.45, 1);
	const phase = useClock(want, speed, 1, false);
	const scaledSize = math.clamp(math.floor(size * textScale + 0.5), MIN_UI_TEXT_SIZE, 42);
	const font =
		weight === Enum.FontWeight.Heavy
			? Enum.Font.BuilderSansExtraBold
			: weight === Enum.FontWeight.Bold
				? Enum.Font.BuilderSansBold
				: Enum.Font.BuilderSansMedium;
	const glintColor = new ColorSequence([
		new ColorSequenceKeypoint(0, color),
		new ColorSequenceKeypoint(0.5, color.Lerp(Palette.white, 0.7)),
		new ColorSequenceKeypoint(1, color),
	]);
	let glint: React.Element | false = false;
	if (want) {
		const floorSize = minSize !== undefined ? minSize : MIN_UI_TEXT_SIZE;
		const minText = math.clamp(math.floor(floorSize * textScale + 0.5), MIN_UI_TEXT_SIZE, scaledSize);
		glint = (
			<textlabel
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				Active={false}
				Selectable={false}
				AutoLocalize={true}
				Text={value}
				TextColor3={Palette.cream}
				TextTransparency={math.clamp(1 - shimmerScale * 0.55, 0.35, 0.82)}
				TextSize={scaledSize}
				FontFace={Font.fromEnum(font)}
				TextXAlignment={align}
				TextYAlignment={Enum.TextYAlignment.Center}
				TextScaled={true}
				TextTruncate={Enum.TextTruncate.None}
				ZIndex={zIndex + 1}
			>
				<uitextsizeconstraint MinTextSize={minText} MaxTextSize={scaledSize} />
				<uigradient
					Color={glintColor}
					Transparency={SHIMMER_GLINT}
					Offset={phase.map((amount) => shimmerOffset(amount, 2.05))}
					Rotation={ShimmerMath.ROTATION}
				/>
			</textlabel>
		);
	}
	return (
		<frame
			Size={sizeConstraint ?? UDim2.fromScale(1, 1)}
			Position={position}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			Active={false}
			ZIndex={zIndex}
			LayoutOrder={layoutOrder}
			ClipsDescendants={true}
			AutomaticSize={Enum.AutomaticSize.None}
		>
			<Text
				value={value}
				size={size}
				color={color}
				weight={weight}
				align={align}
				fit={fit}
				minSize={minSize}
				sizeConstraint={UDim2.fromScale(1, 1)}
				zIndex={zIndex}
			/>
			{glint}
		</frame>
	);
}

export function SectionLabel({
	value,
	color = Palette.muted,
	layoutOrder = 0,
	position,
}: {
	value?: string;
	color?: Color3;
	layoutOrder?: number;
	position?: UDim2;
}) {
	const labelColor = ensureContrast(Palette.night, color);
	return (
		<frame Size={new UDim2(1, 0, 0, 22)} Position={position} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={layoutOrder}>
			<frame
				Size={UDim2.fromOffset(22, StrokeWidth.focus)}
				Position={new UDim2(0, 0, 0.5, 0)}
				AnchorPoint={new Vector2(0, 0.5)}
				BackgroundColor3={color}
				BackgroundTransparency={Chrome.accentHairline}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uigradient
					Transparency={
						new NumberSequence([
							new NumberSequenceKeypoint(0, 0.04),
							new NumberSequenceKeypoint(0.68, 0.18),
							new NumberSequenceKeypoint(1, 1),
						])
					}
				/>
			</frame>
			<Text
				value={value}
				size={14}
				color={labelColor}
				weight={Enum.FontWeight.Heavy}
				fit={false}
				position={UDim2.fromOffset(30, 0)}
				sizeConstraint={new UDim2(1, -38, 0, 22)}
			/>
		</frame>
	);
}

export function QuantityStepper(props: {
	label?: string;
	detail?: string;
	value?: number;
	max?: number;
	accent?: Color3;
	reducedMotion?: boolean;
	onChange: (value: number) => void;
	layoutOrder?: number;
}) {
	const { label, detail, accent = Palette.mint, reducedMotion = false, onChange, layoutOrder = 0 } = props;
	const max = typeIs(props.max, "number") && props.max === props.max ? math.max(0, props.max) : 0;
	const value = typeIs(props.value, "number") && props.value === props.value ? math.clamp(props.value, 0, max) : 0;
	const viewport = useViewport();
	const [narrow, setNarrow] = React.useState(false);
	const stacked = viewport.width < 560 || viewport.height < 420 || narrow;
	const step = max >= 100000 ? math.max(1, math.floor(max / 20)) : max >= 100 ? math.max(1, math.floor(max / 10)) : 1;
	const atMin = value <= 0;
	const atMax = value >= max || max <= 0;
	const controlH = stacked ? TapTarget : 36;
	const detailText = detail ?? (max <= 0 ? "None tradable" : `${compactNumber(value)} / ${compactNumber(max)}`);
	return (
		<frame
			Size={new UDim2(1, 0, 0, stacked ? 108 : 52)}
			BackgroundColor3={Palette.panelRaised}
			BorderSizePixel={0}
			LayoutOrder={layoutOrder}
			ClipsDescendants={false}
			Change={{
				AbsoluteSize: (instance) => {
					if (instance.AbsoluteSize.X > 0) {
						setNarrow(instance.AbsoluteSize.X < 360);
					}
				},
			}}
		>
			<uicorner CornerRadius={new UDim(0, 10)} />
			<Stroke color={value > 0 ? accent : Palette.lineSoft} thickness={1} transparency={value > 0 ? 0.28 : 0.55} />
			<Text
				value={label}
				size={13}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(12, 6)}
				sizeConstraint={new UDim2(1, stacked ? -16 : -220, 0, 18)}
			/>
			<Text
				value={detailText}
				size={12}
				color={value > 0 ? accent : Palette.muted}
				weight={Enum.FontWeight.Bold}
				position={UDim2.fromOffset(12, 26)}
				sizeConstraint={new UDim2(1, stacked ? -16 : -220, 0, 16)}
			/>
			<frame
				Size={stacked ? new UDim2(1, -16, 0, controlH) : UDim2.fromOffset(204, controlH)}
				Position={stacked ? new UDim2(0, 8, 1, -(controlH + 8)) : new UDim2(1, -212, 0.5, -18)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
			>
				<Button
					text="-"
					onClick={() => onChange(math.max(0, value - step))}
					color={Palette.panelSoft}
					textColor={Palette.cream}
					size={new UDim2(stacked ? 0.22 : 0, stacked ? -4 : 36, 1, 0)}
					disabled={atMin}
					reducedMotion={reducedMotion}
				/>
				<Text
					value={compactNumber(value)}
					size={15}
					color={Palette.cream}
					weight={Enum.FontWeight.Heavy}
					align={Enum.TextXAlignment.Center}
					position={stacked ? new UDim2(0.22, 0, 0, 0) : UDim2.fromOffset(36, 0)}
					sizeConstraint={stacked ? new UDim2(0.28, 0, 1, 0) : UDim2.fromOffset(56, 36)}
				/>
				<Button
					text="+"
					onClick={() => onChange(math.min(max, value + step))}
					color={accent}
					textColor={accent}
					outline={true}
					size={stacked ? new UDim2(0.22, -4, 1, 0) : UDim2.fromOffset(36, 36)}
					position={stacked ? new UDim2(0.5, 2, 0, 0) : UDim2.fromOffset(96, 0)}
					disabled={atMax}
					reducedMotion={reducedMotion}
				/>
				<Button
					text="MAX"
					onClick={() => onChange(max)}
					color={Palette.panelRaised}
					textColor={accent}
					outline={true}
					size={stacked ? new UDim2(0.28, -4, 1, 0) : UDim2.fromOffset(64, 36)}
					position={stacked ? new UDim2(0.72, 2, 0, 0) : UDim2.fromOffset(136, 0)}
					disabled={atMax}
					reducedMotion={reducedMotion}
				/>
			</frame>
		</frame>
	);
}

export const SCROLL_EDGE = 18;
export function ScrollEdgeFade({ color = Palette.ink, height = SCROLL_EDGE, zIndex = 200 }: { color?: Color3; height?: number; zIndex?: number }) {
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={zIndex} Active={false}>
			<frame
				Size={new UDim2(1, 0, 0, height)}
				Position={UDim2.fromOffset(0, 0)}
				BackgroundColor3={color}
				BorderSizePixel={0}
				ZIndex={zIndex}
				Active={false}
			>
				<uigradient
					Rotation={90}
					Transparency={
						new NumberSequence([
							new NumberSequenceKeypoint(0, 0.68),
							new NumberSequenceKeypoint(0.55, 0.9),
							new NumberSequenceKeypoint(1, 1),
						])
					}
				/>
			</frame>
			<frame
				Size={new UDim2(1, 0, 0, height)}
				Position={new UDim2(0, 0, 1, -height)}
				BackgroundColor3={color}
				BorderSizePixel={0}
				ZIndex={zIndex}
				Active={false}
			>
				<uigradient
					Rotation={90}
					Transparency={
						new NumberSequence([
							new NumberSequenceKeypoint(0, 1),
							new NumberSequenceKeypoint(0.45, 0.9),
							new NumberSequenceKeypoint(1, 0.68),
						])
					}
				/>
			</frame>
		</frame>
	);
}

export function SweptRing(props: {
	scale: number;
	color: Bindable<Color3>;
	thickness: number;
	spin: React.Binding<number>;
	sweepWidth?: number;
}) {
	const { scale, color, thickness, spin } = props;
	const sweepWidth = math.clamp(props.sweepWidth ?? 0.22, 0.02, 0.9);
	const gradientRotation = spin.map((degrees) => degrees);
	const keypoints = [
		new NumberSequenceKeypoint(0, 1),
		new NumberSequenceKeypoint(math.max(0.001, sweepWidth * 0.5), 0.15),
		new NumberSequenceKeypoint(sweepWidth, 1),
		new NumberSequenceKeypoint(1, 1),
	];
	return (
		<frame
			Size={UDim2.fromScale(scale, scale)}
			Position={UDim2.fromScale(0.5, 0.5)}
			AnchorPoint={new Vector2(0.5, 0.5)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
		>
			<uicorner CornerRadius={new UDim(1, 0)} />
			<uistroke
				Color={color}
				Thickness={thickness}
				Transparency={0.55}
				ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
				LineJoinMode={Enum.LineJoinMode.Round}
			/>
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} Rotation={gradientRotation}>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke
					Color={color}
					Thickness={thickness + 0.5}
					Transparency={0}
					ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
					LineJoinMode={Enum.LineJoinMode.Round}
				>
					<uigradient Transparency={new NumberSequence(keypoints)} Rotation={90} />
				</uistroke>
			</frame>
		</frame>
	);
}

export function OrbitDot({
	radiusScale,
	angleDeg,
	size,
	color,
	glow = false,
	zIndex = 3,
}: {
	radiusScale: number;
	angleDeg: number;
	size: number;
	color: Color3;
	glow?: boolean;
	zIndex?: number;
}) {
	const rad = math.rad(angleDeg);
	return (
		<frame
			Size={UDim2.fromOffset(size, size)}
			Position={UDim2.fromScale(0.5 + math.cos(rad) * radiusScale, 0.5 + math.sin(rad) * radiusScale)}
			AnchorPoint={new Vector2(0.5, 0.5)}
			BackgroundColor3={color}
			BorderSizePixel={0}
			ZIndex={zIndex}
		>
			<uicorner CornerRadius={new UDim(1, 0)} />
			{glow && (
				<frame
					Size={UDim2.fromScale(2.2, 2.2)}
					Position={UDim2.fromScale(0.5, 0.5)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundColor3={color}
					BackgroundTransparency={0.72}
					BorderSizePixel={0}
					ZIndex={zIndex - 1}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</frame>
			)}
		</frame>
	);
}

export function ScrollPads({ edge = SCROLL_EDGE }: { edge?: number }) {
	return (
		<>
			<frame Size={new UDim2(1, 0, 0, edge)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={-100000} />
			<frame Size={new UDim2(1, 0, 0, edge)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={100000} />
		</>
	);
}

export interface IconTileProps {
	kind?: unknown;
	accent?: Color3;
	size?: number;
	radius?: number;
	position?: Bindable<UDim2>;
	anchorPoint?: Vector2;
	spin?: boolean;
	hoverAmount?: React.Binding<number>;
	reducedMotion?: boolean;
	glow?: boolean;
	filled?: boolean;
	zIndex?: number;
}
export function IconTile({
	kind,
	accent = Palette.cyan,
	size = 48,
	radius,
	position,
	anchorPoint,
	spin = false,
	hoverAmount,
	reducedMotion = false,
	glow = false,
	filled = false,
	zIndex = 1,
}: IconTileProps) {
	const effectsPaused = React.useContext(UiEffectsPausedContext);
	const interactionMotion = reducedMotion || effectsPaused;
	const background = filled ? darken(accent, 0.22) : darken(accent, 0.42).Lerp(Palette.panelSoft, 0.28);
	const glyph = Palette.cream;
	const strokeTransparency = useGlowStroke(glow && !interactionMotion, interactionMotion, 0.55, 0.2, 0.62, 2.1);
	const corner = radius ?? math.floor(size * 0.26);
	const inset = 2;
	const inner = math.max(12, size - inset * 2);
	return (
		<frame
			Size={UDim2.fromOffset(size, size)}
			Position={position}
			AnchorPoint={anchorPoint}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={zIndex}
			ClipsDescendants={false}
		>
			<frame
				Size={UDim2.fromOffset(inner, inner)}
				Position={UDim2.fromOffset(inset, inset)}
				BackgroundColor3={background}
				BorderSizePixel={0}
				ClipsDescendants={true}
			>
				<uicorner CornerRadius={new UDim(0, math.max(1, corner - 1))} />
				<uigradient Color={surfaceGradient(background, 0.62)} Rotation={90} />
				<Icon
					kind={kind}
					color={glyph}
					accent={accent}
					size={inner}
					spin={spin}
					hoverAmount={hoverAmount}
					clipSafe={true}
					reducedMotion={reducedMotion}
					position={UDim2.fromScale(0.5, 0.5)}
					anchorPoint={new Vector2(0.5, 0.5)}
				/>
			</frame>
			<frame
				Size={UDim2.fromOffset(inner, inner)}
				Position={UDim2.fromOffset(inset, inset)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ZIndex={zIndex + 1}
				ClipsDescendants={false}
			>
				<uicorner CornerRadius={new UDim(0, math.max(1, corner - 1))} />
				<Stroke color={accent} thickness={1} transparency={glow ? strokeTransparency : filled ? 0.28 : 0.4} />
			</frame>
		</frame>
	);
}

export function Badge(props: {
	value?: unknown;
	accent?: Color3;
	filled?: boolean;
	position?: Bindable<UDim2>;
	size?: UDim2;
	zIndex?: number;
}) {
	let value = props.value;
	if (!typeIs(value, "string")) {
		value = value === undefined ? "" : tostring(value);
	}
	const text = value as string;
	const { accent = Palette.cyan, filled = false, position, size = UDim2.fromOffset(78, 26), zIndex = 3 } = props;
	const fill = filled ? darken(accent, 0.28) : Palette.panelRaised;
	const label = ensureContrast(fill, filled ? Palette.cream : lighten(accent, 0.18));
	const compressLabel = text.size() > 7;
	return (
		<frame
			Size={size}
			Position={position}
			BackgroundColor3={fill}
			BackgroundTransparency={filled ? 0 : 0.04}
			BorderSizePixel={0}
			ZIndex={zIndex}
			ClipsDescendants={false}
		>
			<uicorner CornerRadius={new UDim(0, 6)} />
			<uigradient Color={surfaceGradient(fill, 0.55)} Rotation={90} />
			<frame Size={new UDim2(1, -2, 1, -2)} Position={UDim2.fromOffset(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={zIndex}>
				<uicorner CornerRadius={new UDim(0, 5)} />
				<Stroke color={accent} thickness={1} transparency={filled ? 0.36 : 0.28} />
			</frame>
			{filled && (
				<frame
					Size={new UDim2(0.38, 0, 0, 2)}
					Position={UDim2.fromOffset(8, 0)}
					BackgroundColor3={accent}
					BorderSizePixel={0}
					ZIndex={zIndex + 1}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
					<uigradient Transparency={new NumberSequence([new NumberSequenceKeypoint(0, 0.04), new NumberSequenceKeypoint(1, 1)])} />
				</frame>
			)}
			{/* badges are small: the label always fits inside the box (the global text floor would push it out) */}
			<textlabel
				Size={new UDim2(1, -10, 1, -4)}
				Position={UDim2.fromOffset(5, 2)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				Text={text}
				TextColor3={label}
				TextScaled={true}
				TextWrapped={false}
				FontFace={Font.fromEnum(compressLabel ? Enum.Font.BuilderSansBold : Enum.Font.BuilderSansExtraBold)}
				ZIndex={zIndex + 1}
			>
				<uitextsizeconstraint MaxTextSize={13} MinTextSize={7} />
			</textlabel>
		</frame>
	);
}

export function CountBadge(props: { count?: unknown; zIndex?: number; compact?: boolean; position?: UDim2; anchorPoint?: Vector2 }) {
	const { count, zIndex = 50, compact = false } = props;
	const effectsPaused = React.useContext(UiEffectsPausedContext);
	const scaleRef = useSprScale(1, effectsPaused, 0.68, 0.64, 13);
	const whole = typeIs(count, "number") && count === count ? math.floor(count) : 0;
	// a hop and three soft pings when the count goes up, then it sits still
	const [bumps, setBumps] = React.useState(0);
	const [pinging, setPinging] = React.useState(false);
	const lastCount = React.useRef(whole);
	React.useEffect(() => {
		if (whole > lastCount.current) {
			setBumps((n) => n + 1);
			setPinging(true);
		}
		lastCount.current = whole;
	}, [whole]);
	React.useEffect(() => {
		if (!pinging) {
			return undefined;
		}
		const job = task.delay(3, () => {
			setPinging(false);
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [pinging, bumps]);
	const hop = useFlash(bumps, effectsPaused, 0.45);
	const ping = useClock(pinging && whole > 0 && !effectsPaused, 0.45, 1);
	if (whole <= 0) {
		return <frame Size={UDim2.fromOffset(0, 0)} BackgroundTransparency={1} BorderSizePixel={0} />;
	}
	const label = whole > 99 ? "99+" : tostring(whole);
	const wide = whole >= 10;
	let size = compact ? (wide ? 16 : 14) : wide ? 20 : 16;
	if (whole > 99) {
		size += 4;
	}
	return (
		<frame
			Size={UDim2.fromOffset(size, size)}
			Position={props.position ?? new UDim2(1, compact ? -2 : -3, 0, compact ? 2 : 3)}
			AnchorPoint={props.anchorPoint ?? new Vector2(1, 0)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={zIndex}
			ClipsDescendants={false}
		>
			<frame
				Visible={pinging}
				Size={ping.map((t) => {
					const s = 1 + t * 1.2;
					return UDim2.fromScale(s, s);
				})}
				Position={UDim2.fromScale(0.5, 0.5)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundTransparency={1}
				ZIndex={zIndex}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke Color={Palette.coral} Thickness={1.5} Transparency={ping.map((t) => 0.35 + t * 0.65)} />
			</frame>
			<ScaleFromCenter scaleRef={scaleRef} zIndex={zIndex}>
				<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.coral} BorderSizePixel={0} ZIndex={zIndex} ClipsDescendants={false}>
					<uiscale Scale={hop.map((v) => 1 + v * 0.35)} />
					<uicorner CornerRadius={new UDim(1, 0)} />
					<Stroke color={Palette.cream} thickness={1} transparency={0.55} />
					<textlabel
						Size={new UDim2(1, 0, 1, -1)}
						Position={UDim2.fromOffset(0, 1)}
						BackgroundTransparency={1}
						BorderSizePixel={0}
						Text={label}
						// dark or light, whichever reads on the badge (the colour-safe palette turns it gold)
						TextColor3={contrastOn(Palette.coral)}
						TextSize={MIN_UI_TEXT_SIZE}
						FontFace={Font.fromEnum(Enum.Font.BuilderSansBold)}
						TextXAlignment={Enum.TextXAlignment.Center}
						TextYAlignment={Enum.TextYAlignment.Center}
						TextScaled={true}
						TextWrapped={false}
						ZIndex={zIndex + 1}
					>
						<uitextsizeconstraint MinTextSize={8} MaxTextSize={MIN_UI_TEXT_SIZE} />
					</textlabel>
				</frame>
			</ScaleFromCenter>
		</frame>
	);
}

// ---------- Panel ----------
export interface PanelProps {
	children?: React.ReactNode;
	size?: Bindable<UDim2>;
	position?: Bindable<UDim2>;
	accent?: Color3;
	background?: Color3;
	radius?: number;
	padding?: number;
	zIndex?: number;
	stroke?: boolean;
	layoutOrder?: number;
	clips?: boolean;
	reveal?: React.Binding<number>;
	interactive?: boolean;
	shimmer?: boolean;
	highlight?: boolean;
	reducedMotion?: boolean;
}
export function Panel(props: PanelProps) {
	const {
		children,
		size,
		position,
		accent,
		background = Palette.panel,
		radius = Layout.cardRadius,
		zIndex = 1,
		stroke = true,
		layoutOrder = 0,
		clips = false,
		reveal,
		interactive = false,
		shimmer = false,
		highlight = false,
		reducedMotion = false,
	} = props;
	let padding = props.padding;
	if (padding === undefined) {
		padding = Pad.panel;
	} else if (padding > Pad.panelMax) {
		padding = Pad.panelMax;
	}
	const [hovered, setHovered] = React.useState(false);
	const [hoverArmed, setHoverArmed] = React.useState(false);
	const panelRef = React.useRef<Frame>();
	const panelSize = useGuiSize(panelRef);
	const effectsPaused = React.useContext(UiEffectsPausedContext);
	const settings = useMotionSettings();
	const panelHoverScale = settings.panelHoverScale ?? 1;
	const reducedTransparency = settings.reducedTransparency === true;
	const panelEntranceScale = settings.panelEntranceScale ?? 1;
	const shimmerScale = settings.shimmerScale ?? 1;
	const interactionMotion = reducedMotion || effectsPaused;
	const entranceMotion = interactionMotion || panelEntranceScale <= 0.02 || reveal !== undefined;
	const automaticReveal = useFlipperSpring(
		1,
		entranceMotion,
		620,
		48,
		reveal !== undefined || effectsPaused || panelEntranceScale <= 0.02 ? 1 : 0,
	);
	const activeReveal = reveal ?? automaticReveal;
	const parentPresence = useExitPresence();
	const contentPresence = React.useMemo(() => composePresence(parentPresence, activeReveal), [parentPresence, activeReveal]);
	React.useEffect(() => {
		if (hovered) {
			setHoverArmed(true);
		}
	}, [hovered]);
	const lift = useOptionalFlipperSpring(
		interactive && hovered && !effectsPaused && panelHoverScale > 0.02 ? panelHoverScale : 0,
		interactive && hoverArmed,
		interactionMotion,
		480,
		38,
	);
	const accentColor = accent ?? Palette.lineSoft;
	const highlightOn = useOptionalFlipperSpring(highlight && !effectsPaused ? 1 : 0, highlight, interactionMotion, 420, 36);
	const shimmerWanted = shimmer && interactive && shimmerScale > 0.02 && !effectsPaused;
	const whiteSweep = useClock(shimmerWanted && hovered, SHIMMER_SWEEP_SPEED, 1, false);
	const glowWanted = interactive && accent !== undefined && !interactionMotion;

	const hoverGlow = useOptionalFlipperSpring(glowWanted && hovered ? 1 : 0, interactive && hoverArmed, interactionMotion, 460, 38);
	const revealFade = React.useMemo(() => activeReveal.map((amount) => 1 - math.clamp(amount, 0, 1)), [activeReveal]);
	const strokeTransparency = React.useMemo(() => {
		const live = joinTuple<[number, number]>(lift, highlightOn).map((values) => {
			const hover = values[0];
			const lit = values[1];
			return math.clamp(Chrome.panelStrokeIdle - hover * 0.14 - lit * 0.18, Chrome.panelStrokeHover, 0.72);
		});
		return joinTuple<[number, number]>(live, revealFade).map((values) => math.clamp(values[0] + values[1], 0, 1));
	}, [highlightOn, lift, revealFade]);
	const surfaceTransparency = reducedTransparency ? 0 : revealFade;
	const paintChrome = true;
	const derived = React.useMemo(() => {
		const liftPx = lift.map((amount) => -amount);
		const revealY = activeReveal.map((amount) => (1 - math.clamp(amount, 0, 1)) * 10);
		const surfaceY = joinTuple<[number, number]>(liftPx, revealY).map((values) => values[0] + values[1]);
		return {
			strokeColor: highlightOn.map((amount) => {
				const base = accent !== undefined ? accent.Lerp(Palette.lineSoft, 0.55) : Palette.lineSoft;
				return amount >= 0.45 ? accentColor : base;
			}),
			shadowPosition: joinTuple<[number, Vector2]>(surfaceY, panelSize).map((values) => pixelPosition(values[1], 0, -4, 0, 7 + values[0])),
			surfacePosition: joinTuple<[number, Vector2]>(surfaceY, panelSize).map((values) => pixelPosition(values[1], 0, 0, 0, values[0])),
			shadowTransparency: revealFade.map((amount) => math.clamp(Chrome.panelShadow + amount * (1 - Chrome.panelShadow), 0, 1)),
			ambientPosition: joinTuple<[number, Vector2]>(surfaceY, panelSize).map((values) =>
				pixelPosition(values[1], 0, -Elevation.ambientSpread, 0, Elevation.ambientOffset + values[0]),
			),
			ambientTransparency: revealFade.map((amount) => math.clamp(Elevation.ambientAlpha + amount * (1 - Elevation.ambientAlpha), 0, 1)),
			hoverWashVisible: lift.map((amount) => amount > 0.04),
			hoverWashAlpha: lift.map((amount) => (amount < 0.04 ? 1 : 1 - amount * 0.14)),
			highlightWashVisible: highlightOn.map((amount) => amount > 0.05),
			highlightWashAlpha: highlightOn.map((amount) => (amount < 0.05 ? 1 : 0.94 + (1 - amount) * 0.06)),
			glowVisible: hoverGlow.map((amount) => amount > 0.02),
			glowThickness: hoverGlow.map((amount) => 1 + amount * 1.8),
			glowTransparency: hoverGlow.map((amount) => 1 - amount * 0.78),
		};
	}, [lift, highlightOn, activeReveal, revealFade, accentColor, hoverGlow, panelSize]);
	return (
		<frame
			ref={panelRef}
			Size={size}
			Position={position}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={zIndex}
			LayoutOrder={layoutOrder}
			ClipsDescendants={false}
		>
			<frame
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ZIndex={zIndex}
				ClipsDescendants={false}
				Event={
					interactive
						? {
								MouseEnter: () => {
									setHovered(true);
								},
								MouseLeave: () => {
									setHovered(false);
								},
							}
						: {}
				}
			>
				<uiscale Scale={activeReveal.map((amount) => 0.98 + 0.02 * math.clamp(amount, 0, 1))} />
				{paintChrome && (
					<frame
						Size={new UDim2(1, Elevation.ambientSpread * 2, 1, Elevation.ambientSpread)}
						Position={derived.ambientPosition}
						BackgroundColor3={Palette.shadow}
						BackgroundTransparency={derived.ambientTransparency}
						BorderSizePixel={0}
						Active={false}
						ZIndex={zIndex}
					>
						<uicorner CornerRadius={new UDim(0, radius + Elevation.ambientSpread)} />
					</frame>
				)}
				{paintChrome && (
					<frame
						Size={new UDim2(1, 8, 1, -1)}
						Position={derived.shadowPosition}
						BackgroundColor3={Palette.shadow}
						BackgroundTransparency={derived.shadowTransparency}
						BorderSizePixel={0}
						ZIndex={zIndex}
					>
						<uicorner CornerRadius={new UDim(0, radius + 2)} />
					</frame>
				)}
				<frame
					Size={UDim2.fromScale(1, 1)}
					Position={paintChrome ? derived.surfacePosition : UDim2.fromScale(0, 0)}
					BackgroundColor3={background}
					BackgroundTransparency={surfaceTransparency}
					BorderSizePixel={0}
					ZIndex={zIndex}
					ClipsDescendants={false}
				>
					<uicorner CornerRadius={new UDim(0, radius)} />
					<uigradient Color={surfaceGradient(background, 0.92)} Rotation={90} />
					{accent !== undefined && (
						// accent hairline across the top edge ties each panel to its section colour
						<frame
							Size={new UDim2(1, -radius * 2, 0, StrokeWidth.hairline)}
							Position={UDim2.fromOffset(radius, 1)}
							BackgroundColor3={accent}
							BackgroundTransparency={revealFade.map((amount) => math.clamp(0.45 + amount * 0.55, 0, 1))}
							BorderSizePixel={0}
							Active={false}
							ZIndex={zIndex}
						>
							<uigradient
								Transparency={new NumberSequence([new NumberSequenceKeypoint(0, 1), new NumberSequenceKeypoint(0.5, 0), new NumberSequenceKeypoint(1, 1)])}
							/>
						</frame>
					)}
					{stroke && (
						<frame Size={new UDim2(1, -2, 1, -2)} Position={UDim2.fromOffset(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={zIndex}>
							<uicorner CornerRadius={new UDim(0, math.max(1, radius - 1))} />
							<Stroke color={derived.strokeColor} thickness={1} transparency={strokeTransparency} />
						</frame>
					)}
					{glowWanted && (
						<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={zIndex} Visible={derived.glowVisible}>
							<uicorner CornerRadius={new UDim(0, radius)} />
							<Stroke color={accentColor} thickness={derived.glowThickness} transparency={derived.glowTransparency} />
						</frame>
					)}
					{interactive && (
						<frame
							Size={UDim2.fromScale(1, 1)}
							BackgroundColor3={Palette.cream}
							BackgroundTransparency={derived.hoverWashAlpha}
							BorderSizePixel={0}
							Visible={derived.hoverWashVisible}
							ZIndex={zIndex + 1}
						>
							<uicorner CornerRadius={new UDim(0, radius)} />
							{shimmer && !interactionMotion && (
								<uigradient
									Color={new ColorSequence(Palette.cream)}
									Rotation={ShimmerMath.ROTATION}
									Transparency={SHIMMER_GLINT}
									Offset={whiteSweep.map((phase) => shimmerOffset(phase, 2.25))}
								/>
							)}
						</frame>
					)}
					{highlight && (
						<frame
							Size={UDim2.fromScale(1, 1)}
							BackgroundColor3={Palette.white}
							BackgroundTransparency={derived.highlightWashAlpha}
							BorderSizePixel={0}
							Visible={derived.highlightWashVisible}
							ZIndex={zIndex + 1}
						>
							<uicorner CornerRadius={new UDim(0, radius)} />
						</frame>
					)}
					<frame
						Size={new UDim2(1, -padding * 2, 1, -padding * 2)}
						Position={UDim2.fromOffset(padding, padding)}
						BackgroundTransparency={1}
						BorderSizePixel={0}
						ZIndex={zIndex + 1}
						ClipsDescendants={clips}
					>
						<ExitPresenceContext.Provider value={contentPresence}>{children}</ExitPresenceContext.Provider>
					</frame>
				</frame>
			</frame>
		</frame>
	);
}

export function Divider({ position, color = Palette.lineSoft, transparency = 0.72 }: { position?: UDim2; color?: Color3; transparency?: number }) {
	return (
		<frame
			Size={new UDim2(1, 0, 0, 1)}
			Position={position}
			BackgroundColor3={color}
			BackgroundTransparency={transparency}
			BorderSizePixel={0}
		>
			<uigradient
				Transparency={
					new NumberSequence([
						new NumberSequenceKeypoint(0, 1),
						new NumberSequenceKeypoint(0.18, 0.35),
						new NumberSequenceKeypoint(0.82, 0.35),
						new NumberSequenceKeypoint(1, 1),
					])
				}
			/>
		</frame>
	);
}

// ---------- press motion ----------
const PRIMARY_ACTION: Record<string, boolean> = {
	collect: true,
	buy: true,
	rebirth: true,
	claim: true,
};
function labelMarksPrimary(text: unknown): boolean {
	if (!typeIs(text, "string") || text === "") {
		return false;
	}
	for (const [word] of string.gmatch(string.lower(text), "%a+")) {
		if (PRIMARY_ACTION[word as string] === true) {
			return true;
		}
	}
	return false;
}
function pressAspect(size: unknown): LuaTuple<[number | undefined, boolean]> {
	if (typeOf(size) !== "UDim2") {
		return $tuple(undefined, false);
	}
	const udim = size as UDim2;
	const xScale = udim.X.Scale;
	const yScale = udim.Y.Scale;
	const xOffset = math.abs(udim.X.Offset);
	const yOffset = math.abs(udim.Y.Offset);
	if (xScale === 0 && yScale === 0 && xOffset > 0 && yOffset > 0) {
		return $tuple(xOffset / yOffset, false);
	}
	if (xScale >= 0.9 && yScale < 0.5) {
		return $tuple(undefined, true);
	}
	if (xScale > 0 && yScale > 0) {
		return $tuple(xScale / yScale, false);
	}
	if (xOffset > 0 && yOffset > 0) {
		return $tuple(xOffset / yOffset, xScale >= 0.9);
	}
	return $tuple(undefined, xScale >= 0.9);
}

export interface PressMotionSpec {
	kind?: string;
	role?: string;
	text?: unknown;
	icon?: unknown;
	size?: unknown;
	hover?: number;
	press?: number;
	tilt?: number;
	pressStiffness?: number;
	pressDamping?: number;
	hoverStiffness?: number;
	hoverDamping?: number;
}
export interface PressMotion {
	kind: string;
	role?: string;
	hover: number;
	press: number;
	tilt: number;
	pressStiffness: number;
	pressDamping: number;
	hoverStiffness: number;
	hoverDamping: number;
}
export function resolvePressMotion(input?: string | PressMotionSpec): PressMotion {
	let spec: PressMotionSpec;
	if (typeIs(input, "string")) {
		spec = { kind: input };
	} else {
		spec = input ?? {};
	}
	let kind = spec.kind;
	if (kind !== "icon" && kind !== "text" && kind !== "row") {
		kind = undefined;
	}
	if (kind !== undefined && spec.pressStiffness !== undefined) {
		return spec as PressMotion;
	}
	const text = spec.text;
	const hasLabel = typeIs(text, "string") && text !== "";
	const hasIcon = spec.icon !== undefined && spec.icon !== false && spec.icon !== "";
	const [ratio, fullRow] = pressAspect(spec.size);
	const square = ratio !== undefined && ratio >= 1 / 1.35 && ratio <= 1.35;
	const wide = fullRow || (ratio !== undefined && ratio > 1.35);
	if (kind === undefined) {
		if (hasLabel && labelMarksPrimary(text)) {
			kind = "row";
		} else if (fullRow) {
			kind = "row";
		} else if (hasIcon && !hasLabel && !wide) {
			kind = "icon";
		} else if (square && !hasLabel) {
			kind = "icon";
		} else {
			kind = "text";
		}
	}
	let hoverGain = 0;
	// a press settles at ~0.97 scale: noticeable on touch, never jumpy
	let pressDrop = 0.03;
	let tilt = 0;
	if (kind === "icon") {
		tilt = -1;
	}
	// semantic role from the label: destructive actions stay calm, confirm/claim actions feel springier
	let role = spec.role;
	if (role === undefined && hasLabel) {
		role = classifyIntent(text as string);
	}
	let pressStiffness = 1500;
	let pressDamping = 52;
	let hoverStiffness = 900;
	let hoverDamping = 44;
	if (role === "dangerButton") {
		hoverGain *= 0.5;
		pressDrop = 0.025;
		tilt = 0;
		pressStiffness = 1700;
		pressDamping = 60;
		hoverStiffness = 980;
		hoverDamping = 52;
	} else if (role === "primaryButton" || role === "reward" || role === "reveal" || role === "ceremony") {
		pressDrop = 0.035;
		pressStiffness = 1400;
		pressDamping = 46;
		hoverStiffness = 820;
		hoverDamping = 38;
	}
	return {
		kind,
		role,
		hover: hoverGain,
		press: pressDrop,
		tilt: math.clamp(tilt, -1.5, 1.5),
		pressStiffness,
		pressDamping,
		hoverStiffness,
		hoverDamping,
	};
}

// ---------- button chrome ----------
export type ButtonSound = string | false;
export interface ButtonChrome {
	active: boolean;
	engaged: boolean;
	hovered: boolean;
	offsetY: React.Binding<number>;
	hoverAmount: React.Binding<number>;
	pressAmount: React.Binding<number>;
	impact: React.Binding<number>;
	shimmer: React.Binding<number>;
	shimmerLive: boolean;
	focusRing: React.Binding<number>;
	surfaceSize: React.Binding<UDim2>;
	touchScale: React.Binding<number>;
	tilt: React.Binding<number>;
	events: React.InstanceEvent<ImageButton>;
	assistActivate: () => void;
}
export function useButtonChrome(
	onClick: () => void,
	reducedMotion = false,
	disabled = false,
	sound: ButtonSound = "click",
	allowShimmer = true,
	idleShimmer = false,
	motionSpec?: string | PressMotionSpec,
): ButtonChrome {
	const viewport = useViewport();
	const settings = useMotionSettings();
	const shimmerScale = settings.shimmerScale ?? 1;
	const effectsPaused = React.useContext(UiEffectsPausedContext);
	const softMotion = reducedMotion || effectsPaused;
	const springSoft = effectsPaused;
	const touchChrome = viewport.compact || viewport.tight;
	const [hovered, setHovered] = React.useState(false);
	const [pressed, setPressed] = React.useState(false);
	const [gamepadFocused, setGamepadFocused] = React.useState(false);
	const [engaged, setEngaged] = React.useState(false);
	const [popTrigger, setPopTrigger] = React.useState(0);
	const hoveredRef = React.useRef(false);
	const activeTouch = React.useRef<InputObject>();
	const activeTouchEnd = React.useRef<RBXScriptConnection>();
	const touchOrigin = React.useRef<Vector2>();
	const lastActivationAt = React.useRef(-math.huge);
	const pressWasTouch = React.useRef(false);
	const hoverStall = React.useRef(0);
	const onClickRef = React.useRef(onClick);
	onClickRef.current = onClick;
	const soundRef = React.useRef(sound);
	soundRef.current = sound;
	const activeTouchMove = React.useRef<RBXScriptConnection>();
	const active = !disabled;
	const poseGoal = disabled ? 0 : pressed ? -1 : hovered ? 1 : 0;
	const pressMotion = resolvePressMotion(motionSpec);
	const pose = useOptionalFlipperSpring(
		poseGoal,
		true,
		springSoft,
		pressed ? pressMotion.pressStiffness : pressMotion.hoverStiffness,
		pressed ? pressMotion.pressDamping : pressMotion.hoverDamping,
	);
	const hoverAmount = pose.map((value) => math.clamp(value, 0, 1));
	const pressAmount = pose.map((value) => math.clamp(-value, 0, 1));
	const offsetY = pose.map((value) => {
		if (value >= 0) {
			return -value * 1.4;
		}
		return -value * 1.1;
	});
	const focusRing = useOptionalFlipperSpring(gamepadFocused && active ? 1 : 0, true, springSoft, 760, 32);
	const impact = useFlash(popTrigger, softMotion, touchChrome ? 0.24 : 0.32);
	const shimmerWanted = allowShimmer && shimmerScale > 0.02 && active && !effectsPaused && (idleShimmer || hovered || gamepadFocused);
	const shimmer = useClock(shimmerWanted, ShimmerMath.sweepSpeed(shimmerScale), 1, false);
	const [shimmerLinger, setShimmerLinger] = React.useState(false);
	const wasShimmering = React.useRef(false);
	React.useEffect(() => {
		if (shimmerWanted) {
			wasShimmering.current = true;
			setShimmerLinger(true);
			return undefined;
		}
		if (!wasShimmering.current) {
			return undefined;
		}
		wasShimmering.current = false;
		const job = task.delay(0.35, () => {
			setShimmerLinger(false);
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [shimmerWanted]);
	const surfaceSize = pose.map(() => UDim2.fromScale(1, 1));
	const hoverGain = pressMotion.hover;
	const pressDrop = pressMotion.press;
	const tiltDegrees = pressMotion.tilt;
	const touchScale = joinTuple<[number, number]>(pose, impact).map((values) => {
		const value = values[0];
		if (reducedMotion) {
			// reduced motion: keep the brightness feedback, drop the scale tween
			return 1;
		}
		if (value >= 0) {
			return 1 + math.clamp(value, 0, 1) * hoverGain;
		}
		return 1 - math.clamp(-value, 0, 1) * pressDrop;
	});
	const tilt = pose.map((value) => math.clamp(value, 0, 1) * tiltDegrees);
	React.useEffect(() => {
		const cancel = () => {
			activeTouchEnd.current?.Disconnect();
			activeTouchEnd.current = undefined;
			const moved = activeTouchMove.current;
			if (moved !== undefined) {
				moved.Disconnect();
			}
			activeTouchMove.current = undefined;
			activeTouch.current = undefined;
			touchOrigin.current = undefined;
			setPressed(false);
		};
		const unsubscribe = subscribeInputCancellation(cancel);
		return () => {
			unsubscribe();
			cancel();
		};
	}, []);
	React.useEffect(() => {
		if (!disabled) {
			return;
		}
		activeTouchEnd.current?.Disconnect();
		activeTouchEnd.current = undefined;
		const moved = activeTouchMove.current;
		if (moved !== undefined) {
			moved.Disconnect();
		}
		activeTouchMove.current = undefined;
		activeTouch.current = undefined;
		touchOrigin.current = undefined;
		pressWasTouch.current = false;
		setPressed(false);
		hoveredRef.current = false;
		setHovered(false);
		setGamepadFocused(false);
	}, [disabled]);
	const markHover = () => {
		if (disabled || hoveredRef.current) {
			return;
		}
		setEngaged(true);
		hoveredRef.current = true;
		setHovered(true);
		const now = os.clock();
		if (now - hoverStall.current < 0.1) {
			return;
		}
		hoverStall.current = now;
		if (sound !== false && !pressWasTouch.current) {
			Audio.play(hoverCueFor(sound));
		}
	};
	const clearHover = () => {
		hoveredRef.current = false;
		setHovered(false);
		setPressed(false);
	};
	const activate = () => {
		if (disabled) {
			return;
		}
		const now = os.clock();
		lastActivationAt.current = now;
		setEngaged(true);
		setPressed(false);
		setPopTrigger((current) => current + 1);
		const pressEnergy = touchChrome ? 1.08 : 1.03;
		const currentSound = soundRef.current;
		if (currentSound !== false) {
			Audio.play(currentSound, pressEnergy);
		}
		onClickRef.current();
		InteractionFeedback.tap();
	};
	const finishTouch = (input: InputObject) => {
		if (input !== activeTouch.current) {
			return;
		}
		const origin = touchOrigin.current;
		activeTouchEnd.current?.Disconnect();
		activeTouchEnd.current = undefined;
		const moved = activeTouchMove.current;
		if (moved !== undefined) {
			moved.Disconnect();
		}
		activeTouchMove.current = undefined;
		activeTouch.current = undefined;
		touchOrigin.current = undefined;
		setPressed(false);
		const distance = origin !== undefined ? new Vector2(input.Position.X, input.Position.Y).sub(origin).Magnitude : math.huge;
		if (distance <= 14 && os.clock() - lastActivationAt.current > 0.12) {
			activate();
		}
	};
	const pressKey = (input: InputObject) =>
		input.UserInputType === Enum.UserInputType.MouseButton1 ||
		input.UserInputType === Enum.UserInputType.Touch ||
		input.KeyCode === Enum.KeyCode.ButtonA ||
		input.KeyCode === Enum.KeyCode.Return;
	const events: React.InstanceEvent<ImageButton> = active
		? {
				MouseEnter: () => markHover(),
				MouseLeave: () => {
					clearHover();
				},
				SelectionGained: () => {
					setEngaged(true);
					setGamepadFocused(true);
					markHover();
				},
				SelectionLost: () => {
					clearHover();
					setGamepadFocused(false);
				},
				InputBegan: (_button, input) => {
					if (pressKey(input)) {
						if (input.UserInputType === Enum.UserInputType.Touch && activeTouch.current !== undefined) {
							return;
						}
						pressWasTouch.current = input.UserInputType === Enum.UserInputType.Touch;
						setEngaged(true);
						setPressed(true);
						if (input.UserInputType === Enum.UserInputType.Touch) {
							activeTouch.current = input;
							touchOrigin.current = new Vector2(input.Position.X, input.Position.Y);
							activeTouchEnd.current?.Disconnect();
							activeTouchEnd.current = UserInputService.InputEnded.Connect(finishTouch);
							const previousMove = activeTouchMove.current;
							if (previousMove !== undefined) {
								previousMove.Disconnect();
							}
							activeTouchMove.current = UserInputService.InputChanged.Connect((changed) => {
								if (changed !== activeTouch.current) {
									return;
								}
								const origin = touchOrigin.current;
								if (origin === undefined) {
									return;
								}
								if (new Vector2(changed.Position.X, changed.Position.Y).sub(origin).Magnitude > 14) {
									setPressed(false);
									const moveConnection = activeTouchMove.current;
									activeTouchMove.current = undefined;
									if (moveConnection !== undefined) {
										moveConnection.Disconnect();
									}
								}
							});
						}
					}
				},
				InputEnded: (_button, input) => {
					if (pressKey(input)) {
						setPressed(false);
					}
					if (input.UserInputType === Enum.UserInputType.Touch) {
						finishTouch(input);
					}
				},
				Activated: () => {
					if (pressWasTouch.current) {
						return;
					}
					if (os.clock() - lastActivationAt.current > 0.12) {
						activate();
					}
				},
			}
		: {};
	return {
		active,
		engaged,
		hovered,
		offsetY,
		hoverAmount,
		pressAmount,
		impact,
		shimmer,
		shimmerLive: shimmerWanted || shimmerLinger,
		focusRing,
		surfaceSize,
		touchScale,
		tilt,
		events,
		assistActivate: () => {
			if (os.clock() - lastActivationAt.current > 0.12) {
				activate();
			}
		},
	};
}

const SHIMMER_SPECULAR_COLOR = new ColorSequence([
	new ColorSequenceKeypoint(0, Palette.cream),
	new ColorSequenceKeypoint(0.42, Palette.cream.Lerp(Palette.white, 0.6)),
	new ColorSequenceKeypoint(0.5, Palette.white),
	new ColorSequenceKeypoint(0.58, Palette.cream.Lerp(Palette.white, 0.6)),
	new ColorSequenceKeypoint(1, Palette.cream),
]);
const SHIMMER_TRAIL_COLOR = new ColorSequence([
	new ColorSequenceKeypoint(0, Palette.cream),
	new ColorSequenceKeypoint(0.5, Palette.cream.Lerp(Palette.cyan, 0.1)),
	new ColorSequenceKeypoint(1, Palette.cream),
]);
export function ButtonShimmer(props: {
	hoverAmount: React.Binding<number>;
	shimmer: React.Binding<number>;
	zIndex?: number;
	radius?: number;
	idle?: boolean;
	live?: boolean;
	trail?: boolean;
}) {
	const { hoverAmount, shimmer, zIndex = 2, radius = Layout.buttonRadius, idle = false, live = true } = props;
	const trail = props.trail ?? idle === true;
	const effectsPaused = React.useContext(UiEffectsPausedContext);
	const settings = useMotionSettings();
	const shimmerScale = settings.shimmerScale ?? 1;
	if (!live || effectsPaused || shimmerScale <= 0.02) {
		return undefined;
	}
	const useTrail = ShimmerMath.wantTrail(shimmerScale, trail);
	const strength = hoverAmount.map((amount) => ShimmerMath.surfaceStrength(amount, idle, shimmerScale));
	const visible = hoverAmount.map((amount) => ShimmerMath.shouldShow(amount, idle, shimmerScale));
	return (
		<frame
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ClipsDescendants={true}
			AutomaticSize={Enum.AutomaticSize.None}
			Active={false}
			Selectable={false}
			Visible={visible}
			ZIndex={zIndex}
		>
			<uicorner CornerRadius={new UDim(0, radius)} />
			{useTrail && (
				<frame
					Size={UDim2.fromScale(1, 1)}
					BackgroundColor3={Palette.cream}
					BackgroundTransparency={strength.map((s) => 1 - s * 0.38)}
					BorderSizePixel={0}
					Active={false}
					Selectable={false}
					AutomaticSize={Enum.AutomaticSize.None}
					ZIndex={1}
				>
					<uicorner CornerRadius={new UDim(0, radius)} />
					<uigradient
						Color={SHIMMER_TRAIL_COLOR}
						Rotation={ShimmerMath.ROTATION}
						Transparency={SHIMMER_TRAIL}
						Offset={shimmer.map((phase) => shimmerOffset(phase, ShimmerMath.DEFAULT_TRAVEL, ShimmerMath.TRAIL_LAG))}
					/>
				</frame>
			)}
			<frame
				Size={UDim2.fromScale(1, 1)}
				BackgroundColor3={Palette.cream}
				BackgroundTransparency={strength.map((s) => 1 - s)}
				BorderSizePixel={0}
				Active={false}
				Selectable={false}
				AutomaticSize={Enum.AutomaticSize.None}
				ZIndex={2}
			>
				<uicorner CornerRadius={new UDim(0, radius)} />
				<uigradient
					Color={SHIMMER_SPECULAR_COLOR}
					Rotation={ShimmerMath.ROTATION}
					Transparency={SHIMMER_GLINT}
					Offset={shimmer.map((phase) => shimmerOffset(phase, ShimmerMath.DEFAULT_TRAVEL, 0))}
				/>
			</frame>
		</frame>
	);
}

function fadedBy(base: Bindable<number>, fade: React.Binding<number>): React.Binding<number> {
	if (typeIs(base, "number")) {
		return fade.map((amount) => base + (1 - base) * amount);
	}
	return joinTuple<[number, number]>(base, fade).map((values) => values[0] + (1 - values[0]) * values[1]);
}

// ---------- Button ----------
export interface ButtonProps {
	text?: string;
	onClick: () => void;
	size?: UDim2;
	position?: Bindable<UDim2>;
	color?: Color3;
	textColor?: Color3;
	icon?: unknown;
	disabled?: boolean;
	loading?: boolean;
	shakeToken?: number;
	reducedMotion?: boolean;
	zIndex?: number;
	outline?: boolean;
	highlight?: boolean;
	hug?: boolean;
	selectable?: boolean;
	sound?: ButtonSound;
	children?: React.ReactNode;
	motion?: string | PressMotionSpec;
	tooltip?: unknown;
}
let nextAssistId = 0;
export function Button(props: ButtonProps) {
	const {
		text,
		onClick,
		size = UDim2.fromOffset(160, TapTarget),
		position,
		icon,
		disabled = false,
		loading = false,
		shakeToken = 0,
		reducedMotion = false,
		zIndex = 5,
		outline = false,
		highlight = false,
		hug = false,
		selectable,
		sound = "auto",
		children,
	} = props;
	let color = props.color;
	let textColor = props.textColor;
	if (color === undefined) {
		color = Palette.panelSoft;
		if (textColor === undefined) {
			textColor = Palette.cream;
		}
	}
	const buttonColor = color;
	const resolvedSound = sound === "auto" ? buttonAudioCue(typeIs(text, "string") ? text : "", icon) : sound;
	const effectivelyDisabled = disabled || loading;
	const motion = props.motion ?? {
		text: typeIs(text, "string") ? text : "",
		icon,
		size,
	};
	const chrome = useButtonChrome(onClick, reducedMotion, effectivelyDisabled, resolvedSound, true, highlight, motion);
	const { active, hovered, offsetY, hoverAmount, pressAmount, impact, shimmer, shimmerLive, focusRing, touchScale, tilt, events } = chrome;
	const spinnerTurn = useRotation(loading, 260);
	const labelHiddenByLoading = useFlipperSpring(loading ? 1 : 0, reducedMotion, 520, 40);
	const shake = useFlash(shakeToken, reducedMotion, 0.42);
	const lastShakeToken = React.useRef(shakeToken);
	React.useEffect(() => {
		if (shakeToken !== lastShakeToken.current) {
			lastShakeToken.current = shakeToken;
			if (shakeToken > 0 && !reducedMotion) {
				Audio.play("noticeError");
			}
		}
	}, [reducedMotion, shakeToken]);
	const shakeOffsetX = shake.map((amount) => math.sin(amount * math.pi * 4.5) * amount * 7);
	const effectsPaused = React.useContext(UiEffectsPausedContext);
	const presence = useExitPresence();
	const arrival = useEntrance(reducedMotion || effectsPaused);
	const canSelect = selectable ?? !disabled;
	const breatheWanted = highlight && active;
	const breatheStroke = useGlowStroke(breatheWanted, reducedMotion || effectsPaused, 0.32, 0.22, 0.46, 1.15);
	const buttonRef = React.useRef<ImageButton>();
	const hostSize = useGuiSize(buttonRef);
	const touchShell = useTouchHitShell();
	const visualPosition = joinTuple<[number, number, Vector2]>(arrival, shakeOffsetX, hostSize).map((values) =>
		pixelPosition(values[2], 0.5, values[1], 0.5, (1 - math.clamp(values[0], 0, 1)) * 12),
	);
	const surfacePosition = joinTuple<[number, Vector2]>(offsetY, hostSize).map((values) => pixelPosition(values[1], 0, 0, 0, values[0]));
	const shadowPosition = joinTuple<[number, Vector2]>(offsetY, hostSize).map((values) => pixelPosition(values[1], 0, 0, 0, 5 - values[0]));
	const assistId = React.useRef<string>();
	if (assistId.current === undefined) {
		nextAssistId += 1;
		assistId.current = "Button-" + tostring(nextAssistId);
	}
	const assistAction = React.useRef<() => void>();
	assistAction.current = chrome.assistActivate;
	React.useEffect(() => {
		const button = buttonRef.current;
		if (button === undefined) {
			return;
		}
		button.SelectionImageObject = undefined;
	}, []);
	React.useEffect(() => {
		const button = buttonRef.current;
		if (button === undefined || effectivelyDisabled) {
			return undefined;
		}
		const id = assistId.current!;
		TouchGestureService.RegisterTouchTarget(
			id,
			button,
			() => {
				const action = assistAction.current;
				if (action) {
					action();
				}
			},
			zIndex,
			12,
		);
		return () => TouchGestureService.UnregisterTouchTarget(id);
	}, [effectivelyDisabled, zIndex]);
	const baseFill = effectivelyDisabled ? Palette.panelSoft : outline ? Palette.panel : buttonColor;
	const disabledAmount = useFlipperSpring(effectivelyDisabled ? 1 : 0, reducedMotion || effectsPaused, 520, 40);
	const enabledFill = joinTuple<[number, number]>(hoverAmount, pressAmount).map(([amount, pressedBy]) => {
		const t = math.clamp(amount, 0, 1);
		const p = math.clamp(pressedBy, 0, 1);
		if (outline) {
			return Palette.panel.Lerp(Palette.panelSoft, t * 0.55).Lerp(darken(Palette.panel, 0.12), p);
		}
		// hover brightens, press dims slightly below rest so the tap reads even without motion
		return buttonColor.Lerp(lighten(buttonColor, 0.1), t).Lerp(darken(buttonColor, 0.1), p);
	});
	const fill = joinTuple<[Color3, number]>(enabledFill, disabledAmount).map(([enabled, amount]) =>
		enabled.Lerp(Palette.panelSoft, math.clamp(amount, 0, 1)),
	);
	const preferredLabelColor = outline
		? textColor !== undefined && textColor !== Palette.ink
			? textColor
			: contrastOn(buttonColor) === Palette.ink
				? buttonColor
				: Palette.cream
		: textColor ?? contrastOn(baseFill);
	const enabledLabelColor = ensureContrast(baseFill, preferredLabelColor, 4.5);
	const disabledLabelColor = ensureContrast(Palette.panelSoft, Palette.muted, 3.25);
	const labelColor = disabledAmount.map((amount) => enabledLabelColor.Lerp(disabledLabelColor, math.clamp(amount, 0, 1)));
	const iconOnly = text === "" && icon !== undefined;
	const hasIcon = icon !== undefined;
	// a tooltip: what the caller says, or for an icon-only button, the icon's name
	let tooltip = props.tooltip;
	if (tooltip === undefined && iconOnly) {
		tooltip = labelFor(icon as string | undefined);
	}
	const tipEvents = useTooltip(
		(effectivelyDisabled && typeIs(tooltip, "string") ? undefined : tooltip) as TooltipContent | undefined,
	);
	const buttonEvents = React.useMemo(() => mergeEvents(events, tipEvents), [events, tipEvents]);
	const compactRipple =
		iconOnly ||
		(size.X.Scale === 0 && size.X.Offset > 0 && size.X.Offset <= 56) ||
		(size.Y.Scale === 0 && size.Y.Offset > 0 && size.Y.Offset <= 40);
	const surfaceFade = React.useMemo(() => presence.map((shown) => math.clamp(1 - shown, 0, 1)), [presence]);
	const labelFade = surfaceFade;
	const shadowTransparency = React.useMemo(
		() => fadedBy(effectivelyDisabled ? 0.84 : Chrome.buttonShadow, surfaceFade),
		[surfaceFade, effectivelyDisabled],
	);
	const outlineTransparency = React.useMemo(
		() => fadedBy(outline ? 0.14 : highlight && active ? breatheStroke : 1, surfaceFade),
		[surfaceFade, outline, highlight, active, breatheStroke],
	);
	const breatheRingTransparency = React.useMemo(
		() => fadedBy(breatheStroke.map((amount) => math.clamp(0.55 + amount * 0.9, 0.55, 1)), surfaceFade),
		[surfaceFade, breatheStroke],
	);
	const focusRingTransparency = React.useMemo(
		() => fadedBy(focusRing.map((amount) => 1 - amount * 0.98), surfaceFade),
		[surfaceFade, focusRing],
	);
	const iconAccent = joinTuple<[Color3, number]>(labelColor, disabledAmount).map(([label, amount]) =>
		label.Lerp(Palette.lineSoft, math.clamp(amount, 0, 1)),
	);
	let resolvedSize = size;
	if (hug && size.X.Scale === 0 && typeIs(text, "string") && !iconOnly) {
		const needed = buttonContentWidth(text, hasIcon);
		resolvedSize = new UDim2(0, math.max(size.X.Offset, needed), size.Y.Scale, size.Y.Offset);
	}
	const labelTransparency = joinTuple<[number, number]>(labelFade, labelHiddenByLoading).map((values) =>
		math.clamp(values[0] + values[1], 0, 1),
	);
	const corner = <uicorner CornerRadius={new UDim(0, Layout.buttonRadius)} />;
	// phones: grow only the invisible hit area to the 44px tap target; the visual keeps its size
	const hitExtra =
		touchShell && resolvedSize.Y.Scale === 0 ? math.max(0, TapTarget - resolvedSize.Y.Offset) : 0;
	return (
		<frame Size={resolvedSize} Position={position} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={zIndex} ClipsDescendants={false}>
			<imagebutton
				ref={buttonRef}
				Size={new UDim2(1, 0, 1, hitExtra)}
				Position={UDim2.fromOffset(0, -hitExtra / 2)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				AutoButtonColor={false}
				Active={true}
				Selectable={canSelect}
				SelectionOrder={zIndex}
				ZIndex={zIndex + 1}
				Event={buttonEvents}
			>
				<frame
					Size={new UDim2(1, 0, 1, -hitExtra)}
					Position={visualPosition}
					AnchorPoint={new Vector2(0.5, 0.5)}
					Rotation={tilt}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					ZIndex={zIndex}
				>
					<uiscale Scale={touchScale} />
					<frame
						Size={UDim2.fromScale(1, 1)}
						Position={shadowPosition}
						BackgroundColor3={Palette.shadow}
						BackgroundTransparency={shadowTransparency}
						BorderSizePixel={0}
						ZIndex={zIndex}
					>
						{corner}
					</frame>
					<frame
						Size={UDim2.fromScale(1, 1)}
						Position={surfacePosition}
						BackgroundColor3={fill}
						BackgroundTransparency={surfaceFade}
						BorderSizePixel={0}
						ZIndex={zIndex + 1}
						ClipsDescendants={true}
					>
						{corner}
						{!outline && !effectivelyDisabled && <uigradient Color={surfaceGradient(baseFill, 0.95)} Rotation={90} />}
						{!outline && !effectivelyDisabled && (
							<frame
								Size={new UDim2(1, -12, 0, 1)}
								Position={UDim2.fromOffset(6, 1)}
								BackgroundColor3={Palette.cream}
								BackgroundTransparency={0.7}
								BorderSizePixel={0}
								Active={false}
								ZIndex={zIndex + 2}
							/>
						)}
						{!compactRipple && (
							<frame
								Size={UDim2.fromScale(1, 1)}
								BackgroundColor3={Palette.white}
								BackgroundTransparency={joinTuple<[number, number]>(hoverAmount, impact).map((values) =>
									math.clamp(1 - values[0] * 0.05 - values[1] * 0.06, 0.82, 1),
								)}
								BorderSizePixel={0}
								Active={false}
								ZIndex={zIndex + 2}
							>
								{corner}
							</frame>
						)}
						{active && (
							<ButtonShimmer
								hoverAmount={hoverAmount}
								shimmer={shimmer}
								live={shimmerLive}
								idle={highlight}
								zIndex={zIndex + 2}
								radius={Layout.buttonRadius}
							/>
						)}
						{active && (
							<frame
								Size={UDim2.fromScale(1, 1)}
								BackgroundColor3={Palette.white}
								BackgroundTransparency={impact.map((amount) => math.clamp(1 - amount * 0.48, 0.52, 1))}
								BorderSizePixel={0}
								Active={false}
								ZIndex={zIndex + 4}
								Visible={impact.map((amount) => amount > 0.05)}
							>
								{corner}
							</frame>
						)}
						{active && (
							<frame
								Size={UDim2.fromScale(1, 1)}
								BackgroundTransparency={1}
								BorderSizePixel={0}
								Active={false}
								ZIndex={zIndex + 5}
								Visible={impact.map((amount) => amount > 0.03)}
							>
								{corner}
								<uistroke
									ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
									Color={buttonColor}
									Thickness={impact.map((amount) => 1 + amount * 2)}
									Transparency={impact.map((amount) => math.clamp(1 - amount * 0.78, 0.18, 1))}
								/>
							</frame>
						)}
						<frame
							Size={UDim2.fromScale(1, 1)}
							BackgroundColor3={Palette.coral}
							BackgroundTransparency={shake.map((amount) => math.clamp(1 - amount * 0.6, 0.4, 1))}
							BorderSizePixel={0}
							Active={false}
							ZIndex={zIndex + 4}
							Visible={shake.map((amount) => amount > 0.02)}
						>
							{corner}
						</frame>
						{children}
						<frame
							Size={UDim2.fromScale(1, 1)}
							BackgroundTransparency={1}
							BorderSizePixel={0}
							Active={false}
							ZIndex={zIndex + 3}
							Visible={labelHiddenByLoading.map((amount) => amount < 0.98)}
						>
							{iconOnly && icon !== undefined && (
								<frame
									Size={UDim2.fromOffset(24, 24)}
									Position={UDim2.fromScale(0.5, 0.5)}
									AnchorPoint={new Vector2(0.5, 0.5)}
									BackgroundTransparency={1}
									ZIndex={zIndex + 3}
								>
									<Icon
										kind={icon}
										color={labelColor}
										accent={iconAccent}
										size={24}
										spin={hovered && active}
										hoverAmount={hoverAmount}
										reducedMotion={reducedMotion}
									/>
								</frame>
							)}
							{!iconOnly && hasIcon && (
								<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={zIndex + 3}>
									<frame
										Size={UDim2.fromOffset(20, 20)}
										Position={new UDim2(0, 8, 0.5, 0)}
										AnchorPoint={new Vector2(0, 0.5)}
										BackgroundTransparency={1}
										BorderSizePixel={0}
										ZIndex={zIndex + 3}
									>
										<Icon
											kind={icon}
											color={labelColor}
											accent={iconAccent}
											size={20}
											spin={hovered && active}
											hoverAmount={hoverAmount}
											reducedMotion={reducedMotion}
										/>
									</frame>
									<textlabel
										ref={pinButtonLabel}
										Size={new UDim2(1, -38, 1, 0)}
										Position={UDim2.fromOffset(32, 0)}
										BackgroundTransparency={1}
										BorderSizePixel={0}
										Text={text}
										TextColor3={labelColor}
										TextTransparency={labelTransparency}
										TextSize={BUTTON_LABEL_SIZE}
										FontFace={Font.fromEnum(Enum.Font.BuilderSansBold)}
										TextXAlignment={Enum.TextXAlignment.Center}
										TextYAlignment={Enum.TextYAlignment.Center}
										TextWrapped={true}
										TextScaled={false}
										TextTruncate={Enum.TextTruncate.AtEnd}
										ZIndex={zIndex + 3}
									/>
								</frame>
							)}
							{!iconOnly && !hasIcon && (
								<textlabel
									ref={pinButtonLabel}
									Size={new UDim2(1, -14, 1, 0)}
									Position={UDim2.fromOffset(7, 0)}
									BackgroundTransparency={1}
									BorderSizePixel={0}
									Text={text}
									TextColor3={labelColor}
									TextTransparency={labelTransparency}
									TextSize={BUTTON_LABEL_SIZE}
									FontFace={Font.fromEnum(Enum.Font.BuilderSansBold)}
									TextXAlignment={Enum.TextXAlignment.Center}
									TextYAlignment={Enum.TextYAlignment.Center}
									TextWrapped={true}
									TextScaled={false}
									TextTruncate={Enum.TextTruncate.AtEnd}
									ZIndex={zIndex + 3}
								/>
							)}
						</frame>
						{loading && (
							<frame
								Size={UDim2.fromOffset(18, 18)}
								Position={UDim2.fromScale(0.5, 0.5)}
								AnchorPoint={new Vector2(0.5, 0.5)}
								Rotation={spinnerTurn}
								BackgroundTransparency={1}
								BorderSizePixel={0}
								ZIndex={zIndex + 3}
								Visible={labelHiddenByLoading.map((amount) => amount > 0.02)}
							>
								<uicorner CornerRadius={new UDim(1, 0)} />
								<uistroke Color={enabledLabelColor} Thickness={2.2} Transparency={labelHiddenByLoading.map((amount) => 1 - amount)}>
									<uigradient
										Color={new ColorSequence(enabledLabelColor)}
										Transparency={
											new NumberSequence([
												new NumberSequenceKeypoint(0, 0),
												new NumberSequenceKeypoint(0.7, 0.6),
												new NumberSequenceKeypoint(1, 1),
											])
										}
										Rotation={90}
									/>
								</uistroke>
							</frame>
						)}
					</frame>
					{(outline || highlight) && (
						<frame
							Size={UDim2.fromScale(1, 1)}
							Position={surfacePosition}
							BackgroundTransparency={1}
							BorderSizePixel={0}
							Active={false}
							ZIndex={zIndex + 4}
						>
							{corner}
							<Stroke color={buttonColor} thickness={1} transparency={outlineTransparency} />
						</frame>
					)}
					{highlight && active && (
						<frame
							Size={UDim2.fromScale(1, 1)}
							Position={surfacePosition}
							BackgroundTransparency={1}
							BorderSizePixel={0}
							Active={false}
							ZIndex={zIndex + 4}
							Visible={breatheWanted}
						>
							{corner}
							<Stroke color={lighten(buttonColor, 0.3)} thickness={2} transparency={breatheRingTransparency} />
						</frame>
					)}
					<frame
						Size={UDim2.fromScale(1, 1)}
						Position={surfacePosition}
						BackgroundTransparency={1}
						BorderSizePixel={0}
						Active={false}
						ZIndex={zIndex + 5}
					>
						{corner}
						<Stroke color={Palette.cream} thickness={4} transparency={focusRingTransparency} />
					</frame>
				</frame>
			</imagebutton>
		</frame>
	);
}

// ---------- Meter ----------
const METER_EMPTY_EPS = 1e-4;
export function meterFill(progress: unknown, target: unknown, complete = false): number {
	if (complete) {
		return 1;
	}
	const goal = typeIs(target, "number") && target === target && target > 0 ? target : 1;
	const current = typeIs(progress, "number") && progress === progress ? progress : 0;
	if (current <= 0) {
		return 0;
	}
	if (current >= goal) {
		return 1;
	}
	return math.clamp(current / goal, 0, 1);
}
export interface MeterProps {
	value?: Bindable<number>;
	color?: Color3;
	position?: Bindable<UDim2>;
	size?: Bindable<UDim2>;
	layoutOrder?: number;
	reducedMotion?: boolean;
	shimmer?: boolean;
	rainbow?: boolean;
}
export function Meter(props: MeterProps) {
	const {
		value = 0,
		color = Palette.cyan,
		position,
		size = new UDim2(1, 0, 0, 8),
		layoutOrder = 0,
		reducedMotion = false,
		shimmer = false,
	} = props;
	const effectsPaused = React.useContext(UiEffectsPausedContext);
	const settings = useMotionSettings();
	const shimmerScale = settings.shimmerScale ?? 1;
	const lowMotion = reducedMotion || effectsPaused;
	const literal = typeIs(value, "number") ? (value === value ? math.clamp(value, 0, 1) : 0) : undefined;
	const empty = literal !== undefined && literal <= METER_EMPTY_EPS;
	const animateLiteral = literal !== undefined && !empty;
	const eased = useOptionalFlipperSpring(literal ?? 0, animateLiteral, lowMotion, 420, 38);
	const lead = useOptionalFlipperSpring(literal ?? 0, animateLiteral, lowMotion, 1500, 52);
	const fill = empty
		? new UDim2(0, 0, 1, 0)
		: literal !== undefined && !animateLiteral
			? new UDim2(literal, 0, 1, 0)
			: (literal !== undefined ? eased : (value as React.Binding<number>)).map((amount) => {
					const t = typeIs(amount, "number") && amount === amount ? math.clamp(amount, 0, 1) : 0;
					if (t <= METER_EMPTY_EPS) {
						return new UDim2(0, 0, 1, 0);
					}
					return new UDim2(t, 0, 1, 0);
				});
	// every bar with something in it is alive: a soft glint always sweeps it, and `shimmer` makes
	// it bright (ready states); `rainbow` makes the colours flow along the fill
	const rainbow = props.rainbow === true;
	const wantShimmer = shimmerScale > 0.02 && !empty && !effectsPaused;
	const glintStrength = shimmer ? 1 : 0.45;
	const shimmerBlend = useOptionalFlipperSpring(wantShimmer ? glintStrength : 0, true, lowMotion, 400, 34);
	const flow = useClock(!empty && !lowMotion && !effectsPaused, rainbow ? 0.18 : 0.09, 1, false);
	const tipPulse = usePulse(!empty && !effectsPaused, 2.6);
	const readyPulse = usePulse(wantShimmer, 2);
	const shimmerPhase = useClock(wantShimmer, ShimmerMath.sweepSpeed(shimmerScale), 1, false);
	const rushing = animateLiteral
		? joinTuple<[number, number]>(lead, eased).map((values) => math.clamp(math.abs(values[0] - values[1]) * 6, 0, 1))
		: undefined;
	return (
		<frame
			Size={size}
			Position={position}
			LayoutOrder={layoutOrder}
			BackgroundColor3={Palette.line}
			BackgroundTransparency={Chrome.meterTrack}
			BorderSizePixel={0}
			ClipsDescendants={true}
		>
			<uisizeconstraint MinSize={new Vector2(48, 3)} />
			<uicorner CornerRadius={new UDim(1, 0)} />
			{animateLiteral && (
				<frame
					Size={lead.map((amount) => new UDim2(math.clamp(amount, 0, 1), 0, 1, 0))}
					BackgroundColor3={lighten(color, 0.45)}
					BackgroundTransparency={rushing!.map((amount) => 1 - amount * 0.55)}
					BorderSizePixel={0}
					Visible={!empty}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</frame>
			)}
			<frame Size={fill} BackgroundColor3={color} BorderSizePixel={0} ClipsDescendants={true} Visible={!empty} ZIndex={2}>
				<uicorner CornerRadius={new UDim(1, 0)} />
				{/* the fill flows: a rainbow when asked for, otherwise its own colour, pale crest to deep trough */}
				<uigradient Color={flow.map((t) => (rainbow ? Rainbow.at(t) : Rainbow.family(color, t, 0.7)))} />
				<frame
					Size={
						rushing !== undefined
							? joinTuple<[number, number]>(rushing, tipPulse).map((values) => {
									const d = 5 + values[0] * 5 + values[1] * 2;
									return UDim2.fromOffset(d, d);
								})
							: tipPulse.map((pulse) => {
									const d = 5 + pulse * 2;
									return UDim2.fromOffset(d, d);
								})
					}
					Position={new UDim2(1, -4, 0.5, 0)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundColor3={Palette.white}
					BackgroundTransparency={rushing !== undefined ? rushing.map((amount) => 0.12 - amount * 0.1) : 0.12}
					BorderSizePixel={0}
					ZIndex={2}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</frame>
				<frame
					Size={UDim2.fromScale(1, 1)}
					BackgroundColor3={Palette.white}
					BackgroundTransparency={joinTuple<[number, number]>(readyPulse, shimmerBlend).map((values) =>
						math.clamp(1 - values[1] * (0.2 + values[0] * 0.12), 0, 1),
					)}
					BorderSizePixel={0}
					Visible={shimmerBlend.map((amount) => amount > 0.02)}
				>
					<uigradient
						Color={new ColorSequence(Palette.cream)}
						Transparency={SHIMMER_GLINT}
						Rotation={22}
						Offset={shimmerPhase.map((phase) => shimmerOffset(phase, 2.6))}
					/>
				</frame>
			</frame>
		</frame>
	);
}

// ---------- Slider ----------
export function Slider({
	value,
	onChange,
	onCommit,
	accent = Palette.cyan,
	reducedMotion = false,
	size = UDim2.fromOffset(188, 28),
	position,
}: {
	value?: number;
	onChange?: (value: number) => void;
	onCommit?: (value: number) => void;
	accent?: Color3;
	reducedMotion?: boolean;
	size?: UDim2;
	position?: Bindable<UDim2>;
}) {
	const [focused, setFocused] = React.useState(false);
	const [hovered, setHovered] = React.useState(false);
	const [dragging, setDragging] = React.useState(false);
	const effectsPaused = React.useContext(UiEffectsPausedContext);
	const engaged = focused || hovered || dragging;
	const engagement = useFlipperSpring(engaged ? 1 : 0, reducedMotion || effectsPaused, 460, 38);
	const amount = typeIs(value, "number") && value === value ? math.clamp(value, 0, 1) : 0;
	const thumb = useSpring(amount, reducedMotion || effectsPaused, 470, 44);
	const sliderViewport = useViewport();
	const trackInset = !sliderViewport.desktop && UserInputService.TouchEnabled ? 12 : 10;
	const buttonRef = React.useRef<ImageButton>();
	const activeDrag = React.useRef<InputObject>();
	const dragChange = React.useRef<RBXScriptConnection>();
	const dragEnd = React.useRef<RBXScriptConnection>();
	const dragOrigin = React.useRef<Vector2>();
	const touchAdjusting = React.useRef(false);
	const lastValue = React.useRef(amount);
	const dragStartValue = React.useRef(amount);
	const onChangeRef = React.useRef(onChange);
	onChangeRef.current = onChange;
	const onCommitRef = React.useRef(onCommit);
	onCommitRef.current = onCommit;
	React.useEffect(() => {
		if (activeDrag.current === undefined) {
			lastValue.current = amount;
		}
	}, [amount]);
	const updateFromX = React.useCallback(
		(x: number) => {
			const button = buttonRef.current;
			if (!button) {
				return;
			}
			const width = math.max(1, button.AbsoluteSize.X - trackInset * 2);
			const targetValue = math.clamp((x - button.AbsolutePosition.X - trackInset) / width, 0, 1);
			const snapped = math.clamp(math.round(targetValue * 20) / 20, 0, 1);
			if (snapped === lastValue.current) {
				return;
			}
			Audio.play("sliderStep");
			InteractionFeedback.tick();
			lastValue.current = snapped;
			const change = onChangeRef.current;
			if (change !== undefined) {
				change(snapped);
			}
		},
		[trackInset],
	);
	React.useEffect(() => {
		const button = buttonRef.current;
		if (!button) {
			return undefined;
		}
		const clearDragConnections = () => {
			dragChange.current?.Disconnect();
			dragEnd.current?.Disconnect();
			dragChange.current = undefined;
			dragEnd.current = undefined;
		};
		const cancelDrag = () => {
			if (activeDrag.current !== undefined && lastValue.current !== dragStartValue.current) {
				const commit = onCommitRef.current;
				dragStartValue.current = lastValue.current;
				if (commit !== undefined) {
					commit(lastValue.current);
				}
			}
			setDragging(false);
			activeDrag.current = undefined;
			dragOrigin.current = undefined;
			touchAdjusting.current = false;
			clearDragConnections();
		};
		const begin = button.InputBegan.Connect((input) => {
			if (input.UserInputType !== Enum.UserInputType.MouseButton1 && input.UserInputType !== Enum.UserInputType.Touch) {
				return;
			}
			if (activeDrag.current !== undefined) {
				return;
			}
			setDragging(true);
			activeDrag.current = input;
			dragStartValue.current = lastValue.current;
			dragOrigin.current = new Vector2(input.Position.X, input.Position.Y);
			touchAdjusting.current = input.UserInputType !== Enum.UserInputType.Touch;
			if (input.UserInputType !== Enum.UserInputType.Touch) {
				updateFromX(input.Position.X);
			}
			clearDragConnections();
			dragChange.current = UserInputService.InputChanged.Connect((changedInput) => {
				const drag = activeDrag.current;
				if (drag === undefined) {
					return;
				}
				if (drag.UserInputType === Enum.UserInputType.Touch) {
					if (changedInput !== drag) {
						return;
					}
					const origin = dragOrigin.current;
					if (origin === undefined) {
						return;
					}
					const delta = new Vector2(changedInput.Position.X, changedInput.Position.Y).sub(origin);
					if (!touchAdjusting.current) {
						if (math.abs(delta.Y) >= 8 && math.abs(delta.Y) > math.abs(delta.X) * 1.15) {
							cancelDrag();
							return;
						}
						if (math.abs(delta.X) < 8 || math.abs(delta.X) <= math.abs(delta.Y)) {
							return;
						}
						touchAdjusting.current = true;
					}
					updateFromX(changedInput.Position.X);
					return;
				}
				if (drag.UserInputType === Enum.UserInputType.MouseButton1 && changedInput.UserInputType === Enum.UserInputType.MouseMovement) {
					updateFromX(changedInput.Position.X);
				}
			});
			dragEnd.current = UserInputService.InputEnded.Connect((endedInput) => {
				const drag = activeDrag.current;
				if (drag === undefined) {
					return;
				}
				const exactTouch = drag.UserInputType === Enum.UserInputType.Touch && endedInput === drag;
				const mouseRelease =
					drag.UserInputType === Enum.UserInputType.MouseButton1 && endedInput.UserInputType === Enum.UserInputType.MouseButton1;
				if (!exactTouch && !mouseRelease) {
					return;
				}
				if (exactTouch && !touchAdjusting.current) {
					updateFromX(endedInput.Position.X);
				}
				setDragging(false);
				activeDrag.current = undefined;
				dragOrigin.current = undefined;
				touchAdjusting.current = false;
				clearDragConnections();
				dragStartValue.current = lastValue.current;
				onCommitRef.current?.(lastValue.current);
				Audio.play("sliderCommit");
				InteractionFeedback.tick();
			});
		});
		const unsubscribeCancel = subscribeInputCancellation(cancelDrag);
		return () => {
			begin.Disconnect();
			unsubscribeCancel();
			cancelDrag();
		};
	}, [updateFromX]);
	const adjust = React.useCallback((delta: number) => {
		const adjusted = math.clamp(math.round((lastValue.current + delta) * 20) / 20, 0, 1);
		if (adjusted === lastValue.current) {
			return;
		}
		lastValue.current = adjusted;
		const change = onChangeRef.current;
		if (change !== undefined) {
			change(adjusted);
		}
		onCommitRef.current?.(adjusted);
		Audio.play("sliderStep");
		InteractionFeedback.tick();
	}, []);
	const thumbDiameter = !sliderViewport.desktop && UserInputService.TouchEnabled ? 20 : 18;
	const thumbCenter = thumb.map((current) => new UDim2(current, trackInset - current * trackInset * 2, 0.5, 0));
	return (
		<imagebutton
			ref={buttonRef}
			Size={size}
			Position={position}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			AutoButtonColor={false}
			Active={true}
			Selectable={true}
			Event={{
				MouseEnter: () => {
					setHovered(true);
					Audio.play("hover");
				},
				MouseLeave: () => setHovered(false),
				SelectionGained: () => {
					setFocused(true);
					Audio.play("hover");
				},
				SelectionLost: () => setFocused(false),
				InputBegan: (_button, input) => {
					if (input.KeyCode === Enum.KeyCode.DPadLeft || input.KeyCode === Enum.KeyCode.Left) {
						adjust(-0.05);
					} else if (input.KeyCode === Enum.KeyCode.DPadRight || input.KeyCode === Enum.KeyCode.Right) {
						adjust(0.05);
					}
				},
			}}
		>
			<frame
				Size={new UDim2(1, -4, 0, 28)}
				Position={new UDim2(0, 2, 0.5, 0)}
				AnchorPoint={new Vector2(0, 0.5)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(0, 12)} />
				<uistroke
					ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
					LineJoinMode={Enum.LineJoinMode.Round}
					Color={accent}
					Thickness={1.5}
					Transparency={engagement.map((active) => 1 - math.clamp(active, 0, 1) * 0.72)}
				/>
			</frame>
			<frame
				Size={new UDim2(1, -trackInset * 2, 0, 7)}
				Position={new UDim2(0, trackInset, 0.5, 0)}
				AnchorPoint={new Vector2(0, 0.5)}
				BackgroundColor3={Palette.line}
				BackgroundTransparency={engagement.map((active) => 0.2 - math.clamp(active, 0, 1) * 0.08)}
				BorderSizePixel={0}
				ClipsDescendants={true}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<frame Size={thumb.map((current) => new UDim2(current, 0, 1, 0))} BackgroundColor3={accent} BorderSizePixel={0}>
					<uicorner CornerRadius={new UDim(1, 0)} />
					<uigradient Color={new ColorSequence(lighten(accent, 0.28), accent)} />
				</frame>
			</frame>
			<frame
				Size={UDim2.fromOffset(30, 30)}
				Position={thumbCenter}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundColor3={accent}
				BackgroundTransparency={engagement.map((active) => 1 - math.clamp(active, 0, 1) * 0.14)}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke
					ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
					LineJoinMode={Enum.LineJoinMode.Round}
					Color={accent}
					Thickness={1}
					Transparency={engagement.map((active) => 1 - math.clamp(active, 0, 1) * 0.5)}
				/>
			</frame>
			<frame
				Size={UDim2.fromOffset(thumbDiameter, thumbDiameter)}
				Position={thumbCenter}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundColor3={Palette.cream}
				BorderSizePixel={0}
			>
				<uiscale Scale={engagement.map((active) => 1 + math.clamp(active, 0, 1) * 0.07)} />
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uigradient Color={new ColorSequence(Palette.white, lighten(accent, 0.42))} Rotation={90} />
				<uistroke
					ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
					LineJoinMode={Enum.LineJoinMode.Round}
					Color={accent}
					Thickness={engagement.map((active) => 2 + math.clamp(active, 0, 1) * 0.5)}
					Transparency={0.06}
				/>
				<frame
					Size={UDim2.fromOffset(5, 5)}
					Position={UDim2.fromScale(0.5, 0.5)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundColor3={accent}
					BorderSizePixel={0}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</frame>
			</frame>
		</imagebutton>
	);
}

// ---------- AmountToggle ----------
const AMOUNT_OPTIONS = [1, 5, 10, 25, 0];
export function AmountToggle({
	value,
	onChange,
	accent = Palette.cream,
	position,
	size = UDim2.fromOffset(240, TapTarget),
	layoutOrder = 0,
	reducedMotion = false,
}: {
	value?: number;
	onChange: (amount: number) => void;
	accent?: Color3;
	position?: Bindable<UDim2>;
	size?: UDim2;
	layoutOrder?: number;
	reducedMotion?: boolean;
}) {
	const [focusedIndex, setFocusedIndex] = React.useState(-1);
	const [hoveredIndex, setHoveredIndex] = React.useState(-1);
	let activeIndex = 0;
	let matched = false;
	AMOUNT_OPTIONS.forEach((amount, index) => {
		if (amount === value) {
			activeIndex = index;
			matched = true;
		}
	});
	const slide = useSpring(activeIndex, reducedMotion, 620, 34);
	const selectionFlash = useFlash(activeIndex + 1, reducedMotion, 0.34);
	const hoverSlide = useSpring(math.max(hoveredIndex, 0), reducedMotion, 700, 42);
	const slotScale = 1 / AMOUNT_OPTIONS.size();
	// phones: grow only the invisible tap rows to the 44px target; the visual keeps its size
	const hitExtra = useTouchHitShell() && size.Y.Scale === 0 ? math.max(0, TapTarget - size.Y.Offset) : 0;
	return (
		<frame
			{...{ Name: "AmountToggleTarget" }}
			Size={size}
			Position={position}
			BackgroundColor3={Palette.ink}
			BackgroundTransparency={0.08}
			BorderSizePixel={0}
			LayoutOrder={layoutOrder}
			ClipsDescendants={hitExtra === 0}
		>
			<uicorner CornerRadius={new UDim(0, 9)} />
			<uistroke
				ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
				LineJoinMode={Enum.LineJoinMode.Round}
				Color={focusedIndex >= 0 ? accent : Palette.lineSoft}
				Thickness={focusedIndex >= 0 ? 2 : 1}
				Transparency={focusedIndex >= 0 ? 0.18 : 0.7}
			/>
			<frame
				Size={new UDim2(slotScale, -4, 1, -6)}
				Position={hoverSlide.map((index) => new UDim2(math.clamp(index, 0, AMOUNT_OPTIONS.size() - 1) * slotScale, 3, 0, 3))}
				BackgroundColor3={Palette.white}
				BackgroundTransparency={0.94}
				BorderSizePixel={0}
				Visible={hoveredIndex >= 0}
				ZIndex={1}
			>
				<uicorner CornerRadius={new UDim(0, 7)} />
			</frame>
			<frame
				Size={new UDim2(slotScale, -4, 1, -6)}
				Position={slide.map((index) => new UDim2(math.clamp(index, 0, AMOUNT_OPTIONS.size() - 1) * slotScale, 3, 0, 3))}
				BackgroundColor3={selectionFlash.map((amount) => lighten(accent, amount * 0.18))}
				BorderSizePixel={0}
				Visible={matched}
				ZIndex={2}
			>
				<uicorner CornerRadius={new UDim(0, 7)} />
				<uigradient Color={new ColorSequence(lighten(accent, 0.24), accent)} Rotation={90} />
			</frame>
			{AMOUNT_OPTIONS.map((amount, index) => (
				<imagebutton
					key={tostring(amount)}
					Size={new UDim2(slotScale, -4, 1, hitExtra)}
					Position={new UDim2(index * slotScale, 3, 0, -hitExtra / 2)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					AutoButtonColor={false}
					Active={true}
					Selectable={true}
					ZIndex={3}
					Event={{
						Activated: () => {
							if (amount !== value) {
								onChange(amount);
							}
							Audio.play("amountChange", 0.96 + index * 0.04);
							InteractionFeedback.tick();
						},
						MouseEnter: () => {
							setHoveredIndex(index);
							Audio.play("hover");
						},
						MouseLeave: () => setHoveredIndex((current) => (current === index ? -1 : current)),
						SelectionGained: () => {
							setFocusedIndex(index);
							setHoveredIndex(index);
							Audio.play("hover");
						},
						SelectionLost: () => {
							setFocusedIndex((current) => (current === index ? -1 : current));
							setHoveredIndex((current) => (current === index ? -1 : current));
						},
					}}
				>
					{focusedIndex === index && (
						<frame Size={new UDim2(1, -4, 1, -4 - hitExtra)} Position={UDim2.fromOffset(2, 2 + hitExtra / 2)} BackgroundTransparency={1} BorderSizePixel={0}>
							<uicorner CornerRadius={new UDim(0, 6)} />
							<uistroke
								ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
								LineJoinMode={Enum.LineJoinMode.Round}
								Color={Palette.cream}
								Thickness={1}
								Transparency={0.2}
							/>
						</frame>
					)}
					<Text
						value={amount === 0 ? "MAX" : `x${amount}`}
						size={12}
						color={value === amount ? contrastOn(accent) : Palette.creamSoft}
						weight={Enum.FontWeight.Heavy}
						align={Enum.TextXAlignment.Center}
						fit={false}
						sizeConstraint={new UDim2(1, -2, 1, -hitExtra)}
						position={UDim2.fromOffset(1, hitExtra / 2)}
						zIndex={4}
					/>
				</imagebutton>
			))}
		</frame>
	);
}

// ---------- SegmentedTabs ----------
export interface SegmentedOption {
	id: string;
	label: string;
	icon?: unknown;
	accent?: Color3;
}
function SegmentedTabHit({
	option,
	selected,
	position,
	size,
	onSelect,
	accent,
	sound,
	reducedMotion,
	zIndex,
}: {
	option: SegmentedOption;
	selected: boolean;
	position: UDim2;
	size: UDim2;
	onSelect: (id: string) => void;
	accent: Color3;
	sound: ButtonSound;
	reducedMotion: boolean;
	zIndex: number;
}) {
	const chrome = useButtonChrome(
		() => {
			if (!selected) {
				onSelect(option.id);
			}
		},
		reducedMotion,
		false,
		sound,
		true,
		selected,
		{ text: option.label, size },
	);
	const selectedInk = contrastOn(accent);
	const textColor = chrome.hoverAmount.map((amount) =>
		selected ? selectedInk : Palette.creamSoft.Lerp(Palette.cream, math.clamp(amount, 0, 1) * 0.72),
	);
	const hoverAlpha = chrome.hoverAmount.map((amount) => 1 - math.clamp(amount, 0, 1) * 0.08);
	return (
		<imagebutton
			Size={size}
			Position={position}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			AutoButtonColor={false}
			Active={true}
			Selectable={true}
			ref={pinLayoutGuardIgnore}
			ZIndex={zIndex}
			Event={chrome.events}
		>
			<frame
				Size={UDim2.fromScale(1, 1)}
				Position={chrome.offsetY.map((y) => new UDim2(0.5, 0, 0.5, math.round(y)))}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundColor3={Palette.white}
				BackgroundTransparency={hoverAlpha}
				BorderSizePixel={0}
				ClipsDescendants={true}
				ZIndex={zIndex}
			>
				<uiscale Scale={chrome.touchScale} />
				<uicorner CornerRadius={new UDim(0, 8)} />
				<ButtonShimmer
					hoverAmount={chrome.hoverAmount}
					shimmer={chrome.shimmer}
					live={chrome.shimmerLive}
					idle={selected}
					zIndex={zIndex + 1}
					radius={8}
				/>
				{option.icon !== undefined && (
					<frame
						Size={UDim2.fromOffset(18, 18)}
						Position={new UDim2(0, 12, 0.5, 0)}
						AnchorPoint={new Vector2(0, 0.5)}
						BackgroundTransparency={1}
						ZIndex={zIndex + 2}
					>
						<Icon
							kind={option.icon}
							color={textColor}
							accent={accent}
							size={18}
							spin={chrome.hovered}
							hoverAmount={chrome.hoverAmount}
							reducedMotion={reducedMotion}
						/>
					</frame>
				)}
				<Text
					value={option.label}
					size={13}
					color={textColor}
					weight={selected ? Enum.FontWeight.Heavy : Enum.FontWeight.Bold}
					align={option.icon !== undefined ? Enum.TextXAlignment.Left : Enum.TextXAlignment.Center}
					fit={true} // long labels shrink in narrow tabs instead of spilling out
					minSize={10}
					position={option.icon !== undefined ? UDim2.fromOffset(38, 0) : UDim2.fromOffset(8, 0)}
					sizeConstraint={new UDim2(1, option.icon !== undefined ? -46 : -16, 1, 0)}
					zIndex={zIndex + 2}
				/>
			</frame>
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={zIndex + 3}>
				<uicorner CornerRadius={new UDim(0, 8)} />
				<uistroke
					ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
					LineJoinMode={Enum.LineJoinMode.Round}
					Color={Palette.cream}
					Thickness={3}
					Transparency={chrome.focusRing.map((amount) => 1 - math.clamp(amount, 0, 1) * 0.95)}
				/>
			</frame>
		</imagebutton>
	);
}
export function SegmentedTabs({
	options,
	value,
	onChange,
	accent = Palette.cyan,
	sound = "tabSwitch",
	columns,
	gap = 6,
	size = new UDim2(1, 0, 0, TapTarget),
	position,
	layoutOrder = 0,
	reducedMotion = false,
	zIndex = 5,
}: {
	options: SegmentedOption[];
	value?: string;
	onChange: (id: string) => void;
	accent?: Color3;
	sound?: ButtonSound;
	columns?: number;
	gap?: number;
	size?: Bindable<UDim2>;
	position?: Bindable<UDim2>;
	layoutOrder?: number;
	reducedMotion?: boolean;
	zIndex?: number;
}) {
	const count = math.max(1, options.size());
	const columnCount = math.max(1, math.min(columns ?? count, count));
	const rowCount = math.max(1, math.ceil(count / columnCount));
	let activeIndex = 0;
	let matched = false;
	options.forEach((option, index) => {
		if (option.id === value) {
			activeIndex = index;
			matched = true;
		}
	});
	const activeColumn = activeIndex % columnCount;
	const activeRow = math.floor(activeIndex / columnCount);
	const columnSlide = useFlipperSpring(activeColumn, reducedMotion, 860, 42);
	const columnTrail = useFlipperSpring(activeColumn, reducedMotion, 390, 38);
	const rowSlide = useFlipperSpring(activeRow, reducedMotion, 720, 32);
	const selectionFlash = useFlash(activeIndex + 1, reducedMotion, 0.3);
	const tabsEffectsPaused = React.useContext(UiEffectsPausedContext);
	const tabSweep = useClock(reducedMotion !== true && !tabsEffectsPaused, SHIMMER_SWEEP_SPEED, 1, false);
	const selectedAccent = options[activeIndex]?.accent ?? accent;
	const cellSize = new UDim2(
		1 / columnCount,
		(-gap * (columnCount - 1)) / columnCount,
		1 / rowCount,
		(-gap * (rowCount - 1)) / rowCount,
	);
	const slotPosition = (index: number) => {
		const column = index % columnCount;
		const row = math.floor(index / columnCount);
		return new UDim2(column / columnCount, (gap * column) / columnCount, row / rowCount, (gap * row) / rowCount);
	};
	const carrierSpan = joinTuple<[number, number, number]>(columnSlide, columnTrail, rowSlide);
	const carrierPosition = carrierSpan.map((values) => {
		const column = math.clamp(math.min(values[0], values[1]), 0, columnCount - 1);
		return new UDim2(
			column / columnCount,
			(gap * column) / columnCount,
			math.clamp(values[2], 0, rowCount - 1) / rowCount,
			(gap * math.clamp(values[2], 0, rowCount - 1)) / rowCount,
		);
	});
	const carrierSize = carrierSpan.map((values) => {
		const stretch = math.clamp(math.abs(values[0] - values[1]), 0, columnCount - 1);
		return cellSize.add(new UDim2(stretch / columnCount, (gap * stretch) / columnCount, 0, 0));
	});
	// phones: never wrap into rows. Tabs that would stack (or squeeze under ~84px) become one
	// sideways-scrolling strip of fixed pills, and the selected pill is kept in view.
	const tabsViewport = useViewport();
	const phoneTabs = chromeFor(tabsViewport).stack;
	const stripMode = phoneTabs && (rowCount > 1 || tabsViewport.width / columnCount < 84);
	const stripRef = React.useRef<ScrollingFrame>();
	const PILL_W = 104;
	React.useEffect(() => {
		const strip = stripRef.current;
		if (!stripMode || strip === undefined) {
			return;
		}
		const left = activeIndex * (PILL_W + gap);
		const view = strip.AbsoluteSize.X;
		const current = strip.CanvasPosition.X;
		if (left < current || left + PILL_W > current + view) {
			strip.CanvasPosition = new Vector2(math.max(0, left - (view - PILL_W) / 2), 0);
		}
	}, [stripMode, activeIndex]);
	if (stripMode) {
		const stripSize = typeIs(size, "UDim2") ? new UDim2(size.X.Scale, size.X.Offset, 0, TapTarget) : size;
		const pillSize = new UDim2(0, PILL_W, 1, 0);
		return (
			<scrollingframe
				ref={stripRef}
				Size={stripSize}
				Position={position}
				BackgroundColor3={Palette.ink}
				BackgroundTransparency={0.18}
				BorderSizePixel={0}
				LayoutOrder={layoutOrder}
				ZIndex={zIndex}
				ScrollingDirection={Enum.ScrollingDirection.X}
				ScrollBarThickness={0}
				CanvasSize={UDim2.fromOffset(count * (PILL_W + gap) - gap + 8, 0)}
				ElasticBehavior={Enum.ElasticBehavior.WhenScrollable}
			>
				<uicorner CornerRadius={new UDim(0, 11)} />
				<uistroke
					ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
					Color={Palette.lineSoft}
					Thickness={1}
					Transparency={0.62}
				/>
				<frame
					Size={new UDim2(0, PILL_W, 1, -8)}
					Position={UDim2.fromOffset(4 + activeIndex * (PILL_W + gap), 4)}
					BackgroundColor3={selectedAccent}
					BorderSizePixel={0}
					Visible={matched}
					ZIndex={zIndex + 1}
				>
					<uicorner CornerRadius={new UDim(0, 8)} />
				</frame>
				{options.map((option, index) => (
					<SegmentedTabHit
						key={option.id}
						option={option}
						selected={option.id === value}
						position={new UDim2(0, 4 + index * (PILL_W + gap), 0, 4)}
						size={pillSize.add(new UDim2(0, 0, 0, -8))}
						onSelect={onChange}
						accent={option.accent ?? accent}
						sound={sound}
						reducedMotion={reducedMotion}
						zIndex={zIndex + 2}
					/>
				))}
			</scrollingframe>
		);
	}
	return (
		<frame
			Size={size}
			Position={position}
			BackgroundColor3={Palette.ink}
			BackgroundTransparency={0.18}
			BorderSizePixel={0}
			LayoutOrder={layoutOrder}
			ZIndex={zIndex}
			ClipsDescendants={true}
		>
			<uicorner CornerRadius={new UDim(0, 11)} />
			<uigradient Color={surfaceGradient(Palette.panel, 0.58)} Rotation={90} />
			<uistroke
				ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
				LineJoinMode={Enum.LineJoinMode.Round}
				Color={Palette.lineSoft}
				Thickness={1}
				Transparency={0.62}
			/>
			<frame Size={new UDim2(1, -8, 1, -8)} Position={UDim2.fromOffset(4, 4)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={zIndex + 1}>
				<frame
					Size={carrierSize}
					Position={carrierPosition}
					BackgroundColor3={selectionFlash.map((amount) => lighten(selectedAccent, amount * 0.14))}
					BorderSizePixel={0}
					Visible={matched}
					ZIndex={zIndex + 1}
					ClipsDescendants={true}
				>
					<uicorner CornerRadius={new UDim(0, 8)} />
					<uigradient Color={new ColorSequence(lighten(selectedAccent, 0.14), darken(selectedAccent, 0.06))} Rotation={90} />
					<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} Active={false} ZIndex={zIndex + 1}>
						<uicorner CornerRadius={new UDim(0, 8)} />
						<uistroke
							ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
							LineJoinMode={Enum.LineJoinMode.Round}
							Color={lighten(selectedAccent, 0.24)}
							Thickness={1}
							Transparency={0.28}
						/>
					</frame>
					<frame
						Size={UDim2.fromScale(1, 1)}
						BackgroundColor3={Palette.cream}
						BackgroundTransparency={0.78}
						BorderSizePixel={0}
						Active={false}
						ZIndex={2}
					>
						<uigradient
							Color={new ColorSequence(Palette.cream)}
							Rotation={ShimmerMath.ROTATION}
							Transparency={SHIMMER_GLINT}
							Offset={tabSweep.map((phase) => shimmerOffset(phase, 2.2))}
						/>
					</frame>
					<frame
						Size={new UDim2(0.52, 0, 0, 2)}
						Position={new UDim2(0.5, 0, 1, -3)}
						AnchorPoint={new Vector2(0.5, 1)}
						BackgroundColor3={Palette.cream}
						BackgroundTransparency={0.12}
						BorderSizePixel={0}
					>
						<uicorner CornerRadius={new UDim(1, 0)} />
					</frame>
				</frame>
				{options.map((option, index) => (
					<SegmentedTabHit
						key={option.id}
						option={option}
						selected={option.id === value}
						position={slotPosition(index)}
						size={cellSize}
						onSelect={onChange}
						accent={option.accent ?? accent}
						sound={sound}
						reducedMotion={reducedMotion}
						zIndex={zIndex + 2}
					/>
				))}
			</frame>
		</frame>
	);
}

// ---------- EmptyState ----------
export function EmptyState({
	icon,
	title,
	body,
	accent = Palette.steel,
	size,
	layoutOrder = 0,
	reducedMotion = false,
	titleSize,
	bodySize,
	iconSize,
	compact = false,
}: {
	icon?: unknown;
	title?: string;
	body?: string;
	accent?: Color3;
	size?: UDim2;
	layoutOrder?: number;
	reducedMotion?: boolean;
	titleSize?: number;
	bodySize?: number;
	iconSize?: number;
	compact?: boolean;
}) {
	const reveal = useEntrance(reducedMotion);
	const fade = reveal.map((amount) => 1 - math.clamp(amount, 0, 1));
	const resolvedIcon = iconSize !== undefined ? iconSize : compact ? 22 : 28;
	const resolvedTitle = titleSize !== undefined ? titleSize : compact ? 14 : 16;
	const resolvedBody = bodySize !== undefined ? bodySize : compact ? 12 : 13;
	const resolvedSize = size ?? (compact ? new UDim2(1, 0, 0, 112) : new UDim2(1, 0, 0, 150));
	const titleH = resolvedTitle + 4;
	const bodyH = math.max(resolvedBody * 2 + 6, 28);
	return (
		<frame Size={resolvedSize} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={layoutOrder}>
			<uipadding
				PaddingTop={new UDim(0, 14)}
				PaddingBottom={new UDim(0, 14)}
				PaddingLeft={new UDim(0, 14)}
				PaddingRight={new UDim(0, 14)}
			/>
			<uilistlayout
				FillDirection={Enum.FillDirection.Vertical}
				HorizontalAlignment={Enum.HorizontalAlignment.Center}
				VerticalAlignment={Enum.VerticalAlignment.Center}
				Padding={new UDim(0, 6)}
				SortOrder={Enum.SortOrder.LayoutOrder}
			/>
			<frame Size={UDim2.fromOffset(resolvedIcon, resolvedIcon)} LayoutOrder={0} BackgroundTransparency={1} BorderSizePixel={0}>
				<Icon kind={icon} color={Palette.muted} accent={accent} size={resolvedIcon} spin={false} clipSafe={true} />
			</frame>
			<Text
				value={title}
				size={resolvedTitle}
				color={Palette.creamSoft}
				weight={Enum.FontWeight.Bold}
				align={Enum.TextXAlignment.Center}
				fit={false}
				transparency={fade}
				layoutOrder={1}
				sizeConstraint={new UDim2(1, 0, 0, titleH)}
			/>
			<Text
				value={body}
				size={resolvedBody}
				color={Palette.muted}
				wrap={true}
				align={Enum.TextXAlignment.Center}
				fit={false}
				transparency={fade}
				layoutOrder={2}
				sizeConstraint={new UDim2(1, 0, 0, bodyH)}
			/>
		</frame>
	);
}

// ---------- Dropdown ----------
export interface DropdownOption {
	id: string;
	label: string;
	icon?: unknown;
	detail?: string;
	count?: unknown;
}
export function Dropdown({
	options,
	value,
	onChange,
	accent = Palette.steel,
	label,
	position,
	size = UDim2.fromOffset(210, 48),
	reducedMotion = false,
	layoutOrder = 0,
	zIndex = 40,
}: {
	options: DropdownOption[];
	value?: string;
	onChange: (id: string) => void;
	accent?: Color3;
	label?: string;
	position?: Bindable<UDim2>;
	size?: UDim2;
	reducedMotion?: boolean;
	layoutOrder?: number;
	zIndex?: number;
}) {
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const [open, setOpen] = React.useState(false);
	const [openUp, setOpenUp] = React.useState(false);
	const [hovered, setHovered] = React.useState(false);
	const [focused, setFocused] = React.useState(false);
	const [pointer, setPointer] = React.useState(-1);
	const [rowCap, setRowCap] = React.useState(6);
	const [portalBounds, setPortalBounds] = React.useState({
		x: 0,
		y: 0,
		width: math.max(1, size.X.Offset),
	});
	const [portalLayer] = React.useState(acquireDropdownPortal);
	const touchRows = chrome.stack || (!viewport.desktop && UserInputService.TouchEnabled);
	const rowHeight = touchRows ? TapTarget : 44;
	const listPad = touchRows ? 4 : 2;
	const listInset = touchRows ? 6 : 4;
	const optionText = 16;
	const visibleRows = math.min(options.size(), rowCap);
	const listHeight = visibleRows * rowHeight + math.max(0, visibleRows - 1) * listPad + listInset * 2;
	const amount = useFlipperSpring(open ? 1 : 0, reducedMotion, 760, 40);
	const triggerAmount = useFlipperSpring(open || hovered || focused ? 1 : 0, reducedMotion, 680, 40);
	const corner = 12;
	let selected: DropdownOption | undefined = options[0];
	for (const option of options) {
		if (option.id === value) {
			selected = option;
		}
	}
	const buttonRef = React.useRef<ImageButton>();
	const listRef = React.useRef<Frame>();
	const scrollRef = React.useRef<ScrollingFrame>();
	const overControl = React.useRef(false);
	const overList = React.useRef(false);
	const [shown, setShown] = React.useState(open);
	if (open && !shown) {
		setShown(true);
	}
	React.useEffect(() => {
		if (open) {
			return undefined;
		}
		overList.current = false;
		overControl.current = false;
		const job = task.delay(reducedMotion ? 0 : 0.32, () => {
			setShown(false);
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [open, reducedMotion]);
	const latest = React.useRef({ options, pointer, value, onChange });
	latest.current = { options, pointer, value, onChange };
	const lastPickAt = React.useRef(-math.huge);
	React.useEffect(() => {
		return () => releaseDropdownPortal();
	}, []);
	React.useEffect(() => {
		if (!open) {
			return undefined;
		}
		const connection = UserInputService.InputBegan.Connect((input) => {
			if (input.KeyCode === Enum.KeyCode.Escape || input.KeyCode === Enum.KeyCode.ButtonB) {
				setOpen(false);
				Audio.play("close");
				return;
			}
			const live = latest.current;
			if (input.KeyCode === Enum.KeyCode.Up || input.KeyCode === Enum.KeyCode.DPadUp) {
				setPointer((current) => {
					const count = live.options.size();
					return count === 0 ? -1 : current <= 0 ? count - 1 : current - 1;
				});
				return;
			}
			if (input.KeyCode === Enum.KeyCode.Down || input.KeyCode === Enum.KeyCode.DPadDown) {
				setPointer((current) => {
					const count = live.options.size();
					return count === 0 ? -1 : (current + 1) % count;
				});
				return;
			}
			if (input.KeyCode === Enum.KeyCode.Return || input.KeyCode === Enum.KeyCode.ButtonA) {
				const chosen = live.options[live.pointer];
				if (chosen === undefined) {
					return;
				}
				const now = os.clock();
				if (now - lastPickAt.current < 0.2) {
					return;
				}
				lastPickAt.current = now;
				if (chosen.id !== live.value) {
					live.onChange(chosen.id);
				}
				setOpen(false);
				setPointer(-1);
				Audio.play("filterPick", 0.96 + math.min(live.pointer, 5) * 0.025);
				InteractionFeedback.tap();
				return;
			}
			if (input.UserInputType !== Enum.UserInputType.MouseButton1 && input.UserInputType !== Enum.UserInputType.Touch) {
				return;
			}
			if (overControl.current || overList.current) {
				return;
			}
			const point = new Vector2(input.Position.X, input.Position.Y);
			const inside = (instance: GuiObject | undefined) => {
				if (!instance) {
					return false;
				}
				const origin = instance.AbsolutePosition;
				const extent = instance.AbsoluteSize;
				return point.X >= origin.X && point.X <= origin.X + extent.X && point.Y >= origin.Y && point.Y <= origin.Y + extent.Y;
			};
			if (inside(buttonRef.current) || inside(listRef.current)) {
				return;
			}
			setOpen(false);
		});
		return () => connection.Disconnect();
	}, [open]);
	const chevronRotation = amount.map((progress) => 180 * math.clamp(progress, 0, 1));
	const listSize = amount.map((progress) => UDim2.fromOffset(portalBounds.width, math.floor(listHeight * math.clamp(progress, 0, 1))));
	const listTransparency = amount.map((progress) => 1 - math.clamp(progress * 1.6, 0, 1));
	const listPosition = amount.map((progress) => {
		const offset = math.round((1 - math.clamp(progress, 0, 1)) * 5) * (openUp ? -1 : 1);
		return UDim2.fromOffset(portalBounds.x, portalBounds.y + offset);
	});
	const glowTransparency = triggerAmount.map((progress) => 1 - math.clamp(progress, 0, 1) * 0.85);
	const needsScroll = options.size() > visibleRows;
	const canvasHeight = options.size() * rowHeight + math.max(0, options.size() - 1) * listPad;
	React.useEffect(() => {
		if (!open || !needsScroll || pointer < 0) {
			return;
		}
		const scroller = scrollRef.current;
		if (scroller === undefined) {
			return;
		}
		const rowTop = pointer * (rowHeight + listPad);
		const rowBottom = rowTop + rowHeight;
		const viewHeight = scroller.AbsoluteWindowSize.Y;
		const top = scroller.CanvasPosition.Y;
		if (rowTop < top) {
			scroller.CanvasPosition = new Vector2(0, rowTop);
		} else if (viewHeight > 0 && rowBottom > top + viewHeight) {
			scroller.CanvasPosition = new Vector2(0, rowBottom - viewHeight);
		}
	}, [pointer, open, needsScroll]);
	const scrollBarThickness = amount.map((progress) => (needsScroll && progress > 0.97 ? 4 : 0));
	const scrollBarAlpha = amount.map((progress) => (needsScroll && progress > 0.97 ? 0 : 1));
	const innerH = math.max(0, listHeight - listInset * 2);
	const chooseListDirection = () => {
		const button = buttonRef.current;
		if (button === undefined) {
			return;
		}
		const clipTop = math.max(0, viewport.topInset);
		const clipBottom = viewport.height - math.max(0, viewport.bottomInset);
		const above = button.AbsolutePosition.Y - clipTop;
		const below = clipBottom - (button.AbsolutePosition.Y + button.AbsoluteSize.Y);
		const available = math.max(0, math.max(above, below) - 8);
		const fittingRows = math.clamp(math.floor((available - listInset * 2 + listPad) / (rowHeight + listPad)), 1, 6);
		const nextRows = math.min(options.size(), fittingRows);
		const nextHeight = nextRows * rowHeight + math.max(0, nextRows - 1) * listPad + listInset * 2;
		const nextOpenUp = below < nextHeight + 8 && above > below;
		const screenW = math.max(viewport.screenWidth, viewport.width);
		const screenH = math.max(viewport.screenHeight, viewport.height);
		const safeLeft = math.max(10, viewport.sideInset);
		const nextWidth = math.max(1, math.min(button.AbsoluteSize.X, screenW - safeLeft * 2));
		const nextX = math.clamp(button.AbsolutePosition.X, safeLeft, math.max(safeLeft, screenW - safeLeft - nextWidth));
		const triggerGap = 6;
		const desiredY = nextOpenUp
			? button.AbsolutePosition.Y - triggerGap
			: button.AbsolutePosition.Y + button.AbsoluteSize.Y + triggerGap;
		const nextY = nextOpenUp
			? math.clamp(
					desiredY,
					math.max(clipTop + nextHeight, 10),
					math.max(math.max(clipTop + nextHeight, 10), math.min(clipBottom, screenH - 10)),
				)
			: math.clamp(desiredY, math.max(clipTop, 10), math.max(clipTop, math.min(clipBottom, screenH - 10) - nextHeight));
		setRowCap(fittingRows);
		setOpenUp(nextOpenUp);
		setPortalBounds({ x: nextX, y: nextY, width: nextWidth });
	};
	React.useEffect(() => {
		if (!open || buttonRef.current === undefined) {
			return undefined;
		}
		chooseListDirection();
		const positionConnection = buttonRef.current.GetPropertyChangedSignal("AbsolutePosition").Connect(chooseListDirection);
		const dimensions = buttonRef.current.GetPropertyChangedSignal("AbsoluteSize").Connect(chooseListDirection);
		return () => {
			positionConnection.Disconnect();
			dimensions.Disconnect();
		};
	}, [open, viewport.width, viewport.height, viewport.topInset, viewport.bottomInset, viewport.sideInset]);
	const chooseOption = (option: DropdownOption, index: number) => {
		lastPickAt.current = os.clock();
		overList.current = false;
		overControl.current = false;
		if (option.id !== value) {
			onChange(option.id);
		}
		setOpen(false);
		setPointer(-1);
		Audio.play("filterPick", 0.96 + math.min(index, 5) * 0.025);
		InteractionFeedback.tap();
	};
	const renderRow = (option: DropdownOption, index: number, rowSize: UDim2, checkIcon: string) => {
		const active = option.id === value;
		const lit = pointer === index;
		const hasIcon = option.icon !== undefined;
		const showDetail = !touchRows && option.detail !== undefined;
		const left = hasIcon ? 38 : 14;
		const right = option.count !== undefined ? 56 : active ? 42 : 20;
		return (
			<imagebutton
				key={option.id}
				Size={rowSize}
				LayoutOrder={index}
				BackgroundColor3={active ? accent : Palette.panelSoft}
				BackgroundTransparency={active ? 0.55 : lit ? 0.35 : 1}
				BorderSizePixel={0}
				AutoButtonColor={false}
				ZIndex={zIndex + 7}
				Active={true}
				Selectable={true}
				Event={{
					Activated: () => chooseOption(option, index),
					MouseEnter: () => {
						setPointer(index);
						overList.current = true;
						Audio.play("hover");
					},
					MouseLeave: () => setPointer((current) => (current === index ? -1 : current)),
					SelectionGained: () => {
						setPointer(index);
						Audio.play("hover");
					},
					SelectionLost: () => setPointer((current) => (current === index ? -1 : current)),
				}}
			>
				<uicorner CornerRadius={new UDim(0, 7)} />
				<frame
					Size={active ? new UDim2(0, 3, 1, -8) : UDim2.fromOffset(0, 0)}
					Position={UDim2.fromOffset(0, 4)}
					BackgroundColor3={accent}
					BackgroundTransparency={active ? 0 : 1}
					BorderSizePixel={0}
					Visible={active}
					ZIndex={zIndex + 8}
				>
					<uicorner CornerRadius={new UDim(0, 2)} />
				</frame>
				{hasIcon && (
					<frame
						Size={UDim2.fromOffset(18, 18)}
						Position={new UDim2(0, 12, 0.5, 0)}
						AnchorPoint={new Vector2(0, 0.5)}
						BackgroundTransparency={1}
						ZIndex={zIndex + 8}
					>
						<Icon kind={option.icon} color={active ? Palette.cream : Palette.creamSoft} accent={accent} size={18} spin={lit} />
					</frame>
				)}
				<Text
					value={option.label}
					size={optionText}
					color={active ? Palette.cream : Palette.creamSoft}
					weight={active ? Enum.FontWeight.Heavy : Enum.FontWeight.Bold}
					fit={false}
					position={UDim2.fromOffset(left, showDetail ? 2 : 0)}
					sizeConstraint={new UDim2(1, -(left + right), showDetail ? 0 : 1, showDetail ? 21 : 0)}
					zIndex={zIndex + 8}
				/>
				{showDetail && (
					<Text
						value={option.detail}
						size={12}
						color={Palette.muted}
						weight={Enum.FontWeight.Medium}
						fit={false}
						position={UDim2.fromOffset(left, 20)}
						sizeConstraint={new UDim2(1, -(left + right), 0, 14)}
						zIndex={zIndex + 8}
					/>
				)}
				{option.count !== undefined && (
					<Text
						value={tostring(option.count)}
						size={chrome.stack ? 13 : 11}
						color={active ? accent : Palette.muted}
						weight={Enum.FontWeight.Bold}
						fit={false}
						align={Enum.TextXAlignment.Right}
						position={new UDim2(1, -40, 0, 0)}
						sizeConstraint={new UDim2(0, 32, 1, 0)}
						zIndex={zIndex + 8}
					/>
				)}
				{active && option.count === undefined && (
					<frame
						Size={UDim2.fromOffset(16, 16)}
						Position={new UDim2(1, -12, 0.5, 0)}
						AnchorPoint={new Vector2(1, 0.5)}
						BackgroundTransparency={1}
						ZIndex={zIndex + 8}
					>
						<Icon kind={checkIcon} color={Palette.cream} accent={accent} size={16} spin={false} />
					</frame>
				)}
			</imagebutton>
		);
	};
	const listLayout = (
		<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, listPad)} />
	);
	const rows = needsScroll ? (
		<scrollingframe
			ref={scrollRef}
			Size={new UDim2(1, -listInset * 2, 0, innerH)}
			Position={UDim2.fromOffset(listInset, listInset)}
			CanvasSize={new UDim2(0, 0, 0, canvasHeight)}
			AutomaticCanvasSize={Enum.AutomaticSize.None}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ScrollBarThickness={scrollBarThickness}
			ScrollBarImageColor3={accent}
			ScrollBarImageTransparency={scrollBarAlpha}
			ScrollingDirection={Enum.ScrollingDirection.Y}
			VerticalScrollBarInset={Enum.ScrollBarInset.ScrollBar}
			ElasticBehavior={Enum.ElasticBehavior.Never}
			ScrollingEnabled={amount.map((progress) => progress > 0.97)}
			ClipsDescendants={true}
			Active={true}
			Selectable={false}
			ZIndex={zIndex + 7}
		>
			{listLayout}
			{options.map((option, index) => renderRow(option, index, new UDim2(1, -4, 0, rowHeight), "Check.21"))}
		</scrollingframe>
	) : (
		<frame
			Size={new UDim2(1, -listInset * 2, 0, innerH)}
			Position={UDim2.fromOffset(listInset, listInset)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={zIndex + 7}
		>
			{listLayout}
			{options.map((option, index) => renderRow(option, index, new UDim2(1, 0, 0, rowHeight), "Check.22"))}
		</frame>
	);
	return (
		<frame
			Size={size}
			Position={position}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			LayoutOrder={layoutOrder}
			ZIndex={zIndex}
			ClipsDescendants={false}
		>
			{label !== undefined && (
				<Text
					value={label}
					size={11}
					color={Palette.muted}
					weight={Enum.FontWeight.Bold}
					fit={false}
					position={UDim2.fromOffset(2, -18)}
					sizeConstraint={new UDim2(1, -4, 0, 16)}
					zIndex={zIndex}
				/>
			)}
			<frame Size={new UDim2(1, 6, 1, 6)} Position={UDim2.fromOffset(-3, -3)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={zIndex - 1}>
				<uicorner CornerRadius={new UDim(0, corner + 3)} />
				<uistroke
					ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
					LineJoinMode={Enum.LineJoinMode.Round}
					Color={accent}
					Thickness={3}
					Transparency={glowTransparency}
				/>
			</frame>
			<imagebutton
				ref={buttonRef}
				Size={UDim2.fromScale(1, 1)}
				BackgroundColor3={triggerAmount.map((progress) => Palette.panelRaised.Lerp(Palette.panelSoft, math.clamp(progress, 0, 1) * 0.72))}
				BackgroundTransparency={0}
				BorderSizePixel={0}
				AutoButtonColor={false}
				Active={true}
				Selectable={true}
				ZIndex={zIndex}
				Event={{
					Activated: () => {
						const willOpen = !open;
						if (willOpen) {
							chooseListDirection();
							setPointer(options.findIndex((option) => option.id === value));
						}
						setOpen(willOpen);
						Audio.play(willOpen ? "filterOpen" : "close");
						InteractionFeedback.tick();
					},
					MouseEnter: () => {
						setHovered(true);
						overControl.current = true;
						Audio.play("hover");
					},
					MouseLeave: () => {
						setHovered(false);
						overControl.current = false;
					},
					SelectionGained: () => {
						setHovered(true);
						setFocused(true);
						Audio.play("hover");
					},
					SelectionLost: () => {
						setHovered(false);
						setFocused(false);
					},
				}}
			>
				<uicorner CornerRadius={new UDim(0, corner)} />
				<uistroke
					ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
					LineJoinMode={Enum.LineJoinMode.Round}
					Color={focused ? accent : triggerAmount.map((progress) => Palette.lineSoft.Lerp(accent, math.clamp(progress, 0, 1)))}
					Thickness={focused ? 2 : 1}
					Transparency={focused ? 0.08 : triggerAmount.map((progress) => 0.58 - math.clamp(progress, 0, 1) * 0.38)}
				/>
				{selected !== undefined && selected.icon !== undefined && (
					<frame
						Size={UDim2.fromOffset(18, 18)}
						Position={new UDim2(0, 10, 0.5, 0)}
						AnchorPoint={new Vector2(0, 0.5)}
						BackgroundTransparency={1}
						ZIndex={zIndex + 1}
					>
						<Icon kind={selected.icon} color={Palette.creamSoft} accent={accent} size={18} spin={false} />
					</frame>
				)}
				<Text
					value={selected !== undefined ? selected.label : ""}
					size={optionText}
					color={Palette.cream}
					weight={Enum.FontWeight.Bold}
					fit={true}
					minSize={11}
					position={UDim2.fromOffset(selected !== undefined && selected.icon !== undefined ? 36 : 14, 0)}
					sizeConstraint={new UDim2(1, selected !== undefined && selected.icon !== undefined ? -78 : -52, 1, 0)}
					zIndex={zIndex + 1}
				/>
				<frame
					Size={UDim2.fromOffset(26, 26)}
					Position={new UDim2(1, -8, 0.5, 0)}
					AnchorPoint={new Vector2(1, 0.5)}
					BackgroundColor3={Palette.ink}
					BackgroundTransparency={0.2}
					BorderSizePixel={0}
					ZIndex={zIndex + 1}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
					<frame
						Size={UDim2.fromOffset(12, 12)}
						Position={UDim2.fromScale(0.5, 0.5)}
						AnchorPoint={new Vector2(0.5, 0.5)}
						Rotation={chevronRotation}
						BackgroundTransparency={1}
						ZIndex={zIndex + 2}
					>
						<frame
							Size={new UDim2(0, 9, 0, 2)}
							Position={new UDim2(0.5, -3, 0.5, 0)}
							AnchorPoint={new Vector2(0.5, 0.5)}
							Rotation={45}
							BackgroundColor3={accent}
							BorderSizePixel={0}
							ZIndex={zIndex + 1}
						>
							<uicorner CornerRadius={new UDim(1, 0)} />
						</frame>
						<frame
							Size={new UDim2(0, 9, 0, 2)}
							Position={new UDim2(0.5, 3, 0.5, 0)}
							AnchorPoint={new Vector2(0.5, 0.5)}
							Rotation={-45}
							BackgroundColor3={accent}
							BorderSizePixel={0}
							ZIndex={zIndex + 1}
						>
							<uicorner CornerRadius={new UDim(1, 0)} />
						</frame>
					</frame>
				</frame>
			</imagebutton>
			{(open || shown) &&
				ReactRoblox.createPortal(
					<frame Size={UDim2.fromScale(1, 1)} Position={UDim2.fromOffset(0, 0)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={zIndex + 5}>
						<imagebutton
							Size={UDim2.fromScale(1, 1)}
							BackgroundTransparency={1}
							BorderSizePixel={0}
							AutoButtonColor={false}
							Active={open}
							Selectable={false}
							ZIndex={zIndex + 5}
							Event={{
								Activated: () => {
									setOpen(false);
									Audio.play("close");
								},
							}}
						/>
						<frame
							ref={listRef}
							Size={listSize}
							Position={listPosition}
							AnchorPoint={openUp ? new Vector2(0, 1) : Vector2.zero}
							BackgroundColor3={Palette.ink}
							BackgroundTransparency={listTransparency}
							BorderSizePixel={0}
							ZIndex={zIndex + 6}
							ClipsDescendants={true}
							Visible={amount.map((progress) => progress > 0.01)}
							Event={{
								MouseEnter: () => {
									overList.current = true;
								},
								MouseLeave: () => {
									overList.current = false;
								},
							}}
						>
							<uicorner CornerRadius={new UDim(0, corner)} />
							<uistroke
								ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
								LineJoinMode={Enum.LineJoinMode.Round}
								Color={accent}
								Thickness={1}
								Transparency={listTransparency.map((current) => 0.35 + current * 0.65)}
							/>
							{rows}
						</frame>
					</frame>,
					portalLayer,
				)}
		</frame>
	);
}

// ---------- SearchField ----------
export function SearchField({
	value,
	onChange,
	accent = Palette.steel,
	placeholder = "Search",
	position,
	size = UDim2.fromOffset(220, TapTarget),
	reducedMotion = false,
	zIndex = 10,
}: {
	value: string;
	onChange?: (text: string) => void;
	accent?: Color3;
	placeholder?: string;
	position?: Bindable<UDim2>;
	size?: UDim2;
	reducedMotion?: boolean;
	zIndex?: number;
}) {
	const searchViewport = useViewport();
	const chrome = chromeFor(searchViewport);
	const reactModules = kitMember<ReactModules>("ReactHosts", "reactModules");
	const [draft, setDraft] = React.useState(value);
	const lastEmitted = React.useRef(value);
	const boxRef = React.useRef<TextBox>();
	const [focused, setFocused] = React.useState(false);
	const [clearHovered, setClearHovered] = React.useState(false);
	const debouncedChange = reactModules.useDebounceCallback(
		(text: string) => {
			if (onChange !== undefined) {
				onChange(text);
			}
		},
		{ wait: 0.08 },
	);
	reactModules.useUpdateEffect(() => {
		if (value === "" || !focused) {
			lastEmitted.current = value;
			setDraft(value);
		}
	}, [value, focused]);
	reactModules.useUnmountEffect(() => {
		debouncedChange.flush();
	});
	reactModules.useEventListener(
		UserInputService.InputBegan,
		(input: InputObject, processed: boolean) => {
			if (processed || input.KeyCode !== Enum.KeyCode.Escape) {
				return;
			}
			const box = boxRef.current;
			if (box !== undefined) {
				box.ReleaseFocus();
			}
		},
		{ connected: focused },
	);
	const focus = useFlipperSpring(focused ? 1 : 0, reducedMotion, 720, 40);
	const clearHover = useFlipperSpring(clearHovered ? 1 : 0, reducedMotion, 680, 42);
	const hasQuery = draft !== "";
	const clearReveal = useFlipperSpring(hasQuery ? 1 : 0, reducedMotion, 760, 40, hasQuery ? 1 : 0);
	const touchField = chrome.stack || (!searchViewport.desktop && UserInputService.TouchEnabled);
	const clearSize = touchField ? math.max(40, math.min(TapTarget, size.Y.Offset > 0 ? size.Y.Offset : TapTarget)) : 32;
	const fieldInset = touchField ? 0 : 4;
	const fieldText = 16;
	return (
		<frame Size={size} Position={position} BackgroundColor3={Palette.panelSoft} BorderSizePixel={0} ZIndex={zIndex} ClipsDescendants={true}>
			<uicorner CornerRadius={new UDim(0, 12)} />
			<uistroke
				ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
				LineJoinMode={Enum.LineJoinMode.Round}
				Color={focus.map((amount) => Palette.lineSoft.Lerp(accent, amount))}
				Thickness={focus.map((amount) => 1 + amount)}
				Transparency={focus.map((amount) => 0.45 - amount * 0.35)}
			/>
			<frame
				Size={focus.map((amount) => new UDim2(0, 3, 1, -math.round(16 + (1 - math.clamp(amount, 0, 1)) * 12)))}
				Position={new UDim2(0, 8, 0.5, 0)}
				AnchorPoint={new Vector2(0, 0.5)}
				BackgroundColor3={accent}
				BackgroundTransparency={focus.map((amount) => 1 - math.clamp(amount, 0, 1) * 0.85)}
				BorderSizePixel={0}
				ZIndex={zIndex + 1}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
			<frame
				Size={UDim2.fromOffset(20, 20)}
				Position={new UDim2(0, 16, 0.5, 0)}
				AnchorPoint={new Vector2(0, 0.5)}
				BackgroundTransparency={1}
				ZIndex={zIndex + 1}
			>
				<Icon kind="Search.11" color={focus.map((amount) => Palette.muted.Lerp(accent, amount))} accent={accent} size={20} spin={false} />
			</frame>
			<textbox
				ref={boxRef}
				Size={clearReveal.map((amount) => new UDim2(1, -(52 + (clearSize + 6) * math.clamp(amount, 0, 1)), 1, -(fieldInset * 2)))}
				Position={UDim2.fromOffset(42, fieldInset)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				Text={draft}
				PlaceholderText={placeholder}
				PlaceholderColor3={Palette.muted}
				TextColor3={Palette.cream}
				TextSize={fieldText}
				FontFace={Font.fromEnum(Enum.Font.BuilderSansMedium)}
				TextXAlignment={Enum.TextXAlignment.Left}
				TextYAlignment={Enum.TextYAlignment.Center}
				ClearTextOnFocus={false}
				TextTruncate={Enum.TextTruncate.AtEnd}
				ClipsDescendants={true}
				ZIndex={zIndex + 1}
				Change={{
					Text: (instance) => {
						const text = instance.Text;
						setDraft(text);
						if (text === lastEmitted.current) {
							return;
						}
						lastEmitted.current = text;
						debouncedChange.run(text);
					},
				}}
				Event={{
					Focused: () => {
						setFocused(true);
						Audio.play("inputFocus");
						InteractionFeedback.tick();
					},
					FocusLost: () => {
						setFocused(false);
						debouncedChange.flush();
					},
				}}
			/>
			<imagebutton
				Size={clearReveal.map((amount) => UDim2.fromOffset(clearSize * math.clamp(amount, 0, 1), clearSize * math.clamp(amount, 0, 1)))}
				Position={new UDim2(1, -4, 0.5, 0)}
				AnchorPoint={new Vector2(1, 0.5)}
				BackgroundColor3={clearHover.map((amount) => Palette.panelRaised.Lerp(Palette.panelSoft, math.clamp(amount, 0, 1)))}
				BackgroundTransparency={joinTuple<[number, number]>(clearHover, clearReveal).map(
					(values) => 0.18 - math.clamp(values[0], 0, 1) * 0.12 + (1 - math.clamp(values[1], 0, 1)),
				)}
				BorderSizePixel={0}
				AutoButtonColor={false}
				Active={hasQuery}
				Selectable={hasQuery}
				Visible={clearReveal.map((amount) => amount > 0.02)}
				ZIndex={zIndex + 2}
				Event={{
					Activated: () => {
						debouncedChange.cancel();
						lastEmitted.current = "";
						setDraft("");
						if (onChange !== undefined) {
							onChange("");
						}
						Audio.play("inputClear");
						InteractionFeedback.tap();
					},
					MouseEnter: () => {
						setClearHovered(true);
						Audio.play("hover");
					},
					MouseLeave: () => setClearHovered(false),
					SelectionGained: () => {
						setClearHovered(true);
						Audio.play("hover");
					},
					SelectionLost: () => setClearHovered(false),
				}}
			>
				<uicorner CornerRadius={new UDim(0, 7)} />
				<uistroke
					ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
					LineJoinMode={Enum.LineJoinMode.Round}
					Color={Palette.lineSoft}
					Thickness={1}
					Transparency={0.65}
				/>
				<Icon
					kind="Close.9"
					color={Palette.creamSoft}
					accent={Palette.muted}
					size={14}
					spin={false}
					position={UDim2.fromScale(0.5, 0.5)}
					anchorPoint={new Vector2(0.5, 0.5)}
				/>
			</imagebutton>
		</frame>
	);
}

export function LogoLockup(props: { micro?: boolean; position?: UDim2 }) {
	const micro = props.micro === true;
	const mark = micro ? 40 : 48;
	const textX = mark + 10;
	return (
		<frame
			{...{ Name: "AstralForgeBrand" }}
			Size={UDim2.fromScale(1, 1)}
			Position={props.position}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ClipsDescendants={false}
		>
			<frame
				Size={UDim2.fromOffset(mark, mark)}
				Position={new UDim2(0, 0, 0.5, 0)}
				AnchorPoint={new Vector2(0, 0.5)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={false}
			>
				<imagelabel
					{...{ Name: "ForgeMonogram" }}
					Size={UDim2.fromScale(1, 1)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					Image={COMPACT_MARK_ASSET}
					ScaleType={Enum.ScaleType.Fit}
					ZIndex={2}
				/>
			</frame>
			{!micro && (
				<imagelabel
					{...{ Name: "ForgeWordmark" }}
					Image={WORDMARK_ASSET}
					ScaleType={Enum.ScaleType.Fit}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					Position={new UDim2(0, textX, 0.5, 0)}
					AnchorPoint={new Vector2(0, 0.5)}
					Size={new UDim2(1, -textX, 0, 44)}
					ZIndex={2}
				/>
			)}
		</frame>
	);
}

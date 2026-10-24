// The one tooltip layer. Mounted once at the UI root by <TooltipProvider>; draws the open tip in
// its own top ScreenGui so no clipping ancestor can cut it.
//
// Look and motion are the game's surface: a Surface bubble entering and leaving on usePresence
// with the revealOffset rise, title, a short accent rule, body and hint exactly as before. Rich
// tips add stat rows (with signed deltas in mint/coral), and key hints for the current input.
// A small arrow on the edge facing the target shows what the tip is about.
import React from "@rbxts/react";
import { TITLE_FACE } from "../titleFace";
import ReactRoblox from "@rbxts/react-roblox";
import { Palette } from "../../CoreKit/theme";
import { DialogLayout as D } from "../../pages/generated/DialogLayout";
import { revealOffset, usePresence } from "../../MotionKit/motion";
import { KeyHint, Surface, SurfaceMetrics, SurfaceText } from "../surface";
import { TooltipData, TooltipStat, deltaTone, formatDelta, hasText, keysFor, statValue } from "./content";
import { OpenTip, avoidRects, closeTooltip, currentInput, openTooltip, screenRect, subscribeTooltip } from "./intent";
import { Rect, place } from "./placement";

const Players = game.GetService("Players");
const RunService = game.GetService("RunService");
const GuiService = game.GetService("GuiService");
const Workspace = game.GetService("Workspace");

const GAP = 8;
const EDGE = 10;
// 26-dialogs tooltip .pn: 260 wide, pad 12, gap 6, Cinzel 16 title
const BUBBLE_PAD = D.Tip.pad.left;
const ARROW = 10;

// the device safe area (notch, rounded corners, home bar), measured by the provider
let safeArea: Frame | undefined = undefined;

function screenSize(): Vector2 {
	const camera = Workspace.CurrentCamera;
	return camera !== undefined ? camera.ViewportSize : new Vector2(1280, 720);
}

function bounds(): Rect {
	const view = screenSize();
	const safe = safeArea !== undefined && safeArea.Parent !== undefined ? safeArea : undefined;
	const low = safe !== undefined ? safe.AbsolutePosition : Vector2.zero;
	const high = safe !== undefined ? safe.AbsolutePosition.add(safe.AbsoluteSize) : view;
	const left = math.max(EDGE, low.X + EDGE);
	const top = math.max(EDGE, GuiService.GetGuiInset()[0].Y + 4, low.Y + EDGE);
	const right = math.min(view.X, high.X) - EDGE;
	const bottom = math.min(view.Y, high.Y) - EDGE;
	return { x: left, y: top, w: math.max(0, right - left), h: math.max(0, bottom - top) };
}

interface Spot {
	x: number;
	y: number;
	side: "top" | "bottom" | "left" | "right";
	arrow: number;
	pointed: boolean;
}

function StatRow(props: { stat: TooltipStat; order: number; fade: React.Binding<number>; width: number }) {
	const stat = props.stat;
	const delta = formatDelta(stat);
	const tone = deltaTone(stat);
	return (
		<frame Size={UDim2.fromOffset(props.width, 18)} BackgroundTransparency={1} LayoutOrder={props.order}>
			<SurfaceText
				text={stat.label}
				type="small"
				color={Palette.creamSoft}
				size={new UDim2(0.55, 0, 1, 0)}
				transparency={props.fade}
			/>
			<frame
				Size={new UDim2(0.45, 0, 1, 0)}
				Position={UDim2.fromScale(1, 0)}
				AnchorPoint={new Vector2(1, 0)}
				BackgroundTransparency={1}
			>
				<uilistlayout
					FillDirection={Enum.FillDirection.Horizontal}
					HorizontalAlignment={Enum.HorizontalAlignment.Right}
					VerticalAlignment={Enum.VerticalAlignment.Center}
					Padding={new UDim(0, 6)}
					SortOrder={Enum.SortOrder.LayoutOrder}
				/>
				<SurfaceText text={statValue(stat.value)} type="small" color={stat.color ?? Palette.cream} autoSize={true} transparency={props.fade} order={1} />
				{delta !== undefined && (
					<SurfaceText
						text={delta}
						type="hint"
						color={tone > 0 ? Palette.mint : tone < 0 ? Palette.coral : Palette.muted}
						autoSize={true}
						transparency={props.fade}
						order={2}
					/>
				)}
			</frame>
		</frame>
	);
}

function Bubble(props: { tip: OpenTip; leaving: boolean; reducedMotion: boolean; onGone: (id: number) => void }) {
	const tip = props.tip;
	const data: TooltipData = tip.data;
	const [spot, setSpot] = React.useBinding<Spot>({ x: -1000, y: -1000, side: "top", arrow: 0, pointed: false });
	// waits two frames so AutomaticSize has measured before the bubble shows
	const [ready, setReady] = React.useState(false);
	const [presence, , beginExit] = usePresence(props.reducedMotion);
	const appear = React.useMemo(() => presence.map((a) => (ready ? a : 0)), [presence, ready]);
	const onGone = props.onGone;
	React.useEffect(() => {
		if (props.leaving) {
			beginExit(() => onGone(tip.id));
		}
	}, [props.leaving]);
	const bubbleRef = React.useRef<Frame>();
	React.useEffect(() => {
		const target = tip.target;
		let frames = 0;
		const preferred = data.side ?? "top";
		const connection = RunService.RenderStepped.Connect(() => {
			if (!target.IsDescendantOf(game) || !target.Visible) {
				closeTooltip(tip.id);
				return;
			}
			if (props.leaving && frames >= 2) {
				return;
			}
			const bubble = bubbleRef.current;
			const size = bubble !== undefined ? bubble.AbsoluteSize : Vector2.zero;
			const at = place({
				target: screenRect(target),
				bubble: size,
				bounds: bounds(),
				side: preferred,
				gap: GAP + ARROW / 2,
				avoid: avoidRects(target),
				arrowInset: SurfaceMetrics.radius + ARROW / 2,
			});
			setSpot({ x: at.x, y: at.y, side: at.side, arrow: at.arrow, pointed: !at.fallback });
			frames += 1;
			if (frames === 2) {
				setReady(true);
			}
		});
		return () => connection.Disconnect();
	}, [tip.target, props.leaving]);
	const view = screenSize();
	const narrow = view.X < 700;
	const maxW = math.max(120, math.min(narrow ? 220 : D.Tip.w - BUBBLE_PAD * 2, view.X - EDGE * 2 - BUBBLE_PAD * 2));
	const fade = React.useMemo(() => appear.map((a) => 1 - math.clamp(a, 0, 1)), [appear]);
	const hasTitle = hasText(data.title);
	const input = currentInput();
	const stats = data.stats ?? [];
	const keys = (data.keys ?? []).filter((k) => keysFor(k, input) !== undefined);
	const statW = math.min(maxW, narrow ? 200 : 240);
	const position = React.joinBindings({ spot, appear }).map((v) => UDim2.fromOffset(v.spot.x, v.spot.y + revealOffset(v.appear)));
	return (
		<frame Position={position} Size={UDim2.fromOffset(0, 0)} AutomaticSize={Enum.AutomaticSize.XY} BackgroundTransparency={1}>
			<Surface frameRef={bubbleRef} autoSize={true} padding={BUBBLE_PAD} appear={appear} accent={data.accent} position={UDim2.fromOffset(0, 0)} zIndex={2}>
				<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, D.Tip.gap)} />
				{hasTitle && (
					// 26-dialogs tooltip: Cinzel 16 title over one creamSoft line, no rule
					<textlabel
						LayoutOrder={1}
						Size={UDim2.fromOffset(0, 0)}
						AutomaticSize={Enum.AutomaticSize.XY}
						BackgroundTransparency={1}
						Text={data.title!}
						TextSize={D.TipTitle.text.size}
						FontFace={TITLE_FACE}
						TextColor3={Palette.cream}
						TextTransparency={fade}
						TextWrapped={true}
						TextXAlignment={Enum.TextXAlignment.Left}
					>
						<uisizeconstraint MaxSize={new Vector2(maxW, math.huge)} />
					</textlabel>
				)}
				{hasText(data.body) && (
					<SurfaceText
						text={data.body}
						type="body"
						color={hasTitle ? Palette.creamSoft : Palette.cream}
						autoSize={true}
						wrap={true}
						maxWidth={maxW}
						transparency={fade}
						order={3}
					/>
				)}
				{stats.map((stat, i) => (
					<StatRow key={`stat${i}`} stat={stat} order={10 + i} fade={fade} width={statW} />
				))}
				{hasText(data.hint) && (
					<SurfaceText text={data.hint} type="hint" color={Palette.muted} autoSize={true} wrap={true} maxWidth={maxW} transparency={fade} order={100} />
				)}
				{keys.map((key, i) => (
					<KeyHint key={`key${i}`} keys={keysFor(key, input)!} label={key.label} order={200 + i} />
				))}
			</Surface>
			<frame
				Size={UDim2.fromOffset(ARROW, ARROW)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Rotation={45}
				ZIndex={1}
				BorderSizePixel={0}
				BackgroundColor3={Palette.panel}
				Visible={spot.map((s) => s.pointed)}
				BackgroundTransparency={appear.map((a) => 1 - 0.97 * math.clamp(a, 0, 1))}
				Position={React.joinBindings({ spot, appear }).map(({ spot: s }) => {
					const size = bubbleRef.current !== undefined ? bubbleRef.current.AbsoluteSize : Vector2.zero;
					if (s.side === "top") return UDim2.fromOffset(s.arrow, size.Y);
					if (s.side === "bottom") return UDim2.fromOffset(s.arrow, 0);
					if (s.side === "left") return UDim2.fromOffset(size.X, s.arrow);
					return UDim2.fromOffset(0, s.arrow);
				})}
			>
				<uistroke
					Color={data.accent ?? Palette.lineSoft}
					Thickness={1}
					Transparency={appear.map((a) => 1 - (1 - (data.accent !== undefined ? 0.7 : 0.86)) * math.clamp(a, 0, 1))}
				/>
			</frame>
		</frame>
	);
}

export interface TooltipProviderProps {
	enabled?: boolean;
	reducedMotion?: boolean;
	children?: React.ReactNode;
}

export function TooltipProvider(props: TooltipProviderProps) {
	const [open, setOpen] = React.useState<OpenTip | undefined>(openTooltip());
	// the last tip stays mounted while it plays its exit
	const [shown, setShown] = React.useState<OpenTip | undefined>(openTooltip());
	const enabled = props.enabled !== false;
	const onGone = React.useCallback(
		(id: number) => setShown((current) => (current !== undefined && current.id === id ? undefined : current)),
		[],
	);
	React.useEffect(() => {
		const listener = () => {
			const now = openTooltip();
			setOpen(now);
			if (now !== undefined) {
				setShown(now);
			}
		};
		listener();
		return subscribeTooltip(listener);
	}, []);
	React.useEffect(() => {
		if (!enabled) {
			closeTooltip();
			setShown(undefined);
		}
	}, [enabled]);
	const playerGui = Players.LocalPlayer?.FindFirstChildOfClass("PlayerGui");
	return (
		<>
			{props.children}
			{playerGui !== undefined &&
				ReactRoblox.createPortal(
					<screengui
						key="AstralForgeTooltips"
						DisplayOrder={9000}
						IgnoreGuiInset={true}
						ResetOnSpawn={false}
						ZIndexBehavior={Enum.ZIndexBehavior.Sibling}
					>
						{enabled && shown !== undefined && (
							<Bubble
								key={`tip${shown.id}`}
								tip={shown}
								leaving={open === undefined || open.id !== shown.id}
								reducedMotion={props.reducedMotion === true}
								onGone={onGone}
							/>
						)}
					</screengui>,
					playerGui,
				)}
			{playerGui !== undefined &&
				ReactRoblox.createPortal(
					<screengui
						key="AstralForgeTooltipSafeArea"
						DisplayOrder={8999}
						IgnoreGuiInset={true}
						ScreenInsets={Enum.ScreenInsets.DeviceSafeInsets}
						ResetOnSpawn={false}
					>
						<frame
							Size={UDim2.fromScale(1, 1)}
							BackgroundTransparency={1}
							Active={false}
							Selectable={false}
							ref={(rbx: Frame | undefined) => {
								safeArea = rbx;
							}}
						/>
					</screengui>,
					playerGui,
				)}
		</>
	);
}

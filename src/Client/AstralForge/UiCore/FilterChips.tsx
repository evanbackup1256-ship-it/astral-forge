// Filter chips: one row of squared tabs sharing a single sliding "plate" that marks the
// active filter. The plate is measured from the real chip frames, so labels of any width
// work, and it moves on two springs (a quick lead edge and a lagging tail) so a switch
// reads as the plate being pulled across rather than a colour swap. Counts sit in a small
// notched tag at the chip's right edge. Idle rows cost nothing: springs settle and stop.
import React from "@rbxts/react";
import ArtKit = require("../ArtKit");
import { useFlipperSpring } from "../MotionKit/motion";
import { joinTuple } from "../lua";
import { Palette, contrastOn, darken, lighten } from "../CoreKit/theme";

type LooseComponent = React.FunctionComponent<Record<string, unknown>>;
const Icon = (ArtKit("Icon") as { Icon: LooseComponent }).Icon;

export const FILTER_CHIP_H = 32;
const RADIUS = 7;
const RAIL_H = 3;
const BUILDER = "rbxasset://fonts/families/BuilderSans.json";

export interface FilterChipOption {
	id: string;
	label: string;
	icon?: string;
	accent?: Color3;
}

interface ChipProps {
	option: FilterChipOption;
	count?: number;
	selected: boolean;
	accent: Color3;
	onSelect?: (this: void, id: string) => void;
	order: number;
	zIndex: number;
	chipRef: (this: void, id: string, frame: TextButton | undefined) => void;
}

function FilterChip(props: ChipProps) {
	const [hovered, setHovered] = React.useState(false);
	const { option, count, selected, accent, zIndex } = props;
	const empty = count === 0 && !selected;
	const ink = selected ? Palette.cream : empty ? Palette.muted : hovered ? Palette.cream : Palette.creamSoft;
	const hasCount = count !== undefined;
	return (
		<textbutton
			ref={(frame: TextButton | undefined) => props.chipRef(option.id, frame)}
			Size={UDim2.fromOffset(0, FILTER_CHIP_H)}
			AutomaticSize={Enum.AutomaticSize.X}
			BackgroundColor3={Palette.panelRaised}
			BackgroundTransparency={selected ? 1 : hovered ? 0.55 : 1}
			BorderSizePixel={0}
			AutoButtonColor={false}
			Selectable={true}
			Text=""
			LayoutOrder={props.order}
			ZIndex={zIndex + 2}
			Event={{
				Activated: () => props.onSelect?.(option.id),
				MouseEnter: () => setHovered(true),
				MouseLeave: () => setHovered(false),
				SelectionGained: () => setHovered(true),
				SelectionLost: () => setHovered(false),
			}}
		>
			<uicorner CornerRadius={new UDim(0, RADIUS)} />
			<uipadding PaddingLeft={new UDim(0, 12)} PaddingRight={new UDim(0, hasCount ? 5 : 12)} />
			<uilistlayout
				FillDirection={Enum.FillDirection.Horizontal}
				VerticalAlignment={Enum.VerticalAlignment.Center}
				SortOrder={Enum.SortOrder.LayoutOrder}
				Padding={new UDim(0, 7)}
			/>
			{option.icon !== undefined && (
				<frame Size={UDim2.fromOffset(15, 15)} BackgroundTransparency={1} LayoutOrder={0} ZIndex={zIndex + 3}>
					<Icon kind={option.icon} color={selected ? lighten(accent, 0.35) : ink} accent={accent} size={15} spin={false} />
				</frame>
			)}
			<textlabel
				Size={UDim2.fromOffset(0, FILTER_CHIP_H - RAIL_H)}
				AutomaticSize={Enum.AutomaticSize.X}
				BackgroundTransparency={1}
				Text={option.label}
				TextSize={13}
				FontFace={new Font(BUILDER, selected ? Enum.FontWeight.Heavy : Enum.FontWeight.SemiBold)}
				TextColor3={ink}
				LayoutOrder={1}
				ZIndex={zIndex + 3}
			/>
			{hasCount && (
				<frame
					Size={UDim2.fromOffset(0, 20)}
					AutomaticSize={Enum.AutomaticSize.X}
					BackgroundColor3={selected ? accent : Palette.ink}
					BackgroundTransparency={selected ? 0.05 : empty ? 0.7 : 0.4}
					BorderSizePixel={0}
					LayoutOrder={2}
					ZIndex={zIndex + 3}
				>
					<uicorner CornerRadius={new UDim(0, 4)} />
					<uipadding PaddingLeft={new UDim(0, 6)} PaddingRight={new UDim(0, 6)} />
					<uisizeconstraint MinSize={new Vector2(20, 20)} />
					<textlabel
						Size={UDim2.fromScale(0, 1)}
						AutomaticSize={Enum.AutomaticSize.X}
						BackgroundTransparency={1}
						Text={tostring(count)}
						TextSize={12}
						FontFace={new Font(BUILDER, Enum.FontWeight.Bold)}
						TextColor3={selected ? contrastOn(accent) : empty ? Palette.muted : Palette.creamSoft}
						ZIndex={zIndex + 4}
					/>
				</frame>
			)}
		</textbutton>
	);
}

/** Moving selection plate; lives beside the chip list so the list layout never places it. */
function SelectionPlate(props: { left: number; top?: number; width: number; visible: boolean; accent: Color3; zIndex: number }) {
	const top = props.top ?? 0;
	const lead = useFlipperSpring(props.left, false, 980, 44);
	const tail = useFlipperSpring(props.left, false, 420, 34);
	const width = useFlipperSpring(props.width, false, 700, 40);
	const span = joinTuple<[number, number, number]>(lead, tail, width);
	const position = span.map(([a, b]) => UDim2.fromOffset(math.min(a, b), top));
	const size = span.map(([a, b, w]) => UDim2.fromOffset(w + math.abs(a - b), FILTER_CHIP_H));
	const accent = props.accent;
	return (
		<frame
			Position={position}
			Size={size}
			BackgroundColor3={darken(accent, 0.35)}
			BackgroundTransparency={0.55}
			BorderSizePixel={0}
			Visible={props.visible}
			Active={false}
			ZIndex={props.zIndex + 1}
		>
			<uicorner CornerRadius={new UDim(0, RADIUS)} />
			<uistroke ApplyStrokeMode={Enum.ApplyStrokeMode.Border} Color={accent} Thickness={1} Transparency={0.35} />
			<uigradient Transparency={new NumberSequence(0.35, 0)} Rotation={90} />
			<frame
				Size={new UDim2(1, -10, 0, RAIL_H)}
				Position={new UDim2(0.5, 0, 1, -1)}
				AnchorPoint={new Vector2(0.5, 1)}
				BackgroundColor3={lighten(accent, 0.18)}
				BorderSizePixel={0}
				ZIndex={props.zIndex + 2}
			>
				<uicorner CornerRadius={new UDim(0, 2)} />
			</frame>
		</frame>
	);
}

export interface FilterChipRowProps {
	options?: ReadonlyArray<FilterChipOption>;
	value?: string;
	onChange?: (this: void, id: string) => void;
	counts?: Record<string, number>;
	accent?: Color3;
	fadeColor?: Color3;
	position?: UDim2;
	size?: UDim2;
	layoutOrder?: number;
	zIndex?: number;
	/** wrap chips onto extra lines instead of scrolling (narrow side columns) */
	wrap?: boolean;
}

/** The one filter-chip row used by every list page. Scrolls sideways when the chips don't fit. */
export function FilterChipRow(props: FilterChipRowProps) {
	const zIndex = props.zIndex ?? 6;
	const options = props.options ?? [];
	const rowRef = React.useRef<ScrollingFrame>();
	const listRef = React.useRef<Frame>();
	const chips = React.useRef(new Map<string, TextButton>());
	const [plate, setPlate] = React.useState({ left: 0, top: 0, width: 0, visible: false });
	const [fades, setFades] = React.useState({ left: false, right: false });
	let selectedAccent = props.accent ?? Palette.cyan;
	for (const option of options) {
		if (option.id === props.value && option.accent !== undefined) {
			selectedAccent = option.accent;
		}
	}

	const measurePlate = React.useCallback(() => {
		const list = listRef.current;
		const chip = props.value !== undefined ? chips.current.get(props.value) : undefined;
		if (list === undefined || chip === undefined || chip.Parent === undefined) {
			setPlate((current) => (current.visible ? { ...current, visible: false } : current));
			return;
		}
		const left = math.round(chip.AbsolutePosition.X - list.AbsolutePosition.X);
		const top = math.round(chip.AbsolutePosition.Y - list.AbsolutePosition.Y);
		const width = math.round(chip.AbsoluteSize.X);
		setPlate((current) =>
			current.visible && current.left === left && current.top === top && current.width === width ? current : { left, top, width, visible: true },
		);
	}, [props.value]);

	const chipRef = React.useCallback((id: string, frame: TextButton | undefined) => {
		if (frame === undefined) {
			chips.current.delete(id);
		} else {
			chips.current.set(id, frame);
		}
	}, []);

	React.useEffect(() => {
		measurePlate();
		const chip = props.value !== undefined ? chips.current.get(props.value) : undefined;
		const list = listRef.current;
		if (chip === undefined || list === undefined) {
			return undefined;
		}
		const a = chip.GetPropertyChangedSignal("AbsoluteSize").Connect(measurePlate);
		const b = chip.GetPropertyChangedSignal("AbsolutePosition").Connect(measurePlate);
		// keep the active chip in view when it changes from outside (or sits past the edge)
		const row = rowRef.current;
		if (row !== undefined) {
			const left = chip.AbsolutePosition.X - list.AbsolutePosition.X;
			const view = row.AbsoluteSize.X;
			const current = row.CanvasPosition.X;
			if (left < current || left + chip.AbsoluteSize.X > current + view) {
				row.CanvasPosition = new Vector2(math.max(0, left - (view - chip.AbsoluteSize.X) / 2), 0);
			}
		}
		return () => {
			a.Disconnect();
			b.Disconnect();
		};
	}, [measurePlate, options.size()]);

	React.useEffect(() => {
		const row = rowRef.current;
		if (row === undefined) {
			return undefined;
		}
		const measure = () => {
			const spare = row.AbsoluteCanvasSize.X - row.AbsoluteSize.X;
			const left = spare > 2 && row.CanvasPosition.X > 2;
			const right = spare > 2 && row.CanvasPosition.X < spare - 2;
			setFades((current) => (current.left === left && current.right === right ? current : { left, right }));
		};
		measure();
		const a = row.GetPropertyChangedSignal("AbsoluteCanvasSize").Connect(measure);
		const b = row.GetPropertyChangedSignal("AbsoluteSize").Connect(measure);
		const c = row.GetPropertyChangedSignal("CanvasPosition").Connect(measure);
		return () => {
			a.Disconnect();
			b.Disconnect();
			c.Disconnect();
		};
	}, []);

	const edgeFade = (side: "left" | "right") => (
		<frame
			Size={new UDim2(0, 34, 1, 0)}
			Position={side === "right" ? UDim2.fromScale(1, 0) : UDim2.fromScale(0, 0)}
			AnchorPoint={side === "right" ? new Vector2(1, 0) : Vector2.zero}
			BackgroundColor3={props.fadeColor ?? Palette.panel}
			BorderSizePixel={0}
			Active={false}
			ZIndex={zIndex + 6}
		>
			<uigradient Transparency={new NumberSequence(1, 0)} Rotation={side === "right" ? 0 : 180} />
		</frame>
	);

	return (
		<frame
			Size={props.size ?? new UDim2(1, 0, 0, FILTER_CHIP_H)}
			Position={props.position}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			LayoutOrder={props.layoutOrder}
			ZIndex={zIndex}
		>
			<scrollingframe
				ref={rowRef}
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				CanvasSize={new UDim2()}
				AutomaticCanvasSize={props.wrap === true ? Enum.AutomaticSize.None : Enum.AutomaticSize.X}
				ScrollingDirection={Enum.ScrollingDirection.X}
				ScrollingEnabled={props.wrap !== true}
				ScrollBarThickness={0}
				ElasticBehavior={Enum.ElasticBehavior.WhenScrollable}
				ClipsDescendants={true}
				ZIndex={zIndex}
			>
				{/* hairline track the chips sit on, so unselected chips still read as one control */}
				<frame
					Size={new UDim2(1, 0, 0, 1)}
					Position={new UDim2(0, 0, 1, -1)}
					BackgroundColor3={Palette.lineSoft}
					BackgroundTransparency={0.6}
					BorderSizePixel={0}
					ZIndex={zIndex}
				/>
				<frame
					ref={listRef}
					Size={props.wrap === true ? UDim2.fromScale(1, 1) : new UDim2(0, 0, 1, 0)}
					AutomaticSize={props.wrap === true ? Enum.AutomaticSize.None : Enum.AutomaticSize.X}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					ZIndex={zIndex}
				>
					<SelectionPlate left={plate.left} top={plate.top} width={plate.width} visible={plate.visible} accent={selectedAccent} zIndex={zIndex} />
					<frame Size={props.wrap === true ? UDim2.fromScale(1, 1) : new UDim2(0, 0, 1, 0)} AutomaticSize={props.wrap === true ? Enum.AutomaticSize.None : Enum.AutomaticSize.X} BackgroundTransparency={1} ZIndex={zIndex + 2}>
						<uilistlayout
							Wraps={props.wrap === true}
							FillDirection={Enum.FillDirection.Horizontal}
							VerticalAlignment={props.wrap === true ? Enum.VerticalAlignment.Top : Enum.VerticalAlignment.Center}
							SortOrder={Enum.SortOrder.LayoutOrder}
							Padding={new UDim(0, 4)}
						/>
						{options.map((option, index) => (
							<FilterChip
								key={option.id}
								option={option}
								count={props.counts !== undefined ? props.counts[option.id] : undefined}
								selected={option.id === props.value}
								accent={option.accent ?? props.accent ?? Palette.cyan}
								onSelect={props.onChange}
								order={index}
								zIndex={zIndex}
								chipRef={chipRef}
							/>
						))}
					</frame>
				</frame>
			</scrollingframe>
			{fades.right && edgeFade("right")}
			{fades.left && edgeFade("left")}
		</frame>
	);
}

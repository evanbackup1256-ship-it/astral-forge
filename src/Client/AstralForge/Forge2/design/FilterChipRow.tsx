// FilterChipRow, rebuilt for Forge2: one row of filter chips sharing a single brass plate that
// slides to the active chip. The plate is measured from the real chip frames, and rides two
// springs (a quick lead edge and a lagging tail) so a switch reads as the plate being pulled
// across. Counts sit in a small tag inside each chip. The row scrolls sideways when it can't fit,
// with soft edge fades, and keeps the active chip in view. Every chip is a full 44px target.
import React from "@rbxts/react";
import { useFlipperSpring } from "../../MotionKit/motion";
import { RainbowGradient } from "../../UiCore/rainbowFx";
import { joinTuple } from "../../lua";
import { Corner, Fonts, HIT, Iron } from "./tokens";

export interface FilterOption {
	id: string;
	label: string;
	accent?: Color3;
}

export interface FilterChipRowProps {
	options: ReadonlyArray<FilterOption>;
	value: string;
	onChange: (id: string) => void;
	counts?: Record<string, number>;
	accent?: Color3;
	order?: number;
	/** colour the edge fades blend into (the surface behind the row) */
	fade?: Color3;
}

function FilterChip(props: {
	option: FilterOption;
	count?: number;
	selected: boolean;
	accent: Color3;
	order: number;
	onPick: (id: string) => void;
	bind: (id: string, chip: TextButton | undefined) => void;
}) {
	const [hover, setHover] = React.useState(false);
	const empty = props.count === 0 && !props.selected;
	const ink = props.selected || hover ? Iron.text() : empty ? Iron.muted() : Iron.soft();
	return (
		<textbutton
			ref={(chip: TextButton | undefined) => props.bind(props.option.id, chip)}
			Size={UDim2.fromOffset(0, HIT)}
			AutomaticSize={Enum.AutomaticSize.X}
			BackgroundColor3={Iron.raised()}
			BackgroundTransparency={hover && !props.selected ? 0.6 : 1}
			BorderSizePixel={0}
			AutoButtonColor={false}
			Selectable
			Text=""
			LayoutOrder={props.order}
			ZIndex={3}
			Event={{
				Activated: () => props.onPick(props.option.id),
				MouseEnter: () => setHover(true),
				MouseLeave: () => setHover(false),
				SelectionGained: () => setHover(true),
				SelectionLost: () => setHover(false),
			}}
		>
			<uicorner CornerRadius={new UDim(0, Corner.card)} />
			<uipadding PaddingLeft={new UDim(0, 16)} PaddingRight={new UDim(0, props.count !== undefined ? 8 : 16)} />
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 8)} />
			<textlabel
				Size={UDim2.fromOffset(0, HIT - 4)}
				AutomaticSize={Enum.AutomaticSize.X}
				BackgroundTransparency={1}
				Text={props.option.label}
				TextSize={15}
				FontFace={props.selected ? Fonts.heavy : Fonts.bold}
				TextColor3={ink}
				LayoutOrder={0}
				ZIndex={4}
			/>
			{props.count !== undefined && (
				<frame
					Size={UDim2.fromOffset(0, 22)}
					AutomaticSize={Enum.AutomaticSize.X}
					BackgroundColor3={props.selected ? props.accent : Iron.sunk()}
					BackgroundTransparency={props.selected ? 0.05 : empty ? 0.7 : 0.35}
					BorderSizePixel={0}
					LayoutOrder={1}
					ZIndex={4}
				>
					<uicorner CornerRadius={new UDim(0, Corner.chip)} />
					<uipadding PaddingLeft={new UDim(0, 7)} PaddingRight={new UDim(0, 7)} />
					<uisizeconstraint MinSize={new Vector2(22, 22)} />
					<textlabel
						Size={UDim2.fromScale(0, 1)}
						AutomaticSize={Enum.AutomaticSize.X}
						BackgroundTransparency={1}
						Text={tostring(props.count)}
						TextSize={13}
						FontFace={Fonts.heavy}
						TextColor3={props.selected ? Iron.sunk() : empty ? Iron.muted() : Iron.soft()}
						ZIndex={5}
					/>
				</frame>
			)}
		</textbutton>
	);
}

/** The sliding plate: lead + tail springs stretch it as it travels, a rainbow rail rides its foot. */
function Plate(props: { left: number; width: number; visible: boolean; accent: Color3 }) {
	const lead = useFlipperSpring(props.left, false, 980, 44);
	const tail = useFlipperSpring(props.left, false, 420, 34);
	const width = useFlipperSpring(props.width, false, 700, 40);
	const span = joinTuple<[number, number, number]>(lead, tail, width);
	return (
		<frame
			Position={span.map(([a, b]) => UDim2.fromOffset(math.min(a, b), 0))}
			Size={span.map(([a, b, w]) => UDim2.fromOffset(w + math.abs(a - b), HIT))}
			BackgroundColor3={Iron.raised()}
			BackgroundTransparency={0.1}
			BorderSizePixel={0}
			Visible={props.visible}
			Active={false}
			ZIndex={2}
		>
			<uicorner CornerRadius={new UDim(0, Corner.card)} />
			<uistroke ApplyStrokeMode={Enum.ApplyStrokeMode.Border} Color={props.accent} Thickness={1} Transparency={0.35} />
			<frame
				Size={new UDim2(1, -14, 0, 3)}
				Position={new UDim2(0.5, 0, 1, -2)}
				AnchorPoint={new Vector2(0.5, 1)}
				BackgroundColor3={Color3.fromRGB(255, 255, 255)}
				BorderSizePixel={0}
				ZIndex={3}
			>
				<uicorner CornerRadius={new UDim(0, 2)} />
				<RainbowGradient base={props.accent} state={{ selected: true, active: true }} style="flow" />
			</frame>
		</frame>
	);
}

export function FilterChipRow(props: FilterChipRowProps) {
	const rowRef = React.useRef<ScrollingFrame>();
	const listRef = React.useRef<Frame>();
	const chips = React.useRef(new Map<string, TextButton>());
	const [plate, setPlate] = React.useState({ left: 0, width: 0, visible: false });
	const [fades, setFades] = React.useState({ left: false, right: false });
	let accent = props.accent ?? Iron.brass();
	for (const option of props.options) {
		if (option.id === props.value && option.accent !== undefined) accent = option.accent;
	}

	const measure = React.useCallback(() => {
		const list = listRef.current;
		const chip = chips.current.get(props.value);
		if (list === undefined || chip === undefined || chip.Parent === undefined) {
			setPlate((current) => (current.visible ? { ...current, visible: false } : current));
			return;
		}
		const left = math.round(chip.AbsolutePosition.X - list.AbsolutePosition.X);
		const width = math.round(chip.AbsoluteSize.X);
		setPlate((current) => (current.visible && current.left === left && current.width === width ? current : { left, width, visible: true }));
	}, [props.value]);

	const bind = React.useCallback((id: string, chip: TextButton | undefined) => {
		if (chip === undefined) chips.current.delete(id);
		else chips.current.set(id, chip);
	}, []);

	React.useEffect(() => {
		measure();
		const chip = chips.current.get(props.value);
		const list = listRef.current;
		if (chip === undefined || list === undefined) return undefined;
		const a = chip.GetPropertyChangedSignal("AbsoluteSize").Connect(measure);
		const b = chip.GetPropertyChangedSignal("AbsolutePosition").Connect(measure);
		const row = rowRef.current;
		if (row !== undefined) {
			const left = chip.AbsolutePosition.X - list.AbsolutePosition.X;
			const view = row.AbsoluteSize.X;
			const at = row.CanvasPosition.X;
			if (left < at || left + chip.AbsoluteSize.X > at + view) {
				row.CanvasPosition = new Vector2(math.max(0, left - (view - chip.AbsoluteSize.X) / 2), 0);
			}
		}
		return () => {
			a.Disconnect();
			b.Disconnect();
		};
	}, [measure, props.options.size()]);

	React.useEffect(() => {
		const row = rowRef.current;
		if (row === undefined) return undefined;
		const check = () => {
			const spare = row.AbsoluteCanvasSize.X - row.AbsoluteSize.X;
			const left = spare > 2 && row.CanvasPosition.X > 2;
			const right = spare > 2 && row.CanvasPosition.X < spare - 2;
			setFades((current) => (current.left === left && current.right === right ? current : { left, right }));
		};
		check();
		const links = [
			row.GetPropertyChangedSignal("AbsoluteCanvasSize").Connect(check),
			row.GetPropertyChangedSignal("AbsoluteSize").Connect(check),
			row.GetPropertyChangedSignal("CanvasPosition").Connect(check),
		];
		return () => links.forEach((link) => link.Disconnect());
	}, []);

	const edge = (side: "left" | "right") => (
		<frame
			key={`Fade${side}`}
			Size={new UDim2(0, 36, 1, 0)}
			Position={side === "right" ? UDim2.fromScale(1, 0) : UDim2.fromScale(0, 0)}
			AnchorPoint={side === "right" ? new Vector2(1, 0) : Vector2.zero}
			BackgroundColor3={props.fade ?? Iron.void()}
			BorderSizePixel={0}
			Active={false}
			ZIndex={8}
		>
			<uigradient Transparency={new NumberSequence(1, 0)} Rotation={side === "right" ? 0 : 180} />
		</frame>
	);

	return (
		<frame Size={new UDim2(1, 0, 0, HIT)} BackgroundTransparency={1} LayoutOrder={props.order ?? 0}>
			<scrollingframe
				ref={rowRef}
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				CanvasSize={new UDim2()}
				AutomaticCanvasSize={Enum.AutomaticSize.X}
				ScrollingDirection={Enum.ScrollingDirection.X}
				ScrollBarThickness={0}
				ElasticBehavior={Enum.ElasticBehavior.WhenScrollable}
				ClipsDescendants
			>
				<frame Size={new UDim2(1, 0, 0, 1)} Position={new UDim2(0, 0, 1, -1)} BackgroundColor3={Iron.edge()} BackgroundTransparency={0.6} BorderSizePixel={0} />
				<frame ref={listRef} Size={new UDim2(0, 0, 1, 0)} AutomaticSize={Enum.AutomaticSize.X} BackgroundTransparency={1}>
					<Plate left={plate.left} width={plate.width} visible={plate.visible} accent={accent} />
					<frame Size={new UDim2(0, 0, 1, 0)} AutomaticSize={Enum.AutomaticSize.X} BackgroundTransparency={1} ZIndex={3}>
						<uilistlayout FillDirection={Enum.FillDirection.Horizontal} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 6)} />
						{props.options.map((option, index) => (
							<FilterChip
								key={option.id}
								option={option}
								count={props.counts?.[option.id]}
								selected={option.id === props.value}
								accent={option.accent ?? accent}
								order={index}
								onPick={props.onChange}
								bind={bind}
							/>
						))}
					</frame>
				</frame>
			</scrollingframe>
			{fades.right && edge("right")}
			{fades.left && edge("left")}
		</frame>
	);
}

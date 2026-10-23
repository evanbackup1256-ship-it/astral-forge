// Purpose: the Inventory relic card, built to design/04-inventory (.sc in design/system/af.css).
// Desktop (1920x1080): 176px wide, 16px corners, 8px padding (12 below), a square art well with 11px
// corners and a rarity glow, 6px gaps, a 15px bold name and a 10px uppercase tag pill in the rarity
// colour. Phone (844x390): 104px wide, 5px padding (7 below), 3px gaps, 11px name, 8px tag.
// The rim is the shared RarityRim; the art is the shared ElementFx sheet, so motion and shimmer are
// the same as everywhere else. Selected = the .sc.on ring (2.5px rarity stroke + brass rule) and the
// usual 4px lift spring.
// Owner: presentation. Dependencies: ElementFx, UiCore/ui, UiCore/effectsLayer, CoreKit/theme.
import React from "@rbxts/react";
import Fx = require("../../ElementFx");
import { useFlipperSpring } from "../../MotionKit/motion";
import { Palette } from "../../CoreKit/theme";
import { IconTile, Text } from "../../UiCore/ui";
import { FxTokens, RarityRim } from "../../UiCore/effectsLayer";

export interface RelicCardMetrics {
	width: number;
	height: number;
	pad: number;
	padBottom: number;
	gap: number;
	well: number;
	nameSize: number;
	nameH: number;
	tagSize: number;
	tagH: number;
	radius: number;
}

const DESKTOP: RelicCardMetrics = {
	width: 176,
	height: 226,
	pad: 8,
	padBottom: 12,
	gap: 6,
	well: 160,
	nameSize: 15,
	nameH: 19,
	tagSize: 10,
	tagH: 15,
	radius: 16,
};
const PHONE: RelicCardMetrics = {
	width: 104,
	height: 136,
	pad: 5,
	padBottom: 7,
	gap: 3,
	well: 94,
	nameSize: 11,
	nameH: 14,
	tagSize: 8,
	tagH: 10,
	radius: 16,
};

export function relicCardMetrics(phone: boolean): RelicCardMetrics {
	return phone ? PHONE : DESKTOP;
}

export interface RelicCardProps {
	name: string;
	rarity: string;
	color: Color3;
	element?: string;
	iconKind?: string;
	selected?: boolean;
	/** bulk pick: the ring turns coral */
	picked?: boolean;
	dim?: boolean;
	tag?: string;
	tagColor?: Color3;
	animate?: boolean;
	reducedMotion?: boolean;
	phone?: boolean;
	layoutOrder?: number;
	onSelect?: () => void;
	events?: Record<string, unknown>;
}

const CARD_TOP = Color3.fromHex("221A25");
const CARD_BOTTOM = Color3.fromHex("120D14");
const WELL = Color3.fromHex("0D090F");

export function InventoryRelicCard(props: RelicCardProps) {
	const m = relicCardMetrics(props.phone === true);
	const selected = props.selected === true || props.picked === true;
	const ring = props.picked === true ? Palette.coral : props.color;
	const [hover, setHover] = React.useState(false);
	const lift = useFlipperSpring(selected ? 1 : 0, props.reducedMotion);
	const hasSheet = props.element !== undefined && Fx.sheet(props.element) !== undefined;
	const events = (props.events ?? {}) as Record<string, (...args: unknown[]) => void>;
	const tagW = math.min(m.width - m.pad * 2, math.ceil(props.rarity.size() * (m.tagSize * 0.78 + 1.6)) + 16);
	return (
		<frame
			Size={UDim2.fromOffset(m.width, m.height)}
			LayoutOrder={props.layoutOrder}
			BackgroundTransparency={1}
			BorderSizePixel={0}
		>
			<imagebutton
				Size={UDim2.fromScale(1, 1)}
				Position={lift.map((amount) => UDim2.fromOffset(0, -FxTokens.selectedLift * amount))}
				BackgroundColor3={new Color3(1, 1, 1)}
				BorderSizePixel={0}
				AutoButtonColor={false}
				Selectable={true}
				Event={{
					Activated: () => props.onSelect?.(),
					MouseEnter: (rbx: ImageButton) => {
						setHover(true);
						events.MouseEnter?.(rbx);
					},
					MouseLeave: (rbx: ImageButton) => {
						setHover(false);
						events.MouseLeave?.(rbx);
					},
					SelectionGained: (rbx: ImageButton) => {
						setHover(true);
						events.SelectionGained?.(rbx);
					},
					SelectionLost: (rbx: ImageButton) => {
						setHover(false);
						events.SelectionLost?.(rbx);
					},
					InputBegan: (rbx: ImageButton, input: InputObject) => events.InputBegan?.(rbx, input),
					InputEnded: (rbx: ImageButton, input: InputObject) => events.InputEnded?.(rbx, input),
				}}
			>
				<uicorner CornerRadius={new UDim(0, m.radius)} />
				{/* linear-gradient(180deg, rarity 16% over #221a25, #120d14 70%) */}
				<uigradient
					Rotation={90}
					Color={
						new ColorSequence([
							new ColorSequenceKeypoint(0, CARD_TOP.Lerp(props.color, hover ? 0.22 : 0.16)),
							new ColorSequenceKeypoint(0.7, CARD_BOTTOM),
							new ColorSequenceKeypoint(1, CARD_BOTTOM),
						])
					}
				/>
				<RarityRim rarity={props.rarity} corner={m.radius} selected={selected} />
				{selected && (
					// .sc.on: a 2.5px ring in the rarity colour (coral while bulk picking)
					<frame
						AnchorPoint={new Vector2(0.5, 0.5)}
						Position={UDim2.fromScale(0.5, 0.5)}
						Size={new UDim2(1, -1, 1, -1)}
						BackgroundTransparency={1}
						BorderSizePixel={0}
						ZIndex={4}
					>
						<uicorner CornerRadius={new UDim(0, m.radius)} />
						<uistroke Color={ring} Thickness={2.5} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
					</frame>
				)}
				{/* art well: 1:1, #0d090f lit from 55% down in the rarity colour */}
				<frame
					Size={UDim2.fromOffset(m.well, m.well)}
					Position={UDim2.fromOffset(m.pad, m.pad)}
					BackgroundColor3={WELL}
					BorderSizePixel={0}
					ClipsDescendants={true}
				>
					<uicorner CornerRadius={new UDim(0, 11)} />
					<frame
						AnchorPoint={new Vector2(0.5, 0.5)}
						Position={UDim2.fromScale(0.5, 0.55)}
						Size={UDim2.fromScale(1.1, 1.1)}
						BackgroundColor3={props.color}
						BackgroundTransparency={0.78}
						BorderSizePixel={0}
					>
						<uicorner CornerRadius={new UDim(1, 0)} />
						<uigradient
							Transparency={
								new NumberSequence([
									new NumberSequenceKeypoint(0, 0),
									new NumberSequenceKeypoint(0.7, 1),
									new NumberSequenceKeypoint(1, 1),
								])
							}
						/>
					</frame>
					{hasSheet ? (
						<Fx.ElementFx
							element={props.element!}
							size={UDim2.fromScale(1.12, 1.12)}
							still={props.animate === false}
							reducedMotion={props.reducedMotion}
							reaction="select"
							reactionKey={selected}
							transparency={props.dim ? 0.45 : 0}
						/>
					) : (
						<IconTile
							kind={props.iconKind ?? "Loadout"}
							accent={props.color}
							size={math.floor(m.well * 0.42)}
							radius={12}
							position={UDim2.fromScale(0.5, 0.5)}
							anchorPoint={new Vector2(0.5, 0.5)}
							spin={false}
							still={props.animate === false}
							glow={selected}
							reducedMotion={props.reducedMotion}
						/>
					)}
				</frame>
				<Text
					value={props.name}
					size={m.nameSize}
					color={props.dim ? Palette.muted : Palette.cream}
					weight={Enum.FontWeight.Bold}
					align={Enum.TextXAlignment.Center}
					fit={true}
					minSize={math.max(9, m.nameSize - 3)}
					position={UDim2.fromOffset(m.pad, m.pad + m.well + m.gap)}
					sizeConstraint={new UDim2(1, -m.pad * 2, 0, m.nameH)}
				/>
				<frame
					AnchorPoint={new Vector2(0.5, 1)}
					Size={UDim2.fromOffset(tagW, m.tagH)}
					Position={new UDim2(0.5, 0, 1, -m.padBottom)}
					BackgroundColor3={props.color}
					BackgroundTransparency={props.dim ? 0.5 : 0}
					BorderSizePixel={0}
				>
					<uicorner CornerRadius={new UDim(0, 5)} />
					<Text
						value={props.rarity.upper()}
						size={m.tagSize}
						color={FxTokens.ink}
						weight={Enum.FontWeight.ExtraBold}
						align={Enum.TextXAlignment.Center}
						fit={true}
						minSize={7}
						sizeConstraint={UDim2.fromScale(1, 1)}
					/>
				</frame>
				{props.tag !== undefined && (
					// .lv corner chip: top-left, 13px numerals on rgba(12,9,14,.8) with a brass hairline
					<frame
						Size={UDim2.fromOffset(props.phone ? 30 : 40, props.phone ? 15 : 20)}
						Position={UDim2.fromOffset(props.phone ? 9 : 14, props.phone ? 9 : 14)}
						BackgroundColor3={FxTokens.ink}
						BackgroundTransparency={0.2}
						BorderSizePixel={0}
						ZIndex={3}
					>
						<uicorner CornerRadius={new UDim(0, 6)} />
						<uistroke Color={props.tagColor ?? FxTokens.brass} Thickness={1} Transparency={0.35} />
						<Text
							value={props.tag}
							size={props.phone ? 10 : 13}
							color={props.tagColor ?? Palette.cream}
							weight={Enum.FontWeight.Bold}
							align={Enum.TextXAlignment.Center}
							fit={true}
							minSize={8}
							sizeConstraint={UDim2.fromScale(1, 1)}
							zIndex={3}
						/>
					</frame>
				)}
			</imagebutton>
		</frame>
	);
}

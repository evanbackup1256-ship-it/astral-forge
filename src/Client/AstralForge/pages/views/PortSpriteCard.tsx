// Purpose: the port brief's sprite card (.sc), page-local until the shared UiCore/SpriteCard lands.
// A live element sheet (Shared/ElementSprites through ElementFx: 6x6, 36 frames, 24 fps, FRAME 170.5)
// or the item's icon when it has no element, a 1.5 px rarity stroke, the name and a rarity tag.
// Selected = stroke alpha 1 plus a 4 px lift. `animate` false shows frame 0 (cards outside the view).
// Owner: presentation. Dependencies: ElementFx, UiCore/ui, CoreKit/theme. Review: 2026-10-22.
import React from "@rbxts/react";
import Fx = require("../../ElementFx");
import { useFlipperSpring } from "../../MotionKit/motion";
import { Palette } from "../../CoreKit/theme";
import { IconTile, Text } from "../../UiCore/ui";

export const SPRITE_CARD_W = 104;
export const SPRITE_CARD_H = 132;
export const SPRITE_CARD_GAP = 10;

export interface SpriteCardProps {
	name: string;
	rarity: string;
	color: Color3;
	element?: string;
	iconKind?: string;
	selected?: boolean;
	dim?: boolean;
	tag?: string;
	tagColor?: Color3;
	animate?: boolean;
	reducedMotion?: boolean;
	size?: UDim2;
	position?: UDim2;
	layoutOrder?: number;
	onSelect?: () => void;
	events?: Record<string, unknown>;
}

// how many cards fit across `width`, never fewer than `min`
export function spriteCardColumns(width: number, min = 2, cardW = SPRITE_CARD_W, gap = SPRITE_CARD_GAP): number {
	return math.max(min, math.floor((width + gap) / (cardW + gap)));
}

function sentence(value: string): string {
	const lower = value.lower();
	return lower.sub(1, 1).upper() + lower.sub(2);
}

export function SpriteCard(props: SpriteCardProps) {
	const selected = props.selected === true;
	const [hover, setHover] = React.useState(false);
	const lift = useFlipperSpring(selected ? 1 : 0, props.reducedMotion);
	const hasSheet = props.element !== undefined && Fx.sheet(props.element) !== undefined;
	const events = (props.events ?? {}) as Record<string, (...args: unknown[]) => void>;
	return (
		<frame
			Size={props.size ?? UDim2.fromOffset(SPRITE_CARD_W, SPRITE_CARD_H)}
			Position={props.position}
			LayoutOrder={props.layoutOrder}
			BackgroundTransparency={1}
			BorderSizePixel={0}
		>
			<imagebutton
				Size={UDim2.fromScale(1, 1)}
				Position={lift.map((amount) => UDim2.fromOffset(0, -4 * amount))}
				BackgroundColor3={Palette.panel.Lerp(props.color, selected ? 0.14 : 0.06)}
				BackgroundTransparency={0}
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
				<uicorner CornerRadius={new UDim(0, 12)} />
				<uistroke
					Color={props.color}
					Thickness={1.5}
					Transparency={selected ? 0 : hover ? 0.2 : 0.45}
					ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
				/>
				<uigradient
					Rotation={90}
					Color={new ColorSequence(new Color3(1, 1, 1), Palette.ink.Lerp(new Color3(1, 1, 1), 0.55))}
				/>
				{/* art well: the sheet (or icon) sits on a darker plate, lit from the middle in the rarity colour */}
				<frame
					Size={new UDim2(1, -12, 1, -46)}
					Position={UDim2.fromOffset(6, 6)}
					BackgroundColor3={Palette.ink}
					BackgroundTransparency={0.15}
					BorderSizePixel={0}
					ClipsDescendants={true}
				>
					<uicorner CornerRadius={new UDim(0, 9)} />
					<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={props.color} BackgroundTransparency={0.78} BorderSizePixel={0}>
						<uigradient
							Transparency={
								new NumberSequence([
									new NumberSequenceKeypoint(0, 1),
									new NumberSequenceKeypoint(0.5, 0.2),
									new NumberSequenceKeypoint(1, 1),
								])
							}
						/>
					</frame>
					{hasSheet ? (
						<Fx.ElementFx
							element={props.element!}
							size={UDim2.fromScale(0.96, 0.96)}
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
							size={44}
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
					size={13}
					color={props.dim ? Palette.muted : Palette.cream}
					weight={Enum.FontWeight.Bold}
					align={Enum.TextXAlignment.Center}
					fit={true}
					minSize={10}
					position={new UDim2(0, 6, 1, -38)}
					sizeConstraint={new UDim2(1, -12, 0, 16)}
				/>
				<frame
					AnchorPoint={new Vector2(0.5, 0)}
					Size={new UDim2(1, -24, 0, 14)}
					Position={new UDim2(0.5, 0, 1, -19)}
					BackgroundColor3={props.color}
					BackgroundTransparency={0.1}
					BorderSizePixel={0}
				>
					<uicorner CornerRadius={new UDim(0, 4)} />
					<uisizeconstraint MaxSize={new Vector2(84, 14)} />
					<Text
						value={sentence(props.rarity)}
						size={10}
						color={Palette.ink}
						weight={Enum.FontWeight.Heavy}
						align={Enum.TextXAlignment.Center}
						fit={true}
						minSize={8}
						sizeConstraint={UDim2.fromScale(1, 1)}
					/>
				</frame>
				{props.tag !== undefined && (
					<frame
						Size={UDim2.fromOffset(42, 16)}
						Position={new UDim2(1, -46, 0, 8)}
						BackgroundColor3={props.tagColor ?? Palette.mango}
						BorderSizePixel={0}
						ZIndex={3}
					>
						<uicorner CornerRadius={new UDim(0, 5)} />
						<Text
							value={props.tag}
							size={10}
							color={Palette.ink}
							weight={Enum.FontWeight.Heavy}
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

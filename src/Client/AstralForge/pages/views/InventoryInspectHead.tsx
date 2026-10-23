// Purpose: the top of the Inventory inspect panel and the grid panel's title row, built to
// design/04-inventory. Inspect: a 22px .pn h3 title (rarity glyph + name), a 260px art well
// (140px on phone) with 14px corners, a closest-side rarity glow on #0d090f and a 1.5px rarity ring,
// then three 48px .row stat lines (36px glyph box, 15px label, 17px value in the page accent).
// Owner: presentation. Dependencies: ElementFx, UiCore/ui, ArtKit/Icon, CoreKit/inventoryMath.
import React from "@rbxts/react";
import Fx = require("../../ElementFx");
import { Palette } from "../../CoreKit/theme";
import { Text } from "../../UiCore/ui";
import { Icon } from "../../ArtKit/Icon";
import {
	INSPECT_ART_H,
	INSPECT_ART_H_STACK,
	INSPECT_BTN_GAP,
	INSPECT_STAT_GAP,
	INSPECT_STAT_H,
	INSPECT_TITLE_H,
	InspectHeadHeight,
} from "../../CoreKit/inventoryMath";
import { GlyphWell } from "../../UiCore/mockKit";

const WELL = Color3.fromHex("0D090F");
const MUTED_ROW = Color3.fromHex("FFFFFF");

export interface InspectStat {
	icon: string;
	label: string;
	value: string;
}

/** .pn h3: an accent glyph, the title in the serif at 15px, and an optional muted note on the right */
export function PanelTitle(props: { icon: string; title: string; note?: string; accent: Color3; layoutOrder?: number; position?: UDim2 }) {
	return (
		<frame
			Size={new UDim2(1, 0, 0, INSPECT_TITLE_H)}
			Position={props.position}
			LayoutOrder={props.layoutOrder ?? 0}
			BackgroundTransparency={1}
			BorderSizePixel={0}
		>
			<Icon kind={props.icon} size={18} color={props.accent} accent={props.accent} still={true} position={new UDim2(0, 9, 0.5, 0)} anchorPoint={new Vector2(0.5, 0.5)} />
			<Text
				title={true}
				value={props.title.upper()}
				size={15}
				color={Palette.cream}
				weight={Enum.FontWeight.Bold}
				fit={true}
				minSize={12}
				position={UDim2.fromOffset(28, 0)}
				sizeConstraint={new UDim2(props.note !== undefined ? 0.6 : 1, -28, 1, 0)}
			/>
			{props.note !== undefined && (
				<Text
					value={props.note}
					size={12}
					color={Palette.muted}
					weight={Enum.FontWeight.SemiBold}
					align={Enum.TextXAlignment.Right}
					fit={true}
					minSize={10}
					position={new UDim2(0.6, 0, 0, 0)}
					sizeConstraint={new UDim2(0.4, 0, 1, 0)}
				/>
			)}
		</frame>
	);
}

function StatRow(props: InspectStat & { accent: Color3; y: number }) {
	return (
		<frame
			Size={new UDim2(1, 0, 0, INSPECT_STAT_H)}
			Position={UDim2.fromOffset(0, props.y)}
			BackgroundColor3={MUTED_ROW}
			BackgroundTransparency={0.965}
			BorderSizePixel={0}
		>
			<uicorner CornerRadius={new UDim(0, 11)} />
			<uistroke Color={MUTED_ROW} Thickness={1} Transparency={0.95} />
			<uigradient
				Rotation={90}
				Color={new ColorSequence(new Color3(1, 1, 1), new Color3(0, 0, 0))}
				Transparency={new NumberSequence(0.2, 0)}
			/>
			<frame
				Size={UDim2.fromOffset(36, 36)}
				Position={new UDim2(0, 12, 0.5, -18)}
				BackgroundColor3={new Color3(0, 0, 0)}
				BackgroundTransparency={0.65}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(0, 9)} />
				<uistroke Color={MUTED_ROW} Thickness={1} Transparency={0.92} />
				<Icon kind={props.icon} size={18} color={props.accent} accent={props.accent} still={true} position={UDim2.fromScale(0.5, 0.5)} anchorPoint={new Vector2(0.5, 0.5)} />
			</frame>
			<Text
				value={props.label}
				size={15}
				color={Palette.cream}
				weight={Enum.FontWeight.SemiBold}
				fit={true}
				minSize={12}
				position={new UDim2(0, 60, 0, 0)}
				sizeConstraint={new UDim2(0.45, -60, 1, 0)}
			/>
			<Text
				value={props.value}
				size={17}
				color={props.accent}
				weight={Enum.FontWeight.Bold}
				align={Enum.TextXAlignment.Right}
				fit={true}
				minSize={12}
				position={new UDim2(0.45, 0, 0, 0)}
				sizeConstraint={new UDim2(0.55, -12, 1, 0)}
			/>
		</frame>
	);
}

export interface InspectHeadProps {
	name: string;
	rarity: string;
	color: Color3;
	accent: Color3;
	element?: string;
	iconKind?: string;
	stats: InspectStat[];
	phone?: boolean;
	reducedMotion?: boolean;
	layoutOrder?: number;
}

export function InspectHead(props: InspectHeadProps) {
	const phone = props.phone === true;
	const artH = phone ? INSPECT_ART_H_STACK : INSPECT_ART_H;
	const artTop = INSPECT_TITLE_H + INSPECT_BTN_GAP;
	const statsTop = artTop + artH + INSPECT_BTN_GAP;
	const hasSheet = props.element !== undefined && Fx.sheet(props.element) !== undefined;
	// the mockup draws a 270px still in a 260px-tall well: art a touch taller than the well
	const artSize = math.floor(artH * 1.04);
	return (
		<frame
			Size={new UDim2(1, 0, 0, InspectHeadHeight(phone))}
			LayoutOrder={props.layoutOrder ?? -1}
			BackgroundTransparency={1}
			BorderSizePixel={0}
		>
			<PanelTitle icon="Artifact" title={props.name} note={props.rarity} accent={props.accent} />
			<frame
				Size={new UDim2(1, 0, 0, artH)}
				Position={UDim2.fromOffset(0, artTop)}
				BackgroundColor3={WELL}
				BorderSizePixel={0}
				ClipsDescendants={true}
			>
				<uicorner CornerRadius={new UDim(0, 14)} />
				<uistroke Color={props.color} Thickness={1.5} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
				{/* radial-gradient(closest-side, rarity at 14%, transparent) */}
				<frame
					AnchorPoint={new Vector2(0.5, 0.5)}
					Position={UDim2.fromScale(0.5, 0.5)}
					Size={UDim2.fromOffset(artH, artH)}
					BackgroundColor3={props.color}
					BackgroundTransparency={0.86}
					BorderSizePixel={0}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</frame>
				{hasSheet ? (
					<Fx.ElementFx
						element={props.element!}
						size={UDim2.fromOffset(artSize, artSize)}
						reducedMotion={props.reducedMotion}
						reaction="select"
						reactionKey={props.name}
					/>
				) : (
					<GlyphWell
						kind={props.iconKind ?? "Loadout"}
						accent={props.color}
						size={math.floor(artH * 0.4)}
						radius={16}
						position={UDim2.fromScale(0.5, 0.5)}
						anchorPoint={new Vector2(0.5, 0.5)}
						spin={false}
						glow={true}
						reducedMotion={props.reducedMotion}
					/>
				)}
			</frame>
			{props.stats.map((stat, index) => (
				<StatRow key={`${index}`} {...stat} accent={props.accent} y={statsTop + index * (INSPECT_STAT_H + INSPECT_STAT_GAP)} />
			))}
		</frame>
	);
}


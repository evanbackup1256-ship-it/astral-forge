// Forge UI 4 port kit for the Constellations, Worlds and Expeditions screens.
// Self-contained on purpose: the shared brass/rarity tokens (CoreKit/theme ForgeTheme) and
// UiCore/SpriteCard from the port briefs are not on master yet. Everything here follows the brief's
// spec so each piece can be swapped for the shared one with a one-line import change:
//   PORT_TOKENS  -> Palette.brass / brassDeep / rarity set
//   SpriteCard   -> UiCore/SpriteCard
//   PortPanel    -> Panel with the brass inner rule
// All effects are drawn in code (frames, strokes, gradients); no baked images.
import React from "@rbxts/react";
import { Palette, TapTarget } from "../../CoreKit/theme";
import ElementFxModule = require("../../ElementFx");
import { loadUi, named } from "../luauDeps";
import { GlyphWell, PnSurface } from "../../UiCore/mockKit";

const { Text } = loadUi();
const { ElementFx } = ElementFxModule;

export const PORT_TOKENS = {
	// the shared-theme batch (ForgeTheme) now carries the brief's brass values
	brass: Palette.brass,
	brassDeep: Palette.brassDeep,
	radius: 18,
};

// af.css rarity set (--r-*)
export const RARITY: Record<string, Color3> = {
	Common: Color3.fromRGB(200, 196, 188),
	Rare: Color3.fromRGB(110, 190, 255),
	Epic: Color3.fromRGB(190, 120, 255),
	Legendary: Color3.fromRGB(255, 190, 70),
	Mythic: Color3.fromRGB(255, 110, 150),
	Celestial: Color3.fromRGB(190, 248, 255),
	Astral: Color3.fromRGB(255, 200, 240),
};
export function rarityColor(rarity: string | undefined): Color3 {
	return (rarity !== undefined ? RARITY[rarity] : undefined) ?? RARITY.Common;
}

// Cinzel is not a Roblox font; the brief's fallback is the closest built-in serif
export const SERIF = new Font("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold);
const SERIF_HEAVY = new Font("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Heavy);
const BODY_BOLD = new Font("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold);


/** A serif display line that never scales: one size, truncated with "…" if it would not fit. */
/** Small spaced caps label (the mockups' eyebrow), 11px floor. */
export function Eyebrow(p: { text: string; color?: Color3; position?: UDim2; width?: UDim; align?: Enum.TextXAlignment; zIndex?: number; layoutOrder?: number }) {
	return (
		<textlabel
			BackgroundTransparency={1}
			BorderSizePixel={0}
			Text={p.text.upper()}
			TextSize={11}
			FontFace={BODY_BOLD}
			TextColor3={p.color ?? Palette.mango}
			TextXAlignment={p.align ?? Enum.TextXAlignment.Left}
			TextTruncate={Enum.TextTruncate.AtEnd}
			Position={p.position ?? UDim2.fromOffset(0, 0)}
			Size={new UDim2(p.width ?? new UDim(1, 0), new UDim(0, 14))}
			LayoutOrder={p.layoutOrder ?? 0}
			ZIndex={p.zIndex ?? 3}
		/>
	);
}

/** Panel radius 18, 1px line stroke (from Panel) plus the brass inner rule at 0.75. */
export function PortPanel(p: {
	children?: React.ReactNode;
	padding?: number;
	accent?: Color3;
	background?: Color3;
	reducedMotion?: boolean;
	highlight?: boolean;
	size?: UDim2;
	position?: UDim2;
}) {
	const pad = p.padding ?? 16;
	return (
		<PnSurface
			size={p.size ?? UDim2.fromScale(1, 1)}
			position={p.position}
			accent={p.accent ?? Palette.lineSoft}
			background={p.background ?? Palette.panel}
			radius={PORT_TOKENS.radius}
			padding={pad}
			highlight={p.highlight}
			reducedMotion={p.reducedMotion}
			clips={false}
		>
			<frame
				{...named("BrassRule")}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				Position={UDim2.fromOffset(-pad + 3, -pad + 3)}
				Size={new UDim2(1, 2 * pad - 6, 1, 2 * pad - 6)}
				ZIndex={1}
			>
				<uicorner CornerRadius={new UDim(0, PORT_TOKENS.radius - 3)} />
				<uistroke Color={PORT_TOKENS.brass} Transparency={0.75} Thickness={1} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
			</frame>
			{p.children}
		</PnSurface>
	);
}

/** Thin brass divider with a centre stud, as between the mockups' row groups. */
export const INFO_ROW_H = 40;

/** Label / value row: small still icon tile, label left, value right in the accent. */
export function InfoRow(p: { icon: string; label: string; value: string; accent?: Color3; position?: UDim2; width?: UDim; layoutOrder?: number; reducedMotion?: boolean }) {
	const accent = p.accent ?? Palette.pink;
	// one horizontal list: icon tile, label (fills), value; works both in a UIListLayout and free-placed
	return (
		<frame
			BackgroundColor3={Palette.panelRaised}
			BackgroundTransparency={0.15}
			BorderSizePixel={0}
			Position={p.position ?? UDim2.fromOffset(0, 0)}
			Size={new UDim2(p.width ?? new UDim(1, 0), new UDim(0, INFO_ROW_H))}
			LayoutOrder={p.layoutOrder ?? 0}
			ZIndex={2}
		>
			<uicorner CornerRadius={new UDim(0, 10)} />
			<uistroke Color={Palette.line} Transparency={0.4} Thickness={1} />
			<uipadding PaddingLeft={new UDim(0, 8)} PaddingRight={new UDim(0, 12)} />
			<uilistlayout
				FillDirection={Enum.FillDirection.Horizontal}
				VerticalAlignment={Enum.VerticalAlignment.Center}
				SortOrder={Enum.SortOrder.LayoutOrder}
				Padding={new UDim(0, 10)}
			/>
			<frame key="Icon" BackgroundTransparency={1} Size={UDim2.fromOffset(26, 26)} LayoutOrder={0}>
				<GlyphWell kind={p.icon} accent={accent} size={26} radius={8} still={true} spin={false} position={UDim2.fromOffset(0, 0)} reducedMotion={p.reducedMotion} />
			</frame>
			<textlabel
				key="Label"
				BackgroundTransparency={1}
				Size={new UDim2(0, 0, 0, 18)}
				Text={p.label}
				TextSize={13}
				FontFace={BODY_BOLD}
				TextColor3={Palette.creamSoft}
				TextXAlignment={Enum.TextXAlignment.Left}
				TextTruncate={Enum.TextTruncate.AtEnd}
				LayoutOrder={1}
				ZIndex={3}
			>
				<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
			</textlabel>
			<textlabel
				key="Value"
				BackgroundTransparency={1}
				AutomaticSize={Enum.AutomaticSize.X}
				Size={new UDim2(0, 0, 0, 18)}
				Text={p.value}
				TextSize={13}
				FontFace={BODY_BOLD}
				TextColor3={accent}
				TextXAlignment={Enum.TextXAlignment.Right}
				LayoutOrder={2}
				ZIndex={3}
			/>
		</frame>
	);
}

// deterministic sparse star field, drawn as 1-2px frames (no image)
function hash(n: number): number {
	const x = math.sin(n * 127.1 + 311.7) * 43758.5453;
	return x - math.floor(x);
}
export function StarField(p: { count: number; seed: number; xFrom?: number; zIndex?: number }) {
	const dots: React.Element[] = [];
	const from = p.xFrom ?? 0;
	for (let i = 0; i < p.count; i++) {
		const s = 1 + math.floor(hash(p.seed + i * 3) * 2);
		dots.push(
			<frame
				key={`s${i}`}
				BackgroundColor3={Palette.cream}
				BackgroundTransparency={0.35 + hash(p.seed + i * 7) * 0.5}
				BorderSizePixel={0}
				Position={UDim2.fromScale(from + hash(p.seed + i) * (1 - from), hash(p.seed + i * 5 + 1))}
				Size={UDim2.fromOffset(s, s)}
				ZIndex={p.zIndex ?? 1}
			/>,
		);
	}
	return (
		<frame BackgroundTransparency={1} BorderSizePixel={0} Size={UDim2.fromScale(1, 1)} ZIndex={p.zIndex ?? 1}>
			{dots}
		</frame>
	);
}

/** Engraved planet: outlined disc and a tilted elliptical ring, all strokes. */
export function Planet(p: { color: Color3; size: number; position: UDim2; anchor?: Vector2; dim?: boolean; zIndex?: number }) {
	const z = p.zIndex ?? 2;
	const fade = p.dim === true ? 0.45 : 0;
	return (
		<frame BackgroundTransparency={1} BorderSizePixel={0} AnchorPoint={p.anchor ?? new Vector2(0.5, 0.5)} Position={p.position} Size={UDim2.fromOffset(p.size, p.size)} ZIndex={z}>
			<frame BackgroundColor3={p.color} BackgroundTransparency={0.94} BorderSizePixel={0} Size={UDim2.fromScale(1, 1)} ZIndex={z}>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke Color={p.color} Thickness={2} Transparency={fade} />
			</frame>
			{/* the far half of the ring, then the near half drawn over the disc */}
			<frame
				BackgroundTransparency={1}
				BorderSizePixel={0}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Position={UDim2.fromScale(0.5, 0.55)}
				Size={UDim2.fromScale(2.4, 0.42)}
				Rotation={-10}
				ZIndex={z + 1}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke Color={p.color} Thickness={1.2} Transparency={0.25 + fade} />
			</frame>
			<frame
				BackgroundTransparency={1}
				BorderSizePixel={0}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Position={UDim2.fromScale(0.5, 0.52)}
				Size={UDim2.fromScale(2.0, 0.3)}
				Rotation={-8}
				ZIndex={z + 1}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke Color={p.color} Thickness={1} Transparency={0.5 + fade * 0.5} />
			</frame>
		</frame>
	);
}


/**
 * Sprite card (.sc): the relic's elemental sprite (ElementFx: 6x6 sheet, 36 frames, 24 fps) on a
 * dark well, a 1.5px rarity stroke, the name and a rarity tag. Selected: full stroke, 4px lift.
 */
export function SpriteCard(p: { element?: string; name: string; rarity?: string; selected?: boolean; size: UDim2; position?: UDim2; reducedMotion?: boolean }) {
	const color = rarityColor(p.rarity);
	const lift = p.selected === true ? -4 : 0;
	const pos = p.position ?? UDim2.fromOffset(0, 0);
	return (
		<frame
			{...named("SpriteCard")}
			BackgroundColor3={Palette.panelRaised}
			BorderSizePixel={0}
			Position={new UDim2(pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset + lift)}
			Size={p.size}
			ZIndex={2}
		>
			<uicorner CornerRadius={new UDim(0, 16)} />
			<uistroke Color={color} Thickness={1.5} Transparency={p.selected === true ? 0 : 0.45} />
			<frame BackgroundColor3={Color3.fromRGB(13, 9, 15)} BorderSizePixel={0} Position={UDim2.fromOffset(8, 8)} Size={new UDim2(1, -16, 1, -62)} ClipsDescendants={true} ZIndex={2}>
				<uicorner CornerRadius={new UDim(0, 11)} />
				<uigradient
					Color={new ColorSequence(color.Lerp(Color3.fromRGB(13, 9, 15), 0.75), Color3.fromRGB(13, 9, 15))}
					Rotation={90}
				/>
				{p.element !== undefined && (
					<ElementFx element={p.element} size={UDim2.fromScale(1.12, 1.12)} position={UDim2.fromScale(0.5, 0.5)} framerate={24} reducedMotion={p.reducedMotion} zIndex={3} />
				)}
			</frame>
			<Text value={p.name} size={14} color={Palette.cream} weight={Enum.FontWeight.Bold} align={Enum.TextXAlignment.Center} position={new UDim2(0, 6, 1, -50)} sizeConstraint={new UDim2(1, -12, 0, 18)} zIndex={3} />
			{p.rarity !== undefined && (
				<frame BackgroundColor3={color} BorderSizePixel={0} AnchorPoint={new Vector2(0.5, 0)} Position={new UDim2(0.5, 0, 1, -28)} Size={UDim2.fromOffset(math.max(64, p.rarity.size() * 9 + 16), 18)} ZIndex={3}>
					<uicorner CornerRadius={new UDim(0, 5)} />
					<textlabel
						BackgroundTransparency={1}
						Size={UDim2.fromScale(1, 1)}
						Text={p.rarity.upper()}
						TextSize={11}
						FontFace={BODY_BOLD}
						TextColor3={Palette.ink}
						TextTruncate={Enum.TextTruncate.AtEnd}
						ZIndex={4}
					/>
				</frame>
			)}
		</frame>
	);
}

export { TapTarget };

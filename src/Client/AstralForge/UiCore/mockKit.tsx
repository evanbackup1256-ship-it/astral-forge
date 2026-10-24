// Mockup primitives for the page bodies ported from design/system/af.css (1920x1080 reference).
// Each piece carries the stylesheet's px values; `phone` switches to the `.p` overrides.
//   .pn    -> MockPanel (kit Panel with the brass rule)    .row  -> MockRow
//   .pn h3 -> PanelHeading                                 .lbl  -> Label
//   .chip  -> Chip                                         .rule -> DiamondRule
//   .bar   -> Bar                                          .it   -> ItemTile
import React from "@rbxts/react";
import { Palette } from "../CoreKit/theme";
import { Panel, PanelProps, TITLE_FACE } from "./ui";
import { Bindable } from "../lua";

const ArtIcon = ((require(script.Parent!.Parent!.FindFirstChild("ArtKit")! as ModuleScript) as CallableFunction)("Icon") as { Icon: unknown }).Icon;
const h = React.createElement as unknown as (component: unknown, props?: object, ...children: unknown[]) => React.Element;

export const BODY = new Font("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium);
export const BODY_SEMI = new Font("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.SemiBold);
export const BODY_BOLD = new Font("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold);
export const NUM = new Font("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold);
export { TITLE_FACE };

/** af.css spacing: .main gap and .flexr/.flexc gap (desktop 18, phone 8). */
export function mockGap(phone: boolean) {
	return phone ? 8 : 18;
}
/** .pn padding (18px 20px desktop, 10px 12px phone) and radius (16 / 12). */
export function panelPad(phone: boolean) {
	return phone ? { y: 10, x: 12, radius: 12, gap: 8 } : { y: 18, x: 20, radius: 16, gap: 12 };
}

export function Glyph(p: { kind: string; size: number; color?: Color3; position?: UDim2; layoutOrder?: number }) {
	return (
		<frame Size={UDim2.fromOffset(p.size, p.size)} Position={p.position} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={p.layoutOrder ?? 0}>
			{h(ArtIcon, { kind: p.kind, color: p.color ?? Palette.cream, accent: p.color ?? Palette.mango, size: p.size, position: UDim2.fromOffset(0, 0), spin: false })}
		</frame>
	);
}

/** Plain single-line label; width hugs the text unless `width` is given. */
export function Line(p: {
	text: string | React.Binding<string>;
	size: number;
	font?: Font;
	color?: Color3;
	width?: UDim;
	height?: number;
	align?: Enum.TextXAlignment;
	layoutOrder?: number;
	position?: UDim2;
	anchor?: Vector2;
	tracking?: boolean;
	zIndex?: number;
}) {
	const hug = p.width === undefined;
	return (
		<textlabel
			BackgroundTransparency={1}
			BorderSizePixel={0}
			Text={p.text}
			TextSize={p.size}
			FontFace={p.font ?? BODY_BOLD}
			TextColor3={p.color ?? Palette.cream}
			TextXAlignment={p.align ?? Enum.TextXAlignment.Left}
			TextYAlignment={Enum.TextYAlignment.Center}
			TextTruncate={Enum.TextTruncate.AtEnd}
			AutomaticSize={hug ? Enum.AutomaticSize.X : Enum.AutomaticSize.None}
			Size={new UDim2(p.width ?? new UDim(0, 0), new UDim(0, p.height ?? math.ceil(p.size * 1.25)))}
			Position={p.position}
			AnchorPoint={p.anchor}
			LayoutOrder={p.layoutOrder ?? 0}
			ZIndex={p.zIndex ?? 1}
		/>
	);
}

/** .lbl: 11px bold, uppercase, wide tracking, muted. */
export function Label(p: { text: string; color?: Color3; icon?: string; layoutOrder?: number; phone?: boolean }) {
	return (
		<frame Size={new UDim2(1, 0, 0, 16)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={p.layoutOrder ?? 0}>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 8)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
			{p.icon !== undefined && <Glyph kind={p.icon} size={16} color={p.color ?? Palette.muted} layoutOrder={0} />}
			<Line text={spaced(p.text.upper())} size={p.phone === true ? 10 : 11} color={p.color ?? Palette.muted} layoutOrder={1} />
		</frame>
	);
}

// letter-spacing .12-.16em has no Roblox property; a hair space between letters reads the same at 11-15px
export function spaced(text: string): string {
	const out: string[] = [];
	for (const [ch] of text.gmatch(utf8.charpattern)) {
		out.push(ch as string);
	}
	return out.join("\u{200A}");
}

/** .pn h3: icon in the accent, 15px title caps, optional small note pushed right. */
export function PanelHeading(p: { icon: string; title: string; note?: string | React.Binding<string>; accent?: Color3; phone: boolean; layoutOrder?: number }) {
	const size = p.phone ? 12 : 15;
	return (
		<frame Size={new UDim2(1, 0, 0, p.phone ? 18 : 22)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={p.layoutOrder ?? 0}>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 10)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
			<Glyph kind={p.icon} size={p.phone ? 15 : 18} color={p.accent ?? Palette.mango} layoutOrder={0} />
			<Line text={spaced(p.title.upper())} size={size} font={TITLE_FACE} layoutOrder={1} />
			{p.note !== undefined && (
				<frame Size={new UDim2(1, 0, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
					<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
					<Line text={p.note} size={p.phone ? 11 : 12} font={BODY_SEMI} color={Palette.muted} width={new UDim(1, 0)} height={p.phone ? 18 : 22} align={Enum.TextXAlignment.Right} />
				</frame>
			)}
		</frame>
	);
}

/** .pn: kit Panel (radius 16 / brass rule) with the stylesheet's padding and a vertical stack. */
export function MockPanel(p: {
	size: UDim2;
	position?: UDim2;
	anchor?: Vector2;
	phone: boolean;
	layoutOrder?: number;
	accent?: Color3;
	glow?: Color3;
	/** mockup radial-gradient(w/2 h/2 at cx cy, color alpha, transparent) in panel fractions; replaces the default top-right ellipse */
	glowBox?: { w: number; h: number; cx: number; cy: number; transparency: number };
	reveal?: React.Binding<number>;
	reducedMotion?: boolean;
	flex?: boolean;
	gap?: number;
	name?: string;
	children?: React.ReactNode;
}) {
	const pad = panelPad(p.phone);
	return (
		<frame
			Size={p.size}
			Position={p.position}
			AnchorPoint={p.anchor}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			LayoutOrder={p.layoutOrder ?? 0}
			ZIndex={2}
			{...(p.name !== undefined ? { Name: p.name } : {})}
		>
			{p.flex === true && <uiflexitem FlexMode={Enum.UIFlexMode.Fill} />}
			<Panel size={UDim2.fromScale(1, 1)} radius={pad.radius} padding={pad.y} rule={true} accent={p.accent ?? Palette.brass} background={Palette.panel} reveal={p.reveal} reducedMotion={p.reducedMotion}>
				{p.glow !== undefined && p.glowBox !== undefined && (
					<RadialGlow color={p.glow} box={p.glowBox} inset={pad.y} />
				)}
				{p.glow !== undefined && p.glowBox === undefined && (
					// radial-gradient(300px 160px at 80% 0%, accent .22): a soft ellipse in the top-right
					<frame
						Size={UDim2.fromOffset(600, 320)}
						Position={new UDim2(0.8, 0, 0, -pad.y)}
						AnchorPoint={new Vector2(0.5, 0.5)}
						BackgroundColor3={p.glow}
						BorderSizePixel={0}
						ZIndex={0}
					>
						<uicorner CornerRadius={new UDim(1, 0)} />
						<uigradient
							Transparency={
								new NumberSequence([
									new NumberSequenceKeypoint(0, 0.78),
									new NumberSequenceKeypoint(0.5, 0.9),
									new NumberSequenceKeypoint(1, 1),
								])
							}
						/>
					</frame>
				)}
				<frame Size={new UDim2(1, -(pad.x - pad.y) * 2, 1, 0)} Position={UDim2.fromOffset(pad.x - pad.y, 0)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={2}>
					<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, p.gap ?? pad.gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
					{p.children}
				</frame>
			</Panel>
		</frame>
	);
}

/**
 * CSS radial-gradient glow as concentric rounded frames (the depth.tsx SoftShadow technique: stacked
 * layers with falling opacity, no baked image). `box` is the ellipse (full w x h px) centred at
 * (cx, cy) of the host's outer box; `inset` cancels the host's UIPadding.
 */
export function RadialGlow(p: { color: Color3; box: { w: number; h: number; cx: number; cy: number; transparency: number }; inset?: number }) {
	const layers = 7;
	const inset = p.inset ?? 0;
	// each layer adds an equal share, so the centre (all layers) reaches the stop's opacity and the
	// rim (outer layer only) fades to almost nothing, like the CSS falloff to transparent
	const share = 1 - math.pow(1 - (1 - p.box.transparency), 1 / layers);
	const items: React.Element[] = [];
	for (let index = 0; index < layers; index++) {
		const t = (index + 1) / layers;
		items.push(
			<frame
				key={`g${index}`}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Position={UDim2.fromScale(p.box.cx, p.box.cy)}
				Size={UDim2.fromOffset(math.round(p.box.w * t), math.round(p.box.h * t))}
				BackgroundColor3={p.color}
				BackgroundTransparency={1 - share}
				BorderSizePixel={0}
				ZIndex={0}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>,
		);
	}
	// clipped to the host's outer box like a CSS background layer
	return (
		<frame
			key="RadialGlow"
			Position={UDim2.fromOffset(-inset, -inset)}
			Size={new UDim2(1, inset * 2, 1, inset * 2)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ClipsDescendants={true}
			Active={false}
			ZIndex={0}
		>
			{items}
		</frame>
	);
}

/** .row surface: radius 11, faint top-lit fill, 1px white .05 inner line. */
export function RowSurface(p: { radius?: number }) {
	return (
		<>
			<uicorner CornerRadius={new UDim(0, p.radius ?? 11)} />
			<uigradient
				Rotation={90}
				Color={new ColorSequence(Palette.white, Palette.void)}
				Transparency={new NumberSequence([new NumberSequenceKeypoint(0, 0.965), new NumberSequenceKeypoint(1, 0.88)])}
			/>
			<uistroke Color={Palette.white} Transparency={0.95} Thickness={1} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
		</>
	);
}

/** .rule: a brass hairline, a 9px diamond, another hairline. */
export function DiamondRule(p: { layoutOrder?: number }) {
	const line = (order: number, flip: boolean) => (
		<frame Size={new UDim2(0.5, -12, 0, 1)} BackgroundColor3={Palette.brass} BorderSizePixel={0} LayoutOrder={order}>
			<uigradient
				Transparency={
					new NumberSequence(
						flip
							? [new NumberSequenceKeypoint(0, 0.35), new NumberSequenceKeypoint(1, 1)]
							: [new NumberSequenceKeypoint(0, 1), new NumberSequenceKeypoint(1, 0.35)],
					)
				}
			/>
		</frame>
	);
	return (
		<frame Size={new UDim2(1, 0, 0, 12)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={p.layoutOrder ?? 0}>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 8)} VerticalAlignment={Enum.VerticalAlignment.Center} HorizontalAlignment={Enum.HorizontalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
			{line(0, false)}
			<frame Size={UDim2.fromOffset(9, 9)} Rotation={45} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
				<uistroke Color={Palette.brass} Thickness={1} />
			</frame>
			{line(2, true)}
		</frame>
	);
}

/** .chip (.chip.a when `accent` is set): 28px, radius 8, 12px bold. */
export function Chip(p: { text: string; accent?: Color3; icon?: string; layoutOrder?: number; phone?: boolean }) {
	const on = p.accent !== undefined;
	return (
		<frame
			Size={UDim2.fromOffset(0, p.phone === true ? 24 : 28)}
			AutomaticSize={Enum.AutomaticSize.X}
			BackgroundColor3={on ? p.accent! : Palette.white}
			BackgroundTransparency={on ? 0.8 : 0.95}
			BorderSizePixel={0}
			LayoutOrder={p.layoutOrder ?? 0}
		>
			<uicorner CornerRadius={new UDim(0, 8)} />
			<uistroke Color={on ? p.accent! : Palette.white} Transparency={on ? 0.4 : 0.9} Thickness={1} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
			<uipadding PaddingLeft={new UDim(0, 10)} PaddingRight={new UDim(0, 10)} />
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 6)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
			{p.icon !== undefined && <Glyph kind={p.icon} size={16} color={on ? p.accent : Palette.creamSoft} layoutOrder={0} />}
			<Line text={p.text} size={12} color={on ? Palette.cream : Palette.creamSoft} layoutOrder={1} />
		</frame>
	);
}

/** .bar / .bar.thin: dark inset track with a lit accent fill. */
export function Bar(p: { fill: number | React.Binding<number>; color?: Color3; thin?: boolean; layoutOrder?: number; position?: UDim2; width?: UDim }) {
	const color = p.color ?? Palette.mango;
	const height = p.thin === true ? 6 : 10;
	const size = typeIs(p.fill, "number")
		? UDim2.fromScale(math.clamp(p.fill, 0, 1), 1)
		: (p.fill as React.Binding<number>).map((v) => UDim2.fromScale(math.clamp(v, 0, 1), 1));
	return (
		<frame
			Size={new UDim2(p.width ?? new UDim(1, 0), new UDim(0, height))}
			Position={p.position}
			BackgroundColor3={Color3.fromRGB(9, 6, 10)}
			BorderSizePixel={0}
			LayoutOrder={p.layoutOrder ?? 0}
			ClipsDescendants={true}
		>
			<uicorner CornerRadius={new UDim(0, 5)} />
			<uistroke Color={Palette.white} Transparency={0.95} Thickness={1} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
			<frame Size={size} BackgroundColor3={color} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(0, 5)} />
				<uigradient
					Rotation={90}
					Color={
						new ColorSequence([
							new ColorSequenceKeypoint(0, color.Lerp(Palette.white, 0.4)),
							new ColorSequenceKeypoint(0.55, color),
							new ColorSequenceKeypoint(1, color.Lerp(Palette.void, 0.3)),
						])
					}
				/>
			</frame>
		</frame>
	);
}

/** .it: rarity card. `compact` is the 56px machine thumb (.it with padding 3 and a square art well). */
export function ItemTile(p: {
	color: Color3;
	icon: string;
	width: number;
	compact?: boolean;
	locked?: boolean;
	name?: string;
	tag?: string;
	count?: string;
	layoutOrder?: number;
	phone?: boolean;
}) {
	const compact = p.compact === true;
	const pad = compact ? 3 : p.phone === true ? 5 : 8;
	const radius = compact ? 11 : p.phone === true ? 11 : 14;
	const well = p.width - pad * 2;
	const wellH = compact ? well : math.floor(well / 1.15);
	const nameH = p.name !== undefined ? (p.phone === true ? 14 : 17) : 0;
	const tagH = p.tag !== undefined ? (p.phone === true ? 14 : 17) : 0;
	const gap = p.phone === true ? 4 : 6;
	const height = compact ? p.width : pad + wellH + (nameH > 0 ? gap + nameH : 0) + (tagH > 0 ? gap + tagH : 0) + (p.phone === true ? 7 : 10);
	const rc = p.color;
	return (
		<frame Size={UDim2.fromOffset(p.width, height)} BackgroundColor3={rc.Lerp(Color3.fromRGB(21, 16, 23), 0.78)} BorderSizePixel={0} LayoutOrder={p.layoutOrder ?? 0}>
			<uicorner CornerRadius={new UDim(0, radius)} />
			<uigradient Rotation={90} Color={new ColorSequence([new ColorSequenceKeypoint(0, Palette.white), new ColorSequenceKeypoint(0.75, Color3.fromRGB(110, 100, 110)), new ColorSequenceKeypoint(1, Color3.fromRGB(110, 100, 110))])} />
			<uistroke Color={rc} Transparency={p.locked === true ? 0.7 : 0.3} Thickness={1.5} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
			<frame Size={UDim2.fromOffset(well, wellH)} Position={UDim2.fromOffset(pad, pad)} BackgroundColor3={Palette.ink} BorderSizePixel={0} ClipsDescendants={true}>
				<uicorner CornerRadius={new UDim(0, compact ? 8 : 9)} />
				{p.locked !== true && (
					<frame Size={UDim2.fromScale(0.9, 0.9)} Position={UDim2.fromScale(0.5, 0.58)} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundColor3={rc} BorderSizePixel={0}>
						<uicorner CornerRadius={new UDim(1, 0)} />
						<uigradient Transparency={new NumberSequence([new NumberSequenceKeypoint(0, 0.55), new NumberSequenceKeypoint(1, 1)])} />
					</frame>
				)}
				<Glyph
					kind={p.icon}
					size={math.floor(math.min(well, wellH) * 0.56)}
					color={p.locked === true ? Color3.fromRGB(42, 33, 48) : rc.Lerp(Palette.white, 0.65)}
					position={new UDim2(0.5, -math.floor(math.min(well, wellH) * 0.28), 0.5, -math.floor(math.min(well, wellH) * 0.28))}
				/>
			</frame>
			{p.count !== undefined && <Line text={p.count} size={13} font={NUM} position={new UDim2(1, -12, 0, 12)} anchor={new Vector2(1, 0)} zIndex={3} />}
			{p.name !== undefined && (
				<Line
					text={p.name}
					size={p.phone === true ? 11 : 13}
					width={new UDim(1, -pad * 2)}
					height={nameH}
					align={Enum.TextXAlignment.Center}
					position={UDim2.fromOffset(pad, pad + wellH + gap)}
					color={p.locked === true ? Palette.muted : Palette.cream}
				/>
			)}
			{p.tag !== undefined && (
				<frame
					Size={UDim2.fromOffset(0, tagH)}
					AutomaticSize={Enum.AutomaticSize.X}
					Position={new UDim2(0.5, 0, 0, pad + wellH + gap + nameH + gap)}
					AnchorPoint={new Vector2(0.5, 0)}
					BackgroundColor3={rc}
					BorderSizePixel={0}
				>
					<uicorner CornerRadius={new UDim(0, 5)} />
					<uipadding PaddingLeft={new UDim(0, 7)} PaddingRight={new UDim(0, 7)} />
					<Line text={spaced(p.tag.upper())} size={p.phone === true ? 8 : 9} font={NUM} color={Color3.fromRGB(20, 12, 16)} height={tagH} />
				</frame>
			)}
		</frame>
	);
}

/**
 * .pn surface without the vertical stack: the star-forged panel (radius 16 / phone 12, brass inner
 * rule, panel fill) for hosts that place their own children. Replaces direct use of the kit Panel.
 */
export function PnSurface(p: PanelProps & { phone?: boolean }) {
	const pad = panelPad(p.phone === true);
	return (
		<Panel
			{...p}
			radius={p.radius ?? pad.radius}
			rule={p.rule ?? true}
			accent={p.accent ?? Palette.brass}
			background={p.background ?? Palette.panel}
			padding={p.padding ?? pad.y}
		/>
	);
}

/** .row radius: rows, small cards and list tiles. */
export const ROW_RADIUS = 11;

/**
 * .row face as a child plate (ZIndex 0): faint top-lit fill and the 1px white .05 inner line.
 * Lives on its own child so a host with its own UIGradient / UIStroke keeps them untouched.
 */
export function rowFace(): React.Element {
	return (
		<frame key="RowFace" Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.white} BorderSizePixel={0} Active={false} Selectable={false} ZIndex={0}>
			<uicorner CornerRadius={new UDim(0, ROW_RADIUS)} />
			<uigradient
				Rotation={90}
				Color={new ColorSequence(Palette.white, Palette.void)}
				Transparency={new NumberSequence([new NumberSequenceKeypoint(0, 0.965), new NumberSequenceKeypoint(1, 0.88)])}
			/>
			<uistroke Color={Palette.white} Transparency={0.95} Thickness={1} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
		</frame>
	);
}

/**
 * .it .ar art well for one icon: radius 9, #0c090e well, a soft accent glow under the glyph,
 * glyph at 56% in the accent mixed toward white. Takes the retired IconTile props so call sites
 * swap one name; `glow` brightens the rim, `filled` deepens the glow.
 */
export function GlyphWell(p: {
	kind?: unknown;
	accent?: Color3;
	size?: number;
	radius?: number;
	position?: Bindable<UDim2>;
	anchorPoint?: Vector2;
	spin?: boolean;
	still?: boolean;
	hoverAmount?: React.Binding<number>;
	reducedMotion?: boolean;
	glow?: boolean;
	filled?: boolean;
	zIndex?: number;
	layoutOrder?: number;
}) {
	const size = p.size ?? 48;
	const accent = p.accent ?? Palette.mango;
	const glyph = math.floor(size * 0.56);
	const z = p.zIndex ?? 1;
	return (
		<frame
			Size={UDim2.fromOffset(size, size)}
			Position={p.position}
			AnchorPoint={p.anchorPoint}
			BackgroundColor3={Color3.fromRGB(12, 9, 14)}
			BorderSizePixel={0}
			ZIndex={z}
			LayoutOrder={p.layoutOrder ?? 0}
			ClipsDescendants={true}
		>
			<uicorner CornerRadius={new UDim(0, p.radius ?? math.min(9, math.floor(size * 0.24)))} />
			<uistroke Color={accent} Transparency={p.glow === true ? 0.35 : 0.7} Thickness={1} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
			<frame Size={UDim2.fromScale(0.9, 0.9)} Position={UDim2.fromScale(0.5, 0.58)} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundColor3={accent} BorderSizePixel={0} ZIndex={z}>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uigradient Transparency={new NumberSequence([new NumberSequenceKeypoint(0, p.filled === true ? 0.4 : 0.55), new NumberSequenceKeypoint(1, 1)])} />
			</frame>
			{h(ArtIcon, {
				kind: p.kind,
				color: accent.Lerp(Palette.white, 0.65),
				accent: accent,
				size: glyph,
				spin: p.spin === true,
				still: p.still,
				hoverAmount: p.hoverAmount,
				clipSafe: true,
				reducedMotion: p.reducedMotion,
				position: UDim2.fromScale(0.5, 0.5),
				anchorPoint: new Vector2(0.5, 0.5),
			})}
		</frame>
	);
}

// Group B page bodies: .row / .btn / icon-well pieces from design/system/af.css (1920x1080; `phone` = the .p rules).
// Local to the progression and economy pages; the shared mockKit stays untouched.
import React from "@rbxts/react";
import { Palette, TapTarget } from "../CoreKit/theme";
import { Button, buttonContentWidth } from "../UiCore/ui";
import { Bar, BODY, BODY_SEMI, Glyph, Line, NUM, PanelHeading, TITLE_FACE } from "../UiCore/mockKit";

/** .btn.sec base #3a2e3e */
export const SEC = Color3.fromRGB(58, 46, 62);

/** .row min-height: 48 desktop, 44 phone. */
export function rowHeight(phone: boolean, twoLine = false): number {
	if (phone) return twoLine ? 46 : 44;
	return twoLine ? 56 : 48;
}

/** 36px dark well with the accent glyph (rgba(0,0,0,.35), 1px white .08 inset, radius 9). */
export function IconWell(p: { icon: string; accent?: Color3; size?: number; layoutOrder?: number }) {
	const s = p.size ?? 36;
	return (
		<frame Size={UDim2.fromOffset(s, s)} BackgroundColor3={Color3.fromRGB(0, 0, 0)} BackgroundTransparency={0.65} BorderSizePixel={0} LayoutOrder={p.layoutOrder ?? 0}>
			<uicorner CornerRadius={new UDim(0, math.floor(s / 4))} />
			<uistroke Color={Palette.white} Transparency={0.92} Thickness={1} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
			<Glyph kind={p.icon} size={math.floor(s * 0.5)} color={p.accent ?? Palette.mango} position={UDim2.fromOffset(math.floor(s * 0.25), math.floor(s * 0.25))} />
		</frame>
	);
}

/** .btn / .btn.sm / .btn.sec on the kit Button (keeps its press motion and shimmer). */
export function MockBtn(p: {
	text: string;
	icon?: string;
	accent?: Color3;
	sec?: boolean;
	sm?: boolean;
	phone?: boolean;
	width?: number;
	fill?: boolean;
	disabled?: boolean;
	onClick?: () => void;
	reducedMotion?: boolean;
	layoutOrder?: number;
	position?: UDim2;
	anchor?: Vector2;
}) {
	const height = p.phone === true ? TapTarget : p.sm === true ? 36 : 44;
	const sec = p.sec === true || p.disabled === true;
	// a hugging button used to sit in a 0px-wide wrapper and spill past it, so list layouts (row
	// trailing slots, action strips) packed the next sibling on top of it; the wrapper now takes the
	// width the kit Button would hug to
	const hug = p.width === undefined && p.fill !== true;
	const width = p.fill === true ? new UDim(1, 0) : new UDim(0, p.width ?? buttonContentWidth(p.text, p.icon !== undefined));
	return (
		<frame
			Size={new UDim2(width, new UDim(0, height))}
			Position={p.position}
			AnchorPoint={p.anchor}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			LayoutOrder={p.layoutOrder ?? 0}
		>
			<Button
				text={p.text}
				icon={p.icon}
				onClick={p.onClick ?? (() => {})}
				color={sec ? SEC : p.accent ?? Palette.mango}
				textColor={sec ? Palette.cream : Palette.ink}
				size={UDim2.fromScale(1, 1)}
				hug={hug}
				disabled={p.disabled}
				selectable={p.disabled !== true}
				highlight={!sec}
				reducedMotion={p.reducedMotion}
			/>
		</frame>
	);
}

/** .row: icon well, title + small line (.tt), value or trailing control on the right. */
export function MockRow(p: {
	title: string | React.Binding<string>;
	sub?: string | React.Binding<string>;
	icon?: string;
	accent?: Color3;
	value?: string | React.Binding<string>;
	valueColor?: Color3;
	right?: React.ReactNode;
	rightWidth?: number;
	phone: boolean;
	height?: number;
	layoutOrder?: number;
	outline?: Color3;
	dim?: boolean;
	serif?: boolean;
	name?: string;
}) {
	const phone = p.phone;
	const h = p.height ?? rowHeight(phone, p.sub !== undefined);
	const accent = p.accent ?? Palette.mango;
	const wellSize = phone ? 30 : 36;
	const valueSize = phone ? 14 : 17;
	const titleSize = phone ? 13 : p.serif === true ? 17 : 15;
	const subSize = phone ? 11 : 12;
	const block = titleSize + 4 + (p.sub !== undefined ? 2 + subSize + 3 : 0);
	return (
		<frame
			Size={new UDim2(1, 0, 0, h)}
			BackgroundColor3={Palette.white}
			BorderSizePixel={0}
			LayoutOrder={p.layoutOrder ?? 0}
			{...(p.name !== undefined ? { Name: p.name } : {})}
		>
			<RowFace outline={p.outline} />
			<uipadding PaddingLeft={new UDim(0, phone ? 10 : 12)} PaddingRight={new UDim(0, phone ? 10 : 12)} />
			{/* flex row: well, text (fills), value (hugs), trailing slot. The old absolute layout reserved a
			    fixed 170px value column, so in a two-column stat grid the text block went negative
			    and the value slid over the icon */}
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} VerticalAlignment={Enum.VerticalAlignment.Center} Padding={new UDim(0, 12)} SortOrder={Enum.SortOrder.LayoutOrder} />
			{p.icon !== undefined && (
				<frame Size={UDim2.fromOffset(wellSize, wellSize)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={0}>
					<IconWell icon={p.icon} accent={p.dim === true ? Palette.muted : accent} size={wellSize} />
				</frame>
			)}
			<frame Size={new UDim2(0, 0, 0, block)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
				<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
				<Line text={p.title} size={titleSize} font={p.serif === true ? TITLE_FACE : BODY_SEMI} width={new UDim(1, 0)} color={p.dim === true ? Palette.creamSoft : Palette.cream} />
				{p.sub !== undefined && (
					<Line text={p.sub} size={subSize} font={BODY} color={Palette.muted} width={new UDim(1, 0)} position={UDim2.fromOffset(0, titleSize + 6)} height={subSize + 3} />
				)}
			</frame>
			{p.value !== undefined && (
				<frame Size={UDim2.fromOffset(0, valueSize + 6)} AutomaticSize={Enum.AutomaticSize.X} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
					<uisizeconstraint MaxSize={new Vector2(phone ? 110 : 170, math.huge)} />
					<Line text={p.value} size={valueSize} font={NUM} color={p.valueColor ?? accent} align={Enum.TextXAlignment.Right} height={valueSize + 6} />
				</frame>
			)}
			{p.right !== undefined && (
				<frame Size={UDim2.fromOffset(p.rightWidth ?? 0, h)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={3}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} HorizontalAlignment={Enum.HorizontalAlignment.Right} VerticalAlignment={Enum.VerticalAlignment.Center} Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
					{p.right}
				</frame>
			)}
		</frame>
	);
}

/** Fixed-height block that stacks children with a gap (flex column). */
export function Stack(p: { height?: number; gap: number; layoutOrder?: number; horizontal?: boolean; children?: React.ReactNode; fill?: boolean; name?: string }) {
	return (
		<frame
			Size={p.height !== undefined ? new UDim2(1, 0, 0, p.height) : new UDim2(1, 0, 0, 0)}
			AutomaticSize={p.height === undefined ? Enum.AutomaticSize.Y : Enum.AutomaticSize.None}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			LayoutOrder={p.layoutOrder ?? 0}
			{...(p.name !== undefined ? { Name: p.name } : {})}
		>
			{p.fill === true && <uiflexitem FlexMode={Enum.UIFlexMode.Fill} />}
			<uilistlayout
				FillDirection={p.horizontal === true ? Enum.FillDirection.Horizontal : Enum.FillDirection.Vertical}
				Padding={new UDim(0, p.gap)}
				SortOrder={Enum.SortOrder.LayoutOrder}
				HorizontalFlex={p.horizontal === true ? Enum.UIFlexAlignment.Fill : undefined}
			/>
			{p.children}
		</frame>
	);
}

/** CSS grid repeat(n, 1fr) with a fixed row height. */
export function Grid(p: { columns: number; gap: number; cellHeight: number; count: number; layoutOrder?: number; children?: React.ReactNode }) {
	const rows = math.max(1, math.ceil(p.count / p.columns));
	const each = math.ceil((p.gap * (p.columns - 1)) / p.columns);
	return (
		<frame Size={new UDim2(1, 0, 0, rows * p.cellHeight + (rows - 1) * p.gap)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={p.layoutOrder ?? 0}>
			<uigridlayout
				CellSize={new UDim2(1 / p.columns, -each, 0, p.cellHeight)}
				CellPadding={UDim2.fromOffset(p.gap, p.gap)}
				SortOrder={Enum.SortOrder.LayoutOrder}
				FillDirectionMaxCells={p.columns}
			/>
			{p.children}
		</frame>
	);
}

/** Height of a MockPanel holding `content` px of stacked children (heading included by caller). */
export function panelHeight(phone: boolean, content: number): number {
	return content + (phone ? 10 : 18) * 2;
}
/** .pn h3 height plus its gap. */
export function headingBlock(phone: boolean): number {
	return (phone ? 18 : 22) + (phone ? 8 : 12);
}

/** Tracks a frame's pixel width so grids can size their art wells like CSS aspect boxes. */
export function useWidth(initial: number): [number, (rbx: GuiObject) => void] {
	const [width, setWidth] = React.useState(initial);
	const onSize = React.useCallback((rbx: GuiObject) => {
		const w = math.floor(rbx.AbsoluteSize.X);
		if (w > 0) setWidth((prev) => (math.abs(prev - w) >= 2 ? w : prev));
	}, []);
	return [width, onSize];
}

/** .row surface with exactly one stroke: the white .05 hairline, or `outline` when set (picked / live). */
export function RowFace(p: { outline?: Color3; radius?: number; strong?: boolean }) {
	return (
		<>
			<uicorner CornerRadius={new UDim(0, p.radius ?? 11)} />
			<uigradient
				Rotation={90}
				Color={new ColorSequence(Palette.white, Palette.void)}
				Transparency={new NumberSequence([new NumberSequenceKeypoint(0, 0.965), new NumberSequenceKeypoint(1, 0.88)])}
			/>
			<uistroke
				Color={p.outline ?? Palette.white}
				Transparency={p.outline !== undefined ? (p.strong === true ? 0 : 0.2) : 0.95}
				Thickness={p.outline !== undefined ? (p.strong === true ? 2 : 1.5) : 1}
				ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
			/>
		</>
	);
}

/** .it rarity tile (03 machine rows / 04 cards): dark square, rarity rim, glyph. */
export function TileWell(p: { icon: string; accent: Color3; size: number; dim?: boolean; position?: UDim2; anchor?: Vector2; layoutOrder?: number; children?: React.ReactNode }) {
	return (
		<frame
			Size={UDim2.fromOffset(p.size, p.size)}
			Position={p.position}
			AnchorPoint={p.anchor}
			BackgroundColor3={Color3.fromRGB(0, 0, 0)}
			BackgroundTransparency={0.6}
			BorderSizePixel={0}
			LayoutOrder={p.layoutOrder ?? 0}
		>
			<uicorner CornerRadius={new UDim(0, math.max(8, math.floor(p.size / 5)))} />
			<uistroke Color={p.dim === true ? Palette.muted : p.accent} Thickness={1.5} Transparency={p.dim === true ? 0.6 : 0.25} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
			<Glyph
				kind={p.icon}
				size={math.floor(p.size * 0.5)}
				color={p.dim === true ? Palette.muted : p.accent}
				position={UDim2.fromOffset(math.floor(p.size * 0.25), math.floor(p.size * 0.25))}
			/>
			{p.children}
		</frame>
	);
}

/** 03-forge machine row: 64px .row, 56px tile, "Name · Lv" with a thin bar, value, sm button. */
export const TILE_ROW_H = 64;
export function TileRow(p: {
	icon: string;
	accent: Color3;
	title: string;
	meta?: string;
	sub?: string;
	fill?: number;
	barColor?: Color3;
	value?: string;
	valueColor?: Color3;
	right?: React.ReactNode;
	rightWidth?: number;
	phone: boolean;
	dim?: boolean;
	outline?: Color3;
	height?: number;
	layoutOrder?: number;
	size?: UDim2;
	position?: UDim2;
	name?: string;
	event?: React.InstanceEvent<Frame>;
}) {
	const phone = p.phone;
	const h = p.height ?? (phone ? 56 : TILE_ROW_H);
	const tile = phone ? 44 : 56;
	const rw = p.rightWidth ?? 0;
	const vw = p.value !== undefined ? (phone ? 76 : 130) : 0;
	const left = tile + (phone ? 10 : 14);
	const reserve = rw + vw + (rw > 0 ? 12 : 0) + (vw > 0 ? 12 : 0);
	const title = p.meta !== undefined ? `${p.title} <font color="#9C8AA5" weight="500">· ${p.meta}</font>` : p.title;
	return (
		<frame
			Size={p.size ?? new UDim2(1, 0, 0, h)}
			Position={p.position}
			BackgroundColor3={Palette.white}
			BorderSizePixel={0}
			LayoutOrder={p.layoutOrder ?? 0}
			Event={p.event}
			{...(p.name !== undefined ? { Name: p.name } : {})}
		>
			<RowFace outline={p.outline} />
			<uipadding PaddingLeft={new UDim(0, phone ? 6 : 4)} PaddingRight={new UDim(0, phone ? 10 : 12)} />
			<TileWell icon={p.icon} accent={p.accent} size={tile} dim={p.dim} position={new UDim2(0, 0, 0.5, 0)} anchor={new Vector2(0, 0.5)} />
			<frame BackgroundTransparency={1} BorderSizePixel={0} Position={new UDim2(0, left, 0.5, 0)} AnchorPoint={new Vector2(0, 0.5)} Size={new UDim2(1, -(left + reserve), 0, 34)}>
				<textlabel
					BackgroundTransparency={1}
					RichText={true}
					Text={title}
					TextSize={phone ? 13 : 15}
					FontFace={BODY_SEMI}
					TextColor3={p.dim === true ? Palette.creamSoft : Palette.cream}
					TextXAlignment={Enum.TextXAlignment.Left}
					TextTruncate={Enum.TextTruncate.AtEnd}
					Size={new UDim2(1, 0, 0, 18)}
				/>
				{p.fill !== undefined ? (
					<frame BackgroundTransparency={1} BorderSizePixel={0} Position={UDim2.fromOffset(0, 26)} Size={new UDim2(1, 0, 0, 6)}>
						<Bar fill={p.fill} color={p.barColor ?? Palette.mango} thin={true} />
					</frame>
				) : p.sub !== undefined ? (
					<textlabel
						BackgroundTransparency={1}
						Text={p.sub}
						TextSize={12}
						FontFace={BODY}
						TextColor3={Palette.muted}
						TextXAlignment={Enum.TextXAlignment.Left}
						TextTruncate={Enum.TextTruncate.AtEnd}
						Position={UDim2.fromOffset(0, 19)}
						Size={new UDim2(1, 0, 0, 15)}
					/>
				) : undefined}
			</frame>
			{p.value !== undefined ? (
				<textlabel
					BackgroundTransparency={1}
					Text={p.value}
					TextSize={phone ? 14 : 17}
					FontFace={NUM}
					TextColor3={p.valueColor ?? p.accent}
					TextXAlignment={Enum.TextXAlignment.Right}
					TextTruncate={Enum.TextTruncate.AtEnd}
					AnchorPoint={new Vector2(1, 0.5)}
					Position={new UDim2(1, -(rw > 0 ? rw + 12 : 0), 0.5, 0)}
					Size={UDim2.fromOffset(vw, 22)}
				/>
			) : undefined}
			{p.right !== undefined ? (
				<frame BackgroundTransparency={1} BorderSizePixel={0} AnchorPoint={new Vector2(1, 0.5)} Position={new UDim2(1, 0, 0.5, 0)} Size={UDim2.fromOffset(rw, phone ? TapTarget : 36)}>
					{p.right}
				</frame>
			) : undefined}
		</frame>
	);
}

/** Free-standing .pn h3 (heading above a virtualised list that cannot sit inside a panel stack). */
export const HEADING_SECTION_H = 30;
export function HeadingSection(p: { icon: string; title: string; note?: string; accent?: Color3; phone: boolean }) {
	return (
		<frame BackgroundTransparency={1} BorderSizePixel={0} Size={UDim2.fromScale(1, 1)}>
			<uipadding PaddingLeft={new UDim(0, 4)} PaddingRight={new UDim(0, 4)} PaddingTop={new UDim(0, 4)} />
			<PanelHeading icon={p.icon} title={p.title} note={p.note} accent={p.accent} phone={p.phone} />
		</frame>
	);
}

/** .big number line (Output panel): 58px accent figure + muted unit. */
export function BigFigure(p: { value: string; unit?: string; color: Color3; phone: boolean; layoutOrder?: number }) {
	const size = p.phone ? 34 : 58;
	return (
		<frame BackgroundTransparency={1} BorderSizePixel={0} Size={new UDim2(1, 0, 0, size + 4)} LayoutOrder={p.layoutOrder ?? 0}>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} VerticalAlignment={Enum.VerticalAlignment.Bottom} Padding={new UDim(0, 10)} SortOrder={Enum.SortOrder.LayoutOrder} />
			<textlabel BackgroundTransparency={1} AutomaticSize={Enum.AutomaticSize.X} Text={p.value} TextSize={size} FontFace={NUM} TextColor3={p.color} Size={UDim2.fromOffset(0, size + 4)} LayoutOrder={0} />
			{p.unit !== undefined ? (
				<textlabel BackgroundTransparency={1} AutomaticSize={Enum.AutomaticSize.X} Text={p.unit} TextSize={p.phone ? 13 : 16} FontFace={BODY_SEMI} TextColor3={Palette.muted} Size={UDim2.fromOffset(0, p.phone ? 22 : 30)} LayoutOrder={1} />
			) : undefined}
		</frame>
	);
}

/** Horizontal chip row (fixed height). */
export function ChipRow(p: { height?: number; layoutOrder?: number; children?: React.ReactNode }) {
	return (
		<frame BackgroundTransparency={1} BorderSizePixel={0} Size={new UDim2(1, 0, 0, p.height ?? 28)} LayoutOrder={p.layoutOrder ?? 0}>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} VerticalAlignment={Enum.VerticalAlignment.Center} />
			{p.children}
		</frame>
	);
}

/** Row entrance without a CanvasGroup per row: the row slides up 10px as `reveal` goes 0 -> 1. */
export function Rise(p: { reveal: React.Binding<number>; height: number; layoutOrder?: number; children?: React.ReactNode }) {
	return (
		<frame Size={new UDim2(1, 0, 0, p.height)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false} LayoutOrder={p.layoutOrder ?? 0}>
			<frame Size={UDim2.fromScale(1, 1)} Position={p.reveal.map((v) => UDim2.fromOffset(0, math.floor((1 - v) * 10)))} BackgroundTransparency={1} BorderSizePixel={0}>
				{p.children}
			</frame>
		</frame>
	);
}

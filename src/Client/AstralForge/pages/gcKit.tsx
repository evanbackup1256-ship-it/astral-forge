// Group C page pieces on top of UiCore/mockKit (read-only): the af.css .row variants, .flexr/.flexc
// stacks, the 52x30 toggle, the round avatar ring and the scroll host the ported pages share.
//   .row            -> GcRow (icon well / avatar / chip on the left, .tt two lines, .v on the right)
//   .flexr / .flexc -> Flex
//   toggle span     -> Toggle
import React from "@rbxts/react";
import { Palette } from "../CoreKit/theme";
import { BODY, BODY_SEMI, Glyph, Line, NUM, RowSurface, spaced } from "../UiCore/mockKit";

/** .row min-height (48 desktop / 44 phone). */
export function rowH(phone: boolean) {
	return phone ? 44 : 48;
}

/** .flexr / .flexc: a list layout with the stylesheet gap; children pick their own size or use `fill`. */
export function Flex(p: {
	dir: "row" | "col";
	phone: boolean;
	size?: UDim2;
	position?: UDim2;
	gap?: number;
	layoutOrder?: number;
	fill?: boolean;
	align?: Enum.VerticalAlignment;
	hAlign?: Enum.HorizontalAlignment;
	auto?: boolean;
	name?: string;
	children?: React.ReactNode;
}) {
	return (
		<frame
			Size={p.size ?? UDim2.fromScale(1, 1)}
			Position={p.position}
			AutomaticSize={p.auto === true ? Enum.AutomaticSize.Y : Enum.AutomaticSize.None}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			LayoutOrder={p.layoutOrder ?? 0}
			{...(p.name !== undefined ? { Name: p.name } : {})}
		>
			{p.fill === true && <uiflexitem FlexMode={Enum.UIFlexMode.Fill} />}
			<uilistlayout
				FillDirection={p.dir === "row" ? Enum.FillDirection.Horizontal : Enum.FillDirection.Vertical}
				Padding={new UDim(0, p.gap ?? (p.phone ? 8 : 18))}
				VerticalAlignment={p.align ?? Enum.VerticalAlignment.Top}
				HorizontalAlignment={p.hAlign ?? Enum.HorizontalAlignment.Left}
				SortOrder={Enum.SortOrder.LayoutOrder}
			/>
			{p.children}
		</frame>
	);
}

/** 36px icon well: rgba(0,0,0,.35) square, radius 9, 1px white .08 inner line, glyph in the accent. */
export function IconWell(p: { icon: string; accent?: Color3; size?: number; layoutOrder?: number }) {
	const s = p.size ?? 36;
	return (
		<frame Size={UDim2.fromOffset(s, s)} BackgroundColor3={Palette.void} BackgroundTransparency={0.65} BorderSizePixel={0} LayoutOrder={p.layoutOrder ?? 0}>
			<uicorner CornerRadius={new UDim(0, 9)} />
			<uistroke Color={Palette.white} Transparency={0.92} Thickness={1} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
			<Glyph kind={p.icon} size={math.floor(s * 0.56)} color={p.accent ?? Palette.mango} position={UDim2.fromOffset(math.floor(s * 0.22), math.floor(s * 0.22))} />
		</frame>
	);
}

/** 30px round avatar with the 1.5px brass ring (.4) used by chat rows; shows the first letter. */
export function AvatarRing(p: { name: string; layoutOrder?: number; image?: string }) {
	return (
		<frame Size={UDim2.fromOffset(30, 30)} BackgroundColor3={Color3.fromRGB(42, 32, 48)} BorderSizePixel={0} LayoutOrder={p.layoutOrder ?? 0} ClipsDescendants={true}>
			<uicorner CornerRadius={new UDim(1, 0)} />
			<uistroke Color={Palette.brass} Transparency={0.6} Thickness={1.5} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
			{p.image !== undefined ? (
				<imagelabel Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} Image={p.image}>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</imagelabel>
			) : (
				<Line text={p.name.sub(1, 1).upper()} size={13} color={Palette.creamSoft} width={new UDim(1, 0)} height={30} align={Enum.TextXAlignment.Center} />
			)}
		</frame>
	);
}

export interface GcRowProps {
	title: string | React.Binding<string>;
	sub?: string | React.Binding<string>;
	value?: string | React.Binding<string>;
	valueColor?: Color3;
	valueFont?: Font;
	accent?: Color3;
	icon?: string;
	lead?: React.Element;
	right?: React.Element;
	ring?: Color3;
	dim?: boolean;
	phone: boolean;
	layoutOrder?: number;
	height?: number;
	titleWidth?: number;
	middle?: React.Element;
	name?: string;
}

/** .row: 48px, radius 11, 12px gap, 6px 12px padding; .tt b 600 15px, small 500 12px muted, .v 700 17px num in the accent. */
export function GcRow(p: GcRowProps) {
	const h = p.height ?? (p.sub !== undefined && !p.phone ? 52 : rowH(p.phone));
	const accent = p.accent ?? Palette.mango;
	return (
		<frame
			Size={new UDim2(1, 0, 0, h)}
			BackgroundColor3={Palette.white}
			BackgroundTransparency={0}
			BorderSizePixel={0}
			LayoutOrder={p.layoutOrder ?? 0}
			{...(p.name !== undefined ? { Name: p.name } : {})}
		>
			<RowSurface />
			{p.dim === true && <uigradient Transparency={new NumberSequence(0.55)} />}
			{p.ring !== undefined && (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={2}>
					<uicorner CornerRadius={new UDim(0, 11)} />
					<uistroke Color={p.ring} Thickness={2} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
				</frame>
			)}
			{/* content sits in its own frame so the highlight ring above is not stacked as a list item */}
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
					<uipadding PaddingLeft={new UDim(0, p.phone ? 10 : 12)} PaddingRight={new UDim(0, p.phone ? 10 : 12)} />
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 12)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
				{p.lead}
				{p.lead === undefined && p.icon !== undefined && <IconWell icon={p.icon} accent={accent} size={p.phone ? 30 : 36} layoutOrder={0} />}
				<frame Size={new UDim2(0, p.titleWidth ?? 0, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
					{p.titleWidth === undefined && <uiflexitem FlexMode={Enum.UIFlexMode.Fill} />}
					<uilistlayout FillDirection={Enum.FillDirection.Vertical} VerticalAlignment={Enum.VerticalAlignment.Center} Padding={new UDim(0, 2)} SortOrder={Enum.SortOrder.LayoutOrder} />
					<Line text={p.title} size={p.phone ? 13 : 15} font={BODY_SEMI} width={new UDim(1, 0)} layoutOrder={0} />
					{p.sub !== undefined && <Line text={p.sub} size={p.phone ? 11 : 12} font={BODY} color={Palette.muted} width={new UDim(1, 0)} layoutOrder={1} />}
				</frame>
				{p.middle !== undefined && (
					<frame Size={new UDim2(0, 0, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
						<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
						<uilistlayout FillDirection={Enum.FillDirection.Horizontal} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
						{p.middle}
					</frame>
				)}
				{p.value !== undefined && <Line text={p.value} size={p.phone ? 15 : 17} font={p.valueFont ?? NUM} color={p.valueColor ?? accent} layoutOrder={3} />}
				{p.right !== undefined && (
					<frame Size={UDim2.fromOffset(0, h - 8)} AutomaticSize={Enum.AutomaticSize.X} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={4}>
						<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 8)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
						{p.right}
					</frame>
				)}
			</frame>
		</frame>
	);
}

/** Page host: a vertical scroller with the .main gap; content sizes itself. */
export function GcScroll(p: { phone: boolean; children?: React.ReactNode; name?: string; tail?: number; dir?: "col" | "row" }) {
	return (
		<scrollingframe
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			CanvasSize={UDim2.fromScale(0, 0)}
			AutomaticCanvasSize={Enum.AutomaticSize.Y}
			ScrollingDirection={Enum.ScrollingDirection.Y}
			ScrollBarThickness={4}
			ScrollBarImageColor3={Palette.brass}
			ScrollBarImageTransparency={0.4}
			{...(p.name !== undefined ? { Name: p.name } : {})}
		>
			<uipadding PaddingRight={new UDim(0, 6)} PaddingBottom={new UDim(0, p.tail ?? (p.phone ? 10 : 24))} />
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, p.phone ? 8 : 18)} SortOrder={Enum.SortOrder.LayoutOrder} />
			{p.children}
		</scrollingframe>
	);
}

/** Spacer used where the stylesheet has a .sp flex filler inside a column. */
export function Spacer(p: { layoutOrder?: number; height?: number }) {
	return <frame Size={new UDim2(1, 0, 0, p.height ?? 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={p.layoutOrder ?? 0} />;
}

/** Small muted note line (500 14px muted). */
export function Note(p: { text: string | React.Binding<string>; layoutOrder?: number; phone: boolean; color?: Color3 }) {
	return <Line text={p.text} size={p.phone ? 12 : 14} font={BODY} color={p.color ?? Palette.muted} width={new UDim(1, 0)} layoutOrder={p.layoutOrder} />;
}

export { spaced };

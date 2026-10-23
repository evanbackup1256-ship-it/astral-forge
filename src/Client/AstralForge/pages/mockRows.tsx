// Group B page bodies: .row / .btn / icon-well pieces from design/system/af.css (1920x1080; `phone` = the .p rules).
// Local to the progression and economy pages; the shared mockKit stays untouched.
import React from "@rbxts/react";
import { Palette, TapTarget } from "../CoreKit/theme";
import { Button } from "../UiCore/ui";
import { BODY, BODY_SEMI, Glyph, Line, NUM, RowSurface, TITLE_FACE } from "../UiCore/mockKit";

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
	const width = p.fill === true ? new UDim(1, 0) : new UDim(0, p.width ?? 0);
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
				hug={p.width === undefined && p.fill !== true}
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
	const left = p.icon !== undefined ? wellSize + 12 : 0;
	const right = (p.rightWidth ?? 0) + (p.value !== undefined ? (phone ? 110 : 170) : 0);
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
			<RowSurface />
			{p.outline !== undefined && <uistroke Color={p.outline} Thickness={1.5} Transparency={0.2} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />}
			<uipadding PaddingLeft={new UDim(0, phone ? 10 : 12)} PaddingRight={new UDim(0, phone ? 10 : 12)} />
			{p.icon !== undefined && (
				<frame Size={UDim2.fromOffset(wellSize, wellSize)} Position={new UDim2(0, 0, 0.5, 0)} AnchorPoint={new Vector2(0, 0.5)} BackgroundTransparency={1}>
					<IconWell icon={p.icon} accent={p.dim === true ? Palette.muted : accent} size={wellSize} />
				</frame>
			)}
			<frame
				Size={new UDim2(1, -(left + right + (right > 0 ? 12 : 0)), 0, block)}
				Position={new UDim2(0, left, 0.5, 0)}
				AnchorPoint={new Vector2(0, 0.5)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
			>
				<Line text={p.title} size={titleSize} font={p.serif === true ? TITLE_FACE : BODY_SEMI} width={new UDim(1, 0)} color={p.dim === true ? Palette.creamSoft : Palette.cream} />
				{p.sub !== undefined && (
					<Line text={p.sub} size={subSize} font={BODY} color={Palette.muted} width={new UDim(1, 0)} position={UDim2.fromOffset(0, titleSize + 6)} height={subSize + 3} />
				)}
			</frame>
			{p.value !== undefined && (
				<Line
					text={p.value}
					size={phone ? 14 : 17}
					font={NUM}
					color={p.valueColor ?? accent}
					width={new UDim(0, phone ? 110 : 170)}
					align={Enum.TextXAlignment.Right}
					position={new UDim2(1, -(p.rightWidth ?? 0) - (p.rightWidth !== undefined ? 12 : 0), 0.5, 0)}
					anchor={new Vector2(1, 0.5)}
				/>
			)}
			{p.right !== undefined && (
				<frame
					Size={UDim2.fromOffset(p.rightWidth ?? 0, h)}
					Position={new UDim2(1, 0, 0.5, 0)}
					AnchorPoint={new Vector2(1, 0.5)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
				>
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

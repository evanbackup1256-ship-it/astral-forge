// Flex layout pieces for the mockup page bodies (design/system/af.css .flexr / .flexc / .f1 / .wrap).
// Every child is placed by a UIListLayout (SortOrder LayoutOrder), so nothing is positioned by hand:
//   .flexr         -> FlexRow     (horizontal list, fixed height, children fill the height)
//   .flexc         -> FlexCol     (vertical list, hugs its children unless a height is given)
//   .f1            -> FlexFill    (takes the remaining main-axis space)
//   width:430px    -> FlexFixed   (fixed main-axis size)
//   .tabs strip    -> TabStrip    (the hero .tabs row for pages whose hero is drawn by the shell)
import React from "@rbxts/react";
import { Palette, TapTarget } from "../CoreKit/theme";
import { kitMember, LuauComponent } from "./luauKits";
import { BODY_SEMI, Line } from "../UiCore/mockKit";

const { SegmentedTabs } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");

export function FlexRow(p: {
	height?: number;
	gap: number;
	layoutOrder?: number;
	name?: string;
	align?: Enum.VerticalAlignment;
	justify?: Enum.HorizontalAlignment;
	fillHeight?: boolean;
	children?: React.ReactNode;
}) {
	return (
		<frame
			Size={p.height !== undefined ? new UDim2(1, 0, 0, p.height) : p.fillHeight === true ? UDim2.fromScale(1, 1) : new UDim2(1, 0, 0, 0)}
			AutomaticSize={p.height === undefined && p.fillHeight !== true ? Enum.AutomaticSize.Y : Enum.AutomaticSize.None}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			LayoutOrder={p.layoutOrder ?? 0}
			{...(p.name !== undefined ? { Name: p.name } : {})}
		>
			<uilistlayout
				FillDirection={Enum.FillDirection.Horizontal}
				Padding={new UDim(0, p.gap)}
				SortOrder={Enum.SortOrder.LayoutOrder}
				VerticalAlignment={p.align ?? Enum.VerticalAlignment.Top}
				HorizontalAlignment={p.justify ?? Enum.HorizontalAlignment.Left}
			/>
			{p.children}
		</frame>
	);
}

export function FlexCol(p: { height?: number; gap: number; layoutOrder?: number; name?: string; fill?: boolean; width?: number; children?: React.ReactNode }) {
	const w = p.width !== undefined ? new UDim(0, p.width) : new UDim(1, 0);
	return (
		<frame
			Size={p.height !== undefined ? new UDim2(w, new UDim(0, p.height)) : p.fill === true ? new UDim2(w, new UDim(1, 0)) : new UDim2(w, new UDim(0, 0))}
			AutomaticSize={p.height === undefined && p.fill !== true ? Enum.AutomaticSize.Y : Enum.AutomaticSize.None}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			LayoutOrder={p.layoutOrder ?? 0}
			{...(p.name !== undefined ? { Name: p.name } : {})}
		>
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, p.gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
			{p.children}
		</frame>
	);
}

/** .f1 inside a FlexRow: zero base width, grows into the free space; full row height. */
export function FlexFill(p: { layoutOrder?: number; name?: string; height?: number; children?: React.ReactNode }) {
	return (
		<frame
			Size={p.height !== undefined ? UDim2.fromOffset(0, p.height) : new UDim2(0, 0, 1, 0)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			LayoutOrder={p.layoutOrder ?? 0}
			{...(p.name !== undefined ? { Name: p.name } : {})}
		>
			<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
			{p.children}
		</frame>
	);
}

/** Fixed-width cell inside a FlexRow (full row height unless `height` is set). */
export function FlexFixed(p: { width: number; height?: number; layoutOrder?: number; name?: string; children?: React.ReactNode }) {
	return (
		<frame
			Size={p.height !== undefined ? UDim2.fromOffset(p.width, p.height) : new UDim2(0, p.width, 1, 0)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			LayoutOrder={p.layoutOrder ?? 0}
			{...(p.name !== undefined ? { Name: p.name } : {})}
		>
			{p.children}
		</frame>
	);
}

/** Height of a vertical stack of fixed blocks with a gap. */
export function stackSum(heights: number[], gap: number): number {
	let total = 0;
	for (const value of heights) total += value;
	return total + math.max(0, heights.size() - 1) * gap;
}

/** Hero .tabs for pages whose .hero is the shell header: a note on the left, the tabs on the right. */
export const TAB_STRIP_H = TapTarget;
export function TabStrip(p: {
	options: { id: string; label: string }[];
	value: string;
	onChange: (id: string) => void;
	accent: Color3;
	phone: boolean;
	note?: string;
	width?: number;
	reducedMotion?: boolean;
	layoutOrder?: number;
}) {
	const w = p.width ?? math.max(200, p.options.size() * (p.phone ? 84 : 104));
	return (
		<FlexRow height={TAB_STRIP_H} gap={12} align={Enum.VerticalAlignment.Center} layoutOrder={p.layoutOrder} name="TabStrip">
			<FlexFill layoutOrder={0}>
				{p.note !== undefined && (
					<Line text={p.note} size={p.phone ? 12 : 14} font={BODY_SEMI} color={Palette.muted} width={new UDim(1, 0)} height={TAB_STRIP_H} />
				)}
			</FlexFill>
			<FlexFixed width={w} layoutOrder={1}>
				<SegmentedTabs options={p.options} value={p.value} onChange={p.onChange} accent={p.accent} size={UDim2.fromScale(1, 1)} reducedMotion={p.reducedMotion} />
			</FlexFixed>
		</FlexRow>
	);
}

/** One line slot in a vertical list: fixed height, full width, holds a single text/meter element. */
export function Slot(p: { height: number; layoutOrder: number; name?: string; children?: React.ReactNode }) {
	return (
		<frame
			Size={new UDim2(1, 0, 0, p.height)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			LayoutOrder={p.layoutOrder}
			ClipsDescendants={false}
			{...(p.name !== undefined ? { Name: p.name } : {})}
		>
			{p.children}
		</frame>
	);
}

/**
 * The mockups' card row (.row / .it): [lead tile] [copy column, fills] [action column].
 * Wide: one horizontal list, action vertically centred. Stacked: copy row on top, the action
 * full width underneath. Everything is list-laid; `copy` children should carry LayoutOrder.
 */
export function CardBody(p: {
	stack: boolean;
	gap?: number;
	copyGap?: number;
	lead?: React.Element;
	leadSize?: number;
	action?: React.Element;
	actionWidth?: number;
	actionHeight?: number;
	actionName?: string;
	actionRef?: React.Ref<Frame>;
	children?: React.ReactNode;
}) {
	const gap = p.gap ?? 12;
	const actionH = p.actionHeight ?? TapTarget;
	const action =
		p.action !== undefined ? (
			<frame
				key={p.actionName ?? "Action"}
				Size={p.stack ? new UDim2(1, 0, 0, actionH) : UDim2.fromOffset(p.actionWidth ?? 140, actionH)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={false}
				LayoutOrder={2}
				ref={p.actionRef}
			>
				{p.action}
			</frame>
		) : undefined;
	const lead =
		p.lead !== undefined ? (
			<frame key="Lead" Size={UDim2.fromOffset(p.leadSize ?? 48, p.leadSize ?? 48)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={0}>
				{p.lead}
			</frame>
		) : undefined;
	const copy = (
		<frame key="Copy" Size={new UDim2(0, 0, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1} ClipsDescendants={false}>
			<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
			<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, p.copyGap ?? 4)} VerticalAlignment={Enum.VerticalAlignment.Center} />
			{p.children}
		</frame>
	);
	if (p.stack) {
		return (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
				<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 8)} />
				<frame key="Top" Size={new UDim2(1, 0, 1, -(actionH + 8))} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={0} ClipsDescendants={false}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, gap)} />
					{lead}
					{copy}
				</frame>
				{action}
			</frame>
		);
	}
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, gap)} VerticalAlignment={Enum.VerticalAlignment.Center} />
			{lead}
			{copy}
			{action}
		</frame>
	);
}

/**
 * phone.html .ph-head: 40px row, the 12px muted line on the left and the .tabs on the right. The h1 is
 * the mobile shell's own page title, so it isn't drawn twice here.
 */
export const PHONE_HEAD_H = 40;
export function PhoneHead(p: {
	line?: string;
	options?: { id: string; label: string }[];
	value?: string;
	onChange?: (id: string) => void;
	accent: Color3;
	tabsWidth?: number;
	reducedMotion?: boolean;
	layoutOrder?: number;
}) {
	const tabs = p.options !== undefined && p.options.size() > 0;
	const w = p.tabsWidth ?? (tabs ? p.options!.size() * 78 + 8 : 0);
	return (
		<FlexRow height={PHONE_HEAD_H} gap={10} align={Enum.VerticalAlignment.Center} layoutOrder={p.layoutOrder} name="PhoneHead">
			<FlexFill layoutOrder={0}>
				{p.line !== undefined && <Line text={p.line} size={12} font={BODY_SEMI} color={Palette.muted} width={new UDim(1, 0)} height={PHONE_HEAD_H} />}
			</FlexFill>
			{tabs && (
				<FlexFixed width={w} height={TapTarget} layoutOrder={1}>
					<SegmentedTabs options={p.options} value={p.value} onChange={p.onChange} accent={p.accent} gap={4} size={UDim2.fromScale(1, 1)} reducedMotion={p.reducedMotion} />
				</FlexFixed>
			)}
		</FlexRow>
	);
}

import React from "@rbxts/react";
import { isGamepadDevice, isTouchDevice } from "../CoreKit/interaction";
import { TapTarget } from "../CoreKit/theme";
import { useViewport } from "./motion";

export type FlexSurface = "gamepad" | "touch" | "desktop";
export type FlexJustify = "fill" | "space-between" | "space-around" | "space-evenly" | "none";
export type FlexAlign = "start" | "center" | "end" | "stretch";
export type FlexMode = "grow" | "shrink" | "fill" | "custom" | "none";

export interface FlexPlatform {
	surface: FlexSurface;
	wrap: boolean;
	gap: number;
	minWidth: number;
	minHeight: number;
	justify: FlexJustify;
}

export function flexSurface(): FlexSurface {
	if (isGamepadDevice()) {
		return "gamepad";
	}
	if (isTouchDevice()) {
		return "touch";
	}
	return "desktop";
}

export function useFlexPlatform(): FlexPlatform {
	const surface = flexSurface();
	if (surface === "touch") {
		return { surface, wrap: true, gap: 8, minWidth: TapTarget, minHeight: TapTarget, justify: "fill" };
	}
	if (surface === "gamepad") {
		return { surface, wrap: false, gap: 14, minWidth: TapTarget + 16, minHeight: TapTarget + 8, justify: "space-between" };
	}
	return { surface, wrap: true, gap: 12, minWidth: 120, minHeight: 48, justify: "fill" };
}

function justifyEnum(value: FlexJustify): Enum.UIFlexAlignment {
	if (value === "fill") {
		return Enum.UIFlexAlignment.Fill;
	}
	if (value === "space-between") {
		return Enum.UIFlexAlignment.SpaceBetween;
	}
	if (value === "space-around") {
		return Enum.UIFlexAlignment.SpaceAround;
	}
	if (value === "space-evenly") {
		return Enum.UIFlexAlignment.SpaceEvenly;
	}
	return Enum.UIFlexAlignment.None;
}

function alignEnum(value: FlexAlign): Enum.ItemLineAlignment {
	if (value === "start") {
		return Enum.ItemLineAlignment.Start;
	}
	if (value === "center") {
		return Enum.ItemLineAlignment.Center;
	}
	if (value === "end") {
		return Enum.ItemLineAlignment.End;
	}
	if (value === "stretch") {
		return Enum.ItemLineAlignment.Stretch;
	}
	return Enum.ItemLineAlignment.Automatic;
}

function modeEnum(value: FlexMode): Enum.UIFlexMode {
	if (value === "grow") {
		return Enum.UIFlexMode.Grow;
	}
	if (value === "shrink") {
		return Enum.UIFlexMode.Shrink;
	}
	if (value === "fill") {
		return Enum.UIFlexMode.Fill;
	}
	if (value === "custom") {
		return Enum.UIFlexMode.Custom;
	}
	return Enum.UIFlexMode.None;
}

function mainAlign(direction: "row" | "column", align: FlexAlign) {
	if (direction === "row") {
		return {
			horizontal: Enum.HorizontalAlignment.Left,
			vertical: align === "end" ? Enum.VerticalAlignment.Bottom : align === "start" ? Enum.VerticalAlignment.Top : Enum.VerticalAlignment.Center,
		};
	}
	return {
		horizontal: align === "end" ? Enum.HorizontalAlignment.Right : align === "start" ? Enum.HorizontalAlignment.Left : Enum.HorizontalAlignment.Center,
		vertical: Enum.VerticalAlignment.Top,
	};
}

export interface FlexProps {
	children?: React.ReactNode;
	direction?: "row" | "column";
	wrap?: boolean;
	justify?: FlexJustify;
	align?: FlexAlign;
	gap?: number;
	size?: UDim2;
	position?: UDim2;
	layoutOrder?: number;
	zIndex?: number;
	clips?: boolean;
	exact?: boolean;
}

export function Flex({
	children,
	direction = "row",
	wrap,
	justify,
	align = "center",
	gap,
	size = UDim2.fromScale(1, 1),
	position,
	layoutOrder = 0,
	zIndex = 1,
	clips = false,
	exact = false,
}: FlexProps) {
	const platform = useFlexPlatform();
	const wraps = wrap ?? (exact ? false : platform.wrap);
	const padding = gap ?? (exact ? 8 : platform.gap);
	const distribution = justify ?? (exact ? "none" : platform.justify);
	const main = mainAlign(direction, align);
	return (
		<frame
			Size={size}
			Position={position}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			LayoutOrder={layoutOrder}
			ZIndex={zIndex}
			ClipsDescendants={clips}
		>
			<uilistlayout
				FillDirection={direction === "column" ? Enum.FillDirection.Vertical : Enum.FillDirection.Horizontal}
				SortOrder={Enum.SortOrder.LayoutOrder}
				Padding={new UDim(0, padding)}
				Wraps={wraps}
				HorizontalFlex={direction === "row" ? justifyEnum(distribution) : Enum.UIFlexAlignment.None}
				VerticalFlex={direction === "column" ? justifyEnum(distribution) : Enum.UIFlexAlignment.None}
				ItemLineAlignment={alignEnum(align)}
				HorizontalAlignment={main.horizontal}
				VerticalAlignment={main.vertical}
			/>
			{children}
		</frame>
	);
}

export interface FlexItemProps {
	children?: React.ReactNode;
	mode?: FlexMode;
	grow?: number;
	shrink?: number;
	minWidth?: number;
	minHeight?: number;
	maxWidth?: number;
	maxHeight?: number;
	size?: UDim2;
	automaticSize?: Enum.AutomaticSize;
	layoutOrder?: number;
	zIndex?: number;
}

export function FlexItem({
	children,
	mode = "grow",
	grow,
	shrink,
	minWidth,
	minHeight,
	maxWidth,
	maxHeight,
	size,
	automaticSize = Enum.AutomaticSize.None,
	layoutOrder = 0,
	zIndex = 1,
}: FlexItemProps) {
	const platform = useFlexPlatform();
	const floorX = minWidth ?? platform.minWidth;
	const floorY = minHeight ?? platform.minHeight;
	const itemSize = size ?? (mode === "fill" || mode === "grow" ? new UDim2(0, floorX, 0, floorY) : UDim2.fromOffset(floorX, floorY));
	return (
		<frame
			Size={itemSize}
			AutomaticSize={automaticSize}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			LayoutOrder={layoutOrder}
			ZIndex={zIndex}
			ClipsDescendants={false}
		>
			<uiflexitem FlexMode={modeEnum(mode)} GrowRatio={grow ?? 1} ShrinkRatio={shrink ?? 1} />
			<uisizeconstraint MinSize={new Vector2(floorX, floorY)} MaxSize={new Vector2(maxWidth ?? math.huge, maxHeight ?? math.huge)} />
			{children}
		</frame>
	);
}

export function packColumns(width: number, surface: FlexSurface = flexSurface()): number {
	if (surface === "touch" || width < 640) {
		return 2;
	}
	if (surface === "gamepad" || width < 1100) {
		return 3;
	}
	return 4;
}

function isFlexChildList(value: unknown): value is unknown[] {
	if (!typeIs(value, "table")) {
		return false;
	}
	const record = value as Record<string, unknown>;
	if (record.component !== undefined || record.type !== undefined || record.props !== undefined) {
		return false;
	}
	let numeric = 0;
	let named = 0;
	for (const [key] of pairs(record)) {
		if (typeIs(key, "number")) {
			numeric += 1;
		} else {
			named += 1;
		}
	}
	return numeric > 0 && named === 0;
}

function flattenFlexChildren(value: unknown, into: defined[] = []): defined[] {
	if (value === undefined || value === false || value === true) {
		return into;
	}
	if (isFlexChildList(value)) {
		for (const [, child] of pairs(value)) {
			flattenFlexChildren(child, into);
		}
		return into;
	}
	into.push(value as defined);
	return into;
}

export function useShopColumns(): number {
	const viewport = useViewport();
	const contentW = math.max(280, viewport.width - (viewport.width >= 1100 ? 320 : viewport.width >= 760 ? 96 : 36));
	if (contentW < 540) {
		return 1;
	}
	if (contentW < 900) {
		return 2;
	}
	return 3;
}

export function usePackColumns(): number {
	const viewport = useViewport();
	return packColumns(viewport.width, flexSurface());
}

export const PACK_BREAKPOINTS = [
	{ minWidth: 0, columns: 2 },
	{ minWidth: 640, columns: 3 },
	{ minWidth: 1100, columns: 4 },
];

export interface FlexGridProps {
	children?: React.ReactNode;
	columns?: number;
	gap?: number;
	cellMinWidth?: number;
	cellMinHeight?: number;
	size?: UDim2;
	layoutOrder?: number;
}

export function FlexGrid({ children, columns, gap, cellMinHeight = 160, size = new UDim2(1, 0, 0, 0), layoutOrder = 0 }: FlexGridProps) {
	const packed = usePackColumns();
	const cols = math.max(1, columns ?? packed);
	const platform = useFlexPlatform();
	const gapPx = gap ?? platform.gap;
	const nodes = flattenFlexChildren(children);
	return (
		<frame Size={size} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={layoutOrder} ClipsDescendants={false}>
			<uigridlayout
				CellSize={new UDim2(1 / cols, -math.ceil((gapPx * (cols - 1)) / cols), 0, cellMinHeight)}
				CellPadding={new UDim2(0, gapPx, 0, gapPx)}
				FillDirection={Enum.FillDirection.Horizontal}
				FillDirectionMaxCells={cols}
				SortOrder={Enum.SortOrder.LayoutOrder}
				HorizontalAlignment={Enum.HorizontalAlignment.Left}
				VerticalAlignment={Enum.VerticalAlignment.Top}
			/>
			{nodes.map((child, index) => (
				<frame
					key={`pack-${index}`}
					Size={UDim2.fromScale(1, 1)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					LayoutOrder={index}
					ClipsDescendants={false}
				>
					{child as React.ReactNode}
				</frame>
			))}
		</frame>
	);
}

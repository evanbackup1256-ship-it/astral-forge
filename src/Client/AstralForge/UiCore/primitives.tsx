// UiCore primitives: the short, typed front door to the game's building blocks.
//
//   Panel   Card   Button   Tabs   Chips   Modal   List   Grid
//
// Each one renders the existing component (ui.tsx Panel/Button/SegmentedTabs, FilterChipRow,
// ConfirmDialog-style overlay presence), so visuals, effects and motion are exactly what pages
// already show. What's new is the API: token-based spacing, typed props with no `unknown`
// passthroughs, and Grid/List laid out by layoutEngine (fitColumns) instead of hand math.
import React from "@rbxts/react";
import { Palette, TapTarget } from "../CoreKit/theme";
import { revealOffset, usePresence } from "../MotionKit/motion";
import { FilterChipOption, FilterChipRow } from "./FilterChips";
import { fitColumns } from "./layoutEngine";
import { ModalSelectionScope, overlayZ, useOverlay } from "./overlayCore";
import { SpaceToken, space } from "./tokens";
import { TooltipContent } from "./tooltip/content";
import { Button as CoreButton, OverlayPresence, Panel as CorePanel, SegmentedOption, SegmentedTabs, useGamepadAutofocus } from "./ui";

type Bindable<T> = T | React.Binding<T>;

// ── Panel / Card ───────────────────────────────────────────────────────────────

export interface PanelPrimitiveProps {
	size?: Bindable<UDim2>;
	position?: Bindable<UDim2>;
	accent?: Color3;
	background?: Color3;
	pad?: SpaceToken | number;
	order?: number;
	zIndex?: number;
	clips?: boolean;
	reveal?: React.Binding<number>;
	highlight?: boolean;
	shimmer?: boolean;
	reducedMotion?: boolean;
	children?: React.ReactNode;
}

/** A forged panel: the game's Panel with token padding. */
export function UiPanel(props: PanelPrimitiveProps) {
	return (
		<CorePanel
			size={props.size}
			position={props.position}
			accent={props.accent}
			background={props.background}
			padding={props.pad !== undefined ? space(props.pad) : undefined}
			layoutOrder={props.order}
			zIndex={props.zIndex}
			clips={props.clips}
			reveal={props.reveal}
			highlight={props.highlight}
			shimmer={props.shimmer}
			reducedMotion={props.reducedMotion}
		>
			{props.children}
		</CorePanel>
	);
}

/** A raised card inside a panel: same Panel, interactive hover, raised fill. */
export function UiCard(props: PanelPrimitiveProps & { onPress?: () => void }) {
	return (
		<CorePanel
			size={props.size}
			position={props.position}
			accent={props.accent}
			background={props.background ?? Palette.panelRaised}
			padding={space(props.pad ?? "md")}
			layoutOrder={props.order}
			zIndex={props.zIndex}
			clips={props.clips}
			reveal={props.reveal}
			highlight={props.highlight}
			shimmer={props.shimmer}
			interactive={props.onPress !== undefined}
			reducedMotion={props.reducedMotion}
		>
			{props.children}
		</CorePanel>
	);
}

// ── Button ─────────────────────────────────────────────────────────────────────

export interface ButtonPrimitiveProps {
	text?: string;
	icon?: string;
	onPress: () => void;
	variant?: "solid" | "outline";
	color?: Color3;
	size?: UDim2;
	position?: Bindable<UDim2>;
	disabled?: boolean;
	loading?: boolean;
	hug?: boolean;
	tooltip?: TooltipContent;
	zIndex?: number;
	reducedMotion?: boolean;
}

export function UiButton(props: ButtonPrimitiveProps) {
	return (
		<CoreButton
			text={props.text}
			icon={props.icon}
			onClick={props.onPress}
			outline={props.variant === "outline"}
			color={props.color}
			size={props.size}
			position={props.position}
			disabled={props.disabled}
			loading={props.loading}
			hug={props.hug}
			tooltip={props.tooltip}
			zIndex={props.zIndex}
			reducedMotion={props.reducedMotion}
		/>
	);
}

// ── Tabs / Chips ───────────────────────────────────────────────────────────────

export interface TabsPrimitiveProps {
	options: SegmentedOption[];
	value?: string;
	onChange: (id: string) => void;
	accent?: Color3;
	columns?: number;
	size?: Bindable<UDim2>;
	position?: Bindable<UDim2>;
	order?: number;
	zIndex?: number;
	reducedMotion?: boolean;
}

export function UiTabs(props: TabsPrimitiveProps) {
	return (
		<SegmentedTabs
			options={props.options}
			value={props.value}
			onChange={props.onChange}
			accent={props.accent}
			columns={props.columns}
			size={props.size}
			position={props.position}
			layoutOrder={props.order}
			zIndex={props.zIndex}
			reducedMotion={props.reducedMotion}
		/>
	);
}

export interface ChipsPrimitiveProps {
	options: ReadonlyArray<FilterChipOption>;
	value?: string;
	onChange: (id: string) => void;
	counts?: Record<string, number>;
	accent?: Color3;
	size?: UDim2;
	position?: UDim2;
	order?: number;
	zIndex?: number;
}

export function UiChips(props: ChipsPrimitiveProps) {
	return (
		<FilterChipRow
			options={props.options}
			value={props.value}
			onChange={props.onChange}
			counts={props.counts}
			accent={props.accent}
			size={props.size}
			position={props.position}
			layoutOrder={props.order}
			zIndex={props.zIndex}
		/>
	);
}

// ── List / Grid ────────────────────────────────────────────────────────────────

export interface ListPrimitiveProps<T extends defined> {
	items: ReadonlyArray<T>;
	render: (item: T, index: number) => React.ReactNode;
	key?: (item: T, index: number) => string;
	gap?: SpaceToken | number;
	horizontal?: boolean;
	size?: UDim2;
	position?: UDim2;
	order?: number;
}

/** A vertical (or horizontal) stack that sizes to its content. */
export function UiList<T extends defined>(props: ListPrimitiveProps<T>) {
	const horizontal = props.horizontal === true;
	const children: Record<string, React.ReactNode> = {};
	props.items.forEach((item, index) => {
		children[props.key !== undefined ? props.key(item, index) : `item${index}`] = (
			<frame Size={UDim2.fromScale(0, 0)} AutomaticSize={Enum.AutomaticSize.XY} BackgroundTransparency={1} LayoutOrder={index}>
				{props.render(item, index)}
			</frame>
		);
	});
	return (
		<frame
			Size={props.size ?? (horizontal ? UDim2.fromScale(0, 1) : UDim2.fromScale(1, 0))}
			AutomaticSize={horizontal ? Enum.AutomaticSize.X : Enum.AutomaticSize.Y}
			Position={props.position}
			LayoutOrder={props.order}
			BackgroundTransparency={1}
		>
			<uilistlayout
				FillDirection={horizontal ? Enum.FillDirection.Horizontal : Enum.FillDirection.Vertical}
				SortOrder={Enum.SortOrder.LayoutOrder}
				Padding={new UDim(0, space(props.gap ?? "sm"))}
			/>
			{children}
		</frame>
	);
}

export interface GridPrimitiveProps<T extends defined> {
	items: ReadonlyArray<T>;
	render: (item: T, index: number, cell: number) => React.ReactNode;
	key?: (item: T, index: number) => string;
	/** available width in pixels (from the page layout) */
	width: number;
	minCell: number;
	maxCell?: number;
	maxColumns?: number;
	cellHeight: number;
	gap?: SpaceToken | number;
	position?: UDim2;
	order?: number;
}

/** A grid whose columns fit the width and item count (layoutEngine.fitColumns): no orphan gaps. */
export function UiGrid<T extends defined>(props: GridPrimitiveProps<T>) {
	const gap = space(props.gap ?? "md");
	const fit = fitColumns(props.width, props.items.size(), props.minCell, props.maxColumns ?? 6, gap, props.maxCell);
	const height = fit.rows * props.cellHeight + math.max(0, fit.rows - 1) * gap;
	const children: Record<string, React.ReactNode> = {};
	props.items.forEach((item, index) => {
		const column = index % fit.columns;
		const row = math.floor(index / fit.columns);
		children[props.key !== undefined ? props.key(item, index) : `cell${index}`] = (
			<frame
				Size={UDim2.fromOffset(fit.cell, props.cellHeight)}
				Position={UDim2.fromOffset(column * (fit.cell + fit.gap), row * (props.cellHeight + gap))}
				BackgroundTransparency={1}
			>
				{props.render(item, index, fit.cell)}
			</frame>
		);
	});
	return (
		<frame Size={new UDim2(1, 0, 0, height)} Position={props.position} LayoutOrder={props.order} BackgroundTransparency={1}>
			{children}
		</frame>
	);
}

// ── Modal ──────────────────────────────────────────────────────────────────────

export interface ModalPrimitiveProps {
	name: string;
	width: number;
	height: number;
	accent?: Color3;
	/** B, Esc or a tap on the backdrop; omit to make the modal stay until an action closes it */
	onClose?: () => void;
	reducedMotion?: boolean;
	children?: React.ReactNode;
}

/**
 * A centered modal on a dimmed backdrop: the same presence spring, revealOffset rise and 0.8
 * backdrop as ConfirmDialog. Joins the overlay stack, keeps gamepad selection inside, and moves
 * focus in once the open motion settles.
 */
export function UiModal(props: ModalPrimitiveProps) {
	const [reveal] = usePresence(props.reducedMotion);
	const [depth] = useOverlay(props.name, true, props.onClose);
	const z = overlayZ(depth);
	const focus = useGamepadAutofocus(true, reveal);
	return (
		<OverlayPresence amount={reveal}>
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ZIndex={z} Visible={reveal.map((a) => a > 0.01)}>
				<imagebutton
					Size={UDim2.fromScale(1, 1)}
					BackgroundColor3={Palette.void}
					BackgroundTransparency={reveal.map((a) => 1 - a * 0.8)}
					BorderSizePixel={0}
					AutoButtonColor={false}
					Active={true}
					Selectable={false}
					ZIndex={z + 1}
					Event={{ Activated: () => props.onClose?.() }}
				/>
				<frame
					ref={focus as React.Ref<Frame>}
					{...ModalSelectionScope}
					Size={UDim2.fromOffset(props.width, math.max(props.height, TapTarget))}
					Position={reveal.map((a) => new UDim2(0.5, 0, 0.5, revealOffset(a)))}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundTransparency={1}
					ZIndex={z + 2}
				>
					<CorePanel size={UDim2.fromScale(1, 1)} accent={props.accent} background={Palette.panelRaised} zIndex={z + 3} reveal={reveal} reducedMotion={props.reducedMotion}>
						{props.children}
					</CorePanel>
				</frame>
			</frame>
		</OverlayPresence>
	);
}

// The relic tab's pieces: the toolbar (bag, essence, search, filter/rarity/sort, equip best, multi
// salvage, auto-salvage), the bulk-salvage dock, the auto-salvage sheet, and one relic row.
import React from "@rbxts/react";
import { itemIconKind } from "../../../ArtKit/Icon";
import * as GamepadNavigationService from "../../../CoreKit/GamepadNavigationService";
import { AutoSalvageRules, EffectLabel, OwnedItem, RarityColor, RelicRowHeight, SocketLabel } from "../../../CoreKit/inventoryMath";
import { compactNumber } from "../../../CoreKit/format";
import { Palette, Radius, Space, TapTarget } from "../../../CoreKit/theme";
import { useTooltip } from "../../../Tooltip";
import { counted, memoRow, sameFields } from "../../../UiCore/rowMemo";
import { Badge, Button, Dropdown, IconTile, Panel, SearchField, Text } from "../../../UiCore/ui";
import { loadAudio, named } from "../../luauDeps";

const UserInputService = game.GetService("UserInputService");
const Audio = loadAudio();

export const TABS = ["Relics", "Crates", "Market", "Recipes", "Loadout"];
export const TAB_OPTIONS = TABS.map((id) => ({ id, label: string.upper(id) }));
const FILTERS = [
	{ id: "All", label: "All relics" },
	{ id: "Machine", label: "Machine slot" },
	{ id: "Research", label: "Research slot" },
	{ id: "Equipped", label: "Equipped only" },
	{ id: "Unequipped", label: "Unequipped only" },
	{ id: "Protected", label: "Protected only" },
	{ id: "Duplicates", label: "Duplicates" },
	{ id: "Starred", label: "Starred only" },
];
const SORTS = [
	{ id: "Rarity", label: "Rarity first" },
	{ id: "Power", label: "Highest power" },
	{ id: "Weakest", label: "Lowest power" },
	{ id: "Level", label: "Highest level" },
	{ id: "Newest", label: "Newest first" },
	{ id: "Stars", label: "Most stars" },
	{ id: "Salvage", label: "Salvage value" },
	{ id: "Name", label: "Name A-Z" },
];
const RARITY_FILTERS = [
	{ id: "Any", label: "Any rarity" },
	{ id: "Common", label: "Common" },
	{ id: "Uncommon", label: "Uncommon" },
	{ id: "Rare", label: "Rare" },
	{ id: "Epic", label: "Epic" },
	{ id: "Legendary", label: "Legendary" },
	{ id: "Mythic", label: "Mythic" },
	{ id: "Celestial", label: "Celestial" },
	{ id: "Astral", label: "Astral" },
];
const AUTO_RARITIES = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"];
export const HERO_H = 96;
export const HERO_H_STACK = 124;
export const ROW_GAP = 10;
export const SCROLL_PAD = 24 + 16;
const TOOL_FIELD_DESK = 50;
export const BULK_DOCK_H = 58;
// every relic row's Panel shares one always-shown reveal, so scrolling never replays an entrance
const RELIC_ROW_SHOWN = React.createBinding(1)[0];

const toolFieldH = (stack: boolean) => (stack ? math.max(TapTarget, 52) : TOOL_FIELD_DESK);

/** How tall InventoryTools draws: padding, the phone badge row, the field row(s) and the action row. */
export function inventoryToolsHeight(stack: boolean): number {
	const fieldH = toolFieldH(stack);
	const pad = stack ? 8 : 12;
	const gap = stack ? 8 : 10;
	return pad * 2 + (stack ? 26 + gap : 0) + (stack ? fieldH * 2 + gap : fieldH) + gap + fieldH;
}

interface ToolsProps {
	search: string;
	setSearch: (value: string) => void;
	filter: string;
	setFilter: (value: string) => void;
	rarity: string;
	setRarity: (value: string) => void;
	sort: string;
	setSort: (value: string) => void;
	bulkMode: boolean;
	setBulkMode: (value: boolean) => void;
	autoOpen: boolean;
	setAutoOpen: (value: boolean) => void;
	equipBest: () => void;
	reducedMotion?: boolean;
	stack: boolean;
	filled: number;
	limit: number;
	essence: unknown;
}

/** Bag and essence counts, search, the three dropdowns, and Equip best / Multi salvage / Auto-salvage. */
export function InventoryTools(props: ToolsProps) {
	const { stack, reducedMotion, bulkMode, autoOpen } = props;
	const fieldH = toolFieldH(stack);
	const gap = stack ? 8 : 10;
	const pad = stack ? 8 : 12;
	const bagW = stack ? 100 : 104;
	const essW = stack ? 112 : 116;
	const metaW = bagW + essW + gap;
	const actionW = new UDim2(1 / 3, -math.ceil((gap * 2) / 3), 0, fieldH);
	const accent = bulkMode ? Palette.coral : autoOpen ? Palette.mango : Palette.violet;
	const badges = (
		<>
			<Badge value={`${props.filled} / ${props.limit} BAG`} accent={Palette.violet} filled={true} size={UDim2.fromOffset(bagW, 26)} />
			<Badge value={`${compactNumber(props.essence)} ESS`} accent={Palette.mango} size={UDim2.fromOffset(essW, 26)} />
		</>
	);
	const badgeRow = (size: UDim2, layoutOrder?: number) => (
		<frame Size={size} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={layoutOrder}>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, gap)} SortOrder={Enum.SortOrder.LayoutOrder} VerticalAlignment={Enum.VerticalAlignment.Center} />
			{badges}
		</frame>
	);
	const search = (size: UDim2) => (
		<SearchField value={props.search} onChange={props.setSearch} placeholder="Search relics, effects, or ID" accent={Palette.violet} size={size} reducedMotion={reducedMotion} zIndex={62} />
	);
	const dropdown = (options: Array<{ id: string; label: string }>, value: string, onChange: (value: string) => void, color: Color3, position: UDim2, size: UDim2, zIndex: number) => (
		<Dropdown options={options} value={value} onChange={onChange} accent={color} position={position} size={size} reducedMotion={reducedMotion} zIndex={zIndex} />
	);
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundColor3={Palette.panelRaised} BorderSizePixel={0} ClipsDescendants={false}>
			<uicorner CornerRadius={new UDim(0, 12)} />
			<uistroke ApplyStrokeMode={Enum.ApplyStrokeMode.Border} LineJoinMode={Enum.LineJoinMode.Round} Color={accent} Thickness={1} Transparency={0.5} />
			<uipadding PaddingTop={new UDim(0, pad)} PaddingBottom={new UDim(0, pad)} PaddingLeft={new UDim(0, pad + 2)} PaddingRight={new UDim(0, pad + 2)} />
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, gap)} />
			{stack && badgeRow(new UDim2(1, 0, 0, 26), 0)}
			<frame Size={new UDim2(1, 0, 0, stack ? fieldH * 2 + gap : fieldH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1} ClipsDescendants={false}>
				{stack ? (
					<>
						{search(new UDim2(1, 0, 0, fieldH))}
						{dropdown(FILTERS, props.filter, props.setFilter, Palette.violet, UDim2.fromOffset(0, fieldH + gap), new UDim2(1 / 3, -6, 0, fieldH), 61)}
						{dropdown(RARITY_FILTERS, props.rarity, props.setRarity, Palette.mango, new UDim2(1 / 3, 2, 0, fieldH + gap), new UDim2(1 / 3, -6, 0, fieldH), 60)}
						{dropdown(SORTS, props.sort, props.setSort, Palette.cyan, new UDim2(2 / 3, 4, 0, fieldH + gap), new UDim2(1 / 3, -4, 0, fieldH), 59)}
					</>
				) : (
					<>
						{badgeRow(UDim2.fromOffset(metaW, fieldH))}
						<frame Size={new UDim2(1, -(metaW + gap), 0, fieldH)} Position={UDim2.fromOffset(metaW + gap, 0)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
							{search(new UDim2(0.4, -6, 0, fieldH))}
							{dropdown(FILTERS, props.filter, props.setFilter, Palette.violet, new UDim2(0.4, 0, 0, 0), new UDim2(0.2, -6, 0, fieldH), 61)}
							{dropdown(RARITY_FILTERS, props.rarity, props.setRarity, Palette.mango, new UDim2(0.6, 0, 0, 0), new UDim2(0.2, -6, 0, fieldH), 60)}
							{dropdown(SORTS, props.sort, props.setSort, Palette.cyan, new UDim2(0.8, 0, 0, 0), new UDim2(0.2, 0, 0, fieldH), 59)}
						</frame>
					</>
				)}
			</frame>
			<frame Size={new UDim2(1, 0, 0, fieldH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2} ClipsDescendants={false}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<Button
					text={stack ? "BEST" : "EQUIP BEST"}
					icon="Loadout.2"
					onClick={props.equipBest}
					color={Palette.mint}
					textColor={Palette.ink}
					size={actionW}
					reducedMotion={reducedMotion}
					highlight={true}
				/>
				<Button
					text={bulkMode ? "DONE" : stack ? "SELECT" : "MULTI SALVAGE"}
					icon={bulkMode ? "Check.18" : "Dust.5"}
					onClick={() => {
						props.setBulkMode(!bulkMode);
						props.setAutoOpen(false);
					}}
					color={bulkMode ? Palette.coral : Palette.panelSoft}
					textColor={bulkMode ? Palette.ink : Palette.creamSoft}
					size={actionW}
					reducedMotion={reducedMotion}
					outline={!bulkMode}
				/>
				<Button
					text={stack ? "RECYCLE" : "AUTO-SALVAGE"}
					icon="Inventory.5"
					onClick={() => {
						props.setAutoOpen(!autoOpen);
						props.setBulkMode(false);
					}}
					color={autoOpen ? Palette.mango : Palette.panelSoft}
					textColor={autoOpen ? Palette.ink : Palette.creamSoft}
					size={actionW}
					reducedMotion={reducedMotion}
					outline={!autoOpen}
				/>
			</frame>
		</frame>
	);
}

interface DockProps {
	selectedCount: number;
	selectableCount: number;
	selectionEssence: number;
	selectVisible: () => void;
	clearSelection: () => void;
	salvageSelected: () => void;
	bulkBusy: boolean;
	bulkArmed?: boolean;
	reducedMotion?: boolean;
}

/** Bulk mode's bottom bar: pick the visible relics, then salvage what's picked. */
export function BulkDock(props: DockProps) {
	const picked = props.selectedCount > 0;
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.panelRaised} BorderSizePixel={0} ZIndex={30} ClipsDescendants={false}>
			<uicorner CornerRadius={new UDim(0, 8)} />
			<uistroke ApplyStrokeMode={Enum.ApplyStrokeMode.Border} LineJoinMode={Enum.LineJoinMode.Round} Color={Palette.coral} Thickness={1} Transparency={0.5} />
			<uipadding PaddingTop={new UDim(0, 8)} PaddingBottom={new UDim(0, 8)} PaddingLeft={new UDim(0, 10)} PaddingRight={new UDim(0, 10)} />
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} VerticalAlignment={Enum.VerticalAlignment.Center} />
			<Button
				text={props.selectableCount > 0 ? `Select ${math.min(25, props.selectableCount)}` : "Nothing to pick"}
				icon="Check.19"
				onClick={props.selectVisible}
				color={Palette.violet}
				textColor={Palette.cream}
				size={new UDim2(0.42, -4, 1, 0)}
				reducedMotion={props.reducedMotion}
				disabled={props.selectableCount === 0}
				outline={true}
			/>
			<Button
				text={
					props.bulkBusy
						? "Salvaging"
						: picked && props.bulkArmed
							? `Tap again · salvage ${props.selectedCount}`
							: picked
								? `Salvage ${props.selectedCount}  +${compactNumber(props.selectionEssence)} essence`
								: "Clear"
				}
				icon="Dust.6"
				onClick={picked ? props.salvageSelected : props.clearSelection}
				color={picked ? Palette.coral : Palette.panelSoft}
				textColor={picked ? Palette.ink : Palette.muted}
				size={new UDim2(0.58, -4, 1, 0)}
				reducedMotion={props.reducedMotion}
				disabled={props.bulkBusy}
				highlight={picked}
			/>
		</frame>
	);
}

interface SheetProps {
	passOwned: boolean;
	rules: AutoSalvageRules;
	updateRules: (rules: AutoSalvageRules) => void;
	autoBusy: boolean;
	openShop?: () => void;
	runNow: () => void;
	reducedMotion?: boolean;
	stack: boolean;
	config: unknown;
	onClose: () => void;
}

/** Auto-salvage: owners pick rarities that turn into essence as they drop; others see the pass. */
export function AutoSalvageSheet(props: SheetProps) {
	const { passOwned, rules, autoBusy, reducedMotion, stack } = props;
	const sheetHostRef = React.useRef<Frame>();
	const fieldH = toolFieldH(stack);
	const rarityH = stack ? TapTarget : 36;
	React.useEffect(() => {
		GamepadNavigationService.BeginOverlayFocus();
		return () => GamepadNavigationService.EndOverlayFocus();
	}, []);
	React.useEffect(() => {
		const host = sheetHostRef.current;
		if (!UserInputService.GamepadEnabled || host === undefined) return undefined;
		const selectJob = task.defer(() => {
			if (host.Parent !== undefined) GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, selectJob);
		};
	}, [passOwned, autoBusy]);
	const update = (patch: Partial<AutoSalvageRules>) => props.updateRules({ ...rules, ...patch });
	const toggleRarity = (entry: string) => {
		const rarities = { ...(rules.Rarities ?? {}) };
		if (rarities[entry] === true) {
			delete rarities[entry];
		} else {
			rarities[entry] = true;
		}
		update({ Rarities: rarities });
	};
	const cols = stack ? 3 : 6;
	return (
		<frame {...named("AutoSalvageSheet")} ref={sheetHostRef} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={40} ClipsDescendants={false}>
			<frame
				{...named("AutoSalvageClaim")}
				Size={new UDim2(1, -8, 0, 0)}
				Position={UDim2.fromOffset(4, 6)}
				AutomaticSize={Enum.AutomaticSize.Y}
				BackgroundColor3={Palette.panelRaised}
				BorderSizePixel={0}
				ZIndex={41}
				ClipsDescendants={false}
			>
				<uicorner CornerRadius={new UDim(0, Radius.sheet)} />
				<uistroke ApplyStrokeMode={Enum.ApplyStrokeMode.Border} LineJoinMode={Enum.LineJoinMode.Round} Color={passOwned ? Palette.mango : Palette.lineSoft} Thickness={1} Transparency={0.4} />
				<uipadding PaddingTop={new UDim(0, 10)} PaddingBottom={new UDim(0, 10)} PaddingLeft={new UDim(0, 10)} PaddingRight={new UDim(0, 10)} />
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 8)} />
				<frame Size={new UDim2(1, 0, 0, 28)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={0}>
					<Text value="Auto-salvage" size={12} color={Palette.mango} weight={Enum.FontWeight.Heavy} sizeConstraint={new UDim2(1, -44, 1, 0)} />
					<frame Size={UDim2.fromOffset(28, 28)} Position={new UDim2(1, -28, 0, 0)} BackgroundTransparency={1} BorderSizePixel={0}>
						<Button text="" icon="Close.7" onClick={props.onClose} color={Palette.panelSoft} textColor={Palette.cream} outline={true} size={UDim2.fromScale(1, 1)} reducedMotion={reducedMotion} />
					</frame>
				</frame>
				{!passOwned ? (
					<>
						<Text
							value="Pick rarities once. Later crate drops of those rarities turn into essence."
							size={11}
							color={Palette.creamSoft}
							wrap={true}
							fit={true}
							minSize={10}
							layoutOrder={1}
							sizeConstraint={new UDim2(1, 0, 0, stack ? 32 : 18)}
						/>
						<Button
							text="View pass"
							icon="Shop.10"
							onClick={() => props.openShop?.()}
							color={Palette.mango}
							textColor={Palette.ink}
							size={stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(132, TapTarget)}
							reducedMotion={reducedMotion}
							highlight={true}
						/>
					</>
				) : (
					<>
						<frame Size={new UDim2(1, 0, 0, fieldH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1} ClipsDescendants={false}>
							<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
							<Button
								text={autoBusy ? "Saving" : rules.Enabled ? "ON" : "Off"}
								icon={rules.Enabled ? "Check.20" : "Inventory.6"}
								onClick={() => update({ Enabled: !rules.Enabled })}
								color={rules.Enabled ? Palette.mint : Palette.panelSoft}
								textColor={rules.Enabled ? Palette.ink : Palette.creamSoft}
								size={new UDim2(0.28, -6, 0, fieldH)}
								reducedMotion={reducedMotion}
								disabled={autoBusy}
								outline={!rules.Enabled}
							/>
							<Button
								text={rules.KeepNew ? "Keep new" : "Recycle new"}
								icon={rules.KeepNew ? "Lock.12" : "Dust.7"}
								onClick={() => update({ KeepNew: !rules.KeepNew })}
								color={rules.KeepNew ? Palette.violet : Palette.coral}
								textColor={rules.KeepNew ? Palette.cream : Palette.ink}
								size={new UDim2(0.44, -6, 0, fieldH)}
								reducedMotion={reducedMotion}
								disabled={autoBusy}
								outline={true}
							/>
							<Button
								text="Run"
								icon="Dust.8"
								onClick={props.runNow}
								color={Palette.mango}
								textColor={Palette.ink}
								size={new UDim2(0.28, -6, 0, fieldH)}
								reducedMotion={reducedMotion}
								disabled={autoBusy || !rules.Enabled}
								highlight={rules.Enabled}
							/>
						</frame>
						<frame Size={new UDim2(1, 0, 0, stack ? rarityH * 2 + 8 : rarityH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2} ClipsDescendants={false}>
							{AUTO_RARITIES.map((entry, index) => {
								const active = rules.Rarities?.[entry] === true;
								const col = index % cols;
								return (
									<Button
										key={entry}
										text={stack && entry === "Legendary" ? "Legend" : entry}
										onClick={() => toggleRarity(entry)}
										color={active ? RarityColor(props.config, entry, Palette.muted) : Palette.panelSoft}
										textColor={active ? Palette.ink : Palette.muted}
										position={new UDim2(col / cols, col === 0 ? 0 : 4, 0, math.floor(index / cols) * (rarityH + 8))}
										size={new UDim2(1 / cols, -6, 0, rarityH)}
										reducedMotion={reducedMotion}
										disabled={autoBusy}
										outline={!active}
									/>
								);
							})}
						</frame>
					</>
				)}
			</frame>
		</frame>
	);
}

interface RowProps {
	item: OwnedItem;
	config: unknown;
	selected: boolean;
	bulkSelected: boolean;
	bulkMode: boolean;
	onSelect: () => void;
	reducedMotion?: boolean;
	y?: number;
	layoutOrder?: number;
	stack?: boolean;
}

/** One relic: art, name, what it does, where it's socketed, rarity, level and stars, bulk state. */
export function RelicRow({ item, config, selected, bulkSelected, bulkMode, onSelect, reducedMotion, y, layoutOrder = 0, stack = false }: RowProps) {
	const definition = item.definition;
	const instance = item.instance;
	const accent = RarityColor(config, definition.Rarity, Palette.muted);
	// rarity polish: a faint rarity wash on the row and a rarity-tinted name (falls back to cream)
	const rarityTint = typeIs(accent, "Color3") ? accent : Palette.cream;
	const textW = stack ? -(58 + 8) : -176;
	const locked = instance.Locked === true;
	const stars = tonumber(instance.Stars) ?? 0;
	const equipped = item.equippedOn !== undefined;
	const tip = useTooltip({
		title: `${definition.Name ?? "Relic"} · ${definition.Rarity ?? "Common"}`,
		body: `${EffectLabel(definition, instance.Level, instance.Stars)} · ${definition.Slot ?? "Machine"} slot`,
		hint: equipped ? "Socketed now." : locked ? "Protected from salvage." : undefined,
		accent: rarityTint,
	});
	return (
		<imagebutton
			Size={new UDim2(1, 0, 0, RelicRowHeight(stack))}
			Position={y !== undefined ? UDim2.fromOffset(0, y) : undefined}
			LayoutOrder={layoutOrder}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			AutoButtonColor={false}
			Active={true}
			Selectable={true}
			Event={{
				Activated: () => {
					Audio.play("tick");
					onSelect();
				},
				MouseEnter: (rbx) => {
					tip.MouseEnter(rbx);
					Audio.play("hover");
				},
				SelectionGained: (rbx) => {
					tip.SelectionGained(rbx);
					Audio.play("hover");
				},
				MouseLeave: tip.MouseLeave,
				SelectionLost: tip.SelectionLost,
				InputBegan: tip.InputBegan,
				InputEnded: tip.InputEnded,
			}}
		>
			<Panel
				size={UDim2.fromScale(1, 1)}
				accent={bulkSelected ? Palette.coral : accent}
				background={(selected || bulkSelected ? Palette.panelRaised : Palette.panel).Lerp(rarityTint.Lerp(new Color3(0, 0, 0), 0.78), 0.18)}
				padding={stack ? Space.md : Space.lg}
				interactive={true}
				highlight={selected || bulkSelected}
				reducedMotion={reducedMotion}
				reveal={RELIC_ROW_SHOWN}
				clips={true}
			>
				<IconTile
					kind={itemIconKind(instance.DefinitionId ?? "", definition.Slot)}
					accent={accent}
					size={stack ? 44 : 46}
					radius={Radius.md}
					position={UDim2.fromOffset(0, stack ? 4 : 8)}
					reducedMotion={reducedMotion}
					glow={selected}
				/>
				<Text
					value={definition.Name}
					size={stack ? 15 : 16}
					color={Palette.cream.Lerp(rarityTint, 0.22)}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					minSize={12}
					position={UDim2.fromOffset(58, 0)}
					sizeConstraint={new UDim2(1, textW, 0, 22)}
				/>
				<Text
					value={`${definition.Description}  ·  ${EffectLabel(definition, instance.Level, instance.Stars)}`}
					size={11}
					color={accent}
					position={UDim2.fromOffset(58, 24)}
					sizeConstraint={new UDim2(1, textW, 0, 18)}
				/>
				<Text
					value={equipped ? `On ${SocketLabel(item.equippedOn)}` : locked ? "Protected" : ""}
					size={11}
					color={equipped ? Palette.mint : locked ? Palette.mango : Palette.creamSoft}
					fit={true}
					minSize={9}
					position={UDim2.fromOffset(58, 44)}
					sizeConstraint={new UDim2(1, textW, 0, 16)}
				/>
				<frame
					Size={stack ? new UDim2(1, -(58 + 8), 0, 22) : UDim2.fromOffset(84, 86)}
					Position={stack ? UDim2.fromOffset(58, 68) : new UDim2(1, -84, 0, 4)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
				>
					{stack ? (
						<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 6)} SortOrder={Enum.SortOrder.LayoutOrder} />
					) : (
						<uilistlayout
							FillDirection={Enum.FillDirection.Vertical}
							Padding={new UDim(0, 6)}
							HorizontalAlignment={Enum.HorizontalAlignment.Right}
							SortOrder={Enum.SortOrder.LayoutOrder}
						/>
					)}
					<Badge value={tostring(definition.Rarity ?? "Common")} accent={accent} filled={false} size={UDim2.fromOffset(stack ? 78 : 84, 20)} />
					<Badge
						value={stars > 0 ? `Lv ${instance.Level} ${string.rep("★", math.min(5, stars))}` : `Lv ${instance.Level}`}
						accent={Palette.mango}
						size={stack ? UDim2.fromOffset(stars > 0 ? 92 : 56, 20) : UDim2.fromOffset(84, 20)}
					/>
					{locked && !bulkMode && stack && <Badge value="LOCK" accent={Palette.mango} filled={true} size={UDim2.fromOffset(44, 20)} />}
					{bulkMode && (
						<Badge
							value={bulkSelected ? "ON" : locked ? "LOCK" : equipped ? "USED" : "PICK"}
							accent={bulkSelected ? Palette.coral : locked || equipped ? Palette.lineSoft : accent}
							filled={bulkSelected}
							size={UDim2.fromOffset(stack ? 52 : 84, 20)}
						/>
					)}
				</frame>
			</Panel>
		</imagebutton>
	);
}

// RelicRow shows: the relic (item, by value), config (slot/rarity labels), selected, bulk tick and
// mode, motion, y/layout order, stack layout. memoRow keeps onSelect pointing at the latest closure.
export const RelicRowMemo = memoRow<RowProps>(
	counted("InvRelic", RelicRow),
	["onSelect"],
	sameFields<RowProps>(["item", "config", "selected", "bulkSelected", "bulkMode", "reducedMotion", "y", "layoutOrder", "stack"]),
);

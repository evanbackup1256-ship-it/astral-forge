// The Inventory page: relics (search/filter/sort, inspect, engrave, bulk and auto salvage), crates,
// the market, recipe forging, and the loadout. The tab's pieces live in ./inventory/; this file owns
// the page state and wires them into one PageScaffold per tab.
import React from "@rbxts/react";
import {
	AutoSalvageRules,
	AutoSalvageSignature,
	ChipRows,
	CollectOwned,
	FilterOwned,
	InspectPanelHeight,
	InspectSocketBlock,
	OwnedItem,
	RelicRowHeight,
	RestockClock,
	SalvagePreview,
	SearchOwned,
	SocketTargets,
	SortOwned,
} from "../../CoreKit/inventoryMath";
import { compactNumber } from "../../CoreKit/format";
import { chromeFor, Layout, Palette, Space, TapTarget } from "../../CoreKit/theme";
import { useAntilag } from "../../MotionKit/antilag";
import { useStagger, useViewport, useWallClock } from "../../MotionKit/motion";
import { Badge, EmptyState, IconTile, Panel, SectionLabel, SegmentedTabs, ShimmerText, Text } from "../../UiCore/ui";
import { CompanionBondCard, companionBondHeight } from "../PagesCore/CompanionBondCard";
import { Component, loadAudio, loadBrowse, loadPageScaffold, luauKit } from "../luauDeps";
import { EngravingPanel, engravingPanelHeight } from "./EngravingPanel";
import { RecipeBench, recipeBenchHeight } from "./RecipeBench";
import { DetailPanel } from "./inventory/RelicDetail";
import {
	AutoSalvageSheet,
	BULK_DOCK_H,
	BulkDock,
	HERO_H,
	HERO_H_STACK,
	InventoryTools,
	inventoryToolsHeight,
	RelicRowMemo,
	ROW_GAP,
	SCROLL_PAD,
	TAB_OPTIONS,
	TABS,
} from "./inventory/RelicParts";
import { CRATE_CARD_H, CrateCardMemo, CrateDef, LoadoutBoard, loadoutBoardHeight, MARKET_BANNER_H, MARKET_CARD_H, MARKET_CARD_H_STACK, MarketBanner, MarketCardMemo, MarketOffer } from "./inventory/StoreParts";

const Audio = loadAudio();
const Browse = loadBrowse();
const PageScaffold = loadPageScaffold();
const FlatList = luauKit<{ FlatList: Component }>("LayoutKit", "virtualizedList").FlatList;

// the rarities auto-salvage can take (the server's list; Celestial and Astral are never auto-salvaged)
const AUTO_RARITIES = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"];
const DEFAULT_AUTO_RULES: AutoSalvageRules = { Enabled: false, KeepNew: true, Rarities: { Common: true, Uncommon: true } };
// bulk salvage takes at most this many relics per request
const BULK_LIMIT = 25;

interface ItemsState {
	Inventory?: Record<string, unknown>;
	Equipped?: Record<string, unknown>;
	Essence?: number;
	InventoryLimit?: number;
	Shop?: MarketOffer[];
	ShopRefreshAt?: number;
	AutoSalvage?: AutoSalvageRules;
	Keys?: Record<string, number | undefined>;
	Pity?: Record<string, number | undefined>;
	Effects?: unknown;
	EngravingPaused?: boolean;
}
interface Props {
	state: {
		Items?: ItemsState;
		Shop?: { OwnedPasses?: Record<string, boolean | undefined> };
		Machines?: unknown;
		Research?: unknown;
		Ore?: { Starsteel?: number };
		Cash?: unknown;
		Stardust?: number;
		Cores?: number;
	};
	config: {
		Items?: { Definitions?: unknown[]; Crates?: CrateDef[]; InventoryLimit?: number };
		ClientPageGuides?: { Inventory?: { EmptyItems?: string; EmptyMarket?: string } };
	};
	dispatch: (action: string, payload?: object, callback?: (response: { ok?: boolean; Rolls?: unknown[] }) => void) => unknown;
	reducedMotion?: boolean;
	crateRevealActive?: boolean;
	onCrateReveal: (reveal: { crateId: string; crateName: string; accent: Color3; rolls: unknown[] }) => void;
	openShop?: () => void;
}
interface Section {
	id: string;
	height?: number;
	fill?: boolean;
	minHeight?: number;
	element: React.Element;
}

const salvageable = (item: OwnedItem) => item.equippedOn === undefined && item.instance.Locked !== true;

function InventoryView(props: Props) {
	const { state, config, dispatch, crateRevealActive = false } = props;
	const softMotion = props.reducedMotion;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const antilag = useAntilag();
	const stack = chrome.contentStack;
	const headerReveal = useStagger(0, softMotion);
	const [tab, setTab] = React.useState("Relics");
	const [filter, setFilter] = React.useState("All");
	const [sort, setSort] = React.useState("Rarity");
	const [rarity, setRarity] = React.useState("Any");
	const [search, setSearch] = Browse.useLinkedQuery("Inventory");
	const [bulkMode, setBulkModeState] = React.useState(false);
	// uids picked for bulk salvage, in the order they were picked
	const [bulkSelected, setBulkSelected] = React.useState<string[]>([]);
	const [bulkBusy, setBulkBusy] = React.useState(false);
	// the bulk Salvage button asks for a second tap within 4 seconds
	const [bulkArmed, setBulkArmed] = React.useState(false);
	const [autoOpen, setAutoOpen] = React.useState(false);
	const [autoBusy, setAutoBusy] = React.useState(false);
	// auto-salvage rules being saved: shown until the server's copy matches
	const [autoDraft, setAutoDraft] = React.useState<AutoSalvageRules>();
	const [selectedUid, setSelectedUid] = React.useState<string>();
	const [crateBusy, setCrateBusy] = React.useState(false);
	const mountedRef = React.useRef(true);
	// bumped per crate request and on unmount, so a late reply for an older one is ignored
	const crateAttemptRef = React.useRef(0);
	React.useEffect(
		() => () => {
			mountedRef.current = false;
			crateAttemptRef.current += 1;
		},
		[],
	);
	const items = state.Items;
	const owned = React.useMemo(() => CollectOwned(state, config), [config.Items, items?.Equipped, items?.Inventory]);
	const filtered = React.useMemo(
		() => SortOwned(SearchOwned(FilterOwned(owned, filter), search, rarity, Browse.matches as never), config, sort),
		[config.Items, filter, owned, rarity, search, sort],
	);
	const selected = filtered.find((entry) => entry.uid === selectedUid) ?? filtered[0];
	const relicListRef = React.useRef<ScrollingFrame>();
	// list rows are boxed at their card's height; the stride is that plus the gap, so they can't drift
	const relicRowH = RelicRowHeight(stack);
	const relicRowStride = relicRowH + ROW_GAP;
	const rowBox = (size: UDim2, child: React.Element) => (
		<frame Size={size} BackgroundTransparency={1} BorderSizePixel={0}>
			{child}
		</frame>
	);
	// the shown relic is always one in the list
	React.useEffect(() => {
		if (selected !== undefined && selected.uid !== selectedUid) setSelectedUid(selected.uid);
		if (filtered.size() === 0) setSelectedUid(undefined);
	}, [filtered, selected, selectedUid]);
	// keep the selected row scrolled into view
	React.useEffect(() => {
		const frame = relicListRef.current;
		if (frame === undefined || selected === undefined || bulkMode || tab !== "Relics") return;
		const selectedIndex = math.max(0, filtered.findIndex((item) => item.uid === selected.uid));
		const top = SCROLL_PAD + selectedIndex * relicRowStride;
		const block = RelicRowHeight(stack);
		const view = frame.AbsoluteWindowSize.Y;
		if (view <= 1) return;
		const pos = frame.CanvasPosition.Y;
		if (top < pos + 8) {
			frame.CanvasPosition = new Vector2(0, math.max(0, top - 8));
		} else if (top + block > pos + view - 8) {
			frame.CanvasPosition = new Vector2(0, math.max(0, top + block - view + 8));
		}
	}, [bulkMode, filter, filtered.size(), rarity, relicRowStride, search, selected?.uid, sort, stack, tab]);
	// relics that left the bag drop out of the bulk pick
	React.useEffect(() => {
		const present = new Set<string>();
		for (const item of owned) present.add(item.uid);
		setBulkSelected((current) => current.filter((uid) => present.has(uid)));
	}, [items?.Inventory]);

	const filled = owned.size();
	const limit = items?.InventoryLimit ?? config.Items?.InventoryLimit ?? 100;
	const essence = items?.Essence ?? 0;
	const heroH = stack ? HERO_H_STACK : HERO_H;
	const pageGap = stack ? ROW_GAP : Layout.panelGap;
	const tabH = chrome.mobile ? 54 : 56;
	const targetsForSelected = React.useMemo(
		() => (selected !== undefined ? SocketTargets(state, config, selected.definition) : []),
		[config, selected?.uid, state.Machines, state.Research],
	);
	const chipRows = selected !== undefined && selected.equippedOn === undefined && targetsForSelected.size() > 0 ? ChipRows(targetsForSelected.size(), stack) : 0;
	const inspectPanelH =
		tab === "Relics" && selected !== undefined && !bulkMode
			? InspectPanelHeight(InspectSocketBlock(selected.equippedOn !== undefined, targetsForSelected.size(), chipRows, stack, TapTarget), stack)
			: 0;
	const crates = config.Items?.Crates ?? [];
	const shopOffers = items?.Shop ?? [];
	const marketNow = useWallClock(tab === "Market");
	const shopRefreshAt = items?.ShopRefreshAt ?? 0;
	const marketBannerH = stack ? 132 : MARKET_BANNER_H;
	const untilRestock = (timestamp: number) => math.max(0, shopRefreshAt - timestamp);
	const keysRefreshText = marketNow.map((t) => (untilRestock(t) > 0 ? `Keys refresh in ${RestockClock(untilRestock(t))}` : "Keys refreshing now…"));
	const refreshShort = marketNow.map((t) => (untilRestock(t) > 0 ? `Restock in ${RestockClock(untilRestock(t))}` : "Restocking…"));
	const selectedForBulk = React.useMemo(() => owned.filter((item) => bulkSelected.includes(item.uid) && salvageable(item)), [bulkSelected, owned]);
	const selectableVisible = React.useMemo(() => filtered.filter(salvageable), [filtered]);
	let selectionEssence = 0;
	for (const item of selectedForBulk) selectionEssence += SalvagePreview(config, item.definition, item.instance.Level);
	const passOwned = state.Shop?.OwnedPasses?.AutoSalvage === true;
	const serverAutoRules = items?.AutoSalvage ?? DEFAULT_AUTO_RULES;
	const autoRules = autoDraft ?? serverAutoRules;
	const serverAutoSignature = AutoSalvageSignature(serverAutoRules, AUTO_RARITIES);
	const draftAutoSignature = autoDraft !== undefined ? AutoSalvageSignature(autoDraft, AUTO_RARITIES) : undefined;
	React.useEffect(() => {
		if (draftAutoSignature !== undefined && draftAutoSignature === serverAutoSignature) setAutoDraft(undefined);
	}, [draftAutoSignature, serverAutoSignature]);
	React.useEffect(() => {
		if (!bulkArmed) return undefined;
		const lapse = task.delay(4, () => setBulkArmed(false));
		return () => {
			pcall(task.cancel, lapse);
		};
	}, [bulkArmed, selectedForBulk.size()]);

	const setBulkMode = (value: boolean) => {
		setBulkModeState(value);
		if (!value) setBulkSelected([]);
	};
	const toggleBulkItem = (item: OwnedItem) => {
		if (!salvageable(item)) {
			Audio.play("error");
			return;
		}
		setBulkSelected((current) => {
			if (current.includes(item.uid)) return current.filter((uid) => uid !== item.uid);
			if (current.size() >= BULK_LIMIT) return current;
			return [...current, item.uid];
		});
	};
	const selectVisible = () => {
		setBulkSelected(selectableVisible.filter((_, i) => i < BULK_LIMIT).map((item) => item.uid));
		Audio.play("filterPick");
	};
	/** Salvage these relics in one request; `done` runs on success. */
	const bulkSalvage = (uids: string[], done?: () => void) => {
		setBulkBusy(true);
		dispatch("BulkSalvageItems", { Uids: uids }, (response) => {
			if (!mountedRef.current) return;
			setBulkBusy(false);
			if (!response.ok) return;
			done?.();
			Audio.play("reward");
		});
	};
	const runAutoNow = () => {
		if (autoBusy || bulkBusy || !passOwned || !autoRules.Enabled) return;
		const uids = owned
			.filter((item) => salvageable(item) && autoRules.Rarities?.[item.definition.Rarity ?? ""] === true)
			.filter((_, i) => i < BULK_LIMIT)
			.map((item) => item.uid);
		if (uids.size() === 0) {
			Audio.play("error");
			return;
		}
		bulkSalvage(uids);
	};
	const salvageSelected = () => {
		if (selectedForBulk.size() === 0 || bulkBusy) return;
		// first press arms (the button asks again), the second within 4 seconds salvages
		if (!bulkArmed) {
			setBulkArmed(true);
			return;
		}
		setBulkArmed(false);
		bulkSalvage(
			selectedForBulk.map((item) => item.uid),
			() => setBulkSelected([]),
		);
	};
	const updateAutoRules = (updatedRules: AutoSalvageRules) => {
		if (autoBusy || !passOwned) return;
		let rules = updatedRules;
		let rarities = AUTO_RARITIES.filter((entry) => rules.Rarities?.[entry] === true);
		// turning it on with nothing picked starts from the two lowest rarities
		if (rules.Enabled && rarities.size() === 0) {
			rarities = ["Common", "Uncommon"];
			rules = { ...rules, Rarities: { ...(rules.Rarities ?? {}), Common: true, Uncommon: true } };
		}
		setAutoDraft(rules);
		setAutoBusy(true);
		dispatch("SetItemAutoSalvage", { Enabled: rules.Enabled, KeepNew: rules.KeepNew, Rarities: rarities }, (response) => {
			if (!mountedRef.current) return;
			setAutoBusy(false);
			if (!response.ok) {
				setAutoDraft(undefined);
			} else {
				Audio.play("filterPick");
			}
		});
	};
	const openCrate = (crate: CrateDef, count: number) => {
		if (crateBusy || crateRevealActive) return;
		crateAttemptRef.current += 1;
		const attempt = crateAttemptRef.current;
		setCrateBusy(true);
		dispatch("OpenItemCrate", { Id: crate.Id, Count: count }, (response) => {
			if (!mountedRef.current || crateAttemptRef.current !== attempt) return;
			setCrateBusy(false);
			const rolls = response.Rolls;
			if (!response.ok || rolls === undefined || rolls.size() === 0) return;
			props.onCrateReveal({ crateId: crate.Id, crateName: crate.Name, accent: crate.Color, rolls });
			setTab("Relics");
		});
	};
	const overscan = softMotion ? 0 : antilag.tier <= 1 || antilag.constrained ? 1 : 2;
	const guides = config.ClientPageGuides?.Inventory;

	const tabsBar = (
		<SegmentedTabs
			options={TAB_OPTIONS}
			value={tab}
			onChange={(entry: string) => {
				setTab(entry);
				if (entry !== "Relics") {
					setBulkMode(false);
					setAutoOpen(false);
				}
			}}
			accent={Palette.violet}
			columns={TABS.size()}
			gap={pageGap}
			size={new UDim2(1, 0, 0, tabH)}
			layoutOrder={1}
			reducedMotion={softMotion}
		/>
	);
	const heroTitle = tab === "Crates" ? "Open crates for new relics" : tab === "Market" ? "Crate keys and live stock" : tab === "Loadout" ? "What your sockets add" : `${filled} of ${limit} relics in your bag`;
	const heroPanel = (
		<Panel
			size={UDim2.fromScale(1, 1)}
			accent={Palette.violet}
			background={Palette.panelRaised}
			padding={stack ? Space.lg : Space.xl}
			layoutOrder={0}
			reveal={headerReveal}
			highlight={!softMotion}
			reducedMotion={softMotion}
			clips={false}
		>
			<IconTile kind="Loadout" accent={Palette.violet} size={stack ? 38 : 44} radius={10} position={UDim2.fromOffset(0, stack ? 4 : 6)} reducedMotion={softMotion} glow={true} />
			<Text value="Relics" size={12} color={Palette.violet} weight={Enum.FontWeight.Heavy} position={UDim2.fromOffset(stack ? 50 : 56, 2)} sizeConstraint={new UDim2(1, stack ? -58 : -20, 0, 16)} />
			<ShimmerText
				value={heroTitle}
				size={stack ? 18 : 22}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={false}
				position={UDim2.fromOffset(stack ? 50 : 56, 20)}
				sizeConstraint={new UDim2(1, stack ? -58 : -20, 0, 26)}
				enabled={!softMotion}
				periodSeconds={4.8}
			/>
			<frame
				Visible={tab !== "Relics"}
				Size={stack ? new UDim2(1, 0, 0, 28) : UDim2.fromOffset(220, 30)}
				Position={stack ? new UDim2(0, 0, 1, -28) : new UDim2(1, -220, 0.5, -15)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
			>
				<uilistlayout
					FillDirection={Enum.FillDirection.Horizontal}
					HorizontalAlignment={stack ? Enum.HorizontalAlignment.Left : Enum.HorizontalAlignment.Right}
					Padding={new UDim(0, 8)}
					SortOrder={Enum.SortOrder.LayoutOrder}
				/>
				<Badge value={`${filled} / ${limit}`} accent={Palette.violet} filled={true} size={UDim2.fromOffset(stack ? 108 : 118, 28)} />
				<Badge value={`${compactNumber(essence)} essence`} accent={Palette.mango} size={UDim2.fromOffset(stack ? 100 : 112, 28)} />
			</frame>
		</Panel>
	);
	const sections: Section[] = [
		{ id: "hero", height: heroH, element: heroPanel },
		{ id: "tabs", height: tabH, element: tabsBar },
	];
	const scaffold = (scrollBarColor: Color3, overlay?: React.Element) => (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
			<PageScaffold gap={pageGap} tailPad={stack ? 10 : 14} scrollBarColor={scrollBarColor} scrollBarThickness={4} sections={sections} />
			{overlay}
		</frame>
	);

	if (tab === "Relics") {
		sections.push({
			id: "tools",
			height: inventoryToolsHeight(stack),
			element: (
				<InventoryTools
					search={search}
					setSearch={setSearch}
					filter={filter}
					setFilter={setFilter}
					rarity={rarity}
					setRarity={setRarity}
					sort={sort}
					setSort={setSort}
					bulkMode={bulkMode}
					setBulkMode={setBulkMode}
					autoOpen={autoOpen}
					setAutoOpen={setAutoOpen}
					equipBest={() => dispatch("EquipBestItems")}
					reducedMotion={softMotion}
					stack={stack}
					filled={filled}
					limit={limit}
					essence={essence}
				/>
			),
		});
		const bondH = companionBondHeight(items as never, stack);
		if (bondH > 0) {
			sections.push({ id: "companion", height: bondH, element: <CompanionBondCard items={items as never} dispatch={dispatch as never} stack={stack} reducedMotion={softMotion === true} /> });
		}
		if (inspectPanelH > 0 && selected !== undefined) {
			sections.push({
				id: "inspect",
				height: inspectPanelH,
				element: <DetailPanel item={selected} state={state} config={config} dispatch={dispatch} reducedMotion={softMotion} layoutOrder={0} stack={stack} fill={true} />,
			});
			// the selected relic's engraving lines, right under its inspect panel
			sections.push({
				id: "engrave",
				height: engravingPanelHeight() + 28,
				element: (
					<Panel size={UDim2.fromScale(1, 1)} accent={Palette.mango} background={Palette.panelRaised} padding={14} reducedMotion={softMotion} clips={false}>
						<EngravingPanel
							uid={selected.uid}
							instance={selected.instance as never}
							definition={selected.definition as never}
							essence={tonumber(items?.Essence) ?? 0}
							starsteel={tonumber(state.Ore?.Starsteel) ?? 0}
							paused={items?.EngravingPaused === true}
							dispatch={dispatch as never}
							reducedMotion={softMotion === true}
						/>
					</Panel>
				),
			});
		}
		sections.push({
			id: "list",
			fill: true,
			minHeight: math.max(160, RelicRowHeight(stack) + 48),
			element: (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
					<SectionLabel value={bulkMode ? "Select relics" : "Relics"} color={bulkMode ? Palette.coral : Palette.violet} />
					<FlatList
						data={filtered}
						itemHeight={relicRowStride}
						headerHeight={SCROLL_PAD}
						overscan={overscan}
						canvasTail={SCROLL_PAD}
						frameRef={relicListRef}
						Size={new UDim2(1, 0, 1, -34)}
						Position={UDim2.fromOffset(0, 34)}
						scrollBarColor={Palette.violet}
						scrollBarThickness={4}
						scrollBarTransparency={0.22}
						keyExtractor={(item: OwnedItem) => item.uid}
						renderItem={({ item }: { item: OwnedItem }) =>
							rowBox(
								new UDim2(1, 0, 0, relicRowH),
							<RelicRowMemo
								item={item}
								config={config}
								selected={selected?.uid === item.uid}
								bulkSelected={bulkSelected.includes(item.uid)}
								bulkMode={bulkMode}
								onSelect={() => {
									Audio.play("tick");
									if (bulkMode) {
										toggleBulkItem(item);
									} else {
										setSelectedUid(item.uid);
									}
								}}
								reducedMotion={softMotion}
								layoutOrder={0}
								stack={stack}
							/>,
							)
						}
						ListEmptyComponent={
							<EmptyState
								icon="Loadout.4"
								title={owned.size() === 0 ? "No relics yet" : "Nothing matches"}
								body={owned.size() === 0 ? (guides?.EmptyItems ?? "Open crates or buy a starter coupler from the Market tab.") : "Clear the search or set the filters back to All relics."}
								accent={Palette.violet}
								layoutOrder={0}
							/>
						}
					/>
				</frame>
			),
		});
		if (bulkMode) {
			sections.push({
				id: "bulk",
				height: BULK_DOCK_H,
				element: (
					<BulkDock
						selectedCount={selectedForBulk.size()}
						selectableCount={selectableVisible.size()}
						selectionEssence={selectionEssence}
						selectVisible={selectVisible}
						clearSelection={() => setBulkSelected([])}
						salvageSelected={salvageSelected}
						bulkArmed={bulkArmed}
						bulkBusy={bulkBusy}
						reducedMotion={softMotion}
					/>
				),
			});
		}
		return scaffold(
			Palette.violet,
			autoOpen ? (
				<AutoSalvageSheet
					passOwned={passOwned}
					rules={autoRules}
					updateRules={updateAutoRules}
					autoBusy={autoBusy}
					openShop={props.openShop}
					runNow={runAutoNow}
					reducedMotion={softMotion}
					stack={stack}
					config={config}
					onClose={() => setAutoOpen(false)}
				/>
			) : undefined,
		);
	}

	if (tab === "Crates") {
		const crateCardH = CRATE_CARD_H(stack);
		const crateLabelH = 28;
		sections.push({
			id: "crates",
			fill: true,
			minHeight: math.max(160, crateLabelH + crateCardH + pageGap * 2),
			element: (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
					<FlatList
						data={crates}
						itemHeight={crateCardH + pageGap}
						headerHeight={crateLabelH + pageGap}
						overscan={overscan}
						canvasTail={SCROLL_PAD}
						Size={UDim2.fromScale(1, 1)}
						scrollBarColor={Palette.violet}
						scrollBarThickness={4}
						scrollBarTransparency={0.22}
						keyExtractor={(crate: CrateDef) => crate.Id}
						renderItem={({ item: crate }: { item: CrateDef }) =>
							rowBox(
								new UDim2(1, 0, 0, crateCardH),
							<CrateCardMemo
								crate={crate}
								keys={items?.Keys?.[crate.Id] ?? 0}
								pity={items?.Pity?.[crate.Id] ?? 0}
								onOpen={(count) => openCrate(crate, count)}
								busy={crateBusy}
								reducedMotion={softMotion}
								layoutOrder={0}
								stack={stack}
							/>,
							)
						}
						ListHeaderComponent={<SectionLabel value="Crates" color={Palette.violet} layoutOrder={0} />}
						ListEmptyComponent={
							<EmptyState
								icon="Crate.11"
								title="No crate channels"
								body="More crate channels open as you progress through the story and the Lab."
								accent={Palette.violet}
								layoutOrder={0}
								reducedMotion={softMotion}
							/>
						}
					/>
				</frame>
			),
		});
	} else if (tab === "Market") {
		const marketCardH = stack ? MARKET_CARD_H_STACK : MARKET_CARD_H;
		sections.push({
			id: "market",
			fill: true,
			minHeight: math.max(160, marketBannerH + marketCardH + pageGap * 2),
			element: (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
					<FlatList
						data={shopOffers}
						itemHeight={marketCardH + pageGap}
						headerHeight={marketBannerH + pageGap}
						overscan={overscan}
						canvasTail={SCROLL_PAD}
						Size={UDim2.fromScale(1, 1)}
						scrollBarColor={Palette.mango}
						scrollBarThickness={4}
						scrollBarTransparency={0.22}
						keyExtractor={(offer: MarketOffer) => offer.Id}
						renderItem={({ item: offer }: { item: MarketOffer }) =>
							rowBox(
								new UDim2(1, 0, 0, marketCardH),
							<MarketCardMemo
								offer={offer}
								dispatch={dispatch}
								reducedMotion={softMotion}
								layoutOrder={0}
								cash={state.Cash}
								stardust={state.Stardust ?? 0}
								cores={state.Cores ?? 0}
								refreshShort={refreshShort}
								stack={stack}
							/>,
							)
						}
						ListHeaderComponent={<MarketBanner refreshText={keysRefreshText} reducedMotion={softMotion} layoutOrder={0} stack={stack} />}
						ListEmptyComponent={
							<EmptyState
								icon="Shop.13"
								title="Market offline"
								body={guides?.EmptyMarket ?? "No dock offers right now. More arrive at the next restock."}
								accent={Palette.mango}
								layoutOrder={0}
								reducedMotion={softMotion}
							/>
						}
					/>
				</frame>
			),
		});
	} else if (tab === "Recipes") {
		// recipe forging: craft relics already in the codex
		const definitions = (config.Items?.Definitions ?? []) as never[];
		sections.push({
			id: "recipes",
			height: recipeBenchHeight(definitions, (items ?? {}) as never, stack),
			element: (
				<RecipeBench
					definitions={definitions}
					items={(items ?? {}) as never}
					ore={(state.Ore ?? {}) as never}
					stack={stack}
					dispatch={dispatch as never}
					reducedMotion={softMotion === true}
				/>
			),
		});
	} else {
		sections.push({ id: "loadout-label", height: 28, element: <SectionLabel value="Sockets" color={Palette.mint} layoutOrder={0} /> });
		sections.push({
			id: "loadout",
			height: loadoutBoardHeight(state as never, config as never, stack),
			element: <LoadoutBoard state={state as never} config={config as never} layoutOrder={0} stack={stack} />,
		});
	}
	return scaffold(tab === "Market" ? Palette.mango : Palette.violet);
}

export = { InventoryView };

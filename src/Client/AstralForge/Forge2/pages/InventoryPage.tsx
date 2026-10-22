// Relics, rebuilt on Forge2: filter + sort chips, a roomy list, and an inspect panel (side panel on
// desktop, a sheet on phones). Same remotes and payloads as before: EquipItem {Uid, Target},
// UnequipItem {Target}, UpgradeItem {Uid}, ToggleItemLock {Uid}, SalvageItem {Uid}, EquipBestItems.
import React from "@rbxts/react";
import { Audio } from "../../AudioKit/audio";
import { compactNumber } from "../../CoreKit/format";
import * as InventoryMath from "../../CoreKit/inventoryMath";
import { useListStagger } from "../../MotionKit/motion";
import { Button } from "../design/Button";
import { EmptyState, Modal } from "../design/Layers";
import { Card, Panel } from "../design/Panel";
import { Chip } from "../design/Pick";
import { Text, Title } from "../design/Text";
import { Fonts, gap, Iron, Type } from "../design/tokens";
import { Burst, MotionFX } from "../motion/motion";
import type { PageProps } from "../router/routes";

const FILTERS = ["All", "Equipped", "Starred", "Duplicates"];
const SORTS: ReadonlyArray<[string, string]> = [
	["Power", "Strongest"],
	["Newest", "Newest"],
	["Level", "Level"],
];
const PAGE_SIZE = 40;

function stars(item: InventoryMath.OwnedItem): string {
	const count = math.min(5, tonumber(item.instance.Stars) ?? 0);
	return count > 0 ? ` ${string.rep("★", count)}` : "";
}

function RelicRow(props: { item: InventoryMath.OwnedItem; index: number; selected: boolean; config: unknown; phone: boolean; onPick: () => void }) {
	const reveal = useListStagger(props.index);
	const item = props.item;
	const accent = InventoryMath.RarityColor(props.config, item.definition.Rarity, Iron.muted());
	const where = item.equippedOn !== undefined ? `On ${InventoryMath.SocketLabel(item.equippedOn)}` : item.instance.Locked === true ? "Locked" : "";
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.index}>
			<uiscale Scale={reveal.map((p) => 0.97 + p * 0.03)} />
			<Card accent={accent} selected={props.selected} pad={gap(props.phone, "m")} spacing={2} rarity={item.definition.Rarity} onPress={props.onPick}>
				<Text text={`${item.definition.Name ?? "Relic"}`} size={Type.body(props.phone)} font={Fonts.heavy} color={Iron.text().Lerp(accent, 0.25)} order={0} />
				<Text
					text={`Lv ${item.instance.Level}${stars(item)}  ·  ${InventoryMath.EffectLabel(item.definition, item.instance.Level, item.instance.Stars)}`}
					size={Type.small(props.phone)}
					color={accent}
					order={1}
				/>
				{where !== "" && <Text text={where} size={Type.small(props.phone)} color={item.equippedOn !== undefined ? Iron.brass() : Iron.ember()} order={2} />}
			</Card>
		</frame>
	);
}

function Inspect(props: PageProps & { item: InventoryMath.OwnedItem; onSalvage: () => void }) {
	const { item, request, phone } = props;
	const essence = ((props.session as unknown as { Items?: { Essence?: number } }).Items?.Essence ?? 0) as number;
	const cost = InventoryMath.UpgradeCost(item.definition, item.instance.Level);
	const [canUpgrade, maxed] = InventoryMath.UpgradeState(item.instance.Level, item.definition.MaxLevel, essence, cost);
	const targets = item.equippedOn === undefined ? InventoryMath.SocketTargets(props.session, props.config, item.definition) : [];
	const compare = targets.size() > 0 ? InventoryMath.CompareSocket(props.session, props.config, item.uid, item.definition, item.instance.Level, item.instance.Stars, targets[0].id) : undefined;
	const accent = InventoryMath.RarityColor(props.config, item.definition.Rarity, Iron.muted());
	const locked = item.instance.Locked === true;
	return (
		<Panel pad={gap(phone, "l")} spacing={gap(phone, "m")} seam rarity={item.definition.Rarity}>
			<Title text={item.definition.Name ?? "Relic"} size={Type.title(phone)} rarity={item.definition.Rarity} color={Iron.text().Lerp(accent, 0.2)} order={0} />
			<Text text={item.definition.Description ?? ""} size={Type.body(phone)} color={Iron.soft()} multiline order={1} />
			<Text text={InventoryMath.EffectLabel(item.definition, item.instance.Level, item.instance.Stars)} size={Type.body(phone)} font={Fonts.heavy} color={accent} order={2} />
			{compare !== undefined && <Text text={compare} size={Type.small(phone)} color={Iron.muted()} multiline order={3} />}
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={4}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{item.equippedOn !== undefined ? (
					<Button text="Take off" tone="iron" onPress={() => request("UnequipItem", { Target: item.equippedOn })} order={0} />
				) : (
					targets.map((target, i) => (
						<Button
							key={target.id}
							text={targets.size() > 1 ? `Equip · ${tostring(target.label)}` : "Equip"}
							width={targets.size() > 1 ? 180 : 140}
							onPress={() => request("EquipItem", { Uid: item.uid, Target: target.id }, (reply) => reply.ok === true && MotionFX.play("confirm"))}
							order={i}
						/>
					))
				)}
				<Button
					text={maxed ? "Max level" : `Upgrade · ${compactNumber(cost)}`}
					width={170}
					tone="iron"
					disabled={!canUpgrade}
					busy={props.busy.UpgradeItem === true}
					onPress={() =>
						request("UpgradeItem", { Uid: item.uid }, (reply) => {
							if (reply.ok === true) {
								Burst.spark(accent, 1);
								MotionFX.play("success");
							}
						})
					}
					order={50}
				/>
			</frame>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={5}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<Button text={locked ? "Unlock" : "Lock"} tone="quiet" width={110} onPress={() => request("ToggleItemLock", { Uid: item.uid })} order={0} />
				{!locked && item.equippedOn === undefined && (
					<Button text={`Salvage · ${compactNumber(InventoryMath.SalvagePreview(props.config, item.definition, item.instance.Level))}`} tone="quiet" width={170} onPress={props.onSalvage} order={1} />
				)}
			</frame>
		</Panel>
	);
}

export function InventoryPage(props: PageProps) {
	const phone = props.phone;
	const [filter, setFilter] = React.useState("All");
	const [sort, setSort] = React.useState("Power");
	const [selectedUid, setSelected] = React.useState<string>();
	const [shown, setShown] = React.useState(PAGE_SIZE);
	const [salvaging, setSalvaging] = React.useState(false);
	const owned = React.useMemo(() => InventoryMath.CollectOwned(props.session, props.config), [props.session, props.config]);
	const list = React.useMemo(() => InventoryMath.SortOwned(InventoryMath.FilterOwned(owned, filter), props.config, sort), [owned, filter, sort, props.config]);
	const selected = owned.find((item) => item.uid === selectedUid);
	const visible = list.filter((_, i) => i < shown);
	const space = gap(phone, "l");
	const sideBySide = !phone && !props.chrome.contentStack;
	const salvage = () => {
		if (selected === undefined) return;
		const uid = selected.uid;
		setSalvaging(false);
		setSelected(undefined);
		Audio.play("vaultBank");
		props.request("SalvageItem", { Uid: uid });
	};

	const listColumn = (
		<scrollingframe
			Size={sideBySide ? new UDim2(0.56, -space / 2, 1, 0) : UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			CanvasSize={new UDim2()}
			AutomaticCanvasSize={Enum.AutomaticSize.Y}
			ScrollBarThickness={phone ? 0 : 4}
			ScrollBarImageColor3={Iron.brassDeep()}
		>
			<uipadding PaddingTop={new UDim(0, space)} PaddingBottom={new UDim(0, space * 2)} PaddingLeft={new UDim(0, space)} PaddingRight={new UDim(0, sideBySide ? 4 : space)} />
			<uilistlayout Padding={new UDim(0, gap(phone, "m"))} SortOrder={Enum.SortOrder.LayoutOrder} />
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} VerticalAlignment={Enum.VerticalAlignment.Center} />
				<Title text="Relics" size={Type.title(phone)} order={0} />
				{FILTERS.map((id, i) => (
					<Chip key={id} text={id} on={filter === id} onPress={() => setFilter(id)} order={i + 1} />
				))}
			</frame>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{SORTS.map(([id, label], i) => (
					<Chip key={id} text={label} on={sort === id} onPress={() => setSort(id)} color={Iron.steel()} order={i} />
				))}
				<Button text="Equip best" tone="iron" width={140} busy={props.busy.EquipBestItems === true} onPress={() => props.request("EquipBestItems", {}, (r) => r.ok === true && MotionFX.play("confirm"))} order={10} />
			</frame>
			{list.size() === 0 ? (
				<EmptyState
					title={owned.size() === 0 ? "No relics yet" : "Nothing here"}
					body={owned.size() === 0 ? "Open a crate in the Shop to find your first one." : undefined}
					action={owned.size() === 0 ? { text: "Go to Shop", onPress: () => props.navigate("Shop") } : undefined}
					phone={phone}
					order={2}
				/>
			) : (
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2}>
					<uilistlayout Padding={new UDim(0, gap(phone, "s"))} SortOrder={Enum.SortOrder.LayoutOrder} />
					{visible.map((item, i) => (
						<RelicRow key={item.uid} item={item} index={i} selected={item.uid === selectedUid} config={props.config} phone={phone} onPick={() => setSelected(item.uid)} />
					))}
				</frame>
			)}
			{list.size() > shown && <Button text={`Show ${math.min(PAGE_SIZE, list.size() - shown)} more`} tone="quiet" stretch onPress={() => setShown((n) => n + PAGE_SIZE)} order={3} />}
		</scrollingframe>
	);

	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
			{listColumn}
			{sideBySide && (
				<scrollingframe
					Size={new UDim2(0.44, -space / 2, 1, 0)}
					Position={new UDim2(0.56, space / 2, 0, 0)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					CanvasSize={new UDim2()}
					AutomaticCanvasSize={Enum.AutomaticSize.Y}
					ScrollBarThickness={0}
				>
					<uipadding PaddingTop={new UDim(0, space)} PaddingRight={new UDim(0, space)} PaddingBottom={new UDim(0, space)} />
					{selected !== undefined ? (
						<Inspect {...props} item={selected} onSalvage={() => setSalvaging(true)} />
					) : (
						<EmptyState title="Pick a relic" body="Its details and actions show up here." phone={phone} />
					)}
				</scrollingframe>
			)}
			{!sideBySide && (
				<Modal open={selected !== undefined && !salvaging} title="Relic" onClose={() => setSelected(undefined)} phone={phone}>
					{selected !== undefined && <Inspect {...props} item={selected} onSalvage={() => setSalvaging(true)} />}
				</Modal>
			)}
			<Modal open={salvaging && selected !== undefined} title="Salvage this relic?" onClose={() => setSalvaging(false)} phone={phone}>
				<Text text="It turns into essence. This can't be undone." size={Type.body(phone)} color={Iron.soft()} multiline order={0} />
				<Button text="Salvage" tone="ember" stretch onPress={salvage} order={1} />
			</Modal>
		</frame>
	);
}

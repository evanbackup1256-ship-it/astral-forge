// Workshop, rebuilt on Forge2: what the next machine needs, the buy amount, one batch button, a
// filtered grid of machine cards, and Auto-Forge. Same remotes and payloads as before:
// BuyMachine {Id, Amount} (via the shared purchase planner) and SetAutoForge {Enabled, MachineId, Reserve}.
import React from "@rbxts/react";
import { Audio } from "../../AudioKit/audio";
import { AppHelpers, NavState, UpgradeConfig, UpgradeEntry } from "../../CoreKit/appNav";
import { bulkCost, compactNumber, compareFlux, Flux, gteFlux } from "../../CoreKit/format";
import { useChangePop, useClock, useStagger } from "../../MotionKit/motion";
import { Button } from "../design/Button";
import { FilterChipRow } from "../design/FilterChipRow";
import { EmptyState, Tooltip } from "../design/Layers";
import { Panel } from "../design/Panel";
import { Text, Title } from "../design/Text";
import { Fonts, gap, Iron, Type } from "../design/tokens";
import { MotionFX } from "../motion/motion";
import type { PageProps } from "../router/routes";
import { AmountPicker, cellWidth, columnsFor, Grid, ModelEntries, ModelEntry, PageScroll, Row, SearchBox, Tools, UpgradeCard, useFocusClaim, useWidth, matches } from "./upgradeParts";

interface MachineConfig extends UpgradeConfig {
	Accent?: Color3;
	Color?: Color3;
	Description?: string;
	BaseProduction?: number;
}

interface WorkshopSession {
	Cash?: Flux;
	Production?: unknown;
	Machines: Record<string, number>;
	Zone: number;
	Rebirths: number;
	AutoForge?: { Enabled?: boolean; MachineId?: string; Reserve?: number };
}

type Entry = UpgradeEntry<MachineConfig>;

const SORTS: ReadonlyArray<[string, string]> = [
	["Default", "Tier order"],
	["Return", "Best level return"],
	["Cheapest", "Cheapest first"],
	["Output", "Biggest level gain"],
	["Level", "Highest level"],
];

const RESERVES: ReadonlyArray<[string, string]> = [
	["NONE", "No reserve"],
	["SAFE", "Keep 25%"],
	["HALF", "Keep 50%"],
	["HIGH", "Keep 75%"],
];

function locked(s: WorkshopSession, machine: MachineConfig): boolean {
	return (
		s.Zone < (machine.RequiredZone ?? 1) ||
		s.Rebirths < (machine.RequiredRebirths ?? 0) ||
		(machine.PreviousId !== undefined && (s.Machines[machine.PreviousId] ?? 0) < (machine.PreviousLevel ?? 1))
	);
}

/** The next step in the machine chain, in plain words. */
function nextStep(s: WorkshopSession, machines: MachineConfig[]): string | undefined {
	const names: Record<string, string> = {};
	for (const machine of machines) names[machine.Id] = machine.Name;
	for (const machine of machines) {
		if (machine.PreviousId === undefined) continue;
		const rate = machine.BaseProduction ?? 0;
		const earns = rate > 0 ? ` (+${compactNumber(rate)}/sec)` : "";
		const needRebirths = machine.RequiredRebirths ?? 0;
		const needZone = machine.RequiredZone ?? 1;
		const needLevel = machine.PreviousLevel ?? 1;
		const haveLevel = s.Machines[machine.PreviousId] ?? 0;
		if (s.Rebirths < needRebirths) return `${machine.Name}${earns} after ${needRebirths} rebirth${needRebirths === 1 ? "" : "s"} · you have ${s.Rebirths}`;
		if (s.Zone < needZone) return `${machine.Name}${earns} opens on world ${needZone}`;
		if (haveLevel < needLevel) return `${machine.Name}${earns} · get ${names[machine.PreviousId] ?? machine.PreviousId} to ${needLevel} (now ${haveLevel})`;
	}
	return undefined;
}

function AutoForge(props: { s: WorkshopSession; machines: MachineConfig[]; request: PageProps["request"]; phone: boolean; busy: boolean }) {
	const { s, machines, phone } = props;
	const queue = {
		Enabled: s.AutoForge?.Enabled === true,
		MachineId: s.AutoForge?.MachineId ?? machines[0]?.Id ?? "StellarCore",
		Reserve: s.AutoForge?.Reserve ?? 0.25,
	};
	const target = machines.find((m) => m.Id === queue.MachineId) ?? machines[0];
	// same pick list as before: current target, owned machines newest first, then open ones
	const options: MachineConfig[] = [];
	const seen = new Set<string>();
	const push = (m: MachineConfig) => {
		if (seen.has(m.Id)) return;
		seen.add(m.Id);
		options.push(m);
	};
	if (target !== undefined) push(target);
	for (let i = machines.size() - 1; i >= 0 && options.size() < 24; i--) {
		if ((s.Machines[machines[i].Id] ?? 0) > 0) push(machines[i]);
	}
	for (const m of machines) {
		if (options.size() >= 40) break;
		if (!locked(s, m)) push(m);
	}
	const level = target !== undefined ? (s.Machines[target.Id] ?? 0) : 0;
	const nextCost: Flux = target !== undefined && level < target.MaxLevel ? bulkCost(target.BaseCost, target.CostScale, level, 1, target.MaxLevel) : 0;
	const targetLocked = target !== undefined && locked(s, target);
	const done = target === undefined || level >= target.MaxLevel;
	const waiting = !targetLocked && !done && !gteFlux(s.Cash ?? 0, nextCost);
	const status = !queue.Enabled
		? "Paused"
		: done
			? "Target complete"
			: targetLocked
				? "Waiting for unlock"
				: waiting
					? `Waiting for ${compactNumber(nextCost)} Flux`
					: "Buying the next level";
	const statusPop = useChangePop(status);
	const spin = useClock(queue.Enabled, 40, 360, false);
	const apply = (enabled: boolean, machineId?: string, reserve?: number) => {
		Audio.play(enabled ? "tick" : "tabSwitch");
		if (enabled && !queue.Enabled) MotionFX.play("confirm");
		props.request("SetAutoForge", { Enabled: enabled, MachineId: machineId ?? queue.MachineId, Reserve: reserve ?? queue.Reserve });
	};
	return (
		<Panel pad={gap(phone, "l")} spacing={gap(phone, "m")} order={5} seam={queue.Enabled} rarity="Legendary">
			<Row order={0} spacing={12}>
				<frame Size={UDim2.fromOffset(28, 28)} BackgroundColor3={queue.Enabled ? Iron.brass() : Iron.steel()} BorderSizePixel={0} Rotation={spin} LayoutOrder={0}>
					<uicorner CornerRadius={new UDim(0, 6)} />
				</frame>
				<frame Size={new UDim2(1, -40, 0, Type.title(phone) + 10)} BackgroundTransparency={1} LayoutOrder={1}>
					<Title text="Auto-Forge" size={Type.title(phone)} tags={queue.Enabled ? ["wave"] : undefined} />
				</frame>
			</Row>
			<frame Size={new UDim2(1, 0, 0, Type.body(phone) + 6)} BackgroundTransparency={1} LayoutOrder={1}>
				<uiscale Scale={statusPop} />
				<Text text={target !== undefined ? `${target.Name} · ${status}` : status} size={Type.body(phone)} color={queue.Enabled ? Iron.brass() : Iron.soft()} box={UDim2.fromScale(1, 1)} />
			</frame>
			<FilterChipRow options={options.map((m) => ({ id: m.Id, label: m.Name }))} value={queue.MachineId} onChange={(id) => apply(queue.Enabled, id, queue.Reserve)} order={2} />
			<FilterChipRow
				options={RESERVES.map(([id, label]) => ({ id, label }))}
				value={AppHelpers.reserveId(queue.Reserve)}
				onChange={(id) => apply(queue.Enabled, queue.MachineId, AppHelpers.reserveValue(id))}
				accent={Iron.steel()}
				order={3}
			/>
			<Tooltip tip="Buys one level at a time and never spends your reserve." size={UDim2.fromOffset(phone ? 160 : 200, 44)} order={4}>
			<Button
				text={queue.Enabled ? "Pause queue" : "Start queue"}
				tone={queue.Enabled ? "iron" : "brass"}
				onPress={() => apply(!queue.Enabled)}
				busy={props.busy}
				stretch
			/>
			</Tooltip>
		</Panel>
	);
}

export function WorkshopPage(props: PageProps) {
	const s = props.session as unknown as WorkshopSession;
	const phone = props.phone;
	const machines = (typeIs(props.config.Machines, "table") ? props.config.Machines : []) as MachineConfig[];
	const [amount, setAmount] = React.useState(1);
	const [query, setQuery] = React.useState("");
	const [filter, setFilter] = React.useState("All");
	const [sort, setSort] = React.useState("Default");
	const [hostRef, width] = useWidth();
	const heroIn = useStagger(0);
	const entries = React.useMemo(
		() => AppHelpers.buildUpgradeEntries(machines, s.Machines ?? {}, s as unknown as NavState),
		[machines, s.Machines, s.Zone, s.Rebirths],
	) as Entry[];
	const cash = s.Cash ?? 0;
	const canBuy = (entry: Entry) => Tools.Model.quote(entry as unknown as ModelEntry, amount, cash).ready;
	const near = AppHelpers.trimFarLockedUpgrades(entries) as Entry[];
	const counts: Record<string, number> = { All: near.size(), Affordable: 0, Owned: 0, Next: 0 };
	for (const entry of entries) {
		if (canBuy(entry)) counts.Affordable += 1;
		if (entry.level > 0) counts.Owned += 1;
	}
	for (const entry of near) if (!entry.unlocked) counts.Next += 1;
	const needle = (query.match("^%s*(.-)%s*$")[0] as string).lower();
	const visible: Entry[] = [];
	for (const entry of needle !== "" ? entries : near) {
		if (filter === "Affordable" && !canBuy(entry)) continue;
		if (filter === "Owned" && entry.level <= 0) continue;
		if (filter === "Next" && entry.unlocked) continue;
		if (needle !== "" && !matches(needle, entry.config.Name, entry.config.Description)) continue;
		visible.push(entry);
	}
	visible.sort((left, right) => {
		if (sort === "Return") {
			const lr = canBuy(left) ? 0 : left.unlocked && !left.maxed ? 1 : 2;
			const rr = canBuy(right) ? 0 : right.unlocked && !right.maxed ? 1 : 2;
			if (lr !== rr) return lr < rr;
			const a = Tools.Model.returnScore(left as unknown as ModelEntry);
			const b = Tools.Model.returnScore(right as unknown as ModelEntry);
			if (a !== b) return a > b;
		} else if (sort === "Cheapest") {
			const c = compareFlux(
				Tools.Model.quote(left as unknown as ModelEntry, amount, cash).cost as Flux,
				Tools.Model.quote(right as unknown as ModelEntry, amount, cash).cost as Flux,
			);
			if (c !== 0) return c < 0;
		} else if (sort === "Output") {
			const a = Tools.Model.gainScore(left as unknown as ModelEntry);
			const b = Tools.Model.gainScore(right as unknown as ModelEntry);
			if (a !== b) return a > b;
		} else if (sort === "Level" && left.level !== right.level) {
			return left.level > right.level;
		}
		return left.order < right.order;
	});
	const batch = Tools.useBatch(props.request as never, "BuyMachine", visible as unknown as ModelEntries, amount, cash);
	const first = (s.Machines?.StellarCore ?? 0) < 1;
	let owned = 0;
	for (const m of machines) if ((s.Machines?.[m.Id] ?? 0) > 0) owned += 1;
	const step = first ? undefined : nextStep(s, machines);
	const space = gap(phone, "l");
	const columns = columnsFor(phone, width);
	const buyBatch = () => {
		if (batch.start()) {
			Audio.play("purchase");
			MotionFX.play("success");
		}
	};
	const claimRef = useFocusClaim(batch.count > 0 && !batch.busy, [amount, entries.size()]);
	const rate = compactNumber(s.Production ?? 0);
	const ratePop = useChangePop(rate);
	return (
		<PageScroll phone={phone}>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0} Position={heroIn.map((p) => UDim2.fromOffset(0, (1 - p) * 16))}>
				<Panel pad={gap(phone, "xl")} spacing={gap(phone, "m")} seam={counts.Affordable > 0}>
					<Title text={first ? "Buy a machine" : "Workshop"} size={Type.title(phone)} tags={["wave"]} order={0} />
					<frame Size={new UDim2(1, 0, 0, Type.hero(phone) * 0.8 + 6)} BackgroundTransparency={1} LayoutOrder={1}>
						<uiscale Scale={ratePop} />
						<Text text={`${rate}/sec`} size={math.floor(Type.hero(phone) * 0.8)} font={Fonts.heavy} color={Iron.brass()} box={UDim2.fromScale(1, 1)} />
					</frame>
					<Text
						text={first ? "A machine earns Flux into your vault every second." : (step ?? `${owned} machine${owned === 1 ? "" : "s"} running · more machines = more Flux, even while you're AFK.`)}
						size={Type.body(phone)}
						color={Iron.soft()}
						multiline
						order={2}
					/>
					<AmountPicker value={amount} onChange={setAmount} order={3} />
					<frame ref={claimRef} Size={UDim2.fromOffset(phone ? 180 : 220, phone ? 52 : 56)} BackgroundTransparency={1} LayoutOrder={4}>
					<Button
						text={batch.busy ? batch.status : batch.count > 0 ? `Buy ${batch.count}` : "Nothing to buy"}
						onPress={buyBatch}
						disabled={batch.count <= 0 || batch.busy}
						stretch
						height={phone ? 52 : 56}
						textSize={19}
					/>
					</frame>
				</Panel>
			</frame>

			<FilterChipRow
				options={[
					{ id: "All", label: "Near unlocks" },
					{ id: "Affordable", label: "Can afford" },
					{ id: "Owned", label: "Owned" },
					{ id: "Next", label: "Coming up" },
				]}
				value={filter}
				onChange={(id) => {
					Audio.play("tabSwitch");
					setFilter(id);
				}}
				counts={counts}
				order={1}
			/>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2}>
				<uilistlayout Padding={new UDim(0, gap(phone, "s"))} SortOrder={Enum.SortOrder.LayoutOrder} />
				<SearchBox value={query} onChange={setQuery} hint="Search upgrades" phone={phone} order={0} />
				<FilterChipRow options={SORTS.map(([id, label]) => ({ id, label }))} value={sort} onChange={setSort} accent={Iron.steel()} order={1} />
			</frame>

			<Grid order={3} spacing={space} hostRef={hostRef}>
				{visible.map((entry, index) => (
					<UpgradeCard
						key={entry.config.Id}
						entry={entry}
						index={index}
						amount={amount}
						cash={cash}
						phone={phone}
						effect={(entry.config.BaseProduction ?? 0) > 0 ? `+${compactNumber(entry.config.BaseProduction)} Flux/sec per level` : (entry.config.Description ?? "")}
						accent={entry.config.Accent ?? entry.config.Color ?? Iron.brass()}
						onBuy={(id) => batch.buy(id)}
						busy={batch.busy}
						width={cellWidth(columns, space)}
					/>
				))}
			</Grid>
			{visible.size() === 0 && (
				<EmptyState
					title={needle !== "" ? "Nothing matches" : filter === "Affordable" ? "Can't afford a machine yet" : entries.size() === 0 ? "No machines to show" : "Nothing to buy"}
					body={
						needle !== ""
							? "Clear the search to see the machines again."
							: filter === "Affordable"
								? "Collect your vault or pick a smaller amount."
								: first
									? "Buy a machine to start earning Flux into your vault."
									: "Switch the filter back to Near unlocks."
					}
					action={{ text: filter === "Next" ? "Show next machines" : "Show all", onPress: () => { setFilter(filter === "Next" ? "Next" : "All"); setQuery(""); } }}
					phone={phone}
					order={4}
				/>
			)}

			{!first && <AutoForge s={s} machines={machines} request={props.request} phone={phone} busy={props.busy.SetAutoForge === true} />}
		</PageScroll>
	);
}

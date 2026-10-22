// Boosts, rebuilt on Forge2: the running boost as a ticking reactor gauge (or the best stored one,
// ready to fire), a few totals, then every boost as a card. Same remote and payloads as before:
// ActivateBoost {Id} for a stored charge, ActivateBoost {Id, Buy = true} to run one for Stardust.
import React from "@rbxts/react";
import { Audio } from "../../AudioKit/audio";
import { clockText, compactNumber, Flux } from "../../CoreKit/format";
import { useClock, useFlash, useStagger, useWallClock } from "../../MotionKit/motion";
import { Button } from "../design/Button";
import { FilterChipRow } from "../design/FilterChipRow";
import { EmptyState, Tooltip } from "../design/Layers";
import { Card, Panel } from "../design/Panel";
import { Text, Title } from "../design/Text";
import { Corner, Fonts, gap, Iron, Type } from "../design/tokens";
import { Burst, MotionFX } from "../motion/motion";
import type { PageProps } from "../router/routes";
import { cellWidth, Grid, PageScroll, Row, useFocusClaim, useWidth } from "./upgradeParts";

const Workspace = game.GetService("Workspace");
const TICKS = 36;

interface BoostDef {
	Id: string;
	Name: string;
	Color?: Color3;
	Multiplier?: Flux;
	CapacityMultiplier?: Flux;
	Duration?: number;
	Description?: string;
}

interface BoostsSession {
	BoostInventory?: Record<string, unknown>;
	ActiveBoost?: { Id?: string; EndsAt?: unknown };
	Rebirths?: number;
	Stardust?: number;
}

interface BoostsConfig {
	Boosts?: Record<string, BoostDef>;
	Economy?: { Rebirth?: { StardustBoostPrices?: Record<string, number>; StardustBoostPerRebirth?: number } };
}

const FILTERS = [
	{ id: "All", label: "All" },
	{ id: "Owned", label: "Owned" },
	{ id: "Production", label: "Production" },
	{ id: "Vault", label: "Vault" },
];

const SORTS: ReadonlyArray<[string, string]> = [
	["Recommended", "Owned first"],
	["Strongest", "Strongest"],
	["Longest", "Longest"],
	["Name", "A to Z"],
];

function headline(boost: BoostDef): [string, string] {
	const production = tonumber(boost.Multiplier);
	const vault = tonumber(boost.CapacityMultiplier);
	if (production !== undefined && vault !== undefined) return [`${production}x`, `production · ${vault}x vault`];
	if (production !== undefined) return [`${production}x`, "production"];
	if (vault !== undefined) return [`${vault}x`, "vault"];
	return ["+", "special"];
}

/** extra production-minutes a boost adds (vault boosts count at a third), same as before */
function worth(boost: BoostDef): number {
	const production = (tonumber(boost.Multiplier) ?? 1) - 1;
	const vault = ((tonumber(boost.CapacityMultiplier) ?? 1) - 1) / 3;
	return (production + vault) * (tonumber(boost.Duration) ?? 0);
}

/** mirrors GameService.stardustBoostPrice: base x (1 + rebirths x PerRebirth), or undefined when not sold */
function stardustPrice(config: BoostsConfig, id: string, rebirths: number): number | undefined {
	const rebirth = config.Economy?.Rebirth;
	const base = rebirth?.StardustBoostPrices?.[id];
	if (!typeIs(base, "number") || base <= 0) return undefined;
	const per = tonumber(rebirth?.StardustBoostPerRebirth) ?? 0;
	return math.floor(base * (1 + math.max(0, rebirths) * per));
}

/** 36 ticks round a dial; lit ticks show the time left, the rim's gradient keeps turning. */
function Gauge(props: { fraction: React.Binding<number>; accent: Color3; size: number; children?: React.ReactNode }) {
	const spin = useClock(true, 40, 360, false);
	const size = props.size;
	const ticks: React.Element[] = [];
	for (let index = 0; index < TICKS; index++) {
		const threshold = index / TICKS;
		ticks.push(
			<frame key={index} Size={UDim2.fromScale(1, 1)} Position={UDim2.fromScale(0.5, 0.5)} AnchorPoint={new Vector2(0.5, 0.5)} Rotation={index * (360 / TICKS)} BackgroundTransparency={1} ZIndex={3}>
				<frame
					Size={UDim2.fromOffset(4, math.max(8, math.floor(size * 0.09)))}
					Position={UDim2.fromScale(0.5, 0)}
					AnchorPoint={new Vector2(0.5, 0)}
					BackgroundColor3={props.accent}
					BackgroundTransparency={props.fraction.map((f) => (threshold < f ? 0.05 : 0.82))}
					BorderSizePixel={0}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</frame>
			</frame>,
		);
	}
	return (
		<frame Size={UDim2.fromOffset(size, size)} BackgroundTransparency={1} LayoutOrder={0}>
			<frame Size={UDim2.fromScale(0.78, 0.78)} Position={UDim2.fromScale(0.5, 0.5)} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundColor3={Iron.sunk()} BorderSizePixel={0} ZIndex={2}>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke Color={props.accent} Thickness={2} Transparency={0.35}>
					<uigradient Color={new ColorSequence(new Color3(1, 1, 1), props.accent)} Rotation={spin} />
				</uistroke>
			</frame>
			{ticks}
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ZIndex={6}>
				{props.children}
			</frame>
		</frame>
	);
}

function Running(props: { boost: BoostDef; endsAt: number; phone: boolean }) {
	const now = useWallClock(true);
	const accent = props.boost.Color ?? Iron.ember();
	const [big, small] = headline(props.boost);
	const size = props.phone ? 132 : 160;
	const fraction = now.map((t) => math.clamp((props.endsAt - t) / math.max(1, props.boost.Duration ?? 1), 0, 1));
	return (
		<Panel pad={gap(props.phone, "xl")} spacing={gap(props.phone, "l")} seam rarity="Mythic" layout={props.phone ? "column" : "row"} order={0}>
			<Gauge fraction={fraction} accent={accent} size={size}>
				<Text text={big} size={math.floor(size * 0.22)} font={Fonts.heavy} align="Center" box={new UDim2(1, 0, 0, math.floor(size * 0.24))} position={new UDim2(0, 0, 0.5, -math.floor(size * 0.17))} />
				<textlabel
					Size={new UDim2(1, 0, 0, 18)}
					Position={new UDim2(0, 0, 0.5, math.floor(size * 0.08))}
					BackgroundTransparency={1}
					Text={now.map((t) => clockText(math.max(0, props.endsAt - t)))}
					FontFace={Fonts.heavy}
					TextSize={15}
					TextColor3={accent}
				/>
			</Gauge>
			<frame Size={new UDim2(1, props.phone ? 0 : -size - gap(props.phone, "l"), 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
				<uilistlayout Padding={new UDim(0, 6)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<Title text={props.boost.Name} size={Type.title(props.phone)} tags={["wave"]} order={0} />
				<Text text={`${big} ${small}`} size={Type.body(props.phone)} color={accent} order={1} />
				{props.boost.Description !== undefined && <Text text={props.boost.Description} size={Type.small(props.phone)} color={Iron.muted()} multiline order={2} />}
			</frame>
		</Panel>
	);
}

function Stat(props: { label: string; value: string; color: Color3; phone: boolean; order: number }) {
	const reveal = useStagger(props.order + 1);
	return (
		<frame Size={UDim2.fromOffset(props.phone ? 116 : 150, props.phone ? 52 : 60)} BackgroundTransparency={1} LayoutOrder={props.order}>
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} Position={reveal.map((p) => UDim2.fromOffset(0, (1 - p) * 10))}>
				<Text text={props.value} size={props.phone ? 22 : 26} font={Fonts.heavy} color={props.color} box={new UDim2(1, 0, 0, props.phone ? 28 : 32)} />
				<Text text={props.label} size={Type.small(props.phone)} color={Iron.muted()} box={new UDim2(1, 0, 0, 18)} position={UDim2.fromOffset(0, props.phone ? 30 : 36)} />
			</frame>
		</frame>
	);
}

function BoostCard(props: {
	boost: BoostDef;
	owned: number;
	price?: number;
	stardust: number;
	canActivate: boolean;
	busyText: string;
	index: number;
	phone: boolean;
	width: UDim2;
	onRun: (boost: BoostDef, buy: boolean) => void;
	busy: boolean;
	claimRef?: React.Ref<Frame>;
}) {
	const { boost, owned, price, phone } = props;
	const reveal = useStagger(props.index + 2);
	const buyable = owned <= 0 && price !== undefined;
	const affordable = buyable && props.stardust >= price;
	const ready = (owned > 0 || affordable) && props.canActivate;
	const accent = boost.Color ?? Iron.ember();
	const shown = owned > 0 ? accent : Iron.muted();
	const [big, small] = headline(boost);
	const label = !props.canActivate && (owned > 0 || buyable) ? props.busyText : owned > 0 ? "Activate" : buyable ? `Run · ${compactNumber(price)} Stardust` : "Nothing stored";
	return (
		<frame Size={props.width} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.index}>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} Position={reveal.map((p) => UDim2.fromOffset(0, (1 - p) * 12))}>
				<Card accent={shown} selected={ready} pad={gap(phone, "l")} spacing={gap(phone, "s")} rarity={ready ? "Legendary" : undefined}>
					<frame key="Band" Size={new UDim2(1, 0, 0, phone ? 52 : 58)} BackgroundColor3={shown} BorderSizePixel={0} LayoutOrder={0}>
						<uicorner CornerRadius={new UDim(0, Corner.card)} />
						<uigradient Color={new ColorSequence(shown.Lerp(new Color3(), 0.3), shown.Lerp(new Color3(), 0.75))} Rotation={20} />
						<uipadding PaddingLeft={new UDim(0, 12)} PaddingRight={new UDim(0, 12)} />
					<Row order={0} spacing={10}>
						<Text text={big} size={phone ? 26 : 30} font={Fonts.heavy} color={shown} box={UDim2.fromOffset(phone ? 64 : 76, phone ? 30 : 36)} order={0} />
						<Text text={small} size={Type.small(phone)} color={Iron.soft()} box={new UDim2(1, -(phone ? 140 : 160), 0, 18)} order={1} />
						<Text text={owned > 0 ? `×${compactNumber(owned)}` : "None"} size={Type.body(phone)} font={Fonts.heavy} color={accent} align="Right" box={UDim2.fromOffset(50, 22)} order={2} />
					</Row>
					</frame>
					<Text text={boost.Name} size={Type.body(phone) + 1} font={Fonts.heavy} color={owned > 0 ? Iron.text() : Iron.soft()} order={1} />
					{boost.Description !== undefined && <Text text={boost.Description} size={Type.small(phone)} color={Iron.muted()} multiline order={2} />}
					<Text text={`Lasts ${clockText(boost.Duration ?? 0)}`} size={Type.small(phone)} color={shown} order={3} />
					<frame key="BoostClaimActions" ref={ready ? props.claimRef : undefined} Size={new UDim2(1, 0, 0, 44)} BackgroundTransparency={1} LayoutOrder={4}>
					<Tooltip tip={owned > 0 ? `Runs ${clockText(boost.Duration ?? 0)}. One boost at a time.` : buyable ? `Costs ${compactNumber(price)} Stardust, scaling with rebirths.` : "Win boosts from the prize wheel and daily rewards."} size={UDim2.fromScale(1, 1)}>
					<Button
						text={label}
						onPress={() => {
							if (owned > 0) props.onRun(boost, false);
							else if (buyable) props.onRun(boost, true);
						}}
						disabled={!ready || props.busy}
						glint={ready}
						tone={ready ? "brass" : "iron"}
						stretch
					/>
					</Tooltip>
					</frame>
				</Card>
			</frame>
		</frame>
	);
}

export function BoostsPage(props: PageProps) {
	const s = props.session as unknown as BoostsSession;
	const config = props.config as unknown as BoostsConfig;
	const phone = props.phone;
	const [filter, setFilter] = React.useState("All");
	const [sort, setSort] = React.useState("Recommended");
	const [hostRef, width] = useWidth();
	const [fired, setFired] = React.useState(0);
	const heroIn = useStagger(0);
	const inventory = s.BoostInventory ?? {};
	const ownedOf = (b: BoostDef) => math.max(0, math.floor(tonumber(inventory[b.Id]) ?? 0));
	const all: BoostDef[] = [];
	for (const [, def] of pairs(config.Boosts ?? {})) all.push(def);
	const activeId = s.ActiveBoost?.Id ?? "";
	const endsAt = (s.ActiveBoost !== undefined ? tonumber(s.ActiveBoost.EndsAt) : undefined) ?? 0;
	// re-check the end time each second so the page drops the reactor when the boost runs out
	const [, tick] = React.useState(0);
	React.useEffect(() => {
		if (activeId === "") return undefined;
		const left = endsAt - Workspace.GetServerTimeNow();
		if (left <= 0) return undefined;
		const job = task.delay(left + 0.05, () => tick((n) => n + 1));
		return () => {
			pcall(task.cancel, job);
		};
	}, [activeId, endsAt]);
	const running = activeId !== "" && endsAt > Workspace.GetServerTimeNow();
	const active = running ? (config.Boosts ?? {})[activeId] : undefined;
	let stored = 0;
	let types = 0;
	let banked = 0;
	let best = 1;
	let pick: BoostDef | undefined;
	for (const b of all) {
		const owned = ownedOf(b);
		stored += owned;
		if (owned <= 0) continue;
		types += 1;
		banked += owned * (tonumber(b.Duration) ?? 0);
		best = math.max(best, tonumber(b.Multiplier) ?? 1);
		if (pick === undefined || worth(b) > worth(pick)) pick = b;
	}
	const counts: Record<string, number> = { All: all.size(), Owned: types, Production: 0, Vault: 0 };
	for (const b of all) {
		if (tonumber(b.Multiplier) !== undefined) counts.Production += 1;
		if (tonumber(b.CapacityMultiplier) !== undefined) counts.Vault += 1;
	}
	const visible = all.filter((b) => {
		if (filter === "Owned") return ownedOf(b) > 0;
		if (filter === "Production") return tonumber(b.Multiplier) !== undefined;
		if (filter === "Vault") return tonumber(b.CapacityMultiplier) !== undefined;
		return true;
	});
	visible.sort((a, b) => {
		if (sort === "Strongest") {
			const x = tonumber(a.Multiplier) ?? tonumber(a.CapacityMultiplier) ?? 1;
			const y = tonumber(b.Multiplier) ?? tonumber(b.CapacityMultiplier) ?? 1;
			if (x !== y) return x > y;
		} else if (sort === "Longest") {
			const x = tonumber(a.Duration) ?? 0;
			const y = tonumber(b.Duration) ?? 0;
			if (x !== y) return x > y;
		} else if (sort === "Name") {
			return tostring(a.Name) < tostring(b.Name);
		} else {
			const ao = ownedOf(a) > 0;
			const bo = ownedOf(b) > 0;
			if (ao !== bo) return ao;
			if (worth(a) !== worth(b)) return worth(a) > worth(b);
		}
		return a.Id < b.Id;
	});
	const rebirths = math.max(0, math.floor(tonumber(s.Rebirths) ?? 0));
	const stardust = math.max(0, tonumber(s.Stardust) ?? 0);
	const busyText = active !== undefined ? `${active.Name} running` : "One at a time";
	const claimRef = useFocusClaim(!running && pick !== undefined, [pick?.Id, filter]);
	const busy = props.busy.ActivateBoost === true;
	const run = (boost: BoostDef, buy: boolean) => {
		setFired((n) => n + 1);
		Audio.play("reactorPulse");
		Burst.spark(boost.Color ?? Iron.ember(), 1);
		props.request("ActivateBoost", buy ? { Id: boost.Id, Buy: true } : { Id: boost.Id }, (reply) => {
			if (reply.ok === true) MotionFX.play("milestone");
		});
	};
	const space = gap(phone, "l");
	const columns = phone ? 1 : width >= 1280 ? 3 : 2;
	const fireFlash = useFlash(fired, false, 0.42);
	return (
		<PageScroll phone={phone}>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0} Position={heroIn.map((p) => UDim2.fromOffset(0, (1 - p) * 16))}>
				{active !== undefined ? (
					<Running key={active.Id} boost={active} endsAt={endsAt} phone={phone} />
				) : pick !== undefined ? (
					<Panel pad={gap(phone, "xl")} spacing={gap(phone, "m")} seam rarity="Legendary" scale={fireFlash.map((v) => 1 + v * 0.03)}>
						<Text text="Best pick" size={Type.small(phone)} font={Fonts.heavy} color={Iron.brass()} order={0} />
						<Title text={pick.Name} size={Type.title(phone)} tags={["wave"]} order={0} />
						<Text
							text={`${headline(pick)[0]} ${headline(pick)[1]} for ${clockText(pick.Duration ?? 0)} · ${compactNumber(ownedOf(pick))} stored`}
							size={Type.body(phone)}
							color={Iron.soft()}
							multiline
							order={1}
						/>
						<Button text={`Fire ${pick.Name}`} tone="ember" onPress={() => run(pick!, false)} disabled={busy} width={phone ? 220 : 260} height={phone ? 52 : 56} textSize={19} order={2} />
					</Panel>
				) : (
					<EmptyState title="The boost bay is empty" body="Win boosts from the prize wheel and daily rewards." phone={phone} />
				)}
			</frame>

			<Row order={1} spacing={space}>
				<Stat label="Stored" value={compactNumber(stored)} color={Iron.text()} phone={phone} order={0} />
				<Stat label="Types owned" value={`${types} / ${all.size()}`} color={Iron.steel()} phone={phone} order={1} />
				<Stat label="Time banked" value={`${compactNumber(math.floor(banked / 3600))}h`} color={Iron.brass()} phone={phone} order={2} />
				<Stat label="Best multiplier" value={`${best}x`} color={Iron.ember()} phone={phone} order={3} />
			</Row>

			<FilterChipRow options={FILTERS} value={filter} onChange={(id) => { Audio.play("tabSwitch"); setFilter(id); }} counts={counts} order={2} />
			<FilterChipRow options={SORTS.map(([id, label]) => ({ id, label }))} value={sort} onChange={setSort} accent={Iron.steel()} order={3} />

			<Grid order={4} spacing={space} hostRef={hostRef}>
				{visible.map((b, index) => (
					<BoostCard
						key={b.Id}
						boost={b}
						owned={ownedOf(b)}
						price={stardustPrice(config, b.Id, rebirths)}
						stardust={stardust}
						canActivate={!running}
						busyText={busyText}
						index={index}
						phone={phone}
						width={cellWidth(columns, space)}
						onRun={run}
						busy={busy}
						claimRef={b.Id === pick?.Id ? claimRef : undefined}
					/>
				))}
			</Grid>
			{visible.size() === 0 && all.size() > 0 && (
				<EmptyState title="Nothing in this filter" action={{ text: "Show all", onPress: () => setFilter("All") }} phone={phone} order={5} />
			)}
		</PageScroll>
	);
}

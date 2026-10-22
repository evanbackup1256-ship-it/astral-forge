// Worlds and the star charts, rebuilt on Forge2. Worlds read like stops on a line: the world you
// stand on is lit, the next stop shows what it asks for, everything else stays quiet. Under them
// sit the six Constellations, lit with Star Points (one per lifetime rebirth).
// Remotes: SelectZone {Id}, UnlockZone {Id}, ConstellationAct {Op: "Light", Star}.
import React from "@rbxts/react";
import { Audio } from "../../AudioKit/audio";
import { AppHelpers } from "../../CoreKit/appNav";
import { compactNumber, Flux, gteFlux } from "../../CoreKit/format";
import { useClock, useListStagger, usePulse } from "../../MotionKit/motion";
import * as Constellations from "../../../../Shared/AstralForge/Shared/Constellations";
import { ForgeButton as Button } from "../design/ForgeButton";
import { EmptyState, Tooltip } from "../design/Layers";
import { Card, Meter, Panel } from "../design/Panel";
import { Chip } from "../design/Pick";
import { Text, Title } from "../design/Text";
import { Fonts, gap, HIT, Iron, Type } from "../design/tokens";
import { Burst, MotionFX } from "../motion/motion";
import type { PageProps } from "../router/routes";

interface ZoneDef {
	Id: number;
	Name: string;
	Tagline?: string;
	Description?: string;
	Features?: string[];
	Multiplier?: Flux;
	Cost: Flux;
	CoreCost: number;
	RequiredRebirths: number;
	Color: Color3;
	DarkColor: Color3;
}

interface WorldsSession {
	Zone?: number;
	CurrentZone?: number;
	Rebirths?: number;
	Cores?: number;
	Cash?: Flux;
	Constellations?: { Points?: number; Lifetime?: number; Lit?: Record<string, boolean>; Paused?: boolean };
	ExpeditionBoard?: { Slots?: Array<{ Id: string }> };
}

const CHUNK = 24;
const SEARCH_SCAN = 600;
const SEARCH_RESULTS = 60;
const FILTERS: ReadonlyArray<[string, string]> = [
	["All", "All"],
	["Owned", "Owned"],
	["Next", "Next stops"],
	["Here", "Current"],
];
const SORTS: ReadonlyArray<[string, string]> = [
	["Order", "World order"],
	["Newest", "Newest first"],
	["Multiplier", "Best multiplier"],
	["Name", "A to Z"],
];

function pct(value: number): string {
	return `${math.floor(value * 1000 + 0.5) / 10}%`;
}

// ---------------------------------------------------------------------------------------------
// worlds

interface StopProps {
	zone: ZoneDef;
	index: number;
	here: boolean;
	owned: boolean;
	next: boolean;
	canUnlock: boolean;
	missing?: string;
	phone: boolean;
	busy: boolean;
	onPress: () => void;
}

/** One world. A ring marks where you are (it breathes), a hollow ring marks the next stop. */
function Stop(props: StopProps) {
	const { zone, here, owned, canUnlock, phone } = props;
	const reveal = useListStagger(props.index);
	const breathe = usePulse(here || canUnlock, here ? 0.9 : 1.6);
	const feature = zone.Features?.[0] ?? zone.Description ?? "";
	const boost = `${AppHelpers.formatWorldMultiplier(tonumber(zone.Multiplier) ?? 0)}x`;
	const asks: string[] = [];
	if (!owned) {
		if (zone.RequiredRebirths > 0) asks.push(`${zone.RequiredRebirths} rebirths`);
		if (zone.CoreCost > 0) asks.push(`${compactNumber(zone.CoreCost)} cores`);
		if (gteFlux(zone.Cost, 0.01)) asks.push(`${compactNumber(zone.Cost)} flux`);
	}
	const action = here ? "Here" : owned ? "Travel" : canUnlock ? "Unlock" : props.missing !== undefined ? `Need ${props.missing}` : "Later";
	const tone = here ? "quiet" : owned ? "iron" : canUnlock ? "brass" : "quiet";
	const markSize = phone ? 18 : 22;
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.index}>
			<uiscale Scale={reveal.map((p) => 0.97 + p * 0.03)} />
			<Card accent={zone.Color} selected={here} pad={gap(phone, "l")} spacing={gap(phone, "s")} rarity={here ? "Legendary" : undefined}>
				<frame Size={new UDim2(1, 0, 0, markSize + 8)} BackgroundTransparency={1} LayoutOrder={0}>
					<frame
						Size={UDim2.fromOffset(markSize, markSize)}
						Position={new UDim2(0, 0, 0.5, 0)}
						AnchorPoint={new Vector2(0, 0.5)}
						BackgroundColor3={zone.Color}
						BackgroundTransparency={here ? 0 : 1}
					>
						<uicorner CornerRadius={new UDim(1, 0)} />
						<uistroke
							Color={zone.Color}
							Thickness={2}
							Transparency={here || canUnlock ? breathe.map((a) => 0.1 + a * 0.5) : owned ? 0.2 : 0.65}
						/>
					</frame>
					<Text
						text={zone.Name}
						size={Type.title(phone) - 4}
						font={Fonts.heavy}
						color={owned ? Iron.text() : Iron.soft()}
						box={new UDim2(1, -(markSize + 12 + (phone ? 70 : 90)), 1, 0)}
						position={UDim2.fromOffset(markSize + 12, 0)}
					/>
					<Text
						text={boost}
						size={Type.body(phone)}
						font={Fonts.heavy}
						color={zone.Color}
						align="Right"
						box={new UDim2(0, phone ? 70 : 90, 1, 0)}
						position={new UDim2(1, -(phone ? 70 : 90), 0, 0)}
					/>
				</frame>
				{feature !== "" && <Text text={feature} size={Type.small(phone)} color={Iron.muted()} order={1} />}
				{asks.size() > 0 && <Text text={asks.join("   ")} size={Type.small(phone)} color={canUnlock ? Iron.brass() : Iron.muted()} order={2} />}
				<Tooltip tip={zone.Tagline ?? feature} size={new UDim2(1, 0, 0, HIT)} order={3}>
					<Button
						text={action}
						tone={tone}
						stretch
						disabled={here || (!owned && !canUnlock)}
						busy={props.busy}
						glint={canUnlock}
						onPress={props.onPress}
					/>
				</Tooltip>
			</Card>
		</frame>
	);
}

// ---------------------------------------------------------------------------------------------
// constellations

interface ChartProps {
	chart: Constellations.Constellation;
	index: number;
	lit: Record<string, boolean>;
	points: number;
	paused: boolean;
	pending?: string;
	refused: { key: string; token: number };
	phone: boolean;
	onLight: (star: string) => void;
}

/** A chart: its stars as a strung line of dots, lit ones glowing in turn. */
function Chart(props: ChartProps) {
	const { chart, lit, phone } = props;
	const reveal = useListStagger(props.index);
	let count = 0;
	for (const star of chart.Stars) {
		if (lit[star.Id] !== true) break;
		count += 1;
	}
	const done = count === chart.Stars.size();
	const upcoming = done ? undefined : chart.Stars[count];
	const ready = upcoming !== undefined && props.points >= upcoming.Cost && !props.paused;
	const current = count * chart.PerStar + (done ? chart.Completion : 0);
	const accent = done ? Iron.brass() : count > 0 ? Iron.steel() : Iron.edge();
	const twinkle = useClock(count > 0, 0.8);
	const dot = phone ? 12 : 14;
	const span = phone ? 26 : 34;
	const dots: React.Element[] = [];
	chart.Stars.forEach((star, i) => {
		const on = lit[star.Id] === true;
		dots.push(
			<frame
				key={star.Id}
				Size={UDim2.fromOffset(dot, dot)}
				Position={UDim2.fromOffset(i * span, 0)}
				BackgroundColor3={on ? accent : Iron.sunk()}
				BackgroundTransparency={on ? twinkle.map((t) => 0.05 + (math.sin(t * 2 + i) + 1) * 0.12) : 0.2}
				ZIndex={3}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke Color={on ? accent : star === upcoming ? Iron.brass() : Iron.edge()} Thickness={star === upcoming ? 2 : 1} Transparency={on ? 0.5 : 0.2} />
			</frame>,
		);
		if (i > 0) {
			dots.push(
				<frame
					key={`${star.Id}line`}
					Size={UDim2.fromOffset(span - dot, 2)}
					Position={UDim2.fromOffset((i - 1) * span + dot, dot / 2 - 1)}
					BackgroundColor3={on ? accent : Iron.edge()}
					BackgroundTransparency={on ? 0.2 : 0.7}
					BorderSizePixel={0}
					ZIndex={2}
				/>,
			);
		}
	});
	const tip = upcoming !== undefined
		? `${chart.Blurb} Next: ${upcoming.Name}, +${pct(chart.PerStar)}${count === chart.Stars.size() - 1 ? ` and +${pct(chart.Completion)} for finishing` : ""}.`
		: `${chart.Blurb} Complete.`;
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.index}>
			<uiscale Scale={reveal.map((p) => 0.97 + p * 0.03)} />
			<frame
				Size={new UDim2(1, 0, 0, 0)}
				AutomaticSize={Enum.AutomaticSize.Y}
				BackgroundTransparency={1}
			>
				<Card accent={accent} selected={done} pad={gap(phone, "l")} spacing={gap(phone, "m")} rarity={done ? "Mythic" : undefined}>
					<frame Size={new UDim2(1, 0, 0, Type.body(phone) + 8)} BackgroundTransparency={1} LayoutOrder={0}>
						<Text text={chart.Name} size={Type.body(phone) + 2} font={Fonts.heavy} box={new UDim2(1, -90, 1, 0)} />
						<Text text={`+${pct(current)}`} size={Type.body(phone)} font={Fonts.heavy} color={accent} align="Right" box={new UDim2(0, 90, 1, 0)} position={new UDim2(1, -90, 0, 0)} />
					</frame>
					<frame Size={new UDim2(1, 0, 0, dot)} BackgroundTransparency={1} LayoutOrder={1}>
						{dots}
					</frame>
					<Text text={chart.Kind.lower()} size={Type.small(phone)} color={Iron.muted()} order={2} />
					{upcoming !== undefined && (
						<Tooltip tip={tip} size={new UDim2(1, 0, 0, HIT)} order={3}>
							<Button
								text={`Light ${upcoming.Name}  ${upcoming.Cost}`}
								tone={ready ? "brass" : "quiet"}
								stretch
								disabled={!ready}
								busy={props.pending === upcoming.Id}
								glint={ready}
								shakeToken={props.refused.key === upcoming.Id ? props.refused.token : 0}
								onPress={() => props.onLight(upcoming.Id)}
							/>
						</Tooltip>
					)}
				</Card>
			</frame>
		</frame>
	);
}

function ConstellationBlock(props: PageProps & { order: number }) {
	const phone = props.phone;
	const state = (props.session as unknown as WorldsSession).Constellations;
	const [pending, setPending] = React.useState<string>();
	const [refused, setRefused] = React.useState({ key: "", token: 0 });
	if (state === undefined) return undefined;
	const lit = state.Lit ?? {};
	const points = state.Points ?? 0;
	const paused = state.Paused === true;
	const light = (star: string) => {
		if (pending !== undefined) return;
		setPending(star);
		const fallback = task.delay(8, () => setPending(undefined));
		props.request("ConstellationAct", { Op: "Light", Star: star }, (reply) => {
			pcall(task.cancel, fallback);
			setPending(undefined);
			if (reply.ok === true) {
				Audio.play("successChime");
				Burst.spark(Iron.brass(), 0.9);
				MotionFX.play("success");
			} else {
				Audio.play("error");
				setRefused((r) => ({ key: star, token: r.token + 1 }));
			}
		});
	};
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.order}>
			<uilistlayout Padding={new UDim(0, gap(phone, "m"))} SortOrder={Enum.SortOrder.LayoutOrder} />
			<frame Size={new UDim2(1, 0, 0, Type.hero(phone) + 8)} BackgroundTransparency={1} LayoutOrder={0}>
				<frame Size={new UDim2(0.6, 0, 1, 0)} BackgroundTransparency={1}>
					<Title text="Constellations" size={Type.title(phone)} />
				</frame>
				<Tooltip tip={paused ? "The charts are closed for a moment. Lit stars still count." : "Star Points. Every rebirth you have ever done earns one."} size={new UDim2(0.4, 0, 1, 0)}>
					<Text
						text={paused ? "Charts closed" : tostring(points)}
						size={Type.hero(phone)}
						font={Fonts.heavy}
						color={paused ? Iron.muted() : Iron.brass()}
						align="Right"
						box={UDim2.fromScale(1, 1)}
					/>
				</Tooltip>
			</frame>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
				<uilistlayout Padding={new UDim(0, gap(phone, "m"))} SortOrder={Enum.SortOrder.LayoutOrder} />
				{Constellations.CONSTELLATIONS.map((chart, i) => (
					<Chart
						key={chart.Id}
						chart={chart}
						index={i}
						lit={lit}
						points={points}
						paused={paused}
						pending={pending}
						refused={refused}
						phone={phone}
						onLight={light}
					/>
				))}
			</frame>
		</frame>
	);
}

// ---------------------------------------------------------------------------------------------
// page

export function WorldsPage(props: PageProps) {
	const phone = props.phone;
	const s = props.session as unknown as WorldsSession;
	const config = props.config as { Zones?: ZoneDef[]; MaxZone?: number; ResolveZone?: (this: void, id: number) => ZoneDef | undefined };
	const zone = math.max(1, s.Zone ?? 1);
	const here = s.CurrentZone ?? zone;
	const rebirths = s.Rebirths ?? 0;
	const cores = s.Cores ?? 0;
	const catalog = config.MaxZone ?? config.Zones?.size() ?? 0;
	const total = catalog > 0 ? math.clamp(zone + 2, 1, catalog) : 0;
	const resolve = (id: number) => (config.ResolveZone !== undefined ? config.ResolveZone(id) : config.Zones?.[id - 1]);
	const [filter, setFilter] = React.useState<string>("All");
	const [sort, setSort] = React.useState("Order");
	const [query, setQuery] = React.useState("");
	const [start, setStart] = React.useState(() => math.max(1, here - 4));
	const [count, setCount] = React.useState(CHUNK);
	const [acting, setActing] = React.useState<number>();
	const scrollRef = React.useRef<ScrollingFrame>();
	const space = gap(phone, "l");

	const browsing = filter !== "All" || sort !== "Order" || query !== "";
	const shown = React.useMemo(() => {
		const list: ZoneDef[] = [];
		if (!browsing) {
			for (let id = start; id <= math.min(total, start + count - 1); id++) {
				const z = resolve(id);
				if (z !== undefined) list.push(z);
			}
			return list;
		}
		const needle = query.lower();
		for (let id = math.max(1, total - SEARCH_SCAN + 1); id <= total; id++) {
			const z = resolve(id);
			if (z === undefined) continue;
			if (filter === "Owned" && zone < z.Id) continue;
			if (filter === "Next" && zone >= z.Id) continue;
			if (filter === "Here" && here !== z.Id) continue;
			if (needle !== "") {
				const hay = `${z.Name} ${z.Tagline ?? ""} ${(z.Features ?? []).join(" ")} ${z.Description ?? ""} world ${z.Id}`.lower();
				if (hay.find(needle, 1, true)[0] === undefined) continue;
			}
			list.push(z);
		}
		if (sort === "Newest") list.sort((a, b) => a.Id > b.Id);
		else if (sort === "Multiplier") list.sort((a, b) => (tonumber(a.Multiplier) ?? 0) > (tonumber(b.Multiplier) ?? 0));
		else if (sort === "Name") list.sort((a, b) => tostring(a.Name) < tostring(b.Name));
		while (list.size() > SEARCH_RESULTS) list.pop();
		return list;
	}, [browsing, filter, sort, query, start, count, total, zone, here]);

	const act = (z: ZoneDef, owned: boolean) => {
		if (acting !== undefined) return;
		setActing(z.Id);
		props.request(owned ? "SelectZone" : "UnlockZone", { Id: z.Id }, (reply) => {
			setActing(undefined);
			if (reply.ok !== true) return;
			if (owned) {
				Audio.play("travel");
				MotionFX.play("confirm");
			} else {
				Audio.play("zoneUnlock");
				Burst.spark(z.Color, 1);
				MotionFX.play("milestone");
			}
		});
	};

	const jumpHere = () => {
		setFilter("All");
		setSort("Order");
		setQuery("");
		setStart(math.max(1, here - 4));
		setCount(CHUNK);
		task.defer(() => {
			const scroller = scrollRef.current;
			if (scroller !== undefined) scroller.CanvasPosition = new Vector2(0, 0);
		});
	};

	const board = s.ExpeditionBoard;
	let out = 0;
	for (const slot of board?.Slots ?? []) if (slot.Id !== "") out += 1;
	const slots = board?.Slots?.size() ?? 3;
	const later = !browsing && start + count - 1 < total;
	const earlier = !browsing && start > 1;

	return (
		<scrollingframe
			ref={scrollRef}
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			CanvasSize={new UDim2()}
			AutomaticCanvasSize={Enum.AutomaticSize.Y}
			ScrollBarThickness={phone ? 0 : 4}
			ScrollBarImageColor3={Iron.brassDeep()}
		>
			<uipadding PaddingTop={new UDim(0, space)} PaddingBottom={new UDim(0, space * 3 + props.chrome.bottomSafe)} PaddingLeft={new UDim(0, space)} PaddingRight={new UDim(0, space)} />
			<uilistlayout Padding={new UDim(0, gap(phone, "xl"))} SortOrder={Enum.SortOrder.LayoutOrder} />

			<Panel pad={gap(phone, "l")} spacing={gap(phone, "m")} seam order={0}>
				<frame Size={new UDim2(1, 0, 0, Type.hero(phone) + 12)} BackgroundTransparency={1} LayoutOrder={0}>
					<Text text={tostring(here)} size={Type.hero(phone)} font={Fonts.heavy} color={Iron.brass()} box={new UDim2(0, phone ? 80 : 120, 1, 0)} />
					<frame Size={new UDim2(1, -(phone ? 90 : 136), 1, 0)} Position={UDim2.fromOffset(phone ? 90 : 136, 0)} BackgroundTransparency={1}>
						<Title text={resolve(here)?.Name ?? "Worlds"} size={Type.title(phone)} />
						<Text
							text={here !== zone ? `farthest ${zone} of ${catalog}` : `${zone} of ${catalog}`}
							size={Type.small(phone)}
							color={Iron.muted()}
							position={UDim2.fromOffset(0, Type.title(phone) + 12)}
						/>
					</frame>
				</frame>
				<Meter value={catalog > 0 ? zone / catalog : 0} order={1} height={6} />
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
					<Button text="Find current" tone="iron" width={150} onPress={jumpHere} order={0} />
					<Button text={out > 0 ? `Expeditions ${out}/${slots}` : "Expeditions"} tone="iron" width={180} onPress={() => props.navigate("Expeditions")} order={1} />
				</frame>
			</Panel>

			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} VerticalAlignment={Enum.VerticalAlignment.Center} />
				<textbox
					Size={new UDim2(0, phone ? 200 : 260, 0, HIT)}
					BackgroundColor3={Iron.sunk()}
					BackgroundTransparency={0.2}
					PlaceholderText="Search worlds by name or feature"
					PlaceholderColor3={Iron.muted()}
					Text={query}
					TextColor3={Iron.text()}
					FontFace={Fonts.bold}
					TextSize={15}
					TextXAlignment={Enum.TextXAlignment.Left}
					ClearTextOnFocus={false}
					LayoutOrder={0}
					Change={{ Text: (box) => setQuery(box.Text) }}
				>
					<uicorner CornerRadius={new UDim(0, 6)} />
					<uipadding PaddingLeft={new UDim(0, 12)} PaddingRight={new UDim(0, 12)} />
					<uistroke Color={Iron.edge()} Transparency={0.5} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
				</textbox>
				{FILTERS.map(([id, label], i) => (
					<Chip key={id} text={label} on={filter === id} onPress={() => setFilter(id)} order={i + 1} />
				))}
				{SORTS.map(([id, label], i) => (
					<Chip key={id} text={label} on={sort === id} color={Iron.steel()} onPress={() => setSort(id)} order={10 + i} />
				))}
			</frame>

			{earlier && <Button text={`Show earlier  (${start - 1})`} tone="quiet" stretch onPress={() => {
				const grow = math.min(CHUNK, start - 1);
				setStart(start - grow);
				setCount(math.min(count + grow, CHUNK * 3));
			}} order={2} />}

			{shown.size() === 0 ? (
				<EmptyState title="No worlds match" body="Clear the search or pick another filter." phone={phone} order={3}
					action={{ text: "Show all", onPress: jumpHere }} />
			) : (
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={3}>
					<uilistlayout Padding={new UDim(0, gap(phone, "m"))} SortOrder={Enum.SortOrder.LayoutOrder} />
					{shown.map((z, i) => {
						const owned = zone >= z.Id;
						const rebirthOk = rebirths >= z.RequiredRebirths;
						const coresOk = cores >= z.CoreCost;
						const cashOk = gteFlux(s.Cash ?? 0, z.Cost);
						const isNext = z.Id === zone + 1;
						const canUnlock = !owned && isNext && rebirthOk && coresOk && cashOk;
						const missing = owned
							? undefined
							: !rebirthOk
								? `${z.RequiredRebirths} rebirths`
								: !coresOk
									? `${compactNumber(z.CoreCost)} cores`
									: !cashOk
										? `${compactNumber(z.Cost)} flux`
										: undefined;
						return (
							<Stop
								key={z.Id}
								zone={z}
								index={i}
								here={here === z.Id}
								owned={owned}
								next={isNext}
								canUnlock={canUnlock}
								missing={missing}
								phone={phone}
								busy={acting === z.Id}
								onPress={() => act(z, owned)}
							/>
						);
					})}
				</frame>
			)}

			{later && <Button text={`Show more  (${total - (start + count - 1)} left)`} tone="quiet" stretch onPress={() => {
				if (count >= CHUNK * 3) setStart(start + CHUNK);
				else setCount(count + CHUNK);
			}} order={4} />}

			<ConstellationBlock {...props} order={5} />
		</scrollingframe>
	);
}

// Star charts for v8 Constellations (Forge UI 4 port of design 11-constellations).
// A tab per chart, the chart drawn as a star graph (node frames + rotated 1.5px line frames), and a
// detail panel for the next star with the Light action. Give it the snapshot's Constellations block
// and the page dispatcher; the remote (ConstellationAct Light) and state shape are unchanged.
import React from "@rbxts/react";
import { Palette, TapTarget } from "../../CoreKit/theme";
import { kitMember, LuauComponent } from "../luauKits";
import * as Constellations from "../../../../Shared/AstralForge/Shared/Constellations";
import { Eyebrow, StarField } from "./portKit";
import { BODY, DiamondRule, MockPanel, PanelHeading } from "../../UiCore/mockKit";
import { MockRow, SEC } from "../mockRows";

const { Button, SegmentedTabs, Text } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");

type Reply = (response: { ok?: boolean; message?: string }) => void;
export type ConstellationDispatch = (action: string, payload?: object, callback?: Reply) => unknown;

export interface ConstellationState {
	Points?: number;
	Lifetime?: number;
	Lit?: Record<string, boolean>;
	Paused?: boolean;
}

// generated from design/11-constellations by scripts/gen_from_layout.js (scripts/layout/constellations.spec.json)
import { ConstellationsLayout as L } from "../generated/ConstellationsLayout";
const GAP = 18;
const HEAD_H = 22;
const ROW_GAP = 8;
const LINE_W = 1.5;
// the side-by-side chart | detail layout needs this much width
const ROW_MODE_MIN = 560;
const GRAPH_H_COLUMN = 240;
// full detail: header 40, blurb 36, cost + gives rows, button, divider, three status rows
// 11-constellations detail .pn (460px): h3 + note, 15px blurb, Cost / Gives rows, violet button, rule, three status rows
const DETAIL_PAD = L.Detail.pad.top;
// the blurb keeps room for a second line: chart blurbs run longer than the mockup sample
const BLURB_H = L.Blurb.h * 2;
const DG = L.Detail.gap;
const DETAIL_FULL_H = DETAIL_PAD * 2 + L.DetailHead.h + DG + BLURB_H + DG + (L.Row.h + DG) * 2 + L.Btn.h + DG + L.Rule.h + DG + L.Row.h * 3 + DG * 2;
// compact detail (phones): next star row, status row, the Light button
const COMPACT_PAD = 10;
const DETAIL_COMPACT_H = COMPACT_PAD * 2 + 44 * 2 + 8 * 2 + TapTarget;
const PHONE_BODY_H = 220;

// node positions (0..1 of the chart area) and the lines between them, per chart
const SHAPES: Record<string, { at: Array<[number, number]>; links: Array<[number, number]> }> = {
	Anvil: { at: [[0.16, 0.58], [0.33, 0.36], [0.5, 0.48], [0.42, 0.8], [0.68, 0.24]], links: [[0, 1], [1, 2], [2, 3], [3, 0], [2, 4]] },
	Cistern: { at: [[0.22, 0.28], [0.32, 0.7], [0.52, 0.82], [0.72, 0.68], [0.8, 0.26]], links: [[0, 1], [1, 2], [2, 3], [3, 4]] },
	Hammer: { at: [[0.2, 0.78], [0.38, 0.6], [0.56, 0.42], [0.44, 0.2], [0.78, 0.56]], links: [[0, 1], [1, 2], [2, 3], [2, 4]] },
	Lantern: { at: [[0.5, 0.16], [0.34, 0.42], [0.66, 0.42], [0.62, 0.8], [0.38, 0.8]], links: [[0, 1], [0, 2], [1, 2], [1, 4], [2, 3], [3, 4]] },
	Spark: { at: [[0.46, 0.14], [0.58, 0.44], [0.84, 0.5], [0.54, 0.62], [0.34, 0.88]], links: [[0, 1], [1, 2], [2, 3], [3, 4]] },
	Loom: { at: [[0.2, 0.32], [0.5, 0.18], [0.8, 0.32], [0.66, 0.76], [0.34, 0.76]], links: [[0, 1], [1, 2], [2, 3], [3, 4], [4, 0]] },
};
const FALLBACK_SHAPE = SHAPES.Anvil;

function pct(value: number): string {
	const scaled = math.floor(value * 1000 + 0.5) / 10;
	return `${scaled}%`;
}

function shortName(chart: Constellations.Constellation): string {
	return chart.Name.gsub("^The ", "")[0];
}

interface Layout {
	rowMode: boolean;
	compact: boolean;
	sideW: number;
	tabColumns: number;
	tabsH: number;
	bodyH: number;
	total: number;
}

function layoutFor(stack: boolean, width: number, phone: boolean): Layout {
	const count = Constellations.CONSTELLATIONS.size();
	const rowMode = width >= ROW_MODE_MIN;
	const compact = phone;
	const tabColumns = width >= 520 ? count : 3;
	const tabRows = math.ceil(count / tabColumns);
	const tabsH = tabRows * TapTarget + (tabRows - 1) * 6;
	const sideW = phone ? math.clamp(math.floor(width * 0.36), 220, 300) : math.clamp(math.floor(width * 0.4), 300, L.Detail.w);
	const detailH = compact ? DETAIL_COMPACT_H : DETAIL_FULL_H;
	const bodyH = rowMode ? (phone ? math.max(PHONE_BODY_H, detailH) : detailH) : GRAPH_H_COLUMN + GAP + detailH;
	const total = HEAD_H + ROW_GAP + tabsH + GAP + bodyH;
	return { rowMode, compact, sideW, tabColumns, tabsH, bodyH, total };
}

/** Section height for the charts block. `width` is the room it gets; `phone` uses the compact detail. */
export function constellationsHeight(stack: boolean, width = 1000, phone = stack): number {
	return layoutFor(stack, width, phone).total;
}

interface ChartStatus {
	count: number;
	done: boolean;
	next?: Constellations.Star;
	current: number;
}

function statusOf(chart: Constellations.Constellation, lit: Record<string, boolean>): ChartStatus {
	let count = 0;
	for (const star of chart.Stars) {
		if (lit[star.Id] !== true) {
			break;
		}
		count += 1;
	}
	const done = count === chart.Stars.size();
	return { count, done, next: done ? undefined : chart.Stars[count], current: count * chart.PerStar + (done ? chart.Completion : 0) };
}

function StarGraph(p: { chart: Constellations.Constellation; status: ChartStatus; reducedMotion?: boolean }) {
	const hostRef = React.useRef<Frame>();
	const [area, setArea] = React.useState(new Vector2(0, 0));
	React.useEffect(() => {
		const host = hostRef.current;
		if (host === undefined) {
			return undefined;
		}
		setArea(host.AbsoluteSize);
		const connection = host.GetPropertyChangedSignal("AbsoluteSize").Connect(() => setArea(host.AbsoluteSize));
		return () => connection.Disconnect();
	}, []);
	const shape = SHAPES[p.chart.Id] ?? FALLBACK_SHAPE;
	const inset = 28;
	const w = math.max(0, area.X - inset * 2);
	const h = math.max(0, area.Y - inset * 2);
	const point = (i: number) => new Vector2(inset + shape.at[i][0] * w, inset + shape.at[i][1] * h);
	const isLit = (i: number) => i < p.status.count;
	const nextIndex = p.status.done ? -1 : p.status.count;
	const pieces: React.Element[] = [];
	if (w > 0 && h > 0) {
		shape.links.forEach(([a, b], index) => {
			if (a >= p.chart.Stars.size() || b >= p.chart.Stars.size()) {
				return;
			}
			const from = point(a);
			const to = point(b);
			const delta = to.sub(from);
			const length = delta.Magnitude;
			const angle = math.deg(math.atan2(delta.Y, delta.X));
			const mid = from.add(to).div(2);
			if (isLit(a) && isLit(b)) {
				pieces.push(
					<frame
						key={`l${index}`}
						BackgroundColor3={Palette.pink.Lerp(Palette.cream, 0.55)}
						BorderSizePixel={0}
						AnchorPoint={new Vector2(0.5, 0.5)}
						Position={UDim2.fromOffset(mid.X, mid.Y)}
						Size={UDim2.fromOffset(length, LINE_W)}
						Rotation={angle}
						ZIndex={3}
					/>,
				);
			} else {
				// unlit link: a dotted run of short dashes along the same line
				const dashes = math.max(2, math.floor(length / 9));
				for (let d = 0; d < dashes; d++) {
					const t = (d + 0.5) / dashes;
					const at = from.add(delta.mul(t));
					pieces.push(
						<frame
							key={`d${index}_${d}`}
							BackgroundColor3={Palette.lineSoft}
							BackgroundTransparency={0.2}
							BorderSizePixel={0}
							AnchorPoint={new Vector2(0.5, 0.5)}
							Position={UDim2.fromOffset(at.X, at.Y)}
							Size={UDim2.fromOffset(3, LINE_W)}
							Rotation={angle}
							ZIndex={3}
						/>,
					);
				}
			}
		});
		p.chart.Stars.forEach((star, i) => {
			if (i >= shape.at.size()) {
				return;
			}
			const at = point(i);
			const lit = isLit(i);
			const nextStar = i === nextIndex;
			const size = lit ? 16 : nextStar ? 14 : 10;
			pieces.push(
				<frame
					key={`n${star.Id}`}
					{...{ Name: `Star_${star.Id}` }}
					BackgroundColor3={lit ? Palette.cream : Palette.panel}
					BackgroundTransparency={lit ? 0 : 0.2}
					BorderSizePixel={0}
					AnchorPoint={new Vector2(0.5, 0.5)}
					Position={UDim2.fromOffset(at.X, at.Y)}
					Size={UDim2.fromOffset(size, size)}
					ZIndex={5}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
					<uistroke Color={lit ? Palette.pink : nextStar ? Palette.pink : Palette.lineSoft} Thickness={lit ? 2 : 1.5} Transparency={lit ? 0.35 : nextStar ? 0 : 0.1} />
				</frame>,
			);
			if (nextStar) {
				// a still halo marks the star the button lights
				pieces.push(
					<frame
						key="halo"
						BackgroundTransparency={1}
						BorderSizePixel={0}
						AnchorPoint={new Vector2(0.5, 0.5)}
						Position={UDim2.fromOffset(at.X, at.Y)}
						Size={UDim2.fromOffset(28, 28)}
						ZIndex={4}
					>
						<uicorner CornerRadius={new UDim(1, 0)} />
						<uistroke Color={Palette.pink} Thickness={1} Transparency={0.55} />
					</frame>,
				);
			}
			if (nextStar || (p.status.done && i === p.chart.Stars.size() - 1)) {
				const right = at.X < area.X - 140;
				pieces.push(
					<textlabel
						key="label"
						BackgroundTransparency={1}
						Text={star.Name}
						TextSize={13}
						Font={Enum.Font.BuilderSansBold}
						TextColor3={Palette.cream}
						TextXAlignment={right ? Enum.TextXAlignment.Left : Enum.TextXAlignment.Right}
						TextTruncate={Enum.TextTruncate.AtEnd}
						AnchorPoint={new Vector2(right ? 0 : 1, 1)}
						Position={UDim2.fromOffset(at.X + (right ? 12 : -12), at.Y - 8)}
						Size={UDim2.fromOffset(120, 18)}
						ZIndex={6}
					/>,
				);
			}
		});
	}
	return (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={false} accent={Palette.violet} reducedMotion={p.reducedMotion} name="StarGraphPanel">
			<frame ref={hostRef} {...{ Name: "StarGraph" }} BackgroundTransparency={1} BorderSizePixel={0} Size={UDim2.fromScale(1, 1)} ClipsDescendants={true} ZIndex={2}>
				<StarField count={34} seed={p.chart.Id.size() * 17 + 3} zIndex={2} />
				{pieces}
			</frame>
		</MockPanel>
	);
}

function ChartDetail(p: {
	chart: Constellations.Constellation;
	status: ChartStatus;
	points: number;
	paused: boolean;
	compact: boolean;
	pending: boolean;
	shakeToken: number;
	onLight: () => void;
	reducedMotion?: boolean;
}) {
	const { chart, status, points } = p;
	const nextStar = status.next;
	const ready = nextStar !== undefined && points >= nextStar.Cost && !p.paused;
	const kind = chart.Kind.lower();
	const last = nextStar !== undefined && status.count === chart.Stars.size() - 1;
	const buttonText = p.paused
		? "Charts closed"
		: nextStar === undefined
			? "Chart complete"
			: ready
				? p.compact
					? `Light · ${nextStar.Cost} pts`
					: "Light this star"
				: `Need ${nextStar.Cost - points} more pts`;
	const button = (y: UDim) => (
		<frame BackgroundTransparency={1} BorderSizePixel={0} Position={new UDim2(new UDim(0, 0), y)} Size={new UDim2(1, 0, 0, TapTarget)} ZIndex={4} LayoutOrder={2}>
			<Button
				text={buttonText}
				icon="StarGrid.2"
				onClick={p.onLight}
				color={ready ? Palette.violet : SEC}
				textColor={ready ? Palette.ink : Palette.muted}
				size={UDim2.fromScale(1, 1)}
				disabled={!ready}
				highlight={ready}
				loading={p.pending}
				shakeToken={p.shakeToken}
				reducedMotion={p.reducedMotion}
				tooltip={{ title: chart.Name, body: chart.Blurb, accent: Palette.pink }}
			/>
		</frame>
	);
	if (p.compact) {
		return (
			<MockPanel size={UDim2.fromScale(1, 1)} phone={true} accent={Palette.violet} reducedMotion={p.reducedMotion} name="ChartDetail">
				<MockRow phone={true} icon="StarGrid" accent={Palette.violet} title={nextStar !== undefined ? "Next star" : "All lit"} value={nextStar !== undefined ? nextStar.Name : chart.Name} layoutOrder={0} />
				<MockRow phone={true} icon="Forge" accent={Palette.violet} title={`${status.count} of ${chart.Stars.size()} lit`} value={`+${pct(status.current)} ${kind}`} layoutOrder={1} />
				{button(new UDim(0, 0))}
			</MockPanel>
		);
	}
	return (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={false} accent={Palette.violet} reducedMotion={p.reducedMotion} name="ChartDetail">
			<PanelHeading
				icon="StarGrid"
				title={nextStar !== undefined ? nextStar.Name : chart.Name}
				note={nextStar !== undefined ? `Next star · ${status.count + 1} of ${chart.Stars.size()}` : "Every star lit"}
				accent={Palette.violet}
				phone={false}
				layoutOrder={0}
			/>
			<textlabel
				BackgroundTransparency={1}
				Text={chart.Blurb}
				TextSize={L.Blurb.text.size}
				FontFace={BODY}
				TextColor3={L.Blurb.text.color}
				TextWrapped={true}
				TextXAlignment={Enum.TextXAlignment.Left}
				TextYAlignment={Enum.TextYAlignment.Top}
				Size={new UDim2(1, 0, 0, BLURB_H)}
				LayoutOrder={1}
			/>
			{nextStar !== undefined ? (
				<MockRow phone={false} icon="Dust" accent={Palette.violet} title="Cost" value={`${nextStar.Cost} pts`} layoutOrder={2} />
			) : (
				<MockRow phone={false} icon="Dust" accent={Palette.violet} title="Finishing bonus" value={`+${pct(chart.Completion)} ${kind}`} layoutOrder={2} />
			)}
			<MockRow
				phone={false}
				icon="StarGrid"
				accent={Palette.violet}
				title="Gives"
				value={nextStar !== undefined ? `+${pct(chart.PerStar)}${last ? ` (+${pct(chart.Completion)} to finish)` : ""}` : `+${pct(chart.PerStar)} per star`}
				layoutOrder={3}
			/>
			<frame BackgroundTransparency={1} BorderSizePixel={0} Size={new UDim2(1, 0, 0, L.Btn.h)} LayoutOrder={4}>
				<Button
					text={buttonText}
					icon="StarGrid.2"
					onClick={p.onLight}
					color={ready ? Palette.violet : SEC}
					textColor={ready ? Palette.ink : Palette.cream}
					size={UDim2.fromScale(1, 1)}
					disabled={!ready}
					highlight={ready}
					loading={p.pending}
					shakeToken={p.shakeToken}
					reducedMotion={p.reducedMotion}
					tooltip={{ title: chart.Name, body: chart.Blurb, accent: Palette.pink }}
				/>
			</frame>
			<DiamondRule layoutOrder={5} />
			<MockRow phone={false} icon="Forge" accent={Palette.violet} title="Stars lit" value={`${status.count} of ${chart.Stars.size()}`} layoutOrder={6} />
			<MockRow phone={false} icon="Vault" accent={Palette.violet} title="Bonus now" value={`+${pct(status.current)} ${kind}`} layoutOrder={7} />
			<MockRow phone={false} icon="Core" accent={Palette.violet} title="Star points" value={p.paused ? "Closed" : `${points}`} layoutOrder={8} />
		</MockPanel>
	);
}

export function ConstellationsView(props: {
	state: ConstellationState;
	dispatch: ConstellationDispatch;
	stack: boolean;
	width?: number;
	phone?: boolean;
	reducedMotion?: boolean;
}) {
	const { state, stack } = props;
	const lit = state.Lit ?? {};
	const points = state.Points ?? 0;
	const paused = state.Paused === true;
	const layout = layoutFor(stack, props.width ?? 1000, props.phone ?? stack);
	const charts = Constellations.CONSTELLATIONS;
	// open on the first chart that still has a star to light
	const firstOpen = charts.find((chart) => !statusOf(chart, lit).done) ?? charts[0];
	const [selectedId, setSelectedId] = React.useState(firstOpen.Id);
	const chart = charts.find((c) => c.Id === selectedId) ?? firstOpen;
	const status = statusOf(chart, lit);
	const [pending, setPending] = React.useState<string | undefined>(undefined);
	const [refused, setRefused] = React.useState<{ key: string; token: number }>({ key: "", token: 0 });

	const light = (starId: string) => {
		if (pending !== undefined) {
			return;
		}
		setPending(starId);
		const fallback = task.delay(8, () => setPending(undefined));
		props.dispatch("ConstellationAct", { Op: "Light", Star: starId }, (response) => {
			pcall(task.cancel, fallback);
			setPending(undefined);
			if (response.ok !== true) {
				setRefused((current) => ({ key: starId, token: current.token + 1 }));
			}
		});
	};
	const nextStar = status.next;
	const tabsY = HEAD_H + ROW_GAP;
	const bodyY = tabsY + layout.tabsH + GAP;
	const graphSize = layout.rowMode ? new UDim2(1, -(layout.sideW + GAP), 0, layout.bodyH) : new UDim2(1, 0, 0, GRAPH_H_COLUMN);
	const detailPos = layout.rowMode ? new UDim2(1, -layout.sideW, 0, bodyY) : UDim2.fromOffset(0, bodyY + GRAPH_H_COLUMN + GAP);
	const detailSize = layout.rowMode ? new UDim2(0, layout.sideW, 0, layout.bodyH) : new UDim2(1, 0, 0, layout.bodyH - GRAPH_H_COLUMN - GAP);
	return (
		<frame {...{ Name: "Constellations" }} BackgroundTransparency={1} BorderSizePixel={0} Size={UDim2.fromScale(1, 1)} ClipsDescendants={false}>
			<Eyebrow text={`${chart.Name} · ${status.count} of ${chart.Stars.size()} lit`} color={Palette.pink} position={UDim2.fromOffset(0, 4)} width={new UDim(0.6, 0)} />
			<Text
				value={paused ? "Charts closed" : `${points} star point${points === 1 ? "" : "s"}`}
				size={13}
				color={Palette.mango}
				weight={Enum.FontWeight.Bold}
				align={Enum.TextXAlignment.Right}
				position={new UDim2(0.6, 0, 0, 2)}
				sizeConstraint={new UDim2(0.4, 0, 0, 18)}
			/>
			<SegmentedTabs
				options={charts.map((c) => ({ id: c.Id, label: shortName(c), accent: statusOf(c, lit).done ? Palette.mango : Palette.pink }))}
				value={chart.Id}
				onChange={(id: string) => setSelectedId(id)}
				accent={Palette.pink}
				columns={layout.tabColumns}
				size={new UDim2(1, 0, 0, layout.tabsH)}
				position={UDim2.fromOffset(0, tabsY)}
				reducedMotion={props.reducedMotion}
			/>
			<frame BackgroundTransparency={1} BorderSizePixel={0} Position={UDim2.fromOffset(0, bodyY)} Size={graphSize}>
				<StarGraph chart={chart} status={status} reducedMotion={props.reducedMotion} />
			</frame>
			<frame BackgroundTransparency={1} BorderSizePixel={0} Position={detailPos} Size={detailSize}>
				<ChartDetail
					chart={chart}
					status={status}
					points={points}
					paused={paused}
					compact={layout.compact}
					pending={nextStar !== undefined && pending === nextStar.Id}
					shakeToken={nextStar !== undefined && refused.key === nextStar.Id ? refused.token : 0}
					onLight={() => nextStar !== undefined && light(nextStar.Id)}
					reducedMotion={props.reducedMotion}
				/>
			</frame>
		</frame>
	);
}

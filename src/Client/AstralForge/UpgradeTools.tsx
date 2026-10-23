import React from "@rbxts/react";
import { Palette, TapTarget } from "./CoreKit/theme";
import { amountPayload, compactNumber } from "./CoreKit/format";
import { Dict, OmegaMathApi } from "./lua";
import { BODY, Line, MockPanel, PanelHeading } from "./UiCore/mockKit";
import { MockRow, panelHeight } from "./pages/mockRows";
import createModel = require("./UpgradeModel");
import createQueue = require("./PurchaseQueue");

type Loose = (props: Dict) => React.Element | undefined;
interface UiKit {
	SearchField: Loose;
	Dropdown: Loose;
}

const ReplicatedStorage = game.GetService("ReplicatedStorage");
const Math = require(
	ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("OmegaMath") as ModuleScript,
) as OmegaMathApi;
const Model = createModel(Math);
const UiCore = require(script.Parent!.WaitForChild("UiCore") as ModuleScript) as (name: string) => unknown;
const ui = UiCore("ui") as UiKit;

type Entry = Parameters<typeof Model.plan>[0][number];

interface Batch {
	busy: boolean;
	status: string;
	count: number;
	remaining: unknown;
	start: () => boolean;
	buy: (id: unknown) => unknown;
}

function useBatch(
	dispatch: (action: unknown, payload: unknown, reply?: (response: unknown) => void) => unknown,
	action: unknown,
	entries: Entry[],
	amount: number,
	cash: unknown,
): Batch {
	const [, refresh] = React.useState(0);
	const queue = React.useMemo(
		() => createQueue(dispatch, task.delay, () => refresh((value) => value + 1)),
		[dispatch, action],
	);
	React.useEffect(() => () => queue.cancel(), [queue]);
	const [orders, remaining] = Model.plan(entries, amount, cash);
	// one buy() for the life of the queue: rows memoise on their own inputs, and a fresh closure
	// every render would make every row look changed. It reads the amount at click time, the
	// same value a closure from the latest render would have captured.
	const amountRef = React.useRef(amount);
	amountRef.current = amount;
	const buy = React.useCallback(
		(id: unknown) => {
			if (queue.busy) {
				return undefined;
			}
			return dispatch(action, { Id: id, Amount: amountPayload(amountRef.current) });
		},
		[queue, dispatch, action],
	);
	return {
		busy: queue.busy,
		status: queue.status,
		count: orders.size(),
		remaining,
		start: () => queue.start(action, orders),
		buy,
	};
}

interface ResearchControlsProps {
	stack?: boolean;
	query?: string;
	setQuery?: unknown;
	filter?: string;
	setFilter?: unknown;
	reducedMotion?: boolean;
	batch: Batch;
	count: number;
}

function controlsHeight(stack?: boolean): number {
	const phone = stack === true;
	return panelHeight(phone, (phone ? TapTarget * 2 + 8 : 36) + 8 + 16);
}

function batchLine(batch: Batch, count: number): string {
	if (batch.busy || batch.status !== "") {
		return batch.status;
	}
	return `${count} shown · next batch buys ${batch.count} ${batch.count === 1 ? "upgrade" : "upgrades"}`;
}

// .pn with the search field and filter on one line, status line under it
function ResearchControls(props: ResearchControlsProps) {
	const phone = props.stack === true;
	const fieldsH = phone ? TapTarget * 2 + 8 : 36;
	return (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={Palette.cyan} reducedMotion={props.reducedMotion} gap={8} name="ResearchControls">
			<frame BackgroundTransparency={1} BorderSizePixel={0} Size={new UDim2(1, 0, 0, fieldsH)} LayoutOrder={0} ZIndex={30}>
				<ui.SearchField
					value={props.query}
					onChange={props.setQuery}
					placeholder="Search research and bonuses"
					accent={Palette.cyan}
					reducedMotion={props.reducedMotion}
					position={UDim2.fromOffset(0, 0)}
					size={phone ? new UDim2(1, 0, 0, TapTarget) : new UDim2(1, -220, 0, 36)}
					zIndex={32}
				/>
				<ui.Dropdown
					options={[
						{ id: "Available", label: "Available" },
						{ id: "Affordable", label: "Can afford" },
						{ id: "Owned", label: "Owned" },
						{ id: "Next", label: "Coming up" },
						{ id: "All", label: "All research" },
					]}
					value={props.filter}
					onChange={props.setFilter}
					accent={Palette.cyan}
					reducedMotion={props.reducedMotion}
					position={phone ? UDim2.fromOffset(0, TapTarget + 8) : new UDim2(1, -208, 0, 0)}
					size={phone ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(208, 36)}
					zIndex={44}
				/>
			</frame>
			<Line text={batchLine(props.batch, props.count)} size={12} font={BODY} color={Palette.muted} width={new UDim(1, 0)} height={16} layoutOrder={1} />
		</MockPanel>
	);
}

interface PlannerProps {
	entries: Entry[];
	amount: number;
	cash: unknown;
	accent?: Color3;
	batch: Batch;
	phone?: boolean;
}

// 03-forge Output panel shape: heading, the best pick as a .row, batch line
function Planner(props: PlannerProps) {
	let best: Entry | undefined;
	for (const entry of props.entries) {
		if (
			Model.quote(entry, props.amount, props.cash).ready &&
			(best === undefined || Model.returnScore(entry) > Model.returnScore(best))
		) {
			best = entry;
		}
	}
	const phone = props.phone === true;
	const accent = props.accent ?? Palette.mango;
	const batchText =
		props.batch.busy || props.batch.status !== ""
			? props.batch.status
			: props.batch.count > 0
				? `${props.batch.count} ${props.batch.count === 1 ? "upgrade" : "upgrades"}, ${compactNumber(props.batch.remaining)} Flux left after`
				: "Nothing fits this amount. Try a smaller amount or collect your vault.";
	return (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={accent} name="Planner">
			<PanelHeading icon="Forge" title="Plan" note="Up to 24 per batch" accent={accent} phone={phone} layoutOrder={0} />
			<MockRow phone={phone} icon="Production" accent={accent} title="Best next level" sub={best ? best.config.Name : "Nothing ready"} layoutOrder={1} />
			<MockRow phone={phone} icon="Flux" accent={accent} title="Next batch" sub={batchText} layoutOrder={2} />
		</MockPanel>
	);
}

const Tools = { Model, useBatch, ResearchControls, Planner, controlsHeight };

export = Tools;

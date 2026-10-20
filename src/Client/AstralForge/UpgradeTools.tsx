import React from "@rbxts/react";
import { Palette, TapTarget } from "./CoreKit/theme";
import { amountPayload, compactNumber } from "./CoreKit/format";
import { Dict, OmegaMathApi } from "./lua";
import createModel = require("./UpgradeModel");
import createQueue = require("./PurchaseQueue");

type Loose = (props: Dict) => React.Element | undefined;
interface UiKit {
	Panel: Loose;
	SearchField: Loose;
	Dropdown: Loose;
	Text: Loose;
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

function ResearchControls(props: ResearchControlsProps) {
	const height = props.stack ? 164 : 96;
	return (
		<ui.Panel accent={Palette.cyan} size={UDim2.fromScale(1, 1)} clips={false}>
			<ui.SearchField
				value={props.query}
				onChange={props.setQuery}
				placeholder="Search research and bonuses"
				accent={Palette.cyan}
				reducedMotion={props.reducedMotion}
				position={UDim2.fromOffset(0, 0)}
				size={props.stack ? new UDim2(1, 0, 0, TapTarget) : new UDim2(1, -220, 0, 36)}
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
				position={props.stack ? UDim2.fromOffset(0, TapTarget + 8) : new UDim2(1, -208, 0, 0)}
				size={props.stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(208, 36)}
				zIndex={44}
			/>
			<ui.Text
				value={
					props.batch.busy || props.batch.status !== ""
						? props.batch.status
						: `${props.count} shown · next batch buys ${props.batch.count} ${props.batch.count === 1 ? "upgrade" : "upgrades"}`
				}
				size={11}
				color={Palette.creamSoft}
				fit={true}
				position={UDim2.fromOffset(0, props.stack ? height - 44 : 46)}
				sizeConstraint={new UDim2(1, 0, 0, 20)}
			/>
		</ui.Panel>
	);
}

interface PlannerProps {
	entries: Entry[];
	amount: number;
	cash: unknown;
	accent?: Color3;
	batch: Batch;
}

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
	return (
		<ui.Panel accent={props.accent} size={UDim2.fromScale(1, 1)}>
			<ui.Text
				value={best ? `BEST NEXT-LEVEL RETURN · ${best.config.Name}` : "PLAN YOUR NEXT PURCHASE"}
				size={13}
				weight={Enum.FontWeight.Heavy}
				color={Palette.cream}
				fit={true}
				sizeConstraint={new UDim2(1, 0, 0, 24)}
			/>
			<ui.Text
				value={
					props.batch.busy || props.batch.status !== ""
						? props.batch.status
						: props.batch.count > 0
							? `Next batch: ${props.batch.count} ${props.batch.count === 1 ? "upgrade" : "upgrades"}, ${compactNumber(props.batch.remaining)} Flux left after`
							: "No upgrades fit your selected amount. Try a smaller amount or collect your vault."
				}
				size={12}
				color={Palette.creamSoft}
				wrap={true}
				fit={true}
				minSize={10}
				position={UDim2.fromOffset(0, 30)}
				sizeConstraint={new UDim2(1, 0, 0, 34)}
			/>
			<ui.Text
				value="A batch buys up to 24 upgrades. On Max, your Flux is split between them, 50 levels at most each."
				size={10}
				color={Palette.muted}
				wrap={true}
				fit={true}
				minSize={10}
				position={UDim2.fromOffset(0, 70)}
				sizeConstraint={new UDim2(1, 0, 0, 28)}
			/>
		</ui.Panel>
	);
}

const Tools = { Model, useBatch, ResearchControls, Planner };

export = Tools;

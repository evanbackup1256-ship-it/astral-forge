import React from "@rbxts/react";
import { Dict, OmegaMathApi, OmegaValue, named } from "./lua";
import createModel = require("./PlanningModel");
import * as theme from "./CoreKit/theme";
import { compactNumber as compact } from "./CoreKit/format";
import * as GamepadNavigationService from "./CoreKit/GamepadNavigationService";
import { useViewport, MotionSettingsContext } from "./MotionKit/motion";

const P = theme.Palette;

type Loose = (props: Dict) => React.Element | undefined;

const DescribeGenerated = require(
	game.GetService("ReplicatedStorage").WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("DescribeGenerated") as ModuleScript,
) as {
	milestoneName(this: void, tier: number): string;
};

interface UiKit {
	Panel: Loose;
	Text: Loose;
	Button: Loose;
	Meter: Loose;
}

interface Section {
	id: string;
	height: number;
	element: React.Element;
}

interface PageScaffoldProps {
	sections: Section[];
	gap?: number;
	tailPad?: number;
	scrollBarColor?: Color3;
	scrollBarThickness?: number;
}

interface NextRankPlan {
	rank: number;
	nextRank: number;
	capped: boolean;
	ready: boolean;
	flux: OmegaValue;
	dust: OmegaValue;
	fluxProgress: number;
	dustProgress: number;
	milestone: boolean;
	milestoneRank: number;
	production: number;
	capacity: number;
	tap: number;
	offline: number;
}

interface ChannelDefinition {
	Name: string;
	Description: string;
	Color: Color3;
	[key: string]: unknown;
}

interface ChannelEntry {
	id: string;
	definition: ChannelDefinition;
}

interface Job {
	Id: string;
	Name?: unknown;
	Description?: unknown;
	Kind?: unknown;
	Color?: unknown;
	Progress?: unknown;
	Target?: unknown;
	[key: string]: unknown;
}

interface Milestone {
	Tier: number;
	Required: number;
	[key: string]: unknown;
}

interface ProtocolDefinition {
	Id: string;
	BaseCost: unknown;
	CostScale: unknown;
	MaxLevel?: number;
	[key: string]: unknown;
}

interface Protocol {
	definition: ProtocolDefinition & { Name: string; Description: string; Color: Color3 };
	level: number;
	cost: OmegaValue;
	capped: boolean;
	ready: boolean;
}

interface ShiftPlan {
	charge: number;
	jobs: Job[];
	milestones: Milestone[];
	protocols: Protocol[];
	title?: string;
	body?: unknown;
	action?: string;
	payload?: Dict;
}

interface AnomalyState {
	Loadout?: string[];
	Channel?: string;
	LoadoutSlots?: number;
	Protocols?: Record<string, number>;
	Fragments?: unknown;
	Charge?: unknown;
	Target?: unknown;
	Directives?: Job[];
	Milestones?: Milestone[];
	Ready?: unknown;
	Stabilizations?: number;
	[key: string]: unknown;
}

interface Reply {
	ok?: boolean;
	message?: string;
	error?: string;
}

interface Guard {
	busy: boolean;
	generation: number;
	alive: boolean;
}

interface PlanProps {
	state: Dict;
	config: Dict;
	dispatch: (action: string, payload: Record<string, unknown>, finish?: (reply?: Reply) => void) => void;
	navigate?: (page: string) => void;
	reducedMotion?: boolean;
}

const ReplicatedStorage = game.GetService("ReplicatedStorage");
const Math = require(
	ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("OmegaMath") as ModuleScript,
) as OmegaMathApi;
const Model = createModel(Math);

const UiCore = require(script.Parent!.WaitForChild("UiCore") as ModuleScript) as (name: string) => unknown;
const ui = UiCore("ui") as UiKit;

const LayoutKit = require(script.Parent!.WaitForChild("LayoutKit") as ModuleScript) as (name: string) => unknown;
const { PageScaffold } = LayoutKit("pageScaffold") as { PageScaffold: React.FunctionComponent<PageScaffoldProps> };

// A ref closes the same-frame double-submit window; generations ignore late replies.
function useAction(
	dispatch: PlanProps["dispatch"],
): LuaTuple<[boolean, string, (action: string, payload?: Record<string, unknown>) => void, (status: string) => void]> {
	const [busy, setBusy] = React.useState(false);
	const [status, setStatus] = React.useState("");
	const guard = React.useRef<Guard>({ busy: false, generation: 0, alive: true });
	React.useEffect(() => {
		guard.current.alive = true;
		return () => {
			guard.current.alive = false;
			guard.current.generation += 1;
		};
	}, []);
	function run(action: string, payload?: Record<string, unknown>) {
		const latch = guard.current;
		if (latch.busy || !latch.alive) return;
		latch.busy = true;
		latch.generation += 1;
		const generation = latch.generation;
		setBusy(true);
		setStatus("Working…");
		function finish(reply?: Reply) {
			if (!latch.alive || latch.generation !== generation || !latch.busy) return;
			latch.busy = false;
			setBusy(false);
			setStatus(
				reply && reply.ok
					? (reply.message ?? "Done.")
					: (reply && (reply.error ?? reply.message)) || "No response. Try again.",
			);
		}
		task.delay(12, () => finish());
		const [ok, problem] = pcall(dispatch, action, payload ?? {}, finish);
		if (!ok) finish({ ok: false, message: tostring(problem) });
	}
	return $tuple(busy, status, run, setStatus);
}

function copy(value: unknown, y: number, height: number, size = 14, color: Color3 = P.creamSoft, heavy = false) {
	return (
		<ui.Text
			value={value}
			position={UDim2.fromOffset(0, y)}
			sizeConstraint={new UDim2(1, 0, 0, height)}
			size={size}
			color={color}
			wrap={true}
			fit={heavy}
			minSize={14}
			weight={heavy ? Enum.FontWeight.Heavy : Enum.FontWeight.Medium}
		/>
	);
}

function panel(accent: Color3, children: React.ReactNode) {
	return (
		<ui.Panel size={UDim2.fromScale(1, 1)} accent={accent} padding={16} background={P.panelRaised} clips={true}>
			{children}
		</ui.Panel>
	);
}

function button(text: unknown, y: number, action: () => void, disabled: boolean, accent?: Color3) {
	return (
		<ui.Button
			text={text}
			position={UDim2.fromOffset(0, y)}
			size={new UDim2(1, 0, 0, 48)}
			onClick={action}
			disabled={disabled}
			color={accent ?? P.cyan}
			highlight={!disabled}
		/>
	);
}

function section(id: string, height: number, element: React.Element): Section {
	return { id, height, element };
}

function meter(value: number, y: number, accent: Color3) {
	return (
		<ui.Meter
			value={value}
			position={UDim2.fromOffset(0, y)}
			size={new UDim2(1, 0, 0, 10)}
			color={accent}
			reducedMotion={true}
		/>
	);
}

function pairedSections(sections: Section[], viewport: theme.ChromeViewport): Section[] {
	if (viewport.width < 760) return sections;
	const result = new Array<Section>();
	let index = 0;
	while (index < sections.size()) {
		const first = sections[index];
		const second = sections[index + 1];
		const pair =
			second !== undefined &&
			((first.id === "rank-costs" && second.id === "rank-benefits") ||
				(first.id.sub(1, 10) === "directive-" && second.id.sub(1, 10) === "directive-") ||
				(first.id.sub(1, 9) === "protocol-" && second.id.sub(1, 9) === "protocol-"));
		if (pair) {
			const height = math.max(first.height, second.height);
			const children = new Array<React.Element>();
			for (const [column, item] of ipairs([first, second])) {
				children.push(
					<frame
						Size={new UDim2(0.5, -6, 1, 0)}
						Position={new UDim2((column - 1) * 0.5, column === 1 ? 0 : 6, 0, 0)}
						BackgroundTransparency={1}
					>
						{item.element}
					</frame>,
				);
			}
			result.push(
				section(
					`${first.id}-pair`,
					height,
					<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
						{children}
					</frame>,
				),
			);
			index += 2;
		} else {
			result.push(first);
			index += 1;
		}
	}
	return result;
}

function scaffold(sections: Section[], viewport: theme.ChromeViewport, props: PlanProps, name: string) {
	const chrome = theme.chromeFor(viewport);
	sections = pairedSections(sections, viewport);
	const reducedMotion = props.reducedMotion;
	const inheritedMotion = React.useContext(MotionSettingsContext);
	const softMotion = reducedMotion === true || inheritedMotion.soft === true;
	const motion = table.clone(inheritedMotion);
	motion.soft = softMotion;
	const root = React.useRef<Frame | undefined>(undefined);
	React.useEffect(() => {
		const job = task.delay(0.15, () => {
			if (root.current && GamepadNavigationService.IsConsole()) {
				GamepadNavigationService.FocusClaim(root.current);
			}
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, []);
	return (
		<frame {...named(name)} ref={root} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ClipsDescendants={false}>
			<MotionSettingsContext.Provider value={motion}>
				<PageScaffold
					sections={sections}
					gap={12}
					tailPad={theme.scrollTail(chrome.stack, chrome.bottomSafe, 40)}
					scrollBarColor={P.cyan}
					scrollBarThickness={4}
				/>
			</MotionSettingsContext.Provider>
		</frame>
	);
}

function NextPlan(props: PlanProps) {
	const viewport = useViewport();
	const { state, config } = props;
	const rank = (state.Continuum as Record<string, unknown> | undefined) ?? {};
	const plan = Model.nextRank(state, config) as NextRankPlan;
	const [busy, status, run] = useAction(props.dispatch);
	function navigate(page: string) {
		if (props.navigate) props.navigate(page);
	}
	const missing = plan.capped
		? "Your Continuum rank is at its current limit."
		: plan.ready
		? "You can afford it. Ranking up raises permanent bonuses and keeps your machines."
		: `Still needed: ${compact(plan.flux)} Flux + ${compact(plan.dust)} Stardust.`;
	const sections = new Array<Section>();
	sections.push(
		section(
			"next-plan",
			232,
			panel(P.pink, [
				copy("Continuum · permanent", 0, 22, 12, P.pink, true),
				copy(`Continuum ${plan.rank} → ${plan.nextRank}`, 30, 38, 24, P.cream, true),
				copy(missing, 78, 66, 14),
				button(
					busy ? "UPGRADING…" : plan.capped ? "RANK LIMIT" : "RAISE RANK",
					152,
					() => run("UpgradeContinuum", {}),
					busy || !plan.ready,
					P.pink,
				),
			]),
		),
	);
	sections.push(
		section(
			"rank-costs",
			218,
			panel(P.cyan, [
				copy("Cost", 0, 24, 13, P.cyan, true),
				copy(`Flux · ${compact(state.Cash)} / ${compact(rank.FluxCost ?? 0)}`, 34, 32, 14),
				meter(plan.fluxProgress, 72, P.cyan),
				copy(`Stardust · ${compact(state.Stardust)} / ${compact(rank.StardustCost ?? 0)}`, 96, 32, 14),
				meter(plan.dustProgress, 136, P.pink),
				copy(
					plan.milestone
						? "Next rank includes the milestone production bonus."
						: `Production milestone: rank ${plan.milestoneRank}.`,
					154,
					32,
					12,
					P.muted,
				),
			]),
		),
	);
	sections.push(
		section(
			"rank-benefits",
			246,
			panel(P.mint, [
				copy("Next rank", 0, 24, 13, P.mint, true),
				copy(
					`Production · ${compact(rank.ProductionMultiplier ?? 1)}× → ${compact(
						Math.Mul((rank.ProductionMultiplier as OmegaValue | undefined) ?? 1, plan.production),
					)}×`,
					34,
					36,
				),
				copy(
					`Vault capacity · ${compact(rank.CapacityMultiplier ?? 1)}× → ${compact(
						Math.Mul((rank.CapacityMultiplier as OmegaValue | undefined) ?? 1, plan.capacity),
					)}×`,
					76,
					36,
				),
				copy(
					`Strike power · ${compact(rank.TapMultiplier ?? 1)}× → ${compact(
						Math.Mul((rank.TapMultiplier as OmegaValue | undefined) ?? 1, plan.tap),
					)}×`,
					118,
					36,
				),
				copy(
					`${string.format("%.2f", ((rank.OfflineBonus as number | undefined) ?? 0) * 100)}% → ${string.format(
						"%.2f",
						plan.offline * 100,
					)}%`,
					160,
					36,
				),
			]),
		),
	);
	// only when something is short: where to get it
	if (!plan.ready && !plan.capped) {
		sections.push(
			section(
				"rank-route",
				254,
				panel(P.mango, [
					copy("Short on flux or stardust?", 0, 24, 13, P.mango, true),
					copy(status !== "" ? status : "Rewards, banked reactor shifts and better machines all bring more in.", 32, 64, 14),
					button("Open reactor", 106, () => navigate("Anomaly"), false, P.pink),
					button("Open workshop", 166, () => navigate("Workshop"), false, P.cyan),
				]),
			),
		);
	}
	return scaffold(sections, viewport, props, "ContinuumClaimActions");
}

function ShiftPlan(props: PlanProps) {
	const viewport = useViewport();
	const { state, config } = props;
	const anomaly = (state.Anomaly as Record<string, unknown> | undefined) ?? {};
	const plan = Model.shift(state, config) as ShiftPlan;
	const [busy, status, run, setStatus] = useAction(props.dispatch);
	const [pane, setPane] = React.useState("Directives");
	const sections = new Array<Section>();
	sections.push(
		section(
			"shift-next",
			240,
			panel(P.pink, [
				copy("Reactor · next step", 0, 22, 12, P.pink, true),
				copy(plan.title ?? "", 30, 58, 23, P.cream, true),
				copy(status !== "" ? status : ((plan.body as string | undefined) ?? ""), 96, 58, 14),
				button(
					busy ? "WORKING…" : plan.action === "PulseAnomaly" ? "PULSE CHARGE" : "COLLECT REWARD",
					160,
					() => run(plan.action ?? "", plan.payload ?? {}),
					busy,
					P.pink,
				),
			]),
		),
	);
	sections.push(
		section(
			"shift-meter",
			238,
			panel(P.mint, [
				copy(`Charge · ${math.floor(plan.charge * 100)}%`, 0, 24, 14, P.mint, true),
				meter(plan.charge, 34, P.pink),
				copy(
					`${compact(anomaly.Charge as OmegaValue | undefined ?? 0)} / ${compact(
						anomaly.Target as OmegaValue | undefined ?? 0,
					)} · Combo ${(anomaly.Combo as number | undefined) ?? 0} / ${(anomaly.ComboMax as number | undefined) ?? 20}`,
					56,
					42,
				),
				copy(
					`${compact(anomaly.Fragments as OmegaValue | undefined ?? 0)} fragments · ${(anomaly.Stabilizations as number | undefined) ??
						0} stabilized · core tier ${(anomaly.CoreTier as number | undefined) ?? 1}`,
					106,
					42,
				),
				button(
					"STABILIZE",
					158,
					() => run("StabilizeAnomaly", {}),
					busy || !(anomaly.Ready as boolean | undefined),
					P.mint,
				),
			]),
		),
	);
	const compactTabs = viewport.width < 760;
	const tabs: React.Element[] = [];
	tabs.push(copy("Reactor", 0, 24, 13, P.cyan, true));
	for (const [index, id] of ipairs(["Directives", "Loadout", "Milestones", "Protocols"])) {
		const columns = compactTabs ? 2 : 4;
		const column = (index - 1) % columns;
		const row = math.floor((index - 1) / columns);
		tabs.push(
			<ui.Button
				text={id}
				size={new UDim2(1 / columns, -6, 0, 48)}
				position={new UDim2(column / columns, column === 0 ? 0 : 6, 0, 34 + row * 56)}
				color={pane === id ? P.cyan : P.panelSoft}
				textColor={pane === id ? P.ink : P.cream}
				onClick={() => setPane(id)}
			/>,
		);
	}
	sections.push(section("shift-workbench", compactTabs ? 174 : 118, panel(P.cyan, tabs)));
	const channels = new Array<ChannelEntry>();
	const channelsConfig = ((config.Anomalies as Record<string, unknown> | undefined)?.Channels as
		| Record<string, ChannelDefinition>
		| undefined) ?? {};
	for (const [id, definition] of pairs(channelsConfig)) {
		channels.push({ id: id as string, definition });
	}
	channels.sort((a, b) => a.definition.Name < b.definition.Name);
	const equipped = new Set<string>();
	for (const id of (anomaly.Loadout as string[] | undefined) ?? [anomaly.Channel as string | undefined ?? "Strike"]) {
		equipped.add(id);
	}
	const used = equipped.size();
	const channelChildren: React.Element[] = [];
	channelChildren.push(
		copy(`CHANNEL LOADOUT · ${used} / ${(anomaly.LoadoutSlots as number | undefined) ?? 1} slots`, 0, 26, 13, P.cyan, true),
	);
	channelChildren.push(
		copy("Mix boosts for your current goal. Unequip one to make room; at least one stays active.", 34, 58, 14),
	);
	for (const [index, channel] of ipairs(channels)) {
		const y = 102 + (index - 1) * 124;
		channelChildren.push(
			button(
				`${equipped.has(channel.id) ? "UNEQUIP · " : "EQUIP · "}${channel.definition.Name}`,
				y,
				() => {
					const [loadout, problem] = Model.toggleLoadout(anomaly as AnomalyState, channel.id);
					if (loadout) {
						run("SetAnomalyLoadout", { Loadout: loadout });
					} else {
						setStatus(problem ?? "");
					}
				},
				busy || (!equipped.has(channel.id) && used >= ((anomaly.LoadoutSlots as number | undefined) ?? 1)),
				channel.definition.Color,
			),
		);
		channelChildren.push(copy(channel.definition.Description, y + 56, 46, 13, P.muted));
	}
	if (pane === "Loadout") {
		sections.push(section("shift-loadout", 134 + channels.size() * 124, panel(P.cyan, channelChildren)));
	}
	for (const [_, job] of ipairs(plan.jobs)) {
		if (pane !== "Directives") break;
		const progress = Model.ratio(job.Progress, job.Target);
		sections.push(
			section(
				`directive-${job.Id}`,
				254,
				panel((job.Color as Color3 | undefined) ?? P.mango, [
					copy("Daily task", 0, 20, 11, P.mango, true),
					copy(job.Name as string, 26, 42, 19, P.cream, true),
					copy((job.Description as string | undefined) ?? (job.Kind as string | undefined) ?? "", 74, 56, 14),
					meter(progress, 136, (job.Color as Color3 | undefined) ?? P.mango),
					copy(`${compact(job.Progress)} / ${compact(job.Target)} · ${math.floor(progress * 100)}%`, 152, 22, 12),
					button(
						progress >= 1 ? "CLAIM TASK" : "NOT YET",
						184,
						() => run("ClaimAnomalyDirective", { Id: job.Id }),
						busy || progress < 1,
						(job.Color as Color3 | undefined) ?? P.mango,
					),
				]),
			),
		);
	}
	for (const [index, milestone] of ipairs(plan.milestones)) {
		if (pane !== "Milestones") break;
		if (index > 3) break;
		const ready = ((anomaly.Stabilizations as number | undefined) ?? 0) >= milestone.Required;
		sections.push(
			section(
				`milestone-${milestone.Tier}`,
				172,
				panel(P.mint, [
					copy(`Tier ${milestone.Tier} · ${DescribeGenerated.milestoneName(milestone.Tier)}`, 0, 26, 13, P.mint, true),
					copy(`${(anomaly.Stabilizations as number | undefined) ?? 0} / ${milestone.Required} stabilizations`, 34, 36, 14),
					meter(Model.ratio(anomaly.Stabilizations, milestone.Required), 80, P.mint),
					button(
						ready ? "CLAIM MILESTONE" : "KEEP STABILIZING",
						104,
						() => run("ClaimAnomalyMilestone", { Tier: milestone.Tier }),
						busy || !ready,
						P.mint,
					),
				]),
			),
		);
	}
	for (const protocol of plan.protocols) {
		if (pane !== "Protocols") break;
		const definition = protocol.definition as ProtocolDefinition & { Name: string; Description: string; Color: Color3 };
		sections.push(
			section(
				`protocol-${definition.Id}`,
				218,
				panel(definition.Color, [
					copy(`${definition.Name} · Lv ${compact(protocol.level)}`, 0, 42, 18, P.cream, true),
					copy(definition.Description, 50, 54, 14),
					copy(
						protocol.capped
							? "Maximum level reached."
							: `Next level: ${compact(protocol.cost)} fragments`,
						110,
						32,
						13,
						P.muted,
					),
					button(
						protocol.capped ? "MAXED" : "BUY NEXT LEVEL",
						150,
						() => run("BuyAnomalyProtocol", { Id: definition.Id }),
						busy || !protocol.ready,
						definition.Color,
					),
				]),
			),
		);
	}
	if (pane === "Directives" && plan.jobs.size() === 0) {
		sections.push(
			section(
				"directives-complete",
				110,
				panel(P.mint, [
					copy("All of today's tasks are done", 0, 34, 20, P.cream, true),
					copy("New tasks arrive tomorrow. Keep charging the reactor until then.", 42, 42, 14),
				]),
			),
		);
	}
	return scaffold(sections, viewport, props, "AnomalyClaimActions");
}

const Views = { NextPlan, ShiftPlan };

export = Views;

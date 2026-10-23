import React from "@rbxts/react";
import { isGamepadInput, lastInputIsGamepad } from "./CoreKit/inputLayer";
import { Dict, OmegaMathApi, OmegaValue, named } from "./lua";
import createModel = require("./PlanningModel");
import * as theme from "./CoreKit/theme";
import { compactNumber as compact } from "./CoreKit/format";
import * as GamepadNavigationService from "./CoreKit/GamepadNavigationService";
import { useViewport, MotionSettingsContext } from "./MotionKit/motion";
import { Bar, BODY, MockPanel, PanelHeading } from "./UiCore/mockKit";
import { Grid, headingBlock, MockBtn, MockRow, panelHeight, rowHeight } from "./pages/mockRows";

const P = theme.Palette;
const TapTarget = theme.TapTarget;


const DescribeGenerated = require(
	game.GetService("ReplicatedStorage").WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("DescribeGenerated") as ModuleScript,
) as {
	milestoneName(this: void, tier: number): string;
};


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

// 03-forge pattern: each section is a .pn (heading, .row lines, thin bar, button); heights come
// from the pieces so the scaffold never clips. `phone` is set at the top of each view's render.
let phone = false;
type Piece = [(order: number) => React.Element, number];

function row(title: string, sub?: string, value?: string, icon?: string, accent?: Color3): Piece {
	return [
		(order) => <MockRow phone={phone} title={title} sub={sub} value={value} icon={icon} accent={accent} layoutOrder={order} />,
		rowHeight(phone, sub !== undefined),
	];
}

function para(text: string, color: Color3 = P.creamSoft): Piece {
	const height = phone ? 34 : 40;
	return [
		(order) => (
			<textlabel
				BackgroundTransparency={1}
				Text={text}
				TextSize={phone ? 13 : 15}
				FontFace={BODY}
				TextColor3={color}
				TextWrapped={true}
				TextXAlignment={Enum.TextXAlignment.Left}
				TextYAlignment={Enum.TextYAlignment.Top}
				Size={new UDim2(1, 0, 0, height)}
				LayoutOrder={order}
			/>
		),
		height,
	];
}

function bar(value: number, accent: Color3): Piece {
	return [(order) => <Bar fill={value} color={accent} thin={true} layoutOrder={order} />, 6];
}

function button(text: string, action: () => void, disabled: boolean, accent?: Color3, sec?: boolean): Piece {
	return [
		(order) => <MockBtn text={text} onClick={action} disabled={disabled} accent={accent ?? P.cyan} sec={sec} fill={true} phone={phone} layoutOrder={order} />,
		phone ? TapTarget : 44,
	];
}

function pn(id: string, accent: Color3, icon: string, title: string, note: string | undefined, pieces: Piece[]): Section {
	const gap = phone ? 8 : 12;
	let content = headingBlock(phone);
	for (const [index, piece] of ipairs(pieces)) {
		content += piece[1] + (index > 1 ? gap : 0);
	}
	return section(
		id,
		panelHeight(phone, content),
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={accent}>
			<PanelHeading icon={icon} title={title} note={note} accent={accent} phone={phone} layoutOrder={0} />
			{pieces.map((piece, index) => piece[0](index + 1))}
		</MockPanel>,
	);
}

function section(id: string, height: number, element: React.Element): Section {
	return { id, height, element };
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
						Size={new UDim2(0.5, -9, 1, 0)}
						Position={new UDim2((column - 1) * 0.5, column === 1 ? 0 : 9, 0, 0)}
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
		// any platform: claim first focus when a pad was the last input, and again when the player
		// picks one up while nothing is selected
		const job = task.delay(0.15, () => {
			if (root.current && lastInputIsGamepad()) {
				GamepadNavigationService.FocusClaim(root.current);
			}
		});
		const switched = game.GetService("UserInputService").LastInputTypeChanged.Connect((inputType) => {
			if (root.current && isGamepadInput(inputType) && game.GetService("GuiService").SelectedObject === undefined) {
				GamepadNavigationService.FocusClaim(root.current);
			}
		});
		return () => {
			pcall(task.cancel, job);
			switched.Disconnect();
		};
	}, []);
	return (
		<frame {...named(name)} ref={root} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ClipsDescendants={false}>
			<MotionSettingsContext.Provider value={motion}>
				<PageScaffold
					sections={sections}
					gap={phone ? 8 : 18}
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
	phone = theme.chromeFor(viewport).stack === true;
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
	const fluxNeed = rank.FluxCost ?? 0;
	const dustNeed = rank.StardustCost ?? 0;
	const mult = (key: string, factor: unknown) =>
		`${compact(rank[key] ?? 1)}x to ${compact(Math.Mul((rank[key] as OmegaValue | undefined) ?? 1, factor as OmegaValue))}x`;
	const sections = new Array<Section>();
	sections.push(
		pn("next-plan", P.pink, "Continuum", `Continuum ${plan.rank} to ${plan.nextRank}`, plan.ready ? "Ready" : undefined, [
			para(missing),
			button(busy ? "Upgrading…" : plan.capped ? "Rank limit" : "Raise rank", () => run("UpgradeContinuum", {}), busy || !plan.ready, P.pink),
		]),
	);
	sections.push(
		pn("rank-costs", P.cyan, "Flux", "Cost", undefined, [
			row("Flux", undefined, `${compact(state.Cash)} / ${compact(fluxNeed)}`, "Flux", P.cyan),
			bar(plan.fluxProgress, P.cyan),
			row("Stardust", undefined, `${compact(state.Stardust)} / ${compact(dustNeed)}`, "Dust", P.pink),
			bar(plan.dustProgress, P.pink),
			para(plan.milestone ? "Next rank includes the milestone production bonus." : `Production milestone: rank ${plan.milestoneRank}.`, P.muted),
		]),
	);
	sections.push(
		pn("rank-benefits", P.mint, "Production", "Next rank", undefined, [
			row("Production", undefined, mult("ProductionMultiplier", plan.production), "Production", P.mint),
			row("Vault capacity", undefined, mult("CapacityMultiplier", plan.capacity), "Vault", P.mint),
			row("Strike power", undefined, mult("TapMultiplier", plan.tap), "Overcharge", P.mint),
			row(
				"Offline",
				undefined,
				`${string.format("%.2f", ((rank.OfflineBonus as number | undefined) ?? 0) * 100)}% to ${string.format("%.2f", plan.offline * 100)}%`,
				"Timer",
				P.mint,
			),
		]),
	);
	// only when something is short: where to get it
	if (!plan.ready && !plan.capped) {
		sections.push(
			pn("rank-route", P.mango, "Info", "Short on flux or stardust?", undefined, [
				para(status !== "" ? status : "Rewards, banked reactor shifts and better machines all bring more in."),
				button("Open reactor", () => navigate("Anomaly"), false, P.pink),
				button("Open workshop", () => navigate("Workshop"), false, P.cyan, true),
			]),
		);
	}
	return scaffold(sections, viewport, props, "ContinuumClaimActions");
}

function ShiftPlan(props: PlanProps) {
	const viewport = useViewport();
	phone = theme.chromeFor(viewport).stack === true;
	const { state, config } = props;
	const anomaly = (state.Anomaly as Record<string, unknown> | undefined) ?? {};
	const plan = Model.shift(state, config) as ShiftPlan;
	const [busy, status, run, setStatus] = useAction(props.dispatch);
	const [pane, setPane] = React.useState("Directives");
	const sections = new Array<Section>();
	sections.push(
		pn("shift-next", P.pink, "Anomaly", "Next step", undefined, [
			row(plan.title ?? "", undefined, undefined, "Anomaly", P.pink),
			para(status !== "" ? status : ((plan.body as string | undefined) ?? "")),
			button(
				busy ? "Working…" : plan.action === "PulseAnomaly" ? "Pulse charge" : "Collect reward",
				() => run(plan.action ?? "", plan.payload ?? {}),
				busy,
				P.pink,
			),
		]),
	);
	sections.push(
		pn("shift-meter", P.mint, "Anomaly", "Charge", `${math.floor(plan.charge * 100)}%`, [
			bar(plan.charge, P.pink),
			row(
				"Charge",
				`Combo ${(anomaly.Combo as number | undefined) ?? 0} / ${(anomaly.ComboMax as number | undefined) ?? 20}`,
				`${compact((anomaly.Charge as OmegaValue | undefined) ?? 0)} / ${compact((anomaly.Target as OmegaValue | undefined) ?? 0)}`,
				"Reactor",
				P.mint,
			),
			row(
				"Fragments",
				`${(anomaly.Stabilizations as number | undefined) ?? 0} stabilized · core tier ${(anomaly.CoreTier as number | undefined) ?? 1}`,
				compact((anomaly.Fragments as OmegaValue | undefined) ?? 0),
				"Core",
				P.mint,
			),
			button("Stabilize", () => run("StabilizeAnomaly", {}), busy || !(anomaly.Ready as boolean | undefined), P.mint),
		]),
	);
	const compactTabs = viewport.width < 760;
	const tabColumns = compactTabs ? 2 : 4;
	const tabH = phone ? TapTarget : 36;
	const tabIds = ["Directives", "Loadout", "Milestones", "Protocols"];
	sections.push(
		pn("shift-workbench", P.cyan, "Anomaly", "Reactor", undefined, [
			[
				(order) => (
					<Grid columns={tabColumns} gap={8} cellHeight={tabH} count={tabIds.size()} layoutOrder={order}>
						{tabIds.map((id, index) => (
							<MockBtn text={id} sm={true} fill={true} phone={phone} sec={pane !== id} accent={P.cyan} onClick={() => setPane(id)} layoutOrder={index} />
						))}
					</Grid>
				),
				math.ceil(tabIds.size() / tabColumns) * tabH + (math.ceil(tabIds.size() / tabColumns) - 1) * 8,
			],
		]),
	);
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
	const slots = (anomaly.LoadoutSlots as number | undefined) ?? 1;
	if (pane === "Loadout") {
		const pieces: Piece[] = [para("Mix boosts for your current goal. Unequip one to make room; at least one stays active.")];
		const btnW = phone ? 110 : 140;
		for (const channel of channels) {
			const on = equipped.has(channel.id);
			pieces.push([
				(order) => (
					<MockRow
						phone={phone}
						title={channel.definition.Name}
						sub={channel.definition.Description}
						icon="Anomaly"
						accent={channel.definition.Color}
						outline={on ? channel.definition.Color : undefined}
						rightWidth={btnW}
						right={
							<MockBtn
								text={on ? "Unequip" : "Equip"}
								sm={true}
								width={btnW}
								sec={on}
								accent={channel.definition.Color}
								disabled={busy || (!on && used >= slots)}
								onClick={() => {
									const [loadout, problem] = Model.toggleLoadout(anomaly as AnomalyState, channel.id);
									if (loadout) {
										run("SetAnomalyLoadout", { Loadout: loadout });
									} else {
										setStatus(problem ?? "");
									}
								}}
							/>
						}
						layoutOrder={order}
					/>
				),
				rowHeight(phone, true),
			]);
		}
		sections.push(pn("shift-loadout", P.cyan, "Anomaly", "Channel loadout", `${used} / ${slots} slots`, pieces));
	}
	for (const [_, job] of ipairs(plan.jobs)) {
		if (pane !== "Directives") break;
		const progress = Model.ratio(job.Progress, job.Target);
		const accent = (job.Color as Color3 | undefined) ?? P.mango;
		sections.push(
			pn(`directive-${job.Id}`, accent, "Mission", job.Name as string, "Daily task", [
				para((job.Description as string | undefined) ?? (job.Kind as string | undefined) ?? ""),
				row("Progress", undefined, `${compact(job.Progress)} / ${compact(job.Target)}`, "Mission", accent),
				bar(progress, accent),
				button(progress >= 1 ? "Claim task" : "Not yet", () => run("ClaimAnomalyDirective", { Id: job.Id }), busy || progress < 1, accent),
			]),
		);
	}
	for (const [index, milestone] of ipairs(plan.milestones)) {
		if (pane !== "Milestones") break;
		if (index > 3) break;
		const done = (anomaly.Stabilizations as number | undefined) ?? 0;
		const ready = done >= milestone.Required;
		sections.push(
			pn(`milestone-${milestone.Tier}`, P.mint, "Milestone", `Tier ${milestone.Tier} · ${DescribeGenerated.milestoneName(milestone.Tier)}`, undefined, [
				row("Stabilizations", undefined, `${done} / ${milestone.Required}`, "Milestone", P.mint),
				bar(Model.ratio(anomaly.Stabilizations, milestone.Required), P.mint),
				button(ready ? "Claim milestone" : "Keep stabilizing", () => run("ClaimAnomalyMilestone", { Tier: milestone.Tier }), busy || !ready, P.mint),
			]),
		);
	}
	for (const protocol of plan.protocols) {
		if (pane !== "Protocols") break;
		const definition = protocol.definition as ProtocolDefinition & { Name: string; Description: string; Color: Color3 };
		sections.push(
			pn(`protocol-${definition.Id}`, definition.Color, "Command", definition.Name, `Lv ${compact(protocol.level)}`, [
				para(definition.Description),
				row("Next level", undefined, protocol.capped ? "Max" : `${compact(protocol.cost)} fragments`, "Core", definition.Color),
				button(protocol.capped ? "Maxed" : "Buy next level", () => run("BuyAnomalyProtocol", { Id: definition.Id }), busy || !protocol.ready, definition.Color),
			]),
		);
	}
	if (pane === "Directives" && plan.jobs.size() === 0) {
		sections.push(
			pn("directives-complete", P.mint, "Check", "All of today's tasks are done", undefined, [
				para("New tasks arrive tomorrow. Keep charging the reactor until then."),
			]),
		);
	}
	return scaffold(sections, viewport, props, "AnomalyClaimActions");
}

const Views = { NextPlan, ShiftPlan };

export = Views;

// Research, rebuilt on Forge2: the next node to buy, the buy amount and one batch button, then the
// chain itself as a list of nodes joined by a lit connector. Same remote and payload as before:
// BuyResearch {Id, Amount} through the shared purchase planner. Levels survive rebirth.
import React from "@rbxts/react";
import { Audio } from "../../AudioKit/audio";
import { AppHelpers, NavState, UpgradeConfig, UpgradeEntry } from "../../CoreKit/appNav";
import { compactNumber, Flux } from "../../CoreKit/format";
import { useStagger } from "../../MotionKit/motion";
import { Button } from "../design/Button";
import { FilterChipRow } from "../design/FilterChipRow";
import { EmptyState } from "../design/Layers";
import { Meter, Panel } from "../design/Panel";
import { Text, Title } from "../design/Text";
import { gap, Iron, Type } from "../design/tokens";
import { MotionFX } from "../motion/motion";
import type { PageProps } from "../router/routes";
import { AmountPicker, cellWidth, ModelEntries, PageScroll, SearchBox, Tools, UpgradeCard, useFocusClaim, matches } from "./upgradeParts";

interface ResearchConfig extends UpgradeConfig {
	Description?: string;
	BaseProduction?: number;
	Accent?: Color3;
	Color?: Color3;
}

interface ResearchSession {
	Cash?: Flux;
	Research?: Record<string, number>;
	Zone: number;
	Rebirths: number;
	FeatureUnlocks?: Record<string, { Unlocked?: boolean }>;
}

const FILTERS = [
	{ id: "Available", label: "Open" },
	{ id: "Affordable", label: "Can afford" },
	{ id: "Owned", label: "Owned" },
	{ id: "Next", label: "Coming up" },
	{ id: "All", label: "All research" },
];

function effectLine(config: ResearchConfig): string {
	const production = config.BaseProduction ?? 0;
	return production > 0 ? `+${compactNumber(production)} per level` : (config.Description ?? "");
}

/** The lit line between two nodes; it fills once the node above has a level. */
function Connector(props: { lit: boolean; accent: Color3; order: number }) {
	return (
		<frame Size={new UDim2(1, 0, 0, 18)} BackgroundTransparency={1} LayoutOrder={props.order}>
			<frame Size={new UDim2(0, 3, 1, 0)} Position={UDim2.fromOffset(22, 0)} BackgroundColor3={props.lit ? props.accent : Iron.edge()} BackgroundTransparency={props.lit ? 0.1 : 0.6} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
		</frame>
	);
}

export function ResearchPage(props: PageProps) {
	const s = props.session as unknown as ResearchSession;
	const phone = props.phone;
	const research = (typeIs(props.config.Research, "table") ? props.config.Research : []) as ResearchConfig[];
	const [amount, setAmount] = React.useState(1);
	const [query, setQuery] = React.useState("");
	const [filter, setFilter] = React.useState("Available");
	const heroIn = useStagger(0);
	const entries = React.useMemo(
		() => AppHelpers.buildUpgradeEntries(research, s.Research ?? {}, s as unknown as NavState),
		[research, s.Research, s.Zone, s.Rebirths],
	);
	const cash = s.Cash ?? 0;
	let unlocked = 0;
	let maxed = 0;
	for (const entry of entries) {
		if (entry.unlocked) unlocked += 1;
		if (entry.maxed) maxed += 1;
	}
	const upNext = entries.find((entry) => entry.unlocked && !entry.maxed);
	const counts: Record<string, number> = {};
	for (const option of FILTERS) {
		counts[option.id] = Tools.Model.filter(entries as unknown as ModelEntries, "", option.id, amount, cash).size();
	}
	const visible = Tools.Model.filter(entries as unknown as ModelEntries, query, filter, amount, cash, matches);
	const batch = Tools.useBatch(props.request as never, "BuyResearch", visible, amount, cash);
	const gate = s.FeatureUnlocks?.Research;
	const gated = gate !== undefined && gate.Unlocked === false;
	const space = gap(phone, "l");
	const claimRef = useFocusClaim(batch.count > 0 && !batch.busy && !gated, [amount, unlocked]);
	const buyBatch = () => {
		if (batch.start()) {
			Audio.play("purchase");
			MotionFX.play("success");
		}
	};
	if (gated) {
		return (
			<PageScroll phone={phone}>
				<EmptyState title="Unlocks at 100 Flux" body="Earn 100 Flux to begin research." phone={phone} action={{ text: "Back to the forge", onPress: () => props.navigate("Overview") }} />
			</PageScroll>
		);
	}
	return (
		<PageScroll phone={phone}>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0} Position={heroIn.map((p) => UDim2.fromOffset(0, (1 - p) * 16))}>
				<Panel pad={gap(phone, "xl")} spacing={gap(phone, "m")} seam={batch.count > 0} rarity="Epic">
					<Title text="Research chain" size={Type.title(phone)} tags={["wave"]} order={0} />
					<Text text={upNext !== undefined ? `Next: ${upNext.config.Name}` : `${unlocked} of ${entries.size()} researched`} size={Type.body(phone) + 4} order={1} />
					<Meter value={maxed / math.max(1, entries.size())} order={2} height={phone ? 8 : 10} />
					<Text text={`${maxed} maxed · kept through rebirth`} size={Type.small(phone)} color={Iron.muted()} order={3} />
					<AmountPicker value={amount} onChange={setAmount} order={4} />
					<frame ref={claimRef} Size={UDim2.fromOffset(phone ? 180 : 220, phone ? 52 : 56)} BackgroundTransparency={1} LayoutOrder={5}>
					<Button
						text={batch.busy ? batch.status : batch.count > 0 ? `Research ${batch.count}` : "Nothing to buy"}
						onPress={buyBatch}
						disabled={batch.count <= 0 || batch.busy}
						stretch
						height={phone ? 52 : 56}
						textSize={19}
					/>
					</frame>
				</Panel>
			</frame>

			<FilterChipRow options={FILTERS} value={filter} onChange={(id) => { Audio.play("tabSwitch"); setFilter(id); }} counts={counts} order={1} />
			<SearchBox value={query} onChange={setQuery} hint="Find research" phone={phone} order={2} />

			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={3}>
				<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} />
				{visible.map((entry, index) => {
					const config = entry.config as ResearchConfig;
					const accent = config.Accent ?? config.Color ?? Iron.steel();
					return (
						<React.Fragment key={config.Id}>
							{index > 0 && <Connector lit={visible[index - 1].level > 0} accent={accent} order={index * 2 - 1} />}
							<UpgradeCard
								entry={entry as unknown as UpgradeEntry}
								index={index * 2}
								amount={amount}
								cash={cash}
								phone={phone}
								effect={effectLine(config)}
								accent={accent}
								onBuy={(id) => batch.buy(id)}
								busy={batch.busy}
								maxedLine="Maxed. The bonus is permanent."
								width={cellWidth(1, 0)}
							/>
						</React.Fragment>
					);
				})}
			</frame>
			{visible.size() === 0 && (
				<EmptyState
					title={query !== "" ? "No matching research" : filter === "Available" ? "All caught up" : "Nothing here"}
					body="Try another search or choose All research."
					action={{ text: "Show all", onPress: () => { setFilter("All"); setQuery(""); } }}
					phone={phone}
					order={4}
				/>
			)}
		</PageScroll>
	);
}

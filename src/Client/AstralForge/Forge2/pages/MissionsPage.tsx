// Missions, rebuilt on Forge2: today's progress, claim-all when anything is ready, the shared
// FilterChipRow (with counts) and a sort, then one roomy card per mission. Same remote and payload
// as before: ClaimQuest {Id}. Rows pop when a mission turns ready and glow when it's nearly done.
import React from "@rbxts/react";
import { Audio } from "../../AudioKit/audio";
import { compactNumber, formatReward, Reward } from "../../CoreKit/format";
import { taskFilterCounts, taskMatchesFilter } from "../../CoreKit/taskFilter";
import { useFlash, useListStagger, usePulse, useStagger } from "../../MotionKit/motion";
import Juice = require("../../JuiceFx");
import { Button } from "../design/Button";
import { FilterChipRow } from "../design/FilterChipRow";
import { EmptyState, Tooltip } from "../design/Layers";
import { Card, Meter, Panel } from "../design/Panel";
import { Text, Title } from "../design/Text";
import { Corner, Fonts, gap, Iron, Type } from "../design/tokens";
import { Burst, MotionFX } from "../motion/motion";
import type { PageProps } from "../router/routes";
import { PageScroll, Row, SearchBox, useFocusClaim, matches } from "./upgradeParts";

interface Quest {
	Id: string;
	Name: string;
	Description?: string;
	Reward?: Reward;
	Kind?: string;
	Claimed: boolean;
	Progress: number;
	Target: number;
}

const NEAR = 0.85;
const REWARD_KEYS = ["Cash", "CashMinutes", "Stardust", "Cores", "Signals", "CommandXP", "StreakShield"] as const;

const FILTERS = [
	{ id: "All", label: "All" },
	{ id: "Ready", label: "Ready to claim" },
	{ id: "Active", label: "Still in progress" },
	{ id: "Done", label: "Already claimed" },
];

const SORTS: ReadonlyArray<[string, string]> = [
	["Recommended", "Ready first"],
	["Closest", "Almost done"],
	["List", "Daily order"],
];

function isReady(q: Quest) {
	return !q.Claimed && (tonumber(q.Progress) ?? 0) >= (tonumber(q.Target) ?? 0);
}
function rank(q: Quest) {
	return isReady(q) ? 0 : q.Claimed ? 2 : 1;
}
function progressOf(q: Quest) {
	return math.clamp((tonumber(q.Progress) ?? 0) / math.max(1, tonumber(q.Target) ?? 1), 0, 1);
}

function MissionCard(props: { quest: Quest; index: number; phone: boolean; onClaim: (q: Quest) => void; busy: boolean }) {
	const q = props.quest;
	const phone = props.phone;
	const ready = isReady(q);
	const fraction = progressOf(q);
	const near = !ready && !q.Claimed && fraction >= NEAR;
	const reveal = useListStagger(props.index);
	const pulse = usePulse(near, 2.4);
	// pop once when the mission turns ready
	const was = React.useRef(ready);
	const [turned, setTurned] = React.useState(0);
	React.useEffect(() => {
		if (ready && !was.current) setTurned((n) => n + 1);
		was.current = ready;
	}, [ready]);
	const pop = useFlash(turned, false, 0.6);
	const reward = formatReward(q.Reward);
	const accent = q.Claimed ? Iron.muted() : ready ? Iron.brass() : Iron.steel();
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.index}>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} Position={reveal.map((p) => UDim2.fromOffset(0, math.round((1 - p) * 14)))}>
				<uiscale Scale={pop.map((v) => 1 + v * 0.03)} />
				<Card accent={accent} selected={ready} pad={gap(phone, "l")} spacing={gap(phone, "s")} rarity={ready ? "Legendary" : undefined}>
					<Text text={q.Name} size={Type.body(phone) + 2} font={Fonts.heavy} color={q.Claimed ? Iron.soft() : Iron.text()} order={0} />
					{ready && <Text text="Reward ready" size={Type.small(phone)} font={Fonts.heavy} color={Iron.brass()} order={1} />}
					{q.Description !== undefined && q.Description !== "" && <Text text={q.Description} size={Type.small(phone)} color={Iron.muted()} multiline order={1} />}
					<Row order={2} spacing={12}>
						<Text text={`${compactNumber(q.Progress)} / ${compactNumber(q.Target)}`} size={Type.small(phone)} font={Fonts.heavy} color={accent} box={UDim2.fromOffset(120, 20)} order={0} />
						{reward !== "" && <Text text={reward} size={Type.small(phone)} color={Iron.brass()} box={new UDim2(1, -136, 0, 20)} align="Right" order={1} />}
					</Row>
					<Meter value={fraction} color={accent} height={6} order={3} />
					{!q.Claimed && (
						<Tooltip tip={ready ? `Reward ready: ${reward}` : `${compactNumber(q.Target - q.Progress)} to go${reward !== "" ? ` for ${reward}` : ""}`} size={UDim2.fromOffset(phone ? 140 : 160, 44)} order={4}>
							<Button text={ready ? "Claim" : "Not yet"} onPress={() => props.onClaim(q)} disabled={!ready || props.busy} glint={ready} stretch />
						</Tooltip>
					)}
				</Card>
				{near && (
					<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ZIndex={6}>
						<uicorner CornerRadius={new UDim(0, Corner.panel)} />
						<uistroke Color={Iron.brass()} Thickness={1.5} Transparency={pulse.map((a) => math.clamp(0.65 - a * 0.45, 0.18, 0.65))} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
					</frame>
				)}
			</frame>
		</frame>
	);
}

export function MissionsPage(props: PageProps) {
	const phone = props.phone;
	const raw = (props.session as unknown as { Quests?: unknown }).Quests;
	const quests = (typeIs(raw, "table") ? raw : []) as Quest[];
	const guide = (props.config.ClientPageGuides as Record<string, { EmptyNone?: string; EmptyFilter?: string } | undefined> | undefined)?.Missions;
	const [filter, setFilter] = React.useState("All");
	const [sort, setSort] = React.useState("Recommended");
	const [query, setQuery] = React.useState("");
	const [claims, setClaims] = React.useState(0);
	const claimFlash = useFlash(claims, false, 0.42);
	const heroIn = useStagger(0);
	const counts = taskFilterCounts(quests) as unknown as Record<string, number>;
	const needle = query.lower();
	const visible: Quest[] = [];
	quests.forEach((q) => {
		if (!typeIs(q, "table")) return;
		if (filter !== "All" && !taskMatchesFilter(q, filter)) return;
		if (needle !== "" && !matches(needle, q.Name, q.Description, formatReward(q.Reward), q.Kind)) return;
		visible.push(q);
	});
	const listIndex = new Map<Quest, number>();
	quests.forEach((q, i) => listIndex.set(q, i));
	visible.sort((a, b) => {
		if (sort !== "List") {
			const ra = rank(a);
			const rb = rank(b);
			if (ra !== rb) return ra < rb;
			if (sort === "Closest" && progressOf(a) !== progressOf(b)) return progressOf(a) > progressOf(b);
		}
		return (listIndex.get(a) ?? 0) < (listIndex.get(b) ?? 0);
	});
	let closest: Quest | undefined;
	for (const q of quests) {
		if (!typeIs(q, "table") || q.Claimed === true || progressOf(q) >= 1) continue;
		if (closest === undefined || progressOf(q) > progressOf(closest)) closest = q;
	}
	const closestReward = closest !== undefined ? formatReward(closest.Reward) : "";
	const nextLine =
		closest === undefined
			? "Finish these for Flux and Stardust. They refresh every day."
			: `Closest: ${closest.Name}, ${compactNumber(closest.Progress)} / ${compactNumber(closest.Target)}` + (closestReward !== "" ? ` for ${closestReward}` : "");

	const claimOne = (q: Quest) => {
		setClaims((n) => n + 1);
		Audio.play("purchase");
		Burst.spark(Iron.brass(), 0.8);
		props.request("ClaimQuest", { Id: q.Id }, (reply) => {
			if (reply.ok === true) MotionFX.play("success");
		});
	};
	const claimAll = () => {
		const ready = quests.filter((q) => typeIs(q, "table") && !q.Claimed && (tonumber(q.Target) ?? 0) > 0 && (tonumber(q.Progress) ?? 0) >= (tonumber(q.Target) ?? 0));
		if (ready.size() === 0) return;
		setClaims((n) => n + 1);
		Audio.play("purchase");
		Burst.gain(`${ready.size()} missions`, Iron.brass());
		// one line for the whole batch instead of a pile of separate pops
		const total: Reward = {};
		let pending = ready.size();
		let landed = 0;
		const finish = () => {
			pending -= 1;
			if (pending > 0) return;
			if (landed > 0) MotionFX.play("milestone");
			if (landed < 2) return;
			const summary = formatReward(total);
			Juice.status(summary !== "" ? `+${summary} from ${landed} missions` : `${landed} missions claimed`, "success");
		};
		for (const q of ready) {
			props.request("ClaimQuest", { Id: q.Id }, (reply) => {
				if (reply.ok === true) {
					landed += 1;
					if (q.Reward !== undefined) {
						for (const key of REWARD_KEYS) {
							const amount = q.Reward[key];
							if (amount !== undefined) total[key] = (total[key] ?? 0) + amount;
						}
					}
				}
				finish();
			});
		}
	};
	const busy = props.busy.ClaimQuest === true;
	const claimRef = useFocusClaim(counts.Ready > 0, [counts.Ready, filter]);
	return (
		<PageScroll phone={phone}>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0} Position={heroIn.map((p) => UDim2.fromOffset(0, (1 - p) * 16))}>
				<Panel pad={gap(phone, "xl")} spacing={gap(phone, "m")} seam={counts.Ready > 0} scale={claimFlash.map((v) => 1 + v * 0.02)}>
					<Title text="Today's missions" size={Type.title(phone)} tags={["wave"]} order={0} />
					<Text text={`${counts.Done} of ${quests.size()} done`} size={Type.body(phone) + 4} font={Fonts.heavy} color={counts.Done >= quests.size() && quests.size() > 0 ? Iron.brass() : Iron.text()} order={1} />
					<Meter value={counts.Done / math.max(1, quests.size())} order={2} height={phone ? 8 : 10} />
					<Text text={nextLine} size={Type.body(phone)} color={Iron.soft()} multiline order={3} />
					{counts.Ready > 0 && (
						<frame ref={claimRef} Size={UDim2.fromOffset(phone ? 200 : 240, phone ? 52 : 56)} BackgroundTransparency={1} LayoutOrder={4}>
							<Button text={`Claim all · ${counts.Ready}`} onPress={claimAll} disabled={busy} stretch height={phone ? 52 : 56} textSize={19} />
						</frame>
					)}
				</Panel>
			</frame>

			<FilterChipRow options={FILTERS} value={filter} onChange={(id) => { Audio.play("tabSwitch"); setFilter(id); }} counts={counts} order={1} />
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2}>
				<uilistlayout Padding={new UDim(0, gap(phone, "s"))} SortOrder={Enum.SortOrder.LayoutOrder} />
				<SearchBox value={query} onChange={setQuery} hint="Search missions and rewards" phone={phone} order={0} />
				<FilterChipRow options={SORTS.map(([id, label]) => ({ id, label }))} value={sort} onChange={setSort} accent={Iron.steel()} order={1} />
			</frame>

			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={3}>
				<uilistlayout Padding={new UDim(0, gap(phone, "m"))} SortOrder={Enum.SortOrder.LayoutOrder} />
				{visible.map((q, index) => (
					<MissionCard key={q.Id} quest={q} index={index} phone={phone} onClaim={claimOne} busy={busy} />
				))}
			</frame>
			{visible.size() === 0 && (
				<EmptyState
					title={quests.size() === 0 ? "No missions right now" : "Nothing in this filter"}
					body={quests.size() === 0 ? (guide?.EmptyNone ?? "New dailies land at reset.") : (guide?.EmptyFilter ?? "Switch the filter back to All.")}
					action={quests.size() > 0 ? { text: "Show all", onPress: () => { setFilter("All"); setQuery(""); } } : undefined}
					phone={phone}
					order={4}
				/>
			)}
		</PageScroll>
	);
}

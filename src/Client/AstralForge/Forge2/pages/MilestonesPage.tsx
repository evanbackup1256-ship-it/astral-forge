// Milestones, rebuilt on Forge2: the count reached, Claim all, a search line with ready / in
// progress / claimed chips and three orders, then one roomy card per milestone. Rows that turn
// ready pop once; the closest-to-done ones glow. Remote unchanged: ClaimAchievement {Id}.
import React from "@rbxts/react";
import { Audio } from "../../AudioKit/audio";
import { compactNumber, formatReward, Reward } from "../../CoreKit/format";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { taskFilterCounts, taskMatchesFilter } from "../../CoreKit/taskFilter";
import { useChangePop, useFlash, useGlowStroke, useListStagger, useStagger } from "../../MotionKit/motion";
import { PressButton as Button } from "../design/PressButton";
import { EmptyState } from "../design/Layers";
import { Card, Meter, Panel } from "../design/Panel";
import { Chip } from "../design/Pick";
import { Text, Title } from "../design/Text";
import { Corner, Fonts, gap, HIT, Iron, Type } from "../design/tokens";
import { Burst, MotionFX } from "../motion/motion";
import type { PageProps } from "../router/routes";

const UserInputService = game.GetService("UserInputService");

interface Milestone {
	Id: string;
	Name: string;
	Description?: string;
	Reward?: Reward;
	Claimed: boolean;
	Progress: number;
	Target: number;
}

const FILTERS: ReadonlyArray<[string, string]> = [
	["All", "All"],
	["Ready", "Ready"],
	["Active", "In progress"],
	["Done", "Claimed"],
];
const SORTS: ReadonlyArray<[string, string]> = [
	["Recommended", "Ready first"],
	["Closest", "Almost done"],
	["Name", "A to Z"],
];
const PAGE_SIZE = 40;
const NEAR = 0.85;

function rank(m: Milestone): number {
	if (!m.Claimed && m.Progress >= m.Target) return 0;
	return m.Claimed ? 2 : 1;
}

function share(m: Milestone): number {
	return math.clamp(m.Progress / math.max(1, m.Target), 0, 1);
}

function read(raw: unknown): Milestone[] {
	const out: Milestone[] = [];
	if (!typeIs(raw, "table")) return out;
	for (const [, entry] of pairs(raw as Record<string, unknown>)) {
		if (!typeIs(entry, "table")) continue;
		const m = entry as Partial<Milestone>;
		if (!typeIs(m.Id, "string")) continue;
		out.push({
			Id: m.Id,
			Name: tostring(m.Name ?? m.Id),
			Description: m.Description,
			Reward: m.Reward,
			Claimed: m.Claimed === true,
			Progress: tonumber(m.Progress) ?? 0,
			Target: tonumber(m.Target) ?? 1,
		});
	}
	return out;
}

function matches(query: string, m: Milestone): boolean {
	const q = query.lower();
	if (q.match("^%s*$")[0] !== undefined) return true;
	for (const field of [m.Name, m.Description ?? "", formatReward(m.Reward)]) {
		if (field.lower().find(q, 1, true)[0] !== undefined) return true;
	}
	return false;
}

function MilestoneCard(props: { m: Milestone; index: number; phone: boolean; focusRef?: React.Ref<Frame>; onClaim: (m: Milestone) => void }) {
	const { m, phone } = props;
	const ready = rank(m) === 0;
	const near = !ready && !m.Claimed && share(m) >= NEAR;
	const rise = useListStagger(props.index);
	// pop once when a milestone turns ready while you're looking at it
	const wasReady = React.useRef(ready);
	const [turned, setTurned] = React.useState(0);
	React.useEffect(() => {
		if (ready && !wasReady.current) setTurned((n) => n + 1);
		wasReady.current = ready;
	}, [ready]);
	const pop = useFlash(turned, false, 0.6);
	const glow = useGlowStroke(near, false, 1);
	const reward = formatReward(m.Reward);
	const accent = m.Claimed ? Iron.muted() : ready ? Iron.brass() : Iron.steel();
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.index}>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} Position={rise.map((p) => UDim2.fromOffset(0, (1 - p) * 14))}>
				<uiscale Scale={pop.map((v) => 1 + v * 0.03)} />
				<Card accent={accent} pad={gap(phone, "l")} spacing={gap(phone, "s")} seam={ready} rarity="Legendary" color={m.Claimed ? Iron.sunk() : undefined}>
					<Text text={m.Name} size={Type.body(phone) + 1} font={Fonts.heavy} color={m.Claimed ? Iron.muted() : Iron.text()} order={0} />
					{m.Description !== undefined && m.Description !== "" && <Text text={m.Description} size={Type.small(phone)} color={Iron.muted()} multiline order={1} />}
					{reward !== "" && <Text text={reward} size={Type.small(phone)} font={Fonts.heavy} color={m.Claimed ? Iron.muted() : Iron.brass()} order={2} />}
					<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={3}>
						<uilistlayout
							FillDirection={phone ? Enum.FillDirection.Vertical : Enum.FillDirection.Horizontal}
							Padding={new UDim(0, gap(phone, "m"))}
							VerticalAlignment={Enum.VerticalAlignment.Center}
							SortOrder={Enum.SortOrder.LayoutOrder}
						/>
						<frame Size={new UDim2(1, phone ? 0 : -170, 0, 26)} BackgroundTransparency={1} LayoutOrder={0}>
							<Text
								text={m.Claimed ? "✓" : ready ? "" : `${compactNumber(m.Progress)} / ${compactNumber(m.Target)}`}
								size={Type.small(phone)}
								color={Iron.muted()}
								box={new UDim2(1, 0, 0, 16)}
							/>
							<frame Size={new UDim2(1, 0, 0, 8)} Position={new UDim2(0, 0, 1, -8)} BackgroundTransparency={1}>
								<Meter value={m.Claimed || ready ? 1 : share(m)} color={accent} height={8} />
								{near && (
									<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
										<uicorner CornerRadius={new UDim(1, 0)} />
										<uistroke Color={Iron.brass()} Transparency={glow} Thickness={2} />
									</frame>
								)}
							</frame>
						</frame>
						<frame ref={props.focusRef} Size={phone ? new UDim2(1, 0, 0, HIT) : UDim2.fromOffset(160, HIT)} BackgroundTransparency={1} LayoutOrder={1}>
							{m.Claimed ? (
								<Text text="Claimed" size={Type.small(phone)} color={Iron.muted()} align={phone ? "Left" : "Right"} box={UDim2.fromScale(1, 1)} />
							) : (
								<Button text={ready ? "Claim" : "Locked"} onPress={() => props.onClaim(m)} disabled={!ready} tone={ready ? "brass" : "quiet"} stretch />
							)}
						</frame>
					</frame>
				</Card>
			</frame>
		</frame>
	);
}

export function MilestonesPage(props: PageProps) {
	const phone = props.phone;
	const all = read((props.session as unknown as { Achievements?: unknown }).Achievements);
	const counts = taskFilterCounts(all);
	const [filter, setFilter] = React.useState("All");
	const [sort, setSort] = React.useState("Recommended");
	const [query, setQuery] = React.useState("");
	const [shown, setShown] = React.useState(PAGE_SIZE);
	const [claims, setClaims] = React.useState(0);
	const flash = useFlash(claims, false, 0.42);
	const heroIn = useStagger(0);
	const countPop = useChangePop(counts.Done);

	const visible = all.filter((m) => taskMatchesFilter(m, filter) && matches(query, m));
	visible.sort((a, b) => {
		const ra = rank(a);
		const rb = rank(b);
		if (sort === "Name") return a.Name < b.Name;
		if (ra !== rb) return ra < rb;
		if (sort === "Closest") return share(a) > share(b);
		return a.Name < b.Name;
	});
	const firstReady = visible.find((m) => rank(m) === 0)?.Id;
	const focusRef = React.useRef<Frame>();
	React.useEffect(() => {
		if (firstReady === undefined || !UserInputService.GamepadEnabled) return undefined;
		const job = task.defer(() => {
			const host = focusRef.current;
			if (host !== undefined && host.Parent !== undefined) GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [firstReady, filter]);

	const claim = (m: Milestone) => {
		setClaims((n) => n + 1);
		Burst.gain(formatReward(m.Reward), Iron.brass(), "Milestone.2");
		Audio.play("collect");
		props.request("ClaimAchievement", { Id: m.Id }, (reply) => reply.ok === true && MotionFX.play("milestone"));
	};
	const claimAll = () => {
		for (const m of all) if (rank(m) === 0) claim(m);
	};

	const space = gap(phone, "l");
	return (
		<scrollingframe
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			CanvasSize={new UDim2()}
			AutomaticCanvasSize={Enum.AutomaticSize.Y}
			ScrollBarThickness={phone ? 0 : 4}
			ScrollBarImageColor3={Iron.brassDeep()}
		>
			<uipadding PaddingTop={new UDim(0, space)} PaddingBottom={new UDim(0, space * 3)} PaddingLeft={new UDim(0, space)} PaddingRight={new UDim(0, space)} />
			<uilistlayout Padding={new UDim(0, space)} SortOrder={Enum.SortOrder.LayoutOrder} />

			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0} Position={heroIn.map((p) => UDim2.fromOffset(0, (1 - p) * 16))}>
				<Panel pad={gap(phone, "xl")} spacing={gap(phone, "m")} seam={counts.Ready > 0} scale={flash.map((v) => 1 + v * 0.02)}>
					<Title text="Milestones" size={Type.title(phone)} tags={["wave"]} order={0} />
					<frame Size={new UDim2(1, 0, 0, Type.hero(phone) + 8)} BackgroundTransparency={1} LayoutOrder={1}>
						<uiscale Scale={countPop} />
						<Text text={`${counts.Done}`} size={Type.hero(phone)} font={Fonts.heavy} color={Iron.brass()} box={UDim2.fromOffset(phone ? 90 : 140, Type.hero(phone) + 8)} />
						<Text
							text={`/ ${all.size()}`}
							size={Type.title(phone)}
							color={Iron.muted()}
							box={UDim2.fromOffset(120, Type.title(phone) + 6)}
							position={new UDim2(0, phone ? 92 : 142, 1, -(Type.title(phone) + 10))}
						/>
					</frame>
					<Meter value={counts.Done / math.max(1, all.size())} order={2} />
					<Text text="Kept through every rebirth." size={Type.small(phone)} color={Iron.muted()} order={3} />
					{counts.Ready > 0 && <Button text={`Claim all  ${counts.Ready}`} onPress={claimAll} width={phone ? 200 : 240} height={52} textSize={19} order={4} />}
				</Panel>
			</frame>

			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
				<uilistlayout Padding={new UDim(0, gap(phone, "s"))} SortOrder={Enum.SortOrder.LayoutOrder} />
				<frame Size={new UDim2(1, 0, 0, HIT)} BackgroundColor3={Iron.sunk()} BorderSizePixel={0} LayoutOrder={0}>
					<uicorner CornerRadius={new UDim(0, Corner.card)} />
					<uistroke Color={Iron.edge()} Transparency={0.5} />
					<textbox
						Size={new UDim2(1, -24, 1, 0)}
						Position={UDim2.fromOffset(12, 0)}
						BackgroundTransparency={1}
						Text={query}
						PlaceholderText="Search"
						PlaceholderColor3={Iron.muted()}
						TextColor3={Iron.text()}
						FontFace={Fonts.bold}
						TextSize={Type.body(phone)}
						TextXAlignment={Enum.TextXAlignment.Left}
						ClearTextOnFocus={false}
						Change={{ Text: (box) => setQuery(box.Text) }}
					/>
				</frame>
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
					{FILTERS.map(([id, label], i) => {
						const n = counts[id as keyof typeof counts];
						return (
							<Chip
								key={id}
								text={id === "All" || n === 0 ? label : `${label} ${n}`}
								on={filter === id}
								onPress={() => {
									Audio.play("filterPick");
									setFilter(id);
									setShown(PAGE_SIZE);
								}}
								order={i}
							/>
						);
					})}
					<frame Size={UDim2.fromOffset(12, HIT)} BackgroundTransparency={1} LayoutOrder={9} />
					{SORTS.map(([id, label], i) => (
						<Chip key={id} text={label} on={sort === id} color={Iron.steel()} onPress={() => setSort(id)} order={10 + i} />
					))}
				</frame>
			</frame>

			{visible.size() === 0 ? (
				<EmptyState
					title={all.size() === 0 ? "Nothing yet" : "No match"}
					body={all.size() === 0 ? "Keep playing and they will show up." : undefined}
					action={
						all.size() === 0
							? undefined
							: {
									text: "Show all",
									onPress: () => {
										setFilter("All");
										setQuery("");
									},
								}
					}
					phone={phone}
					order={2}
				/>
			) : (
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2}>
					<uilistlayout Padding={new UDim(0, gap(phone, "m"))} SortOrder={Enum.SortOrder.LayoutOrder} />
					{visible
						.filter((_, i) => i < shown)
						.map((m, i) => (
							<MilestoneCard key={m.Id} m={m} index={i} phone={phone} focusRef={m.Id === firstReady ? focusRef : undefined} onClaim={claim} />
						))}
					{visible.size() > shown && <Button text={`${visible.size() - shown} more`} tone="iron" onPress={() => setShown((n) => n + PAGE_SIZE)} stretch order={PAGE_SIZE * 100} />}
				</frame>
			)}
		</scrollingframe>
	);
}

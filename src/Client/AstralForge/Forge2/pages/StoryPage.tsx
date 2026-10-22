// Story on Forge2: the chapter archive and a beat-by-beat reader. Opening a chapter marks it read;
// finishing it pays its reward once. B (or Close) leaves the reader.
// Remotes: ReadStoryChapter { Id }, ClaimStoryChapter { Id }
import React from "@rbxts/react";
import { Audio } from "../../AudioKit/audio";
import { formatReward, Reward } from "../../CoreKit/format";
import { useChangePop, useStagger } from "../../MotionKit/motion";
import { Button } from "../design/Button";
import { EmptyState } from "../design/Layers";
import { Card, Meter, Panel } from "../design/Panel";
import { Chip } from "../design/Pick";
import { Text, Title } from "../design/Text";
import { Fonts, gap, Iron, Type } from "../design/tokens";
import { useBack } from "../input/input";
import { Burst, MotionFX } from "../motion/motion";
import type { PageProps } from "../router/routes";

interface ChapterState {
	Id: string;
	Unlocked?: boolean;
	Read?: boolean;
	Claimed?: boolean;
	Progress?: number;
	Target?: number;
}
interface ChapterConfig {
	Id: string;
	Title: string;
	Chapter?: string;
	Summary?: string;
	Body: string[];
	Color: Color3;
	Reward?: Reward;
}

const NAMES = ["Bay Seven", "Stellar Core", "ILYRA VALE", "Astral Forge", "Hollow Star"];
type Filter = "All" | "New" | "Reward";

/** Proper names in a beat pick up the chapter colour. */
function lightUp(text: string, color: Color3): string {
	const rgb = `${math.floor(color.R * 255)},${math.floor(color.G * 255)},${math.floor(color.B * 255)}`;
	let out = text;
	for (const name of NAMES) out = out.gsub(name, `<font color="rgb(${rgb})"><b>${name}</b></font>`)[0];
	return out;
}

function Beat(props: { text: string; color: Color3; phone: boolean; index: number }) {
	const rise = useStagger(0, false, 0, 0.3);
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2} Position={rise.map((p) => UDim2.fromOffset((1 - p) * 18, 0))}>
			<Text text={lightUp(props.text, props.color)} size={Type.body(props.phone) + 1} color={Iron.text()} font={Fonts.body} multiline transparency={rise.map((p) => 1 - p)} />
		</frame>
	);
}

function Reader(props: { page: PageProps; entry: ChapterConfig; state: ChapterState; onClose: () => void }) {
	const { entry, state } = props;
	const phone = props.page.phone;
	const [beat, setBeat] = React.useState(0);
	const total = math.max(1, entry.Body.size());
	const finished = beat >= total - 1;
	const pop = useChangePop(beat);
	useBack(true, props.onClose);
	React.useEffect(() => {
		Audio.play("storyOpen");
		if (state.Read !== true) props.page.request("ReadStoryChapter", { Id: entry.Id });
	}, [entry.Id]);
	const claim = () => {
		props.page.request("ClaimStoryChapter", { Id: entry.Id }, (reply) => {
			if (reply.ok === true) {
				MotionFX.play("milestone");
				Burst.spark(entry.Color, 1);
			}
		});
	};
	return (
		<Panel pad={gap(phone, "xl")} spacing={gap(phone, "m")} seam rarity="Legendary" order={0}>
			<Text text={entry.Chapter ?? ""} size={Type.small(phone)} color={entry.Color} order={0} />
			<Title text={entry.Title} size={Type.title(phone)} tags={["wave"]} order={1} />
			<Beat key={`beat${beat}`} text={entry.Body[beat] ?? ""} color={entry.Color} phone={phone} index={beat} />
			<frame Size={new UDim2(1, 0, 0, 10)} BackgroundTransparency={1} LayoutOrder={3}>
				<uiscale Scale={pop} />
				<Meter value={(beat + 1) / total} color={entry.Color} height={6} />
			</frame>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={4}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 10)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<Button text="Back" tone="iron" width={110} disabled={beat === 0} onPress={() => setBeat(math.max(0, beat - 1))} order={0} />
				{!finished && <Button text="Next" width={140} onPress={() => setBeat(beat + 1)} order={1} />}
				{finished && state.Claimed !== true && entry.Reward !== undefined && <Button text={`Claim · ${formatReward(entry.Reward)}`} width={phone ? 220 : 260} onPress={claim} order={1} />}
				{finished && (state.Claimed === true || entry.Reward === undefined) && <Button text="Read again" tone="iron" width={140} onPress={() => setBeat(0)} order={1} />}
				<Button text="Close" tone="quiet" width={110} onPress={props.onClose} order={2} />
			</frame>
		</Panel>
	);
}

function ChapterRow(props: { entry: ChapterConfig; state: ChapterState; phone: boolean; index: number; onOpen: () => void }) {
	const { entry, state, phone } = props;
	const open = state.Unlocked === true;
	const done = state.Claimed === true || state.Read === true;
	const waiting = open && state.Claimed !== true && state.Read === true && entry.Reward !== undefined;
	const rise = useStagger(props.index + 1);
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.index} Position={rise.map((p) => UDim2.fromOffset(0, (1 - p) * 10))}>
			<Card accent={open ? entry.Color : Iron.edge()} pad={gap(phone, "m")} spacing={6} selected={open && !done} onPress={open ? props.onOpen : undefined}>
				<Text text={`${entry.Chapter !== undefined ? `${entry.Chapter} · ` : ""}${entry.Title}`} size={Type.body(phone)} font={Fonts.heavy} color={open ? Iron.text() : Iron.muted()} order={0} />
				{open ? (
					<Text text={waiting ? `Reward waiting · ${formatReward(entry.Reward!)}` : done ? (entry.Summary ?? "Read") : (entry.Summary ?? "New")} size={Type.small(phone)} color={waiting ? Iron.brass() : Iron.muted()} multiline order={1} />
				) : (
					<>
						<Text text={`Opens at ${math.floor(state.Progress ?? 0)}/${state.Target ?? 1}`} size={Type.small(phone)} color={Iron.muted()} order={1} />
						<Meter value={(state.Progress ?? 0) / math.max(1, state.Target ?? 1)} color={entry.Color} height={6} order={2} />
					</>
				)}
			</Card>
		</frame>
	);
}

export function StoryPage(props: PageProps) {
	const phone = props.phone;
	const chapters = ((props.session as unknown as { Story?: ChapterState[] }).Story ?? []) as ChapterState[];
	const configs = ((props.config as unknown as { Story?: ChapterConfig[] }).Story ?? []) as ChapterConfig[];
	const [reading, setReading] = React.useState<string | undefined>(undefined);
	const [filter, setFilter] = React.useState<Filter>("All");
	const byId = new Map<string, ChapterConfig>();
	for (const c of configs) byId.set(c.Id, c);
	const isNew = (c: ChapterState) => c.Unlocked === true && c.Read !== true;
	const hasReward = (c: ChapterState) => c.Unlocked === true && c.Claimed !== true && byId.get(c.Id)?.Reward !== undefined;
	const shown = chapters.filter((c) => byId.has(c.Id) && (filter === "All" || (filter === "New" ? isNew(c) : hasReward(c))));
	const openEntry = reading !== undefined ? byId.get(reading) : undefined;
	const openState = chapters.find((c) => c.Id === reading);
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
			{openEntry !== undefined && openState !== undefined ? (
				<Reader key={openEntry.Id} page={props} entry={openEntry} state={openState} onClose={() => setReading(undefined)} />
			) : (
				<>
					<Panel pad={gap(phone, "l")} spacing={gap(phone, "s")} order={0}>
						<Title text="Story" size={Type.title(phone)} tags={["wave"]} order={0} />
						<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
							<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
							<Chip text="All" on={filter === "All"} onPress={() => setFilter("All")} order={0} />
							<Chip text={`New ${chapters.filter(isNew).size()}`} on={filter === "New"} onPress={() => setFilter("New")} order={1} />
							<Chip text={`Rewards ${chapters.filter(hasReward).size()}`} on={filter === "Reward"} onPress={() => setFilter("Reward")} order={2} />
						</frame>
					</Panel>
					<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
						<uilistlayout Padding={new UDim(0, gap(phone, "m"))} SortOrder={Enum.SortOrder.LayoutOrder} />
						{shown.size() === 0 ? (
							<EmptyState title={filter === "All" ? "No chapters yet" : "Nothing here"} body={filter === "All" ? "Chapters open as the forge grows." : "Try All."} phone={phone} />
						) : (
							shown.map((c, i) => <ChapterRow key={c.Id} entry={byId.get(c.Id)!} state={c} phone={phone} index={i} onOpen={() => setReading(c.Id)} />)
						)}
					</frame>
				</>
			)}
		</scrollingframe>
	);
}

// Story on Forge2: the chapter archive and a beat-by-beat reader. Opening a chapter marks it read;
// finishing it pays its reward once. B (or Close) leaves the reader.
// Remotes: ReadStoryChapter { Id }, ClaimStoryChapter { Id }
import React from "@rbxts/react";
import { Audio } from "../../AudioKit/audio";
import { formatReward, Reward } from "../../CoreKit/format";
import { useChangePop, usePulse, useStagger } from "../../MotionKit/motion";
import { Palette } from "../../CoreKit/theme";
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

function graphemes(text: string): number {
	const [count] = utf8.len(text);
	return typeIs(count, "number") ? count : text.size();
}

/** One part of the chapter, typed out at the old reader's pace (length/72 per 0.022s step). */
function Beat(props: { text: string; color: Color3; phone: boolean; index: number }) {
	const rise = useStagger(0, false, 0, 0.3);
	const decorated = lightUp(props.text, props.color);
	const [shown, setShown] = React.useBinding(0);
	React.useEffect(() => {
		let alive = true;
		setShown(0);
		Audio.play("storyBeat");
		const length = graphemes(props.text);
		const step = math.max(1, math.floor(length / 72));
		const worker = task.spawn(() => {
			let count = 0;
			while (alive && count < length) {
				count = math.min(length, count + step);
				setShown(count);
				task.wait(0.022);
			}
		});
		return () => {
			alive = false;
			pcall(task.cancel, worker);
		};
	}, [props.index, props.text]);
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2} Position={rise.map((p) => UDim2.fromOffset((1 - p) * 18, 0))}>
			<textlabel
				Size={new UDim2(1, 0, 0, 0)}
				AutomaticSize={Enum.AutomaticSize.Y}
				BackgroundTransparency={1}
				Text={decorated}
				RichText
				MaxVisibleGraphemes={shown.map((n) => (n >= graphemes(props.text) ? -1 : n))}
				FontFace={Fonts.body}
				TextColor3={Iron.text()}
				TextTransparency={rise.map((p) => 1 - p)}
				TextSize={Type.body(props.phone) + 1}
				TextWrapped
				TextXAlignment={Enum.TextXAlignment.Left}
				TextYAlignment={Enum.TextYAlignment.Top}
			/>
		</frame>
	);
}

function RewardBox(props: { reward: string; claimed: boolean; color: Color3; phone: boolean }) {
	return (
		<frame Size={new UDim2(1, 0, 0, 56)} BackgroundColor3={Iron.face()} BorderSizePixel={0} LayoutOrder={3}>
			<uicorner CornerRadius={new UDim(0, 8)} />
			<uistroke Color={props.color} Transparency={0.35} />
			<frame Size={new UDim2(0, 3, 1, -12)} Position={UDim2.fromOffset(0, 6)} BackgroundColor3={props.color} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(0, 2)} />
			</frame>
			<Text text={props.claimed ? "Reward claimed" : "Reward"} size={11} font={Fonts.heavy} color={props.color} box={new UDim2(1, -28, 0, 16)} position={UDim2.fromOffset(16, 8)} />
			<Text text={props.reward} size={Type.body(props.phone)} font={Fonts.heavy} color={props.claimed ? Iron.muted() : Iron.text()} box={new UDim2(1, -28, 0, 22)} position={UDim2.fromOffset(16, 26)} />
		</frame>
	);
}

function Reader(props: { page: PageProps; entry: ChapterConfig; state: ChapterState; onClose: () => void }) {
	const { entry, state } = props;
	const phone = props.page.phone;
	// a finished chapter opens as a replay: every part can be revisited
	const [replay] = React.useState(state.Read === true || state.Claimed === true);
	const [beat, setBeat] = React.useState(0);
	const total = math.max(1, entry.Body.size());
	const last = beat >= total - 1;
	const claimed = state.Claimed === true;
	const pop = useChangePop(beat);
	// the chapter mark breathes while it's open (old ArchiveMark: usePulse 1.2, +3% scale)
	const pulse = usePulse(true, 1.2);
	useBack(true, () => {
		Audio.play("close");
		props.onClose();
	});
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
	const close = () => {
		Audio.play("close");
		props.onClose();
	};
	const hasReward = entry.Reward !== undefined;
	const actionText = last ? (claimed || !hasReward ? "Done" : "Collect reward") : "Continue";
	const action = last ? (claimed || !hasReward ? close : claim) : () => setBeat(beat + 1);
	return (
		<Panel pad={gap(phone, "xl")} spacing={gap(phone, "m")} seam rarity="Legendary" order={0}>
			<frame Size={new UDim2(1, 0, 0, 24)} BackgroundTransparency={1} LayoutOrder={0}>
				<uiscale Scale={pulse.map((a) => 1 + a * 0.03)} />
				<Text text={`${entry.Chapter ?? "Chapter"} · part ${beat + 1} / ${total}`} size={Type.small(phone)} color={entry.Color} box={UDim2.fromScale(1, 1)} />
			</frame>
			<Title text={entry.Title} size={Type.title(phone)} tags={["wave"]} order={1} />
			<Beat key={`beat${beat}`} text={entry.Body[beat] ?? ""} color={entry.Color} phone={phone} index={beat} />
			{last && hasReward && <RewardBox reward={formatReward(entry.Reward!)} claimed={claimed} color={entry.Color} phone={phone} />}
			<frame Size={new UDim2(1, 0, 0, 10)} BackgroundTransparency={1} LayoutOrder={4}>
				<uiscale Scale={pop} />
				<Meter value={(beat + 1) / total} color={entry.Color} height={6} />
			</frame>
			<Text text={replay ? "Replay: read any part" : `Part ${beat + 1} of ${total}`} size={Type.small(phone)} color={replay ? Palette.green : Iron.muted()} order={5} />
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={6}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 10)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<Button text="Back" tone="iron" width={128} disabled={beat === 0} onPress={() => setBeat(math.max(0, beat - 1))} order={0} />
				<frame {...({ Name: last && !claimed && hasReward ? "StoryClaim" : "StoryContinue" } as object)} Size={UDim2.fromOffset(phone ? 180 : 220, 48)} BackgroundTransparency={1} LayoutOrder={1}>
					<Button text={actionText} stretch height={48} glint={!claimed || !last} onPress={action} />
				</frame>
				{replay && <Button text="Close" tone="quiet" width={110} onPress={close} order={2} />}
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
					<>
					<Text text={waiting ? `Reward waiting · ${formatReward(entry.Reward!)}` : done ? "Finished chapter" : "Ready to read"} size={Type.small(phone)} color={waiting ? Iron.brass() : Iron.muted()} order={1} />
					{entry.Summary !== undefined && <Text text={entry.Summary} size={Type.small(phone)} color={Iron.muted()} multiline order={2} />}
					</>
				) : (
					<>
						<Text text={`Keep playing to unlock this chapter. ${math.floor(state.Progress ?? 0)} / ${state.Target ?? 1}`} size={Type.small(phone)} color={Iron.muted()} multiline order={1} />
						<Meter value={(state.Progress ?? 0) / math.max(1, state.Target ?? 1)} color={entry.Color} height={6} order={2} />
					</>
				)}
			</Card>
		</frame>
	);
}

function Search(props: { value: string; onChange: (v: string) => void; phone: boolean; order: number }) {
	const [focused, setFocused] = React.useState(false);
	return (
		<frame Size={new UDim2(1, 0, 0, 44)} BackgroundColor3={Iron.sunk()} BorderSizePixel={0} LayoutOrder={props.order}>
			<uicorner CornerRadius={new UDim(0, 6)} />
			<uistroke Color={focused ? Iron.brass() : Iron.edge()} Transparency={focused ? 0.1 : 0.5} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
			<textbox
				Size={new UDim2(1, -24, 1, 0)}
				Position={UDim2.fromOffset(12, 0)}
				BackgroundTransparency={1}
				Text={props.value}
				PlaceholderText="Search chapters"
				PlaceholderColor3={Iron.muted()}
				TextColor3={Iron.text()}
				FontFace={Fonts.bold}
				TextSize={Type.body(props.phone)}
				TextXAlignment={Enum.TextXAlignment.Left}
				TextTruncate={Enum.TextTruncate.AtEnd}
				ClearTextOnFocus={false}
				Selectable
				Change={{ Text: (box) => props.onChange(box.Text) }}
				Event={{ Focused: () => setFocused(true), FocusLost: () => setFocused(false) }}
			/>
		</frame>
	);
}

function matches(entry: ChapterConfig, query: string): boolean {
	if (query === "") return true;
	const needle = query.lower();
	for (const field of [entry.Title, entry.Chapter ?? "", entry.Summary ?? ""]) {
		if (field.lower().find(needle, 1, true)[0] !== undefined) return true;
	}
	return false;
}

function Column(props: { size: UDim2; order: number; pad: number; children?: React.ReactNode }) {
	return (
		<scrollingframe
			Size={props.size}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			CanvasSize={new UDim2()}
			AutomaticCanvasSize={Enum.AutomaticSize.Y}
			ScrollBarThickness={4}
			ScrollBarImageColor3={Iron.brassDeep()}
			LayoutOrder={props.order}
		>
			<uipadding PaddingTop={new UDim(0, props.pad)} PaddingBottom={new UDim(0, props.pad * 3)} PaddingLeft={new UDim(0, props.pad)} PaddingRight={new UDim(0, props.pad)} />
			<uilistlayout Padding={new UDim(0, props.pad)} SortOrder={Enum.SortOrder.LayoutOrder} />
			{props.children}
		</scrollingframe>
	);
}

export function StoryPage(props: PageProps) {
	const phone = props.phone;
	const chapters = ((props.session as unknown as { Story?: ChapterState[] }).Story ?? []) as ChapterState[];
	const configs = ((props.config as unknown as { Story?: ChapterConfig[] }).Story ?? []) as ChapterConfig[];
	const [reading, setReading] = React.useState<string | undefined>(undefined);
	const [filter, setFilter] = React.useState<Filter>("All");
	const [query, setQuery] = React.useState("");
	const byId = new Map<string, ChapterConfig>();
	for (const c of configs) byId.set(c.Id, c);
	const isNew = (c: ChapterState) => c.Unlocked === true && c.Read !== true;
	const hasReward = (c: ChapterState) => c.Unlocked === true && c.Claimed !== true && byId.get(c.Id)?.Reward !== undefined;
	const shown = chapters.filter((c) => {
		const entry = byId.get(c.Id);
		return entry !== undefined && matches(entry, query) && (filter === "All" || (filter === "New" ? isNew(c) : hasReward(c)));
	});
	const openEntry = reading !== undefined ? byId.get(reading) : undefined;
	const openState = chapters.find((c) => c.Id === reading);
	const space = gap(phone, "l");
	// the archive's orbit rings breathe while nothing is open (old: usePulse 3.4, +16px)
	const archivePulse = usePulse(openEntry === undefined, 3.4);
	const rings = (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ClipsDescendants ZIndex={0}>
			{[0, 1, 2].map((i) => (
				<frame
					key={`orbit${i}`}
					Size={archivePulse.map((a) => UDim2.fromOffset(260 + i * 82 + a * 16, 260 + i * 82 + a * 16))}
					Position={UDim2.fromScale(0.85, 0.5)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					Rotation={i * 17}
					BackgroundTransparency={1}
					ZIndex={0}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
					<uistroke Color={i === 1 ? Palette.cyan : Iron.brass()} Transparency={0.7 + i * 0.08} />
				</frame>
			))}
		</frame>
	);
	const header = (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0}>
		<Panel pad={gap(phone, "l")} spacing={gap(phone, "s")} order={0}>
			<Title text="Story" size={Type.title(phone)} tags={["wave"]} order={0} />
			<Text text="Short chapters from under Bay Seven." size={Type.small(phone)} color={Iron.muted()} order={0} />
			<Search value={query} onChange={setQuery} phone={phone} order={1} />
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<Chip text="All" on={filter === "All"} onPress={() => setFilter("All")} order={0} />
				<Chip text={`New ${chapters.filter(isNew).size()}`} on={filter === "New"} onPress={() => setFilter("New")} order={1} />
				<Chip text={`Rewards ${chapters.filter(hasReward).size()}`} on={filter === "Reward"} onPress={() => setFilter("Reward")} order={2} />
			</frame>
		</Panel>
			{rings}
		</frame>
	);
	const list = (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
			<uilistlayout Padding={new UDim(0, gap(phone, "m"))} SortOrder={Enum.SortOrder.LayoutOrder} />
			{shown.size() === 0 ? (
				<EmptyState
					title={query !== "" ? "No chapters match" : filter === "All" ? "No chapters yet" : "Nothing here"}
					body={query !== "" || filter !== "All" ? "Clear the search or pick another filter." : "Chapters open as the forge grows."}
					phone={phone}
				/>
			) : (
				shown.map((c, i) => <ChapterRow key={c.Id} entry={byId.get(c.Id)!} state={c} phone={phone} index={i} onOpen={() => setReading(c.Id)} />)
			)}
		</frame>
	);
	const reader = openEntry !== undefined && openState !== undefined ? <Reader key={openEntry.Id} page={props} entry={openEntry} state={openState} onClose={() => setReading(undefined)} /> : undefined;
	if (!phone) {
		// desktop: the archive on the left, the open chapter on the right (the old two-column layout)
		return (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} SortOrder={Enum.SortOrder.LayoutOrder} />
				<Column size={new UDim2(0.38, 0, 1, 0)} order={0} pad={space}>
					{header}
					{list}
				</Column>
				<Column size={new UDim2(0.62, 0, 1, 0)} order={1} pad={space}>
					{reader ?? <EmptyState title="Story" body="Pick a chapter, then start reading." phone={phone} />}
				</Column>
			</frame>
		);
	}
	return (
		<Column size={UDim2.fromScale(1, 1)} order={0} pad={space}>
			{reader ?? (
				<>
					{header}
					{list}
				</>
			)}
		</Column>
	);
}

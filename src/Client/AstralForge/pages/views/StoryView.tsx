// Story: the Bay Seven chapters laid out like design/19-journal (a grid of chapter cards beside a
// 430px chapter card) and, once a chapter is open, like design/20-journal-entry (the book spread with
// the typed-out part on the left and Progress / Chapter reward / Other chapters on the right).
// Unlocks, reads and claims stay server-owned (state.Story, ReadStoryChapter, ClaimStoryChapter).
// Everything is placed by list / grid layouts inside the one PageScaffold scroller.
import React from "@rbxts/react";
import { formatReward, Reward } from "../../CoreKit/format";
import { ClientLog } from "../../CoreKit/log";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { chromeFor, Palette, scrollTail, TapTarget } from "../../CoreKit/theme";
import { useEntrance, useViewport } from "../../MotionKit/motion";
import { measureWrappedTextHeight } from "../../UiCore/ui";
import { Bar, BODY, Chip, Glyph, Line, MockPanel, mockGap, NUM, PanelHeading, panelPad, spaced, TITLE_FACE } from "../../UiCore/mockKit";
import { headingBlock, MockBtn, MockRow, panelHeight, RowFace, rowHeight, useWidth } from "../mockRows";
import { FlexCol, FlexFill, FlexFixed, FlexRow, stackSum, TAB_STRIP_H, TabStrip } from "../mockLayout";
import { loadAudio, loadBrowse, loadPageScaffold } from "../luauDeps";

const UserInputService = game.GetService("UserInputService");
const Audio = loadAudio();
const Browse = loadBrowse();
const PageScaffold = loadPageScaffold();

interface StoryStatus {
	Id: string;
	Unlocked?: boolean;
	Read?: boolean;
	Claimed?: boolean;
	Progress?: number;
	Target?: number;
}
interface StoryEntry {
	Id: string;
	Title?: string;
	Chapter?: string;
	Summary?: string;
	Body?: string[];
	Color?: Color3;
	Reward?: Reward;
}
type Dispatch = (action: string, payload: { Id: string }) => unknown;
interface StoryProps {
	state: { Story?: StoryStatus[] };
	config: { Story?: StoryEntry[] };
	dispatch: Dispatch;
	reducedMotion?: boolean;
}
type Section = { id: string; height: number; element: React.Element };

const HIGHLIGHTS = ["Bay Seven", "Stellar Core", "ILYRA VALE", "Astral Forge", "Hollow Star", "stars"];
function illuminate(text: string, accent: Color3): string {
	const rgb = `${math.floor(accent.R * 255)},${math.floor(accent.G * 255)},${math.floor(accent.B * 255)}`;
	let result = text;
	for (const phrase of HIGHLIGHTS) {
		result = result.gsub(phrase, `<font color="rgb(${rgb})"><b>${phrase}</b></font>`)[0];
	}
	return result;
}

function entryOf(config: StoryProps["config"], id: string): StoryEntry | undefined {
	const list = config.Story;
	if (!typeIs(list, "table")) return undefined;
	return list.find((entry) => typeIs(entry, "table") && entry.Id === id);
}

function pickDefault(chapters: StoryStatus[]): string | undefined {
	for (const chapter of chapters) if (typeIs(chapter, "table") && chapter.Unlocked && !chapter.Claimed) return chapter.Id;
	for (const chapter of chapters) if (typeIs(chapter, "table") && chapter.Unlocked) return chapter.Id;
	return chapters[0]?.Id;
}

function chipText(status: StoryStatus): string {
	if (!status.Unlocked) return `${math.floor(status.Progress ?? 0)} of ${status.Target ?? 1}`;
	if (status.Claimed || status.Read) return "Done";
	return "New";
}

function statusText(status: StoryStatus): string {
	if (!status.Unlocked) return "Locked";
	if (status.Claimed) return "Finished";
	if (status.Read) return "Reward waiting";
	return "Ready to read";
}

// ---------- chapter card (19-journal page card: number + serif title, summary line, chip) ----------
function cardHeight(phone: boolean): number {
	return phone ? 10 + 20 + 6 + 16 + 6 + TapTarget + 10 : 14 + 22 + 8 + 18 + 8 + 28 + 14;
}

function ChapterCard(props: { status: StoryStatus; entry: StoryEntry; index: number; selected: boolean; phone: boolean; onSelect: () => void }) {
	const { status, entry, phone } = props;
	const open = status.Unlocked === true;
	const done = status.Claimed === true || status.Read === true;
	const pad = phone ? 10 : 14;
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.white} BorderSizePixel={0} LayoutOrder={props.index}>
			<RowFace outline={props.selected ? Palette.mango : undefined} strong={props.selected} />
			{done && (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.mango} BorderSizePixel={0} ZIndex={0}>
					<uicorner CornerRadius={new UDim(0, 11)} />
					<uigradient Rotation={90} Transparency={new NumberSequence(0.9, 0.98)} />
				</frame>
			)}
			<textbutton
				key="Hit"
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				Text=""
				AutoButtonColor={false}
				Selectable={true}
				ZIndex={3}
				Event={{
					Activated: () => {
						if (open) {
							props.onSelect();
							Audio.play("storyPage");
						} else {
							Audio.play("locked");
						}
					},
					MouseEnter: () => Audio.play("hover"),
					SelectionGained: () => Audio.play("hover"),
				}}
			/>
			<frame key="Content" Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={2}>
				<uipadding PaddingTop={new UDim(0, pad)} PaddingBottom={new UDim(0, pad)} PaddingLeft={new UDim(0, pad)} PaddingRight={new UDim(0, pad)} />
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, phone ? 6 : 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<FlexRow height={phone ? 20 : 22} gap={10} align={Enum.VerticalAlignment.Center} layoutOrder={0}>
					<Line text={tostring(entry.Chapter ?? props.index + 1)} size={phone ? 15 : 18} font={NUM} color={open ? Palette.mango : Palette.muted} layoutOrder={0} zIndex={2} />
					<FlexFill layoutOrder={1}>
						<Line text={entry.Title ?? entry.Id} size={phone ? 15 : 18} font={TITLE_FACE} color={open ? Palette.cream : Palette.muted} width={new UDim(1, 0)} height={phone ? 20 : 22} zIndex={2} />
					</FlexFill>
					{done && <Glyph kind="Check" size={18} color={Palette.mango} layoutOrder={2} />}
					{!open && <Glyph kind="Lock" size={16} color={Palette.muted} layoutOrder={2} />}
				</FlexRow>
				<Line text={entry.Summary ?? ""} size={phone ? 12 : 14} font={BODY} color={Palette.creamSoft} width={new UDim(1, 0)} height={phone ? 16 : 18} layoutOrder={1} zIndex={2} />
				<FlexRow height={phone ? TapTarget : 28} gap={8} align={Enum.VerticalAlignment.Center} layoutOrder={2}>
					<Chip text={chipText(status)} accent={open ? Palette.mango : undefined} phone={phone} layoutOrder={0} />
				</FlexRow>
			</frame>
		</frame>
	);
}

function graphemeCount(text: string): number {
	let count = 0;
	for (const [_] of utf8.graphemes(text)) count += 1;
	return count;
}

// ---------- the open chapter: one part typed out, Back / Continue / Collect ----------
function useReveal(text: string, key: string, reducedMotion: boolean | undefined): React.Binding<number> {
	const [visible, setVisible] = React.useBinding(0);
	React.useEffect(() => {
		let alive = true;
		setVisible(0);
		Audio.play("storyBeat");
		const length = graphemeCount(text);
		const step = math.max(1, math.floor(length / (reducedMotion ? 28 : 72)));
		const wait = reducedMotion ? 0.012 : 0.022;
		const worker = task.spawn(() => {
			let count = 0;
			while (alive && count < length) {
				count = math.min(length, count + step);
				setVisible(count);
				task.wait(wait);
			}
		});
		return () => {
			alive = false;
			pcall(() => task.cancel(worker));
		};
	}, [key, reducedMotion]);
	return visible;
}

function ReaderBook(props: {
	entry: StoryEntry;
	status: StoryStatus;
	beat: number;
	total: number;
	phone: boolean;
	replay: boolean;
	reducedMotion?: boolean;
	enter: React.Binding<number>;
	textWidth: number;
	onTextSize: (rbx: GuiObject) => void;
	onBack: () => void;
	onRewind: () => void;
	onNext: () => void;
	onClaim: () => void;
	onClose: () => void;
}) {
	const { entry, status, beat, total, phone } = props;
	const accent = entry.Color ?? Palette.mango;
	const body = entry.Body ?? [];
	const text = body[beat] ?? "";
	const visible = useReveal(text, `${entry.Id}:${beat}:${props.replay}`, props.reducedMotion);
	const final = beat >= total - 1;
	const actionText = final ? (status.Claimed ? "Done" : "Collect reward") : "Continue";
	const actionIcon = final ? (status.Claimed ? "Check" : "Gift") : "Chevron";
	const action = final ? (status.Claimed ? props.onClose : props.onClaim) : props.onNext;
	const actionsRef = React.useRef<Frame>();
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) return;
		const host = actionsRef.current;
		if (host === undefined) return;
		const job = task.defer(() => {
			if (host.Parent !== undefined) GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(() => task.cancel(job));
		};
	}, [beat, status.Claimed, actionText]);
	return (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={Palette.brass} glow={accent} reveal={props.enter} reducedMotion={props.reducedMotion} gap={0} name="StoryBook">
			<uipadding PaddingTop={new UDim(0, bookPadY(phone))} PaddingLeft={new UDim(0, phone ? 0 : 36)} PaddingRight={new UDim(0, phone ? 0 : 36)} />
			<FlexRow height={36} gap={12} align={Enum.VerticalAlignment.Center} layoutOrder={0}>
				<MockBtn text="Chapters" icon="Back.1" sec={true} sm={true} phone={phone} onClick={props.onBack} reducedMotion={props.reducedMotion} layoutOrder={0} />
				<FlexFill layoutOrder={1}>
					<Line text={spaced(`PART ${beat + 1} OF ${total}`)} size={11} color={Palette.muted} width={new UDim(1, 0)} height={36} align={Enum.TextXAlignment.Right} />
				</FlexFill>
			</FlexRow>
			<frame Size={new UDim2(1, 0, 0, 20)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1} />
			<Line text={entry.Title ?? entry.Id} size={titleSize(phone)} font={TITLE_FACE} width={new UDim(1, 0)} height={titleSize(phone)} layoutOrder={2} />
			<frame Size={new UDim2(1, 0, 0, 12)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={3} />
			<frame
				key="StoryText"
				Size={new UDim2(1, 0, 0, textHeight(text, props.textWidth, phone))}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				LayoutOrder={4}
				Change={{ AbsoluteSize: props.onTextSize }}
			>
				<uisizeconstraint MaxSize={new Vector2(TEXT_MAX_W, math.huge)} />
				<textlabel
					Size={UDim2.fromScale(1, 1)}
					BackgroundTransparency={1}
					RichText={true}
					Text={illuminate(text, accent)}
					MaxVisibleGraphemes={visible.map((count) => (count >= graphemeCount(text) ? -1 : count))}
					TextSize={bodySize(phone)}
					FontFace={BODY}
					TextColor3={Palette.creamSoft}
					TextWrapped={true}
					TextXAlignment={Enum.TextXAlignment.Left}
					TextYAlignment={Enum.TextYAlignment.Top}
					LineHeight={LINE_HEIGHT}
				/>
			</frame>
			<frame Size={new UDim2(1, 0, 0, 20)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={5} />
			<frame key="StoryActions" ref={actionsRef} Size={new UDim2(1, 0, 0, btnH(phone))} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={6}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 12)} SortOrder={Enum.SortOrder.LayoutOrder} VerticalAlignment={Enum.VerticalAlignment.Center} />
				<MockBtn text="Back" icon="Back.2" sec={true} phone={phone} width={phone ? 110 : 128} disabled={beat <= 0} onClick={props.onRewind} reducedMotion={props.reducedMotion} layoutOrder={0} />
				<MockBtn text={actionText} icon={actionIcon} accent={final && !status.Claimed ? Palette.mint : accent} phone={phone} width={phone ? 180 : 240} onClick={action} reducedMotion={props.reducedMotion} layoutOrder={1} />
			</frame>
		</MockPanel>
	);
}

const TEXT_MAX_W = 760;
const LINE_HEIGHT = 1.4;
function bookPadY(phone: boolean): number {
	return phone ? 14 : 46 - panelPad(phone).y;
}
function titleSize(phone: boolean): number {
	return phone ? 30 : 72;
}
function bodySize(phone: boolean): number {
	return phone ? 17 : 20;
}
function btnH(phone: boolean): number {
	return phone ? TapTarget : 44;
}
function textHeight(text: string, width: number, phone: boolean): number {
	const w = math.max(160, math.min(TEXT_MAX_W, width));
	return math.max(64, math.ceil(measureWrappedTextHeight(text, w, bodySize(phone), Enum.FontWeight.Medium) * LINE_HEIGHT) + 8);
}

const CATEGORY_LABELS = ["All", "New", "Reward", "Read", "Locked"];

export function StoryView(props: StoryProps) {
	const { state, config, dispatch, reducedMotion } = props;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const phone = chrome.contentStack;
	const enter = useEntrance(reducedMotion);
	const chapters = (typeIs(state.Story, "table") ? state.Story : []).filter((chapter) => typeIs(chapter, "table"));
	const [selectedId, setSelectedId] = React.useState<string | undefined>(() => pickDefault(chapters));
	const [started, setStarted] = React.useState(false);
	const [beat, setBeat] = React.useState(0);
	const [textWidth, onTextSize] = useWidth(phone ? 320 : 720);

	React.useEffect(() => {
		Audio.play("storyOpen");
		ClientLog.debug("nav", "story opened");
	}, []);
	React.useEffect(() => {
		if (selectedId === undefined || chapters.find((chapter) => chapter.Id === selectedId) === undefined) {
			setSelectedId(pickDefault(chapters));
			setStarted(false);
			setBeat(0);
		}
	}, [state.Story, selectedId]);
	React.useEffect(() => {
		if (started && selectedId !== undefined) ClientLog.debug("story", `${selectedId} beat ${beat + 1}`);
	}, [beat, selectedId, started]);

	const browse = Browse.useBrowse<StoryStatus>({
		id: "Story",
		items: chapters,
		text: (chapter) => {
			const entry = entryOf(config, chapter.Id);
			return [entry?.Title ?? chapter.Id, entry?.Chapter, entry?.Summary];
		},
		categories: [
			{ id: "All", label: "All" },
			{ id: "New", label: "New", test: (chapter) => chapter.Unlocked === true && chapter.Read !== true },
			{ id: "Reward", label: "Reward", test: (chapter) => chapter.Unlocked === true && chapter.Claimed !== true && chapter.Read === true },
			{ id: "Read", label: "Read", test: (chapter) => chapter.Read === true },
			{ id: "Locked", label: "Locked", test: (chapter) => chapter.Unlocked !== true },
		],
	});
	// a deep link from Quick Find opens the best match directly
	React.useEffect(() => {
		const top = browse.results[0];
		if (browse.searching && browse.relevance === true && top !== undefined && top.Id !== selectedId) {
			setSelectedId(top.Id);
			setStarted(false);
			setBeat(0);
		}
	}, [browse.query]);

	const status = chapters.find((chapter) => chapter.Id === selectedId);
	const story = status !== undefined ? entryOf(config, status.Id) : undefined;
	if (status === undefined || story === undefined) {
		return <frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} />;
	}
	const body = typeIs(story.Body, "table") ? story.Body : [];
	const total = math.max(1, body.size());
	const finished = status.Read === true || status.Claimed === true;
	const locked = status.Unlocked !== true;
	const rewardText = formatReward(story.Reward);
	const gap = mockGap(phone);
	const pad = panelPad(phone);
	const head = headingBlock(phone);
	const rowH = rowHeight(phone);
	const bH = btnH(phone);

	const begin = () => {
		if (locked) return;
		setBeat(0);
		setStarted(true);
		Audio.play("storyOpen");
		if (status.Read !== true) dispatch("ReadStoryChapter", { Id: story.Id });
	};
	const closeReader = () => {
		Audio.play("close");
		setStarted(false);
		setBeat(0);
	};
	const selectChapter = (id: string) => {
		Audio.play("page");
		setSelectedId(id);
		setStarted(false);
		setBeat(0);
	};
	const advance = () => {
		Audio.play("storyReveal");
		setBeat(math.min(total - 1, beat + 1));
	};
	const rewind = () => {
		Audio.play("close");
		setBeat(math.max(0, beat - 1));
	};
	const claim = () => {
		ClientLog.debug("story", `claim ${story.Id}`);
		dispatch("ClaimStoryChapter", { Id: story.Id });
	};

	let claimedCount = 0;
	let openCount = 0;
	for (const chapter of chapters) {
		if (chapter.Unlocked) openCount += 1;
		if (chapter.Claimed) claimedCount += 1;
	}
	const rewardRow = (order: number) => (
		<MockRow
			phone={phone}
			icon="Gift"
			title={rewardText !== "" ? rewardText : "No reward"}
			value={status.Claimed ? "Claimed" : finished ? "Ready" : undefined}
			valueColor={status.Claimed ? Palette.muted : Palette.mint}
			dim={rewardText === ""}
			layoutOrder={order}
		/>
	);

	// ---------- reading: the 20-journal-entry spread ----------
	if (started) {
		const text = body[beat] ?? "";
		const bookContent = 36 + 20 + titleSize(phone) + 12 + textHeight(text, textWidth, phone) + 20 + bH;
		const bookH = panelHeight(phone, bookContent + bookPadY(phone) * 2);
		const book = (
			<ReaderBook
				key={story.Id}
				entry={story}
				status={status}
				beat={beat}
				total={total}
				phone={phone}
				replay={finished}
				reducedMotion={reducedMotion}
				enter={enter}
				textWidth={textWidth}
				onTextSize={onTextSize}
				onBack={closeReader}
				onRewind={rewind}
				onNext={advance}
				onClaim={claim}
				onClose={closeReader}
			/>
		);
		const progressH = panelHeight(phone, head + rowH + pad.gap + 10);
		const progressPanel = (
			<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} reducedMotion={reducedMotion} name="StoryProgress">
				<PanelHeading icon="Milestone" title="Progress" phone={phone} layoutOrder={0} />
				<MockRow phone={phone} icon="Story.4" title={finished ? "Replay" : "Parts read"} value={`${beat + 1} of ${total}`} layoutOrder={1} />
				<Bar fill={(beat + 1) / total} color={story.Color ?? Palette.mango} layoutOrder={2} />
			</MockPanel>
		);
		const rewardH = panelHeight(phone, head + rowH);
		const rewardPanel = (
			<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} reducedMotion={reducedMotion} name="StoryReward">
				<PanelHeading icon="Gift" title="Chapter reward" phone={phone} layoutOrder={0} />
				{rewardRow(1)}
			</MockPanel>
		);
		const others = chapters.filter((chapter) => chapter.Id !== status.Id && chapter.Unlocked === true && chapter.Claimed !== true);
		const nearby = others.filter((_, index) => index < 3);
		const nearbyCount = math.max(1, nearby.size());
		const nearbyH = panelHeight(phone, head + stackSum(table.create(nearbyCount, rowH), pad.gap));
		const nearbyPanel = (
			<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} reducedMotion={reducedMotion} name="StoryNearby">
				<PanelHeading icon="Journal" title="Other chapters" phone={phone} layoutOrder={0} />
				{nearby.size() === 0 ? (
					<MockRow phone={phone} icon="Check" title="Nothing else waiting" dim={true} layoutOrder={1} />
				) : (
					nearby.map((other, index) => (
						<frame key={other.Id} Size={new UDim2(1, 0, 0, rowH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1 + index}>
							<MockRow phone={phone} icon="Story.3" title={entryOf(config, other.Id)?.Title ?? other.Id} value={chipText(other)} />
							<textbutton Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} Text="" ZIndex={3} Event={{ Activated: () => selectChapter(other.Id) }} />
						</frame>
					))
				)}
			</MockPanel>
		);
		const sections: Section[] = [];
		if (phone) {
			sections.push({ id: "book", height: bookH, element: book });
			sections.push({ id: "progress", height: progressH, element: progressPanel });
			sections.push({ id: "reward", height: rewardH, element: rewardPanel });
			sections.push({ id: "nearby", height: nearbyH, element: nearbyPanel });
		} else {
			const sideH = stackSum([progressH, rewardH, nearbyH], gap);
			const bodyH = math.max(bookH, sideH);
			sections.push({
				id: "spread",
				height: bodyH,
				element: (
					<FlexRow fillHeight={true} gap={gap} name="StorySpread">
						<FlexFill layoutOrder={0}>{book}</FlexFill>
						<FlexFixed width={460} layoutOrder={1}>
							<FlexCol fill={true} gap={gap}>
								<FlexFixed width={460} height={progressH} layoutOrder={0}>
									{progressPanel}
								</FlexFixed>
								<FlexFixed width={460} height={rewardH} layoutOrder={1}>
									{rewardPanel}
								</FlexFixed>
								<FlexFixed width={460} height={math.max(nearbyH, bodyH - progressH - rewardH - gap * 2)} layoutOrder={2}>
									{nearbyPanel}
								</FlexFixed>
							</FlexCol>
						</FlexFixed>
					</FlexRow>
				),
			});
		}
		return (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
				<PageScaffold gap={gap} tailPad={scrollTail(phone, chrome.bottomSafe, 24)} scrollBarColor={Palette.brass} scrollBarThickness={4} sections={sections} owner="StoryReader" />
			</frame>
		);
	}

	// ---------- browsing: the 19-journal chapter grid + chapter card ----------
	const shown: { status: StoryStatus; entry: StoryEntry }[] = [];
	for (const chapter of browse.results) {
		const entry = entryOf(config, chapter.Id);
		if (entry !== undefined) shown.push({ status: chapter, entry });
	}
	const columns = phone ? 2 : 3;
	const cellGap = phone ? 8 : 12;
	const cellH = cardHeight(phone);
	const gridRows = math.ceil(shown.size() / columns);
	const gridH = gridRows * cellH + math.max(0, gridRows - 1) * cellGap;
	const mainContent = head + (shown.size() > 0 ? gridH : rowH) + pad.gap + 10;
	const mainH = panelHeight(phone, mainContent);
	const mainPanel = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} reveal={enter} reducedMotion={reducedMotion} name="StoryChapters">
			<PanelHeading icon="Story.2" title="Bay Seven" note={`${claimedCount} of ${chapters.size()} archived · ${openCount} open`} phone={phone} layoutOrder={0} />
			{shown.size() > 0 ? (
				<frame key="ChapterGrid" Size={new UDim2(1, 0, 0, gridH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
					<uigridlayout
						CellSize={new UDim2(1 / columns, -math.ceil((cellGap * (columns - 1)) / columns), 0, cellH)}
						CellPadding={UDim2.fromOffset(cellGap, cellGap)}
						FillDirectionMaxCells={columns}
						SortOrder={Enum.SortOrder.LayoutOrder}
					/>
					{shown.map((item, index) => (
						<ChapterCard
							key={item.status.Id}
							status={item.status}
							entry={item.entry}
							index={index}
							selected={item.status.Id === status.Id}
							phone={phone}
							onSelect={() => selectChapter(item.status.Id)}
						/>
					))}
				</frame>
			) : (
				<MockRow phone={phone} icon="Search" title="No chapters here yet" dim={true} layoutOrder={1} />
			)}
			<Bar fill={claimedCount / math.max(1, chapters.size())} color={Palette.mango} layoutOrder={2} />
		</MockPanel>
	);

	const sideW = phone ? 0 : 430;
	const summary = story.Summary ?? "";
	const summarySize = phone ? 13 : 15;
	const summaryH = math.max(20, math.ceil(measureWrappedTextHeight(summary, math.max(160, (phone ? viewport.width - 48 : sideW - pad.x * 2)), summarySize) * 1.3));
	const titleH = phone ? 26 : 32;
	const sideContent = head + titleH + pad.gap + summaryH + pad.gap + rowH + (locked ? pad.gap + 10 : 0) + pad.gap + rowH + pad.gap + bH;
	const sideH = panelHeight(phone, sideContent);
	const side = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} glow={story.Color} reveal={enter} reducedMotion={reducedMotion} name="StoryChapter">
			<PanelHeading icon="Story.3" title="Chapter" note={story.Chapter} accent={story.Color} phone={phone} layoutOrder={0} />
			<Line text={story.Title ?? story.Id} size={phone ? 22 : 28} font={TITLE_FACE} width={new UDim(1, 0)} height={titleH} layoutOrder={1} />
			<textlabel
				Size={new UDim2(1, 0, 0, summaryH)}
				BackgroundTransparency={1}
				Text={summary}
				TextSize={summarySize}
				FontFace={BODY}
				TextColor3={Palette.creamSoft}
				TextWrapped={true}
				TextXAlignment={Enum.TextXAlignment.Left}
				TextYAlignment={Enum.TextYAlignment.Top}
				LineHeight={1.2}
				LayoutOrder={2}
			/>
			<MockRow phone={phone} icon={locked ? "Lock" : "Story.4"} title={statusText(status)} value={locked ? chipText(status) : `${total} parts`} dim={locked} layoutOrder={3} />
			{locked && <Bar fill={math.clamp((status.Progress ?? 0) / math.max(1, status.Target ?? 1), 0, 1)} color={story.Color ?? Palette.mango} layoutOrder={4} />}
			{rewardRow(5)}
			<MockBtn
				text={locked ? "Locked" : finished ? "Replay" : "Start reading"}
				icon={locked ? "Lock" : "Story.4"}
				accent={story.Color ?? Palette.mango}
				fill={true}
				phone={phone}
				disabled={locked}
				onClick={begin}
				reducedMotion={reducedMotion}
				layoutOrder={6}
			/>
		</MockPanel>
	);

	const options = CATEGORY_LABELS.map((id) => {
		const count = browse.counts[id];
		return { id, label: count !== undefined && id !== "All" ? `${id} ${count}` : id };
	});
	const sections: Section[] = [
		{
			id: "tabs",
			height: TAB_STRIP_H,
			element: (
				<TabStrip
					options={options}
					value={browse.category}
					onChange={(id) => browse.setCategory(id)}
					accent={Palette.mango}
					phone={phone}
					note={`${shown.size()} of ${chapters.size()} chapters`}
					width={phone ? math.min(viewport.width - 24, 420) : 560}
					reducedMotion={reducedMotion}
				/>
			),
		},
	];
	if (phone) {
		sections.push({ id: "chapter", height: sideH, element: side });
		sections.push({ id: "chapters", height: mainH, element: mainPanel });
	} else {
		const bodyH = math.max(mainH, sideH);
		sections.push({
			id: "body",
			height: bodyH,
			element: (
				<FlexRow fillHeight={true} gap={gap} name="StoryBody">
					<FlexFill layoutOrder={0}>
						<frame Size={new UDim2(1, 0, 0, mainH)} BackgroundTransparency={1} BorderSizePixel={0}>
							{mainPanel}
						</frame>
					</FlexFill>
					<FlexFixed width={sideW} height={sideH} layoutOrder={1}>
						{side}
					</FlexFixed>
				</FlexRow>
			),
		});
	}
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<PageScaffold gap={gap} tailPad={scrollTail(phone, chrome.bottomSafe, 24)} scrollBarColor={Palette.brass} scrollBarThickness={4} sections={sections} owner="StoryView" />
		</frame>
	);
}

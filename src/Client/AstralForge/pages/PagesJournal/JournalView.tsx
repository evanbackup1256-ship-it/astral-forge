// Journal: the milestone goals read as a book. Every six milestones (in config order) make a
// chapter; a page is filled when its milestone is claimed. Progress and claims stay server-owned
// (state.Achievements, ClaimAchievement), so nothing new is saved. Tabs: Pages (the chapter grid),
// Goals (open pages, closest first) and Keepsakes (finished chapters). Opening a page shows the
// entry spread: line-art star map on the left, goal text, progress, reward and nearby pages.
import React from "@rbxts/react";
import { compactNumber, formatReward, Reward } from "../../CoreKit/format";
import { chromeFor, Palette, scrollTail, TapTarget } from "../../CoreKit/theme";
import { useEntrance, useFlash, useViewport } from "../../MotionKit/motion";
import { kitMember, LuauComponent } from "../luauKits";
import { Bar, BODY, Chip, Glyph, Line, MockPanel, mockGap, NUM, PanelHeading, panelPad, spaced, TITLE_FACE } from "../../UiCore/mockKit";
import { headingBlock, MockBtn, MockRow, panelHeight, RowFace, rowHeight } from "../mockRows";
import { FlexCol, FlexFill, FlexFixed, FlexRow, stackSum, TAB_STRIP_H, TabStrip } from "../mockLayout";

import { MotionFX } from "../../UiCore/screenFx";

const { PageScaffold } = kitMember<{ PageScaffold: LuauComponent }>("LayoutKit", "pageScaffold");
const PAGES_PER_CHAPTER = 6;

interface Entry {
	Id: string;
	Name: string;
	Description?: string;
	Reward?: Reward;
	Claimed: boolean;
	Progress: number;
	Target: number;
}
interface JournalPage {
	entry: Entry;
	number: number;
	chapter: number;
	done: boolean;
	ready: boolean;
	fraction: number;
}
interface Chapter {
	index: number;
	pages: JournalPage[];
	filled: number;
}
type Dispatch = (action: string, payload: { Id: string }, callback?: (response: { ok?: boolean }) => void) => unknown;
interface JournalProps {
	state: { Achievements?: Entry[] };
	dispatch: Dispatch;
	reducedMotion?: boolean;
	navigate?: (page: string) => unknown;
}

function buildChapters(list: Entry[]): Chapter[] {
	const chapters: Chapter[] = [];
	list.forEach((entry, index) => {
		if (!typeIs(entry, "table")) return;
		const chapterIndex = math.floor(index / PAGES_PER_CHAPTER);
		let chapter = chapters[chapterIndex];
		if (chapter === undefined) {
			chapter = { index: chapterIndex, pages: [], filled: 0 };
			chapters[chapterIndex] = chapter;
		}
		const target = math.max(1, entry.Target);
		const page: JournalPage = {
			entry,
			number: index + 1,
			chapter: chapterIndex,
			done: entry.Claimed === true,
			ready: entry.Claimed !== true && entry.Progress >= target,
			fraction: entry.Claimed ? 1 : math.clamp(entry.Progress / target, 0, 1),
		};
		chapter.pages.push(page);
		if (page.done) chapter.filled += 1;
	});
	return chapters;
}

function chipText(page: JournalPage): string {
	if (page.done) return "Done";
	if (page.ready) return "Ready";
	return `${compactNumber(page.entry.Progress)} of ${compactNumber(page.entry.Target)}`;
}

function rewardLines(reward: Reward | undefined): string[] {
	const lines: string[] = [];
	if (reward === undefined) return lines;
	for (const [key, value] of pairs(reward as unknown as Record<string, unknown>)) {
		const one = formatReward({ [key]: value } as unknown as Reward);
		if (one !== "") lines.push(one);
	}
	lines.sort();
	return lines;
}

// ---------- star map line art (built in code) ----------
function hash(text: string): number {
	let seed = 7;
	for (let i = 1; i <= text.size(); i++) seed = (seed * 31 + string.byte(text, i)[0]) % 1000003;
	return seed;
}
function starPoints(id: string, count: number, w: number, h: number): Vector2[] {
	let seed = hash(id);
	const points: Vector2[] = [];
	for (let i = 0; i < count; i++) {
		seed = (seed * 1103 + 12345) % 1000003;
		const x = 0.06 + (0.88 * i) / math.max(1, count - 1);
		const y = 0.15 + ((seed % 1000) / 1000) * 0.7;
		points.push(new Vector2(x * w, y * h));
	}
	return points;
}

function StarMap(props: { id: string; fraction: number; width: number; height: number; reducedMotion?: boolean }) {
	const count = 7;
	const points = starPoints(props.id, count, props.width, props.height);
	const lit = math.clamp(math.floor(props.fraction * count + 1e-6), props.fraction > 0 ? 1 : 0, count);
	const dots = React.useRef<Frame[]>([]);
	React.useEffect(() => {
		if (props.reducedMotion) return;
		const tweens: Tween[] = [];
		dots.current.forEach((dot, index) => {
			if (index >= lit) return;
			const tween = MotionFX.tween(dot, new TweenInfo(2 + (index % 4), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				BackgroundTransparency: 0.45,
			}, false);
			if (tween) tweens.push(tween);
		});
		return () => tweens.forEach((tween) => tween.Cancel());
	}, [props.id, lit, props.reducedMotion]);
	const segments: React.Element[] = [];
	for (let i = 0; i < count - 1; i++) {
		const a = points[i];
		const b = points[i + 1];
		const mid = a.add(b).div(2);
		const delta = b.sub(a);
		const solid = i + 1 < lit;
		segments.push(
			<frame
				key={`Seg${i}`}
				Size={UDim2.fromOffset(delta.Magnitude, solid ? 2 : 1)}
				Position={UDim2.fromOffset(mid.X, mid.Y)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Rotation={math.deg(math.atan2(delta.Y, delta.X))}
				BackgroundColor3={solid ? Palette.cream : Palette.lineSoft}
				BackgroundTransparency={solid ? 0.15 : 0.55}
				BorderSizePixel={0}
			/>,
		);
	}
	return (
		<frame Size={UDim2.fromOffset(props.width, props.height)} Position={UDim2.fromScale(0.5, 0.5)} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundTransparency={1}>
			{segments}
			{points.map((point, index) => (
				<frame
					key={`Star${index}`}
					ref={(dot: Frame | undefined) => {
						if (dot) dots.current[index] = dot;
					}}
					Size={UDim2.fromOffset(index < lit ? 10 : 8, index < lit ? 10 : 8)}
					Position={UDim2.fromOffset(point.X, point.Y)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundColor3={index < lit ? Palette.cream : Palette.ink}
					BackgroundTransparency={0}
					BorderSizePixel={0}
					ZIndex={2}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
					{index >= lit && <uistroke Color={Palette.creamSoft} Thickness={1} Transparency={0.2} />}
				</frame>
			))}
		</frame>
	);
}

// ---------- page card (19-journal .row column: number + serif title + check, goal line, chip) ----------
const CARD_PAD = 14;
function cardHeight(phone: boolean): number {
	// padding, title line 22, gap 8, goal line 18, gap 8, chip / claim slot 36, padding
	return phone ? 10 + 20 + 6 + 16 + 6 + TapTarget + 10 : CARD_PAD + 22 + 8 + 18 + 8 + 36 + CARD_PAD;
}

function PageCard(props: { page: JournalPage; phone: boolean; onOpen: () => void; onClaim: () => void; reducedMotion?: boolean; layoutOrder?: number }) {
	const { page, phone } = props;
	// page stamp: 180 ms scale 1.15 -> 1 when the page fills
	const [stampNonce, setStampNonce] = React.useState(0);
	const wasDone = React.useRef(page.done);
	React.useEffect(() => {
		if (page.done && !wasDone.current) setStampNonce((value) => value + 1);
		wasDone.current = page.done;
	}, [page.done]);
	const stamp = useFlash(stampNonce, props.reducedMotion === true, 0.18);
	const pad = phone ? 10 : CARD_PAD;
	const lit = page.done || page.ready;
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.white} BorderSizePixel={0} LayoutOrder={props.layoutOrder ?? 0} key={`Page${page.number}`}>
			<RowFace outline={page.ready ? Palette.mint : undefined} />
			{lit && (
				// background:linear-gradient(180deg, mango .10, white .02)
				<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.mango} BorderSizePixel={0} ZIndex={0}>
					<uicorner CornerRadius={new UDim(0, 11)} />
					<uigradient Rotation={90} Transparency={new NumberSequence(0.9, 0.98)} />
				</frame>
			)}
			<textbutton Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} Text="" ZIndex={1} Event={{ Activated: () => props.onOpen() }} />
			<frame key="Content" Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={2}>
			<uipadding PaddingTop={new UDim(0, pad)} PaddingBottom={new UDim(0, pad)} PaddingLeft={new UDim(0, pad)} PaddingRight={new UDim(0, pad)} />
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, phone ? 6 : 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
			<FlexRow height={phone ? 20 : 22} gap={10} align={Enum.VerticalAlignment.Center} layoutOrder={0}>
				<Line text={tostring(page.number)} size={phone ? 15 : 18} font={NUM} color={Palette.mango} layoutOrder={0} zIndex={2} />
				<FlexFill layoutOrder={1}>
					<Line text={page.entry.Name} size={phone ? 15 : 18} font={TITLE_FACE} width={new UDim(1, 0)} height={phone ? 20 : 22} zIndex={2} />
				</FlexFill>
				{page.done && (
					<frame Size={UDim2.fromOffset(18, 18)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
						<uiscale Scale={stamp.map((t) => 1 + 0.15 * t)} />
						<Glyph kind="Check" size={18} color={Palette.mango} />
					</frame>
				)}
			</FlexRow>
			<Line text={page.entry.Description ?? ""} size={phone ? 12 : 14} font={BODY} color={Palette.creamSoft} width={new UDim(1, 0)} height={phone ? 16 : 18} layoutOrder={1} zIndex={2} />
			<FlexRow height={phone ? TapTarget : 36} gap={8} align={Enum.VerticalAlignment.Center} layoutOrder={2}>
				{page.ready ? (
					<MockBtn text="Claim" icon="Gift" accent={Palette.mint} sm={true} phone={phone} onClick={props.onClaim} reducedMotion={props.reducedMotion} layoutOrder={0} />
				) : (
					<Chip text={chipText(page)} accent={page.done ? Palette.mango : undefined} phone={phone} layoutOrder={0} />
				)}
			</FlexRow>
			</frame>
		</frame>
	);
}

function rewardRows(lines: string[], phone: boolean, value: string, first: number, empty: string): React.Element[] {
	if (lines.size() === 0) return [<MockRow key="none" phone={phone} icon="Gift" title={empty} dim={true} layoutOrder={first} />];
	return lines.map((line, index) => <MockRow key={`r${index}`} phone={phone} icon="Gift" title={line} value={value !== "" ? value : undefined} layoutOrder={first + index} />);
}

// ---------- entry spread (20-journal-entry: book page f1, 460px column of Progress / Page reward / Nearby) ----------
function EntryView(props: {
	page: JournalPage;
	total: number;
	nearby: JournalPage[];
	phone: boolean;
	bottomSafe: number;
	onBack: () => void;
	onOpen: (id: string) => void;
	onClaim: () => void;
	reducedMotion?: boolean;
	enter: React.Binding<number>;
}) {
	const { page, phone } = props;
	const gap = mockGap(phone);
	const pad = panelPad(phone);
	const head = headingBlock(phone);
	const rowH = rowHeight(phone);
	const btnH = phone ? TapTarget : 44;
	const rewards = rewardLines(page.entry.Reward);
	const artH = phone ? 150 : 260;
	const titleSize = phone ? 30 : 72;
	const descH = phone ? 40 : 60;
	const bookPadY = phone ? 14 : 46 - pad.y;
	const bookContent = 36 + 20 + titleSize + 12 + descH + 12 + artH;
	const bookH = panelHeight(phone, bookContent + bookPadY * 2);

	const book = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={Palette.brass} glow={Palette.mango} reveal={props.enter} reducedMotion={props.reducedMotion} gap={0} name="EntryBook">
			<uipadding PaddingTop={new UDim(0, bookPadY)} PaddingLeft={new UDim(0, phone ? 0 : 36)} PaddingRight={new UDim(0, phone ? 0 : 36)} />
			<FlexRow height={36} gap={12} align={Enum.VerticalAlignment.Center} layoutOrder={0}>
				<MockBtn text="Journal" icon="Back.1" sec={true} sm={true} phone={phone} onClick={props.onBack} reducedMotion={props.reducedMotion} layoutOrder={0} />
				<FlexFill layoutOrder={1}>
					<Line text={spaced(`PAGE ${page.number} OF ${props.total}`)} size={11} color={Palette.muted} width={new UDim(1, 0)} height={36} align={Enum.TextXAlignment.Right} />
				</FlexFill>
			</FlexRow>
			<frame Size={new UDim2(1, 0, 0, 20)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1} />
			<Line text={page.entry.Name} size={titleSize} font={TITLE_FACE} width={new UDim(1, 0)} height={titleSize} layoutOrder={2} />
			<frame Size={new UDim2(1, 0, 0, 12)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={3} />
			<frame Size={new UDim2(1, 0, 0, descH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={4}>
				<uisizeconstraint MaxSize={new Vector2(720, math.huge)} />
				<textlabel
					Size={UDim2.fromScale(1, 1)}
					BackgroundTransparency={1}
					Text={page.entry.Description ?? ""}
					TextSize={phone ? 14 : 20}
					FontFace={BODY}
					TextColor3={Palette.creamSoft}
					TextWrapped={true}
					TextXAlignment={Enum.TextXAlignment.Left}
					TextYAlignment={Enum.TextYAlignment.Top}
					LineHeight={1.25}
				/>
			</frame>
			<frame Size={new UDim2(1, 0, 0, 12)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={5} />
			<frame Size={new UDim2(1, 0, 0, artH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={6} key="StarMap">
				<StarMap id={page.entry.Id} fraction={page.fraction} width={phone ? 300 : 620} height={artH} reducedMotion={props.reducedMotion} />
			</frame>
		</MockPanel>
	);

	const progressH = panelHeight(phone, head + rowH + pad.gap + 10 + (page.ready ? pad.gap + btnH : 0));
	const progressPanel = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} reducedMotion={props.reducedMotion} name="EntryProgress">
			<PanelHeading icon="Milestone" title="Progress" phone={phone} layoutOrder={0} />
			<MockRow phone={phone} icon="StarGrid" title={page.done ? "Filled" : "Progress"} value={chipText(page)} layoutOrder={1} />
			<Bar fill={page.fraction} color={Palette.mango} layoutOrder={2} />
			{page.ready && <MockBtn text="Claim page" icon="Gift" fill={true} phone={phone} onClick={props.onClaim} reducedMotion={props.reducedMotion} layoutOrder={3} />}
		</MockPanel>
	);
	const rewardH = panelHeight(phone, head + stackSum(rewards.size() === 0 ? [rowH] : rewards.map(() => rowH), pad.gap));
	const rewardPanel = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} reducedMotion={props.reducedMotion} name="EntryReward">
			<PanelHeading icon="Gift" title="Page reward" phone={phone} layoutOrder={0} />
			{rewardRows(rewards, phone, page.done ? "Claimed" : "", 1, "No reward on this page")}
		</MockPanel>
	);
	const nearbyCount = math.max(1, props.nearby.size());
	const nearbyH = panelHeight(phone, head + nearbyCount * rowH + (nearbyCount - 1) * pad.gap);
	const nearbyPanel = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} reducedMotion={props.reducedMotion} name="EntryNearby">
			<PanelHeading icon="Journal" title="Nearby pages" phone={phone} layoutOrder={0} />
			{props.nearby.size() === 0 ? (
				<MockRow phone={phone} icon="Check" title="Every other page is filled" dim={true} layoutOrder={1} />
			) : (
				props.nearby.map((other, index) => (
					<frame key={other.entry.Id} Size={new UDim2(1, 0, 0, rowH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1 + index}>
						<MockRow phone={phone} icon="Journal" title={other.entry.Name} value={chipText(other)} />
						<textbutton Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} Text="" ZIndex={3} Event={{ Activated: () => props.onOpen(other.entry.Id) }} />
					</frame>
				))
			)}
		</MockPanel>
	);

	const sideHeights = [progressH, rewardH, nearbyH];
	const sideH = stackSum(sideHeights, gap);
	const sections: { id: string; height: number; element: React.Element }[] = [];
	if (phone) {
		sections.push({ id: "book", height: bookH, element: book });
		sections.push({ id: "progress", height: progressH, element: progressPanel });
		sections.push({ id: "reward", height: rewardH, element: rewardPanel });
		sections.push({ id: "nearby", height: nearbyH, element: nearbyPanel });
	} else {
		const bodyH = math.max(bookH, sideH);
		sections.push({
			id: "spread",
			height: bodyH,
			element: (
				<FlexRow fillHeight={true} gap={gap} name="EntrySpread">
					<FlexFill layoutOrder={0}>{book}</FlexFill>
					<FlexFixed width={460} layoutOrder={1}>
						<FlexCol fill={true} gap={gap}>
							<FlexFixed width={460} height={progressH} layoutOrder={0}>
								{progressPanel}
							</FlexFixed>
							<FlexFixed width={460} height={rewardH} layoutOrder={1}>
								{rewardPanel}
							</FlexFixed>
							{/* .pn.f1: the nearby list takes what is left of the column */}
							<FlexFixed width={460} height={math.max(nearbyH, bodyH - progressH - rewardH - gap * 2)} layoutOrder={2}>
								{nearbyPanel}
							</FlexFixed>
						</FlexCol>
					</FlexFixed>
				</FlexRow>
			),
		});
	}
	return <PageScaffold gap={gap} tailPad={scrollTail(phone, props.bottomSafe, 24)} scrollBarColor={Palette.brass} scrollBarThickness={4} sections={sections} owner="JournalEntry" />;
}

const TABS = [
	{ id: "Pages", label: "Pages" },
	{ id: "Goals", label: "Goals" },
	{ id: "Keepsakes", label: "Keepsakes" },
];

export function JournalView(props: JournalProps) {
	const { state, dispatch, reducedMotion } = props;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const phone = chrome.contentStack;
	const enter = useEntrance(reducedMotion);
	const [tab, setTab] = React.useState("Pages");
	const [openId, setOpenId] = React.useState<string | undefined>(undefined);
	const [chapterPick, setChapterPick] = React.useState<number | undefined>(undefined);

	const list = state.Achievements ?? [];
	const chapters = buildChapters(list);
	const allPages: JournalPage[] = [];
	for (const chapter of chapters) for (const page of chapter.pages) allPages.push(page);
	const filledTotal = allPages.filter((page) => page.done).size();
	let current = chapters.find((chapter) => chapter.filled < chapter.pages.size()) ?? chapters[chapters.size() - 1];
	if (chapterPick !== undefined && chapters[chapterPick] !== undefined) current = chapters[chapterPick];
	const claim = (id: string) => dispatch("ClaimAchievement", { Id: id });
	const gap = mockGap(phone);
	const pad = panelPad(phone);
	const head = headingBlock(phone);
	const rowH = rowHeight(phone);
	const btnH = phone ? TapTarget : 44;

	const opened = openId !== undefined ? allPages.find((page) => page.entry.Id === openId) : undefined;
	if (opened !== undefined) {
		const nearby: JournalPage[] = [];
		for (const delta of [1, -1, 2, -2, 3]) {
			const other = allPages[opened.number - 1 + delta];
			if (other !== undefined && !other.done && nearby.size() < 2) nearby.push(other);
		}
		return (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
				<EntryView
					key={opened.entry.Id}
					page={opened}
					total={allPages.size()}
					nearby={nearby}
					phone={phone}
					bottomSafe={chrome.bottomSafe}
					onBack={() => setOpenId(undefined)}
					onOpen={setOpenId}
					onClaim={() => claim(opened.entry.Id)}
					reducedMotion={reducedMotion}
					enter={enter}
				/>
			</frame>
		);
	}

	// which pages the main panel lists
	let shown: JournalPage[] = [];
	let panelTitle = "";
	let panelCount = "";
	if (tab === "Pages" && current !== undefined) {
		shown = current.pages;
		panelTitle = `Chapter ${current.index + 1}`;
		panelCount = `${current.filled} of ${current.pages.size()} pages`;
	} else if (tab === "Goals") {
		shown = allPages.filter((page) => !page.done);
		shown.sort((a, b) => (a.ready !== b.ready ? a.ready : a.fraction > b.fraction));
		panelTitle = "Open pages";
		panelCount = `${shown.size()} left`;
	}
	const columns = phone ? 2 : 3;
	const cellH = cardHeight(phone);
	const cellGap = phone ? 6 : 12;
	const rows = math.max(1, math.ceil(shown.size() / columns));
	const gridH = rows * cellH + (rows - 1) * cellGap;
	const navH = phone ? TapTarget : 36;

	let mainPanel: React.Element;
	let mainH: number;
	if (tab === "Keepsakes") {
		const finished = chapters.filter((chapter) => chapter.filled === chapter.pages.size() && chapter.pages.size() > 0);
		const count = math.max(1, finished.size());
		mainH = panelHeight(phone, head + count * rowH + (count - 1) * pad.gap);
		mainPanel = (
			<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} reveal={enter} reducedMotion={reducedMotion} name="Keepsakes">
				<PanelHeading icon="Loadout" title="Finished chapters" note={`${finished.size()} kept`} phone={phone} layoutOrder={0} />
				{finished.size() === 0 ? (
					<MockRow phone={phone} icon="Lock" title="Fill every page in a chapter and it is kept here." dim={true} layoutOrder={1} />
				) : (
					finished.map((chapter, index) => (
						<frame key={`C${chapter.index}`} Size={new UDim2(1, 0, 0, rowH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1 + index}>
							<MockRow
								phone={phone}
								icon="Loadout"
								title={`Chapter ${chapter.index + 1}`}
								sub={`Pages ${chapter.pages[0].number} to ${chapter.pages[chapter.pages.size() - 1].number}`}
								height={rowH}
								value="Filled"
							/>
							<textbutton
								Size={UDim2.fromScale(1, 1)}
								BackgroundTransparency={1}
								Text=""
								ZIndex={3}
								Event={{
									Activated: () => {
										setChapterPick(chapter.index);
										setTab("Pages");
									},
								}}
							/>
						</frame>
					))
				)}
			</MockPanel>
		);
	} else {
		const chapterNav = tab === "Pages" && current !== undefined && chapters.size() > 1;
		const emptyText = list.size() === 0 ? "Pages appear as you play." : "Every page is filled.";
		mainH = panelHeight(
			phone,
			head + (chapterNav ? navH + pad.gap : 0) + (shown.size() > 0 ? gridH : rowH) + (tab === "Pages" ? pad.gap + 10 : 0),
		);
		mainPanel = (
			<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} reveal={enter} reducedMotion={reducedMotion} name="JournalPages">
				<PanelHeading icon="Journal" title={panelTitle} note={panelCount} phone={phone} layoutOrder={0} />
				{chapterNav && (
					<FlexRow height={navH} gap={8} align={Enum.VerticalAlignment.Center} layoutOrder={1}>
						<MockBtn
							text="Previous"
							icon="Back.1"
							sec={true}
							sm={true}
							phone={phone}
							disabled={current!.index === 0}
							onClick={() => setChapterPick(math.max(0, current!.index - 1))}
							reducedMotion={reducedMotion}
							layoutOrder={0}
						/>
						<MockBtn
							text="Next"
							icon="Chevron"
							sec={true}
							sm={true}
							phone={phone}
							disabled={current!.index >= chapters.size() - 1}
							onClick={() => setChapterPick(math.min(chapters.size() - 1, current!.index + 1))}
							reducedMotion={reducedMotion}
							layoutOrder={1}
						/>
					</FlexRow>
				)}
				{shown.size() > 0 ? (
					<frame Size={new UDim2(1, 0, 0, gridH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2} key="PageGrid">
						<uigridlayout
							CellSize={new UDim2(1 / columns, -math.ceil((cellGap * (columns - 1)) / columns), 0, cellH)}
							CellPadding={UDim2.fromOffset(cellGap, cellGap)}
							FillDirectionMaxCells={columns}
							SortOrder={Enum.SortOrder.LayoutOrder}
						/>
						{shown.map((page, index) => (
							<PageCard key={page.entry.Id} page={page} phone={phone} onOpen={() => setOpenId(page.entry.Id)} onClaim={() => claim(page.entry.Id)} reducedMotion={reducedMotion} layoutOrder={index} />
						))}
					</frame>
				) : (
					<MockRow phone={phone} icon="Check" title={emptyText} dim={true} layoutOrder={2} />
				)}
				{tab === "Pages" && current !== undefined && <Bar fill={current.filled / math.max(1, current.pages.size())} color={Palette.mango} layoutOrder={3} />}
			</MockPanel>
		);
	}

	// chapter reward card: what finishing it gives (the sum of its page rewards) and the next open page
	const nextOpen = current?.pages.find((page) => !page.done);
	const chapterRewards: string[] = [];
	if (current !== undefined) {
		const totals: Record<string, number> = {};
		for (const page of current.pages) {
			if (page.entry.Reward === undefined) continue;
			for (const [key, value] of pairs(page.entry.Reward as unknown as Record<string, unknown>)) {
				if (typeIs(value, "number")) totals[key as string] = (totals[key as string] ?? 0) + value;
			}
		}
		for (const line of rewardLines(totals as unknown as Reward)) chapterRewards.push(line);
	}
	const readyCount = current !== undefined ? current.pages.filter((page) => page.ready).size() : 0;
	const rewardCount = math.max(1, chapterRewards.size());
	const lineH = phone ? 18 : 20;
	const sideContent =
		head + rewardCount * rowH + (rewardCount - 1) * pad.gap + pad.gap + lineH + pad.gap + rowH + (nextOpen !== undefined ? pad.gap + btnH : 0);
	const sideH = panelHeight(phone, sideContent);
	const side = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} reveal={enter} reducedMotion={reducedMotion} name="ChapterReward">
			<PanelHeading icon="Gift" title="Chapter reward" phone={phone} layoutOrder={0} />
			{rewardRows(chapterRewards, phone, "", 1, "No rewards in this chapter")}
			<Line
				text={current !== undefined ? `Fill all ${current.pages.size()} pages in this chapter.` : "Pages appear as you play."}
				size={phone ? 13 : 15}
				font={BODY}
				color={Palette.creamSoft}
				width={new UDim(1, 0)}
				height={lineH}
				layoutOrder={20}
			/>
			<MockRow phone={phone} icon="Timer" title="Ready to claim" value={readyCount > 0 ? `${readyCount} new` : "None"} layoutOrder={21} />
			{nextOpen !== undefined && (
				<MockBtn text="Open next page" icon="Journal" fill={true} phone={phone} onClick={() => setOpenId(nextOpen.entry.Id)} reducedMotion={reducedMotion} layoutOrder={22} />
			)}
		</MockPanel>
	);

	const tabs = (
		<TabStrip
			options={TABS}
			value={tab}
			onChange={setTab}
			accent={Palette.mango}
			phone={phone}
			note={`${filledTotal} of ${allPages.size()} pages filled`}
			width={phone ? 252 : 330}
			reducedMotion={reducedMotion}
		/>
	);
	const sections: { id: string; height: number; element: React.Element }[] = [{ id: "tabs", height: TAB_STRIP_H, element: tabs }];
	const showSide = tab === "Pages";
	if (phone || !showSide) {
		sections.push({ id: "pages", height: mainH, element: mainPanel });
		if (showSide) sections.push({ id: "reward", height: sideH, element: side });
	} else {
		const bodyH = math.max(mainH, sideH);
		sections.push({
			id: "body",
			height: bodyH,
			element: (
				<FlexRow fillHeight={true} gap={gap} name="JournalBody">
					<FlexFill layoutOrder={0}>{mainPanel}</FlexFill>
					<FlexFixed width={430} height={sideH} layoutOrder={1}>
						{side}
					</FlexFixed>
				</FlexRow>
			),
		});
	}
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<PageScaffold gap={gap} tailPad={scrollTail(phone, chrome.bottomSafe, 24)} scrollBarColor={Palette.brass} scrollBarThickness={4} sections={sections} owner="JournalView" />
		</frame>
	);
}

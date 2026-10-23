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

const TweenService = game.GetService("TweenService");

const { Button, Meter, Panel, SegmentedTabs, Text } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");
const { PageScaffold } = kitMember<{ PageScaffold: LuauComponent }>("LayoutKit", "pageScaffold");

const SERIF = Font.fromName("Merriweather", Enum.FontWeight.Bold);
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

// a drawn check (no glyph): two rotated bars
function Check(props: { color: Color3; position: UDim2; scale?: React.Binding<number> }) {
	return (
		<frame Size={UDim2.fromOffset(14, 12)} Position={props.position} BackgroundTransparency={1} BorderSizePixel={0}>
			{props.scale && <uiscale Scale={props.scale} />}
			<frame Size={UDim2.fromOffset(6, 2)} Position={UDim2.fromOffset(0, 6)} Rotation={45} BackgroundColor3={props.color} BorderSizePixel={0} />
			<frame Size={UDim2.fromOffset(12, 2)} Position={UDim2.fromOffset(3, 4)} Rotation={-50} BackgroundColor3={props.color} BorderSizePixel={0} />
		</frame>
	);
}

function TitleLine(props: { number: number; title: string; size: number; position?: UDim2; width: UDim2 }) {
	return (
		<frame Size={props.width} Position={props.position} BackgroundTransparency={1} BorderSizePixel={0}>
			<Text value={string.format("%02d", props.number)} size={props.size - 2} color={Palette.mango} weight={Enum.FontWeight.Bold} sizeConstraint={new UDim2(0, 28, 1, 0)} />
			<textlabel
				Text={props.title}
				FontFace={SERIF}
				TextSize={props.size}
				TextColor3={Palette.cream}
				TextXAlignment={Enum.TextXAlignment.Left}
				TextTruncate={Enum.TextTruncate.AtEnd}
				BackgroundTransparency={1}
				Position={UDim2.fromOffset(30, 0)}
				Size={new UDim2(1, -30, 1, 0)}
			/>
		</frame>
	);
}

// ---------- page card ----------
function PageCard(props: { page: JournalPage; onOpen: () => void; onClaim: () => void; reducedMotion?: boolean; layoutOrder?: number }) {
	const { page } = props;
	// page stamp: 180 ms scale 1.15 -> 1 plus a brass ring pulse when the page fills
	const [stampNonce, setStampNonce] = React.useState(0);
	const wasDone = React.useRef(page.done);
	React.useEffect(() => {
		if (page.done && !wasDone.current) setStampNonce((value) => value + 1);
		wasDone.current = page.done;
	}, [page.done]);
	const stamp = useFlash(stampNonce, props.reducedMotion === true, 0.18);
	const chip = chipText(page);
	const accent = page.done ? Palette.brass : page.ready ? Palette.green : Palette.line;
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={page.done ? Palette.panelRaised : Palette.panel} BorderSizePixel={0} LayoutOrder={props.layoutOrder}>
			<uicorner CornerRadius={new UDim(0, 10)} />
			<uistroke Color={accent} Thickness={1} Transparency={page.done ? 0.45 : page.ready ? 0.2 : 0.5} />
			{page.done && (
				<uigradient Rotation={90} Color={new ColorSequence(Palette.brassDeep.Lerp(Palette.panelRaised, 0.55), Palette.panel)} />
			)}
			<textbutton Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} Text="" ZIndex={2} Event={{ Activated: () => props.onOpen() }} />
			<TitleLine number={page.number} title={page.entry.Name} size={15} position={UDim2.fromOffset(10, 8)} width={new UDim2(1, -44, 0, 20)} />
			{page.done && <Check color={Palette.cream} position={new UDim2(1, -26, 0, 12)} scale={stamp.map((t) => 1 + 0.15 * t)} />}
			<frame
				key="StampRing"
				Size={UDim2.fromOffset(26, 26)}
				Position={new UDim2(1, -32, 0, 5)}
				BackgroundTransparency={1}
				Visible={stampNonce > 0}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke Color={Palette.brass} Thickness={2} Transparency={stamp.map((t) => 1 - t)} />
				<uiscale Scale={stamp.map((t) => 1.6 - 0.6 * t)} />
			</frame>
			<Text
				value={page.entry.Description ?? ""}
				size={12}
				color={Palette.creamSoft}
				fit={true}
				minSize={10}
				position={UDim2.fromOffset(10, 32)}
				sizeConstraint={new UDim2(1, -20, 0, 16)}
			/>
			{page.ready ? (
				<frame Size={UDim2.fromOffset(84, 28)} Position={new UDim2(0, 8, 1, -34)} BackgroundTransparency={1} ZIndex={3}>
					<Button text="Claim" onClick={props.onClaim} color={Palette.green} textColor={Palette.ink} size={UDim2.fromScale(1, 1)} highlight={true} reducedMotion={props.reducedMotion} zIndex={4} />
				</frame>
			) : (
				<frame
					Size={UDim2.fromOffset(math.max(44, chip.size() * 7 + 14), 20)}
					Position={new UDim2(0, 10, 1, -28)}
					BackgroundColor3={page.done ? Palette.brassDeep : Palette.ink}
					BackgroundTransparency={page.done ? 0.35 : 0.1}
					BorderSizePixel={0}
				>
					<uicorner CornerRadius={new UDim(0, 5)} />
					<uistroke Color={page.done ? Palette.brass : Palette.line} Thickness={1} Transparency={0.4} />
					<Text value={chip} size={11} color={Palette.cream} weight={Enum.FontWeight.Bold} align={Enum.TextXAlignment.Center} sizeConstraint={UDim2.fromScale(1, 1)} />
				</frame>
			)}
		</frame>
	);
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
			const tween = TweenService.Create(dot, new TweenInfo(2 + (index % 4), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				BackgroundTransparency: 0.45,
			});
			tween.Play();
			tweens.push(tween);
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

function InfoRow(props: { label: string; value: string; position: UDim2; onClick?: () => void; reducedMotion?: boolean }) {
	return (
		<frame Size={new UDim2(1, 0, 0, 30)} Position={props.position} BackgroundColor3={Palette.panelRaised} BorderSizePixel={0}>
			<uicorner CornerRadius={new UDim(0, 8)} />
			<uistroke Color={Palette.line} Thickness={1} Transparency={0.4} />
			<Text value={props.label} size={12} color={Palette.creamSoft} weight={Enum.FontWeight.Medium} fit={true} minSize={10} position={UDim2.fromOffset(12, 7)} sizeConstraint={new UDim2(0.6, -12, 0, 16)} />
			<Text value={props.value} size={12} color={Palette.mango} weight={Enum.FontWeight.Bold} align={Enum.TextXAlignment.Right} fit={true} minSize={10} position={new UDim2(0.6, 0, 0, 7)} sizeConstraint={new UDim2(0.4, -12, 0, 16)} />
			{props.onClick && <textbutton Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} Text="" Event={{ Activated: () => props.onClick!() }} />}
		</frame>
	);
}

function SideLabel(props: { text: string }) {
	return (
		<frame Size={new UDim2(1, 0, 0, 16)} BackgroundTransparency={1}>
			<frame Size={UDim2.fromOffset(8, 8)} Position={UDim2.fromOffset(0, 4)} Rotation={45} BackgroundTransparency={1}>
				<uistroke Color={Palette.brass} Thickness={1} />
			</frame>
			<textlabel Text={props.text.upper()} FontFace={SERIF} TextSize={11} TextColor3={Palette.creamSoft} TextXAlignment={Enum.TextXAlignment.Left} BackgroundTransparency={1} Position={UDim2.fromOffset(16, 0)} Size={new UDim2(1, -16, 1, 0)} />
		</frame>
	);
}

// ---------- entry spread ----------
function EntryView(props: {
	page: JournalPage;
	total: number;
	nearby: JournalPage[];
	stack: boolean;
	viewportWidth: number;
	bottomSafe: number;
	gap: number;
	onBack: () => void;
	onOpen: (id: string) => void;
	onClaim: () => void;
	reducedMotion?: boolean;
	enter: React.Binding<number>;
}) {
	const { page, stack } = props;
	const rewards = rewardLines(page.entry.Reward);
	const artW = stack ? 300 : 420;
	const artH = stack ? 140 : 200;
	const bookH = stack ? 150 + 90 + artH : 520;
	const progressH = 16 + 12 + 34 + 16 + (page.ready ? TapTarget + 8 : 0) + 24;
	const rewardH = 16 + 12 + math.max(1, rewards.size()) * 34 + 24;
	const nearbyH = 16 + 12 + math.max(1, props.nearby.size()) * 34 + 24;
	const book = (
		<Panel size={UDim2.fromScale(1, 1)} accent={Palette.brass} background={Palette.panel} padding={stack ? 14 : 28} radius={18} reveal={props.enter} reducedMotion={props.reducedMotion}>
			<uigradient Rotation={120} Color={new ColorSequence(Palette.brassDeep.Lerp(Palette.panel, 0.7), Palette.panel)} />
			{!stack && (
				<frame key="Spine" Size={new UDim2(0, 1, 1, 0)} Position={UDim2.fromScale(0.5, 0)} BackgroundColor3={Palette.brass} BackgroundTransparency={0.8} BorderSizePixel={0} />
			)}
			<frame Size={UDim2.fromOffset(96, TapTarget)} BackgroundTransparency={1}>
				<Button text="Journal" icon="Back.1" onClick={props.onBack} color={Palette.panelSoft} textColor={Palette.cream} outline={true} size={UDim2.fromScale(1, 1)} reducedMotion={props.reducedMotion} />
			</frame>
			<Text value={`PAGE ${page.number} OF ${props.total}`} size={10} color={Palette.muted} weight={Enum.FontWeight.Bold} align={Enum.TextXAlignment.Right} position={new UDim2(1, -140, 0, 14)} sizeConstraint={UDim2.fromOffset(140, 14)} />
			<textlabel
				Text={page.entry.Name}
				FontFace={SERIF}
				TextSize={stack ? 24 : 34}
				TextColor3={Palette.cream}
				TextXAlignment={Enum.TextXAlignment.Left}
				TextTruncate={Enum.TextTruncate.AtEnd}
				BackgroundTransparency={1}
				Position={UDim2.fromOffset(0, TapTarget + 14)}
				Size={new UDim2(1, 0, 0, stack ? 30 : 44)}
			/>
			<Text
				value={page.entry.Description ?? ""}
				size={stack ? 13 : 15}
				color={Palette.creamSoft}
				wrap={true}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(0, TapTarget + (stack ? 48 : 64))}
				sizeConstraint={new UDim2(stack ? 1 : 0.8, 0, 0, stack ? 36 : 44)}
			/>
			<frame
				key="Art"
				Size={new UDim2(1, 0, 0, artH)}
				Position={UDim2.fromOffset(0, TapTarget + (stack ? 92 : 130))}
				BackgroundTransparency={1}
			>
				<StarMap id={page.entry.Id} fraction={page.fraction} width={artW} height={artH} reducedMotion={props.reducedMotion} />
			</frame>
		</Panel>
	);
	const progressPanel = (
		<Panel size={UDim2.fromScale(1, 1)} accent={Palette.line} background={Palette.panel} padding={12} radius={18} reducedMotion={props.reducedMotion}>
			<SideLabel text="Progress" />
			<InfoRow label={page.done ? "Filled" : "Progress"} value={chipText(page)} position={UDim2.fromOffset(0, 26)} />
			<Meter value={page.fraction} color={Palette.mango} shimmer={page.ready} position={UDim2.fromOffset(0, 64)} size={new UDim2(1, 0, 0, 6)} reducedMotion={props.reducedMotion} />
			{page.ready && (
				<frame Size={new UDim2(1, 0, 0, TapTarget)} Position={UDim2.fromOffset(0, 78)} BackgroundTransparency={1}>
					<Button text="Claim page" onClick={props.onClaim} color={Palette.mango} textColor={Palette.ink} size={UDim2.fromScale(1, 1)} highlight={true} reducedMotion={props.reducedMotion} />
				</frame>
			)}
		</Panel>
	);
	const rewardPanel = (
		<Panel size={UDim2.fromScale(1, 1)} accent={Palette.line} background={Palette.panel} padding={12} radius={18} reducedMotion={props.reducedMotion}>
			<SideLabel text="Page reward" />
			{rewards.size() === 0 ? (
				<InfoRow label="No reward on this page" value="" position={UDim2.fromOffset(0, 26)} />
			) : (
				rewards.map((line, index) => <InfoRow key={`R${index}`} label={line} value={page.done ? "Claimed" : ""} position={UDim2.fromOffset(0, 26 + index * 34)} />)
			)}
		</Panel>
	);
	const nearbyPanel = (
		<Panel size={UDim2.fromScale(1, 1)} accent={Palette.line} background={Palette.panel} padding={12} radius={18} reducedMotion={props.reducedMotion}>
			<SideLabel text="Nearby pages" />
			{props.nearby.size() === 0 ? (
				<InfoRow label="Every other page is filled" value="" position={UDim2.fromOffset(0, 26)} />
			) : (
				props.nearby.map((other, index) => (
					<InfoRow key={other.entry.Id} label={other.entry.Name} value={chipText(other)} position={UDim2.fromOffset(0, 26 + index * 34)} onClick={() => props.onOpen(other.entry.Id)} />
				))
			)}
		</Panel>
	);
	const sections: { id: string; height?: number; fill?: boolean; minHeight?: number; element: React.Element }[] = [];
	if (stack) {
		sections.push({ id: "book", height: bookH, element: book });
		sections.push({ id: "progress", height: progressH, element: progressPanel });
		sections.push({ id: "reward", height: rewardH, element: rewardPanel });
		sections.push({ id: "nearby", height: nearbyH, element: nearbyPanel });
	} else {
		const sideW = math.clamp(math.floor(props.viewportWidth * 0.24), 240, 320);
		const sideH = progressH + rewardH + nearbyH + 24;
		sections.push({
			id: "spread",
			fill: true,
			minHeight: math.max(bookH, sideH),
			element: (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
					<frame Size={new UDim2(1, -(sideW + 12), 1, 0)} BackgroundTransparency={1}>
						{book}
					</frame>
					<frame Size={new UDim2(0, sideW, 1, 0)} Position={new UDim2(1, -sideW, 0, 0)} BackgroundTransparency={1}>
						<frame Size={new UDim2(1, 0, 0, progressH)} BackgroundTransparency={1}>
							{progressPanel}
						</frame>
						<frame Size={new UDim2(1, 0, 0, rewardH)} Position={UDim2.fromOffset(0, progressH + 12)} BackgroundTransparency={1}>
							{rewardPanel}
						</frame>
						<frame Size={new UDim2(1, 0, 1, -(progressH + rewardH + 24))} Position={UDim2.fromOffset(0, progressH + rewardH + 24)} BackgroundTransparency={1}>
							{nearbyPanel}
						</frame>
					</frame>
				</frame>
			),
		});
	}
	return (
		<PageScaffold
			gap={props.gap}
			tailPad={scrollTail(stack, props.bottomSafe, 24)}
			scrollBarColor={Palette.brass}
			scrollBarThickness={4}
			sections={sections}
		/>
	);
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
	const stack = chrome.contentStack;
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
	const gap = stack ? chrome.panelGap : 14;

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
					stack={stack}
					viewportWidth={viewport.width}
					bottomSafe={chrome.bottomSafe}
					gap={gap}
					onBack={() => setOpenId(undefined)}
					onOpen={setOpenId}
					onClaim={() => claim(opened.entry.Id)}
					reducedMotion={reducedMotion}
					enter={enter}
				/>
			</frame>
		);
	}

	const heroH = stack ? 64 : 118;
	const tabsW = stack ? 230 : 280;
	const hero = (
		<Panel size={UDim2.fromScale(1, 1)} accent={Palette.brass} background={Palette.panelRaised} padding={stack ? 12 : 20} radius={18} reveal={enter} reducedMotion={reducedMotion} clips={true}>
			{!stack && current !== undefined && (
				<Text value={`CHAPTER ${current.index + 1}`} size={11} color={Palette.mango} weight={Enum.FontWeight.Heavy} sizeConstraint={new UDim2(0.5, 0, 0, 14)} />
			)}
			<textlabel
				Text="Journal"
				FontFace={SERIF}
				TextSize={stack ? 24 : 34}
				TextColor3={Palette.cream}
				TextXAlignment={Enum.TextXAlignment.Left}
				BackgroundTransparency={1}
				Position={UDim2.fromOffset(0, stack ? 0 : 16)}
				Size={new UDim2(0, stack ? 130 : 260, 0, stack ? 30 : 42)}
			/>
			<Text
				value={stack ? `${filledTotal} of ${allPages.size()} pages` : "Pages you fill by playing. Finish a chapter to close it."}
				size={stack ? 12 : 13}
				color={Palette.muted}
				fit={true}
				minSize={10}
				position={stack ? UDim2.fromOffset(0, 32) : UDim2.fromOffset(0, 60)}
				sizeConstraint={new UDim2(1, -(tabsW + 16), 0, 18)}
			/>
			<SegmentedTabs
				options={TABS}
				value={tab}
				onChange={setTab}
				accent={Palette.mango}
				size={UDim2.fromOffset(tabsW, TapTarget)}
				position={new UDim2(1, -tabsW, 0.5, -TapTarget / 2)}
				reducedMotion={reducedMotion}
			/>
		</Panel>
	);

	// which pages the main panel lists
	let shown: JournalPage[] = [];
	let panelTitle = "";
	let panelCount = "";
	if (tab === "Pages" && current !== undefined) {
		shown = current.pages;
		panelTitle = `Chapter ${current.index + 1}`;
		panelCount = `${filledTotal} of ${allPages.size()} pages`;
	} else if (tab === "Goals") {
		shown = allPages.filter((page) => !page.done);
		shown.sort((a, b) => (a.ready !== b.ready ? a.ready : a.fraction > b.fraction));
		panelTitle = "Open pages";
		panelCount = `${shown.size()} left`;
	}
	const columns = stack ? 2 : 3;
	const cellH = 92;
	const cellGap = 8;

	let mainPanel: React.Element;
	if (tab === "Keepsakes") {
		const finished = chapters.filter((chapter) => chapter.filled === chapter.pages.size());
		mainPanel = (
			<Panel size={UDim2.fromScale(1, 1)} accent={Palette.line} background={Palette.panel} padding={stack ? 10 : 14} radius={18} reducedMotion={reducedMotion}>
				<SideLabel text="Finished chapters" />
				<scrollingframe Size={new UDim2(1, 0, 1, -24)} Position={UDim2.fromOffset(0, 24)} BackgroundTransparency={1} BorderSizePixel={0} CanvasSize={new UDim2()} AutomaticCanvasSize={Enum.AutomaticSize.Y} ScrollBarThickness={3} ScrollBarImageColor3={Palette.brass}>
					<uilistlayout Padding={new UDim(0, 6)} SortOrder={Enum.SortOrder.LayoutOrder} />
					{finished.size() === 0 ? (
						<Text value="Fill every page in a chapter and it is kept here." size={13} color={Palette.muted} sizeConstraint={new UDim2(1, 0, 0, 20)} />
					) : (
						finished.map((chapter) => (
							<frame key={`C${chapter.index}`} Size={new UDim2(1, -6, 0, 30)} BackgroundTransparency={1} LayoutOrder={chapter.index}>
								<InfoRow
									label={`Chapter ${chapter.index + 1}  ·  pages ${chapter.pages[0].number} to ${chapter.pages[chapter.pages.size() - 1].number}`}
									value="Filled"
									position={UDim2.fromOffset(0, 0)}
									onClick={() => {
										setChapterPick(chapter.index);
										setTab("Pages");
									}}
								/>
							</frame>
						))
					)}
				</scrollingframe>
			</Panel>
		);
	} else {
		const chapterNav = tab === "Pages" && current !== undefined;
		mainPanel = (
			<Panel size={UDim2.fromScale(1, 1)} accent={Palette.line} background={Palette.panel} padding={stack ? 10 : 14} radius={18} reducedMotion={reducedMotion}>
				<frame Size={new UDim2(1, chapterNav ? -76 : 0, 0, 16)} BackgroundTransparency={1}>
					<SideLabel text={panelTitle} />
				</frame>
				<Text value={panelCount} size={10} color={Palette.muted} align={Enum.TextXAlignment.Right} position={new UDim2(1, chapterNav ? -236 : -160, 0, 2)} sizeConstraint={UDim2.fromOffset(150, 14)} />
				{chapterNav && (
					<frame Size={UDim2.fromOffset(72, 28)} Position={new UDim2(1, -72, 0, -6)} BackgroundTransparency={1}>
						<Button text="<" onClick={() => setChapterPick(math.max(0, current!.index - 1))} disabled={current!.index === 0} size={UDim2.fromOffset(34, 28)} color={Palette.panelSoft} textColor={Palette.cream} reducedMotion={reducedMotion} />
						<Button
							text=">"
							onClick={() => setChapterPick(math.min(chapters.size() - 1, current!.index + 1))}
							disabled={current!.index >= chapters.size() - 1}
							size={UDim2.fromOffset(34, 28)}
							position={UDim2.fromOffset(38, 0)}
							color={Palette.panelSoft}
							textColor={Palette.cream}
							reducedMotion={reducedMotion}
						/>
					</frame>
				)}
				<scrollingframe
					Size={new UDim2(1, 0, 1, tab === "Pages" ? -46 : -30)}
					Position={UDim2.fromOffset(0, 26)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					CanvasSize={new UDim2()}
					AutomaticCanvasSize={Enum.AutomaticSize.Y}
					ScrollingDirection={Enum.ScrollingDirection.Y}
					ScrollBarThickness={3}
					ScrollBarImageColor3={Palette.brass}
				>
					<uipadding PaddingRight={new UDim(0, 6)} PaddingBottom={new UDim(0, 4)} />
					<uigridlayout CellSize={new UDim2(1 / columns, -cellGap, 0, cellH)} CellPadding={UDim2.fromOffset(cellGap, cellGap)} SortOrder={Enum.SortOrder.LayoutOrder} />
					{shown.map((page, index) => (
						<PageCard key={page.entry.Id} page={page} onOpen={() => setOpenId(page.entry.Id)} onClaim={() => claim(page.entry.Id)} reducedMotion={reducedMotion} layoutOrder={index} />
					))}
				</scrollingframe>
				{shown.size() === 0 && (
					<Text value={list.size() === 0 ? "Pages appear as you play." : "Every page is filled."} size={13} color={Palette.muted} align={Enum.TextXAlignment.Center} position={new UDim2(0, 0, 0.5, -10)} sizeConstraint={new UDim2(1, 0, 0, 20)} />
				)}
				{tab === "Pages" && current !== undefined && (
					<Meter
						value={current.filled / math.max(1, current.pages.size())}
						color={Palette.mango}
						shimmer={current.filled === current.pages.size()}
						position={new UDim2(0, 0, 1, -8)}
						size={new UDim2(1, 0, 0, 6)}
						reducedMotion={reducedMotion}
					/>
				)}
			</Panel>
		);
	}

	// chapter card: what finishing it gives (the sum of its page rewards) and the next open page
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
	const sideRows = math.max(1, chapterRewards.size()) + 1;
	const sideH = 16 + 12 + sideRows * 34 + 8 + TapTarget + 28;
	const side = (
		<Panel size={UDim2.fromScale(1, 1)} accent={Palette.brass} background={Palette.panel} padding={12} radius={18} reducedMotion={reducedMotion}>
			<SideLabel text="Chapter rewards" />
			{chapterRewards.size() === 0 ? (
				<InfoRow label="No rewards in this chapter" value="" position={UDim2.fromOffset(0, 26)} />
			) : (
				chapterRewards.map((line, index) => <InfoRow key={`CR${index}`} label={line} value="" position={UDim2.fromOffset(0, 26 + index * 34)} />)
			)}
			<InfoRow
				label="Ready to claim"
				value={readyCount > 0 ? `${readyCount}` : "None"}
				position={UDim2.fromOffset(0, 26 + math.max(1, chapterRewards.size()) * 34)}
			/>
			{nextOpen !== undefined && (
				<frame Size={new UDim2(1, 0, 0, TapTarget)} Position={new UDim2(0, 0, 1, -TapTarget)} BackgroundTransparency={1}>
					<Button text="Open next page" onClick={() => setOpenId(nextOpen.entry.Id)} color={Palette.mango} textColor={Palette.ink} size={UDim2.fromScale(1, 1)} reducedMotion={reducedMotion} />
				</frame>
			)}
		</Panel>
	);

	const sections: { id: string; height?: number; fill?: boolean; minHeight?: number; element: React.Element }[] = [
		{ id: "hero", height: heroH, element: hero },
	];
	const gridMin = 26 + 2 * (cellH + cellGap) + 30;
	if (stack) {
		sections.push({ id: "pages", fill: true, minHeight: gridMin, element: mainPanel });
		if (tab === "Pages") sections.push({ id: "reward", height: sideH, element: side });
	} else {
		const sideW = math.clamp(math.floor(viewport.width * 0.22), 220, 300);
		sections.push({
			id: "body",
			fill: true,
			minHeight: math.max(gridMin, sideH),
			element: (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
					<frame Size={new UDim2(1, -(sideW + 12), 1, 0)} BackgroundTransparency={1}>
						{mainPanel}
					</frame>
					<frame Size={new UDim2(0, sideW, 0, sideH)} Position={new UDim2(1, -sideW, 0, 0)} BackgroundTransparency={1}>
						{side}
					</frame>
				</frame>
			),
		});
	}
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<PageScaffold gap={gap} tailPad={scrollTail(stack, chrome.bottomSafe, 24)} scrollBarColor={Palette.brass} scrollBarThickness={4} sections={sections} />
		</frame>
	);
}

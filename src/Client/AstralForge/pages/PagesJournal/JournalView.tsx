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
import { Bar, BODY, BODY_BOLD, Chip, Glyph, Line, MockPanel, mockGap, NUM, PanelHeading, panelPad, spaced, TITLE_FACE } from "../../UiCore/mockKit";
import { headingBlock, MockBtn, MockRow, panelHeight, RowFace, rowHeight } from "../mockRows";
import { FlexCol, FlexFill, FlexFixed, FlexRow, stackSum } from "../mockLayout";

import { PHONE_HEAD_H as PH_HEAD_H, PhoneHead } from "../mockLayout";
import { useHeroShown, useHeroSlot } from "../../UiCore/heroSlot";
import { GlyphWell } from "../../UiCore/mockKit";

import { MotionFX } from "../../UiCore/screenFx";
import { JournalLayout as L } from "../generated/JournalLayout";
import { JournalEntryLayout as E } from "../generated/JournalEntryLayout";
import { JournalPhoneLayout as P } from "../generated/JournalPhoneLayout";
import { JournalEntryPhoneLayout as EP } from "../generated/JournalEntryPhoneLayout";

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

// ---------- chapter reward tiles (mockup .sc: 176x227 card, 160 art well, 15px name, rarity-style tag) ----------
interface RewardTileData {
	key: string;
	name: string;
	tag: string;
	glyph: string;
	color: Color3;
}
const REWARD_KINDS: Record<string, { name: string; glyph: string; color: Color3; order: number; tag: (n: number) => string }> = {
	Cash: { name: "Flux", glyph: "Gem", color: Palette.mango, order: 0, tag: (n) => compactNumber(n) },
	CashMinutes: { name: "Flux time", glyph: "Timer", color: Palette.mango, order: 1, tag: (n) => `${compactNumber(n)} MIN` },
	Stardust: { name: "Stardust", glyph: "Gem", color: L.SideTag.fill.color, order: 2, tag: (n) => compactNumber(n) },
	Cores: { name: "Cores", glyph: "Gift", color: Palette.mint, order: 3, tag: (n) => compactNumber(n) },
	Signals: { name: "Signals", glyph: "Gift", color: Palette.mint, order: 4, tag: (n) => compactNumber(n) },
	CommandXP: { name: "Command XP", glyph: "Milestone", color: Palette.brass, order: 5, tag: (n) => compactNumber(n) },
	StreakShield: { name: "Streak shield", glyph: "Lock", color: Palette.brass, order: 6, tag: (n) => `x${n}` },
	Essence: { name: "Essence", glyph: "Gem", color: L.SideTag.fill.color, order: 7, tag: (n) => compactNumber(n) },
	DomainEssence: { name: "Domain essence", glyph: "Gem", color: L.SideTag.fill.color, order: 8, tag: (n) => compactNumber(n) },
	Fragments: { name: "Fragments", glyph: "Gift", color: Palette.brass, order: 9, tag: (n) => compactNumber(n) },
	FreeSpins: { name: "Free spins", glyph: "Gift", color: Palette.mint, order: 10, tag: (n) => `x${n}` },
};

function RewardTile(props: { tile: RewardTileData; reducedMotion?: boolean; layoutOrder?: number }) {
	const { tile } = props;
	const art = L.SideArt;
	const card = L.SideCard;
	return (
		<frame BackgroundColor3={Palette.white} BorderSizePixel={0} LayoutOrder={props.layoutOrder ?? 0}>
			<uicorner CornerRadius={new UDim(0, card.radius)} />
			{card.gradient !== undefined && <uigradient Rotation={card.gradient.rotation} Color={card.gradient.color} Transparency={card.gradient.transparency} />}
			<uistroke Color={tile.color} Transparency={0.55} Thickness={1.5} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
			{/* .sc .w: #0d090f well lit from the middle in the tile colour */}
			<frame
				Size={UDim2.fromOffset(art.w, art.h)}
				Position={UDim2.fromOffset(art.x - card.x, art.y - card.y)}
				BackgroundColor3={art.fill.color}
				BorderSizePixel={0}
				ClipsDescendants={true}
			>
				<uicorner CornerRadius={new UDim(0, art.radius)} />
				<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={tile.color} BackgroundTransparency={0.75} BorderSizePixel={0}>
					<uigradient
						Transparency={
							new NumberSequence([new NumberSequenceKeypoint(0, 1), new NumberSequenceKeypoint(0.5, 0.25), new NumberSequenceKeypoint(1, 1)])
						}
						Rotation={90}
					/>
				</frame>
				<GlyphWell
					kind={tile.glyph}
					accent={tile.color}
					size={64}
					radius={16}
					position={UDim2.fromScale(0.5, 0.5)}
					anchorPoint={new Vector2(0.5, 0.5)}
					spin={false}
					reducedMotion={props.reducedMotion}
				/>
			</frame>
			<Line
				text={tile.name}
				size={L.SideName.text.size}
				font={BODY_BOLD}
				color={L.SideName.text.color}
				width={new UDim(1, -card.pad.left * 2)}
				height={L.SideName.h}
				align={Enum.TextXAlignment.Center}
				position={UDim2.fromOffset(card.pad.left, L.SideName.y - card.y)}
			/>
			{/* .sc .tg: 10px tracked tag on the tile colour */}
			<frame
				Size={UDim2.fromOffset(0, L.SideTag.h)}
				AutomaticSize={Enum.AutomaticSize.X}
				Position={new UDim2(0.5, 0, 0, L.SideTag.y - card.y)}
				AnchorPoint={new Vector2(0.5, 0)}
				BackgroundColor3={tile.color}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(0, L.SideTag.radius)} />
				<uipadding PaddingLeft={new UDim(0, L.SideTag.pad.left)} PaddingRight={new UDim(0, L.SideTag.pad.right)} PaddingTop={new UDim(0, L.SideTag.pad.top)} />
				<Line text={spaced(tile.tag.upper())} size={L.SideTag.text.size} font={NUM} color={L.SideTag.text.color} height={L.SideTag.h - L.SideTag.pad.top - L.SideTag.pad.bottom} />
			</frame>
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
const CARD_PAD = L.Card.pad.top;
function cardHeight(phone: boolean): number {
	// padding, title line 22, gap 8, goal line 18, gap 8, chip / claim slot 36, padding
	return phone ? P.Card.h : L.Card.h;
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
	const pad = phone ? P.Card.pad.top : CARD_PAD;
	const padX = phone ? P.Card.pad.left : CARD_PAD;
	const lit = page.done || page.ready;
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.white} BorderSizePixel={0} LayoutOrder={props.layoutOrder ?? 0} key={`Page${page.number}`}>
			<RowFace outline={page.ready ? Palette.mint : undefined} />
			{lit && (
				// background:linear-gradient(180deg, mango .10, white .02)
				<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.white} BorderSizePixel={0} ZIndex={0}>
					<uicorner CornerRadius={new UDim(0, L.Card.radius)} />
					<uigradient Rotation={L.Card.gradient.rotation} Color={L.Card.gradient.color} Transparency={L.Card.gradient.transparency} />
				</frame>
			)}
			<textbutton Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} Text="" ZIndex={1} Event={{ Activated: () => props.onOpen() }} />
			<frame key="Content" Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={2}>
			<uipadding PaddingTop={new UDim(0, pad)} PaddingBottom={new UDim(0, pad)} PaddingLeft={new UDim(0, padX)} PaddingRight={new UDim(0, padX)} />
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, phone ? P.Card.gap : L.Card.gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
			<FlexRow height={phone ? P.CardHead.h : L.CardHead.h} gap={L.CardHead.gap} align={Enum.VerticalAlignment.Center} layoutOrder={0}>
				<Line text={tostring(page.number)} size={L.CardNum.text.size} font={NUM} color={L.CardNum.text.color} layoutOrder={0} zIndex={2} />
				<FlexFill layoutOrder={1}>
					<Line text={page.entry.Name} size={phone ? P.CardTitle.text.size : L.CardTitle.text.size} font={TITLE_FACE} color={L.CardTitle.text.color} width={new UDim(1, 0)} height={phone ? P.CardTitle.h : L.CardTitle.h} zIndex={2} />
				</FlexFill>
				{page.done && (
					<frame Size={UDim2.fromOffset(phone ? 18 : L.CardCheck.w, phone ? 18 : L.CardCheck.h)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
						<uiscale Scale={stamp.map((t) => 1 + 0.15 * t)} />
						<Glyph kind="Check" size={phone ? 18 : L.CardCheck.w} color={L.CardCheck.icon.color} />
					</frame>
				)}
			</FlexRow>
			<Line text={page.entry.Description ?? ""} size={phone ? P.CardGoal.text.size : L.CardGoal.text.size} font={BODY} color={L.CardGoal.text.color} width={new UDim(1, 0)} height={phone ? P.CardGoal.h : L.CardGoal.h} layoutOrder={1} zIndex={2} />
			<FlexRow height={phone ? P.CardChip.h : L.CardChipDone.h} gap={L.CardChipDone.gap} align={Enum.VerticalAlignment.Center} layoutOrder={2}>
				{/* .chip / .chip.a (mockup cards carry a chip only; a ready page claims from its entry spread) */}
				<Chip text={chipText(page)} accent={page.done ? Palette.mango : page.ready ? Palette.mint : undefined} phone={false} layoutOrder={0} />
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
	const artH = phone ? 150 : math.floor(E.Art.h);
	const titleSize = phone ? 30 : E.Title.text.size;
	const descH = phone ? 40 : E.Desc.h;
	const bookPadY = phone ? 14 : E.Book.pad.top - pad.y;
	const titleGap = phone ? 20 : E.Title.y - (E.BookBar.y + E.BookBar.h);
	const descGap = phone ? 12 : E.Desc.y - (E.Title.y + E.Title.h);
	const artGap = phone ? 12 : E.Art.y - (E.Desc.y + E.Desc.h);
	const bookContent = E.Back.h + titleGap + titleSize + descGap + descH + artGap + artH;
	const bookH = panelHeight(phone, bookContent + bookPadY * 2);

	const book = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={Palette.brass} glow={Palette.mango} reveal={props.enter} reducedMotion={props.reducedMotion} gap={0} name="EntryBook">
			<uipadding PaddingTop={new UDim(0, bookPadY)} PaddingLeft={new UDim(0, phone ? 0 : E.Book.pad.left - pad.x)} PaddingRight={new UDim(0, phone ? 0 : E.Book.pad.right - pad.x)} />
			<FlexRow height={E.BookBar.h} gap={E.BookBar.gap} align={Enum.VerticalAlignment.Center} layoutOrder={0}>
				<MockBtn text="Journal" icon="Back.1" sec={true} sm={true} phone={phone} onClick={props.onBack} reducedMotion={props.reducedMotion} layoutOrder={0} />
				<FlexFill layoutOrder={1}>
					<Line text={spaced(`PAGE ${page.number} OF ${props.total}`)} size={E.PageOf.text.size} color={E.PageOf.text.color} width={new UDim(1, 0)} height={E.BookBar.h} align={Enum.TextXAlignment.Right} />
				</FlexFill>
			</FlexRow>
			<frame Size={new UDim2(1, 0, 0, titleGap)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1} />
			<Line text={page.entry.Name} size={titleSize} font={TITLE_FACE} width={new UDim(1, 0)} height={titleSize} layoutOrder={2} />
			<frame Size={new UDim2(1, 0, 0, descGap)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={3} />
			<frame Size={new UDim2(1, 0, 0, descH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={4}>
				<uisizeconstraint MaxSize={new Vector2(E.Desc.w, math.huge)} />
				<textlabel
					Size={UDim2.fromScale(1, 1)}
					BackgroundTransparency={1}
					Text={page.entry.Description ?? ""}
					TextSize={phone ? 14 : E.Desc.text.size}
					FontFace={BODY}
					TextColor3={Palette.creamSoft}
					TextWrapped={true}
					TextXAlignment={Enum.TextXAlignment.Left}
					TextYAlignment={Enum.TextYAlignment.Top}
					LineHeight={1.25}
				/>
			</frame>
			<frame Size={new UDim2(1, 0, 0, artGap)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={5} />
			<frame Size={new UDim2(1, 0, 0, artH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={6} key="StarMap">
				<StarMap id={page.entry.Id} fraction={page.fraction} width={phone ? 300 : E.Art.w} height={artH} reducedMotion={props.reducedMotion} />
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
		// phone.html: .ph-head (page title, "Page N"), then a .flexr of the progress panel (.row + .bar)
		// and a 260 column of buttons (claim / back)
		const headH = PH_HEAD_H;
		const bodyH = EP.Body.h;
		sections.push({
			id: "head",
			height: headH,
			element: <PhoneHead title={page.entry.Name} line={`Page ${page.number}`} />,
		});
		sections.push({
			id: "spread",
			height: bodyH,
			element: (
				<FlexRow fillHeight={true} gap={EP.Body.gap} name="EntrySpread">
					<FlexFill layoutOrder={0}>
						<MockPanel size={UDim2.fromScale(1, 1)} phone={true} reveal={props.enter} reducedMotion={props.reducedMotion} name="EntryProgress">
							<MockRow phone={true} icon="StarGrid" title={page.done ? "Filled" : page.entry.Description ?? "Progress"} value={chipText(page)} height={EP.Row.h} layoutOrder={1} />
							<Bar fill={page.fraction} color={Palette.mango} layoutOrder={2} />
						</MockPanel>
					</FlexFill>
					<FlexFixed width={EP.Side.w} layoutOrder={1}>
						<MockPanel size={UDim2.fromScale(1, 1)} phone={true} reducedMotion={props.reducedMotion} name="EntryActions">
							<MockBtn text={page.done ? "Claimed" : "Claim page"} icon="Gift" fill={true} phone={true} disabled={!page.ready} onClick={props.onClaim} reducedMotion={props.reducedMotion} layoutOrder={1} />
							<MockBtn text="Back" icon="Back.1" sec={true} fill={true} phone={true} onClick={props.onBack} reducedMotion={props.reducedMotion} layoutOrder={2} />
						</MockPanel>
					</FlexFixed>
				</FlexRow>
			),
		});
	} else {
		const bodyH = math.max(bookH, sideH);
		sections.push({
			id: "spread",
			height: bodyH,
			element: (
				<FlexRow fillHeight={true} gap={phone ? gap : E.Body.gap} name="EntrySpread">
					<FlexFill layoutOrder={0}>{book}</FlexFill>
					<FlexFixed width={E.Column.w} layoutOrder={1}>
						<FlexCol fill={true} gap={E.Column.gap}>
							<FlexFixed width={E.Column.w} height={progressH} layoutOrder={0}>
								{progressPanel}
							</FlexFixed>
							<FlexFixed width={E.Column.w} height={rewardH} layoutOrder={1}>
								{rewardPanel}
							</FlexFixed>
							{/* .pn.f1: the nearby list takes what is left of the column */}
							<FlexFixed width={E.Column.w} height={math.max(nearbyH, bodyH - progressH - rewardH - gap * 2)} layoutOrder={2}>
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
	// desktop: the hero's bottom-right .tabs slot (shell); phones: .ph-head
	useHeroSlot("Journal", opened === undefined ? { tabs: { options: TABS, value: tab, onChange: (id) => setTab(id), accent: Palette.mango, width: math.ceil(L.Tabs.w) } } : undefined);
	const inHero = useHeroShown();
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
	const cellGap = phone ? P.Grid.gap : L.Grid.gap;
	const rows = math.max(1, math.ceil(shown.size() / columns));
	const gridH = rows * cellH + (rows - 1) * cellGap;

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
		const emptyText = list.size() === 0 ? "Pages appear as you play." : "Every page is filled.";
		mainH = phone
			? P.Pages.pad.top * 2 + (shown.size() > 0 ? gridH : rowH)
			: panelHeight(phone, head + (shown.size() > 0 ? gridH : rowH) + (tab === "Pages" ? pad.gap + 10 : 0));
		mainPanel = (
			<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} reveal={enter} reducedMotion={reducedMotion} name="JournalPages">
				{/* phone.html: the page panel is the grid alone (the count sits in .ph-head) */}
				{!phone && <PanelHeading icon="Journal" title={panelTitle} note={panelCount} phone={phone} layoutOrder={0} />}
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
				{!phone && tab === "Pages" && current !== undefined && <Bar fill={current.filled / math.max(1, current.pages.size())} color={Palette.mango} layoutOrder={3} />}
			</MockPanel>
		);
	}

	// chapter reward card: what finishing it gives (the sum of its page rewards) and the next open page
	const nextOpen = current?.pages.find((page) => !page.done);
	const chapterTotals: RewardTileData[] = [];
	if (current !== undefined) {
		const totals: Record<string, number> = {};
		for (const page of current.pages) {
			if (page.entry.Reward === undefined) continue;
			for (const [key, value] of pairs(page.entry.Reward as unknown as Record<string, unknown>)) {
				if (typeIs(value, "number")) totals[key as string] = (totals[key as string] ?? 0) + value;
			}
		}
		for (const [key, amount] of pairs(totals)) {
			const kind = REWARD_KINDS[key as string];
			if (kind !== undefined && amount > 0) chapterTotals.push({ key: key as string, name: kind.name, tag: kind.tag(amount), glyph: kind.glyph, color: kind.color });
		}
		chapterTotals.sort((a, b) => REWARD_KINDS[a.key].order < REWARD_KINDS[b.key].order);
	}
	const readyCount = current !== undefined ? current.pages.filter((page) => page.ready).size() : 0;
	// .wrap of .sc reward tiles, two to a row (176 + 12 + 176 fills the 390 column)
	const tilesPerRow = math.max(1, math.floor((L.SideReward.w + L.SideReward.gap) / (L.SideCard.w + L.SideReward.gap)));
	const tileRows = math.max(1, math.ceil(chapterTotals.size() / tilesPerRow));
	const wrapH = chapterTotals.size() === 0 ? rowH : tileRows * L.SideCard.h + (tileRows - 1) * L.SideReward.gap;
	const lineH = L.SideLine.h;
	const sideContent = head + wrapH + pad.gap + lineH + pad.gap + L.SideRow.h + (nextOpen !== undefined ? pad.gap + L.SideBtn.h : 0);
	const sideH = panelHeight(phone, sideContent);
	const side = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} reveal={enter} reducedMotion={reducedMotion} name="ChapterReward">
			<PanelHeading icon="Gift" title="Chapter reward" phone={phone} layoutOrder={0} />
			{chapterTotals.size() === 0 ? (
				<MockRow phone={phone} icon="Gift" title="No rewards in this chapter" dim={true} layoutOrder={1} />
			) : (
				<frame Size={new UDim2(1, 0, 0, wrapH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
					<uigridlayout
						CellSize={UDim2.fromOffset(L.SideCard.w, L.SideCard.h)}
						CellPadding={UDim2.fromOffset(L.SideReward.gap, L.SideReward.gap)}
						FillDirectionMaxCells={tilesPerRow}
						SortOrder={Enum.SortOrder.LayoutOrder}
					/>
					{chapterTotals.map((tile, index) => (
						<RewardTile key={tile.key} tile={tile} reducedMotion={reducedMotion} layoutOrder={index} />
					))}
				</frame>
			)}
			<Line
				text={current !== undefined ? `Fill all ${current.pages.size()} pages in this chapter.` : "Pages appear as you play."}
				size={L.SideLine.text.size}
				font={BODY}
				color={L.SideLine.text.color}
				width={new UDim(1, 0)}
				height={lineH}
				layoutOrder={20}
			/>
			<MockRow phone={phone} icon="Timer" title="Ready to claim" value={readyCount > 0 ? `${readyCount} new` : "None"} height={L.SideRow.h} layoutOrder={21} />
			{nextOpen !== undefined && (
				<MockBtn text="Open next page" icon="Journal" fill={true} phone={phone} onClick={() => setOpenId(nextOpen.entry.Id)} reducedMotion={reducedMotion} layoutOrder={22} />
			)}
		</MockPanel>
	);

	const sections: { id: string; height: number; element: React.Element }[] = [];
	if (!inHero) {
		const note = tab === "Keepsakes" ? `${filledTotal} of ${allPages.size()} pages` : panelCount;
		sections.push({ id: "head", height: PH_HEAD_H, element: <PhoneHead line={note} options={TABS} value={tab} onChange={(id) => setTab(id)} accent={Palette.mango} reducedMotion={reducedMotion} /> });
	}
	// phone.html shows the page grid alone; the chapter reward card is desktop-only there
	const showSide = tab === "Pages" && !phone;
	if (!showSide) {
		sections.push({ id: "pages", height: mainH, element: mainPanel });
	} else {
		const bodyH = math.max(mainH, sideH);
		sections.push({
			id: "body",
			height: bodyH,
			element: (
				<FlexRow fillHeight={true} gap={L.Body.gap} name="JournalBody">
					<FlexFill layoutOrder={0}>{mainPanel}</FlexFill>
					<FlexFixed width={L.Side.w} height={sideH} layoutOrder={1}>
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

// The Story page: chapters from under Bay Seven. A chapter rail (or, on phones, an archive list) picks
// the chapter; the reader plays it one beat at a time with the text typing itself in, and the last beat
// collects the chapter's reward. Finished chapters replay.
import React from "@rbxts/react";
import { Icon } from "../../ArtKit/Icon";
import { formatReward } from "../../CoreKit/format";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { ClientLog } from "../../CoreKit/log";
import { chromeFor, darken, Layout, Palette, TapTarget } from "../../CoreKit/theme";
import { useAntilag } from "../../MotionKit/antilag";
import { useEntrance, usePulse, useStagger, useViewport } from "../../MotionKit/motion";
import { Badge, Button, EmptyState, measureWrappedTextHeight, Meter, meterFill, SearchField, Text } from "../../UiCore/ui";
import { Component, loadAudio, loadBrowse, loadPageScaffold, luauKit, named } from "../luauDeps";

const UserInputService = game.GetService("UserInputService");
const Audio = loadAudio();
const Browse = loadBrowse();
const PageScaffold = loadPageScaffold();
const FlatList = luauKit<{ FlatList: Component }>("LayoutKit", "virtualizedList").FlatList;

const CHAPTER_ROW_H = 58;
const CHAPTER_ROW_GAP = 8;
const CHAPTER_ROW_STRIDE = CHAPTER_ROW_H + CHAPTER_ROW_GAP;
const ILLUMINATED = ["Bay Seven", "Stellar Core", "ILYRA VALE", "Astral Forge", "Hollow Star", "stars"];

/** A chapter's progress, from the player's state. */
interface ChapterStatus {
	Id: string;
	Unlocked?: boolean;
	Read?: boolean;
	Claimed?: boolean;
	Progress: number;
	Target: number;
}
/** A chapter's words, from the config. */
interface ChapterDef {
	Id: string;
	Chapter: string;
	Title: string;
	Summary?: string;
	Body?: string[];
	Color: Color3;
	Reward?: unknown;
}
interface Props {
	state: { Story?: ChapterStatus[] };
	config: { Story?: ChapterDef[] };
	dispatch: (action: string, payload?: object) => unknown;
	reducedMotion?: boolean;
}

/** Bold the story's proper names in the chapter colour (RichText). */
function illuminate(text: string, accent: Color3): string {
	const rgb = `${math.floor(accent.R * 255)},${math.floor(accent.G * 255)},${math.floor(accent.B * 255)}`;
	let result = text;
	for (const phrase of ILLUMINATED) {
		[result] = result.gsub(phrase, `<font color="rgb(${rgb})"><b>${phrase}</b></font>`);
	}
	return result;
}

function chapterConfig(config: Props["config"], id: string): ChapterDef | undefined {
	return typeIs(config.Story, "table") ? config.Story.find((entry) => entry.Id === id) : undefined;
}

/** The first open chapter not yet collected, else the first open one, else the first. */
function pickDefaultChapter(chapters: ChapterStatus[]): string | undefined {
	return (chapters.find((c) => c.Unlocked === true && !c.Claimed) ?? chapters.find((c) => c.Unlocked === true) ?? chapters[0])?.Id;
}

interface MarkProps {
	accent: Color3;
	active: boolean;
	reducedMotion?: boolean;
	beat: number;
	total: number;
	compact: boolean;
	finished: boolean;
	unlocked: boolean;
	unlockProgress: number;
	unlockLabel: string;
	reward: string;
	claimed: boolean;
}

/** The chapter's seal: open / ready / locked / replay, with how far along it is. */
function ArchiveMark(props: MarkProps) {
	const { accent, active, reducedMotion, finished, unlocked } = props;
	const pulse = usePulse(active && !reducedMotion, 1.2);
	const enter = useEntrance(reducedMotion);
	const progress = active ? meterFill(props.beat + 1, math.max(1, props.total)) : finished ? 1 : math.clamp(props.unlockProgress, 0, 1);
	const statusLabel = !active && finished ? "REPLAY" : active ? "OPEN" : unlocked ? "READY" : "LOCKED";
	let detail = active
		? `Part ${props.beat + 1} / ${math.max(1, props.total)}`
		: finished
			? "Finished chapter"
			: unlocked
				? "Ready to read"
				: props.unlockLabel;
	// show what the chapter pays before it's collected, not only on the last page
	if (!active && !props.claimed && props.reward !== "") detail = `${detail} · ${props.reward}`;
	if (props.compact) {
		return (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={darken(accent, 0.92)} BorderSizePixel={0} ClipsDescendants={true}>
				<uicorner CornerRadius={new UDim(0, 12)} />
				<uigradient Color={new ColorSequence(darken(accent, 0.86), Palette.void)} Rotation={90} />
				<frame Size={new UDim2(0, 3, 1, -16)} Position={UDim2.fromOffset(0, 8)} BackgroundColor3={accent} BorderSizePixel={0}>
					<uicorner CornerRadius={new UDim(0, 2)} />
				</frame>
				<Icon kind="Story.2" color={Palette.cream} accent={accent} size={32} position={UDim2.fromOffset(14, 14)} />
				<Text value={statusLabel} size={11} color={accent} weight={Enum.FontWeight.Heavy} position={UDim2.fromOffset(56, 12)} sizeConstraint={new UDim2(1, -70, 0, 16)} />
				<Text
					value={detail}
					size={13}
					color={Palette.cream}
					weight={Enum.FontWeight.Bold}
					wrap={true}
					fit={true}
					minSize={9}
					position={UDim2.fromOffset(56, 30)}
					sizeConstraint={new UDim2(1, -70, 0, 22)}
				/>
				<Meter value={progress} color={accent} reducedMotion={reducedMotion} position={UDim2.fromOffset(14, 54)} size={new UDim2(1, -28, 0, 5)} />
			</frame>
		);
	}
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={darken(accent, 0.92)} BorderSizePixel={0} ClipsDescendants={true}>
			<uicorner CornerRadius={new UDim(0, 14)} />
			<uigradient Color={new ColorSequence(darken(accent, 0.86), Palette.void)} Rotation={112} />
			<frame Size={new UDim2(0, 3, 0.5, 0)} Position={new UDim2(0, 2, 0.25, 0)} BackgroundColor3={accent} BackgroundTransparency={0.15} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(0, 2)} />
			</frame>
			<frame
				Size={UDim2.fromOffset(84, 84)}
				Position={new UDim2(0.5, 0, 0, 28)}
				AnchorPoint={new Vector2(0.5, 0)}
				BackgroundColor3={Palette.panel}
				BackgroundTransparency={enter.map((amount) => 1 - amount)}
				BorderSizePixel={0}
				ClipsDescendants={true}
			>
				<uiscale Scale={pulse.map((amount) => 1 + amount * 0.03)} />
				<uicorner CornerRadius={new UDim(0, 22)} />
				<uistroke Color={accent} Thickness={1} Transparency={0.28} />
				<Icon kind="Story.3" color={Palette.cream} accent={accent} size={48} position={UDim2.fromOffset(18, 18)} />
			</frame>
			<frame Size={new UDim2(0.86, 0, 0, 64)} Position={new UDim2(0.07, 0, 0, 124)} BackgroundTransparency={1} BorderSizePixel={0}>
				<Text value={statusLabel} size={12} color={accent} weight={Enum.FontWeight.Heavy} align={Enum.TextXAlignment.Center} sizeConstraint={new UDim2(1, 0, 0, 16)} />
				<Text
					value={detail}
					size={12}
					color={Palette.creamSoft}
					weight={Enum.FontWeight.Bold}
					fit={true}
					minSize={9}
					align={Enum.TextXAlignment.Center}
					position={UDim2.fromOffset(0, 20)}
					sizeConstraint={new UDim2(1, 0, 0, 18)}
				/>
				<Meter value={progress} color={accent} reducedMotion={reducedMotion} position={UDim2.fromOffset(0, 46)} size={new UDim2(1, 0, 0, 6)} />
			</frame>
		</frame>
	);
}

function ChapterRailRow(props: { chapter?: ChapterStatus; entry?: ChapterDef; selected: boolean; onSelect: () => void; layoutOrder?: number }) {
	const { chapter, entry } = props;
	// A browse row with no chapter used to throw on Unlocked and take the page down.
	if (!typeIs(chapter, "table") || !typeIs(entry, "table")) {
		return <frame Size={new UDim2(1, 0, 0, CHAPTER_ROW_H)} BackgroundTransparency={1} BorderSizePixel={0} />;
	}
	const open = chapter.Unlocked === true;
	const done = chapter.Claimed === true || chapter.Read === true;
	const accent = entry.Color;
	return (
		<textbutton
			Size={new UDim2(1, -4, 0, CHAPTER_ROW_H)}
			BackgroundColor3={props.selected ? Palette.panel : Palette.ink}
			BorderSizePixel={0}
			Text=""
			AutoButtonColor={false}
			Active={true}
			Selectable={true}
			LayoutOrder={props.layoutOrder}
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
		>
			<uicorner CornerRadius={new UDim(0, 10)} />
			<uistroke
				Color={props.selected ? accent : Palette.lineSoft}
				Thickness={1}
				Transparency={props.selected ? 0.15 : 0.55}
				ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
			/>
			<frame Size={new UDim2(0, 3, 1, -12)} Position={UDim2.fromOffset(0, 6)} BackgroundColor3={open ? accent : Palette.muted} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(0, 2)} />
			</frame>
			<Text
				value={entry.Chapter}
				size={10}
				color={open ? accent : Palette.muted}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={8}
				position={UDim2.fromOffset(12, 8)}
				sizeConstraint={new UDim2(1, -84, 0, 14)}
			/>
			<Text
				value={entry.Title}
				size={13}
				color={open ? Palette.cream : Palette.muted}
				weight={Enum.FontWeight.Bold}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(12, 24)}
				sizeConstraint={new UDim2(1, -84, 0, 18)}
			/>
			{!open && (
				<Text
					value={`${math.floor(chapter.Progress)} / ${chapter.Target}`}
					size={10}
					color={Palette.muted}
					position={UDim2.fromOffset(12, 42)}
					sizeConstraint={new UDim2(1, -84, 0, 12)}
				/>
			)}
			<Badge
				value={!open ? "LOCK" : done ? "DONE" : "NEW"}
				accent={open ? (done ? Palette.mint : accent) : Palette.muted}
				filled={open}
				position={new UDim2(1, -70, 0.5, -11)}
				size={UDim2.fromOffset(62, 22)}
			/>
		</textbutton>
	);
}

interface BeatProps {
	text: string;
	index: number;
	total: number;
	color: Color3;
	reducedMotion?: boolean;
	claimed: boolean;
	reward: string;
	replay: boolean;
	onBack: () => void;
	onNext: () => void;
	onClaim: () => void;
	onClose: () => void;
	stack: boolean;
	condensed: boolean;
}

/** One beat of the chapter: the text types itself in; Back / Continue (or Collect / Done) below. */
function StoryBeat(props: BeatProps) {
	const { text, index, total, color, reducedMotion, claimed, stack, condensed } = props;
	const enter = useEntrance(reducedMotion);
	const viewport = useViewport();
	const [visible, setVisible] = React.useBinding(0);
	React.useEffect(() => {
		let alive = true;
		setVisible(0);
		Audio.play("storyBeat");
		const stepDiv = reducedMotion ? 28 : 72;
		const stepWait = reducedMotion ? 0.012 : 0.022;
		const revealWorker = task.spawn(() => {
			let count = 0;
			const step = math.max(1, math.floor(text.size() / stepDiv));
			while (alive && count < text.size()) {
				count = math.min(text.size(), count + step);
				setVisible(count);
				task.wait(stepWait);
			}
		});
		return () => {
			alive = false;
			pcall(() => task.cancel(revealWorker));
		};
	}, [index, reducedMotion, props.replay, text]);
	const final = index >= total - 1;
	const action = final ? (claimed ? props.onClose : props.onClaim) : props.onNext;
	const actionText = final ? (claimed ? "Done" : "Collect reward") : "Continue";
	const storyActionsHostRef = React.useRef<Frame>();
	// a controller lands on the beat's main action
	React.useEffect(() => {
		const host = storyActionsHostRef.current;
		if (!UserInputService.GamepadEnabled || host === undefined) return undefined;
		const selectJob = task.defer(() => {
			if (host.Parent !== undefined) GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, selectJob);
		};
	}, [index, claimed, actionText]);
	const tipText = props.replay ? "Replay: read any part" : `Part ${index + 1} of ${total}`;
	const btnH = stack ? TapTarget : 48;
	const showTip = !condensed && !stack;
	const tipH = showTip ? 32 : 0;
	const stacked = stack && !condensed;
	const actionsH = stacked ? btnH * 2 + 10 : btnH;
	const bodySize = stack ? 17 : 20;
	const lineHeight = stack ? 1.36 : 1.42;
	const partFill = meterFill(index + 1, total);
	const bodyGap = stack ? 16 : Layout.panelGap;
	const bodyPadR = stack ? 4 : Layout.stackGap;
	const measureWidth = math.max(160, math.floor((viewport.width ?? 390) * (stack ? 0.92 : 0.55)) - bodyPadR - 12);
	const textH = math.max(64, math.ceil(measureWrappedTextHeight(text, measureWidth, bodySize, Enum.FontWeight.Medium) * lineHeight) + 8);
	const estimatedBodyH = textH + (final ? 56 + bodyGap : 0) + (stack ? 24 : 16) + 12;
	const fade = enter.map((amount) => 1 - amount);

	const headerElement = stack ? (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<Meter value={partFill} color={color} reducedMotion={reducedMotion} shimmer={final} position={UDim2.fromOffset(0, 4)} size={new UDim2(1, 0, 0, 4)} />
		</frame>
	) : (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<Text value={`Part ${index + 1} of ${total}`} size={13} color={color} weight={Enum.FontWeight.Heavy} sizeConstraint={new UDim2(1, 0, 0, 20)} transparency={fade} />
			<Meter value={partFill} color={color} reducedMotion={reducedMotion} shimmer={final} position={UDim2.fromOffset(0, 26)} size={new UDim2(1, 0, 0, 5)} />
		</frame>
	);
	const bodyElement = (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, bodyGap)} />
			<uipadding PaddingRight={new UDim(0, bodyPadR)} PaddingBottom={new UDim(0, 12)} />
			<textlabel
				Size={new UDim2(1, -4, 0, 0)}
				AutomaticSize={Enum.AutomaticSize.Y}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				Text={illuminate(text, color)}
				RichText={true}
				TextColor3={Palette.cream}
				TextSize={bodySize}
				FontFace={Font.fromEnum(Enum.Font.BuilderSansMedium)}
				TextWrapped={true}
				TextXAlignment={Enum.TextXAlignment.Left}
				TextYAlignment={Enum.TextYAlignment.Top}
				LineHeight={lineHeight}
				MaxVisibleGraphemes={visible}
				TextTransparency={fade}
				TextScaled={false}
				TextTruncate={Enum.TextTruncate.None}
				LayoutOrder={0}
			/>
			{final && (
				<frame Size={new UDim2(1, -4, 0, 56)} BackgroundColor3={Palette.panel} BorderSizePixel={0} LayoutOrder={1} ClipsDescendants={false}>
					<uicorner CornerRadius={new UDim(0, 10)} />
					<uistroke Color={color} Thickness={1} Transparency={0.35} />
					<frame Size={new UDim2(0, 3, 1, -12)} Position={UDim2.fromOffset(0, 6)} BackgroundColor3={color} BorderSizePixel={0}>
						<uicorner CornerRadius={new UDim(0, 2)} />
					</frame>
					<Text
						value={claimed ? "REWARD CLAIMED" : "REWARD"}
						size={11}
						color={color}
						weight={Enum.FontWeight.Heavy}
						position={UDim2.fromOffset(16, 8)}
						sizeConstraint={new UDim2(1, -28, 0, 16)}
					/>
					<Text
						value={props.reward}
						size={15}
						color={Palette.cream}
						weight={Enum.FontWeight.Bold}
						wrap={true}
						fit={true}
						minSize={11}
						position={UDim2.fromOffset(16, 26)}
						sizeConstraint={new UDim2(1, -28, 0, 24)}
					/>
				</frame>
			)}
			<frame Size={new UDim2(1, 0, 0, stack ? 24 : 16)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2} />
		</frame>
	);
	const tipElement = (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
			<frame Size={UDim2.fromOffset(0, tipH)} AutomaticSize={Enum.AutomaticSize.X} BackgroundColor3={Palette.panelSoft} BorderSizePixel={0} ClipsDescendants={false}>
				<uicorner CornerRadius={new UDim(0, 8)} />
				<uistroke Color={Palette.green} Thickness={1} Transparency={0.4} />
				<uipadding PaddingLeft={new UDim(0, 12)} PaddingRight={new UDim(0, 12)} />
				<textlabel
					Size={new UDim2(0, 0, 1, 0)}
					AutomaticSize={Enum.AutomaticSize.X}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					Text={tipText}
					TextColor3={Palette.green}
					TextSize={12}
					FontFace={Font.fromEnum(Enum.Font.BuilderSansBold)}
					TextXAlignment={Enum.TextXAlignment.Left}
					TextYAlignment={Enum.TextYAlignment.Center}
					TextTruncate={Enum.TextTruncate.None}
					ZIndex={4}
				/>
			</frame>
		</frame>
	);
	const continueSlot = (
		<frame
			{...named(final && !claimed ? "StoryClaim" : "StoryContinue")}
			Size={stacked ? new UDim2(1, 0, 0, btnH) : new UDim2(1, -140, 0, btnH)}
			Position={stacked ? undefined : UDim2.fromOffset(140, 0)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			LayoutOrder={0}
		>
			<Button
				text={actionText}
				icon={final ? (claimed ? "Check" : "Gift") : "Chevron"}
				onClick={action}
				color={final ? color : Palette.mint}
				textColor={Palette.ink}
				size={UDim2.fromScale(1, 1)}
				reducedMotion={reducedMotion}
				highlight={!claimed || props.replay}
			/>
		</frame>
	);
	const backSlot = (
		<frame
			{...named("StoryBack")}
			Size={stacked ? new UDim2(1, 0, 0, btnH) : UDim2.fromOffset(128, btnH)}
			Position={stacked ? undefined : UDim2.fromOffset(0, 0)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			LayoutOrder={1}
		>
			<Button
				text="Back"
				icon="Back.2"
				onClick={props.onBack}
				color={Palette.panelSoft}
				textColor={Palette.creamSoft}
				outline={true}
				size={UDim2.fromScale(1, 1)}
				disabled={index <= 0}
				reducedMotion={reducedMotion}
			/>
		</frame>
	);
	const sections = [
		{ id: "beat-header", height: stack ? 28 : 40, element: headerElement },
		{ id: "beat-body", fill: true, minHeight: 72, height: estimatedBodyH, element: bodyElement },
	];
	if (showTip) sections.push({ id: "beat-tip", height: tipH, element: tipElement });
	const actionsGap = 8;
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
			<frame Size={new UDim2(1, 0, 1, -(actionsH + actionsGap))} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={true}>
				<PageScaffold gap={showTip ? Layout.stackGap : 6} tailPad={4} scrollBarColor={color} scrollBarThickness={stack ? 4 : 3} sections={sections} />
			</frame>
			<frame
				{...named("StoryBeatActions")}
				ref={storyActionsHostRef}
				Size={new UDim2(1, 0, 0, actionsH)}
				Position={new UDim2(0, 0, 1, -actionsH)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={false}
				ZIndex={6}
			>
				{stacked ? (
					<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
						<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 10)} />
						{continueSlot}
						{backSlot}
					</frame>
				) : (
					<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
						{backSlot}
						{continueSlot}
					</frame>
				)}
			</frame>
		</frame>
	);
}

function StoryView({ state, config, dispatch, reducedMotion }: Props) {
	const softMotion = reducedMotion;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const stack = chrome.contentStack;
	const shortLandscape = chrome.landscape && viewport.height < 500;
	const chapters = typeIs(state.Story, "table") ? state.Story : [];
	const [selectedId, setSelectedId] = React.useState(() => pickDefaultChapter(chapters));
	const [started, setStarted] = React.useState(false);
	const [beat, setBeat] = React.useState(0);
	/** Show a chapter's cover (not reading yet). */
	const openChapter = (id: string | undefined) => {
		setSelectedId(id);
		setStarted(false);
		setBeat(0);
	};
	React.useEffect(() => {
		Audio.play("storyOpen");
		ClientLog.debug("nav", "story opened");
	}, []);
	// the selected chapter disappeared (new state): fall back to the default
	React.useEffect(() => {
		if (selectedId === undefined || chapters.find((chapter) => chapter.Id === selectedId) === undefined) {
			openChapter(pickDefaultChapter(chapters));
		}
	}, [chapters, selectedId]);
	React.useEffect(() => {
		if (started && selectedId !== undefined) ClientLog.debug("story", `${selectedId} beat ${beat + 1}`);
	}, [beat, selectedId, started]);
	const status = chapters.find((chapter) => chapter.Id === selectedId);
	const story = status !== undefined ? chapterConfig(config, status.Id) : undefined;
	const antilag = useAntilag();
	const intro = useEntrance(softMotion);
	const archivePulse = usePulse(!softMotion && !started, 3.4);
	const archiveReveal = useStagger(0, softMotion);
	const chapterBrowse = Browse.useBrowse<ChapterStatus>({
		id: "Story",
		items: chapters,
		text: (chapter) => {
			if (!typeIs(chapter, "table")) return [];
			const entry = chapterConfig(config, chapter.Id);
			return [entry?.Title ?? chapter.Id, entry?.Chapter, entry?.Summary];
		},
		categories: [
			{ id: "All", label: "All" },
			{ id: "New", label: "New", test: (chapter) => typeIs(chapter, "table") && chapter.Unlocked === true && chapter.Read !== true },
			{ id: "Reward", label: "Reward", test: (chapter) => typeIs(chapter, "table") && chapter.Unlocked === true && chapter.Claimed !== true && chapter.Read === true },
			{ id: "Read", label: "Read", test: (chapter) => typeIs(chapter, "table") && chapter.Read === true },
			{ id: "Locked", label: "Locked", test: (chapter) => typeIs(chapter, "table") && chapter.Unlocked !== true },
		],
	});
	// a search that lands on one clear match opens it directly
	React.useEffect(() => {
		const top = chapterBrowse.results[0];
		if (chapterBrowse.searching && chapterBrowse.relevance !== undefined && chapterBrowse.relevance !== false && top !== undefined && top.Id !== selectedId) {
			openChapter(top.Id);
		}
	}, [chapterBrowse.query]);
	if (story === undefined || status === undefined) {
		return <frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} />;
	}

	const body = typeIs(story.Body, "table") ? story.Body : [];
	const reward = formatReward(story.Reward as never);
	const finished = status.Read === true || status.Claimed === true;
	const locked = status.Unlocked !== true;
	const unlockFill = meterFill(status.Progress, math.max(1, status.Target), status.Unlocked);
	const unlockLabel = locked ? `${math.floor(status.Progress)} / ${status.Target}` : story.Chapter;
	const begin = () => {
		if (locked) return;
		setBeat(0);
		setStarted(true);
		Audio.play("storyOpen");
		if (!status.Read) dispatch("ReadStoryChapter", { Id: story.Id });
	};
	const closeReplay = () => {
		Audio.play("close");
		setStarted(false);
		setBeat(0);
	};
	const selectChapter = (id: string) => {
		Audio.play("page");
		openChapter(id);
	};
	const advance = () => {
		Audio.play("storyReveal");
		setBeat(math.min(body.size() - 1, beat + 1));
	};
	const rewind = () => {
		Audio.play("close");
		setBeat(math.max(0, beat - 1));
	};
	const readingMobile = stack && started;
	const markH = readingMobile ? 0 : stack ? (chrome.landscape ? 0 : 68) : 76;
	const railGap = 14;
	const railShare = 0.26;
	const chapterCount = chapters.size();
	let unlockedCount = 0;
	let claimedCount = 0;
	for (const chapter of chapters) {
		if (!typeIs(chapter, "table")) continue;
		if (chapter.Unlocked) unlockedCount += 1;
		if (chapter.Claimed) claimedCount += 1;
	}
	const multi = chapterCount > 1;
	const railMarkH = multi && !stack ? 84 : stack ? markH : 0;
	// the mark is ~76px of content; taller only left an empty card
	const readerPad = shortLandscape ? 12 : stack ? (started ? 12 : 14) : Layout.contentInset;
	const shownChapters: Array<{ chapter: ChapterStatus; entry: ChapterDef }> = [];
	for (const chapter of chapterBrowse.results) {
		const entry = chapterConfig(config, chapter.Id);
		if (entry !== undefined) shownChapters.push({ chapter, entry });
	}
	const mark = (compact: boolean) => (
		<ArchiveMark
			accent={story.Color}
			active={started}
			reducedMotion={softMotion}
			beat={beat}
			total={body.size()}
			compact={compact}
			finished={finished}
			unlocked={status.Unlocked === true}
			unlockProgress={unlockFill}
			unlockLabel={unlockLabel}
			reward={reward}
			claimed={status.Claimed === true}
		/>
	);
	const readLabel = locked ? "Locked" : finished ? "Open selected" : "Read selected";
	const coverButton = (text: string, icon: string, size: UDim2, position?: UDim2) => (
		<Button
			text={text}
			icon={icon}
			onClick={begin}
			color={locked ? Palette.panelSoft : story.Color}
			textColor={locked ? Palette.muted : Palette.ink}
			size={size}
			position={position}
			disabled={locked}
			reducedMotion={softMotion}
			highlight={!locked}
		/>
	);

	// the rail (desktop): the chapter's mark on top, then search, filter chips and the chapter list
	let rail: React.Element | undefined;
	if (!readingMobile && markH > 0) {
		const railHeaderH = 20 + TapTarget + 8 + Browse.CHIP_H + 8;
		const railListTop = railMarkH + 10;
		rail = (
			<frame
				Size={stack ? new UDim2(1, 0, 0, markH) : new UDim2(railShare, -railGap / 2, 1, 0)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={true}
			>
				{(stack || multi) && (
					<frame Size={stack ? UDim2.fromScale(1, 1) : new UDim2(1, 0, 0, railMarkH)} BackgroundTransparency={1} BorderSizePixel={0}>
						{mark(true)}
					</frame>
				)}
				{!stack && multi && (
					<frame Size={new UDim2(1, 0, 1, -railListTop)} Position={UDim2.fromOffset(0, railListTop)} BackgroundTransparency={1} BorderSizePixel={0}>
						<Text
							value="CHAPTERS"
							size={10}
							color={Palette.muted}
							weight={Enum.FontWeight.Heavy}
							sizeConstraint={new UDim2(1, 0, 0, 16)}
							transparency={archiveReveal.map((amount) => 1 - amount)}
						/>
						<SearchField
							value={chapterBrowse.query}
							onChange={chapterBrowse.setQuery}
							placeholder="Search chapters"
							accent={story.Color}
							reducedMotion={softMotion}
							position={UDim2.fromOffset(0, 20)}
							size={new UDim2(1, -4, 0, TapTarget)}
							zIndex={12}
						/>
						<Browse.ChipRow
							options={chapterBrowse.categories}
							value={chapterBrowse.category}
							onChange={chapterBrowse.setCategory}
							counts={chapterBrowse.counts}
							accent={story.Color}
							position={UDim2.fromOffset(0, 20 + TapTarget + 8)}
							size={new UDim2(1, -4, 0, Browse.CHIP_H)}
						/>
						{shownChapters.size() === 0 && (
							<frame BackgroundTransparency={1} BorderSizePixel={0} Position={UDim2.fromOffset(0, railHeaderH)} Size={new UDim2(1, 0, 0, 112)}>
								<EmptyState icon="Story" title="No chapters match" body="Clear the search or pick another filter." accent={story.Color} compact={true} size={UDim2.fromScale(1, 1)} />
							</frame>
						)}
						<FlatList
							data={shownChapters}
							itemHeight={CHAPTER_ROW_STRIDE}
							headerHeight={0}
							overscan={softMotion ? 0 : antilag.constrained ? 1 : 2}
							canvasTail={8}
							Size={new UDim2(1, 0, 1, -railHeaderH)}
							Position={UDim2.fromOffset(0, railHeaderH)}
							scrollBarColor={story.Color}
							scrollBarThickness={3}
							keyExtractor={(item: (typeof shownChapters)[number]) => item.chapter.Id}
							renderItem={({ item, index }: { item: (typeof shownChapters)[number]; index: number }) => (
								<ChapterRailRow
									chapter={item.chapter}
									entry={item.entry}
									selected={item.chapter.Id === status.Id}
									onSelect={() => selectChapter(item.chapter.Id)}
									layoutOrder={index}
								/>
							)}
						/>
					</frame>
				)}
				{!stack && !multi && mark(false)}
			</frame>
		);
	}

	// phones, not reading: the whole archive as one scrolling list
	let archive: React.Element | undefined;
	if (!started && multi && stack) {
		archive = (
			<PageScaffold
				inset={16}
				gap={8}
				tailPad={4}
				scrollBarColor={story.Color}
				sections={[
					{
						id: "archive-head",
						height: 26,
						element: (
							<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
								<Badge value="STORY" accent={story.Color} filled={true} position={UDim2.fromOffset(0, 2)} size={UDim2.fromOffset(88, 24)} />
								<Text
									value={`${claimedCount}/${chapterCount} archived  ·  ${unlockedCount} open`}
									size={13}
									color={story.Color}
									weight={Enum.FontWeight.Heavy}
									align={Enum.TextXAlignment.Right}
									position={new UDim2(0, 100, 0, 4)}
									sizeConstraint={new UDim2(1, -100, 0, 20)}
								/>
							</frame>
						),
					},
					{
						id: "archive-title",
						height: 32,
						element: <Text value="Bay Seven" size={22} color={Palette.cream} weight={Enum.FontWeight.Heavy} fit={true} minSize={16} sizeConstraint={new UDim2(1, 0, 0, 32)} />,
					},
					{
						id: "archive-browse",
						height: Browse.barHeight(true, true),
						element: <Browse.BrowseBar browse={chapterBrowse} placeholder="Search chapters" accent={story.Color} stack={true} reducedMotion={softMotion} zIndex={30} />,
					},
					{
						id: "archive-chapters",
						fill: true,
						minHeight: 140,
						height: math.max(140, shownChapters.size() * CHAPTER_ROW_STRIDE + 8),
						element: (
							<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
								<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, CHAPTER_ROW_GAP)} />
								{shownChapters.map(({ chapter, entry }, i) => (
									<ChapterRailRow
										key={chapter.Id}
										chapter={chapter}
										entry={entry}
										selected={chapter.Id === status.Id}
										onSelect={() => selectChapter(chapter.Id)}
										layoutOrder={i}
									/>
								))}
								<frame Size={new UDim2(1, 0, 0, 8)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={99} />
							</frame>
						),
					},
					{ id: "archive-read", height: TapTarget, element: coverButton(readLabel, "Story.4", UDim2.fromScale(1, 1)) },
				]}
			/>
		);
	}

	// the chapter's cover: title, summary, and Start / Replay
	let cover: React.Element | undefined;
	if (!started && (!multi || !stack)) {
		cover = (
			<frame
				Size={new UDim2(1, -readerPad * 2, 1, shortLandscape ? -16 : -36)}
				Position={intro.map((amount) => new UDim2(0, readerPad + math.floor((1 - amount) * 12), 0, shortLandscape ? 8 : 18))}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={true}
			>
				<frame Size={new UDim2(1, 0, 0, 28)} BackgroundTransparency={1} BorderSizePixel={0}>
					<Badge value={multi ? "CHAPTER" : "STORY"} accent={story.Color} filled={true} position={UDim2.fromOffset(0, 2)} size={UDim2.fromOffset(110, 26)} />
					<Text
						value={story.Chapter}
						size={13}
						color={story.Color}
						weight={Enum.FontWeight.Heavy}
						wrap={true}
						fit={true}
						minSize={11}
						align={Enum.TextXAlignment.Right}
						position={new UDim2(0, 120, 0, 4)}
						sizeConstraint={new UDim2(1, -120, 0, 20)}
					/>
				</frame>
				<Text
					value={story.Title}
					size={shortLandscape || stack ? 22 : 34}
					color={Palette.cream}
					weight={Enum.FontWeight.Heavy}
					wrap={true}
					fit={true}
					minSize={16}
					position={UDim2.fromOffset(0, shortLandscape ? 34 : 40)}
					sizeConstraint={new UDim2(1, shortLandscape ? -224 : 0, 0, shortLandscape ? 34 : stack ? 64 : 78)}
				/>
				{!shortLandscape && (
					<Text
						value={story.Summary ?? ""}
						size={stack ? 14 : 16}
						color={Palette.creamSoft}
						wrap={true}
						fit={true}
						minSize={12}
						position={UDim2.fromOffset(0, stack ? 112 : 128)}
						sizeConstraint={new UDim2(1, 0, 0, stack ? 96 : 80)}
					/>
				)}
				{!shortLandscape && (
					<Text
						value={
							finished
								? "Finished. Open it any time to read again."
								: locked
									? "Keep playing to unlock this chapter."
									: multi
										? "Pick a chapter, then start reading."
										: "Short chapters from under Bay Seven."
						}
						size={13}
						color={Palette.muted}
						wrap={true}
						fit={true}
						minSize={11}
						position={UDim2.fromOffset(0, stack ? 220 : 224)}
						sizeConstraint={new UDim2(1, 0, 0, 40)}
					/>
				)}
				{coverButton(
					locked ? "Locked" : finished ? "Replay" : "Start reading",
					"Story.5",
					shortLandscape ? UDim2.fromOffset(210, TapTarget) : stack ? new UDim2(1, 0, 0, TapTarget) : new UDim2(0.5, 0, 0, 52),
					shortLandscape ? new UDim2(1, -210, 1, -TapTarget) : new UDim2(0, 0, 1, -(stack ? TapTarget + 4 : 56)),
				)}
			</frame>
		);
	}

	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.void} BorderSizePixel={0} ClipsDescendants={true}>
			<uicorner CornerRadius={new UDim(0, 14)} />
			<uistroke Color={story.Color} Thickness={1} Transparency={0.52} />
			{/* three faint orbit rings behind the archive breathe while you browse */}
			{!reducedMotion &&
				[0, 1, 2].map((index) => (
					<frame
						key={`archive-orbit-${index}`}
						Size={archivePulse.map((amount) => UDim2.fromOffset(260 + index * 82 + amount * 16, 260 + index * 82 + amount * 16))}
						Position={new UDim2(1, 50 - index * 32, 0, -70 + index * 28)}
						AnchorPoint={new Vector2(0.5, 0.5)}
						BackgroundTransparency={1}
						BorderSizePixel={0}
						Rotation={index * 17}
						ZIndex={0}
					>
						<uicorner CornerRadius={new UDim(1, 0)} />
						<uistroke Color={index === 1 ? Palette.cyan : story.Color} Thickness={1} Transparency={0.9 + index * 0.02} />
					</frame>
				))}
			{rail}
			<frame
				Size={readingMobile ? UDim2.fromScale(1, 1) : stack ? new UDim2(1, 0, 1, -(markH + 6)) : new UDim2(1 - railShare, -railGap / 2, 1, 0)}
				Position={readingMobile ? UDim2.fromOffset(0, 0) : stack ? UDim2.fromOffset(0, markH + 6) : new UDim2(railShare, railGap / 2, 0, 0)}
				BackgroundColor3={Palette.panelRaised}
				BorderSizePixel={0}
				ClipsDescendants={true}
			>
				<uicorner CornerRadius={new UDim(0, 14)} />
				<uistroke Color={Palette.lineSoft} Thickness={1} Transparency={0.6} />
				{!stack && (
					<frame Size={new UDim2(0, 2, 1, -32)} Position={UDim2.fromOffset(0, 16)} BackgroundColor3={story.Color} BorderSizePixel={0}>
						<uicorner CornerRadius={new UDim(0, 2)} />
					</frame>
				)}
				{archive}
				{cover}
				{started && (
					<frame
						Size={new UDim2(1, -readerPad * 2, 1, -(stack ? 20 : 32))}
						Position={UDim2.fromOffset(readerPad, stack ? 10 : 16)}
						BackgroundTransparency={1}
						BorderSizePixel={0}
						ClipsDescendants={true}
					>
						<StoryBeat
							key={`${story.Id}:${beat}:${finished ? "replay" : "live"}`}
							text={body[beat] ?? ""}
							index={beat}
							total={math.max(1, body.size())}
							color={story.Color}
							reducedMotion={softMotion}
							claimed={status.Claimed === true}
							reward={reward}
							replay={finished}
							onBack={rewind}
							onNext={advance}
							onClaim={() => {
								ClientLog.debug("story", `claim ${story.Id}`);
								dispatch("ClaimStoryChapter", { Id: story.Id });
							}}
							onClose={closeReplay}
							stack={stack}
							condensed={viewport.height < 620 || viewport.keyboardOpen || chrome.landscape}
						/>
					</frame>
				)}
			</frame>
		</frame>
	);
}

export = { StoryView };

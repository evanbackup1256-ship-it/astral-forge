// Quick Find: Ctrl/Cmd+K (or the top bar search) opens one panel that jumps anywhere in the game.
// The index and ranking live in QuickFindIndex; this file only draws the panel and handles input.
//
// It is built from the shared surfaces (UiCore/surface): a base Surface, an inset search field,
// section labels, SurfaceRows that light up on one spring each, and an inset preview pane on wide
// panels. Keys: Up/Down/Tab move (wrapping), PageUp/PageDown jump 5, Enter/A open, Esc/B close.
// The left stick and D-pad move too, and the pad is held by Quick Find while it is open.
import React from "@rbxts/react";
import { InteractionFeedback } from "./CoreKit/interaction";
import Model from "./BrowseModel";
import * as theme from "./CoreKit/theme";
import { revealOffset, usePresence, useViewport } from "./MotionKit/motion";
import { sinkPadInput } from "./CoreKit/padSink";
import { mergeEvents, showTooltipFor, useTooltip } from "./Tooltip";
import { KIND_META, Results, SearchEntry, search } from "./QuickFindIndex";
import {
	IconTile,
	KeyHint,
	KindChip,
	SectionLabel,
	Surface,
	SurfaceMetrics,
	SurfaceMotion,
	SurfaceRow,
	SurfaceText,
	useSurfaceEnter,
	useSurfaceSpring,
} from "./UiCore/surface";

const UserInputService = game.GetService("UserInputService");
const GuiService = game.GetService("GuiService");

interface AudioApi {
	play(name: string): void;
}
const AudioKit = require(script.Parent!.FindFirstChild("AudioKit")! as ModuleScript) as CallableFunction;
const Audio = (AudioKit("audio") as { Audio: AudioApi }).Audio;
const ArtKit = require(script.Parent!.FindFirstChild("ArtKit")! as ModuleScript) as CallableFunction;
const IconComponent = (ArtKit("Icon") as { Icon: unknown }).Icon as React.FC<IconProps>;

interface IconProps {
	kind?: string;
	color: Color3;
	accent: Color3;
	size: number;
	spin: boolean;
}
function Glyph(props: IconProps & { box: number }) {
	return (
		<frame
			Size={UDim2.fromOffset(props.box, props.box)}
			Position={UDim2.fromScale(0.5, 0.5)}
			AnchorPoint={new Vector2(0.5, 0.5)}
			BackgroundTransparency={1}
		>
			{React.createElement(IconComponent, {
				kind: props.kind,
				color: props.color,
				accent: props.accent,
				size: props.size,
				spin: false,
			})}
		</frame>
	);
}

const Palette = theme.Palette as unknown as Record<"mango" | "cream" | "creamSoft" | "muted" | "white" | "ink", Color3>;

const openers: Array<() => void> = [];

const ROW_H = 52;
const ROW_H_TOUCH = SurfaceMetrics.rowH;
const SECTION_H = 26;
const SEARCH_H = 48;
const FOOTER_H = 40;
const TIP_LONG_PRESS = 0.45;
const PAGE_STEP = 5;
// held keys repeat after a short pause, like a normal list
const REPEAT_DELAY = 0.35;
const REPEAT_EVERY = 0.07;
const STICK_ON = 0.6;
const STICK_OFF = 0.35;
const NAV_DOWN = new Set<Enum.KeyCode>([Enum.KeyCode.Down, Enum.KeyCode.DPadDown]);
const NAV_UP = new Set<Enum.KeyCode>([Enum.KeyCode.Up, Enum.KeyCode.DPadUp]);

function isHeld(key: Enum.KeyCode): boolean {
	if (UserInputService.IsKeyDown(key)) {
		return true;
	}
	for (const state of UserInputService.GetGamepadState(Enum.UserInputType.Gamepad1)) {
		if (state.KeyCode === key) {
			return state.UserInputState === Enum.UserInputState.Begin || state.UserInputState === Enum.UserInputState.Change;
		}
	}
	return false;
}

function actionWords(entry: SearchEntry): string {
	if (entry.locked) {
		return "Locked for now";
	}
	return entry.kind === "Action" ? "run it now" : entry.kind === "Page" ? "open the page" : "open it on its page";
}

// ── Row ────────────────────────────────────────────────────────────────────────

interface RowProps {
	entry: SearchEntry;
	index: number;
	order: number;
	selected: boolean;
	query: string;
	height: number;
	showKind: boolean;
	delay: number;
	reduced: boolean;
	onPick: (entry: SearchEntry) => void;
	onHover: (index: number) => void;
	register: (index: number, row: GuiObject | undefined) => void;
}

function Row(props: RowProps) {
	const entry = props.entry;
	// one spring per row; it only retargets, and all colour comes from the row's own accent,
	// so moving the highlight never repaints a row mid-tween
	const lit = useSurfaceSpring(props.selected ? 1 : 0, props.reduced);
	const enter = useSurfaceEnter(props.reduced, props.delay);
	const fade = enter.map((a) => 1 - math.clamp(a, 0, 1));
	// a cut-off title or line shows in full as a tip (hover, resting highlight, or long press)
	const [titleCut, setTitleCut] = React.useState(false);
	const [lineCut, setLineCut] = React.useState(false);
	const cut = titleCut || lineCut;
	const tipEvents = useTooltip(cut ? { title: entry.title, body: entry.subtitle } : undefined);
	const rowRef = React.useRef<TextButton>();
	const pressedAt = React.useRef<number>();
	React.useEffect(() => {
		const row = rowRef.current;
		// the preview pane already shows the whole text when it's there; mouse users have hover
		if (!props.selected || !cut || !props.showKind || row === undefined) {
			return undefined;
		}
		if (UserInputService.MouseEnabled && !UserInputService.GamepadEnabled) {
			return undefined;
		}
		return showTooltipFor(row, { title: entry.title, body: entry.subtitle });
	}, [props.selected, cut, entry.key]);

	const events = mergeEvents(tipEvents, {
		InputBegan: (_rbx: GuiObject, input: InputObject) => {
			if (input.UserInputType === Enum.UserInputType.Touch) {
				pressedAt.current = os.clock();
			}
		},
		Activated: () => {
			// a long press on a cut-off row was to read its tip, not to jump
			const held = pressedAt.current;
			pressedAt.current = undefined;
			if (cut && held !== undefined && os.clock() - held >= TIP_LONG_PRESS) {
				return;
			}
			InteractionFeedback.tap();
			props.onPick(entry);
		},
		MouseEnter: () => props.onHover(props.index),
	});
	const compact = props.height < ROW_H;
	const textLeft = 54;
	const badge = entry.badge ?? 0;
	const rightW = (props.showKind ? 96 : 0) + (badge > 0 ? 34 : 0);
	return (
		<SurfaceRow
			height={props.height}
			order={props.order}
			accent={entry.accent}
			lit={lit}
			enter={enter}
			zIndex={4}
			events={events as never}
			buttonRef={(row: TextButton | undefined) => {
				rowRef.current = row;
				props.register(props.index, row);
			}}
		>
			<IconTile size={compact ? 30 : 32} accent={entry.accent} position={new UDim2(0, 12, 0.5, 0)} anchor={new Vector2(0, 0.5)} zIndex={7}>
				<Glyph
					box={18}
					kind={entry.locked ? "Lock.18" : entry.icon}
					color={entry.locked ? Palette.muted : entry.accent}
					accent={entry.accent}
					size={18}
					spin={false}
				/>
			</IconTile>
			<SurfaceText
				text={Model.highlight(entry.title, props.query, "#" + entry.accent.ToHex())}
				rich={true}
				type="title"
				color={entry.locked ? Palette.creamSoft : lit.map((a) => Palette.cream.Lerp(Palette.white, math.clamp(a, 0, 1)))}
				size={new UDim2(1, -(textLeft + rightW + 12), 0, 18)}
				position={new UDim2(0, textLeft, 0.5, -18)}
				transparency={fade}
				zIndex={7}
				onFits={(fits) => setTitleCut(!fits)}
			/>
			<SurfaceText
				text={entry.subtitle ?? ""}
				type="small"
				color={Palette.creamSoft}
				size={new UDim2(1, -(textLeft + rightW + 12), 0, 15)}
				position={new UDim2(0, textLeft, 0.5, 2)}
				transparency={fade}
				zIndex={7}
				onFits={(fits) => setLineCut(!fits)}
			/>
			{rightW > 0 && (
				<frame
					Size={UDim2.fromOffset(rightW, 22)}
					Position={new UDim2(1, -12, 0.5, 0)}
					AnchorPoint={new Vector2(1, 0.5)}
					BackgroundTransparency={1}
					ZIndex={7}
				>
					<uilistlayout
						FillDirection={Enum.FillDirection.Horizontal}
						HorizontalAlignment={Enum.HorizontalAlignment.Right}
						VerticalAlignment={Enum.VerticalAlignment.Center}
						Padding={new UDim(0, 6)}
						SortOrder={Enum.SortOrder.LayoutOrder}
					/>
					{badge > 0 && <KindChip text={tostring(badge)} accent={Palette.mango} order={1} zIndex={8} />}
					{props.showKind && <KindChip text={KIND_META[entry.kind].label} order={2} zIndex={8} />}
				</frame>
			)}
		</SurfaceRow>
	);
}

// ── Preview (wide panels) ──────────────────────────────────────────────────────

// the picked row in full: big tile, what it is, the whole title and line, what Enter does
function Preview(props: { entry: SearchEntry; touch: boolean; reduced: boolean }) {
	const entry = props.entry;
	const enter = useSurfaceEnter(props.reduced, 0.001);
	const fade = enter.map((a) => 1 - math.clamp(a, 0, 1));
	const accent = entry.accent;
	const action = actionWords(entry);
	const badge = entry.badge ?? 0;
	return (
		<frame
			Size={UDim2.fromScale(1, 1)}
			Position={enter.map((a) => UDim2.fromOffset(0, revealOffset(a)))}
			BackgroundTransparency={1}
			ZIndex={4}
		>
			<IconTile size={48} accent={accent} zIndex={5}>
				<Glyph
					box={26}
					kind={entry.locked ? "Lock.18" : entry.icon}
					color={entry.locked ? Palette.muted : accent}
					accent={accent}
					size={26}
					spin={false}
				/>
			</IconTile>
			<SurfaceText
				text={string.upper(KIND_META[entry.kind].label)}
				type="label"
				color={accent}
				size={new UDim2(1, 0, 0, 14)}
				position={UDim2.fromOffset(0, 60)}
				transparency={fade}
				zIndex={5}
			/>
			<SurfaceText
				text={entry.title}
				type="display"
				wrap={true}
				fit={true}
				size={new UDim2(1, 0, 0, 48)}
				position={UDim2.fromOffset(0, 78)}
				transparency={fade}
				zIndex={5}
			/>
			<SurfaceText
				text={entry.subtitle ?? ""}
				type="body"
				color={Palette.creamSoft}
				wrap={true}
				fit={true}
				size={new UDim2(1, 0, 1, -(130 + 46))}
				position={UDim2.fromOffset(0, 130)}
				transparency={fade}
				zIndex={5}
			/>
			{badge > 0 && (
				<SurfaceText
					text={`${badge} ready`}
					type="hint"
					color={Palette.mango}
					size={new UDim2(1, 0, 0, 16)}
					position={new UDim2(0, 0, 1, -40)}
					transparency={fade}
					zIndex={5}
				/>
			)}
			<SurfaceText
				text={entry.locked ? action : props.touch ? `Tap to ${action}` : `Enter to ${action}`}
				type="hint"
				color={entry.locked ? Palette.muted : Palette.cream}
				size={new UDim2(1, 0, 0, 18)}
				position={new UDim2(0, 0, 1, -18)}
				transparency={fade}
				zIndex={5}
			/>
		</frame>
	);
}

// ── Panel ──────────────────────────────────────────────────────────────────────

interface QuickFindComponentProps {
	state: Record<string, unknown>;
	enabled?: boolean;
	reducedMotion?: boolean;
	chatUnread?: number;
	dispatch: (action: string) => void;
	navigate: (route: string) => void;
}

const NO_RESULTS: Results = { sections: [], flat: [], total: 0 };

// Mounted once per open, so it enters with the game's panel presence and leaves with its exit.
function QuickFindPanel(props: QuickFindComponentProps & { onClosed: () => void }) {
	const [query, setQuery] = React.useState("");
	const [selected, setSelected] = React.useState(1);
	// bumps on each new result set, so rows remount and stagger in
	const wave = React.useRef(0);
	const boxRef = React.useRef<TextBox>();
	const listRef = React.useRef<ScrollingFrame>();
	const contentRef = React.useRef<Frame>();
	const viewport = useViewport();
	const reduced = props.reducedMotion === true || GuiService.ReducedMotionEnabled === true;
	const [show, exiting, beginExit] = usePresence(reduced);
	const open = !exiting;
	const resultsRef = React.useRef<SearchEntry[]>([]);
	const pickRef = React.useRef<() => void>(() => {});
	const openRef = React.useRef(false);
	openRef.current = open;
	const repeatToken = React.useRef(0);
	// keyboard/pad moves scroll the pick into view; hover never does (a still pointer over a
	// scrolling list would keep re-picking rows)
	const followRef = React.useRef(true);
	const lastPointer = React.useRef<Vector2>();
	const stickDir = React.useRef(0);

	// up/down wrap at the ends, page steps stop there; held repeats tick but don't rumble
	const moveBy = (step: number, held = false) => {
		const count = resultsRef.current.size();
		if (count === 0) {
			return;
		}
		Audio.play("tick");
		followRef.current = true;
		if (!held) {
			InteractionFeedback.tick();
		}
		setSelected((current) => {
			const target = current + step;
			if (math.abs(step) === 1) {
				return target < 1 ? count : target > count ? 1 : target;
			}
			return math.clamp(target, 1, count);
		});
	};

	const onClosed = props.onClosed;
	const close = React.useCallback(() => {
		boxRef.current?.ReleaseFocus();
		if (!exiting) {
			beginExit(onClosed);
		}
	}, [exiting, beginExit, onClosed]);
	const dismiss = React.useCallback(() => {
		close();
		Audio.play("close");
	}, [close]);

	// keyboard + gamepad
	React.useEffect(() => {
		const began = UserInputService.InputBegan.Connect((input) => {
			const kind = input.UserInputType;
			const pad = kind === Enum.UserInputType.Gamepad1;
			if (kind !== Enum.UserInputType.Keyboard && !pad) {
				return;
			}
			const key = input.KeyCode;
			if (!open) {
				return;
			}
			if (key === Enum.KeyCode.Escape || key === Enum.KeyCode.ButtonB) {
				dismiss();
				return;
			}
			if (key === Enum.KeyCode.ButtonA) {
				pickRef.current();
				return;
			}
			const shift = UserInputService.IsKeyDown(Enum.KeyCode.LeftShift) || UserInputService.IsKeyDown(Enum.KeyCode.RightShift);
			let step = 0;
			if (NAV_DOWN.has(key) || (key === Enum.KeyCode.Tab && !shift)) {
				step = 1;
			} else if (NAV_UP.has(key) || (key === Enum.KeyCode.Tab && shift)) {
				step = -1;
			} else if (key === Enum.KeyCode.PageDown) {
				step = PAGE_STEP;
			} else if (key === Enum.KeyCode.PageUp) {
				step = -PAGE_STEP;
			}
			if (step === 0) {
				return;
			}
			moveBy(step);
			const token = (repeatToken.current += 1);
			task.delay(REPEAT_DELAY, () => {
				while (repeatToken.current === token && openRef.current && isHeld(key)) {
					moveBy(step, true);
					task.wait(REPEAT_EVERY);
				}
			});
		});
		const ended = UserInputService.InputEnded.Connect(() => {
			repeatToken.current += 1;
		});
		// left stick: one step per push, then repeats (a little slower) while held
		const stick = UserInputService.InputChanged.Connect((input) => {
			if (!open || input.KeyCode !== Enum.KeyCode.Thumbstick1) {
				return;
			}
			const y = input.Position.Y;
			if (stickDir.current === 0 && math.abs(y) >= STICK_ON) {
				const dir = y > 0 ? -1 : 1;
				stickDir.current = dir;
				moveBy(dir);
				const token = (repeatToken.current += 1);
				task.delay(REPEAT_DELAY, () => {
					while (repeatToken.current === token && openRef.current && stickDir.current === dir) {
						moveBy(dir, true);
						task.wait(REPEAT_EVERY * 1.6);
					}
				});
			} else if (stickDir.current !== 0 && math.abs(y) < STICK_OFF) {
				stickDir.current = 0;
				repeatToken.current += 1;
			}
		});
		return () => {
			began.Disconnect();
			ended.Disconnect();
			stick.Disconnect();
			repeatToken.current += 1;
		};
	}, [open, dismiss]);

	// while open, Quick Find holds the pad so focus behind the panel doesn't move or click;
	// the handlers above still run because UserInputService sees sunk input
	React.useEffect(() => {
		if (!open) {
			return undefined;
		}
		const before = GuiService.SelectedObject;
		GuiService.SelectedObject = undefined;
		const release = sinkPadInput("AstralForgeQuickFindPad", [
			Enum.KeyCode.Thumbstick1,
			Enum.KeyCode.DPadUp,
			Enum.KeyCode.DPadDown,
			Enum.KeyCode.DPadLeft,
			Enum.KeyCode.DPadRight,
			Enum.KeyCode.ButtonA,
			Enum.KeyCode.ButtonB,
		]);
		return () => {
			release();
			if (before !== undefined && before.Parent !== undefined && GuiService.SelectedObject === undefined) {
				GuiService.SelectedObject = before;
			}
		};
	}, [open]);

	// type straight away
	React.useEffect(() => {
		if (!open) {
			return undefined;
		}
		const job = task.defer(() => {
			const box = boxRef.current;
			if (box !== undefined && box.Parent !== undefined) {
				box.CaptureFocus();
			}
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [open]);

	const results = React.useMemo<Results>(
		() => (open ? search(props.state, query, props.chatUnread) : NO_RESULTS),
		[open, query, props.state, props.chatUnread],
	);
	const flat = results.flat;
	resultsRef.current = flat;
	const pickIndex = math.clamp(selected, 1, math.max(1, flat.size()));
	const current = flat[pickIndex - 1];

	// a new result set staggers in and the highlight follows it
	const signature = query + "#" + tostring(flat.size());
	const lastSignature = React.useRef(signature);
	if (lastSignature.current !== signature) {
		lastSignature.current = signature;
		followRef.current = true;
		wave.current += 1;
	}

	// layout: centred panel; full width with 44px rows on phones, inside the notch and home bar
	const touch = UserInputService.TouchEnabled && !UserInputService.KeyboardEnabled;
	const phone = viewport.width < 600;
	const rowH = touch || phone ? ROW_H_TOUCH : ROW_H;
	const [inset] = GuiService.GetGuiInset();
	const chrome = theme.chromeFor(viewport);
	const width = phone ? viewport.width - math.max(8, chrome.sideSafe) * 2 : math.min(640, viewport.width - 48);
	const height = phone ? viewport.height - inset.Y - 12 - math.max(12, chrome.bottomSafe) : math.min(520, viewport.height - inset.Y - 96);
	const pad = phone ? 8 : 12;
	const preview = width >= 560;
	const previewW = preview ? math.floor(width * 0.36) : 0;
	const footerH = touch ? 0 : FOOTER_H;
	const listTop = pad + SEARCH_H + 8;

	const pick = (entry: SearchEntry | undefined) => {
		if (entry === undefined) {
			return;
		}
		Model.pushRecent(entry.key);
		close();
		if (entry.kind === "Action") {
			Audio.play("confirm");
			props.dispatch(entry.run!);
			return;
		}
		if (entry.kind !== "Page" && entry.route !== undefined) {
			Model.link(entry.route, {
				query: entry.query ?? entry.title,
				category: entry.category,
			});
		}
		props.navigate(entry.route!);
	};
	pickRef.current = () => pick(resultsRef.current[pickIndex - 1]);

	const rowRefs = React.useRef<Record<number, GuiObject>>({});
	const register = React.useCallback((i: number, row: GuiObject | undefined) => {
		if (row !== undefined) {
			rowRefs.current[i] = row;
		} else {
			delete rowRefs.current[i];
		}
	}, []);

	// keep the pick in view after keyboard/pad moves (after layout)
	React.useEffect(() => {
		if (!open) {
			return undefined;
		}
		const job = task.defer(() => {
			const row = rowRefs.current[pickIndex];
			const content = contentRef.current;
			const list = listRef.current;
			if (row === undefined || content === undefined || list === undefined || !followRef.current) {
				return;
			}
			followRef.current = false;
			const top = row.AbsolutePosition.Y - content.AbsolutePosition.Y;
			const bottom = top + row.AbsoluteSize.Y;
			const view = list.AbsoluteWindowSize.Y;
			if (top - SECTION_H < list.CanvasPosition.Y) {
				list.CanvasPosition = new Vector2(0, math.max(0, top - SECTION_H));
			} else if (bottom > list.CanvasPosition.Y + view) {
				list.CanvasPosition = new Vector2(0, bottom - view);
			}
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [pickIndex, open, results, rowH]);

	// hover picks a row only when the pointer really moved onto it
	const hoverPick = (rowIndex: number) => {
		const pointer = UserInputService.GetMouseLocation();
		const last = lastPointer.current;
		lastPointer.current = pointer;
		if (last !== undefined && pointer.sub(last).Magnitude < 1) {
			return;
		}
		setSelected(rowIndex);
	};

	const list: React.Element[] = [];
	let order = 0;
	let index = 0;
	for (const [s, section] of ipairs(results.sections)) {
		order += 1;
		list.push(<SectionLabel key={`s${s}`} text={string.upper(section.title)} order={order} height={SECTION_H} zIndex={4} />);
		for (const entry of section.entries) {
			order += 1;
			index += 1;
			list.push(
				<Row
					key={`${wave.current}:${entry.key}#${s}`}
					entry={entry}
					index={index}
					order={order}
					selected={index === pickIndex}
					query={query}
					height={rowH}
					showKind={!preview}
					reduced={reduced}
					delay={index <= SurfaceMotion.staggerRows ? index * SurfaceMotion.stagger : 0}
					onPick={pick}
					onHover={hoverPick}
					register={register}
				/>,
			);
		}
	}

	const clearLabel = query !== "" ? "Clear" : touch ? "Close" : "Esc";

	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} Visible={show.map((a) => a > 0.01)} ZIndex={500}>
			{/* dim backdrop; tap outside closes */}
			<imagebutton
				Size={UDim2.fromScale(1, 1)}
				BackgroundColor3={new Color3(0, 0, 0)}
				BackgroundTransparency={show.map((a) => 1 - 0.55 * a)}
				BorderSizePixel={0}
				AutoButtonColor={false}
				Selectable={false}
				Active={open}
				ZIndex={1}
				Event={{ Activated: dismiss }}
			/>
			<frame
				key="QuickFind"
				Size={UDim2.fromOffset(width, height)}
				Position={show.map((a) =>
					phone ? new UDim2(0.5, 0, 0, inset.Y + 12 + revealOffset(a)) : new UDim2(0.5, 0, 0.5, inset.Y / 2 + revealOffset(a)),
				)}
				AnchorPoint={phone ? new Vector2(0.5, 0) : new Vector2(0.5, 0.5)}
				BackgroundTransparency={1}
				Active={true}
				ZIndex={2}
			>
				<Surface appear={show} padding={0} active={true} zIndex={2}>
					{/* search field */}
					<Surface
						tone="inset"
						padding={0}
						size={new UDim2(1, -pad * 2, 0, SEARCH_H)}
						position={UDim2.fromOffset(pad, pad)}
						accent={Palette.mango}
						zIndex={3}
					>
						<frame
							Size={UDim2.fromOffset(20, 20)}
							Position={new UDim2(0, 14, 0.5, 0)}
							AnchorPoint={new Vector2(0, 0.5)}
							BackgroundTransparency={1}
							ZIndex={4}
						>
							<Glyph box={20} kind="Search.9" color={Palette.creamSoft} accent={Palette.mango} size={20} spin={false} />
						</frame>
						<textbox
							ref={boxRef}
							Size={new UDim2(1, -(44 + 48 + 76), 1, 0)}
							Position={UDim2.fromOffset(44, 0)}
							BackgroundTransparency={1}
							Text={query}
							PlaceholderText="Search pages, settings, relics, machines…"
							PlaceholderColor3={Palette.muted}
							TextColor3={Palette.cream}
							TextSize={17}
							FontFace={Font.fromName("BuilderSans", Enum.FontWeight.Medium)}
							TextXAlignment={Enum.TextXAlignment.Left}
							TextTruncate={Enum.TextTruncate.AtEnd}
							ClearTextOnFocus={false}
							ZIndex={4}
							Change={{
								Text: (box) => {
									if (box.Text !== query) {
										if (box.IsFocused() && box.Text.size() > query.size()) {
											Audio.play("searchType");
										}
										setQuery(box.Text);
										setSelected(1);
									}
								},
							}}
							Event={{
								FocusLost: (_box, enterPressed) => {
									if (enterPressed && openRef.current) {
										pickRef.current();
									}
								},
							}}
						/>
						<SurfaceText
							text={query === "" ? "" : `${results.total} found`}
							type="hint"
							color={Palette.creamSoft}
							align={Enum.TextXAlignment.Right}
							size={UDim2.fromOffset(72, 30)}
							position={new UDim2(1, -50, 0.5, 0)}
							anchor={new Vector2(1, 0.5)}
							zIndex={4}
						/>
						{/* clear (with text) or close (empty); 44px in the 48px field */}
						<textbutton
							Size={UDim2.fromOffset(theme.TapTarget, theme.TapTarget)}
							Position={new UDim2(1, -2, 0.5, 0)}
							AnchorPoint={new Vector2(1, 0.5)}
							BackgroundColor3={theme.Palette.panelRaised}
							BackgroundTransparency={0.2}
							BorderSizePixel={0}
							AutoButtonColor={true}
							Text={clearLabel}
							TextSize={11}
							FontFace={Font.fromName("BuilderSans", Enum.FontWeight.Bold)}
							TextColor3={Palette.creamSoft}
							ZIndex={4}
							Event={{
								Activated: () => {
									if (query !== "") {
										setQuery("");
										setSelected(1);
										boxRef.current?.CaptureFocus();
									} else {
										dismiss();
									}
								},
							}}
						>
							<uicorner CornerRadius={new UDim(0, theme.Radius.md)} />
						</textbutton>
					</Surface>
					{/* results */}
					<scrollingframe
						ref={listRef}
						Size={new UDim2(1, -(pad * 2 + (preview ? previewW + 8 : 0)), 1, -(listTop + footerH + 6))}
						Position={UDim2.fromOffset(pad, listTop)}
						BackgroundTransparency={1}
						BorderSizePixel={0}
						CanvasSize={new UDim2()}
						AutomaticCanvasSize={Enum.AutomaticSize.Y}
						ScrollBarThickness={3}
						ScrollBarImageColor3={Palette.muted}
						ScrollingDirection={Enum.ScrollingDirection.Y}
						ZIndex={3}
					>
						<frame
							ref={contentRef}
							Size={new UDim2(1, -4, 0, 0)}
							AutomaticSize={Enum.AutomaticSize.Y}
							BackgroundTransparency={1}
							ZIndex={3}
						>
							<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, SurfaceMetrics.rowGap)} />
							{list}
							{open && flat.size() === 0 && (
								<frame key="empty" Size={new UDim2(1, 0, 0, 150)} BackgroundTransparency={1} LayoutOrder={1} ZIndex={4}>
									<IconTile size={44} accent={Palette.muted} position={new UDim2(0.5, 0, 0, 16)} anchor={new Vector2(0.5, 0)} zIndex={4}>
										<Glyph box={22} kind="Search.9" color={Palette.muted} accent={Palette.muted} size={22} spin={false} />
									</IconTile>
									<SurfaceText
										text={`Nothing matches "${query}"`}
										type="title"
										align={Enum.TextXAlignment.Center}
										size={new UDim2(1, -32, 0, 22)}
										position={UDim2.fromOffset(16, 70)}
										zIndex={4}
									/>
									<SurfaceText
										// kept as two literals (a single long string tripped a compiler bug)
										text={
											'Search works on page names, settings, relics, machines and research. Try "music", "vault" or a relic' + "'s name."
										}
										type="body"
										color={Palette.muted}
										wrap={true}
										fit={true}
										align={Enum.TextXAlignment.Center}
										size={new UDim2(1, -32, 0, 40)}
										position={UDim2.fromOffset(16, 96)}
										zIndex={4}
									/>
								</frame>
							)}
						</frame>
					</scrollingframe>
					{preview && (
						<Surface
							tone="inset"
							size={new UDim2(0, previewW, 1, -(listTop + footerH + 10))}
							position={new UDim2(1, -(previewW + pad), 0, listTop)}
							clips={true}
							zIndex={3}
						>
							{current !== undefined && <Preview key={current.key} entry={current} touch={touch} reduced={reduced} />}
						</Surface>
					)}
					{footerH > 0 && (
						<frame Size={new UDim2(1, 0, 0, footerH)} Position={new UDim2(0, 0, 1, -footerH)} BackgroundTransparency={1} ZIndex={3}>
							<frame
								Size={new UDim2(1, 0, 0, 1)}
								BackgroundColor3={theme.Palette.lineSoft}
								BackgroundTransparency={0.5}
								BorderSizePixel={0}
								ZIndex={3}
							/>
							<frame Size={new UDim2(1, -pad * 2 - 4, 1, 0)} Position={UDim2.fromOffset(pad + 2, 0)} BackgroundTransparency={1} ZIndex={3}>
								<uilistlayout
									FillDirection={Enum.FillDirection.Horizontal}
									VerticalAlignment={Enum.VerticalAlignment.Center}
									Padding={new UDim(0, 18)}
									SortOrder={Enum.SortOrder.LayoutOrder}
								/>
								<KeyHint keys="↑ ↓ Tab" label="Move" order={1} zIndex={4} />
								<KeyHint keys="Enter" label="Open" order={2} zIndex={4} />
								<KeyHint keys="Esc" label="Close" order={3} zIndex={4} />
								{!phone && <KeyHint keys="Ctrl+K" label="From anywhere" order={4} zIndex={4} />}
							</frame>
						</frame>
					)}
				</Surface>
			</frame>
		</frame>
	);
}

// Owns the open requests (top bar, overview, Ctrl/Cmd+K) and mounts a fresh panel per open.
function QuickFindComponent(props: QuickFindComponentProps) {
	const [session, setSession] = React.useState<number>();
	const sessionRef = React.useRef<number>();
	sessionRef.current = session;
	const enabled = props.enabled !== false;
	React.useEffect(() => {
		const request = () => {
			if (enabled && sessionRef.current === undefined) {
				const id = os.clock();
				sessionRef.current = id;
				setSession(id);
				Audio.play("open");
			}
		};
		openers.push(request);
		// "/" belongs to Roblox chat, so only Ctrl/Cmd+K opens it from the keyboard
		const keys = UserInputService.InputBegan.Connect((input) => {
			if (input.KeyCode !== Enum.KeyCode.K || UserInputService.GetFocusedTextBox() !== undefined) {
				return;
			}
			const ctrl =
				UserInputService.IsKeyDown(Enum.KeyCode.LeftControl) ||
				UserInputService.IsKeyDown(Enum.KeyCode.RightControl) ||
				UserInputService.IsKeyDown(Enum.KeyCode.LeftMeta) ||
				UserInputService.IsKeyDown(Enum.KeyCode.RightMeta);
			if (ctrl) {
				request();
			}
		});
		return () => {
			keys.Disconnect();
			const at = openers.indexOf(request);
			if (at !== -1) {
				openers.remove(at);
			}
		};
	}, [enabled]);
	React.useEffect(() => {
		if (!enabled) {
			setSession(undefined);
		}
	}, [enabled]);
	const onClosed = React.useCallback(() => setSession(undefined), []);
	if (session === undefined || !enabled) {
		return undefined;
	}
	return <QuickFindPanel key={`qf${session}`} {...props} onClosed={onClosed} />;
}

const QuickFind = {
	open(): void {
		for (const fn of table.clone(openers)) {
			fn();
		}
	},
	QuickFind: QuickFindComponent,
};

export = QuickFind;

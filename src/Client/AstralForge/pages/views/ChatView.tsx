// The Chat page: a status header, channel tabs, whisper peers, the message log (virtualised, sticks to
// the bottom unless you scroll up to read), autocomplete chips and the composer. The chat hook in
// ClientRuntime/chat.ts owns the channels and sending; this page only shows and edits.
import React from "@rbxts/react";
import ChatRules = require("../../../../Shared/AstralForge/Shared/ChatRules");
import { ChatApi, ChatRecord } from "../../ClientRuntime/chat";
import * as ChatText from "../../CoreKit/chatText";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { frameStroke } from "../../CoreKit/profileFrame";
import { chromeFor, darken, Layout, lighten, Palette } from "../../CoreKit/theme";
import { Icon, PlayerMark } from "../../ArtKit/Icon";
import { useAntilag } from "../../MotionKit/antilag";
import { useFlipperSpring, usePulse, useStagger, useViewport } from "../../MotionKit/motion";
import { AnimatedTitle, titleFxAccent } from "../../ReactHosts/AnimatedTitle";
import { Badge, Button, SearchField, SegmentedTabs, segmentedHeight, Text } from "../../UiCore/ui";
import { Component, loadAudio, loadPageScaffold, luauKit, luauModule, named } from "../luauDeps";

const UserInputService = game.GetService("UserInputService");
const Audio = loadAudio();
const PageScaffold = loadPageScaffold();
const FlatList = luauKit<{ FlatList: Component }>("LayoutKit", "virtualizedList").FlatList;
const ElementFx = luauModule<{ ElementFx: Component }>("ElementFx").ElementFx;

const ARTIFACT_CHIP_W = 124;
const ROW_HEIGHT = 98;
const CARD_H = 90;
const SYSTEM_CARD_H = 66;
const STATUS_HEIGHT = 64;
const BANNER_HEIGHT = 52;
const INPUT_HEIGHT = 60;
const SIDE_INSET = 12;
const STATUS_RESERVE = 128;
// message rows: the name/title column starts at x=66 and stops before the 62px channel badge (at -72)
// with a 6px gap; the header's STATUS_RESERVE used to be subtracted here too, leaving ~0px on phones
const MESSAGE_RIGHT = 66 + 78;
const NEAR_BOTTOM = 96;
// room for "/w name " in front of a full message
const DRAFT_LIMIT = ChatRules.MAX_INPUT + 40;
const TAB_ROW_H = 44;
const PEER_ROW_H = 40;
const SUGGEST_ROW_H = 40;
const TAB_DEFS = [
	{ id: "all", label: "All" },
	{ id: "global", label: "Global" },
	{ id: "server", label: "Server" },
	{ id: "crew", label: "Crew" },
	{ id: "friends", label: "Friends" },
	{ id: "whispers", label: "Whispers" },
];
const MOBILE_PLACEHOLDER: Record<string, string | undefined> = {
	global: "Message global…  (/help)",
	server: "Message server…  (/help)",
	crew: "Message crew…  (/help)",
	friends: "Message friends…  (/help)",
	whispers: "Private message…  (/help)",
};
const EMPTY_TAB_TEXT: Record<string, string | undefined> = {
	whispers: "No whispers yet. Type /w name message to start one.",
	friends: "Nothing from friends in this server yet.",
	crew: "Crew chat is private to your crew. Start one on the Crew page.",
	global: "Global chat is quiet. Say hello to every server.",
};
const CHANNEL_BADGE: Record<string, string | undefined> = { global: "GLOBAL", crew: "CREW", whisper: "WHISPER", friends: "FRIEND" };
const TAG_COLORS = [Palette.cyan, Palette.mint, Palette.violet, Palette.mango, Palette.pink, Palette.blue];

const EMPTY_CHAT: ChatApi = {
	messages: [],
	unread: 0,
	unreadByTab: {},
	connected: false,
	tab: "all",
	setTab: () => {},
	peer: undefined,
	setPeer: () => {},
	whispers: [],
	muted: {},
	setMute: () => {},
	openWhisper: () => {},
	send: (_text, done) => {
		done?.(false, "Chat is still connecting.");
	},
	clear: () => {},
	suggest: () => [],
	placeholder: "Say something... (/help)",
	focusRequest: 0,
	requestFocus: () => {},
	showGlobal: true,
	textScale: 1.075,
};

const blank = (text: string) => text.gsub("%s", "")[0] === "";

/** A finite author id, or 0. */
function authorOf(userId: unknown): number {
	const id = tonumber(userId) ?? 0;
	return id !== id || math.abs(id) === math.huge ? 0 : id;
}

function userColor(userId: unknown): Color3 {
	return TAG_COLORS[math.floor(math.abs(authorOf(userId))) % TAG_COLORS.size()];
}

function channelBadge(message: ChatRecord): string {
	if (message.localPlayer) return "YOU";
	return CHANNEL_BADGE[message.channel] ?? `WORLD ${message.world}`;
}

interface Chip {
	key: string;
	element: React.Element;
}

// one-row chip strip (whisper peers, autocomplete). Chat keeps no raw scrollers, so it clips:
// callers pass chips most-relevant first and the tail is what gets cut on narrow screens.
function chipRail(chips: Chip[], zIndex?: number) {
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={true} ZIndex={zIndex}>
			<uilistlayout
				key="layout"
				FillDirection={Enum.FillDirection.Horizontal}
				Padding={new UDim(0, 6)}
				SortOrder={Enum.SortOrder.LayoutOrder}
				VerticalAlignment={Enum.VerticalAlignment.Center}
			/>
			{chips.map((chip, i) => (
				<frame key={chip.key} LayoutOrder={i + 1} Size={new UDim2(0, 0, 1, -4)} AutomaticSize={Enum.AutomaticSize.X} BackgroundTransparency={1}>
					{chip.element}
				</frame>
			))}
		</frame>
	);
}

/** 0 -> 1 the frame after a new message mounts; already-seen messages start at 1. */
function useMessageEntrance(animate: boolean, reducedMotion?: boolean): React.Binding<number> {
	const shouldAnimate = React.useRef(animate && !reducedMotion);
	const [live, setLive] = React.useState(!shouldAnimate.current);
	React.useEffect(() => {
		if (!shouldAnimate.current) {
			setLive(true);
			return undefined;
		}
		setLive(false);
		let alive = true;
		const job = task.defer(() => {
			if (alive) setLive(true);
		});
		return () => {
			alive = false;
			pcall(task.cancel, job);
		};
	}, []);
	return useFlipperSpring(live ? 1 : 0, reducedMotion, 780, 38);
}

interface RowProps {
	message: ChatRecord;
	reducedMotion?: boolean;
	bodySize: number;
	animate: boolean;
	rowHeight: number;
	onWhisper?: (userId: number) => void;
}

function MessageRow({ message, reducedMotion, bodySize, animate, rowHeight, onWhisper }: RowProps) {
	const enter = useMessageEntrance(animate, reducedMotion);
	const system = message.system === true;
	const accent = system ? Palette.mango : (message.profileAccent ?? userColor(message.userId));
	// the sender's chosen profile frame on their mark ring (default frame: unchanged 1px ring)
	const markRing = frameStroke(system ? undefined : message.profileFrame, accent);
	const pulse = usePulse(!system, 2.4 + math.abs(authorOf(message.userId) % 5) * 0.14);
	const fade = enter.map((amount) => 1 - amount);
	const scale = <uiscale Scale={enter.map((amount) => 0.97 + amount * 0.03)} />;

	if (system) {
		const cardY = math.floor((rowHeight - SYSTEM_CARD_H) / 2);
		return (
			<frame Size={new UDim2(1, 0, 0, rowHeight)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={true}>
				<frame
					Size={new UDim2(1, -4, 0, SYSTEM_CARD_H)}
					Position={enter.map((amount) => UDim2.fromOffset(math.round((1 - amount) * 14), cardY + math.round((1 - amount) * 8)))}
					BackgroundColor3={Palette.panelRaised}
					BackgroundTransparency={fade.map((amount) => 0.08 + amount * 0.92)}
					BorderSizePixel={0}
					ClipsDescendants={true}
				>
					{scale}
					<uicorner CornerRadius={new UDim(0, 12)} />
					<uistroke Color={accent} Thickness={1} Transparency={fade.map((amount) => 0.42 + amount * 0.58)} />
					<frame Size={new UDim2(0, 3, 1, -12)} Position={UDim2.fromOffset(0, 6)} BackgroundColor3={accent} BackgroundTransparency={fade} BorderSizePixel={0}>
						<uicorner CornerRadius={new UDim(0, 2)} />
					</frame>
					<frame
						Size={UDim2.fromOffset(38, 38)}
						Position={UDim2.fromOffset(14, 14)}
						BackgroundColor3={darken(accent, 0.62)}
						BackgroundTransparency={fade}
						BorderSizePixel={0}
						ClipsDescendants={true}
					>
						<uicorner CornerRadius={new UDim(0, 10)} />
						<Icon kind="Chat.2" color={Palette.ink} accent={accent} size={22} position={UDim2.fromOffset(8, 8)} />
					</frame>
					<Text
						value="Game message"
						size={12}
						color={accent}
						weight={Enum.FontWeight.Bold}
						fit={false}
						position={UDim2.fromOffset(64, 12)}
						sizeConstraint={new UDim2(1, -78, 0, 16)}
						transparency={fade}
					/>
					<Text
						value={message.text}
						size={bodySize}
						color={Palette.cream}
						weight={Enum.FontWeight.Medium}
						wrap={true}
						position={UDim2.fromOffset(64, 32)}
						sizeConstraint={new UDim2(1, -78, 0, 28)}
						transparency={fade}
					/>
				</frame>
			</frame>
		);
	}

	const cardH = math.max(CARD_H, rowHeight - 8);
	const mention = message.mention === true;
	const titled = message.titleName !== undefined;
	const artifactColor = message.artifactColor ?? accent;
	const chipRoom = message.artifactName !== undefined ? ARTIFACT_CHIP_W + 6 : 0;
	return (
		<frame Size={new UDim2(1, 0, 0, rowHeight)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={true}>
			<frame
				Size={new UDim2(1, -4, 0, cardH)}
				Position={enter.map((amount) => UDim2.fromOffset(math.round((1 - amount) * 14), 4 + math.round((1 - amount) * 10)))}
				BackgroundColor3={mention ? darken(Palette.mango, 0.8) : message.localPlayer ? darken(accent, 0.88) : Palette.panel}
				BackgroundTransparency={fade.map((amount) => 0.04 + amount * 0.96)}
				BorderSizePixel={0}
				ClipsDescendants={true}
			>
				{scale}
				<uicorner CornerRadius={new UDim(0, 12)} />
				<uistroke
					Color={mention ? Palette.mango : accent}
					Thickness={mention ? 2 : 1}
					Transparency={fade.map((amount) => (mention ? 0.1 : message.localPlayer ? 0.32 : 0.58) + amount * 0.42)}
				/>
				{message.artifactElement !== undefined && (
					<ElementFx element={message.artifactElement} size={UDim2.fromOffset(64, 64)} position={UDim2.fromOffset(33, 38)} transparency={0.25} reducedMotion={reducedMotion} />
				)}
				<frame
					Size={UDim2.fromOffset(42, 42)}
					Position={UDim2.fromOffset(12, 17)}
					BackgroundColor3={darken(accent, 0.5)}
					BackgroundTransparency={fade}
					BorderSizePixel={0}
					ClipsDescendants={true}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
					<uistroke Color={markRing.color} Thickness={markRing.thickness} Transparency={pulse.map((amount) => 0.2 + amount * 0.4)}>
						{markRing.gradient !== undefined && <uigradient Color={markRing.gradient} Rotation={35} />}
					</uistroke>
					<PlayerMark userId={message.userId} color={Palette.ink} accent={accent} size={26} position={UDim2.fromOffset(8, 8)} />
					<frame Size={UDim2.fromOffset(10, 10)} Position={UDim2.fromOffset(30, 30)} BackgroundColor3={Palette.green} BorderSizePixel={0}>
						<uicorner CornerRadius={new UDim(1, 0)} />
						<uistroke Color={Palette.ink} Thickness={1} />
					</frame>
				</frame>
				<Text
					value={message.displayName}
					size={15}
					color={accent}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					minSize={10}
					position={UDim2.fromOffset(66, 8)}
					sizeConstraint={new UDim2(1, -(MESSAGE_RIGHT + chipRoom), 0, 18)}
					transparency={fade}
				/>
				{message.artifactName !== undefined && (
					<frame
						Size={UDim2.fromOffset(ARTIFACT_CHIP_W, 20)}
						Position={new UDim2(1, -(78 + ARTIFACT_CHIP_W), 0, 9)}
						BackgroundColor3={darken(artifactColor, 0.72)}
						BackgroundTransparency={fade.map((amount) => 0.1 + amount * 0.9)}
						BorderSizePixel={0}
						ClipsDescendants={true}
					>
						<uicorner CornerRadius={new UDim(1, 0)} />
						<uistroke Color={artifactColor} Thickness={1} Transparency={pulse.map((amount) => 0.25 + amount * 0.35)} />
						{message.artifactElement !== undefined && (
							<ElementFx element={message.artifactElement} size={UDim2.fromOffset(22, 22)} position={UDim2.fromOffset(12, 10)} reducedMotion={reducedMotion} />
						)}
						<Text
							value={string.upper(message.artifactName)}
							size={10}
							color={lighten(artifactColor, 0.2)}
							weight={Enum.FontWeight.Heavy}
							fit={true}
							minSize={8}
							position={UDim2.fromOffset(24, 3)}
							sizeConstraint={new UDim2(1, -30, 0, 14)}
							transparency={fade}
						/>
					</frame>
				)}
				{titled ? (
					<AnimatedTitle
						text={message.titleName}
						fx={message.titleFx}
						size={12}
						reducedMotion={reducedMotion}
						position={UDim2.fromOffset(66, 28)}
						sizeConstraint={new UDim2(1, -MESSAGE_RIGHT, 0, 18)}
						transparency={fade}
					/>
				) : (
					<Text
						value={`@${message.username}`}
						size={12}
						color={Palette.muted}
						weight={Enum.FontWeight.Bold}
						fit={false}
						position={UDim2.fromOffset(66, 28)}
						sizeConstraint={new UDim2(1, -80, 0, 16)}
						transparency={fade}
					/>
				)}
				<Badge
					value={channelBadge(message)}
					accent={message.titleFx !== undefined ? titleFxAccent(message.titleFx) : accent}
					filled={true}
					position={new UDim2(1, -72, 0, 10)}
					size={UDim2.fromOffset(62, 26)}
				/>
				<Text
					value={ChatRules.clock(message.at)}
					size={11}
					color={Palette.muted}
					align={Enum.TextXAlignment.Center}
					position={new UDim2(1, -72, 0, 38)}
					sizeConstraint={UDim2.fromOffset(62, 16)}
					transparency={fade}
				/>
				{onWhisper !== undefined && !message.localPlayer && (
					<textbutton
						{...named("WhisperAuthor")}
						Size={new UDim2(1, -MESSAGE_RIGHT, 0, 24)}
						Position={UDim2.fromOffset(66, 6)}
						BackgroundTransparency={1}
						Text=""
						AutoButtonColor={false}
						ZIndex={5}
						Event={{ Activated: () => onWhisper(message.userId) }}
					/>
				)}
				{titled && (
					<Text
						value={`@${message.username}`}
						size={11}
						color={Palette.muted}
						weight={Enum.FontWeight.Bold}
						fit={false}
						position={UDim2.fromOffset(66, 46)}
						sizeConstraint={new UDim2(1, -80, 0, 14)}
						transparency={fade}
					/>
				)}
				<Text
					value={message.text}
					size={bodySize + 1}
					color={Palette.cream}
					weight={Enum.FontWeight.Medium}
					wrap={true}
					position={UDim2.fromOffset(66, titled ? 62 : 48)}
					sizeConstraint={new UDim2(1, -78, 0, math.max(titled ? 26 : 34, cardH - (titled ? 70 : 56)))}
					transparency={fade}
				/>
			</frame>
		</frame>
	);
}

/** How far a scroller is from its bottom edge, in pixels. */
function maxScroll(frame: ScrollingFrame): number {
	return math.max(0, frame.CanvasSize.Y.Offset - frame.AbsoluteWindowSize.Y);
}

function ChatView(props: { chat?: ChatApi; reducedMotion?: boolean }) {
	const chat = props.chat ?? EMPTY_CHAT;
	const softMotion = props.reducedMotion;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const antilag = useAntilag();
	const textScale = chat.textScale ?? 1.075;
	const bodySize = math.floor((chrome.mobile ? 15 : 14) * textScale + 0.5);
	const rowHeight = math.floor((chrome.mobile ? 144 : ROW_HEIGHT) * math.max(1, textScale * 0.95) + 0.5);
	const condensed = chrome.landscape || viewport.keyboardOpen || viewport.height < 700;
	const showStatus = !condensed;
	const showBanner = !condensed && viewport.height >= 760;
	const chromeGap = condensed ? 8 : Layout.stackGap;
	const inputHeight = condensed ? 62 : INPUT_HEIGHT;
	const [draft, setDraft] = React.useState("");
	const [failure, setFailure] = React.useState("");
	const [viewHeight, setViewHeight] = React.useState(0);
	const [searchOpen, setSearchOpen] = React.useState(false);
	const [logQuery, setLogQuery] = React.useState("");
	const input = React.useRef<TextBox>();
	const stickBottom = React.useRef(true);
	const lastMessageId = React.useRef<string>();
	// bumped on every send and on unmount, so a late reply from an old send is ignored
	const sendAttempt = React.useRef(0);
	const sentHistory = React.useRef<string[]>([]);
	const recallIndex = React.useRef(0);
	const recallDraft = React.useRef("");
	const chatClaimHostRef = React.useRef<Frame>();
	const headerReveal = useStagger(0, softMotion);
	const bannerReveal = useStagger(1, softMotion);
	const statusReveal = useStagger(3, softMotion);
	React.useEffect(
		() => () => {
			sendAttempt.current += 1;
		},
		[],
	);
	// ids already shown once: only messages new since then slide in
	const enteredIds = React.useRef<Record<string, true | undefined>>({});
	const listFrame = React.useRef<ScrollingFrame>();
	const count = chat.messages.size();
	const latestMessageId = count > 0 ? chat.messages[count - 1].id : undefined;
	const tab = chat.tab ?? "all";
	const peer = tab === "whispers" ? chat.peer : undefined;
	// searching the log shows only matching lines; the live log keeps scrolling underneath
	const filteringLog = searchOpen && logQuery.match("^%s*$")[0] === undefined;
	let shownMessages = chat.messages;
	if (filteringLog || tab !== "all" || chat.showGlobal === false) {
		shownMessages = chat.messages.filter((message) => {
			const channel = message.channel ?? "server";
			let keep =
				ChatRules.inTab(channel, tab) &&
				!(tab === "all" && channel === "global" && chat.showGlobal === false) &&
				(peer === undefined || channel === "system" || message.peerId === peer);
			if (keep && filteringLog) {
				keep = ChatRules.matches(
					{ text: message.text ?? "", username: message.username ?? "", displayName: message.displayName ?? "", channel },
					logQuery,
				);
			}
			return keep;
		});
	}
	const suggestions = draft.match("^%s*$")[0] !== undefined ? [] : chat.suggest(draft);
	const stackH = shownMessages.size() * rowHeight;
	const topPad = viewHeight > 0 ? math.max(0, viewHeight - stackH) : 0;
	const renderedIds = new Map<string, boolean>();
	for (const message of chat.messages) {
		const animate = enteredIds.current[message.id] === undefined;
		if (animate) enteredIds.current[message.id] = true;
		renderedIds.set(message.id, animate);
	}
	// forget ids that scrolled out of the log
	let remembered = 0;
	for (const [_] of pairs(enteredIds.current)) remembered += 1;
	if (remembered > count + 8) {
		const live: Record<string, true | undefined> = {};
		for (const message of chat.messages) live[message.id] = true;
		enteredIds.current = live;
	}

	const scrollToBottom = React.useCallback(
		(force?: boolean) => {
			task.defer(() => {
				const frame = listFrame.current;
				if (frame === undefined || (force !== true && !stickBottom.current)) return;
				frame.CanvasPosition = new Vector2(0, maxScroll(frame));
				stickBottom.current = true;
			});
		},
		[listFrame],
	);
	// reading history: new messages are counted instead of yanking the list, and a button jumps back
	const [unseen, setUnseen] = React.useState(0);
	React.useEffect(() => {
		const frame = listFrame.current;
		if (frame === undefined) return undefined;
		const syncSize = () => setViewHeight(math.max(0, frame.AbsoluteWindowSize.Y));
		syncSize();
		const sizeConn = frame.GetPropertyChangedSignal("AbsoluteWindowSize").Connect(syncSize);
		const scrollConn = frame.GetPropertyChangedSignal("CanvasPosition").Connect(() => {
			const near = frame.CanvasPosition.Y >= maxScroll(frame) - NEAR_BOTTOM;
			stickBottom.current = near;
			if (near) setUnseen(0);
		});
		return () => {
			sizeConn.Disconnect();
			scrollConn.Disconnect();
		};
	}, [listFrame, count, topPad]);
	React.useEffect(() => {
		if (latestMessageId !== lastMessageId.current) {
			if (lastMessageId.current !== undefined && !stickBottom.current) setUnseen((n) => math.min(99, n + 1));
			scrollToBottom();
		}
		lastMessageId.current = latestMessageId;
	}, [latestMessageId, scrollToBottom]);
	React.useEffect(() => scrollToBottom(true), [scrollToBottom]);

	/** Put text in the composer (state and the live TextBox) and park the cursor at its end. */
	const fillComposer = (fill: string, focus: boolean) => {
		setDraft(fill);
		const box = input.current;
		if (box === undefined) return;
		box.Text = fill;
		task.defer(() => {
			if (input.current !== box) return;
			if (focus) box.CaptureFocus();
			box.CursorPosition = fill.size() + 1;
		});
	};
	const submit = () => {
		const box = input.current;
		const outgoing = box !== undefined ? box.Text : draft;
		if (blank(outgoing)) return;
		sendAttempt.current += 1;
		const attempt = sendAttempt.current;
		ChatRules.remember(sentHistory.current, outgoing);
		recallIndex.current = 0;
		setFailure("");
		setDraft("");
		if (box !== undefined) {
			box.Text = "";
			task.defer(() => {
				if (input.current === box) box.CaptureFocus();
			});
		}
		stickBottom.current = true;
		chat.send(outgoing, (ok, reason) => {
			if (attempt !== sendAttempt.current) return;
			if (ok) {
				setFailure("");
				scrollToBottom(true);
				return;
			}
			// give the unsent text back, unless something new was typed meanwhile
			const restore = input.current;
			if (restore !== undefined) {
				if (blank(restore.Text)) {
					restore.Text = outgoing;
					setDraft(outgoing);
				}
			} else {
				setDraft((current) => (blank(current) ? outgoing : current));
			}
			setFailure(reason ?? "Message not sent.");
		});
	};
	// global and slash commands go through the server, so they don't wait on the TextChannel
	const canSend = !blank(draft) && (chat.connected || tab === "global" || draft.match("^%s*/")[0] !== undefined);

	// The "/" key asks for the box; wait a frame so the slash itself isn't typed into it.
	React.useEffect(() => {
		const requested = chat.focusRequest ?? 0;
		if (requested <= 0 || os.clock() - requested > 1) return undefined;
		const thread = task.delay(0.05, () => {
			const box = input.current;
			if (box === undefined || !box.IsDescendantOf(game)) return;
			box.CaptureFocus();
			if (box.Text === "/") {
				box.Text = "";
				setDraft("");
			}
		});
		return () => task.cancel(thread);
	}, [chat.focusRequest]);
	// Up / Down in the focused chat box walks back through what you sent; coming back down past
	// the newest message restores whatever you had been typing.
	React.useEffect(() => {
		const connection = UserInputService.InputBegan.Connect((inputObject) => {
			const box = input.current;
			if (box === undefined || !box.IsFocused()) return;
			const direction = inputObject.KeyCode === Enum.KeyCode.Up ? 1 : inputObject.KeyCode === Enum.KeyCode.Down ? -1 : 0;
			if (direction === 0) return;
			if (recallIndex.current === 0) recallDraft.current = box.Text;
			const [index, text] = ChatRules.recall(sentHistory.current, recallIndex.current, direction);
			if (index === recallIndex.current) return;
			recallIndex.current = index;
			fillComposer(index === 0 ? recallDraft.current : text, false);
		});
		return () => connection.Disconnect();
	}, []);
	React.useEffect(() => {
		const host = chatClaimHostRef.current;
		if (!UserInputService.GamepadEnabled || host === undefined) return undefined;
		const selectJob = task.defer(() => {
			if (host.Parent !== undefined) GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, selectJob);
		};
	}, [condensed, canSend]);

	const placeholder =
		failure !== "" ? failure : chrome.mobile ? (MOBILE_PLACEHOLDER[tab] ?? "Message…  (/help)") : (chat.placeholder ?? "Say something... (/help)");
	const statusElement = (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.panelRaised} BorderSizePixel={0} ClipsDescendants={true} ZIndex={20}>
			<uicorner CornerRadius={new UDim(0, 12)} />
			<uistroke Color={Palette.lineSoft} Thickness={1} Transparency={0.5} />
			<frame Size={new UDim2(0, 3, 1, -16)} Position={UDim2.fromOffset(0, 8)} BackgroundColor3={Palette.cyan} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(0, 2)} />
			</frame>
			<frame Size={UDim2.fromOffset(42, 42)} Position={UDim2.fromOffset(14, 11)} BackgroundColor3={darken(Palette.cyan, 0.72)} BorderSizePixel={0} ClipsDescendants={true}>
				<uicorner CornerRadius={new UDim(0, 11)} />
				<uigradient Color={new ColorSequence(lighten(Palette.cyan, 0.15), darken(Palette.cyan, 0.45))} Rotation={120} />
				<Icon kind="Chat.3" color={Palette.ink} accent={Palette.cyan} size={26} position={UDim2.fromOffset(8, 8)} />
			</frame>
			<frame Size={new UDim2(1, -(STATUS_RESERVE + 68 + 52), 0, 48)} Position={UDim2.fromOffset(68, 8)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
				<Text
					value="Chat"
					size={18}
					color={Palette.cream}
					weight={Enum.FontWeight.Heavy}
					fit={false}
					sizeConstraint={new UDim2(1, 0, 0, 24)}
					transparency={headerReveal.map((amount) => 1 - amount)}
				/>
				<Text
					value={filteringLog ? `${shownMessages.size()} of ${count} match` : `${count} log${count === 1 ? "" : "s"}  ·  Roblox-filtered`}
					size={13}
					color={Palette.muted}
					weight={Enum.FontWeight.Bold}
					fit={false}
					position={UDim2.fromOffset(0, 28)}
					sizeConstraint={new UDim2(1, 0, 0, 18)}
					transparency={(showBanner ? bannerReveal : statusReveal).map((amount) => 1 - amount)}
				/>
			</frame>
			<Button
				text=""
				icon={searchOpen ? "Close.5" : "Search.7"}
				onClick={() => {
					if (searchOpen) setLogQuery("");
					setSearchOpen(!searchOpen);
				}}
				color={searchOpen ? Palette.cyan : Palette.panelSoft}
				textColor={searchOpen ? Palette.ink : Palette.cream}
				size={UDim2.fromOffset(44, 44)}
				position={new UDim2(1, -(STATUS_RESERVE + 48), 0.5, -22)}
				reducedMotion={softMotion}
			/>
			<Badge
				value={chat.connected ? "ONLINE" : "CONNECTING"}
				accent={chat.connected ? Palette.green : Palette.mango}
				filled={true}
				position={new UDim2(1, -(STATUS_RESERVE - 4), 0.5, -13)}
				size={UDim2.fromOffset(STATUS_RESERVE - 16, 26)}
			/>
		</frame>
	);

	let messagesElement = (
		<FlatList
			data={shownMessages}
			itemHeight={rowHeight}
			headerHeight={topPad}
			overscan={softMotion ? 0 : antilag.constrained ? 1 : 2}
			canvasTail={0}
			Size={UDim2.fromScale(1, 1)}
			scrollBarColor={Palette.cyan}
			scrollBarThickness={4}
			scrollBarTransparency={0.12}
			ZIndex={10}
			frameRef={listFrame}
			keyExtractor={(message: ChatRecord) => message.id}
			renderItem={({ item: message }: { item: ChatRecord }) => (
				<MessageRow
					message={message}
					reducedMotion={softMotion}
					bodySize={bodySize}
					animate={renderedIds.get(message.id) === true}
					rowHeight={rowHeight}
					onWhisper={!message.system && !message.remote ? (userId) => chat.openWhisper(userId) : undefined}
				/>
			)}
		/>
	);
	if (unseen > 0) {
		messagesElement = (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
				{messagesElement}
				<Button
					text={`${unseen} new message${unseen === 1 ? "" : "s"}`}
					icon="Chat.4"
					color={Palette.cyan}
					textColor={Palette.ink}
					hug={true}
					reducedMotion={softMotion}
					size={UDim2.fromOffset(0, 40)}
					position={new UDim2(0.5, -90, 1, -52)}
					zIndex={30}
					onClick={() => {
						setUnseen(0);
						scrollToBottom(true);
					}}
				/>
			</frame>
		);
	}
	const emptyLine = (text: string) => (
		<Text value={text} size={14} color={Palette.muted} align={Enum.TextXAlignment.Center} sizeConstraint={new UDim2(1, 0, 0, 40)} position={UDim2.fromOffset(0, 20)} />
	);
	const bannerElement = (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.panel} BorderSizePixel={0} ClipsDescendants={true} ZIndex={20}>
			<uicorner CornerRadius={new UDim(0, Layout.cardRadius)} />
			<uistroke Color={Palette.mango} Thickness={1} Transparency={0.32} />
			<frame Size={new UDim2(0, 3, 1, -12)} Position={UDim2.fromOffset(0, 6)} BackgroundColor3={Palette.mango} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(0, 2)} />
			</frame>
			<Icon kind="Forge.18" color={Palette.ink} accent={Palette.mango} size={24} position={UDim2.fromOffset(14, 14)} />
			<Text value="Keep it clean" size={12} color={Palette.mango} weight={Enum.FontWeight.Heavy} fit={false} position={UDim2.fromOffset(48, 8)} sizeConstraint={new UDim2(1, -60, 0, 16)} />
			<Text
				value="Roblox filters messages. /help for shortcuts."
				size={13}
				minSize={10}
				color={Palette.creamSoft}
				weight={Enum.FontWeight.Bold}
				fit={true}
				position={UDim2.fromOffset(48, 28)}
				sizeConstraint={new UDim2(1, -60, 0, 16)}
			/>
		</frame>
	);
	const inputElement = (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.panelRaised} BorderSizePixel={0} ClipsDescendants={false} ZIndex={20}>
			<uicorner CornerRadius={new UDim(0, 12)} />
			<uistroke Color={failure !== "" ? Palette.coral : Palette.lineSoft} Thickness={1} Transparency={0.45} />
			<textbox
				ref={input}
				Size={new UDim2(1, -148, 1, -14)}
				Position={UDim2.fromOffset(14, 7)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClearTextOnFocus={false}
				Text={draft}
				PlaceholderText={placeholder}
				PlaceholderColor3={failure !== "" ? Palette.coral : Palette.muted}
				TextColor3={Palette.cream}
				TextSize={16}
				FontFace={Font.fromEnum(Enum.Font.BuilderSansMedium)}
				TextXAlignment={Enum.TextXAlignment.Left}
				TextYAlignment={Enum.TextYAlignment.Center}
				TextTruncate={Enum.TextTruncate.None}
				TextScaled={false}
				MultiLine={false}
				TextEditable={true}
				MaxVisibleGraphemes={DRAFT_LIMIT}
				Change={{ Text: (box) => setDraft(ChatText.limit(box.Text, DRAFT_LIMIT)) }}
				Event={{
					Focused: () => Audio.play("inputFocus"),
					FocusLost: (_box, enterPressed) => {
						if (enterPressed) submit();
					},
				}}
			/>
			<frame
				{...named("ChatClaimActions")}
				ref={chatClaimHostRef}
				Size={UDim2.fromOffset(0, 48)}
				AutomaticSize={Enum.AutomaticSize.X}
				AnchorPoint={new Vector2(1, 0.5)}
				Position={new UDim2(1, -8, 0.5, 0)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={false}
			>
				<Button
					text="SEND"
					icon="Send.4"
					onClick={submit}
					color={Palette.cyan}
					textColor={Palette.ink}
					size={UDim2.fromOffset(0, 48)}
					hug={true}
					disabled={!canSend}
					reducedMotion={softMotion}
					highlight={canSend}
				/>
			</frame>
		</frame>
	);

	const sections: Array<{ id: string; height?: number; fill?: boolean; minHeight?: number; element: React.Element }> = [];
	if (showStatus) sections.push({ id: "status", height: STATUS_HEIGHT, element: statusElement });
	if (showStatus && searchOpen) {
		sections.push({
			id: "search",
			height: 44,
			element: (
				<SearchField
					value={logQuery}
					onChange={setLogQuery}
					placeholder="Search words, from:name or in:global"
					accent={Palette.cyan}
					reducedMotion={softMotion}
					size={UDim2.fromScale(1, 1)}
					zIndex={22}
				/>
			),
		});
	}
	const unreadByTab = chat.unreadByTab ?? {};
	const tabOptions = TAB_DEFS.map((def) => {
		const waiting = unreadByTab[def.id] ?? 0;
		return { id: def.id, label: waiting > 0 ? `${def.label} ${waiting}` : def.label };
	});
	const tabColumns = viewport.compact ? 3 : TAB_DEFS.size();
	sections.push({
		id: "tabs",
		height: segmentedHeight(TAB_DEFS.size(), tabColumns, viewport, TAB_ROW_H, 6),
		element: (
			<SegmentedTabs options={tabOptions} value={tab} onChange={chat.setTab} accent={Palette.cyan} columns={tabColumns} gap={6} size={UDim2.fromScale(1, 1)} reducedMotion={softMotion} />
		),
	});
	if (tab === "whispers" && chat.whispers.size() > 0) {
		const peerChips = chat.whispers.map((entry): Chip => {
			const selected = entry.userId === chat.peer;
			let label = entry.displayName;
			if (entry.unread > 0) label = `${label} (${entry.unread})`;
			if (entry.online === false) label = `${label} · away`;
			return {
				key: `peer-${entry.userId}`,
				element: (
					<Button
						text={label}
						onClick={() => chat.setPeer(entry.userId)}
						color={selected ? Palette.violet : Palette.panelSoft}
						textColor={selected ? Palette.ink : Palette.cream}
						size={UDim2.fromOffset(0, PEER_ROW_H - 4)}
						hug={true}
						reducedMotion={softMotion}
					/>
				),
			};
		});
		sections.push({ id: "peers", height: PEER_ROW_H, element: chipRail(peerChips) });
	}
	const nothingShown = shownMessages.size() === 0;
	sections.push({
		id: "messages",
		fill: true,
		minHeight: 120,
		element: !nothingShown
			? messagesElement
			: filteringLog
				? emptyLine(`No messages match "${logQuery}".`)
				: emptyLine(EMPTY_TAB_TEXT[tab] ?? "Nobody has said anything here yet. Say hi."),
	});
	if (showBanner) sections.push({ id: "banner", height: BANNER_HEIGHT, element: bannerElement });
	if (suggestions.size() > 0) {
		const suggestChips = suggestions.map((suggestion, i): Chip => {
			const first = i === 0;
			return {
				key: `suggest-${i + 1}`,
				element: (
					<Button
						text={suggestion.kind === "command" ? suggestion.label : `${suggestion.label}  ${suggestion.detail}`}
						onClick={() => fillComposer(suggestion.fill, true)}
						color={first ? Palette.cyan : Palette.panelSoft}
						textColor={first ? Palette.ink : Palette.cream}
						size={UDim2.fromOffset(0, SUGGEST_ROW_H - 4)}
						hug={true}
						reducedMotion={softMotion}
					/>
				),
			};
		});
		sections.push({ id: "suggest", height: SUGGEST_ROW_H, element: chipRail(suggestChips, 24) });
	}
	sections.push({ id: "input", height: inputHeight, element: inputElement });
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.void} BorderSizePixel={0} ClipsDescendants={true}>
			<uicorner CornerRadius={new UDim(0, Layout.cardRadius)} />
			<uistroke Color={Palette.cyan} Thickness={1} Transparency={0.55} />
			<PageScaffold gap={chromeGap} inset={SIDE_INSET} tailPad={chromeGap} scrollBarColor={Palette.cyan} scrollBarThickness={0} sections={sections} />
		</frame>
	);
}

export = { ChatView };

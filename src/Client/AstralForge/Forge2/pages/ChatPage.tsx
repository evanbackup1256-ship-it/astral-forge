// Chat, rebuilt on Forge2 over the same chat runtime as before (TextChatService channels plus the
// ChatGlobal / ChatOpenWhisper remotes): channel tabs with unread counts, whispers, mute, clear,
// and the Social settings (global in All, text size, profile accents). B closes an open message
// menu, then leaves a whisper thread.
import React from "@rbxts/react";
import { Audio } from "../../AudioKit/audio";
import type { useGameChat } from "../../ClientRuntime/chat";
import { useShellChat } from "../shell/chatContext";
import { useChangePop, useStagger } from "../../MotionKit/motion";
import { Button } from "../design/Button";
import { Panel } from "../design/Panel";
import { Chip, Tab } from "../design/Pick";
import { EmptyState } from "../design/Layers";
import { Text } from "../design/Text";
import { Fonts, gap, HIT, Iron, Type } from "../design/tokens";
import { useBack } from "../input/input";
import type { PageProps } from "../router/routes";

const TABS: Array<[string, string]> = [
	["all", "All"],
	["server", "Server"],
	["global", "Global"],
	["crew", "Crew"],
	["friends", "Friends"],
	["whispers", "Whispers"],
];

type Chat = ReturnType<typeof useGameChat>;
type Message = Chat["messages"][number];

function nameColor(message: Message): Color3 {
	if (message.profileAccent !== undefined) return message.profileAccent;
	if (message.system === true) return Iron.muted();
	if (message.localPlayer) return Iron.brass();
	return Color3.fromHSV((message.userId % 97) / 97, 0.45, 1);
}

function Line(props: { message: Message; index: number; phone: boolean; size: number; open: boolean; onPick: () => void }) {
	const m = props.message;
	const rise = useStagger(math.min(props.index, 8), false, 0.02, 0.16);
	const name = m.system === true ? "" : `<b>${m.displayName}</b>${m.titleName !== undefined ? `  <i>${m.titleName}</i>` : ""}  `;
	const tag = m.channel === "global" ? "Global · " : "";
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.index}>
			<frame
				Size={new UDim2(1, 0, 0, 0)}
				AutomaticSize={Enum.AutomaticSize.Y}
				BackgroundColor3={m.mention === true ? Iron.raised() : Iron.sunk()}
				BackgroundTransparency={props.open || m.mention === true ? 0 : 0.6}
				BorderSizePixel={0}
				Position={rise.map((p) => UDim2.fromOffset((1 - p) * 12, 0))}
			>
				<uicorner CornerRadius={new UDim(0, 6)} />
				<uipadding PaddingLeft={new UDim(0, 10)} PaddingRight={new UDim(0, 10)} PaddingTop={new UDim(0, 6)} PaddingBottom={new UDim(0, 6)} />
				<textlabel
					Size={new UDim2(1, 0, 0, 0)}
					AutomaticSize={Enum.AutomaticSize.Y}
					BackgroundTransparency={1}
					RichText
					TextWrapped
					TextXAlignment={Enum.TextXAlignment.Left}
					FontFace={Fonts.body}
					TextSize={props.size}
					TextColor3={m.system === true ? Iron.muted() : Iron.soft()}
					Text={`<font color="#${nameColor(m).ToHex()}">${tag}${name}</font>${m.text}`}
				/>
				{m.system !== true && !m.localPlayer && (
					<textbutton Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} Text="" Selectable Event={{ Activated: props.onPick }} />
				)}
			</frame>
		</frame>
	);
}

export function ChatPage(props: PageProps) {
	const shellChat = useShellChat();
	if (shellChat === undefined) return undefined;
	return <ChatBody page={props} chat={shellChat} />;
}

function ChatBody(outer: { page: PageProps; chat: Chat }) {
	const props = outer.page;
	const phone = props.phone;
	const chat = outer.chat;
	const [draft, setDraft] = React.useState("");
	const [menuFor, setMenuFor] = React.useState<number | undefined>(undefined);
	const [note, setNote] = React.useState("");
	const listRef = React.useRef<ScrollingFrame>();
	const notePop = useChangePop(note);

	useBack(menuFor !== undefined, () => setMenuFor(undefined));
	useBack(menuFor === undefined && chat.tab === "whispers" && chat.peer !== undefined, () => chat.setPeer(undefined));

	const shown = chat.messages.filter((m) => {
		if (chat.tab === "all") return m.channel !== "global" || chat.showGlobal;
		if (chat.tab === "whispers") return chat.peer === undefined ? false : m.peerId === chat.peer;
		return m.channel === chat.tab || m.system === true;
	});
	const textSize = math.floor(Type.body(phone) * chat.textScale);

	// keep the newest line in view as messages arrive
	React.useEffect(() => {
		const list = listRef.current;
		if (list === undefined) return;
		task.defer(() => {
			list.CanvasPosition = new Vector2(0, math.max(0, list.AbsoluteCanvasSize.Y - list.AbsoluteSize.Y));
		});
	}, [shown.size(), chat.tab, chat.peer]);

	const submit = () => {
		if (draft === "") return;
		const text = draft;
		chat.send(text, (ok, reason) => {
			if (ok) {
				setDraft("");
				setNote("");
			} else {
				Audio.play("error");
				setNote(reason ?? "");
			}
		});
	};

	const menuTarget = menuFor !== undefined ? chat.messages.find((m) => m.userId === menuFor) : undefined;
	const space = gap(phone, "m");
	const whisperPicker = chat.tab === "whispers" && chat.peer === undefined;

	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
			<uipadding PaddingTop={new UDim(0, space)} PaddingBottom={new UDim(0, space)} PaddingLeft={new UDim(0, space)} PaddingRight={new UDim(0, space)} />
			<uilistlayout Padding={new UDim(0, space)} SortOrder={Enum.SortOrder.LayoutOrder} />

			<scrollingframe
				Size={new UDim2(1, 0, 0, HIT + 4)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				CanvasSize={new UDim2()}
				AutomaticCanvasSize={Enum.AutomaticSize.X}
				ScrollingDirection={Enum.ScrollingDirection.X}
				ScrollBarThickness={0}
				LayoutOrder={0}
			>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 6)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{TABS.map(([key, label], i) => (
					<Tab
						key={key}
						text={label}
						active={chat.tab === key}
						width={phone ? 92 : 112}
						badge={key === "all" ? undefined : chat.unreadByTab[key]}
						order={i}
						onPress={() => {
							setMenuFor(undefined);
							chat.setTab(key);
						}}
					/>
				))}
			</scrollingframe>

			{chat.tab === "whispers" && chat.peer !== undefined && (
				<frame Size={new UDim2(1, 0, 0, HIT)} BackgroundTransparency={1} LayoutOrder={1}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 10)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
					<Button text="Back" tone="quiet" width={88} onPress={() => chat.setPeer(undefined)} order={0} />
					<Text text={chat.whispers.find((w) => w.userId === chat.peer)?.displayName ?? ""} size={Type.body(phone)} font={Fonts.heavy} box={new UDim2(1, -100, 1, 0)} order={1} />
				</frame>
			)}

			<scrollingframe
				ref={listRef}
				Size={new UDim2(1, 0, 1, -(HIT + 4 + space) * 2 - (chat.tab === "whispers" && chat.peer !== undefined ? HIT + space : 0) - (menuTarget !== undefined ? HIT + space : 0) - (note !== "" ? 20 + space : 0))}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				CanvasSize={new UDim2()}
				AutomaticCanvasSize={Enum.AutomaticSize.Y}
				ScrollBarThickness={phone ? 2 : 4}
				ScrollBarImageColor3={Iron.brassDeep()}
				LayoutOrder={2}
			>
				<uilistlayout Padding={new UDim(0, 4)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{whisperPicker ? (
					chat.whispers.size() === 0 ? (
						<EmptyState title="No whispers" body="Type /w and a name to start one." phone={phone} />
					) : (
						chat.whispers.map((w, i) => (
							<frame key={tostring(w.userId)} Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={i}>
								<Panel pad={10} spacing={2} seam={w.unread > 0}>
									<Text text={w.unread > 0 ? `${w.displayName}  (${w.unread})` : w.displayName} size={Type.body(phone)} font={Fonts.heavy} order={0} />
									<Text text={w.lastText} size={Type.small(phone)} color={Iron.muted()} order={1} />
								</Panel>
								<textbutton Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} Text="" Selectable ZIndex={5} Event={{ Activated: () => chat.setPeer(w.userId) }} />
							</frame>
						))
					)
				) : shown.size() === 0 ? (
					<EmptyState title={chat.connected ? "Quiet in here" : "Connecting"} phone={phone} />
				) : (
					shown.map((m, i) => (
						<Line key={m.id} message={m} index={shown.size() - 1 - i} phone={phone} size={textSize} open={menuFor === m.userId} onPick={() => setMenuFor(menuFor === m.userId ? undefined : m.userId)} />
					))
				)}
			</scrollingframe>

			{menuTarget !== undefined && (
				<frame Size={new UDim2(1, 0, 0, HIT)} BackgroundTransparency={1} LayoutOrder={3}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} VerticalAlignment={Enum.VerticalAlignment.Center} />
					<Chip text="Whisper" on={false} order={0} onPress={() => {
						chat.openWhisper(menuTarget.userId);
						setMenuFor(undefined);
					}} />
					<Chip text={chat.muted[menuTarget.userId] === true ? "Unmute" : "Mute"} on={false} color={Iron.ember()} order={1} onPress={() => {
						chat.setMute(menuTarget.userId, chat.muted[menuTarget.userId] !== true);
						setMenuFor(undefined);
					}} />
				</frame>
			)}

			<frame Size={new UDim2(1, 0, 0, HIT + 4)} BackgroundTransparency={1} LayoutOrder={4}>
				<textbox
					Size={new UDim2(1, -(phone ? 82 : 196), 1, 0)}
					BackgroundColor3={Iron.sunk()}
					BorderSizePixel={0}
					Text={draft}
					PlaceholderText={chat.placeholder}
					PlaceholderColor3={Iron.muted()}
					TextColor3={Iron.text()}
					FontFace={Fonts.body}
					TextSize={Type.body(phone)}
					TextXAlignment={Enum.TextXAlignment.Left}
					TextTruncate={Enum.TextTruncate.AtEnd}
					ClearTextOnFocus={false}
					Change={{ Text: (box) => setDraft(box.Text) }}
					Event={{ FocusLost: (_box, enter) => enter && submit() }}
				>
					<uicorner CornerRadius={new UDim(0, 6)} />
					<uipadding PaddingLeft={new UDim(0, 12)} PaddingRight={new UDim(0, 12)} />
				</textbox>
				<frame Size={UDim2.fromOffset(phone ? 74 : 188, HIT + 4)} Position={new UDim2(1, phone ? -74 : -188, 0, 0)} BackgroundTransparency={1}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 8)} HorizontalAlignment={Enum.HorizontalAlignment.Right} SortOrder={Enum.SortOrder.LayoutOrder} />
					{!phone && <Button text="Clear" tone="quiet" width={88} order={0} onPress={chat.clear} />}
					<Button text="Send" width={phone ? 74 : 92} height={HIT + 4} disabled={draft === ""} order={1} onPress={submit} />
				</frame>
			</frame>
			{note !== "" && (
				<frame Size={new UDim2(1, 0, 0, 20)} BackgroundTransparency={1} LayoutOrder={5}>
					<uiscale Scale={notePop} />
					<Text text={note} size={Type.small(phone)} color={Iron.ember()} box={UDim2.fromScale(1, 1)} />
				</frame>
			)}
		</frame>
	);
}

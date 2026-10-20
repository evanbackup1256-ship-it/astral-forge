import { ClientEvents } from "../ClientNetwork";
import React from "@rbxts/react";
import * as ChatText from "../CoreKit/chatText";
import { truthy } from "../lua";
import * as ProfileStyle from "../../../Shared/AstralForge/Shared/ProfileStyle";

const Players = game.GetService("Players");
const ReplicatedStorage = game.GetService("ReplicatedStorage");
const TextChatService = game.GetService("TextChatService");

interface AudioApi {
	play(sound: string): void;
}
const Audio = (require(script.Parent!.Parent!.FindFirstChild("AudioKit") as ModuleScript) as (name: string) => { Audio: AudioApi })(
	"audio",
).Audio;
const sharedRoot = ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared");
const ChatRules = require(sharedRoot.WaitForChild("ChatRules") as ModuleScript) as typeof import("../../../Shared/AstralForge/Shared/ChatRules");

const MAX_MESSAGES = 200;
const MAX_INPUT = ChatRules.MAX_INPUT;
const TAB_KEYS = ["global", "server", "crew", "friends", "whispers"];
const CHANNEL_LABEL: Record<string, string | undefined> = {
	global: "global chat",
	server: "this server",
	crew: "your crew",
	friends: "friends here",
};

type Done = (ok: boolean, reason?: string) => void;
type Run = (action: string, payload: Record<string, unknown>, callback: (response: unknown) => void) => unknown;

interface ChatRecord {
	id: string;
	userId: number;
	username: string;
	displayName: string;
	text: string;
	at: number;
	world: number;
	channel: string;
	peerId?: number;
	localPlayer: boolean;
	system?: boolean;
	remote?: boolean;
	mention?: boolean;
	titleId?: string;
	titleName?: string;
	titleFx?: string;
	artifactName?: string;
	artifactElement?: string;
	artifactColor?: Color3;
	profileAccent?: Color3;
	profileFrame?: string;
}

interface WhisperEntry {
	userId: number;
	name: string;
	displayName: string;
	unread: number;
	lastText: string;
	online?: boolean;
}

interface Channels {
	server?: TextChannel;
	friends?: TextChannel;
	crew: Record<string, TextChannel | undefined>;
	whisper: Map<number, TextChannel>;
}

function nonEmpty(value: unknown): string | undefined {
	return typeIs(value, "string") && value !== "" ? value : undefined;
}

function readTitleAttrs(player: Player | undefined) {
	if (player === undefined) {
		return {} as Partial<ChatRecord>;
	}
	const titleId = player.GetAttribute("EquippedTitle");
	const titleName = player.GetAttribute("EquippedTitleName");
	const titleFx = player.GetAttribute("EquippedTitleFx");
	const artifactName = player.GetAttribute("EquippedArtifactName");
	const artifactElement = player.GetAttribute("EquippedArtifactElement");
	const artifactColor = player.GetAttribute("EquippedArtifactColor");
	const style = ProfileStyle.fromPlayer(player);
	const hasArtifact = typeIs(player.GetAttribute("EquippedArtifact"), "string") && player.GetAttribute("EquippedArtifact") !== "";
	return {
		titleId: nonEmpty(titleId),
		titleName: nonEmpty(titleName),
		titleFx: nonEmpty(titleFx),
		artifactName: hasArtifact ? nonEmpty(artifactName) : undefined,
		artifactElement: hasArtifact ? nonEmpty(artifactElement) : undefined,
		artifactColor: hasArtifact && typeIs(artifactColor, "Color3") ? artifactColor : undefined,
		profileAccent: style.accent,
		profileFrame: style.frame?.Id,
	} as Partial<ChatRecord>;
}

let systemSerial = 0;
function systemMessage(text: string): ChatRecord {
	systemSerial += 1;
	return {
		id: `system-${systemSerial}-${os.clock()}`,
		userId: 0,
		username: "System",
		displayName: "System",
		text,
		at: os.time(),
		world: 0,
		channel: "system",
		localPlayer: false,
		system: true,
	};
}

function pushTrimmed(current: ChatRecord[], incoming: ChatRecord): ChatRecord[] {
	const updated = table.clone(current);
	updated.push(incoming);
	while (updated.size() > MAX_MESSAGES) {
		updated.shift();
	}
	return updated;
}

function statusError(status: Enum.TextChatMessageStatus): string {
	if (status === Enum.TextChatMessageStatus.Floodchecked) {
		return "Slow down, chat is rate limited.";
	}
	if (status === Enum.TextChatMessageStatus.MessageTooLong) {
		return "Message is too long.";
	}
	if (status === Enum.TextChatMessageStatus.TextFilterFailed) {
		return "Roblox chat filters blocked that message.";
	}
	if (status === Enum.TextChatMessageStatus.InvalidPrivacySettings) {
		return "Chat is unavailable for this account.";
	}
	if (status === Enum.TextChatMessageStatus.InvalidTextChannelPermissions) {
		return "You can't send on this channel.";
	}
	return "Message not sent.";
}

function rosterOf(selfId: number) {
	const list: Array<{ userId: number; name: string; displayName: string }> = [];
	for (const player of Players.GetPlayers()) {
		if (player.UserId !== selfId) {
			list.push({ userId: player.UserId, name: player.Name, displayName: player.DisplayName });
		}
	}
	return list;
}

function buildRecord(userId: number, text: string, channel: string, peerId: number | undefined, id: string): ChatRecord {
	const player = Players.GetPlayerByUserId(userId);
	const title = readTitleAttrs(player);
	const zone = player !== undefined ? player.GetAttribute("CurrentZone") : undefined;
	return {
		id,
		userId,
		username: player !== undefined ? player.Name : `Player${userId}`,
		displayName: player !== undefined ? player.DisplayName : `Player ${userId}`,
		text,
		world: typeIs(zone, "number") ? zone : 1,
		channel,
		peerId,
		localPlayer: userId === Players.LocalPlayer.UserId,
		at: os.time(),
		// someone else @mentioning you gets highlighted and a stronger sound
		mention:
			userId !== Players.LocalPlayer.UserId &&
			ChatRules.mentions(text, Players.LocalPlayer.Name, Players.LocalPlayer.DisplayName),
		titleId: title.titleId,
		titleName: title.titleName,
		titleFx: title.titleFx,
		artifactName: title.artifactName,
		artifactElement: title.artifactElement,
		artifactColor: title.artifactColor,
		profileAccent: title.profileAccent,
		profileFrame: title.profileFrame,
	};
}

function emptyUnread(): Record<string, number> {
	return { global: 0, server: 0, crew: 0, friends: 0, whispers: 0 };
}

function useGameChat(active: boolean, enabled = true, dispatch?: Run, settings?: unknown) {
	const selfId = Players.LocalPlayer.UserId;
	const [messages, setMessages] = React.useState<ChatRecord[]>([]);
	const [unreadByTab, setUnreadByTab] = React.useState(emptyUnread);
	const [connected, setConnected] = React.useState(false);
	const [tab, setTabState] = React.useState("all");
	const [peer, setPeerState] = React.useState<number | undefined>(undefined);
	const [whispers, setWhispers] = React.useState<WhisperEntry[]>([]);
	const [muted, setMuted] = React.useState<Record<number, true | undefined>>({});
	// stamped by the "/" key so the chat page focuses its box once it is open (a stale stamp,
	// from an earlier press, is ignored when the page is opened some other way later)
	const [focusRequest, setFocusRequest] = React.useState(0);
	const requestFocus = React.useCallback(() => {
		setFocusRequest(os.clock());
	}, []);
	const channelsRef = React.useRef<Channels>({ server: undefined, friends: undefined, crew: {}, whisper: new Map() });
	const pendingRef = React.useRef(new Map<number, { text?: string; done?: Done }>());
	const seenRef = React.useRef({ ids: new Set<string>(), order: [] as string[] });
	const lastWhisperRef = React.useRef<number | undefined>(undefined);
	const activeRef = React.useRef(active);
	const tabRef = React.useRef(tab);
	const peerRef = React.useRef(peer);
	const mutedRef = React.useRef(muted);
	const dispatchRef = React.useRef(dispatch);
	const aliveRef = React.useRef(true);
	const settingsRef = React.useRef(settings);
	settingsRef.current = settings;
	const sendWorkers = React.useRef(new Set<thread>());
	activeRef.current = active;
	tabRef.current = tab;
	peerRef.current = peer;
	mutedRef.current = muted;
	dispatchRef.current = dispatch;
	const clearSeen = React.useCallback((which: string, peerId?: number) => {
		setUnreadByTab((current) => {
			if (which === "all") {
				return emptyUnread();
			}
			if (current[which] === undefined || current[which] === 0) {
				return current;
			}
			const nextValue = table.clone(current);
			nextValue[which] = 0;
			return nextValue;
		});
		if (which === "whispers" || which === "all") {
			setWhispers((current) => {
				let changed = false;
				const nextValue: WhisperEntry[] = [];
				for (const entry of current) {
					if (entry.unread > 0 && (peerId === undefined || entry.userId === peerId)) {
						const copy = table.clone(entry);
						copy.unread = 0;
						nextValue.push(copy);
						changed = true;
					} else {
						nextValue.push(entry);
					}
				}
				return changed ? nextValue : current;
			});
		}
	}, []);
	React.useEffect(() => {
		if (active) {
			clearSeen(tab, tab === "whispers" ? peer : undefined);
		}
	}, [active, tab, peer]);
	const note = React.useCallback((text: string) => {
		setMessages((current) => pushTrimmed(current, systemMessage(text)));
	}, []);
	const touchWhisper = React.useCallback((peerId: number, text: string | undefined, incoming: boolean) => {
		setWhispers((current) => {
			const nextValue: WhisperEntry[] = [];
			let found: WhisperEntry | undefined;
			for (const entry of current) {
				if (entry.userId === peerId) {
					found = table.clone(entry);
				} else {
					nextValue.push(entry);
				}
			}
			if (found === undefined) {
				const player = Players.GetPlayerByUserId(peerId);
				found = {
					userId: peerId,
					name: player !== undefined ? player.Name : `Player${peerId}`,
					displayName: player !== undefined ? player.DisplayName : `Player ${peerId}`,
					unread: 0,
					lastText: "",
				};
			}
			if (text !== undefined) {
				found.lastText = text;
			}
			found.online = channelsRef.current.whisper.get(peerId) !== undefined;
			if (incoming) {
				const looking = activeRef.current && tabRef.current === "whispers" && peerRef.current === peerId;
				if (!looking) {
					found.unread = math.min(99, found.unread + 1);
				}
			}
			nextValue.unshift(found);
			return nextValue;
		});
	}, []);
	const ingestRecord = React.useCallback((record: ChatRecord, quiet: boolean) => {
		const seen = seenRef.current;
		if (seen.ids.has(record.id)) {
			return undefined;
		}
		seen.ids.add(record.id);
		seen.order.push(record.id);
		if (seen.order.size() > MAX_MESSAGES * 2) {
			seen.ids.delete(seen.order.shift()!);
		}
		setMessages((current) => pushTrimmed(current, record));
		const tabKey = record.channel === "whisper" ? "whispers" : record.channel;
		if (record.channel === "whisper" && record.peerId !== undefined) {
			touchWhisper(record.peerId, record.text, !record.localPlayer);
			if (!record.localPlayer) {
				lastWhisperRef.current = record.peerId;
			}
		}
		if (record.localPlayer || quiet || mutedRef.current[record.userId]) {
			return undefined;
		}
		const prefs = settingsRef.current as { ChatSounds?: number } | undefined;
		if (!typeIs(prefs, "table") || prefs.ChatSounds === undefined || prefs.ChatSounds >= 0.5) {
			Audio.play(record.mention ? "notification" : "chatReceive");
		}
		let seeing = activeRef.current && (tabRef.current === "all" || tabRef.current === tabKey);
		if (record.channel === "whisper" && tabRef.current === "whispers") {
			seeing = activeRef.current && peerRef.current === record.peerId;
		}
		// a whisper or a mention you are not looking at comes out of the island with who sent it
		if (!seeing && (record.channel === "whisper" || record.mention)) {
			pcall(() => {
				const Juice = require(script.Parent!.Parent!.FindFirstChild("JuiceFx") as ModuleScript) as {
					banner(this: void, ...args: unknown[]): void;
				};
				const theme = (require(script.Parent!.Parent!.FindFirstChild("CoreKit") as ModuleScript) as (
					name: string,
				) => { Palette: { violet: Color3; cyan: Color3 } })("theme");
				Juice.banner(
					record.channel === "whisper" ? `${record.displayName} whispered` : `${record.displayName} mentioned you`,
					record.text,
					record.channel === "whisper" ? theme.Palette.violet : theme.Palette.cyan,
					"Chat",
					3.2,
					"Info",
				);
			});
		}
		if (!seeing) {
			setUnreadByTab((current) => {
				const nextValue = table.clone(current);
				nextValue[tabKey] = math.min(99, (nextValue[tabKey] ?? 0) + 1);
				return nextValue;
			});
		}
	}, []);
	const sendOn = React.useCallback((target: TextChannel, text: string, done?: Done) => {
		Audio.play("chatSend");
		// eslint-disable-next-line prefer-const
		let worker: thread | undefined;
		worker = task.defer(() => {
			const [ok, result] = pcall(() => target.SendAsync(text));
			if (worker !== undefined) {
				sendWorkers.current.delete(worker);
			}
			worker = undefined;
			if (!aliveRef.current) {
				return undefined;
			}
			if (!ok) {
				if (done) {
					done(false, "Roblox could not send this message. Check your chat privacy settings and try again.");
				}
				return undefined;
			}
			if (result === undefined) {
				if (done) {
					done(false, "Roblox did not confirm the message. Try again.");
				}
				return undefined;
			}
			const message = result as TextChatMessage;
			if (message.Status !== Enum.TextChatMessageStatus.Success) {
				const name = tostring(message.Status);
				if (string.find(name, "Sending")[0] === undefined && string.find(name, "Pending")[0] === undefined) {
					if (done) {
						done(false, statusError(message.Status));
					}
					return undefined;
				}
			}
			if (done) {
				done(true);
			}
		});
		sendWorkers.current.add(worker);
	}, []);
	React.useEffect(() => {
		if (!enabled) {
			setConnected(false);
			setMessages([systemMessage("Chat is disabled in this experience.")]);
			return undefined;
		}
		aliveRef.current = true;
		let alive = true;
		const connections: RBXScriptConnection[] = [];
		const channelConnections = new Map<TextChannel, RBXScriptConnection>();
		const track = (connection: RBXScriptConnection) => {
			connections.push(connection);
			return connection;
		};
		const ingestText = (message: TextChatMessage, channel: string, peerId: number | undefined) => {
			if (!alive || message.TextSource === undefined || message.Status !== Enum.TextChatMessageStatus.Success) {
				return undefined;
			}
			const userId = message.TextSource.UserId;
			const id = message.MessageId !== "" ? message.MessageId : `${userId}-${os.clock()}`;
			ingestRecord(buildRecord(userId, message.Text, channel, peerId, id), false);
		};
		const attach = (candidate: Instance) => {
			if (!alive || !candidate.IsA("TextChannel") || channelConnections.has(candidate)) {
				return undefined;
			}
			const name = candidate.Name;
			const refs = channelsRef.current;
			if (name === ChatRules.SERVER_CHANNEL) {
				refs.server = candidate;
				channelConnections.set(
					candidate,
					candidate.MessageReceived.Connect((message) => {
						ingestText(message, "server", undefined);
					}),
				);
				setConnected(true);
			} else if (name === ChatRules.FRIENDS_CHANNEL) {
				refs.friends = candidate;
				channelConnections.set(
					candidate,
					candidate.MessageReceived.Connect((message) => {
						ingestText(message, "friends", undefined);
					}),
				);
			} else if (ChatRules.isCrewChannel(name)) {
				// every crew channel replicates; only members receive its messages, and sending
				// picks the channel named for this player's own crew
				refs.crew[name] = candidate;
				channelConnections.set(
					candidate,
					candidate.MessageReceived.Connect((message) => {
						ingestText(message, "crew", undefined);
					}),
				);
			} else {
				const peerId = ChatRules.whisperPeer(name, selfId);
				if (peerId === undefined) {
					return undefined;
				}
				refs.whisper.set(peerId, candidate);
				channelConnections.set(
					candidate,
					candidate.MessageReceived.Connect((message) => {
						ingestText(message, "whisper", peerId);
					}),
				);
				touchWhisper(peerId, undefined, false);
				const pending = pendingRef.current.get(peerId);
				pendingRef.current.delete(peerId);
				if (typeIs(pending, "table") && pending.text !== undefined) {
					sendOn(candidate, pending.text, pending.done);
				}
			}
		};
		const detach = (candidate: Instance) => {
			const connection = channelConnections.get(candidate as TextChannel);
			if (connection === undefined) {
				return undefined;
			}
			connection.Disconnect();
			channelConnections.delete(candidate as TextChannel);
			const refs = channelsRef.current;
			if (refs.server === candidate) {
				refs.server = undefined;
				setConnected(false);
			} else if (refs.friends === candidate) {
				refs.friends = undefined;
			} else if (refs.crew[candidate.Name] === candidate) {
				refs.crew[candidate.Name] = undefined;
			} else {
				for (const [peerId, channel] of refs.whisper) {
					if (channel === candidate) {
						refs.whisper.delete(peerId);
						touchWhisper(peerId, undefined, false);
					}
				}
			}
		};
		const onEffect = (raw: unknown) => {
			if (!alive || !typeIs(raw, "table")) {
				return undefined;
			}
			const payload = raw as { Type?: unknown; Messages?: unknown; Backlog?: unknown };
			if (payload.Type !== "ChatGlobal" || !typeIs(payload.Messages, "table")) {
				return undefined;
			}
			for (const entry of payload.Messages as unknown[]) {
				if (!typeIs(entry, "table")) {
					continue;
				}
				const item = entry as { UserId?: unknown; Text?: unknown; Id?: unknown; Name?: unknown; Display?: unknown; At?: unknown };
				if (typeIs(item.UserId, "number") && typeIs(item.Text, "string")) {
					const record = buildRecord(item.UserId, item.Text, "global", undefined, `g-${tostring(item.Id)}`);
					if (typeIs(item.Name, "string")) {
						record.username = item.Name;
					}
					if (typeIs(item.Display, "string")) {
						record.displayName = item.Display;
					}
					record.remote = Players.GetPlayerByUserId(item.UserId) === undefined;
					if (typeIs(item.At, "number")) {
						record.at = item.At;
					}
					ingestRecord(record, payload.Backlog === true);
				}
			}
		};
		track(ClientEvents.effect.connect(onEffect));
		const connecting = systemMessage("Chat is connecting. This can take a moment on slower devices.");
		setMessages([connecting]);
		const connectWorker = task.spawn(() => {
			const channels = TextChatService.WaitForChild("TextChannels", 30);
			if (!alive) {
				return undefined;
			}
			if (channels === undefined) {
				setConnected(false);
				note("Roblox chat did not start. Rejoin, then check Privacy > Communication if it still fails.");
				return undefined;
			}
			track(channels.ChildAdded.Connect(attach));
			track(channels.ChildRemoved.Connect(detach));
			for (const item of channels.GetChildren()) {
				attach(item);
			}
			if (channelsRef.current.server === undefined) {
				const general = channels.WaitForChild(ChatRules.SERVER_CHANNEL, 30);
				if (general === undefined && alive) {
					note("Roblox chat is unavailable. Rejoin, then check Privacy > Communication if it still fails.");
					return undefined;
				}
			}
			if (alive) {
				setMessages((current) => {
					const kept: ChatRecord[] = [];
					for (const message of current) {
						if (message !== connecting) {
							kept.push(message);
						}
					}
					return pushTrimmed(kept, systemMessage("Chat is ready. Roblox filters every message. Type / to see shortcuts."));
				});
			}
		});
		return () => {
			alive = false;
			aliveRef.current = false;
			pcall(task.cancel, connectWorker);
			for (const worker of sendWorkers.current) {
				pcall(task.cancel, worker);
			}
			sendWorkers.current.clear();
			for (const connection of connections) {
				connection.Disconnect();
			}
			for (const [, connection] of channelConnections) {
				connection.Disconnect();
			}
			channelsRef.current = { server: undefined, friends: undefined, crew: {}, whisper: new Map() };
		};
	}, [enabled]);
	const setTab = React.useCallback((nextTab: string) => {
		if (!ChatRules.CHANNELS.includes(nextTab)) {
			return undefined;
		}
		setTabState(nextTab);
	}, []);
	const setPeer = React.useCallback((userId: number | undefined) => {
		setPeerState(userId);
		if (userId !== undefined) {
			setTabState("whispers");
		}
	}, []);
	const openWhisper = React.useCallback((userId: unknown, text?: string, done?: Done) => {
		if (!typeIs(userId, "number") || userId === selfId) {
			if (done) {
				done(false, "Pick another player to whisper.");
			}
			return undefined;
		}
		setPeerState(userId);
		setTabState("whispers");
		touchWhisper(userId, undefined, false);
		const existing = channelsRef.current.whisper.get(userId);
		if (existing !== undefined) {
			if (text !== undefined) {
				sendOn(existing, text, done);
			} else if (done) {
				done(true);
			}
			return undefined;
		}
		const run = dispatchRef.current;
		if (run === undefined) {
			if (done) {
				done(false, "Whispers are still starting.");
			}
			return undefined;
		}
		pendingRef.current.set(userId, { text, done });
		run("ChatOpenWhisper", { UserId: userId }, (raw) => {
			const response = raw as { ok?: unknown; error?: unknown } | undefined;
			if (!typeIs(response, "table") || response.ok === false) {
				const pending = pendingRef.current.get(userId);
				pendingRef.current.delete(userId);
				const reason =
					typeIs(response, "table") && typeIs(response.error, "string") ? response.error : "Could not open that whisper.";
				if (pending !== undefined && pending.done !== undefined) {
					pending.done(false, reason);
				} else if (text === undefined) {
					note(reason);
				}
				return undefined;
			}
			// the channel may have replicated before the reply landed
			const ready = channelsRef.current.whisper.get(userId);
			const pending = pendingRef.current.get(userId);
			if (ready !== undefined && pending !== undefined) {
				pendingRef.current.delete(userId);
				if (pending.text !== undefined) {
					sendOn(ready, pending.text, pending.done);
				} else if (pending.done !== undefined) {
					pending.done(true);
				}
			} else if (pending !== undefined && pending.text === undefined) {
				pendingRef.current.delete(userId);
				if (pending.done !== undefined) {
					pending.done(true);
				}
			}
		});
	}, []);
	const sendGlobal = React.useCallback((text: string, done?: Done) => {
		const run = dispatchRef.current;
		if (run === undefined) {
			if (done) {
				done(false, "Global chat is still starting.");
			}
			return undefined;
		}
		Audio.play("chatSend");
		run("ChatGlobal", { Text: text }, (raw) => {
			const response = raw as { ok?: unknown; error?: unknown } | undefined;
			if (typeIs(response, "table") && response.ok !== false) {
				if (done) {
					done(true);
				}
			} else if (done) {
				done(
					false,
					typeIs(response, "table") && typeIs(response.error, "string")
						? response.error
						: "Global chat did not take that message.",
				);
			}
		});
	}, []);
	const setMute = React.useCallback((userId: number, value: boolean) => {
		setMuted((current) => {
			const nextValue = table.clone(current);
			nextValue[userId] = value ? true : undefined;
			return nextValue;
		});
	}, []);
	const sendTo = (where: string, text: string, done?: Done) => {
		const refs = channelsRef.current;
		if (where === "global") {
			sendGlobal(text, done);
		} else if (where === "crew") {
			const store = require(script.Parent!.Parent!.FindFirstChild("CrewStore") as ModuleScript) as {
				get(this: void): { crew?: { Channel?: string } };
			};
			const mine = store.get().crew;
			const channel = mine && mine.Channel !== undefined ? refs.crew[mine.Channel] : undefined;
			if (channel === undefined) {
				if (done) {
					done(false, "Join a crew on the Crew page to use crew chat.");
				}
				return undefined;
			}
			sendOn(channel, text, done);
		} else if (where === "friends") {
			if (refs.friends === undefined) {
				if (done) {
					done(false, "Friends chat is still connecting.");
				}
				return undefined;
			}
			sendOn(refs.friends, text, done);
		} else if (where === "whispers") {
			const target = peerRef.current;
			if (target === undefined) {
				if (done) {
					done(false, "Pick a conversation, or type /w name message.");
				}
				return undefined;
			}
			openWhisper(target, text, done);
		} else {
			if (refs.server === undefined) {
				if (done) {
					done(false, "Chat is still connecting.");
				}
				return undefined;
			}
			sendOn(refs.server, text, done);
		}
	};
	const send = React.useCallback(
		(raw: unknown, done?: Done) => {
			if (!enabled) {
				if (done) {
					done(false, "Chat is disabled in this experience.");
				}
				return undefined;
			}
			const command = ChatRules.parse(ChatText.limit(raw, MAX_INPUT + 40)) as {
				kind: string;
				body?: string;
				target?: string;
			};
			const kind = command.kind;
			const finish = (ok: boolean, reason?: string) => {
				if (done) {
					done(ok, reason);
				}
			};
			if (kind === "empty") {
				finish(false, "Type a message first.");
			} else if (kind === "say") {
				sendTo(tabRef.current, ChatText.limit(command.body, MAX_INPUT), done);
			} else if (kind === "clear") {
				setMessages([systemMessage("Messages on this device were cleared.")]);
				finish(true);
			} else if (kind === "help") {
				const lines: string[] = [];
				for (const info of ChatRules.COMMANDS) {
					lines.push(info.usage);
				}
				note(
					"Shortcuts: " +
						lines.join("  ·  ") +
						". Search supports from:name and in:global. Press Up to bring back a message you sent.",
				);
				finish(true);
			} else if (kind === "w") {
				const found = ChatRules.findPlayer(command.target, rosterOf(selfId));
				if (found === undefined) {
					finish(
						false,
						command.target === undefined ? "Who should get it? /w name message" : `No one here matches "${command.target}".`,
					);
					return undefined;
				}
				openWhisper(found.userId, command.body !== undefined ? ChatText.limit(command.body, MAX_INPUT) : undefined, done);
			} else if (kind === "r") {
				const target = lastWhisperRef.current;
				if (target === undefined) {
					finish(false, "No whisper to reply to yet.");
					return undefined;
				}
				if (command.body === undefined) {
					setPeer(target);
					finish(true);
					return undefined;
				}
				openWhisper(target, ChatText.limit(command.body, MAX_INPUT), done);
			} else if (kind === "g" || kind === "s" || kind === "f" || kind === "c") {
				const where = kind === "g" ? "global" : kind === "s" ? "server" : kind === "c" ? "crew" : "friends";
				if (command.body === undefined) {
					setTabState(where);
					finish(true);
					return undefined;
				}
				sendTo(where, ChatText.limit(command.body, MAX_INPUT), done);
			} else if (kind === "mute" || kind === "unmute") {
				const found = ChatRules.findPlayer(command.target, rosterOf(selfId));
				if (found === undefined) {
					finish(false, command.target === undefined ? `Who? /${kind} name` : `No one here matches "${command.target}".`);
					return undefined;
				}
				setMute(found.userId, kind === "mute");
				note(kind === "mute" ? `${found.displayName} is muted on this device.` : `${found.displayName} can be heard again.`);
				finish(true);
			} else {
				finish(false, "Unknown shortcut. Type /help to see the list.");
			}
		},
		[enabled],
	);
	const clear = React.useCallback(() => {
		setMessages([systemMessage("Messages on this device were cleared.")]);
	}, []);
	const suggest = React.useCallback((draft: unknown) => ChatRules.suggest(draft, rosterOf(selfId), 5), []);
	let unread = 0;
	for (const key of TAB_KEYS) {
		unread += unreadByTab[key] ?? 0;
	}
	let visible = messages;
	if (next(muted)[0] !== undefined) {
		visible = [];
		for (const record of messages) {
			if (!muted[record.userId]) {
				visible.push(record);
			}
		}
	}
	let peerName: string | undefined;
	if (peer !== undefined) {
		for (const entry of whispers) {
			if (entry.userId === peer) {
				peerName = entry.displayName;
			}
		}
	}
	const placeholder =
		tab === "whispers"
			? peerName !== undefined
				? `Whisper ${peerName}...`
				: "Type /w name to start a whisper"
			: tab === "global"
				? `Message every server (one every ${ChatRules.GLOBAL_COOLDOWN}s)...`
				: `Message ${CHANNEL_LABEL[tab] ?? "this server"}... (/ for shortcuts)`;
	const prefs = settings as { ChatShowGlobal?: number; ChatTextSize?: unknown } | undefined;
	return {
		messages: visible,
		unread,
		unreadByTab,
		connected,
		tab,
		setTab,
		peer,
		setPeer,
		whispers,
		muted,
		setMute,
		openWhisper,
		send,
		clear,
		suggest,
		placeholder,
		focusRequest,
		requestFocus,
		// Social settings the page applies: global chat in the All tab, and message text size
		showGlobal: !typeIs(prefs, "table") || prefs.ChatShowGlobal === undefined || prefs.ChatShowGlobal >= 0.5,
		textScale:
			typeIs(prefs, "table") && typeIs(prefs.ChatTextSize, "number") ? 0.85 + prefs.ChatTextSize * 0.45 : 1.075,
	};
}

export { useGameChat };

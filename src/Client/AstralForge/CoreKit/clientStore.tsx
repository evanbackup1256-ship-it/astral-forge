import React from "@rbxts/react";
import { Session } from "../state";
import * as SeenHints from "../../../Shared/AstralForge/Shared/SeenHints";
import { Rodux, RoduxStore } from "../vendor";

export interface BootStatus {
	marks: Record<string, boolean>;
	ready: boolean;
	progress: number;
	reducedMotion: boolean;
}

const EMPTY_BOOT_STATUS: BootStatus = {
	marks: {
		bridge: false,
		remotes: false,
		state: false,
		audio: false,
		assets: false,
		fonts: false,
		modules: false,
		shell: false,
		mail: false,
		research: false,
		forge: false,
		trade: false,
		boosts: false,
		settings: false,
		mobile: false,
	},
	ready: false,
	progress: 0,
	reducedMotion: false,
};

export interface ClientState {
	session?: Session;
	visit?: unknown;
	navigation: { page: string };
	boot: { status: BootStatus; visible: boolean };
	domain: { busy: boolean; overlay?: unknown };
}

const INITIAL_STATE: ClientState = {
	navigation: { page: "Overview" },
	boot: { status: EMPTY_BOOT_STATUS, visible: true },
	domain: { busy: false },
};

type Payload = Record<string, unknown>;

function optimisticSession(session: Session | undefined, action: string, payload: Payload, gameVersion?: string): Session | undefined {
	if (session === undefined) {
		return undefined;
	}
	if (action === "SetSetting") {
		const settings = { ...session.Settings };
		const batch = payload.Values;
		if (typeIs(batch, "table")) {
			for (const [key, value] of pairs(batch as Record<string, unknown>)) {
				if (typeIs(value, "number")) {
					settings[key] = math.clamp(value, 0, 1);
				}
			}
			return { ...session, Settings: settings };
		}
		if (typeIs(payload.Key, "string") && typeIs(payload.Value, "number")) {
			settings[payload.Key] = payload.Value;
			return { ...session, Settings: settings };
		}
	}
	if (action === "SetMobileLayout" && typeIs(payload.Desktop, "string")) {
		return { ...session, Flags: { ...session.Flags, DesktopLayout: payload.Desktop } };
	}
	if (action === "SetMobileLayout" && typeIs(payload.Pins, "table")) {
		return { ...session, Flags: { ...session.Flags, MobileTabPins: payload.Pins } };
	}
	if (action === "SetMobileLayout" && typeIs(payload.Values, "table")) {
		return { ...session, Settings: { ...session.Settings, ...(payload.Values as Record<string, unknown>) } };
	}
	if (action === "MarkHintSeen" && typeIs(payload.Id, "string")) {
		const seen = SeenHints.normalizeSeenHints(session.Flags?.SeenHints);
		if (SeenHints.isHintId(payload.Id) && !seen.includes(payload.Id)) {
			seen.push(payload.Id);
		}
		return { ...session, Flags: { ...session.Flags, SeenHints: seen } };
	}
	if (action === "SetTutorialStep" && typeIs(payload.Step, "number")) {
		return { ...session, Flags: { ...session.Flags, TutorialStep: math.max(1, math.floor(payload.Step)) } };
	}
	if (action === "ReplayTutorial") {
		return { ...session, Flags: { ...session.Flags, TutorialDone: false, TutorialStep: 1 } };
	}
	if (action === "CompleteTutorial") {
		return { ...session, Flags: { ...session.Flags, TutorialDone: true } };
	}
	if (action === "DismissRelease") {
		return { ...session, Flags: { ...session.Flags, LastSeenVersion: gameVersion ?? session.Game.Version } };
	}
	if (action === "OpenRelease") {
		return { ...session, Flags: { ...session.Flags, LastSeenVersion: "" } };
	}
	if (action === "ReadStoryChapter" && typeIs(payload.Id, "string") && session.Story !== undefined) {
		return {
			...session,
			Story: session.Story.map((chapter) => (chapter.Id === payload.Id ? { ...chapter, Read: true } : chapter)),
		};
	}
	if (action === "ReadMail" && typeIs(payload.Id, "string") && session.Mailbox !== undefined) {
		let newlyRead = false;
		const messages = session.Mailbox.Messages.map((message) => {
			if (message.Id !== payload.Id || message.Read) {
				return message;
			}
			newlyRead = true;
			return { ...message, Read: true };
		});
		return {
			...session,
			Mailbox: { Messages: messages, Unread: math.max(0, session.Mailbox.Unread - (newlyRead ? 1 : 0)) },
		};
	}
	if (
		action === "SetAutoForge" &&
		session.AutoForge !== undefined &&
		typeIs(payload.Enabled, "boolean") &&
		typeIs(payload.MachineId, "string") &&
		typeIs(payload.Reserve, "number")
	) {
		return {
			...session,
			AutoForge: { ...session.AutoForge, Enabled: payload.Enabled, MachineId: payload.MachineId, Reserve: payload.Reserve },
		};
	}
	if (action === "RouteLabPower" && session.Lab !== undefined && typeIs(payload.Channel, "string") && typeIs(payload.Delta, "number")) {
		const routing = { ...session.Lab.Routing };
		const current = routing[payload.Channel] ?? 0;
		const wanted = math.floor(payload.Delta);
		const actual = wanted > 0 ? math.min(wanted, session.Lab.AvailableCells) : -math.min(-wanted, current);
		routing[payload.Channel] = math.max(0, current + actual);
		return {
			...session,
			Lab: {
				...session.Lab,
				Routing: routing,
				AvailableCells: math.clamp(session.Lab.AvailableCells - actual, 0, session.Lab.TotalCells),
			},
		};
	}
	if (action === "SetAnomalyChannel" && session.Anomaly !== undefined && typeIs(payload.Id, "string")) {
		return { ...session, Anomaly: { ...session.Anomaly, Channel: payload.Id } };
	}
	if (action === "ClaimAnomalyDirective" && session.Anomaly !== undefined && typeIs(payload.Id, "string")) {
		let changed = false;
		const directives = session.Anomaly.Directives.map((directive) => {
			if (directive.Id !== payload.Id || directive.Claimed || directive.Progress < directive.Target) {
				return directive;
			}
			changed = true;
			return { ...directive, Claimed: true };
		});
		return changed ? { ...session, Anomaly: { ...session.Anomaly, Directives: directives } } : session;
	}
	if (action === "ClaimAnomalyMilestone" && session.Anomaly !== undefined && typeIs(payload.Tier, "number")) {
		const anomaly = session.Anomaly;
		let changed = false;
		const milestones = anomaly.Milestones.map((milestone) => {
			if (milestone.Tier !== payload.Tier || milestone.Claimed || anomaly.Stabilizations < milestone.Required) {
				return milestone;
			}
			changed = true;
			return { ...milestone, Claimed: true };
		});
		return changed ? { ...session, Anomaly: { ...anomaly, Milestones: milestones } } : session;
	}
	if (action === "CollectVault") {
		return { ...session, Vault: 0 };
	}
	if (action === "SelectZone" && typeIs(payload.Id, "number")) {
		return { ...session, CurrentZone: math.max(1, math.floor(payload.Id)) };
	}
	if (action === "EquipTitle" && typeIs(payload.Id, "string") && session.Command !== undefined) {
		const selected = session.Command.Titles.find((title) => title.Id === payload.Id);
		if (selected === undefined || !selected.Unlocked || selected.Equipped) {
			return session;
		}
		return {
			...session,
			Command: {
				...session.Command,
				Titles: session.Command.Titles.map((title) => ({ ...title, Equipped: title.Id === payload.Id })),
			},
		};
	}
	return session;
}

export type ClientAction =
	| { type: "session/snapshot"; snapshot: Session }
	| { type: "session/patch"; patch: Partial<Session> }
	| { type: "session/optimistic"; action: string; payload: Payload; gameVersion?: string }
	| { type: "session/visit"; visit: unknown }
	| { type: "navigation/open"; page: string }
	| { type: "boot/status"; status: BootStatus }
	| { type: "boot/visible"; visible: boolean }
	| { type: "domain/overlay"; overlay: unknown }
	| { type: "domain/busy"; busy: boolean }
	| { type: "runtime/reset" };

function clientReducer(state: ClientState = INITIAL_STATE, action: ClientAction): ClientState {
	switch (action.type) {
		case "session/snapshot": {
			if (state.session !== undefined) {
				if (action.snapshot.Revision < state.session.Revision) {
					return state;
				}
				if (action.snapshot.Revision === state.session.Revision && action.snapshot.SnapshotId < state.session.SnapshotId) {
					return state;
				}
			}
			return { ...state, session: action.snapshot, visit: action.snapshot.Visit };
		}
		case "session/patch": {
			if (state.session === undefined) {
				return state;
			}
			const patch = action.patch;
			if (typeIs(patch, "table")) {
				const patchRevision = tonumber(patch.Revision);
				const patchSnapshot = tonumber(patch.SnapshotId);
				if (patchRevision !== undefined && patchRevision < state.session.Revision) {
					return state;
				}
				if (
					patchRevision !== undefined &&
					patchRevision === state.session.Revision &&
					patchSnapshot !== undefined &&
					patchSnapshot < state.session.SnapshotId
				) {
					return state;
				}
			}
			return { ...state, session: { ...state.session, ...action.patch } };
		}
		case "session/optimistic": {
			const session = optimisticSession(state.session, action.action, action.payload, action.gameVersion);
			return session === state.session ? state : { ...state, session };
		}
		case "session/visit":
			return state.visit === action.visit ? state : { ...state, visit: action.visit };
		case "navigation/open":
			return state.navigation.page === action.page ? state : { ...state, navigation: { page: action.page } };
		case "boot/status":
			return state.boot.status === action.status ? state : { ...state, boot: { ...state.boot, status: action.status } };
		case "boot/visible":
			return state.boot.visible === action.visible ? state : { ...state, boot: { ...state.boot, visible: action.visible } };
		case "domain/overlay":
			return state.domain.overlay === action.overlay ? state : { ...state, domain: { ...state.domain, overlay: action.overlay } };
		case "domain/busy":
			return state.domain.busy === action.busy ? state : { ...state, domain: { ...state.domain, busy: action.busy } };
		case "runtime/reset":
			return INITIAL_STATE;
	}
	return state;
}

export type ClientStore = RoduxStore<ClientState, ClientAction>;

let activeClientStore: ClientStore | undefined;

export const ClientActions = {
	setSnapshot: (snapshot: Session): ClientAction => ({ type: "session/snapshot", snapshot }),
	patchSession: (patch: Partial<Session>): ClientAction => ({ type: "session/patch", patch }),
	applyOptimistic: (action: string, payload: Payload, gameVersion?: string): ClientAction => ({
		type: "session/optimistic",
		action,
		payload,
		gameVersion,
	}),
	setVisit: (visit: unknown): ClientAction => ({ type: "session/visit", visit }),
	navigate: (page: string): ClientAction => ({ type: "navigation/open", page }),
	setBootStatus: (status: BootStatus): ClientAction => ({ type: "boot/status", status }),
	setBootVisible: (visible: boolean): ClientAction => ({ type: "boot/visible", visible }),
	setDomainOverlay: (overlay: unknown): ClientAction => ({ type: "domain/overlay", overlay }),
	setDomainBusy: (busy: boolean): ClientAction => ({ type: "domain/busy", busy }),
	reset: (): ClientAction => ({ type: "runtime/reset" }),
};

export function createClientStore(): ClientStore {
	activeClientStore?.destruct();
	const store = Rodux.Store.new(clientReducer, INITIAL_STATE);
	activeClientStore = store;
	return store;
}

export function getActiveClientStore(): ClientStore | undefined {
	return activeClientStore;
}

export function destroyClientStore(store: ClientStore) {
	if (activeClientStore === store) {
		activeClientStore = undefined;
	}
	store.destruct();
}

const ClientStoreContext = React.createContext<ClientStore | undefined>(undefined);

export function ClientStoreProvider(props: { store: ClientStore; children?: React.ReactNode }) {
	return <ClientStoreContext.Provider value={props.store}>{props.children}</ClientStoreContext.Provider>;
}

export function useClientStore(): ClientStore {
	const store = React.useContext(ClientStoreContext);
	if (store === undefined) {
		error("ClientStoreProvider is missing", 2);
	}
	return store;
}

export function useClientDispatch() {
	const store = useClientStore();
	return React.useCallback((action: ClientAction) => store.dispatch(action), [store]);
}

export function useClientSelector<T>(selector: (state: ClientState) => T, equal: (left: T, right: T) => boolean = (left, right) => left === right): T {
	const store = useClientStore();
	const selectorRef = React.useRef(selector);
	const equalRef = React.useRef(equal);
	selectorRef.current = selector;
	equalRef.current = equal;
	const [selected, setSelected] = React.useState(() => selector(store.getState()));
	const selectedRef = React.useRef(selected);
	selectedRef.current = selected;
	React.useEffect(() => {
		const sync = (nextState: ClientState) => {
			const selectedNext = selectorRef.current(nextState);
			if (equalRef.current(selectedRef.current, selectedNext)) {
				return;
			}
			selectedRef.current = selectedNext;
			setSelected(() => selectedNext);
		};
		sync(store.getState());
		const connection = store.changed.connect(sync);
		return () => connection.disconnect();
	}, [store]);
	return selected;
}

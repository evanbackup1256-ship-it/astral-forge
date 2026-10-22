// The client store is four slices, each with its own initial state and reducer. The root reducer
// hands every action to every slice and only builds a new root table when a slice changed.
import { Session } from "../../state";
import { applyOptimistic, Payload } from "./optimistic";

export interface BootStatus {
	marks: Record<string, boolean>;
	ready: boolean;
	progress: number;
	reducedMotion: boolean;
}

const BOOT_MARKS = [
	"bridge", "remotes", "state", "audio", "assets", "fonts", "modules", "shell",
	"mail", "research", "forge", "trade", "boosts", "settings", "mobile",
] as const;

function emptyBootStatus(): BootStatus {
	const marks: Record<string, boolean> = {};
	for (const mark of BOOT_MARKS) {
		marks[mark] = false;
	}
	return { marks, ready: false, progress: 0, reducedMotion: false };
}

export interface SessionSlice {
	session?: Session;
	visit?: unknown;
}
export interface NavigationSlice {
	page: string;
}
export interface BootSlice {
	status: BootStatus;
	visible: boolean;
}
export interface DomainSlice {
	busy: boolean;
	overlay?: unknown;
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

// A snapshot or patch older than what we hold is dropped: revision first, snapshot id breaks ties.
function isStale(current: Session, revision: number | undefined, snapshotId: number | undefined): boolean {
	if (revision === undefined) {
		return false;
	}
	if (revision < current.Revision) {
		return true;
	}
	return revision === current.Revision && snapshotId !== undefined && snapshotId < current.SnapshotId;
}

function sessionSlice(state: SessionSlice, action: ClientAction): SessionSlice {
	switch (action.type) {
		case "session/snapshot": {
			const snapshot = action.snapshot;
			if (state.session !== undefined && isStale(state.session, snapshot.Revision, snapshot.SnapshotId)) {
				return state;
			}
			return { session: snapshot, visit: snapshot.Visit };
		}
		case "session/patch": {
			if (state.session === undefined) {
				return state;
			}
			const patch = action.patch;
			if (typeIs(patch, "table") && isStale(state.session, tonumber(patch.Revision), tonumber(patch.SnapshotId))) {
				return state;
			}
			return { ...state, session: { ...state.session, ...patch } };
		}
		case "session/optimistic": {
			const session = applyOptimistic(state.session, action.action, action.payload, action.gameVersion);
			return session === state.session ? state : { ...state, session };
		}
		case "session/visit":
			return state.visit === action.visit ? state : { ...state, visit: action.visit };
	}
	return state;
}

function navigationSlice(state: NavigationSlice, action: ClientAction): NavigationSlice {
	return action.type === "navigation/open" && state.page !== action.page ? { page: action.page } : state;
}

function bootSlice(state: BootSlice, action: ClientAction): BootSlice {
	if (action.type === "boot/status" && state.status !== action.status) {
		return { ...state, status: action.status };
	}
	if (action.type === "boot/visible" && state.visible !== action.visible) {
		return { ...state, visible: action.visible };
	}
	return state;
}

function domainSlice(state: DomainSlice, action: ClientAction): DomainSlice {
	if (action.type === "domain/overlay" && state.overlay !== action.overlay) {
		return { ...state, overlay: action.overlay };
	}
	if (action.type === "domain/busy" && state.busy !== action.busy) {
		return { ...state, busy: action.busy };
	}
	return state;
}

// The root keeps its historical shape (session and visit at the top) so every existing selector
// reads the same paths.
export interface ClientState {
	session?: Session;
	visit?: unknown;
	navigation: NavigationSlice;
	boot: BootSlice;
	domain: DomainSlice;
}

export function initialClientState(): ClientState {
	return {
		navigation: { page: "Overview" },
		boot: { status: emptyBootStatus(), visible: true },
		domain: { busy: false },
	};
}

export const INITIAL_STATE: ClientState = initialClientState();

export function clientReducer(state: ClientState = INITIAL_STATE, action: ClientAction): ClientState {
	if (action.type === "runtime/reset") {
		return INITIAL_STATE;
	}
	const sessionIn: SessionSlice = { session: state.session, visit: state.visit };
	const sessionOut = sessionSlice(sessionIn, action);
	const navigation = navigationSlice(state.navigation, action);
	const boot = bootSlice(state.boot, action);
	const domain = domainSlice(state.domain, action);
	if (sessionOut === sessionIn && navigation === state.navigation && boot === state.boot && domain === state.domain) {
		return state;
	}
	return { session: sessionOut.session, visit: sessionOut.visit, navigation, boot, domain };
}

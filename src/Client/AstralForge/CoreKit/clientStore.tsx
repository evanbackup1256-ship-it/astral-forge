// Client store: Rodux store over the slices in ./store, plus the React provider and hooks.
// Slices and optimistic edits live in store/slices.ts and store/optimistic.ts; named reads live in
// store/selectors.ts; memoised derived reads use store/memo.ts.
import React from "@rbxts/react";
import { Session } from "../state";
import { Rodux, RoduxStore } from "../vendor";
import { ClientAction, ClientState, INITIAL_STATE, clientReducer } from "./store/slices";
import { Payload } from "./store/optimistic";

export type { BootStatus, ClientAction, ClientState } from "./store/slices";
export { createSelector, shallowEqual } from "./store/memo";
export * as ClientSelectors from "./store/selectors";

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

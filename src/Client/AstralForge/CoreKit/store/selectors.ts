// Named reads of the client store. Components should prefer these over inline lambdas so the
// paths into the store live in one place.
import { Session } from "../../state";
import { ClientState } from "./slices";

export const selectSession = (state: ClientState): Session | undefined => state.session;
export const selectVisit = (state: ClientState) => state.visit;
export const selectPage = (state: ClientState) => state.navigation.page;
export const selectBootStatus = (state: ClientState) => state.boot.status;
export const selectBootVisible = (state: ClientState) => state.boot.visible;
export const selectDomainOverlay = (state: ClientState) => state.domain.overlay;
export const selectDomainBusy = (state: ClientState) => state.domain.busy;
export const selectSettings = (state: ClientState) => state.session?.Settings;
export const selectFlags = (state: ClientState) => state.session?.Flags;

export function selectSessionField<K extends keyof Session>(key: K) {
	return (state: ClientState): Session[K] | undefined => state.session?.[key];
}

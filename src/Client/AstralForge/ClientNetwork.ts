// Client side of the typed wire contract (Shared/Network.ts). The handlers are created only
// when NetworkController.connect() runs, after index.client has seen the server's bridge
// folder, so an early server failure shows the boot failure screen instead of a hang.
import { GlobalEvents, GlobalFunctions } from "../../Shared/AstralForge/Shared/Network";

export function createClientNetwork() {
	return {
		events: GlobalEvents.createClient({}),
		functions: GlobalFunctions.createClient({}),
	};
}

export type ClientNetwork = ReturnType<typeof createClientNetwork>;
/** The request function: `request.invoke(action, payload).expect()` yields for the reply. */
export type RequestFunction = ClientNetwork["functions"]["request"];
/** A server push carrying one payload table (state, toast, effect). */
export type PushEvent = ClientNetwork["events"]["effect"];
export type ShutdownEvent = ClientNetwork["events"]["shutdown"];

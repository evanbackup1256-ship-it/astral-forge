// Client side of the typed wire contract (Shared/Network.ts).
import { GlobalEvents, GlobalFunctions } from "../../Shared/AstralForge/Shared/Network";

export const ClientEvents = GlobalEvents.createClient({});
export const ClientFunctions = GlobalFunctions.createClient({});

/** The request function: `request.invoke(action, payload).expect()` yields for the reply. */
export type RequestFunction = typeof ClientFunctions.request;
/** A server push carrying one payload table (state, toast, effect). */
export type PushEvent = typeof ClientEvents.effect;

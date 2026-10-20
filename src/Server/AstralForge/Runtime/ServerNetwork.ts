// Server side of the typed wire contract. Imported by the runtime services and gameplay
// services that push to clients.
import { GlobalEvents, GlobalFunctions } from "../../../Shared/AstralForge/Shared/Network";

export const ServerEvents = GlobalEvents.createServer({});
export const ServerFunctions = GlobalFunctions.createServer({});

/** A server-to-client push carrying one untyped payload table (state, toast, effect). */
export type PayloadEvent = typeof ServerEvents.effect;

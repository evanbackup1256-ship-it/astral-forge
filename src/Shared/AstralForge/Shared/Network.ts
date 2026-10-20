// Typed wire contract between server and client (@flamework/networking).
// Payload shapes are the same ones the raw remotes carried: one request function taking
// (action, payload) and four server-to-client pushes. Flamework's incoming guard drops requests
// whose `action` is not a string; RemoteFirewall and the rate limits still run in the handler.
import { Networking } from "@flamework/networking";

export interface ShutdownPacket {
	Phase: string;
	Message: string;
	StartedAt: number;
	Revision: number;
}

interface ServerToClientEvents {
	state(snapshot: unknown): void;
	toast(payload: unknown): void;
	effect(payload: unknown): void;
	shutdown(packet: ShutdownPacket): void;
}

interface ClientToServerFunctions {
	request(action: string, payload?: unknown): unknown;
}

export const GlobalEvents = Networking.createEvent<{}, ServerToClientEvents>();
export const GlobalFunctions = Networking.createFunction<ClientToServerFunctions, {}>();

// Typed view of the lazy service registry (Services/ServerServices). Only the members the
// Flamework runtime services touch are typed; the registry itself still builds on demand.
import { PayloadEvent } from "./ServerNetwork";
import type { FluxSurgeService } from "../Services/FluxSurgeService";
import ServerServices = require("../Services/ServerServices");

export interface GameServiceLike {
	_effect: PayloadEvent;
	_toastPlayer(player: Player, title: unknown, body: unknown, kind: unknown): void;
	_snapshot(player: Player): unknown;
	Start(): void;
	Shutdown(): void;
	ShowRelease(player: Player): LuaTuple<[boolean, unknown]>;
	GrantStudioWheelSpins(player: Player, amount: unknown): LuaTuple<[boolean, unknown, unknown]>;
	GrantStudioMoney(player: Player): LuaTuple<[boolean, unknown, unknown]>;
}
export interface Startable {
	Start(): void;
	Destroy(): void;
}
export interface DataServiceLike {
	Shutdown(): void;
	StartAutosave(seconds: unknown): void;
}
export interface ServicesShape {
	GameService: {
		new: (
			this: void,
			dataService: DataServiceLike,
			worldService: unknown,
			fluxSurgeService: FluxSurgeService,
			remotes: Record<string, unknown>,
		) => GameServiceLike;
	};
	WorldService: { new: (this: void) => Startable };
}

/** Factory modules not yet converted to services; they return their class (with .new). */
export type DataServiceClass = { new: (this: void) => DataServiceLike };
export type AdminServiceClass = { new: (this: void, dataService: DataServiceLike) => unknown };
export type CharacterIntegrityClass = { new: (this: void) => Startable };

export const Registry = ServerServices as unknown as ServicesShape;

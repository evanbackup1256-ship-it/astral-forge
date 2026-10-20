// Typed view of the lazy service registry (Services/ServerServices). Only the members the
// Flamework runtime services touch are typed; the registry itself still builds on demand.
import ModuleLog = require("../ModuleLog");
import ServerServices = require("../Services/ServerServices");

export interface GameServiceLike {
	_effect: RemoteEvent;
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
	ServerTelemetry: Parameters<typeof ModuleLog.AttachTelemetry>[0];
	DataService: { new: (this: void) => DataServiceLike };
	AdminService: { new: (this: void, dataService: DataServiceLike) => unknown };
	GameService: {
		new: (
			this: void,
			dataService: DataServiceLike,
			worldService: unknown,
			fluxSurgeService: unknown,
			remotes: Record<string, unknown>,
		) => GameServiceLike;
	};
	WorldService: { new: (this: void) => Startable };
	FluxSurgeService: {
		new: (
			this: void,
			toast: (player: Player, title: unknown, body: unknown, kind: unknown) => void,
			effect: (player: Player, payload: unknown) => void,
		) => unknown;
	};
	Security: { new: (this: void) => Startable };
	CharacterIntegrity: { new: (this: void) => Startable };
}

export const Registry = ServerServices as unknown as ServicesShape;

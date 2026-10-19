import { ModuleLogApi, req } from "./LuaInterop";

interface ValueBox {
	Value: unknown;
}

type Component = (this: void, data: ValueBox) => unknown;

interface MatterWorld {
	spawn(...components: unknown[]): number;
	contains(entity: number): boolean;
	despawn(entity: number): void;
	clear(): void;
	query(...components: Component[]): IterableFunction<LuaTuple<[number, ValueBox, ValueBox]>>;
}

interface MatterLoop {
	trackErrors: boolean;
	scheduleSystems(systems: unknown[]): void;
	begin(events: Record<string, RBXScriptSignal>): Record<string, RBXScriptConnection>;
}

interface MatterLib {
	component: (this: void, name: string) => Component;
	useDeltaTime: (this: void) => number;
	World: { new: (this: void) => MatterWorld };
	Loop: { new: (this: void, world: MatterWorld, service: unknown) => MatterLoop };
}

interface TickingService {
	_tickPlayer(player: unknown, runtime: unknown, deltaTime: number): void;
}

export = () => {
	const ReplicatedStorage = game.GetService("ReplicatedStorage");

	const ModuleLog = req<ModuleLogApi>(script.Parent!.Parent!.WaitForChild("ModuleLog"));

	// If Argon/Rojo does not sync the rbxts include tree, Matter will be unavailable.
	// Wrap the entire require chain so the server can still boot without the ECS runtime.
	const [matterOk, matterResult] = pcall(() => {
		const include = ReplicatedStorage.FindFirstChild("rbxts_include");
		assert(include, "Matter requires ReplicatedStorage.rbxts_include");
		const nodeModules = include.FindFirstChild("node_modules");
		assert(nodeModules, "Matter requires the replicated node_modules folder");
		const rbxts = nodeModules.FindFirstChild("@rbxts");
		assert(rbxts, "Matter requires the replicated @rbxts folder");
		const matterPackage = rbxts.FindFirstChild("matter");
		assert(matterPackage, "@rbxts/matter is not replicated; run npm install and restart Rojo");
		const matterModule = matterPackage.FindFirstChild("lib");
		assert(matterModule && matterModule.IsA("ModuleScript"), "@rbxts/matter/lib is not a ModuleScript");

		return ModuleLog.Require(matterModule, "Matter ECS");
	});

	// No-op fallback: GameService nil-guards and empty implementations let the rest of the server start.
	if (!matterOk) {
		ModuleLog.Warn("Matter", "Matter ECS unavailable; runtime disabled. " + tostring(matterResult));

		class NoOpMatterRuntime {
			constructor(_service?: unknown) {}

			SpawnPlayer(_player: Player, _runtime: unknown, _profile: unknown): number {
				return 0;
			}

			Despawn(_entity: number): void {}

			Start(): void {}

			Step(): void {}

			Stop(): void {}
		}

		return table.freeze(NoOpMatterRuntime);
	}

	const Matter = matterResult as MatterLib;

	const PlayerComponent = Matter.component("AstralForge.Player");
	const RuntimeComponent = Matter.component("AstralForge.Runtime");

	const playerProductionSystem = (world: MatterWorld, service: TickingService): void => {
		const deltaTime = Matter.useDeltaTime();
		for (const [, playerState, runtimeState] of world.query(PlayerComponent, RuntimeComponent)) {
			service._tickPlayer(playerState.Value, runtimeState.Value, deltaTime);
		}
	};

	const playerProduction = {
		system: playerProductionSystem,
		priority: 5,
	};

	class MatterRuntime {
		World: MatterWorld;
		_service: unknown;
		_stepEvent: BindableEvent;
		_loop: MatterLoop;
		_connections?: Record<string, RBXScriptConnection>;
		_scheduled: boolean;

		constructor(service: unknown) {
			this.World = Matter.World.new();
			this._service = service;
			this._stepEvent = new Instance("BindableEvent");
			this._loop = Matter.Loop.new(this.World, service);
			this._loop.trackErrors = false;
			this._connections = undefined;
			this._scheduled = false;
		}

		SpawnPlayer(player: Player, runtime: unknown, _profile: unknown): number {
			return this.World.spawn(PlayerComponent({ Value: player }), RuntimeComponent({ Value: runtime }));
		}

		Despawn(entity: number): void {
			if (this.World.contains(entity)) {
				this.World.despawn(entity);
			}
		}

		Start(): void {
			if (this._connections) {
				return;
			}
			if (!this._scheduled) {
				this._loop.scheduleSystems([playerProduction]);
				this._scheduled = true;
			}
			this._connections = this._loop.begin({
				default: this._stepEvent.Event,
			});
			ModuleLog.Info("tick", "5 Hz loop started");
		}

		Step(): void {
			if (this._connections) {
				this._stepEvent.Fire();
			}
		}

		Stop(): void {
			if (this._connections) {
				for (const [, connection] of pairs(this._connections)) {
					connection.Disconnect();
				}
				table.clear(this._connections);
				this._connections = undefined;
			}
			this.World.clear();
		}
	}

	return table.freeze(MatterRuntime);
};

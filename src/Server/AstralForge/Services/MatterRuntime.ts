import { Service } from "@flamework/core";
import ModuleLog = require("../ModuleLog");

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

const ReplicatedStorage = game.GetService("ReplicatedStorage");

// @rbxts/matter is mapped into rbxts_include by default.project.json; a missing package is a
// broken build and fails the boot loudly.
const Matter = ModuleLog.Require(
	ReplicatedStorage.WaitForChild("rbxts_include")
		.WaitForChild("node_modules")
		.WaitForChild("@rbxts")
		.WaitForChild("matter")
		.WaitForChild("lib") as ModuleScript,
	"Matter ECS",
) as MatterLib;

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

/** Matter ECS world that drives per-player production at 5 Hz for GameService. */
@Service({ loadOrder: 1 })
export class MatterRuntime {
	readonly World: MatterWorld = Matter.World.new();
	private readonly stepEvent = new Instance("BindableEvent");
	private loop?: MatterLoop;
	private connections?: Record<string, RBXScriptConnection>;

	SpawnPlayer(player: Player, runtime: unknown, _profile: unknown): number {
		return this.World.spawn(PlayerComponent({ Value: player }), RuntimeComponent({ Value: runtime }));
	}

	Despawn(entity: number): void {
		if (this.World.contains(entity)) {
			this.World.despawn(entity);
		}
	}

	/** Starts the loop; systems receive the ticking service (GameService) as their argument. */
	Start(service: TickingService): void {
		if (this.connections) {
			return;
		}
		if (this.loop === undefined) {
			const loop = Matter.Loop.new(this.World, service);
			loop.trackErrors = false;
			loop.scheduleSystems([playerProduction]);
			this.loop = loop;
		}
		this.connections = this.loop.begin({
			default: this.stepEvent.Event,
		});
		ModuleLog.Info("tick", "server tick loop started at 5 Hz");
	}

	Step(): void {
		if (this.connections) {
			this.stepEvent.Fire();
		}
	}

	Stop(): void {
		if (this.connections) {
			for (const [, connection] of pairs(this.connections)) {
				connection.Disconnect();
			}
			table.clear(this.connections);
			this.connections = undefined;
		}
		this.World.clear();
	}
}

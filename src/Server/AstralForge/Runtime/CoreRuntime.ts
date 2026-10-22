// Server runtime orchestration. Every core system is a Flamework @Service built by injection;
// this service runs their boot steps in OnInit and their runtime start in OnStart, and
// registers their shutdown order with the bridge.
import { OnInit, OnStart, Service } from "@flamework/core";
import { RemoteBridge } from "./RemoteBridge";
import { Security } from "../Services/Security/Security";
import { DataService } from "../Services/DataService";
import { AdminService } from "../Services/AdminService";
import { WorldService } from "../Services/WorldService";
import { GameService } from "../Services/GameService";
import { ConvergenceService } from "../Services/ConvergenceService";
import { BootGraph } from "./BootGraph";
import CharacterIntegrityModule = require("../Services/Security/CharacterIntegrity");

interface Startable {
	Start(): void;
	Destroy(): void;
}
/** CharacterIntegrity is a factory module that returns its class (with .new). */
type CharacterIntegrityClass = { new: (this: void) => Startable };

@Service({ loadOrder: 5 })
export class CoreRuntime implements OnInit, OnStart {
	private integrity!: Startable;
	constructor(
		private readonly bridge: RemoteBridge,
		private readonly data: DataService,
		private readonly admin: AdminService,
		private readonly world: WorldService,
		private readonly security: Security,
		private readonly gameplay: GameService,
		private readonly convergence: ConvergenceService,
	) {}
	onInit() {
		const bridge = this.bridge;
		const CharacterIntegrity = CharacterIntegrityModule() as unknown as CharacterIntegrityClass;
		// construction order comes from these dependencies (ties keep the order written here);
		// each step registers its own teardown once built (lower order closes first), so a
		// failed boot only tears down what exists
		const graph = new BootGraph()
			.add("player data construction", [], () => {
				this.data.build();
				bridge.onClose(4, "data service", () => this.data.Shutdown());
			})
			.add("administration construction", ["player data construction"], () => this.admin.build())
			.add("integrity construction", ["player data construction"], () => {
				this.integrity = CharacterIntegrity.new();
				bridge.onClose(2, "security pipeline", () => this.security.Destroy());
				bridge.onClose(1, "character integrity", () => this.integrity.Destroy());
			})
			.add("convergence construction", ["player data construction"], () => this.convergence.build())
			.add(
				"gameplay construction",
				["player data construction", "administration construction", "integrity construction", "convergence construction"],
				() => {
					this.gameplay.build();
					bridge.onClose(3, "game service", () => this.gameplay.Shutdown());
				},
			);
		for (const step of graph.order()) {
			bridge.bootStep(step.name, step.run);
		}
	}
	onStart() {
		const bridge = this.bridge;
		// one phase per former runtime service, so a yielding start does not hold up the others
		bridge.startPhase(() => bridge.startStep("world start", () => this.world.Start()));
		bridge.startPhase(() => {
			bridge.startStep("security start", () => this.security.Start());
			bridge.startStep("integrity start", () => this.integrity.Start());
		});
		bridge.startPhase(() => {
			bridge.startStep("game start", () => this.gameplay.Start());
			bridge.startStep("autosave start", () => this.data.StartAutosave(bridge.gameConfig.Game.AutosaveSeconds as number));
		});
	}
}

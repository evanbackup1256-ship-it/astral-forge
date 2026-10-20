// Server runtime orchestration. Every core system is a Flamework @Service built by injection;
// this service runs their boot steps in OnInit and their runtime start in OnStart, and
// registers their shutdown order with the bridge.
import { OnInit, OnStart, Service } from "@flamework/core";
import { RemoteBridge } from "./RemoteBridge";
import { Security } from "../Services/Security";
import { DataService } from "../Services/DataService";
import { AdminService } from "../Services/AdminService";
import { WorldService } from "../Services/WorldService";
import { GameService } from "../Services/GameService";
import CharacterIntegrityModule = require("../Services/CharacterIntegrity");

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
	) {}
	onInit() {
		const bridge = this.bridge;
		bridge.bootStep("player data construction", () => this.data.build());
		bridge.onClose(4, "data service", () => this.data.Shutdown());
		bridge.bootStep("administration construction", () => this.admin.build());
		const CharacterIntegrity = CharacterIntegrityModule() as unknown as CharacterIntegrityClass;
		this.integrity = bridge.bootStep("integrity construction", () => CharacterIntegrity.new());
		bridge.onClose(2, "security pipeline", () => this.security.Destroy());
		bridge.onClose(1, "character integrity", () => this.integrity.Destroy());
		bridge.bootStep("gameplay construction", () => this.gameplay.build());
		bridge.onClose(3, "game service", () => this.gameplay.Shutdown());
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

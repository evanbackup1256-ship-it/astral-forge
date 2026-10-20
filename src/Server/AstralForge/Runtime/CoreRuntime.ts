// Flamework services wrapping the server's core systems. Construction happens in OnInit
// (ordered by loadOrder + injected dependencies), runtime start in OnStart.
import { OnInit, OnStart, Service } from "@flamework/core";
import { RemoteBridge } from "./RemoteBridge";
import { DataServiceLike, GameServiceLike, Registry, Startable } from "./ServerRegistry";

@Service({ loadOrder: 1 })
export class PlayerDataRuntime implements OnInit {
	public service!: DataServiceLike;
	constructor(private readonly bridge: RemoteBridge) {}
	onInit() {
		this.service = this.bridge.bootStep("player data construction", () => Registry.DataService.new());
		this.bridge.onClose(4, "data service", () => this.service.Shutdown());
	}
}

@Service({ loadOrder: 2 })
export class AdminRuntime implements OnInit {
	public service: unknown;
	constructor(
		private readonly bridge: RemoteBridge,
		private readonly data: PlayerDataRuntime,
	) {}
	onInit() {
		this.service = this.bridge.bootStep("administration construction", () =>
			Registry.AdminService.new(this.data.service),
		);
	}
}

@Service({ loadOrder: 2 })
export class WorldRuntime implements OnInit, OnStart {
	public service!: Startable;
	constructor(private readonly bridge: RemoteBridge) {}
	onInit() {
		this.service = this.bridge.bootStep("world construction", () => Registry.WorldService.new());
	}
	onStart() {
		this.bridge.startPhase(() => this.bridge.startStep("world start", () => this.service.Start()));
	}
}

@Service({ loadOrder: 2 })
export class FluxSurgeRuntime implements OnInit {
	public service: unknown;
	public gameService?: GameServiceLike;
	constructor(private readonly bridge: RemoteBridge) {}
	onInit() {
		this.service = this.bridge.bootStep("flux surge construction", () =>
			Registry.FluxSurgeService.new(
				(player, title, body, kind) => this.gameService?._toastPlayer(player, title, body, kind),
				(player, payload) => this.gameService?._effect.fire(player, payload),
			),
		);
	}
}

@Service({ loadOrder: 2 })
export class SecurityRuntime implements OnInit, OnStart {
	public pipeline!: Startable;
	public integrity!: Startable;
	constructor(private readonly bridge: RemoteBridge) {}
	onInit() {
		this.pipeline = this.bridge.bootStep("security construction", () => Registry.Security.new());
		this.integrity = this.bridge.bootStep("integrity construction", () => Registry.CharacterIntegrity.new());
		this.bridge.onClose(2, "security pipeline", () => this.pipeline.Destroy());
		this.bridge.onClose(1, "character integrity", () => this.integrity.Destroy());
	}
	onStart() {
		this.bridge.startPhase(() => {
			this.bridge.startStep("security start", () => this.pipeline.Start());
			this.bridge.startStep("integrity start", () => this.integrity.Start());
		});
	}
}

@Service({ loadOrder: 3 })
export class GameRuntime implements OnInit, OnStart {
	public service!: GameServiceLike;
	constructor(
		private readonly bridge: RemoteBridge,
		private readonly data: PlayerDataRuntime,
		private readonly admin: AdminRuntime,
		private readonly world: WorldRuntime,
		private readonly flux: FluxSurgeRuntime,
		private readonly security: SecurityRuntime,
	) {}
	onInit() {
		const bridge = this.bridge;
		this.service = bridge.bootStep("gameplay construction", () =>
			Registry.GameService.new(this.data.service, this.world.service, this.flux.service, {
				Security: this.security.pipeline,
				Admin: this.admin.service,
			}),
		);
		this.flux.gameService = this.service;
		bridge.onClose(3, "game service", () => this.service.Shutdown());
	}
	onStart() {
		this.bridge.startPhase(() => {
			this.bridge.startStep("game start", () => this.service.Start());
			this.bridge.startStep("autosave start", () =>
				this.data.service.StartAutosave(this.bridge.gameConfig.Game.AutosaveSeconds),
			);
		});
	}
}

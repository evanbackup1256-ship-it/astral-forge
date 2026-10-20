// Flamework services wrapping the server's core systems. Construction happens in OnInit
// (ordered by loadOrder + injected dependencies), runtime start in OnStart.
import { OnInit, OnStart, Service } from "@flamework/core";
import { FluxSurgeService } from "../Services/FluxSurgeService";
import { RemoteBridge } from "./RemoteBridge";
import {
	AdminServiceClass,
	CharacterIntegrityClass,
	DataServiceClass,
	DataServiceLike,
	GameServiceLike,
	Registry,
	Startable,
} from "./ServerRegistry";
import { ServerTelemetry } from "../Services/ServerTelemetry";
import { Security } from "../Services/Security";
import { SessionGate } from "../Services/SessionGate";
import { RemoteFirewall } from "../Services/RemoteFirewall";
import { GameAntiCheat } from "../Services/GameAntiCheat";
import { PlayerAnalytics } from "../Services/PlayerAnalytics";
import { PlayerBadges } from "../Services/PlayerBadges";
import { SpecializationService } from "../Services/SpecializationService";
import DataServiceModule = require("../Services/DataService");
import AdminServiceModule = require("../Services/AdminService");
import CharacterIntegrityModule = require("../Services/CharacterIntegrity");

@Service({ loadOrder: 1 })
export class PlayerDataRuntime implements OnInit {
	public service!: DataServiceLike;
	constructor(
		private readonly bridge: RemoteBridge,
		private readonly telemetry: ServerTelemetry,
	) {}
	onInit() {
		const DataService = DataServiceModule(this.telemetry) as unknown as DataServiceClass;
		this.service = this.bridge.bootStep("player data construction", () => DataService.new());
		this.bridge.onClose(4, "data service", () => this.service.Shutdown());
	}
}

@Service({ loadOrder: 2 })
export class AdminRuntime implements OnInit {
	public service: unknown;
	constructor(
		private readonly bridge: RemoteBridge,
		private readonly data: PlayerDataRuntime,
		private readonly telemetry: ServerTelemetry,
	) {}
	onInit() {
		const AdminService = AdminServiceModule(this.telemetry) as unknown as AdminServiceClass;
		this.service = this.bridge.bootStep("administration construction", () => AdminService.new(this.data.service));
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
export class SecurityRuntime implements OnInit, OnStart {
	public integrity!: Startable;
	constructor(
		private readonly bridge: RemoteBridge,
		public readonly pipeline: Security,
	) {}
	onInit() {
		const CharacterIntegrity = CharacterIntegrityModule() as unknown as CharacterIntegrityClass;
		this.integrity = this.bridge.bootStep("integrity construction", () => CharacterIntegrity.new());
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
		private readonly flux: FluxSurgeService,
		private readonly security: SecurityRuntime,
		private readonly session: SessionGate,
		private readonly firewall: RemoteFirewall,
		private readonly antiCheat: GameAntiCheat,
		private readonly analytics: PlayerAnalytics,
		private readonly badges: PlayerBadges,
		// GameService reads the shared Specializations rules; this service keeps them live-tuned.
		private readonly _specializations: SpecializationService,
	) {}
	onInit() {
		const bridge = this.bridge;
		this.service = bridge.bootStep("gameplay construction", () =>
			Registry.GameService.new(this.data.service, this.world.service, this.flux, {
				Security: this.security.pipeline,
				Admin: this.admin.service,
				Session: this.session,
				Firewall: this.firewall,
				AntiCheat: this.antiCheat,
				Analytics: this.analytics,
				Badges: this.badges,
			}),
		);
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

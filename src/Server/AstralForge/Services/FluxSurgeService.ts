// Server-wide Flux Surge: every IntervalSeconds production is multiplied for DurationSeconds.
// GameService ticks it and reads Multiplier/State; start and end are announced to every player.
import { Service } from "@flamework/core";
import ModuleLog = require("../ModuleLog");
import { num } from "./LuaInterop";
import GameConfig = require("../../../Shared/AstralForge/Shared/GameConfig");
import { ServerEvents } from "../Runtime/ServerNetwork";

const Players = game.GetService("Players");

interface SurgeConfigSource {
	IntervalSeconds?: unknown;
	DurationSeconds?: unknown;
	Multiplier?: unknown;
	ToastTitle?: string;
	ToastBody?: string;
	EndTitle?: string;
	EndBody?: string;
}

function surgeConfig() {
	const config = (GameConfig as unknown as { FluxSurge?: SurgeConfigSource }).FluxSurge;
	return {
		Interval: math.max(60, math.floor(num(config && config.IntervalSeconds) ?? 20 * 60)),
		Duration: math.max(10, math.floor(num(config && config.DurationSeconds) ?? 60)),
		Multiplier: math.max(1, num(config && config.Multiplier) ?? 2),
		ToastTitle: (config && config.ToastTitle) ?? "Flux Surge",
		ToastBody: (config && config.ToastBody) ?? "All production is doubled for 60 seconds.",
		EndTitle: (config && config.EndTitle) ?? "Flux Surge ended",
		EndBody: (config && config.EndBody) ?? "Production returned to normal.",
	};
}

function announce(title: string, body: string, tone: string, effect: Record<string, unknown>) {
	for (const player of Players.GetPlayers()) {
		ServerEvents.toast.fire(player, { Title: title, Body: body, Tone: tone });
		ServerEvents.effect.fire(player, effect);
	}
}

@Service({ loadOrder: 1 })
export class FluxSurgeService {
	private endsAt = 0;
	private accumulator = 0;

	Multiplier(now?: number): number {
		return this.endsAt > (now ?? os.time()) ? surgeConfig().Multiplier : 1;
	}

	EndsAt(): number {
		return this.endsAt;
	}

	Active(now?: number): boolean {
		return this.endsAt > (now ?? os.time());
	}

	State(now?: number) {
		const timestamp = now ?? os.time();
		const config = surgeConfig();
		const active = this.endsAt > timestamp;
		return {
			Active: active,
			EndsAt: this.endsAt,
			Multiplier: active ? config.Multiplier : 1,
			DurationSeconds: config.Duration,
			IntervalSeconds: config.Interval,
			AffectsCapacity: false,
		};
	}

	Tick(deltaTime: number) {
		const now = os.time();
		const config = surgeConfig();
		const wasActive = this.endsAt > now;
		this.accumulator += deltaTime;
		if (!wasActive && this.accumulator >= config.Interval) {
			this.accumulator = 0;
			this.endsAt = now + config.Duration;
			ModuleLog.Info("Flux Surge", "server-wide surge started");
			announce(config.ToastTitle, config.ToastBody, "Special", {
				Type: "FluxSurge",
				EndsAt: this.endsAt,
				Multiplier: config.Multiplier,
				AffectsCapacity: false,
			});
		} else if (wasActive && this.endsAt <= now) {
			ModuleLog.Info("Flux Surge", "server-wide surge ended");
			announce(config.EndTitle, config.EndBody, "Info", {
				Type: "FluxSurgeEnded",
				EndsAt: 0,
				Multiplier: 1,
				AffectsCapacity: false,
			});
			this.endsAt = 0;
		}
	}

	static IdleState(this: void) {
		return { Active: false, Multiplier: 1, AffectsCapacity: false };
	}
}

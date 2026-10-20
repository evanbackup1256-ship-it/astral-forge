import { ModuleLogApi, num, req, SharedFolder } from "./LuaInterop";

interface SurgeConfigSource {
	IntervalSeconds?: unknown;
	DurationSeconds?: unknown;
	Multiplier?: unknown;
	ToastTitle?: string;
	ToastBody?: string;
	EndTitle?: string;
	EndBody?: string;
}

type ToastCallback = (this: void, player: Player, title: string, body: string, kind: string) => void;
type EffectCallback = (this: void, player: Player, effect: unknown) => void;

export = () => {
	const Players = game.GetService("Players");
	const ModuleLog = req<ModuleLogApi>(script.Parent!.Parent!.WaitForChild("ModuleLog"));
	const GameConfig = req<{ FluxSurge?: SurgeConfigSource }>(SharedFolder().WaitForChild("GameConfig"));

	const surgeConfig = () => {
		const config = GameConfig.FluxSurge;
		return {
			Interval: math.max(60, math.floor(num(config && config.IntervalSeconds) ?? 20 * 60)),
			Duration: math.max(10, math.floor(num(config && config.DurationSeconds) ?? 60)),
			Multiplier: math.max(1, num(config && config.Multiplier) ?? 2),
			ToastTitle: (config && config.ToastTitle) ?? "Flux Surge",
			ToastBody: (config && config.ToastBody) ?? "All production is doubled for 60 seconds.",
			EndTitle: (config && config.EndTitle) ?? "Flux Surge ended",
			EndBody: (config && config.EndBody) ?? "Production returned to normal.",
		};
	};

	class FluxSurgeService {
		_endsAt = 0;
		_accumulator = 0;
		_toast: ToastCallback;
		_effect: EffectCallback;

		constructor(toastCallback: ToastCallback, effectCallback: EffectCallback) {
			this._toast = toastCallback;
			this._effect = effectCallback;
		}

		Multiplier(now?: number): number {
			const config = surgeConfig();
			return this._endsAt > (now ?? os.time()) ? config.Multiplier : 1;
		}

		EndsAt(): number {
			return this._endsAt;
		}

		Active(now?: number): boolean {
			return this._endsAt > (now ?? os.time());
		}

		State(now?: number) {
			const timestamp = now ?? os.time();
			const config = surgeConfig();
			const active = this._endsAt > timestamp;
			return {
				Active: active,
				EndsAt: this._endsAt,
				Multiplier: active ? config.Multiplier : 1,
				DurationSeconds: config.Duration,
				IntervalSeconds: config.Interval,
				AffectsCapacity: false,
			};
		}

		Tick(deltaTime: number) {
			const now = os.time();
			const config = surgeConfig();
			const wasActive = this._endsAt > now;
			this._accumulator += deltaTime;
			if (!wasActive && this._accumulator >= config.Interval) {
				this._accumulator = 0;
				this._endsAt = now + config.Duration;
				ModuleLog.Info("Flux Surge", "A server-wide Flux Surge has started!");
				for (const player of Players.GetPlayers()) {
					this._toast(player, config.ToastTitle, config.ToastBody, "Special");
					this._effect(player, {
						Type: "FluxSurge",
						EndsAt: this._endsAt,
						Multiplier: config.Multiplier,
						AffectsCapacity: false,
					});
				}
			} else if (wasActive && this._endsAt <= now) {
				ModuleLog.Info("Flux Surge", "The server-wide Flux Surge has ended.");
				for (const player of Players.GetPlayers()) {
					this._toast(player, config.EndTitle, config.EndBody, "Info");
					this._effect(player, {
						Type: "FluxSurgeEnded",
						EndsAt: 0,
						Multiplier: 1,
						AffectsCapacity: false,
					});
				}
				this._endsAt = 0;
			}
		}

		static IdleState(this: void) {
			return {
				Active: false,
				Multiplier: 1,
				AffectsCapacity: false,
			};
		}
	}

	return FluxSurgeService;
};

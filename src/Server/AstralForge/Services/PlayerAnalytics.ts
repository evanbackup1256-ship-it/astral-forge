import { Service } from "@flamework/core";
import { ServerTelemetry } from "./ServerTelemetry";
import { ModuleLogApi, num, req } from "./LuaInterop";

interface AnalyticsProfile {
	Stats?: { Joins?: unknown };
	CurrentZone: number;
	Rebirths: number;
	Domain: { Rank: number };
	Flags: { TutorialStep: number };
}

interface PerformancePayload {
	FPS: number;
	P95Ms: number;
	PingMs: number;
	Input: string;
}

interface TelemetryApi {
	RecordClientPerformance: (this: void, payload: PerformancePayload) => void;
}

const AnalyticsService = game.GetService("AnalyticsService");
const ModuleLog = req<ModuleLogApi>(script.Parent!.Parent!.WaitForChild("ModuleLog"));

const PROGRESSION_ACTIONS: Record<string, string | undefined> = {
	Rebirth: "Rebirth",
	DomainExpansion: "DomainExpansion",
	UnlockZone: "World",
};

const CUSTOM_ACTIONS: Record<string, boolean | undefined> = {
	CollectVault: true,
	BuyMachine: true,
	BuyResearch: true,
	OpenItemCrate: true,
	ClaimConvergenceReward: true,
};

const emit = (key: string, callback: () => void) => {
	const [ok, issue] = pcall(callback);
	if (!ok) {
		ModuleLog.Every("analytics:" + key, 60, "Analytics", tostring(issue));
	}
};

@Service({ loadOrder: 2 })
export class PlayerAnalytics {
	constructor(private readonly telemetry: ServerTelemetry) {}

	_lastPerformance = new Map<Player, number>();
	_seenActions = new Map<Player, Map<string, boolean>>();
	_joinedAt = new Map<Player, number>();

	PlayerJoined(player: Player, profile: AnalyticsProfile) {
		this._joinedAt.set(player, os.clock());
		emit("session", () => {
			const joins = math.max(0, math.floor(num(profile.Stats && profile.Stats.Joins) ?? 0));
			AnalyticsService.LogCustomEvent(player, "AF_SessionStart", joins, {
				world: tostring(profile.CurrentZone),
				first_session: joins <= 1 ? "true" : "false",
			});
		});
	}

	PlayerLeft(player: Player, profile: AnalyticsProfile) {
		const duration = math.max(0, math.floor(os.clock() - (this._joinedAt.get(player) ?? os.clock())));
		emit("session-end", () => {
			AnalyticsService.LogCustomEvent(player, "AF_SessionEnd", duration, {
				world: tostring(profile.CurrentZone),
				rebirths: tostring(math.floor(profile.Rebirths)),
			});
		});
	}

	RecordAction(player: Player, action: string, profile: AnalyticsProfile, elapsedMs: number) {
		const progression = PROGRESSION_ACTIONS[action];
		if (progression !== undefined) {
			emit("progression:" + action, () => {
				// `a and x or b and y or z` falls through when x / y is nil, exactly like the Luau
				let level: number | undefined;
				if (action === "DomainExpansion" && profile.Domain.Rank !== undefined) {
					level = profile.Domain.Rank;
				} else if (action === "UnlockZone" && profile.CurrentZone !== undefined) {
					level = profile.CurrentZone;
				} else {
					level = profile.Rebirths;
				}
				const safeLevel = math.max(1, math.floor(level ?? 1));
				AnalyticsService.LogProgressionEvent(
					player,
					progression,
					Enum.AnalyticsProgressionType.Complete,
					safeLevel,
					progression + " " + tostring(safeLevel),
				);
			});
		}
		if (action === "SetTutorialStep" || action === "CompleteTutorial") {
			emit("onboarding", () => {
				const step = action === "CompleteTutorial" ? 16 : math.clamp(profile.Flags.TutorialStep, 1, 15);
				AnalyticsService.LogOnboardingFunnelStepEvent(
					player,
					step,
					action === "CompleteTutorial" ? "First Shift complete" : "First Shift",
				);
			});
		} else if (CUSTOM_ACTIONS[action]) {
			let seen = this._seenActions.get(player);
			if (!seen) {
				seen = new Map();
				this._seenActions.set(player, seen);
			}
			if (seen.get(action)) {
				return;
			}
			seen.set(action, true);
			emit("action:" + action, () => {
				AnalyticsService.LogCustomEvent(player, "AF_" + action, 1, {
					world: tostring(profile.CurrentZone),
					latency_band: elapsedMs >= 500 ? "slow" : elapsedMs >= 180 ? "warm" : "fast",
				});
			});
		}
	}

	RecordPerformance(player: Player, payload: PerformancePayload): boolean {
		const now = os.clock();
		if (now - (this._lastPerformance.get(player) ?? 0) < 45) {
			return true;
		}
		this._lastPerformance.set(player, now);
		this.telemetry.RecordClientPerformance(payload);
		emit("performance", () => {
			AnalyticsService.LogCustomEvent(player, "AF_ClientPerformance", payload.FPS, {
				p95_ms: "%.1f".format(payload.P95Ms),
				ping_ms: tostring(math.floor(payload.PingMs)),
				input: payload.Input,
			});
		});
		return true;
	}

	Forget(player: Player) {
		this._lastPerformance.delete(player);
		this._seenActions.delete(player);
		this._joinedAt.delete(player);
	}
}


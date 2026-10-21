import { T } from "../../../Shared/AstralForge/Shared/Locale";
import { Service } from "@flamework/core";
import { ServerTelemetry } from "./ServerTelemetry";
import { ModuleLogApi, num, req } from "./LuaInterop";
import * as FirstGoals from "../../../Shared/AstralForge/Shared/FirstGoals";

interface AnalyticsProfile {
	Stats?: { Joins?: unknown };
	CurrentZone: number;
	Rebirths: number;
	Domain: { Rank: number };
	Flags: { TutorialStep: number; FirstGoals?: unknown };
	Settings?: { FirstGoals?: unknown };
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
		ModuleLog.Every("analytics:" + key, 60, "Analytics", string.format("analytics event %s failed: %s", key, tostring(issue)));
	}
};

@Service({ loadOrder: 2 })
export class PlayerAnalytics {
	constructor(private readonly telemetry: ServerTelemetry) {}

	_lastPerformance = new Map<Player, number>();
	_seenActions = new Map<Player, Map<string, boolean>>();
	_joinedAt = new Map<Player, number>();
	// per-server action counts for the admin economy dashboard (bounded by the action list)
	_actionCounts = new Map<string, number>();

	ActionCounts(): Map<string, number> {
		return this._actionCounts;
	}

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
		if (this._actionCounts.has(action) || this._actionCounts.size() < 256) {
			this._actionCounts.set(action, (this._actionCounts.get(action) ?? 0) + 1);
		}
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
				AnalyticsService.LogOnboardingFunnelStepEvent(player, step, action === "CompleteTutorial" ? "First Shift complete" : "First Shift");
			});
		} else if (action === "ClaimFirstGoal") {
			// first goals continue the tour's onboarding funnel: step 17 is the first goal
			const claimed = FirstGoals.normalizeClaimed(profile.Flags.FirstGoals);
			const last = claimed[claimed.size() - 1];
			const goal = last !== undefined ? FirstGoals.goalById(last) : undefined;
			if (goal !== undefined) {
				emit("first-goal", () => {
					AnalyticsService.LogOnboardingFunnelStepEvent(
						player,
						FirstGoals.FUNNEL_FIRST_STEP + claimed.size() - 1,
						T("PlayerAnalytics.FirstGoalS", goal.title),
					);
				});
			}
		} else if (action === "SetSetting" && profile.Settings !== undefined && profile.Settings.FirstGoals === 0) {
			let seen = this._seenActions.get(player);
			if (!seen) {
				seen = new Map();
				this._seenActions.set(player, seen);
			}
			if (!seen.get("FirstGoalsOff")) {
				seen.set("FirstGoalsOff", true);
				const claimed = FirstGoals.normalizeClaimed(profile.Flags.FirstGoals).size();
				emit("first-goals-off", () => {
					AnalyticsService.LogCustomEvent(player, "AF_FirstGoalsSkipped", claimed, {
						world: tostring(profile.CurrentZone),
					});
				});
			}
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

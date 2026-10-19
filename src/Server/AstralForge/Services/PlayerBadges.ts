import { ModuleLogApi, req, SharedFolder, isTable, num } from "./LuaInterop";

interface BadgeProfile {
	Stats?: { Collected?: unknown; MachinesBought?: unknown };
	Rebirths?: unknown;
	Zone?: unknown;
	Domain?: unknown;
}

export = () => {
	const BadgeService = game.GetService("BadgeService") as unknown as { AwardBadgeAsync(userId: number, badgeId: number): boolean };
	const GameConfig = req<{ PlatformBadges: Record<string, unknown> }>(SharedFolder().WaitForChild("GameConfig"));
	const ModuleLog = req<ModuleLogApi>(script.Parent!.Parent!.WaitForChild("ModuleLog"));

	class PlayerBadges {
		_attempted = new Map<Player, Map<string, boolean>>();
		_alive = true;
		_workers = new Map<object, thread>();

		_award(player: Player, key: string) {
			const badgeId = GameConfig.PlatformBadges[key];
			if (!typeIs(badgeId, "number") || badgeId <= 0) {
				return;
			}
			let playerAttempts = this._attempted.get(player);
			if (!playerAttempts) {
				playerAttempts = new Map();
				this._attempted.set(player, playerAttempts);
			}
			if (playerAttempts.get(key)) {
				return;
			}
			playerAttempts.set(key, true);
			const attempts = playerAttempts;
			const token = {};
			const worker = task.defer(() => {
				if (!this._alive) {
					this._workers.delete(token);
					return;
				}
				const [ok, awarded] = pcall(() => BadgeService.AwardBadgeAsync(player.UserId, badgeId));
				if (this._alive && (!ok || awarded !== true)) {
					attempts.delete(key);
					ModuleLog.Every("badge:" + key, 60, "Badges", ok ? "platform declined badge award" : tostring(awarded));
				}
				this._workers.delete(token);
			});
			this._workers.set(token, worker);
		}

		Evaluate(player: Player, profile: BadgeProfile, action?: string) {
			const collected = profile.Stats && profile.Stats.Collected;
			if (typeIs(collected, "number") && collected > 0) {
				this._award(player, "FirstCollect");
			} else if (typeIs(collected, "string") && collected !== "" && collected !== "0") {
				this._award(player, "FirstCollect");
			}
			if ((num(profile.Stats && profile.Stats.MachinesBought) ?? 0) > 0) {
				this._award(player, "FirstMachine");
			}
			if ((num(profile.Rebirths) ?? 0) > 0) {
				this._award(player, "FirstRebirth");
			}
			if ((num(profile.Zone) ?? 0) >= 5) {
				this._award(player, "WorldFive");
			}
			if (isTable(profile.Domain) && (num(profile.Domain.Rank) ?? 0) > 0) {
				this._award(player, "DomainExpansion");
			}
			if (action === "ClaimConvergenceReward") {
				this._award(player, "Convergence");
			}
		}

		Forget(player: Player) {
			this._attempted.delete(player);
		}

		Destroy() {
			if (!this._alive) {
				return;
			}
			this._alive = false;
			for (const [, worker] of this._workers) {
				pcall(task.cancel, worker);
			}
			this._workers.clear();
			this._attempted.clear();
		}
	}

	return PlayerBadges;
};

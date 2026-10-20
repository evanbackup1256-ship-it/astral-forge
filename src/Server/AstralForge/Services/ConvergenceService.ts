import { Service } from "@flamework/core";
import type { DataService } from "./DataService";
import { Dict, Flux, ModuleLogApi, num, req, sharedDataKit, SharedFolder } from "./LuaInterop";

interface Manifest {
	EventId: string;
	Name: string;
	StartsAt: number;
	EndsAt: number;
}

interface PersonalTier {
	Required: number;
	Reward: Dict;
}

interface LiveOpsApi {
	CurrentConvergence: (this: void, now: number) => Manifest;
	Convergence: {
		ContributionByAction: Record<string, unknown>;
		GlobalPhases: unknown;
		PersonalTiers: PersonalTier[];
	};
}

interface EventProfile {
	Contribution: number;
	Claimed: Record<string, unknown>;
}

interface ConvergenceOpsMathApi {
	EnsureRewardBags: (this: void, profile: unknown) => void;
	ShardFor: (this: void, jobId: string, shards: number) => number;
	EnsureEventProfile: (this: void, profile: unknown, eventId: string) => EventProfile;
	ReadEventProfile: (this: void, profile: unknown, eventId: string) => EventProfile;
	ShardKey: (this: void, eventId: string, shard: number) => string;
	SumShards: (this: void, shards: unknown[], legacy: unknown) => number;
	ProductionMultiplier: (this: void, total: number, phases: unknown) => number;
	PhaseState: (this: void, total: number, phases: unknown) => LuaTuple<[number, string, number]>;
	CanClaimTier: (this: void, personal: number, required: number, claimed: unknown, index: number) => boolean;
}

interface OmegaMathApi {
	Add: (this: void, a: unknown, b: unknown) => Flux;
}

interface DataServiceApi {
	AtomicUpdate(
		player: Player,
		transform: (profile: Dict) => unknown,
		flag?: boolean,
		label?: string,
	): LuaTuple<[boolean, unknown]>;
	Get(player: Player): unknown;
}

interface ConvergenceProfile {
	Cash: Flux;
	RunCash: Flux;
	LifetimeCash: Flux;
	Stats: { Collected: Flux };
	Stardust: unknown;
	Cores: unknown;
	Command: { Signals: unknown };
	BoostInventory: Record<string, unknown>;
}

const StoreAccess = req<{ isPreview: (this: void) => boolean }>(script.Parent!.Parent!.WaitForChild("Modules").WaitForChild("StoreAccess"));
const MemoryStoreService = game.GetService("MemoryStoreService");
const Players = game.GetService("Players");

const LiveOps = sharedDataKit("LiveOpsConfig") as LiveOpsApi;
const ConvergenceOpsMath = (
	req<(this: void, name: string) => unknown>(script.Parent!.Parent!.WaitForChild("Modules").WaitForChild("OpsMath"))
)("ConvergenceOpsMath") as ConvergenceOpsMathApi;
const ModuleLog = req<ModuleLogApi>(script.Parent!.Parent!.WaitForChild("ModuleLog"));

const MAP_NAME = "AF_Convergence_v1";
// The global total is split across shard keys so a thousand servers never contend on one
// key; each server writes its own shard and sums all shards on its 15 s refresh. Nothing is
// broadcast: a MessagingService fan-out costs (publishes x servers) against the experience-wide
// receive budget, which does not survive high server counts.
const SHARDS = 8;
const SHUTDOWN_FLUSH_SECONDS = 2.5;
const BINDTOCLOSE_FLUSH_SECONDS = 10;

const applyReward = (rawProfile: unknown, reward: Dict) => {
	const profile = rawProfile as ConvergenceProfile;
	const cash = math.max(0, num(reward.Cash) ?? 0);
	const OmegaMath = req<OmegaMathApi>(SharedFolder().WaitForChild("OmegaMath"));
	ConvergenceOpsMath.EnsureRewardBags(profile);
	profile.Cash = OmegaMath.Add(profile.Cash, cash);
	profile.RunCash = OmegaMath.Add(profile.RunCash, cash);
	profile.LifetimeCash = OmegaMath.Add(profile.LifetimeCash, cash);
	profile.Stats.Collected = OmegaMath.Add(profile.Stats.Collected, cash);
	profile.Stardust = (num(profile.Stardust) ?? 0) + math.max(0, num(reward.Stardust) ?? 0);
	profile.Cores = (num(profile.Cores) ?? 0) + math.max(0, num(reward.Cores) ?? 0);
	if (reward.Signals !== undefined && reward.Signals !== false) {
		profile.Command.Signals = (num(profile.Command.Signals) ?? 0) + math.max(0, num(reward.Signals) ?? 0);
	}
	if (reward.Boost !== undefined && reward.Boost !== false) {
		const boost = reward.Boost as string;
		profile.BoostInventory[boost] = (num(profile.BoostInventory[boost]) ?? 0) + 1;
	}
};

@Service({ loadOrder: 2 })
export class ConvergenceService {
	_data: DataServiceApi;
	_map: MemoryStoreHashMap | undefined;
	_pending = new Map<Player, number>();
	_stashed = new Map<number, number>();
	_pendingGlobal = 0;
	_global = 0;
	_eventId = "";
	_shard!: number;
	_running = false;
	_worker: thread | undefined = undefined;
	_shutdownBound = false;

	constructor(dataService: DataService) {
		this._data = dataService as unknown as DataServiceApi;
	}

	// Runs from the server runtime's "convergence construction" boot step, so a MemoryStore
	// failure is reported through BootFailure.
	build() {
		this._map = StoreAccess.isPreview() ? undefined : MemoryStoreService.GetHashMap(MAP_NAME);
		this._shard = ConvergenceOpsMath.ShardFor(game.JobId, SHARDS);
	}

	_manifest() {
		const manifest = LiveOps.CurrentConvergence(os.time());
		if (this._eventId !== manifest.EventId) {
			this._eventId = manifest.EventId;
			this._global = 0;
			this._pending = new Map();
			this._pendingGlobal = 0;
		}
		return manifest;
	}

	RecordAction(player: Player, action: string) {
		this._manifest();
		const amount = LiveOps.Convergence.ContributionByAction[action];
		if (!typeIs(amount, "number") || amount <= 0) {
			return;
		}
		this._pending.set(player, (this._pending.get(player) ?? 0) + amount);
		this._pendingGlobal += amount;
		// Drain any contribution that was orphaned when a previous flush failed during PlayerRemoving.
		const stashed = this._stashed.get(player.UserId);
		if (stashed !== undefined && stashed > 0) {
			this._pending.set(player, (this._pending.get(player) ?? 0) + stashed);
			this._stashed.delete(player.UserId);
		}
	}

	FlushPlayer(player: Player): boolean {
		const manifest = this._manifest();
		const amount = this._pending.get(player) ?? 0;
		if (amount <= 0) {
			return true;
		}
		this._pending.set(player, 0);
		const [ok] = this._data.AtomicUpdate(
			player,
			(profile) => {
				const state = ConvergenceOpsMath.EnsureEventProfile(profile, manifest.EventId);
				state.Contribution += amount;
			},
			true,
			"convergence",
		);
		if (!ok) {
			this._pending.set(player, (this._pending.get(player) ?? 0) + amount);
		}
		return ok;
	}

	_flushGlobal() {
		const manifest = this._manifest();
		const amount = this._pendingGlobal;
		if (amount <= 0) {
			return;
		}
		this._pendingGlobal = 0;
		const map = this._map;
		if (map === undefined) {
			this._global += amount;
			return;
		}
		const expiry = math.max(60, manifest.EndsAt - os.time() + 86_400);
		const key = ConvergenceOpsMath.ShardKey(manifest.EventId, this._shard);
		const [ok, total] = pcall(() =>
			map.UpdateAsync(key, (previous: unknown) => math.max(0, num(previous) ?? 0) + amount, expiry),
		);
		if (!(ok && typeIs(total, "number"))) {
			this._pendingGlobal += amount;
			ModuleLog.Every("convergence-flush", 30, "LiveOps", tostring(total));
		}
	}

	_refresh() {
		const map = this._map;
		if (map === undefined) {
			return;
		}
		const manifest = this._manifest();
		const shards: unknown[] = [];
		for (let shard = 1; shard <= SHARDS; shard++) {
			const [ok, value] = pcall(() => map.GetAsync(ConvergenceOpsMath.ShardKey(manifest.EventId, shard)));
			// a failed shard read keeps the last known total rather than dropping it
			if (!ok) {
				return;
			}
			shards[shard - 1] = value;
		}
		// events that began before sharding kept their total under the bare event id
		const [okLegacy, legacy] = pcall(() => map.GetAsync(manifest.EventId));
		if (!okLegacy) {
			return;
		}
		this._global = math.max(this._global, ConvergenceOpsMath.SumShards(shards, legacy));
	}

	Multiplier(): number {
		return ConvergenceOpsMath.ProductionMultiplier(this._global + this._pendingGlobal, LiveOps.Convergence.GlobalPhases);
	}

	State(player: Player, profile: unknown) {
		const manifest = this._manifest();

		const saved = ConvergenceOpsMath.ReadEventProfile(profile, manifest.EventId);
		const personal = saved.Contribution + (this._pending.get(player) ?? 0);
		const total = this._global + this._pendingGlobal;
		const [phaseIndex, phaseName, nextTarget] = ConvergenceOpsMath.PhaseState(total, LiveOps.Convergence.GlobalPhases);
		const tiers: Dict[] = [];
		LiveOps.Convergence.PersonalTiers.forEach((tier, i) => {
			const index = i + 1;
			tiers[i] = {
				Tier: index,
				Required: tier.Required,
				Reward: tier.Reward,
				Claimed: saved.Claimed[tostring(index)] === true,
				CanClaim: ConvergenceOpsMath.CanClaimTier(personal, tier.Required, saved.Claimed, index),
			};
		});
		return {
			EventId: manifest.EventId,
			Name: manifest.Name,
			StartsAt: manifest.StartsAt,
			EndsAt: manifest.EndsAt,
			GlobalContribution: total,
			GlobalTarget: nextTarget,
			Phase: phaseIndex,
			PhaseName: phaseName,
			ProductionMultiplier: this.Multiplier(),
			PersonalContribution: personal,
			Tiers: tiers,
		};
	}

	Claim(player: Player, rawTier: unknown) {
		if (!this.FlushPlayer(player)) {
			return { ok: false, error: "The convergence is busy. Try again." };
		}
		const tierIndex = math.floor(num(rawTier) ?? 0);
		const tier = (LiveOps.Convergence.PersonalTiers as unknown as Record<number, PersonalTier | undefined>)[tierIndex];
		if (!tier) {
			return { ok: false, error: "That convergence reward does not exist." };
		}
		const manifest = this._manifest();
		const [ok, result] = this._data.AtomicUpdate(
			player,
			(profile) => {
				const state = ConvergenceOpsMath.EnsureEventProfile(profile, manifest.EventId);
				const key = tostring(tierIndex);
				if (state.Claimed[key] !== undefined && state.Claimed[key] !== false) {
					return { ok: false, error: "That reward was already claimed." };
				}
				if (state.Contribution < tier.Required) {
					return { ok: false, error: "Keep forging to unlock this reward." };
				}
				state.Claimed[key] = true;
				applyReward(profile, tier.Reward);
				return { ok: true, message: "Convergence reward claimed.", Reward: tier.Reward };
			},
			true,
			"convergence-claim",
		);
		if (!ok) {
			return { ok: false, error: "The convergence is busy. Try again." };
		}
		return result;
	}

	Start() {
		if (this._running) {
			return;
		}
		this._running = true;
		task.spawn(() => this._refresh());
		this._worker = task.spawn(() => {
			while (this._running) {
				task.wait(15);

				if (!this._running) {
					break;
				}
				for (const player of Players.GetPlayers()) {
					this.FlushPlayer(player);
				}
				this._flushGlobal();
				this._refresh();
			}
			this._worker = undefined;
		});

		// Ensure pending contributions are written to profiles before the server closes,
		// using a dedicated BindToClose handler with a larger budget than normal cleanup.
		if (!this._shutdownBound) {
			this._shutdownBound = true;
			game.BindToClose(() => {
				this.ShutdownFlush();
			});
		}
	}

	// Await flushing all per-player and global pending contributions within the shutdown budget.
	ShutdownFlush() {
		const deadline = os.clock() + BINDTOCLOSE_FLUSH_SECONDS;
		let pendingCount = 0;
		for (const player of Players.GetPlayers()) {
			let ok = this.FlushPlayer(player);
			let attempts = 1;
			while (!ok && os.clock() < deadline) {
				task.wait(0.1);
				ok = this.FlushPlayer(player);
				attempts += 1;
				if (attempts > 50) {
					break;
				}
			}
			if (!ok) {
				pendingCount += 1;
			}
		}
		if (pendingCount > 0) {
			ModuleLog.Warn("LiveOps", "shutdown flush left %d player contribution(s) pending".format(pendingCount));
		}
		if (this._pendingGlobal > 0 && os.clock() < deadline) {
			let finished = false;
			const worker = task.spawn(() => {
				this._flushGlobal();
				finished = true;
			});
			while (!finished && os.clock() < deadline) {
				task.wait();
			}
			if (!finished) {
				pcall(task.cancel, worker);
				ModuleLog.Warn("LiveOps", "shutdown flush could not complete global convergence write");
			}
		}
	}

	PlayerRemoving(player: Player) {
		const deadline = os.clock() + 6;
		let flushed = this.FlushPlayer(player);
		while (!flushed && this._data.Get(player) !== undefined && os.clock() < deadline) {
			task.wait(0.1);
			flushed = this.FlushPlayer(player);
		}
		const remaining = this._pending.get(player) ?? 0;
		if (!flushed && remaining > 0) {
			// Do not drop the data: stash it by userId so it can be recovered on rejoin.
			this._stashed.set(player.UserId, (this._stashed.get(player.UserId) ?? 0) + remaining);
			ModuleLog.Warn("LiveOps", "could not flush %s contribution before leave; stashed for rejoin".format(player.Name));
		}
		this._pending.delete(player);
	}

	Stop() {
		this._running = false;
		if (this._worker) {
			task.cancel(this._worker);
			this._worker = undefined;
		}

		// Fallback flush path; the main shutdown flush is handled by BindToClose in Start().
		const deadline = os.clock() + SHUTDOWN_FLUSH_SECONDS;
		for (const player of Players.GetPlayers()) {
			if (os.clock() >= deadline) {
				ModuleLog.Warn("LiveOps", "ran out of time flushing contributions");
				break;
			}
			let ok = this.FlushPlayer(player);
			let attempts = 1;
			while (!ok && os.clock() < deadline) {
				task.wait(0.1);
				ok = this.FlushPlayer(player);
				attempts += 1;
				if (attempts > 20) {
					break;
				}
			}
		}
		if (this._pendingGlobal > 0 && os.clock() < deadline) {
			let finished = false;
			const worker = task.spawn(() => {
				this._flushGlobal();
				finished = true;
			});
			while (!finished && os.clock() < deadline) {
				task.wait();
			}
			if (!finished) {
				pcall(task.cancel, worker);
				ModuleLog.Warn("LiveOps", "skipped the convergence write — shutdown is already late");
			}
		}
	}
}


// Server-wide live events (warning, live, results): scoring, shared goals, tickets, catches and supply drops.
import { T } from "../../../../Shared/AstralForge/Shared/Locale";
import { Service } from "@flamework/core";
import { Dict, sharedDataKit } from "../LuaInterop";

interface EventState {
	Phase?: string;
	Id?: string;
	PhaseEndsAt: number;
	StartedAt?: number;
	LastId?: string;
}

interface EventDef {
	Id: string;
	Kind: string;
	Mods?: Record<string, number>;
	MaxPointsPerCollect?: number;
	MaxTickets?: number;
	Winners?: number;
	Prize?: { Stardust: number; Cores: number };
	Consolation?: { Stardust: number };
	TapsPerSecond?: number;
	MaxStars?: number;
	MinGap?: number;
	DustPerStar?: number;
	DropSeconds?: number;
	ClaimsPerDrop?: number;
	Reward?: Dict;
	RewardFluxSeconds?: number;
	RewardStardust?: number;
	TopBonusStardust?: number[];
	TopBonusCores?: number[];
}

interface SupplyDropState {
	Id: number;
	At: number;
	Announced?: boolean;
	Claimed: Record<number, boolean>;
	Left: number;
}

interface TapWindow {
	Second: number;
	Count: number;
}

interface CollectBonus {
	Dust: number;
	Cores: number;
	Keys: number;
	KeyCrate?: string;
	FluxBonus: number;
}

interface ServerEventsApi {
	FIRST_REST_SECONDS: number;
	LIVE_SECONDS: number;
	EVENTS: Record<string, EventDef | undefined>;
	advance(this: void, state: EventState | undefined, now: number, roll: number): LuaTuple<[EventState, boolean]>;
	mod(this: void, state: EventState | undefined, name: string): number;
	productionMultiplier(this: void, state: EventState | undefined): number;
	collectPoints(this: void, collected: number, perSecond: number, cap?: number): number;
	drops(
		this: void,
		id: string | undefined,
		collected: number,
		perSecond: number,
		rollA: number,
		rollB: number,
	): { Dust: number; Cores: number; Keys: number; KeyCrate?: string };
	communityGoal(this: void, players: number): number;
	titanHealth(this: void, players: number): number;
	titanCollectHit(this: void, collected: number, perSecond: number): number;
	ranking(this: void, points: Record<number, number>): { UserId: number; Points: number }[];
	racePrize(this: void, rank: number): { Stardust?: number; Cores?: number };
	drawWinners(this: void, tickets: Record<number, number>, rolls: number[], count?: number): number[];
	supplyTimes(this: void): number[];
}

interface ServerEventHooks {
	random(this: void): number;
	announce(this: void, phase: string, def: EventDef): void;
	broadcast(this: void): void;
	pay(this: void, entries: Dict[], def: EventDef, why: string): void;
}

const Players = game.GetService("Players");
const ServerEvents = sharedDataKit("ServerEvents") as ServerEventsApi;

// Runs the server's events. Hooks:
//   random()                     a 0..1 roll
//   announce(phase, def)         tell everyone (Warning / Live / Results / Completed / Defeated)
//   broadcast()                  push State() to every player
//   pay(entries, def, why)       entries = { { UserId, FluxSeconds, Stardust, Cores, Keys, KeyCrate, Rank } }
@Service({ loadOrder: 1 })
export class ServerEventService {
	_hooks!: ServerEventHooks;
	_state: EventState | undefined;
	_accumulator = 0;
	_broadcastDue = false;
	_lastBroadcast = 0;
	// per-event scratch: who scored what, the shared bar, tickets, catches, crates
	_points!: Record<number, number>;
	_names!: Record<number, string>;
	_goal!: number;
	_progress!: number;
	_completed!: boolean;
	_tickets!: Record<number, number>;
	_winners!: { UserId: number; Name: string }[] | undefined;
	_caught!: Record<number, number>;
	_lastCatch!: Record<number, number>;
	_tapWindow!: Record<number, TapWindow>;
	_drops!: SupplyDropState[];

	constructor() {
		this._state = undefined;
		this._reset();
	}

	/** GameService supplies the random roll, announcements, broadcast and payout hooks. */
	Attach(hooks: ServerEventHooks) {
		this._hooks = hooks;
	}

	_reset() {
		this._points = {};
		this._names = {};
		this._goal = 0;
		this._progress = 0;
		this._completed = false;
		this._tickets = {};
		this._winners = undefined;
		this._caught = {};
		this._lastCatch = {};
		this._tapWindow = {};
		this._drops = [];
	}

	_def(): EventDef | undefined {
		const state = this._state;
		return state !== undefined && state.Id !== undefined ? ServerEvents.EVENTS[state.Id] : undefined;
	}

	_live(kind?: string): EventDef | undefined {
		const state = this._state;
		const d = this._def();
		if (state === undefined || state.Phase !== "Live" || d === undefined) {
			return undefined;
		}
		if (kind !== undefined && d.Kind !== kind) {
			return undefined;
		}
		return d;
	}

	_touch(player: Player) {
		this._names[player.UserId] = player.DisplayName;
		this._broadcastDue = true;
	}

	Step(dt: number) {
		this._accumulator += dt;
		if (this._accumulator < 1) {
			return;
		}
		this._accumulator = 0;
		const now = os.time();
		const [nextState, changed] = ServerEvents.advance(this._state, now, this._hooks.random());
		if (changed) {
			const previous = this._state;
			this._state = nextState;
			this._enter(previous, nextState);
		}
		// a supply crate landing is news for everyone
		const d = this._live("supply");
		if (d !== undefined) {
			for (const drop of this._drops) {
				if (drop.Announced !== true && now >= drop.At) {
					drop.Announced = true;
					this._broadcastDue = true;
				}
			}
		}
		if (this._broadcastDue && os.clock() - this._lastBroadcast >= 1) {
			this._broadcastDue = false;
			this._lastBroadcast = os.clock();
			this._hooks.broadcast();
		}
	}

	_enter(previous: EventState | undefined, state: EventState) {
		const d = this._def();
		if (state.Phase === "Live") {
			this._reset();
			if (d !== undefined && d.Kind === "goal") {
				this._goal = ServerEvents.communityGoal(Players.GetPlayers().size());
			} else if (d !== undefined && d.Kind === "titan") {
				this._goal = ServerEvents.titanHealth(Players.GetPlayers().size());
			} else if (d !== undefined && d.Kind === "supply") {
				const started = state.StartedAt ?? os.time();
				let index = 0;
				for (const offset of ServerEvents.supplyTimes()) {
					index++;
					this._drops.push({ Id: index, At: started + offset, Claimed: {}, Left: d.ClaimsPerDrop ?? 0 });
				}
			}
		} else if (state.Phase === "Results" && d !== undefined) {
			this._settle(d);
		}
		if (d !== undefined && (state.Phase === "Warning" || state.Phase === "Live" || state.Phase === "Results")) {
			this._hooks.announce(state.Phase, d);
		}
		this._hooks.broadcast();
		this._lastBroadcast = os.clock();
		this._broadcastDue = false;
	}

	// the end of an event that pays by standing
	_settle(d: EventDef) {
		if (d.Kind === "race") {
			const entries: Dict[] = [];
			let rank = 0;
			for (const entry of ServerEvents.ranking(this._points)) {
				rank++;
				const prize = ServerEvents.racePrize(rank);
				entries.push({ UserId: entry.UserId, Stardust: prize.Stardust, Cores: prize.Cores, Rank: rank });
			}
			if (entries.size() > 0) {
				this._hooks.pay(entries, d, "race");
			}
		} else if (d.Kind === "draw") {
			const rolls: number[] = [];
			for (let index = 1; index <= (d.Winners ?? 0); index++) {
				rolls.push(this._hooks.random());
			}
			const winners = ServerEvents.drawWinners(this._tickets, rolls, d.Winners);
			this._winners = [];
			const won: Record<number, boolean> = {};
			const entries: Dict[] = [];
			let rank = 0;
			for (const userId of winners) {
				rank++;
				won[userId] = true;
				this._winners.push({ UserId: userId, Name: this._names[userId] ?? tostring(userId) });
				entries.push({ UserId: userId, Stardust: d.Prize?.Stardust, Cores: d.Prize?.Cores, Rank: rank });
			}
			for (const [userId, n] of pairs(this._tickets)) {
				if (n > 0 && won[userId] !== true) {
					entries.push({ UserId: userId, Stardust: d.Consolation?.Stardust });
				}
			}
			if (entries.size() > 0) {
				this._hooks.pay(entries, d, "draw");
			}
		}
	}

	// the community order filled, or the titan brought down: pay everyone who helped, by standing
	_payShared(d: EventDef, why: string) {
		const entries: Dict[] = [];
		let rank = 0;
		for (const entry of ServerEvents.ranking(this._points)) {
			rank++;
			entries.push({
				UserId: entry.UserId,
				FluxSeconds: d.RewardFluxSeconds,
				Stardust: (d.RewardStardust ?? 0) + (d.TopBonusStardust !== undefined ? d.TopBonusStardust[rank - 1] ?? 0 : 0),
				Cores: d.TopBonusCores !== undefined ? d.TopBonusCores[rank - 1] ?? 0 : 0,
				Rank: rank,
			});
		}
		this._hooks.pay(entries, d, why);
	}

	ProductionMultiplier(): number {
		return ServerEvents.mod(this._state, "Production");
	}

	TapMultiplier(): number {
		return ServerEvents.mod(this._state, "Tap");
	}

	CritBonus(): number {
		return ServerEvents.mod(this._state, "Crit");
	}

	ComboWindowMultiplier(): number {
		return ServerEvents.mod(this._state, "ComboWindow");
	}

	// a vault collect: returns what the event adds to it { Dust, Cores, Keys, KeyCrate, FluxBonus }
	OnCollect(player: Player, collected: number, perSecond: number): CollectBonus {
		const out: CollectBonus = { Dust: 0, Cores: 0, Keys: 0, KeyCrate: undefined, FluxBonus: 0 };
		const d = this._live();
		if (d === undefined || collected <= 0) {
			return out;
		}
		if (d.Kind === "drops") {
			const drops = ServerEvents.drops(d.Id, collected, perSecond, this._hooks.random(), this._hooks.random());
			out.Dust = drops.Dust;
			out.Cores = drops.Cores;
			out.Keys = drops.Keys;
			out.KeyCrate = drops.KeyCrate;
		} else if (d.Kind === "mod" && d.Mods !== undefined && d.Mods.Collect !== undefined) {
			out.FluxBonus = d.Mods.Collect;
		} else if (d.Kind === "goal" && !this._completed) {
			const points = ServerEvents.collectPoints(collected, perSecond, d.MaxPointsPerCollect);
			this._points[player.UserId] = (this._points[player.UserId] ?? 0) + points;
			this._progress += points;
			this._touch(player);
			if (this._progress >= this._goal) {
				this._completed = true;
				this._payShared(d, "goal");
				this._hooks.announce("Completed", d);
				this._hooks.broadcast();
			}
		} else if (d.Kind === "titan" && !this._completed) {
			this._hitTitan(player, ServerEvents.titanCollectHit(collected, perSecond));
		} else if (d.Kind === "race") {
			this._points[player.UserId] =
				(this._points[player.UserId] ?? 0) + ServerEvents.collectPoints(collected, perSecond, d.MaxPointsPerCollect);
			this._touch(player);
		} else if (d.Kind === "draw") {
			this._tickets[player.UserId] = math.min(d.MaxTickets ?? 0, (this._tickets[player.UserId] ?? 0) + 1);
			this._touch(player);
		}
		return out;
	}

	_hitTitan(player: Player, damage: number) {
		const d = this._live("titan");
		if (d === undefined || this._completed || damage <= 0) {
			return;
		}
		damage = math.min(damage, this._goal - this._progress);
		this._points[player.UserId] = (this._points[player.UserId] ?? 0) + damage;
		this._progress += damage;
		this._touch(player);
		if (this._progress >= this._goal) {
			this._completed = true;
			this._payShared(d, "titan");
			this._hooks.announce("Defeated", d);
			this._hooks.broadcast();
		}
	}

	// an overcharge tap: only the titan cares (a few hits a second at most)
	OnTap(player: Player) {
		const d = this._live("titan");
		if (d === undefined || this._completed) {
			return;
		}
		const second = math.floor(os.clock());
		let window = this._tapWindow[player.UserId];
		if (window === undefined || window.Second !== second) {
			window = { Second: second, Count: 0 };
			this._tapWindow[player.UserId] = window;
		}
		if (window.Count >= (d.TapsPerSecond ?? 0)) {
			return;
		}
		window.Count += 1;
		this._hitTitan(player, 1);
	}

	// Falling Stars: a catch is worth Stardust; returns the amount or nil and why
	CatchStar(player: Player): LuaTuple<[number | undefined, string | undefined]> {
		const d = this._live("stars");
		if (d === undefined) {
			return $tuple(undefined, T("ServerEventService.NoStarsAreFallingRight"));
		}
		const caught = this._caught[player.UserId] ?? 0;
		if (caught >= (d.MaxStars ?? 0)) {
			return $tuple(undefined, T("ServerEventService.YouVeCaughtEveryStar"));
		}
		const now = os.clock();
		if (now - (this._lastCatch[player.UserId] ?? 0) < (d.MinGap ?? 0)) {
			return $tuple(undefined, T("ServerEventService.TooQuick"));
		}
		this._lastCatch[player.UserId] = now;
		this._caught[player.UserId] = caught + 1;
		this._touch(player);
		return $tuple(d.DustPerStar, undefined);
	}

	// Supply Drop: the first players to grab a landed crate each get the reward
	ClaimSupply(player: Player, dropId: unknown): LuaTuple<[unknown, string | undefined]> {
		const d = this._live("supply");
		if (d === undefined) {
			return $tuple(undefined, T("ServerEventService.ThereSNoSupplyDrop"));
		}
		const now = os.time();
		for (const drop of this._drops) {
			if (drop.Id === dropId) {
				if (now < drop.At || now > drop.At + (d.DropSeconds ?? 0)) {
					return $tuple(undefined, T("ServerEventService.ThatCrateIsnTDown"));
				}
				if (drop.Claimed[player.UserId] === true) {
					return $tuple(undefined, T("ServerEventService.YouAlreadyGrabbedThisOne"));
				}
				if (drop.Left <= 0) {
					return $tuple(undefined, T("ServerEventService.SomeoneBeatYouToIt"));
				}
				drop.Left -= 1;
				drop.Claimed[player.UserId] = true;
				this._touch(player);
				return $tuple(d.Reward, undefined);
			}
		}
		return $tuple(undefined, T("ServerEventService.ThatCrateIsnTDown"));
	}

	Start(id: string): boolean {
		if (ServerEvents.EVENTS[id] === undefined) {
			return false;
		}
		const previous = this._state;
		const now = os.time();
		this._state = {
			Phase: "Live",
			Id: id,
			PhaseEndsAt: now + ServerEvents.LIVE_SECONDS,
			StartedAt: now,
			LastId: previous !== undefined ? previous.LastId : undefined,
		};
		this._enter(previous, this._state);
		return true;
	}

	_topOf(points: Record<number, number>): { Name: string; Points: number; UserId: number }[] {
		const top: { Name: string; Points: number; UserId: number }[] = [];
		let index = 0;
		for (const entry of ServerEvents.ranking(points)) {
			index++;
			if (index > 5) {
				break;
			}
			top.push({ Name: this._names[entry.UserId] ?? tostring(entry.UserId), Points: entry.Points, UserId: entry.UserId });
		}
		return top;
	}

	State(player?: Player): Dict {
		const state = this._state;
		const now = os.time();
		if (state === undefined) {
			return { Phase: "Rest", PhaseEndsAt: now + ServerEvents.FIRST_REST_SECONDS };
		}
		const d = this._def();
		const public_: Dict = {
			Phase: state.Phase,
			Id: state.Id,
			Kind: d !== undefined ? d.Kind : undefined,
			PhaseEndsAt: state.PhaseEndsAt,
			StartedAt: state.StartedAt,
			Multiplier: ServerEvents.productionMultiplier(state),
		};
		const userId = player !== undefined ? player.UserId : 0;
		if (d === undefined || (state.Phase !== "Live" && state.Phase !== "Results")) {
			return public_;
		}
		if (d.Kind === "goal" || d.Kind === "titan") {
			public_.Goal = this._goal;
			public_.Progress = math.min(this._progress, this._goal);
			public_.Completed = this._completed;
			public_.Yours = this._points[userId] ?? 0;
			public_.Top = this._topOf(this._points);
		} else if (d.Kind === "race") {
			public_.Top = this._topOf(this._points);
			public_.Yours = this._points[userId] ?? 0;
			let rank = 0;
			for (const entry of ServerEvents.ranking(this._points)) {
				rank++;
				if (entry.UserId === userId) {
					public_.YourRank = rank;
					break;
				}
			}
		} else if (d.Kind === "draw") {
			public_.Tickets = this._tickets[userId] ?? 0;
			let pool = 0;
			for (const [, n] of pairs(this._tickets)) {
				pool += n;
			}
			public_.Pool = pool;
			public_.Winners = this._winners;
		} else if (d.Kind === "stars") {
			public_.Caught = this._caught[userId] ?? 0;
			public_.MaxStars = d.MaxStars;
		} else if (d.Kind === "supply") {
			const drops: Dict[] = [];
			for (const drop of this._drops) {
				drops.push({
					Id: drop.Id,
					At: drop.At,
					EndsAt: drop.At + (d.DropSeconds ?? 0),
					Left: drop.Left,
					Mine: drop.Claimed[userId] === true,
				});
			}
			public_.Drops = drops;
		}
		return public_;
	}
}

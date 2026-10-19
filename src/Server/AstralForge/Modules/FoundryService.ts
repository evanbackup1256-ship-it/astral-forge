// Star Foundry on the server: the save shape, the one-time migration from Continuum/Reactor, every
// player move (one FoundryAct action with an Op), passive Shards, Ignite timing and the public state.
// The rules themselves live in FoundryMath (shared), so the client previews exactly what the server
// will compute.

const ReplicatedStorage = game.GetService("ReplicatedStorage");

interface FoundryBoard {
	Radius: number;
	Pieces: Record<string, unknown>;
}

interface FoundryPiece {
	Kind: string;
	Tier: number;
	Facing: number;
}

interface FoundryFlow {
	Delivered: number;
}

interface FoundryEffects {
	Production: number;
	Tap: number;
	Capacity: number;
	Offline: number;
}

interface FoundryMath {
	MIN_RADIUS: number;
	MAX_RADIUS: number;
	BENCH_CAP: number;
	IGNITE_SURGE_AT: number;
	IGNITE_SURGE_SECONDS: number;
	IGNITE_SURGE: number;
	flow(this: void, board: FoundryBoard): FoundryFlow & Record<string, unknown>;
	effects(this: void, flow: Record<string, unknown>): FoundryEffects;
	shardRate(this: void, flow: Record<string, unknown>): number;
	migrate(
		this: void,
		continuumRank: number,
		fragments: number,
		stabilizations: number,
	): LuaTuple<[FoundryBoard, unknown[], number]>;
	parse(this: void, key: string): LuaTuple<[number | undefined, number | undefined]>;
	onBoard(this: void, radius: number, q: number, r: number): boolean;
	validPiece(this: void, piece: unknown): boolean;
	key(this: void, q: number, r: number): string;
	drawCost(this: void, draws: number): number;
	expandCost(this: void, radius: number): number | undefined;
	bestTier(this: void, board: FoundryBoard, bench: unknown[]): number;
	draw(this: void, roll1: number, roll2: number, tier: number): FoundryPiece;
	cellCount(this: void, radius: number): number;
	wavePhase(this: void, igniteAt: number, now: number): number;
	targetPhase(this: void, board: FoundryBoard): number;
	onBeat(this: void, phase: number, target: number): boolean;
	canFuse(this: void, moving: FoundryPiece, target: FoundryPiece): boolean;
	igniteShards(this: void, flow: Record<string, unknown>, combo: number): number;
}

const FoundryMath = require(
	ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("FoundryMath") as ModuleScript,
) as FoundryMath;

type Profile = Record<string, unknown>;

interface FoundrySave {
	Migrated: boolean;
	Radius: number;
	Pieces: Record<string, unknown>;
	Bench: FoundryPiece[];
	Shards: number;
	Draws: number;
	Combo: number;
	BestCombo: number;
	IgniteAt: number;
	SurgeEndsAt: number;
	LastAt: number;
	Version: number;
	Effects?: FoundryEffects;
	ShardRate?: number;
	Delivered?: number;
	ShardsCapped?: boolean;
}

const MAX_SHARDS = 1e15;
const MAX_ACCRUE_SECONDS = 8 * 3600;

function finite(value: unknown, fallback: number): number {
	const n = tonumber(value);
	if (n === undefined || n !== n || n === math.huge || n === -math.huge) {
		return fallback;
	}
	return n;
}

// recompute the bonuses the economy reads (stored, so production ticks never re-run the flow)
function recompute(f: FoundrySave): FoundryFlow {
	const flow = FoundryMath.flow({ Radius: f.Radius, Pieces: f.Pieces });
	const effects = FoundryMath.effects(flow);
	f.Effects = {
		Production: math.min(1e300, effects.Production),
		Tap: math.min(1e300, effects.Tap),
		Capacity: math.min(1e300, effects.Capacity),
		Offline: effects.Offline,
	};
	f.ShardRate = FoundryMath.shardRate(flow);
	f.Delivered = (flow as FoundryFlow).Delivered;
	f.Version = (tonumber(f.Version) ?? 0) + 1;
	return flow;
}

interface Slot {
	bench: boolean;
	index?: number;
	key?: string;
	piece?: FoundryPiece;
}

// where a piece comes from or goes to: a board cell "q,r" or a bench slot "bench:N"
function slot(f: FoundrySave, ref: unknown): Slot | undefined {
	if (!typeIs(ref, "string") || ref.size() > 16) {
		return undefined;
	}
	const [index] = string.match(ref, "^bench:(%d+)$");
	if (index !== undefined) {
		const i = tonumber(index);
		if (i !== undefined && i >= 1 && i <= FoundryMath.BENCH_CAP) {
			return { bench: true, index: i, piece: f.Bench[i - 1] };
		}
		return undefined;
	}
	const [q, r] = FoundryMath.parse(ref);
	if (q === undefined || r === undefined || !FoundryMath.onBoard(f.Radius, q, r)) {
		return undefined;
	}
	const key = FoundryMath.key(q, r);
	return { bench: false, key: key, piece: f.Pieces[key] as FoundryPiece | undefined };
}

function take(f: FoundrySave, at: Slot): FoundryPiece | undefined {
	if (at.bench) {
		return f.Bench.remove(at.index! - 1);
	}
	const piece = f.Pieces[at.key!] as FoundryPiece | undefined;
	f.Pieces[at.key!] = undefined;
	return piece;
}

function put(f: FoundrySave, at: Slot, piece: FoundryPiece): boolean {
	if (at.bench) {
		if (f.Bench.size() >= FoundryMath.BENCH_CAP) {
			return false;
		}
		f.Bench.insert(math.min(at.index! - 1, f.Bench.size()), piece);
		return true;
	}
	f.Pieces[at.key!] = piece;
	return true;
}

const FoundryService = {
	MAX_SHARDS,
	MAX_ACCRUE_SECONDS,

	// the save is always valid after this: bad cells, bad pieces and impossible numbers are dropped
	Ensure(this: void, profile: Profile, now?: number): FoundrySave {
		const clock = now ?? os.time();
		let f = profile.Foundry as FoundrySave | undefined;
		if (!typeIs(f, "table") || f.Migrated !== true) {
			const continuum = typeIs(profile.Continuum, "table")
				? (profile.Continuum as Record<string, unknown>)
				: {};
			const anomaly = typeIs(profile.Anomaly, "table") ? (profile.Anomaly as Record<string, unknown>) : {};
			const [board, bench, shards] = FoundryMath.migrate(
				finite(continuum.Rank, 0),
				finite(anomaly.Fragments, 0),
				finite(anomaly.Stabilizations, 0),
			);
			f = {
				Migrated: true,
				Radius: board.Radius,
				Pieces: board.Pieces,
				Bench: bench as FoundryPiece[],
				Shards: shards,
				Draws: 0,
				Combo: 0,
				BestCombo: 0,
				IgniteAt: clock,
				SurgeEndsAt: 0,
				LastAt: clock,
				Version: 0,
			};
			profile.Foundry = f;
		}
		f.Radius = math.clamp(
			math.floor(finite(f.Radius, FoundryMath.MIN_RADIUS)),
			FoundryMath.MIN_RADIUS,
			FoundryMath.MAX_RADIUS,
		);
		const clean: Record<string, unknown> = {};
		if (typeIs(f.Pieces, "table")) {
			for (const [key, piece] of pairs(f.Pieces)) {
				let q: number | undefined;
				let r: number | undefined;
				if (typeIs(key, "string")) {
					[q, r] = FoundryMath.parse(key);
				}
				if (
					q !== undefined &&
					r !== undefined &&
					FoundryMath.onBoard(f.Radius, q, r) &&
					FoundryMath.validPiece(piece)
				) {
					const safePiece = piece as FoundryPiece;
					clean[FoundryMath.key(q, r)] = { Kind: safePiece.Kind, Tier: safePiece.Tier, Facing: safePiece.Facing };
				}
			}
		}
		f.Pieces = clean;
		const bench: FoundryPiece[] = [];
		if (typeIs(f.Bench, "table")) {
			for (const piece of f.Bench) {
				if (bench.size() < FoundryMath.BENCH_CAP && FoundryMath.validPiece(piece)) {
					const safePiece = piece as FoundryPiece;
					bench.push({ Kind: safePiece.Kind, Tier: safePiece.Tier, Facing: safePiece.Facing });
				}
			}
		}
		f.Bench = bench;
		f.Shards = math.clamp(finite(f.Shards, 0), 0, MAX_SHARDS);
		// saves converted before the conversion was capped could start with trillions of Shards
		if (f.ShardsCapped !== true) {
			f.ShardsCapped = true;
			f.Shards = math.min(f.Shards, 60_000);
		}
		f.Draws = math.clamp(math.floor(finite(f.Draws, 0)), 0, 10_000);
		f.Combo = math.clamp(math.floor(finite(f.Combo, 0)), 0, 1000);
		f.BestCombo = math.clamp(math.floor(finite(f.BestCombo, 0)), 0, 1_000_000);
		f.IgniteAt = finite(f.IgniteAt, clock);
		f.SurgeEndsAt = finite(f!.SurgeEndsAt, 0);
		f.LastAt = math.min(finite(f.LastAt, clock), clock);
		recompute(f);
		return f;
	},

	// passive Shards since the last visit (capped so a long absence is not a jackpot)
	Accrue(this: void, f: FoundrySave, now: number): void {
		const elapsed = math.clamp(now - finite(f.LastAt, now), 0, MAX_ACCRUE_SECONDS);
		f.Shards = math.min(MAX_SHARDS, f.Shards + finite(f.ShardRate, 0) * elapsed);
		f.LastAt = now;
	},

	// One move. Returns ok, message, extra (extra.Sound names the cue the client should play).
	Act(this: void, profile: Profile, payload: unknown, random: Random, now: number): LuaTuple<[boolean, string?, Record<string, unknown>?]> {
		const f = FoundryService.Ensure(profile, now);
		FoundryService.Accrue(f, now);
		if (!typeIs(payload, "table") || !typeIs((payload as Record<string, unknown>).Op, "string")) {
			return $tuple(false, "That foundry move is not valid.", undefined);
		}
		const payloadTable = payload as Record<string, unknown>;
		const op = payloadTable.Op as string;
		if (op === "place" || op === "move" || op === "fuse" || op === "store") {
			const from = slot(f, payloadTable.From);
			const to =
				op === "store"
					? { bench: true as boolean, index: f.Bench.size() + 1 }
					: slot(f, payloadTable.To);
			if (from === undefined || to === undefined || from.piece === undefined) {
				return $tuple(false, "Pick a piece and a free cell.", undefined);
			}
			if (!from.bench && !to.bench && from.key === to.key) {
				return $tuple(false, "That piece is already there.", undefined);
			}
			const moving = from.piece;
			const target = to.bench ? undefined : to.piece;
			if (target !== undefined) {
				if (!FoundryMath.canFuse(moving, target)) {
					return $tuple(false, "Only two identical pieces can fuse.", undefined);
				}
				take(f, from);
				f.Pieces[to.key!] = { Kind: target.Kind, Tier: target.Tier + 1, Facing: target.Facing };
				recompute(f);
				return $tuple(
					true,
					"Fused into a tier " + (target.Tier + 1) + " " + target.Kind + ".",
					{ Sound: "foundryFuse", Cell: to.key },
				);
			}
			if (to.bench && f.Bench.size() >= FoundryMath.BENCH_CAP && !from.bench) {
				return $tuple(false, "The bench is full.", undefined);
			}
			const piece = take(f, from);
			if (piece === undefined) {
				return $tuple(false, "That foundry move is not valid.", undefined);
			}
			if (!put(f, to, piece)) {
				put(f, from, piece);
				return $tuple(false, "The bench is full.", undefined);
			}
			recompute(f);
			return $tuple(true, undefined, {
				Sound: to.bench ? "foundryPickUp" : "foundryPlace",
				Cell: to.key,
			});
		} else if (op === "rotate") {
			const at = slot(f, payloadTable.At);
			if (at === undefined || at.bench || at.piece === undefined) {
				return $tuple(false, "Pick a piece on the board.", undefined);
			}
			const steps = payloadTable.Back === true ? 5 : 1;
			at.piece.Facing = (at.piece.Facing + steps) % 6;
			recompute(f);
			return $tuple(true, undefined, { Sound: "foundryRotate", Cell: at.key });
		} else if (op === "draw") {
			if (f.Bench.size() >= FoundryMath.BENCH_CAP) {
				return $tuple(false, "Make room on the bench first.", undefined);
			}
			const cost = FoundryMath.drawCost(f.Draws);
			if (f.Shards < cost) {
				return $tuple(false, "You need " + math.ceil(cost - f.Shards) + " more Shards.", undefined);
			}
			f.Shards -= cost;
			f.Draws += 1;
			const piece = FoundryMath.draw(
				random.NextNumber(),
				random.NextNumber(),
				FoundryMath.bestTier({ Radius: f.Radius, Pieces: f.Pieces }, f.Bench),
			);
			f.Bench.push(piece);
			const rare = piece.Tier > 1;
			return $tuple(
				true,
				"New " + piece.Kind + (rare ? " (tier " + piece.Tier + ")" : "") + ".",
				{ Sound: rare ? "foundryDrawRare" : "foundryDraw", Piece: piece },
			);
		} else if (op === "expand") {
			const cost = FoundryMath.expandCost(f.Radius);
			if (cost === undefined) {
				return $tuple(false, "The foundry is as big as it gets.", undefined);
			}
			if (f.Shards < cost) {
				return $tuple(false, "You need " + math.ceil(cost - f.Shards) + " more Shards.", undefined);
			}
			f.Shards -= cost;
			f.Radius += 1;
			recompute(f);
			return $tuple(
				true,
				"The foundry grew to " + FoundryMath.cellCount(f.Radius) + " cells.",
				{ Sound: "foundryExpand" },
			);
		} else if (op === "ignite") {
			const board: FoundryBoard = { Radius: f.Radius, Pieces: f.Pieces };
			const phase = FoundryMath.wavePhase(f.IgniteAt, now);
			const target = FoundryMath.targetPhase(board);
			if (!FoundryMath.onBeat(phase, target)) {
				f.Combo = 0;
				return $tuple(true, undefined, { Sound: "foundryIgniteMiss", OnBeat: false });
			}
			f.Combo += 1;
			f.BestCombo = math.max(f.BestCombo, f.Combo);
			const flow = FoundryMath.flow(board);
			const gained = FoundryMath.igniteShards(flow, f.Combo);
			f.Shards = math.min(MAX_SHARDS, f.Shards + gained);
			let surged = false;
			if (f.Combo % FoundryMath.IGNITE_SURGE_AT === 0) {
				f.SurgeEndsAt = now + FoundryMath.IGNITE_SURGE_SECONDS;
				surged = true;
			}
			return $tuple(true, undefined, {
				Sound: surged ? "foundrySurge" : "foundryIgnite",
				OnBeat: true,
				Gained: gained,
				Combo: f.Combo,
			});
		}
		return $tuple(false, "That foundry move is not valid.", undefined);
	},

	// the economy's view: production, capacity, tap multipliers and the offline bonus (Ignite surge applied)
	Effects(this: void, profile: Profile, now?: number): LuaTuple<[number, number, number, number]> {
		const f = typeIs(profile, "table") ? (profile.Foundry as FoundrySave | undefined) : undefined;
		const e = typeIs(f, "table") && typeIs(f.Effects, "table") ? (f.Effects as FoundryEffects) : undefined;
		if (e === undefined) {
			return $tuple(1, 1, 1, 0);
		}
		const surge = finite(f!.SurgeEndsAt, 0) > (now ?? os.time()) ? FoundryMath.IGNITE_SURGE : 1;
		function boosted(value: number): number {
			const v = math.max(1, finite(value, 1));
			return math.min(1e300, 1 + (v - 1) * surge);
		}
		return $tuple(
			boosted(e.Production),
			boosted(e.Capacity),
			boosted(e.Tap),
			math.clamp(finite(e.Offline, 0), 0, 0.45),
		);
	},

	// what the client sees
	State(this: void, profile: Profile, now: number): Record<string, unknown> | undefined {
		const f = profile.Foundry as FoundrySave | undefined;
		if (!typeIs(f, "table") || f.Migrated !== true) {
			return undefined;
		}
		const pending = math.clamp(now - finite(f.LastAt, now), 0, MAX_ACCRUE_SECONDS) * finite(f.ShardRate, 0);
		const [production, capacity, tap, offline] = FoundryService.Effects(profile, now);
		return {
			Radius: f.Radius,
			Pieces: f.Pieces,
			Bench: f.Bench,
			Shards: math.floor(math.min(MAX_SHARDS, f.Shards + pending)),
			ShardRate: f.ShardRate,
			DrawCost: FoundryMath.drawCost(f.Draws),
			ExpandCost: FoundryMath.expandCost(f.Radius),
			Combo: f.Combo,
			BestCombo: f.BestCombo,
			IgniteAt: f.IgniteAt,
			SurgeEndsAt: f.SurgeEndsAt,
			Effects: { Production: production, Capacity: capacity, Tap: tap, Offline: offline },
			Version: f.Version,
		};
	},
};

export = table.freeze(FoundryService);

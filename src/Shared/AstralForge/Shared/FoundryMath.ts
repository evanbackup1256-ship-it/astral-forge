// Star Foundry: the rules, as pure functions (no Roblox services), shared by server, client and tests.
//
// A hex board (axial coordinates q, r). Pieces sit on cells and face one of six sides:
//   Ember    a source: emits energy out of its facing side
//   Conduit  carries what it receives out of its facing side (a little loss, less at higher tiers)
//   Lens     focuses everything it receives out of its facing side, stronger
//   Prism    splits what it receives three ways (facing, facing+2, facing+4)
//   Anvils   sinks that turn the energy reaching them into a bonus:
//            ForgeAnvil -> production, StrikeAnvil -> tap, VaultAnvil -> capacity, EchoAnvil -> offline
// Two identical pieces (kind and tier) fuse into one of the next tier.
//
// Flow is computed, not simulated: every Ember sends its energy along the board, a piece is
// crossed at most once per path (so loops cannot amplify forever), paths stop after MAX_HOPS,
// trickles below MIN_FLOW are dropped and the whole walk has a hard STEP_BUDGET. Traversal order
// is fixed (cells sorted, faces in order), so server and client always get the same answer.

interface Piece {
	Kind: string;
	Tier: number;
	Facing: number;
}

interface Board {
	Radius: number;
	Pieces: Record<string, Piece>;
}

interface Flow {
	Production: number;
	Tap: number;
	Capacity: number;
	Offline: number;
	Delivered: number;
	Wasted: number;
	Links: { from: string; to: string; amount: number }[];
	Lit: Record<string, number>;
}

const MIN_RADIUS = 2;
const MAX_RADIUS = 5;
const MAX_HOPS = 24;
const MIN_FLOW = 0.01;
const STEP_BUDGET = 6000;
const MAX_TIER = 40;
const BENCH_CAP = 12;
const EMBER_BASE = 10;
const TIER_GROWTH = 2.2;

const KINDS: Record<string, { role: string; stat?: string }> = table.freeze({
	Ember: table.freeze({ role: "source" }),
	Conduit: table.freeze({ role: "relay" }),
	Lens: table.freeze({ role: "relay" }),
	Prism: table.freeze({ role: "split" }),
	ForgeAnvil: table.freeze({ role: "sink", stat: "Production" }),
	StrikeAnvil: table.freeze({ role: "sink", stat: "Tap" }),
	VaultAnvil: table.freeze({ role: "sink", stat: "Capacity" }),
	EchoAnvil: table.freeze({ role: "sink", stat: "Offline" }),
});

// what a draw from the shop can give, by weight
const DRAW_WEIGHTS: ReadonlyArray<[string, number]> = table.freeze([
	["Ember", 22],
	["Conduit", 26],
	["Lens", 12],
	["Prism", 10],
	["ForgeAnvil", 12],
	["StrikeAnvil", 7],
	["VaultAnvil", 7],
	["EchoAnvil", 4],
]);

// axial neighbours, clockwise from east
const DIRECTIONS: ReadonlyArray<[number, number]> = table.freeze([
	[1, 0],
	[1, -1],
	[0, -1],
	[-1, 0],
	[-1, 1],
	[0, 1],
]);

function key(q: number, r: number): string {
	return `${q},${r}`;
}

function parse(key: string): LuaTuple<[number | undefined, number | undefined]> {
	const [q, r] = key.match("^(%-?%d+),(%-?%d+)$");
	return $tuple(tonumber(q), tonumber(r));
}

function onBoard(radius: number, q: number, r: number): boolean {
	const s = -q - r;
	return math.max(math.abs(q), math.abs(r), math.abs(s)) <= radius;
}

function cellCount(radius: number): number {
	return 3 * radius * (radius + 1) + 1;
}

function cells(radius: number): string[] {
	const list: string[] = [];
	for (let q = -radius; q <= radius; q++) {
		for (let r = -radius; r <= radius; r++) {
			if (onBoard(radius, q, r)) {
				list.push(key(q, r));
			}
		}
	}
	list.sort();
	return list;
}

function validPiece(piece: unknown): boolean {
	return (
		typeIs(piece, "table") &&
		typeIs((piece as Piece).Kind, "string") &&
		KINDS[(piece as Piece).Kind] !== undefined &&
		typeIs((piece as Piece).Tier, "number") &&
		(piece as Piece).Tier === math.floor((piece as Piece).Tier) &&
		(piece as Piece).Tier >= 1 &&
		(piece as Piece).Tier <= MAX_TIER &&
		typeIs((piece as Piece).Facing, "number") &&
		(piece as Piece).Facing === math.floor((piece as Piece).Facing) &&
		(piece as Piece).Facing >= 0 &&
		(piece as Piece).Facing <= 5
	);
}

// how strong a piece is at a tier
function tierScale(tier: number): number {
	return TIER_GROWTH ** (math.clamp(tier, 1, MAX_TIER) - 1);
}

function emberOutput(tier: number): number {
	return EMBER_BASE * tierScale(tier);
}

function relayGain(piece: Piece): number {
	const t = math.clamp(piece.Tier, 1, MAX_TIER) - 1;
	if (piece.Kind === "Conduit") {
		return math.min(1.25, 0.92 + 0.04 * t);
	} else if (piece.Kind === "Lens") {
		return 1.8 * 1.12 ** t;
	} else if (piece.Kind === "Prism") {
		return 0.6 * 1.12 ** t;
	}
	return 0;
}

function sinkGain(piece: Piece): number {
	return 1.1 ** (math.clamp(piece.Tier, 1, MAX_TIER) - 1);
}

function outputs(piece: Piece): number[] {
	if (piece.Kind === "Prism") {
		return [piece.Facing, (piece.Facing + 2) % 6, (piece.Facing + 4) % 6];
	}
	return [piece.Facing];
}

function flow(board: Board): Flow {
	const radius = math.clamp(
		math.floor((tonumber(board.Radius) ?? MIN_RADIUS) as number),
		MIN_RADIUS,
		MAX_RADIUS,
	);
	const pieces = board.Pieces ?? {};
	const result: Flow = {
		Production: 0,
		Tap: 0,
		Capacity: 0,
		Offline: 0,
		Delivered: 0,
		Wasted: 0,
		Links: [],
		Lit: {},
	};
	const linkIndex: Record<string, number> = {};
	let steps = 0;
	function addLink(from: string, to: string, amount: number): void {
		const id = from + ">" + to;
		const at = linkIndex[id];
		if (at === undefined) {
			result.Links.push({ from, to, amount });
			linkIndex[id] = result.Links.size() - 1;
		} else {
			result.Links[at].amount += amount;
		}
		result.Lit[to] = (result.Lit[to] ?? 0) + amount;
	}
	const visiting: Record<string, boolean> = {};
	function send(fromKey: string, q: number, r: number, direction: number, amount: number, hops: number): void {
		steps += 1;
		if (steps > STEP_BUDGET || amount < MIN_FLOW) {
			result.Wasted += math.max(0, amount);
			return;
		}
		const d = DIRECTIONS[direction];
		const nq = q + d[0];
		const nr = r + d[1];
		const targetKey = key(nq, nr);
		const target = pieces[targetKey];
		if (
			!onBoard(radius, nq, nr) ||
			target === undefined ||
			!validPiece(target) ||
			visiting[targetKey] ||
			hops >= MAX_HOPS
		) {
			result.Wasted += amount;
			return;
		}
		addLink(fromKey, targetKey, amount);
		const role = KINDS[target.Kind].role;
		if (role === "sink") {
			const stat = KINDS[target.Kind].stat!;
			const gained = amount * sinkGain(target);
			(result as unknown as Record<string, number>)[stat] += gained;
			result.Delivered += gained;
			return;
		}
		if (role === "source") {
			// an ember is not a relay: what reaches it is lost
			result.Wasted += amount;
			return;
		}
		visiting[targetKey] = true;
		const gain = relayGain(target);
		for (const side of outputs(target)) {
			send(targetKey, nq, nr, side, amount * gain, hops + 1);
		}
		visiting[targetKey] = false;
	}
	const keys: string[] = [];
	for (const [k] of pairs(pieces)) {
		keys.push(k);
	}
	keys.sort();
	for (const k of keys) {
		const piece = pieces[k];
		const [q, r] = parse(k);
		if (
			q !== undefined &&
			r !== undefined &&
			onBoard(radius, q, r) &&
			validPiece(piece) &&
			piece.Kind === "Ember"
		) {
			visiting[k] = true;
			send(k, q, r, piece.Facing, emberOutput(piece.Tier), 0);
			visiting[k] = false;
		}
	}
	return result;
}

// what the energy is worth to the economy
function effects(flowResult: Flow, surge?: number): { Production: number; Tap: number; Capacity: number; Offline: number } {
	const boost = math.max(1, surge ?? 1);
	return {
		Production: 1 + flowResult.Production * boost / 10,
		Tap: 1 + flowResult.Tap * boost / 10,
		Capacity: 1 + flowResult.Capacity * boost / 12,
		Offline: math.min(0.45, flowResult.Offline * boost / 400),
	};
}

// shards earned per second from everything the board delivers
function shardRate(flowResult: Flow): number {
	return math.sqrt(math.max(0, flowResult.Delivered)) * 0.02;
}

function drawCost(draws: number): number {
	return math.floor(25 * 1.32 ** math.max(0, draws));
}

function expandCost(radius: number): number | undefined {
	if (radius >= MAX_RADIUS) {
		return undefined;
	}
	return math.floor(400 * 6 ** (radius - MIN_RADIUS));
}

// a draw: weighted kind; tier 1 most of the time, with a small chance of a better piece
function draw(roll: number, tierRoll: number, bestTier: number): Piece {
	let total = 0;
	for (const entry of DRAW_WEIGHTS) {
		total += entry[1];
	}
	let pick = roll * total;
	let kind = DRAW_WEIGHTS[0][0];
	for (const entry of DRAW_WEIGHTS) {
		pick -= entry[1];
		if (pick <= 0) {
			kind = entry[0];
			break;
		}
	}
	let tier = 1;
	if (tierRoll > 0.97) {
		tier = math.max(1, math.floor(bestTier * 0.6));
	} else if (tierRoll > 0.85) {
		tier = 2;
	}
	return { Kind: kind, Tier: math.clamp(tier, 1, MAX_TIER), Facing: 0 };
}

function canFuse(a: Piece | undefined, b: Piece | undefined): boolean {
	return a !== undefined && b !== undefined && a.Kind === b.Kind && a.Tier === b.Tier && a.Tier < MAX_TIER;
}

function bestTier(board: Board, bench?: Piece[]): number {
	let best = 1;
	for (const [, piece] of pairs(board.Pieces ?? {})) {
		best = math.max(best, piece.Tier);
	}
	for (const piece of bench ?? []) {
		best = math.max(best, piece.Tier);
	}
	return best;
}

// Ignite: a wave sweeps round the board every PERIOD seconds; tapping while it crosses the target
// angle (within WINDOW of a turn) is on beat.
const IGNITE_PERIOD = 2.4;
const IGNITE_WINDOW = 0.07;
const IGNITE_SURGE_AT = 10;
const IGNITE_SURGE_SECONDS = 60;
const IGNITE_SURGE = 1.5;

function wavePhase(startedAt: number, now: number): number {
	return ((now - startedAt) / IGNITE_PERIOD) % 1;
}

function targetPhase(board: Board): number {
	// the angle of the brightest anvil (or 0 with none), as a fraction of a turn
	const flowResult = flow(board);
	let best = -1;
	let bestKey: string | undefined = undefined;
	for (const [key, amount] of pairs(flowResult.Lit)) {
		const piece = (board.Pieces ?? {})[key];
		if (piece && KINDS[piece.Kind].role === "sink" && amount > best) {
			best = amount;
			bestKey = key;
		}
	}
	if (bestKey === undefined) {
		return 0;
	}
	const [q, r] = parse(bestKey);
	if (q === undefined || r === undefined) {
		return 0;
	}
	const x = 1.5 * q;
	const y = math.sqrt(3) * (r + q / 2);
	return (math.atan2(y, x) / (2 * math.pi)) % 1;
}

function onBeat(phase: number, target: number): boolean {
	const delta = math.abs(phase - target);
	return math.min(delta, 1 - delta) <= IGNITE_WINDOW;
}

function igniteShards(flowResult: Flow, combo: number): number {
	return math.max(1, math.floor((5 + shardRate(flowResult) * 6) * (1 + 0.1 * math.min(combo, 20))));
}

// Old saves: a Continuum rank and Reactor progress become a starter board worth about as much,
// plus Shards. Returns the board, bench and shards to grant.
function migrate(
	continuumRank: number,
	anomalyFragments: number,
	stabilizations: number,
): LuaTuple<[Board, Piece[], number]> {
	const rank = math.max(0, math.floor(continuumRank));
	// the old production multiplier was 1.16^rank (x1.5 every 25 ranks)
	const oldProduction = 1.16 ** rank * 1.5 ** math.floor(rank / 25);
	const needed = math.max(0, (oldProduction - 1) * 10);
	// ember -> conduit -> forge anvil delivers emberOutput * 0.92
	let tier = 1;
	while (tier < MAX_TIER && emberOutput(tier) * 0.92 < needed) {
		tier += 1;
	}
	const pieces: Record<string, Piece> = {
		["-1,0"]: { Kind: "Ember", Tier: tier, Facing: 0 },
		["0,0"]: { Kind: "Conduit", Tier: 1, Facing: 0 },
		["1,0"]: { Kind: "ForgeAnvil", Tier: 1, Facing: 0 },
	};
	const bench: Piece[] = [
		{ Kind: "Ember", Tier: 1, Facing: 0 },
		{ Kind: "StrikeAnvil", Tier: 1, Facing: 0 },
	];
	// old progress converts, capped: enough for a strong start, not enough to skip the game
	const fragments = math.clamp(anomalyFragments, 0, 2000);
	const stabilized = math.clamp(stabilizations, 0, 400);
	const shards = math.floor(fragments * 4 + stabilized * 25 + math.min(rank, 200) * 30);
	return $tuple(
		{ Radius: MIN_RADIUS + (rank >= 40 ? 1 : 0), Pieces: pieces },
		bench,
		shards,
	);
}

const FoundryMath = {
	MIN_RADIUS,
	MAX_RADIUS,
	MAX_HOPS,
	MIN_FLOW,
	STEP_BUDGET,
	MAX_TIER,
	BENCH_CAP,
	EMBER_BASE,
	TIER_GROWTH,
	KINDS,
	DRAW_WEIGHTS,
	DIRECTIONS,
	key,
	parse,
	onBoard,
	cellCount,
	cells,
	validPiece,
	tierScale,
	emberOutput,
	flow,
	effects,
	shardRate,
	drawCost,
	expandCost,
	draw,
	canFuse,
	bestTier,
	IGNITE_PERIOD,
	IGNITE_WINDOW,
	IGNITE_SURGE_AT,
	IGNITE_SURGE_SECONDS,
	IGNITE_SURGE,
	wavePhase,
	targetPhase,
	onBeat,
	igniteShards,
	migrate,
};

export = table.freeze(FoundryMath);

// Lab: lab orders and power routing (stateless functions over a profile).
import { Dict, d, economyKit, num, req, SharedFolder } from "../LuaInterop";
import LabOrderMath from "../../Modules/LabOrderMath";

type Kit = Record<string, (this: void, ...args: unknown[]) => unknown>;
type Profile = Dict;

interface GameConfigShape {
	Lab: Dict;
	MaxZone: number;
	[key: string]: unknown;
}

const Economy = economyKit("Economy") as Kit;
const GameConfig = req<GameConfigShape>(SharedFolder().WaitForChild("GameConfig"));

const LabService: Dict = {};

const orderById: Record<string, Dict> = {};
for (const order of GameConfig.Lab.Orders as Dict[]) {
	orderById[order.Id as string] = order;
}

const channelOrder = LabOrderMath.CHANNEL_ORDER;

function utcDay(): number {
	return math.floor(os.time() / 86_400);
}

function ensureLab(profile: Profile): Dict {
	profile.Lab = LabOrderMath.Ensure(profile.Lab, num(d(GameConfig.Lab.Power).BaseCells));
	return d(profile.Lab);
}

function totalCells(profile: Profile): number {
	return LabOrderMath.TotalCells(
		num(profile.Rebirths) ?? 0,
		num(d(GameConfig.Lab.Power).BaseCells) ?? 0,
		num(d(GameConfig.Lab.Power).RebirthsPerCell) ?? 0,
		num(d(GameConfig.Lab.Power).MaxCells) ?? 0,
	);
}

function normalizeRouting(profile: Profile): boolean {
	const lab = ensureLab(profile);
	return LabOrderMath.NormalizeRouting(lab.Routing as Record<string, number>, channelOrder, totalCells(profile));
}

function orderTarget(profile: Profile, order: Dict): number {
	let bankFluxTarget: number | undefined;
	if (order.Kind === "BankFlux") {
		const steady = Economy.SteadyProduction(profile);
		bankFluxTarget = num(Economy.AsNumber(Economy.Mul(steady, order.ProductionSeconds))) ?? 0;
	}
	return LabOrderMath.OrderTarget(order as never, math.max(0, num(profile.Rebirths) ?? 0), bankFluxTarget);
}

function rollOrders(profile: Profile, day: number, userId: number) {
	const available: number[] = table.create((GameConfig.Lab.Orders as Dict[]).size());
	const definitions = GameConfig.Lab.Orders as Dict[];
	for (const [index, definition] of pairs(definitions)) {
		if (definition.Kind !== "UnlockWorld" || (num(profile.Zone) ?? 0) < GameConfig.MaxZone) {
			available.push(index as number);
		}
	}
	const seed = math.abs((day * 48_271 + userId * 69_621 + 17) % 2_147_483_647);
	const random = new Random(seed);
	const rolled: Dict[] = [];
	for (let slot = 1; slot <= math.min(num(GameConfig.Lab.OrderCount) ?? 0, available.size()); slot++) {
		const pick = random.NextInteger(1, available.size());
		const definition = definitions[available[pick - 1] - 1];
		available.remove(pick - 1);
		rolled[slot - 1] = {
			Id: definition.Id,
			Progress: 0,
			Target: orderTarget(profile, definition),
			Claimed: false,
		};
	}
	d(profile.Lab).Day = day;
	d(profile.Lab).Orders = rolled;
}

function Ensure(profile: Profile, userId: number): boolean {
	const lab = ensureLab(profile);
	let changed = normalizeRouting(profile);
	const day = utcDay();
	if (lab.Day !== day) {
		rollOrders(profile, day, userId);
		changed = true;
	} else {
		const seen: Record<string, boolean> = {};
		let count = 0;
		let invalid = false;
		for (const [index, state] of pairs(lab.Orders as object)) {
			count += 1;
			const stateBag = state as Dict;
			if (
				!typeIs(index, "number") ||
				index !== math.floor(index) ||
				index < 1 ||
				index > (num(GameConfig.Lab.OrderCount) ?? 0) ||
				!typeIs(state, "table") ||
				!orderById[stateBag.Id as string] ||
				seen[stateBag.Id as string]
			) {
				rollOrders(profile, day, userId);
				changed = true;
				invalid = true;
				break;
			}
			seen[stateBag.Id as string] = true;
		}
		if (!invalid && count !== (num(GameConfig.Lab.OrderCount) ?? 0)) {
			rollOrders(profile, day, userId);
			changed = true;
		}
	}
	return changed;
}
LabService.Ensure = Ensure;

function Progress(profile: Profile, kind: string, amount: number): boolean {
	const lab = ensureLab(profile);
	return LabOrderMath.ApplyProgress(lab.Orders as never[], orderById as never, kind, amount);
}
LabService.Progress = Progress;

function ClaimOrder(profile: Profile, orderId: string): LuaTuple<[boolean, string, unknown]> {
	const lab = ensureLab(profile);
	const orders = lab.Orders;
	if (!typeIs(orders, "table")) {
		return $tuple(false, "That order is no longer on the board.", undefined);
	}
	const [ok, message, reward] = LabOrderMath.TryClaim(orders as never[], orderById as never, orderId);
	if (ok) {
		if (!typeIs(profile.Stats, "table")) {
			profile.Stats = { OrdersCompleted: 0 };
		}
		d(profile.Stats).OrdersCompleted =
			math.max(0, math.floor(num(d(profile.Stats).OrdersCompleted) ?? 0)) + 1;
	}
	return $tuple(ok, message, reward);
}
LabService.ClaimOrder = ClaimOrder;

function RoutePower(profile: Profile, channelId: string, delta: number): LuaTuple<[boolean, string]> {
	if (!d(d(GameConfig.Lab.Power).Channels)[channelId]) {
		return $tuple(false, "That power rail does not exist.");
	}
	if (delta !== -1 && delta !== 1) {
		return $tuple(false, "Move one cell at a time.");
	}
	const lab = ensureLab(profile);
	normalizeRouting(profile);
	const total = totalCells(profile);
	const routing = lab.Routing as Record<string, number>;
	let used = 0;
	for (const id of channelOrder) {
		used += routing[id];
	}
	const current = routing[channelId];
	if (delta > 0 && used >= total) {
		return $tuple(false, "All cells are already assigned. Free one first.");
	}
	if (delta < 0 && current <= 0) {
		return $tuple(false, "That rail is already empty.");
	}
	routing[channelId] = current + delta;
	if (!typeIs(profile.Stats, "table")) {
		profile.Stats = { PowerMoves: 0 };
	}
	d(profile.Stats).PowerMoves = math.max(0, math.floor(num(d(profile.Stats).PowerMoves) ?? 0)) + 1;
	return $tuple(true, delta > 0 ? "Power cell assigned." : "Power cell returned.");
}
LabService.RoutePower = RoutePower;

function PowerEffect(profile: Profile, channelId: string): number {
	const channel = d(d(GameConfig.Lab.Power).Channels)[channelId] as Dict | undefined;
	if (!channel) {
		return 0;
	}
	// count only cells the player still owns (rebirth-based cell count can drop after an
	// ascension before the routing is next normalized), filled in channel order like State()
	const lab = ensureLab(profile);
	const routingBag = lab.Routing as Record<string, number>;
	let left = totalCells(profile);
	for (const id of channelOrder) {
		const raw = routingBag[id];
		const cells = typeIs(raw, "number") && raw === raw && raw < math.huge ? math.clamp(math.floor(raw), 0, math.max(0, left)) : 0;
		if (id === channelId) {
			return cells * (num(channel.EffectPerCell) ?? 0);
		}
		left -= cells;
	}
	return 0;
}
LabService.PowerEffect = PowerEffect;

function State(profile: Profile): Dict {
	const lab = ensureLab(profile);
	const total = totalCells(profile);
	let used = 0;
	const routing: Record<string, number> = {};
	const effects: Record<string, number> = {};
	for (const channelId of channelOrder) {
		const raw = (lab.Routing as Record<string, number>)[channelId];
		const value =
			typeIs(raw, "number") && raw === raw && raw !== math.huge && raw !== -math.huge
				? math.clamp(math.floor(raw), 0, math.max(0, total - used))
				: 0;
		routing[channelId] = value;
		const channel = d(d(GameConfig.Lab.Power).Channels)[channelId] as Dict | undefined;
		effects[channelId] = channel ? value * (num(channel.EffectPerCell) ?? 0) : 0;
		used += value;
	}
	const orders: Dict[] = table.create((lab.Orders as Dict[]).size());
	for (const [index, state] of pairs(lab.Orders as Dict[])) {
		const stateBag = state as Dict;
		orders[(index as number) - 1] = {
			Id: stateBag.Id,
			Progress: stateBag.Progress,
			Target: stateBag.Target,
			Claimed: stateBag.Claimed,
		};
	}
	return {
		Day: lab.Day,
		ResetAt: (utcDay() + 1) * 86_400,
		Orders: orders,
		Routing: routing,
		Effects: effects,
		TotalCells: total,
		AvailableCells: math.max(0, total - used),
	};
}
LabService.State = State;

export = table.freeze(LabService);

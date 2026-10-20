// Server events: every few minutes the whole server gets one. Each event below does exactly what
// its text says; the numbers here are the rules the server applies and the screen shows.
//   Kind "mod"    changes how the forge behaves (production, overcharge, crits, combo, collects)
//   Kind "drops"  vault collects drop something extra
//   Kind "goal"   the server fills one shared order together
//   Kind "titan"  the server beats down one shared health bar
//   Kind "race"   collects score points; the top three win
//   Kind "draw"   collects earn tickets; three are drawn at the end
//   Kind "stars"  stars fall across everyone's screen; catch them
//   Kind "supply" crates drop a few times; the first three to grab each one win it

type Dict = Record<string, unknown>;

interface EventDef {
	Id: string;
	Name: string;
	Kind: string;
	Mods?: Record<string, number>;
	Drops?: { Dust?: number; CoreChance?: number; CoreMax?: number; KeyChance?: number; KeyCrate?: string };
}

interface State {
	Phase?: string;
	Id?: string;
	PhaseEndsAt: number;
	StartedAt?: number;
	LastId?: string;
}

const REST_SECONDS = 8 * 60;
const WARNING_SECONDS = 60;
const LIVE_SECONDS = 5 * 60;
const RESULTS_SECONDS = 20;
const FIRST_REST_SECONDS = 3 * 60;

function def<T extends object>(t: T): Readonly<T> {
	return table.freeze(t);
}
const EVENTS = table.freeze({
	MeteorShower: def({
		Id: "MeteorShower", Name: "Meteor Shower", Kind: "mod", Icon: "Boost.21", Accent: "mango",
		Blurb: "Meteors are hitting the forge.",
		How: "Every machine on the server makes 50% more while it lasts.",
		Mods: { Production: 1.5 },
	}),
	StardustRain: def({
		Id: "StardustRain", Name: "Stardust Rain", Kind: "drops", Icon: "Dust.15", Accent: "violet",
		Blurb: "Stardust is coming down over the forge.",
		How: "Every vault collect catches stardust. Bigger collects catch more, up to 25.",
		Drops: { Dust: 25 },
	}),
	CommunityForge: def({
		Id: "CommunityForge", Name: "Community Forge", Kind: "goal", Icon: "Crew.20", Accent: "cyan",
		Blurb: "The server has one big order to fill.",
		How: "Vault collects add points to the order. Fill it before time runs out and everyone who helped gets paid.",
		PointsPerPlayer: 900, MinGoal: 900, MaxPointsPerCollect: 600,
		RewardFluxSeconds: 300, RewardStardust: 30, TopBonusStardust: [ 40, 25, 15 ],
	}),
	Overheat: def({
		Id: "Overheat", Name: "Overheat", Kind: "mod", Icon: "Overcharge.13", Accent: "coral",
		Blurb: "The forge is running hot.",
		How: "Overcharge taps hit three times as hard.",
		Mods: { Tap: 3 },
	}),
	CriticalMass: def({
		Id: "CriticalMass", Name: "Critical Mass", Kind: "mod", Icon: "Jackpot.7", Accent: "pink",
		Blurb: "Every strike is close to splitting.",
		How: "Overcharge taps have a 25% better chance to crit.",
		Mods: { Crit: 0.25 },
	}),
	ComboFever: def({
		Id: "ComboFever", Name: "Combo Fever", Kind: "mod", Icon: "Timer.11", Accent: "mint",
		Blurb: "Your rhythm holds longer.",
		How: "Overcharge combos stay alive twice as long between taps.",
		Mods: { ComboWindow: 2 },
	}),
	TwinSuns: def({
		Id: "TwinSuns", Name: "Twin Suns", Kind: "mod", Icon: "StarGrid.7", Accent: "mango",
		Blurb: "Two suns are up over the forge.",
		How: "Production up 25% and overcharge taps up 50%.",
		Mods: { Production: 1.25, Tap: 1.5 },
	}),
	GoldenVault: def({
		Id: "GoldenVault", Name: "Golden Vault", Kind: "mod", Icon: "Vault.11", Accent: "mango",
		Blurb: "Vaults are paying out in gold.",
		How: "Every vault collect pays 50% extra flux on top.",
		Mods: { Collect: 0.5 },
	}),
	CoreSeam: def({
		Id: "CoreSeam", Name: "Core Seam", Kind: "drops", Icon: "Core.10", Accent: "violet",
		Blurb: "A seam of Cores runs under the forge.",
		How: "Vault collects have a 30% chance to dig up 1 to 3 Cores.",
		Drops: { CoreChance: 0.3, CoreMax: 3 },
	}),
	KeyCache: def({
		Id: "KeyCache", Name: "Key Cache", Kind: "drops", Icon: "Crate.20", Accent: "cyan",
		Blurb: "Someone left a box of keys in the vaults.",
		How: "Vault collects have a 15% chance to turn up a Forge crate key.",
		Drops: { KeyChance: 0.15, KeyCrate: "ForgeCrate" },
	}),
	IronTitan: def({
		Id: "IronTitan", Name: "The Iron Titan", Kind: "titan", Icon: "Forge.31", Accent: "coral",
		Blurb: "Something huge has walked into the forge.",
		How: "Overcharge taps hit it for 1 and vault collects hit it harder. Bring it down before time's up and everyone who hit it gets paid.",
		HealthPerPlayer: 500, MinHealth: 600, MaxCollectHit: 60, TapsPerSecond: 8,
		RewardFluxSeconds: 300, RewardStardust: 40, TopBonusStardust: [ 30, 20, 10 ], TopBonusCores: [ 3, 2, 1 ],
	}),
	ForgeRace: def({
		Id: "ForgeRace", Name: "Forge Race", Kind: "race", Icon: "Leaderboard.3", Accent: "cyan",
		Blurb: "Five minutes. Most banked wins.",
		How: "Vault collects score points. The top three when it ends win Stardust and Cores; everyone who scores gets a little.",
		MaxPointsPerCollect: 600,
		Prizes: [ { Stardust: 120, Cores: 6 }, { Stardust: 80, Cores: 4 }, { Stardust: 50, Cores: 2 } ],
		Consolation: { Stardust: 10 },
	}),
	LuckyDraw: def({
		Id: "LuckyDraw", Name: "Lucky Draw", Kind: "draw", Icon: "Gift.20", Accent: "pink",
		Blurb: "Tickets are on the counter.",
		How: "Every vault collect is a ticket, up to 25. Three tickets are drawn when it ends.",
		MaxTickets: 25, Winners: 3,
		Prize: { Stardust: 150, Cores: 5 },
		Consolation: { Stardust: 5 },
	}),
	FallingStars: def({
		Id: "FallingStars", Name: "Falling Stars", Kind: "stars", Icon: "Milestone.8", Accent: "mango",
		Blurb: "Stars are falling past the forge.",
		How: "Tap the stars as they fall. Each one is 3 Stardust, up to 40 stars.",
		DustPerStar: 3, MaxStars: 40, MinGap: 0.45,
	}),
	SupplyDrop: def({
		Id: "SupplyDrop", Name: "Supply Drop", Kind: "supply", Icon: "Crate.21", Accent: "mint",
		Blurb: "Supply crates are coming down.",
		How: "Four crates land during the event. The first three players to grab each one get a crate key and Stardust.",
		DropAt: [ 0.12, 0.38, 0.62, 0.86 ], DropSeconds: 12, ClaimsPerDrop: 3,
		Reward: { Keys: 1, KeyCrate: "ForgeCrate", Stardust: 25 },
	}),
});
const ORDER: ReadonlyArray<string> = table.freeze([
	"MeteorShower", "StardustRain", "CommunityForge", "Overheat", "CriticalMass", "ComboFever", "TwinSuns", "GoldenVault",
	"CoreSeam", "KeyCache", "IronTitan", "ForgeRace", "LuckyDraw", "FallingStars", "SupplyDrop",
]);
const BY_ID = EVENTS as unknown as Readonly<Record<string, EventDef | undefined>>;
const at = <T>(list: ReadonlyArray<T>, luaIndex: number) => (list as unknown as Record<number, T | undefined>)[luaIndex];

function pick(lastId: string | undefined, roll: number): string {
	const choices: string[] = [];
	for (const id of ORDER) {
		if (id !== lastId) {
			choices.push(id);
		}
	}
	const index = math.clamp(math.floor(roll * choices.size()) + 1, 1, choices.size());
	return choices[index - 1];
}

function advance(state: State | undefined, now: number, roll: number): LuaTuple<[State, boolean]> {
	if (state === undefined || state.Phase === undefined) {
		return $tuple({ Phase: "Rest", Id: undefined, PhaseEndsAt: now + FIRST_REST_SECONDS, LastId: undefined }, true);
	}
	if (now < state.PhaseEndsAt) {
		return $tuple(state, false);
	}
	if (state.Phase === "Rest") {
		const id = pick(state.LastId, roll);
		return $tuple({ Phase: "Warning", Id: id, PhaseEndsAt: now + WARNING_SECONDS, LastId: state.LastId }, true);
	} else if (state.Phase === "Warning") {
		return $tuple(
			{ Phase: "Live", Id: state.Id, PhaseEndsAt: now + LIVE_SECONDS, StartedAt: now, LastId: state.LastId },
			true,
		);
	} else if (state.Phase === "Live") {
		return $tuple({ Phase: "Results", Id: state.Id, PhaseEndsAt: now + RESULTS_SECONDS, LastId: state.Id }, true);
	}
	return $tuple({ Phase: "Rest", Id: undefined, PhaseEndsAt: now + REST_SECONDS, LastId: state.LastId }, true);
}

function liveDef(state: State | undefined): EventDef | undefined {
	if (state === undefined || state.Phase !== "Live" || state.Id === undefined) {
		return undefined;
	}
	return BY_ID[state.Id];
}
// a modifier of the live event, or the neutral value
function mod(state: State | undefined, name: string): number {
	const d = liveDef(state);
	const value = d && d.Mods && d.Mods[name];
	if (typeIs(value, "number")) {
		return value;
	}
	return name === "Crit" || name === "Collect" ? 0 : 1;
}
function productionMultiplier(state: State | undefined): number {
	return mod(state, "Production");
}

// what a collect is worth in "seconds of output", the unit every collect-driven event scores in
function collectSeconds(collected: number, perSecond: number): number {
	if (collected <= 0) {
		return 0;
	}
	return perSecond > 0 ? collected / perSecond : 1;
}
function collectPoints(collected: number, perSecond: number, cap?: number): number {
	if (collected <= 0) {
		return 0;
	}
	return math.clamp(math.floor(collectSeconds(collected, perSecond)), 1, cap ?? EVENTS.CommunityForge.MaxPointsPerCollect);
}

// what a collect drops during a "drops" event; rolls are 0..1
function drops(id: string | undefined, collected: number, perSecond: number, rollA: number, rollB: number) {
	const d = id !== undefined ? BY_ID[id] : undefined;
	const out: { Dust: number; Cores: number; Keys: number; KeyCrate?: string } = { Dust: 0, Cores: 0, Keys: 0, KeyCrate: undefined };
	if (d === undefined || d.Kind !== "drops" || collected <= 0) {
		return out;
	}
	const dropDef = d.Drops!;
	if (dropDef.Dust !== undefined) {
		out.Dust = math.clamp(math.floor(math.sqrt(collectSeconds(collected, perSecond))), 1, dropDef.Dust);
	}
	if (dropDef.CoreChance !== undefined && rollA < dropDef.CoreChance) {
		out.Cores = 1 + math.floor(rollB * dropDef.CoreMax! * 0.999);
	}
	if (dropDef.KeyChance !== undefined && rollA < dropDef.KeyChance) {
		out.Keys = 1;
		out.KeyCrate = dropDef.KeyCrate;
	}
	return out;
}
function rainDust(collected: number, perSecond: number): number {
	return drops("StardustRain", collected, perSecond, 1, 0).Dust;
}

function communityGoal(players: number): number {
	const d = EVENTS.CommunityForge;
	return math.max(d.MinGoal, math.max(1, math.floor(players)) * d.PointsPerPlayer);
}
function communityStardust(rank: number): number {
	const d = EVENTS.CommunityForge;
	return d.RewardStardust + (at(d.TopBonusStardust, rank) ?? 0);
}

function titanHealth(players: number): number {
	const d = EVENTS.IronTitan;
	return math.max(d.MinHealth, math.max(1, math.floor(players)) * d.HealthPerPlayer);
}
function titanCollectHit(collected: number, perSecond: number): number {
	if (collected <= 0) {
		return 0;
	}
	const seconds = collectSeconds(collected, perSecond);
	return math.clamp(math.floor(math.sqrt(seconds) * 2), 1, EVENTS.IronTitan.MaxCollectHit);
}

// highest first; ties go to whoever has the lower user id so the order never flickers
function ranking(points: Record<number, number>) {
	const list: { UserId: number; Points: number }[] = [];
	for (const [userId, value] of pairs(points)) {
		if (value > 0) {
			list.push({ UserId: userId, Points: value });
		}
	}
	list.sort((a, b) => {
		if (a.Points !== b.Points) {
			return a.Points > b.Points;
		}
		return a.UserId < b.UserId;
	});
	return list;
}

function racePrize(rank: number) {
	const d = EVENTS.ForgeRace;
	return (at(d.Prizes, rank) ?? d.Consolation) as Readonly<Record<string, number>>;
}

// Lucky Draw: `rolls` (0..1 each) pick tickets; a player can win once
function drawWinners(tickets: Record<number, number>, rolls: number[], count?: number): number[] {
	const pool: { UserId: number; Tickets: number }[] = [];
	for (const [userId, n] of pairs(tickets)) {
		if (n > 0) {
			pool.push({ UserId: userId, Tickets: n });
		}
	}
	pool.sort((a, b) => a.UserId < b.UserId);
	const winners: number[] = [];
	const rounds = math.min(count ?? EVENTS.LuckyDraw.Winners, pool.size());
	for (let index = 1; index <= rounds; index++) {
		let total = 0;
		for (const entry of pool) {
			total += entry.Tickets;
		}
		if (total <= 0) {
			break;
		}
		const target = (at(rolls, index) ?? 0) * total;
		let pickAt = pool.size() - 1;
		let run = 0;
		for (let i = 0; i < pool.size(); i++) {
			run += pool[i].Tickets;
			if (target < run) {
				pickAt = i;
				break;
			}
		}
		winners.push(pool[pickAt].UserId);
		pool.remove(pickAt);
	}
	return winners;
}

// Supply Drop: when each crate lands, as seconds after the event went live
function supplyTimes(): number[] {
	const d = EVENTS.SupplyDrop;
	const times: number[] = [];
	for (const fraction of d.DropAt) {
		times.push(math.floor(LIVE_SECONDS * fraction));
	}
	return times;
}

function secondsLeft(state: State | undefined, now: number): number {
	if (state === undefined || state.PhaseEndsAt === undefined) {
		return 0;
	}
	return math.max(0, state.PhaseEndsAt - now);
}

export = table.freeze({
	REST_SECONDS,
	WARNING_SECONDS,
	LIVE_SECONDS,
	RESULTS_SECONDS,
	FIRST_REST_SECONDS,
	EVENTS,
	ORDER,
	pick,
	advance,
	mod,
	productionMultiplier,
	collectSeconds,
	collectPoints,
	drops,
	rainDust,
	communityGoal,
	communityStardust,
	titanHealth,
	titanCollectHit,
	ranking,
	racePrize,
	drawWinners,
	supplyTimes,
	secondsLeft,
});

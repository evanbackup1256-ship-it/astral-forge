// Purpose: costs, gates and multipliers for every world after the last hand-tuned one.
// The hand-tuned worlds end steep (about x40 cost and x1.6 output per world). The old tail restarted
// from world 5's numbers, so world 13 paid x15 against world 12's x370. Here each world after the
// anchor steps from the one before it, starting at the hand-tuned pace and easing towards the long
// endless pace over a couple dozen worlds. Everything is closed form, so world 400,000 costs the
// same to work out as world 13.
// Owner: gameplay. Dependencies: none.

type Row = Record<string, unknown>;

// the last hand-tuned world; its numbers are read from the config, never copied here
export const ANCHOR_ID = 12;

// per-world ratios at the start of the tail and in the long run, and how fast one eases into the other
const COST_START = 40;
const COST_END = 1.85;
const MULT_START = 1.6;
const MULT_END = 1.22;
const MULT_FAST_TIER = 3400; // past this the multiplier only creeps, as before
const MULT_CREEP = 1.000055;
const CORE_STEP_START = 100;
const CORE_STEP_END = 3;
const REBIRTH_STEP_START = 55;
const REBIRTH_STEP_END = 2;
const EASE = 12; // worlds for the hand-tuned pace to fade to about a third

const LN10 = math.log(10);
const LN_MAX = math.log(1e300);

export interface Anchor {
	Cost: number | string;
	CoreCost: number;
	Multiplier: number;
	RequiredRebirths: number;
}

export interface WorldStats {
	Cost: number | string;
	CoreCost: number;
	Multiplier: number;
	RequiredRebirths: number;
}

// sum over k = 1..steps of exp(-k / EASE): how much of the hand-tuned pace is still in play
function easeSum(steps: number): number {
	const q = math.exp(-1 / EASE);
	return (q * (1 - q ** steps)) / (1 - q);
}

function lnOf(value: number | string): number {
	if (typeIs(value, "number")) {
		return math.log(math.max(value, 1));
	}
	const [mantissa, exponent] = value.match("^([%d%.]+)e%+?(%d+)$") as LuaTuple<[string | undefined, string | undefined]>;
	const m = tonumber(mantissa);
	const e = tonumber(exponent);
	return m !== undefined && e !== undefined ? math.log(m) + e * LN10 : 0;
}

// Big costs are stored the way the rest of the config writes them: "1.23456789e400".
function fromLn(ln: number): number | string {
	if (ln < math.log(1e300)) {
		return math.floor(math.exp(ln));
	}
	const log10 = ln / LN10;
	const exponent = math.floor(log10);
	return string.format("%.8fe%d", 10 ** (log10 - exponent), exponent);
}

export function statsFor(anchor: Anchor, id: number): WorldStats {
	const steps = math.max(0, math.floor(id) - ANCHOR_ID);
	const eased = easeSum(steps);
	const costLn = lnOf(anchor.Cost) + steps * math.log(COST_END) + eased * (math.log(COST_START) - math.log(COST_END));
	const fast = math.min(steps, MULT_FAST_TIER);
	const multLn =
		math.log(math.max(anchor.Multiplier, 1)) +
		fast * math.log(MULT_END) +
		(steps - fast) * math.log(MULT_CREEP) +
		eased * (math.log(MULT_START) - math.log(MULT_END));
	return {
		Cost: fromLn(costLn),
		CoreCost: math.floor(anchor.CoreCost + steps * CORE_STEP_END + eased * (CORE_STEP_START - CORE_STEP_END)),
		Multiplier: multLn >= LN_MAX ? 1e300 : math.exp(multLn),
		RequiredRebirths: math.floor(
			anchor.RequiredRebirths + steps * REBIRTH_STEP_END + eased * (REBIRTH_STEP_START - REBIRTH_STEP_END),
		),
	};
}

// Hand-written names and lines for the first worlds past the anchor. Layouts reuse the five built ones.
export const FLAVOR: Record<number, Row> = {
	13: {
		Name: "Tidewell",
		Tagline: "A dock built on a tide of slow light.",
		Description: "Platforms that rise and settle with the light tide.",
		Lore: "Tidewell's rails drift a few metres every cycle. Crews bolt everything twice and still lose the odd crate over the edge.",
		Features: ["Drifting rails", "Long offline time", "Heavy cores"],
		Layout: "Dock",
	},
	14: {
		Name: "Cinder Choir",
		Tagline: "Forges that hum in tune when they run hot.",
		Description: "A ring of kilns that sing as the output climbs.",
		Lore: "Nobody planned the humming. It started when the third kiln went in, and now crews tune their machines by ear.",
		Features: ["Heat forges", "Rebirth gate", "Loud shifts"],
		Layout: "Foundry",
	},
	15: {
		Name: "Saltglass Flats",
		Tagline: "Miles of crystal crust over a dry sea.",
		Description: "Crystal salt flats that split light into usable heat.",
		Lore: "The flats crack in straight lines, which surveyors swear isn't natural. The output is good enough that nobody asks twice.",
		Features: ["Crystal multipliers", "Wide lanes", "Brittle floors"],
		Layout: "Crystal",
	},
	16: {
		Name: "The Undertow",
		Tagline: "Where folded space pulls a little too hard.",
		Description: "A rift that drags unfinished work towards its centre.",
		Lore: "Anything left half-built in The Undertow ends up somewhere else by morning. Finish the job or lose it.",
		Features: ["Short routes", "Steep core costs", "Bigger multiplier"],
		Layout: "Rift",
	},
	17: {
		Name: "Lantern Reach",
		Tagline: "The last lit dock before the dark.",
		Description: "A thin chain of lit platforms at the edge of the charts.",
		Lore: "Every crew that passes hangs a lantern. There are thousands now, and the light carries far enough to work by.",
		Features: ["Deep vaults", "Rebirth gate", "Quiet nights"],
		Layout: "Horizon",
	},
	18: {
		Name: "Second Dawn",
		Tagline: "A young star, and room to build around it.",
		Description: "Open space around a new star, with nothing built yet.",
		Lore: "Second Dawn is where long-haul crews start over. The star is small and fierce, and the first forge here sets the pace for everyone after.",
		Features: ["Max multipliers", "Fresh ground", "Endless flux"],
		Layout: "Foundry",
	},
};

// Rewrites every world after the anchor in a raw 1-based zone list, in place.
export function apply(zones: Record<number, Row>): void {
	const anchor = zones[ANCHOR_ID];
	if (!typeIs(anchor, "table")) {
		return;
	}
	const base = anchor as unknown as Anchor;
	let index = ANCHOR_ID + 1;
	while (zones[index] !== undefined) {
		const zone = zones[index];
		const id = tonumber(zone.Id) ?? index;
		const stats = statsFor(base, id);
		zone.Cost = stats.Cost;
		zone.CoreCost = stats.CoreCost;
		zone.Multiplier = stats.Multiplier;
		zone.RequiredRebirths = stats.RequiredRebirths;
		const flavor = FLAVOR[id];
		if (flavor !== undefined) {
			for (const [key, value] of pairs(flavor)) {
				zone[key as string] = value;
			}
		}
		index += 1;
	}
}

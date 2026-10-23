// "This session": what you've done since you joined, counted on the client and shown as a live card.
// Values bump when they change and play time ticks every second.
import React from "@rbxts/react";
import * as theme from "./CoreKit/theme";
import * as format from "./CoreKit/format";
import * as motion from "./MotionKit/motion";
import { OmegaMathApi, OmegaValue } from "./lua";

// ArtKit is still Luau; require it through the kit factory at call time like the bundled code did.
const Icon = ((require(script.Parent!.FindFirstChild("ArtKit")! as ModuleScript) as CallableFunction)("Icon") as { Icon: unknown }).Icon;
const P = theme.Palette;
const h = React.createElement as unknown as (component: unknown, props?: object, ...children: unknown[]) => React.Element;

let startedAt = os.clock();
const counts: Record<string, number> = {
	collects: 0,
	overcharges: 0,
	crits: 0,
	claims: 0,
	upgrades: 0,
	bestCombo: 0,
	crates: 0,
	rebirths: 0,
};
let fluxCollected: OmegaValue = 0;
let fluxText = "0";
let fluxSpent: OmegaValue = 0;
let fluxSpentText = "0";
let bestDrop: { name: string; rarity: string; rank: number } | undefined;
const RARITY_RANK: Record<string, number> = { Common: 1, Rare: 2, Epic: 3, Legendary: 4, Mythic: 5, Celestial: 6, Astral: 7 };
// flux earned per minute: one bucket per minute since join, newest last, at most CHART_BARS kept
const CHART_BARS = 40;
const minuteBuckets: number[] = [0];
let bucketStartedAt = os.clock();
let panelOpen = false;
let shareHandler: (() => void) | undefined;
const listeners = new Set<() => void>();

function notify() {
	for (const listener of listeners) {
		task.spawn(listener);
	}
}

function rollBuckets() {
	const now = os.clock();
	while (now - bucketStartedAt >= 60) {
		bucketStartedAt += 60;
		minuteBuckets.push(0);
		if (minuteBuckets.size() > CHART_BARS) {
			minuteBuckets.remove(0);
		}
	}
}

let omegaModule: OmegaMathApi | false | undefined;
function omega(): OmegaMathApi | undefined {
	if (omegaModule === undefined) {
		const [ok, module] = pcall(() =>
			require(
				game
					.GetService("ReplicatedStorage")
					.WaitForChild("AstralForge")
					.WaitForChild("Shared")
					.WaitForChild("OmegaMath") as ModuleScript,
			),
		);
		omegaModule = ok ? (module as OmegaMathApi) : false;
	}
	return omegaModule === false ? undefined : omegaModule;
}

function useStats() {
	const [, setRevision] = React.useState(0);
	React.useEffect(() => {
		const listener = () => {
			setRevision((n) => n + 1);
		};
		listeners.add(listener);
		return () => {
			listeners.delete(listener);
		};
	}, []);
	return counts;
}

function clockText(seconds: number): string {
	const s = math.max(0, math.floor(seconds));
	if (s >= 3600) {
		return string.format("%dh %02dm", math.floor(s / 3600), math.floor((s % 3600) / 60));
	}
	return string.format("%dm %02ds", math.floor(s / 60), s % 60);
}

interface StatProps {
	order: number;
	label: string;
	icon: string;
	accent: Color3;
	text?: unknown;
	live?: unknown;
	value?: unknown;
	reducedMotion?: boolean;
}

function Stat(props: StatProps) {
	const flash = motion.useFlash(props.value as number, props.reducedMotion, 0.5);
	return h(
		"frame",
		{
			Size: new UDim2(0, 0, 0, 44),
			LayoutOrder: props.order,
			BackgroundColor3: P.panelSoft,
			BackgroundTransparency: 0.25,
			BorderSizePixel: 0,
		},
		h("uiflexitem", { FlexMode: Enum.UIFlexMode.Fill }),
		h("uicorner", { CornerRadius: new UDim(0, 10) }),
		h("uistroke", {
			Color: props.accent,
			Thickness: 1,
			Transparency: flash.map((v) => 0.75 - v * 0.65),
		}),
		h("uiscale", {
			Scale: flash.map((v) => 1 + v * 0.05),
		}),
		h(Icon, {
			kind: props.icon,
			color: P.cream,
			accent: props.accent,
			size: 20,
			position: new UDim2(0, 10, 0.5, -10),
			spin: false,
		}),
		h(
			"textlabel",
			{
				Size: new UDim2(1, -40, 0, 18),
				Position: UDim2.fromOffset(36, 5),
				BackgroundTransparency: 1,
				Text: props.live !== undefined ? props.live : tostring(props.text),
				TextColor3: P.cream,
				TextSize: 15,
				TextXAlignment: Enum.TextXAlignment.Left,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
			},
			h("uitextsizeconstraint", { MaxTextSize: 15, MinTextSize: 10 }),
		),
		h(
			"textlabel",
			{
				Size: new UDim2(1, -40, 0, 14),
				Position: UDim2.fromOffset(36, 24),
				BackgroundTransparency: 1,
				Text: props.label,
				TextColor3: P.muted,
				TextSize: 11,
				TextXAlignment: Enum.TextXAlignment.Left,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansBold),
			},
			h("uitextsizeconstraint", { MaxTextSize: 11, MinTextSize: 8 }),
		),
	);
}

interface CardProps {
	columns?: number;
	position?: UDim2;
	reducedMotion?: boolean;
}

interface StatEntry {
	key: string;
	label: string;
	icon: string;
	accent: Color3;
	text?: unknown;
	live?: unknown;
	value?: unknown;
}

const SessionStats = {
	bump(this: void, key: string, amount?: number) {
		if (counts[key] === undefined) {
			return;
		}
		counts[key] += amount ?? 1;
		notify();
	},

	best(this: void, key: string, value: number) {
		if (counts[key] !== undefined && value > counts[key]) {
			counts[key] = value;
			notify();
		}
	},

	addFlux(this: void, amount: unknown) {
		const O = omega();
		if (O === undefined || amount === undefined) {
			return;
		}
		const [ok, total] = pcall(O.Add, fluxCollected, amount);
		if (ok) {
			fluxCollected = (O.Persist as (value: unknown) => OmegaValue)(total);
			fluxText = format.compactNumber(fluxCollected);
			rollBuckets();
			const [okN, n] = pcall(O.ToNumber, amount);
			if (okN && n === n && n < math.huge) {
				minuteBuckets[minuteBuckets.size() - 1] += math.max(0, n);
			}
			notify();
		}
	},

	/** Records flux spent when Cash went down between two snapshots. */
	spendFlux(this: void, before: unknown, after: unknown) {
		const O = omega();
		if (O === undefined || before === undefined || after === undefined) {
			return;
		}
		const [okGt, lower] = pcall(O.Lt, after, before);
		if (!okGt || !lower) {
			return;
		}
		const [ok, total] = pcall(() => O.Add(fluxSpent, O.Sub(before, after)));
		if (ok) {
			fluxSpent = (O.Persist as (value: unknown) => OmegaValue)(total);
			fluxSpentText = format.compactNumber(fluxSpent);
			notify();
		}
	},

	/** Keeps the rarest item seen this session (ties keep the first). */
	drop(this: void, name: unknown, rarity: unknown) {
		if (!typeIs(name, "string") || name === "") {
			return;
		}
		const tier = typeIs(rarity, "string") ? rarity : "Common";
		const rank = RARITY_RANK[tier] ?? 0;
		if (bestDrop === undefined || rank > bestDrop.rank) {
			bestDrop = { name, rarity: tier, rank };
			notify();
		}
	},

	reset(this: void) {
		for (const [key] of pairs(counts)) {
			counts[key] = 0;
		}
		fluxCollected = 0;
		fluxText = "0";
		fluxSpent = 0;
		fluxSpentText = "0";
		bestDrop = undefined;
		minuteBuckets.clear();
		minuteBuckets.push(0);
		startedAt = os.clock();
		bucketStartedAt = startedAt;
		notify();
	},

	/** Snapshot for the Session panel. */
	read(this: void) {
		rollBuckets();
		return {
			counts,
			fluxText,
			fluxSpentText,
			bestDrop,
			playedSeconds: os.clock() - startedAt,
			perMinute: table.clone(minuteBuckets),
		};
	},

	clockText(this: void, seconds: number) {
		return clockText(seconds);
	},

	useStats(this: void) {
		return useStats();
	},

	isOpen(this: void) {
		return panelOpen;
	},
	setOpen(this: void, open: boolean) {
		if (panelOpen !== open) {
			panelOpen = open;
			notify();
		}
	},
	toggle(this: void) {
		panelOpen = !panelOpen;
		notify();
	},
	/** Whoever owns sharing (screenshot card, chat post) registers here; without it the button is hidden. */
	setShareHandler(this: void, handler: (() => void) | undefined) {
		shareHandler = handler;
		notify();
	},
	share(this: void) {
		shareHandler?.();
	},
	canShare(this: void) {
		return shareHandler !== undefined;
	},

	Card(this: void, props: CardProps) {
		const stats = useStats();
		const clock = motion.useClock(true, 1, 86400, true);
		const columns = props.columns ?? 4;
		const entries: StatEntry[] = [
			{
				key: "time",
				label: "Played",
				icon: "Timer.6",
				accent: P.cyan,
				live: clock.map(() => clockText(os.clock() - startedAt)),
			},
			{ key: "flux", label: "Flux collected", icon: "Flux.18", accent: P.cyan, text: fluxText, value: fluxText },
			{ key: "collects", label: "Vault collects", icon: "Vault.7", accent: P.green, text: stats.collects },
			{ key: "overcharges", label: "Overcharges", icon: "Overcharge.8", accent: P.mango, text: stats.overcharges },
			{ key: "crits", label: "Critical taps", icon: "Boost.20", accent: P.mango, text: stats.crits },
			{ key: "combo", label: "Best combo", icon: "Wave.13", accent: P.pink, text: `x${stats.bestCombo}` },
			{ key: "claims", label: "Rewards claimed", icon: "Rewards.2", accent: P.pink, text: stats.claims },
			{ key: "upgrades", label: "Upgrades bought", icon: "Forge.25", accent: P.violet, text: stats.upgrades },
		];
		const rows = math.ceil(entries.size() / columns);
		const grid: Record<string, React.Element> = {
			layout: h("uilistlayout", {
				FillDirection: Enum.FillDirection.Vertical,
				Padding: new UDim(0, 8),
				SortOrder: Enum.SortOrder.LayoutOrder,
			}),
		};
		for (let row = 1; row <= rows; row++) {
			const cells: Record<string, React.Element> = {
				layout: h("uilistlayout", {
					FillDirection: Enum.FillDirection.Horizontal,
					Padding: new UDim(0, 8),
					SortOrder: Enum.SortOrder.LayoutOrder,
					HorizontalFlex: Enum.UIFlexAlignment.Fill,
				}),
			};
			for (let col = 1; col <= columns; col++) {
				const entry = entries[(row - 1) * columns + col - 1];
				if (entry !== undefined) {
					cells[entry.key] = h(Stat, {
						order: col,
						label: entry.label,
						icon: entry.icon,
						accent: entry.accent,
						text: entry.text,
						live: entry.live,
						value: entry.value ?? entry.text,
						reducedMotion: props.reducedMotion,
					});
				}
			}
			grid[`row${row}`] = h(
				"frame",
				{ Size: new UDim2(1, 0, 0, 44), BackgroundTransparency: 1, LayoutOrder: row },
				cells,
			);
		}
		return h(
			"frame",
			{
				Size: new UDim2(1, 0, 0, rows * 52 - 8),
				Position: props.position,
				BackgroundTransparency: 1,
			},
			grid,
		);
	},

	height(this: void, columns: number): number {
		return math.ceil(8 / columns) * 52 - 8;
	},
};

export = SessionStats;

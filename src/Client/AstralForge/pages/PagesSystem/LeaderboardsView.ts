import { asFlux, clockText, compactNumber, Flux } from "../../CoreKit/format";
import { Palette } from "../../CoreKit/theme";
import RankDashboard = require("../../RankDashboard");
import OmegaMath = require("../../../../Shared/AstralForge/Shared/OmegaMath");

interface Board {
	id: string;
	label: string;
	short: string;
	description: string;
	icon: string;
	accent: Color3;
	group: string;
}

const RAW: Array<Omit<Board, "group"> & { group?: string }> = [
	{ id: "Flux", label: "Lifetime Flux", short: "FLUX", description: "All the Flux you have ever made.", icon: "Flux.16", accent: Palette.cyan },
	{
		id: "Weekly",
		label: "This Week",
		short: "WEEK",
		description: "Flux made since Monday 00:00 UTC. The top 100 get Cores and Stardust when the week ends; #1 takes 25 Cores.",
		icon: "Flux.16",
		accent: Palette.mango,
	},
	{ id: "Rebirths", label: "Most Rebirths", short: "REBIRTHS", description: "Pilots who have restarted the forge the most.", icon: "Rebirth.6", accent: Palette.violet },
	{ id: "PlayTime", label: "Time Played", short: "PLAYTIME", description: "Total time spent playing.", icon: "Command.4", accent: Palette.mint },
	{ id: "Dust", label: "Most Stardust", short: "DUST", description: "Most Stardust on hand right now.", icon: "Dust.10", accent: Palette.mango },
	{ id: "Cores", label: "Most Cores", short: "CORES", description: "Cores on hand, ready to spend.", icon: "Core.7", accent: Palette.violet },
	{ id: "Domain", label: "Domain Rank", short: "DOMAIN", description: "The highest Domain rank reached.", icon: "Domain.4", accent: Palette.pink },
	{ id: "Worlds", label: "Farthest World", short: "WORLDS", description: "The farthest forge worlds unlocked.", icon: "World.8", accent: Palette.green, group: "Progression" },
	{ id: "Crates", label: "Crates Opened", short: "CRATES", description: "Every sealed crate cracked open, any tier, any skin.", icon: "Crate.12", accent: Palette.mango, group: "Collection" },
	{ id: "Finds", label: "Items Found", short: "FINDS", description: "Relics, tools and oddities pulled into the vault.", icon: "Artifact.7", accent: Palette.cyan, group: "Collection" },
	{ id: "Ore", label: "Ore Mined", short: "ORE", description: "Raw ore hauled out of the deep veins.", icon: "Forge.21", accent: Palette.mango, group: "Activity" },
	{ id: "Wardens", label: "Wardens Felled", short: "WARDENS", description: "Vault wardens brought down in combat.", icon: "Milestone.4", accent: Palette.pink, group: "Activity" },
	{ id: "Orders", label: "Orders Filled", short: "ORDERS", description: "Contracts and work orders delivered on time.", icon: "Mission.7", accent: Palette.mint, group: "Activity" },
	{
		id: "Stars",
		label: "Ore Cuts",
		short: "CUTS",
		description: "Ore cuts finished, including ones from before the workshop rebuild.",
		icon: "Dust.11",
		accent: Palette.violet,
		group: "Activity",
	},
	{
		id: "Cipher",
		label: "Commissions Finished",
		short: "COMMISSIONS",
		description: "Daily commissions finished. Older puzzle clears still count.",
		icon: "Forge.22",
		accent: Palette.cyan,
		group: "Activity",
	},
];
const BOARD_GROUP: Record<string, string | undefined> = {
	Flux: "Economy",
	Weekly: "Economy",
	Dust: "Economy",
	Cores: "Economy",
	Rebirths: "Progression",
	Domain: "Progression",
	PlayTime: "Activity",
};
const BOARDS: Board[] = RAW.map((board) => ({ ...board, group: board.group ?? BOARD_GROUP[board.id] ?? "Progression" }));
const STAT_BOARD_KEYS: Record<string, string | undefined> = {
	Crates: "CratesOpened",
	Finds: "ItemsFound",
	Ore: "OreMined",
	Wardens: "WardenDefeats",
	Orders: "OrdersCompleted",
};

function metaFor(id: string): Board {
	return BOARDS.find((board) => board.id === id) ?? BOARDS[0];
}

function formatValue(id: string, value: unknown): string {
	if (id === "PlayTime") {
		return clockText(typeIs(value, "number") ? value : asFlux(value as Flux));
	}
	if (id === "Worlds") {
		return `WORLD ${math.max(1, math.floor(asFlux(value as Flux)))}`;
	}
	if (id === "Domain") {
		const rank = math.floor(asFlux(value as Flux));
		return rank > 0 ? `RANK ${rank}` : "UNRANKED";
	}
	return compactNumber(value);
}

function scoreCounts(id: string, value: unknown): boolean {
	if (id === "Worlds") {
		return asFlux(value as Flux) > 1;
	}
	return asFlux(value as Flux) > 0;
}

type Bag = Record<string, unknown>;

function ownValue(state: Bag, id: string): unknown {
	const statKey = STAT_BOARD_KEYS[id];
	if (statKey !== undefined) {
		const stats = state.Stats as Bag | undefined;
		return math.max(0, math.floor(tonumber(stats && stats[statKey]) ?? 0));
	}
	if (id === "Stars") {
		let total = 0;
		const sky = state.Sky as Bag | undefined;
		if (typeIs(sky, "table") && typeIs(sky.Plotted, "table")) {
			for (const [, count] of pairs(sky.Plotted as Bag)) {
				total += math.max(0, math.floor(tonumber(count) ?? 0));
			}
		}
		return total;
	}
	if (id === "Cipher") {
		const sky = state.Sky as Bag | undefined;
		const solves =
			typeIs(sky, "table") && typeIs(sky.Cipher, "table") ? (sky.Cipher as Bag).Solves : false;
		return math.max(0, math.floor(tonumber(solves) ?? 0));
	}
	if (id === "Flux") {
		return state.LifetimeCash;
	}
	if (id === "Weekly") {
		return (state.WeeklyBoard as Bag | undefined)?.Score ?? 0;
	}
	if (id === "Rebirths") {
		return state.Rebirths;
	}
	if (id === "PlayTime") {
		return (state.Stats as Bag | undefined)?.PlayTime ?? 0;
	}
	if (id === "Dust") {
		return state.Stardust;
	}
	if (id === "Cores") {
		return state.Cores;
	}
	if (id === "Domain") {
		return (state.Domain as Bag | undefined)?.Rank ?? 0;
	}
	return state.Zone;
}

function serverValueFor(summary: Bag, id: string): unknown {
	if (STAT_BOARD_KEYS[id] !== undefined || id === "Stars" || id === "Cipher") {
		const boards = summary.Boards;
		return typeIs(boards, "table") ? (tonumber((boards as Bag)[id]) ?? 0) : 0;
	}
	if (id === "Flux") {
		return summary.LifetimeCash ?? 0;
	}
	if (id === "Weekly") {
		const boards = summary.Boards;
		return typeIs(boards, "table") ? ((boards as Bag).Weekly ?? 0) : 0;
	}
	if (id === "Rebirths") {
		return summary.Rebirths;
	}
	if (id === "PlayTime") {
		return summary.PlayTime ?? 0;
	}
	if (id === "Dust") {
		return summary.Stardust ?? 0;
	}
	if (id === "Cores") {
		return summary.Cores ?? 0;
	}
	if (id === "Domain") {
		return summary.DomainRank ?? 0;
	}
	return summary.CurrentZone;
}

function serverEntries(players: unknown[], id: string): unknown[] {
	const sorted = [...(players as Bag[])];
	sorted.sort((left, right) => {
		const compare = (OmegaMath.Compare as (a: unknown, b: unknown) => number)(
			serverValueFor(left, id) ?? 0,
			serverValueFor(right, id) ?? 0,
		);
		return compare === 0 ? (left.UserId as number) < (right.UserId as number) : compare > 0;
	});
	return sorted.map((summary) => ({
		UserId: summary.UserId,
		Name: summary.DisplayName,
		Value: serverValueFor(summary, id),
		Category: id,
	}));
}

export const LeaderboardsView = RankDashboard({ boards: BOARDS, metaFor, ownValue, formatValue, serverEntries, scoreCounts });

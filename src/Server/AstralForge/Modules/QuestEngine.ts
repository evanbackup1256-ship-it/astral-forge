// Quest and achievement engine.
//
// Gameplay code reports what happened with one event (Progression.Progress(profile, "Tap", 1)).
// TRIGGERS says which quest kinds each event moves, so "BuyAny" is a row in a table rather than
// a special case in a loop. Daily quests are built from DAILY, one row per slot, and saved in the
// same shape as before: Quests = { Day, Items: [{ Id, Name, Description, Kind, Target, Progress, Reward, Claimed }] }.
// Achievements keep their claimed map (Achievements[id] = true); progress is read live, never stored.
import { T } from "../../../Shared/AstralForge/Shared/Locale";

type Dict = Record<string, unknown>;
type Reward = Record<string, unknown>;

export interface QuestRow {
	Id: string;
	Name: string;
	Description: string;
	Kind: string;
	Target: number;
	Progress: number;
	Reward: Reward;
	Claimed: boolean;
}

// event -> the quest kinds it advances. An event missing here advances quests of its own kind.
export const TRIGGERS: Record<string, string[]> = {
	EarnCash: ["EarnCash"],
	Tap: ["Tap"],
	BuyMachine: ["BuyMachine", "BuyAny"],
	BuyResearch: ["BuyResearch", "BuyAny"],
};

// what a day's quests scale from; worked out by Progression from the profile
export interface DailyContext {
	Day: number;
	Rotation: number; // 0..2, from day and user id, picks the third slot's variant
	EarnTarget: number;
	TapTarget: number;
	UpgradeTarget: number;
}

interface Variant {
	Name: string;
	Description: string;
	Kind: string;
}

interface DailySlot {
	IdPrefix: string;
	Variants: Variant[]; // one, or one per rotation
	Target: (ctx: DailyContext) => number;
	Reward: (ctx: DailyContext) => Reward;
}

export const DAILY: DailySlot[] = [
	{
		IdPrefix: "earn",
		Variants: [{ Name: "Shift Quota", Description: "Bank Flux from your vault.", Kind: "EarnCash" }],
		Target: (ctx) => ctx.EarnTarget,
		Reward: (ctx) => ({ Cash: math.floor(ctx.EarnTarget * 0.15), Stardust: 5 }),
	},
	{
		IdPrefix: "tap",
		Variants: [{ Name: "Hands On", Description: "Use manual overcharge.", Kind: "Tap" }],
		Target: (ctx) => ctx.TapTarget,
		Reward: (ctx) => ({ Cash: math.floor(ctx.EarnTarget * 0.08), Stardust: 4 }),
	},
	{
		IdPrefix: "upgrade",
		Variants: [
			{ Name: "Machinist", Description: "Upgrade any machines.", Kind: "BuyMachine" },
			{ Name: "Research Grant", Description: "Purchase research levels.", Kind: "BuyResearch" },
			{ Name: "Expansion Plan", Description: "Purchase machines or research.", Kind: "BuyAny" },
		],
		Target: (ctx) => ctx.UpgradeTarget,
		Reward: (ctx) => ({ Cash: math.floor(ctx.EarnTarget * 0.12), Stardust: 6 }),
	},
];

export function buildDaily(ctx: DailyContext): QuestRow[] {
	return DAILY.map((slot) => {
		const variant = slot.Variants[slot.Variants.size() === 1 ? 0 : ctx.Rotation % slot.Variants.size()];
		return {
			Id: string.format("%s_%d", slot.IdPrefix, ctx.Day),
			Name: variant.Name,
			Description: variant.Description,
			Kind: variant.Kind,
			Target: slot.Target(ctx),
			Progress: 0,
			Reward: slot.Reward(ctx),
			Claimed: false,
		};
	});
}

function whole(value: unknown): number {
	return math.max(0, math.floor(tonumber(value) ?? 0));
}

// Advances every quest the event triggers. Returns how many quests it touched.
export function emit(quests: unknown, event: unknown, amount: unknown): number {
	if (!typeIs(quests, "table") || !typeIs(event, "string")) return 0;
	const delta = whole(amount);
	if (delta !== delta || delta === math.huge || delta <= 0) return 0;
	const kinds = TRIGGERS[event] ?? [event];
	let updated = 0;
	for (const [, quest] of pairs(quests as Dict)) {
		if (typeIs(quest, "table") && kinds.includes((quest as Dict).Kind as string)) {
			const bag = quest as Dict;
			bag.Progress = math.min(whole(bag.Target), whole(bag.Progress) + delta);
			updated += 1;
		}
	}
	return updated;
}

export function canClaim(quest: unknown): LuaTuple<[boolean, string]> {
	if (!typeIs(quest, "table")) return $tuple(false, T("EconomyMath.MissionNotFound"));
	const bag = quest as Dict;
	if (bag.Claimed === true) return $tuple(false, T("EconomyMath.ThatMissionRewardWasAlready"));
	if (whole(bag.Progress) < whole(bag.Target)) return $tuple(false, T("EconomyMath.ThatMissionIsNotComplete"));
	return $tuple(true, "");
}

export function findQuest<Q extends { Id: string }>(quests: Q[], id: string): Q | undefined {
	return quests.find((quest) => quest.Id === id);
}

// ---- Achievements ---------------------------------------------------------------------------

export interface AchievementDef {
	Id: string;
	Kind: string;
	Target: number;
}

const achievementIndex = new WeakMap<object, Map<string, AchievementDef>>();

// id lookup over the config list, built once per list
export function findAchievement<A extends AchievementDef>(list: A[], id: string): A | undefined {
	let index = achievementIndex.get(list);
	if (index === undefined) {
		index = new Map();
		for (const achievement of list) index.set(achievement.Id, achievement);
		achievementIndex.set(list, index);
	}
	return index.get(id) as A | undefined;
}

export function canClaimAchievement(
	claimed: unknown,
	achievement: AchievementDef,
	progress: number,
): LuaTuple<[boolean, string]> {
	if (typeIs(claimed, "table") && (claimed as Dict)[achievement.Id] === true)
		return $tuple(false, T("Progression.ThatMilestoneWasAlreadyClaimed"));
	if (progress < achievement.Target) return $tuple(false, T("Progression.ThatMilestoneIsNotComplete"));
	return $tuple(true, "");
}

// Group, like-goal and notification opt-in rewards. Pure: GameService checks group membership (it yields)
// and applies the returned reward with ProgressionService.ApplyReward inside its usual mutate.
import { T } from "../../../../Shared/AstralForge/Shared/Locale";
type Dict = Record<string, unknown>;

export interface LikeGoal {
	Likes: number;
	Reward: Dict;
}

export interface CommunityConfig {
	GroupId: number;
	GroupName: string;
	GroupReward: Dict;
	Likes: number;
	LikeGoals: ReadonlyArray<LikeGoal>;
	NotifyEnabled: boolean;
	NotifyReward: Dict;
}

export interface CommunityPublic {
	GroupId: number;
	GroupName: string;
	GroupClaimed: boolean;
	GroupReward: Dict;
	Likes: number;
	LikeGoals: { Index: number; Likes: number; Reward: Dict; Claimed: boolean }[];
	NotifyRewardEnabled: boolean;
	NotifyClaimed: boolean;
	NotifyReward: Dict;
}

function bag(raw: unknown): Dict {
	return typeIs(raw, "table") ? (raw as Dict) : {};
}

function claimedGoals(raw: unknown): Dict {
	const goals = bag(raw).LikeGoals;
	return typeIs(goals, "table") ? (goals as Dict) : {};
}

export function publicState(raw: unknown, config: CommunityConfig): CommunityPublic {
	const rewards = bag(raw);
	const goals = claimedGoals(raw);
	return {
		GroupId: config.GroupId,
		GroupName: config.GroupName,
		GroupClaimed: rewards.GroupClaimed === true,
		GroupReward: config.GroupReward,
		Likes: config.Likes,
		LikeGoals: config.LikeGoals.map((goal, index) => ({
			Index: index + 1,
			Likes: goal.Likes,
			Reward: goal.Reward,
			Claimed: goals[tostring(index + 1)] === true,
		})),
		NotifyRewardEnabled: config.NotifyEnabled,
		NotifyClaimed: rewards.NotifyClaimed === true,
		NotifyReward: config.NotifyReward,
	};
}

export type ClaimResult = { ok: true; reward: Dict } | { ok: false; message: string };

// marks the claim on `rewards` (the profile's SocialRewards table) and returns the reward to apply.
// inGroup is only consulted for "Group" and must come from a server-side Player:IsInGroup check.
export function claim(rewards: Dict, kind: unknown, index: unknown, inGroup: boolean | undefined, config: CommunityConfig): ClaimResult {
	if (kind === "Group") {
		if (config.GroupId <= 0) {
			return { ok: false, message: T("CommunityRewards.ThereSNoGroupReward") };
		}
		if (rewards.GroupClaimed === true) {
			return { ok: false, message: T("CommunityRewards.YouAlreadyClaimedTheGroup") };
		}
		if (inGroup !== true) {
			return {
				ok: false,
				message: inGroup === undefined ? T("CommunityRewards.CouldnTCheckTheGroup") : T("CommunityRewards.JoinTheSGroupFirst", config.GroupName),
			};
		}
		rewards.GroupClaimed = true;
		return { ok: true, reward: config.GroupReward };
	}
	if (kind === "Like") {
		if (!typeIs(index, "number")) {
			return { ok: false, message: T("CommunityRewards.ThatLikeGoalDoesnT") };
		}
		const goal = config.LikeGoals[math.floor(index) - 1];
		if (goal === undefined) {
			return { ok: false, message: T("CommunityRewards.ThatLikeGoalDoesnT") };
		}
		if (config.Likes < goal.Likes) {
			return { ok: false, message: T("CommunityRewards.TheCommunityHasnTReached") };
		}
		if (!typeIs(rewards.LikeGoals, "table")) {
			rewards.LikeGoals = {};
		}
		const goals = rewards.LikeGoals as Dict;
		const key = tostring(math.floor(index));
		if (goals[key] === true) {
			return { ok: false, message: T("CommunityRewards.YouAlreadyClaimedThatGoal") };
		}
		goals[key] = true;
		return { ok: true, reward: goal.Reward };
	}
	if (kind === "Notify") {
		if (!config.NotifyEnabled) {
			return { ok: false, message: T("CommunityRewards.ThereSNoRewardFor") };
		}
		if (rewards.NotifyClaimed === true) {
			return { ok: false, message: T("CommunityRewards.YouAlreadyClaimedThisReward") };
		}
		rewards.NotifyClaimed = true;
		return { ok: true, reward: config.NotifyReward };
	}
	return { ok: false, message: T("CommunityRewards.ThatRewardDoesnTExist") };
}

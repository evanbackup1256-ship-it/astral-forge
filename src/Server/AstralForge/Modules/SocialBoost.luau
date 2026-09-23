--!strict
-- Pure social production-boost math. No Roblox services — ServerServices and
-- Lune verify scripts share this so friend/premium multipliers stay testable
-- without Studio. Profile mutation stays with Apply; config knobs are injected.

local SocialBoost = {}

export type SocialConfig = {
	MaxBoostedFriends: number,
	FriendProductionPerPlayer: number,
	PremiumProductionBonus: number,
}

export type SocialBoostState = {
	FriendCount: number,
	FriendLimit: number,
	FriendBonus: number,
	Premium: boolean,
	PremiumBonus: number,
	Multiplier: number,
}

function SocialBoost.Compute(
	friendCount: number,
	premium: boolean,
	config: SocialConfig
): SocialBoostState
	local friendLimit = config.MaxBoostedFriends
	local count = math.clamp(math.floor(friendCount), 0, friendLimit)
	local friendBonus = count * config.FriendProductionPerPlayer
	local premiumBonus = premium and config.PremiumProductionBonus or 0
	return {
		FriendCount = count,
		FriendLimit = friendLimit,
		FriendBonus = friendBonus,
		Premium = premium,
		PremiumBonus = premiumBonus,
		Multiplier = 1 + friendBonus + premiumBonus,
	}
end

function SocialBoost.Changed(previous: any, nextState: SocialBoostState): boolean
	return type(previous) ~= "table"
		or previous.FriendCount ~= nextState.FriendCount
		or previous.FriendLimit ~= nextState.FriendLimit
		or previous.FriendBonus ~= nextState.FriendBonus
		or previous.Premium ~= nextState.Premium
		or previous.PremiumBonus ~= nextState.PremiumBonus
		or previous.Multiplier ~= nextState.Multiplier
end

-- Mutates profile.SocialBoost; returns whether the bag changed.
function SocialBoost.Apply(profile: any, friendCount: number, premium: boolean, config: SocialConfig): boolean
	local nextState = SocialBoost.Compute(friendCount, premium, config)
	local changed = SocialBoost.Changed(profile.SocialBoost, nextState)
	profile.SocialBoost = nextState
	return changed
end

return table.freeze(SocialBoost)

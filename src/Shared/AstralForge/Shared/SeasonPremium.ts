// The Season Pass lane on the Rank Track: every season tier pays a second reward to pass owners.
// Rewards come from the tier number so the generated tier table stays untouched. Pure data, no
// Roblox APIs, so server and client read the same numbers.

interface PremiumReward {
	Stardust?: number;
	Signals?: number;
	Cores?: number;
	Boost?: string;
	Keys?: Record<string, number>;
}

const SeasonPremium = {
	PassKey: "SeasonPass",

	Reward(this: void, tier: number): PremiumReward {
		const t = math.max(1, math.floor(tier));
		if (t % 10 === 0) {
			return { Cores: math.max(1, math.floor(t / 20)), Stardust: 25 + t, Boost: "Hyperdrive" };
		}
		if (t % 5 === 0) {
			return { Stardust: 12 + math.floor(t / 2), Signals: 10 + math.floor(t / 2), Keys: { ForgeCrate: 1 } };
		}
		return { Stardust: 6 + math.floor(t / 3), Signals: 6 + math.floor(t / 2) };
	},
};

export = SeasonPremium;

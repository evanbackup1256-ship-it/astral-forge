type Profile = Record<string, unknown>;

const ProfileBagMath = {
	EnsureStats(this: void, profile: Profile): Record<string, unknown> {
		if (!typeIs(profile.Stats, "table")) {
			profile.Stats = {};
		}
		return profile.Stats as Record<string, unknown>;
	},

	AddFinite(this: void, current: unknown, amount: unknown, ceiling?: number): number {
		const cap = typeIs(ceiling, "number") && ceiling === ceiling ? ceiling : 1e308;
		let base = tonumber(current);
		if (base === undefined || base !== base || base === math.huge || base === -math.huge) {
			base = 0;
		}
		base = math.max(0, base);
		let delta = tonumber(amount);
		if (delta === undefined || delta !== delta || delta === math.huge || delta === -math.huge) {
			delta = 0;
		}
		let nextValue = base + delta;
		if (nextValue !== nextValue || nextValue === math.huge || nextValue > cap) {
			nextValue = cap;
		}
		return nextValue;
	},

	BumpStat(this: void, profile: Profile, key: string, amount?: number): number {
		const stats = ProfileBagMath.EnsureStats(profile);
		let rawDelta = tonumber(amount);
		if (rawDelta === undefined || rawDelta !== rawDelta || rawDelta === math.huge || rawDelta === -math.huge) {
			rawDelta = amount === undefined ? 1 : 0;
		}
		const delta = math.max(0, math.floor(math.min(rawDelta, 1e15)));
		stats[key] = math.floor(ProfileBagMath.AddFinite(stats[key], delta));
		return stats[key] as number;
	},

	EnsureDaily(this: void, profile: Profile): { LastClaimDay: number; Streak: number } {
		if (!typeIs(profile.Daily, "table")) {
			profile.Daily = { LastClaimDay: -1, Streak: 0 };
		}
		const daily = profile.Daily as { LastClaimDay: unknown; Streak: unknown };
		daily.LastClaimDay = math.floor(tonumber(daily.LastClaimDay) ?? -1);
		daily.Streak = math.max(0, math.floor(tonumber(daily.Streak) ?? 0));
		return daily as { LastClaimDay: number; Streak: number };
	},

	EnsureQuests(this: void, profile: Profile): { Day: number; Items: unknown[] } {
		if (!typeIs(profile.Quests, "table")) {
			profile.Quests = { Day: -1, Items: {} };
		} else if (!typeIs((profile.Quests as Record<string, unknown>).Items, "table")) {
			(profile.Quests as Record<string, unknown>).Items = {};
		}
		return profile.Quests as { Day: number; Items: unknown[] };
	},

	EnsureTimedRewards(this: void, profile: Profile): { Day: number; PlaySeconds: number; Claimed: Record<string, unknown> } {
		if (!typeIs(profile.TimedRewards, "table")) {
			profile.TimedRewards = { Day: -1, PlaySeconds: 0, Claimed: {} };
		} else if (!typeIs((profile.TimedRewards as Record<string, unknown>).Claimed, "table")) {
			(profile.TimedRewards as Record<string, unknown>).Claimed = {};
		}
		return profile.TimedRewards as { Day: number; PlaySeconds: number; Claimed: Record<string, unknown> };
	},

	EnsureItemKeys(this: void, profile: Profile): Record<string, number> {
		if (!typeIs(profile.Items, "table")) {
			profile.Items = { Keys: {} };
		} else if (!typeIs((profile.Items as Record<string, unknown>).Keys, "table")) {
			(profile.Items as Record<string, unknown>).Keys = {};
		}
		return (profile.Items as Record<string, unknown>).Keys as Record<string, number>;
	},

	EnsureItems(this: void, profile: Profile): Record<string, unknown> {
		if (!typeIs(profile.Items, "table")) {
			profile.Items = {
				Inventory: {},
				NextId: 1,
				Essence: 0,
				Keys: {},
				Pity: {},
				Equipped: {},
				Discovered: {},
				Shop: { Day: -1, Purchased: {}, Stock: {} },
				AutoSalvage: { Enabled: false, KeepNew: true, Rarities: { Common: true, Uncommon: true } },
			};
			return profile.Items as Record<string, unknown>;
		}
		const items = profile.Items as Record<string, unknown>;
		if (!typeIs(items.Inventory, "table")) {
			items.Inventory = {};
		}
		if (!typeIs(items.Keys, "table")) {
			items.Keys = {};
		}
		if (!typeIs(items.Pity, "table")) {
			items.Pity = {};
		}
		if (!typeIs(items.Equipped, "table")) {
			items.Equipped = {};
		}
		if (!typeIs(items.Discovered, "table")) {
			items.Discovered = {};
		}
		if (!typeIs(items.Shop, "table")) {
			items.Shop = { Day: -1, Purchased: {}, Stock: {} };
		} else {
			const shop = items.Shop as Record<string, unknown>;
			if (!typeIs(shop.Purchased, "table")) {
				shop.Purchased = {};
			}
			if (!typeIs(shop.Stock, "table")) {
				shop.Stock = {};
			}
			shop.Day = math.floor(tonumber(shop.Day) ?? -1);
		}
		items.Essence = math.max(0, math.floor(tonumber(items.Essence) ?? 0));
		items.NextId = math.max(1, math.floor(tonumber(items.NextId) ?? 1));
		return items;
	},

	EnsureAutoSalvage(this: void, profile: Profile): Record<string, unknown> {
		const items = ProfileBagMath.EnsureItems(profile);
		if (!typeIs(items.AutoSalvage, "table")) {
			items.AutoSalvage = { Enabled: false, KeepNew: true, Rarities: {} };
		}
		const autoSalvage = items.AutoSalvage as Record<string, unknown>;
		if (!typeIs(autoSalvage.Rarities, "table")) {
			autoSalvage.Rarities = {};
		}
		autoSalvage.Enabled = autoSalvage.Enabled === true;
		autoSalvage.KeepNew = autoSalvage.KeepNew !== false;
		return autoSalvage;
	},

	EnsureDailyShop(this: void, profile: Profile, day?: number, owned?: unknown): { Day: number; Bought: Record<string, number>; Owned: Record<string, boolean> } {
		if (!typeIs(profile.DailyShop, "table")) {
			profile.DailyShop = { Day: -1, Bought: {} };
		}
		const shop = profile.DailyShop as Record<string, unknown>;
		shop.Day = math.floor(tonumber(shop.Day) ?? -1);
		if (!typeIs(shop.Bought, "table")) {
			shop.Bought = {};
		}
		const bought = shop.Bought as Record<string, unknown>;
		for (const [slot, count] of pairs(bought)) {
			const n = tonumber(count);
			if (!typeIs(slot, "string") || n === undefined || n !== n || n < 0 || n > 1000) {
				bought[slot as string] = undefined;
			} else {
				bought[slot as string] = math.floor(n);
			}
		}
		if (day !== undefined && (shop.Day as number) !== day) {
			shop.Day = day;
			shop.Bought = {};
			shop.Owned = undefined;
		}
		if (!typeIs(shop.Owned, "table")) {
			shop.Owned = {};
			if (typeIs(owned, "table")) {
				const ownedTable = owned as Record<string, unknown>;
				for (const [id, has] of pairs(ownedTable)) {
					if (typeIs(id, "string") && has === true) {
						(shop.Owned as Record<string, boolean>)[id] = true;
					}
				}
			}
		} else {
			const ownedTable = shop.Owned as Record<string, unknown>;
			for (const [id, has] of pairs(ownedTable)) {
				if (!typeIs(id, "string") || has !== true) {
					ownedTable[id as string] = undefined;
				}
			}
		}
		return shop as { Day: number; Bought: Record<string, number>; Owned: Record<string, boolean> };
	},

	EnsureCosmetics(this: void, profile: Profile, knownSkin?: (id: string) => boolean): { CrateSkins: Record<string, boolean>; CrateSkin: string } {
		if (!typeIs(profile.Cosmetics, "table")) {
			profile.Cosmetics = { CrateSkins: { Classic: true }, CrateSkin: "Classic" };
		}
		const cosmetics = profile.Cosmetics as Record<string, unknown>;
		if (!typeIs(cosmetics.CrateSkins, "table")) {
			cosmetics.CrateSkins = {};
		}
		const skins = cosmetics.CrateSkins as Record<string, unknown>;
		for (const [id, owned] of pairs(skins)) {
			if (!typeIs(id, "string") || owned !== true || (knownSkin !== undefined && !knownSkin(id))) {
				skins[id as string] = undefined;
			}
		}
		skins.Classic = true;
		if (!typeIs(cosmetics.CrateSkin, "string") || skins[cosmetics.CrateSkin] !== true) {
			cosmetics.CrateSkin = "Classic";
		}
		return cosmetics as { CrateSkins: Record<string, boolean>; CrateSkin: string };
	},

	EnsureActiveBoost(this: void, profile: Profile): { Id: string; EndsAt: number } {
		if (!typeIs(profile.ActiveBoost, "table")) {
			profile.ActiveBoost = { Id: "", EndsAt: 0 };
		}
		const boost = profile.ActiveBoost as Record<string, unknown>;
		boost.EndsAt = math.max(0, math.floor(tonumber(boost.EndsAt) ?? 0));
		if (!typeIs(boost.Id, "string")) {
			boost.Id = "";
		}
		return boost as { Id: string; EndsAt: number };
	},

	EnsureBoostInventory(this: void, profile: Profile): Record<string, number> {
		if (!typeIs(profile.BoostInventory, "table")) {
			profile.BoostInventory = {};
		}
		return profile.BoostInventory as Record<string, number>;
	},

	EnsureFlags(this: void, profile: Profile): Record<string, unknown> {
		if (!typeIs(profile.Flags, "table")) {
			profile.Flags = {};
		}
		return profile.Flags as Record<string, unknown>;
	},

	EnsureDomain(this: void, profile: Profile): Record<string, unknown> {
		if (!typeIs(profile.Domain, "table")) {
			profile.Domain = {
				Rank: 0,
				Essence: 0,
				LastExpandedAt: 0,
				TotalRebirthsSpent: 0,
				TotalCoresSpent: 0,
				SkillPoints: 0,
				Links: {},
			};
		} else if (!typeIs((profile.Domain as Record<string, unknown>).Links, "table")) {
			(profile.Domain as Record<string, unknown>).Links = {};
		}
		const domain = profile.Domain as Record<string, unknown>;
		domain.Rank = math.max(0, math.floor(tonumber(domain.Rank) ?? 0));
		domain.Essence = math.max(0, math.floor(tonumber(domain.Essence) ?? 0));
		domain.SkillPoints = math.max(0, math.floor(tonumber(domain.SkillPoints) ?? 0));
		return domain;
	},

	EnsureAnomaly(this: void, profile: Profile): Record<string, unknown> {
		if (!typeIs(profile.Anomaly, "table")) {
			profile.Anomaly = {
				Charge: 0,
				Fragments: 0,
				Stabilizations: 0,
				Protocols: {},
				Discoveries: {},
				DirectiveProgress: {},
				DirectiveClaims: {},
				MilestoneClaims: {},
				Loadout: {},
				Channel: "",
				Cycle: -1,
				DirectiveCycle: -1,
				LastActionAt: 0,
				PulseWindowStartedAt: 0,
				Combo: 0,
				BestCombo: 0,
				CoreXP: 0,
				CoreTier: 0,
				SurgeEndsAt: 0,
			};
		} else {
			const anomaly = profile.Anomaly as Record<string, unknown>;
			if (!typeIs(anomaly.Protocols, "table")) {
				anomaly.Protocols = {};
			}
			if (!typeIs(anomaly.Discoveries, "table")) {
				anomaly.Discoveries = {};
			}
			if (!typeIs(anomaly.DirectiveProgress, "table")) {
				anomaly.DirectiveProgress = {};
			}
			if (!typeIs(anomaly.DirectiveClaims, "table")) {
				anomaly.DirectiveClaims = {};
			}
			if (!typeIs(anomaly.MilestoneClaims, "table")) {
				anomaly.MilestoneClaims = {};
			}
			if (!typeIs(anomaly.Loadout, "table")) {
				anomaly.Loadout = {};
			}
			if (!typeIs(anomaly.Channel, "string")) {
				anomaly.Channel = "";
			}
		}
		const anomaly = profile.Anomaly as Record<string, unknown>;
		anomaly.Charge = ProfileBagMath.AddFinite(anomaly.Charge, 0);
		anomaly.Fragments = math.floor(ProfileBagMath.AddFinite(anomaly.Fragments, 0));
		anomaly.Stabilizations = math.floor(ProfileBagMath.AddFinite(anomaly.Stabilizations, 0));
		const cycle = tonumber(anomaly.Cycle);
		anomaly.Cycle =
			typeIs(cycle, "number") && cycle === cycle && cycle !== math.huge && cycle !== -math.huge
				? math.floor(cycle)
				: -1;
		const directiveCycle = tonumber(anomaly.DirectiveCycle);
		anomaly.DirectiveCycle =
			typeIs(directiveCycle, "number") && directiveCycle === directiveCycle && directiveCycle !== math.huge && directiveCycle !== -math.huge
				? math.floor(directiveCycle)
				: -1;
		anomaly.LastActionAt = ProfileBagMath.AddFinite(anomaly.LastActionAt, 0);
		anomaly.PulseWindowStartedAt = ProfileBagMath.AddFinite(anomaly.PulseWindowStartedAt, 0);
		anomaly.Combo = math.floor(ProfileBagMath.AddFinite(anomaly.Combo, 0));
		anomaly.BestCombo = math.floor(ProfileBagMath.AddFinite(anomaly.BestCombo, 0));
		anomaly.CoreXP = math.floor(ProfileBagMath.AddFinite(anomaly.CoreXP, 0));
		anomaly.CoreTier = math.floor(ProfileBagMath.AddFinite(anomaly.CoreTier, 0));
		anomaly.SurgeEndsAt = ProfileBagMath.AddFinite(anomaly.SurgeEndsAt, 0);
		return anomaly;
	},

	EnsureContinuum(this: void, profile: Profile): Record<string, unknown> {
		if (!typeIs(profile.Continuum, "table")) {
			profile.Continuum = { Rank: 0, TotalFluxSpent: 0, TotalStardustSpent: 0 };
		}
		const continuum = profile.Continuum as Record<string, unknown>;
		continuum.Rank = math.max(0, math.floor(tonumber(continuum.Rank) ?? 0));
		return continuum;
	},

	EnsureFoundry(this: void, profile: Profile): Record<string, unknown> {
		if (!typeIs(profile.Foundry, "table")) {
			profile.Foundry = {
				Migrated: true,
				Radius: 2,
				Pieces: {},
				Bench: {},
				Shards: 0,
				Draws: 0,
				Combo: 0,
				BestCombo: 0,
				IgniteAt: 0,
				SurgeEndsAt: 0,
				LastAt: 0,
				Version: 0,
			};
		}
		return profile.Foundry as Record<string, unknown>;
	},
};

export = table.freeze(ProfileBagMath);

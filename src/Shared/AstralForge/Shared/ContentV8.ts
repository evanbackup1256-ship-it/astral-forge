// Purpose: version 8 content: relic sets, elemental companions, earned crate skins, titles, profile
// frames and accents, achievements, named late-game worlds and the next live events. Everything here
// is plain rows appended to the existing tables at load, so no system changes and no save changes:
// ids are new, nothing old is renamed, and every reward is Stardust/Cores/keys/boosts (no Robux).
// Copy lives in Locale under "Content.*". Owner: gameplay. Dependencies: Locale.
import { T } from "./Locale";

type Row = Record<string, unknown>;
type Rgb = [number, number, number];
const ENDLESS_LEVEL_CAP = 9_000_000_000_000_000;

export const RELIC_SETS: ReadonlyArray<{ Id: string; Name: string; Blurb: string; Relics: string[] }> = table.freeze([
	{ Id: "Drydock", Name: T("Content.Set.Drydock.Name"), Blurb: T("Content.Set.Drydock.Blurb"), Relics: ["BilgeWrench", "TallyLedger", "MooringHook", "HarbourBell"] },
	{ Id: "Lamplighter", Name: T("Content.Set.Lamplighter.Name"), Blurb: T("Content.Set.Lamplighter.Blurb"), Relics: ["WickTrimmer", "OilCan", "NightRoster", "GlassChimney"] },
	{ Id: "LastLight", Name: T("Content.Set.LastLight.Name"), Blurb: T("Content.Set.LastLight.Blurb"), Relics: ["SunsetGear", "DuskCompass", "FinalEmber", "KeepersOath"] },
]);

const RELICS: Row[] = [
	{ Id: "BilgeWrench", Name: T("Content.Relic.BilgeWrench.Name"), Description: T("Content.Relic.BilgeWrench.Desc"), Slot: "Machine", Rarity: "Uncommon", EffectKind: "Production", BaseEffect: 0.045, LevelGrowth: 0.22, MaxLevel: ENDLESS_LEVEL_CAP, EssenceBase: 26, Set: "Drydock" },
	{ Id: "TallyLedger", Name: T("Content.Relic.TallyLedger.Name"), Description: T("Content.Relic.TallyLedger.Desc"), Slot: "Research", Targets: ["Storage"], Rarity: "Uncommon", EffectKind: "Capacity", BaseEffect: 0.05, LevelGrowth: 0.24, MaxLevel: ENDLESS_LEVEL_CAP, EssenceBase: 28, Set: "Drydock" },
	{ Id: "MooringHook", Name: T("Content.Relic.MooringHook.Name"), Description: T("Content.Relic.MooringHook.Desc"), Slot: "Research", Targets: ["Offline"], Rarity: "Rare", EffectKind: "Offline", BaseEffect: 0.038, LevelGrowth: 0.2, MaxLevel: ENDLESS_LEVEL_CAP, EssenceBase: 45, Set: "Drydock" },
	{ Id: "HarbourBell", Name: T("Content.Relic.HarbourBell.Name"), Description: T("Content.Relic.HarbourBell.Desc"), Slot: "Research", Targets: ["Overcharge"], Rarity: "Rare", EffectKind: "Tap", BaseEffect: 0.05, LevelGrowth: 0.2, MaxLevel: ENDLESS_LEVEL_CAP, EssenceBase: 46, Set: "Drydock" },
	{ Id: "WickTrimmer", Name: T("Content.Relic.WickTrimmer.Name"), Description: T("Content.Relic.WickTrimmer.Desc"), Slot: "Research", Targets: ["Critical"], Rarity: "Epic", EffectKind: "Critical", BaseEffect: 0.018, LevelGrowth: 0.18, MaxLevel: ENDLESS_LEVEL_CAP, EssenceBase: 74, Set: "Lamplighter" },
	{ Id: "OilCan", Name: T("Content.Relic.OilCan.Name"), Description: T("Content.Relic.OilCan.Desc"), Slot: "Machine", Rarity: "Epic", EffectKind: "Production", BaseEffect: 0.11, LevelGrowth: 0.19, MaxLevel: ENDLESS_LEVEL_CAP, EssenceBase: 76, Set: "Lamplighter" },
	{ Id: "NightRoster", Name: T("Content.Relic.NightRoster.Name"), Description: T("Content.Relic.NightRoster.Desc"), Slot: "Research", Targets: ["Automation"], Rarity: "Legendary", EffectKind: "Automation", BaseEffect: 0.014, LevelGrowth: 0.18, MaxLevel: ENDLESS_LEVEL_CAP, EssenceBase: 118, Set: "Lamplighter" },
	{ Id: "GlassChimney", Name: T("Content.Relic.GlassChimney.Name"), Description: T("Content.Relic.GlassChimney.Desc"), Slot: "Research", Targets: ["Efficiency"], Rarity: "Legendary", EffectKind: "Production", BaseEffect: 0.17, LevelGrowth: 0.18, MaxLevel: ENDLESS_LEVEL_CAP, EssenceBase: 122, Set: "Lamplighter" },
	{ Id: "SunsetGear", Name: T("Content.Relic.SunsetGear.Name"), Description: T("Content.Relic.SunsetGear.Desc"), Slot: "Machine", Rarity: "Mythic", EffectKind: "Production", BaseEffect: 0.38, LevelGrowth: 0.16, MaxLevel: ENDLESS_LEVEL_CAP, EssenceBase: 205, Set: "LastLight" },
	{ Id: "DuskCompass", Name: T("Content.Relic.DuskCompass.Name"), Description: T("Content.Relic.DuskCompass.Desc"), Slot: "Research", Targets: ["Storage"], Rarity: "Mythic", EffectKind: "Capacity", BaseEffect: 0.3, LevelGrowth: 0.16, MaxLevel: ENDLESS_LEVEL_CAP, EssenceBase: 205, Set: "LastLight" },
	{ Id: "FinalEmber", Name: T("Content.Relic.FinalEmber.Name"), Description: T("Content.Relic.FinalEmber.Desc"), Slot: "Machine", Rarity: "Celestial", EffectKind: "Production", BaseEffect: 0.6, LevelGrowth: 0.15, MaxLevel: ENDLESS_LEVEL_CAP, EssenceBase: 320, Set: "LastLight" },
	{ Id: "KeepersOath", Name: T("Content.Relic.KeepersOath.Name"), Description: T("Content.Relic.KeepersOath.Desc"), Slot: "Research", Targets: ["Critical"], Rarity: "Celestial", EffectKind: "Critical", BaseEffect: 0.048, LevelGrowth: 0.15, MaxLevel: ENDLESS_LEVEL_CAP, EssenceBase: 320, Set: "LastLight" },
];

const COMPANIONS: Row[] = [
	{ Id: "HearthCoal", Name: T("Content.Companion.HearthCoal.Name"), Element: "Fire", Description: T("Content.Companion.HearthCoal.Desc"), Rarity: "COMMON", EffectKind: "Production", EffectPerLevel: 0.035, Color: Color3.fromRGB(255, 120, 60), ShopOnly: true },
	{ Id: "KettleSprite", Name: T("Content.Companion.KettleSprite.Name"), Element: "Steam", Description: T("Content.Companion.KettleSprite.Desc"), Rarity: "COMMON", EffectKind: "Offline", EffectPerLevel: 0.02, Color: Color3.fromRGB(220, 226, 236), ShopOnly: true },
	{ Id: "DuneCarver", Name: T("Content.Companion.DuneCarver.Name"), Element: "Sand", Description: T("Content.Companion.DuneCarver.Desc"), Rarity: "UNCOMMON", EffectKind: "Capacity", EffectPerLevel: 0.07, Color: Color3.fromRGB(230, 196, 130), ShopOnly: true },
	{ Id: "TidePup", Name: T("Content.Companion.TidePup.Name"), Element: "Water", Description: T("Content.Companion.TidePup.Desc"), Rarity: "UNCOMMON", EffectKind: "Tap", EffectPerLevel: 0.08, Color: Color3.fromRGB(70, 160, 240), ShopOnly: true },
	{ Id: "Bramblekin", Name: T("Content.Companion.Bramblekin.Name"), Element: "Nature", Description: T("Content.Companion.Bramblekin.Desc"), Rarity: "RARE", EffectKind: "Automation", EffectPerLevel: 0.008, Color: Color3.fromRGB(110, 200, 100), ShopOnly: true },
	{ Id: "Quarrytoad", Name: T("Content.Companion.Quarrytoad.Name"), Element: "Earth", Description: T("Content.Companion.Quarrytoad.Desc"), Rarity: "RARE", EffectKind: "OfflineHours", EffectPerLevel: 0.3, Color: Color3.fromRGB(150, 120, 90), ShopOnly: true },
	{ Id: "Hoarfrost", Name: T("Content.Companion.Hoarfrost.Name"), Element: "Ice", Description: T("Content.Companion.Hoarfrost.Desc"), Rarity: "EPIC", EffectKind: "Critical", EffectPerLevel: 0.009, Color: Color3.fromRGB(170, 225, 255), ShopOnly: true },
	{ Id: "Mirewisp", Name: T("Content.Companion.Mirewisp.Name"), Element: "Poison", Description: T("Content.Companion.Mirewisp.Desc"), Rarity: "EPIC", EffectKind: "Production", EffectPerLevel: 0.055, Color: Color3.fromRGB(150, 220, 80), ShopOnly: true },
	{ Id: "Whiteout", Name: T("Content.Companion.Whiteout.Name"), Element: "Blizzard", Description: T("Content.Companion.Whiteout.Desc"), Rarity: "LEGENDARY", EffectKind: "Capacity", EffectPerLevel: 0.11, Color: Color3.fromRGB(225, 240, 255), ShopOnly: true },
	{ Id: "Gloamstalker", Name: T("Content.Companion.Gloamstalker.Name"), Element: "Shadow", Description: T("Content.Companion.Gloamstalker.Desc"), Rarity: "LEGENDARY", EffectKind: "Critical", EffectPerLevel: 0.011, Color: Color3.fromRGB(90, 80, 140), ShopOnly: true },
	{ Id: "Heartwarden", Name: T("Content.Companion.Heartwarden.Name"), Element: "Blood", Description: T("Content.Companion.Heartwarden.Desc"), Rarity: "MYTHIC", EffectKind: "Tap", EffectPerLevel: 0.16, Color: Color3.fromRGB(200, 40, 70), ShopOnly: true },
	{ Id: "OldLantern", Name: T("Content.Companion.OldLantern.Name"), Element: "Spirit", Description: T("Content.Companion.OldLantern.Desc"), Rarity: "MYTHIC", EffectKind: "Production", EffectPerLevel: 0.12, Color: Color3.fromRGB(200, 230, 255), ShopOnly: true },
];

export const EARNED_SKINS: ReadonlyArray<{ Id: string; Name: string; Tier: string; Blurb: string; Accent: Rgb; Glow: Rgb; Vfx: string; Earn: { Kind: string; Target: number } }> = table.freeze([
	{ Id: "Footlocker", Name: T("Content.Skin.Footlocker.Name"), Tier: "Rare", Blurb: T("Content.Skin.Footlocker.Blurb"), Accent: [170, 150, 110], Glow: [240, 220, 170], Vfx: "embers", Earn: { Kind: "Rebirths", Target: 25 } },
	{ Id: "LampCase", Name: T("Content.Skin.LampCase.Name"), Tier: "Epic", Blurb: T("Content.Skin.LampCase.Blurb"), Accent: [255, 200, 110], Glow: [255, 236, 190], Vfx: "stars", Earn: { Kind: "Rebirths", Target: 75 } },
	{ Id: "TideChest", Name: T("Content.Skin.TideChest.Name"), Tier: "Epic", Blurb: T("Content.Skin.TideChest.Blurb"), Accent: [70, 160, 220], Glow: [190, 230, 255], Vfx: "frost", Earn: { Kind: "Visits", Target: 150 } },
	{ Id: "BargainBin", Name: T("Content.Skin.BargainBin.Name"), Tier: "Rare", Blurb: T("Content.Skin.BargainBin.Blurb"), Accent: [220, 170, 90], Glow: [255, 220, 160], Vfx: "shards", Earn: { Kind: "Trades", Target: 50 } },
	{ Id: "TapTin", Name: T("Content.Skin.TapTin.Name"), Tier: "Epic", Blurb: T("Content.Skin.TapTin.Blurb"), Accent: [200, 120, 255], Glow: [240, 200, 255], Vfx: "nebula", Earn: { Kind: "Taps", Target: 100000 } },
	{ Id: "Heirloom", Name: T("Content.Skin.Heirloom.Name"), Tier: "Legendary", Blurb: T("Content.Skin.Heirloom.Blurb"), Accent: [150, 90, 60], Glow: [255, 200, 150], Vfx: "magma", Earn: { Kind: "Crates", Target: 2500 } },
]);

const TITLES: Row[] = [
	{ Id: "OldHand", Name: T("Content.Title.OldHand.Name"), Description: T("Content.Title.OldHand.Desc"), Kind: "Rebirths", Target: 50, Fx: "ember" },
	{ Id: "Centurion", Name: T("Content.Title.Centurion.Name"), Description: T("Content.Title.Centurion.Desc"), Kind: "Rebirths", Target: 100, Fx: "starforge" },
	{ Id: "LongHauler", Name: T("Content.Title.LongHauler.Name"), Description: T("Content.Title.LongHauler.Desc"), Kind: "Expeditions", Target: 100, Fx: "comet" },
	{ Id: "Menagerie", Name: T("Content.Title.Menagerie.Name"), Description: T("Content.Title.Menagerie.Desc"), Kind: "Artifacts", Target: 57, Fx: "aurora" },
	{ Id: "Keeper", Name: T("Content.Title.Keeper.Name"), Description: T("Content.Title.Keeper.Desc"), Kind: "Artifacts", Target: 30, Fx: "frost" },
	{ Id: "Quadrillionaire", Name: T("Content.Title.Quadrillionaire.Name"), Description: T("Content.Title.Quadrillionaire.Desc"), Kind: "LifetimeCash", Target: 1e15, Fx: "molten" },
	{ Id: "Hoarder", Name: T("Content.Title.Hoarder.Name"), Description: T("Content.Title.Hoarder.Desc"), Kind: "Crates", Target: 2500, Fx: "chrome" },
	{ Id: "Broker", Name: T("Content.Title.Broker.Name"), Description: T("Content.Title.Broker.Desc"), Kind: "Trades", Target: 100, Fx: "shimmer" },
	{ Id: "Fixture", Name: T("Content.Title.Fixture.Name"), Description: T("Content.Title.Fixture.Desc"), Kind: "Visits", Target: 365, Fx: "glow" },
	{ Id: "SeasonStalwart", Name: T("Content.Title.SeasonStalwart.Name"), Description: T("Content.Title.SeasonStalwart.Desc"), Kind: "Seasons", Target: 50, Fx: "wave" },
];

export const FRAMES: ReadonlyArray<{ Id: string; Name: string; Description: string; Thickness: number; Gradient: boolean; Unlock: { Kind: string; Target: number } }> = table.freeze([
	{ Id: "Lanternlight", Name: T("Content.Frame.Lanternlight.Name"), Description: T("Content.Frame.Lanternlight.Desc"), Thickness: 2, Gradient: true, Unlock: { Kind: "Rebirths", Target: 100 } },
	{ Id: "Weathered", Name: T("Content.Frame.Weathered.Name"), Description: T("Content.Frame.Weathered.Desc"), Thickness: 3, Gradient: false, Unlock: { Kind: "Rebirths", Target: 200 } },
	{ Id: "Stamped", Name: T("Content.Frame.Stamped.Name"), Description: T("Content.Frame.Stamped.Desc"), Thickness: 1, Gradient: false, Unlock: { Kind: "Trades", Target: 100 } },
	{ Id: "Keyring", Name: T("Content.Frame.Keyring.Name"), Description: T("Content.Frame.Keyring.Desc"), Thickness: 2, Gradient: true, Unlock: { Kind: "Crates", Target: 1000 } },
	{ Id: "Calloused", Name: T("Content.Frame.Calloused.Name"), Description: T("Content.Frame.Calloused.Desc"), Thickness: 2, Gradient: false, Unlock: { Kind: "Taps", Target: 100000 } },
	{ Id: "Regulars", Name: T("Content.Frame.Regulars.Name"), Description: T("Content.Frame.Regulars.Desc"), Thickness: 1, Gradient: true, Unlock: { Kind: "Visits", Target: 200 } },
]);
export const ACCENTS: ReadonlyArray<{ Id: string; Name: string; Rgb: Rgb; Unlock: { Kind: string; Target: number } }> = table.freeze([
	{ Id: "Harbour", Name: T("Content.Accent.Harbour.Name"), Rgb: [150, 164, 180], Unlock: { Kind: "Rebirths", Target: 60 } },
	{ Id: "Wick", Name: T("Content.Accent.Wick.Name"), Rgb: [255, 170, 90], Unlock: { Kind: "Rebirths", Target: 120 } },
	{ Id: "Dusk", Name: T("Content.Accent.Dusk.Name"), Rgb: [214, 120, 150], Unlock: { Kind: "Rebirths", Target: 250 } },
	{ Id: "Kelp", Name: T("Content.Accent.Kelp.Name"), Rgb: [90, 150, 110], Unlock: { Kind: "Visits", Target: 100 } },
	{ Id: "Ledger", Name: T("Content.Accent.Ledger.Name"), Rgb: [70, 110, 190], Unlock: { Kind: "Trades", Target: 50 } },
	{ Id: "Sootfall", Name: T("Content.Accent.Sootfall.Name"), Rgb: [80, 80, 88], Unlock: { Kind: "Crates", Target: 1000 } },
]);

const ACHIEVEMENTS: Row[] = [
	{ Id: "HalfCentury", Name: T("Content.Achievement.HalfCentury.Name"), Description: T("Content.Achievement.HalfCentury.Desc"), Kind: "Rebirths", Target: 50, Reward: { Stardust: 480, Cores: 10, Essence: 6, Boost: "DomainSurge" } },
	{ Id: "Hundredfold", Name: T("Content.Achievement.Hundredfold.Name"), Description: T("Content.Achievement.Hundredfold.Desc"), Kind: "Rebirths", Target: 100, Reward: { Stardust: 650, Cores: 14, Essence: 10, Boost: "Hyperdrive" } },
	{ Id: "FarShore", Name: T("Content.Achievement.FarShore.Name"), Description: T("Content.Achievement.FarShore.Desc"), Kind: "Zone", Target: 25, Reward: { Stardust: 500, Cores: 12, Essence: 6, Boost: "StarforgeFlow" } },
	{ Id: "Halfway", Name: T("Content.Achievement.Halfway.Name"), Description: T("Content.Achievement.Halfway.Desc"), Kind: "Zone", Target: 50, Reward: { Stardust: 650, Cores: 15, Essence: 8, Boost: "Hyperdrive" } },
	{ Id: "Charted", Name: T("Content.Achievement.Charted.Name"), Description: T("Content.Achievement.Charted.Desc"), Kind: "Zone", Target: 125, Reward: { Stardust: 800, Cores: 18, Essence: 12, Boost: "DomainSurge" } },
	{ Id: "Landmark", Name: T("Content.Achievement.Landmark.Name"), Description: T("Content.Achievement.Landmark.Desc"), Kind: "Zone", Target: 150, Reward: { Stardust: 900, Cores: 20, Essence: 14, Boost: "StarforgeFlow" } },
	{ Id: "DomainTwentyFive", Name: T("Content.Achievement.DomainTwentyFive.Name"), Description: T("Content.Achievement.DomainTwentyFive.Desc"), Kind: "DomainRank", Target: 25, Reward: { Stardust: 750, Cores: 16, Essence: 20 } },
	{ Id: "DomainFifty", Name: T("Content.Achievement.DomainFifty.Name"), Description: T("Content.Achievement.DomainFifty.Desc"), Kind: "DomainRank", Target: 50, Reward: { Stardust: 900, Cores: 20, Essence: 26, Boost: "DomainSurge" } },
	{ Id: "Quadrillion", Name: T("Content.Achievement.Quadrillion.Name"), Description: T("Content.Achievement.Quadrillion.Desc"), Kind: "LifetimeCash", Target: 1e15, Reward: { Stardust: 400, Cores: 8 } },
	{ Id: "Quintillion", Name: T("Content.Achievement.Quintillion.Name"), Description: T("Content.Achievement.Quintillion.Desc"), Kind: "LifetimeCash", Target: 1e18, Reward: { Stardust: 600, Cores: 12, Essence: 6 } },
	{ Id: "Voyager", Name: T("Content.Achievement.Voyager.Name"), Description: T("Content.Achievement.Voyager.Desc"), Kind: "Expeditions", Target: 120, Reward: { Stardust: 320, Signals: 90, CashMinutes: 30, Boost: "Afterburner" } },
	{ Id: "RegularOrder", Name: T("Content.Achievement.RegularOrder.Name"), Description: T("Content.Achievement.RegularOrder.Desc"), Kind: "LabOrders", Target: 300, Reward: { Stardust: 420, Cores: 7, CashMinutes: 40, Boost: "NightShift" } },
	{ Id: "Steady", Name: T("Content.Achievement.Steady.Name"), Description: T("Content.Achievement.Steady.Desc"), Kind: "AnomalyStabilizations", Target: 150, Reward: { Stardust: 600, Cores: 12, Boost: "Hyperdrive" } },
	{ Id: "WheelWorn", Name: T("Content.Achievement.WheelWorn.Name"), Description: T("Content.Achievement.WheelWorn.Desc"), Kind: "WheelSpins", Target: 250, Reward: { Stardust: 380, Cores: 5, FreeSpins: 4 } },
	{ Id: "TwoMonths", Name: T("Content.Achievement.TwoMonths.Name"), Description: T("Content.Achievement.TwoMonths.Desc"), Kind: "DailyStreak", Target: 60, Reward: { Stardust: 450, Signals: 120, CashMinutes: 40, StreakShield: 1 } },
];

const LANDMARK_WORLDS: Record<number, { Name: string; Tagline: string; Lore: string }> = table.freeze({
	[150]: { Name: T("Content.World.150.Name"), Tagline: T("Content.World.150.Tagline"), Lore: T("Content.World.150.Lore") },
	[200]: { Name: T("Content.World.200.Name"), Tagline: T("Content.World.200.Tagline"), Lore: T("Content.World.200.Lore") },
	[250]: { Name: T("Content.World.250.Name"), Tagline: T("Content.World.250.Tagline"), Lore: T("Content.World.250.Lore") },
	[300]: { Name: T("Content.World.300.Name"), Tagline: T("Content.World.300.Tagline"), Lore: T("Content.World.300.Lore") },
	[400]: { Name: T("Content.World.400.Name"), Tagline: T("Content.World.400.Tagline"), Lore: T("Content.World.400.Lore") },
	[500]: { Name: T("Content.World.500.Name"), Tagline: T("Content.World.500.Tagline"), Lore: T("Content.World.500.Lore") },
	[750]: { Name: T("Content.World.750.Name"), Tagline: T("Content.World.750.Tagline"), Lore: T("Content.World.750.Lore") },
	[1000]: { Name: T("Content.World.1000.Name"), Tagline: T("Content.World.1000.Tagline"), Lore: T("Content.World.1000.Lore") },
	[1500]: { Name: T("Content.World.1500.Name"), Tagline: T("Content.World.1500.Tagline"), Lore: T("Content.World.1500.Lore") },
	[2500]: { Name: T("Content.World.2500.Name"), Tagline: T("Content.World.2500.Tagline"), Lore: T("Content.World.2500.Lore") },
	[5000]: { Name: T("Content.World.5000.Name"), Tagline: T("Content.World.5000.Tagline"), Lore: T("Content.World.5000.Lore") },
	[10000]: { Name: T("Content.World.10000.Name"), Tagline: T("Content.World.10000.Tagline"), Lore: T("Content.World.10000.Lore") },
});

export interface ContentEvent { Id: string; Name: string; Blurb: string; Token: string; Accent: Rgb; StartsAt: number; EndsAt: number; DailyCap: number; Shop: Array<{ Id: string; Name: string; Price: number; Stock: number; Reward: Record<string, unknown> }> }
export const EVENTS: ReadonlyArray<ContentEvent> = table.freeze([
	{ Id: "Tinkerweek2026", Name: T("Content.Event.Tinkerweek2026.Name"), Blurb: T("Content.Event.Tinkerweek2026.Blurb"), Token: T("Content.Event.Tinkerweek2026.Token"), Accent: [200, 170, 120], StartsAt: 1794528000, EndsAt: 1795737600, DailyCap: 600, Shop: [
		{ Id: "dust", Name: T("Content.Event.Tinkerweek2026.dust"), Price: 150, Stock: 10, Reward: { Stardust: 60 } },
		{ Id: "cinder", Name: T("Content.Event.Tinkerweek2026.cinder"), Price: 300, Stock: 6, Reward: { Keys: { CinderCrate: 1 } } },
		{ Id: "overdrive", Name: T("Content.Event.Tinkerweek2026.overdrive"), Price: 250, Stock: 4, Reward: { Boost: "Overdrive" } },
		{ Id: "signals", Name: T("Content.Event.Tinkerweek2026.signals"), Price: 200, Stock: 4, Reward: { Signals: 60 } },
		{ Id: "cores", Name: T("Content.Event.Tinkerweek2026.cores"), Price: 900, Stock: 3, Reward: { Cores: 4 } },
	] },
	{ Id: "Meltwater2027", Name: T("Content.Event.Meltwater2027.Name"), Blurb: T("Content.Event.Meltwater2027.Blurb"), Token: T("Content.Event.Meltwater2027.Token"), Accent: [120, 200, 210], StartsAt: 1801785600, EndsAt: 1802995200, DailyCap: 600, Shop: [
		{ Id: "dust", Name: T("Content.Event.Meltwater2027.dust"), Price: 150, Stock: 10, Reward: { Stardust: 60 } },
		{ Id: "tidal", Name: T("Content.Event.Meltwater2027.tidal"), Price: 400, Stock: 5, Reward: { Keys: { TidalCrate: 1 } } },
		{ Id: "vault", Name: T("Content.Event.Meltwater2027.vault"), Price: 250, Stock: 4, Reward: { Boost: "VaultSurge" } },
		{ Id: "spins", Name: T("Content.Event.Meltwater2027.spins"), Price: 200, Stock: 5, Reward: { FreeSpins: 2 } },
		{ Id: "cores", Name: T("Content.Event.Meltwater2027.cores"), Price: 900, Stock: 3, Reward: { Cores: 4 } },
	] },
	{ Id: "Starfall2027", Name: T("Content.Event.Starfall2027.Name"), Blurb: T("Content.Event.Starfall2027.Blurb"), Token: T("Content.Event.Starfall2027.Token"), Accent: [190, 170, 255], StartsAt: 1804809600, EndsAt: 1806019200, DailyCap: 600, Shop: [
		{ Id: "dust", Name: T("Content.Event.Starfall2027.dust"), Price: 150, Stock: 10, Reward: { Stardust: 60 } },
		{ Id: "nebula", Name: T("Content.Event.Starfall2027.nebula"), Price: 350, Stock: 6, Reward: { Keys: { NebulaCrate: 1 } } },
		{ Id: "hyperdrive", Name: T("Content.Event.Starfall2027.hyperdrive"), Price: 450, Stock: 3, Reward: { Boost: "Hyperdrive" } },
		{ Id: "shield", Name: T("Content.Event.Starfall2027.shield"), Price: 300, Stock: 2, Reward: { StreakShield: 1 } },
		{ Id: "cores", Name: T("Content.Event.Starfall2027.cores"), Price: 900, Stock: 3, Reward: { Cores: 4 } },
	] },
]);

function hasId(list: Row[], id: unknown): boolean {
	for (const row of list) {
		if (row.Id === id) {
			return true;
		}
	}
	return false;
}

function appendNew(list: unknown, rows: Row[]): void {
	if (!typeIs(list, "table")) {
		return;
	}
	const target = list as Row[];
	for (const row of rows) {
		if (!hasId(target, row.Id)) {
			target.push(table.clone(row));
		}
	}
}

export function landmarkWorld(id: number): { Name: string; Tagline: string; Lore: string } | undefined {
	return LANDMARK_WORLDS[id];
}

// Called once from the bottom of GameConfig. Appends rows and gives the landmark worlds their names;
// world stats still come from WorldCurve, so nothing about pacing moves.
export function extend(config: Row): void {
	const items = config.Items as Row;
	appendNew(items.Definitions, RELICS);
	const operations = config.Operations as Row;
	appendNew(operations.Artifacts, COMPANIONS);
	appendNew(operations.Titles, TITLES);
	appendNew(config.Achievements, ACHIEVEMENTS);
	const resolve = config.ResolveZone as ((id: number) => Row | undefined) | undefined;
	if (typeIs(resolve, "function")) {
		config.ResolveZone = (id: number) => {
			const zone = resolve(id);
			const landmark = typeIs(id, "number") ? LANDMARK_WORLDS[math.floor(id)] : undefined;
			if (zone === undefined || landmark === undefined || (config.Zones as Row[] as unknown as Record<number, unknown>)[id] !== undefined) {
				return zone;
			}
			zone.Name = landmark.Name;
			zone.Tagline = landmark.Tagline;
			zone.Lore = landmark.Lore;
			return zone;
		};
	}
}

export const COUNTS = table.freeze({
	Relics: RELICS.size(),
	RelicSets: RELIC_SETS.size(),
	Companions: COMPANIONS.size(),
	CrateSkins: EARNED_SKINS.size(),
	Titles: TITLES.size(),
	Frames: FRAMES.size(),
	Accents: ACCENTS.size(),
	Achievements: ACHIEVEMENTS.size(),
	Worlds: 12,
	Events: EVENTS.size(),
});

--!strict
-- Tuning for the two sanctuary features: ore outcrops and the Rift Warden.
--
-- Pure data (colours are plain RGB triples, not Color3) so the same numbers
-- are shared by the server services, the client and the Lune tests
-- (scripts/verify_sanctuary_world.luau). GameConfig exposes it as
-- GameConfig.Ore and GameConfig.RiftBoss.

export type Rgb = { number }

export type OreType = {
	Id: string,
	Name: string,
	-- Where it grows (SanctuaryLayout region id).
	Region: string,
	Color: Rgb,
	Glow: Rgb,
	YieldMin: number,
	YieldMax: number,
}

export type OreUpgrade = {
	Id: string,
	Name: string,
	Description: string,
	-- What it improves: Production / Capacity / Tap / BossDamage / OreYield.
	Effect: string,
	PerLevel: number,
	MaxLevel: number,
	-- Ore cost of the first level, by ore id; each level multiplies by Scale.
	Cost: { [string]: number },
	Scale: number,
}

local SanctuaryConfig = {}

SanctuaryConfig.Ore = {
	-- Seconds before a node a player mined grows back for that player.
	RegrowSeconds = 90,
	-- How long the mining prompt is held.
	HoldSeconds = 1.1,
	-- Mining reach: prompt distance, and the server's own check (with slack).
	PromptDistance = 12,
	ServerReach = 18,
	Types = {
		{
			Id = "Emberite",
			Name = "Emberite",
			Region = "Emberreach",
			Color = { 255, 128, 64 },
			Glow = { 255, 196, 120 },
			YieldMin = 3,
			YieldMax = 5,
		},
		{
			Id = "Voidglass",
			Name = "Voidglass",
			Region = "Hollows",
			Color = { 150, 104, 255 },
			Glow = { 206, 172, 255 },
			YieldMin = 2,
			YieldMax = 4,
		},
		{
			Id = "Starsteel",
			Name = "Starsteel",
			Region = "Spire",
			Color = { 140, 220, 255 },
			Glow = { 226, 248, 255 },
			YieldMin = 1,
			YieldMax = 2,
		},
	} :: { OreType },
	Upgrades = {
		{
			Id = "TemperedCores",
			Name = "Tempered Cores",
			Description = "Machines produce 3% more per level.",
			Effect = "Production",
			PerLevel = 0.03,
			MaxLevel = 30,
			Cost = { Emberite = 6 },
			Scale = 1.24,
		},
		{
			Id = "DeepVault",
			Name = "Deep Vault",
			Description = "The vault holds 4% more per level.",
			Effect = "Capacity",
			PerLevel = 0.04,
			MaxLevel = 25,
			Cost = { Voidglass = 5 },
			Scale = 1.26,
		},
		{
			Id = "ResonantStrike",
			Name = "Resonant Strike",
			Description = "Overcharge taps hit 5% harder per level.",
			Effect = "Tap",
			PerLevel = 0.05,
			MaxLevel = 25,
			Cost = { Emberite = 3, Voidglass = 3 },
			Scale = 1.27,
		},
		{
			Id = "StarsteelEdge",
			Name = "Starsteel Edge",
			Description = "Strikes on the Rift Warden land 8% harder per level.",
			Effect = "BossDamage",
			PerLevel = 0.08,
			MaxLevel = 15,
			Cost = { Starsteel = 3 },
			Scale = 1.32,
		},
		{
			Id = "ProspectorsEye",
			Name = "Prospector's Eye",
			Description = "Every outcrop gives 6% more ore per level.",
			Effect = "OreYield",
			PerLevel = 0.06,
			MaxLevel = 10,
			Cost = { Starsteel = 2, Emberite = 8 },
			Scale = 1.4,
		},
	} :: { OreUpgrade },
}

SanctuaryConfig.RiftBoss = {
	Name = "The Rift Warden",
	-- Quiet time between appearances, and the first appearance after a server starts.
	IntervalSeconds = 540,
	FirstDelaySeconds = 150,
	-- The Warden takes shape in the Riftmaw before it can be struck.
	FormingSeconds = 40,
	-- How long it stays before slipping back into the rift.
	ActiveSeconds = 150,
	-- How long the defeat / escape moment plays before it goes quiet.
	OutroSeconds = 6,
	-- Health: a base plus a share per fighter in the sanctuary when it wakes.
	BaseHealth = 900,
	HealthPerFighter = 700,
	-- Strikes.
	StrikeCooldown = 0.28,
	StrikeRange = 64,
	BaseDamage = 12,
	DamagePerLevel = 2.5,
	CritChance = 0.12,
	CritMultiplier = 2,
	-- Slams: a telegraphed ring on the arena floor that staggers anyone inside.
	SlamIntervalMin = 6,
	SlamIntervalMax = 9,
	SlamTelegraphSeconds = 1.7,
	SlamRadius = 24,
	DazeSeconds = 2.2,
	-- Fewer strikes than this and a fighter was only passing through.
	MinStrikesForReward = 3,
	-- Reward = Base + Share x (the fighter's share of all damage dealt).
	Rewards = {
		Stardust = { Base = 40, Share = 360 },
		Starsteel = { Base = 2, Share = 6 },
		Emberite = { Base = 4, Share = 8 },
		Voidglass = { Base = 3, Share = 7 },
	},
}

return SanctuaryConfig

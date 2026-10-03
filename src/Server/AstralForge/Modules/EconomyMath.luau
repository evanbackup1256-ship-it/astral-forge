--!strict
--[=[
	EconomyMath: merged module suite.
	Members (14): Economy, EconomyEnvelopeMath, ForgePathClaim, OfflineProjection, RebirthGate, TapCritProjection, UpgradeCostReason, ContinuumDomainMath, AnomalyOpsMath, ProgressionGate, ProgressionOpsMath, WheelMath, CrateRoll, OverchargeCombo.

	Each member keeps its original source inside its own closure (so every member
	still has its own local-register budget) and is evaluated lazily, exactly once,
	on first access.  Use `require(<this module>)("<Member>")` (or index the returned
	table with the member name) to get a member's exports.
]=]

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("EconomyMath: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("EconomyMath: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

-- ======================================================================
-- Module: Economy   (merged from Economy.luau, 668 lines)
-- ======================================================================
__defs["Economy"] = function()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
local OmegaMath = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("OmegaMath"))
local CapacityProjection = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))("CapacityProjection")
local LevelRewards = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))("LevelRewards")
local OfflineProjection = __load("OfflineProjection")
local TapCritProjection = __load("TapCritProjection")
local UpgradeCostReason = __load("UpgradeCostReason")
local RebirthGate = __load("RebirthGate")
local ContinuumDomainMath = __load("ContinuumDomainMath")
local ForgePathClaim = __load("ForgePathClaim")
local EconomyEnvelopeMath = __load("EconomyEnvelopeMath")
local ForgeEchoMath = require(script.Parent:WaitForChild("ForgeEchoMath"))
local AnomalyOpsMath = __load("AnomalyOpsMath")
local OreMath = require(script.Parent:WaitForChild("OreMath"))

local Economy = {}


type Persist = number | string

local function bounded(value: any): Persist
	return OmegaMath.Persist(value)
end

function Economy.Add(left: any, right: any): Persist
	return OmegaMath.Add(left, right)
end

function Economy.Sub(left: any, right: any): Persist
	return OmegaMath.Sub(left, right)
end

function Economy.Mul(left: any, right: any): Persist
	return OmegaMath.Mul(left, right)
end

function Economy.Lt(left: any, right: any): boolean
	return OmegaMath.Lt(left, right)
end

function Economy.Lte(left: any, right: any): boolean
	return OmegaMath.Lte(left, right)
end

function Economy.Gt(left: any, right: any): boolean
	return OmegaMath.Gt(left, right)
end

function Economy.Gte(left: any, right: any): boolean
	return OmegaMath.Gte(left, right)
end

function Economy.AsNumber(value: any): number
	return OmegaMath.ToNumber(value)
end

function Economy.Persist(value: any): Persist
	return OmegaMath.Persist(value)
end

function Economy.Floor(value: any): Persist
	return OmegaMath.Floor(value)
end

function Economy.Min(left: any, right: any): Persist
	return OmegaMath.Min(left, right)
end

function Economy.Max(left: any, right: any): Persist
	return OmegaMath.Max(left, right)
end

type ProfileLike = {
	Cash: Persist,
	Vault: Persist,
	Cores: number,
	Stardust: number,
	Rebirths: number,
	Domain: {
		Rank: number,
		Essence: number,
	}?,
	Continuum: {
		Rank: number,
		TotalFluxSpent: number,
		TotalStardustSpent: number,
	}?,
	RunCash: Persist,
	Zone: number,
	CurrentZone: number,
	Machines: { [string]: number },
	Research: { [string]: number },
	GridUpgrades: { [string]: number },
	ActiveBoost: { Id: string, EndsAt: number },
	Items: {
		Inventory: { [string]: { DefinitionId: string, Level: number, AcquiredAt: number } },
		Equipped: { [string]: string },
	}?,
	Command: {
		EquippedArtifact: string,
		Artifacts: { [string]: { Level: number, Fragments: number } },
		MachineMastery: { [string]: number },
	}?,
	Anomaly: {
		SurgeEndsAt: number,
		Channel: string,
		Protocols: { [string]: number },
		Loadout: { string }?,
		CoreTier: number?,
	}?,
	Lab: {
		Routing: { [string]: number },
	}?,
	OwnedPasses: { [string]: boolean }?,
	GuildBonuses: { Production: number, Capacity: number, Offline: number, Automation: number, Tap: number }?,
	SocialBoost: { FriendCount: number, FriendBonus: number, Premium: boolean, PremiumBonus: number, Multiplier: number }?,
	ForgeEchoes: {
		Captures: number,
		Inventory: { [string]: { TraitId: string, Level: number, Strength: number } },
		Equipped: { [string]: string },
	}?,
	ForgePath: {
		ClaimedSteps: { [string]: boolean },
		XP: number,
	}?,
}

function Economy.LabPowerEffect(profile: ProfileLike, channelId: string): number
	local lab = profile.Lab
	local channel = GameConfig.Lab.Power.Channels[channelId]
	if not lab or not lab.Routing or not channel then
		return 0
	end
	return EconomyEnvelopeMath.LabPowerEffect(lab.Routing, channelId, channel)
end

local machineById = {}
for _, machine in GameConfig.Machines do
	machineById[machine.Id] = machine
end

local researchById = {}
for _, research in GameConfig.Research do
	researchById[research.Id] = research
end

local gridById = {}
for _, upgrade in GameConfig.GridUpgrades do
	gridById[upgrade.Id] = upgrade
end

function Economy.GetMachine(id: string)
	return machineById[id]
end

function Economy.GetResearch(id: string)
	return researchById[id]
end

function Economy.GetGridUpgrade(id: string)
	return gridById[id]
end

function Economy.GetArtifact(id: string)
	for _, artifact in GameConfig.Operations.Artifacts do
		if artifact.Id == id then
			return artifact
		end
	end
	return nil
end

function Economy.GetItemDefinition(id: string)
	for _, definition in GameConfig.Items.Definitions do
		if definition.Id == id then
			return definition
		end
	end
	return nil
end

function Economy.ItemEffect(
	profile: ProfileLike,
	effectKind: string,
	slotFilter: string?,
	targetFilter: string?
): number
	-- ApplyReward Keys / partial Studio fixtures may leave Items without Equipped
	-- or Inventory tables — production projections must not throw.
	-- Nil-safe Machines/Research: mid-sanitize / partial fixtures must not throw
	-- when Equipped still points at a slot bag that reconcile has not finished.
	return EconomyEnvelopeMath.ItemEffect(
		profile.Items,
		profile.Machines,
		profile.Research,
		effectKind,
		Economy.GetItemDefinition,
		slotFilter,
		targetFilter
	)
end

function Economy.ArtifactEffect(profile: ProfileLike, effectKind: string): number
	local command = profile.Command
	if not command or command.EquippedArtifact == "" then
		return 0
	end
	-- Partial Command bags (ensureCommand Signals path) may omit Artifacts.
	if type(command.Artifacts) ~= "table" then
		return 0
	end
	local artifact = Economy.GetArtifact(command.EquippedArtifact)
	local owned = command.Artifacts[command.EquippedArtifact]
	if not artifact or not owned then
		return 0
	end
	return EconomyEnvelopeMath.ArtifactLevelEffect(artifact, owned, effectKind)
end

function Economy.MasteryMultiplier(profile: ProfileLike): number
	local command = profile.Command
	if not command then
		return 1
	end
	return EconomyEnvelopeMath.MasteryMultiplier(command.MachineMastery)
end

function Economy.GridEffect(profile: ProfileLike, effectKind: string): number
	return EconomyEnvelopeMath.GridEffect(profile.GridUpgrades, gridById, effectKind)
end

function Economy.AnomalyEffect(profile: ProfileLike, effectKind: string, now: number?): number
	local state = profile.Anomaly
	if not state then
		return 0
	end
	return AnomalyOpsMath.Effect(state, effectKind, GameConfig.Anomalies.Protocols, GameConfig.Anomalies.Channels, GameConfig.Anomalies.Types, GameConfig.Anomalies.CycleSeconds, now or os.time(), GameConfig.Anomalies.CoreTiers)
end

function Economy.AnomalySurgeMultiplier(profile: ProfileLike, now: number?): number
	return AnomalyOpsMath.SurgeMultiplier(profile.Anomaly, now or os.time(), GameConfig.Anomalies.SurgeMultiplier)
end

function Economy.GetZone(id: number)
	return GameConfig.ResolveZone(id)
end

function Economy.MaxZone(): number
	return GameConfig.MaxZone
end

function Economy.GetExpedition(id: string)
	return GameConfig.ResolveExpedition(id)
end

function Economy.DomainTreeBonus(profile: ProfileLike, field: string): number
	local domain = profile.Domain
	return EconomyEnvelopeMath.DomainTreeBonus(domain and domain.Nodes, GameConfig.Domain.Tree, field)
end

function Economy.MachineCost(id: string, currentLevel: number): number
	return UpgradeCostReason.LevelCost(OmegaMath, Economy.GetMachine(id), currentLevel)
end

function Economy.ResearchCost(id: string, currentLevel: number): number
	return UpgradeCostReason.LevelCost(OmegaMath, Economy.GetResearch(id), currentLevel)
end

function Economy.GridUpgradeCost(id: string, currentLevel: number): number
	return UpgradeCostReason.LevelCost(OmegaMath, Economy.GetGridUpgrade(id), currentLevel)
end

function Economy.GridBulkCost(id: string, currentLevel: number, count: number): Persist
	return UpgradeCostReason.BulkCost(OmegaMath, Economy.GetGridUpgrade(id), currentLevel, count)
end

function Economy.AffordableGridLevels(
	id: string,
	currentLevel: number,
	stardust: any,
	maximum: number
): (number, Persist)
	return UpgradeCostReason.AffordableLevels(OmegaMath, Economy.GetGridUpgrade(id), currentLevel, stardust, maximum)
end

function Economy.MachineBulkCost(id: string, currentLevel: number, count: number): Persist
	return UpgradeCostReason.BulkCost(OmegaMath, Economy.GetMachine(id), currentLevel, count)
end

function Economy.ResearchBulkCost(id: string, currentLevel: number, count: number): Persist
	return UpgradeCostReason.BulkCost(OmegaMath, Economy.GetResearch(id), currentLevel, count)
end

function Economy.AffordableMachineLevels(
	id: string,
	currentLevel: number,
	cash: any,
	maximum: number
): (number, Persist)
	return UpgradeCostReason.AffordableLevels(OmegaMath, Economy.GetMachine(id), currentLevel, cash, maximum)
end

function Economy.AffordableResearchLevels(
	id: string,
	currentLevel: number,
	cash: any,
	maximum: number
): (number, Persist)
	return UpgradeCostReason.AffordableLevels(OmegaMath, Economy.GetResearch(id), currentLevel, cash, maximum)
end

function Economy.RawProduction(profile: ProfileLike): Persist
	local total: Persist = 0
	local owned = profile.Machines
	if type(owned) ~= "table" then
		return 0
	end
	for id, level in owned do
		if type(level) == "number" and level > 0 then
			local machine = machineById[id]
			if machine then
				local itemMultiplier = 1
					+ Economy.ItemEffect(profile, "Production", "Machine", "Machine:" .. machine.Id)
				local piece = OmegaMath.Mul(
					OmegaMath.Mul(machine.BaseProduction, level),
					(1 + machine.Growth * math.max(0, level - 1)) * itemMultiplier
				)
				total = OmegaMath.Add(total, piece)
			end
		end
	end
	return total
end


function Economy.PassBonuses(profile: ProfileLike): (number, number)
	local owned = profile.OwnedPasses
	if type(owned) ~= "table" then
		return 0, 0
	end
	local MonetizationConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))("MonetizationConfig")
	return MonetizationConfig.PassBonuses(owned)
end

-- Sums EffectAmount (a whole-number percentage, e.g. 2 = "+2%") across every claimed
-- Forge Path step whose EffectKind matches, returning a 0..N fraction ready to use the
-- same way GridEffect/EchoEffect/ArtifactEffect/ItemEffect already are: `1 + result`.
function Economy.ForgePathEffect(profile: ProfileLike?, effectKind: string): number
	local forgePath = profile and profile.ForgePath
	if forgePath == nil then
		return 0
	end
	-- ClaimedSteps may be missing on partial ForgePath bags (corrupt save / mid
	-- ensure). ProgressionGate already guards this; PermanentMultiplier must too
	-- or a single missing table throws the whole production tick.
	return ForgePathClaim.Effect(forgePath.ClaimedSteps, GameConfig.ForgePath.Steps, effectKind)
end

function Economy.PermanentMultiplier(profile: ProfileLike): Persist
	local domain = profile.Domain
	local insightResearch = profile.Research
	local insightLevel = (type(insightResearch) == "table" and insightResearch.Insight) or 0
	return bounded(EconomyEnvelopeMath.PermanentMultiplier(
		profile.Cores,
		GameConfig.Economy.CoreMultiplier,
		GameConfig.Economy.CoreExponent,
		domain and domain.Rank or 0,
		domain and domain.Essence or 0,
		1_000_000,
		GameConfig.Domain.ProductionPerRank,
		GameConfig.Domain.ProductionPerEssence,
		Economy.DomainTreeBonus(profile, "Production"),
		Economy.ForgePathEffect(profile, "Production"),
		profile.Rebirths,
		GameConfig.Economy.RebirthMultiplier,
		Economy.ForgePathEffect(profile, "RebirthMultiplier"),
		insightLevel
	))
end


-- Bonus from the Foundry's ore upgrades (0.12 = +12%): Production, Capacity,
-- Tap, BossDamage or OreYield.
function Economy.OreEffect(profile: ProfileLike, effectKind: string): number
	return OreMath.Effect((profile :: any).OreUpgrades, effectKind, GameConfig.Ore)
end

function Economy.EchoEffect(profile: ProfileLike, effectKind: string): number
	return ForgeEchoMath.EquippedEffect(
		profile.ForgeEchoes,
		effectKind,
		GameConfig.ForgeEchoes.Traits,
		GameConfig.ForgeEchoes.MaxLevel,
		GameConfig.ForgeEchoes.HarmonyBonus
	)
end

function Economy.ContinuumCosts(rank: number): (Persist, Persist)
	return ContinuumDomainMath.ContinuumCosts(OmegaMath, GameConfig.Continuum, rank)
end

function Economy.ContinuumEffects(profile: ProfileLike): (Persist, Persist, Persist, number)
	local rank = profile.Continuum and math.max(0, math.floor(profile.Continuum.Rank or 0)) or 0
	return ContinuumDomainMath.ContinuumEffects(OmegaMath, GameConfig.Continuum, rank)
end

function Economy.DomainRequirements(rank: number): (number, number)
	return ContinuumDomainMath.DomainRequirements(OmegaMath, GameConfig.Domain, rank)
end

function Economy.DomainRewards(rank: number): (number, number)
	return ContinuumDomainMath.DomainRewards(GameConfig.Domain, rank)
end

function Economy.Production(profile: ProfileLike, now: number?): Persist
	local research = profile.Research
	local efficiencyLevel = (type(research) == "table" and research.Efficiency) or 0
	local zone = Economy.GetZone(profile.CurrentZone) or GameConfig.Zones[1]
	local passProduction = select(1, Economy.PassBonuses(profile))
	local multiplier = OmegaMath.Mul(1 + efficiencyLevel * 0.15, zone.Multiplier)
	multiplier = OmegaMath.Mul(multiplier, Economy.PermanentMultiplier(profile))
	multiplier = OmegaMath.Mul(multiplier, 1 + Economy.GridEffect(profile, "GridProduction"))
	multiplier = OmegaMath.Mul(multiplier, 1 + Economy.EchoEffect(profile, "Production"))
	multiplier = OmegaMath.Mul(multiplier, 1 + Economy.ArtifactEffect(profile, "Production"))
	multiplier = OmegaMath.Mul(multiplier, 1 + Economy.ItemEffect(profile, "Production", "Research"))
	multiplier = OmegaMath.Mul(multiplier, 1 + Economy.AnomalyEffect(profile, "Production", now))
	multiplier = OmegaMath.Mul(multiplier, 1 + Economy.LabPowerEffect(profile, "Production"))
	multiplier = OmegaMath.Mul(multiplier, 1 + Economy.OreEffect(profile, "Production"))
	multiplier = OmegaMath.Mul(multiplier, 1 + passProduction)
	multiplier = OmegaMath.Mul(multiplier, 1 + (profile.GuildBonuses and profile.GuildBonuses.Production or 0))
	multiplier = OmegaMath.Mul(multiplier, math.max(1, profile.SocialBoost and profile.SocialBoost.Multiplier or 1))
	multiplier = OmegaMath.Mul(multiplier, Economy.MasteryMultiplier(profile))
	multiplier = OmegaMath.Mul(multiplier, Economy.AnomalySurgeMultiplier(profile, now))
	multiplier = OmegaMath.Mul(multiplier, select(1, Economy.ContinuumEffects(profile)))
	-- Forge Level mastery (permanent) and the Forge Surge from recent level-ups (timed).
	local progression = profile.Progression
	if type(progression) == "table" then
		multiplier = OmegaMath.Mul(multiplier, 1 + LevelRewards.mastery(tonumber(progression.RewardedLevel) or 0))
		multiplier = OmegaMath.Mul(multiplier, LevelRewards.surgeMultiplier(progression.Surge, now or os.time()))
	end
	local activeBoost = profile.ActiveBoost
	if activeBoost and activeBoost.EndsAt > (now or os.time()) then
		local boost = GameConfig.Boosts[activeBoost.Id]
		if boost and boost.Multiplier then
			multiplier = OmegaMath.Mul(multiplier, boost.Multiplier)
		end
	end
	return OmegaMath.Mul(Economy.RawProduction(profile), multiplier)
end

-- Permanent/steady production only: excludes ActiveBoost.Multiplier and Anomaly Surge.
-- Flux Surge / Convergence are applied by callers on top of Production — never feed those
-- into Capacity. When temporary multipliers end, vault clamps and overflow deletes.
function Economy.SteadyProduction(profile: ProfileLike, now: number?): Persist
	-- Nil-safe Research: migration edges and partial fixtures can hit SteadyProduction
	-- (lab bank targets, vault capacity) before sanitize finishes Research bags.
	local research = profile.Research
	local efficiencyLevel = (type(research) == "table" and research.Efficiency) or 0
	local zone = Economy.GetZone(profile.CurrentZone) or GameConfig.Zones[1]
	local passProduction = select(1, Economy.PassBonuses(profile))
	return CapacityProjection.SteadyProduction(OmegaMath, Economy.RawProduction(profile), {
		EfficiencyLevel = efficiencyLevel,
		ZoneMultiplier = zone.Multiplier,
		PermanentMultiplier = Economy.PermanentMultiplier(profile),
		Additives = {
			Economy.GridEffect(profile, "GridProduction"),
			Economy.EchoEffect(profile, "Production"),
			Economy.ArtifactEffect(profile, "Production"),
			Economy.ItemEffect(profile, "Production", "Research"),
			Economy.AnomalyEffect(profile, "Production", now),
			Economy.LabPowerEffect(profile, "Production"),
			passProduction,
			profile.GuildBonuses and profile.GuildBonuses.Production or 0,
			Economy.OreEffect(profile, "Production"),
		},
		SocialMultiplier = profile.SocialBoost and profile.SocialBoost.Multiplier or 1,
		MasteryMultiplier = Economy.MasteryMultiplier(profile),
		ContinuumProduction = select(1, Economy.ContinuumEffects(profile)),
	})
end

function Economy.Capacity(profile: ProfileLike, now: number?, _production: any): Persist
	local research = profile.Research
	local storageLevel = (type(research) == "table" and research.Storage) or 0
	local passCapacity = select(2, Economy.PassBonuses(profile))
	local _, continuumCapacity = Economy.ContinuumEffects(profile)
	local domainRank = profile.Domain and math.max(0, profile.Domain.Rank or 0) or 0
	local boostCapacityMultiplier = 1
	local activeBoost = profile.ActiveBoost
	if activeBoost and activeBoost.EndsAt > (now or os.time()) then
		local boost = GameConfig.Boosts[activeBoost.Id]
		if boost and boost.CapacityMultiplier then
			boostCapacityMultiplier = boost.CapacityMultiplier
		end
	end
	local seconds = CapacityProjection.Seconds({
		BaseSeconds = GameConfig.Economy.BaseCapacitySeconds,
		SecondsPerLevel = GameConfig.Economy.CapacitySecondsPerLevel,
		StorageLevel = storageLevel,
		Additives = {
			Economy.GridEffect(profile, "GridCapacity"),
			Economy.EchoEffect(profile, "Capacity"),
			Economy.ArtifactEffect(profile, "Capacity"),
			Economy.ItemEffect(profile, "Capacity", "Research"),
			Economy.AnomalyEffect(profile, "Capacity", now),
			Economy.LabPowerEffect(profile, "Storage"),
			passCapacity,
			profile.GuildBonuses and profile.GuildBonuses.Capacity or 0,
			Economy.ForgePathEffect(profile, "Capacity"),
			Economy.OreEffect(profile, "Capacity"),
		},
		DomainRank = domainRank,
		CapacityPerRank = GameConfig.Domain.CapacityPerRank,
		BoostCapacityMultiplier = boostCapacityMultiplier,
		MaxSeconds = GameConfig.Economy.MaxCapacitySeconds,
		DomainTreeCapacity = Economy.DomainTreeBonus(profile, "Capacity"),
	})
	local output = Economy.SteadyProduction(profile, now)
	return CapacityProjection.Vault(
		OmegaMath,
		GameConfig.Economy.BaseCapacity,
		output,
		seconds,
		continuumCapacity
	)
end


function Economy.CapacitySeconds(profile: ProfileLike, now: number?, _production: any): number
	local output = Economy.SteadyProduction(profile, now)
	return CapacityProjection.CapacitySeconds(OmegaMath, Economy.Capacity(profile, now), output, Economy.Lte)
end

local function researchLevel(profile: ProfileLike, key: string): number
	local research = profile.Research
	if type(research) ~= "table" then
		return 0
	end
	return research[key] or 0
end

function Economy.TapPower(profile: ProfileLike, now: number?): Persist
	-- Same nil-safe Research path as SteadyProduction: partial fixtures / mid-sanitize
	-- profiles must not throw on Overcharge reads during Overcharge / tap grants.
	return TapCritProjection.TapPower(OmegaMath, Economy.Production(profile, now), researchLevel(profile, "Overcharge"), {
		Grid = Economy.GridEffect(profile, "GridTap"),
		Echo = Economy.EchoEffect(profile, "Tap"),
		Artifact = Economy.ArtifactEffect(profile, "Tap"),
		Item = Economy.ItemEffect(profile, "Tap", "Research"),
		Anomaly = Economy.AnomalyEffect(profile, "Tap", now),
		Lab = Economy.LabPowerEffect(profile, "Tap"),
		Guild = profile.GuildBonuses and profile.GuildBonuses.Tap or 0,
		Continuum = select(3, Economy.ContinuumEffects(profile)),
		ForgePath = Economy.ForgePathEffect(profile, "TapPower"),
		Ore = Economy.OreEffect(profile, "Tap"),
	})
end

function Economy.CriticalChance(profile: ProfileLike): number
	return TapCritProjection.CriticalChance(
		researchLevel(profile, "Critical"),
		Economy.GridEffect(profile, "GridCritical"),
		Economy.EchoEffect(profile, "Critical"),
		Economy.ArtifactEffect(profile, "Critical"),
		Economy.ItemEffect(profile, "Critical", "Research"),
		Economy.AnomalyEffect(profile, "Critical"),
		Economy.ForgePathEffect(profile, "CriticalChance")
	)
end

function Economy.CriticalMultiplier(profile: ProfileLike): number
	return TapCritProjection.CriticalMultiplier(
		researchLevel(profile, "Critical"),
		researchLevel(profile, "Impact"),
		Economy.ForgePathEffect(profile, "CriticalMultiplier")
	)
end

function Economy.AutoCollectRate(profile: ProfileLike): number
	return EconomyEnvelopeMath.AutoCollectRate(
		researchLevel(profile, "Automation"),
		Economy.GridEffect(profile, "GridAutomation"),
		Economy.EchoEffect(profile, "Automation"),
		Economy.ArtifactEffect(profile, "Automation"),
		Economy.ItemEffect(profile, "Automation", "Research"),
		Economy.AnomalyEffect(profile, "Automation"),
		profile.GuildBonuses and profile.GuildBonuses.Automation or 0,
		Economy.ForgePathEffect(profile, "AutoCollect")
	)
end

function Economy.OfflineHours(profile: ProfileLike): number
	return EconomyEnvelopeMath.OfflineHours(
		GameConfig.Economy.BaseOfflineHours,
		researchLevel(profile, "Offline"),
		Economy.ArtifactEffect(profile, "OfflineHours"),
		24
	)
end

function Economy.OfflineEfficiency(profile: ProfileLike, now: number?): number
	local _, _, _, continuumOffline = Economy.ContinuumEffects(profile)
	return EconomyEnvelopeMath.OfflineEfficiency(
		GameConfig.Economy.BaseOfflineEfficiency,
		researchLevel(profile, "Offline"),
		Economy.GridEffect(profile, "GridOffline"),
		Economy.EchoEffect(profile, "Offline"),
		Economy.ArtifactEffect(profile, "Offline"),
		Economy.ItemEffect(profile, "Offline", "Research"),
		Economy.AnomalyEffect(profile, "Offline", now),
		profile.GuildBonuses and profile.GuildBonuses.Offline or 0,
		profile.Domain and math.max(0, profile.Domain.Rank or 0) or 0,
		GameConfig.Domain.OfflineEfficiencyPerRank,
		continuumOffline,
		Economy.ForgePathEffect(profile, "Offline")
	)
end


function Economy.OfflineEarnings(
	profile: ProfileLike,
	startedAt: number,
	endedAt: number
): (Persist, number, number, boolean)
	return OfflineProjection.Project(
		startedAt,
		endedAt,
		Economy.OfflineHours(profile) * 3600,
		30,
		GameConfig.Anomalies.CycleSeconds,
		profile.ActiveBoost and profile.ActiveBoost.EndsAt or 0,
		profile.Anomaly and profile.Anomaly.SurgeEndsAt or 0,
		function(sample: number)
			return {
				Production = Economy.Production(profile, sample),
				Efficiency = Economy.OfflineEfficiency(profile, sample),
			}
		end,
		Economy.Add,
		Economy.Mul,
		bounded
	)
end

function Economy.PrestigeReward(runCash: any): Persist
	return RebirthGate.PrestigeReward(
		OmegaMath,
		runCash,
		GameConfig.Economy.PrestigeRequirement,
		GameConfig.Economy.PrestigeExponent,
		Economy.Lt
	)
end

function Economy.NextPrestigeTarget(currentReward: any): Persist
	return RebirthGate.NextPrestigeTarget(
		OmegaMath,
		currentReward,
		GameConfig.Economy.PrestigeRequirement,
		GameConfig.Economy.PrestigeExponent
	)
end

function Economy.TotalMachineLevels(profile: ProfileLike): number
	return EconomyEnvelopeMath.SumNumericLevels(profile.Machines)
end

function Economy.TotalResearchLevels(profile: ProfileLike): number
	return EconomyEnvelopeMath.SumNumericLevels(profile.Research)
end

return table.freeze(Economy)
end

-- ======================================================================
-- Module: EconomyEnvelopeMath   (merged from EconomyEnvelopeMath.luau, 266 lines)
-- ======================================================================
__defs["EconomyEnvelopeMath"] = function()
-- Pure economy envelope helpers: bag level sums, auto-collect / offline hours /
-- offline efficiency caps, mastery + domain-tree bonuses. No Roblox services —
-- Economy and Lune verify scripts share this so RunQuick-adjacent envelopes stay
-- offline-testable. Effect totals (grid/echo/…) are injected by the caller.

local EconomyEnvelopeMath = {}

-- Sums numeric values in a bag (Machines / Research). Non-tables → 0.
function EconomyEnvelopeMath.SumNumericLevels(bag: any): number
	if type(bag) ~= "table" then
		return 0
	end
	local total = 0
	for _, value in bag do
		if type(value) == "number" then
			total += value
		end
	end
	return total
end

-- Soft-capped auto-collect rate. Parts are already fractional addends.
function EconomyEnvelopeMath.AutoCollectRate(
	automationLevel: number,
	grid: number,
	echo: number,
	artifact: number,
	item: number,
	anomaly: number,
	guild: number,
	forgePath: number
): number
	return math.min(
		0.8,
		math.max(0, tonumber(automationLevel) or 0) * 0.02
			+ (tonumber(grid) or 0)
			+ (tonumber(echo) or 0)
			+ (tonumber(artifact) or 0)
			+ (tonumber(item) or 0)
			+ (tonumber(anomaly) or 0)
			+ (tonumber(guild) or 0)
			+ (tonumber(forgePath) or 0)
	)
end

-- Offline hours soft-capped at `cap` (default 24).
function EconomyEnvelopeMath.OfflineHours(
	baseHours: number,
	researchOffline: number,
	artifactOffline: number,
	cap: number?
): number
	local softCap = if type(cap) == "number" then cap else 24
	return math.min(
		softCap,
		(tonumber(baseHours) or 0)
			+ math.max(0, tonumber(researchOffline) or 0) * 1.25
			+ (tonumber(artifactOffline) or 0)
	)
end

-- Offline efficiency soft-capped at 1. Continuum offline addend is already a fraction.
function EconomyEnvelopeMath.OfflineEfficiency(
	baseEfficiency: number,
	researchOffline: number,
	grid: number,
	echo: number,
	artifact: number,
	item: number,
	anomaly: number,
	guild: number,
	domainRank: number,
	offlinePerRank: number,
	continuumOffline: number,
	forgePath: number
): number
	return math.min(
		1,
		(tonumber(baseEfficiency) or 0)
			+ math.max(0, tonumber(researchOffline) or 0) * 0.06
			+ (tonumber(grid) or 0)
			+ (tonumber(echo) or 0)
			+ (tonumber(artifact) or 0)
			+ (tonumber(item) or 0)
			+ (tonumber(anomaly) or 0)
			+ (tonumber(guild) or 0)
			+ math.max(0, tonumber(domainRank) or 0) * (tonumber(offlinePerRank) or 0)
			+ (tonumber(continuumOffline) or 0)
			+ (tonumber(forgePath) or 0)
	)
end

-- Machine mastery → production multiplier. Soft-caps at +50%.
function EconomyEnvelopeMath.MasteryMultiplier(machineMastery: any): number
	if type(machineMastery) ~= "table" then
		return 1
	end
	local points = 0
	for _, value in machineMastery do
		if type(value) == "number" then
			points += value
		end
	end
	return 1 + math.min(0.5, points * 0.002)
end

-- Domain tree node bonuses for a field (Production / Capacity / …).
-- `nodes` is profile.Domain.Nodes; `tree` is GameConfig.Domain.Tree.
function EconomyEnvelopeMath.DomainTreeBonus(nodes: any, tree: any, field: string): number
	if type(nodes) ~= "table" or type(tree) ~= "table" then
		return 0
	end
	local total = 0
	for _, node in tree do
		if type(node) == "table" and nodes[node.Id] == true then
			local amount = node[field]
			if type(amount) == "number" then
				total += amount
			end
		end
	end
	return total
end

-- Lab power channel bonus: routing cells × EffectPerCell. Missing channel → 0.
function EconomyEnvelopeMath.LabPowerEffect(routing: any, channelId: any, channel: any): number
	if type(routing) ~= "table" or type(channel) ~= "table" or type(channelId) ~= "string" then
		return 0
	end
	local perCell = tonumber(channel.EffectPerCell) or 0
	local cells = tonumber(routing[channelId]) or 0
	return math.max(0, cells) * perCell
end

-- Relic / item effect at level: BaseEffect * (1 + LevelGrowth * max(0, level-1)).
-- Matches InventoryMath.EffectAtLevel — keep formulas in lockstep via verify.
function EconomyEnvelopeMath.EffectAtLevel(definition: any, level: any): number
	if type(definition) ~= "table" then
		return 0
	end
	local base = tonumber(definition.BaseEffect) or 0
	local growth = tonumber(definition.LevelGrowth) or 0
	local safeLevel = if type(level) == "number" then level else 1
	return base * (1 + growth * math.max(0, safeLevel - 1))
end

-- Artifact effect: EffectPerLevel * owned.Level when kinds match.
function EconomyEnvelopeMath.ArtifactLevelEffect(artifact: any, owned: any, effectKind: any): number
	if type(artifact) ~= "table" or type(owned) ~= "table" then
		return 0
	end
	if artifact.EffectKind ~= effectKind then
		return 0
	end
	local perLevel = tonumber(artifact.EffectPerLevel) or 0
	local level = tonumber(owned.Level) or 0
	return perLevel * math.max(0, level)
end

-- Grid upgrade bag → effect total for `effectKind`. `gridById` maps id → upgrade.
function EconomyEnvelopeMath.GridEffect(levels: any, gridById: any, effectKind: any): number
	if type(levels) ~= "table" or type(gridById) ~= "table" then
		return 0
	end
	local total = 0
	for id, level in levels do
		if type(level) == "number" and level > 0 then
			local upgrade = gridById[id]
			if type(upgrade) == "table" and upgrade.EffectKind == effectKind then
				local per = tonumber(upgrade.EffectPerLevel) or 0
				total += level * per
			end
		end
	end
	return total
end


-- Permanent production multiplier parts (cores ^ exp, domain rank/essence, rebirths).
-- Domain-tree / ForgePath / Insight addends are injected so Economy stays the
-- catalog owner while the arithmetic stays Lune-testable.
function EconomyEnvelopeMath.PermanentMultiplier(
	cores: any,
	coreMultiplier: any,
	coreExponent: any,
	rank: any,
	essence: any,
	essenceCap: any,
	productionPerRank: any,
	productionPerEssence: any,
	domainTreeBonus: any,
	forgePathProduction: any,
	rebirths: any,
	rebirthMultiplier: any,
	forgePathRebirth: any,
	insightLevel: any
): number
	local safeCores = math.max(0, tonumber(cores) or 0)
	local coreBonus = (tonumber(coreMultiplier) or 0) * (safeCores ^ (tonumber(coreExponent) or 0))
	local safeRank = math.max(0, tonumber(rank) or 0)
	local safeEssence = math.max(0, tonumber(essence) or 0)
	local cap = tonumber(essenceCap) or 1_000_000
	if safeEssence > cap then
		safeEssence = cap
	end
	local safeRebirths = math.max(0, tonumber(rebirths) or 0)
	local domainMultiplier = 1
		+ safeRank * (tonumber(productionPerRank) or 0)
		+ safeEssence * (tonumber(productionPerEssence) or 0)
		+ (tonumber(domainTreeBonus) or 0)
		+ (tonumber(forgePathProduction) or 0)
	local rebirthScale = (tonumber(rebirthMultiplier) or 0)
		* (1 + (tonumber(forgePathRebirth) or 0))
		* (1 + math.max(0, tonumber(insightLevel) or 0) * 0.02)
	return (1 + coreBonus + safeRebirths * rebirthScale) * domainMultiplier
end

-- Sum equipped relic effects for `effectKind`. `getDefinition(id)` resolves catalogs;
-- Machines/Research owned levels gate socket eligibility. Partial Items bags → 0.
function EconomyEnvelopeMath.ItemEffect(
	items: any,
	machines: any,
	research: any,
	effectKind: any,
	getDefinition: ((any) -> any)?,
	slotFilter: any?,
	targetFilter: any?
): number
	if type(items) ~= "table" or type(effectKind) ~= "string" then
		return 0
	end
	local equipped = items.Equipped
	local inventory = items.Inventory
	if type(equipped) ~= "table" or type(inventory) ~= "table" then
		return 0
	end
	local resolve = getDefinition
	if type(resolve) ~= "function" then
		return 0
	end
	local total = 0
	for target, uid in equipped do
		local instance = inventory[uid]
		local definition = instance and resolve(instance.DefinitionId)
		local slot, targetId = string.match(tostring(target), "^(%a+):([%w_]+)$")
		local ownedLevel = if slot == "Machine" and type(machines) == "table"
			then machines[targetId]
			elseif slot == "Research" and type(research) == "table"
			then research[targetId]
			else nil
		if
			type(definition) == "table"
			and type(ownedLevel) == "number"
			and ownedLevel > 0
			and definition.EffectKind == effectKind
			and (not slotFilter or slot == slotFilter)
			and (not targetFilter or target == targetFilter)
		then
			total += EconomyEnvelopeMath.EffectAtLevel(definition, instance.Level)
		end
	end
	return total
end

return table.freeze(EconomyEnvelopeMath)
end

-- ======================================================================
-- Module: ForgePathClaim   (merged from ForgePathClaim.luau, 84 lines)
-- ======================================================================
__defs["ForgePathClaim"] = function()
-- Pure forge-path claim gate + XP consume. No Roblox services — ProgressionService
-- and Lune verify scripts share this so step ordering / XP math can be tested
-- without Studio. Reward application stays in ProgressionService.ApplyReward.

local ForgePathClaim = {}

type ForgePathBag = {
	XP: number,
	ClaimedSteps: { [string]: boolean },
}

type StepLike = {
	XPCost: number,
	Reward: any?,
}

function ForgePathClaim.Ensure(forgePath): ForgePathBag
	if type(forgePath) ~= "table" then
		return { ClaimedSteps = {}, XP = 0, XPDay = -1, XPEarnedToday = 0 } :: any
	end
	if type(forgePath.ClaimedSteps) ~= "table" then
		forgePath.ClaimedSteps = {}
	end
	forgePath.XP = math.max(0, math.floor(tonumber(forgePath.XP) or 0))
	forgePath.XPDay = math.floor(tonumber(forgePath.XPDay) or -1)
	forgePath.XPEarnedToday = math.max(0, math.floor(tonumber(forgePath.XPEarnedToday) or 0))
	return forgePath
end

-- Mutates forgePath on success (deducts XP, marks ClaimedSteps).
-- Returns ok, errOrNil, stepOrNil — step is returned so callers can ApplyReward.
function ForgePathClaim.TryClaim(forgePath, rawStep: any, steps: { StepLike }): (boolean, string?, StepLike?)
	ForgePathClaim.Ensure(forgePath)
	if type(rawStep) ~= "number" then
		return false, "Invalid forge path step.", nil
	end
	local stepIndex = math.floor(rawStep)
	local step = steps[stepIndex]
	if not step then
		return false, "That forge path step doesn't exist.", nil
	end
	local key = tostring(stepIndex)
	if forgePath.ClaimedSteps[key] then
		return false, "That step was already claimed.", nil
	end
	if stepIndex > 1 and not forgePath.ClaimedSteps[tostring(stepIndex - 1)] then
		return false, "Claim the previous step first.", nil
	end
	if forgePath.XP < step.XPCost then
		return false, "Not enough forge XP for that step.", nil
	end
	forgePath.XP -= step.XPCost
	forgePath.ClaimedSteps[key] = true
	return true, nil, step
end

-- Sums EffectAmount (whole-number percent, e.g. 2 = "+2%") across claimed steps
-- whose EffectKind matches, returning a 0..N fraction for `1 + result` multipliers.
-- Partial ClaimedSteps / missing steps must not throw (corrupt save / mid-ensure).
function ForgePathClaim.Effect(claimedSteps: any, steps: any, effectKind: string): number
	if type(claimedSteps) ~= "table" or type(steps) ~= "table" then
		return 0
	end
	local total = 0
	for stepKey in claimedSteps do
		local stepIndex = tonumber(stepKey)
		local step = stepIndex and steps[stepIndex]
		if type(step) == "table" and step.EffectKind == effectKind then
			total += tonumber(step.EffectAmount) or 0
		end
	end
	return total / 100
end

-- Forge-path XP awarded when banking flux. Injected xpConfig from GameConfig.
function ForgePathClaim.XpFromBankedAmount(amountNumber: number, xpConfig: any): number
	local scale = tonumber(xpConfig and xpConfig.LogScale) or 4
	local minimum = tonumber(xpConfig and xpConfig.Minimum) or 1
	local safeAmount = math.max(0, tonumber(amountNumber) or 0)
	return math.max(minimum, math.floor(math.log(safeAmount + 1) / math.log(10) * scale))
end

return table.freeze(ForgePathClaim)
end

-- ======================================================================
-- Module: OfflineProjection   (merged from OfflineProjection.luau, 106 lines)
-- ======================================================================
__defs["OfflineProjection"] = function()
-- Pure offline earnings segment projection. No Roblox services — Economy and
-- Lune verify scripts share this so elapsed/cap/boundary math can be tested
-- without Studio. Production/efficiency sampling stays injected by the caller.

local OfflineProjection = {}

type SampleResult = {
	Production: any,
	Efficiency: number,
}

-- sampleAt(midpointSeconds) -> SampleResult
-- add(left, right) / mul(left, right) match Economy.Add / Economy.Mul
-- persist(value) matches Economy bounded Persist (optional; identity if nil)
function OfflineProjection.Project(
	startedAt: number,
	endedAt: number,
	maxSeconds: number,
	minElapsed: number,
	cycleSeconds: number,
	boostEnd: number,
	surgeEnd: number,
	sampleAt: (number) -> SampleResult,
	add: (any, any) -> any,
	mul: (any, any) -> any,
	persist: ((any) -> any)?
): (any, number, number, boolean)
	local rawElapsed = math.max(0, endedAt - startedAt)
	local maximum = math.max(0, maxSeconds)
	local elapsed = math.min(rawElapsed, maximum)
	local capped = rawElapsed > maximum
	if elapsed < minElapsed then
		return 0, elapsed, 0, capped
	end

	local from = startedAt
	local to = startedAt + elapsed
	local boundaries = { from, to }
	local cycle = math.max(1, cycleSeconds)
	local nextCycle = (math.floor(from / cycle) + 1) * cycle
	while nextCycle < to do
		table.insert(boundaries, nextCycle)
		nextCycle += cycle
	end
	if boostEnd > from and boostEnd < to then
		table.insert(boundaries, boostEnd)
	end
	if surgeEnd > from and surgeEnd < to then
		table.insert(boundaries, surgeEnd)
	end
	table.sort(boundaries)

	local reward: any = 0
	local weightedEfficiency = 0
	for index = 1, #boundaries - 1 do
		local left = boundaries[index]
		local right = boundaries[index + 1]
		local duration = right - left
		if duration > 0 then
			local sample = left + duration * 0.5
			local result = sampleAt(sample)
			local efficiency = result.Efficiency
			reward = add(reward, mul(result.Production, efficiency * duration))
			weightedEfficiency += efficiency * duration
		end
	end
	if persist then
		reward = persist(reward)
	end
	return reward, elapsed, weightedEfficiency / elapsed, capped
end

-- Client Offline rail bag. Runtime fields optional when session cold.
function OfflineProjection.PublicSnapshot(args: {
	runtime: any?,
	production: any,
	vault: any,
	offlineHours: number,
}): any
	local runtime = args.runtime
	if runtime then
		return {
			Reward = runtime.OfflineReward,
			Seconds = runtime.OfflineSeconds,
			Efficiency = runtime.OfflineEfficiency,
			Capped = runtime.OfflineCapped,
			Production = args.production,
			AwaySeconds = runtime.OfflineAwaySeconds or runtime.OfflineSeconds,
			CapHours = runtime.OfflineCapHours or args.offlineHours,
			Vault = args.vault,
		}
	end
	return {
		Reward = 0,
		Seconds = 0,
		Efficiency = 0,
		Capped = false,
		Production = args.production,
		AwaySeconds = 0,
		CapHours = args.offlineHours,
		Vault = args.vault,
	}
end

return table.freeze(OfflineProjection)
end

-- ======================================================================
-- Module: RebirthGate   (merged from RebirthGate.luau, 61 lines)
-- ======================================================================
__defs["RebirthGate"] = function()
-- Pure rebirth eligibility / requirement / prestige-reward math. No Roblox
-- services — Economy, ServerServices, and Lune verify scripts share this so
-- rebirth gates can be tested without Studio. Profile mutation stays with callers.

local RebirthGate = {}

-- True when the player has enough rebirths for a gate (upgrade / zone / domain).
function RebirthGate.MeetsRequired(rebirths: number, required: number?): boolean
	local have = math.max(0, math.floor(tonumber(rebirths) or 0))
	local need = math.max(0, math.floor(tonumber(required) or 0))
	return have >= need
end

function RebirthGate.RequirementMessage(required: number): string
	local need = math.max(0, math.floor(tonumber(required) or 0))
	return string.format("Requires %d rebirths.", need)
end

-- Prestige core reward from run flux. Mirrors Economy.PrestigeReward exactly:
-- below requirement → 0; otherwise max(1, floor((run/req)^exponent)).
function RebirthGate.PrestigeReward(
	omegaMath,
	runCash: any,
	requirement: number,
	exponent: number,
	lt: (any, any) -> boolean
): any
	if lt(runCash, requirement) then
		return 0
	end
	local ratio = omegaMath.Div(runCash, requirement)
	return omegaMath.Max(1, omegaMath.Floor(omegaMath.Pow(ratio, exponent)))
end

-- Rebirth action is allowed when prestige reward is at least 1 core.
function RebirthGate.CanRebirth(prestigeReward: any, gte: (any, any) -> boolean): boolean
	return gte(prestigeReward, 1)
end

-- Stardust granted on a successful rebirth (sqrt of cores * scale, floored).
function RebirthGate.StardustReward(coreReward: number, scale: number, minimum: number): number
	local reward = math.max(0, tonumber(coreReward) or 0)
	local stardustScale = tonumber(scale) or 5
	local stardustMinimum = tonumber(minimum) or 4
	return math.max(stardustMinimum, math.floor(math.sqrt(reward) * stardustScale))
end

-- Run-cash target for the next prestige core after currentReward.
-- Mirrors Economy.NextPrestigeTarget: floor(req * (max(1, reward+1))^(1/exp)).
function RebirthGate.NextPrestigeTarget(
	omegaMath: any,
	currentReward: any,
	requirement: number,
	exponent: number
): any
	local desired = omegaMath.Max(1, omegaMath.Add(currentReward, 1))
	return omegaMath.Floor(omegaMath.Mul(requirement, omegaMath.Pow(desired, 1 / exponent)))
end

return table.freeze(RebirthGate)
end

-- ======================================================================
-- Module: TapCritProjection   (merged from TapCritProjection.luau, 79 lines)
-- ======================================================================
__defs["TapCritProjection"] = function()
-- Pure tap power + critical chance/multiplier projection. No Roblox services —
-- Economy and Lune verify scripts share this so tap/crit math can be tested
-- without Studio. Effect totals (grid/echo/artifact/…) are injected by the caller.

local TapCritProjection = {}

type TapBonuses = {
	Grid: number,
	Echo: number,
	Artifact: number,
	Item: number,
	Anomaly: number,
	Lab: number,
	Guild: number,
	-- Continuum tap scale is already a multiplier (not 1+x).
	Continuum: any,
	ForgePath: number,
	-- Foundry ore upgrades (optional; absent means +0%).
	Ore: number?,
}

-- Mirrors Economy.TapPower composition: max(1, production*0.15) then
-- Overcharge / effect / continuum / forge-path multipliers. Balance constants
-- (0.15 base share, 0.35 per Overcharge level) stay here intentionally.
function TapCritProjection.TapPower(omegaMath, production: any, overchargeLevel: number, bonuses: TapBonuses): any
	local tap = omegaMath.Max(1, omegaMath.Mul(production, 0.15))
	tap = omegaMath.Mul(tap, 1 + overchargeLevel * 0.35)
	tap = omegaMath.Mul(tap, 1 + bonuses.Grid)
	tap = omegaMath.Mul(tap, 1 + bonuses.Echo)
	tap = omegaMath.Mul(tap, 1 + bonuses.Artifact)
	tap = omegaMath.Mul(tap, 1 + bonuses.Item)
	tap = omegaMath.Mul(tap, 1 + bonuses.Anomaly)
	tap = omegaMath.Mul(tap, 1 + bonuses.Lab)
	tap = omegaMath.Mul(tap, 1 + bonuses.Guild)
	tap = omegaMath.Mul(tap, bonuses.Continuum)
	tap = omegaMath.Mul(tap, 1 + bonuses.ForgePath)
	-- Foundry ore upgrades. Optional so older callers (and tests) that predate
	-- the Foundry still add nothing.
	tap = omegaMath.Mul(tap, 1 + (bonuses.Ore or 0))
	return tap
end

-- Soft-capped critical chance. researchCritical is Research.Critical level.
function TapCritProjection.CriticalChance(
	researchCritical: number,
	grid: number,
	echo: number,
	artifact: number,
	item: number,
	anomaly: number,
	forgePath: number
): number
	return math.min(
		0.75,
		0.05
			+ researchCritical * 0.012
			+ grid
			+ echo
			+ artifact
			+ item
			+ anomaly
			+ forgePath
	)
end

-- Critical payout multiplier. Impact research + forge-path CriticalMultiplier.
function TapCritProjection.CriticalMultiplier(
	researchCritical: number,
	researchImpact: number,
	forgePath: number
): number
	return 2
		+ math.floor(researchCritical / 5) * 0.5
		+ researchImpact * 0.1
		+ forgePath
end

return table.freeze(TapCritProjection)
end

-- ======================================================================
-- Module: UpgradeCostReason   (merged from UpgradeCostReason.luau, 80 lines)
-- ======================================================================
__defs["UpgradeCostReason"] = function()
-- Pure upgrade lock-reason + geometric cost helpers. No Roblox services —
-- ProgressionGate / Economy and Lune verify scripts share this so buy-gate
-- and cost math can be tested without Studio.

local UpgradeCostReason = {}

type UpgradeLike = {
	RequiredZone: number?,
	RequiredRebirths: number?,
	PreviousId: string?,
	PreviousLevel: number?,
	BaseCost: number?,
	CostScale: number?,
}

type CostDef = {
	BaseCost: number,
	CostScale: number,
}

function UpgradeCostReason.LevelCost(omegaMath, def: CostDef?, currentLevel: number): any
	if not def then
		return math.huge
	end
	return omegaMath.ScaledCost(def.BaseCost, def.CostScale, currentLevel)
end

function UpgradeCostReason.BulkCost(omegaMath, def: CostDef?, currentLevel: number, count: number): any
	if not def then
		return math.huge
	end
	return omegaMath.GeometricSum(def.BaseCost, def.CostScale, currentLevel, count)
end

function UpgradeCostReason.AffordableLevels(
	omegaMath,
	def: CostDef?,
	currentLevel: number,
	currency: any,
	maximum: number
): (number, any)
	if not def then
		return 0, 0
	end
	return omegaMath.AffordableCount(def.BaseCost, def.CostScale, currentLevel, currency, maximum)
end

-- zoneNameForIndex(requiredZone) -> string?
-- previousNameForId(previousId) -> string?
function UpgradeCostReason.Evaluate(
	profile,
	upgrade: UpgradeLike,
	levels,
	zoneNameForIndex: (number) -> string?,
	previousNameForId: (string) -> string?
): string?
	local requiredZone = upgrade.RequiredZone or 1
	local zoneOwned = math.max(0, math.floor(tonumber(profile.Zone) or 0))
	if zoneOwned < requiredZone then
		local zoneName = zoneNameForIndex(requiredZone)
		return "Reach " .. (zoneName or ("World " .. tostring(requiredZone)))
	end
	local requiredRebirths = upgrade.RequiredRebirths or 0
	local rebirths = math.max(0, math.floor(tonumber(profile.Rebirths) or 0))
	if rebirths < requiredRebirths then
		return string.format("Complete %d rebirth%s", requiredRebirths, requiredRebirths == 1 and "" or "s")
	end
	if upgrade.PreviousId and (levels[upgrade.PreviousId] or 0) < (upgrade.PreviousLevel or 1) then
		local previousName = previousNameForId(upgrade.PreviousId)
		return string.format(
			"Raise %s to level %d",
			previousName or upgrade.PreviousId,
			upgrade.PreviousLevel or 1
		)
	end
	return nil
end

return table.freeze(UpgradeCostReason)
end

-- ======================================================================
-- Module: ContinuumDomainMath   (merged from ContinuumDomainMath.luau, 211 lines)
-- ======================================================================
__defs["ContinuumDomainMath"] = function()
-- Pure Continuum cost + Domain requirement/reward envelopes. No Roblox
-- services — Economy and Lune verify_runquick_pure share this so endless
-- economy soak subsets can run offline. Profile mutation stays with callers;
-- omegaMath + config knobs are injected.

local ContinuumDomainMath = {}

local MAX_VALUE = 1e308

type ContinuumConfig = {
	BaseFluxCost: number,
	FluxCostScale: number,
	BaseStardustCost: number,
	StardustCostScale: number,
}

type ContinuumEffectsConfig = {
	ProductionScale: number,
	MilestoneEvery: number,
	MilestoneScale: number,
	CapacityScale: number,
	TapScale: number,
	OfflineCap: number,
	OfflinePerRank: number,
}

type DomainConfig = {
	BaseRequiredRebirths: number,
	RebirthsPerRank: number,
	BaseRequiredCores: number,
	CoreRequirementScale: number,
	BaseEssenceReward: number,
	EssencePerRank: number,
	BaseStardustReward: number,
	StardustPerRank: number,
}

function ContinuumDomainMath.ContinuumCosts(omegaMath: any, config: ContinuumConfig, rank: number): (any, any)
	local safeRank = math.max(0, math.floor(tonumber(rank) or 0))
	local flux = omegaMath.Floor(omegaMath.Mul(config.BaseFluxCost, omegaMath.BoundedPower(config.FluxCostScale, safeRank)))
	local stardust = omegaMath.Floor(omegaMath.Mul(config.BaseStardustCost, omegaMath.BoundedPower(config.StardustCostScale, safeRank)))
	return flux, stardust
end

function ContinuumDomainMath.DomainRequirements(omegaMath: any, config: DomainConfig, rank: number): (number, number)
	local safeRank = math.max(0, math.floor(tonumber(rank) or 0))
	local rebirths = math.floor(math.min(
		MAX_VALUE,
		config.BaseRequiredRebirths + safeRank * config.RebirthsPerRank
	))
	local cores = omegaMath.ScaledCost(config.BaseRequiredCores, config.CoreRequirementScale, safeRank)
	return rebirths, omegaMath.ToNumber(cores)
end

function ContinuumDomainMath.DomainRewards(config: DomainConfig, rank: number): (number, number)
	local safeRank = math.max(0, math.floor(tonumber(rank) or 0))
	local essence = math.floor(math.min(
		MAX_VALUE,
		config.BaseEssenceReward + safeRank * config.EssencePerRank
	))
	local stardust = math.floor(math.min(
		MAX_VALUE,
		config.BaseStardustReward + safeRank * config.StardustPerRank
	))
	return essence, stardust
end

-- Rank → production/capacity/tap multipliers + offline efficiency addend.
-- Mirrors Economy.ContinuumEffects; milestones multiply production only.
function ContinuumDomainMath.ContinuumEffects(
	omegaMath: any,
	config: ContinuumEffectsConfig,
	rank: number
): (any, any, any, number)
	local safeRank = math.max(0, math.floor(tonumber(rank) or 0))
	local every = math.max(1, math.floor(tonumber(config.MilestoneEvery) or 1))
	local milestones = math.floor(safeRank / every)
	local milestoneMultiplier = omegaMath.BoundedPower(config.MilestoneScale, milestones)
	local production = omegaMath.Mul(omegaMath.BoundedPower(config.ProductionScale, safeRank), milestoneMultiplier)
	local capacity = omegaMath.BoundedPower(config.CapacityScale, safeRank)
	local tap = omegaMath.BoundedPower(config.TapScale, safeRank)
	local offline = math.min(config.OfflineCap, safeRank * config.OfflinePerRank)
	return production, capacity, tap, offline
end


function ContinuumDomainMath.DomainProductionMultiplier(rank: any, essence: any, productionPerRank: any, productionPerEssence: any, essenceCap: any, domainTreeBonus: any): number
	local safeRank = math.max(0, math.floor(tonumber(rank) or 0))
	local safeEssence = math.max(0, tonumber(essence) or 0)
	local cap = tonumber(essenceCap) or 1_000_000
	if safeEssence > cap then
		safeEssence = cap
	end
	return 1 + safeRank * (tonumber(productionPerRank) or 0) + safeEssence * (tonumber(productionPerEssence) or 0) + (tonumber(domainTreeBonus) or 0)
end

function ContinuumDomainMath.DomainRankBonus(rank: any, perRank: any, domainTreeBonus: any): number
	local safeRank = math.max(0, math.floor(tonumber(rank) or 0))
	return safeRank * (tonumber(perRank) or 0) + (tonumber(domainTreeBonus) or 0)
end

-- Non-negative integer coerce for Domain/Continuum snapshot bags (string fixtures).
function ContinuumDomainMath.NonNegativeInt(value: any): number
	return math.max(0, math.floor(tonumber(value) or 0))
end

-- Snapshot Domain bag fields that must stay numeric for client UI rails.
function ContinuumDomainMath.SnapshotDomainInts(domain: any): {
	Essence: number,
	LastExpandedAt: number,
	TotalRebirthsSpent: number,
	TotalCoresSpent: number,
	SkillPoints: number,
}
	local bag = if type(domain) == "table" then domain else {}
	return {
		Essence = ContinuumDomainMath.NonNegativeInt(bag.Essence),
		LastExpandedAt = ContinuumDomainMath.NonNegativeInt(bag.LastExpandedAt),
		TotalRebirthsSpent = ContinuumDomainMath.NonNegativeInt(bag.TotalRebirthsSpent),
		TotalCoresSpent = ContinuumDomainMath.NonNegativeInt(bag.TotalCoresSpent),
		SkillPoints = ContinuumDomainMath.NonNegativeInt(bag.SkillPoints),
	}
end

-- Full Domain snapshot bag for client rails. Injects gate/economy helpers.
function ContinuumDomainMath.SnapshotDomainPublic(args: {
	domain: any,
	rank: number,
	requiredRebirths: number,
	requiredCores: number,
	essenceReward: number,
	stardustReward: number,
	rebirths: number,
	cores: any,
	domainConfig: any,
	MeetsRequired: (number, number) -> boolean,
	Gte: (any, any) -> boolean,
	DomainTreeBonus: (string) -> number,
}): any
	local ints = ContinuumDomainMath.SnapshotDomainInts(args.domain)
	local bag = if type(args.domain) == "table" then args.domain else {}
	local config = args.domainConfig or {}
	return {
		Rank = args.rank,
		Essence = ints.Essence,
		LastExpandedAt = ints.LastExpandedAt,
		TotalRebirthsSpent = ints.TotalRebirthsSpent,
		TotalCoresSpent = ints.TotalCoresSpent,
		RequiredRebirths = args.requiredRebirths,
		RequiredCores = args.requiredCores,
		CanExpand = args.MeetsRequired(args.rebirths, args.requiredRebirths) and args.Gte(args.cores, args.requiredCores),
		EssenceReward = args.essenceReward,
		StardustReward = args.stardustReward,
		ProductionMultiplier = ContinuumDomainMath.DomainProductionMultiplier(
			args.rank,
			bag.Essence,
			config.ProductionPerRank,
			config.ProductionPerEssence,
			1_000_000,
			args.DomainTreeBonus("Production")
		),
		CapacityMultiplier = 1 + ContinuumDomainMath.DomainRankBonus(
			args.rank,
			config.CapacityPerRank,
			args.DomainTreeBonus("Capacity")
		),
		OfflineBonus = ContinuumDomainMath.DomainRankBonus(
			args.rank,
			config.OfflineEfficiencyPerRank,
			args.DomainTreeBonus("Offline")
		),
		SkillPoints = ints.SkillPoints,
		Nodes = type(bag.Nodes) == "table" and bag.Nodes or {},
	}
end

-- Full Continuum snapshot bag for client rails.
function ContinuumDomainMath.SnapshotContinuumPublic(args: {
	rank: number,
	totalFluxSpent: any,
	totalStardustSpent: any,
	fluxCost: any,
	stardustCost: any,
	cash: any,
	stardust: any,
	production: any,
	capacity: any,
	tap: any,
	offline: any,
	milestoneEvery: number,
	Gte: (any, any) -> boolean,
}): any
	local every = math.max(1, math.floor(tonumber(args.milestoneEvery) or 1))
	local safeRank = math.max(0, math.floor(tonumber(args.rank) or 0))
	return {
		Rank = args.rank,
		TotalFluxSpent = args.totalFluxSpent,
		TotalStardustSpent = math.max(0, tonumber(args.totalStardustSpent) or 0),
		FluxCost = args.fluxCost,
		StardustCost = args.stardustCost,
		CanUpgrade = args.Gte(args.cash, args.fluxCost) and args.Gte(args.stardust, args.stardustCost),
		ProductionMultiplier = args.production,
		CapacityMultiplier = args.capacity,
		TapMultiplier = args.tap,
		OfflineBonus = args.offline,
		NextMilestone = (math.floor(safeRank / every) + 1) * every,
	}
end

return table.freeze(ContinuumDomainMath)
end

-- ======================================================================
-- Module: AnomalyOpsMath   (merged from AnomalyOpsMath.luau, 269 lines)
-- ======================================================================
__defs["AnomalyOpsMath"] = function()
-- Pure anomaly protocol / charge-target / directive / core-XP helpers. No Roblox
-- services — AnomalyService and Lune verify scripts share FindProtocol /
-- ProtocolEffect / ChargeTarget / SelectDirectives / ProtocolCost /
-- RewardMultiplier / ApplyCoreXP / NextCoreTier so reactor math stays testable
-- without Studio. Clocks and profile mutation stay with the caller; balance
-- tables are injected (GameConfig values).

local AnomalyOpsMath = {}

type ProtocolLike = {
	Id: string,
	EffectKind: string?,
	EffectPerLevel: number?,
	BaseCost: number?,
	CostScale: number?,
}

type DirectiveDefinition = {
	Id: string,
	TargetMin: number,
	TargetMax: number,
}

type CoreTierLike = {
	Tier: number,
	MaximumTargetBonus: number?,
}

-- Locate a protocol definition by Id. Partial / empty lists return nil.
function AnomalyOpsMath.FindProtocol(list: any, protocolId: any): any?
	if type(list) ~= "table" or type(protocolId) ~= "string" then
		return nil
	end
	for _, protocol in list do
		if type(protocol) == "table" and protocol.Id == protocolId then
			return protocol
		end
	end
	return nil
end

-- Sum EffectPerLevel * owned level for protocols matching effectKind.
-- Missing Protocols bag or nil levels → 0 (Studio fixtures / mid-migrate).
function AnomalyOpsMath.ProtocolEffect(protocolsBag: any, protocolDefs: any, effectKind: string): number
	if type(protocolDefs) ~= "table" or type(effectKind) ~= "string" then
		return 0
	end
	local levels = if type(protocolsBag) == "table" then protocolsBag else nil
	local total = 0
	for _, protocol in protocolDefs do
		if type(protocol) == "table" and protocol.EffectKind == effectKind then
			local level = 0
			if levels ~= nil then
				level = math.max(0, math.floor(tonumber(levels[protocol.Id]) or 0))
			end
			total += level * (tonumber(protocol.EffectPerLevel) or 0)
		end
	end
	return total
end

-- Highest MaximumTargetBonus among CoreTiers with Tier <= currentTier.
function AnomalyOpsMath.CoreTierMaximumBonus(coreTier: any, tierConfigs: any): number
	local tier = math.max(0, math.floor(tonumber(coreTier) or 0))
	if type(tierConfigs) ~= "table" then
		return 0
	end
	local bonus = 0
	for _, tierConfig in tierConfigs do
		if type(tierConfig) == "table" then
			local configTier = math.max(0, math.floor(tonumber(tierConfig.Tier) or 0))
			if configTier <= tier then
				bonus = tonumber(tierConfig.MaximumTargetBonus) or 0
			end
		end
	end
	return bonus
end

-- Charge target before stabilize: clamp base + stab*perStab to max+tierBonus.
function AnomalyOpsMath.ChargeTarget(
	baseTarget: number,
	targetPerStabilization: number,
	maximumTarget: number,
	stabilizations: any,
	tierBonus: number
): number
	local stabs = math.max(0, math.floor(tonumber(stabilizations) or 0))
	local base = math.max(0, tonumber(baseTarget) or 0)
	local per = math.max(0, tonumber(targetPerStabilization) or 0)
	local maxCap = math.max(0, tonumber(maximumTarget) or 0) + math.max(0, tonumber(tierBonus) or 0)
	return math.min(maxCap, base + stabs * per)
end

-- Upgrade cost for the next protocol level (current level → level+1).
function AnomalyOpsMath.ProtocolCost(protocol: ProtocolLike, level: any): number
	local safeLevel = math.max(0, math.floor(tonumber(level) or 0))
	local base = math.max(0, tonumber(protocol and protocol.BaseCost) or 0)
	local scale = math.max(1, tonumber(protocol and protocol.CostScale) or 1)
	return math.max(1, math.floor(base * scale ^ safeLevel + 0.5))
end

-- Pick DirectiveSlots definitions for a cycle with difficulty-scaled targets.
function AnomalyOpsMath.SelectDirectives(cycle: any, definitions: any, slots: any): { any }
	local selected = {}
	if type(definitions) ~= "table" then
		return selected
	end
	local count = #definitions
	if count <= 0 then
		return selected
	end
	local safeCycle = math.max(0, math.floor(tonumber(cycle) or 0))
	local slotCount = math.max(0, math.floor(tonumber(slots) or 0))
	local start = safeCycle % count
	for slot = 1, slotCount do
		local index = (start + (slot - 1) * 3) % count + 1
		local definition = definitions[index]
		if type(definition) == "table" then
			local difficulty = ((safeCycle * 7 + slot * 13) % 5) / 4
			local targetMin = tonumber(definition.TargetMin) or 1
			local targetMax = tonumber(definition.TargetMax) or targetMin
			local target = math.floor(targetMin + (targetMax - targetMin) * difficulty + 0.5)
			selected[slot] = {
				Definition = definition,
				Target = math.max(1, target),
			}
		end
	end
	return selected
end

-- Stabilize yield multiplier: anomaly.RewardMultiplier * (1+protocolReward) * channel.
function AnomalyOpsMath.RewardMultiplier(
	anomalyRewardMultiplier: any,
	protocolRewardEffect: number,
	channelRewardAmount: number?
): number
	local base = math.max(0, tonumber(anomalyRewardMultiplier) or 1)
	local protocol = 1 + math.max(0, tonumber(protocolRewardEffect) or 0)
	local channel = 1 + math.max(0, tonumber(channelRewardAmount) or 0)
	return base * protocol * channel
end

-- Bank Core XP and advance every CoreTier the bag now qualifies for.
-- Seen when string/non-number CoreXP in Studio fixtures made `(CoreXP or 0) + xp`
-- concatenate instead of add; tonumber + multi-tier walk keeps Stabilize honest.
-- Mutates anomaly in place; returns tiers gained.
function AnomalyOpsMath.ApplyCoreXP(anomaly: any, xp: any, tierConfigs: any): number
	if type(anomaly) ~= "table" then
		return 0
	end
	local add = math.max(0, tonumber(xp) or 0)
	local coreXP = math.max(0, tonumber(anomaly.CoreXP) or 0) + add
	anomaly.CoreXP = coreXP
	local currentTier = math.max(0, math.floor(tonumber(anomaly.CoreTier) or 0))
	local gained = 0
	if type(tierConfigs) == "table" then
		for _, tierConfig in tierConfigs do
			if type(tierConfig) == "table" then
				local configTier = math.max(0, math.floor(tonumber(tierConfig.Tier) or 0))
				local required = math.max(0, tonumber(tierConfig.RequiredXP) or 0)
				if configTier > currentTier and coreXP >= required then
					currentTier = configTier
					gained += 1
				end
			end
		end
	end
	if gained > 0 then
		anomaly.CoreTier = currentTier
	end
	return gained
end

-- First CoreTiers entry with Tier > currentTier (State progress rail).
function AnomalyOpsMath.NextCoreTier(coreTier: any, tierConfigs: any): any?
	local tier = math.max(0, math.floor(tonumber(coreTier) or 0))
	if type(tierConfigs) ~= "table" then
		return nil
	end
	for _, tierConfig in tierConfigs do
		if type(tierConfig) == "table" then
			local configTier = math.max(0, math.floor(tonumber(tierConfig.Tier) or 0))
			if configTier > tier then
				return tierConfig
			end
		end
	end
	return nil
end


function AnomalyOpsMath.LoadoutEffect(loadout: any, channels: any, effectKind: string): number
	if type(loadout) ~= "table" or type(channels) ~= "table" or type(effectKind) ~= "string" then
		return 0
	end
	local total = 0
	for _, channelId in loadout do
		local channel = channels[channelId]
		if type(channel) == "table" and channel.EffectKind == effectKind then
			total += tonumber(channel.EffectAmount) or 0
		end
	end
	return total
end

function AnomalyOpsMath.CycleTypeEffect(types: any, cycleSeconds: any, now: any, effectKind: string): number
	if type(types) ~= "table" or type(effectKind) ~= "string" then
		return 0
	end
	local count = #types
	if count <= 0 then
		return 0
	end
	local seconds = math.max(1, math.floor(tonumber(cycleSeconds) or 1))
	local timestamp = math.max(0, math.floor(tonumber(now) or 0))
	local cycle = math.floor(timestamp / seconds)
	local anomaly = types[cycle % count + 1]
	if type(anomaly) == "table" and anomaly.EffectKind == effectKind then
		return tonumber(anomaly.EffectAmount) or 0
	end
	return 0
end

function AnomalyOpsMath.CorePassiveProduction(coreTier: any, tierConfigs: any): number
	local tier = math.max(0, math.floor(tonumber(coreTier) or 0))
	if tier <= 0 or type(tierConfigs) ~= "table" then
		return 0
	end
	local total = 0
	for _, tierConfig in tierConfigs do
		if type(tierConfig) == "table" then
			local configTier = math.max(0, math.floor(tonumber(tierConfig.Tier) or 0))
			if configTier <= tier then
				total += tonumber(tierConfig.PassiveProduction) or 0
			end
		end
	end
	return total
end

function AnomalyOpsMath.Effect(state: any, effectKind: string, protocolDefs: any, channels: any, types: any, cycleSeconds: any, now: any, coreTiers: any): number
	if type(state) ~= "table" or type(effectKind) ~= "string" then
		return 0
	end
	local total = AnomalyOpsMath.ProtocolEffect(state.Protocols, protocolDefs, effectKind)
	total += AnomalyOpsMath.LoadoutEffect(state.Loadout, channels, effectKind)
	total += AnomalyOpsMath.CycleTypeEffect(types, cycleSeconds, now, effectKind)
	if effectKind == "Production" then
		total += AnomalyOpsMath.CorePassiveProduction(state.CoreTier, coreTiers)
	end
	return total
end

function AnomalyOpsMath.SurgeMultiplier(state: any, now: any, surgeMultiplier: any): number
	if type(state) ~= "table" then
		return 1
	end
	local endsAt = tonumber(state.SurgeEndsAt)
	local timestamp = tonumber(now) or 0
	if endsAt ~= nil and endsAt > timestamp then
		return math.max(1, tonumber(surgeMultiplier) or 1)
	end
	return 1
end

return table.freeze(AnomalyOpsMath)
end

-- ======================================================================
-- Module: ProgressionGate   (merged from ProgressionGate.luau, 122 lines)
-- ======================================================================
__defs["ProgressionGate"] = function()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = __load("Economy")
local UpgradeCostReason = __load("UpgradeCostReason")
local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
local ForgeLevels = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))("ForgeLevels")

local ProgressionGate = {}

function ProgressionGate.Progress(profile, kind: string): number
	if kind == "Always" then
		return math.huge
	elseif kind == "Level" then
		return ProgressionGate.Level(profile)
	elseif kind == "LifetimeCash" then
		return Economy.AsNumber(profile.LifetimeCash)
	elseif kind == "MachinesBought" then
		-- Lifetime machine levels bought, which (unlike MachineLevels) survives
		-- rebirth. A profile older than the counter can read low, so it never
		-- counts for less than the machine levels owned right now.
		local stats = profile.Stats
		local bought = math.max(0, math.floor(tonumber(stats and stats.MachinesBought) or 0))
		return math.max(bought, Economy.TotalMachineLevels(profile))
	elseif kind == "MachineLevels" then
		return Economy.TotalMachineLevels(profile)
	elseif kind == "ResearchLevels" then
		return Economy.TotalResearchLevels(profile)
	elseif kind == "Rebirths" then
		local current = math.max(0, math.floor(tonumber(profile.Rebirths) or 0))
		local spent = 0
		if type(profile.Domain) == "table" then
			spent = math.max(0, math.floor(tonumber(profile.Domain.TotalRebirthsSpent) or 0))
		end
		return current + spent
	elseif kind == "Domain" or kind == "DomainRank" then
		return math.max(0, tonumber(profile.Domain and profile.Domain.Rank) or 0)
	elseif kind == "Zone" then
		return math.max(0, math.floor(tonumber(profile.Zone) or 0))
	elseif kind == "PlayTime" then
		local stats = profile.Stats
		return math.max(0, math.floor(tonumber(stats and stats.PlayTime) or 0))
	elseif kind == "AnomalyStabilizations" then
		local anomaly = profile.Anomaly
		local fromAnomaly = tonumber(anomaly and anomaly.Stabilizations)
		if fromAnomaly ~= nil then
			return math.max(0, math.floor(fromAnomaly))
		end
		local stats = profile.Stats
		return math.max(0, math.floor(tonumber(stats and stats.AnomalyStabilizations) or 0))
	elseif kind == "ForgePathSteps" then
		local claimed = 0
		local forgePath = profile.ForgePath
		if type(forgePath) == "table" and type(forgePath.ClaimedSteps) == "table" then
			for _ in forgePath.ClaimedSteps do
				claimed += 1
			end
		end
		return claimed
	end
	return 0
end

function ProgressionGate.Meets(profile, requirement): boolean
	if not requirement then
		return true
	end
	return ProgressionGate.Progress(profile, requirement.Kind) >= requirement.Target
end

-- The player's Forge Level: the highest level of the ladder whose goal they
-- meet (ForgeLevels). Level goals never use the "Level" kind, so this cannot
-- recurse.
function ProgressionGate.Level(profile): number
	return ForgeLevels.levelFor(function(kind: string): number
		return ProgressionGate.Progress(profile, kind)
	end)
end

-- Level, tier and the next goal with its progress, for the state snapshot.
function ProgressionGate.LevelState(profile)
	return ForgeLevels.snapshot(function(kind: string): number
		return ProgressionGate.Progress(profile, kind)
	end)
end

function ProgressionGate.IsFeatureUnlocked(profile, featureId: string): boolean
	local rule = GameConfig.Unlocks[featureId]
	return rule == nil or ProgressionGate.Progress(profile, rule.Kind) >= rule.Target
end

function ProgressionGate.FeatureStates(profile)
	local result = {}
	-- Nearly every rule is level-gated: work the level out once, not per rule.
	local level = ProgressionGate.Level(profile)
	for id, rule in GameConfig.Unlocks do
		local progress = if rule.Kind == "Level" then level else ProgressionGate.Progress(profile, rule.Kind)
		result[id] = {
			Unlocked = progress >= rule.Target,
			Progress = progress == math.huge and rule.Target or progress,
			Target = rule.Target,
			Requirement = rule.Requirement,
			Name = rule.Name,
			-- The level that opens this feature (nil for Admin's owner rule).
			Level = if rule.Kind == "Level" then rule.Target else nil,
		}
	end
	return result
end

function ProgressionGate.UpgradeReason(profile, upgrade, levels): string?
	return UpgradeCostReason.Evaluate(profile, upgrade, levels, function(requiredZone: number): string?
		local zone = GameConfig.Zones[requiredZone]
		return zone and zone.Name
	end, function(previousId: string): string?
		local previous = Economy.GetMachine(previousId) or Economy.GetResearch(previousId)
		return previous and previous.Name
	end)
end

return table.freeze(ProgressionGate)
end

-- ======================================================================
-- Module: ProgressionOpsMath   (merged from ProgressionOpsMath.luau, 260 lines)
-- ======================================================================
__defs["ProgressionOpsMath"] = function()
-- Pure Progression ops helpers. No Roblox services — ProgressionService and
-- Lune verify scripts share WeeklyValue / CommanderReward / TitleUnlocked /
-- FindById / AchievementProgress / AdvanceQuestProgress / CanClaimQuest so
-- weekly directives, commander gifts, title gates, milestone progress, and
-- daily mission Progress/Target tonumber stay testable without Studio.
-- Command Ensure and Economy.Gte / AsNumber stay with the caller (injected).

local ProgressionOpsMath = {}

local function sumNumericLevels(bag: any): number
	if type(bag) ~= "table" then
		return 0
	end
	local total = 0
	for _, value in bag do
		if type(value) == "number" then
			total += value
		end
	end
	return total
end

type TitleLike = {
	Kind: string?,
	Target: number?,
}

-- Weekly directive progress sources. Partial Stats/Command bags (Studio fixtures
-- / mid-migrate) must return 0 instead of throwing on nil indexing.
function ProgressionOpsMath.WeeklyValue(profile: any, kind: string): number
	local stats = type(profile) == "table" and profile.Stats or nil
	if kind == "Upgrades" then
		return math.max(0, math.floor(tonumber(stats and stats.MachinesBought) or 0))
			+ math.max(0, math.floor(tonumber(stats and stats.ResearchBought) or 0))
	elseif kind == "Expeditions" then
		local command = type(profile) == "table" and profile.Command or nil
		return math.max(0, math.floor(tonumber(command and command.ExpeditionsCompleted) or 0))
	end
	if type(stats) ~= "table" then
		return 0
	end
	return math.max(0, math.floor(tonumber(stats[kind]) or 0))
end

-- Commander gift table by milestone level. ClaimCommanderReward applies this bag.
function ProgressionOpsMath.CommanderReward(level: any): { [string]: number }
	local safe = math.max(1, math.floor(tonumber(level) or 1))
	if safe % 10 == 0 then
		return { Cores = math.max(1, safe / 10), Stardust = 10 + safe, Signals = 10 + safe }
	elseif safe % 5 == 0 then
		return { Stardust = 8 + safe, Signals = 8 + math.floor(safe / 2), StreakShield = 1 }
	end
	return { CashMinutes = 5 + safe, Signals = 3 + math.floor(safe / 3) }
end

function ProgressionOpsMath.FindById(list: any, id: string): any?
	if type(list) ~= "table" or type(id) ~= "string" then
		return nil
	end
	for _, item in list do
		if type(item) == "table" and item.Id == id then
			return item
		end
	end
	return nil
end

-- Title unlock gate. `command` must already be Ensure'd; `lifetimeGte` injects
-- Economy.Gte (or a pure substitute) so this module stays Lune-safe.
function ProgressionOpsMath.TitleUnlocked(
	profile: any,
	title: TitleLike,
	command: any,
	commanderLevel: number,
	lifetimeGte: ((any, any) -> boolean)?
): boolean
	if type(title) ~= "table" or type(command) ~= "table" then
		return false
	end
	local kind = title.Kind
	local target = tonumber(title.Target) or 0
	if kind == "Level" then
		return commanderLevel >= target
	elseif kind == "Expeditions" then
		return math.max(0, math.floor(tonumber(command.ExpeditionsCompleted) or 0)) >= target
	elseif kind == "Artifacts" then
		local count = 0
		if type(command.Artifacts) == "table" then
			for _ in command.Artifacts do
				count += 1
			end
		end
		return count >= target
	elseif kind == "LifetimeCash" then
		local gte = lifetimeGte
		if type(gte) ~= "function" then
			return false
		end
		local cash = if type(profile) == "table" then profile.LifetimeCash else nil
		return gte(cash, target) == true
	elseif kind == "Rebirths" then
		local rebirths = if type(profile) == "table" then tonumber(profile.Rebirths) or 0 else 0
		return rebirths >= target
	end
	return false
end

-- Achievement Kind → current progress. `lifetimeAsNumber` injects Economy.AsNumber
-- (or a pure Omega substitute) for LifetimeCash; Machine/Research levels use
-- EconomyEnvelopeMath.SumNumericLevels so partial bags stay Lune-safe.
function ProgressionOpsMath.AchievementProgress(profile: any, kind: string, lifetimeAsNumber: ((any) -> number)?): number
	if type(profile) ~= "table" or type(kind) ~= "string" then
		return 0
	end
	if kind == "LifetimeCash" then
		local asNumber = lifetimeAsNumber
		if type(asNumber) ~= "function" then
			return 0
		end
		return math.max(0, asNumber(profile.LifetimeCash) or 0)
	elseif kind == "MachineLevels" then
		return sumNumericLevels(profile.Machines)
	elseif kind == "ResearchLevels" then
		return sumNumericLevels(profile.Research)
	elseif kind == "Rebirths" then
		-- Match ProgressionGate: Domain expand zeroes current Rebirths but keeps
		-- TotalRebirthsSpent — achievements must not regress after expansion.
		local current = math.max(0, math.floor(tonumber(profile.Rebirths) or 0))
		local spent = 0
		if type(profile.Domain) == "table" then
			spent = math.max(0, math.floor(tonumber(profile.Domain.TotalRebirthsSpent) or 0))
		end
		return current + spent
	elseif kind == "Zone" then
		return math.max(0, math.floor(tonumber(profile.Zone) or 0))
	elseif kind == "PlayTime" then
		local stats = profile.Stats
		return math.max(0, math.floor(tonumber(stats and stats.PlayTime) or 0))
	elseif kind == "AnomalyPulses" then
		local stats = profile.Stats
		return math.max(0, math.floor(tonumber(stats and stats.AnomalyPulses) or 0))
	elseif kind == "AnomalyStabilizations" then
		-- Prefer Anomaly bag (source of truth + Admin GrantAnomalyStabilizations);
		-- Stats can lag when admin grants only bump Anomaly.Stabilizations.
		local anomaly = profile.Anomaly
		local fromAnomaly = tonumber(anomaly and anomaly.Stabilizations)
		if fromAnomaly ~= nil then
			return math.max(0, math.floor(fromAnomaly))
		end
		local stats = profile.Stats
		return math.max(0, math.floor(tonumber(stats and stats.AnomalyStabilizations) or 0))
	elseif kind == "AnomalyProtocols" then
		local stats = profile.Stats
		return math.max(0, math.floor(tonumber(stats and stats.AnomalyProtocols) or 0))
	elseif kind == "ForgePathSteps" then
		local claimed = 0
		local forgePath = profile.ForgePath
		if type(forgePath) == "table" and type(forgePath.ClaimedSteps) == "table" then
			for _ in forgePath.ClaimedSteps do
				claimed += 1
			end
		end
		return claimed
	elseif kind == "DailyStreak" then
		return math.max(0, math.floor(tonumber(profile.Daily and profile.Daily.Streak) or 0))
	elseif kind == "WheelSpins" then
		return math.max(0, math.floor(tonumber(profile.Wheel and profile.Wheel.Spins) or 0))
	elseif kind == "LabOrders" then
		return math.max(0, math.floor(tonumber(profile.Stats and profile.Stats.OrdersCompleted) or 0))
	elseif kind == "Expeditions" then
		-- Prefer Command bag (ClaimExpedition source of truth); Stats can lag on partial fixtures.
		local command = profile.Command
		local fromCommand = tonumber(command and command.ExpeditionsCompleted)
		if fromCommand ~= nil then
			return math.max(0, math.floor(fromCommand))
		end
		return math.max(0, math.floor(tonumber(profile.Stats and profile.Stats.Expeditions) or 0))
	elseif kind == "DomainRank" or kind == "Domain" then
		return math.max(0, math.floor(tonumber(profile.Domain and profile.Domain.Rank) or 0))
	elseif kind == "StoryClaims" then
		local count = 0
		local claimed = profile.Story and profile.Story.Claimed
		if type(claimed) == "table" then
			for _, value in claimed do
				if value == true then
					count += 1
				end
			end
		end
		return count
	end
	return 0
end

-- Advance matching quest Progress. Studio fixtures / mid-migrate bags may store
-- Progress/Target as numeric strings — bare `progress + amount` concatenates.
-- BuyAny matches BuyMachine / BuyResearch the same way ProgressionService.Progress does.
function ProgressionOpsMath.AdvanceQuestProgress(items: any, kind: any, amount: any): number
	if type(items) ~= "table" or type(kind) ~= "string" then
		return 0
	end
	local delta = math.max(0, math.floor(tonumber(amount) or 0))
	if delta ~= delta or delta == math.huge or delta == -math.huge or delta <= 0 then
		return 0
	end
	local updated = 0
	for _, quest in items do
		if type(quest) == "table" then
			local questKind = quest.Kind
			if
				questKind == kind
				or (questKind == "BuyAny" and (kind == "BuyMachine" or kind == "BuyResearch"))
			then
				local progress = math.max(0, math.floor(tonumber(quest.Progress) or 0))
				local target = math.max(0, math.floor(tonumber(quest.Target) or 0))
				quest.Progress = math.min(target, progress + delta)
				updated += 1
			end
		end
	end
	return updated
end

-- Claim gate for a single quest bag. Returns ok, reason. Numeric-string Progress
-- / Target must not lexicographically compare (e.g. "9" < "10" is false).
function ProgressionOpsMath.CanClaimQuest(quest: any): (boolean, string)
	if type(quest) ~= "table" then
		return false, "Mission not found."
	end
	if quest.Claimed == true then
		return false, "That mission reward was already claimed."
	end
	local progress = math.max(0, math.floor(tonumber(quest.Progress) or 0))
	local target = math.max(0, math.floor(tonumber(quest.Target) or 0))
	if progress < target then
		return false, "That mission is not complete yet."
	end
	return true, ""
end

-- Scale raw command XP by a Domain-tree CommandXP bonus (fraction). Always ≥ 0.
function ProgressionOpsMath.ScaledCommandXP(amount: any, domainBonus: any): number
	local value = math.max(0, math.floor(tonumber(amount) or 0))
	local bonus = tonumber(domainBonus) or 0
	return math.floor(value * (1 + bonus))
end

-- Apply ScaledCommandXP onto an Ensure'd Command bag (XP + SeasonXP). Returns granted.
function ProgressionOpsMath.ApplyCommandXP(command: any, amount: any, domainBonus: any): number
	if type(command) ~= "table" then
		return 0
	end
	local granted = ProgressionOpsMath.ScaledCommandXP(amount, domainBonus)
	command.XP = (tonumber(command.XP) or 0) + granted
	command.SeasonXP = (tonumber(command.SeasonXP) or 0) + granted
	return granted
end

return table.freeze(ProgressionOpsMath)
end

-- ======================================================================
-- Module: WheelMath   (merged from WheelMath.luau, 134 lines)
-- ======================================================================
__defs["WheelMath"] = function()
-- Pure fortune-wheel bag ensure / readiness snapshot / pity pool helpers.
-- No Roblox services — ProgressionService and Lune verify scripts share this so
-- FreeSpins-only bags and pity floors can be tested without Studio. Random rolls
-- and ApplyReward mutation stay with the caller; reward tables are injected.

local WheelMath = {}

WheelMath.RARITY_RANK = {
	COMMON = 1,
	UNCOMMON = 2,
	RARE = 3,
	EPIC = 4,
	LEGENDARY = 5,
	MYTHIC = 6,
}

type WheelBag = {
	LastSpinAt: number,
	Spins: number,
	PityMisses: number,
	FreeSpins: number,
}

type PoolEntry = {
	Index: number,
	Prize: any,
	Weight: number,
}

-- ApplyReward FreeSpins may seed Wheel={FreeSpins=N} without LastSpinAt/Spins/
-- PityMisses — WheelState / SpinWheel must rebuild before arithmetic.
function WheelMath.Ensure(wheel: any): WheelBag
	if type(wheel) ~= "table" then
		return {
			LastSpinAt = 0,
			Spins = 0,
			PityMisses = 0,
			FreeSpins = 0,
		}
	end
	wheel.LastSpinAt = math.max(0, math.floor(tonumber(wheel.LastSpinAt) or 0))
	wheel.Spins = math.max(0, math.floor(tonumber(wheel.Spins) or 0))
	wheel.PityMisses = math.max(0, math.floor(tonumber(wheel.PityMisses) or 0))
	wheel.FreeSpins = math.max(0, math.floor(tonumber(wheel.FreeSpins) or 0))
	return wheel :: WheelBag
end

function WheelMath.RarityRank(rarity: any): number
	return WheelMath.RARITY_RANK[string.upper(tostring(rarity or ""))] or 1
end

-- Readiness snapshot for client WheelState. Mutates nothing; callers Ensure first.
function WheelMath.Snapshot(
	now: number,
	wheel: WheelBag,
	cooldownSeconds: number,
	pityAfter: number
): {
	CanSpin: boolean,
	ReadyAt: number,
	Spins: number,
	FreeSpins: number,
	PityMisses: number,
	PityAfter: number,
	PityArmed: boolean,
}
	local safeCooldown = math.max(0, math.floor(tonumber(cooldownSeconds) or 0))
	local safePityAfter = math.max(1, math.floor(tonumber(pityAfter) or 8))
	local readyAt = wheel.LastSpinAt + safeCooldown
	local freeSpins = wheel.FreeSpins
	local pityMisses = wheel.PityMisses
	local cooldownReady = now >= readyAt
	return {
		CanSpin = freeSpins > 0 or cooldownReady,
		ReadyAt = if freeSpins > 0 then now else math.max(now, readyAt),
		Spins = wheel.Spins,
		FreeSpins = freeSpins,
		PityMisses = pityMisses,
		PityAfter = safePityAfter,
		PityArmed = pityMisses + 1 >= safePityAfter,
	}
end

-- Pity-filtered weight pool. When forcePity empties the pool, callers fall back
-- to the unfiltered rewards table (mirrors former SpinWheel behavior).
function WheelMath.BuildPool(
	rewards: { any },
	forcePity: boolean,
	floorRank: number
): ({ PoolEntry }, number)
	local pool: { PoolEntry } = {}
	local totalWeight = 0
	for index, prize in rewards do
		local rank = WheelMath.RarityRank(prize.Rarity)
		if not forcePity or rank >= floorRank then
			local weight = math.max(0, tonumber(prize.Weight) or 0)
			table.insert(pool, { Index = index, Prize = prize, Weight = weight })
			totalWeight += weight
		end
	end
	return pool, totalWeight
end

function WheelMath.FullPool(rewards: { any }): ({ PoolEntry }, number)
	return WheelMath.BuildPool(rewards, false, 1)
end

-- Weighted pick. `roll` is in [0, totalWeight]; empty pool → nil.
function WheelMath.PickEntry(pool: { PoolEntry }, totalWeight: number, roll: number): PoolEntry?
	if #pool == 0 or totalWeight <= 0 then
		return nil
	end
	local selected = pool[#pool]
	local cursor = 0
	for _, entry in pool do
		cursor += entry.Weight
		if roll <= cursor then
			selected = entry
			break
		end
	end
	return selected
end

-- After a spin: clear pity on floor+ hit, else increment.
function WheelMath.NextPityMisses(pityMisses: any, selectedRank: number, floorRank: number): number
	if selectedRank >= floorRank then
		return 0
	end
	return math.max(0, math.floor(tonumber(pityMisses) or 0)) + 1
end

return table.freeze(WheelMath)
end

-- ======================================================================
-- Module: CrateRoll   (merged from CrateRoll.luau, 151 lines)
-- ======================================================================
__defs["CrateRoll"] = function()
-- Pure crate pity / weighted rarity / drop selection. No Roblox services —
-- ServerServices and Lune verify scripts share this so open-count gates and
-- pity rolls can be tested without Studio. RNG and inventory mutation stay
-- with the caller; rarity tables and definitions are injected.

local CrateRoll = {}

CrateRoll.RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

type CrateLike = {
	PityRarity: string,
	PityAfter: number,
	Weights: { [string]: number },
}

type RarityData = {
	Rank: number,
}

-- Pity floor: once pity+1 reaches PityAfter, only rarities at/above pityRank roll.
function CrateRoll.MinimumRank(pity: number, pityAfter: number, pityRank: number): number
	local safePity = math.max(0, math.floor(tonumber(pity) or 0))
	local after = math.max(0, math.floor(tonumber(pityAfter) or 0))
	local rank = math.max(0, math.floor(tonumber(pityRank) or 0))
	return if safePity + 1 >= after then rank else 0
end

function CrateRoll.TotalWeight(
	weights: { [string]: number },
	rarities: { [string]: RarityData },
	minimumRank: number
): number
	local total = 0
	for rarity, weight in weights do
		local data = rarities[rarity]
		if data and data.Rank >= minimumRank then
			total += weight
		end
	end
	return total
end

-- Walk rarity order subtracting weights; returns selected rarity name.
function CrateRoll.SelectRarity(
	roll: number,
	weights: { [string]: number },
	rarities: { [string]: RarityData },
	minimumRank: number,
	pityRarityFallback: string,
	order: { string }?
): string
	local remaining = roll
	local selected = pityRarityFallback
	local walk = order or CrateRoll.RARITY_ORDER
	for _, rarity in walk do
		local data = rarities[rarity]
		local weight = weights[rarity] or 0
		if data and data.Rank >= minimumRank and weight > 0 then
			remaining -= weight
			if remaining <= 0 then
				selected = rarity
				break
			end
		end
	end
	return selected
end

-- Collect definitions matching rarity, then pick by 1-based index.
function CrateRoll.Candidates(definitions: { any }, selectedRarity: string): { any }
	local candidates = {}
	for _, definition in definitions do
		if definition.Rarity == selectedRarity then
			table.insert(candidates, definition)
		end
	end
	return candidates
end

function CrateRoll.PickCandidate(candidates: { any }, index: number): any?
	if #candidates < 1 then
		return nil
	end
	local safeIndex = math.clamp(math.floor(index), 1, #candidates)
	return candidates[safeIndex]
end

-- Full roll: returns definition, rarity, pityHit. nextNumber/nextInteger inject RNG.
function CrateRoll.Roll(
	crate: CrateLike,
	pity: number,
	rarities: { [string]: RarityData },
	definitions: { any },
	nextNumber: (number, number) -> number,
	nextInteger: (number, number) -> number
): (any?, string, boolean)
	local pityData = rarities[crate.PityRarity]
	local pityRank = pityData and pityData.Rank or 0
	local minimumRank = CrateRoll.MinimumRank(pity, crate.PityAfter, pityRank)
	local totalWeight = CrateRoll.TotalWeight(crate.Weights, rarities, minimumRank)
	local roll = nextNumber(0, math.max(totalWeight, 0.001))
	local selectedRarity = CrateRoll.SelectRarity(
		roll,
		crate.Weights,
		rarities,
		minimumRank,
		crate.PityRarity
	)
	local candidates = CrateRoll.Candidates(definitions, selectedRarity)
	local selected = CrateRoll.PickCandidate(candidates, nextInteger(1, math.max(1, #candidates)))
	local selectedRank = rarities[selectedRarity] and rarities[selectedRarity].Rank or 0
	local pityHit = selectedRank >= pityRank
	if not selected then
		return nil, selectedRarity, false
	end
	return selected, selectedRarity, pityHit
end

-- Open count: only 1 or 5. Non-number → 1. Other numbers → nil + error.
function CrateRoll.NormalizeOpenCount(rawCount: any): (number?, string?)
	local count = if type(rawCount) == "number" then math.clamp(math.floor(rawCount), 1, 5) else 1
	if count ~= 1 and count ~= 5 then
		return nil, "Crates can be opened one or five at a time."
	end
	return count, nil
end

-- True when every positive-weight rarity is marked for auto-salvage and KeepNew is off.
function CrateRoll.GuaranteedRecycle(
	weights: { [string]: number },
	autoEnabled: boolean,
	keepNew: any,
	rarityRules: { [string]: boolean }
): boolean
	if not autoEnabled or keepNew ~= false then
		return false
	end
	for rarity, weight in weights do
		if weight > 0 and rarityRules[rarity] ~= true then
			return false
		end
	end
	return true
end

function CrateRoll.RequiredSlots(count: number, guaranteedRecycle: boolean): number
	return if guaranteedRecycle then 0 else math.max(0, math.floor(count))
end

return table.freeze(CrateRoll)
end

-- ======================================================================
-- Module: OverchargeCombo   (merged from OverchargeCombo.luau, 43 lines)
-- ======================================================================
__defs["OverchargeCombo"] = function()
-- Pure overcharge tap-combo window / multiplier. No Roblox services —
-- ServerServices and Lune verify scripts share this so combo math stays
-- testable without Studio. Config knobs are injected by the caller.

local OverchargeCombo = {}

function OverchargeCombo.Window(comboWindow: number): number
	return comboWindow
end

function OverchargeCombo.Multiplier(combo: number, comboMax: number, bonusPerStack: number): number
	return 1 + math.min(comboMax, math.max(0, combo)) * bonusPerStack
end

-- Advance combo after a successful tap within the window.
function OverchargeCombo.NextCombo(previousCombo: number, comboMax: number): number
	return math.min(comboMax, math.max(0, math.floor(previousCombo)) + 1)
end

-- True when the gap since last tap exceeds the combo window (combo resets).
function OverchargeCombo.Expired(elapsed: number, comboWindow: number): boolean
	return elapsed > comboWindow
end

-- Public Overcharge bag for client rails.
function OverchargeCombo.PublicSnapshot(args: {
	combo: number,
	comboMultiplier: number,
	comboMax: number,
	comboWindow: number,
	comboBonusPerStack: number,
}): any
	return {
		Combo = args.combo,
		ComboMultiplier = args.comboMultiplier,
		ComboMax = args.comboMax,
		ComboWindow = args.comboWindow,
		ComboBonusPerStack = args.comboBonusPerStack,
	}
end

return table.freeze(OverchargeCombo)
end

-- ======================================================================
-- Suite entry point
-- ======================================================================
local __members = {}
for name in __defs do
	table.insert(__members, name)
end
table.sort(__members)
table.freeze(__members)
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		-- The boot loader reads the member list to warm every member up front.
		if name == "__members" then
			return __members
		end
		return __load(name)
	end,
})

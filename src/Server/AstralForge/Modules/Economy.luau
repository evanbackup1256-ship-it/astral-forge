--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
local OmegaMath = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("OmegaMath"))
local CapacityProjection = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("CapacityProjection"))
local OfflineProjection = require(script.Parent:WaitForChild("OfflineProjection"))
local TapCritProjection = require(script.Parent:WaitForChild("TapCritProjection"))
local UpgradeCostReason = require(script.Parent:WaitForChild("UpgradeCostReason"))
local RebirthGate = require(script.Parent:WaitForChild("RebirthGate"))
local ContinuumDomainMath = require(script.Parent:WaitForChild("ContinuumDomainMath"))
local ForgePathClaim = require(script.Parent:WaitForChild("ForgePathClaim"))
local EconomyEnvelopeMath = require(script.Parent:WaitForChild("EconomyEnvelopeMath"))

local Economy = {}

local MAX_ECONOMY_NUMBER = 1e308

export type Persist = number | string

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

export type ProfileLike = {
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
	return math.max(0, lab.Routing[channelId] or 0) * channel.EffectPerCell
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
	if not profile.Items then
		return 0
	end
	-- ApplyReward Keys / partial Studio fixtures may leave Items without Equipped
	-- or Inventory tables — production projections must not throw.
	local equipped = profile.Items.Equipped
	local inventory = profile.Items.Inventory
	if type(equipped) ~= "table" or type(inventory) ~= "table" then
		return 0
	end
	local machines = profile.Machines
	local research = profile.Research
	local total = 0
	for target, uid in equipped do
		local instance = inventory[uid]
		local definition = instance and Economy.GetItemDefinition(instance.DefinitionId)
		local slot, targetId = string.match(target, "^(%a+):([%w_]+)$")
		-- Nil-safe Machines/Research: mid-sanitize / partial fixtures must not throw
		-- when Equipped still points at a slot bag that reconcile has not finished.
		local ownedLevel = if slot == "Machine" and type(machines) == "table"
			then machines[targetId]
			elseif slot == "Research" and type(research) == "table"
			then research[targetId]
			else nil
		if
			definition
			and type(ownedLevel) == "number"
			and ownedLevel > 0
			and definition.EffectKind == effectKind
			and (not slotFilter or slot == slotFilter)
			and (not targetFilter or target == targetFilter)
		then
			total += definition.BaseEffect * (1 + definition.LevelGrowth * math.max(0, instance.Level - 1))
		end
	end
	return total
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
	if not artifact or not owned or artifact.EffectKind ~= effectKind then
		return 0
	end
	return artifact.EffectPerLevel * owned.Level
end

function Economy.MasteryMultiplier(profile: ProfileLike): number
	local command = profile.Command
	if not command then
		return 1
	end
	return EconomyEnvelopeMath.MasteryMultiplier(command.MachineMastery)
end

function Economy.GridEffect(profile: ProfileLike, effectKind: string): number
	local levels = profile.GridUpgrades
	if type(levels) ~= "table" then
		return 0
	end
	local total = 0
	for id, level in levels do
		if type(level) == "number" and level > 0 then
			local upgrade = gridById[id]
			if upgrade and upgrade.EffectKind == effectKind then
				total += level * upgrade.EffectPerLevel
			end
		end
	end
	return total
end

function Economy.AnomalyEffect(profile: ProfileLike, effectKind: string, now: number?): number
	local state = profile.Anomaly
	if not state then
		return 0
	end
	local total = 0
	-- ApplyReward Fragments may seed Anomaly without Protocols — projections must not throw.
	local protocols = state.Protocols
	if type(protocols) == "table" then
		for _, protocol in GameConfig.Anomalies.Protocols do
			if protocol.EffectKind == effectKind then
				total += (protocols[protocol.Id] or 0) * protocol.EffectPerLevel
			end
		end
	end
	-- Overdrive Core: Channel (a single always-on selection) is replaced by Loadout, up to
	-- LoadoutSlots channels slotted at once, each still applying its own EffectAmount -- this
	-- sums every slotted channel that matches effectKind instead of reading one field. Loadout
	-- may be empty on profiles that haven't re-slotted since the old single-Channel system;
	-- DataService's sanitize pass seeds Loadout from the legacy Channel field on load, so this
	-- never silently drops a returning player's existing selection.
	if type(state.Loadout) == "table" then
		for _, channelId in state.Loadout do
			local channel = GameConfig.Anomalies.Channels[channelId]
			if channel and channel.EffectKind == effectKind then
				total += channel.EffectAmount
			end
		end
	end
	local timestamp = now or os.time()
	local cycle = math.floor(timestamp / GameConfig.Anomalies.CycleSeconds)
	local anomaly = GameConfig.Anomalies.Types[cycle % #GameConfig.Anomalies.Types + 1]
	if anomaly and anomaly.EffectKind == effectKind then
		total += anomaly.EffectAmount
	end
	if effectKind == "Production" and type(state.CoreTier) == "number" and state.CoreTier > 0 then
		for _, tierConfig in GameConfig.Anomalies.CoreTiers do
			if tierConfig.Tier <= state.CoreTier then
				total += tierConfig.PassiveProduction
			end
		end
	end
	return total
end

function Economy.AnomalySurgeMultiplier(profile: ProfileLike, now: number?): number
	local state = profile.Anomaly
	if state and state.SurgeEndsAt > (now or os.time()) then
		return GameConfig.Anomalies.SurgeMultiplier
	end
	return 1
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
	local MonetizationConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("MonetizationConfig"))
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
	local cores = math.max(0, tonumber(profile.Cores) or 0)
	local coreBonus = GameConfig.Economy.CoreMultiplier * (cores ^ GameConfig.Economy.CoreExponent)
	local domain = profile.Domain
	local rank = domain and math.max(0, tonumber(domain.Rank) or 0) or 0
	local essence = domain and math.max(0, tonumber(domain.Essence) or 0) or 0
	if essence > 1_000_000 then
		essence = 1_000_000
	end
	local rebirths = math.max(0, tonumber(profile.Rebirths) or 0)
	local domainMultiplier = 1
		+ rank * GameConfig.Domain.ProductionPerRank
		+ essence * GameConfig.Domain.ProductionPerEssence
		+ Economy.DomainTreeBonus(profile, "Production")
		+ Economy.ForgePathEffect(profile, "Production")
	local insightResearch = profile.Research
	local insightLevel = (type(insightResearch) == "table" and insightResearch.Insight) or 0
	local rebirthMultiplier = GameConfig.Economy.RebirthMultiplier
		* (1 + Economy.ForgePathEffect(profile, "RebirthMultiplier"))
		* (1 + insightLevel * 0.02)
	return bounded((1 + coreBonus + rebirths * rebirthMultiplier) * domainMultiplier)
end


function Economy.EchoEffect(profile: ProfileLike, effectKind: string): number
	local echoes = profile.ForgeEchoes
	if not echoes or type(echoes.Inventory) ~= "table" or type(echoes.Equipped) ~= "table" then
		return 0
	end
	local total = 0
	local affinities = {}
	local equippedCount = 0
	local used = {}
	for _, uid in echoes.Equipped do
		local instance = type(uid) == "string" and echoes.Inventory[uid] or nil
		if instance and not used[uid] then
			used[uid] = true
			local trait = nil
			for _, candidate in GameConfig.ForgeEchoes.Traits do
				if candidate.Id == instance.TraitId then trait = candidate break end
			end
			if trait then
				equippedCount += 1
				affinities[trait.Affinity] = true
				if trait.EffectKind == effectKind then
					local level = math.clamp(math.floor(tonumber(instance.Level) or 1), 1, GameConfig.ForgeEchoes.MaxLevel)
					local strength = math.clamp(tonumber(instance.Strength) or 1, 0.75, 1.5)
					total += (trait.BaseEffect + trait.EffectPerLevel * (level - 1)) * strength
				end
			end
		end
	end
	local affinityCount = 0
	for _ in affinities do affinityCount += 1 end
	if equippedCount >= 2 and affinityCount == equippedCount then
		total *= 1 + GameConfig.ForgeEchoes.HarmonyBonus
	end
	return total
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
	multiplier = OmegaMath.Mul(multiplier, 1 + passProduction)
	multiplier = OmegaMath.Mul(multiplier, 1 + (profile.GuildBonuses and profile.GuildBonuses.Production or 0))
	multiplier = OmegaMath.Mul(multiplier, math.max(1, profile.SocialBoost and profile.SocialBoost.Multiplier or 1))
	multiplier = OmegaMath.Mul(multiplier, Economy.MasteryMultiplier(profile))
	multiplier = OmegaMath.Mul(multiplier, Economy.AnomalySurgeMultiplier(profile, now))
	multiplier = OmegaMath.Mul(multiplier, select(1, Economy.ContinuumEffects(profile)))
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

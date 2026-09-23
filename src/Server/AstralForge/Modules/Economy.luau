--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
local OmegaMath = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("OmegaMath"))

local Economy = {}

local MAX_ECONOMY_NUMBER = 1e308

export type Persist = number | string

local function bounded(value: any): Persist
	return OmegaMath.Persist(value)
end

local function scaledCost(baseCost: number, scale: number, level: number): Persist
	return OmegaMath.ScaledCost(baseCost, scale, level)
end

local function boundedPower(base: number, exponent: number): Persist
	return OmegaMath.BoundedPower(base, exponent)
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
	local machines = profile.Machines
	local research = profile.Research
	local total = 0
	for target, uid in profile.Items.Equipped do
		local instance = profile.Items.Inventory[uid]
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
	local points = 0
	for _, value in command.MachineMastery do
		points += value
	end
	return 1 + math.min(0.5, points * 0.002)
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
	for _, protocol in GameConfig.Anomalies.Protocols do
		if protocol.EffectKind == effectKind then
			total += (state.Protocols[protocol.Id] or 0) * protocol.EffectPerLevel
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
	local nodes = domain and domain.Nodes
	if type(nodes) ~= "table" then
		return 0
	end
	local tree = GameConfig.Domain.Tree
	if type(tree) ~= "table" then
		return 0
	end
	local total = 0
	for _, node in tree do
		if nodes[node.Id] == true then
			local amount = node[field]
			if type(amount) == "number" then
				total += amount
			end
		end
	end
	return total
end

function Economy.MachineCost(id: string, currentLevel: number): number
	local machine = Economy.GetMachine(id)
	if not machine then
		return math.huge
	end
	return scaledCost(machine.BaseCost, machine.CostScale, currentLevel)
end

function Economy.ResearchCost(id: string, currentLevel: number): number
	local research = Economy.GetResearch(id)
	if not research then
		return math.huge
	end
	return scaledCost(research.BaseCost, research.CostScale, currentLevel)
end

function Economy.GridUpgradeCost(id: string, currentLevel: number): number
	local upgrade = Economy.GetGridUpgrade(id)
	if not upgrade then
		return math.huge
	end
	return scaledCost(upgrade.BaseCost, upgrade.CostScale, currentLevel)
end

function Economy.GridBulkCost(id: string, currentLevel: number, count: number): Persist
	local upgrade = Economy.GetGridUpgrade(id)
	if not upgrade then
		return math.huge
	end
	return OmegaMath.GeometricSum(upgrade.BaseCost, upgrade.CostScale, currentLevel, count)
end

function Economy.AffordableGridLevels(
	id: string,
	currentLevel: number,
	stardust: any,
	maximum: number
): (number, Persist)
	local upgrade = Economy.GetGridUpgrade(id)
	if not upgrade then
		return 0, 0
	end
	return OmegaMath.AffordableCount(upgrade.BaseCost, upgrade.CostScale, currentLevel, stardust, maximum)
end

function Economy.MachineBulkCost(id: string, currentLevel: number, count: number): Persist
	local machine = Economy.GetMachine(id)
	if not machine then
		return math.huge
	end
	return OmegaMath.GeometricSum(machine.BaseCost, machine.CostScale, currentLevel, count)
end

function Economy.ResearchBulkCost(id: string, currentLevel: number, count: number): Persist
	local research = Economy.GetResearch(id)
	if not research then
		return math.huge
	end
	return OmegaMath.GeometricSum(research.BaseCost, research.CostScale, currentLevel, count)
end

function Economy.AffordableMachineLevels(
	id: string,
	currentLevel: number,
	cash: any,
	maximum: number
): (number, Persist)
	local machine = Economy.GetMachine(id)
	if not machine then
		return 0, 0
	end
	return OmegaMath.AffordableCount(machine.BaseCost, machine.CostScale, currentLevel, cash, maximum)
end

function Economy.AffordableResearchLevels(
	id: string,
	currentLevel: number,
	cash: any,
	maximum: number
): (number, Persist)
	local research = Economy.GetResearch(id)
	if not research then
		return 0, 0
	end
	return OmegaMath.AffordableCount(research.BaseCost, research.CostScale, currentLevel, cash, maximum)
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
	local claimed = forgePath.ClaimedSteps
	if type(claimed) ~= "table" then
		return 0
	end
	local total = 0
	for stepKey in claimed do
		local stepIndex = tonumber(stepKey)
		local step = stepIndex and GameConfig.ForgePath.Steps[stepIndex]
		if step and step.EffectKind == effectKind then
			total += step.EffectAmount
		end
	end
	return total / 100
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
	local safeRank = math.max(0, math.floor(rank))
	local config = GameConfig.Continuum
	local flux = OmegaMath.Floor(OmegaMath.Mul(config.BaseFluxCost, boundedPower(config.FluxCostScale, safeRank)))
	local stardust = OmegaMath.Floor(OmegaMath.Mul(config.BaseStardustCost, boundedPower(config.StardustCostScale, safeRank)))
	return flux, stardust
end

function Economy.ContinuumEffects(profile: ProfileLike): (Persist, Persist, Persist, number)
	local rank = profile.Continuum and math.max(0, math.floor(profile.Continuum.Rank or 0)) or 0
	local config = GameConfig.Continuum
	local milestones = math.floor(rank / config.MilestoneEvery)
	local milestoneMultiplier = boundedPower(config.MilestoneScale, milestones)
	local production = OmegaMath.Mul(boundedPower(config.ProductionScale, rank), milestoneMultiplier)
	local capacity = boundedPower(config.CapacityScale, rank)
	local tap = boundedPower(config.TapScale, rank)
	local offline = math.min(config.OfflineCap, rank * config.OfflinePerRank)
	return production, capacity, tap, offline
end

function Economy.DomainRequirements(rank: number): (number, number)
	local safeRank = math.max(0, math.floor(rank))
	local rebirths = math.floor(math.min(
		MAX_ECONOMY_NUMBER,
		GameConfig.Domain.BaseRequiredRebirths + safeRank * GameConfig.Domain.RebirthsPerRank
	))
	local cores = scaledCost(
		GameConfig.Domain.BaseRequiredCores,
		GameConfig.Domain.CoreRequirementScale,
		safeRank
	)
	return rebirths, OmegaMath.ToNumber(cores)
end

function Economy.DomainRewards(rank: number): (number, number)
	local safeRank = math.max(0, math.floor(rank))
	local essence = math.floor(math.min(
		MAX_ECONOMY_NUMBER,
		GameConfig.Domain.BaseEssenceReward + safeRank * GameConfig.Domain.EssencePerRank
	))
	local stardust = math.floor(math.min(
		MAX_ECONOMY_NUMBER,
		GameConfig.Domain.BaseStardustReward + safeRank * GameConfig.Domain.StardustPerRank
	))
	return essence, stardust
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
	multiplier = OmegaMath.Mul(multiplier, select(1, Economy.ContinuumEffects(profile)))
	return OmegaMath.Mul(Economy.RawProduction(profile), multiplier)
end

function Economy.Capacity(profile: ProfileLike, now: number?, _production: any): Persist
	local research = profile.Research
	local storageLevel = (type(research) == "table" and research.Storage) or 0
	local passCapacity = select(2, Economy.PassBonuses(profile))
	local seconds = GameConfig.Economy.BaseCapacitySeconds
		* (GameConfig.Economy.CapacitySecondsPerLevel ^ storageLevel)
	seconds *= 1 + Economy.GridEffect(profile, "GridCapacity")
	seconds *= 1 + Economy.EchoEffect(profile, "Capacity")
	seconds *= 1 + Economy.ArtifactEffect(profile, "Capacity")
	seconds *= 1 + Economy.ItemEffect(profile, "Capacity", "Research")
	seconds *= 1 + Economy.AnomalyEffect(profile, "Capacity", now)
	seconds *= 1 + Economy.LabPowerEffect(profile, "Storage")
	seconds *= 1 + passCapacity
	seconds *= 1 + (profile.GuildBonuses and profile.GuildBonuses.Capacity or 0)
	seconds *= 1 + Economy.ForgePathEffect(profile, "Capacity")
	local _, continuumCapacity = Economy.ContinuumEffects(profile)
	local domainRank = profile.Domain and math.max(0, profile.Domain.Rank or 0) or 0
	seconds *= 1 + domainRank * GameConfig.Domain.CapacityPerRank
	local activeBoost = profile.ActiveBoost
	if activeBoost and activeBoost.EndsAt > (now or os.time()) then
		local boost = GameConfig.Boosts[activeBoost.Id]
		if boost and boost.CapacityMultiplier then
			seconds *= boost.CapacityMultiplier
		end
	end
	seconds = math.clamp(seconds, 1, GameConfig.Economy.MaxCapacitySeconds)

	seconds *= 1 + Economy.DomainTreeBonus(profile, "Capacity")
	local output = Economy.SteadyProduction(profile, now)

	local capacity = OmegaMath.Floor(OmegaMath.Max(
		GameConfig.Economy.BaseCapacity,
		OmegaMath.Mul(OmegaMath.Mul(output, seconds), continuumCapacity)
	))
	return capacity
end


function Economy.CapacitySeconds(profile: ProfileLike, now: number?, _production: any): number
	local output = Economy.SteadyProduction(profile, now)
	if Economy.Lte(output, 0) then
		return 0
	end
	return OmegaMath.ToNumber(OmegaMath.Div(Economy.Capacity(profile, now), output))
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
	local overchargeLevel = researchLevel(profile, "Overcharge")
	local tap = OmegaMath.Max(1, OmegaMath.Mul(Economy.Production(profile, now), 0.15))
	tap = OmegaMath.Mul(tap, 1 + overchargeLevel * 0.35)
	tap = OmegaMath.Mul(tap, 1 + Economy.GridEffect(profile, "GridTap"))
	tap = OmegaMath.Mul(tap, 1 + Economy.EchoEffect(profile, "Tap"))
	tap = OmegaMath.Mul(tap, 1 + Economy.ArtifactEffect(profile, "Tap"))
	tap = OmegaMath.Mul(tap, 1 + Economy.ItemEffect(profile, "Tap", "Research"))
	tap = OmegaMath.Mul(tap, 1 + Economy.AnomalyEffect(profile, "Tap", now))
	tap = OmegaMath.Mul(tap, 1 + Economy.LabPowerEffect(profile, "Tap"))
	tap = OmegaMath.Mul(tap, 1 + (profile.GuildBonuses and profile.GuildBonuses.Tap or 0))
	tap = OmegaMath.Mul(tap, select(3, Economy.ContinuumEffects(profile)))
	tap = OmegaMath.Mul(tap, 1 + Economy.ForgePathEffect(profile, "TapPower"))
	return tap
end

function Economy.CriticalChance(profile: ProfileLike): number
	return math.min(
		0.75,
		0.05
			+ researchLevel(profile, "Critical") * 0.012
			+ Economy.GridEffect(profile, "GridCritical")
			+ Economy.EchoEffect(profile, "Critical")
			+ Economy.ArtifactEffect(profile, "Critical")
			+ Economy.ItemEffect(profile, "Critical", "Research")
			+ Economy.AnomalyEffect(profile, "Critical")
			+ Economy.ForgePathEffect(profile, "CriticalChance")
	)
end

function Economy.CriticalMultiplier(profile: ProfileLike): number
	return 2
		+ math.floor(researchLevel(profile, "Critical") / 5) * 0.5
		+ researchLevel(profile, "Impact") * 0.1
		+ Economy.ForgePathEffect(profile, "CriticalMultiplier")
end

function Economy.AutoCollectRate(profile: ProfileLike): number
	return math.min(
		0.8,
		researchLevel(profile, "Automation") * 0.02
			+ Economy.GridEffect(profile, "GridAutomation")
			+ Economy.EchoEffect(profile, "Automation")
			+ Economy.ArtifactEffect(profile, "Automation")
			+ Economy.ItemEffect(profile, "Automation", "Research")
			+ Economy.AnomalyEffect(profile, "Automation")
			+ (profile.GuildBonuses and profile.GuildBonuses.Automation or 0)
			+ Economy.ForgePathEffect(profile, "AutoCollect")
	)
end

function Economy.OfflineHours(profile: ProfileLike): number
	return math.min(
		24,
		GameConfig.Economy.BaseOfflineHours
			+ researchLevel(profile, "Offline") * 1.25
			+ Economy.ArtifactEffect(profile, "OfflineHours")
	)
end

function Economy.OfflineEfficiency(profile: ProfileLike, now: number?): number
	local _, _, _, continuumOffline = Economy.ContinuumEffects(profile)
	return math.min(
		1,
		GameConfig.Economy.BaseOfflineEfficiency
			+ researchLevel(profile, "Offline") * 0.06
			+ Economy.GridEffect(profile, "GridOffline")
			+ Economy.EchoEffect(profile, "Offline")
			+ Economy.ArtifactEffect(profile, "Offline")
			+ Economy.ItemEffect(profile, "Offline", "Research")
			+ Economy.AnomalyEffect(profile, "Offline", now)
			+ (profile.GuildBonuses and profile.GuildBonuses.Offline or 0)
			+ (profile.Domain and math.max(0, profile.Domain.Rank or 0) or 0) * GameConfig.Domain.OfflineEfficiencyPerRank
			+ continuumOffline
			+ Economy.ForgePathEffect(profile, "Offline")
	)
end


function Economy.OfflineEarnings(
	profile: ProfileLike,
	startedAt: number,
	endedAt: number
): (Persist, number, number, boolean)
	local rawElapsed = math.max(0, endedAt - startedAt)
	local maximum = math.max(0, Economy.OfflineHours(profile) * 3600)
	local elapsed = math.min(rawElapsed, maximum)
	if elapsed < 30 then
		return 0, elapsed, 0, rawElapsed > maximum
	end


	local from = startedAt
	local to = startedAt + elapsed
	local boundaries = { from, to }
	local cycleSeconds = math.max(1, GameConfig.Anomalies.CycleSeconds)
	local nextCycle = (math.floor(from / cycleSeconds) + 1) * cycleSeconds
	while nextCycle < to do
		table.insert(boundaries, nextCycle)
		nextCycle += cycleSeconds
	end
	local boostEnd = profile.ActiveBoost and profile.ActiveBoost.EndsAt or 0
	if boostEnd > from and boostEnd < to then
		table.insert(boundaries, boostEnd)
	end
	local surgeEnd = profile.Anomaly and profile.Anomaly.SurgeEndsAt or 0
	if surgeEnd > from and surgeEnd < to then
		table.insert(boundaries, surgeEnd)
	end
	table.sort(boundaries)

	local reward = 0
	local weightedEfficiency = 0
	for index = 1, #boundaries - 1 do
		local left = boundaries[index]
		local right = boundaries[index + 1]
		local duration = right - left
		if duration > 0 then
			local sample = left + duration * 0.5
			local efficiency = Economy.OfflineEfficiency(profile, sample)
			reward = Economy.Add(reward, Economy.Mul(Economy.Production(profile, sample), efficiency * duration))
			weightedEfficiency += efficiency * duration
		end
	end
	return bounded(reward), elapsed, weightedEfficiency / elapsed, rawElapsed > maximum
end

function Economy.PrestigeReward(runCash: any): Persist
	if Economy.Lt(runCash, GameConfig.Economy.PrestigeRequirement) then
		return 0
	end
	local ratio = OmegaMath.Div(runCash, GameConfig.Economy.PrestigeRequirement)
	return OmegaMath.Max(1, OmegaMath.Floor(OmegaMath.Pow(ratio, GameConfig.Economy.PrestigeExponent)))
end

function Economy.NextPrestigeTarget(currentReward: any): Persist
	local desired = OmegaMath.Max(1, OmegaMath.Add(currentReward, 1))
	return OmegaMath.Floor(OmegaMath.Mul(
		GameConfig.Economy.PrestigeRequirement,
		OmegaMath.Pow(desired, 1 / GameConfig.Economy.PrestigeExponent)
	))
end

function Economy.TotalMachineLevels(profile: ProfileLike): number
	local machines = profile.Machines
	if type(machines) ~= "table" then
		return 0
	end
	local total = 0
	for _, value in machines do
		if type(value) == "number" then
			total += value
		end
	end
	return total
end

function Economy.TotalResearchLevels(profile: ProfileLike): number
	local research = profile.Research
	if type(research) ~= "table" then
		return 0
	end
	local total = 0
	for _, value in research do
		if type(value) == "number" then
			total += value
		end
	end
	return total
end

return table.freeze(Economy)

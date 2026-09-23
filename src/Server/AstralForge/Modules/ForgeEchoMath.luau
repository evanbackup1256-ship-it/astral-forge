--!strict
-- Pure forge-echo inventory / slot / effect / pattern helpers. No Roblox
-- services — ForgeEchoService and Lune verify scripts share this so vault math
-- can be tested without Studio. Profile mutation and Random draft picks stay
-- with the caller; Config / trait tables are injected.

local ForgeEchoMath = {}

ForgeEchoMath.PATTERN_IDS = { "Collect", "Surge", "Build", "Explore" }

ForgeEchoMath.PATTERN_AFFINITY = {
	Collect = "Industry",
	Surge = "Impulse",
	Build = "Craft",
	Explore = "Void",
}

export type ForgeEchoesBag = {
	Charge: number,
	Resonance: number,
	Captures: number,
	NextId: number,
	Pattern: { [string]: number },
	Draft: { Id: string, Choices: { any } },
	Inventory: { [string]: any },
	Equipped: { [string]: string },
}

-- Studio fixtures / mid-migrate bags may omit ForgeEchoes entirely, or leave
-- Pattern/Draft/Inventory/Equipped nil — Admin GrantEchoCharge and
-- ForgeEchoService paths must rebuild before indexing Charge / Draft.Choices.
function ForgeEchoMath.Ensure(echoes: any): ForgeEchoesBag
	if type(echoes) ~= "table" then
		return {
			Charge = 0,
			Resonance = 0,
			Captures = 0,
			NextId = 1,
			Pattern = { Collect = 0, Surge = 0, Build = 0, Explore = 0 },
			Draft = { Id = "", Choices = {} },
			Inventory = {},
			Equipped = { ["1"] = "", ["2"] = "", ["3"] = "" },
		}
	end
	echoes.Pattern = type(echoes.Pattern) == "table" and echoes.Pattern
		or { Collect = 0, Surge = 0, Build = 0, Explore = 0 }
	echoes.Draft = type(echoes.Draft) == "table" and echoes.Draft or { Id = "", Choices = {} }
	echoes.Draft.Choices = type(echoes.Draft.Choices) == "table" and echoes.Draft.Choices or {}
	echoes.Inventory = type(echoes.Inventory) == "table" and echoes.Inventory or {}
	echoes.Equipped = type(echoes.Equipped) == "table" and echoes.Equipped
		or { ["1"] = "", ["2"] = "", ["3"] = "" }
	echoes.Charge = math.max(0, tonumber(echoes.Charge) or 0)
	echoes.Resonance = math.max(0, math.floor(tonumber(echoes.Resonance) or 0))
	echoes.Captures = math.max(0, math.floor(tonumber(echoes.Captures) or 0))
	echoes.NextId = math.max(1, math.floor(tonumber(echoes.NextId) or 1))
	return echoes :: ForgeEchoesBag
end

function ForgeEchoMath.InventoryCount(inventory: any): number
	if type(inventory) ~= "table" then
		return 0
	end
	local count = 0
	for _ in inventory do
		count += 1
	end
	return count
end

-- Captures unlock slots by SlotCaptureRequirements index; clamped to [1, maxSlots].
function ForgeEchoMath.UnlockedSlots(
	captures: any,
	slotCaptureRequirements: { number },
	maxSlots: number
): number
	local safeCaptures = math.max(0, math.floor(tonumber(captures) or 0))
	local slots = 1
	for index, requirement in slotCaptureRequirements do
		if safeCaptures >= requirement then
			slots = index
		end
	end
	return math.clamp(slots, 1, maxSlots)
end

function ForgeEchoMath.EffectValue(
	instance: any,
	trait: { BaseEffect: number, EffectPerLevel: number },
	maxLevel: number
): number
	local level = math.clamp(math.floor(tonumber(instance and instance.Level) or 1), 1, maxLevel)
	local strength = math.clamp(tonumber(instance and instance.Strength) or 1, 0.75, 1.5)
	return (trait.BaseEffect + trait.EffectPerLevel * (level - 1)) * strength
end

function ForgeEchoMath.UpgradeCost(
	level: any,
	maxLevel: number,
	upgradeBaseDust: number,
	upgradeScale: number
): number
	local safeLevel = math.clamp(math.floor(tonumber(level) or 1), 1, maxLevel)
	if safeLevel >= maxLevel then
		return 0
	end
	return math.max(1, math.floor(upgradeBaseDust * (upgradeScale ^ (safeLevel - 1)) + 0.5))
end

-- Returns dominant pattern id and its affinity label. Empty / missing Pattern → Collect.
function ForgeEchoMath.DominantPattern(
	pattern: any,
	patternAffinity: { [string]: string }?
): (string, string)
	local affinity = patternAffinity or ForgeEchoMath.PATTERN_AFFINITY
	local best = "Collect"
	local value = -1
	local bag = type(pattern) == "table" and pattern or {}
	for _, id in ForgeEchoMath.PATTERN_IDS do
		local score = math.max(0, tonumber(bag[id]) or 0)
		if score > value then
			best = id
			value = score
		end
	end
	return best, affinity[best] or "Industry"
end


-- Sum equipped echo effects for `effectKind`. Traits may be a list or Id→trait map.
-- Harmony bonus applies when every equipped slot shares a distinct affinity.
function ForgeEchoMath.EquippedEffect(
	echoes: any,
	effectKind: any,
	traits: any,
	maxLevel: any,
	harmonyBonus: any
): number
	if type(echoes) ~= "table" or type(effectKind) ~= "string" then
		return 0
	end
	if type(echoes.Inventory) ~= "table" or type(echoes.Equipped) ~= "table" then
		return 0
	end
	local traitById: { [string]: any } = {}
	if type(traits) == "table" then
		for key, candidate in traits do
			if type(candidate) == "table" and type(candidate.Id) == "string" then
				traitById[candidate.Id] = candidate
			elseif type(key) == "string" and type(candidate) == "table" then
				traitById[key] = candidate
			end
		end
	end
	local levelCap = math.max(1, math.floor(tonumber(maxLevel) or 1))
	local total = 0
	local affinities = {}
	local equippedCount = 0
	local used = {}
	for _, uid in echoes.Equipped do
		local instance = type(uid) == "string" and echoes.Inventory[uid] or nil
		if instance and not used[uid] then
			used[uid] = true
			local trait = traitById[instance.TraitId]
			if trait then
				equippedCount += 1
				affinities[trait.Affinity] = true
				if trait.EffectKind == effectKind then
					total += ForgeEchoMath.EffectValue(instance, trait, levelCap)
				end
			end
		end
	end
	local affinityCount = 0
	for _ in affinities do
		affinityCount += 1
	end
	if equippedCount >= 2 and affinityCount == equippedCount then
		total *= 1 + (tonumber(harmonyBonus) or 0)
	end
	return total
end

return table.freeze(ForgeEchoMath)

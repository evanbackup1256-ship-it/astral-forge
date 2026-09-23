--!strict
-- Pure anomaly protocol / charge-target / directive helpers. No Roblox services —
-- AnomalyService and Lune verify scripts share FindProtocol / ProtocolEffect /
-- ChargeTarget / SelectDirectives / ProtocolCost so reactor math stays testable
-- without Studio. Clocks and profile mutation stay with the caller; balance
-- tables are injected (GameConfig values).

local AnomalyOpsMath = {}

export type ProtocolLike = {
	Id: string,
	EffectKind: string?,
	EffectPerLevel: number?,
	BaseCost: number?,
	CostScale: number?,
}

export type DirectiveDefinition = {
	Id: string,
	TargetMin: number,
	TargetMax: number,
}

export type CoreTierLike = {
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

return table.freeze(AnomalyOpsMath)

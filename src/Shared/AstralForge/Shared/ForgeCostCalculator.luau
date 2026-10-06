--!strict
-- Purpose: Pure cost/reward/affordability calculations for Astral Forge actions, usable on client and server.
-- Owner: Astral Forge economy. Dependencies: OmegaMath, GameConfig. Last-reviewed: 2026-10-05.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared")

local OmegaMath = require(Shared:WaitForChild("OmegaMath"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

export type CurrencySnapshot = {
	Cash: any,
	Vault: any,
	Stardust: any,
	Cores: any,
}

export type CostResult = {
	ok: boolean,
	deficit: CurrencySnapshot?,
	quote: CurrencySnapshot?,
}

export type ForgeCostCalculator = {
	CanAfford: (profile: any, cost: CurrencySnapshot) -> boolean,
	QuoteUpgrade: (profile: any, featureId: string, levels: number) -> CostResult,
	QuoteAnomalyProtocol: (profile: any, protocolId: string) -> CostResult,
	QuoteContinuumUpgrade: (profile: any, rank: number) -> CostResult,
	QuoteGridBulk: (profile: any, cellIds: { string }) -> CostResult,
}

local function canAfford(profile: any, cost: CurrencySnapshot): boolean
	-- TODO: implement using OmegaMath comparison against profile currencies
	return true
end

local function quoteUpgrade(_profile: any, _featureId: string, _levels: number): CostResult
	-- TODO: read GameConfig.ForgePath / research / machine scaling costs
	return { ok = false, deficit = nil, quote = nil }
end

local function quoteAnomalyProtocol(_profile: any, _protocolId: string): CostResult
	-- TODO: read AnomalyOpsMath.ProtocolCost
	return { ok = false, deficit = nil, quote = nil }
end

local function quoteContinuumUpgrade(_profile: any, _rank: number): CostResult
	-- TODO: read Economy.ContinuumCosts
	return { ok = false, deficit = nil, quote = nil }
end

local function quoteGridBulk(_profile: any, _cellIds: { string }): CostResult
	-- TODO: read Economy.GridBulkCost / AffordableGridLevels
	return { ok = false, deficit = nil, quote = nil }
end

local ForgeCostCalculator: ForgeCostCalculator = {
	CanAfford = canAfford,
	QuoteUpgrade = quoteUpgrade,
	QuoteAnomalyProtocol = quoteAnomalyProtocol,
	QuoteContinuumUpgrade = quoteContinuumUpgrade,
	QuoteGridBulk = quoteGridBulk,
}

return table.freeze(ForgeCostCalculator)

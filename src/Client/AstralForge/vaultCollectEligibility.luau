--!strict
-- Pure vault-collect eligibility thresholds shared by Overview, VaultPill,
-- and Workspace. No Roblox services — Lune verify scripts exercise these
-- without Studio. Callers pass already-normalized flux numbers (asFlux).

local VaultCollectEligibility = {}

-- Minimum vault flux before Collect is enabled (matches prior inline 0.01).
VaultCollectEligibility.MIN_COLLECTABLE = 0.01
-- Fill ratio that highlights the collect CTA as urgent.
VaultCollectEligibility.NEAR_FULL = 0.85
-- Fill ratio treated as a full / wasting-production vault.
VaultCollectEligibility.FULL = 0.99

function VaultCollectEligibility.isEligible(vaultFlux: number): boolean
	local amount = tonumber(vaultFlux) or 0
	return amount >= VaultCollectEligibility.MIN_COLLECTABLE
end

function VaultCollectEligibility.isNearFull(fill: number): boolean
	local ratio = tonumber(fill) or 0
	return ratio >= VaultCollectEligibility.NEAR_FULL
end

function VaultCollectEligibility.isFull(fill: number): boolean
	local ratio = tonumber(fill) or 0
	return ratio >= VaultCollectEligibility.FULL
end

return table.freeze(VaultCollectEligibility)

--!strict
-- Pure boost-id → icon-kind mapping for ActiveBoost chrome. No Roblox
-- services — MainGame and Lune verify scripts share this so icon routing
-- stays testable without Studio.

local BoostIconKind = {}

function BoostIconKind.of(boostId: any): string
	if boostId == "DomainSurge" then
		return "Domain"
	end
	if boostId == "VaultSurge" then
		return "Vault"
	end
	if boostId == "Hyperdrive" then
		return "World"
	end
	return "Reactor"
end

return table.freeze(BoostIconKind)

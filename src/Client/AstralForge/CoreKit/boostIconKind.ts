export function of(boostId: unknown): string {
	if (boostId === "DomainSurge") {
		return "Domain";
	}
	if (boostId === "VaultSurge") {
		return "Vault";
	}
	if (boostId === "Hyperdrive") {
		return "World";
	}
	return "Reactor";
}

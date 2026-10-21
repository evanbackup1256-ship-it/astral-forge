// Pays a relic rig the first time it is fully socketed, and reads the ledger back
// for the profile snapshot. The bonus itself is applied from the shared module.
import RelicRigs from "../../../../Shared/AstralForge/Shared/RelicRigs";
import { Dict, isTable } from "../LuaInterop";

type Rig = (typeof RelicRigs.RIGS)[number];

function itemsOf(profile: Dict): Dict | undefined {
	return isTable(profile.Items) ? profile.Items : undefined;
}

function Settle(profile: Dict): Rig[] {
	const items = itemsOf(profile);
	if (items === undefined) {
		return [];
	}
	const ledger = RelicRigs.ensure(items.Rigs);
	items.Rigs = ledger;
	const fresh = RelicRigs.pending(profile, ledger);
	for (const entry of fresh) {
		ledger.Lit[entry.Id] = true;
	}
	return fresh;
}

function Public(profile: Dict): { Lit: Record<string, boolean>; Active: Record<string, boolean>; Bonus: Record<string, number> } {
	return RelicRigs.view(profile);
}

const RelicRigService = {
	Settle,
	Public,
	effectText: RelicRigs.effectText,
};

export = RelicRigService;

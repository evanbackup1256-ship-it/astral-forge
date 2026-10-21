// Companion Bonds (v8 #3): the server side of bond XP and evolution traits. The math lives in
// Shared/CompanionRelic so the HUD and Inventory read the same curve. Actions are counted into the
// player's runtime as they happen and banked on the 10s maintenance pass, like event tokens.
import CompanionRelic = require("../../../../Shared/AstralForge/Shared/CompanionRelic");
import * as HotFlags from "../Security/HotFlags";
import { Dict, isTable } from "../LuaInterop";
import { T } from "../../../../Shared/AstralForge/Shared/Locale";

const PAUSE_FLAG = "CompanionBondsPaused" as const;

function paused(): boolean {
	return HotFlags.Get(PAUSE_FLAG);
}

function Record(runtime: Dict | undefined, action: string): void {
	if (runtime === undefined || paused()) return;
	if (action === "Overcharge") {
		runtime.BondTaps = ((runtime.BondTaps as number | undefined) ?? 0) + 1;
	} else if (action === "OpenItemCrate") {
		runtime.BondCrates = ((runtime.BondCrates as number | undefined) ?? 0) + 1;
	}
}

// Banks the counted play onto the current companion. Returns whether the profile changed and the
// rank reached when it crossed an evolution (0 otherwise).
function Settle(runtime: Dict, profile: Dict, now: number): LuaTuple<[boolean, number]> {
	const last = (runtime.BondAt as number | undefined) ?? now;
	const taps = (runtime.BondTaps as number | undefined) ?? 0;
	const crates = (runtime.BondCrates as number | undefined) ?? 0;
	runtime.BondAt = now;
	runtime.BondTaps = 0;
	runtime.BondCrates = 0;
	if (paused()) return $tuple(false, 0);
	// a long gap (a stalled server, a debugger) is not play time
	const minutes = math.clamp(now - last, 0, 60) / 60;
	const xp = CompanionRelic.xpFor(minutes, taps, crates);
	const evolved = CompanionRelic.addBondXP(profile.Items, xp);
	return $tuple(evolved !== undefined, evolved ?? 0);
}

function Act(profile: Dict, payload: unknown): LuaTuple<[boolean, string]> {
	if (paused()) return $tuple(false, T("CompanionBonds.Paused"));
	const bag = isTable(payload) ? (payload as Dict) : undefined;
	if (bag === undefined || bag.Op !== "PickTrait") return $tuple(false, T("CompanionBonds.UnknownAction"));
	return CompanionRelic.pickTrait(profile.Items, bag.Trait);
}

export = table.freeze({ PAUSE_FLAG, Record, Settle, Act });

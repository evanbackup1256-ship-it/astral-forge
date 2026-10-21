// Live-ops kill switches an owner can flip from the admin panel without a deploy. Every flag
// defaults to off, so a server that never hears a change behaves exactly as before. Changes
// reach other live servers through the admin MessagingService topic, and the current state is
// kept in a DataStore so a server that starts later loads it (see Encode/Decode).
import { T } from "../../../../Shared/AstralForge/Shared/Locale";

export const STORE_NAME = "AstralForge_LiveOpsFlags_v1";
export const STORE_KEY = "state";

export const FLAGS = table.freeze({
	TradingPaused: "New trades and settlements are refused.",
	CratesPaused: "Crate opening is refused.",
	AnnouncementsMuted: "Cross-server admin announcements are not shown in this server.",
	LimitedEventsPaused: "The running limited event stops paying tokens and its stall closes. Tokens are kept.",
	// ---- v8 C: Companion Bonds ----
	CompanionBondsPaused: "Companions stop gaining bond XP and trait picks are refused. Ranks and shares are kept.",
	// ---- end v8 C: Companion Bonds ----
	// ---- v8 C: Expedition Board ----
	ExpeditionBoardPaused: "Expedition launches, claims and recalls are refused. Running expeditions keep their timers and crew.",
	// ---- end v8 C: Expedition Board ----
	// ---- v8 C: Forge Programs ----
	ForgeProgramsPaused: "Forge Programs stop running and can't be edited. Saved rules are kept.",
	// ---- end v8 C: Forge Programs ----
	ConstellationsPaused: "No new stars can be lit. Stars already lit keep paying.",
});

export type HotFlag = keyof typeof FLAGS;

const state: Partial<Record<HotFlag, boolean>> = {};
let changedAt = 0;

export function IsFlag(name: unknown): name is HotFlag {
	return typeIs(name, "string") && (FLAGS as Record<string, string | undefined>)[name] !== undefined;
}

export function Get(name: HotFlag): boolean {
	return state[name] === true;
}

/** Returns true when the value changed. */
export function Set(name: HotFlag, on: boolean, at?: number): boolean {
	const stamp = at ?? os.time();
	// a late or replayed message must not undo a newer change
	if (stamp < changedAt) return false;
	changedAt = stamp;
	const before = state[name] === true;
	state[name] = on === true;
	return before !== (on === true);
}

/** Parses "Name=on" / "Name=off" from the admin option field. */
export function Parse(option: unknown): LuaTuple<[HotFlag | undefined, boolean, string | undefined]> {
	if (!typeIs(option, "string")) return $tuple(undefined, false, T("HotFlags.UseNameOnOrName"));
	const [name, value] = option.match("^%s*([%a]+)%s*=%s*(%a+)%s*$") as LuaTuple<[string | undefined, string | undefined]>;
	if (!IsFlag(name)) return $tuple(undefined, false, T("HotFlags.UnknownFlagFlagsTradingPausedCratesPaused"));
	const lowered = (value ?? "").lower();
	if (lowered !== "on" && lowered !== "off") return $tuple(undefined, false, T("HotFlags.UseNameOnOrName"));
	return $tuple(name, lowered === "on", undefined);
}

export function Snapshot(): Array<{ Name: string; On: boolean; Description: string }> {
	const out: Array<{ Name: string; On: boolean; Description: string }> = [];
	for (const [name, description] of pairs(FLAGS)) {
		out.push({ Name: name, On: state[name] === true, Description: description });
	}
	out.sort((a, b) => a.Name < b.Name);
	return out;
}

/** The stored form: every flag's value plus the stamp of the newest change. */
export function Encode(): { Flags: Record<string, boolean>; ChangedAt: number } {
	const flags: Record<string, boolean> = {};
	for (const [name] of pairs(FLAGS)) flags[name] = state[name] === true;
	return { Flags: flags, ChangedAt: changedAt };
}

/** Applies a stored state if it is newer than what this server has. Returns true when applied. */
export function Decode(raw: unknown): boolean {
	if (!typeIs(raw, "table")) return false;
	const bag = raw as { Flags?: unknown; ChangedAt?: unknown };
	const at = tonumber(bag.ChangedAt);
	if (at === undefined || at < changedAt || !typeIs(bag.Flags, "table")) return false;
	changedAt = at;
	for (const [name] of pairs(FLAGS)) state[name] = (bag.Flags as Record<string, unknown>)[name] === true;
	return true;
}

/** Merge for UpdateAsync: keeps whichever of stored and local is newer, so writes never go backwards. */
export function Merge(stored: unknown): { Flags: Record<string, boolean>; ChangedAt: number } {
	const storedAt = typeIs(stored, "table") ? tonumber((stored as { ChangedAt?: unknown }).ChangedAt) ?? -1 : -1;
	if (storedAt > changedAt) {
		Decode(stored);
	}
	return Encode();
}

/** Test hook: back to every flag off. */
export function Reset(): void {
	for (const [name] of pairs(state)) delete state[name];
	changedAt = 0;
}

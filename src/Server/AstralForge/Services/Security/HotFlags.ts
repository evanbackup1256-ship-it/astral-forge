// Live-ops kill switches an owner can flip from the admin panel without a deploy. Every flag
// defaults to off, so a server that never hears a change behaves exactly as before. Changes
// reach other live servers through the admin MessagingService topic; a server that starts
// later begins with every flag off.

export const FLAGS = table.freeze({
	TradingPaused: "New trades and settlements are refused.",
	CratesPaused: "Crate opening is refused.",
	AnnouncementsMuted: "Cross-server admin announcements are not shown in this server.",
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
	if (!typeIs(option, "string")) return $tuple(undefined, false, "Use Name=on or Name=off.");
	const [name, value] = option.match("^%s*([%a]+)%s*=%s*(%a+)%s*$") as LuaTuple<[string | undefined, string | undefined]>;
	if (!IsFlag(name)) return $tuple(undefined, false, "Unknown flag. Flags: TradingPaused, CratesPaused, AnnouncementsMuted.");
	const lowered = (value ?? "").lower();
	if (lowered !== "on" && lowered !== "off") return $tuple(undefined, false, "Use Name=on or Name=off.");
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

/** Test hook: back to every flag off. */
export function Reset(): void {
	for (const [name] of pairs(state)) delete state[name];
	changedAt = 0;
}

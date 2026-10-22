// One registry for every client-to-server action. Each entry says whether the action takes a
// payload and, once ported, the payload's schema; the schema is both the runtime check (run by
// RemoteFirewall after the generic shape limits) and the payload's TypeScript type (Payload<K>).
// The wire is unchanged: still the single `request(action, payload)` function and the action
// names in Protocol.Actions. An entry marked `legacy()` keeps its hand-written check in
// RemoteFirewall until it is ported; `Remotes` is keyed by every Protocol action, so adding an
// action without a registry entry is a compile error.
import Protocol from "../Protocol";

export type ActionName = keyof typeof Protocol.Actions;

// ---- schema combinators ----------------------------------------------------------------------

export interface Schema<T> {
	readonly check: (this: void, value: unknown) => string | undefined;
	/** phantom, never set; carries the decoded type for Infer<> */
	readonly _t?: T;
}
export type Infer<S> = S extends Schema<infer T> ? T : never;

function schema<T>(check: (this: void, value: unknown) => string | undefined): Schema<T> {
	return { check };
}

function finite(value: unknown): value is number {
	return typeIs(value, "number") && value === value && value !== math.huge && value !== -math.huge;
}

export const S = {
	str(min: number, max: number, reason: string): Schema<string> {
		return schema((v) => (typeIs(v, "string") && v.size() >= min && v.size() <= max ? undefined : reason));
	},
	num(min: number, max: number, reason: string): Schema<number> {
		return schema((v) => (finite(v) && v >= min && v <= max ? undefined : reason));
	},
	int(min: number, max: number, reason: string): Schema<number> {
		return schema((v) => (finite(v) && v >= min && v <= max && v % 1 === 0 ? undefined : reason));
	},
	bool(reason: string): Schema<boolean> {
		return schema((v) => (typeIs(v, "boolean") ? undefined : reason));
	},
	oneOf<const L extends ReadonlyArray<string>>(values: L, reason: string): Schema<L[number]> {
		const set = new Set<unknown>(values as ReadonlyArray<unknown>);
		return schema((v) => (set.has(v) ? undefined : reason));
	},
	/** dense 1..n array of strings, the same rule RemoteFirewallMath.StringArrayField uses */
	strList(maxEntries: number, min: number, max: number, reason: string): Schema<string[]> {
		return schema((v) => {
			if (!typeIs(v, "table")) return reason;
			const list = v as unknown[];
			let count = 0;
			for (const [index, entry] of pairs(v as object)) {
				count += 1;
				if (count > maxEntries) return reason;
				if (!typeIs(index, "number") || index % 1 !== 0 || index < 1 || index > list.size()) return reason;
				if (!typeIs(entry, "string") || entry.size() < min || entry.size() > max) return reason;
			}
			return count === list.size() ? undefined : reason;
		});
	},
	opt<T>(inner: Schema<T>): Schema<T | undefined> {
		return schema((v) => (v === undefined ? undefined : inner.check(v)));
	},
	/**
	 * A table with these fields. Extra keys are allowed (session keys such as TxnId ride along on
	 * every request); `refine` adds cross-field rules once every field has passed.
	 */
	obj<F extends Record<string, Schema<unknown>>>(
		fields: F,
		reason: string,
		refine?: (this: void, value: { [K in keyof F]: Infer<F[K]> }) => string | undefined,
	): Schema<{ [K in keyof F]: Infer<F[K]> }> {
		return schema((v) => {
			if (!typeIs(v, "table")) return reason;
			const bag = v as Record<string, unknown>;
			for (const [key, field] of pairs(fields as Record<string, Schema<unknown>>)) {
				const problem = field.check(bag[key]);
				if (problem !== undefined) return problem;
			}
			return refine !== undefined ? refine(v as never) : undefined;
		});
	},
};

// ---- entries ---------------------------------------------------------------------------------

export type Entry =
	| { readonly Kind: "none" }
	| { readonly Kind: "schema"; readonly Schema: Schema<unknown> }
	| { readonly Kind: "legacy" };

const none = { Kind: "none" } as const;
const legacy = { Kind: "legacy" } as const;
function payload<T>(s: Schema<T>) {
	return { Kind: "schema", Schema: s } as { readonly Kind: "schema"; readonly Schema: Schema<T> };
}

const FEEDBACK_CATEGORIES = ["Bug", "Suggestion", "Balance", "Performance", "Interface", "Other"] as const;

const definitions = {
	GetState: none,
	MeasureLatency: none,
	GetPlayers: none,
	GetTrade: none,
	ConfirmTrade: none,
	CancelTrade: none,
	GetAdminState: none,
	CollectVault: none,
	Overcharge: none,
	DomainExpansion: none,
	UpgradeContinuum: none,
	Ascend: none,
	ClaimDaily: none,
	ClaimExpedition: none,
	CompleteTutorial: none,
	ReplayTutorial: none,
	DismissRelease: none,
	OpenRelease: none,
	PulseAnomaly: none,
	StabilizeAnomaly: none,
	ActivateAnomalySurge: none,
	SyncShop: none,
	LeavePlot: none,
	GetGuild: none,
	LeaveGuild: none,
	DisbandGuild: none,
	ClaimGuildGoal: none,
	EquipBestItems: none,
	ClaimAllMail: none,
	VerifyCreatorFollow: none,
	GetCrew: none,
	CrewLeave: none,

	SubmitFeedback: payload(
		S.obj(
			{
				Category: S.str(3, 16, "invalid feedback"),
				Message: S.str(8, 600, "invalid feedback"),
			},
			"invalid feedback",
			(v) => {
				if (!new Set<unknown>(FEEDBACK_CATEGORIES).has(v.Category)) return "invalid feedback category";
				return S.obj(
					{
						Impact: S.opt(S.int(1, 5, "invalid feedback impact")),
						Device: S.opt(S.str(1, 16, "invalid feedback device")),
						Screen: S.opt(S.str(3, 16, "invalid feedback screen")),
						Page: S.opt(S.str(1, 32, "invalid feedback page")),
					},
					"invalid feedback",
				).check(v);
			},
		),
	),
	CompanionAct: payload(
		S.obj(
			{ Op: S.oneOf(["PickTrait"], "invalid companion action"), Trait: S.str(1, 24, "invalid companion action") },
			"invalid companion action",
		),
	),
	ExpeditionAct: payload(
		S.obj(
			{
				Op: S.oneOf(["Launch", "Claim", "Recall"], "invalid expedition action"),
				Slot: S.int(1, 5, "invalid expedition slot"),
			},
			"invalid expedition action",
			(v) =>
				v.Op !== "Launch"
					? undefined
					: S.obj(
							{
								Id: S.str(1, 48, "invalid expedition route"),
								Crew: S.opt(S.strList(3, 1, 32, "invalid expedition crew")),
							},
							"invalid expedition route",
						).check(v),
		),
	),
	ProgramAct: payload(
		S.obj(
			{
				Op: S.oneOf(["Save", "Toggle", "Delete"], "invalid program action"),
				Index: S.opt(S.int(1, 5, "invalid program index")),
			},
			"invalid program action",
			(v) => {
				if (v.Op !== "Save") return v.Index === undefined ? "invalid program index" : undefined;
				return S.obj(
					{
						Rule: S.obj(
							{
								When: S.str(1, 24, "invalid program rule"),
								Do: S.str(1, 24, "invalid program rule"),
								Arg: S.opt(S.num(0, 1000, "invalid program value")),
								Enabled: S.opt(S.bool("invalid program switch")),
							},
							"invalid program rule",
						),
					},
					"invalid program rule",
				).check(v);
			},
		),
	),
} satisfies Partial<Record<ActionName, Entry>>;

type Defined = typeof definitions;
type Rest = Exclude<ActionName, keyof Defined>;

// Everything not listed above keeps its RemoteFirewall check for now.
const rest = {} as Record<Rest, typeof legacy>;
for (const [name] of pairs(Protocol.Actions)) {
	if ((definitions as Record<string, Entry>)[name] === undefined) {
		(rest as Record<string, Entry>)[name] = legacy;
	}
}

export const Remotes: { readonly [K in ActionName]: K extends keyof Defined ? Defined[K] : typeof legacy } =
	table.freeze({ ...rest, ...definitions }) as never;

/** Decoded payload type for an action (undefined for no-payload and legacy actions). */
export type Payload<K extends ActionName> = (typeof Remotes)[K] extends { Kind: "schema"; Schema: Schema<infer T> }
	? T
	: undefined;

export function EntryFor(action: string): Entry | undefined {
	return (Remotes as Record<string, Entry | undefined>)[action];
}

export function TakesNoPayload(action: string): boolean {
	return EntryFor(action)?.Kind === "none";
}

/**
 * Runs the action's schema. Returns [true] for legacy entries (the caller still runs its own
 * check) and [false, reason] for unknown actions or a payload that fails the schema.
 */
export function Validate(action: string, value: unknown): LuaTuple<[boolean, string | undefined, boolean]> {
	const entry = EntryFor(action);
	if (entry === undefined) return $tuple(false, "unknown action", false);
	if (entry.Kind !== "schema") return $tuple(true, undefined, false);
	const problem = entry.Schema.check(value);
	return $tuple(problem === undefined, problem, true);
}

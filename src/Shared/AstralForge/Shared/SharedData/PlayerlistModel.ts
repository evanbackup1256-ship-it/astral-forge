type Dict = Record<string, unknown>;

interface OmegaLike {
	Gt?: (this: void, a: unknown, b: unknown) => unknown;
}

interface Artifact {
	Id: string;
	Name: string;
	Element: string;
	Rarity: string;
	Level: number;
	Color?: Color3;
	Effect?: string;
}

interface Row {
	UserId: number;
	Name: string;
	DisplayName: string;
	IsLocal: boolean;
	CurrentZone: number;
	Zone: number;
	Rebirths: number;
	Production: number | string;
	LifetimeCash: number | string;
	DomainRank: number;
	PlayTime: number;
	AccountAge: number;
	Premium: boolean;
	Shards: number;
	FoundryPieces: number;
	Artifact?: Artifact;
	CurrentPage: string;
}

const REASONS = table.freeze([
	{ id: "Exploiting", label: "Exploiting", detail: "Cheats, scripts or abusing glitches." },
	{ id: "Scamming", label: "Scamming", detail: "Tricked someone in a trade or promised something fake." },
	{ id: "Harassment", label: "Harassment", detail: "Targeting, bullying or threatening someone." },
	{ id: "Trolling", label: "Trolling", detail: "Ruining the game for others on purpose." },
	{ id: "Spam", label: "Spam", detail: "Flooding chat or invites." },
	{ id: "Inappropriate", label: "Inappropriate", detail: "Offensive name, avatar or messages." },
	{ id: "Impersonating", label: "Impersonating", detail: "Pretending to be staff, a creator or another player." },
	{ id: "Botting", label: "Botting", detail: "Looks automated: macros, AFK farms or alt swarms." },
	{ id: "Other", label: "Other", detail: "Something else. Add details below." },
]);

const SEVERITIES = table.freeze([
	{ id: "Minor", label: "Minor" },
	{ id: "Serious", label: "Serious" },
	{ id: "Urgent", label: "Urgent" },
]);

const WHENS = table.freeze([
	{ id: "Now", label: "Just now" },
	{ id: "Earlier", label: "Earlier" },
	{ id: "Repeated", label: "Keeps happening" },
]);

const WHERES = table.freeze([
	{ id: "World", label: "In world" },
	{ id: "Chat", label: "Chat" },
	{ id: "Trade", label: "Trade" },
	{ id: "Guild", label: "Guild" },
]);

const SORTS = table.freeze([
	{ id: "Production", label: "Output" },
	{ id: "Lifetime", label: "Lifetime" },
	{ id: "Rebirths", label: "Rebirths" },
	{ id: "Played", label: "Played" },
]);

const DETAILS_MAX = 400;
const SEARCH_MIN_ROWS = 6;

// Output comparisons go through OmegaMath when it is loadable (in game); plain numbers otherwise.
// (SharedData is a folder now, so OmegaMath is a sibling of the folder, not of this member.)
let omega: OmegaLike | false | undefined = undefined;
function omegaMath(): OmegaLike | undefined {
	if (omega === undefined) {
		const [ok, loaded] = pcall(() => require(script.Parent!.Parent!.WaitForChild("OmegaMath", 5) as ModuleScript));
		omega = ok && typeIs(loaded, "table") ? (loaded as OmegaLike) : false;
	}
	return omega === false ? undefined : omega;
}
function productionGreater(a: unknown, b: unknown): boolean {
	const math_ = omegaMath();
	if (math_ && math_.Gt) {
		const [ok, result] = pcall(math_.Gt, a, b);
		if (ok) {
			return result === true;
		}
	}
	return (tonumber(a) ?? 0) > (tonumber(b) ?? 0);
}
function productionEqual(a: unknown, b: unknown): boolean {
	return !productionGreater(a, b) && !productionGreater(b, a);
}
function num(value: unknown): number {
	if (typeIs(value, "number") && value === value) {
		return value;
	}
	return 0;
}

// big-number values (1e15 and up) arrive as encoded strings; keep them for formatting and sorting
function bigValue(value: unknown): number | string {
	if (typeIs(value, "number")) {
		return value === value ? value : 0;
	}
	if (typeIs(value, "string") && (value.match("^%-?%d+%.?%d*e%-?%d+$")[0] !== undefined || value === "inf")) {
		return value;
	}
	return 0;
}

function artifact(raw: unknown): Artifact | undefined {
	const r = raw as Dict;
	if (!typeIs(raw, "table") || !typeIs(r.Id, "string") || r.Id === "") {
		return undefined;
	}
	return {
		Id: r.Id,
		Name: typeIs(r.Name, "string") && r.Name !== "" ? r.Name : r.Id,
		Element: typeIs(r.Element, "string") ? r.Element : "",
		Rarity: typeIs(r.Rarity, "string") ? r.Rarity : "COMMON",
		Level: math.max(1, math.floor(num(r.Level))),
		Color: typeOf(r.Color) === "Color3" ? (r.Color as Color3) : undefined,
		Effect: typeIs(r.Effect, "string") ? r.Effect : undefined,
	};
}

// live attributes win over the polled record: they replicate the moment someone equips
function artifactOf(player: Instance | undefined, fallback: unknown): unknown {
	if (player === undefined) {
		return fallback;
	}
	const id = player.GetAttribute("EquippedArtifact");
	if (!typeIs(id, "string") || id === "") {
		return undefined;
	}
	return artifact({
		Id: id,
		Name: player.GetAttribute("EquippedArtifactName"),
		Element: player.GetAttribute("EquippedArtifactElement"),
		Rarity: player.GetAttribute("EquippedArtifactRarity"),
		Level: player.GetAttribute("EquippedArtifactLevel"),
		Color: player.GetAttribute("EquippedArtifactColor"),
		Effect: player.GetAttribute("EquippedArtifactEffect"),
	});
}

function clean(raw: unknown, skipUserId?: number): Row[] {
	const rows: Row[] = [];
	const seen: Record<number, boolean> = {};
	if (!typeIs(raw, "table")) {
		return rows;
	}
	for (const [, value] of pairs(raw as Dict)) {
		if (!typeIs(value, "table")) {
			continue;
		}
		const entry = value as Dict;
		let userId = tonumber(entry.UserId);
		if (userId === undefined || userId !== userId || userId <= 0) {
			continue;
		}
		userId = math.floor(userId);
		if (seen[userId] || userId === skipUserId) {
			continue;
		}
		seen[userId] = true;
		const name = typeIs(entry.Name, "string") && entry.Name !== "" ? entry.Name : tostring(userId);
		const production = entry.Production;
		rows.push({
			UserId: userId,
			Name: name,
			DisplayName: typeIs(entry.DisplayName, "string") && entry.DisplayName !== "" ? entry.DisplayName : name,
			IsLocal: entry.IsLocal === true,
			CurrentZone: math.max(1, num(entry.CurrentZone)),
			Zone: math.max(1, num(entry.Zone)),
			Rebirths: num(entry.Rebirths),
			// big-number output (Googol and up) arrives as an encoded value; keep it for formatting and sorting
			Production: bigValue(production),
			LifetimeCash: bigValue(entry.LifetimeCash),
			DomainRank: num(entry.DomainRank),
			PlayTime: num(entry.PlayTime),
			AccountAge: num(entry.AccountAge),
			Premium: entry.Premium === true,
			Shards: num(entry.Shards),
			FoundryPieces: num(entry.FoundryPieces),
			Artifact: artifact(entry.Artifact),
			CurrentPage: typeIs(entry.CurrentPage, "string") ? entry.CurrentPage : "",
		});
	}
	return rows;
}

function view(rows: Row[], sortId: string, query?: string, friendsOnly?: boolean, friends?: Record<number, boolean>): Row[] {
	const needle = (query ?? "").gsub("^%s*(.-)%s*$", "%1")[0].lower();
	const out: Row[] = [];
	for (const row of rows) {
		if (!row.IsLocal) {
			if (friendsOnly && !(friends && friends[row.UserId])) {
				continue;
			}
			if (
				needle !== "" &&
				row.DisplayName.lower().find(needle, 1, true)[0] === undefined &&
				row.Name.lower().find(needle, 1, true)[0] === undefined
			) {
				continue;
			}
		}
		out.push(row);
	}
	out.sort((left, right) => {
		if (left.IsLocal !== right.IsLocal) {
			return left.IsLocal;
		}
		return statBefore(left, right, sortId);
	});
	return out;
}

// the leaderboard order for one stat, ties broken by user id so ranks never jump between refreshes
function statBefore(left: Row, right: Row, sortId: string): boolean {
	if (sortId === "Name") {
		const a = left.DisplayName.lower();
		const b = right.DisplayName.lower();
		if (a !== b) {
			return a < b;
		}
	} else if (sortId === "Rebirths") {
		if (left.Rebirths !== right.Rebirths) {
			return left.Rebirths > right.Rebirths;
		}
	} else if (sortId === "Lifetime") {
		if (!productionEqual(left.LifetimeCash, right.LifetimeCash)) {
			return productionGreater(left.LifetimeCash, right.LifetimeCash);
		}
	} else if (sortId === "Played") {
		if (left.PlayTime !== right.PlayTime) {
			return left.PlayTime > right.PlayTime;
		}
	} else if (!productionEqual(left.Production, right.Production)) {
		return productionGreater(left.Production, right.Production);
	}
	return left.UserId < right.UserId;
}

// rank of every player on the server for one stat (the local row is pinned on top of the list,
// but its rank is its real place)
function ranks(rows: Row[], sortId: string): Record<number, number> {
	const ordered = [...rows];
	ordered.sort((left, right) => statBefore(left, right, sortId));
	const out: Record<number, number> = {};
	for (const [index, row] of ipairs(ordered)) {
		out[row.UserId] = index;
	}
	return out;
}

function playTime(seconds: number): string {
	const total = math.max(0, math.floor(num(seconds)));
	const hours = math.floor(total / 3600);
	const minutes = math.floor((total % 3600) / 60);
	if (hours > 0) {
		return "%dh %dm".format(hours, minutes);
	}
	if (minutes > 0) {
		return "%dm".format(minutes);
	}
	return "<1m";
}

function accountAge(days: number): string {
	const value = math.max(0, math.floor(num(days)));
	if (value >= 365) {
		return "%dy".format(math.floor(value / 365));
	}
	if (value >= 30) {
		return "%dmo".format(math.floor(value / 30));
	}
	return "%dd".format(value);
}

function details(text?: string): string {
	let trimmed = (text ?? "").gsub("^%s*(.-)%s*$", "%1")[0];
	if (trimmed.size() > DETAILS_MAX) {
		trimmed = trimmed.sub(1, DETAILS_MAX);
	}
	const [, brokenAt] = utf8.len(trimmed);
	if (brokenAt !== undefined) {
		trimmed = trimmed.sub(1, (brokenAt as number) - 1);
	}
	return trimmed;
}

export = table.freeze({
	REASONS,
	SEVERITIES,
	WHENS,
	WHERES,
	SORTS,
	ranks,
	DETAILS_MAX,
	SEARCH_MIN_ROWS,
	artifact,
	artifactOf,
	clean,
	view,
	playTime,
	accountAge,
	details,
});

// Shared display progression and permission policy. Existing membership data stays valid.
type Dict = Record<string, unknown>;

interface BigMath {
	Gte(this: void, a: unknown, b: unknown): boolean;
	Compare(this: void, a: unknown, b: unknown): number;
}

interface Member {
	Role?: string;
	JoinedAt?: unknown;
}

interface HallInfo {
	Level: number;
	Points: number;
	Progress: number;
	Remaining: number;
	Title: string;
}

export = (Math: BigMath) => {
	const roles: Record<string, number> = { Leader: 3, Officer: 2, Member: 1 };
	const Social = {
		canManage(this: void, actor: unknown, target: unknown, operation?: string): boolean {
			if (!typeIs(actor, "table") || !typeIs(target, "table")) {
				return false;
			}
			const a = roles[(actor as Member).Role as string] ?? 0;
			const b = roles[(target as Member).Role as string] ?? 0;
			if (operation === "Role") {
				return a === 3 && b > 0 && b < 3;
			}
			return a >= 2 && b > 0 && a > b;
		},

		successor(this: void, members: Record<string, Member> | undefined, departing: unknown): string | undefined {
			const candidates: { id: string; member: Member }[] = [];
			for (const [id, member] of pairs(members ?? {})) {
				if (id !== departing) {
					candidates.push({ id, member });
				}
			}
			candidates.sort((a, b) => {
				const ar = roles[a.member.Role as string] ?? 1;
				const br = roles[b.member.Role as string] ?? 1;
				if (ar !== br) {
					return ar > br;
				}
				const aj = tonumber(a.member.JoinedAt) ?? math.huge;
				const bj = tonumber(b.member.JoinedAt) ?? math.huge;
				if (aj !== bj) {
					return aj < bj;
				}
				return (tonumber(a.id) ?? math.huge) < (tonumber(b.id) ?? math.huge);
			});
			const first = candidates[0];
			return first && first.id;
		},

		hall(this: void, guild: { Upgrades?: Record<string, unknown> }): HallInfo {
			let points = 0;
			for (const [, level] of pairs(guild.Upgrades ?? {})) {
				if (typeIs(level, "number") && level === level && level > 0 && level < math.huge) {
					points += math.floor(level);
				}
			}
			const level = 1 + math.floor(points / 5);
			const title =
				level >= 13
					? "Astral Citadel"
					: level >= 7
						? "Starforge Hall"
						: level >= 4
							? "United Foundry"
							: level >= 2
								? "Growing Hall"
								: "New Charter";
			return { Level: level, Points: points, Progress: (points % 5) / 5, Remaining: 5 - (points % 5), Title: title };
		},

		rank(this: void, entries: unknown[] | undefined, guildBoard?: boolean): Dict[] {
			const rows: Dict[] = [];
			const seen = new Map<unknown, boolean>();
			for (const entry of entries ?? []) {
				if (typeIs(entry, "table")) {
					const e = entry as Dict;
					const id = guildBoard ? e.Id : tonumber(e.UserId);
					const value = guildBoard ? e.Activity : e.Value;
					const parsed = typeIs(value, "string") ? tonumber(value) : undefined;
					const valid =
						(typeIs(value, "number") && value === value && value >= 0 && value < math.huge) ||
						(typeIs(value, "string") &&
							parsed !== undefined &&
							parsed === parsed &&
							parsed >= 0 &&
							value.match("^[%d%.eE%+%-]+$")[0] !== undefined &&
							Math.Gte(value, 0));
					const validId = guildBoard
						? typeIs(id, "string") && id !== ""
						: typeIs(id, "number") && id === id && id > 0 && id < math.huge && id % 1 === 0;
					if (validId && !seen.get(id) && valid) {
						seen.set(id, true);
						const row = table.clone(e);
						row.UserId = guildBoard ? e.UserId : id;
						row.Value = value;
						rows.push(row);
					}
				}
			}
			rows.sort((a, b) => {
				const comparison = Math.Compare(a.Value, b.Value);
				if (comparison !== 0) {
					return comparison > 0;
				}
				return guildBoard ? (a.Id as string) < (b.Id as string) : (a.UserId as number) < (b.UserId as number);
			});
			return rows;
		},
	};
	return Social;
};

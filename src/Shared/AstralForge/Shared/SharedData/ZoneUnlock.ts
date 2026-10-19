interface ZoneLike {
	Id: number;
	Name: string;
	RequiredRebirths?: number;
	CoreCost?: number;
	Cost: unknown;
}

interface UnlockFlags {
	Unlocked: boolean;
	RebirthOk: boolean;
	CoresOk: boolean;
	CashOk: boolean;
	CanUnlock: boolean;
	IsNext: boolean;
}

function Flags(
	unlockedZone: number,
	rebirths: number,
	cores: number,
	cash: unknown,
	zone: ZoneLike,
	gteCash: (a: unknown, b: unknown) => boolean,
): UnlockFlags {
	const haveZone = math.max(0, math.floor(tonumber(unlockedZone) ?? 0));
	const haveRebirths = math.max(0, math.floor(tonumber(rebirths) ?? 0));
	const haveCores = math.max(0, tonumber(cores) ?? 0);
	const unlocked = haveZone >= zone.Id;
	const rebirthOk = haveRebirths >= (zone.RequiredRebirths ?? 0);
	const coresOk = haveCores >= (zone.CoreCost ?? 0);
	const cashOk = gteCash(cash, zone.Cost);
	const isNext = zone.Id === haveZone + 1;
	return {
		Unlocked: unlocked,
		RebirthOk: rebirthOk,
		CoresOk: coresOk,
		CashOk: cashOk,
		IsNext: isNext,
		CanUnlock: !unlocked && isNext && rebirthOk && coresOk && cashOk,
	};
}

function Evaluate(
	unlockedZone: number,
	rebirths: number,
	cores: number,
	cash: unknown,
	zoneId: number,
	zone: ZoneLike,
	cashLt: (a: unknown, b: unknown) => boolean,
): LuaTuple<[string, string | undefined]> {
	const haveZone = math.max(0, math.floor(tonumber(unlockedZone) ?? 0));
	const target = math.floor(tonumber(zoneId) ?? 0);
	if (target <= haveZone) {
		return $tuple("Travel", undefined);
	}
	if (target !== haveZone + 1) {
		return $tuple("Error", "Worlds must be unlocked in order.");
	}
	const haveRebirths = math.max(0, math.floor(tonumber(rebirths) ?? 0));
	if (haveRebirths < (zone.RequiredRebirths ?? 0)) {
		return $tuple("Error", "Requires %d rebirths.".format(zone.RequiredRebirths ?? 0));
	}
	const haveCores = math.max(0, tonumber(cores) ?? 0);
	if (haveCores < (zone.CoreCost ?? 0)) {
		return $tuple("Error", "Requires %d astral cores.".format(zone.CoreCost ?? 0));
	}
	if (cashLt(cash, zone.Cost)) {
		return $tuple("Error", "NEED_MORE_FLUX");
	}
	return $tuple("Unlock", undefined);
}

export = table.freeze({ Flags, Evaluate });

// Inline helper so the compiled output has no cross-module TS.import (keeps Lune tests working)
type Dict = Record<string, unknown>;
function isTable(value: unknown): value is Dict {
	return typeIs(value, "table");
}

const NUMERIC_KEYS = ["Revision", "SnapshotId", "ServerTime", "Cores", "Stardust", "Rebirths", "Zone", "CurrentZone"];
const PERSIST_KEYS = ["Cash", "Vault", "RunCash", "LifetimeCash", "Production", "Capacity"];
const TABLE_KEYS = ["Game", "Machines", "Research", "Wheel", "Daily", "TimedRewards", "Quests", "Settings", "Flags"];

export function IsFiniteNumber(value: unknown): value is number {
	if (!typeIs(value, "number")) {
		return false;
	}
	return value === value && value !== math.huge && value !== -math.huge;
}

export function IsPersist(value: unknown): boolean {
	if (IsFiniteNumber(value)) {
		return value >= 0;
	}
	if (!typeIs(value, "string") || value.size() === 0) {
		return false;
	}
	const lower = value.lower();
	if (lower === "inf" || lower === "infinity") {
		return true;
	}
	return value.match("^[%+%-]?%d+%.?%d*[eE][%+%-]?%d+$")[0] !== undefined || tonumber(value) !== undefined;
}

export function IsValidEnvelope(candidate: unknown): boolean {
	if (!isTable(candidate)) {
		return false;
	}
	for (const key of NUMERIC_KEYS) {
		if (!IsFiniteNumber(candidate[key])) {
			return false;
		}
	}
	for (const key of PERSIST_KEYS) {
		if (!IsPersist(candidate[key])) {
			return false;
		}
	}
	for (const key of TABLE_KEYS) {
		if (!typeIs(candidate[key], "table")) {
			return false;
		}
	}
	const revision = candidate.Revision;
	const snapshotId = candidate.SnapshotId;
	if (!typeIs(revision, "number") || revision < 0) {
		return false;
	}
	if (!typeIs(snapshotId, "number") || snapshotId < 0) {
		return false;
	}
	return true;
}

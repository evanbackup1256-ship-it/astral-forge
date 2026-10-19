export function Remaining(deadline: unknown, now: unknown): number {
	return math.max(0, (tonumber(deadline) ?? 0) - (tonumber(now) ?? 0));
}

export function IsLive(deadline: unknown, now: unknown): boolean {
	return Remaining(deadline, now) <= 0;
}

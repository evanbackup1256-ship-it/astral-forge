// Versioned codec for the mobile HUD editor's saved memory slots (M1-M3).
// Stored on the profile as a compact string so old saves without it decode to empty slots.

interface Entry {
	x: number;
	y: number;
}
type Memory = Record<string, Entry>;
type Slots = Record<number, Memory>;

const VERSION = "v1";
const SLOT_COUNT = 3;
const MAX_ENTRIES = 6;
const MAX_LENGTH = 512;

function validId(id: unknown): boolean {
	return typeIs(id, "string") && id.size() >= 1 && id.size() <= 12 && id.match("^%a+$")[0] !== undefined;
}

function unit(value: unknown): number | undefined {
	const num = tonumber(value);
	if (num === undefined || num !== num) {
		return undefined;
	}
	return math.clamp(num, 0, 1);
}

function Encode(slots: unknown): string {
	const parts: string[] = [VERSION];
	for (let index = 1; index <= SLOT_COUNT; index++) {
		const memory = typeIs(slots, "table") ? (slots as Record<number, unknown>)[index] : undefined;
		const entries: string[] = [];
		if (typeIs(memory, "table")) {
			const ids: string[] = [];
			for (const [id] of pairs(memory as Record<string, unknown>)) {
				if (validId(id)) {
					ids.push(id);
				}
			}
			ids.sort();
			for (const id of ids) {
				if (entries.size() >= MAX_ENTRIES) {
					break;
				}
				const entry = (memory as Record<string, unknown>)[id];
				const x = typeIs(entry, "table") ? unit((entry as Record<string, unknown>).x) : undefined;
				const y = typeIs(entry, "table") ? unit((entry as Record<string, unknown>).y) : undefined;
				if (x !== undefined && y !== undefined) {
					entries.push("%s:%.3f:%.3f".format(id, x, y));
				}
			}
		}
		parts.push(entries.join(","));
	}
	return parts.join("|");
}

function Decode(raw: unknown): Slots {
	const slots: Slots = {};
	if (!typeIs(raw, "string") || raw.size() > MAX_LENGTH) {
		return slots;
	}
	const parts = raw.split("|");
	if (parts[0] !== VERSION) {
		return slots;
	}
	for (let index = 1; index <= SLOT_COUNT; index++) {
		const chunk = parts[index] as string | undefined;
		if (chunk !== undefined && chunk !== "") {
			const memory: Memory = {};
			let count = 0;
			for (const item of chunk.split(",")) {
				const [id, x, y] = item.match("^(%a+):([%d%.]+):([%d%.]+)$");
				const ux = unit(x);
				const uy = unit(y);
				if (id !== undefined && validId(id) && ux !== undefined && uy !== undefined && count < MAX_ENTRIES) {
					memory[id as string] = { x: ux, y: uy };
					count += 1;
				}
			}
			if (count > 0) {
				slots[index] = memory;
			}
		}
	}
	return slots;
}

// Round-trips untrusted input so only canonical, bounded strings reach the save.
function Normalize(raw: unknown): string | undefined {
	if (!typeIs(raw, "string") || raw.size() > MAX_LENGTH) {
		return undefined;
	}
	const parts = raw.split("|");
	if (parts[0] !== VERSION) {
		return undefined;
	}
	return Encode(Decode(raw));
}

export = table.freeze({ VERSION, SLOT_COUNT, MAX_ENTRIES, MAX_LENGTH, Encode, Decode, Normalize });

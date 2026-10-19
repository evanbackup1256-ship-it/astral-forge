// Purpose: keep default crate models consistent between the shop and opening reveal.
// Owner: presentation. Dependencies: caller-provided crate definitions.
// Last-reviewed: 2026-10-06.

interface Definition {
	Id: string;
	ModelId?: string;
}

const DEFAULT_SKIN = "Classic";

const Appearance = {
	resolve(this: void, skinId: string | undefined, crateId: string | undefined, crates: Definition[]): string {
		const selected = skinId ?? DEFAULT_SKIN;
		if (selected !== DEFAULT_SKIN) {
			return selected;
		}
		for (const crate of crates) {
			if (crate.Id === crateId && crate.ModelId !== undefined && crate.ModelId !== "") {
				return crate.ModelId;
			}
		}
		return DEFAULT_SKIN;
	},
};

export = table.freeze(Appearance);

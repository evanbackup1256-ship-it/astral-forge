// Night Iron tokens for Forge2. Colours come from the live Palette (so High Contrast and Colorblind
// modes still recolour everything); this file only decides which palette entry plays which role.
import { Palette } from "../../CoreKit/theme";

export const Iron = {
	void: () => Palette.void,
	face: () => Palette.graphite,
	raised: () => Palette.panelRaised,
	sunk: () => Palette.ink,
	steel: () => Palette.steel,
	edge: () => Palette.lineSoft,
	brass: () => Palette.brass,
	brassDeep: () => Palette.brassDeep,
	ember: () => Palette.ember,
	text: () => Palette.cream,
	soft: () => Palette.creamSoft,
	muted: () => Palette.muted,
};

/** generous spacing: phones get the left value, desktop the right */
export function gap(phone: boolean, size: "s" | "m" | "l" | "xl"): number {
	const sizes = { s: [6, 8], m: [10, 14], l: [14, 22], xl: [18, 32] } as const;
	return sizes[size][phone ? 0 : 1];
}

export const Corner = { chip: 4, card: 6, panel: 8 };

export const Type = {
	hero: (phone: boolean) => (phone ? 34 : 52),
	title: (phone: boolean) => (phone ? 22 : 28),
	body: (phone: boolean) => (phone ? 15 : 17),
	small: (phone: boolean) => (phone ? 12 : 13),
};

/** smallest pressable edge; touch always gets the full 44px */
export const HIT = 44;

export const Fonts = {
	heavy: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
	bold: Font.fromEnum(Enum.Font.BuilderSansBold),
	body: Font.fromEnum(Enum.Font.BuilderSans),
};

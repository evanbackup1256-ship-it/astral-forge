import * as ForgeTheme from "../../../Shared/AstralForge/Shared/ForgeTheme";
import { planMobileLayout } from "./mobileLayout";

export {
	fitPanelHeight,
	fitTouchGridWidth,
	isMobileLandscape,
	moreDockHeight,
	planMobileLayout,
	scrollTail,
} from "./mobileLayout";

export const Palette = ForgeTheme.newPalette();

let accessibilitySignature = "";
export function applyAccessibilityTheme(highContrast?: boolean, colorblind?: boolean) {
	const signature = `${highContrast}:${colorblind}`;
	if (signature === accessibilitySignature) {
		return;
	}
	accessibilitySignature = signature;
	ForgeTheme.applyAccessibility(Palette, {
		HighContrast: highContrast === true,
		Colorblind: colorblind === true,
	});
}

export const Layout = {
	// spacing runs on a 4px grid with roomy defaults: whitespace separates things, not borders
	pagePadding: 24,
	topbarClearance: 8,
	minTopInset: 36,
	panelGap: 24,
	stackGap: 16,
	controlGap: 16,
	lineGap: 12,
	cardPadding: 24,
	cardRadius: 14,
	buttonRadius: 10,
	topbarHeight: 74,
	sidebarWidth: 268,
	sidebarCollapsedWidth: 78,
	rightRailWidth: 296,
	contentMinWidth: 620,
	contentInset: 24,
	workspaceHeaderHeight: 86,
	contentMaxWidth: 1680,
	maxShellWidth: 3440,
	referenceWidth: 1920,
	referenceHeight: 1080,
	minScale: 0.75,
	maxScale: 1,
	chromeScale: 1,
};

/** Shared shape tokens: every kit surface takes its radius, stroke and inner padding from here. */
// Three radii, used everywhere: sm for chips, badges and bars; md for buttons, inputs and
// small tiles; lg for cards, panels and sheets. Fully round pills use UDim(1, 0).
export const Radius = {
	sm: 6,
	md: 10,
	lg: 14,
	chip: 6,
	control: Layout.buttonRadius,
	card: Layout.cardRadius,
	sheet: 18,
} as const;

export const StrokeWidth = {
	hairline: 1,
	focus: 2,
} as const;

export const Pad = {
	tight: 8,
	control: 14,
	panel: 22,
	panelMax: 28,
} as const;

/**
 * Spacing scale (uirevamp 01). Everything snaps to these; pick by role, not by pixel count.
 * hair 2 · xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32 · section 48
 */
export const Space = {
	hair: 2,
	xs: 4,
	sm: 8,
	md: 12,
	lg: 16,
	xl: 24,
	xxl: 32,
	section: 48,
} as const;

/**
 * Type scale (uirevamp 01): a 1.2 ratio from a 13px body. Display and title use FancyText for
 * headings; everything else is BuilderSans. Numbers use the same faces with tabular intent.
 */
const TypeScale = {
	micro: { size: 11, weight: Enum.FontWeight.Bold },
	label: { size: 12, weight: Enum.FontWeight.SemiBold },
	body: { size: 14, weight: Enum.FontWeight.Medium },
	lead: { size: 16, weight: Enum.FontWeight.SemiBold },
	title: { size: 20, weight: Enum.FontWeight.Bold },
	heading: { size: 24, weight: Enum.FontWeight.Bold },
	display: { size: 34, weight: Enum.FontWeight.Heavy },
} as const;

/**
 * The "forged plate" look: a panel is a slab with a cool 1px bevel catching light on its top edge,
 * a darker foot, and depth from a wide soft shadow instead of outlines.
 */
export const Bevel = {
	topLight: 0.9,
	topLightHot: 0.78,
	footShade: 0.82,
} as const;

/** One subtle elevation: a soft ambient shadow. The key shadow is kept for API shape but is invisible. */
export const Elevation = {
	ambientSpread: 12,
	ambientOffset: 8,
	ambientAlpha: 0.8,
	keyOffset: 4,
	keyAlpha: 1,
} as const;

export const Chrome = {
	// flatter, quieter chrome: edges are barely there at rest and firm up on hover/focus only
	panelShadow: 1,
	panelStrokeIdle: 0.78,
	panelStrokeHover: 0.45,
	buttonShadow: 0.82,
	railStrokeIdle: 1,
	railStrokeActive: 0.55,
	accentHairline: 0.45,
	meterTrack: 0.3,
};

export const Breakpoints = {
	tight: 840,
	compact: 1100,
	short: 740,
};

export const TapTarget = 44;

export function mobileChrome(
	compact: boolean,
	tight: boolean,
	short = false,
	width = 1280,
	height = 720,
	bottomInset = 0,
	sideInset = 0,
	desktop = false,
	orientationWidth = width,
	orientationHeight = height,
) {
	const plan = planMobileLayout({
		width,
		height,
		compact,
		tight,
		short,
		bottomInset,
		sideInset,
		desktop,
		orientationWidth,
		orientationHeight,
	});
	return {
		mobile: plan.mobile,
		stack: plan.stack,
		contentStack: plan.contentStack,
		landscape: plan.landscape,
		portrait: plan.portrait,
		tablet: plan.tablet,
		compact,
		tight,
		short,
		pagePadding: plan.pagePadding,
		contentInset: plan.contentInset,
		cardPadding: plan.cardPadding,
		panelGap: plan.panelGap,
		controlGap: plan.controlGap,
		railRow: plan.railRow,
		railCollapsedRow: plan.railCollapsedRow,
		railGap: plan.railGap,
		bodyText: plan.bodyText,
		labelText: plan.labelText,
		titleText: plan.titleText,
		bottomSafe: plan.bottomSafe,
		sideSafe: plan.sideSafe,
		topbarRows: plan.topbarRows,
		moreCols: plan.moreCols,
		moreCellH: plan.moreCellH,
		moreDockH: plan.moreDockH,
		workspaceHeaderH: plan.workspaceHeaderH,
		quickBarH: plan.quickBarH,
		contentBudget: plan.contentBudget,
		tabBarH: plan.tabBarH,
		tabBarSlots: plan.tabBarSlots,
		tenFoot: false,
	};
}

export type MobileChrome = ReturnType<typeof mobileChrome>;

export interface ChromeViewport {
	compact: boolean;
	tight: boolean;
	short: boolean;
	width: number;
	height: number;
	bottomInset?: number;
	sideInset?: number;
	desktop?: boolean;
	screenWidth?: number;
	screenHeight?: number;
	tenFoot?: boolean;
}

export function chromeFor(viewport: ChromeViewport): MobileChrome {
	const chrome = mobileChrome(
		viewport.compact,
		viewport.tight,
		viewport.short,
		viewport.width,
		viewport.height,
		viewport.bottomInset ?? 0,
		viewport.sideInset ?? 0,
		viewport.desktop ?? false,
		viewport.screenWidth ?? viewport.width,
		viewport.screenHeight ?? viewport.height,
	);
	chrome.tenFoot = viewport.tenFoot === true;
	return chrome;
}

export function lighten(color: Color3, amount: number): Color3 {
	return color.Lerp(Palette.white, math.clamp(amount, 0, 1));
}

export function darken(color: Color3, amount: number): Color3 {
	return color.Lerp(Palette.shadow, math.clamp(amount, 0, 1));
}

function linearChannel(channel: number): number {
	return channel <= 0.04045 ? channel / 12.92 : math.pow((channel + 0.055) / 1.055, 2.4);
}

export function relativeLuminance(color: Color3): number {
	return linearChannel(color.R) * 0.2126 + linearChannel(color.G) * 0.7152 + linearChannel(color.B) * 0.0722;
}

export function contrastRatio(first: Color3, second: Color3): number {
	const a = relativeLuminance(first);
	const b = relativeLuminance(second);
	return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

// whichever of the light and dark text colours reads better. (Light and dark break even around a
// luminance of 0.18, not 0.45: mid-tone fills like sky blue, pink or gold need dark text.)
export function contrastOn(background: Color3): Color3 {
	return contrastRatio(background, Palette.ink) > contrastRatio(background, Palette.cream) ? Palette.ink : Palette.cream;
}

// keep the preferred colour if it reads; otherwise tint it toward whichever end reads better,
// and if even the tint fails, use that end outright
export function ensureContrast(background: Color3, preferred: Color3, minimum = 4.5): Color3 {
	if (contrastRatio(background, preferred) >= minimum) {
		return preferred;
	}
	const towards = contrastOn(background);
	const tinted = preferred.Lerp(towards, 0.62);
	if (contrastRatio(background, tinted) >= minimum) {
		return tinted;
	}
	return towards;
}

export function surfaceGradient(base: Color3, strength = 1): ColorSequence {
	// a smooth fall from a soft top light to a deeper base; no hard band at the top edge (a band
	// in the first few pixels read as a stray line on dark buttons and cards)
	return new ColorSequence([
		// nearly flat: just enough falloff that a surface doesn't read as a sticker
		new ColorSequenceKeypoint(0, lighten(base, 0.03 * strength)),
		new ColorSequenceKeypoint(0.5, base),
		new ColorSequenceKeypoint(1, darken(base, 0.06 * strength)),
	]);
}

export function strokeGradient(color: Color3): ColorSequence {
	return new ColorSequence([
		new ColorSequenceKeypoint(0, lighten(color, 0.12)),
		new ColorSequenceKeypoint(0.5, color),
		new ColorSequenceKeypoint(1, darken(color, 0.18)),
	]);
}

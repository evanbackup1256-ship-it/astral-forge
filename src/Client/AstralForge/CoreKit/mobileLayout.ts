const TAP_TARGET = 48;
const MORE_COUNT = 10;

export function isMobileLandscape(width: number, height: number, _compact?: boolean, _tight?: boolean): boolean {
	return width > height && height < 700;
}

export function fitPanelHeight(desired: number, budget: number, minH = 96, maxShare = 0.55): number {
	const cap = math.max(minH, math.floor(budget * maxShare));
	return math.clamp(desired, minH, cap);
}

export function moreDockHeight(stack: boolean, count = MORE_COUNT, cols = 4, cellH = TAP_TARGET, gap = 6): number {
	if (!stack) {
		return TAP_TARGET + 8;
	}
	const safeCols = math.max(1, cols);
	const rows = math.max(1, math.ceil(math.max(1, count) / safeCols));
	return rows * (cellH + math.clamp(gap, 2, 12)) + 18;
}

export function fitTouchGridWidth(viewportWidth: number, edgePad: number, sideSafe: number, cols: number, gap: number, scale: number): number {
	const available = math.max(180, viewportWidth - math.max(edgePad, sideSafe) * 2);
	const minimum = math.max(1, cols) * (TAP_TARGET + math.max(0, gap)) + 10;
	return math.min(available, math.max(minimum, available * math.clamp(scale, 0, 1)));
}

export function scrollTail(stack: boolean, bottomSafe: number, base = 40): number {
	if (!stack) {
		return base;
	}
	return base + math.max(bottomSafe, 12) + 28;
}

export interface MobileLayoutInput {
	width: number;
	height: number;
	compact?: boolean;
	tight?: boolean;
	short?: boolean;
	desktop?: boolean;
	orientationWidth?: number;
	orientationHeight?: number;
	bottomInset?: number;
	sideInset?: number;
}

export interface MobileLayoutPlan {
	mobile: boolean;
	stack: boolean;
	contentStack: boolean;
	landscape: boolean;
	portrait: boolean;
	tablet: boolean;
	pagePadding: number;
	contentInset: number;
	cardPadding: number;
	panelGap: number;
	controlGap: number;
	railRow: number;
	railCollapsedRow: number;
	railGap: number;
	bodyText: number;
	labelText: number;
	titleText: number;
	bottomSafe: number;
	sideSafe: number;
	topbarRows: number;
	moreCols: number;
	moreCellH: number;
	moreDockH: number;
	workspaceHeaderH: number;
	quickBarH: number;
	contentBudget: number;
	tabBarH: number;
	tabBarSlots: number;
}

let planCache: MobileLayoutPlan | undefined;
// numeric fields start as false so nothing matches until the first plan is made
const planKey: {
	width: number | false;
	height: number | false;
	compact: boolean;
	tight: boolean;
	short: boolean;
	desktop: boolean;
	orientationWidth: number | false;
	orientationHeight: number | false;
	bottomInset: number | false;
	sideInset: number | false;
} = {
	width: false,
	height: false,
	compact: false,
	tight: false,
	short: false,
	desktop: false,
	orientationWidth: false,
	orientationHeight: false,
	bottomInset: false,
	sideInset: false,
};

function quantize(value: unknown): number {
	if (!typeIs(value, "number") || value !== value || value === math.huge || value === -math.huge) {
		return 0;
	}
	return math.floor(value + 0.5);
}

export function planMobileLayout(input: MobileLayoutInput): MobileLayoutPlan {
	let width = quantize(input.width);
	let height = quantize(input.height);
	const orientationWidth = quantize(input.orientationWidth ?? input.width);
	const orientationHeight = quantize(input.orientationHeight ?? input.height);
	const bottomInset = quantize(math.max(0, input.bottomInset ?? 0));
	const sideInset = quantize(input.sideInset ?? 0);
	const compact = input.compact === true;
	const tight = input.tight === true;
	const short = input.short === true;
	const desktop = input.desktop === true;
	if (
		planCache !== undefined &&
		planKey.width === width &&
		planKey.height === height &&
		planKey.compact === compact &&
		planKey.tight === tight &&
		planKey.short === short &&
		planKey.desktop === desktop &&
		planKey.orientationWidth === orientationWidth &&
		planKey.orientationHeight === orientationHeight &&
		planKey.bottomInset === bottomInset &&
		planKey.sideInset === sideInset
	) {
		return planCache;
	}
	const narrow = orientationWidth < 840 || orientationHeight < 500;
	const mobile = narrow || (!desktop && (compact || tight || short));
	const stack =
		narrow ||
		(!desktop &&
			(tight ||
				(compact && short) ||
				(compact && orientationHeight <= orientationWidth * 1.05 && orientationWidth < 980)));
	const physicallyShortSurface = !desktop && stack && orientationHeight < 420;
	const landscape = !desktop && (isMobileLandscape(orientationWidth, orientationHeight, compact, tight) || physicallyShortSurface);
	const portrait = stack && !landscape;
	const phone = stack;
	const tablet = phone && width >= 700 && !landscape;
	const shortDesktop = desktop && (short || orientationHeight < 740);
	const topbarRows = !phone ? (shortDesktop ? 56 : 74) : landscape ? 44 : tablet ? 52 : 48;
	const bottomSafe = landscape ? math.max(10, bottomInset) : phone ? math.max(bottomInset, 6) : math.max(8, bottomInset);
	const sideSafe = landscape ? math.max(sideInset, 16) : phone ? math.max(sideInset, 12) : math.max(0, sideInset);
	const panelGap = landscape ? 10 : phone ? 14 : shortDesktop ? 14 : 18;
	const pagePadding = landscape ? 10 : phone ? (tablet ? 18 : 14) : shortDesktop || compact ? 16 : 20;
	const contentInset = landscape ? 10 : phone ? (tablet ? 18 : 14) : shortDesktop || compact ? 16 : 20;
	const workspaceHeaderH = phone ? 0 : shortDesktop ? 62 : 86;
	const tabBarCore = landscape ? TAP_TARGET : tablet ? 56 : 52;
	const tabBarH = phone ? tabBarCore + bottomSafe : 0;
	const tabBarSlots = phone ? math.max(3, math.min(6, math.floor((width - sideSafe * 2) / 64))) : 0;
	const moreCols = landscape ? 5 : 4;
	const moreCellH = landscape ? 50 : tablet ? 58 : 54;
	const moreDockH = phone ? moreDockHeight(true, 8, moreCols, moreCellH, landscape ? 6 : 8) : 0;
	const quickBarH = 0;
	const chromeReserve = topbarRows + (phone ? tabBarH + panelGap : 20) + workspaceHeaderH;
	const contentBudget = math.max(1, height - chromeReserve - 4);
	planKey.width = width;
	planKey.height = height;
	planKey.compact = compact;
	planKey.tight = tight;
	planKey.short = short;
	planKey.desktop = desktop;
	planKey.orientationWidth = orientationWidth;
	planKey.orientationHeight = orientationHeight;
	planKey.bottomInset = bottomInset;
	planKey.sideInset = sideInset;
	planCache = {
		mobile,
		stack,
		contentStack: stack,
		landscape,
		portrait,
		tablet,
		pagePadding,
		contentInset,
		cardPadding: landscape ? 14 : phone ? (tablet ? 18 : 16) : shortDesktop ? 16 : 20,
		panelGap,
		controlGap: landscape ? 10 : phone ? 12 : 16,
		railRow: landscape ? 52 : phone ? 60 : shortDesktop || compact ? 52 : 64,
		railCollapsedRow: landscape ? 48 : phone ? 54 : shortDesktop || compact ? 48 : 56,
		railGap: phone ? 8 : compact ? 10 : 12,
		bodyText: landscape ? 14 : phone ? 15 : 16,
		labelText: landscape ? 12 : phone ? 13 : 14,
		titleText: landscape ? 17 : phone ? (tablet ? 20 : 18) : shortDesktop ? 24 : 26,
		bottomSafe,
		sideSafe,
		topbarRows,
		moreCols,
		moreCellH,
		moreDockH,
		workspaceHeaderH,
		quickBarH,
		contentBudget,
		tabBarH,
		tabBarSlots,
	};
	return planCache;
}

export const EDIT_BOUNDS = Color3.fromRGB(72, 190, 255);

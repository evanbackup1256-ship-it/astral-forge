// Pure emulation of how the Roblox UI engine turns UDim2 + modifiers into absolute pixels.
// Sources (see docs/layoutguard-research.md): GuiObject.Position/Size/AnchorPoint/SizeConstraint,
// UIPadding, UIScale, UIAspectRatioConstraint, UISizeConstraint and UITextSizeConstraint docs.
//
// Quirks we reproduce on purpose:
//  - AbsolutePosition is always the top-left corner, whatever the AnchorPoint (DevForum 771689).
//  - Scale in Size/Position resolves against the parent's content box (after UIPadding).
//  - SizeConstraint RelativeXX / RelativeYY resolve both scale components against one axis.
//  - UIScale multiplies the absolute size of its parent and everything under it, about the
//    parent's anchor point; descendants' AbsoluteSize already include it.
//  - UIAspectRatioConstraint overrides a list/grid layout's size for that element.
import { Insets, Rect, Vec, fromPosSize, isFiniteNumber } from "./geom";

export interface UDimV {
	scale: number;
	offset: number;
}

export interface UDim2V {
	xs: number;
	xo: number;
	ys: number;
	yo: number;
}

export type SizeConstraintKind = "XY" | "XX" | "YY";
export type AspectTypeKind = "FitWithinMaxSize" | "ScaleWithParentSize";
export type DominantAxisKind = "Width" | "Height";

export interface AspectSpec {
	ratio: number;
	aspectType: AspectTypeKind;
	dominant: DominantAxisKind;
}

export interface SizeLimits {
	minX: number;
	minY: number;
	maxX: number;
	maxY: number;
}

export interface PaddingSpec {
	left: UDimV;
	top: UDimV;
	right: UDimV;
	bottom: UDimV;
}

export function udim(scale: number, offset: number): UDimV {
	return { scale, offset };
}

export function udim2(xs: number, xo: number, ys: number, yo: number): UDim2V {
	return { xs, xo, ys, yo };
}

export function fromScale(xs: number, ys: number): UDim2V {
	return { xs, xo: 0, ys, yo: 0 };
}

export function fromOffset(xo: number, yo: number): UDim2V {
	return { xs: 0, xo, ys: 0, yo };
}

export function resolveUDim(u: UDimV, length: number): number {
	return u.scale * length + u.offset;
}

/** Size of an element inside a parent content box, honouring GuiObject.SizeConstraint. */
export function resolveSize(size: UDim2V, parentW: number, parentH: number, constraint: SizeConstraintKind = "XY"): Vec {
	let baseX = parentW;
	let baseY = parentH;
	if (constraint === "XX") {
		baseY = parentW;
	} else if (constraint === "YY") {
		baseX = parentH;
	}
	return { x: size.xs * baseX + size.xo, y: size.ys * baseY + size.yo };
}

/** Position of the anchor point in parent content-box coordinates. */
export function resolvePosition(position: UDim2V, parentW: number, parentH: number): Vec {
	return { x: position.xs * parentW + position.xo, y: position.ys * parentH + position.yo };
}

/** Top-left corner from the anchor position, the anchor point and the final size. */
export function topLeftFromAnchor(anchorPos: Vec, anchor: Vec, size: Vec): Vec {
	return { x: anchorPos.x - anchor.x * size.x, y: anchorPos.y - anchor.y * size.y };
}

/** The anchor point's absolute location for an element whose top-left is known. */
export function anchorWorld(topLeft: Vec, anchor: Vec, size: Vec): Vec {
	return { x: topLeft.x + anchor.x * size.x, y: topLeft.y + anchor.y * size.y };
}

/** UIPadding: horizontal scale resolves against width, vertical against height. */
export function resolvePadding(p: PaddingSpec | undefined, w: number, h: number): Insets {
	if (p === undefined) {
		return { left: 0, top: 0, right: 0, bottom: 0 };
	}
	return {
		left: resolveUDim(p.left, w),
		top: resolveUDim(p.top, h),
		right: resolveUDim(p.right, w),
		bottom: resolveUDim(p.bottom, h),
	};
}

export function clampSize(size: Vec, limits: SizeLimits | undefined): Vec {
	if (limits === undefined) {
		return size;
	}
	const maxX = limits.maxX > 0 ? limits.maxX : math.huge;
	const maxY = limits.maxY > 0 ? limits.maxY : math.huge;
	// UISizeConstraint: MinSize wins when it exceeds MaxSize, so apply the max first, then the min
	return {
		x: math.max(limits.minX, math.min(size.x, maxX)),
		y: math.max(limits.minY, math.min(size.y, maxY)),
	};
}

/**
 * UIAspectRatioConstraint. FitWithinMaxSize: largest box of the ratio inside the computed size.
 * ScaleWithParentSize: the dominant axis keeps its computed length and the other follows the
 * ratio; if that would exceed the parent on the other axis, it is fitted into the parent.
 */
export function applyAspect(size: Vec, spec: AspectSpec | undefined, parentW: number, parentH: number): Vec {
	if (spec === undefined || !(spec.ratio > 0) || !isFiniteNumber(spec.ratio)) {
		return size;
	}
	const r = spec.ratio;
	if (spec.aspectType === "FitWithinMaxSize") {
		if (size.y <= 0) {
			return { x: 0, y: 0 };
		}
		if (size.x / size.y > r) {
			return { x: size.y * r, y: size.y };
		}
		return { x: size.x, y: size.x / r };
	}
	let w: number;
	let h: number;
	if (spec.dominant === "Width") {
		w = size.x;
		h = w / r;
		if (parentH > 0 && h > parentH) {
			h = parentH;
			w = h * r;
		}
	} else {
		h = size.y;
		w = h * r;
		if (parentW > 0 && w > parentW) {
			w = parentW;
			h = w / r;
		}
	}
	return { x: w, y: h };
}

/** UITextSizeConstraint clamp; MaxTextSize 0 means unbounded. */
export function clampTextSize(size: number, minSize: number, maxSize: number): number {
	const hi = maxSize > 0 ? maxSize : math.huge;
	return math.clamp(size, math.min(minSize, hi), hi);
}

export interface ElementSpec {
	position: UDim2V;
	size: UDim2V;
	anchor: Vec;
	sizeConstraint?: SizeConstraintKind;
	aspect?: AspectSpec;
	limits?: SizeLimits;
	/** product of UIScale values applied from this element upward (1 = none) */
	scale?: number;
}

/**
 * Full placement of a free (not layout-owned) element in a parent's content box.
 * `content` is the parent's absolute content rect (after UIPadding). Returns the absolute rect.
 */
export function placeElement(spec: ElementSpec, content: Rect): Rect {
	const pw = content.x1 - content.x0;
	const ph = content.y1 - content.y0;
	let size = resolveSize(spec.size, pw, ph, spec.sizeConstraint ?? "XY");
	size = clampSize(size, spec.limits);
	size = applyAspect(size, spec.aspect, pw, ph);
	const s = spec.scale ?? 1;
	const anchorPos = resolvePosition(spec.position, pw, ph);
	const scaled = { x: size.x * s, y: size.y * s };
	const tl = topLeftFromAnchor(anchorPos, spec.anchor, scaled);
	return fromPosSize(content.x0 + tl.x, content.y0 + tl.y, scaled.x, scaled.y);
}

/**
 * Inverse: given the measured absolute rect of an element and its parent content rect, recover the
 * Position UDim2 offset that would place it there with the same scale part. Used to propose fixes
 * (suggested offsets in reports) without writing to the Instance.
 */
export function offsetForTopLeft(spec: ElementSpec, content: Rect, desiredTopLeft: Vec, absSize: Vec): UDim2V {
	const pw = content.x1 - content.x0;
	const ph = content.y1 - content.y0;
	const anchorX = desiredTopLeft.x - content.x0 + spec.anchor.x * absSize.x;
	const anchorY = desiredTopLeft.y - content.y0 + spec.anchor.y * absSize.y;
	return {
		xs: spec.position.xs,
		xo: math.round(anchorX - spec.position.xs * pw),
		ys: spec.position.ys,
		yo: math.round(anchorY - spec.position.ys * ph),
	};
}

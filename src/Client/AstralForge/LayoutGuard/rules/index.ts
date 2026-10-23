// Rule registry. Order matters only for log readability (structural problems first).
import { Rule } from "../types";
import { ActionCollision, ContentOverlap } from "./overlap";
import { ClippedContent, Occlusion, OutOfParent } from "./clipping";
import { TextOverflow, TextTooSmall } from "./text";
import { SafeArea, TargetSpacing, TouchTarget, ViewportOverflow } from "./touch";
import { ColumnImbalance, EmptyBand, LowFill } from "./whitespace";
import { GutterInconsistency, Misalignment } from "./alignment";
import { FocusDeadLink, FocusOrder, FocusUnreachable } from "./focus";
import { CanvasOverflow, DisabledScroll, InvalidGeometry, NestedScroll } from "./scroll";

export const RULES: ReadonlyArray<Rule> = [
	InvalidGeometry,
	ViewportOverflow,
	SafeArea,
	ClippedContent,
	OutOfParent,
	ActionCollision,
	Occlusion,
	ContentOverlap,
	TextOverflow,
	TextTooSmall,
	TouchTarget,
	TargetSpacing,
	CanvasOverflow,
	NestedScroll,
	DisabledScroll,
	FocusDeadLink,
	FocusOrder,
	FocusUnreachable,
	EmptyBand,
	LowFill,
	ColumnImbalance,
	Misalignment,
	GutterInconsistency,
];

export const RULE_BY_ID = new Map<string, Rule>();
for (const r of RULES) RULE_BY_ID.set(r.id, r);

/** Rules the device matrix re-runs per phone: geometry-only, no whitespace taste rules. */
export const MATRIX_RULES: ReadonlyArray<string> = [
	"ViewportOverflow",
	"SafeArea",
	"ClippedContent",
	"ActionCollision",
	"ContentOverlap",
	"TextOverflow",
	"TextTooSmall",
	"TouchTarget",
	"CanvasOverflow",
];

/** Old rule ids (the 1.x guard) mapped to the new ones, so existing suppression attributes keep working. */
export const LEGACY_IDS: ReadonlyMap<string, string> = new Map([
	["SmallTouchTarget", "TouchTarget"],
	["ActionOutsideViewport", "ViewportOverflow"],
	["ClippedAction", "ClippedContent"],
	["ActionOutsideParent", "OutOfParent"],
	["TextCollision", "ContentOverlap"],
	["StackCollision", "ContentOverlap"],
	["NestedScrollConflict", "NestedScroll"],
]);

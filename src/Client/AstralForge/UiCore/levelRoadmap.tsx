import React from "@rbxts/react";
import { compactNumber } from "../CoreKit/format";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { Palette, TapTarget, chromeFor } from "../CoreKit/theme";
import { joinTuple } from "../lua";
import { ScaleFromCenter, composePresence, useEntrance, useExitTransition, useViewport } from "../MotionKit/motion";
import { Button, OverlayPresence, Text, pixelPosition, useGamepadAutofocus, useGuiSize } from "./ui";

const ContextActionService = game.GetService("ContextActionService");
const UserInputService = game.GetService("UserInputService");
const AstralForge = script.Parent!.Parent!;
const Audio = (require(AstralForge.WaitForChild("AudioKit") as ModuleScript) as (name: string) => {
	Audio: { play(cue: string, energy?: number): void };
})("audio").Audio;

const UNIT = 4;
const ROW_H = 54;
const TIER_H = 44;
const RAIL_X = 14;
const TEXT_X = 40;

const TIER_ACCENT_KEYS: Record<string, string> = {
	Beginner: "mint",
	Apprentice: "cyan",
	Journeyman: "blue",
	Expert: "violet",
	Master: "mango",
	Legend: "pink",
};

export interface NextStep {
	Progress?: unknown;
	Target?: unknown;
	Text?: string;
	Unlocks?: unknown;
	[key: string]: unknown;
}
interface LevelDef {
	Level: number;
	Tier?: string;
	Goal?: { Text?: unknown };
	Unlocks?: unknown;
}
type RoadmapState = { Level?: unknown; FeatureUnlocks?: unknown } | undefined;

export function tierAccent(tier: unknown): Color3 {
	const key = typeIs(tier, "string") ? TIER_ACCENT_KEYS[tier] : undefined;
	return key !== undefined ? ((Palette as unknown as Record<string, Color3>)[key] as Color3) : Palette.cyan;
}

export function featureNames(state: RoadmapState, ids: unknown): string[] {
	const names: string[] = [];
	if (!typeIs(ids, "table")) {
		return names;
	}
	const unlocks = state !== undefined ? state.FeatureUnlocks : undefined;
	for (const id of ids as unknown[]) {
		const row = typeIs(unlocks, "table") ? (unlocks as Record<string, unknown>)[id as string] : undefined;
		const name = typeIs(row, "table") ? (row as { Name?: unknown }).Name : undefined;
		names.push(typeIs(name, "string") ? name : tostring(id));
	}
	return names;
}

export function joinNames(names: string[]): string {
	const count = names.size();
	if (count === 0) {
		return "";
	} else if (count === 1) {
		return names[0];
	}
	const head: string[] = [];
	for (let i = 0; i < count - 1; i++) {
		head.push(names[i]);
	}
	return head.join(", ") + " and " + names[count - 1];
}

export function readLevelState(state: RoadmapState): LuaTuple<[number, string, NextStep | undefined]> {
	const levelState = state !== undefined ? state.Level : undefined;
	if (!typeIs(levelState, "table")) {
		return $tuple(1, "Beginner", undefined);
	}
	const ls = levelState as { Level?: unknown; Tier?: unknown; Next?: unknown };
	const level = typeIs(ls.Level, "number") ? math.max(1, math.floor(ls.Level)) : 1;
	const tier = typeIs(ls.Tier, "string") ? ls.Tier : "Beginner";
	const nextStep = typeIs(ls.Next, "table") ? (ls.Next as NextStep) : undefined;
	return $tuple(level, tier, nextStep);
}

function progressText(nextStep: NextStep): string {
	return `${compactNumber(nextStep.Progress)} / ${compactNumber(nextStep.Target)}`;
}

export function progressFraction(nextStep: NextStep | undefined): number {
	if (nextStep === undefined) {
		return 1;
	}
	return math.clamp((tonumber(nextStep.Progress) ?? 0) / math.max(1, tonumber(nextStep.Target) ?? 1), 0, 1);
}

function Track(props: { value: number; color: Color3; size: UDim2; position: UDim2; zIndex: number }) {
	return (
		<frame
			Size={props.size}
			Position={props.position}
			BackgroundColor3={Palette.line}
			BorderSizePixel={0}
			ZIndex={props.zIndex}
			ClipsDescendants={true}
		>
			<uicorner CornerRadius={new UDim(1, 0)} />
			<frame Size={UDim2.fromScale(math.clamp(props.value, 0, 1), 1)} BackgroundColor3={props.color} BorderSizePixel={0} ZIndex={props.zIndex}>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
		</frame>
	);
}

type RowStatus = "done" | "here" | "next" | "ahead";

function RailNode({ status, accent, centerY }: { status: RowStatus; accent: Color3; centerY: number }) {
	const here = status === "here";
	const reached = status === "done" || here;
	const size = here ? 12 : 8;
	return (
		<frame
			AnchorPoint={new Vector2(0.5, 0.5)}
			Position={UDim2.fromOffset(RAIL_X, centerY)}
			Size={UDim2.fromOffset(size, size)}
			BackgroundColor3={here ? accent : reached ? Palette.creamSoft : Palette.panelRaised}
			BorderSizePixel={0}
			ZIndex={478}
		>
			<uicorner CornerRadius={new UDim(1, 0)} />
			{!reached && (
				<uistroke
					ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
					Color={status === "next" ? Palette.creamSoft : Palette.lineSoft}
					Thickness={1.5}
				/>
			)}
		</frame>
	);
}

interface LevelRewardsApi {
	forLevel(this: void, level: number, tier?: string): { Stardust: number; SurgeMultiplier: number };
}

function LevelRow(props: {
	def: LevelDef;
	status: RowStatus;
	opens: string;
	nextStep?: NextStep;
	accent: Color3;
	rightW: number;
	y: number;
}) {
	const { def, status, nextStep, y, accent, rightW } = props;
	const here = status === "here";
	const isNext = status === "next";
	const ahead = status === "ahead";
	const goalText = def.Goal !== undefined && typeIs(def.Goal.Text, "string") ? def.Goal.Text : "Where every forge starts";
	let detail = props.opens !== "" ? `Opens ${props.opens}` : "Permanent production bonus";
	if (def.Level > 1 && status !== "done" && !here) {
		const LevelRewards = (
			require(
				game.GetService("ReplicatedStorage").WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("SharedData") as ModuleScript,
			) as (name: string) => LevelRewardsApi
		)("LevelRewards");
		const reward = LevelRewards.forLevel(def.Level, def.Tier);
		detail += string.format(" · +%d stardust, Surge ×%.2f", reward.Stardust, reward.SurgeMultiplier);
	}
	const rightText = here ? "Current" : isNext && nextStep !== undefined ? progressText(nextStep) : "";
	return (
		<frame
			Size={new UDim2(1, -UNIT * 2, 0, ROW_H)}
			Position={UDim2.fromOffset(0, y)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={476}
		>
			<RailNode status={status} accent={accent} centerY={17} />
			<Text
				value={goalText}
				size={14}
				color={ahead ? Palette.creamSoft : Palette.cream}
				weight={here || isNext ? Enum.FontWeight.Bold : Enum.FontWeight.Medium}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(TEXT_X, 8)}
				sizeConstraint={new UDim2(1, -(TEXT_X + rightW + UNIT * 3), 0, 18)}
				zIndex={477}
			/>
			<Text
				value={detail}
				size={11}
				color={Palette.muted}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(TEXT_X, 28)}
				sizeConstraint={new UDim2(1, -(TEXT_X + rightW + UNIT * 3), 0, 14)}
				zIndex={477}
			/>
			{rightText !== "" && (
				<Text
					value={rightText}
					size={11}
					color={here ? accent : Palette.creamSoft}
					weight={Enum.FontWeight.Bold}
					align={Enum.TextXAlignment.Right}
					fit={true}
					minSize={9}
					position={new UDim2(1, -rightW, 0, 9)}
					sizeConstraint={UDim2.fromOffset(rightW, 14)}
					zIndex={477}
				/>
			)}
			{isNext && nextStep !== undefined && (
				<Track
					value={progressFraction(nextStep)}
					color={accent}
					size={UDim2.fromOffset(rightW, 3)}
					position={new UDim2(1, -rightW, 0, 30)}
					zIndex={477}
				/>
			)}
		</frame>
	);
}

export interface RoadmapConfig {
	Levels?: unknown;
	LevelTierBlurbs?: unknown;
	[key: string]: unknown;
}

export function LevelRoadmap(props: { state: RoadmapState; config?: RoadmapConfig; onClose: () => void; reducedMotion?: boolean }) {
	const cardRef = React.useRef<Frame>();
	const parentSize = useGuiSize(cardRef, true);
	const { state, config, onClose } = props;
	const softMotion = props.reducedMotion;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const compact = chrome.stack || viewport.width < 620 || viewport.height < 560;

	const [level, tier, nextStep] = readLevelState(state);
	const ladder = (config !== undefined && typeIs(config.Levels, "table") ? config.Levels : []) as LevelDef[];
	const accent = tierAccent(tier);

	React.useEffect(() => {
		Audio.play("modalOpen");
	}, []);
	const enter = useEntrance(softMotion);
	const [leave, closing, beginExit] = useExitTransition(softMotion);
	const motion = composePresence(enter, leave);
	const close = React.useCallback(() => {
		if (closing) {
			return;
		}
		Audio.play("close");
		beginExit(onClose);
	}, [beginExit, closing, onClose]);
	React.useEffect(() => {
		const actionName = "AstralForgeLevelRoadmapClose";
		ContextActionService.BindActionAtPriority(
			actionName,
			(_name, inputState) => {
				if (inputState === Enum.UserInputState.Begin) {
					close();
				}
				return Enum.ContextActionResult.Sink;
			},
			false,
			2400,
			Enum.KeyCode.ButtonB,
		);
		return () => ContextActionService.UnbindAction(actionName);
	}, [close]);
	const padFocus = useGamepadAutofocus(true);
	React.useEffect(() => {
		GamepadNavigationService.BeginOverlayFocus();
		return () => {
			GamepadNavigationService.EndOverlayFocus();
		};
	}, []);
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = padFocus.current;
		if (host === undefined) {
			return undefined;
		}
		const job = task.defer(() => {
			if (host.Parent === undefined) {
				return;
			}
			GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			task.cancel(job);
		};
	}, []);

	const side = chrome.sideSafe + UNIT * 4;
	const width = math.min(viewport.width - side * 2, 600);
	const safeHeight = math.max(1, viewport.height - viewport.topInset - chrome.bottomSafe - UNIT * 4);
	const height = math.min(compact ? 580 : 640, safeHeight);
	const pad = compact ? UNIT * 4 : UNIT * 6;
	const headerH = nextStep !== undefined ? 132 : 104;
	const listTop = headerH + UNIT * 3;
	const listH = math.max(60, height - pad * 2 - listTop);
	const rightW = compact ? 64 : 88;

	const rows = new Map<string, React.Element>();
	let y = 0;
	let focusY = 0;
	let firstNodeY: number | undefined;
	let lastNodeY = 0;
	let reachedNodeY = 0;
	for (const def of ladder) {
		const nodeY = y + 17;
		if (firstNodeY === undefined) {
			firstNodeY = nodeY;
		}
		lastNodeY = nodeY;
		if (def.Level <= level) {
			reachedNodeY = nodeY;
		}
		if (def.Level === level) {
			focusY = y;
		}
		const status: RowStatus =
			def.Level < level ? "done" : def.Level === level ? "here" : def.Level === level + 1 ? "next" : "ahead";
		rows.set(
			`Level_${def.Level}`,
			<LevelRow
				def={def}
				status={status}
				opens={joinNames(featureNames(state, def.Unlocks))}
				nextStep={status === "next" ? nextStep : undefined}
				accent={accent}
				rightW={rightW}
				y={y}
			/>,
		);
		y += ROW_H;
	}
	const canvasH = y + UNIT * 2;
	const railTop = firstNodeY ?? 0;
	rows.set(
		"Rail",
		<frame
			AnchorPoint={new Vector2(0.5, 0)}
			Position={UDim2.fromOffset(RAIL_X, railTop)}
			Size={UDim2.fromOffset(2, math.max(0, lastNodeY - railTop))}
			BackgroundColor3={Palette.line}
			BorderSizePixel={0}
			ZIndex={476}
		/>,
	);
	rows.set(
		"RailFill",
		<frame
			AnchorPoint={new Vector2(0.5, 0)}
			Position={UDim2.fromOffset(RAIL_X, railTop)}
			Size={UDim2.fromOffset(2, math.max(0, reachedNodeY - railTop))}
			BackgroundColor3={accent}
			BorderSizePixel={0}
			ZIndex={477}
		/>,
	);

	const listRef = React.useRef<ScrollingFrame>();
	React.useEffect(() => {
		const list = listRef.current;
		if (list === undefined) {
			return;
		}
		list.CanvasPosition = new Vector2(0, math.max(0, math.min(focusY - TIER_H, canvasH - listH)));
	}, []);

	const cardPosition = joinTuple<[number, Vector2]>(motion, parentSize).map((values) =>
		pixelPosition(values[1], 0.5, 0, 0.5, (1 - values[0]) * 12),
	);
	const cardScale = motion.map((amount) => 0.96 + amount * 0.04);
	const fade = motion.map((amount) => 1 - amount);
	const opensNext = nextStep !== undefined ? joinNames(featureNames(state, nextStep.Unlocks)) : "";

	return (
		<OverlayPresence amount={motion}>
			<frame
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ZIndex={470}
				Visible={motion.map((amount) => amount > 0.003)}
			>
				<imagebutton
					Size={UDim2.fromScale(1, 1)}
					BackgroundColor3={Palette.void}
					BackgroundTransparency={motion.map((amount) => 1 - amount * 0.6)}
					BorderSizePixel={0}
					AutoButtonColor={false}
					Active={true}
					Selectable={false}
					ZIndex={470}
					Event={{
						Activated: () => {
							close();
						},
					}}
				/>
				<frame
					ref={(node: Frame | undefined) => {
						padFocus.current = node;
						cardRef.current = node;
					}}
					Size={UDim2.fromOffset(width, height)}
					Position={cardPosition}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					ZIndex={471}
					Visible={motion.map((amount) => amount > 0.002)}
				>
					<ScaleFromCenter scale={cardScale} zIndex={471}>
						<frame
							Size={UDim2.fromScale(1, 1)}
							BackgroundColor3={Palette.panelRaised}
							BackgroundTransparency={fade}
							BorderSizePixel={0}
							ZIndex={472}
							ClipsDescendants={true}
						>
							<uicorner CornerRadius={new UDim(0, 16)} />
							<uistroke ApplyStrokeMode={Enum.ApplyStrokeMode.Border} Color={Palette.lineSoft} Thickness={1} Transparency={0.35} />
						</frame>
						<frame
							Size={new UDim2(1, -pad * 2, 1, -pad * 2)}
							Position={UDim2.fromOffset(pad, pad)}
							BackgroundTransparency={1}
							BorderSizePixel={0}
							ZIndex={473}
						>
							<Text
								value="UNLOCKS"
								size={12}
								color={Palette.muted}
								weight={Enum.FontWeight.Bold}
								fit={true}
								minSize={10}
								position={UDim2.fromOffset(0, 0)}
								sizeConstraint={new UDim2(1, -(TapTarget + UNIT * 3), 0, 16)}
								zIndex={474}
							/>
							<Text
								value={nextStep !== undefined ? "What opens next" : "Everything is open"}
								size={compact ? 24 : 28}
								color={Palette.cream}
								weight={Enum.FontWeight.Heavy}
								fit={true}
								minSize={18}
								position={UDim2.fromOffset(0, 18)}
								sizeConstraint={new UDim2(1, -(TapTarget + UNIT * 3), 0, 34)}
								zIndex={474}
							/>
							<Text
								value=""
								size={13}
								color={accent}
								weight={Enum.FontWeight.Bold}
								fit={true}
								minSize={10}
								position={UDim2.fromOffset(compact ? 116 : 134, 28)}
								sizeConstraint={new UDim2(1, -((compact ? 116 : 134) + TapTarget + UNIT * 3), 0, 18)}
								zIndex={474}
							/>
							<Button
								text=""
								icon="Close.13"
								onClick={close}
								color={Palette.panel}
								textColor={Palette.creamSoft}
								size={UDim2.fromOffset(TapTarget, TapTarget)}
								position={new UDim2(1, -TapTarget, 0, 0)}
								reducedMotion={softMotion}
								disabled={closing}
							/>
							{nextStep !== undefined && (
								<Text
									value={nextStep.Text}
									size={14}
									color={Palette.cream}
									weight={Enum.FontWeight.Bold}
									fit={true}
									minSize={11}
									position={UDim2.fromOffset(0, 66)}
									sizeConstraint={new UDim2(1, -96, 0, 18)}
									zIndex={474}
								/>
							)}
							{nextStep !== undefined && (
								<Text
									value={progressText(nextStep)}
									size={12}
									color={Palette.creamSoft}
									weight={Enum.FontWeight.Bold}
									align={Enum.TextXAlignment.Right}
									fit={true}
									minSize={9}
									position={new UDim2(1, -92, 0, 67)}
									sizeConstraint={UDim2.fromOffset(92, 16)}
									zIndex={474}
								/>
							)}
							<Track
								value={progressFraction(nextStep)}
								color={accent}
								size={new UDim2(1, 0, 0, 4)}
								position={UDim2.fromOffset(0, nextStep !== undefined ? 92 : 66)}
								zIndex={474}
							/>
							{nextStep !== undefined && (
								<Text
									value={opensNext !== "" ? `Opens ${opensNext}` : "Adds a permanent production bonus"}
									size={12}
									color={Palette.muted}
									fit={true}
									minSize={9}
									position={UDim2.fromOffset(0, 104)}
									sizeConstraint={new UDim2(1, 0, 0, 16)}
									zIndex={474}
								/>
							)}
							{nextStep === undefined && (
								<Text
									value="Every milestone is reached and every feature is open."
									size={12}
									color={Palette.muted}
									fit={true}
									minSize={9}
									position={UDim2.fromOffset(0, 76)}
									sizeConstraint={new UDim2(1, 0, 0, 16)}
									zIndex={474}
								/>
							)}
							<frame
								Size={new UDim2(1, 0, 0, 1)}
								Position={UDim2.fromOffset(0, headerH)}
								BackgroundColor3={Palette.lineSoft}
								BackgroundTransparency={0.4}
								BorderSizePixel={0}
								ZIndex={474}
							/>
							<scrollingframe
								ref={listRef}
								Size={new UDim2(1, 0, 0, listH)}
								Position={UDim2.fromOffset(0, listTop)}
								CanvasSize={UDim2.fromOffset(0, canvasH)}
								BackgroundTransparency={1}
								BorderSizePixel={0}
								ScrollBarThickness={2}
								ScrollBarImageColor3={Palette.lineSoft}
								ScrollBarImageTransparency={0.2}
								ScrollingDirection={Enum.ScrollingDirection.Y}
								ElasticBehavior={Enum.ElasticBehavior.WhenScrollable}
								VerticalScrollBarInset={Enum.ScrollBarInset.ScrollBar}
								ClipsDescendants={true}
								Active={true}
								Selectable={false}
								ZIndex={475}
							>
								{rows}
							</scrollingframe>
						</frame>
					</ScaleFromCenter>
				</frame>
			</frame>
		</OverlayPresence>
	);
}

const openListeners = new Set<(value: boolean) => void>();
let roadmapOpen = false;

function setRoadmapOpen(value: boolean) {
	if (roadmapOpen === value) {
		return;
	}
	roadmapOpen = value;
	for (const listener of openListeners) {
		listener(value);
	}
}

export function openRoadmap() {
	setRoadmapOpen(true);
}

export function LevelRoadmapHost(props: { state: RoadmapState; config?: RoadmapConfig; reducedMotion?: boolean }) {
	const [open, setOpen] = React.useState(roadmapOpen);
	React.useEffect(() => {
		const listener = (value: boolean) => {
			setOpen(value);
		};
		openListeners.add(listener);
		setOpen(roadmapOpen);
		return () => {
			openListeners.delete(listener);
		};
	}, []);
	if (!open) {
		return undefined;
	}
	return (
		<LevelRoadmap
			state={props.state}
			config={props.config}
			reducedMotion={props.reducedMotion}
			onClose={() => {
				setRoadmapOpen(false);
			}}
		/>
	);
}

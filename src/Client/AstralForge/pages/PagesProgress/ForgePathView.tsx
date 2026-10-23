import React from "@rbxts/react";
import { FocusPlan, useFocusOrder } from "../../CoreKit/focusOrder";
import { compactNumber, formatReward, Reward } from "../../CoreKit/format";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { chromeFor, darken, Layout, lighten, Palette, scrollTail, TapTarget } from "../../CoreKit/theme";
import { DecoratedForgePathStep, decorateForgePathSteps, ForgePathStep } from "../../CoreKit/types";
import { useAntilag } from "../../MotionKit/antilag";
import { useStagger, useViewport } from "../../MotionKit/motion";
import { named } from "../luauDeps";
import { BrowseApi, clientModule, kitMember, LuauComponent } from "../luauKits";

const UserInputService = game.GetService("UserInputService");

interface UiKit {
	IconTile: LuauComponent;
	Panel: LuauComponent;
	Button: LuauComponent;
	Text: LuauComponent;
	Meter: LuauComponent;
	Badge: LuauComponent;
	EmptyState: LuauComponent;
}
const { EmptyState } = kitMember<UiKit>("UiCore", "ui");
import { SplitColumns, splitColumns, StackBlocks } from "../../UiCore/ui";
import { Bar, BODY_BOLD, Glyph, MockPanel, PanelHeading, spaced } from "../../UiCore/mockKit";
import { Grid, headingBlock, MockBtn, MockRow, panelHeight, RowFace, rowHeight, Rise } from "../mockRows";

type ColumnSection = { id: string; height: number; element: React.Element };
const { PageScaffold } = kitMember<{ PageScaffold: LuauComponent }>("LayoutKit", "pageScaffold");
const { FlatList } = kitMember<{ FlatList: LuauComponent }>("LayoutKit", "virtualizedList");
const Browse = clientModule<BrowseApi>("BrowseKit");

// 15-rewards rows: two-line .row (56 / 46 phone)
const STEP_ROW_HEIGHT = 56;
const STEP_ROW_HEIGHT_STACK = 46;
const EMPTY_FORGE_PATH: { ClaimedSteps: number[]; XP: number } = { ClaimedSteps: [], XP: 0 };

interface ForgePathGuide {
	Complete?: string;
	NeedXp?: string;
	HeroBlurb?: string;
}
interface ForgePathConfig {
	ForgePath?: { Steps?: ForgePathStep[] };
	ClientPageGuides?: { ForgePath?: ForgePathGuide };
	[key: string]: unknown;
}
interface ForgePathState {
	ForgePath?: { ClaimedSteps: number[]; XP: number };
	[key: string]: unknown;
}
type Dispatch = (action: string, payload?: object) => unknown;

interface ForgePathViewProps {
	state: ForgePathState;
	config?: ForgePathConfig;
	dispatch: Dispatch;
	reducedMotion?: boolean;
}

function pageGuide(config: ForgePathConfig | undefined): ForgePathGuide | undefined {
	const guides = config?.ClientPageGuides;
	return guides !== undefined ? guides.ForgePath : undefined;
}

function effectLabel(step: DecoratedForgePathStep): string {
	let noun = step.Noun;
	if (noun === undefined || noun === "") {
		const names: Record<string, string> = {
			Production: "production",
			TapPower: "tap power",
			Capacity: "vault capacity",
			CriticalChance: "critical chance",
			AutoCollect: "auto-collect rate",
			Offline: "offline income",
			CriticalMultiplier: "critical multiplier",
			RebirthMultiplier: "rebirth multiplier",
		};
		noun = names[step.EffectKind] ?? step.EffectKind;
	}
	return `+${step.EffectAmount}% ${noun}`;
}

interface ForgePathRowProps {
	step: DecoratedForgePathStep;
	claimed: boolean;
	unlockedForClaim: boolean;
	affordable: boolean;
	xp: number;
	onClaim: (step: number) => unknown;
	reducedMotion?: boolean;
	index: number;
	stack?: boolean;
}

function ForgePathRow({
	step,
	claimed,
	unlockedForClaim,
	affordable,
	xp,
	onClaim,
	reducedMotion,
	index,
	stack,
}: ForgePathRowProps) {
	const reveal = useStagger(index, reducedMotion, 0.015, 0.12);
	const ready = !claimed && unlockedForClaim && affordable;
	const locked = !claimed && !unlockedForClaim;
	const phone = stack === true;
	return (
		<Rise reveal={reveal} height={phone ? STEP_ROW_HEIGHT_STACK : STEP_ROW_HEIGHT} layoutOrder={index}>
			<MockRow
				phone={phone}
				height={phone ? STEP_ROW_HEIGHT_STACK : STEP_ROW_HEIGHT}
				icon={claimed ? "Check" : locked ? "Lock" : step.Icon}
				accent={claimed ? Palette.muted : step.Color}
				dim={claimed || locked}
				title={`Step ${step.Step} · ${effectLabel(step)}`}
				sub={formatReward(step.Reward as Reward | undefined)}
				value={claimed ? "Claimed" : `${compactNumber(math.min(xp, step.XPCost))} / ${compactNumber(step.XPCost)} XP`}
				valueColor={claimed ? Palette.muted : ready ? step.Color : Palette.creamSoft}
				outline={ready ? Palette.mango : undefined}
				rightWidth={ready ? (phone ? 84 : 110) : undefined}
				right={ready ? <MockBtn text="Claim" accent={step.Color} sm={true} phone={phone} width={phone ? 84 : 110} onClick={() => onClaim(step.Step)} reducedMotion={reducedMotion} /> : undefined}
			/>
		</Rise>
	);
}

/** 15-rewards "This week" cell: label, glyph, figure, Claim on the live one; claimed cells at .55. */
const DAY_CELL_H = 148;
const DAY_CELL_H_PHONE = 118;
function DayCell(p: { step: DecoratedForgePathStep; claimed: boolean; ready: boolean; next: boolean; phone: boolean; onClaim: (step: number) => unknown; reducedMotion?: boolean; order: number }) {
	const { step, phone } = p;
	return (
		<canvasgroup BackgroundTransparency={1} GroupTransparency={p.claimed ? 0.45 : 0} LayoutOrder={p.order}>
			<frame BackgroundColor3={Palette.white} BorderSizePixel={0} Size={UDim2.fromScale(1, 1)}>
				<RowFace outline={p.next ? Palette.mango : undefined} strong={p.next} />
				<uipadding PaddingTop={new UDim(0, phone ? 10 : 14)} PaddingBottom={new UDim(0, phone ? 10 : 14)} PaddingLeft={new UDim(0, 8)} PaddingRight={new UDim(0, 8)} />
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} HorizontalAlignment={Enum.HorizontalAlignment.Center} Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<textlabel BackgroundTransparency={1} Text={spaced(`STEP ${step.Step}`)} TextSize={phone ? 10 : 11} FontFace={BODY_BOLD} TextColor3={Palette.muted} Size={new UDim2(1, 0, 0, 14)} LayoutOrder={0} />
				<frame BackgroundTransparency={1} Size={UDim2.fromOffset(phone ? 22 : 28, phone ? 22 : 28)} LayoutOrder={1}>
					<Glyph kind={p.claimed ? "Check" : step.Icon} size={phone ? 22 : 28} color={p.claimed ? Palette.mint : step.Color} />
				</frame>
				<textlabel BackgroundTransparency={1} Text={`+${step.EffectAmount}%`} TextSize={phone ? 13 : 15} FontFace={BODY_BOLD} TextColor3={Palette.cream} TextTruncate={Enum.TextTruncate.AtEnd} Size={new UDim2(1, 0, 0, 18)} LayoutOrder={2} />
				{p.ready ? (
					<MockBtn text="Claim" sm={true} phone={false} fill={true} onClick={() => p.onClaim(step.Step)} reducedMotion={p.reducedMotion} layoutOrder={3} />
				) : undefined}
			</frame>
		</canvasgroup>
	);
}

interface SpotlightPanelProps {
	step?: DecoratedForgePathStep;
	xp: number;
	ready: boolean;
	complete: boolean;
	guide?: ForgePathGuide;
	onClaim: (step: number) => unknown;
	reducedMotion?: boolean;
	stack?: boolean;
}

function SpotlightPanel({ step, xp, ready, complete, guide, onClaim, reducedMotion, stack }: SpotlightPanelProps) {
	const claimHostRef = React.useRef<Frame>();
	React.useEffect(() => {
		if (!ready || complete || step === undefined || !UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = claimHostRef.current;
		if (host === undefined) {
			return undefined;
		}
		const selectJob = task.defer(() => {
			if (host.Parent === undefined) {
				return;
			}
			GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, selectJob);
		};
	}, [ready, complete, step !== undefined ? step.Step : 0]);
	const phone = stack === true;
	if (complete || step === undefined) {
		return (
			<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={complete ? Palette.mint : Palette.violet} reducedMotion={reducedMotion} name="ForgePathNext">
				<PanelHeading icon={complete ? "Check" : "Forge"} title={complete ? "Path complete" : "Next step"} accent={complete ? Palette.mint : Palette.violet} phone={phone} layoutOrder={0} />
				<MockRow
					phone={phone}
					icon="Info"
					accent={complete ? Palette.mint : Palette.violet}
					title={complete ? (guide?.Complete ?? "Path cleared. Permanent bonuses stay through rebirth.") : "Forge Path isn't ready"}
					sub={complete ? undefined : "Check back in a moment."}
					layoutOrder={1}
				/>
			</MockPanel>
		);
	}
	const progressFrac = math.clamp(xp / math.max(1, step.XPCost), 0, 1);
	const needXp = !ready && xp < step.XPCost;
	return (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={ready ? step.Color : Palette.violet} glow={ready ? step.Color : undefined} reducedMotion={reducedMotion} name="ForgePathNext">
			<PanelHeading icon={step.Icon} title={`Step ${step.Step}`} note="Next step" accent={step.Color} phone={phone} layoutOrder={0} />
			<MockRow phone={phone} icon={step.Icon} accent={step.Color} title={effectLabel(step)} value={`${compactNumber(math.min(xp, step.XPCost))} / ${compactNumber(step.XPCost)}`} layoutOrder={1} />
			<MockRow
				phone={phone}
				icon="Gift"
				accent={Palette.mango}
				title={needXp ? (guide?.NeedXp ?? "Bank Flux to earn Forge Path XP.") : "Reward"}
				value={needXp ? undefined : formatReward(step.Reward as Reward | undefined)}
				layoutOrder={2}
			/>
			<Bar fill={progressFrac} color={ready ? step.Color : Palette.violet} layoutOrder={3} />
			<frame {...named("ForgePathClaimActions")} Size={new UDim2(1, 0, 0, phone ? TapTarget : 44)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false} ref={claimHostRef} LayoutOrder={4}>
				<MockBtn text={ready ? "Claim" : "Earning XP"} icon={ready ? "Check" : undefined} accent={step.Color} phone={phone} fill={true} disabled={!ready} onClick={() => onClaim(step.Step)} reducedMotion={reducedMotion} />
			</frame>
		</MockPanel>
	);
}

function ForgePathViewComponent({ state, config, dispatch, reducedMotion }: ForgePathViewProps) {
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const stack = chrome.contentStack;
	const antilag = useAntilag();
	const softMotion = reducedMotion;
	const forgePath = state.ForgePath ?? EMPTY_FORGE_PATH;
	const guide = pageGuide(config);
	const steps = React.useMemo(() => {
		const raw = config !== undefined && config.ForgePath !== undefined ? config.ForgePath.Steps : undefined;
		return decorateForgePathSteps(raw);
	}, [config]);
	const claimedSet = new Set<number>();
	for (const stepId of forgePath.ClaimedSteps) {
		claimedSet.add(stepId);
	}
	const claimedCount = forgePath.ClaimedSteps.size();
	const totalCount = steps.size();
	let nextStep: DecoratedForgePathStep | undefined;
	let nextReady = false;
	for (const step of steps) {
		if (!claimedSet.has(step.Step)) {
			const unlocked = step.Step === 1 || claimedSet.has(step.Step - 1);
			if (unlocked) {
				nextStep = step;
				nextReady = forgePath.XP >= step.XPCost;
				break;
			}
		}
	}
	const pathComplete = totalCount > 0 && claimedCount >= totalCount;
	const onClaim = (step: number) => dispatch("ClaimForgePathStep", { Step: step });
	const headerReveal = useStagger(0, softMotion);
	const listGap = stack ? 8 : 12;
	const g = stack ? 8 : 12;
	const rowH = rowHeight(stack);
	const spotlightH = pathComplete || nextStep === undefined ? panelHeight(stack, headingBlock(stack) + rowHeight(stack, true)) : panelHeight(stack, headingBlock(stack) + rowH * 2 + g * 3 + 10 + (stack ? TapTarget : 44));
	const progressH = panelHeight(stack, headingBlock(stack) + rowH * 3 + g * 2);
	const headerH = stack ? progressH : math.max(spotlightH, progressH);
	const dayCols = stack ? 4 : 7;
	const dayH = stack ? DAY_CELL_H_PHONE : DAY_CELL_H;
	const weekH = panelHeight(stack, headingBlock(stack) + dayH);
	// phones in landscape have the width for the side-by-side step row (claim on the right)
	const rowStack = stack && !chrome.landscape;
	const stepRowHeight = rowStack ? STEP_ROW_HEIGHT_STACK : STEP_ROW_HEIGHT;
	const progressFrac = totalCount > 0 ? claimedCount / totalCount : 0;
	const heroBlurb = guide?.HeroBlurb ?? "One track. Every step pays out.";
	const stepStride = stepRowHeight + listGap;
	const browse = Browse.useBrowse<DecoratedForgePathStep>({
		id: "ForgePath",
		items: steps,
		text: (step) => [effectLabel(step), formatReward(step.Reward as Reward | undefined), `step ${step.Step}`, step.EffectKind],
		categories: [
			{ id: "All", label: "All" },
			{
				id: "Upcoming",
				label: "Upcoming",
				test: (step) => !claimedSet.has(step.Step),
			},
			{
				id: "Claimed",
				label: "Claimed",
				test: (step) => claimedSet.has(step.Step),
			},
		],
	});
	const stepsElement =
		totalCount > 0 && browse.results.size() === 0 ? (
			<Browse.NoResults
				browse={browse}
				noun="steps"
				icon="Forge.12"
				accent={Palette.violet}
				reducedMotion={softMotion}
				size={UDim2.fromScale(1, 1)}
			/>
		) : totalCount === 0 ? (
			<EmptyState
				icon="Forge.13"
				title="Forge Path isn't ready"
				body="Check back in a moment."
				accent={Palette.violet}
				reducedMotion={softMotion}
			/>
		) : (
			<FlatList
				data={browse.results}
				itemHeight={stepStride}
				overscan={softMotion ? 0 : antilag.constrained ? 1 : 2}
				canvasTail={8}
				Size={UDim2.fromScale(1, 1)}
				scrollBarColor={Palette.violet}
				scrollBarThickness={4}
				keyExtractor={(step: DecoratedForgePathStep) => step.Step}
				renderItem={({ item, index }: { item: DecoratedForgePathStep; index: number }) => (
					<ForgePathRow
						step={item}
						claimed={claimedSet.has(item.Step)}
						unlockedForClaim={item.Step === 1 || claimedSet.has(item.Step - 1)}
						affordable={forgePath.XP >= item.XPCost}
						xp={forgePath.XP}
						onClaim={onClaim}
						reducedMotion={reducedMotion}
						index={index + 1}
						stack={rowStack}
					/>
				)}
			/>
		);
	// the 7-step window around the next claim (15-rewards "This week")
	const nextIndex = nextStep !== undefined ? steps.indexOf(nextStep) : pathComplete ? totalCount - 1 : 0;
	const windowStart = math.clamp(nextIndex - 3, 0, math.max(0, totalCount - dayCols));
	const windowSteps = steps.filter((_, i) => i >= windowStart && i < windowStart + dayCols);
	const weekSection: ColumnSection = {
		id: "week",
		height: weekH,
		element: (
			<MockPanel size={UDim2.fromScale(1, 1)} phone={stack} accent={Palette.violet} reveal={headerReveal} reducedMotion={softMotion} name="ForgePathWeek">
				<PanelHeading icon="Forge" title="Forge Path" note={`${claimedCount} of ${totalCount} claimed`} accent={Palette.violet} phone={stack} layoutOrder={0} />
				<Grid columns={dayCols} gap={stack ? 8 : 12} cellHeight={dayH} count={dayCols} layoutOrder={1}>
					{windowSteps.map((step, i) => (
						<DayCell
							key={step.Step}
							step={step}
							claimed={claimedSet.has(step.Step)}
							next={nextStep !== undefined && step.Step === nextStep.Step}
							ready={nextStep !== undefined && step.Step === nextStep.Step && nextReady}
							phone={stack}
							onClaim={onClaim}
							reducedMotion={softMotion}
							order={i}
						/>
					))}
				</Grid>
			</MockPanel>
		),
	};
	const heroSection: ColumnSection = {
		id: "hero",
		height: headerH,
		element: (
			<MockPanel size={UDim2.fromScale(1, 1)} phone={stack} accent={Palette.violet} reducedMotion={softMotion} name="ForgePathProgress">
				<PanelHeading icon="Milestone" title="Progress" accent={Palette.violet} phone={stack} layoutOrder={0} />
				<MockRow phone={stack} icon="Forge" accent={Palette.violet} title="Forge Path XP" value={compactNumber(forgePath.XP)} layoutOrder={1} />
				<MockRow phone={stack} icon="Check" accent={Palette.violet} title="Steps claimed" value={`${claimedCount} / ${totalCount}`} layoutOrder={2} />
				<MockRow phone={stack} icon="Info" accent={Palette.violet} title={heroBlurb} value={`${math.floor(progressFrac * 100)}%`} layoutOrder={3} />
			</MockPanel>
		),
	};
	const spotlightSection: ColumnSection = {
					id: "spotlight",
					height: spotlightH,
					element: (
						<SpotlightPanel
							step={nextStep}
							xp={forgePath.XP}
							ready={nextReady}
							complete={pathComplete}
							guide={guide}
							onClaim={onClaim}
							reducedMotion={reducedMotion}
							stack={stack}
						/>
					),
				};
	// desktop: the next claim and progress side by side (.flexr of two f1 panels) under the step strip
	const topPlan = splitColumns(stack ? 0 : viewport.width, math.floor((viewport.width - 18) / 2), 18, 900);
	const topH = headerH;
	const pageHostRef = React.useRef<Frame>();
	useFocusOrder(
		pageHostRef,
		{ regions: ["hero", "spotlight", "browse", "steps"], first: ["spotlight", "browse", "steps"], columns: [["Side", "Main"]] },
		[nextReady, pathComplete, browse.category, topPlan.split, stack],
	);
	const topSections: ColumnSection[] = topPlan.split
		? [
				weekSection,
				{
					id: "top",
					height: topH,
					element: (
						<SplitColumns
							height={topH}
							plan={topPlan}
							sideOnRight={true}
							side={<StackBlocks riseFrom={1} blocks={[{ ...heroSection, height: topH, rise: 1 }]} />}
							main={<StackBlocks riseFrom={1} blocks={[{ ...spotlightSection, height: topH, rise: 2 }]} />}
						/>
					),
				},
			]
		: [weekSection, spotlightSection, { ...heroSection, height: progressH }];
	return (
		<frame ref={pageHostRef} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<PageScaffold
				gap={stack ? 8 : 18}
				tailPad={scrollTail(stack, chrome.bottomSafe, 48)}
				scrollBarColor={Palette.violet}
				scrollBarThickness={4}
				sections={[
					...topSections,
					{
						id: "browse",
						height: Browse.barHeight(stack, true),
						element: (
							<Browse.BrowseBar
								browse={browse}
								placeholder="Search steps by reward or bonus"
								accent={Palette.violet}
								stack={stack}
								reducedMotion={softMotion}
								zIndex={30}
							/>
						),
					},
					{
						id: "steps",
						fill: true,
						minHeight: math.max(160, stepStride * 2),
						element: stepsElement,
					},
				]}
			/>
		</frame>
	);
}

export const ForgePathView = React.memo(ForgePathViewComponent, (previous: ForgePathViewProps, incoming: ForgePathViewProps) => {
	const prevXp = previous.state.ForgePath?.XP;
	const nextXp = incoming.state.ForgePath?.XP;
	const prevClaimed = previous.state.ForgePath?.ClaimedSteps.size();
	const nextClaimed = incoming.state.ForgePath?.ClaimedSteps.size();
	const prevSteps = previous.config?.ForgePath?.Steps;
	const nextSteps = incoming.config?.ForgePath?.Steps;
	return (
		previous.dispatch === incoming.dispatch &&
		previous.reducedMotion === incoming.reducedMotion &&
		prevXp === nextXp &&
		prevClaimed === nextClaimed &&
		prevSteps === nextSteps
	);
});

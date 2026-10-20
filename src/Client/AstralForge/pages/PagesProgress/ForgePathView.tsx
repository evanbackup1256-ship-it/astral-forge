import React from "@rbxts/react";
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
const { IconTile, Panel, Button, Text, Meter, Badge, EmptyState } = kitMember<UiKit>("UiCore", "ui");
const { PageScaffold } = kitMember<{ PageScaffold: LuauComponent }>("LayoutKit", "pageScaffold");
const { FlatList } = kitMember<{ FlatList: LuauComponent }>("LayoutKit", "virtualizedList");
const { Icon } = kitMember<{ Icon: LuauComponent }>("ArtKit", "Icon");
const Browse = clientModule<BrowseApi>("BrowseKit");

const STEP_ROW_HEIGHT = 168;
const STEP_ROW_HEIGHT_STACK = 224;
const SPOTLIGHT_H = 148;
const SPOTLIGHT_H_STACK = 188;
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

function rewardChips(reward: Reward | undefined, accent: Color3): React.Element[] {
	const chips: { label: string; icon: string }[] = [];
	const cash = reward?.Cash ?? 0;
	const stardust = reward?.Stardust ?? 0;
	const cores = reward?.Cores ?? 0;
	const essence = reward?.Essence ?? 0;
	if (cash > 0) chips.push({ label: `${compactNumber(cash)} flux`, icon: "Flux.14" });
	if (stardust > 0) chips.push({ label: `${compactNumber(stardust)} dust`, icon: "Dust.2" });
	if (cores > 0) chips.push({ label: `${compactNumber(cores)} cores`, icon: "Core.5" });
	if (essence > 0) chips.push({ label: `${compactNumber(essence)} essence`, icon: "StarGrid.4" });
	if (reward?.Boost !== undefined) chips.push({ label: reward.Boost, icon: "Boost.13" });
	return chips.map((chip, index) => (
		<frame
			key={index}
			Size={UDim2.fromOffset(0, 26)}
			AutomaticSize={Enum.AutomaticSize.X}
			BackgroundColor3={darken(accent, 0.55)}
			BorderSizePixel={0}
			LayoutOrder={index}
			ClipsDescendants={false}
		>
			<uicorner CornerRadius={new UDim(0, 6)} />
			<uigradient Color={new ColorSequence(lighten(darken(accent, 0.5), 0.06), darken(accent, 0.2))} Rotation={90} />
			<uipadding
				PaddingLeft={new UDim(0, 6)}
				PaddingRight={new UDim(0, 8)}
				PaddingTop={new UDim(0, 4)}
				PaddingBottom={new UDim(0, 4)}
			/>
			<uilistlayout
				FillDirection={Enum.FillDirection.Horizontal}
				Padding={new UDim(0, 6)}
				SortOrder={Enum.SortOrder.LayoutOrder}
				VerticalAlignment={Enum.VerticalAlignment.Center}
			/>
			<frame
				Size={UDim2.fromOffset(16, 16)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				LayoutOrder={0}
				ClipsDescendants={true}
			>
				<Icon kind={chip.icon} color={Palette.cream} accent={accent} size={16} spin={false} clipSafe={true} />
			</frame>
			<textlabel
				Size={UDim2.fromOffset(0, 18)}
				AutomaticSize={Enum.AutomaticSize.X}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				Text={chip.label}
				TextColor3={Palette.cream}
				TextSize={11}
				FontFace={Font.fromEnum(Enum.Font.BuilderSansBold)}
				TextXAlignment={Enum.TextXAlignment.Left}
				TextYAlignment={Enum.TextYAlignment.Center}
				LayoutOrder={1}
			/>
		</frame>
	));
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
	const accent = claimed ? Palette.muted : ready ? step.Color : Palette.mango;
	const progressFrac = math.clamp(xp / math.max(1, step.XPCost), 0, 1);
	const statusText = claimed
		? "CLAIMED"
		: locked
			? "CLAIM THE STEP BEFORE THIS"
			: `${compactNumber(math.min(xp, step.XPCost))} / ${compactNumber(step.XPCost)} XP`;
	const rowH = stack ? STEP_ROW_HEIGHT_STACK : STEP_ROW_HEIGHT;
	const textW = stack ? -48 : -200;
	return (
		<frame
			Size={new UDim2(1, -4, 0, rowH)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			LayoutOrder={index}
			ClipsDescendants={false}
		>
			<Panel
				size={UDim2.fromScale(1, 1)}
				accent={accent}
				background={Palette.panel}
				padding={12}
				reveal={reveal}
				highlight={ready}
				reducedMotion={reducedMotion}
				clips={false}
			>
				<IconTile
					kind={step.Icon}
					accent={claimed ? Palette.muted : step.Color}
					size={38}
					radius={10}
					position={UDim2.fromOffset(0, 4)}
					spin={false}
					reducedMotion={reducedMotion}
				/>
				<Text
					value={`STEP ${step.Step}`}
					size={10}
					color={claimed ? Palette.muted : step.Color}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					position={UDim2.fromOffset(48, 2)}
					sizeConstraint={new UDim2(1, textW, 0, 16)}
				/>
				<Text
					value={effectLabel(step)}
					size={14}
					color={claimed ? Palette.muted : Palette.cream}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					position={UDim2.fromOffset(48, 20)}
					sizeConstraint={new UDim2(1, textW, 0, 20)}
				/>
				<Text
					value={formatReward(step.Reward as Reward | undefined)}
					size={10}
					color={Palette.mango}
					weight={Enum.FontWeight.Bold}
					wrap={true}
					fit={true}
					minSize={9}
					position={UDim2.fromOffset(48, 42)}
					sizeConstraint={new UDim2(1, textW, 0, 16)}
				/>
				<frame
					Size={new UDim2(1, textW, 0, 26)}
					Position={UDim2.fromOffset(48, 60)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					ClipsDescendants={false}
				>
					<uilistlayout
						FillDirection={Enum.FillDirection.Horizontal}
						Padding={new UDim(0, 6)}
						SortOrder={Enum.SortOrder.LayoutOrder}
						VerticalAlignment={Enum.VerticalAlignment.Center}
					/>
					{rewardChips(step.Reward as Reward | undefined, claimed ? Palette.muted : step.Color)}
				</frame>
				<Meter
					value={claimed ? 1 : progressFrac}
					color={accent}
					reducedMotion={reducedMotion}
					shimmer={ready}
					position={UDim2.fromOffset(0, stack ? 98 : 104)}
					size={new UDim2(1, stack ? 0 : -200, 0, 8)}
				/>
				<Text
					value={statusText}
					size={10}
					color={ready ? step.Color : Palette.muted}
					weight={Enum.FontWeight.Bold}
					fit={false}
					position={UDim2.fromOffset(0, stack ? 112 : 118)}
					sizeConstraint={new UDim2(1, stack ? 0 : -200, 0, 16)}
				/>
				{stack ? (
					claimed ? (
						<Badge
							value="CLAIMED"
							accent={Palette.muted}
							filled={true}
							size={new UDim2(1, 0, 0, TapTarget)}
							position={new UDim2(0, 0, 1, -TapTarget)}
						/>
					) : (
						<Button
							text={ready ? "CLAIM STEP" : locked ? "LOCKED" : "NEED XP"}
							icon={ready ? "Check.4" : undefined}
							onClick={() => onClaim(step.Step)}
							color={ready ? step.Color : Palette.panelSoft}
							textColor={ready ? Palette.ink : Palette.muted}
							size={new UDim2(1, 0, 0, TapTarget)}
							position={new UDim2(0, 0, 1, -TapTarget)}
							reducedMotion={reducedMotion}
							disabled={!ready}
							highlight={ready}
						/>
					)
				) : claimed ? (
					<Badge
						value="CLAIMED"
						accent={Palette.muted}
						filled={true}
						position={new UDim2(1, -150, 0, 26)}
						size={UDim2.fromOffset(140, 32)}
					/>
				) : (
					<Button
						text={ready ? "CLAIM" : locked ? "LOCKED" : "NEED XP"}
						icon={ready ? "Check.5" : undefined}
						onClick={() => onClaim(step.Step)}
						color={ready ? step.Color : Palette.panelSoft}
						textColor={ready ? Palette.ink : Palette.muted}
						size={UDim2.fromOffset(140, 32)}
						position={new UDim2(1, -150, 0, 26)}
						reducedMotion={reducedMotion}
						disabled={!ready}
						highlight={ready}
					/>
				)}
			</Panel>
		</frame>
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
	if (complete) {
		return (
			<Panel
				size={UDim2.fromScale(1, 1)}
				accent={Palette.mint}
				background={Palette.panelRaised}
				padding={stack ? 14 : 16}
				clips={false}
			>
				<EmptyState
					icon="Check.6"
					title="Forge Path complete"
					body={guide?.Complete ?? "Path cleared. Permanent bonuses stay through rebirth."}
					accent={Palette.mint}
					compact={true}
					size={UDim2.fromScale(1, 1)}
					reducedMotion={reducedMotion}
				/>
			</Panel>
		);
	}
	if (step === undefined) {
		return (
			<Panel
				size={UDim2.fromScale(1, 1)}
				accent={Palette.violet}
				background={Palette.panelRaised}
				padding={stack ? 14 : 16}
				clips={false}
			>
				<EmptyState
					icon="Forge.11"
					title="Forge Path isn't ready"
					body="Check back in a moment."
					accent={Palette.violet}
					compact={true}
					size={UDim2.fromScale(1, 1)}
					reducedMotion={reducedMotion}
				/>
			</Panel>
		);
	}
	const progressFrac = math.clamp(xp / math.max(1, step.XPCost), 0, 1);
	const needXp = !ready && xp < step.XPCost;
	return (
		<Panel
			size={UDim2.fromScale(1, 1)}
			accent={ready ? step.Color : Palette.violet}
			background={Palette.panelRaised}
			padding={stack ? 14 : 16}
			highlight={ready}
			reducedMotion={reducedMotion}
			clips={false}
		>
			<Text
				value={ready ? "READY TO CLAIM" : "NEXT STEP"}
				size={10}
				color={ready ? step.Color : Palette.violet}
				weight={Enum.FontWeight.Heavy}
				sizeConstraint={new UDim2(1, stack ? 0 : -180, 0, 16)}
			/>
			<Text
				value={`Step ${step.Step} · ${effectLabel(step)}`}
				size={stack ? 18 : 22}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				position={UDim2.fromOffset(0, 18)}
				sizeConstraint={new UDim2(1, stack ? 0 : -180, 0, 28)}
			/>
			<Text
				value={needXp ? (guide?.NeedXp ?? "Bank Flux to earn Forge Path XP.") : formatReward(step.Reward as Reward | undefined)}
				size={11}
				color={needXp ? Palette.creamSoft : Palette.mango}
				wrap={true}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(0, 50)}
				sizeConstraint={new UDim2(1, stack ? 0 : -180, 0, 32)}
			/>
			<Meter
				value={progressFrac}
				color={ready ? step.Color : Palette.violet}
				reducedMotion={reducedMotion}
				shimmer={ready}
				position={UDim2.fromOffset(0, stack ? 96 : 92)}
				size={new UDim2(1, stack ? 0 : -180, 0, 8)}
			/>
			<Text
				value={`${compactNumber(math.min(xp, step.XPCost))} / ${compactNumber(step.XPCost)} XP`}
				size={10}
				color={Palette.muted}
				weight={Enum.FontWeight.Bold}
				position={UDim2.fromOffset(0, stack ? 110 : 106)}
				sizeConstraint={new UDim2(1, stack ? 0 : -180, 0, 16)}
			/>
			{stack ? (
				<frame
					{...named("ForgePathClaimActions")}
					Size={new UDim2(1, 0, 0, TapTarget)}
					Position={new UDim2(0, 0, 1, -TapTarget)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					ClipsDescendants={false}
					ref={claimHostRef}
				>
					<Button
						text={ready ? "CLAIM NOW" : "NEED MORE XP"}
						icon={ready ? "Check.7" : undefined}
						onClick={() => onClaim(step.Step)}
						color={ready ? step.Color : Palette.panelSoft}
						textColor={ready ? Palette.ink : Palette.muted}
						size={UDim2.fromScale(1, 1)}
						reducedMotion={reducedMotion}
						disabled={!ready}
						highlight={ready}
					/>
				</frame>
			) : (
				<frame
					{...named("ForgePathClaimActions")}
					Size={UDim2.fromOffset(160, TapTarget)}
					Position={new UDim2(1, -160, 0.5, -TapTarget / 2)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					ClipsDescendants={false}
					ref={claimHostRef}
				>
					<Button
						text={ready ? "CLAIM NOW" : "NEED XP"}
						icon={ready ? "Check.8" : undefined}
						onClick={() => onClaim(step.Step)}
						color={ready ? step.Color : Palette.panelSoft}
						textColor={ready ? Palette.ink : Palette.muted}
						size={UDim2.fromScale(1, 1)}
						reducedMotion={reducedMotion}
						disabled={!ready}
						highlight={ready}
					/>
				</frame>
			)}
		</Panel>
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
	const listGap = stack ? chrome.panelGap : Layout.panelGap;
	const headerH = stack ? 148 : 128;
	const spotlightH = stack ? SPOTLIGHT_H_STACK : SPOTLIGHT_H;
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
	return (
		<PageScaffold
			gap={listGap}
			tailPad={scrollTail(stack, chrome.bottomSafe, 48)}
			scrollBarColor={Palette.violet}
			scrollBarThickness={4}
			sections={[
				{
					id: "hero",
					height: headerH,
					element: (
						<Panel
							size={UDim2.fromScale(1, 1)}
							accent={Palette.violet}
							background={Palette.panelRaised}
							padding={stack ? 14 : 16}
							reveal={headerReveal}
							clips={false}
						>
							<IconTile
								kind="Forge"
								accent={Palette.violet}
								size={stack ? 48 : 56}
								radius={14}
								position={UDim2.fromOffset(0, stack ? 4 : 18)}
								glow={true}
								spin={false}
								reducedMotion={softMotion}
							/>
							<Text
								value="FORGE PATH"
								size={10}
								color={Palette.violet}
								weight={Enum.FontWeight.Heavy}
								position={UDim2.fromOffset(stack ? 0 : 72, stack ? 60 : 0)}
								sizeConstraint={new UDim2(1, stack ? -8 : -220, 0, 16)}
							/>
							<Text
								value={heroBlurb}
								size={stack ? 16 : 18}
								color={Palette.cream}
								weight={Enum.FontWeight.Heavy}
								fit={true}
								minSize={10}
								wrap={true}
								position={UDim2.fromOffset(stack ? 0 : 72, stack ? 78 : 16)}
								sizeConstraint={new UDim2(1, stack ? -8 : -292, 0, 44)}
							/>
							<Meter
								value={progressFrac}
								color={Palette.violet}
								reducedMotion={softMotion}
								shimmer={nextReady}
								position={UDim2.fromOffset(stack ? 0 : 72, stack ? 114 : 56)}
								size={new UDim2(1, stack ? -8 : -292, 0, 8)}
							/>
							<Text
								value={`${claimedCount} / ${totalCount} steps claimed  ·  ${compactNumber(forgePath.XP)} XP banked`}
								size={11}
								color={Palette.creamSoft}
								wrap={true}
								fit={true}
								minSize={9}
								position={UDim2.fromOffset(stack ? 0 : 72, stack ? 126 : 70)}
								sizeConstraint={new UDim2(1, stack ? -8 : -292, 0, 24)}
							/>
							{!stack && (
								<frame
									Size={new UDim2(0, 200, 0, 40)}
									Position={new UDim2(1, -200, 0.5, -20)}
									BackgroundTransparency={1}
									BorderSizePixel={0}
								>
									<Text
										value={`${compactNumber(forgePath.XP)}`}
										size={26}
										color={Palette.violet}
										weight={Enum.FontWeight.Heavy}
										fit={true}
										position={UDim2.fromOffset(0, 0)}
										sizeConstraint={new UDim2(1, 0, 0, 32)}
									/>
									<Text
										value="FORGE XP"
										size={10}
										color={Palette.muted}
										weight={Enum.FontWeight.Bold}
										fit={true}
										position={UDim2.fromOffset(0, 34)}
										sizeConstraint={new UDim2(1, 0, 0, 14)}
									/>
								</frame>
							)}
						</Panel>
					),
				},
				{
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
				},
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

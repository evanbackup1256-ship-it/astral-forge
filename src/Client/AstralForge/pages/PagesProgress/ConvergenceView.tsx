import React from "@rbxts/react";
import { clockText, compactNumber, formatReward, Reward } from "../../CoreKit/format";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { chromeFor, Palette, scrollTail } from "../../CoreKit/theme";
import { useEntrance, useStagger, useViewport, useWallClock } from "../../MotionKit/motion";
import { loadPageScaffold, loadUi, named } from "../luauDeps";

const UserInputService = game.GetService("UserInputService");
const { Badge, Button, Meter, Panel, SectionLabel, Text } = loadUi();
const PageScaffold = loadPageScaffold();

const SECTION_LABEL_H = 28;

interface ConvergenceTier {
	Tier: number;
	Required: number;
	CanClaim: boolean;
	Claimed: boolean;
	Reward?: Reward;
}
interface ConvergenceEvent {
	EventId?: string;
	Name: string;
	PhaseName: string;
	EndsAt: number;
	GlobalContribution: number;
	GlobalTarget: number;
	PersonalContribution: number;
	ProductionMultiplier: number;
	Tiers?: ConvergenceTier[];
}
interface ConvergenceState {
	Convergence?: ConvergenceEvent;
	[key: string]: unknown;
}
type Dispatch = (action: string, payload?: object) => unknown;
interface ConvergenceViewProps {
	state: ConvergenceState;
	dispatch: Dispatch;
	reducedMotion?: boolean;
}
interface Section {
	id: string;
	height?: number;
	fill?: boolean;
	minHeight?: number;
	element: React.Element;
}

function ConvergenceViewReady(props: ConvergenceViewProps) {
	const state = props.state;
	const dispatch = props.dispatch;
	const reducedMotion = props.reducedMotion;
	const event = state.Convergence as ConvergenceEvent;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const softMotion = reducedMotion;
	const stack = chrome.contentStack;
	const now = useWallClock(event !== undefined);
	const reveal = useStagger(0, softMotion);
	const revealTiers = useStagger(1, softMotion);
	const revealClaim = useStagger(2, softMotion);
	const revealHero = useStagger(3, softMotion);
	const revealFill = useStagger(4, softMotion);
	const globalFill = math.clamp(event.GlobalContribution / math.max(1, event.GlobalTarget), 0, 1);
	const tiers = event.Tiers ?? [];
	const heroHeight = stack ? 226 : 198;
	const tierHeight = stack ? 154 : 94;
	const pageGap = 12;
	const tiersH = tiers.size() > 0 ? tiers.size() * tierHeight + math.max(0, tiers.size() - 1) * pageGap : 0;
	const claimHostRef = React.useRef<Frame>();
	let firstClaimTier: number | undefined;
	for (const tier of tiers) {
		if (tier.CanClaim) {
			firstClaimTier = tier.Tier;
			break;
		}
	}
	React.useEffect(() => {
		if (firstClaimTier === undefined || !UserInputService.GamepadEnabled) {
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
	}, [firstClaimTier, event.EventId]);
	const heroPanel = (
		<Panel
			size={UDim2.fromScale(1, 1)}
			accent={Palette.mango}
			background={Palette.panelRaised}
			padding={16}
			reveal={reveal}
			reducedMotion={softMotion}
			clips={false}
		>
			<Text
				value="WEEKLY COOPERATIVE EVENT"
				size={10}
				color={Palette.mango}
				weight={Enum.FontWeight.Heavy}
				sizeConstraint={new UDim2(1, -120, 0, 16)}
			/>
			<Text
				value={event.Name}
				size={stack ? 25 : 31}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={18}
				position={UDim2.fromOffset(0, 22)}
				sizeConstraint={new UDim2(1, -8, 0, 42)}
			/>
			<Text
				value="Everyone contributes to the same weekly forge. Finish each phase together to unlock a global production boost."
				size={11}
				color={Palette.creamSoft}
				wrap={true}
				position={UDim2.fromOffset(0, 68)}
				sizeConstraint={new UDim2(1, -8, 0, 38)}
			/>
			<Badge value={event.PhaseName} accent={Palette.mango} filled={true} position={new UDim2(0, 0, 1, -68)} size={UDim2.fromOffset(112, 28)} />
			<Text
				value={now.map((timestamp) => `${clockText(math.max(0, event.EndsAt - timestamp))} LEFT`)}
				size={10}
				color={Palette.muted}
				weight={Enum.FontWeight.Bold}
				align={Enum.TextXAlignment.Right}
				position={new UDim2(1, -150, 1, -68)}
				sizeConstraint={UDim2.fromOffset(150, 28)}
			/>
			<Meter
				value={globalFill}
				color={Palette.mango}
				position={new UDim2(0, 0, 1, -28)}
				size={new UDim2(1, 0, 0, 9)}
				reducedMotion={softMotion}
				shimmer={true}
			/>
			<Text
				value={`${compactNumber(event.GlobalContribution)} / ${compactNumber(event.GlobalTarget)}  •  ${string.format("%.2fx", event.ProductionMultiplier)} PRODUCTION`}
				size={10}
				color={Palette.creamSoft}
				fit={true}
				minSize={8}
				position={new UDim2(0, 0, 1, -18)}
				sizeConstraint={new UDim2(1, 0, 0, 18)}
			/>
		</Panel>
	);
	const tierPanels = tiers.map((tier, index) => {
		const progress = math.clamp(event.PersonalContribution / math.max(1, tier.Required), 0, 1);
		const buttonColor = tier.CanClaim ? Palette.mint : tier.Claimed ? Palette.panelSoft : Palette.violet;
		const tierReveal = tier.CanClaim ? revealClaim : revealTiers;
		return (
			<Panel
				key={`tier-${tier.Tier}`}
				size={new UDim2(1, 0, 0, tierHeight)}
				accent={tier.CanClaim ? Palette.mint : Palette.violet}
				padding={13}
				layoutOrder={index}
				reveal={tierReveal}
				interactive={tier.CanClaim}
				reducedMotion={softMotion}
				clips={false}
			>
				<Text
					value={`TIER ${tier.Tier}  •  ${compactNumber(event.PersonalContribution)} / ${compactNumber(tier.Required)}`}
					size={11}
					color={tier.CanClaim ? Palette.mint : Palette.creamSoft}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					minSize={8}
					sizeConstraint={new UDim2(1, stack ? 0 : -170, 0, 19)}
				/>
				<Text
					value={formatReward(tier.Reward)}
					size={10}
					color={Palette.muted}
					fit={true}
					minSize={8}
					position={UDim2.fromOffset(0, 25)}
					sizeConstraint={new UDim2(1, stack ? 0 : -170, 0, 18)}
				/>
				<Meter
					value={progress}
					color={tier.CanClaim ? Palette.mint : Palette.violet}
					position={stack ? UDim2.fromOffset(0, 54) : new UDim2(0, 0, 1, -12)}
					size={new UDim2(1, stack ? 0 : -170, 0, 6)}
					reducedMotion={softMotion}
					shimmer={tier.CanClaim && !softMotion}
				/>
				<frame
					{...named("ConvergenceClaimActions")}
					Size={stack ? new UDim2(1, 0, 0, 48) : UDim2.fromOffset(150, 48)}
					Position={stack ? new UDim2(0, 0, 1, -48) : new UDim2(1, -150, 0.5, -24)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					ClipsDescendants={false}
					ref={tier.Tier === firstClaimTier ? claimHostRef : undefined}
				>
					<Button
						text={tier.Claimed ? "CLAIMED" : tier.CanClaim ? "CLAIM" : "LOCKED"}
						icon={tier.Claimed ? "Check.9" : "Gift.8"}
						onClick={() => {
							if (tier.CanClaim) {
								dispatch("ClaimConvergenceReward", { Tier: tier.Tier });
							}
						}}
						color={buttonColor}
						textColor={tier.CanClaim ? Palette.ink : Palette.creamSoft}
						disabled={!tier.CanClaim}
						size={UDim2.fromScale(1, 1)}
						reducedMotion={softMotion}
						highlight={tier.CanClaim && !softMotion}
					/>
				</frame>
			</Panel>
		);
	});
	const sections: Section[] = [
		{
			id: "hero",
			height: heroHeight,
			element: heroPanel,
		},
		{
			id: "tiers-label",
			height: SECTION_LABEL_H,
			element: <SectionLabel value="YOUR CONTRIBUTION REWARDS" color={Palette.violet} />,
		},
	];
	if (tiersH > 0) {
		sections.push({
			id: "tiers",
			height: tiersH,
			element: (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
					<uilistlayout
						FillDirection={Enum.FillDirection.Vertical}
						SortOrder={Enum.SortOrder.LayoutOrder}
						Padding={new UDim(0, pageGap)}
					/>
					{tierPanels}
				</frame>
			),
		});
	}
	return (
		<PageScaffold
			gap={pageGap}
			tailPad={scrollTail(chrome.stack, chrome.bottomSafe, 80)}
			scrollBarColor={Palette.mango}
			scrollBarThickness={4}
			sections={sections}
		/>
	);
}

function ConvergenceView(props: ConvergenceViewProps) {
	const state = props.state;
	const reducedMotion = props.reducedMotion;
	const event = state.Convergence;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const softMotion = reducedMotion;
	const now = useWallClock(event !== undefined);
	const enter = useEntrance(softMotion);
	const reveal = useStagger(0, softMotion);
	const revealTiers = useStagger(1, softMotion);
	const revealClaim = useStagger(2, softMotion);
	const revealHero = useStagger(3, softMotion);
	const revealFill = useStagger(4, softMotion);
	const convergenceSoft = softMotion === true || revealHero === undefined || revealFill === undefined;
	if (event === undefined) {
		return (
			<Panel
				size={UDim2.fromScale(1, 1)}
				accent={Palette.mango}
				padding={22}
				reveal={softMotion ? revealHero : enter}
				highlight={!convergenceSoft}
				reducedMotion={softMotion}
			>
				<Text value="FORGE CONVERGENCE" size={26} weight={Enum.FontWeight.Heavy} />
				<Text
					value="Getting this week's shared forge ready…"
					size={12}
					color={Palette.muted}
					position={UDim2.fromOffset(0, 42)}
					sizeConstraint={new UDim2(1, 0, 0, 30)}
				/>
			</Panel>
		);
	}
	return <ConvergenceViewReady {...props} />;
}

export = { ConvergenceView };

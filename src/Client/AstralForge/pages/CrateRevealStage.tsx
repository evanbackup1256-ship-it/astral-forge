// Astral Forge v2: Cinematic Crate Reveal Stage
// AAA tactile physics, physical collectible card presentation,
// center-lock reticle framing, holographic prismatic foil shaders,
// and omni-platform gamepad/touch certification.
// 100% Declarative React 17 (@rbxts/react). Zero imperative UI widgets.
import React from "@rbxts/react";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { darken, lighten, Palette, TapTarget } from "../CoreKit/theme";
import { useAntilag } from "../MotionKit/antilag";
import { ScaleFromCenter } from "../MotionKit/motion";
import Rainbow = require("../Rainbow");
import { AudioPlayer, kitMember, LuauComponent } from "./luauKits";

const UserInputService = game.GetService("UserInputService");
const RunService = game.GetService("RunService");

const { Audio } = kitMember<{ Audio: AudioPlayer }>("AudioKit", "audio");
const { itemIconKind } = kitMember<{ itemIconKind: (this: void, definitionId: unknown) => string }>("ArtKit", "Icon");
const { Badge, Button, IconTile, Panel, Text } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");

function easeOutExpo(t: number): number {
	return t === 1 ? 1 : 1 - math.pow(2, -10 * t);
}

function easeOutBack(t: number): number {
	const c1 = 1.70158;
	const c3 = 1.70158 + 1;
	return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2);
}

// holographic foil: the full wheel at even brightness, so it reads as foil catching light rather
// than five pastel stripes
const HOLO_GRADIENT = Rainbow.loop("soft");

const shimmerClock = React.createContext<React.Binding<number>>(undefined as unknown as React.Binding<number>);

function useShimmerClock(): React.Binding<number> {
	return React.useContext(shimmerClock);
}

function ShimmerProvider(props: { children?: React.ReactNode }) {
	const [clock, setClock] = React.useBinding(0);
	React.useEffect(() => {
		const conn = RunService.RenderStepped.Connect((dt) => {
			setClock((clock.getValue() + dt * 0.72) % 1);
		});
		return () => {
			conn.Disconnect();
		};
	}, []);
	return <shimmerClock.Provider value={clock}>{props.children}</shimmerClock.Provider>;
}

interface LayoutInput {
	portrait?: boolean;
	sideSafe: number;
	viewportWidth: number;
	viewportHeight: number;
	shortLandscape?: boolean;
	topInset: number;
	bottomSafe: number;
}

interface StageLayout {
	compactHeight: boolean;
	headerSize: UDim2;
	headerPosition: UDim2;
	headerAnchor: Vector2;
	stageSize: UDim2;
	stagePosition: UDim2;
	stageAnchor: Vector2;
	reelWidth: number;
	reelHeight: number;
	resultSize: UDim2;
	resultPosition: UDim2;
	resultAnchor: Vector2;
	actionSize: UDim2;
	actionPosition: UDim2;
	actionAnchor: Vector2;
}

function resolveLayout(props: LayoutInput): StageLayout {
	const edge = props.portrait ? 10 : 18;
	const leftEdge = edge + props.sideSafe;
	const rightEdge = edge + props.sideSafe;
	const usableWidth = math.max(1, props.viewportWidth - leftEdge - rightEdge);
	if (props.shortLandscape) {
		const columnGap = 12;
		const availableRight = math.max(1, usableWidth - columnGap - 1);
		const rightWidth = math.min(availableRight, math.min(218, math.max(132, math.floor(usableWidth * 0.36))));
		const leftWidth = math.max(1, usableWidth - columnGap - rightWidth);
		const headerTop = props.topInset + 5;
		const headerHeight = 52;
		const stageTop = headerTop + headerHeight + 8;
		const stageBottom = props.viewportHeight - props.bottomSafe - 8;
		const stageHeight = math.max(1, math.min(202, stageBottom - stageTop));
		return {
			compactHeight: false,
			headerSize: UDim2.fromOffset(leftWidth, headerHeight),
			headerPosition: UDim2.fromOffset(leftEdge, headerTop),
			headerAnchor: Vector2.zero,
			stageSize: UDim2.fromOffset(leftWidth, stageHeight),
			stagePosition: UDim2.fromOffset(leftEdge, stageTop),
			stageAnchor: Vector2.zero,
			reelWidth: math.max(1, leftWidth - 24),
			reelHeight: math.max(1, stageHeight - 58),
			resultSize: UDim2.fromOffset(rightWidth, 126),
			resultPosition: new UDim2(1, -rightEdge, 0, props.topInset + 12),
			resultAnchor: new Vector2(1, 0),
			actionSize: UDim2.fromOffset(rightWidth, TapTarget),
			actionPosition: new UDim2(1, -rightEdge, 1, -(props.bottomSafe + 8)),
			actionAnchor: new Vector2(1, 1),
		};
	}
	if (props.viewportHeight < 540) {
		const stageWidth = math.min(usableWidth, 390);
		const headerTop = props.topInset + 4;
		const headerHeight = 44;
		const actionBottom = props.bottomSafe + 8;
		const actionTop = props.viewportHeight - actionBottom - TapTarget;
		const stageTop = headerTop + headerHeight + 6;
		const stageBottom = math.max(stageTop + 1, actionTop - 8);
		const stageHeight = stageBottom - stageTop;
		const resultHeight = math.max(1, math.min(100, stageHeight - 12));
		return {
			compactHeight: true,
			headerSize: UDim2.fromOffset(stageWidth, headerHeight),
			headerPosition: new UDim2(0.5, 0, 0, headerTop),
			headerAnchor: new Vector2(0.5, 0),
			stageSize: UDim2.fromOffset(stageWidth, stageHeight),
			stagePosition: new UDim2(0.5, 0, 0, stageTop),
			stageAnchor: new Vector2(0.5, 0),
			reelWidth: math.max(1, stageWidth - 24),
			reelHeight: math.max(1, stageHeight - 58),
			resultSize: UDim2.fromOffset(math.max(1, stageWidth - 24), resultHeight),
			resultPosition: UDim2.fromOffset(math.floor(props.viewportWidth / 2), math.floor(stageTop + stageHeight / 2)),
			resultAnchor: new Vector2(0.5, 0.5),
			actionSize: UDim2.fromOffset(stageWidth, TapTarget),
			actionPosition: new UDim2(0.5, 0, 1, -actionBottom),
			actionAnchor: new Vector2(0.5, 1),
		};
	}
	const stageWidth = math.min(usableWidth, props.portrait ? 390 : 850);
	const stageHeight = props.portrait
		? math.clamp(math.floor(props.viewportHeight * 0.37), 204, 232)
		: math.clamp(math.floor(props.viewportHeight * 0.38), 232, 286);
	const headerHeight = props.portrait ? 74 : 82;
	const resultHeight = props.portrait ? 88 : 94;
	const resultWidth = math.min(props.portrait ? stageWidth : 470, usableWidth);
	const actionWidth = math.min(props.portrait ? stageWidth : 260, usableWidth);
	const actionBottom = props.bottomSafe + 10;
	const resultBottom = actionBottom + TapTarget + 10;
	const freeTop = props.topInset + headerHeight + 16;
	const freeBottom = props.viewportHeight - resultBottom - resultHeight - 10;
	const stageCenter = math.floor((freeTop + freeBottom) * 0.5);
	return {
		compactHeight: false,
		headerSize: UDim2.fromOffset(math.min(stageWidth, 620), headerHeight),
		headerPosition: new UDim2(0.5, 0, 0, props.topInset + 8),
		headerAnchor: new Vector2(0.5, 0),
		stageSize: UDim2.fromOffset(stageWidth, stageHeight),
		stagePosition: UDim2.fromOffset(math.floor(props.viewportWidth / 2), stageCenter),
		stageAnchor: new Vector2(0.5, 0.5),
		reelWidth: math.max(1, stageWidth - 24),
		reelHeight: stageHeight - 58,
		resultSize: UDim2.fromOffset(resultWidth, resultHeight),
		resultPosition: new UDim2(0.5, 0, 1, -resultBottom),
		resultAnchor: new Vector2(0.5, 1),
		actionSize: UDim2.fromOffset(actionWidth, TapTarget),
		actionPosition: new UDim2(0.5, 0, 1, -actionBottom),
		actionAnchor: new Vector2(0.5, 1),
	};
}

interface ReelCardData {
	key: string;
	rarity: string;
	accent: Color3;
	definitionId: unknown;
	name: string;
	winner?: boolean;
}

interface StageProps extends LayoutInput {
	phase: string;
	reducedMotion?: boolean;
	allowAmbient?: boolean;
	winnerAccent: Color3;
	sessionAccent: Color3;
	winnerRarity: string;
	winnerName: string;
	climbColor?: Color3;
	crateName: string;
	rollCount: number;
	rollIndex: number;
	spinEnergy: React.Binding<number>;
	tickEnergy: React.Binding<number>;
	spinProgress: React.Binding<number>;
	reelOffset: React.Binding<number>;
	winnerCardScale: React.Binding<number>;
	landFlash: React.Binding<number>;
	landPop: React.Binding<number>;
	claimSlide: React.Binding<number>;
	visualShow: React.Binding<number>;
	shellScale?: number | React.Binding<number>;
	cards: ReelCardData[];
	economyMode?: boolean;
	stride: number;
	cardWidth: number;
	cardHeight: number;
	fxBudget: number;
	resultDetail: string;
	resultTag: string;
	claimText: string;
	onQuickLand: () => void;
	onClaim: () => void;
	[key: string]: unknown;
}

interface SectionProps {
	props: StageProps;
	layout: StageLayout;
}

function stageCenterOf(layout: StageLayout) {
	return new UDim2(
		layout.stagePosition.X.Scale,
		layout.stagePosition.X.Offset + (0.5 - layout.stageAnchor.X) * layout.stageSize.X.Offset,
		layout.stagePosition.Y.Scale,
		layout.stagePosition.Y.Offset + (0.5 - layout.stageAnchor.Y) * layout.stageSize.Y.Offset,
	);
}

function isLanded(phase: string) {
	return phase === "land" || phase === "done" || phase === "exit";
}

// Cinematic atmospheric stage lighting (replaces cluttered grid lines)
function CinematicBackdrop({ props: p, layout }: SectionProps) {
	const landed = isLanded(p.phase);
	const center = stageCenterOf(layout);
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={405} Active={false}>
			{/* Soft central ambient spotlight */}
			<frame
				Size={UDim2.fromOffset(layout.stageSize.X.Offset + 120, layout.stageSize.Y.Offset + 100)}
				Position={center}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundColor3={landed ? p.winnerAccent : p.sessionAccent}
				BackgroundTransparency={p.spinEnergy.map((e) => {
					const base = landed ? 0.88 : 0.94;
					return math.clamp(base - e * 0.08, 0, 1);
				})}
				BorderSizePixel={0}
				ZIndex={405}
			>
				<uicorner CornerRadius={new UDim(0, 32)} />
				<uigradient
					Transparency={
						new NumberSequence([
							new NumberSequenceKeypoint(0, 0),
							new NumberSequenceKeypoint(0.65, 0.5),
							new NumberSequenceKeypoint(1, 1),
						])
					}
				/>
			</frame>
			{/* Stage horizontal grounding aura */}
			<frame
				Size={new UDim2(0.85, 0, 0, 1)}
				Position={
					new UDim2(0.5, 0, layout.stagePosition.Y.Scale, layout.stagePosition.Y.Offset + layout.stageSize.Y.Offset / 2 + 18)
				}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundColor3={landed ? p.winnerAccent : p.sessionAccent}
				BackgroundTransparency={0.65}
				BorderSizePixel={0}
				ZIndex={406}
			>
				<uigradient
					Transparency={
						new NumberSequence([
							new NumberSequenceKeypoint(0, 1),
							new NumberSequenceKeypoint(0.5, 0),
							new NumberSequenceKeypoint(1, 1),
						])
					}
				/>
			</frame>
		</frame>
	);
}

// Clean, human-designed cinematic header (no buzzword salad)
function CinematicHeader({ props: p, layout }: SectionProps) {
	const landed = isLanded(p.phase);
	const narrowShort = p.shortLandscape && layout.headerSize.X.Offset < 260;
	const simplifiedHeader = narrowShort || layout.compactHeight;

	const statusText =
		p.phase === "charge" || p.phase === "seal"
			? "SEAL UNLOCKED"
			: p.phase === "spin"
				? "SELECTING RELIC..."
				: p.phase === "climb"
					? "RESONANCE SURGE"
					: landed
						? `${p.winnerRarity.upper()} RELIC`
						: "RELIC VAULT";

	const statusColor = landed
		? p.winnerAccent
		: p.phase === "climb"
			? (p.climbColor ?? Palette.violet)
			: p.phase === "spin"
				? Palette.cyan
				: Palette.muted;

	return (
		<frame
			Size={layout.headerSize}
			Position={layout.headerPosition}
			AnchorPoint={layout.headerAnchor}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={420}
		>
			{!simplifiedHeader && (
				<Text
					value="RELIC FORGE"
					size={10}
					color={p.sessionAccent}
					weight={Enum.FontWeight.Heavy}
					align={p.shortLandscape ? Enum.TextXAlignment.Left : Enum.TextXAlignment.Center}
					sizeConstraint={new UDim2(1, p.shortLandscape ? -128 : 0, 0, 14)}
					zIndex={421}
				/>
			)}
			<Text
				value={p.crateName}
				size={p.shortLandscape ? 20 : p.portrait ? 22 : 26}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				align={p.shortLandscape && !simplifiedHeader ? Enum.TextXAlignment.Left : Enum.TextXAlignment.Center}
				fit={true}
				minSize={12}
				position={UDim2.fromOffset(0, simplifiedHeader ? 0 : p.shortLandscape ? 14 : 15)}
				sizeConstraint={new UDim2(1, p.shortLandscape && !simplifiedHeader ? -128 : 0, 0, p.shortLandscape ? 26 : 32)}
				zIndex={421}
			/>
			{/* Clean status pill & drop count */}
			<frame
				Size={
					simplifiedHeader
						? new UDim2(1, 0, 0, 16)
						: p.shortLandscape
							? UDim2.fromOffset(136, 32)
							: new UDim2(1, 0, 0, 16)
				}
				Position={
					simplifiedHeader
						? UDim2.fromOffset(0, 26)
						: p.shortLandscape
							? new UDim2(1, -136, 0, 6)
							: UDim2.fromOffset(0, 50)
				}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ZIndex={421}
			>
				<Text
					value={p.rollCount > 1 ? `${statusText}  â€¢  DROP ${p.rollIndex + 1}/${p.rollCount}` : statusText}
					size={10}
					color={statusColor}
					weight={Enum.FontWeight.Bold}
					align={p.shortLandscape && !simplifiedHeader ? Enum.TextXAlignment.Right : Enum.TextXAlignment.Center}
					fit={true}
					minSize={8}
					sizeConstraint={UDim2.fromScale(1, 1)}
					zIndex={421}
				/>
			</frame>
			{/* Batch progress bar if multiple rolls */}
			{p.rollCount > 1 && !p.shortLandscape && !layout.compactHeight && (
				<frame
					Size={UDim2.fromOffset(math.min(180, p.rollCount * 28), 3)}
					Position={new UDim2(0.5, 0, 1, -1)}
					AnchorPoint={new Vector2(0.5, 1)}
					BackgroundColor3={Palette.line}
					BorderSizePixel={0}
					ZIndex={421}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
					<frame
						Size={new UDim2(math.clamp((p.rollIndex + 1) / math.max(1, p.rollCount), 0, 1), 0, 1, 0)}
						BackgroundColor3={landed ? p.winnerAccent : p.sessionAccent}
						BorderSizePixel={0}
						ZIndex={422}
					>
						<uicorner CornerRadius={new UDim(1, 0)} />
					</frame>
				</frame>
			)}
		</frame>
	);
}

interface ReelCardProps {
	card: ReelCardData;
	x: number;
	width: number;
	height: number;
	emphasize: boolean;
	detailed: boolean;
	fitScale: number;
	reducedMotion?: boolean;
	winnerScale: React.Binding<number>;
	shimmerPhase: number;
}

// Physical collectible holographic card
function ReelCard({ card, x, width, height, emphasize, detailed, fitScale, reducedMotion, winnerScale, shimmerPhase }: ReelCardProps) {
	const clock = useShimmerClock();
	const scale = emphasize ? winnerScale.map((amount) => amount * fitScale) : 0.94 * fitScale;
	const cardZ = emphasize ? 438 : 431;

	const shimmerX = React.joinBindings([clock]).map((vals) => {
		const t = (vals[0] + shimmerPhase) % 1;
		const sweep = t < 0.22 ? easeOutExpo(t / 0.22) : t < 0.35 ? 1 - (t - 0.22) / 0.13 : -0.15;
		return new UDim2(sweep, -28, 0, 0);
	});

	const isHolo =
		card.rarity === "Mythic" ||
		card.rarity === "Celestial" ||
		card.rarity === "Astral" ||
		(emphasize && card.rarity === "Legendary");

	return (
		<frame
			Size={UDim2.fromOffset(width, height)}
			Position={UDim2.fromOffset(x, 0)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={cardZ}
		>
			{/* Radiant outer aura for landed winning card */}
			{emphasize && !reducedMotion && (
				<frame
					Size={new UDim2(1, 24, 1, 24)}
					Position={UDim2.fromScale(0.5, 0.5)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					ZIndex={cardZ - 1}
				>
					<uistroke
						Color={lighten(card.accent, 0.28)}
						Thickness={3}
						Transparency={winnerScale.map((amt) => math.clamp(1 - amt * 0.75, 0.05, 1))}
					/>
					<uicorner CornerRadius={new UDim(0, 18)} />
				</frame>
			)}

			{/* Scaled Card Body */}
			<frame
				Size={UDim2.fromScale(1, 1)}
				Position={UDim2.fromScale(0.5, 0.5)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ZIndex={cardZ}
			>
				<uiscale Scale={scale} />
				{/* Card drop shadow */}
				<frame
					Size={new UDim2(1, -6, 1, -8)}
					Position={UDim2.fromOffset(3, 5)}
					BackgroundColor3={Color3.fromRGB(0, 0, 0)}
					BackgroundTransparency={0.42}
					BorderSizePixel={0}
					ZIndex={cardZ}
				>
					<uicorner CornerRadius={new UDim(0, 14)} />
				</frame>

				{/* Card Face Chassis */}
				<frame
					Size={new UDim2(1, -4, 1, -4)}
					BackgroundColor3={Palette.panelRaised}
					BorderSizePixel={0}
					ZIndex={cardZ + 1}
					ClipsDescendants={true}
				>
					<uicorner CornerRadius={new UDim(0, 14)} />
					{/* Sleek metallic stroke colored by rarity */}
					<uistroke
						Color={emphasize ? lighten(card.accent, 0.3) : card.accent}
						Thickness={emphasize ? 2.2 : 1}
						Transparency={emphasize ? 0.04 : 0.42}
					/>
					<uigradient
						Color={new ColorSequence(lighten(Palette.panelRaised, 0.06), darken(Palette.panelRaised, 0.16))}
						Rotation={90}
					/>
					{/* Top rarity gem pip socket */}
					<frame
						Size={UDim2.fromOffset(8, 8)}
						Position={new UDim2(0.5, 0, 0, 8)}
						AnchorPoint={new Vector2(0.5, 0)}
						BackgroundColor3={card.accent}
						BorderSizePixel={0}
						ZIndex={cardZ + 3}
					>
						<uicorner CornerRadius={new UDim(1, 0)} />
					</frame>

					{/* Prismatic Holographic Foil Overlay (Mythic / Celestial / Astral) */}
					{isHolo && !reducedMotion && (
						<frame
							Size={new UDim2(1.8, 0, 1.8, 0)}
							Position={React.joinBindings([clock]).map((vals) => {
								const t = (vals[0] * 0.72 + shimmerPhase) % 1;
								const offset = -0.4 + t * 1.4;
								return new UDim2(offset, 0, offset * 0.45, 0);
							})}
							AnchorPoint={new Vector2(0.5, 0.5)}
							BackgroundColor3={Color3.fromRGB(255, 255, 255)}
							BackgroundTransparency={0}
							BorderSizePixel={0}
							Rotation={32}
							ZIndex={cardZ + 4}
						>
							<uigradient
								Color={HOLO_GRADIENT}
								Transparency={
									new NumberSequence([
										new NumberSequenceKeypoint(0, 1),
										new NumberSequenceKeypoint(0.35, emphasize ? 0.62 : 0.82),
										new NumberSequenceKeypoint(0.5, emphasize ? 0.38 : 0.72),
										new NumberSequenceKeypoint(0.65, emphasize ? 0.62 : 0.82),
										new NumberSequenceKeypoint(1, 1),
									])
								}
							/>
						</frame>
					)}

					{/* Specular light sweep across card */}
					{!reducedMotion && (
						<frame
							Size={UDim2.fromOffset(32, height)}
							Position={shimmerX}
							AnchorPoint={new Vector2(0, 0)}
							BackgroundColor3={Color3.fromRGB(255, 255, 255)}
							BackgroundTransparency={0}
							BorderSizePixel={0}
							Rotation={14}
							ZIndex={cardZ + 5}
						>
							<uigradient
								Color={
									new ColorSequence([
										new ColorSequenceKeypoint(0, Palette.cream),
										new ColorSequenceKeypoint(0.5, Palette.cream),
										new ColorSequenceKeypoint(1, Palette.cream),
									])
								}
								Transparency={
									new NumberSequence([
										new NumberSequenceKeypoint(0, 1),
										new NumberSequenceKeypoint(0.35, emphasize ? 0.34 : 0.7),
										new NumberSequenceKeypoint(0.5, emphasize ? 0.18 : 0.54),
										new NumberSequenceKeypoint(0.65, emphasize ? 0.34 : 0.7),
										new NumberSequenceKeypoint(1, 1),
									])
								}
							/>
						</frame>
					)}

					{/* Card Glyph & Typography */}
					{detailed ? (
						<>
							<IconTile
								kind={itemIconKind(card.definitionId)}
								accent={card.accent}
								size={50}
								radius={12}
								position={new UDim2(0.5, 0, 0, 22)}
								anchorPoint={new Vector2(0.5, 0)}
								reducedMotion={reducedMotion}
								glow={emphasize}
								filled={true}
								zIndex={cardZ + 3}
							/>
							<Badge
								value={card.rarity.upper()}
								accent={card.accent}
								filled={true}
								position={new UDim2(0.5, -46, 0, 78)}
								size={UDim2.fromOffset(92, 18)}
								zIndex={cardZ + 4}
							/>
							<Text
								value={card.name}
								size={11}
								color={Palette.cream}
								weight={Enum.FontWeight.Heavy}
								align={Enum.TextXAlignment.Center}
								fit={true}
								minSize={9}
								position={UDim2.fromOffset(6, 100)}
								sizeConstraint={new UDim2(1, -12, 0, 22)}
								zIndex={cardZ + 3}
							/>
						</>
					) : undefined}
				</frame>
			</frame>
		</frame>
	);
}

// Horizontal Reel Showcase Window with Center Lock Reticle
function ForgeReel({ props, layout }: SectionProps) {
	const landed = isLanded(props.phase);
	const cardFitScale = math.clamp(layout.reelHeight / 148, 0.75, 1);
	const selectorScale = props.tickEnergy.map((amount) => 1 + amount * 0.035);
	const progressWidth = props.spinProgress.map((amount) => new UDim2(math.clamp(amount, 0, 1), 0, 1, 0));
	const reticleAccent = landed ? props.winnerAccent : props.sessionAccent;

	const cardElements: React.Element[] = [];
	props.cards.forEach((card, index) => {
		// Luau position i = index + 1; it checked cards[i] (this card) and cards[i + 2]
		const two = props.cards[index + 2];
		const besideWinner = card.winner === true || (two !== undefined && two.winner === true);
		const position = index + 1;
		const detailed = !props.economyMode || position <= 4 || card.winner === true || besideWinner;
		cardElements.push(
			<ReelCard
				key={card.key}
				card={card}
				x={position * props.stride}
				width={props.cardWidth}
				height={props.cardHeight}
				emphasize={card.winner === true && landed}
				detailed={detailed}
				fitScale={cardFitScale}
				reducedMotion={props.reducedMotion}
				winnerScale={props.winnerCardScale}
				shimmerPhase={(position * 0.13) % 1}
			/>,
		);
	});

	return (
		<frame
			Size={layout.stageSize}
			Position={layout.stagePosition}
			AnchorPoint={layout.stageAnchor}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={425}
			ClipsDescendants={false}
		>
			{/* Showcase chassis shadow */}
			<frame
				Size={new UDim2(1, 4, 1, 6)}
				Position={UDim2.fromOffset(-2, 5)}
				BackgroundColor3={Color3.fromRGB(0, 0, 0)}
				BackgroundTransparency={0.35}
				BorderSizePixel={0}
				ZIndex={424}
			>
				<uicorner CornerRadius={new UDim(0, 16)} />
			</frame>

			{/* Showcase chassis body */}
			<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.panel} BorderSizePixel={0} ZIndex={425} ClipsDescendants={false}>
				<uicorner CornerRadius={new UDim(0, 16)} />
				<uistroke
					Color={landed ? props.winnerAccent : props.sessionAccent}
					Thickness={landed ? 2 : 1.25}
					Transparency={landed ? 0.08 : 0.35}
				/>
				<uigradient Color={new ColorSequence(lighten(Palette.panel, 0.035), darken(Palette.panel, 0.14))} Rotation={90} />

				{/* Reel viewing aperture (clips cards horizontally) */}
				<frame
					Size={UDim2.fromOffset(layout.reelWidth, layout.reelHeight)}
					Position={new UDim2(0.5, 0, 0.5, 0)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundColor3={Palette.void}
					BackgroundTransparency={0.04}
					BorderSizePixel={0}
					ZIndex={427}
					ClipsDescendants={true}
					Visible={!layout.compactHeight || !landed}
				>
					<uicorner CornerRadius={new UDim(0, 12)} />
					<uistroke Color={Palette.line} Thickness={1} Transparency={0.45} />

					{/* Moving cards track */}
					<ShimmerProvider>
						<frame
							Size={UDim2.fromOffset(props.cards.size() * props.stride, props.cardHeight)}
							Position={props.reelOffset.map((offset) =>
								UDim2.fromOffset(
									layout.reelWidth / 2 - props.cardWidth / 2 - offset,
									math.floor((layout.reelHeight - props.cardHeight) / 2),
								),
							)}
							BackgroundTransparency={1}
							BorderSizePixel={0}
							ZIndex={429}
						>
							{cardElements}
						</frame>
					</ShimmerProvider>

					{/* Left edge depth vignette */}
					<frame
						Size={new UDim2(0, math.min(64, layout.reelWidth * 0.18), 1, 0)}
						BackgroundColor3={Palette.void}
						BackgroundTransparency={0}
						BorderSizePixel={0}
						ZIndex={438}
					>
						<uigradient Transparency={new NumberSequence([new NumberSequenceKeypoint(0, 0), new NumberSequenceKeypoint(1, 1)])} />
					</frame>

					{/* Right edge depth vignette */}
					<frame
						Size={new UDim2(0, math.min(64, layout.reelWidth * 0.18), 1, 0)}
						Position={UDim2.fromScale(1, 0)}
						AnchorPoint={new Vector2(1, 0)}
						BackgroundColor3={Palette.void}
						BackgroundTransparency={0}
						BorderSizePixel={0}
						ZIndex={438}
					>
						<uigradient Transparency={new NumberSequence([new NumberSequenceKeypoint(0, 1), new NumberSequenceKeypoint(1, 0)])} />
					</frame>

					{/* Center target reticle bracket */}
					<frame
						Size={UDim2.fromOffset(props.cardWidth + 10, props.cardHeight + 6)}
						Position={UDim2.fromScale(0.5, 0.5)}
						AnchorPoint={new Vector2(0.5, 0.5)}
						BackgroundColor3={reticleAccent}
						BackgroundTransparency={landed ? 0.92 : 0.96}
						BorderSizePixel={0}
						ZIndex={439}
					>
						<uiscale Scale={selectorScale.map((amount) => amount * cardFitScale)} />
						<uicorner CornerRadius={new UDim(0, 14)} />
						<uistroke Color={reticleAccent} Thickness={landed ? 2.5 : 1.5} Transparency={landed ? 0.05 : 0.22} />
					</frame>

					{/* Center hairline alignment guide */}
					<frame
						Size={new UDim2(0, 1, 1, -8)}
						Position={UDim2.fromScale(0.5, 0.5)}
						AnchorPoint={new Vector2(0.5, 0.5)}
						BackgroundColor3={Palette.cream}
						BackgroundTransparency={props.tickEnergy.map((amount) => math.clamp(0.68 - amount * 0.42, 0.1, 1))}
						BorderSizePixel={0}
						ZIndex={440}
					/>
				</frame>

				{/* Top center reticle arrow notch */}
				<frame
					Size={UDim2.fromOffset(18, 9)}
					Position={new UDim2(0.5, 0, 0, 6)}
					AnchorPoint={new Vector2(0.5, 0)}
					BackgroundColor3={reticleAccent}
					BorderSizePixel={0}
					ZIndex={446}
				>
					<uicorner CornerRadius={new UDim(0, 3)} />
				</frame>

				{/* Bottom center reticle arrow notch */}
				<frame
					Size={UDim2.fromOffset(18, 9)}
					Position={new UDim2(0.5, 0, 1, -6)}
					AnchorPoint={new Vector2(0.5, 1)}
					BackgroundColor3={reticleAccent}
					BorderSizePixel={0}
					ZIndex={446}
				>
					<uicorner CornerRadius={new UDim(0, 3)} />
				</frame>

				{/* Bottom subtle spin progress line */}
				<frame
					Size={new UDim2(1, -24, 0, 2)}
					Position={new UDim2(0.5, 0, 1, -2)}
					AnchorPoint={new Vector2(0.5, 1)}
					BackgroundColor3={Palette.line}
					BorderSizePixel={0}
					ZIndex={447}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
					<frame Size={progressWidth} BackgroundColor3={reticleAccent} BorderSizePixel={0} ZIndex={448}>
						<uicorner CornerRadius={new UDim(1, 0)} />
					</frame>
				</frame>
			</frame>
		</frame>
	);
}

// Cinematic Landing Impact Visuals (lens flare, shockwave ring, radiant embers)
function LandingBurst({ props, layout }: SectionProps) {
	if (props.phase !== "land" && props.phase !== "climb") {
		return undefined;
	}
	const count = math.clamp(math.floor(6 + props.fxBudget * 8), 6, 14);
	const center = stageCenterOf(layout);

	const sparks: React.Element[] = [];
	if (!props.reducedMotion && props.allowAmbient) {
		for (let index = 0; index <= count - 1; index++) {
			const angle = (index / count) * math.pi * 2 - math.pi / 2;
			const distance = 72 + (index % 4) * 26;
			const travel = props.landFlash.map((amount) => 1 - amount);
			sparks.push(
				<frame
					key={`crate-ember-${index}`}
					Size={UDim2.fromOffset(index % 2 === 0 ? 6 : 4, index % 2 === 0 ? 6 : 4)}
					Position={travel.map(
						(amount) =>
							new UDim2(
								center.X.Scale,
								center.X.Offset + math.cos(angle) * distance * amount,
								center.Y.Scale,
								center.Y.Offset + math.sin(angle) * distance * amount,
							),
					)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					Rotation={index * 45}
					BackgroundColor3={index % 3 === 0 ? Palette.cream : props.winnerAccent}
					BackgroundTransparency={travel.map((amount) => math.clamp(amount * 1.3, 0, 1))}
					BorderSizePixel={0}
					ZIndex={448}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</frame>,
			);
		}
	}

	// Expanding circular shockwave ring
	const shockRing = !props.reducedMotion && (
		<frame
			Size={props.landFlash.map((f) => {
				const s = easeOutExpo(f) * 180;
				return UDim2.fromOffset(s, s);
			})}
			Position={center}
			AnchorPoint={new Vector2(0.5, 0.5)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={449}
		>
			<uistroke
				Color={props.winnerAccent}
				Thickness={2.4}
				Transparency={props.landFlash.map((f) => math.clamp(0.05 + (1 - f) * 0.9, 0, 1))}
			/>
			<uicorner CornerRadius={new UDim(1, 0)} />
		</frame>
	);

	// Central optical flare bloom
	const opticalFlare = (
		<frame
			Size={props.landFlash.map((amount) => UDim2.fromOffset(160 + amount * 440, 3 + amount * 3))}
			Position={center}
			AnchorPoint={new Vector2(0.5, 0.5)}
			BackgroundColor3={Palette.cream}
			BackgroundTransparency={props.landFlash.map((amount) => math.clamp(1 - amount * 0.85, 0, 1))}
			BorderSizePixel={0}
			ZIndex={448}
		>
			<uigradient
				Color={new ColorSequence(props.winnerAccent, Palette.cream)}
				Transparency={
					new NumberSequence([
						new NumberSequenceKeypoint(0, 1),
						new NumberSequenceKeypoint(0.44, 0.05),
						new NumberSequenceKeypoint(0.56, 0.05),
						new NumberSequenceKeypoint(1, 1),
					])
				}
			/>
		</frame>
	);

	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={448} Active={false}>
			{sparks}
			{shockRing}
			{opticalFlare}
		</frame>
	);
}

// Clean Result Display Card (bold presentation, clear discovery badges)
function ResultPanel({ props, layout }: SectionProps) {
	const visible = isLanded(props.phase);
	const [accentLineWidth, setAccentLineWidth] = React.useBinding(0);

	React.useEffect(() => {
		if (!visible) {
			return undefined;
		}
		const start = os.clock();
		const dur = 0.52;
		const conn = RunService.RenderStepped.Connect(() => {
			const t = math.clamp((os.clock() - start) / dur, 0, 1);
			setAccentLineWidth(easeOutBack(t));
		});
		return () => {
			conn.Disconnect();
		};
	}, [props.winnerName, visible]);

	if (!visible) {
		return undefined;
	}

	const isHolo = props.winnerRarity === "Mythic" || props.winnerRarity === "Celestial" || props.winnerRarity === "Astral";

	return (
		<frame
			Size={layout.resultSize}
			Position={props.landPop.map(
				(amount) =>
					new UDim2(
						layout.resultPosition.X.Scale,
						layout.resultPosition.X.Offset,
						layout.resultPosition.Y.Scale,
						layout.resultPosition.Y.Offset + math.round((1 - amount) * 16),
					),
			)}
			AnchorPoint={layout.resultAnchor}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={450}
		>
			<Panel
				size={UDim2.fromScale(1, 1)}
				accent={props.winnerAccent}
				background={Palette.panelRaised}
				padding={props.shortLandscape ? 10 : 12}
				highlight={true}
				reducedMotion={props.reducedMotion}
				clips={false}
				zIndex={450}
			>
				{/* Prismatic top edge bar for Mythic/Celestial/Astral */}
				{isHolo && !props.reducedMotion && (
					<frame
						Size={new UDim2(1, 0, 0, 2)}
						Position={new UDim2(0, 0, 0, 0)}
						BackgroundColor3={Color3.fromRGB(255, 255, 255)}
						BackgroundTransparency={0}
						BorderSizePixel={0}
						ZIndex={455}
					>
						<uigradient
							Color={HOLO_GRADIENT}
							Transparency={
								new NumberSequence([
									new NumberSequenceKeypoint(0, 0.7),
									new NumberSequenceKeypoint(0.5, 0.05),
									new NumberSequenceKeypoint(1, 0.7),
								])
							}
						/>
						<uicorner CornerRadius={new UDim(1, 0)} />
					</frame>
				)}

				{/* Rarity header */}
				<Text
					value={`${props.winnerRarity.upper()}  â€¢  ROLL ${props.rollIndex + 1}/${props.rollCount}`}
					size={10}
					color={props.winnerAccent}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					minSize={7}
					sizeConstraint={new UDim2(1, props.shortLandscape ? 0 : -118, 0, 14)}
					zIndex={452}
				/>
				{/* Relic title */}
				<Text
					value={props.winnerName}
					size={props.shortLandscape ? 17 : 20}
					color={Palette.cream}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					minSize={10}
					position={UDim2.fromOffset(0, 18)}
					sizeConstraint={new UDim2(1, props.shortLandscape ? 0 : -118, 0, 26)}
					zIndex={452}
				/>
				{/* Accent separator bar */}
				<frame
					Size={accentLineWidth.map((t) => new UDim2(t * (props.shortLandscape ? 0.55 : 0.45), 0, 0, 2))}
					Position={UDim2.fromOffset(0, 44)}
					BackgroundColor3={props.winnerAccent}
					BackgroundTransparency={0}
					BorderSizePixel={0}
					ZIndex={453}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</frame>
				{/* Relic detail / description */}
				<Text
					value={props.resultDetail}
					size={10}
					color={Palette.creamSoft}
					fit={true}
					minSize={8}
					wrap={true}
					position={UDim2.fromOffset(0, 48)}
					sizeConstraint={new UDim2(1, props.shortLandscape ? 0 : -118, 0, props.shortLandscape ? 32 : 24)}
					zIndex={452}
				/>
				{/* Discovery badge (NEW FIND / ESSENCE / OWNED) */}
				<Badge
					value={props.resultTag}
					accent={props.resultTag === "NEW FIND" ? Palette.mint : props.winnerAccent}
					filled={true}
					position={props.shortLandscape ? new UDim2(0, 0, 1, -27) : new UDim2(1, -106, 0.5, -14)}
					size={props.shortLandscape ? new UDim2(1, 0, 0, 22) : UDim2.fromOffset(106, 28)}
					zIndex={453}
				/>
			</Panel>
		</frame>
	);
}

// Root CrateRevealStage orchestrator
function CrateRevealStage(props: StageProps) {
	const layout = resolveLayout(props);
	const antilag = useAntilag();
	const softMotion = props.reducedMotion === true;
	const reducedMotion = softMotion;
	const allowAmbient = !reducedMotion && props.allowAmbient !== false && antilag.allowAmbient;
	const actionHostRef = React.useRef<Frame>();

	// Omni-Platform Gamepad Overlay Focus Stack
	React.useEffect(() => {
		GamepadNavigationService.BeginOverlayFocus();
		return () => {
			GamepadNavigationService.EndOverlayFocus();
		};
	}, []);

	// Gamepad focus selection when actionable
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = actionHostRef.current;
		if (host === undefined) {
			return undefined;
		}
		if (props.phase !== "spin" && props.phase !== "done") {
			GamepadNavigationService.ClearSelection();
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
	}, [props.phase]);

	const dimmer = props.visualShow.map((amount) => 1 - math.clamp(amount, 0, 1) * 0.985);
	const accentWash = props.visualShow.map((amount) => 1 - math.clamp(amount, 0, 1) * 0.08);
	const showingClaim = props.phase === "done" || props.phase === "exit";

	const stageProps = table.clone(props);
	stageProps.reducedMotion = reducedMotion;
	stageProps.allowAmbient = allowAmbient;

	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} Active={true} ZIndex={400}>
			{/* Full-screen click-to-skip or click-to-claim backdrop */}
			<imagebutton
				Size={UDim2.fromScale(1, 1)}
				BackgroundColor3={Palette.void}
				BackgroundTransparency={dimmer}
				BorderSizePixel={0}
				AutoButtonColor={false}
				Selectable={false}
				Active={props.phase === "spin" || props.phase === "done"}
				ZIndex={401}
				Event={{
					Activated: () => {
						if (props.phase === "spin") {
							Audio.play("crateBrake");
							props.onQuickLand();
						} else if (props.phase === "done") {
							Audio.play("crateClaim");
							props.onClaim();
						}
					},
				}}
			/>
			{/* Atmospheric ambient stage wash */}
			<frame
				Size={UDim2.fromScale(1, 1)}
				BackgroundColor3={darken(props.sessionAccent, 0.6)}
				BackgroundTransparency={accentWash}
				BorderSizePixel={0}
				ZIndex={402}
			>
				<uigradient Color={new ColorSequence(darken(props.sessionAccent, 0.78), Palette.void)} Rotation={90} />
			</frame>
			{/* Scaled Stage Content */}
			<frame
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ZIndex={404}
				ClipsDescendants={true}
				Visible={props.visualShow.map((amount) => amount > 0.015)}
			>
				<ScaleFromCenter scale={props.shellScale} zIndex={404}>
					<CinematicBackdrop props={stageProps} layout={layout} />
					<CinematicHeader props={stageProps} layout={layout} />
					<ForgeReel props={stageProps} layout={layout} />
					<LandingBurst props={stageProps} layout={layout} />
					<ResultPanel props={stageProps} layout={layout} />

					{/* Skip / Fast-Forward Button during spin */}
					{props.phase === "spin" && (
						<frame
							ref={actionHostRef}
							key="CrateSkip"
							Size={layout.actionSize}
							Position={layout.actionPosition}
							AnchorPoint={layout.actionAnchor}
							BackgroundTransparency={1}
							BorderSizePixel={0}
							ZIndex={455}
						>
							<Button
								text="SKIP TO RESULT"
								icon="Chevron.1"
								onClick={props.onQuickLand}
								color={Palette.panelSoft}
								textColor={Palette.creamSoft}
								outline={true}
								size={UDim2.fromScale(1, 1)}
								reducedMotion={reducedMotion}
								selectable={true}
							/>
						</frame>
					)}

					{/* Claim Drop Button when finished */}
					{showingClaim && (
						<frame
							ref={actionHostRef}
							key="CrateClaim"
							Size={layout.actionSize}
							Position={props.claimSlide.map(
								(amount) =>
									new UDim2(
										layout.actionPosition.X.Scale,
										layout.actionPosition.X.Offset,
										layout.actionPosition.Y.Scale,
										layout.actionPosition.Y.Offset + math.round((1 - amount) * 24),
									),
							)}
							AnchorPoint={layout.actionAnchor}
							BackgroundTransparency={1}
							BorderSizePixel={0}
							ClipsDescendants={false}
							ZIndex={456}
						>
							<Button
								text={props.claimText}
								icon="Gift.1"
								onClick={props.onClaim}
								color={props.sessionAccent}
								textColor={Palette.ink}
								size={UDim2.fromScale(1, 1)}
								reducedMotion={reducedMotion}
								highlight={true}
								selectable={true}
								disabled={props.phase === "exit"}
							/>
						</frame>
					)}
				</ScaleFromCenter>
			</frame>
		</frame>
	);
}

export = { CrateRevealStage, resolveLayout, ShimmerProvider };

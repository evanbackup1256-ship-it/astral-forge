import React from "@rbxts/react";
import { Audio } from "../AudioKit/audio";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { InteractionFeedback } from "../CoreKit/interaction";
import { Layout, Palette, TapTarget } from "../CoreKit/theme";
import { subscribeContinuous, useViewport } from "../MotionKit/motion";
import { joinTuple } from "../lua";
import { celebrationsAllowed, isReducedMotion } from "../MotionPreference";
import { CrateModel } from "./crateModel";
import { buildLayer, ForgeFrame, ForgeLayer, ForgePhase, LayerKind, layersFor, release } from "./crateForge";
import { Badge, Button, IconTile, Panel, Text } from "./ui";
import { itemIconKind } from "../ArtKit/Icon";
import { EffectLabel } from "../CoreKit/inventoryMath";
import Juice = require("../JuiceFx");

// Crate and artifact reveals.
// Crates open like a sealed casting: the crate rattles while a gauge beside it climbs the rarity
// ladder and the furnace light behind it opens slot by slot, then the seal lets go, plate and slag
// come out at three depths, and the relic rises out of the crate white-hot and cools to its colour.
// Each depth is its own pooled viewport (crateForge.ts). Artifacts get their own beat: shards pull
// in to a point and the artifact forms there. Server contracts are untouched: this only reads the
// rolls it is given.

const RunService = game.GetService("RunService");
const UserInputService = game.GetService("UserInputService");
const GuiService = game.GetService("GuiService");
const ReplicatedStorage = game.GetService("ReplicatedStorage");

const LADDER = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial", "Astral"];

interface Roll {
	Uid?: unknown;
	Rarity: string;
	DefinitionId: string;
	New?: boolean;
	Pity?: boolean;
	AutoSalvaged?: boolean;
	Essence?: number;
}
interface Definition {
	Id: string;
	Name: string;
	Rarity: string;
	Slot?: string;
	[key: string]: unknown;
}
interface CrateConfig {
	Items?: {
		Rarities: Record<string, { Color?: Color3 } | undefined>;
		Definitions?: Definition[];
		Crates?: Array<{ Id: string; ModelId?: string; Weights?: Record<string, number> }>;
	};
}
export interface ArtifactRevealInfo {
	name: string;
	rarity?: string;
	color?: Color3;
	element?: string;
	description?: string;
	fresh?: boolean;
}
interface RevealSession {
	rolls?: unknown;
	crateId?: string;
	crateName?: string;
	accent?: unknown;
	artifact?: ArtifactRevealInfo;
}
export interface CrateRevealProps {
	session?: RevealSession;
	config: CrateConfig;
	reducedMotion?: boolean;
	onClose: () => void;
	skin?: unknown;
	[key: string]: unknown;
}
interface CrateAppearanceModule {
	resolve(this: void, skinId: string | undefined, crateId: string | undefined, crates: { Id: string; ModelId?: string }[]): string;
}

function rankOf(rarity: unknown): number {
	const index = LADDER.indexOf(tostring(rarity));
	return index >= 0 ? index + 1 : 1;
}
function rarityColor(config: CrateConfig, rarity: unknown): Color3 {
	return config.Items?.Rarities?.[tostring(rarity)]?.Color ?? Palette.mango;
}
function defOf(config: CrateConfig, id: string): Definition | undefined {
	for (const def of config.Items?.Definitions ?? []) {
		if (def.Id === id) {
			return def;
		}
	}
	return undefined;
}
function nameOf(config: CrateConfig, id: string): string {
	for (const def of config.Items?.Definitions ?? []) {
		if (def.Id === id) {
			return def.Name;
		}
	}
	return "Unknown relic";
}

// seconds since `key` last changed; stops ticking once `until` has passed
function useStageClock(key: string, stopAfter: number): React.Binding<number> {
	const [t, setT] = React.useBinding(0);
	React.useEffect(() => {
		setT(0);
		let elapsed = 0;
		const conn = RunService.RenderStepped.Connect((dt) => {
			elapsed += dt;
			setT(elapsed);
			if (elapsed > stopAfter) {
				conn.Disconnect();
			}
		});
		return () => conn.Disconnect();
	}, [key]);
	return t;
}

function easeOut(x: number): number {
	const c = math.clamp(x, 0, 1);
	return 1 - (1 - c) ** 3;
}
// slight overshoot for things that land
function easeBack(x: number): number {
	const c = math.clamp(x, 0, 1) - 1;
	return 1 + 2.2 * c ** 3 + 1.2 * c ** 2;
}

// shared plumbing: touch controls off, gamepad focus held, keys advance
function useOverlayInput(advance: () => void) {
	const ref = React.useRef(advance);
	ref.current = advance;
	React.useEffect(() => {
		const previousTouch = GuiService.TouchControlsEnabled;
		GuiService.TouchControlsEnabled = false;
		GamepadNavigationService.BeginOverlayFocus();
		const conn = UserInputService.InputBegan.Connect((input) => {
			const key = input.KeyCode;
			if (
				key === Enum.KeyCode.Return ||
				key === Enum.KeyCode.Space ||
				key === Enum.KeyCode.ButtonA ||
				key === Enum.KeyCode.ButtonB ||
				key === Enum.KeyCode.Escape
			) {
				ref.current();
			}
		});
		return () => {
			conn.Disconnect();
			GamepadNavigationService.EndOverlayFocus();
			GuiService.TouchControlsEnabled = previousTouch;
		};
	}, []);
}

function Backdrop(props: { amount: React.Binding<number>; onTap: () => void }) {
	return (
		<textbutton
			Size={UDim2.fromScale(1, 1)}
			BackgroundColor3={Palette.void}
			BackgroundTransparency={props.amount.map((a) => 1 - a * 0.72)}
			AutoButtonColor={false}
			Text=""
			Modal={true}
			Selectable={false}
			ZIndex={500}
			Event={{ Activated: () => props.onTap() }}
		/>
	);
}

// the game's own Button, mounted only once its moment arrives
function ActionButton(props: { sound?: string | false; text: string; accent: Color3; position: UDim2; onClick: () => void; shown: boolean; reducedMotion: boolean }) {
	if (!props.shown) {
		return undefined;
	}
	return (
		<Button
			text={props.text}
			onClick={props.onClick}
			color={props.accent}
			textColor={Palette.ink}
			size={UDim2.fromOffset(220, TapTarget)}
			position={props.position.sub(UDim2.fromOffset(110, TapTarget))}
			reducedMotion={props.reducedMotion}
			highlight={true}
			sound={props.sound ?? "auto"}
			zIndex={520}
		/>
	);
}

// ---------------------------------------------------------------- relic card

function DropCard(props: {
	roll: Roll;
	config: CrateConfig;
	size: Vector2;
	position: UDim2;
	appear: React.Binding<number>;
	best: boolean;
	large: boolean;
	reducedMotion: boolean;
}) {
	const roll = props.roll;
	const accent = rarityColor(props.config, roll.Rarity);
	const salvaged = roll.AutoSalvaged === true;
	const tag = salvaged ? `+${roll.Essence ?? 0} ESSENCE` : roll.New === true ? "NEW" : roll.Pity === true ? "PITY" : undefined;
	const title = salvaged ? "Recycled" : nameOf(props.config, roll.DefinitionId);
	const large = props.large;
	const pad = large ? Layout.cardPadding : 12;
	const fade = props.appear.map((a) => 1 - math.clamp(a * 1.6, 0, 1));
	const def = defOf(props.config, roll.DefinitionId);
	const iconSize = large ? 64 : 40;
	const textX = iconSize + (large ? 14 : 10);
	return (
		<Panel
			size={UDim2.fromOffset(props.size.X, props.size.Y)}
			position={props.appear.map((a) =>
				props.position.add(UDim2.fromOffset(-props.size.X / 2, -props.size.Y / 2 + math.floor((1 - easeOut(a)) * 26))),
			)}
			accent={accent}
			background={Palette.panelRaised}
			padding={pad}
			reveal={props.appear}
			highlight={props.best}
			reducedMotion={props.reducedMotion}
			zIndex={510}
		>
			{/* icon on the left, then name / effect, badges along the top: the same reading order as a relic row */}
			<IconTile
				kind={salvaged ? "Dust.9" : itemIconKind(roll.DefinitionId, def?.Slot)}
				accent={accent}
				size={iconSize}
				filled={props.best || large}
				reducedMotion={props.reducedMotion}
				position={UDim2.fromOffset(0, large ? 34 : 30)}
				zIndex={511}
			/>
			<Badge value={string.upper(roll.Rarity)} accent={accent} filled={true} size={UDim2.fromOffset(large ? 104 : 80, 20)} zIndex={511} />
			{tag !== undefined && (
				<Badge
					value={tag}
					accent={salvaged ? Palette.mango : Palette.mint}
					size={UDim2.fromOffset(large ? 104 : 60, 20)}
					position={new UDim2(1, large ? -104 : -60, 0, 0)}
					zIndex={511}
				/>
			)}
			<Text
				value={title}
				size={large ? 22 : 14}
				minSize={11}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				wrap={true}
				fit={true}
				transparency={fade}
				position={UDim2.fromOffset(textX, large ? 34 : 30)}
				sizeConstraint={new UDim2(1, -textX, 0, large ? 52 : 36)}
				zIndex={511}
			/>
			{!salvaged && (
				<Text
					value={EffectLabel(def, 1)}
					size={large ? 14 : 11}
					minSize={10}
					color={accent}
					weight={Enum.FontWeight.Bold}
					fit={true}
					transparency={fade}
					position={UDim2.fromOffset(textX, large ? 90 : 68)}
					sizeConstraint={new UDim2(1, -textX, 0, 18)}
					zIndex={511}
				/>
			)}
		</Panel>
	);
}

// ---------------------------------------------------------------- crate reveal

const BREACH = 0.4;

// eight notches on a brass strip beside the crate; they light one rarity at a time while the
// pressure builds, so a good drop takes longer to top out
function PressureGauge(props: { step: React.Binding<number>; config: CrateConfig; position: UDim2; shown: React.Binding<number> }) {
	const notches = LADDER.map((rarity, index) => (
		<frame
			key={rarity}
			Size={UDim2.fromOffset(14, 5)}
			LayoutOrder={LADDER.size() - index}
			BackgroundColor3={props.step.map((s) => (s > index ? rarityColor(props.config, rarity) : Palette.lineSoft))}
			BackgroundTransparency={joinTuple<[number, number]>(props.step, props.shown).map(([s, shown]) => 1 - shown * (s > index ? 1 : 0.35))}
			BorderSizePixel={0}
			ZIndex={505}
		>
			<uicorner CornerRadius={new UDim(0, 2)} />
		</frame>
	));
	return (
		<frame
			AnchorPoint={new Vector2(0, 0.5)}
			Size={UDim2.fromOffset(14, LADDER.size() * 9)}
			Position={props.position}
			BackgroundTransparency={1}
			ZIndex={505}
		>
			<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 4)} VerticalAlignment={Enum.VerticalAlignment.Center} />
			{notches}
		</frame>
	);
}

// a screen-space slot for one pooled viewport layer
function LayerHost(props: { hostRef: React.MutableRefObject<Frame | undefined>; size: number; position: UDim2 | React.Binding<UDim2>; zIndex: number; visible?: React.Binding<boolean> }) {
	return (
		<frame
			ref={props.hostRef as React.Ref<Frame> as never}
			AnchorPoint={new Vector2(0.5, 0.5)}
			Size={UDim2.fromOffset(props.size, props.size)}
			Position={props.position}
			BackgroundTransparency={1}
			Visible={props.visible}
			ZIndex={props.zIndex}
		/>
	);
}

const LAYER_Z: Record<LayerKind, number> = { far: 501, light: 502, mid: 504, relic: 506, near: 507 };

function CrateReveal(props: CrateRevealProps & { rolls: Roll[] }) {
	const config = props.config;
	const session = props.session!;
	const rolls = props.rolls;
	const still = props.reducedMotion === true || isReducedMotion();
	const viewport = useViewport();
	const best = React.useMemo(() => {
		let pick = rolls[0];
		for (const roll of rolls) {
			if (rankOf(roll.Rarity) > rankOf(pick.Rarity)) {
				pick = roll;
			}
		}
		return pick;
	}, [rolls]);
	const bestRank = rankOf(best.Rarity);
	const bestColor = rarityColor(config, best.Rarity);
	const count = rolls.size();
	const narrow = viewport.width < 520;
	const phone = narrow || (UserInputService.TouchEnabled && !UserInputService.MouseEnabled);
	// the pressure takes longer to top out for better drops; reduced motion goes straight to the cards
	const buildTime = 0.7 + math.max(0, bestRank - 3) * 0.22;
	const dealGap = count > 1 ? 0.09 : 0;
	const castTime = 0.55 + count * dealGap;
	const [phase, setPhase] = React.useState<ForgePhase>(still ? "done" : "build");
	const t = useStageClock(phase, phase === "done" ? 0.9 : buildTime + 0.2);
	const [lid, setLid] = React.useState(still ? 1 : 0);
	const closing = React.useRef(false);
	const landed = React.useRef(false);
	const phaseRef = React.useRef<{ phase: ForgePhase; since: number }>({ phase, since: os.clock() });

	const stepAt = (s: number) => math.clamp(math.floor((s / buildTime) * bestRank) + 1, 1, bestRank);
	const gaugeStep = t.map((s) => (phase === "build" ? stepAt(s) : bestRank));

	const hosts: Record<LayerKind, React.MutableRefObject<Frame | undefined>> = {
		far: React.useRef<Frame>(),
		light: React.useRef<Frame>(),
		mid: React.useRef<Frame>(),
		relic: React.useRef<Frame>(),
		near: React.useRef<Frame>(),
	};

	const landCues = () => {
		if (landed.current) {
			return;
		}
		landed.current = true;
		if (bestRank >= 6) {
			Audio.playCelebration(["crateRevealMythic", "discovery", "reward"], 0.1);
		} else if (bestRank >= 4) {
			Audio.playCelebration(["crateRevealEpic", "crateRare"], 0.06);
		} else {
			Audio.play(best.New === true ? "crateRare" : "crateLand");
		}
	};

	// the layers: built once per opening from the pool, stepped from one clock, handed back on close
	React.useEffect(() => {
		const opened = os.clock();
		const kinds = still ? (["relic"] as LayerKind[]) : layersFor(bestRank, phone);
		const slot = defOf(config, best.DefinitionId)?.Slot;
		const layers = new Array<ForgeLayer>();
		for (const kind of kinds) {
			const host = hosts[kind].current;
			if (host !== undefined) {
				layers.push(buildLayer(kind, host, LAYER_Z[kind], { rank: bestRank, phone, seed: rolls.size() * 31 + bestRank, slot, still, breach: BREACH }));
			}
		}
		const frameAt = (): ForgeFrame => {
			const now = os.clock();
			const current = phaseRef.current;
			const s = now - current.since;
			const step = current.phase === "build" ? stepAt(s) : bestRank;
			return {
				phase: current.phase,
				t: s,
				clock: now - opened,
				pressure: current.phase === "build" ? math.clamp(s / buildTime, 0, 1) : 1,
				heat: rarityColor(config, LADDER[step - 1]),
				color: bestColor,
			};
		};
		const stepAll = () => {
			const frame = frameAt();
			for (const layer of layers) {
				layer.step(frame);
			}
		};
		stepAll();
		const stop = still ? undefined : subscribeContinuous(stepAll);
		return () => {
			stop?.();
			for (const layer of layers) {
				release(layer);
			}
		};
	}, []);

	React.useEffect(() => {
		phaseRef.current = { phase, since: os.clock() };
		if (phase === "build") {
			Audio.play("crateCharge");
			let lastStep = 0;
			const steps = RunService.Heartbeat.Connect(() => {
				// the gauge only ticks out loud for drops worth the wait
				if (bestRank < 4) {
					return;
				}
				const step = stepAt(t.getValue());
				if (step > lastStep) {
					lastStep = step;
					Audio.play("crateRarityStep", 0.88 + step * 0.06);
				}
			});
			const job = task.delay(buildTime, () => setPhase("breach"));
			return () => {
				steps.Disconnect();
				pcall(task.cancel, job);
			};
		}
		if (phase === "breach") {
			setLid(1);
			Audio.play("crateSeal");
			InteractionFeedback.reward();
			const job = task.delay(BREACH, () => setPhase("cast"));
			return () => {
				pcall(task.cancel, job);
			};
		}
		if (phase === "cast") {
			const job = task.delay(castTime, () => setPhase("done"));
			return () => {
				pcall(task.cancel, job);
			};
		}
		setLid(1);
		landCues();
		return undefined;
	}, [phase]);

	// one tap skips to the cards, the next one keeps them
	const advance = () => {
		if (phase !== "done") {
			setPhase("done");
		} else if (!closing.current) {
			closing.current = true;
			Audio.play("crateClaim");
			props.onClose();
		}
	};
	useOverlayInput(advance);

	const CrateAppearance = require(
		ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("CrateAppearance") as ModuleScript,
	) as CrateAppearanceModule;
	const skin = CrateAppearance.resolve(props.skin as string | undefined, session.crateId, config.Items?.Crates ?? []);

	const backdrop = t.map((s) => (phase === "build" ? math.clamp(s / 0.2, 0, 1) : 1));
	const crateY = 0.45;
	// the crate holds centre while the pressure builds, then drops away so the cast owns the screen
	const sink = t.map((s) => (phase === "build" ? 0 : phase === "breach" ? easeOut(s / BREACH) * 0.4 : phase === "cast" ? 0.4 + easeOut(s / 0.5) * 0.6 : 1));
	const cratePos = sink.map((k) => new UDim2(0.5, 0, crateY + k * 0.33, 0));
	const crateSize = math.min(260, viewport.width * 0.6);
	const relicSize = math.min(count === 1 ? 220 : 180, viewport.width * 0.5);
	const anchor = new UDim2(0.5, 0, crateY, 0);

	const cols = count === 1 ? 1 : math.min(count, narrow ? 2 : 5);
	const rows = math.ceil(count / cols);
	const large = count === 1;
	const cardSize = large ? new Vector2(math.min(340, viewport.width - 48), 150) : new Vector2(narrow ? 156 : 184, 112);
	const gap = 12;
	const gridW = cols * cardSize.X + (cols - 1) * gap;
	const gridH = rows * cardSize.Y + (rows - 1) * gap;
	// a single drop sits under its cast relic; a multi-open lets the relic go and centres the grid
	const gridY = large ? 0.66 : 0.42;

	const cards = rolls.map((roll, index) => {
		const col = index % cols;
		const row = math.floor(index / cols);
		const x = -gridW / 2 + cardSize.X / 2 + col * (cardSize.X + gap);
		const y = -gridH / 2 + cardSize.Y / 2 + row * (cardSize.Y + gap);
		const appear = t.map((s) => {
			if (phase === "build" || phase === "breach") {
				return 0;
			}
			if (still) {
				return 1;
			}
			const start = phase === "cast" ? 0.3 + index * dealGap : 0;
			return phase === "done" && s > 0.3 ? 1 : math.clamp((s - start) / 0.3, 0, 1);
		});
		return (
			<DropCard
				key={`${index}`}
				roll={roll}
				config={config}
				size={cardSize}
				position={new UDim2(0.5, x, gridY, y)}
				appear={appear}
				best={roll === best && count > 1}
				large={large}
				reducedMotion={still}
			/>
		);
	});

	const allSalvaged = rolls.every((roll) => roll.AutoSalvaged === true);
	const claim = allSalvaged ? "Bank essence" : count === 1 ? "Keep it" : `Keep all ${count}`;
	const header = phase === "build" ? `Opening ${session.crateName ?? "crate"}` : count === 1 ? "You got" : `${count} drops`;
	const relicShown = t.map((s) => large || phase !== "done" || s < 0.25);

	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ZIndex={500}>
			<Backdrop amount={backdrop} onTap={advance} />
			<Text
				value={header}
				size={16}
				color={Palette.creamSoft}
				weight={Enum.FontWeight.Bold}
				align={Enum.TextXAlignment.Center}
				position={new UDim2(0, 0, 0, math.max(viewport.topInset, 0) + 56)}
				sizeConstraint={new UDim2(1, 0, 0, 22)}
				zIndex={505}
			/>
			{!still && (
				<React.Fragment>
					<LayerHost hostRef={hosts.far} size={crateSize * 1.7} position={anchor} zIndex={LAYER_Z.far} />
					<LayerHost hostRef={hosts.light} size={crateSize * 1.5} position={cratePos} zIndex={LAYER_Z.light} />
					<LayerHost hostRef={hosts.mid} size={crateSize * 2.2} position={anchor} zIndex={LAYER_Z.mid} />
					<LayerHost hostRef={hosts.near} size={crateSize * 3} position={anchor} zIndex={LAYER_Z.near} />
					<frame AnchorPoint={new Vector2(0.5, 0.5)} Size={UDim2.fromOffset(crateSize, crateSize)} Position={cratePos} BackgroundTransparency={1} ZIndex={503}>
						<CrateModel skin={skin} open={lid} shake={phase === "build" ? 1 : 0} spin={false} live={true} zoom={0.9} zIndex={503} />
					</frame>
					<PressureGauge
						step={gaugeStep}
						config={config}
						position={new UDim2(0.5, crateSize / 2 + 14, crateY, 0)}
						shown={t.map((s) => (phase === "build" ? math.clamp(s / 0.2, 0, 1) : phase === "breach" ? 1 - math.clamp(s / 0.25, 0, 1) : 0))}
					/>
				</React.Fragment>
			)}
			<LayerHost
				hostRef={hosts.relic}
				size={relicSize}
				position={new UDim2(0.5, 0, large ? 0.34 : 0.3, 0)}
				zIndex={LAYER_Z.relic}
				visible={relicShown}
			/>
			{cards}
			<ActionButton
				text={claim}
				accent={bestColor}
				position={new UDim2(0.5, 0, 1, -math.max(viewport.bottomInset, 0) - 36)}
				onClick={advance}
				sound={false}
				shown={phase === "done"}
				reducedMotion={still}
			/>
			{phase !== "done" && (
				<Text
					value="Tap to skip"
					size={12}
					color={Palette.muted}
					align={Enum.TextXAlignment.Center}
					position={new UDim2(0, 0, 1, -math.max(viewport.bottomInset, 0) - 30)}
					sizeConstraint={new UDim2(1, 0, 0, 16)}
					zIndex={505}
				/>
			)}
		</frame>
	);
}

// ---------------------------------------------------------------- artifact reveal

const SHARDS = 9;

function ArtifactReveal(props: { info: ArtifactRevealInfo; config: CrateConfig; reducedMotion?: boolean; onClose: () => void }) {
	const info = props.info;
	const still = props.reducedMotion === true || isReducedMotion();
	const color = info.color ?? rarityColor(props.config, info.rarity);
	const gatherTime = still ? 0.2 : 1.05;
	const [formed, setFormed] = React.useState(false);
	const t = useStageClock(formed ? "formed" : "gather", formed ? 0.8 : gatherTime + 0.1);
	const closing = React.useRef(false);

	const form = () => {
		if (formed) {
			return;
		}
		setFormed(true);
		Audio.playCelebration(["artifactUpgrade", "discovery"], 0.08);
		InteractionFeedback.reward();
		if (celebrationsAllowed()) {
			const camera = game.GetService("Workspace").CurrentCamera;
			Juice.burst(camera ? camera.ViewportSize.div(2).sub(new Vector2(0, 40)) : undefined, color, 1.1);
		}
	};
	React.useEffect(() => {
		Audio.play("crateCharge", 0.8);
		const job = task.delay(gatherTime, form);
		return () => {
			pcall(task.cancel, job);
		};
	}, []);
	const advance = () => {
		if (!formed) {
			form();
		} else if (!closing.current) {
			closing.current = true;
			props.onClose();
		}
	};
	useOverlayInput(advance);

	// shards start on a wide ring and spiral in; each one is a small rotated diamond
	const shards = new Array<React.Element>();
	for (let i = 0; i < SHARDS; i++) {
		const angle0 = (i / SHARDS) * math.pi * 2;
		const pos = t.map((s) => {
			const k = formed ? 1 : easeOut(s / gatherTime);
			const radius = (1 - k) * 170 + 6;
			const angle = angle0 + k * 1.6;
			return new UDim2(0.5, math.cos(angle) * radius, 0.4, math.sin(angle) * radius * 0.8);
		});
		shards.push(
			<frame
				key={`s${i}`}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Size={UDim2.fromOffset(10, 10)}
				Position={pos}
				Rotation={45}
				BackgroundColor3={i % 3 === 0 ? Palette.cream : color}
				BackgroundTransparency={t.map((s) => (formed ? math.clamp(s / 0.15, 0, 1) : 0.1))}
				BorderSizePixel={0}
				ZIndex={505}
			/>,
		);
	}
	const gemIn = t.map((s) => (formed ? (still ? 1 : easeBack(s / 0.35)) : 0));
	const cardW = math.min(360, useViewport().width - 32);
	const textIn = t.map((s) => (formed ? math.clamp((s - (still ? 0 : 0.18)) / 0.25, 0, 1) : 0));

	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ZIndex={500}>
			<Backdrop amount={t.map((s) => (formed ? 1 : math.clamp(s / 0.25, 0, 1)))} onTap={advance} />
			{shards}
			{/* the artifact: a faceted diamond with an inner facet, no glow loop */}
			<frame
				AnchorPoint={new Vector2(0.5, 0.5)}
				Size={UDim2.fromOffset(96, 96)}
				Position={new UDim2(0.5, 0, 0.4, 0)}
				Rotation={45}
				BackgroundColor3={Palette.panelRaised}
				BackgroundTransparency={gemIn.map((g) => 1 - math.clamp(g, 0, 1))}
				BorderSizePixel={0}
				ZIndex={506}
			>
				<uiscale Scale={gemIn.map((g) => math.max(0.01, g))} />
				<uicorner CornerRadius={new UDim(0, Layout.buttonRadius)} />
				<uistroke Color={color} Thickness={2} Transparency={gemIn.map((g) => 1 - math.clamp(g, 0, 1))} />
				<frame
					AnchorPoint={new Vector2(0.5, 0.5)}
					Size={UDim2.fromScale(0.46, 0.46)}
					Position={UDim2.fromScale(0.5, 0.5)}
					BackgroundColor3={color}
					BackgroundTransparency={gemIn.map((g) => 1 - math.clamp(g, 0, 1) * 0.9)}
					BorderSizePixel={0}
					ZIndex={507}
				>
					<uicorner CornerRadius={new UDim(0, 6)} />
				</frame>
			</frame>
			<Panel
				size={UDim2.fromOffset(cardW, 132)}
				position={textIn.map((a) => new UDim2(0.5, -cardW / 2, 0.4, 84 + math.floor((1 - a) * 10)))}
				accent={color}
				background={Palette.panelRaised}
				padding={Layout.cardPadding - 6}
				reveal={textIn}
				reducedMotion={still}
				zIndex={508}
			>
				<Badge
					value={string.upper(`${info.rarity ?? ""}${info.element !== undefined ? ` · ${info.element}` : ""}`)}
					accent={color}
					filled={true}
					size={UDim2.fromOffset(150, 22)}
					zIndex={509}
				/>
				<Text
					value={info.name}
					size={24}
					minSize={14}
					color={Palette.cream}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					transparency={textIn.map((a) => 1 - a)}
					position={UDim2.fromOffset(0, 30)}
					sizeConstraint={new UDim2(1, 0, 0, 30)}
					zIndex={509}
				/>
				<Text
					value={info.fresh === false ? "Already held, so this restocks as upgrade fragments." : info.description ?? "Added to your artifacts."}
					size={13}
					color={Palette.creamSoft}
					wrap={true}
					transparency={textIn.map((a) => 1 - a)}
					position={UDim2.fromOffset(0, 64)}
					sizeConstraint={new UDim2(1, 0, 0, 36)}
					zIndex={509}
				/>
			</Panel>
			<ActionButton text="Done" accent={color} position={new UDim2(0.5, 0, 1, -40)} onClick={advance} shown={formed} reducedMotion={still} />
		</frame>
	);
}

// ---------------------------------------------------------------- empty / failure

function EmptyReveal(props: { onClose: () => void }) {
	const t = useStageClock("empty", 0.4);
	useOverlayInput(props.onClose);
	const show = t.map((s) => math.clamp(s / 0.2, 0, 1));
	// 300 wide, narrower on small phones so it never touches the edges
	const width = math.min(300, useViewport().width - 32);
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ZIndex={500}>
			<Backdrop amount={show} onTap={props.onClose} />
			<Panel
				size={UDim2.fromOffset(width, 96)}
				position={new UDim2(0.5, -width / 2, 0.42, -48)}
				accent={Palette.coral}
				background={Palette.panelRaised}
				padding={Layout.cardPadding - 6}
				reveal={show}
				zIndex={505}
			>
				<Text value="Crate didn't open" size={18} color={Palette.cream} weight={Enum.FontWeight.Heavy} sizeConstraint={new UDim2(1, 0, 0, 24)} zIndex={506} />
				<Text value="Nothing was used. Try again." size={13} color={Palette.creamSoft} position={UDim2.fromOffset(0, 30)} sizeConstraint={new UDim2(1, 0, 0, 20)} zIndex={506} />
			</Panel>
			<ActionButton text="Back to inventory" accent={Palette.coral} position={new UDim2(0.5, 0, 1, -40)} onClick={props.onClose} shown={true} reducedMotion={isReducedMotion()} />
		</frame>
	);
}

export function CrateRevealOverlay(props: CrateRevealProps) {
	const session = props.session;
	if (session?.artifact !== undefined) {
		return <ArtifactReveal info={session.artifact} config={props.config} reducedMotion={props.reducedMotion} onClose={props.onClose} />;
	}
	const rolls = (typeIs(session?.rolls, "table") ? session!.rolls : []) as Roll[];
	if (session === undefined || rolls.size() === 0) {
		return <EmptyReveal onClose={props.onClose} />;
	}
	return <CrateReveal {...props} rolls={rolls} />;
}

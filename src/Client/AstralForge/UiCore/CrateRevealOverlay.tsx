import React from "@rbxts/react";
import { Audio } from "../AudioKit/audio";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { InteractionFeedback } from "../CoreKit/interaction";
import { Palette, darken } from "../CoreKit/theme";
import { useViewport } from "../MotionKit/motion";
import { celebrationsAllowed, flashesAllowed, isReducedMotion } from "../MotionPreference";
import { CrateModel } from "./crateModel";
import Juice = require("../JuiceFx");

// Crate and artifact reveals.
// Crates: the crate rattles on its own, the lid lets go, and the drops come out one at a time.
// Better drops rattle longer and the crate's edge light walks up the rarity ladder before it opens,
// so you can feel a good one coming. Artifacts get their own beat: shards pull in to a point
// and the artifact forms there. Server contracts are untouched: this only reads the rolls it is given.

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

function Backdrop(props: { tint: Color3; amount: React.Binding<number>; onTap: () => void }) {
	return (
		<textbutton
			Size={UDim2.fromScale(1, 1)}
			BackgroundColor3={darken(props.tint, 0.88)}
			BackgroundTransparency={props.amount.map((a) => 1 - a * 0.82)}
			AutoButtonColor={false}
			Text=""
			Modal={true}
			Selectable={false}
			ZIndex={500}
			Event={{ Activated: () => props.onTap() }}
		/>
	);
}

function ActionButton(props: { text: string; accent: Color3; position: UDim2; onClick: () => void; visible: React.Binding<number> }) {
	return (
		<textbutton
			AnchorPoint={new Vector2(0.5, 1)}
			Size={UDim2.fromOffset(220, 48)}
			Position={props.position}
			BackgroundColor3={props.accent}
			BackgroundTransparency={props.visible.map((v) => 1 - v)}
			TextTransparency={props.visible.map((v) => 1 - v)}
			AutoButtonColor={true}
			Text={props.text}
			TextColor3={Palette.ink}
			TextSize={16}
			FontFace={Font.fromEnum(Enum.Font.BuilderSansBold)}
			ZIndex={520}
			Event={{ Activated: () => props.onClick() }}
		>
			<uicorner CornerRadius={new UDim(0, 10)} />
		</textbutton>
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
}) {
	const roll = props.roll;
	const accent = rarityColor(props.config, roll.Rarity);
	const salvaged = roll.AutoSalvaged === true;
	const tag = salvaged ? `+${roll.Essence ?? 0} essence` : roll.New === true ? "New" : roll.Pity === true ? "Pity drop" : undefined;
	const title = salvaged ? "Recycled" : nameOf(props.config, roll.DefinitionId);
	const large = props.large;
	return (
		<frame
			AnchorPoint={new Vector2(0.5, 0.5)}
			Size={UDim2.fromOffset(props.size.X, props.size.Y)}
			Position={props.appear.map((a) => props.position.add(UDim2.fromOffset(0, math.floor((1 - easeOut(a)) * 26))))}
			BackgroundColor3={darken(accent, 0.78)}
			BackgroundTransparency={props.appear.map((a) => 1 - math.clamp(a * 1.6, 0, 1))}
			BorderSizePixel={0}
			ZIndex={510}
		>
			<uicorner CornerRadius={new UDim(0, large ? 14 : 10)} />
			<uiscale Scale={props.appear.map((a) => 0.9 + easeBack(a) * 0.1)} />
			<uistroke
				Color={accent}
				Thickness={props.best ? 2 : 1}
				Transparency={props.appear.map((a) => 1 - math.clamp(a * 1.4, 0, 1) * (props.best ? 1 : 0.6))}
			/>
			{/* a rarity bar across the top edge, the one bit of colour that does the talking */}
			<frame
				Size={new UDim2(1, -24, 0, 3)}
				Position={UDim2.fromOffset(12, 10)}
				BackgroundColor3={accent}
				BackgroundTransparency={props.appear.map((a) => 1 - math.clamp(a * 1.6, 0, 1))}
				BorderSizePixel={0}
				ZIndex={511}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
			<textlabel
				Size={new UDim2(1, -24, 0, large ? 18 : 14)}
				Position={UDim2.fromOffset(12, large ? 22 : 18)}
				BackgroundTransparency={1}
				Text={string.upper(roll.Rarity)}
				TextColor3={accent}
				TextTransparency={props.appear.map((a) => 1 - math.clamp(a * 1.6, 0, 1))}
				TextSize={large ? 14 : 11}
				FontFace={Font.fromEnum(Enum.Font.BuilderSansBold)}
				TextXAlignment={Enum.TextXAlignment.Left}
				ZIndex={511}
			/>
			<textlabel
				Size={new UDim2(1, -24, 0, large ? 56 : 34)}
				Position={UDim2.fromOffset(12, large ? 44 : 34)}
				BackgroundTransparency={1}
				Text={title}
				TextColor3={Palette.cream}
				TextTransparency={props.appear.map((a) => 1 - math.clamp(a * 1.6, 0, 1))}
				TextSize={large ? 26 : 15}
				TextWrapped={true}
				TextScaled={true}
				FontFace={Font.fromEnum(Enum.Font.BuilderSansExtraBold)}
				TextXAlignment={Enum.TextXAlignment.Left}
				TextYAlignment={Enum.TextYAlignment.Top}
				ZIndex={511}
			>
				<uitextsizeconstraint MaxTextSize={large ? 26 : 15} MinTextSize={10} />
			</textlabel>
			{tag !== undefined && (
				<textlabel
					Size={new UDim2(1, -24, 0, 16)}
					Position={new UDim2(0, 12, 1, large ? -28 : -22)}
					BackgroundTransparency={1}
					Text={tag}
					TextColor3={salvaged ? Palette.mango : Palette.mint}
					TextTransparency={props.appear.map((a) => 1 - math.clamp(a * 1.6, 0, 1))}
					TextSize={large ? 14 : 12}
					FontFace={Font.fromEnum(Enum.Font.BuilderSansBold)}
					TextXAlignment={Enum.TextXAlignment.Left}
					ZIndex={511}
				/>
			)}
		</frame>
	);
}

// ---------------------------------------------------------------- crate reveal

type CratePhase = "rattle" | "open" | "done";

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
	// rattle length grows with the best drop; reduced motion skips straight to a short beat
	const rattleTime = still ? 0.25 : 0.7 + math.max(0, bestRank - 3) * 0.22;
	const dealGap = still ? 0 : rolls.size() > 1 ? 0.09 : 0;
	const [phase, setPhase] = React.useState<CratePhase>("rattle");
	const t = useStageClock(phase, phase === "rattle" ? rattleTime + 0.1 : 0.6 + rolls.size() * dealGap + 0.3);
	const [rattle, setRattle] = React.useState(1);
	const [lid, setLid] = React.useState(0);
	const closing = React.useRef(false);

	// edge light: walks the ladder up to the best rarity while the crate shakes
	const edge = t.map((s) => {
		if (phase !== "rattle") {
			return bestColor;
		}
		const step = math.clamp(math.floor((s / rattleTime) * bestRank) + 1, 1, bestRank);
		return rarityColor(config, LADDER[step - 1]);
	});

	React.useEffect(() => {
		if (phase === "rattle") {
			Audio.play("crateCharge");
			let lastStep = 0;
			const steps = RunService.Heartbeat.Connect(() => {
				// tick audio as the ladder climbs, only for drops worth the wait
				if (bestRank < 4) {
					return;
				}
				const step = math.clamp(math.floor((t.getValue() / rattleTime) * bestRank) + 1, 1, bestRank);
				if (step > lastStep) {
					lastStep = step;
					Audio.play("crateRarityStep", 0.88 + step * 0.06);
				}
			});
			const job = task.delay(rattleTime, () => setPhase("open"));
			return () => {
				steps.Disconnect();
				pcall(task.cancel, job);
			};
		}
		if (phase === "open") {
			setRattle(0);
			setLid(1);
			Audio.play("crateSeal");
			InteractionFeedback.reward();
			const job = task.delay(0.35 + rolls.size() * dealGap, () => {
				setPhase("done");
				landCues();
			});
			return () => {
				pcall(task.cancel, job);
			};
		}
		return undefined;
	}, [phase]);

	const landCues = () => {
		if (bestRank >= 6) {
			Audio.playCelebration(["crateRevealMythic", "discovery", "reward"], 0.1);
		} else if (bestRank >= 4) {
			Audio.playCelebration(["crateRevealEpic", "crateRare"], 0.06);
		} else {
			Audio.play(best.New === true ? "crateRare" : "crateLand");
		}
		if (bestRank >= 4 && celebrationsAllowed()) {
			const camera = game.GetService("Workspace").CurrentCamera;
			Juice.burst(camera ? camera.ViewportSize.div(2) : undefined, bestColor, 0.8 + bestRank * 0.12);
		}
		if (bestRank >= 6 && flashesAllowed()) {
			Juice.flash(Palette.cream, bestRank >= 7 ? 0.45 : 0.25);
		}
	};

	const advance = () => {
		if (phase === "rattle") {
			setPhase("open");
		} else if (phase === "open") {
			setPhase("done");
			landCues();
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

	const backdrop = t.map((s) => (phase === "rattle" ? math.clamp(s / 0.2, 0, 1) : 1));
	// crate: centred while it rattles, then sinks and fades so the drops own the screen
	const cratePos = t.map((s) => {
		const sink = phase === "rattle" ? 0 : phase === "open" ? easeOut(s / 0.4) : 1;
		return new UDim2(0.5, 0, 0.45 + sink * 0.32, 0);
	});
	const crateSize = math.min(260, viewport.width * 0.6);

	const count = rolls.size();
	const narrow = viewport.width < 520;
	const cols = count === 1 ? 1 : math.min(count, narrow ? 2 : 5);
	const rows = math.ceil(count / cols);
	const large = count === 1;
	const cardSize = large ? new Vector2(math.min(300, viewport.width - 48), 190) : new Vector2(narrow ? 150 : 168, 120);
	const gap = 12;
	const gridW = cols * cardSize.X + (cols - 1) * gap;
	const gridH = rows * cardSize.Y + (rows - 1) * gap;

	const cards = rolls.map((roll, index) => {
		const col = index % cols;
		const row = math.floor(index / cols);
		const x = -gridW / 2 + cardSize.X / 2 + col * (cardSize.X + gap);
		const y = -gridH / 2 + cardSize.Y / 2 + row * (cardSize.Y + gap);
		const appear = t.map((s) => {
			if (phase === "rattle") {
				return 0;
			}
			if (phase === "done" && still) {
				return 1;
			}
			const start = phase === "open" ? 0.18 + index * dealGap : 0;
			return phase === "done" && s > 0.3 ? 1 : math.clamp((s - start) / 0.3, 0, 1);
		});
		return (
			<DropCard
				key={`${index}`}
				roll={roll}
				config={config}
				size={cardSize}
				position={new UDim2(0.5, x, 0.42, y)}
				appear={appear}
				best={roll === best && count > 1}
				large={large}
			/>
		);
	});

	const allSalvaged = rolls.every((roll) => roll.AutoSalvaged === true);
	const claim = allSalvaged ? "Bank essence" : count === 1 ? "Keep it" : `Keep all ${count}`;
	const doneAmount = t.map((s) => (phase === "done" ? math.clamp(s / 0.25, 0, 1) : 0));
	const header = phase === "rattle" ? `Opening ${session.crateName ?? "crate"}` : count === 1 ? "You got" : `${count} drops`;

	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ZIndex={500}>
			<Backdrop tint={bestColor} amount={backdrop} onTap={advance} />
			<textlabel
				AnchorPoint={new Vector2(0.5, 0)}
				Size={UDim2.fromOffset(320, 22)}
				Position={new UDim2(0.5, 0, 0, math.max(viewport.topInset, 0) + 56)}
				BackgroundTransparency={1}
				Text={header}
				TextColor3={Palette.creamSoft}
				TextSize={16}
				FontFace={Font.fromEnum(Enum.Font.BuilderSansBold)}
				ZIndex={505}
			/>
			<frame
				AnchorPoint={new Vector2(0.5, 0.5)}
				Size={UDim2.fromOffset(crateSize, crateSize)}
				Position={cratePos}
				BackgroundTransparency={1}
				ZIndex={502}
			>
				<CrateModel
					skin={skin}
					open={lid}
					shake={still ? 0 : rattle}
					spin={false}
					live={!still}
					zoom={0.9}
					zIndex={502}
				/>
				{/* the tell: a thin ring under the crate that changes colour as the ladder climbs */}
				<frame
					AnchorPoint={new Vector2(0.5, 0.5)}
					Size={new UDim2(0.7, 0, 0, 6)}
					Position={new UDim2(0.5, 0, 0.92, 0)}
					BackgroundColor3={edge}
					BackgroundTransparency={t.map((s) => (phase === "rattle" ? 0.15 + math.sin(s * 18) * 0.1 : math.clamp(s / 0.3, 0, 1)))}
					BorderSizePixel={0}
					ZIndex={503}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</frame>
			</frame>
			{cards}
			<ActionButton
				text={claim}
				accent={bestColor}
				position={new UDim2(0.5, 0, 1, -math.max(viewport.bottomInset, 0) - 36)}
				onClick={advance}
				visible={doneAmount}
			/>
			<textlabel
				AnchorPoint={new Vector2(0.5, 1)}
				Size={UDim2.fromOffset(260, 16)}
				Position={new UDim2(0.5, 0, 1, -math.max(viewport.bottomInset, 0) - 14)}
				BackgroundTransparency={1}
				Text={phase === "done" ? "" : "Tap to skip"}
				TextColor3={Palette.muted}
				TextSize={12}
				FontFace={Font.fromEnum(Enum.Font.BuilderSans)}
				ZIndex={505}
			/>
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
	const textIn = t.map((s) => (formed ? math.clamp((s - (still ? 0 : 0.18)) / 0.25, 0, 1) : 0));

	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ZIndex={500}>
			<Backdrop tint={color} amount={t.map((s) => (formed ? 1 : math.clamp(s / 0.25, 0, 1)))} onTap={advance} />
			{shards}
			{/* the artifact: a faceted diamond with an inner facet, no glow loop */}
			<frame
				AnchorPoint={new Vector2(0.5, 0.5)}
				Size={UDim2.fromOffset(96, 96)}
				Position={new UDim2(0.5, 0, 0.4, 0)}
				Rotation={45}
				BackgroundColor3={darken(color, 0.35)}
				BackgroundTransparency={gemIn.map((g) => 1 - math.clamp(g, 0, 1))}
				BorderSizePixel={0}
				ZIndex={506}
			>
				<uiscale Scale={gemIn.map((g) => math.max(0.01, g))} />
				<uicorner CornerRadius={new UDim(0, 10)} />
				<uistroke Color={color} Thickness={3} Transparency={gemIn.map((g) => 1 - math.clamp(g, 0, 1))} />
				<frame
					AnchorPoint={new Vector2(0.5, 0.5)}
					Size={UDim2.fromScale(0.46, 0.46)}
					Position={UDim2.fromScale(0.5, 0.5)}
					BackgroundColor3={color}
					BackgroundTransparency={gemIn.map((g) => 1 - math.clamp(g, 0, 1) * 0.9)}
					BorderSizePixel={0}
					ZIndex={507}
				>
					<uicorner CornerRadius={new UDim(0, 4)} />
				</frame>
			</frame>
			<textlabel
				AnchorPoint={new Vector2(0.5, 0)}
				Size={UDim2.fromOffset(340, 16)}
				Position={new UDim2(0.5, 0, 0.4, 84)}
				BackgroundTransparency={1}
				Text={string.upper(`${info.rarity ?? ""}${info.element !== undefined ? ` · ${info.element}` : ""} artifact`)}
				TextColor3={color}
				TextTransparency={textIn.map((a) => 1 - a)}
				TextSize={13}
				FontFace={Font.fromEnum(Enum.Font.BuilderSansBold)}
				ZIndex={508}
			/>
			<textlabel
				AnchorPoint={new Vector2(0.5, 0)}
				Size={UDim2.fromOffset(340, 34)}
				Position={textIn.map((a) => new UDim2(0.5, 0, 0.4, 102 + math.floor((1 - a) * 8)))}
				BackgroundTransparency={1}
				Text={info.name}
				TextColor3={Palette.cream}
				TextTransparency={textIn.map((a) => 1 - a)}
				TextSize={30}
				TextScaled={true}
				FontFace={Font.fromEnum(Enum.Font.BuilderSansExtraBold)}
				ZIndex={508}
			>
				<uitextsizeconstraint MaxTextSize={30} MinTextSize={16} />
			</textlabel>
			<textlabel
				AnchorPoint={new Vector2(0.5, 0)}
				Size={UDim2.fromOffset(320, 40)}
				Position={new UDim2(0.5, 0, 0.4, 142)}
				BackgroundTransparency={1}
				Text={info.fresh === false ? "Already held, so this restocks as upgrade fragments." : info.description ?? "Added to your artifacts."}
				TextColor3={Palette.muted}
				TextTransparency={textIn.map((a) => 1 - a)}
				TextSize={14}
				TextWrapped={true}
				FontFace={Font.fromEnum(Enum.Font.BuilderSans)}
				ZIndex={508}
			/>
			<ActionButton text="Done" accent={color} position={new UDim2(0.5, 0, 1, -40)} onClick={advance} visible={textIn} />
		</frame>
	);
}

// ---------------------------------------------------------------- empty / failure

function EmptyReveal(props: { onClose: () => void }) {
	const t = useStageClock("empty", 0.4);
	useOverlayInput(props.onClose);
	const show = t.map((s) => math.clamp(s / 0.2, 0, 1));
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ZIndex={500}>
			<Backdrop tint={Palette.coral} amount={show} onTap={props.onClose} />
			<textlabel
				AnchorPoint={new Vector2(0.5, 0.5)}
				Size={UDim2.fromOffset(300, 48)}
				Position={UDim2.fromScale(0.5, 0.42)}
				BackgroundTransparency={1}
				Text={"The crate didn't open.\nNothing was used. Try again."}
				TextColor3={Palette.cream}
				TextTransparency={show.map((a) => 1 - a)}
				TextSize={16}
				TextWrapped={true}
				FontFace={Font.fromEnum(Enum.Font.BuilderSansBold)}
				ZIndex={505}
			/>
			<ActionButton text="Back" accent={Palette.coral} position={new UDim2(0.5, 0, 1, -40)} onClick={props.onClose} visible={show} />
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

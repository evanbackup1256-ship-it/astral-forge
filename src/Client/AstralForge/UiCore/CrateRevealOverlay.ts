import React from "@rbxts/react";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { InteractionFeedback } from "../CoreKit/interaction";
import { chromeFor, Palette, TapTarget } from "../CoreKit/theme";
import { useAntilag } from "../MotionKit/antilag";
import {
	easeOutCubic,
	resolveIntent,
	useBoatTween,
	useExitTransition,
	useFlash,
	useFlipperSpring,
	useViewport,
} from "../MotionKit/motion";
import { Button, Panel, Text, useGamepadAutofocus } from "./ui";

const h = React.createElement as unknown as (component: unknown, props?: object, ...children: unknown[]) => React.Element;

const ContextActionService = game.GetService("ContextActionService");
const GuiService = game.GetService("GuiService");
const RunService = game.GetService("RunService");
const UserInputService = game.GetService("UserInputService");
const ReplicatedStorage = game.GetService("ReplicatedStorage");

const AstralForge = script.Parent!.Parent!;

interface AudioApi {
	play(name: string, pitch?: number): void;
	playCelebration(cues: string[], gap: number): void;
}
const Audio = (
	(require(AstralForge.WaitForChild("AudioKit") as ModuleScript) as (member: string) => unknown)("audio") as { Audio: AudioApi }
).Audio;
const CrateRevealStage = (
	(require(AstralForge.WaitForChild("pages").WaitForChild("PagesShop") as ModuleScript) as (member: string) => unknown)(
		"CrateRevealStage",
	) as { CrateRevealStage: unknown }
).CrateRevealStage;

interface JuiceFxModule {
	burst(this: void, at: Vector2 | undefined, color: Color3, scale: number): void;
	flash(this: void, color: Color3, strength: number): void;
	moment(this: void, title: string, detail: string | undefined, color: Color3, icon: string): void;
	status(this: void, text: string, kind: string): void;
}

const CARD_W = 156;
const CARD_H = 132;
const CARD_GAP = 12;
const STRIDE = CARD_W + CARD_GAP;
const START_SLOT = 2;
const WIN_SLOT = 15;
const FILLER_COUNT = 19;
const START_OFFSET = START_SLOT * STRIDE;
const TARGET_OFFSET = WIN_SLOT * STRIDE;
const SPIN_SECONDS = 3.8;
const BATCH_SPIN_SECONDS = 1.42;
const EXIT_SETTLE = 0.42;
// the resonance climb walks this ladder one rung at a time before an Epic-or-better drop lands
const RARITY_LADDER = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial", "Astral"];
const CLIMB_FROM_RANK = 4;

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
		Crates?: Array<{ Id: string; Weights?: Record<string, number> }>;
	};
}
interface RevealSession {
	rolls?: unknown;
	crateId?: string;
	crateName?: string;
	accent?: unknown;
}
interface StripCard {
	key: string;
	definitionId: string;
	name: string;
	rarity: string;
	accent: Color3;
	winner: boolean;
	tag?: string;
}

function rarityRank(rarity: unknown) {
	for (const [index, name] of ipairs(RARITY_LADDER)) {
		if (name === rarity) {
			return index;
		}
	}
	return 1;
}
function playRevealCues(roll: Roll | undefined) {
	if (roll === undefined) {
		Audio.play("crateLand");
		return;
	}
	const plan = resolveIntent({ role: "reveal", rarity: roll.Rarity });
	const cue = plan.cue as string | undefined;
	const weight = plan.weight as number;
	const celebrate = plan.celebrate !== undefined && plan.celebrate !== false;
	const special = roll.New === true || roll.Pity === true;
	if (celebrate) {
		Audio.playCelebration([cue ?? "crateRevealMythic", "discovery", "prestige", "reward"], 0.12);
		InteractionFeedback.reward();
	} else if (weight >= 0.75) {
		Audio.playCelebration([cue ?? "crateRevealMythic", "discovery", "reward"], 0.08);
	} else if (weight >= 0.4) {
		Audio.playCelebration([cue ?? "crateRevealEpic", special ? "crateRare" : "crateLand"], 0.06);
	} else {
		Audio.play(special ? "crateRare" : "crateLand");
	}
	// the reveal lands with light that scales with rarity
	const Juice = require(AstralForge.WaitForChild("JuiceFx") as ModuleScript) as JuiceFxModule;
	const camera = game.GetService("Workspace").CurrentCamera;
	const centre = camera ? camera.ViewportSize.div(2) : undefined;
	const accent =
		(Palette as unknown as Record<string, Color3 | undefined>)[string.lower(tostring(roll.Rarity ?? ""))] ?? Palette.mango;
	if (weight >= 0.4) {
		Juice.burst(centre, accent, 0.9 + weight);
	}
	if (celebrate || weight >= 0.75) {
		Juice.flash(Palette.cream, celebrate ? 0.55 : 0.3);
		Juice.moment(`${string.upper(tostring(roll.Rarity ?? "RARE"))}`, special ? "New to your collection." : undefined, accent, "Crate.18");
	} else if (special) {
		Juice.status("New to your collection", "special");
	}
}
function rarityColor(config: CrateConfig, rarity: string): Color3 {
	return config.Items?.Rarities[rarity]?.Color ?? Palette.mango;
}
function definitionName(config: CrateConfig, definitionId: string) {
	for (const definition of config.Items?.Definitions ?? []) {
		if (definition.Id === definitionId) {
			return definition.Name;
		}
	}
	return definitionId;
}
function buildStrip(config: CrateConfig, session: RevealSession, roll: Roll, rollIndex: number): StripCard[] {
	const crate = (config.Items?.Crates ?? []).find((entry) => entry.Id === session.crateId);
	const weights = crate?.Weights ?? { Common: 1 };
	const definitions = config.Items?.Definitions ?? [];
	const pools: Record<string, Definition[] | undefined> = {};
	for (const definition of definitions) {
		let pool = pools[definition.Rarity];
		if (pool === undefined) {
			pool = [];
			pools[definition.Rarity] = pool;
		}
		pool.push(definition);
	}
	const weighted: Array<{ rarity: string; weight: number }> = [];
	let totalWeight = 0;
	for (const [rarity, rawWeight] of pairs(weights)) {
		const weight = math.max(0, rawWeight);
		if (weight <= 0) {
			continue;
		}
		weighted.push({ rarity: rarity, weight: weight });
		totalWeight += weight;
	}
	weighted.sort((a, b) => a.rarity < b.rarity);
	const fillerAt = (seed: number): Definition | undefined => {
		if (definitions.size() === 0) {
			return undefined;
		}
		if (totalWeight <= 0) {
			return definitions[seed % definitions.size()];
		}
		let sample = ((math.abs(math.sin(seed * 12.9898)) * 43758.5453) % 1) * totalWeight;
		let selected: string | undefined;
		for (const entry of weighted) {
			sample -= entry.weight;
			if (sample <= 0) {
				selected = entry.rarity;
				break;
			}
		}
		const pool = selected !== undefined ? pools[selected] : undefined;
		if (pool === undefined || pool.size() === 0) {
			return definitions[seed % definitions.size()];
		}
		return pool[seed % pool.size()];
	};
	const cards: StripCard[] = [];
	for (let index = 0; index <= FILLER_COUNT - 1; index++) {
		if (index === WIN_SLOT) {
			cards.push({
				key: `winner-${roll.Uid}-${rollIndex}`,
				definitionId: roll.DefinitionId,
				name: definitionName(config, roll.DefinitionId),
				rarity: roll.Rarity,
				accent: rarityColor(config, roll.Rarity),
				winner: true,
				tag: roll.New === true ? "NEW" : roll.Pity === true ? "PITY" : "WIN",
			});
			continue;
		}
		const filler = fillerAt(rollIndex * 97 + index * 13 + 11);
		cards.push({
			key: filler !== undefined ? `filler-${rollIndex}-${index}-${filler.Id}` : `fallback-${rollIndex}-${index}`,
			definitionId: filler?.Id ?? roll.DefinitionId,
			name: filler?.Name ?? definitionName(config, roll.DefinitionId),
			rarity: filler?.Rarity ?? roll.Rarity,
			accent: rarityColor(config, filler?.Rarity ?? roll.Rarity),
			winner: false,
		});
	}
	return cards;
}
function reelProgress(t: number, travel: number) {
	const x = math.clamp(t, 0, 1);
	if (x <= 0.13) {
		const u = x / 0.13;
		return 0.055 * u * u * u;
	}
	if (x <= 0.67) {
		const u = (x - 0.13) / 0.54;
		return 0.055 + 0.735 * (u + math.sin(u * math.pi) * 0.035);
	}
	if (x <= 0.92) {
		const u = (x - 0.67) / 0.25;
		return 0.79 + 0.21 * (1 - (1 - u) ** 3.7);
	}
	const u = (x - 0.92) / 0.08;
	const overshoot = math.min(0.018, (STRIDE * 0.34) / math.max(STRIDE, travel));
	return 1 + math.sin(u * math.pi * 2) * math.exp(-3.6 * u) * overshoot;
}

interface CrateAppearanceModule {
	resolve(this: void, skin: unknown, crateId: unknown, crates: unknown): unknown;
}

export interface CrateRevealProps {
	session?: RevealSession;
	config: CrateConfig;
	reducedMotion?: boolean;
	onClose: () => void;
	skin?: unknown;
	[key: string]: unknown;
}

function CrateRevealExperience(param: CrateRevealProps) {
	const session = param.session!;
	const config = param.config;
	const reducedMotion = param.reducedMotion;
	const onClose = param.onClose;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const antilag = useAntilag();
	const reelFrameRate = 240;
	const [rollIndex, setRollIndex] = React.useState(0);
	const [phase, setPhase] = React.useState("enter");
	const [offset, setOffset] = React.useBinding(START_OFFSET);
	const [spinEnergy, setSpinEnergy] = React.useBinding(0);
	const [spinProgress, setSpinProgress] = React.useBinding(0);
	const [tickEnergy, setTickEnergy] = React.useBinding(0);
	const closedRef = React.useRef(false);
	const spinSettledRef = React.useRef(false);
	const quickLandAtRef = React.useRef(-1);
	const quickLandOffsetRef = React.useRef(START_OFFSET);
	const brakeSoundedRef = React.useRef(false);
	const [live, setLive] = React.useState(false);
	const [climbStep, setClimbStep] = React.useState(0);
	const climbSkipRef = React.useRef(false);
	const [exitAmount, exiting, beginExit] = useExitTransition(reducedMotion, EXIT_SETTLE);
	React.useEffect(() => {
		let alive = true;
		const job = task.defer(() => {
			if (alive) {
				setLive(true);
			}
		});
		return () => {
			alive = false;
			pcall(task.cancel, job);
		};
	}, []);
	const present = live;
	const motionScale = reducedMotion ? 0.55 : 1;
	const boatShow = useBoatTween(present ? 1 : 0, (present ? 0.3 : EXIT_SETTLE) * motionScale, false, easeOutCubic, 0);
	const show = useFlipperSpring(present ? 1 : 0, false, 720, 36);
	const landHold = phase === "land" || phase === "done" || phase === "exit";
	const claimHold = phase === "done" || phase === "exit";
	const landPop = useFlipperSpring(landHold ? 1 : 0, false, 640, 14);
	const claimSlide = useFlipperSpring(claimHold ? 1 : 0, false, 520, 24);
	const landFlash = useFlash(phase === "land" ? rollIndex + 1 : 0, false, 0.62 * motionScale);
	const claimFlash = useFlash(phase === "done" ? rollIndex + 11 : 0, false, 0.48 * motionScale);
	const sealFlash = useFlash(phase === "seal" ? rollIndex + 21 : 0, false, 0.55 * motionScale);
	const climbFlash = useFlash(phase === "climb" ? climbStep + 31 : 0, false, 0.22);
	const chargePulse = useFlipperSpring(phase === "charge" || phase === "seal" ? 1 : 0, false, 360, 19);
	let rolls = session.rolls as Roll[];
	if (!typeIs(rolls, "table")) {
		rolls = [];
	}
	const currentRoll = rolls[math.clamp(rollIndex, 0, math.max(0, rolls.size() - 1))] as Roll | undefined;
	const strip = React.useMemo(
		() => buildStrip(config, session, currentRoll!, rollIndex),
		[config, currentRoll, rollIndex, session],
	);
	const travelDistance = TARGET_OFFSET - START_OFFSET;
	React.useEffect(() => {
		const previousTouch = GuiService.TouchControlsEnabled;
		GamepadNavigationService.BeginOverlayFocus();
		GuiService.TouchControlsEnabled = false;
		return () => {
			GamepadNavigationService.EndOverlayFocus();
			GuiService.TouchControlsEnabled = previousTouch;
		};
	}, []);
	const phaseAfter = (from: string, seconds: number, to: string, onStart?: () => void) => {
		if (phase !== from) {
			return undefined;
		}
		onStart?.();
		let alive = true;
		const job = task.delay(seconds, () => {
			if (alive) {
				setPhase(to);
			}
		});
		return () => {
			alive = false;
			pcall(task.cancel, job);
		};
	};
	React.useEffect(() => phaseAfter("enter", reducedMotion ? 0.12 : 0.2, "charge"), [phase, reducedMotion]);
	React.useEffect(
		() => phaseAfter("charge", reducedMotion ? 0.32 : 0.62, "seal", () => Audio.play("crateCharge")),
		[phase, reducedMotion],
	);
	React.useEffect(
		() =>
			phaseAfter("seal", reducedMotion ? 0.16 : 0.44, "spin", () => {
				Audio.play("crateSeal");
				InteractionFeedback.confirm();
			}),
		[phase, reducedMotion],
	);
	const landCurrent = React.useCallback(() => {
		if (spinSettledRef.current) {
			return undefined;
		}
		spinSettledRef.current = true;
		setOffset(TARGET_OFFSET);
		setSpinEnergy(0);
		setSpinProgress(1);
		setTickEnergy(1);
		const rank = currentRoll !== undefined ? rarityRank(currentRoll.Rarity) : 1;
		if (rank >= CLIMB_FROM_RANK && !reducedMotion) {
			climbSkipRef.current = false;
			setClimbStep(0);
			setPhase("climb");
			return;
		}
		setPhase("land");
		playRevealCues(currentRoll);
		InteractionFeedback.reward();
	}, [currentRoll, reducedMotion, setOffset, setSpinEnergy, setSpinProgress, setTickEnergy]);
	React.useEffect(() => {
		if (phase !== "climb") {
			return undefined;
		}
		let alive = true;
		const target = currentRoll !== undefined ? rarityRank(currentRoll.Rarity) : 1;
		const job = task.spawn(() => {
			// each rung arrives a little faster than the last, so the climb accelerates into the reveal
			for (let step = 1; step <= target; step++) {
				if (!alive || climbSkipRef.current) {
					break;
				}
				setClimbStep(step);
				Audio.play("crateRarityStep", 0.88 + step * 0.07);
				if (step >= CLIMB_FROM_RANK) {
					InteractionFeedback.tick();
				}
				task.wait(math.max(0.07, 0.17 - step * 0.012));
			}
			if (!alive) {
				return;
			}
			setClimbStep(target);
			task.wait(0.08);
			if (!alive) {
				return;
			}
			setPhase("land");
			playRevealCues(currentRoll);
			InteractionFeedback.reward();
		});
		return () => {
			alive = false;
			pcall(task.cancel, job);
		};
	}, [phase, currentRoll]);
	const skipSpin = React.useCallback(() => {
		if (phase === "climb") {
			climbSkipRef.current = true;
			return undefined;
		}
		if (phase !== "spin") {
			return undefined;
		}
		Audio.play("crateNear");
		if (quickLandAtRef.current < 0) {
			quickLandAtRef.current = os.clock();
			quickLandOffsetRef.current = START_OFFSET;
		}
	}, [phase]);
	React.useEffect(() => {
		if (phase !== "spin") {
			return undefined;
		}
		spinSettledRef.current = false;
		setOffset(START_OFFSET);
		setSpinEnergy(0);
		setSpinProgress(0);
		setTickEnergy(0);
		quickLandAtRef.current = -1;
		quickLandOffsetRef.current = START_OFFSET;
		brakeSoundedRef.current = false;
		Audio.play("crateOpen");
		if (rollIndex === 0 && !reducedMotion) {
			Audio.play("crateOrbit");
		}
		const startedAt = os.clock();
		let lastVisualAt = startedAt - 1 / reelFrameRate;
		const duration = (rollIndex === 0 ? SPIN_SECONDS : BATCH_SPIN_SECONDS) * (reducedMotion ? 0.55 : 1);
		let lastTickSlot = -1;
		let lastTickAt = -math.huge;
		let previousValue = START_OFFSET;
		let tick = 0;
		const connection: RBXScriptConnection = RunService.RenderStepped.Connect(() => {
			if (spinSettledRef.current) {
				connection.Disconnect();
				return undefined;
			}
			const now = os.clock();
			const elapsed = now - startedAt;
			let raw = math.clamp(elapsed / duration, 0, 1);
			if (raw < 1 && now - lastVisualAt < 1 / reelFrameRate) {
				return undefined;
			}
			const visualDelta = math.max(1 / 240, now - lastVisualAt);
			lastVisualAt = now;
			let value: number;
			if (quickLandAtRef.current >= 0) {
				if (quickLandOffsetRef.current === START_OFFSET) {
					quickLandOffsetRef.current = previousValue;
				}
				const quick = math.clamp((now - quickLandAtRef.current) / 0.34, 0, 1);
				value = quickLandOffsetRef.current + (TARGET_OFFSET - quickLandOffsetRef.current) * (1 - (1 - quick) ** 4);
				raw = 0.94 + quick * 0.06;
			} else {
				value = START_OFFSET + travelDistance * reelProgress(raw, travelDistance);
			}
			setOffset(value);
			setSpinProgress(raw);
			const cardsPerSecond = math.abs(value - previousValue) / visualDelta / STRIDE;
			previousValue = value;
			const authoredEnergy = raw < 0.1 ? raw / 0.1 : raw < 0.7 ? 1 : math.clamp((0.97 - raw) / 0.27, 0, 1);
			setSpinEnergy(math.clamp(cardsPerSecond / 18, 0, 1) * authoredEnergy);
			if (raw >= 0.69 && !brakeSoundedRef.current) {
				brakeSoundedRef.current = true;
				Audio.play("crateBrake");
			}
			tick *= math.exp(-visualDelta * 18);
			const slot = math.floor(value / STRIDE + 0.5);
			const tickGap = rollIndex === 0 ? 0.045 : 0.065;
			if (slot !== lastTickSlot && raw < 0.97 && elapsed - lastTickAt >= tickGap) {
				lastTickSlot = slot;
				lastTickAt = elapsed;
				tick = raw > 0.72 ? 1 : 0.58;
				Audio.play("crateTick", 0.94 + raw * 0.18);
				if (raw > 0.72) {
					InteractionFeedback.tick();
				}
			}
			setTickEnergy(tick);
			if (raw >= 1) {
				connection.Disconnect();
				landCurrent();
			}
		});
		return () => connection.Disconnect();
	}, [
		landCurrent,
		phase,
		reducedMotion,
		reelFrameRate,
		rollIndex,
		setOffset,
		setSpinEnergy,
		setSpinProgress,
		setTickEnergy,
		travelDistance,
	]);
	React.useEffect(() => {
		if (phase !== "land") {
			return undefined;
		}
		let alive = true;
		const landed = rolls[rollIndex] as Roll | undefined;
		const ascended = landed !== undefined && (landed.Rarity === "Celestial" || landed.Rarity === "Astral");
		const hold = ascended ? 1.6 : rollIndex >= rolls.size() - 1 ? 0.72 : 0.62;
		const job = task.delay(hold, () => {
			if (!alive) {
				return undefined;
			}
			if (rollIndex >= rolls.size() - 1) {
				setPhase("done");
			} else {
				setRollIndex((value) => value + 1);
				setPhase("spin");
			}
		});
		return () => {
			alive = false;
			pcall(task.cancel, job);
		};
	}, [phase, rollIndex, rolls]);
	const finish = React.useCallback(() => {
		if (closedRef.current || phase === "exit" || exiting) {
			return undefined;
		}
		GamepadNavigationService.ClearSelection();
		Audio.play("crateClaim");
		InteractionFeedback.confirm();
		setPhase("exit");
		beginExit(() => {
			if (!closedRef.current) {
				closedRef.current = true;
				onClose();
			}
		});
	}, [beginExit, exiting, onClose, phase]);
	React.useEffect(() => {
		const actionName = "AstralForgeCrateClose";
		ContextActionService.BindActionAtPriority(
			actionName,
			(_name, inputState) => {
				if (inputState === Enum.UserInputState.Begin) {
					if (phase === "spin" || phase === "climb") {
						skipSpin();
					} else if (phase === "done") {
						finish();
					}
				}
				return Enum.ContextActionResult.Sink;
			},
			false,
			2300,
			Enum.KeyCode.ButtonB,
		);
		const input = UserInputService.InputBegan.Connect((event, processed) => {
			if (processed) {
				return undefined;
			}
			const activate =
				event.KeyCode === Enum.KeyCode.ButtonA || event.KeyCode === Enum.KeyCode.Return || event.KeyCode === Enum.KeyCode.Space;
			if (!activate) {
				return undefined;
			}
			if (phase === "spin" || phase === "climb") {
				skipSpin();
			} else if (phase === "done") {
				finish();
			}
		});
		return () => {
			input.Disconnect();
			ContextActionService.UnbindAction(actionName);
		};
	}, [finish, phase, skipSpin]);
	const count = rolls.size();
	const safeRoll: Roll = currentRoll ?? {
		Rarity: "Common",
		DefinitionId: "Unknown",
		New: false,
		Pity: false,
		AutoSalvaged: false,
		Essence: 0,
	};
	const winnerAccent = rarityColor(config, safeRoll.Rarity);
	const resultTag =
		safeRoll.AutoSalvaged === true
			? `+${safeRoll.Essence ?? 0} ESSENCE`
			: safeRoll.New === true
				? "NEW FIND"
				: safeRoll.Pity === true
					? "PITY DROP"
					: "OWNED";
	const resultDetail =
		safeRoll.AutoSalvaged === true
			? "Relic Recycler converted this drop into essence."
			: safeRoll.Pity === true
				? "Pity protection delivered this rarity."
				: safeRoll.New === true
					? "Added to your relic inventory."
					: "Added to your inventory.";
	const claimText = rolls.every((roll) => roll.AutoSalvaged === true)
		? "BANK ESSENCE"
		: count === 1
			? "CLAIM RELIC"
			: `CLAIM ${count} DROPS`;
	const visualShow = React.joinBindings([show, boatShow, exitAmount]).map((values) =>
		math.clamp(math.min(values[0], values[1], values[2]), 0, 1),
	);
	const winnerCardScale = React.joinBindings([landPop, landFlash, claimFlash]).map(
		(values) => 0.94 + values[0] * 0.075 + values[1] * 0.025 + values[2] * 0.02,
	);
	const CrateAppearance = require(
		ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("CrateAppearance") as ModuleScript,
	) as CrateAppearanceModule;
	const ladderColors: Color3[] = [];
	for (const name of RARITY_LADDER) {
		ladderColors.push(rarityColor(config, name));
	}
	return h(CrateRevealStage, {
		crateName: session.crateName,
		skin: CrateAppearance.resolve(param.skin, session.crateId, config.Items!.Crates),
		sessionAccent: session.accent,
		cards: strip,
		cardWidth: CARD_W,
		cardHeight: CARD_H,
		stride: STRIDE,
		reelOffset: offset,
		phase: phase,
		rollIndex: rollIndex,
		rollCount: count,
		winnerName: definitionName(config, safeRoll.DefinitionId),
		winnerRarity: safeRoll.Rarity,
		winnerAccent: winnerAccent,
		resultTag: resultTag,
		resultDetail: resultDetail,
		claimText: claimText,
		reducedMotion: reducedMotion,
		shortLandscape: chrome.landscape && viewport.height < 400,
		portrait: chrome.portrait,
		viewportWidth: viewport.width,
		viewportHeight: viewport.height,
		topInset: viewport.topInset,
		bottomSafe: math.max(chrome.bottomSafe, 8),
		sideSafe: math.max(chrome.sideSafe, viewport.sideInset),
		fxBudget: antilag.fxBudget,
		glowScale: antilag.glowScale,
		allowAmbient: antilag.allowAmbient,
		economyMode: chrome.mobile || antilag.tier <= 1,
		visualShow: visualShow,
		spinEnergy: spinEnergy,
		spinProgress: spinProgress,
		tickEnergy: tickEnergy,
		landFlash: landFlash,
		landPop: landPop,
		claimSlide: claimSlide,
		chargePulse: chargePulse,
		sealFlash: sealFlash,
		climbFlash: climbFlash,
		climbStep: climbStep,
		climbColor: rarityColor(config, RARITY_LADDER[math.clamp(climbStep, 1, RARITY_LADDER.size()) - 1]),
		winnerRank: rarityRank(safeRoll.Rarity),
		ladderColors: ladderColors,
		winnerCardScale: winnerCardScale,
		onQuickLand: skipSpin,
		onClaim: finish,
	});
}

function EmptyCrateReveal(param: { reducedMotion?: boolean; onClose: () => void }) {
	const reducedMotion = param.reducedMotion;
	const onClose = param.onClose;
	const viewport = useViewport();
	const safeGutter = viewport.sideInset + 10;
	const width = math.max(1, math.min(360, viewport.width - safeGutter * 2));
	const focusRef = useGamepadAutofocus(true);
	React.useEffect(() => {
		GamepadNavigationService.BeginOverlayFocus();
		return () => GamepadNavigationService.EndOverlayFocus();
	}, []);
	React.useEffect(() => {
		const host = focusRef.current;
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
			pcall(task.cancel, job);
		};
	}, []);
	return h(
		"frame",
		{
			ref: focusRef,
			Name: "CrateClaim",
			Size: UDim2.fromScale(1, 1),
			BackgroundColor3: Palette.void,
			BackgroundTransparency: 0.02,
			BorderSizePixel: 0,
			ClipsDescendants: false,
			Active: true,
			ZIndex: 400,
		},
		h(
			"frame",
			{
				Size: UDim2.fromOffset(width, 164),
				Position: UDim2.fromScale(0.5, 0.5),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				ZIndex: 410,
			},
			h(
				Panel,
				{ size: UDim2.fromScale(1, 1), accent: Palette.coral, background: Palette.panelRaised, padding: 16, clips: false, zIndex: 411 },
				h(Text, {
					value: "Crate didn't open",
					size: 20,
					color: Palette.cream,
					weight: Enum.FontWeight.Heavy,
					align: Enum.TextXAlignment.Center,
					fit: true,
					minSize: 14,
					sizeConstraint: new UDim2(1, 0, 0, 28),
					zIndex: 412,
				}),
				h(Text, {
					value: "Nothing was taken. Try opening it again.",
					size: 12,
					color: Palette.creamSoft,
					align: Enum.TextXAlignment.Center,
					wrap: true,
					position: UDim2.fromOffset(0, 36),
					sizeConstraint: new UDim2(1, 0, 0, 40),
					zIndex: 412,
				}),
				h(Button, {
					text: "BACK TO INVENTORY",
					icon: "Close.25",
					onClick: onClose,
					color: Palette.coral,
					textColor: Palette.ink,
					size: new UDim2(1, 0, 0, TapTarget),
					position: new UDim2(0, 0, 1, -TapTarget),
					reducedMotion: reducedMotion,
					selectable: true,
					highlight: true,
					zIndex: 413,
				}),
			),
		),
	);
}

export function CrateRevealOverlay(props: CrateRevealProps) {
	const session = props.session;
	const rolls = session !== undefined ? session.rolls : undefined;
	const hasRolls = typeIs(rolls, "table") && (rolls as unknown[]).size() > 0;
	if (hasRolls) {
		const attributes = table.clone(props);
		setmetatable(attributes, undefined as unknown as LuaMetatable<CrateRevealProps>);
		return h(CrateRevealExperience, attributes);
	}
	return h(EmptyCrateReveal, { reducedMotion: props.reducedMotion, onClose: props.onClose });
}

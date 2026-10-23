import React from "@rbxts/react";
import OmegaMath = require("../../../../Shared/AstralForge/Shared/OmegaMath");
import * as FirstGoals from "../../../../Shared/AstralForge/Shared/FirstGoals";
import { AppHelpers } from "../../CoreKit/appNav";
import { asFlux, compactNumber, Flux, gteFlux } from "../../CoreKit/format";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import * as JourneyMath from "../../CoreKit/journeyMath";
import * as ReleaseClockMath from "../../CoreKit/releaseClockMath";
import { chromeFor, darken, Layout, Pad, Palette, Radius, scrollTail, Space, surfaceGradient, TapTarget, TypeScale } from "../../CoreKit/theme";
import * as VaultCollectEligibility from "../../CoreKit/vaultCollectEligibility";
import { useAntilag } from "../../MotionKit/antilag";
import { Flex, FlexItem } from "../../MotionKit/flexbox";
import { useClock, useFlash, usePulse, useStagger, useViewport } from "../../MotionKit/motion";
import makeOverviewGoal = require("../../OverviewGoals");
import QuickFind = require("../../QuickFind");
import ReadyBoard = require("../../ReadyBoard");
import SessionStats = require("../../SessionStats");
import { useFocusOrder } from "../../CoreKit/focusOrder";
import { named } from "../luauDeps";
import { AudioPlayer, kitMember, LuauComponent } from "../luauKits";
import { RebirthPanel } from "./RebirthPanel";

const UserInputService = game.GetService("UserInputService");
const Workspace = game.GetService("Workspace");

interface UiKit {
	Badge: LuauComponent;
	Button: LuauComponent;
	IconTile: LuauComponent;
	Meter: LuauComponent;
	Panel: LuauComponent;
	ShimmerText: LuauComponent;
	Text: LuauComponent;
	meterFill: (this: void, value: number, target: number) => number;
}
const { Badge, Button, IconTile, Meter, Panel, ShimmerText, Text, meterFill } = kitMember<UiKit>("UiCore", "ui");
const { PageScaffold } = kitMember<{ PageScaffold: LuauComponent }>("LayoutKit", "pageScaffold");
const { NumberSpinnerHost } = kitMember<{ NumberSpinnerHost: LuauComponent }>("ReactHosts", "NumberSpinnerHost");
const { Audio } = kitMember<{ Audio: AudioPlayer }>("AudioKit", "audio");

interface OverviewFlags {
	stack: boolean;
	phone: boolean;
	landscapePhone: boolean;
	wideOverview: boolean;
	ultraOverview: boolean;
	rebirthVisible: boolean;
	domainVisible: boolean;
	countdownInPage: boolean;
	short: boolean;
	chromePanelGap: number;
	layoutPanelGap: number;
	fitHeight?: number;
	roomyHero?: boolean;
}
interface OverviewPlan {
	heroH: number;
	heroBandH?: number;
	rebirthH: number;
	domainH: number;
	notesH: number;
	opsH: number;
	metricCardH: number;
	metricsH: number;
	countdownH: number;
	sectionGap: number;
	topBandH: number;
	sectionCount: number;
	overviewTail: number;
	contentIntrinsic: number;
}
const LayoutSectionPlan = kitMember<{ planOverview(this: void, flags: OverviewFlags): OverviewPlan }>("LayoutKit", "layoutSectionPlan");
const PageReadyMath = kitMember<{
	CountReadyQuests(this: void, quests: unknown): number;
	CountReadyLabOrders(this: void, lab: unknown): number;
	ForgePathReady(this: void, state: unknown, config: unknown): boolean;
	OpsClaims(this: void, missionsReady: unknown, labReady: unknown, pathReady: unknown, anomalyReady: unknown): number;
}>("LayoutKit", "pageReadyMath");

const overviewGoal = makeOverviewGoal(OmegaMath, compactNumber);

interface FirstGoalView {
	goal: FirstGoals.FirstGoal;
	index: number;
	have: number;
	done: boolean;
	open: boolean;
}

// the first-goals path after the tour, until every goal is claimed or the player turns it off
type FirstGoalState = {
	Flags?: { TutorialDone?: unknown; FirstGoals?: unknown };
	Settings?: { FirstGoals?: unknown };
	Stats?: { MachinesBought?: unknown; ResearchBought?: unknown; CratesOpened?: unknown; ItemsSalvaged?: unknown };
	Level?: { Level?: unknown };
	Rebirths?: unknown;
	PrestigeReward?: unknown;
	FeatureUnlocks?: Record<string, { Unlocked?: unknown } | undefined>;
};
// main card: room between the vault readout and the Collect column on desktop
const HERO_COLUMN_GAP = 28;
// roomy hero: gap between the readout/CTA row and the full-width vault meter band under it
const HERO_BAND_GAP = 18;
const denseHeroFor = (short: boolean, wide: boolean, phone: boolean) => short && wide && !phone;

function firstGoalView(raw: unknown): FirstGoalView | undefined {
	const state = raw as FirstGoalState;
	if (state.Flags?.TutorialDone !== true || state.Settings?.FirstGoals === 0) {
		return undefined;
	}
	const [goal, index] = FirstGoals.currentGoal(FirstGoals.normalizeClaimed(state.Flags.FirstGoals));
	if (goal === undefined) {
		return undefined;
	}
	const count = (value: unknown) => (typeIs(value, "number") ? value : 0);
	const [have, done] = FirstGoals.progressOf(goal, {
		machinesBought: count(state.Stats?.MachinesBought),
		researchBought: count(state.Stats?.ResearchBought),
		cratesOpened: count(state.Stats?.CratesOpened),
		itemsSalvaged: count(state.Stats?.ItemsSalvaged),
		level: count(state.Level?.Level),
		rebirths: count(state.Rebirths),
		rebirthReady: OmegaMath.Gte((state.PrestigeReward ?? 0) as never, 1),
	});
	const gate = state.FeatureUnlocks?.[goal.page];
	return { goal, index, have, done, open: gate === undefined || gate.Unlocked !== false };
}

type Dispatch = (action: string, payload?: object, callback?: (response: { ok?: boolean }) => void) => unknown;

interface NextLevelStep {
	Level?: number;
	Text?: string;
	Progress?: unknown;
	Target?: unknown;
}
interface DomainState {
	Rank: number;
	Essence: Flux;
	LastExpandedAt: number;
	TotalRebirthsSpent: number;
	TotalCoresSpent: number;
	RequiredRebirths: number;
	RequiredCores: number;
	CanExpand: boolean;
	EssenceReward: Flux;
	StardustReward: Flux;
	ProductionMultiplier: Flux;
	CapacityMultiplier: Flux;
	OfflineBonus: number;
	SkillPoints: number;
	Nodes: unknown[];
}
interface OverviewState {
	Vault: Flux;
	Cash: Flux;
	RunCash: Flux;
	Capacity: Flux;
	CapacitySeconds?: number;
	Production: Flux;
	RawProduction: Flux;
	PermanentMultiplier: Flux;
	TapPower?: number;
	Rebirths: number;
	Zone?: number;
	Cores: number;
	PrestigeReward: Flux;
	NextPrestigeTarget: Flux;
	OfflineHours?: unknown;
	Flags?: { TutorialDone?: boolean };
	FeatureUnlocks?: Record<string, { Unlocked?: boolean } | undefined>;
	Machines: Record<string, number | undefined>;
	Research: { Efficiency?: number; Storage?: number; Offline?: number; Overcharge?: number };
	Level?: { Next?: NextLevelStep };
	Quests?: unknown;
	Lab?: unknown;
	Domain?: DomainState;
	[key: string]: unknown;
}
interface MachineConfig {
	Id: string;
	Name?: string;
	BaseProduction?: number;
	PreviousId?: string;
	PreviousLevel?: number;
	RequiredRebirths?: number;
	RequiredZone?: number;
}
interface OverviewGuide {
	OpsTitle?: string;
	OpsBody?: string;
	EmptyClaims?: string;
}
interface OverviewConfig {
	Economy?: { Rebirth?: { StardustSqrtScale?: number; StardustMinimum?: number }; PrestigeRequirement?: number };
	Machines?: MachineConfig[];
	ClientPageGuides?: { Overview?: OverviewGuide };
	[key: string]: unknown;
}
interface Section {
	id: string;
	height?: number;
	fill?: boolean;
	minHeight?: number;
	element: React.Element;
}

interface ReleaseCountdownProps {
	releaseAt?: number;
	reducedMotion?: boolean;
	stack?: boolean;
	layoutOrder?: number;
}

function ReleaseCountdown({ releaseAt, reducedMotion, stack, layoutOrder }: ReleaseCountdownProps) {
	const viewport = useViewport();
	const syncedNow = () => {
		const [ok, value] = pcall(() => Workspace.GetServerTimeNow());
		if (ok && typeIs(value, "number")) {
			return math.floor(value);
		}
		return os.time();
	};
	const [now, setNow] = React.useState(syncedNow());
	React.useEffect(() => {
		let alive = true;
		const worker = task.spawn(() => {
			while (alive) {
				task.wait(0.5);
				if (alive) {
					const current = syncedNow();
					setNow(current);
					// once it's live nothing on the card reads the clock again; stop waking up
					// (and re-rendering) every second for the rest of the session
					if (ReleaseClockMath.IsLive(releaseAt, current)) {
						break;
					}
				}
			}
		});
		return () => {
			alive = false;
			pcall(() => task.cancel(worker));
		};
	}, [releaseAt]);
	const remaining = ReleaseClockMath.Remaining(releaseAt, now);
	const live = ReleaseClockMath.IsLive(releaseAt, now);
	const [slam, setSlam] = React.useState(0);
	const wasLive = React.useRef(live);
	React.useEffect(() => {
		if (live && !wasLive.current) {
			wasLive.current = true;
			setSlam((n) => n + 1);
			if (!reducedMotion) {
				Audio.play("prestige");
				Audio.play("bootFinaleBang");
			}
		}
		if (!live) {
			wasLive.current = false;
		}
	}, [live, reducedMotion]);
	const animateLive = live;
	const pulse = usePulse(animateLive, 2.15);
	const flash = useFlash(slam, reducedMotion, 1.2);
	const orbit = useClock(animateLive, 0.48, 1, true);
	const values = [
		{ label: "days", value: math.floor(remaining / 86400), color: Palette.cyan },
		{ label: "hrs", value: math.floor(remaining / 3600) % 24, color: Palette.violet },
		{ label: "min", value: math.floor(remaining / 60) % 60, color: Palette.pink },
		{ label: "sec", value: remaining % 60, color: Palette.mango },
	];
	const railBelowCopy = stack === true || viewport.width < 1080;
	const height = live ? (railBelowCopy ? 170 : 148) : railBelowCopy ? 162 : 132;
	const railTop = live ? (railBelowCopy ? 78 : 36) : railBelowCopy ? 68 : 28;
	const railLeft = live ? 0 : railBelowCopy ? 0 : 360;
	const accent = live ? Palette.mint : Palette.cyan;
	const wash = live ? pulse.map((amount) => 0.88 - amount * 0.22) : 1;
	return (
		<Panel
			layoutOrder={layoutOrder}
			size={new UDim2(1, 0, 0, height)}
			accent={accent}
			background={Palette.panelRaised}
			padding={Space.lg + Space.xs}
			reducedMotion={reducedMotion}
			highlight={live}
			clips={false}
		>
			{live && (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.mint} BackgroundTransparency={wash} BorderSizePixel={0} ZIndex={1}>
					<uicorner CornerRadius={new UDim(0, Radius.lg)} />
				</frame>
			)}
			<IconTile
				kind="Calendar"
				accent={accent}
				size={46}
				radius={Radius.lg}
				position={UDim2.fromOffset(0, 2)}
				glow={live}
				spin={live && !reducedMotion}
				reducedMotion={reducedMotion}
			/>
			<Text
				value={live ? "Astral Forge is live." : "Launch · Aug 31, 2026"}
				size={railBelowCopy ? TypeScale.lead.size + 1 : TypeScale.title.size}
				color={live ? Palette.mint : Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={13}
				position={UDim2.fromOffset(46 + Space.lg, Space.sm)}
				sizeConstraint={new UDim2(1, railBelowCopy ? -(46 + Space.lg) : -420, 0, 30)}
			/>
			<frame
				Size={new UDim2(1, -railLeft, 0, railBelowCopy ? 58 : 68)}
				Position={UDim2.fromOffset(railLeft, railTop)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={false}
				ZIndex={3}
			>
				{live ? (
					<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={true}>
						{!reducedMotion &&
							[0, 1, 2, 3, 4, 5, 6, 7].map((index) => (
								<frame
									key={index}
									Size={flash.map((amount) => UDim2.fromOffset(5 + math.floor(amount * 6), 5 + math.floor(amount * 6)))}
									Position={orbit.map((turn) => {
										const angle = turn * math.pi * 2 + index * (math.pi / 4);
										const radius = 36 + math.sin(turn * math.pi * 2 + index) * 4;
										return new UDim2(0.5, math.floor(math.cos(angle) * radius), 0.5, math.floor(math.sin(angle) * 12));
									})}
									AnchorPoint={new Vector2(0.5, 0.5)}
									BackgroundColor3={index % 2 === 0 ? Palette.mint : Palette.cyan}
									BackgroundTransparency={pulse.map((amount) => 0.08 + (1 - amount) * 0.5)}
									BorderSizePixel={0}
									ZIndex={4}
								>
									<uicorner CornerRadius={new UDim(1, 0)} />
								</frame>
							))}
						<frame
							Size={new UDim2(0.62, 0, 1, -4)}
							Position={new UDim2(0.5, 0, 0.5, 0)}
							AnchorPoint={new Vector2(0.5, 0.5)}
							BackgroundColor3={Palette.ink}
							BackgroundTransparency={0.08}
							BorderSizePixel={0}
							ZIndex={5}
						>
							<uiscale Scale={flash.map((amount) => 1 + amount * 0.28)} />
							<uicorner CornerRadius={new UDim(0, Radius.lg)} />
							<uistroke
								ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
								LineJoinMode={Enum.LineJoinMode.Round}
								Color={Palette.mint}
								Thickness={flash.map((amount) => 1.2 + amount * 2.4)}
								Transparency={pulse.map((amount) => 0.08 + (1 - amount) * 0.32)}
							/>
							<ShimmerText
								value="LIVE"
								size={stack === true ? 26 : 32}
								color={Palette.mint}
								weight={Enum.FontWeight.Heavy}
								align={Enum.TextXAlignment.Center}
								fit={true}
								minSize={16}
								sizeConstraint={UDim2.fromScale(1, 1)}
								enabled={!reducedMotion}
								periodSeconds={1.6}
								reducedMotion={reducedMotion}
							/>
						</frame>
					</frame>
				) : (
					values.map((entry, index) => (
						<frame
							key={entry.label}
							Size={new UDim2(0.25, -Space.sm, 1, 0)}
							Position={new UDim2(index * 0.25, index === 0 ? 0 : Space.sm, 0, 0)}
							BackgroundColor3={Palette.ink}
							BackgroundTransparency={0.04}
							BorderSizePixel={0}
							ClipsDescendants={false}
						>
							<uicorner CornerRadius={new UDim(0, Radius.md)} />
							<uigradient Color={surfaceGradient(Palette.ink, 0.8)} Rotation={90} />
							<uistroke
								ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
								LineJoinMode={Enum.LineJoinMode.Round}
								Color={entry.color}
								Thickness={1}
								Transparency={0.62}
							/>
							<frame Size={new UDim2(0, 3, 0.5, 0)} Position={new UDim2(0, 0, 0.25, 0)} BackgroundColor3={entry.color} BorderSizePixel={0}>
								<uicorner CornerRadius={new UDim(1, 0)} />
							</frame>
							<NumberSpinnerHost
								value={entry.value}
								reducedMotion={reducedMotion}
								duration={0.36}
								size={stack === true ? 20 : 24}
								color={entry.color}
								align={Enum.TextXAlignment.Center}
								position={UDim2.fromOffset(0, 5)}
								sizeConstraint={new UDim2(1, 0, 0, 30)}
							/>
							<Text
								value={entry.label}
								size={TypeScale.micro.size}
								color={Palette.muted}
								weight={Enum.FontWeight.Heavy}
								align={Enum.TextXAlignment.Center}
								fit={false}
								position={new UDim2(0, 0, 1, -22)}
								sizeConstraint={new UDim2(1, 0, 0, 16)}
							/>
						</frame>
					))
				)}
			</frame>
		</Panel>
	);
}

interface MetricProps {
	label: string;
	value: string;
	detail: string;
	accent: Color3;
	size?: UDim2;
	layoutOrder?: number;
	reveal?: unknown;
	compact?: boolean;
}

function Metric({ label, value, detail, accent, size = new UDim2(1, 0, 0, 92), layoutOrder = 0, reveal, compact = false }: MetricProps) {
	// a number on a plate: the figure leads, one quiet caption under it; the accent is a rail, not a heading
	const inset = compact ? Space.md : Space.lg;
	return (
		<Panel
			size={size}
			accent={accent}
			background={Palette.panelRaised}
			padding={compact ? Space.sm : Space.md}
			layoutOrder={layoutOrder}
			reveal={reveal}
		>
			<frame
				Size={new UDim2(0, 3, 1, -Space.md)}
				Position={new UDim2(0, 0, 0.5, 0)}
				AnchorPoint={new Vector2(0, 0.5)}
				BackgroundColor3={accent}
				BackgroundTransparency={0.15}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
			<frame Size={new UDim2(1, -inset, 1, 0)} Position={UDim2.fromOffset(inset, 0)} BackgroundTransparency={1} BorderSizePixel={0}>
				<uilistlayout
					FillDirection={Enum.FillDirection.Vertical}
					HorizontalAlignment={Enum.HorizontalAlignment.Left}
					VerticalAlignment={Enum.VerticalAlignment.Center}
					Padding={new UDim(0, Space.xs)}
					SortOrder={Enum.SortOrder.LayoutOrder}
				/>
				<Text
					value={value}
					size={compact ? TypeScale.title.size : TypeScale.heading.size}
					color={Palette.cream}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					minSize={14}
					layoutOrder={0}
					sizeConstraint={new UDim2(1, 0, 0, compact ? 22 : 28)}
				/>
				<Text
					value={detail === "" ? label : `${label}  ·  ${detail}`}
					size={TypeScale.micro.size}
					color={Palette.muted}
					weight={Enum.FontWeight.SemiBold}
					fit={true}
					minSize={11}
					layoutOrder={1}
					sizeConstraint={new UDim2(1, 0, 0, 14)}
				/>
			</frame>
		</Panel>
	);
}

function listedFluxPerSec(machine: unknown): number {
	const base = typeIs(machine, "table") ? (machine as { BaseProduction?: unknown }).BaseProduction : undefined;
	if (!typeIs(base, "number") || base <= 0) {
		return 0;
	}
	return base;
}

function firstRebirthStardust(config: OverviewConfig | undefined): number {
	const economy = config !== undefined && typeIs(config.Economy, "table") ? config.Economy : undefined;
	const bag = economy !== undefined && typeIs(economy.Rebirth, "table") ? economy.Rebirth : undefined;
	const scale = bag !== undefined && typeIs(bag.StardustSqrtScale, "number") ? bag.StardustSqrtScale : 5;
	const minimum = bag !== undefined && typeIs(bag.StardustMinimum, "number") ? bag.StardustMinimum : 4;
	return math.max(minimum, math.floor(math.sqrt(1) * scale));
}

function levelGoalLine(state: OverviewState): string | undefined {
	const nextStep = state.Level?.Next;
	if (!typeIs(nextStep, "table") || !typeIs(nextStep.Text, "string")) {
		return undefined;
	}
	return `Level ${nextStep.Level}: ${nextStep.Text} · ${compactNumber(nextStep.Progress)}/${compactNumber(nextStep.Target)}`;
}

function nextMachineGateLine(state: OverviewState, config: OverviewConfig | undefined): string | undefined {
	if (config === undefined || !typeIs(config.Machines, "table") || !typeIs(state.Machines, "table")) {
		return undefined;
	}
	const machines = config.Machines;
	const names: Record<string, string> = {};
	for (const machine of machines) {
		if (machine !== undefined && typeIs(machine.Id, "string")) {
			names[machine.Id] = typeIs(machine.Name, "string") ? machine.Name : machine.Id;
		}
	}
	for (const machine of machines) {
		if (machine === undefined || !typeIs(machine.PreviousId, "string")) {
			continue;
		}
		const needLevel = typeIs(machine.PreviousLevel, "number") ? machine.PreviousLevel : 1;
		let haveLevel = state.Machines[machine.PreviousId];
		if (!typeIs(haveLevel, "number")) {
			haveLevel = 0;
		}
		const rebirthsNeed = typeIs(machine.RequiredRebirths, "number") ? machine.RequiredRebirths : 0;
		const zoneNeed = typeIs(machine.RequiredZone, "number") ? machine.RequiredZone : 1;
		const rebirthsHave = math.max(0, math.floor(tonumber(state.Rebirths) ?? 0));
		const zoneHave = math.max(0, math.floor(tonumber(state.Zone) ?? 0));
		const machineName = typeIs(machine.Name, "string") ? machine.Name : machine.Id;
		const rate = listedFluxPerSec(machine);
		const rateBit = rate > 0 ? ` +${compactNumber(rate)}/sec` : "";
		if (rebirthsHave < rebirthsNeed) {
			return `${machineName}${rateBit} · ${rebirthsHave}/${rebirthsNeed} rebirths`;
		} else if (zoneHave < zoneNeed) {
			return `${machineName}${rateBit} · world ${zoneHave}/${zoneNeed}`;
		} else if (haveLevel < needLevel) {
			const prevName = names[machine.PreviousId] ?? machine.PreviousId;
			return `${machineName}${rateBit} · ${prevName} ${haveLevel}/${needLevel}`;
		}
	}
	return undefined;
}

function rebirthPayoutLine(state: OverviewState, config: OverviewConfig | undefined): string | undefined {
	if (gteFlux(state.PrestigeReward, 1)) {
		return undefined;
	}
	const economy = config?.Economy;
	// the server's NextPrestigeTarget already includes the per-rebirth growth; the config base is a fallback
	const scaled = asFlux(state.NextPrestigeTarget);
	const target = scaled > 0 ? scaled : typeIs(economy?.PrestigeRequirement, "number") ? economy.PrestigeRequirement : 0;
	if (target <= 0) {
		return undefined;
	}
	const have = math.max(0, asFlux(state.RunCash)) + math.max(0, asFlux(state.Vault));
	if (have >= target) {
		return undefined;
	}
	const dust = firstRebirthStardust(config);
	return `1 core + ${compactNumber(dust)} stardust · ${compactNumber(have)}/${compactNumber(target)} flux`;
}

function progressLadder(state: OverviewState, config: OverviewConfig | undefined, limit: number): string[] {
	const lines: string[] = [];
	const push = (line: string | undefined) => {
		if (line !== undefined && line !== "" && lines.size() < limit) {
			lines.push(line);
		}
	};
	push(levelGoalLine(state));
	push(nextMachineGateLine(state, config));
	const rebirthGate = state.FeatureUnlocks?.Rebirth;
	if (rebirthGate !== undefined && rebirthGate.Unlocked === true) {
		push(rebirthPayoutLine(state, config));
	}
	return lines;
}

// puts the "Ready now" strip first when it is shown
// With the Ready strip on screen, the "ops" card (claims across Missions, Lab, Forge Path) only
// repeated it lower down, so it is left out.
function withReady(entry: Section | undefined, sections: Section[]): Section[] {
	if (entry !== undefined) {
		for (let index = sections.size() - 1; index >= 0; index--) {
			if (sections[index].id === "ops") {
				sections.remove(index);
			}
		}
		sections.unshift(entry);
	}
	return sections;
}

interface OverviewViewProps {
	state: OverviewState;
	config?: OverviewConfig;
	dispatch: Dispatch;
	reducedMotion?: boolean;
	effectsPaused?: boolean;
	openWorkshop?: () => unknown;
	openDomain?: () => unknown;
	releaseAt?: number;
	navigate?: (page: string) => unknown;
}


const TWO_COLUMN_MIN = 1440;
const COLUMN_PAIRS: [string, string][] = [
	["notes", "ops"],
	["rebirth", "domain"],
	["journal", "session"],
];

// Places paired sections in two columns. A pair only forms when both halves have height; a lone
// half stays full width. Children keep their own height (top aligned) because several panels
// position their contents from that height.
function pairColumns(enabled: boolean, gap: number, sections: Section[]): Section[] {
	if (!enabled) {
		return sections;
	}
	const byId = new Map<string, Section>();
	for (const section of sections) {
		byId.set(section.id, section);
	}
	const used = new Set<string>();
	const out: Section[] = [];
	for (const section of sections) {
		if (used.has(section.id)) {
			continue;
		}
		let partner: Section | undefined;
		let leftFirst = true;
		for (const [a, b] of COLUMN_PAIRS) {
			const other = section.id === a ? b : section.id === b ? a : undefined;
			if (other === undefined) continue;
			const found = byId.get(other);
			if (found !== undefined && !used.has(other) && (found.height ?? 0) > 0 && (section.height ?? 0) > 0) {
				partner = found;
				leftFirst = section.id === a;
			}
		}
		if (partner === undefined) {
			out.push(section);
			continue;
		}
		used.add(section.id);
		used.add(partner.id);
		const left = leftFirst ? section : partner;
		const right = leftFirst ? partner : section;
		const half = new UDim2(0.5, -math.floor(gap / 2), 0, 0);
		out.push({
			id: `${left.id}-${right.id}`,
			height: math.max((left.height ?? 0), (right.height ?? 0)),
			element: (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
					<frame
						{...named(`OverviewColumn-${left.id}`)}
						Size={new UDim2(half.X.Scale, half.X.Offset, 0, (left.height ?? 0))}
						BackgroundTransparency={1}
						BorderSizePixel={0}
						ClipsDescendants={false}
					>
						{left.element}
					</frame>
					<frame
						{...named(`OverviewColumn-${right.id}`)}
						Size={new UDim2(half.X.Scale, half.X.Offset, 0, (right.height ?? 0))}
						Position={new UDim2(0.5, math.ceil(gap / 2), 0, 0)}
						BackgroundTransparency={1}
						BorderSizePixel={0}
						ClipsDescendants={false}
					>
						{right.element}
					</frame>
				</frame>
			),
		});
	}
	return out;
}

export function OverviewView({
	state,
	config,
	dispatch,
	reducedMotion,
	effectsPaused,
	openWorkshop,
	openDomain,
	releaseAt,
	navigate,
}: OverviewViewProps) {
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const antilag = useAntilag();
	const softMotion = reducedMotion;
	const quietMotion = softMotion === true || effectsPaused === true || antilag.skipEntrance;
	const stack = chrome.contentStack;
	const phone = chrome.stack;
	const canCollect = VaultCollectEligibility.isEligible(asFlux(state.Vault));
	const canRebirth = gteFlux(state.PrestigeReward, 1);
	const target = asFlux(state.NextPrestigeTarget);
	const progress = canRebirth ? 1 : meterFill(asFlux(state.RunCash), math.max(1, target));
	const vaultFill = meterFill(asFlux(state.Vault), asFlux(state.Capacity));
	const stellarLevel = state.Machines.StellarCore ?? 0;
	let tutorialDone = false;
	const flags = state.Flags;
	if (flags !== undefined && flags.TutorialDone === true) {
		tutorialDone = true;
	}
	const firstRun = !tutorialDone || stellarLevel < 1;
	const showOvercharge = tutorialDone && stellarLevel >= 1;
	let offlineHours = typeIs(state.OfflineHours, "number") ? state.OfflineHours : 0;
	offlineHours = math.floor(offlineHours + 0.5);
	const rebirthVisible = AppHelpers.featureUnlocked(state, "Rebirth");
	const domainVisible = AppHelpers.featureUnlocked(state, "Domain");
	const heroReveal = useStagger(0, quietMotion);
	const metricsReveal = useStagger(1, quietMotion);
	const rebirthReveal = useStagger(2, quietMotion);
	const domainReveal = useStagger(3, quietMotion);
	const notesReveal = useStagger(4, quietMotion);
	const opsReveal = useStagger(5, quietMotion);
	const [collectTrigger, setCollectTrigger] = React.useState(0);
	const collectFlash = useFlash(collectTrigger, reducedMotion, 0.42);
	const fireCollect = () => {
		if (!canCollect) {
			return undefined;
		}
		setCollectTrigger((value) => value + 1);
		return dispatch("CollectVault");
	};
	const missionsReady = PageReadyMath.CountReadyQuests(state.Quests);
	const labReady = PageReadyMath.CountReadyLabOrders(state.Lab);
	const pathReady = PageReadyMath.ForgePathReady(state, config);
	const opsClaims = PageReadyMath.OpsClaims(missionsReady, labReady, pathReady, false);
	// story chapters that are open but not read or collected yet
	let storyWaiting = 0;
	if (typeIs(state.Story, "table")) {
		for (const [, chapter] of pairs(state.Story as object)) {
			if (typeIs(chapter, "table")) {
				const c = chapter as { Unlocked?: unknown; Claimed?: unknown };
				if (c.Unlocked === true && c.Claimed !== true) storyWaiting += 1;
			}
		}
	}
	const opsParts: string[] = [];
	if (missionsReady > 0) opsParts.push(missionsReady === 1 ? "1 mission" : `${missionsReady} missions`);
	if (labReady > 0) opsParts.push(labReady === 1 ? "1 lab order" : `${labReady} lab orders`);
	if (pathReady === true) opsParts.push("a Forge Path step");
	if (storyWaiting > 0) opsParts.push(storyWaiting === 1 ? "a new story chapter" : `${storyWaiting} story chapters`);
	const opsDetail =
		opsParts.size() === 0
			? undefined
			: opsParts.size() === 1
				? `Waiting for you: ${opsParts[0]}.`
				: `Waiting for you: ${opsParts.filter((_, i) => i < opsParts.size() - 1).join(", ")} and ${opsParts[opsParts.size() - 1]}.`;
	const opsGuide = config !== undefined && config.ClientPageGuides !== undefined ? config.ClientPageGuides.Overview : undefined;
	const [overchargeTrigger, setOverchargeTrigger] = React.useState(0);
	const [overchargeReadyAt, setOverchargeReadyAt] = React.useState(0);
	const [overchargeLeft, setOverchargeLeft] = React.useState(0);
	const overchargeFlash = useFlash(overchargeTrigger, reducedMotion, 0.3);
	React.useEffect(() => {
		if (overchargeReadyAt <= 0) {
			setOverchargeLeft(0);
			return undefined;
		}
		let alive = true;
		const worker = task.spawn(() => {
			while (alive) {
				const left = math.max(0, overchargeReadyAt - os.clock());
				if (!alive) {
					break;
				}
				setOverchargeLeft(math.ceil(left * 10) / 10);
				if (left <= 0) {
					break;
				}
				task.wait(math.max(0.016, left - (math.ceil(left * 10) - 1) / 10));
			}
		});
		return () => {
			alive = false;
			pcall(() => task.cancel(worker));
		};
	}, [overchargeReadyAt]);
	const fireOvercharge = () => {
		if (os.clock() < overchargeReadyAt) {
			return undefined;
		}
		Audio.play("reactorPulse");
		setOverchargeTrigger((value) => value + 1);
		setOverchargeReadyAt(os.clock() + 0.45);
		setOverchargeLeft(0.45);
		dispatch("Overcharge");
	};
	const overchargeLabel =
		overchargeLeft > 0.02
			? `Cooling ${string.format("%.1f", overchargeLeft)}s`
			: state.TapPower !== undefined
				? `Overcharge  +${compactNumber(state.TapPower)}`
				: "Overcharge";
	const vaultClaimHostRef = React.useRef<Frame>();
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = vaultClaimHostRef.current;
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
	}, [canCollect, overchargeLeft]);
	const landscapePhone = phone && chrome.landscape;
	const primaryIsBuy = !canCollect && stellarLevel < 1;
	const primaryText = primaryIsBuy
		? landscapePhone
			? "Buy machine"
			: "Buy a machine"
		: landscapePhone
			? "Collect"
			: "Collect stored Flux";
	const primaryClick = primaryIsBuy ? openWorkshop : fireCollect;
	const primaryDisabled = primaryIsBuy ? false : !canCollect;
	const primaryIcon = primaryIsBuy ? "Forge" : "Collect";
	const primaryColor = primaryIsBuy ? Palette.coral : Palette.green;
	const primaryHighlight = primaryIsBuy ? true : canCollect ? firstRun || vaultFill >= 0.85 : false;
	const comebackLine = `Earns for ${offlineHours}h while you're away. Then collect.`;
	const wideOverview = !stack && viewport.width >= 1180;
	const ultraOverview = !stack && viewport.width >= 1680;
	// wide desktop: notes|ops, rebirth|domain, journal|session sit side by side (each keeps its own height)
	const twoColumn = !stack && viewport.width >= TWO_COLUMN_MIN;
	const countdownInPage =
		typeIs(releaseAt, "number") &&
		releaseAt >
			(() => {
				const [ok, value] = pcall(() => Workspace.GetServerTimeNow());
				if (ok && typeIs(value, "number")) {
					return value;
				}
				return os.time();
			})();
	let fitHeight: number | undefined;
	if (chrome.short === true && !stack) {
		const shellTop = 6 + chrome.topbarRows + chrome.panelGap;
		const workspaceChrome = chrome.workspaceHeaderH + 32 + chrome.contentInset;
		const bottom = chrome.bottomSafe + chrome.pagePadding + 12;
		fitHeight = math.max(280, math.floor(viewport.height - shellTop - workspaceChrome - bottom));
	}
	const overviewPlan = LayoutSectionPlan.planOverview({
		stack,
		phone,
		landscapePhone,
		wideOverview,
		ultraOverview,
		rebirthVisible,
		domainVisible,
		countdownInPage,
		short: chrome.short === true,
		chromePanelGap: chrome.panelGap,
		layoutPanelGap: Layout.panelGap,
		fitHeight,
		roomyHero: !phone && !denseHeroFor(chrome.short === true, wideOverview, phone),
	});
	const heroBandH = overviewPlan.heroBandH ?? 0;
	const roomyHero = heroBandH > 0;
	const heroH = overviewPlan.heroH;
	const rebirthH = overviewPlan.rebirthH;
	const domainH = overviewPlan.domainH;
	const notesH = overviewPlan.notesH;
	const opsH = overviewPlan.opsH + (stack && storyWaiting > 0 ? TapTarget + 8 : 0);
	const metricCardH = overviewPlan.metricCardH;
	const metricsH = overviewPlan.metricsH;
	const countdownH = overviewPlan.countdownH;
	const sectionGap = overviewPlan.sectionGap;
	const topBandH = overviewPlan.topBandH;
	const overviewTail = overviewPlan.overviewTail;
	const columnMax = stack ? math.huge : Layout.contentMaxWidth;
	const columnPad = !stack && viewport.width >= Layout.contentMaxWidth + 80 ? 12 : 0;
	const denseHero = denseHeroFor(chrome.short === true, wideOverview, phone);
	const readoutRow = denseHero ? heroH - metricCardH - 8 : heroH;
	const ctaH = denseHero ? 40 : TapTarget;
	const heroReadoutH = landscapePhone ? 118 : phone ? 168 : 0;
	const phoneCtaBlockH = landscapePhone ? ctaH + 8 : ctaH * 2 + 12;
	// a waiting chapter adds a fifth button: its own row on phones, a fifth column on desktop
	const opsButtonRows = stack ? (storyWaiting > 0 ? 3 : 2) : 1;
	const opsButtonH = TapTarget * opsButtonRows + (stack ? 8 * (opsButtonRows - 1) : 0);
	const opsButtonSize = stack
		? new UDim2(0.5, -4, 0, TapTarget)
		: storyWaiting > 0
			? new UDim2(0.2, -7, 0, TapTarget)
			: new UDim2(0.25, -6, 0, TapTarget);
	const journey = JourneyMath.Build(state);
	const journeyNext = journey.Next;
	const journeyRecent: string[] = [];
	for (let index = journey.Done.size() - 1; index >= math.max(0, journey.Done.size() - 3); index--) {
		journeyRecent.push(journey.Done[index].Title);
	}
	// label 16 + title 26 + progress 16 + meter 6 (ends at y=76), plus the panel padding on both sides
	const journalH = 76 + (stack ? chrome.cardPadding * 2 : 32);
	const domain =
		state.Domain ??
		({
			Rank: 0,
			Essence: 0,
			LastExpandedAt: 0,
			TotalRebirthsSpent: 0,
			TotalCoresSpent: 0,
			RequiredRebirths: 10,
			RequiredCores: 25,
			CanExpand: false,
			EssenceReward: 3,
			StardustReward: 250,
			ProductionMultiplier: 1,
			CapacityMultiplier: 1,
			OfflineBonus: 0,
			SkillPoints: 0,
			Nodes: [],
		} as DomainState);
	const readyList = ReadyBoard.collect(state, config);
	const readySection: Section | undefined =
		tutorialDone && navigate !== undefined
			? {
					id: "ready",
					height: phone ? 52 : 58,
					element: (
						<ReadyBoard.Strip
							list={readyList}
							compact={phone}
							pillHeight={phone ? 48 : 44}
							onOpen={navigate}
							onFind={() => QuickFind.open()}
						/>
					),
				}
			: undefined;
	// pad order: ready strip, hero (vault actions take the first selection), then the sections top to
	// bottom; paired sections are named OverviewColumn-<id> and linked left/right
	const overviewFocusRef = React.useRef<Frame>();
	const overviewRegions = ["ready", "top"];
	const overviewColumns: Array<[string, string]> = [];
	for (const [a, b] of COLUMN_PAIRS) {
		overviewRegions.push(a, `OverviewColumn-${a}`, b, `OverviewColumn-${b}`);
		overviewColumns.push([`OverviewColumn-${a}`, `OverviewColumn-${b}`]);
		if (a === "notes") {
			overviewRegions.push("countdown");
		}
	}
	useFocusOrder(
		overviewFocusRef,
		{ regions: overviewRegions, first: ["OverviewVaultClaimActions", "top"], columns: twoColumn ? overviewColumns : undefined },
		[twoColumn, rebirthVisible, domainVisible, countdownInPage, roomyHero],
	);
	const domainProgress = math.min(
		math.clamp(asFlux(state.Rebirths ?? 0) / math.max(1, asFlux(domain.RequiredRebirths)), 0, 1),
		math.clamp(asFlux(state.Cores ?? 0) / math.max(1, asFlux(domain.RequiredCores)), 0, 1),
	);
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false} ref={overviewFocusRef}>
			<frame
				Size={new UDim2(1, -columnPad * 2, 1, 0)}
				Position={UDim2.fromScale(0.5, 0)}
				AnchorPoint={new Vector2(0.5, 0)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={false}
			>
				<uisizeconstraint MaxSize={new Vector2(columnMax, math.huge)} />
				<PageScaffold
					gap={sectionGap}
					tailPad={scrollTail(stack, chrome.bottomSafe, overviewTail)}
					scrollBarColor={Palette.green}
					scrollBarThickness={4}
					sections={pairColumns(twoColumn, sectionGap, withReady(readySection, [
						{
							id: "top",
							height: topBandH,
							element: (
								<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={0} ClipsDescendants={false}>
									<uilistlayout
										FillDirection={
											denseHero ? Enum.FillDirection.Vertical : wideOverview ? Enum.FillDirection.Horizontal : Enum.FillDirection.Vertical
										}
										SortOrder={Enum.SortOrder.LayoutOrder}
										Padding={new UDim(0, denseHero ? 8 : wideOverview ? (ultraOverview ? 16 : 12) : sectionGap)}
										VerticalAlignment={Enum.VerticalAlignment.Top}
									/>
									<Panel
										layoutOrder={0}
										size={denseHero ? new UDim2(1, 0, 0, readoutRow) : wideOverview ? new UDim2(0.62, -6, 1, 0) : new UDim2(1, 0, 0, heroH)}
										accent={vaultFill >= 0.99 ? Palette.mango : Palette.green}
										background={Palette.panelRaised}
										padding={stack ? chrome.cardPadding : denseHero ? 10 : ultraOverview ? 30 : 26}
										reveal={heroReveal}
										highlight={vaultFill >= 0.99 && !effectsPaused}
										reducedMotion={softMotion}
										clips={false}
									>
										<uigradient Color={surfaceGradient(vaultFill >= 0.99 ? Palette.mango : Palette.green, 0.94)} Rotation={62} />
										{!phone && !roomyHero && (
											<uilistlayout
												FillDirection={Enum.FillDirection.Horizontal}
												Padding={new UDim(0, denseHero ? 16 : HERO_COLUMN_GAP)}
												SortOrder={Enum.SortOrder.LayoutOrder}
												VerticalAlignment={Enum.VerticalAlignment.Center}
												HorizontalFlex={Enum.UIFlexAlignment.Fill}
											/>
										)}
										{roomyHero ? (
											<>
												<frame
													{...named("OverviewHeroUpper")}
													Size={new UDim2(1, 0, 1, -(heroBandH + HERO_BAND_GAP))}
													BackgroundTransparency={1}
													BorderSizePixel={0}
													ClipsDescendants={false}
												>
													<uilistlayout
														FillDirection={Enum.FillDirection.Horizontal}
														Padding={new UDim(0, HERO_COLUMN_GAP)}
														SortOrder={Enum.SortOrder.LayoutOrder}
														VerticalAlignment={Enum.VerticalAlignment.Top}
														HorizontalFlex={Enum.UIFlexAlignment.Fill}
													/>
													<frame
														Size={phone ? new UDim2(1, 0, 0, heroReadoutH) : new UDim2(0, 0, 1, 0)}
														BackgroundTransparency={1}
														BorderSizePixel={0}
														ClipsDescendants={false}
														LayoutOrder={0}
														ZIndex={2}
													>
														<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
														<uilistlayout
															FillDirection={Enum.FillDirection.Vertical}
															Padding={new UDim(0, landscapePhone || denseHero ? 4 : phone ? 8 : 10)}
															SortOrder={Enum.SortOrder.LayoutOrder}
															VerticalAlignment={roomyHero ? Enum.VerticalAlignment.Top : Enum.VerticalAlignment.Center}
														/>
														<frame
															Size={new UDim2(1, 0, 0, 18)}
															BackgroundTransparency={1}
															BorderSizePixel={0}
															LayoutOrder={0}
															ClipsDescendants={false}
														>
															<uilistlayout
																FillDirection={Enum.FillDirection.Horizontal}
																Padding={new UDim(0, 8)}
																SortOrder={Enum.SortOrder.LayoutOrder}
																VerticalAlignment={Enum.VerticalAlignment.Center}
															/>
															<Text
																value={firstRun ? "Your forge" : "This run"}
																size={11}
																color={vaultFill >= 0.99 ? Palette.mango : Palette.green}
																weight={Enum.FontWeight.Heavy}
																fit={false}
																layoutOrder={0}
																sizeConstraint={new UDim2(0, phone ? 96 : 110, 1, 0)}
															/>
															{vaultFill >= 0.99 && (
																<Badge
																	value="FULL"
																	accent={Palette.mango}
																	size={UDim2.fromOffset(phone ? 56 : 62, 18)}
																	filled={false}
																	layoutOrder={1}
																/>
															)}
														</frame>
														<Text
															value={compactNumber(state.Vault)}
															size={landscapePhone ? 32 : stack ? 38 : 46}
															color={Palette.cream}
															weight={Enum.FontWeight.Heavy}
															fit={true}
															minSize={22}
															layoutOrder={1}
															sizeConstraint={new UDim2(1, 0, 0, landscapePhone || denseHero ? 36 : 54)}
														/>
														<Text
															value={`Flux stored · vault holds ${compactNumber(state.Capacity)}`}
															size={stack ? chrome.labelText : 12}
															color={Palette.creamSoft}
															wrap={true}
															fit={true}
															minSize={11}
															layoutOrder={2}
															sizeConstraint={new UDim2(1, 0, 0, 18)}
														/>
														{!roomyHero && (
															<>
																<Meter
																	value={vaultFill}
																	rainbow={true}
																	color={vaultFill >= 0.99 ? Palette.mango : Palette.green}
																	reducedMotion={softMotion}
																	shimmer={vaultFill >= 0.99 && !effectsPaused}
																	layoutOrder={3}
																	size={new UDim2(1, 0, 0, 10)}
																/>
																<Text
																	value={
																		vaultFill >= 0.99
																			? "Vault full. Machines stop until you collect."
																			: firstRun
																				? "Machines earn Flux into this vault. Collect it, then buy more."
																				: `${compactNumber(state.Production)} Flux per second flowing in`
																	}
																	size={stack ? chrome.labelText : 11}
																	color={vaultFill >= 0.99 ? Palette.mango : Palette.muted}
																	weight={Enum.FontWeight.Bold}
																	wrap={true}
																	fit={true}
																	minSize={11}
																	layoutOrder={4}
																	sizeConstraint={new UDim2(1, 0, 0, landscapePhone ? 22 : denseHero ? 16 : 28)}
																/>
															</>
														)}
													</frame>
													{phone ? (
														<frame
															{...named("OverviewVaultClaimActions")}
															ref={vaultClaimHostRef}
															Size={new UDim2(1, 0, 0, phoneCtaBlockH)}
															Position={new UDim2(0, 0, 1, -(phoneCtaBlockH + 4))}
															BackgroundTransparency={1}
															BorderSizePixel={0}
															ZIndex={3}
															ClipsDescendants={false}
														>
															<uilistlayout
																FillDirection={landscapePhone && showOvercharge ? Enum.FillDirection.Horizontal : Enum.FillDirection.Vertical}
																Padding={new UDim(0, 8)}
																SortOrder={Enum.SortOrder.LayoutOrder}
																VerticalAlignment={Enum.VerticalAlignment.Center}
															/>
															<Button
																text={primaryText}
																icon={primaryIcon}
																onClick={primaryClick}
																color={primaryColor}
																textColor={Palette.ink}
																size={landscapePhone && showOvercharge ? new UDim2(0.5, -4, 0, ctaH) : new UDim2(1, 0, 0, ctaH)}
																reducedMotion={reducedMotion}
																disabled={primaryDisabled}
																highlight={primaryHighlight}
															/>
															{showOvercharge && (
																<Button
																	text={overchargeLabel}
																	icon="Overcharge.3"
																	onClick={fireOvercharge}
																	sound="reactorPulse"
																	color={overchargeLeft > 0.02 ? Palette.panelSoft : Palette.mango}
																	textColor={overchargeLeft > 0.02 ? Palette.muted : Palette.ink}
																	size={landscapePhone ? new UDim2(0.5, -4, 0, ctaH) : new UDim2(1, 0, 0, ctaH)}
																	reducedMotion={reducedMotion}
																	disabled={overchargeLeft > 0.02}
																/>
															)}
															{!showOvercharge && !landscapePhone && (
																<Text
																	value={comebackLine}
																	size={stack ? chrome.labelText : 12}
																	color={Palette.creamSoft}
																	weight={Enum.FontWeight.Bold}
																	wrap={true}
																	fit={true}
																	minSize={11}
																	sizeConstraint={new UDim2(1, 0, 0, ctaH)}
																/>
															)}
															{showOvercharge && !landscapePhone && (
																<Meter
																	value={overchargeLeft > 0 ? 1 - overchargeLeft / 0.45 : 1}
																	color={Palette.mango}
																	reducedMotion={softMotion}
																	position={new UDim2(0, 0, 1, -4)}
																	size={new UDim2(1, 0, 0, 4)}
																/>
															)}
															<frame
																Size={React.joinBindings([collectFlash, overchargeFlash]).map((values) => {
																	const amount = math.max(values[0], values[1]);
																	return new UDim2(amount, 0, 0, 2);
																})}
																Position={new UDim2(0.5, 0, 1, -2)}
																AnchorPoint={new Vector2(0.5, 0)}
																BackgroundColor3={Palette.cream}
																BackgroundTransparency={React.joinBindings([collectFlash, overchargeFlash]).map(
																	(values) => 1 - math.max(values[0], values[1]),
																)}
																BorderSizePixel={0}
																ZIndex={8}
															>
																<uicorner CornerRadius={new UDim(1, 0)} />
															</frame>
														</frame>
													) : (
														<frame
															{...named("OverviewVaultClaimActions")}
															ref={vaultClaimHostRef}
															Size={denseHero ? new UDim2(0, 250, 1, 0) : roomyHero ? new UDim2(0, 230, 1, 0) : UDim2.fromOffset(230, 168)}
															LayoutOrder={1}
															BackgroundTransparency={1}
															BorderSizePixel={0}
															ZIndex={3}
															ClipsDescendants={false}
														>
															<uilistlayout
																FillDirection={Enum.FillDirection.Vertical}
																Padding={new UDim(0, denseHero ? 4 : Layout.controlGap)}
																SortOrder={Enum.SortOrder.LayoutOrder}
															/>
															<Button
																text={primaryText}
																icon={primaryIcon}
																onClick={primaryClick}
																color={primaryColor}
																textColor={Palette.ink}
																size={new UDim2(1, 0, 0, ctaH)}
																reducedMotion={reducedMotion}
																disabled={primaryDisabled}
																highlight={primaryHighlight}
															/>
															{showOvercharge && (
																<Button
																	text={overchargeLabel}
																	icon="Overcharge.4"
																	onClick={fireOvercharge}
																	sound="reactorPulse"
																	color={overchargeLeft > 0.02 ? Palette.panelSoft : Palette.mango}
																	textColor={overchargeLeft > 0.02 ? Palette.muted : Palette.ink}
																	size={new UDim2(1, 0, 0, ctaH)}
																	reducedMotion={reducedMotion}
																	disabled={overchargeLeft > 0.02}
																/>
															)}
															{showOvercharge && (
																<Meter
																	value={overchargeLeft > 0 ? 1 - overchargeLeft / 0.45 : 1}
																	color={Palette.mango}
																	reducedMotion={softMotion}
																	size={new UDim2(1, 0, 0, 4)}
																/>
															)}
															<Text
																value={
																	!showOvercharge
																		? comebackLine
																		: overchargeLeft > 0.02
																			? `Ready in ${string.format("%.1f", overchargeLeft)}s`
																			: "Tap for an instant burst of Flux"
																}
																size={11}
																color={overchargeLeft > 0.02 ? Palette.mango : Palette.muted}
																weight={Enum.FontWeight.Bold}
																fit={false}
																wrap={!showOvercharge}
																sizeConstraint={new UDim2(1, 0, 0, showOvercharge ? 16 : 32)}
																align={Enum.TextXAlignment.Center}
															/>
															<frame
																Size={collectFlash.map((amount) => new UDim2(amount, 0, 0, 2))}
																Position={new UDim2(0.5, 0, 1, 0)}
																AnchorPoint={new Vector2(0.5, 1)}
																BackgroundColor3={Palette.cream}
																BackgroundTransparency={collectFlash.map((amount) => 1 - amount)}
																BorderSizePixel={0}
																ZIndex={8}
															>
																<uicorner CornerRadius={new UDim(1, 0)} />
															</frame>
														</frame>
													)}
												</frame>
												<frame
													{...named("OverviewHeroBand")}
													Size={new UDim2(1, 0, 0, heroBandH)}
													Position={new UDim2(0, 0, 1, -heroBandH)}
													BackgroundTransparency={1}
													BorderSizePixel={0}
													ClipsDescendants={false}
													ZIndex={2}
												>
													<frame Size={new UDim2(1, 0, 0, 1)} BackgroundColor3={Palette.lineSoft} BackgroundTransparency={0.55} BorderSizePixel={0} LayoutOrder={-1} />
													<uipadding PaddingTop={new UDim(0, 0)} />
													<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, 12)} SortOrder={Enum.SortOrder.LayoutOrder} />
												<Meter
													value={vaultFill}
													rainbow={true}
													color={vaultFill >= 0.99 ? Palette.mango : Palette.green}
													reducedMotion={softMotion}
													shimmer={vaultFill >= 0.99 && !effectsPaused}
													layoutOrder={3}
													size={new UDim2(1, 0, 0, 10)}
												/>
												<Text
													value={
														vaultFill >= 0.99
															? "Vault full. Machines stop until you collect."
															: firstRun
																? "Machines earn Flux into this vault. Collect it, then buy more."
																: `${compactNumber(state.Production)} Flux per second flowing in`
													}
													size={stack ? chrome.labelText : 11}
													color={vaultFill >= 0.99 ? Palette.mango : Palette.muted}
													weight={Enum.FontWeight.Bold}
													wrap={true}
													fit={true}
													minSize={11}
													layoutOrder={4}
													sizeConstraint={new UDim2(1, 0, 0, heroBandH - 35)}
												/>
												</frame>
											</>
										) : (
											<>
												<frame
													Size={phone ? new UDim2(1, 0, 0, heroReadoutH) : new UDim2(0, 0, 1, 0)}
													BackgroundTransparency={1}
													BorderSizePixel={0}
													ClipsDescendants={false}
													LayoutOrder={0}
													ZIndex={2}
												>
													<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
													<uilistlayout
														FillDirection={Enum.FillDirection.Vertical}
														Padding={new UDim(0, landscapePhone || denseHero ? 4 : phone ? 8 : 10)}
														SortOrder={Enum.SortOrder.LayoutOrder}
														VerticalAlignment={roomyHero ? Enum.VerticalAlignment.Top : Enum.VerticalAlignment.Center}
													/>
													<frame
														Size={new UDim2(1, 0, 0, 18)}
														BackgroundTransparency={1}
														BorderSizePixel={0}
														LayoutOrder={0}
														ClipsDescendants={false}
													>
														<uilistlayout
															FillDirection={Enum.FillDirection.Horizontal}
															Padding={new UDim(0, 8)}
															SortOrder={Enum.SortOrder.LayoutOrder}
															VerticalAlignment={Enum.VerticalAlignment.Center}
														/>
														<Text
															value={firstRun ? "Your forge" : "This run"}
															size={11}
															color={vaultFill >= 0.99 ? Palette.mango : Palette.green}
															weight={Enum.FontWeight.Heavy}
															fit={false}
															layoutOrder={0}
															sizeConstraint={new UDim2(0, phone ? 96 : 110, 1, 0)}
														/>
														{vaultFill >= 0.99 && (
															<Badge
																value="FULL"
																accent={Palette.mango}
																size={UDim2.fromOffset(phone ? 56 : 62, 18)}
																filled={false}
																layoutOrder={1}
															/>
														)}
													</frame>
													<Text
														value={compactNumber(state.Vault)}
														size={landscapePhone ? 32 : stack ? 38 : 46}
														color={Palette.cream}
														weight={Enum.FontWeight.Heavy}
														fit={true}
														minSize={22}
														layoutOrder={1}
														sizeConstraint={new UDim2(1, 0, 0, landscapePhone || denseHero ? 36 : 54)}
													/>
													<Text
														value={`Flux stored · vault holds ${compactNumber(state.Capacity)}`}
														size={stack ? chrome.labelText : 12}
														color={Palette.creamSoft}
														wrap={true}
														fit={true}
														minSize={11}
														layoutOrder={2}
														sizeConstraint={new UDim2(1, 0, 0, 18)}
													/>
													{!roomyHero && (
														<>
															<Meter
																value={vaultFill}
																rainbow={true}
																color={vaultFill >= 0.99 ? Palette.mango : Palette.green}
																reducedMotion={softMotion}
																shimmer={vaultFill >= 0.99 && !effectsPaused}
																layoutOrder={3}
																size={new UDim2(1, 0, 0, 10)}
															/>
															<Text
																value={
																	vaultFill >= 0.99
																		? "Vault full. Machines stop until you collect."
																		: firstRun
																			? "Machines earn Flux into this vault. Collect it, then buy more."
																			: `${compactNumber(state.Production)} Flux per second flowing in`
																}
																size={stack ? chrome.labelText : 11}
																color={vaultFill >= 0.99 ? Palette.mango : Palette.muted}
																weight={Enum.FontWeight.Bold}
																wrap={true}
																fit={true}
																minSize={11}
																layoutOrder={4}
																sizeConstraint={new UDim2(1, 0, 0, landscapePhone ? 22 : denseHero ? 16 : 28)}
															/>
														</>
													)}
												</frame>
												{phone ? (
													<frame
														{...named("OverviewVaultClaimActions")}
														ref={vaultClaimHostRef}
														Size={new UDim2(1, 0, 0, phoneCtaBlockH)}
														Position={new UDim2(0, 0, 1, -(phoneCtaBlockH + 4))}
														BackgroundTransparency={1}
														BorderSizePixel={0}
														ZIndex={3}
														ClipsDescendants={false}
													>
														<uilistlayout
															FillDirection={landscapePhone && showOvercharge ? Enum.FillDirection.Horizontal : Enum.FillDirection.Vertical}
															Padding={new UDim(0, 8)}
															SortOrder={Enum.SortOrder.LayoutOrder}
															VerticalAlignment={Enum.VerticalAlignment.Center}
														/>
														<Button
															text={primaryText}
															icon={primaryIcon}
															onClick={primaryClick}
															color={primaryColor}
															textColor={Palette.ink}
															size={landscapePhone && showOvercharge ? new UDim2(0.5, -4, 0, ctaH) : new UDim2(1, 0, 0, ctaH)}
															reducedMotion={reducedMotion}
															disabled={primaryDisabled}
															highlight={primaryHighlight}
														/>
														{showOvercharge && (
															<Button
																text={overchargeLabel}
																icon="Overcharge.3"
																onClick={fireOvercharge}
																sound="reactorPulse"
																color={overchargeLeft > 0.02 ? Palette.panelSoft : Palette.mango}
																textColor={overchargeLeft > 0.02 ? Palette.muted : Palette.ink}
																size={landscapePhone ? new UDim2(0.5, -4, 0, ctaH) : new UDim2(1, 0, 0, ctaH)}
																reducedMotion={reducedMotion}
																disabled={overchargeLeft > 0.02}
															/>
														)}
														{!showOvercharge && !landscapePhone && (
															<Text
																value={comebackLine}
																size={stack ? chrome.labelText : 12}
																color={Palette.creamSoft}
																weight={Enum.FontWeight.Bold}
																wrap={true}
																fit={true}
																minSize={11}
																sizeConstraint={new UDim2(1, 0, 0, ctaH)}
															/>
														)}
														{showOvercharge && !landscapePhone && (
															<Meter
																value={overchargeLeft > 0 ? 1 - overchargeLeft / 0.45 : 1}
																color={Palette.mango}
																reducedMotion={softMotion}
																position={new UDim2(0, 0, 1, -4)}
																size={new UDim2(1, 0, 0, 4)}
															/>
														)}
														<frame
															Size={React.joinBindings([collectFlash, overchargeFlash]).map((values) => {
																const amount = math.max(values[0], values[1]);
																return new UDim2(amount, 0, 0, 2);
															})}
															Position={new UDim2(0.5, 0, 1, -2)}
															AnchorPoint={new Vector2(0.5, 0)}
															BackgroundColor3={Palette.cream}
															BackgroundTransparency={React.joinBindings([collectFlash, overchargeFlash]).map(
																(values) => 1 - math.max(values[0], values[1]),
															)}
															BorderSizePixel={0}
															ZIndex={8}
														>
															<uicorner CornerRadius={new UDim(1, 0)} />
														</frame>
													</frame>
												) : (
													<frame
														{...named("OverviewVaultClaimActions")}
														ref={vaultClaimHostRef}
														Size={denseHero ? new UDim2(0, 250, 1, 0) : roomyHero ? new UDim2(0, 230, 1, 0) : UDim2.fromOffset(230, 168)}
														LayoutOrder={1}
														BackgroundTransparency={1}
														BorderSizePixel={0}
														ZIndex={3}
														ClipsDescendants={false}
													>
														<uilistlayout
															FillDirection={Enum.FillDirection.Vertical}
															Padding={new UDim(0, denseHero ? 4 : Layout.controlGap)}
															SortOrder={Enum.SortOrder.LayoutOrder}
														/>
														<Button
															text={primaryText}
															icon={primaryIcon}
															onClick={primaryClick}
															color={primaryColor}
															textColor={Palette.ink}
															size={new UDim2(1, 0, 0, ctaH)}
															reducedMotion={reducedMotion}
															disabled={primaryDisabled}
															highlight={primaryHighlight}
														/>
														{showOvercharge && (
															<Button
																text={overchargeLabel}
																icon="Overcharge.4"
																onClick={fireOvercharge}
																sound="reactorPulse"
																color={overchargeLeft > 0.02 ? Palette.panelSoft : Palette.mango}
																textColor={overchargeLeft > 0.02 ? Palette.muted : Palette.ink}
																size={new UDim2(1, 0, 0, ctaH)}
																reducedMotion={reducedMotion}
																disabled={overchargeLeft > 0.02}
															/>
														)}
														{showOvercharge && (
															<Meter
																value={overchargeLeft > 0 ? 1 - overchargeLeft / 0.45 : 1}
																color={Palette.mango}
																reducedMotion={softMotion}
																size={new UDim2(1, 0, 0, 4)}
															/>
														)}
														<Text
															value={
																!showOvercharge
																	? comebackLine
																	: overchargeLeft > 0.02
																		? `Ready in ${string.format("%.1f", overchargeLeft)}s`
																		: "Tap for an instant burst of Flux"
															}
															size={11}
															color={overchargeLeft > 0.02 ? Palette.mango : Palette.muted}
															weight={Enum.FontWeight.Bold}
															fit={false}
															wrap={!showOvercharge}
															sizeConstraint={new UDim2(1, 0, 0, showOvercharge ? 16 : 32)}
															align={Enum.TextXAlignment.Center}
														/>
														<frame
															Size={collectFlash.map((amount) => new UDim2(amount, 0, 0, 2))}
															Position={new UDim2(0.5, 0, 1, 0)}
															AnchorPoint={new Vector2(0.5, 1)}
															BackgroundColor3={Palette.cream}
															BackgroundTransparency={collectFlash.map((amount) => 1 - amount)}
															BorderSizePixel={0}
															ZIndex={8}
														>
															<uicorner CornerRadius={new UDim(1, 0)} />
														</frame>
													</frame>
												)}
											</>
										)}
									</Panel>
									<Flex
										direction={denseHero ? "row" : wideOverview || stack ? "column" : "row"}
										wrap={false}
										justify="fill"
										align="stretch"
										gap={stack ? 10 : denseHero ? 8 : ultraOverview ? 12 : wideOverview ? 8 : 12}
										size={
											denseHero ? new UDim2(1, 0, 0, metricCardH) : wideOverview ? new UDim2(0.38, -6, 1, 0) : new UDim2(1, 0, 0, metricsH)
										}
										layoutOrder={1}
										exact={true}
									>
										<FlexItem
											mode="fill"
											minWidth={stack ? 160 : 160}
											minHeight={stack ? metricCardH : wideOverview ? metricCardH : 72}
											layoutOrder={0}
										>
											<Metric
												label={firstRun ? "earning now" : "output"}
												value={`${compactNumber(state.Production)} / sec`}
												detail={
													firstRun ? `${compactNumber(state.RawProduction)} before bonuses` : `${compactNumber(state.RawProduction)} base`
												}
												accent={Palette.cyan}
												size={UDim2.fromScale(1, 1)}
												compact={stack || denseHero}
												reveal={metricsReveal}
											/>
										</FlexItem>
										<FlexItem
											mode="fill"
											minWidth={stack ? 160 : 180}
											minHeight={stack ? metricCardH : wideOverview ? metricCardH : 72}
											layoutOrder={1}
										>
											<Metric
												label={firstRun ? "to spend" : "banked"}
												value={compactNumber(state.Cash)}
												detail={`${compactNumber(state.RunCash)} this run`}
												accent={Palette.mango}
												size={UDim2.fromScale(1, 1)}
												compact={stack || denseHero}
												reveal={metricsReveal}
											/>
										</FlexItem>
										<FlexItem
											mode="fill"
											minWidth={stack ? 160 : 180}
											minHeight={stack ? metricCardH : wideOverview ? metricCardH : 72}
											layoutOrder={2}
										>
											<Metric
												label={firstRun ? "bonus that stays" : "permanent"}
												value={`${compactNumber(state.PermanentMultiplier)}x`}
												detail={firstRun ? `${compactNumber(state.Rebirths)} rebirths` : `${compactNumber(state.Rebirths)} resets`}
												accent={Palette.violet}
												size={UDim2.fromScale(1, 1)}
												compact={stack || denseHero}
												reveal={metricsReveal}
											/>
										</FlexItem>
									</Flex>
								</frame>
							),
						},
						{
							id: "notes",
							height: notesH,
							element: (
								<Panel
									layoutOrder={2}
									size={UDim2.fromScale(1, 1)}
									accent={Palette.cyan}
									background={Palette.panel}
									padding={stack ? chrome.cardPadding : ultraOverview ? 20 : 18}
									reveal={notesReveal}
									clips={false}
								>
									{(() => {
										let stellarRate = 0;
										if (config !== undefined && typeIs(config.Machines, "table")) {
											for (const machine of config.Machines) {
												if (machine !== undefined && machine.Id === "StellarCore") {
													stellarRate = listedFluxPerSec(machine);
													break;
												}
											}
										}
										const coreDust = firstRebirthStardust(config);
										let title = "Push toward rebirth";
										let fillLine = `Full bar pays 1 core + ${compactNumber(coreDust)} stardust.`;
										let body = `Pays 1 core + ${compactNumber(coreDust)} stardust.`;
										let meter = progress;
										let accent = Palette.cyan;
										let cta = "";
										let ctaAction: (() => unknown) | undefined;
										let statValue = `${math.floor(progress * 100 + 0.5)}%`;
										let statLabel = "Pays 1 core";
										if (vaultFill >= 0.99) {
											title = "Collect stored Flux";
											body = "Vault full. Collect.";
											meter = 1;
											accent = Palette.mango;
											cta = "Collect stored Flux";
											ctaAction = () => dispatch("CollectVault");
											statValue = "Full";
											statLabel = "Vault";
										} else {
											const stellar = state.Machines.StellarCore ?? 0;
											if (stellar < 1) {
												if (canCollect) {
													title = "Collect stored Flux";
													body =
														stellarRate > 0
															? `Collect this into cash, then buy Stellar Core (+${compactNumber(stellarRate)}/sec). You keep earning for ${offlineHours}h while you're away.`
															: `Collect this into cash, then buy Stellar Core. You keep earning for ${offlineHours}h while you're away.`;
													fillLine =
														stellarRate > 0
															? `Collect pays cash for Stellar Core (+${compactNumber(stellarRate)}/sec).`
															: "Collect pays cash for Stellar Core.";
													meter = vaultFill;
													accent = Palette.green;
													cta = "Collect stored Flux";
													ctaAction = fireCollect;
													statValue = compactNumber(state.Vault);
													statLabel = "Into cash";
												} else {
													title = "Buy a machine";
													body =
														stellarRate > 0
															? `Stellar Core earns ${compactNumber(stellarRate)} Flux/sec into this vault once you buy it. You keep earning for ${offlineHours}h while you're away.`
															: `Stellar Core earns Flux into this vault every second. You keep earning for ${offlineHours}h while you're away.`;
													fillLine =
														stellarRate > 0
															? `Buying Stellar Core starts ${compactNumber(stellarRate)} Flux/sec.`
															: "Buying Stellar Core starts Flux every second.";
													meter = 0.08;
													cta = "Buy a machine";
													ctaAction = openWorkshop;
													statValue = stellarRate > 0 ? `+${compactNumber(stellarRate)}` : "0";
													statLabel = stellarRate > 0 ? "flux / sec" : "machines";
												}
											} else {
												const efficiency = state.Research.Efficiency ?? 0;
												if (efficiency < 3) {
													title = "Buy Efficiency to 3";
													body = "Unlocks Storage.";
													fillLine = "Full bar unlocks Storage.";
													meter = math.clamp(efficiency / 3, 0, 1);
													cta = "Open Research";
													ctaAction = () => navigate?.("Research");
													statValue = `${efficiency}/3`;
													statLabel = "Unlocks storage";
												} else {
													const storage = state.Research.Storage ?? 0;
													if (storage < 3) {
														title = "Buy Storage to 3";
														body = "Unlocks the offline relay.";
														fillLine = "Full bar unlocks the offline relay.";
														meter = math.clamp(storage / 3, 0, 1);
														cta = "Open Research";
														ctaAction = () => navigate?.("Research");
														statValue = `${storage}/3`;
														statLabel = "Unlocks relay";
													} else {
														const offline = state.Research.Offline ?? 0;
														if (offline < 1) {
															title = "Buy the offline relay";
															body = "Longer offline pay.";
															fillLine = "This buy pays you longer while you're away.";
															meter = 0.15;
															cta = "Open Research";
															ctaAction = () => navigate?.("Research");
															statValue = "Next";
															statLabel = "Longer AFK";
														} else {
															const overcharge = state.Research.Overcharge ?? 0;
															if (overcharge < 1) {
																title = "Buy the tap bonus";
																body = "Stronger taps.";
																fillLine = "This buy makes taps stronger.";
																meter = 0.2;
																cta = "Open Research";
																ctaAction = () => navigate?.("Research");
																statValue = "Next";
																statLabel = "Stronger taps";
															} else if (canRebirth) {
																title = "Rebirth for Cores";
																body = `Rebirth for ${compactNumber(state.PrestigeReward)} Cores.`;
																fillLine = `Collect ${compactNumber(state.PrestigeReward)} cores below.`;
																meter = 1;
																accent = Palette.pink;
																statValue = `+${compactNumber(state.PrestigeReward)}`;
																statLabel = "Cores ready";
															} else if (progress < 0.45) {
																title = "Buy more machines";
																body = `Pays 1 core + ${compactNumber(coreDust)} stardust.`;
																fillLine = `Full bar pays 1 core + ${compactNumber(coreDust)} stardust.`;
																cta = "Buy a machine";
																ctaAction = openWorkshop;
																statValue = `${math.floor(progress * 100 + 0.5)}%`;
																statLabel = "Pays 1 core";
															}
														}
													}
												}
											}
										}
										const firstGoal = vaultFill < 0.99 ? firstGoalView(state) : undefined;
										const adaptiveGoal =
											vaultFill < 0.99 && firstGoal === undefined
												? overviewGoal(state, { missions: missionsReady, lab: labReady, path: pathReady })
												: undefined;
										if (firstGoal !== undefined) {
											const goal = firstGoal.goal;
											title = goal.title;
											body = firstGoal.done
												? `Done. Claim ${compactNumber(goal.rewardFlux)} Flux${goal.rewardKeys !== undefined ? " and a crate key" : ""}.`
												: firstGoal.open
													? goal.line
													: `${goal.line} Opens at level ${goal.pageLevel}.`;
											if (firstGoal.index === 1 && !firstGoal.done) {
												body += " You can turn these goals off in Settings.";
											}
											fillLine = "";
											meter = firstGoal.have / math.max(1, goal.need);
											accent = firstGoal.done ? Palette.green : Palette.mango;
											statValue = firstGoal.done ? `+${compactNumber(goal.rewardFlux)}` : `${firstGoal.have}/${goal.need}`;
											statLabel = `${firstGoal.index} of ${FirstGoals.GOALS.size()}`;
											cta = firstGoal.done ? "Claim reward" : firstGoal.open ? goal.cta : "";
											ctaAction = undefined;
											if (firstGoal.done) {
												ctaAction = () => dispatch("ClaimFirstGoal", { Id: goal.id });
											} else if (firstGoal.open && navigate !== undefined) {
												const page = goal.page;
												ctaAction = () => navigate(page);
											}
										}
										if (adaptiveGoal !== undefined) {
											title = adaptiveGoal.title;
											body = adaptiveGoal.body;
											fillLine = "";
											meter = adaptiveGoal.progress;
											statValue = adaptiveGoal.value;
											statLabel = adaptiveGoal.label;
											cta = adaptiveGoal.cta ?? "";
											ctaAction = undefined;
											if (adaptiveGoal.page === "Domain") {
												ctaAction = openDomain;
											} else if (adaptiveGoal.page !== undefined && navigate !== undefined) {
												const page = adaptiveGoal.page;
												ctaAction = () => navigate(page);
											}
										}
										const meterTop = stack ? notesH - (cta !== "" ? TapTarget + 28 : 28) : notesH - 52;
										const bodyRoom = math.max(16, meterTop - 52 - 6);
										const ladderSlots = math.clamp(math.floor(bodyRoom / 13), 1, 3);
										const ladder =
											vaultFill >= 0.99 || adaptiveGoal !== undefined || firstGoal !== undefined
												? []
												: progressLadder(state, config, ladderSlots);
										if (ladder.size() > 0) {
											const keep: string[] = [];
											const limit = fillLine !== "" ? math.max(0, ladderSlots - 1) : ladderSlots;
											for (let index = 0; index < math.min(limit, ladder.size()); index++) {
												keep[index] = ladder[index];
											}
											if (fillLine !== "" && keep.size() > 0) {
												body = fillLine + "\n" + keep.join("\n");
											} else if (fillLine !== "") {
												body = fillLine;
											} else {
												body = ladder.join("\n");
											}
										}
										const copyLeft = stack ? 0 : 48;
										const copyWidth = stack ? 0 : -220;
										const action = ctaAction;
										const showCta = !stack && cta !== "" && action !== undefined;
										return (
											<>
												{!stack && (
													<IconTile
														kind="Milestone"
														accent={accent}
														size={34}
														radius={10}
														position={UDim2.fromOffset(0, 0)}
														spin={false}
														reducedMotion={quietMotion}
													/>
												)}
												<Text
													value={firstGoal !== undefined ? "First goals" : "Next up"}
													size={11}
													color={accent}
													weight={Enum.FontWeight.Heavy}
													fit={false}
													position={UDim2.fromOffset(copyLeft, stack ? 0 : 2)}
													sizeConstraint={new UDim2(1, copyWidth - copyLeft, 0, 16)}
												/>
												<Text
													value={title}
													size={stack ? 19 : 20}
													color={Palette.cream}
													weight={Enum.FontWeight.Heavy}
													fit={true}
													minSize={14}
													position={UDim2.fromOffset(copyLeft, 22)}
													sizeConstraint={new UDim2(1, copyWidth - copyLeft, 0, 28)}
												/>
												<Text
													value={body}
													size={ladder.size() > 0 ? 11 : stack ? chrome.labelText : 12}
													color={Palette.creamSoft}
													wrap={true}
													fit={true}
													minSize={11}
													position={UDim2.fromOffset(copyLeft, 52)}
													sizeConstraint={new UDim2(1, copyWidth - copyLeft, 0, ladder.size() > 0 ? bodyRoom : stack ? 48 : 36)}
												/>
												<Meter
													value={meter}
													color={accent}
													reducedMotion={softMotion}
													shimmer={meter >= 0.99 && !effectsPaused}
													position={UDim2.fromOffset(copyLeft, stack ? notesH - (cta !== "" ? TapTarget + 28 : 28) : notesH - 52)}
													size={new UDim2(1, copyWidth - copyLeft, 0, 8)}
												/>
												{!stack && (
													<frame
														Size={UDim2.fromOffset(196, 112)}
														Position={new UDim2(1, -196, 0.5, -56)}
														BackgroundColor3={Palette.ink}
														BorderSizePixel={0}
														ZIndex={3}
													>
														<uicorner CornerRadius={new UDim(0, Radius.lg)} />
														<uistroke
															ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
															LineJoinMode={Enum.LineJoinMode.Round}
															Color={accent}
															Thickness={1}
															Transparency={0.55}
														/>
														<Text
															value={statValue}
															size={22}
															color={accent}
															weight={Enum.FontWeight.Heavy}
															align={Enum.TextXAlignment.Center}
															fit={true}
															minSize={14}
															position={UDim2.fromOffset(8, showCta ? 8 : 24)}
															sizeConstraint={new UDim2(1, -16, 0, 32)}
														/>
														<Text
															value={statLabel}
															size={11}
															color={Palette.creamSoft}
															weight={Enum.FontWeight.Heavy}
															align={Enum.TextXAlignment.Center}
															fit={false}
															position={UDim2.fromOffset(8, showCta ? 40 : 58)}
															sizeConstraint={new UDim2(1, -16, 0, 16)}
														/>
														{showCta && action !== undefined && (
															<Button
																text={cta}
																onClick={action}
																color={accent}
																textColor={Palette.ink}
																size={new UDim2(1, -16, 0, TapTarget)}
																position={UDim2.fromOffset(8, 64)}
																reducedMotion={softMotion}
																highlight={meter >= 0.99}
															/>
														)}
													</frame>
												)}
												{stack && cta !== "" && action !== undefined && (
													<Button
														text={cta}
														onClick={action}
														color={accent}
														textColor={Palette.ink}
														size={new UDim2(1, 0, 0, TapTarget)}
														position={new UDim2(0, 0, 1, -TapTarget)}
														reducedMotion={softMotion}
														highlight={meter >= 0.99}
													/>
												)}
											</>
										);
									})()}
								</Panel>
							),
						},
						{
							id: "ops",
							height: opsH,
							element: (
								<Panel
									layoutOrder={3}
									size={UDim2.fromScale(1, 1)}
									accent={opsClaims > 0 ? Palette.green : Palette.cyan}
									background={Palette.panel}
									padding={stack ? chrome.cardPadding : 16}
									reveal={opsReveal}
									highlight={opsClaims > 0 && !effectsPaused}
									reducedMotion={softMotion}
									clips={false}
								>
									<frame
										Size={new UDim2(1, 0, 1, -(opsButtonH + 8))}
										BackgroundTransparency={1}
										BorderSizePixel={0}
										ClipsDescendants={true}
									>
										<Text
											value={firstRun && opsClaims === 0 ? "Rewards later" : (opsGuide?.OpsTitle ?? "Ready to claim")}
											size={11}
											color={opsClaims > 0 ? Palette.green : Palette.cyan}
											weight={Enum.FontWeight.Heavy}
											sizeConstraint={new UDim2(1, 0, 0, 16)}
										/>
										<Text
											value={
												opsClaims > 0
													? `${opsClaims} ready to claim`
													: storyWaiting > 0
														? storyWaiting === 1
															? "A chapter is waiting"
															: `${storyWaiting} chapters are waiting`
														: (opsGuide?.EmptyClaims ?? "Nothing to claim yet. Keep forging.")
											}
											size={stack ? 17 : 18}
											color={Palette.cream}
											weight={Enum.FontWeight.Heavy}
											fit={true}
											position={UDim2.fromOffset(0, 18)}
											sizeConstraint={new UDim2(1, 0, 0, 24)}
										/>
										<Text
											value={
												firstRun && opsClaims === 0
													? "Missions and other rewards unlock as you earn Flux. Do the highlighted step above first."
													: (opsDetail ?? opsGuide?.OpsBody ?? "Claims waiting across Missions, Lab, Forge Path, and Anomaly.")
											}
											size={stack ? chrome.labelText : 11}
											color={Palette.creamSoft}
											wrap={true}
											fit={true}
											minSize={11}
											position={UDim2.fromOffset(0, 46)}
											sizeConstraint={new UDim2(1, 0, 0, 28)}
										/>
									</frame>
									<frame
										Size={new UDim2(1, 0, 0, opsButtonH)}
										Position={new UDim2(0, 0, 1, -opsButtonH)}
										BackgroundTransparency={1}
										BorderSizePixel={0}
									>
										<uilistlayout
											FillDirection={Enum.FillDirection.Horizontal}
											HorizontalFlex={Enum.UIFlexAlignment.Fill}
											VerticalFlex={Enum.UIFlexAlignment.Fill}
											Wraps={stack}
											Padding={new UDim(0, 8)}
											SortOrder={Enum.SortOrder.LayoutOrder}
										/>
										<Button
											text={missionsReady > 0 ? `Missions · ${missionsReady}` : "Missions"}
											icon="Mission.2"
											onClick={() => navigate?.("Missions")}
											color={missionsReady > 0 ? Palette.cyan : Palette.panelSoft}
											textColor={missionsReady > 0 ? Palette.ink : Palette.creamSoft}
											size={opsButtonSize}
											reducedMotion={reducedMotion}
											highlight={missionsReady > 0}
											layoutOrder={0}
										/>
										<Button
											text={labReady > 0 ? `Lab · ${labReady}` : "Lab"}
											icon="Lab.3"
											onClick={() => navigate?.("Lab")}
											color={labReady > 0 ? Palette.mint : Palette.panelSoft}
											textColor={labReady > 0 ? Palette.ink : Palette.creamSoft}
											size={opsButtonSize}
											reducedMotion={reducedMotion}
											highlight={labReady > 0}
											layoutOrder={1}
										/>
										<Button
											text={pathReady ? (stack ? "Path · ready" : "Forge Path · ready") : "Forge Path"}
											icon="Forge.6"
											onClick={() => navigate?.("ForgePath")}
											color={pathReady ? Palette.violet : Palette.panelSoft}
											textColor={pathReady ? Palette.ink : Palette.creamSoft}
											size={opsButtonSize}
											reducedMotion={reducedMotion}
											highlight={pathReady}
											layoutOrder={2}
										/>
										<Button
											text={storyWaiting > 0 && !stack ? "Market" : "Black Market"}
											icon="Shop.3"
											onClick={() => navigate?.("Bazaar")}
											color={Palette.panelSoft}
											textColor={Palette.creamSoft}
											size={opsButtonSize}
											reducedMotion={reducedMotion}
											highlight={false}
											layoutOrder={4}
										/>
										{storyWaiting > 0 && (
											<Button
												text={`Story · ${storyWaiting}`}
												icon="Story.1"
												onClick={() => navigate?.("Story")}
												color={Palette.mint}
												textColor={Palette.ink}
												size={stack ? new UDim2(1, 0, 0, TapTarget) : opsButtonSize}
												reducedMotion={reducedMotion}
												highlight={true}
												layoutOrder={stack ? 5 : 3}
											/>
										)}
									</frame>
								</Panel>
							),
						},
						{
							id: "countdown",
							height: countdownInPage ? countdownH : 0,
							element: countdownInPage ? (
								<ReleaseCountdown releaseAt={releaseAt} reducedMotion={reducedMotion} stack={stack} layoutOrder={6} />
							) : (
								<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} />
							),
						},
						{
							id: "rebirth",
							height: rebirthVisible ? rebirthH : 0,
							element: rebirthVisible ? (
								<RebirthPanel
									state={state}
									config={config}
									dispatch={dispatch}
									reducedMotion={reducedMotion}
									effectsPaused={effectsPaused}
									height={rebirthH}
									reveal={rebirthReveal}
									openWorkshop={openWorkshop}
									layoutOrder={4}
								/>
							) : (
								<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} />
							),
						},
						{
							id: "domain",
							height: domainVisible ? domainH : 0,
							element: domainVisible ? (
								<Panel
									layoutOrder={5}
									size={UDim2.fromScale(1, 1)}
									accent={Palette.pink}
									background={darken(Palette.violet, 0.9)}
									padding={stack ? chrome.cardPadding : 18}
									reveal={domainReveal}
									highlight={domain.CanExpand && !effectsPaused}
									reducedMotion={softMotion}
									clips={false}
								>
									<uigradient Color={surfaceGradient(Palette.violet, 0.88)} Rotation={62} />
									<IconTile
										kind="World"
										accent={domain.CanExpand ? Palette.pink : Palette.violet}
										size={phone ? 54 : 62}
										radius={14}
										position={UDim2.fromOffset(0, phone ? 4 : 18)}
										glow={domain.CanExpand && !effectsPaused}
										spin={domain.CanExpand && !effectsPaused}
										reducedMotion={softMotion}
									/>
									<frame
										Size={phone ? new UDim2(1, -68, 0, 132) : new UDim2(1, -290, 1, 0)}
										Position={UDim2.fromOffset(phone ? 66 : 80, 0)}
										BackgroundTransparency={1}
										BorderSizePixel={0}
										ClipsDescendants={true}
									>
										<Text
											value={`Domain rank ${domain.Rank}`}
											size={11}
											color={Palette.pink}
											weight={Enum.FontWeight.Heavy}
											fit={false}
											sizeConstraint={new UDim2(1, 0, 0, 16)}
										/>
										<Text
											value={
												domain.CanExpand
													? `Domain rank ${domain.Rank + 1} is ready`
													: asFlux(state.Rebirths ?? 0) < asFlux(domain.RequiredRebirths)
														? `${compactNumber(math.max(1, asFlux(domain.RequiredRebirths) - asFlux(state.Rebirths ?? 0)))} more rebirths to Domain rank ${domain.Rank + 1}`
														: `More astral cores for Domain rank ${domain.Rank + 1}`
											}
											size={phone ? 20 : 23}
											color={Palette.cream}
											weight={Enum.FontWeight.Heavy}
											wrap={true}
											fit={true}
											minSize={11}
											position={UDim2.fromOffset(0, 22)}
											sizeConstraint={new UDim2(1, 0, 0, 34)}
										/>
										<Text
											value="Costs rebirths and cores. This run's machines and worlds reset. Research, relics, and Stardust stay."
											size={phone ? chrome.labelText : 11}
											color={Palette.creamSoft}
											wrap={true}
											fit={true}
											minSize={11}
											position={UDim2.fromOffset(0, 60)}
											sizeConstraint={new UDim2(1, 0, 0, phone ? 58 : 44)}
										/>
										{!phone && (
											<Text
												// only the bonuses that do something (a "1x vault time" is no bonus at all)
												value={(() => {
													const parts = [`${compactNumber(domain.ProductionMultiplier)}x production`];
													if (asFlux(domain.CapacityMultiplier) > 1.005) {
														parts.push(`${compactNumber(domain.CapacityMultiplier)}x vault time`);
													}
													if ((tonumber(domain.OfflineBonus) ?? 0) > 0.004) {
														parts.push(`+${math.floor(domain.OfflineBonus * 100 + 0.5)}% offline`);
													}
													return "Permanent: " + parts.join("  /  ");
												})()}
												size={11}
												color={Palette.cyan}
												weight={Enum.FontWeight.Bold}
												fit={false}
												position={UDim2.fromOffset(0, 112)}
												sizeConstraint={new UDim2(1, 0, 0, 18)}
											/>
										)}
									</frame>
									{phone ? (
										<frame
											Size={new UDim2(1, 0, 0, 186)}
											Position={new UDim2(0, 0, 1, -190)}
											BackgroundTransparency={1}
											BorderSizePixel={0}
											ClipsDescendants={true}
										>
											<Text
												value={`${compactNumber(state.Rebirths)} / ${compactNumber(domain.RequiredRebirths)} rebirths`}
												size={chrome.labelText}
												color={asFlux(state.Rebirths ?? 0) >= asFlux(domain.RequiredRebirths) ? Palette.green : Palette.muted}
												weight={Enum.FontWeight.Bold}
												fit={false}
												sizeConstraint={new UDim2(1, 0, 0, 16)}
											/>
											<Text
												value={`${compactNumber(state.Cores)} / ${compactNumber(domain.RequiredCores)} astral cores`}
												size={chrome.labelText}
												color={asFlux(state.Cores ?? 0) >= asFlux(domain.RequiredCores) ? Palette.green : Palette.muted}
												weight={Enum.FontWeight.Bold}
												fit={false}
												position={UDim2.fromOffset(0, 18)}
												sizeConstraint={new UDim2(1, 0, 0, 16)}
											/>
											<Meter
												value={domainProgress}
												rainbow={true}
												color={Palette.pink}
												reducedMotion={quietMotion}
												shimmer={domain.CanExpand && !effectsPaused}
												position={UDim2.fromOffset(0, 40)}
												size={new UDim2(1, 0, 0, 8)}
											/>
											<Text
												value={`Next: +${domain.EssenceReward} essence  ·  +${compactNumber(domain.StardustReward)} stardust`}
												size={chrome.labelText}
												color={Palette.mango}
												weight={Enum.FontWeight.Bold}
												wrap={true}
												fit={true}
												minSize={11}
												position={UDim2.fromOffset(0, 54)}
												sizeConstraint={new UDim2(1, 0, 0, 28)}
											/>
											<Button
												text={domain.CanExpand ? "Open the gate" : "View domain"}
												icon="Domain.2"
												onClick={openDomain}
												color={domain.CanExpand ? Palette.pink : Palette.panelSoft}
												textColor={domain.CanExpand ? Palette.ink : Palette.cream}
												outline={!domain.CanExpand}
												size={new UDim2(1, 0, 0, ctaH)}
												position={new UDim2(0, 0, 1, -ctaH)}
												reducedMotion={reducedMotion}
												highlight={domain.CanExpand}
											/>
										</frame>
									) : (
										<frame
											Size={UDim2.fromOffset(270, 188)}
											Position={new UDim2(1, -270, 0, 4)}
											BackgroundTransparency={1}
											BorderSizePixel={0}
											ClipsDescendants={true}
										>
											<Badge
												value={`${compactNumber(domain.Essence)} DOMAIN ESSENCE`}
												accent={Palette.pink}
												filled={true}
												position={UDim2.fromOffset(0, 0)}
												size={new UDim2(1, 0, 0, 26)}
											/>
											<Text
												value={`${compactNumber(state.Rebirths)} / ${compactNumber(domain.RequiredRebirths)} rebirths`}
												size={11}
												color={asFlux(state.Rebirths ?? 0) >= asFlux(domain.RequiredRebirths) ? Palette.green : Palette.muted}
												weight={Enum.FontWeight.Bold}
												fit={false}
												position={UDim2.fromOffset(0, 34)}
												sizeConstraint={new UDim2(1, 0, 0, 16)}
											/>
											<Text
												value={`${compactNumber(state.Cores)} / ${compactNumber(domain.RequiredCores)} astral cores`}
												size={11}
												color={asFlux(state.Cores ?? 0) >= asFlux(domain.RequiredCores) ? Palette.green : Palette.muted}
												weight={Enum.FontWeight.Bold}
												fit={false}
												position={UDim2.fromOffset(0, 52)}
												sizeConstraint={new UDim2(1, 0, 0, 16)}
											/>
											<Meter
												value={domainProgress}
												rainbow={true}
												color={Palette.pink}
												reducedMotion={quietMotion}
												shimmer={domain.CanExpand && !effectsPaused}
												position={UDim2.fromOffset(0, 74)}
												size={new UDim2(1, 0, 0, 8)}
											/>
											<Button
												text={domain.CanExpand ? "Open the gate" : "Requirements"}
												icon="Domain.3"
												onClick={openDomain}
												color={domain.CanExpand ? Palette.pink : Palette.panelSoft}
												textColor={domain.CanExpand ? Palette.ink : Palette.cream}
												outline={!domain.CanExpand}
												size={new UDim2(1, 0, 0, ctaH)}
												position={UDim2.fromOffset(0, 96)}
												reducedMotion={reducedMotion}
												highlight={domain.CanExpand}
											/>
										</frame>
									)}
								</Panel>
							) : (
								<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} />
							),
						},
						{
							id: "journal",
							height: journalH,
							element: (
								<Panel
									layoutOrder={7}
									size={UDim2.fromScale(1, 1)}
									accent={Palette.mango}
									background={Palette.panelRaised}
									padding={stack ? chrome.cardPadding : 16}
									reducedMotion={softMotion}
									clips={true}
								>
									<Text
										value={`Forge journal  ·  ${journey.Count} / ${journey.Total}`}
										size={10}
										color={Palette.mango}
										weight={Enum.FontWeight.Heavy}
										fit={true}
										minSize={8}
										sizeConstraint={new UDim2(1, 0, 0, 16)}
									/>
									<Text
										value={journeyNext !== undefined ? journeyNext.Title : "Journal complete"}
										size={phone ? 17 : 19}
										color={Palette.cream}
										weight={Enum.FontWeight.Heavy}
										fit={true}
										minSize={13}
										position={UDim2.fromOffset(0, 20)}
										sizeConstraint={new UDim2(1, 0, 0, 26)}
									/>
									<Text
										value={
											journeyNext !== undefined
												? `${compactNumber(journeyNext.Have)} / ${compactNumber(journeyNext.Target)} ${journeyNext.Unit}`
												: "Complete"
										}
										size={chrome.labelText}
										color={Palette.creamSoft}
										fit={true}
										minSize={9}
										position={UDim2.fromOffset(0, 48)}
										sizeConstraint={new UDim2(1, 0, 0, 16)}
									/>
									<Meter
										value={journeyNext !== undefined ? journeyNext.Progress : 1}
										color={Palette.mango}
										reducedMotion={quietMotion}
										shimmer={false}
										position={UDim2.fromOffset(0, 70)}
										size={new UDim2(1, 0, 0, 6)}
									/>
</Panel>
							),
						},
						{
							// this session, live
							id: "session",
							// title row 24 + stat grid + panel padding on both sides (the old +56 clipped the second row)
							height: SessionStats.height(phone ? 2 : 4) + 24 + 2 * (stack ? chrome.cardPadding : Pad.panel),
							element: (
								<Panel
									layoutOrder={8}
									size={UDim2.fromScale(1, 1)}
									accent={Palette.cyan}
									background={Palette.panelRaised}
									padding={stack ? chrome.cardPadding : Pad.panel}
									reducedMotion={softMotion}
									clips={true}
								>
									<Text
										value="This session"
										size={14}
										color={Palette.cream}
										weight={Enum.FontWeight.Bold}
										fit={false}
										sizeConstraint={new UDim2(1, 0, 0, 16)}
									/>
									<SessionStats.Card columns={phone ? 2 : 4} position={UDim2.fromOffset(0, 24)} reducedMotion={softMotion} />
								</Panel>
							),
						},
					]))}
				/>
			</frame>
		</frame>
	);
}

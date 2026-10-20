import React from "@rbxts/react";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { fitTouchGridWidth, moreDockHeight } from "../../CoreKit/mobileLayout";
import { chromeFor, darken, Palette, scrollTail, TapTarget } from "../../CoreKit/theme";
import { useFlipperSpring, useStagger, useViewport } from "../../MotionKit/motion";
import { MobileTabPinsEditor, mobileTabPinsEditorHeight } from "./MobileTabPinsEditor";
import { AudioPlayer, BrowseApi, clientModule, kitMember, LuauComponent, sharedModule } from "../luauKits";

const UserInputService = game.GetService("UserInputService");
const { Audio } = kitMember<{ Audio: AudioPlayer }>("AudioKit", "audio");
const { MobileControls } = kitMember<{ MobileControls: LuauComponent }>("UiOverlays", "MobileControls");
const { PageScaffold } = kitMember<{ PageScaffold: LuauComponent }>("LayoutKit", "pageScaffold");
const { Icon } = kitMember<{ Icon: LuauComponent }>("ArtKit", "Icon");
const { Button, Panel, SearchField, Slider, SegmentedTabs, Text } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");
const Browse = clientModule<BrowseApi>("BrowseKit");

interface SchemaSection {
	id: string;
	label: string;
	blurb: string;
	icon: string;
	accent: string;
	touchOnly?: boolean;
}
interface SchemaChoice {
	label: string;
	value: number;
}
interface SchemaEntry {
	key: string;
	section: string;
	label: string;
	help: string;
	kind: string;
	default: number;
	advanced?: boolean;
	choices?: SchemaChoice[];
}
interface SchemaPreset {
	id: string;
	label: string;
	values: Record<string, number>;
	notice: string;
}
type Settings = Record<string, number | undefined>;
interface SettingsSchema {
	SECTIONS: SchemaSection[];
	ENTRIES: SchemaEntry[];
	PRESETS: SchemaPreset[];
	value(this: void, settings: Settings, key: string): number;
	matchingPreset(this: void, settings: Settings): string | undefined;
	sectionDefaults(this: void, section: string): Record<string, number>;
	group(this: void, key: string): { label: string; order: number };
}
const Schema = sharedModule<(name: string) => SettingsSchema>("SharedData")("SettingsSchema");

type Dispatch = (action: string, payload?: object) => unknown;

const ROW_H = 60;
const ROW_H_STACK = 110;
const NAV_W = 196;
const MOBILE_DOCK_DESTINATIONS = ["Overview", "Workshop", "Inventory", "Research", "Shop", "Settings"];

function accentOf(section: SchemaSection): Color3 {
	return (Palette as unknown as Record<string, Color3 | undefined>)[section.accent] ?? Palette.cyan;
}
const SECTION_BY_ID: Record<string, SchemaSection | undefined> = {};
for (const section of Schema.SECTIONS) {
	SECTION_BY_ID[section.id] = section;
}

// The forge switch. One spring drives everything, so the track colour, halo, knob stretch and
// glyph all move together instead of snapping: the knob stretches like jelly mid-travel and
// settles with a small overshoot, the track fills with the section colour, a dot lights inside
// the knob when on. Hover brightens the edge; pressing squeezes the knob.
const SWITCH_W = 58;
const SWITCH_H = 30;
const SWITCH_KNOB = 22;
const SWITCH_PAD = 4;

interface SwitchProps {
	on: boolean;
	accent: Color3;
	softMotion?: boolean;
	anchorPoint?: Vector2;
	position: UDim2;
	onToggle: () => void;
}

function Switch(props: SwitchProps) {
	const { on, accent, softMotion } = props;
	const amount = useFlipperSpring(on ? 1 : 0, softMotion, 380, 24);
	const [hovered, setHovered] = React.useState(false);
	const [pressed, setPressed] = React.useState(false);
	const hover = useFlipperSpring(hovered ? 1 : 0, softMotion, 700, 40);
	const press = useFlipperSpring(pressed ? 1 : 0, softMotion, 1000, 42);
	const anchor = props.anchorPoint ?? Vector2.zero;
	const trackX = anchor.X >= 0.5 ? 1 : 0;
	const motion = React.joinBindings([amount, press]);
	const travel = SWITCH_W - SWITCH_PAD * 2 - SWITCH_KNOB;
	const settle = (a: number) => math.clamp(a, 0, 1);
	return (
		<textbutton
			Size={UDim2.fromOffset(SWITCH_W + 10, TapTarget)}
			Position={props.position}
			AnchorPoint={anchor}
			BackgroundTransparency={1}
			AutoButtonColor={false}
			BorderSizePixel={0}
			Text=""
			Selectable={true}
			Event={{
				Activated: () => {
					Audio.play(on ? "toggleOff" : "toggleOn");
					props.onToggle();
				},
				MouseEnter: () => setHovered(true),
				MouseLeave: () => {
					setHovered(false);
					setPressed(false);
				},
				SelectionGained: () => setHovered(true),
				SelectionLost: () => setHovered(false),
				MouseButton1Down: () => setPressed(true),
				MouseButton1Up: () => setPressed(false),
			}}
		>
			{/* halo behind the track, only when on */}
			<frame
				key="Halo"
				Size={UDim2.fromOffset(SWITCH_W + 8, SWITCH_H + 8)}
				Position={new UDim2(trackX, trackX === 1 ? 4 : -4, 0.5, 0)}
				AnchorPoint={new Vector2(trackX, 0.5)}
				BackgroundColor3={accent}
				BackgroundTransparency={amount.map((a) => 1 - 0.16 * settle(a))}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
			<frame
				key="Track"
				Size={UDim2.fromOffset(SWITCH_W, SWITCH_H)}
				Position={UDim2.fromScale(trackX, 0.5)}
				AnchorPoint={new Vector2(trackX, 0.5)}
				BackgroundColor3={amount.map((a) => Palette.graphite.Lerp(accent, settle(a)))}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uigradient Rotation={90} Transparency={new NumberSequence([new NumberSequenceKeypoint(0, 0), new NumberSequenceKeypoint(1, 0.18)])} />
				<uistroke
					ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
					Color={amount.map((a) => Palette.lineSoft.Lerp(accent, settle(a)))}
					Transparency={hover.map((h) => 0.4 - 0.32 * math.clamp(h, 0, 1))}
					Thickness={1}
				/>
				{/* stretches toward its direction of travel, squeezes while pressed */}
				<frame
					key="Knob"
					Size={motion.map((values) => {
						const a = values[0];
						const p = math.clamp(values[1], 0, 1);
						const stretch = math.sin(math.pi * settle(a)) * 9;
						return UDim2.fromOffset(SWITCH_KNOB + stretch + p * 5, SWITCH_KNOB - p * 3);
					})}
					Position={amount.map((a) => new UDim2(0, SWITCH_PAD + SWITCH_KNOB / 2 + math.clamp(a, -0.08, 1.08) * travel, 0.5, 0))}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundColor3={amount.map((a) => Palette.creamSoft.Lerp(Palette.cream, settle(a)))}
					BorderSizePixel={0}
					ZIndex={2}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
					{/* off: a short dash */}
					<frame
						key="Off"
						Size={UDim2.fromOffset(8, 2)}
						Position={UDim2.fromScale(0.5, 0.5)}
						AnchorPoint={new Vector2(0.5, 0.5)}
						BackgroundColor3={Palette.graphite}
						BackgroundTransparency={amount.map((a) => 0.25 + 0.75 * settle(a))}
						BorderSizePixel={0}
						ZIndex={3}
					/>
					{/* on: a lit dot in the section colour */}
					<frame
						key="On"
						Size={amount.map((a) => {
							const d = 4 + 4 * settle(a);
							return UDim2.fromOffset(d, d);
						})}
						Position={UDim2.fromScale(0.5, 0.5)}
						AnchorPoint={new Vector2(0.5, 0.5)}
						BackgroundColor3={accent}
						BackgroundTransparency={amount.map((a) => 1 - settle(a))}
						BorderSizePixel={0}
						ZIndex={3}
					>
						<uicorner CornerRadius={new UDim(1, 0)} />
					</frame>
				</frame>
			</frame>
		</textbutton>
	);
}

interface ChoiceProps {
	choices: SchemaChoice[];
	value: number;
	accent: Color3;
	size: UDim2;
	position: UDim2;
	anchorPoint?: Vector2;
	softMotion?: boolean;
	onPick: (value: number) => void;
}

// Several fixed options: the shared segmented control, whose highlight slides between choices.
function Choice(props: ChoiceProps) {
	const { choices, value } = props;
	const options: Array<{ id: string; label: string }> = [];
	let picked: string | undefined;
	choices.forEach((option, i) => {
		const id = tostring(i + 1);
		options.push({ id, label: option.label });
		if (math.abs(option.value - value) < 0.02) {
			picked = id;
		}
	});
	return (
		<frame Size={props.size} Position={props.position} AnchorPoint={props.anchorPoint} BackgroundTransparency={1}>
			<SegmentedTabs
				options={options}
				value={picked}
				accent={props.accent}
				gap={4}
				size={UDim2.fromScale(1, 1)}
				reducedMotion={props.softMotion}
				onChange={(id: string) => {
					const option = choices[(tonumber(id) ?? 0) - 1] as SchemaChoice | undefined;
					if (option !== undefined && id !== picked) {
						props.onPick(option.value);
					}
				}}
			/>
		</frame>
	);
}

interface SettingRowProps {
	entry: SchemaEntry;
	value: number;
	accent: Color3;
	tag?: string;
	stack: boolean;
	softMotion?: boolean;
	dispatch: Dispatch;
	layoutOrder: number;
}

function SettingRow(props: SettingRowProps) {
	const { entry, value: saved, accent, stack, softMotion, dispatch } = props;
	const [draft, setDraft] = React.useState(saved);
	React.useEffect(() => {
		setDraft(saved);
	}, [saved]);
	const commit = (value: number) => {
		setDraft(value);
		dispatch("SetSetting", { Key: entry.key, Value: value });
	};
	const controlW = entry.kind === "toggle" ? 68 : entry.kind === "choice" ? math.min(260, 64 * (entry.choices ?? []).size()) : 240;
	const textRight = stack ? 0 : controlW + 20;
	let control: React.Element;
	if (entry.kind === "toggle") {
		control = (
			<Switch
				on={draft >= 0.5}
				accent={accent}
				softMotion={softMotion}
				position={stack ? new UDim2(0, 0, 1, -(TapTarget + 2)) : new UDim2(1, 0, 0.5, 0)}
				anchorPoint={stack ? new Vector2(0, 0) : new Vector2(1, 0.5)}
				onToggle={() => commit(draft >= 0.5 ? 0 : 1)}
			/>
		);
	} else if (entry.kind === "choice") {
		control = (
			<Choice
				choices={entry.choices!}
				value={draft}
				accent={accent}
				size={stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(controlW, TapTarget)}
				position={stack ? new UDim2(0, 0, 1, -(TapTarget + 2)) : new UDim2(1, 0, 0.5, 0)}
				anchorPoint={stack ? new Vector2(0, 0) : new Vector2(1, 0.5)}
				onPick={commit}
				softMotion={softMotion}
			/>
		);
	} else {
		control = (
			<frame
				Size={stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(controlW, 32)}
				Position={stack ? new UDim2(0, 0, 1, -TapTarget) : new UDim2(1, 0, 0.5, 0)}
				AnchorPoint={stack ? new Vector2(0, 0) : new Vector2(1, 0.5)}
				BackgroundTransparency={1}
			>
				<Slider
					value={draft}
					accent={accent}
					reducedMotion={softMotion}
					size={new UDim2(1, -52, 1, 0)}
					onChange={setDraft}
					onCommit={(value: number) => commit(value)}
				/>
				<Text
					value={`${math.floor(draft * 100 + 0.5)}%`}
					size={13}
					color={Palette.creamSoft}
					weight={Enum.FontWeight.Bold}
					align={Enum.TextXAlignment.Right}
					position={new UDim2(1, -46, 0, 0)}
					sizeConstraint={new UDim2(0, 46, 1, 0)}
				/>
			</frame>
		);
	}
	return (
		<frame Size={new UDim2(1, 0, 0, stack ? ROW_H_STACK : ROW_H)} LayoutOrder={props.layoutOrder} BackgroundTransparency={1} BorderSizePixel={0}>
			<Text
				value={props.tag !== undefined ? `${entry.label}  ·  ${props.tag}` : entry.label}
				size={15}
				color={Palette.cream}
				weight={Enum.FontWeight.Bold}
				position={UDim2.fromOffset(0, stack ? 8 : 11)}
				sizeConstraint={new UDim2(1, -textRight, 0, 20)}
			/>
			<Text
				value={entry.help}
				size={12}
				color={Palette.muted}
				position={UDim2.fromOffset(0, stack ? 29 : 32)}
				sizeConstraint={new UDim2(1, -textRight, 0, 16)}
			/>
			{control}
			<frame
				Size={new UDim2(1, 0, 0, 1)}
				Position={new UDim2(0, 0, 1, 0)}
				BackgroundColor3={Palette.lineSoft}
				BackgroundTransparency={0.75}
				BorderSizePixel={0}
			/>
		</frame>
	);
}

interface SectionButtonProps {
	section: SchemaSection;
	active: boolean;
	count: number;
	compact: boolean;
	size: UDim2;
	layoutOrder: number;
	softMotion?: boolean;
	onPick: (id: string) => void;
}

function SectionButton(props: SectionButtonProps) {
	const { section, active } = props;
	const accent = accentOf(section);
	return (
		<frame Size={props.size} LayoutOrder={props.layoutOrder} BackgroundTransparency={1} BorderSizePixel={0}>
			<Button
				text=""
				size={UDim2.fromScale(1, 1)}
				color={active ? darken(accent, 0.62) : Palette.panelSoft}
				highlight={active}
				reducedMotion={props.softMotion}
				sound={active ? false : "tabSwitch"}
				onClick={() => {
					if (!active) {
						props.onPick(section.id);
					}
				}}
				children={
					<>
						<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ZIndex={11}>
							<Icon
								kind={section.icon}
								color={active ? accent : Palette.muted}
								accent={accent}
								size={18}
								position={new UDim2(0, props.compact ? 10 : 14, 0.5, -9)}
							/>
							<Text
								value={section.label}
								size={14}
								color={active ? Palette.cream : Palette.creamSoft}
								weight={active ? Enum.FontWeight.Heavy : Enum.FontWeight.Bold}
								fit={props.compact === true} // three to a row on phones: long names shrink to fit
								minSize={10}
								position={UDim2.fromOffset(props.compact ? 34 : 40, 0)}
								sizeConstraint={new UDim2(1, props.compact ? -38 : -70, 1, 0)}
								zIndex={11}
							/>
							{!props.compact && (
								<Text
									value={tostring(props.count)}
									size={12}
									color={Palette.muted}
									align={Enum.TextXAlignment.Right}
									position={new UDim2(1, -36, 0, 0)}
									sizeConstraint={new UDim2(0, 26, 1, 0)}
									zIndex={11}
								/>
							)}
						</frame>
					</>
				}
			/>
		</frame>
	);
}

interface MobileSlot {
	id: string;
	label: string;
	xKey: string;
	yKey: string;
	x: number;
	y: number;
	defaultX: number;
	defaultY: number;
	width: number;
	height: number;
	anchorY?: number;
	safeTop: number;
}

interface SettingsViewProps {
	state: {
		Settings?: Settings;
		Game: { Version: string };
		FeatureUnlocks?: Record<string, { Unlocked?: boolean } | undefined>;
		Flags?: { MobileLayoutSlots?: unknown; MobileTabPins?: unknown };
	};
	dispatch: Dispatch;
	reducedMotion?: boolean;
}

export function SettingsView({ state, dispatch, reducedMotion }: SettingsViewProps) {
	const softMotion = reducedMotion;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const stack = chrome.contentStack;
	const touch = !viewport.desktop && UserInputService.TouchEnabled;
	const mobileHudAvailable = touch && chrome.stack;
	const settings = state.Settings ?? {};
	const [activeSection, setActiveSection] = React.useState("sound");
	const [query, setQuery] = Browse.useLinkedQuery("Settings");
	const [changedOnly, setChangedOnly] = React.useState(false);
	const [advancedOpen, setAdvancedOpen] = React.useState<Record<string, boolean | undefined>>({});
	const [mobileEdit, setMobileEdit] = React.useState(false);
	const reveal = useStagger(0, softMotion);

	const sections: SchemaSection[] = [];
	for (const section of Schema.SECTIONS) {
		if (!section.touchOnly || mobileHudAvailable) {
			sections.push(section);
		}
	}
	React.useEffect(() => {
		const sectionInfo = SECTION_BY_ID[activeSection];
		if (sectionInfo && sectionInfo.touchOnly && !mobileHudAvailable) {
			setActiveSection("interface");
		}
	}, [activeSection, mobileHudAvailable]);
	const section = (SECTION_BY_ID[activeSection] ?? SECTION_BY_ID["interface"])!;
	const accent = accentOf(section);

	const settingsClaimHostRef = React.useRef<Frame>();
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = settingsClaimHostRef.current;
		if (host === undefined) {
			return undefined;
		}
		const job = task.defer(() => {
			if (host.Parent !== undefined) {
				GamepadNavigationService.FocusClaim(host);
			}
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [activeSection]);

	const searching = query.match("^%s*$")[0] === undefined;
	const isChanged = (entry: SchemaEntry) => {
		const current: unknown = Schema.value(settings, entry.key);
		const defaultValue = entry.default;
		if (typeIs(current, "number") && typeIs(defaultValue, "number")) {
			return math.abs(current - defaultValue) > 0.01;
		}
		return tostring(current) !== tostring(defaultValue);
	};
	const changedEntries: SchemaEntry[] = [];
	for (const entry of Schema.ENTRIES) {
		const home = SECTION_BY_ID[entry.section];
		if (!home) {
			continue;
		}
		if (!(home.touchOnly && !mobileHudAvailable) && isChanged(entry)) {
			changedEntries.push(entry);
		}
	}
	const showChanged = changedOnly && !searching;
	const listing = searching || showChanged;
	const rows: SchemaEntry[] = [];
	let hiddenAdvanced = 0;
	for (const entry of Schema.ENTRIES) {
		const home = SECTION_BY_ID[entry.section];
		if (!home || (home.touchOnly && !mobileHudAvailable)) {
			continue;
		}
		if (searching) {
			if (Browse.matches(query, entry.label, entry.help, home.label, entry.key)) {
				rows.push(entry);
			}
		} else if (showChanged) {
			if (isChanged(entry)) {
				rows.push(entry);
			}
		} else if (entry.section === activeSection) {
			if (entry.advanced && !advancedOpen[activeSection]) {
				hiddenAdvanced += 1;
			} else {
				rows.push(entry);
			}
		}
	}
	const counts: Record<string, number | undefined> = {};
	for (const entry of Schema.ENTRIES) {
		counts[entry.section] = (counts[entry.section] ?? 0) + 1;
	}

	const preset = Schema.matchingPreset(settings);
	const applyPreset = (entry: SchemaPreset) => {
		dispatch("SetSetting", { Values: entry.values, Label: entry.notice });
	};
	const resetSection = () => {
		dispatch("SetSetting", { Values: Schema.sectionDefaults(activeSection), Label: `${section.label} settings reset.` });
	};

	const quickScale = Schema.value(settings, "MobileQuickScale");
	const dockScale = Schema.value(settings, "MobileDockScale");
	const toastScale = Schema.value(settings, "MobileToastScale");
	const hudSafeTop = viewport.topInset + chrome.topbarRows + 12;
	const densityScale = 0.82 + Schema.value(settings, "UiDensity") * 0.36;
	const hudEdgePad = math.max(8, math.floor(chrome.pagePadding * densityScale));
	const dockGap = chrome.landscape ? 3 : 3 + math.floor(Schema.value(settings, "MobileButtonSpacing") * 5);
	const touchTargetFloor = Schema.value(settings, "LargeTouchTargets") >= 0.5 ? TapTarget + 6 : TapTarget;
	const dockCellH = math.max(touchTargetFloor, math.floor(chrome.moreCellH * (0.88 + dockScale * 0.16)));
	const quickWidth = math.max(200, (viewport.width - math.max(hudEdgePad, chrome.sideSafe) * 2) * (0.72 + quickScale * 0.28));
	const quickHeight = math.max(TapTarget + 8, math.floor(chrome.quickBarH * (0.86 + quickScale * 0.22)));
	const dockWidth = fitTouchGridWidth(viewport.width, hudEdgePad, chrome.sideSafe, chrome.moreCols, dockGap, 0.72 + dockScale * 0.28);
	let dockCount = 0;
	for (const id of MOBILE_DOCK_DESTINATIONS) {
		const unlock = state.FeatureUnlocks && state.FeatureUnlocks[id];
		if (!(unlock !== undefined && unlock.Unlocked === false)) {
			dockCount += 1;
		}
	}
	const dockHeight = moreDockHeight(true, math.max(1, dockCount), chrome.moreCols, dockCellH, dockGap);
	const toastWidth = math.min(220, math.max(180, viewport.width - 48)) * (0.8 + toastScale * 0.2);
	const toastHeight = 2 * (48 + 4);
	const mobileSlots = React.useMemo(() => {
		const slots: MobileSlot[] = [];
		const slot = (id: string, label: string, xKey: string, yKey: string, dx: number, dy: number, width: number, height: number, anchorY?: number) => {
			slots.push({
				id,
				label,
				xKey,
				yKey,
				x: settings[xKey] ?? dx,
				y: settings[yKey] ?? dy,
				defaultX: dx,
				defaultY: dy,
				width: math.floor(width),
				height: math.floor(height),
				anchorY,
				safeTop: hudSafeTop,
			});
		};
		if (chrome.quickBarH > 0) {
			slot("quick", "QUICK ACTIONS", "MobileQuickX", "MobileQuickY", 0.5, 0.7, quickWidth, quickHeight);
		}
		if (chrome.stack && viewport.height >= 480 && chrome.quickBarH > 0) {
			slot("dock", "NAVIGATION", "MobileDockX", "MobileDockY", 0.5, 0.92, dockWidth, dockHeight);
		}
		slot("toasts", "NOTIFICATIONS", "MobileToastX", "MobileToastY", 0.84, 0.27, toastWidth, toastHeight, 0);
		return slots;
	}, [
		chrome.quickBarH,
		chrome.stack,
		dockHeight,
		dockWidth,
		hudSafeTop,
		quickHeight,
		quickWidth,
		settings.MobileDockX,
		settings.MobileDockY,
		settings.MobileQuickX,
		settings.MobileQuickY,
		settings.MobileToastX,
		settings.MobileToastY,
		toastHeight,
		toastWidth,
		viewport.height,
	]);

	// Desktop keeps search and the view chips on one row beside each other; phones stack them.
	const searchH = stack ? TapTarget : 40;
	const actionsY = 56;
	const searchY = stack ? actionsY + 40 + 10 : 60;
	const chipsX = stack ? 0 : 356;
	const chipsY = stack ? searchY + searchH + 8 : searchY + math.floor((searchH - Browse.CHIP_H) / 2);
	const headerH = (stack ? chipsY + Browse.CHIP_H : searchY + math.max(searchH, Browse.CHIP_H)) + 32;
	const header = (
		<Panel size={UDim2.fromScale(1, 1)} accent={accent} background={Palette.panelRaised} padding={16} reveal={reveal} reducedMotion={softMotion} clips={false}>
			<Text
				value="Settings"
				size={stack ? 22 : 26}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={16}
				sizeConstraint={new UDim2(1, stack ? 0 : -340, 0, 30)}
			/>
			<Text
				value={`Saves automatically  ·  v${state.Game.Version}`}
				size={12}
				color={Palette.muted}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(0, 34)}
				sizeConstraint={new UDim2(1, stack ? 0 : -340, 0, 16)}
			/>
			<frame
				key="SettingsClaimActions"
				Size={stack ? new UDim2(1, 0, 0, 40) : UDim2.fromOffset(320, 40)}
				Position={stack ? UDim2.fromOffset(0, actionsY) : new UDim2(1, -320, 0, 0)}
				BackgroundTransparency={1}
				ClipsDescendants={false}
				ZIndex={6}
				ref={settingsClaimHostRef}
			>
				<Button
					text="REPLAY TOUR"
					icon="Guide.1"
					onClick={() => {
						dispatch("ReplayTutorial");
					}}
					color={Palette.panelSoft}
					textColor={Palette.cream}
					outline={true}
					size={new UDim2(0.5, -4, 1, 0)}
					reducedMotion={softMotion}
				/>
				<Button
					text="PATCH NOTES"
					icon="Gift.14"
					onClick={() => {
						dispatch("OpenRelease");
					}}
					color={Palette.panelSoft}
					textColor={Palette.cream}
					outline={true}
					size={new UDim2(0.5, -4, 1, 0)}
					position={new UDim2(0.5, 4, 0, 0)}
					reducedMotion={softMotion}
				/>
			</frame>
			<SearchField
				value={query}
				onChange={setQuery}
				placeholder="Search settings"
				accent={accent}
				size={stack ? new UDim2(1, 0, 0, searchH) : UDim2.fromOffset(340, searchH)}
				position={UDim2.fromOffset(0, searchY)}
				reducedMotion={softMotion}
			/>
			<Browse.ChipRow
				options={[
					{ id: "sections", label: "By section", icon: "Settings.2" },
					{ id: "changed", label: "Changed from default", icon: "Refresh.4" },
				]}
				value={changedOnly ? "changed" : "sections"}
				counts={{ changed: changedEntries.size() }}
				onChange={(id: string) => {
					if (id === "changed") {
						setQuery("");
					}
					Audio.play("tabSwitch");
					setChangedOnly(id === "changed");
				}}
				accent={accent}
				position={UDim2.fromOffset(chipsX, chipsY)}
				size={new UDim2(1, -chipsX, 0, Browse.CHIP_H)}
			/>
		</Panel>
	);

	const navButtons: Record<string, React.Element> = {
		layout: (
			<uilistlayout
				FillDirection={stack ? Enum.FillDirection.Horizontal : Enum.FillDirection.Vertical}
				Wraps={stack}
				Padding={new UDim(0, 6)}
				SortOrder={Enum.SortOrder.LayoutOrder}
			/>
		),
	};
	const chipW = stack ? math.floor((viewport.width - chrome.pagePadding * 2 - 24 - 12) / 3) : NAV_W - 16;
	sections.forEach((entry, index) => {
		navButtons[entry.id] = (
			<SectionButton
				section={entry}
				active={!listing && entry.id === activeSection}
				count={counts[entry.id] ?? 0}
				compact={stack}
				size={UDim2.fromOffset(chipW, stack ? TapTarget : 42)}
				layoutOrder={index + 1}
				softMotion={softMotion}
				onPick={(id) => {
					setQuery("");
					setChangedOnly(false);
					setActiveSection(id);
				}}
			/>
		);
	});
	const navRows = stack ? math.ceil(sections.size() / 3) : sections.size();
	const navH = stack ? navRows * (TapTarget + 6) + 12 : sections.size() * 48 + 16;

	const listChildren: Record<string, React.Element> = {
		layout: <uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 0)} />,
	};
	const rowH = stack ? ROW_H_STACK : ROW_H;
	let listH = 0;
	let order = 0;
	const add = (key: string, element: React.Element, height: number) => {
		order += 1;
		listChildren[key] = (
			<frame Size={new UDim2(1, 0, 0, height)} LayoutOrder={order} BackgroundTransparency={1}>
				{element}
			</frame>
		);
		listH += height;
	};
	add(
		"title",
		<>
			<Text
				value={
					searching
						? `${rows.size()} result${rows.size() === 1 ? "" : "s"} for "${query}"`
						: showChanged
							? `${rows.size()} changed setting${rows.size() === 1 ? "" : "s"}`
							: section.label
				}
				size={18}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				sizeConstraint={new UDim2(1, -110, 0, 24)}
			/>
			<Text
				value={searching ? "From every section." : showChanged ? "What you changed from the default." : section.blurb}
				size={12}
				color={Palette.muted}
				position={UDim2.fromOffset(0, 26)}
				sizeConstraint={new UDim2(1, -110, 0, 16)}
			/>
			{(!searching || showChanged) && (
				<Button
					text={showChanged ? "RESET ALL" : "RESET"}
					icon="Refresh.5"
					onClick={
						showChanged
							? () => {
									const values: Record<string, unknown> = {};
									for (const entry of changedEntries) {
										values[entry.key] = entry.default;
									}
									dispatch("SetSetting", { Values: values, Label: "Settings back to defaults." });
								}
							: resetSection
					}
					color={Palette.panelSoft}
					textColor={Palette.creamSoft}
					outline={true}
					size={UDim2.fromOffset(100, 34)}
					position={new UDim2(1, -100, 0, 4)}
					reducedMotion={softMotion}
				/>
			)}
		</>,
		56,
	);
	if (!listing && activeSection === "display") {
		const presetCells: Record<string, React.Element> = {};
		const presetCount = Schema.PRESETS.size();
		Schema.PRESETS.forEach((entry, index) => {
			presetCells[entry.id] = (
				<Button
					text={entry.label.upper()}
					onClick={() => applyPreset(entry)}
					color={preset === entry.id ? accent : Palette.panelSoft}
					textColor={preset === entry.id ? Palette.ink : Palette.creamSoft}
					outline={preset !== entry.id}
					highlight={preset === entry.id}
					size={new UDim2(1 / presetCount, -6, 1, 0)}
					position={new UDim2(index / presetCount, 3, 0, 0)}
					reducedMotion={softMotion}
				/>
			);
		});
		add(
			"presets",
			<>
				<Text
					value={preset === undefined ? "PRESET  ·  CUSTOM" : "PRESET"}
					size={11}
					color={accent}
					weight={Enum.FontWeight.Heavy}
					sizeConstraint={new UDim2(1, 0, 0, 14)}
				/>
				<frame Size={new UDim2(1, 0, 0, 38)} Position={UDim2.fromOffset(0, 18)} BackgroundTransparency={1}>
					{presetCells}
				</frame>
			</>,
			66,
		);
	}
	if (!listing) {
		// stable regroup by sub-heading so related options sit together
		const buckets = new Map<number, SchemaEntry[]>();
		const orders: number[] = [];
		for (const entry of rows) {
			const order = Schema.group(entry.key).order;
			let bucket = buckets.get(order);
			if (bucket === undefined) {
				bucket = [];
				buckets.set(order, bucket);
				orders.push(order);
			}
			bucket.push(entry);
		}
		orders.sort((a, b) => a < b);
		rows.clear();
		for (const order of orders) {
			for (const entry of buckets.get(order)!) {
				rows.push(entry);
			}
		}
	}
	let lastGroup: string | undefined;
	rows.forEach((entry, index) => {
		if (!listing) {
			const heading = Schema.group(entry.key).label;
			if (heading !== lastGroup) {
				lastGroup = heading;
				add(
					"group_" + heading,
					<Text
						value={heading.upper()}
						size={11}
						color={accent}
						weight={Enum.FontWeight.Heavy}
						position={UDim2.fromOffset(0, 10)}
						sizeConstraint={new UDim2(1, 0, 0, 14)}
					/>,
					28,
				);
			}
		}
		add(
			"row_" + entry.key,
			<SettingRow
				entry={entry}
				value={Schema.value(settings, entry.key)}
				accent={listing ? accentOf(SECTION_BY_ID[entry.section]!) : accent}
				tag={listing ? SECTION_BY_ID[entry.section]!.label : isChanged(entry) ? "changed" : undefined}
				stack={stack}
				softMotion={softMotion}
				dispatch={dispatch}
				layoutOrder={index + 1}
			/>,
			rowH,
		);
	});
	if (listing && rows.size() === 0) {
		add(
			"empty",
			<Text
				value={showChanged ? "Everything is on its default." : 'No match. Try "music" or "text".'}
				size={13}
				color={Palette.muted}
				sizeConstraint={new UDim2(1, 0, 0, 40)}
			/>,
			40,
		);
	}
	if (!listing && (hiddenAdvanced > 0 || advancedOpen[activeSection])) {
		add(
			"advanced",
			<Button
				text={advancedOpen[activeSection] ? "HIDE ADVANCED" : `SHOW ${hiddenAdvanced} ADVANCED`}
				icon={advancedOpen[activeSection] ? "Hide.1" : "Chevron.3"}
				onClick={() => {
					const nextOpen = table.clone(advancedOpen);
					nextOpen[activeSection] = !advancedOpen[activeSection];
					setAdvancedOpen(nextOpen);
				}}
				color={Palette.panelSoft}
				textColor={Palette.creamSoft}
				outline={true}
				size={new UDim2(1, 0, 0, 38)}
				position={UDim2.fromOffset(0, 12)}
				reducedMotion={softMotion}
			/>,
			58,
		);
	}
	if (!listing && activeSection === "mobile" && mobileHudAvailable) {
		add(
			"hud",
			<Button
				text="MOVE PHONE BUTTONS"
				icon="Settings.3"
				onClick={() => setMobileEdit(true)}
				color={accent}
				textColor={Palette.ink}
				size={new UDim2(1, 0, 0, TapTarget)}
				position={UDim2.fromOffset(0, 10)}
				reducedMotion={softMotion}
			/>,
			TapTarget + 14,
		);
		add(
			"tabPins",
			<MobileTabPinsEditor
				savedPins={(state.Flags ?? {}).MobileTabPins}
				dispatch={dispatch}
				accent={accent}
				stack={stack}
				softMotion={softMotion === true}
			/>,
			mobileTabPinsEditorHeight(stack),
		);
	}
	if (!listing && activeSection === "interface" && UserInputService.GamepadEnabled) {
		add(
			"controller",
			<>
				<Text
					value="CONTROLLER"
					size={11}
					color={accent}
					weight={Enum.FontWeight.Heavy}
					position={UDim2.fromOffset(0, 14)}
					sizeConstraint={new UDim2(1, 0, 0, 14)}
				/>
				<Text
					value="LB / RB pages  ·  Y vault  ·  X overcharge  ·  LT / RT amount  ·  B back  ·  Start settings"
					size={12}
					color={Palette.creamSoft}
					wrap={true}
					position={UDim2.fromOffset(0, 32)}
					sizeConstraint={new UDim2(1, 0, 0, 34)}
				/>
			</>,
			72,
		);
	}
	const list = (
		<Panel
			size={UDim2.fromScale(1, 1)}
			accent={listing ? Palette.steel : accent}
			background={Palette.panel}
			padding={stack ? 14 : 20}
			reducedMotion={softMotion}
			clips={false}
		>
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
				{listChildren}
			</frame>
		</Panel>
	);
	const listPanelH = listH + (stack ? 28 : 40);

	const scaffold: Array<{ id: string; height: number; element: React.Element }> = [{ id: "header", height: headerH, element: header }];
	if (stack) {
		scaffold.push({
			id: "sections",
			height: navH,
			element: (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
					<uipadding PaddingTop={new UDim(0, 6)} />
					{navButtons}
				</frame>
			),
		});
		scaffold.push({ id: "list", height: listPanelH, element: list });
	} else {
		const bodyH = math.max(listPanelH, navH);
		scaffold.push({
			id: "body",
			height: bodyH,
			element: (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
					<Panel size={new UDim2(0, NAV_W, 0, bodyH)} background={Palette.panelRaised} accent={accent} padding={8} reducedMotion={softMotion} clips={false}>
						{navButtons}
					</Panel>
					<frame Size={new UDim2(1, -(NAV_W + 12), 0, listPanelH)} Position={UDim2.fromOffset(NAV_W + 12, 0)} BackgroundTransparency={1}>
						{list}
					</frame>
				</frame>
			),
		});
	}

	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<PageScaffold gap={12} tailPad={scrollTail(stack, chrome.bottomSafe, 64)} scrollBarColor={accent} scrollBarThickness={4} sections={scaffold} />
			{mobileHudAvailable && (
				<MobileControls
					visible={mobileEdit}
					dispatch={dispatch}
					reducedMotion={softMotion}
					onClose={() => setMobileEdit(false)}
					slots={mobileSlots}
					savedSlots={(state.Flags ?? {}).MobileLayoutSlots}
					scales={{ quick: quickScale, dock: dockScale, toasts: toastScale }}
					opacities={{
						quick: Schema.value(settings, "MobileQuickOpacity"),
						dock: Schema.value(settings, "MobileDockOpacity"),
						toasts: Schema.value(settings, "MobileToastOpacity"),
					}}
				/>
			)}
		</frame>
	);
}

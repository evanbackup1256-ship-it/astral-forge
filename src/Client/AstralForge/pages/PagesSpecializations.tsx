// Forge Specializations: pick one of four builds that trade one forge stat for another.
//
// Layout is a fixed stack of measured sections (no text is left to grow into its neighbour):
//   hero      the equipped build and its four live stats
//   status    when you can switch next, as a meter that empties while the forge reconfigures
//   builds    one card per build: what it trades, how its stats compare with yours, equip
//   foundation bonuses kept from the retired Star Grid
import React from "@rbxts/react";
import { Bar, Chip, GlyphWell, Label, PnSurface, spaced } from "../UiCore/mockKit";
import { MockBtn, RowFace } from "./mockRows";
import { useFocusOrder } from "../CoreKit/focusOrder";
import { compactNumber } from "../CoreKit/format";
import { chromeFor, Palette, TapTarget } from "../CoreKit/theme";
import { useViewport } from "../MotionKit/motion";
import { kitMember, LuauComponent, sharedModule } from "./luauKits";

const Workspace = game.GetService("Workspace");
const Ui = kitMember<Record<string, LuauComponent>>("UiCore", "ui");
const { PageScaffold } = kitMember<{ PageScaffold: LuauComponent }>("LayoutKit", "pageScaffold");
const OmegaMath = sharedModule<{ Compare(this: void, a: unknown, b: unknown): number }>("OmegaMath");

type Flux = number | string;
interface BuildPreview {
	Id: string;
	Name: string;
	Description: string;
	Gain: string;
	Cost: string;
	GainMultiplier: number;
	CostMultiplier: number;
	Production: Flux;
	Capacity: Flux;
	Tap: Flux;
	Offline: number;
}
interface Snapshot {
	Focus: string;
	Name: string;
	Builds: BuildPreview[];
	Foundation: Array<{ Name: string; Value: number }>;
	Gain: number;
	Cost: number;
	Cooldown: number;
	ReadyAt: number;
	Production: Flux;
	Capacity: Flux;
	Tap: Flux;
	Offline: number;
}
type StatKey = "Production" | "Capacity" | "Tap" | "Offline";
interface Response {
	ok: boolean;
	Uncertain?: boolean;
	message?: string;
	error?: string;
}
interface Props {
	state: { Specialization?: Snapshot };
	reducedMotion?: boolean;
	dispatch: (action: string, payload: { Id: string }, callback: (response: Response) => void) => void;
}
interface Section {
	id: string;
	key: string;
	height: number;
	element: React.Element;
	stretch: boolean;
}

let unresolved: { Id: string } | undefined;

// how each build looks, and what its trade-off stats are called on screen
const LOOK: Record<string, { icon: string; accent: Color3; tagline: string }> = {
	Balanced: { icon: "Forge.19", accent: Palette.cyan, tagline: "Even rates, no trade-offs" },
	Handcraft: { icon: "Overcharge.6", accent: Palette.mango, tagline: "For players who tap" },
	Reserve: { icon: "Vault.5", accent: Palette.violet, tagline: "For longer gaps between collects" },
	NightShift: { icon: "Timer.5", accent: Palette.blue, tagline: "For time away from the game" },
};
const STAT_NAME: Record<string, string | undefined> = {
	Tap: "overcharge",
	Production: "production",
	Capacity: "vault size",
	Offline: "offline earnings",
};
const STATS: Array<{ key: StatKey; label: string; format: (value: Flux) => string }> = [
	{ key: "Production", label: "Production", format: (v) => compactNumber(v) + "/s" },
	{ key: "Capacity", label: "Vault", format: (v) => compactNumber(v) },
	{ key: "Tap", label: "Overcharge", format: (v) => compactNumber(v) },
	{ key: "Offline", label: "Offline", format: (v) => math.floor((tonumber(v) ?? 0) * 100 + 0.5) + "%" },
];
const GAP = 14;
const CARD_H = 268;
const CHIP_H = 28;

function lookFor(id: string) {
	return LOOK[id] ?? LOOK.Balanced;
}

function clock(seconds: number): string {
	const whole = math.max(0, math.ceil(seconds));
	return "%d:%02d".format(math.floor(whole / 60), whole % 60);
}

function chip(text: string, accent: Color3, order: number, fill?: boolean) {
	return (
		<frame
			Size={UDim2.fromOffset(0, CHIP_H)}
			AutomaticSize={fill ? Enum.AutomaticSize.None : Enum.AutomaticSize.X}
			LayoutOrder={order}
			BackgroundColor3={accent}
			BackgroundTransparency={0.8}
			BorderSizePixel={0}
		>
			<uicorner CornerRadius={new UDim(0, 8)} />
			<uistroke Color={accent} Transparency={0.4} Thickness={1} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
			<uipadding PaddingLeft={new UDim(0, 12)} PaddingRight={new UDim(0, 12)} />
			<textlabel
				Size={UDim2.fromScale(fill ? 1 : 0, 1)}
				AutomaticSize={fill ? Enum.AutomaticSize.None : Enum.AutomaticSize.X}
				BackgroundTransparency={1}
				TextTruncate={Enum.TextTruncate.AtEnd}
				Text={text}
				TextSize={13}
				TextColor3={Palette.cream}
				FontFace={new Font("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)}
			/>
		</frame>
	);
}

function chipRow(children: React.Element[], position: UDim2) {
	return (
		<frame Size={new UDim2(1, 0, 0, CHIP_H)} Position={position} BackgroundTransparency={1}>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
			{children}
		</frame>
	);
}

// one stat: small label over a value, tinted when this build raises or lowers it
function statTile(label: string, value: string, tint: Color3 | undefined, size: UDim2, position: UDim2) {
	return (
		<frame Size={size} Position={position} BackgroundColor3={Palette.white} BorderSizePixel={0}>
			<RowFace outline={tint} />
			<Ui.Text
				value={spaced(label.upper())}
				size={11}
				color={Palette.muted}
				weight={Enum.FontWeight.Bold}
				position={UDim2.fromOffset(12, 7)}
				sizeConstraint={new UDim2(1, -24, 0, 14)}
			/>
			<Ui.Text
				value={value}
				size={16}
				color={tint ?? Palette.cream}
				weight={Enum.FontWeight.Heavy}
				position={UDim2.fromOffset(12, 23)}
				sizeConstraint={new UDim2(1, -24, 0, 20)}
			/>
		</frame>
	);
}

function SpecializationsViewBoard(props: Props) {
	const state = props.state.Specialization;
	const [note, setNote] = React.useState("");
	const [busy, setBusy] = React.useState(false);
	const pending = React.useRef(false);
	const live = React.useRef(true);
	const timeout = React.useRef<thread>();
	const serial = React.useRef(0);
	const viewport = useViewport();
	const stack = chromeFor(viewport).contentStack;
	const [now, setNow] = React.useState(Workspace.GetServerTimeNow());
	React.useEffect(() => {
		live.current = true;
		return () => {
			live.current = false;
			if (timeout.current) {
				task.cancel(timeout.current);
			}
		};
	}, []);
	// tick once a second only while the forge is reconfiguring
	const readyAt = state ? state.ReadyAt : 0;
	React.useEffect(() => {
		if (readyAt <= Workspace.GetServerTimeNow()) {
			return undefined;
		}
		let alive = true;
		const ticker = task.spawn(() => {
			while (alive) {
				setNow(Workspace.GetServerTimeNow());
				if (Workspace.GetServerTimeNow() >= readyAt) {
					break;
				}
				task.wait(1);
			}
		});
		return () => {
			alive = false;
			pcall(task.cancel, ticker);
		};
	}, [readyAt]);
	const sections: Section[] = [];
	const add = (key: string, height: number, element: React.Element) => {
		sections.push({ id: key, key, height, element, stretch: false });
	};
	const selectBuild = (id: string) => {
		if (pending.current) {
			return;
		}
		const order = unresolved ?? { Id: id };
		unresolved = order;
		pending.current = true;
		serial.current += 1;
		const token = serial.current;
		setBusy(true);
		timeout.current = task.delay(20, () => {
			if (serial.current !== token) {
				return;
			}
			serial.current += 1;
			timeout.current = undefined;
			pending.current = false;
			if (live.current) {
				setBusy(false);
				setNote("No response yet. Retry to confirm the previous build change.");
			}
		});
		props.dispatch("SelectSpecialization", order, (response) => {
			if (!response.Uncertain && unresolved === order) {
				unresolved = undefined;
			}
			if (serial.current !== token) {
				return;
			}
			if (timeout.current) {
				task.cancel(timeout.current);
				timeout.current = undefined;
			}
			pending.current = false;
			if (!live.current) {
				return;
			}
			setBusy(false);
			setNote(
				response.Uncertain
					? "The change has not been confirmed. Retry before choosing another build."
					: response.ok
						? (response.message ?? "Build equipped.")
						: (response.error ?? "The build could not be changed."),
			);
		});
	};

	if (!state) {
		add(
			"loading",
			96,
			<PnSurface radius={16} rule={true} size={UDim2.fromScale(1, 1)} padding={18} accent={Palette.brass}>
				<Ui.Text value="Loading your forge build..." size={16} color={Palette.muted} sizeConstraint={new UDim2(1, 0, 0, 24)} />
			</PnSurface>,
		);
		return <PageScaffold sections={sections} gap={GAP} tailPad={72} scrollBarColor={Palette.mango} />;
	}

	const current = lookFor(state.Focus);
	const cooling = state.ReadyAt > now;
	const locked = busy || unresolved !== undefined || cooling;

	// hero: the equipped build and its live numbers
	const tileCols = stack ? 2 : 4;
	const tileRows = math.ceil(STATS.size() / tileCols);
	const tileH = 50;
	const heroTop = 78;
	const heroH = 18 + heroTop + tileRows * tileH + (tileRows - 1) * 10 + 18;
	const tiles: React.Element[] = [];
	STATS.forEach((stat, index) => {
		const col = index % tileCols;
		const row = math.floor(index / tileCols);
		tiles.push(
			statTile(
				stat.label,
				stat.format(state[stat.key]),
				undefined,
				new UDim2(1 / tileCols, -10 + 10 / tileCols, 0, tileH),
				new UDim2(col / tileCols, (col * 10) / tileCols, 0, heroTop + row * (tileH + 10)),
			),
		);
	});
	add(
		"hero",
		heroH,
		<PnSurface radius={16} rule={true} size={UDim2.fromScale(1, 1)} padding={18} accent={Palette.brass} clips={false}>
			<GlyphWell kind={current.icon} accent={current.accent} size={56} filled={true} reducedMotion={props.reducedMotion} />
			<Ui.Text
				value={spaced("EQUIPPED BUILD")}
				size={12}
				color={current.accent}
				weight={Enum.FontWeight.Heavy}
				position={UDim2.fromOffset(72, 2)}
				sizeConstraint={new UDim2(1, -72, 0, 16)}
			/>
			<Ui.Text
				value={state.Name}
				size={24}
				weight={Enum.FontWeight.Heavy}
				position={UDim2.fromOffset(72, 18)}
				sizeConstraint={new UDim2(1, -72, 0, 30)}
			/>
			<Ui.Text
				value={current.tagline}
				size={14}
				color={Palette.muted}
				position={UDim2.fromOffset(72, 48)}
				sizeConstraint={new UDim2(1, -72, 0, 18)}
			/>
			{tiles}
		</PnSurface>,
	);

	// status: switching is free, but the forge needs time to reconfigure between switches
	const remaining = math.max(0, state.ReadyAt - now);
	add(
		"status",
		92,
		<PnSurface radius={16} rule={true} size={UDim2.fromScale(1, 1)} padding={16} accent={Palette.brass}>
			<GlyphWell
				kind={cooling ? "Timer" : "Check"}
				accent={cooling ? Palette.mango : Palette.green}
				size={40}
				reducedMotion={props.reducedMotion}
			/>
			<Ui.Text
				value={cooling ? `Reconfiguring · next switch in ${clock(remaining)}` : "Ready to switch. Changing builds is free."}
				size={16}
				weight={Enum.FontWeight.Bold}
				fit={true}
				minSize={12}
				position={UDim2.fromOffset(54, 0)}
				sizeConstraint={new UDim2(1, -54, 0, 20)}
			/>
			{cooling ? (
				<Bar fill={1 - remaining / math.max(1, state.Cooldown)} color={Palette.mango} thin={true} position={UDim2.fromOffset(54, 30)} width={new UDim(1, -54)} />
			) : (
				<Ui.Text
					value={`After a switch the forge needs ${math.ceil(state.Cooldown / 60)} minutes before the next one.`}
					size={13}
					color={Palette.muted}
					wrap={true}
					fit={true}
					minSize={10}
					position={UDim2.fromOffset(54, 24)}
					sizeConstraint={new UDim2(1, -54, 0, 36)}
				/>
			)}
		</PnSurface>,
	);

	if (unresolved) {
		add(
			"retry",
			TapTarget,
			<frame key="RetryConfirm" Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
				<Ui.Button
					text="Confirm your last build change"
					size={UDim2.fromScale(1, 1)}
					color={Palette.mango}
					disabled={busy}
					reducedMotion={props.reducedMotion}
					onClick={() => selectBuild(unresolved!.Id)}
				/>
			</frame>,
		);
	}
	if (note !== "") {
		add("response", 28, <Ui.Text value={note} size={14} color={Palette.creamSoft} sizeConstraint={new UDim2(1, 0, 0, 24)} />);
	}

	// the four builds, two to a row on wide screens
	const columns = stack ? 1 : 2;
	const rows = math.ceil(state.Builds.size() / columns);
	const cards: Record<string, React.Element> = {};
	state.Builds.forEach((build, index) => {
		const look = lookFor(build.Id);
		const equipped = state.Focus === build.Id;
		const positive = math.floor((build.GainMultiplier - 1) * 100 + 0.5);
		const negative = math.floor((1 - build.CostMultiplier) * 100 + 0.5);
		const chips =
			build.Gain !== ""
				? [
						chip(`+${positive}% ${STAT_NAME[build.Gain] ?? build.Gain}`, Palette.green, 1),
						chip(`-${negative}% ${STAT_NAME[build.Cost] ?? build.Cost}`, Palette.coral, 2),
					]
				: [chip("No trade-offs", Palette.cyan, 1)];
		const compare: React.Element[] = [];
		STATS.forEach((stat, statIndex) => {
			const col = statIndex % 2;
			const row = math.floor(statIndex / 2);
			// compare with what you have now: higher reads green, lower reads red
			const [ok, order] = pcall(OmegaMath.Compare, build[stat.key], state[stat.key]);
			const tint =
				equipped || !ok ? undefined : (order as number) > 0 ? Palette.green : (order as number) < 0 ? Palette.coral : undefined;
			compare.push(
				statTile(
					stat.label,
					stat.format(build[stat.key]),
					tint,
					new UDim2(0.5, -5, 0, 44),
					new UDim2(col * 0.5, col * 5, 0, 88 + row * 50),
				),
			);
		});
		const col = index % columns;
		const row = math.floor(index / columns);
		cards[build.Id] = (
			<frame
				Size={new UDim2(1 / columns, -GAP + GAP / columns, 0, CARD_H)}
				Position={new UDim2(col / columns, (col * GAP) / columns, 0, row * (CARD_H + GAP))}
				BackgroundTransparency={1}
			>
				<PnSurface radius={16} rule={true}
					size={UDim2.fromScale(1, 1)}
					padding={16}
					accent={Palette.brass}
					clips={false}
					highlight={equipped}
					reducedMotion={props.reducedMotion}
				>
					<GlyphWell
						kind={look.icon}
						accent={look.accent}
						size={44}
						filled={equipped}
						glow={equipped && !props.reducedMotion}
						reducedMotion={props.reducedMotion}
					/>
					<Ui.Text
						value={build.Name}
						size={19}
						weight={Enum.FontWeight.Heavy}
						position={UDim2.fromOffset(58, 0)}
						sizeConstraint={new UDim2(1, -150, 0, 24)}
					/>
					<Ui.Text
						value={look.tagline}
						size={13}
						color={Palette.muted}
						position={UDim2.fromOffset(58, 25)}
						sizeConstraint={new UDim2(1, -58, 0, 18)}
					/>
					{equipped ? (
						<frame Size={UDim2.fromOffset(0, 28)} AutomaticSize={Enum.AutomaticSize.X} Position={new UDim2(1, 0, 0, 2)} AnchorPoint={new Vector2(1, 0)} BackgroundTransparency={1}>
							<Chip text="Equipped" accent={look.accent} icon="Check" />
						</frame>
					) : undefined}
					{chipRow(chips, UDim2.fromOffset(0, 54))}
					<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
						{compare}
					</frame>
					<frame key="EquipBuy" Size={new UDim2(1, 0, 0, 44)} Position={new UDim2(0, 0, 1, -44)} BackgroundTransparency={1} BorderSizePixel={0}>
						<MockBtn
							text={equipped ? "Equipped" : cooling ? `Ready in ${clock(remaining)}` : "Equip " + build.Name}
							fill={true}
							accent={look.accent}
							sec={equipped}
							phone={stack}
							disabled={locked || equipped}
							reducedMotion={props.reducedMotion}
							onClick={() => selectBuild(build.Id)}
						/>
					</frame>
				</PnSurface>
			</frame>
		);
	});
	add(
		"builds",
		rows * CARD_H + (rows - 1) * GAP,
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
			{cards}
		</frame>,
	);

	// the old Star Grid's purchased bonuses still apply to every build
	if (state.Foundation.size() > 0) {
		const chips: React.Element[] = [];
		state.Foundation.forEach((bonus, index) => {
			const percent = bonus.Value * 100;
			const shown = percent < 1000 ? "%.1f".format(percent) : compactNumber(percent);
			chips.push(chip(`${bonus.Name} +${shown}%`, Palette.creamSoft, index + 1, true));
		});
		const perRow = stack ? 2 : 4;
		const chipRows = math.ceil(chips.size() / perRow);
		add(
			"foundation",
			52 + chipRows * (CHIP_H + 8),
			<PnSurface radius={16} rule={true} size={UDim2.fromScale(1, 1)} padding={16} accent={Palette.brass}>
				<Label text="Kept from the Star Grid · every build" />
				<frame Size={new UDim2(1, 0, 0, chipRows * (CHIP_H + 8))} Position={UDim2.fromOffset(0, 26)} BackgroundTransparency={1}>
					<uigridlayout
						CellSize={new UDim2(1 / perRow, -8, 0, CHIP_H)}
						CellPadding={UDim2.fromOffset(8, 8)}
						SortOrder={Enum.SortOrder.LayoutOrder}
					/>
					{chips}
				</frame>
			</PnSurface>,
		);
	}
	add(
		"rules",
		40,
		<Ui.Text
			value="Builds change rates going forward only. Collect your vault before moving to a build with a smaller vault."
			size={13}
			color={Palette.muted}
			wrap={true}
			fit={true}
			minSize={10}
			sizeConstraint={new UDim2(1, 0, 0, 36)}
		/>,
	);
	return <PageScaffold sections={sections} gap={GAP} tailPad={72} scrollBarColor={current.accent} />;
}


function SpecializationsView(props: Props) {
	const hostRef = React.useRef<Frame>();
	useFocusOrder(
		hostRef,
		// explicit pad order: retry confirm (when shown) > builds (Equip) > the rest
		{ regions: ["hero", "status", "retry", "builds", "foundation", "rules"], first: ["retry", "builds"] },
		[props.state.Specialization !== undefined, props.state.Specialization?.Focus],
	);
	return (
		<frame ref={hostRef} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<SpecializationsViewBoard {...props} />
		</frame>
	);
}

export = () => ({ SpecializationsView });

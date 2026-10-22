// Star Grid (Forge Specializations), rebuilt on Forge2. Four builds, each trading one forge stat
// for another. The equipped build sits on top with its live numbers; the rest show only what they
// would change. Foundation bonuses kept from the retired grid close the page.
// Remote: SelectSpecialization {Id}. An unconfirmed change is retried with the SAME order until
// the server answers, so a lost reply can never switch twice.
import React from "@rbxts/react";
import { Audio } from "../../AudioKit/audio";
import { compactNumber } from "../../CoreKit/format";
import { useChangePop, useListStagger, usePulse } from "../../MotionKit/motion";
import OmegaMath = require("../../../../Shared/AstralForge/Shared/OmegaMath");
import { ForgeButton as Button } from "../design/ForgeButton";
import { EmptyState, Tooltip } from "../design/Layers";
import { Card, Meter, Panel } from "../design/Panel";
import { Text, Title } from "../design/Text";
import { Fonts, gap, Iron, Type } from "../design/tokens";
import { Burst, MotionFX } from "../motion/motion";
import type { PageProps } from "../router/routes";

const Workspace = game.GetService("Workspace");

type Flux = number | string;
interface Build {
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
	Builds: Build[];
	Foundation: Array<{ Name: string; Value: number }>;
	Cooldown: number;
	ReadyAt: number;
	Production: Flux;
	Capacity: Flux;
	Tap: Flux;
	Offline: number;
}
type StatKey = "Production" | "Capacity" | "Tap" | "Offline";

const LOOK: Record<string, { accent: () => Color3; line: string }> = {
	Balanced: { accent: Iron.steel, line: "Even rates, no trade-offs" },
	Handcraft: { accent: Iron.ember, line: "For players who tap" },
	Reserve: { accent: Iron.brass, line: "For longer gaps between collects" },
	NightShift: { accent: Iron.soft, line: "For time away from the game" },
};
const STAT_WORD: Record<string, string | undefined> = { Tap: "overcharge", Production: "production", Capacity: "vault size", Offline: "offline earnings" };
const STATS: Array<{ key: StatKey; word: string; format: (v: Flux) => string }> = [
	{ key: "Production", word: "per second", format: (v) => compactNumber(v) },
	{ key: "Capacity", word: "vault", format: (v) => compactNumber(v) },
	{ key: "Tap", word: "overcharge", format: (v) => compactNumber(v) },
	{ key: "Offline", word: "offline", format: (v) => `${math.floor((tonumber(v) ?? 0) * 100 + 0.5)}%` },
];

// survives remounts: a change the server hasn't confirmed is resent as-is
let unresolved: { Id: string } | undefined;

function lookOf(id: string) {
	return LOOK[id] ?? LOOK.Balanced;
}

function clock(seconds: number): string {
	const whole = math.max(0, math.ceil(seconds));
	return "%d:%02d".format(math.floor(whole / 60), whole % 60);
}

function Figure(props: { value: string; word: string; color?: Color3; phone: boolean; order: number; width: UDim }) {
	const pop = useChangePop(props.value);
	return (
		<frame Size={new UDim2(props.width.Scale, props.width.Offset, 0, props.phone ? 54 : 64)} BackgroundTransparency={1} LayoutOrder={props.order}>
			<uiscale Scale={pop} />
			<Text text={props.value} size={props.phone ? 22 : 28} font={Fonts.heavy} color={props.color ?? Iron.text()} box={new UDim2(1, 0, 0, props.phone ? 28 : 34)} />
			<Text text={props.word} size={Type.small(props.phone)} color={Iron.muted()} box={new UDim2(1, 0, 0, 16)} position={UDim2.fromOffset(0, props.phone ? 32 : 38)} />
		</frame>
	);
}

function BuildCard(props: { build: Build; state: Snapshot; index: number; equipped: boolean; locked: boolean; cooling: boolean; remaining: number; busy: boolean; phone: boolean; onEquip: () => void }) {
	const { build, state, phone } = props;
	const look = lookOf(build.Id);
	const accent = look.accent();
	const reveal = useListStagger(props.index);
	const glow = usePulse(props.equipped, 0.8);
	const up = math.floor((build.GainMultiplier - 1) * 100 + 0.5);
	const down = math.floor((1 - build.CostMultiplier) * 100 + 0.5);
	const deltas: React.Element[] = [];
	STATS.forEach((stat, i) => {
		const [ok, order] = pcall(OmegaMath.Compare, build[stat.key], state[stat.key]);
		const diff = ok ? (order as number) : 0;
		if (props.equipped || diff === 0) return;
		deltas.push(
			<Figure
				key={stat.key}
				value={stat.format(build[stat.key])}
				word={stat.word}
				color={diff > 0 ? Iron.brass() : Iron.ember()}
				phone={phone}
				order={i}
				width={new UDim(0.5, -8)}
			/>,
		);
	});
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.index}>
			<uiscale Scale={reveal.map((p) => 0.97 + p * 0.03)} />
			<Card accent={accent} selected={props.equipped} pad={gap(phone, "l")} spacing={gap(phone, "m")} rarity={props.equipped ? "Legendary" : undefined}>
				<frame Size={new UDim2(1, 0, 0, Type.title(phone) + 10)} BackgroundTransparency={1} LayoutOrder={0}>
					<frame Size={new UDim2(1, -30, 1, 0)} BackgroundTransparency={1}>
						<Title text={build.Name} size={Type.title(phone)} color={Iron.text().Lerp(accent, 0.2)} />
					</frame>
					{props.equipped && (
						<frame Size={UDim2.fromOffset(14, 14)} Position={new UDim2(1, -14, 0.5, -7)} BackgroundColor3={accent}>
							<uicorner CornerRadius={new UDim(1, 0)} />
							<uistroke Color={accent} Thickness={3} Transparency={glow.map((a) => 0.3 + a * 0.6)} />
						</frame>
					)}
				</frame>
				<Tooltip tip={build.Description} size={new UDim2(1, 0, 0, Type.body(phone) + 6)} order={1}>
					<Text text={look.line} size={Type.body(phone)} color={Iron.soft()} />
				</Tooltip>
				{build.Gain !== "" && (
					<Text
						text={`+${up}% ${STAT_WORD[build.Gain] ?? build.Gain}     -${down}% ${STAT_WORD[build.Cost] ?? build.Cost}`}
						size={Type.small(phone)}
						font={Fonts.heavy}
						color={accent}
						order={2}
					/>
				)}
				{deltas.size() > 0 && (
					<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={3}>
						<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
						{deltas}
					</frame>
				)}
				{!props.equipped && (
					<Button
						text={props.cooling ? clock(props.remaining) : "Equip"}
						tone="iron"
						stretch
						disabled={props.locked}
						busy={props.busy}
						onPress={props.onEquip}
						order={4}
					/>
				)}
			</Card>
		</frame>
	);
}

export function StarGridPage(props: PageProps) {
	const phone = props.phone;
	const state = (props.session as unknown as { Specialization?: Snapshot }).Specialization;
	const [now, setNow] = React.useState(Workspace.GetServerTimeNow());
	const [busy, setBusy] = React.useState(false);
	const [note, setNote] = React.useState("");
	const live = React.useRef(true);
	const pending = React.useRef(false);
	const serial = React.useRef(0);
	const timeout = React.useRef<thread>();
	React.useEffect(() => () => {
		live.current = false;
		if (timeout.current) pcall(task.cancel, timeout.current);
	}, []);
	const readyAt = state?.ReadyAt ?? 0;
	React.useEffect(() => {
		if (readyAt <= Workspace.GetServerTimeNow()) return undefined;
		let alive = true;
		const ticker = task.spawn(() => {
			while (alive) {
				setNow(Workspace.GetServerTimeNow());
				if (Workspace.GetServerTimeNow() >= readyAt) break;
				task.wait(1);
			}
		});
		return () => {
			alive = false;
			pcall(task.cancel, ticker);
		};
	}, [readyAt]);

	const chooseBuild = (id: string) => {
		if (pending.current) return;
		const order = unresolved ?? { Id: id };
		unresolved = order;
		pending.current = true;
		serial.current += 1;
		const token = serial.current;
		setBusy(true);
		timeout.current = task.delay(20, () => {
			if (serial.current !== token) return;
			serial.current += 1;
			timeout.current = undefined;
			pending.current = false;
			if (live.current) {
				setBusy(false);
				setNote("No answer yet. Press again to confirm the last change.");
			}
		});
		props.request("SelectSpecialization", order, (reply) => {
			const uncertain = reply.Uncertain === true;
			if (!uncertain && unresolved === order) unresolved = undefined;
			if (serial.current !== token) return;
			if (timeout.current) {
				pcall(task.cancel, timeout.current);
				timeout.current = undefined;
			}
			pending.current = false;
			if (!live.current) return;
			setBusy(false);
			setNote(uncertain ? "Not confirmed yet. Press again before picking another." : "");
			if (reply.ok === true) {
				Audio.play("successChime");
				Burst.spark(lookOf(id).accent(), 1);
				MotionFX.play("modeSwitch");
			}
		});
	};

	const space = gap(phone, "l");
	if (state === undefined) {
		return (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
				<uipadding PaddingTop={new UDim(0, space)} PaddingLeft={new UDim(0, space)} PaddingRight={new UDim(0, space)} />
				<EmptyState title="Warming the forge" phone={phone} />
			</frame>
		);
	}
	const look = lookOf(state.Focus);
	const cooling = state.ReadyAt > now;
	const remaining = math.max(0, state.ReadyAt - now);
	const locked = busy || unresolved !== undefined || cooling;
	const figureWidth = phone ? new UDim(0.5, -8) : new UDim(0.25, -8);
	return (
		<scrollingframe
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			CanvasSize={new UDim2()}
			AutomaticCanvasSize={Enum.AutomaticSize.Y}
			ScrollBarThickness={phone ? 0 : 4}
			ScrollBarImageColor3={Iron.brassDeep()}
		>
			<uipadding PaddingTop={new UDim(0, space)} PaddingBottom={new UDim(0, space * 3 + props.chrome.bottomSafe)} PaddingLeft={new UDim(0, space)} PaddingRight={new UDim(0, space)} />
			<uilistlayout Padding={new UDim(0, gap(phone, "xl"))} SortOrder={Enum.SortOrder.LayoutOrder} />

			<Panel pad={gap(phone, "xl")} spacing={gap(phone, "l")} seam order={0}>
				<Title text={state.Name} size={Type.hero(phone)} color={Iron.text().Lerp(look.accent(), 0.25)} order={0} />
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
					{STATS.map((stat, i) => (
						<Figure key={stat.key} value={stat.format(state[stat.key])} word={stat.word} phone={phone} order={i} width={figureWidth} />
					))}
				</frame>
				{cooling && (
					<Tooltip tip={`After a switch the forge needs ${math.ceil(state.Cooldown / 60)} minutes before the next one.`} size={new UDim2(1, 0, 0, 30)} order={2}>
						<Meter value={1 - remaining / math.max(1, state.Cooldown)} color={look.accent()} height={6} />
						<Text text={clock(remaining)} size={Type.small(phone)} color={Iron.muted()} align="Right" position={UDim2.fromOffset(0, 12)} />
					</Tooltip>
				)}
				{note !== "" && <Text text={note} size={Type.small(phone)} color={Iron.ember()} multiline order={3} />}
			</Panel>

			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
				<uilistlayout Padding={new UDim(0, gap(phone, "m"))} SortOrder={Enum.SortOrder.LayoutOrder} />
				{state.Builds.map((build, i) => (
					<BuildCard
						key={build.Id}
						build={build}
						state={state}
						index={i}
						equipped={build.Id === state.Focus}
						locked={locked}
						cooling={cooling}
						remaining={remaining}
						busy={busy}
						phone={phone}
						onEquip={() => chooseBuild(build.Id)}
					/>
				))}
			</frame>

			{state.Foundation.size() > 0 && (
				<Panel pad={gap(phone, "l")} spacing={gap(phone, "s")} order={2}>
					<Text text="kept from the grid, on every build" size={Type.small(phone)} color={Iron.muted()} order={0} />
					<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
						<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
						{state.Foundation.map((bonus, i) => (
							<Figure key={bonus.Name} value={`+${math.floor(bonus.Value * 1000 + 0.5) / 10}%`} word={bonus.Name.lower()} color={Iron.brass()} phone={phone} order={i} width={new UDim(0, phone ? 120 : 150)} />
						))}
					</frame>
				</Panel>
			)}
			<Text text="Builds change rates from now on. Collect first before moving to a smaller vault." size={Type.small(phone)} color={Iron.muted()} multiline order={3} />
		</scrollingframe>
	);
}

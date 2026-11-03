// The Reaches: mine ore from three regions and fight the Rift Warden with everyone in the server.
// Mining: each region has seven outcrops; hold one to break it loose, and it grows back over 90 seconds.
// The Warden: one health bar for the whole server (read live from ReplicatedStorage.AstralForgeWarden). Tap to
// strike; every so often it winds up a slam, and a strike thrown into the wind-up gets you stunned. Ore buys the
// five foundry upgrades at the bottom, which are permanent.
import React from "@rbxts/react";
import * as Reaches from "../../../../Shared/AstralForge/Shared/Reaches";
import { compactNumber } from "../../CoreKit/format";
import { chromeFor, Palette } from "../../CoreKit/theme";
import { useEntrance, useFlash, usePulse, useViewport } from "../../MotionKit/motion";
import { useServerClock } from "../../hooks/useServerClock";
import { ART } from "../../ArtKit/ArtAssets";
import { ScreenFx } from "../../UiCore/screenFx";
import { HoldButton } from "../PagesSystem/AdminParts";
import { loadAudio, loadPageScaffold, loadUi } from "../luauDeps";

const ReplicatedStorage = game.GetService("ReplicatedStorage");
const Workspace = game.GetService("Workspace");
const { Button, Meter, Panel, SegmentedTabs, Text } = loadUi();
const PageScaffold = loadPageScaffold();

interface Reply {
	ok?: boolean;
	message?: string;
	error?: string;
	Amount?: number;
	Ore?: string;
	Node?: string;
	RegrowAt?: number;
	Damage?: number;
	Crit?: boolean;
	Felled?: boolean;
	Caught?: boolean;
	Stunned?: boolean;
	StunnedUntil?: number;
}
type Dispatch = (action: string, payload?: object, callback?: (response: Reply) => void) => unknown;

interface UpgradeRow {
	Id: string;
	Name: string;
	Description: string;
	Level: number;
	MaxLevel: number;
	Bonus: number;
	NextBonus: number;
	Cost: Record<string, number>;
	Affordable: boolean;
	Maxed: boolean;
}

interface Props {
	state: {
		Rebirths?: number;
		Ore?: Record<string, number>;
		Stats?: Record<string, number>;
		Reaches?: {
			Forge?: { Upgrades?: UpgradeRow[] };
			Warden?: { YourDamage?: number; YourStrikes?: number; Fighters?: number; StunnedUntil?: number };
			Depleted?: Record<string, number>;
		};
	};
	dispatch: Dispatch;
	reducedMotion?: boolean;
}

const PAD = 20;
const GAP = 14;
const REGROW = 90;
const rgb = (triple: [number, number, number]) => Color3.fromRGB(triple[0], triple[1], triple[2]);
const ORE_COLOR: Record<string, Color3> = {};
for (const entry of Reaches.REGIONS) ORE_COLOR[entry.Ore] = rgb(entry.Glow);

function clock(seconds: number): string {
	const whole = math.max(0, math.ceil(seconds));
	return `${math.floor(whole / 60)}:${string.format("%02d", whole % 60)}`;
}

// ── the Warden's live state ────────────────────────────────────────────────────

interface WardenLive {
	State: string;
	Hp: number;
	MaxHp: number;
	RespawnAt: number;
	SlamFrom: number;
	SlamAt: number;
}

function readBoard(board: Instance): WardenLive {
	return {
		State: tostring(board.GetAttribute("State") ?? "Active"),
		Hp: tonumber(board.GetAttribute("Hp")) ?? 0,
		MaxHp: tonumber(board.GetAttribute("MaxHp")) ?? 1,
		RespawnAt: tonumber(board.GetAttribute("RespawnAt")) ?? 0,
		SlamFrom: tonumber(board.GetAttribute("SlamFrom")) ?? 0,
		SlamAt: tonumber(board.GetAttribute("SlamAt")) ?? 0,
	};
}

function useWarden(): WardenLive | undefined {
	const [snapshot, setSnapshot] = React.useState<WardenLive>();
	React.useEffect(() => {
		let alive = true;
		let connection: RBXScriptConnection | undefined;
		task.spawn(() => {
			const board = ReplicatedStorage.WaitForChild("AstralForgeWarden", 30);
			if (!alive || board === undefined) {
				return;
			}
			setSnapshot(readBoard(board));
			connection = board.AttributeChanged.Connect(() => setSnapshot(readBoard(board)));
		});
		return () => {
			alive = false;
			connection?.Disconnect();
		};
	}, []);
	return snapshot;
}

// ── small pieces ───────────────────────────────────────────────────────────────

/** A number that rises off its spot and fades, then removes itself. */
function Popup(p: { text: string; color: Color3; big?: boolean; x: number; reducedMotion?: boolean }) {
	const enter = useEntrance(p.reducedMotion === true);
	return (
		<textlabel
			AnchorPoint={new Vector2(0.5, 1)}
			Size={UDim2.fromOffset(p.big === true ? 200 : 150, p.big === true ? 34 : 24)}
			Position={enter.map((value) => new UDim2(p.x, 0, 0.5, -value * 46))}
			BackgroundTransparency={1}
			Text={p.text}
			TextColor3={p.color}
			TextSize={p.big === true ? 26 : 18}
			FontFace={Font.fromEnum(Enum.Font.BuilderSansExtraBold)}
			TextStrokeTransparency={enter.map((value) => 0.4 + value * 0.6)}
			TextTransparency={enter.map((value) => math.clamp(value * 1.2 - 0.2, 0, 1))}
			ZIndex={20}
		/>
	);
}

interface Pop {
	key: number;
	text: string;
	color: Color3;
	big: boolean;
	x: number;
}

function usePops(): [Pop[], (text: string, color: Color3, big?: boolean) => void] {
	const [pops, setPops] = React.useState<Pop[]>([]);
	const counter = React.useRef(0);
	const add = (text: string, color: Color3, big = false) => {
		counter.current += 1;
		const key = counter.current;
		const x = 0.35 + math.random() * 0.3;
		setPops((list) => {
			const kept = list.size() >= 6 ? list.filter((_, index) => index > 0) : list;
			return [...kept, { key, text, color, big, x }];
		});
		task.delay(1.1, () => setPops((list) => list.filter((entry) => entry.key !== key)));
	};
	return [pops, add];
}

const ORE_ART: Record<string, [string, string]> = {
	Emberite: [ART.OreEmberite, ART.OreEmberiteSpent],
	Voidglass: [ART.OreVoidglass, ART.OreVoidglassSpent],
	Starsteel: [ART.OreStarsteel, ART.OreStarsteelSpent],
};

/** An outcrop as its specimen plate: the mined-out plate underneath, the full one fading back in as it regrows. */
function OutcropArt(p: { ore: string; grown: number; flash: React.Binding<number> }) {
	const [full, spent] = ORE_ART[p.ore] ?? ORE_ART.Emberite;
	const grown = math.clamp(p.grown, 0, 1);
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
			<uiscale Scale={p.flash.map((value) => 1 + value * 0.08)} />
			<imagelabel Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} Image={spent} ScaleType={Enum.ScaleType.Fit} ImageTransparency={grown >= 1 ? 1 : 0} />
			<imagelabel Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} Image={full} ScaleType={Enum.ScaleType.Fit} ImageTransparency={grown >= 1 ? 0 : 1 - grown * 0.55} />
		</frame>
	);
}

function OutcropTile(p: {
	entry: Reaches.Region;
	index: number;
	open: boolean;
	regrowAt: number;
	now: number;
	busy: boolean;
	reducedMotion?: boolean;
	onMine: () => void;
	hitToken: number;
	layoutOrder: number;
}) {
	const color = rgb(p.entry.Glow);
	const left = p.regrowAt - p.now;
	const ready = left <= 0;
	const flash = useFlash(p.hitToken, p.reducedMotion, 0.3);
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.ink} BorderSizePixel={0} LayoutOrder={p.layoutOrder}>
			<uicorner CornerRadius={new UDim(0, 12)} />
			<uistroke Color={color} Thickness={1} Transparency={ready && p.open ? 0.45 : 0.85} />
			<frame Size={new UDim2(1, -8, 0, 88)} Position={UDim2.fromOffset(4, 0)} BackgroundTransparency={1}>
				<OutcropArt ore={p.entry.Ore} grown={ready ? 1 : 1 - left / REGROW} flash={flash} />
			</frame>
			<Text
				value={!p.open ? "Locked" : ready ? "Hold to mine" : `Regrows in ${clock(left)}`}
				size={12}
				color={!p.open ? Palette.muted : ready ? Palette.cream : Palette.creamSoft}
				weight={Enum.FontWeight.Heavy}
				align={Enum.TextXAlignment.Center}
				position={UDim2.fromOffset(6, 88)}
				sizeConstraint={new UDim2(1, -12, 0, 16)}
				fit={true}
				minSize={11}
			/>
			{ready && p.open ? (
				<HoldButton text="MINE" color={color} seconds={1.1} size={new UDim2(1, -16, 0, 44)} position={new UDim2(0, 8, 1, -52)} disabled={p.busy} reducedMotion={p.reducedMotion} onComplete={p.onMine} />
			) : (
				<Meter value={p.open ? 1 - math.max(0, left) / REGROW : 0} color={color} position={new UDim2(0, 10, 1, -26)} size={new UDim2(1, -20, 0, 6)} reducedMotion={p.reducedMotion} />
			)}
		</frame>
	);
}

/** The Warden as its bestiary plate: idle, winding up a slam (the engraved ring pulses behind it), or felled. */
function WardenSigil(p: { share: number; windup: boolean; down: boolean; hitToken: number; reducedMotion?: boolean }) {
	const hit = useFlash(p.hitToken, p.reducedMotion, 0.35);
	const pulse = usePulse(p.windup, 4);
	const image = p.down ? ART.WardenDown : p.windup ? ART.WardenWindup : ART.WardenIdle;
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
			<uiaspectratioconstraint AspectRatio={1} />
			{p.windup && (
				<imagelabel
					AnchorPoint={new Vector2(0.5, 0.5)}
					Position={UDim2.fromScale(0.5, 0.52)}
					Size={pulse.map((value) => UDim2.fromScale(0.86 + value * 0.22, 0.86 + value * 0.22))}
					BackgroundTransparency={1}
					Image={ART.BootShockwave}
					ImageColor3={Palette.coral}
					ImageTransparency={pulse.map((value) => 0.15 + value * 0.45)}
				/>
			)}
			<imagelabel
				AnchorPoint={new Vector2(0.5, 0.5)}
				Position={hit.map((value) => new UDim2(0.5, math.sin(value * 30) * 7 * value, 0.5, -value * 4))}
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				Image={image}
				ScaleType={Enum.ScaleType.Fit}
				ImageColor3={hit.map((value) => new Color3(1, 1, 1).Lerp(Palette.cream, value))}
				ZIndex={2}
			/>
		</frame>
	);
}

function UpgradeRowView(p: { row: UpgradeRow; busy: boolean; onBuy: () => void; layoutOrder: number }) {
	const row = p.row;
	const percent = (value: number) => `${math.floor(value * 1000 + 0.5) / 10}%`;
	const costParts: string[] = [];
	let firstOre = "Emberite";
	for (const [ore, amount] of pairs(row.Cost)) {
		if (costParts.size() === 0) firstOre = ore as string;
		costParts.push(`${compactNumber(amount)} ${ore}`);
	}
	const accent = ORE_COLOR[firstOre] ?? Palette.mango;
	return (
		<frame Size={new UDim2(1, 0, 0, UPGRADE_ROW - 8)} BackgroundColor3={Palette.panelRaised} BorderSizePixel={0} LayoutOrder={p.layoutOrder}>
			<uicorner CornerRadius={new UDim(0, 10)} />
			<frame Size={new UDim2(0, 4, 1, -18)} Position={UDim2.fromOffset(0, 9)} BackgroundColor3={accent} BorderSizePixel={0} />
			<Text value={`${row.Name}  ·  level ${row.Level} of ${row.MaxLevel}`} size={14} color={Palette.cream} weight={Enum.FontWeight.Heavy} position={UDim2.fromOffset(16, 10)} sizeConstraint={new UDim2(1, -190, 0, 19)} fit={true} minSize={11} />
			<Text value={row.Description} size={12} color={Palette.muted} position={UDim2.fromOffset(16, 31)} sizeConstraint={new UDim2(1, -190, 0, 16)} fit={true} minSize={11} />
			<Text
				value={row.Maxed ? `Now +${percent(row.Bonus)}  ·  maxed` : `Now +${percent(row.Bonus)}  →  +${percent(row.NextBonus)}  ·  costs ${costParts.join(", ")}`}
				size={12}
				color={row.Maxed ? Palette.mint : row.Affordable ? accent : Palette.creamSoft}
				weight={Enum.FontWeight.Heavy}
				position={UDim2.fromOffset(16, 50)}
				sizeConstraint={new UDim2(1, -190, 0, 16)}
				fit={true}
				minSize={11}
			/>
			<Button
				text={row.Maxed ? "MAXED" : "UPGRADE"}
				onClick={p.onBuy}
				color={row.Affordable ? accent : Palette.panelSoft}
				textColor={row.Affordable ? Palette.ink : Palette.muted}
				size={UDim2.fromOffset(150, 44)}
				position={new UDim2(1, -164, 0.5, -22)}
				disabled={p.busy || row.Maxed || !row.Affordable}
			/>
		</frame>
	);
}

const UPGRADE_ROW = 84;
const TILE_H = 160;
const WARDEN_H = 300;

// ── the page ───────────────────────────────────────────────────────────────────

function ReachesView(props: Props) {
	const viewport = useViewport();
	const stack = chromeFor(viewport).contentStack;
	const Audio = React.useMemo(() => loadAudio(), []);
	const [busy, setBusy] = React.useState(false);
	const [regionId, setRegionId] = React.useState(Reaches.REGIONS[0].Id);
	const [mined, setMined] = React.useState<Record<string, number>>({});
	const [hits, setHits] = React.useState<Record<string, number>>({});
	const [stunnedUntil, setStunnedUntil] = React.useState(0);
	const [strikeToken, setStrikeToken] = React.useState(0);
	const [note, setNote] = React.useState<{ text: string; ok: boolean }>();
	const [minePops, addMinePop] = usePops();
	const [strikePops, addStrikePop] = usePops();
	const warden = useWarden();
	const serverNow = Workspace.GetServerTimeNow();
	const windup = warden !== undefined && warden.SlamAt > serverNow;
	const now = useServerClock(true, windup || stunnedUntil > serverNow ? 0.1 : 1);
	const balances = props.state.Ore ?? {};
	const stats = props.state.Stats ?? {};
	const reaches = props.state.Reaches ?? {};
	const rebirths = props.state.Rebirths ?? 0;
	const fight = reaches.Warden ?? {};
	const entry = Reaches.region(regionId) ?? Reaches.REGIONS[0];
	const open = Reaches.regionOpen(entry, rebirths);
	const down = warden?.State === "Down";
	const stunned = math.max(stunnedUntil, fight.StunnedUntil ?? 0) > now;

	// the server's depletion list, overlaid with what this page has mined since the last push
	const regrowAt = (id: string) => math.max(reaches.Depleted?.[id] ?? 0, mined[id] ?? 0);

	const mine = (index: number) => {
		const node = Reaches.nodeId(entry, index);
		props.dispatch("OreAct", { Op: "Mine", Node: node }, (reply) => {
			if (reply.ok === true) {
				Audio.play("toastSuccess");
				setMined((previous) => ({ ...previous, [node]: reply.RegrowAt ?? Workspace.GetServerTimeNow() + REGROW }));
				setHits((previous) => ({ ...previous, [node]: (previous[node] ?? 0) + 1 }));
				addMinePop(`+${reply.Amount ?? 0} ${reply.Ore ?? entry.Ore}`, rgb(entry.Glow));
			} else {
				setNote({ text: reply.error ?? reply.message ?? "That didn't work.", ok: false });
			}
		});
	};

	const strike = () => {
		props.dispatch("OreAct", { Op: "Strike" }, (reply) => {
			if (reply.ok === true) {
				setStrikeToken((token) => token + 1);
				const crit = reply.Crit === true;
				addStrikePop(crit ? `CRIT ${string.format("%.1f", reply.Damage ?? 0)}` : string.format("%.1f", reply.Damage ?? 0), crit ? Palette.mango : Palette.cream, crit);
				Audio.play(crit ? "domainImpact" : "click");
				if (reply.Felled === true) {
					ScreenFx.play("milestone", 1.1);
				}
			} else if (reply.Caught === true) {
				setStunnedUntil(reply.StunnedUntil ?? Workspace.GetServerTimeNow() + Reaches.WARDEN.StunSeconds);
				addStrikePop("CAUGHT BY THE SLAM", Palette.coral, true);
				ScreenFx.play("warning", 0.9);
			}
		});
	};

	const send = (payload: object, onOk?: () => void) => {
		if (busy) return;
		setBusy(true);
		props.dispatch("OreAct", payload, (reply) => {
			setBusy(false);
			const ok = reply.ok === true;
			setNote({ text: ok ? (reply.message ?? "Done.") : (reply.error ?? reply.message ?? "That didn't work."), ok });
			if (ok && onOk !== undefined) onOk();
		});
	};

	const sections: { id: string; height: number; element: React.Element }[] = [];

	// ── header: what you carry ────────────────────────────────────────────────
	sections.push({
		id: "head",
		height: stack ? 214 : 128,
		element: (
			<Panel size={UDim2.fromScale(1, 1)} accent={Palette.mango} background={Palette.panelRaised} padding={PAD}>
				<Text value="THE REACHES" size={11} color={Palette.mango} weight={Enum.FontWeight.Heavy} sizeConstraint={new UDim2(1, 0, 0, 15)} />
				<Text value="Ore, and the thing guarding it" size={22} color={Palette.cream} weight={Enum.FontWeight.Heavy} position={UDim2.fromOffset(0, 18)} sizeConstraint={new UDim2(stack ? 1 : 0.5, 0, 0, 28)} fit={true} minSize={14} />
				<Text
					value={note !== undefined ? note.text : `${compactNumber(stats.OreMined ?? 0)} ore mined  ·  ${compactNumber(stats.WardenDefeats ?? 0)} Wardens felled`}
					size={13}
					color={note === undefined ? Palette.muted : note.ok ? Palette.mint : Palette.coral}
					weight={note === undefined ? Enum.FontWeight.Medium : Enum.FontWeight.Heavy}
					position={UDim2.fromOffset(0, 52)}
					sizeConstraint={new UDim2(stack ? 1 : 0.5, -12, 0, 18)}
					fit={true}
					minSize={11}
				/>
				<frame Size={stack ? new UDim2(1, 0, 0, 66) : new UDim2(0.5, -12, 0, 66)} Position={stack ? UDim2.fromOffset(0, 86) : new UDim2(0.5, 12, 0, 6)} BackgroundTransparency={1}>
					<uigridlayout CellSize={new UDim2(1 / 3, -9, 1, 0)} CellPadding={UDim2.fromOffset(12, 0)} SortOrder={Enum.SortOrder.LayoutOrder} />
					{Reaches.REGIONS.map((region, index) => {
						const color = rgb(region.Glow);
						return (
							<frame key={region.Ore} BackgroundColor3={Palette.ink} BorderSizePixel={0} LayoutOrder={index}>
								<uicorner CornerRadius={new UDim(0, 10)} />
								<uistroke Color={color} Thickness={1} Transparency={0.65} />
								<frame Size={new UDim2(0, 3, 1, -16)} Position={UDim2.fromOffset(0, 8)} BackgroundColor3={color} BorderSizePixel={0} />
								<Text value={string.upper(region.Ore)} size={11} color={Palette.muted} weight={Enum.FontWeight.Heavy} position={UDim2.fromOffset(14, 8)} sizeConstraint={new UDim2(1, -22, 0, 15)} fit={true} minSize={11} />
								<Text value={compactNumber(balances[region.Ore] ?? 0)} size={22} color={color} weight={Enum.FontWeight.Heavy} position={UDim2.fromOffset(14, 25)} sizeConstraint={new UDim2(1, -22, 0, 28)} fit={true} minSize={12} />
							</frame>
						);
					})}
				</frame>
			</Panel>
		),
	});

	// ── mining ────────────────────────────────────────────────────────────────
	const columns = stack ? 3 : 7;
	const rows = math.ceil(Reaches.NODES_PER_REGION / columns);
	const color = rgb(entry.Glow);
	const tiles: React.Element[] = [];
	for (let i = 1; i <= Reaches.NODES_PER_REGION; i++) {
		const id = Reaches.nodeId(entry, i);
		tiles.push(
			<OutcropTile
				key={id}
				entry={entry}
				index={i}
				open={open}
				regrowAt={regrowAt(id)}
				now={now}
				busy={false}
				reducedMotion={props.reducedMotion}
				onMine={() => mine(i)}
				hitToken={hits[id] ?? 0}
				layoutOrder={i}
			/>,
		);
	}
	let readyCount = 0;
	for (let i = 1; i <= Reaches.NODES_PER_REGION; i++) {
		if (regrowAt(Reaches.nodeId(entry, i)) <= now) readyCount += 1;
	}
	sections.push({
		id: "mine",
		height: PAD * 2 + 52 + 48 + rows * TILE_H + (rows - 1) * 10,
		element: (
			<Panel size={UDim2.fromScale(1, 1)} accent={color} background={Palette.panel} padding={PAD}>
				<SegmentedTabs
					options={Reaches.REGIONS.map((region) => ({ id: region.Id, label: string.upper(region.Name) }))}
					value={regionId}
					onChange={(id: string) => setRegionId(id)}
					accent={color}
					columns={3}
					gap={4}
					size={new UDim2(1, 0, 0, 44)}
					reducedMotion={props.reducedMotion}
				/>
				<Text value={entry.Tagline} size={13} color={Palette.creamSoft} position={UDim2.fromOffset(0, 56)} sizeConstraint={new UDim2(stack ? 1 : 0.65, 0, 0, 18)} fit={true} minSize={11} />
				<Text
					value={open ? `${readyCount} of ${Reaches.NODES_PER_REGION} ready  ·  each grows back in 90s` : `Opens at ${entry.MinRebirths} rebirth${entry.MinRebirths === 1 ? "" : "s"}`}
					size={13}
					color={open ? color : Palette.coral}
					weight={Enum.FontWeight.Heavy}
					align={stack ? Enum.TextXAlignment.Left : Enum.TextXAlignment.Right}
					position={stack ? UDim2.fromOffset(0, 76) : new UDim2(0.65, 0, 0, 56)}
					sizeConstraint={stack ? new UDim2(1, 0, 0, 18) : new UDim2(0.35, 0, 0, 18)}
					fit={true}
					minSize={11}
				/>
				<frame Size={new UDim2(1, 0, 1, -100)} Position={UDim2.fromOffset(0, 100)} BackgroundTransparency={1}>
					<uigridlayout
						CellSize={new UDim2(1 / columns, -(10 * (columns - 1)) / columns - 1, 0, TILE_H)}
						CellPadding={UDim2.fromOffset(10, 10)}
						SortOrder={Enum.SortOrder.LayoutOrder}
					/>
					{tiles}
				</frame>
				<frame Size={new UDim2(1, 0, 0, 0)} Position={UDim2.fromOffset(0, 100)} BackgroundTransparency={1} ZIndex={20}>
					{minePops.map((pop) => (
						<Popup key={`m${pop.key}`} text={pop.text} color={pop.color} big={pop.big} x={pop.x} reducedMotion={props.reducedMotion} />
					))}
				</frame>
			</Panel>
		),
	});

	// ── the Rift Warden ───────────────────────────────────────────────────────
	const share = warden !== undefined && warden.MaxHp > 0 ? warden.Hp / warden.MaxHp : 0;
	const slamIn = warden !== undefined ? warden.SlamAt - now : 0;
	const stunLeft = math.max(stunnedUntil, fight.StunnedUntil ?? 0) - now;
	const status =
		warden === undefined
			? "Finding the Rift…"
			: down
				? `Felled. It re-forms in ${clock(warden.RespawnAt - now)}.`
				: windup
					? `BRACE! The slam lands in ${string.format("%.1f", math.max(0, slamIn))}s. Don't strike.`
					: stunned
						? `Stunned for ${string.format("%.1f", math.max(0, stunLeft))}s`
						: `${math.ceil(warden.Hp)} of ${warden.MaxHp} left${(fight.Fighters ?? 0) > 1 ? `  ·  ${fight.Fighters} fighting` : ""}`;
	const sigilSize = stack ? 150 : 220;
	sections.push({
		id: "warden",
		height: stack ? WARDEN_H + 170 : WARDEN_H,
		element: (
			<Panel size={UDim2.fromScale(1, 1)} accent={windup ? Palette.coral : Palette.violet} background={Palette.panel} padding={PAD} highlight={windup}>
				<frame
					Size={UDim2.fromOffset(sigilSize, sigilSize)}
					Position={stack ? new UDim2(0.5, -sigilSize / 2, 0, 0) : UDim2.fromOffset(10, (WARDEN_H - PAD * 2 - sigilSize) / 2)}
					BackgroundTransparency={1}
				>
					<WardenSigil share={share} windup={windup} down={down} hitToken={strikeToken} reducedMotion={props.reducedMotion} />
					{strikePops.map((pop) => (
						<Popup key={`s${pop.key}`} text={pop.text} color={pop.color} big={pop.big} x={pop.x} reducedMotion={props.reducedMotion} />
					))}
				</frame>
				<frame
					Size={stack ? new UDim2(1, 0, 0, WARDEN_H - PAD * 2 - 6) : new UDim2(1, -(sigilSize + 40), 1, 0)}
					Position={stack ? UDim2.fromOffset(0, sigilSize + 16) : UDim2.fromOffset(sigilSize + 40, 0)}
					BackgroundTransparency={1}
				>
					<Text value="THE RIFT WARDEN  ·  EVERYONE IN THE SERVER FIGHTS THE SAME ONE" size={11} color={windup ? Palette.coral : Palette.violet} weight={Enum.FontWeight.Heavy} sizeConstraint={new UDim2(1, 0, 0, 15)} fit={true} minSize={11} />
					<Text value={status} size={20} color={windup ? Palette.coral : down ? Palette.mint : Palette.cream} weight={Enum.FontWeight.Heavy} position={UDim2.fromOffset(0, 20)} sizeConstraint={new UDim2(1, 0, 0, 28)} fit={true} minSize={12} />
					<Meter value={down ? 0 : share} color={share < 0.25 ? Palette.coral : Palette.violet} position={UDim2.fromOffset(0, 56)} size={new UDim2(1, 0, 0, 12)} reducedMotion={props.reducedMotion} />
					<Text
						value={`Your part: ${fight.YourStrikes ?? 0} strikes, ${string.format("%.1f", fight.YourDamage ?? 0)} damage. ${Reaches.WARDEN.MinStrikes} strikes earn a share of the Starsteel; whoever hits hardest gets 3 more.`}
						size={12}
						color={Palette.creamSoft}
						wrap={true}
						fit={true}
						minSize={11}
						position={UDim2.fromOffset(0, 80)}
						sizeConstraint={new UDim2(1, 0, 0, 34)}
					/>
					<Text
						value="It winds up a slam every so often: the ring turns red. Strike into it and you're stunned for two seconds."
						size={12}
						color={Palette.muted}
						wrap={true}
						fit={true}
						minSize={11}
						position={UDim2.fromOffset(0, 118)}
						sizeConstraint={new UDim2(1, 0, 0, 34)}
					/>
					<Button
						text={down ? "RE-FORMING" : stunned ? "STUNNED" : windup ? "BRACE…" : "STRIKE"}
						onClick={strike}
						color={windup ? Palette.coral : Palette.violet}
						textColor={Palette.ink}
						size={new UDim2(1, 0, 0, 64)}
						position={new UDim2(0, 0, 1, -64)}
						disabled={down || stunned || warden === undefined}
						highlight={!down && !stunned && !windup}
						reducedMotion={props.reducedMotion}
					/>
				</frame>
			</Panel>
		),
	});

	// ── the ore foundry ───────────────────────────────────────────────────────
	const upgrades = reaches.Forge?.Upgrades ?? [];
	sections.push({
		id: "forge",
		height: PAD * 2 + 22 + upgrades.size() * UPGRADE_ROW,
		element: (
			<Panel size={UDim2.fromScale(1, 1)} accent={Palette.mango} background={Palette.panel} padding={PAD}>
				<Text value="ORE FOUNDRY  ·  PERMANENT UPGRADES" size={11} color={Palette.mango} weight={Enum.FontWeight.Heavy} sizeConstraint={new UDim2(1, 0, 0, 15)} />
				<frame Size={new UDim2(1, 0, 1, -22)} Position={UDim2.fromOffset(0, 22)} BackgroundTransparency={1}>
					<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 8)} />
					{upgrades.map((row, index) => (
						<UpgradeRowView key={row.Id} row={row} busy={busy} layoutOrder={index} onBuy={() => send({ Op: "Buy", Upgrade: row.Id }, () => ScreenFx.play("success", 0.8))} />
					))}
				</frame>
			</Panel>
		),
	});
	return <PageScaffold sections={sections} gap={16} tailPad={stack ? 12 : 18} owner="ReachesView" />;
}

export = { ReachesView };

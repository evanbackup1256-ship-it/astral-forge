import React from "@rbxts/react";
import Tools = require("../../UpgradeTools");
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { useStagger, useViewport } from "../../MotionKit/motion";
import { chromeFor, darken, Palette, TapTarget } from "../../CoreKit/theme";
import { bulkCost, compactNumber, compareFlux, Flux, gteFlux } from "../../CoreKit/format";
import { AppHelpers, NavState, UpgradeConfig, UpgradeEntry } from "../../CoreKit/appNav";
import { asFlux } from "../../CoreKit/format";
import * as VaultCollectEligibility from "../../CoreKit/vaultCollectEligibility";
import { BODY, BODY_SEMI, Bar, Chip, DiamondRule, ItemTile, Line, MockPanel, NUM, PanelHeading, PnSurface, RowSurface, mockGap, panelPad } from "../../UiCore/mockKit";
import { loadUi } from "../luauDeps";
// generated from design/03-forge by scripts/gen_from_layout.js (scripts/layout/forge.spec.json)
import { ForgeLayout as L } from "../generated/ForgeLayout";
import { useHeroTabs } from "../../UiCore/heroSlot";
import { MockTabs } from "../socialKit";
import { ProgramsPanel, ProgramsState, programsPanelHeight } from "./ProgramsPanel";

// header-forge.png (1024x120), already uploaded (assets/uploaded.md)
const UserInputService = game.GetService("UserInputService");
const { Button, Dropdown, Text } = loadUi();

interface MachineConfig extends UpgradeConfig {
	Accent?: Color3;
	Color: Color3;
	Icon?: string;
	Description?: string;
	BaseProduction?: number;
}
type Entry = UpgradeEntry<MachineConfig>;
type ModelEntry = Parameters<typeof Tools.Model.quote>[0];
type ModelEntries = Parameters<typeof Tools.Model.filter>[0];
type Dispatch = (action: unknown, payload: unknown, reply?: (response: unknown) => void) => unknown;

interface WorkshopState {
	Cash?: Flux;
	Production?: unknown;
	Machines: Record<string, number | undefined>;
	Zone: number;
	Rebirths: number;
	AutoForge?: { Enabled: boolean; MachineId: string; Reserve: number; Bought: number };
	[key: string]: unknown;
}

const AUTO_FORGE_RESERVES = [
	{ id: "NONE", label: "No reserve" },
	{ id: "SAFE", label: "Keep 25%" },
	{ id: "HALF", label: "Keep 50%" },
	{ id: "HIGH", label: "Keep 75%" },
];

function machineLocked(state: WorkshopState, machine: MachineConfig) {
	return (
		state.Zone < (machine.RequiredZone ?? 1) ||
		state.Rebirths < (machine.RequiredRebirths ?? 0) ||
		(machine.PreviousId !== undefined && (state.Machines[machine.PreviousId] ?? 0) < (machine.PreviousLevel ?? 1))
	);
}

function AutoForgePanel(props: {
	state: WorkshopState;
	machines: MachineConfig[];
	dispatch: Dispatch;
	reducedMotion?: boolean;
	height: number;
	stack?: boolean;
}) {
	const { state, machines, dispatch, height } = props;
	const viewport = useViewport();
	const softMotion = props.reducedMotion;
	const stack = props.stack ?? chromeFor(viewport).stack;
	const queue = state.AutoForge ?? {
		Enabled: false,
		MachineId: (machines[0] as MachineConfig | undefined)?.Id ?? "StellarCore",
		Reserve: 0.25,
		Bought: 0,
	};
	const target = machines.find((machine) => machine.Id === queue.MachineId) ?? (machines[0] as MachineConfig | undefined);
	const machineOptions = (() => {
		const options: Array<{ id: string; label: string }> = [];
		const seen = new Set<string>();
		const push = (machine: MachineConfig) => {
			if (seen.has(machine.Id)) {
				return undefined;
			}
			seen.add(machine.Id);
			options.push({ id: machine.Id, label: machine.Name });
		};
		const current = machines.find((machine) => machine.Id === queue.MachineId);
		if (current !== undefined) {
			push(current);
		}
		for (let index = machines.size() - 1; index >= 0 && options.size() < 24; index--) {
			const machine = machines[index];
			if ((state.Machines[machine.Id] ?? 0) > 0) {
				push(machine);
			}
		}
		for (const machine of machines) {
			if (options.size() >= 40) {
				break;
			}
			if (machineLocked(state, machine)) {
				continue;
			}
			push(machine);
		}
		return options;
	})();
	const level = target !== undefined ? (state.Machines[target.Id] ?? 0) : 0;
	const nextCost: Flux =
		target !== undefined && level < target.MaxLevel ? bulkCost(target.BaseCost, target.CostScale, level, 1, target.MaxLevel) : 0;
	const targetLocked = target !== undefined && machineLocked(state, target);
	const waiting = !targetLocked && target !== undefined && level < target.MaxLevel && !gteFlux(state.Cash as Flux, nextCost);
	const status = !queue.Enabled
		? "PAUSED"
		: target === undefined || level >= target.MaxLevel
			? "TARGET COMPLETE"
			: targetLocked
				? "WAITING FOR UNLOCK"
				: waiting
					? `WAITING FOR ${compactNumber(nextCost)} FLUX`
					: "NEXT LEVEL QUEUED";
	const badgeStatus = !queue.Enabled
		? "PAUSED"
		: targetLocked
			? "LOCKED"
			: waiting
				? "WAITING"
				: target === undefined || level >= (target.MaxLevel ?? 0)
					? "DONE"
					: "LIVE";
	const apply = (enabled: boolean, machineId?: string, reserve?: number) =>
		dispatch("SetAutoForge", {
			Enabled: enabled,
			MachineId: machineId ?? queue.MachineId,
			Reserve: reserve ?? queue.Reserve,
		});
	// phones (portrait and landscape): label + badge, title, a full-width line, then the machine picker and
	// the reserve/start row underneath; featureHeight in WorkshopView matches this so nothing spills into the list
	const controlY = stack ? 104 : 102;
	// desktop: the three controls share the row (44% / 28% / 28%), so a 840-900px window with the side
	// nav no longer pushes the start button past the panel edge; fixed widths needed about 630px
	const machineW = stack ? new UDim2(1, 0, 0, TapTarget) : new UDim2(0.44, -8, 0, 42);
	const reserveW = stack ? new UDim2(0.5, -5, 0, TapTarget) : new UDim2(0.28, -8, 0, 42);
	const buttonW = stack ? new UDim2(0.5, -5, 0, TapTarget) : new UDim2(0.28, 0, 0, 42);
	return (
		<PnSurface radius={stack ? 12 : 16} rule
			size={new UDim2(1, -4, 0, height)}
			accent={Palette.brass}
			background={Palette.panel}
			padding={14}
			layoutOrder={1}
			reducedMotion={softMotion}
			zIndex={24}
			clips={false}
		>
			{/* .pn h3 + .chip (03-forge kit) in place of the pre-revamp IconTile / Badge header; the old
			    desktop copy reserved a fixed 220px column and went negative under ~300px of panel */}
			<frame Size={new UDim2(1, 0, 0, stack ? 18 : 22)} BackgroundTransparency={1} BorderSizePixel={0}>
				<PanelHeading
					icon="Forge"
					title="Auto-Forge"
					note={stack ? undefined : `${compactNumber(queue.Bought)} auto levels`}
					accent={queue.Enabled ? Palette.mango : Palette.muted}
					phone={stack}
				/>
			</frame>
			<frame
				Size={UDim2.fromOffset(0, stack ? 24 : 28)}
				AutomaticSize={Enum.AutomaticSize.X}
				Position={stack ? new UDim2(1, 0, 0, 24) : new UDim2(1, 0, 0, 30)}
				AnchorPoint={new Vector2(1, 0)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
			>
				<Chip text={stack ? badgeStatus : status} accent={queue.Enabled ? Palette.mint : undefined} phone={stack} />
			</frame>
			<frame
				Size={new UDim2(1, stack ? 0 : -150, 0, stack ? 40 : 44)}
				Position={UDim2.fromOffset(0, stack ? 52 : 34)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
			>
				<Text
					value={"Buys one level at a time and never spends your reserve."}
					size={stack ? 11 : 12}
					color={Palette.creamSoft}
					wrap={true}
					fit={true}
					minSize={9}
					sizeConstraint={UDim2.fromScale(1, 1)}
				/>
			</frame>
			<Dropdown
				options={machineOptions}
				value={target?.Id ?? machineOptions[0]?.id ?? "StellarCore"}
				onChange={(id: string) => apply(queue.Enabled, id, queue.Reserve)}
				accent={Palette.mango}
				label="TARGET MACHINE"
				position={UDim2.fromOffset(0, controlY)}
				size={machineW}
				reducedMotion={softMotion}
				zIndex={54}
			/>
			<Dropdown
				options={AUTO_FORGE_RESERVES}
				value={AppHelpers.reserveId(queue.Reserve)}
				onChange={(id: string) => apply(queue.Enabled, queue.MachineId, AppHelpers.reserveValue(id))}
				accent={Palette.cyan}
				label="FLUX RESERVE"
				position={stack ? UDim2.fromOffset(0, controlY + TapTarget + 26) : new UDim2(0.44, 4, 0, controlY)}
				size={reserveW}
				reducedMotion={softMotion}
				zIndex={52}
			/>
			<frame
				Size={buttonW}
				Position={stack ? new UDim2(0.5, 5, 0, controlY + TapTarget + 26) : new UDim2(0.72, 0, 0, controlY)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ZIndex={26}
			>
				<Button
					text={queue.Enabled ? "PAUSE QUEUE" : "START QUEUE"}
					icon={queue.Enabled ? "Pause.1" : "Play.1"}
					onClick={() => apply(!queue.Enabled)}
					color={queue.Enabled ? Palette.panelSoft : Palette.mango}
					textColor={queue.Enabled ? Palette.cream : Palette.ink}
					outline={queue.Enabled}
					size={UDim2.fromScale(1, 1)}
					reducedMotion={softMotion}
					highlight={!queue.Enabled}
					zIndex={27}
				/>
			</frame>
		</PnSurface>
	);
}

function listedFluxPerSec(machine: unknown): number {
	const base = typeIs(machine, "table") ? (machine as { BaseProduction?: unknown }).BaseProduction : undefined;
	if (!typeIs(base, "number") || base <= 0) {
		return 0;
	}
	return base;
}

// Forge, ported from design/03-forge (desktop.html 1920x1080, phone.html).
// Desktop: Machines panel (flex) with a Next upgrades grid under a brass rule; a 520px column with
// the Output panel (glow top-right, 58px rate) and Auto-Forge under it. Gap 18 everywhere.
// Phone (landscape): Machines panel and a 236px Output panel. Portrait: the two stacked.
// .big row is bottom-aligned: a centred line this tall puts "per second" where the mockup has it
const UNIT_H = 2 * (L.OutputRate.y + L.OutputRate.h - (L.OutputUnit.y + L.OutputUnit.h / 2));

function machineGain(machine: MachineConfig, level: number): number {
	const base = listedFluxPerSec(machine);
	const growth = tonumber((machine as unknown as { Growth?: unknown }).Growth) ?? 0;
	return base * (1 + 2 * growth * level);
}

function MachineLine(p: {
	entry: Entry;
	phone: boolean;
	ready: boolean;
	onBuy: () => unknown;
	order: number;
	reducedMotion?: boolean;
}) {
	const { entry, phone } = p;
	const machine = entry.config;
	const rowH = phone ? 64 : L.Row.h; // phone.html .row: 56 .it + 4px padding
	const color = machine.Accent ?? machine.Color ?? Palette.mango;
	const name = typeIs(machine.Name, "string") ? machine.Name : machine.Id;
	const tail = !entry.unlocked ? "Locked" : `Lv ${compactNumber(entry.level)}`;
	const fill = machine.MaxLevel > 0 ? entry.level / machine.MaxLevel : 0;
	const rate = listedFluxPerSec(machine);
	const value = !entry.unlocked ? (entry.lockShort !== "" ? entry.lockShort : "Locked") : rate > 0 ? `+${compactNumber(rate)}/s` : entry.maxed ? "Maxed" : "";
	const label = entry.maxed ? "Maxed" : entry.level < 1 ? "Buy" : "Upgrade";
	return (
		<frame Size={new UDim2(1, 0, 0, rowH)} BackgroundColor3={Palette.white} BorderSizePixel={0} LayoutOrder={p.order}>
			<RowSurface />
			<uipadding PaddingLeft={new UDim(0, phone ? 10 : L.Row.pad.left)} PaddingRight={new UDim(0, phone ? 10 : L.Row.pad.right)} />
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, phone ? 14 : L.Row.gap)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
			<ItemTile color={color} icon={entry.unlocked ? (machine.Icon ?? "Forge") : "Lock"} width={phone ? 56 : L.RowTile.w} compact={true} locked={!entry.unlocked} layoutOrder={0} />
			<frame Size={new UDim2(0, 0, 0, phone ? 30 : L.RowText.h)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
				<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
				<textlabel
					BackgroundTransparency={1}
					Size={new UDim2(1, 0, 0, phone ? 17 : L.RowName.h)}
					RichText={true}
					Text={`${name} <font color="#B2A0A6" weight="500">· ${tail}</font>`}
					TextSize={phone ? 13 : L.RowName.text.size}
					FontFace={BODY_SEMI}
					TextColor3={L.RowName.text.color}
					TextXAlignment={Enum.TextXAlignment.Left}
					TextTruncate={Enum.TextTruncate.AtEnd}
				/>
				<Bar fill={fill} thin={true} color={Palette.mango} position={new UDim2(0, 0, 1, -(phone ? 6 : L.RowBar.h))} />
			</frame>
			<Line text={value} size={L.RowValue.text.size} font={NUM} color={L.RowValue.text.color} layoutOrder={2} />
			<Button
				text={phone ? undefined : label}
				icon={entry.level < 1 ? "Forge" : "Production"}
				onClick={() => p.onBuy()}
				disabled={!p.ready}
				color={Palette.mango}
				textColor={Color3.fromRGB(27, 15, 8)}
				hug={!phone}
				size={phone ? UDim2.fromOffset(44, 36) : UDim2.fromOffset(0, L.RowBuy.h)}
				reducedMotion={p.reducedMotion}
				tooltip={!entry.unlocked ? entry.lockReason : p.ready ? undefined : `Costs ${compactNumber(entry.price)} Flux`}
			/>
		</frame>
	);
}

function WorkshopView(props: {
	state: WorkshopState;
	config?: { Machines?: unknown; Boosts?: unknown };
	dispatch: Dispatch;
	buyAmount: number;
	setBuyAmount: (amount: number) => void;
	reducedMotion?: boolean;
}) {
	const { state, config, dispatch, buyAmount, reducedMotion } = props;
	const machines = (config !== undefined && typeIs(config.Machines, "table") ? config.Machines : []) as MachineConfig[];
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const phone = chrome.stack;
	const portrait = phone && !chrome.landscape;
	const gap = mockGap(phone);
	const pad = panelPad(phone);
	const machinesReveal = useStagger(0, reducedMotion);
	// 03-forge .hero .tabs: Machines / Upgrades / Auto filter the page's own sections
	const [tab, setTab] = React.useState("Machines");
	useHeroTabs(
		phone ? undefined : (
			<MockTabs
				options={[
					{ id: "Machines", label: "Machines" },
					{ id: "Upgrades", label: "Upgrades" },
					{ id: "Auto", label: "Auto" },
				]}
				value={tab}
				onChange={setTab}
				accent={Palette.mango}
				phone={false}
				reducedMotion={reducedMotion}
				layoutOrder={0}
			/>
		),
	);
	const outputReveal = useStagger(1, reducedMotion);
	const entries = React.useMemo(
		() => AppHelpers.buildUpgradeEntries(machines, state.Machines, state as NavState),
		[machines, state.Machines, state.Zone, state.Rebirths],
	);
	const cash = state.Cash;
	const near = AppHelpers.trimFarLockedUpgrades(entries);
	const batch = Tools.useBatch(dispatch, "BuyMachine", near as unknown as ModelEntries, buyAmount, cash);
	const ready = (entry: Entry) => Tools.Model.quote(entry as unknown as ModelEntry, buyAmount, cash).ready;
	let running = 0;
	for (const entry of entries) {
		if (entry.level > 0) running += 1;
	}

	// gamepad lands on the first machine row
	const listRef = React.useRef<ScrollingFrame>();
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) return undefined;
		const host = listRef.current;
		if (host === undefined) return undefined;
		const job = task.defer(() => {
			if (host.Parent !== undefined) GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [near.size()]);

	// Next upgrades: the three cheapest levels you can work toward right now
	const upgrades = near.filter((e) => e.unlocked && !e.maxed);
	upgrades.sort((a, b) => compareFlux(a.price, b.price) < 0);
	const nextThree = upgrades.filter((_, i) => i < 3);

	const rowH = phone ? 64 : L.Row.h; // phone.html .row: 56 .it + 4px padding
	const rowGap = phone ? 8 : L.Row2.y - (L.Row.y + L.Row.h);
	const listH = near.size() * rowH + math.max(0, near.size() - 1) * rowGap;
	const upgradeCellH = L.Upgrade.h; // 14 + 19 + 6 + 16 + 6 + 36 + 14
	const showUpgrades = !phone && nextThree.size() > 0;
	// panel gap, .rule 12, gap, h3 21, gap, grid
	const lowerH = showUpgrades ? L.Machines.gap + L.Rule.h + L.Machines.gap + L.UpgradesHeading.h + L.Machines.gap + upgradeCellH : 0;
	const headH = phone ? 18 : L.Heading.h;

	const upgradeCell = (entry: Entry, i: number) => {
		const m = entry.config;
		const gain = machineGain(m, entry.level);
		return (
			<frame key={m.Id} BackgroundColor3={Palette.white} BorderSizePixel={0} LayoutOrder={i}>
				<RowSurface />
				<uipadding PaddingLeft={new UDim(0, L.Upgrade.pad.left)} PaddingRight={new UDim(0, L.Upgrade.pad.right)} PaddingTop={new UDim(0, L.Upgrade.pad.top)} PaddingBottom={new UDim(0, L.Upgrade.pad.bottom)} />
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, L.Upgrade.gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<Line text={`${typeIs(m.Name, "string") ? m.Name : m.Id} level ${compactNumber(entry.level + 1)}`} size={L.UpgradeName.text.size} font={BODY_SEMI} width={new UDim(1, 0)} height={L.UpgradeName.h} layoutOrder={0} />
				<Line
					text={gain > 0 ? `+${compactNumber(gain)} Flux/sec` : entry.level < 1 ? "Starts earning" : "Raises its level cap"}
					size={L.UpgradeLine.text.size}
					font={BODY}
					color={L.UpgradeLine.text.color}
					width={new UDim(1, 0)}
					height={L.UpgradeLine.h}
					layoutOrder={1}
				/>
				<Button
					text={`${compactNumber(entry.price)}`}
					icon="Flux"
					onClick={() => batch.buy(m.Id)}
					disabled={!ready(entry)}
					size={new UDim2(1, 0, 0, L.UpgradeBuy.h)}
					reducedMotion={reducedMotion}
				/>
			</frame>
		);
	};

	const machinesPanel = (
		<MockPanel
			size={portrait ? new UDim2(1, 0, 0, pad.y * 2 + headH + pad.gap + math.min(listH, 3 * rowH + 2 * rowGap)) : new UDim2(0, 0, 1, 0)}
			flex={!portrait}
			phone={phone}
			layoutOrder={0}
			reveal={machinesReveal}
			reducedMotion={reducedMotion}
			name="ForgeMachines"
		>
			<PanelHeading icon="Forge" title="Machines" note={phone ? `${running} of ${entries.size()}` : `${running} of ${entries.size()} running`} phone={phone} layoutOrder={0} />
			<scrollingframe
				ref={listRef}
				Size={new UDim2(1, 0, 1, -(headH + pad.gap + lowerH))}
				CanvasSize={UDim2.fromOffset(0, listH)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ScrollBarThickness={4}
				ScrollBarImageColor3={Palette.brass}
				ScrollingDirection={Enum.ScrollingDirection.Y}
				VerticalScrollBarInset={Enum.ScrollBarInset.ScrollBar}
				LayoutOrder={1}
				SelectionGroup={true}
			>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, rowGap)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{near.size() === 0 ? (
					<Line text="No machines yet." size={14} color={Palette.muted} />
				) : (
					near.map((entry, i) => (
						<MachineLine
							key={entry.config.Id}
							entry={entry}
							phone={phone}
							ready={ready(entry)}
							onBuy={() => batch.buy(entry.config.Id)}
							order={i}
							reducedMotion={reducedMotion}
						/>
					))
				)}
			</scrollingframe>
			{showUpgrades && <DiamondRule layoutOrder={2} />}
			{showUpgrades && <PanelHeading icon="Production" title="Next upgrades" phone={false} layoutOrder={3} />}
			{showUpgrades && (
				<frame Size={new UDim2(1, 0, 0, upgradeCellH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={4}>
					<uigridlayout CellSize={new UDim2(1 / 3, -math.ceil((L.UpgradeGrid.gap * 2) / 3), 0, upgradeCellH)} CellPadding={UDim2.fromOffset(L.UpgradeGrid.gap, 0)} SortOrder={Enum.SortOrder.LayoutOrder} />
					{nextThree.map((entry, i) => upgradeCell(entry, i))}
				</frame>
			)}
		</MockPanel>
	);

	// Output: production, multipliers, vault fill, collect + overcharge
	const s = state as WorkshopState & { Vault?: Flux; Capacity?: Flux; PermanentMultiplier?: Flux; TapPower?: number; ActiveBoost?: { Id?: string; EndsAt?: unknown } };
	const rateText = compactNumber(s.Production ?? 0);
	const vault = tonumber(s.Vault) ?? 0;
	const capacity = tonumber(s.Capacity) ?? 0;
	const vaultFill = capacity > 0 ? vault / capacity : 0;
	const canCollect = VaultCollectEligibility.isEligible(asFlux(s.Vault ?? 0));
	const chips: Array<{ text: string; on: boolean }> = [];
	const perm = tonumber(s.PermanentMultiplier) ?? 1;
	if (perm > 1) chips.push({ text: `x${compactNumber(perm)} rebirth`, on: true });
	const boosts = (config !== undefined && typeIs(config.Boosts, "table") ? config.Boosts : {}) as Record<string, { Multiplier?: unknown } | undefined>;
	const boostId = s.ActiveBoost?.Id ?? "";
	const boostEnds = (s.ActiveBoost !== undefined ? tonumber(s.ActiveBoost.EndsAt) : undefined) ?? 0;
	const [okNow, nowValue] = pcall(() => game.GetService("Workspace").GetServerTimeNow());
	const now = okNow && typeIs(nowValue, "number") ? nowValue : os.time();
	if (boostId !== "" && boostEnds > now) {
		const mult = tonumber(boosts[boostId]?.Multiplier) ?? 1;
		if (mult > 1) chips.push({ text: `x${compactNumber(mult)} boost`, on: false });
	}
	const [overchargeAt, setOverchargeAt] = React.useState(0);
	const overcharge = () => {
		if (os.clock() < overchargeAt) return;
		setOverchargeAt(os.clock() + 0.45);
		dispatch("Overcharge", undefined);
	};
	const collect = () => {
		if (canCollect) dispatch("CollectVault", undefined);
	};
	const bigSize = phone ? 34 : L.OutputBig.text.size;
	const outputH = phone
		? undefined
		: L.Output.pad.top + L.Heading.h + L.Output.gap + L.OutputRate.h + L.Output.gap + (chips.size() > 0 ? L.OutputChips.h + L.Output.gap : 0) + L.OutputBar.h + L.Output.gap + L.OutputActions.h + L.Output.pad.bottom;
	const outputPanel = (
		<MockPanel
			size={phone ? (portrait ? new UDim2(1, 0, 0, pad.y * 2 + 18 + 8 + 40 + 8 + 10 + 8 + 44) : new UDim2(0, 236, 1, 0)) : new UDim2(1, 0, 0, outputH!)}
			phone={phone}
			layoutOrder={phone ? 1 : 0}
			glow={phone ? undefined : Palette.mango}
			reveal={outputReveal}
			reducedMotion={reducedMotion}
			name="ForgeOutput"
		>
			<PanelHeading icon="Production" title="Output" phone={phone} layoutOrder={0} />
			<frame Size={new UDim2(1, 0, 0, phone ? 40 : L.OutputRate.h)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, phone ? 4 : L.OutputRate.gap)} VerticalAlignment={Enum.VerticalAlignment.Bottom} SortOrder={Enum.SortOrder.LayoutOrder} />
				<Line text={rateText} size={bigSize} font={NUM} color={L.OutputBig.text.color} height={phone ? 40 : L.OutputBig.h} layoutOrder={0} />
				<Line text={phone ? "/s" : "per second"} size={phone ? 15 : L.OutputUnit.text.size} font={BODY_SEMI} color={L.OutputUnit.text.color} height={phone ? 30 : UNIT_H} layoutOrder={1} />
			</frame>
			{!phone && chips.size() > 0 && (
				<frame Size={new UDim2(1, 0, 0, L.OutputChips.h)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, L.OutputChips.gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
					{chips.map((c, i) => (
						<Chip key={c.text} text={c.text} accent={c.on ? Palette.mango : undefined} layoutOrder={i} />
					))}
				</frame>
			)}
			<Bar fill={vaultFill} layoutOrder={3} />
			<frame Size={new UDim2(1, 0, 0, L.OutputActions.h)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={4}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, L.OutputActions.gap)} HorizontalFlex={Enum.UIFlexAlignment.Fill} SortOrder={Enum.SortOrder.LayoutOrder} />
				<Button
					text={phone ? "Collect" : `Collect ${compactNumber(s.Vault ?? 0)}`}
					icon="Collect"
					onClick={collect}
					disabled={!canCollect}
					highlight={canCollect && vaultFill >= 0.85}
					color={Palette.mango}
					textColor={Color3.fromRGB(27, 15, 8)}
					size={new UDim2(1, 0, 0, 44)}
					reducedMotion={reducedMotion}
				/>
				{!phone && (
					<Button
						text="Overcharge"
						icon="Overcharge"
						onClick={overcharge}
						hug={true}
						size={UDim2.fromOffset(0, 44)}
						reducedMotion={reducedMotion}
						tooltip={s.TapPower !== undefined ? `+${compactNumber(s.TapPower)} Flux per tap` : undefined}
					/>
				)}
			</frame>
		</MockPanel>
	);

	// desktop .flexr: the tab's .pn.f1 on the left, the 520px column with Output on the right
	const upgradeCols = phone ? 2 : 3;
	const upgradeRows = math.ceil(upgrades.size() / upgradeCols);
	const upgradeGridH = upgradeRows * upgradeCellH + math.max(0, upgradeRows - 1) * L.UpgradeGrid.gap;
	const programsHeight = programsPanelHeight(state as ProgramsState, phone);
	const autoH = 246;
	let left: React.Element;
	if (tab === "Upgrades") {
		left = (
			<MockPanel size={new UDim2(0, 0, 1, 0)} flex={true} phone={phone} layoutOrder={0} reveal={machinesReveal} reducedMotion={reducedMotion} name="ForgeUpgrades">
				<PanelHeading icon="Production" title="Upgrades" note={`${upgrades.size()} available`} phone={phone} layoutOrder={0} />
				{upgrades.size() === 0 ? (
					<Line text="Every unlocked machine is maxed." size={14} color={Palette.muted} layoutOrder={1} />
				) : (
					<scrollingframe Size={new UDim2(1, 0, 1, -(headH + pad.gap))} CanvasSize={UDim2.fromOffset(0, upgradeGridH)} BackgroundTransparency={1} BorderSizePixel={0} ScrollBarThickness={4} ScrollBarImageColor3={Palette.brass} ScrollingDirection={Enum.ScrollingDirection.Y} LayoutOrder={1} SelectionGroup={true}>
						<uigridlayout CellSize={new UDim2(1 / upgradeCols, -math.ceil((L.UpgradeGrid.gap * (upgradeCols - 1)) / upgradeCols), 0, upgradeCellH)} CellPadding={UDim2.fromOffset(L.UpgradeGrid.gap, L.UpgradeGrid.gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
						{upgrades.map((entry, i) => upgradeCell(entry, i))}
					</scrollingframe>
				)}
			</MockPanel>
		);
	} else if (tab === "Auto") {
		left = (
			<scrollingframe Size={new UDim2(0, 0, 1, 0)} CanvasSize={UDim2.fromOffset(0, autoH + (programsHeight > 0 ? gap + programsHeight : 0))} BackgroundTransparency={1} BorderSizePixel={0} ScrollBarThickness={0} ScrollingDirection={Enum.ScrollingDirection.Y} LayoutOrder={0} SelectionGroup={true}>
				<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<frame Size={new UDim2(1, 0, 0, autoH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={0}>
					<AutoForgePanel state={state} machines={machines} dispatch={dispatch} reducedMotion={reducedMotion} height={autoH} stack={phone} />
				</frame>
				{programsHeight > 0 && (
					<frame Size={new UDim2(1, 0, 0, programsHeight)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
						<ProgramsPanel state={state as ProgramsState} dispatch={dispatch} stack={phone} reducedMotion={reducedMotion} />
					</frame>
				)}
			</scrollingframe>
		);
	} else {
		left = machinesPanel;
	}
	if (phone) {
		// 03-forge phone.html .ph-head: 12px muted line on the left, the .tabs on the right (h1 is the shell title);
		// then the .flexr body: the tab's panel and the 236px Output panel (portrait stacks Output first)
		const phoneHeadH = TapTarget + 8;
		return (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<frame Size={new UDim2(1, 0, 0, phoneHeadH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={0}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 10)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
					<frame Size={new UDim2(0, 0, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={0}>
						<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
						<Line text={`${running} of ${entries.size()} machines running`} size={12} font={BODY_SEMI} color={Palette.muted} height={phoneHeadH} layoutOrder={0} />
					</frame>
					<MockTabs
						options={[
							{ id: "Machines", label: "Machines" },
							{ id: "Upgrades", label: "Upgrades" },
							{ id: "Auto", label: "Auto" },
						]}
						value={tab}
						onChange={setTab}
						accent={Palette.mango}
						phone={true}
						reducedMotion={reducedMotion}
						layoutOrder={1}
					/>
				</frame>
				<frame Size={new UDim2(1, 0, 1, -(phoneHeadH + gap))} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
					<uilistlayout
						FillDirection={portrait ? Enum.FillDirection.Vertical : Enum.FillDirection.Horizontal}
						Padding={new UDim(0, gap)}
						HorizontalFlex={portrait ? Enum.UIFlexAlignment.Fill : Enum.UIFlexAlignment.None}
						SortOrder={Enum.SortOrder.LayoutOrder}
					/>
					{portrait ? outputPanel : left}
					{portrait ? left : outputPanel}
				</frame>
			</frame>
		);
	}
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
			{left}
			<frame Size={new UDim2(0, L.Column.w, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{outputPanel}
			</frame>
		</frame>
	);
}

export = { WorkshopView };

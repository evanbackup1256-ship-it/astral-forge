// The open relic: where it can go (socket chips), Socket/Swap/Detach, Upgrade, Protect and Salvage,
// and a footer that compares it with what's in the chosen socket.
import React from "@rbxts/react";
import CompanionRelic = require("../../../../../Shared/AstralForge/Shared/CompanionRelic");
import { compactNumber } from "../../../CoreKit/format";
import * as GamepadNavigationService from "../../../CoreKit/GamepadNavigationService";
import {
	ACTION_BTN,
	ChipRows,
	CompareSocket,
	INSPECT_BTN_GAP,
	INSPECT_FOOTER_H,
	INSPECT_PAD,
	InspectActionsHeight,
	InspectPanelHeight,
	InspectSocketBlock,
	OwnedItem,
	RarityColor,
	SalvagePreview,
	SocketLabel,
	SocketTargets,
	UpgradeCost,
	UpgradeState,
} from "../../../CoreKit/inventoryMath";
import { contrastOn, Palette, TapTarget } from "../../../CoreKit/theme";
import { Button, Panel, Text } from "../../../UiCore/ui";
import { loadAudio, named } from "../../luauDeps";

const UserInputService = game.GetService("UserInputService");
const Audio = loadAudio();

interface Props {
	item: OwnedItem;
	state: { Items?: { Essence?: number }; Machines?: unknown; Research?: unknown };
	config: unknown;
	dispatch: (action: string, payload?: object) => unknown;
	reducedMotion?: boolean;
	layoutOrder?: number;
	stack?: boolean;
	fill?: boolean;
}

export function DetailPanel({ item, state, config, dispatch, reducedMotion, layoutOrder, stack = false, fill = false }: Props) {
	const inspectActionsHostRef = React.useRef<Frame>();
	const accent = RarityColor(config, item.definition.Rarity, Palette.muted);
	const essence = state.Items?.Essence ?? 0;
	const level = item.instance.Level;
	const cost = UpgradeCost(item.definition, level);
	const [canUpgrade, maxed] = UpgradeState(level, item.definition.MaxLevel, essence, cost);
	const targets = React.useMemo(() => SocketTargets(state, config, item.definition), [config, item.definition, state.Machines, state.Research]);
	const [target, setTarget] = React.useState(item.equippedOn ?? targets[0]?.id ?? "");
	// salvaging destroys the relic, so it takes a second tap within a few seconds
	const [salvageArmedFor, setSalvageArmedFor] = React.useState<string>();
	React.useEffect(() => {
		if (salvageArmedFor === undefined) return undefined;
		const lapse = task.delay(4, () => setSalvageArmedFor(undefined));
		return () => {
			pcall(task.cancel, lapse);
		};
	}, [salvageArmedFor]);
	// keep the chosen socket valid as the relic or the unlocked sockets change
	React.useEffect(() => {
		setTarget((current) => {
			if (item.equippedOn !== undefined) return item.equippedOn;
			if (targets.find((candidate) => candidate.id === current) !== undefined) return current;
			return targets[0]?.id ?? "";
		});
	}, [item.uid, item.equippedOn, targets]);
	const salvage = SalvagePreview(config, item.definition, level);
	const equipped = item.equippedOn !== undefined;
	const compareLine = equipped ? undefined : (CompareSocket(state, config, item.uid, item.definition, level, item.instance.Stars, target) as string | undefined);
	const swapping = compareLine !== undefined && compareLine.sub(1, 8) === "Replaces";
	const locked = item.instance.Locked === true;
	const chipCols = stack ? 2 : 3;
	const chipRows = ChipRows(targets.size(), stack);
	const socketBlock = InspectSocketBlock(equipped, targets.size(), chipRows, stack, TapTarget);
	const chipHeight = stack ? TapTarget : 40;
	const chipStep = stack ? TapTarget + 6 : 42;
	const actionsH = InspectActionsHeight(stack);
	const detailH = InspectPanelHeight(socketBlock, stack);
	const actionSize = stack ? new UDim2(0.5, -5, 0, ACTION_BTN) : new UDim2(0.25, -7, 0, ACTION_BTN);
	// a controller lands on the relic's actions whenever they change
	React.useEffect(() => {
		const host = inspectActionsHostRef.current;
		if (!UserInputService.GamepadEnabled || host === undefined) return undefined;
		const selectJob = task.defer(() => {
			if (host.Parent !== undefined) GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, selectJob);
		};
	}, [item.uid, equipped, locked, canUpgrade, target]);

	const full = UDim2.fromScale(1, 1);
	const socketButton = equipped ? (
		<Button
			text="Detach"
			icon="Close.8"
			onClick={() => dispatch("UnequipItem", { Target: item.equippedOn })}
			color={Palette.panelSoft}
			textColor={Palette.cream}
			size={full}
			reducedMotion={reducedMotion}
			outline={true}
		/>
	) : (
		<Button
			text={swapping ? "Swap in" : "Socket"}
			icon="Loadout.3"
			onClick={() => {
				if (target !== "") dispatch("EquipItem", { Uid: item.uid, Target: target });
			}}
			color={Palette.mint}
			textColor={Palette.ink}
			size={full}
			reducedMotion={reducedMotion}
			disabled={target === ""}
			highlight={target !== ""}
		/>
	);
	const salvageArmed = salvageArmedFor === item.uid;
	const blocked = equipped || locked;
	// the four actions: one row on desktop, two by two on phones
	const slots: Array<[name: string, element: React.Element]> = [
		["InspectSocketClaim", socketButton],
		[
			"InspectUpgradeClaim",
			<Button
				text={maxed ? "Maxed" : `Upgrade  ${compactNumber(cost)}`}
				icon="StarGrid.5"
				onClick={() => dispatch("UpgradeItem", { Uid: item.uid })}
				color={canUpgrade ? Palette.mango : Palette.panelSoft}
				textColor={canUpgrade ? Palette.ink : Palette.muted}
				size={full}
				reducedMotion={reducedMotion}
				disabled={!canUpgrade}
				highlight={canUpgrade}
			/>,
		],
		[
			"InspectProtect",
			<Button
				text={locked ? "Unprotect" : "Protect"}
				icon="Lock.13"
				sound={locked ? "favoriteOff" : "favoriteOn"}
				onClick={() => dispatch("ToggleItemLock", { Uid: item.uid })}
				color={locked ? Palette.mango : Palette.panelSoft}
				textColor={locked ? Palette.ink : Palette.creamSoft}
				size={full}
				reducedMotion={reducedMotion}
				outline={!locked}
			/>,
		],
		[
			"InspectSalvage",
			<Button
				text={salvageArmed ? `Tap again · +${salvage}` : `Salvage  +${salvage}`}
				icon="Dust.9"
				onClick={() => {
					if (!salvageArmed) {
						setSalvageArmedFor(item.uid);
						return;
					}
					setSalvageArmedFor(undefined);
					dispatch("SalvageItem", { Uid: item.uid });
				}}
				color={blocked ? Palette.panelSoft : Palette.coral}
				textColor={blocked ? Palette.muted : Palette.ink}
				size={full}
				reducedMotion={reducedMotion}
				disabled={blocked}
				outline={blocked}
			/>,
		],
	];
	const slotPosition = (index: number) =>
		stack
			? new UDim2(index % 2 === 0 ? 0 : 0.5, index % 2 === 0 ? 0 : 5, 0, index < 2 ? 0 : ACTION_BTN + INSPECT_BTN_GAP)
			: new UDim2(index * 0.25, index * 2, 0, 0);
	const socketedLine =
		item.equippedOn === CompanionRelic.TARGET
			? "Your companion. Detach it to socket it instead."
			: tostring(item.equippedOn).sub(1, 11) === "Expedition:"
				? "Away on an expedition until it's claimed or recalled."
				: `Socketed on ${SocketLabel(item.equippedOn)}`;
	const footer = equipped
		? "Detach before salvaging."
		: (compareLine ?? (locked ? "Protected relics can't be salvaged." : `Essence bank: ${compactNumber(essence)}`));
	return (
		<Panel size={fill ? full : new UDim2(1, 0, 0, detailH)} accent={accent} background={Palette.panelRaised} padding={INSPECT_PAD} layoutOrder={layoutOrder} clips={false} zIndex={20}>
			<frame Size={full} BackgroundTransparency={1} BorderSizePixel={0}>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, INSPECT_BTN_GAP)} />
				{equipped && (
					<Text value={socketedLine} size={13} color={Palette.mint} weight={Enum.FontWeight.Bold} fit={true} minSize={9} layoutOrder={0} sizeConstraint={new UDim2(1, 0, 0, 20)} />
				)}
				{!equipped && targets.size() > 0 && (
					<frame Size={new UDim2(1, 0, 0, chipRows * chipStep)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={0}>
						{targets.map((entry, index) => {
							const active = entry.id === target;
							return (
								<imagebutton
									key={entry.id}
									Size={new UDim2(1 / chipCols, -6, 0, chipHeight)}
									Position={new UDim2((index % chipCols) / chipCols, 0, 0, math.floor(index / chipCols) * chipStep)}
									BackgroundColor3={active ? accent : Palette.panelSoft}
									BackgroundTransparency={active ? 0.15 : 0.2}
									BorderSizePixel={0}
									AutoButtonColor={false}
									Active={true}
									Selectable={true}
									Event={{
										Activated: () => {
											setTarget(entry.id);
											Audio.play("tick");
										},
										MouseEnter: () => Audio.play("hover"),
										SelectionGained: () => Audio.play("hover"),
									}}
								>
									<uicorner CornerRadius={new UDim(0, 8)} />
									<uistroke Color={active ? accent : Palette.lineSoft} Thickness={1} Transparency={active ? 0.2 : 0.55} />
									<Text
										value={entry.label}
										size={12}
										color={active ? contrastOn(accent) : Palette.cream}
										weight={Enum.FontWeight.Bold}
										align={Enum.TextXAlignment.Center}
										position={UDim2.fromOffset(6, 0)}
										sizeConstraint={new UDim2(1, -12, 1, 0)}
									/>
								</imagebutton>
							);
						})}
					</frame>
				)}
				{!equipped && targets.size() === 0 && (
					<Text
						value="Nothing it fits is unlocked yet. Unlock its machine or research first."
						size={12}
						color={Palette.mango}
						wrap={true}
						fit={true}
						minSize={10}
						layoutOrder={0}
						sizeConstraint={new UDim2(1, 0, 0, 28)}
					/>
				)}
				<frame {...named("InspectClaimActions")} ref={inspectActionsHostRef} Size={new UDim2(1, 0, 0, actionsH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2} ClipsDescendants={false}>
					{slots.map(([name, element], index) => (
						<frame key={name} {...named(name)} Size={actionSize} Position={slotPosition(index)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
							{element}
						</frame>
					))}
				</frame>
				<Text
					value={footer}
					size={12}
					color={compareLine !== undefined && !equipped ? Palette.cream : Palette.muted}
					layoutOrder={3}
					sizeConstraint={new UDim2(1, 0, 0, INSPECT_FOOTER_H)}
				/>
			</frame>
		</Panel>
	);
}

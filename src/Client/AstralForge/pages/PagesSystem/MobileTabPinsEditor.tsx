// Settings > Phone: choose and order up to five pages that lead the phone bottom bar.
// Pins are saved to Flags.MobileTabPins through SetMobileLayout; the bar fills the rest from
// its priority order.
import React from "@rbxts/react";
import { darken, Palette, TapTarget } from "../../CoreKit/theme";
import * as NavRouteTable from "../../CoreKit/navRouteTable";
import * as NavRoutes from "../../../../Shared/AstralForge/Shared/NavRoutes";
import { kitMember, LuauComponent } from "../luauKits";

const { Button, SegmentedTabs, Text } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");

const ROW_GAP = 8;
const LABEL_H = 34;

type Dispatch = (action: string, payload?: object) => void;

interface Props {
	savedPins: unknown;
	dispatch: Dispatch;
	accent: Color3;
	stack: boolean;
	softMotion: boolean;
}

function labelOf(id: string): string {
	return NavRoutes.PRIMARY_ROUTES.find((r) => r.id === id)?.label ?? NavRoutes.MORE_ROUTES.find((r) => r.id === id)?.label ?? id;
}

function groupRoutes(key: string): string[] {
	const group = NavRouteTable.NAV_GROUPS.find((g) => g.key === key);
	const ids = new Array<string>();
	for (const id of group?.routes ?? []) {
		if (NavRoutes.isNavId(id)) {
			ids.push(id);
		}
	}
	return ids;
}

function gridColumns(stack: boolean) {
	return stack ? 2 : 3;
}

/** Height Settings reserves for the editor: enough for the largest group's grid. */
export function mobileTabPinsEditorHeight(stack: boolean): number {
	let rows = 1;
	for (const group of NavRouteTable.NAV_GROUPS) {
		rows = math.max(rows, math.ceil(groupRoutes(group.key).size() / gridColumns(stack)));
	}
	return LABEL_H + (TapTarget + ROW_GAP) * 3 + rows * (TapTarget + ROW_GAP) + 10;
}

export function MobileTabPinsEditor(props: Props) {
	const { dispatch, accent, stack, softMotion } = props;
	const pins = NavRoutes.normalizeMobileTabPins(props.savedPins);
	const [selected, setSelected] = React.useState<string | undefined>(undefined);
	const [group, setGroup] = React.useState(NavRouteTable.NAV_GROUPS[0].key);
	const chosen = selected !== undefined && pins.includes(selected) ? selected : undefined;
	const full = pins.size() >= NavRoutes.MAX_MOBILE_TAB_PINS;

	const save = (updated: string[]) => dispatch("SetMobileLayout", { Pins: updated });
	const move = (delta: number) => {
		if (chosen === undefined) return;
		const from = pins.indexOf(chosen);
		const to = math.clamp(from + delta, 0, pins.size() - 1);
		if (to === from) return;
		const updated = table.clone(pins);
		updated[from] = updated[to];
		updated[to] = chosen;
		save(updated);
	};

	const cols = gridColumns(stack);
	const pinW = 1 / NavRoutes.MAX_MOBILE_TAB_PINS;
	const pinRow: Record<string, React.Element> = {};
	for (let i = 0; i < NavRoutes.MAX_MOBILE_TAB_PINS; i++) {
		const id = pins[i];
		pinRow[`pin${i}`] =
			id !== undefined ? (
				<Button
					text={labelOf(id)}
					onClick={() => setSelected(chosen === id ? undefined : id)}
					color={chosen === id ? accent : Palette.panelSoft}
					textColor={chosen === id ? Palette.ink : Palette.cream}
					outline={chosen !== id}
					size={new UDim2(pinW, -6, 0, TapTarget)}
					position={new UDim2(pinW * i, 0, 0, 0)}
					reducedMotion={softMotion}
				/>
			) : (
				<frame
					Size={new UDim2(pinW, -6, 0, TapTarget)}
					Position={new UDim2(pinW * i, 0, 0, 0)}
					BackgroundColor3={darken(Palette.panelSoft, 0.35)}
					BackgroundTransparency={0.4}
					BorderSizePixel={0}
				>
					<uicorner CornerRadius={new UDim(0, 10)} />
					<uistroke Color={Palette.brass} Transparency={0.75} Thickness={1} />
				</frame>
			);
	}

	const ids = groupRoutes(group);
	const cellW = 1 / cols;
	const grid: Record<string, React.Element> = {};
	ids.forEach((id, index) => {
		const pinned = pins.includes(id);
		grid[id] = (
			<Button
				text={labelOf(id)}
				icon={pinned ? "Check" : undefined}
				onClick={() => {
					if (pinned) {
						setSelected(id);
					} else if (!full) {
						save([...pins, id]);
					}
				}}
				disabled={!pinned && full}
				color={pinned ? darken(accent, 0.55) : Palette.panelSoft}
				textColor={Palette.cream}
				outline={!pinned}
				size={new UDim2(cellW, -6, 0, TapTarget)}
				position={new UDim2(cellW * (index % cols), 0, 0, math.floor(index / cols) * (TapTarget + ROW_GAP))}
				reducedMotion={softMotion}
			/>
		);
	});

	const y0 = LABEL_H;
	const y1 = y0 + TapTarget + ROW_GAP;
	const y2 = y1 + TapTarget + ROW_GAP;
	const y3 = y2 + TapTarget + ROW_GAP;
	const third = 1 / 3;
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
			<Text
				value={`PHONE TAB BAR  ·  ${pins.size()}/${NavRoutes.MAX_MOBILE_TAB_PINS} PINNED`}
				size={11}
				color={accent}
				weight={Enum.FontWeight.Heavy}
				position={UDim2.fromOffset(0, 12)}
				sizeConstraint={new UDim2(1, 0, 0, 14)}
			/>
			<frame Size={new UDim2(1, 0, 0, TapTarget)} Position={UDim2.fromOffset(0, y0)} BackgroundTransparency={1}>
				{pinRow}
			</frame>
			<frame Size={new UDim2(1, 0, 0, TapTarget)} Position={UDim2.fromOffset(0, y1)} BackgroundTransparency={1}>
				<Button
					text="MOVE LEFT"
					icon="Chevron.3"
					onClick={() => move(-1)}
					disabled={chosen === undefined || pins.indexOf(chosen) === 0}
					color={Palette.panelSoft}
					textColor={Palette.creamSoft}
					outline={true}
					size={new UDim2(third, -6, 0, TapTarget)}
					reducedMotion={softMotion}
				/>
				<Button
					text="MOVE RIGHT"
					icon="Chevron.3"
					onClick={() => move(1)}
					disabled={chosen === undefined || pins.indexOf(chosen) === pins.size() - 1}
					color={Palette.panelSoft}
					textColor={Palette.creamSoft}
					outline={true}
					size={new UDim2(third, -6, 0, TapTarget)}
					position={new UDim2(third, 0, 0, 0)}
					reducedMotion={softMotion}
				/>
				<Button
					text={chosen !== undefined ? "UNPIN" : "CLEAR ALL"}
					icon="Hide.1"
					onClick={() => {
						if (chosen !== undefined) {
							save(pins.filter((id) => id !== chosen));
							setSelected(undefined);
						} else {
							save([]);
						}
					}}
					disabled={pins.size() === 0}
					color={Palette.panelSoft}
					textColor={Palette.creamSoft}
					outline={true}
					size={new UDim2(third, -6, 0, TapTarget)}
					position={new UDim2(third * 2, 0, 0, 0)}
					reducedMotion={softMotion}
				/>
			</frame>
			<SegmentedTabs
				options={NavRouteTable.NAV_GROUPS.map((g) => ({ id: g.key, label: g.label }))}
				value={group}
				onChange={(id: string) => setGroup(id)}
				accent={accent}
				gap={4}
				size={new UDim2(1, 0, 0, TapTarget)}
				position={UDim2.fromOffset(0, y2)}
				reducedMotion={softMotion}
			/>
			<frame Size={new UDim2(1, 0, 1, -y3)} Position={UDim2.fromOffset(0, y3)} BackgroundTransparency={1}>
				{grid}
			</frame>
		</frame>
	);
}

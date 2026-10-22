// Pieces shared by the Workshop and Research pages: the scrolling page body, the buy-amount
// picker, a search box, and the upgrade card with its quote and buy button. All built on the
// Forge2 primitives; buying still goes through the shared purchase planner (UpgradeTools).
import React from "@rbxts/react";
import Tools = require("../../UpgradeTools");
import Browse = require("../../BrowseKit");
import { Audio } from "../../AudioKit/audio";
import type { UpgradeEntry } from "../../CoreKit/appNav";
import { compactNumber } from "../../CoreKit/format";
import { useChangePop, useFlash, useListStagger } from "../../MotionKit/motion";
import { Button } from "../design/Button";
import { Card, Meter } from "../design/Panel";
import { AmountToggle } from "../../UiCore/ui";
import { Text } from "../design/Text";
import { Corner, Fonts, gap, HIT, Iron, Type } from "../design/tokens";
import { Burst } from "../motion/motion";
import { Tooltip } from "../design/Layers";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";

const UserInputService = game.GetService("UserInputService");

/** On a gamepad, park selection on the page's main action (the old FocusClaim hosts). */
export function useFocusClaim(enabled: boolean, deps: unknown[]): React.MutableRefObject<Frame | undefined> {
	const ref = React.useRef<Frame>();
	React.useEffect(() => {
		const host = ref.current;
		if (!enabled || host === undefined || !UserInputService.GamepadEnabled) return undefined;
		const job = task.defer(() => {
			if (host.Parent !== undefined) GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [enabled, ...deps]);
	return ref;
}


export type ModelEntry = Parameters<typeof Tools.Model.quote>[0];
export type ModelEntries = Parameters<typeof Tools.Model.filter>[0];

export function PageScroll(props: { phone: boolean; children?: React.ReactNode }) {
	const space = gap(props.phone, "l");
	return (
		<scrollingframe
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			CanvasSize={new UDim2()}
			AutomaticCanvasSize={Enum.AutomaticSize.Y}
			ScrollingDirection={Enum.ScrollingDirection.Y}
			ScrollBarThickness={props.phone ? 0 : 4}
			ScrollBarImageColor3={Iron.brassDeep()}
		>
			<uipadding PaddingTop={new UDim(0, space)} PaddingBottom={new UDim(0, space * 3)} PaddingLeft={new UDim(0, space)} PaddingRight={new UDim(0, space)} />
			<uilistlayout Padding={new UDim(0, space)} SortOrder={Enum.SortOrder.LayoutOrder} />
			{props.children}
		</scrollingframe>
	);
}

/** A wrapping row that holds controls side by side and lets them fall to new lines on phones. */
export function Row(props: { order?: number; spacing?: number; children?: React.ReactNode; align?: "Left" | "Right" }) {
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.order ?? 0}>
			<uilistlayout
				FillDirection={Enum.FillDirection.Horizontal}
				HorizontalAlignment={props.align === "Right" ? Enum.HorizontalAlignment.Right : Enum.HorizontalAlignment.Left}
				VerticalAlignment={Enum.VerticalAlignment.Center}
				Wraps
				Padding={new UDim(0, props.spacing ?? 8)}
				SortOrder={Enum.SortOrder.LayoutOrder}
			/>
			{props.children}
		</frame>
	);
}

export function AmountPicker(props: { value: number; onChange: (amount: number) => void; order?: number }) {
	// the current client's AmountToggle itself, so its slide and press motion match exactly
	return (
		<frame Size={new UDim2(1, 0, 0, HIT)} BackgroundTransparency={1} LayoutOrder={props.order ?? 0}>
			<uisizeconstraint MaxSize={new Vector2(320, HIT)} />
			<AmountToggle value={props.value} onChange={props.onChange} accent={Iron.brass()} size={UDim2.fromScale(1, 1)} />
		</frame>
	);
}

export function SearchBox(props: { value: string; onChange: (text: string) => void; hint: string; phone: boolean; order?: number }) {
	const [focused, setFocused] = React.useState(false);
	return (
		<frame Size={new UDim2(1, 0, 0, HIT)} BackgroundColor3={Iron.sunk()} BorderSizePixel={0} LayoutOrder={props.order ?? 0}>
			<uicorner CornerRadius={new UDim(0, Corner.card)} />
			<uistroke Color={focused ? Iron.brass() : Iron.edge()} Transparency={focused ? 0.2 : 0.6} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
			<textbox
				Size={new UDim2(1, -28, 1, 0)}
				Position={UDim2.fromOffset(14, 0)}
				BackgroundTransparency={1}
				Text={props.value}
				PlaceholderText={props.hint}
				PlaceholderColor3={Iron.muted()}
				TextColor3={Iron.text()}
				FontFace={Fonts.body}
				TextSize={Type.body(props.phone)}
				TextXAlignment={Enum.TextXAlignment.Left}
				ClearTextOnFocus={false}
				Change={{ Text: (box) => props.onChange(box.Text) }}
				Event={{ Focused: () => setFocused(true), FocusLost: () => setFocused(false) }}
			/>
		</frame>
	);
}

export interface UpgradeCardProps {
	entry: UpgradeEntry;
	index: number;
	amount: number;
	cash: unknown;
	phone: boolean;
	/** the one line under the name: what a level does */
	effect: string;
	accent: Color3;
	onBuy: (id: string) => void;
	busy: boolean;
	width: UDim2;
	/** shown under the name once maxed */
	maxedLine?: string;
	/** hover / gamepad tip on the card */
	tip?: string;
}

export function UpgradeCard(props: UpgradeCardProps) {
	const entry = props.entry;
	const reveal = useListStagger(props.index);
	const quote = Tools.Model.quote(entry as unknown as ModelEntry, props.amount, props.cash);
	const [buys, setBuys] = React.useState(0);
	const flash = useFlash(buys, false, 0.42);
	const levelPop = useChangePop(entry.level);
	const phone = props.phone;
	const label = entry.maxed
		? "Maxed"
		: !entry.unlocked
			? entry.lockShort !== "" ? entry.lockShort : "Locked"
			: quote.count > 1
				? `×${quote.count} · ${compactNumber(quote.cost)}`
				: compactNumber(quote.cost);
	const buy = () => {
		setBuys((n) => n + 1);
		Audio.play("purchase");
		Burst.spark(props.accent, 0.6);
		props.onBuy(entry.config.Id);
	};
	const levelText = `Lv ${compactNumber(entry.level)} / ${compactNumber(entry.config.MaxLevel)}`;
	return (
		<frame Size={props.width} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.index}>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} Position={reveal.map((p) => UDim2.fromOffset(0, (1 - p) * 12))}>
				<uiscale Scale={flash.map((v) => 1 + v * 0.025)} />
				<Card accent={entry.unlocked ? props.accent : Iron.muted()} selected={quote.ready} pad={gap(phone, "l")} spacing={gap(phone, "s")} rarity={entry.maxed ? "Mythic" : undefined}>
					<Text text={entry.config.Name} size={Type.body(phone) + 2} font={Fonts.heavy} color={entry.unlocked ? Iron.text() : Iron.soft()} order={0} />
					<Text text={entry.maxed ? (props.maxedLine ?? "Fully upgraded.") : entry.unlocked ? props.effect : entry.lockReason} size={Type.small(phone)} color={Iron.muted()} multiline order={1} />
					<frame Size={new UDim2(1, 0, 0, 20)} BackgroundTransparency={1} LayoutOrder={2}>
						<uiscale Scale={levelPop} />
						<Text text={levelText} size={Type.small(phone)} font={Fonts.heavy} color={props.accent} box={UDim2.fromScale(1, 1)} />
					</frame>
					<Meter value={entry.level / math.max(1, entry.config.MaxLevel)} color={props.accent} height={6} order={3} />
					<Tooltip tip={props.tip ?? (entry.unlocked ? `${entry.config.Name}: ${props.effect}` : entry.lockReason)} size={new UDim2(1, 0, 0, HIT)} order={4}>
						<Button text={entry.maxed ? "Maxed" : quote.ready ? (quote.count > 1 ? label : `Buy level · ${label}`) : label} onPress={buy} stretch disabled={!quote.ready || props.busy} glint={quote.ready} tone={quote.ready ? "brass" : "iron"} />
					</Tooltip>
				</Card>
			</frame>
		</frame>
	);
}

/** Cards per row: one on phones, more as the page widens. */
export function columnsFor(phone: boolean, width: number): number {
	if (phone) return 1;
	return width >= 1500 ? 3 : width >= 900 ? 2 : 1;
}

export function cellWidth(columns: number, spacing: number): UDim2 {
	return new UDim2(1 / columns, -(spacing * (columns - 1)) / columns, 0, 0);
}

export function useWidth(): [React.MutableRefObject<Frame | undefined>, number] {
	const ref = React.useRef<Frame>();
	const [width, setWidth] = React.useState(0);
	React.useEffect(() => {
		const host = ref.current;
		if (host === undefined) return undefined;
		setWidth(host.AbsoluteSize.X);
		const link = host.GetPropertyChangedSignal("AbsoluteSize").Connect(() => setWidth(host.AbsoluteSize.X));
		return () => link.Disconnect();
	}, []);
	return [ref, width];
}

export function Grid(props: { order?: number; spacing: number; children?: React.ReactNode; hostRef?: React.Ref<Frame> }) {
	return (
		<frame ref={props.hostRef} Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.order ?? 0}>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, props.spacing)} SortOrder={Enum.SortOrder.LayoutOrder} />
			{props.children}
		</frame>
	);
}

/** fuzzy text match from BrowseKit, typed */
export const matches = Browse.matches as (query: string, ...rest: unknown[]) => boolean;

export { Tools };

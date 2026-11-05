// The Rebirth page. The overview card shows the run at a glance; this page is the run itself:
// the current heat and streak, what's coming, and the chamber door. The panel below is the same
// card the overview carries, so the plan and the forge work exactly the same here.
import React from "@rbxts/react";
import { Flux } from "../../CoreKit/format";
import { chromeFor, Palette } from "../../CoreKit/theme";
import { useStagger, useViewport } from "../../MotionKit/motion";
import { kitMember, LuauComponent } from "../luauKits";
import { RebirthPanel } from "./RebirthPanel";

interface RebirthViewProps {
	state: {
		Rebirth?: {
			Heat?: number;
			Streak?: number;
			BestStreak?: number;
			TemperDue?: boolean;
			Lifetime?: number;
			StreakTarget?: number;
		};
		Rebirths?: number;
		ServerTime?: number;
		NextPrestigeTarget: Flux;
		RunCash: Flux;
		Vault: Flux;
		[key: string]: unknown;
	};
	config?: { [key: string]: unknown };
	dispatch: (action: string, payload?: object, callback?: (response: { ok?: boolean }) => void) => unknown;
	reducedMotion?: boolean;
	effectsPaused?: boolean;
	navigate?: (page: string) => void;
}

interface UiKit {
	Icon: LuauComponent;
	Text: LuauComponent;
}
const { Icon, Text } = kitMember<UiKit>("UiCore", "ui");

function StatChip(props: { label: string; value: string; accent: Color3; order: number; wide?: boolean }) {
	return (
		<frame
			LayoutOrder={props.order}
			Size={new UDim2(props.wide ? 1 : 0.5, props.wide ? 0 : -8, 0, 64)}
			BackgroundColor3={Palette.ink}
			BackgroundTransparency={0.3}
			BorderSizePixel={0}
			ZIndex={3}
		>
			<uicorner CornerRadius={new UDim(0, 10)} />
			<uistroke Color={props.accent} Transparency={0.6} />
			<Text
				value={props.value}
				size={22}
				color={props.accent}
				weight={Enum.FontWeight.Heavy}
				fit={false}
				position={UDim2.fromOffset(14, 8)}
				sizeConstraint={new UDim2(1, -28, 0, 26)}
				zIndex={4}
			/>
			<Text
				value={props.label}
				size={11}
				color={Palette.creamSoft}
				fit={false}
				position={UDim2.fromOffset(14, 38)}
				sizeConstraint={new UDim2(1, -28, 0, 16)}
				zIndex={4}
			/>
		</frame>
	);
}

export function RebirthView(props: RebirthViewProps) {
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const stack = chrome.contentStack;
	const info = props.state.Rebirth ?? {};
	const streak = tonumber(info.Streak) ?? 0;
	const heat = tonumber(info.Heat) ?? 0;
	const best = tonumber(info.BestStreak) ?? 0;
	const heroReveal = useStagger(0, props.reducedMotion);
	const pad = stack ? chrome.cardPadding : 22;
	return (
		<scrollingframe
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			CanvasSize={UDim2.fromOffset(0, 0)}
			AutomaticCanvasSize={Enum.AutomaticSize.Y}
			ScrollingDirection={Enum.ScrollingDirection.Y}
			ScrollBarThickness={3}
			ScrollBarImageColor3={Palette.violet}
		>
			<uipadding
				PaddingLeft={new UDim(0, pad)}
				PaddingRight={new UDim(0, pad)}
				PaddingTop={new UDim(0, pad)}
				PaddingBottom={new UDim(0, pad)}
			/>
			<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, stack ? 12 : 18)} />
			<frame LayoutOrder={1} Size={new UDim2(1, 0, 0, 84)} BackgroundTransparency={1} BorderSizePixel={0}>
				<Icon kind="Rebirth.9" size={64} position={UDim2.fromOffset(0, 8)} />
				<Text
					value="IGNITION"
					size={12}
					color={Palette.violet}
					weight={Enum.FontWeight.Heavy}
					fit={false}
					position={UDim2.fromOffset(78, 10)}
					sizeConstraint={new UDim2(1, -78, 0, 14)}
				/>
				<Text
					value={`Rebirth ${(tonumber(info.Lifetime) ?? tonumber(props.state.Rebirths) ?? 0) + 1}`}
					size={stack ? 24 : 30}
					color={Palette.cream}
					weight={Enum.FontWeight.Heavy}
					fit={false}
					position={UDim2.fromOffset(78, 26)}
					sizeConstraint={new UDim2(1, -78, 0, 34)}
				/>
				<Text
					value="Bank the run, keep the streak, temper the metal."
					size={12}
					color={Palette.creamSoft}
					fit={false}
					position={UDim2.fromOffset(78, 60)}
					sizeConstraint={new UDim2(1, -78, 0, 16)}
				/>
			</frame>
			<frame LayoutOrder={2} Size={new UDim2(1, 0, 0, 64)} BackgroundTransparency={1} BorderSizePixel={0}>
				<uilistlayout
					FillDirection={Enum.FillDirection.Horizontal}
					SortOrder={Enum.SortOrder.LayoutOrder}
					Padding={new UDim(0, 12)}
				/>
				<StatChip label="Streak" value={`×${streak}`} accent={streak > 0 ? Palette.mango : Palette.muted} order={1} />
				<StatChip label="Last run's heat" value={tostring(heat)} accent={heat >= 70 ? Palette.mint : Palette.cyan} order={2} />
			</frame>
			<StatChip
				label={info.TemperDue === true ? "A temper is waiting — open the chamber to choose" : `Best streak ×${best}`}
				value={info.TemperDue === true ? "Temper due" : `Streak pays +${math.floor(streak * 6)}% stardust`}
				accent={info.TemperDue === true ? Palette.mango : Palette.violet}
				order={3}
				wide={true}
			/>
			<RebirthPanel
				state={props.state}
				config={props.config as never}
				dispatch={props.dispatch}
				reducedMotion={props.reducedMotion}
				effectsPaused={props.effectsPaused}
				height={stack ? 240 : 210}
				reveal={heroReveal}
				openWorkshop={props.navigate !== undefined ? () => props.navigate!("Workshop") : undefined}
				layoutOrder={4}
			/>
		</scrollingframe>
	);
}

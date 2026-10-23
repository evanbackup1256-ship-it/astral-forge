// design/27-social pieces shared by the social shell and its pages (Chat, Crew, Guild, Mail).
//   .tabs / .tab  -> MockTabs     row avatar disc -> AvatarDisc     .pn sized to its rows -> FitPanel
import React from "@rbxts/react";
import { Palette, TapTarget } from "../CoreKit/theme";
import { useButtonChrome } from "../UiCore/ui";
import { BODY_BOLD, MockPanel, panelPad } from "../UiCore/mockKit";
import { useFlipperSpring } from "../MotionKit/motion";

/** .tab.on text (#1a0f0a) */
export const TAB_ON_TEXT = Color3.fromRGB(26, 15, 10);
/** .tabs well rgba(8,6,10,.7) */
const TABS_WELL = Color3.fromRGB(8, 6, 10);
/** row avatar #2a2030 */
export const AVATAR_FILL = Color3.fromRGB(42, 32, 48);

export interface MockTabOption {
	id: string;
	label: string;
}

function MockTab(p: { option: MockTabOption; on: boolean; accent: Color3; height: number; onPick: (id: string) => void; reducedMotion?: boolean; order: number }) {
	const chrome = useButtonChrome(() => p.onPick(p.option.id), p.reducedMotion === true, false, "tabSwitch", false);
	const lit = useFlipperSpring(p.on ? 1 : 0, p.reducedMotion, 700, 38);
	return (
		<imagebutton
			Size={UDim2.fromOffset(0, p.height)}
			AutomaticSize={Enum.AutomaticSize.X}
			BackgroundColor3={p.accent}
			BackgroundTransparency={lit.map((a) => 1 - a)}
			AutoButtonColor={false}
			Image=""
			BorderSizePixel={0}
			LayoutOrder={p.order}
			Event={chrome.events}
		>
			<uicorner CornerRadius={new UDim(0, 10)} />
			{/* .tab.on: linear-gradient(180deg, accent, accent 70% dark) */}
			<uigradient
				Rotation={90}
				Color={new ColorSequence(Palette.white, Color3.fromRGB(178, 178, 178))}
			/>
			<uipadding PaddingLeft={new UDim(0, 18)} PaddingRight={new UDim(0, 18)} />
			<textlabel
				Size={new UDim2(0, 0, 1, 0)}
				AutomaticSize={Enum.AutomaticSize.X}
				BackgroundTransparency={1}
				Text={p.option.label}
				FontFace={BODY_BOLD}
				TextSize={14}
				TextColor3={p.on ? TAB_ON_TEXT : chrome.hovered ? Palette.cream : Palette.muted}
			/>
		</imagebutton>
	);
}

/** af.css .tabs: a 4px-padded dark well (radius 14, white .06 ring) of .tab pills; the picked one is lit. */
export function MockTabs(p: {
	options: MockTabOption[];
	value: string;
	onChange: (id: string) => void;
	accent?: Color3;
	phone: boolean;
	reducedMotion?: boolean;
	layoutOrder?: number;
	fill?: boolean;
}) {
	// .tab min-height 40; phones keep the full tap target
	const tabH = p.phone ? TapTarget : 40;
	return (
		<frame

			Size={p.fill === true ? new UDim2(1, 0, 0, tabH + 8) : UDim2.fromOffset(0, tabH + 8)}
			AutomaticSize={p.fill === true ? Enum.AutomaticSize.None : Enum.AutomaticSize.X}
			BackgroundColor3={TABS_WELL}
			BackgroundTransparency={0.3}
			BorderSizePixel={0}
			LayoutOrder={p.layoutOrder ?? 0}
		>
			<uicorner CornerRadius={new UDim(0, 14)} />
			<uistroke Color={Palette.white} Transparency={0.94} Thickness={1} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
			<uipadding PaddingLeft={new UDim(0, 4)} PaddingRight={new UDim(0, 4)} PaddingTop={new UDim(0, 4)} PaddingBottom={new UDim(0, 4)} />
			<uilistlayout
				FillDirection={Enum.FillDirection.Horizontal}
				Padding={new UDim(0, 4)}
				VerticalAlignment={Enum.VerticalAlignment.Center}
				HorizontalFlex={p.fill === true ? Enum.UIFlexAlignment.Fill : Enum.UIFlexAlignment.None}
				SortOrder={Enum.SortOrder.LayoutOrder}
			/>
			{p.options.map((option, index) => (
				<MockTab
					key={option.id}
					option={option}
					on={option.id === p.value}
					accent={p.accent ?? Palette.mint}
					height={tabH}
					onPick={p.onChange}
					reducedMotion={p.reducedMotion}
					order={index}
				/>
			))}
		</frame>
	);
}

/** Row avatar: a 30px #2a2030 disc with a 1.5px brass .4 ring and the player's headshot. */
export function AvatarDisc(p: { userId?: number; size?: number; ring?: Color3; ringTransparency?: number; layoutOrder?: number }) {
	const s = p.size ?? 30;
	return (
		<imagelabel
			Size={UDim2.fromOffset(s, s)}
			BackgroundColor3={AVATAR_FILL}
			BorderSizePixel={0}
			Image={p.userId !== undefined && p.userId > 0 ? `rbxthumb://type=AvatarHeadShot&id=${p.userId}&w=48&h=48` : ""}
			LayoutOrder={p.layoutOrder ?? 0}
		>
			<uicorner CornerRadius={new UDim(1, 0)} />
			<uistroke Color={p.ring ?? Palette.brass} Thickness={1.5} Transparency={p.ringTransparency ?? 0.6} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
		</imagelabel>
	);
}

/** A MockPanel whose height is its heading plus `rows` stacked rows (`rowH` each, `gap` apart) and `extra` px. */
export function fitPanelHeight(phone: boolean, headingH: number, rowHeights: number[], extra = 0): number {
	const pad = panelPad(phone);
	let content = headingH;
	for (const h of rowHeights) {
		content += pad.gap + h;
	}
	return content + extra + pad.y * 2;
}

export function FitPanel(p: { height: number; phone: boolean; accent?: Color3; layoutOrder?: number; name?: string; reducedMotion?: boolean; flex?: boolean; children?: React.ReactNode }) {
	return (
		<MockPanel
			size={new UDim2(1, 0, 0, p.height)}
			phone={p.phone}
			accent={p.accent}
			layoutOrder={p.layoutOrder}
			name={p.name}
			reducedMotion={p.reducedMotion}
			flex={p.flex}
		>
			{p.children}
		</MockPanel>
	);
}

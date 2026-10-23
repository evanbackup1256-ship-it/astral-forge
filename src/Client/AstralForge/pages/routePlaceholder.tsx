// A routed page whose screen hasn't been ported yet: one centred card (icon, title, one line, a way
// back) inside the normal page scaffold, so it scrolls and fits like every other page.
import React from "@rbxts/react";
import { chromeFor, Palette, scrollTail, surfaceGradient } from "../CoreKit/theme";
import { useViewport } from "../MotionKit/motion";
import { RimLight, SoftShadow } from "../UiCore/depth";
import { loadPageScaffold, loadUi } from "./luauDeps";

const PageScaffold = loadPageScaffold();
const { Button, Text } = loadUi();
const Icon = (require(script.Parent!.Parent!.WaitForChild("ArtKit") as ModuleScript) as (name: string) => {
	Icon: React.FunctionComponent<Record<string, unknown>>;
})("Icon").Icon;

export const SERIF = new Font("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold);

export interface PlaceholderPageProps {
	id: string;
	icon: string;
	title: string;
	body: string;
	accent: Color3;
	navigate?: (page: string) => unknown;
	reducedMotion?: boolean;
}

export function PlaceholderPage(props: PlaceholderPageProps) {
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const phone = chrome.mobile;
	const cardH = phone ? 236 : 300;
	const iconBox = phone ? 56 : 72;
	const card = (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.panel} BorderSizePixel={0}>
			<uicorner CornerRadius={new UDim(0, 18)} />
			<uigradient Color={surfaceGradient(Palette.panel, 0.7)} Rotation={90} />
			<SoftShadow radius={18} />
			<RimLight color={Palette.line} inner={Palette.brass} />
			<uilistlayout
				FillDirection={Enum.FillDirection.Vertical}
				HorizontalAlignment={Enum.HorizontalAlignment.Center}
				VerticalAlignment={Enum.VerticalAlignment.Center}
				Padding={new UDim(0, phone ? 8 : 12)}
				SortOrder={Enum.SortOrder.LayoutOrder}
			/>
			<uipadding PaddingLeft={new UDim(0, 20)} PaddingRight={new UDim(0, 20)} />
			<frame
				LayoutOrder={1}
				Size={UDim2.fromOffset(iconBox, iconBox)}
				BackgroundColor3={Palette.panelRaised}
				BackgroundTransparency={0.2}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(0, 16)} />
				<uistroke Color={props.accent} Transparency={0.55} Thickness={1} />
				<Icon kind={props.icon} size={math.floor(iconBox * 0.6)} accent={props.accent} position={UDim2.fromScale(0.5, 0.5)} anchorPoint={new Vector2(0.5, 0.5)} reducedMotion={props.reducedMotion} />
			</frame>
			<textlabel
				LayoutOrder={2}
				Size={new UDim2(1, 0, 0, phone ? 30 : 38)}
				BackgroundTransparency={1}
				FontFace={SERIF}
				Text={props.title}
				TextColor3={Palette.cream}
				TextSize={phone ? 24 : 30}
				TextScaled={false}
				TextTruncate={Enum.TextTruncate.AtEnd}
			/>
			<Text
				layoutOrder={3}
				value={props.body}
				size={phone ? 13 : 15}
				color={Palette.muted}
				align={Enum.TextXAlignment.Center}
				wrap={true}
				fit={false}
				sizeConstraint={new UDim2(1, 0, 0, phone ? 36 : 40)}
			/>
			<frame LayoutOrder={4} Size={UDim2.fromOffset(phone ? 200 : 220, 44)} BackgroundTransparency={1}>
				<Button
					text="Back to the Forge"
					icon="Forge.3"
					color={Palette.brass}
					textColor={Palette.ink}
					size={UDim2.fromScale(1, 1)}
					reducedMotion={props.reducedMotion}
					onClick={() => props.navigate?.("Workshop")}
				/>
			</frame>
		</frame>
	);
	return (
		<PageScaffold
			gap={16}
			tailPad={scrollTail(chrome.contentStack, chrome.bottomSafe, 40)}
			scrollBarColor={Palette.lineSoft}
			sections={[{ id: `${props.id}Placeholder`, height: cardH, element: card }]}
		/>
	);
}

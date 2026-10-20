import React from "@rbxts/react";
import { FrameStroke, frameStroke } from "../../CoreKit/profileFrame";
import { PlayerMark } from "../../ArtKit/Icon";
import { Palette, Radius, TapTarget } from "../../CoreKit/theme";
import * as ProfileStyle from "../../../../Shared/AstralForge/Shared/ProfileStyle";
import { kitMember, LuauComponent } from "../luauKits";

const Players = game.GetService("Players");

const { Button, Text } = kitMember<{ Button: LuauComponent; Text: LuauComponent }>("UiCore", "ui");

export interface ProfileStylePanelProps {
	cosmetics: unknown;
	rebirths: unknown;
	dispatch: (action: string, payload?: object) => unknown;
	stack: boolean;
	reducedMotion?: boolean;
}

const SWATCH = TapTarget;
const SWATCH_GAP = 10;
const FRAME_BTN_W = 132;
const PREVIEW_H = 64;
// the three places other players see your style, drawn small under the main preview
const SAMPLE_H = 46;
const SAMPLE_GAP = 8;

// header + hint, preview, accent row, frame row
export function profileStyleHeight(stack: boolean): number {
	return 26 + 22 + 10 + PREVIEW_H + SAMPLE_GAP + SAMPLE_H + 14 + 18 + SWATCH + 6 + 14 + 18 + TapTarget + 4 + (stack ? 8 : 0);
}

function unlockHint(unlock: ProfileStyle.StyleUnlock): string {
	return unlock.Kind === "Free" ? "" : `${unlock.Target} rebirths`;
}

function StyleSample(props: { order: number; label: string; ring: FrameStroke; accent: Color3; kind: "card" | "mark" | "row"; name: string }) {
	const { ring, accent } = props;
	const stroke = (thickness: number, transparency: number) => (
		<uistroke Color={ring.color} Thickness={thickness} Transparency={transparency}>
			{ring.gradient !== undefined && <uigradient Color={ring.gradient} Rotation={35} />}
		</uistroke>
	);
	const mark = props.kind === "mark";
	return (
		<frame
			Size={new UDim2(1 / 3, -math.ceil((SAMPLE_GAP * 2) / 3), 1, 0)}
			LayoutOrder={props.order}
			BackgroundColor3={props.kind === "row" ? Palette.panel : Palette.panelSoft}
			BackgroundTransparency={0.2}
			BorderSizePixel={0}
		>
			<uicorner CornerRadius={new UDim(0, Radius.md)} />
			{!mark && stroke(ring.thickness, ring.framed ? 0.45 : 0.8)}
			{mark ? (
				<frame Size={UDim2.fromOffset(26, 26)} Position={new UDim2(0, 8, 0.5, 0)} AnchorPoint={new Vector2(0, 0.5)} BackgroundColor3={accent} BackgroundTransparency={0.55} BorderSizePixel={0}>
					<uicorner CornerRadius={new UDim(1, 0)} />
					{stroke(ring.thickness, 0.2)}
				</frame>
			) : (
				<Text value={props.kind === "row" ? "1" : "·"} size={12} color={Palette.muted} weight={Enum.FontWeight.Bold} fit={false} align={Enum.TextXAlignment.Center} position={UDim2.fromOffset(4, 14)} sizeConstraint={UDim2.fromOffset(20, 18)} />
			)}
			<Text value={props.label} size={10} color={Palette.muted} weight={Enum.FontWeight.Bold} fit={true} minSize={8} position={UDim2.fromOffset(mark ? 40 : 26, 6)} sizeConstraint={new UDim2(1, mark ? -46 : -32, 0, 14)} />
			<Text value={props.name} size={12} color={accent} weight={Enum.FontWeight.Heavy} fit={true} minSize={9} position={UDim2.fromOffset(mark ? 40 : 26, 22)} sizeConstraint={new UDim2(1, mark ? -46 : -32, 0, 16)} />
		</frame>
	);
}

export function ProfileStylePanel(props: ProfileStylePanelProps) {
	const saved = ProfileStyle.read(props.cosmetics);
	// show the pick straight away; the server snapshot confirms or reverts it
	const [pending, setPending] = React.useState<ProfileStyle.ProfileStyleState | undefined>(undefined);
	React.useEffect(() => {
		setPending(undefined);
	}, [saved.Accent, saved.Frame]);
	const shown = pending ?? saved;
	const accentColor = ProfileStyle.accentColor(shown.Accent);
	const frame = ProfileStyle.findFrame(shown.Frame) ?? ProfileStyle.FRAMES[0];
	const ring = frameStroke(frame, accentColor);
	const choose = (accent?: string, frameId?: string) => {
		setPending({ Accent: accent ?? shown.Accent, Frame: frameId ?? shown.Frame });
		props.dispatch("SetProfileStyle", { Accent: accent, Frame: frameId });
	};
	const localName = Players.LocalPlayer !== undefined ? Players.LocalPlayer.DisplayName : "You";

	const accentTop = 26 + 22 + 10 + PREVIEW_H + SAMPLE_GAP + SAMPLE_H + 14;
	const samplesTop = 26 + 22 + 10 + PREVIEW_H + SAMPLE_GAP;
	const frameTop = accentTop + 18 + SWATCH + 6 + 14;

	const swatches = ProfileStyle.ACCENTS.map((option, index) => {
		const unlocked = ProfileStyle.isUnlocked(option.Unlock, props.rebirths);
		const selected = option.Id === shown.Accent;
		const color = Color3.fromRGB(option.Rgb[0], option.Rgb[1], option.Rgb[2]);
		return (
			<imagebutton
				key={option.Id}
				Size={UDim2.fromOffset(SWATCH, SWATCH)}
				Position={UDim2.fromOffset(index * (SWATCH + SWATCH_GAP), 2)}
				BackgroundColor3={color}
				BackgroundTransparency={unlocked ? 0 : 0.7}
				AutoButtonColor={unlocked}
				BorderSizePixel={0}
				Event={{
					Activated: () => {
						if (unlocked && !selected) {
							choose(option.Id, undefined);
						}
					},
				}}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke Color={selected ? Palette.cream : Palette.lineSoft} Thickness={selected ? 3 : 1} Transparency={selected ? 0 : 0.4} />
				{!unlocked && (
					<Text
						value={unlockHint(option.Unlock)}
						size={9}
						minSize={7}
						color={Palette.cream}
						fit={true}
						align={Enum.TextXAlignment.Center}
						sizeConstraint={UDim2.fromScale(1, 1)}
					/>
				)}
			</imagebutton>
		);
	});

	// the frame row scrolls sideways like the accent row, so more frames never overflow a phone
	const frameButtons = ProfileStyle.FRAMES.map((option, index) => {
		const unlocked = ProfileStyle.isUnlocked(option.Unlock, props.rebirths);
		const selected = option.Id === shown.Frame;
		return (
			<frame
				key={option.Id}
				Size={UDim2.fromOffset(FRAME_BTN_W, TapTarget)}
				Position={UDim2.fromOffset(index * (FRAME_BTN_W + 8), 0)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
			>
				<Button
					text={unlocked ? option.Name : `${option.Name} · ${unlockHint(option.Unlock)}`}
					onClick={() => {
						if (unlocked && !selected) {
							choose(undefined, option.Id);
						}
					}}
					disabled={!unlocked}
					color={selected ? accentColor : Palette.panelSoft}
					textColor={selected ? Palette.ink : Palette.cream}
					outline={!selected}
					size={UDim2.fromScale(1, 1)}
					reducedMotion={props.reducedMotion}
				/>
			</frame>
		);
	});

	return (
		<>
			<Text
				value="Your accent and frame show on your nameplate, in the player list and in chat."
				size={11}
				minSize={8}
				color={Palette.muted}
				fit={props.stack}
				position={UDim2.fromOffset(0, 26)}
				sizeConstraint={new UDim2(1, 0, 0, 18)}
			/>
			<frame
				Size={new UDim2(1, 0, 0, PREVIEW_H)}
				Position={UDim2.fromOffset(0, 26 + 22 + 10)}
				BackgroundColor3={Palette.panelSoft}
				BackgroundTransparency={0.2}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(0, 14)} />
				{/* drawn exactly as the player list, chat and ranks draw it */}
				<uistroke Color={ring.color} Thickness={ring.thickness} Transparency={0.1}>
					{ring.gradient !== undefined && <uigradient Color={ring.gradient} Rotation={35} />}
				</uistroke>
				<frame
					Size={UDim2.fromOffset(44, 44)}
					Position={new UDim2(0, 10, 0.5, 0)}
					AnchorPoint={new Vector2(0, 0.5)}
					BackgroundColor3={accentColor}
					BackgroundTransparency={0.55}
					BorderSizePixel={0}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
					<uistroke Color={ring.color} Thickness={ring.thickness + 1}>
						{ring.gradient !== undefined && <uigradient Color={ring.gradient} Rotation={35} />}
					</uistroke>
					<PlayerMark userId={Players.LocalPlayer?.UserId ?? 0} color={Palette.ink} accent={accentColor} size={30} position={UDim2.fromScale(0.5, 0.5)} anchorPoint={new Vector2(0.5, 0.5)} />
				</frame>
				<Text
					value={localName}
					size={18}
					minSize={12}
					color={accentColor}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					align={Enum.TextXAlignment.Left}
					position={UDim2.fromOffset(66, 10)}
					sizeConstraint={new UDim2(1, -76, 0, 24)}
				/>
				<Text
					value={`${ProfileStyle.findAccent(shown.Accent)?.Name ?? ""}  ·  ${frame.Name} frame`}
					size={12}
					color={Palette.creamSoft}
					fit={false}
					align={Enum.TextXAlignment.Left}
					position={UDim2.fromOffset(66, 36)}
					sizeConstraint={new UDim2(1, -76, 0, 18)}
				/>
			</frame>
			<frame Size={new UDim2(1, 0, 0, SAMPLE_H)} Position={UDim2.fromOffset(0, samplesTop)} BackgroundTransparency={1} BorderSizePixel={0}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, SAMPLE_GAP)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<StyleSample order={1} label="Player list" ring={ring} accent={accentColor} kind="card" name={localName} />
				<StyleSample order={2} label="Chat" ring={ring} accent={accentColor} kind="mark" name={localName} />
				<StyleSample order={3} label="Ranks" ring={ring} accent={accentColor} kind="row" name={localName} />
			</frame>
			<Text value="Accent" size={12} color={Palette.creamSoft} weight={Enum.FontWeight.Bold} fit={false} position={UDim2.fromOffset(0, accentTop)} sizeConstraint={new UDim2(1, 0, 0, 16)} />
			<scrollingframe
				Size={new UDim2(1, 0, 0, SWATCH + 6)}
				Position={UDim2.fromOffset(0, accentTop + 18)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ScrollingDirection={Enum.ScrollingDirection.X}
				ScrollBarThickness={2}
				ScrollBarImageColor3={accentColor}
				CanvasSize={UDim2.fromOffset(ProfileStyle.ACCENTS.size() * (SWATCH + SWATCH_GAP), 0)}
				ClipsDescendants={true}
			>
				{swatches}
			</scrollingframe>
			<Text value="Frame" size={12} color={Palette.creamSoft} weight={Enum.FontWeight.Bold} fit={false} position={UDim2.fromOffset(0, frameTop)} sizeConstraint={new UDim2(1, 0, 0, 16)} />
			<scrollingframe
				Size={new UDim2(1, 0, 0, TapTarget + 4)}
				Position={UDim2.fromOffset(0, frameTop + 18)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ScrollingDirection={Enum.ScrollingDirection.X}
				ScrollBarThickness={2}
				ScrollBarImageColor3={accentColor}
				CanvasSize={UDim2.fromOffset(ProfileStyle.FRAMES.size() * (FRAME_BTN_W + 8), 0)}
				ClipsDescendants={true}
			>
				{frameButtons}
			</scrollingframe>
		</>
	);
}

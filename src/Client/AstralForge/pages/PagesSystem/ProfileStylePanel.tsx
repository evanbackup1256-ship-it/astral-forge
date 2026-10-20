import React from "@rbxts/react";
import { Palette, TapTarget } from "../../CoreKit/theme";
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
const FRAME_BTN_W = 112;
const PREVIEW_H = 64;

// header + hint, preview, accent row, frame row
export function profileStyleHeight(stack: boolean): number {
	return 26 + 22 + 10 + PREVIEW_H + 14 + 18 + SWATCH + 6 + 14 + 18 + TapTarget + (stack ? 8 : 0);
}

function unlockHint(unlock: ProfileStyle.StyleUnlock): string {
	return unlock.Kind === "Free" ? "" : `${unlock.Target} rebirths`;
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
	const choose = (accent?: string, frameId?: string) => {
		setPending({ Accent: accent ?? shown.Accent, Frame: frameId ?? shown.Frame });
		props.dispatch("SetProfileStyle", { Accent: accent, Frame: frameId });
	};
	const localName = Players.LocalPlayer !== undefined ? Players.LocalPlayer.DisplayName : "You";

	const accentTop = 26 + 22 + 10 + PREVIEW_H + 14;
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

	const frameButtons = ProfileStyle.FRAMES.map((option, index) => {
		const unlocked = ProfileStyle.isUnlocked(option.Unlock, props.rebirths);
		const selected = option.Id === shown.Frame;
		return (
			<frame
				key={option.Id}
				Size={UDim2.fromOffset(FRAME_BTN_W, TapTarget)}
				Position={UDim2.fromOffset(index * (FRAME_BTN_W + 8), frameTop + 18)}
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
				color={Palette.muted}
				fit={false}
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
				<uicorner CornerRadius={new UDim(0, 12)} />
				<uistroke Color={accentColor} Thickness={frame.Thickness} Transparency={0.1}>
					{frame.Gradient && (
						<uigradient
							Color={new ColorSequence([
								new ColorSequenceKeypoint(0, accentColor),
								new ColorSequenceKeypoint(0.5, Palette.cream),
								new ColorSequenceKeypoint(1, accentColor),
							])}
							Rotation={20}
						/>
					)}
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
					<uistroke Color={accentColor} Thickness={frame.Thickness + 1} />
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
			{frameButtons}
		</>
	);
}

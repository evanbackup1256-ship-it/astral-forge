// Purpose: the revamp sprite card (.sc): an animated 6x6 sprite sheet in a rarity-stroked tile with
// a name and a rarity tag. Selected lifts 4px and takes a full-strength stroke plus a glow.
import React from "@rbxts/react";
import { SpriteClip2 } from "../ArtKit/SpriteClip2";
import { Palette } from "../CoreKit/theme";
import { isReducedMotion } from "../MotionPreference";
import { Glow, SoftShadow } from "./depth";
import * as ForgeTheme from "../../../Shared/AstralForge/Shared/ForgeTheme";

const SHEET_SIZE = 1024;

export interface SpriteCardProps {
	sheet: string;
	name: string;
	rarity: string;
	columns?: number;
	count?: number;
	frameRate?: number;
	selected?: boolean;
	size?: UDim2;
	layoutOrder?: number;
	onPress?: () => void;
}

export function rarityColor(rarity: string): Color3 {
	return ForgeTheme.Rarity[rarity] ?? Palette.lineSoft;
}

export function SpriteCard(props: SpriteCardProps) {
	const imageRef = React.useRef<ImageLabel>();
	const columns = props.columns ?? 6;
	const count = props.count ?? 36;
	const frame = SHEET_SIZE / columns;
	const tint = rarityColor(props.rarity);
	const selected = props.selected === true;
	React.useEffect(() => {
		const image = imageRef.current;
		if (image === undefined) {
			return undefined;
		}
		const sprite = SpriteClip2.ImageSprite.new({
			adornee: image,
			spriteSheetId: props.sheet,
			currentFrame: 1,
			spriteSize: new Vector2(frame, frame),
			spriteOffset: Vector2.zero,
			edgeOffset: Vector2.zero,
			spriteCount: count,
			columnCount: columns,
			frameRate: props.frameRate ?? 24,
			isLooped: true,
		});
		if (isReducedMotion()) {
			sprite.SetFrame(1);
		} else {
			sprite.Play(1);
		}
		return () => sprite.Destroy();
	}, [props.sheet, columns, count]);
	return (
		<textbutton
			Text=""
			AutoButtonColor={false}
			BackgroundTransparency={1}
			Size={props.size ?? UDim2.fromOffset(150, 196)}
			LayoutOrder={props.layoutOrder}
			Event={{ Activated: () => props.onPress?.() }}
		>
			<frame
				key="Body"
				Position={UDim2.fromOffset(0, selected ? -4 : 0)}
				Size={UDim2.fromScale(1, 1)}
				BackgroundColor3={Palette.panelRaised}
				BorderSizePixel={0}
			>
				{selected ? <Glow color={tint} radius={14} /> : <SoftShadow radius={14} spread={10} drop={6} />}
				<uicorner CornerRadius={new UDim(0, 14)} />
				<uigradient
					Rotation={90}
					Color={new ColorSequence(Palette.panelRaised, Palette.panel)}
				/>
				<uistroke Color={tint} Thickness={1.5} Transparency={selected ? 0 : 0.45} />
				<imagelabel
					key="Sprite"
					ref={imageRef}
					BackgroundTransparency={1}
					AnchorPoint={new Vector2(0.5, 0)}
					Position={new UDim2(0.5, 0, 0, 10)}
					Size={new UDim2(1, -20, 1, -64)}
					ScaleType={Enum.ScaleType.Fit}
					Image={props.sheet}
					ImageRectSize={new Vector2(frame, frame)}
					ZIndex={2}
				/>
				<textlabel
					key="Name"
					BackgroundTransparency={1}
					Position={new UDim2(0, 10, 1, -50)}
					Size={new UDim2(1, -20, 0, 22)}
					FontFace={new Font("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)}
					Text={props.name}
					TextColor3={Palette.cream}
					TextSize={16}
					TextTruncate={Enum.TextTruncate.AtEnd}
					ZIndex={2}
				/>
				<textlabel
					key="Rarity"
					BackgroundTransparency={1}
					Position={new UDim2(0, 10, 1, -26)}
					Size={new UDim2(1, -20, 0, 16)}
					FontFace={new Font("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)}
					Text={string.upper(props.rarity)}
					TextColor3={tint}
					TextSize={11}
					ZIndex={2}
				/>
			</frame>
		</textbutton>
	);
}

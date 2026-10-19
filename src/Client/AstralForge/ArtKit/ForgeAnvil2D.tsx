import React from "@rbxts/react";
import { ImageSprite, SpriteClip2 } from "./SpriteClip2";
import { FORGE_RIG_ART_SCALE, FORGE_RIG_LOOP_SECONDS, ForgeRig2D, ForgeRig2DProps } from "./ForgeRig2D";
import { ScaleFromCenter, useSprScale } from "../MotionKit/motion";
import { Palette } from "../CoreKit/theme";

const STATIC_FORGE_IMAGE = "rbxassetid://112120837024079";
const FORGE_V9_SPRITE_SHEET_ASSET_ID: number = 121741065241026;
export const FORGE_V10_SPRITE_SHEET_ASSET_ID: number = 138110704320197;
export const FORGE_V10_FINALE_SPRITE_SHEET_ASSET_ID: number = 97397846255311;
export const FORGE_V11_PARTS_ATLAS_ASSET_ID: number = 104699600841724;
export const FORGE_ASSET_MANIFEST = [
	`rbxassetid://112120837024079`,
	`rbxassetid://${FORGE_V9_SPRITE_SHEET_ASSET_ID}`,
	`rbxassetid://${FORGE_V10_SPRITE_SHEET_ASSET_ID}`,
	`rbxassetid://${FORGE_V10_FINALE_SPRITE_SHEET_ASSET_ID}`,
	`rbxassetid://${FORGE_V11_PARTS_ATLAS_ASSET_ID}`,
];
export const FORGE_SPRITE_SHEET_ASSET_ID =
	FORGE_V10_SPRITE_SHEET_ASSET_ID > 0 ? FORGE_V10_SPRITE_SHEET_ASSET_ID : FORGE_V9_SPRITE_SHEET_ASSET_ID;
const FRAME_COUNT = 25;
const COLUMN_COUNT = 5;
const FRAME_RATE = 16;
const IMPACT_FRAME = 15;
const WINDUP_FRAME = 8;
const SPARK_FRAME = 18;
const FRAME_EDGE = 204;
const FRAME_SIZE = new Vector2(FRAME_EDGE, FRAME_EDGE);
const HALF_FRAME_SIZE = new Vector2(FRAME_EDGE, FRAME_EDGE / 2);
export const FORGE_LOOP_SECONDS = FORGE_V11_PARTS_ATLAS_ASSET_ID > 0 ? FORGE_RIG_LOOP_SECONDS : FRAME_COUNT / FRAME_RATE;
export const FORGE_FINALE_SECONDS = 2.15;
export const FORGE_FINALE_CONTACT = 18 / 24;
export const FORGE_ART_SCALE = FORGE_V11_PARTS_ATLAS_ASSET_ID > 0 ? FORGE_RIG_ART_SCALE : 0.84;
const FINALE_IMPACT_END = 1;

function assetUri(id: number) {
	return `rbxassetid://${id}`;
}
function clamp01(value: number) {
	return math.clamp(value, 0, 1);
}
function range(value: number, start: number, finish: number) {
	return clamp01((value - start) / math.max(0.001, finish - start));
}
function phasePulse(value: number, start: number, peak: number, finish: number) {
	if (value <= start || value >= finish) {
		return 0;
	}
	return value <= peak ? range(value, start, peak) : 1 - range(value, peak, finish);
}
function smooth(value: number) {
	const t = clamp01(value);
	return t * t * (3 - 2 * t);
}
function easeInCubic(value: number) {
	const t = clamp01(value);
	return t * t * t;
}
function hammerPose(value: number): { position: UDim2; rotation: number; scale: number } {
	const amount = clamp01(value);
	if (amount <= 0.1) {
		const t = 1 - math.pow(1 - range(amount, 0, 0.1), 3);
		return { position: UDim2.fromScale(0.78 + t * 0.035, 0.255 - t * 0.055), rotation: -12 - 32 * t, scale: 0.96 - t * 0.055 };
	}
	if (amount <= 0.54) {
		const t = smooth(range(amount, 0.1, 0.54));
		const arc = math.sin(t * math.pi);
		return {
			position: UDim2.fromScale(0.815 - arc * 0.12 - t * 0.055, 0.2 - arc * 0.15 + t * 0.005),
			rotation: -44 + t * 914,
			scale: 0.905 + arc * 0.16,
		};
	}
	if (amount <= 0.62) {
		const t = smooth(range(amount, 0.54, 0.62));
		return { position: UDim2.fromScale(0.76 + t * 0.015, 0.205 - t * 0.018), rotation: 870 + t * 28, scale: 0.905 + t * 0.04 };
	}
	const t = easeInCubic(range(amount, 0.62, FORGE_FINALE_CONTACT));
	return { position: UDim2.fromScale(0.775 - t * 0.035, 0.187 + t * 0.22), rotation: 898 + t * 127, scale: 0.945 + t * 0.105 };
}
function impactFrameOffset(amount: number) {
	const frame = 15 + math.floor(range(amount, FORGE_FINALE_CONTACT, FINALE_IMPACT_END) * 10);
	const zeroBased = math.clamp(frame, 15, 25) - 1;
	return new Vector2((zeroBased % COLUMN_COUNT) * FRAME_SIZE.X, math.floor(zeroBased / COLUMN_COUNT) * FRAME_SIZE.Y);
}
function finaleFrameOffset(amount: number) {
	const zeroBased = math.clamp(math.floor(clamp01(amount) * (FRAME_COUNT - 1)), 0, FRAME_COUNT - 1);
	return new Vector2((zeroBased % COLUMN_COUNT) * FRAME_SIZE.X, math.floor(zeroBased / COLUMN_COUNT) * FRAME_SIZE.Y);
}

type ForgeAnvil2DProps = Omit<ForgeRig2DProps, "atlasId">;

export function ForgeAnvil2D(props: ForgeAnvil2DProps) {
	if (FORGE_V11_PARTS_ATLAS_ASSET_ID > 0) {
		return <ForgeRig2D {...props} atlasId={FORGE_V11_PARTS_ATLAS_ASSET_ID} />;
	}
	return <ForgeAnvil2DView {...props} />;
}

function ForgeAnvil2DView({
	size,
	position,
	reducedMotion,
	exiting = false,
	finaleActive = false,
	finaleTimeline,
	fade,
	onWindup,
	onStrike,
	onSpark,
	zIndex = 520,
}: ForgeAnvil2DProps) {
	const imageRef = React.useRef<ImageLabel>();
	const blendImageRef = React.useRef<ImageLabel>();
	const spriteRef = React.useRef<ImageSprite>();
	const windupRef = React.useRef(onWindup);
	const strikeRef = React.useRef(onStrike);
	const sparkRef = React.useRef(onSpark);
	const exitingRef = React.useRef(exiting);
	const fadeRef = React.useRef(fade);
	windupRef.current = onWindup;
	strikeRef.current = onStrike;
	sparkRef.current = onSpark;
	exitingRef.current = exiting;
	fadeRef.current = fade;
	const spriteConfigured = FORGE_SPRITE_SHEET_ASSET_ID > 0;
	const finaleConfigured = FORGE_V10_FINALE_SPRITE_SHEET_ASSET_ID > 0;
	const artSprRef = useSprScale(1, reducedMotion, 0.9, 0.7, 7.5);
	React.useEffect(() => {
		const image = imageRef.current;
		const blendImage = blendImageRef.current;
		if (image === undefined || blendImage === undefined || !spriteConfigured) {
			return undefined;
		}
		const sprite = SpriteClip2.ImageSprite.new({
			adornee: image,
			blendAdornee: blendImage,
			spriteSheetId: assetUri(FORGE_SPRITE_SHEET_ASSET_ID),
			currentFrame: 1,
			spriteSize: FRAME_SIZE,
			spriteOffset: Vector2.zero,
			edgeOffset: Vector2.zero,
			spriteCount: FRAME_COUNT,
			columnCount: COLUMN_COUNT,
			frameRate: FRAME_RATE,
			isLooped: true,
			getOpacity: () => 1 - fadeRef.current.getValue(),
		});
		spriteRef.current = sprite;
		const impactConnection = sprite.GetSignal("FrameChanged").Connect(() => {
			if (sprite.currentFrame === WINDUP_FRAME) {
				windupRef.current?.();
			} else if (sprite.currentFrame === IMPACT_FRAME) {
				strikeRef.current?.();
			} else if (sprite.currentFrame === SPARK_FRAME) {
				sparkRef.current?.();
			}
		});
		const lastFrameConnection = sprite.GetSignal("FrameLast").Connect(() => {
			if (exitingRef.current) {
				sprite.Pause();
			}
		});
		if (reducedMotion) {
			sprite.SetFrame(1);
		} else {
			sprite.Play(1);
		}
		return () => {
			impactConnection.Disconnect();
			lastFrameConnection.Disconnect();
			sprite.Destroy();
			if (spriteRef.current === sprite) {
				spriteRef.current = undefined;
			}
		};
	}, [reducedMotion, spriteConfigured]);
	React.useEffect(() => {
		if (!finaleActive || reducedMotion) {
			return;
		}
		spriteRef.current?.Pause();
		if (imageRef.current !== undefined) {
			imageRef.current.ImageTransparency = 1;
		}
		if (blendImageRef.current !== undefined) {
			blendImageRef.current.ImageTransparency = 1;
		}
	}, [finaleActive, reducedMotion]);
	React.useEffect(() => {
		if (!exiting || reducedMotion || finaleActive) {
			return;
		}
		const sprite = spriteRef.current;
		if (sprite === undefined) {
			return;
		}
		sprite.Stop();
		sprite.Play(math.max(1, IMPACT_FRAME - 4));
	}, [exiting, finaleActive, reducedMotion]);
	const forgeImage = spriteConfigured ? assetUri(FORGE_SPRITE_SHEET_ASSET_ID) : STATIC_FORGE_IMAGE;
	const finaleImage = assetUri(FORGE_V10_FINALE_SPRITE_SHEET_ASSET_ID);
	const artScale = FORGE_ART_SCALE;
	const splitTransparency = finaleTimeline.map((amount) => (amount >= FORGE_FINALE_CONTACT ? 1 : 0));
	const impactTransparency = finaleTimeline.map((amount) => (amount >= FORGE_FINALE_CONTACT ? 0 : 1));
	const impactOffset = finaleTimeline.map(impactFrameOffset);
	const finaleOffset = finaleTimeline.map(finaleFrameOffset);
	const hammerPosition = finaleTimeline.map((amount) => hammerPose(amount).position);
	const hammerRotation = finaleTimeline.map((amount) => hammerPose(amount).rotation);
	const hammerScale = finaleTimeline.map((amount) => hammerPose(amount).scale);
	const trailVisible = (amount: number, index: number) => {
		const flight = phasePulse(amount, 0.1 + index * 0.01, 0.4, FORGE_FINALE_CONTACT);
		return clamp01(1 - flight * (0.22 - index * 0.035));
	};
	const split = finaleActive && !finaleConfigured && (
		<>
			<imagelabel
				Size={UDim2.fromScale(1, 0.5)}
				Position={UDim2.fromScale(0.5, 0.75)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				Image={forgeImage}
				ImageTransparency={splitTransparency}
				ImageRectOffset={new Vector2(0, FRAME_EDGE / 2)}
				ImageRectSize={HALF_FRAME_SIZE}
				ScaleType={Enum.ScaleType.Fit}
				ZIndex={zIndex + 3}
			/>
			{!reducedMotion &&
				[2, 1, 0].map((index) => {
					const lag = 0.017 + index * 0.016;
					return (
						<imagelabel
							key={`hammer-trail-${index}`}
							Size={UDim2.fromScale(1, 0.5)}
							Position={finaleTimeline.map((amount) => hammerPose(math.max(0, amount - lag)).position)}
							Rotation={finaleTimeline.map((amount) => hammerPose(math.max(0, amount - lag)).rotation)}
							AnchorPoint={new Vector2(0.82, 0.5)}
							BackgroundTransparency={1}
							BorderSizePixel={0}
							Image={forgeImage}
							ImageColor3={index === 0 ? Palette.cyan : index === 1 ? Palette.coral : Palette.mango}
							ImageTransparency={finaleTimeline.map((amount) => trailVisible(amount, index))}
							ImageRectOffset={Vector2.zero}
							ImageRectSize={HALF_FRAME_SIZE}
							ScaleType={Enum.ScaleType.Fit}
							ZIndex={zIndex + 4 + index}
						>
							<uiscale
								Scale={finaleTimeline.map(
									(amount) => hammerPose(math.max(0, amount - lag)).scale * (1 + index * 0.018),
								)}
							/>
						</imagelabel>
					);
				})}
			<imagelabel
				Size={UDim2.fromScale(1, 0.5)}
				Position={hammerPosition}
				Rotation={hammerRotation}
				AnchorPoint={new Vector2(0.82, 0.5)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				Image={forgeImage}
				ImageTransparency={splitTransparency}
				ImageRectOffset={Vector2.zero}
				ImageRectSize={HALF_FRAME_SIZE}
				ScaleType={Enum.ScaleType.Fit}
				ZIndex={zIndex + 8}
			>
				<uiscale Scale={hammerScale} />
			</imagelabel>
			<imagelabel
				Size={UDim2.fromScale(1, 1)}
				Position={UDim2.fromScale(0.5, 0.5)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				Image={forgeImage}
				ImageTransparency={impactTransparency}
				ImageRectOffset={impactOffset}
				ImageRectSize={FRAME_SIZE}
				ScaleType={Enum.ScaleType.Fit}
				ZIndex={zIndex + 9}
			/>
		</>
	);
	return (
		<frame
			Size={size}
			Position={position}
			AnchorPoint={new Vector2(0.5, 0.5)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ClipsDescendants={false}
			ZIndex={zIndex}
		>
			<frame
				Size={UDim2.fromScale(artScale, artScale)}
				Position={UDim2.fromScale(0.5, 0.5)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ZIndex={zIndex}
			>
				<ScaleFromCenter scaleRef={artSprRef} zIndex={zIndex}>
					<uiaspectratioconstraint AspectRatio={1} DominantAxis={Enum.DominantAxis.Height} />
					<imagelabel
						ref={imageRef}
						Size={UDim2.fromScale(1, 1)}
						Position={UDim2.fromScale(0.5, 0.5)}
						AnchorPoint={new Vector2(0.5, 0.5)}
						BackgroundTransparency={1}
						BorderSizePixel={0}
						Image={forgeImage}
						ImageTransparency={spriteConfigured ? 0 : 1}
						ImageRectOffset={Vector2.zero}
						ImageRectSize={spriteConfigured ? FRAME_SIZE : Vector2.zero}
						ScaleType={Enum.ScaleType.Fit}
						ResampleMode={Enum.ResamplerMode.Default}
						Visible={!finaleActive}
						ZIndex={zIndex + 1}
					/>
					{spriteConfigured && (
						<imagelabel
							ref={blendImageRef}
							Size={UDim2.fromScale(1, 1)}
							Position={UDim2.fromScale(0.5, 0.5)}
							AnchorPoint={new Vector2(0.5, 0.5)}
							BackgroundTransparency={1}
							BorderSizePixel={0}
							Image={forgeImage}
							ImageTransparency={1}
							ImageRectOffset={Vector2.zero}
							ImageRectSize={FRAME_SIZE}
							ScaleType={Enum.ScaleType.Fit}
							ResampleMode={Enum.ResamplerMode.Default}
							Visible={!finaleActive}
							ZIndex={zIndex + 2}
						/>
					)}
					{finaleActive && finaleConfigured && (
						<imagelabel
							Size={UDim2.fromScale(1, 1)}
							Position={UDim2.fromScale(0.5, 0.5)}
							AnchorPoint={new Vector2(0.5, 0.5)}
							BackgroundTransparency={1}
							BorderSizePixel={0}
							Image={finaleImage}
							ImageRectOffset={finaleOffset}
							ImageRectSize={FRAME_SIZE}
							ScaleType={Enum.ScaleType.Fit}
							ResampleMode={Enum.ResamplerMode.Default}
							ImageTransparency={fade}
							ZIndex={zIndex + 9}
						/>
					)}
					{split}
				</ScaleFromCenter>
			</frame>
		</frame>
	);
}

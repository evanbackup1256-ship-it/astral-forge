import { mergeEvents, useTooltip } from "../../Tooltip";
import React from "@rbxts/react";
import { FrameStroke, frameStroke } from "../../CoreKit/profileFrame";
import { PlayerMark } from "../../ArtKit/Icon";
import { Palette, Radius, TapTarget } from "../../CoreKit/theme";
import * as ProfileStyle from "../../../../Shared/AstralForge/Shared/ProfileStyle";
import { ClientActions, useClientDispatch } from "../../CoreKit/clientStore";
import * as NavRoutes from "../../../../Shared/AstralForge/Shared/NavRoutes";
import BrowseModel = require("../../BrowseModel");
import { kitMember, LuauComponent, sharedModule } from "../luauKits";

const Players = game.GetService("Players");

// crate skins you already own can be swapped here too; same EquipCrateSkin action the Shop uses
interface SkinOption {
	Id: string;
	Name: string;
	Accent: [number, number, number];
	Default?: boolean;
	DailyOnly?: boolean;
}
const ShopCatalog = sharedModule<(name: string) => unknown>("SharedData")("ShopCatalog") as { SKINS: SkinOption[]; DEFAULT_SKIN: string };
const SKIN_BTN_W = 150;
const SKIN_ROW_H = 18 + TapTarget + 4 + 10;

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
// room around the swatches so the selected ring (3px, drawn outside the dot) isn't cut by the scroller
const SWATCH_PAD = 4;
const SWATCH_ROW_H = SWATCH + SWATCH_PAD * 2;

// three samples side by side are ~64px each on a 286px phone, too narrow for a name: stack them there
function samplesHeight(stack: boolean): number {
	return stack ? SAMPLE_H * 3 + SAMPLE_GAP * 2 : SAMPLE_H;
}

// header + hint, preview, accent row, frame row
export function profileStyleHeight(stack: boolean): number {
	return 26 + 22 + 10 + PREVIEW_H + SAMPLE_GAP + samplesHeight(stack) + 14 + 18 + SWATCH_ROW_H + 14 + 18 + TapTarget + 4 + NEXT_H + SKIN_ROW_H + (stack ? 8 : 0);
}

const NEXT_H = 22;

// the closest accent or frame you haven't unlocked yet, from the same catalog the server checks
function nextUnlockLine(rebirths: unknown): string {
	const have = typeIs(rebirths, "number") && rebirths === rebirths ? rebirths : 0;
	let best: { name: string; kind: string; target: number } | undefined;
	const consider = (name: string, kind: string, unlock: ProfileStyle.StyleUnlock) => {
		if (unlock.Kind === "Rebirths" && unlock.Target > have && (best === undefined || unlock.Target < best.target)) {
			best = { name, kind, target: unlock.Target };
		}
	};
	ProfileStyle.ACCENTS.forEach((option) => consider(option.Name, "accent", option.Unlock));
	ProfileStyle.FRAMES.forEach((option) => consider(option.Name, "frame", option.Unlock));
	if (best === undefined) {
		return "Every accent and frame is unlocked.";
	}
	const togo = best.target - have;
	return `Next unlock: ${best.name} ${best.kind} at ${best.target} rebirths (${togo} to go)`;
}

function unlockHint(unlock: ProfileStyle.StyleUnlock): string {
	return unlock.Kind === "Free" ? "" : `${unlock.Target} rebirths`;
}

// one accent dot; its name (and what unlocks it) shows on hover, pad focus or a long press
function AccentSwatch(props: {
	option: ProfileStyle.AccentOption;
	index: number;
	unlocked: boolean;
	selected: boolean;
	onPick: () => void;
}) {
	const { option, index, unlocked, selected } = props;
	const color = Color3.fromRGB(option.Rgb[0], option.Rgb[1], option.Rgb[2]);
	const tip = useTooltip({
		title: option.Name,
		body: unlocked ? (selected ? "You're wearing this one." : "Tap to wear it.") : `Unlocks at ${option.Unlock.Target} rebirths.`,
	});
	return (
		<imagebutton
			Size={UDim2.fromOffset(SWATCH, SWATCH)}
			Position={UDim2.fromOffset(SWATCH_PAD + index * (SWATCH + SWATCH_GAP), SWATCH_PAD)}
			BackgroundColor3={color}
			BackgroundTransparency={unlocked ? 0 : 0.7}
			AutoButtonColor={unlocked}
			BorderSizePixel={0}
			Event={mergeEvents(tip, {
				Activated: () => {
					if (unlocked && !selected) {
						props.onPick();
					}
				},
			})}
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
}

function StyleSample(props: { stack: boolean; order: number; label: string; ring: FrameStroke; accent: Color3; kind: "card" | "mark" | "row"; name: string }) {
	const { ring, accent } = props;
	const stroke = (thickness: number, transparency: number) => (
		<uistroke Color={ring.color} Thickness={thickness} Transparency={transparency}>
			{ring.gradient !== undefined && <uigradient Color={ring.gradient} Rotation={35} />}
		</uistroke>
	);
	const mark = props.kind === "mark";
	return (
		<frame
			Size={props.stack ? new UDim2(1, 0, 0, SAMPLE_H) : new UDim2(1 / 3, -math.ceil((SAMPLE_GAP * 2) / 3), 1, 0)}
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
	// owned skins only, in catalog order; old saves without the bag still own the default skin
	const bag = typeIs(props.cosmetics, "table") ? (props.cosmetics as { CrateSkins?: unknown; CrateSkin?: unknown }) : {};
	const ownedBag = typeIs(bag.CrateSkins, "table") ? (bag.CrateSkins as Record<string, unknown>) : {};
	const equippedSkin = typeIs(bag.CrateSkin, "string") ? bag.CrateSkin : ShopCatalog.DEFAULT_SKIN;
	const [pendingSkin, setPendingSkin] = React.useState<string | undefined>(undefined);
	React.useEffect(() => {
		setPendingSkin(undefined);
	}, [equippedSkin]);
	const shownSkin = pendingSkin ?? equippedSkin;
	const ownedSkins = ShopCatalog.SKINS.filter((skin) => skin.Id === ShopCatalog.DEFAULT_SKIN || ownedBag[skin.Id] === true);
	// skins you don't own yet sit after yours; tapping one opens the Shop (Daily Shop-only skins are left out)
	const lockedSkins = ShopCatalog.SKINS.filter((skin) => skin.DailyOnly !== true && !ownedSkins.includes(skin));
	const storeDispatch = useClientDispatch();
	const openShop = () => {
		if (NavRoutes.isNavId("Shop")) {
			// same deep link Quick Find uses: the Shop opens on (or switches to) its Skins section
			BrowseModel.link("Shop", { query: BrowseModel.recall("Shop")?.query ?? "", category: "Skins" });
			storeDispatch(ClientActions.navigate("Shop"));
		}
	};
	const lockedButtons = lockedSkins.map((skin, index) => (
		<frame
			key={`locked-${skin.Id}`}
			Size={UDim2.fromOffset(SKIN_BTN_W, TapTarget)}
			Position={UDim2.fromOffset(SWATCH_PAD + (ownedSkins.size() + index) * (SKIN_BTN_W + 8), 2)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
		>
			<Button
				text={`${skin.Name} · Shop`}
				icon="Shop.1"
				onClick={openShop}
				color={Palette.panelSoft}
				textColor={Palette.muted}
				outline={true}
				size={UDim2.fromScale(1, 1)}
				reducedMotion={props.reducedMotion}
			/>
		</frame>
	));
	const skinButtons = ownedSkins.map((skin, index) => {
		const selected = skin.Id === shownSkin;
		const tint = Color3.fromRGB(skin.Accent[0], skin.Accent[1], skin.Accent[2]);
		return (
			<frame
				key={skin.Id}
				Size={UDim2.fromOffset(SKIN_BTN_W, TapTarget)}
				Position={UDim2.fromOffset(SWATCH_PAD + index * (SKIN_BTN_W + 8), 2)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
			>
				<Button
					text={skin.Name}
					onClick={() => {
						if (!selected) {
							setPendingSkin(skin.Id);
							props.dispatch("EquipCrateSkin", { Id: skin.Id });
						}
					}}
					color={selected ? tint : Palette.panelSoft}
					textColor={selected ? Palette.ink : Palette.cream}
					outline={!selected}
					size={UDim2.fromScale(1, 1)}
					reducedMotion={props.reducedMotion}
				/>
			</frame>
		);
	});
	const localName = Players.LocalPlayer !== undefined ? Players.LocalPlayer.DisplayName : "You";

	const accentTop = 26 + 22 + 10 + PREVIEW_H + SAMPLE_GAP + samplesHeight(props.stack) + 14;
	const samplesTop = 26 + 22 + 10 + PREVIEW_H + SAMPLE_GAP;
	const frameTop = accentTop + 18 + SWATCH_ROW_H + 14;

	const swatches = ProfileStyle.ACCENTS.map((option, index) => (
		<AccentSwatch
			key={option.Id}
			option={option}
			index={index}
			unlocked={ProfileStyle.isUnlocked(option.Unlock, props.rebirths)}
			selected={option.Id === shown.Accent}
			onPick={() => choose(option.Id, undefined)}
		/>
	));

	// the frame row scrolls sideways like the accent row, so more frames never overflow a phone
	const frameButtons = ProfileStyle.FRAMES.map((option, index) => {
		const unlocked = ProfileStyle.isUnlocked(option.Unlock, props.rebirths);
		const selected = option.Id === shown.Frame;
		return (
			<frame
				key={option.Id}
				Size={UDim2.fromOffset(FRAME_BTN_W, TapTarget)}
				Position={UDim2.fromOffset(SWATCH_PAD + index * (FRAME_BTN_W + 8), 2)}
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
					tooltip={{
						title: option.Name,
						body: option.Description,
						hint: unlocked ? undefined : `Unlocks at ${option.Unlock.Target} rebirths`,
					}}
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
			<frame Size={new UDim2(1, 0, 0, samplesHeight(props.stack))} Position={UDim2.fromOffset(0, samplesTop)} BackgroundTransparency={1} BorderSizePixel={0}>
				<uilistlayout FillDirection={props.stack ? Enum.FillDirection.Vertical : Enum.FillDirection.Horizontal} Padding={new UDim(0, SAMPLE_GAP)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<StyleSample stack={props.stack} order={1} label="Player list" ring={ring} accent={accentColor} kind="card" name={localName} />
				<StyleSample stack={props.stack} order={2} label="Chat" ring={ring} accent={accentColor} kind="mark" name={localName} />
				<StyleSample stack={props.stack} order={3} label="Ranks" ring={ring} accent={accentColor} kind="row" name={localName} />
			</frame>
			<Text value="Accent" size={12} color={Palette.creamSoft} weight={Enum.FontWeight.Bold} fit={false} position={UDim2.fromOffset(0, accentTop)} sizeConstraint={new UDim2(1, 0, 0, 16)} />
			<scrollingframe
				Size={new UDim2(1, 0, 0, SWATCH_ROW_H)}
				Position={UDim2.fromOffset(0, accentTop + 18)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ScrollingDirection={Enum.ScrollingDirection.X}
				ScrollBarThickness={2}
				ScrollBarImageColor3={accentColor}
				CanvasSize={UDim2.fromOffset(ProfileStyle.ACCENTS.size() * (SWATCH + SWATCH_GAP) - SWATCH_GAP + SWATCH_PAD * 2, 0)}
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
				CanvasSize={UDim2.fromOffset(ProfileStyle.FRAMES.size() * (FRAME_BTN_W + 8) - 8 + SWATCH_PAD * 2, 0)}
				ClipsDescendants={true}
			>
				{frameButtons}
			</scrollingframe>
			<Text
				value={nextUnlockLine(props.rebirths)}
				size={11}
				minSize={8}
				color={Palette.muted}
				fit={true}
				position={UDim2.fromOffset(0, frameTop + 18 + TapTarget + 4 + 6)}
				sizeConstraint={new UDim2(1, 0, 0, 16)}
			/>
			<Text
				value={lockedSkins.size() > 0 ? "Crate skin · tap a locked one to find it in the Shop" : "Crate skin"}
				size={12}
				minSize={9}
				color={Palette.creamSoft}
				weight={Enum.FontWeight.Bold}
				fit={true}
				position={UDim2.fromOffset(0, frameTop + 18 + TapTarget + 4 + NEXT_H)}
				sizeConstraint={new UDim2(1, 0, 0, 16)}
			/>
			<scrollingframe
				Size={new UDim2(1, 0, 0, TapTarget + 4)}
				Position={UDim2.fromOffset(0, frameTop + 18 + TapTarget + 4 + NEXT_H + 18)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ScrollingDirection={Enum.ScrollingDirection.X}
				ScrollBarThickness={2}
				ScrollBarImageColor3={accentColor}
				CanvasSize={UDim2.fromOffset((ownedSkins.size() + lockedSkins.size()) * (SKIN_BTN_W + 8) - 8 + SWATCH_PAD * 2, 0)}
				ClipsDescendants={true}
			>
				{skinButtons}
				{lockedButtons}
			</scrollingframe>
		</>
	);
}

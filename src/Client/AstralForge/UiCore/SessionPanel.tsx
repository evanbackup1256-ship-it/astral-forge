// Session panel: opens from the Session button in the top bar (desktop) or the mobile header.
// A right-anchored card with six stat tiles, a flux-per-minute bar chart and Reset / Share card.
// All depth is built in code (SoftShadow, RimLight, gradients); no image assets.
import React from "@rbxts/react";
import { Palette, darken } from "../CoreKit/theme";
import { useBackLayer } from "../CoreKit/backLayer";
import { useViewport } from "../MotionKit/motion";
import { SoftShadow, RimLight } from "./depth";
import { rarityColor } from "./SpriteCard";
import { Button, LooseComponent } from "./ui";
import SessionStats = require("../SessionStats");

const AstralForge = script.Parent!.Parent!;
const Icon = (
	(require(AstralForge.WaitForChild("ArtKit") as ModuleScript) as (member: string) => unknown)("Icon") as {
		Icon: LooseComponent;
	}
).Icon;

const TITLE_FONT = Font.fromEnum(Enum.Font.Merriweather); // closest Roblox serif to Cinzel
const LABEL_FONT = Font.fromEnum(Enum.Font.BuilderSansBold);
const NUMBER_FONT = new Font("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold);

function useTick(seconds: number) {
	const [, setTick] = React.useState(0);
	React.useEffect(() => {
		let alive = true;
		task.spawn(() => {
			while (alive) {
				task.wait(seconds);
				if (alive) {
					setTick((n) => n + 1);
				}
			}
		});
		return () => {
			alive = false;
		};
	}, []);
}

function Label(props: {
	text: string;
	size: number;
	minSize?: number;
	color: Color3;
	font: Font;
	frame: UDim2;
	position?: UDim2;
	anchor?: Vector2;
	align?: Enum.TextXAlignment;
	order?: number;
	zIndex?: number;
}) {
	return (
		<textlabel
			Size={props.frame}
			Position={props.position}
			AnchorPoint={props.anchor}
			LayoutOrder={props.order}
			BackgroundTransparency={1}
			Text={props.text}
			TextColor3={props.color}
			TextSize={props.size}
			TextScaled={true}
			FontFace={props.font}
			TextXAlignment={props.align ?? Enum.TextXAlignment.Left}
			TextTruncate={Enum.TextTruncate.AtEnd}
			ZIndex={props.zIndex ?? 62}
		>
			<uitextsizeconstraint MaxTextSize={props.size} MinTextSize={props.minSize ?? math.max(10, props.size - 4)} />
		</textlabel>
	);
}

interface TileProps {
	order: number;
	label: string;
	value: string;
	icon: string;
	accent: Color3;
	valueColor?: Color3;
	compact: boolean;
}

function Tile(props: TileProps) {
	const h = props.compact ? 50 : 56;
	return (
		<frame Size={new UDim2(0, 0, 0, h)} LayoutOrder={props.order} BackgroundColor3={Palette.panelRaised} BorderSizePixel={0} ZIndex={61}>
			<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
			<uicorner CornerRadius={new UDim(0, 10)} />
			<uistroke Color={Palette.line} Thickness={1} Transparency={0.35} />
			<uigradient
				Color={new ColorSequence(Palette.panelRaised, darken(Palette.panelRaised, 0.18))}
				Rotation={90}
			/>
			<Icon kind={props.icon} color={Palette.muted} accent={props.accent} size={14} position={UDim2.fromOffset(10, 9)} />
			<Label text={props.label} size={11} minSize={10} color={Palette.muted} font={LABEL_FONT}
				frame={new UDim2(1, -36, 0, 14)} position={UDim2.fromOffset(30, 9)} />
			<Label text={props.value} size={props.compact ? 17 : 20} minSize={12} color={props.valueColor ?? Palette.cream}
				font={props.valueColor !== undefined ? TITLE_FONT : NUMBER_FONT}
				frame={new UDim2(1, -20, 0, props.compact ? 20 : 24)} position={new UDim2(0, 10, 1, -(props.compact ? 6 : 8))}
				anchor={new Vector2(0, 1)} />
		</frame>
	);
}

/** 40-bar strip, one rounded Frame per bar with a brass gradient. Newest minute on the right. */
function Chart(props: { values: number[]; height: number }) {
	let peak = 0;
	for (const v of props.values) {
		peak = math.max(peak, v);
	}
	const bars: React.Element[] = [];
	const count = props.values.size();
	for (let i = 0; i < count; i++) {
		const share = peak > 0 ? props.values[i] / peak : 0;
		bars.push(
			<frame
				key={`bar${i}`}
				LayoutOrder={i}
				Size={new UDim2(1 / 40, -2, math.max(0.03, share), 0)}
				BackgroundColor3={Palette.brass}
				BackgroundTransparency={i === count - 1 ? 0 : 0.15}
				BorderSizePixel={0}
				ZIndex={62}
			>
				<uicorner CornerRadius={new UDim(0, 2)} />
				<uigradient Color={new ColorSequence(Palette.brass, Palette.brassDeep)} Rotation={90}
					Transparency={new NumberSequence(0, 0.35)} />
			</frame>,
		);
	}
	return (
		<frame Size={new UDim2(1, 0, 0, props.height)} BackgroundTransparency={1} LayoutOrder={3} ZIndex={61}>
			<Label text="FLUX PER MINUTE" size={11} color={Palette.muted} font={LABEL_FONT} frame={new UDim2(1, 0, 0, 14)} />
			<frame Size={new UDim2(1, 0, 1, -20)} Position={UDim2.fromOffset(0, 20)} BackgroundColor3={Palette.ink}
				BackgroundTransparency={0.4} BorderSizePixel={0} ClipsDescendants={true} ZIndex={61}>
				<uicorner CornerRadius={new UDim(0, 8)} />
				<uipadding PaddingLeft={new UDim(0, 6)} PaddingRight={new UDim(0, 6)} PaddingTop={new UDim(0, 6)} PaddingBottom={new UDim(0, 4)} />
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} HorizontalAlignment={Enum.HorizontalAlignment.Right}
					VerticalAlignment={Enum.VerticalAlignment.Bottom} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 2)} />
				{bars}
				{peak <= 0 && (
					<Label text="Collect flux to start the chart" size={12} color={Palette.muted} font={LABEL_FONT}
						frame={UDim2.fromScale(1, 1)} align={Enum.TextXAlignment.Center} />
				)}
			</frame>
		</frame>
	);
}

export interface SessionPanelProps {
	/** px from the top of the screen to just under the top bar / mobile header */
	top: number;
	edgePad: number;
	reducedMotion?: boolean;
}

export function SessionPanel(props: SessionPanelProps) {
	SessionStats.useStats();
	useTick(1);
	const viewport = useViewport();
	const open = SessionStats.isOpen();
	useBackLayer(open, () => SessionStats.setOpen(false));
	if (!open) {
		return undefined;
	}
	const data = SessionStats.read();
	const phone = viewport.width < 700 || viewport.height < 500;
	const sideInset = viewport.sideInset ?? 0;
	const width = math.min(560, viewport.width - props.edgePad * 2 - sideInset * 2 - 8);
	const maxHeight = math.max(160, viewport.height - props.top - 12 - (viewport.bottomInset ?? 0));
	const columns = width < 420 ? 2 : 3;
	const compact = phone;
	const drop = data.bestDrop;
	const tiles: TileProps[] = [
		{ order: 1, label: "FLUX EARNED", value: data.fluxText, icon: "Flux.31", accent: Palette.cyan, compact },
		{ order: 2, label: "CRATES OPENED", value: tostring(data.counts.crates), icon: "Crate.4", accent: Palette.violet, compact },
		{
			order: 3,
			label: "BEST DROP",
			value: drop !== undefined ? drop.name : "None yet",
			icon: `Rarity${drop !== undefined ? drop.rarity : "Common"}.1`,
			accent: drop !== undefined ? rarityColor(drop.rarity) : Palette.muted,
			valueColor: drop !== undefined ? rarityColor(drop.rarity) : Palette.muted,
			compact,
		},
		{ order: 4, label: "REBIRTHS", value: tostring(data.counts.rebirths), icon: "Rebirth.31", accent: Palette.pink, compact },
		{ order: 5, label: "PLAYTIME", value: SessionStats.clockText(data.playedSeconds), icon: "Timer.31", accent: Palette.mint, compact },
		{ order: 6, label: "FLUX SPENT", value: data.fluxSpentText, icon: "Flux.32", accent: Palette.mango, compact },
	];
	const tileH = compact ? 50 : 56;
	const rows = math.ceil(tiles.size() / columns);
	const gridH = rows * tileH + (rows - 1) * 8;
	const chartH = compact ? 96 : 120;
	const headerH = compact ? 40 : 58;
	const footerH = 40;
	const bodyH = gridH + 12 + chartH + 12 + footerH;
	const height = math.min(maxHeight, headerH + 14 + bodyH + 16);
	const canShare = SessionStats.canShare();

	const rowsEls: React.Element[] = [];
	for (let r = 0; r < rows; r++) {
		const cells: React.Element[] = [];
		for (let c = 0; c < columns; c++) {
			const tile = tiles[r * columns + c];
			if (tile !== undefined) {
				cells.push(
					<Tile key={tile.label} {...tile} />,
				);
			}
		}
		rowsEls.push(
			<frame key={`row${r}`} Size={new UDim2(1, 0, 0, tileH)} BackgroundTransparency={1} LayoutOrder={r} ZIndex={61}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 8)}
					SortOrder={Enum.SortOrder.LayoutOrder} HorizontalFlex={Enum.UIFlexAlignment.Fill} />
				{cells}
			</frame>,
		);
	}

	return (
		<frame
			Size={UDim2.fromOffset(width, height)}
			Position={new UDim2(1, -(props.edgePad + sideInset + 4), 0, props.top + 8)}
			AnchorPoint={new Vector2(1, 0)}
			BackgroundColor3={Palette.panel}
			BorderSizePixel={0}
			Active={true}
			ZIndex={60}
		>
			<uicorner CornerRadius={new UDim(0, 18)} />
			<uigradient Color={new ColorSequence(Palette.panelRaised, Palette.panel)} Rotation={90} />
			<RimLight color={Palette.line} inner={Palette.brass} />
			<SoftShadow radius={18} spread={18} drop={8} zIndex={59} />
			{/* header */}
			<frame Size={new UDim2(1, -32, 0, headerH)} Position={UDim2.fromOffset(16, 12)} BackgroundTransparency={1} ZIndex={61}>
				{!compact && (
					<Label text="SINCE YOU JOINED" size={10} color={Palette.mango} font={LABEL_FONT} frame={new UDim2(1, -150, 0, 12)} />
				)}
				<Label text={compact ? "THIS SESSION" : "This Session"} size={compact ? 15 : 24} minSize={13} color={Palette.cream}
					font={TITLE_FONT} frame={new UDim2(1, -150, 0, compact ? 24 : 30)} position={UDim2.fromOffset(compact ? 22 : 0, compact ? 0 : 14)} />
				{compact && <Icon kind="Session.2" color={Palette.mango} accent={Palette.mango} size={16} position={UDim2.fromOffset(0, 4)} />}
				{/* playtime pill + close */}
				<frame Size={UDim2.fromOffset(72, 26)} Position={new UDim2(1, -46, 0, compact ? 0 : 16)} AnchorPoint={new Vector2(1, 0)}
					BackgroundColor3={darken(Palette.brassDeep, 0.35)} BorderSizePixel={0} ZIndex={61}>
					<uicorner CornerRadius={new UDim(0, 6)} />
					<uistroke Color={Palette.brass} Thickness={1} Transparency={0.4} />
					<Label text={SessionStats.clockText(data.playedSeconds)} size={12} minSize={10} color={Palette.cream} font={NUMBER_FONT}
						frame={new UDim2(1, -8, 1, 0)} position={UDim2.fromOffset(4, 0)} align={Enum.TextXAlignment.Center} />
				</frame>
				<Button text="" icon="Close.31" onClick={() => SessionStats.setOpen(false)} size={UDim2.fromOffset(34, 34)}
					position={new UDim2(1, 0, 0, compact ? -4 : 12)} color={Palette.panelSoft} textColor={Palette.cream}
					reducedMotion={props.reducedMotion} zIndex={63} />
			</frame>
			{/* brass rule under the title */}
			<frame Size={new UDim2(1, -32, 0, 1)} Position={UDim2.fromOffset(16, 12 + headerH + 6)} BackgroundColor3={Palette.brass}
				BorderSizePixel={0} ZIndex={61}>
				<uigradient Transparency={new NumberSequence([
					new NumberSequenceKeypoint(0, 1),
					new NumberSequenceKeypoint(0.5, 0.2),
					new NumberSequenceKeypoint(1, 1),
				])} />
			</frame>
			{/* body scrolls if the screen is too short, so nothing gets cut off */}
			<scrollingframe
				Size={new UDim2(1, -24, 1, -(12 + headerH + 14 + 12))}
				Position={UDim2.fromOffset(16, 12 + headerH + 14)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				CanvasSize={UDim2.fromOffset(0, bodyH)}
				ScrollingDirection={Enum.ScrollingDirection.Y}
				ScrollBarThickness={bodyH > height - headerH - 40 ? 3 : 0}
				ScrollBarImageColor3={Palette.brass}
				ZIndex={61}
			>
				<uipadding PaddingRight={new UDim(0, 8)} />
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, 12)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<frame Size={new UDim2(1, 0, 0, gridH)} BackgroundTransparency={1} LayoutOrder={1} ZIndex={61}>
					<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
					{rowsEls}
				</frame>
				<Chart values={data.perMinute} height={chartH} />
				<frame Size={new UDim2(1, 0, 0, footerH)} BackgroundTransparency={1} LayoutOrder={4} ZIndex={61}>
					<Button text="Reset" icon="Refresh.31" onClick={() => SessionStats.reset()} size={UDim2.fromOffset(110, 36)}
						color={Palette.panelSoft} textColor={Palette.cream} reducedMotion={props.reducedMotion} zIndex={62} />
					{canShare && (
						<Button text="Share card" onClick={() => SessionStats.share()} size={UDim2.fromOffset(140, 36)}
							position={new UDim2(1, -140, 0, 0)} color={Palette.brass} textColor={Palette.ink}
							reducedMotion={props.reducedMotion} zIndex={62} />
					)}
				</frame>
			</scrollingframe>
		</frame>
	);
}

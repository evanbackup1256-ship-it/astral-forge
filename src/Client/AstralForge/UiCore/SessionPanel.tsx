// Session panel: opens from the Session button in the top bar (desktop) or the mobile header.
// A right-anchored card with six stat tiles, a flux-per-minute bar chart and Reset / Share card.
// All depth is built in code (SoftShadow, RimLight, gradients); no image assets.
import React from "@rbxts/react";
import { Palette, darken } from "../CoreKit/theme";
import { useBackLayer } from "../CoreKit/backLayer";
import { useViewport } from "../MotionKit/motion";
import { SoftShadow, RimLight } from "./depth";
import { rarityColor } from "./SpriteCard";
import { Button, LooseComponent, TITLE_FACE } from "./ui";
import { NUM, spaced } from "./mockKit";
import SessionStats = require("../SessionStats");
// generated from design/01-hud-session by scripts/gen_from_layout.js (scripts/layout/hud_session.spec.json)
import { HudSessionLayout as L } from "../pages/generated/HudSessionLayout";
import { HudSessionPhoneLayout as PL } from "../pages/generated/HudSessionPhoneLayout";

const AstralForge = script.Parent!.Parent!;
const Icon = (
	(require(AstralForge.WaitForChild("ArtKit") as ModuleScript) as (member: string) => unknown)("Icon") as {
		Icon: LooseComponent;
	}
).Icon;

const TITLE_FONT = TITLE_FACE; // closest Roblox serif to Cinzel
const LABEL_FONT = Font.fromEnum(Enum.Font.BuilderSansBold);
// af.css .btn.sec base
const SEC = Color3.fromRGB(58, 46, 62);
const NUMBER_FONT = NUM;

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

function tileHeight(compact: boolean): number {
	return compact ? 52 : L.Tile.h;
}

function Tile(props: TileProps) {
	// 01-hud-session .row (column): padding 14/16, .lbl with icon, .big value at 30px
	const h = tileHeight(props.compact);
	const px = props.compact ? 10 : L.Tile.pad.left;
	const py = props.compact ? 8 : L.Tile.pad.top;
	return (
		<frame Size={new UDim2(0, 0, 0, h)} LayoutOrder={props.order} BackgroundColor3={Palette.panelRaised} BorderSizePixel={0} ZIndex={61}>
			<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
			{/* .row radius and hairline; the tile's own gradient stays as it was */}
			<uicorner CornerRadius={new UDim(0, L.Tile.radius)} />
			<uistroke Color={Palette.white} Transparency={0.95} Thickness={1} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
			<uigradient
				Color={new ColorSequence(Palette.panelRaised, darken(Palette.panelRaised, 0.18))}
				Rotation={90}
			/>
			<Icon kind={props.icon} color={Palette.muted} accent={props.accent} size={props.compact ? 14 : L.TileIcon.w} position={UDim2.fromOffset(px, py)} />
			<Label text={spaced(props.label)} size={props.compact ? 10 : L.TileLabel.text.size} minSize={9} color={L.TileLabel.text.color} font={LABEL_FONT}
				frame={new UDim2(1, -(px * 2 + L.TileLabel.text.x), 0, props.compact ? 16 : L.TileLabel.h)} position={UDim2.fromOffset(px + (props.compact ? 22 : L.TileLabel.text.x), py)} />
			<Label text={props.value} size={props.compact ? 18 : L.TileValue.text.size} minSize={12} color={props.valueColor ?? Palette.cream}
				font={NUMBER_FONT}
				frame={new UDim2(1, -px * 2, 0, props.compact ? 22 : L.TileValue.h)} position={new UDim2(0, px, 1, -py)}
				anchor={new Vector2(0, 1)} />
		</frame>
	);
}

/** label 14 + panel gap 12, then the 140px chart (01-hud-session svg) */
const CHART_TOP = L.Chart.y - L.ChartLabel.y;

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
			<Label text={spaced("FLUX PER MINUTE")} size={L.ChartLabel.text.size} color={L.ChartLabel.text.color} font={LABEL_FONT} frame={new UDim2(1, 0, 0, L.ChartLabel.h)} />
			<frame Size={new UDim2(1, 0, 1, -CHART_TOP)} Position={UDim2.fromOffset(0, CHART_TOP)} BackgroundColor3={Palette.ink}
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
	const width = math.min(phone ? 560 : L.Panel.w, viewport.width - props.edgePad * 2 - sideInset * 2 - 8);
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
	const tileH = tileHeight(compact);
	const rows = math.ceil(tiles.size() / columns);
	const gridGap = compact ? 10 : L.Grid.gap;
	const gridH = rows * tileH + (rows - 1) * gridGap;
	// desktop: .pn padding 18/20, gap 12: head 58 / .rule 12 / grid / label+chart / footer 44 (= the 542px mockup panel)
	const padY = compact ? 12 : L.Panel.pad.top;
	const padX = compact ? 16 : L.Panel.pad.left;
	const gap = compact ? 12 : L.Panel.gap;
	const chartH = compact ? 96 : L.Chart.y + L.Chart.h - L.ChartLabel.y;
	const headerH = compact ? 40 : L.Head.h;
	const ruleH = compact ? 2 : L.Rule.h;
	const footerH = compact ? 36 : L.Footer.h;
	const bodyH = gridH + gap + chartH + gap + footerH;
	const bodyTop = padY + headerH + gap + ruleH + gap;
	const height = math.min(maxHeight, bodyTop + bodyH + padY);
	const canShare = SessionStats.canShare();

	if (phone) {
		return (
			<PhoneSession
				tiles={tiles}
				clock={SessionStats.clockText(data.playedSeconds)}
				canShare={canShare}
				width={math.min(PL.Panel.w, width)}
				maxHeight={maxHeight}
				position={new UDim2(1, -(props.edgePad + sideInset + 4), 0, props.top + 8)}
				reducedMotion={props.reducedMotion}
			/>
		);
	}
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
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, gridGap)}
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
			ref={(node: Frame | undefined) => node?.SetAttribute("LayoutFloating", true)}
		>
			<uicorner CornerRadius={new UDim(0, L.Panel.radius)} />
			<uigradient Color={L.Panel.gradient!.color} Rotation={L.Panel.gradient!.rotation} />
			<RimLight color={Palette.line} inner={Palette.brass} />
			<SoftShadow radius={L.Panel.radius} spread={18} drop={8} zIndex={59} />
			{/* header */}
			<frame Size={new UDim2(1, -padX * 2, 0, headerH)} Position={UDim2.fromOffset(padX, padY)} BackgroundTransparency={1} ZIndex={61}>
				{!compact && (
					<Label text={spaced("SINCE YOU JOINED")} size={L.Kicker.text.size} color={L.Kicker.text.color} font={LABEL_FONT} frame={new UDim2(1, -150, 0, L.Kicker.h)} />
				)}
				<Label text={compact ? "THIS SESSION" : "This Session"} size={compact ? 15 : L.Title.text.size} minSize={13} color={L.Title.text.color}
					font={TITLE_FONT} frame={new UDim2(1, -150, 0, compact ? 24 : L.Title.h)} position={UDim2.fromOffset(compact ? 22 : 0, compact ? 0 : L.Title.y - L.Head.y)} />
				{compact && <Icon kind="Session.2" color={Palette.mango} accent={Palette.mango} size={16} position={UDim2.fromOffset(0, 4)} />}
				{/* playtime pill + close */}
				<frame Size={UDim2.fromOffset(compact ? 80 : L.Clock.w, L.Clock.h)} Position={new UDim2(1, compact ? -46 : -(L.Close.w + L.Head.gap), 0, compact ? 0 : L.Clock.y - L.Head.y)} AnchorPoint={new Vector2(1, 0)}
					BackgroundColor3={L.Clock.fill!.color} BackgroundTransparency={L.Clock.fill!.transparency} BorderSizePixel={0} ZIndex={61}>
					<uicorner CornerRadius={new UDim(0, L.Clock.radius)} />
					<uistroke Color={L.Clock.stroke!.color} Thickness={L.Clock.stroke!.thickness} Transparency={L.Clock.stroke!.transparency} />
					<Label text={SessionStats.clockText(data.playedSeconds)} size={12} minSize={10} color={Palette.cream} font={NUMBER_FONT}
						frame={new UDim2(1, -8, 1, 0)} position={UDim2.fromOffset(4, 0)} align={Enum.TextXAlignment.Center} />
				</frame>
				<Button text="" icon="Close.31" onClick={() => SessionStats.setOpen(false)} size={compact ? UDim2.fromOffset(34, 34) : UDim2.fromOffset(L.Close.w, L.Close.h)}
					position={new UDim2(1, compact ? 0 : -L.Close.w, 0, compact ? -4 : L.Close.y - L.Head.y)} color={SEC} textColor={Palette.cream}
					reducedMotion={props.reducedMotion} zIndex={63} />
			</frame>
			{/* brass rule under the title */}
			<frame Size={new UDim2(1, -padX * 2, 0, 1)} Position={UDim2.fromOffset(padX, padY + headerH + gap + math.floor(ruleH / 2))} BackgroundColor3={Palette.brass}
				BorderSizePixel={0} ZIndex={61}>
				<uigradient Transparency={new NumberSequence([
					new NumberSequenceKeypoint(0, 1),
					new NumberSequenceKeypoint(0.5, 0.2),
					new NumberSequenceKeypoint(1, 1),
				])} />
			</frame>
			{/* body scrolls if the screen is too short, so nothing gets cut off */}
			<scrollingframe
				Size={new UDim2(1, -(padX * 2 - 8), 1, -(bodyTop + padY))}
				Position={UDim2.fromOffset(padX, bodyTop)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				CanvasSize={UDim2.fromOffset(0, bodyH)}
				ScrollingDirection={Enum.ScrollingDirection.Y}
				ScrollBarThickness={bodyH > height - headerH - 40 ? 3 : 0}
				ScrollBarImageColor3={Palette.brass}
				ZIndex={61}
			>
				<uipadding PaddingRight={new UDim(0, 8)} />
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<frame Size={new UDim2(1, 0, 0, gridH)} BackgroundTransparency={1} LayoutOrder={1} ZIndex={61}>
					<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, gridGap)} SortOrder={Enum.SortOrder.LayoutOrder} />
					{rowsEls}
				</frame>
				<Chart values={data.perMinute} height={chartH} />
				<frame Size={new UDim2(1, 0, 0, footerH)} BackgroundTransparency={1} LayoutOrder={4} ZIndex={61}>
					<Button text="Reset" icon="Refresh.31" onClick={() => SessionStats.reset()} size={UDim2.fromOffset(compact ? 110 : L.Reset.w, footerH)}
						color={SEC} textColor={Palette.cream} reducedMotion={props.reducedMotion} zIndex={62} />
					{canShare && (
						<Button text="Share card" onClick={() => SessionStats.share()} size={UDim2.fromOffset(compact ? 150 : L.Share.w, footerH)}
							position={new UDim2(1, -(compact ? 150 : L.Share.w), 0, 0)} color={Palette.brass} textColor={Palette.ink}
							reducedMotion={props.reducedMotion} zIndex={62} />
					)}
				</frame>
			</scrollingframe>
		</frame>
	);
}

// 01-hud-session phone.html: a 380px .pn with an h3 ("THIS SESSION" + playtime small), a 2-column
// grid of 44px .row stats (36 well / 13px title / 17px value) and the sm buttons right-aligned.
// The mockup only shows Close; Reset and Share card stay beside it so phones keep those actions.
function PhoneSession(props: {
	tiles: TileProps[];
	clock: string;
	canShare: boolean;
	width: number;
	maxHeight: number;
	position: UDim2;
	reducedMotion?: boolean;
}) {
	const pad = PL.Panel.pad;
	const rows = math.ceil(props.tiles.size() / 2);
	const gridH = rows * PL.Row.h + (rows - 1) * PL.Grid.gap;
	const bodyH = PL.Heading.h + PL.Panel.gap + gridH + PL.Panel.gap + PL.Close.h;
	const height = math.min(props.maxHeight, pad.top + bodyH + pad.bottom);
	const accent = PL.HeadingIcon.icon!.color;
	const closeW = math.ceil(PL.Close.w);
	return (
		<frame
			Size={UDim2.fromOffset(props.width, height)}
			Position={props.position}
			AnchorPoint={new Vector2(1, 0)}
			BackgroundColor3={Palette.panel}
			BorderSizePixel={0}
			Active={true}
			ZIndex={60}
			ref={(node: Frame | undefined) => node?.SetAttribute("LayoutFloating", true)}
		>
			<uicorner CornerRadius={new UDim(0, PL.Panel.radius)} />
			<uigradient Color={PL.Panel.gradient!.color} Rotation={PL.Panel.gradient!.rotation} />
			<RimLight color={Palette.line} inner={Palette.brass} />
			<SoftShadow radius={PL.Panel.radius} spread={12} drop={6} zIndex={59} />
			<scrollingframe
				Size={new UDim2(1, -(pad.left + pad.right), 1, -(pad.top + pad.bottom))}
				Position={UDim2.fromOffset(pad.left, pad.top)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				CanvasSize={UDim2.fromOffset(0, bodyH)}
				ScrollingDirection={Enum.ScrollingDirection.Y}
				ScrollBarThickness={bodyH > height - pad.top - pad.bottom ? 3 : 0}
				ScrollBarImageColor3={Palette.brass}
				ZIndex={61}
			>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, PL.Panel.gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{/* h3 */}
				<frame Size={new UDim2(1, 0, 0, PL.Heading.h)} BackgroundTransparency={1} LayoutOrder={1} ZIndex={61}>
					<Icon kind="Session.2" color={accent} accent={accent} size={PL.HeadingIcon.w} position={UDim2.fromOffset(0, 0)} />
					<Label text={spaced(PL.Heading.text!.value)} size={PL.Heading.text!.size} color={PL.Heading.text!.color} font={TITLE_FONT}
						frame={new UDim2(1, -(PL.Heading.text!.x + 60), 1, 0)} position={UDim2.fromOffset(PL.Heading.text!.x, 0)} />
					<Label text={props.clock} size={PL.HeadingClock.text!.size} color={PL.HeadingClock.text!.color} font={LABEL_FONT}
						frame={UDim2.fromOffset(60, PL.Heading.h)} position={new UDim2(1, 0, 0, 0)} anchor={new Vector2(1, 0)} align={Enum.TextXAlignment.Right} />
				</frame>
				{/* stat grid */}
				<frame Size={new UDim2(1, 0, 0, gridH)} BackgroundTransparency={1} LayoutOrder={2} ZIndex={61}>
					<uigridlayout CellSize={new UDim2(0.5, -PL.Grid.gap / 2, 0, PL.Row.h)} CellPadding={UDim2.fromOffset(PL.Grid.gap, PL.Grid.gap)}
						SortOrder={Enum.SortOrder.LayoutOrder} />
					{props.tiles.map((tile) => (
						<frame key={tile.label} LayoutOrder={tile.order} BackgroundColor3={Palette.white} BorderSizePixel={0} ZIndex={61}>
							<uicorner CornerRadius={new UDim(0, PL.Row.radius)} />
							<uigradient Color={PL.Row.gradient!.color} Transparency={PL.Row.gradient!.transparency} Rotation={PL.Row.gradient!.rotation} />
							<uistroke Color={Palette.white} Transparency={0.95} Thickness={1} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
							<frame Size={UDim2.fromOffset(PL.RowWell.w, PL.RowWell.h)} Position={new UDim2(0, PL.Row.pad.left, 0.5, 0)} AnchorPoint={new Vector2(0, 0.5)}
								BackgroundColor3={PL.RowWell.fill!.color} BackgroundTransparency={PL.RowWell.fill!.transparency} BorderSizePixel={0} ZIndex={62}>
								<uicorner CornerRadius={new UDim(0, PL.RowWell.radius)} />
								<uistroke Color={PL.RowWell.stroke!.color} Transparency={PL.RowWell.stroke!.transparency} Thickness={1} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
								<Icon kind={tile.icon} color={accent} accent={tile.accent} size={18} position={UDim2.fromOffset(9, 9)} />
							</frame>
							<Label text={sentence(tile.label)} size={PL.RowTitle.text!.size} minSize={10} color={PL.RowTitle.text!.color} font={ROW_FONT}
								frame={new UDim2(0.55, -(PL.RowWell.w + PL.Row.gap), 0, PL.RowTitle.h)}
								position={new UDim2(0, PL.Row.pad.left + PL.RowWell.w + PL.Row.gap, 0.5, 0)} anchor={new Vector2(0, 0.5)} />
							<Label text={tile.value} size={PL.RowValue.text!.size} minSize={11} color={tile.valueColor ?? PL.RowValue.text!.color} font={NUMBER_FONT}
								frame={new UDim2(0.45, -PL.Row.pad.right, 0, PL.RowValue.h)} position={new UDim2(1, -PL.Row.pad.right, 0.5, 0)}
								anchor={new Vector2(1, 0.5)} align={Enum.TextXAlignment.Right} />
						</frame>
					))}
				</frame>
				{/* sm buttons, right-aligned like the mockup's Close */}
				<frame Size={new UDim2(1, 0, 0, PL.Close.h)} BackgroundTransparency={1} LayoutOrder={3} ZIndex={61}>
					<Button text="Reset" icon="Refresh.31" onClick={() => SessionStats.reset()} size={UDim2.fromOffset(96, PL.Close.h)} position={new UDim2(1, -(closeW + 6 + (props.canShare ? 116 + 6 : 0) + 96), 0, 0)}
						color={SEC} textColor={Palette.cream} reducedMotion={props.reducedMotion} zIndex={62} />
					{props.canShare && (
						<Button text="Share card" onClick={() => SessionStats.share()} size={UDim2.fromOffset(116, PL.Close.h)} position={new UDim2(1, -(closeW + 6 + 116), 0, 0)}
							color={Palette.brass} textColor={Palette.ink} reducedMotion={props.reducedMotion} zIndex={62} />
					)}
					<Button text="Close" icon="Close.31" onClick={() => SessionStats.setOpen(false)} size={UDim2.fromOffset(closeW, PL.Close.h)} position={new UDim2(1, -closeW, 0, 0)}
						color={SEC} textColor={Palette.cream} reducedMotion={props.reducedMotion} zIndex={62} />
				</frame>
			</scrollingframe>
		</frame>
	);
}

const ROW_FONT = new Font("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.SemiBold);
function sentence(label: string): string {
	const lower = string.lower(label);
	return string.upper(string.sub(lower, 1, 1)) + string.sub(lower, 2);
}

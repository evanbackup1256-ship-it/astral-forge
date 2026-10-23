// Overview, ported from design/01-hud-session (desktop.html 1920x1080, phone.html).
// Desktop: the painted forge stage fills the page; "This Session" sits top-right (700px wide,
// 30px from the right, 24px down) and the vault actions sit bottom-left (40px in, 36px up).
// Phone (landscape): the stage on the left, a 380px session panel on the right.
// Phone (portrait): the session panel full width with the vault actions under it.
import React from "@rbxts/react";
import { asFlux, compactNumber, Flux } from "../../CoreKit/format";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import * as VaultCollectEligibility from "../../CoreKit/vaultCollectEligibility";
import { chromeFor, Palette } from "../../CoreKit/theme";
import { useClock, useFlash, useStagger, useViewport } from "../../MotionKit/motion";
import { HEADER_ART } from "../../ArtKit/uiArt";
import SessionStats = require("../../SessionStats");
import { Button } from "../../UiCore/ui";
import {
	BODY_BOLD,
	DiamondRule,
	Glyph,
	Label,
	Line,
	MockPanel,
	NUM,
	PanelHeading,
	RowSurface,
	TITLE_FACE,
	panelPad,
} from "../../UiCore/mockKit";
import { AudioPlayer, kitMember } from "../luauKits";
import { named } from "../luauDeps";

const UserInputService = game.GetService("UserInputService");
const Workspace = game.GetService("Workspace");
const { Audio } = kitMember<{ Audio: AudioPlayer }>("AudioKit", "audio");

type Dispatch = (action: string, payload?: object, callback?: (response: { ok?: boolean }) => void) => unknown;

interface OverviewState {
	Vault: Flux;
	Capacity: Flux;
	Machines: Record<string, number | undefined>;
	Flags?: { TutorialDone?: boolean };
	ActiveBoost?: { Id?: string; EndsAt?: unknown };
	[key: string]: unknown;
}
interface OverviewConfig {
	Boosts?: Record<string, { Name?: string; Multiplier?: unknown } | undefined>;
	[key: string]: unknown;
}
interface OverviewViewProps {
	state: OverviewState;
	config?: OverviewConfig;
	dispatch: Dispatch;
	reducedMotion?: boolean;
	effectsPaused?: boolean;
	openWorkshop?: () => unknown;
	openDomain?: () => unknown;
	releaseAt?: number;
	navigate?: (page: string) => unknown;
}

const RARITY_TEXT: Record<string, Color3> = {
	Common: Color3.fromRGB(200, 196, 188),
	Rare: Color3.fromRGB(110, 190, 255),
	Epic: Color3.fromRGB(190, 120, 255),
	Legendary: Color3.fromRGB(255, 190, 70),
	Mythic: Color3.fromRGB(255, 110, 150),
	Celestial: Color3.fromRGB(190, 248, 255),
	Astral: Color3.fromRGB(255, 200, 240),
};

function serverNow(): number {
	const [ok, value] = pcall(() => Workspace.GetServerTimeNow());
	return ok && typeIs(value, "number") ? value : os.time();
}

function clockShort(seconds: number): string {
	const s = math.max(0, math.floor(seconds));
	if (s >= 3600) {
		return `${math.floor(s / 3600)}h ${string.format("%02d", math.floor((s % 3600) / 60))}m`;
	}
	return `${math.floor(s / 60)}m ${string.format("%02d", s % 60)}s`;
}

// --- desktop stat cell: .row column, padding 14px 16px, .lbl over a 30px number -------------
const STAT_H = 14 + 16 + 4 + 30 + 14;
function StatCell(p: { icon: string; label: string; value: string | React.Binding<string>; color?: Color3; order: number; phone: boolean }) {
	if (p.phone) {
		// phone.html: .row with a 36px icon well, name, value in the accent
		return (
			<frame Size={new UDim2(0.5, -3, 0, 44)} BackgroundColor3={Palette.white} BorderSizePixel={0} LayoutOrder={p.order}>
				<RowSurface />
				<uipadding PaddingLeft={new UDim(0, 10)} PaddingRight={new UDim(0, 10)} />
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 10)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
				<frame Size={UDim2.fromOffset(32, 32)} BackgroundColor3={Palette.void} BackgroundTransparency={0.65} BorderSizePixel={0} LayoutOrder={0}>
					<uicorner CornerRadius={new UDim(0, 9)} />
					<uistroke Color={Palette.white} Transparency={0.92} Thickness={1} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
					<Glyph kind={p.icon} size={18} color={Palette.mango} position={UDim2.fromOffset(7, 7)} />
				</frame>
				<frame Size={new UDim2(0, 0, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
					<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
					<Line text={p.label} size={13} font={BODY_BOLD} width={new UDim(1, 0)} height={44} />
				</frame>
				<textlabel
					BackgroundTransparency={1}
					Size={UDim2.fromOffset(0, 44)}
					AutomaticSize={Enum.AutomaticSize.X}
					Text={p.value}
					TextSize={16}
					FontFace={NUM}
					TextColor3={p.color ?? Palette.mango}
					LayoutOrder={2}
				/>
			</frame>
		);
	}
	return (
		<frame Size={new UDim2(1 / 3, -20 / 3, 0, STAT_H)} BackgroundColor3={Palette.white} BorderSizePixel={0} LayoutOrder={p.order}>
			<RowSurface />
			<uipadding PaddingLeft={new UDim(0, 16)} PaddingRight={new UDim(0, 16)} PaddingTop={new UDim(0, 14)} PaddingBottom={new UDim(0, 14)} />
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, 4)} SortOrder={Enum.SortOrder.LayoutOrder} />
			<Label text={p.label} icon={p.icon} layoutOrder={0} />
			<textlabel
				BackgroundTransparency={1}
				Size={new UDim2(1, 0, 0, 30)}
				Text={p.value}
				TextSize={30}
				FontFace={NUM}
				TextColor3={p.color ?? Palette.cream}
				TextXAlignment={Enum.TextXAlignment.Left}
				TextTruncate={Enum.TextTruncate.AtEnd}
				LayoutOrder={1}
			/>
		</frame>
	);
}

// --- "Cash per minute": 600x140 area chart drawn with frames (viewBox 0 0 600 140) -------------
const CHART_H = 140;
function MinuteChart(p: { buckets: number[]; width: number; order: number }) {
	const w = p.width;
	const values = p.buckets.size() >= 2 ? p.buckets : [p.buckets[0] ?? 0, p.buckets[0] ?? 0];
	let top = 0;
	for (const v of values) top = math.max(top, v);
	const yFor = (v: number) => (top <= 0 ? CHART_H - 20 : CHART_H - 20 - (v / top) * (CHART_H - 34));
	const points: Vector2[] = [];
	for (let i = 0; i < values.size(); i++) {
		points.push(new Vector2((i / (values.size() - 1)) * w, yFor(values[i])));
	}
	const children: React.Element[] = [];
	// dashed guides at 35 / 70 / 105 (#4A3A50, dash 2 gap 5)
	for (const gy of [35, 70, 105]) {
		for (let x = 0; x < w; x += 7) {
			children.push(<frame key={`g${gy}-${x}`} Size={UDim2.fromOffset(2, 1)} Position={UDim2.fromOffset(x, gy)} BackgroundColor3={Palette.line} BorderSizePixel={0} />);
		}
	}
	// area: 4px columns under the curve, mango .45 fading to 0 at the floor
	const col = 4;
	for (let x = 0; x < w; x += col) {
		const t = x / w;
		const seg = math.min(points.size() - 2, math.floor(t * (points.size() - 1)));
		const a = points[seg];
		const b = points[seg + 1];
		const k = b.X === a.X ? 0 : (x - a.X) / (b.X - a.X);
		const y = a.Y + (b.Y - a.Y) * k;
		children.push(
			<frame key={`a${x}`} Size={UDim2.fromOffset(col, CHART_H - y)} Position={UDim2.fromOffset(x, y)} BackgroundColor3={Palette.mango} BorderSizePixel={0}>
				<uigradient Rotation={90} Transparency={new NumberSequence([new NumberSequenceKeypoint(0, 0.55), new NumberSequenceKeypoint(1, 1)])} />
			</frame>,
		);
	}
	// 3px line
	for (let i = 0; i < points.size() - 1; i++) {
		const a = points[i];
		const b = points[i + 1];
		const mid = a.add(b).div(2);
		const d = b.sub(a);
		children.push(
			<frame
				key={`l${i}`}
				Size={UDim2.fromOffset(d.Magnitude + 2, 3)}
				Position={UDim2.fromOffset(mid.X, mid.Y)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Rotation={math.deg(math.atan2(d.Y, d.X))}
				BackgroundColor3={Palette.mango}
				BorderSizePixel={0}
				ZIndex={2}
			/>,
		);
	}
	const last = points[points.size() - 1];
	return (
		<frame Size={new UDim2(1, 0, 0, CHART_H)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={p.order} ClipsDescendants={true}>
			{children}
			<frame Size={UDim2.fromOffset(12, 12)} Position={UDim2.fromOffset(math.min(last.X, w - 8), last.Y)} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundColor3={Palette.pink} BorderSizePixel={0} ZIndex={3}>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke Color={Palette.ink} Thickness={2} />
			</frame>
		</frame>
	);
}

export function OverviewView({ state, config, dispatch, reducedMotion, effectsPaused, openWorkshop, navigate }: OverviewViewProps) {
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const phone = chrome.stack;
	const portrait = phone && !chrome.landscape;
	const quiet = reducedMotion === true || effectsPaused === true;
	const stageReveal = useStagger(0, quiet);
	const panelReveal = useStagger(1, quiet);
	SessionStats.useStats();
	const snap = SessionStats.read();
	const clock = useClock(true, 1, 86400, true);
	const played = clock.map(() => clockShort(SessionStats.read().playedSeconds));
	const [hidden, setHidden] = React.useState(false);

	const canCollect = VaultCollectEligibility.isEligible(asFlux(state.Vault));
	const stellarLevel = state.Machines.StellarCore ?? 0;
	const primaryIsBuy = !canCollect && stellarLevel < 1;
	const [collectTrigger, setCollectTrigger] = React.useState(0);
	useFlash(collectTrigger, reducedMotion, 0.42);
	const collect = () => {
		if (primaryIsBuy) {
			openWorkshop?.();
			return;
		}
		if (!canCollect) return;
		setCollectTrigger((n) => n + 1);
		dispatch("CollectVault");
	};

	// active boost: "Boost x2 · 14:59", otherwise a way into Boosts
	const boostClock = useClock(true, 1, 86400, true);
	const boostId = state.ActiveBoost?.Id ?? "";
	const boostEnds = (state.ActiveBoost !== undefined ? tonumber(state.ActiveBoost.EndsAt) : undefined) ?? 0;
	const boostDef = boostId !== "" ? config?.Boosts?.[boostId] : undefined;
	const boostMult = boostDef !== undefined ? tonumber(boostDef.Multiplier) ?? 1 : 1;
	const boostRunning = boostId !== "" && boostEnds > serverNow();
	const boostText = boostClock.map(() => {
		if (!boostRunning) return "Boosts";
		const left = math.max(0, math.floor(boostEnds - serverNow()));
		return `Boost x${compactNumber(boostMult)} · ${math.floor(left / 60)}:${string.format("%02d", left % 60)}`;
	});

	// tutorial and gamepad focus land on the vault actions
	const actionsRef = React.useRef<Frame>();
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) return undefined;
		const host = actionsRef.current;
		if (host === undefined) return undefined;
		const job = task.defer(() => {
			if (host.Parent !== undefined) GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [canCollect]);

	const best = snap.bestDrop;
	const stats: Array<{ icon: string; label: string; value: string | React.Binding<string>; color?: Color3 }> = [
		{ icon: "Flux", label: "Flux earned", value: snap.fluxText },
		{ icon: "Crate", label: "Crates opened", value: tostring(snap.counts.crates) },
		{ icon: "Jackpot", label: "Best drop", value: best !== undefined ? best.name : "None yet", color: best !== undefined ? RARITY_TEXT[best.rarity] : Palette.muted },
		{ icon: "Rebirth", label: "Rebirths", value: tostring(snap.counts.rebirths) },
		{ icon: "Timer", label: "Playtime", value: played },
		{ icon: "Dust", label: "Flux spent", value: snap.fluxSpentText },
	];

	const btnH = 44;
	const vaultText = primaryIsBuy ? "Buy a machine" : `Collect ${compactNumber(state.Vault)}`;
	const actions = (
		<frame
			ref={actionsRef}
			{...named("OverviewVaultClaimActions")}
			Size={UDim2.fromOffset(0, btnH)}
			AutomaticSize={Enum.AutomaticSize.X}
			Position={portrait ? undefined : phone ? new UDim2(0, 12, 1, -12) : new UDim2(0, 40, 1, -36)}
			AnchorPoint={portrait ? undefined : new Vector2(0, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			LayoutOrder={3}
			ZIndex={4}
			SelectionGroup={true}
		>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 12)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
			<Button
				text={vaultText}
				icon={primaryIsBuy ? "Forge" : "Collect"}
				onClick={collect}
				disabled={!primaryIsBuy && !canCollect}
				color={Palette.mango}
				textColor={Color3.fromRGB(27, 15, 8)}
				hug={true}
				size={UDim2.fromOffset(0, btnH)}
				highlight={canCollect}
				reducedMotion={reducedMotion}
			/>
			<Button
				text={boostRunning ? undefined : "Boosts"}
				icon="Boost"
				onClick={() => {
					Audio.play("uiTap");
					navigate?.("Boosts");
				}}
				color={Palette.cyan}
				textColor={Color3.fromRGB(27, 15, 8)}
				hug={true}
				size={UDim2.fromOffset(0, btnH)}
				reducedMotion={reducedMotion}
			>
				{boostRunning && (
					<textlabel
						BackgroundTransparency={1}
						Size={UDim2.fromScale(1, 1)}
						Text={boostText}
						TextSize={15}
						FontFace={BODY_BOLD}
						TextColor3={Color3.fromRGB(27, 15, 8)}
					/>
				)}
			</Button>
		</frame>
	);

	// --- session panel -------------------------------------------------------------------------
	const pad = panelPad(phone);
	const deskInner = 700 - pad.x * 2;
	const headH = 16 + 44;
	// the desk card never runs past the stage: when the stage is shorter than the card it scales down
	// from its top-right anchor instead of pushing the Reset row off screen
	const [stageH, setStageH] = React.useBinding(0);
	const deskPanelH = pad.y * 2 + headH + 12 + 12 + 12 + (STAT_H * 2 + 10) + 12 + 16 + 12 + CHART_H + 12 + 44;
	const phonePanelH = pad.y * 2 + 18 + 8 + (44 * 2 + 6) + 8 + 36;
	const grid = (
		<frame Size={new UDim2(1, 0, 0, phone ? 44 * 2 + 6 : STAT_H * 2 + 10)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={3}>
			<uigridlayout
				CellSize={phone ? new UDim2(0.5, -3, 0, 44) : new UDim2(1 / 3, -20 / 3, 0, STAT_H)}
				CellPadding={phone ? UDim2.fromOffset(6, 6) : UDim2.fromOffset(10, 10)}
				SortOrder={Enum.SortOrder.LayoutOrder}
			/>
			{(phone ? stats.filter((_, i) => i < 4) : stats).map((s, i) => (
				<StatCell key={s.label} icon={s.icon} label={s.label} value={s.value} color={s.color} order={i} phone={phone} />
			))}
		</frame>
	);
	const sessionPanel = phone ? (
		<MockPanel
			size={portrait ? new UDim2(1, 0, 0, phonePanelH) : new UDim2(0, 380, 1, 0)}
			phone={true}
			layoutOrder={2}
			reveal={panelReveal}
			reducedMotion={reducedMotion}
			name="OverviewSession"
		>
			<PanelHeading icon="Timer" title="This session" note={played} phone={true} layoutOrder={0} />
			{grid}
			<frame Size={new UDim2(1, 0, 0, 36)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={4}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} HorizontalAlignment={Enum.HorizontalAlignment.Right} Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<Button text="Reset" icon="Refresh" onClick={() => SessionStats.reset()} hug={true} size={UDim2.fromOffset(0, 36)} reducedMotion={reducedMotion} />
			</frame>
		</MockPanel>
	) : (
		<MockPanel
			size={UDim2.fromOffset(700, deskPanelH)}
			position={new UDim2(1, -30, 0, 24)}
			anchor={new Vector2(1, 0)}
			phone={false}
			reveal={panelReveal}
			reducedMotion={reducedMotion}
			name="OverviewSession"
		>
			<uiscale Scale={stageH.map((h) => (h <= 0 ? 1 : math.clamp((h - 48) / deskPanelH, 0.5, 1)))} />
			<frame Size={new UDim2(1, 0, 0, headH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={0}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 16)} VerticalAlignment={Enum.VerticalAlignment.Bottom} SortOrder={Enum.SortOrder.LayoutOrder} />
				<frame Size={new UDim2(0, 0, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={0}>
					<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
					<uilistlayout FillDirection={Enum.FillDirection.Vertical} VerticalAlignment={Enum.VerticalAlignment.Bottom} SortOrder={Enum.SortOrder.LayoutOrder} />
					<Label text="Since you joined" color={Palette.mango} layoutOrder={0} />
					<Line text="This Session" size={40} font={TITLE_FACE} height={44} layoutOrder={1} />
				</frame>
				<frame Size={UDim2.fromOffset(0, 36)} AutomaticSize={Enum.AutomaticSize.X} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 16)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
					<PlayedChip played={played} />
					<Button icon="Close" onClick={() => setHidden(true)} size={UDim2.fromOffset(36, 36)} reducedMotion={reducedMotion} tooltip="Hide the session card" />
				</frame>
			</frame>
			<DiamondRule layoutOrder={1} />
			{grid}
			<Label text="Flux per minute" layoutOrder={4} />
			<MinuteChart buckets={snap.perMinute} width={deskInner} order={5} />
			<frame Size={new UDim2(1, 0, 0, 44)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={6}>
				<Button text="Reset" icon="Refresh" onClick={() => SessionStats.reset()} hug={true} size={UDim2.fromOffset(0, 44)} reducedMotion={reducedMotion} />
				{SessionStats.canShare() && (
					<frame Size={UDim2.fromOffset(0, 44)} AutomaticSize={Enum.AutomaticSize.X} Position={UDim2.fromScale(1, 0)} AnchorPoint={new Vector2(1, 0)} BackgroundTransparency={1}>
						<Button
							text="Share card"
							icon="Send"
							onClick={() => SessionStats.share()}
							color={Palette.mango}
							textColor={Color3.fromRGB(27, 15, 8)}
							hug={true}
							size={UDim2.fromOffset(0, 44)}
							reducedMotion={reducedMotion}
						/>
					</frame>
				)}
			</frame>
		</MockPanel>
	);

	// --- stage: painted forge art, 18px radius, brass inset line, left-to-right darkening ---------
	const stage = (
		<frame
			{...named("OverviewStage")}
			Change={{ AbsoluteSize: (f: Frame) => setStageH(f.AbsoluteSize.Y) }}
			Size={portrait ? new UDim2(1, 0, 0, 160) : phone ? new UDim2(1, -(380 + 8), 1, 0) : UDim2.fromScale(1, 1)}
			BackgroundColor3={Palette.ink}
			BackgroundTransparency={stageReveal.map((v) => 1 - math.clamp(v, 0, 1))}
			BorderSizePixel={0}
			ClipsDescendants={true}
			LayoutOrder={0}
		>
			<uicorner CornerRadius={new UDim(0, phone ? 12 : 18)} />
			<uistroke Color={Palette.brass} Transparency={phone ? 0.7 : 0.75} Thickness={1} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
			<imagelabel
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				Image={HEADER_ART.forge}
				ScaleType={Enum.ScaleType.Crop}
				ImageTransparency={stageReveal.map((v) => (phone ? 0.15 : 0) + (1 - math.clamp(v, 0, 1)))}
			/>
			{!phone && (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.ink} BorderSizePixel={0}>
					<uigradient
						Transparency={
							new NumberSequence([
								new NumberSequenceKeypoint(0, 0.9),
								new NumberSequenceKeypoint(0.55, 0.45),
								new NumberSequenceKeypoint(1, 0.15),
							])
						}
					/>
				</frame>
			)}
			{!phone && !hidden && sessionPanel}
			{!phone && hidden && (
				<frame Size={UDim2.fromOffset(0, 36)} AutomaticSize={Enum.AutomaticSize.X} Position={new UDim2(1, -30, 0, 24)} AnchorPoint={new Vector2(1, 0)} BackgroundTransparency={1} ZIndex={3}>
					<Button text="Session" icon="Timer" onClick={() => setHidden(false)} hug={true} size={UDim2.fromOffset(0, 36)} reducedMotion={reducedMotion} />
				</frame>
			)}
			{!portrait && actions}
		</frame>
	);

	if (!phone) {
		return (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
				{stage}
			</frame>
		);
	}
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<uilistlayout
				FillDirection={portrait ? Enum.FillDirection.Vertical : Enum.FillDirection.Horizontal}
				Padding={new UDim(0, 8)}
				SortOrder={Enum.SortOrder.LayoutOrder}
			/>
			{stage}
			{sessionPanel}
			{portrait && actions}
		</frame>
	);
}

function PlayedChip(p: { played: React.Binding<string> }) {
	return (
		<frame Size={UDim2.fromOffset(0, 28)} AutomaticSize={Enum.AutomaticSize.X} BackgroundColor3={Palette.mango} BackgroundTransparency={0.8} BorderSizePixel={0} LayoutOrder={0}>
			<uicorner CornerRadius={new UDim(0, 8)} />
			<uistroke Color={Palette.mango} Transparency={0.4} Thickness={1} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
			<uipadding PaddingLeft={new UDim(0, 10)} PaddingRight={new UDim(0, 10)} />
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 6)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
			<Glyph kind="Timer" size={16} color={Palette.mango} layoutOrder={0} />
			<textlabel BackgroundTransparency={1} Size={UDim2.fromOffset(0, 16)} AutomaticSize={Enum.AutomaticSize.X} Text={p.played} TextSize={12} FontFace={BODY_BOLD} TextColor3={Palette.cream} LayoutOrder={1} />
		</frame>
	);
}

// Season (design/16-season): hero, the tier track (free row over the Star Pass row, tier numbers,
// XP bar), "This week" directives and the Star Pass card. Reads Command season data and config
// Operations.SeasonTiers; claims go through ClaimSeasonTier / ClaimSeasonPremium.
import React from "@rbxts/react";
import { compactNumber, formatReward, Reward } from "../CoreKit/format";
import { chromeFor, Palette, scrollTail } from "../CoreKit/theme";
import { useViewport } from "../MotionKit/motion";
import { Bar, BODY, BODY_SEMI, Glyph, Line, MockPanel, NUM, PanelHeading, spaced, TITLE_FACE } from "../UiCore/mockKit";
// generated from design/16-season by scripts/gen_from_layout.js (scripts/layout/season.spec.json)
import { SeasonLayout as L } from "./generated/SeasonLayout";
import SeasonPremium = require("../../../Shared/AstralForge/Shared/SeasonPremium");
import { MockBtn, panelHeight, headingBlock, RowFace } from "./mockRows";
import { loadPageScaffold } from "./luauDeps";
import { PlaceholderPage } from "./routePlaceholder";

const PageScaffold = loadPageScaffold();

interface SeasonTier {
	Tier: number;
	RequiredXP: number;
	Reward?: Reward;
}
interface Directive {
	Id: string;
	Name: string;
	Claimed?: boolean;
	Progress: number;
	Target: number;
}
interface SeasonCommand {
	SeasonXP?: number;
	SeasonClaims?: Record<string, boolean | undefined>;
	PremiumClaims?: Record<string, boolean | undefined>;
	SeasonPassOwned?: boolean;
	Weekly?: Directive[];
}
interface SeasonViewProps {
	state?: { Command?: SeasonCommand };
	config?: { Operations?: { SeasonTiers?: SeasonTier[]; SeasonName?: string } };
	dispatch?: (action: string, payload?: unknown) => unknown;
	navigate?: (page: string) => unknown;
	reducedMotion?: boolean;
}

const ACCENT = Palette.pink;
const CELL_W = L.TierCol.w;
const CELL_GAP = L.TrackRow.gap;
// the weekly row value column: wide enough for "31B / 50B" at 17px
const VALUE_W = 96;

function premiumText(tier: number): string {
	const r = SeasonPremium.Reward(tier);
	if (r.Cores !== undefined) return `${r.Cores} Cores`;
	if (r.Keys !== undefined) return "Crate";
	if (r.Stardust !== undefined) return `${r.Stardust} Dust`;
	return "Pass";
}

function TierCell(p: { top: string; label: string; state: "done" | "ready" | "locked"; current: boolean; onClick?: () => void; h: number; order: number }) {
	const icon = p.state === "done" ? "Check" : p.state === "locked" ? "Lock" : p.top;
	return (
		<textbutton
			Size={new UDim2(1, 0, 0, p.h)}
			BackgroundColor3={Palette.white}
			BorderSizePixel={0}
			Text=""
			AutoButtonColor={false}
			Active={p.state === "ready"}
			LayoutOrder={p.order}
			Event={{ Activated: () => p.state === "ready" && p.onClick?.() }}
		>
			<RowFace outline={p.current || p.state === "ready" ? ACCENT : undefined} />
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} HorizontalAlignment={Enum.HorizontalAlignment.Center} VerticalAlignment={Enum.VerticalAlignment.Center} Padding={new UDim(0, L.TierCell.gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
			<Glyph kind={icon} size={L.TierGlyph.w} color={p.state === "locked" ? Palette.muted : Palette.cream} layoutOrder={0} />
			<Line text={p.label} size={L.TierLabel.text.size} height={L.TierLabel.h} font={BODY} color={p.state === "locked" ? Palette.muted : Palette.creamSoft} width={new UDim(1, -8)} align={Enum.TextXAlignment.Center} layoutOrder={1} />
		</textbutton>
	);
}

function SeasonView(props: SeasonViewProps) {
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const phone = chrome.contentStack;
	const tiers = props.config?.Operations?.SeasonTiers;
	const command = props.state?.Command;
	if (tiers === undefined || tiers.size() === 0 || command === undefined) {
		return (
			<PlaceholderPage id="Season" icon="Season.1" title="Season" body="The season track opens with the next season." accent={Palette.violet} navigate={props.navigate} reducedMotion={props.reducedMotion} />
		);
	}
	const xp = command.SeasonXP ?? 0;
	const claims = command.SeasonClaims ?? {};
	const pclaims = command.PremiumClaims ?? {};
	const passOwned = command.SeasonPassOwned === true;
	const dispatch = props.dispatch;
	let reached = 0;
	for (const t of tiers) if (xp >= t.RequiredXP) reached = t.Tier;
	const nextTier = tiers.find((t) => xp < t.RequiredXP);
	const prevXP = tiers.find((t) => t.Tier === reached)?.RequiredXP ?? 0;
	const fill = nextTier === undefined ? 1 : math.clamp((xp - prevXP) / math.max(1, nextTier.RequiredXP - prevXP), 0, 1);
	const currentTier = nextTier?.Tier ?? reached;
	const name = props.config?.Operations?.SeasonName ?? "Season";

	const cellH = phone ? 46 : L.TierCell.h;
	const colGap = phone ? 8 : L.TierCol.gap;
	const numH = phone ? 16 : L.TierNum.h;
	const colH = cellH * 2 + colGap * 2 + numH;
	const heroH = phone ? 110 : 150;
	const trackH = panelHeight(phone, headingBlock(phone) + colH + (phone ? 8 : L.Track.gap) + L.TrackBar.h);
	const weekly = command.Weekly ?? [];
	const weekH = panelHeight(phone, headingBlock(phone) + math.max(1, weekly.size()) * L.WeekRow.h + math.max(0, weekly.size() - 1) * (phone ? 8 : L.Week.gap));
	const passH = panelHeight(phone, headingBlock(phone) + L.PassBody.h + L.Pass.gap + L.PassBtn.h);

	const hero = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={ACCENT} glow={ACCENT} reducedMotion={props.reducedMotion} name="SeasonHero">
			<Line text={spaced(passOwned ? "FREE AND STAR PASS" : "FREE TRACK")} size={11} color={ACCENT} layoutOrder={0} />
			<Line text={name} size={phone ? 28 : 40} font={TITLE_FACE} height={phone ? 32 : 46} layoutOrder={1} />
			<Line text={`Tier ${reached} of ${tiers.size()} · ${compactNumber(xp)} XP`} size={13} font={BODY} color={Palette.creamSoft} layoutOrder={2} />
		</MockPanel>
	);

	const columns = tiers.map((t, i) => {
		const tk = tostring(t.Tier);
		const unlocked = xp >= t.RequiredXP;
		const freeState = claims[tk] === true ? "done" : unlocked ? "ready" : "locked";
		const passState = passOwned && pclaims[tk] === true ? "done" : passOwned && unlocked ? "ready" : "locked";
		const current = t.Tier === currentTier;
		return (
			<frame key={tk} Size={UDim2.fromOffset(CELL_W, colH)} BackgroundTransparency={1} LayoutOrder={i}>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, colGap)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<TierCell top="Gift" label={t.Reward !== undefined ? formatReward(t.Reward) : `Tier ${t.Tier}`} state={freeState} current={current} h={cellH} order={0} onClick={() => dispatch?.("ClaimSeasonTier", { Tier: t.Tier })} />
				<TierCell top="Gem" label={passOwned ? premiumText(t.Tier) : "Pass"} state={passState} current={false} h={cellH} order={1} onClick={() => dispatch?.("ClaimSeasonPremium", { Tier: t.Tier })} />
				<Line text={tk} size={phone ? 12 : L.TierNum.text.size} height={numH} font={NUM} color={current ? ACCENT : L.TierNum.text.color} width={new UDim(1, 0)} align={Enum.TextXAlignment.Center} layoutOrder={2} />
			</frame>
		);
	});
	const startIndex = math.max(0, tiers.findIndex((t) => t.Tier === currentTier) - 2);
	const track = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={ACCENT} reducedMotion={props.reducedMotion} name="SeasonTrack">
			<PanelHeading icon="Season.1" title="Track" note={nextTier !== undefined ? `${compactNumber(nextTier.RequiredXP - xp)} XP to tier ${nextTier.Tier}` : "Complete"} accent={ACCENT} phone={phone} layoutOrder={0} />
			<scrollingframe
				Size={new UDim2(1, 0, 0, colH)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				CanvasSize={new UDim2()}
				AutomaticCanvasSize={Enum.AutomaticSize.X}
				CanvasPosition={new Vector2(startIndex * (CELL_W + CELL_GAP), 0)}
				ScrollingDirection={Enum.ScrollingDirection.X}
				ScrollBarThickness={0}
				ScrollBarImageColor3={ACCENT}
				LayoutOrder={1}
			>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, CELL_GAP)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{columns}
			</scrollingframe>
			<Bar fill={fill} color={ACCENT} layoutOrder={2} />
		</MockPanel>
	);

	const week = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={ACCENT} reducedMotion={props.reducedMotion} name="SeasonWeek">
			<PanelHeading icon="Timer" title="This week" accent={ACCENT} phone={phone} layoutOrder={0} />
			{weekly.size() === 0 && <Line text="New directives arrive with the weekly reset." size={12} font={BODY} color={Palette.muted} layoutOrder={1} />}
			{weekly.map((d, i) => {
				const done = d.Progress >= d.Target;
				return (
					<frame key={d.Id} Size={new UDim2(1, 0, 0, L.WeekRow.h)} BackgroundColor3={Palette.white} BorderSizePixel={0} LayoutOrder={i + 1}>
						<RowFace />
						<uipadding PaddingLeft={new UDim(0, L.WeekRow.pad.left)} PaddingRight={new UDim(0, L.WeekRow.pad.right)} />
						<Line text={d.Name} size={L.WeekName.text.size} height={L.WeekName.h} font={BODY_SEMI} color={L.WeekName.text.color} width={new UDim(1, -(VALUE_W + L.WeekRow.gap))} position={UDim2.fromOffset(0, L.WeekName.y - L.WeekRow.y)} />
						<Line text={done ? "Done" : `${compactNumber(d.Progress)} / ${compactNumber(d.Target)}`} size={L.WeekValue.text.size} height={L.WeekValue.h} font={NUM} color={ACCENT} width={new UDim(0, VALUE_W)} align={Enum.TextXAlignment.Right} position={new UDim2(1, -VALUE_W, 0.5, 0)} anchor={new Vector2(0, 0.5)} />
						<frame Size={new UDim2(1, -(VALUE_W + L.WeekRow.gap), 0, L.WeekBar.h)} Position={UDim2.fromOffset(0, L.WeekBar.y - L.WeekRow.y)} BackgroundTransparency={1} BorderSizePixel={0}>
							<Bar fill={math.clamp(d.Progress / math.max(1, d.Target), 0, 1)} color={ACCENT} thin={true} />
						</frame>
					</frame>
				);
			})}
		</MockPanel>
	);

	const pass = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={ACCENT} glow={Palette.violet} reducedMotion={props.reducedMotion} name="SeasonPass">
			<PanelHeading icon="Gem" title="Star Pass" note={passOwned ? "Owned" : undefined} accent={ACCENT} phone={phone} layoutOrder={0} />
			<frame Size={new UDim2(1, 0, 0, L.PassBody.h)} BackgroundTransparency={1} LayoutOrder={1}>
				<Glyph kind="Gem" size={L.PassArt.w / 2} color={Palette.violet} position={UDim2.fromOffset(L.PassArt.w / 4, L.PassArt.h / 4)} />
				<textlabel
					Text="A pass reward on every tier: dust, signals, crates and cores."
					TextSize={L.PassText.text.size}
					FontFace={BODY}
					TextColor3={L.PassText.text.color}
					TextWrapped={true}
					TextXAlignment={Enum.TextXAlignment.Left}
					BackgroundTransparency={1}
					Size={new UDim2(1, -(L.PassArt.w + L.PassBody.gap), 0, L.PassText.h)}
					Position={new UDim2(0, L.PassArt.w + L.PassBody.gap, 0.5, 0)}
					AnchorPoint={new Vector2(0, 0.5)}
				/>
			</frame>
			<frame Size={new UDim2(1, 0, 0, L.PassBtn.h)} BackgroundTransparency={1} LayoutOrder={2}>
				<MockBtn text={passOwned ? "Pass active" : "Get Star Pass"} icon="Gem" accent={ACCENT} phone={phone} fill={true} disabled={passOwned} onClick={() => props.navigate?.("Shop")} reducedMotion={props.reducedMotion} />
			</frame>
		</MockPanel>
	);

	const sections: Array<{ id: string; height: number; element: React.Element }> = [
		{ id: "hero", height: heroH, element: hero },
		{ id: "track", height: trackH, element: track },
	];
	if (phone) {
		sections.push({ id: "week", height: weekH, element: week }, { id: "pass", height: passH, element: pass });
	} else {
		const h = math.max(weekH, passH);
		sections.push({
			id: "lower",
			height: h,
			element: (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, L.Lower.gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
					<frame Size={new UDim2(0, 0, 1, 0)} BackgroundTransparency={1} LayoutOrder={0}>
						<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
						{week}
					</frame>
					<frame Size={new UDim2(0, L.Pass.w, 1, 0)} BackgroundTransparency={1} LayoutOrder={1}>
						{pass}
					</frame>
				</frame>
			),
		});
	}
	return <PageScaffold gap={phone ? 8 : L.Main.gap} tailPad={scrollTail(phone, chrome.bottomSafe, 48)} scrollBarColor={ACCENT} scrollBarThickness={4} sections={sections} />;
}

export = () => ({ SeasonView });

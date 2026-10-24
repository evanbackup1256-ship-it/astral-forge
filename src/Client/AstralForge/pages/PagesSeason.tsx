// Season (design/16-season): shell hero (via heroSlot), the tier track (free row over the Star Pass row, tier numbers,
// XP bar), "This week" directives and the Star Pass card. Reads Command season data and config
// Operations.SeasonTiers; claims go through ClaimSeasonTier / ClaimSeasonPremium.
import React from "@rbxts/react";
import { compactNumber, formatReward, Reward } from "../CoreKit/format";
import { chromeFor, Palette, scrollTail } from "../CoreKit/theme";
import { useViewport } from "../MotionKit/motion";
import { Bar, BODY, BODY_SEMI, Glyph, Line, MockPanel, NUM, PanelHeading } from "../UiCore/mockKit";
// generated from design/16-season by scripts/gen_from_layout.js (scripts/layout/season.spec.json)
import { SeasonLayout as L } from "./generated/SeasonLayout";
import SeasonPremium = require("../../../Shared/AstralForge/Shared/SeasonPremium");
import { MockBtn, panelHeight, headingBlock, RowFace, useWidth } from "./mockRows";
import { PHONE_HEAD_H, PhoneHead } from "./mockLayout";
import { useHeroShown, useHeroSlot } from "../UiCore/heroSlot";
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
// the track shows 8 tiers across the panel on desktop, 6 on phone (design/16-season desktop / phone)
const VISIBLE = 8;
const VISIBLE_PHONE = 6;

function premiumText(tier: number): string {
	const r = SeasonPremium.Reward(tier);
	if (r.Cores !== undefined) return `${r.Cores} Cores`;
	if (r.Keys !== undefined) return "Crate";
	if (r.Stardust !== undefined) return `${r.Stardust} Dust`;
	return "Pass";
}

// .row cell, column flex, padding 10, gap 4: glyph over the small label. Claimed tiers sit at
// opacity .55, the current tier gets the 2px inset pink ring, pass cells the pink .18 wash.
function TierCell(p: { glyph: string; label: string; state: "done" | "ready" | "locked"; current: boolean; pass: boolean; onClick?: () => void; h: number; phone: boolean; order: number }) {
	const icon = p.state === "done" ? "Check" : p.state === "locked" ? "Lock" : p.glyph;
	const fade = p.state === "done" ? 0.45 : 0;
	return (
		<canvasgroup Size={new UDim2(1, 0, 0, p.h)} BackgroundTransparency={1} GroupTransparency={fade} LayoutOrder={p.order}>
			<textbutton
				Size={UDim2.fromScale(1, 1)}
				BackgroundColor3={Palette.white}
				BorderSizePixel={0}
				Text=""
				AutoButtonColor={false}
				Active={p.state === "ready"}
				Event={{ Activated: () => p.state === "ready" && p.onClick?.() }}
			>
				<RowFace outline={p.current ? ACCENT : p.state === "ready" ? ACCENT : undefined} strong={p.current} />
				{p.pass && (
					<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={ACCENT} BorderSizePixel={0} ZIndex={0}>
						<uicorner CornerRadius={new UDim(0, L.TierCell.radius)} />
						<uigradient Rotation={90} Transparency={new NumberSequence(0.82, 1)} />
					</frame>
				)}
				<uipadding PaddingTop={new UDim(0, L.TierCell.pad.top)} PaddingBottom={new UDim(0, L.TierCell.pad.bottom)} PaddingLeft={new UDim(0, L.TierCell.pad.left)} PaddingRight={new UDim(0, L.TierCell.pad.right)} />
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} HorizontalAlignment={Enum.HorizontalAlignment.Center} VerticalAlignment={Enum.VerticalAlignment.Center} Padding={new UDim(0, L.TierCell.gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{!p.phone && <Glyph kind={icon} size={L.TierGlyph.w} color={L.TierGlyph.icon.color} layoutOrder={0} />}
				<Line text={p.label} size={p.phone ? 11 : L.TierLabel.text.size} height={L.TierLabel.h} font={BODY} color={L.TierLabel.text.color} width={new UDim(1, 0)} align={Enum.TextXAlignment.Center} layoutOrder={1} />
			</textbutton>
		</canvasgroup>
	);
}

function SeasonView(props: SeasonViewProps) {
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const phone = chrome.contentStack;
	const heroShown = useHeroShown();
	const [trackW, onTrackSize] = useWidth(1560);
	const tiers = props.config?.Operations?.SeasonTiers;
	const command = props.state?.Command;
	const xp = command?.SeasonXP ?? 0;
	const passOwned = command?.SeasonPassOwned === true;
	let reached = 0;
	for (const t of tiers ?? []) if (xp >= t.RequiredXP) reached = t.Tier;
	const name = props.config?.Operations?.SeasonName ?? "Season";
	// .hero: kicker "Free and Star Pass", the season name as the title, tier and xp on the line
	useHeroSlot("Season", tiers !== undefined && command !== undefined ? { kicker: passOwned ? "Free and Star Pass" : "Free track", title: name, line: `Tier ${reached} of ${tiers.size()} · ${compactNumber(xp)} XP` } : undefined);
	if (tiers === undefined || tiers.size() === 0 || command === undefined) {
		return (
			<PlaceholderPage id="Season" icon="Season.1" title="Season" body="The season track opens with the next season." accent={Palette.violet} navigate={props.navigate} reducedMotion={props.reducedMotion} />
		);
	}
	const claims = command.SeasonClaims ?? {};
	const pclaims = command.PremiumClaims ?? {};
	const dispatch = props.dispatch;
	const nextTier = tiers.find((t) => xp < t.RequiredXP);
	const prevXP = tiers.find((t) => t.Tier === reached)?.RequiredXP ?? 0;
	const fill = nextTier === undefined ? 1 : math.clamp((xp - prevXP) / math.max(1, nextTier.RequiredXP - prevXP), 0, 1);
	const currentTier = nextTier?.Tier ?? reached;

	const visible = phone ? VISIBLE_PHONE : VISIBLE;
	const colGapX = phone ? 8 : L.TrackRow.gap;
	// columns flex to fill the panel like the mockup; the rest of the season scrolls sideways
	const cellW = math.max(40, (trackW - (visible - 1) * colGapX) / visible);
	const cellH = phone ? 40 : L.TierCell.h;
	const colGap = L.TierCol.gap;
	const numH = phone ? 16 : L.TierNum.h;
	const colH = cellH * 2 + colGap * 2 + numH;
	const gapY = phone ? 8 : L.Track.gap;
	const trackH = panelHeight(phone, headingBlock(phone) + colH + gapY + L.TrackBar.h);
	const weekly = command.Weekly ?? [];
	const rowH = phone ? 44 : L.WeekRow.h;
	const weekH = panelHeight(phone, headingBlock(phone) + math.max(1, weekly.size()) * rowH + math.max(0, weekly.size() - 1) * gapY);
	const artW = phone ? 96 : L.PassArt.w;
	const passH = panelHeight(phone, headingBlock(phone) + artW + gapY + (phone ? 44 : L.PassBtn.h));

	const currentIndex = math.max(0, tiers.findIndex((t) => t.Tier === currentTier));
	const startIndex = math.clamp(currentIndex - 3, 0, math.max(0, tiers.size() - visible));
	const first = tiers[startIndex]?.Tier ?? 1;
	const last = tiers[math.min(tiers.size() - 1, startIndex + visible - 1)]?.Tier ?? first;
	const columns = tiers.map((t, i) => {
		const tk = tostring(t.Tier);
		const unlocked = xp >= t.RequiredXP;
		const freeState = claims[tk] === true ? "done" : unlocked ? "ready" : "locked";
		const passState = passOwned && pclaims[tk] === true ? "done" : passOwned && unlocked ? "ready" : "locked";
		const current = t.Tier === currentTier;
		return (
			<frame key={tk} Size={UDim2.fromOffset(cellW, colH)} BackgroundTransparency={1} LayoutOrder={i}>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, colGap)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<TierCell glyph="Gift" label={t.Reward !== undefined ? formatReward(t.Reward) : `Tier ${t.Tier}`} state={freeState} current={current} pass={false} h={cellH} phone={phone} order={0} onClick={() => dispatch?.("ClaimSeasonTier", { Tier: t.Tier })} />
				<TierCell glyph="Gem" label={passOwned ? premiumText(t.Tier) : "Pass"} state={passState} current={false} pass={true} h={cellH} phone={phone} order={1} onClick={() => dispatch?.("ClaimSeasonPremium", { Tier: t.Tier })} />
				<Line text={tk} size={phone ? 12 : L.TierNum.text.size} height={numH} font={NUM} color={current ? ACCENT : L.TierNum.text.color} width={new UDim(1, 0)} align={Enum.TextXAlignment.Center} layoutOrder={2} />
			</frame>
		);
	});
	const toNext = nextTier !== undefined ? ` · ${compactNumber(nextTier.RequiredXP - xp)} XP to tier ${nextTier.Tier}` : " · Complete";
	const track = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={ACCENT} reducedMotion={props.reducedMotion} name="SeasonTrack">
			<PanelHeading icon="Season.1" title="Track" note={`Tiers ${first}–${last}${toNext}`} accent={ACCENT} phone={phone} layoutOrder={0} />
			<scrollingframe
				Size={new UDim2(1, 0, 0, colH)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				CanvasSize={new UDim2()}
				AutomaticCanvasSize={Enum.AutomaticSize.X}
				CanvasPosition={new Vector2(startIndex * (cellW + colGapX), 0)}
				ScrollingDirection={Enum.ScrollingDirection.X}
				ScrollBarThickness={0}
				LayoutOrder={1}
				Change={{ AbsoluteSize: onTrackSize }}
			>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, colGapX)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{columns}
			</scrollingframe>
			<Bar fill={fill} color={ACCENT} layoutOrder={2} />
		</MockPanel>
	);

	// .row: .tt.f1 (b, then the thin bar 6px under it) and the .v value hugging its text
	const week = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={ACCENT} reducedMotion={props.reducedMotion} name="SeasonWeek">
			<PanelHeading icon="Timer" title="This week" accent={ACCENT} phone={phone} layoutOrder={0} />
			{weekly.size() === 0 && <Line text="New directives arrive with the weekly reset." size={12} font={BODY} color={Palette.muted} layoutOrder={1} />}
			{weekly.map((d, i) => {
				const done = d.Progress >= d.Target;
				return (
					<frame key={d.Id} Size={new UDim2(1, 0, 0, rowH)} BackgroundColor3={Palette.white} BorderSizePixel={0} LayoutOrder={i + 1}>
						<RowFace />
						<uipadding PaddingLeft={new UDim(0, phone ? 10 : L.WeekRow.pad.left)} PaddingRight={new UDim(0, phone ? 10 : L.WeekRow.pad.right)} />
						<uilistlayout FillDirection={Enum.FillDirection.Horizontal} VerticalAlignment={Enum.VerticalAlignment.Center} Padding={new UDim(0, L.WeekRow.gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
						<frame Size={new UDim2(0, 0, 0, L.WeekName.h + 6 + L.WeekBar.h)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={0}>
							<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
							<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, 6)} SortOrder={Enum.SortOrder.LayoutOrder} />
							<Line text={d.Name} size={phone ? 13 : L.WeekName.text.size} height={L.WeekName.h} font={BODY_SEMI} color={L.WeekName.text.color} width={new UDim(1, 0)} layoutOrder={0} />
							<Bar fill={math.clamp(d.Progress / math.max(1, d.Target), 0, 1)} color={ACCENT} thin={true} layoutOrder={1} />
						</frame>
						<textlabel
							Text={done ? "Done" : `${compactNumber(d.Progress)} / ${compactNumber(d.Target)}`}
							TextSize={phone ? 14 : L.WeekValue.text.size}
							FontFace={NUM}
							TextColor3={L.WeekValue.text.color}
							BackgroundTransparency={1}
							AutomaticSize={Enum.AutomaticSize.X}
							Size={UDim2.fromOffset(0, L.WeekValue.h)}
							TextXAlignment={Enum.TextXAlignment.Right}
							LayoutOrder={1}
						/>
					</frame>
				);
			})}
		</MockPanel>
	);

	// Star Pass: .flexr (160px art | 15px copy, centred), then the pink .btn
	const pass = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={ACCENT} glow={ACCENT} glowBox={{ w: 600, h: 400, cx: 0.8, cy: 0.4, transparency: 0.8 }} reducedMotion={props.reducedMotion} name="SeasonPass">
			<PanelHeading icon="Gem" title="Star Pass" note={passOwned ? "Owned" : undefined} accent={ACCENT} phone={phone} layoutOrder={0} />
			<frame Size={new UDim2(1, 0, 0, artW)} BackgroundTransparency={1} LayoutOrder={1}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} VerticalAlignment={Enum.VerticalAlignment.Center} Padding={new UDim(0, L.PassBody.gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<frame Size={UDim2.fromOffset(artW, artW)} BackgroundTransparency={1} LayoutOrder={0}>
					<Glyph kind="Gem" size={artW / 2} color={Palette.violet} position={UDim2.fromOffset(artW / 4, artW / 4)} />
				</frame>
				<frame Size={new UDim2(0, 0, 1, 0)} BackgroundTransparency={1} LayoutOrder={1}>
					<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
					<textlabel
						Text="A pass reward on every tier: dust, signals, crates and cores."
						TextSize={phone ? 13 : L.PassText.text.size}
						FontFace={BODY}
						TextColor3={L.PassText.text.color}
						TextWrapped={true}
						TextXAlignment={Enum.TextXAlignment.Left}
						BackgroundTransparency={1}
						Size={new UDim2(1, 0, 0, L.PassText.h)}
						Position={UDim2.fromScale(0, 0.5)}
						AnchorPoint={new Vector2(0, 0.5)}
					/>
				</frame>
			</frame>
			<frame Size={new UDim2(1, 0, 0, phone ? 44 : L.PassBtn.h)} BackgroundTransparency={1} LayoutOrder={2}>
				<MockBtn text={passOwned ? "Pass active" : "Get Star Pass"} icon="Gem" accent={ACCENT} phone={phone} fill={true} disabled={passOwned} onClick={() => props.navigate?.("Shop")} reducedMotion={props.reducedMotion} />
			</frame>
		</MockPanel>
	);

	const sections: Array<{ id: string; height: number; element: React.Element }> = [];
	if (!heroShown) {
		sections.push({ id: "head", height: PHONE_HEAD_H, element: <PhoneHead line={`${name} · Tier ${reached} of ${tiers.size()}`} accent={ACCENT} /> });
	}
	sections.push({ id: "track", height: trackH, element: track });
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

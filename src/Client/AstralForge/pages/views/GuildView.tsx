// The Guild page. Without a guild: charter one or join by tag. With one: a hero card (name, shared
// bonuses, leave/disband) and five panes: Overview (hall level, the shared goal), Treasury (deposits),
// Upgrades (hall upgrades bought from the bank), Members (roles, kicks) and Community (the guild
// channel, announcements, moderation, rules, rename and logo review).
import { Dependency } from "@flamework/core";
import React from "@rbxts/react";
import OmegaMath = require("../../../../Shared/AstralForge/Shared/OmegaMath");
import * as ProfileStyle from "../../../../Shared/AstralForge/Shared/ProfileStyle";
import SocialProgression = require("../../../../Shared/AstralForge/Shared/SocialProgression");
import createRequest = require("../../ActionRequest");
import { PlayerMark } from "../../ArtKit/Icon";
import type { EffectFeedController } from "../../Controllers/EffectFeedController";
import { cutBytes } from "../../CoreKit/chatText";
import { clockText, compactNumber, Flux, formatReward, gteFlux } from "../../CoreKit/format";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { chromeFor, darken, ensureContrast, Layout, Palette, scrollTail, TapTarget } from "../../CoreKit/theme";
import { useEntrance, useStagger, useViewport, useWallClock } from "../../MotionKit/motion";
import { Badge, Button, EmptyState, Meter, Panel, SearchField, SectionLabel, Text } from "../../UiCore/ui";
import { requestConfirm } from "../../UiOverlays/ConfirmDialog";
import { loadAudio, loadBrowse, loadPageScaffold, named } from "../luauDeps";
import { STICKY_H, StickyGroup, StickyGroupLabel } from "./StickyGroupLabel";

const Players = game.GetService("Players");
const UserInputService = game.GetService("UserInputService");
const Audio = loadAudio();
const Browse = loadBrowse();
const PageScaffold = loadPageScaffold();
const Social = SocialProgression(OmegaMath as never);

const ROLE_RANK: Record<string, number | undefined> = { Leader: 0, Officer: 1, Member: 2 };
const ROLE_COLORS: Record<string, Color3 | undefined> = { Leader: Palette.mango, Officer: Palette.cyan, Member: Palette.creamSoft };
const UPGRADE_ACCENTS: Record<string, Color3 | undefined> = {
	ProductionBoost: Palette.coral,
	VaultBoost: Palette.mango,
	OfflineBoost: Palette.cyan,
	AutomationBoost: Palette.mint,
	TapBoost: Palette.violet,
};
const GUILD_TABS = ["Overview", "Treasury", "Upgrades", "Members", "Community"];
const SETTING_KEYS = ["ChatEnabled", "AnnouncementsEnabled", "LogoEnabled", "OfficerAnnouncements", "OfficerModeration", "SlowMode"];
const SETTING_LABELS: Record<string, string> = {
	ChatEnabled: "CHAT",
	AnnouncementsEnabled: "NEWS",
	LogoEnabled: "LOGOS",
	OfficerAnnouncements: "OFFICER NEWS",
	OfficerModeration: "OFFICER MODS",
	SlowMode: "SLOW MODE",
};
const MODERATION: Array<[action: string, label: string, color: Color3]> = [
	["MuteGuildMember", "MUTE", Palette.mango],
	["BanGuildMember", "BAN", Palette.coral],
	["UnmuteGuildMember", "UNMUTE", Palette.cyan],
	["UnbanGuildMember", "UNBAN", Palette.violet],
];

interface GuildMember {
	Name: string;
	Role: string;
	Contributed: number;
}
interface GuildGoal {
	TypeId: string;
	Progress: number;
	Target: number;
	EndsAt: number;
	Completed?: boolean;
	Contributors?: Record<string, number | undefined>;
	Claimed?: Record<string, boolean | undefined>;
}
interface ChatMessage {
	Id?: string;
	SpeakerUserId: number;
	SpeakerName?: string;
	SpeakerRole?: string;
	Message?: string;
	PublishedAt?: number;
}
interface Announcement {
	Id: string;
	Title: string;
	Body: string;
	AuthorName?: string;
	Pinned?: boolean;
	PublishedAt?: number;
	EditedAt?: number;
}
interface Logo {
	Id: string;
	URL?: string;
}
type GuildSettings = Record<string, boolean | undefined>;
interface Guild {
	Id: string;
	Name: string;
	Tag: string;
	Activity?: number;
	BankCash: number;
	BankDust: number;
	Members: Record<string, GuildMember>;
	Upgrades?: Record<string, number | undefined>;
	Goal?: GuildGoal;
	Community?: { Settings?: GuildSettings; Chat?: ChatMessage[]; Announcements?: Announcement[]; Logo?: Logo };
}
interface UpgradeConfig {
	Name: string;
	Description: string;
	MaxLevel: number;
	Currency: "Cash" | "Dust";
	BaseCost: number;
	CostScale: number;
	EffectPerLevel: number;
	Tiers?: Array<{ Name: string; Cost?: number; Effect?: number }>;
}
interface GoalType {
	Id: string;
	Name?: string;
	Description?: string;
	Metric?: string;
	Reward?: unknown;
}
interface GuildConfig {
	Upgrades: Record<string, UpgradeConfig | undefined>;
	UpgradeOrder?: string[];
	CreateCost?: number;
	MaxMembers?: number;
	RenameCost?: number;
	RenameCooldownSeconds?: number;
	Goal?: { Types?: GoalType[]; MinContributionForReward?: number };
}
interface Config {
	Guild?: GuildConfig;
	ClientPageGuides?: { Guild?: { EmptyTitle?: string; EmptyBody?: string; Benefits?: string } };
}
interface Reply {
	ok?: unknown;
	message?: string;
	error?: string;
	Messages?: ChatMessage[];
	Announcements?: Announcement[];
	Settings?: GuildSettings;
	Logos?: Logo[];
	[key: string]: unknown;
}
type Dispatch = (action: string, payload?: object, callback?: (response: Reply) => void) => unknown;
interface Props {
	state: { Guild?: Guild; Cash?: Flux; GuildBonuses?: Record<string, number | undefined> };
	config: Config;
	dispatch: Dispatch;
	reducedMotion?: boolean;
	initialTab?: string;
}
interface Section {
	id: string;
	height: number;
	element: React.Element;
}
interface UpgradeRow {
	id: string;
	config: UpgradeConfig;
	level: number;
	cost: number;
	currentEffect: number;
	nextEffect: number;
	nextTierName?: string;
	tierIndex: number;
	tierCount: number;
	affordable: boolean;
	maxed: boolean;
	accent: Color3;
}

/** Total effect of an upgrade at `level`: named tiers first, then EffectPerLevel for each level past them. */
function effectAtLevel(config: UpgradeConfig, level: number): number {
	const safe = math.max(0, math.floor(level));
	if (safe <= 0) return 0;
	const tiers = config.Tiers;
	if (tiers === undefined || tiers.size() === 0) return safe * config.EffectPerLevel;
	const named = math.min(safe, tiers.size());
	let total = 0;
	for (let index = 0; index < named; index++) {
		const effect = tiers[index]?.Effect;
		total += typeIs(effect, "number") ? effect : 0;
	}
	if (safe > named) total += (safe - named) * config.EffectPerLevel;
	return total;
}

/** Price of the next level: the next tier's own cost, or the scaling curve. */
function costAtLevel(config: UpgradeConfig, level: number): number {
	const tierCost = config.Tiers?.[level]?.Cost;
	if (typeIs(tierCost, "number")) return math.floor(tierCost + 0.5);
	return math.floor(config.BaseCost * config.CostScale ** math.max(0, level) + 0.5);
}

function percentText(value: number): string {
	const scaled = value * 100;
	return scaled >= 10 || scaled % 1 === 0 ? `+${math.floor(scaled + 0.5)}%` : `+${string.format("%.1f", scaled)}%`;
}

/** Every hall upgrade in display order (UpgradeOrder first), with its price and effect now and next. */
function buildUpgradeRows(config: Config, guild: Guild): UpgradeRow[] {
	const guildConfig = config.Guild;
	if (guildConfig === undefined) return [];
	const ids: string[] = [];
	for (const id of guildConfig.UpgradeOrder ?? []) if (guildConfig.Upgrades[id] !== undefined) ids.push(id);
	for (const [id] of pairs(guildConfig.Upgrades)) if (!ids.includes(id)) ids.push(id);
	return ids.map((id) => {
		const upgrade = guildConfig.Upgrades[id]!;
		const level = guild.Upgrades?.[id] ?? 0;
		const maxed = level >= upgrade.MaxLevel;
		const cost = costAtLevel(upgrade, level);
		const bank = upgrade.Currency === "Cash" ? guild.BankCash : guild.BankDust;
		const tierCount = upgrade.Tiers?.size() ?? 0;
		return {
			id,
			config: upgrade,
			level,
			cost,
			currentEffect: effectAtLevel(upgrade, level),
			nextEffect: effectAtLevel(upgrade, level + 1),
			nextTierName: level < tierCount ? upgrade.Tiers![level].Name : undefined,
			tierIndex: math.min(level, tierCount),
			tierCount,
			affordable: !maxed && gteFlux(bank, cost),
			maxed,
			accent: UPGRADE_ACCENTS[id] ?? Palette.violet,
		};
	});
}

const goalUnitLabel = (metric: string) => (metric === "ContributeCash" ? "Flux banked" : metric === "ContributeDust" ? "dust banked" : "upgrades bought");
const sanitizeGuildTag = (value: string) => string.upper(value).gsub("[^A-Z0-9]", "")[0].sub(1, 4);
const localKey = () => tostring(Players.LocalPlayer?.UserId ?? "");

/** A text box styled like the rest of the guild forms. */
function Field(props: {
	placeholder: string;
	value: string;
	onChange: (text: string) => void;
	size?: UDim2;
	position?: UDim2;
	editable?: boolean;
	onEnter?: () => void;
	stroke?: boolean;
}) {
	return (
		<textbox
			Size={props.size ?? new UDim2(1, 0, 0, 42)}
			Position={props.position ?? UDim2.fromOffset(0, 0)}
			PlaceholderText={props.placeholder}
			Text={props.value}
			TextXAlignment={Enum.TextXAlignment.Left}
			BackgroundColor3={Palette.void}
			BorderSizePixel={0}
			TextColor3={Palette.cream}
			PlaceholderColor3={Palette.muted}
			TextSize={14}
			ClearTextOnFocus={false}
			TextEditable={props.editable ?? true}
			FontFace={Font.fromEnum(Enum.Font.BuilderSansMedium)}
			Change={{ Text: (box) => props.onChange(box.Text) }}
			Event={{
				Focused: () => Audio.play("inputFocus"),
				FocusLost: (_box, enterPressed) => {
					if (enterPressed) props.onEnter?.();
				},
			}}
		>
			<uicorner CornerRadius={new UDim(0, 10)} />
			{props.stroke !== false && <uistroke Color={Palette.line} Thickness={1} Transparency={0.55} />}
			<uipadding PaddingLeft={new UDim(0, 12)} PaddingRight={new UDim(0, 12)} />
		</textbox>
	);
}

interface ActionProps {
	reducedMotion?: boolean;
	dispatch: Dispatch;
	busy: boolean;
	shakeToken: number;
}

/** The shared objective: progress, time left, your part, and the reward claim. */
function GuildGoalCard({ guild, config, stack, reducedMotion, dispatch, busy, shakeToken }: ActionProps & { guild: Guild; config: Config; stack: boolean }) {
	const goal = guild.Goal;
	const now = useWallClock(goal !== undefined);
	const claimHostRef = React.useRef<Frame>();
	const key = localKey();
	const mine = goal?.Contributors?.[key] ?? 0;
	const helped = mine >= (config.Guild?.Goal?.MinContributionForReward ?? 1);
	const claimed = goal?.Claimed?.[key] === true;
	const canClaim = goal?.Completed === true && helped && !claimed;
	// a controller lands on Claim the moment the reward is ready
	React.useEffect(() => {
		const host = claimHostRef.current;
		if (!canClaim || !UserInputService.GamepadEnabled || host === undefined) return undefined;
		const selectJob = task.defer(() => {
			if (host.Parent !== undefined) GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, selectJob);
		};
	}, [canClaim, goal?.TypeId, goal?.Completed]);
	if (goal === undefined) {
		return (
			<Panel size={new UDim2(1, 0, 0, 116)} accent={Palette.mint} background={Palette.panelRaised} padding={stack ? 16 : 18} reducedMotion={reducedMotion}>
				<Text value="GUILD GOAL" size={10} color={Palette.mint} weight={Enum.FontWeight.Heavy} sizeConstraint={new UDim2(1, 0, 0, 14)} />
				<Text
					value="The next shared goal is being drawn up."
					size={12}
					color={Palette.creamSoft}
					wrap={true}
					fit={true}
					minSize={11}
					position={UDim2.fromOffset(0, 22)}
					sizeConstraint={new UDim2(1, 0, 0, 34)}
				/>
			</Panel>
		);
	}
	const definition = config.Guild?.Goal?.Types?.find((entry) => entry.Id === goal.TypeId);
	const fill = math.clamp(goal.Progress / math.max(1, goal.Target), 0, 1);
	const accent = goal.Completed ? Palette.mint : Palette.mango;
	const surface = darken(accent, 0.9);
	const on = (color: Color3) => ensureContrast(surface, color);
	const sideWidth = new UDim2(1, stack ? 0 : -170, 0, 16);
	return (
		<Panel size={new UDim2(1, 0, 0, stack ? 234 : 196)} accent={accent} background={surface} padding={16} highlight={canClaim} reducedMotion={reducedMotion} clips={false}>
			<Text value={goal.Completed ? "GUILD GOAL • COMPLETE" : "GUILD GOAL"} size={10} color={on(accent)} weight={Enum.FontWeight.Heavy} sizeConstraint={new UDim2(1, -120, 0, 14)} />
			<Text
				value={definition?.Name ?? "Shared objective"}
				size={stack ? 20 : 25}
				color={on(Palette.cream)}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={15}
				position={UDim2.fromOffset(0, 18)}
				sizeConstraint={new UDim2(1, -8, 0, 32)}
			/>
			<Text
				value={definition?.Description ?? "Every deposit and build counts toward it."}
				size={11}
				color={on(Palette.creamSoft)}
				wrap={true}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(0, stack ? 50 : 52)}
				sizeConstraint={new UDim2(1, -8, 0, 30)}
			/>
			<Text
				value={now.map((timestamp) => (goal.EndsAt > timestamp ? `${clockText(math.max(0, goal.EndsAt - timestamp))} LEFT` : "WINDOW CLOSED"))}
				size={10}
				color={on(Palette.muted)}
				weight={Enum.FontWeight.Bold}
				align={Enum.TextXAlignment.Right}
				position={new UDim2(1, -150, 0, 0)}
				sizeConstraint={UDim2.fromOffset(150, 16)}
			/>
			<Meter value={fill} color={accent} position={new UDim2(0, 0, 0, stack ? 92 : 94)} size={new UDim2(1, 0, 0, 9)} reducedMotion={reducedMotion} shimmer={goal.Completed} />
			<Text
				value={`${compactNumber(goal.Progress)} / ${compactNumber(goal.Target)} ${goalUnitLabel(definition?.Metric ?? "")}`}
				size={10}
				color={on(Palette.creamSoft)}
				fit={true}
				minSize={8}
				position={UDim2.fromOffset(0, stack ? 106 : 108)}
				sizeConstraint={new UDim2(1, 0, 0, 16)}
			/>
			<Text
				value={mine > 0 ? `YOU HELPED WITH ${compactNumber(mine)}` : "YOU HAVE NOT HELPED YET"}
				size={10}
				color={on(mine > 0 ? Palette.mint : Palette.muted)}
				weight={Enum.FontWeight.Heavy}
				position={UDim2.fromOffset(0, stack ? 126 : 128)}
				sizeConstraint={sideWidth}
			/>
			{definition !== undefined && (
				<Text
					value={`REWARD  ${formatReward(definition.Reward as never)}`}
					size={10}
					color={on(Palette.muted)}
					fit={true}
					minSize={8}
					position={UDim2.fromOffset(0, stack ? 146 : 148)}
					sizeConstraint={sideWidth}
				/>
			)}
			<frame
				{...named("GuildClaimActions")}
				ref={canClaim ? claimHostRef : undefined}
				Size={stack ? new UDim2(1, 0, 0, 46) : UDim2.fromOffset(160, 46)}
				Position={stack ? new UDim2(0, 0, 1, -46) : new UDim2(1, -160, 1, -46)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={false}
			>
				<Button
					text={claimed ? "CLAIMED" : canClaim ? "CLAIM REWARD" : goal.Completed ? "NOT ELIGIBLE" : "NOT YET"}
					icon={claimed ? "Check.13" : "Gift.9"}
					onClick={() => {
						if (canClaim && !busy) dispatch("ClaimGuildGoal", {});
					}}
					color={canClaim ? Palette.mint : Palette.panelSoft}
					textColor={canClaim ? Palette.ink : Palette.creamSoft}
					disabled={!canClaim || busy}
					loading={canClaim && busy}
					shakeToken={canClaim ? shakeToken : 0}
					highlight={canClaim}
					size={UDim2.fromScale(1, 1)}
					reducedMotion={reducedMotion}
				/>
			</frame>
		</Panel>
	);
}

/** One hall upgrade: tier, what it does now and next, the bank against its price, and Buy. */
function UpgradeCard({ row, guild, canBuy, stack, reducedMotion, dispatch, busy, shakeToken, layoutOrder }: ActionProps & { row: UpgradeRow; guild: Guild; canBuy: boolean; stack: boolean; layoutOrder: number }) {
	const cash = row.config.Currency === "Cash";
	const bank = cash ? guild.BankCash : guild.BankDust;
	const fill = row.maxed ? 1 : math.clamp(bank / math.max(1, row.cost), 0, 1);
	const actionable = canBuy && row.affordable && !row.maxed;
	const side = stack ? 0 : -260;
	return (
		<Panel
			size={new UDim2(1, 0, 0, stack ? 180 : 140)}
			accent={row.accent}
			background={Palette.panelRaised}
			padding={stack ? 14 : 16}
			layoutOrder={layoutOrder}
			interactive={actionable}
			highlight={actionable}
			reducedMotion={reducedMotion}
			clips={false}
		>
			<Text value={row.config.Name} size={stack ? 15 : 17} color={Palette.cream} weight={Enum.FontWeight.Heavy} fit={true} minSize={12} sizeConstraint={new UDim2(1, stack ? -90 : -260, 0, 22)} />
			<Badge
				value={row.tierCount > 0 ? `TIER ${row.tierIndex}/${row.tierCount}` : `LV ${compactNumber(row.level)}`}
				accent={row.accent}
				filled={row.level > 0}
				position={new UDim2(1, stack ? -84 : -254, 0, 0)}
				size={UDim2.fromOffset(84, 24)}
			/>
			<Text
				value={row.config.Description}
				size={10}
				color={Palette.muted}
				wrap={true}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(0, 26)}
				sizeConstraint={new UDim2(1, side, 0, 28)}
			/>
			<Text
				value={
					row.maxed
						? `${percentText(row.currentEffect)}, fully installed`
						: `${percentText(row.currentEffect)} now to ${percentText(row.nextEffect)} at ${row.nextTierName ?? "the next level"}`
				}
				size={11}
				color={row.maxed ? Palette.mint : Palette.creamSoft}
				weight={Enum.FontWeight.Bold}
				fit={true}
				minSize={8}
				position={UDim2.fromOffset(0, stack ? 58 : 60)}
				sizeConstraint={new UDim2(1, side, 0, 18)}
			/>
			<Meter value={fill} color={row.accent} position={UDim2.fromOffset(0, stack ? 82 : 84)} size={new UDim2(1, side, 0, 6)} reducedMotion={reducedMotion} />
			<Text
				value={row.maxed ? "MAXED" : `BANK ${compactNumber(bank)} / ${compactNumber(row.cost)} ${cash ? "flux" : "dust"}`}
				size={10}
				color={row.affordable ? Palette.mint : Palette.muted}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={8}
				position={UDim2.fromOffset(0, stack ? 96 : 98)}
				sizeConstraint={new UDim2(1, side, 0, 16)}
			/>
			<Button
				text={row.maxed ? "MAXED" : row.affordable ? `BUY ${compactNumber(row.cost)}` : "NEED MORE"}
				icon={row.maxed ? "Check.14" : "Forge.15"}
				onClick={() => {
					if (actionable && !busy) dispatch("BuyGuildUpgrade", { Id: row.id });
				}}
				color={actionable ? row.accent : Palette.panelSoft}
				textColor={actionable ? Palette.ink : Palette.creamSoft}
				disabled={!actionable || busy}
				loading={actionable && busy}
				shakeToken={actionable ? shakeToken : 0}
				highlight={actionable}
				size={stack ? new UDim2(1, 0, 0, 44) : UDim2.fromOffset(240, 44)}
				position={stack ? new UDim2(0, 0, 1, -44) : new UDim2(1, -240, 1, -44)}
				reducedMotion={reducedMotion}
			/>
		</Panel>
	);
}

interface MemberRowProps extends ActionProps {
	userKey: string;
	name: string;
	role: string;
	contributed: number;
	goalShare: number;
	share: number;
	isLocal: boolean;
	canManage: boolean;
	myRole: string;
	stack: boolean;
	layoutOrder: number;
	onKick: () => void;
}

// shared by MemberRow and the list height, so the section is exactly as tall as its rows
function memberRowLayout(row: { canManage: boolean; myRole: string; role: string; stack: boolean }) {
	const manageable = row.canManage && Social.canManage({ Role: row.myRole }, { Role: row.role }, "Kick");
	const height = row.stack && !manageable ? 60 : row.stack ? 122 : manageable ? 112 : 84;
	return { manageable, height };
}

function MemberRow(props: MemberRowProps) {
	const { role, isLocal, stack, reducedMotion, busy, shakeToken } = props;
	const userId = tonumber(props.userKey) ?? 0;
	// the member's published profile accent, else the role colour
	const accent =
		ProfileStyle.fromPlayer(Players.GetPlayerByUserId(userId)).accent ?? (role === "Leader" ? Palette.mango : role === "Officer" ? Palette.cyan : Palette.steel);
	const surface = isLocal ? darken(Palette.green, 0.88) : Palette.panel;
	const { manageable, height } = memberRowLayout(props);
	const canPromote = props.myRole === "Leader";
	// phones, rows you can't manage: one compact block (name, role on the right, one stats line)
	const compactRow = stack && !manageable;
	const textX = compactRow ? 38 : 44;
	return (
		<Panel size={new UDim2(1, 0, 0, height)} accent={isLocal ? Palette.green : accent} background={surface} padding={stack ? 12 : 14} layoutOrder={props.layoutOrder} reducedMotion={reducedMotion} clips={false}>
			<PlayerMark userId={userId} accent={accent} size={compactRow ? 28 : 34} position={UDim2.fromOffset(0, compactRow ? 4 : 2)} />
			<Text
				value={props.name}
				size={14}
				color={ensureContrast(surface, Palette.cream)}
				weight={Enum.FontWeight.Bold}
				fit={true}
				minSize={10}
				position={UDim2.fromOffset(textX, 0)}
				sizeConstraint={new UDim2(1, compactRow ? (isLocal ? -38 - 118 : -38 - 70) : -44, 0, 20)}
			/>
			<Badge
				value={string.upper(role)}
				accent={accent}
				filled={role === "Leader" || role === "Officer"}
				position={compactRow ? new UDim2(1, -64, 0, 2) : UDim2.fromOffset(44, 20)}
				size={UDim2.fromOffset(role === "Leader" ? 60 : role === "Officer" ? 64 : 58, 16)}
			/>
			{isLocal && (
				<Badge value="YOU" accent={Palette.green} filled={true} position={new UDim2(1, compactRow ? -114 : -48, 0, 2)} size={UDim2.fromOffset(44, compactRow ? 16 : 18)} />
			)}
			<Text
				value={`${compactNumber(props.contributed)} banked  •  ${math.floor(props.share * 100 + 0.5)}%${compactRow ? "" : " of all deposits"}${compactRow && props.goalShare > 0 ? `  •  ${compactNumber(props.goalShare)} to goal` : ""}`}
				size={10}
				color={ensureContrast(surface, Palette.muted)}
				fit={true}
				minSize={8}
				position={UDim2.fromOffset(textX, compactRow ? 22 : 38)}
				sizeConstraint={new UDim2(1, -44, 0, 16)}
			/>
			{!compactRow && props.goalShare > 0 && (
				<Text
					value={`${compactNumber(props.goalShare)} toward this goal`}
					size={9}
					color={ensureContrast(surface, Palette.mint)}
					weight={Enum.FontWeight.Heavy}
					position={UDim2.fromOffset(44, 54)}
					sizeConstraint={new UDim2(1, -44, 0, 14)}
				/>
			)}
			{manageable && (
				<Button
					text={!canPromote ? "LEADER ONLY" : role === "Officer" ? "DEMOTE" : "PROMOTE"}
					onClick={() => {
						if (!busy) props.dispatch("SetGuildRole", { UserId: userId, Role: role === "Officer" ? "Member" : "Officer" });
					}}
					color={Palette.panelSoft}
					textColor={Palette.creamSoft}
					disabled={busy || !canPromote}
					loading={busy}
					shakeToken={shakeToken}
					size={new UDim2(0.5, -4, 0, 40)}
					position={new UDim2(0, 0, 1, -40)}
					reducedMotion={reducedMotion}
				/>
			)}
			{manageable && (
				<Button
					text="KICK"
					onClick={() => {
						if (!busy) props.onKick();
					}}
					color={Palette.panelSoft}
					textColor={Palette.coral}
					disabled={busy}
					loading={busy}
					shakeToken={shakeToken}
					size={new UDim2(0.5, -4, 0, 40)}
					position={new UDim2(0.5, 4, 1, -40)}
					reducedMotion={reducedMotion}
				/>
			)}
		</Panel>
	);
}

/** No guild yet: charter one (name, tag, flux) or join an existing one by its tag. */
function JoinOrCreate({ config, dispatch, reducedMotion, busy, shakeToken, cash }: ActionProps & { config: Config; cash?: Flux }) {
	const [name, setName] = React.useState("");
	const [tag, setTag] = React.useState("");
	const [joinTag, setJoinTag] = React.useState("");
	const createCost = config.Guild?.CreateCost ?? 5000;
	const canAfford = gteFlux(cash ?? 0, createCost);
	const trimmedName = name.gsub("^%s+", "")[0].gsub("%s+$", "")[0];
	const canCharter = !busy && trimmedName.size() >= 3 && tag.size() >= 3 && canAfford;
	const canJoin = !busy && joinTag.size() >= 3;
	const charter = () => {
		if (canCharter) dispatch("CreateGuild", { Name: trimmedName, Tag: sanitizeGuildTag(tag) });
	};
	const join = () => {
		if (canJoin) dispatch("JoinGuild", { Tag: sanitizeGuildTag(joinTag) });
	};
	return (
		<>
			<Panel size={new UDim2(1, 0, 0, 276)} accent={Palette.violet} background={Palette.panelRaised} padding={18} layoutOrder={1} reducedMotion={reducedMotion} clips={false}>
				<Text value="CHARTER A GUILD" size={10} color={Palette.violet} weight={Enum.FontWeight.Heavy} sizeConstraint={new UDim2(1, 0, 0, 14)} />
				<Text value="Start your own hall" size={26} weight={Enum.FontWeight.Heavy} fit={true} minSize={16} position={UDim2.fromOffset(0, 18)} sizeConstraint={new UDim2(1, 0, 0, 32)} />
				<Text
					value={`Costs ${compactNumber(createCost)} flux · you have ${compactNumber(cash)}. You lead it and share every hall upgrade.`}
					size={11}
					color={canAfford ? Palette.creamSoft : Palette.coral}
					wrap={true}
					fit={true}
					minSize={10}
					position={UDim2.fromOffset(0, 52)}
					sizeConstraint={new UDim2(1, 0, 0, 32)}
				/>
				<Field placeholder="Guild name (3-28 characters)" value={name} onChange={(text) => setName(cutBytes(text, 28))} position={UDim2.fromOffset(0, 90)} onEnter={charter} />
				<Field placeholder="Tag (3-4 letters or numbers)" value={tag} onChange={(text) => setTag(sanitizeGuildTag(text))} position={UDim2.fromOffset(0, 138)} onEnter={charter} />
				<Button
					text={!canAfford ? `NEED ${compactNumber(createCost)} FLUX` : "CHARTER GUILD"}
					icon="Forge.16"
					onClick={charter}
					color={canCharter ? Palette.violet : Palette.panelSoft}
					textColor={canCharter ? Palette.ink : Palette.muted}
					disabled={!canCharter}
					loading={canAfford && busy}
					shakeToken={canAfford ? shakeToken : 0}
					size={new UDim2(1, 0, 0, TapTarget)}
					position={new UDim2(0, 0, 1, -TapTarget)}
					reducedMotion={reducedMotion}
				/>
			</Panel>
			<Panel size={new UDim2(1, 0, 0, 192)} accent={Palette.mint} padding={18} layoutOrder={2} reducedMotion={reducedMotion} clips={false}>
				<Text value="JOIN A GUILD" size={10} color={Palette.mint} weight={Enum.FontWeight.Heavy} sizeConstraint={new UDim2(1, 0, 0, 14)} />
				<Text
					value="Already know a tag? Type it in and jump into the hall."
					size={11}
					color={Palette.creamSoft}
					wrap={true}
					fit={true}
					minSize={10}
					position={UDim2.fromOffset(0, 20)}
					sizeConstraint={new UDim2(1, 0, 0, 30)}
				/>
				<Field placeholder="Guild tag" value={joinTag} onChange={(text) => setJoinTag(sanitizeGuildTag(text))} position={UDim2.fromOffset(0, 56)} onEnter={join} />
				<Button
					text="JOIN GUILD"
					icon="Crew.9"
					onClick={join}
					color={canJoin ? Palette.mint : Palette.panelSoft}
					textColor={canJoin ? Palette.ink : Palette.muted}
					disabled={!canJoin}
					loading={canJoin && busy}
					shakeToken={canJoin ? shakeToken : 0}
					size={new UDim2(1, 0, 0, TapTarget)}
					position={new UDim2(0, 0, 1, -TapTarget)}
					reducedMotion={reducedMotion}
				/>
			</Panel>
		</>
	);
}

/** The Community pane: guild channel, announcements and, for staff, moderation, rules, rename and logos. */
function GuildCommunityPanel({ guild, dispatch, reducedMotion, stack, role, config, onBack }: { guild: Guild; dispatch: Dispatch; reducedMotion?: boolean; stack: boolean; role: string; config: Config; onBack: () => void }) {
	const guildConfig = config.Guild;
	const community = guild.Community ?? {};
	const [settings, setSettings] = React.useState<GuildSettings>(community.Settings ?? { ChatEnabled: true, AnnouncementsEnabled: true, LogoEnabled: true });
	const [messages, setMessages] = React.useState<ChatMessage[]>(community.Chat ?? []);
	const [announcements, setAnnouncements] = React.useState<Announcement[]>(community.Announcements ?? []);
	const [logos, setLogos] = React.useState<Logo[]>([]);
	const [chatDraft, setChatDraft] = React.useState("");
	const [announcementTitle, setAnnouncementTitle] = React.useState("");
	const [announcementBody, setAnnouncementBody] = React.useState("");
	const [logoAsset, setLogoAsset] = React.useState("");
	const [moderationUserId, setModerationUserId] = React.useState("");
	const [renameName, setRenameName] = React.useState("");
	const [renameTag, setRenameTag] = React.useState("");
	// the action in flight ("" when idle): one at a time, and its own button shows the spinner
	const [busy, setBusy] = React.useState("");
	const chatScroll = React.useRef<ScrollingFrame>();
	const localUserId = Players.LocalPlayer.UserId;
	const leader = role === "Leader";
	const manager = leader || role === "Officer";
	const chatOn = settings.ChatEnabled !== false;
	const requestCommunity = React.useCallback(() => {
		dispatch("GetGuildChatHistory", { Limit: 50 }, (result) => {
			if (result.ok) setMessages(result.Messages ?? []);
		});
		dispatch("GetGuildAnnouncements", {}, (result) => {
			if (result.ok) setAnnouncements(result.Announcements ?? []);
		});
		dispatch("GetGuildSettings", {}, (result) => {
			if (result.ok) setSettings(result.Settings ?? {});
		});
		if (leader) {
			dispatch("GetGuildLogoReview", {}, (result) => {
				if (result.ok) setLogos(result.Logos ?? []);
			});
		}
	}, [dispatch, manager, guild.Id]);
	// load on open, poll gently, and take live packets for this guild from the effect feed
	React.useEffect(() => {
		requestCommunity();
		let alive = true;
		const worker = task.spawn(() => {
			while (alive) {
				task.wait(8);
				if (alive) requestCommunity();
			}
		});
		const connection = Dependency<EffectFeedController>().connect((raw: unknown) => {
			const packet = raw as { GuildId?: string; Type?: string; Message?: ChatMessage; Refresh?: boolean };
			if (!alive || !typeIs(packet, "table") || packet.GuildId !== guild.Id) return;
			const message = packet.Message;
			if (packet.Type === "GuildChat" && typeIs(message, "table")) {
				setMessages((previous) => {
					if (previous.find((existing) => existing.Id === message.Id) !== undefined) return previous;
					const updated = [...previous, message];
					while (updated.size() > 50) updated.remove(0);
					return updated;
				});
			} else if (packet.Refresh === true || ["GuildAnnouncement", "GuildSettings", "GuildLogo", "GuildModeration"].includes(packet.Type ?? "")) {
				// Refresh: another server changed something too large to relay inline
				requestCommunity();
			}
		});
		return () => {
			alive = false;
			connection.Disconnect();
			pcall(task.cancel, worker);
		};
	}, [requestCommunity, guild.Id]);
	// new messages scroll the channel to the bottom
	React.useEffect(() => {
		const frame = chatScroll.current;
		if (frame === undefined) return undefined;
		const job = task.defer(() => {
			if (frame.Parent !== undefined) frame.CanvasPosition = new Vector2(0, math.max(0, frame.AbsoluteCanvasSize.Y - frame.AbsoluteWindowSize.Y));
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [messages.size()]);
	const run = (action: string, payload: object, done?: (result: Reply) => void) => {
		if (busy !== "") return;
		setBusy(action);
		dispatch(action, payload, (result) => {
			setBusy("");
			if (result.ok) requestCommunity();
			done?.(result);
		});
	};
	const idle = busy === "";
	const sendChat = () => {
		if (chatDraft === "" || !chatOn) return;
		run("SendGuildChat", { Content: chatDraft }, (result) => {
			if (result.ok) setChatDraft("");
		});
	};

	let previousSpeaker: number | undefined;
	const chatRows = messages.map((message, index) => {
		const own = message.SpeakerUserId === localUserId;
		const grouped = previousSpeaker === message.SpeakerUserId;
		previousSpeaker = message.SpeakerUserId;
		const stamp = typeIs(message.PublishedAt, "number") ? os.date("%H:%M", message.PublishedAt) : "";
		const roleTag = message.SpeakerRole !== undefined && message.SpeakerRole !== "Member" ? `  ·  ${string.upper(message.SpeakerRole)}` : "";
		return (
			<frame key={message.Id ?? tostring(index + 1)} LayoutOrder={index + 1} Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1}>
				<uipadding PaddingLeft={new UDim(0, own ? 40 : 0)} PaddingRight={new UDim(0, own ? 0 : 40)} PaddingTop={new UDim(0, grouped ? 0 : 4)} />
				<frame
					Size={new UDim2(1, 0, 0, 0)}
					AutomaticSize={Enum.AutomaticSize.Y}
					BackgroundColor3={own ? Palette.cyan : Palette.panelSoft}
					BackgroundTransparency={own ? 0.82 : 0.35}
					BorderSizePixel={0}
				>
					<uicorner CornerRadius={new UDim(0, 10)} />
					<uipadding PaddingLeft={new UDim(0, 10)} PaddingRight={new UDim(0, 10)} PaddingTop={new UDim(0, 6)} PaddingBottom={new UDim(0, 6)} />
					<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 2)} />
					{!grouped && (
						<textlabel
							LayoutOrder={1}
							Size={new UDim2(1, 0, 0, 16)}
							BackgroundTransparency={1}
							Text={`${message.SpeakerName ?? tostring(message.SpeakerUserId)}${roleTag}   ${stamp}`}
							TextColor3={ROLE_COLORS[message.SpeakerRole ?? ""] ?? Palette.creamSoft}
							TextSize={12}
							TextXAlignment={Enum.TextXAlignment.Left}
							FontFace={Font.fromEnum(Enum.Font.BuilderSansBold)}
						/>
					)}
					<textlabel
						LayoutOrder={2}
						Size={new UDim2(1, 0, 0, 0)}
						AutomaticSize={Enum.AutomaticSize.Y}
						BackgroundTransparency={1}
						Text={tostring(message.Message ?? "")}
						TextColor3={Palette.cream}
						TextSize={14}
						TextWrapped={true}
						TextXAlignment={Enum.TextXAlignment.Left}
						FontFace={Font.fromEnum(Enum.Font.BuilderSansMedium)}
					/>
				</frame>
			</frame>
		);
	});

	const announcementRows =
		announcements.size() === 0
			? [<Text key="no-announcements" value="Quiet for now. When a leader posts news, it shows up here." size={12} color={Palette.muted} />]
			: announcements.map((item) => (
					<Panel key={item.Id} size={new UDim2(1, 0, 0, 116)} accent={item.Pinned ? Palette.mango : Palette.cyan} padding={12} reducedMotion={reducedMotion}>
						<Text
							value={`${item.Pinned ? "[PINNED] " : ""}${item.Title}  ·  ${item.AuthorName ?? "Guild staff"}`}
							size={13}
							weight={Enum.FontWeight.Bold}
							fit={true}
							sizeConstraint={new UDim2(1, 0, 0, 22)}
						/>
						<Text value={item.Body} size={11} color={Palette.creamSoft} wrap={true} fit={true} minSize={10} position={UDim2.fromOffset(0, 28)} sizeConstraint={new UDim2(1, 0, 0, 52)} />
						{manager && (
							<Button
								text={item.Pinned ? "UNPIN" : "PIN"}
								onClick={() => run("PinGuildAnnouncement", { AnnouncementId: item.Id, Pinned: !item.Pinned })}
								color={Palette.panelSoft}
								size={UDim2.fromOffset(92, 32)}
								position={new UDim2(1, -96, 1, -32)}
								disabled={!idle}
								reducedMotion={reducedMotion}
							/>
						)}
						{manager && (
							<Button
								text="ARCHIVE"
								onClick={() => run("ArchiveGuildAnnouncement", { AnnouncementId: item.Id })}
								color={Palette.panelSoft}
								textColor={Palette.coral}
								size={UDim2.fromOffset(92, 32)}
								position={new UDim2(1, -194, 1, -32)}
								disabled={!idle}
								reducedMotion={reducedMotion}
							/>
						)}
						<Text
							value={typeIs(item.PublishedAt, "number") ? `${os.date("%b %d · %H:%M", item.PublishedAt)}${item.EditedAt !== undefined ? " · edited" : ""}` : ""}
							size={10}
							color={Palette.muted}
							position={new UDim2(0, 0, 1, -24)}
							sizeConstraint={new UDim2(1, -200, 0, 18)}
						/>
					</Panel>
				));

	const sections: Section[] = [
		{
			id: "guild-community-back",
			height: 48,
			element: <Button text="‹  GUILD OVERVIEW" onClick={onBack} color={Palette.panelSoft} textColor={Palette.cream} size={new UDim2(1, 0, 0, 44)} reducedMotion={reducedMotion} />,
		},
		{
			id: "guild-community-chat",
			height: 430,
			element: (
				<Panel size={UDim2.fromScale(1, 1)} accent={Palette.cyan} padding={14} reducedMotion={reducedMotion} clips={false}>
					<Text
						value={`GUILD CHANNEL · ${messages.size()} MESSAGE${messages.size() === 1 ? "" : "S"}${settings.SlowMode === true ? " · SLOW MODE" : ""}`}
						size={12}
						color={Palette.cyan}
						weight={Enum.FontWeight.Heavy}
						sizeConstraint={new UDim2(1, 0, 0, 20)}
					/>
					<scrollingframe
						ref={chatScroll}
						Size={new UDim2(1, 0, 0, 308)}
						Position={UDim2.fromOffset(0, 26)}
						BackgroundColor3={Palette.void}
						BackgroundTransparency={0.35}
						BorderSizePixel={0}
						CanvasSize={new UDim2()}
						AutomaticCanvasSize={Enum.AutomaticSize.Y}
						ScrollingDirection={Enum.ScrollingDirection.Y}
						ScrollBarThickness={3}
						ScrollBarImageColor3={Palette.cyan}
					>
						<uicorner CornerRadius={new UDim(0, 12)} />
						<uipadding PaddingLeft={new UDim(0, 8)} PaddingRight={new UDim(0, 8)} PaddingTop={new UDim(0, 8)} PaddingBottom={new UDim(0, 8)} />
						<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 8)} />
						{chatRows.size() > 0 ? chatRows : <EmptyState key="no-chat" icon="Chat" title="No messages yet" body="Only members of this guild can see the chat." accent={Palette.cyan} compact={true} />}
					</scrollingframe>
					<Field
						placeholder={chatOn ? "Message your guild…" : "Leader turned chat off"}
						value={chatDraft}
						onChange={(text) => setChatDraft(cutBytes(text, 400))}
						size={new UDim2(1, -112, 0, 42)}
						position={UDim2.fromOffset(0, 344)}
						editable={chatOn}
						onEnter={sendChat}
						stroke={false}
					/>
					<Button
						text="SEND"
						onClick={sendChat}
						color={Palette.cyan}
						textColor={Palette.ink}
						size={UDim2.fromOffset(104, 42)}
						position={new UDim2(1, -104, 0, 344)}
						disabled={!idle || !chatOn || chatDraft === ""}
						loading={busy === "SendGuildChat"}
						reducedMotion={reducedMotion}
					/>
					<Text
						value={`${chatDraft.size()}/400 · filtered by Roblox · members only`}
						size={10}
						color={Palette.muted}
						position={UDim2.fromOffset(0, 390)}
						sizeConstraint={new UDim2(1, 0, 0, 16)}
					/>
				</Panel>
			),
		},
		{
			id: "guild-community-announcements",
			height: math.max(168, announcementRows.size() * 126 + (manager ? 164 : 64)),
			element: (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
					<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 10)} />
					<SectionLabel value="Announcements" color={Palette.mango} />
					{manager && (
						<Panel size={new UDim2(1, 0, 0, 154)} accent={Palette.mango} padding={12} clips={false}>
							<Field placeholder="Announcement title" value={announcementTitle} onChange={(text) => setAnnouncementTitle(cutBytes(text, 120))} size={new UDim2(1, 0, 0, 40)} stroke={false} />
							<Field
								placeholder="Announcement body"
								value={announcementBody}
								onChange={(text) => setAnnouncementBody(cutBytes(text, 800))}
								size={new UDim2(1, 0, 0, 46)}
								position={UDim2.fromOffset(0, 44)}
								stroke={false}
							/>
							<Button
								text="PUBLISH"
								onClick={() =>
									run("CreateGuildAnnouncement", { Title: announcementTitle, Body: announcementBody }, (result) => {
										if (!result.ok) return;
										setAnnouncementTitle("");
										setAnnouncementBody("");
									})
								}
								color={Palette.mango}
								textColor={Palette.ink}
								size={new UDim2(1, 0, 0, 36)}
								position={new UDim2(0, 0, 1, -36)}
								disabled={!idle || settings.AnnouncementsEnabled === false || announcementTitle === "" || announcementBody === ""}
								reducedMotion={reducedMotion}
							/>
							{settings.AnnouncementsEnabled === false && (
								<Text value="The guild leader turned announcements off." size={11} minSize={9} fit={true} color={Palette.coral} position={UDim2.fromOffset(0, -16)} />
							)}
						</Panel>
					)}
					{announcementRows}
				</frame>
			),
		},
	];
	if (manager) {
		const target = tonumber(moderationUserId);
		sections.push({
			id: "guild-community-moderation",
			height: 146,
			element: (
				<Panel size={UDim2.fromScale(1, 1)} accent={Palette.coral} padding={14} clips={false}>
					<SectionLabel value="Moderation" color={Palette.coral} />
					<Field placeholder="Guild member user ID" value={moderationUserId} onChange={(text) => setModerationUserId(text.sub(1, 20))} position={UDim2.fromOffset(0, 28)} stroke={false} />
					<frame Size={new UDim2(1, 0, 0, 40)} Position={UDim2.fromOffset(0, 76)} BackgroundTransparency={1}>
						{MODERATION.map(([action, label, color], i) => (
							<Button
								key={action}
								text={label}
								onClick={() => {
									if (target !== undefined && target > 0) run(action, { UserId: math.floor(target) });
								}}
								color={color}
								textColor={Palette.ink}
								size={new UDim2(0.25, -6, 0, 40)}
								position={new UDim2(i * 0.25, 0, 0, 0)}
								disabled={!idle || target === undefined}
								reducedMotion={reducedMotion}
							/>
						))}
					</frame>
				</Panel>
			),
		});
	}
	if (leader) {
		sections.push({
			id: "guild-community-settings",
			height: 160,
			element: (
				<Panel size={UDim2.fromScale(1, 1)} accent={Palette.violet} padding={14}>
					<SectionLabel value="Guild rules" color={Palette.violet} />
					<frame Size={new UDim2(1, 0, 0, 90)} Position={UDim2.fromOffset(0, 26)} BackgroundTransparency={1}>
						{SETTING_KEYS.map((key, i) => {
							const enabled = key === "SlowMode" ? settings[key] === true : settings[key] !== false;
							return (
								<Button
									key={key}
									text={`${SETTING_LABELS[key]}  ${enabled ? "ON" : "OFF"}`}
									onClick={() => {
										setSettings({ ...settings, [key]: !enabled });
										run("SetGuildSettings", { Settings: { [key]: !enabled } });
									}}
									color={enabled ? Palette.mint : Palette.panelSoft}
									textColor={enabled ? Palette.ink : Palette.cream}
									size={new UDim2(1 / 3, -6, 0, 42)}
									position={new UDim2((i % 3) / 3, 0, 0, math.floor(i / 3) * 48)}
									disabled={!idle}
									reducedMotion={reducedMotion}
								/>
							);
						})}
					</frame>
					<Text
						value="Choose what officers can manage. Slow mode adds 6 seconds between member messages."
						size={11}
						color={Palette.muted}
						wrap={true}
						fit={true}
						minSize={9}
						position={UDim2.fromOffset(0, 116)}
						sizeConstraint={new UDim2(1, 0, 0, 16)}
					/>
				</Panel>
			),
		});
		const cooldownDays = math.floor((guildConfig?.RenameCooldownSeconds ?? 604800) / 86400);
		const renameReady = renameName.size() >= 3 || renameTag.size() >= 3;
		sections.push({
			id: "guild-community-rename",
			height: 178,
			element: (
				<Panel size={UDim2.fromScale(1, 1)} accent={Palette.mango} padding={14} clips={false}>
					<SectionLabel value={`Rename ${guild.Name ?? ""} [${guild.Tag ?? "?"}]`} color={Palette.mango} />
					<Field placeholder="New guild name (3–28)" value={renameName} onChange={(text) => setRenameName(cutBytes(text, 28))} size={new UDim2(0.7, -6, 0, 42)} position={UDim2.fromOffset(0, 28)} stroke={false} />
					<Field
						placeholder="TAG"
						value={renameTag}
						onChange={(text) => setRenameTag(string.upper(text.gsub("[^%w]", "")[0].sub(1, 4)))}
						size={new UDim2(0.3, 0, 0, 42)}
						position={new UDim2(0.7, 0, 0, 28)}
						stroke={false}
					/>
					<Button
						text="RENAME GUILD"
						onClick={() =>
							run("RenameGuild", { Name: renameName.size() >= 3 ? renameName : (guild.Name ?? ""), Tag: renameTag.size() >= 3 ? renameTag : undefined }, (result) => {
								if (!result.ok) return;
								setRenameName("");
								setRenameTag("");
							})
						}
						color={Palette.mango}
						textColor={Palette.ink}
						size={new UDim2(1, 0, 0, 40)}
						position={UDim2.fromOffset(0, 78)}
						disabled={!idle || !renameReady}
						loading={busy === "RenameGuild"}
						reducedMotion={reducedMotion}
					/>
					<Text
						value={`Costs ${guildConfig?.RenameCost ?? 10000} flux · once every ${cooldownDays} days · names are filtered`}
						size={10}
						color={Palette.muted}
						position={UDim2.fromOffset(0, 124)}
						sizeConstraint={new UDim2(1, 0, 0, 16)}
					/>
				</Panel>
			),
		});
	}
	if (manager) {
		const activeLogo = community.Logo;
		sections.push({
			id: "guild-community-logo",
			height: 164 + logos.size() * 94,
			element: (
				<Panel size={UDim2.fromScale(1, 1)} accent={Palette.violet} padding={14} clips={false}>
					<SectionLabel value="Guild logo" color={Palette.violet} />
					{activeLogo?.URL !== undefined && (
						<imagelabel Size={UDim2.fromOffset(56, 56)} Position={new UDim2(1, -60, 0, 0)} BackgroundTransparency={1} Image={activeLogo.URL} ScaleType={Enum.ScaleType.Fit} />
					)}
					<Field placeholder="Roblox image asset ID" value={logoAsset} onChange={(text) => setLogoAsset(cutBytes(text, 800))} position={UDim2.fromOffset(0, 28)} stroke={false} />
					<Button
						text="SUBMIT FOR REVIEW"
						onClick={() =>
							run("UploadGuildLogo", { URL: logoAsset }, (result) => {
								if (result.ok) setLogoAsset("");
							})
						}
						color={Palette.violet}
						textColor={Palette.cream}
						size={new UDim2(1, 0, 0, 38)}
						position={UDim2.fromOffset(0, 76)}
						disabled={!idle || settings.LogoEnabled === false || logoAsset === ""}
						reducedMotion={reducedMotion}
					/>
					<frame Size={new UDim2(1, 0, 0, logos.size() * 90)} Position={UDim2.fromOffset(0, 120)} BackgroundTransparency={1}>
						<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 6)} />
						{logos.map((logo) => (
							<Panel key={logo.Id} size={new UDim2(1, 0, 0, 84)} accent={Palette.violet} padding={10}>
								<imagelabel Size={UDim2.fromOffset(52, 52)} BackgroundTransparency={1} Image={logo.URL ?? ""} ScaleType={Enum.ScaleType.Fit} />
								<Text value={`Logo ${logo.Id.sub(1, 8)} · pending`} size={12} fit={true} position={UDim2.fromOffset(58, 4)} sizeConstraint={new UDim2(1, -220, 0, 22)} />
								<Button
									text="APPROVE"
									onClick={() => run("ModerateGuildLogo", { LogoId: logo.Id, Decision: "approved" })}
									color={Palette.mint}
									size={UDim2.fromOffset(92, 34)}
									position={new UDim2(1, -196, 0, 12)}
									disabled={!idle}
									reducedMotion={reducedMotion}
								/>
								<Button
									text="REJECT"
									onClick={() => run("ModerateGuildLogo", { LogoId: logo.Id, Decision: "rejected", Reason: "Did not meet guild logo guidelines." })}
									color={Palette.panelSoft}
									textColor={Palette.coral}
									size={UDim2.fromOffset(92, 34)}
									position={new UDim2(1, -98, 0, 12)}
									disabled={!idle}
									reducedMotion={reducedMotion}
								/>
							</Panel>
						))}
					</frame>
				</Panel>
			),
		});
	}
	return <PageScaffold gap={10} tailPad={scrollTail(stack, 0, 72)} scrollBarColor={Palette.cyan} scrollBarThickness={4} sections={sections} />;
}

function GuildView(props: Props) {
	const { state, config, dispatch } = props;
	const softMotion = props.reducedMotion;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const stack = chrome.contentStack;
	const enter = useEntrance(softMotion);
	const reveal = useStagger(0, softMotion);
	// the request handle mutates in place; this counter re-renders when it changes
	const [, refreshRequest] = React.useState(0);
	const request = React.useMemo(
		() => createRequest(dispatch as never, task.delay, () => refreshRequest((v) => v + 1)),
		[dispatch],
	);
	React.useEffect(() => {
		request.alive = true;
		return () => request.dispose();
	}, [request]);
	const busy = request.busy;
	const [pane, setPane] = React.useState(props.initialTab ?? "Overview");
	const [shakeToken, setShakeToken] = React.useState(0);
	const [contributeCash, setContributeCash] = React.useState("");
	const [contributeDust, setContributeDust] = React.useState("");
	// member search lives above the no-guild early return so hook order never changes
	const [memberQuery, setMemberQuery] = Browse.useLinkedQuery("GuildMembers");
	const [memberRole, setMemberRole] = React.useState("All");
	const guild = state.Guild;
	const key = localKey();
	React.useEffect(() => {
		dispatch("GetGuild", {});
	}, [dispatch]);
	const send: Dispatch = (action, payload, callback) =>
		request.run(action, payload, (response) => {
			if (!response.ok) setShakeToken((token) => token + 1);
			callback?.(response as Reply);
		});
	/** Leave, disband and kick go through the confirm dialog first. */
	const confirmThen = (title: string, body: string, confirmText: string, run: () => void) =>
		requestConfirm({ title, body, confirmText, tone: "danger", onConfirm: run, onCancel: () => {} });
	// the result of the last guild action, at 0-based t; the panel only exists while there is one to show
	const withStatus = (list: Section[], at: number): Section[] => {
		if (request.status !== "") {
			list.insert(
				at,
				{
					id: "guild-feedback",
					height: 72,
					element: (
						<Panel size={UDim2.fromScale(1, 1)} padding={16} accent={Palette.cyan}>
							<Text value={request.status} size={13} wrap={true} fit={true} minSize={11} sizeConstraint={new UDim2(1, 0, 0, 40)} />
						</Panel>
					),
				},
			);
		}
		return list;
	};
	const pageGap = stack ? 12 : Layout.panelGap;

	if (guild === undefined || guild.Id === "") {
		const guide = config.ClientPageGuides?.Guild;
		return (
			<PageScaffold
				gap={pageGap}
				tailPad={scrollTail(chrome.stack, chrome.bottomSafe, 80)}
				scrollBarColor={Palette.violet}
				scrollBarThickness={4}
				sections={withStatus(
					[
						{
							id: "empty-hero",
							height: 128,
							element: (
								<Panel size={UDim2.fromScale(1, 1)} accent={Palette.violet} background={Palette.panelRaised} padding={stack ? 16 : 20} highlight={true} reveal={enter} reducedMotion={softMotion} clips={false}>
									<Text value={guide?.EmptyTitle ?? "No guild yet"} size={20} color={Palette.cream} weight={Enum.FontWeight.Heavy} sizeConstraint={new UDim2(1, 0, 0, 28)} />
									<Text
										value={guide?.EmptyBody ?? "Charter one for shared upgrades, or join with a tag."}
										size={12}
										color={Palette.creamSoft}
										wrap={true}
										fit={true}
										minSize={11}
										position={UDim2.fromOffset(0, 34)}
										sizeConstraint={new UDim2(1, 0, 0, 36)}
									/>
									<Text
										value={guide?.Benefits ?? "Shared production, vault, offline, automation, and tap boosts."}
										size={11}
										color={Palette.violet}
										weight={Enum.FontWeight.Bold}
										wrap={true}
										fit={true}
										minSize={10}
										position={UDim2.fromOffset(0, 78)}
										sizeConstraint={new UDim2(1, 0, 0, 28)}
									/>
								</Panel>
							),
						},
						{
							id: "join",
							height: 276 + pageGap + 192,
							element: (
								<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
									<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, pageGap)} />
									<JoinOrCreate config={config} dispatch={send} reducedMotion={softMotion} busy={busy} shakeToken={shakeToken} cash={state.Cash} />
								</frame>
							),
						},
					],
					0,
				)}
			/>
		);
	}

	const myRole = guild.Members[key]?.Role ?? "Member";
	if (pane === "Community") {
		return <GuildCommunityPanel guild={guild} dispatch={dispatch} reducedMotion={softMotion} stack={stack} role={myRole} config={config} onBack={() => setPane("Overview")} />;
	}

	// leaders first, then officers, then members; richest contributors first inside each
	const members: Array<{ key: string; name: string; role: string; contributed: number }> = [];
	for (const [memberKey, member] of pairs(guild.Members)) {
		members.push({ key: memberKey, name: member.Name, role: member.Role, contributed: member.Contributed });
	}
	members.sort((left, right) => {
		const leftRank = ROLE_RANK[left.role] ?? 3;
		const rightRank = ROLE_RANK[right.role] ?? 3;
		return leftRank !== rightRank ? leftRank < rightRank : left.contributed > right.contributed;
	});
	let totalContributed = 0;
	for (const member of members) totalContributed += member.contributed;
	const canManage = myRole === "Leader";
	const canBuy = myRole === "Leader" || myRole === "Officer";
	const actions = { reducedMotion: softMotion, dispatch: send, busy, shakeToken };
	const heroSurface = darken(Palette.violet, 0.9);
	const bonus = (kind: string) => percentText(state.GuildBonuses?.[kind] ?? 0);
	const lastOne = canManage && members.size() === 1;
	const heroButton = (
		<Button
			text={lastOne ? "DISBAND" : "LEAVE"}
			onClick={() => {
				if (busy) return;
				if (lastOne) {
					confirmThen("Disband your guild?", "The hall and its bank close for good.", "Disband", () => send("DisbandGuild", {}));
				} else {
					confirmThen("Leave this guild?", "Leaving a guild does not refund contributions.", "Leave", () => send("LeaveGuild", {}));
				}
			}}
			color={Palette.panelSoft}
			textColor={Palette.coral}
			disabled={busy}
			loading={busy}
			shakeToken={shakeToken}
			size={stack ? new UDim2(1, 0, 0, 42) : UDim2.fromOffset(140, 42)}
			position={stack ? new UDim2(0, 0, 1, -42) : new UDim2(1, -140, 0, 0)}
			reducedMotion={softMotion}
		/>
	);
	const hero = (
		<Panel size={UDim2.fromScale(1, 1)} accent={Palette.violet} background={heroSurface} padding={stack ? 16 : 20} reveal={reveal} highlight={!softMotion} reducedMotion={softMotion} clips={false}>
			<Text
				value={`[${guild.Tag}]  •  ${members.size()}/${config.Guild?.MaxMembers ?? 20} MEMBERS`}
				size={10}
				color={ensureContrast(heroSurface, Palette.violet)}
				weight={Enum.FontWeight.Heavy}
				sizeConstraint={new UDim2(1, stack ? -8 : -160, 0, 14)}
			/>
			<Text
				value={guild.Name}
				size={stack ? 24 : 31}
				color={ensureContrast(heroSurface, Palette.cream)}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={17}
				position={UDim2.fromOffset(0, 20)}
				sizeConstraint={new UDim2(1, stack ? -8 : -160, 0, 38)}
			/>
			<Text
				value={`ACTIVITY ${compactNumber(guild.Activity)}  •  YOU ARE ${string.upper(myRole)}`}
				size={11}
				color={ensureContrast(heroSurface, Palette.creamSoft)}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(0, stack ? 62 : 64)}
				sizeConstraint={new UDim2(1, -8, 0, 18)}
			/>
			<Text
				value={`SHARED BONUSES  ${bonus("Production")} production  •  ${bonus("Capacity")} vault  •  ${bonus("Offline")} offline  •  ${bonus("Automation")} auto  •  ${bonus("Tap")} tap`}
				size={10}
				color={ensureContrast(heroSurface, Palette.mint)}
				wrap={true}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(0, stack ? 86 : 88)}
				sizeConstraint={new UDim2(1, -8, 0, stack ? 46 : 32)}
			/>
			{heroButton}
		</Panel>
	);
	const columns = stack ? 2 : 5;
	const tabs = (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
			{GUILD_TABS.map((id, i) => (
				<Button
					key={id}
					text={string.upper(id)}
					size={new UDim2(1 / columns, -6, 0, 48)}
					position={new UDim2((i % columns) / columns, 0, 0, math.floor(i / columns) * 56)}
					color={pane === id ? Palette.violet : Palette.panelSoft}
					onClick={() => setPane(id)}
					reducedMotion={softMotion}
				/>
			))}
		</frame>
	);
	const sections = withStatus(
		[
			{ id: "hero", height: stack ? 218 : 132, element: hero },
			{ id: "guild-navigation", height: math.ceil(GUILD_TABS.size() / columns) * 56, element: tabs },
		],
		1,
	);
	const add = (id: string, height: number, element: React.Element) => sections.push({ id, height, element });

	if (pane === "Overview") {
		const hall = Social.hall(guild);
		add(
			"hall-progress",
			stack ? 132 : 112,
			<Panel size={UDim2.fromScale(1, 1)} padding={16} accent={Palette.mint}>
				<Text value={`HALL LEVEL ${hall.Level} · ${hall.Title}`} size={19} wrap={true} fit={true} minSize={14} weight={Enum.FontWeight.Heavy} sizeConstraint={new UDim2(1, 0, 0, 26)} />
				<Meter value={hall.Progress} position={UDim2.fromOffset(0, 34)} size={new UDim2(1, 0, 0, 10)} color={Palette.mint} reducedMotion={softMotion} />
				<Text
					value={`${hall.Remaining} more upgrade level${hall.Remaining === 1 ? "" : "s"} to the next hall level. Every five installed upgrade levels add one.`}
					position={UDim2.fromOffset(0, 54)}
					size={13}
					color={Palette.creamSoft}
					wrap={true}
					fit={true}
					minSize={11}
					sizeConstraint={new UDim2(1, 0, 0, stack ? 44 : 24)}
				/>
			</Panel>,
		);
		add("goal", guild.Goal === undefined ? 116 : stack ? 234 : 196, <GuildGoalCard guild={guild} config={config} stack={stack} {...actions} />);
	} else if (pane === "Treasury") {
		const deposit = (draft: string, currency: string, clear: () => void) => {
			const amount = tonumber(draft);
			if (amount === undefined || amount < 1 || busy) return;
			send("ContributeGuild", { Amount: math.floor(amount), Currency: currency });
			clear();
		};
		const amountBox = (placeholder: string, value: string, onChange: (text: string) => void, position: UDim2) => (
			<Field placeholder={placeholder} value={value} onChange={onChange} size={stack ? new UDim2(1, 0, 0, 40) : new UDim2(0.5, -6, 0, 40)} position={position} />
		);
		add(
			"bank",
			stack ? 310 : 216,
			<Panel size={UDim2.fromScale(1, 1)} accent={Palette.mango} background={Palette.panelRaised} padding={stack ? 16 : 18} reducedMotion={softMotion} clips={false}>
				<Text value="GUILD BANK" size={10} color={Palette.mango} weight={Enum.FontWeight.Heavy} sizeConstraint={new UDim2(1, 0, 0, 14)} />
				<Text
					value={`${compactNumber(guild.BankCash)} flux  •  ${compactNumber(guild.BankDust)} dust`}
					size={stack ? 17 : 20}
					color={Palette.cream}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					minSize={13}
					position={UDim2.fromOffset(0, 18)}
					sizeConstraint={new UDim2(1, 0, 0, 26)}
				/>
				<Text
					value="Deposits fund every hall upgrade and count toward the guild goal."
					size={10}
					color={Palette.muted}
					wrap={true}
					fit={true}
					minSize={9}
					position={UDim2.fromOffset(0, 46)}
					sizeConstraint={new UDim2(1, 0, 0, 26)}
				/>
				{amountBox("Flux amount", contributeCash, setContributeCash, UDim2.fromOffset(0, 76))}
				<Button
					text="DEPOSIT FLUX"
					onClick={() => deposit(contributeCash, "Cash", () => setContributeCash(""))}
					color={Palette.mango}
					textColor={Palette.ink}
					disabled={busy || (tonumber(contributeCash) ?? 0) < 1}
					size={stack ? new UDim2(1, 0, 0, 42) : new UDim2(0.5, -6, 0, 42)}
					position={stack ? UDim2.fromOffset(0, 126) : UDim2.fromOffset(0, 128)}
					reducedMotion={softMotion}
				/>
				{amountBox("Dust amount", contributeDust, setContributeDust, stack ? UDim2.fromOffset(0, 172) : new UDim2(0.5, 6, 0, 76))}
				<Button
					text="DEPOSIT DUST"
					onClick={() => deposit(contributeDust, "Dust", () => setContributeDust(""))}
					color={Palette.cyan}
					textColor={Palette.ink}
					disabled={busy || (tonumber(contributeDust) ?? 0) < 1}
					size={stack ? new UDim2(1, 0, 0, 42) : new UDim2(0.5, -6, 0, 42)}
					position={stack ? UDim2.fromOffset(0, 222) : new UDim2(0.5, 6, 0, 128)}
					reducedMotion={softMotion}
				/>
			</Panel>,
		);
	} else if (pane === "Upgrades") {
		const rows = buildUpgradeRows(config, guild);
		const upgradeHeight = stack ? 180 : 140;
		add("upgrades-label", 34, <SectionLabel value="Hall upgrades" color={Palette.violet} />);
		add(
			"upgrades",
			rows.size() === 0 ? 72 : rows.size() * upgradeHeight + math.max(0, rows.size() - 1) * pageGap,
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, pageGap)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{rows.size() === 0 ? (
					<EmptyState
						key="empty-upgrades"
						title="Loading hall upgrades"
						body="They show up as soon as the hall sends them."
						icon="Forge.17"
						accent={Palette.violet}
						size={new UDim2(1, 0, 0, 72)}
						layoutOrder={1}
					/>
				) : (
					rows.map((row, i) => <UpgradeCard key={row.id} row={row} guild={guild} canBuy={canBuy} stack={stack} layoutOrder={i + 1} {...actions} />)
				)}
			</frame>,
		);
	} else {
		add(
			"role-policy",
			stack ? 176 : 120,
			<Panel size={UDim2.fromScale(1, 1)} padding={16} accent={Palette.cyan}>
				<Text value="ROLES & SUCCESSION" size={17} weight={Enum.FontWeight.Heavy} sizeConstraint={new UDim2(1, 0, 0, 24)} />
				<Text
					value="Leaders manage roles and the hall. Officers handle upgrades and members. Everyone can contribute and claim goal rewards. Leadership passes to an officer, then the earliest member."
					position={UDim2.fromOffset(0, 32)}
					size={13}
					color={Palette.creamSoft}
					wrap={true}
					fit={true}
					minSize={11}
					sizeConstraint={new UDim2(1, 0, 0, stack ? 110 : 52)}
				/>
			</Panel>,
		);
		const roleCounts: Record<string, number> = { All: 0, Leader: 0, Officer: 0, Member: 0 };
		const matching = members.filter((member) => Browse.matches(memberQuery, member.name, member.role, member.key));
		for (const member of matching) {
			roleCounts.All += 1;
			roleCounts[member.role] = (roleCounts[member.role] ?? 0) + 1;
		}
		// pin yourself above the role-sorted list so you never have to search for your own row
		const shown = [
			...matching.filter((member) => member.key === key && (memberRole === "All" || member.role === memberRole)),
			...matching.filter((member) => member.key !== key && (memberRole === "All" || member.role === memberRole)),
		];
		const goalContributors = guild.Goal?.Contributors;
		const groupLabel = (role: string) =>
			role === "You" ? "YOU" : role === "Leader" ? "LEADER" : role === "Officer" ? `OFFICERS · ${roleCounts.Officer}` : `MEMBERS · ${roleCounts.Member}`;
		const groupColor = (role: string) => (role === "You" ? Palette.green : role === "Leader" ? Palette.mango : role === "Officer" ? Palette.cyan : Palette.creamSoft);
		const memberGroups: StickyGroup[] = [];
		let rowsH = 0;
		let lastGroupRole = "";
		const memberRows = shown.map((member, i) => {
			const rowProps = {
				userKey: member.key,
				name: member.name,
				role: member.role,
				contributed: member.contributed,
				goalShare: goalContributors?.[member.key] ?? 0,
				share: totalContributed > 0 ? member.contributed / totalContributed : 0,
				isLocal: member.key === key,
				canManage: canBuy && member.key !== key,
				myRole,
				stack,
				layoutOrder: i + 1,
				onKick: () =>
					confirmThen(`Kick ${member.name}?`, "They can rejoin with the tag later.", "Kick", () => send("KickGuildMember", { UserId: tonumber(member.key) })),
				...actions,
			};
			const rowRole = member.key === key ? "You" : member.role;
			if (rowRole !== lastGroupRole) {
				lastGroupRole = rowRole;
				memberGroups.push({ top: rowsH + i * pageGap, label: groupLabel(rowRole), color: groupColor(rowRole) });
			}
			rowsH += memberRowLayout(rowProps).height;
			return <MemberRow key={member.key} {...rowProps} />;
		});
		const stickyGroups = memberGroups.size() > 1;
		const stickyPad = stickyGroups ? STICKY_H + 6 : 0;
		const memberBlockH = shown.size() === 0 ? 72 : stickyPad + rowsH + math.max(0, shown.size() - 1) * pageGap;
		const memberSearchH = stack ? TapTarget : 40;
		if (members.size() > 3) {
			add(
				"member-filter",
				memberSearchH + 8 + Browse.CHIP_H,
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
					<SearchField value={memberQuery} onChange={setMemberQuery} placeholder="Search members" accent={Palette.violet} reducedMotion={softMotion} size={new UDim2(1, 0, 0, memberSearchH)} zIndex={20} />
					<Browse.ChipRow
						options={[
							{ id: "All", label: "Everyone" },
							{ id: "Leader", label: "Leader" },
							{ id: "Officer", label: "Officers" },
							{ id: "Member", label: "Members" },
						]}
						value={memberRole}
						onChange={(id: string) => setMemberRole(id)}
						counts={roleCounts}
						accent={Palette.violet}
						position={UDim2.fromOffset(0, memberSearchH + 8)}
					/>
				</frame>,
			);
		}
		add(
			"members",
			memberBlockH,
			shown.size() === 0 ? (
				<EmptyState
					title={members.size() > 0 ? "No members match" : "Loading members"}
					body={members.size() > 0 ? "Clear the search or pick Everyone." : "The roster shows up in a moment."}
					icon="Pilot.2"
					accent={Palette.cyan}
					size={new UDim2(1, 0, 0, 72)}
				/>
			) : (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
					{stickyGroups && (
						<StickyGroupLabel groups={memberGroups.map((g) => ({ ...g, top: g.top + stickyPad }))} height={memberBlockH} reducedMotion={softMotion} listId="guild-members" />
					)}
					<frame Size={new UDim2(1, 0, 1, -stickyPad)} Position={UDim2.fromOffset(0, stickyPad)} BackgroundTransparency={1} BorderSizePixel={0}>
						<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, pageGap)} SortOrder={Enum.SortOrder.LayoutOrder} />
						{memberRows}
					</frame>
				</frame>
			),
		);
	}
	return <PageScaffold gap={12} tailPad={scrollTail(chrome.stack, chrome.bottomSafe, 80)} scrollBarColor={Palette.violet} scrollBarThickness={4} sections={sections} />;
}

export = { GuildView };

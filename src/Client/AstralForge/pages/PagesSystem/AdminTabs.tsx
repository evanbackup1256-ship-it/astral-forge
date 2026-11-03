// The Control Room's four working tabs besides the console: Show Room (screen effects), Live Ops (broadcasts,
// gifts, kits, flags), Telemetry (server pulse and security) and Audit (what staff ran, active bans).
import React from "@rbxts/react";
import { ADMIN_REASONS, Choice, fieldsFor, LETTERBOX_CAPTION_CHOICES } from "../../CoreKit/adminFields";
import { compactNumber } from "../../CoreKit/format";
import { Palette } from "../../CoreKit/theme";
import { useStagger } from "../../MotionKit/motion";
import { ShowPreview } from "../../UiCore/AdminShow";
import { kitMember, LuauComponent } from "../luauKits";
import { ago, BarRow, Chip, clockTime, headshot, SectionTitle, StatTile, uptimeText, useCountUp, HoldButton, Switch } from "./AdminParts";
import type { AdminContext, AuditRecord } from "./AdminRunner";

const { Button, Dropdown, EmptyState, Panel, SearchField, Text } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");

export const GAP = 14;

// ── layout helpers ─────────────────────────────────────────────────────────────

/** A vertical stack that sizes itself to what is in it. */
export function Col(props: { gap?: number; order?: number; children?: React.ReactNode }) {
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={props.order}>
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, props.gap ?? GAP)} />
			{props.children}
		</frame>
	);
}

/** Two columns when there is room (ratio is the left column's share), one stack when there is not. */
export function Split(props: { wide: boolean; ratio: number; order?: number; left: React.Element; right: React.Element }) {
	if (!props.wide) {
		return (
			<Col order={props.order}>
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
					{props.left}
				</frame>
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2}>
					{props.right}
				</frame>
			</Col>
		);
	}
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={props.order}>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, GAP)} />
			<frame Size={new UDim2(props.ratio, -GAP / 2, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
				{props.left}
			</frame>
			<frame Size={new UDim2(1 - props.ratio, -GAP / 2, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2}>
				{props.right}
			</frame>
		</frame>
	);
}

/** A caption above a control. `z` keeps an open dropdown above the fields under it. */
export function Field(props: { label: string; z: number; order: number; children: React.Element }) {
	return (
		<frame Size={new UDim2(1, 0, 0, 62)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={props.order} ZIndex={props.z}>
			<Text
				value={props.label}
				size={11}
				color={Palette.muted}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={11}
				sizeConstraint={new UDim2(1, 0, 0, 15)}
			/>
			<frame Size={new UDim2(1, 0, 0, 44)} Position={UDim2.fromOffset(0, 18)} BackgroundTransparency={1} ZIndex={props.z}>
				{props.children}
			</frame>
		</frame>
	);
}

function Line(props: { left: string; right?: string; accent?: Color3; rightColor?: Color3; order: number }) {
	return (
		<frame Size={new UDim2(1, 0, 0, 26)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={props.order} ClipsDescendants={true}>
			<Text
				value={props.left}
				size={12}
				color={props.accent ?? Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={11}
				sizeConstraint={new UDim2(0.55, -4, 1, 0)}
			/>
			<Text
				value={props.right ?? ""}
				size={12}
				color={props.rightColor ?? Palette.cyan}
				align={Enum.TextXAlignment.Right}
				fit={true}
				minSize={11}
				position={new UDim2(0.55, 4, 0, 0)}
				sizeConstraint={new UDim2(0.45, -4, 1, 0)}
			/>
		</frame>
	);
}

function PanelBox(props: { title: string; accent: Color3; order?: number; reducedMotion?: boolean; children?: React.ReactNode; gap?: number }) {
	return (
		<Panel size={new UDim2(1, 0, 0, 0)} autoHeight={true} accent={props.accent} background={Palette.panel} padding={16} layoutOrder={props.order} reducedMotion={props.reducedMotion}>
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, props.gap ?? 10)} />
			<SectionTitle value={props.title} accent={props.accent} layoutOrder={0} />
			{props.children}
		</Panel>
	);
}

function Note(props: { value: string; order: number; color?: Color3; height?: number }) {
	return (
		<Text
			value={props.value}
			size={12}
			color={props.color ?? Palette.muted}
			wrap={true}
			fit={true}
			minSize={11}
			sizeConstraint={new UDim2(1, 0, 0, props.height ?? 32)}
			layoutOrder={props.order}
		/>
	);
}

function TargetLine(props: { ctx: AdminContext; order: number; everyone?: boolean }) {
	const target = props.ctx.target;
	const text = props.everyone === true ? "Everyone in this server" : target !== undefined ? `${target.DisplayName}  ·  @${target.Name}` : "Pick a player on the Console tab";
	return (
		<frame Size={new UDim2(1, 0, 0, 30)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={props.order}>
			<Text value="TARGET" size={11} color={Palette.muted} weight={Enum.FontWeight.Heavy} fit={true} minSize={11} sizeConstraint={new UDim2(0, 56, 0, 30)} />
			{props.everyone !== true && target !== undefined && (
				<imagelabel Size={UDim2.fromOffset(24, 24)} Position={UDim2.fromOffset(60, 3)} BackgroundTransparency={1} Image={headshot(target.UserId)}>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</imagelabel>
			)}
			<Text
				value={text}
				size={13}
				color={props.everyone === true || target !== undefined ? Palette.cream : Palette.coral}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(props.everyone !== true && target !== undefined ? 92 : 60, 0)}
				sizeConstraint={new UDim2(1, props.everyone !== true && target !== undefined ? -92 : -60, 0, 30)}
			/>
		</frame>
	);
}

function reasonChoices(selected: string): Choice[] {
	return [...ADMIN_REASONS.filter((entry) => entry.id === selected), ...ADMIN_REASONS.filter((entry) => entry.id !== selected)];
}

// ── show room ──────────────────────────────────────────────────────────────────

interface ShowCard {
	id: string;
	title: string;
	blurb: string;
	accent: Color3;
}

const SHOW_CARDS: ShowCard[] = [
	{ id: "Fireworks", title: "Fireworks", blurb: "Colour bursts over the whole screen.", accent: Palette.mango },
	{ id: "Aurora", title: "Aurora", blurb: "Slow ribbons of light drifting across the top.", accent: Palette.mint },
	{ id: "Starfall", title: "Starfall", blurb: "Shooting stars streak down the sky.", accent: Palette.cyan },
	{ id: "MatrixRain", title: "Code rain", blurb: "Green glyphs fall behind everything.", accent: Palette.green },
	{ id: "Glitch", title: "Signal glitch", blurb: "The picture tears and flickers.", accent: Palette.pink },
	{ id: "Heartbeat", title: "Heartbeat", blurb: "The edges flush red in time with a pulse.", accent: Palette.coral },
	{ id: "Snowfall", title: "Snowfall", blurb: "Soft snow drifts down, no cold required.", accent: Palette.steel },
	{ id: "Letterbox", title: "Letterbox", blurb: "Cinematic bars slide in with a caption.", accent: Palette.brass },
];

const CARD_H = 244;
const PREVIEW_H = 104;

function EffectCard(props: {
	card: ShowCard;
	ctx: AdminContext;
	duration: string;
	reason: string;
	caption: string;
	onCaption: () => void;
	index: number;
}) {
	const { card, ctx } = props;
	const [hovered, setHovered] = React.useState(false);
	const [pinned, setPinned] = React.useState(false);
	const reveal = useStagger(props.index, ctx.reducedMotion);
	const busy = ctx.runner.busyId !== undefined;
	const live = hovered || pinned;
	const available = ctx.has(card.id);
	const everyone = ctx.has("ServerShow");
	return (
		<frame
			BackgroundColor3={Palette.panel}
			BackgroundTransparency={reveal.map((value) => 1 - math.clamp(value, 0, 1) * 0.94)}
			BorderSizePixel={0}
			LayoutOrder={props.index}
			Event={{ MouseEnter: () => setHovered(true), MouseLeave: () => setHovered(false) }}
		>
			<uicorner CornerRadius={new UDim(0, 14)} />
			<uistroke Color={card.accent} Thickness={1.2} Transparency={live ? 0.3 : 0.78} />
			<textbutton
				Size={new UDim2(1, -24, 0, PREVIEW_H)}
				Position={UDim2.fromOffset(12, 12)}
				BackgroundTransparency={1}
				Text=""
				AutoButtonColor={false}
				Active={true}
				Event={{ Activated: () => setPinned(!pinned) }}
			>
				<ShowPreview kind={card.id} live={live} />
				{!live && (
					<Text
						value="TAP OR HOVER TO PLAY"
						size={11}
						color={Palette.cream}
						weight={Enum.FontWeight.Heavy}
						align={Enum.TextXAlignment.Center}
						position={new UDim2(0, 0, 1, -22)}
						sizeConstraint={new UDim2(1, 0, 0, 16)}
						zIndex={5}
					/>
				)}
			</textbutton>
			<Text
				value={card.title}
				size={15}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(14, PREVIEW_H + 20)}
				sizeConstraint={new UDim2(1, card.id === "Letterbox" ? -170 : -28, 0, 20)}
			/>
			{card.id === "Letterbox" && (
				<frame Size={UDim2.fromOffset(168, 44)} Position={new UDim2(1, -180, 0, PREVIEW_H + 10)} BackgroundTransparency={1}>
					<Chip label={props.caption} selected={false} accent={card.accent} onClick={props.onCaption} />
				</frame>
			)}
			<Text
				value={card.blurb}
				size={12}
				color={Palette.muted}
				wrap={true}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(14, PREVIEW_H + 42)}
				sizeConstraint={new UDim2(1, -28, 0, 32)}
			/>
			<frame Size={new UDim2(1, -28, 0, 40)} Position={new UDim2(0, 14, 1, -52)} BackgroundTransparency={1}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 8)} />
				<Button
					text="ON TARGET"
					layoutOrder={1}
					size={new UDim2(0.5, -4, 1, 0)}
					color={Palette.panelSoft}
					textColor={Palette.cream}
					disabled={busy || !available || ctx.target === undefined}
					reducedMotion={ctx.reducedMotion}
					onClick={() =>
						ctx.runner.run({
							command: card.id,
							targetUserId: ctx.target!.UserId,
							amount: props.duration,
							option: card.id === "Letterbox" ? props.caption : "",
							reason: props.reason,
							dryRun: false,
						})
					}
				/>
				<HoldButton
					text="EVERYONE"
					layoutOrder={2}
					size={new UDim2(0.5, -4, 1, 0)}
					color={card.accent}
					disabled={busy || !everyone}
					busy={ctx.runner.busyId === "ServerShow"}
					reducedMotion={ctx.reducedMotion}
					onComplete={() =>
						ctx.runner.run({ command: "ServerShow", targetUserId: 0, amount: props.duration, option: card.id, reason: props.reason, dryRun: false })
					}
				/>
			</frame>
		</frame>
	);
}

export function ShowRoomTab(props: { ctx: AdminContext }) {
	const ctx = props.ctx;
	const [duration, setDuration] = React.useState("8");
	const [reason, setReason] = React.useState("Community event");
	const [captionIndex, setCaptionIndex] = React.useState(0);
	const durations: Choice[] = [{ id: "4", label: "4 seconds" }, { id: "8", label: "8 seconds" }, { id: "12", label: "12 seconds" }, { id: "20", label: "20 seconds" }];
	const columns = ctx.width >= 1000 ? 3 : ctx.width >= 640 ? 2 : 1;
	const caption = LETTERBOX_CAPTION_CHOICES[captionIndex % LETTERBOX_CAPTION_CHOICES.size()].id;
	const busy = ctx.runner.busyId !== undefined;
	return (
		<Col>
			<PanelBox title="SHOW ROOM" accent={Palette.brass} order={1} reducedMotion={ctx.reducedMotion}>
				<Note value="Play an effect on one player, or on every screen in this server. Hover a card to see it, or tap it on a touch screen." order={1} />
				<TargetLine ctx={ctx} order={2} />
				<frame Size={new UDim2(1, 0, 0, 62)} BackgroundTransparency={1} LayoutOrder={3} ZIndex={30}>
					<frame Size={new UDim2(0.5, -6, 1, 0)} BackgroundTransparency={1} ZIndex={32}>
						<Field label="HOW LONG" z={32} order={1}>
							<Dropdown options={durations} value={duration} onChange={setDuration} accent={Palette.brass} size={UDim2.fromScale(1, 1)} reducedMotion={ctx.reducedMotion} zIndex={80} />
						</Field>
					</frame>
					<frame Size={new UDim2(0.5, -6, 1, 0)} Position={new UDim2(0.5, 6, 0, 0)} BackgroundTransparency={1} ZIndex={31}>
						<Field label="LOGGED AS" z={31} order={1}>
							<Dropdown options={reasonChoices(reason)} value={reason} onChange={setReason} accent={Palette.steel} size={UDim2.fromScale(1, 1)} reducedMotion={ctx.reducedMotion} zIndex={70} />
						</Field>
					</frame>
				</frame>
				<frame Size={new UDim2(1, 0, 0, 44)} BackgroundTransparency={1} LayoutOrder={4}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 8)} />
					<Button
						text="CLEAR THEIR SCREEN"
						layoutOrder={1}
						size={new UDim2(0.5, -4, 1, 0)}
						color={Palette.panelSoft}
						textColor={Palette.cream}
						disabled={busy || !ctx.has("ClearEffects") || ctx.target === undefined}
						reducedMotion={ctx.reducedMotion}
						onClick={() =>
							ctx.runner.run({ command: "ClearEffects", targetUserId: ctx.target!.UserId, amount: "3", option: "", reason, dryRun: false })
						}
					/>
					<HoldButton
						text="CLEAR EVERYONE"
						layoutOrder={2}
						size={new UDim2(0.5, -4, 1, 0)}
						color={Palette.coral}
						disabled={busy || !ctx.has("ServerShow")}
						reducedMotion={ctx.reducedMotion}
						onComplete={() => ctx.runner.run({ command: "ServerShow", targetUserId: 0, amount: "3", option: "ClearEffects", reason, dryRun: false })}
					/>
				</frame>
			</PanelBox>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2}>
				<uigridlayout
					CellSize={new UDim2(1 / columns, -(GAP * (columns - 1)) / columns - 1, 0, CARD_H)}
					CellPadding={UDim2.fromOffset(GAP, GAP)}
					SortOrder={Enum.SortOrder.LayoutOrder}
					FillDirection={Enum.FillDirection.Horizontal}
				/>
				{SHOW_CARDS.map((card, index) => (
					<EffectCard
						key={card.id}
						card={card}
						ctx={ctx}
						duration={duration}
						reason={reason}
						caption={caption}
						onCaption={() => setCaptionIndex(captionIndex + 1)}
						index={index}
					/>
				))}
			</frame>
		</Col>
	);
}

// ── live ops ───────────────────────────────────────────────────────────────────

function OpsCard(props: { title: string; blurb: string; accent: Color3; ctx: AdminContext; children?: React.ReactNode; order: number }) {
	return (
		<PanelBox title={props.title} accent={props.accent} order={props.order} reducedMotion={props.ctx.reducedMotion}>
			<Note value={props.blurb} order={1} />
			{props.children}
		</PanelBox>
	);
}

function AnnounceCard(props: { ctx: AdminContext; order: number }) {
	const ctx = props.ctx;
	const [text, setText] = React.useState("");
	const clean = text.gsub("^%s*(.-)%s*$", "%1")[0];
	const ready = clean.size() >= 3;
	return (
		<OpsCard title="BROADCAST" blurb="A banner on every player's screen in every server. It passes Roblox's text filter before anyone sees it." accent={Palette.mango} ctx={ctx} order={props.order}>
			<frame Size={new UDim2(1, 0, 0, 44)} BackgroundTransparency={1} LayoutOrder={2}>
				<SearchField value={text} onChange={setText} debounce={0} accent={Palette.mango} placeholder="What do you want everyone to know?" size={UDim2.fromScale(1, 1)} reducedMotion={ctx.reducedMotion} />
			</frame>
			<Text
				value={`${clean.size()} / 140`}
				size={11}
				color={clean.size() > 140 ? Palette.coral : Palette.muted}
				align={Enum.TextXAlignment.Right}
				fit={true}
				minSize={11}
				sizeConstraint={new UDim2(1, 0, 0, 15)}
				layoutOrder={3}
			/>
			<HoldButton
				text="HOLD TO BROADCAST"
				layoutOrder={4}
				size={new UDim2(1, 0, 0, 46)}
				color={Palette.mango}
				disabled={!ready || clean.size() > 140 || ctx.runner.busyId !== undefined || !ctx.has("Announce")}
				busy={ctx.runner.busyId === "Announce"}
				reducedMotion={ctx.reducedMotion}
				onComplete={() =>
					ctx.runner.run({ command: "Announce", targetUserId: 0, amount: "1", option: clean, reason: "Staff announcement", dryRun: false }, (outcome) => {
						if (outcome.ok) setText("");
					})
				}
			/>
		</OpsCard>
	);
}

function GiftCard(props: { ctx: AdminContext; order: number }) {
	const ctx = props.ctx;
	const fields = fieldsFor("ServerGift");
	const [amount, setAmount] = React.useState(fields.defaultAmount);
	const [currency, setCurrency] = React.useState(fields.defaultOption);
	return (
		<OpsCard title="GIFT THE SERVER" blurb="Everyone playing here receives the same gift and sees a toast about it." accent={Palette.mint} ctx={ctx} order={props.order}>
			<Field label="WHAT" z={40} order={2}>
				<Dropdown options={fields.optionChoices} value={currency} onChange={setCurrency} accent={Palette.mint} size={UDim2.fromScale(1, 1)} reducedMotion={ctx.reducedMotion} zIndex={90} />
			</Field>
			<Field label="HOW MUCH EACH" z={39} order={3}>
				<Dropdown options={fields.amountChoices} value={amount} onChange={setAmount} accent={Palette.mint} size={UDim2.fromScale(1, 1)} reducedMotion={ctx.reducedMotion} zIndex={80} />
			</Field>
			<HoldButton
				text="HOLD TO GIFT"
				layoutOrder={4}
				size={new UDim2(1, 0, 0, 46)}
				color={Palette.mint}
				disabled={ctx.runner.busyId !== undefined || !ctx.has("ServerGift")}
				busy={ctx.runner.busyId === "ServerGift"}
				reducedMotion={ctx.reducedMotion}
				onComplete={() => ctx.runner.run({ command: "ServerGift", targetUserId: 0, amount, option: currency, reason: "Community event", dryRun: false })}
			/>
		</OpsCard>
	);
}

function TargetedCard(props: {
	ctx: AdminContext;
	order: number;
	command: string;
	title: string;
	blurb: string;
	accent: Color3;
	holdText: string;
	reason: string;
	needsAmount?: boolean;
}) {
	const ctx = props.ctx;
	const fields = fieldsFor(props.command);
	const [amount, setAmount] = React.useState(fields.defaultAmount);
	const [option, setOption] = React.useState(fields.defaultOption);
	return (
		<OpsCard title={props.title} blurb={props.blurb} accent={props.accent} ctx={ctx} order={props.order}>
			<TargetLine ctx={ctx} order={2} />
			{fields.usesOption && (
				<Field label={string.upper(fields.optionLabel)} z={40} order={3}>
					<Dropdown options={fields.optionChoices} value={option} onChange={setOption} accent={props.accent} size={UDim2.fromScale(1, 1)} reducedMotion={ctx.reducedMotion} zIndex={90} />
				</Field>
			)}
			{fields.usesAmount && (
				<Field label={string.upper(fields.amountLabel)} z={39} order={4}>
					<Dropdown options={fields.amountChoices} value={amount} onChange={setAmount} accent={props.accent} size={UDim2.fromScale(1, 1)} reducedMotion={ctx.reducedMotion} zIndex={80} />
				</Field>
			)}
			<HoldButton
				text={props.holdText}
				layoutOrder={5}
				size={new UDim2(1, 0, 0, 46)}
				color={props.accent}
				disabled={ctx.runner.busyId !== undefined || !ctx.has(props.command) || ctx.target === undefined}
				busy={ctx.runner.busyId === props.command}
				reducedMotion={ctx.reducedMotion}
				onComplete={() =>
					ctx.runner.run({ command: props.command, targetUserId: ctx.target!.UserId, amount, option, reason: props.reason, dryRun: false })
				}
			/>
		</OpsCard>
	);
}

function WhisperCard(props: { ctx: AdminContext; order: number }) {
	const ctx = props.ctx;
	const [text, setText] = React.useState("");
	const clean = text.gsub("^%s*(.-)%s*$", "%1")[0];
	const ready = clean.size() >= 2 && clean.size() <= 64;
	return (
		<OpsCard title="WHISPER" blurb="A private note that appears only for this player, with the team's name on it." accent={Palette.cyan} ctx={ctx} order={props.order}>
			<TargetLine ctx={ctx} order={2} />
			<frame Size={new UDim2(1, 0, 0, 44)} BackgroundTransparency={1} LayoutOrder={3}>
				<SearchField value={text} onChange={setText} debounce={0} accent={Palette.cyan} placeholder="A short note" size={UDim2.fromScale(1, 1)} reducedMotion={ctx.reducedMotion} />
			</frame>
			<Text
				value={`${clean.size()} / 64`}
				size={11}
				color={clean.size() > 64 ? Palette.coral : Palette.muted}
				align={Enum.TextXAlignment.Right}
				fit={true}
				minSize={11}
				sizeConstraint={new UDim2(1, 0, 0, 15)}
				layoutOrder={4}
			/>
			<Button
				text="SEND WHISPER"
				layoutOrder={5}
				size={new UDim2(1, 0, 0, 46)}
				color={Palette.cyan}
				textColor={Palette.ink}
				disabled={!ready || ctx.target === undefined || ctx.runner.busyId !== undefined || !ctx.has("Whisper")}
				loading={ctx.runner.busyId === "Whisper"}
				reducedMotion={ctx.reducedMotion}
				onClick={() =>
					ctx.runner.run({ command: "Whisper", targetUserId: ctx.target!.UserId, amount: "1", option: clean, reason: "Player request", dryRun: false }, (outcome) => {
						if (outcome.ok) setText("");
					})
				}
			/>
		</OpsCard>
	);
}

function FlagsCard(props: { ctx: AdminContext; order: number }) {
	const ctx = props.ctx;
	const flags = ctx.admin.HotFlags ?? [];
	const [pending, setPending] = React.useState<Record<string, boolean>>({});
	// a flag the server has caught up on no longer needs the optimistic value
	React.useEffect(() => {
		let changed = false;
		const remaining: Record<string, boolean> = {};
		for (const [name, wanted] of pairs(pending)) {
			const row = flags.find((flag) => flag.Name === name);
			if (row !== undefined && row.On === wanted) {
				changed = true;
			} else {
				remaining[name] = wanted;
			}
		}
		if (changed) setPending(remaining);
	}, [ctx.admin.HotFlags]);
	return (
		<PanelBox title="LIVE FLAGS" accent={Palette.coral} order={props.order} reducedMotion={ctx.reducedMotion}>
			<Note value="Switches that change behaviour in every server at once. Each flip is logged." order={1} />
			{flags.size() === 0 && <Note value="No flags are defined." order={2} />}
			{flags.map((flag, index) => {
				const on = pending[flag.Name] ?? flag.On;
				return (
					<frame key={flag.Name} Size={new UDim2(1, 0, 0, 52)} BackgroundTransparency={1} LayoutOrder={10 + index}>
						<Text
							value={flag.Name}
							size={13}
							color={on ? Palette.coral : Palette.cream}
							weight={Enum.FontWeight.Heavy}
							fit={true}
							minSize={11}
							position={UDim2.fromOffset(0, 5)}
							sizeConstraint={new UDim2(1, -64, 0, 18)}
						/>
						<Text
							value={flag.Description}
							size={11}
							color={Palette.muted}
							fit={true}
							minSize={11}
							position={UDim2.fromOffset(0, 26)}
							sizeConstraint={new UDim2(1, -64, 0, 16)}
						/>
						<frame Size={UDim2.fromOffset(54, 44)} Position={new UDim2(1, -54, 0.5, -22)} BackgroundTransparency={1}>
							<Switch
								on={on}
								accent={Palette.coral}
								disabled={ctx.runner.busyId !== undefined || !ctx.has("ToggleHotFlag")}
								reducedMotion={ctx.reducedMotion}
								onChange={(turnOn) => {
									setPending({ ...pending, [flag.Name]: turnOn });
									ctx.runner.run(
										{ command: "ToggleHotFlag", targetUserId: 0, amount: "1", option: `${flag.Name}=${turnOn ? "on" : "off"}`, reason: "Community event", dryRun: false },
										(outcome) => {
											if (!outcome.ok) {
												const revert = { ...pending };
												delete revert[flag.Name];
												setPending(revert);
											}
										},
									);
								}}
							/>
						</frame>
					</frame>
				);
			})}
		</PanelBox>
	);
}

function AnnouncementsCard(props: { ctx: AdminContext; order: number }) {
	const items = props.ctx.admin.Announcements ?? [];
	return (
		<PanelBox title="RECENT BROADCASTS" accent={Palette.violet} order={props.order} reducedMotion={props.ctx.reducedMotion}>
			{items.size() === 0 && <Note value="Nothing has been broadcast on this server yet." order={1} />}
			{items.map((item, index) => (
				<Line key={`${item.At}${index}`} order={index + 1} left={item.Text} right={`${item.From}  ·  ${clockTime(item.At)}`} rightColor={Palette.muted} />
			))}
		</PanelBox>
	);
}

export function LiveOpsTab(props: { ctx: AdminContext }) {
	const ctx = props.ctx;
	const show = (id: string) => ctx.has(id);
	const left: React.Element[] = [];
	const right: React.Element[] = [];
	if (show("Announce")) left.push(<AnnounceCard key="announce" ctx={ctx} order={left.size() + 1} />);
	if (show("ServerGift")) left.push(<GiftCard key="gift" ctx={ctx} order={left.size() + 1} />);
	if (show("ApplyKit")) {
		left.push(
			<TargetedCard key="kit" ctx={ctx} order={left.size() + 1} command="ApplyKit" title="LOADOUT KIT" blurb="Hand one player a ready-made bundle of currencies, keys and boosts." accent={Palette.violet} holdText="HOLD TO APPLY KIT" reason="Playtest grant" />,
		);
	}
	if (show("Spotlight")) {
		right.push(
			<TargetedCard key="spot" ctx={ctx} order={right.size() + 1} command="Spotlight" title="SPOTLIGHT" blurb="Names one player to the whole server with a title, fireworks for everyone and an aurora for them." accent={Palette.brass} holdText="HOLD TO SHINE A LIGHT" reason="Staff showcase" />,
		);
	}
	if (show("FastForward")) {
		right.push(
			<TargetedCard key="ff" ctx={ctx} order={right.size() + 1} command="FastForward" title="FAST-FORWARD" blurb="Credits hours of the player's current production in one go." accent={Palette.cyan} holdText="HOLD TO FAST-FORWARD" reason="Playtest grant" />,
		);
	}
	if (show("Whisper")) right.push(<WhisperCard key="whisper" ctx={ctx} order={right.size() + 1} />);
	return (
		<Col>
			<Split wide={ctx.wide} ratio={0.5} order={1} left={<Col>{left}</Col>} right={<Col>{right}</Col>} />
			<FlagsCard ctx={ctx} order={2} />
			<AnnouncementsCard ctx={ctx} order={3} />
		</Col>
	);
}

// ── telemetry ──────────────────────────────────────────────────────────────────

function levelColor(level?: string): Color3 {
	if (level === "kick") return Palette.coral;
	if (level === "throttle") return Palette.mango;
	return Palette.muted;
}

export function TelemetryTab(props: { ctx: AdminContext }) {
	const ctx = props.ctx;
	const admin = ctx.admin;
	const telemetry = admin.Telemetry ?? {};
	const economy = admin.Economy ?? {};
	const performance = telemetry.ClientPerformance ?? {};
	const reduced = ctx.reducedMotion;
	const online = useCountUp(ctx.online.size(), reduced);
	const accepted = useCountUp(telemetry.RemoteAccepted ?? 0, reduced);
	const rejected = telemetry.RemoteRejected ?? 0;
	const rate = telemetry.RemoteRejectRate ?? 0;
	const columns = ctx.width >= 820 ? 4 : ctx.width >= 520 ? 3 : 2;
	const fps = performance.AverageFPS ?? 0;
	const tiles: Array<{ label: string; value: string; sub?: string; accent: Color3 }> = [
		{ label: "PLAYERS HERE", value: tostring(math.floor(online + 0.5)), sub: `${telemetry.SessionsStarted ?? 0} joined since start`, accent: Palette.mint },
		{ label: "UPTIME", value: uptimeText(telemetry.UptimeSeconds ?? 0), sub: "this server", accent: Palette.cyan },
		{ label: "REQUESTS OK", value: compactNumber(math.floor(accepted + 0.5)), sub: `${rejected} refused  ·  ${math.floor(rate * 1000) / 10}%`, accent: rate > 0.05 ? Palette.mango : Palette.mint },
		{ label: "CLIENT FPS", value: performance.Samples !== undefined && performance.Samples > 0 ? tostring(math.floor(fps + 0.5)) : "--", sub: `ping ${math.floor(performance.AveragePingMs ?? 0)} ms  ·  p95 ${math.floor(performance.AverageP95Ms ?? 0)} ms`, accent: fps > 0 && fps < 30 ? Palette.coral : Palette.violet },
		{ label: "TOTAL FLUX", value: compactNumber(economy.TotalCash ?? 0), sub: `richest ${compactNumber(economy.RichestCash ?? 0)}`, accent: Palette.cyan },
		{ label: "MEDIAN RATE", value: `${compactNumber(economy.MedianProduction ?? 0)}/s`, sub: `median rebirths ${compactNumber(economy.MedianRebirths ?? 0)}`, accent: Palette.mint },
		{ label: "STARDUST", value: compactNumber(economy.TotalStardust ?? 0), sub: "all profiles here", accent: Palette.mango },
		{ label: "CORES", value: compactNumber(economy.TotalCores ?? 0), sub: `${telemetry.IntegrityReports ?? 0} integrity reports`, accent: Palette.pink },
	];
	const timings = [...(telemetry.Timings ?? [])].sort((left, right) => left.AverageMs > right.AverageMs);
	const slowest = timings.size() > 0 ? timings[0].AverageMs : 1;
	const rejections = telemetry.TopRejections ?? [];
	const mostRejected = rejections.size() > 0 ? rejections[0].Count : 1;
	const actions = economy.TopActions ?? [];
	const mostActed = actions.size() > 0 ? actions[0].Count : 1;
	const flagged = admin.SecurityPlayers ?? [];
	const recentFlags = admin.SecurityFlags ?? [];
	const securityRows: React.Element[] = [];
	for (let i = 0; i < math.min(6, flagged.size()); i++) {
		const row = flagged[i];
		securityRows.push(<Line key={`p${row.UserId}`} order={i + 1} left={`${row.Name}  ·  ${row.Score}`} right={`${row.Flags}x ${row.LastKind}`} rightColor={levelColor(row.Level)} />);
	}
	for (let i = 0; i < math.min(5, recentFlags.size()); i++) {
		const flag = recentFlags[i];
		securityRows.push(
			<Line key={`f${i}`} order={20 + i} left={`${flag.Kind}  ·  ${flag.Name}`} right={`${clockTime(flag.At)}  ${flag.Response ?? ""}`} accent={Palette.coral} rightColor={Palette.muted} />,
		);
	}
	const repaired = (admin.AntiCheatRules ?? []).filter((rule) => rule.Repairs > 0);
	for (let i = 0; i < math.min(4, repaired.size()); i++) {
		securityRows.push(<Line key={`r${repaired[i].Id}`} order={40 + i} left={`rule ${repaired[i].Id}`} right={`${compactNumber(repaired[i].Repairs)} saves repaired`} accent={Palette.steel} rightColor={Palette.muted} />);
	}
	return (
		<Col>
			<PanelBox title="SERVER PULSE" accent={Palette.cyan} order={1} reducedMotion={reduced}>
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
					<uigridlayout
						CellSize={new UDim2(1 / columns, -(GAP * (columns - 1)) / columns - 1, 0, 76)}
						CellPadding={UDim2.fromOffset(GAP, GAP)}
						SortOrder={Enum.SortOrder.LayoutOrder}
						FillDirection={Enum.FillDirection.Horizontal}
					/>
					{tiles.map((tile, index) => (
						<StatTile key={tile.label} label={tile.label} value={tile.value} sub={tile.sub} accent={tile.accent} layoutOrder={index + 1} index={index} reducedMotion={reduced} />
					))}
				</frame>
			</PanelBox>
			<Split
				wide={ctx.wide}
				ratio={0.5}
				order={2}
				left={
					<Col>
						<PanelBox title="SLOWEST REQUESTS" accent={Palette.violet} order={1} reducedMotion={reduced}>
							{timings.size() === 0 && <Note value="No requests have been timed yet." order={1} />}
							{timings.map((timing, index) =>
								index < 6 ? (
									<BarRow key={timing.Name} label={timing.Name} value={`${math.floor(timing.AverageMs * 10) / 10} ms`} share={timing.AverageMs / math.max(1, slowest)} accent={Palette.violet} layoutOrder={index + 1} reducedMotion={reduced} />
								) : undefined,
							)}
						</PanelBox>
					</Col>
				}
				right={
					<Col>
						<PanelBox title="WHY REQUESTS WERE REFUSED" accent={Palette.coral} order={1} reducedMotion={reduced}>
							{rejections.size() === 0 && <Note value="Nothing has been refused." order={1} />}
							{rejections.map((entry, index) => (
								<BarRow key={entry.Reason} label={entry.Reason} value={tostring(entry.Count)} share={entry.Count / math.max(1, mostRejected)} accent={Palette.coral} layoutOrder={index + 1} reducedMotion={reduced} />
							))}
						</PanelBox>
					</Col>
				}
			/>
			<Split
				wide={ctx.wide}
				ratio={0.5}
				order={3}
				left={
					<Col>
						<PanelBox title="MOST USED ACTIONS" accent={Palette.mint} order={1} reducedMotion={reduced}>
							{actions.size() === 0 && <Note value="No actions recorded yet." order={1} />}
							{actions.map((entry, index) => (
								<BarRow key={entry.Action} label={entry.Action} value={compactNumber(entry.Count)} share={entry.Count / math.max(1, mostActed)} accent={Palette.mint} layoutOrder={index + 1} reducedMotion={reduced} />
							))}
						</PanelBox>
					</Col>
				}
				right={
					<Col>
						<PanelBox title="SECURITY" accent={Palette.coral} order={1} reducedMotion={reduced} gap={4}>
							{securityRows.size() === 0 && <Note value="No flagged players, no repaired saves." order={1} />}
							{securityRows}
						</PanelBox>
					</Col>
				}
			/>
		</Col>
	);
}

// ── audit ──────────────────────────────────────────────────────────────────────

function AuditEntry(props: { record: AuditRecord; index: number; last: boolean; reducedMotion: boolean }) {
	const { record } = props;
	const reveal = useStagger(props.index, props.reducedMotion, 0.04);
	const detail: string[] = [];
	if (record.Option !== undefined && record.Option !== "") detail.push(record.Option);
	if (record.Amount !== undefined && record.Amount !== 0) detail.push(compactNumber(record.Amount));
	if (record.Reason !== undefined && record.Reason !== "") detail.push(record.Reason);
	return (
		<frame Size={new UDim2(1, 0, 0, 70)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={props.index + 1}>
			<frame Size={new UDim2(0, 2, 1, props.last ? -34 : 0)} Position={UDim2.fromOffset(6, 0)} BackgroundColor3={Palette.line} BackgroundTransparency={0.4} BorderSizePixel={0} />
			<frame
				Size={UDim2.fromOffset(14, 14)}
				Position={UDim2.fromOffset(0, 10)}
				BackgroundColor3={Palette.coral}
				BackgroundTransparency={reveal.map((value) => 1 - math.clamp(value, 0, 1))}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke Color={Palette.ink} Thickness={3} />
			</frame>
			<Text
				value={record.Command}
				size={14}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(28, 6)}
				sizeConstraint={new UDim2(1, -120, 0, 20)}
				transparency={reveal.map((value) => 1 - math.clamp(value, 0, 1))}
			/>
			<Text
				value={`${clockTime(record.At)}  ·  ${ago(record.At)}`}
				size={11}
				color={Palette.muted}
				align={Enum.TextXAlignment.Right}
				fit={true}
				minSize={11}
				position={new UDim2(1, -92, 0, 8)}
				sizeConstraint={new UDim2(0, 92, 0, 16)}
			/>
			<Text
				value={`${record.ActorName}  →  ${record.TargetName}`}
				size={12}
				color={Palette.cyan}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(28, 27)}
				sizeConstraint={new UDim2(1, -28, 0, 17)}
			/>
			<Text
				value={detail.join("  ·  ")}
				size={11}
				color={Palette.muted}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(28, 46)}
				sizeConstraint={new UDim2(1, -28, 0, 16)}
			/>
		</frame>
	);
}

export function AuditTab(props: { ctx: AdminContext }) {
	const ctx = props.ctx;
	const recent = ctx.admin.Recent ?? [];
	const banned = ctx.admin.Banned ?? [];
	return (
		<Split
			wide={ctx.wide}
			ratio={0.6}
			left={
				<PanelBox title="AUDIT LOG" accent={Palette.coral} reducedMotion={ctx.reducedMotion} gap={0}>
					{recent.size() === 0 ? (
						<frame Size={new UDim2(1, 0, 0, 150)} BackgroundTransparency={1} LayoutOrder={1}>
							<EmptyState icon="Command" title="No commands run yet" body="Anything staff run shows up here, newest first." compact={true} />
						</frame>
					) : (
						recent.map((record, index) => <AuditEntry key={record.Id} record={record} index={index} last={index === recent.size() - 1} reducedMotion={ctx.reducedMotion} />)
					)}
				</PanelBox>
			}
			right={
				<PanelBox title="ACTIVE BANS" accent={Palette.mango} reducedMotion={ctx.reducedMotion}>
					{banned.size() === 0 && <Note value="Nobody is banned right now." order={1} />}
					{banned.map((entry, index) => (
						<frame key={tostring(entry.UserId)} Size={new UDim2(1, 0, 0, 52)} BackgroundTransparency={1} LayoutOrder={index + 2}>
							<Text value={entry.Name} size={13} color={Palette.cream} weight={Enum.FontWeight.Heavy} fit={true} minSize={11} position={UDim2.fromOffset(0, 5)} sizeConstraint={new UDim2(1, -130, 0, 18)} />
							<Text
								value={`${entry.Scope}  ·  ${entry.Until < 0 ? "permanent" : entry.Until === 0 ? "this server" : `until ${os.date("%b %d %H:%M", entry.Until)}`}`}
								size={11}
								color={Palette.muted}
								fit={true}
								minSize={11}
								position={UDim2.fromOffset(0, 26)}
								sizeConstraint={new UDim2(1, -130, 0, 16)}
							/>
							<HoldButton
								text="UNBAN"
								size={UDim2.fromOffset(120, 36)}
								position={new UDim2(1, -120, 0.5, -18)}
								color={Palette.mango}
								disabled={ctx.runner.busyId !== undefined || !ctx.has("Unban")}
								busy={ctx.runner.busyId === "Unban"}
								reducedMotion={ctx.reducedMotion}
								onComplete={() =>
									ctx.runner.run({ command: "Unban", targetUserId: entry.UserId, amount: tostring(entry.UserId), option: "", reason: "Moderation action", dryRun: false })
								}
							/>
						</frame>
					))}
				</PanelBox>
			}
		/>
	);
}

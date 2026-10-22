// Forge Path, rebuilt on Forge2: XP banked, the path's progress, the next step in the spotlight
// with its claim, then every step on the track (search + upcoming / claimed). Each step is its
// own colour; claimed steps dim. Remote unchanged: ClaimForgePathStep {Step}.
import React from "@rbxts/react";
import { Audio } from "../../AudioKit/audio";
import { compactNumber, formatReward, Reward } from "../../CoreKit/format";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { DecoratedForgePathStep, decorateForgePathSteps, ForgePathStep } from "../../CoreKit/types";
import { useChangePop, useFlash, useListStagger, useStagger } from "../../MotionKit/motion";
import { PressButton as Button } from "../design/PressButton";
import { EmptyState } from "../design/Layers";
import { Card, Meter, Panel } from "../design/Panel";
import { Chip } from "../design/Pick";
import { Text, Title } from "../design/Text";
import { Corner, Fonts, gap, HIT, Iron, Type } from "../design/tokens";
import { Burst, MotionFX } from "../motion/motion";
import type { PageProps } from "../router/routes";

const UserInputService = game.GetService("UserInputService");
const PAGE_SIZE = 30;

interface Guide {
	Complete?: string;
	NeedXp?: string;
	HeroBlurb?: string;
}

const NOUNS: Record<string, string> = {
	Production: "production",
	TapPower: "tap power",
	Capacity: "vault capacity",
	CriticalChance: "critical chance",
	AutoCollect: "auto-collect rate",
	Offline: "offline income",
	CriticalMultiplier: "critical multiplier",
	RebirthMultiplier: "rebirth multiplier",
};

function effect(step: DecoratedForgePathStep): string {
	const noun = step.Noun !== undefined && step.Noun !== "" ? step.Noun : (NOUNS[step.EffectKind] ?? step.EffectKind);
	return `+${step.EffectAmount}% ${noun}`;
}

function rewardBits(reward: Reward | undefined): string[] {
	const bits: string[] = [];
	if ((reward?.Cash ?? 0) > 0) bits.push(`${compactNumber(reward!.Cash)} flux`);
	if ((reward?.Stardust ?? 0) > 0) bits.push(`${compactNumber(reward!.Stardust)} dust`);
	if ((reward?.Cores ?? 0) > 0) bits.push(`${compactNumber(reward!.Cores)} cores`);
	if ((reward?.Essence ?? 0) > 0) bits.push(`${compactNumber(reward!.Essence)} essence`);
	if (reward?.Boost !== undefined) bits.push(tostring(reward.Boost));
	return bits;
}

function Pills(props: { bits: string[]; color: Color3; phone: boolean; order: number }) {
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.order}>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 6)} SortOrder={Enum.SortOrder.LayoutOrder} />
			{props.bits.map((bit, i) => (
				<frame key={`b${i}`} Size={UDim2.fromOffset(0, 24)} AutomaticSize={Enum.AutomaticSize.X} BackgroundColor3={props.color.Lerp(Iron.sunk(), 0.7)} BorderSizePixel={0} LayoutOrder={i}>
					<uicorner CornerRadius={new UDim(0, Corner.chip)} />
					<uipadding PaddingLeft={new UDim(0, 8)} PaddingRight={new UDim(0, 8)} />
					<textlabel Size={UDim2.fromOffset(0, 24)} AutomaticSize={Enum.AutomaticSize.X} BackgroundTransparency={1} Text={bit} FontFace={Fonts.bold} TextSize={Type.small(props.phone)} TextColor3={Iron.text()} />
				</frame>
			))}
		</frame>
	);
}

function StepCard(props: { step: DecoratedForgePathStep; claimed: boolean; open: boolean; xp: number; index: number; phone: boolean; onClaim: (step: DecoratedForgePathStep) => void }) {
	const { step, claimed, phone } = props;
	const ready = !claimed && props.open && props.xp >= step.XPCost;
	const locked = !claimed && !props.open;
	const rise = useListStagger(props.index);
	const color = claimed ? Iron.muted() : step.Color;
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.index}>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} Position={rise.map((p) => UDim2.fromOffset((1 - p) * 18, 0))}>
				<Card accent={color} pad={gap(phone, "l")} spacing={gap(phone, "s")} seam={ready} color={claimed ? Iron.sunk() : undefined}>
					<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0}>
						<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, gap(phone, "m"))} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
						<Text text={tostring(step.Step)} size={phone ? 24 : 30} font={Fonts.heavy} color={color} box={UDim2.fromOffset(phone ? 40 : 52, phone ? 30 : 36)} order={0} />
						<frame Size={new UDim2(1, -(phone ? 40 : 52) - gap(phone, "m") - (phone ? 0 : 160), 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
							<uilistlayout Padding={new UDim(0, 4)} SortOrder={Enum.SortOrder.LayoutOrder} />
							<Text text={effect(step)} size={Type.body(phone)} font={Fonts.heavy} color={claimed ? Iron.muted() : Iron.text()} order={0} />
							<Pills bits={rewardBits(step.Reward as Reward | undefined)} color={color} phone={phone} order={1} />
						</frame>
						{!phone && (
							<frame Size={UDim2.fromOffset(150, HIT)} BackgroundTransparency={1} LayoutOrder={2}>
								{claimed ? (
									<Text text="✓" size={22} font={Fonts.heavy} color={Iron.muted()} align="Right" box={UDim2.fromScale(1, 1)} />
								) : (
									<Button text={ready ? "Claim" : locked ? "Locked" : compactNumber(step.XPCost)} onPress={() => props.onClaim(step)} disabled={!ready} tone={ready ? "brass" : "quiet"} stretch />
								)}
							</frame>
						)}
					</frame>
					{!claimed && <Meter value={props.xp / math.max(1, step.XPCost)} color={ready ? step.Color : Iron.steel()} height={6} order={1} />}
					{phone && !claimed && (
						<Button text={ready ? "Claim" : locked ? "Locked" : `${compactNumber(step.XPCost)} XP`} onPress={() => props.onClaim(step)} disabled={!ready} tone={ready ? "brass" : "quiet"} stretch order={2} />
					)}
				</Card>
			</frame>
		</frame>
	);
}

export function ForgePathPage(props: PageProps) {
	const phone = props.phone;
	const config = props.config as { ForgePath?: { Steps?: ForgePathStep[] }; ClientPageGuides?: { ForgePath?: Guide } };
	const guide = config.ClientPageGuides?.ForgePath;
	const path = (props.session as unknown as { ForgePath?: { ClaimedSteps?: number[]; XP?: number } }).ForgePath;
	const xp = path?.XP ?? 0;
	const claimedList = path?.ClaimedSteps ?? [];
	const steps = React.useMemo(() => decorateForgePathSteps(config.ForgePath?.Steps), [config.ForgePath?.Steps]);
	const claimed = new Set<number>();
	for (const id of claimedList) claimed.add(id);
	const isOpen = (step: DecoratedForgePathStep) => step.Step === 1 || claimed.has(step.Step - 1);
	const spotlight = steps.find((step) => !claimed.has(step.Step) && isOpen(step));
	const spotReady = spotlight !== undefined && xp >= spotlight.XPCost;
	const complete = steps.size() > 0 && claimedList.size() >= steps.size();

	const [filter, setFilter] = React.useState("All");
	const [query, setQuery] = React.useState("");
	const [shown, setShown] = React.useState(PAGE_SIZE);
	const [claims, setClaims] = React.useState(0);
	const flash = useFlash(claims, false, 0.45);
	const heroIn = useStagger(0);
	const spotIn = useStagger(1);
	const xpText = compactNumber(xp);
	const xpPop = useChangePop(xpText, false, 0.1);

	const focusRef = React.useRef<Frame>();
	React.useEffect(() => {
		if (!spotReady || complete || !UserInputService.GamepadEnabled) return undefined;
		const job = task.defer(() => {
			const host = focusRef.current;
			if (host !== undefined && host.Parent !== undefined) GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [spotReady, complete, spotlight?.Step ?? 0]);

	const claim = (step: DecoratedForgePathStep) => {
		setClaims((n) => n + 1);
		Burst.gain(effect(step), step.Color, step.Icon);
		Audio.play("unlock");
		props.request("ClaimForgePathStep", { Step: step.Step }, (reply) => reply.ok === true && MotionFX.play("milestone"));
	};

	const q = query.lower();
	const searching = q.match("^%s*$")[0] === undefined;
	const visible = steps.filter((step) => {
		if (filter === "Upcoming" && claimed.has(step.Step)) return false;
		if (filter === "Claimed" && !claimed.has(step.Step)) return false;
		if (!searching) return true;
		for (const field of [effect(step), formatReward(step.Reward as Reward | undefined), `step ${step.Step}`, step.EffectKind]) {
			if (field.lower().find(q, 1, true)[0] !== undefined) return true;
		}
		return false;
	});

	const space = gap(phone, "l");
	return (
		<scrollingframe
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			CanvasSize={new UDim2()}
			AutomaticCanvasSize={Enum.AutomaticSize.Y}
			ScrollBarThickness={phone ? 0 : 4}
			ScrollBarImageColor3={Iron.brassDeep()}
		>
			<uipadding PaddingTop={new UDim(0, space)} PaddingBottom={new UDim(0, space * 3)} PaddingLeft={new UDim(0, space)} PaddingRight={new UDim(0, space)} />
			<uilistlayout Padding={new UDim(0, space)} SortOrder={Enum.SortOrder.LayoutOrder} />

			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0} Position={heroIn.map((p) => UDim2.fromOffset(0, (1 - p) * 16))}>
				<Panel pad={gap(phone, "xl")} spacing={gap(phone, "m")} seam rarity="Mythic">
					<Title text="Forge Path" size={Type.title(phone)} tags={["wave"]} order={0} />
					<frame Size={new UDim2(1, 0, 0, Type.hero(phone) + 8)} BackgroundTransparency={1} LayoutOrder={1}>
						<uiscale Scale={xpPop} />
						<Text text={`${xpText} XP`} size={Type.hero(phone)} font={Fonts.heavy} color={Iron.brass()} box={UDim2.fromScale(1, 1)} />
					</frame>
					<Meter value={steps.size() > 0 ? claimedList.size() / steps.size() : 0} order={2} />
					<Text text={`${claimedList.size()} / ${steps.size()}  ·  ${guide?.HeroBlurb ?? "One track. Every step pays out."}`} size={Type.small(phone)} color={Iron.muted()} multiline order={3} />
				</Panel>
			</frame>

			{complete ? (
				<EmptyState title="Path complete" body={guide?.Complete ?? "Every bonus stays through rebirth."} phone={phone} order={1} />
			) : spotlight === undefined ? (
				<EmptyState title="Not ready yet" body="Check back in a moment." phone={phone} order={1} />
			) : (
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1} Position={spotIn.map((p) => UDim2.fromOffset(0, (1 - p) * 14))}>
					<Panel pad={gap(phone, "xl")} spacing={gap(phone, "m")} seam={spotReady} rarity="Legendary" color={Iron.raised()} scale={flash.map((v) => 1 + v * 0.025)}>
						<Title text={effect(spotlight)} size={Type.title(phone)} color={Iron.text().Lerp(spotlight.Color, 0.35)} tags={spotReady ? ["wave"] : undefined} order={0} />
						<Pills bits={rewardBits(spotlight.Reward as Reward | undefined)} color={spotlight.Color} phone={phone} order={1} />
						<Meter value={xp / math.max(1, spotlight.XPCost)} color={spotReady ? spotlight.Color : Iron.steel()} order={2} height={10} />
						<Text
							text={spotReady ? `${compactNumber(spotlight.XPCost)} XP` : `${compactNumber(math.min(xp, spotlight.XPCost))} / ${compactNumber(spotlight.XPCost)}  ·  ${guide?.NeedXp ?? "Bank flux to earn XP."}`}
							size={Type.small(phone)}
							color={Iron.muted()}
							multiline
							order={3}
						/>
						<frame ref={focusRef} Size={new UDim2(1, 0, 0, 56)} BackgroundTransparency={1} LayoutOrder={4}>
							<Button text={spotReady ? "Claim" : "Earn XP"} onPress={() => claim(spotlight)} disabled={!spotReady} width={phone ? 200 : 240} height={56} textSize={20} stretch={phone} />
						</frame>
					</Panel>
				</frame>
			)}

			{steps.size() > 0 && (
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2}>
					<uilistlayout Padding={new UDim(0, gap(phone, "s"))} SortOrder={Enum.SortOrder.LayoutOrder} />
					<frame Size={new UDim2(1, 0, 0, HIT)} BackgroundColor3={Iron.sunk()} BorderSizePixel={0} LayoutOrder={0}>
						<uicorner CornerRadius={new UDim(0, Corner.card)} />
						<uistroke Color={Iron.edge()} Transparency={0.5} />
						<textbox
							Size={new UDim2(1, -24, 1, 0)}
							Position={UDim2.fromOffset(12, 0)}
							BackgroundTransparency={1}
							Text={query}
							PlaceholderText="Search"
							PlaceholderColor3={Iron.muted()}
							TextColor3={Iron.text()}
							FontFace={Fonts.bold}
							TextSize={Type.body(phone)}
							TextXAlignment={Enum.TextXAlignment.Left}
							ClearTextOnFocus={false}
							Change={{ Text: (box) => setQuery(box.Text) }}
						/>
					</frame>
					<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
						<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
						{["All", "Upcoming", "Claimed"].map((id, i) => (
							<Chip
								key={id}
								text={id}
								on={filter === id}
								onPress={() => {
									Audio.play("filterPick");
									setFilter(id);
									setShown(PAGE_SIZE);
								}}
								order={i}
							/>
						))}
					</frame>
				</frame>
			)}

			{steps.size() > 0 &&
				(visible.size() === 0 ? (
					<EmptyState
						title="No match"
						phone={phone}
						order={3}
						action={{
							text: "Show all",
							onPress: () => {
								setFilter("All");
								setQuery("");
							},
						}}
					/>
				) : (
					<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={3}>
						<uilistlayout Padding={new UDim(0, gap(phone, "m"))} SortOrder={Enum.SortOrder.LayoutOrder} />
						{visible
							.filter((_, i) => i < shown)
							.map((step, i) => (
								<StepCard key={`s${step.Step}`} step={step} claimed={claimed.has(step.Step)} open={isOpen(step)} xp={xp} index={i} phone={phone} onClaim={claim} />
							))}
						{visible.size() > shown && <Button text={`${visible.size() - shown} more`} tone="iron" onPress={() => setShown((n) => n + PAGE_SIZE)} stretch order={100000} />}
					</frame>
				))}
		</scrollingframe>
	);
}

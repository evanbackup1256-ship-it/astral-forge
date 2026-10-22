// Forge Convergence on Forge2: the weekly cross-server push. One shared meter, the current phase
// and its production bonus, and your own reward tiers.
// Remote: ClaimConvergenceReward { Tier }
import React from "@rbxts/react";
import { Audio } from "../../AudioKit/audio";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { Palette } from "../../CoreKit/theme";
import { clockText, compactNumber, formatReward, Reward } from "../../CoreKit/format";
import { useChangePop, useStagger, useWallClock } from "../../MotionKit/motion";
import { Button } from "../design/Button";
import { EmptyState } from "../design/Layers";
import { Card, Meter, Panel } from "../design/Panel";
import { Text, Title } from "../design/Text";
import { Fonts, gap, Iron, Type } from "../design/tokens";
import { Burst, MotionFX } from "../motion/motion";
import type { PageProps } from "../router/routes";

interface Tier {
	Tier: number;
	Required: number;
	CanClaim: boolean;
	Claimed: boolean;
	Reward?: Reward;
}
interface ConvergenceEvent {
	EventId?: string;
	Name: string;
	PhaseName: string;
	EndsAt: number;
	GlobalContribution: number;
	GlobalTarget: number;
	PersonalContribution: number;
	ProductionMultiplier: number;
	Tiers?: Tier[];
}

function TierCard(props: { tier: Tier; mine: number; phone: boolean; index: number; request: PageProps["request"]; hostRef?: React.MutableRefObject<Frame | undefined> }) {
	const { tier, phone } = props;
	const rise = useStagger(props.index + 2);
	const [busy, setBusy] = React.useState(false);
	const claim = () => {
		setBusy(true);
		props.request("ClaimConvergenceReward", { Tier: tier.Tier }, (reply) => {
			setBusy(false);
			if (reply.ok === true) {
				Audio.play("missionClaim");
				Burst.spark(Iron.brass(), 0.9);
			}
		});
	};
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.index} Position={rise.map((p) => UDim2.fromOffset(0, (1 - p) * 10))}>
			<Card accent={tier.Claimed ? Iron.edge() : Iron.brass()} pad={gap(phone, "m")} spacing={6} selected={tier.CanClaim && !tier.Claimed}>
				<Text text={`Tier ${tier.Tier} · ${formatReward(tier.Reward)}`} size={Type.body(phone)} font={Fonts.heavy} color={tier.Claimed ? Iron.muted() : Iron.text()} order={0} />
				<Meter value={tier.Claimed ? 1 : props.mine / math.max(1, tier.Required)} order={1} />
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
					<Text text={`${compactNumber(math.min(props.mine, tier.Required))} / ${compactNumber(tier.Required)}`} size={Type.small(phone)} color={Iron.muted()} box={new UDim2(1, phone ? 0 : -170, 0, 20)} order={0} />
					<frame {...({ Name: "ConvergenceClaimActions" } as object)} ref={props.hostRef} Size={phone ? new UDim2(1, 0, 0, 48) : UDim2.fromOffset(150, 48)} BackgroundTransparency={1} LayoutOrder={1}>
						<Button
							text={tier.Claimed ? "Claimed" : tier.CanClaim ? "Claim" : "Locked"}
							tone={tier.CanClaim ? "brass" : "iron"}
							disabled={!tier.CanClaim}
							busy={busy}
							glint={tier.CanClaim}
							stretch
							height={48}
							onPress={() => {
								if (tier.CanClaim) claim();
							}}
						/>
					</frame>
				</frame>
			</Card>
		</frame>
	);
}

export function ConvergencePage(props: PageProps) {
	const phone = props.phone;
	const event = (props.session as unknown as { Convergence?: ConvergenceEvent }).Convergence;
	const now = useWallClock(event !== undefined);
	const phasePop = useChangePop(event?.PhaseName ?? "");
	const claimHost = React.useRef<Frame>();
	const firstClaim = (event?.Tiers ?? []).find((t) => t.CanClaim)?.Tier;
	// a gamepad lands on the first tier that can be claimed (old ConvergenceView did the same)
	React.useEffect(() => {
		if (firstClaim === undefined || !game.GetService("UserInputService").GamepadEnabled) return undefined;
		const job = task.defer(() => {
			const host = claimHost.current;
			if (host !== undefined && host.Parent !== undefined) GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [firstClaim, event?.EventId]);
	const space = gap(phone, "l");
	React.useEffect(() => {
		if (event !== undefined) MotionFX.play("modeSwitch");
	}, [event?.PhaseName]);
	if (event === undefined) {
		return (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
				<uipadding PaddingTop={new UDim(0, space)} PaddingLeft={new UDim(0, space)} PaddingRight={new UDim(0, space)} />
				<EmptyState title="Forge Convergence" body="Getting this week's shared forge ready…" phone={phone} />
			</frame>
		);
	}
	const tiers = event.Tiers ?? [];
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
			<Panel pad={gap(phone, "xl")} spacing={gap(phone, "m")} seam rarity="Mythic" order={0}>
				<Text text="Weekly cooperative event" size={Type.small(phone)} color={Iron.brass()} order={-1} />
				<Title text={event.Name} size={Type.title(phone)} tags={["rainbow", "wave"]} order={0} />
				<Text text="One forge, every server, all week. Clear a phase together and everyone's production goes up." size={Type.small(phone) + 1} color={Iron.muted()} multiline order={1} />
				<frame Size={new UDim2(1, 0, 0, 28)} BackgroundTransparency={1} LayoutOrder={2}>
					<uiscale Scale={phasePop} />
					<Text text={event.PhaseName} size={20} font={Fonts.heavy} color={Iron.brass()} box={new UDim2(0.5, 0, 1, 0)} />
					<textlabel
						Size={new UDim2(0.5, 0, 1, 0)}
						Position={UDim2.fromScale(0.5, 0)}
						BackgroundTransparency={1}
						Text={now.map((t) => `${clockText(math.max(0, event.EndsAt - t))} left`)}
						FontFace={Fonts.bold}
						TextColor3={Iron.soft()}
						TextSize={Type.small(phone) + 2}
						TextXAlignment={Enum.TextXAlignment.Right}
						TextTruncate={Enum.TextTruncate.AtEnd}
					/>
				</frame>
				<Meter value={event.GlobalContribution / math.max(1, event.GlobalTarget)} color={Iron.ember()} height={12} order={3} />
				<Text
					text={`${compactNumber(event.GlobalContribution)} / ${compactNumber(event.GlobalTarget)} · ${string.format("×%.2f", event.ProductionMultiplier)} production`}
					size={Type.small(phone) + 1}
					color={Iron.soft()}
					order={4}
				/>
				<Text text={`You've put in ${compactNumber(event.PersonalContribution)}`} size={Type.small(phone) + 1} color={Iron.muted()} order={5} />
			</Panel>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
				<uilistlayout Padding={new UDim(0, gap(phone, "m"))} SortOrder={Enum.SortOrder.LayoutOrder} />
				<Text text="Your rewards" size={Type.body(phone)} font={Fonts.heavy} color={Palette.violet} order={-1} />
				{tiers.size() === 0 ? (
					<EmptyState title="No rewards this week" body="Tiers show up when the event starts." phone={phone} />
				) : (
					tiers.map((tier, i) => <TierCard key={`t${tier.Tier}`} tier={tier} mine={event.PersonalContribution} phone={phone} index={i} request={props.request} hostRef={tier.Tier === firstClaim ? claimHost : undefined} />)
				)}
			</frame>
		</scrollingframe>
	);
}

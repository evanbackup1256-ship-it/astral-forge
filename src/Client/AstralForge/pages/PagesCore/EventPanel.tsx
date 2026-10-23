import React from "@rbxts/react";
import { formatReward, Reward } from "../../CoreKit/format";
import { Palette, TapTarget } from "../../CoreKit/theme";
import { kitMember, LuauComponent } from "../luauKits";
import * as LimitedEvents from "../../../../Shared/AstralForge/Shared/LimitedEvents";

const { Button, IconTile, Panel, Text } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");
const Workspace = game.GetService("Workspace");

type Reply = (response: { ok?: boolean; message?: string }) => void;
export type EventDispatch = (action: string, payload?: object, callback?: Reply) => unknown;

export interface EventState {
	Id?: string;
	Paused?: boolean;
	Tokens?: number;
	DayEarned?: number;
	Bought?: Record<string, number>;
	NextId?: string;
}

const PAD = 14;
const HEAD_H = 92;
const ROW_H = 58;
const ROW_H_STACK = 58 + TapTarget + 6;
const ROW_GAP = 8;
const SOON_H = PAD * 2 + 44;

function rgb(accent: [number, number, number]): Color3 {
	return Color3.fromRGB(accent[0], accent[1], accent[2]);
}

function leftText(seconds: number): string {
	const total = math.max(0, math.floor(seconds));
	const days = math.floor(total / 86400);
	const hours = math.floor((total % 86400) / 3600);
	if (days > 0) {
		return `${days}d ${hours}h`;
	}
	const minutes = math.floor((total % 3600) / 60);
	return hours > 0 ? `${hours}h ${minutes}m` : `${math.max(1, minutes)}m`;
}

function dateText(at: number): string {
	return os.date("!%b %d", at).gsub(" 0", " ")[0];
}

export function eventPanelHeight(state: EventState | undefined, stack: boolean): number {
	const event = LimitedEvents.byId(state?.Id);
	if (event === undefined) {
		return LimitedEvents.byId(state?.NextId) !== undefined ? SOON_H : 0;
	}
	const rowH = stack ? ROW_H_STACK : ROW_H;
	const rows = event.Shop.size();
	return PAD * 2 + HEAD_H + rows * rowH + (rows - 1) * ROW_GAP;
}

// refreshes the countdown twice a minute; nothing here needs to be finer than that
function useServerNow(): number {
	const [now, setNow] = React.useState(() => Workspace.GetServerTimeNow());
	React.useEffect(() => {
		let alive = true;
		task.spawn(() => {
			while (alive) {
				task.wait(30);
				if (alive) {
					setNow(Workspace.GetServerTimeNow());
				}
			}
		});
		return () => {
			alive = false;
		};
	}, []);
	return now;
}

export function EventPanel(props: { state: EventState; dispatch: EventDispatch; stack: boolean; reducedMotion?: boolean }) {
	const { state, stack } = props;
	const now = useServerNow();
	const [pending, setPending] = React.useState<string | undefined>(undefined);
	const [refused, setRefused] = React.useState<{ key: string; token: number }>({ key: "", token: 0 });
	const event = LimitedEvents.byId(state.Id);

	if (event === undefined) {
		const upcoming = LimitedEvents.byId(state.NextId);
		if (upcoming === undefined) {
			return <frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} />;
		}
		return (
			<Panel size={UDim2.fromScale(1, 1)} accent={rgb(upcoming.Accent)} background={Palette.panel} padding={PAD} reducedMotion={props.reducedMotion} clips={false}>
				<Text value="Next event" size={13} color={rgb(upcoming.Accent)} weight={Enum.FontWeight.SemiBold} sizeConstraint={new UDim2(1, 0, 0, 16)} />
				<Text
					value={`${upcoming.Name} opens ${dateText(upcoming.StartsAt)}, in ${leftText(upcoming.StartsAt - now)}.`}
					size={14}
					color={Palette.cream}
					weight={Enum.FontWeight.Bold}
					fit={true}
					minSize={10}
					position={UDim2.fromOffset(0, 20)}
					sizeConstraint={new UDim2(1, 0, 0, 22)}
				/>
			</Panel>
		);
	}

	const accent = rgb(event.Accent);
	const tokens = state.Tokens ?? 0;
	const bought = state.Bought ?? {};
	const buy = (itemId: string) => {
		if (pending !== undefined) {
			return;
		}
		setPending(itemId);
		const fallback = task.delay(8, () => setPending(undefined));
		props.dispatch("EventAct", { Op: "Buy", Item: itemId }, (response) => {
			pcall(task.cancel, fallback);
			setPending(undefined);
			if (response.ok !== true) {
				setRefused((current) => ({ key: itemId, token: current.token + 1 }));
			}
		});
	};

	const rowH = stack ? ROW_H_STACK : ROW_H;
	const rows: Record<string, React.Element> = {};
	event.Shop.forEach((item, index) => {
		const left = math.max(0, item.Stock - (bought[item.Id] ?? 0));
		const affordable = tokens >= item.Price;
		const ready = left > 0 && affordable;
		rows[item.Id] = (
			<frame
				Size={new UDim2(1, 0, 0, rowH)}
				Position={UDim2.fromOffset(0, HEAD_H + index * (rowH + ROW_GAP))}
				BackgroundTransparency={1}
				BorderSizePixel={0}
			>
				<IconTile kind="Gift" accent={ready ? accent : Palette.panelSoft} size={40} radius={12} position={UDim2.fromOffset(0, 6)} glow={false} reducedMotion={props.reducedMotion} />
				<Text
					value={item.Name}
					size={15}
					color={Palette.cream}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					minSize={11}
					position={UDim2.fromOffset(52, 6)}
					sizeConstraint={new UDim2(1, stack ? -52 : -(52 + 162), 0, 21)}
				/>
				<Text
					value={`${formatReward(item.Reward as Reward)} · ${left} of ${item.Stock} left`}
					size={12}
					color={Palette.muted}
					wrap={true}
					fit={true}
					minSize={9}
					position={UDim2.fromOffset(52, 28)}
					sizeConstraint={new UDim2(1, stack ? -52 : -(52 + 162), 0, 28)}
				/>
				<frame
					Size={stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(150, 44)}
					Position={stack ? UDim2.fromOffset(0, ROW_H) : new UDim2(1, -150, 0.5, -22)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
				>
					<Button
						text={left <= 0 ? "Sold out" : `${item.Price} ${event.Token.lower()}`}
						onClick={() => buy(item.Id)}
						color={ready ? accent : Palette.panelSoft}
						textColor={ready ? Palette.ink : Palette.muted}
						size={UDim2.fromScale(1, 1)}
						disabled={!ready}
						highlight={ready}
						loading={pending === item.Id}
						shakeToken={refused.key === item.Id ? refused.token : 0}
						reducedMotion={props.reducedMotion}
					/>
				</frame>
			</frame>
		);
	});

	const dayEarned = state.DayEarned ?? 0;
	const capped = dayEarned >= event.DailyCap;
	return (
		<Panel size={UDim2.fromScale(1, 1)} accent={accent} background={Palette.panel} padding={PAD} reducedMotion={props.reducedMotion} clips={false}>
			<Text
				value={`Ends in ${leftText(event.EndsAt - now)}`}
				size={13}
				color={accent}
				weight={Enum.FontWeight.SemiBold}
				fit={true}
				minSize={9}
				sizeConstraint={new UDim2(1, 0, 0, 16)}
			/>
			<Text
				value={event.Name}
				size={20}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={13}
				position={UDim2.fromOffset(0, 18)}
				sizeConstraint={new UDim2(1, 0, 0, 26)}
			/>
			<Text
				value={event.Blurb}
				size={12}
				color={Palette.creamSoft}
				wrap={true}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(0, 44)}
				sizeConstraint={new UDim2(1, 0, 0, 28)}
			/>
			<Text
				value={
					capped
						? `${tokens} ${event.Token.lower()} · today's ${event.DailyCap} are in, more tomorrow`
						: `${tokens} ${event.Token.lower()} · ${dayEarned} of ${event.DailyCap} earned today`
				}
				size={12}
				color={accent}
				weight={Enum.FontWeight.Bold}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(0, 72)}
				sizeConstraint={new UDim2(1, 0, 0, 16)}
			/>
			{rows}
		</Panel>
	);
}

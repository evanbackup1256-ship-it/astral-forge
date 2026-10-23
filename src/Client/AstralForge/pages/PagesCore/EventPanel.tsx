import React from "@rbxts/react";
import { formatReward, Reward } from "../../CoreKit/format";
import { Palette, TapTarget } from "../../CoreKit/theme";
import { kitMember, LuauComponent } from "../luauKits";
import * as LimitedEvents from "../../../../Shared/AstralForge/Shared/LimitedEvents";
import { BrassRule, FORGE_RADIUS } from "../../UiCore/forgeCard";
import { BODY, BODY_SEMI, Label, PnSurface, RowSurface, TITLE_FACE } from "../../UiCore/mockKit";
import { IconWell } from "../gcKit";

const { Button, Text } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");
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
const ROW_H = 60;
const ROW_H_STACK = 60 + TapTarget + 6;
const ROW_GAP = 12;
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
			<PnSurface radius={FORGE_RADIUS} size={UDim2.fromScale(1, 1)} accent={rgb(upcoming.Accent)} background={Palette.panel} padding={PAD} reducedMotion={props.reducedMotion} clips={false}><BrassRule pad={PAD} />
				<Label text="Next event" color={rgb(upcoming.Accent)} />
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
			</PnSurface>
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
				{/* design/16-season row: .row surface, icon well, semibold name over a muted reward line */}
				<frame Size={new UDim2(1, 0, 0, ROW_H)} BackgroundColor3={Palette.white} BorderSizePixel={0}>
					<RowSurface />
				</frame>
				<frame Position={UDim2.fromOffset(10, 12)} Size={UDim2.fromOffset(36, 36)} BackgroundTransparency={1}>
					<IconWell icon="Gift" accent={ready ? accent : Palette.muted} />
				</frame>
				<textlabel
					Text={item.Name}
					FontFace={BODY_SEMI}
					TextSize={15}
					TextColor3={Palette.cream}
					BackgroundTransparency={1}
					TextXAlignment={Enum.TextXAlignment.Left}
					TextTruncate={Enum.TextTruncate.AtEnd}
					Position={UDim2.fromOffset(58, 10)}
					Size={new UDim2(1, stack ? -68 : -(58 + 170), 0, 20)}
				/>
				<textlabel
					Text={`${formatReward(item.Reward as Reward)} · ${left} of ${item.Stock} left`}
					FontFace={BODY}
					TextSize={12}
					TextColor3={Palette.muted}
					BackgroundTransparency={1}
					TextXAlignment={Enum.TextXAlignment.Left}
					TextTruncate={Enum.TextTruncate.AtEnd}
					Position={UDim2.fromOffset(58, 32)}
					Size={new UDim2(1, stack ? -68 : -(58 + 170), 0, 16)}
				/>
				<frame
					Size={stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(150, 44)}
					Position={stack ? UDim2.fromOffset(0, ROW_H + 6) : new UDim2(1, -158, 0, 8)}
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
		<PnSurface radius={FORGE_RADIUS} size={UDim2.fromScale(1, 1)} accent={accent} background={Palette.panel} padding={PAD} reducedMotion={props.reducedMotion} clips={false}><BrassRule pad={PAD} />
			<Label text={`Ends in ${leftText(event.EndsAt - now)}`} color={accent} />
			<textlabel
				Text={event.Name}
				FontFace={TITLE_FACE}
				TextSize={20}
				TextColor3={Palette.cream}
				BackgroundTransparency={1}
				TextXAlignment={Enum.TextXAlignment.Left}
				TextTruncate={Enum.TextTruncate.AtEnd}
				Position={UDim2.fromOffset(0, 18)}
				Size={new UDim2(1, 0, 0, 26)}
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
		</PnSurface>
	);
}

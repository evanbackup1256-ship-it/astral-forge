import React from "@rbxts/react";
import { formatReward, Reward } from "../../CoreKit/format";
import { Palette, TapTarget } from "../../CoreKit/theme";
import { kitMember, LuauComponent } from "../luauKits";

const { Button, EmptyState, IconTile, Panel, Text } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");

type Reply = (response: { ok?: boolean; message?: string }) => void;
export type CommunityDispatch = (action: string, payload?: object, callback?: Reply) => unknown;

export interface CommunityState {
	GroupId?: number;
	GroupName?: string;
	GroupClaimed?: boolean;
	GroupReward?: Reward;
	Likes?: number;
	LikeGoals?: { Index: number; Likes: number; Reward?: Reward; Claimed?: boolean }[];
	NotifyRewardEnabled?: boolean;
	NotifyClaimed?: boolean;
	NotifyReward?: Reward;
}

interface Row {
	key: string;
	icon: string;
	accent: Color3;
	title: string;
	detail: string;
	button: string;
	ready: boolean;
	onClick: () => void;
}

const HEADER_H = 26;
const ROW_H = 58;
const ROW_H_STACK = 58 + TapTarget + 6;
const ROW_GAP = 8;
const EMPTY_H = 14 * 2 + HEADER_H + 20;

// can this player be shown Roblox's notification prompt? (13+, not already opted in, not prompted in 30 days)
function useCanPromptNotifications(): [boolean, () => void] {
	const [can, setCan] = React.useState(false);
	React.useEffect(() => {
		let alive = true;
		const job = task.spawn(() => {
			const [found, service] = pcall(() => game.GetService("ExperienceNotificationService"));
			if (!found || service === undefined) {
				return;
			}
			const [ok, eligible] = pcall(() => service.CanPromptOptInAsync());
			if (alive && ok && eligible === true) {
				setCan(true);
			}
		});
		return () => {
			alive = false;
			pcall(task.cancel, job);
		};
	}, []);
	const prompt = () => {
		pcall(() => game.GetService("ExperienceNotificationService").PromptOptIn());
		// the prompt only shows once per 30 days, so hide the row after asking
		setCan(false);
	};
	return [can, prompt];
}

export function communityPanelHeight(state: CommunityState | undefined, stack: boolean, canNotify: boolean): number {
	const rows = communityRowCount(state, canNotify);
	if (state === undefined) {
		return 0;
	}
	if (rows === 0) {
		return EMPTY_H;
	}
	const rowH = stack ? ROW_H_STACK : ROW_H;
	return 14 * 2 + HEADER_H + rows * rowH + (rows - 1) * ROW_GAP;
}

function communityRowCount(state: CommunityState | undefined, canNotify: boolean): number {
	if (state === undefined) {
		return 0;
	}
	let rows = (state.GroupId ?? 0) > 0 ? 1 : 0;
	if ((state.LikeGoals ?? []).size() > 0) {
		rows += 1;
	}
	if (canNotify) {
		rows += 1;
	}
	return rows;
}

export function useCommunityRewards(state: CommunityState | undefined, stack: boolean) {
	const [canNotify, promptNotify] = useCanPromptNotifications();
	return { height: communityPanelHeight(state, stack, canNotify), canNotify, promptNotify };
}

export function CommunityPanel(props: {
	state: CommunityState;
	dispatch: CommunityDispatch;
	stack: boolean;
	canNotify: boolean;
	promptNotify: () => void;
	reducedMotion?: boolean;
}) {
	const { state, stack } = props;
	const [pending, setPending] = React.useState<string | undefined>(undefined);
	const [refused, setRefused] = React.useState<{ key: string; token: number }>({ key: "", token: 0 });
	const claim = (key: string, payload: { Kind: string; Index: number }) => {
		if (pending !== undefined) {
			return;
		}
		setPending(key);
		const fallback = task.delay(8, () => setPending(undefined));
		props.dispatch("ClaimCommunityReward", payload, (response) => {
			pcall(task.cancel, fallback);
			setPending(undefined);
			if (response.ok !== true) {
				setRefused((current) => ({ key, token: current.token + 1 }));
			}
		});
	};

	const rows: Row[] = [];
	const groupName = state.GroupName ?? "the group";
	if ((state.GroupId ?? 0) > 0) {
		const claimed = state.GroupClaimed === true;
		rows.push({
			key: "group",
			icon: "Guild",
			accent: Palette.cyan,
			title: claimed ? `In the ${groupName} group` : `Join the ${groupName} group`,
			detail: claimed ? "Claimed" : formatReward(state.GroupReward),
			button: claimed ? "Claimed" : "Check & claim",
			ready: !claimed,
			onClick: () => claim("group", { Kind: "Group", Index: 1 }),
		});
	}
	const likes = state.Likes ?? 0;
	const goals = state.LikeGoals ?? [];
	if (goals.size() > 0) {
		// the first goal still to claim: reached ones first, otherwise the next one to reach
		const open = goals.find((goal) => goal.Claimed !== true);
		const reached = open !== undefined && likes >= open.Likes;
		rows.push({
			key: "likes",
			icon: "Gift",
			accent: Palette.pink,
			title: open === undefined ? "Every like goal claimed" : `Like goal: ${open.Likes} likes`,
			detail:
				open === undefined
					? `${likes} likes so far. Thanks for the support.`
					: reached
						? formatReward(open.Reward)
						: `${likes} of ${open.Likes} likes. Liking the game helps reach it.`,
			button: open === undefined ? "Done" : reached ? "Claim" : "Not yet",
			ready: reached,
			onClick: () => {
				if (open !== undefined) {
					claim("likes", { Kind: "Like", Index: open.Index });
				}
			},
		});
	}
	if (props.canNotify) {
		const paid = state.NotifyRewardEnabled === true && state.NotifyClaimed !== true;
		rows.push({
			key: "notify",
			icon: "Mail",
			accent: Palette.mango,
			title: "Get notified",
			detail: paid ? `Turn on notifications: ${formatReward(state.NotifyReward)}` : "Hear when your vault is full or an event starts.",
			button: "Turn on",
			ready: true,
			onClick: () => {
				props.promptNotify();
				if (paid) {
					claim("notify", { Kind: "Notify", Index: 1 });
				}
			},
		});
	}

	const rowH = stack ? ROW_H_STACK : ROW_H;
	const children: Record<string, React.Element> = {};
	rows.forEach((row, index) => {
		children[row.key] = (
			<frame
				Size={new UDim2(1, 0, 0, rowH)}
				Position={UDim2.fromOffset(0, HEADER_H + index * (rowH + ROW_GAP))}
				BackgroundTransparency={1}
				BorderSizePixel={0}
			>
				<IconTile kind={row.icon} accent={row.ready ? row.accent : Palette.panelSoft} size={40} radius={12} position={UDim2.fromOffset(0, 6)} glow={row.ready} reducedMotion={props.reducedMotion} />
				<Text
					value={row.title}
					size={15}
					color={Palette.cream}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					minSize={11}
					position={UDim2.fromOffset(52, 6)}
					sizeConstraint={new UDim2(1, stack ? -52 : -(52 + 162), 0, 21)}
				/>
				<Text
					value={row.detail}
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
						text={row.button}
						onClick={row.onClick}
						color={row.ready ? row.accent : Palette.panelSoft}
						textColor={row.ready ? Palette.ink : Palette.muted}
						size={UDim2.fromScale(1, 1)}
						disabled={!row.ready}
						highlight={row.ready}
						loading={pending === row.key}
						shakeToken={refused.key === row.key ? refused.token : 0}
						reducedMotion={props.reducedMotion}
					/>
				</frame>
			</frame>
		);
	});
	return (
		<Panel size={UDim2.fromScale(1, 1)} accent={Palette.cyan} background={Palette.panel} padding={14} reducedMotion={props.reducedMotion} clips={false}>
			<Text value="Community" size={13} color={Palette.cyan} weight={Enum.FontWeight.SemiBold} fit={false} sizeConstraint={new UDim2(1, 0, 0, 16)} />
			{rows.size() === 0 ? (
				<frame Size={new UDim2(1, 0, 1, -HEADER_H)} Position={UDim2.fromOffset(0, HEADER_H)} BackgroundTransparency={1} BorderSizePixel={0}>
					<EmptyState title="Nothing here yet" compact={true} inset={0} size={UDim2.fromScale(1, 1)} reducedMotion={props.reducedMotion} />
				</frame>
			) : (
				children
			)}
		</Panel>
	);
}

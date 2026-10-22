// Lab on Forge2: today's orders (claim one or all), the power board (route cells into output,
// vault or taps), and Forge Programs (when/then rules) once they unlock.
// Remotes: ClaimLabOrder { Id }, RouteLabPower { Channel, Delta }, ProgramAct { Op, Index?, Rule? }
import React from "@rbxts/react";
import Programs = require("../../../../Shared/AstralForge/Shared/ForgePrograms");
import { Audio } from "../../AudioKit/audio";
import { Palette } from "../../CoreKit/theme";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { Dropdown } from "../../UiCore/ui";
import { clockText, formatReward, Reward } from "../../CoreKit/format";
import { useChangePop, useFlash, useStagger, useWallClock } from "../../MotionKit/motion";
import { Button } from "../design/Button";
import { EmptyState } from "../design/Layers";
import { Card, Meter, Panel } from "../design/Panel";
import { Text, Title } from "../design/Text";
import { Fonts, gap, HIT, Iron, Type } from "../design/tokens";
import { Burst, MotionFX } from "../motion/motion";
import type { PageProps } from "../router/routes";

const CHANNELS = ["Production", "Storage", "Tap"];

interface OrderState {
	Id: string;
	Claimed?: boolean;
	Progress: number;
	Target: number;
}
interface OrderConfig {
	Id: string;
	Name: string;
	Description?: string;
	Color: Color3;
	Reward: Reward;
}
interface ChannelConfig {
	Name: string;
	Description: string;
	Color: Color3;
}
interface LabState {
	ResetAt: number;
	Orders: OrderState[];
	AvailableCells: number;
	TotalCells: number;
	Routing: Record<string, number | undefined>;
	Effects: Record<string, number | undefined>;
}
interface Rule {
	When: string;
	Do: string;
	Arg?: number;
	Enabled: boolean;
}
interface ProgramsState {
	Unlocked: boolean;
	Rules: Rule[];
	Max: number;
	Paused?: boolean;
}

function Row(props: { order: number; children?: React.ReactNode; wraps?: boolean }) {
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.order}>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps={props.wraps !== false} Padding={new UDim(0, 8)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
			{props.children}
		</frame>
	);
}

function OrderCard(props: { state: OrderState; config: OrderConfig; index: number; phone: boolean; request: PageProps["request"] }) {
	const { state, config, phone } = props;
	const ready = state.Claimed !== true && state.Progress >= state.Target;
	const rise = useStagger(props.index + 2);
	const [claims, setClaims] = React.useState(0);
	const [claiming, setClaiming] = React.useState(false);
	const flash = useFlash(claims, false, 0.4);
	const [refused, setRefused] = React.useState(0);
	// a refusal shakes the button, same curve as the old client's shakeToken
	const shake = useFlash(refused, false, 0.42);
	const claim = () => {
		if (!ready || claiming) return;
		setClaims((n) => n + 1);
		setClaiming(true);
		// one claim in flight per order; if the server never answers the button frees itself after 8s
		const fallback = task.delay(8, () => setClaiming(false));
		props.request("ClaimLabOrder", { Id: state.Id }, (reply) => {
			pcall(task.cancel, fallback);
			setClaiming(false);
			if (reply.ok === true) {
				Audio.play("missionClaim");
				Burst.spark(config.Color, 0.8);
			} else {
				setRefused((n) => n + 1);
			}
		});
	};
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.index} Position={rise.map((p) => UDim2.fromOffset(0, (1 - p) * 12))}>
			<Card accent={config.Color} pad={gap(phone, "m")} spacing={6} selected={ready} scale={flash.map((v) => 1 + v * 0.02)}>
				<Text text={config.Name} size={Type.body(phone)} font={Fonts.heavy} order={0} />
				{config.Description !== undefined && <Text text={config.Description} size={Type.small(phone)} color={Iron.muted()} multiline order={1} />}
				<Meter value={state.Claimed === true ? 1 : state.Progress / math.max(1, state.Target)} color={config.Color} order={2} />
				<Row order={3}>
					<Text
						text={`${math.min(state.Progress, state.Target)}/${state.Target} · ${formatReward(config.Reward)}`}
						size={Type.small(phone)}
						color={state.Claimed === true ? Iron.muted() : Iron.soft()}
						box={new UDim2(1, phone ? 0 : -186, 0, 20)}
						order={0}
					/>
					<frame Size={UDim2.fromOffset(phone ? 140 : 176, 48)} BackgroundTransparency={1} LayoutOrder={1} Position={shake.map((a) => UDim2.fromOffset(math.sin(a * math.pi * 4.5) * a * 7, 0))}>
						<Button text={state.Claimed === true ? "Collected" : ready ? "Collect" : "Not yet"} tone={ready ? "brass" : "iron"} disabled={!ready} busy={claiming} glint={ready} stretch height={48} onPress={claim} />
					</frame>
				</Row>
			</Card>
		</frame>
	);
}

function Channel(props: { id: string; config: ChannelConfig; cells: number; effect: number; free: number; phone: boolean; order: number; request: PageProps["request"] }) {
	const pop = useChangePop(props.cells);
	const route = (delta: number) => () => {
		Audio.play("click");
		props.request("RouteLabPower", { Channel: props.id, Delta: delta });
	};
	return (
		<Card accent={props.config.Color} pad={gap(props.phone, "m")} spacing={6} order={props.order}>
			<Text text={props.config.Name} size={Type.body(props.phone)} font={Fonts.heavy} order={0} />
			<Text text={`${props.config.Description} · +${math.floor(props.effect * 100)}% now`} size={Type.small(props.phone)} color={Iron.muted()} multiline order={1} />
			<Row order={2} wraps={false}>
				<Button text="−" tone="iron" width={HIT} disabled={props.cells <= 0} onPress={route(-1)} order={0} />
				<frame Size={UDim2.fromOffset(90, HIT)} BackgroundTransparency={1} LayoutOrder={1}>
					<uiscale Scale={pop} />
					<Text text={`${props.cells} cells`} size={18} font={Fonts.heavy} color={props.config.Color} align="Center" box={UDim2.fromScale(1, 1)} />
				</frame>
				<Button text="+" width={HIT} disabled={props.free <= 0} onPress={route(1)} order={2} />
			</Row>
		</Card>
	);
}

function sentence(rule: Rule): string {
	const action = Programs.actionOf(rule.Do);
	const when = Programs.whenOf(rule.When);
	const arg = when?.Arg !== undefined ? ` ${rule.Arg ?? when.Arg.Default} ${when.Arg.Label}` : "";
	return `${when?.Name ?? rule.When}${arg}: ${string.lower(action?.Name ?? rule.Do)}`;
}

function RuleBuilder(props: { phone: boolean; request: PageProps["request"]; order: number }) {
	const [doId, setDo] = React.useState(Programs.ACTIONS[0].Id);
	const action = Programs.actionOf(doId) ?? Programs.ACTIONS[0];
	const [whenId, setWhen] = React.useState(action.Whens[0]);
	const when = Programs.whenOf(action.Whens.includes(whenId) ? whenId : action.Whens[0]) ?? Programs.WHENS[0];
	const [arg, setArg] = React.useState<number | undefined>(undefined);
	const value = when.Arg !== undefined ? math.clamp(arg ?? when.Arg.Default, when.Arg.Min, when.Arg.Max) : undefined;
	const step = (delta: number) => {
		if (when.Arg === undefined || value === undefined) return;
		setArg(math.clamp(value + delta * when.Arg.Step, when.Arg.Min, when.Arg.Max));
	};
	return (
		<Panel pad={gap(props.phone, "m")} spacing={8} color={Iron.sunk()} order={props.order}>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1} ZIndex={46}>
				<uilistlayout FillDirection={props.phone ? Enum.FillDirection.Vertical : Enum.FillDirection.Horizontal} Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<Dropdown
					options={Programs.ACTIONS.map((a) => ({ id: a.Id, label: a.Name }))}
					value={action.Id}
					label="Do"
					onChange={(id: string) => {
						setDo(id);
						setArg(undefined);
						const picked = Programs.actionOf(id);
						if (picked !== undefined) setWhen(picked.Whens[0]);
					}}
					accent={Palette.coral}
					size={props.phone ? new UDim2(1, 0, 0, HIT) : new UDim2(0.5, -4, 0, HIT)}
					layoutOrder={0}
					zIndex={47}
				/>
				<Dropdown
					options={action.Whens.map((id) => ({ id, label: Programs.whenOf(id)?.Name ?? id }))}
					value={when.Id}
					label="When"
					onChange={(id: string) => {
						setWhen(id);
						setArg(undefined);
					}}
					accent={Palette.coral}
					size={props.phone ? new UDim2(1, 0, 0, HIT) : new UDim2(0.5, -4, 0, HIT)}
					layoutOrder={1}
					zIndex={46}
				/>
			</frame>
			{when.Arg !== undefined && value !== undefined && (
				<Row order={4} wraps={false}>
					<Button text="−" tone="iron" width={HIT} onPress={() => step(-1)} order={0} />
					<Text text={`${value} ${when.Arg.Label}`} size={16} font={Fonts.heavy} align="Center" box={UDim2.fromOffset(120, HIT)} order={1} />
					<Button text="+" tone="iron" width={HIT} onPress={() => step(1)} order={2} />
				</Row>
			)}
			<Button
				text="Add rule"
				width={150}
				order={5}
				onPress={() => {
					props.request("ProgramAct", { Op: "Save", Rule: { Do: action.Id, When: when.Id, Arg: value, Enabled: true } }, (reply) => {
						if (reply.ok === true) MotionFX.play("confirm");
					});
				}}
			/>
		</Panel>
	);
}

function ProgramsSection(props: { programs: ProgramsState; phone: boolean; request: PageProps["request"]; order: number }) {
	const { programs, phone } = props;
	return (
		<Panel pad={gap(phone, "l")} spacing={gap(phone, "m")} order={props.order}>
			<Title text="Forge Programs" size={Type.title(phone)} order={0} />
			<Text
				text={programs.Paused === true ? "Programs are paused for a moment" : `${programs.Rules.size()} of ${programs.Max} rules`}
				size={Type.small(phone)}
				color={programs.Paused === true ? Iron.ember() : Iron.muted()}
				order={1}
			/>
			{programs.Rules.map((rule, index) => {
				const on = rule.Enabled !== false;
				return (
					<Row key={`rule${index}`} order={10 + index} wraps={false}>
						<Text text={sentence(rule)} size={Type.small(phone) + 1} color={on ? Iron.text() : Iron.muted()} box={new UDim2(1, -(90 + HIT + 46 + 16), 0, HIT)} order={0} />
						<Button text={on ? "On" : "Off"} tone={on ? "brass" : "iron"} width={90} onPress={() => props.request("ProgramAct", { Op: "Toggle", Index: index + 1 })} order={1} />
						<Button text="Remove" tone="quiet" width={HIT + 46} onPress={() => props.request("ProgramAct", { Op: "Delete", Index: index + 1 })} order={2} />
					</Row>
				);
			})}
			{programs.Rules.size() < programs.Max && <RuleBuilder phone={phone} request={props.request} order={100} />}
		</Panel>
	);
}

export function LabPage(props: PageProps) {
	const phone = props.phone;
	const session = props.session as unknown as { Lab?: LabState; ForgePrograms?: ProgramsState };
	const config = props.config as unknown as { Lab?: { Orders: OrderConfig[]; Power: { Channels: Record<string, ChannelConfig | undefined> } }; ClientPageGuides?: { Lab?: { EmptyOrders?: string } } };
	const now = useWallClock(true);
	const lastAll = React.useRef(-math.huge);
	const claimHost = React.useRef<Frame>();
	const readyCount = (session.Lab?.Orders ?? []).filter((o) => o.Claimed !== true && o.Progress >= o.Target).size();
	// a gamepad lands on the first claim when orders come due, like the old Lab
	React.useEffect(() => {
		if (readyCount <= 0 || !game.GetService("UserInputService").GamepadEnabled) return undefined;
		const job = task.defer(() => {
			const host = claimHost.current;
			if (host !== undefined && host.Parent !== undefined) GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [readyCount]);
	const space = gap(phone, "l");
	const lab = session.Lab;
	const programs = session.ForgePrograms;
	if (lab === undefined || config.Lab === undefined) {
		return (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
				<uipadding PaddingTop={new UDim(0, space)} PaddingLeft={new UDim(0, space)} PaddingRight={new UDim(0, space)} />
				<EmptyState title="Workshop Lab" body="Loading the Lab..." phone={phone} />
			</frame>
		);
	}
	const byId: Record<string, OrderConfig | undefined> = {};
	for (const entry of config.Lab.Orders) byId[entry.Id] = entry;
	const ready = lab.Orders.filter((o) => o.Claimed !== true && o.Progress >= o.Target);
	const claimAll = () => {
		if (os.clock() - lastAll.current < 1.5) return;
		lastAll.current = os.clock();
		for (const order of ready) props.request("ClaimLabOrder", { Id: order.Id });
		MotionFX.play("success");
	};
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

			<frame ref={claimHost} Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0}>
			<uilistlayout Padding={new UDim(0, space)} SortOrder={Enum.SortOrder.LayoutOrder} />
			<Panel pad={gap(phone, "l")} spacing={gap(phone, "s")} seam={ready.size() > 0} order={0}>
				<Title text="Workshop Lab" size={Type.title(phone)} tags={["wave"]} order={0} />
				<textlabel
					Size={new UDim2(1, 0, 0, 22)}
					BackgroundTransparency={1}
					Text={now.map((t) => `New orders in ${clockText(lab.ResetAt - t)}`)}
					FontFace={Fonts.bold}
					TextColor3={Iron.soft()}
					TextSize={Type.small(phone) + 2}
					TextXAlignment={Enum.TextXAlignment.Left}
					TextTruncate={Enum.TextTruncate.AtEnd}
					LayoutOrder={1}
				/>
				<Text text={`${lab.Orders.filter((o) => o.Claimed === true).size()} / ${lab.Orders.size()} paid`} size={Type.small(phone)} color={Palette.mint} order={2} />
				{ready.size() > 0 && (
					<frame {...({ Name: "LabClaimActions" } as object)} Size={UDim2.fromOffset(phone ? 200 : 220, 48)} BackgroundTransparency={1} LayoutOrder={3}>
						<Button text={`Claim all · ${ready.size()}`} stretch height={48} glint onPress={claimAll} />
					</frame>
				)}
			</Panel>

			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
				<uilistlayout Padding={new UDim(0, gap(phone, "m"))} SortOrder={Enum.SortOrder.LayoutOrder} />
				<Text text="Today's orders" size={Type.body(phone)} font={Fonts.heavy} color={Palette.mint} order={-1} />
				{lab.Orders.size() === 0 ? (
					<EmptyState title="No orders yet" body={config.ClientPageGuides?.Lab?.EmptyOrders ?? "Orders refresh at the lab reset clock."} phone={phone} />
				) : (
					lab.Orders.map((order, i) => {
						const entry = byId[order.Id];
						return entry !== undefined ? <OrderCard key={order.Id} state={order} config={entry} index={i} phone={phone} request={props.request} /> : undefined;
					})
				)}
			</frame>
			</frame>

			<Panel pad={gap(phone, "l")} spacing={gap(phone, "m")} order={2}>
				<Title text="Power board" size={Type.title(phone)} order={0} />
				<Text text={`${lab.AvailableCells} of ${lab.TotalCells} cells free. Move cells whenever you like.`} size={Type.small(phone) + 1} color={Iron.soft()} multiline order={1} />
				<Text text="Bonuses apply at once. A new cell unlocks every 8 rebirths." size={Type.small(phone)} color={Iron.muted()} multiline order={3} />
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2}>
					<uigridlayout CellSize={new UDim2(phone ? 1 : 1 / 3, phone ? 0 : -8, 0, phone ? 150 : 170)} CellPadding={UDim2.fromOffset(10, 10)} SortOrder={Enum.SortOrder.LayoutOrder} />
					{CHANNELS.map((id, i) => {
						const channel = config.Lab!.Power.Channels[id];
						return channel !== undefined ? (
							<Channel key={id} id={id} config={channel} cells={lab.Routing[id] ?? 0} effect={lab.Effects[id] ?? 0} free={lab.AvailableCells} phone={phone} order={i} request={props.request} />
						) : undefined;
					})}
				</frame>
			</Panel>

			{programs !== undefined && programs.Unlocked && <ProgramsSection programs={programs} phone={phone} request={props.request} order={3} />}
		</scrollingframe>
	);
}

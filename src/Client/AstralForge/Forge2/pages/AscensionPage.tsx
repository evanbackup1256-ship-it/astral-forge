// Ascension, rebuilt on Forge2. The final, endless reset: a slow double orbit around your rank,
// what it resets (always on screen, never folded away), a press-and-hold to ascend, the harmony
// strip and the six sigils.
// Remotes: Ascend {}, UpgradeSigil {Id}.
import React from "@rbxts/react";
import { Audio } from "../../AudioKit/audio";
import { compactNumber } from "../../CoreKit/format";
import { useClock, useFlipperSpring, useListStagger } from "../../MotionKit/motion";
import { ForgeButton as Button } from "../design/ForgeButton";
import { EmptyState, Tooltip } from "../design/Layers";
import { Card, Meter, Panel } from "../design/Panel";
import { Text, Title } from "../design/Text";
import { Fonts, gap, HIT, Iron, Type } from "../design/tokens";
import { Burst, MotionFX } from "../motion/motion";
import type { PageProps } from "../router/routes";

const RunService = game.GetService("RunService");
const UserInputService = game.GetService("UserInputService");

type Flux = number | string;
interface Sigil {
	Id: string;
	Name: string;
	Line: string;
	Effect: string;
	Level: number;
	EffectiveLevel: number;
	Multiplier: Flux;
	Cost: Flux;
	Affordable: boolean;
}
interface AscensionState {
	Rank: number;
	Aether: Flux;
	Production: Flux;
	DomainRank: number;
	RequiredDomainRank: number;
	CanAscend: boolean;
	Gain: Flux;
	NextRankProduction: Flux;
	Harmony: number;
	Sigils: Sigil[];
}

const AETHER = Color3.fromRGB(255, 196, 120);
const SIGIL_COLORS: Record<string, Color3 | undefined> = {
	Sol: Color3.fromRGB(255, 184, 52),
	Bastion: Color3.fromRGB(96, 166, 255),
	Strike: Color3.fromRGB(255, 104, 112),
	Ember: Color3.fromRGB(250, 104, 178),
	Crown: Color3.fromRGB(178, 134, 255),
	Lodestar: Color3.fromRGB(86, 236, 178),
};
const HOLD_SECONDS = 1.6;
export const RESET_WARNING =
	"Ascending resets your Domain, rebirths, cores and current run. Research, relics, artifacts, the Star Foundry and sigils stay.";

function Orbit(props: { count: number; radius: number; dot: number; speed: number; color: Color3 }) {
	const spin = useClock(true, 0.05, math.pi * 2);
	const dots: React.Element[] = [];
	for (let i = 1; i <= props.count; i++) {
		const phase = ((i - 1) / props.count) * math.pi * 2;
		dots.push(
			<frame
				key={`d${i}`}
				Size={UDim2.fromOffset(props.dot, props.dot)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Position={spin.map((angle) => {
					const a = angle * props.speed + phase;
					return new UDim2(0.5, math.cos(a) * props.radius, 0.5, math.sin(a) * props.radius);
				})}
				BackgroundColor3={props.color}
				BackgroundTransparency={0.15 + (i % 3) * 0.2}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>,
		);
	}
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
			{dots}
		</frame>
	);
}

function isPress(input: InputObject) {
	return input.UserInputType === Enum.UserInputType.MouseButton1 || input.UserInputType === Enum.UserInputType.Touch || input.KeyCode === Enum.KeyCode.ButtonA;
}

/** Press and hold; letting go early (anywhere) cancels. A tap is never enough for a full reset. */
function HoldToAscend(props: { enabled: boolean; phone: boolean; onConfirm: () => void }) {
	const [fill, setFill] = React.useBinding(0);
	const holding = React.useRef<RBXScriptConnection>();
	const release = React.useRef<RBXScriptConnection>();
	const stop = () => {
		holding.current?.Disconnect();
		holding.current = undefined;
		release.current?.Disconnect();
		release.current = undefined;
		setFill(0);
	};
	React.useEffect(() => stop, []);
	React.useEffect(() => {
		if (!props.enabled) stop();
	}, [props.enabled]);
	const begin = (pressed: InputObject) => {
		if (!props.enabled || holding.current) return;
		Audio.play("rebirthCharge");
		const started = os.clock();
		release.current = UserInputService.InputEnded.Connect((input) => {
			if (input.UserInputType === pressed.UserInputType && input.KeyCode === pressed.KeyCode) stop();
		});
		holding.current = RunService.Heartbeat.Connect(() => {
			const amount = math.clamp((os.clock() - started) / HOLD_SECONDS, 0, 1);
			setFill(amount);
			if (amount >= 1) {
				stop();
				props.onConfirm();
			}
		});
	};
	return (
		<textbutton
			Size={new UDim2(1, 0, 0, props.phone ? HIT + 12 : 64)}
			BackgroundColor3={props.enabled ? AETHER.Lerp(Iron.sunk(), 0.6) : Iron.sunk()}
			BorderSizePixel={0}
			AutoButtonColor={false}
			Text=""
			Active={props.enabled}
			Selectable={props.enabled}
			ClipsDescendants
			LayoutOrder={9}
			Event={{
				InputBegan: (_, input) => isPress(input) && begin(input),
				InputEnded: (_, input) => {
					if (!isPress(input)) return;
					if (holding.current) Audio.play("close");
					stop();
				},
				MouseLeave: stop,
			}}
		>
			<uicorner CornerRadius={new UDim(0, 8)} />
			<uistroke Color={props.enabled ? AETHER : Iron.edge()} Transparency={0.25} Thickness={1.5} />
			<frame Size={fill.map((a) => UDim2.fromScale(a, 1))} BackgroundColor3={AETHER} BorderSizePixel={0} ZIndex={2} />
			<textlabel
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				Text={fill.map((a) => (!props.enabled ? "Not yet" : a > 0 ? "Keep holding" : "Hold to ascend"))}
				TextColor3={fill.map((a) => (a > 0.5 ? Iron.sunk() : Iron.text()))}
				TextSize={18}
				FontFace={Fonts.heavy}
				ZIndex={3}
			/>
		</textbutton>
	);
}

function SigilCard(props: { sigil: Sigil; index: number; busy: boolean; phone: boolean; harmony: number; onBuy: () => void }) {
	const { sigil, phone } = props;
	const color = SIGIL_COLORS[sigil.Id] ?? AETHER;
	const reveal = useListStagger(props.index);
	const pulse = useClock(sigil.Level > 0, 0.6, math.pi * 2);
	const flash = useFlipperSpring(sigil.Level, false, 300, 22);
	const boosted = sigil.EffectiveLevel > sigil.Level;
	return (
		<frame Size={new UDim2(phone ? 1 : 0.5, phone ? 0 : -8, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.index}>
			<uiscale Scale={reveal.map((p) => 0.97 + p * 0.03)} />
			<Card accent={color} pad={gap(phone, "l")} spacing={gap(phone, "s")}>
				<frame Size={new UDim2(1, 0, 0, 44)} BackgroundTransparency={1} LayoutOrder={0}>
					<frame Size={UDim2.fromOffset(40, 40)} BackgroundColor3={color.Lerp(Iron.sunk(), 0.72)}>
						<uicorner CornerRadius={new UDim(1, 0)} />
						<uistroke Color={color} Thickness={2} Transparency={pulse.map((a) => (sigil.Level > 0 ? 0.15 + (math.sin(a) + 1) * 0.2 : 0.6))} />
						<Text text={sigil.Level > 0 ? compactNumber(sigil.Level) : ""} size={14} font={Fonts.heavy} color={color} align="Center" box={UDim2.fromScale(1, 1)} />
					</frame>
					<Tooltip tip={sigil.Line} size={new UDim2(1, -52, 1, 0)}>
						<frame Size={UDim2.fromScale(1, 1)} Position={UDim2.fromOffset(52, 0)} BackgroundTransparency={1}>
							<Text text={sigil.Name} size={Type.body(phone) + 3} font={Fonts.heavy} box={UDim2.fromScale(1, 1)} />
						</frame>
					</Tooltip>
				</frame>
				<Text
					text={sigil.Level > 0 ? `×${compactNumber(sigil.Multiplier)} ${sigil.Effect.lower()}${boosted ? `   acts as ${compactNumber(sigil.EffectiveLevel)}` : ""}` : sigil.Line}
					size={Type.small(phone)}
					color={sigil.Level > 0 ? Iron.text() : Iron.muted()}
					order={1}
				/>
				<Button text={compactNumber(sigil.Cost)} tone={sigil.Affordable ? "brass" : "quiet"} stretch disabled={!sigil.Affordable || props.busy} glint={sigil.Affordable} onPress={props.onBuy} order={2} />
			</Card>
			<frame
				Size={UDim2.fromScale(1, 1)}
				BackgroundColor3={color}
				BackgroundTransparency={flash.map((v) => 1 - math.clamp(math.abs(v - sigil.Level), 0, 1) * 0.35)}
				BorderSizePixel={0}
				ZIndex={0}
			>
				<uicorner CornerRadius={new UDim(0, 8)} />
			</frame>
		</frame>
	);
}

export function AscensionPage(props: PageProps) {
	const phone = props.phone;
	const state = (props.session as unknown as { Ascension?: AscensionState }).Ascension;
	const [busy, setBusy] = React.useState(false);
	const space = gap(phone, "l");
	const send = (action: string, payload: Record<string, unknown>, color: Color3) => {
		if (busy) return;
		setBusy(true);
		props.request(action, payload, (reply) => {
			setBusy(false);
			if (reply.ok === true) {
				Audio.play("successChime");
				Burst.spark(color, action === "Ascend" ? 1.4 : 0.9);
				MotionFX.play(action === "Ascend" ? "milestone" : "success");
			} else {
				Audio.play("error");
			}
		});
	};
	if (!typeIs(state, "table")) {
		return (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
				<uipadding PaddingTop={new UDim(0, space)} PaddingLeft={new UDim(0, space)} PaddingRight={new UDim(0, space)} />
				<EmptyState title="Ascension" body="Opening the final door." phone={phone} />
			</frame>
		);
	}
	const outer = phone ? 52 : 72;
	const inner = phone ? 30 : 42;
	const mark = outer * 2 + 16;
	const progress = math.clamp(state.DomainRank / math.max(1, state.RequiredDomainRank), 0, 1);
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
			<uipadding PaddingTop={new UDim(0, space)} PaddingBottom={new UDim(0, space * 3 + props.chrome.bottomSafe)} PaddingLeft={new UDim(0, space)} PaddingRight={new UDim(0, space)} />
			<uilistlayout Padding={new UDim(0, gap(phone, "xl"))} SortOrder={Enum.SortOrder.LayoutOrder} />

			<Panel pad={gap(phone, "xl")} spacing={gap(phone, "l")} color={AETHER.Lerp(Iron.face(), 0.9)} seam rarity="Mythic" order={0}>
				<frame Size={new UDim2(1, 0, 0, mark)} BackgroundTransparency={1} LayoutOrder={0}>
					<frame Size={UDim2.fromOffset(mark, mark)} BackgroundTransparency={1}>
						<Orbit count={12} radius={outer} dot={6} speed={1} color={AETHER} />
						<Orbit count={7} radius={inner} dot={5} speed={-1.6} color={AETHER.Lerp(Color3.fromRGB(255, 255, 255), 0.25)} />
						<Text text={tostring(state.Rank)} size={phone ? 26 : 34} font={Fonts.heavy} align="Center" box={UDim2.fromOffset(mark, 40)} position={UDim2.fromOffset(0, mark / 2 - 20)} />
					</frame>
					<frame Size={new UDim2(1, -(mark + space), 1, 0)} Position={UDim2.fromOffset(mark + space, 0)} BackgroundTransparency={1}>
						<uilistlayout Padding={new UDim(0, 6)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
						<Title text="Ascension" size={Type.title(phone)} color={Iron.text().Lerp(AETHER, 0.3)} tags={["wave"]} order={0} />
						<Text text={`${compactNumber(state.Aether)} aether`} size={Type.body(phone) + 4} font={Fonts.heavy} color={AETHER} order={1} />
						<Text text={`×${compactNumber(state.Production)} production`} size={Type.small(phone)} color={Iron.soft()} order={2} />
					</frame>
				</frame>
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundColor3={Iron.ember()} BackgroundTransparency={0.85} BorderSizePixel={0} LayoutOrder={1}>
					<uicorner CornerRadius={new UDim(0, 6)} />
					<uipadding PaddingTop={new UDim(0, 10)} PaddingBottom={new UDim(0, 10)} PaddingLeft={new UDim(0, 12)} PaddingRight={new UDim(0, 12)} />
					<Text text={RESET_WARNING} size={Type.small(phone)} color={Iron.text()} multiline />
				</frame>
			</Panel>

			<Panel pad={gap(phone, "l")} spacing={gap(phone, "m")} seam={state.CanAscend} order={1}>
				<Text
					text={state.CanAscend ? `+${compactNumber(state.Gain)} aether` : `Domain ${state.DomainRank} of ${state.RequiredDomainRank}`}
					size={Type.title(phone)}
					font={Fonts.heavy}
					color={state.CanAscend ? AETHER : Iron.text()}
					order={0}
				/>
				<Meter value={progress} color={AETHER} height={6} order={1} />
				<Tooltip tip={state.CanAscend ? "Going further past the requirement pays more aether." : `Reach Domain rank ${state.RequiredDomainRank} to ascend.`} size={new UDim2(1, 0, 0, 20)} order={2}>
					<Text text={`next rank ×${compactNumber(state.NextRankProduction)}`} size={Type.small(phone)} color={Iron.muted()} />
				</Tooltip>
				<HoldToAscend enabled={state.CanAscend && !busy} phone={phone} onConfirm={() => send("Ascend", {}, AETHER)} />
			</Panel>

			<Tooltip
				tip={state.Harmony > 0 ? `Every started sigil acts ${state.Harmony} level${state.Harmony === 1 ? "" : "s"} higher.` : "Raise all six sigils together and each one acts higher."}
				size={new UDim2(1, 0, 0, 64)}
				order={2}
			>
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
					<Text text={`harmony ${state.Harmony}`} size={Type.small(phone)} font={Fonts.heavy} color={Iron.muted()} box={new UDim2(1, 0, 0, 18)} />
					{state.Sigils.map((sigil, i) => {
						const color = SIGIL_COLORS[sigil.Id] ?? AETHER;
						const n = math.max(1, state.Sigils.size());
						return (
							<frame
								key={sigil.Id}
								Size={new UDim2(1 / n, -8, 0, 30)}
								Position={new UDim2(i / n, 4, 0, 28)}
								BackgroundColor3={color.Lerp(Iron.sunk(), sigil.Level > state.Harmony ? 0.4 : 0.75)}
								BorderSizePixel={0}
							>
								<uicorner CornerRadius={new UDim(1, 0)} />
								<Text text={compactNumber(sigil.Level)} size={13} font={Fonts.heavy} align="Center" box={UDim2.fromScale(1, 1)} />
							</frame>
						);
					})}
				</frame>
			</Tooltip>

			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={3}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, gap(phone, "m"))} SortOrder={Enum.SortOrder.LayoutOrder} />
				{state.Sigils.map((sigil, i) => (
					<SigilCard
						key={sigil.Id}
						sigil={sigil}
						index={i}
						busy={busy}
						phone={phone}
						harmony={state.Harmony}
						onBuy={() => send("UpgradeSigil", { Id: sigil.Id }, SIGIL_COLORS[sigil.Id] ?? AETHER)}
					/>
				))}
			</frame>

		</scrollingframe>
	);
}

// Echoes, rebuilt on Forge2. The loom fills as you play (four tracks feed one charge); a full charge
// strikes three echoes and you keep one. Up to four ride in the chord. The rest wait in the vault to
// be tuned, fused, locked or broken for resonance, and the journal remembers every tier you've held.
// Every number comes from the server snapshot or EchoMath, so previews match what you get.
// Remote: EchoAct {Op: Strike | Reroll | Keep{Choice} | Slot{Slot,Uid} | Tune{Uid} | Fuse{A,B} | Lock{Uid} | Dismantle{Uid}}
import React from "@rbxts/react";
import { Audio } from "../../AudioKit/audio";
import { compactNumber } from "../../CoreKit/format";
import { useChangePop, useClock, useListStagger, usePulse, useSpring } from "../../MotionKit/motion";
import EchoMath = require("../../../../Shared/AstralForge/Shared/EchoMath");
import { ForgeButton as Button } from "../design/ForgeButton";
import { EmptyState, Modal, Tooltip } from "../design/Layers";
import { Card, Meter, Panel } from "../design/Panel";
import { Text, Title } from "../design/Text";
import { Fonts, gap, HIT, Iron, Type } from "../design/tokens";
import { Burst, MotionFX } from "../motion/motion";
import { useBack } from "../input/input";
import type { PageProps } from "../router/routes";

interface Choice {
	Trait: string;
	Tier: string;
	Level: number;
	Imprints?: string[];
}
interface Owned extends Choice {
	Uid: string;
	Locked: boolean;
	Effects: Record<string, number>;
	TuneCost: number;
	Resonance: number;
}
interface Slot {
	Slot: number;
	Open: boolean;
	Uid: string;
	NeedsCaptures: number;
}
interface EchoState {
	Charge: number;
	ChargeTarget: number;
	Ready: boolean;
	Tracks: Record<string, number>;
	Dominant?: string;
	Resonance: number;
	Captures: number;
	Draft: Choice[];
	Rerolled: boolean;
	Inventory: Owned[];
	InventoryLimit: number;
	Chord: Slot[];
	Bonuses?: { Harmony?: boolean; Unison?: boolean; Spectrum?: boolean };
	Totals?: Record<string, number>;
	Journal?: Record<string, number>;
	Odds?: Record<string, number>;
}

const TIER_COLOR: Record<string, () => Color3> = { Faint: Iron.muted, Clear: Iron.steel, Vivid: Iron.ember, Perfect: Iron.brass };
const TRACK: Record<string, { word: string; color: () => Color3 }> = {
	Collect: { word: "collecting", color: Iron.steel },
	Surge: { word: "overcharging", color: Iron.ember },
	Build: { word: "building", color: Iron.brass },
	Explore: { word: "exploring", color: Iron.soft },
};
const KIND_WORDS: Record<string, string> = {
	Production: "production",
	Capacity: "vault",
	Tap: "overcharge",
	Critical: "crit chance",
	Automation: "auto-collect",
	Offline: "offline",
};

function pct(value: number): string {
	const p = value * 100;
	return p >= 10 ? "+%d%%".format(math.floor(p + 0.5)) : "+%.1f%%".format(p);
}

function tierColor(tier: string): Color3 {
	return (TIER_COLOR[tier] ?? Iron.muted)();
}

function effectLine(effects: Record<string, number> | undefined): string {
	const parts: string[] = [];
	for (const kind of EchoMath.KINDS) {
		const v = effects?.[kind] ?? 0;
		if (v > 0) parts.push(`${pct(v)} ${KIND_WORDS[kind] ?? kind.lower()}`);
	}
	return parts.join("   ");
}

function choiceEffects(choice: Choice): Record<string, number> {
	const [ok, out] = pcall(() =>
		EchoMath.effects({ Trait: choice.Trait, Tier: choice.Tier, Level: choice.Level ?? 1, Imprints: choice.Imprints ?? [], Locked: false }),
	);
	return ok ? out : {};
}

// ---------------------------------------------------------------------------------------------

function Loom(props: { state: EchoState; phone: boolean; draftOpen: boolean; full: boolean; busy: boolean; onStrike: () => void; order: number }) {
	const { state, phone } = props;
	const fill = math.clamp(state.Charge / math.max(1, state.ChargeTarget), 0, 1);
	const shown = useSpring(fill, false, 120, 18, 0);
	const ready = state.Ready && !props.draftOpen && !props.full;
	const thrum = usePulse(ready, 1.2);
	const spin = useClock(ready, 0.35);
	const odds = state.Odds ?? {};
	const oddsTip = EchoMath.TIERS.map((t) => `${t} ${math.floor((odds[t] ?? 0) * 100 + 0.5)}%`).join("   ");
	const ring = phone ? 120 : 160;
	const ticks: React.Element[] = [];
	const TICKS = 28;
	for (let i = 0; i < TICKS; i++) {
		const at = (i + 0.5) / TICKS;
		ticks.push(
			<frame
				key={`t${i}`}
				Size={UDim2.fromOffset(4, 12)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Position={spin.map((a) => {
					const angle = -math.pi / 2 + (i / TICKS) * math.pi * 2 + (ready ? a * 0.15 : 0);
					return new UDim2(0.5, math.cos(angle) * (ring / 2 - 8), 0.5, math.sin(angle) * (ring / 2 - 8));
				})}
				Rotation={(i / TICKS) * 360}
				BackgroundColor3={Iron.brass()}
				BackgroundTransparency={shown.map((v) => (v >= at ? 0 : 0.8))}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>,
		);
	}
	return (
		<Panel pad={gap(phone, "xl")} spacing={gap(phone, "l")} seam={ready} rarity="Mythic" order={props.order}>
			<frame Size={new UDim2(1, 0, 0, ring)} BackgroundTransparency={1} LayoutOrder={0}>
				<Tooltip tip={`Strike odds: ${oddsTip}. Resonance improves them.`} size={UDim2.fromOffset(ring, ring)}>
					{ticks}
					<frame Size={UDim2.fromOffset(ring - 40, ring - 40)} AnchorPoint={new Vector2(0.5, 0.5)} Position={UDim2.fromScale(0.5, 0.5)} BackgroundColor3={Iron.sunk()}>
						<uicorner CornerRadius={new UDim(1, 0)} />
						<uistroke Color={Iron.brass()} Thickness={2} Transparency={ready ? thrum.map((a) => 0.1 + a * 0.6) : 0.7} />
						<Text text={`${math.floor(fill * 100)}`} size={phone ? 30 : 40} font={Fonts.heavy} align="Center" color={ready ? Iron.brass() : Iron.text()} box={UDim2.fromScale(1, 1)} />
					</frame>
				</Tooltip>
				<frame Size={new UDim2(1, -(ring + gap(phone, "l")), 1, 0)} Position={UDim2.fromOffset(ring + gap(phone, "l"), 0)} BackgroundTransparency={1}>
					<uilistlayout Padding={new UDim(0, phone ? 6 : 10)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
					{EchoMath.TRACKS.map((track, i) => {
						const art = TRACK[track];
						const value = state.Tracks[track] ?? 0;
						const lead = state.Dominant === track;
						return (
							<frame key={track} Size={new UDim2(1, 0, 0, phone ? 22 : 26)} BackgroundTransparency={1} LayoutOrder={i}>
								<Text text={art.word} size={Type.small(phone)} color={lead ? art.color() : Iron.muted()} font={lead ? Fonts.heavy : Fonts.bold} box={new UDim2(1, 0, 0, 14)} />
								<frame Size={new UDim2(1, 0, 0, 4)} Position={new UDim2(0, 0, 1, -4)} BackgroundTransparency={1}>
									<Meter value={value / math.max(1, state.ChargeTarget)} color={art.color()} height={4} />
								</frame>
							</frame>
						);
					})}
				</frame>
			</frame>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 12)} SortOrder={Enum.SortOrder.LayoutOrder} VerticalAlignment={Enum.VerticalAlignment.Center} />
				<Button
					text={props.full ? "Vault full" : props.draftOpen ? "Keep one first" : state.Ready ? "Strike" : "Charging"}
					tone={ready ? "ember" : "quiet"}
					width={phone ? 160 : 200}
					height={phone ? 52 : 56}
					disabled={!ready}
					busy={props.busy}
					glint={ready}
					onPress={props.onStrike}
					order={0}
				/>
				<Tooltip tip="Resonance: from broken echoes. Better strikes and rerolls." size={UDim2.fromOffset(phone ? 110 : 140, HIT)} order={1}>
					<Text text={`${compactNumber(state.Resonance)} res`} size={Type.body(phone)} font={Fonts.heavy} color={Iron.soft()} box={UDim2.fromScale(1, 1)} />
				</Tooltip>
			</frame>
		</Panel>
	);
}

function DraftCard(props: { choice: Choice; index: number; phone: boolean; disabled: boolean; onKeep: () => void }) {
	const { choice, phone } = props;
	const reveal = useListStagger(props.index);
	const def = EchoMath.trait(choice.Trait);
	const color = tierColor(choice.Tier);
	const shimmer = usePulse(choice.Tier === "Perfect" || choice.Tier === "Vivid", 1.4);
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.index}>
			<uiscale Scale={reveal.map((p) => 0.9 + p * 0.1)} />
			<Card accent={color} pad={gap(phone, "l")} spacing={gap(phone, "s")} seam={choice.Tier === "Perfect"} rarity={choice.Tier === "Perfect" ? "Mythic" : undefined}>
				<frame Size={new UDim2(1, 0, 0, Type.title(phone) + 10)} BackgroundTransparency={1} LayoutOrder={0}>
					<Title text={def?.Name ?? choice.Trait} size={Type.title(phone)} color={Iron.text().Lerp(color, 0.3)} />
				</frame>
				<textlabel
					Size={new UDim2(1, 0, 0, 18)}
					BackgroundTransparency={1}
					Text={choice.Tier.lower()}
					FontFace={Fonts.heavy}
					TextColor3={color}
					TextTransparency={shimmer.map((a) => a * 0.35)}
					TextSize={Type.small(phone) + 1}
					TextXAlignment={Enum.TextXAlignment.Left}
					LayoutOrder={1}
				/>
				<Text text={effectLine(choiceEffects(choice))} size={Type.small(phone)} color={Iron.soft()} multiline order={2} />
				{def !== undefined && <Text text={def.Line} size={Type.small(phone)} color={Iron.muted()} multiline order={3} />}
				<Button text="Keep" stretch disabled={props.disabled} onPress={props.onKeep} order={4} />
			</Card>
		</frame>
	);
}

function ChordSlot(props: { slot: Slot; echo?: Owned; slotting: boolean; phone: boolean; order: number; onPress: () => void }) {
	const { slot, echo, phone } = props;
	const def = echo !== undefined ? EchoMath.trait(echo.Trait) : undefined;
	const color = echo !== undefined ? tierColor(echo.Tier) : Iron.edge();
	const invite = usePulse(props.slotting && slot.Open, 2);
	const pop = useChangePop(echo?.Uid ?? "");
	const size = phone ? 64 : 84;
	return (
		<frame Size={UDim2.fromOffset(size + 16, size + 30)} BackgroundTransparency={1} LayoutOrder={props.order}>
			<textbutton
				Size={UDim2.fromOffset(size, size)}
				Position={UDim2.fromOffset(8, 0)}
				BackgroundColor3={echo !== undefined ? color : Iron.sunk()}
				BackgroundTransparency={echo !== undefined ? 0.15 : 0.3}
				Text={!slot.Open ? `${slot.NeedsCaptures}` : echo !== undefined ? (def?.Name ?? "").sub(1, 1) : ""}
				FontFace={Fonts.heavy}
				TextColor3={echo !== undefined ? Iron.sunk() : Iron.muted()}
				TextSize={phone ? 24 : 30}
				AutoButtonColor={false}
				Active={slot.Open}
				Selectable={slot.Open}
				Event={{ Activated: () => slot.Open && props.onPress() }}
			>
				<uiscale Scale={pop} />
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke
					Color={props.slotting && slot.Open ? Iron.brass() : color}
					Thickness={2}
					Transparency={props.slotting && slot.Open ? invite.map((a) => a * 0.7) : slot.Open ? 0.3 : 0.75}
				/>
			</textbutton>
			<Text
				text={!slot.Open ? "captures" : echo !== undefined ? `${def?.Name ?? echo.Trait}` : props.slotting ? "here" : "empty"}
				size={Type.small(phone) - 1}
				color={Iron.muted()}
				align="Center"
				box={new UDim2(1, 0, 0, 16)}
				position={UDim2.fromOffset(0, size + 8)}
			/>
		</frame>
	);
}

function VaultCard(props: {
	echo: Owned;
	index: number;
	partner?: Owned;
	stardust: number;
	inChord: boolean;
	phone: boolean;
	onAct: (payload: Record<string, unknown>) => void;
	onSlot: () => void;
	onBreak: () => void;
}) {
	const { echo, phone } = props;
	const reveal = useListStagger(props.index);
	const def = EchoMath.trait(echo.Trait);
	const color = tierColor(echo.Tier);
	const maxed = echo.Level >= EchoMath.MAX_LEVEL;
	const canTune = !maxed && props.stardust >= echo.TuneCost;
	const upcoming = EchoMath.nextTier(echo.Tier);
	const canFuse = props.partner !== undefined && upcoming !== undefined && !echo.Locked && !props.partner.Locked;
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.index}>
			<uiscale Scale={reveal.map((p) => 0.97 + p * 0.03)} />
			<Card accent={color} selected={props.inChord} pad={gap(phone, "l")} spacing={gap(phone, "s")}>
				<frame Size={new UDim2(1, 0, 0, Type.body(phone) + 8)} BackgroundTransparency={1} LayoutOrder={0}>
					<Text text={def?.Name ?? echo.Trait} size={Type.body(phone) + 2} font={Fonts.heavy} color={Iron.text().Lerp(color, 0.25)} box={new UDim2(1, -110, 1, 0)} />
					<Text
						text={`${echo.Tier.lower()}  ${echo.Level}${echo.Locked ? "  locked" : ""}`}
						size={Type.small(phone)}
						font={Fonts.heavy}
						color={color}
						align="Right"
						box={new UDim2(0, 110, 1, 0)}
						position={new UDim2(1, -110, 0, 0)}
					/>
				</frame>
				<Text text={effectLine(echo.Effects)} size={Type.small(phone)} color={Iron.soft()} multiline order={1} />
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
					<Button text={props.inChord ? "In chord" : "Chord"} tone="iron" width={110} disabled={props.inChord} onPress={props.onSlot} order={0} />
					<Button
						text={maxed ? "Tuned" : `Tune ${compactNumber(echo.TuneCost)}`}
						tone="iron"
						width={130}
						disabled={!canTune}
						onPress={() => props.onAct({ Op: "Tune", Uid: echo.Uid })}
						order={1}
					/>
					{props.partner !== undefined && upcoming !== undefined && (
						<Button text={`Fuse to ${upcoming.lower()}`} width={150} disabled={!canFuse} onPress={() => props.onAct({ Op: "Fuse", A: echo.Uid, B: props.partner!.Uid })} order={2} />
					)}
					<Button text={echo.Locked ? "Unlock" : "Lock"} tone="quiet" width={100} onPress={() => props.onAct({ Op: "Lock", Uid: echo.Uid })} order={3} />
					{!echo.Locked && <Button text={`Break +${echo.Resonance}`} tone="quiet" width={130} onPress={props.onBreak} order={4} />}
				</frame>
			</Card>
		</frame>
	);
}

// ---------------------------------------------------------------------------------------------

export function EchoesPage(props: PageProps) {
	const phone = props.phone;
	const session = props.session as unknown as { ForgeEchoes?: EchoState; Stardust?: unknown };
	const state = session.ForgeEchoes;
	const [slotting, setSlotting] = React.useState<string>();
	const [breaking, setBreaking] = React.useState<Owned>();
	const [sending, setSending] = React.useState(false);
	useBack(slotting !== undefined, () => setSlotting(undefined));
	const space = gap(phone, "l");

	const act = (payload: Record<string, unknown>) => {
		if (sending) return;
		setSending(true);
		const op = payload.Op as string;
		props.request("EchoAct", payload, (reply) => {
			setSending(false);
			if (reply.ok !== true) {
				Audio.play("error");
				return;
			}
			if (op === "Strike" || op === "Reroll") {
				Audio.play("rebirthCharge");
				MotionFX.play("milestone");
				Burst.spark(Iron.brass(), 1.2);
			} else if (op === "Keep") {
				Audio.play("successChime");
				MotionFX.play("success");
			} else if (op === "Fuse") {
				Audio.play("successChime");
				Burst.spark(tierColor(tostring(reply.Tier ?? "Clear")), 1.2);
				MotionFX.play("success");
			} else if (op === "Tune") {
				Burst.spark(Iron.steel(), 0.7);
			} else if (op === "Dismantle") {
				Audio.play("vaultBank");
			} else if (op === "Slot") {
				MotionFX.play("confirm");
			}
		});
	};

	if (state === undefined || state.Inventory === undefined) {
		return (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
				<uipadding PaddingTop={new UDim(0, space)} PaddingLeft={new UDim(0, space)} PaddingRight={new UDim(0, space)} />
				<EmptyState title="Echoes" body="They open later in the game. Keep forging." phone={phone} action={{ text: "Back to the forge", onPress: () => props.navigate("Overview") }} />
			</frame>
		);
	}

	const byUid: Record<string, Owned> = {};
	for (const echo of state.Inventory) byUid[echo.Uid] = echo;
	const chordUids = new Set<string>();
	for (const slot of state.Chord) if (slot.Open && slot.Uid !== "") chordUids.add(slot.Uid);
	const draftOpen = state.Draft.size() > 0;
	const full = state.Inventory.size() >= state.InventoryLimit;
	const stardust = tonumber(session.Stardust) ?? 0;
	const bonuses: string[] = [];
	if (state.Bonuses?.Harmony) bonuses.push(`Harmony +${math.floor(EchoMath.HARMONY * 100)}%`);
	if (state.Bonuses?.Unison) bonuses.push(`Unison +${math.floor(EchoMath.UNISON * 100)}%`);
	if (state.Bonuses?.Spectrum) bonuses.push(`Spectrum +${math.floor(EchoMath.SPECTRUM * 100)}%`);
	const totals = effectLine(state.Totals);

	const partnerOf = (echo: Owned) => state.Inventory.find((o) => o.Uid !== echo.Uid && o.Trait === echo.Trait && o.Tier === echo.Tier);

	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
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

				<Loom state={state} phone={phone} draftOpen={draftOpen} full={full} busy={sending} onStrike={() => act({ Op: "Strike" })} order={0} />

				{draftOpen && (
					<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
						<uilistlayout Padding={new UDim(0, gap(phone, "m"))} SortOrder={Enum.SortOrder.LayoutOrder} />
						<Title text="Keep one" size={Type.title(phone)} tags={["wave"]} order={0} />
						<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
							<uilistlayout Padding={new UDim(0, gap(phone, "m"))} SortOrder={Enum.SortOrder.LayoutOrder} />
							{state.Draft.map((choice, i) => (
								<DraftCard key={`d${i}`} choice={choice} index={i} phone={phone} disabled={sending || full} onKeep={() => act({ Op: "Keep", Choice: i + 1 })} />
							))}
						</frame>
						<Button
							text={state.Rerolled ? "Rerolled" : `Reroll  ${EchoMath.REROLL_RESONANCE} res`}
							tone="iron"
							stretch
							disabled={state.Rerolled || state.Resonance < EchoMath.REROLL_RESONANCE || sending}
							onPress={() => act({ Op: "Reroll" })}
							order={2}
						/>
					</frame>
				)}

				<Panel pad={gap(phone, "l")} spacing={gap(phone, "m")} order={2} seam={bonuses.size() > 0}>
					<Title text="Chord" size={Type.title(phone)} order={0} />
					<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
						<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 4)} SortOrder={Enum.SortOrder.LayoutOrder} />
						{state.Chord.map((slot) => (
							<ChordSlot
								key={`s${slot.Slot}`}
								slot={slot}
								echo={slot.Uid !== "" ? byUid[slot.Uid] : undefined}
								slotting={slotting !== undefined}
								phone={phone}
								order={slot.Slot}
								onPress={() => {
									if (slotting !== undefined) {
										act({ Op: "Slot", Slot: slot.Slot, Uid: slotting });
										setSlotting(undefined);
									} else if (slot.Uid !== "") {
										act({ Op: "Slot", Slot: slot.Slot, Uid: "" });
									}
								}}
							/>
						))}
					</frame>
					{bonuses.size() > 0 && <Text text={bonuses.join("     ")} size={Type.body(phone)} font={Fonts.heavy} color={Iron.brass()} order={2} />}
					{totals !== "" && <Text text={totals} size={Type.small(phone)} color={Iron.soft()} multiline order={3} />}
					{slotting !== undefined && <Button text="Cancel" tone="quiet" width={120} onPress={() => setSlotting(undefined)} order={4} />}
				</Panel>

				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={3}>
					<uilistlayout Padding={new UDim(0, gap(phone, "m"))} SortOrder={Enum.SortOrder.LayoutOrder} />
					<frame Size={new UDim2(1, 0, 0, Type.title(phone) + 10)} BackgroundTransparency={1} LayoutOrder={0}>
						<frame Size={new UDim2(1, -90, 1, 0)} BackgroundTransparency={1}>
							<Title text="Vault" size={Type.title(phone)} />
						</frame>
						<Text
							text={`${state.Inventory.size()}/${state.InventoryLimit}`}
							size={Type.body(phone)}
							font={Fonts.heavy}
							color={full ? Iron.ember() : Iron.muted()}
							align="Right"
							box={new UDim2(0, 90, 1, 0)}
							position={new UDim2(1, -90, 0, 0)}
						/>
					</frame>
					{state.Inventory.size() === 0 ? (
						<EmptyState title="Nothing kept yet" body="Fill the loom and strike." phone={phone} order={1} />
					) : (
						state.Inventory.map((echo, i) => (
							<VaultCard
								key={echo.Uid}
								echo={echo}
								index={i + 1}
								partner={partnerOf(echo)}
								stardust={stardust}
								inChord={chordUids.has(echo.Uid)}
								phone={phone}
								onAct={act}
								onSlot={() => setSlotting(echo.Uid)}
								onBreak={() => setBreaking(echo)}
							/>
						))
					)}
				</frame>

				<Panel pad={gap(phone, "l")} spacing={gap(phone, "s")} order={4}>
					<Tooltip tip={`Hold a trait at every tier for a permanent +${math.floor(EchoMath.JOURNAL_BONUS * 100)}% to what it does.`} size={new UDim2(1, 0, 0, Type.title(phone) + 10)} order={0}>
						<Title text="Journal" size={Type.title(phone)} />
					</Tooltip>
					{EchoMath.TRAITS.map((t, i) => {
						const reached = tonumber(state.Journal?.[t.Id]) ?? 0;
						const done = reached >= EchoMath.TIERS.size();
						return (
							<frame key={t.Id} Size={new UDim2(1, 0, 0, 26)} BackgroundTransparency={1} LayoutOrder={i + 1}>
								<Text text={t.Name} size={Type.small(phone) + 1} color={done ? Iron.brass() : reached > 0 ? Iron.text() : Iron.muted()} font={done ? Fonts.heavy : Fonts.bold} box={new UDim2(1, -96, 1, 0)} />
								{EchoMath.TIERS.map((tier, k) => (
									<frame
										key={tier}
										Size={UDim2.fromOffset(14, 14)}
										Position={new UDim2(1, -96 + k * 24, 0.5, -7)}
										BackgroundColor3={tierColor(tier)}
										BackgroundTransparency={k < reached ? 0 : 0.85}
									>
										<uicorner CornerRadius={new UDim(1, 0)} />
									</frame>
								))}
							</frame>
						);
					})}
				</Panel>
			</scrollingframe>

			<Modal open={breaking !== undefined} title="Break this echo?" onClose={() => setBreaking(undefined)} phone={phone}>
				<Text text={`It's gone for good. You get ${breaking?.Resonance ?? 0} resonance back.`} size={Type.body(phone)} color={Iron.soft()} multiline order={0} />
				<Button
					text="Break"
					tone="ember"
					stretch
					onPress={() => {
						const uid = breaking?.Uid;
						setBreaking(undefined);
						if (uid !== undefined) act({ Op: "Dismantle", Uid: uid });
					}}
					order={1}
				/>
			</Modal>
		</frame>
	);
}

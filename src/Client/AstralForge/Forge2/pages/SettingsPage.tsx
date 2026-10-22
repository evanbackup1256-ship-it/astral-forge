// Settings, rebuilt on Forge2 from the shared SettingsSchema: six sections (Phone only on touch),
// search across all of them, a "changed" view with reset-all, per-section reset, Graphics presets,
// advanced rows behind a toggle, the phone tab-bar pins, profile style (accent, frame, crate skin),
// Tour / Notes, and the controller map. Every change persists through the same remotes:
// SetSetting {Key, Value} / {Values, Label}, SetMobileLayout {Pins}, SetProfileStyle {Accent, Frame},
// EquipCrateSkin {Id}, ReplayTutorial, OpenRelease.
// The switch, slider and segmented control keep the current client's springs and timings.
import React from "@rbxts/react";
import { Audio } from "../../AudioKit/audio";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import * as NavRouteTable from "../../CoreKit/navRouteTable";
import { frameStroke } from "../../CoreKit/profileFrame";
import { readSetting } from "../../CoreKit/settingsService";
import { useFlipperSpring, useListStagger, useStagger, useViewport } from "../../MotionKit/motion";
import { SegmentedTabs, Slider } from "../../UiCore/ui";
import Schema = require("../../../../Shared/AstralForge/Shared/SharedData/SettingsSchema");
import ShopCatalog = require("../../../../Shared/AstralForge/Shared/SharedData/ShopCatalog");
import * as NavRoutes from "../../../../Shared/AstralForge/Shared/NavRoutes";
import * as ProfileStyle from "../../../../Shared/AstralForge/Shared/ProfileStyle";
import { PressButton as Button } from "../design/PressButton";
import { Panel } from "../design/Panel";
import { Chip, Tab } from "../design/Pick";
import { Text, Title } from "../design/Text";
import { Corner, Fonts, gap, HIT, Iron, Type } from "../design/tokens";
import { MotionFX } from "../motion/motion";
import type { PageProps } from "../router/routes";

const UserInputService = game.GetService("UserInputService");

type Entry = (typeof Schema.ENTRIES)[number];
type Section = (typeof Schema.SECTIONS)[number];
type Bag = Record<string, unknown>;
const labelOf = (id: string) => NavRouteTable.find(id)?.label ?? id;

// ── the forge switch: one spring drives track, halo, knob stretch and glyph (old timings) ─────

const SW_W = 58;
const SW_H = 30;
const KNOB = 22;
const SW_PAD = 4;

function Switch(props: { on: boolean; onToggle: () => void }) {
	const amount = useFlipperSpring(props.on ? 1 : 0, false, 380, 24);
	const [hovered, setHovered] = React.useState(false);
	const [pressed, setPressed] = React.useState(false);
	const hover = useFlipperSpring(hovered ? 1 : 0, false, 700, 40);
	const press = useFlipperSpring(pressed ? 1 : 0, false, 1000, 42);
	const motion = React.joinBindings([amount, press]);
	const travel = SW_W - SW_PAD * 2 - KNOB;
	const settle = (a: number) => math.clamp(a, 0, 1);
	const accent = Iron.brass();
	return (
		<textbutton
			Size={UDim2.fromOffset(SW_W + 10, HIT)}
			BackgroundTransparency={1}
			AutoButtonColor={false}
			Text=""
			Selectable
			Event={{
				Activated: () => {
					Audio.play(props.on ? "toggleOff" : "toggleOn");
					props.onToggle();
				},
				MouseEnter: () => setHovered(true),
				MouseLeave: () => {
					setHovered(false);
					setPressed(false);
				},
				SelectionGained: () => setHovered(true),
				SelectionLost: () => setHovered(false),
				MouseButton1Down: () => setPressed(true),
				MouseButton1Up: () => setPressed(false),
			}}
		>
			<frame Size={UDim2.fromOffset(SW_W + 8, SW_H + 8)} Position={new UDim2(1, 4, 0.5, 0)} AnchorPoint={new Vector2(1, 0.5)} BackgroundColor3={accent} BackgroundTransparency={amount.map((a) => 1 - 0.16 * settle(a))} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
			<frame Size={UDim2.fromOffset(SW_W, SW_H)} Position={UDim2.fromScale(1, 0.5)} AnchorPoint={new Vector2(1, 0.5)} BackgroundColor3={amount.map((a) => Iron.face().Lerp(accent, settle(a)))} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uigradient Rotation={90} Transparency={new NumberSequence([new NumberSequenceKeypoint(0, 0), new NumberSequenceKeypoint(1, 0.18)])} />
				<uistroke ApplyStrokeMode={Enum.ApplyStrokeMode.Border} Color={amount.map((a) => Iron.edge().Lerp(accent, settle(a)))} Transparency={hover.map((h) => 0.4 - 0.32 * math.clamp(h, 0, 1))} />
				<frame
					Size={motion.map(([a, pr]) => {
						const p = math.clamp(pr, 0, 1);
						const stretch = math.sin(math.pi * settle(a)) * 9;
						return UDim2.fromOffset(KNOB + stretch + p * 5, KNOB - p * 3);
					})}
					Position={amount.map((a) => new UDim2(0, SW_PAD + KNOB / 2 + math.clamp(a, -0.08, 1.08) * travel, 0.5, 0))}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundColor3={amount.map((a) => Iron.soft().Lerp(Iron.text(), settle(a)))}
					BorderSizePixel={0}
					ZIndex={2}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
					<frame Size={UDim2.fromOffset(8, 2)} Position={UDim2.fromScale(0.5, 0.5)} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundColor3={Iron.face()} BackgroundTransparency={amount.map((a) => 0.25 + 0.75 * settle(a))} BorderSizePixel={0} ZIndex={3} />
					<frame
						Size={amount.map((a) => UDim2.fromOffset(4 + 4 * settle(a), 4 + 4 * settle(a)))}
						Position={UDim2.fromScale(0.5, 0.5)}
						AnchorPoint={new Vector2(0.5, 0.5)}
						BackgroundColor3={accent}
						BackgroundTransparency={amount.map((a) => 1 - settle(a))}
						BorderSizePixel={0}
						ZIndex={3}
					>
						<uicorner CornerRadius={new UDim(1, 0)} />
					</frame>
				</frame>
			</frame>
		</textbutton>
	);
}

// ── one setting ──────────────────────────────────────────────────────────────────────────────

function SettingRow(props: { entry: Entry; value: number; tag?: string; phone: boolean; index: number; request: PageProps["request"] }) {
	const { entry, phone } = props;
	const [draft, setDraft] = React.useState(props.value);
	React.useEffect(() => setDraft(props.value), [props.value]);
	const rise = useListStagger(props.index);
	const commit = (value: number) => {
		setDraft(value);
		props.request("SetSetting", { Key: entry.key, Value: value });
	};
	let control: React.Element;
	if (entry.kind === "toggle") {
		control = <Switch on={draft >= 0.5} onToggle={() => commit(draft >= 0.5 ? 0 : 1)} />;
	} else if (entry.kind === "choice") {
		const choices = entry.choices ?? [];
		let picked: string | undefined;
		const options = choices.map((choice, i) => {
			if (math.abs(choice.value - draft) < 0.02) picked = tostring(i + 1);
			return { id: tostring(i + 1), label: choice.label };
		});
		control = (
			<frame Size={phone ? new UDim2(1, 0, 0, HIT) : UDim2.fromOffset(math.min(280, 64 * choices.size()), HIT)} BackgroundTransparency={1}>
				<SegmentedTabs
					options={options}
					value={picked}
					accent={Iron.brass()}
					gap={4}
					size={UDim2.fromScale(1, 1)}
					onChange={(id: string) => {
						const choice = choices[(tonumber(id) ?? 0) - 1];
						if (choice !== undefined && id !== picked) commit(choice.value);
					}}
				/>
			</frame>
		);
	} else {
		control = (
			<frame Size={phone ? new UDim2(1, 0, 0, HIT) : UDim2.fromOffset(260, 32)} BackgroundTransparency={1}>
				<Slider value={draft} accent={Iron.brass()} size={new UDim2(1, -52, 1, 0)} onChange={setDraft} onCommit={commit} />
				<Text text={`${math.floor(draft * 100 + 0.5)}%`} size={13} color={Iron.soft()} align="Right" box={new UDim2(0, 46, 1, 0)} position={new UDim2(1, -46, 0, 0)} />
			</frame>
		);
	}
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.index}>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} Position={rise.map((p) => UDim2.fromOffset(0, (1 - p) * 8))}>
				<uipadding PaddingTop={new UDim(0, 10)} PaddingBottom={new UDim(0, 10)} />
				<uilistlayout
					FillDirection={phone ? Enum.FillDirection.Vertical : Enum.FillDirection.Horizontal}
					VerticalAlignment={Enum.VerticalAlignment.Center}
					Padding={new UDim(0, 8)}
					SortOrder={Enum.SortOrder.LayoutOrder}
				/>
				<frame Size={new UDim2(1, phone ? 0 : -300, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0}>
					<uilistlayout Padding={new UDim(0, 2)} SortOrder={Enum.SortOrder.LayoutOrder} />
					<Text text={entry.label} size={Type.body(phone)} order={0} />
					{props.tag !== undefined && <Text text={props.tag} size={Type.small(phone)} color={Iron.brass()} order={1} />}
				</frame>
				<frame Size={new UDim2(phone ? 1 : 0, phone ? 0 : 290, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
					<uilistlayout HorizontalAlignment={phone ? Enum.HorizontalAlignment.Left : Enum.HorizontalAlignment.Right} SortOrder={Enum.SortOrder.LayoutOrder} />
					{control}
				</frame>
			</frame>
			<frame Size={new UDim2(1, 0, 0, 1)} Position={new UDim2(0, 0, 1, 0)} BackgroundColor3={Iron.edge()} BackgroundTransparency={0.75} BorderSizePixel={0} />
		</frame>
	);
}

// ── phone tab bar pins ───────────────────────────────────────────────────────────────────────

function TabPins(props: { saved: unknown; phone: boolean; request: PageProps["request"]; order: number }) {
	const pins = NavRoutes.normalizeMobileTabPins(props.saved);
	const [selected, setSelected] = React.useState<string | undefined>(undefined);
	const [group, setGroup] = React.useState(NavRouteTable.NAV_GROUPS[0].key);
	const chosen = selected !== undefined && pins.includes(selected) ? selected : undefined;
	const full = pins.size() >= NavRoutes.MAX_MOBILE_TAB_PINS;
	const save = (updated: string[]) => props.request("SetMobileLayout", { Pins: updated });
	const move = (delta: number) => {
		if (chosen === undefined) return;
		const from = pins.indexOf(chosen);
		const to = math.clamp(from + delta, 0, pins.size() - 1);
		if (to === from) return;
		const updated = table.clone(pins);
		updated[from] = updated[to];
		updated[to] = chosen;
		save(updated);
	};
	const ids = (NavRouteTable.NAV_GROUPS.find((g) => g.key === group)?.routes ?? []).filter((id) => NavRoutes.isNavId(id));
	const slotW = new UDim2(1 / NavRoutes.MAX_MOBILE_TAB_PINS, -6, 0, HIT);
	const slots: React.Element[] = [];
	for (let i = 0; i < NavRoutes.MAX_MOBILE_TAB_PINS; i++) {
		const id = pins[i];
		slots.push(
			id !== undefined ? (
				<frame key={`p${i}`} Size={slotW} BackgroundTransparency={1} LayoutOrder={i}>
					<Button text={labelOf(id)} tone={chosen === id ? "brass" : "iron"} onPress={() => setSelected(chosen === id ? undefined : id)} stretch textSize={14} />
				</frame>
			) : (
				<frame key={`p${i}`} Size={slotW} BackgroundColor3={Iron.sunk()} BackgroundTransparency={0.4} BorderSizePixel={0} LayoutOrder={i}>
					<uicorner CornerRadius={new UDim(0, Corner.card)} />
					<uistroke Color={Iron.edge()} Transparency={0.55} />
				</frame>
			),
		);
	}
	const third = new UDim2(1 / 3, -6, 0, HIT);
	return (
		<Panel pad={gap(props.phone, "l")} spacing={gap(props.phone, "m")} order={props.order} color={Iron.sunk()}>
			<Title text={`Tab bar  ${pins.size()}/${NavRoutes.MAX_MOBILE_TAB_PINS}`} size={Type.body(props.phone) + 3} order={0} />
			<frame Size={new UDim2(1, 0, 0, HIT)} BackgroundTransparency={1} LayoutOrder={1}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 6)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{slots}
			</frame>
			<frame Size={new UDim2(1, 0, 0, HIT)} BackgroundTransparency={1} LayoutOrder={2}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 6)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<frame Size={third} BackgroundTransparency={1} LayoutOrder={0}>
					<Button text="◀" tone="iron" onPress={() => move(-1)} disabled={chosen === undefined || pins.indexOf(chosen) === 0} stretch />
				</frame>
				<frame Size={third} BackgroundTransparency={1} LayoutOrder={1}>
					<Button text="▶" tone="iron" onPress={() => move(1)} disabled={chosen === undefined || pins.indexOf(chosen) === pins.size() - 1} stretch />
				</frame>
				<frame Size={third} BackgroundTransparency={1} LayoutOrder={2}>
					<Button
						text="Unpin"
						tone="ember"
						onPress={() => {
							if (chosen === undefined) return;
							save(pins.filter((id) => id !== chosen));
							setSelected(undefined);
						}}
						disabled={chosen === undefined}
						stretch
					/>
				</frame>
			</frame>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={3}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 6)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{NavRouteTable.NAV_GROUPS.map((g, i) => (
					<Chip key={g.key} text={g.label} on={group === g.key} onPress={() => setGroup(g.key)} order={i} />
				))}
			</frame>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={4}>
				<uigridlayout CellSize={new UDim2(props.phone ? 0.5 : 1 / 3, -6, 0, HIT)} CellPadding={UDim2.fromOffset(6, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{ids.map((id, i) => {
					const pinned = pins.includes(id);
					return (
						<frame key={id} BackgroundTransparency={1} LayoutOrder={i}>
							<Button
								text={pinned ? `✓ ${labelOf(id)}` : labelOf(id)}
								tone={pinned ? "brass" : "quiet"}
								disabled={!pinned && full}
								onPress={() => {
									if (pinned) setSelected(id);
									else if (!full) save([...pins, id]);
								}}
								stretch
								textSize={14}
							/>
						</frame>
					);
				})}
			</frame>
		</Panel>
	);
}

// ── profile style ────────────────────────────────────────────────────────────────────────────

function ProfileStyleBlock(props: { cosmetics: unknown; rebirths: unknown; phone: boolean; request: PageProps["request"]; order: number }) {
	const phone = props.phone;
	const saved = ProfileStyle.read(props.cosmetics);
	const [pending, setPending] = React.useState<ProfileStyle.ProfileStyleState | undefined>(undefined);
	React.useEffect(() => setPending(undefined), [saved.Accent, saved.Frame]);
	const shown = pending ?? saved;
	const facts = ProfileStyle.readFacts(typeIs(props.cosmetics, "table") ? (props.cosmetics as { Facts?: unknown }).Facts : undefined);
	facts.Rebirths = math.max(facts.Rebirths, typeIs(props.rebirths, "number") ? math.floor(props.rebirths) : 0);
	const accent = ProfileStyle.accentColor(shown.Accent);
	const frame = ProfileStyle.findFrame(shown.Frame) ?? ProfileStyle.FRAMES[0];
	const ring = frameStroke(frame, accent);
	const pick = (accentId?: string, frameId?: string) => {
		setPending({ Accent: accentId ?? shown.Accent, Frame: frameId ?? shown.Frame });
		Audio.play("confirm");
		props.request("SetProfileStyle", { Accent: accentId, Frame: frameId }, (reply) => {
			if (reply.ok === true) MotionFX.play("confirm");
			else setPending(undefined);
		});
	};
	const bag = typeIs(props.cosmetics, "table") ? (props.cosmetics as { CrateSkins?: unknown; CrateSkin?: unknown }) : {};
	const owned = typeIs(bag.CrateSkins, "table") ? (bag.CrateSkins as Record<string, unknown>) : {};
	const equipped = typeIs(bag.CrateSkin, "string") ? bag.CrateSkin : ShopCatalog.DEFAULT_SKIN;
	const [pendingSkin, setPendingSkin] = React.useState<string | undefined>(undefined);
	React.useEffect(() => setPendingSkin(undefined), [equipped]);
	type Skin = { Id: string; Name: string; Accent: [number, number, number]; DailyOnly?: boolean; Earn?: ProfileStyle.StyleUnlock };
	const all = [...(ShopCatalog.SKINS as unknown as Skin[]), ...(ShopCatalog.EARNED_SKINS as unknown as Skin[])];
	const skins = all.filter((skin) => skin.Id === ShopCatalog.DEFAULT_SKIN || owned[skin.Id] === true || (skin.Earn !== undefined && ProfileStyle.isUnlocked(skin.Earn, facts)));
	const earning = (ShopCatalog.EARNED_SKINS as unknown as Skin[]).filter((skin) => !skins.includes(skin));
	const intro = useStagger(0);
	return (
		<Panel pad={gap(phone, "l")} spacing={gap(phone, "m")} order={props.order} seam rarity="Legendary">
			<Title text="Profile style" size={Type.body(phone) + 4} order={0} />
			<frame Size={new UDim2(1, 0, 0, 64)} BackgroundColor3={Iron.raised()} BorderSizePixel={0} LayoutOrder={1}>
				<uiscale Scale={intro.map((p) => 0.97 + p * 0.03)} />
				<uicorner CornerRadius={new UDim(0, Corner.panel)} />
				<uistroke Color={ring.color} Thickness={ring.thickness + 1} Transparency={0.05}>
					{ring.gradient !== undefined && <uigradient Color={ring.gradient} Rotation={35} />}
				</uistroke>
				<frame Size={UDim2.fromOffset(40, 40)} Position={new UDim2(0, 12, 0.5, 0)} AnchorPoint={new Vector2(0, 0.5)} BackgroundColor3={accent} BorderSizePixel={0}>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</frame>
				<Text text={game.GetService("Players").LocalPlayer.DisplayName} size={Type.body(phone)} font={Fonts.heavy} color={accent} box={new UDim2(1, -76, 0, 22)} position={UDim2.fromOffset(64, 10)} />
				<Text text={`${ProfileStyle.findAccent(shown.Accent)?.Name ?? ""}  ·  ${frame.Name}`} size={Type.small(phone)} color={Iron.muted()} box={new UDim2(1, -76, 0, 16)} position={UDim2.fromOffset(64, 36)} />
			</frame>
			<scrollingframe Size={new UDim2(1, 0, 0, HIT + 8)} BackgroundTransparency={1} BorderSizePixel={0} CanvasSize={new UDim2()} AutomaticCanvasSize={Enum.AutomaticSize.X} ScrollingDirection={Enum.ScrollingDirection.X} ScrollBarThickness={0} LayoutOrder={2}>
				<uipadding PaddingLeft={new UDim(0, 4)} PaddingTop={new UDim(0, 4)} />
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 10)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{ProfileStyle.ACCENTS.map((option, i) => {
					const open = ProfileStyle.isUnlocked(option.Unlock, facts);
					const on = option.Id === shown.Accent;
					return (
						<textbutton
							key={option.Id}
							Size={UDim2.fromOffset(HIT, HIT)}
							BackgroundColor3={Color3.fromRGB(option.Rgb[0], option.Rgb[1], option.Rgb[2])}
							BackgroundTransparency={open ? 0 : 0.7}
							AutoButtonColor={open}
							Text={open ? "" : "🔒"}
							TextSize={14}
							LayoutOrder={i}
							Selectable
							Event={{ Activated: () => open && !on && pick(option.Id, undefined) }}
						>
							<uicorner CornerRadius={new UDim(1, 0)} />
							<uistroke Color={on ? Iron.text() : Iron.edge()} Thickness={on ? 3 : 1} Transparency={on ? 0 : 0.4} />
						</textbutton>
					);
				})}
			</scrollingframe>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={3}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{ProfileStyle.FRAMES.map((option, i) => {
					const open = ProfileStyle.isUnlocked(option.Unlock, facts);
					return (
						<Chip
							key={option.Id}
							text={open ? option.Name : `🔒 ${option.Name}`}
							on={option.Id === shown.Frame}
							onPress={() => open && option.Id !== shown.Frame && pick(undefined, option.Id)}
							order={i}
						/>
					);
				})}
			</frame>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={4}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{skins.map((skin, i) => (
					<Chip
						key={skin.Id}
						text={skin.Name}
						color={Color3.fromRGB(skin.Accent[0], skin.Accent[1], skin.Accent[2])}
						on={(pendingSkin ?? equipped) === skin.Id}
						onPress={() => {
							if ((pendingSkin ?? equipped) === skin.Id) return;
							setPendingSkin(skin.Id);
							props.request("EquipCrateSkin", { Id: skin.Id }, (reply) => reply.ok !== true && setPendingSkin(undefined));
						}}
						order={i}
					/>
				))}
			</frame>
			{earning.size() > 0 && (
				<Text text={earning.map((skin) => `${skin.Name}: ${skin.Earn !== undefined ? ProfileStyle.unlockText(skin.Earn) : ""}`).join("   ·   ")} size={Type.small(phone)} color={Iron.muted()} multiline order={5} />
			)}
		</Panel>
	);
}

// ── page ─────────────────────────────────────────────────────────────────────────────────────

export function SettingsPage(props: PageProps) {
	const phone = props.phone;
	const viewport = useViewport();
	const s = props.session as unknown as { Settings?: Bag; Game?: { Version?: string }; Flags?: { MobileTabPins?: unknown }; Cosmetics?: unknown; Rebirths?: unknown };
	const settings = s.Settings ?? {};
	const touch = !viewport.desktop && UserInputService.TouchEnabled;
	const sections = Schema.SECTIONS.filter((section) => section.touchOnly !== true || touch);
	const [active, setActive] = React.useState("sound");
	const [query, setQuery] = React.useState("");
	const [changedOnly, setChangedOnly] = React.useState(false);
	const [advanced, setAdvanced] = React.useState<Record<string, boolean | undefined>>({});
	const sectionOf = (id: string): Section | undefined => Schema.SECTIONS.find((x) => x.id === id);
	React.useEffect(() => {
		if (sectionOf(active)?.touchOnly === true && !touch) setActive("interface");
	}, [active, touch]);
	const section = sectionOf(active) ?? sectionOf("interface")!;
	const heroIn = useStagger(0);

	const focusRef = React.useRef<Frame>();
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) return undefined;
		const job = task.defer(() => {
			const host = focusRef.current;
			if (host !== undefined && host.Parent !== undefined) GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [active]);

	const visibleEntry = (entry: Entry) => {
		const home = sectionOf(entry.section);
		return home !== undefined && !(home.touchOnly === true && !touch);
	};
	const changed = (entry: Entry) => math.abs(readSetting(settings, entry.key) - entry.default) > 0.01;
	const changedList = Schema.ENTRIES.filter((e) => visibleEntry(e) && changed(e));
	const searching = query.match("^%s*$")[0] === undefined;
	const showChanged = changedOnly && !searching;
	const listing = searching || showChanged;
	const q = query.lower();
	const hit = (entry: Entry) => {
		for (const field of [entry.label, entry.help, sectionOf(entry.section)?.label ?? "", entry.key]) {
			if (field.lower().find(q, 1, true)[0] !== undefined) return true;
		}
		return false;
	};
	let hiddenAdvanced = 0;
	let rows = Schema.ENTRIES.filter((entry) => {
		if (!visibleEntry(entry)) return false;
		if (searching) return hit(entry);
		if (showChanged) return changed(entry);
		if (entry.section !== active) return false;
		if (entry.advanced === true && advanced[active] !== true) {
			hiddenAdvanced += 1;
			return false;
		}
		return true;
	});
	if (!listing) {
		// keep related options together under their sub-heading (stable within a group)
		const indexed = rows.map((entry, i) => ({ entry, i, g: Schema.group(entry.key).order }));
		indexed.sort((a, b) => (a.g !== b.g ? a.g < b.g : a.i < b.i));
		rows = indexed.map((x) => x.entry);
	}
	const sectionChanged = changedList.filter((e) => e.section === active).size();
	const preset = Schema.matchingPreset(settings as never);

	const resetSection = () => props.request("SetSetting", { Values: Schema.sectionDefaults(active), Label: `${section.label} settings reset.` });
	const resetAll = () => {
		const values: Record<string, number> = {};
		for (const entry of changedList) values[entry.key] = entry.default;
		props.request("SetSetting", { Values: values, Label: "Settings back to defaults." });
	};

	const body: React.Element[] = [];
	let order = 0;
	let lastGroup: string | undefined;
	rows.forEach((entry) => {
		if (!listing) {
			const heading = Schema.group(entry.key).label;
			if (heading !== lastGroup) {
				lastGroup = heading;
				order += 1;
				body.push(<Text key={`g_${heading}`} text={heading} size={Type.small(phone)} font={Fonts.heavy} color={Iron.brass()} box={new UDim2(1, 0, 0, 30)} order={order} />);
			}
		}
		order += 1;
		body.push(
			<SettingRow
				key={`r_${entry.key}`}
				entry={entry}
				value={readSetting(settings, entry.key)}
				tag={listing ? sectionOf(entry.section)?.label : undefined}
				phone={phone}
				index={order}
				request={props.request}
			/>,
		);
	});

	const space = gap(phone, "l");
	const sectionTabs = (
		<frame Size={phone ? new UDim2(1, 0, 0, 0) : UDim2.fromOffset(180, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0}>
			<uilistlayout FillDirection={phone ? Enum.FillDirection.Horizontal : Enum.FillDirection.Vertical} Wraps={phone} Padding={new UDim(0, 6)} SortOrder={Enum.SortOrder.LayoutOrder} />
			{sections.map((x, i) => (
				<Tab
					key={x.id}
					text={x.label}
					active={!listing && x.id === active}
					badge={changedList.filter((e) => e.section === x.id).size()}
					width={phone ? math.floor((viewport.width - space * 2 - 12) / 3) - 1 : 180}
					onPress={() => {
						if (x.id === active && !listing) return;
						Audio.play("tabSwitch");
						setQuery("");
						setChangedOnly(false);
						setActive(x.id);
					}}
					order={i}
				/>
			))}
		</frame>
	);

	const list = (
		<frame Size={phone ? new UDim2(1, 0, 0, 0) : new UDim2(1, -180 - space, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
			<uilistlayout Padding={new UDim(0, space)} SortOrder={Enum.SortOrder.LayoutOrder} />
			<Panel pad={gap(phone, "l")} spacing={0} order={0}>
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} VerticalAlignment={Enum.VerticalAlignment.Center} Padding={new UDim(0, 10)} SortOrder={Enum.SortOrder.LayoutOrder} />
					<frame Size={new UDim2(1, -120, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0}>
						<uilistlayout Padding={new UDim(0, 2)} SortOrder={Enum.SortOrder.LayoutOrder} />
						<Title text={searching ? `"${query}"` : showChanged ? "Changed" : section.label} size={Type.title(phone)} order={0} />
						{!listing && <Text text={section.blurb} size={Type.small(phone)} color={Iron.muted()} multiline order={1} />}
					</frame>
					{(!searching || showChanged) && (
						<Button text="Reset" tone="iron" width={100} onPress={showChanged ? resetAll : resetSection} disabled={showChanged ? changedList.size() === 0 : sectionChanged === 0} order={1} />
					)}
				</frame>
				{!listing && active === "display" && (
					<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
						<uipadding PaddingTop={new UDim(0, 14)} PaddingBottom={new UDim(0, 6)} />
						<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
						{Schema.PRESETS.map((p, i) => (
							<Button
								key={p.id}
								text={p.label}
								tone={preset === p.id ? "brass" : "iron"}
								width={phone ? 120 : 140}
								onPress={() => props.request("SetSetting", { Values: p.values, Label: p.notice })}
								order={i}
							/>
						))}
					</frame>
				)}
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2}>
					<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} />
					{body}
					{listing && rows.size() === 0 && <Text text={showChanged ? "All on defaults." : 'Try "music" or "text".'} size={Type.body(phone)} color={Iron.muted()} box={new UDim2(1, 0, 0, 40)} order={0} />}
				</frame>
				{!listing && (hiddenAdvanced > 0 || advanced[active] === true) && (
					<frame Size={new UDim2(1, 0, 0, HIT + 16)} BackgroundTransparency={1} LayoutOrder={3}>
						<uipadding PaddingTop={new UDim(0, 12)} />
						<Button
							text={advanced[active] === true ? "Fewer" : `${hiddenAdvanced} more`}
							tone="quiet"
							stretch
							onPress={() => {
								const updated = table.clone(advanced);
								updated[active] = advanced[active] !== true;
								setAdvanced(updated);
							}}
						/>
					</frame>
				)}
				{!listing && active === "interface" && UserInputService.GamepadEnabled && (
					<Text text="LB / RB pages  ·  Y vault  ·  X overcharge  ·  LT / RT amount  ·  B back  ·  Start settings" size={Type.small(phone)} color={Iron.soft()} multiline order={4} />
				)}
			</Panel>
			{!listing && active === "mobile" && touch && <TabPins saved={s.Flags?.MobileTabPins} phone={phone} request={props.request} order={1} />}
			{!listing && active === "interface" && <ProfileStyleBlock cosmetics={s.Cosmetics} rebirths={s.Rebirths} phone={phone} request={props.request} order={2} />}
		</frame>
	);

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
				<Panel pad={gap(phone, "xl")} spacing={gap(phone, "m")} seam>
					<Title text="Settings" size={Type.title(phone)} tags={["wave"]} order={0} />
					<Text text={`Saves automatically  ·  v${s.Game?.Version ?? "?"}`} size={Type.small(phone)} color={Iron.muted()} order={1} />
					<frame ref={focusRef} Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2}>
						<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
						<Button text="Tour" tone="iron" width={phone ? 110 : 130} onPress={() => props.request("ReplayTutorial")} order={0} />
						<Button text="Notes" tone="iron" width={phone ? 110 : 130} onPress={() => props.request("OpenRelease")} order={1} />
					</frame>
					<frame Size={new UDim2(1, 0, 0, HIT)} BackgroundColor3={Iron.sunk()} BorderSizePixel={0} LayoutOrder={3}>
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
					<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={4}>
						<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
						<Chip text="Sections" on={!changedOnly} onPress={() => setChangedOnly(false)} order={0} />
						<Chip
							text={changedList.size() > 0 ? `Changed ${changedList.size()}` : "Changed"}
							on={changedOnly}
							onPress={() => {
								Audio.play("tabSwitch");
								setQuery("");
								setChangedOnly(true);
							}}
							order={1}
						/>
					</frame>
				</Panel>
			</frame>

			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
				<uilistlayout FillDirection={phone ? Enum.FillDirection.Vertical : Enum.FillDirection.Horizontal} Padding={new UDim(0, space)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{sectionTabs}
				{list}
			</frame>
		</scrollingframe>
	);
}

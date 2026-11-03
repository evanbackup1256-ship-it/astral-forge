// Small pieces of the Control Room (AdminView): the hold-to-confirm button, the count-up and typewriter hooks,
// the result stamp, the lock-on reticle, the switch, and the rows and chips the tabs are built from.
import React from "@rbxts/react";
import { compactNumber } from "../../CoreKit/format";
import { Palette } from "../../CoreKit/theme";
import { useAntilag } from "../../MotionKit/antilag";
import { useClock, useEntrance, useFlash, usePulse, useSpring, useStagger } from "../../MotionKit/motion";
import { AudioPlayer, kitMember, LuauComponent } from "../luauKits";

const UserInputService = game.GetService("UserInputService");
const { Audio } = kitMember<{ Audio: AudioPlayer }>("AudioKit", "audio");
const { Text } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");

export interface AdminPlayer {
	UserId: number;
	DisplayName: string;
	Name: string;
	Cash?: unknown;
	Vault?: unknown;
	Capacity?: unknown;
	Cores?: number;
	Rebirths?: number;
	Zone?: number;
	Production?: unknown;
	Stardust?: number;
	Keys?: number;
	Unlimited?: boolean;
}

export interface AdminCommand {
	Id: string;
	Label: string;
	Category?: string;
	Danger?: string;
	NeedsOption?: boolean;
	World?: boolean;
	Input?: { Mode?: string; UsesAmount?: boolean; Minimum?: number; Maximum?: number; Integer?: boolean; Summary?: string };
}

/** The server's labels can end in a "(Option = ...)" hint for the typed field; lists and headings read better without it. */
export function plainLabel(label: string): string {
	const [withoutOption] = label.gsub("%s*%(Option = [^%)]*%)", "");
	const [withoutAmount] = withoutOption.gsub("%s*%(Amount = [^%)]*%)", "");
	return withoutAmount;
}

export const CATEGORY_LABEL: Record<string, string> = {
	Economy: "ECONOMY",
	Progress: "PROGRESS",
	Items: "ITEMS",
	Resets: "RESETS",
	Troll: "PRANKS",
	Effects: "EFFECTS",
	Moderation: "MODERATION",
	LiveOps: "LIVE OPS",
};

export function catAccent(category?: string): Color3 {
	if (category === "Economy") return Palette.mint;
	if (category === "Progress") return Palette.cyan;
	if (category === "Items") return Palette.violet;
	if (category === "Resets") return Palette.mango;
	if (category === "Troll") return Palette.pink;
	if (category === "Effects") return Palette.brass;
	if (category === "Moderation") return Palette.coral;
	if (category === "LiveOps") return Palette.blue;
	return Palette.steel;
}

// ── hooks ──────────────────────────────────────────────────────────────────────

/** Eases a number toward its target; the caller formats what comes back. Snaps when the antilag tier drops entrances. */
export function useCountUp(target: number, reducedMotion = false): number {
	const antilag = useAntilag();
	const [shown, setShown] = React.useState(target);
	const shownRef = React.useRef(target);
	React.useEffect(() => {
		const from = shownRef.current;
		if (from === target || reducedMotion || !antilag.entrance) {
			shownRef.current = target;
			setShown(target);
			return undefined;
		}
		let alive = true;
		const startedAt = os.clock();
		const worker = task.spawn(() => {
			while (alive) {
				const progress = math.clamp((os.clock() - startedAt) / 0.7, 0, 1);
				const value = from + (target - from) * (1 - (1 - progress) ** 3);
				shownRef.current = value;
				setShown(value);
				if (progress >= 1) {
					break;
				}
				task.wait(0.05);
			}
		});
		return () => {
			alive = false;
			pcall(task.cancel, worker);
		};
	}, [target]);
	return shown;
}

function utf8Prefix(text: string, count: number): string {
	const length = utf8.len(text)[0];
	const total = typeIs(length, "number") ? length : text.size();
	if (count >= total) {
		return text;
	}
	if (count <= 0) {
		return "";
	}
	const position = utf8.offset(text, count + 1);
	return text.sub(1, (position ?? text.size() + 1) - 1);
}

/** Types a line out, then holds it. A new line restarts the typing. */
export function useTypewriter(text: string, reducedMotion = false, charsPerSecond = 95): string {
	const antilag = useAntilag();
	const instant = reducedMotion || !antilag.entrance;
	const [count, setCount] = React.useState(instant ? 1e6 : 0);
	React.useEffect(() => {
		if (instant) {
			setCount(1e6);
			return undefined;
		}
		setCount(0);
		let alive = true;
		const startedAt = os.clock();
		const worker = task.spawn(() => {
			while (alive) {
				const typed = math.floor((os.clock() - startedAt) * charsPerSecond);
				setCount(typed);
				if (typed >= text.size()) {
					break;
				}
				task.wait(0.03);
			}
		});
		return () => {
			alive = false;
			pcall(task.cancel, worker);
		};
	}, [text, instant]);
	return utf8Prefix(text, count);
}

export function clockTime(at?: number): string {
	return at !== undefined ? os.date("%H:%M", at) : "--:--";
}

export function ago(at: number | undefined): string {
	if (at === undefined) return "";
	const seconds = math.max(0, os.time() - at);
	if (seconds < 60) return `${seconds}s ago`;
	if (seconds < 3600) return `${math.floor(seconds / 60)}m ago`;
	return `${math.floor(seconds / 3600)}h ago`;
}

export function uptimeText(seconds: number): string {
	const whole = math.floor(seconds);
	const hours = math.floor(whole / 3600);
	const minutes = math.floor((whole % 3600) / 60);
	return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m ${whole % 60}s`;
}

// ── hold to confirm ────────────────────────────────────────────────────────────

export interface HoldButtonProps {
	text: string;
	color: Color3;
	size?: UDim2;
	position?: UDim2;
	layoutOrder?: number;
	seconds?: number;
	disabled?: boolean;
	busy?: boolean;
	shakeToken?: number;
	reducedMotion?: boolean;
	onComplete: () => void;
}

/**
 * A button that runs only after it is held for a moment: the fill sweeps across, letting go early cancels.
 * Keyboard and gamepad (which cannot hold a pointer) confirm with a second press inside 1.4 seconds.
 */
export function HoldButton(props: HoldButtonProps) {
	const seconds = props.seconds ?? 0.85;
	const disabled = props.disabled === true || props.busy === true;
	const [holding, setHolding] = React.useState(false);
	const [hint, setHint] = React.useState(false);
	const [doneToken, setDoneToken] = React.useState(0);
	const holdingRef = React.useRef(false);
	const startedAt = React.useRef(0);
	const holdToken = React.useRef(0);
	const doneAt = React.useRef(-10);
	const lastTap = React.useRef(-10);
	const mounted = React.useRef(true);
	const onCompleteRef = React.useRef(props.onComplete);
	onCompleteRef.current = props.onComplete;
	const disabledRef = React.useRef(disabled);
	disabledRef.current = disabled;
	const clock = useClock(holding, 1, 1000, true);
	const done = useFlash(doneToken, props.reducedMotion, 0.3);
	const shake = useFlash(props.shakeToken ?? 0, props.reducedMotion, 0.4);

	React.useEffect(() => {
		mounted.current = true;
		return () => {
			mounted.current = false;
			holdToken.current += 1;
		};
	}, []);

	const finish = () => {
		holdingRef.current = false;
		holdToken.current += 1;
		doneAt.current = os.clock();
		if (mounted.current) {
			setHolding(false);
			setDoneToken((token) => token + 1);
		}
		onCompleteRef.current();
	};
	const begin = () => {
		if (disabledRef.current || holdingRef.current) return;
		holdingRef.current = true;
		holdToken.current += 1;
		const token = holdToken.current;
		startedAt.current = os.clock();
		setHolding(true);
		Audio.play("adminArm");
		task.delay(seconds, () => {
			if (holdToken.current === token && holdingRef.current && !disabledRef.current) {
				finish();
			}
		});
	};
	const cancel = () => {
		if (!holdingRef.current) return;
		holdingRef.current = false;
		holdToken.current += 1;
		if (mounted.current) setHolding(false);
	};
	const tap = () => {
		const now = os.clock();
		// the release that ends a completed hold also fires Activated
		if (now - doneAt.current < 0.5 || disabledRef.current) return;
		const input = UserInputService.GetLastInputType();
		const pointer = input === Enum.UserInputType.MouseButton1 || input === Enum.UserInputType.Touch;
		if (!pointer && now - lastTap.current < 1.4) {
			lastTap.current = -10;
			finish();
			return;
		}
		lastTap.current = now;
		setHint(true);
		task.delay(1.4, () => {
			if (mounted.current) setHint(false);
		});
	};

	const fillBinding = clock.map(() => UDim2.fromScale(math.clamp((os.clock() - startedAt.current) / seconds, 0, 1), 1));
	const fill = holding ? fillBinding : UDim2.fromScale(0, 1);
	const label = props.busy === true ? "WORKING…" : holding ? "KEEP HOLDING" : hint ? "HOLD, OR PRESS TWICE" : props.text;
	return (
		<frame Size={props.size ?? UDim2.fromOffset(200, 46)} Position={props.position} LayoutOrder={props.layoutOrder} BackgroundTransparency={1} BorderSizePixel={0}>
			<frame
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				Position={shake.map((value) => UDim2.fromOffset(math.sin(value * 38) * 7 * value, 0))}
			>
				<textbutton
					Size={UDim2.fromScale(1, 1)}
					BackgroundColor3={disabled ? Palette.panelSoft : Palette.panelRaised}
					BorderSizePixel={0}
					Text=""
					AutoButtonColor={false}
					Active={!disabled}
					Selectable={!disabled}
					ClipsDescendants={true}
					Event={{
						MouseButton1Down: begin,
						MouseButton1Up: cancel,
						MouseLeave: cancel,
						InputBegan: (_button: TextButton, input: InputObject) => {
							if (input.KeyCode === Enum.KeyCode.ButtonA) begin();
						},
						InputEnded: (_button: TextButton, input: InputObject) => {
							if (input.KeyCode === Enum.KeyCode.ButtonA) cancel();
						},
						Activated: tap,
					}}
				>
					<uicorner CornerRadius={new UDim(0, 10)} />
					<uistroke Color={props.color} Thickness={1.4} Transparency={disabled ? 0.75 : 0.2} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
					<frame Size={fill} BackgroundColor3={props.color} BackgroundTransparency={0.5} BorderSizePixel={0} />
					{holding && (
						<frame
							Size={new UDim2(0, 3, 1, 0)}
							BackgroundColor3={props.color}
							BorderSizePixel={0}
							Position={fillBinding.map((size) => new UDim2(size.X.Scale, -3, 0, 0))}
						/>
					)}
					<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.white} BorderSizePixel={0} BackgroundTransparency={done.map((value) => 1 - value * 0.55)} />
					<textlabel
						Size={UDim2.fromScale(1, 1)}
						BackgroundTransparency={1}
						Text={label}
						TextSize={14}
						FontFace={Font.fromEnum(Enum.Font.BuilderSansBold)}
						TextColor3={disabled ? Palette.muted : Palette.cream}
						TextTruncate={Enum.TextTruncate.AtEnd}
						ZIndex={3}
					>
						<uipadding PaddingLeft={new UDim(0, 10)} PaddingRight={new UDim(0, 10)} />
					</textlabel>
				</textbutton>
			</frame>
		</frame>
	);
}

// ── result stamp ───────────────────────────────────────────────────────────────

/** A stamp that lands on the runner after a command: mint when it went through, coral when it was refused. */
export function Stamp(props: { ok: boolean; text: string; position?: UDim2; reducedMotion?: boolean }) {
	const enter = useEntrance(props.reducedMotion === true);
	const color = props.ok ? Palette.mint : Palette.coral;
	return (
		<frame
			AnchorPoint={new Vector2(0.5, 0.5)}
			Position={props.position ?? UDim2.fromScale(0.5, 0.5)}
			Size={UDim2.fromOffset(220, 58)}
			Rotation={props.ok ? -6 : 5}
			BackgroundColor3={Palette.ink}
			BackgroundTransparency={enter.map((value) => 1 - value * 0.12)}
			BorderSizePixel={0}
			ZIndex={40}
			Active={false}
		>
			<uicorner CornerRadius={new UDim(0, 8)} />
			<uistroke Color={color} Thickness={3} Transparency={enter.map((value) => 1 - value)} />
			<uiscale Scale={enter.map((value) => 1.7 - value * 0.7)} />
			<textlabel
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				Text={props.text}
				TextSize={26}
				FontFace={Font.fromEnum(Enum.Font.BuilderSansExtraBold)}
				TextColor3={color}
				TextTransparency={enter.map((value) => 1 - value)}
				ZIndex={41}
			/>
		</frame>
	);
}

// ── reticle ────────────────────────────────────────────────────────────────────

/** Four corner brackets around a tile. They close in whenever `token` changes, as if locking on. */
export function Reticle(props: { size: number; accent: Color3; token: number; reducedMotion?: boolean }) {
	const antilag = useAntilag();
	const pop = useFlash(props.token, props.reducedMotion, 0.32);
	const pulse = usePulse(antilag.allowAmbient, 1.2);
	const arm = math.max(8, math.floor(props.size * 0.2));
	const thickness = 2;
	const corners: Array<[number, number]> = [
		[0, 0],
		[1, 0],
		[0, 1],
		[1, 1],
	];
	return (
		<frame
			AnchorPoint={new Vector2(0.5, 0.5)}
			Position={UDim2.fromScale(0.5, 0.5)}
			Size={pop.map((value) => UDim2.fromOffset(props.size + 8 + value * 22, props.size + 8 + value * 22))}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			Active={false}
		>
			{corners.map(([cx, cy], index) => (
				<React.Fragment key={`corner${index}`}>
					<frame
						AnchorPoint={new Vector2(cx, cy)}
						Position={UDim2.fromScale(cx, cy)}
						Size={UDim2.fromOffset(arm, thickness)}
						BackgroundColor3={props.accent}
						BorderSizePixel={0}
						BackgroundTransparency={pulse.map((value) => 0.1 + value * 0.3)}
					/>
					<frame
						AnchorPoint={new Vector2(cx, cy)}
						Position={UDim2.fromScale(cx, cy)}
						Size={UDim2.fromOffset(thickness, arm)}
						BackgroundColor3={props.accent}
						BorderSizePixel={0}
						BackgroundTransparency={pulse.map((value) => 0.1 + value * 0.3)}
					/>
				</React.Fragment>
			))}
		</frame>
	);
}

// ── switch ─────────────────────────────────────────────────────────────────────

export function Switch(props: { on: boolean; onChange: (on: boolean) => void; accent: Color3; disabled?: boolean; reducedMotion?: boolean }) {
	const knob = useSpring(props.on ? 1 : 0, props.reducedMotion, 420, 30);
	// the 46x26 track sits inside a 54x44 catch area so a thumb can find it
	return (
		<textbutton
			Size={UDim2.fromOffset(54, 44)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			Text=""
			AutoButtonColor={false}
			Active={props.disabled !== true}
			Selectable={props.disabled !== true}
			Event={{
				Activated: () => {
					if (props.disabled !== true) {
						Audio.play("tabSwitch");
						props.onChange(!props.on);
					}
				},
			}}
		>
			<frame
				AnchorPoint={new Vector2(0.5, 0.5)}
				Position={UDim2.fromScale(0.5, 0.5)}
				Size={UDim2.fromOffset(46, 26)}
				BackgroundColor3={knob.map((value) => Palette.panelSoft.Lerp(props.accent, value * 0.9))}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke Color={Palette.lineSoft} Thickness={1} Transparency={0.45} />
				<frame
					AnchorPoint={new Vector2(0, 0.5)}
					Size={UDim2.fromOffset(20, 20)}
					Position={knob.map((value) => new UDim2(0, 3 + value * 20, 0.5, 0))}
					BackgroundColor3={Palette.cream}
					BorderSizePixel={0}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</frame>
			</frame>
		</textbutton>
	);
}

// ── scan line ──────────────────────────────────────────────────────────────────

/** A hairline with a light that travels along it; a flat hairline when the antilag tier turns ambient motion off. */
export function ScanLine(props: { accent: Color3; position?: UDim2 }) {
	const antilag = useAntilag();
	const clock = useClock(antilag.allowAmbient, 0.3, 2, false);
	return (
		<frame Size={new UDim2(1, 0, 0, 2)} Position={props.position} BackgroundColor3={props.accent} BorderSizePixel={0} BackgroundTransparency={antilag.allowAmbient ? 0 : 0.8}>
			{antilag.allowAmbient && (
				<uigradient
					Transparency={
						new NumberSequence([
							new NumberSequenceKeypoint(0, 1),
							new NumberSequenceKeypoint(0.35, 0.82),
							new NumberSequenceKeypoint(0.5, 0.05),
							new NumberSequenceKeypoint(0.65, 0.82),
							new NumberSequenceKeypoint(1, 1),
						])
					}
					Offset={clock.map((phase) => new Vector2(phase - 1, 0))}
				/>
			)}
		</frame>
	);
}

// ── rows and chips ─────────────────────────────────────────────────────────────

export function SectionTitle(props: { value: string; accent: Color3; position?: UDim2; layoutOrder?: number }) {
	return (
		<Text
			value={props.value}
			size={11}
			color={props.accent}
			weight={Enum.FontWeight.Heavy}
			fit={false}
			position={props.position ?? UDim2.fromOffset(0, 0)}
			sizeConstraint={new UDim2(1, -8, 0, 15)}
			layoutOrder={props.layoutOrder}
		/>
	);
}

export function headshot(userId: number): string {
	return `rbxthumb://type=AvatarHeadShot&id=${userId}&w=150&h=150`;
}

export const PLAYER_ROW = 58;

export function PlayerRow(props: {
	player: AdminPlayer;
	selected: boolean;
	you: boolean;
	index: number;
	onClick: () => void;
	reducedMotion?: boolean;
}) {
	const { player, selected } = props;
	const reveal = useStagger(props.index, props.reducedMotion);
	return (
		<textbutton
			LayoutOrder={props.index + 1}
			Size={new UDim2(1, 0, 0, PLAYER_ROW)}
			BackgroundColor3={selected ? Palette.panelRaised : Palette.panel}
			BackgroundTransparency={reveal.map((value) => (selected ? 0 : 0.12) + (1 - math.clamp(value, 0, 1)) * (1 - (selected ? 0 : 0.12)))}
			BorderSizePixel={0}
			Text=""
			AutoButtonColor={false}
			Active={true}
			Selectable={true}
			Event={{
				Activated: () => {
					Audio.play("playerlistSelect");
					props.onClick();
				},
			}}
		>
			<uicorner CornerRadius={new UDim(0, 10)} />
			<uistroke Color={selected ? Palette.mint : Palette.lineSoft} Thickness={1} Transparency={selected ? 0.4 : 0.85} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
			<frame Size={UDim2.fromOffset(40, 40)} Position={UDim2.fromOffset(12, 9)} BackgroundColor3={Palette.ink} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<imagelabel Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} Image={headshot(player.UserId)} ZIndex={2}>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</imagelabel>
			</frame>
			<Text
				value={props.you ? `${player.DisplayName}  ·  you` : player.DisplayName}
				size={13}
				color={props.you ? Palette.mint : Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(62, 9)}
				sizeConstraint={new UDim2(1, -74, 0, 18)}
			/>
			<Text
				value={`@${player.Name}  ·  ${compactNumber(player.Cash ?? 0)} Flux`}
				size={11}
				color={Palette.cyan}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(62, 30)}
				sizeConstraint={new UDim2(1, -74, 0, 16)}
			/>
		</textbutton>
	);
}

export const COMMAND_ROW = 52;

export function CommandRow(props: { entry: AdminCommand; selected: boolean; armed: boolean; index: number; onClick: () => void; reducedMotion?: boolean }) {
	const { entry, selected } = props;
	const accent = catAccent(entry.Category);
	const reveal = useStagger(props.index % 14, props.reducedMotion);
	return (
		<textbutton
			LayoutOrder={props.index + 1}
			Size={new UDim2(1, 0, 0, COMMAND_ROW)}
			BackgroundColor3={selected ? Palette.panelRaised : Palette.panel}
			BackgroundTransparency={reveal.map((value) => (selected ? 0 : 0.1) + (1 - math.clamp(value, 0, 1)) * 0.9)}
			BorderSizePixel={0}
			Text=""
			AutoButtonColor={false}
			Active={true}
			Selectable={true}
			Event={{
				Activated: () => {
					Audio.play("tabSwitch");
					props.onClick();
				},
			}}
		>
			<uicorner CornerRadius={new UDim(0, 10)} />
			<uistroke Color={selected ? accent : Palette.line} Thickness={1} Transparency={selected ? 0.25 : 0.8} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
			<frame Size={new UDim2(0, 4, 1, -16)} Position={UDim2.fromOffset(0, 8)} BackgroundColor3={accent} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
			<Text
				value={plainLabel(entry.Label)}
				size={13}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(16, 8)}
				sizeConstraint={new UDim2(1, -44, 0, 18)}
			/>
			<Text
				value={`${CATEGORY_LABEL[entry.Category ?? "Economy"] ?? "OTHER"}  ·  ${entry.Id}`}
				size={11}
				color={Palette.muted}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(16, 28)}
				sizeConstraint={new UDim2(1, -44, 0, 16)}
			/>
			{props.armed && (
				<frame
					Size={UDim2.fromOffset(7, 7)}
					Position={new UDim2(1, -16, 0.5, 0)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundColor3={Palette.mango}
					BorderSizePixel={0}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</frame>
			)}
		</textbutton>
	);
}

export function Chip(props: { label: string; count?: number; selected: boolean; accent: Color3; onClick: () => void; layoutOrder?: number }) {
	const [hovered, setHovered] = React.useState(false);
	const text = props.count !== undefined ? `${props.label}  ${props.count}` : props.label;
	// the pill is 30px tall inside a 44px catch area, with 6px of room on its right for the gap between chips
	return (
		<textbutton
			LayoutOrder={props.layoutOrder}
			AutomaticSize={Enum.AutomaticSize.X}
			Size={UDim2.fromOffset(0, 44)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			Text=""
			AutoButtonColor={false}
			Active={true}
			Selectable={true}
			Event={{
				MouseEnter: () => setHovered(true),
				MouseLeave: () => setHovered(false),
				Activated: () => {
					Audio.play("tabSwitch");
					props.onClick();
				},
			}}
		>
			<uipadding PaddingRight={new UDim(0, 6)} />
			<frame
				AutomaticSize={Enum.AutomaticSize.X}
				Size={UDim2.fromOffset(0, 30)}
				Position={new UDim2(0, 0, 0.5, -15)}
				BackgroundColor3={props.selected ? props.accent : Palette.panelSoft}
				BackgroundTransparency={props.selected ? 0 : hovered ? 0.3 : 0.55}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(0, 8)} />
				<uipadding PaddingLeft={new UDim(0, 12)} PaddingRight={new UDim(0, 12)} />
				<textlabel
					AutomaticSize={Enum.AutomaticSize.X}
					Size={UDim2.fromOffset(0, 30)}
					BackgroundTransparency={1}
					Text={text}
					TextSize={12}
					FontFace={Font.fromEnum(Enum.Font.BuilderSansBold)}
					TextColor3={props.selected ? Palette.ink : Palette.creamSoft}
				/>
			</frame>
		</textbutton>
	);
}

/** A labelled meter whose bar springs to its share of the widest row. */
export function BarRow(props: { label: string; value: string; share: number; accent: Color3; layoutOrder?: number; reducedMotion?: boolean }) {
	const grow = useSpring(math.clamp(props.share, 0, 1), props.reducedMotion, 160, 20, 0);
	return (
		<frame Size={new UDim2(1, 0, 0, 38)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={props.layoutOrder}>
			<Text
				value={props.label}
				size={12}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={11}
				sizeConstraint={new UDim2(1, -90, 0, 16)}
			/>
			<Text
				value={props.value}
				size={12}
				color={props.accent}
				weight={Enum.FontWeight.Heavy}
				align={Enum.TextXAlignment.Right}
				fit={true}
				minSize={11}
				position={new UDim2(1, -86, 0, 0)}
				sizeConstraint={new UDim2(0, 86, 0, 16)}
			/>
			<frame Size={new UDim2(1, 0, 0, 6)} Position={UDim2.fromOffset(0, 24)} BackgroundColor3={Palette.ink} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<frame Size={grow.map((value) => UDim2.fromScale(value, 1))} BackgroundColor3={props.accent} BorderSizePixel={0}>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</frame>
			</frame>
		</frame>
	);
}

/** A number with a caption, for the masthead and the telemetry grid. */
export function StatTile(props: { label: string; value: string; accent: Color3; sub?: string; layoutOrder?: number; index?: number; reducedMotion?: boolean }) {
	const reveal = useStagger(props.index ?? 0, props.reducedMotion);
	return (
		<frame
			Size={UDim2.fromScale(1, 1)}
			BackgroundColor3={Palette.ink}
			BackgroundTransparency={reveal.map((value) => 1 - math.clamp(value, 0, 1))}
			BorderSizePixel={0}
			ClipsDescendants={true}
			LayoutOrder={props.layoutOrder}
		>
			<uicorner CornerRadius={new UDim(0, 10)} />
			<uistroke Color={props.accent} Thickness={1} Transparency={0.78} />
			<frame Size={new UDim2(0, 3, 1, -16)} Position={UDim2.fromOffset(0, 8)} BackgroundColor3={props.accent} BorderSizePixel={0} />
			<Text
				value={props.label}
				size={11}
				color={Palette.muted}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(14, 8)}
				sizeConstraint={new UDim2(1, -22, 0, 15)}
			/>
			<Text
				value={props.value}
				size={19}
				color={props.accent}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(14, 25)}
				sizeConstraint={new UDim2(1, -22, 0, 26)}
			/>
			{props.sub !== undefined && (
				<Text
					value={props.sub}
					size={11}
					color={Palette.creamSoft}
					fit={true}
					minSize={11}
					position={UDim2.fromOffset(14, 53)}
					sizeConstraint={new UDim2(1, -22, 0, 15)}
				/>
			)}
		</frame>
	);
}

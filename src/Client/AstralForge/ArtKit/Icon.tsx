import React from "@rbxts/react";
import { useExitPresence, useMotionSettings } from "../MotionKit/motion";
import { Palette } from "../CoreKit/theme";
import IconManifest = require("../IconManifest");

const RunService = game.GetService("RunService");

function fadeWithPresence(local_: number | React.Binding<number>, presence: React.Binding<number>): React.Binding<number> {
	if (typeIs(local_, "number")) {
		return presence.map((shown) => math.clamp(local_ + (1 - shown), 0, 1));
	}
	return React.joinBindings([local_, presence]).map((values) => math.clamp(values[0] + (1 - values[1]), 0, 1));
}

export const VECTOR_ICON_ATLAS = "rbxassetid://139083324249955";
export const GAME_ICON_ASSET = "rbxassetid://77239367431949";
export const WORDMARK_ASSET = "rbxassetid://75854849112049";
export const COMPACT_MARK_ASSET = "rbxassetid://93834740732329";
export const LOCKUP_ASSET = "rbxassetid://94028186779182";
export const VECTOR_ICON_CELL = 128;
export const VECTOR_ICON_COLUMNS = 8;
export const VECTOR_ICON_INDEX: Record<string, number> = {
	Brand: 0,
	Flux: 1,
	Core: 2,
	Dust: 3,
	Forge: 4,
	Research: 5,
	Grid: 6,
	World: 7,
	Mission: 8,
	Milestone: 9,
	Leaderboard: 10,
	Crew: 11,
	Guild: 12,
	Wheel: 13,
	Games: 14,
	Credits: 15,
	Gift: 16,
	Guide: 17,
	Settings: 18,
	Close: 19,
	Menu: 20,
	Chevron: 21,
	Back: 22,
	Check: 23,
	StarGrid: 24,
	Command: 25,
	Anomaly: 26,
	Reactor: 27,
	Lab: 28,
	Loadout: 29,
	Artifact: 30,
	Vault: 31,
	Rebirth: 32,
	Hide: 33,
	Lock: 34,
	Story: 35,
	Mail: 36,
	Chat: 37,
	Shop: 38,
	Boost: 39,
	Jackpot: 40,
	Admin: 44,
	Pilot: 45,
	Overview: 46,
	Inventory: 47,
	Continuum: 48,
	Rewards: 49,
	Collect: 50,
	Overcharge: 51,
	Domain: 52,
	Search: 53,
	Pause: 54,
	Play: 55,
	Refresh: 56,
	Send: 57,
	Code: 58,
	Crate: 59,
	Calendar: 60,
	Timer: 61,
	Wave: 62,
	Visit: 63,
};

function vectorIconIndex(kind: unknown): number {
	if (typeIs(kind, "string")) {
		const index = VECTOR_ICON_INDEX[kind] as number | undefined;
		if (index !== undefined) {
			return index;
		}
	}
	return VECTOR_ICON_INDEX.Guide;
}

export function VectorIconFace({
	kind,
	color,
	transparency = 0,
}: {
	kind: unknown;
	color?: Color3;
	transparency?: number | React.Binding<number>;
}) {
	const presence = useExitPresence();
	const faded = React.useMemo(() => fadeWithPresence(transparency, presence), [transparency, presence]);
	const index = vectorIconIndex(kind);
	const column = index % VECTOR_ICON_COLUMNS;
	const row = math.floor(index / VECTOR_ICON_COLUMNS);
	return (
		<imagelabel
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			Image={VECTOR_ICON_ATLAS}
			ImageColor3={color}
			ImageTransparency={faded}
			ImageRectOffset={new Vector2(column * VECTOR_ICON_CELL, row * VECTOR_ICON_CELL)}
			ImageRectSize={new Vector2(VECTOR_ICON_CELL, VECTOR_ICON_CELL)}
			ScaleType={Enum.ScaleType.Stretch}
		/>
	);
}

const ITEM_ICONS: Record<string, string> = {
	IonCoupler: "Command.1",
	FluxLens: "Flux.1",
	CapacityCoil: "Vault.1",
	PulseInjector: "Anomaly.1",
	AutoRelay: "Grid.1",
	ChronoSeal: "Rebirth.1",
	CriticalPrism: "Artifact.1",
	StarDrive: "World.1",
	QuantumCatalyst: "Lab.1",
	VaultHeart: "Core.1",
	SingularityCore: "Brand.1",
	Omniframe: "Loadout.1",
};

export function itemIconKind(definitionId: string, slot?: string): string {
	return (ITEM_ICONS[definitionId] as string | undefined) ?? (slot === "Machine" ? "Forge.item" : "Research.item");
}

interface RewardLike {
	Cores?: number;
	Stardust?: number;
	Boost?: unknown;
	FreeSpins?: unknown;
	Keys?: unknown;
	CashMinutes?: number;
	Signals?: unknown;
	CommandXP?: unknown;
	Essence?: unknown;
}

// Luau truthiness on reward fields (0 counts as present).
const set = (value: unknown) => value !== undefined && value !== false;

export function rewardIconKind(reward: RewardLike): string {
	if (set(reward.Cores)) return "Core.reward";
	if (set(reward.Stardust)) return "Dust.reward";
	if (set(reward.Boost)) return "Boost.reward";
	if (set(reward.FreeSpins)) return "Wheel.reward";
	if (set(reward.Keys)) return "Crate.reward";
	if (set(reward.CashMinutes)) return "Flux.reward";
	if (set(reward.Signals) || set(reward.CommandXP)) return "Command.reward";
	if (set(reward.Essence)) return "Artifact.reward";
	return "Gift.reward";
}

export function prizeShapeFromReward(reward: RewardLike | undefined, rarity: string): string {
	if (rarity.upper() === "MYTHIC") {
		return "jackpot";
	}
	if (reward?.Boost !== undefined) {
		return "boost";
	}
	if (reward?.Cores !== undefined && (reward.Cores ?? 0) > 0) {
		return "core";
	}
	if (
		reward?.Stardust !== undefined &&
		(reward.Stardust ?? 0) > 0 &&
		(reward.CashMinutes === undefined || reward.CashMinutes === 0)
	) {
		return "dust";
	}
	return "flux";
}

function GlyphFace({
	kind,
	color,
	transparency = 0,
}: {
	kind: unknown;
	color?: Color3;
	transparency?: number | React.Binding<number>;
}) {
	return <VectorIconFace kind={kind} color={color} transparency={transparency} />;
}

function semanticIconColor(kind: unknown): Color3 {
	switch (kind) {
		case "Dust":
		case "Forge":
		case "Milestone":
		case "Wheel":
		case "Gift":
		case "Shop":
		case "Jackpot":
		case "Collect":
		case "Code":
		case "Calendar":
			return Palette.mango;
		case "Core":
		case "Research":
		case "StarGrid":
		case "Anomaly":
		case "Artifact":
		case "Rebirth":
		case "Continuum":
		case "Inventory":
		case "Crate":
			return Palette.violet;
		case "Close":
		case "Hide":
		case "Lock":
		case "Admin":
			return Palette.coral;
		case "Check":
		case "Crew":
		case "Guild":
		case "Games":
		case "Boost":
		case "Play":
		case "Visit":
			return Palette.mint;
		case "Brand":
		case "Mission":
		case "Guide":
		case "Settings":
		case "Credits":
		case "Story":
		case "Lab":
		case "Rewards":
		case "Domain":
		case "Wave":
			return Palette.pink;
		default:
			return Palette.cyan;
	}
}

function coloredFace(kind: unknown, requested: Color3 | undefined): Color3 {
	return requested ?? semanticIconColor(kind);
}

export function PlayerMark({
	userId,
	accent,
	color = Palette.cream,
	size = 28,
	position,
	anchorPoint,
}: {
	userId: number;
	accent?: Color3;
	color?: Color3;
	size?: number;
	position?: UDim2;
	anchorPoint?: Vector2;
}) {
	const seed = math.abs(math.floor(userId));
	const mark = "Pilot.mark";
	if (artFor(mark)[0] !== undefined) {
		return <Icon kind={mark} size={size} position={position} anchorPoint={anchorPoint} />;
	}
	return (
		<frame
			Size={UDim2.fromOffset(size, size)}
			Position={position}
			AnchorPoint={anchorPoint}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ClipsDescendants={true}
		>
			<frame
				Size={UDim2.fromScale(0.82, 0.82)}
				Position={new UDim2(0.5, seed % 2 === 0 ? 1 : -1, 0.5, 1)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
			>
				<GlyphFace kind="Pilot" color={color} transparency={0.38} />
			</frame>
			<frame
				Size={UDim2.fromScale(0.82, 0.82)}
				Position={UDim2.fromScale(0.5, 0.5)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
			>
				<GlyphFace kind="Pilot" color={accent} />
			</frame>
		</frame>
	);
}

// Every icon id (a concept, a dot, then its use) has its own art in IconManifest: a body and a
// light layer that moves (spin, pulse, twinkle, bob, beat or a glint sweep). One shared clock
// drives every mounted icon at 30 fps; reduced motion holds them still. Ids that aren't drawn yet
// fall back to their concept's base icon, then to the old vector atlas.
const [iconClock, setIconClock] = React.createBinding(0);
let iconUsers = 0;
let iconConnection: RBXScriptConnection | undefined;
let iconLast = 0;

function useIconClock(enabled: boolean): React.Binding<number> {
	React.useEffect(() => {
		if (!enabled) {
			return undefined;
		}
		iconUsers += 1;
		if (iconConnection === undefined) {
			iconConnection = RunService.Heartbeat.Connect(() => {
				const now = os.clock();
				if (now - iconLast >= 1 / 30) {
					iconLast = now;
					setIconClock(now);
				}
			});
		}
		return () => {
			iconUsers -= 1;
			if (iconUsers <= 0 && iconConnection !== undefined) {
				iconConnection.Disconnect();
				iconConnection = undefined;
				iconUsers = 0;
			}
		};
	}, [enabled]);
	return iconClock;
}

function conceptOf(kind: unknown): string {
	return typeIs(kind, "string") ? ((kind.match("^[^.]+")[0] as string | undefined) ?? kind) : "Guide";
}
export { conceptOf as iconConcept };

type IconEntry = NonNullable<(typeof IconManifest.Icons)[string]>;

function artFor(kind: unknown): LuaTuple<[IconEntry?, string?, string?]> {
	const icons = IconManifest.Icons;
	const entry = icons[kind as string] ?? icons[conceptOf(kind)];
	if (entry === undefined) {
		return $tuple(undefined);
	}
	const sheet = IconManifest.Sheets[entry.b[0]] as string | undefined;
	const lightSheet = IconManifest.Sheets[entry.l[0]] as string | undefined;
	if (sheet === undefined || sheet === "" || lightSheet === undefined || lightSheet === "") {
		return $tuple(undefined);
	}
	return $tuple(entry, sheet, lightSheet);
}

export interface IconProps {
	kind: unknown;
	size?: number;
	spin?: boolean;
	hoverAmount?: React.Binding<number>;
	position?: UDim2;
	anchorPoint?: Vector2;
	color?: Color3;
	accent?: Color3;
}

export function Icon(props: IconProps) {
	const { kind, size = 28, spin = true, hoverAmount, position, anchorPoint } = props;
	const settings = useMotionSettings();
	const motionScale = settings.motionScale ?? 1;
	const [entry, sheet, lightSheet] = artFor(kind);
	const still = motionScale < 0.05 || settings.reducedMotion === true;
	const clock = useIconClock(entry !== undefined && !still);
	if (entry === undefined) {
		// not drawn yet: the old flat glyph
		return (
			<frame Size={UDim2.fromOffset(size, size)} Position={position} AnchorPoint={anchorPoint} BackgroundTransparency={1}>
				<GlyphFace kind={conceptOf(kind)} color={props.color ?? coloredFace(conceptOf(kind), props.accent)} />
			</frame>
		);
	}
	const cell = IconManifest.Cell;
	const anim = entry.a;
	const phase = entry.p * 10;
	const speed = entry.s * (spin ? 1 : 0.5);
	const hover = hoverAmount;
	const t = (now: number) => (now + phase) * speed;
	const lift =
		anim === "bob"
			? clock.map((now) => new UDim2(0.5, 0, 0.5, math.sin(t(now) * 2.2) * size * 0.04))
			: UDim2.fromScale(0.5, 0.5);
	let scale = clock.map((now) => {
		let s = 1;
		if (anim === "beat") {
			const q = (t(now) * 0.8) % 1;
			s += q < 0.12 ? math.sin((q / 0.12) * math.pi) * 0.07 : 0;
		} else if (anim === "pulse") {
			s += math.sin(t(now) * 3) * 0.025;
		}
		return s;
	});
	if (hover !== undefined) {
		scale = React.joinBindings([scale, hover]).map((v) => v[0] + math.clamp(v[1], 0, 1) * 0.06);
	}
	const lightTransparency = clock.map((now) => {
		const x = t(now);
		if (anim === "pulse") {
			return 0.3 - math.sin(x * 3) * 0.3;
		} else if (anim === "twinkle") {
			return math.clamp(0.15 + math.sin(x * 5.3) * 0.25 + math.sin(x * 8.1) * 0.2, 0, 0.9);
		}
		return 0.12;
	});
	const light = (
		<imagelabel
			Size={UDim2.fromScale(1, 1)}
			Position={UDim2.fromScale(0.5, 0.5)}
			AnchorPoint={new Vector2(0.5, 0.5)}
			BackgroundTransparency={1}
			Image={lightSheet}
			ImageRectOffset={new Vector2(entry.l[1], entry.l[2])}
			ImageRectSize={new Vector2(cell, cell)}
			ImageTransparency={still ? 0.12 : lightTransparency}
			Rotation={anim === "spin" && !still ? clock.map((now) => (t(now) * 36) % 360) : 0}
			ZIndex={2}
		>
			{anim === "shine" && !still && (
				<uigradient
					// a glint crossing the light layer every few seconds
					Transparency={
						new NumberSequence([
							new NumberSequenceKeypoint(0, 0.55),
							new NumberSequenceKeypoint(0.45, 0.55),
							new NumberSequenceKeypoint(0.5, 0),
							new NumberSequenceKeypoint(0.55, 0.55),
							new NumberSequenceKeypoint(1, 0.55),
						])
					}
					Rotation={35}
					Offset={clock.map((now) => {
						const q = (t(now) * 0.35) % 1;
						return new Vector2(-1 + q * 2.6, 0);
					})}
				/>
			)}
		</imagelabel>
	);
	return (
		<frame
			Size={UDim2.fromOffset(size, size)}
			Position={position}
			AnchorPoint={anchorPoint}
			BackgroundTransparency={1}
			BorderSizePixel={0}
		>
			<frame
				Size={UDim2.fromScale(1, 1)}
				Position={still ? UDim2.fromScale(0.5, 0.5) : lift}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundTransparency={1}
			>
				<uiscale Scale={still ? 1 : scale} />
				<imagelabel
					Size={UDim2.fromScale(1, 1)}
					BackgroundTransparency={1}
					Image={sheet}
					ImageRectOffset={new Vector2(entry.b[1], entry.b[2])}
					ImageRectSize={new Vector2(cell, cell)}
					ZIndex={1}
				/>
				{light}
			</frame>
		</frame>
	);
}

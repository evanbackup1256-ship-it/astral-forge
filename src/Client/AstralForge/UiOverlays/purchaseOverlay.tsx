import React from "@rbxts/react";
import ReactRoblox from "@rbxts/react-roblox";
import { Audio } from "../AudioKit/audio";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { Layout, Palette } from "../CoreKit/theme";
import { useViewport } from "../MotionKit/motion";
import { isReducedMotion } from "../MotionPreference";
import { Badge, IconTile, Panel, Text } from "../UiCore/ui";

// Purchase status. It sits where the game's notices play (top centre, just under the top bar)
// instead of covering the shop, and reads left to right: what you're buying, what it costs, where it's at.
// Pending shows three hopping dots and a sliding hairline; the result swaps the dots for a status
// badge and the hairline becomes a bar that drains until the card leaves on its own.

const Players = game.GetService("Players");
const RunService = game.GetService("RunService");
const UserInputService = game.GetService("UserInputService");

const PURCHASE_RESULT_HOLD = 2.2;
const PURCHASE_RESULT_HOLD_REDUCED = 1.8;
const PURCHASE_PENDING_FAILSAFE = 45;

const CARD_H = 84;
const ICON = 52;
const DOT = 7;
const RIGHT_W = 96;

interface PurchaseItem {
	name: string;
	price?: string;
	icon?: string;
	accent?: Color3;
}

interface PurchaseOverlayProps {
	phase: string;
	reducedMotion?: boolean;
	detail?: string;
	item?: PurchaseItem;
	onDismiss?: () => void;
}

function usePhaseClock(phase: string, stopAfter: number): React.Binding<number> {
	const [t, setT] = React.useBinding(0);
	React.useEffect(() => {
		setT(0);
		if (phase === "hidden") {
			return undefined;
		}
		let elapsed = 0;
		const conn = RunService.RenderStepped.Connect((dt) => {
			elapsed += dt;
			setT(elapsed);
			if (phase !== "pending" && elapsed > stopAfter) {
				conn.Disconnect();
			}
		});
		return () => conn.Disconnect();
	}, [phase]);
	return t;
}

function Dot(props: { index: number; t: React.Binding<number>; still: boolean; color: Color3 }) {
	const i = props.index;
	const hop = props.t.map((t) => {
		const cycle = (t * 1.5 - i * 0.15) % 1;
		const p = cycle < 0 ? cycle + 1 : cycle;
		return p < 0.4 ? math.sin((p / 0.4) * math.pi) : 0;
	});
	return (
		<frame
			Size={UDim2.fromOffset(DOT, DOT)}
			AnchorPoint={new Vector2(0.5, 0.5)}
			Position={hop.map((h) => new UDim2(0.5, (i - 1) * (DOT + 6), 0.5, props.still ? 0 : -math.floor(h * 6)))}
			BackgroundColor3={props.color}
			BackgroundTransparency={hop.map((h) => (props.still ? 0.6 - h * 0.5 : 0.15 - h * 0.15))}
			BorderSizePixel={0}
			ZIndex={14}
		>
			<uicorner CornerRadius={new UDim(1, 0)} />
		</frame>
	);
}

function PurchaseOverlay(props: PurchaseOverlayProps) {
	const phase = props.phase;
	const still = props.reducedMotion === true || isReducedMotion();
	const visible = phase !== "hidden";
	const result = phase === "success" || phase === "fail";
	const hold = still ? PURCHASE_RESULT_HOLD_REDUCED : PURCHASE_RESULT_HOLD;
	const t = usePhaseClock(phase, hold);
	const viewport = useViewport();
	const dismissRef = React.useRef(props.onDismiss);
	dismissRef.current = props.onDismiss;
	const hostRef = React.useRef<TextButton>();

	React.useEffect(() => {
		if (phase === "success") {
			Audio.play("purchaseResult");
		} else if (phase === "fail") {
			Audio.play("error");
		}
		if (!result) {
			return undefined;
		}
		const job = task.delay(hold, () => dismissRef.current?.());
		return () => {
			pcall(task.cancel, job);
		};
	}, [phase]);

	React.useEffect(() => {
		if (!result || !UserInputService.GamepadEnabled || hostRef.current === undefined) {
			return undefined;
		}
		GamepadNavigationService.FocusClaim(hostRef.current);
		return undefined;
	}, [result]);

	const playerGui = Players.LocalPlayer?.FindFirstChildOfClass("PlayerGui");
	if (!visible || playerGui === undefined) {
		return undefined;
	}

	const item = props.item;
	const itemAccent = item?.accent ?? Palette.mango;
	const statusAccent = phase === "success" ? Palette.mint : phase === "fail" ? Palette.coral : itemAccent;
	const name = item?.name ?? "Purchase";
	const line =
		phase === "pending"
			? "Confirm it in the Roblox window."
			: phase === "success"
				? "It's on your account now."
				: props.detail ?? "Nothing was charged.";

	const width = math.min(380, viewport.width - 24);
	const top = Layout.topbarHeight + 12;

	const enter = t.map((s) => (still || result ? 1 : math.clamp(s / 0.22, 0, 1)));
	const settle = t.map((s) => (still || !result ? 0 : math.max(0, 1 - s / 0.3)));
	// hairline: pending slides a short segment across; a result drains from full over the hold time
	const barSize = t.map((s) => (phase === "pending" ? new UDim2(0.28, 0, 0, 2) : new UDim2(math.clamp(1 - s / hold, 0, 1), 0, 0, 2)));
	const barPos = t.map((s) => {
		if (phase !== "pending") {
			return UDim2.fromOffset(0, 0);
		}
		const sweep = (s * 0.7) % 1;
		return new UDim2(sweep * 1.28 - 0.28, 0, 0, 0);
	});

	const dismiss = () => {
		if (result) {
			Audio.play("purchaseExit");
			dismissRef.current?.();
		}
	};

	return ReactRoblox.createPortal(
		<screengui
			key="AstralForgePurchase"
			DisplayOrder={8500}
			IgnoreGuiInset={false}
			ResetOnSpawn={false}
			ZIndexBehavior={Enum.ZIndexBehavior.Sibling}
		>
			<Panel
				size={UDim2.fromOffset(width, CARD_H)}
				position={enter.map((a) => new UDim2(0.5, -width / 2, 0, top - math.floor((1 - a) * 12)))}
				accent={statusAccent}
				background={Palette.panelRaised}
				padding={0}
				reveal={enter}
				highlight={phase === "success"}
				reducedMotion={still}
				clips={true}
				zIndex={10}
			>
				<uiscale Scale={settle.map((s) => 1 + s * 0.025)} />
				<IconTile
					kind={item?.icon ?? "Shop.1"}
					accent={itemAccent}
					size={ICON}
					position={UDim2.fromOffset(16, (CARD_H - ICON) / 2)}
					reducedMotion={still}
					zIndex={12}
				/>
				<Text
					value={name}
					size={16}
					minSize={12}
					color={Palette.cream}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					position={UDim2.fromOffset(16 + ICON + 14, 18)}
					sizeConstraint={new UDim2(1, -(16 + ICON + 14 + RIGHT_W + 12), 0, 22)}
					zIndex={12}
				/>
				<Text
					value={line}
					size={12}
					minSize={10}
					color={phase === "fail" ? Palette.coral : Palette.creamSoft}
					wrap={true}
					position={UDim2.fromOffset(16 + ICON + 14, 42)}
					sizeConstraint={new UDim2(1, -(16 + ICON + 14 + RIGHT_W + 12), 0, 30)}
					zIndex={12}
				/>
				{/* right column: price over the live status */}
				<frame
					Size={UDim2.fromOffset(RIGHT_W, CARD_H - 24)}
					Position={new UDim2(1, -(RIGHT_W + 14), 0, 12)}
					BackgroundTransparency={1}
					ZIndex={12}
				>
					{item?.price !== undefined && (
						<Badge value={item.price} accent={itemAccent} size={UDim2.fromOffset(RIGHT_W, 22)} zIndex={13} />
					)}
					{phase === "pending" ? (
						<frame Size={UDim2.fromOffset(RIGHT_W, 22)} Position={UDim2.fromOffset(0, 32)} BackgroundTransparency={1} ZIndex={13}>
							<Dot index={0} t={t} still={still} color={itemAccent} />
							<Dot index={1} t={t} still={still} color={itemAccent} />
							<Dot index={2} t={t} still={still} color={itemAccent} />
						</frame>
					) : (
						<Badge
							value={phase === "success" ? "BOUGHT" : "NOT BOUGHT"}
							accent={statusAccent}
							filled={true}
							size={UDim2.fromOffset(RIGHT_W, 22)}
							position={UDim2.fromOffset(0, 32)}
							zIndex={13}
						/>
					)}
				</frame>
				<frame
					Size={barSize}
					Position={barPos.map((p) => new UDim2(p.X.Scale, 0, 1, -2))}
					BackgroundColor3={statusAccent}
					BackgroundTransparency={0.2}
					BorderSizePixel={0}
					ZIndex={13}
				/>
				<textbutton
					ref={hostRef}
					Size={UDim2.fromScale(1, 1)}
					BackgroundTransparency={1}
					Text=""
					Selectable={result}
					Active={result}
					ZIndex={15}
					Event={{ Activated: dismiss }}
				/>
			</Panel>
		</screengui>,
		playerGui,
	);
}

export { PurchaseOverlay, PURCHASE_RESULT_HOLD, PURCHASE_RESULT_HOLD_REDUCED, PURCHASE_PENDING_FAILSAFE };

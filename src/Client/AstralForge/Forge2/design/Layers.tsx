// Things that float above the page: Modal (B closes it), Toast stack, Tooltip, and EmptyState.
import React from "@rbxts/react";
import { useBack } from "../input/input";
import { useStagger } from "../../MotionKit/motion";
import { MotionFX, usePresenceOf } from "../motion/motion";
import { Button } from "./Button";
import { Panel } from "./Panel";
import { Text, Title } from "./Text";
import { gap, Iron, Type } from "./tokens";
import type { Toast } from "../store/store";

export interface ModalProps {
	open: boolean;
	title: string;
	onClose: () => void;
	phone: boolean;
	children?: React.ReactNode;
}

export function Modal(props: ModalProps) {
	const [presence, mounted] = usePresenceOf(props.open);
	useBack(props.open, props.onClose);
	React.useEffect(() => {
		if (props.open) MotionFX.play("modeSwitch");
	}, [props.open]);
	if (!mounted) return undefined;
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Iron.void()} BackgroundTransparency={presence.map((p) => 1 - p * 0.45)} ZIndex={50}>
			<textbutton Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} Text="" Selectable={false} Event={{ Activated: props.onClose }} />
			<frame
				Size={new UDim2(props.phone ? 0.94 : 0, props.phone ? 0 : 520, 0, 0)}
				AutomaticSize={Enum.AutomaticSize.Y}
				Position={presence.map((p) => new UDim2(0.5, 0, 0.5, (1 - p) * 24))}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundTransparency={1}
				ZIndex={51}
			>
				<uiscale Scale={presence.map((p) => 0.94 + p * 0.06)} />
				<Panel pad={gap(props.phone, "l")} spacing={gap(props.phone, "m")} seam>
					<Title text={props.title} size={Type.title(props.phone)} order={0} />
					<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
						<uilistlayout Padding={new UDim(0, 10)} SortOrder={Enum.SortOrder.LayoutOrder} />
						{props.children}
					</frame>
					<Button text="Close" tone="iron" onPress={props.onClose} order={2} />
				</Panel>
			</frame>
		</frame>
	);
}

const TONE_ACCENT: Record<string, () => Color3> = {
	Info: Iron.steel,
	Success: Iron.brass,
	Warning: Iron.ember,
	Special: Iron.brass,
};

function ToastRow(props: { toast: Toast; index: number; phone: boolean }) {
	const rise = useStagger(props.index, false, 0.03, 0.2);
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.toast.id}>
			<uiscale Scale={rise.map((p) => 0.9 + p * 0.1)} />
			<Panel pad={12} spacing={2} color={Iron.raised()} seam={props.toast.tone === "Special"}>
				<Text text={props.toast.title} size={Type.body(props.phone)} color={(TONE_ACCENT[props.toast.tone] ?? Iron.steel)()} order={0} />
				{props.toast.body !== "" && <Text text={props.toast.body} size={Type.small(props.phone)} color={Iron.soft()} multiline order={1} />}
			</Panel>
		</frame>
	);
}

export function ToastStack(props: { toasts: ReadonlyArray<Toast>; phone: boolean; bottom: number }) {
	return (
		<frame
			Size={new UDim2(0, props.phone ? 300 : 360, 1, 0)}
			Position={new UDim2(1, -12, 1, -props.bottom)}
			AnchorPoint={new Vector2(1, 1)}
			BackgroundTransparency={1}
			ZIndex={60}
		>
			<uilistlayout Padding={new UDim(0, 8)} VerticalAlignment={Enum.VerticalAlignment.Bottom} SortOrder={Enum.SortOrder.LayoutOrder} />
			{props.toasts.map((toast, index) => (
				<ToastRow key={`t${toast.id}`} toast={toast} index={index} phone={props.phone} />
			))}
		</frame>
	);
}

/** Wrap anything to give it a hover / gamepad-selection tip. */
export function Tooltip(props: { tip: string; size: UDim2; order?: number; children?: React.ReactNode }) {
	const [shown, setShown] = React.useState(false);
	return (
		<frame
			Size={props.size}
			BackgroundTransparency={1}
			LayoutOrder={props.order ?? 0}
			Event={{ MouseEnter: () => setShown(true), MouseLeave: () => setShown(false) }}
		>
			{props.children}
			{shown && (
				<frame Size={UDim2.fromOffset(240, 0)} AutomaticSize={Enum.AutomaticSize.Y} Position={new UDim2(0.5, 0, 0, -6)} AnchorPoint={new Vector2(0.5, 1)} BackgroundTransparency={1} ZIndex={70}>
					<Panel pad={10} color={Iron.sunk()}>
						<Text text={props.tip} size={13} color={Iron.soft()} multiline />
					</Panel>
				</frame>
			)}
		</frame>
	);
}

export interface EmptyStateProps {
	title: string;
	body?: string;
	action?: { text: string; onPress: () => void };
	phone: boolean;
	order?: number;
}

/** Settles in with a slight tilt, like the old empty screens. */
export function EmptyState(props: EmptyStateProps) {
	const settle = useStagger(0, false, 0, 0.35);
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.order ?? 0}>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} Rotation={settle.map((p) => (1 - p) * -2.5)}>
				<uiscale Scale={settle.map((p) => 0.96 + p * 0.04)} />
				<Panel pad={gap(props.phone, "xl")} spacing={gap(props.phone, "m")} color={Iron.sunk()}>
					<Title text={props.title} size={Type.title(props.phone)} align="Center" tags={["floatwave"]} order={0} />
					{props.body !== undefined && <Text text={props.body} size={Type.body(props.phone)} color={Iron.muted()} align="Center" multiline order={1} />}
					{props.action !== undefined && <Button text={props.action.text} onPress={props.action.onPress} order={2} />}
				</Panel>
			</frame>
		</frame>
	);
}

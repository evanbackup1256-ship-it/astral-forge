// The Forge2 HUD shell: currency bar on top, the nav rail (desktop) or tab bar (phone), one page,
// and the toast stack. Phones get a bottom tab bar sized from the shared mobile layout plan.
import React from "@rbxts/react";
import { compactNumber } from "../../CoreKit/format";
import { chromeFor, MobileChrome } from "../../CoreKit/theme";
import { useChangePop, useViewport } from "../../MotionKit/motion";
import { RainbowGradient } from "../../UiCore/rainbowFx";
import { EmptyState, Modal, ToastStack } from "../design/Layers";
import { Tab } from "../design/Pick";
import { Text } from "../design/Text";
import { Fonts, gap, HIT, Iron } from "../design/tokens";
import { useInputKind, useRegion } from "../input/input";
import { labelOf, navGroups, PHONE_TABS } from "../router/routes";
import { Router } from "../router/Router";
import { RebirthCeremonyHost } from "../../UiCore/RebirthCeremony";
import type { Request } from "../store/net";
import { useForge, useForgeStore } from "../store/store";

function Readout(props: { label: string; value: unknown; color: Color3; order: number; phone: boolean }) {
	const text = compactNumber(props.value ?? 0);
	const pop = useChangePop(text);
	return (
		<frame Size={UDim2.fromOffset(props.phone ? 74 : 120, HIT)} BackgroundTransparency={1} LayoutOrder={props.order}>
			<uiscale Scale={pop} />
			<Text text={text} size={props.phone ? 18 : 22} font={Fonts.heavy} color={props.color} box={new UDim2(1, 0, 0, props.phone ? 24 : 28)} />
			{!props.phone && <Text text={props.label} size={12} color={Iron.muted()} box={new UDim2(1, 0, 0, 14)} position={UDim2.fromOffset(0, 28)} />}
		</frame>
	);
}

function TopBar(props: { phone: boolean; height: number }) {
	const session = useForge((s) => s.session);
	const region = useRegion("top");
	const pad = useInputKind() === "Gamepad";
	return (
		<frame ref={region} Size={new UDim2(1, 0, 0, props.height)} BackgroundColor3={Iron.sunk()} BorderSizePixel={0} ZIndex={10}>
			<uipadding PaddingLeft={new UDim(0, gap(props.phone, "m"))} PaddingRight={new UDim(0, gap(props.phone, "m"))} />
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, gap(props.phone, "m"))} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
			<Readout label="Flux" value={session?.Cash} color={Iron.text()} order={0} phone={props.phone} />
			<Readout label="Vault" value={session?.Vault} color={Iron.brass()} order={1} phone={props.phone} />
			<Readout label="Cores" value={session?.Cores} color={Iron.steel()} order={2} phone={props.phone} />
			{!props.phone && <Readout label="Stardust" value={session?.Stardust} color={Iron.ember()} order={3} phone={props.phone} />}
			{pad && <Text text="B  back" size={13} color={Iron.muted()} box={UDim2.fromOffset(70, 18)} order={9} />}
			<frame key="Seam" Size={new UDim2(1, 0, 0, 2)} Position={new UDim2(0, 0, 1, -2)} BackgroundColor3={Color3.fromRGB(255, 255, 255)} BorderSizePixel={0}>
				<RainbowGradient base={Iron.brass()} state={{ active: true }} style="flow" />
			</frame>
		</frame>
	);
}

function Rail(props: { page: string; navigate: (id: string) => void; width: number; top: number }) {
	const region = useRegion("nav");
	const groups = navGroups();
	return (
		<scrollingframe
			ref={region as never}
			Size={new UDim2(0, props.width, 1, -props.top)}
			Position={UDim2.fromOffset(0, props.top)}
			BackgroundColor3={Iron.sunk()}
			BackgroundTransparency={0.2}
			BorderSizePixel={0}
			CanvasSize={new UDim2()}
			AutomaticCanvasSize={Enum.AutomaticSize.Y}
			ScrollBarThickness={2}
		>
			<uipadding PaddingTop={new UDim(0, 16)} PaddingLeft={new UDim(0, 10)} PaddingRight={new UDim(0, 10)} PaddingBottom={new UDim(0, 16)} />
			<uilistlayout Padding={new UDim(0, 4)} SortOrder={Enum.SortOrder.LayoutOrder} />
			{groups.map((group, gi) => (
				<frame key={group.key} Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={gi}>
					<uilistlayout Padding={new UDim(0, 4)} SortOrder={Enum.SortOrder.LayoutOrder} />
					<Text text={group.label} size={12} color={Iron.muted()} box={new UDim2(1, 0, 0, 22)} order={0} />
					{group.routes.map((id, ri) => (
						<Tab key={id} text={labelOf(id)} active={props.page === id} onPress={() => props.navigate(id)} width={props.width - 20} order={ri + 1} />
					))}
				</frame>
			))}
		</scrollingframe>
	);
}

function TabBar(props: { page: string; navigate: (id: string) => void; chrome: MobileChrome; width: number }) {
	const region = useRegion("tabs");
	const slots = math.max(3, math.min(PHONE_TABS.size(), props.chrome.tabBarSlots));
	const tabs = PHONE_TABS.filter((_, i) => i < slots);
	const height = math.max(HIT + 12, props.chrome.tabBarH);
	return (
		<frame
			ref={region}
			Size={new UDim2(1, 0, 0, height + props.chrome.bottomSafe)}
			Position={new UDim2(0, 0, 1, 0)}
			AnchorPoint={new Vector2(0, 1)}
			BackgroundColor3={Iron.sunk()}
			BorderSizePixel={0}
			ZIndex={10}
		>
			<uipadding PaddingTop={new UDim(0, 6)} PaddingLeft={new UDim(0, 6)} PaddingRight={new UDim(0, 6)} />
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} HorizontalAlignment={Enum.HorizontalAlignment.Center} Padding={new UDim(0, 4)} SortOrder={Enum.SortOrder.LayoutOrder} />
			{tabs.map((id, i) => (
				<Tab key={id} text={labelOf(id)} active={props.page === id} onPress={() => props.navigate(id)} width={math.floor((props.width - 12 - (tabs.size() - 1) * 4) / tabs.size())} order={i} />
			))}
		</frame>
	);
}

export function Shell(props: { request: Request; config: Record<string, unknown> }) {
	const store = useForgeStore();
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const phone = chrome.stack;
	const page = useForge((s) => s.page);
	const session = useForge((s) => s.session);
	const toasts = useForge((s) => s.toasts);
	const busy = useForge((s) => s.busy);
	const shutdown = useForge((s) => s.shutdown);
	const navigate = React.useCallback((id: string) => store.update(() => ({ page: id })), [store]);
	const topH = phone ? 52 : 64;
	const railW = phone ? 0 : 196;
	const bottomH = phone ? math.max(HIT + 12, chrome.tabBarH) + chrome.bottomSafe : 0;
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Iron.void()} BorderSizePixel={0}>
			<TopBar phone={phone} height={topH} />
			{!phone && <Rail page={page} navigate={navigate} width={railW} top={topH} />}
			{session === undefined ? (
				<frame Size={new UDim2(1, 0, 1, -topH)} Position={UDim2.fromOffset(0, topH)} BackgroundTransparency={1}>
					<uipadding PaddingTop={new UDim(0, 48)} PaddingLeft={new UDim(0, 16)} PaddingRight={new UDim(0, 16)} />
					<EmptyState title="Lighting the forge" body="Loading your save." phone={phone} />
				</frame>
			) : (
				<Router
					page={page}
					size={new UDim2(1, -railW, 1, -topH - bottomH)}
					position={UDim2.fromOffset(railW, topH)}
					inner={{ session, config: props.config, request: props.request, navigate, phone, chrome, busy }}
				/>
			)}
			{phone && <TabBar page={page} navigate={navigate} chrome={chrome} width={viewport.width} />}
			<ToastStack toasts={toasts} phone={phone} bottom={bottomH + 12} />
			{/* the shared rebirth ceremony, full screen above everything (B skips) */}
			<RebirthCeremonyHost />
			<Modal open={shutdown !== undefined} title="Server restarting" onClose={() => store.update(() => ({ shutdown: undefined }))} phone={phone}>
				<Text text={shutdown ?? ""} size={16} color={Iron.soft()} multiline />
			</Modal>
		</frame>
	);
}

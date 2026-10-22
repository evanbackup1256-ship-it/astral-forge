// Forge overview, rebuilt on Forge2: one big vault number, collect and overcharge, the run toward
// the next rebirth, and the rates. Same remotes as before (CollectVault, Overcharge).
import React from "@rbxts/react";
import { Audio } from "../../AudioKit/audio";
import { AppHelpers } from "../../CoreKit/appNav";
import { asFlux, compactNumber, gteFlux } from "../../CoreKit/format";
import * as VaultCollectEligibility from "../../CoreKit/vaultCollectEligibility";
import { useChangePop, useFlash, useStagger } from "../../MotionKit/motion";
import { Button } from "../design/Button";
import { ForgeButton } from "../design/ForgeButton";
import { Meter, Panel } from "../design/Panel";
import { Chip } from "../design/Pick";
import { Text, Title } from "../design/Text";
import { Tooltip } from "../design/Layers";
import { Fonts, gap, HIT, Iron, Type } from "../design/tokens";
import { Burst, MotionFX } from "../motion/motion";
import type { PageProps } from "../router/routes";
import { ChargeDial, RebirthChamber, rebirthOf, RebirthSession } from "./rebirth/RebirthChamber";

interface OverviewSession {
	Vault?: unknown;
	Capacity?: unknown;
	Production?: unknown;
	TapPower?: unknown;
	RunCash?: unknown;
	PrestigeReward?: unknown;
	NextPrestigeTarget?: unknown;
	Machines?: Record<string, number>;
	Flags?: { TutorialDone?: boolean };
	FeatureUnlocks?: Record<string, { Unlocked?: boolean }>;
	Overcharge?: { Combo?: number; ComboMultiplier?: number };
}

function Stat(props: { label: string; value: string; order: number; phone: boolean; tip: string }) {
	const reveal = useStagger(props.order + 2);
	const pop = useChangePop(props.value);
	return (
		<Tooltip tip={props.tip} size={new UDim2(props.phone ? 0.5 : 0.25, -10, 0, props.phone ? 64 : 76)} order={props.order}>
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} Position={reveal.map((p) => UDim2.fromOffset(0, (1 - p) * 10))}>
				<uiscale Scale={pop} />
				<Text text={props.value} size={props.phone ? 24 : 30} font={Fonts.heavy} box={new UDim2(1, 0, 0, props.phone ? 30 : 38)} />
				<Text text={props.label} size={Type.small(props.phone)} color={Iron.muted()} box={new UDim2(1, 0, 0, 18)} position={UDim2.fromOffset(0, props.phone ? 32 : 40)} />
			</frame>
		</Tooltip>
	);
}

export function OverviewPage(props: PageProps) {
	const s = props.session as unknown as OverviewSession;
	const phone = props.phone;
	const vault = asFlux(s.Vault);
	const canCollect = VaultCollectEligibility.isEligible(vault);
	const tutorialDone = s.Flags?.TutorialDone === true;
	const showOvercharge = tutorialDone && (s.Machines?.StellarCore ?? 0) >= 1;
	const canRebirth = gteFlux((s.PrestigeReward ?? 0) as number, 1);
	const target = math.max(1, asFlux(s.NextPrestigeTarget));
	const runFill = canRebirth ? 1 : asFlux(s.RunCash) / target;
	const vaultFill = asFlux(s.Vault) / math.max(1, asFlux(s.Capacity));
	const rebirthVisible = AppHelpers.featureUnlocked(s as never, "Rebirth");
	const [collects, setCollects] = React.useState(0);
	const [charges, setCharges] = React.useState(0);
	const collectFlash = useFlash(collects, false, 0.42);
	const chargeFlash = useFlash(charges, false, 0.3);
	const heroIn = useStagger(0);
	const vaultText = compactNumber(s.Vault ?? 0);
	const vaultPop = useChangePop(vaultText, false, 0.1);
	const combo = s.Overcharge?.Combo ?? 0;
	const [chamber, setChamber] = React.useState(false);
	const rebirth = rebirthOf(props.session as unknown as RebirthSession);
	const starsWaiting = (rebirth.Pending ?? []).size();
	const idle = React.useBinding(0)[0];

	const collect = () => {
		if (!canCollect) return;
		setCollects((n) => n + 1);
		Burst.gain(`+${vaultText} flux`, Iron.steel(), "Flux.19");
		Audio.play("vaultBank");
		props.request("CollectVault");
	};
	const overcharge = () => {
		setCharges((n) => n + 1);
		if (s.TapPower !== undefined) Burst.spark(Iron.ember(), 0.9);
		Audio.play("reactorPulse");
		props.request("Overcharge", {}, (reply) => {
			if (reply.ok === true && combo >= 9) MotionFX.play("confirm");
		});
	};

	const space = gap(phone, "l");
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
			<uipadding PaddingTop={new UDim(0, space)} PaddingBottom={new UDim(0, space * 2)} PaddingLeft={new UDim(0, space)} PaddingRight={new UDim(0, space)} />
			<uilistlayout Padding={new UDim(0, space)} SortOrder={Enum.SortOrder.LayoutOrder} />

			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0} Position={heroIn.map((p) => UDim2.fromOffset(0, (1 - p) * 16))}>
				<Panel pad={gap(phone, "xl")} spacing={gap(phone, "m")} seam={canCollect} scale={collectFlash.map((v) => 1 + v * 0.02)}>
					<Title text="The Forge" size={Type.title(phone)} tags={["wave"]} order={0} />
					<frame Size={new UDim2(1, 0, 0, Type.hero(phone) + 8)} BackgroundTransparency={1} LayoutOrder={1}>
						<uiscale Scale={vaultPop} />
						<Text text={vaultText} size={Type.hero(phone)} font={Fonts.heavy} color={Iron.brass()} box={UDim2.fromScale(1, 1)} />
					</frame>
					<Meter value={vaultFill} order={2} height={phone ? 8 : 10} />
					<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={3}>
						<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 10)} SortOrder={Enum.SortOrder.LayoutOrder} />
						<Button text="Collect" onPress={collect} disabled={!canCollect} width={phone ? 150 : 200} height={phone ? 52 : 56} textSize={20} order={0} />
						{showOvercharge && (
							<frame Size={UDim2.fromOffset(phone ? 150 : 200, phone ? 52 : 56)} BackgroundTransparency={1} LayoutOrder={1}>
								<uiscale Scale={chargeFlash.map((v) => 1 + v * 0.06)} />
								<Button text={combo > 1 ? `Overcharge ×${combo}` : "Overcharge"} tone="ember" onPress={overcharge} stretch height={phone ? 52 : 56} textSize={20} />
							</frame>
						)}
					</frame>
				</Panel>
			</frame>

			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 10)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<Stat label="per second" value={compactNumber(s.Production ?? 0)} order={0} phone={phone} tip="Flux your machines make every second." />
				<Stat label="vault size" value={compactNumber(s.Capacity ?? 0)} order={1} phone={phone} tip="The vault stops filling when it's full." />
				<Stat label="per tap" value={compactNumber(s.TapPower ?? 0)} order={2} phone={phone} tip="What one overcharge adds." />
				<Stat label="this run" value={compactNumber(s.RunCash ?? 0)} order={3} phone={phone} tip="Flux earned since your last rebirth." />
			</frame>

			{rebirthVisible && (
				<Panel pad={gap(phone, "l")} spacing={gap(phone, "m")} order={2} seam={canRebirth} rarity="Mythic">
					<frame Size={new UDim2(1, 0, 0, 56)} BackgroundTransparency={1} LayoutOrder={0}>
						<ChargeDial size={56} fill={math.clamp(runFill, 0, 1)} charge={idle} color={canRebirth ? Iron.brass() : Iron.ember()} />
						<frame Size={new UDim2(1, -(phone ? 190 : 240), 1, 0)} Position={UDim2.fromOffset(72, 0)} BackgroundTransparency={1}>
							<Text text={canRebirth ? `+${compactNumber(s.PrestigeReward ?? 0)} cores` : `${math.floor(math.clamp(runFill, 0, 1) * 100)}%`} size={Type.title(phone)} font={Fonts.heavy} box={new UDim2(1, 0, 0, 30)} />
							<Text text={canRebirth ? "rebirth" : `of ${compactNumber(target)}`} size={Type.small(phone)} color={Iron.muted()} box={new UDim2(1, 0, 0, 16)} position={UDim2.fromOffset(0, 34)} />
						</frame>
						<frame Size={UDim2.fromOffset(phone ? 110 : 150, HIT)} Position={new UDim2(1, 0, 0.5, 0)} AnchorPoint={new Vector2(1, 0.5)} BackgroundTransparency={1}>
							<ForgeButton
								text={canRebirth ? "Rebirth" : starsWaiting > 0 ? "Star" : "Plan"}
								tone={canRebirth || starsWaiting > 0 ? "ember" : "iron"}
								stretch
								glint={canRebirth}
								onPress={() => {
									Audio.play("page");
									setChamber(true);
								}}
							/>
						</frame>
					</frame>
					<Meter value={runFill} color={Iron.ember()} order={1} />
				</Panel>
			)}

			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={3}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<Chip text="Relics" on={false} onPress={() => props.navigate("Inventory")} order={0} />
				<Chip text="Workshop" on={false} onPress={() => props.navigate("Workshop")} order={1} />
				<Chip text="Missions" on={false} onPress={() => props.navigate("Missions")} order={2} />
			</frame>
		</scrollingframe>
		<RebirthChamber
			open={chamber}
			session={props.session as unknown as RebirthSession}
			config={props.config}
			request={props.request}
			phone={phone}
			onClose={() => setChamber(false)}
		/>
		</frame>
	);
}

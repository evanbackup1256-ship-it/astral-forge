// Purpose: 01-hud-session quick actions, bottom-left of the Overview workspace on desktop:
// Collect (banks the vault) and the running boost with its time left (opens the boosts list).
// Phones keep MobileQuickActions; this one is desktop only.
import React from "@rbxts/react";
import { asFlux, clockText, compactNumber, Flux } from "../CoreKit/format";
import { Palette } from "../CoreKit/theme";
import { Button } from "./ui";

const Workspace = game.GetService("Workspace");

export interface HudBoost {
	Name?: string;
	Multiplier?: Flux;
	Color?: Color3;
}

export function HudQuickActions(props: {
	vault: unknown;
	dispatch: (action: string, payload?: object) => void;
	boost?: HudBoost;
	boostEndsAt: number;
	openBoosts: () => void;
	reducedMotion?: boolean;
	zIndex?: number;
}) {
	const [now, setNow] = React.useState(() => Workspace.GetServerTimeNow());
	const boostLive = props.boost !== undefined && props.boostEndsAt > now;
	React.useEffect(() => {
		if (props.boost === undefined) {
			return undefined;
		}
		let alive = true;
		task.spawn(() => {
			while (alive) {
				setNow(Workspace.GetServerTimeNow());
				task.wait(1);
			}
		});
		return () => {
			alive = false;
		};
	}, [props.boost, props.boostEndsAt]);
	const vault = asFlux(props.vault as Flux);
	const vaultReady = vault >= 1;
	const collectW = 132;
	const boostW = 156;
	const h = 40;
	const multiplier = props.boost?.Multiplier;
	const boostText = boostLive
		? `${multiplier !== undefined ? `Boost x${compactNumber(multiplier)}` : props.boost!.Name ?? "Boost"} · ${clockText(math.max(0, props.boostEndsAt - now))}`
		: "Boosts";
	return (
		<frame
			key="HudQuickActions"
			Size={UDim2.fromOffset(collectW + 10 + boostW, h)}
			AnchorPoint={new Vector2(0, 1)}
			Position={new UDim2(0, 16, 1, -16)}
			BackgroundTransparency={1}
			ZIndex={props.zIndex ?? 26}
		>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 10)} SortOrder={Enum.SortOrder.LayoutOrder} />
			<frame Size={UDim2.fromOffset(collectW, h)} BackgroundTransparency={1} LayoutOrder={1}>
				<Button
					text={vaultReady ? `Collect ${compactNumber(vault)}` : "Vault empty"}
					icon="Flux.22"
					onClick={() => props.dispatch("CollectVault")}
					color={vaultReady ? Palette.mango : Palette.panelSoft}
					textColor={vaultReady ? Palette.ink : Palette.muted}
					disabled={!vaultReady}
					size={UDim2.fromScale(1, 1)}
					reducedMotion={props.reducedMotion}
				/>
			</frame>
			<frame Size={UDim2.fromOffset(boostW, h)} BackgroundTransparency={1} LayoutOrder={2}>
				<Button
					text={boostText}
					icon="Boost.1"
					onClick={props.openBoosts}
					color={boostLive ? Palette.cyan : Palette.panelSoft}
					textColor={boostLive ? Palette.ink : Palette.cream}
					size={UDim2.fromScale(1, 1)}
					reducedMotion={props.reducedMotion}
				/>
			</frame>
		</frame>
	);
}

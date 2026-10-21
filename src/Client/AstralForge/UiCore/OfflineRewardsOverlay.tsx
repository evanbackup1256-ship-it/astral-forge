import React from "@rbxts/react";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { Flux, asFlux, clockText, compactNumber } from "../CoreKit/format";
import { Palette, TapTarget, chromeFor } from "../CoreKit/theme";
import {
	revealOffset,
	usePresence,
	useGlowStroke,
	useStagger,
	useViewport,
} from "../MotionKit/motion";
import { joinTuple } from "../lua";
import { Button, IconTile, OverlayPresence, Text, pixelPosition, useGamepadAutofocus, useGuiSize } from "./ui";
import { SHELL_PAD_KEYS, usePadSink } from "../CoreKit/padSink";

const h = React.createElement as unknown as (component: unknown, props?: object, ...children: unknown[]) => React.Element;

const UserInputService = game.GetService("UserInputService");

const AstralForge = script.Parent!.Parent!;
const loadKit = (name: string) => require(AstralForge.WaitForChild(name) as ModuleScript) as (member: string) => unknown;

interface AudioApi {
	play(name: string): void;
	playCelebration(cues: string[], delay?: number): void;
}
const Audio = (loadKit("AudioKit")("audio") as { Audio: AudioApi }).Audio;
const NumberSpinnerHost = (loadKit("ReactHosts")("NumberSpinnerHost") as { NumberSpinnerHost: unknown }).NumberSpinnerHost;

function StatTile(_param: { label: string; value: string; color: Color3; index: number; reducedMotion?: boolean }) {
	const label = _param.label;
	const value = _param.value;
	const color = _param.color;
	const index = _param.index;
	const reducedMotion = _param.reducedMotion;
	const reveal = useStagger(index, reducedMotion, 0.07, 0.22);
	return h(
		"frame",
		{
			Size: new UDim2(0.25, -6, 1, 0),
			Position: new UDim2(index * 0.25, index === 0 ? 0 : 6, 0, 0),
			BackgroundColor3: Palette.ink,
			BackgroundTransparency: reveal.map((amount) => 1 - amount),
			BorderSizePixel: 0,
		},
		h("uicorner", {
			CornerRadius: new UDim(0, 10),
		}),
		h(Text, {
			value: label,
			size: 9,
			color: Palette.muted,
			weight: Enum.FontWeight.Heavy,
			align: Enum.TextXAlignment.Center,
			fit: true,
			minSize: 9,
			position: UDim2.fromOffset(2, 8),
			sizeConstraint: new UDim2(1, -4, 0, 14),
		}),
		h(Text, {
			value: value,
			size: value.size() > 6 ? 11 : 12,
			color: color,
			weight: Enum.FontWeight.Heavy,
			align: Enum.TextXAlignment.Center,
			fit: true,
			minSize: 9,
			position: UDim2.fromOffset(2, 28),
			sizeConstraint: new UDim2(1, -4, 0, 28),
		}),
	);
}

interface OfflineRewardsOverlayProps {
	reward: Flux;
	seconds: number;
	efficiency: number;
	capped?: boolean;
	reducedMotion?: boolean;
	effectsEnabled?: boolean;
	production?: Flux;
	awaySeconds?: number;
	capHours?: number;
	vault?: Flux;
	onCollect: () => void;
	onClose: () => void;
	waiting?: string[];
	spinNote?: string;
	onCollectAll?: (bankVault: boolean) => void;
}

export function OfflineRewardsOverlay(_param: OfflineRewardsOverlayProps) {
	// the shell's pad shortcuts stay quiet while the rewards card is up
	usePadSink(true, "AstralForgeOfflineRewardsSink", SHELL_PAD_KEYS);
	const reward = _param.reward;
	const seconds = _param.seconds;
	const efficiency = _param.efficiency;
	const capped = _param.capped;
	const reducedMotion = _param.reducedMotion;
	const softMotion = reducedMotion;
	const effectsEnabled = _param.effectsEnabled;
	const production = _param.production;
	const awaySeconds = _param.awaySeconds;
	const capHours = _param.capHours;
	const vault = _param.vault;
	const onCollect = _param.onCollect;
	const onClose = _param.onClose;
	const waiting = _param.waiting ?? [];
	const spinNote = _param.spinNote;
	const onCollectAll = _param.onCollectAll;
	const hasExtras = waiting.size() > 0;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const stack = chrome.stack || viewport.width < 720;
	const [motion, closing, beginExit] = usePresence(softMotion);
	const padFocus = useGamepadAutofocus(true);
	const overlayHostRef = React.useRef<GuiObject>();
	const parentSize = useGuiSize(overlayHostRef, true);
	React.useEffect(() => {
		GamepadNavigationService.BeginOverlayFocus();
		return () => {
			GamepadNavigationService.EndOverlayFocus();
		};
	}, []);
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = overlayHostRef.current ?? padFocus.current;
		if (host === undefined) {
			return undefined;
		}
		const job = task.defer(() => {
			if (host.Parent === undefined) {
				return;
			}
			GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			task.cancel(job);
		};
	}, []);
	const bankedSeconds = math.max(0, seconds);
	const actualAway = math.max(bankedSeconds, awaySeconds ?? bankedSeconds);
	const hoursCap = math.max(1, capHours ?? math.floor(bankedSeconds / 3600 + 0.49));
	const efficiencyPct = math.floor(math.clamp(efficiency, 0, 1) * 100 + 0.5);
	const rate = production !== undefined ? asFlux(production) : 0;
	const missedSeconds = math.max(0, actualAway - bankedSeconds);
	const missed = capped === true && rate > 0 ? rate * efficiency * missedSeconds : 0;
	const vaultAmount = asFlux(vault ?? 0);
	const canBankVault = vaultAmount >= 0.01;
	const rewardAmount = asFlux(reward);
	const bigHaul = rate > 0 && rewardAmount >= rate * 3600;
	const rewardGlow = useGlowStroke(bigHaul, softMotion, 0.35, 0.15, 0.62, 1.6);
	const cardWidth = math.min(stack ? math.max(280, viewport.width - chrome.sideSafe * 2 - 20) : 560, 560);
	// The card is as tall as the layout it can show: stats, the explanation and stacked buttons
	// when there is room, otherwise stats and side-by-side buttons with nothing left empty.
	const statsBottom = stack ? 224 : 222;
	const roomH = math.max(240, viewport.height - viewport.topInset - chrome.bottomSafe - 24);
	const fullInner = statsBottom + 48 + TapTarget * 2 + 8;
	const shortInner = statsBottom + 14 + TapTarget;
	const cardHeight =
		roomH >= fullInner + 28 ? math.min(math.max(stack ? 468 : 420, fullInner + 28), roomH) : math.min(shortInner + 28, roomH);
	const innerHeight = cardHeight - 28;
	const shortCard = innerHeight < fullInner;
	const tinyCard = shortCard && innerHeight < statsBottom + 10 + TapTarget;
	const finish = React.useCallback(
		(bankVault: boolean) => {
			if (closing) {
				return undefined;
			}
			Audio.play(bankVault ? "offlineCollect" : "close");
			if (bankVault) {
				if (hasExtras && onCollectAll !== undefined) onCollectAll(canBankVault);
				else if (canBankVault) onCollect();
			}
			beginExit(onClose);
		},
		[beginExit, closing, onClose, onCollect, onCollectAll, hasExtras, canBankVault],
	);
	// B does what the CLOSE / KEEP VAULT button does (the shell never sees it while the card is up)
	const finishRef = React.useRef(finish);
	finishRef.current = finish;
	React.useEffect(() => {
		const connection = UserInputService.InputBegan.Connect((input) => {
			if (input.KeyCode === Enum.KeyCode.ButtonB) {
				finishRef.current(false);
			}
		});
		return () => connection.Disconnect();
	}, []);
	React.useEffect(() => {
		if (bigHaul) {
			Audio.playCelebration(["offlineOpen", "discovery"], 0.12);
		} else {
			Audio.play("offlineOpen");
		}
	}, []);
	const cardPosition = joinTuple(motion, parentSize).map(
		(values) => pixelPosition(values[1] as Vector2, 0.5, 0, 0.5, revealOffset(values[0] as number)),
	);
	const scrim = motion.map((amount) => math.clamp(1 - amount * 0.78, 0.2, 1));
	const fade = motion.map((amount) => 1 - amount);
	const _exp = {
		label: "AWAY",
		value: clockText(actualAway),
		color: Palette.cyan,
	};
	// banked only differs from away when the offline cap cut it short; otherwise show the cap itself
	const _exp_1 =
		capped === true || bankedSeconds < actualAway - 1
			? {
					label: "BANKED",
					value: clockText(bankedSeconds),
					color: Palette.mint,
				}
			: {
					label: "LIMIT",
					value: `${hoursCap}h`,
					color: Palette.mint,
				};
	const _exp_2 = {
		label: "EFFICIENCY",
		value: `${efficiencyPct}%`,
		color: Palette.violet,
	};
	const _object = {
		label: "RATE",
		value: rate > 0 ? `${compactNumber(production ?? 0)}/s` : "—",
		color: Palette.mango,
	};
	const rows = [_exp, _exp_1, _exp_2, _object];
	const copy = capped
		? `Offline earnings cap out at ${hoursCap}h. ${
				missed > 0
					? `About ${compactNumber(missed)} flux was earned outside that window and missed.`
					: "Everything inside the window is already in your cash."
			}`
		: `Earned at ${efficiencyPct}% efficiency for ${clockText(bankedSeconds)}. That flux is already in your cash.`;
	// what else is waiting reads as one sentence, in place of the efficiency note
	let waitingText = "";
	if (hasExtras) {
		const list =
			waiting.size() === 1
				? waiting[0]
				: `${waiting.filter((_, i) => i < waiting.size() - 1).join(", ")} and ${waiting[waiting.size() - 1]}`;
		waitingText = `Also waiting: ${list}.`;
	}
	if (spinNote !== undefined) waitingText = waitingText === "" ? spinNote : `${waitingText} ${spinNote}`;
	const noteText = waitingText !== "" ? waitingText : copy;
	const _exp_3 = h("imagebutton", {
		Size: UDim2.fromScale(1, 1),
		BackgroundColor3: Palette.void,
		BackgroundTransparency: scrim,
		BorderSizePixel: 0,
		AutoButtonColor: false,
		Active: true,
		Selectable: false,
		ZIndex: 460,
	});
	const _exp_4 = h("uicorner", {
		CornerRadius: new UDim(0, 14),
	});
	const _exp_5 = h("uistroke", {
		Color: Palette.mint,
		Thickness: 2,
		Transparency: motion.map((amount) => 0.45 - amount * 0.28),
	});
	const _exp_6 = h(IconTile, {
		kind: "Gift",
		accent: Palette.mint,
		size: stack ? 40 : 48,
		radius: 14,
		position: UDim2.fromOffset(0, 0),
		glow: effectsEnabled === true || bigHaul,
		spin: false,
		reducedMotion: softMotion,
	});
	const _exp_7 = h(Text, {
		value: "WELCOME BACK",
		size: 11,
		color: Palette.mint,
		weight: Enum.FontWeight.Heavy,
		fit: true,
		minSize: 9,
		position: UDim2.fromOffset(56, 2),
		sizeConstraint: new UDim2(1, -70, 0, 16),
	});
	const _exp_8 = h(Text, {
		value: "The forge kept running.",
		size: stack ? 18 : 22,
		color: Palette.cream,
		weight: Enum.FontWeight.Heavy,
		fit: true,
		minSize: 14,
		position: UDim2.fromOffset(56, 20),
		sizeConstraint: new UDim2(1, -70, 0, 28),
	});
	const _exp_9 = h(
		"frame",
		{
			Size: new UDim2(1, 0, 0, stack ? 70 : 76),
			Position: UDim2.fromOffset(0, 64),
			BackgroundColor3: Palette.ink,
			BorderSizePixel: 0,
			ZIndex: 465,
		},
		h("uicorner", {
			CornerRadius: new UDim(0, 14),
		}),
		h("uistroke", {
			Color: Palette.mint,
			Thickness: 1.5,
			Transparency: rewardGlow,
			ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
		}),
		h(Text, {
			value: "ALREADY IN YOUR CASH",
			size: 10,
			color: Palette.creamSoft,
			weight: Enum.FontWeight.Heavy,
			fit: true,
			minSize: 9,
			position: UDim2.fromOffset(14, 10),
			sizeConstraint: new UDim2(1, -28, 0, 14),
		}),
		h(NumberSpinnerHost, {
			value: rewardAmount,
			reducedMotion: softMotion,
			duration: 0.85,
			prefix: "+",
			extraSuffix: " FLUX",
			spacedSuffix: true,
			size: stack ? 24 : 30,
			color: Palette.mint,
			position: UDim2.fromOffset(14, 28),
			sizeConstraint: UDim2.fromOffset(0, 40),
			autoWidth: true,
			zIndex: 466,
		}),
	);
	const _newValue = rows.map((row, index) =>
		h(StatTile, {
			key: row.label,
			label: row.label,
			value: row.value,
			color: row.color,
			index: index,
			reducedMotion: reducedMotion,
		}),
	);
	const _exp_10 = h(
		"frame",
		{
			Size: new UDim2(1, 0, 0, stack ? 78 : 70),
			Position: UDim2.fromOffset(0, stack ? 146 : 152),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			Visible: !tinyCard,
		},
		_newValue,
	);
	const _exp_11 = shortCard
		? undefined
		: h(Text, {
				value: noteText,
				size: 11,
				color: waitingText !== "" ? Palette.cream : Palette.creamSoft,
				wrap: true,
				fit: true,
				minSize: 9,
				position: new UDim2(0, 0, 1, -(TapTarget * 2 + 40)),
				sizeConstraint: new UDim2(1, 0, 0, 36),
			});
	let _result_1: React.Element;
	if (canBankVault || hasExtras) {
		const _attributes: Record<string, unknown> = {};
		_attributes.text = hasExtras ? "COLLECT ALL" : `BANK VAULT  ${compactNumber(vault ?? 0)}`;
		_attributes.icon = "Collect.3";
		_attributes.onClick = () => finish(true);
		_attributes.color = Palette.mint;
		_attributes.textColor = Palette.ink;
		_attributes.size = shortCard ? new UDim2(0.5, -5, 0, TapTarget) : new UDim2(1, 0, 0, TapTarget);
		_attributes.position = shortCard ? new UDim2(0, 0, 1, -TapTarget) : new UDim2(0, 0, 1, -(TapTarget * 2 + 8));
		_attributes.reducedMotion = reducedMotion;
		_attributes.disabled = closing;
		_attributes.highlight = true;
		_result_1 = h(Button, _attributes);
	} else {
		_result_1 = h(Button, {
			text: "CONTINUE",
			icon: "Collect.4",
			onClick: () => finish(false),
			color: Palette.mint,
			textColor: Palette.ink,
			size: shortCard ? new UDim2(0.5, -5, 0, TapTarget) : new UDim2(1, 0, 0, TapTarget),
			position: shortCard ? new UDim2(0, 0, 1, -TapTarget) : new UDim2(0, 0, 1, -(TapTarget * 2 + 8)),
			reducedMotion: reducedMotion,
			disabled: closing,
			highlight: true,
		});
	}
	return h(
		OverlayPresence,
		{
			amount: motion,
		},
		h(
			"frame",
			{
				Size: UDim2.fromScale(1, 1),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				ZIndex: 460,
				Visible: motion.map((amount) => amount > 0.004),
			},
			_exp_3,
			h(
				"frame",
				{
					ref: (node: GuiObject | undefined) => {
						padFocus.current = node;
						overlayHostRef.current = node;
					},
					Size: UDim2.fromOffset(cardWidth, cardHeight),
					Position: cardPosition,
					AnchorPoint: new Vector2(0.5, 0.5),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ZIndex: 461,
					Visible: motion.map((amount) => amount > 0.004),
				},
				h(
					"frame",
					{
						Size: UDim2.fromScale(1, 1),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						ZIndex: 461,
					},
					h(
						"frame",
						{
							Size: UDim2.fromScale(1, 1),
							BackgroundColor3: Palette.panelRaised,
							BackgroundTransparency: fade,
							BorderSizePixel: 0,
							ZIndex: 462,
							ClipsDescendants: true,
						},
						_exp_4,
						_exp_5,
						h(
							"frame",
							{
								Size: new UDim2(1, -28, 1, -28),
								Position: UDim2.fromOffset(14, 14),
								BackgroundTransparency: 1,
								BorderSizePixel: 0,
								ZIndex: 464,
							},
							_exp_6,
							_exp_7,
							_exp_8,
							_exp_9,
							_exp_10,
							_exp_11,
							_result_1,
							h(Button, {
								text: canBankVault ? "KEEP VAULT" : "CLOSE",
								icon: "Close.16",
								onClick: () => finish(false),
								color: Palette.panelSoft,
								textColor: Palette.cream,
								size: shortCard ? new UDim2(0.5, -5, 0, TapTarget) : new UDim2(1, 0, 0, TapTarget),
								position: shortCard ? new UDim2(0.5, 5, 1, -TapTarget) : new UDim2(0, 0, 1, -TapTarget),
								reducedMotion: reducedMotion,
								disabled: closing,
							}),
						),
					),
				),
			),
		),
	);
}

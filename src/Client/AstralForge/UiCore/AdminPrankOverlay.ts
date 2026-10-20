import React from "@rbxts/react";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { chromeFor, Palette, TapTarget } from "../CoreKit/theme";
import { useClock, useRotation, useViewport } from "../MotionKit/motion";
import { Button, Panel, Text } from "./ui";
import { SHELL_PAD_KEYS, usePadSink } from "../CoreKit/padSink";

const h = React.createElement as unknown as (component: unknown, props?: object, ...children: unknown[]) => React.Element;

const UserInputService = game.GetService("UserInputService");

const HUD_STAGE_KINDS: Record<string, boolean | undefined> = {
	InvertHud: true,
	SpinHud: true,
	TinyHud: true,
	GiantHud: true,
	JumbleHud: true,
	ShakeHud: true,
};

interface PrankCardProps {
	title: string;
	body: string;
	action: string;
	accent: Color3;
	height: number;
	reducedMotion?: boolean;
	onClose: () => void;
}

function PrankCard(param: PrankCardProps) {
	const title = param.title;
	const body = param.body;
	const action = param.action;
	const accent = param.accent;
	const height = param.height;
	const reducedMotion = param.reducedMotion;
	const onClose = param.onClose;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const width = chrome.stack ? new UDim2(1, -math.max(24, chrome.sideSafe * 2 + 16), 0, height) : new UDim2(0, 420, 0, height);
	return h(
		"frame",
		{
			Size: width,
			Position: UDim2.fromScale(0.5, 0.5),
			AnchorPoint: new Vector2(0.5, 0.5),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			ZIndex: 422,
		},
		h(
			Panel,
			{ size: UDim2.fromScale(1, 1), accent: accent, background: Palette.panelRaised, padding: 18, zIndex: 422, clips: false },
			h(Text, {
				value: "ASTRAL FORGE",
				size: 10,
				color: accent,
				weight: Enum.FontWeight.Heavy,
				sizeConstraint: new UDim2(1, 0, 0, 16),
			}),
			h(Text, {
				value: title,
				size: 20,
				color: Palette.cream,
				weight: Enum.FontWeight.Heavy,
				wrap: true, fit: true, minSize: 10,
				sizeConstraint: new UDim2(1, 0, 0, 48),
				position: UDim2.fromOffset(0, 22),
			}),
			h(Text, {
				value: body,
				size: 13,
				color: Palette.creamSoft,
				wrap: true, fit: true, minSize: 10,
				sizeConstraint: new UDim2(1, 0, 0, 72),
				position: UDim2.fromOffset(0, 74),
			}),
			h(Button, {
				text: action,
				onClick: onClose,
				color: accent,
				textColor: Palette.ink,
				size: new UDim2(1, 0, 0, TapTarget),
				position: new UDim2(0, 0, 1, -TapTarget),
				reducedMotion: reducedMotion,
				highlight: true,
			}),
		),
	);
}

function ConfettiBits() {
	const bits: React.Element[] = [];
	for (let index = 0; index <= 27; index++) {
		const accent =
			index % 4 === 0 ? Palette.mango : index % 4 === 1 ? Palette.cyan : index % 4 === 2 ? Palette.pink : Palette.violet;
		bits.push(
			h("frame", {
				key: `bit-${index}`,
				Size: UDim2.fromOffset(9 + (index % 3) * 3, 16 + (index % 2) * 6),
				Position: new UDim2(((index * 37) % 100) / 100, 0, ((index * 53) % 100) / 100, 0),
				Rotation: (index * 27) % 360,
				BackgroundColor3: accent,
				BorderSizePixel: 0,
				ZIndex: 421,
			}),
		);
	}
	return h(React.Fragment, undefined, bits);
}

export interface Prank {
	kind: string;
	endsAt: number;
	caption?: string;
	duration?: unknown;
}

export function HudPrankStage(param: { prank?: Prank; reducedMotion?: boolean; children?: unknown }) {
	const prank = param.prank;
	const reducedMotion = param.reducedMotion;
	const children = param.children;
	const kind = game.GetService("Workspace").GetAttribute("AstralForgeVRCanvasWidth") !== undefined && game.GetService("Workspace").GetAttribute("AstralForgeVRCanvasWidth") !== false
		? ""
		: prank?.kind ?? "";
	const spinning = kind === "SpinHud";
	const shaking = kind === "ShakeHud";
	const invert = kind === "InvertHud";
	const tiny = kind === "TinyHud";
	const giant = kind === "GiantHud";
	const jumbling = kind === "JumbleHud";
	const rotation = useRotation(spinning && !reducedMotion, 80);
	const shake = useClock(shaking && !reducedMotion, 16, math.pi * 2, true);
	const jumble = useClock(jumbling && !reducedMotion, 5, math.pi * 2, true);
	const frameRotation = spinning
		? reducedMotion
			? 24
			: rotation
		: invert
			? 180
			: jumbling
				? reducedMotion
					? 3
					: jumble.map((phase) => math.sin(phase * 7) * 5)
				: 0;
	const size = tiny ? UDim2.fromScale(0.4, 0.4) : giant ? UDim2.fromScale(1.82, 1.82) : UDim2.fromScale(1, 1);
	const restPosition = tiny || giant ? UDim2.fromScale(0.5, 0.5) : UDim2.fromScale(0, 0);
	const position =
		shaking && !reducedMotion
			? shake.map((phase) => new UDim2(0, math.sin(phase * 3.2) * 16, 0, math.cos(phase * 2.5) * 12))
			: jumbling && !reducedMotion
				? jumble.map((phase) => new UDim2(0, math.sin(phase * 11) * 12, 0, math.cos(phase * 13) * 8))
				: restPosition;
	const anchor = tiny || giant ? new Vector2(0.5, 0.5) : new Vector2(0, 0);
	return h(
		"frame",
		{
			Size: UDim2.fromScale(1, 1),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			ClipsDescendants: tiny || giant || shaking || jumbling,
		},
		h(
			"frame",
			{ Size: size, Position: position, AnchorPoint: anchor, Rotation: frameRotation, BackgroundTransparency: 1, BorderSizePixel: 0 },
			children,
		),
	);
}

export function AdminPrankOverlay(param: { prank: Prank; reducedMotion?: boolean; onClose: () => void }) {
	usePadSink(true, "AstralForgePrankSink", SHELL_PAD_KEYS);
	const prank = param.prank;
	const softMotion = param.reducedMotion;
	const onClose = param.onClose;
	const kind = prank.kind;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const overlayHostRef = React.useRef<Frame>();
	const toastInset = math.max(chrome.bottomSafe, viewport.bottomInset ?? 0, 8);
	const [now, setNow] = React.useState(os.clock());
	React.useEffect(() => {
		GamepadNavigationService.BeginOverlayFocus();
		return () => GamepadNavigationService.EndOverlayFocus();
	}, []);
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = overlayHostRef.current;
		if (host === undefined) {
			return undefined;
		}
		const job = task.defer(() => {
			if (host.Parent === undefined) {
				return;
			}
			GamepadNavigationService.FocusClaim(host);
		});
		return () => task.cancel(job);
	}, [prank.kind]);
	React.useEffect(() => {
		const worker = task.spawn(() => {
			while (os.clock() < prank.endsAt) {
				task.wait(0.2);
				setNow(os.clock());
			}
			onClose();
		});
		return () => task.cancel(worker);
	}, [onClose, prank.endsAt, prank.kind]);
	const left = math.max(0, prank.endsAt - now);
	const washOn = kind === "DiscoHud" || kind === "RainbowHud";
	const wash = useClock(washOn && !softMotion, 0.42, 1, true);
	const washColor = wash.map((alpha) => Color3.fromHSV(alpha, kind === "RainbowHud" ? 0.55 : 0.88, 1));
	const caption = prank.caption !== undefined && prank.caption !== "" ? prank.caption : "CLOWN";
	const prankDuration = typeIs(prank.duration, "number") ? prank.duration : 6;
	const prankRevealed = left <= math.min(2.5, prankDuration * 0.6);
	const stageOnly = HUD_STAGE_KINDS[kind] !== undefined;
	const blind = kind === "Blind";
	const jump = kind === "Jumpscare";
	const confetti = kind === "ConfettiStorm";
	const disco = kind === "DiscoHud";
	const rainbow = kind === "RainbowHud";
	const fakeRebirth = kind === "FakeRebirth";
	const fakeTrade = kind === "FakeTrade";
	const fakeRob = kind === "FakeRob";
	const fakeDrop = kind === "FakeRareDrop";
	const fakeEvent = kind === "FakeEvent";
	const clown = kind === "ClownTitle";
	const muteToasts = kind === "MuteToasts";
	const emptyBag = kind === "EmptyBagScare";
	const fill = jump ? Palette.coral : clown ? Palette.ink : Palette.void;
	const fillAlpha = blind
		? 0.04
		: fakeRebirth || fakeTrade || fakeRob || fakeDrop || fakeEvent || jump
			? 0.14
			: confetti
				? 0.78
				: disco || rainbow
					? 0.48
					: clown
						? 0.22
						: muteToasts
							? 1
							: emptyBag
								? 0.22
								: stageOnly
									? 0.86
									: 0.7;
	const banner = stageOnly
		? kind === "InvertHud"
			? "HUD INVERTED"
			: kind === "SpinHud"
				? "HUD SPINNING"
				: kind === "TinyHud"
					? "TINY HUD"
					: kind === "GiantHud"
						? "GIANT HUD"
						: kind === "JumbleHud"
							? "HUD MISALIGNED"
							: "HUD SHAKING"
		: undefined;
	const card = (title: string, body: string, action: string, accent: Color3, height: number) =>
		h(PrankCard, { title, body, action, accent, height, reducedMotion: softMotion, onClose });
	return h(
		"frame",
		{
			ref: overlayHostRef,
			Size: UDim2.fromScale(1, 1),
			BackgroundColor3: washOn ? washColor : fill,
			BackgroundTransparency: fillAlpha,
			BorderSizePixel: 0,
			ZIndex: 420,
		},
		banner !== undefined &&
			h(Text, {
				value: `${banner}  ${string.format("%.1f", left)}s`,
				size: 16,
				color: Palette.cyan,
				weight: Enum.FontWeight.Heavy,
				align: Enum.TextXAlignment.Center,
				sizeConstraint: new UDim2(1, -24, 0, 24),
				position: new UDim2(0, 12, 0.06, 0),
			}),
		jump && card("BEHIND YOU", "Got you. Admin's bored.", "OK FINE", Palette.coral, 240),
		fakeRebirth &&
			card(
				prankRevealed ? "RANK UNCHANGED" : "NEW ASCENSION READY",
				prankRevealed ? "No progress or currency changed." : "The next rank is ready. Review its rewards before starting over.",
				prankRevealed ? "CLOSE" : "REVIEW",
				Palette.violet,
				268,
			),
		fakeTrade &&
			card(
				prankRevealed ? "OFFER WITHDRAWN" : "INCOMING TRADE",
				prankRevealed ? "No trade session was opened and no relics moved." : "The Hollow Broker offers 3 Flux for your relic case.",
				prankRevealed ? "CLOSE" : "REVIEW OFFER",
				Palette.cyan,
				268,
			),
		fakeRob &&
			card(
				prankRevealed ? "VAULT CHECK COMPLETE" : "VAULT RECONCILIATION",
				prankRevealed ? "No balances changed." : "A relay reports a mismatch in your last vault deposit.",
				prankRevealed ? "CLOSE" : "CHECK BALANCE",
				Palette.mango,
				268,
			),
		fakeDrop &&
			card(
				prankRevealed ? "RELIC SIGNAL LOST" : "ASTRAL RELIC DISCOVERED",
				prankRevealed ? "No relic was added. Your case is unchanged." : "Mythic relic in the recovery beam. Grab it.",
				prankRevealed ? "CLOSE" : "OPEN RELIC CASE",
				Palette.mango,
				268,
			),
		fakeEvent &&
			card(
				prankRevealed ? "SIGNAL CLEARED" : "STARFALL EVENT INBOUND",
				prankRevealed ? "No server event started. The alert was a visual decoy." : caption,
				prankRevealed ? "CLOSE" : "TRACK SIGNAL",
				Palette.cyan,
				268,
			),
		confetti &&
			h(
				React.Fragment,
				undefined,
				h(ConfettiBits),
				h(Text, {
					value: "CONFETTI TAX",
					size: 32,
					color: Palette.mango,
					weight: Enum.FontWeight.Heavy,
					align: Enum.TextXAlignment.Center,
					sizeConstraint: new UDim2(1, -24, 0, 40),
					position: new UDim2(0, 12, 0.42, 0),
				}),
			),
		(disco || rainbow) &&
			h(Text, {
				value: disco ? "DISCO FORGE" : "RAINBOW WASH",
				size: 28,
				color: Palette.cream,
				weight: Enum.FontWeight.Heavy,
				align: Enum.TextXAlignment.Center,
				sizeConstraint: new UDim2(1, -24, 0, 36),
				position: new UDim2(0, 12, 0.44, 0),
			}),
		blind &&
			h(Text, {
				value: `LIGHTS OUT  ${string.format("%.1f", left)}s`,
				size: 16,
				color: Palette.creamSoft,
				weight: Enum.FontWeight.Bold,
				align: Enum.TextXAlignment.Center,
				sizeConstraint: new UDim2(1, -24, 0, 24),
				position: new UDim2(0, 12, 0.9, 0),
			}),
		clown &&
			h(Text, {
				value: string.upper(caption),
				size: 36,
				color: Palette.mango,
				weight: Enum.FontWeight.Heavy,
				wrap: true, fit: true, minSize: 10,
				align: Enum.TextXAlignment.Center,
				sizeConstraint: new UDim2(1, -32, 0, 120),
				position: new UDim2(0, 16, 0.38, 0),
			}),
		muteToasts &&
			h(
				"frame",
				{
					Size: UDim2.fromOffset(math.min(280, viewport.width - chrome.sideSafe * 2 - 24), 72),
					Position: new UDim2(1, -math.max(16, chrome.sideSafe), 1, -math.max(16, toastInset)),
					AnchorPoint: new Vector2(1, 1),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ZIndex: 430,
				},
				h(
					Panel,
					{ size: UDim2.fromScale(1, 1), accent: Palette.coral, background: Palette.panel, padding: 12, zIndex: 430, clips: false },
					h(Text, {
						value: "Ledger Sync",
						size: 13,
						color: Palette.cream,
						weight: Enum.FontWeight.Heavy,
						sizeConstraint: new UDim2(1, 0, 0, 18),
					}),
					h(Text, {
						value: "Vault storage verification in progress. Balances secured.",
						size: 11,
						color: Palette.creamSoft,
						wrap: true, fit: true, minSize: 9,
						sizeConstraint: new UDim2(1, 0, 0, 28),
						position: UDim2.fromOffset(0, 22),
					}),
				),
			),
		emptyBag &&
			card(
				"Relic Matrix",
				"Relic list refreshed.",
				"CONFIRM",
				Palette.violet,
				248,
			),
	);
}

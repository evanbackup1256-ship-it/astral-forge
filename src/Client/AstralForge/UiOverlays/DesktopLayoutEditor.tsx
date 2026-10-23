// Desktop HUD editor: drag the alert island and combo badge on an 8px grid, and tune the side
// menu, top bar and page width inside fixed limits. Changes preview live and save on Done.
import { glyphButton } from "../UiCore/glyphIcons";
import React from "@rbxts/react";
import { Audio } from "../AudioKit/audio";
import { DesktopLayout, DesktopLayoutValues, openDesktopEditor, setDesktopPreview, useSavedDesktopLayout } from "../CoreKit/desktopLayout";
import { EDIT_BOUNDS } from "../CoreKit/mobileLayout";
import { Palette } from "../CoreKit/theme";
import { usePresence } from "../MotionKit/motion";
import { useEventListener } from "../ReactHosts/reactModules";
import { Button, Panel, Text } from "../UiCore/ui";
import { MobileDragging } from "./MobileControls";

const UserInputService = game.GetService("UserInputService");

type Tab = "nav" | "top" | "island" | "combo" | "page";
const TABS: ReadonlyArray<{ id: Tab; label: string }> = [
	{ id: "nav", label: "Side menu" },
	{ id: "top", label: "Top bar" },
	{ id: "island", label: "Alerts" },
	{ id: "combo", label: "Combo" },
	{ id: "page", label: "Page" },
];
const CHIP_NAMES: Record<string, string> = { F: "Flux", C: "Cores", D: "Dust", E: "Event", P: "Companion" };
const CHIP_HIDE_KEY: Record<string, string | undefined> = { C: "top.hideCores", D: "top.hideDust", E: "top.hideEvent", P: "top.hideCompanion" };

const ISLAND_BOX = new Vector2(360, 44);
const COMBO_BOX = new Vector2(168, 44);
const PANEL_W = 616;
const PANEL_H = 250;

export interface DesktopLayoutEditorProps {
	dispatch: (action: string, payload?: object) => void;
	viewportWidth: number;
	viewportHeight: number;
	// where the floating pieces sit when docked
	islandDock: Vector2;
	comboDock: Vector2;
	onClose: () => void;
}

function DragBox(props: {
	id: "island" | "combo";
	box: Vector2;
	at: Vector2;
	viewport: Vector2;
	selected: boolean;
	onSelect: () => void;
	onMove: (topCenter: Vector2) => void;
}) {
	const { id, box, viewport } = props;
	const [pos, setPos] = React.useState(props.at);
	React.useEffect(() => setPos(props.at), [props.at]);
	const moveRef = React.useRef(props.onMove);
	moveRef.current = props.onMove;
	React.useEffect(() => {
		return MobileDragging.register({
			id: "desktop-" + id,
			position: props.at,
			snap: DesktopLayout.GRID,
			bounds: { minX: box.X / 2, maxX: math.max(box.X / 2, viewport.X - box.X / 2), minY: 0, maxY: math.max(0, viewport.Y - box.Y) },
			onMove: (moved) => {
				setPos(moved);
				moveRef.current(moved);
			},
		});
	}, [id, box, viewport, props.at]);
	return (
		<frame
			Size={UDim2.fromOffset(box.X, box.Y)}
			Position={UDim2.fromOffset(pos.X, pos.Y)}
			AnchorPoint={new Vector2(0.5, 0)}
			BackgroundColor3={EDIT_BOUNDS}
			BackgroundTransparency={props.selected ? 0.82 : 0.9}
			BorderSizePixel={0}
			Active={true}
			ZIndex={410}
			Event={{
				InputBegan: (_rbx, input) => {
					if (input.UserInputType === Enum.UserInputType.MouseButton1 || input.UserInputType === Enum.UserInputType.Touch) {
						props.onSelect();
						MobileDragging.beginDrag("desktop-" + id, input);
					}
				},
			}}
		>
			<uicorner CornerRadius={new UDim(0, 10)} />
			<uistroke Color={EDIT_BOUNDS} Thickness={props.selected ? 2 : 1} Transparency={props.selected ? 0 : 0.4} />
		</frame>
	);
}

function Stepper(props: { label: string; value: string; onLess: () => void; onMore: () => void; position: UDim2; lessOff?: boolean; moreOff?: boolean }) {
	return (
		<frame Size={UDim2.fromOffset(268, 36)} Position={props.position} BackgroundTransparency={1}>
			<Text value={props.label} size={13} color={Palette.muted} sizeConstraint={UDim2.fromOffset(120, 36)} fit={true} />
			<Button {...glyphButton("Minus", "−")} onClick={props.onLess} disabled={props.lessOff} size={UDim2.fromOffset(36, 36)} position={UDim2.fromOffset(124, 0)} outline={true} />
			<Text value={props.value} size={14} color={Palette.cream} align={Enum.TextXAlignment.Center} position={UDim2.fromOffset(164, 0)} sizeConstraint={UDim2.fromOffset(60, 36)} fit={true} />
			<Button {...glyphButton("Plus", "+")} onClick={props.onMore} disabled={props.moreOff} size={UDim2.fromOffset(36, 36)} position={UDim2.fromOffset(228, 0)} outline={true} />
		</frame>
	);
}

export function DesktopLayoutEditor(props: DesktopLayoutEditorProps) {
	const saved = useSavedDesktopLayout();
	const [draft, setDraft] = React.useState<DesktopLayoutValues>(saved);
	const [tab, setTab] = React.useState<Tab>("nav");
	const [presence, , begin] = usePresence(false);
	const viewport = React.useMemo(() => new Vector2(props.viewportWidth, props.viewportHeight), [props.viewportWidth, props.viewportHeight]);

	React.useEffect(() => {
		MobileDragging.setEditMode(true);
		return () => {
			MobileDragging.setEditMode(false);
			setDesktopPreview(undefined);
		};
	}, []);
	React.useEffect(() => setDesktopPreview(draft), [draft]);

	const change = (key: string, value: unknown) => setDraft((current) => DesktopLayout.SetValue(current, key, value));
	const step = (key: string, delta: number) => change(key, (draft[key] as number) + delta);
	const close = (save: boolean) => {
		if (save) {
			const encoded = DesktopLayout.Encode(draft);
			if (encoded !== DesktopLayout.Encode(saved)) {
				props.dispatch("SetMobileLayout", { Desktop: encoded });
			}
			Audio.play("dragDrop");
		} else {
			Audio.play("close");
		}
		begin(() => {
			setDesktopPreview(undefined);
			props.onClose();
		});
	};
	useEventListener(UserInputService.InputBegan, (input: InputObject, processed: boolean) => {
		if (!processed && input.KeyCode === Enum.KeyCode.Escape) close(false);
	});

	const spot = (id: "island" | "combo", dock: Vector2): Vector2 => {
		const x = draft[id + ".x"] as number;
		const y = draft[id + ".y"] as number;
		return x === DesktopLayout.DOCKED ? dock : new Vector2(math.floor(x * viewport.X + 0.5), math.floor(y * viewport.Y + 0.5));
	};
	const place = (id: "island" | "combo") => (topCenter: Vector2) => {
		setDraft((current) => {
			const withX = DesktopLayout.SetValue(current, id + ".x", topCenter.X / math.max(1, viewport.X));
			return DesktopLayout.SetValue(withX, id + ".y", topCenter.Y / math.max(1, viewport.Y));
		});
	};
	const islandScale = (draft["island.scale"] as number) / 100;
	const comboScale = (draft["combo.scale"] as number) / 100;
	const islandAt = React.useMemo(() => spot("island", props.islandDock), [draft["island.x"], draft["island.y"], props.islandDock, viewport]);
	const comboAt = React.useMemo(() => spot("combo", props.comboDock), [draft["combo.x"], draft["combo.y"], props.comboDock, viewport]);
	const islandBox = React.useMemo(() => ISLAND_BOX.mul(islandScale), [islandScale]);
	const comboBox = React.useMemo(() => COMBO_BOX.mul(comboScale), [comboScale]);

	const field = (key: string) => DesktopLayout.FIELDS.find((entry) => entry.key === key)!;
	const atMin = (key: string) => (draft[key] as number) <= (field(key).min ?? 0);
	const atMax = (key: string) => (draft[key] as number) >= (field(key).max ?? 100);
	const percent = (key: string) => `${draft[key]}%`;
	const row = (index: number) => UDim2.fromOffset(index % 2 === 0 ? 0 : 296, math.floor(index / 2) * 50);

	let body: React.Element;
	if (tab === "nav") {
		const right = draft["nav.side"] === 1;
		const collapsed = draft["nav.collapsed"] === 1;
		body = (
			<>
				<Button text={right ? "Right side" : "Left side"} icon="Menu.5" onClick={() => change("nav.side", right ? 0 : 1)} size={UDim2.fromOffset(268, 36)} position={row(0)} outline={true} />
				<Button text={collapsed ? "Icons only" : "Full labels"} onClick={() => change("nav.collapsed", collapsed ? 0 : 1)} size={UDim2.fromOffset(268, 36)} position={row(1)} outline={true} />
				<Stepper label="Width" value={(draft["nav.width"] as number) === 0 ? "Auto" : percent("nav.width")} position={row(2)} lessOff={atMin("nav.width") || collapsed}
					moreOff={atMax("nav.width") || collapsed} onLess={() => step("nav.width", -10)} onMore={() => step("nav.width", (draft["nav.width"] as number) === 0 ? 50 : 10)} />
			</>
		);
	} else if (tab === "top") {
		const order = draft["top.order"] as string;
		const letters: string[] = [];
		for (let index = 1; index <= order.size(); index++) letters.push(order.sub(index, index));
		const swap = (from: number, to: number) => {
			if (to < 0 || to >= letters.size()) return;
			const swapped = table.clone(letters);
			swapped[from] = letters[to];
			swapped[to] = letters[from];
			change("top.order", swapped.join(""));
		};
		body = (
			<>
				<Stepper label="Height" value={percent("top.height")} position={row(0)} lessOff={atMin("top.height")} moreOff={atMax("top.height")}
					onLess={() => step("top.height", -10)} onMore={() => step("top.height", 10)} />
				{letters.map((letter, index) => {
					const hideKey = CHIP_HIDE_KEY[letter];
					const hidden = hideKey !== undefined && draft[hideKey] === 1;
					return (
						<frame key={letter} Size={UDim2.fromOffset(268, 36)} Position={row(index + 1)} BackgroundTransparency={1}>
							<Button text="‹" onClick={() => swap(index, index - 1)} disabled={index === 0} size={UDim2.fromOffset(30, 36)} outline={true} />
							<Button text={CHIP_NAMES[letter]} onClick={() => hideKey !== undefined && change(hideKey, hidden ? 0 : 1)} disabled={hideKey === undefined}
								color={hidden ? Palette.panel : undefined} size={UDim2.fromOffset(196, 36)} position={UDim2.fromOffset(36, 0)} outline={hidden} />
							<Button text="›" onClick={() => swap(index, index + 1)} disabled={index === letters.size() - 1} size={UDim2.fromOffset(30, 36)} position={UDim2.fromOffset(238, 0)} outline={true} />
						</frame>
					);
				})}
			</>
		);
	} else if (tab === "island") {
		body = (
			<>
				<Stepper label="Size" value={percent("island.scale")} position={row(0)} lessOff={atMin("island.scale")} moreOff={atMax("island.scale")}
					onLess={() => step("island.scale", -5)} onMore={() => step("island.scale", 5)} />
				<Button text="Back to top bar" onClick={() => { change("island.x", -1); change("island.y", -1); }} disabled={draft["island.x"] === DesktopLayout.DOCKED}
					size={UDim2.fromOffset(268, 36)} position={row(1)} outline={true} />
			</>
		);
	} else if (tab === "combo") {
		const hidden = draft["combo.hidden"] === 1;
		body = (
			<>
				<Stepper label="Size" value={percent("combo.scale")} position={row(0)} lessOff={atMin("combo.scale")} moreOff={atMax("combo.scale")}
					onLess={() => step("combo.scale", -5)} onMore={() => step("combo.scale", 5)} />
				<Button text={hidden ? "Hidden" : "Shown"} icon="Hide.2" onClick={() => change("combo.hidden", hidden ? 0 : 1)} size={UDim2.fromOffset(268, 36)} position={row(1)} outline={true} />
				<Button text="Back to corner" onClick={() => { change("combo.x", -1); change("combo.y", -1); }} disabled={draft["combo.x"] === DesktopLayout.DOCKED}
					size={UDim2.fromOffset(268, 36)} position={row(2)} outline={true} />
			</>
		);
	} else {
		body = (
			<Stepper label="Max width" value={percent("page.width")} position={row(0)} lessOff={atMin("page.width")} moreOff={atMax("page.width")}
				onLess={() => step("page.width", -5)} onMore={() => step("page.width", 5)} />
		);
	}

	const panelX = math.floor((viewport.X - PANEL_W) / 2);
	const panelY = viewport.Y - PANEL_H - 24;
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.ink} BackgroundTransparency={presence.map((amount) => 1 - amount * 0.35)} BorderSizePixel={0} ZIndex={400} Active={false}>
			{(draft["combo.hidden"] !== 1 || tab === "combo") && (
				<DragBox id="combo" box={comboBox} at={comboAt} viewport={viewport} selected={tab === "combo"} onSelect={() => setTab("combo")} onMove={place("combo")} />
			)}
			<DragBox id="island" box={islandBox} at={islandAt} viewport={viewport} selected={tab === "island"} onSelect={() => setTab("island")} onMove={place("island")} />
			<Panel radius={18} rule size={UDim2.fromOffset(PANEL_W, PANEL_H)} position={presence.map((amount) => UDim2.fromOffset(panelX, panelY + (1 - amount) * 16))} background={Palette.panelRaised}
				padding={22} zIndex={420} reveal={presence} clips={false}>
				<frame Size={new UDim2(1, 0, 0, 32)} BackgroundTransparency={1}>
					{TABS.map((entry, index) => (
						<Button key={entry.id} text={entry.label} onClick={() => setTab(entry.id)} outline={tab !== entry.id} highlight={DesktopLayout.IsCustom(draft, entry.id)}
							size={UDim2.fromOffset(108, 32)} position={UDim2.fromOffset(index * 114, 0)} />
					))}
				</frame>
				<frame Size={new UDim2(1, 0, 0, 140)} Position={UDim2.fromOffset(0, 54)} BackgroundTransparency={1}>
					{body}
				</frame>
				<frame Size={new UDim2(1, 0, 0, 32)} Position={new UDim2(0, 0, 1, -32)} BackgroundTransparency={1}>
					<Button text="Reset" onClick={() => setDraft((current) => DesktopLayout.ResetElement(current, tab))} disabled={!DesktopLayout.IsCustom(draft, tab)}
						size={UDim2.fromOffset(96, 32)} outline={true} />
					<Button text="Reset all" onClick={() => setDraft(DesktopLayout.Defaults())} disabled={!DesktopLayout.IsCustom(draft)}
						size={UDim2.fromOffset(110, 32)} position={UDim2.fromOffset(104, 0)} outline={true} />
					<Button text="Cancel" onClick={() => close(false)} size={UDim2.fromOffset(100, 32)} position={new UDim2(1, -208, 0, 0)} outline={true} />
					<Button text="Done" onClick={() => close(true)} color={Palette.brass} textColor={Palette.ink} size={UDim2.fromOffset(100, 32)} position={new UDim2(1, -100, 0, 0)} />
				</frame>
			</Panel>
		</frame>
	);
}

export { openDesktopEditor };

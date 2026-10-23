// Companions: the elemental companions found on expeditions (Command artifacts). An owned grid of
// sprite cards, a large stage for the picked one (its sheet playing, bonus, level and sparks) with
// Equip and Feed, and the level-up row (sparks + stardust into the next level). Index shows every
// companion, unfound ones as a dim still. Uses the existing EquipArtifact / UpgradeArtifact actions.
import * as CompanionDrops from "../../../../Shared/AstralForge/Shared/CompanionDrops";
import React from "@rbxts/react";
import { compactNumber, Flux, gteFlux } from "../../CoreKit/format";
import { chromeFor, Palette, scrollTail, TapTarget } from "../../CoreKit/theme";
import { useEntrance, useFlash, useViewport } from "../../MotionKit/motion";
import { Rarity } from "../../../../Shared/AstralForge/Shared/ForgeTheme";
import { clientModule, kitMember, LuauComponent } from "../luauKits";
import { Bar, DiamondRule, Line, PanelHeading, PnSurface, spaced, TITLE_FACE } from "../../UiCore/mockKit";
import { MockBtn, MockRow, rowHeight } from "../mockRows";

const TweenService = game.GetService("TweenService");
import { MotionFX } from "../../UiCore/screenFx";

const { SegmentedTabs, Text } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");
const { PageScaffold } = kitMember<{ PageScaffold: LuauComponent }>("LayoutKit", "pageScaffold");
const ElementFxModule = clientModule<{
	ElementFx: LuauComponent;
	sheet: (this: void, element: unknown) => { Color: Color3; Label: string } | undefined;
}>("ElementFx");
const ElementFx = ElementFxModule.ElementFx;
const elementSheet = ElementFxModule.sheet;

const SERIF = Font.fromName("Merriweather", Enum.FontWeight.Bold);
const MAX_LEVEL = 10;

interface ArtifactDef {
	Id: string;
	Name: string;
	Rarity: string;
	Color: Color3;
	Element: unknown;
	Description?: string;
	EffectKind: string;
	EffectPerLevel: number;
}
interface Owned {
	Level: number;
	Fragments: number;
}
interface CompanionsProps {
	state: { Command?: { Artifacts?: Record<string, Owned | undefined>; EquippedArtifact?: string }; Stardust?: Flux; Companions?: Record<string, boolean> };
	config: { Operations?: { Artifacts?: ArtifactDef[] } };
	dispatch: (action: string, payload?: object, callback?: (response: { ok?: boolean }) => void) => unknown;
	reducedMotion?: boolean;
}

// "LEGENDARY" and "Legendary" both appear in config
function rarityName(raw: string): string {
	const lower = raw.lower();
	return lower.sub(1, 1).upper() + lower.sub(2);
}
function rarityColor(raw: string): Color3 {
	return Rarity[rarityName(raw)] ?? (rarityName(raw) === "Uncommon" ? Palette.mint : Palette.lineSoft);
}
const SHEEN_RARITIES = new Set(["Legendary", "Mythic", "Celestial", "Astral"]);

function effectText(artifact: ArtifactDef, level: number): string {
	if (artifact.EffectKind === "OfflineHours") {
		return `+${"%.1f".format(artifact.EffectPerLevel * level)}h offline`;
	}
	return `+${"%.0f".format(artifact.EffectPerLevel * level * 100)}%`;
}
const KIND_LABEL: Record<string, string | undefined> = {
	Production: "Production",
	Capacity: "Vault capacity",
	OfflineHours: "Offline time",
	Tap: "Tap power",
	Critical: "Critical chance",
	Crates: "Crate luck",
};
function kindLabel(kind: string): string {
	return KIND_LABEL[kind] ?? kind;
}
// costs mirror the server's UpgradeArtifact (CommandView shows the same numbers)
function sparkCost(level: number): number {
	return 4 + level * 2;
}
function dustCost(level: number): number {
	return 8 * level;
}

// ---------- SpriteCard (UiCore/SpriteCard.tsx per the port brief; page-local until it lands) ----------
interface SpriteCardProps {
	element: unknown;
	name: string;
	rarity: string;
	level?: number;
	selected: boolean;
	found: boolean;
	following: boolean;
	onSelect: () => void;
	size: UDim2;
	reducedMotion?: boolean;
	layoutOrder?: number;
}

function SpriteCard(props: SpriteCardProps) {
	const liftRef = React.useRef<Frame>();
	const gradientRef = React.useRef<UIGradient>();
	const color = props.found ? rarityColor(props.rarity) : Palette.line;
	const sheen = props.found && SHEEN_RARITIES.has(rarityName(props.rarity)) && !props.reducedMotion;
	// selected: 4 px lift, rim at alpha 1
	React.useEffect(() => {
		const host = liftRef.current;
		if (host === undefined) return;
		const target = UDim2.fromOffset(0, props.selected ? -4 : 0);
		if (props.reducedMotion) {
			host.Position = target;
			return;
		}
		const tween = MotionFX.tween(host, new TweenInfo(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position: target }, props.reducedMotion);
		return () => tween?.Cancel();
	}, [props.selected, props.reducedMotion]);
	// Legendary and above: a slow sheen across the rim, 4 s period
	React.useEffect(() => {
		const gradient = gradientRef.current;
		if (gradient === undefined || !sheen) return;
		gradient.Offset = new Vector2(-1, 0);
		const tween = TweenService.Create(gradient, new TweenInfo(4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
			Offset: new Vector2(1, 0),
		});
		tween.Play();
		return () => tween.Cancel();
	}, [sheen]);
	return (
		<frame Size={props.size} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={props.layoutOrder}>
			<frame ref={liftRef} Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.ink} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(0, 14)} />
				<uistroke Color={color} Thickness={1.5} Transparency={props.selected ? 0 : 0.4} ApplyStrokeMode={Enum.ApplyStrokeMode.Border}>
					{sheen && (
						<uigradient
							ref={gradientRef}
							Rotation={20}
							Transparency={
								new NumberSequence([
									new NumberSequenceKeypoint(0, 0),
									new NumberSequenceKeypoint(0.45, 0),
									new NumberSequenceKeypoint(0.5, 0.6),
									new NumberSequenceKeypoint(0.55, 0),
									new NumberSequenceKeypoint(1, 0),
								])
							}
							Color={
								new ColorSequence([
									new ColorSequenceKeypoint(0, color),
									new ColorSequenceKeypoint(0.5, Palette.cream),
									new ColorSequenceKeypoint(1, color),
								])
							}
						/>
					)}
				</uistroke>
				<frame
					key="BrassRule"
					Size={new UDim2(1, -6, 1, -6)}
					Position={UDim2.fromOffset(3, 3)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
				>
					<uicorner CornerRadius={new UDim(0, 11)} />
					<uistroke Color={Palette.brass} Thickness={1} Transparency={0.75} />
				</frame>
				<frame
					key="Well"
					Size={new UDim2(1, -12, 1, -50)}
					Position={UDim2.fromOffset(6, 6)}
					BackgroundColor3={Palette.void}
					BackgroundTransparency={0.2}
					BorderSizePixel={0}
					ClipsDescendants={true}
				>
					<uicorner CornerRadius={new UDim(0, 10)} />
					<uigradient
						Rotation={90}
						Color={new ColorSequence(color.Lerp(Palette.void, 0.82), Palette.void)}
					/>
					<ElementFx
						element={props.element}
						size={new UDim2(0.92, 0, 0.92, 0)}
						position={UDim2.fromScale(0.5, 0.52)}
						still={!props.found}
						transparency={props.found ? 0 : 0.72}
						tint={props.found ? undefined : Palette.void}
						reducedMotion={props.reducedMotion}
						reaction="select"
						reactionKey={props.selected}
					/>
					{props.level !== undefined && (
						<frame Size={UDim2.fromOffset(42, 18)} Position={UDim2.fromOffset(5, 5)} BackgroundColor3={Palette.void} BackgroundTransparency={0.15} BorderSizePixel={0}>
							<uicorner CornerRadius={new UDim(0, 6)} />
							<uistroke Color={Palette.line} Thickness={1} />
							<Text value={`Lv ${props.level}`} size={11} color={Palette.cream} weight={Enum.FontWeight.Bold} align={Enum.TextXAlignment.Center} sizeConstraint={UDim2.fromScale(1, 1)} />
						</frame>
					)}
					{props.following && (
						<frame Size={UDim2.fromOffset(10, 10)} Position={new UDim2(1, -15, 0, 9)} BackgroundColor3={Palette.mint} BorderSizePixel={0}>
							<uicorner CornerRadius={new UDim(1, 0)} />
						</frame>
					)}
				</frame>
				<Text
					value={props.found ? props.name : "Not found yet"}
					size={12}
					color={props.found ? Palette.cream : Palette.muted}
					weight={Enum.FontWeight.Bold}
					align={Enum.TextXAlignment.Center}
					fit={true}
					minSize={9}
					position={new UDim2(0, 6, 1, -42)}
					sizeConstraint={new UDim2(1, -12, 0, 16)}
				/>
				<frame
					Size={UDim2.fromOffset(math.max(44, rarityName(props.rarity).size() * 7 + 14), 15)}
					Position={new UDim2(0.5, 0, 1, -22)}
					AnchorPoint={new Vector2(0.5, 0)}
					BackgroundColor3={color}
					BackgroundTransparency={props.found ? 0.15 : 0.7}
					BorderSizePixel={0}
				>
					<uicorner CornerRadius={new UDim(0, 4)} />
					<Text
						value={rarityName(props.rarity).upper()}
						size={9}
						color={Palette.ink}
						weight={Enum.FontWeight.Heavy}
						align={Enum.TextXAlignment.Center}
						sizeConstraint={UDim2.fromScale(1, 1)}
					/>
				</frame>
			</frame>
			<textbutton
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				Text=""
				ZIndex={10}
				Event={{ Activated: () => props.onSelect() }}
			/>
		</frame>
	);
}

// ---------- header ----------
function HeaderStars(props: { reducedMotion?: boolean }) {
	// 7 dots, alpha tweened on their own 2 to 5 s periods; still under reduced motion
	const refs = React.useRef<Frame[]>([]);
	const spots = [
		[0.52, 0.22],
		[0.58, 0.62],
		[0.63, 0.35],
		[0.69, 0.78],
		[0.74, 0.18],
		[0.9, 0.3],
		[0.97, 0.7],
	];
	React.useEffect(() => {
		if (props.reducedMotion) return;
		const tweens: Tween[] = [];
		refs.current.forEach((dot, index) => {
			const tween = MotionFX.tween(dot, new TweenInfo(2 + ((index * 7) % 4), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				BackgroundTransparency: 0.85,
			}, false);
			if (tween) tweens.push(tween);
		});
		return () => tweens.forEach((tween) => tween.Cancel());
	}, [props.reducedMotion]);
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={0}>
			{spots.map((spot, index) => (
				<frame
					key={`Star${index}`}
					ref={(dot: Frame | undefined) => {
						if (dot) refs.current[index] = dot;
					}}
					Size={UDim2.fromOffset(index % 3 === 0 ? 3 : 2, index % 3 === 0 ? 3 : 2)}
					Position={UDim2.fromScale(spot[0], spot[1])}
					BackgroundColor3={Palette.cream}
					BackgroundTransparency={0.3}
					BorderSizePixel={0}
				/>
			))}
		</frame>
	);
}

const TABS = [
	{ id: "Owned", label: "Owned" },
	{ id: "Index", label: "Index" },
];

export function CompanionsView(props: CompanionsProps) {
	const { state, config, dispatch, reducedMotion } = props;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const stack = chrome.contentStack;
	const enter = useEntrance(reducedMotion);
	const [tab, setTab] = React.useState("Owned");
	const [picked, setPicked] = React.useState<string | undefined>(undefined);
	const [busy, setBusy] = React.useState(false);
	const [equipNonce, setEquipNonce] = React.useState(0);
	const ring = useFlash(equipNonce, reducedMotion === true, 0.6);

	const defs = config.Operations?.Artifacts ?? [];
	const owned = state.Command?.Artifacts ?? {};
	const following = state.Command?.EquippedArtifact;
	const ownedDefs = defs.filter((artifact) => owned[artifact.Id] !== undefined);
	const shown = tab === "Owned" ? ownedDefs : defs;
	// named companions from crate drops sit after the expedition ones; they only follow the crate odds
	const ownedNamedSet = state.Companions ?? {};
	const ownedNamed = CompanionDrops.COMPANION_DROPS.filter((drop) => ownedNamedSet[drop.Key] === true);
	const shownNamed = tab === "Owned" ? ownedNamed : CompanionDrops.COMPANION_DROPS;
	const foundCount = ownedDefs.size() + ownedNamed.size();
	const totalCount = defs.size() + CompanionDrops.COMPANION_DROPS.size();
	let selected = defs.find((artifact) => artifact.Id === picked && owned[artifact.Id] !== undefined);
	if (selected === undefined) {
		selected = ownedDefs.find((artifact) => artifact.Id === following) ?? ownedDefs[0];
	}
	const followName = defs.find((artifact) => artifact.Id === following)?.Name;

	const cardW = stack ? 104 : 124;
	const cardH = stack ? 134 : 152;
	const gap = stack ? 10 : 12;
	const heroH = stack ? 64 : 118;

	const hero = (
		<PnSurface size={UDim2.fromScale(1, 1)} accent={Palette.brass} background={Palette.panelRaised} padding={stack ? 12 : 20} radius={18} reveal={enter} reducedMotion={reducedMotion} clips={true}>
			<HeaderStars reducedMotion={reducedMotion} />
			{!stack && (
				<Text value={`${foundCount} OF ${totalCount} FOUND`} size={11} color={Palette.mint} weight={Enum.FontWeight.Heavy} sizeConstraint={new UDim2(0.5, 0, 0, 14)} />
			)}
			<textlabel
				Text="Companions"
				FontFace={SERIF}
				TextSize={stack ? 24 : 34}
				TextColor3={Palette.cream}
				TextXAlignment={Enum.TextXAlignment.Left}
				BackgroundTransparency={1}
				Position={UDim2.fromOffset(0, stack ? 0 : 16)}
				Size={new UDim2(0, stack ? 180 : 360, 0, stack ? 30 : 42)}
			/>
			<Text
				value={followName !== undefined ? `${followName} is following you` : "Pick one to follow you around the forge"}
				size={stack ? 12 : 13}
				color={Palette.muted}
				fit={true}
				minSize={10}
				position={stack ? UDim2.fromOffset(0, 32) : UDim2.fromOffset(0, 60)}
				sizeConstraint={new UDim2(1, stack ? -190 : -320, 0, 18)}
			/>
			<SegmentedTabs
				options={TABS}
				value={tab}
				onChange={setTab}
				accent={Palette.mint}
				size={UDim2.fromOffset(stack ? 170 : 200, TapTarget)}
				position={new UDim2(1, stack ? -170 : -200, 0.5, -TapTarget / 2)}
				reducedMotion={reducedMotion}
			/>
		</PnSurface>
	);

	// mockup 14 right column: one .pn with the OWNED h3 + card wrap, a diamond rule, then the FUSE h3 + its row.
	// The game has no three-of-a-kind fuse action, so the row is the level-up (sparks + stardust -> next level).
	const fuseRowH = stack ? 96 : 120;
	const fuseH = 22 + 12 + fuseRowH;
	const fuseRow = (() => {
		if (selected === undefined) return undefined;
		const mine = owned[selected.Id]!;
		const atMax = mine.Level >= MAX_LEVEL;
		const sparksNeed = sparkCost(mine.Level);
		const dustNeed = dustCost(mine.Level);
		const dust = state.Stardust ?? 0;
		const sparksOk = !atMax && mine.Fragments >= sparksNeed;
		const dustOk = !atMax && gteFlux(dust, dustNeed);
		const slotW = stack ? 84 : 104;
		const input = (key: string, order: number, title: string, value: string, ok: boolean, fill: number) => (
			<frame key={key} Size={UDim2.fromOffset(slotW, fuseRowH)} BackgroundColor3={Palette.ink} BorderSizePixel={0} LayoutOrder={order}>
				<uicorner CornerRadius={new UDim(0, 14)} />
				<uistroke Color={ok ? Palette.mango : Palette.line} Thickness={1.5} Transparency={ok ? 0.2 : 0.4} />
				<uipadding PaddingLeft={new UDim(0, 8)} PaddingRight={new UDim(0, 8)} PaddingTop={new UDim(0, 10)} PaddingBottom={new UDim(0, 10)} />
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} VerticalAlignment={Enum.VerticalAlignment.Bottom} HorizontalAlignment={Enum.HorizontalAlignment.Center} Padding={new UDim(0, 6)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<Line text={spaced(title.upper())} size={10} color={Palette.muted} width={new UDim(1, 0)} align={Enum.TextXAlignment.Center} layoutOrder={0} />
				<Line text={value} size={13} width={new UDim(1, 0)} align={Enum.TextXAlignment.Center} layoutOrder={1} />
				<Bar fill={math.clamp(fill, 0, 1)} color={Palette.mango} thin={true} layoutOrder={2} />
			</frame>
		);
		return (
			<frame Size={new UDim2(1, 0, 0, fuseRowH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={4}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} VerticalAlignment={Enum.VerticalAlignment.Center} Padding={new UDim(0, stack ? 8 : 12)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{input("Sparks", 0, "Sparks", `${mine.Fragments} / ${atMax ? "-" : sparksNeed}`, sparksOk, mine.Fragments / math.max(1, sparksNeed))}
				{input("Dust", 1, "Stardust", compactNumber(dustNeed), dustOk, gteFlux(dust, dustNeed) ? 1 : 0.4)}
				<frame key="Arrow" Size={UDim2.fromOffset(stack ? 28 : 44, fuseRowH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
					<frame Size={new UDim2(0.8, 0, 0, 2)} Position={UDim2.fromScale(0.5, 0.5)} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundColor3={Palette.brass} BorderSizePixel={0} />
					<frame Size={UDim2.fromOffset(8, 2)} Position={new UDim2(0.9, -7, 0.5, -3)} Rotation={40} BackgroundColor3={Palette.brass} BorderSizePixel={0} />
					<frame Size={UDim2.fromOffset(8, 2)} Position={new UDim2(0.9, -7, 0.5, 2)} Rotation={-40} BackgroundColor3={Palette.brass} BorderSizePixel={0} />
				</frame>
				<SpriteCard
					element={selected.Element}
					name={atMax ? "Max level" : `Lv ${mine.Level + 1}`}
					rarity={selected.Rarity}
					found={sparksOk && dustOk}
					following={false}
					selected={false}
					onSelect={() => undefined}
					size={UDim2.fromOffset(slotW, fuseRowH)}
					reducedMotion={reducedMotion}
					layoutOrder={3}
				/>
				<frame key="Spacer" Size={new UDim2(0, 0, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={4}>
					<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
				</frame>
				<MockBtn
					text={atMax ? "Max level" : `Feed · ${compactNumber(dustNeed)} dust`}
					icon="Dust"
					accent={Palette.violet}
					phone={stack}
					disabled={!(sparksOk && dustOk) || busy}
					onClick={() => {
						if (busy) return;
						setBusy(true);
						dispatch("UpgradeArtifact", { Id: selected!.Id }, () => setBusy(false));
					}}
					reducedMotion={reducedMotion}
					layoutOrder={5}
				/>
			</frame>
		);
	})();
	const gridPad = stack ? 10 : 16;
	const gridCount = shown.size() + shownNamed.size();
	const grid = (gridW: number) => {
		const cols = math.max(1, math.floor((gridW - gridPad * 2 + gap) / (cardW + gap)));
		const rowsN = math.max(1, math.ceil(gridCount / cols));
		const wrapH = rowsN * cardH + (rowsN - 1) * gap + 8;
		return { cols, wrapH };
	};
	const gridPanel = (wrapH: number) => (
		<PnSurface size={UDim2.fromScale(1, 1)} radius={16} rule={true} accent={Palette.brass} background={Palette.panel} padding={gridPad} reducedMotion={reducedMotion}>
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, 12)} SortOrder={Enum.SortOrder.LayoutOrder} />
			<PanelHeading
				icon="Artifact"
				title={tab === "Owned" ? "Owned" : "Index"}
				note={tab === "Owned" ? tostring(foundCount) : `${foundCount} / ${totalCount}`}
				accent={Palette.mint}
				phone={stack}
				layoutOrder={0}
			/>
			<frame Size={new UDim2(1, 0, 0, wrapH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
				<uipadding PaddingTop={new UDim(0, 4)} PaddingLeft={new UDim(0, 2)} PaddingBottom={new UDim(0, 4)} />
				<uigridlayout CellSize={UDim2.fromOffset(cardW, cardH)} CellPadding={UDim2.fromOffset(gap, gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{shown.map((artifact, index) => {
					const mine = owned[artifact.Id];
					return (
						<SpriteCard
							key={artifact.Id}
							element={artifact.Element}
							name={artifact.Name}
							rarity={artifact.Rarity}
							level={mine?.Level}
							found={mine !== undefined}
							following={artifact.Id === following}
							selected={selected !== undefined && artifact.Id === selected.Id}
							onSelect={() => {
								if (mine !== undefined) setPicked(artifact.Id);
							}}
							size={UDim2.fromScale(1, 1)}
							reducedMotion={reducedMotion}
							layoutOrder={index}
						/>
					);
				})}
				{shownNamed.map((drop, index) => (
					<SpriteCard
						key={`named-${drop.Key}`}
						element={drop.Key}
						name={drop.Name}
						rarity={drop.Rarity}
						found={ownedNamedSet[drop.Key] === true}
						following={false}
						selected={false}
						onSelect={() => undefined}
						size={UDim2.fromScale(1, 1)}
						reducedMotion={reducedMotion}
						layoutOrder={shown.size() + index}
					/>
				))}
				{gridCount === 0 && (
					<Line text="Companions turn up on Command expeditions, and now and then in crates." size={13} color={Palette.muted} width={new UDim(1, 0)} layoutOrder={0} />
				)}
			</frame>
			{fuseRow !== undefined && <DiamondRule layoutOrder={2} />}
			{fuseRow !== undefined && (
				<PanelHeading icon="Research" title="Level up" note="Sparks and stardust raise the next level" accent={Palette.violet} phone={stack} layoutOrder={3} />
			)}
			{fuseRow}
		</PnSurface>
	);

	// ---------- stage ----------
	let stage: React.Element;
	if (selected === undefined) {
		stage = (
			<PnSurface size={UDim2.fromScale(1, 1)} accent={Palette.line} background={Palette.panel} padding={20} radius={18} reducedMotion={reducedMotion}>
				<Text value="No companion yet" size={16} color={Palette.cream} weight={Enum.FontWeight.Bold} sizeConstraint={new UDim2(1, 0, 0, 22)} />
				<Text value="Expeditions can bring one home." size={13} color={Palette.muted} position={UDim2.fromOffset(0, 26)} sizeConstraint={new UDim2(1, 0, 0, 18)} />
			</PnSurface>
		);
	} else {
		const artifact = selected;
		const mine = owned[artifact.Id]!;
		const color = rarityColor(artifact.Rarity);
		const atMax = mine.Level >= MAX_LEVEL;
		const sparksNeed = sparkCost(mine.Level);
		const dustNeed = dustCost(mine.Level);
		const dust = state.Stardust ?? 0;
		const canFeed = !atMax && mine.Fragments >= sparksNeed && gteFlux(dust, dustNeed);
		const isFollowing = artifact.Id === following;
		const sheet = elementSheet(artifact.Element);
		const act = (action: string, after?: () => void) => {
			if (busy) return;
			setBusy(true);
			dispatch(action, { Id: artifact.Id }, (response) => {
				setBusy(false);
				if (response.ok && after) after();
			});
		};
		const spriteH = stack ? 150 : 230;
		const tag = `${rarityName(artifact.Rarity)} · ${sheet !== undefined ? sheet.Label.sub(1, 1) + sheet.Label.sub(2).lower() : ""}`;
		const rh = rowHeight(stack);
		stage = (
			<PnSurface size={UDim2.fromScale(1, 1)} radius={16} rule={true} accent={Palette.brass} background={Palette.panel} padding={stack ? 14 : 18} reveal={enter} reducedMotion={reducedMotion} clips={false}>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, stack ? 8 : 10)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<frame Size={new UDim2(1, 0, 0, spriteH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={0}>
					<frame
						key="EquipRing"
						Size={UDim2.fromOffset(spriteH * 0.8, spriteH * 0.8)}
						Position={UDim2.fromScale(0.5, 0.5)}
						AnchorPoint={new Vector2(0.5, 0.5)}
						BackgroundTransparency={1}
					>
						<uicorner CornerRadius={new UDim(1, 0)} />
						<uistroke Color={Palette.brass} Thickness={2} Transparency={ring.map((t) => 1 - t * 0.8)} />
						<uiscale Scale={ring.map((t) => 1.25 - 0.25 * t)} />
					</frame>
					<ElementFx
						element={artifact.Element}
						size={UDim2.fromOffset(spriteH, spriteH)}
						position={UDim2.fromScale(0.5, 0.5)}
						reducedMotion={reducedMotion}
						reaction={equipNonce > 0 ? "equip" : "select"}
						reactionKey={`${artifact.Id}:${equipNonce}`}
					/>
				</frame>
				<frame Size={new UDim2(1, 0, 0, stack ? 26 : 32)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} VerticalAlignment={Enum.VerticalAlignment.Center} Padding={new UDim(0, 10)} SortOrder={Enum.SortOrder.LayoutOrder} />
					<Line text={spaced(artifact.Name)} size={stack ? 20 : 26} font={TITLE_FACE} layoutOrder={0} />
					<frame Size={UDim2.fromOffset(0, 20)} AutomaticSize={Enum.AutomaticSize.X} BackgroundColor3={color.Lerp(Palette.ink, 0.7)} BorderSizePixel={0} LayoutOrder={1}>
						<uicorner CornerRadius={new UDim(0, 6)} />
						<uistroke Color={color} Thickness={1} Transparency={0.4} />
						<uipadding PaddingLeft={new UDim(0, 8)} PaddingRight={new UDim(0, 8)} />
						<Line text={tag} size={11} color={color} height={20} />
					</frame>
				</frame>
				<Line text={artifact.Description ?? ""} size={13} color={Palette.muted} width={new UDim(1, 0)} height={18} layoutOrder={2} />
				<MockRow title={kindLabel(artifact.EffectKind)} icon="Boost" accent={Palette.mint} value={effectText(artifact, mine.Level)} valueColor={Palette.mint} phone={stack} height={rh} layoutOrder={3} />
				<MockRow
					title="Level"
					icon="Milestone"
					value={atMax ? `${mine.Level} / ${MAX_LEVEL} · Max` : `${mine.Level} / ${MAX_LEVEL}`}
					valueColor={Palette.mango}
					phone={stack}
					height={rh}
					layoutOrder={4}
				/>
				<Bar fill={mine.Level / MAX_LEVEL} color={Palette.mango} layoutOrder={5} />
				<frame Size={new UDim2(1, 0, 0, stack ? TapTarget : 44)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={6}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 10)} SortOrder={Enum.SortOrder.LayoutOrder} />
					<frame Size={new UDim2(0, 0, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={0}>
						<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
						<MockBtn
							text={isFollowing ? "Equipped" : "Equip"}
							icon="Check"
							fill={true}
							phone={stack}
							disabled={isFollowing || busy}
							onClick={() => act("EquipArtifact", () => setEquipNonce((value) => value + 1))}
							reducedMotion={reducedMotion}
						/>
					</frame>
					<MockBtn
						text={atMax ? "Max level" : `Feed · ${compactNumber(dustNeed)} dust`}
						icon="Dust"
						sec={true}
						phone={stack}
						disabled={!canFeed || busy}
						onClick={() => act("UpgradeArtifact")}
						reducedMotion={reducedMotion}
						layoutOrder={1}
					/>
				</frame>
			</PnSurface>
		);
	}
	const stageMinH = (stack ? 150 : 230) + (stack ? 26 : 32) + 18 + rowHeight(stack) * 2 + 10 + (stack ? TapTarget : 44) + (stack ? 8 : 10) * 6 + (stack ? 28 : 36);

	const sections: { id: string; height?: number; fill?: boolean; minHeight?: number; element: React.Element }[] = [
		{ id: "hero", height: heroH, element: hero },
	];
	if (stack) {
		const g = grid(viewport.width - 24);
		sections.push({ id: "grid", height: gridPad * 2 + 22 + 12 + g.wrapH + (fuseRow !== undefined ? 12 + 12 + fuseH : 0), element: gridPanel(g.wrapH) });
		sections.push({ id: "stage", height: stageMinH, element: stage });
	} else {
		const stageW = math.clamp(math.floor(viewport.width * 0.36), 320, 560);
		const g = grid(math.max(200, viewport.width - 300 - stageW - 14));
		sections.push({
			id: "body",
			fill: true,
			minHeight: math.max(stageMinH, gridPad * 2 + 22 + 12 + g.wrapH + (fuseRow !== undefined ? 12 + 12 + fuseH : 0)),
			element: (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
					<frame Size={new UDim2(0, stageW, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0}>
						{stage}
					</frame>
					<frame Size={new UDim2(1, -(stageW + 14), 1, 0)} Position={UDim2.fromOffset(stageW + 14, 0)} BackgroundTransparency={1} BorderSizePixel={0}>
						{gridPanel(g.wrapH)}
					</frame>
				</frame>
			),
		});
	}
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<PageScaffold
				gap={stack ? chrome.panelGap : 14}
				tailPad={scrollTail(stack, chrome.bottomSafe, 24)}
				scrollBarColor={Palette.brass}
				scrollBarThickness={4}
				sections={sections}
			/>
		</frame>
	);
}

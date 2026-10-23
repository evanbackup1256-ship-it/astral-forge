// Recipe bench for v8 recipe forging. Self-contained so it can become an Inventory tab once the
// restyle settles: pass the snapshot's Items block, the ore bag and the page dispatcher.
import React from "@rbxts/react";
import { Palette, TapTarget } from "../../CoreKit/theme";
import { kitMember, LuauComponent } from "../luauKits";
import { Label } from "../../UiCore/mockKit";
import { rarityColor } from "../PagesProgress/portKit";
import { RowFace, SEC, TileWell } from "../mockRows";
import * as RelicRecipes from "../../../../Shared/AstralForge/Shared/RelicRecipes";

const { Button, Text } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");

type Reply = (response: { ok?: boolean; message?: string }) => void;
export type RecipeDispatch = (action: string, payload?: object, callback?: Reply) => unknown;

interface Definition extends RelicRecipes.RecipeDefinition {
	Name: string;
	Rarity: string;
}

interface ItemsState {
	Inventory?: Record<string, { DefinitionId?: string; Locked?: boolean }>;
	Equipped?: Record<string, string>;
	Discovered?: Record<string, boolean>;
	Essence?: number;
	Recipes?: { Crafted?: Record<string, number>; Paused?: boolean };
}

// 04-inventory / 03-forge: each recipe is a 64px .row with a rarity tile, name, cost line and sm Forge
const ROW_H = 64;
const ROW_H_STACK = 64 + TapTarget + 8;
const GAP = 8;
const HEAD_H = 44;
const TILE = 48;

export function recipeBenchHeight(definitions: Definition[], items: ItemsState, stack: boolean): number {
	const rows = definitions.filter((d) => items.Discovered?.[d.Id] === true).size();
	return HEAD_H + math.max(1, rows) * ((stack ? ROW_H_STACK : ROW_H) + GAP);
}

function costText(recipe: RelicRecipes.Recipe): string {
	const parts = [`${recipe.Essence} Essence`, `${recipe.Emberite} Emberite`];
	if (recipe.Voidglass > 0) parts.push(`${recipe.Voidglass} Voidglass`);
	if (recipe.Starsteel > 0) parts.push(`${recipe.Starsteel} Starsteel`);
	if (recipe.SacrificeRarity !== undefined) parts.push(`a spare ${recipe.SacrificeRarity.lower()}`);
	return parts.join(" · ");
}

// the lowest-level spare of the right rarity: not protected, not in use
function spareFor(items: ItemsState, rarity: string, rarityOf: (id: string) => string | undefined): string | undefined {
	const used: Record<string, boolean> = {};
	for (const [, uid] of pairs(items.Equipped ?? {})) {
		used[uid] = true;
	}
	for (const [uid, instance] of pairs(items.Inventory ?? {})) {
		if (!used[uid] && instance.Locked !== true && instance.DefinitionId !== undefined && rarityOf(instance.DefinitionId) === rarity) {
			return uid;
		}
	}
	return undefined;
}

export function RecipeBench(props: {
	definitions: Definition[];
	items: ItemsState;
	ore: { Emberite?: number; Voidglass?: number; Starsteel?: number };
	stack: boolean;
	dispatch: RecipeDispatch;
	reducedMotion?: boolean;
}) {
	const { items, ore, stack } = props;
	const [pending, setPending] = React.useState<string | undefined>(undefined);
	const [refused, setRefused] = React.useState<{ key: string; token: number }>({ key: "", token: 0 });
	const byId: Record<string, Definition> = {};
	for (const definition of props.definitions) {
		byId[definition.Id] = definition;
	}
	const rarityOf = (id: string) => byId[id]?.Rarity;
	const crafted = items.Recipes?.Crafted ?? {};
	let weekTotal = 0;
	for (const [, count] of pairs(crafted)) {
		weekTotal += count;
	}
	const paused = items.Recipes?.Paused === true;

	const craft = (id: string, sacrifice: string | undefined) => {
		if (pending !== undefined) {
			return;
		}
		setPending(id);
		const fallback = task.delay(8, () => setPending(undefined));
		props.dispatch("CraftRelic", { Id: id, Sacrifice: sacrifice }, (response) => {
			pcall(task.cancel, fallback);
			setPending(undefined);
			if (response.ok !== true) {
				setRefused((current) => ({ key: id, token: current.token + 1 }));
			}
		});
	};

	const rowH = stack ? ROW_H_STACK : ROW_H;
	const rows: Record<string, React.Element> = {};
	let index = 0;
	for (const definition of props.definitions) {
		if (items.Discovered?.[definition.Id] !== true) {
			continue;
		}
		const recipe = RelicRecipes.recipeFor(definition);
		const made = crafted[definition.Id] ?? 0;
		const spare = recipe.SacrificeRarity !== undefined ? spareFor(items, recipe.SacrificeRarity, rarityOf) : undefined;
		const ready =
			!paused &&
			weekTotal < RelicRecipes.WEEKLY_TOTAL &&
			made < recipe.WeeklyCap &&
			(items.Essence ?? 0) >= recipe.Essence &&
			(ore.Emberite ?? 0) >= recipe.Emberite &&
			(ore.Voidglass ?? 0) >= recipe.Voidglass &&
			(ore.Starsteel ?? 0) >= recipe.Starsteel &&
			(recipe.SacrificeRarity === undefined || spare !== undefined);
		rows[definition.Id] = (
			<frame Size={new UDim2(1, 0, 0, rowH)} Position={UDim2.fromOffset(0, HEAD_H + index * (rowH + GAP))} BackgroundColor3={Palette.white} BorderSizePixel={0}>
				<RowFace outline={ready ? Palette.mango : undefined} />
				<uipadding PaddingLeft={new UDim(0, 8)} PaddingRight={new UDim(0, 12)} PaddingTop={new UDim(0, 8)} />
				<TileWell icon="Artifact" accent={rarityColor(definition.Rarity)} size={TILE} dim={!ready} />
				<Text
					value={`${definition.Name} · ${definition.Rarity}`}
					size={15}
					color={Palette.cream}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					minSize={11}
					position={UDim2.fromOffset(TILE + 12, 2)}
					sizeConstraint={new UDim2(1, stack ? -(TILE + 12) : -(TILE + 12 + 132), 0, 20)}
				/>
				<Text
					value={`${costText(recipe)}  ·  ${made} of ${recipe.WeeklyCap} this week`}
					size={12}
					color={Palette.muted}
					wrap={true}
					fit={true}
					minSize={9}
					position={UDim2.fromOffset(TILE + 12, 24)}
					sizeConstraint={new UDim2(1, stack ? -(TILE + 12) : -(TILE + 12 + 132), 0, 24)}
				/>
				<frame
					Size={stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(120, 36)}
					Position={stack ? UDim2.fromOffset(0, ROW_H - 8) : new UDim2(1, -120, 0, (TILE - 36) / 2)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
				>
					<Button
						text="Forge"
						onClick={() => craft(definition.Id, spare)}
						color={ready ? Palette.mango : SEC}
						textColor={ready ? Palette.ink : Palette.muted}
						size={UDim2.fromScale(1, 1)}
						disabled={!ready}
						highlight={ready}
						loading={pending === definition.Id}
						shakeToken={refused.key === definition.Id ? refused.token : 0}
						reducedMotion={props.reducedMotion}
					/>
				</frame>
			</frame>
		);
		index += 1;
	}

	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<Label text="Recipes" color={Palette.mango} icon="Forge" />
			<Text
				value={
					paused
						? "The bench is closed for a moment."
						: index === 0
							? "Find a relic in a crate and its recipe shows up here."
							: `${weekTotal} of ${RelicRecipes.WEEKLY_TOTAL} crafts used this week. Resets Monday.`
				}
				size={13}
				color={Palette.creamSoft}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(0, 22)}
				sizeConstraint={new UDim2(1, 0, 0, 18)}
			/>
			{rows}
		</frame>
	);
}

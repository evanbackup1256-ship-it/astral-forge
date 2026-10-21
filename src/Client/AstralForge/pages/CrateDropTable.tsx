// Every item a crate can drop and its exact chance, from the same weights the server rolls with.
import React from "@rbxts/react";
import { Palette } from "../CoreKit/theme";
import { crateOdds, floorRank, RarityOdds } from "../../../Shared/AstralForge/Shared/CrateOdds";
import CrateConfig = require("../../../Shared/AstralForge/Shared/CrateConfig");
import { Components, loadUi, sharedModule } from "./luauDeps";

const { Panel, SectionLabel, Text } = loadUi() as Components;
const RelicSystem = sharedModule<(name: string) => unknown>("SharedData")("RelicSystem") as {
	chanceText(this: void, chance: number): string;
};

const h = React.createElement as unknown as (
	component: unknown,
	props?: Record<string, unknown>,
	...children: unknown[]
) => React.ReactElement;

const ROW = 22;
const HEAD = 26;
const PAD = 14;
const NOTE = 34;

interface DropItems {
	Rarities?: Record<string, { Rank?: number; Color?: Color3 }>;
	Definitions?: { Id: string; Name: string; Rarity: string }[];
}

interface DropCrate {
	Id: string;
	Name: string;
	Weights?: Record<string, number>;
	PityAfter?: number;
	PityRarity?: string;
}

interface CrateDropTableProps {
	items?: DropItems;
	crate: DropCrate;
	pity: number;
	stack: boolean;
}

function oddsFor(items: DropItems | undefined, crate: DropCrate, pity: number): LuaTuple<[RarityOdds[], boolean]> {
	const rarities = items?.Rarities ?? {};
	const pityDue = floorRank(crate, rarities, pity) > 0;
	return $tuple(crateOdds(crate, rarities, items?.Definitions ?? [], CrateConfig.RarityOrder as string[], pity), pityDue);
}

function rowCount(odds: RarityOdds[]): number {
	let count = 0;
	for (const row of odds) {
		count += 1 + row.items.size();
	}
	return count;
}

export function crateDropTableHeight(items: DropItems | undefined, crate: DropCrate, _stack: boolean): number {
	const [odds] = oddsFor(items, crate, 0);
	return PAD * 2 + HEAD + NOTE + rowCount(odds) * ROW;
}

function line(key: string, order: number, label: string, chance: string, color: Color3, heading: boolean) {
	return h(
		"frame",
		{
			key: key,
			Size: new UDim2(1, 0, 0, ROW),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			LayoutOrder: order,
		},
		h(Text, {
			value: label,
			size: heading ? 13 : 12,
			color: heading ? color : Palette.creamSoft,
			weight: heading ? Enum.FontWeight.Bold : Enum.FontWeight.Medium,
			fit: true,
			minSize: 10,
			position: UDim2.fromOffset(heading ? 0 : 16, 3),
			sizeConstraint: new UDim2(0.7, heading ? 0 : -16, 0, 16),
		}),
		h(Text, {
			value: chance,
			size: 12,
			color: heading ? Palette.cream : Palette.creamSoft,
			weight: heading ? Enum.FontWeight.Bold : Enum.FontWeight.Medium,
			align: Enum.TextXAlignment.Right,
			position: new UDim2(0.7, 0, 0, 3),
			sizeConstraint: new UDim2(0.3, 0, 0, 16),
		}),
	);
}

export function CrateDropTable(props: CrateDropTableProps) {
	const crate = props.crate;
	// the list is sized for a normal open; once pity is due the same rows show the pity odds
	const [normal] = oddsFor(props.items, crate, 0);
	const [odds, pityDue] = oddsFor(props.items, crate, props.pity);
	const rarities = props.items?.Rarities ?? {};
	const rows: Record<string, unknown> = {
		Layout: h("uilistlayout", { SortOrder: Enum.SortOrder.LayoutOrder, Padding: new UDim(0, 0) }),
	};
	let order = 0;
	for (const row of odds) {
		const color = rarities[row.rarity]?.Color ?? Palette.cream;
		order += 1;
		rows[`R${order}`] = line(`R${order}`, order, row.rarity, RelicSystem.chanceText(row.chance), color, true);
		for (const item of row.items) {
			order += 1;
			rows[`R${order}`] = line(`R${order}`, order, item.name, RelicSystem.chanceText(item.chance), color, false);
		}
	}
	const note =
		crate.PityRarity === undefined || crate.PityAfter === undefined
			? "Each item in a rarity is equally likely."
			: pityDue
				? `Pity is due: your next open is ${crate.PityRarity} or better, so these are the odds for it.`
				: `Each item in a rarity is equally likely. After ${math.max(0, crate.PityAfter - 1)} opens without a ${crate.PityRarity} or better, the next one only rolls ${crate.PityRarity} and up.`;
	return h(
		Panel,
		{
			size: UDim2.fromScale(1, 1),
			background: Palette.panelRaised,
			padding: PAD,
			clips: true,
		},
		h(SectionLabel, { value: "All drops", color: Palette.violet }),
		h(Text, {
			value: note,
			size: 11,
			color: Palette.muted,
			wrap: true,
			fit: true,
			minSize: 9,
			position: UDim2.fromOffset(0, HEAD),
			sizeConstraint: new UDim2(1, 0, 0, NOTE - 4),
		}),
		h(
			"frame",
			{
				Size: new UDim2(1, 0, 0, rowCount(normal) * ROW),
				Position: UDim2.fromOffset(0, HEAD + NOTE),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
			},
			rows,
		),
	);
}

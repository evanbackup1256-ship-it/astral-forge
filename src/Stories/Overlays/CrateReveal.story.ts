import StoryKit = require("../StoryKit");

type Dict = Record<string, unknown>;
interface Definition {
	Id: string;
	Rarity: string;
}
interface Crate {
	Id: string;
	Name: string;
	Color: unknown;
}
interface Config {
	Items: { Definitions: Definition[]; Crates: Crate[] };
}

const React = StoryKit.React;
const UILabs = StoryKit.UILabs;

const overlay = (
	require(StoryKit.client.WaitForChild("UiCore") as ModuleScript) as (name: string) => Record<string, React.FunctionComponent<Dict>>
)("CrateRevealOverlay");
const SharedData = require(StoryKit.shared.WaitForChild("SharedData") as ModuleScript) as (name: string) => Dict;
const ShopCatalog = SharedData("ShopCatalog");
const RelicSystem = SharedData("RelicSystem");

const skins: string[] = [];
for (const skin of ShopCatalog.SKINS as { Id: string }[]) {
	skins.push(skin.Id);
}

function rollsFor(config: Config, rarity: unknown, count: number) {
	let pick: Definition | undefined = undefined;
	for (const definition of config.Items.Definitions) {
		if (definition.Rarity === rarity) {
			pick = definition;
			break;
		}
	}
	const chosen = pick ?? config.Items.Definitions[0];
	const rolls: Dict[] = [];
	for (let index = 1; index <= count; index++) {
		rolls.push({
			Uid: `story${index}`,
			DefinitionId: chosen.Id,
			Rarity: chosen.Rarity,
			New: index === 1,
			Pity: false,
			AutoSalvaged: false,
			Essence: 0,
		});
	}
	return rolls;
}

export = StoryKit.story(
	{
		name: "Crate reveal",
		summary: "The relic reel: spin, near-miss and landing for each rarity, single and multi-open, then the result cards.",
		controls: {
			Rarity: UILabs.Choose(RelicSystem.ORDER as string[], 7),
			Count: UILabs.Choose([1, 5], 1),
			Skin: UILabs.Choose(skins, 1),
			Replay: 0,
		},
	},
	(controls, kit) => {
		const config = kit.config as unknown as Config;
		const crate = config.Items.Crates[0];
		return React.createElement(overlay.CrateRevealOverlay, {
			key: `${controls.Rarity}-${controls.Count}-${controls.Skin}-${controls.Replay}`,
			session: {
				crateId: crate.Id,
				crateName: crate.Name,
				accent: crate.Color,
				rolls: rollsFor(config, controls.Rarity, controls.Count as number),
			},
			config: kit.config,
			skin: controls.Skin,
			reducedMotion: kit.reducedMotion,
			onClose: () => {
				print("[story] reveal closed");
			},
		});
	},
);

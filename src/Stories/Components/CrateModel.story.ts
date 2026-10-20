import StoryKit = require("../StoryKit");

type Dict = Record<string, unknown>;

const React = StoryKit.React;
const UILabs = StoryKit.UILabs;

const crate = (
	require(StoryKit.client.WaitForChild("UiCore") as ModuleScript) as (name: string) => Record<string, React.FunctionComponent<Dict>>
)("crateModel");
const ShopCatalog = (
	require(StoryKit.shared.WaitForChild("SharedData") as ModuleScript) as (name: string) => { SKINS: { Id: string }[] }
)("ShopCatalog");

const skins: string[] = [];
for (const skin of ShopCatalog.SKINS) {
	skins.push(skin.Id);
}

export = StoryKit.story(
	{
		name: "Crate skin",
		summary:
			"A crate skin from the prop kit (Crate_<Skin>_Body/_Lid), as the Shop and the crate reveal show it.",
		controls: {
			Skin: UILabs.Choose(skins, 1),
			Open: UILabs.Slider(0, 0, 1, 0.05),
			Shake: UILabs.Slider(0, 0, 1, 0.05),
			Spin: true,
			Zoom: UILabs.Slider(0.9, 0.5, 1.5, 0.05),
		},
	},
	(controls) =>
		React.createElement(crate.CrateModel, {
			skin: controls.Skin,
			open: controls.Open,
			shake: controls.Shake,
			spin: controls.Spin,
			zoom: controls.Zoom,
			size: UDim2.fromScale(0.8, 0.8),
			position: UDim2.fromScale(0.5, 0.5),
			anchorPoint: new Vector2(0.5, 0.5),
		}),
);

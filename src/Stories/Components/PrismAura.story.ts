import StoryKit = require("../StoryKit");

type Dict = Record<string, unknown>;

const React = StoryKit.React;
const UILabs = StoryKit.UILabs;
const h = React.createElement;

const prism = (
	require(StoryKit.client.WaitForChild("UiCore") as ModuleScript) as (name: string) => Record<string, React.FunctionComponent<Dict>>
)("prismFx");
const Palette = (
	require(StoryKit.client.WaitForChild("CoreKit") as ModuleScript) as (name: string) => { Palette: Record<string, Color3> }
)("theme").Palette;

export = StoryKit.story(
	{
		name: "Prismatic aura",
		summary: "The Celestial and Astral look: turning rim, light rays and sparks (UiCore#prismFx).",
		controls: {
			Rarity: UILabs.Choose(["Celestial", "Astral"], 1),
			Intensity: UILabs.Slider(1, 0, 1, 0.05),
			Rays: true,
			Sparks: true,
		},
	},
	(controls) =>
		h(
			"frame",
			{
				Size: UDim2.fromOffset(260, 180),
				Position: UDim2.fromScale(0.5, 0.5),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundColor3: Palette.panelRaised,
			},
			h("uicorner", { CornerRadius: new UDim(0, 14) }),
			h(prism.PrismAura, {
				rarity: controls.Rarity,
				intensity: controls.Intensity,
				rays: controls.Rays,
				sparks: controls.Sparks,
				corner: 14,
				clipRays: false,
			}),
			h("textlabel", {
				Size: UDim2.fromScale(1, 1),
				BackgroundTransparency: 1,
				Text: (controls.Rarity as string).upper() + " RELIC",
				TextColor3: Palette.cream,
				Font: Enum.Font.BuilderSansExtraBold,
				TextSize: 22,
				ZIndex: 10,
			}),
		),
);

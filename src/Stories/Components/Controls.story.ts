import StoryKit = require("../StoryKit");

type Dict = Record<string, unknown>;
type Comp = React.FunctionComponent<Dict>;

const React = StoryKit.React;
const UILabs = StoryKit.UILabs;
const h = React.createElement;

const ui = (require(StoryKit.client.WaitForChild("UiCore") as ModuleScript) as (name: string) => Record<string, Comp>)("ui");
const Palette = (
	require(StoryKit.client.WaitForChild("CoreKit") as ModuleScript) as (name: string) => { Palette: Record<string, Color3> }
)("theme").Palette;

const ACCENTS = ["mango", "cyan", "mint", "coral", "violet", "pink"];

function Gallery(props: { controls: Dict; reducedMotion: boolean }) {
	const controls = props.controls;
	const [tab, setTab] = React.useState("one");
	const [query, setQuery] = React.useState("");
	const accent = Palette[controls.Accent as string] ?? Palette.mango;
	const row = (order: number, height: number, ...children: React.ReactNode[]) =>
		h(
			"frame",
			{ Size: new UDim2(1, 0, 0, height), BackgroundTransparency: 1, LayoutOrder: order },
			h("uilistlayout", {
				FillDirection: Enum.FillDirection.Horizontal,
				Padding: new UDim(0, 10),
				VerticalAlignment: Enum.VerticalAlignment.Center,
			}),
			...children,
		);
	return h(
		"frame",
		{ Size: new UDim2(1, -32, 1, -32), Position: UDim2.fromOffset(16, 16), BackgroundTransparency: 1 },
		h("uilistlayout", { Padding: new UDim(0, 14), SortOrder: Enum.SortOrder.LayoutOrder }),
		row(
			1,
			48,
			h(ui.Button, {
				text: controls.Label,
				icon: "Shop",
				color: accent,
				textColor: Palette.ink,
				size: UDim2.fromOffset(200, 44),
				disabled: controls.Disabled,
				highlight: !controls.Disabled,
				reducedMotion: props.reducedMotion,
				onClick: () => {
					print("[story] pressed");
				},
			}),
			h(ui.Button, {
				text: "OUTLINE",
				icon: "Guide",
				color: Palette.panelSoft,
				textColor: Palette.cream,
				outline: true,
				size: UDim2.fromOffset(160, 44),
				reducedMotion: props.reducedMotion,
			}),
			h(ui.Button, {
				text: "LOCKED",
				icon: "Lock",
				color: Palette.panelSoft,
				textColor: Palette.creamSoft,
				disabled: true,
				size: UDim2.fromOffset(140, 44),
				reducedMotion: props.reducedMotion,
			}),
		),
		row(
			2,
			24,
			h(ui.Badge, { value: "NEW", accent: accent, filled: true, size: UDim2.fromOffset(60, 20) }),
			h(ui.Badge, { value: "LV 12 ★★", accent: Palette.mango, size: UDim2.fromOffset(92, 20) }),
			h(ui.Badge, { value: "SOLD OUT", accent: Palette.lineSoft, size: UDim2.fromOffset(90, 20) }),
		),
		row(
			3,
			14,
			h(ui.Meter, {
				value: controls.Progress,
				color: accent,
				size: UDim2.fromOffset(360, 10),
				reducedMotion: props.reducedMotion,
			}),
		),
		row(
			4,
			44,
			h(ui.SegmentedTabs, {
				options: [
					{ id: "one", label: "Daily" },
					{ id: "two", label: "Crates" },
					{ id: "three", label: "Skins" },
				],
				value: tab,
				onChange: setTab,
				accent: accent,
				columns: 3,
				size: UDim2.fromOffset(420, 44),
				reducedMotion: props.reducedMotion,
			}),
		),
		row(
			5,
			44,
			h(ui.SearchField, {
				value: query,
				onChange: setQuery,
				placeholder: "Search settings",
				accent: accent,
				size: UDim2.fromOffset(340, 38),
				reducedMotion: props.reducedMotion,
			}),
		),
		row(
			6,
			140,
			h(
				ui.Panel,
				{
					size: UDim2.fromOffset(420, 130),
					accent: accent,
					background: Palette.panelRaised,
					highlight: true,
					reducedMotion: props.reducedMotion,
				},
				h(ui.Text, {
					value: "A panel",
					size: 20,
					color: Palette.cream,
					weight: Enum.FontWeight.Heavy,
					sizeConstraint: new UDim2(1, 0, 0, 26),
				}),
				h(ui.Text, {
					value: controls.Body,
					size: 13,
					color: Palette.creamSoft,
					wrap: true,
					position: UDim2.fromOffset(0, 30),
					sizeConstraint: new UDim2(1, 0, 0, 60),
				}),
			),
		),
	);
}

export = StoryKit.story(
	{
		name: "Controls",
		summary: "Buttons, badges, meters, tabs, search and panels from UiCore#ui.",
		controls: {
			Label: "BUY · 400",
			Disabled: false,
			Accent: UILabs.Choose(ACCENTS, 1),
			Progress: UILabs.Slider(0.62, 0, 1, 0.01),
			Body: "Text inside a panel wraps to its width. Long strings should never run under the button beside them.",
		},
	},
	(controls, kit) => h(Gallery, { controls: controls, reducedMotion: kit.reducedMotion }),
);

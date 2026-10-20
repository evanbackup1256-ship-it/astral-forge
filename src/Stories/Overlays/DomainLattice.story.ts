import StoryKit = require("../StoryKit");

type Dict = Record<string, unknown>;

interface Lattice {
	HEARTH: number;
	EDGES: { key: string; a: number; b: number }[];
	degrees(this: void, links: unknown): Record<number, number>;
}

const React = StoryKit.React;
const UILabs = StoryKit.UILabs;

const chamber = (
	require(StoryKit.client.WaitForChild("UiOverlays") as ModuleScript) as (name: string) => Record<string, React.FunctionComponent<Dict>>
)("DomainChamber");
const DomainLattice = require(
	game.GetService("ReplicatedStorage").WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("DomainLattice") as ModuleScript,
) as Lattice;

export = StoryKit.story(
	{
		name: "Domain lattice",
		summary: "The lattice: etch links out from the Hearth, close facets, read what it gives.",
		controls: {
			Points: UILabs.Slider(6, 0, 40, 1),
			Etched: UILabs.Slider(8, 0, 30, 1),
		},
	},
	(controls, kit) => {
		// grow a connected set of links out from the Hearth, in figure order
		const etched = controls.Etched as number;
		const links: Record<string, boolean> = {};
		let count = 0;
		let grew = true;
		while (grew && count < etched) {
			grew = false;
			const degree = DomainLattice.degrees(links);
			for (const e of DomainLattice.EDGES) {
				if (count >= etched) {
					break;
				}
				if (!links[e.key] && (e.a === DomainLattice.HEARTH || (degree[e.a] ?? 0) > 0 || (degree[e.b] ?? 0) > 0)) {
					links[e.key] = true;
					count += 1;
					grew = true;
					break;
				}
			}
		}
		return React.createElement(chamber.DomainChamber, {
			mode: "lattice",
			domain: {
				Rank: 7,
				SkillPoints: controls.Points,
				Links: links,
				ProductionMultiplier: 1 + 7 * 1.5,
				LatticeClearedAtRank: 0,
			},
			dispatch: kit.dispatch,
			reducedMotion: kit.reducedMotion,
			onConfirm: () => {},
			onMode: (mode: unknown) => {
				print("[story] mode", mode);
			},
			onClose: () => {
				print("[story] lattice closed");
			},
		});
	},
);

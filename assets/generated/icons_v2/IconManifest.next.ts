// Generated from tools/assetgen/icons_v2.py output (IconManifest). Do not edit by hand.
// One icon per concept: b = its cell ([sheet, x, y]). Any id ("Forge.7") falls back to its concept ("Forge").
// t = 1 marks control icons: white art the game tints with the label beside them. l, a, p, s are unused.

type IconCell = [sheet: number, x: number, y: number];

interface IconEntry {
	b: IconCell;
	l: IconCell;
	a: string;
	p: number;
	s: number;
	// 1 for control icons: white art the game tints with the colour of the label beside them
	t?: number;
}

interface IconManifest {
	Cell: number;
	Sheets: string[];
	Icons: { [name: string]: IconEntry | undefined };
}

const IconManifest: IconManifest = {
	Cell: 96,
	Sheets: [
		"", // icons_v2_000.png
	],
	Icons: {
		"Admin": { b: [0, 0, 0], l: [0, 0, 0], a: "none", p: 0, s: 1 },
		"Anomaly": { b: [0, 96, 0], l: [0, 96, 0], a: "none", p: 0, s: 1 },
		"Artifact": { b: [0, 192, 0], l: [0, 192, 0], a: "none", p: 0, s: 1 },
		"Back": { b: [0, 288, 0], l: [0, 288, 0], a: "none", p: 0, s: 1, t: 1 },
		"Boost": { b: [0, 384, 0], l: [0, 384, 0], a: "none", p: 0, s: 1 },
		"Brand": { b: [0, 480, 0], l: [0, 480, 0], a: "none", p: 0, s: 1 },
		"Calendar": { b: [0, 576, 0], l: [0, 576, 0], a: "none", p: 0, s: 1 },
		"Chat": { b: [0, 672, 0], l: [0, 672, 0], a: "none", p: 0, s: 1 },
		"Check": { b: [0, 768, 0], l: [0, 768, 0], a: "none", p: 0, s: 1, t: 1 },
		"Chevron": { b: [0, 864, 0], l: [0, 864, 0], a: "none", p: 0, s: 1, t: 1 },
		"Close": { b: [0, 0, 96], l: [0, 0, 96], a: "none", p: 0, s: 1, t: 1 },
		"Code": { b: [0, 96, 96], l: [0, 96, 96], a: "none", p: 0, s: 1, t: 1 },
		"Collect": { b: [0, 192, 96], l: [0, 192, 96], a: "none", p: 0, s: 1 },
		"Command": { b: [0, 288, 96], l: [0, 288, 96], a: "none", p: 0, s: 1 },
		"Continuum": { b: [0, 384, 96], l: [0, 384, 96], a: "none", p: 0, s: 1 },
		"Core": { b: [0, 480, 96], l: [0, 480, 96], a: "none", p: 0, s: 1 },
		"Crate": { b: [0, 576, 96], l: [0, 576, 96], a: "none", p: 0, s: 1 },
		"Credits": { b: [0, 672, 96], l: [0, 672, 96], a: "none", p: 0, s: 1 },
		"Crew": { b: [0, 768, 96], l: [0, 768, 96], a: "none", p: 0, s: 1 },
		"Domain": { b: [0, 864, 96], l: [0, 864, 96], a: "none", p: 0, s: 1 },
		"Dust": { b: [0, 0, 192], l: [0, 0, 192], a: "none", p: 0, s: 1 },
		"Ember": { b: [0, 96, 192], l: [0, 96, 192], a: "none", p: 0, s: 1 },
		"Flux": { b: [0, 192, 192], l: [0, 192, 192], a: "none", p: 0, s: 1 },
		"Forge": { b: [0, 288, 192], l: [0, 288, 192], a: "none", p: 0, s: 1 },
		"Games": { b: [0, 384, 192], l: [0, 384, 192], a: "none", p: 0, s: 1 },
		"Gift": { b: [0, 480, 192], l: [0, 480, 192], a: "none", p: 0, s: 1 },
		"Grid": { b: [0, 576, 192], l: [0, 576, 192], a: "none", p: 0, s: 1 },
		"Guide": { b: [0, 672, 192], l: [0, 672, 192], a: "none", p: 0, s: 1 },
		"Guild": { b: [0, 768, 192], l: [0, 768, 192], a: "none", p: 0, s: 1 },
		"Hide": { b: [0, 864, 192], l: [0, 864, 192], a: "none", p: 0, s: 1, t: 1 },
		"Inventory": { b: [0, 0, 288], l: [0, 0, 288], a: "none", p: 0, s: 1 },
		"Jackpot": { b: [0, 96, 288], l: [0, 96, 288], a: "none", p: 0, s: 1 },
		"Lab": { b: [0, 192, 288], l: [0, 192, 288], a: "none", p: 0, s: 1 },
		"Leaderboard": { b: [0, 288, 288], l: [0, 288, 288], a: "none", p: 0, s: 1 },
		"Loadout": { b: [0, 384, 288], l: [0, 384, 288], a: "none", p: 0, s: 1 },
		"Lock": { b: [0, 480, 288], l: [0, 480, 288], a: "none", p: 0, s: 1, t: 1 },
		"Mail": { b: [0, 576, 288], l: [0, 576, 288], a: "none", p: 0, s: 1 },
		"Menu": { b: [0, 672, 288], l: [0, 672, 288], a: "none", p: 0, s: 1, t: 1 },
		"Milestone": { b: [0, 768, 288], l: [0, 768, 288], a: "none", p: 0, s: 1 },
		"Mission": { b: [0, 864, 288], l: [0, 864, 288], a: "none", p: 0, s: 1 },
		"Overcharge": { b: [0, 0, 384], l: [0, 0, 384], a: "none", p: 0, s: 1 },
		"Overview": { b: [0, 96, 384], l: [0, 96, 384], a: "none", p: 0, s: 1 },
		"Pause": { b: [0, 192, 384], l: [0, 192, 384], a: "none", p: 0, s: 1, t: 1 },
		"Pilot": { b: [0, 288, 384], l: [0, 288, 384], a: "none", p: 0, s: 1 },
		"Play": { b: [0, 384, 384], l: [0, 384, 384], a: "none", p: 0, s: 1, t: 1 },
		"Production": { b: [0, 480, 384], l: [0, 480, 384], a: "none", p: 0, s: 1 },
		"Reactor": { b: [0, 576, 384], l: [0, 576, 384], a: "none", p: 0, s: 1 },
		"Rebirth": { b: [0, 672, 384], l: [0, 672, 384], a: "none", p: 0, s: 1 },
		"Refresh": { b: [0, 768, 384], l: [0, 768, 384], a: "none", p: 0, s: 1, t: 1 },
		"Research": { b: [0, 864, 384], l: [0, 864, 384], a: "none", p: 0, s: 1 },
		"Rewards": { b: [0, 0, 480], l: [0, 0, 480], a: "none", p: 0, s: 1 },
		"Search": { b: [0, 96, 480], l: [0, 96, 480], a: "none", p: 0, s: 1, t: 1 },
		"Send": { b: [0, 192, 480], l: [0, 192, 480], a: "none", p: 0, s: 1, t: 1 },
		"Settings": { b: [0, 288, 480], l: [0, 288, 480], a: "none", p: 0, s: 1, t: 1 },
		"Shop": { b: [0, 384, 480], l: [0, 384, 480], a: "none", p: 0, s: 1 },
		"StarGrid": { b: [0, 480, 480], l: [0, 480, 480], a: "none", p: 0, s: 1 },
		"Story": { b: [0, 576, 480], l: [0, 576, 480], a: "none", p: 0, s: 1 },
		"Timer": { b: [0, 672, 480], l: [0, 672, 480], a: "none", p: 0, s: 1 },
		"Travel": { b: [0, 768, 480], l: [0, 768, 480], a: "none", p: 0, s: 1 },
		"Vault": { b: [0, 864, 480], l: [0, 864, 480], a: "none", p: 0, s: 1 },
		"Visit": { b: [0, 0, 576], l: [0, 0, 576], a: "none", p: 0, s: 1 },
		"Wave": { b: [0, 96, 576], l: [0, 96, 576], a: "none", p: 0, s: 1 },
		"Wheel": { b: [0, 192, 576], l: [0, 192, 576], a: "none", p: 0, s: 1 },
		"World": { b: [0, 288, 576], l: [0, 288, 576], a: "none", p: 0, s: 1 },
	},
};

export = IconManifest;

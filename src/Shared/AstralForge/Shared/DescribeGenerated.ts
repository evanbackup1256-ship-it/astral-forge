// Descriptions for the endless machine and research tails. Each line pairs a sentence about the
// part (keyed by its core or noun word) with one about its character (keyed by its prefix), so
// neighbours never match and no full line comes back more than a couple of times. Pure data, no
// Roblox APIs: the config generator loads it under Lune too.

const MACHINE_PREFIX_LINES: Record<string, string> = {
	Aether: "Runs on thin air, more or less.",
	Quark: "Built small and fussy on purpose.",
	Helix: "The coils twist the output twice before it leaves.",
	Nova: "Bright when it starts up. Brighter at full tilt.",
	Ion: "Smells like a thunderstorm in the bay.",
	Prism: "Splits the beam and keeps the best part.",
	Void: "Quiet. Unsettlingly quiet.",
	Solar: "Soaks up whatever sun it can find.",
	Lunar: "Does its best work on the night shift.",
	Chrono: "Always a beat ahead of the rest of the line.",
	Pulse: "Throbs on a rhythm you'll hear in your sleep.",
	Nexus: "Every pipe in the bay ends up running through it.",
	Flux: "Made of the same stuff it makes.",
	Halo: "Glows a soft ring around the casing.",
	Rift: "Pulls a little extra through a crack in space.",
	Storm: "Rattles the windows when it ramps up.",
	Ember: "Keeps a coal burning in its belly all day.",
	Frost: "Runs cold, which the crew likes in summer.",
	Glass: "You can watch the Flux move through it.",
	Iron: "Ugly, sturdy, and it never breaks down.",
	Myth: "Nobody's sure who designed it. It works.",
	Omega: "Built like it's meant to be the last one. It isn't.",
	Sigma: "Adds everything up and keeps the remainder.",
	Delta: "Built for one job: more than yesterday.",
	Astra: "Points its intake at the brightest star in range.",
	Cosmo: "A bit of everything up there, fed in at once.",
	Nebula: "Breathes in gas clouds, breathes out Flux.",
	Photon: "Runs on light and very little patience.",
	Grav: "Heavy enough to bend the floor plates.",
	Arc: "Sparks jump between the terminals all shift.",
	Rune: "Etched with marks nobody on the crew can read.",
	Crystal: "Rings like a bell when output peaks.",
	Plasma: "Hotter than it looks, and it looks hot.",
	Titan: "Takes up half the bay and earns it.",
	Echo: "Hums the last shift's tune back at you.",
	Drift: "Floats a few centimeters off its mounts.",
	Spark: "Starts on the first try, every time.",
	Forge: "Old-school hammer and fire, just bigger.",
	Star: "A little piece of a star, bolted down.",
	Night: "Painted black so it doesn't keep anyone up.",
};

const MACHINE_CORE_LINES: Record<string, [string, string, string]> = {
	Loom: ["Weaves loose Flux into tight bolts.", "The loom never drops a thread.", "Feeds in a fresh warp every cycle."],
	Anvil: ["Hammers raw output into shape.", "You can hear this anvil two decks up.", "Every strike knocks a little more Flux out of the ore."],
	Spindle: ["Spins the stream thin and fast.", "Winds Flux on until the spool groans.", "The spindle never stops turning."],
	Kiln: ["Bakes the slag until only Flux is left.", "Keeps the kiln door shut and the heat in.", "Fires each batch slow and pulls it out glowing."],
	Array: ["Rows of collectors, all pointed the same way.", "One panel fails and the rest of the array carries it.", "Lines up its dishes and listens."],
	Engine: ["Pistons, belts and a lot of noise.", "The engine idles high and runs higher.", "Turns over fast and keeps turning."],
	Well: ["Draws Flux up from somewhere deep.", "Drop a stone down the well and you never hear it land.", "The bucket comes up full every time."],
	Core: ["A dense core that spits out power.", "The core is the size of a fist and heavier than the bay.", "Keep the core fed and it keeps you paid."],
	Lattice: ["A frame of struts that catches stray energy.", "The lattice hums where the struts cross.", "Every node in the lattice pulls its weight."],
	Dynamo: ["Spins a current out of almost nothing.", "The dynamo whines a little at full speed.", "Give it one turn and it never wants to stop."],
	Press: ["Squeezes every last drop out of the feed.", "The press comes down every few seconds, like clockwork.", "Flat, dense and very efficient."],
	Sieve: ["Shakes out the junk and keeps the good Flux.", "Fine mesh, coarse noise.", "Only the good stuff makes it through the sieve."],
	Relay: ["Passes power down the line without losing much.", "Clicks over a thousand times a minute.", "The relay is why the rest of the line keeps up."],
	Crown: ["Sits on top of the stack and runs the show.", "Polished brass, which nobody asked for.", "The crown takes a cut from everything below it."],
	Gate: ["Opens onto somewhere with more Flux.", "The gate cycles open, shut, open.", "Stand back when the gate fires."],
	Heart: ["Beats steady in the middle of the bay.", "Put a hand on the casing and you can feel it beating.", "Pumps Flux out to the rest of the line."],
	Spire: ["Tall enough to scrape the ceiling.", "The tip of the spire glows when it's working.", "Catches charge from high up in the bay."],
	Forge: ["A furnace with opinions about temperature.", "The bellows breathe all shift.", "Melts down the feed and pours it out as Flux."],
	Drive: ["Built to push, and push hard.", "The drive rumbles through the deck plates.", "Spins up to speed and doesn't look back."],
	Matrix: ["A grid of cells, each doing a tiny bit.", "The matrix reroutes itself when a cell burns out.", "Thousands of small parts acting like one big one."],
};

const RESEARCH_PREFIX_LINES: Record<string, string> = {
	Folded: "Fits a lot of thinking into a small space.",
	Silent: "Works quietly in the background of every run.",
	Bound: "Once it's learned, it stays learned.",
	Hollow: "Leaves room for the next idea to fit in.",
	Lucent: "Clears up a problem that's been foggy for a while.",
	Prime: "Starts from the basics and gets them right.",
	Deep: "The kind of work that takes a long night.",
	High: "Big-picture stuff with small-print payoffs.",
	Inner: "Tunes the parts of the forge you never see.",
	Outer: "Looks past the bay for better ideas.",
	True: "Checked twice, then checked again.",
	Wild: "Half guesswork, but the guesses keep paying.",
	Keen: "Sharpens something that was already sharp.",
	Vast: "Slow to finish, big when it does.",
	Fine: "Tiny adjustments, added up.",
	Dark: "Nobody is quite sure why it works.",
	Bright: "The lab lit up when this one clicked.",
	Swift: "Speeds up something that used to drag.",
	Still: "Steadies the numbers so they stop wobbling.",
	Live: "Keeps learning while the forge runs.",
};

const RESEARCH_NOUN_LINES: Record<string, [string, string, string]> = {
	Lattice: ["Maps how every machine leans on the next.", "Lab notes on the lattice fill a whole shelf.", "A study of the joins between things. Rebirths can't undo it."],
	Manifold: ["Folds the forge's pipes into a neater shape.", "The manifold diagrams look like spaghetti. They work.", "Routes more through the same pipes."],
	Circuit: ["Rewires one more loop for less waste.", "Trace the circuit and you'll find a shortcut.", "A cleaner circuit that stays clean after a rebirth."],
	Protocol: ["A better way of doing the same job.", "Written down so nobody forgets it after a reset.", "The crew follows this protocol without being told."],
	Doctrine: ["The lab's house rules, refined again.", "Somebody argued for this doctrine for weeks. They were right.", "A doctrine the forge keeps through every rebirth."],
	Axiom: ["One small truth the rest of the research leans on.", "Obvious once someone said it out loud.", "Proven once. Kept for good."],
	Theorem: ["Pages of math that end in a bigger number.", "The proof is three whiteboards long.", "A theorem that holds after every rebirth."],
	Pattern: ["Spots the rhythm in how the forge runs.", "Once you see the pattern you can't unsee it.", "A pattern the crew picked up and won't drop."],
	Vector: ["Points effort where it does the most good.", "Fewer wasted moves, same direction.", "Sets a heading the forge keeps through resets."],
	Field: ["Studies the charge that hangs around the bay.", "Field readings from three shifts, finally making sense.", "A field theory that survives a rebirth intact."],
	Lens: ["Focuses the forge on what pays.", "Look through this lens and the waste stands out.", "Grinds a cleaner lens for the lab, and keeps it."],
	Codec: ["Packs more into each pulse.", "Squeezes the signal without losing any of it.", "A tighter codec, kept on file for good."],
	Harmonic: ["Gets the machines humming the same note.", "Tune it right and the bay sounds like a choir.", "A harmonic that holds through every reset."],
	Ledger: ["Tracks every Flux in and out.", "The ledger finally balances, and then some.", "Bookkeeping that carries over every rebirth."],
	Cipher: ["Cracks a code that's been slowing things down.", "Half the lab gave up on this cipher.", "Once it's cracked, it stays cracked."],
	Orbit: ["Times the work to the bay's slow spin.", "Plots a cleaner orbit for the supply drones.", "Stays in orbit however many times you start over."],
	Thread: ["Pull one loose thread and the whole thing improves.", "Follows a thread from an old lab note.", "A thread of work the forge never loses."],
	Index: ["Files everything so it's found faster.", "A better index for the lab's piles of notes.", "Indexed once, kept through every rebirth."],
};

function compose(lead: [string, string, string] | undefined, tail: string | undefined, pick: number, fallback: string): string {
	if (lead === undefined || tail === undefined) return fallback;
	const first = lead[pick % 3];
	// alternate which half leads so the same pair doesn't always read the same way
	return pick % 2 === 0 ? `${first} ${tail}` : `${tail} ${first}`;
}

const DescribeGenerated = {
	machine(this: void, prefix: string, core: string, prefixIndex: number, cycle: number): string {
		return compose(MACHINE_CORE_LINES[core], MACHINE_PREFIX_LINES[prefix], prefixIndex + cycle, "A late-game machine that follows Chrono Array.");
	},
	research(this: void, prefix: string, noun: string, prefixIndex: number, cycle: number): string {
		return compose(RESEARCH_NOUN_LINES[noun], RESEARCH_PREFIX_LINES[prefix], prefixIndex + cycle, "Permanent research. Kept through rebirths.");
	},
};

export = DescribeGenerated;

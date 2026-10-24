#!/usr/bin/env node
// Roblox throws at load ("ColorSequence must end at time=1.0") on a sequence whose literal keypoints don't
// start at exactly 0, end at exactly 1, ascend, or exceed 20 points. Scans pages/generated (every list) and
// the hand-written client UI (lists whose keypoint times are all numeric literals).
const fs = require("fs");
const path = require("path");
const root = path.resolve(__dirname, "..");
const scanRoot = path.join(root, "src");
const files = [];
(function walk(d) {
	for (const e of fs.readdirSync(d, { withFileTypes: true })) {
		const p = path.join(d, e.name);
		if (e.isDirectory()) walk(p);
		else if (/\.tsx?$/.test(e.name)) files.push(p);
	}
})(scanRoot);
const bad = [];
let checked = 0;
for (const file of files) {
	const src = fs.readFileSync(file, "utf8");
	const generated = file.includes(`${path.sep}pages${path.sep}generated${path.sep}`);
	const re = /new (Color|Number)Sequence\(\s*\[/g;
	let m;
	while ((m = re.exec(src))) {
		// the list body up to its matching ]
		let depth = 1, i = re.lastIndex;
		while (i < src.length && depth > 0) {
			const ch = src[i++];
			if (ch === "[") depth++;
			else if (ch === "]") depth--;
		}
		const body = src.slice(re.lastIndex, i - 1);
		const kp = new RegExp(`new ${m[1]}SequenceKeypoint\\(\\s*([^,]+?)\\s*,`, "g");
		const times = [...body.matchAll(kp)].map((k) => k[1]);
		if (times.length === 0) continue;
		const nums = times.map((t) => (/^-?\d*\.?\d+$/.test(t) ? Number(t) : NaN));
		if (nums.some(Number.isNaN)) {
			if (generated) bad.push(`${file}: non-literal keypoint time in generated layout`);
			continue;
		}
		checked++;
		const line = src.slice(0, m.index).split("\n").length;
		const where = `${path.relative(root, file)}:${line}`;
		if (nums[0] !== 0) bad.push(`${where}: ${m[1]}Sequence starts at ${nums[0]}, not 0`);
		if (nums[nums.length - 1] !== 1) bad.push(`${where}: ${m[1]}Sequence ends at ${nums[nums.length - 1]}, not 1`);
		if (nums.some((t, j) => j > 0 && t <= nums[j - 1])) bad.push(`${where}: ${m[1]}Sequence times not strictly ascending`);
		if (nums.length > 20) bad.push(`${where}: ${m[1]}Sequence has ${nums.length} keypoints (max 20)`);
	}
}
if (bad.length > 0) {
	console.error(bad.join("\n"));
	process.exit(1);
}
console.log(`verify_sequences: ok (${checked} literal sequences)`);

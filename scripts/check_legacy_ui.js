// Fails when source pulls the retired kit Panel / IconTile or the castIron face instead of
// mockKit's PnSurface / GlyphWell / rowFace. UiCore/ui.tsx (defines them) and mockKit (wraps them) are exempt.
const fs = require("fs"), path = require("path");
const root = path.join(__dirname, "..", "src");
const exempt = [/Stories[\\/]/, /UiCore[\\/]ui\.tsx$/, /UiCore[\\/]mockKit\.tsx$/];
const rules = [
	[/import\s*\{[^}]*\b(Panel|IconTile)\b[^}]*\}\s*from\s*"[^"]*UiCore\/ui"/, "imports legacy $1 from UiCore/ui"],
	[/import\s*\{[^}]*\b(Panel|IconTile)\b[^}]*\}\s*from\s*"\.\/ui"/, "imports legacy $1 from ./ui"],
	[/const\s*\{[^}]*\b(Panel|IconTile)\b[^}]*\}\s*=\s*(loadUi\(\)|kitMember[^;]*"UiCore",\s*"ui")/, "destructures legacy $1 from the ui kit"],
	[/luaProp\(\s*_ui\s*,\s*"(Panel|IconTile)"/, "luaProp legacy $1"],
	[/\b[uU]i\.(Panel|IconTile)\b/, "member access legacy ui.$1"],
	[/from\s*"[^"]*castIron"/, "imports retired castIron"],
];
let bad = 0;
(function walk(d) {
	for (const e of fs.readdirSync(d, { withFileTypes: true })) {
		const p = path.join(d, e.name);
		if (e.isDirectory()) walk(p);
		else if (/\.tsx?$/.test(e.name) && !exempt.some((r) => r.test(p))) {
			const s = fs.readFileSync(p, "utf8");
			for (const [re, msg] of rules) {
				const m = s.match(re);
				if (m) { bad++; console.log(`${path.relative(root, p)}: ${msg.replace("$1", m[1])}`); }
			}
		}
	}
})(root);
if (bad) { console.log(`legacy ui guard: ${bad} hit(s)`); process.exit(1); }
console.log("legacy ui guard: clean");

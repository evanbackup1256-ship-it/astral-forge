// Purpose: validate a complete Blender crate kit before exposing it to clients.
// Owner: asset pipeline. Dependencies: InsertService and CrateKit asset manifest.
// Review: 2026-10-05.

const InsertService = game.GetService("InsertService");
const ReplicatedStorage = game.GetService("ReplicatedStorage");

type Expansion = { Id: number; Skins: string[] };
type KitManifest = {
	Id: number;
	Skins: string[];
	TextureOverrides?: Record<string, number>;
	Expansions?: Expansion[];
};

function prepare(item: MeshPart, overrides?: Record<string, number>): MeshPart {
	const copy = item.Clone();
	const replacement = overrides ? overrides[item.Name] : undefined;
	if (replacement !== undefined && replacement > 0) {
		(copy as unknown as { TextureID: string }).TextureID = "rbxassetid://" + tostring(replacement);
		const surface = copy.FindFirstChildWhichIsA("SurfaceAppearance");
		if (surface) {
			// SurfaceAppearance maps are not script-writable; drop it so TextureID shows.
			surface.Destroy();
		}
	}
	copy.Anchored = true;
	copy.CanCollide = false;
	copy.CanQuery = false;
	copy.CanTouch = false;
	copy.CFrame = new CFrame();
	return copy;
}

// Later crates ship as separate kits so the original kit never has to be re-uploaded. A failed or
// unpublished expansion only costs its own skins (they keep the procedural crate).
function hasAll(folder: Instance, skins: string[]): boolean {
	for (const skinId of skins) {
		if (!folder.FindFirstChild("Crate_" + skinId + "_Body") || !folder.FindFirstChild("Crate_" + skinId + "_Lid")) {
			return false;
		}
	}
	return true;
}

function mergeExpansions(kit: KitManifest, pending: Folder, skins: string[]): void {
	for (const expansion of kit.Expansions ?? []) {
		if (!typeIs(expansion.Id, "number") || expansion.Id <= 0) {
			continue;
		}
		if (hasAll(pending, expansion.Skins)) {
			for (const skinId of expansion.Skins) {
				skins.push(skinId);
			}
			continue;
		}
		const [loaded, asset] = pcall(() => InsertService.LoadAsset(expansion.Id) as Instance);
		if (!loaded || asset === undefined) {
			warn("Crate expansion kit " + tostring(expansion.Id) + " could not load; its crates stay procedural.");
			continue;
		}
		for (const item of asset.GetDescendants()) {
			if (item.IsA("MeshPart") && string.sub(item.Name, 1, 6) === "Crate_" && !pending.FindFirstChild(item.Name)) {
				prepare(item as MeshPart, kit.TextureOverrides).Parent = pending;
			}
		}
		asset.Destroy();
		for (const skinId of expansion.Skins) {
			skins.push(skinId);
		}
	}
}

const Loader = {
	load(this: void): boolean {
		const shared = ReplicatedStorage.FindFirstChild("AstralForge");
		const folder = shared && shared.FindFirstChild("Shared");
		const manifest = folder && folder.FindFirstChild("CrateKit");
		if (!manifest || !manifest.IsA("ModuleScript")) {
			return false;
		}
		const kit = require(manifest) as KitManifest;
		if (!typeIs(kit.Id, "number") || kit.Id <= 0) {
			return false;
		}
		const existing = ReplicatedStorage.FindFirstChild("CrateKit");
		if (existing) {
			// a kit saved into the place file skips the base download, but it still needs any
			// expansion kits published after it was saved
			if (existing.IsA("Folder")) {
				mergeExpansions(kit, existing, []);
			}
			return true;
		}
		const [loaded, asset] = pcall(() => InsertService.LoadAsset(kit.Id) as Instance);
		if (!loaded || asset === undefined) {
			warn("Crate model kit could not load; keeping the existing kit.");
			return false;
		}
		const pending = new Instance("Folder");
		pending.Name = "CrateKit";
		for (const item of asset.GetDescendants()) {
			if (item.IsA("MeshPart") && string.sub(item.Name, 1, 6) === "Crate_") {
				if (pending.FindFirstChild(item.Name)) {
					pending.Destroy();
					asset.Destroy();
					return false;
				}
				prepare(item as MeshPart, kit.TextureOverrides).Parent = pending;
			}
		}
		asset.Destroy();
		const skins = table.clone(kit.Skins);
		mergeExpansions(kit, pending, skins);
		// Skins without a meshed pair fall back to the client's procedural crate, so only
		// half pairs and a missing default are fatal.
		let complete = 0;
		const missing: string[] = [];
		for (const skinId of skins) {
			const hasBody = pending.FindFirstChild("Crate_" + skinId + "_Body") !== undefined;
			const hasLid = pending.FindFirstChild("Crate_" + skinId + "_Lid") !== undefined;
			if (hasBody && hasLid) {
				complete += 1;
			} else {
				for (const piece of ["Body", "Lid"]) {
					const orphan = pending.FindFirstChild("Crate_" + skinId + "_" + piece);
					if (orphan) {
						orphan.Destroy();
					}
				}
				missing.push(skinId);
			}
		}
		if (complete === 0 || !pending.FindFirstChild("Crate_Classic_Body")) {
			pending.Destroy();
			warn("Crate model kit is incomplete; keeping the existing kit.");
			return false;
		}
		if (missing.size() > 0) {
			warn(
				"Crate model kit has no mesh for " +
					missing.join(", ") +
					"; those skins use procedural crates.",
			);
		}
		pending.SetAttribute("AssetId", kit.Id);
		pending.Parent = ReplicatedStorage;
		return true;
	},
};

export = table.freeze(Loader);

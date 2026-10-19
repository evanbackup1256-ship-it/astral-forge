// Purpose: load the Domain lattice gem kit once and publish its MeshParts for clients.
// Owner: asset pipeline. Dependencies: InsertService, Shared/DomainKit. Review: 2026-10-08.

const InsertService = game.GetService("InsertService");
const ReplicatedStorage = game.GetService("ReplicatedStorage");

const Loader = {
	load(this: void): boolean {
		if (ReplicatedStorage.FindFirstChild("DomainKit")) {
			return true;
		}
		const shared = ReplicatedStorage.FindFirstChild("AstralForge");
		const folder = shared && shared.FindFirstChild("Shared");
		const manifest = folder && folder.FindFirstChild("DomainKit");
		if (!manifest || !manifest.IsA("ModuleScript")) {
			return false;
		}
		const kit = require(manifest) as unknown as { Id?: unknown };
		if (!typeIs(kit.Id, "number") || kit.Id <= 0) {
			return false;
		}
		let asset: Instance | undefined = undefined;
		for (const attempt of $range(1, 3)) {
			const [loaded, result] = pcall(() => InsertService.LoadAsset(kit.Id as number) as Instance);
			if (loaded && result !== undefined) {
				asset = result;
				break;
			}
			task.wait(2 * attempt);
		}
		if (asset === undefined) {
			// non-fatal: the lattice keeps its procedural glass orbs
			warn("Domain gem kit could not load; the lattice keeps its procedural orbs.");
			return false;
		}
		const pending = new Instance("Folder");
		pending.Name = "DomainKit";
		for (const item of asset.GetDescendants()) {
			if (item.IsA("MeshPart") && string.sub(item.Name, 1, 7) === "Domain_" && !pending.FindFirstChild(item.Name)) {
				const copy = item.Clone();
				copy.Anchored = true;
				copy.CanCollide = false;
				copy.CanQuery = false;
				copy.CanTouch = false;
				copy.CastShadow = false;
				copy.CFrame = new CFrame();
				copy.Parent = pending;
			}
		}
		asset.Destroy();
		pending.SetAttribute("AssetId", kit.Id as number);
		pending.Parent = ReplicatedStorage;
		return true;
	},
};

export = table.freeze(Loader);

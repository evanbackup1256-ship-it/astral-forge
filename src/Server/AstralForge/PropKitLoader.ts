const InsertService = game.GetService("InsertService");
const ReplicatedStorage = game.GetService("ReplicatedStorage");

const ModuleLog = require(script.Parent!.FindFirstChild("ModuleLog")! as ModuleScript) as {
	Warn(this: void, scope: string, message: string): void;
	Info(this: void, scope: string, message: string): void;
};

const PropKitLoader = {
	// Supply-chain guard: only these root classes are expected from a kit asset.
	ALLOWED_ROOT_CLASSES: table.freeze({
		Folder: true,
		Model: true,
		Configuration: true,
	}),

	load(this: void): void {
		task.spawn(() => {
			(require(script.Parent!.FindFirstChild("CrateKitLoader")! as ModuleScript) as { load(this: void): boolean }).load();
		});
		task.spawn(() => {
			(require(script.Parent!.FindFirstChild("DomainKitLoader")! as ModuleScript) as { load(this: void): boolean }).load();
		});
		if (ReplicatedStorage.FindFirstChild("PropKit") !== undefined) {
			return;
		}
		const shared = ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared");
		const kit = require(shared.WaitForChild("PropKit") as ModuleScript) as unknown as {
			KitReady?: unknown;
			Id?: unknown;
		};
		if (kit.KitReady !== true) {
			// Release guard: loading remains non-fatal until the uploaded kit is configured.
			ModuleLog.Warn("PropKit", "[RELEASE BLOCKER] Prop/crate kit is not uploaded; KitReady is false.");
			return;
		}
		const id = kit.Id;
		if (!typeIs(id, "number") || id <= 0) {
			ModuleLog.Warn("PropKit", "[RELEASE BLOCKER] Prop/crate kit has no valid uploaded asset ID.");
			return;
		}

		let ok = false;
		let result: unknown = undefined;
		for (const attempt of $range(1, 4)) {
			[ok, result] = pcall(() => InsertService.LoadAsset(id) as Instance);
			if (ok && typeIs(result, "Instance")) {
				break;
			}
			ModuleLog.Warn("PropKit", "LoadAsset attempt " + attempt + " failed for asset " + id + "; retrying...");
			task.wait(2 * attempt);
		}

		if (!ok || !typeIs(result, "Instance")) {
			ModuleLog.Warn("PropKit", "couldn't load the prop kit " + id + ": " + tostring(result) + ". The game owner must own the asset.");
			return;
		}

		// Reject any inserted asset whose root class is not on the allowlist.
		if (!(PropKitLoader.ALLOWED_ROOT_CLASSES as Readonly<Record<string, boolean>>)[result.ClassName]) {
			ModuleLog.Warn("PropKit", "rejected prop kit " + id + ": unexpected root class " + result.ClassName + ". Destroying inserted content.");
			result.Destroy();
			return;
		}

		const folder = new Instance("Folder");
		folder.Name = "PropKit";
		for (const item of result.GetDescendants()) {
			const kitPart = string.sub(item.Name, 1, 7) === "Casino_" || string.sub(item.Name, 1, 6) === "Crate_";
			if (item.IsA("MeshPart") && kitPart && folder.FindFirstChild(item.Name) === undefined) {
				const copy = item.Clone();
				copy.Anchored = true;
				copy.CanCollide = false;
				copy.CanQuery = false;
				copy.CanTouch = false;
				copy.CastShadow = false;
				copy.CFrame = new CFrame();
				copy.Parent = folder;
			}
		}
		result.Destroy();
		folder.Parent = ReplicatedStorage;
		ModuleLog.Info("PropKit", "kit ready (" + folder.GetChildren().size() + " pieces)");
	},
};

export = PropKitLoader;

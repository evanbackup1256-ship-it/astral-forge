// Loads each uploaded UI decal once and publishes the image id inside it (see Shared/UiArt).
import { UI_ART_DECALS, UI_ART_READY, artAttribute } from "../../Shared/AstralForge/Shared/UiArt";
import ModuleLog = require("./ModuleLog");

const InsertService = game.GetService("InsertService");
const ReplicatedStorage = game.GetService("ReplicatedStorage");

export function resolveUiArt() {
	let pending = 0;
	let resolved = 0;
	for (const [id] of pairs(UI_ART_DECALS)) {
		pending += 1;
		task.spawn(() => {
			const [ok, model] = pcall(() => InsertService.LoadAsset(tonumber(id) as number) as Instance);
			if (ok && model !== undefined) {
				const decal = model.FindFirstChildWhichIsA("Decal", true);
				if (decal !== undefined && decal.Texture !== "") {
					ReplicatedStorage.SetAttribute(artAttribute(id), decal.Texture);
					resolved += 1;
				}
				model.Destroy();
			}
			pending -= 1;
		});
	}
	task.spawn(() => {
		const started = os.clock();
		while (pending > 0 && os.clock() - started < 8) task.wait(0.1);
		ReplicatedStorage.SetAttribute(UI_ART_READY, true);
		ModuleLog.Info("art", `ui art resolved ${resolved} decals, ${pending} pending`);
	});
}

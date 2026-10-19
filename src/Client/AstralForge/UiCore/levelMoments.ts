// milestone rewards play in the island as a "moment"; a running forge surge shows as an island buff
import { compactNumber } from "../CoreKit/format";
import { Palette } from "../CoreKit/theme";

interface JuiceFxModule {
	moment(this: void, title: string, detail: string | undefined, color: Color3, icon: string): void;
}

interface LevelEffect {
	Type?: unknown;
	Names?: unknown;
	Flux?: unknown;
	Stardust?: unknown;
	SurgeMultiplier?: unknown;
}

let pendingNames: string[] = [];

export function pushLevelMoment(effect: unknown) {
	if (!typeIs(effect, "table")) {
		return;
	}
	const e = effect as LevelEffect;
	if (e.Type === "LevelUp") {
		pendingNames = typeIs(e.Names, "table") ? (e.Names as string[]) : [];
		return;
	}
	if (e.Type !== "LevelReward") {
		return;
	}
	const opened = pendingNames;
	pendingNames = [];
	const parts: string[] = [];
	if ((tonumber(e.Flux) ?? 0) > 0) {
		parts.push(`+${compactNumber(e.Flux)} flux`);
	}
	if ((tonumber(e.Stardust) ?? 0) > 0) {
		parts.push(`+${compactNumber(e.Stardust)} stardust`);
	}
	if ((tonumber(e.SurgeMultiplier) ?? 1) > 1) {
		parts.push(string.format("x%.2f surge", e.SurgeMultiplier as number));
	}
	const title = opened.size() > 0 ? `${string.upper(opened.join(" + "))} UNLOCKED` : "MILESTONE!";
	const JuiceFx = require(script.Parent!.Parent!.WaitForChild("JuiceFx") as ModuleScript) as JuiceFxModule;
	JuiceFx.moment(title, parts.size() > 0 ? parts.join(" · ") : undefined, Palette.brass, "Forge.27");
}

export function LevelMomentHost(_param: unknown): undefined {
	return undefined;
}

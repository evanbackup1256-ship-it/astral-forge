interface ModuleLogApi {
	Warn: (this: void, scope: string, message: string) => void;
}

interface ConfigSnapshot {
	GetValue(key: string): unknown;
	Refresh(): void;
	UpdateAvailable: RBXScriptSignal;
}

interface SpecializationsApi {
	Configure: (this: void, gain: unknown, tradeoff: unknown, respecSeconds: unknown) => void;
}

export = () => {
	const Shared = game.GetService("ReplicatedStorage").WaitForChild("AstralForge").WaitForChild("Shared");
	const Specializations = require(Shared.WaitForChild("Specializations") as ModuleScript) as SpecializationsApi;
	const ModuleLog = require(script.Parent!.Parent!.WaitForChild("ModuleLog") as ModuleScript) as ModuleLogApi;
	task.defer(() => {
		let isStudio = false;
		pcall(() => {
			const rs = game.GetService("RunService");
			if (rs && typeIs((rs as unknown as { IsStudio?: unknown }).IsStudio, "function")) {
				isStudio = rs.IsStudio();
			}
		});
		if (isStudio) {
			return;
		}
		const [ok, snapshot] = pcall(
			() => (game.GetService("ConfigService" as keyof Services) as unknown as { GetConfigAsync(): ConfigSnapshot }).GetConfigAsync(),
		);
		if (!ok) {
			ModuleLog.Warn("Specializations", "Live build tuning unavailable; using documented defaults.");
			return;
		}
		const config = snapshot as ConfigSnapshot;
		const apply = () => {
			Specializations.Configure(
				config.GetValue("SpecializationGain"),
				config.GetValue("SpecializationTradeoff"),
				config.GetValue("SpecializationRespecSeconds"),
			);
		};
		apply();
		config.UpdateAvailable.Connect(() => {
			const [refreshed, message] = pcall(() => {
				config.Refresh();
				apply();
			});
			if (!refreshed) {
				ModuleLog.Warn("Specializations", "Live build refresh failed: " + tostring(message));
			}
		});
	});
	return Specializations;
};

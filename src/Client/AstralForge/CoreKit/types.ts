export interface ForgePathEffectDisplay {
	label: string;
	unit: string;
	noun: string;
	icon: string;
	color: Color3;
}

export const FORGE_PATH_EFFECT_DISPLAY: Record<string, ForgePathEffectDisplay> = {
	Production: { label: "Output", unit: "%", noun: "production", icon: "Forge.1", color: Color3.fromRGB(242, 96, 112) },
	TapPower: { label: "Strike", unit: "%", noun: "tap power", icon: "Overcharge.2", color: Color3.fromRGB(241, 177, 65) },
	Capacity: { label: "Reserve", unit: "%", noun: "vault capacity", icon: "Vault.2", color: Color3.fromRGB(145, 112, 238) },
	CriticalChance: { label: "Precision", unit: "%", noun: "critical chance", icon: "Jackpot.1", color: Color3.fromRGB(90, 205, 232) },
	AutoCollect: { label: "Auto", unit: "%", noun: "auto-collect rate", icon: "Vault.3", color: Color3.fromRGB(145, 112, 238) },
	Offline: { label: "Idle", unit: "%", noun: "offline income", icon: "Timer.1", color: Color3.fromRGB(90, 205, 232) },
	CriticalMultiplier: { label: "Impact", unit: "%", noun: "critical multiplier", icon: "Jackpot.2", color: Color3.fromRGB(241, 177, 65) },
	RebirthMultiplier: { label: "Cycle", unit: "%", noun: "rebirth multiplier", icon: "Rebirth.3", color: Color3.fromRGB(224, 94, 170) },
};

const FALLBACK_DISPLAY: ForgePathEffectDisplay = { label: "Bonus", unit: "%", noun: "bonus", icon: "Forge.2", color: Color3.fromRGB(145, 112, 238) };

export function forgePathEffectDisplay(effectKind: string): ForgePathEffectDisplay {
	return FORGE_PATH_EFFECT_DISPLAY[effectKind] ?? FALLBACK_DISPLAY;
}

export interface ForgePathStep {
	Step: number;
	XPCost: number;
	EffectKind: string;
	EffectAmount: number;
	Reward?: unknown;
}

export interface DecoratedForgePathStep extends ForgePathStep {
	Icon: string;
	Color: Color3;
	Noun: string;
	Label: string;
	Unit: string;
}

export function decorateForgePathStep(step: ForgePathStep): DecoratedForgePathStep {
	const display = forgePathEffectDisplay(step.EffectKind);
	return {
		Step: step.Step,
		XPCost: step.XPCost,
		EffectKind: step.EffectKind,
		EffectAmount: step.EffectAmount,
		Reward: step.Reward,
		Icon: display.icon,
		Color: display.color,
		Noun: display.noun,
		Label: display.label,
		Unit: display.unit,
	};
}

export function decorateForgePathSteps(steps: ReadonlyArray<ForgePathStep> | undefined): DecoratedForgePathStep[] {
	if (steps === undefined) {
		return [];
	}
	return steps.map((step) => decorateForgePathStep(step));
}

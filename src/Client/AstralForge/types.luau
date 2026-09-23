-- ============================================================
-- FORGE PATH — DISPLAY METADATA ONLY
-- ============================================================
-- Authoritative step list lives in Shared GameConfig.ForgePath.Steps.
-- This module only maps EffectKind → icons/colors/labels for the client UI.

local FORGE_PATH_EFFECT_DISPLAY = {
	Production = { label = "Output", unit = "%", noun = "production", icon = "Forge", color = Color3.fromRGB(242, 96, 112) },
	TapPower = { label = "Strike", unit = "%", noun = "tap power", icon = "Overcharge", color = Color3.fromRGB(241, 177, 65) },
	Capacity = { label = "Reserve", unit = "%", noun = "vault capacity", icon = "Vault", color = Color3.fromRGB(145, 112, 238) },
	CriticalChance = { label = "Precision", unit = "%", noun = "critical chance", icon = "Jackpot", color = Color3.fromRGB(90, 205, 232) },
	AutoCollect = { label = "Auto", unit = "%", noun = "auto-collect rate", icon = "Vault", color = Color3.fromRGB(145, 112, 238) },
	Offline = { label = "Idle", unit = "%", noun = "offline income", icon = "Timer", color = Color3.fromRGB(90, 205, 232) },
	CriticalMultiplier = { label = "Impact", unit = "%", noun = "critical multiplier", icon = "Jackpot", color = Color3.fromRGB(241, 177, 65) },
	RebirthMultiplier = { label = "Cycle", unit = "%", noun = "rebirth multiplier", icon = "Rebirth", color = Color3.fromRGB(224, 94, 170) },
}

local FALLBACK_DISPLAY = { label = "Bonus", unit = "%", noun = "bonus", icon = "Forge", color = Color3.fromRGB(145, 112, 238) }

local function forgePathEffectDisplay(effectKind)
	return FORGE_PATH_EFFECT_DISPLAY[effectKind] or FALLBACK_DISPLAY
end

local function decorateForgePathStep(step)
	local display = forgePathEffectDisplay(step.EffectKind)
	return {
		Step = step.Step,
		XPCost = step.XPCost,
		EffectKind = step.EffectKind,
		EffectAmount = step.EffectAmount,
		Reward = step.Reward,
		Icon = display.icon,
		Color = display.color,
		Noun = display.noun,
		Label = display.label,
		Unit = display.unit,
	}
end

local function decorateForgePathSteps(steps)
	if steps == nil then
		return {}
	end
	local decorated = table.create(#steps)
	for index, step in steps do
		decorated[index] = decorateForgePathStep(step)
	end
	return decorated
end

return {
	FORGE_PATH_EFFECT_DISPLAY = FORGE_PATH_EFFECT_DISPLAY,
	forgePathEffectDisplay = forgePathEffectDisplay,
	decorateForgePathStep = decorateForgePathStep,
	decorateForgePathSteps = decorateForgePathSteps,
}

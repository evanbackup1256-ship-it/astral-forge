-- ============================================================
-- FORGE PATH
-- ============================================================
-- MUST stay in lockstep with buildForgePathSteps() in GameConfig.luau.
local FORGE_PATH_STEP_COUNT = 80
local FORGE_PATH_EFFECT_CYCLE = { {
	kind = "Production",
	base = 3,
	label = "Output",
	unit = "%",
	noun = "production",
	icon = "Forge",
	color = Color3.fromRGB(242, 96, 112),
}, {
	kind = "TapPower",
	base = 2,
	label = "Strike",
	unit = "%",
	noun = "tap power",
	icon = "Overcharge",
	color = Color3.fromRGB(241, 177, 65),
}, {
	kind = "Capacity",
	base = 3,
	label = "Reserve",
	unit = "%",
	noun = "vault capacity",
	icon = "Vault",
	color = Color3.fromRGB(145, 112, 238),
}, {
	kind = "CriticalChance",
	base = 1,
	label = "Precision",
	unit = "%",
	noun = "critical chance",
	icon = "Jackpot",
	color = Color3.fromRGB(90, 205, 232),
}, {
	kind = "AutoCollect",
	base = 2,
	label = "Auto",
	unit = "%",
	noun = "auto-collect rate",
	icon = "Vault",
	color = Color3.fromRGB(145, 112, 238),
}, {
	kind = "Offline",
	base = 2,
	label = "Idle",
	unit = "%",
	noun = "offline income",
	icon = "Timer",
	color = Color3.fromRGB(90, 205, 232),
}, {
	kind = "CriticalMultiplier",
	base = 2,
	label = "Impact",
	unit = "%",
	noun = "critical multiplier",
	icon = "Jackpot",
	color = Color3.fromRGB(241, 177, 65),
}, {
	kind = "RebirthMultiplier",
	base = 2,
	label = "Cycle",
	unit = "%",
	noun = "rebirth multiplier",
	icon = "Rebirth",
	color = Color3.fromRGB(224, 94, 170),
} }
local FORGE_PATH_MILESTONE_BOOSTS = {
	[10] = "Hyperdrive",
	[20] = "Afterburner",
	[30] = "Ionstorm",
	[40] = "DomainSurge",
	[50] = "CoreSurge",
	[60] = "TwinCatalyst",
	[70] = "MidnightForge",
	[80] = "DomainSurge",
}
local function buildForgePathSteps()
	local steps = {}
	for step = 1, FORGE_PATH_STEP_COUNT do
		local slot = FORGE_PATH_EFFECT_CYCLE[(step - 1) % #FORGE_PATH_EFFECT_CYCLE + 1]
		local effectAmount = math.floor(slot.base * (1 + (step - 1) * 0.35))
		local xpExponent = if step <= 40 then (step - 1) else (39 + (step - 40) * 0.72)
		local xpCost = math.floor(120 * math.pow(1.24, xpExponent))
		local major = step % 5 == 0
		local apex = step % 20 == 0
		local boostId = FORGE_PATH_MILESTONE_BOOSTS[step]
		if not boostId and step % 15 == 0 then
			boostId = "VaultSurge"
		end
		local reward
		if apex then
			reward = {
				Cores = math.floor(8 + step * 2.4),
				Stardust = math.floor(160 + step * 55),
				Essence = math.floor(1 + step / 8),
				Signals = math.floor(12 + step * 0.8),
				CommandXP = math.floor(80 + step * 6),
			}
		elseif major then
			reward = {
				Cores = math.floor(4 + step * 1.6),
				Stardust = math.floor(80 + step * 40),
				Essence = math.floor(step / 10),
			}
		else
			reward = {
				Cash = math.floor(2000 * math.pow(1.3, math.min(step - 1, 55))),
				Stardust = math.floor(20 + step * 10),
			}
			if step % 3 == 0 then
				reward.CashMinutes = math.floor(2 + step * 0.15)
			end
			if step % 7 == 0 then
				reward.Signals = math.floor(4 + step * 0.35)
			end
		end
		if boostId then
			reward.Boost = boostId
		end
		if step == FORGE_PATH_STEP_COUNT then
			reward.FreeSpins = 3
			reward.StreakShield = 1
		end
		table.insert(steps, {
			Step = step,
			XPCost = xpCost,
			EffectKind = slot.kind,
			EffectAmount = effectAmount,
			Reward = reward,
			Icon = slot.icon,
			Color = slot.color,
		})
	end
	return steps
end
local FORGE_PATH_STEPS = buildForgePathSteps()
return {
	FORGE_PATH_STEPS = FORGE_PATH_STEPS,
	FORGE_PATH_STEP_COUNT = FORGE_PATH_STEP_COUNT,
	FORGE_PATH_EFFECT_CYCLE = FORGE_PATH_EFFECT_CYCLE,
}

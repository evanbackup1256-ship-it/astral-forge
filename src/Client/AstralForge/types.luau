-- ============================================================
-- FORGE PATH
-- ============================================================
-- Single linear meta-progression track that replaced the old three-way split between
-- Progression Tree (skill grid), Prestige (tier multipliers), and Season Pass (battle-pass
-- chests). Every step grants one permanent stat bonus AND a one-time reward chest, claimed
-- together in one action, funded by Forge Path XP earned passively from normal play.
local FORGE_PATH_STEP_COUNT = 40
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
local function buildForgePathSteps()
	local steps = {}
	for step = 1, FORGE_PATH_STEP_COUNT do
		local slot = FORGE_PATH_EFFECT_CYCLE[(step - 1) % #FORGE_PATH_EFFECT_CYCLE + 1]
		local effectAmount = math.floor(slot.base * (1 + (step - 1) * 0.35))
		local xpCost = math.floor(120 * math.pow(1.24, step - 1))
		local major = step % 5 == 0
		local boost = if step % 10 == 0 then {
			Boost = "Hyperdrive",
		} else {}
		local _result
		if major then
			local _object = {
				Cores = math.floor(4 + step * 1.6),
				Stardust = math.floor(80 + step * 40),
				Essence = math.floor(step / 10),
			}
			for _k, _v in boost do
				_object[_k] = _v
			end
			_result = _object
		else
			local _object = {
				Cash = math.floor(2000 * math.pow(1.3, step - 1)),
				Stardust = math.floor(20 + step * 10),
			}
			for _k, _v in boost do
				_object[_k] = _v
			end
			_result = _object
		end
		local reward = _result
		local _arg0 = {
			Step = step,
			XPCost = xpCost,
			EffectKind = slot.kind,
			EffectAmount = effectAmount,
			Reward = reward,
			Icon = slot.icon,
			Color = slot.color,
		}
		table.insert(steps, _arg0)
	end
	return steps
end
local FORGE_PATH_STEPS = buildForgePathSteps()
return {
	FORGE_PATH_STEPS = FORGE_PATH_STEPS,
}

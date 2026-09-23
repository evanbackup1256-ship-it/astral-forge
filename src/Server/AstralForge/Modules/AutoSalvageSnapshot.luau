--!strict
-- Pure AutoSalvage / AutoForge snapshot bags peeled from ServerServices (wave45).

local AutoSalvageSnapshot = {}

function AutoSalvageSnapshot.Normalize(raw)
	if type(raw) == "table" then
		return raw
	end
	return { Enabled = false, KeepNew = true, Rarities = {} }
end

function AutoSalvageSnapshot.Public(raw, copyDictionary)
	local autoSalvage = AutoSalvageSnapshot.Normalize(raw)
	return {
		Enabled = autoSalvage.Enabled == true,
		KeepNew = autoSalvage.KeepNew ~= false,
		Rarities = copyDictionary(type(autoSalvage.Rarities) == "table" and autoSalvage.Rarities or {}),
	}
end

function AutoSalvageSnapshot.DefaultAutoForge()
	return { Enabled = false, MachineId = "StellarCore", Reserve = 0.25, Bought = 0 }
end

function AutoSalvageSnapshot.PublicAutoForge(raw, copyDictionary)
	return copyDictionary(type(raw) == "table" and raw or AutoSalvageSnapshot.DefaultAutoForge())
end

return AutoSalvageSnapshot

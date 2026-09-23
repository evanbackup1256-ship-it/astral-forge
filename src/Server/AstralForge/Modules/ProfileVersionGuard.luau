--!strict

local ProfileVersionGuard = {}

function ProfileVersionGuard.ReadCompatible(raw: any, targetVersion: number): number
	assert(type(raw) == "table", "stored profile is not a table")
	assert(type(targetVersion) == "number" and targetVersion >= 1, "invalid target schema")
	if raw.DataVersion == nil then
		return 0 -- Pre-versioned saves are still eligible for the existing migration.
	end
	local sourceVersion = tonumber(raw.DataVersion)
	assert(sourceVersion ~= nil and sourceVersion >= 0 and sourceVersion % 1 == 0, "stored profile has an invalid schema")
	assert(sourceVersion <= targetVersion, "stored profile has a newer schema")
	return sourceVersion
end

return table.freeze(ProfileVersionGuard)

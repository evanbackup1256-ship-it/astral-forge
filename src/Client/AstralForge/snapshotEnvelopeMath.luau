--!strict
-- Pure snapshot envelope validators peeled from MainGame (wave43). No Roblox services.

local SnapshotEnvelopeMath = {}

local NUMERIC_KEYS = { "Revision", "SnapshotId", "ServerTime", "Cores", "Stardust", "Rebirths", "Zone", "CurrentZone" }
local PERSIST_KEYS = { "Cash", "Vault", "RunCash", "LifetimeCash", "Production", "Capacity" }
local TABLE_KEYS = { "Game", "Machines", "Research", "Wheel", "Daily", "TimedRewards", "Quests", "Settings", "Flags" }

function SnapshotEnvelopeMath.IsFiniteNumber(value: any): boolean
	if type(value) ~= "number" then
		return false
	end
	return value == value and value ~= math.huge and value ~= -math.huge
end

function SnapshotEnvelopeMath.IsPersist(value: any): boolean
	if SnapshotEnvelopeMath.IsFiniteNumber(value) then
		return value >= 0
	end
	if type(value) ~= "string" or #value == 0 then
		return false
	end
	local lower = string.lower(value)
	if lower == "inf" or lower == "infinity" then
		return true
	end
	return (string.match(value, "^[%+%-]?%d+%.?%d*[eE][%+%-]?%d+$")) ~= nil or tonumber(value) ~= nil
end

function SnapshotEnvelopeMath.IsValidEnvelope(candidate: any): boolean
	if type(candidate) ~= "table" then
		return false
	end
	for _, key in NUMERIC_KEYS do
		if not SnapshotEnvelopeMath.IsFiniteNumber(candidate[key]) then
			return false
		end
	end
	for _, key in PERSIST_KEYS do
		if not SnapshotEnvelopeMath.IsPersist(candidate[key]) then
			return false
		end
	end
	for _, key in TABLE_KEYS do
		if type(candidate[key]) ~= "table" then
			return false
		end
	end
	local revision = candidate.Revision
	local snapshotId = candidate.SnapshotId
	if type(revision) ~= "number" or revision < 0 then
		return false
	end
	if type(snapshotId) ~= "number" or snapshotId < 0 then
		return false
	end
	return true
end

return table.freeze(SnapshotEnvelopeMath)

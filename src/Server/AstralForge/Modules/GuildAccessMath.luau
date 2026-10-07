--!strict
-- Purpose: Validate guild join policy and member-cap boundaries.
-- Owner: Astral Forge guild systems. Dependencies: none. Last-reviewed: 2026-10-07.

local GuildAccessMath = {}

export type JoinMode = "Open" | "Closed"

local MIN_MEMBER_CAP = 2

function GuildAccessMath.NormalizeJoinMode(value: unknown): (JoinMode?, string?)
	if value == nil or value == "Open" then
		return "Open", nil
	end
	if type(value) == "string" and value == "Closed" then
		return "Closed", nil
	end
	return nil, "Choose Open or Closed guild access."
end

function GuildAccessMath.NormalizeMemberCap(value: unknown, currentMembers: number, maximum: number): (number?, string?)
	if value == nil then
		return maximum, nil
	end
	if type(value) ~= "number" then
		return nil, "Member cap must be a whole number."
	end
	if value ~= value or value == math.huge or value == -math.huge or value % 1 ~= 0 then
		return nil, "Member cap must be a whole number."
	end
	if value < MIN_MEMBER_CAP or value > maximum then
		return nil, `Member cap must be between {MIN_MEMBER_CAP} and {maximum}.`
	end
	if value < currentMembers then
		return nil, `Member cap cannot be lower than your current {currentMembers} members.`
	end
	return value, nil
end

function GuildAccessMath.CanJoin(
	mode: unknown,
	currentMembers: number,
	memberCap: unknown,
	maximum: number,
	alreadyMember: boolean
): (boolean, string?)
	if alreadyMember then
		return true, nil
	end
	local normalizedMode, modeError = GuildAccessMath.NormalizeJoinMode(mode)
	if not normalizedMode then
		return false, modeError
	end
	if normalizedMode == "Closed" then
		return false, "This guild is closed to new members."
	end
	local cap = GuildAccessMath.NormalizeMemberCap(memberCap, currentMembers, maximum)
	if cap == nil or currentMembers >= cap then
		return false, "That guild is full."
	end
	return true, nil
end

return table.freeze(GuildAccessMath)

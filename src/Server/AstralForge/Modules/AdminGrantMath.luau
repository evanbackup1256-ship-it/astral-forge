--!strict
-- Pure admin grant/moderation input sanitizers. No Roblox services —
-- AdminService and Lune verify scripts share this so amount/text/danger
-- coercion can be tested without Studio. Player lookup and datastore stay
-- with the caller; maxGrant is injected.

local AdminGrantMath = {}

AdminGrantMath.DEFAULT_MAX_GRANT = 1e308

function AdminGrantMath.Finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Coerce payload Amount (number or numeric string) into a positive clamped grant.
-- Returns nil when the value is missing/non-finite/non-positive after fallback.
function AdminGrantMath.BoundedAmount(raw: any, fallback: number?, maxGrant: number?): number?
	local ceiling = tonumber(maxGrant) or AdminGrantMath.DEFAULT_MAX_GRANT
	local value = if type(raw) == "string" then tonumber(raw) else raw
	if value == nil and fallback ~= nil then
		value = fallback
	end
	if not AdminGrantMath.Finite(value) or (value :: number) <= 0 then
		return nil
	end
	return math.clamp(value :: number, 1, ceiling)
end

-- Strip control chars, trim, and hard-cap length for Command/Nonce/Reason/Option.
function AdminGrantMath.CleanText(raw: any, maximum: number): string
	if type(raw) ~= "string" then
		return ""
	end
	local cap = math.max(0, math.floor(tonumber(maximum) or 0))
	local value = string.gsub(raw, "[%c]", " ")
	value = string.gsub(value, "^%s+", "")
	value = string.gsub(value, "%s+$", "")
	return string.sub(value, 1, cap)
end

-- Danger tier for admin UI arming: explicit Danger wins; else category map.
function AdminGrantMath.CommandDanger(definition: { [string]: any }?): string
	if type(definition) ~= "table" then
		return "quick"
	end
	if type(definition.Danger) == "string" and definition.Danger ~= "" then
		return definition.Danger
	end
	local category = definition.Category or "Economy"
	if category == "Troll" or category == "Resets" or category == "Moderation" then
		return "arm"
	end
	return "quick"
end

return table.freeze(AdminGrantMath)

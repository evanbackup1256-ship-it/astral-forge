--!strict
-- Pure RemoteFirewall payload helpers: user-id coerce/extract, cooldown keys,
-- and field validators. No Roblox services — RemoteFirewall and Lune verify
-- scripts share this so payload gates stay testable without Studio.
-- Instance→Player.UserId unwrap stays with the caller (inject already-raw ids).
-- Studio negative-id allowance is injected via `studio` (RunService:IsStudio).

local RemoteFirewallMath = {}

RemoteFirewallMath.MAX_SAFE_USER_ID = 9007199254740991
RemoteFirewallMath.MIN_SAFE_USER_ID = -9007199254740991

RemoteFirewallMath.COOLDOWN_KEY_FIELDS = table.freeze({
	"Id",
	"Key",
	"Index",
	"Code",
	"Channel",
	"Target",
	"Uid",
	"ChoiceId",
	"Slot",
	"Tier",
	"Level",
	"Role",
	"UserId",
	"MachineId",
})

function RemoteFirewallMath.Integer(value: any): boolean
	return type(value) == "number" and value == math.floor(value)
end

function RemoteFirewallMath.SafeNumber(value: any): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and math.abs(value) <= RemoteFirewallMath.MAX_SAFE_USER_ID
end

-- Coerce payload UserId (number or numeric string) into a non-zero safe integer.
-- `studio == true` allows negative Studio test ids; live rejects rounded < 1.
function RemoteFirewallMath.CoerceUserId(raw: any, studio: boolean?): number?
	local value = raw
	if type(value) == "string" then
		local trimmed = string.match(value, "^%s*(%-?%d+)%s*$")
		if not trimmed then
			return nil
		end
		value = tonumber(trimmed)
	end
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	local rounded = if value >= 0 then math.floor(value + 0.5) else math.ceil(value - 0.5)
	if math.abs(value - rounded) > 1e-6 then
		return nil
	end
	if rounded == 0 then
		return nil
	end
	if rounded < RemoteFirewallMath.MIN_SAFE_USER_ID or rounded > RemoteFirewallMath.MAX_SAFE_USER_ID then
		return nil
	end
	if studio ~= true and rounded < 1 then
		return nil
	end
	return rounded
end

-- Pull a raw user-id candidate from a scalar or common payload keys.
-- Does not coerce — pair with CoerceUserId.
function RemoteFirewallMath.ExtractUserId(payload: any): any
	if payload == nil then
		return nil
	end
	if type(payload) == "number" or type(payload) == "string" then
		return payload
	end
	if type(payload) ~= "table" then
		return nil
	end
	local raw = payload.UserId
	if raw == nil then
		raw = payload.userId
	end
	if raw == nil then
		raw = payload.Id
	end
	if raw == nil then
		raw = payload.TargetUserId
	end
	return raw
end

function RemoteFirewallMath.CooldownKey(action: string, payload: any, fields: { string }?): string
	if type(payload) ~= "table" then
		return action
	end
	local keyFields = fields or RemoteFirewallMath.COOLDOWN_KEY_FIELDS
	local parts = table.create(#keyFields)
	for _, field in keyFields do
		local value = payload[field]
		if value ~= nil then
			table.insert(parts, field .. "=" .. tostring(value))
		end
	end
	if #parts == 0 then
		return action
	end
	return action .. ":" .. table.concat(parts, "|")
end

function RemoteFirewallMath.StringField(payload: { [any]: any }, key: string, minimum: number, maximum: number): boolean
	local value = payload[key]
	return type(value) == "string" and value:len() >= minimum and value:len() <= maximum
end

function RemoteFirewallMath.StringArrayField(
	payload: { [any]: any },
	key: string,
	maxEntries: number,
	entryMinLen: number,
	entryMaxLen: number
): boolean
	local value = payload[key]
	if type(value) ~= "table" then
		return false
	end
	local count = 0
	for _, entry in value do
		count += 1
		if count > maxEntries then
			return false
		end
		if type(entry) ~= "string" or entry:len() < entryMinLen or entry:len() > entryMaxLen then
			return false
		end
	end
	return true
end

function RemoteFirewallMath.NumberField(
	payload: { [any]: any },
	key: string,
	minimum: number,
	maximum: number,
	mustBeInteger: boolean?
): boolean
	local value = payload[key]
	return RemoteFirewallMath.SafeNumber(value)
		and (not mustBeInteger or RemoteFirewallMath.Integer(value))
		and value >= minimum
		and value <= maximum
end

return table.freeze(RemoteFirewallMath)

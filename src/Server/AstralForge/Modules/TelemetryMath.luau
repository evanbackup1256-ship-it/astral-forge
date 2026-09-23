--!strict
-- Pure ServerServices telemetry pack helpers. No Roblox services — GameService
-- and Lune verify scripts share this so float32 clamp + packed snapshots stay
-- testable without Studio. Settings flags are caller-provided booleans.

local TelemetryMath = {}

TelemetryMath.VERSION = 1
TelemetryMath.BYTES = 30
TelemetryMath.FLOAT_MIN = -3.4e38
TelemetryMath.FLOAT_MAX = 3.4e38

-- Clamp any numeric-ish value into a finite float32 envelope. Non-finite → 0.
function TelemetryMath.Number(value: any, asNumber: ((any) -> number)?): number
	local numeric = if type(asNumber) == "function" then asNumber(value) else tonumber(value)
	if type(numeric) ~= "number" or numeric ~= numeric or numeric == math.huge or numeric == -math.huge then
		return 0
	end
	return math.clamp(numeric, TelemetryMath.FLOAT_MIN, TelemetryMath.FLOAT_MAX)
end

function TelemetryMath.SettingsFlags(settings: any): number
	local flags = 0
	if type(settings) ~= "table" then
		return flags
	end
	if settings.ReducedMotion then
		flags = bit32.bor(flags, 1)
	end
	if settings.UIEffects then
		flags = bit32.bor(flags, 2)
	end
	if settings.SoundEffects then
		flags = bit32.bor(flags, 4)
	end
	if settings.HideOtherPlots then
		flags = bit32.bor(flags, 8)
	end
	return flags
end

function TelemetryMath.Encode(
	revision: any,
	settings: any,
	cash: any,
	vault: any,
	production: any,
	capacity: any,
	cores: any,
	stardust: any,
	asNumber: ((any) -> number)?
): buffer
	local packed = buffer.create(TelemetryMath.BYTES)
	buffer.writeu8(packed, 0, TelemetryMath.VERSION)
	buffer.writeu8(packed, 1, TelemetryMath.SettingsFlags(settings))
	local rev = math.floor(math.max(0, tonumber(revision) or 0)) % 4_294_967_296
	buffer.writeu32(packed, 2, rev)
	buffer.writef32(packed, 6, TelemetryMath.Number(cash, asNumber))
	buffer.writef32(packed, 10, TelemetryMath.Number(vault, asNumber))
	buffer.writef32(packed, 14, TelemetryMath.Number(production, asNumber))
	buffer.writef32(packed, 18, TelemetryMath.Number(capacity, asNumber))
	buffer.writef32(packed, 22, TelemetryMath.Number(cores, asNumber))
	buffer.writef32(packed, 26, TelemetryMath.Number(stardust, asNumber))
	return packed
end

return table.freeze(TelemetryMath)

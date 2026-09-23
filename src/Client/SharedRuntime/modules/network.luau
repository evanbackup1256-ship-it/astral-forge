-- Compiled with roblox-ts v3.0.0
local TELEMETRY_VERSION = 1
local TELEMETRY_BYTES = 30
local ECONOMY_PACKET_VERSION = 1
local ECONOMY_PACKET_BYTES = 48
local TelemetryFlags = {
	ReducedMotion = 1,
	UIEffects = 2,
	SoundEffects = 4,
	HideOtherPlots = 8,
}
local SocialFlags = {
	Friended = 1,
	Blocked = 2,
	Muted = 4,
	ChatBanned = 8,
}
local function finite(value)
	return value == value and value ~= math.huge and value ~= -math.huge
end
local function safeF32(value)
	if not finite(value) then
		return 0
	end
	return math.clamp(value, -3.4e38, 3.4e38)
end
local function safeF64(value)
	return if finite(value) then value else 0
end
local function safeU32(value)
	if not finite(value) then
		return 0
	end
	return math.floor(math.max(0, value)) % 4_294_967_296
end
local function hasFlag(flags, flag)
	return bit32.band(flags, flag) ~= 0
end
local function setFlag(flags, flag, enabled)
	return if enabled then bit32.bor(flags, flag) else bit32.band(flags, bit32.bnot(flag))
end
local function encodeTelemetry(record)
	local packed = buffer.create(TELEMETRY_BYTES)
	buffer.writeu8(packed, 0, TELEMETRY_VERSION)
	buffer.writeu8(packed, 1, bit32.band(record.flags, 0xff))
	buffer.writeu32(packed, 2, safeU32(record.revision))
	buffer.writef32(packed, 6, safeF32(record.cash))
	buffer.writef32(packed, 10, safeF32(record.vault))
	buffer.writef32(packed, 14, safeF32(record.production))
	buffer.writef32(packed, 18, safeF32(record.capacity))
	buffer.writef32(packed, 22, safeF32(record.cores))
	buffer.writef32(packed, 26, safeF32(record.stardust))
	return packed
end
local function decodeTelemetry(payload)
	if buffer.len(payload) < TELEMETRY_BYTES or buffer.readu8(payload, 0) ~= TELEMETRY_VERSION then
		return nil
	end
	return {
		revision = buffer.readu32(payload, 2),
		flags = buffer.readu8(payload, 1),
		cash = buffer.readf32(payload, 6),
		vault = buffer.readf32(payload, 10),
		production = buffer.readf32(payload, 14),
		capacity = buffer.readf32(payload, 18),
		cores = buffer.readf32(payload, 22),
		stardust = buffer.readf32(payload, 26),
	}
end
--* Compact economy mirror: two bitfields/IDs followed by f64 currency lanes. 
local function encodeEconomy(record)
	local packed = buffer.create(ECONOMY_PACKET_BYTES)
	buffer.writeu8(packed, 0, ECONOMY_PACKET_VERSION)
	buffer.writeu8(packed, 1, 0)
	buffer.writeu32(packed, 4, safeU32(record.userId))
	buffer.writeu32(packed, 8, bit32.band(record.socialFlags, 0xffffffff))
	buffer.writeu32(packed, 12, safeU32(record.revision))
	buffer.writef64(packed, 16, safeF64(record.cash))
	buffer.writef64(packed, 24, safeF64(record.vault))
	buffer.writef64(packed, 32, safeF64(record.production))
	buffer.writef64(packed, 40, safeF64(record.capacity))
	return packed
end
local function decodeEconomy(payload)
	if buffer.len(payload) < ECONOMY_PACKET_BYTES or buffer.readu8(payload, 0) ~= ECONOMY_PACKET_VERSION then
		return nil
	end
	return {
		userId = buffer.readu32(payload, 4),
		socialFlags = buffer.readu32(payload, 8),
		revision = buffer.readu32(payload, 12),
		cash = buffer.readf64(payload, 16),
		vault = buffer.readf64(payload, 24),
		production = buffer.readf64(payload, 32),
		capacity = buffer.readf64(payload, 40),
	}
end
--* Immutable-name facade used by profile/social replication code. 
local BinaryStateBitpacker = table.freeze({
	encodeTelemetry = encodeTelemetry,
	decodeTelemetry = decodeTelemetry,
	encodeEconomy = encodeEconomy,
	decodeEconomy = decodeEconomy,
})
--* O(1) relationship flag operations shared by server mirrors and chat gates. 
local BitfieldRelationshipMatrix = table.freeze({
	flags = SocialFlags,
	has = hasFlag,
	set = setFlag,
})
return {
	hasFlag = hasFlag,
	setFlag = setFlag,
	encodeTelemetry = encodeTelemetry,
	decodeTelemetry = decodeTelemetry,
	encodeEconomy = encodeEconomy,
	decodeEconomy = decodeEconomy,
	TELEMETRY_VERSION = TELEMETRY_VERSION,
	TELEMETRY_BYTES = TELEMETRY_BYTES,
	ECONOMY_PACKET_VERSION = ECONOMY_PACKET_VERSION,
	ECONOMY_PACKET_BYTES = ECONOMY_PACKET_BYTES,
	TelemetryFlags = TelemetryFlags,
	SocialFlags = SocialFlags,
	BinaryStateBitpacker = BinaryStateBitpacker,
	BitfieldRelationshipMatrix = BitfieldRelationshipMatrix,
}

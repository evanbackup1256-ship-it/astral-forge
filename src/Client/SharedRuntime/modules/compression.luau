-- Compiled with roblox-ts v3.0.0
local VERSION = 1
local MODE_RAW = 0
local MODE_RLE = 1
local HEADER_BYTES = 6
local MAX_OUTPUT_BYTES = 1_048_576
local function writeHeader(target, mode, sourceLength)
	buffer.writeu8(target, 0, VERSION)
	buffer.writeu8(target, 1, mode)
	buffer.writeu32(target, 2, sourceLength)
end
--* Byte RLE with a raw fallback; incompressible payloads never expand beyond the header. 
local function compressBuffer(source)
	local sourceLength = buffer.len(source)
	if sourceLength == 0 then
		local empty = buffer.create(HEADER_BYTES)
		writeHeader(empty, MODE_RAW, 0)
		return empty
	end
	local runs = {}
	local cursor = 0
	while cursor < sourceLength do
		local byte = buffer.readu8(source, cursor)
		local count = 1
		while count < 255 and cursor + count < sourceLength and buffer.readu8(source, cursor + count) == byte do
			count += 1
		end
		local _count = count
		-- ▼ Array.push ▼
		table.insert(runs, _count)
		table.insert(runs, byte)
		-- ▲ Array.push ▲
		cursor += count
	end
	local useRle = #runs < sourceLength
	local output = buffer.create(HEADER_BYTES + (if useRle then #runs else sourceLength))
	writeHeader(output, if useRle then MODE_RLE else MODE_RAW, sourceLength)
	if useRle then
		for index = 0, #runs - 1 do
			buffer.writeu8(output, HEADER_BYTES + index, runs[index + 1])
		end
	else
		buffer.copy(output, HEADER_BYTES, source, 0, sourceLength)
	end
	return output
end
local function decompressBuffer(payload, outputLimit)
	if outputLimit == nil then
		outputLimit = MAX_OUTPUT_BYTES
	end
	if buffer.len(payload) < HEADER_BYTES or buffer.readu8(payload, 0) ~= VERSION then
		return nil
	end
	local mode = buffer.readu8(payload, 1)
	local expectedLength = buffer.readu32(payload, 2)
	if expectedLength > math.max(0, outputLimit) then
		return nil
	end
	local output = buffer.create(expectedLength)
	if mode == MODE_RAW then
		if buffer.len(payload) - HEADER_BYTES ~= expectedLength then
			return nil
		end
		buffer.copy(output, 0, payload, HEADER_BYTES, expectedLength)
		return output
	end
	if mode ~= MODE_RLE then
		return nil
	end
	local sourceOffset = HEADER_BYTES
	local outputOffset = 0
	while sourceOffset + 1 < buffer.len(payload) do
		local count = buffer.readu8(payload, sourceOffset)
		local byte = buffer.readu8(payload, sourceOffset + 1)
		if count == 0 or outputOffset + count > expectedLength then
			return nil
		end
		buffer.fill(output, outputOffset, byte, count)
		outputOffset += count
		sourceOffset += 2
	end
	return if outputOffset == expectedLength and sourceOffset == buffer.len(payload) then output else nil
end
local function compressString(source)
	return compressBuffer(buffer.fromstring(source))
end
local function decompressString(payload, outputLimit)
	if outputLimit == nil then
		outputLimit = MAX_OUTPUT_BYTES
	end
	local decoded = decompressBuffer(payload, outputLimit)
	return if decoded == nil then nil else buffer.tostring(decoded)
end
local NetworkBufferStreamCompressor = table.freeze({
	compressBuffer = compressBuffer,
	decompressBuffer = decompressBuffer,
	compressString = compressString,
	decompressString = decompressString,
})
return {
	compressBuffer = compressBuffer,
	decompressBuffer = decompressBuffer,
	compressString = compressString,
	decompressString = decompressString,
	NetworkBufferStreamCompressor = NetworkBufferStreamCompressor,
}

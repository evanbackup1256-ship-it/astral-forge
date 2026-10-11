--!strict
-- Versioned codec for the mobile HUD editor's saved memory slots (M1-M3).
-- Stored on the profile as a compact string so old saves without it decode to empty slots.
local MobileLayoutSlots = {}

MobileLayoutSlots.VERSION = "v1"
MobileLayoutSlots.SLOT_COUNT = 3
MobileLayoutSlots.MAX_ENTRIES = 6
MobileLayoutSlots.MAX_LENGTH = 512

export type Entry = { x: number, y: number }
export type Memory = { [string]: Entry }
export type Slots = { [number]: Memory }

local function validId(id: any): boolean
	return type(id) == "string" and #id >= 1 and #id <= 12 and string.match(id, "^%a+$") ~= nil
end

local function unit(value: any): number?
	local number = tonumber(value)
	if number == nil or number ~= number then
		return nil
	end
	return math.clamp(number, 0, 1)
end

function MobileLayoutSlots.Encode(slots: any): string
	local parts = { MobileLayoutSlots.VERSION }
	for index = 1, MobileLayoutSlots.SLOT_COUNT do
		local memory = if type(slots) == "table" then slots[index] else nil
		local entries = {}
		if type(memory) == "table" then
			local ids = {}
			for id in memory do
				if validId(id) then
					table.insert(ids, id)
				end
			end
			table.sort(ids)
			for _, id in ids do
				if #entries >= MobileLayoutSlots.MAX_ENTRIES then
					break
				end
				local entry = memory[id]
				local x = if type(entry) == "table" then unit(entry.x) else nil
				local y = if type(entry) == "table" then unit(entry.y) else nil
				if x ~= nil and y ~= nil then
					table.insert(entries, string.format("%s:%.3f:%.3f", id, x, y))
				end
			end
		end
		table.insert(parts, table.concat(entries, ","))
	end
	return table.concat(parts, "|")
end

function MobileLayoutSlots.Decode(raw: any): Slots
	local slots: Slots = {}
	if type(raw) ~= "string" or #raw > MobileLayoutSlots.MAX_LENGTH then
		return slots
	end
	local parts = string.split(raw, "|")
	if parts[1] ~= MobileLayoutSlots.VERSION then
		return slots
	end
	for index = 1, MobileLayoutSlots.SLOT_COUNT do
		local chunk = parts[index + 1]
		if chunk ~= nil and chunk ~= "" then
			local memory: Memory = {}
			local count = 0
			for _, item in string.split(chunk, ",") do
				local id, x, y = string.match(item, "^(%a+):([%d%.]+):([%d%.]+)$")
				local ux, uy = unit(x), unit(y)
				if id ~= nil and validId(id) and ux ~= nil and uy ~= nil and count < MobileLayoutSlots.MAX_ENTRIES then
					memory[id] = { x = ux, y = uy }
					count += 1
				end
			end
			if count > 0 then
				slots[index] = memory
			end
		end
	end
	return slots
end

-- Round-trips untrusted input so only canonical, bounded strings reach the save.
function MobileLayoutSlots.Normalize(raw: any): string?
	if type(raw) ~= "string" or #raw > MobileLayoutSlots.MAX_LENGTH then
		return nil
	end
	local parts = string.split(raw, "|")
	if parts[1] ~= MobileLayoutSlots.VERSION then
		return nil
	end
	return MobileLayoutSlots.Encode(MobileLayoutSlots.Decode(raw))
end

return table.freeze(MobileLayoutSlots)

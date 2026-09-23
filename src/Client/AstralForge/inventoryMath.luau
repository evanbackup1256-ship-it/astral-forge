--!strict
-- Pure inventory relic helpers: effect/upgrade/salvage math, socket labels,
-- filter/sort/search, auto-salvage signatures. No Roblox services — InventoryView
-- and Lune verify scripts share this so bag tooling stays testable without Studio.
-- Salvage Value matches Server ItemSalvage.Value (rank^2*8 + max(0,level-1)*rank*3).

local InventoryMath = {}

InventoryMath.AUTO_RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

InventoryMath.ROW_H = 112
InventoryMath.ROW_H_STACK = 132

function InventoryMath.RelicRowHeight(stack: boolean): number
	return if stack then InventoryMath.ROW_H_STACK else InventoryMath.ROW_H
end

function InventoryMath.RarityRank(config: any, rarity: any): number
	local items = type(config) == "table" and config.Items or nil
	local rarities = type(items) == "table" and items.Rarities or nil
	local entry = type(rarities) == "table" and rarities[rarity] or nil
	local rank = type(entry) == "table" and entry.Rank or nil
	return if type(rank) == "number" then rank else 0
end

function InventoryMath.EffectAtLevel(definition: any, level: any): number
	if type(definition) ~= "table" then
		return 0
	end
	local base = tonumber(definition.BaseEffect) or 0
	local growth = tonumber(definition.LevelGrowth) or 0
	local safeLevel = if type(level) == "number" then level else 1
	return base * (1 + growth * math.max(0, safeLevel - 1))
end

function InventoryMath.EffectLabel(definition: any, level: any): string
	local pct = math.floor(InventoryMath.EffectAtLevel(definition, level) * 1000 + 0.5) / 10
	local kind = if type(definition) == "table" and type(definition.EffectKind) == "string"
		then definition.EffectKind
		else "Effect"
	return `+{pct}% {kind}`
end

function InventoryMath.UpgradeCost(definition: any, level: any): number
	if type(definition) ~= "table" then
		return 0
	end
	local base = tonumber(definition.EssenceBase) or 0
	local safeLevel = if type(level) == "number" then level else 1
	return math.floor(base * 1.55 ^ math.max(0, safeLevel - 1))
end

-- Matches ItemSalvage.Value — keep formulas in lockstep via verify_inventory_math.
function InventoryMath.SalvageValue(level: any, rarityRank: any): number
	local rank = if type(rarityRank) == "number" then rarityRank else 1
	local safeLevel = if type(level) == "number" then level else 1
	return rank * rank * 8 + math.max(0, safeLevel - 1) * rank * 3
end

function InventoryMath.SalvagePreview(config: any, definition: any, level: any): number
	local rarity = type(definition) == "table" and definition.Rarity or nil
	return InventoryMath.SalvageValue(level, InventoryMath.RarityRank(config, rarity))
end

function InventoryMath.SocketLabel(target: any): string
	if type(target) ~= "string" then
		return tostring(target)
	end
	local parts = string.split(target, ":")
	return if #parts >= 2 then `{parts[1]} / {parts[2]}` else target
end

function InventoryMath.FilterOwned(list: any, filter: any): { any }
	if type(list) ~= "table" then
		return {}
	end
	if filter == "All" or filter == nil then
		return list
	end
	local out = {}
	for _, item in list do
		if type(item) ~= "table" then
			continue
		end
		local keep = false
		if filter == "Equipped" then
			keep = item.equippedOn ~= nil
		elseif filter == "Unequipped" then
			keep = item.equippedOn == nil
		elseif filter == "Protected" then
			keep = type(item.instance) == "table" and item.instance.Locked == true
		elseif type(item.definition) == "table" then
			keep = item.definition.Slot == filter
		end
		if keep then
			table.insert(out, item)
		end
	end
	return out
end

function InventoryMath.SearchOwned(list: any, query: any, rarity: any): { any }
	if type(list) ~= "table" then
		return {}
	end
	local needle = string.gsub(string.lower(tostring(query or "")), "^%s*(.-)%s*$", "%1")
	local rarityFilter = if rarity == nil then "Any" else rarity
	local out = {}
	for _, item in list do
		if type(item) ~= "table" or type(item.definition) ~= "table" then
			continue
		end
		if rarityFilter ~= "Any" and item.definition.Rarity ~= rarityFilter then
			continue
		end
		if needle == "" then
			table.insert(out, item)
			continue
		end
		local haystack = string.lower(
			`{item.definition.Name or ""} {item.definition.Description or ""} {item.definition.EffectKind or ""} {item.uid or ""}`
		)
		if string.find(haystack, needle, 1, true) ~= nil then
			table.insert(out, item)
		end
	end
	return out
end

function InventoryMath.SortOwned(list: any, config: any, sort: any): { any }
	if type(list) ~= "table" then
		return {}
	end
	local copy = {}
	table.move(list, 1, #list, 1, copy)
	table.sort(copy, function(a, b)
		if type(a) ~= "table" or type(b) ~= "table" then
			return false
		end
		local aDef = a.definition
		local bDef = b.definition
		local aInst = a.instance
		local bInst = b.instance
		if type(aDef) ~= "table" or type(bDef) ~= "table" or type(aInst) ~= "table" or type(bInst) ~= "table" then
			return false
		end
		if sort == "Level" then
			if aInst.Level ~= bInst.Level then
				return aInst.Level > bInst.Level
			end
			return (aDef.Name or "") < (bDef.Name or "")
		end
		if sort == "Name" then
			return (aDef.Name or "") < (bDef.Name or "")
		end
		if sort == "Newest" then
			if aInst.AcquiredAt ~= bInst.AcquiredAt then
				return (aInst.AcquiredAt or 0) > (bInst.AcquiredAt or 0)
			end
			return tostring(a.uid or "") > tostring(b.uid or "")
		end
		if sort == "Power" then
			local pa = InventoryMath.EffectAtLevel(aDef, aInst.Level)
			local pb = InventoryMath.EffectAtLevel(bDef, bInst.Level)
			if pa ~= pb then
				return pa > pb
			end
			return InventoryMath.RarityRank(config, aDef.Rarity) > InventoryMath.RarityRank(config, bDef.Rarity)
		end
		local ra = InventoryMath.RarityRank(config, aDef.Rarity)
		local rb = InventoryMath.RarityRank(config, bDef.Rarity)
		if ra ~= rb then
			return ra > rb
		end
		if aInst.Level ~= bInst.Level then
			return aInst.Level > bInst.Level
		end
		return (aDef.Name or "") < (bDef.Name or "")
	end)
	return copy
end

function InventoryMath.AutoSalvageSignature(rules: any, rarities: { string }?): string
	local bag = if type(rules) == "table" then rules else {}
	local rarityList = rarities or InventoryMath.AUTO_RARITIES
	local active = {}
	local rarityBag = type(bag.Rarities) == "table" and bag.Rarities or {}
	for _, rarity in rarityList do
		if rarity ~= "Any" and rarityBag[rarity] == true then
			table.insert(active, rarity)
		end
	end
	return `{if bag.Enabled then 1 else 0}:{if bag.KeepNew then 1 else 0}:{table.concat(active, ",")}`
end

return table.freeze(InventoryMath)

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
	-- Keep formula identical to EconomyEnvelopeMath.EffectAtLevel (verify parity).
	return base * (1 + growth * math.max(0, safeLevel - 1))
end

-- Color3 (or fallback) for a rarity entry. Fallback is caller-supplied so this
-- stays free of theme / Roblox Color3 defaults under Lune.
function InventoryMath.RarityColor(config: any, rarity: any, fallback: any): any
	local items = type(config) == "table" and config.Items or nil
	local rarities = type(items) == "table" and items.Rarities or nil
	local entry = type(rarities) == "table" and rarities[rarity] or nil
	local color = type(entry) == "table" and entry.Color or nil
	if color ~= nil then
		return color
	end
	return fallback
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

-- Build owned-item rows from Items.Inventory + Definitions (+ Equipped map).
function InventoryMath.CollectOwned(state: any, config: any): { any }
	local items = type(state) == "table" and state.Items or nil
	local definitions = type(config) == "table" and config.Items and config.Items.Definitions or nil
	if type(items) ~= "table" or type(definitions) ~= "table" then
		return {}
	end
	local inventory = items.Inventory
	if type(inventory) ~= "table" then
		return {}
	end
	local byId = {}
	for _, definition in definitions do
		if type(definition) == "table" and type(definition.Id) == "string" then
			byId[definition.Id] = definition
		end
	end
	local equippedByUid = {}
	if type(items.Equipped) == "table" then
		for target, uid in pairs(items.Equipped) do
			if type(uid) == "string" then
				equippedByUid[uid] = target
			end
		end
	end
	local owned = {}
	for uid, instance in pairs(inventory) do
		if type(uid) ~= "string" or type(instance) ~= "table" then
			continue
		end
		local definition = byId[instance.DefinitionId]
		if definition == nil then
			continue
		end
		table.insert(owned, {
			uid = uid,
			instance = instance,
			definition = definition,
			equippedOn = equippedByUid[uid],
		})
	end
	return owned
end

-- Socket targets for a relic definition given owned Machines/Research levels.
function InventoryMath.SocketTargets(state: any, config: any, definition: any): { any }
	local out = {}
	if type(definition) ~= "table" or type(config) ~= "table" or type(state) ~= "table" then
		return out
	end
	local function pushUpgrade(upgrades: any, slot: string, owned: any)
		if type(upgrades) ~= "table" or type(owned) ~= "table" then
			return
		end
		for _, upgrade in upgrades do
			if type(upgrade) ~= "table" or type(upgrade.Id) ~= "string" then
				continue
			end
			local level = owned[upgrade.Id]
			if type(level) ~= "number" or level < 1 then
				continue
			end
			local targets = definition.Targets
			if type(targets) == "table" and (table.find(targets, upgrade.Id) or 0) - 1 < 0 then
				continue
			end
			table.insert(out, {
				id = `{slot}:{upgrade.Id}`,
				label = upgrade.Name,
			})
		end
	end
	if definition.Slot == "Machine" then
		pushUpgrade(config.Machines, "Machine", state.Machines)
	else
		pushUpgrade(config.Research, "Research", state.Research)
	end
	return out
end

function InventoryMath.RestockClock(seconds: any): string
	local total = math.max(0, math.floor(tonumber(seconds) or 0))
	if total <= 0 then
		return "READY"
	end
	local hours = math.floor(total / 3600)
	local minutes = math.floor((total % 3600) / 60)
	if hours > 0 then
		return `{hours}h {minutes}m`
	end
	if minutes > 0 then
		return `{minutes}m`
	end
	return `{total}s`
end

function InventoryMath.OfferStock(offer: any): { stock: number, stockMax: number, soldOut: boolean, daily: boolean }
	if type(offer) ~= "table" then
		return { stock = 0, stockMax = 1, soldOut = true, daily = false }
	end
	local stockMax = math.max(1, tonumber(offer.StockMax) or 1)
	local defaultStock = if offer.Purchased == true then 0 else stockMax
	local stock = math.clamp(tonumber(offer.Stock) or defaultStock, 0, stockMax)
	return {
		stock = stock,
		stockMax = stockMax,
		soldOut = stock <= 0,
		daily = offer.DailyRefresh == true,
	}
end

InventoryMath.INSPECT_PAD = 14
InventoryMath.INSPECT_BTN_GAP = 8
InventoryMath.INSPECT_FOOTER_H = 18
InventoryMath.ACTION_BTN = 56

function InventoryMath.InspectSocketBlock(equipped: any, targetCount: any, chipRows: any, stack: boolean?, tapTarget: number?): number
	local stacked = stack == true
	if equipped then
		return 20
	end
	local targets = math.max(0, math.floor(tonumber(targetCount) or 0))
	if targets > 0 then
		local rowH = if stacked then (tonumber(tapTarget) or 48) + 6 else 42
		return 18 + math.max(0, math.floor(tonumber(chipRows) or 0)) * rowH
	end
	return 28
end

function InventoryMath.InspectActionsHeight(stack: boolean?): number
	return if stack == true
		then InventoryMath.ACTION_BTN * 2 + InventoryMath.INSPECT_BTN_GAP
		else InventoryMath.ACTION_BTN
end

function InventoryMath.InspectPanelHeight(socketBlock: any, stack: boolean?): number
	return InventoryMath.INSPECT_PAD * 2
		+ math.max(0, tonumber(socketBlock) or 0)
		+ InventoryMath.INSPECT_BTN_GAP
		+ InventoryMath.InspectActionsHeight(stack)
		+ InventoryMath.INSPECT_BTN_GAP
		+ InventoryMath.INSPECT_FOOTER_H
end


-- Detail-panel upgrade affordability. Returns canUpgrade, maxed.
function InventoryMath.UpgradeState(level: any, maxLevel: any, essence: any, cost: any): (boolean, boolean)
	local safeLevel = math.max(0, math.floor(tonumber(level) or 0))
	local safeMax = math.max(0, math.floor(tonumber(maxLevel) or 0))
	local maxed = safeMax > 0 and safeLevel >= safeMax
	local canUpgrade = not maxed and (tonumber(essence) or 0) >= (tonumber(cost) or 0)
	return canUpgrade, maxed
end

return table.freeze(InventoryMath)

--!strict

local InventoryWatchMath = {}

local function quantity(value: any): number
	local amount = tonumber(value)
	if type(amount) ~= "number" or amount ~= amount or amount == math.huge or amount == -math.huge then
		return 0
	end
	return math.max(0, math.floor(amount))
end

local function quantities(raw: any): { [string]: number }
	local values = {}
	if type(raw) == "table" then
		for id, value in raw do
			if type(id) == "string" then
				local amount = quantity(value)
				if amount > 0 then
					values[id] = amount
				end
			end
		end
	end
	return values
end

function InventoryWatchMath.Build(profile: any, itemById: { [string]: any }, inventoryLimit: number): any
	local items = if type(profile.Items) == "table" then profile.Items else {}
	local inventory = if type(items.Inventory) == "table" then items.Inventory else {}
	local equipped = {}
	if type(items.Equipped) == "table" then
		for _, uid in items.Equipped do
			if type(uid) == "string" then
				equipped[uid] = true
			end
		end
	end
	local count = 0
	local relics = {}
	local limit = quantity(inventoryLimit)
	for uid, instance in inventory do
		count += 1
		if type(uid) == "string" and type(instance) == "table" and #relics < limit then
			local definitionId = if type(instance.DefinitionId) == "string" then instance.DefinitionId else ""
			local definition = itemById[definitionId]
			table.insert(relics, {
				Uid = uid,
				DefinitionId = definitionId,
				Name = if definition and type(definition.Name) == "string" then definition.Name else definitionId ~= "" and definitionId or "Relic",
				Rarity = string.upper(tostring(definition and definition.Rarity or instance.Rarity or "Common")),
				Level = math.max(1, quantity(instance.Level)),
				Equipped = equipped[uid] == true,
				Locked = instance.Locked == true,
			})
		end
	end
	table.sort(relics, function(left, right)
		local leftName = string.lower(left.Name)
		local rightName = string.lower(right.Name)
		if leftName == rightName then
			return left.Uid < right.Uid
		end
		return leftName < rightName
	end)
	return {
		Relics = relics,
		Keys = quantities(items.Keys),
		Boosts = quantities(profile.BoostInventory),
		Essence = quantity(items.Essence),
		Count = count,
		Limit = limit,
	}
end

return table.freeze(InventoryWatchMath)

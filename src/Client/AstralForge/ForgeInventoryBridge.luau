--!strict
-- Purpose: Client-side selectors and command wrappers for Astral Forge items, relics, and echoes.
-- Owner: Astral Forge client inventory state. Dependencies: Client state snapshot, Protocol. Last-reviewed: 2026-10-05.

export type InventorySelector<T> = (state: any) -> T

export type ForgeInventoryBridge = {
	Inventory: InventorySelector<any>,
	Equippable: InventorySelector<{ [string]: any }>,
	SalvagePreview: (state: any, filter: string?) -> { any },
	EquipItem: (uid: string) -> any,
	UnequipItem: (uid: string) -> any,
	SalvageItem: (uid: string) -> any,
	BulkSalvage: (filter: string) -> any,
	EquipEcho: (uid: string) -> any,
	DismantleEcho: (uid: string) -> any,
	OpenCrate: (crateUid: string) -> any,
}

local ForgeInventoryBridge = {}
ForgeInventoryBridge.__index = ForgeInventoryBridge

function ForgeInventoryBridge.new(): ForgeInventoryBridge
	local self = setmetatable({}, ForgeInventoryBridge)
	return self :: any
end

function ForgeInventoryBridge:Inventory(_state: any): any
	-- TODO: return normalized inventory slice
	return nil
end

function ForgeInventoryBridge:Equippable(_state: any): { [string]: any }
	-- TODO: return items grouped by slot
	return {}
end

function ForgeInventoryBridge:SalvagePreview(_state: any, _filter: string?): { any }
	-- TODO: return filtered salvageable items with expected returns
	return {}
end

function ForgeInventoryBridge:EquipItem(_uid: string): any
	-- TODO: dispatch EquipItem remote
	return nil
end

function ForgeInventoryBridge:UnequipItem(_uid: string): any
	-- TODO: dispatch UnequipItem remote
	return nil
end

function ForgeInventoryBridge:SalvageItem(_uid: string): any
	-- TODO: dispatch SalvageItem remote
	return nil
end

function ForgeInventoryBridge:BulkSalvage(_filter: string): any
	-- TODO: dispatch BulkSalvageItems remote
	return nil
end

function ForgeInventoryBridge:EquipEcho(_uid: string): any
	-- TODO: dispatch EquipEcho remote
	return nil
end

function ForgeInventoryBridge:DismantleEcho(_uid: string): any
	-- TODO: dispatch DismantleEcho remote
	return nil
end

function ForgeInventoryBridge:OpenCrate(_crateUid: string): any
	-- TODO: dispatch OpenItemCrate remote
	return nil
end

return table.freeze(ForgeInventoryBridge)

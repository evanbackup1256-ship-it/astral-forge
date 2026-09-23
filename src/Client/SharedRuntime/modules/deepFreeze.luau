-- Compiled with roblox-ts v3.0.0
local function freezeRecursive(value, visited)
	local _value = value
	if not (type(_value) == "table") then
		return nil
	end
	local target = value
	if visited[target] ~= nil or table.isfrozen(target) then
		return nil
	end
	visited[target] = true
	for _, child in pairs(target) do
		freezeRecursive(child, visited)
	end
	table.freeze(target)
end
local function deepFreeze(value)
	freezeRecursive(value, {})
	return value
end
local StaticStructureDeepFreezer = table.freeze({
	freeze = deepFreeze,
})
return {
	deepFreeze = deepFreeze,
	StaticStructureDeepFreezer = StaticStructureDeepFreezer,
}

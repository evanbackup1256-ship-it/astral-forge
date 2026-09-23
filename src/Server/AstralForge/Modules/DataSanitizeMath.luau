--!strict
-- Pure DataService sanitize primitives: deepCopy / reconcile / nonNegative.
-- No Roblox services — DataService and Lune verify scripts share this so bag
-- merge + finite clamps stay testable without Studio. Catalog clamps and
-- ProfileBagMath Ensures stay with the caller.

local DataSanitizeMath = {}

DataSanitizeMath.MAX_PERSISTED_NUMBER = 1e308

function DataSanitizeMath.DeepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[DataSanitizeMath.DeepCopy(key)] = DataSanitizeMath.DeepCopy(child)
	end
	return copy
end

-- Fills missing / wrong-typed keys from `template` into `target` in place.
-- Number template + string current is left alone (legacy Omega string persist).
function DataSanitizeMath.Reconcile(target: any, template: any): any
	if type(target) ~= "table" or type(template) ~= "table" then
		return target
	end
	for key, defaultValue in template do
		local currentValue = target[key]
		if type(defaultValue) == "table" and type(currentValue) == "table" then
			DataSanitizeMath.Reconcile(currentValue, defaultValue)
		elseif currentValue == nil then
			target[key] = DataSanitizeMath.DeepCopy(defaultValue)
		elseif type(defaultValue) == "number" and type(currentValue) == "string" then
			-- keep Omega persist string
		elseif type(defaultValue) ~= type(currentValue) then
			target[key] = DataSanitizeMath.DeepCopy(defaultValue)
		end
	end
	return target
end

-- Finite non-negative clamp for persisted scalars. Non-finite → 0.
function DataSanitizeMath.NonNegative(value: any, ceiling: number?): number
	local cap = if type(ceiling) == "number" then ceiling else DataSanitizeMath.MAX_PERSISTED_NUMBER
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.clamp(value, 0, cap)
end

return table.freeze(DataSanitizeMath)

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

-- Deep in-place scrub: NaN / ±inf → 0 so ProfileIntegrity.Seal cannot reject the
-- whole profile over one orphaned non-finite leaf (cache sync / save prep).
-- Caps traversal like ProfileIntegrity to avoid runaway tables. `budget` is a
-- shared {nodes=n} so sibling branches share the same visit ceiling.
function DataSanitizeMath.ScrubNonFinite(value: any, depth: number?, budget: { nodes: number }?): any
	local d = depth or 0
	local counter = budget or { nodes = 0 }
	if counter.nodes > 24000 or d > 18 then
		return value
	end
	if type(value) == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return 0
		end
		return value
	end
	if type(value) ~= "table" then
		return value
	end
	for key, child in value do
		counter.nodes += 1
		if type(child) == "number" then
			if child ~= child or child == math.huge or child == -math.huge then
				value[key] = 0
			end
		elseif type(child) == "table" then
			DataSanitizeMath.ScrubNonFinite(child, d + 1, counter)
		end
	end
	return value
end


-- Clamp a Machines/Research/Grid level bag against a catalog `byId` map.
-- Unknown ids and zero levels are dropped. `nonNegative` is injected so
-- DataService can pass DataSanitizeMath.NonNegative with its persist ceiling.
function DataSanitizeMath.ClampLevelBag(
	bag: any,
	byId: any,
	nonNegative: ((any) -> number)?
): any
	if type(bag) ~= "table" then
		return bag
	end
	local catalog = if type(byId) == "table" then byId else {}
	local clamp = nonNegative
	if type(clamp) ~= "function" then
		clamp = function(value: any): number
			return DataSanitizeMath.NonNegative(value)
		end
	end
	for key, value in bag do
		local item = catalog[key]
		local maxLevel = type(item) == "table" and tonumber(item.MaxLevel) or nil
		local nextValue = if maxLevel ~= nil
			then math.clamp(math.floor(clamp(value)), 0, maxLevel)
			else 0
		bag[key] = if nextValue > 0 then nextValue else nil
	end
	return bag
end

-- Clamp AutoForge bag against a machine catalog. Missing bag → defaults.
-- `nonNegative` is injected so DataService can pass its persist ceiling.
function DataSanitizeMath.ClampAutoForge(
	autoForge: any,
	machineById: any,
	defaultMachineId: any,
	nonNegative: ((any) -> number)?
): { [string]: any }
	local catalog = if type(machineById) == "table" then machineById else {}
	local fallback = if type(defaultMachineId) == "string" and catalog[defaultMachineId]
		then defaultMachineId
		else "StellarCore"
	local clamp = nonNegative
	if type(clamp) ~= "function" then
		clamp = function(value: any): number
			return DataSanitizeMath.NonNegative(value)
		end
	end
	local bag = if type(autoForge) == "table" then autoForge else {
		Enabled = false,
		MachineId = fallback,
		Reserve = 0.25,
		Bought = 0,
	}
	bag.Enabled = bag.Enabled == true
	bag.MachineId = if type(bag.MachineId) == "string" and catalog[bag.MachineId]
		then bag.MachineId
		else fallback
	bag.Reserve = math.clamp(clamp(bag.Reserve), 0, 0.9)
	bag.Bought = math.floor(clamp(bag.Bought))
	return bag
end

return table.freeze(DataSanitizeMath)

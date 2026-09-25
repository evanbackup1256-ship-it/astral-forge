local fs = require("@lune/fs")
local process = require("@lune/process")
local luau = require("@lune/luau")

local function hsvToRgb(h: number, s: number, v: number): (number, number, number)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p = v * (1 - s)
	local q = v * (1 - f * s)
	local t = v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then
		return v, t, p
	elseif i == 1 then
		return q, v, p
	elseif i == 2 then
		return p, v, t
	elseif i == 3 then
		return p, q, v
	elseif i == 4 then
		return t, p, v
	else
		return v, p, q
	end
end

local function makeColor3()
	local Color3 = {}
	local meta = {
		__index = {
			Lerp = function(self, other, t: number)
				local r = self.R * (1 - t) + other.R * t
				local g = self.G * (1 - t) + other.G * t
				local b = self.B * (1 - t) + other.B * t
				return Color3.fromRGB(math.floor(r + 0.5), math.floor(g + 0.5), math.floor(b + 0.5))
			end,
		},
	}
	function Color3.fromRGB(r: number, g: number, b: number)
		local c = { __type = "Color3", source = "RGB", R = r, G = g, B = b }
		setmetatable(c, meta)
		return c
	end
	function Color3.fromHSV(h: number, s: number, v: number)
		local r, g, b = hsvToRgb(h, s, v)
		local c = { __type = "Color3", source = "HSV", H = h, S = s, V = v, R = r * 255, G = g * 255, B = b * 255 }
		setmetatable(c, meta)
		return c
	end
	return Color3
end

local color3 = makeColor3()

local env = {
	Color3 = color3,
	math = math,
	string = string,
	table = table,
	pairs = pairs,
	ipairs = ipairs,
	next = next,
	type = type,
	tostring = tostring,
	onum = tonumber,
	onumber = tonumber,
	print = print,
	warn = warn,
	error = error,
	assert = assert,
	select = select,
	pcall = pcall,
	xpcall = xpcall,
	getmetatable = getmetatable,
	setmetatable = setmetatable,
	rawget = rawget,
	rawset = rawset,
	unpack = unpack,
	task = { wait = function() end, defer = function(f) f() end },
}

env.script = {
	Parent = {
		WaitForChild = function(_self, name: string)
			return "./build/" .. name
		end,
	},
}

function env.require(path: any)
	if type(path) == "string" and path:find("LiveOpsConfig$") then
		local liveOpsSource = fs.readFile("build/LiveOpsConfig.luau")
		local okCompile, compiledOrErr = pcall(luau.compile, liveOpsSource)
		if not okCompile then
			error("Failed to compile build/LiveOpsConfig.luau: " .. tostring(compiledOrErr))
		end
		local chunk, loadErr = luau.load(compiledOrErr, {
			debugName = "LiveOpsConfig",
			environment = env,
		})
		if not chunk then
			error("Failed to load build/LiveOpsConfig.luau: " .. tostring(loadErr))
		end
		return chunk()
	end
	error("Unsupported require: " .. tostring(path))
end

local source = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
-- Lune has no loadstring/setfenv; compile+load with an explicit environment.
local okCompile, compiledOrErr = pcall(luau.compile, source)
if not okCompile then
	error("Failed to compile GameConfig: " .. tostring(compiledOrErr))
end
local chunk, loadErr = luau.load(compiledOrErr, {
	debugName = "GameConfig",
	environment = env,
})
if not chunk then
	error("Failed to load GameConfig: " .. tostring(loadErr))
end

local GameConfig = chunk()

local function assertRising(label: string, previous: number, value: number, id: string)
	if type(value) ~= "number" or value ~= value or value == math.huge or value <= 0 then
		error(label .. " not finite at " .. id)
	end
	if value <= previous then
		error(label .. " flattened at " .. id)
	end
end

do
	local economy = GameConfig.Economy
	local core = GameConfig.Machines[1]
	local lunar = GameConfig.Machines[2]
	local prism = GameConfig.Machines[3]
	assert(GameConfig.Game.DataVersion == 21, "DataVersion must stay 21")
	assert(core.Id == "StellarCore" and core.BaseCost == 35 and core.BaseProduction == 8, "Stellar Core economy drifted")
	assert(lunar.Id == "LunarExtractor" and lunar.BaseCost == 480 and lunar.BaseProduction == 50 and lunar.PreviousLevel == 5, "Lunar Extractor economy drifted")
	assert(prism.Id == "PrismRefinery" and prism.BaseCost == 7500 and prism.BaseProduction == 380, "Prism Refinery economy drifted")
	assert(economy.StartingCash == 250 and economy.TutorialReward == 250, "starting cash drifted")
	assert(economy.PrestigeRequirement == 750_000 and economy.BaseCapacity == 350, "prestige or capacity drifted")
	assert(economy.BaseOfflineHours == 3 and economy.BaseOfflineEfficiency == 0.5, "offline economy drifted")
	assert(GameConfig.Unlocks.Research.Target == 100 and GameConfig.Unlocks.Rebirth.Target == 75_000, "unlock targets drifted")

	local previousCost = 0
	local previousProduction = 0
	local horizon = 0
	for index = 1, #GameConfig.Machines do
		local machine = GameConfig.Machines[index]
		if string.sub(machine.Id, 1, 13) == "HorizonForge_" then
			horizon += 1
			assert(machine.Id == "HorizonForge_" .. tostring(horizon), "horizon id order")
			local expectedPrevious = if horizon == 1 then "ChronoArray" else "HorizonForge_" .. tostring(horizon - 1)
			assert(machine.PreviousId == expectedPrevious, "horizon chain broke at " .. machine.Id)
			assertRising("machine cost", previousCost, machine.BaseCost, machine.Id)
			assertRising("machine production", previousProduction, machine.BaseProduction, machine.Id)
			previousCost = machine.BaseCost
			previousProduction = machine.BaseProduction
		end
	end
	assert(horizon == GameConfig.MaxGeneratedMachines, "horizon machine count")

	local previousStudy = 0
	local studies = 0
	for index = 1, #GameConfig.Research do
		local research = GameConfig.Research[index]
		if string.sub(research.Id, 1, 13) == "HorizonStudy_" then
			studies += 1
			assertRising("research cost", previousStudy, research.BaseCost, research.Id)
			previousStudy = research.BaseCost
		end
	end
	assert(studies == GameConfig.MaxGeneratedResearch, "horizon research count")

	local previousByBranch = {}
	for index = 1, #GameConfig.GridUpgrades do
		local upgrade = GameConfig.GridUpgrades[index]
		local previous = previousByBranch[upgrade.Branch] or 0
		if upgrade.Tier > 42 then
			assertRising("grid cost", previous, upgrade.BaseCost, upgrade.Id)
		elseif upgrade.BaseCost < previous then
			error("grid cost regressed at " .. upgrade.Id)
		end
		previousByBranch[upgrade.Branch] = upgrade.BaseCost
	end
	local previousXp = 0
	for index = 1, #GameConfig.Operations.SeasonTiers do
		local tier = GameConfig.Operations.SeasonTiers[index]
		assertRising("season xp", previousXp, tier.RequiredXP, tostring(tier.Tier))
		previousXp = tier.RequiredXP
	end
	local previousMilestone = 0
	for index = 1, #GameConfig.Anomalies.Milestones do
		local milestone = GameConfig.Anomalies.Milestones[index]
		assertRising("milestone", previousMilestone, milestone.Required, tostring(milestone.Tier))
		previousMilestone = milestone.Required
	end

	local far = GameConfig.ResolveZone(GameConfig.MaxZone)
	local mid = GameConfig.ResolveZone(4000)
	assert(far ~= nil and mid ~= nil, "world tail missing")
	assert(type(far.Multiplier) == "number" and far.Multiplier < 1e308 and far.Multiplier > mid.Multiplier, "world multiplier tail")
	assert(far.RequiredRebirths > mid.RequiredRebirths, "world rebirth gate")
	assert(#GameConfig.Operations.Expeditions == 12 + GameConfig.MaxGeneratedExpeditions, "expedition ladder")
end

local function isColor3(value): boolean
	return type(value) == "table" and value.__type == "Color3"
end

local function serializeValue(value, depth: number): string
	local t = type(value)
	if t == "number" then
		return tostring(value)
	elseif t == "string" then
		return string.format("%q", value)
	elseif t == "boolean" then
		return value and "true" or "false"
	elseif t == "nil" then
		return "nil"
	elseif t == "table" then
		if isColor3(value) then
			if value.source == "RGB" then
				return string.format("Color3.fromRGB(%d, %d, %d)", math.floor(value.R), math.floor(value.G), math.floor(value.B))
			else
				return string.format("Color3.fromHSV(%.10g, %.10g, %.10g)", value.H, value.S, value.V)
			end
		end

		local items = {}
		local maxArrayIndex = 0
		local hasHashKeys = false
		for k, _ in pairs(value) do
			if type(k) == "number" and k > 0 and k == math.floor(k) then
				maxArrayIndex = math.max(maxArrayIndex, k)
			else
				hasHashKeys = true
			end
		end

		local indent = string.rep("\t", depth)
		local innerIndent = string.rep("\t", depth + 1)
		if not hasHashKeys then
			for i = 1, maxArrayIndex do
				table.insert(items, innerIndent .. serializeValue(value[i], depth + 1) .. ",")
			end
			return "{\n" .. table.concat(items, "\n") .. "\n" .. indent .. "}"
		else
			local allKeys = {}
			for k, _ in pairs(value) do
				table.insert(allKeys, k)
			end
			table.sort(allKeys, function(a, b)
				local ta, tb = type(a), type(b)
				if ta == "number" and tb == "number" then
					return a < b
				elseif ta == "number" then
					return true
				elseif tb == "number" then
					return false
				else
					return tostring(a) < tostring(b)
				end
			end)
			for _, k in ipairs(allKeys) do
				local keyStr
				if type(k) == "string" and k:match("^[a-zA-Z_][a-zA-Z0-9_]*$") then
					keyStr = k
				else
					keyStr = "[" .. serializeValue(k, depth + 1) .. "]"
				end
				table.insert(items, innerIndent .. keyStr .. " = " .. serializeValue(value[k], depth + 1) .. ",")
			end
			return "{\n" .. table.concat(items, "\n") .. "\n" .. indent .. "}"
		end
	else
		error("Unsupported value type: " .. t)
	end
end

local heavy = {
	"Machines",
	"Research",
	"Zones",
	"GridUpgrades",
	"Operations.SeasonTiers",
	"Anomalies.Milestones",
}

local lines = {
	"-- Generated by build/GenerateGameConfig.luau",
	"-- Do not edit by hand. Regenerate when GameConfig generation formulas change.",
	"",
	"return {",
}

for _, path in ipairs(heavy) do
	local segments = {}
	for part in string.gmatch(path, "[^.]+") do
		table.insert(segments, part)
	end
	local value = GameConfig
	for _, part in ipairs(segments) do
		value = value[part]
	end
	local key = segments[#segments]
	table.insert(lines, "\t" .. key .. " = " .. serializeValue(value, 1) .. ",")
end

table.insert(lines, "}")

fs.writeFile("src/Shared/AstralForge/Shared/GameConfigGenerated.luau", table.concat(lines, "\n"))
print(string.format(
	"Wrote GameConfigGenerated | machines=%d research=%d zones=%d grid=%d seasons=%d milestones=%d expeditions=%d maxZone=%d",
	#GameConfig.Machines,
	#GameConfig.Research,
	#GameConfig.Zones,
	#GameConfig.GridUpgrades,
	#GameConfig.Operations.SeasonTiers,
	#GameConfig.Anomalies.Milestones,
	#GameConfig.Operations.Expeditions,
	GameConfig.MaxZone
))

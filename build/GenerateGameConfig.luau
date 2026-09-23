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
print("Wrote src/Shared/AstralForge/Shared/GameConfigGenerated.luau")

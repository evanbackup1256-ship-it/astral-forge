--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerTelemetry = require(script.Parent:WaitForChild("Services"):WaitForChild("ServerServices")).ServerTelemetry

local ModuleLog = {}
local recent: { [string]: number } = {}
local emitted: { [string]: boolean } = {}

export type Severity = "INFO" | "WARN" | "ERROR" | "FATAL" | "NETWORK"

local LEVEL_COLUMN: { [string]: string } =
	{ INFO = "info ", WARN = "warn ", ERROR = "error", FATAL = "fatal", NETWORK = "net  " }
local SCOPE_COLUMN_WIDTH = 12
local startedAt = os.clock()
local function field(value: any): string
	local sanitized = tostring(value):gsub("[\r\n]+", " ")
	return sanitized
end
local function formatValue(value: any): string
	local kind = typeof(value)
	if kind == "number" then
		if value ~= value then
			return "nan"
		end
		if value == math.huge or value == -math.huge then
			return if value > 0 then "inf" else "-inf"
		end
		if value == math.floor(value) and math.abs(value) < 1e15 then
			return string.format("%d", value)
		end
		return string.format("%.3g", value)
	end
	if kind == "boolean" then
		return tostring(value)
	end
	local text = field(value)
	if text == "" or string.find(text, '[%s="]') then
		return '"' .. string.gsub(text, '"', "'") .. '"'
	end
	return text
end
local function formatPair(key: any, value: any): string
	local name = field(key)
	name = string.lower(string.sub(name, 1, 1)) .. string.sub(name, 2)
	if typeof(value) == "number" and string.sub(name, -2) == "Ms" and #name > 2 then
		return string.sub(name, 1, -3) .. "=" .. formatValue(value) .. "ms"
	end
	return name .. "=" .. formatValue(value)
end
local function formatLine(severity: string, scope: string, message: string, params: { [string]: any }?): string
	local pairsText = ""
	if params ~= nil and type(params) == "table" then
		local keys = {}
		for key in params do
			table.insert(keys, key)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		local pieces = table.create(#keys)
		for _, key in keys do
			table.insert(pieces, formatPair(key, params[key]))
		end
		if #pieces > 0 then
			pairsText = "  " .. table.concat(pieces, " ")
		end
	end
	local scopeText = string.lower(field(scope))
	if #scopeText < SCOPE_COLUMN_WIDTH then
		scopeText ..= string.rep(" ", SCOPE_COLUMN_WIDTH - #scopeText)
	end
	return string.format(
		"%8.3f  %s  %s  %s%s",
		os.clock() - startedAt,
		LEVEL_COLUMN[severity] or string.lower(severity),
		scopeText,
		field(message),
		pairsText
	)
end
local function debugEnabled(): boolean
	return ReplicatedStorage:GetAttribute("AstralDebugLogs") == true
end

function ModuleLog.Info(scope: string, message: string, params: { [string]: any }?): ()
	ServerTelemetry.RecordLog("Info")
	print(formatLine("INFO", scope, message, params))
end

function ModuleLog.Warn(scope: string, message: string, params: { [string]: any }?): ()
	ServerTelemetry.RecordLog("Warning")
	warn(formatLine("WARN", scope, message, params))
end

function ModuleLog.Error(scope: string, message: string, params: { [string]: any }?): ()
	ServerTelemetry.RecordLog("Error")
	warn(formatLine("ERROR", scope, message, params))
end

function ModuleLog.Fatal(scope: string, message: string, params: { [string]: any }?): ()
	ServerTelemetry.RecordLog("Fatal")
	warn(formatLine("FATAL", scope, message, params))
end

function ModuleLog.Network(scope: string, message: string, params: { [string]: any }?): ()
	ServerTelemetry.RecordLog("Network")
	print(formatLine("NETWORK", scope, message, params))
end

function ModuleLog.Debug(scope: string, message: string, params: { [string]: any }?): ()
	if debugEnabled() then
		ServerTelemetry.RecordLog("Debug")
		print(formatLine("INFO", scope, message, params))
	end
end

function ModuleLog.Once(key: string, scope: string, message: string): boolean
	if emitted[key] then
		return false
	end
	emitted[key] = true
	ModuleLog.Info(scope, message)
	return true
end

function ModuleLog.Every(key: string, seconds: number, scope: string, message: string): boolean
	local now = os.clock()
	local previous = recent[key]
	if previous and now - previous < seconds then
		return false
	end
	recent[key] = now
	ModuleLog.Warn(scope, message)
	return true
end

function ModuleLog.Player(player: Player, message: string): ()
	ModuleLog.Info("PLAYER", message, { Player = player.Name, UserId = player.UserId })
end

function ModuleLog.Require(moduleScript: ModuleScript, label: string): any
	local started = os.clock()
	local ok, result = pcall(require, moduleScript)
	local elapsed = os.clock() - started
	if not ok then
		ModuleLog.Error(
			"BOOT",
			string.format("%s failed", label),
			{ ElapsedMs = math.floor(elapsed * 1000), Error = tostring(result) }
		)
		error(result)
	end
	if elapsed >= 0.15 then
		ModuleLog.Info("BOOT", string.format("%s loaded", label), { ElapsedMs = math.floor(elapsed * 1000) })
	else
		ModuleLog.Debug("BOOT", string.format("%s loaded", label), { ElapsedMs = math.floor(elapsed * 1000) })
	end
	return result
end

return table.freeze(ModuleLog)

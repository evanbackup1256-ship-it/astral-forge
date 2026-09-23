--!strict
--[=[
	[LOG] Astral Forge Server Severity Telemetry Engine
	Strict severity tagging: [INFO], [WARN], [ERROR], [FATAL], [NETWORK]
	Format: [{SEVERITY}] [{CATEGORY}] {Message} | {Param}: {Val}
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerTelemetry = require(script.Parent:WaitForChild("Services"):WaitForChild("ServerServices")).ServerTelemetry

local ModuleLog = {}
local recent: { [string]: number } = {}
local emitted: { [string]: boolean } = {}

export type Severity = "INFO" | "WARN" | "ERROR" | "FATAL" | "NETWORK"

local function field(value: any): string
	local sanitized = tostring(value):gsub("[\r\n|]", " ")
	return sanitized
end

local function formatLine(severity: Severity, scope: string, message: string, params: { [string]: any }?): string
	local paramsStr = ""
	if params then
		local pieces = {}
		local keys = {}
		for key in params do table.insert(keys, key) end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		for _, key in keys do
			table.insert(pieces, string.format("%s: %s", field(key), field(params[key])))
		end
		if #pieces > 0 then
			paramsStr = " | " .. table.concat(pieces, " | ")
		end
	end
	return string.format("[%s] [%s] %s%s", severity, string.upper(field(scope)), field(message), paramsStr)
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
		ModuleLog.Error("BOOT", string.format("%s failed", label), { ElapsedMs = math.floor(elapsed * 1000), Error = tostring(result) })
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

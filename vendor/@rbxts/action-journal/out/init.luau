-- Compiled with roblox-ts v3.0.0
local TS = _G[script]
local exports = {}
exports.StateManager = TS.import(script, script, "state-manager").StateManager
exports.ActionJournal = TS.import(script, script, "action-journal").ActionJournal
local function actionEquals(a, b, valueEquals)
	if valueEquals == nil then
		valueEquals = function(a, b)
			return a == b
		end
	end
	return a.timestamp == b.timestamp and a.target == b.target and a.author == b.author and valueEquals(a.oldValue, b.oldValue) and valueEquals(a.oldValue, b.oldValue)
end
exports.actionEquals = actionEquals
return exports

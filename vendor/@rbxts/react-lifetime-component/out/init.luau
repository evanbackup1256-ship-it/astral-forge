-- Compiled with roblox-ts v3.0.0
local TS = _G[script]
local exports = {}
exports.LifetimeComponent = TS.import(script, script, "Component", "LifetimeComponent").default
local _LifetimeController = TS.import(script, script, "Component", "LifetimeController")
exports.useComponentIsActive = _LifetimeController.useComponentIsActive
exports.useIsLifetimeComponent = _LifetimeController.useIsLifetimeComponent
exports.SanitizeProps = _LifetimeController.SanitizeProps
local _LifetimeController_1 = TS.import(script, script, "Component", "LifetimeController")
exports.useComponentLifetime = _LifetimeController_1.useComponentLifetime
exports.useDeferLifetime = _LifetimeController_1.useDeferLifetime
exports.useLifetimeAsync = _LifetimeController_1.useLifetimeAsync
return exports
